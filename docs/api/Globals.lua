---@meta
--- GGL Action Framework - Global Systems Stubs
--- LossOfControl, TeamCache, CombatTracker, Pet, HealingEngine, BitUtils

-- ============================================================================
-- Loss of Control System
-- ============================================================================

---@class LossOfControl
local LossOfControl = {}

--- Get CC duration and texture
---@param locType string CC type: "STUN", "ROOT", "SILENCE", "FEAR", "POLYMORPH", "SLEEP", "SNARE", "DISARM", "SCHOOL_INTERRUPT"
---@param name? string Specific spell name
---@return number duration CC duration remaining
---@return number texture Spell texture ID
function LossOfControl:Get(locType, name) end

--- Check if all specified CCs are absent
---@param types string|table CC types to check
---@return boolean missed All CCs are absent
function LossOfControl:IsMissed(types) end

--- Full CC validation
---@param applied string|table CCs that should be applied (MustBeApplied)
---@param missed string|table CCs that should be missed (MustBeMissed)
---@param exception? string|table Exception CCs
---@return boolean valid A wanted CC is applied AND no forbidden CC is present
---@return boolean isApplied At least one wanted CC is present (incl. Dwarf poison exception)
function LossOfControl:IsValid(applied, missed, exception) end

--- Highest-priority current LoC for frame display
---@return number texture Spell texture ID (0 if none)
---@return number duration CC duration (0 if none)
---@return number expirationTime CC expiration time (0 if none)
function LossOfControl:GetFrameData() end

--- Priority of the current LoC for frame ordering
---@return number order 1 = heavy, 2 = medium, 3 = light, 0 = none
function LossOfControl:GetFrameOrder() end

--- Manually recompute/sort the frame data
function LossOfControl:UpdateFrameData() end

--- Whether the LoC frame is enabled in the UI toggles
---@param frame_type? string "PlayerFrame" else the rotation frame
---@return boolean enabled Frame is enabled
function LossOfControl:IsEnabled(frame_type) end

--- Per-race { Applied, Missed } CC presets for Dwarf / Scourge / Gnome
---@type table
LossOfControl.GetExtra = {}

-- ============================================================================
-- Team Cache System
-- ============================================================================

---@class TeamCacheSide
---@field Size number Current member count
---@field MaxSize number Inferred max group size (5 party / 40 raid / arena bracket)
---@field Type string|nil "raid"/"party" (Friendly) or "arena" (Enemy); nil when solo
---@field UNITs table<string, string> unitID -> GUID mapping
---@field GUIDs table<string, string> GUID -> unitID mapping
---@field IndexToPLAYERs table Indexed player list
---@field IndexToPETs table Indexed pet list
---@field HEALER table<string, boolean> unitID set of healers
---@field TANK table<string, boolean> unitID set of tanks
---@field DAMAGER table<string, boolean> unitID set of damagers
---@field DAMAGER_MELEE table<string, boolean> unitID set of melee damagers
---@field DAMAGER_RANGE table<string, boolean> unitID set of ranged damagers
---@field hasShaman boolean Classic-only: a shaman is present in the party

---@class TeamCache
---@field Friendly TeamCacheSide Friendly unit cache
---@field Enemy TeamCacheSide Enemy unit cache
---@field threatData table Classic-only: GUID -> threat record { unit, isTanking, status, scaledPercent, threatValue }
local TeamCache = {}

-- ============================================================================
-- Combat Tracker System
-- ============================================================================

--- Public combat-tracking query API (A.CombatTracker). All methods use colon
--- syntax: A.CombatTracker:TimeToDie("target"). None are cache-wrapped.
--- "Real health" is a Classic/TBC emulation: where Blizzard only exposes %
--- health for enemies, the tracker reconstructs absolute HP from logged damage.
---@class CombatTracker
local CombatTracker = {}

--- Real max health. Returns Blizzard UnitHealthMax when UnitHasRealHealth is
--- true; else reconstructs from logged damage-taken ratios (Classic emulation).
---@param unitID string Unit ID
---@return number max Real max health (0 if dead/unrecorded)
function CombatTracker:UnitHealthMax(unitID) end

--- Real current health, same dual-path logic as UnitHealthMax.
---@param unitID string Unit ID
---@return number health Real current health (0 if dead/unrecorded)
function CombatTracker:UnitHealth(unitID) end

--- Whether the Blizzard health API is trustworthy for this unit
--- (true for self/pet/group/PvE NPCs; false for enemy players/pets pre-WOTLK).
---@param unitID string Unit ID
---@return boolean real
function CombatTracker:UnitHasRealHealth(unitID) end

