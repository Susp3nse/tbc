# Base engine API research

Verification of the foundational layer of "The Action" framework: the **Action OBJECT**
(`ActionObject`), the **Base** engine globals/TeamCache, **UnitInspect**, and the remaining
global systems (`LossOfControl`, `TeamCache`, `Pet`, `BitUtils`).

Sources of truth read in full:
- `docs/action/Modules/Engines/Base.lua` (521 lines)
- `docs/action/Modules/Engines/UnitInspect.lua` (179 lines)

Cross-referenced (where the symbols actually live):
- `docs/action/Modules/Actions.lua` — **all** ActionObject (`A:Method`) definitions
- `docs/action/Modules/Engines/Combat.lua` — `A.LossOfControl` public table
- `docs/action/Modules/Components/Tools.lua` — `A.Bit` (BitUtils)
- `docs/action/Modules/Misc/PrevSpell.lua` — `Pet:PrevGCD` / `Pet:PrevOffGCD`

---

## ActionObject methods

**Key finding on location:** Base.lua does **not** define any ActionObject methods. Every
`ActionObject:Method` (the `:` methods like `:IsReady`, `:GetCooldown`, etc.) is defined as
`function A:<name>(...)` in **`docs/action/Modules/Actions.lua`** (73 such methods, lines
~234–1593), where `A` is the action-object metatable returned by `A:Add()` / `Action.Create()`.
The existing `docs/api/ActionObject.lua` stub documents these.

I verified every stubbed signature against the Actions.lua definitions. **All parameter names
and ordering in `ActionObject.lua` match the implementation exactly.** Spot-confirmed signatures:

| Method | Real signature (Actions.lua) | Stub correct? |
|---|---|---|
| `:IsReady` | `(unitID, skipRange, skipLua, skipShouldStop, skipUsable)` | yes |
| `:IsReadyP` | `(unitID, skipRange, skipLua, skipShouldStop, skipUsable)` | yes |
| `:IsReadyM` | `(unitID, skipRange, skipUsable)` | yes |
| `:IsReadyByPassCastGCD` | `(unitID, skipRange, skipLua, skipUsable)` | yes |
| `:IsReadyByPassCastGCDP` | `(unitID, skipRange, skipLua, skipUsable)` | yes |
| `:IsReadyToUse` | `(unitID, skipShouldStop, skipUsable)` | yes |
| `:IsCastable` | `(unitID, skipRange, skipShouldStop, isMsg, skipUsable)` | yes |
| `:IsRacialReady` / `:IsRacialReadyP` / `:AutoRacial` | `(unitID, skipRange, skipLua, skipShouldStop)` | yes |
| `:AbsentImun` | `(unitID, imunBuffs)` | yes |
| `:CanSafetyCastHeal` | `(unitID, offset)` | yes |
| `:GetSpellAmount` | `(unitID, X)` | yes |
| `:GetSpellAbsorb` / `:GetSpellTravelTime` | `(unitID)` | yes |
| `:DoSpellFilterProjectileSpeed` | `(owner)` | yes |
| `:IsExists` | `(replacementByPass)` | yes |
| `:IsUsable` | `(extraCD, skipUsable)` | yes |
| `:IsSuspended` | `(delay, reset)` | yes |
| `:IsSpellLastGCD` / `:IsSpellLastCastOrGCD` | `(byID)` | yes |
| `:GetSpellTexture` / `:GetColoredSpellTexture` / `:GetItemInfo` / `:GetItemIcon` / `:GetItemTexture` / `:GetColoredItemTexture` / `:GetColoredSwapTexture` | `(custom)` | yes |

The full method roster (73) present in Actions.lua matches the stub's method list 1:1 — no
ActionObject method is missing from the stub and the stub lists none that are absent from the
implementation. The stub's param types are generically `any`/optional, which is acceptable
(most are boolean flags / `unitID` strings); see "Stub discrepancies" for the one method the
stub mislabels structurally (`:Info` vs the documented getters — see Pet note below).

