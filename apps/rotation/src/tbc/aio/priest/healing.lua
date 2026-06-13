-- Priest Healing Utilities
-- Shared healing target scanning for Holy and Discipline playstyles
-- Load order 5 (same as druid healing.lua)

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Healing]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local Constants = NS.Constants
local predict_effective_deficit = NS.predict_effective_deficit

-- Lua optimizations
local tsort = table.sort

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

local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0

-- Pre-allocate 40 entry tables
for i = 1, 40 do
    healing_targets[i] = {}
end

local function unit_has_aggro(unit_id)
    local threat = _G.UnitThreatSituation(unit_id)
    return threat and threat >= 2
end

local function is_in_raid()
    return _G.IsInRaid and _G.IsInRaid() or false
end

local function is_in_party()
    if is_in_raid() then return false end
    return _G.IsInGroup and _G.IsInGroup() or false
end

local scan_frame = 0

local function scan_healing_targets()
    -- Once-per-frame cache: TMW.time is updated each frame
    local now = _G.TMW and _G.TMW.time or 0
    if now == scan_frame and healing_targets_count > 0 then
        return healing_targets, healing_targets_count
    end
    scan_frame = now

    healing_targets_count = 0

    local in_raid = is_in_raid()
    local units_to_scan = in_raid and RAID_UNITS or PARTY_UNITS
    local max_units = in_raid and 40 or 5

    for i = 1, max_units do
        local unit = units_to_scan[i]
        if unit and _G.UnitExists(unit) and not _G.UnitIsDead(unit) and _G.UnitIsConnected(unit) and _G.UnitCanAssist("player", unit) then
            local in_range = false
            if _G.UnitIsUnit(unit, "player") then
                in_range = true
            else
                local spell_range = _G.IsSpellInRange("Flash Heal", unit)
                if spell_range == 1 then
                    in_range = true
                elseif spell_range == 0 then
                    in_range = false
                else
                    local _, unit_in_range = _G.UnitInRange(unit)
                    in_range = (unit_in_range == true)
                end
            end

            if in_range then
                healing_targets_count = healing_targets_count + 1
                local idx = healing_targets_count

                if not healing_targets[idx] then
                    healing_targets[idx] = {}
                end

                local entry = healing_targets[idx]
                entry.unit = unit
                local max_hp = _G.UnitHealthMax(unit)
                entry.hp = _G.UnitHealth(unit) / max_hp * 100
                entry.is_player = _G.UnitIsUnit(unit, "player")
                entry.has_aggro = unit_has_aggro(unit)
                entry.has_renew = has_renew(unit)
                entry.has_pws = has_pws(unit)
                entry.has_weakened_soul = has_weakened_soul(unit)

                -- Effective HP accounts for incoming heals, HoTs, absorbs, and damage
                local eff_deficit = predict_effective_deficit(unit, 1.5)
                entry.effective_hp = max_hp > 0 and (100 - (eff_deficit / max_hp) * 100) or entry.hp

                local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit)
                entry.is_tank = entry.has_aggro or (role == "TANK")
            end
        end
    end

    if healing_targets_count > 1 then
        tsort(healing_targets, function(a, b)
            if not a or not a.effective_hp then return false end
            if not b or not b.effective_hp then return true end
            return a.effective_hp < b.effective_hp
        end)
    end

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

local function get_lowest_hp_target(threshold)
    threshold = threshold or 100

    for i = 1, healing_targets_count do
        local entry = healing_targets[i]
        if entry and entry.effective_hp < threshold then
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

NS.is_in_raid = is_in_raid
NS.is_in_party = is_in_party
NS.scan_healing_targets = scan_healing_targets
NS.get_tank_target = get_tank_target
NS.get_lowest_hp_target = get_lowest_hp_target
NS.count_below_hp = count_below_hp

NS.PARTY_UNITS = PARTY_UNITS
NS.RAID_UNITS = RAID_UNITS

print("|cFF00FF00[Flux AIO Priest]|r Healing utilities loaded")
