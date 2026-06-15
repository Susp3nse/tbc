--- Elemental Shaman Module
--- Elemental playstyle strategies: Lightning Bolt spam, Chain Lightning weaving, shock rotation
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "SHAMAN" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Elemental]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Menagerie Elemental]|r Registry not found!")
    return
end

local A = NS.A
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local create_racial_strategy = NS.create_racial_strategy
local ttd_too_short = NS.ttd_too_short
local ttd_below = NS.ttd_below
local try_aoe_fire_totem = NS.try_aoe_fire_totem
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- ELEMENTAL STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local ele_state = {
    clearcasting_charges = 0,
    elemental_mastery_active = false,
    flame_shock_duration = 0,
    chain_lightning_cd = 0,
}

-- Module-level LB counter for fixed_ratio mode (persists across frames, reset on CL cast)
-- Starts at 99 so Chain Lightning is available on first cast (opening CL)
local lb_casts_since_cl = 99
local last_combat_state = false

local function get_ele_state(context)
    if context._ele_valid then return ele_state end
    context._ele_valid = true

    -- Reset LB counter on combat exit so CL is available on first cast of next fight
    if last_combat_state and not context.in_combat then
        lb_casts_since_cl = 99
    end
    last_combat_state = context.in_combat

    ele_state.clearcasting_charges = context.clearcasting_charges
    ele_state.elemental_mastery_active = context.has_elemental_mastery
    ele_state.flame_shock_duration = context.flame_shock_duration
    ele_state.chain_lightning_cd = A.ChainLightning:GetCooldown() or 0

    return ele_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Elemental Mastery (off-GCD — guaranteed crit next spell)
local Ele_ElementalMastery = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.ElementalMastery,
    spell_target = PLAYER_UNIT,
    setting_key = "ele_use_elemental_mastery",

    matches = function(context, state)
        if ttd_too_short(context) then return false end
        -- Hold EM for Chain Lightning (guaranteed-crit CL is optimal)
        local rot = context.settings.ele_rotation_type or "cl_clearcast"
        if context.settings.ele_em_hold_for_cl and rot ~= "lb_only" and state.chain_lightning_cd > 0 then
            return false
        end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ElementalMastery, icon, PLAYER_UNIT, "[ELE] Elemental Mastery")
    end,
}

-- [2] Racial (off-GCD)
local ELE_RACIAL_SPELLS = {
    { A.BloodFurySP, "Blood Fury (SP)" },
    { A.Berserking, "Berserking" },
}
local Ele_Racial = create_racial_strategy({ prefix = "ELE", spells = ELE_RACIAL_SPELLS })

-- [4] Totem Management — drop/refresh configured totems
local Ele_TotemManagement = NS.make_totem_management({
    prefix = "[ELE]",
    respect_is_moving = true,
    fire = { key = "ele_fire_totem", default = "totem_of_wrath", condition = "totem_fire_condition", lookup = NS.FIRE_TOTEM_SPELLS },
    earth = { key = "ele_earth_totem", default = "strength_of_earth", condition = "totem_earth_condition", lookup = NS.EARTH_TOTEM_SPELLS },
    water = { key = "ele_water_totem", default = "mana_spring", condition = "totem_water_condition", lookup = NS.WATER_TOTEM_SPELLS },
    air = { key = "ele_air_totem", default = "wrath_of_air", condition = "totem_air_condition", lookup = NS.AIR_TOTEM_SPELLS },
})

-- [5] Fire Elemental (long CD summon)
local Ele_FireElemental = NS.make_fire_elemental("[ELE]", "ele_use_fire_elemental")

-- [6] Flame Shock — maintain DoT (instant, works while moving)
local Ele_FlameShock = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.FlameShock,
    setting_key = "ele_use_flame_shock",

    matches = function(context, state)
        -- Hold-shocks: rotation skips shocks; interrupt middleware still fires them.
        if context.settings.ele_shock_interrupt_only then return false end
        -- Only apply if DoT is not active
        if state.flame_shock_duration > 2 then return false end
        -- TTD gate: don't waste mana applying DoT on dying target
        local fs_ttd = context.settings.ele_fs_min_ttd or 0
        if ttd_below(context, fs_ttd) then return false end
        -- Mana conservation gate
        local mana_stop = context.settings.ele_mana_stop_shocks or 0
        if mana_stop > 0 and context.mana_pct < mana_stop then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.FlameShock, icon, TARGET_UNIT,
            format("[ELE] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
    end,
}

