--- Demonology Warlock Module
--- Demonology playstyle strategies: Felguard pet DPS + Shadow Bolt, or DS/Ruin nuke
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARLOCK" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Demonology]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Demonology]|r Registry not found!")
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
-- DEMONOLOGY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local demo_state = {
    pet_exists = false,
    pet_hp = 0,
    has_sacrifice = false,
    corruption_duration = 0,
    immolate_duration = 0,
    curse_duration = 0,
}

local function get_demo_state(context)
    if context._demo_valid then return demo_state end
    context._demo_valid = true

    demo_state.pet_exists = context.pet_active
    demo_state.pet_hp = context.pet_hp
    demo_state.has_sacrifice = context.has_ds_any
    demo_state.corruption_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.CORRUPTION) or 0
    demo_state.immolate_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.IMMOLATE) or 0
    demo_state.curse_duration = get_curse_duration(context)

    return demo_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Fel Domination + Pet Resummon — instant resummon if pet dies mid-fight
local Demo_FelDomResummon = {
    requires_combat = true,
    spell = A.FelDomination,
    setting_key = "demo_use_fel_domination",

    matches = function(context, state)
        if context.settings.demo_use_sacrifice then return false end  -- DS/Ruin build
        if context.pet_active then return false end  -- Pet is alive
        return true
    end,

    execute = function(icon, context, state)
        -- Try Fel Domination first (makes next summon instant)
        if is_spell_available(A.FelDomination) and A.FelDomination:IsReady(PLAYER_UNIT) then
            local result = try_cast(A.FelDomination, icon, PLAYER_UNIT, "[DEMO] Fel Domination")
            if result then return result end
        end
        -- Then summon Felguard
        if is_spell_available(A.SummonFelguard) and A.SummonFelguard:IsReady(PLAYER_UNIT) then
            return try_cast(A.SummonFelguard, icon, PLAYER_UNIT, "[DEMO] Summon Felguard (resummon)")
        end
        return nil
    end,
}

-- [2] Soul Link — maintain pet+player damage sharing buff
local Demo_SoulLink = {
    spell = A.SoulLink,
    setting_key = "demo_use_soul_link",

    matches = function(context, state)
        if context.settings.demo_use_sacrifice then return false end  -- DS/Ruin build
        if not context.pet_active then return false end
        if context.has_soul_link then return false end  -- Already active
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.SoulLink, icon, PLAYER_UNIT, "[DEMO] Soul Link")
    end,
}

-- [3] Health Funnel Pet — channel heal pet below threshold (Felguard build only)
local Demo_HealthFunnel = {
    requires_combat = true,
    spell = A.HealthFunnel,

    matches = function(context, state)
        if context.settings.demo_use_sacrifice then return false end  -- DS/Ruin build
        if not state.pet_exists then return false end
        if context.is_moving then return false end
        local threshold = context.settings.demo_pet_heal_hp or 40
        return state.pet_hp < threshold and state.pet_hp > 0
    end,

    execute = function(icon, context, state)
        return try_cast(A.HealthFunnel, icon, "pet",
            format("[DEMO] Health Funnel - Pet HP: %.0f%%", state.pet_hp))
    end,
}

-- [4] Demonic Sacrifice — sacrifice pet if DS build + no buff active
local Demo_DemonicSacrifice = {
    spell = A.DemonicSacrifice,
    setting_key = "demo_use_sacrifice",

    matches = function(context, state)
        if state.has_sacrifice then return false end
        if not state.pet_exists then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemonicSacrifice, icon, PLAYER_UNIT, "[DEMO] Demonic Sacrifice")
    end,
}

-- [5] Maintain Curse — apply assigned curse if missing/expired
local Demo_MaintainCurse = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.settings.curse_type == "none" then return false end
        return state.curse_duration < 1.5
    end,

    execute = function(icon, context, state)
        local curse_spell = get_curse_spell(context)
        if curse_spell then
            return try_cast(curse_spell, icon, TARGET_UNIT,
                format("[DEMO] %s", context.settings.curse_type))
        end
        return nil
    end,
}

-- [4] Maintain Corruption — if enabled (Felguard build usually)
local Demo_MaintainCorruption = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Corruption,
    setting_key = "demo_use_corruption",

    matches = function(context, state)
        return state.corruption_duration < 1.5
    end,

    execute = function(icon, context, state)
        return try_cast(A.Corruption, icon, TARGET_UNIT,
            format("[DEMO] Corruption - Dur: %.1fs", state.corruption_duration))
    end,
}

-- [5] Maintain Immolate — if enabled
local Demo_MaintainImmolate = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Immolate,
    setting_key = "demo_use_immolate",

    matches = function(context, state)
        if context.is_moving then return false end
        return state.immolate_duration < 3
    end,

    execute = function(icon, context, state)
        return try_cast(A.Immolate, icon, TARGET_UNIT,
            format("[DEMO] Immolate - Dur: %.1fs", state.immolate_duration))
    end,
}

-- [6] AoE — Seed of Corruption when enough enemies
local Demo_AoE = {
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
            format("[DEMO] Seed of Corruption (AoE) - Enemies: %d", context.enemy_count))
    end,
}

-- [7] Racial (off-GCD)
local Demo_Racial = {
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
            return A.BloodFury:Show(icon), "[DEMO] Blood Fury"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[DEMO] Arcane Torrent"
        end
        return nil
    end,
}

-- [9] Primary Filler — Shadow Bolt or Incinerate (DS/Ruin fire build)
local Demo_PrimarySpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- DS/Ruin fire build: use Incinerate when fire sacrifice buff is active
        if context.has_ds_fire and is_spell_available(A.Incinerate) then
            local result = try_cast(A.Incinerate, icon, TARGET_UNIT, "[DEMO] Incinerate (DS/Ruin)")
            if result then return result end
        end
        return try_cast(A.ShadowBolt, icon, TARGET_UNIT, "[DEMO] Shadow Bolt")
    end,
}

-- [10] Life Tap — mana fallback
local Demo_LifeTap = {
    requires_combat = true,
    spell = A.LifeTap,

    matches = function(context, state)
        local min_hp = context.settings.life_tap_min_hp or 40
        if context.hp < min_hp then return false end
        local threshold = context.settings.life_tap_mana_pct or 30
        return context.mana_pct < threshold
    end,

    execute = function(icon, context, state)
        return try_cast(A.LifeTap, icon, PLAYER_UNIT,
            format("[DEMO] Life Tap (fallback) - Mana: %.0f%%", context.mana_pct))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("demonology", {
    named("FelDomResummon",      Demo_FelDomResummon),
    named("SoulLink",            Demo_SoulLink),
    named("HealthFunnel",        Demo_HealthFunnel),
    named("DemonicSacrifice",    Demo_DemonicSacrifice),
    named("MaintainCurse",       Demo_MaintainCurse),
    named("MaintainCorruption",  Demo_MaintainCorruption),
    named("MaintainImmolate",    Demo_MaintainImmolate),
    named("AoE",                 Demo_AoE),
    named("Racial",              Demo_Racial),
    named("PrimarySpell",        Demo_PrimarySpell),
    named("LifeTap",             Demo_LifeTap),
}, {
    context_builder = get_demo_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warlock]|r Demonology module loaded")