--- Seconds the unit has been in combat (0 if not in combat). Also resets the
--- stored combat time when it detects the unit left combat.
---@param unitID? string Unit ID (default "player")
---@return number seconds Seconds in combat
---@return string GUID Resolved GUID
function CombatTracker:CombatTime(unitID) end

--- Sum of damage taken by the unit in the last X seconds (from the time-bucketed table).
---@param unitID string Unit ID
---@param X? number Window seconds, max 10 (default 5)
---@return number damage
function CombatTracker:GetLastTimeDMGX(unitID, X) end

--- Per-hit average damage TAKEN over the recent real-time window (<= GCD*2+1 s).
---@param unitID string Unit ID
---@return number total Total (all 0 if stale/no combat)
---@return number Hits Hit count
---@return number phys Physical damage
---@return number magic Magic damage
---@return number swing Swing damage
function CombatTracker:GetRealTimeDMG(unitID) end

--- Per-hit average damage DONE over the recent real-time window.
---@param unitID string Unit ID
---@return number total
---@return number Hits
---@return number phys
---@return number magic
---@return number swing
function CombatTracker:GetRealTimeDPS(unitID) end

--- Sustained damage TAKEN per second (damage / combatTime) if last hit <= 5s ago.
---@param unitID string Unit ID
---@return number total
---@return number Hits
---@return number phys
---@return number magic
function CombatTracker:GetDMG(unitID) end

--- Sustained damage DONE, per-hit average, if last done-hit <= 5s ago.
---@param unitID string Unit ID
---@return number total
---@return number Hits
---@return number phys
---@return number magic
function CombatTracker:GetDPS(unitID) end

--- Per-hit average healing TAKEN if last heal <= 5s ago.
---@param unitID string Unit ID
---@return number total
---@return number Hits
function CombatTracker:GetHEAL(unitID) end

--- Per-hit average healing DONE.
---@param unitID string Unit ID
---@return number total
---@return number Hits
function CombatTracker:GetHPS(unitID) end

--- Per-school sustained damage TAKEN (per combat-second). Only populated for
--- the player; 5s staleness per school.
---@param unitID string Unit ID
---@return number Holy
---@return number Fire
---@return number Nature
---@return number Frost
---@return number Shadow
---@return number Arcane
function CombatTracker:GetSchoolDMG(unitID) end

--- Last recorded amount of `spell` taken by the unit if within Xs. Player-taken
--- spells only. Numeric spell is resolved to a name.
---@param unitID string Unit ID
---@param spell number|string Spell ID or name
---@param X? number Window seconds (default 5)
---@return number amount (0 if none/stale)
function CombatTracker:GetSpellAmountX(unitID, spell, X) end

--- Same as GetSpellAmountX but with no time window (last value ever recorded).
---@param unitID string Unit ID
---@param spell number|string Spell ID or name
---@return number amount
function CombatTracker:GetSpellAmount(unitID, spell) end

--- Seconds since the unit last cast `spell`, plus the start timestamp. Returns
--- math.huge, 0 if never. Only @player self, and any players in PvP.
---@param unitID string Unit ID
---@param spell number|string Spell ID or name
---@return number seconds Seconds since last cast
---@return number startTimestamp Cast start timestamp
function CombatTracker:GetSpellLastCast(unitID, spell) end

--- How many times `spell` was cast this fight. Same player/PvP scope as GetSpellLastCast.
---@param unitID string Unit ID
---@param spell number|string Spell ID or name
---@return number count
function CombatTracker:GetSpellCounter(unitID, spell) end

--- Current absorb shield amount for `spell`, or total absorb if `spell` omitted.
--- Falls back to aura value if the logged value <= 0. Players / player-controlled pets only.
---@param unitID string Unit ID
---@param spell? number|string Spell ID or name (nil = total absorb)
---@return number absorb
function CombatTracker:GetAbsorb(unitID, spell) end

--- Diminishing-returns state for an ENEMY unit. Tick 100->50->25->0
--- (taunt 100->65->42->27->0). Returns 100,0,0,0 if no active DR.
---@param unitID string Unit ID
---@param drCat string DR category, e.g. "stun", "root", "fear", "kidney_shot"
---@return number DR_Tick Current DR tick value
---@return number DR_Remain Seconds to DR reset
---@return number DR_Application Current stacks
---@return number DR_ApplicationMax Stack cap
function CombatTracker:GetDR(unitID, drCat) end

--- Time to die: health / sustained DMG taken. Needs DMG>=1 and Hits>1, else 500.
---@param unitID? string Unit ID (default "target")
---@return number seconds 500 = effectively infinite, 0 = dead
function CombatTracker:TimeToDie(unitID) end

