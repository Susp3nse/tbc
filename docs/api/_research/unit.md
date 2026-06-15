# Unit Engine — Verified API Reference

Source of truth: `/Users/traveler/Repos/tbc/docs/action/Modules/Engines/Unit.lua` (7276 lines).
Cross-checked against stub `/Users/traveler/Repos/tbc/docs/api/Unit.lua`.

## How the API is registered

The file exports **three** distinct PseudoClasses, all built with the same `PseudoClass(methods)`
helper (lines 127–135). `PseudoClass` just installs a `__call` metamethod that runs `self:New(...)`
and returns `self`, so each is invoked as `Class(arg):Method(...)`.

| Export | Invoked as | `New(...)` args | Methods table |
|--------|-----------|-----------------|---------------|
| `A.Unit` | `Unit(unitID):Method(...)` | `New(UnitID, Refresh)` — `self.UnitID`, `self.Refresh` | lines 4399–6555 |
| `A.FriendlyTeam` | `FriendlyTeam(ROLE):Method(...)` | `New(ROLE, Refresh=0.05)` — `self.ROLE`, `self.Refresh` | lines 6583–6867 |
| `A.EnemyTeam` | `EnemyTeam(ROLE):Method(...)` | `New(ROLE, Refresh=0.05)` — `self.ROLE`, `self.Refresh` | lines 6877–7206 |

Methods are **table entries** (`Name = Cache:Pass(function(self, ...) ... end, "UnitID")`), not
`function Unit:Name()` declarations. Only `New` is declared classically (`function A.Unit:New(...)`).

### Caching wrappers (load-bearing)

Every method is wrapped by `Cache:Pass` or `Cache:Wrap` (defined lines 137–177):

- **`Cache:Pass(fn, keyMode)`** — returns `fn` unchanged unless `CONST.CACHE_MEM_DRIVE` is on (then
  behaves like `Wrap`). Effectively *uncached by default*.
- **`Cache:Wrap(fn, keyMode)`** — memoizes the multi-return for `CACHE_DEFAULT_TIMER_UNIT` seconds,
  keyed by `keyMode`. `keyMode` is the second string arg, either `"UnitID"` (cache per unit token) or
  `"UnitGUID"` (cache per GUID — survives token reuse but costs a `UnitGUID()` lookup).
- The cache stores results in a buffer and `unpack`s them, so wrapped methods preserve all return
  values.

All signatures below are `Method(self, ...)` in source; documented as `Method(...)` (the `self` is the
`Unit(unitID)` / `FriendlyTeam(ROLE)` instance). Param types/defaults are read from the bodies and the
embedded `-- @return` / `-- Nill-able:` comments, which are accurate and authoritative.

One alias exists: **`A.Unit.HasDeBuffs = A.Unit.SortDeBuffs`** (line 6556) — `HasDeBuffs` IS
`SortDeBuffs`.

---

## `A.Unit` — `Unit(unitID):Method()` (the targeting + unit-state surface)

Total `A.Unit` methods: **128** callable (127 `Cache:`-wrapped table entries + the `HasDeBuffs`
alias; `New` documented separately, not counted).

### Auras — buffs / debuffs / tooltip numbers

