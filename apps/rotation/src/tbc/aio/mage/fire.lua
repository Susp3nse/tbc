--- Fire Mage Module
--- Fire playstyle strategies
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "MAGE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Fire]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Fire]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- FIRE STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local fire_state = {
    scorch_stacks = 0,
    scorch_duration = 0,
}

local function get_fire_state(context)
    if context._fire_valid then return fire_state end
    context._fire_valid = true

    fire_state.scorch_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.IMPROVED_SCORCH) or 0
    fire_state.scorch_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.IMPROVED_SCORCH) or 0

    return fire_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Maintain Improved Scorch debuff
local Fire_MaintainScorch = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Scorch,
    setting_key = "fire_maintain_scorch",

    matches = function(context, state)
        if context.is_moving then return false end
        local refresh = context.settings.fire_scorch_refresh or Constants.SCORCH.DEFAULT_REFRESH
        return state.scorch_stacks < Constants.SCORCH.MAX_STACKS or state.scorch_duration < refresh
    end,

    execute = function(icon, context, state)
        return try_cast(A.Scorch, icon, TARGET_UNIT,
            format("[FIRE] Scorch - Stacks: %d, Duration: %.1fs", state.scorch_stacks, state.scorch_duration))
    end,
}

-- [2] Combustion (off-GCD)
local Fire_Combustion = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.Combustion,
    spell_target = PLAYER_UNIT,
    setting_key = "fire_use_combustion",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local hp_threshold = context.settings.fire_combustion_below_hp or 0
        if hp_threshold > 0 and context.target_hp > hp_threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Combustion, icon, PLAYER_UNIT, "[FIRE] Combustion")
    end,
}

-- [3] Icy Veins (off-GCD, cross-tree talent)
local Fire_IcyVeins = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.IcyVeins,
    spell_target = PLAYER_UNIT,
    setting_key = "fire_use_icy_veins",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.IcyVeins, icon, PLAYER_UNIT, "[FIRE] Icy Veins")
    end,
}

-- [4] Racial (off-GCD)
local Fire_Racial = {
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
            return A.Berserking:Show(icon), "[FIRE] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[FIRE] Arcane Torrent"
        end
        return nil
    end,
}

-- [6] Blast Wave (instant AoE talent — melee range)
local Fire_BlastWave = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.BlastWave,
    setting_key = "fire_use_blast_wave",

    matches = function(context, state)
        local min_enemies = context.settings.fire_melee_aoe_min_enemies or 2
        if context.enemy_count_melee < min_enemies then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.BlastWave, icon, TARGET_UNIT, "[FIRE] Blast Wave")
    end,
}

-- [7] Dragon's Breath (instant cone talent — melee range)
local Fire_DragonsBreath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.DragonsBreath,
    setting_key = "fire_use_dragons_breath",

    matches = function(context, state)
        local min_enemies = context.settings.fire_melee_aoe_min_enemies or 2
        if context.enemy_count_melee < min_enemies then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DragonsBreath, icon, TARGET_UNIT, "[FIRE] Dragon's Breath")
    end,
}

-- [8] Fire Blast weave (instant between casts)
local Fire_FireBlastWeave = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.FireBlast,
    setting_key = "fire_weave_fire_blast",

    execute = function(icon, context, state)
        return try_cast(A.FireBlast, icon, TARGET_UNIT, "[FIRE] Fire Blast")
    end,
}

-- [9] AoE rotation (when enough enemies)
local Fire_AoE = {
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
        -- Melee AoE preferred when enough enemies nearby
        if context.enemy_count_melee >= threshold and A.ArcaneExplosion:IsReady(PLAYER_UNIT) then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[FIRE] Arcane Explosion (AoE)")
        end
        -- Ranged AoE filler
        return try_cast(A.Flamestrike, icon, TARGET_UNIT, "[FIRE] Flamestrike (AoE)")
    end,
}

-- [10] Movement spell (instant while moving)
local Fire_MovementSpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local result, msg
        if s.fire_move_fire_blast then
            result, msg = try_cast(A.FireBlast, icon, TARGET_UNIT, "[FIRE] Fire Blast (moving)")
            if result then return result, msg end
        end
        if s.fire_move_ice_lance then
            result, msg = try_cast(A.IceLance, icon, TARGET_UNIT, "[FIRE] Ice Lance (moving)")
            if result then return result, msg end
        end
        if s.fire_move_cone_of_cold then
            result, msg = try_cast(A.ConeOfCold, icon, TARGET_UNIT, "[FIRE] Cone of Cold (moving)")
            if result then return result, msg end
        end
        if s.fire_move_arcane_explosion and context.in_melee_range then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[FIRE] Arcane Explosion (moving)")
        end
        return nil
    end,
}

-- [11] Primary filler spell (Fireball or Scorch)
local Fire_PrimarySpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local primary = context.settings.fire_primary_spell or "fireball"
        if primary == "scorch" then
            return try_cast(A.Scorch, icon, TARGET_UNIT, "[FIRE] Scorch (primary)")
        end
        return try_cast(A.Fireball, icon, TARGET_UNIT, "[FIRE] Fireball")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("fire", {
    named("MaintainScorch",  Fire_MaintainScorch),
    named("Combustion",      Fire_Combustion),
    named("IcyVeins",        Fire_IcyVeins),
    named("Racial",          Fire_Racial),
    named("BlastWave",       Fire_BlastWave),
    named("DragonsBreath",   Fire_DragonsBreath),
    named("FireBlastWeave",  Fire_FireBlastWeave),
    named("AoE",             Fire_AoE),
    named("MovementSpell",   Fire_MovementSpell),
    named("PrimarySpell",    Fire_PrimarySpell),
}, {
    context_builder = get_fire_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Mage]|r Fire module loaded")