--- Like TimeToDie but to X% remaining health: (health - maxHP*X/100)/DMG.
---@param unitID? string Unit ID (default "target")
---@param X number Percent health floor to die *to*
---@return number seconds
function CombatTracker:TimeToDieX(unitID, X) end

--- Same as TimeToDie but uses the magic damage-taken component only.
---@param unitID? string Unit ID (default "target")
---@return number seconds
function CombatTracker:TimeToDieMagic(unitID) end

--- Magic-only variant of TimeToDieX.
---@param unitID? string Unit ID (default "target")
---@param X number Percent health floor
---@return number seconds
function CombatTracker:TimeToDieMagicX(unitID, X) end

--- Dev helper: "wipe" clears the target's real-health caches; "data" returns the
--- internal RealUnitHealth struct.
---@param command string "wipe" or "data"
---@return table|nil RealUnitHealth (for "data"), else nil
function CombatTracker:Debug(command) end

-- ----------------------------------------------------------------------------
-- Internal CLEU handlers (NOT on A.CombatTracker)
--
-- The following are private CLEU loggers on an internal `CombatTracker` local
-- table, wired into the OnEventCLEU / OnEventDR dispatch. They are fed the
-- unpacked CombatLogGetCurrentEventInfo() tuple and are NOT reachable via
-- A.CombatTracker. Listed here for reference only — do not call as public API:
--   logDamage, logSwing, logHealing, logAbsorb, update_logAbsorb,
--   remove_logAbsorb, logHealthMax, logLastCast, logDied, logDR,
--   logEnvironmentalDamage, AddToData
-- (The previously-stubbed `logUpdateAbsorb` is dead/commented-out in source.)
-- ----------------------------------------------------------------------------

-- ============================================================================
-- Pet System
-- ============================================================================

---@class Pet
local Pet = {}

--- Whether the Nth-prior pet GCD was the given spell (Prev.PetGCD[Index] == Spell:Info()).
--- Prints a warning if Index > LastRecord.
---@param Index number History index (1 = most recent)
---@param Spell ActionObject Spell to compare (required)
---@return boolean match
function Pet:PrevGCD(Index, Spell) end

--- Same as PrevGCD, for the pet off-GCD history.
---@param Index number History index (1 = most recent)
---@param Spell ActionObject Spell to compare (required)
---@return boolean match
function Pet:PrevOffGCD(Index, Spell) end

-- ============================================================================
-- Healing Engine System
-- ============================================================================

--- A single tracked member of the healing group (Data.UnitIDs[unitID]). Built by
--- the :Setup metamethod; mutated in the TMW_ACTION_HEALINGENGINE_UNIT_UPDATE callback.
---@class HealingEngineMember
---@field Unit string The unit token (unitID)
---@field GUID string Unit GUID
---@field HP number Modified health percent (0-100): realHP plus incoming heals/absorbs, then threat/pet/role adjustments. Drives sort/target logic.
---@field AHP number Modified actual health = HP * MHP / 100 (finalized after the update callback)
---@field MHP number Maximum actual health (A.Unit():HealthMax())
---@field realHP number True current health percent (0-100); 0 if MHP == 0
---@field realAHP number True current actual health (A.Unit():Health())
---@field Role string "TANK" | "HEALER" | "DAMAGER" | "NONE" (pets resolve to "DAMAGER")
---@field LUA string Per-unit custom Lua condition (empty string = none)
---@field Enabled boolean Whether the unit is eligible for SetHealingTarget (from DB)
---@field useDispel boolean DB toggle — dispel allowed on this unit
---@field useShields boolean DB toggle — shields allowed
---@field useHoTs boolean DB toggle — HoTs allowed
---@field useUtils boolean DB toggle — offensive/supportive utils (BoP, Freedom, etc.)
---@field isPlayer boolean True if a player (defaults to not isPet when the arg is omitted)
---@field isPet boolean True if a pet (from DB)
---@field isSelf boolean True if this unit's GUID == the player GUID
---@field isSelectAble boolean True if the unit passed eligibility (range/connected/not charmed/LOS/faction, alive-or-ressable, pet-allowed). When false, incDMG = 0 and HP = realHP.
---@field incDMG number Real-time incoming damage (GetRealTimeDMG()), gated by PredictOptions[2]
---@field incOffsetDMG number Threshold MHP * db.MultiplierIncomingDamageLimit, raised to incDMG if larger

