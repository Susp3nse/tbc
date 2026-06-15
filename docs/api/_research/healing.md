# Healing Engine — Verified API Reference

Source of truth: `/Users/traveler/Repos/tbc/docs/action/Modules/Engines/HealingEngine.lua` (1596 lines).
Stub cross-checked: `HealingEngine` class in `/Users/traveler/Repos/tbc/docs/api/Globals.lua` (lines 130-134).

Exposure pattern:
```lua
A.HealingEngine = { Data = Data }      -- only key seeded at creation
local HealingEngine = A.HealingEngine
function HealingEngine.X(...) ... end   -- all public functions added afterward
```
So the public surface is `A.HealingEngine` = `{ Data = <Data table>, <26 functions> }`.

The engine only runs when toggle `GetToggle(8, "HealingEngineAPI")` is enabled (gates `Initialize`).

---

## 1. Functions (26 public `HealingEngine.X`)

Notes on types: `unitID` = WoW unit token string ("player", "raid1", "focus", ...). `GUID` = WoW GUID string. "thisUnit"/member = a unit-data table from `Data.UnitIDs` (see §2).

| # | Function (real signature) | Params (type — meaning, default) | Returns | What it actually does | Cache wrapper |
|---|---|---|---|---|---|
| 1 | `SortMembers()` | none | nil | Manually re-sorts `SortedUnitIDs_MostlyIncDMG` by `incDMG` desc, and `SortedUnitIDs` by HP (asc) or AHP (asc) depending on `db.SelectSortMethod == "HP"`. No-op if `#SortedUnitIDs <= 1`. | — |
| 2 | `SetTargetMostlyIncDMG(delay)` | `delay` (number, optional — seconds to lock target; default `0.5`) | nil | Forces the healing target to the most-damaged unit (`SortedUnitIDs_MostlyIncDMG[1]`); sets `healingTargetDelay = TMW.time + delay`, updates color frame. No-op if list empty. | — |
| 3 | `SetTarget(unitID, delay)` | `unitID` (string — unit to force as heal target); `delay` (number, optional — lock seconds; default `0.5`) | nil | Resolves `unitID`→GUID→canonical group unitID and sets it as healing target (color frame + delay) if found and not already set. | — |
| 4 | `GetMembersAll()` | none | table | Returns the live `SortedUnitIDs` array (all selectable members, sorted). Reference, not a copy. | — |
| 5 | `GetBuffsCount(ID, duration, source, byID)` | `ID` (number/string — aura id/name); `duration` (number, optional — min remaining secs, default `0`); `source` (optional — caster filter); `byID` (boolean, optional — match by id) | number | Count of **player** members (`isPlayer`) in `SortedUnitIDs` having buff `ID` with remaining > `duration`. | — |
| 6 | `GetDeBuffsCount(ID, duration, source, byID)` | same as #5 | number | Count of **player** members having the debuff `ID` with remaining > `duration`. | — |
| 7 | `GetHealth()` | none | number, number | `[1]` current group actual HP, `[2]` group max HP (latest `Frequency.Actual` record). Returns `huge, huge` if no record. | — |
| 8 | `GetHealthAVG()` | none | number | Group health percent (0-100). Returns `100` if no frequency record. | — |
| 9 | `GetHealthFrequency(timer)` | `timer` (number — lookback window secs, **max 10**, errors if >10) | number | Group HP% delta over the last `timer` seconds. Positive = gain, negative = loss, 0 = unchanged. | **`MakeFunctionCachedDynamic`** (line 1223) |
| 10 | `GetIncomingDMG()` | none | number, number | `[1]` total group incoming DMG/s (sum of member `incDMG`), `[2]` per-unit average. | **`MakeFunctionCachedStatic`** (line 1242) |
| 11 | `GetIncomingHPS()` | none | number, number | `[1]` total group incoming heal/s (sum of `A.Unit():GetHEAL()`), `[2]` per-unit average. | **`MakeFunctionCachedStatic`** (line 1261) |
| 12 | `GetIncomingDMGAVG()` | none | number | Group incoming-DMG as % of group max HP per second. `0` if no record. | — |
| 13 | `GetIncomingHPSAVG()` | none | number | Group incoming-HPS as % of group max HP per second. `0` if no record. | — |
| 14 | `GetTimeToFullDie()` | none | number | Average member `TimeToDie()` across `SortedUnitIDs`. Returns `huge` if total is 0. | — |
| 15 | `GetTimeToDieUnits(timer)` | `timer` (number — TTD threshold secs) | number | Count of members whose `TimeToDie() <= timer`. | — |
| 16 | `GetTimeToDieMagicUnits(timer)` | `timer` (number — magic TTD threshold) | number | Count of members whose `TimeToDieMagic() <= timer`. | — |
| 17 | `GetTimeToFullHealth()` | none | number | Group time-to-max-HP = `(MHP - AHP) / GetIncomingHPS()`. `0` if no record or HPS <= 0. | — |
| 18 | `GetMinimumUnits(fullPartyMinus, raidLimit)` | `fullPartyMinus` (number, optional — subtract from small-group counts, default `0`); `raidLimit` (number, optional — cap for >5 groups, default = all members) | number | Heuristic minimum unit count worth AoE-healing given current group size. See body for the `<=1 / <=3 / <=5 / >5` ladder. | — |
| 19 | `GetBelowHealthPercentUnits(hp, range)` | `hp` (number — HP% threshold); `range` (number, optional — only count units passing `CanInterract(range)`) | number | Count of members with `realHP <= hp` (optionally range-gated). **Alias:** `GetBelowHealthPercentercentUnits` (typo, line 1394) points to same fn. | — |
| 20 | `HealingByRange(range, object, inParty, isMelee)` | `range` (number — range to check `CanInterract`); `object` (spell object — must expose `:PredictHeal`); `inParty` (boolean, optional — only party members); `isMelee` (boolean, optional — only melee) | number | Count of members healable at `range` that pass `object:PredictHeal(unit,nil,GUID)`. (Doc `@usage` line is stale — real params are `range, object, inParty, isMelee`.) | — |
| 21 | `HealingBySpell(object, inParty, isMelee)` | `object` (spell object — `:IsInRange` + `:PredictHeal`); `inParty` (boolean, optional); `isMelee` (boolean, optional) | number | Count of members healable by `object` (uses `object:IsInRange` instead of a numeric range). | — |
| 22 | `GetOptionsByUnitID(unitID, unitGUID)` | `unitID` (string); `unitGUID` (string, optional — skips a `UnitGUID()` call) | boolean, boolean, boolean, boolean, table | DB (un-modified) per-unit options: `useDispel, useShields, useHoTs, useUtils, dbUnit`. Resolves focus first (TBC+), else group member. Fallback for non-group: `isPlayer, true, true, isPlayer, emptyTable, emptyTable` (note 6 values on fallback — extra trailing `emptyTable`). Do not mutate returned table. | — |
| 23 | `IsMostlyIncDMG(unitID)` | `unitID` (string) | boolean, number | `[1]` true if `unitID` is the most-injured unit (`SortedUnitIDs_MostlyIncDMG[1]`); `[2]` that unit's `incDMG`. Returns `false, 0` otherwise. | — |
| 24 | `GetTarget()` | none | string, string | Current `healingTarget` (unitID) and `healingTargetGUID`. Both default to `"none"`. | — |
| 25 | `GetBossHealth()` | none | number×5 | `[1]` avg cur HP, `[2]` avg max HP, `[3]` total cur HP, `[4]` total max HP, `[5]` boss count. All `0` if no bosses tracked. | — |
| 26 | `GetBossHealthPercent()` | none | number | Average boss HP% (`0` if none). | — |
| 27 | `GetBossTimeToDie()` | none | number×3 | `[1]` avg TTD, `[2]` total TTD, `[3]` boss count. `0,0,0` if none. | — |
| 28 | `GetBossMain()` | none | string, string, number \| nil | Boss with most holders: `[1]` unitID, `[2]` GUID, `[3]` focus count (how many holders target it). All nil if none. | — |
| 29 | `IsManaSave(unitID)` | `unitID` (string, optional — stop-condition unit) | boolean / nil | True when mana-management says conserve: `db.ManaManagementManaBoss >= 0`, boss HP > 0, `manaP <= bossHP`, `manaP <= ManaManagementManaBoss`, no Innervate; if `unitID` given it must be above `ManaManagementStopAtHP` and TTD above `ManaManagementStopAtTTD`. Returns nil (falsy) otherwise. | — |

