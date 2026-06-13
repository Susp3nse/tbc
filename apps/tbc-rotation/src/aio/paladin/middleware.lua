-- Paladin Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, dispels, self-buffs

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PALADIN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Paladin Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local DetermineUsableObject = A.DetermineUsableObject

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- DIVINE SHIELD (Emergency — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_DivineShield",
    priority = Priority.MIDDLEWARE.FORM_RESHIFT,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.divine_shield_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DivineShield:IsReady(PLAYER_UNIT) then
            return A.DivineShield:Show(icon), format("[MW] Divine Shield - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- LAY ON HANDS (Emergency full heal)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_LayOnHands",
    priority = 450,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.lay_on_hands_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context)
        if A.LayOnHands:IsReady(PLAYER_UNIT) then
            return A.LayOnHands:Show(icon), format("[MW] Lay on Hands - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_Healthstone",
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
    name = "Paladin_HealingPotion",
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
-- MANA POTION (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_ManaPotion",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY,

    matches = function(context)
        if not context.settings.use_mana_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_potion_pct or 40
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperManaPotion:IsExists() and A.SuperManaPotion:IsReady(PLAYER_UNIT) then
            return A.SuperManaPotion:Show(icon), format("[MW] Super Mana Potion - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- DARK/DEMONIC RUNE (Mana recovery — separate CD from potion)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_DarkRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,

    matches = function(context)
        if not context.settings.use_dark_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.dark_rune_pct or 40
        if context.mana_pct > threshold then return false end
        local min_hp = context.settings.dark_rune_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DarkRune:IsExists() and A.DarkRune:IsReady(PLAYER_UNIT) then
            return A.DarkRune:Show(icon), format("[MW] Dark Rune - Mana: %.0f%%", context.mana_pct)
        end
        if A.DemonicRune:IsExists() and A.DemonicRune:IsReady(PLAYER_UNIT) then
            return A.DemonicRune:Show(icon), format("[MW] Demonic Rune - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- SEAL OF WISDOM (Low mana seal swap)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_SealOfWisdom",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 10,

    matches = function(context)
        if not context.settings.use_seal_of_wisdom_low_mana then return false end
        if not context.in_combat then return false end
        -- Don't switch if already using Seal of Wisdom
        if context.seal_wisdom_active then return false end
        -- Only switch when mana is below threshold
        local threshold = context.settings.seal_of_wisdom_mana_pct or 20
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SealOfWisdom:IsReady(PLAYER_UNIT) then
            return A.SealOfWisdom:Show(icon), format("[MW] Seal of Wisdom - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- CLEANSE (Dispel on self — poison + disease + magic w/ talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_Cleanse",
    priority = 200,

    matches = function(context)
        if not context.settings.use_cleanse then return false end
        if context.is_mounted then return false end
        local hasPoison = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Poison")
        local hasDisease = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Disease")
        local hasMagic = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Magic")
        if not hasPoison and not hasDisease and not hasMagic then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Cleanse:IsReady(PLAYER_UNIT) then
            return A.Cleanse:Show(icon), "[MW] Cleanse"
        end
        return nil
    end,
})

-- ============================================================================
-- HAMMER OF JUSTICE (Interrupt via stun)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_HammerOfJustice",
    priority = 150,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_hammer_of_justice then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if A.HammerOfJustice:IsReady(TARGET_UNIT) then
                return A.HammerOfJustice:Show(icon), format("[MW] Hammer of Justice - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: AURA (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_SelfBuffAura",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC + 10,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        -- Check if any aura is active
        if (Unit(PLAYER_UNIT):HasBuffs(Constants.AURA_BUFF_IDS) or 0) > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        local spec = context.settings.playstyle or "retribution"

        -- Ret: Sanctity Aura if known, else Devotion
        if spec == "retribution" then
            if A.SanctityAura:IsReady(PLAYER_UNIT) then
                return A.SanctityAura:Show(icon), "[MW] Sanctity Aura"
            end
            if A.DevotionAura:IsReady(PLAYER_UNIT) then
                return A.DevotionAura:Show(icon), "[MW] Devotion Aura (fallback)"
            end
        end

        -- Prot: Devotion Aura (or Ret Aura for threat)
        if spec == "protection" then
            if A.DevotionAura:IsReady(PLAYER_UNIT) then
                return A.DevotionAura:Show(icon), "[MW] Devotion Aura"
            end
            if A.RetributionAura:IsReady(PLAYER_UNIT) then
                return A.RetributionAura:Show(icon), "[MW] Retribution Aura (fallback)"
            end
        end

        -- Holy: Concentration Aura
        if spec == "holy" then
            if A.ConcentrationAura:IsReady(PLAYER_UNIT) then
                return A.ConcentrationAura:Show(icon), "[MW] Concentration Aura"
            end
            if A.DevotionAura:IsReady(PLAYER_UNIT) then
                return A.DevotionAura:Show(icon), "[MW] Devotion Aura (fallback)"
            end
        end

        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: BLESSING (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_SelfBuffBlessing",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        -- Check if any blessing is active
        if (Unit(PLAYER_UNIT):HasBuffs(Constants.BLESSING_BUFF_IDS) or 0) > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        local spec = context.settings.playstyle or "retribution"

        -- Ret: Blessing of Might
        if spec == "retribution" then
            if A.BlessingOfMight:IsReady(PLAYER_UNIT) then
                return A.BlessingOfMight:Show(icon), "[MW] Blessing of Might"
            end
        end

        -- Prot: Blessing of Kings if known, else Sanctuary
        if spec == "protection" then
            if A.BlessingOfKings:IsReady(PLAYER_UNIT) then
                return A.BlessingOfKings:Show(icon), "[MW] Blessing of Kings"
            end
            if A.BlessingOfMight:IsReady(PLAYER_UNIT) then
                return A.BlessingOfMight:Show(icon), "[MW] Blessing of Might (fallback)"
            end
        end

        -- Holy: Blessing of Wisdom
        if spec == "holy" then
            if A.BlessingOfWisdom:IsReady(PLAYER_UNIT) then
                return A.BlessingOfWisdom:Show(icon), "[MW] Blessing of Wisdom"
            end
        end

        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Paladin]|r Middleware module loaded")
