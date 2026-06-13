-- Priest Middleware Module
-- Cross-playstyle concerns: emergency, recovery, dispels, mana, self-buffs

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local DetermineUsableObject = A.DetermineUsableObject
local is_spell_available = NS.is_spell_available
local GetNumGroupMembers = _G.GetNumGroupMembers

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local MultiUnits = A.MultiUnits
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit

-- Count enemies targeting the player by classification (nameplate scan)
local UnitClassification = _G.UnitClassification
local function count_mobs_targeting_me()
    local plates = MultiUnits:GetActiveUnitPlates()
    local bosses, elites, trash = 0, 0, 0
    for unitID in pairs(plates) do
        local tt = unitID .. "target"
        if UnitExists(tt) and UnitIsUnit(tt, PLAYER_UNIT) then
            local class = UnitClassification(unitID)
            if class == "worldboss" then
                bosses = bosses + 1
            elseif class == "elite" or class == "rareelite" then
                elites = elites + 1
            else
                trash = trash + 1
            end
        end
    end
    return bosses, elites, trash
end

-- ============================================================================
-- DESPERATE PRAYER (Emergency self-heal — highest priority)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_DesperatePrayer",
    priority = Priority.MIDDLEWARE.EMERGENCY_HEAL + 10,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_desperate_prayer then return false end
        local threshold = context.settings.desperate_prayer_hp or 30
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if is_spell_available(A.DesperatePrayer) and A.DesperatePrayer:IsReady(PLAYER_UNIT) then
            return A.DesperatePrayer:Show(icon), format("[MW] Desperate Prayer - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- FADE (Threat reduction)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_Fade",
    priority = Priority.MIDDLEWARE.EMERGENCY_HEAL - 10,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_fade then return false end
        -- Group-only: solo Fade is pointless (mob comes right back)
        if context.settings.fade_group_only and (GetNumGroupMembers() or 0) == 0 then return false end
        -- Nameplate scan: count mobs targeting us by classification
        local bosses, elites, trash = count_mobs_targeting_me()
        if bosses >= (context.settings.fade_min_bosses or 1) then return true end
        if elites >= (context.settings.fade_min_elites or 1) then return true end
        if trash >= (context.settings.fade_min_trash or 3) then return true end
        return false
    end,

    execute = function(icon, context)
        if A.Fade:IsReady(PLAYER_UNIT) then
            return A.Fade:Show(icon), "[MW] Fade - threat reduction"
        end
        return nil
    end,
})

-- ============================================================================
-- SILENCE (Interrupt — Shadow talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_Silence",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.shadow_use_silence then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if is_spell_available(A.Silence) and A.Silence:IsReady(TARGET_UNIT) then
                return A.Silence:Show(icon), format("[MW] Silence - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- DISPEL MAGIC (Party dispel)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_DispelMagic",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE - 5,

    matches = function(context)
        if not context.settings.auto_dispel_magic then return false end
        if context.is_mounted then return false end
        return true
    end,

    execute = function(icon, context)
        -- Check self first
        local hasMagic = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Magic")
        if hasMagic and A.DispelMagic:IsReady(PLAYER_UNIT) then
            return A.DispelMagic:Show(icon), "[MW] Dispel Magic (self)"
        end
        -- Check party members
        local members = GetNumGroupMembers() or 0
        if members > 0 then
            local prefix = members > 5 and "raid" or "party"
            local count = members > 5 and members or (members - 1)
            for i = 1, count do
                local unit = prefix .. i
                if _G.UnitExists(unit) and not Unit(unit):IsDead() then
                    local has = A.AuraIsValid(unit, "UseDispel", "Magic")
                    if has and A.DispelMagic:IsReady(unit) then
                        return A.DispelMagic:Show(icon), format("[MW] Dispel Magic (%s)", unit)
                    end
                end
            end
        end
        return nil
    end,
})

