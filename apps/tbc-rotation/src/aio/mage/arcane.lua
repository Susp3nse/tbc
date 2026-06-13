--- Arcane Mage Module
--- Arcane playstyle strategies with burn/conserve phase management
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "MAGE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Arcane]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Arcane]|r Registry not found!")
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
-- PHASE TRACKING (persists across frames)
-- ============================================================================
-- Arcane uses a two-phase system:
--   "burn"    = spend mana freely, spam AB with all CDs
--   "conserve" = AB x N → filler while stacks drop, repeat
local arcane_phase = "burn"

-- ============================================================================
-- ARCANE STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local arcane_state = {
    is_burning = true,
    is_conserving = false,
    ab_will_drop = false,
}

local function get_arcane_state(context)
    if context._arcane_valid then return arcane_state end
    context._arcane_valid = true

    local settings = context.settings
    local start_conserve = settings.arcane_start_conserve_pct or Constants.ARCANE.DEFAULT_START_CONSERVE
    local stop_conserve = settings.arcane_stop_conserve_pct or Constants.ARCANE.DEFAULT_STOP_CONSERVE

    -- Lower conserve threshold during Bloodlust/Heroism (burn harder)
    local has_bloodlust = (Unit("player"):HasBuffs(Constants.BLOODLUST_IDS, true) or 0) > 0
    if has_bloodlust and start_conserve > 10 then
        start_conserve = 10
    end

    -- Phase transitions
    if arcane_phase == "burn" and context.mana_pct <= start_conserve then
        arcane_phase = "conserve"
    elseif arcane_phase == "conserve" and context.mana_pct >= stop_conserve and context.ab_stacks <= 1 then
        arcane_phase = "burn"
    end

    -- Reset on combat exit
    if not context.in_combat then
        arcane_phase = "burn"
    end

    arcane_state.is_burning = (arcane_phase == "burn")
    arcane_state.is_conserving = (arcane_phase == "conserve")

    -- Will AB stacks drop before we can recast?
    local ab_cast_time = A.ArcaneBlast:GetSpellCastTimeCache() or 2.5
    arcane_state.ab_will_drop = context.ab_duration > 0 and context.ab_duration < ab_cast_time

    return arcane_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Icy Veins (off-GCD, first CD to activate for Cold Snap reset later)
local Arcane_IcyVeins = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.IcyVeins,
    spell_target = PLAYER_UNIT,
    setting_key = "arcane_use_icy_veins",

    matches = function(context, state)
        if not state.is_burning then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.IcyVeins, icon, PLAYER_UNIT, "[ARCANE] Icy Veins")
    end,
}

-- [2] Cold Snap (reset Icy Veins CD after it expires)
local Arcane_ColdSnap = {
    requires_combat = true,
    is_burst = true,
    spell = A.ColdSnap,
    spell_target = PLAYER_UNIT,
    setting_key = "arcane_use_cold_snap",

    matches = function(context, state)
        if not state.is_burning then return false end
        -- Don't waste Cold Snap while Icy Veins is still active
        if context.icy_veins_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local iv_cd = A.IcyVeins:GetCooldown() or 0
        if iv_cd < 20 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ColdSnap, icon, PLAYER_UNIT, "[ARCANE] Cold Snap")
    end,
}

-- [3] Arcane Power (off-GCD, burn phase only)
local Arcane_ArcanePower = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.ArcanePower,
    spell_target = PLAYER_UNIT,
    setting_key = "arcane_use_arcane_power",

    matches = function(context, state)
        if not state.is_burning then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ArcanePower, icon, PLAYER_UNIT, "[ARCANE] Arcane Power")
    end,
}

-- [4] Presence of Mind (off-GCD, instant next AB during burn)
local Arcane_PresenceOfMind = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.PresenceOfMind,
    spell_target = PLAYER_UNIT,
    setting_key = "arcane_use_pom",

    matches = function(context, state)
        if not state.is_burning then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.PresenceOfMind, icon, PLAYER_UNIT, "[ARCANE] Presence of Mind")
    end,
}

-- [5] Racial (off-GCD, burn phase only — DPS racials wasted during conserve)
local Arcane_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        if not state.is_burning then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[ARCANE] Berserking"
        end
        if A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
            return A.ArcaneTorrent:Show(icon), "[ARCANE] Arcane Torrent"
        end
        return nil
    end,
}

-- [7] AoE rotation (when enough enemies)
local Arcane_AoE = {
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
        -- Arcane Explosion preferred (lowest threat via Arcane Subtlety)
        if context.enemy_count_melee >= threshold and A.ArcaneExplosion:IsReady(PLAYER_UNIT) then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[ARCANE] Arcane Explosion (AoE)")
        end
        -- Ranged AoE filler
        return try_cast(A.Flamestrike, icon, TARGET_UNIT, "[ARCANE] Flamestrike (AoE)")
    end,
}