Function count: **29 public functions** (table is 1-indexed beyond 26 because boss/mana controllers were appended; the literal count of distinct `function HealingEngine.X` definitions is **29**, plus 1 alias `GetBelowHealthPercentercentUnits`).

> Correction to my own header: there are **29** public `HealingEngine.*` functions + 1 typo alias. (Earlier "26" in the section title is wrong — use 29.)

### Internal (NOT public — local functions, do not document as API)
`PerformByProfileHP`, `OnUpdate`, `ClearHealingTarget`, `SetHealingTarget`, `SetColorTarget`, `UpdateTargetLOS`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `UNIT_TARGET`, `Initialize`, and the per-unit metamethods (`CanSelect`, `CanRessurect`, `SetupOffsets`, `Setup`, `HasLua`, `RunLua`). The metamethods are reachable from a member table but are infrastructure, not the `HealingEngine.*` surface.

---

## 2. Member / Unit data model (`thisUnit`)

Each entry of `Data.UnitIDs[unitID]` is a table populated by the `:Setup(unitID, unitGUID[, isPlayer])` metamethod (lines 542-662). Fields:

| Field | Type | Meaning |
|---|---|---|
| `Unit` | string | The unit token (unitID). |
| `GUID` | string | Unit GUID. |
| `HP` | number 0-100 | **Modified** health percent — base realHP plus incoming heals/absorbs, then adjusted by threat/pet multipliers and role offsets. This is the value the sort/target logic uses. |
| `AHP` | number 0-huge | **Modified** actual health = `HP * MHP / 100` (computed after the update callback fires). |
| `MHP` | number 0-huge | Maximum actual health (`A.Unit():HealthMax()`). |
| `realHP` | number 0-100 | True current health percent (`100 * realAHP / MHP`; 0 if MHP==0). |
| `realAHP` | number 0-huge | True current actual health (`A.Unit():Health()`). |
| `Role` | string | `"TANK"`, `"HEALER"`, `"DAMAGER"`, or `"NONE"`. `"AUTO"` in DB is resolved at Setup (pets→`"DAMAGER"`, players→`A.Unit():Role()`). Pets are `"DAMAGER"`. |
| `LUA` | string | Per-unit custom Lua condition (empty string = none). |
| `Enabled` | boolean | Whether the unit is eligible for `SetHealingTarget`. From DB. |
| `useDispel` | boolean | DB toggle — dispel allowed on this unit. |
| `useShields` | boolean | DB toggle — shields allowed. |
| `useHoTs` | boolean | DB toggle — HoTs allowed. |
| `useUtils` | boolean | DB toggle — offensive/supportive utils (BoP, Freedom, etc.). |
| `isPlayer` | boolean | True if a player (defaults to `not isPet` when `isPlayer` arg omitted). |
| `isPet` | boolean | True if a pet (merged from DB). |
| `isSelf` | boolean | True if this unit's GUID == player GUID. |
| `isSelectAble` | boolean | True if the unit passed eligibility (range/connected/not charmed/LOS/faction, alive-or-ressable, pet-allowed). When false, `incDMG/incOffsetDMG = 0`, `HP = realHP`. |
| `incDMG` | number 0-huge | Real-time incoming damage (`GetRealTimeDMG()`), gated by `PredictOptions[2]`. |
| `incOffsetDMG` | number 0-huge | Threshold = `MHP * db.MultiplierIncomingDamageLimit`, raised to `incDMG` if larger. |

