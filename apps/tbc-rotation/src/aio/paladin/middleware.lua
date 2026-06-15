-- Paladin Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, dispels, self-buffs

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PALADIN" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Paladin Middleware]|r Core module not loaded!")
    return
end

A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- Hammer of Justice ranks 1-4 (TBC). The learned-immune tracker keys on the
-- actual cast spellID, and useMaxRank can cast any learned rank.
local HAMMER_OF_JUSTICE_SPELL_IDS = { 853, 5588, 5589, 10308 }

-- ============================================================================
-- DIVINE SHIELD (Emergency — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Paladin_DivineShield",
    priority = Priority.MIDDLEWARE.EMERGENCY_DEFENSIVE,
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

NS.register_recovery_middleware({
    prefix = "Paladin",
    healthstone = {
        name = "Paladin_Healthstone",
        hp_default = 35,
        actions = { A.HealthstoneMaster, A.HealthstoneMajor },
    },
    healing_potion = {
        name = "Paladin_HealingPotion",
        hp_default = 25,
        actions = { A.SuperHealingPotion, A.MajorHealingPotion },
    },
    mana = {
        potion = {
            name = "Paladin_ManaPotion",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY,
            pct_default = 40,
            actions = { A.SuperManaPotion },
        },
        rune = {
            name = "Paladin_DarkRune",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,
            pct_default = 40,
            actions = { A.DarkRune, A.DemonicRune },
        },
    },
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
        if NS.is_spell_immune(TARGET_UNIT, HAMMER_OF_JUSTICE_SPELL_IDS) then return false end
        return true
    end,

    execute = function(icon, context)
        local cast_left = Unit(TARGET_UNIT):IsCastingRemains()
        if cast_left and cast_left > 0 and A.HammerOfJustice:IsReady(TARGET_UNIT) then
            return A.HammerOfJustice:Show(icon), format("[MW] Hammer of Justice (stun-interrupt) - Cast: %.1fs", cast_left)
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

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Paladin]|r Middleware module loaded")
