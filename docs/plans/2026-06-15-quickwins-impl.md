# WS-1 Quick Wins — Implementation Plan (trimmed)

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md` §4.1.
> **Evidence:** `2026-06-14-platform-audit/03-performance.md` (#1/#2/#3), `02-diagnostics.md` (B).
> **Status:** Not started (verified 2026-06-15). **Risk:** Trivial. **Ships as:** one small PR.
> **Supersedes:** `2026-06-15-quickwins-impl-archive.md` (ring-buffer version — see "Why the rings
> were dropped" below).
>
> Four independent fixes bundled because none needs design debate. The only ordering constraint is
> that `NS.ShowCopyWindow` (Step 2) must land before the WS-3 live-panel work consumes it.

## Goal

Stop the largest sustained per-frame GC source (the Hunter decision log), collapse the two
copy/paste export windows into one shared modal, and close two small unbounded-growth leaks — using
the **lowest-risk** mechanism for each (a gate, a cap, a one-line prune), not data-structure rewrites.

---

## Step 1 — Perf guard: gate `logDecision` (perf #1, HIGH)

**File:** `apps/tbc-rotation/src/aio/hunter/adaptive.lua`

`logDecision(...)` is called unconditionally at `adaptive.lua:900`. After its internal throttle
(`adaptive.lua:501–503`, ≥0.20s + choice-change) it allocates a ~45-field table (`adaptive.lua:514`)
several times/second for the whole fight — even when its only consumer (`show_adaptive_panel`) is
off. That allocation is the sustained GC pressure.

**This is safe because live readout does not depend on it.** The live panel reads
`State.lastDecision` (`adaptive.lua:192`), a *single pre-allocated* table updated in place every tick
at `adaptive.lua:871–899`. `logDecision` is the *separate* history-append path. Gating it only stops
the exportable history from accruing while the panel is closed — the intended semantics.

Wrap the **call site** (line 900) so the argument expressions short-circuit too:
```lua
if NS.cached_settings and NS.cached_settings.show_adaptive_panel then
   logDecision(unit, d, shootAt, shootDoneAt)
end
```
`logDecision` has exactly one call site (verified), so the call-site guard is sufficient — no
early-return needed inside the function body.

**Semantics note:** combined with the existing throttle, the gate means the log only accrues *while
the panel is open* — there is no pre-open backfill. Opening the panel mid-fight starts the exportable
history from that moment, not from pull. This is intended (the live readout via `lastDecision` is
always current); just don't expect a full-fight export from a panel opened late. The panel's
row-count display (`adaptivepanel.lua:364`) is unaffected: it only renders inside `Panel:Refresh()`,
which the panel's `OnUpdate` calls *only when* `show_adaptive_panel` is true — the same boolean as the
gate, so the counter and the logging stay in lockstep (no stale/frozen count).

> Leave the existing `while #State.decisionLog > State.decisionLogMax do table.remove(..., 1) end`
> trim (`adaptive.lua:561–563`) **as-is.** With this gate, that O(n) shift only runs while the panel
> is open, throttled to ~5/sec, and is dwarfed by the 45-field allocation right beside it. Not worth
> a ring. Same reasoning retires the `fireHistory` ring (cap 20, negligible). See below.

**Verification:** open the adaptive panel, run a sim/dummy fight, confirm the decision log still
populates and exports correctly; close the panel and confirm (via `/mlog` or a temporary counter)
that `logDecision` no longer fires. `pnpm --filter @menagerie/tbc-rotation build` must succeed.

---

## Step 2 — `NS.ShowCopyWindow(title, text)` singleton (diag B)

**Files:** `apps/tbc-rotation/src/aio/debug.lua` (new helper, next to `NS.CreateDebugWindow`);
call sites `hunter/cliptracker.lua:~1172` (`ShowExportWindow`) and
`hunter/adaptivepanel.lua:~367` (`ShowDecisionExport`).

2.1 Add one lazily-created shared modal built on `NS.CreateDebugWindow`:
```lua
-- Lazily creates a single shared copy/export modal. Both class export buttons funnel here.
function NS.ShowCopyWindow(title, text)
   -- create-once: frame + scroll + multiline EditBox (reuse NS.CreateDebugWindow chrome)
   -- per-call: SetText(text), set title, HighlightText(), SetFocus(), Show()
end
```
Reuse the warm theme/backdrop already exported by `debug.lua` (`NS.DBG_THEME` / `NS.DBG_BACKDROP`).
Singleton — one frame, no per-call allocation.