Setup also merges all DB keys from `dbUnitIDs[unitID]` first (`Enabled, Role, useDispel, useShields, useHoTs, useUtils, isPet, LUA`).

### Member metamethods (on each `UnitIDs[unitID]` via shared `__index`)
| Method | Returns | Purpose |
|---|---|---|
| `CanSelect(self[, unitID])` | boolean | Targetability: InRange + IsConnected + not Charmed + not InLOS + (PvP or not Enemy). |
| `CanRessurect(self)` | boolean | Out of combat, not self, isPlayer, `db.SelectResurrects`, not ghost, no incoming res, (TBC+ or not Druid). |
| `SetupOffsets(self, manualOffset, autoOffset)` | nil | If `manualOffset==0` → auto: `HP = min(autoOffset, HP)`. Else manual: FIXED → `HP = manualOffset`; Mobile → `HP = HP + manualOffset`. |
| `Setup(self, unitID, unitGUID[, isPlayer])` | nil | Builds the member (see fields above); fires `TMW_ACTION_HEALINGENGINE_UNIT_UPDATE`. |
| `HasLua(self)` | boolean | `self.LUA ~= ""`. |
| `RunLua(self[, luaCode])` | boolean | Runs the unit's Lua condition (or passed code) via `StdUi.RunLua`; empty LUA → true. Self reference inside Lua: `Action.HealingEngine.Data.UnitIDs[thisunit]`. |

