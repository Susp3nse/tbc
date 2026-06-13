--- Restoration Shaman Module
--- Restoration playstyle strategies: Chain Heal, Earth Shield maintenance, emergency healing
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "SHAMAN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Restoration]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Restoration]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local resolve_totem_spell = NS.resolve_totem_spell
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format
local GetTotemInfo = _G.GetTotemInfo

-- ============================================================================
-- PARTY/RAID HEALING TARGET SCAN
-- ============================================================================
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

-- Pre-allocated healing target table (pre-populate entries to avoid {} in combat)
local MAX_HEALING_TARGETS = 40
local healing_targets = {}
for i = 1, MAX_HEALING_TARGETS do
    healing_targets[i] = { unit = nil, hp = 100, is_player = false }
end
local healing_targets_count = 0

local function is_in_raid()
    return _G.IsInRaid and _G.IsInRaid() or false
end

--- Scan party/raid for healing targets, sorted by HP ascending (most injured first)
local function scan_healing_targets()
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
                local spell_range = _G.IsSpellInRange("Chain Heal", unit)
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
                entry.unit = unit
                entry.hp = _G.UnitHealth(unit) / _G.UnitHealthMax(unit) * 100
                entry.is_player = _G.UnitIsUnit(unit, "player")
            end
        end
    end

    -- Sort by HP ascending (most injured first)
    -- Only sort the populated portion; comparator pre-allocated at module level
    if healing_targets_count > 1 then
        -- Manual insertion sort on small array (avoids table.sort closure allocation)
        for i = 2, healing_targets_count do
            local val = healing_targets[i]
            local val_hp = val.hp
            local j = i - 1
            while j >= 1 and healing_targets[j].hp > val_hp do
                healing_targets[j + 1] = healing_targets[j]
                j = j - 1
            end
            healing_targets[j + 1] = val
        end
    end
end

--- Get the most injured healing target below a threshold
--- @param threshold number HP% threshold
--- @return string|nil unit The unit ID, or nil if none below threshold
--- @return number hp The unit's HP%, or 100
local function get_lowest_target(threshold)
    scan_healing_targets()
    if healing_targets_count > 0 then
        local entry = healing_targets[1]
        if entry and entry.hp < threshold then
            return entry.unit, entry.hp
        end
    end
    return nil, 100
end

-- ============================================================================
-- RESTORATION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local resto_state = {
    earth_shield_charges = 0,
    earth_shield_duration = 0,
    natures_swiftness_active = false,
    mana_tide_cd = 0,
}

local FOCUS_UNIT = "focus"

local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    -- Earth Shield tracked on focus target (typically tank)
    if _G.UnitExists(FOCUS_UNIT) then
        resto_state.earth_shield_charges = Unit(FOCUS_UNIT):HasBuffsStacks(Constants.BUFF_ID.EARTH_SHIELD, "player", true) or 0
        resto_state.earth_shield_duration = Unit(FOCUS_UNIT):HasBuffs(Constants.BUFF_ID.EARTH_SHIELD, "player", true) or 0
    else
        resto_state.earth_shield_charges = 0
        resto_state.earth_shield_duration = 0
    end

    resto_state.natures_swiftness_active = context.has_natures_swiftness
    resto_state.mana_tide_cd = A.ManaTideTotem:GetCooldown() or 0

    return resto_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Nature's Swiftness Emergency — instant Healing Wave on critically low target
local Resto_NaturesSwiftnessEmergency = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.NaturesSwiftness,
    spell_target = PLAYER_UNIT,  -- NS is a self-buff, not cast on target
    setting_key = "resto_use_natures_swiftness",

    matches = function(context, state)
        local threshold = context.settings.resto_ns_hp_threshold or 30

        -- Check focus target first (tank)
        if _G.UnitExists(FOCUS_UNIT) and not _G.UnitIsDead(FOCUS_UNIT) then
            local focus_hp = _G.UnitHealth(FOCUS_UNIT) / _G.UnitHealthMax(FOCUS_UNIT) * 100
            if focus_hp < threshold then return true end
        end

        -- Check lowest party/raid member
        local unit, hp = get_lowest_target(threshold)
        if unit then return true end

        return false
    end,

    execute = function(icon, context, state)
        -- Pop Nature's Swiftness (off-GCD-ish — makes next Nature spell instant)
        if A.NaturesSwiftness:IsReady(PLAYER_UNIT) then
            return A.NaturesSwiftness:Show(icon), "[RESTO] Nature's Swiftness (emergency)"
        end
        return nil
    end,
}

