# WS-1 Quick Wins — Implementation Plan (ARCHIVED)

> **⚠️ ARCHIVED 2026-06-15 — superseded by `2026-06-15-quickwins-impl.md`.**
> Kept for the record. This version proposed ring-buffer conversions for `decisionLog`,
> `fireHistory`, and `ClipLog`. On review those rings were judged not worth their complexity: once
> the `logDecision` gate (Step 1.1) lands, the O(n) `table.remove(t,1)` trims only run on cold paths
> (panel open, or tiny caps), while the rings add wrap-ordering risk across every export reader. The
> active plan keeps the gate, the empty-bucket prune, and the `ShowCopyWindow` singleton, and
> replaces the `ClipLog` ring with a simple cap reduction. See "Why the rings were dropped" in the
> active plan for the full rationale.
>
> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md` §4.1.
> **Evidence:** `2026-06-14-platform-audit/03-performance.md` (#1/#2/#3), `02-diagnostics.md` (B).
> **Status:** Not started (verified 2026-06-15). **Risk:** Trivial. **Ships as:** one small PR.
>
> Three independent fixes bundled because none needs design debate. The only ordering constraint is
> that `NS.ShowCopyWindow` (step 2) must land before the WS-3 live-panel work consumes it.

## Goal

Stop the largest sustained per-frame GC source (the Hunter decision log), collapse the two
copy/paste export windows into one shared modal, and close two small unbounded-growth leaks.

---

## Step 1 — Perf guard: gate `logDecision`, fix O(n) ring trims (perf #1, HIGH)

**Files:** `apps/tbc-rotation/src/aio/hunter/adaptive.lua`

1.1 **Gate the log append on the panel setting.** `logDecision(...)` is called unconditionally at
`adaptive.lua:900`, allocating a ~45-field table several times/second for the whole fight even when
its only consumer (`show_adaptive_panel`) is off. The live panel reads the *separate* pre-allocated
`lastDecision` table, so live readout is unaffected — only the exportable history stops accruing when
the panel is closed, which is the intended semantics.

Wrap the call site:
```lua
if NS.cached_settings and NS.cached_settings.show_adaptive_panel then
   logDecision(...)
end
```
Prefer guarding at the **call site** (line 900) over inside `logDecision` so the argument expressions
also short-circuit. If `logDecision` is invoked from more than one site, instead early-return at the
top of the function body and accept the (cheap) arg evaluation.

1.2 **Replace the at-cap `table.remove(t, 1)` O(n) shift with a ring index.** `adaptive.lua:561–562`
does `while #State.decisionLog > State.decisionLogMax do table.remove(State.decisionLog, 1) end` —
each removal shifts the whole array. Convert `decisionLog` to a ring: keep a write pointer
`decisionLogHead` bumped `(head % max) + 1` per insert; overwrite in place; readers (the export CSV
builder + panel) iterate from `head` wrapping around. The CSV/export reader must be updated to read in
ring order.

1.3 **Same ring fix for `fireHistory`** at `adaptive.lua:714–715` (`fireHistoryMax = 20`). Low
severity (small cap) but identical pattern — do it in the same pass for consistency, or note it as
explicitly skipped.

**Verification:** open the adaptive panel, run a sim/dummy fight, confirm the decision log still
populates and exports correctly; close the panel and confirm (via `/mlog` or a temporary counter) that
`logDecision` no longer fires. `pnpm --filter @menagerie/tbc-rotation build` must succeed.

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

**Verification:** click Export on both the clip tracker and the adaptive panel; confirm the modal opens
with text pre-selected and Ctrl-C copies. Confirm only one frame is created (open both — same frame
reused).

> This is a dependency for WS-3: `CreateLivePanel`'s Export button calls `NS.ShowCopyWindow`. Land it here.

---

## Step 3 — Leak prunes (perf #2/#3, MED/LOW)

3.1 **`learned_immune` empty-bucket prune.** `core.lua:366` and `:374` clear expired *spell* entries
(`bucket[id] = nil`) but never the now-empty *bucket*, so one tiny table leaks per creature template
per session. After each prune, add:
```lua
if next(bucket) == nil then learned_immune[npc_id] = nil end
```
Apply in both the array branch (~366) and scalar branch (~374).

3.2 **`ClipLog` cap/wrap.** `cliptracker.lua:623–624` trims a 5000-cap log via `table.remove(self.ClipLog, 1)`
per insert at cap (O(n) each). Either lower `ClipLogMax` (`cliptracker.lua:124`) to a UI-reasonable bound
(a few hundred) or convert to a ring index. `RefreshLogDisplay` (`cliptracker.lua:~1064`) iterates the
whole table, so a ring index is compatible — match whatever step 1.2 establishes.

**Verification:** static — confirm prune lines present; the leak is too slow to observe in a short test.

---

## Out of scope / risks

- No rotation-behavior change anywhere in this PR. The `logDecision` gate changes only *when history
  accrues*, not what the rotation does.
- Ring conversions must preserve export ordering — the only behavioral surface. Verify exports
  byte-compare sanely before/after on a captured fight.
