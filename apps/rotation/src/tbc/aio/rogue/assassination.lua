--- Assassination Rogue Module
--- Assassination playstyle strategies: Mutilate builder, SnD/Rupture/Envenom/Evis finishers
--- Cold Blood cooldown, Deadly Poison synergy

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "ROGUE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Assassination]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Assassination]|r Registry not found!")
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
-- ASSASSINATION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local assassination_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    deadly_poison_stacks = 0,
    deadly_poison_duration = 0,
    cold_blood_active = false,
    find_weakness_active = false,
    expose_armor_active = false,
    pooling = false,
}

local function get_assassination_state(context)
    if context._assassination_valid then return assassination_state end
    context._assassination_valid = true

    assassination_state.pooling = false

    assassination_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SLICE_AND_DICE) or 0
    assassination_state.snd_active = assassination_state.snd_duration > 0
    assassination_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.RUPTURE) or 0
    assassination_state.rupture_active = assassination_state.rupture_duration > 0
    assassination_state.deadly_poison_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.DEADLY_POISON) or 0
    assassination_state.deadly_poison_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEADLY_POISON) or 0
    assassination_state.cold_blood_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.COLD_BLOOD) or 0) > 0
    assassination_state.find_weakness_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.FIND_WEAKNESS) or 0) > 0
    assassination_state.expose_armor_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.EXPOSE_ARMOR) or 0) > 0

    return assassination_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Stealth Opener — highest priority when stealthed with target
local Assassination_StealthOpener = {
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
                return A.Garrote:Show(icon), "[ASSASSINATION] Garrote - Stealth opener"
            end
        elseif opener == "cheap_shot" then
            if context.energy >= Constants.ENERGY.CHEAP_SHOT and A.CheapShot:IsReady(TARGET_UNIT) then
                return A.CheapShot:Show(icon), "[ASSASSINATION] Cheap Shot - Stealth opener"
            end
        elseif opener == "ambush" then
            if context.is_behind and context.energy >= Constants.ENERGY.AMBUSH
               and A.Ambush:IsReady(TARGET_UNIT) then
                return A.Ambush:Show(icon), "[ASSASSINATION] Ambush - Stealth opener"
            end
        end
        return nil
    end,
}

-- [2] Maintain Slice and Dice — SnD not active or below refresh threshold
local Assassination_MaintainSnD = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if context.cp < 1 then return false end
        local refresh = context.settings.assassination_snd_refresh or Constants.ROGUE.SND_MIN_DURATION
        return not state.snd_active or state.snd_duration < refresh
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.SLICE_AND_DICE and A.SliceAndDice:IsReady(PLAYER_UNIT) then
            return A.SliceAndDice:Show(icon),
                format("[ASSASSINATION] Slice and Dice - Duration: %.1fs, CP: %d", state.snd_duration, context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [3] Cold Blood — off-GCD, pair with next finisher
local Assassination_ColdBlood = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.ColdBlood,
    spell_target = PLAYER_UNIT,
    setting_key = "assassination_use_cold_blood",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        -- Only use when we have CP for a finisher soon
        local min_cp = context.settings.assassination_min_cp_finisher or 4
        return context.cp >= min_cp
    end,

    execute = function(icon, context, state)
        return try_cast(A.ColdBlood, icon, PLAYER_UNIT, "[ASSASSINATION] Cold Blood")
    end,
}

-- [4] Racial — off-GCD (Blood Fury, Berserking, Arcane Torrent)
local Assassination_Racial = {
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
            return A.BloodFury:Show(icon), "[ASSASSINATION] Blood Fury"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[ASSASSINATION] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[ASSASSINATION] Arcane Torrent"
        end
        return nil
    end,
}

-- [6] Expose Armor — at 5 CP, debuff not active
local Assassination_ExposeArmor = {
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
            return A.ExposeArmor:Show(icon), format("[ASSASSINATION] Expose Armor - CP: %d", context.cp)
        end
        state.pooling = true
        return nil
    end,
}

