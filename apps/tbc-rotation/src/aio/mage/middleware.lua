-- Mage Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, mana, self-buffs

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "MAGE" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Mage Middleware]|r Core module not loaded!")
    return
end

A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local GetNumGroupMembers = _G.GetNumGroupMembers

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- ICE BLOCK (Emergency — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_IceBlock",
    priority = Priority.MIDDLEWARE.EMERGENCY_HEAL,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.ice_block_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        if context.hypothermia then return false end
        return true
    end,

    execute = function(icon, context)
        if A.IceBlock:IsReady(PLAYER_UNIT) then
            return A.IceBlock:Show(icon), format("[MW] Ice Block - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- MANA SHIELD (Emergency absorb)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_ManaShield",
    priority = Priority.MIDDLEWARE.PROACTIVE_HEAL,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.mana_shield_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        if context.mana_pct < 20 then return false end
        return true
    end,

    execute = function(icon, context)
        if A.ManaShield:IsReady(PLAYER_UNIT) then
            return A.ManaShield:Show(icon), format("[MW] Mana Shield - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- ICE BARRIER (Absorb shield — Frost talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_IceBarrier",
    priority = Priority.MIDDLEWARE.PROACTIVE_HEAL - 5,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_ice_barrier then return false end
        local has_barrier = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.ICE_BARRIER) or 0) > 0
        if has_barrier then return false end
        return true
    end,

    execute = function(icon, context)
        if A.IceBarrier:IsReady(PLAYER_UNIT) then
            return A.IceBarrier:Show(icon), "[MW] Ice Barrier"
        end
        return nil
    end,
})

-- ============================================================================
-- COUNTERSPELL (Interrupt)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_Counterspell",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_counterspell then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if A.Counterspell:IsReady(TARGET_UNIT) then
                return A.Counterspell:Show(icon), format("[MW] Counterspell - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

NS.register_recovery_middleware({
    prefix = "Mage",
    healthstone = {
        hp_default = 35,
        actions = { A.HealthstoneMaster, A.HealthstoneMajor },
    },
    healing_potion = {
        hp_default = 25,
        actions = { A.SuperHealingPotion, A.MajorHealingPotion },
    },
    mana = {
        potion = {
            name = "Mage_ManaPotion",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY,
            pct_default = 50,
            actions = { A.SuperManaPotion },
        },
        rune = {
            name = "Mage_DarkRune",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,
            pct_default = 50,
            min_hp_default = 50,
            actions = { A.DarkRune, A.DemonicRune },
        },
    },
})

-- ============================================================================
-- MANA GEM (Mana recovery — separate from potion CD)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_ManaGem",
    priority = 285,

    matches = function(context)
        if not context.settings.use_mana_gem then return false end
        if not context.in_combat then return false end
        local threshold = context.settings.mana_gem_pct or 70
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.ManaEmerald:IsReady(PLAYER_UNIT) then
            return A.ManaEmerald:Show(icon), format("[MW] Mana Emerald - Mana: %.0f%%", context.mana_pct)
        end
        if A.ManaRuby:IsReady(PLAYER_UNIT) then
            return A.ManaRuby:Show(icon), format("[MW] Mana Ruby - Mana: %.0f%%", context.mana_pct)
        end
        if A.ManaCitrine:IsReady(PLAYER_UNIT) then
            return A.ManaCitrine:Show(icon), format("[MW] Mana Citrine - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- EVOCATION (Mana recovery — channeled)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_Evocation",
    priority = 260,

    matches = function(context)
        if not context.settings.use_evocation then return false end
        if not context.in_combat then return false end
        local threshold = context.settings.evocation_pct or 20
        if context.mana_pct > threshold then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Evocation:IsReady(PLAYER_UNIT) then
            return A.Evocation:Show(icon), format("[MW] Evocation - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- REMOVE CURSE (Utility — scans self then party members)
-- ============================================================================
local _curse_target = PLAYER_UNIT  -- updated each frame by matches, read by execute

rotation_registry:register_middleware({
    name = "Mage_RemoveCurse",
    priority = 200,

    matches = function(context)
        if not context.settings.auto_remove_curse then return false end
        if context.is_mounted then return false end
        -- Check self first
        if A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Curse") then
            _curse_target = PLAYER_UNIT
            return true
        end
        -- Scan party members
        local n = GetNumGroupMembers()
        for i = 1, n do
            local unit = "party" .. i
            if A.AuraIsValid(unit, "UseDispel", "Curse") then
                _curse_target = unit
                return true
            end
        end
        return false
    end,

    execute = function(icon, context)
        if A.RemoveCurse:IsReady(_curse_target) then
            return A.RemoveCurse:Show(icon), format("[MW] Remove Curse -> %s", _curse_target)
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: ARMOR (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_SelfBuffArmor",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC + 10,

    matches = function(context)
        if context.is_mounted then return false end
        -- Check if any armor buff is active
        local has_armor = (Unit(PLAYER_UNIT):HasBuffs(Constants.ARMOR_BUFF_IDS) or 0) > 0
        if has_armor then return false end
        return true
    end,

    execute = function(icon, context)
        local armor = context.settings.armor_type or "auto"

        -- Resolve "auto" to Molten Armor (best PvE choice for all specs)
        if armor == "auto" or armor == "molten" then
            if A.MoltenArmor:IsReady(PLAYER_UNIT) then
                return A.MoltenArmor:Show(icon), "[MW] Molten Armor"
            end
        end

        if armor == "mage" then
            if A.MageArmor:IsReady(PLAYER_UNIT) then
                return A.MageArmor:Show(icon), "[MW] Mage Armor"
            end
        end

        if armor == "ice" then
            if A.IceArmor:IsReady(PLAYER_UNIT) then
                return A.IceArmor:Show(icon), "[MW] Ice Armor"
            end
        end

        -- Fallback: try any armor if auto and Molten not available
        if armor == "auto" then
            if A.MageArmor:IsReady(PLAYER_UNIT) then
                return A.MageArmor:Show(icon), "[MW] Mage Armor (fallback)"
            end
            if A.IceArmor:IsReady(PLAYER_UNIT) then
                return A.IceArmor:Show(icon), "[MW] Ice Armor (fallback)"
            end
        end

        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: ARCANE INTELLECT (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Mage_SelfBuffIntellect",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_arcane_intellect then return false end
        local has_int = (Unit(PLAYER_UNIT):HasBuffs(Constants.INTELLECT_BUFF_IDS) or 0) > 0
        if has_int then return false end
        return true
    end,

    execute = function(icon, context)
        -- Try Arcane Brilliance first if in a group
        local in_group = (GetNumGroupMembers() or 0) > 0
        if in_group and A.SelfArcaneBrilliance:IsReady(PLAYER_UNIT) then
            return A.SelfArcaneBrilliance:Show(icon), "[MW] Arcane Brilliance"
        end
        if A.SelfArcaneIntellect:IsReady(PLAYER_UNIT) then
            return A.SelfArcaneIntellect:Show(icon), "[MW] Arcane Intellect"
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Mage]|r Middleware module loaded")
