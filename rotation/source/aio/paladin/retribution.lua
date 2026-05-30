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
local IsSpellKnown = _G.IsSpellKnown
local get_spell_mana_cost = NS.get_spell_mana_cost

-- Pull window (seconds) during which the Seal of the Crusader opener may fire.
-- Crusader Strike refreshes the Judgement debuff afterward, so the opener only
-- needs to land it once at the start of the fight.
local OPENER_COMBAT_WINDOW = 8

-- How early (seconds) before the latest safe prep moment we allow Seal of Command to be
-- prepped for a twist. Wider = more reliable twists but Command holds slightly longer
-- (less Blood uptime); narrower = more Blood uptime but more missed twists under GCD
-- contention. Tune against parse uptimes (target ~Blood 60%+ / Command ~40%).
local PREP_LEAD_BUFFER = 0.3

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

-- Rank-safe Seal of Command cast for twisting.
-- The rank is chosen by ret_twist_seal_rank; Rank 1 is the mana-efficient default
-- because Seal of Command's proc damage is rank-independent (65 vs 280 mana).
-- isRank-tagged actions make IsReady() unreliable (it fails for non-max ranks), so
-- we gate on IsSpellKnown + mana and Show() directly — the same pattern Holy uses
-- for its ranked heal casts.
local function show_twist_soc(icon, context, log_message)
    local soc = (context.settings.ret_twist_seal_rank == "max")
        and A.SealOfCommandMax or A.SealOfCommandR1
    if not IsSpellKnown(soc.ID) then return nil end
    local cost = get_spell_mana_cost(soc)
    if cost and cost > 0 and context.mana < cost then return nil end
    return soc:Show(icon), log_message
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Avenging Wrath (off-GCD, +30% damage)
local Ret_AvengingWrath = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.AvengingWrath,
    spell_target = PLAYER_UNIT,

    -- Firing mode is driven by the "Avenging Wrath" dropdown (ret_avenging_wrath):
    --   never    — disabled (manual /flux burst won't fire it either)
    --   cooldown — fire whenever it's off cooldown
    --   bosses   — fire on cooldown, but only against boss targets
    --   burst    — fire only while bursting: the /flux burst window OR a configured
    --              auto-burst condition (should_auto_burst == true)
    -- Note: not is_burst-tagged. We handle the /flux burst case explicitly here so
    -- the dispatcher's auto-burst gate doesn't suppress the cooldown/bosses modes.
    matches = function(context, state)
        local mode = context.settings.ret_avenging_wrath or "burst"
        if mode == "never" then return false end
        -- Common guards for any firing mode
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if context.forbearance_active then return false end

        if mode == "cooldown" then
            return true
        elseif mode == "bosses" then
            return context.is_boss == true
        elseif mode == "burst" then
            return NS.is_force_active("force_burst") or NS.should_auto_burst(context) == true
        end
        return false
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

-- [3] Opener: Seal of the Crusader → Judgement (Heart of the Crusader, +3% raid crit)
-- Fires only in the first few seconds of combat and stops permanently once the
-- Judgement of the Crusader debuff is on the target. Crusader Strike (Ret talent)
-- refreshes all Judgements on hit, so this one application is maintained all fight.
-- is_gcd_gated = false so the off-GCD Judgement step lands immediately once the
-- seal is up (the on-GCD Seal cast is naturally skipped while on GCD via IsReady).
local Ret_Opener = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    setting_key = "ret_opener_crusader",

    matches = function(context, state)
        -- Pull-only: skip once we're past the opener window.
        if context.combat_time <= 0 or context.combat_time > OPENER_COMBAT_WINDOW then return false end
        -- Within ~10yd: lets Seal of the Crusader (a self-buff) go up while closing,
        -- so it's ready by the time we're in Judgement range. The Judgement step
        -- self-gates on its own 10yd range via IsReady().
        if context.target_range and context.target_range > 10 then return false end
        -- Skip if Judgement of the Crusader is already on the target — including when
        -- ANOTHER paladin applied it. HasDeBuffs with no caster arg matches any source
        -- (framework uses the "HARMFUL PLAYER" filter only when a caster is passed).
        -- Crusader Strike refreshes the debuff for the rest of the fight.
        if (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.JUDGEMENT_CRUSADER) or 0) > 0 then
            return false
        end
        -- Don't start the opener unless Judgement is off cooldown, so the
        -- Seal of the Crusader -> Judge pair completes immediately. Otherwise we'd
        -- cast the seal, fail to judge it, get it overwritten by Prep-SoC, and
        -- re-cast it in a loop — i.e. get stuck on the opener.
        if state.judgement_cd_remaining and state.judgement_cd_remaining > 0 then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Step 1 (on-GCD): get Seal of the Crusader up. Skipped while on GCD since
        -- IsReady() is false for a GCD spell mid-GCD.
        if not context.seal_crusader_active then
            if A.SealOfCrusader:IsReady(PLAYER_UNIT) then
                return A.SealOfCrusader:Show(icon), "[RET] Opener: Seal of the Crusader"
            end
            return nil
        end
        -- Step 2 (off-GCD): Judge to apply Judgement of the Crusader (+3% raid crit).
        if A.Judgement:IsReady(TARGET_UNIT) then
            return A.Judgement:Show(icon), "[RET] Opener: Judge Crusader (+3% raid crit)"
        end
        return nil
    end,
}

