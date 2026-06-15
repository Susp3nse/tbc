---@meta
--- GGL Action Framework - MultiUnits System Stubs
--- Enemy / AoE targeting. Invoke with colon syntax: `A.MultiUnits:GetByRange(8)`.
---
--- Two independent enemy-tracking systems back these functions:
---   1) Nameplate-based (always on, all specs): driven by NAME_PLATE_UNIT_ADDED/_REMOVED.
---      Backing table `activeUnitPlates` (enemy nameplate unitID -> "<unit>target" token) is the
---      workhorse every GetBy* counter iterates. Counting is bounded by visible enemy nameplates.
---   2) CLEU-based "cleave" detection (ranged DPS only, `A.IamRanger and not A.IamHealer`): driven by
---      COMBAT_LOG_EVENT_UNFILTERED, stored in `activeUnitCLEU`. Its only public consumer is
---      `GetActiveEnemies`. Empty for every other spec.
---
--- Filter conventions shared by all GetBy* counters:
---   - `count` is an early-exit cap (loop breaks once total >= count), not a filter; pass it as a perf
---     hint when you only need "are there at least N".
---   - `range` nil = no range filter (count all nameplates), not "0 yards".
---   - Totems are excluded from every counter except GetByRangeCasting.

---@class MultiUnits
local MultiUnits = {}

--- The cleave/AoE counter. CLEU-based, ranged-DPS only (prints an error if not A.IamRanger).
--- Returns the largest distinct-destination count any single attacker has cleaved within `timer`
--- seconds. Falls back to `GetByRangeInCombat(nil, 10)` (nameplate in-combat count) when CLEU is
--- empty or the current target is not an enemy.
--- Cached (MakeFunctionCachedDynamic, CLEU-specific timer constant).
---@param timer? number Seconds window for "recent" cleave hits (default 5).
---@param skipClear? boolean True = don't prune stale destinations (default nil).
---@return number total Best cleave count.
function MultiUnits:GetActiveEnemies(timer, skipClear) end

--- Raw enemy-nameplate table (mutable live reference, not a copy):
--- enemy nameplate unitID -> "<unit>target" token. Not cached.
---@return table
function MultiUnits:GetActiveUnitPlates() end

--- Raw enemy+friendly nameplate table (mutable live reference). Not cached.
---@return table
function MultiUnits:GetActiveUnitPlatesAny() end

--- Raw GUID-keyed enemy nameplate table (GUID -> target token).
--- Skipped entirely when A.Zone == "pvp" (table stays empty in PvP). Not cached.
---@return table
function MultiUnits:GetActiveUnitPlatesGUID() end

--- Counts enemy nameplates (non-totem) within `range`.
--- Single-target fallback: if the nameplate scan yields 0 but the current `target` is in range,
--- returns 1. Cached (MakeFunctionCachedDynamic).
---@param range? number Yards via Unit:CanInterract(range) (default nil = no range filter, count all).
---@param count? number Early-exit cap (default nil).
---@return number total
function MultiUnits:GetByRange(range, count) end

--- Counts in-combat, in-range non-totem enemies that already have the given DoTs (HasDeBuffs > 0).
--- Cached.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@param deBuffs table|number Debuff list (or single debuff) to check. Required.
---@param upTTD? number Minimum TimeToDie in seconds (default nil = no TTD floor).
---@return number total
function MultiUnits:GetByRangeAppliedDoTs(range, count, deBuffs, upTTD) end

--- Average TimeToDie of in-range non-totem enemies (0 if none). Cached.
---@param range? number Yards (default nil = all).
---@return number average
function MultiUnits:GetByRangeAreaTTD(range) end

--- Counts enemies currently casting (Unit:IsCasting()) in range, optionally filtered to interruptible
--- casts and/or specific spells. Totems are allowed here (they can cast). Cached.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@param kickAble? boolean True = only interruptible casts (default nil).
---@param spells? table|number|string Spell list, or single spellID/name, or nil = any cast.
---@return number total
function MultiUnits:GetByRangeCasting(range, count, kickAble, spells) end

--- Like GetByRange but only enemies with CombatTime() > 0, with optional TTD floor.
--- Same single-target `target` fallback (target must also be in combat). Cached.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@param upTTD? number Minimum TimeToDie in seconds (default nil = no TTD filter).
---@return number total
function MultiUnits:GetByRangeInCombat(range, count, upTTD) end

--- Counts in-range non-totem enemies whose "<unit>target" token equals `unitID`; also returns the
--- last matching nameplate unitID ("none" sentinel if none). Range-based sibling of
--- GetBySpellIsFocused. Cached.
---@param unitID string The unit enemies must be targeting.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@return number total, string namePlateUnitID
function MultiUnits:GetByRangeIsFocused(unitID, range, count) end

--- Counts in-combat, in-range non-totem enemies that are missing the given DoTs
--- (HasDeBuffs(deBuffs, true) == 0). In PvP only counts player units. Cached.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@param deBuffs table|number Debuff list (or single debuff) to check. Required.
---@param upTTD? number Minimum TimeToDie in seconds (default nil = no TTD floor).
---@return number total
function MultiUnits:GetByRangeMissedDoTs(range, count, deBuffs, upTTD) end

--- Counts in-combat enemies needing a taunt: not a player, target is not a tank, not a boss, in
--- range, optional TTD floor, not a totem. Cached.
---@param range? number Yards (default nil).
---@param count? number Early-exit cap (default nil).
---@param upTTD? number Minimum TimeToDie in seconds (default nil = no TTD filter).
---@return number total
function MultiUnits:GetByRangeTaunting(range, count, upTTD) end

--- Counts enemy nameplates (excluding totems) the `spell` is in range of. If `spell` is a table it
--- uses `spell:IsInRange(unit)`, else `A.IsInRange(spell, unit)`. Not cached.
---@param spell number|string|table SpellID/name, or an ActionObject spell table (range source). Required.
---@param count? number Early-exit cap (default nil = count all).
---@return number total
function MultiUnits:GetBySpell(spell, count) end

--- Counts in-range non-totem enemies whose "<unit>target" token equals `unitID`; also returns the
--- last matching nameplate unitID ("none" sentinel if none). Not cached.
---@param unitID string The unit enemies must be targeting.
---@param spell number|string|table SpellID/name, or an ActionObject spell table (range source). Required.
---@param count? number Early-exit cap (default nil).
---@return number total, string namePlateUnitID
function MultiUnits:GetBySpellIsFocused(unitID, spell, count) end