--- A.HealingEngine.Data — the engine's full member / frequency / boss / queue model.
---@class HealingEngineData
---@field IsRunning boolean Whether the OnUpdate loop + listeners are active
---@field Aura table { Innervate = 29166 } — used by IsManaSave / ManaManagement
---@field UnitIDs table<string, HealingEngineMember> Map unitID -> member table. Has :Wipe().
---@field Frequency table { Actual = {}, Temp = {} } with :Wipe(). Actual = ring of { MHP, AHP, TIME } records (older than 10s pruned); Temp = current-tick accumulator. Drives all GetHealth*/frequency math.
---@field SortedUnitIDs string[] Selectable members sorted by HP/AHP ascending. :Wipe().
---@field SortedUnitIDs_MostlyIncDMG string[] Selectable members sorted by incDMG descending. :Wipe().
---@field QueueOrder table { useDispel={}, useHoTs={}, useShields={}, useUtils={} } keyed by Role — per-role FPS-saving guard. :Wipe().
---@field BossIDs table Boss tracking: [bossGUID] = { [holderUnitID]=true,... } plus reverse [holderUnitID] = bossGUID. :Wipe().
---@field frame table The color/OnUpdate frame ("TargetColor")
---@field isClassic boolean Convenience copy of StdUi.isClassic
---@field sort_incDMG fun(a: any, b: any): boolean Comparator exposed for custom profiles
---@field sort_HP fun(a: any, b: any): boolean Comparator exposed for custom profiles
---@field sort_AHP fun(a: any, b: any): boolean Comparator exposed for custom profiles

--- A.HealingEngine — group healing target-selection / metrics engine.
--- Public functions are plain `HealingEngine.X(...)` (no self / DOT form). The
--- engine only runs when GetToggle(8, "HealingEngineAPI") is enabled.
---
--- Primary extension point — callback fired once per unit at the end of :Setup,
--- before AHP is finalized:
---   TMW_ACTION_HEALINGENGINE_UNIT_UPDATE(callbackEvent, thisUnit, db, QueueOrder)
---     thisUnit  : HealingEngineMember (mutable; apply offsets/HoTs/incDMG here)
---     db        : active spec DB
---     QueueOrder: per-role guard table (set QueueOrder.useX[Role] to suppress redundant work)
--- (The color frame also fires TMW_ACTION_METAENGINE_UPDATE("HealingEngine", "focus"|"target", unit).)
---@class HealingEngine
---@field Data HealingEngineData The engine's live data model (members, frequency, bosses, queue)
local HealingEngine = {}

--- Manually re-sort SortedUnitIDs_MostlyIncDMG (incDMG desc) and SortedUnitIDs
--- (HP or AHP asc, per db.SelectSortMethod). No-op if #SortedUnitIDs <= 1.
function HealingEngine.SortMembers() end

--- Force the healing target to the most-damaged unit (SortedUnitIDs_MostlyIncDMG[1]).
--- No-op if the list is empty.
---@param delay? number Seconds to lock the target (default 0.5)
function HealingEngine.SetTargetMostlyIncDMG(delay) end

--- Resolve unitID -> GUID -> canonical group unitID and set it as the healing
--- target if found and not already set.
---@param unitID string Unit to force as the heal target
---@param delay? number Lock seconds (default 0.5)
function HealingEngine.SetTarget(unitID, delay) end

--- The live SortedUnitIDs array (all selectable members, sorted). Reference, not a copy.
---@return string[] members
function HealingEngine.GetMembersAll() end

--- Count of PLAYER members in SortedUnitIDs having buff `ID` with remaining > duration.
---@param ID number|string Aura id or name
---@param duration? number Min remaining seconds (default 0)
---@param source? any Caster filter
---@param byID? boolean Match by id
---@return number count
function HealingEngine.GetBuffsCount(ID, duration, source, byID) end

--- Count of PLAYER members having the debuff `ID` with remaining > duration.
---@param ID number|string Aura id or name
---@param duration? number Min remaining seconds (default 0)
---@param source? any Caster filter
---@param byID? boolean Match by id
---@return number count
function HealingEngine.GetDeBuffsCount(ID, duration, source, byID) end

--- Latest group health record (Frequency.Actual). Returns huge, huge if no record.
---@return number currentHP Current group actual HP
---@return number maxHP Group max HP
function HealingEngine.GetHealth() end

--- Group health percent (0-100). Returns 100 if no frequency record.
---@return number percent
function HealingEngine.GetHealthAVG() end

--- Group HP% delta over the last `timer` seconds. Positive = gain, negative =
--- loss, 0 = unchanged. ERRORS if timer > 10.
---@param timer number Lookback window seconds (max 10)
---@return number delta
function HealingEngine.GetHealthFrequency(timer) end