-- [5] Twist into Blood: Command is prepped (active) → cast Seal of Blood/Martyr in the
-- 0.4s pre-swing window so the swing procs BOTH (Command via the overlap + Blood's
-- guaranteed hit). TBC twisting is UNIDIRECTIONAL — you can only twist Command -> Blood,
-- so Command must be the active seal going into the window. Blood then rides as the
-- resident seal until we prep Command again before the next swing.
local Ret_TwistBlood = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        -- Must be on Command to twist into Blood (unidirectional).
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
        -- When twisting, judge Blood RIGHT BEFORE prepping Command (the standard rule:
        -- "cast Judgement right before you prep Command"). We drop Blood for the prep
        -- anyway, so judging at that moment gets Judgement of Blood essentially for free
        -- and avoids a wasted re-seal. JudgeSeal is off-GCD and outranks PrepCommand, so
        -- it consumes Blood one frame and PrepCommand casts Command the next. Only judge
        -- inside the prep lead band; in the resident phase an early judge would force a
        -- re-seal whose GCD can eat the prep window (missed twist).
        if state.should_twist and judge == "blood" and state.time_to_swing > 0 then
            local lead = Constants.TWIST.WINDOW + state.spell_gcd
            if state.time_to_swing < lead or state.time_to_swing > lead + PREP_LEAD_BUFFER then
                return false
            end
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
        -- Only protect the actual 0.4s twist window so the Command-twist cast isn't
        -- clipped. We intentionally do NOT block the whole last ~1.5s before a swing:
        -- that pinned CS to one slot per swing and stretched its real interval to 9-11s
        -- instead of firing near its 6s cooldown. CS damage + the Judgement-of-the-
        -- Crusader refresh (which keeps the +3% raid crit up) outrank a skipped twist.
        if state.should_twist and state.in_twist_window then
            return false
        end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.CrusaderStrike, icon, TARGET_UNIT, "[RET] Crusader Strike")
    end,
}

-- [8] Prep Command: switch from resident Blood to Seal of Command, but ONLY in the short
-- lead just before the swing — late enough that Command isn't the resident seal, early
-- enough that its GCD finishes before the 0.4s twist window so we can twist into Blood.
-- This is the "from" side of the unidirectional Command -> Blood twist. Command rank per
-- setting. Outside this lead, Blood stays resident (MaintainBlood), so Blood keeps the
-- dominant uptime while Command is only briefly up to enable the twist.
local Ret_PrepCommand = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not state.should_twist then return false end
        if state.seal_command_active then return false end   -- already prepped
        if state.time_to_swing <= 0 then return false end
        -- Prep lead band: [window+gcd, window+gcd+PREP_LEAD_BUFFER]. Below the band it's
        -- too late to prep AND twist (skip this swing, Blood just rides); above it we'd
        -- hold Command too long and steal Blood's uptime.
        local lead = Constants.TWIST.WINDOW + state.spell_gcd
        if state.time_to_swing < lead or state.time_to_swing > lead + PREP_LEAD_BUFFER then
            return false
        end
        -- Don't override Seal of Wisdom during mana recovery.
        if context.seal_wisdom_active and context.settings.use_seal_of_wisdom_low_mana then
            local threshold = context.settings.seal_of_wisdom_mana_pct or 20
            if context.mana_pct <= threshold then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        return show_twist_soc(icon, context,
            format("[RET] Prep SoC (swing in %.2fs)", state.time_to_swing))
    end,
}

-- [9] Maintain Seal of Blood/Martyr as the RESIDENT seal — the guaranteed-damage seal we
-- also Judge. Re-applies it whenever it's dropped (after a Judgement, or after a twist
-- left Command up), EXCEPT in the pre-twist lead/window where PrepCommand + TwistBlood
-- run. Blood is a 30s seal, so this only fires when it actually dropped → Blood keeps the
-- dominant uptime, Command only flashes up briefly to enable each twist.
local Ret_MaintainBlood = {
    requires_combat = true,

    matches = function(context, state)
        -- Already up — let it ride; no need to re-cast a 30s seal.
        if state.seal_blood_active then return false end
        -- In the pre-twist lead/window, let PrepCommand + TwistBlood drive the seal.
        if state.should_twist and state.time_to_swing > 0 then
            local lead = Constants.TWIST.WINDOW + state.spell_gcd
            if state.time_to_swing <= lead + PREP_LEAD_BUFFER then return false end
        end
        -- Don't override Seal of Wisdom during mana recovery.
        if context.seal_wisdom_active and context.settings.use_seal_of_wisdom_low_mana then
            local threshold = context.settings.seal_of_wisdom_mana_pct or 20
            if context.mana_pct <= threshold then return false end
        end
        return true
    end,

    execute = function(icon, context, state)
        if SealOfBloodAction:IsReady(PLAYER_UNIT) then
            return SealOfBloodAction:Show(icon), "[RET] Maintain SoB (resident)"
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
    named("Opener",              Ret_Opener),
    named("JudgeSeal",           Ret_JudgeSeal),
    named("CrusaderStrike",      Ret_CrusaderStrike),
    named("TwistBlood",          Ret_TwistBlood),
    named("PrepCommand",         Ret_PrepCommand),
    named("MaintainBlood",       Ret_MaintainBlood),
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
