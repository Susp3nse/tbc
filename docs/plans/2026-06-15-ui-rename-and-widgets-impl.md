# `ui.lua` → `profileui.lua` Rename + Shared Widget Primitives — Implementation Plan

> **Type:** Implementation (concrete file edits) with a short design rationale up front.
> **Date:** 2026-06-15. **Risk:** Low (rename: mechanical · widgets: additive + consumer refactor).
> **Owner decisions (locked):** rename target = `profileui.lua`; scope = rename **+** settings-widget
> library; adaptive engine generalization = **out of scope** for this plan.
>
> **Relationship to the platform-hardening effort:** this is a *sibling* workstream to
> `2026-06-14-platform-hardening-design.md`. As of 2026-06-15 the three workstreams this plan defers
> to have **already landed**: WS-3 (`livepanel.lua` / `NS.CreateLivePanel`, now slot 6 — `debugpanel.lua`
> and `hunter/adaptivepanel.lua` are thin instances), WS-1 (`NS.ShowCopyWindow`, now in `debug.lua:229`),
> and WS-9 (theme consolidation — `NS.Theme` is the single palette; `NS.DBG_THEME` is just an alias).
> This plan still deliberately does **not** touch live-panel chrome. It owns the two things no shipped
> work covers: (1) the `ui.lua` misnomer, and (2) the **settings-side** widget chrome still duplicated
> across `settings.lua` / `debug.lua` / `hunter/cliptracker.lua`.

---

## 1. Why

Two distinct, independent problems:

### 1a. `ui.lua` is misnamed

`src/aio/ui.lua` does exactly one thing: read `_G.Menagerie_SETTINGS_SCHEMA` and emit
`A.Data.ProfileUI[2]` — the **framework's built-in ProfileUI backing store**. Its own header already
says `-- Menagerie - ProfileUI Generator`. The name `ui.lua` implies it owns "the UI," but the actual
on-screen UI is `settings.lua` (custom tabbed panel) + `dashboard.lua` + the diagnostic panels.
`ui.lua` is the *schema→ProfileUI* adapter and nothing else. → rename to **`profileui.lua`**.

### 1b. UI *chrome* is hand-rolled 3× (the "reusable small parts" concern)

The genuinely-reusable, settings-flavored chrome is copy-pasted with cosmetic drift:

| Primitive | Copies | Evidence |
|-----------|--------|----------|
| Themed hover button (backdrop + accent-on-hover swap) | 3 | `debug.lua:115` `create_debug_button`, `hunter/cliptracker.lua:67` `create_theme_button`, `settings.lua` dropdown button inline |
| Thin backdrop table | ≥3 | `BACKDROP_THIN` (settings, cliptracker), `DBG_BACKDROP` (debug) — same edge/insets |
| Section header font-string | 2+ | `settings.lua:119` `create_section_header`, ad-hoc headers in panels |

> **Note (2026-06-15):** the old "per-class cold-blue `THEME` table" row is **resolved** — WS-9 landed,
> and `cliptracker.lua:52`, `meleeweave.lua:39`, `adaptivepanel.lua:28` are all `local THEME = NS.Theme`
> now. No theme-table drift remains; the three primitives above are the only live duplication.

This is the user's point: classes (and shared modules) re-implement the same little UI parts instead
of pulling from one library.

> **Scope honesty — what is NOT generically reusable.** The settings *widget builders*
> (`create_checkbox` `settings.lua:128`, `create_slider` :186, `create_slider_decimal` :271,
> `create_dropdown` :356) are **bound to settings**: they call `read_setting`/`write_setting`
> (→ `pActionDB`), `setup_scroll_forward`/`close_active_dropdown` (tab-scroll/popup state), and the
> `LAYOUT` constants. They are *settings* widgets, not free-floating ones. So the "library" here is the
> **chrome primitive layer** they (and the panels) consume — not a fully generic checkbox. This plan
> extracts the shared primitives and routes the settings builders through them; it does **not** attempt
> a risky dependency-injection rewrite of the settings builders themselves.

---

## 2. Design

### 2a. New module: `src/aio/widgets.lua`

A shared low-level UI primitive layer. **No** settings/schema/panel knowledge — pure chrome.

```lua
-- NS.Widgets (loaded after theme.lua, before debug/settings/panels)
NS.Widgets = {
  BACKDROP_THIN,                       -- the one canonical thin backdrop table (pre-allocated)
  themed_button(parent, opts),         -- opts = { width, height=22, text, font, theme }
                                       --   builds backdrop'd Button with accent-on-hover swap
  section_header(parent, text, opts),  -- themed FontString header; returns the fontstring
}
```