| Method | Signature (real params) | Returns | Description |
|--------|------------------------|---------|-------------|
| `AuraTooltipNumberByIndex` | `(spell, filter="HELPFUL", caster, byID, kindKey, requestedIndex=1)` | `number` | Scans auras, matches `spell` against `AssociativeTables`, returns a packed tooltip number for the matched aura by `kindKey`/`requestedIndex`. `0` if not found. Cache:Wrap/UnitGUID. |
| `AuraVariableNumber` | `(spell, filter="HELPFUL", caster, byID)` | `number` | First non-zero value in the matched aura's `points` table; `0` if none. Cache:Wrap/UnitGUID. |
| `GetBuffInfo` | `(auraTable, caster)` | `number, number, number, number` | rank, remain duration, total duration, stacks. `auraTable` is `{[spellID or name]=rank}`. `0,0,0,0` if absent. HELPFUL[ PLAYER]. |
| `GetBuffInfoByName` | `(auraName, caster)` | `number, number, number, number` | spellID, remain, total, stacks for exact-name match. `auraName` must be exact string. |
| `GetDeBuffInfo` | `(auraTable, caster)` | `number, number, number, number` | rank, remain, total, stacks (HARMFUL filter). Same shape as GetBuffInfo. |
| `GetDeBuffInfoByName` | `(auraName, caster)` | `number, number, number, number` | spellID, remain, total, stacks for exact debuff name. |
| `HasBuffs` | `(spell, caster, byID)` | `number, number` | current remain, total duration of first matching buff (`huge` if permanent); `0,0` if absent. Cache:Wrap/UnitGUID. |
| `SortBuffs` | `(spell, caster, byID)` | `number, number` | Like HasBuffs but returns the **highest-remaining** matching buff. |
| `HasBuffsStacks` | `(spell, caster, byID)` | `number` | Stack count of first matching buff (1 if charges==0); `0` if absent. |
| `SortDeBuffs` | `(spell, caster, byID)` | `number, number` | Highest-remaining matching debuff: current remain, total duration. Limited to 1 (single) or 3 (table) scans. **`HasDeBuffs` is an alias of this.** |
| `HasDeBuffs` | `(spell, caster, byID)` | `number, number` | **Alias → `SortDeBuffs`** (line 6556). |
| `HasDeBuffsStacks` | `(spell, caster, byID)` | `number` | Stack count of first matching debuff; `0` if absent. |
| `PT` | `(spell, debuff, byID)` | `boolean` | Pandemic threshold: true if a matching aura's remaining ≤30% of its duration. `debuff` truthy → HARMFUL PLAYER, else HELPFUL. |
| `IsDeBuffsLimited` | `()` | `boolean, number` | True if debuff count ≥ `CONST.AURAS_MAX_LIMIT`; also returns the count. |
| `DeBuffCyclone` | `()` | `number` | Stub: always `0` (no such effects in this build). |
| `HasFlags` | `()` | `boolean` | Carrying a BG flag (`HasBuffs(AuraList.Flags) > 0`). Cache:Wrap/UnitGUID. |

Notes: `caster` truthy switches the filter to `"HARMFUL PLAYER"` / `"HELPFUL PLAYER"` (player-cast
only). `byID` truthy matches by spellID instead of name. `spell` is an `AssociativeTables` key (string
group name, spellID, or list).

### Health & power & HP

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `Health` | `()` | `number` | `CombatTracker:UnitHealth(unitID)`. |
| `HealthMax` | `()` | `number` | `CombatTracker:UnitHealthMax(unitID)`. |
| `HealthDeficit` | `()` | `number` | `HealthMax - Health`. |
| `HealthDeficitPercent` | `()` | `number` | `100 - HealthPercent`. |
| `HealthPercent` | `()` | `number` | HP% (0–100); for units without real health values returns raw `UnitHealth`. Guards div-by-zero. |
| `HealthPercentLosePerSecond` | `()` | `number` | `max(GetDMG% - GetHEAL%, 0)`. |
| `HealthPercentGainPerSecond` | `()` | `number` | `max(GetHEAL% - GetDMG%, 0)`. |
| `Power` | `()` | `number` | `UnitPower`. |
| `PowerType` | `()` | `string` | Power token (MANA/ENERGY/RAGE…) — `select(2, UnitPowerType)`. (Stub comment says number; it is a string.) |
| `PowerMax` | `()` | `number` | `UnitPowerMax`. |
| `PowerDeficit` | `()` | `number` | `PowerMax - Power`. |
| `PowerDeficitPercent` | `()` | `number` | `PowerDeficit*100/PowerMax`. |
| `PowerPercent` | `()` | `number` | `Power*100/PowerMax`. |
| `GetTotalHealAbsorbs` | `()` | `number` | Healing the unit will absorb without gaining HP. |
| `GetTotalHealAbsorbsPercent` | `()` | `number` | Above as % of max HP. |
| `GetIncomingResurrection` | `()` | `boolean` | `UnitHasIncomingResurrection`. |
| `GetIncomingHeals` | `(castTime, unitGUID)` | `number` | Predicted *others'* heals landing within `castTime` (HealComm); `0` if `castTime<=0`. Cache:Pass/UnitGUID. |
| `GetIncomingHealsIncSelf` | `(castTime, unitGUID)` | `number` | Like above but includes your own incoming heals. Cache:Wrap/UnitGUID. |

