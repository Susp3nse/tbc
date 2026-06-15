-- Shaman Class Module
-- Defines all Shaman spells, constants, totem utilities, and registers Shaman as a class

local _G, setmetatable = _G, setmetatable
local GetTime = _G.GetTime
local GetTotemInfo = _G.GetTotemInfo
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "SHAMAN" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Shaman]|r Core module not loaded!")
    return
end

-- ============================================================================
-- ACTION DEFINITIONS
-- ============================================================================
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    BloodFuryAP     = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    BloodFurySP     = Create({ Type = "Spell", ID = 33697, Click = { unit = "player", type = "spell", spell = 33697 } }),
    Berserking      = Create({ Type = "Spell", ID = 26297, Click = { unit = "player", type = "spell", spell = 26297 } }),
    WarStomp        = Create({ Type = "Spell", ID = 20549, Click = { unit = "player", type = "spell", spell = 20549 } }),
    GiftOfTheNaaru  = Create({ Type = "Spell", ID = 28880, Click = { unit = "player", type = "spell", spell = 28880 } }),

    -- Core Damage
    LightningBolt  = Create({ Type = "Spell", ID = 403, useMaxRank = true }),
    ChainLightning = Create({ Type = "Spell", ID = 421, useMaxRank = true }),
    EarthShock     = Create({ Type = "Spell", ID = 25454, useMaxRank = true }),  -- R8 (25454) for damage
    EarthShockR1   = Create({ Type = "Spell", ID = 8042 }),  -- R1 (8042) for interrupt-only (saves mana)
    FlameShock     = Create({ Type = "Spell", ID = 8050, useMaxRank = true }),
    FrostShock     = Create({ Type = "Spell", ID = 8056, useMaxRank = true }),
    Stormstrike    = Create({ Type = "Spell", ID = 17364 }),

    -- Shields
    WaterShield    = Create({ Type = "Spell", ID = 24398, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    LightningShield = Create({ Type = "Spell", ID = 324, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    EarthShield    = Create({ Type = "Spell", ID = 974, useMaxRank = true }),

    -- Healing
    HealingWave       = Create({ Type = "Spell", ID = 331, useMaxRank = true }),
    LesserHealingWave = Create({ Type = "Spell", ID = 8004, useMaxRank = true }),
    ChainHeal         = Create({ Type = "Spell", ID = 1064, useMaxRank = true }),

    -- Fire Totems
    SearingTotem       = Create({ Type = "Spell", ID = 3599, useMaxRank = true }),
    FireNovaTotem      = Create({ Type = "Spell", ID = 1535, useMaxRank = true }),
    MagmaTotem         = Create({ Type = "Spell", ID = 8190, useMaxRank = true }),
    TotemOfWrath       = Create({ Type = "Spell", ID = 30706 }),
    FlametongueTotem   = Create({ Type = "Spell", ID = 8227, useMaxRank = true }),
    FireElementalTotem = Create({ Type = "Spell", ID = 2894 }),

    -- Earth Totems
    StrengthOfEarth    = Create({ Type = "Spell", ID = 8075, useMaxRank = true }),
    StoneskinTotem     = Create({ Type = "Spell", ID = 8071, useMaxRank = true }),
    TremorTotem        = Create({ Type = "Spell", ID = 8143 }),
    EarthbindTotem     = Create({ Type = "Spell", ID = 2484 }),
    EarthElementalTotem = Create({ Type = "Spell", ID = 2062 }),

    -- Water Totems
    ManaSpringTotem    = Create({ Type = "Spell", ID = 5675, useMaxRank = true }),
    HealingStreamTotem = Create({ Type = "Spell", ID = 5394, useMaxRank = true }),
    ManaTideTotem      = Create({ Type = "Spell", ID = 16190 }),

    -- Air Totems
    WindfuryTotem      = Create({ Type = "Spell", ID = 8512, useMaxRank = true }),
    GraceOfAirTotem    = Create({ Type = "Spell", ID = 8835, useMaxRank = true }),
    WrathOfAirTotem    = Create({ Type = "Spell", ID = 3738 }),
    GroundingTotem     = Create({ Type = "Spell", ID = 8177 }),
    TranquilAirTotem   = Create({ Type = "Spell", ID = 25908 }),

    -- Weapon Imbues
    WindfuryWeapon     = Create({ Type = "Spell", ID = 8232, useMaxRank = true, Click = { unit = "player", type = "spell" } }),
    FlametongueWeapon  = Create({ Type = "Spell", ID = 8024, useMaxRank = true, Click = { unit = "player", type = "spell" } }),

    -- Cooldowns
    ElementalMastery   = Create({ Type = "Spell", ID = 16166, Click = { unit = "player", type = "spell", spell = 16166 } }),
    NaturesSwiftness   = Create({ Type = "Spell", ID = 16188, Click = { unit = "player", type = "spell", spell = 16188 } }),
    ShamanisticRage    = Create({ Type = "Spell", ID = 30823, Click = { unit = "player", type = "spell", spell = 30823 } }),
    Bloodlust          = Create({ Type = "Spell", ID = 2825 }),
    Heroism            = Create({ Type = "Spell", ID = 32182 }),

    -- Enhancement: swing sync resync macro. Auto-attack toggle (ID 6603) is
    -- the natural icon identity for a swing-related action. We use macroAFTER
    -- (not before) so /startattack is the LAST command in the assembled macro
    -- -- guarantees auto-attack ends ON regardless of whether the framework
    -- appends /cast Auto Attack (which would otherwise toggle it off).
    -- The trailing /run callback into Menagerie_ResyncFired (defined in
    -- enhancement.lua) lets us confirm via debug log that the macro actually
    -- executed in-game — not just that we recommended it on the icon.
    -- Logic source: enhanceshaman.com/pages/guide/sync_stagger
    SwingResync = Create({ Type = "Spell", ID = 6603, Desc = "Swing Resync",
        Click = { macroafter = "/cleartarget\n/targetlasttarget\n/startattack\n/run if Menagerie_ResyncFired then Menagerie_ResyncFired() end\n" } }),

    -- Utility
    Purge       = Create({ Type = "Spell", ID = 370, useMaxRank = true }),
    CurePoison  = Create({ Type = "Spell", ID = 526, Click = { unit = "player", type = "spell", spell = 526 } }),
    CureDisease = Create({ Type = "Spell", ID = 2870, Click = { unit = "player", type = "spell", spell = 2870 } }),

    -- Items
    MajorManaPotion    = Create({ Type = "Item", ID = 13444, Click = { unit = "player", type = "item", item = 13444 } }),
}

-- ============================================================================
-- CLASS-SPECIFIC FRAMEWORK REFERENCES
-- ============================================================================
A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A
NS.register_consumable_actions(A)

local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Framework helpers
local MultiUnits = A.MultiUnits

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local Constants = {
    BUFF_ID = {
        WATER_SHIELD       = 33736,
        LIGHTNING_SHIELD   = 25472,
        EARTH_SHIELD       = 32594,
        ELEMENTAL_FOCUS    = 16246,  -- Clearcasting (2 charges, -40% mana cost)
        ELEMENTAL_MASTERY  = 16166,
        NATURES_SWIFTNESS  = 16188,
        SHAMANISTIC_RAGE   = 30823,
        SHAMANISTIC_FOCUS  = 43339,  -- -60% shock cost after melee crit
        FLURRY             = 16280,  -- +30% melee haste, 3 charges
    },

    DEBUFF_ID = {
        FLAME_SHOCK  = 25457,  -- Max rank Flame Shock DoT
        STORMSTRIKE  = 17364,  -- +20% nature dmg, 2 charges, 12s
    },

    TOTEM_SLOT = {
        FIRE  = 1,
        EARTH = 2,
        WATER = 3,
        AIR   = 4,
    },

    -- Totem refresh threshold (seconds remaining before re-dropping)
    TOTEM_REFRESH_THRESHOLD = 10,

    -- WF totem twist timing
    -- WF buff persists ~10s on melee after the totem is replaced. To keep
    -- continuous uptime we re-drop WF *before* the carried buff expires.
    -- Old behavior used a single CYCLE_TIME (10s) for both phases, which
    -- made the full WF→Grace→WF loop 20s — half the rate it should be.
    TWIST = {
        WF_BUFF_DURATION = 10,        -- WF buff persists ~10s on players after totem replaced
        WF_PHASE_DURATION = 1.5,      -- hold WF active for one GCD before swapping to Grace
        DEFAULT_PHASE_DURATION = 7.5, -- swap back to WF ~1.5s before the carried buff expires
        OOM_THRESHOLD = 0.20,         -- skip twist below 20% mana
    },
}

NS.Constants = Constants

-- ============================================================================
-- TOTEM UTILITIES
-- ============================================================================
-- Pre-allocated totem state (refreshed each frame via extend_context)
local totem_state = {
    fire_active = false,
    fire_remaining = 0,
    fire_start = 0,
    fire_is_fire_elemental = false,
    fire_is_fire_nova = false,
    earth_active = false,
    earth_remaining = 0,
    earth_start = 0,
    earth_is_tremor = false,
    water_active = false,
    water_remaining = 0,
    water_start = 0,
    air_active = false,
    air_remaining = 0,
    air_start = 0,
    air_is_windfury = false,
}

-- Pre-computed field name keys (avoid string concat in combat hot path)
local SLOT_ACTIVE_KEYS = { "fire_active", "earth_active", "water_active", "air_active" }
local SLOT_REMAINING_KEYS = { "fire_remaining", "earth_remaining", "water_remaining", "air_remaining" }
local SLOT_START_KEYS = { "fire_start", "earth_start", "water_start", "air_start" }

local function refresh_totem_state()
    local now = GetTime()
    for slot = 1, 4 do
        local have, name, start, dur = GetTotemInfo(slot)
        local active = have and name ~= "" and name ~= nil
        totem_state[SLOT_ACTIVE_KEYS[slot]] = active
        totem_state[SLOT_REMAINING_KEYS[slot]] = active and ((start + dur) - now) or 0
        totem_state[SLOT_START_KEYS[slot]] = active and start or 0
        if slot == Constants.TOTEM_SLOT.FIRE then
            totem_state.fire_is_fire_elemental = active and name:find("Fire Elemental") ~= nil
            totem_state.fire_is_fire_nova = active and name:find("Fire Nova") ~= nil
        elseif slot == Constants.TOTEM_SLOT.EARTH then
            totem_state.earth_is_tremor = active and name:find("Tremor") ~= nil
        elseif slot == Constants.TOTEM_SLOT.AIR then
            totem_state.air_is_windfury = active and name:find("Windfury") ~= nil
        end
    end
end

NS.totem_state = totem_state
NS.refresh_totem_state = refresh_totem_state
NS.tremor_active_in_earth_slot = function() return totem_state.earth_is_tremor end

-- Totem spell lookup tables (setting value → spell reference)
-- Built after A is defined; used by totem management strategies
local FIRE_TOTEM_SPELLS = {
    totem_of_wrath = function() return A.TotemOfWrath end,
    searing        = function() return A.SearingTotem end,
    magma          = function() return A.MagmaTotem end,
    flametongue    = function() return A.FlametongueTotem end,
}

local EARTH_TOTEM_SPELLS = {
    strength_of_earth = function() return A.StrengthOfEarth end,
    stoneskin         = function() return A.StoneskinTotem end,
    tremor            = function() return A.TremorTotem end,
}

local WATER_TOTEM_SPELLS = {
    mana_spring    = function() return A.ManaSpringTotem end,
    healing_stream = function() return A.HealingStreamTotem end,
}

local AIR_TOTEM_SPELLS = {
    wrath_of_air  = function() return A.WrathOfAirTotem end,
    windfury      = function() return A.WindfuryTotem end,
    grace_of_air  = function() return A.GraceOfAirTotem end,
    tranquil_air  = function() return A.TranquilAirTotem end,
    grounding     = function() return A.GroundingTotem end,
}

NS.FIRE_TOTEM_SPELLS = FIRE_TOTEM_SPELLS
NS.EARTH_TOTEM_SPELLS = EARTH_TOTEM_SPELLS
NS.WATER_TOTEM_SPELLS = WATER_TOTEM_SPELLS
NS.AIR_TOTEM_SPELLS = AIR_TOTEM_SPELLS

--- Resolve a totem setting value to a spell object
--- @param setting_value string The setting dropdown value (e.g. "searing")
--- @param lookup_table table The TOTEM_SPELLS table for that slot
--- @return table|nil The spell Action object, or nil if not found/not known
local function resolve_totem_spell(setting_value, lookup_table)
    local getter = lookup_table[setting_value]
    if not getter then return nil end
    local spell = getter()
    if not spell then return nil end
    return spell
end

NS.resolve_totem_spell = resolve_totem_spell

--- Check if a totem element is allowed based on group condition setting
--- @param condition string "always" or "group_only"
--- @param in_group boolean Whether player is in a party/raid
--- @return boolean
local function totem_allowed(condition, in_group)
    return (condition or "always") ~= "group_only" or in_group
end
NS.totem_allowed = totem_allowed

local function totem_slot_needs_refresh(context, slot_opt, slot_active, slot_remaining, is_earth)
    local s = context.settings
    local setting = s[slot_opt.key] or slot_opt.default
    if setting == "none" then return false end
    if not totem_allowed(s[slot_opt.condition], context.in_group) then return false end
    if is_earth and s.use_auto_tremor and context.totem_earth_active
        and NS.tremor_active_in_earth_slot() then
        return false
    end
    return NS.timer_needs_refresh(slot_active, slot_remaining, Constants.TOTEM_REFRESH_THRESHOLD)
end

local function drop_totem_slot(icon, context, slot_opt, slot_active, slot_remaining, log_msg, is_earth)
    if not totem_slot_needs_refresh(context, slot_opt, slot_active, slot_remaining, is_earth) then
        return nil
    end
    local spell = resolve_totem_spell(context.settings[slot_opt.key] or slot_opt.default, slot_opt.lookup)
    if spell and spell:IsReady(PLAYER_UNIT) then
        return spell:Show(icon), log_msg
    end
    return nil
end

function NS.make_totem_management(opts)
    local prefix = opts.prefix
    local fire_log = prefix .. " Fire Totem"
    local earth_log = prefix .. " Earth Totem"
    local water_log = prefix .. " Water Totem"
    local air_log = prefix .. " Air Totem"

    return {
        requires_combat = true,

        matches = function(context, state)
            if opts.respect_is_moving and context.is_moving then return false end
            local s = context.settings
            if (not opts.skip_fire or not opts.skip_fire(s, context)) and not context.fire_elemental_active
                and totem_slot_needs_refresh(context, opts.fire, context.totem_fire_active, context.totem_fire_remaining, false) then
                return true
            end
            if totem_slot_needs_refresh(context, opts.earth, context.totem_earth_active, context.totem_earth_remaining, true) then
                return true
            end
            if totem_slot_needs_refresh(context, opts.water, context.totem_water_active, context.totem_water_remaining, false) then
                return true
            end
            if (not opts.skip_air or not opts.skip_air(s, context))
                and totem_slot_needs_refresh(context, opts.air, context.totem_air_active, context.totem_air_remaining, false) then
                return true
            end
            return false
        end,

        execute = function(icon, context, state)
            if opts.respect_is_moving and context.is_moving then return nil end
            local s = context.settings
            local result, log_msg
            if (not opts.skip_fire or not opts.skip_fire(s, context)) and not context.fire_elemental_active then
                result, log_msg = drop_totem_slot(icon, context, opts.fire, context.totem_fire_active, context.totem_fire_remaining, fire_log, false)
                if result then return result, log_msg end
            end
            result, log_msg = drop_totem_slot(icon, context, opts.earth, context.totem_earth_active, context.totem_earth_remaining, earth_log, true)
            if result then return result, log_msg end
            result, log_msg = drop_totem_slot(icon, context, opts.water, context.totem_water_active, context.totem_water_remaining, water_log, false)
            if result then return result, log_msg end
            if not opts.skip_air or not opts.skip_air(s, context) then
                result, log_msg = drop_totem_slot(icon, context, opts.air, context.totem_air_active, context.totem_air_remaining, air_log, false)
                if result then return result, log_msg end
            end
            return nil
        end,
    }
end

function NS.make_fire_elemental(prefix, setting_key)
    return {
        requires_combat = true,
        is_burst = true,
        spell = A.FireElementalTotem,
        spell_target = PLAYER_UNIT,
        setting_key = setting_key,

        matches = function(context, state)
            if NS.ttd_too_short(context) then return false end
            return true
        end,

        execute = function(icon, context, state)
            return try_cast(A.FireElementalTotem, icon, PLAYER_UNIT, prefix .. " Fire Elemental Totem")
        end,
    }
end

-- ============================================================================
-- CLASS REGISTRATION
-- ============================================================================
rotation_registry:register_class({
    name = "Shaman",
    playstyles = { "elemental", "enhancement", "restoration" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "elemental"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        elemental = {
            { spell = A.LightningBolt, name = "Lightning Bolt", required = true },
            { spell = A.ChainLightning, name = "Chain Lightning", required = false },
            { spell = A.EarthShock, name = "Earth Shock", required = true },
            { spell = A.FlameShock, name = "Flame Shock", required = false },
            { spell = A.ElementalMastery, name = "Elemental Mastery", required = false, note = "21pt Elemental talent" },
            { spell = A.TotemOfWrath, name = "Totem of Wrath", required = false, note = "41pt Elemental talent" },
        },
        enhancement = {
            { spell = A.Stormstrike, name = "Stormstrike", required = false, note = "40pt Enhancement talent" },
            { spell = A.EarthShock, name = "Earth Shock", required = true },
            { spell = A.FlameShock, name = "Flame Shock", required = false },
            { spell = A.ShamanisticRage, name = "Shamanistic Rage", required = false, note = "41pt Enhancement talent" },
            { spell = A.WindfuryWeapon, name = "Windfury Weapon", required = false },
            { spell = A.FlametongueWeapon, name = "Flametongue Weapon", required = false },
        },
        restoration = {
            { spell = A.HealingWave, name = "Healing Wave", required = true },
            { spell = A.LesserHealingWave, name = "Lesser Healing Wave", required = true },
            { spell = A.ChainHeal, name = "Chain Heal", required = false },
            { spell = A.EarthShield, name = "Earth Shield", required = false, note = "41pt Restoration talent" },
            { spell = A.NaturesSwiftness, name = "Nature's Swiftness", required = false, note = "21pt Restoration talent" },
            { spell = A.ManaTideTotem, name = "Mana Tide Totem", required = false, note = "31pt Restoration talent" },
        },
    },

    extend_context = function(ctx)
        local pu = Unit(PLAYER_UNIT)
        local tu = Unit(TARGET_UNIT)
        local moving = Player:IsMoving()
        ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
        ctx.is_mounted = Player:IsMounted()
        ctx.in_group = IsInGroup() or IsInRaid() or false

        -- Shield state
        ctx.has_water_shield = (pu:HasBuffs(Constants.BUFF_ID.WATER_SHIELD) or 0) > 0
        ctx.water_shield_charges = pu:HasBuffsStacks(Constants.BUFF_ID.WATER_SHIELD) or 0
        ctx.has_lightning_shield = (pu:HasBuffs(Constants.BUFF_ID.LIGHTNING_SHIELD) or 0) > 0

        -- Proc/buff state
        ctx.has_clearcasting = (pu:HasBuffs(Constants.BUFF_ID.ELEMENTAL_FOCUS) or 0) > 0
        ctx.clearcasting_charges = pu:HasBuffsStacks(Constants.BUFF_ID.ELEMENTAL_FOCUS) or 0
        ctx.has_elemental_mastery = (pu:HasBuffs(Constants.BUFF_ID.ELEMENTAL_MASTERY) or 0) > 0
        ctx.shamanistic_rage_active = (pu:HasBuffs(Constants.BUFF_ID.SHAMANISTIC_RAGE) or 0) > 0

        -- Target state
        ctx.flame_shock_duration = tu:HasDeBuffs(Constants.DEBUFF_ID.FLAME_SHOCK) or 0

        -- Multi-target
        local aoe_t = NS.cached_settings and NS.cached_settings.aoe_threshold
        ctx.enemy_count = (aoe_t and aoe_t > 0 and MultiUnits:GetByRangeInCombat(30)) or 1

        -- Totem state (refreshed per frame)
        refresh_totem_state()
        ctx.totem_fire_active = totem_state.fire_active
        ctx.totem_fire_remaining = totem_state.fire_remaining
        ctx.totem_fire_start = totem_state.fire_start
        ctx.totem_fire_is_fire_nova = totem_state.fire_is_fire_nova
        ctx.totem_earth_active = totem_state.earth_active
        ctx.totem_earth_remaining = totem_state.earth_remaining
        ctx.totem_water_active = totem_state.water_active
        ctx.totem_water_remaining = totem_state.water_remaining
        ctx.totem_air_active = totem_state.air_active
        ctx.totem_air_remaining = totem_state.air_remaining
        ctx.totem_air_start = totem_state.air_start
        ctx.totem_air_is_windfury = totem_state.air_is_windfury

        -- Fire Elemental protection: don't let rotation overwrite manually cast Fire Elemental
        ctx.fire_elemental_active = ctx.totem_fire_active and totem_state.fire_is_fire_elemental

        -- Cache invalidation flags for per-playstyle context_builders
        ctx._ele_valid = false
        ctx._enh_valid = false
        ctx._resto_valid = false
    end,

    dashboard = {
        resource = { type = "mana", label = "Mana" },
        cooldowns = {
            elemental = { A.ElementalMastery, A.FireElementalTotem, A.Trinket1, A.Trinket2 },
            enhancement = { A.ShamanisticRage, A.FireElementalTotem, A.Trinket1, A.Trinket2 },
            restoration = { A.NaturesSwiftness, A.ManaTideTotem, A.Trinket1, A.Trinket2 },
        },
        buffs = {
            elemental = {
                { id = Constants.BUFF_ID.ELEMENTAL_MASTERY, label = "EM" },
                { id = Constants.BUFF_ID.ELEMENTAL_FOCUS, label = "CC" },
            },
            enhancement = {
                { id = Constants.BUFF_ID.SHAMANISTIC_RAGE, label = "SR" },
                { id = Constants.BUFF_ID.FLURRY, label = "Flurry" },
            },
            restoration = {
                { id = Constants.BUFF_ID.NATURES_SWIFTNESS, label = "NS" },
                { id = Constants.BUFF_ID.WATER_SHIELD, label = "WS" },
            },
        },
        debuffs = {
            elemental = {
                { id = Constants.DEBUFF_ID.FLAME_SHOCK, label = "FS", target = true },
            },
            enhancement = {
                { id = Constants.DEBUFF_ID.STORMSTRIKE, label = "SS", target = true, show_stacks = true },
                { id = Constants.DEBUFF_ID.FLAME_SHOCK, label = "FS", target = true },
            },
        },
        swing_label = { enhancement = "Shoot" },

        -- Enhancement-only swing sync indicator. NS.swing_sync is populated
        -- by enhancement.lua's CLEU tracker; this line reads and renders it.
        -- Returns (nil, nil) outside enhancement / when no swing data yet,
        -- which tells the dashboard to hide the line.
        custom_lines = {
            function(ctx)
                if (ctx.settings.playstyle or "elemental") ~= "enhancement" then return nil, nil end
                local ss = NS.swing_sync
                if not ss then return nil, nil end
                local d = ss.delta
                if d == 0 then return nil, nil end  -- no data / out of combat

                local ms = math.floor(math.abs(d) * 1000)
                if d < 0 then
                    return "Sync", string.format("|cffff4040OH lead %dms|r", ms)
                elseif d < 0.5 then
                    return "Sync", string.format("|cff40ff40OK %dms|r", ms)
                else
                    return "Sync", string.format("|cffff8040Drift %dms|r", ms)
                end
            end,
        },
    },
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Shaman]|r Class module loaded")
