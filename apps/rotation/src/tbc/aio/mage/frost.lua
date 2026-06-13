--- Frost Mage Module
--- Frost playstyle strategies
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "MAGE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Frost]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Frost]|r Registry not found!")
    return
end

local A = NS.A
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- FROST STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local frost_state = {}

local function get_frost_state(context)
    if context._frost_valid then return frost_state end
    context._frost_valid = true

    return frost_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Icy Veins (off-GCD)
local Frost_IcyVeins = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.IcyVeins,
    spell_target = PLAYER_UNIT,
    setting_key = "frost_use_icy_veins",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.IcyVeins, icon, PLAYER_UNIT, "[FROST] Icy Veins")
    end,
}

-- [2] Summon Water Elemental
local Frost_WaterElemental = {
    requires_combat = true,
    is_burst = true,
    spell = A.SummonWaterElemental,
    spell_target = PLAYER_UNIT,
    setting_key = "frost_use_water_elemental",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.SummonWaterElemental, icon, PLAYER_UNIT, "[FROST] Summon Water Elemental")
    end,
}

-- [3] Cold Snap (reset frost CDs when IV + WE both expired)
local Frost_ColdSnap = {
    requires_combat = true,
    is_burst = true,
    spell = A.ColdSnap,
    spell_target = PLAYER_UNIT,
    setting_key = "frost_use_cold_snap",

    matches = function(context, state)
        -- Don't waste Cold Snap while Icy Veins is still active
        if context.icy_veins_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        -- Use when major frost CDs are on long cooldown (maximize Cold Snap value)
        local iv_cd = A.IcyVeins:GetCooldown() or 0
        if iv_cd < 20 then return false end
        -- Only check Water Elemental CD if the spell is actually talented
        if is_spell_available(A.SummonWaterElemental) then
            local we_cd = A.SummonWaterElemental:GetCooldown() or 0
            if we_cd < 20 then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ColdSnap, icon, PLAYER_UNIT, "[FROST] Cold Snap")
    end,
}

-- [4] Racial (off-GCD)
local Frost_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[FROST] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[FROST] Arcane Torrent"
        end
        return nil
    end,
}

-- [6] AoE rotation (when enough enemies)
local Frost_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if context.enemy_count_melee >= threshold then return true end
        if not context.is_moving and context.enemy_count_ranged >= threshold then return true end
        return false
    end,

    execute = function(icon, context, state)
        local threshold = context.settings.aoe_threshold or 0
        -- Cone of Cold weave (instant frontal)
        if context.enemy_count_melee >= threshold and A.ConeOfCold:IsReady(TARGET_UNIT) then
            return try_cast(A.ConeOfCold, icon, TARGET_UNIT, "[FROST] Cone of Cold (AoE)")
        end
        -- Melee AoE
        if context.enemy_count_melee >= threshold and A.ArcaneExplosion:IsReady(PLAYER_UNIT) then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[FROST] Arcane Explosion (AoE)")
        end
        -- Ranged AoE — Blizzard (channeled, synergy with Improved Blizzard)
        return try_cast(A.Blizzard, icon, TARGET_UNIT, "[FROST] Blizzard (AoE)")
    end,
}

-- [7] Movement spell (instant while moving)
local Frost_MovementSpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local result, msg
        if s.frost_move_fire_blast then
            result, msg = try_cast(A.FireBlast, icon, TARGET_UNIT, "[FROST] Fire Blast (moving)")
            if result then return result, msg end
        end
        if s.frost_move_ice_lance then
            result, msg = try_cast(A.IceLance, icon, TARGET_UNIT, "[FROST] Ice Lance (moving)")
            if result then return result, msg end
        end
        if s.frost_move_cone_of_cold then
            result, msg = try_cast(A.ConeOfCold, icon, TARGET_UNIT, "[FROST] Cone of Cold (moving)")
            if result then return result, msg end
        end
        if s.frost_move_arcane_explosion and context.in_melee_range then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[FROST] Arcane Explosion (moving)")
        end
        return nil
    end,
}

-- [8] Frostbolt (primary filler — 90%+ of all casts)
local Frost_Frostbolt = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Frostbolt,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Frostbolt, icon, TARGET_UNIT, "[FROST] Frostbolt")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("frost", {
    named("IcyVeins",        Frost_IcyVeins),
    named("WaterElemental",  Frost_WaterElemental),
    named("ColdSnap",        Frost_ColdSnap),
    named("Racial",          Frost_Racial),
    named("AoE",             Frost_AoE),
    named("MovementSpell",   Frost_MovementSpell),
    named("Frostbolt",       Frost_Frostbolt),
}, {
    context_builder = get_frost_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Mage]|r Frost module loaded")