-- [1b] Nature's Swiftness Healing Wave — consume NS with a big instant HW
local Resto_NSHealingWave = {
    requires_combat = true,

    matches = function(context, state)
        -- Only fire if NS buff is active (instant cast HW)
        return state.natures_swiftness_active
    end,

    execute = function(icon, context, state)
        -- Target the most injured unit
        local threshold = context.settings.resto_ns_hp_threshold or 30

        -- Focus target first
        if _G.UnitExists(FOCUS_UNIT) and not _G.UnitIsDead(FOCUS_UNIT) then
            local focus_hp = _G.UnitHealth(FOCUS_UNIT) / _G.UnitHealthMax(FOCUS_UNIT) * 100
            if focus_hp < threshold then
                if A.HealingWave:IsReady(FOCUS_UNIT) then
                    return A.HealingWave:Show(icon), format("[RESTO] NS + Healing Wave (focus) - HP: %.0f%%", focus_hp)
                end
            end
        end

        -- Lowest party member
        local unit, hp = get_lowest_target(threshold)
        if unit and A.HealingWave:IsReady(unit) then
            return A.HealingWave:Show(icon), format("[RESTO] NS + Healing Wave (%s) - HP: %.0f%%", unit, hp)
        end

        return nil
    end,
}

-- [2] Earth Shield Maintenance — keep on focus/tank (41-pt Restoration talent)
local Resto_EarthShieldMaintain = {
    spell = A.EarthShield,
    spell_target = FOCUS_UNIT,
    setting_key = "resto_maintain_earth_shield",

    matches = function(context, state)
        if not _G.UnitExists(FOCUS_UNIT) then return false end
        if _G.UnitIsDead(FOCUS_UNIT) then return false end
        local refresh_at = context.settings.resto_earth_shield_refresh or 2
        -- Refresh when charges low or missing
        if state.earth_shield_charges <= refresh_at then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.EarthShield:IsReady(FOCUS_UNIT) then
            return A.EarthShield:Show(icon),
                format("[RESTO] Earth Shield (focus) - Charges: %d", state.earth_shield_charges)
        end
        return nil
    end,
}

-- [3] Mana Tide Totem — proactive mana recovery
local Resto_ManaTide = {
    requires_combat = true,
    spell = A.ManaTideTotem,
    spell_target = PLAYER_UNIT,
    setting_key = "resto_use_mana_tide",

    matches = function(context, state)
        if state.mana_tide_cd > 0 then return false end
        local threshold = context.settings.resto_mana_tide_pct or 65
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ManaTideTotem, icon, PLAYER_UNIT,
            format("[RESTO] Mana Tide Totem - Mana: %.0f%%", context.mana_pct))
    end,
}

