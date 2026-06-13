--- Combat Rogue Module
--- Combat playstyle strategies: Sinister Strike builder, SnD/Rupture/Evis finishers
--- Blade Flurry + Adrenaline Rush cooldown management

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "ROGUE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Combat]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Combat]|r Registry not found!")
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
-- COMBAT STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local combat_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    blade_flurry_active = false,
    adrenaline_rush_active = false,
    expose_armor_active = false,
    pooling = false,
}

local function get_combat_state(context)
    if context._combat_valid then return combat_state end
    context._combat_valid = true

    combat_state.pooling = false

    combat_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SLICE_AND_DICE) or 0
    combat_state.snd_active = combat_state.snd_duration > 0
    combat_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.RUPTURE) or 0
    combat_state.rupture_active = combat_state.rupture_duration > 0
    combat_state.blade_flurry_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.BLADE_FLURRY) or 0) > 0
    combat_state.adrenaline_rush_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.ADRENALINE_RUSH) or 0) > 0
    combat_state.expose_armor_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.EXPOSE_ARMOR) or 0) > 0

    return combat_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Stealth Opener — highest priority when stealthed with target
local Combat_StealthOpener = {
    requires_enemy = true,
    requires_stealth = true,

    matches = function(context, state)
        if context.in_combat and not context.is_stealthed then return false end
        local opener = context.settings.opener or "garrote"
        return opener ~= "none"
    end,

    execute = function(icon, context, state)
        local opener = context.settings.opener or "garrote"
        if opener == "garrote" then
            if context.is_behind and context.energy >= Constants.ENERGY.GARROTE
               and A.Garrote:IsReady(TARGET_UNIT) then
                return A.Garrote:Show(icon), "[COMBAT] Garrote - Stealth opener"
            end
        elseif opener == "cheap_shot" then
            if context.energy >= Constants.ENERGY.CHEAP_SHOT and A.CheapShot:IsReady(TARGET_UNIT) then
                return A.CheapShot:Show(icon), "[COMBAT] Cheap Shot - Stealth opener"
            end
        elseif opener == "ambush" then
            if context.is_behind and context.energy >= Constants.ENERGY.AMBUSH
               and A.Ambush:IsReady(TARGET_UNIT) then
                return A.Ambush:Show(icon), "[COMBAT] Ambush - Stealth opener"
            end
        end
        return nil
    end,
}

-- [2] Maintain Slice and Dice — SnD not active or below refresh threshold
local Combat_MaintainSnD = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if context.cp < 1 then return false end
        local refresh = context.settings.combat_snd_refresh or Constants.ROGUE.SND_MIN_DURATION
        return not state.snd_active or state.snd_duration < refresh
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.SLICE_AND_DICE and A.SliceAndDice:IsReady(PLAYER_UNIT) then
            return A.SliceAndDice:Show(icon),
                format("[COMBAT] Slice and Dice - Duration: %.1fs, CP: %d", state.snd_duration, context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [3] Blade Flurry — off-GCD, on CD
local Combat_BladeFlurry = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.BladeFlurry,
    spell_target = PLAYER_UNIT,
    setting_key = "combat_use_blade_flurry",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return not state.blade_flurry_active
    end,

    execute = function(icon, context, state)
        return try_cast(A.BladeFlurry, icon, PLAYER_UNIT, "[COMBAT] Blade Flurry")
    end,
}

-- [4] Adrenaline Rush — off-GCD, on CD
local Combat_AdrenalineRush = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.AdrenalineRush,
    spell_target = PLAYER_UNIT,
    setting_key = "combat_use_adrenaline_rush",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return not state.adrenaline_rush_active
    end,

    execute = function(icon, context, state)
        return try_cast(A.AdrenalineRush, icon, PLAYER_UNIT, "[COMBAT] Adrenaline Rush")
    end,
}

-- [5] Racial — off-GCD (Blood Fury, Berserking, Arcane Torrent)
local Combat_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if A.BloodFury:IsReady(PLAYER_UNIT) then return true end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFury:IsReady(PLAYER_UNIT) then
            return A.BloodFury:Show(icon), "[COMBAT] Blood Fury"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[COMBAT] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[COMBAT] Arcane Torrent"
        end
        return nil
    end,
}

