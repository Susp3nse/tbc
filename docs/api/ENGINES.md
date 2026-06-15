# The Action — Engine API Reference (verified)

> **Status:** Verified against the actual addon source in `docs/action/Modules/Engines/`
> (and `Modules/Actions.lua`, `Modules/Misc/`, `Modules/Components/`) on 2026-06-15.
> This document is the human-readable companion to the EmmyLua stubs in `docs/api/*.lua`.
> Where the two disagree, **this doc and the corrected stubs win over the old auto-generated stubs** —
> the per-function "discrepancy" notes call out what changed and why.
>
> Priorities of this reference, per request: the **Targeting Engine** (Part 1) and the
> **Healing Engine** (Part 2) are built out in full; the supporting engines (Part 3) are a verified
> index.

---

## 0. Orientation — how the framework is namespaced

Everything hangs off one global: `A = _G.Action`. The engines attach themselves to it.

| Surface | Invoked as | What it is |
|---|---|---|
| `A.Unit` | `Unit(unitID):Method(...)` | Per-unit **state** (auras, health, range, casting, threat, identity). PseudoClass. |
| `A.FriendlyTeam` | `FriendlyTeam(ROLE):Method(...)` | **Friendly selection** — iterate allies of a role. PseudoClass. |
| `A.EnemyTeam` | `EnemyTeam(ROLE):Method(...)` | **Enemy selection** — iterate enemies of a role. PseudoClass. |
| `A.MultiUnits` | `MultiUnits:Method(...)` | **AoE / enemy counting** via nameplates + combat-log cleave. Singleton. |
| `A.HealingEngine` | `HealingEngine.Func(...)` | **Heal-target selection** + group health analytics. Note: `.` calls, not `:`. |
| `A.CombatTracker` | `CombatTracker:Method(...)` | CLEU-driven combat data (real-health emulation, TTD, DPS, DR). Underpins most of the above. |
| `A.Player` | `Player:Method(...)` | The player singleton (resources, casting, gear, movement). |
| `A.TeamCache` | `A.TeamCache.Friendly / .Enemy` | Group/enemy roster + role buckets + (Classic) threat. |
| `A.LossOfControl` | `LossOfControl:Method(...)` | CC tracking. |
| `A.Pet` | `Pet:Method(...)` | Pet GCD history. |
| `A.Bit` | `A.Bit.func(Flags)` | CLEU unit-flag bit tests. |
| ActionObject | `<spell>:Method(...)` | The object returned by `Action.Create` / `A:Add`. Lives in `Modules/Actions.lua`. |

### Two invocation conventions to never mix up
- **`Unit`, `FriendlyTeam`, `EnemyTeam` are PseudoClasses**: you *call* the class to bind an argument,
  then use **colon** methods. `Unit("focus"):HealthPercent()`, `EnemyTeam("HEALER"):GetUnitID(40)`.
  The bound argument is `unitID` for `Unit`, and a `ROLE` for the two Team classes.
- **`HealingEngine` uses dot calls** (`HealingEngine.GetTarget()`), not colon — its functions take no `self`.

### The caching model (load-bearing)
`Unit`/`FriendlyTeam`/`EnemyTeam` methods are each wrapped at definition by one of:
- **`Cache:Pass(fn, keyMode)`** — effectively **uncached** by default (only caches if `CONST.CACHE_MEM_DRIVE` is on).
- **`Cache:Wrap(fn, keyMode)`** — **memoizes** the full multi-return for `CACHE_DEFAULT_TIMER_UNIT` seconds,
  keyed by `keyMode` (`"UnitID"` = per unit token, `"UnitGUID"` = per GUID, survives token reuse but costs a `UnitGUID()` lookup).

`MultiUnits` counters and a few `HealingEngine` functions are wrapped post-definition with
`MakeFunctionCachedDynamic` / `MakeFunctionCachedStatic`. Caching is noted per-function below — it matters
when you call something many times per tick.

**`ROLE` values** (for the Team classes): `"TANK"`, `"HEALER"`, `"DAMAGER"`, `"DAMAGER_MELEE"`,
`"DAMAGER_RANGE"`, or `nil` (= any role). Unit-not-found returns the sentinel string `"none"`.

---

# Part 1 — The Targeting Engine

The "targeting engine" is three cooperating surfaces:
1. **`Unit(unitID)`** — evaluate one unit (the building block).
2. **`FriendlyTeam(ROLE)`** — pick an ally.
3. **`EnemyTeam(ROLE)` + `MultiUnits`** — pick / count enemies.

> ⚠️ The old auto-generated `docs/api/Unit.lua` stub **flattened all three classes into one fake `Unit`**.
> The team-selection methods (`GetUnitID(range)`, `GetCC`, `GetBuffs`, `GetTTD`, `IsBreakAble`,
> `PlayersInRange`, `FocusingUnitIDByClasses`, …) are **NOT** on `Unit(unitID)` — they are on
> `FriendlyTeam(ROLE)` / `EnemyTeam(ROLE)`. The corrected stubs split them apart.

---

## 1A. `Unit(unitID)` — per-unit state (128 methods)

`unitID` is any WoW unit token (`"player"`, `"target"`, `"focus"`, `"raid7"`, a nameplate token, …).
`caster` truthy on aura methods switches the filter to player-cast-only (`"… PLAYER"`); `byID` truthy
matches by spellID instead of name. `spell` is an `AssociativeTables` key (group name / spellID / list).

