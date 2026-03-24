--- Retribution Paladin Module
--- Retribution playstyle strategies including seal twisting
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "PALADIN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Retribution]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Retribution]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local SealOfBloodAction = NS.SealOfBloodAction
local SEAL_BLOOD_BUFF_ID = NS.SEAL_BLOOD_BUFF_ID
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- WoW API
local UnitCreatureType = _G.UnitCreatureType
local GetSpellCooldown = _G.GetSpellCooldown
local GetTime = _G.GetTime

-- ============================================================================
-- RETRIBUTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local ret_state = {
    seal_blood_active = false,
    seal_command_active = false,
    low_mana = false,
    can_exorcism = false,
    can_consecration = false,
    target_below_20 = false,
    in_twist_window = false,
    time_to_swing = 0,
    should_twist = false,
    target_undead_or_demon = false,
    judgement_cd_remaining = 0,
    spell_gcd = 1.5,
}

local function get_ret_state(context)
    if context._ret_valid then return ret_state end
    context._ret_valid = true

    -- Read directly from context (set in extend_context)
    ret_state.seal_blood_active = context.seal_blood_active
    ret_state.seal_command_active = context.seal_command_active
    ret_state.in_twist_window = context.in_twist_window
    ret_state.time_to_swing = context.time_to_swing

    -- Mana thresholds (from wowsims)
    ret_state.low_mana = context.mana <= Constants.TWIST.LOW_MANA
    ret_state.can_exorcism = context.mana_pct > Constants.MANA.EXORCISM_PCT
    ret_state.can_consecration = context.mana_pct > Constants.MANA.CONSEC_PCT

    -- Execute phase
    ret_state.target_below_20 = context.target_hp < 20

    -- Twist decision: enabled by setting AND not low mana
    ret_state.should_twist = context.settings.ret_seal_twist and not ret_state.low_mana

    -- Creature type check for Exorcism
    local ctype = UnitCreatureType(TARGET_UNIT)
    ret_state.target_undead_or_demon = (ctype == "Undead" or ctype == "Demon")

    -- Judgement CD remaining + haste-adjusted spell GCD (wowsims twist timing guard)
    local j_start, j_dur = GetSpellCooldown(A.Judgement.ID)
    if j_start and j_start > 0 and j_dur and j_dur > 0 then
        local j_rem = (j_start + j_dur) - GetTime()
        ret_state.judgement_cd_remaining = j_rem > 0 and j_rem or 0
    else
        ret_state.judgement_cd_remaining = 0
    end
    ret_state.spell_gcd = (A.GetGCD and A.GetGCD()) or 1.5

    return ret_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Avenging Wrath (off-GCD, +30% damage)
local Ret_AvengingWrath = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.AvengingWrath,
    spell_target = PLAYER_UNIT,
    setting_key = "use_avenging_wrath",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.AvengingWrath, icon, PLAYER_UNIT, "[RET] Avenging Wrath")
    end,
}

-- [2] Racial (off-GCD)
local Ret_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,

    matches = function(context, state)
        if not context.settings.use_racial then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[RET] Stoneform"
        end
        if context.hp < 60 and A.GiftOfTheNaaru and A.GiftOfTheNaaru:IsReady(PLAYER_UNIT) then
            return A.GiftOfTheNaaru:Show(icon), "[RET] Gift of the Naaru"
        end
        return nil
    end,
}

-- [5] Complete Seal Twist: SoC active + in twist window → cast SoB
local Ret_CompleteSealTwist = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        if not state.seal_command_active then return false end
        if not state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        if SealOfBloodAction:IsReady(PLAYER_UNIT) then
            return SealOfBloodAction:Show(icon),
                format("[RET] Twist -> SoB (swing in %.2fs)", state.time_to_swing)
        end
        return nil
    end,
}

-- [6] Judge configured seal (off-GCD — Judgement does NOT trigger GCD in TBC)
local Ret_JudgeSeal = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        if not context.settings.ret_use_judgement then return false end
        -- Gate judging when critically low mana: preserve active seal (re-seal costs ~210 mana)
        if state.low_mana and context.mana < 300 then return false end
        -- Check if the seal we want to judge is active
        local judge = context.settings.ret_judge_seal or "blood"
        if judge == "blood" then
            if not state.seal_blood_active then return false end
        elseif judge == "crusader" then
            if not context.seal_crusader_active then return false end
        elseif judge == "wisdom" then
            if not context.seal_wisdom_active then return false end
        elseif judge == "light" then
            if not context.seal_light_active then return false end
        else
            if not context.has_any_seal then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        local judge = context.settings.ret_judge_seal or "blood"
        return try_cast(A.Judgement, icon, TARGET_UNIT, format("[RET] Judge (%s)", judge))
    end,
}

-- [7] Crusader Strike (6s CD)
local Ret_CrusaderStrike = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.CrusaderStrike,

    matches = function(context, state)
        if not context.settings.ret_use_crusader_strike then return false end
        -- Don't waste GCD on CS without a seal active — let MaintainSealFallback re-seal first
        if not context.has_any_seal then return false end
        -- When twisting: don't CS if in twist window or swing imminent
        if state.should_twist and state.seal_command_active then
            if state.in_twist_window then return false end
            if state.time_to_swing > 0 and state.time_to_swing < 1.5 then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.CrusaderStrike, icon, TARGET_UNIT, "[RET] Crusader Strike")
    end,
}

