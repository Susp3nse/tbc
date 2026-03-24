-- Warrior Class Module
-- Defines all Warrior spells, constants, helper functions, and registers Warrior as a class

local _G, setmetatable = _G, setmetatable
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Warrior]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    BloodFury          = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    Berserking         = Create({ Type = "Spell", ID = 26296, Click = { unit = "player", type = "spell", spell = 26296 } }),
    Stoneform          = Create({ Type = "Spell", ID = 20594, Click = { unit = "player", type = "spell", spell = 20594 } }),
    WillOfTheForsaken  = Create({ Type = "Spell", ID = 7744,  Click = { unit = "player", type = "spell", spell = 7744 } }),
    WarStomp           = Create({ Type = "Spell", ID = 20549, Click = { unit = "player", type = "spell", spell = 20549 } }),
    EscapeArtist       = Create({ Type = "Spell", ID = 20589, Click = { unit = "player", type = "spell", spell = 20589 } }),

    -- Core Damage (useMaxRank with base IDs)
    HeroicStrike       = Create({ Type = "Spell", ID = 78, useMaxRank = true }),
    Cleave             = Create({ Type = "Spell", ID = 845, useMaxRank = true }),
    MortalStrike       = Create({ Type = "Spell", ID = 12294, useMaxRank = true }),
    Bloodthirst        = Create({ Type = "Spell", ID = 23881, useMaxRank = true }),
    Execute            = Create({ Type = "Spell", ID = 5308, useMaxRank = true }),
    Overpower          = Create({ Type = "Spell", ID = 7384, useMaxRank = true }),
    Slam               = Create({ Type = "Spell", ID = 1464, useMaxRank = true }),
    Revenge            = Create({ Type = "Spell", ID = 6572, useMaxRank = true }),
    ShieldSlam         = Create({ Type = "Spell", ID = 23922, useMaxRank = true }),
    Devastate          = Create({ Type = "Spell", ID = 20243, useMaxRank = true }),
    Rend               = Create({ Type = "Spell", ID = 772, useMaxRank = true }),
    Hamstring          = Create({ Type = "Spell", ID = 1715, useMaxRank = true }),
    SunderArmor        = Create({ Type = "Spell", ID = 7386, useMaxRank = true }),
    ThunderClap        = Create({ Type = "Spell", ID = 6343, useMaxRank = true }),

    -- Single-rank spells
    Whirlwind          = Create({ Type = "Spell", ID = 1680 }),
    VictoryRush        = Create({ Type = "Spell", ID = 34428 }),
    Taunt              = Create({ Type = "Spell", ID = 355 }),
    MockingBlow        = Create({ Type = "Spell", ID = 694, useMaxRank = true }),
    ChallengingShout   = Create({ Type = "Spell", ID = 1161, Click = { unit = "player", type = "spell", spell = 1161 } }),
    Charge             = Create({ Type = "Spell", ID = 100, useMaxRank = true }),
    Intercept          = Create({ Type = "Spell", ID = 20252, useMaxRank = true }),

    -- Shouts
    BattleShout        = Create({ Type = "Spell", ID = 6673, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    CommandingShout    = Create({ Type = "Spell", ID = 469, Click = { unit = "player", type = "spell", spell = 469 } }),
    DemoralizingShout  = Create({ Type = "Spell", ID = 1160, useMaxRank = true }),

    -- Cooldowns (self-cast)
    DeathWish          = Create({ Type = "Spell", ID = 12292, Click = { unit = "player", type = "spell", spell = 12292 } }),
    Recklessness       = Create({ Type = "Spell", ID = 1719, Click = { unit = "player", type = "spell", spell = 1719 } }),
    SweepingStrikes    = Create({ Type = "Spell", ID = 12328, Click = { unit = "player", type = "spell", spell = 12328 } }),
    Bloodrage          = Create({ Type = "Spell", ID = 2687, Click = { unit = "player", type = "spell", spell = 2687 } }),
    BerserkerRage      = Create({ Type = "Spell", ID = 18499, Click = { unit = "player", type = "spell", spell = 18499 } }),
    Rampage            = Create({ Type = "Spell", ID = 29801, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Defensive (self-cast)
    ShieldBlock        = Create({ Type = "Spell", ID = 2565, Click = { unit = "player", type = "spell", spell = 2565 } }),
    ShieldWall         = Create({ Type = "Spell", ID = 871, Click = { unit = "player", type = "spell", spell = 871 } }),
    LastStand          = Create({ Type = "Spell", ID = 12975, Click = { unit = "player", type = "spell", spell = 12975 } }),
    SpellReflection    = Create({ Type = "Spell", ID = 23920, Click = { unit = "player", type = "spell", spell = 23920 } }),

    -- Stances
    BattleStance       = Create({ Type = "Spell", ID = 2457 }),
    DefensiveStance    = Create({ Type = "Spell", ID = 71   }),
    BerserkerStance    = Create({ Type = "Spell", ID = 2458 }),

    -- Defensive abilities
    Retaliation        = Create({ Type = "Spell", ID = 20230 }),

    -- Interrupts
    Pummel             = Create({ Type = "Spell", ID = 6552, useMaxRank = true }),
    ShieldBash         = Create({ Type = "Spell", ID = 72, useMaxRank = true }),

    -- PvP CC / Utility
    Disarm             = Create({ Type = "Spell", ID = 676, Click = { macrobefore = "/stopcasting" } }),
    IntimidatingShout  = Create({ Type = "Spell", ID = 5246, Click = { macrobefore = "/stopcasting" } }),
    ConcussionBlow     = Create({ Type = "Spell", ID = 12809, isTalent = true, Click = { macrobefore = "/stopcasting" } }),
    PiercingHowl       = Create({ Type = "Spell", ID = 12323, isTalent = true }),
    Intervene          = Create({ Type = "Spell", ID = 3411 }),
    Perception         = Create({ Type = "Spell", ID = 20600, Click = { unit = "player", type = "spell", spell = 20600 } }),

    -- PvP tracking (hidden, for buff/debuff condition checks)
    Evasion            = Create({ Type = "Spell", ID = 26669, Hidden = true }),
    Deterrence         = Create({ Type = "Spell", ID = 19263, Hidden = true }),
    FreeActionPotion   = Create({ Type = "Spell", ID = 6615, Hidden = true }),

    -- Talents (hidden, for rank queries)
    TacticalMastery    = Create({ Type = "Spell", ID = 12295, Hidden = true, isTalent = true }),

    -- External buff cancelauras
    PowerWordShield    = Create({ Type = "Spell", ID = 17,   Click = { type = "cancelaura" } }),
    BlessingOfProtection = Create({ Type = "Spell", ID = 1022, Click = { type = "cancelaura" } }),

    -- Items (No Click table — MetaEngine auto-generates secure bindings)
    SuperHealingPotion = Create({ Type = "Potion", ID = 22829, QueueForbidden = true }),
    MajorHealingPotion = Create({ Type = "Potion", ID = 13446, QueueForbidden = true }),
    -- Healthstones
    HealthstoneMaster  = Create({ Type = "Item", ID = 22105, QueueForbidden = true }),
    HealthstoneMajor   = Create({ Type = "Item", ID = 22104, QueueForbidden = true }),

    -- Bandages (descending quality for DetermineUsableObject)
    HeavyNetherweaveBandage = Create({ Type = "Item", ID = 21991, QueueForbidden = true }),
    NetherweaveBandage      = Create({ Type = "Item", ID = 21990, QueueForbidden = true }),
    HeavyRuneclothBandage   = Create({ Type = "Item", ID = 14530, QueueForbidden = true }),
    RuneclothBandage        = Create({ Type = "Item", ID = 14529, QueueForbidden = true }),
    HeavyMageweaveBandage   = Create({ Type = "Item", ID = 8545,  QueueForbidden = true }),
    MageweaveBandage        = Create({ Type = "Item", ID = 8544,  QueueForbidden = true }),
    HeavySilkBandage        = Create({ Type = "Item", ID = 6451,  QueueForbidden = true }),
    SilkBandage             = Create({ Type = "Item", ID = 6450,  QueueForbidden = true }),
    HeavyWoolBandage        = Create({ Type = "Item", ID = 3531,  QueueForbidden = true }),
    WoolBandage             = Create({ Type = "Item", ID = 3530,  QueueForbidden = true }),
    HeavyLinenBandage       = Create({ Type = "Item", ID = 2581,  QueueForbidden = true }),
    LinenBandage            = Create({ Type = "Item", ID = 1251,  QueueForbidden = true }),
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

-- Register off-hand weapon inventory query (required before HasWeaponOffHand works)
Player:RegisterWeaponOffHand()

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    STANCE = {
        BATTLE    = 1,
        DEFENSIVE = 2,
        BERSERKER = 3,
    },

    -- Preferred stance per spec (used by stance correction middleware)
    PREFERRED_STANCE = {
        arms       = 1,  -- Battle
        fury       = 3,  -- Berserker
        protection = 2,  -- Defensive
    },

    -- All-rank arrays for party buff detection (any source, any rank)
    BATTLE_SHOUT_IDS  = { 6673, 5242, 6192, 11549, 11550, 11551, 2048 },
    COMMANDING_SHOUT_IDS = { 469 },

    BUFF_ID = {
        BATTLE_SHOUT      = 2048,
        COMMANDING_SHOUT  = 469,
        DEATH_WISH        = 12292,
        RECKLESSNESS      = 1719,
        SWEEPING_STRIKES  = 12328,
        BERSERKER_RAGE    = 18499,
        ENRAGE            = 14202,
        FLURRY            = 12974,
        RAMPAGE           = 30033,
        SHIELD_BLOCK      = 2565,
        LAST_STAND        = 12975,
        SPELL_REFLECTION  = 23920,
        RETALIATION       = 20230,
        -- External buffs (for cancelaura)
        POWER_WORD_SHIELD = 17,
        BLESSING_OF_PROT  = 1022,
    },

    DEBUFF_ID = {
        REND              = 25208,
        SUNDER_ARMOR      = 25225,
        THUNDER_CLAP      = 25264,
        DEMO_SHOUT        = 25203,
    },

    SUNDER_MAX_STACKS        = 5,
    SUNDER_REFRESH_WINDOW    = 3,
    TC_REFRESH_WINDOW        = 2,
    RAMPAGE_MAX_STACKS       = 5,

    -- PvP immunity check tables (for AbsentImun calls)
    -- Keys match AuraList categories in the framework
    PVP = {
        AttackTypes       = { "TotalImun", "DamagePhysImun" },
        AuraForInterrupt  = { "TotalImun", "DamagePhysImun", "KickImun" },
        AuraForFear       = { "TotalImun", "DamagePhysImun", "FearImun" },
        AuraForStun       = { "TotalImun", "DamagePhysImun", "CCTotalImun", "StunImun" },
        AuraForSlow       = { "TotalImun", "DamagePhysImun", "CCTotalImun", "Freedom" },
        AuraForDisarm     = { "TotalImun", "DamagePhysImun", "CCTotalImun" },
    },

    -- Taunt thresholds (matching Druid Growl/Challenging Roar pattern)
    TAUNT = {
        CC_THRESHOLD       = 2,     -- Skip CC'd mobs with > 2s remaining
        MIN_TTD            = 4,     -- Skip dying mobs (unless targeting healer)
        CSHOUT_RANGE       = 10,    -- Challenging Shout scan range (10yd PBAoE)
        CSHOUT_MIN_BOSSES  = 1,     -- Min loose bosses for Challenging Shout
        CSHOUT_MIN_ELITES  = 3,     -- Min loose elites for Challenging Shout
        CSHOUT_MIN_TRASH   = 5,     -- Min loose trash for Challenging Shout
    },
}

NS.Constants = Constants

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
local STANCE_NAMES = { "Battle", "Defensive", "Berserker" }

-- Breakable CC spell names for PvE detection (matching druid bear.lua pattern)
local BREAKABLE_CC_NAMES = {
    "Polymorph", "Freezing Trap Effect", "Repentance", "Blind",
    "Sap", "Gouge", "Hibernate", "Wyvern Sting", "Scatter Shot",
    "Shackle Undead", "Seduction",
}

-- PvE CC scan: check nameplates within 10y for breakable CC debuffs
local function has_pve_breakable_cc_nearby()
    local plates = MultiUnits:GetActiveUnitPlates()
    for unitID in pairs(plates) do
        if Unit(unitID):GetRange() <= 10 then
            for i = 1, #BREAKABLE_CC_NAMES do
                if (Unit(unitID):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
                    return true
                end
            end
        end
    end
    return false
end

rotation_registry:register_class({
    name = "Warrior",
    version = "v1.8.1",
    playstyles = { "arms", "fury", "protection" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "fury"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        arms = {
            { spell = A.MortalStrike, name = "Mortal Strike", required = true, note = "Arms talent" },
            { spell = A.Overpower, name = "Overpower", required = false },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Slam, name = "Slam", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.Rend, name = "Rend", required = false },
            { spell = A.SweepingStrikes, name = "Sweeping Strikes", required = false, note = "Arms talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
        },
        fury = {
            { spell = A.Bloodthirst, name = "Bloodthirst", required = true, note = "Fury talent" },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.Slam, name = "Slam", required = false },
            { spell = A.Rampage, name = "Rampage", required = false, note = "41pt Fury talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
            { spell = A.Recklessness, name = "Recklessness", required = false },
        },
        protection = {
            { spell = A.ShieldSlam, name = "Shield Slam", required = false, note = "Prot talent" },
            { spell = A.Revenge, name = "Revenge", required = true },
            { spell = A.Devastate, name = "Devastate", required = false, note = "41pt Prot talent" },
            { spell = A.SunderArmor, name = "Sunder Armor", required = false },
            { spell = A.ShieldBlock, name = "Shield Block", required = false },
            { spell = A.ThunderClap, name = "Thunder Clap", required = false },
            { spell = A.LastStand, name = "Last Stand", required = false, note = "Prot talent" },
        },
    },

    extend_context = function(ctx)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit("player"):CombatTime() or 0
        ctx.stance = Player:GetStance()
        ctx.rage = Player:Rage()
        ctx.enemy_count = MultiUnits:GetByRangeInCombat(8) or 0

        -- Threat info for threat-lead gating (prot utility abilities)
        ctx.threat_status = _G.UnitThreatSituation("player", "target") or 0
        ctx.threat_percent = 0
        if ctx.target_exists and ctx.target_enemy then
            local _, pct = _G.UnitDetailedThreatSituation("player", "target")
            ctx.threat_percent = pct or 0
        end

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

        -- PvP state (framework-managed, auto-detects BG/arena/flagged)
        ctx.is_pvp = A.IsInPvP or false
        ctx.is_arena = A.Zone == "arena"
        ctx.is_battleground = A.Zone == "pvp"
        ctx.target_is_player = ctx.target_exists and _G.UnitIsPlayer("target") or false

        -- CC break prevention flag — true if any nearby enemy has breakable CC
        -- Strategies check this before firing AoE (WW, Cleave, TC, Demo Shout)
        if ctx.is_pvp then
            local ok = A.EnemyTeam(nil):IsBreakAble(8)
            ctx.has_breakable_cc_nearby = ok or false
        else
            ctx.has_breakable_cc_nearby = has_pve_breakable_cc_nearby()
        end

        -- Buff tracking
        ctx.has_battle_shout = (Unit("player"):HasBuffs(Constants.BATTLE_SHOUT_IDS) or 0) > 0
        ctx.has_commanding_shout = (Unit("player"):HasBuffs(Constants.COMMANDING_SHOUT_IDS) or 0) > 0
        ctx.death_wish_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.DEATH_WISH) or 0) > 0
        ctx.recklessness_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.RECKLESSNESS) or 0) > 0
        ctx.sweeping_strikes_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SWEEPING_STRIKES) or 0) > 0
        ctx.berserker_rage_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.BERSERKER_RAGE) or 0) > 0
        ctx.rampage_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.RAMPAGE) or 0) > 0
        ctx.rampage_stacks = Unit("player"):HasBuffsStacks(Constants.BUFF_ID.RAMPAGE) or 0
        ctx.rampage_duration = Unit("player"):HasBuffs(Constants.BUFF_ID.RAMPAGE) or 0
        ctx.shield_block_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.SHIELD_BLOCK) or 0) > 0
        ctx.enrage_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.ENRAGE) or 0) > 0
        ctx.flurry_active = (Unit("player"):HasBuffs(Constants.BUFF_ID.FLURRY) or 0) > 0

        -- OH swing diagnostic (temporary — shows in CTX dump for HS trick debugging)
        ctx.has_offhand = Player:HasWeaponOffHand(true) and true or false
        if ctx.has_offhand then
            local oh_s = Player:GetSwingStart(2) or 0
            local oh_spd = Player:GetSwing(2) or 0
            ctx.oh_start = oh_s
            ctx.oh_speed = oh_spd
            if oh_s > 0 and oh_spd > 0 then
                local rem = (oh_s + oh_spd) - _G.GetTime()
                ctx.oh_remain = rem > 0 and math.floor(rem * 100 + 0.5) / 100 or 0
            else
                ctx.oh_remain = -1  -- API returned zero
            end
            ctx.mh_remain = math.floor((NS.get_time_until_swing() or 0) * 100 + 0.5) / 100
        end

        -- Cache invalidation flags for per-playstyle context_builders
        ctx._arms_valid = false
        ctx._fury_valid = false
        ctx._prot_valid = false
    end,

    gap_handler = function(icon, context)
        if A.Charge:IsReady(TARGET_UNIT) then
            return A.Charge:Show(icon), "[GAP] Charge"
        end
        if A.Intercept:IsReady(TARGET_UNIT) then
            return A.Intercept:Show(icon), "[GAP] Intercept"
        end
        return nil
    end,

    dashboard = {
        resource = { type = "rage", label = "Rage" },
        cooldowns = {
            arms = { A.SweepingStrikes, A.Recklessness, A.DeathWish, A.Trinket1, A.Trinket2 },
            fury = { A.DeathWish, A.Recklessness, A.Trinket1, A.Trinket2 },
            protection = { A.ShieldBlock, A.ShieldWall, A.LastStand, A.Trinket1, A.Trinket2 },
        },
        buffs = {
            arms = {
                { id = Constants.BUFF_ID.SWEEPING_STRIKES, label = "SS" },
                { id = Constants.BUFF_ID.RECKLESSNESS, label = "Reck" },
                { id = Constants.BUFF_ID.ENRAGE, label = "Enr" },
            },
            fury = {
                { id = Constants.BUFF_ID.DEATH_WISH, label = "DW" },
                { id = Constants.BUFF_ID.RECKLESSNESS, label = "Reck" },
                { id = Constants.BUFF_ID.RAMPAGE, label = "Ramp" },
                { id = Constants.BUFF_ID.FLURRY, label = "Flurry" },
            },
            protection = {
                { id = Constants.BUFF_ID.SHIELD_BLOCK, label = "SB" },
                { id = Constants.BUFF_ID.LAST_STAND, label = "LS" },
                { id = Constants.BUFF_ID.SPELL_REFLECTION, label = "SR" },
            },
        },
        debuffs = {
            arms = {
                { id = Constants.DEBUFF_ID.REND, label = "Rend", target = true },
                { id = Constants.DEBUFF_ID.SUNDER_ARMOR, label = "Sunder", target = true, show_stacks = true },
            },
            fury = {
                { id = Constants.DEBUFF_ID.SUNDER_ARMOR, label = "Sunder", target = true, show_stacks = true },
            },
            protection = {
                { id = Constants.DEBUFF_ID.SUNDER_ARMOR, label = "Sunder", target = true, show_stacks = true },
                { id = Constants.DEBUFF_ID.THUNDER_CLAP, label = "TC", target = true, owned = false },
                { id = Constants.DEBUFF_ID.DEMO_SHOUT, label = "Demo", target = true, owned = false },
            },
        },
        custom_lines = {
            function(context) return "Stance", STANCE_NAMES[context.stance] or "?" end,
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Class module loaded")