---

## 3. `Data` table (`A.HealingEngine.Data`)

Defined lines 274-351. Keys:

| Key | Type | Meaning |
|---|---|---|
| `IsRunning` | boolean | Whether the engine's OnUpdate loop + listeners are active (toggled in `Initialize`). |
| `Aura` | table | `{ Innervate = 29166 }` — used by `IsManaSave`/ManaManagement. |
| `UnitIDs` | table | Map `unitID → member table` (see §2). Pre-generated by `StdUi:tGenerateHealingEngineUnitIDs`. Has `:Wipe()` (wipes each sub-table). |
| `Frequency` | table | `{ Actual = {}, Temp = {} }` with `:Wipe()`. `Actual` = ring of `{ MHP, AHP, TIME }` records (entries older than 10s pruned); `Temp` = accumulator for the current tick. Drives all `GetHealth*`/frequency math. |
| `SortedUnitIDs` | array | Selectable members sorted by HP/AHP ascending. `:Wipe()`. |
| `SortedUnitIDs_MostlyIncDMG` | array | Selectable members sorted by `incDMG` descending. `:Wipe()`. |
| `QueueOrder` | table | `{ useDispel={}, useHoTs={}, useShields={}, useUtils={} }` keyed by Role — per-role FPS-saving guard used by `PerformByProfileHP` and passed to the update callback. `:Wipe()`. |
| `BossIDs` | table | Boss tracking: `[bossGUID] = { [holderUnitID]=true,... }` plus reverse `[holderUnitID] = bossGUID`. `:Wipe()`. Populated by `UNIT_TARGET`. |
| `frame` | Frame | The color/OnUpdate frame ("TargetColor"). |
| `isClassic` | boolean | Convenience copy of `StdUi.isClassic`. |
| `sort_incDMG`, `sort_HP`, `sort_AHP` | function | Comparators exposed for custom profiles. |

Note `Frequency.Actual` records use uppercase `MHP/AHP/TIME` keys (distinct from member-table `MHP/AHP`).

---

## 4. Callbacks & Events

### Fired by the engine
| Event | When | Args |
|---|---|---|
| `TMW_ACTION_HEALINGENGINE_UNIT_UPDATE` | Once per unit, at the end of `:Setup` (line 659), before `AHP` is finalized. | `(callbackEvent, thisUnit, db, QueueOrder)`. `thisUnit` = the member table (mutable; offsets/HoTs/incDMG meant to be applied here). `db` = active spec DB. `QueueOrder` = the per-role guard table (set `QueueOrder.useX[Role]` to suppress redundant work). Reference impl is `PerformByProfileHP`. |
| `TMW_ACTION_METAENGINE_UPDATE` | When the color frame's unit/mode changes (`frame:SetColor`). | `("HealingEngine", "focus" or "target", unit)`. |

### Listened to (drive the engine)
- `TMW_ACTION_HEALINGENGINE_INITIALIZE`, `TMW_ACTION_PLAYER_SPECIALIZATION_CHANGED`, `TMW_ACTION_IS_INITIALIZED` → `Initialize`.
- `TMW_ACTION_DB_UPDATED` → rebinds `db`, `PredictOptions`, `SelectStopOptions`, `dbUnitIDs`; wipes BossIDs if mana-mgmt off.
- `TMW_ACTION_PROFILE_DB_UPDATED` → reloads Paladin blessing locals.
- `TMW_ACTION_GROUP_UPDATE` → updates `inGroup`/`maxGroupSize`, wipes BossIDs.
- `TMW_ACTION_METAENGINE_AUTH` → resets frame so initial unit color sets correctly.
- WoW events via `Listener` (only while running): `PLAYER_FOCUS_CHANGED`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `UNIT_TARGET`, plus always-on `PLAYER_REGEN_ENABLED/DISABLED` (combat flag + wipes), and `ADDON_LOADED` (remap locals).

