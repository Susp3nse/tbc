--- Affliction Warlock Module
--- Affliction playstyle strategies: DoT maintenance + Shadow Bolt filler
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARLOCK" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Affliction]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Affliction]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local get_curse_duration = NS.get_curse_duration
local get_curse_spell = NS.get_curse_spell
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- AFFLICTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local affliction_state = {
    corruption_duration = 0,
    ua_duration = 0,
    siphon_duration = 0,
    immolate_duration = 0,
    curse_duration = 0,
    isb_active = false,
}

local function get_affliction_state(context)
    if context._affliction_valid then return affliction_state end
    context._affliction_valid = true

    affliction_state.corruption_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.CORRUPTION) or 0
    affliction_state.ua_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.UNSTABLE_AFF) or 0
    affliction_state.siphon_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SIPHON_LIFE) or 0
    affliction_state.immolate_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.IMMOLATE) or 0
    affliction_state.curse_duration = get_curse_duration(context)
    affliction_state.isb_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.ISB) or 0) > 0

    return affliction_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Shadow Trance (Nightfall) proc — instant Shadow Bolt, highest priority
local Aff_ShadowTrance = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ShadowBolt,
    setting_key = "aff_use_shadow_trance",

    matches = function(context, state)
        return context.has_shadow_trance
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShadowBolt, icon, TARGET_UNIT, "[AFF] Shadow Bolt (Nightfall)")
    end,
}

-- [2] Maintain Curse — apply assigned curse if missing/expired
-- Amplify Curse cast before CoD/CoA when available
local Aff_MaintainCurse = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.settings.curse_type == "none" then return false end
        -- CoA has accelerating ticks — last ticks deal most damage, never clip early
        local threshold = 1.5
        if context.settings.curse_type == "agony" then
            threshold = 0.1
        end
        return state.curse_duration < threshold
    end,

    execute = function(icon, context, state)
        -- Amplify Curse before CoD or CoA
        local curse_type = context.settings.curse_type
        if context.settings.aff_use_amplify_curse
            and (curse_type == "doom" or curse_type == "agony")
            and is_spell_available(A.AmplifyCurse) then
            local result = try_cast(A.AmplifyCurse, icon, PLAYER_UNIT, "[AFF] Amplify Curse")
            if result then return result end
        end

        local curse_spell = get_curse_spell(context)
        if curse_spell then
            return try_cast(curse_spell, icon, TARGET_UNIT,
                format("[AFF] %s", context.settings.curse_type))
        end
        return nil
    end,
}

-- [3] Maintain Unstable Affliction — refresh when dot falls off
local Aff_MaintainUA = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.UnstableAffliction,
    setting_key = "aff_use_ua",

    matches = function(context, state)
        if context.is_moving then return false end
        return state.ua_duration < 3  -- 1.5s cast time, start early
    end,

    execute = function(icon, context, state)
        return try_cast(A.UnstableAffliction, icon, TARGET_UNIT,
            format("[AFF] Unstable Affliction - Dur: %.1fs", state.ua_duration))
    end,
}

-- [4] Maintain Corruption — refresh when dot falls off (instant cast)
local Aff_MaintainCorruption = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Corruption,
    setting_key = "aff_use_corruption",

    matches = function(context, state)
        return state.corruption_duration < 1.5
    end,

    execute = function(icon, context, state)
        return try_cast(A.Corruption, icon, TARGET_UNIT,
            format("[AFF] Corruption - Dur: %.1fs", state.corruption_duration))
    end,
}

-- [5] Maintain Siphon Life — only when ISB debuff active on target
local Aff_MaintainSiphonLife = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.SiphonLife,
    setting_key = "aff_use_siphon_life",

    matches = function(context, state)
        if state.siphon_duration > 1.5 then return false end
        -- wowsims optimization: only apply when ISB (+20% shadow) is active
        return state.isb_active
    end,

    execute = function(icon, context, state)
        return try_cast(A.SiphonLife, icon, TARGET_UNIT,
            format("[AFF] Siphon Life - Dur: %.1fs ISB: yes", state.siphon_duration))
    end,
}

-- [6] Maintain Immolate — optional, reapply when dot falls off
local Aff_MaintainImmolate = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Immolate,
    setting_key = "aff_use_immolate",

    matches = function(context, state)
        if context.is_moving then return false end
        return state.immolate_duration < 3  -- 2.0s cast (1.5s w/ Bane)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Immolate, icon, TARGET_UNIT,
            format("[AFF] Immolate - Dur: %.1fs", state.immolate_duration))
    end,
}

-- [7] Drain Soul Execute — target below HP threshold
local Aff_DrainSoul = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.DrainSoul,
    setting_key = "aff_use_drain_soul",

    matches = function(context, state)
        if context.is_moving then return false end
        local threshold = context.settings.aff_drain_soul_hp or 25
        return context.target_hp < threshold
    end,

    execute = function(icon, context, state)
        return try_cast(A.DrainSoul, icon, TARGET_UNIT,
            format("[AFF] Drain Soul - Target: %.0f%%", context.target_hp))
    end,
}

-- [8] AoE — Seed of Corruption when enough enemies
local Aff_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if context.enemy_count < threshold then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.SeedOfCorruption, icon, TARGET_UNIT,
            format("[AFF] Seed of Corruption (AoE) - Enemies: %d", context.enemy_count))
    end,
}

-- [9] Racial (off-GCD)
local Aff_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if A.BloodFury:IsReady(PLAYER_UNIT) then return true end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFury:IsReady(PLAYER_UNIT) then
            return A.BloodFury:Show(icon), "[AFF] Blood Fury"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[AFF] Arcane Torrent"
        end
        return nil
    end,
}

-- [11] Shadow Bolt — primary filler
local Aff_ShadowBolt = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ShadowBolt,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShadowBolt, icon, TARGET_UNIT, "[AFF] Shadow Bolt")
    end,
}

-- [12] Life Tap — mana fallback (backup if middleware didn't fire)
local Aff_LifeTap = {
    requires_combat = true,
    spell = A.LifeTap,

    matches = function(context, state)
        local min_hp = context.settings.life_tap_min_hp or 40
        if context.hp < min_hp then return false end
        -- Mirror the middleware threshold so this only fires when middleware would also fire
        local threshold = context.settings.life_tap_mana_pct or 30
        return context.mana_pct < threshold
    end,

    execute = function(icon, context, state)
        return try_cast(A.LifeTap, icon, PLAYER_UNIT,
            format("[AFF] Life Tap (fallback) - Mana: %.0f%%", context.mana_pct))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("affliction", {
    named("ShadowTrance",        Aff_ShadowTrance),
    named("MaintainCurse",       Aff_MaintainCurse),
    named("MaintainUA",          Aff_MaintainUA),
    named("MaintainCorruption",  Aff_MaintainCorruption),
    named("MaintainSiphonLife",  Aff_MaintainSiphonLife),
    named("MaintainImmolate",    Aff_MaintainImmolate),
    named("DrainSoul",           Aff_DrainSoul),
    named("AoE",                 Aff_AoE),              -- below DoT maintenance
    named("Racial",              Aff_Racial),
    named("ShadowBolt",          Aff_ShadowBolt),
    named("LifeTap",             Aff_LifeTap),
}, {
    context_builder = get_affliction_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warlock]|r Affliction module loaded")
