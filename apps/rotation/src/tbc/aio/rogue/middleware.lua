-- Rogue Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, energy, threat

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "ROGUE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Rogue Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local DetermineUsableObject = A.DetermineUsableObject

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- EMERGENCY VANISH (Last resort — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_EmergencyVanish",
    priority = 500,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_vanish_emergency then return false end
        local threshold = context.settings.vanish_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Vanish:IsReady(PLAYER_UNIT) then
            return A.Vanish:Show(icon), format("[MW] Emergency Vanish - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- EVASION (Emergency dodge)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_Evasion",
    priority = 450,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_evasion then return false end
        local threshold = context.settings.evasion_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Evasion:IsReady(PLAYER_UNIT) then
            return A.Evasion:Show(icon), format("[MW] Evasion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- CLOAK OF SHADOWS (Magic debuff removal)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_CloakOfShadows",
    priority = 400,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_cloak_of_shadows then return false end
        local threshold = context.settings.cloak_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        local hasMagic = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Magic")
        if not hasMagic then return false end
        return true
    end,

    execute = function(icon, context)
        if A.CloakOfShadows:IsReady(PLAYER_UNIT) then
            return A.CloakOfShadows:Show(icon), format("[MW] Cloak of Shadows - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- KICK (Interrupt)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_Kick",
    priority = 350,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_kick then return false end
        if not context.has_valid_enemy_target then return false end
        if context.energy < Constants.ENERGY.KICK then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if A.Kick:IsReady(TARGET_UNIT) then
                return A.Kick:Show(icon), format("[MW] Kick - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.healthstone_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local HealthStoneObject = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HealthstoneMaster, A.HealthstoneMajor)
        if HealthStoneObject then
            return HealthStoneObject:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALING POTION (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,

    matches = function(context)
        if not context.settings.use_healing_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.healing_potion_hp or 25
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperHealingPotion:IsReady(PLAYER_UNIT) then
            return A.SuperHealingPotion:Show(icon), format("[MW] Super Healing Potion - HP: %.0f%%", context.hp)
        end
        if A.MajorHealingPotion:IsReady(PLAYER_UNIT) then
            return A.MajorHealingPotion:Show(icon), format("[MW] Major Healing Potion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- FEINT (Threat reduction)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_Feint",
    priority = 280,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_feint then return false end
        if not context.has_valid_enemy_target then return false end
        if context.energy < Constants.ENERGY.FEINT then return false end
        -- Only use when we have significant threat (tanking the target)
        local isTanking = Unit(PLAYER_UNIT):IsTanking(TARGET_UNIT)
        if not isTanking then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Feint:IsReady(TARGET_UNIT) then
            return A.Feint:Show(icon), "[MW] Feint - Threat reduction"
        end
        return nil
    end,
})

-- ============================================================================
-- THISTLE TEA (Energy recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_ThistleTea",
    priority = 250,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_thistle_tea then return false end
        local threshold = context.settings.thistle_tea_energy or 40
        if context.energy > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.ThistleTea:IsReady(PLAYER_UNIT) then
            return A.ThistleTea:Show(icon), format("[MW] Thistle Tea - Energy: %d", context.energy)
        end
        return nil
    end,
})

-- ============================================================================
-- HASTE POTION (Burst DPS — sync with BF/AR burst window)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Rogue_HastePotion",
    priority = 200,
    is_burst = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_haste_potion then return false end
        if context.combat_time < 2 then return false end
        return true
    end,

    execute = function(icon, context)
        if A.HastePotion:IsReady(PLAYER_UNIT) then
            return A.HastePotion:Show(icon), "[MW] Haste Potion"
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Rogue]|r Middleware module loaded (9 entries)")