- **Theme source.** WS-9 already consolidated the palette: `NS.Theme` is the single canonical table
  and `NS.DBG_THEME` is just an alias of it (`debug.lua` sets `NS.DBG_THEME = NS.Theme`). So
  `themed_button`/`section_header` take an optional `theme` arg **defaulting to `NS.Theme`**; every
  consumer already passes a table that *is* `NS.Theme`, so the migration is byte-stable with no
  per-call hedging.
- **Pre-allocation.** `BACKDROP_THIN` is created once at load (respects the no-inline-tables-in-combat
  rule — though this is load-time UI, keep the discipline). It carries only edge/insets (no colors),
  so it needs no theme at its own load time; `themed_button` reads `theme.*` colors at call-time
  (consumers run at slot 5+), which is why `widgets.lua` can sit at order 1 without depending on
  `theme.lua` having loaded first.
- **Lua 5.1 / 200-local limit / single-lowercase-word filename** — all satisfied (`widgets.lua`).

### 2b. Load order

`widgets.lua` must load **before** its consumers (`debug.lua` slot 5, `livepanel.lua` slot 6,
`settings.lua` slot 7, panels slot 9). Slot it at **order 1** (shared, same slot as `theme`/`common`).
Add to `builder.config.json` `loadOrder`. Because `themed_button` reads theme colors only at call-time
(see §2a), order-1 placement alongside `theme`/`common` is safe even though they share the slot — no
load-time dependency on `theme.lua` executing first.

> WS-3's `livepanel.lua` is already live at order 6 and consumes `NS.CreateDebugButton` (see Step 3a) —
> it is downstream of `widgets`, not a load-order conflict.

### 2c. `ui.lua` → `profileui.lua`

Pure rename. **No behavior change.** Same slot (order 3), same `_G.Menagerie_SETTINGS_SCHEMA` →
`A.Data.ProfileUI[2]` contract.

---

## 3. Steps

### Step 1 — Rename `ui.lua` → `profileui.lua` (mechanical, do first, ships alone)

