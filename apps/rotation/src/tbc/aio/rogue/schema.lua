-- Rogue Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Rogue class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "ROGUE" then return end
local S = _G.FluxAIO_SECTIONS

-- Enable this profile
A.Data.ProfileEnabled[A.CurrentProfile] = true

-- ============================================================================
-- SETTINGS SCHEMA (Single Source of Truth)
-- ============================================================================
-- All setting metadata lives here. Used by:
--   1. aio/ui.lua: generates A.Data.ProfileUI[2] (framework backing store)
--   2. aio/settings.lua: renders the custom tabbed Settings UI
--   3. aio/core.lua: refresh_settings() iterates to build cached_settings
--
-- Keys are snake_case -- the same string used everywhere:
--   GetToggle(2, key), SetToggle({2, key, ...}), cached_settings[key], context.settings[key]

_G.FluxAIO_SETTINGS_SCHEMA = {
    -- Tab 1: General
    [1] = { name = "General", sections = {
        { header = "Spec Selection", settings = {
            { type = "dropdown", key = "playstyle", default = "combat", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "combat", text = "Combat" },
                  { value = "assassination", text = "Assassination" },
                  { value = "subtlety", text = "Subtlety" },
              }},
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_kick", default = true, label = "Auto Kick",
              tooltip = "Interrupt enemy casts with Kick." },
            { type = "checkbox", key = "use_feint", default = false, label = "Auto Feint",
              tooltip = "Use Feint when tanking the target (threat reduction)." },
            { type = "checkbox", key = "use_expose_armor", default = false, label = "Expose Armor",
              tooltip = "Use Expose Armor at 5 CP (disable if warrior provides Sunder)." },
            { type = "checkbox", key = "use_shiv", default = true, label = "Use Shiv",
              tooltip = "Use Shiv to refresh Deadly Poison when < 2s remaining." },
        }},
        { header = "Stealth Opener", settings = {
            { type = "dropdown", key = "opener", default = "garrote", label = "Opener",
              tooltip = "Spell to use when opening from stealth.",
              options = {
                  { value = "garrote", text = "Garrote" },
                  { value = "cheap_shot", text = "Cheap Shot" },
                  { value = "ambush", text = "Ambush" },
                  { value = "none", text = "None" },
              }},
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Recovery Items", settings = {
            { type = "slider", key = "healthstone_hp", default = 35, min = 0, max = 100,
              label = "Healthstone HP (%)", tooltip = "Use Healthstone below this HP%. 0 = disable.", format = "%d%%" },
            { type = "checkbox", key = "use_healing_potion", default = true, label = "Use Healing Potion",
              tooltip = "Use Healing Potion when HP drops low in combat." },
            { type = "slider", key = "healing_potion_hp", default = 25, min = 10, max = 50,
              label = "Healing Potion HP (%)", tooltip = "Use Healing Potion below this HP%.", format = "%d%%" },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Combat
    [2] = { name = "Combat", sections = {
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "combat_use_blade_flurry", default = true, label = "Use Blade Flurry",
              tooltip = "Use Blade Flurry on cooldown (Combat talent)." },
            { type = "checkbox", key = "combat_use_adrenaline_rush", default = true, label = "Use Adrenaline Rush",
              tooltip = "Use Adrenaline Rush on cooldown (Combat talent)." },
        }},
        { header = "Finishers", settings = {
            { type = "checkbox", key = "combat_use_rupture", default = true, label = "Use Rupture",
              tooltip = "Maintain Rupture DoT on target." },
            { type = "slider", key = "combat_rupture_min_ttd", default = 12, min = 6, max = 30,
              label = "Rupture Min TTD (sec)", tooltip = "Only use Rupture if target will live this long.", format = "%d sec" },
            { type = "slider", key = "combat_snd_refresh", default = 2, min = 1, max = 5,
              label = "SnD Refresh (sec)", tooltip = "Refresh Slice and Dice when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "combat_rupture_refresh", default = 2, min = 1, max = 5,
              label = "Rupture Refresh (sec)", tooltip = "Refresh Rupture when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "combat_min_cp_finisher", default = 5, min = 3, max = 5,
              label = "Min CP for Finisher", tooltip = "Minimum combo points before using Eviscerate.", format = "%d" },
        }},
    }},

    -- Tab 3: Assassination
    [3] = { name = "Assassination", sections = {
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "assassination_use_cold_blood", default = true, label = "Use Cold Blood",
              tooltip = "Use Cold Blood with finishers (guaranteed crit)." },
        }},
        { header = "Envenom", settings = {
            { type = "checkbox", key = "assassination_use_envenom", default = true, label = "Use Envenom",
              tooltip = "Use Envenom (consumes Deadly Poison stacks). Disable for Rupture>Evis only." },
            { type = "slider", key = "assassination_envenom_min_stacks", default = 2, min = 1, max = 5,
              label = "Envenom Min DP Stacks", tooltip = "Minimum Deadly Poison stacks before Envenom.", format = "%d" },
        }},
        { header = "Finishers", settings = {
            { type = "checkbox", key = "assassination_use_rupture", default = true, label = "Use Rupture",
              tooltip = "Maintain Rupture DoT on target." },
            { type = "slider", key = "assassination_rupture_min_ttd", default = 12, min = 6, max = 30,
              label = "Rupture Min TTD (sec)", tooltip = "Only use Rupture if target will live this long.", format = "%d sec" },
            { type = "slider", key = "assassination_snd_refresh", default = 2, min = 1, max = 5,
              label = "SnD Refresh (sec)", tooltip = "Refresh Slice and Dice when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "assassination_rupture_refresh", default = 2, min = 1, max = 5,
              label = "Rupture Refresh (sec)", tooltip = "Refresh Rupture when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "assassination_min_cp_finisher", default = 4, min = 3, max = 5,
              label = "Min CP for Finisher", tooltip = "Minimum combo points before using a finisher.", format = "%d" },
        }},
    }},

    -- Tab 4: Subtlety
    [4] = { name = "Subtlety", sections = {
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "subtlety_use_shadowstep", default = true, label = "Use Shadowstep",
              tooltip = "Use Shadowstep on cooldown for +20% damage buff (Subtlety 41pt talent)." },
            { type = "checkbox", key = "subtlety_use_preparation", default = true, label = "Use Preparation",
              tooltip = "Use Preparation to reset Shadowstep, Vanish, Evasion cooldowns." },
            { type = "checkbox", key = "subtlety_use_ghostly_strike", default = true, label = "Use Ghostly Strike",
              tooltip = "Use Ghostly Strike as a secondary builder on cooldown (Subtlety talent). Grants +15% dodge for 7s." },
        }},
        { header = "Finishers", settings = {
            { type = "checkbox", key = "subtlety_use_rupture", default = true, label = "Use Rupture",
              tooltip = "Maintain Rupture DoT on target." },
            { type = "slider", key = "subtlety_rupture_min_ttd", default = 12, min = 6, max = 30,
              label = "Rupture Min TTD (sec)", tooltip = "Only use Rupture if target will live this long.", format = "%d sec" },
            { type = "slider", key = "subtlety_snd_refresh", default = 2, min = 1, max = 5,
              label = "SnD Refresh (sec)", tooltip = "Refresh Slice and Dice when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "subtlety_rupture_refresh", default = 2, min = 1, max = 5,
              label = "Rupture Refresh (sec)", tooltip = "Refresh Rupture when this many seconds remain.", format = "%d sec" },
            { type = "slider", key = "subtlety_min_cp_finisher", default = 5, min = 3, max = 5,
              label = "Min CP for Finisher", tooltip = "Minimum combo points before using Eviscerate.", format = "%d" },
        }},
    }},

    -- Tab 5: CDs & Defense
    [5] = { name = "CDs & Defense", sections = {
        S.trinkets("Use racial ability (Blood Fury, Berserking, Arcane Torrent) on cooldown."),
        { header = "Energy Recovery", settings = {
            { type = "checkbox", key = "use_thistle_tea", default = true, label = "Use Thistle Tea",
              tooltip = "Auto-use Thistle Tea for +100 energy." },
            { type = "slider", key = "thistle_tea_energy", default = 40, min = 10, max = 80,
              label = "Thistle Tea Below Energy", tooltip = "Use Thistle Tea when energy drops below this.", format = "%d" },
            { type = "checkbox", key = "use_haste_potion", default = true, label = "Use Haste Potion",
              tooltip = "Auto-use Haste Potion (best during Blade Flurry + Adrenaline Rush window)." },
        }},
        { header = "Defensive", settings = {
            { type = "checkbox", key = "use_evasion", default = false, label = "Auto Evasion",
              tooltip = "Use Evasion when HP drops below threshold." },
            { type = "slider", key = "evasion_hp", default = 40, min = 0, max = 75,
              label = "Evasion HP (%)", tooltip = "Use Evasion below this HP%. 0 = disable.", format = "%d%%" },
            { type = "checkbox", key = "use_cloak_of_shadows", default = true, label = "Auto Cloak of Shadows",
              tooltip = "Use Cloak of Shadows to remove magic debuffs." },
            { type = "slider", key = "cloak_hp", default = 50, min = 0, max = 75,
              label = "Cloak HP (%)", tooltip = "Use Cloak below this HP% when magic debuffed. 0 = disable.", format = "%d%%" },
            { type = "checkbox", key = "use_vanish_emergency", default = false, label = "Emergency Vanish",
              tooltip = "Use Vanish as last-resort escape at critically low HP." },
            { type = "slider", key = "vanish_hp", default = 10, min = 0, max = 30,
              label = "Vanish Emergency HP (%)", tooltip = "Use Vanish below this HP%. 0 = disable.", format = "%d%%" },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Rogue schema loaded")
