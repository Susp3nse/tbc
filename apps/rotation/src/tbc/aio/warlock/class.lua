-- Warlock Class Module
-- Defines all Warlock spells, constants, helper functions, and registers Warlock as a class

local _G, setmetatable, pairs, ipairs, tostring, select, type = _G, setmetatable, pairs, ipairs, tostring, select, type
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARLOCK" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Warlock]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    BloodFury          = Create({ Type = "Spell", ID = 33702, Click = { unit = "player", type = "spell", spell = 33702 } }),
    ArcaneTorrent      = Create({ Type = "Spell", ID = 28730, Click = { unit = "player", type = "spell", spell = 28730 } }),
    WilloftheForsaken  = Create({ Type = "Spell", ID = 7744, Click = { unit = "player", type = "spell", spell = 7744 } }),
    EscapeArtist       = Create({ Type = "Spell", ID = 20589, Click = { unit = "player", type = "spell", spell = 20589 } }),

    -- Core Damage
    ShadowBolt     = Create({ Type = "Spell", ID = 686, useMaxRank = true }),
    Incinerate     = Create({ Type = "Spell", ID = 29722, useMaxRank = true }),   -- TBC spell, auto max rank
    SearingPain    = Create({ Type = "Spell", ID = 5676, useMaxRank = true }),
    SoulFire       = Create({ Type = "Spell", ID = 6353, useMaxRank = true }),
    Shadowburn     = Create({ Type = "Spell", ID = 17877, useMaxRank = true }),
    Conflagrate    = Create({ Type = "Spell", ID = 17962, useMaxRank = true }),
    DeathCoil      = Create({ Type = "Spell", ID = 6789, useMaxRank = true }),

    -- DoTs
    Corruption          = Create({ Type = "Spell", ID = 172, useMaxRank = true }),
    Immolate            = Create({ Type = "Spell", ID = 348, useMaxRank = true }),
    CurseOfAgony        = Create({ Type = "Spell", ID = 980, useMaxRank = true }),
    CurseOfDoom         = Create({ Type = "Spell", ID = 603, useMaxRank = true }),
    CurseOfElements     = Create({ Type = "Spell", ID = 1490, useMaxRank = true }),
    CurseOfRecklessness = Create({ Type = "Spell", ID = 704, useMaxRank = true }),
    CurseOfTongues      = Create({ Type = "Spell", ID = 1714, useMaxRank = true }),
    UnstableAffliction  = Create({ Type = "Spell", ID = 30108, useMaxRank = true }),  -- 41pt Affliction talent
    SiphonLife          = Create({ Type = "Spell", ID = 18265, useMaxRank = true }),
    SeedOfCorruption    = Create({ Type = "Spell", ID = 27243 }),

    -- Channels
    DrainLife  = Create({ Type = "Spell", ID = 689, useMaxRank = true }),
    DrainSoul  = Create({ Type = "Spell", ID = 1120, useMaxRank = true }),
    DrainMana  = Create({ Type = "Spell", ID = 5138, useMaxRank = true }),
    HealthFunnel = Create({ Type = "Spell", ID = 755, useMaxRank = true }),

    -- AoE
    RainOfFire  = Create({ Type = "Spell", ID = 5740, useMaxRank = true }),
    Hellfire    = Create({ Type = "Spell", ID = 1949, useMaxRank = true }),
    Shadowfury  = Create({ Type = "Spell", ID = 30283, useMaxRank = true }),  -- 41pt Destro talent

    -- Mana Management
    LifeTap   = Create({ Type = "Spell", ID = 1454, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    DarkPact  = Create({ Type = "Spell", ID = 18220, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Defensive / Utility
    Fear            = Create({ Type = "Spell", ID = 5782, useMaxRank = true }),
    HowlOfTerror    = Create({ Type = "Spell", ID = 5484, useMaxRank = true }),
    Banish          = Create({ Type = "Spell", ID = 710, useMaxRank = true }),
    ShadowWard      = Create({ Type = "Spell", ID = 6229, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    Soulshatter     = Create({ Type = "Spell", ID = 29858, Click = { unit = "player", type = "spell", spell = 29858 } }),
    AmplifyCurse    = Create({ Type = "Spell", ID = 18288, Click = { unit = "player", type = "spell", spell = 18288 } }),

    -- Demonology
    DemonicSacrifice = Create({ Type = "Spell", ID = 18788, Click = { unit = "player", type = "spell", spell = 18788 } }),
    SoulLink         = Create({ Type = "Spell", ID = 19028, Click = { unit = "player", type = "spell", spell = 19028 } }),
    FelDomination    = Create({ Type = "Spell", ID = 18708, Click = { unit = "player", type = "spell", spell = 18708 } }),

    -- Pet Summons
    SummonImp       = Create({ Type = "Spell", ID = 688, Click = { unit = "player", type = "spell", spell = 688 } }),
    SummonVoidwalker = Create({ Type = "Spell", ID = 697, Click = { unit = "player", type = "spell", spell = 697 } }),
    SummonSuccubus  = Create({ Type = "Spell", ID = 712, Click = { unit = "player", type = "spell", spell = 712 } }),
    SummonFelhunter = Create({ Type = "Spell", ID = 691, Click = { unit = "player", type = "spell", spell = 691 } }),
    SummonFelguard  = Create({ Type = "Spell", ID = 30146, Click = { unit = "player", type = "spell", spell = 30146 } }),

    -- Self-Buffs
    FelArmor    = Create({ Type = "Spell", ID = 28189, Click = { unit = "player", type = "spell", spell = 28189 } }),
    FelArmorR1  = Create({ Type = "Spell", ID = 28176, Click = { unit = "player", type = "spell", spell = 28176 } }),
    DemonArmor  = Create({ Type = "Spell", ID = 706, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Items
    SuperManaPotion    = Create({ Type = "Item", ID = 22832, Click = { unit = "player", type = "item", item = 22832 } }),
    SuperHealingPotion = Create({ Type = "Item", ID = 22829, Click = { unit = "player", type = "item", item = 22829 } }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446, Click = { unit = "player", type = "item", item = 13446 } }),
    DarkRune           = Create({ Type = "Item", ID = 20520, Click = { unit = "player", type = "item", item = 20520 } }),
    DemonicRune        = Create({ Type = "Item", ID = 12662, Click = { unit = "player", type = "item", item = 12662 } }),

    -- Healthstones
    HealthstoneMaster = Create({ Type = "Item", ID = 22105, Click = { unit = "player", type = "item", item = 22105 } }),
    HealthstoneMajor  = Create({ Type = "Item", ID = 22104, Click = { unit = "player", type = "item", item = 22104 } }),
    HealthstoneFel    = Create({ Type = "Item", ID = 22103, Click = { unit = "player", type = "item", item = 22103 } }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local TARGET_UNIT = NS.TARGET_UNIT

-- Framework helpers
local MultiUnits = A.MultiUnits

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    BUFF_ID = {
        SHADOW_TRANCE    = 17941,  -- Nightfall proc: instant Shadow Bolt
        BACKLASH         = 34936,  -- Instant SB/Incinerate proc from physical hits
        FEL_ARMOR_R2     = 28189,  -- +100 spell damage
        FEL_ARMOR_R1     = 28176,  -- +50 spell damage
        DEMON_ARMOR      = 27260,  -- Max rank Demon Armor
        SOUL_LINK        = 19028,  -- 20% dmg transferred to pet
        -- Demonic Sacrifice buffs
        DS_BURNING_WISH  = 18789,  -- Imp sacrifice: +15% fire damage
        DS_TOUCH_SHADOW  = 18791,  -- Succubus sacrifice: +15% shadow damage
        DS_FEL_STAMINA   = 18790,  -- Voidwalker sacrifice: HP regen
        DS_FEL_ENERGY    = 18792,  -- Felhunter sacrifice: mana regen
    },

    DEBUFF_ID = {
        ISB              = 17800,  -- Shadow Vulnerability (Improved Shadow Bolt): +20% shadow dmg
        CORRUPTION       = 27216,  -- Max rank Corruption
        IMMOLATE         = 27215,  -- Max rank Immolate
        UNSTABLE_AFF     = 30405,  -- Max rank Unstable Affliction
        SIPHON_LIFE      = 30911,  -- Max rank Siphon Life
        COA              = 27218,  -- Max rank Curse of Agony
        COD              = 30910,  -- Max rank Curse of Doom
        COE              = 27228,  -- Max rank Curse of Elements
        COR              = 27226,  -- Max rank Curse of Recklessness
        COT              = 11719,  -- Max rank Curse of Tongues
        SEED             = 27243,  -- Seed of Corruption
    },

    -- All Fel/Demon Armor buff IDs for checking if any armor is active
    ARMOR_BUFF_IDS = { 28189, 28176, 27260, 706, 687, 696, 1086, 11733, 11734, 11735 },

    -- All Demonic Sacrifice buff IDs
    DS_BUFF_IDS = { 18789, 18791, 18790, 18792 },
}

NS.Constants = Constants

-- ============================================================================
-- CURSE HELPERS (shared by all specs)
-- ============================================================================
local CURSE_DEBUFF_IDS = {
    elements = Constants.DEBUFF_ID.COE,
    agony = Constants.DEBUFF_ID.COA,
    doom = Constants.DEBUFF_ID.COD,
    recklessness = Constants.DEBUFF_ID.COR,
    tongues = Constants.DEBUFF_ID.COT,
}

local function get_curse_duration(context)
    local curse_type = context.settings.curse_type
    if curse_type == "none" then return 999 end
    local debuff_id = CURSE_DEBUFF_IDS[curse_type]
    if not debuff_id then return 999 end
    return Unit(TARGET_UNIT):HasDeBuffs(debuff_id) or 0
end

local CURSE_SPELLS = {
    elements = A.CurseOfElements,
    agony = A.CurseOfAgony,
    doom = A.CurseOfDoom,
    recklessness = A.CurseOfRecklessness,
    tongues = A.CurseOfTongues,
}

local function get_curse_spell(context)
    local curse_type = context.settings.curse_type
    -- CoD does zero damage if target dies before 60s tick — fall back to CoA
    if curse_type == "doom" and context.ttd > 0 and context.ttd < 60 then
        return CURSE_SPELLS["agony"]
    end
    return CURSE_SPELLS[curse_type]
end

NS.CURSE_DEBUFF_IDS = CURSE_DEBUFF_IDS
NS.get_curse_duration = get_curse_duration
NS.get_curse_spell = get_curse_spell

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Warlock",
    version = "v1.7.0",
    playstyles = { "affliction", "demonology", "destruction" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "affliction"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        affliction = {
            { spell = A.ShadowBolt, name = "Shadow Bolt", required = true },
            { spell = A.Corruption, name = "Corruption", required = true },
            { spell = A.LifeTap, name = "Life Tap", required = true },
            { spell = A.UnstableAffliction, name = "Unstable Affliction", required = false, note = "41pt Affliction talent" },
            { spell = A.SiphonLife, name = "Siphon Life", required = false, note = "Affliction talent" },
            { spell = A.DarkPact, name = "Dark Pact", required = false, note = "Affliction talent" },
            { spell = A.AmplifyCurse, name = "Amplify Curse", required = false, note = "Affliction talent" },
            { spell = A.DrainSoul, name = "Drain Soul", required = false },
            { spell = A.Immolate, name = "Immolate", required = false },
        },
        demonology = {
            { spell = A.ShadowBolt, name = "Shadow Bolt", required = true },
            { spell = A.LifeTap, name = "Life Tap", required = true },
            { spell = A.Corruption, name = "Corruption", required = false },
            { spell = A.Immolate, name = "Immolate", required = false },
            { spell = A.HealthFunnel, name = "Health Funnel", required = false },
            { spell = A.SummonFelguard, name = "Summon Felguard", required = false, note = "41pt Demo talent" },
            { spell = A.DemonicSacrifice, name = "Demonic Sacrifice", required = false, note = "Demo talent" },
            { spell = A.FelDomination, name = "Fel Domination", required = false, note = "Demo talent" },
            { spell = A.SoulLink, name = "Soul Link", required = false, note = "Demo talent" },
        },
        destruction = {
            { spell = A.ShadowBolt, name = "Shadow Bolt", required = true },
            { spell = A.LifeTap, name = "Life Tap", required = true },
            { spell = A.Immolate, name = "Immolate", required = false },
            { spell = A.Incinerate, name = "Incinerate", required = false, note = "TBC ability" },
            { spell = A.Conflagrate, name = "Conflagrate", required = false, note = "Destro talent" },
            { spell = A.Shadowburn, name = "Shadowburn", required = false, note = "Destro talent" },
            { spell = A.Shadowfury, name = "Shadowfury", required = false, note = "41pt Destro talent" },
        },
    },

    extend_context = function(ctx)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit("player"):CombatTime() or 0

        -- Pet state
        ctx.pet_exists = _G.UnitExists("pet") == 1 or _G.UnitExists("pet") == true
        ctx.pet_hp = ctx.pet_exists and (Unit("pet"):HealthPercent() or 0) or 0
        ctx.pet_active = ctx.pet_exists and not _G.UnitIsDeadOrGhost("pet")

        -- Proc buffs
        ctx.has_shadow_trance = (Unit("player"):HasBuffs(Constants.BUFF_ID.SHADOW_TRANCE) or 0) > 0
        ctx.has_backlash = (Unit("player"):HasBuffs(Constants.BUFF_ID.BACKLASH) or 0) > 0

        -- Demonic Sacrifice buffs
        ctx.has_ds_shadow = (Unit("player"):HasBuffs(Constants.BUFF_ID.DS_TOUCH_SHADOW) or 0) > 0
        ctx.has_ds_fire = (Unit("player"):HasBuffs(Constants.BUFF_ID.DS_BURNING_WISH) or 0) > 0
        ctx.has_ds_any = ctx.has_ds_shadow or ctx.has_ds_fire
            or (Unit("player"):HasBuffs(Constants.BUFF_ID.DS_FEL_STAMINA) or 0) > 0
            or (Unit("player"):HasBuffs(Constants.BUFF_ID.DS_FEL_ENERGY) or 0) > 0

        -- Armor buff
        ctx.has_fel_armor = (Unit("player"):HasBuffs(Constants.BUFF_ID.FEL_ARMOR_R2) or 0) > 0
            or (Unit("player"):HasBuffs(Constants.BUFF_ID.FEL_ARMOR_R1) or 0) > 0

        -- Soul Link buff
        ctx.has_soul_link = (Unit("player"):HasBuffs(Constants.BUFF_ID.SOUL_LINK) or 0) > 0

        -- Soul shards
        ctx.soul_shards = _G.GetItemCount(6265) or 0

        -- Enemy count
        ctx.enemy_count = MultiUnits:GetByRangeInCombat(30) or 0

        -- Cache invalidation flags (reset per frame)
        ctx._affliction_valid = false
        ctx._demo_valid = false
        ctx._destro_valid = false
    end,

    dashboard = {
        resource = { type = "mana", label = "Mana" },
        cooldowns = {
            affliction = { A.AmplifyCurse, A.Trinket1, A.Trinket2 },
            demonology = { A.FelDomination, A.Trinket1, A.Trinket2 },
            destruction = { A.Shadowburn, A.Conflagrate, A.Trinket1, A.Trinket2 },
        },
        buffs = {
            affliction = {
                { id = Constants.BUFF_ID.SHADOW_TRANCE, label = "NT" },
            },
            demonology = {
                { id = Constants.BUFF_ID.SOUL_LINK, label = "SL" },
            },
            destruction = {
                { id = Constants.BUFF_ID.BACKLASH, label = "BL" },
            },
        },
        debuffs = {
            affliction = {
                { id = Constants.DEBUFF_ID.CORRUPTION, label = "Corr", target = true },
                { id = Constants.DEBUFF_ID.UNSTABLE_AFF, label = "UA", target = true },
                { id = Constants.DEBUFF_ID.SIPHON_LIFE, label = "SL", target = true },
                { id = Constants.DEBUFF_ID.COA, label = "CoA", target = true },
            },
            demonology = {
                { id = Constants.DEBUFF_ID.CORRUPTION, label = "Corr", target = true },
                { id = Constants.DEBUFF_ID.IMMOLATE, label = "Immo", target = true },
                { id = Constants.DEBUFF_ID.ISB, label = "ISB", target = true, show_stacks = true, owned = false },
            },
            destruction = {
                { id = Constants.DEBUFF_ID.IMMOLATE, label = "Immo", target = true },
                { id = Constants.DEBUFF_ID.CORRUPTION, label = "Corr", target = true },
                { id = Constants.DEBUFF_ID.ISB, label = "ISB", target = true, show_stacks = true, owned = false },
            },
        },
        swing_label = "Wand",
        custom_lines = {
            function(context) return "Shards", tostring(context.soul_shards or 0) end,
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warlock]|r Class module loaded")