--- Group incoming damage per second (sum of member incDMG).
---@return number total Total group incoming DMG/s
---@return number average Per-unit average
function HealingEngine.GetIncomingDMG() end

--- Group incoming healing per second (sum of A.Unit():GetHEAL()).
---@return number total Total group incoming heal/s
---@return number average Per-unit average
function HealingEngine.GetIncomingHPS() end

--- Group incoming-DMG as a % of group max HP per second. 0 if no record.
---@return number percent
function HealingEngine.GetIncomingDMGAVG() end

--- Group incoming-HPS as a % of group max HP per second. 0 if no record.
---@return number percent
function HealingEngine.GetIncomingHPSAVG() end

--- Average member TimeToDie() across SortedUnitIDs. Returns huge if total is 0.
---@return number seconds
function HealingEngine.GetTimeToFullDie() end

--- Count of members whose TimeToDie() <= timer.
---@param timer number TTD threshold seconds
---@return number count
function HealingEngine.GetTimeToDieUnits(timer) end

--- Count of members whose TimeToDieMagic() <= timer.
---@param timer number Magic TTD threshold seconds
---@return number count
function HealingEngine.GetTimeToDieMagicUnits(timer) end

--- Group time-to-max-HP = (MHP - AHP) / GetIncomingHPS(). 0 if no record or HPS <= 0.
---@return number seconds
function HealingEngine.GetTimeToFullHealth() end

--- Heuristic minimum unit count worth AoE-healing given the current group size
--- (see body for the <=1 / <=3 / <=5 / >5 ladder).
---@param fullPartyMinus? number Subtract from small-group counts (default 0)
---@param raidLimit? number Cap for >5 groups (default = all members)
---@return number count
function HealingEngine.GetMinimumUnits(fullPartyMinus, raidLimit) end

--- Count of members with realHP <= hp (optionally range-gated by CanInterract(range)).
--- Alias: GetBelowHealthPercentercentUnits (real typo, kept for back-compat — do not "fix").
---@param hp number HP% threshold
---@param range? number Only count units passing CanInterract(range)
---@return number count
function HealingEngine.GetBelowHealthPercentUnits(hp, range) end

--- Typo alias of GetBelowHealthPercentUnits (kept for back-compat — do not "fix").
---@param hp number HP% threshold
---@param range? number Only count units passing CanInterract(range)
---@return number count
function HealingEngine.GetBelowHealthPercentercentUnits(hp, range) end

--- Count of members healable at `range` that pass object:PredictHeal(unit, nil, GUID).
---@param range number Range to check CanInterract
---@param object table Spell object exposing :PredictHeal
---@param inParty? boolean Only party members
---@param isMelee? boolean Only melee
---@return number count
function HealingEngine.HealingByRange(range, object, inParty, isMelee) end

--- Count of members healable by `object` (uses object:IsInRange instead of a numeric range).
---@param object table Spell object exposing :IsInRange and :PredictHeal
---@param inParty? boolean Only party members
---@param isMelee? boolean Only melee
---@return number count
function HealingEngine.HealingBySpell(object, inParty, isMelee) end

--- DB (un-modified) per-unit options. Resolves focus first (TBC+), else the group
--- member. Do not mutate the returned table.
--- NOTE: the non-group fallback path actually returns 6 values
--- (isPlayer, true, true, isPlayer, emptyTable, emptyTable) — the trailing 6th is
--- a leftover bug; the documented contract is the 5 returns below.
---@param unitID string Unit ID
---@param unitGUID? string Skips a UnitGUID() call
---@return boolean useDispel
---@return boolean useShields
---@return boolean useHoTs
---@return boolean useUtils
---@return table dbUnit Per-unit DB options table (do not mutate)
function HealingEngine.GetOptionsByUnitID(unitID, unitGUID) end

--- Whether `unitID` is the most-injured unit (SortedUnitIDs_MostlyIncDMG[1]).
---@param unitID string Unit ID
---@return boolean isMostInjured True if unitID is the most-injured unit
---@return number incDMG That unit's incoming damage (0 otherwise)
function HealingEngine.IsMostlyIncDMG(unitID) end

--- Current healing target. Both default to "none".
---@return string unitID Current healingTarget unitID
---@return string GUID Current healingTargetGUID
function HealingEngine.GetTarget() end

--- Boss health aggregate. All 0 if no bosses tracked.
---@return number avgCurrentHP Average current HP
---@return number avgMaxHP Average max HP
---@return number totalCurrentHP Total current HP
---@return number totalMaxHP Total max HP
---@return number bossCount Boss count
function HealingEngine.GetBossHealth() end

