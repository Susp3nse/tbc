-- Paladin Class Module
-- Defines all Paladin spells, constants, helper functions, and registers Paladin as a class

local _G, setmetatable, pairs, ipairs, tostring, select, type = _G, setmetatable, pairs, ipairs, tostring, select, type
local GetTime = _G.GetTime
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PALADIN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Paladin]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    ArcaneTorrent   = Create({ Type = "Spell", ID = 28730, Click = { unit = "player", type = "spell", spell = 28730 } }),
    Stoneform       = Create({ Type = "Spell", ID = 20594, Click = { unit = "player", type = "spell", spell = 20594 } }),
    GiftOfTheNaaru  = Create({ Type = "Spell", ID = 28880, Click = { unit = "player", type = "spell", spell = 28880 } }),
    Perception      = Create({ Type = "Spell", ID = 20600, Click = { unit = "player", type = "spell", spell = 20600 } }),

    -- Seals
    SealOfRighteousness = Create({ Type = "Spell", ID = 20154, useMaxRank = true }),
    SealOfCommandR1     = Create({ Type = "Spell", ID = 20375 }),                      -- R1 for twist (65 mana)
    SealOfCommandMax    = Create({ Type = "Spell", ID = 20375, useMaxRank = true }),    -- Max rank
    SealOfBlood         = Create({ Type = "Spell", ID = 31892 }),                       -- Horde only
    SealOfTheMartyr     = Create({ Type = "Spell", ID = 348700 }),                      -- Alliance SoB equiv (verify in-game)
    SealOfVengeance     = Create({ Type = "Spell", ID = 31801 }),                       -- Alliance stacking DoT
    SealOfWisdom        = Create({ Type = "Spell", ID = 20166, useMaxRank = true }),
    SealOfLight         = Create({ Type = "Spell", ID = 20165, useMaxRank = true }),
    SealOfCrusader      = Create({ Type = "Spell", ID = 21082, useMaxRank = true }),

    -- Judgement (single spell, OFF-GCD in TBC)
    Judgement = Create({ Type = "Spell", ID = 20271 }),

    -- Core Abilities
    CrusaderStrike  = Create({ Type = "Spell", ID = 35395 }),                           -- 41-pt Ret talent, 6s CD
    Consecration    = Create({ Type = "Spell", ID = 26573, useMaxRank = true }),
    Exorcism        = Create({ Type = "Spell", ID = 879, useMaxRank = true }),           -- Undead/Demon only
    HammerOfWrath   = Create({ Type = "Spell", ID = 24275, useMaxRank = true }),         -- Execute <20%
    HolyWrath       = Create({ Type = "Spell", ID = 2812, useMaxRank = true }),          -- Undead/Demon AoE

    -- Prot Abilities
    AvengersShield  = Create({ Type = "Spell", ID = 31935, useMaxRank = true }),         -- 41-pt Prot talent
    HolyShield      = Create({ Type = "Spell", ID = 20925, useMaxRank = true }),         -- Prot talent

    -- Healing (no explicit Click — framework sets autounit="help" automatically,
    -- enabling [@mouseover,help][@focus,help][@target,help][@player] targeting via meta3 macro)
    FlashOfLight    = Create({ Type = "Spell", ID = 19750, useMaxRank = true }),
    HolyLight       = Create({ Type = "Spell", ID = 635, useMaxRank = true }),
    HolyShock       = Create({ Type = "Spell", ID = 20473, useMaxRank = true }),         -- 31-pt Holy talent
    LayOnHands      = Create({ Type = "Spell", ID = 633, useMaxRank = true }),

    -- Defensive
    DivineShield     = Create({ Type = "Spell", ID = 642, Click = { unit = "player", type = "spell", spell = 642 } }),
    DivineProtection = Create({ Type = "Spell", ID = 5573, Click = { unit = "player", type = "spell", spell = 5573 } }),
    BlessingOfProtection = Create({ Type = "Spell", ID = 1022, useMaxRank = true }),
    HammerOfJustice  = Create({ Type = "Spell", ID = 853, useMaxRank = true }),          -- 6s stun

    -- Utility
    Cleanse          = Create({ Type = "Spell", ID = 4987, Click = { unit = "player", type = "spell", spell = 4987 } }),
    RighteousDefense = Create({ Type = "Spell", ID = 31789 }),                           -- Taunt (targets friendly)
    RighteousFury    = Create({ Type = "Spell", ID = 25780, Click = { unit = "player", type = "spell", spell = 25780 } }),

    -- Cooldowns
    AvengingWrath    = Create({ Type = "Spell", ID = 31884, Click = { unit = "player", type = "spell", spell = 31884 } }),
    DivineFavor      = Create({ Type = "Spell", ID = 20216, Click = { unit = "player", type = "spell", spell = 20216 } }),
    DivineIllumination = Create({ Type = "Spell", ID = 31842, Click = { unit = "player", type = "spell", spell = 31842 } }),

    -- Auras (persistent, self-cast)
    DevotionAura     = Create({ Type = "Spell", ID = 465, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    RetributionAura  = Create({ Type = "Spell", ID = 7294, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    ConcentrationAura = Create({ Type = "Spell", ID = 19746, Click = { unit = "player", type = "spell", spell = 19746 } }),
    SanctityAura     = Create({ Type = "Spell", ID = 20218, Click = { unit = "player", type = "spell", spell = 20218 } }),
    ShadowResistAura = Create({ Type = "Spell", ID = 19876, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    FrostResistAura  = Create({ Type = "Spell", ID = 19888, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    FireResistAura   = Create({ Type = "Spell", ID = 19891, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Blessings (self-cast)
    BlessingOfMight  = Create({ Type = "Spell", ID = 19740, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    BlessingOfWisdom = Create({ Type = "Spell", ID = 19742, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    BlessingOfKings  = Create({ Type = "Spell", ID = 20217, Click = { unit = "player", type = "spell", spell = 20217 } }),

    -- Items
    SuperManaPotion    = Create({ Type = "Item", ID = 22832 }),
    SuperHealingPotion = Create({ Type = "Item", ID = 22829 }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446 }),
    DarkRune           = Create({ Type = "Item", ID = 20520 }),
    DemonicRune        = Create({ Type = "Item", ID = 12662 }),

    -- Healthstones
    HealthstoneMaster = Create({ Type = "Item", ID = 22105 }),
    HealthstoneMajor  = Create({ Type = "Item", ID = 22104 }),

    -- Buff tracking
    Heroism   = Create({ Type = "Spell", ID = 32182 }),
    Bloodlust = Create({ Type = "Spell", ID = 2825 }),
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
local TARGET_UNIT = NS.TARGET_UNIT

-- Framework helpers
local MultiUnits = A.MultiUnits
local UnitFactionGroup = _G.UnitFactionGroup

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    BUFF_ID = {
        -- Seals (buff IDs for max rank or single rank)
        SEAL_RIGHTEOUSNESS  = 27155,
        SEAL_COMMAND_R1     = 20375,
        SEAL_COMMAND_MAX    = 27170,
        SEAL_BLOOD          = 31892,
        SEAL_MARTYR         = 348700,   -- verify in-game
        SEAL_VENGEANCE      = 31801,
        SEAL_WISDOM         = 27166,
        SEAL_LIGHT          = 27160,
        SEAL_CRUSADER       = 27158,
        -- Cooldowns & buffs
        AVENGING_WRATH      = 31884,
        DIVINE_SHIELD       = 642,
        DIVINE_PROTECTION   = 5573,
        DIVINE_FAVOR        = 20216,
        DIVINE_ILLUMINATION = 31842,
        HOLY_SHIELD         = 27179,
        RIGHTEOUS_FURY      = 25780,
        LIGHTS_GRACE        = 31834,
        VENGEANCE_TALENT    = 20059,    -- +5% dmg per stack, max 3
        -- Blessings (max rank buff IDs for tracking)
        BLESSING_MIGHT      = 27140,
        BLESSING_WISDOM     = 27142,
        BLESSING_KINGS      = 20217,
    },

    DEBUFF_ID = {
        FORBEARANCE         = 25771,    -- 1 min, blocks DS/DP/BoP/LoH/AW
        JUDGEMENT_CRUSADER   = 27159,    -- +3% crit on target
        JUDGEMENT_WISDOM     = 27164,    -- attacks restore mana
        JUDGEMENT_LIGHT      = 27163,    -- attacks restore HP
        SEAL_VENGEANCE_DOT   = 31803,   -- stacking DoT on target (0-5)
    },

    TWIST = {
        WINDOW    = 0.4,     -- 399ms from wowsims, rounded to 0.4
        LOW_MANA  = 1000,    -- mana threshold to disable twisting
    },

    MANA = {
        EXORCISM_PCT = 40,   -- only Exorcism when mana > 40%
        CONSEC_PCT   = 60,   -- only Consecration when mana > 60%
        PROT_CONSEC_PCT = 30, -- Prot is less aggressive on mana gating
    },

    -- Taunt thresholds (matching Druid Growl/Challenging Roar pattern)
    TAUNT = {
        CC_THRESHOLD       = 2,     -- Skip CC'd mobs with > 2s remaining
        MIN_TTD            = 4,     -- Skip dying mobs (unless targeting healer)
    },

    -- All aura buff IDs for checking if any aura is active
    AURA_BUFF_IDS = { 27149, 27150, 19746, 20218, 27151, 27152, 27153, 32223 },

    -- All blessing buff IDs for checking if any blessing is active on self
    BLESSING_BUFF_IDS = { 27140, 27142, 20217, 1038, 27168, 27141, 27143, 25898, 25895, 27169 },
}

NS.Constants = Constants

-- ============================================================================
-- FACTION-SPECIFIC SEAL RESOLUTION
-- ============================================================================
local player_faction = UnitFactionGroup("player")
local is_horde = (player_faction == "Horde")

-- Resolve the DPS seal: Seal of Blood (Horde) or Seal of the Martyr (Alliance)
local SealOfBloodAction = is_horde and A.SealOfBlood or A.SealOfTheMartyr
local SEAL_BLOOD_BUFF_ID = is_horde and Constants.BUFF_ID.SEAL_BLOOD or Constants.BUFF_ID.SEAL_MARTYR

-- Export for use in rotation modules
NS.is_horde = is_horde
NS.SealOfBloodAction = SealOfBloodAction
NS.SEAL_BLOOD_BUFF_ID = SEAL_BLOOD_BUFF_ID

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Paladin",
    version = "v1.7.8",
    playstyles = { "retribution", "protection", "holy" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "retribution"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        retribution = {
            { spell = SealOfBloodAction, name = is_horde and "Seal of Blood" or "Seal of the Martyr", required = true },
            { spell = A.SealOfCommandR1, name = "Seal of Command", required = true },
            { spell = A.Judgement, name = "Judgement", required = true },
            { spell = A.CrusaderStrike, name = "Crusader Strike", required = false, note = "41-pt Ret talent" },
            { spell = A.Exorcism, name = "Exorcism", required = false },
            { spell = A.Consecration, name = "Consecration", required = false },
            { spell = A.HammerOfWrath, name = "Hammer of Wrath", required = false },
        },
        protection = {
            { spell = A.SealOfRighteousness, name = "Seal of Righteousness", required = true },
            { spell = A.Judgement, name = "Judgement", required = true },
            { spell = A.Consecration, name = "Consecration", required = true },
            { spell = A.RighteousFury, name = "Righteous Fury", required = true },
            { spell = A.HolyShield, name = "Holy Shield", required = false, note = "Prot talent" },
            { spell = A.AvengersShield, name = "Avenger's Shield", required = false, note = "41-pt Prot talent" },
            { spell = A.RighteousDefense, name = "Righteous Defense", required = false },
            { spell = A.Exorcism, name = "Exorcism", required = false },
            { spell = A.HammerOfWrath, name = "Hammer of Wrath", required = false },
        },
        holy = {
            { spell = A.FlashOfLight, name = "Flash of Light", required = true },
            { spell = A.HolyLight, name = "Holy Light", required = true },
            { spell = A.Judgement, name = "Judgement", required = true },
            { spell = A.Cleanse, name = "Cleanse", required = false },
            { spell = A.HolyShock, name = "Holy Shock", required = false, note = "31-pt Holy talent" },
            { spell = A.DivineFavor, name = "Divine Favor", required = false, note = "Holy talent" },
            { spell = A.DivineIllumination, name = "Divine Illumination", required = false, note = "41-pt Holy talent" },
        },
    },

    extend_context = function(ctx)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit("player"):CombatTime() or 0

        -- Seal tracking
        ctx.seal_blood_active = (Unit("player"):HasBuffs(SEAL_BLOOD_BUFF_ID) or 0) > 0
        ctx.seal_command_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_COMMAND_R1) or 0) > 0
            or (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_COMMAND_MAX) or 0) > 0
        ctx.seal_righteousness_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_RIGHTEOUSNESS) or 0) > 0
        ctx.seal_vengeance_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_VENGEANCE) or 0) > 0
        ctx.seal_wisdom_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_WISDOM) or 0) > 0
        ctx.seal_light_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_LIGHT) or 0) > 0
        ctx.seal_crusader_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SEAL_CRUSADER) or 0) > 0
        ctx.has_any_seal = ctx.seal_blood_active or ctx.seal_command_active
            or ctx.seal_righteousness_active or ctx.seal_vengeance_active
            or ctx.seal_wisdom_active or ctx.seal_light_active
            or ctx.seal_crusader_active

        -- Key buffs/debuffs
        ctx.forbearance_active = (Unit("player"):HasDeBuffs(Constants.DEBUFF_ID.FORBEARANCE) or 0) > 0
        ctx.avenging_wrath_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.AVENGING_WRATH) or 0) > 0
        ctx.righteous_fury_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.RIGHTEOUS_FURY) or 0) > 0

        -- Enemy count for AoE decisions
        ctx.enemy_count = MultiUnits:GetByRangeInCombat(8)

        -- Swing timer data (for Ret seal twisting)
        local swing_start = Player:GetSwingStart(1) or 0
        local swing_duration = Player:GetSwing(1) or 0
        if swing_start > 0 and swing_duration > 0 then
            local remaining = (swing_start + swing_duration) - GetTime()
            ctx.time_to_swing = remaining > 0 and remaining or 0
        else
            ctx.time_to_swing = 0
        end
        ctx.in_twist_window = ctx.time_to_swing > 0 and ctx.time_to_swing <= Constants.TWIST.WINDOW

        -- Sync framework AutoTarget with our use_auto_tab setting:
        -- When our smart Auto Tab is enabled, disable the native one (we manage targeting).
        -- When ours is off, let the framework handle auto-targeting.
        local our_auto_tab = ctx.settings.use_auto_tab
        local native_auto_target = A.GetToggle(1, "AutoTarget")
        if our_auto_tab and native_auto_target then
            A.SetToggle({1, "AutoTarget"}, false)
        elseif not our_auto_tab and not native_auto_target then
            A.SetToggle({1, "AutoTarget"}, true)
        end

        -- Cache invalidation flags for per-playstyle context_builders
        ctx._ret_valid = false
        ctx._prot_valid = false
        ctx._holy_valid = false
    end,

    dashboard = {
        resource = { type = "mana", label = "Mana" },
        cooldowns = {
            retribution = { A.AvengingWrath, A.CrusaderStrike, A.Trinket1, A.Trinket2 },
            protection = { A.HolyShield, A.AvengingWrath, A.Trinket1, A.Trinket2 },
            holy = { A.DivineFavor, A.DivineIllumination, A.HolyShock, A.Trinket1, A.Trinket2 },
        },
        buffs = {
            retribution = {
                { id = Constants.BUFF_ID.AVENGING_WRATH, label = "AW" },
                { id = Constants.BUFF_ID.VENGEANCE_TALENT, label = "Veng" },
            },
            protection = {
                { id = Constants.BUFF_ID.HOLY_SHIELD, label = "HS" },
                { id = Constants.BUFF_ID.RIGHTEOUS_FURY, label = "RF" },
                { id = Constants.BUFF_ID.AVENGING_WRATH, label = "AW" },
            },
            holy = {
                { id = Constants.BUFF_ID.DIVINE_FAVOR, label = "DF" },
                { id = Constants.BUFF_ID.DIVINE_ILLUMINATION, label = "DI" },
                { id = Constants.BUFF_ID.LIGHTS_GRACE, label = "LG" },
            },
        },
        debuffs = {
            retribution = {
                { id = Constants.DEBUFF_ID.JUDGEMENT_CRUSADER, label = "JoC", target = true, owned = false },
                { id = Constants.DEBUFF_ID.SEAL_VENGEANCE_DOT, label = "SoV", target = true },
            },
            protection = {
                { id = Constants.DEBUFF_ID.SEAL_VENGEANCE_DOT, label = "SoV", target = true },
                { id = Constants.DEBUFF_ID.JUDGEMENT_WISDOM, label = "JoW", target = true, owned = false },
            },
            holy = {
                { id = Constants.DEBUFF_ID.FORBEARANCE, label = "Forb" },
            },
        },
        swing_label = "Shoot",
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Paladin]|r Class module loaded")