-- [7] Expose Armor — at 5 CP, debuff not active
local Combat_ExposeArmor = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "use_expose_armor",
    min_cp = 5,

    matches = function(context, state)
        if state.pooling then return false end
        return not state.expose_armor_active
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.EXPOSE_ARMOR and A.ExposeArmor:IsReady(TARGET_UNIT) then
            return A.ExposeArmor:Show(icon), format("[COMBAT] Expose Armor - CP: %d", context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [8] Rupture — at 5 CP, not active, TTD > threshold, skip during BF multi-target
local Combat_Rupture = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "combat_use_rupture",

    matches = function(context, state)
        if state.pooling then return false end
        if context.cp < 5 then return false end
        if state.rupture_active then
            local refresh = context.settings.combat_rupture_refresh or 2
            if state.rupture_duration >= refresh then return false end
        end
        local min_ttd = context.settings.combat_rupture_min_ttd or 12
        if context.ttd < min_ttd then return false end
        -- Skip Rupture during Blade Flurry if multiple enemies (Eviscerate cleaves better)
        if state.blade_flurry_active and context.enemy_count >= 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.RUPTURE and A.Rupture:IsReady(TARGET_UNIT) then
            return A.Rupture:Show(icon),
                format("[COMBAT] Rupture - CP: %d, Duration: %.1fs", context.cp, state.rupture_duration)
        end
        state.pooling = true
        return nil
    end,
}

-- [9] Eviscerate — at min_cp+ CP dump
local Combat_Eviscerate = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if state.pooling then return false end
        local min_cp = context.settings.combat_min_cp_finisher or 5
        if context.cp < min_cp then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.EVISCERATE and A.Eviscerate:IsReady(TARGET_UNIT) then
            return A.Eviscerate:Show(icon), format("[COMBAT] Eviscerate - CP: %d", context.cp)
        end
        return nil
    end,
}

-- [10] Shiv Refresh — Deadly Poison < 2s remaining on target
-- Bypasses pooling gate: DP refresh is higher priority than pooling for the next finisher
local Combat_ShivRefresh = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "use_shiv",

    matches = function(context, state)
        -- Do NOT check state.pooling here — DP refresh must happen even while pooling
        local dp_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEADLY_POISON) or 0
        if dp_duration <= 0 then return false end
        return dp_duration < Constants.ROGUE.DP_REFRESH_THRESHOLD
    end,

    execute = function(icon, context, state)
        if A.Shiv:IsReady(TARGET_UNIT) then
            return A.Shiv:Show(icon), "[COMBAT] Shiv - Refresh Deadly Poison"
        end
        return nil
    end,
}

-- [11] Sinister Strike — primary builder
local Combat_SinisterStrike = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    spell = A.SinisterStrike,

    matches = function(context, state)
        if state.pooling then return false end
        if context.cp >= 5 then return false end
        return context.energy >= Constants.ENERGY.SINISTER_STRIKE
    end,

    execute = function(icon, context, state)
        return try_cast(A.SinisterStrike, icon, TARGET_UNIT,
            format("[COMBAT] Sinister Strike - Energy: %d, CP: %d", context.energy, context.cp))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("combat", {
    named("StealthOpener",  Combat_StealthOpener),
    named("MaintainSnD",    Combat_MaintainSnD),
    named("BladeFlurry",    Combat_BladeFlurry),
    named("AdrenalineRush", Combat_AdrenalineRush),
    named("Racial",         Combat_Racial),
    named("ExposeArmor",    Combat_ExposeArmor),
    named("Rupture",        Combat_Rupture),
    named("Eviscerate",     Combat_Eviscerate),
    named("ShivRefresh",    Combat_ShivRefresh),
    named("SinisterStrike", Combat_SinisterStrike),
}, {
    context_builder = get_combat_state,
    check_prerequisites = function(strategy, context)
        if strategy.requires_stealth ~= nil and strategy.requires_stealth ~= context.is_stealthed then return false end
        if strategy.requires_behind ~= nil and strategy.requires_behind ~= context.is_behind then return false end
        if strategy.min_cp and context.cp < strategy.min_cp then return false end
        return true
    end,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Rogue]|r Combat strategies registered (10 strategies)")
