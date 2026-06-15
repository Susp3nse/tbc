-- Hunter Middleware Module
-- Recovery items: Healthstone, Healing Potion, Dark/Demonic Rune

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Hunter Middleware]|r Core module not loaded!")
    return
end

A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- MIND CONTROL BREAK (Kael'thas) — top-priority override.
-- When Infinity Blade (30312) is equipped AND your current target is an ally
-- Mind-Controlled by Kael (debuff 36797), suggest ONLY Wing Clip on them to
-- break the MC via melee damage, suppressing the entire rest of the rotation.
-- Target-driven: you pick the MC'd ally (raid frame / target). Opt-in by
-- equipping the blade; zero effect otherwise. Wing Clip shows even out of
-- melee range so it reads as "stop and go break it", not "keep shooting".
-- ============================================================================
local MIND_CONTROL_ID   = 36797   -- Kael'thas "Mind Control" debuff on the victim
local INFINITY_BLADE_ID = 30312
local GetInventoryItemID = _G.GetInventoryItemID

local function infinity_blade_equipped()
    -- 16 = main-hand, 17 = off-hand
    return GetInventoryItemID(PLAYER_UNIT, 16) == INFINITY_BLADE_ID
        or GetInventoryItemID(PLAYER_UNIT, 17) == INFINITY_BLADE_ID
end

rotation_registry:register_middleware({
    name = "Hunter_MCBreak",
    priority = 600,  -- above FORM_RESHIFT (500): overrides the whole rotation
    matches = function(context)
        if not context.in_combat then return false end
        if not infinity_blade_equipped() then return false end
        -- Current target must be the MC'd ally (Kael's MC debuff, matched by ID)
        return (Unit(TARGET_UNIT):HasDeBuffs(MIND_CONTROL_ID, nil, true) or 0) > 0
    end,
    execute = function(icon, context)
        return A.WingClip:Show(icon), "[MW] Wing Clip — break Mind Control"
    end,
})

NS.register_recovery_middleware({
    prefix = "Hunter",
    healthstone = {
        hp_default = 40,
        actions = { A.HealthstoneMaster, A.HealthstoneMajor, A.HealthstoneFel },
    },
    healing_potion = {
        hp_default = 35,
        actions = { A.SuperHealingPotion, A.MajorHealingPotion },
    },
    mana = {
        rune = {
            name = "Hunter_ManaRune",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY,
            pct_default = 20,
            min_hp_default = 50,
            actions = { A.DarkRune, A.DemonicRune },
        },
    },
})

-- ============================================================================
-- FEIGN DEATH (Threat management)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Hunter_FeignDeath",
    priority = Priority.MIDDLEWARE.DISPEL_CURSE,
    is_defensive = true,
    setting_key = "use_feign_death",

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if not A.FeignDeath:IsReady(PLAYER_UNIT) then return false end
        -- Never feign on excluded NPCs (e.g. mobs that punish/ignore feign)
        local npcID = select(6, Unit("target"):InfoGUID())
        if NS.NO_FEIGN[npcID] then return false end
        -- Only feign when we have aggro
        local is_tanking = _G.UnitIsUnit("targettarget", PLAYER_UNIT)
        return is_tanking
    end,

    execute = function(icon, context)
        return A.FeignDeath:Show(icon), "[MW] Feign Death (threat)"
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Hunter]|r Middleware module loaded")