-- [7] Chain Lightning — per rotation type setting
local Ele_ChainLightning = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ChainLightning,

    matches = function(context, state)
        if context.is_moving then return false end

        -- CL must be off cooldown
        if state.chain_lightning_cd > 0 then return false end

        -- EM active: always consume with CL (guaranteed crit, highest value)
        if state.elemental_mastery_active then return true end

        local rot = context.settings.ele_rotation_type or "cl_clearcast"
        if rot == "lb_only" then return false end

        if rot == "cl_on_cd" then
            return true
        elseif rot == "cl_clearcast" then
            -- Use CL when we have clearcasting charges
            return state.clearcasting_charges >= 2
        elseif rot == "fixed_ratio" then
            local ratio = context.settings.ele_fixed_lb_per_cl or 3
            return lb_casts_since_cl >= ratio
        end

        return false
    end,

    execute = function(icon, context, state)
        local result = try_cast(A.ChainLightning, icon, TARGET_UNIT, "[ELE] Chain Lightning")
        if result then
            lb_casts_since_cl = 0  -- Reset counter on CL cast
        end
        return result
    end,
}

-- [8] Earth Shock — filler shock when FS DoT is ticking
local Ele_EarthShock = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.EarthShock,
    setting_key = "ele_use_earth_shock",

    matches = function(context, state)
        -- Hold-shocks: rotation skips shocks; interrupt middleware still fires them.
        if context.settings.ele_shock_interrupt_only then return false end
        -- Only use as filler when FS DoT is already active
        if state.flame_shock_duration <= 2 then return false end
        -- Mana conservation gate
        local mana_stop = context.settings.ele_mana_stop_shocks or 0
        if mana_stop > 0 and context.mana_pct < mana_stop then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ELE] Earth Shock (filler)")
    end,
}

-- [9] AoE rotation (when enough enemies)
local Ele_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if (context.enemy_count or 1) < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- CL is our primary AoE (3 targets)
        if state.chain_lightning_cd <= 0 then
            local result = try_cast(A.ChainLightning, icon, TARGET_UNIT, "[ELE] Chain Lightning (AoE)")
            if result then
                lb_casts_since_cl = 0
                return result
            end
        end
        -- Fire totems for AoE: only if fire slot is empty/expiring and no Fire Elemental
        if not ttd_too_short(context) then
            local result, log_msg = try_aoe_fire_totem(icon, context)
            if result then return result, log_msg end
        end
        -- Fall through to LB on primary target
        return nil
    end,
}

-- [10] Movement spell (instant while moving)
local Ele_MovementSpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local mana_stop = context.settings.ele_mana_stop_shocks or 0
        local mana_ok = mana_stop <= 0 or context.mana_pct >= mana_stop

        -- Flame Shock if DoT is down
        if mana_ok and state.flame_shock_duration <= 2 and context.settings.ele_use_flame_shock then
            local fs_ttd = context.settings.ele_fs_min_ttd or 0
            if not ttd_below(context, fs_ttd) then
                local result = try_cast(A.FlameShock, icon, TARGET_UNIT, "[ELE] Flame Shock (moving)")
                if result then return result end
            end
        end
        -- Earth Shock as filler while moving
        if mana_ok and context.settings.ele_use_earth_shock then
            return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ELE] Earth Shock (moving)")
        end
        return nil
    end,
}

-- [11] Lightning Bolt — primary filler (majority of casts)
local Ele_LightningBolt = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.LightningBolt,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local result = try_cast(A.LightningBolt, icon, TARGET_UNIT, "[ELE] Lightning Bolt")
        if result then
            lb_casts_since_cl = lb_casts_since_cl + 1
        end
        return result
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("elemental", {
    named("ElementalMastery", Ele_ElementalMastery),
    named("Racial",           Ele_Racial),
    named("TotemManagement",  Ele_TotemManagement),
    named("FireElemental",    Ele_FireElemental),    -- long CD, must be above filler
    named("FlameShock",       Ele_FlameShock),       -- DoT maintenance before AoE/fillers
    named("AoE",              Ele_AoE),
    named("ChainLightning",   Ele_ChainLightning),
    named("EarthShock",       Ele_EarthShock),
    named("MovementSpell",    Ele_MovementSpell),
    named("LightningBolt",    Ele_LightningBolt),    -- primary filler, always last
}, {
    context_builder = get_ele_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Shaman]|r Elemental module loaded")
