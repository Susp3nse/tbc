--- Subtlety Rogue Module
--- Subtlety playstyle strategies: Hemorrhage builder, SnD/Rupture/Evis finishers
--- Shadowstep + Preparation cooldown management

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "ROGUE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Subtlety]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Subtlety]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- SUBTLETY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local subtlety_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    hemo_debuff_active = false,
    shadowstep_buff_active = false,
    master_of_subtlety_active = false,
    expose_armor_active = false,
    pooling = false,
}

local function get_subtlety_state(context)
    if context._subtlety_valid then return subtlety_state end
    context._subtlety_valid = true

    subtlety_state.pooling = false

    subtlety_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SLICE_AND_DICE) or 0
    subtlety_state.snd_active = subtlety_state.snd_duration > 0
    subtlety_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.RUPTURE) or 0
    subtlety_state.rupture_active = subtlety_state.rupture_duration > 0
    subtlety_state.hemo_debuff_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.HEMORRHAGE) or 0) > 0
    subtlety_state.shadowstep_buff_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SHADOWSTEP_BUFF) or 0) > 0
    subtlety_state.master_of_subtlety_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.MASTER_OF_SUBTLETY) or 0) > 0
    subtlety_state.expose_armor_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.EXPOSE_ARMOR) or 0) > 0

    return subtlety_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Stealth Opener — Premeditation → Shadowstep → opener spell
local Subtlety_StealthOpener = {
    requires_enemy = true,
    requires_stealth = true,

    matches = function(context, state)
        if context.in_combat and not context.is_stealthed then return false end
        local opener = context.settings.opener or "garrote"
        return opener ~= "none"
    end,

    execute = function(icon, context, state)
        -- Premeditation first (2 free CP from stealth, off-GCD)
        if A.Premeditation:IsReady(PLAYER_UNIT) then
            return A.Premeditation:Show(icon), "[SUBTLETY] Premeditation - Stealth opener setup"
        end

        -- Shadowstep next if talented (teleport + 20% damage buff)
        if context.settings.subtlety_use_shadowstep and A.Shadowstep:IsReady(TARGET_UNIT) then
            return A.Shadowstep:Show(icon), "[SUBTLETY] Shadowstep - Stealth opener"
        end

        -- Then opener spell
        local opener = context.settings.opener or "garrote"
        if opener == "ambush" then
            if context.is_behind and context.energy >= Constants.ENERGY.AMBUSH
               and A.Ambush:IsReady(TARGET_UNIT) then
                return A.Ambush:Show(icon), "[SUBTLETY] Ambush - Stealth opener"
            end
        elseif opener == "garrote" then
            if context.is_behind and context.energy >= Constants.ENERGY.GARROTE
               and A.Garrote:IsReady(TARGET_UNIT) then
                return A.Garrote:Show(icon), "[SUBTLETY] Garrote - Stealth opener"
            end
        elseif opener == "cheap_shot" then
            if context.energy >= Constants.ENERGY.CHEAP_SHOT and A.CheapShot:IsReady(TARGET_UNIT) then
                return A.CheapShot:Show(icon), "[SUBTLETY] Cheap Shot - Stealth opener"
            end
        end
        return nil
    end,
}

-- [2] Maintain Slice and Dice — SnD not active or below refresh threshold
local Subtlety_MaintainSnD = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if context.cp < 1 then return false end
        local refresh = context.settings.subtlety_snd_refresh or Constants.ROGUE.SND_MIN_DURATION
        return not state.snd_active or state.snd_duration < refresh
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.SLICE_AND_DICE and A.SliceAndDice:IsReady(PLAYER_UNIT) then
            return A.SliceAndDice:Show(icon),
                format("[SUBTLETY] Slice and Dice - Duration: %.1fs, CP: %d", state.snd_duration, context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [3] Shadowstep — on GCD, use on CD for +20% damage buff
local Subtlety_Shadowstep = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    spell = A.Shadowstep,
    setting_key = "subtlety_use_shadowstep",

    matches = function(context, state)
        return not state.shadowstep_buff_active
    end,

    execute = function(icon, context, state)
        return try_cast(A.Shadowstep, icon, TARGET_UNIT, "[SUBTLETY] Shadowstep - +20% damage")
    end,
}