### Range, LoS, movement & interaction

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `GetRange` | `()` | `number, number` | **max range, min range** (LibRangeCheck). Capped to nameplate max for nameplated units; `huge` if unknown. Cache:Wrap/UnitGUID. |
| `CanInterract` | `(range, orBooleanInRange)` | `boolean` | True if min range >0 and (≤`range` OR `orBooleanInRange`). |
| `InRange` | `()` | `boolean` | Is `player` or `UnitInRange`. |
| `InLOS` | `(unitGUID)` | `boolean` | `UnitInLOS(unitID, unitGUID)`. |
| `InGroup` | `(includeAnyGroups, unitGUID)` | `boolean` | In player's group; `includeAnyGroups` → `UnitInAnyGroup`. |
| `InParty` | `()` | `boolean` | `UnitPlayerOrPetInParty`. |
| `InRaid` | `()` | `boolean` | `UnitPlayerOrPetInRaid`. |
| `InVehicle` | `()` | `boolean` | `UnitInVehicle`. |
| `IsNameplate` | `()` | `boolean, string?` | Enemy-plate match → true + nameplate unitID. |
| `IsNameplateAny` | `()` | `boolean, string?` | Any-plate match → true + nameplate unitID. |
| `IsVisible` | `()` | `boolean` | `UnitIsVisible`. |
| `IsExists` | `()` | `boolean` | `UnitExists`. |
| `IsConnected` | `()` | `boolean` | `UnitIsConnected`. |
| `GetCurrentSpeed` | `()` | `number, number` | current speed %, max speed % (run=100). Cache:Wrap/UnitGUID. |
| `GetMaxSpeed` | `()` | `number` | `select(2, GetCurrentSpeed)`. |
| `IsMounted` | `()` | `boolean` | Player → `Player:IsMounted`; else maxSpeed ≥ 200. |
| `IsMoving` | `()` | `boolean` | current speed ≠ 0 (player uses `Player:IsMoving`). |
| `IsMovingTime` | `()` | `number` | Seconds spent continuously moving; `-1` if not moving. Cache/UnitGUID. |
| `IsStaying` | `()` | `boolean` | current speed == 0. |
| `IsStayingTime` | `()` | `number` | Seconds stationary; `-1` if moving. |
| `IsMovingIn` | `(snap_timer=0.2)` | `boolean` | Moving toward player (snapshot range deltas; player always true). |
| `IsMovingOut` | `(snap_timer=0.2)` | `boolean` | Moving away from player. |
| `CanCooperate` | `(otherunit)` | `boolean` | `UnitCanCooperate(unitID, otherunit)`. |

### Casting / interrupt

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `IsCasting` | `()` | `castName, castStartTime, castEndTime, notInterruptable, spellID, isChannel` | Raw cast/channel info; `notInterruptable` is recomputed from `KickImun` buffs. Cache:Wrap/UnitGUID. |
| `CastTime` | `(argSpellID)` | `total, remainSec, donePercent, spellID, castName, notInterruptable, isChannel` | 7 returns. `remainSec` counts X→0; `donePercent` 0→100. For `player`, falls back to `GetSpellInfo` cast time. |
| `IsCastingRemains` | `(argSpellID)` | `remainSec, donePercent, spellID, castName, notInterruptable, isChannel` | `select(2, CastTime)` (drops `total`). |
| `MultiCast` | `(spells, range)` | `total, remain, percent, spellID, name, notInterruptable` | Returns cast info only if the cast matches `spells` (table) or `AuraList.CastBarsCC`; else `0,0,0`. |
| `CanInterrupt` | `(kickAble, auras, minX=34, maxX=68)` | `boolean` | True once cast progress passes a randomized `minX–maxX`% threshold (humanized kick). `kickAble` requires interruptable; `auras` blocks if matched. |