---

## 5. Toggles / Options read

| Source | Key(s) | Effect |
|---|---|---|
| `GetToggle(8, "HealingEngineAPI")` | — | Master enable/disable of the whole engine. |
| `GetToggle(1, "DisableRegularFrames")` | — | With healthy MetaEngine, sets color frame alpha to 0. |
| Paladin (`GetToggle(2, ...)`) | `BlessingofProtectionUnits`, `DispelUnits`, `BlessingofSacrificeUnits`, `BlessingofFreedomUnits`, `BlessingBuffHealingEnginePvP`, `BlessingBuffHealingEnginePvE` | Per-unit blessing/util gating in `PerformByProfileHP`. |
| Priest (`GetToggle(2, ...)`) | `PreParePOWS`, `PrePareRenew`, `RenewOnlyTank` | Pre-shield / pre-renew behavior in `PerformByProfileHP`. |
| Active spec DB (`db.*`) | `PredictOptions`, `SelectStopOptions`, `SelectSortMethod`, `OffsetMode`, `Offset*` (Tanks/Healers/Damagers/Self × base/Dispel/Shields/HoTs/Utils/Focused/Unfocused), `Multiplier*` (Threat, PetsInCombat, PetsOutCombat, IncomingDamageLimit), `SelectPets`, `SelectResurrects`, `AfterTargetEnemyOrBossDelay`, `AfterMouseoverEnemyDelay`, `ManaManagementManaBoss`, `ManaManagementStopAtHP`, `ManaManagementStopAtTTD` | Drive offsets, prediction, sorting, target-stop delays, mana management, boss tracking. |

`PredictOptions` indices used: `[1]` incoming heals, `[2]` real-time DMG, `[5]` absorb positive, `[6]` total heal absorbs.
`SelectStopOptions` indices `[1..6]`: mouseover-friendly, mouseover-enemy, target-enemy, target-boss, player-dead, sync-pause (also gate "focus healing" mode).

---

## 6. Stub Discrepancies (`docs/api/Globals.lua` lines 130-134)

The existing stub is effectively a **placeholder** — it is almost entirely missing.

1. **Empty class.** Stub is `---@class HealingEngine / local HealingEngine = {}` with a comment "Healing engine is complex and profile-specific / Basic reference for the global object." **Zero** of the 29 public functions are declared.
2. **No `Data` field.** `A.HealingEngine.Data` (the entire member/Frequency/Boss/QueueOrder model) is undocumented.
3. **No member data model.** None of the `thisUnit` fields (`HP, AHP, MHP, realHP, realAHP, Role, incDMG, incOffsetDMG, isSelectAble, isSelf, isPet, isPlayer, Enabled, useDispel/Shields/HoTs/Utils, LUA, Unit, GUID`) are typed.
4. **No callbacks documented.** `TMW_ACTION_HEALINGENGINE_UNIT_UPDATE` (the primary extension point) and `TMW_ACTION_METAENGINE_UPDATE` are absent.
5. **No multi-return signatures.** Functions returning tuples (`GetHealth`, `GetIncomingDMG`, `GetIncomingHPS`, `GetBossHealth` ×5, `GetBossTimeToDie` ×3, `GetBossMain`, `GetOptionsByUnitID` ×5/6, `IsMostlyIncDMG`, `GetTarget`) need explicit `---@return` lists.

Source-internal naming gotchas to preserve when writing the corrected stub:
- `GetBelowHealthPercentercentUnits` is a **real typo alias** (line 1394) kept for back-compat — document, don't "fix".
- `GetOptionsByUnitID` fallback path returns **6** values (`isPlayer, true, true, isPlayer, emptyTable, emptyTable`) while its own `@usage`/normal path returns **5**. The 6th is almost certainly a leftover bug; stub should reflect the documented 5-return contract but a comment should flag the extra.
- `HealingByRange`'s inline `@usage` comment lists `(range, predictName, spell, isMelee)` but the real params are `(range, object, inParty, isMelee)`. Trust the signature, not the comment.
- `GetHealthFrequency` **errors** (hard `error()`) if `timer > 10`.
