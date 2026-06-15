-- Paladin Healing Module
-- Party/raid scanning and healing utilities for Holy Paladin
-- Adapted from Druid healing.lua — no HOT tracking (Paladin has no HoTs)
-- Loads after: core.lua, paladin/class.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "PALADIN" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Paladin Healing]|r Core module not loaded!")
    return
end

if not NS.Constants then
    print("|cFFFF0000[Menagerie Paladin Healing]|r Constants not found in Core!")
    return
end

local Unit = NS.Unit
local HEALING_REDUCTION_DEBUFFS = NS.HEALING_REDUCTION_DEBUFFS
local is_in_raid = NS.is_in_raid
local is_in_party = NS.is_in_party

-- ============================================================================
-- PARTY/RAID HEALING SYSTEM
-- ============================================================================

-- Pre-allocated target pool (reused each scan, never reallocated in combat)
local healing_targets = {}
local healing_targets_count = 0
for i = 1, 40 do
	    healing_targets[i] = { unit = nil, hp = 100, is_player = false, has_aggro = false,
	                            is_tank = false, has_poison = false, has_disease = false,
	                            has_magic = false, needs_cleanse = false,
	                            has_healing_reduction = false, incoming_dps = 0, deficit = 0 }
end

local function decorate_paladin_heal_entry(entry, unit)
    entry.is_tank = Unit(unit):IsTank() == true

    entry.has_healing_reduction = false
    for k = 1, #HEALING_REDUCTION_DEBUFFS do
        if (Unit(unit):HasDeBuffs(HEALING_REDUCTION_DEBUFFS[k]) or 0) > 0 then
            entry.has_healing_reduction = true
            break
        end
    end

    -- Check for dispellable debuffs
    entry.has_poison = _G.Action.AuraIsValid(unit, "UseDispel", "Poison") or false
    entry.has_disease = _G.Action.AuraIsValid(unit, "UseDispel", "Disease") or false
    entry.has_magic = _G.Action.AuraIsValid(unit, "UseDispel", "Magic") or false
    entry.needs_cleanse = entry.has_poison or entry.has_disease or entry.has_magic
end

local healing_scan_options = {
    range_spell = "Flash of Light",
    out = healing_targets,
    decorate_entry = decorate_paladin_heal_entry,
}

local function scan_healing_targets()
    local _, count = NS.scan_healing_targets(nil, healing_scan_options)
    healing_targets_count = count
    return healing_targets, healing_targets_count
end

local function get_tank_target()
    scan_healing_targets()

    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.is_tank then
            return entry
        end
    end

    return nil
end

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100
    scan_healing_targets()

    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
            return entry
        end
    end

    return nil
end

local function all_members_above_hp(threshold)
    scan_healing_targets()

    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
            return false
        end
    end

    return true
end

local function get_cleanse_target()
    scan_healing_targets()

    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.needs_cleanse then
            return entry
        end
    end

    return nil
end

-- ============================================================================
-- EXPORTS
-- ============================================================================
NS.scan_healing_targets = scan_healing_targets
NS.get_tank_target = get_tank_target
NS.get_lowest_hp_target = get_lowest_hp_target
NS.all_members_above_hp = all_members_above_hp
NS.get_cleanse_target = get_cleanse_target
NS.is_in_raid = is_in_raid
NS.is_in_party = is_in_party

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Paladin]|r Healing module loaded")