### Threat & combat state

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `ThreatSituation` | `(otherunitID)` | `number, number, number` | status (0–3), scaledPercent, threatValue. Pulls cached `TeamCachethreatData` by GUID; falls back to `otherunitID or "target"`. Percent/value only meaningful Classic–TBC w/ ThreatLib. |
| `IsTanking` | `(otherunitID, range)` | `boolean` | PvP: target-of-target check; PvE: threat ≥3 OR `IsTankingAoE`. |
| `IsTankingAoE` | `(range)` | `boolean` | True if tanking any active enemy nameplate (within `range`). |
| `CombatTime` | `()` | `number, string` | Seconds in combat, unitGUID (`CombatTracker:CombatTime`). |
| `GetDR` | `(drCat)` | `DR_Tick, DR_Remain, DR_Application, DR_ApplicationMax` | Diminishing-returns state for a category. `DR_Tick` 100→50→25→0 (taunt 100→65→42→27→0). See big `drCat` list in source. |
| `IsControlAble` | `(drCat, DR_Tick=0)` | `boolean` | Whether CC of `drCat` will still apply (DR above tick), with boss/creature-type/fear-immunity guards. |
| `GetDMG` | `(index)` | `number…` | Damage **taken** smoothed: total, hits, phys, magic (`select(index,...)` if index given). |
| `GetDPS` | `(index)` | `number…` | Damage **done** smoothed: total, hits, phys, magic. |
| `GetHEAL` | `(index)` | `number…` | Healing taken: total, hits. |
| `GetHPS` | `(index)` | `number…` | Healing done: total, hits. |
| `GetRealTimeDMG` | `(index)` | `number…` | Real-time damage taken: total, hits, phys, magic, swing. |
| `GetRealTimeDPS` | `(index)` | `number…` | Real-time damage done: total, hits, phys, magic, swing. |
| `GetSchoolDMG` | `(index)` | `number…` | Damage by school: Holy, Fire, Nature, Frost, Shadow, Arcane (player only). |
| `GetLastTimeDMGX` | `(x)` | `number` | Damage taken in last `x` seconds. |
| `GetSpellAmountX` | `(spell, x)` | `number` | Amount taken from `spell` in last `x` seconds. |
| `GetSpellAmount` | `(spell)` | `number` | Total amount taken from `spell` this fight. |
| `GetSpellLastCast` | `(spell)` | `number, number` | Seconds since last cast, start timestamp. |
| `GetSpellCounter` | `(spell)` | `number` | Total casts of `spell` this fight. |
| `GetAbsorb` | `(spell)` | `number` | Absorb taken total (or by `spell`). |
| `IsPenalty` | `()` | `boolean` | True if unit level >0 and < playerLevel−10 (heal/damage penalty). |
| `GetLevel` | `()` | `number` | `UnitLevel` or 0 (−1 = boss/skull). |

### UnitCooldown (enemy spell-cooldown tracking)

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `GetCooldown` | `(spellName)` | `number, number` | Remaining CD seconds, start timestamp. |
| `GetMaxDuration` | `(spellName)` | `number` | Max CD of the spell on the unit. |
| `GetUnitID` | `(spellName)` | `unitID?` | Who last cast `spellName` (else nil). **Note:** this is the `A.Unit` `GetUnitID(spellName)`, distinct from the team-class `GetUnitID(range)`. |
| `GetBlinkOrShrimmer` | `()` | `number, number, number` | charges, current CD, summary CD. |
| `IsSpellInFly` | `(spellName)` | `boolean` | Spell currently mid-flight. |

### Time-to-die / TTD

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `TimeToDie` | `()` | `number` | Seconds until 0% (`CombatTracker:TimeToDie`). |
| `TimeToDieX` | `(x)` | `number` | Seconds until `x`% HP. |
| `TimeToDieMagic` | `()` | `number` | TTD from magic damage only. |
| `TimeToDieMagicX` | `(x)` | `number` | TTD-magic to `x`%. |
| `IsExecuted` | `()` | `boolean` | `TimeToDieX(20) <= GCD + currentGCD` (in execute window). |