The full reference surface (don't miss the test file):

1. `git mv apps/tbc-rotation/src/aio/ui.lua apps/tbc-rotation/src/aio/profileui.lua`
2. `apps/tbc-rotation/builder.config.json:18` — `"source": "ui.lua"` → `"profileui.lua"` (keep `order: 3`).
3. `apps/tbc-rotation/test/lua-behavior.test.ts` — **3** `dofile("src/aio/ui.lua")` sites (lines ~295, ~1105, ~1141) → `profileui.lua`. **These break the test suite if missed.**
4. `apps/tbc-rotation/CLAUDE.md` (+ `AGENTS.md` symlink) — load-order table (slot 3 row) and the shared-modules table row `ui.lua` → `profileui.lua`.
5. **18×** `*/schema.lua` comment references — **two per class file** (druid/hunter/mage/paladin/priest/rogue/shaman/warlock/warrior):
   - line-3 `-- Must load before ui.lua, core.lua, and settings.lua` → `profileui.lua`
   - the "Used by" block line `--   1. aio/ui.lua: generates A.Data.ProfileUI[2] (framework backing store)` (≈line 19, warrior ≈line 23) → `aio/profileui.lua`.
   `grep -rn 'ui\.lua' src/aio/*/schema.lua` should return **zero** hits after this step.
6. Update the file's own header comment if desired (already says "ProfileUI Generator" — fine as-is).
7. **Cross-plan note (not a code edit):** `docs/plans/2026-06-15-schema-and-actions-impl.md` plans to
   implement the schema-tail auto-append *in `ui.lua`*. Leave a one-line note there pointing at the new
   name so whoever picks up WS-4 lands in `profileui.lua`. (Historical/dated audit docs that mention
   `ui.lua` are frozen records — do **not** rewrite them.)

**Verify:** `pnpm --filter @menagerie/tbc-rotation build` succeeds and
`pnpm --filter @menagerie/tbc-rotation test` (the lua-behavior suite) is green. Commit:
`refactor(app): rename ui.lua to profileui.lua`.

### Step 2 — Add `widgets.lua` with the chrome primitives (additive, no consumers yet)

1. Create `src/aio/widgets.lua`: `NS.Widgets.BACKDROP_THIN`, `themed_button`, `section_header`.
   Port the union of `create_debug_button` + `create_theme_button` behavior (width/height/font
   configurable; accent-on-hover border+bg swap; returns the button with `.label`).
2. Add to `builder.config.json` `loadOrder` (shared, order 1).
3. Add a shared-modules-table row in `apps/tbc-rotation/CLAUDE.md`.

**Verify:** build succeeds (module loads, defines `NS.Widgets`, no consumer yet). Commit:
`feat(app): add shared widgets chrome primitives`.

### Step 3 — Route consumers onto `NS.Widgets` (one consumer per commit, byte-stable visuals)

Do these **independently** so each is easy to eyeball-diff in-game:

- **3a `debug.lua` (+ transitive `livepanel.lua`)** — replace `create_debug_button` body with
  `NS.Widgets.themed_button`; drop the local `DBG_BACKDROP` in favor of `NS.Widgets.BACKDROP_THIN`.
  **Critical:** `debug.lua:137` exports `NS.CreateDebugButton = create_debug_button`, and
  `livepanel.lua` consumes it (`local CreateDebugButton = NS.CreateDebugButton` at :52, used at :360
  for Export and :371 for Clear). **Keep the `NS.CreateDebugButton` export** (re-point it at the
  widget-backed `create_debug_button`, or set `NS.CreateDebugButton = function(p,t,w) return
  NS.Widgets.themed_button(p, {text=t, width=w}) end`). Doing so migrates livepanel's buttons for
  free — verify the `/mdebug` / adaptive-panel Export+Clear buttons still render identically.
  (`DBG_THEME`/`NS.DBG_THEME` is now just an alias of `NS.Theme` post-WS-9 — no separate theme to
  preserve.)
- **3b `hunter/cliptracker.lua`** — replace `create_theme_button` + local `BACKDROP_THIN` likewise.
  (Per the audit, the cliptracker *detector* stays Hunter-specific; only its **chrome** moves.)
- **3c `settings.lua`** — point the dropdown button + `create_section_header` + `BACKDROP_THIN` at
  `NS.Widgets`. Leave `create_checkbox/slider/slider_decimal/dropdown` **in place** (settings-bound);
  they just consume the shared backdrop/header/button primitives for their chrome.

**Verify each:** build + visual check (`/menagerie`, `/mlog`, hunter cliptracker panel) — pixels
unchanged. Commits: `refactor(app): route <module> chrome through NS.Widgets`.

---

## 4. Dead code after Step 3

Removable once consumers migrate (list explicitly, remove with approval):
- `debug.lua`: `create_debug_button`, local `DBG_BACKDROP`.
- `hunter/cliptracker.lua`: `create_theme_button`, local `BACKDROP_THIN`.
- `settings.lua`: local `BACKDROP_THIN`, inline dropdown-button construction, `create_section_header`
  (if fully replaced).

## 5. Explicitly NOT in this plan (clean seams)

- **Live-panel chrome / `adaptivepanel.lua` migration** → **already shipped** as WS-3 (`livepanel.lua`
  / `NS.CreateLivePanel`, slot 6). This plan only unifies the *button/backdrop/header* primitives, not
  the panel windows — and it stays off `livepanel.lua` except for the transitive `NS.CreateDebugButton`
  re-point in Step 3a.
- **Theme-table unification** → **already shipped** as WS-9 (`NS.Theme` is canonical). Nothing left to do.
- **Copy/export window** → **already shipped** as WS-1 (`NS.ShowCopyWindow`, `debug.lua:229`).
- **Generalizing the adaptive decision engine** (recalculatable-values "any class can be adaptive")
  → out of scope per owner decision; the audit deferred it as ~irreducible Hunter math. If revisited,
  it's a *separate design doc*, not this one.
- **Full dependency-injection rewrite of the settings widget builders** → not worth the risk; they
  have exactly one consumer (the settings panel).

## 6. Sequencing

Step 1 (rename) is independent and ships first/alone. Steps 2–3 are a second small PR. Both are
parallel-safe with the hardening workstreams; only soft coupling is the theme-table choice (§2a) which
should match WS-9.

## 7. Open question for the human

- **`widgets.lua` vs. folding into `common.lua`:** `common.lua` is "first-slot low-level helpers."
  A dedicated `widgets.lua` keeps UI primitives discoverable and separate from non-UI helpers
  (recommended). Confirm before Step 2, or say "fold into common."
