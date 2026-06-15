# MultiUnits & CombatTracker — Verified Public API

Source of truth:
- `docs/action/Modules/Engines/MultiUnits.lua` (516 lines)
- `docs/action/Modules/Engines/Combat.lua` (2853 lines)

Both engines attach their public surface to the global `A` (`_G.Action`) table.
All public methods are written `function A.X.Method(self, ...)` / `Method = function(self, ...)`,
so callers invoke them with colon syntax: `A.MultiUnits:GetByRange(8)`, `A.CombatTracker:TimeToDie("target")`.
The leading `self` parameter is omitted from the "call signature" column below.

---

# 1. MultiUnits  (enemy / AoE targeting)  — PRIORITY

`A.MultiUnits = {}` is declared at line 184; every public function is added with
`function A.MultiUnits.Name(self, ...)`. A private local table `MultiUnits` (line 55) holds the
backing state and the event handlers (`AddNameplate`, `OnEventCLEU`, etc.) — those are **internal**,
not on `A.MultiUnits`, and are not part of the public API.

## 1.1 How enemies are tracked — two independent data sources

There are **two completely separate enemy-counting mechanisms**. Understanding which one a function
reads is the whole story.

### A) Nameplate-based (always on, all specs)
Driven by Blizzard nameplate events `NAME_PLATE_UNIT_ADDED` / `_REMOVED` → `MultiUnits.AddNameplate` /
`RemoveNameplate`. Three backing tables (all `unitID → "unitIDtarget"` string maps, except the GUID one):

| Internal table | Public getter | Contents |
|---|---|---|
| `activeUnitPlates` | `GetActiveUnitPlates()` | **Enemy** nameplates only (`UnitCanAttack(player, unitID)` true). Key = nameplate unitID, value = that unit's `…target` token. |
| `activeUnitPlatesAny` | `GetActiveUnitPlatesAny()` | Enemy **and** friendly nameplates. |
| `activeUnitPlatesGUID` | `GetActiveUnitPlatesGUID()` | Enemy nameplates keyed by GUID → target token. **Skipped entirely when `A.Zone == "pvp"`** (table stays empty in PvP). |

`activeUnitPlates` is the workhorse: every `GetBy*` counting function iterates `pairs(activeUnitPlates)`
and applies range / combat / cast / DoT filters. Counting is therefore bounded by how many enemy
nameplates the client currently shows (nameplate visibility distance, addon settings).

### B) CLEU-based ("cleave" detection — ranged DPS only)
Driven by `COMBAT_LOG_EVENT_UNFILTERED` → `MultiUnits.OnEventCLEU`, stored in `activeUnitCLEU`.
**Only registered when `A.IamRanger and not A.IamHealer`** (`OnInitCLEU`, lines 139-151); for all other
specs the CLEU listener is removed and this data stays empty.

Structure: `activeUnitCLEU[SourceGUID] = { TS = <rounded ts>, [DestGUID] = TMW.time, … }` — i.e. for each
attacking source it records which destination GUIDs it has damaged/DoT'd recently. A source row is
created/updated only when the event's `DestFlags` is an enemy AND the event is a `*DAMAGE` event, or a
`SPELL_AURA_APPLIED`/`_REFRESH` DEBUFF cast by the player. Rows are weak tables (`__mode = "kv"`). Death
events (`UNIT_DIED`, `UNIT_DESTROYED`, `UNIT_DISSIPATES`, `PARTY_KILL`, `SPELL_INSTAKILL`) purge the dead
DestGUID from every source row. Combat-end (`PLAYER_REGEN_ENABLED`) and a guarded `PLAYER_REGEN_DISABLED`
wipe the whole table.

The only public consumer of the CLEU data is **`GetActiveEnemies`** (the cleave counter).

## 1.2 Public functions

Call syntax: `A.MultiUnits:Method(args)`. "Cached" = wrapped post-definition with a caching factory.

