# Platform Audit 03 — Memory Leaks & Hot-Path Performance

Read-only audit of `apps/tbc-rotation/src/aio/`. Focus: unbounded table growth,
per-frame allocations in the rotation dispatch, OnUpdate waste, CLEU handler cost,
and redundant recompute. Lua 5.1 / WoW secure env; the rotation dispatcher (`A[3]`)
runs every frame.

## Severity-ranked summary

| # | Severity | Where | Problem | Type |
|---|----------|-------|---------|------|
| 1 | **High** | `hunter/adaptive.lua:900` + `logDecision` 499-564 | ~45-field decision-log table allocated every time the shot choice changes (or every 0.2s), **even when the panel is closed and no export is requested**. Sustained GC churn for the whole fight; ring buffer holds 900 entries. | per-frame alloc / GC churn |
| 2 | **Med** | `core.lua:334` `learned_immune` | Inner spell entries are lazily pruned, but the per-npcID **bucket table is never removed** when it empties. One small table leaks per unique creature template encountered, forever (until `/reload`). | slow leak |
| 3 | **Med** | `hunter/cliptracker.lua:629-633` | `ClipLog` grows to `ClipLogMax = 5000` entries (each a ~16-field table) and trims via `table.remove(…, 1)` — an O(n) shift on every insert past the cap. At 5000 cap that is a 5000-element memmove per clip in sustained combat. | per-event CPU + memory footprint |
| 4 | **Low** | `core.lua:386` immune CLEU + `cliptracker.lua:763` + `adaptive.lua:731` | Three independent `COMBAT_LOG_EVENT_UNFILTERED` handlers each call `CombatLogGetCurrentEventInfo()` on **every** combat-log event before filtering. Unavoidable cost is the unpack; ordering of cheap guards is mostly fine. cliptracker/adaptive run their unpack even when their feature/combat is irrelevant. | CLEU CPU |
| 5 | **Low** | `debugpanel.lua:346` | `update_frame` OnUpdate accumulates + calls `refresh_panel()` every 0.1s **always** (even when panel hidden). `refresh_panel` early-outs cheaply, so cost is negligible, but the timer runs unconditionally. | OnUpdate (benign) |
| 6 | **Low** | `core.lua:1257` `try_cast_fmt` / heal variants | `format()` builds the log string on the **success path only**, but the format also runs when `debug` is off (the message is returned regardless and discarded by the caller). Minor per-cast string alloc, not per-frame. | minor alloc |

No issues found in: `main.lua` `create_context` (correctly reuses one table, zero literals), dashboard OnUpdate handlers (all correctly gated on `dashboard_frame:IsShown()`), `debug_print` throttle cache (correctly TTL-pruned), `debug_log_lines` (bounded at 500), `should_auto_burst` / `is_force_active` (scalar reads only).

---

## Detailed findings

### 1. HIGH — Adaptive decision-log allocates every frame regardless of UI state

`hunter/adaptive.lua`

`ChooseAction` (line 756) runs every frame the Hunter rotation ticks in combat.
Its last step before returning is:

```lua
-- adaptive.lua:900
logDecision(unit, d, shootAt, shootDoneAt)
```

`logDecision` (499-564) throttles only on *identical consecutive choices within
0.20s*:

```lua
if d.chosenOpt == State.lastDecisionLogChoice and (now - (State.lastDecisionLogAt or 0)) < 0.20 then
    return
end
...
table.insert(State.decisionLog, {  -- ~45 fields, fresh table every call
    timestamp = timestamp(), rawTime = now, chooseDelta = ..., -- 45 keys
})
while #State.decisionLog > State.decisionLogMax do   -- decisionLogMax = 900
    table.remove(State.decisionLog, 1)               -- O(n) shift once at cap
end
```

**Why it's a problem.** The shot choice flip-flops constantly (shoot ↔ steady ↔
multi ↔ arcane) during a normal rotation, so the 0.20s same-choice guard rarely
suppresses anything — in practice you allocate a ~45-field table several times per
second for the entire fight. `State.decisionLog` and the `decisionLogMax = 900` ring
exist **only** to feed the Export button on `adaptivepanel.lua` and the CSV dump.
There is no gate on `show_adaptive_panel` or any "record decisions" setting — it runs
for every Hunter, always. Once the buffer hits 900, every further insert also does a
`table.remove(t, 1)` (900-element memmove).