-- [8] Prep Seal Twist: cast SoC R1 to set up next twist
local Ret_PrepSealTwist = {
    requires_combat = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        -- Only prep if SoC is not already active
        if state.seal_command_active then return false end
        -- Don't override Seal of Wisdom during mana recovery
        if context.seal_wisdom_active and context.settings.use_seal_of_wisdom_low_mana then
            local threshold = context.settings.seal_of_wisdom_mana_pct or 20
            if context.mana_pct <= threshold then return false end
        end
        -- Don't prep if in twist window (too late)
        if state.in_twist_window then return false end
        -- Don't prep if swing is very imminent
        if state.time_to_swing > 0 and state.time_to_swing < 0.5 then return false end
        -- Mirror wowsims: don't replace the judgeable seal with SoC if Judgement
        -- comes off CD before latestTwistStart (time_to_swing - spellGCD).
        -- Let JudgeSeal fire first, then prep SoC on the next frame.
        -- Condition from wowsims: nextJudgementCD > latestTwistStart
        if state.time_to_swing > 0 then
            local judge = context.settings.ret_judge_seal or "blood"
            local judge_seal_active =
                (judge == "blood"    and state.seal_blood_active)       or
                (judge == "crusader" and context.seal_crusader_active)  or
                (judge == "wisdom"   and context.seal_wisdom_active)    or
                (judge == "light"    and context.seal_light_active)
            if judge_seal_active then
                if state.judgement_cd_remaining <= (state.time_to_swing - state.spell_gcd) then
                    return false
                end
            end
        end
        return true
    end,

    execute = function(icon, context, state)
        if A.SealOfCommandR1:IsReady(PLAYER_UNIT) then
            return A.SealOfCommandR1:Show(icon),
                format("[RET] Prep SoC R1 (swing in %.2fs)", state.time_to_swing)
        end
        return nil
    end,
}

-- [9] Hammer of Wrath (execute phase, target < 20%)
local Ret_HammerOfWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HammerOfWrath,

    matches = function(context, state)
        if not context.settings.ret_use_hammer_of_wrath then return false end
        if not state.target_below_20 then return false end
        -- Skip when mana is critical — strip to SoB+CS+Judge only (wowsims)
        if state.low_mana then return false end
        -- Don't clip twist
        if state.should_twist and state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HammerOfWrath, icon, TARGET_UNIT, "[RET] Hammer of Wrath")
    end,
}

-- [10] Exorcism (Undead/Demon only, mana > 40%)
local Ret_Exorcism = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Exorcism,

    matches = function(context, state)
        if not context.settings.ret_use_exorcism then return false end
        if context.is_moving then return false end
        if not state.target_undead_or_demon then return false end
        if not state.can_exorcism then return false end
        -- Don't clip twist window
        if state.should_twist and state.in_twist_window then return false end
        -- Need enough time before next swing for the 1.5s cast
        if state.should_twist and state.time_to_swing > 0 and state.time_to_swing < 2.0 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Exorcism, icon, TARGET_UNIT, "[RET] Exorcism")
    end,
}

-- [11] Consecration (filler, mana > 60%)
local Ret_Consecration = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Consecration,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.settings.ret_use_consecration then return false end
        if not state.can_consecration then return false end
        -- AoE threshold check
        local aoe_thresh = context.settings.ret_aoe_threshold or 0
        if aoe_thresh > 0 and context.enemy_count < aoe_thresh then return false end
        -- Don't clip twist window
        if state.should_twist and state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Consecration, icon, PLAYER_UNIT, "[RET] Consecration")
    end,
}

-- [12] Holy Wrath (Undead/Demon AoE, low priority filler)
local Ret_HolyWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HolyWrath,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.target_undead_or_demon then return false end
        if context.enemy_count < 3 then return false end
        if context.mana_pct < 40 then return false end
        -- Don't clip twist window
        if state.should_twist and state.in_twist_window then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyWrath, icon, PLAYER_UNIT, "[RET] Holy Wrath")
    end,
}

-- [13] Maintain Seal fallback (no seal active — catch-all)
local Ret_MaintainSealFallback = {
    requires_combat = true,

    matches = function(context, state)
        if context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        if SealOfBloodAction:IsReady(PLAYER_UNIT) then
            return SealOfBloodAction:Show(icon), "[RET] Re-seal SoB (fallback)"
        end
        -- SoB unavailable (pre-64, wrong faction, OOM) — fall back to SoC then SoR
        if A.SealOfCommandMax:IsReady(PLAYER_UNIT) then
            return A.SealOfCommandMax:Show(icon), "[RET] Re-seal SoC (fallback)"
        end
        if A.SealOfRighteousness:IsReady(PLAYER_UNIT) then
            return A.SealOfRighteousness:Show(icon), "[RET] Re-seal SoR (fallback)"
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("retribution", {
    named("AvengingWrath",       Ret_AvengingWrath),
    named("Racial",              Ret_Racial),
    named("CompleteSealTwist",   Ret_CompleteSealTwist),
    named("JudgeSeal",           Ret_JudgeSeal),
    named("CrusaderStrike",      Ret_CrusaderStrike),
    named("PrepSealTwist",       Ret_PrepSealTwist),
    named("HammerOfWrath",       Ret_HammerOfWrath),
    named("Exorcism",            Ret_Exorcism),
    named("Consecration",        Ret_Consecration),
    named("HolyWrath",           Ret_HolyWrath),
    named("MaintainSealFallback", Ret_MaintainSealFallback),
}, {
    context_builder = get_ret_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Paladin]|r Retribution module loaded")
