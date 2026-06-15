-- Priest Healing Utilities
-- Shared healing target scanning for Holy and Discipline playstyles
-- Load order 5 (same as druid healing.lua)

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Priest Healing]|r Core module not loaded!")
    return
end

A = NS.A
local Unit = NS.Unit
local Constants = NS.Constants

-- ============================================================================
-- HOT / DEBUFF DETECTION UTILITIES
-- ============================================================================

local function has_weakened_soul(unit)
    if not unit or not _G.UnitExists(unit) then return true end
    return (Unit(unit):HasDeBuffs(Constants.DEBUFF_ID.WEAKENED_SOUL) or 0) > 0
end

local function has_renew(unit)
    if not unit or not _G.UnitExists(unit) then return false end
    return (Unit(unit):HasBuffs(A.Renew.ID, "player") or 0) > 0
end

local function has_pws(unit)
    if not unit or not _G.UnitExists(unit) then return false end
    return (Unit(unit):HasBuffs(Constants.BUFF_ID.POWER_WORD_SHIELD, nil, true) or 0) > 0
end

-- ============================================================================
-- PARTY/RAID HEALING SYSTEM (druid/paladin pattern)
-- ============================================================================

local PARTY_UNITS = NS.PARTY_UNITS
local RAID_UNITS = NS.RAID_UNITS

local healing_targets = {}
local healing_targets_count = 0

-- Pre-allocate 40 entry tables
for i = 1, 40 do
    healing_targets[i] = {}
end

-- Capture core's generic scanner NOW, before we publish our wrapper below. The
-- wrapper used to call NS.scan_healing_targets, but the export at the bottom
-- overwrote that field with the wrapper itself — so it recursed into itself and
-- stack-overflowed on the first in-combat scan. Hold a direct reference instead
-- (mirrors the paladin/healing.lua fix).
local core_scan_healing_targets = NS.scan_healing_targets

local function decorate_priest_heal_entry(entry, unit)
    entry.has_renew = has_renew(unit)
    entry.has_pws = has_pws(unit)
    entry.has_weakened_soul = has_weakened_soul(unit)

    local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit)
    entry.is_tank = entry.has_aggro or (role == "TANK")
end

local scan_frame = 0
local healing_scan_options = {
    range_spell = "Flash Heal",
    out = healing_targets,
    decorate_entry = decorate_priest_heal_entry,
}

local function scan_healing_targets()
    -- Once-per-frame cache: TMW.time is updated each frame
    local now = _G.TMW and _G.TMW.time or 0
    if now == scan_frame and healing_targets_count > 0 then
        return healing_targets, healing_targets_count
    end
    scan_frame = now

    local _, count = core_scan_healing_targets(nil, healing_scan_options)
    healing_targets_count = count

    return healing_targets, healing_targets_count
end

local function get_tank_target()
    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.is_tank then
            return entry
        end
    end

    return nil
end

local function count_below_hp(threshold)
    threshold = threshold or 100
    local count = 0
    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- EXPORT TO NAMESPACE
-- ============================================================================

NS.has_weakened_soul = has_weakened_soul
NS.has_renew = has_renew
NS.has_pws = has_pws

-- Namespaced so we never clobber core's shared NS.scan_healing_targets (other
-- classes / recovery middleware rely on the generic scanner).
NS.scan_priest_healing_targets = scan_healing_targets
NS.get_tank_target = get_tank_target
NS.count_below_hp = count_below_hp

NS.PARTY_UNITS = PARTY_UNITS
NS.RAID_UNITS = RAID_UNITS

print("|cFF00FF00[Menagerie Priest]|r Healing utilities loaded")
