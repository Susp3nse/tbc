--- Destruction Warlock Module
--- Destruction playstyle strategies: Shadow Bolt spam or Immolate/Incinerate/Conflagrate cycle
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARLOCK" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Destruction]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Menagerie Destruction]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local create_racial_strategy = NS.create_racial_strategy
local get_curse_duration = NS.get_curse_duration
local is_spell_available = NS.is_spell_available
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- DESTRUCTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local destro_state = {
    immolate_duration = 0,
    curse_duration = 0,
    backlash_active = false,
    isb_active = false,
    target_below_execute = false,
    is_fire_build = false,
}

local function get_destro_state(context)
    if context._destro_valid then return destro_state end
    context._destro_valid = true

    destro_state.immolate_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.IMMOLATE, "player", true) or 0
    destro_state.curse_duration = get_curse_duration(context)
    destro_state.backlash_active = context.has_backlash
    destro_state.isb_active = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.ISB) or 0) > 0
    local sb_hp = context.settings.destro_shadowburn_hp or 10
    destro_state.target_below_execute = context.target_hp < sb_hp
    destro_state.is_fire_build = context.settings.destro_primary_spell == "incinerate"

    return destro_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Backlash Proc — instant Shadow Bolt or Incinerate
local Destro_Backlash = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "destro_use_backlash",

    matches = function(context, state)
        return state.backlash_active
    end,

    execute = function(icon, context, state)
        -- Fire build: instant Incinerate; Shadow build: instant Shadow Bolt
        if state.is_fire_build and is_spell_available(A.Incinerate) then
            local result = try_cast(A.Incinerate, icon, TARGET_UNIT, "[DESTRO] Incinerate (Backlash)")
            if result then return result end
        end
        return try_cast(A.ShadowBolt, icon, TARGET_UNIT, "[DESTRO] Shadow Bolt (Backlash)")
    end,
}

-- [2] Maintain Immolate — ALWAYS top priority for fire build (Incinerate needs it for +25%)
local Destro_MaintainImmolate = NS.maintain_aura({
    name = "MaintainImmolate",
    log_prefix = "[DESTRO]",
    requires_combat = true,
    requires_enemy = true,
    spell = A.Immolate,
    kind = "debuff",
    source = "player",
    window = 3,
    remaining_field = "immolate_duration",
    setting_key = "destro_use_immolate",
    extra_guard = function(context, state)
        return state.is_fire_build and not context.is_moving
    end,
})

-- [3] Conflagrate — instant, use on CD, CONSUMES Immolate
-- Only fire if Immolate IS currently on target (Conflagrate requires it)
local Destro_Conflagrate = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Conflagrate,
    setting_key = "destro_use_conflagrate",

    matches = function(context, state)
        -- Only for fire build (shadow build doesn't maintain Immolate)
        if not state.is_fire_build then return false end
        -- Conflagrate requires Immolate to be on target (it consumes it)
        return state.immolate_duration > 0
    end,

    execute = function(icon, context, state)
        return try_cast(A.Conflagrate, icon, TARGET_UNIT,
            format("[DESTRO] Conflagrate - Immo: %.1fs", state.immolate_duration))
    end,
}

-- [4] Maintain Curse — apply assigned curse if missing/expired
local Destro_MaintainCurse = NS.make_maintain_curse("DESTRO")

-- [5] Shadowfury — instant AoE stun on CD (41pt Destro talent)
local Destro_Shadowfury = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Shadowfury,
    setting_key = "destro_use_shadowfury",

    matches = function(context, state)
        -- Fire build: use on CD (DPS gain even single-target)
        if state.is_fire_build then return true end
        -- Shadow build: only use for AoE
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if context.enemy_count < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Shadowfury, icon, TARGET_UNIT, "[DESTRO] Shadowfury")
    end,
}

-- [6] Shadowburn — execute below HP threshold (instant, costs 1 Soul Shard)
local Destro_Shadowburn = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Shadowburn,
    setting_key = "destro_use_shadowburn",

    matches = function(context, state)
        if context.soul_shards < 1 then return false end
        return state.target_below_execute
    end,

    execute = function(icon, context, state)
        return try_cast(A.Shadowburn, icon, TARGET_UNIT,
            format("[DESTRO] Shadowburn - Target: %.0f%% Shards: %d", context.target_hp, context.soul_shards))
    end,
}

-- [7] AoE — Seed of Corruption when enough enemies
local Destro_AoE = NS.make_aoe("DESTRO")

-- [8] Racial (off-GCD)
local DESTRO_RACIAL_SPELLS = {
    { A.BloodFury, "Blood Fury" },
    { A.ArcaneTorrent, "Arcane Torrent" },
}
local Destro_Racial = create_racial_strategy({ prefix = "DESTRO", spells = DESTRO_RACIAL_SPELLS })

-- [10] Primary Spell — Shadow Bolt or Incinerate filler
local Destro_PrimarySpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        if state.is_fire_build and is_spell_available(A.Incinerate) then
            local result = try_cast(A.Incinerate, icon, TARGET_UNIT, "[DESTRO] Incinerate")
            if result then return result end
        end
        return try_cast(A.ShadowBolt, icon, TARGET_UNIT, "[DESTRO] Shadow Bolt")
    end,
}

-- [11] Life Tap — mana fallback
local Destro_LifeTap = NS.make_lifetap("DESTRO")

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("destruction", {
    named("Backlash",           Destro_Backlash),
    named("MaintainImmolate",   Destro_MaintainImmolate),
    named("Conflagrate",        Destro_Conflagrate),
    named("MaintainCurse",      Destro_MaintainCurse),
    named("Shadowfury",         Destro_Shadowfury),
    named("Shadowburn",         Destro_Shadowburn),
    named("AoE",                Destro_AoE),
    named("Racial",             Destro_Racial),
    named("PrimarySpell",       Destro_PrimarySpell),
    named("LifeTap",            Destro_LifeTap),
}, {
    context_builder = get_destro_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Warlock]|r Destruction module loaded")