### Role / class / spec / GUID identity

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `Name` | `()` | `string` | `UnitName` or `"none"`. |
| `Race` | `()` | `string` | Non-localized race token; `"none"` fallback. |
| `Class` | `()` | `string` | Uppercase class token (WARRIOR…); `"none"` fallback. |
| `Role` | `(hasRole)` | `boolean \| string` | Without `hasRole`: returns role string (TANK/HEALER/DAMAGER/NONE). With `hasRole` string: returns boolean match. Includes Proving-Grounds special cases. |
| `Classification` | `()` | `string` | `UnitClassification` (elite/worldboss/rare…) or empty. |
| `CreatureType` | `()` | `string` | English creature type (Beast/Demon/Humanoid…) or empty. |
| `CreatureFamily` | `()` | `string` | English creature family (Wolf/Cat/Imp…) or empty. |
| `InfoGUID` | `(unitGUID)` | `utype, n, n, n, n, npc_id, spawn_uid` | Parses GUID into 7 fields (strings/numbers); nil if no GUID. Cache:Wrap/UnitID. |
| `HasSpec` | `(specID)` | `boolean` | Spec match (player via `A.PlayerSpec`; others via `UnitSpecsMap`, class spec-buffs, or used-spell heuristics). `specID` may be number or table. |
| `IsHealer` | `(class)` | `boolean` | Multi-strategy healer detection (team cache, assigned role, power/offhand/shield, then DPS-vs-HPS combat heuristic). |
| `IsTank` | `(class)` | `boolean` | Multi-strategy tank detection (team cache, role, shield/stance, threat ≥3, DMG-taken heuristic). |
| `IsDamager` | `(class)` | `boolean` | Multi-strategy DPS detection (mirror of above). |
| `IsMelee` | `(class)` | `boolean` | Melee detection (class + role + power/offhand + spell-counter heuristics). |
| `IsHealerClass` | `()` | `boolean` | Class CAN be healer (lookup only). |
| `IsTankClass` | `()` | `boolean` | Class can be tank. |
| `IsMeleeClass` | `()` | `boolean` | Class can be melee. |
| `IsEnemy` | `(isPlayer)` | `boolean` | Hostile (`UnitCanAttack`/`UnitIsEnemy`); `isPlayer` requires it be a player. Cache:Wrap/UnitGUID. |
| `IsPlayer` | `()` | `boolean` | `UnitIsPlayer`. |
| `IsPet` | `()` | `boolean` | Player-controlled non-player. |
| `IsPlayerOrPet` | `()` | `boolean` | Player or player-controlled. |
| `IsNPC` | `()` | `boolean` | Not player-controlled. |
| `IsDead` | `()` | `boolean` | DeadOrGhost and not feign-death. |
| `IsGhost` | `()` | `boolean` | `UnitIsGhost`. |
| `IsCharmed` | `()` | `boolean` | `UnitIsCharmed`. |
| `IsBoss` | `()` | `boolean` | npc_id/boss-frame/level-skull boss detection. |
| `IsDummy` | `()` | `boolean` | npc_id in `InfoIsDummy`. |
| `IsUndead` / `IsDemon` / `IsHumanoid` / `IsElemental` / `IsTotem` | `()` | `boolean` | `CreatureType()` equality shortcuts. |
| `InCC` | `(index=1)` | `number` | Remaining CC seconds (scans `InfoAllCC` from `index`); `0` if none. Cache:Wrap/UnitGUID. |

### Focus / burst / defensive decision helpers (`A.Unit`)

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `IsFocused` | `(burst, deffensive, range, isMelee)` | `boolean` | True if a friendly/arena damager/melee is targeting this unit, optionally gated by attacker burst buffs, this unit's defensive buffs, range, and melee flag. Cache:Wrap/UnitGUID. |
| `UseBurst` | `(pBurst)` | `boolean` | Whether to burst this unit — enemy-player logic (TTD, healer CC, focus) or HealingEngine-as-healer logic. |
| `UseDeff` | `()` | `boolean` | Whether to pop defensives (executed / heavily focused / low TTD + focused). |

`New` (line 6558): `New(UnitID, Refresh)` — errors loudly if `UnitID` is nil; sets `self.UnitID`,
`self.Refresh`.

---

## Targeting / selection helpers — `A.FriendlyTeam` and `A.EnemyTeam`

**These are the team-iteration / enemy-selection helpers.** The stub WRONGLY flattens them onto the
single `Unit` class. They live on separate PseudoClasses keyed by `ROLE`
(`"TANK"|"HEALER"|"DAMAGER"|"DAMAGER_MELEE"|"DAMAGER_RANGE"|nil`), invoked as
`A.FriendlyTeam(ROLE):Method()` / `A.EnemyTeam(ROLE):Method()`. Role filtering is done by the file-local
`CheckUnitByRole(ROLE, unitID)` (line 6571). Unit-not-found returns `"none"` (`str_none`).

