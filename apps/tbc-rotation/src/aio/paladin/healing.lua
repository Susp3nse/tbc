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
-- Capture core's generic scanner NOW, before we publish our own wrapper below.
-- The wrapper used to call NS.scan_healing_targets, but our export at the bottom
-- overwrote that field with the wrapper itself — so it recursed into itself and
-- stack-overflowed on the first in-combat scan. Hold a direct reference instead.
local core_scan_healing_targets = NS.scan_healing_targets

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
    local _, count = core_scan_healing_targets(nil, healing_scan_options)
    healing_targets_count = count
    return healing_targets, healing_targets_count
end

-- ============================================================================
-- EXPORTS
-- ============================================================================
-- Publish under a class-namespaced key so we never clobber core's shared
-- NS.scan_healing_targets (other classes / recovery middleware rely on it).
NS.scan_paladin_healing_targets = scan_healing_targets

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Paladin]|r Healing module loaded")
