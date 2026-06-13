-- Mage Class Module
-- Defines all Mage spells, constants, helper functions, and registers Mage as a class

local _G, setmetatable, pairs, ipairs, tostring, select, type = _G, setmetatable, pairs, ipairs, tostring, select, type
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "MAGE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Mage]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    ArcaneTorrent      = Create({ Type = "Spell", ID = 28730, Click = { unit = "player", type = "spell", spell = 28730 } }),
    Berserking         = Create({ Type = "Spell", ID = 26297, Click = { unit = "player", type = "spell", spell = 26297 } }),

    -- Core Damage
    Fireball       = Create({ Type = "Spell", ID = 133, useMaxRank = true }),
    Frostbolt      = Create({ Type = "Spell", ID = 116, useMaxRank = true }),
    ArcaneBlast    = Create({ Type = "Spell", ID = 30451 }),
    ArcaneMissiles = Create({ Type = "Spell", ID = 5143, useMaxRank = true }),
    Scorch         = Create({ Type = "Spell", ID = 2948, useMaxRank = true }),
    FireBlast      = Create({ Type = "Spell", ID = 2136, useMaxRank = true }),
    IceLance       = Create({ Type = "Spell", ID = 30455 }),

    -- AoE
    ArcaneExplosion = Create({ Type = "Spell", ID = 1449, useMaxRank = true }),
    Flamestrike     = Create({ Type = "Spell", ID = 2120, useMaxRank = true }),
    Blizzard        = Create({ Type = "Spell", ID = 10, useMaxRank = true }),
    ConeOfCold      = Create({ Type = "Spell", ID = 120, useMaxRank = true }),
    BlastWave       = Create({ Type = "Spell", ID = 11113, useMaxRank = true }),
    DragonsBreath   = Create({ Type = "Spell", ID = 31661, useMaxRank = true }),

    -- Defensive
    IceBarrier = Create({ Type = "Spell", ID = 11426, useMaxRank = true }),
    ManaShield = Create({ Type = "Spell", ID = 1463, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    IceBlock   = Create({ Type = "Spell", ID = 45438, Click = { unit = "player", type = "spell", spell = 45438 } }),
    Blink      = Create({ Type = "Spell", ID = 1953, Click = { unit = "player", type = "spell", spell = 1953 } }),

    -- Cooldowns
    Combustion           = Create({ Type = "Spell", ID = 11129, Click = { unit = "player", type = "spell", spell = 11129 } }),
    IcyVeins             = Create({ Type = "Spell", ID = 12472, Click = { unit = "player", type = "spell", spell = 12472 } }),
    ArcanePower          = Create({ Type = "Spell", ID = 12042, Click = { unit = "player", type = "spell", spell = 12042 } }),
    PresenceOfMind       = Create({ Type = "Spell", ID = 12043, Click = { unit = "player", type = "spell", spell = 12043 } }),
    ColdSnap             = Create({ Type = "Spell", ID = 11958, Click = { unit = "player", type = "spell", spell = 11958 } }),
    SummonWaterElemental = Create({ Type = "Spell", ID = 31687, Click = { unit = "player", type = "spell", spell = 31687 } }),

    -- Utility
    Counterspell = Create({ Type = "Spell", ID = 2139 }),
    RemoveCurse  = Create({ Type = "Spell", ID = 475, Click = { unit = "player", type = "spell", spell = 475 } }),
    Evocation    = Create({ Type = "Spell", ID = 12051, Click = { unit = "player", type = "spell", spell = 12051 } }),

    -- Self-Buffs
    MoltenArmor          = Create({ Type = "Spell", ID = 30482, Click = { unit = "player", type = "spell", spell = 30482 } }),
    MageArmor            = Create({ Type = "Spell", ID = 6117, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    IceArmor             = Create({ Type = "Spell", ID = 7302, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    SelfArcaneIntellect  = Create({ Type = "Spell", ID = 1459, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    SelfArcaneBrilliance = Create({ Type = "Spell", ID = 23028, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Items
    SuperManaPotion    = Create({ Type = "Item", ID = 22832, Click = { unit = "player", type = "item", item = 22832 } }),
    SuperHealingPotion = Create({ Type = "Item", ID = 22829, Click = { unit = "player", type = "item", item = 22829 } }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446, Click = { unit = "player", type = "item", item = 13446 } }),
    DarkRune           = Create({ Type = "Item", ID = 20520, Click = { unit = "player", type = "item", item = 20520 } }),
    DemonicRune        = Create({ Type = "Item", ID = 12662, Click = { unit = "player", type = "item", item = 12662 } }),
    ManaEmerald        = Create({ Type = "Item", ID = 22044, Click = { unit = "player", type = "item", item = 22044 } }),
    ManaRuby           = Create({ Type = "Item", ID = 8008,  Click = { unit = "player", type = "item", item = 8008 } }),
    ManaCitrine        = Create({ Type = "Item", ID = 8007,  Click = { unit = "player", type = "item", item = 8007 } }),

    -- Healthstones
    HealthstoneMaster = Create({ Type = "Item", ID = 22105, Click = { unit = "player", type = "item", item = 22105 } }),
    HealthstoneMajor  = Create({ Type = "Item", ID = 22104, Click = { unit = "player", type = "item", item = 22104 } }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local PLAYER_UNIT = NS.PLAYER_UNIT

-- Framework helpers
local MultiUnits = A.MultiUnits

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    BUFF_ID = {
        CLEARCASTING     = 12536,
        COMBUSTION       = 11129,
        ARCANE_POWER     = 12042,
        ICY_VEINS        = 12472,
        PRESENCE_OF_MIND = 12043,
        ICE_BARRIER      = 33405,
        MOLTEN_ARMOR     = 30482,
        MAGE_ARMOR       = 22783,
        MAGE_ARMOR_MAX   = 27125, -- max rank Mage Armor buff ID
        ICE_ARMOR        = 27124, -- max rank Ice Armor buff ID
        ARCANE_INTELLECT = 27126, -- max rank Arcane Intellect buff ID
        ARCANE_BRILLIANCE = 27127, -- max rank Arcane Brilliance buff ID
    },

    DEBUFF_ID = {
        IMPROVED_SCORCH = 22959,   -- Fire Vulnerability, stacks to 5
        ARCANE_BLAST    = 36032,   -- Self-debuff, stacks to 3
        HYPOTHERMIA     = 41425,   -- 30s lockout after Ice Block
    },

    SCORCH = {
        MAX_STACKS      = 5,
        DEFAULT_REFRESH = 6,
    },

    ARCANE = {
        MAX_AB_STACKS              = 3,
        DEFAULT_START_CONSERVE     = 35,
        DEFAULT_STOP_CONSERVE      = 60,
        DEFAULT_BLASTS_BEFORE_FILLER = 3,
    },

    -- All armor buff IDs for checking if any armor is active
    ARMOR_BUFF_IDS = { 30482, 22783, 27125, 27124, 7302, 6117, 168, 7300, 7301 },

    -- All intellect buff IDs for checking if intellect buff is active
    INTELLECT_BUFF_IDS = { 27126, 27127, 23028, 1459, 1460, 1461, 10156, 10157 },

    -- Bloodlust / Heroism buff IDs (Horde / Alliance)
    BLOODLUST_IDS = { 2825, 32182 },
}

NS.Constants = Constants

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Mage",
    version = "v1.7.0",
    playstyles = { "fire", "frost", "arcane" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "fire"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        fire = {
            { spell = A.Fireball, name = "Fireball", required = true },
            { spell = A.Scorch, name = "Scorch", required = true },
            { spell = A.FireBlast, name = "Fire Blast", required = false },
            { spell = A.Combustion, name = "Combustion", required = false, note = "Fire talent" },
            { spell = A.IcyVeins, name = "Icy Veins", required = false, note = "Frost talent" },
            { spell = A.BlastWave, name = "Blast Wave", required = false, note = "Fire talent" },
            { spell = A.DragonsBreath, name = "Dragon's Breath", required = false, note = "Fire talent" },
        },
        frost = {
            { spell = A.Frostbolt, name = "Frostbolt", required = true },
            { spell = A.FireBlast, name = "Fire Blast", required = false },
            { spell = A.IceLance, name = "Ice Lance", required = false },
            { spell = A.ConeOfCold, name = "Cone of Cold", required = false },
            { spell = A.IcyVeins, name = "Icy Veins", required = false, note = "Frost talent" },
            { spell = A.ColdSnap, name = "Cold Snap", required = false, note = "Frost talent" },
            { spell = A.SummonWaterElemental, name = "Water Elemental", required = false, note = "41pt Frost talent" },
        },
        arcane = {
            { spell = A.ArcaneBlast, name = "Arcane Blast", required = true },
            { spell = A.Frostbolt, name = "Frostbolt", required = false, note = "Filler" },
            { spell = A.ArcaneMissiles, name = "Arcane Missiles", required = false, note = "Filler" },
            { spell = A.Scorch, name = "Scorch", required = false, note = "Filler" },
            { spell = A.ArcanePower, name = "Arcane Power", required = false, note = "Arcane talent" },
            { spell = A.PresenceOfMind, name = "Presence of Mind", required = false, note = "Arcane talent" },
            { spell = A.IcyVeins, name = "Icy Veins", required = false, note = "Frost talent" },
            { spell = A.ColdSnap, name = "Cold Snap", required = false, note = "Frost talent" },
        },
    },

    extend_context = function(ctx)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit("player"):CombatTime() or 0
        ctx.ab_stacks = Unit("player"):HasDeBuffsStacks(Constants.DEBUFF_ID.ARCANE_BLAST, nil, true) or 0
        ctx.ab_duration = Unit("player"):HasDeBuffs(Constants.DEBUFF_ID.ARCANE_BLAST, nil, true) or 0
        ctx.hypothermia = (Unit("player"):HasDeBuffs(Constants.DEBUFF_ID.HYPOTHERMIA) or 0) > 0
        ctx.enemy_count_melee = MultiUnits:GetByRangeInCombat(10)
        ctx.enemy_count_ranged = MultiUnits:GetByRangeInCombat(40)
        -- CD buff states
        ctx.has_clearcasting = (Unit("player"):HasBuffs(Constants.BUFF_ID.CLEARCASTING) or 0) > 0
        ctx.icy_veins_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.ICY_VEINS, true) or 0) > 0
        ctx.arcane_power_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.ARCANE_POWER, true) or 0) > 0
        ctx.combustion_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.COMBUSTION, true) or 0) > 0
        ctx.pom_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.PRESENCE_OF_MIND, true) or 0) > 0
        -- Cache invalidation flags for per-playstyle context_builders
        ctx._fire_valid = false
        ctx._frost_valid = false
        ctx._arcane_valid = false
    end,

    gap_handler = function(icon, context)
        if A.Blink:IsReady(PLAYER_UNIT) then
            return A.Blink:Show(icon), "[GAP] Blink"
        end
        return nil
    end,

    dashboard = {
        resource = { type = "mana", label = "Mana" },
        cooldowns = {
            fire   = { A.Combustion },
            frost  = { A.IcyVeins, A.ColdSnap, A.SummonWaterElemental },
            arcane = { A.ArcanePower, A.PresenceOfMind, A.IcyVeins },
        },
        buffs = {
            fire = {
                { id = Constants.BUFF_ID.COMBUSTION, label = "Comb" },
                { id = Constants.BUFF_ID.CLEARCASTING, label = "CC" },
                { id = Constants.ARMOR_BUFF_IDS, label = "Armor" },
                { id = Constants.INTELLECT_BUFF_IDS, label = "Int" },
            },
            frost = {
                { id = Constants.BUFF_ID.ICY_VEINS, label = "IV" },
                { id = Constants.BUFF_ID.CLEARCASTING, label = "CC" },
                { id = Constants.ARMOR_BUFF_IDS, label = "Armor" },
                { id = Constants.INTELLECT_BUFF_IDS, label = "Int" },
            },
            arcane = {
                { id = Constants.BUFF_ID.ARCANE_POWER, label = "AP" },
                { id = Constants.BUFF_ID.PRESENCE_OF_MIND, label = "PoM" },
                { id = Constants.BUFF_ID.CLEARCASTING, label = "CC" },
                { id = Constants.ARMOR_BUFF_IDS, label = "Armor" },
                { id = Constants.INTELLECT_BUFF_IDS, label = "Int" },
            },
        },
        swing_label = "Wand",
        debuffs = {
            fire = {
                { id = Constants.DEBUFF_ID.IMPROVED_SCORCH, label = "Scorch", target = true, show_stacks = true, owned = false },
            },
            frost = {
                { id = 122, label = "FNova", target = true, owned = false },
                { id = 33395, label = "Freeze", target = true, owned = false },
            },
            arcane = {
                { id = Constants.DEBUFF_ID.ARCANE_BLAST, label = "AB", show_stacks = true },
            },
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Mage]|r Class module loaded")
