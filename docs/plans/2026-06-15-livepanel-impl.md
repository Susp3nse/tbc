# WS-3 + WS-9 — `CreateLivePanel` Factory + Ticker Consolidation — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md`
> §4.3 (WS-3, ★ flagship), §4.9 (WS-9). **Evidence:** `2026-06-14-platform-audit/02-diagnostics.md`
> (A/D/F), `03-performance.md` (#1).
> **Status (verified 2026-06-15):** Shared *debug* panel DONE (`debugpanel.lua` — the reference
> pattern). The **generalized factory** and the **adaptive-panel migration** are not started. Theme
> color-half DONE (WS-9); ticker consolidation pending (gated here). **Risk:** Med.
> **Depends on:** WS-1 step 2 (`NS.ShowCopyWindow`) must land first.

## Goal

Extract the debug panel's `out` writer + pooled-FontString layout engine into a reusable
`NS.CreateLivePanel(opts)` factory, then make **both** the shared debug panel and the Hunter adaptive
panel instances of it. This dogfoods the factory, deletes ~300 lines of hand-rolled window/ticker/
export code from `adaptivepanel.lua`, applies the warm theme to the off-brand adaptive panel, and
collapses the per-panel tickers into the factory's single refresh loop.

## Design decision (resolves §8 Q2): new `livepanel.lua`

Create a new module `apps/tbc-rotation/src/aio/livepanel.lua`; `debugpanel.lua` becomes a thin
consumer. This keeps the **shared-vs-instance boundary explicit**. Load order: the factory must load
before any panel instance — slot it just before `debugpanel.lua` (currently slot 9). Add to
`builder.config.json` `loadOrder` accordingly (e.g. `livepanel.lua` at slot 9, panels at 9/10).

---

## Step 1 — Build `NS.CreateLivePanel(opts)` in `livepanel.lua`

Move the `out` writer (`out:header` / `out:kv(label, val, hex)` / `out:line`) and the pooled-FontString
layout engine out of `debugpanel.lua` into the factory. Contract:

```lua
-- NS.CreateLivePanel(opts) -> panel
--   opts = {
--     title,                       -- window title
--     setting_key,                 -- NS.cached_settings flag that shows/hides it
--     width            = 240,
--     refresh_interval = 0.1,      -- seconds; one shared 10Hz default
--     build(out, ctx),             -- REQUIRED: the only thing a class writes
--     export = function(ctx) return csv_string end,  -- optional -> Export btn (uses NS.ShowCopyWindow)
--     on_clear = function() ... end,                 -- optional -> Clear btn
--   }
```

Factory **owns:** frame via `NS.CreateDebugWindow` (warm theme, movable, close btn), the `out` writer +
alloc-free pooled layout (reuse FontStrings across refreshes — **no per-frame table/string churn**),
auto-height from `out` entries, Export/Clear buttons, toggle-watch on `cached_settings[setting_key]`,
and a single refresh loop gated on `:IsShown()`. Class supplies **only** `build(out, ctx)`.

**Alloc rule (sacred):** the refresh path runs at 10 Hz — it must allocate nothing. Pre-build the
FontString pool at panel creation; `build` writes into reused rows; `out:kv` formats into a reused
buffer. Verify no `{}` or string concatenation that allocates inside the refresh tick.

---

## Step 2 — `debugpanel.lua` becomes a thin instance

Rewrite `debugpanel.lua` as:
```lua
NS.CreateLivePanel{
   title = "Menagerie Debug",
   setting_key = "show_debug_panel",
   build = function(out, ctx)
      build_generic_core(out, ctx)              -- the shared rows already in debugpanel today
      local cc = rotation_registry.class_config
      if cc and cc.debug_panel then cc.debug_panel(out, ctx) end
   end,
}
```
`/mdebug` must still toggle it. The class-provided `class_config.debug_panel(out, ctx)` callback
contract is unchanged — Hunter's `diag.lua` provider keeps working as-is.

**Verification:** `/mdebug` opens the panel; generic rows + Hunter's class rows render; warm theme;
movable; closes; toggles with the setting. Compare visually against pre-change screenshot.

---

## Step 3 — `hunter/adaptivepanel.lua` becomes an instance

Rewrite as:
```lua
NS.CreateLivePanel{
   title = "Adaptive",
   setting_key = "show_adaptive_panel",
   width = 360,
   build = function(out, ctx) ... end,          -- ~150 lines of pure content (which rows, hex colors)
   export = NS.HunterAdaptive.GetDecisionCSV,    -- Export btn -> NS.ShowCopyWindow
}
```
- Drop the ~300 lines of bespoke frame/`header()`/`row()`/`spacer()` closures, the 5 Hz `OnUpdate`
  watcher (`adaptivepanel.lua:438`), and the bespoke export window (now WS-1's `ShowCopyWindow`).
- `out:kv`'s existing `hex` arg covers the colorized option rows — `build` converts a `NS.Theme` color
  to a 6-char hex.
- Move `ForceRecompute()` / `refresh_settings()` calls **into** the `build` callback (they ran in the
  old ticker).
- The decision-log gate from WS-1 step 1 stays orthogonal — the panel reads `lastDecision`; the gated
  history feeds `GetDecisionCSV` for export.

**Verification (this is the risky one):**
- Panel renders at the expected size with all sections; pooled layout handles the larger row count /
  360px width / section bands **without per-frame allocation** (watch GC during a fight, or instrument
  a temporary alloc counter).
- Auto-height reproduces the old fixed ~360×590 footprint reasonably (or pin a min-height if needed).
- Export button produces the same CSV as before.
- Toggling `show_adaptive_panel` shows/hides correctly.

---

## Step 4 — WS-9 ticker consolidation (falls out of WS-3)

Once panels own their refresh via the factory's single loop:
- `adaptivepanel.lua`'s 5 Hz watcher is **gone** (subsumed by step 3).
- `debugpanel.lua`'s 10 Hz + 0.5 Hz watchers collapse into the factory loop (step 2).
- **Not factory candidates** (deferred per design §5, leave as-is): `cliptracker.lua:~1308` (0.5 Hz),
  `meleeweave.lua:~604` (20 Hz), `dashboard.lua` tickers (energy/refresh). **But** lower
  `meleeweave`'s unjustified 20 Hz to 10 Hz (0.1s) — one-line, no behavioral change, the largest
  hygiene win outside the factory.
- `dashboard.lua:172` `DARK_BORDER` local — optional: fold into `NS.Theme` as `border_dark`, or leave
  as a documented semantic constant. Minor; not blocking.

**Verification:** count remaining `OnUpdate` frames — should drop from 8 toward ~4 (dashboard ×3 +
cliptracker + meleeweave, panels now factory-owned). Confirm no visible refresh-rate regression on any
panel.

---

## Risks / open items

- **Pooled-layout generality** is the keystone risk: the debug panel's layout was sized for its row
  count; the adaptive panel is wider with more rows and color bands. Validate the pool grows/reuses
  correctly without per-frame allocation **before** declaring step 3 done.
- **Auto-height vs fixed:** if auto-height jitters with variable row counts, pin a min-height per panel
  via `opts` rather than fighting the layout engine.
- Ship as two commits: factory + debugpanel migration (behavior-preserving), then adaptive migration
  (visible change, verify separately).
- **Out of scope (do not generalize — §5):** the cliptracker swing *detector* and the meleeweave
  traffic-light *coach*. Only the panel/window/export chrome generalizes now; leave clean seams.