2.2 Replace both call sites with one line each: `NS.ShowCopyWindow("Adaptive Decisions", csv)` /
`NS.ShowCopyWindow("Clip Log", text)`. Delete the two bespoke ~50-line frame-construction blocks and
their global-named frames (`HunterClipTrackerExportFrame`, `HunterAdaptiveDecisionExportFrame`).

**Verification:** click Export on both the clip tracker and the adaptive panel; confirm the modal
opens with text pre-selected and Ctrl-C copies. Confirm only one frame is created (open both — same
frame reused).

> Dependency for WS-3: `CreateLivePanel`'s Export button calls `NS.ShowCopyWindow`. Land it here.

---

## Step 3 — Leak prunes (perf #2/#3, MED/LOW)

### 3.1 `learned_immune` empty-bucket prune (`core.lua`)

`is_spell_immune` (`core.lua:354`) lazily clears expired *spell* entries (`bucket[id] = nil` at
`core.lua:366` and `:374`) but never the now-empty *bucket*, so one tiny table leaks per creature
template per session.

- **Scalar branch:** after `bucket[spell_ids] = nil` (`core.lua:374`), before the `return false` at
  `:375`, add:
  ```lua
  if next(bucket) == nil then learned_immune[npc_id] = nil end
  ```
- **Array branch:** the prune at `core.lua:366` happens **mid-loop** — do *not* check emptiness
  there. Add the same `if next(bucket) == nil then learned_immune[npc_id] = nil end` **after the
  loop**, immediately before `return false` at `core.lua:369`.

### 3.2 `ClipLog` — lower the cap (not a ring)

`cliptracker.lua:623–624` trims a **5000**-cap log via `table.remove(self.ClipLog, 1)` per insert at
cap (O(n) each). Rather than convert to a ring (which would force wrap-aware rewrites of
`RefreshLogDisplay` at `cliptracker.lua:1064` and `:1113`, plus the `deepcopy` export at `:1340`),
**lower `ClipLogMax`** (`cliptracker.lua:124`) from `5000` to a UI-reasonable bound — **500**. The
trim stays `table.remove(t, 1)` but now shifts ≤500 references at ~1/sec: negligible, and every
reader keeps working unchanged (plain `ipairs`, correct chronological order, no partial-fill edge
case).

**Verification:** static — confirm the two prune lines are present and `ClipLogMax = 500`; the
`learned_immune` leak is too slow to observe in a short test. Confirm the clip-log UI and its export
still render in order after the cap change.

---

## Why the rings were dropped (vs. the archived plan)

The archived version proposed ring-index conversions for `decisionLog`, `fireHistory`, and `ClipLog`
to avoid O(n) `table.remove(t, 1)`. They were cut because the cost they remove is, in practice, not
on a hot path:

| Buffer | Cap | When the O(n) trim actually runs | Decision |
|---|---|---|---|
| `decisionLog` | 900 | Only while the adaptive panel is **open** (after Step 1's gate), throttled ~5/sec — beside a 45-field alloc that dominates it | Keep `table.remove`; gate is the real win |
| `fireHistory` | 20 | Per shot fired; ~20 pointer-moves | Keep `table.remove`; negligible |
| `ClipLog` | 5000→500 | Per clip (~1/sec) | Lower the cap; ≤500 moves, no reader churn |

A ring that overwrites in place keeps `#t == max` but puts the oldest entry at `head`, not index 1.
Every `ipairs` export reader (`decisionCSV` at `adaptive.lua:620`, `RefreshLogDisplay`, the
`deepcopy` export) would need wrap-aware iteration, `clear*` would need to reset `head`, and the
partial-fill phase (before first reaching cap) is the classic ring bug. That's real ordering risk on
the one behavioral surface (export output) to optimize a path that, post-gate, barely runs. Net
negative. If a `decisionLog` ring is ever wanted, it should be its own change with a before/after
byte-compare of an exported CSV on a captured fight.

---

## Out of scope / risks

- **No rotation-behavior change anywhere in this PR.** The `logDecision` gate changes only *when*
  history accrues, not what the rotation does.
- The `ClipLog` cap reduction is the only change with a visible surface (fewer historical clip rows
  retained in the UI). 500 is well above any practical inspection window; confirm the export still
  reads sanely after the change.