-- [4] Totem Management — maintain spec totems
local Resto_TotemManagement = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD
        local totem_ok = NS.totem_allowed
        if not context.fire_elemental_active and (s.resto_fire_totem or "searing") ~= "none" and totem_ok(s.totem_fire_condition, context.in_group) then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then return true end
        end
        local earth_setting = s.resto_earth_totem or "strength_of_earth"
        if earth_setting ~= "none" and totem_ok(s.totem_earth_condition, context.in_group) then
            local skip_earth = false
            if s.use_auto_tremor and context.totem_earth_active then
                local have, name = GetTotemInfo(2)
                if have and name and name:find("Tremor") then skip_earth = true end
            end
            if not skip_earth then
                if not context.totem_earth_active or context.totem_earth_remaining < threshold then return true end
            end
        end
        if (s.resto_water_totem or "mana_spring") ~= "none" and totem_ok(s.totem_water_condition, context.in_group) then
            if not context.totem_water_active or context.totem_water_remaining < threshold then return true end
        end
        if (s.resto_air_totem or "wrath_of_air") ~= "none" and totem_ok(s.totem_air_condition, context.in_group) then
            if not context.totem_air_active or context.totem_air_remaining < threshold then return true end
        end
        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD
        local totem_ok = NS.totem_allowed

        -- Fire totem (skip if "none", Fire Elemental active, or group-only while solo)
        if not context.fire_elemental_active and (s.resto_fire_totem or "searing") ~= "none" and totem_ok(s.totem_fire_condition, context.in_group) then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then
                local spell = resolve_totem_spell(s.resto_fire_totem or "searing", NS.FIRE_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[RESTO] Fire Totem"
                end
            end
        end

        -- Earth totem (skip if "none", Tremor active, or group-only while solo)
        local earth_setting = s.resto_earth_totem or "strength_of_earth"
        if earth_setting ~= "none" and totem_ok(s.totem_earth_condition, context.in_group) then
            local skip_earth = false
            if s.use_auto_tremor and context.totem_earth_active then
                local have, name = GetTotemInfo(2)
                if have and name and name:find("Tremor") then skip_earth = true end
            end
            if not skip_earth then
                if not context.totem_earth_active or context.totem_earth_remaining < threshold then
                    local spell = resolve_totem_spell(earth_setting, NS.EARTH_TOTEM_SPELLS)
                    if spell and spell:IsReady(PLAYER_UNIT) then
                        return spell:Show(icon), "[RESTO] Earth Totem"
                    end
                end
            end
        end

        -- Water totem (skip if "none" or group-only while solo)
        if (s.resto_water_totem or "mana_spring") ~= "none" and totem_ok(s.totem_water_condition, context.in_group) then
            if not context.totem_water_active or context.totem_water_remaining < threshold then
                local spell = resolve_totem_spell(s.resto_water_totem or "mana_spring", NS.WATER_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[RESTO] Water Totem"
                end
            end
        end

        -- Air totem (skip if "none" or group-only while solo)
        if (s.resto_air_totem or "wrath_of_air") ~= "none" and totem_ok(s.totem_air_condition, context.in_group) then
            if not context.totem_air_active or context.totem_air_remaining < threshold then
                local spell = resolve_totem_spell(s.resto_air_totem or "wrath_of_air", NS.AIR_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[RESTO] Air Totem"
                end
            end
        end

        return nil
    end,
}

-- [5] Racial (off-GCD)
local Resto_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        -- Caster shaman uses SP Blood Fury or Berserking
        if A.BloodFurySP:IsReady(PLAYER_UNIT) then return true end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFurySP:IsReady(PLAYER_UNIT) then
            return A.BloodFurySP:Show(icon), "[RESTO] Blood Fury (SP)"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[RESTO] Berserking"
        end
        return nil
    end,
}

-- [6] Chain Heal — primary healing spell (bounces to 3 targets, smart targeting)
local Resto_ChainHeal = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local primary = context.settings.resto_primary_heal or "chain_heal"
        if primary ~= "chain_heal" then return false end
        -- Only heal if someone needs it (below 90% HP)
        local unit, hp = get_lowest_target(90)
        if not unit then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Target the most injured unit — Chain Heal bounces handle the rest
        local unit, hp = get_lowest_target(90)
        if unit and A.ChainHeal:IsReady(unit) then
            return A.ChainHeal:Show(icon), format("[RESTO] Chain Heal (%s) - HP: %.0f%%", unit, hp)
        end
        return nil
    end,
}

-- [7] Lesser Healing Wave — fast emergency single-target
local Resto_LesserHealingWave = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        -- Used as primary heal or when someone is low and needs fast heal
        local primary = context.settings.resto_primary_heal or "chain_heal"
        if primary == "lesser_healing_wave" then
            local unit, hp = get_lowest_target(90)
            if unit then return true end
        else
            -- As emergency: heal if someone below 50%
            local unit, hp = get_lowest_target(50)
            if unit then return true end
        end
        return false
    end,

    execute = function(icon, context, state)
        local primary = context.settings.resto_primary_heal or "chain_heal"
        local threshold = (primary == "lesser_healing_wave") and 90 or 50
        local unit, hp = get_lowest_target(threshold)
        if unit and A.LesserHealingWave:IsReady(unit) then
            return A.LesserHealingWave:Show(icon), format("[RESTO] Lesser HW (%s) - HP: %.0f%%", unit, hp)
        end
        return nil
    end,
}

-- [8] Healing Wave — big slow heal
local Resto_HealingWave = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local primary = context.settings.resto_primary_heal or "chain_heal"
        if primary == "healing_wave" then
            local unit, hp = get_lowest_target(90)
            if unit then return true end
        else
            -- As fallback: heal if someone below 70%
            local unit, hp = get_lowest_target(70)
            if unit then return true end
        end
        return false
    end,

    execute = function(icon, context, state)
        local primary = context.settings.resto_primary_heal or "chain_heal"
        local threshold = (primary == "healing_wave") and 90 or 70
        local unit, hp = get_lowest_target(threshold)
        if unit and A.HealingWave:IsReady(unit) then
            return A.HealingWave:Show(icon), format("[RESTO] Healing Wave (%s) - HP: %.0f%%", unit, hp)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("restoration", {
    named("NaturesSwiftness",  Resto_NaturesSwiftnessEmergency),
    named("NSHealingWave",     Resto_NSHealingWave),
    named("EarthShieldMaint",  Resto_EarthShieldMaintain),
    named("ManaTide",          Resto_ManaTide),
    named("TotemManagement",   Resto_TotemManagement),
    named("Racial",            Resto_Racial),
    named("ChainHeal",         Resto_ChainHeal),
    named("LesserHealingWave", Resto_LesserHealingWave),
    named("HealingWave",       Resto_HealingWave),
}, {
    context_builder = get_resto_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Shaman]|r Restoration module loaded")