### Auras — buffs / debuffs / tooltip numbers
| Method | Signature | Returns | Description |
|---|---|---|---|
| `AuraTooltipNumberByIndex` | `(spell, filter="HELPFUL", caster, byID, kindKey, requestedIndex=1)` | `number` | Packed tooltip number for the matched aura (`0` if absent). Cache:Wrap/GUID. |
| `AuraVariableNumber` | `(spell, filter="HELPFUL", caster, byID)` | `number` | First non-zero value in the aura's `points` table; `0` if none. Cache:Wrap/GUID. |
| `GetBuffInfo` | `(auraTable, caster)` | `rank, remain, total, stacks` | `auraTable` = `{[id or name]=rank}`. `0,0,0,0` if absent. |
| `GetBuffInfoByName` | `(auraName, caster)` | `spellID, remain, total, stacks` | Exact-name match. |
| `GetDeBuffInfo` | `(auraTable, caster)` | `rank, remain, total, stacks` | HARMFUL filter. |
| `GetDeBuffInfoByName` | `(auraName, caster)` | `spellID, remain, total, stacks` | Exact debuff name. |
| `HasBuffs` | `(spell, caster, byID)` | `remain, total` | First matching buff (`huge` total if permanent); `0,0` if absent. Cache:Wrap/GUID. |
| `SortBuffs` | `(spell, caster, byID)` | `remain, total` | Like `HasBuffs` but the **highest-remaining** match. |
| `HasBuffsStacks` | `(spell, caster, byID)` | `number` | Stacks of first match (1 if charges==0); `0` if absent. |
| `SortDeBuffs` | `(spell, caster, byID)` | `remain, total` | Highest-remaining matching debuff (scans 1 single / 3 table). |
| `HasDeBuffs` | `(spell, caster, byID)` | `remain, total` | **Alias of `SortDeBuffs`** — NOT a boolean. |
| `HasDeBuffsStacks` | `(spell, caster, byID)` | `number` | Stacks of first matching debuff. |
| `PT` | `(spell, debuff, byID)` | `boolean` | Pandemic: remaining ≤30% of duration. `debuff` truthy → HARMFUL PLAYER. |
| `IsDeBuffsLimited` | `()` | `boolean, number` | Debuff count ≥ `CONST.AURAS_MAX_LIMIT`, plus the count. |
| `DeBuffCyclone` | `()` | `number` | Always `0` in this build (no such effects). |
| `HasFlags` | `()` | `boolean` | Carrying a BG flag. Cache:Wrap/GUID. |

