--- Restoration Shaman Module
--- Restoration playstyle strategies: Chain Heal, Earth Shield maintenance, emergency healing
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "SHAMAN" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Restoration]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Menagerie Restoration]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local try_heal_cast_fmt = NS.try_heal_cast_fmt
local named = NS.named
local create_racial_strategy = NS.create_racial_strategy
local scan_healing_targets = NS.scan_healing_targets
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local format = string.format

-- ============================================================================
-- PARTY/RAID HEALING TARGETS
-- ============================================================================
-- Pre-allocated scan options (no {} in combat). range_spell gates by Chain Heal reach.
local RESTO_SCAN_OPTIONS = { range_spell = "Chain Heal" }

--- Get the most injured healing target below a threshold from cached scan state.
--- @param state table Restoration state returned by get_resto_state
--- @param threshold number effective HP% threshold
--- @return string|nil unit The unit ID, or nil if none below threshold
--- @return number hp The unit's effective HP%, or 100
local function get_lowest_target(state, threshold)
    local entries, count = state.heal_entries, state.heal_count
    if entries and count > 0 then
        local entry = entries[1]
        if entry and entry.unit and entry.effective_hp < threshold then
            return entry.unit, entry.effective_hp
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
    heal_entries = nil,
    heal_count = 0,
}

local FOCUS_UNIT = "focus"

local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    resto_state.heal_entries, resto_state.heal_count =
        scan_healing_targets(context, RESTO_SCAN_OPTIONS)

    -- Earth Shield tracked on focus target (typically tank)
    if _G.UnitExists(FOCUS_UNIT) then
        resto_state.earth_shield_charges = Unit(FOCUS_UNIT):HasBuffsStacks(Constants.BUFF_ID.EARTH_SHIELD, "player", true) or 0
        resto_state.earth_shield_duration = Unit(FOCUS_UNIT):HasBuffs(Constants.BUFF_ID.EARTH_SHIELD, "player", true) or 0
    else
        resto_state.earth_shield_charges = 0
        resto_state.earth_shield_duration = 0
    end

    resto_state.natures_swiftness_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.NATURES_SWIFTNESS) or 0) > 0
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
        local unit = get_lowest_target(state, threshold)
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
                local result, log_msg = try_heal_cast_fmt(A.HealingWave, icon, FOCUS_UNIT, "[RESTO]", "NS + Healing Wave",
                    "(focus) - HP: %.0f%%", focus_hp)
                if result then return result, log_msg end
            end
        end

        -- Lowest party member
        local unit, hp = get_lowest_target(state, threshold)
        if not unit then return nil end
        return try_heal_cast_fmt(A.HealingWave, icon, unit, "[RESTO]", "NS + Healing Wave",
            "(%s) - HP: %.0f%%", unit, hp)
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
        return try_heal_cast_fmt(A.EarthShield, icon, FOCUS_UNIT, "[RESTO]", "Earth Shield",
            "(focus) - Charges: %d", state.earth_shield_charges)
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
local Resto_TotemManagement = NS.make_totem_management({
    prefix = "[RESTO]",
    respect_is_moving = true,
    fire = { key = "resto_fire_totem", default = "searing", condition = "totem_fire_condition", lookup = NS.FIRE_TOTEM_SPELLS },
    earth = { key = "resto_earth_totem", default = "strength_of_earth", condition = "totem_earth_condition", lookup = NS.EARTH_TOTEM_SPELLS },
    water = { key = "resto_water_totem", default = "mana_spring", condition = "totem_water_condition", lookup = NS.WATER_TOTEM_SPELLS },
    air = { key = "resto_air_totem", default = "wrath_of_air", condition = "totem_air_condition", lookup = NS.AIR_TOTEM_SPELLS },
})

-- [5] Racial (off-GCD)
local RESTO_RACIAL_SPELLS = {
    { A.BloodFurySP, "Blood Fury (SP)" },
    { A.Berserking, "Berserking" },
}
local Resto_Racial = create_racial_strategy({ prefix = "RESTO", spells = RESTO_RACIAL_SPELLS })

-- [6] Chain Heal — primary healing spell (bounces to 3 targets, smart targeting)
local Resto_ChainHeal = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local primary = context.settings.resto_primary_heal or "chain_heal"
        if primary ~= "chain_heal" then return false end
        -- Only heal if someone needs it (below 90% HP)
        local unit = get_lowest_target(state, 90)
        if not unit then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Target the most injured unit — Chain Heal bounces handle the rest
        local unit, hp = get_lowest_target(state, 90)
        if not unit then return nil end
        return try_heal_cast_fmt(A.ChainHeal, icon, unit, "[RESTO]", "Chain Heal",
            "(%s) - HP: %.0f%%", unit, hp)
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
            local unit = get_lowest_target(state, 90)
            if unit then return true end
        else
            -- As emergency: heal if someone below 50%
            local unit = get_lowest_target(state, 50)
            if unit then return true end
        end
        return false
    end,

    execute = function(icon, context, state)
        local primary = context.settings.resto_primary_heal or "chain_heal"
        local threshold = (primary == "lesser_healing_wave") and 90 or 50
        local unit, hp = get_lowest_target(state, threshold)
        if not unit then return nil end
        return try_heal_cast_fmt(A.LesserHealingWave, icon, unit, "[RESTO]", "Lesser HW",
            "(%s) - HP: %.0f%%", unit, hp)
    end,
}

-- [8] Healing Wave — big slow heal
local Resto_HealingWave = {
    requires_combat = true,

    matches = function(context, state)
        if context.is_moving then return false end
        local primary = context.settings.resto_primary_heal or "chain_heal"
        if primary == "healing_wave" then
            local unit = get_lowest_target(state, 90)
            if unit then return true end
        else
            -- As fallback: heal if someone below 70%
            local unit = get_lowest_target(state, 70)
            if unit then return true end
        end
        return false
    end,

    execute = function(icon, context, state)
        local primary = context.settings.resto_primary_heal or "chain_heal"
        local threshold = (primary == "healing_wave") and 90 or 70
        local unit, hp = get_lowest_target(state, threshold)
        if not unit then return nil end
        return try_heal_cast_fmt(A.HealingWave, icon, unit, "[RESTO]", "Healing Wave",
            "(%s) - HP: %.0f%%", unit, hp)
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
print("|cFF00FF00[Menagerie Shaman]|r Restoration module loaded")