-- [4] Preparation — off-GCD, reset key cooldowns
local Subtlety_Preparation = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.Preparation,
    spell_target = PLAYER_UNIT,
    setting_key = "subtlety_use_preparation",

    matches = function(context, state)
        -- Use Preparation when Shadowstep is on CD (only fires if Shadowstep is talented)
        if not is_spell_available(A.Shadowstep) then return false end
        return not A.Shadowstep:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Preparation, icon, PLAYER_UNIT, "[SUBTLETY] Preparation - Reset CDs")
    end,
}

-- [5] Racial — off-GCD (Blood Fury, Berserking, Arcane Torrent)
local Subtlety_Racial = {
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
            return A.BloodFury:Show(icon), "[SUBTLETY] Blood Fury"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[SUBTLETY] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[SUBTLETY] Arcane Torrent"
        end
        return nil
    end,
}

-- [7] Ghostly Strike — secondary builder on CD, +15% dodge 7s (Subtlety talent)
local Subtlety_GhostlyStrike = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    spell = A.GhostlyStrike,
    setting_key = "subtlety_use_ghostly_strike",

    matches = function(context, state)
        if state.pooling then return false end
        if context.cp >= 5 then return false end
        return context.energy >= Constants.ENERGY.GHOSTLY_STRIKE
    end,

    execute = function(icon, context, state)
        return try_cast(A.GhostlyStrike, icon, TARGET_UNIT,
            format("[SUBTLETY] Ghostly Strike - Energy: %d, CP: %d", context.energy, context.cp))
    end,
}

-- [8] Expose Armor — at 5 CP, debuff not active
local Subtlety_ExposeArmor = {
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
            return A.ExposeArmor:Show(icon), format("[SUBTLETY] Expose Armor - CP: %d", context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [9] Rupture — at 5 CP, not active, TTD > threshold
local Subtlety_Rupture = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "subtlety_use_rupture",
    min_cp = 5,

    matches = function(context, state)
        if state.pooling then return false end
        local refresh = context.settings.subtlety_rupture_refresh or 2
        if state.rupture_active and state.rupture_duration >= refresh then return false end
        local min_ttd = context.settings.subtlety_rupture_min_ttd or 12
        if context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.RUPTURE and A.Rupture:IsReady(TARGET_UNIT) then
            return A.Rupture:Show(icon),
                format("[SUBTLETY] Rupture - CP: %d, Duration: %.1fs", context.cp, state.rupture_duration)
        end
        state.pooling = true
        return nil
    end,
}

-- [10] Eviscerate — at min_cp+ CP dump
local Subtlety_Eviscerate = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if state.pooling then return false end
        local min_cp = context.settings.subtlety_min_cp_finisher or 5
        if context.cp < min_cp then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.EVISCERATE and A.Eviscerate:IsReady(TARGET_UNIT) then
            return A.Eviscerate:Show(icon), format("[SUBTLETY] Eviscerate - CP: %d", context.cp)
        end
        return nil
    end,
}

-- [11] Hemorrhage — primary builder (also maintains debuff passively)
local Subtlety_Hemorrhage = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    spell = A.Hemorrhage,

    matches = function(context, state)
        if state.pooling then return false end
        if context.cp >= 5 then return false end
        return context.energy >= Constants.ENERGY.HEMORRHAGE
    end,

    execute = function(icon, context, state)
        return try_cast(A.Hemorrhage, icon, TARGET_UNIT,
            format("[SUBTLETY] Hemorrhage - Energy: %d, CP: %d", context.energy, context.cp))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("subtlety", {
    named("StealthOpener",  Subtlety_StealthOpener),
    named("MaintainSnD",    Subtlety_MaintainSnD),
    named("Shadowstep",     Subtlety_Shadowstep),
    named("Preparation",    Subtlety_Preparation),
    named("Racial",         Subtlety_Racial),
    named("GhostlyStrike",  Subtlety_GhostlyStrike),
    named("ExposeArmor",    Subtlety_ExposeArmor),
    named("Rupture",        Subtlety_Rupture),
    named("Eviscerate",     Subtlety_Eviscerate),
    named("Hemorrhage",     Subtlety_Hemorrhage),
}, {
    context_builder = get_subtlety_state,
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
print("|cFF00FF00[Flux AIO Rogue]|r Subtlety strategies registered (10 strategies)")
