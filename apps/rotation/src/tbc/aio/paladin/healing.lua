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

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Paladin Healing]|r Core module not loaded!")
    return
end

if not NS.Constants then
    print("|cFFFF0000[Flux AIO Paladin Healing]|r Constants not found in Core!")
    return
end

local Unit = NS.Unit
local predict_effective_deficit = NS.predict_effective_deficit
local HEALING_REDUCTION_DEBUFFS = NS.HEALING_REDUCTION_DEBUFFS
local tsort = table.sort

-- ============================================================================
-- PARTY/RAID HEALING SYSTEM
-- ============================================================================

local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

-- Pre-allocated target pool (reused each scan, never reallocated in combat)
local healing_targets = {}
local healing_targets_count = 0
for i = 1, 40 do
    healing_targets[i] = { unit = nil, hp = 100, is_player = false, has_aggro = false,
                            is_tank = false, has_poison = false, has_disease = false,
                            has_magic = false, needs_cleanse = false,
                            has_healing_reduction = false, incoming_dps = 0, deficit = 0 }
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

local function scan_healing_targets()
    healing_targets_count = 0

    local in_raid = is_in_raid()
    local units_to_scan = in_raid and RAID_UNITS or PARTY_UNITS
    local max_units = in_raid and 40 or 5

    for i = 1, max_units do
        local unit = units_to_scan[i]
        if unit and _G.UnitExists(unit) and not _G.UnitIsDead(unit)
            and _G.UnitIsConnected(unit) and _G.UnitCanAssist("player", unit) then

            local in_range = false
            if _G.UnitIsUnit(unit, "player") then
                in_range = true
            else
                -- Use Flash of Light for range check (40yd)
                local spell_range = _G.IsSpellInRange("Flash of Light", unit)
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
                local entry = healing_targets[idx]
                if not entry then
                    entry = { unit = nil, hp = 100, is_player = false, has_aggro = false,
                              is_tank = false, has_poison = false, has_disease = false,
                              has_magic = false, needs_cleanse = false,
                              has_healing_reduction = false, incoming_dps = 0, deficit = 0 }
                    healing_targets[idx] = entry
                end
                entry.unit = unit
                local max_hp = _G.UnitHealthMax(unit)
                entry.hp = _G.UnitHealth(unit) / max_hp * 100
                entry.is_player = (unit == "player")
                entry.has_aggro = unit_has_aggro(unit)

                -- Effective HP accounts for incoming heals, absorbs, and damage
                local eff_deficit = predict_effective_deficit(unit, 1.5)
                entry.effective_hp = max_hp > 0 and (100 - (eff_deficit / max_hp) * 100) or entry.hp

                entry.is_tank = Unit(unit):IsTank() == true

                entry.deficit = _G.UnitHealthMax(unit) - _G.UnitHealth(unit)
                entry.incoming_dps = Unit(unit):GetDMG() or 0

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
        end
    end

    -- Mark stale entries so sort pushes them to the end (preserves pre-allocated tables)
    for i = healing_targets_count + 1, 40 do
        if healing_targets[i] then
            healing_targets[i].effective_hp = 999
        end
    end

    -- Sort by effective HP ascending (most in need first)
    if healing_targets_count > 1 then
        tsort(healing_targets, function(a, b)
            return a.effective_hp < b.effective_hp
        end)
    end

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
print("|cFF00FF00[Flux AIO Paladin]|r Healing module loaded")