| Function | Call signature | Params (type — meaning — default) | Returns | Description | Cached |
|---|---|---|---|---|---|
| `GetActiveUnitPlates` | `()` | — | `table` — the live `activeUnitPlates` map (enemy nameplate unitID → `…target` token) | Raw enemy-nameplate table (mutable reference, not a copy). | no |
| `GetActiveUnitPlatesAny` | `()` | — | `table` — `activeUnitPlatesAny` (enemy + friendly nameplates) | Raw enemy+friendly nameplate table. | no |
| `GetActiveUnitPlatesGUID` | `()` | — | `table` — `activeUnitPlatesGUID` (GUID → target token); empty in PvP | Raw GUID-keyed enemy nameplate table. | no |
| `GetBySpell` | `(spell, count)` | `spell` (number\|string spellID/name **or** an ActionObject spell table — required) · `count` (number — early-exit cap; default nil = count all) | `number` total | Counts enemy nameplates (excluding totems) the `spell` is in range of. If `spell` is a table it uses `spell:IsInRange(unit)`, else `A.IsInRange(spell, unit)`. | no |
| `GetBySpellIsFocused` | `(unitID, spell, count)` | `unitID` (string — the unit enemies must be targeting) · `spell` (number\|string\|table — range source) · `count` (number — cap; default nil) | `number total, string namePlateUnitID` ("none" if none) | Counts in-range non-totem enemies whose `…target` is `unitID`; also returns the last matching nameplate unitID. | no |
| `GetByRange` | `(range, count)` | `range` (number — yards via `Unit:CanInterract(range)`; default nil = no range filter, counts all) · `count` (number — cap; default nil) | `number` total | Counts enemy nameplates (non-totem) within `range`. **Fallback:** if total is 0 but `target` is in range, returns 1. | **yes** (`MakeFunctionCachedDynamic`) |
| `GetByRangeInCombat` | `(range, count, upTTD)` | `range` (number — yards; default nil) · `count` (number — cap; default nil) · `upTTD` (number — minimum TimeToDie in s; default nil = no TTD filter) | `number` total | Like `GetByRange` but only enemies with `CombatTime() > 0` (and optional TTD floor). Same `target` fallback (must also be in combat). | **yes** |
| `GetByRangeCasting` | `(range, count, kickAble, spells)` | `range` (number; default nil) · `count` (number — cap; default nil) · `kickAble` (boolean — true ⇒ only interruptible casts; default nil) · `spells` (table of spellID/name, or single number/string, or nil = any cast) | `number` total | Counts enemies currently casting (via `Unit:IsCasting()`) in range, optionally filtered to interruptible and/or specific spells. Totems allowed (they can cast). | **yes** |
| `GetByRangeTaunting` | `(range, count, upTTD)` | `range` (number; default nil) · `count` (cap; default nil) · `upTTD` (min TTD; default nil) | `number` total | Counts in-combat enemies needing a taunt: not a player, target is not a tank, not a boss, in range, optional TTD, not a totem. | **yes** |
| `GetByRangeMissedDoTs` | `(range, count, deBuffs, upTTD)` | `range` (number; default nil) · `count` (cap; default nil) · `deBuffs` (table or number — debuff list to check; **required**) · `upTTD` (min TTD; default nil) | `number` total | Counts in-combat enemies in range that are **missing** the given DoTs (`HasDeBuffs(deBuffs,true)==0`), not totems. In PvP only counts player units. | **yes** |
| `GetByRangeAppliedDoTs` | `(range, count, deBuffs, upTTD)` | same as above; `deBuffs` **required** | `number` total | Mirror of the above: counts in-combat in-range enemies that **already have** the DoTs (`HasDeBuffs>0`). | **yes** |
| `GetByRangeIsFocused` | `(unitID, range, count)` | `unitID` (string — unit enemies must target) · `range` (number; default nil) · `count` (cap; default nil) | `number total, string namePlateUnitID` ("none" if none) | Counts in-range non-totem enemies whose target is `unitID`; returns last matching nameplate. (Range-based sibling of `GetBySpellIsFocused`.) | **yes** |
| `GetByRangeAreaTTD` | `(range)` | `range` (number; default nil = all) | `number` — **average** TimeToDie of in-range non-totem enemies (0 if none) | Sums `TimeToDie()` over in-range enemies and divides by count. | **yes** |
| `GetActiveEnemies` | `(timer, skipClear)` | `timer` (number — seconds window for "recent" cleave hits; default **5**) · `skipClear` (boolean — true ⇒ don't prune stale destinations; default nil) | `number` — best cleave count | **The cleave/AoE counter.** CLEU-based; ranged-DPS only. See below. | **yes** (`MakeFunctionCachedDynamic`, `CONST.CACHE_DEFAULT_TIMER_MULTIUNIT_CLEU`) |

### Counting / filter conventions (apply across all `GetBy*`)
- **`count` is an early-exit cap**, not a filter: the loop `break`s once `total >= count`. Passing it is
  a perf optimization when you only need "are there at least N".
- **`range` nil** means *no range filtering* (counts all nameplates), not "0 yards". Range is tested via
  `A.Unit(unit):CanInterract(range)` (or `spell:IsInRange` in `GetBySpell`).
- **Totems are excluded** from every counter except `GetByRangeCasting` (where totems can legitimately be casting).
- `GetByRange` / `GetByRangeInCombat` have a **single-target fallback**: if the nameplate scan yields 0
  but the current `target` satisfies the range (and combat, for InCombat), they return 1. The other
  counters have no such fallback.

### `GetActiveEnemies` (cleave detection) — detail
This is the function rotations call to decide AoE-vs-single. Logic (lines 455-515):
1. Prints an error if `not A.IamRanger` (it is meant for ranged specs only).
2. If `activeUnitCLEU` has data **and the current `target` is an enemy**, it takes the target's GUID and,
   for every source row that has hit that target GUID, counts how many *distinct destination GUIDs* that
   source has damaged within the last `timer` seconds (pruning stale entries unless `skipClear`). It
   collects each source's distinct-dest count, sorts descending, and returns the **highest** single count
   — i.e. "the biggest group any one attacker is currently cleaving across", used as the active-enemy
   estimate.
3. **Fallback:** if that yields 0 (CLEU empty/target not enemy), it returns
   `self:GetByRangeInCombat(nil, 10)` — the nameplate in-combat count capped at 10.
4. Result is cached with a CLEU-specific timer constant.

So: nameplate counters answer "how many enemy plates match filter X right now"; `GetActiveEnemies`
answers "how many targets am I effectively cleaving" from combat-log evidence, falling back to nameplates.

## 1.3 Stub discrepancies (`docs/api/MultiUnits.lua`)

The stub lists all 14 public functions with correct names and roughly correct return arity, but the
**types are uniformly `any`** and several meanings are wrong/missing:

1. **All params typed `any`.** Should be: `range`/`count`/`upTTD`/`timer` → `number`; `unitID` → `string`;
   `spell` → `number|string|table`; `spells` → `table|number|string`; `deBuffs` → `table|number`;
   `kickAble`/`skipClear` → `boolean`.
2. **`spell` / `deBuffs` marked optional (`?`) but are effectively required** — `GetBySpell`/`GetBySpellIsFocused`
   need a spell; `GetByRangeMissedDoTs`/`GetByRangeAppliedDoTs` error/misbehave without `deBuffs`.
3. **No caching noted.** 9 of the 14 functions are wrapped in `MakeFunctionCachedDynamic`
   (`GetByRange`, `…InCombat`, `…Casting`, `…Taunting`, `…MissedDoTs`, `…AppliedDoTs`, `…IsFocused`,
   `…AreaTTD`, `GetActiveEnemies`). The plain getters and the two `…Focused`/`GetBySpell*` non-cached ones are not.
4. **`GetActiveEnemies` description "Active enemies (CLEU)" understates it** — doesn't mention the ranged-only
   restriction, the `timer` default of 5, or the nameplate `GetByRangeInCombat(nil,10)` fallback.
5. **`GetByRange`/`…InCombat` single-target fallback (returns 1 from `target`) is undocumented.**
6. **`GetActiveUnitPlatesGUID` returns empty in PvP** — not noted (the stub just says "Nameplates by GUID").
7. Return-string of the `…IsFocused` functions is `"none"` sentinel, not nil — stub says `string` which is
   technically fine but the sentinel is worth a note.

---

# 2. CombatTracker

Two distinct surfaces exist:
- **Internal CLEU loggers** — a private local `CombatTracker` table (line 85). Members like `logDamage`,
  `logSwing`, `logHealing`, `logAbsorb`, `update_logAbsorb`, `remove_logAbsorb`, `logHealthMax`,
  `logLastCast`, `logDied`, `logDR`, `logEnvironmentalDamage`, `AddToData`. These are wired into
  `OnEventCLEU` / `OnEventDR` dispatch tables and fed by the combat log. **Not** the public query API.
- **Public query API** — `A.CombatTracker = { … }` (line 1959). This is what rotations call:
  `A.CombatTracker:TimeToDie("target")`, etc. All members are `Method = function(self, ...)`.

## 2.1 Public query API (`A.CombatTracker`)

Call syntax `A.CombatTracker:Method(args)`. GUID resolution uses `GetGUID(unitID)` (team-cache → `UnitGUID`)
unless noted. None of these are cache-wrapped (no `MakeFunctionCached*` in this file's public block).

| Function | Call signature | Params | Returns | Description |
|---|---|---|---|---|
| `UnitHealthMax` | `(unitID)` | `unitID` (string) | `number` (0 if dead/unrecorded) | Real max health. Returns Blizzard `UnitHealthMax` when `UnitHasRealHealth(unitID)`; else reconstructs from logged damage-taken ratios (Classic %-health emulation). |
| `UnitHealth` | `(unitID)` | `unitID` (string) | `number` (0 if dead/unrecorded) | Real current health, same dual-path logic as above. |
| `UnitHasRealHealth` | `(unitID)` | `unitID` (string) | `boolean` | Whether Blizzard health API is trustworthy for this unit (true for self/pet/group/PvE NPCs; false for enemy players/pets pre-WOTLK). |
| `CombatTime` | `(unitID)` | `unitID` (string; default `"player"`) | `number seconds, string GUID` | Seconds the unit has been in combat (0 if not in combat; also resets stored combat_time when it detects the unit left combat). Multi-return includes the resolved GUID. |
| `GetLastTimeDMGX` | `(unitID, X)` | `unitID` (string) · `X` (number — window seconds, max 10; default **5**) | `number` | Sum of damage taken by the unit in the last `X` seconds (from the `DS` time-bucketed table). |
| `GetRealTimeDMG` | `(unitID)` | `unitID` (string) | `number total, number Hits, number phys, number magic, number swing` | Per-hit average damage **taken** over the recent real-time window (≤ GCD*2+1 s). All 0 if stale/no combat. |
| `GetRealTimeDPS` | `(unitID)` | `unitID` (string) | `number total, number Hits, number phys, number magic, number swing` | Per-hit average damage **done** over the recent real-time window. |
| `GetDMG` | `(unitID)` | `unitID` (string) | `number total, number Hits, number phys, number magic` | Sustained damage **taken** per second (damage / combatTime) if last hit ≤ 5s ago. |
| `GetDPS` | `(unitID)` | `unitID` (string) | `number total, number Hits, number phys, number magic` | Sustained damage **done**, per-hit average, if last done-hit ≤ 5s ago. |
| `GetHEAL` | `(unitID)` | `unitID` (string) | `number total, number Hits` | Per-hit average healing **taken** if last heal ≤ 5s ago. |
| `GetHPS` | `(unitID)` | `unitID` (string) | `number total, number Hits` | Per-hit average healing **done**. |
| `GetSchoolDMG` | `(unitID)` | `unitID` (string) | `number Holy, Fire, Nature, Frost, Shadow, Arcane` | Per-school sustained damage **taken** (per combat-second). **Only populated for the player** (`School` table exists only on player's GUID); 5s staleness per school. |
| `GetSpellAmountX` | `(unitID, spell, X)` | `unitID` (string) · `spell` (number ID or string name) · `X` (window seconds; default **5**) | `number` (0 if none/stale) | Last recorded amount of `spell` taken by unit if within `X`s. Numeric spell is resolved to a name. **Player-taken spells only.** |
| `GetSpellAmount` | `(unitID, spell)` | `unitID` (string) · `spell` (number\|string) | `number` | Same as above but no time window (last value ever recorded). |
| `GetSpellLastCast` | `(unitID, spell)` | `unitID` (string) · `spell` (number\|string) | `number seconds, number startTimestamp` | Seconds since the unit last cast `spell`, plus the start timestamp. Returns `math.huge, 0` if never. **Only @player self, and any players in PvP** (CLEU `logLastCast` gate). |
| `GetSpellCounter` | `(unitID, spell)` | `unitID` (string) · `spell` (number\|string) | `number` | How many times `spell` was cast this fight. Same player/PvP scope as above. |
| `GetAbsorb` | `(unitID, spell)` | `unitID` (string) · `spell` (number\|string — optional; nil ⇒ total) | `number` | Current absorb shield amount for `spell`, or total absorb if `spell` omitted. Falls back to aura value if logged value ≤ 0. **Players / player-controlled pets only.** |
| `GetDR` | `(unitID, drCat)` | `unitID` (string) · `drCat` (string — DR category, e.g. `"stun"`,`"root"`,`"fear"`,`"kidney_shot"`; see source list lines 2291-2326) | `number DR_Tick, number DR_Remain, number DR_Application, number DR_ApplicationMax` | Diminishing-returns state for an **enemy** unit. Tick 100→50→25→0 (taunt 100→65→42→27→0); Remain = seconds to DR reset; Application = current stacks; ApplicationMax = cap. Returns `100,0,0,0` if no active DR. |
| `TimeToDie` | `(unitID)` | `unitID` (string; default `"target"`) | `number` (seconds; **500** = effectively infinite, 0 = dead) | health / sustained DMG taken. Needs DMG≥1 and Hits>1, else 500. Training-dummy totems excepted. |
| `TimeToDieX` | `(unitID, X)` | `unitID` (string; default `"target"`) · `X` (number — % health floor to die *to*) | `number` | Like `TimeToDie` but to `X`% remaining health: `(health - maxHP*X/100)/DMG`. |
| `TimeToDieMagic` | `(unitID)` | `unitID` (string; default `"target"`) | `number` | Same as `TimeToDie` but uses **magic** damage-taken component only. |
| `TimeToDieMagicX` | `(unitID, X)` | `unitID` (string; default `"target"`) · `X` (% health floor) | `number` | Magic-only variant of `TimeToDieX`. |
| `Debug` | `(command)` | `command` (string: `"wipe"` or `"data"`) | `RealUnitHealth` table (for `"data"`), else nil | Dev helper: `"wipe"` clears the target's real-health caches; `"data"` returns the internal `RealUnitHealth` struct. |

### Notes
- "Real health" (`UnitHealth`/`UnitHealthMax`) is a Classic/TBC emulation: where Blizzard only exposes %
  health for enemies, the tracker reconstructs absolute HP from logged damage taken. `UnitHasRealHealth`
  tells you which path applies. `TimeToDie*` and the `MultiUnits` TTD filters all sit on top of this.
- Several functions are intentionally **player-scoped** (school damage, spell amounts, last-cast, counter,
  absorb) because their CLEU loggers only record when the dest/source is the player (or any player in PvP).

## 2.2 Stub discrepancies (`docs/api/Globals.lua`, `CombatTracker` class)

The existing stub is **fundamentally wrong about scope**: it documents **only the 12 internal CLEU logger
functions** (`logDamage`, `logSwing`, `logHealing`, `logAbsorb`, `logUpdateAbsorb`, `update_logAbsorb`,
`remove_logAbsorb`, `logHealthMax`, `logLastCast`, `logDied`, `logDR`, `logEnvironmentalDamage`) and
**none** of the 23 public `A.CombatTracker:` query methods that rotations actually call.

1. **Every public query method is missing** from the stub: `UnitHealth`, `UnitHealthMax`,
   `UnitHasRealHealth`, `CombatTime`, `GetLastTimeDMGX`, `GetRealTimeDMG`, `GetRealTimeDPS`, `GetDMG`,
   `GetDPS`, `GetHEAL`, `GetHPS`, `GetSchoolDMG`, `GetSpellAmount(X)`, `GetSpellLastCast`,
   `GetSpellCounter`, `GetAbsorb`, `GetDR`, `TimeToDie(X)`, `TimeToDieMagic(X)`, `Debug`. These are the
   real API surface and should be the bulk of the stub.
2. **`logUpdateAbsorb` is documented but is dead/commented-out** in source (lines 785-807 are a block
   comment). The live function is `update_logAbsorb`. The stub lists both as if both exist.
3. **The documented loggers are `CombatTracker.foo(...)` free functions on a private table** — they are not
   reachable via `A.CombatTracker` at all, so documenting them under the public `CombatTracker` class is
   misleading. They should either be dropped or clearly marked "internal CLEU handler, not on `A.CombatTracker`".
4. The internal loggers are all typed `(...) any`; in reality they receive the unpacked
   `CombatLogGetCurrentEventInfo()` tuple (timestamp, event, sourceGUID, …) — but since they're internal
   this matters less than fixing item 1.