### `A.FriendlyTeam(ROLE):...`

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `GetUnitID` | `(range)` | `string` | First alive, in-range friendly of `ROLE` (≤`range`); `"none"` otherwise. |
| `GetCC` | `(spells)` | `number, unitID` | First friendly of `ROLE` under CC (or matching `spells` debuff): remaining, unit. `0,"none"` if none. |
| `GetBuffs` | `(spells, range, source)` | `number, unitID` | First friendly of `ROLE` (in range) with matching buff: remaining, unit. |
| `GetDeBuffs` | `(spells, range)` | `number, unitID` | First friendly of `ROLE` with matching debuff: remaining, unit. |
| `GetTTD` | `(count, seconds, range)` | `boolean, number, unitID` | True once `count` friendlies of `ROLE` have TTD ≤ `seconds`; returns count + (last) unit. Cache:Wrap/ROLE. |
| `AverageTTD` | `(range)` | `number, number` | Average TTD of valid friendlies of `ROLE`, and their count. |
| `MissedBuffs` | `(spells, source)` | `boolean, unitID` | First friendly of `ROLE` MISSING `spells` buff: true, unit. |
| `PlayersInCombat` | `(range, combatTime)` | `boolean, unitID` | First friendly of `ROLE` in combat (optionally combatTime ≤ `combatTime`): true, unit. |
| `HealerIsFocused` | `(burst, deffensive, range, isMelee)` | `boolean, unitID` | First **HEALER** (ROLE forced) being focused (`Unit:IsFocused`): true, unit. |

### `A.EnemyTeam(ROLE):...` (enemy selection)