This is the single largest sustained allocation source in combat for Hunters and is
pure GC pressure on a frame-rate-sensitive path.

**Fix.** Gate the logging on demand. Cheapest correct fix:

```lua
-- only record when the diagnostic panel is actually visible
if NS.cached_settings and NS.cached_settings.show_adaptive_panel then
    logDecision(unit, d, shootAt, shootDoneAt)
end
```

(Or add a dedicated `record_decision_log` setting.) The live panel reads
`State.lastDecision` (the pre-allocated `d` table, already updated in place at
870-899) for its per-tick display — that path is allocation-free and unaffected. Only
the *history* (`decisionLog`) needs gating. Also consider lowering `decisionLogMax`
and/or switching the ring to an index-wrap buffer to kill the O(n) `table.remove`.

---

### 2. MED — `learned_immune` buckets never evicted (slow leak)

`core.lua:334`

```lua
local learned_immune = {} -- [npcID] = { [spellID] = expiry }
```

`mark_spell_immune` (343) creates a bucket per npcID on first immune hit.
`is_spell_immune` (355) lazily prunes **expired spell entries inside** a bucket:

```lua
if expiry then
    if now < expiry then return true end
    bucket[id] = nil -- lazy prune
end
```

But nothing ever removes the **bucket table itself** when its last spell entry
expires. So `learned_immune` accumulates one (eventually-empty) sub-table per unique
creature template the player has ever cast an immune-missed spell at, for the life of
the session.