--- Average boss HP%. 0 if none.
---@return number percent
function HealingEngine.GetBossHealthPercent() end

--- Boss time-to-die aggregate. 0,0,0 if none.
---@return number avgTTD Average TTD
---@return number totalTTD Total TTD
---@return number bossCount Boss count
function HealingEngine.GetBossTimeToDie() end

--- Boss with the most holders. All nil if none.
---@return string|nil unitID Boss unitID
---@return string|nil GUID Boss GUID
---@return number|nil focusCount How many holders target it
function HealingEngine.GetBossMain() end

--- True when mana-management says conserve: db.ManaManagementManaBoss >= 0, boss
--- HP > 0, manaP <= bossHP, manaP <= ManaManagementManaBoss, no Innervate; if
--- unitID is given it must be above ManaManagementStopAtHP and TTD above
--- ManaManagementStopAtTTD. Returns nil (falsy) otherwise.
---@param unitID? string Stop-condition unit
---@return boolean|nil save
function HealingEngine.IsManaSave(unitID) end

-- ============================================================================
-- Bit Utilities
-- ============================================================================

---@class BitUtils
local BitUtils = {}

--- Check if CLEU unit flags indicate an enemy. True when the HOSTILE OR the
--- NEUTRAL reaction bit is set (neutral units count as enemy too).
---@param Flags number CLEU unit flags
---@return boolean isEnemy
function BitUtils.isEnemy(Flags) end

--- Check if CLEU unit flags indicate a player. True when the player TYPE bit OR
--- the player CONTROL bit is set.
---@param Flags number CLEU unit flags
---@return boolean isPlayer
function BitUtils.isPlayer(Flags) end

--- Check if CLEU unit flags indicate a pet (TYPE_PET bit set).
---@param Flags number CLEU unit flags
---@return boolean isPet
function BitUtils.isPet(Flags) end

-- ============================================================================
-- WoW Global API Stubs (commonly used)
-- ============================================================================

--- Get current time
---@return number time Current time in seconds
function GetTime() end

--- Get spell info
---@param spellID number|string Spell ID or name
---@return string name, string rank, number icon, number castTime, number minRange, number maxRange, number spellID
function GetSpellInfo(spellID) end

--- Get spell texture
---@param spellID number Spell ID
---@return string texture Texture path
function GetSpellTexture(spellID) end

--- Get unit health
---@param unitID string Unit ID
---@return number health Current health
function UnitHealth(unitID) end

--- Get unit max health
---@param unitID string Unit ID
---@return number health Maximum health
function UnitHealthMax(unitID) end

--- Get unit power
---@param unitID string Unit ID
---@param powerType? number Power type
---@return number power Current power
function UnitPower(unitID, powerType) end

--- Get unit max power
---@param unitID string Unit ID
---@param powerType? number Power type
---@return number power Maximum power
function UnitPowerMax(unitID, powerType) end

--- Check if unit exists
---@param unitID string Unit ID
---@return boolean exists Unit exists
function UnitExists(unitID) end

--- Check if unit is dead
---@param unitID string Unit ID
---@return boolean dead Unit is dead
function UnitIsDead(unitID) end

--- Check if unit is dead or ghost
---@param unitID string Unit ID
---@return boolean dead Unit is dead or ghost
function UnitIsDeadOrGhost(unitID) end

--- Get unit name
---@param unitID string Unit ID
---@return string name Unit name
---@return string realm Realm name
function UnitName(unitID) end

--- Get unit GUID
---@param unitID string Unit ID
---@return string guid Global unique identifier
function UnitGUID(unitID) end

--- Check if unit is player controlled
---@param unitID string Unit ID
---@return boolean isPlayer Is player
function UnitIsPlayer(unitID) end

--- Check if two unit IDs refer to the same unit
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean same Units are the same
function UnitIsUnit(unit1, unit2) end

--- Check if unit is enemy
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean isEnemy Units are enemies
function UnitIsEnemy(unit1, unit2) end

--- Check if unit is friend
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean isFriend Units are friends
function UnitIsFriend(unit1, unit2) end

--- Check if unit1 can assist unit2
---@param unit1 string First unit
---@param unit2 string Second unit
---@return boolean canAssist Can assist
function UnitCanAssist(unit1, unit2) end

--- Get unit class
---@param unitID string Unit ID
---@return string className Localized class name
---@return string classToken Class token (e.g., "WARRIOR")
---@return number classID Class ID
function UnitClass(unitID) end

--- Get unit level
---@param unitID string Unit ID
---@return number level Unit level
function UnitLevel(unitID) end

