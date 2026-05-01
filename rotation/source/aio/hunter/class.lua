-- Hunter Class Module
-- Defines all Hunter spells, constants, helper functions, and registers Hunter as a class

local _G, setmetatable, type = _G, setmetatable, type
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create
local CONST = A.Const

Action[A.PlayerClass] = {
    -- Racial
    Shadowmeld        = Create({ Type = "Spell", ID = 20580, Click = { unit = "player", type = "spell", spell = 20580 } }),
    Perception         = Create({ Type = "Spell", ID = 20600, FixedTexture = CONST.HUMAN, Click = { unit = "player", type = "spell", spell = 20600 } }),
    BloodFury          = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    Berserking         = Create({ Type = "Spell", ID = 20554, Click = { unit = "player", type = "spell", spell = 20554 } }),
    Stoneform          = Create({ Type = "Spell", ID = 20594, Click = { unit = "player", type = "spell", spell = 20594 } }),
    WilloftheForsaken  = Create({ Type = "Spell", ID = 7744, Click = { unit = "player", type = "spell", spell = 7744 } }),
    EscapeArtist       = Create({ Type = "Spell", ID = 20589, Click = { unit = "player", type = "spell", spell = 20589 } }),
    ArcaneTorrent      = Create({ Type = "Spell", ID = 28730, Click = { unit = "player", type = "spell", spell = 28730 } }),

    -- General
    ShootBow      = Create({ Type = "Spell", ID = 2480, QueueForbidden = true, BlockForbidden = true, Click = { autounit = "harm", type = "spell", spell = 2480 } }),
    ShootCrossbow = Create({ Type = "Spell", ID = 7919, QueueForbidden = true, BlockForbidden = true, Click = { autounit = "harm", type = "spell", spell = 7919 } }),
    ShootGun      = Create({ Type = "Spell", ID = 7918, QueueForbidden = true, BlockForbidden = true, Click = { autounit = "harm", type = "spell", spell = 7918 } }),
    Throw         = Create({ Type = "Spell", ID = 2764, QueueForbidden = true, BlockForbidden = true, Click = { autounit = "harm", type = "spell", spell = 2764 } }),

    -- Beast Mastery
    AspectoftheBeast   = Create({ Type = "Spell", ID = 13161, Click = { unit = "player", type = "spell", spell = 13161 } }),
    AspectoftheCheetah = Create({ Type = "Spell", ID = 5118, Click = { unit = "player", type = "spell", spell = 5118 } }),
    AspectoftheHawk    = Create({ Type = "Spell", ID = 13165, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    AspectoftheMonkey  = Create({ Type = "Spell", ID = 13163, Click = { unit = "player", type = "spell", spell = 13163 } }),
    AspectofthePack    = Create({ Type = "Spell", ID = 13159, Click = { unit = "player", type = "spell", spell = 13159 } }),
    AspectoftheViper   = Create({ Type = "Spell", ID = 34074, Click = { unit = "player", type = "spell", spell = 34074 } }),
    AspectoftheWild    = Create({ Type = "Spell", ID = 20043, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    BeastLore          = Create({ Type = "Spell", ID = 1462, Click = { autounit = "harm", type = "spell", spell = 1462 } }),
    BestialWrath       = Create({ Type = "Spell", ID = 19574, Click = { unit = "player", type = "spell", spell = 19574 } }),
    CallPet            = Create({ Type = "Spell", ID = 883, Click = { unit = "player", type = "spell", spell = 883 } }),
    DismissPet         = Create({ Type = "Spell", ID = 2641, Click = { unit = "player", type = "spell", spell = 2641 } }),
    EagleEye           = Create({ Type = "Spell", ID = 6197, Click = { unit = "player", type = "spell", spell = 6197 } }),
    EyesoftheBeast     = Create({ Type = "Spell", ID = 1002, Click = { unit = "player", type = "spell", spell = 1002 } }),
    FeedPet            = Create({ Type = "Spell", ID = 6991, Click = { unit = "player", type = "spell", spell = 6991 } }),
    Intimidation       = Create({ Type = "Spell", ID = 19577, Click = { autounit = "harm", type = "spell", spell = 19577 } }),
    KillCommand        = Create({ Type = "Spell", ID = 34026, Click = { autounit = "harm", type = "spell", spell = 34026 } }),
    MendPet            = Create({ Type = "Spell", ID = 136, useMaxRank = true, Click = { unit = "pet", type = "spell" } }),
    RevivePet          = Create({ Type = "Spell", ID = 982, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    ScareBeast         = Create({ Type = "Spell", ID = 1513, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    TameBeast          = Create({ Type = "Spell", ID = 1515, Click = { autounit = "harm", type = "spell", spell = 1515 } }),

    -- Marksmanship
    AimedShot        = Create({ Type = "Spell", ID = 19434, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    ArcaneShot       = Create({ Type = "Spell", ID = 3044, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    ConcussiveShot   = Create({ Type = "Spell", ID = 5116, Click = { autounit = "harm", type = "spell", spell = 5116 } }),
    DistractingShot  = Create({ Type = "Spell", ID = 20736, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    Flare            = Create({ Type = "Spell", ID = 1543, Click = { unit = "player", type = "spell", spell = 1543 } }),
    HuntersMark      = Create({ Type = "Spell", ID = 1130, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    MultiShot        = Create({ Type = "Spell", ID = 2643, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    RapidFire        = Create({ Type = "Spell", ID = 3045, Click = { unit = "player", type = "spell", spell = 3045 } }),
    ScatterShot      = Create({ Type = "Spell", ID = 19503, Click = { autounit = "harm", type = "spell", spell = 19503 } }),
    ScorpidSting     = Create({ Type = "Spell", ID = 3043, Click = { autounit = "harm", type = "spell", spell = 3043 } }),
    SerpentSting     = Create({ Type = "Spell", ID = 1978, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    SilencingShot    = Create({ Type = "Spell", ID = 34490, Click = { autounit = "harm", type = "spell", spell = 34490 } }),
    SteadyShot       = Create({ Type = "Spell", ID = 34120, Click = { autounit = "harm", type = "spell", spell = 34120 } }),
    TrueshotAura     = Create({ Type = "Spell", ID = 19506, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    ViperSting       = Create({ Type = "Spell", ID = 3034, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    Volley           = Create({ Type = "Spell", ID = 1510, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    TranquilizingShot = Create({ Type = "Spell", ID = 19801, Click = { autounit = "harm", type = "spell", spell = 19801 } }),

    -- Survival
    Counterattack    = Create({ Type = "Spell", ID = 19306, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    Deterrence       = Create({ Type = "Spell", ID = 19263, Click = { unit = "player", type = "spell", spell = 19263 } }),
    Disengage        = Create({ Type = "Spell", ID = 781, useMaxRank = true, Click = { autounit = "harm", type = "spell", spell = 781 } }),
    ExplosiveTrap    = Create({ Type = "Spell", ID = 13813, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    FeignDeath       = Create({ Type = "Spell", ID = 5384, Click = { unit = "player", type = "spell", spell = 5384 } }),
    FreezingTrap     = Create({ Type = "Spell", ID = 1499, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    FreezingTrapDebuff = Create({ Type = "Spell", ID = 3355 }),
    FrostTrap        = Create({ Type = "Spell", ID = 13809, Click = { unit = "player", type = "spell", spell = 13809 } }),
    ImmolationTrap   = Create({ Type = "Spell", ID = 13795, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    Misdirection     = Create({ Type = "Spell", ID = 34477, Click = { unit = "focus", type = "spell", spell = 34477 } }),
    MongooseBite     = Create({ Type = "Spell", ID = 1495, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    RaptorStrike     = Create({ Type = "Spell", ID = 2973, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    Readiness        = Create({ Type = "Spell", ID = 23989, Click = { unit = "player", type = "spell", spell = 23989 } }),
    SnakeTrap        = Create({ Type = "Spell", ID = 34600, Click = { unit = "player", type = "spell", spell = 34600 } }),
    TrackHidden      = Create({ Type = "Spell", ID = 19885, Click = { unit = "player", type = "spell", spell = 19885 } }),
    WingClip         = Create({ Type = "Spell", ID = 2974, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),
    WyvernSting      = Create({ Type = "Spell", ID = 19386, useMaxRank = true, Click = { autounit = "harm", type = "spell" } }),

    -- Talents
    RapidKilling1 = Create({ Type = "Talent", ID = 34948 }),
    RapidKilling2 = Create({ Type = "Talent", ID = 34949 }),

    -- Misc / Buffs
    Heroism   = Create({ Type = "Spell", ID = 32182 }),
    Bloodlust = Create({ Type = "Spell", ID = 2825 }),
    Drums     = Create({ Type = "Spell", ID = 29529 }),

    -- Items
    SuperHealingPotion = Create({ Type = "Potion", ID = 22829, QueueForbidden = true, Click = { unit = "player", type = "item", item = 22829 } }),
    HSMaster1          = Create({ Type = "Spell", ID = 22105, Click = { unit = "player", type = "spell", spell = 22105 } }),
    HSMaster2          = Create({ Type = "Spell", ID = 22104, Click = { unit = "player", type = "spell", spell = 22104 } }),
    HSMaster3          = Create({ Type = "Spell", ID = 22103, Click = { unit = "player", type = "spell", spell = 22103 } }),
    HastePotion        = Create({ Type = "Item", ID = 22838, Click = { unit = "player", type = "item", item = 22838 } }),
    MajorHealingPotion = Create({ Type = "Item", ID = 13446, Click = { unit = "player", type = "item", item = 13446 } }),
    DarkRune           = Create({ Type = "Item", ID = 20520, Click = { unit = "player", type = "item", item = 20520 } }),
    DemonicRune        = Create({ Type = "Item", ID = 12662, Click = { unit = "player", type = "item", item = 12662 } }),

    -- Immunity/Pooling
    PoolResource = Create({ Type = "Spell", ID = 1, FixedTexture = 612968, Desc = "Target Immune - Stop DPS" }),

    -- Pet Attack
    PetAttack = Create({ Type = "Spell", ID = 1, FixedTexture = 134296, Desc = "Pet Attack", Macro = "/petattack" }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local cached_settings = NS.cached_settings
local Pet = LibStub("PetLibrary")
local Toaster = _G.Toaster
local GetSpellTexture = _G.TMW.GetSpellTexture

local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitRangedDamage = _G.UnitRangedDamage
local GetNumGroupMembers = _G.GetNumGroupMembers

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {}

-- Immunity check tables (for AbsentImun calls)
Constants.Temp = {
    TotalAndPhys                = {"TotalImun", "DamagePhysImun"},
    TotalAndCC                  = {"TotalImun", "CCTotalImun"},
    TotalAndPhysKick            = {"TotalImun", "DamagePhysImun", "KickImun"},
    TotalAndPhysAndCC           = {"TotalImun", "DamagePhysImun", "CCTotalImun"},
    TotalAndPhysAndStun         = {"TotalImun", "DamagePhysImun", "StunImun"},
    TotalAndPhysAndCCAndStun    = {"TotalImun", "DamagePhysImun", "CCTotalImun", "StunImun"},
    TotalAndMag                 = {"TotalImun", "DamageMagicImun"},
    TotalAndMagKick             = {"TotalImun", "DamageMagicImun", "KickImun"},
    DisablePhys                 = {"TotalImun", "DamagePhysImun", "Freedom", "CCTotalImun"},
    DisableMag                  = {"TotalImun", "DamageMagicImun", "Freedom", "CCTotalImun"},
}

-- PvP Immunity Spell IDs (from LibAuraTypes.lua TBC)
Constants.TOTAL_IMUN  = { 642, 1020, 45438, 11958, 1022, 5599, 10278, 31224, 33786, 710, 18647 }
Constants.PHYS_IMUN   = { 1022, 5599, 10278, 642, 1020, 45438, 11958, 33786, 710, 18647 }
Constants.MAGIC_IMUN  = { 31224, 8178, 642, 1020, 45438, 11958, 33786 }
Constants.CC_IMUN     = { 19574, 34471, 18499, 1719, 31224, 642, 1020, 45438, 11958, 33786 }

-- PvE Boss Immunity Mechanics (TBC)
Constants.PVE_IMMUNITY_BUFFS = {
    39872,  -- Teron Gorefiend - Shadow of Death
    41450,  -- Illidan - Demon Form transition
    41451,  -- Illidan - Shadow Prison
    40733,  -- Illidan - Flame Crash immunity
    46165,  -- Felmyst - Demonic Vapor
    38112,  -- Hydross - Mark transition immunity
    45662,  -- Brutallus - Burn
    46410,  -- Kil'jaeden - Darkness
    46228,  -- Kil'jaeden - Sacrifice
    30410,  -- Shade of Akama
    43431,  -- Reliquary of Souls - Spirit Shock
}

-- Mana-using classes for Viper Sting
Constants.VIPER_STING_CLASSES = {
    PALADIN = true,
    PRIEST = true,
    SHAMAN = true,
    MAGE = true,
    WARLOCK = true,
    DRUID = true,
    HUNTER = true,
}

NS.Constants = Constants

-- ============================================================================
-- PET LIBRARY SETUP
-- ============================================================================
Pet:AddActionsSpells(3, {
    -- Bite ranks
    17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261, 27050,
    -- Claw ranks
    16827, 16828, 16829, 16830, 16831, 16832, 3010, 3009, 27049,
    -- Gore ranks
    35290, 35291, 35292, 35293, 35294, 35295, 35296, 35297, 35298,
}, true)

NS.Pet = Pet

-- ============================================================================
-- TOASTER REGISTRATION
-- ============================================================================
if Toaster then
    Toaster:Register("TripToast", function(toast, ...)
        local title, message, spellID = ...
        toast:SetTitle(title or "nil")
        toast:SetText(message or "nil")
        if spellID then
            if type(spellID) ~= "number" then
                toast:SetIconTexture("Interface\\FriendsFrame\\Battlenet-WoWicon")
            else
                toast:SetIconTexture((GetSpellTexture(spellID)))
            end
        else
            toast:SetIconTexture("Interface\\FriendsFrame\\Battlenet-WoWicon")
        end
        toast:SetUrgencyLevel("normal")
    end)
end

-- ============================================================================
-- CACHED RANGE FUNCTIONS
-- ============================================================================
local function AtRange(unit)
    return A.ArcaneShot:IsInRange(unit)
end
AtRange = A.MakeFunctionCachedDynamic(AtRange)

local function InMelee(unit)
    return A.WingClip:IsInRange(unit)
end
InMelee = A.MakeFunctionCachedDynamic(InMelee)

local function GetRange(unit)
    return Unit(unit):GetRange() or 0
end
GetRange = A.MakeFunctionCachedDynamic(GetRange)

NS.AtRange = AtRange
NS.InMelee = InMelee
NS.GetRange = GetRange

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================
local function num(val)
    if val then return 1 else return 0 end
end

NS.num = num

-- ============================================================================
-- PRIORITY LOGIC FUNCTIONS
-- ============================================================================

--- Check if target is immune to damage (stop attacking)
local function CheckImmuneOrDoNotAttack(unit)
    if not Unit(unit):IsExists() then return false end

    if A.IsInPvP then
        if (Unit(unit):HasBuffs(Constants.TOTAL_IMUN) or 0) > 0 then return true end
        if (Unit(unit):HasDeBuffs(Constants.TOTAL_IMUN) or 0) > 0 then return true end
    else
        if (Unit(unit):HasBuffs(Constants.PVE_IMMUNITY_BUFFS) or 0) > 0 then return true end
        if (Unit(unit):HasDeBuffs(Constants.PVE_IMMUNITY_BUFFS) or 0) > 0 then return true end
    end
    return false
end

--- Check if target is CC-immune (PvP only)
local function CheckCCImmune(unit)
    if not A.IsInPvP then return false end
    return (Unit(unit):HasBuffs(Constants.CC_IMUN) or 0) > 0
end

--- Should we use Wing Clip on this target?
local function ShouldUseWingClip(unit)
    if Unit(unit):IsBoss() then return false end

    local targetHP = Unit(unit):HealthPercent()

    if A.IsInPvP then
        local pvpThreshold = cached_settings.wing_clip_hp_pvp or 20
        return targetHP >= pvpThreshold
    end

    local inGroup = GetNumGroupMembers() > 0
    local pveThreshold = cached_settings.wing_clip_hp_pve or 20

    if inGroup then
        local mobTarget = unit .. "target"
        if Unit(mobTarget):IsExists() and Unit(mobTarget):IsTank() then
            return false
        end
    end

    return targetHP >= pveThreshold
end

--- Should we use Viper Sting on this target? (PvP only)
local function ShouldUseViperSting(unit)
    if not A.IsInPvP then return false end
    if not Unit(unit):IsPlayer() then return false end

    local targetHP = Unit(unit):HealthPercent()
    local hpThreshold = cached_settings.viper_sting_hp_threshold or 30
    if targetHP < hpThreshold then return false end

    if Unit(unit):PowerType() ~= "MANA" then return false end

    local targetClass = Unit(unit):Class()
    if not targetClass then return false end
    if not Constants.VIPER_STING_CLASSES[targetClass] then return false end

    -- Per-class toggle: "viper_sting_priest", "viper_sting_paladin", etc.
    local toggleKey = "viper_sting_" .. targetClass:lower()
    if cached_settings[toggleKey] == false then return false end

    return true
end

NS.CheckImmuneOrDoNotAttack = CheckImmuneOrDoNotAttack
NS.CheckCCImmune = CheckCCImmune
NS.ShouldUseWingClip = ShouldUseWingClip
NS.ShouldUseViperSting = ShouldUseViperSting

-- Also expose on A for Debug UI compatibility
A.ShouldUseWingClip = ShouldUseWingClip
A.ShouldUseViperSting = ShouldUseViperSting

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Hunter",
    version = "v1.7.0",
    playstyles = { "ranged" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return "ranged"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        ranged = {
            { spell = A.SteadyShot, name = "Steady Shot", required = true },
            { spell = A.ArcaneShot, name = "Arcane Shot", required = true },
            { spell = A.MultiShot, name = "Multi-Shot", required = false },
            { spell = A.SerpentSting, name = "Serpent Sting", required = false },
            { spell = A.HuntersMark, name = "Hunter's Mark", required = false },
            { spell = A.AimedShot, name = "Aimed Shot", required = false, note = "MM talent" },
            { spell = A.KillCommand, name = "Kill Command", required = false, note = "BM talent" },
            { spell = A.BestialWrath, name = "Bestial Wrath", required = false, note = "41pt BM talent" },
            { spell = A.RapidFire, name = "Rapid Fire", required = false },
            { spell = A.Readiness, name = "Readiness", required = false, note = "21pt MM talent" },
            { spell = A.SilencingShot, name = "Silencing Shot", required = false, note = "41pt MM talent" },
            { spell = A.Misdirection, name = "Misdirection", required = false },
            { spell = A.MendPet, name = "Mend Pet", required = false },
            { spell = A.FreezingTrap, name = "Freezing Trap", required = false },
            { spell = A.WingClip, name = "Wing Clip", required = false },
        },
    },

    extend_context = function(ctx)
        ctx.weapon_speed = UnitRangedDamage("player") or 3.0
        ctx.combat_time = Unit("player"):CombatTime() or 0
        ctx.is_moving = Player:IsMoving()
        ctx.is_mounted = Player:IsMounted()
        ctx.shoot_timer = Player:GetSwingShoot()
        ctx.pet_exists = Unit("pet"):IsExists()
        ctx.pet_dead = UnitIsDeadOrGhost("pet") or Unit("pet"):IsDead()
        ctx.pet_active = Pet:IsActive() or (ctx.pet_exists and not ctx.pet_dead)
        ctx.pet_hp = Unit("pet"):HealthPercent() or 0
    end,

    dashboard = {
        resource = { type = "mana", label = "Mana" },
        cooldowns = { A.RapidFire, A.BestialWrath, A.KillCommand, A.Trinket1, A.Trinket2 },
        buffs = {
            { id = 3045, label = "RF" },       -- Rapid Fire
            { id = 34471, label = "TBW" },     -- The Beast Within
        },
        debuffs = {
            { id = A.SerpentSting.ID, label = "Serp", target = true },
        },
        swing_label = "Auto Shot",
        custom_lines = {
            function(context)
                if context.pet_active then return "Pet HP", format("%.0f%%", context.pet_hp or 0) end
                return "Pet", "Inactive"
            end,
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Hunter]|r Class module loaded")