**Worst-case size.** Bounded by the number of distinct npcIDs you land an immune
`SPELL_MISSED` on — realistically dozens to low hundreds over a long session, each an
empty/near-empty table. **Small in absolute terms** (this is why it's Med, not High):
keyed by creature template, not GUID, and the TTL keeps the *contents* tiny. It is a
genuine never-shrinks-without-`/reload` leak, but the per-entry footprint is a few
words. The AGENTS.md comment claims "memory stays tiny" — true for entry *count*, but
the table never actually shrinks.

**Fix.** When the loop that prunes a bucket leaves it empty, drop the bucket:

```lua
-- after pruning inside is_spell_immune, if the bucket is now empty:
if next(bucket) == nil then learned_immune[npc_id] = nil end
```

Cheapest place is in the array-rank branch and the scalar branch of
`is_spell_immune` after a lazy prune. Low effort, removes the leak entirely.

---

### 3. MED — ClipLog O(n) trim and 5000-entry footprint

`hunter/cliptracker.lua:611-633`

```lua
table.insert(self.ClipLog, entry)        -- ~16-field table per clip
...
while #self.ClipLog > self.ClipLogMax do -- ClipLogMax = 5000
    table.remove(self.ClipLog, 1)        -- O(n) shift of up to 5000 elements
end
```

**Why it's a problem.** Two issues: (a) the cap is **5000** entries — at ~16 fields
each that is a sizeable resident buffer purely for the clip-tracker UI/CSV; (b) once
at cap, every new clip does `table.remove(t, 1)`, a full 5000-element memmove. Clips
only fire on auto-shot intervals (sub-second cadence in heavy haste), not every frame,
so this is per-event rather than per-frame — but the trim cost is high and the buffer
large. This entire path is also gated on `clip_tracker_enabled` (good — disabled
hunters pay nothing), and the UI refresh is gated on `Frame:IsShown()` (also good).

**Fix.** Either drop `ClipLogMax` to something UI-reasonable (a few hundred), or use a
ring/wrap index instead of `table.remove(t, 1)`. The `RefreshLogDisplay` (1068) already
rebuilds a `lines` table from scratch each call, so a wrap buffer is compatible.

---

### 4. LOW — Three CLEU handlers, each unpacks every combat-log event

- `core.lua:386` (immunity learner) — `CombatLogGetCurrentEventInfo()` then filters
  `event ~= "SPELL_MISSED" or missType ~= "IMMUNE"`. The expensive part (a second
  `UnitGUID` comparison, `has_total_immunity`) only runs after the cheap event filter.
  This one is well-ordered.
- `cliptracker.lua:763` `OnCLEU` — calls `IsEnabled()` (cheap settings read) first and
  returns if disabled. When enabled, unpacks 13 returns of
  `CombatLogGetCurrentEventInfo()` on *every* event, then `pGUID` source check. Fine.
- `adaptive.lua:731` `OnCLEU_AdaptiveFire` — unpacks **first**, then filters
  `subevent ~= "SPELL_CAST_SUCCESS"`. Always running; no enable gate.

**Why it's Low.** CLEU fires a lot in raids, but each handler's post-unpack work is a
couple of string compares and a GUID check — cheap. The unavoidable cost is the
`CombatLogGetCurrentEventInfo()` call itself (returns are not allocated as a table in
this API, they're multiple returns), so there is no per-event table allocation here.

**Optional fix.** Reorder `adaptive.lua:731` to check `subevent` before doing further
work (it already does — only the unpack precedes it, which is required to read
subevent). Marginal. The real lever, if CLEU cost ever shows up in a profile, is to
register on narrower events where the API allows, but TBC's CLEU is a single
unfiltered event, so this is mostly inherent.

---

### 5. LOW — debugpanel update_frame ticks every 0.1s even when hidden

`debugpanel.lua:344-352`

```lua
update_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= UPDATE_INTERVAL then   -- 0.1s
        self.elapsed = 0
        refresh_panel()
    end
end)
```

`refresh_panel` (280) early-outs immediately if the panel isn't shown
(`if not (panel_frame and panel_frame:IsShown()) then return end`), so the per-tick
cost when hidden is one add, one compare, and a function call every 0.1s — negligible.
Listed only for completeness; **not worth changing**. (The sibling `watch_frame` at
0.5s is correctly minimal.)

---

### 6. LOW — try_cast_fmt builds format string on success even when debug off

`core.lua:1257-1268` (and `try_heal_cast_fmt`, plus inline `format(...)` log messages
in `create_combat_strategy` 1569 and the recovery/trinket middleware).

The strategy/middleware `execute` functions return `result, log_msg`, and `log_msg` is
built with `format()` on the **cast-success path**. `main.lua`'s
`execute_strategies`/`execute_middleware` only *consume* that message when
`debug_mode`/`debug_system` is on (96-122, 178-189) — but the `format()` already ran
inside `execute` before the return, regardless of the debug flag.

**Why it's Low.** This only happens on the frame a spell actually fires (once per
GCD-ish), not every frame, and only one string per cast. Real but tiny.

**Fix (optional).** Pass the format args through and let the dispatcher build the
string only when it will log. This is a larger refactor of the `try_*_fmt` contract
for marginal gain — defer unless profiling flags it.

---

## What was checked and is clean

- **`main.lua` `create_context` (205-259):** reuses a single module-level
  `reusable_context`, wipes it with `for k in pairs(ctx) do ctx[k]=nil end`, and writes
  scalar fields. No `{}` literals, no `format`, no closures per frame. Correct.
- **Dispatch loop (`execute_middleware`/`execute_strategies`):** `ipairs` over
  pre-sorted registry arrays (not fresh tables); the per-entry `format`/`gsub` only run
  inside `if debug_mode/debug_system` guards. Correct.
- **`debug_print` throttle cache (`core.lua:1092-1119`):** TTL-pruned every 30s
  (`DEBUG_CACHE_PRUNE_INTERVAL`), entries expire at 60s. Bounded. Correct.
- **`debug_log_lines`:** bounded at `MAX_LOG_LINES = 500` via `trim_debug_log`. Correct.
- **Dashboard `fr_frame` (per-frame OnUpdate, `dashboard.lua:1405`):** early-outs on
  `not dashboard_frame:IsShown()`. Correct.
- **`validate_playstyle_spells` (`core.lua:1434`):** cached on
  `last_validated_playstyle`; only recomputes on playstyle change. Correct.
- **Adaptive recompute (`adaptive.lua:767`):** lazy — only on `dirty`/scheduled, driven
  by `UNIT_AURA` marking dirty. Per-tick is ~float ops, as documented. Correct.