--- Get unit classification (elite, worldboss, rare, etc.)
---@param unitID string Unit ID
---@return string classification Classification string
function UnitClassification(unitID) end

--- Get unit creature type
---@param unitID string Unit ID
---@return string creatureType Creature type (Beast, Demon, Humanoid, etc.)
function UnitCreatureType(unitID) end

--- Check if unit is in range
---@param unitID string Unit ID
---@return boolean inRange Unit is in range
function UnitInRange(unitID) end

--- Check if unit is visible
---@param unitID string Unit ID
---@return boolean visible Unit is visible
function UnitIsVisible(unitID) end

--- Check if unit is connected (online)
---@param unitID string Unit ID
---@return boolean connected Unit is connected
function UnitIsConnected(unitID) end

--- Check if unit is affecting combat
---@param unitID string Unit ID
---@return boolean inCombat Unit is in combat
function UnitAffectingCombat(unitID) end

--- Get unit faction group
---@param unitID string Unit ID
---@return string faction "Horde" or "Alliance"
---@return string localizedFaction Localized faction name
function UnitFactionGroup(unitID) end

--- Get unit group role
---@param unitID string Unit ID
---@return string role "TANK", "HEALER", "DAMAGER", or "NONE"
function UnitGroupRolesAssigned(unitID) end

--- Get detailed threat situation
---@param unit1 string Attacking unit
---@param unit2 string Target unit
---@return boolean isTanking Is tanking
---@return number status Threat status (0-3)
---@return number scaledPercent Threat percentage (scaled)
---@return number rawPercent Raw threat percentage
---@return number threatValue Threat value
function UnitDetailedThreatSituation(unit1, unit2) end

--- Get threat situation
---@param unit1 string Unit
---@param unit2? string Target
---@return number status Threat status (0-3)
function UnitThreatSituation(unit1, unit2) end

--- Get unit ranged attack speed
---@param unitID string Unit ID
---@return number speed Attack speed in seconds
---@return number minDamage Minimum damage
---@return number maxDamage Maximum damage
---@return number bonusPos Positive bonus
---@return number bonusNeg Negative bonus
---@return number percent Damage percentage
function UnitRangedDamage(unitID) end

--- Get unit casting info
---@param unitID string Unit ID
---@return string|nil name, string text, number texture, number startTime, number endTime, boolean isTradeSkill, string castID, boolean notInterruptible, number spellID
function UnitCastingInfo(unitID) end

--- Get unit channel info
---@param unitID string Unit ID
---@return string|nil name, string text, number texture, number startTime, number endTime, boolean isTradeSkill, boolean notInterruptible, number spellID
function UnitChannelInfo(unitID) end

--- Get unit buff
---@param unitID string Unit ID
---@param index number Buff index
---@param filter? string Filter (e.g., "PLAYER")
---@return string name, number icon, number count, string debuffType, number duration, number expirationTime, string source, boolean isStealable, boolean nameplateShowPersonal, number spellID
function UnitBuff(unitID, index, filter) end

--- Get unit debuff
---@param unitID string Unit ID
---@param index number Debuff index
---@param filter? string Filter
---@return string name, number icon, number count, string debuffType, number duration, number expirationTime, string source, boolean isStealable, boolean nameplateShowPersonal, number spellID
function UnitDebuff(unitID, index, filter) end

--- Check if spell is usable
---@param spellID number Spell ID
---@return boolean usable Spell is usable
---@return boolean noMana Not enough resources
function IsUsableSpell(spellID) end

--- Check if spell is known
---@param spellID number Spell ID
---@return boolean known Spell is known
function IsSpellKnown(spellID) end

--- Check if spell is in range of unit
---@param spell number|string Spell ID or name
---@param unit string Target unit ID
---@return number|nil inRange 1 if in range, 0 if not, nil if not applicable
function IsSpellInRange(spell, unit) end

--- Get spell cooldown
---@param spellID number Spell ID
---@return number start Start time
---@return number duration Cooldown duration
---@return number enabled Is enabled
function GetSpellCooldown(spellID) end

--- Check if player is in combat (secure)
---@return boolean inCombat Player is in combat lockdown
function InCombatLockdown() end

--- Print message
---@param ... any Messages to print
function print(...) end

--- Get number of group members
---@return number count Number of group members
function GetNumGroupMembers() end

--- Get number of raid members (removed in Anniversary client, use IsInRaid)
---@deprecated Use IsInRaid() instead
---@return number count Number of raid members
function GetNumRaidMembers() end

--- Get number of party members (removed in Anniversary client, use IsInGroup)
---@deprecated Use IsInGroup() instead
---@return number count Number of party members
function GetNumPartyMembers() end

