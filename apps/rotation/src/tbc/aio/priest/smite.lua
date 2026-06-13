-- Priest Smite DPS Module
-- Holy DPS with Shadow Weaving/Misery utility via SW:P
-- Holy Fire Weave optimization, Surge of Light procs

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Smite]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- SMITE STATE (per-frame cache)
-- ============================================================================
local smite_state = {
    swp_active = false,
    swp_remaining = 0,
    surge_of_light = false,
    hf_ready = false,
    mb_ready = false,
    swd_ready = false,
    swd_safe = false,
    in_weave_window = false,
}

-- Base cast times with Divine Fury talent: Smite 2.0s, Holy Fire 3.0s
local SMITE_CAST_BASE = 2.0
local HF_CAST_BASE = 3.0

local function get_smite_state(context)
    if context._smite_valid then return smite_state end
    context._smite_valid = true

    local swp_dur = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SHADOW_WORD_PAIN, "player", true) or 0
    smite_state.swp_active = swp_dur > 0
    smite_state.swp_remaining = swp_dur
    smite_state.surge_of_light = context.has_surge_of_light
    smite_state.hf_ready = is_spell_available(A.HolyFire) and A.HolyFire:IsReady(TARGET_UNIT)
    smite_state.mb_ready = is_spell_available(A.MindBlast) and A.MindBlast:IsReady(TARGET_UNIT)
    smite_state.swd_ready = is_spell_available(A.ShadowWordDeath) and A.ShadowWordDeath:IsReady(TARGET_UNIT)
    smite_state.swd_safe = context.hp > (context.settings.smite_swd_hp or 40)

    -- Holy Fire Weave window: swpRemaining > smiteCastTime AND swpRemaining < hfCastTime
    -- This means SW:P will fall off during HF cast but NOT during Smite cast
    smite_state.in_weave_window = smite_state.swp_active
        and swp_dur > SMITE_CAST_BASE
        and swp_dur < HF_CAST_BASE

    return smite_state
end

-- ============================================================================
-- SMITE STRATEGIES
-- ============================================================================
rotation_registry:register("smite", {

    -- [1] Shadow Word: Pain (maintain for Shadow Weaving + Misery)
    named("ShadowWordPain", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if state.swp_active then return false end
            if context.ttd < 6 then return false end
            return true
        end,
        execute = function(icon, context, state)
            return try_cast(A.ShadowWordPain, icon, TARGET_UNIT, "[SMITE] SW:P")
        end,
    }),

    -- [2] Starshards (Night Elf racial)
    named("Starshards", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.settings.smite_use_starshards then return false end
            return is_spell_available(A.Starshards) and A.Starshards:IsReady(TARGET_UNIT)
        end,
        execute = function(icon, context, state)
            return try_cast(A.Starshards, icon, TARGET_UNIT, "[SMITE] Starshards")
        end,
    }),

    -- [3] Devouring Plague (Undead racial)
    named("DevouringPlague", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.settings.smite_use_devouring_plague then return false end
            -- Don't waste 3min CD on dying targets
            if context.ttd and context.ttd > 0 and context.ttd < 8 then return false end
            local dp_remaining = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEVOURING_PLAGUE, "player", true) or 0
            if dp_remaining > 3 then return false end
            return is_spell_available(A.DevouringPlague) and A.DevouringPlague:IsReady(TARGET_UNIT)
        end,
        execute = function(icon, context, state)
            return try_cast(A.DevouringPlague, icon, TARGET_UNIT, "[SMITE] Devouring Plague")
        end,
    }),

    -- [4] Mind Blast (optional)
    named("MindBlast", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.settings.smite_use_mb then return false end
            if context.is_moving then return false end
            return state.mb_ready
        end,
        execute = function(icon, context, state)
            return try_cast(A.MindBlast, icon, TARGET_UNIT, "[SMITE] Mind Blast")
        end,
    }),

    -- [5] Shadow Word: Death (optional)
    named("ShadowWordDeath", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.settings.smite_use_swd then return false end
            if not state.swd_safe then return false end
            return state.swd_ready
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.ShadowWordDeath, icon, TARGET_UNIT, "[SMITE]", "SW:D", "HP: %.0f%%", context.hp)
        end,
    }),

    -- [6] Surge of Light Smite (instant free Smite proc)
    named("SurgeOfLightSmite", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            return state.surge_of_light
        end,
        execute = function(icon, context, state)
            return try_cast(A.Smite, icon, TARGET_UNIT, "[SMITE] Surge of Light Smite (instant)")
        end,
    }),

    -- [7] Holy Fire Weave (HF off CD + in weave window)
    named("HolyFireWeave", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not context.settings.smite_holy_fire_weave then return false end
            if context.is_moving then return false end
            if not state.hf_ready then return false end
            return state.in_weave_window
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.HolyFire, icon, TARGET_UNIT, "[SMITE]", "HF Weave", "SW:P rem: %.1fs", state.swp_remaining)
        end,
    }),

    -- [8] Holy Fire (off CD, normal priority outside weave window)
    named("HolyFire", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if context.is_moving then return false end
            -- If weave mode is on and we're in the weave window, skip (handled by HolyFireWeave above)
            if context.settings.smite_holy_fire_weave and state.in_weave_window then return false end
            return state.hf_ready
        end,
        execute = function(icon, context, state)
            return try_cast(A.HolyFire, icon, TARGET_UNIT, "[SMITE] Holy Fire")
        end,
    }),

    -- [8.5] Inner Focus (off-GCD, pair with Holy Fire or Mind Blast)
    named("InnerFocus", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if context.has_inner_focus then return false end
            if not is_spell_available(A.InnerFocus) then return false end
            if not A.InnerFocus:IsReady(PLAYER_UNIT) then return false end
            -- Pair with HF or MB for max value
            return state.hf_ready or state.mb_ready
        end,
        execute = function(icon, context, state)
            return try_cast(A.InnerFocus, icon, PLAYER_UNIT, "[SMITE] Inner Focus")
        end,
    }),

    -- [9] Racial (off-GCD)
    named("Racial", {
        is_gcd_gated = false,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.use_racial then return false end
            return true
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then
                return A.Berserking:Show(icon), "[SMITE] Berserking"
            end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
                return A.ArcaneTorrent:Show(icon), "[SMITE] Arcane Torrent"
            end
            return nil
        end,
    }),

    -- [11] Smite (filler)
    named("SmiteFiller", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if context.is_moving then return false end
            return true
        end,
        execute = function(icon, context, state)
            return try_cast(A.Smite, icon, TARGET_UNIT, "[SMITE] Smite")
        end,
    }),

}, {
    context_builder = get_smite_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Smite rotation loaded")
