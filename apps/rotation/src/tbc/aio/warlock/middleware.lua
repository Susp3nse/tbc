-- Warlock Middleware Module
-- Cross-playstyle concerns: emergency, recovery, mana management, threat, self-buffs

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARLOCK" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Warlock Middleware]|r Core module not loaded!")
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
-- DEATH COIL (Emergency — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_DeathCoil",
    priority = Priority.MIDDLEWARE.EMERGENCY_HEAL,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.death_coil_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DeathCoil:IsReady(TARGET_UNIT) then
            return A.DeathCoil:Show(icon), format("[MW] Death Coil - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_Healthstone",
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
            A.HealthstoneFel, A.HealthstoneMaster, A.HealthstoneMajor)
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
    name = "Warlock_HealingPotion",
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
-- SOULSHATTER (Threat reduction)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_Soulshatter",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE,
    is_defensive = true,

    matches = function(context)
        if not context.settings.use_soulshatter then return false end
        if not context.in_combat then return false end
        if context.soul_shards < 1 then return false end
        return true
    end,

    execute = function(icon, context)
        -- Use when we're the tank target or about to pull aggro
        -- IsTanking returns true when we're highest on threat — use as trigger
        local isTanking = Unit(PLAYER_UNIT):IsTanking(TARGET_UNIT)
        if isTanking and A.Soulshatter:IsReady(PLAYER_UNIT) then
            return A.Soulshatter:Show(icon), "[MW] Soulshatter (threat)"
        end
        return nil
    end,
})

-- ============================================================================
-- DARK PACT (Pet mana -> warlock mana, Affliction talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_DarkPact",
    priority = Priority.MIDDLEWARE.INNERVATE,

    matches = function(context)
        if not context.settings.aff_use_dark_pact then return false end
        if not context.in_combat then return false end
        local threshold = context.settings.life_tap_mana_pct or 30
        if context.mana_pct > threshold then return false end
        if not context.pet_active then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DarkPact:IsReady(PLAYER_UNIT) then
            return A.DarkPact:Show(icon), format("[MW] Dark Pact - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- LIFE TAP (HP -> Mana, proactive when safe)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_LifeTap",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 15,

    matches = function(context)
        if not context.in_combat then return false end
        local mana_threshold = context.settings.life_tap_mana_pct or 30
        if context.mana_pct > mana_threshold then return false end
        local min_hp = context.settings.life_tap_min_hp or 40
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.LifeTap:IsReady(PLAYER_UNIT) then
            return A.LifeTap:Show(icon), format("[MW] Life Tap - Mana: %.0f%% HP: %.0f%%", context.mana_pct, context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- MANA POTION (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_ManaPotion",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,

    matches = function(context)
        if not context.settings.use_mana_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_potion_pct or 30
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperManaPotion:IsReady(PLAYER_UNIT) then
            return A.SuperManaPotion:Show(icon), format("[MW] Super Mana Potion - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- DARK/DEMONIC RUNE (Mana recovery — separate CD from potion)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_DarkRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 10,

    matches = function(context)
        if not context.settings.use_dark_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.dark_rune_pct or 30
        if context.mana_pct > threshold then return false end
        local min_hp = context.settings.dark_rune_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DarkRune:IsReady(PLAYER_UNIT) then
            return A.DarkRune:Show(icon), format("[MW] Dark Rune - Mana: %.0f%%", context.mana_pct)
        end
        if A.DemonicRune:IsReady(PLAYER_UNIT) then
            return A.DemonicRune:Show(icon), format("[MW] Demonic Rune - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: FEL ARMOR (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warlock_SelfBuffArmor",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC + 10,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_fel_armor then return false end
        -- Check if any armor buff is active
        if (Unit(PLAYER_UNIT):HasBuffs(Constants.ARMOR_BUFF_IDS) or 0) > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        -- Try Fel Armor R2 first, then R1, then Demon Armor as fallback
        if A.FelArmor:IsReady(PLAYER_UNIT) then
            return A.FelArmor:Show(icon), "[MW] Fel Armor"
        end
        if A.FelArmorR1:IsReady(PLAYER_UNIT) then
            return A.FelArmorR1:Show(icon), "[MW] Fel Armor (R1)"
        end
        if A.DemonArmor:IsReady(PLAYER_UNIT) then
            return A.DemonArmor:Show(icon), "[MW] Demon Armor (fallback)"
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warlock]|r Middleware module loaded")