-- [8] Movement spell (Fire Blast while moving)
local Arcane_MovementSpell = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local result, msg
        if s.arcane_move_fire_blast then
            result, msg = try_cast(A.FireBlast, icon, TARGET_UNIT, "[ARCANE] Fire Blast (moving)")
            if result then return result, msg end
        end
        if s.arcane_move_ice_lance then
            result, msg = try_cast(A.IceLance, icon, TARGET_UNIT, "[ARCANE] Ice Lance (moving)")
            if result then return result, msg end
        end
        if s.arcane_move_cone_of_cold then
            result, msg = try_cast(A.ConeOfCold, icon, TARGET_UNIT, "[ARCANE] Cone of Cold (moving)")
            if result then return result, msg end
        end
        if s.arcane_move_arcane_explosion and context.in_melee_range then
            return try_cast(A.ArcaneExplosion, icon, PLAYER_UNIT, "[ARCANE] Arcane Explosion (moving)")
        end
        return nil
    end,
}

-- [9] Burn phase — spam Arcane Blast
local Arcane_BurnAB = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ArcaneBlast,

    matches = function(context, state)
        if context.is_moving then return false end
        if not state.is_burning then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ArcaneBlast, icon, TARGET_UNIT,
            format("[ARCANE] Arcane Blast (BURN) - Stacks: %d", context.ab_stacks))
    end,
}

-- [10] Conserve phase — N Arcane Blasts per cycle (uses ab_stacks as cast counter)
local Arcane_ConserveAB = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ArcaneBlast,

    matches = function(context, state)
        if context.is_moving then return false end
        if not state.is_conserving then return false end
        -- Use ab_stacks as the reliable cast counter (0-3 stacks tracks AB casts)
        local max_casts = context.settings.arcane_blasts_between_fillers or Constants.ARCANE.DEFAULT_BLASTS_BEFORE_FILLER
        -- Clearcasting: allow one extra AB since it's free (no mana cost)
        if context.ab_stacks >= max_casts and not context.has_clearcasting then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ArcaneBlast, icon, TARGET_UNIT,
            format("[ARCANE] Arcane Blast (CONSERVE %d/%d)%s",
                context.ab_stacks + 1,
                context.settings.arcane_blasts_between_fillers or Constants.ARCANE.DEFAULT_BLASTS_BEFORE_FILLER,
                context.has_clearcasting and " [CC]" or ""))
    end,
}

-- [10] Conserve phase — filler spell while AB stacks drop
local Arcane_Filler = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if context.is_moving then return false end
        if not state.is_conserving then return false end
        local max_casts = context.settings.arcane_blasts_between_fillers or Constants.ARCANE.DEFAULT_BLASTS_BEFORE_FILLER
        -- Cast filler when ab_stacks reached max (ConserveAB blocks), or when stacks are about to drop
        if context.ab_stacks < max_casts and not state.ab_will_drop then return false end
        return true
    end,

    execute = function(icon, context, state)
        local filler = context.settings.arcane_filler or "frostbolt"
        if filler == "frostbolt" then
            return try_cast(A.Frostbolt, icon, TARGET_UNIT, "[ARCANE] Frostbolt (filler)")
        elseif filler == "fireball" then
            return try_cast(A.Fireball, icon, TARGET_UNIT, "[ARCANE] Fireball (filler)")
        elseif filler == "arcane_missiles" then
            return try_cast(A.ArcaneMissiles, icon, TARGET_UNIT, "[ARCANE] Arcane Missiles (filler)")
        elseif filler == "scorch" then
            return try_cast(A.Scorch, icon, TARGET_UNIT, "[ARCANE] Scorch (filler)")
        end
        -- Fallback
        return try_cast(A.Frostbolt, icon, TARGET_UNIT, "[ARCANE] Frostbolt (filler)")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("arcane", {
    named("IcyVeins",        Arcane_IcyVeins),
    named("ColdSnap",        Arcane_ColdSnap),
    named("ArcanePower",     Arcane_ArcanePower),
    named("PresenceOfMind",  Arcane_PresenceOfMind),
    named("Racial",          Arcane_Racial),
    named("AoE",             Arcane_AoE),
    named("MovementSpell",   Arcane_MovementSpell),
    named("BurnAB",          Arcane_BurnAB),
    named("ConserveAB",      Arcane_ConserveAB),
    named("Filler",          Arcane_Filler),
}, {
    context_builder = get_arcane_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Mage]|r Arcane module loaded")