| Method | Signature | Returns | Description |
|--------|-----------|---------|-------------|
| `GetUnitID` | `(range)` | `string` | First alive, in-range enemy of `ROLE`; `"none"` otherwise. |
| `GetCC` | `(spells)` | `number, unitID` | First enemy of `ROLE` under CC (HEALER role skips current target): remaining, unit. |
| `GetBuffs` | `(spells, range, source)` | `number, unitID` | First enemy of `ROLE` (in range) with matching buff. |
| `GetDeBuffs` | `(spells, range)` | `number, unitID` | First enemy of `ROLE` with matching debuff. |
| `GetTTD` | `(count, seconds, range)` | `boolean, number, unitID` | True once `count` enemies of `ROLE` have TTD ≤ `seconds`. Cache:Pass/ROLE. |
| `AverageTTD` | `(range)` | `number, number` | Average enemy TTD + count. (Note: source has latent bug — uses undeclared `arena`/`arenas`.) |
| `IsBreakAble` | `(range)` | `boolean, unitID` | First non-target enemy of `ROLE` with a `"BreakAble"` debuff (don't break CC on your kill target). |
| `PlayersInRange` | `(stop, range)` | `boolean, number, unitID` | Counts enemies of `ROLE` in range; returns true once count ≥ `stop`. |
| `FocusingUnitIDByClasses` | `(unitID, stop, range, ...)` | `boolean, number, unitID` | Counts enemies of `ROLE` & class-in-`...` whose target is `unitID`; true once count ≥ `stop`. Who-is-focusing query. |
| `HasInvisibleUnits` | `(checkVisible)` | `boolean, unitID, class` | Any alive ROGUE/DRUID enemy (optionally only if not visible): true, unit, class. (No ROLE.) |
| `IsTauntPetAble` | `(object, range)` | `boolean, unitID` | First enemy pet (optionally in range of `object`): true, pet. |
| `IsCastingBreakAble` | `(offset=0.5)` | `boolean, unitID` | Enemy finishing (≤`offset`s) a cast matching `AuraList.Premonition` in range: true, unit. |
| `IsReshiftAble` | `(offset=0.05)` | `boolean, unitID` | Enemy about to finish (≤ GCD+offset) a `AuraList.Reshift` cast, when player isn't melee-focused. |
| `IsPremonitionAble` | `(offset=0.05)` | `boolean, unitID` | Enemy about to finish (≤ GCD+offset) a `AuraList.Premonition` cast: true, unit. |

`A.FriendlyTeam:New` / `A.EnemyTeam:New` (lines 6869 / 7208): `New(ROLE, Refresh=0.05)`.

---

## Stub discrepancies (`docs/api/Unit.lua`)

The stub is **structurally wrong in one systemic way plus many type gaps**:

### Systemic

1. **Three classes flattened into one.** The stub declares a single `Unit` class and attaches the
   `FriendlyTeam`/`EnemyTeam` ROLE-keyed methods onto it. In reality those are separate PseudoClasses
   invoked as `FriendlyTeam(ROLE):X()` / `EnemyTeam(ROLE):X()`, NOT `Unit(unitID):X()`. The
   mis-attached methods are: `GetUnitID(range)`, `GetCC`, `GetBuffs`, `GetDeBuffs`, `GetTTD`,
   `AverageTTD`, `MissedBuffs`, `PlayersInCombat`, `PlayersInRange`, `HealerIsFocused`, `IsBreakAble`,
   `FocusingUnitIDByClasses`, `HasInvisibleUnits`, `IsTauntPetAble`, `IsCastingBreakAble`,
   `IsReshiftAble`, `IsPremonitionAble`. **The stub omits these classes entirely** and gives no `New`.

2. **`GetUnitID` collision.** The stub documents `GetUnitID(range)` (the team variant). The real
   `A.Unit:GetUnitID(spellName)` (UnitCooldown — "who last cast spellName") is a *different method with
   a different param and return* and is missing from the stub's intent.

3. **Pervasive `any`.** ~100+ params typed `any` and dozens of `---@return any` where the source's
   embedded `-- @return` comments give exact types. Examples needing fixing: `GetCooldown`→`number,
   number`; `GetMaxDuration`→`number`; `GetBlinkOrShrimmer`→`number, number, number`;
   `GetSchoolDMG`→`number`(multi); `IsSpellInFly`→`boolean`; `IsDeBuffsLimited`→`boolean, number`;
   `GetBuffInfoByName`/`GetDeBuffInfoByName`→`number, number, number, number`; `DeBuffCyclone`→`number`.

### Specific signature/return errors (high-value)

4. **`PowerType` typed `string` "MANA, ENERGY…"** — correct. But the *source comment* mislabels it
   `@return number`; the stub is actually right here. (Flag only so the doc author doesn't "fix" it to
   number.)
5. **`CastTime`** real return is **7 values** `total, remainSec, donePercent, spellID, castName,
   notInterruptable, isChannel`. Stub has the right 7 but mislabels position 2/3 wording; ensure
   `remainSec` (X→0) vs `donePercent` (0→100) are documented per source.
6. **`MultiCast`** real return is `total, remain, percent, spellID, name, notInterruptable` (6 values,
   `0,0,0` when no match) — stub returns `any`.
7. **`HasDeBuffs`** must be documented as an **alias of `SortDeBuffs`** (returns highest-remaining,
   limited to 1/3 scans) — not an independent "has debuff" boolean. Stub omits `HasDeBuffs` entirely.
8. **`InfoGUID`** returns 7 mixed string/number fields (`utype` is a string, not number) — stub's
   `string, number*6` is close but `npc_id`/`spawn_uid` can be nil.
9. **`Role`** returns either `boolean` (when `hasRole` passed) or `string` — stub only says `string`.
10. **`GetDMG/GetDPS/GetHEAL/GetHPS/GetRealTimeDMG/GetRealTimeDPS/GetSchoolDMG`** are multi-return
    (total + components) when called without `index`; stub types single `number`.
11. **Defaults not captured:** `AuraTooltipNumberByIndex` filter default `"HELPFUL"` & requestedIndex
    `1`; aura filters default HELPFUL/HARMFUL with `caster`→`… PLAYER`; `CanInterrupt` minX/maxX
    default 34/68; `IsMovingIn/Out` snap_timer 0.2; `InCC` index 1; CC `*Able` offset defaults.

### Source bug worth noting (not a stub issue)

- `A.EnemyTeam:AverageTTD` (line 6988) references undeclared locals `arena`/`arenas` (the Friendly
  version uses `member`/`members`). It will error or read globals at runtime; documented as-is.