> Scope note: per the task, I did not exhaustively re-derive every return type from each method
> body in Actions.lua (that file is the ActionObject's home and is its own research target). The
> signatures and the where-it-lives question are the load-bearing facts and are confirmed above.

---

## Base helpers (`docs/action/Modules/Engines/Base.lua`)

Base.lua is the **Instance / Zone / Mode / Duel / TeamCache** engine. It defines a handful of
`A:`/`A.` helpers plus the event-driven machinery that populates `A.TeamCache` and `A.InstanceInfo`.
It also wires up LibThreatClassic2 (Classic-only) threat data into `TeamCache.threatData`.

### Public functions

| Function | Signature | Returns | Description |
|---|---|---|---|
| `A:GetTimeSinceJoinInstance()` | `()` | `number` | `TMW.time - A.TimeStampZone`, or `math.huge` if never set. Seconds since entering current instance/zone. |
| `A:GetTimeDuel()` | `()` | `number` | Seconds elapsed in current duel (`TMW.time - TimeStampDuel - CACHE_DEFAULT_OFFSET_DUEL`), or `0` if not dueling. |
| `A:CheckInPvP()` | `()` | `boolean` | True if in arena/bg/warmode, an active battlefield arena, or targeting an enemy player (1519 Eternal Palace excepted). Drives `A.IsInPvP`. |
| `A.UI_INFO_MESSAGE_IS_WARMODE(...)` | `(... )` → reads `arg2 = MSG` | `boolean` | True if the `UI_INFO_MESSAGE` payload is a warmode toggle on/off system string. |

### Global nilable fields set/owned by Base.lua

(Documented in the file's own header, lines 1–16; populated by the internal `OnEvent` handler.)

| Field | Type | Meaning |
|---|---|---|
| `A.Zone` | string | `"none"`, `"pvp"`, `"arena"`, `"party"`, `"raid"`, `"scenario"` |
| `A.ZoneID` | number | UiMapID from `GetBestMapForUnit("player")` (0 fallback) |
| `A.IsInInstance` | boolean | from `IsInInstance()` |
| `A.TimeStampZone` | number | `TMW.time` when zone last changed |
| `A.TimeStampDuel` | number | `TMW.time` at duel start |
| `A.IsInPvP` | boolean | result of `A:CheckInPvP()` (unless `A.IsLockedMode`) |
| `A.IsInDuel` | boolean | true while a duel is active |
| `A.IsInWarMode` | boolean | mirrors warmode-desired (or nil) |
| `A.TeamCache` | table | the TeamCache table (see below) |
| `A.InstanceInfo` | table | `{ Name, Type, difficultyID, ID, GroupSize, isRated, KeyStone }` |

### Internal (not public API, but load-bearing behavior)

- `OnEvent(event, ...)` — single handler registered via `Listener:Add("ACTION_EVENT_BASE", ...)`
  for every event in `GetEventInfo`. Categorizes events into CHALLENGE/INSTANCE/ZONE/ENTERING/
  TARGET/DUEL/UI_INFO_MESSAGE/UNITS and updates instance, mode/duel, and the TeamCache accordingly.
- Fires callbacks: `TMW_ACTION_MODE_CHANGED`, `TMW_ACTION_GROUP_UPDATE`, `TMW_ACTION_ENTERING`,
  `TMW_ACTION_DEPRECATED`, `TMW_ACTION_THREATLIB_UPDATE`.
- `A.IsLockedMode` — read (not defined here) to suppress mode/duel recomputation.
- TeamCache population uses `A.Unit(unit):IsHealer()/IsTank()/IsMelee()/Class()/InParty()` to
  bucket units into HEALER / TANK / DAMAGER / DAMAGER_MELEE / DAMAGER_RANGE.
- Threat block (Classic only, guarded by `ThreatLib`): `UpdateThreatData(unit)` /
  `CheckStatus()` write into `TeamCache.threatData[GUID] = { unit, isTanking, status,
  scaledPercent, threatValue }`. Negative threat is corrected by `+ 410065408`.

---

## UnitInspect (`docs/action/Modules/Engines/UnitInspect.lua`)

Caches equipped-item info per inspected unit GUID. Internally opens & immediately hides the
Blizzard InspectFrame (hooked once) to pull `GetInventoryItemID` data. Cache is wiped on
`PLAYER_REGEN_ENABLED`, `UNIT_INVENTORY_CHANGED`.

### Public API

| Function | Signature | Returns | Description |
|---|---|---|---|
| `A.GetUnitItem(unitID, invID, itemClassID, itemSubClassID, itemID, byPassDistance)` | `unitID` string, `invID` number (inventory slot), then **all optional**: `itemClassID` number, `itemSubClassID` number, `itemID` number, `byPassDistance` boolean | `boolean` or `nil` | True if the unit's item in `invID` matches the supplied class/subclass/item filters (any omitted filter is a wildcard). `byPassDistance` returns `true` when the unit can't be inspected (out of range) and no cached item exists. `nil` if no GUID. |
| `A.GetUnitItemInfo(unitID, invID)` | `unitID` string, `invID` number | `table` or `nil` | Returns the cached item record `{ itemClassID, itemSubClassID, itemID }` for the slot, inspecting on demand. `nil` if no GUID / nothing found. |

### Internal helpers

| Function | Signature | Notes |
|---|---|---|
| `GetGUID(unitID)` | `(unitID)` → GUID | Resolves via `TeamCacheFriendlyUNITs` / `TeamCacheEnemyUNITs`, falling back to `UnitGUID`. |
| `UnitInspectItem(unitID, invID)` | `(unitID, invID)` → cache record or nil | Gated by: out of combat (`CombatTracker:CombatTime("player")==0`), `UnitPlayerControlled`, `CheckInteractDistance(unitID,1)`, `CanInspect(unitID,false)`, and not self. `pcall(InspectUnit, unitID)`. |
| `UnitInspectWipe(...)` | `(unitID?)` | Wipe one unit's cache (if `unitID`) or the whole cache. |

Cache record shape: `{ itemClassID = ClassID, itemSubClassID = SubClassID, itemID = ID }`
(from `GetItemInfoInstant(ID)`).

> Note: the locale-bypass logic (`AllowedLocale`, `scriptErrors` CVar toggling) is present but
> **commented out** in the current source; only the ruRU `SpecializationSpecName` /
> `InspectTalentFrameSpecName` shim on `PLAYER_ENTERING_WORLD` is active.

---

## LossOfControl (`docs/action/Modules/Engines/Combat.lua`, `A.LossOfControl`)

The stub (`docs/api/Globals.lua`) documents `Get`, `IsMissed`, `IsValid` only. The real public
table has **more** methods, and the `IsValid` return semantics in the stub need a tweak.

| Method | Real signature | Returns | Description |
|---|---|---|---|
| `:Get(locType, name)` | `locType` string, `name?` string | `number duration, number textureID` | Remaining seconds of the named CC type (optionally a specific spell `name`); `0, 0` if absent. **Note: param is `name`, the stub's `name` is correct.** |
| `:IsMissed(MustBeMissed)` | `string` or `table` of types | `boolean` | True if **all** listed CC types are absent. (Stub calls the param `types` — fine, real name is `MustBeMissed`.) |
| `:IsValid(MustBeApplied, MustBeMissed, Exception)` | all `string`/`table` | `boolean result, boolean isApplied` | result = a wanted CC is applied AND no forbidden CC is present; `isApplied` = at least one wanted CC present (incl. Dwarf poison exception). |
| `:GetFrameData()` | `()` | `number textureID, number duration, number expirationTime` | Highest-priority current LoC for frame display; all 0 if none. **Missing from stub.** |
| `:GetFrameOrder()` | `()` | `number` | Priority of current LoC: 1 heavy, 2 medium, 3 light, 0 none. **Missing from stub.** |
| `:UpdateFrameData()` | `()` | — | Manually recompute/sort the frame data. **Missing from stub.** |
| `:IsEnabled(frame_type)` | `frame_type?` string (`"PlayerFrame"` else rotation) | `boolean` | Whether the LoC frame is enabled in UI toggles. **Missing from stub.** |
| `.GetExtra` | (field, table) | table | Per-race `{ Applied, Missed }` CC presets for Dwarf / Scourge / Gnome. **Missing from stub.** |

**Stub correction:** `IsValid` stub says it returns `(valid, partial)`; real second return is
`isApplied` (at-least-one-wanted-CC-present), not a generic "partial". The CC-type list in the
stub's `:Get` doc is illustrative; the implementation keys off `LossOfControlData[locType]` with
TBC type strings (e.g. STUN, ROOT, SILENCE, FEAR, POLYMORPH, INCAPACITATE, DISORIENT, SNARE,
ROOT, BANISH, CYCLONE, etc. — the full set appears in `GetExtra`).

---

## TeamCache (`docs/action/Modules/Engines/Base.lua`, `A.TeamCache`)

The real structure is **richer** than the `TeamCacheSide` stub. Each side (`Friendly`/`Enemy`)
is a table with these fields (Base.lua lines 47–76):

| Field | Type | Meaning |
|---|---|---|
| `Size` | number | current member count |
| `MaxSize` | number | inferred max group size (5 party / 40 raid / arena bracket) |
| `Type` | string\|nil | `"raid"` / `"party"` (Friendly) or `"arena"` (Enemy); nil when solo |
| `UNITs` | table | unitID → GUID |
| `GUIDs` | table | GUID → unitID |
| `IndexToPLAYERs` | table | index → player unitID |
| `IndexToPETs` | table | index → pet unitID |
| `HEALER` | table | unitID set of healers |
| `TANK` | table | unitID set of tanks |
| `DAMAGER` | table | unitID set of damagers |
| `DAMAGER_MELEE` | table | melee damagers |
| `DAMAGER_RANGE` | table | ranged damagers |
| `hasShaman` | boolean | Classic-only: a shaman present in party |

Top-level `A.TeamCache` also has `threatData` (Classic-only, GUID → threat record).

**Stub gaps:** `TeamCacheSide` stub lists only `UNITs, GUIDs, Type, IndexToPLAYERs, IndexToPETs`
and its `Type` enum says `"none"` — real code uses **`nil`** (not `"none"`) when solo, and the
Enemy `Type` is `"arena"`. Missing fields: `Size`, `MaxSize`, `HEALER`, `TANK`, `DAMAGER`,
`DAMAGER_MELEE`, `DAMAGER_RANGE`, `hasShaman`. `TeamCache` stub also omits `threatData`.

---

## Pet (`docs/action/Modules/Misc/PrevSpell.lua`, `A.Pet`)

| Method | Real signature | Returns | Description |
|---|---|---|---|
| `:PrevGCD(Index, Spell)` | `Index` number (1 = most recent), `Spell` ActionObject (required) | `boolean` | `Prev.PetGCD[Index] == Spell:Info()` — whether the Nth-prior pet GCD was that spell. Prints a warning if `Index > LastRecord`. |
| `:PrevOffGCD(Index, Spell)` | same | `boolean` | Same, for pet off-GCD history. |

**Stub corrections:** stub types `Spell` as optional (`Spell?`) and the return as
`boolean|ActionObject match`. In reality `Spell` is **required** (the body calls `Spell:Info()`
unconditionally — passing nil errors), and the return is a plain **`boolean`**, not an
ActionObject. There is no "return the previous spell" overload in this implementation.

---

## BitUtils (`docs/action/Modules/Components/Tools.lua`, `A.Bit`)

| Function | Real signature | Returns | Description |
|---|---|---|---|
| `.isEnemy(Flags)` | `Flags` number (CLEU unit flags) | `boolean` | `CL_REACTION_HOSTILE` **or** `CL_REACTION_NEUTRAL` bit set. (Stub omits that neutral also counts as enemy.) |
| `.isPlayer(Flags)` | `Flags` number | `boolean` | `CL_TYPE_PLAYER` **or** `CL_CONTROL_PLAYER` bit set. |
| `.isPet(Flags)` | `Flags` number | `boolean` | `CL_TYPE_PET` bit set. |

Stub signatures are correct (dot-functions, single `Flags` number). Only nuance: `isEnemy`
treats **neutral** units as enemy too, and `isPlayer` matches either the player *type* or
player *control* bit — worth noting in the descriptions.

---

## Stub discrepancies (summary)

| Stub file | Symbol | Issue | Fix |
|---|---|---|---|
| `Globals.lua` | `TeamCacheSide` | Missing `Size, MaxSize, HEALER, TANK, DAMAGER, DAMAGER_MELEE, DAMAGER_RANGE, hasShaman` | add them |
| `Globals.lua` | `TeamCacheSide.Type` | Says `"none"` when solo | real value is **`nil`**; Enemy.Type is `"arena"` |
| `Globals.lua` | `TeamCache` | Missing `threatData` field (Classic) | add as `table` |
| `Globals.lua` | `LossOfControl` | Missing `GetFrameData`, `GetFrameOrder`, `UpdateFrameData`, `IsEnabled`, `GetExtra` | add them |
| `Globals.lua` | `LossOfControl:IsValid` | 2nd return labeled `partial` | rename to `isApplied` (at-least-one-applied) |
| `Globals.lua` | `Pet:PrevGCD` / `:PrevOffGCD` | `Spell?` optional + `boolean\|ActionObject` return | `Spell` is **required**; return is **`boolean`** |
| `Globals.lua` | `BitUtils.isEnemy` | doc omits neutral-counts-as-enemy | note `HOSTILE or NEUTRAL` |
| `Globals.lua` | `BitUtils.isPlayer` | doc omits control-player bit | note `TYPE_PLAYER or CONTROL_PLAYER` |
| `ActionObject.lua` | (all 73 methods) | none structural — signatures match Actions.lua | param types are generic `any` but correct in name/order |
| — | (location) | Stubs imply ActionObject lives near Base | it lives in **`Modules/Actions.lua`**; Base.lua defines none of them |

### Action.lua (top-level framework) cross-check

`docs/api/Action.lua` documents `Action.Create`, toggles, GCD/ping, queue/interrupt, timers,
`Action.Unit`, etc. These are defined across `docs/action/Action.lua` and `Modules/*` (e.g.
`Action.ToggleMode/ToggleRole/ToggleBurst/BurstIsON` at Action.lua:10449–10512,
`InterruptIsValid` at 12240, `GetToggle/SetToggle` at 13270/13102). The factory `A:Add` (aka
`Action.Create`) returns the metatable-backed ActionObject documented above. No discrepancies
found in the spot-checked framework signatures; full framework verification is its own task.