--- Check if player is in a group
---@param groupType? number Group type
---@return boolean inGroup Player is in a group
function IsInGroup(groupType) end

--- Check if player is in a raid
---@return boolean inRaid Player is in a raid
function IsInRaid() end

--- Get raid roster info
---@param index number Raid member index
---@return string name, number rank, number subgroup, number level, string class, string fileName, string zone, boolean online, boolean isDead, string role, boolean isML, string combatRole
function GetRaidRosterInfo(index) end

--- Get totem information
---@param slot number Totem slot (1=Fire, 2=Earth, 3=Water, 4=Air)
---@return boolean haveTotem Totem exists
---@return string totemName Totem name
---@return number startTime Start timestamp
---@return number duration Duration in seconds
---@return number icon Texture ID
function GetTotemInfo(slot) end

--- Get weapon enchant info (imbues)
---@return boolean hasMainHandEnchant Has main hand enchant
---@return number mainHandExpiration Main hand expiration time
---@return number mainHandCharges Main hand charges
---@return number mainHandEnchantID Main hand enchant ID
---@return boolean hasOffHandEnchant Has off hand enchant
---@return number offHandExpiration Off hand expiration time
---@return number offHandCharges Off hand charges
---@return number offHandEnchantID Off hand enchant ID
function GetWeaponEnchantInfo() end

--- Get inventory item ID
---@param unit string Unit ID
---@param slot number Inventory slot
---@return number|nil itemID Item ID or nil
function GetInventoryItemID(unit, slot) end

--- Get inventory item texture
---@param unit string Unit ID
---@param slot number Inventory slot
---@return string|nil texture Texture path or nil
function GetInventoryItemTexture(unit, slot) end

--- Get item count in bags
---@param itemID number Item ID
---@param includeBank? boolean Include bank
---@param includeCharges? boolean Count charges instead
---@return number count Item count
function GetItemCount(itemID, includeBank, includeCharges) end

--- Get combat log event info
---@return number timestamp, string subevent, boolean hideCaster, string sourceGUID, string sourceName, number sourceFlags, number sourceRaidFlags, string destGUID, string destName, number destFlags, number destRaidFlags, ...
function CombatLogGetCurrentEventInfo() end

--- Clear a table (WoW global utility)
---@param tbl table Table to clear
---@return table tbl The cleared table
function wipe(tbl) end

--- Format date/time string
---@param formatString? string Date format string
---@param time? number Unix timestamp
---@return string formatted Formatted date string
function date(formatString, time) end

-- ============================================================================
-- WoW Frame API
-- ============================================================================

--- Create a UI frame
---@param frameType string Frame type ("Frame", "Button", "EditBox", "ScrollFrame", etc.)
---@param name? string Global frame name
---@param parent? any Parent frame
---@param template? string XML template name (e.g., "BackdropTemplate")
---@return table frame The created frame
function CreateFrame(frameType, name, parent, template) end

--- Main UI parent frame
---@type table
UIParent = {}

--- Game tooltip frame
---@type table
GameTooltip = {}

--- Hide game tooltip
function GameTooltip_Hide() end

-- ============================================================================
-- WoW Timer API
-- ============================================================================

---@class C_Timer_NS
C_Timer = {}

--- Schedule a callback after a delay
---@param seconds number Delay in seconds
---@param callback function Function to call
function C_Timer.After(seconds, callback) end

--- Create a new ticker
---@param seconds number Interval in seconds
---@param callback function Function to call each tick
---@param iterations? number Max iterations (nil = infinite)
---@return table ticker Ticker handle with :Cancel() method
function C_Timer.NewTicker(seconds, callback, iterations) end

--- Create a one-shot timer
---@param seconds number Delay in seconds
---@param callback function Function to call
---@return table timer Timer handle with :Cancel() method
function C_Timer.NewTimer(seconds, callback) end

-- ============================================================================
-- WoW Constants & Global Tables
-- ============================================================================

--- Slash command handler table
---@type table<string, function>
SlashCmdList = {}

--- Class colors indexed by class token
---@type table<string, {r: number, g: number, b: number}>
RAID_CLASS_COLORS = {}

--- Inventory slot constants
---@type number
INVSLOT_HEAD = 1

-- ============================================================================
-- TellMeWhen Globals (TMW addon)
-- ============================================================================

---@class TMW
---@field GetSpellTexture fun(spellID: number): string|nil
TMW = {}

-- ============================================================================
-- Third-Party Addon Globals
-- ============================================================================

--- Toaster notification addon (optional)
---@type table|nil
Toaster = nil