-- [7] Rupture — at 4-5 CP, not active, TTD > threshold
local Assassination_Rupture = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "assassination_use_rupture",

    matches = function(context, state)
        if state.pooling then return false end
        local min_cp = context.settings.assassination_min_cp_finisher or 4
        if context.cp < min_cp then return false end
        local refresh = context.settings.assassination_rupture_refresh or 2
        if state.rupture_active and state.rupture_duration >= refresh then return false end
        local min_ttd = context.settings.assassination_rupture_min_ttd or 12
        if context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.RUPTURE and A.Rupture:IsReady(TARGET_UNIT) then
            return A.Rupture:Show(icon),
                format("[ASSASSINATION] Rupture - CP: %d, Duration: %.1fs", context.cp, state.rupture_duration)
        end
        state.pooling = true
        return nil
    end,
}

-- [8] Envenom — at 4-5 CP when Deadly Poison stacks >= threshold
local Assassination_Envenom = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "assassination_use_envenom",
    spell = A.Envenom,

    matches = function(context, state)
        if state.pooling then return false end
        local min_cp = context.settings.assassination_min_cp_finisher or 4
        if context.cp < min_cp then return false end
        local min_stacks = context.settings.assassination_envenom_min_stacks or 2
        if state.deadly_poison_stacks < min_stacks then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.ENVENOM and A.Envenom:IsReady(TARGET_UNIT) then
            return A.Envenom:Show(icon),
                format("[ASSASSINATION] Envenom - CP: %d, DP Stacks: %d", context.cp, state.deadly_poison_stacks)
        end
        return nil
    end,
}

-- [9] Eviscerate — at min_cp+ fallback CP dump
local Assassination_Eviscerate = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,

    matches = function(context, state)
        if state.pooling then return false end
        local min_cp = context.settings.assassination_min_cp_finisher or 4
        if context.cp < min_cp then return false end
        return true
    end,

    execute = function(icon, context, state)
        if context.energy >= Constants.ENERGY.EVISCERATE and A.Eviscerate:IsReady(TARGET_UNIT) then
            return A.Eviscerate:Show(icon), format("[ASSASSINATION] Eviscerate - CP: %d", context.cp)
        end
        return nil
    end,
}

-- [10] Shiv Refresh — Deadly Poison < 2s remaining on target
-- Bypasses pooling gate: DP refresh is higher priority than pooling for the next finisher
local Assassination_ShivRefresh = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    setting_key = "use_shiv",

    matches = function(context, state)
        -- Do NOT check state.pooling here — DP refresh must happen even while pooling
        if state.deadly_poison_duration <= 0 then return false end
        return state.deadly_poison_duration < Constants.ROGUE.DP_REFRESH_THRESHOLD
    end,

    execute = function(icon, context, state)
        if A.Shiv:IsReady(TARGET_UNIT) then
            return A.Shiv:Show(icon), "[ASSASSINATION] Shiv - Refresh Deadly Poison"
        end
        return nil
    end,
}

-- [11] Mutilate — primary builder (requires behind target, daggers MH+OH)
local Assassination_Mutilate = {
    requires_combat = true,
    requires_enemy = true,
    requires_stealth = false,
    requires_behind = true,
    spell = A.Mutilate,

    matches = function(context, state)
        if state.pooling then return false end
        if context.cp >= 5 then return false end
        return context.energy >= Constants.ENERGY.MUTILATE
    end,

    execute = function(icon, context, state)
        return try_cast(A.Mutilate, icon, TARGET_UNIT,
            format("[ASSASSINATION] Mutilate - Energy: %d, CP: %d", context.energy, context.cp))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("assassination", {
    named("StealthOpener",  Assassination_StealthOpener),
    named("MaintainSnD",    Assassination_MaintainSnD),
    named("ColdBlood",      Assassination_ColdBlood),
    named("Racial",         Assassination_Racial),
    named("ExposeArmor",    Assassination_ExposeArmor),
    named("Rupture",        Assassination_Rupture),
    named("Envenom",        Assassination_Envenom),
    named("Eviscerate",     Assassination_Eviscerate),
    named("ShivRefresh",    Assassination_ShivRefresh),
    named("Mutilate",       Assassination_Mutilate),
}, {
    context_builder = get_assassination_state,
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
print("|cFF00FF00[Flux AIO Rogue]|r Assassination strategies registered (10 strategies)")