-- ============================================================================
-- ABOLISH DISEASE (Party cleanse)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_AbolishDisease",
    priority = Priority.MIDDLEWARE.DISPEL_POISON,

    matches = function(context)
        if not context.settings.auto_abolish_disease then return false end
        if context.is_mounted then return false end
        return true
    end,

    execute = function(icon, context)
        -- Check self first
        local hasDisease = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Disease")
        if hasDisease and A.AbolishDisease:IsReady(PLAYER_UNIT) then
            return A.AbolishDisease:Show(icon), "[MW] Abolish Disease (self)"
        end
        -- Check party members
        local members = GetNumGroupMembers() or 0
        if members > 0 then
            local prefix = members > 5 and "raid" or "party"
            local count = members > 5 and members or (members - 1)
            for i = 1, count do
                local unit = prefix .. i
                if _G.UnitExists(unit) and not Unit(unit):IsDead() then
                    local has = A.AuraIsValid(unit, "UseDispel", "Disease")
                    if has and A.AbolishDisease:IsReady(unit) then
                        return A.AbolishDisease:Show(icon), format("[MW] Abolish Disease (%s)", unit)
                    end
                end
            end
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_Healthstone",
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
    name = "Priest_HealingPotion",
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
-- SHADOWFIEND (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_Shadowfiend",
    priority = Priority.MIDDLEWARE.INNERVATE,

    matches = function(context)
        if not context.settings.use_shadowfiend then return false end
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        local threshold = context.settings.shadowfiend_pct or 50
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if is_spell_available(A.Shadowfiend) and A.Shadowfiend:IsReady(TARGET_UNIT) then
            return A.Shadowfiend:Show(icon), format("[MW] Shadowfiend - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- MANA POTION (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_ManaPotion",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY,

    matches = function(context)
        if not context.settings.use_mana_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_potion_pct or 50
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
    name = "Priest_DarkRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,

    matches = function(context)
        if not context.settings.use_dark_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.dark_rune_pct or 50
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
-- SELF-BUFF: INNER FIRE (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_SelfBuffInnerFire",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC + 10,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_inner_fire then return false end
        if context.has_inner_fire then return false end
        return true
    end,

    execute = function(icon, context)
        if A.InnerFire:IsReady(PLAYER_UNIT) then
            return A.InnerFire:Show(icon), "[MW] Inner Fire"
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: FORTITUDE (Out of combat)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_SelfBuffFortitude",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC + 5,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_fortitude then return false end
        if (Unit(PLAYER_UNIT):HasBuffs(Constants.FORTITUDE_IDS) or 0) > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        -- Try Prayer of Fortitude first if in a group
        local in_group = (GetNumGroupMembers() or 0) > 0
        if in_group and is_spell_available(A.PrayerOfFortitude) and A.PrayerOfFortitude:IsReady(PLAYER_UNIT) then
            return A.PrayerOfFortitude:Show(icon), "[MW] Prayer of Fortitude"
        end
        if A.PowerWordFortitude:IsReady(PLAYER_UNIT) then
            return A.PowerWordFortitude:Show(icon), "[MW] Power Word: Fortitude"
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: DIVINE SPIRIT (Out of combat, Disc talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_SelfBuffDivineSpirit",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_divine_spirit then return false end
        if (Unit(PLAYER_UNIT):HasBuffs(Constants.DIVINE_SPIRIT_IDS) or 0) > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        local in_group = (GetNumGroupMembers() or 0) > 0
        if in_group and is_spell_available(A.PrayerOfSpirit) and A.PrayerOfSpirit:IsReady(PLAYER_UNIT) then
            return A.PrayerOfSpirit:Show(icon), "[MW] Prayer of Spirit"
        end
        if is_spell_available(A.DivineSpirit) and A.DivineSpirit:IsReady(PLAYER_UNIT) then
            return A.DivineSpirit:Show(icon), "[MW] Divine Spirit"
        end
        return nil
    end,
})

-- ============================================================================
-- SELF-BUFF: SHADOW PROTECTION (Out of combat, optional)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_SelfBuffShadowProt",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC - 5,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_shadow_protection then return false end
        local has_sp = (Unit(PLAYER_UNIT):HasBuffs(Constants.SHADOW_PROT_IDS) or 0) > 0
        if has_sp then return false end
        return true
    end,

    execute = function(icon, context)
        local in_group = (GetNumGroupMembers() or 0) > 0
        if in_group and is_spell_available(A.PrayerOfShadowProtection) and A.PrayerOfShadowProtection:IsReady(PLAYER_UNIT) then
            return A.PrayerOfShadowProtection:Show(icon), "[MW] Prayer of Shadow Protection"
        end
        if A.ShadowProtection:IsReady(PLAYER_UNIT) then
            return A.ShadowProtection:Show(icon), "[MW] Shadow Protection"
        end
        return nil
    end,
})

-- ============================================================================
-- FEAR WARD (Buff on tank/self — OOC/between pulls)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Priest_FearWard",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC - 10,

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        if not context.settings.use_fear_ward then return false end
        return true
    end,

    execute = function(icon, context)
        if not is_spell_available(A.FearWard) or not A.FearWard:IsReady(PLAYER_UNIT) then
            return nil
        end
        -- Check self first
        local self_has = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.FEAR_WARD) or 0) > 0
        if not self_has then
            return A.FearWard:Show(icon), "[MW] Fear Ward (self)"
        end
        -- Check focus/tank target
        if _G.UnitExists("focus") and not Unit("focus"):IsDead() then
            local focus_has = (Unit("focus"):HasBuffs(Constants.BUFF_ID.FEAR_WARD) or 0) > 0
            if not focus_has and A.FearWard:IsReady("focus") then
                return A.FearWard:Show(icon), "[MW] Fear Ward (focus)"
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
print("|cFF00FF00[Flux AIO Priest]|r Middleware module loaded")