### Health & power
| Method | Signature | Returns | Description |
|---|---|---|---|
| `Health` / `HealthMax` | `()` | `number` | `CombatTracker:UnitHealth(Max)` — **real-health emulated** for enemies (see CombatTracker). |
| `HealthDeficit` / `HealthDeficitPercent` | `()` | `number` | Missing HP / `100 - HealthPercent`. |
| `HealthPercent` | `()` | `number` | 0–100; guards div-by-zero. |
| `HealthPercentLosePerSecond` / `…GainPerSecond` | `()` | `number` | `max(DMG%−HEAL%,0)` / `max(HEAL%−DMG%,0)`. |
| `Power` / `PowerMax` / `PowerDeficit` / `PowerDeficitPercent` / `PowerPercent` | `()` | `number` | Power arithmetic. |
| `PowerType` | `()` | `string` | Power token ("MANA"/"ENERGY"/…). *(Source comment mislabels as number — it's a string.)* |
| `GetTotalHealAbsorbs` / `GetTotalHealAbsorbsPercent` | `()` | `number` | Heal the unit will absorb without gaining HP. |
| `GetIncomingResurrection` | `()` | `boolean` | Has an incoming res. |
| `GetIncomingHeals` | `(castTime, unitGUID)` | `number` | Predicted **others'** heals landing within `castTime` (HealComm); `0` if `castTime<=0`. |
| `GetIncomingHealsIncSelf` | `(castTime, unitGUID)` | `number` | …including your own. Cache:Wrap/GUID. |

### Range, LoS, movement & interaction
| Method | Signature | Returns | Description |
|---|---|---|---|
| `GetRange` | `()` | `maxRange, minRange` | LibRangeCheck; capped to nameplate max; `huge` if unknown. Cache:Wrap/GUID. |
| `CanInterract` | `(range, orBooleanInRange)` | `boolean` | minRange>0 and (≤`range` OR `orBooleanInRange`). **The canonical range gate.** |
| `InRange` | `()` | `boolean` | `player` or `UnitInRange`. |
| `InLOS` | `(unitGUID)` | `boolean` | Line of sight. |
| `InGroup` | `(includeAnyGroups, unitGUID)` | `boolean` | In player's group. |
| `InParty` / `InRaid` / `InVehicle` | `()` | `boolean` | Membership / vehicle. |
| `IsNameplate` / `IsNameplateAny` | `()` | `boolean, string?` | Plate match → true + nameplate token. |
| `IsVisible` / `IsExists` / `IsConnected` | `()` | `boolean` | Visibility / existence / connection. |
| `GetCurrentSpeed` | `()` | `cur%, max%` | Run = 100. Cache:Wrap/GUID. |
| `GetMaxSpeed` | `()` | `number` | `select(2, GetCurrentSpeed)`. |
| `IsMounted` / `IsMoving` / `IsStaying` | `()` | `boolean` | State. |
| `IsMovingTime` / `IsStayingTime` | `()` | `number` | Seconds moving / stationary; `-1` otherwise. |
| `IsMovingIn` / `IsMovingOut` | `(snap_timer=0.2)` | `boolean` | Closing / opening distance to player. |
| `CanCooperate` | `(otherunit)` | `boolean` | `UnitCanCooperate`. |

### Casting / interrupt
| Method | Signature | Returns | Description |
|---|---|---|---|
| `IsCasting` | `()` | `castName, startT, endT, notInterruptable, spellID, isChannel` | Raw cast/channel; `notInterruptable` recomputed from `KickImun`. Cache:Wrap/GUID. |
| `CastTime` | `(argSpellID)` | `total, remainSec, donePercent, spellID, castName, notInterruptable, isChannel` | **7 returns.** `remainSec` counts X→0; `donePercent` 0→100. |
| `IsCastingRemains` | `(argSpellID)` | `remainSec, donePercent, spellID, castName, notInterruptable, isChannel` | `select(2, CastTime)`. |
| `MultiCast` | `(spells, range)` | `total, remain, percent, spellID, name, notInterruptable` | Cast info only if it matches `spells`/`CastBarsCC`; else `0,0,0`. |
| `CanInterrupt` | `(kickAble, auras, minX=34, maxX=68)` | `boolean` | True once progress passes a randomized `minX–maxX`% threshold (humanized kick). |

### Threat & combat state
| Method | Signature | Returns | Description |
|---|---|---|---|
| `ThreatSituation` | `(otherunitID)` | `status(0–3), scaledPercent, threatValue` | Percent/value only meaningful Classic–TBC w/ ThreatLib. |
| `IsTanking` | `(otherunitID, range)` | `boolean` | PvP: target-of-target; PvE: threat ≥3 OR `IsTankingAoE`. |
| `IsTankingAoE` | `(range)` | `boolean` | Tanking any active enemy nameplate in `range`. |
| `CombatTime` | `()` | `seconds, GUID` | Seconds in combat. |
| `GetDR` | `(drCat)` | `DR_Tick, DR_Remain, DR_Application, DR_ApplicationMax` | DR state. Tick 100→50→25→0 (taunt 100→65→42→27→0). |
| `IsControlAble` | `(drCat, DR_Tick=0)` | `boolean` | Whether CC of `drCat` still applies (boss/type/fear-immunity guards). |
| `GetDMG`/`GetDPS`/`GetHEAL`/`GetHPS` | `(index)` | `total, hits[, phys, magic]` | Smoothed damage/heal taken/done. `select(index,…)` if `index` given. |
| `GetRealTimeDMG`/`GetRealTimeDPS` | `(index)` | `total, hits, phys, magic, swing` | Real-time window. |
| `GetSchoolDMG` | `(index)` | `Holy, Fire, Nature, Frost, Shadow, Arcane` | Player only. |
| `GetLastTimeDMGX` | `(x)` | `number` | Damage taken in last `x` s. |
| `GetSpellAmountX`/`GetSpellAmount` | `(spell[, x])` | `number` | Amount taken from `spell` (last `x` s / fight). |
| `GetSpellLastCast` | `(spell)` | `secsSince, startTS` | Last cast of `spell`. |
| `GetSpellCounter` | `(spell)` | `number` | Casts of `spell` this fight. |
| `GetAbsorb` | `(spell)` | `number` | Absorb taken (total or by `spell`). |
| `IsPenalty` | `()` | `boolean` | Level >0 and < playerLevel−10. |
| `GetLevel` | `()` | `number` | `UnitLevel` (−1 = boss/skull → returns 0 guard). |

### UnitCooldown — enemy spell-cooldown tracking
| Method | Signature | Returns | Description |
|---|---|---|---|
| `GetCooldown` | `(spellName)` | `remain, startTS` | Enemy ability CD. |
| `GetMaxDuration` | `(spellName)` | `number` | Max CD of the spell. |
| `GetUnitID` | `(spellName)` | `unitID?` | **Who last cast `spellName`** (nil if none). ⚠️ Different method from the Team-class `GetUnitID(range)`. |
| `GetBlinkOrShrimmer` | `()` | `charges, curCD, summaryCD` | Blink/Shimmer tracking. |
| `IsSpellInFly` | `(spellName)` | `boolean` | Spell mid-flight. |

### Time-to-die
| Method | Signature | Returns | Description |
|---|---|---|---|
| `TimeToDie` | `()` | `number` | Seconds to 0% (`CombatTracker:TimeToDie`). 500 ≈ ∞. |
| `TimeToDieX` | `(x)` | `number` | Seconds to `x`% HP. |
| `TimeToDieMagic` / `TimeToDieMagicX` | `([x])` | `number` | Magic-damage-only variants. |
| `IsExecuted` | `()` | `boolean` | `TimeToDieX(20) <= GCD + currentGCD`. |

### Identity / role / class
| Method | Signature | Returns | Description |
|---|---|---|---|
| `Name` / `Race` / `Class` | `()` | `string` | `"none"` fallback. Class is the uppercase token. |
| `Role` | `(hasRole)` | `boolean \| string` | No arg → role string ("TANK"/"HEALER"/"DAMAGER"/"NONE"); with `hasRole` string → boolean match. |
| `Classification` / `CreatureType` / `CreatureFamily` | `()` | `string` | Elite/worldboss…; Beast/Demon…; Wolf/Cat… |
| `InfoGUID` | `(unitGUID)` | `utype, n, n, n, n, npc_id, spawn_uid` | Parses GUID into 7 fields; nil if no GUID. Cache:Wrap/UnitID. |
| `HasSpec` | `(specID)` | `boolean` | Spec match. `specID` number or table. |
| `IsHealer` / `IsTank` / `IsDamager` / `IsMelee` | `(class)` | `boolean` | Multi-strategy role detection (team cache → assigned role → gear/power → combat heuristic). |
| `IsHealerClass` / `IsTankClass` / `IsMeleeClass` | `()` | `boolean` | Class *can be* that role (lookup only). |
| `IsEnemy` | `(isPlayer)` | `boolean` | Hostile; `isPlayer` requires a player. Cache:Wrap/GUID. |
| `IsPlayer` / `IsPet` / `IsPlayerOrPet` / `IsNPC` | `()` | `boolean` | Control/type. |
| `IsDead` / `IsGhost` / `IsCharmed` | `()` | `boolean` | State (IsDead excludes feign). |
| `IsBoss` / `IsDummy` | `()` | `boolean` | Boss / training-dummy detection. |
| `IsUndead`/`IsDemon`/`IsHumanoid`/`IsElemental`/`IsTotem` | `()` | `boolean` | `CreatureType` shortcuts. |
| `InCC` | `(index=1)` | `number` | Remaining CC seconds; `0` if none. Cache:Wrap/GUID. |

### Focus / burst / defensive decision helpers
| Method | Signature | Returns | Description |
|---|---|---|---|
| `IsFocused` | `(burst, deffensive, range, isMelee)` | `boolean` | A friendly/arena damager/melee is targeting this unit (optionally gated by attacker burst, this unit's defensives, range, melee). Cache:Wrap/GUID. |
| `UseBurst` | `(pBurst)` | `boolean` | Whether to burst this unit. |
| `UseDeff` | `()` | `boolean` | Whether to pop defensives (executed / heavily focused / low TTD + focused). |

`Unit(unitID):New(UnitID, Refresh)` — constructor; errors loudly if `UnitID` is nil.

---

## 1B. `FriendlyTeam(ROLE)` — friendly selection (10 methods)

Iterates allies matching `ROLE` (via the file-local `CheckUnitByRole`). Returns `"none"` when nothing matches.

| Method | Signature | Returns | Description |
|---|---|---|---|
| `GetUnitID` | `(range)` | `unitID` | First alive, in-range friendly of `ROLE`; `"none"` otherwise. |
| `GetCC` | `(spells)` | `remain, unitID` | First friendly under CC (or matching `spells` debuff). `0,"none"` if none. |
| `GetBuffs` | `(spells, range, source)` | `remain, unitID` | First friendly (in range) with matching buff. |
| `GetDeBuffs` | `(spells, range)` | `remain, unitID` | First friendly with matching debuff. |
| `GetTTD` | `(count, seconds, range)` | `boolean, number, unitID` | True once `count` friendlies have TTD ≤ `seconds`. Cache:Wrap/ROLE. |
| `AverageTTD` | `(range)` | `avgTTD, count` | Average TTD of valid friendlies. |
| `MissedBuffs` | `(spells, source)` | `boolean, unitID` | First friendly **missing** the `spells` buff. |
| `PlayersInCombat` | `(range, combatTime)` | `boolean, unitID` | First friendly in combat (optional combatTime cap). |
| `HealerIsFocused` | `(burst, deffensive, range, isMelee)` | `boolean, unitID` | First **HEALER** (role forced) being focused by an enemy. |

`FriendlyTeam(ROLE):New(ROLE, Refresh=0.05)`.

---

## 1C. `EnemyTeam(ROLE)` + `MultiUnits` — enemy selection & AoE counting

### `EnemyTeam(ROLE)` — pick an enemy (14 methods)
| Method | Signature | Returns | Description |
|---|---|---|---|
| `GetUnitID` | `(range)` | `unitID` | First alive, in-range enemy of `ROLE`; `"none"` otherwise. |
| `GetCC` | `(spells)` | `remain, unitID` | First enemy under CC (HEALER role skips current target). |
| `GetBuffs` | `(spells, range, source)` | `remain, unitID` | First enemy (in range) with matching buff. |
| `GetDeBuffs` | `(spells, range)` | `remain, unitID` | First enemy with matching debuff. |
| `GetTTD` | `(count, seconds, range)` | `boolean, number, unitID` | True once `count` enemies have TTD ≤ `seconds`. Cache:Pass/ROLE. |
| `AverageTTD` | `(range)` | `avgTTD, count` | ⚠️ Source has a latent bug (undeclared `arena`/`arenas` locals). |
| `IsBreakAble` | `(range)` | `boolean, unitID` | First **non-target** enemy with a `"BreakAble"` debuff (don't break CC on your kill target). |
| `PlayersInRange` | `(stop, range)` | `boolean, count, unitID` | True once enemy count in range ≥ `stop`. |
| `FocusingUnitIDByClasses` | `(unitID, stop, range, ...)` | `boolean, count, unitID` | Counts enemies of `ROLE` & class-in-`...` whose target is `unitID`. "Who's focusing X?" |
| `HasInvisibleUnits` | `(checkVisible)` | `boolean, unitID, class` | Any alive ROGUE/DRUID enemy (optionally only if not visible). No ROLE filter. |
| `IsTauntPetAble` | `(object, range)` | `boolean, unitID` | First enemy pet (optionally in range of `object`). |
| `IsCastingBreakAble` | `(offset=0.5)` | `boolean, unitID` | Enemy finishing (≤`offset`s) a `Premonition`-list cast in range. |
| `IsReshiftAble` | `(offset=0.05)` | `boolean, unitID` | Enemy about to finish a `Reshift`-list cast (when player isn't melee-focused). |
| `IsPremonitionAble` | `(offset=0.05)` | `boolean, unitID` | Enemy about to finish a `Premonition`-list cast. |

`EnemyTeam(ROLE):New(ROLE, Refresh=0.05)`.

### `MultiUnits` — AoE / enemy counting (14 functions)

> **Two independent enemy-tracking systems. Knowing which one a function reads is the whole story.**
>
> **A) Nameplate-based** (always on, all specs). Driven by `NAME_PLATE_UNIT_ADDED/_REMOVED`. Every
> `GetBy*` counter iterates the live enemy-nameplate map and applies filters. **Counts are bounded by
> nameplate visibility** (distance + client settings).
>
> **B) CLEU "cleave" tracking** (ranged DPS only — registered iff `A.IamRanger and not A.IamHealer`).
> Records, per attacking source, which destination GUIDs it has hit recently. **Only `GetActiveEnemies`
> reads it.**

Raw getters (uncached, return live mutable references):

| Function | Returns | Description |
|---|---|---|
| `GetActiveUnitPlates()` | `table` | Enemy nameplates: `unitID → "…target"` token. |
| `GetActiveUnitPlatesAny()` | `table` | Enemy **and** friendly nameplates. |
| `GetActiveUnitPlatesGUID()` | `table` | Enemy plates keyed by GUID. **Empty in PvP** (`A.Zone == "pvp"`). |

Counters — `MultiUnits:Func(...)`. **Conventions:** `range = nil` means *no range filter* (count all),
not 0 yards; `count` is an **early-exit cap** (loop breaks at `total >= count`), not a filter; **totems
are excluded** everywhere except `GetByRangeCasting`.

| Function | Signature | Returns | Description | Cached |
|---|---|---|---|---|
| `GetBySpell` | `(spell, count)` | `total` | Enemies the `spell` is in range of. `spell` = id/name/ActionObject. | no |
| `GetBySpellIsFocused` | `(unitID, spell, count)` | `total, namePlateUnitID` | In-range enemies targeting `unitID`. | no |
| `GetByRange` | `(range, count)` | `total` | Enemies within `range`. **Fallback: returns 1 from `target` if in range.** | yes |
| `GetByRangeInCombat` | `(range, count, upTTD)` | `total` | Like above, only in-combat enemies (optional TTD floor). Same `target` fallback. | yes |
| `GetByRangeCasting` | `(range, count, kickAble, spells)` | `total` | Enemies currently casting (optionally only interruptible / specific `spells`). Totems counted. | yes |
| `GetByRangeTaunting` | `(range, count, upTTD)` | `total` | In-combat enemies needing a taunt (target isn't a tank, not a boss). | yes |
| `GetByRangeMissedDoTs` | `(range, count, deBuffs, upTTD)` | `total` | In-combat in-range enemies **missing** `deBuffs`. PvP: players only. | yes |
| `GetByRangeAppliedDoTs` | `(range, count, deBuffs, upTTD)` | `total` | …enemies that **already have** `deBuffs`. | yes |
| `GetByRangeIsFocused` | `(unitID, range, count)` | `total, namePlateUnitID` | In-range enemies targeting `unitID`. | yes |
| `GetByRangeAreaTTD` | `(range)` | `avgTTD` | Average TimeToDie of in-range enemies (0 if none). | yes |
| `GetActiveEnemies` | `(timer=5, skipClear)` | `count` | **The cleave/AoE counter** (CLEU, ranged-DPS only). See below. | yes |

**`GetActiveEnemies` — the AoE-vs-single decider.** From the combat log it finds, among attackers
hitting your current target, the largest set of distinct destination GUIDs any one source has hit within
`timer` seconds (the biggest cleave), and returns that count. **Falls back to
`GetByRangeInCombat(nil, 10)`** (nameplates, capped at 10) when CLEU is empty or the target isn't an
enemy. Prints an error if called on a non-ranged spec.

> So: the nameplate counters answer "how many enemy plates match filter X right now"; `GetActiveEnemies`
> answers "how many targets am I effectively cleaving" from combat-log evidence.

---

# Part 2 — The Healing Engine (`A.HealingEngine`)

Heal-target selection + group-health analytics. **Gated entirely behind `GetToggle(8, "HealingEngineAPI")`.**
Functions are **dot calls** (`HealingEngine.GetTarget()`), not colon.

> The old `docs/api/Globals.lua` stub was a **placeholder** — zero of these 29 functions, no `Data`
> table, no member model, no callbacks. The corrected stub adds them all.

## 2.1 Functions (29 public + 1 typo alias)

`unitID` = unit token; member/"thisUnit" = an entry of `Data.UnitIDs` (see §2.2).

### Target control
| Function | Signature | Returns | Description |
|---|---|---|---|
| `GetTarget` | `()` | `unitID, GUID` | Current heal target; both default `"none"`. |
| `SetTarget` | `(unitID, delay=0.5)` | nil | Force a heal target (resolves to canonical group unitID); locks for `delay` s. |
| `SetTargetMostlyIncDMG` | `(delay=0.5)` | nil | Force the most-damaged unit as target. |
| `SortMembers` | `()` | nil | Manually re-sort the member lists (by `incDMG` desc and HP/AHP asc). |
| `GetMembersAll` | `()` | `table` | Live `SortedUnitIDs` array (reference, not a copy). |
| `IsMostlyIncDMG` | `(unitID)` | `boolean, number` | Is `unitID` the most-injured unit, and its `incDMG`. |

### Group counting / selection
| Function | Signature | Returns | Description |
|---|---|---|---|
| `GetMinimumUnits` | `(fullPartyMinus=0, raidLimit=all)` | `number` | Heuristic minimum unit count worth AoE-healing given group size. |
| `GetBelowHealthPercentUnits` | `(hp, range)` | `number` | Members with `realHP <= hp` (optionally range-gated). Typo alias: `GetBelowHealthPercentercentUnits`. |
| `HealingByRange` | `(range, object, inParty, isMelee)` | `number` | Members healable at `range` passing `object:PredictHeal`. *(Inline `@usage` comment is stale — trust this signature.)* |
| `HealingBySpell` | `(object, inParty, isMelee)` | `number` | Members healable by `object` (uses `object:IsInRange`). |
| `GetBuffsCount` | `(ID, duration=0, source, byID)` | `number` | Player members with buff `ID` remaining > `duration`. |
| `GetDeBuffsCount` | `(ID, duration=0, source, byID)` | `number` | Player members with debuff `ID` remaining > `duration`. |
| `GetTimeToDieUnits` | `(timer)` | `number` | Members with `TimeToDie() <= timer`. |
| `GetTimeToDieMagicUnits` | `(timer)` | `number` | Members with `TimeToDieMagic() <= timer`. |

### Group health analytics
| Function | Signature | Returns | Description |
|---|---|---|---|
| `GetHealth` | `()` | `curHP, maxHP` | Latest group actual HP / max. `huge,huge` if no record. |
| `GetHealthAVG` | `()` | `number` | Group HP% (0–100). `100` if no record. |
| `GetHealthFrequency` | `(timer)` | `number` | Group HP% delta over last `timer` s. ⚠️ **`error()`s if `timer > 10`.** Cached (dynamic). |
| `GetIncomingDMG` | `()` | `total, perUnitAvg` | Group incoming DMG/s. Cached (static). |
| `GetIncomingHPS` | `()` | `total, perUnitAvg` | Group incoming heal/s. Cached (static). |
| `GetIncomingDMGAVG` / `GetIncomingHPSAVG` | `()` | `number` | …as % of group max HP per second. |
| `GetTimeToFullDie` | `()` | `number` | Average member TTD. `huge` if 0. |
| `GetTimeToFullHealth` | `()` | `number` | `(MHP − AHP) / GetIncomingHPS()`. |

### Options / mana / bosses
| Function | Signature | Returns | Description |
|---|---|---|---|
| `GetOptionsByUnitID` | `(unitID, unitGUID)` | `useDispel, useShields, useHoTs, useUtils, dbUnit` | **DB (un-modified)** per-unit options. *(Non-group fallback returns a 6th value — leftover bug; treat as 5.)* Don't mutate the returned table. |
| `IsManaSave` | `(unitID)` | `boolean \| nil` | True when mana-management says conserve (boss HP / thresholds / no Innervate). |
| `GetBossHealth` | `()` | `avgCur, avgMax, totalCur, totalMax, count` | Boss HP aggregates. |
| `GetBossHealthPercent` | `()` | `number` | Average boss HP%. |
| `GetBossTimeToDie` | `()` | `avgTTD, totalTTD, count` | Boss TTD aggregates. |
| `GetBossMain` | `()` | `unitID, GUID, focusCount` | Boss with the most holders (all nil if none). |

## 2.2 Member data model (`Data.UnitIDs[unitID]`, a.k.a. `thisUnit`)

Built by the per-unit `:Setup` metamethod; the `TMW_ACTION_HEALINGENGINE_UNIT_UPDATE` callback fires at
the end of it. **`HP`/`AHP` are the *modified* values used for sorting/targeting; `realHP`/`realAHP` are
the true values.**

| Field | Type | Meaning |
|---|---|---|
| `Unit` / `GUID` | string | Unit token / GUID. |
| `HP` | 0–100 | **Modified** health% (real + incoming heals/absorbs, then threat/pet multipliers + role offsets). Sort/target key. |
| `AHP` | 0–huge | **Modified** actual health (`HP * MHP / 100`, finalized *after* the callback). |
| `MHP` | 0–huge | Max actual health. |
| `realHP` / `realAHP` | 0–100 / 0–huge | True current health% / actual. |
| `Role` | string | `"TANK"`/`"HEALER"`/`"DAMAGER"`/`"NONE"`. Pets are `"DAMAGER"`. ("AUTO" resolved at Setup.) |
| `LUA` | string | Per-unit custom condition ("" = none). |
| `Enabled` | boolean | Eligible for selection (from DB). |
| `useDispel` / `useShields` / `useHoTs` / `useUtils` | boolean | DB toggles (utils = BoP/Freedom/etc.). |
| `isPlayer` / `isPet` / `isSelf` | boolean | Identity. |
| `isSelectAble` | boolean | Passed targetability (range/connected/not charmed/LoS/faction, alive-or-ressable). When false: `incDMG/incOffsetDMG=0`, `HP=realHP`. |
| `incDMG` | 0–huge | Real-time incoming damage (gated by `PredictOptions[2]`). |
| `incOffsetDMG` | 0–huge | `max(MHP * MultiplierIncomingDamageLimit, incDMG)`. |

Member metamethods (infrastructure, reachable on a member table): `CanSelect`, `CanRessurect`,
`SetupOffsets`, `Setup`, `HasLua`, `RunLua`.

## 2.3 `Data` table (`A.HealingEngine.Data`)

| Key | Type | Meaning |
|---|---|---|
| `IsRunning` | boolean | Engine loop + listeners active. |
| `Aura` | table | `{ Innervate = 29166 }`. |
| `UnitIDs` | table | `unitID → member`. `:Wipe()`. |
| `Frequency` | table | `{ Actual = {…{MHP,AHP,TIME}}, Temp = {} }` — drives all `GetHealth*` math (10s ring). |
| `SortedUnitIDs` | array | Selectable members sorted by HP/AHP asc. |
| `SortedUnitIDs_MostlyIncDMG` | array | Sorted by `incDMG` desc. |
| `QueueOrder` | table | Per-role FPS guard `{ useDispel/useHoTs/useShields/useUtils = {} }`. |
| `BossIDs` | table | `[bossGUID] = {holderUnitID=true,…}` + reverse map. |
| `frame` | Frame | Color/OnUpdate frame. |
| `sort_incDMG` / `sort_HP` / `sort_AHP` | function | Comparators for custom profiles. |

## 2.4 Callbacks

| Event | When | Args |
|---|---|---|
| `TMW_ACTION_HEALINGENGINE_UNIT_UPDATE` | Once per unit at end of `:Setup` (before `AHP` finalized). **The primary extension point.** | `(callbackEvent, thisUnit, db, QueueOrder)` — `thisUnit` is mutable (apply offsets/HoTs/incDMG here); set `QueueOrder.useX[Role]` to suppress redundant per-role work. |
| `TMW_ACTION_METAENGINE_UPDATE` | Color frame unit/mode change. | `("HealingEngine", "focus"\|"target", unit)` |

Reference implementation of the callback: the local `PerformByProfileHP`. Inside per-unit Lua, the self
reference is `Action.HealingEngine.Data.UnitIDs[thisunit]`.

---

# Part 3 — Supporting engines (verified index)

## 3.1 `A.CombatTracker` — the data layer under everything

CLEU-driven. **Real-health emulation:** for enemies where Blizzard only exposes %HP, it reconstructs
absolute HP from logged damage taken. `UnitHasRealHealth(unitID)` tells you which path applies. All
`Unit(unitID)` health/TTD/DMG methods sit on top of this. None of these are cache-wrapped.

| Method | Signature | Returns | Description |
|---|---|---|---|
| `UnitHealth` / `UnitHealthMax` | `(unitID)` | `number` | Real (emulated) current / max health; 0 if dead/unrecorded. |
| `UnitHasRealHealth` | `(unitID)` | `boolean` | Whether Blizzard health API is trustworthy here. |
| `CombatTime` | `(unitID="player")` | `seconds, GUID` | Seconds in combat (0 if not). |
| `GetLastTimeDMGX` | `(unitID, X=5)` | `number` | Damage taken in last `X` s (max 10). |
| `GetRealTimeDMG` / `GetRealTimeDPS` | `(unitID)` | `total, hits, phys, magic, swing` | Recent-window damage taken / done. |
| `GetDMG` / `GetDPS` | `(unitID)` | `total, hits, phys, magic` | Sustained damage taken / done (per combat-second). |
| `GetHEAL` / `GetHPS` | `(unitID)` | `total, hits` | Healing taken / done. |
| `GetSchoolDMG` | `(unitID)` | `Holy, Fire, Nature, Frost, Shadow, Arcane` | Per-school sustained DMG taken. **Player only.** |
| `GetSpellAmountX` / `GetSpellAmount` | `(unitID, spell[, X=5])` | `number` | Amount of `spell` taken (window / ever). **Player-taken only.** |
| `GetSpellLastCast` | `(unitID, spell)` | `secsSince, startTS` | `huge,0` if never. **Player + any players in PvP.** |
| `GetSpellCounter` | `(unitID, spell)` | `number` | Casts this fight. Same scope. |
| `GetAbsorb` | `(unitID, spell?)` | `number` | Absorb amount (by `spell` or total). **Players/pets only.** |
| `GetDR` | `(unitID, drCat)` | `DR_Tick, DR_Remain, DR_Application, DR_ApplicationMax` | Enemy DR state (`100,0,0,0` if none). |
| `TimeToDie` | `(unitID="target")` | `number` | Seconds to 0% (500 ≈ ∞, 0 = dead). |
| `TimeToDieX` | `(unitID="target", X)` | `number` | Seconds to `X`% HP. |
| `TimeToDieMagic` / `TimeToDieMagicX` | `(unitID="target"[, X])` | `number` | Magic-only variants. |
| `Debug` | `(command)` | `table\|nil` | `"wipe"` clears caches; `"data"` returns the `RealUnitHealth` struct. |

> The old stub documented only the ~12 **internal CLEU loggers** (`logDamage`, `logSwing`, …) and **none**
> of these 23 public methods. Corrected stub flips that: public methods are the API; loggers are marked internal.

## 3.2 `A.Player` — the player singleton

Singleton (`A.Player = { UnitID = "player" }`); methods are `Player:Method(...)`. Resource/power accessors
are **uncached live API reads**. Most retail powers (Focus, RunicPower, SoulShards, AstralPower, HolyPower,
Maelstrom, Chi, Insanity, ArcaneCharges, Fury, Pain, Essence) exist for cross-expansion source compat and
**return 0 on TBC** — only Mana/Rage/Energy/ComboPoints are live. Full per-method tables are in
[`_research/player.md`](_research/player.md); the categories:

- **Movement & state** (18): `IsMoving`/`IsMovingTime`/`IsStaying`, `IsFalling`→`(boolean, number)`,
  `IsMounted`, `IsStealthed`, `IsShooting`, `IsAttacking`, `IsBehind(x=2.5)`, `TargetIsBehind`, …
- **Casting & GCD** (11): `IsCasting`→`string|nil`, `IsChanneling`→`string|nil`, `CastRemains(spellID?)`,
  `CastCost` (uncached) vs `CastCostCache` (cached), `Execute_Time`, `GCDRemains`, `SpellHaste`, `HastePct`.
- **Self auras** (3): `CancelBuff`, `GetBuffsUnitCount(...)`→`(number,number)`, `GetDeBuffsUnitCount(...)`.
- **Cooldowns / swing / totems / runes** (9): `GetSwing(inv)`, `GetSwingShoot`, `GetTotemInfo`, `Rune`, `RuneTimeToX`.
- **Gear / bags / inventory / tier** (26): `AddTier`/`GetTier`/`HasTier`, `AddBag`/`GetBag`→`table|nil`,
  `Register*` weapon/ammo trackers, `HasShield`/`HasWeapon*`→`number|nil` itemID, `GetWeaponMeleeDamage`.
- **Resources**: Mana (incl. predicted `ManaP`/`ManaP*`), Rage, Energy (note `EnergyTimeToX(Amount, Offset)`
  — `Offset` is a **regen-rate multiplier**, not a time offset), Focus, ComboPoints (`ComboPoints(unitID="target")`).
- `HasGlyph(spell)` (WOTLK–BFA builds).

> Stub gotchas fixed: nil-union returns (`IsCasting`/`GetBag`/`HasWeapon*`), dropped varargs on
> `Get(De)BuffsUnitCount`, and the source typo **`Insanityrain`** (returns a drain rate, not a resource).

## 3.3 `A.TeamCache` + Base (Zone / Mode / Instance)

`A.TeamCache.Friendly` and `.Enemy` each have: `Size`, `MaxSize`, `Type` (`"raid"`/`"party"`/`"arena"`,
**`nil` when solo** — *not* `"none"`), `UNITs` (unitID→GUID), `GUIDs`, `IndexToPLAYERs`, `IndexToPETs`,
and role buckets `HEALER`/`TANK`/`DAMAGER`/`DAMAGER_MELEE`/`DAMAGER_RANGE`, plus `hasShaman` (Classic).
`A.TeamCache.threatData` (Classic) maps GUID → threat record.

Base.lua public helpers: `A:GetTimeSinceJoinInstance()`, `A:GetTimeDuel()`, `A:CheckInPvP()`. It owns the
globals `A.Zone`, `A.ZoneID`, `A.IsInInstance`, `A.IsInPvP`, `A.IsInDuel`, `A.IsInWarMode`, `A.InstanceInfo`.

## 3.4 `A.LossOfControl` — CC tracking

| Method | Signature | Returns | Description |
|---|---|---|---|
| `Get` | `(locType, name?)` | `duration, textureID` | Remaining seconds of a CC type; `0,0` if absent. |
| `IsMissed` | `(types)` | `boolean` | All listed CC types absent. |
| `IsValid` | `(applied, missed, exception?)` | `result, isApplied` | result = a wanted CC present AND no forbidden present; **2nd return is `isApplied`** (≥1 wanted present), not "partial". |
| `GetFrameData` | `()` | `textureID, duration, expirationTime` | Highest-priority current LoC (was missing from stub). |
| `GetFrameOrder` | `()` | `number` | 1 heavy / 2 medium / 3 light / 0 none (missing from stub). |
| `UpdateFrameData` | `()` | — | Recompute frame data (missing from stub). |
| `IsEnabled` | `(frame_type?)` | `boolean` | LoC frame enabled in toggles (missing from stub). |

## 3.5 `A.Pet` and `A.Bit`

- `Pet:PrevGCD(Index, Spell)` / `Pet:PrevOffGCD(Index, Spell)` → `boolean`. **`Spell` is required** (an
  ActionObject; the body calls `Spell:Info()`), and the return is a plain boolean — the old stub's
  optional `Spell?`/`boolean|ActionObject` was wrong.
- `A.Bit.isEnemy(Flags)` → hostile **or neutral**; `A.Bit.isPlayer(Flags)` → type **or** control player
  bit; `A.Bit.isPet(Flags)`. All take CLEU unit flags (number).

## 3.6 ActionObject (`<spell>:Method`)

The 73 `:` methods (`:IsReady`, `:IsReadyP`, `:IsCastable`, `:AbsentImun`, `:CanSafetyCastHeal`,
`:GetSpellAmount`, …) are defined in **`Modules/Actions.lua`** (not Base.lua), on the metatable returned by
`Action.Create` / `A:Add`. The existing `docs/api/ActionObject.lua` stub matches them 1:1 in name and
parameter order (types are generic but correct in shape); see [`_research/base.md`](_research/base.md) for
the verified signature spot-checks. Deep return-type verification of Actions.lua is a separate task.

---

## Appendix — Source gotchas worth preserving (not bugs to "fix")

- **`Unit:HasDeBuffs` is an alias of `SortDeBuffs`** (returns highest-remaining duration, not a boolean).
- **`HealingEngine.GetBelowHealthPercentercentUnits`** is a real typo alias kept for back-compat.
- **`HealingEngine.GetHealthFrequency(timer)` hard-`error()`s if `timer > 10`.**
- **`HealingEngine.GetOptionsByUnitID`** non-group fallback returns a 6th value (leftover bug); treat the
  contract as 5 returns.
- **`Player.Insanityrain`** is mis-spelled in source (missing the "D") and returns a *drain rate*.
- **`EnemyTeam:AverageTTD`** references undeclared `arena`/`arenas` locals — a latent source bug.
- **`MultiUnits` `range = nil`** means *no range filter*, and **`count`** is an early-exit cap, not a filter.
- **`GetActiveUnitPlatesGUID()` is empty in PvP.**

---
*Generated from a verified read of the engine source. Per-engine deep-dive research lives in
`docs/api/_research/{healing,unit,multiunits-combat,player,base}.md`.*
