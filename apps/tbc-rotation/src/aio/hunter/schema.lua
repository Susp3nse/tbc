-- Hunter Settings Schema
-- Defines _G.Menagerie_SETTINGS_SCHEMA for Hunter class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end
local S = _G.Menagerie_SECTIONS

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

_G.Menagerie_SETTINGS_SCHEMA = {
    -- Tab 1: General
    [1] = { name = "General", sections = {
        S.immunity(),
        { header = "Targeting", settings = {
            { type = "checkbox", key = "mouseover", default = true, label = "Use @mouseover",
              tooltip = "Check mouseover target before current target." },
            { type = "checkbox", key = "aoe", default = true, label = "Enable AoE",
              tooltip = "Enable multi-target abilities (Multi-Shot, Explosive Trap)." },
        }},
        S.cooldowns(),
        S.recovery({
            header = "Recovery Items",
            healthstone_hp = 40,
            healing_potion_hp = 35,
            healing_potion_min = 0,
            healing_potion_max = 100,
            healing_potion_toggle_tooltip = "Use Healing Potion when HP drops low in combat.",
            healing_potion_tooltip = "Use Healing Potion when HP drops below this.",
        }),
        S.mana_recovery({
            dark_rune = true,
            dark_rune_pct = 20,
            dark_rune_min = 0,
            dark_rune_max = 100,
            dark_rune_toggle_label = "Use Mana Rune",
            dark_rune_toggle_tooltip = "Use Dark/Demonic Rune when mana is low.",
            dark_rune_label = "Mana Rune Mana (%)",
            dark_rune_tooltip = "Use Dark/Demonic Rune when mana drops below this.",
            dark_rune_min_hp = 50,
        }),
    }},

    -- Tab 2: Rotation
    [2] = { name = "Rotation", sections = {
        { header = "Adaptive Engine", settings = {
            { type = "checkbox", key = "inhouse_swingshot", default = false, label = "In-House SwingShot",
              tooltip = "Use Menagerie's own Auto Shot clock for Adaptive DPS. Falls back to Action's GetSwingShoot() while unsynced." },
            { type = "slider", key = "adaptive_exec_pad_ms", default = 100, min = 0, max = 250, label = "Adaptive Cast Pad (ms)",
              tooltip = "Safety time added to Adaptive's cast-vs-auto clip check. Raise if logs show borderline recommendations clipping; lower if Adaptive waits too much.", format = "%d ms" },
            { type = "slider_decimal", key = "weapon_speed", default = 2.9, min = 1.5, max = 4, precision = 1, label = "Weapon Speed (sec)",
              tooltip = "Your ranged weapon speed (e.g. 2.8, 2.9, 3.0). Used by Adaptive DPS for the haste multiplier. Set this to your unbuffed bow/gun/crossbow speed." },
        }},
        { header = "Arcane Shot", settings = {
            { type = "checkbox", key = "use_arcane", default = false, label = "Use Arcane Shot",
              tooltip = "Weave Arcane Shot into rotation (mana-intensive)." },
            { type = "slider", key = "arcane_shot_mana", default = 15, min = 0, max = 100, label = "Arcane Shot Min Mana (%)",
              tooltip = "Only use Arcane Shot above this mana %.", format = "%d%%" },
        }},
        { header = "Sting Selection (Priority Order)", settings = {
            { type = "checkbox", key = "use_serpent_sting", default = false, label = "Serpent Sting",
              tooltip = "Maintain Serpent Sting DoT. Highest sting priority." },
            { type = "checkbox", key = "use_scorpid_sting", default = false, label = "Scorpid Sting (Boss Only)",
              tooltip = "Apply Scorpid Sting on boss targets." },
            { type = "checkbox", key = "use_viper_sting_pve", default = false, label = "Viper Sting (PvE Mana Drain)",
              tooltip = "Apply Viper Sting on mana-using targets in PvE." },
        }},
        { header = "Hunter's Mark", settings = {
            { type = "checkbox", key = "static_mark", default = true, label = "Static Mark",
              tooltip = "Don't switch Hunter's Mark target until it expires." },
            { type = "checkbox", key = "boss_mark", default = false, label = "Boss Only Mark",
              tooltip = "Only apply Hunter's Mark on boss targets." },
            { type = "slider", key = "mark_refresh", default = 0, min = 0, max = 15, label = "Mark Refresh Lead (sec)",
              tooltip = "Re-cast Hunter's Mark this many seconds before it expires so the built-up attack power isn't lost when it drops. 0 = only re-apply after it fully falls off.", format = "%d sec" },
        }},
        { header = "Traps & Aggro", settings = {
            { type = "checkbox", key = "freezing_trap_pve", default = true, label = "Freezing Trap on Adds",
              tooltip = "Drop Freezing Trap when multiple enemies are on you." },
            { type = "checkbox", key = "protect_freeze", default = true, label = "Protect Frozen Target",
              tooltip = "Auto-switch target away from frozen enemies." },
            { type = "checkbox", key = "concussive_shot_pve", default = true, label = "Concussive Shot (PvE)",
              tooltip = "Use Concussive Shot to slow mobs running at you." },
            { type = "checkbox", key = "intimidation_pve", default = true, label = "Intimidation (PvE)",
              tooltip = "Use Intimidation stun on aggro swap." },
            { type = "checkbox", key = "use_feign_death", default = false, label = "Feign Death (Threat)",
              tooltip = "Auto Feign Death when you have aggro on your target." },
            { type = "checkbox", key = "use_wing_clip", default = true, label = "Wing Clip (Melee)",
              tooltip = "Auto-cast Wing Clip on melee targets. HP thresholds and bosses are still honored. Turn off to never auto-suggest Wing Clip." },
        }},
    }},

    -- Tab 3: Cooldowns
    [3] = { name = "Cooldowns", sections = {
        { header = "Burst Cooldowns", settings = {
            { type = "checkbox", key = "use_bestial_wrath", default = true, label = "Bestial Wrath",
              tooltip = "Use Bestial Wrath on cooldown during burst." },
            { type = "checkbox", key = "use_rapid_fire", default = true, label = "Rapid Fire",
              tooltip = "Use Rapid Fire on cooldown during burst." },
            { type = "checkbox", key = "use_readiness", default = true, label = "Readiness",
              tooltip = "Use Readiness to reset cooldowns." },
            { type = "checkbox", key = "use_racial", default = true, label = "Racial (Berserking/Blood Fury)",
              tooltip = "Use racial DPS cooldown during burst." },
        }},
        { header = "Trinkets", settings = {
            { type = "dropdown", key = "trinket1_mode", default = "off", label = "Trinket 1",
              tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
              options = {
                  { value = "off", text = "Off" },
                  { value = "offensive", text = "Offensive (Burst)" },
                  { value = "defensive", text = "Defensive" },
              }},
            { type = "dropdown", key = "trinket2_mode", default = "off", label = "Trinket 2",
              tooltip = "Off = never use. Offensive = fires during burst. Defensive = fires during def.",
              options = {
                  { value = "off", text = "Off" },
                  { value = "offensive", text = "Offensive (Burst)" },
                  { value = "defensive", text = "Defensive" },
              }},
        }},
        { header = "Burst Sync", settings = {
            { type = "checkbox", key = "auto_sync_cds", default = false, label = "Sync CDs with Bloodlust/Drums",
              tooltip = "Only pop burst CDs during Bloodlust, Heroism, or Drums." },
            { type = "checkbox", key = "use_haste_potion", default = false, label = "Use Haste Potion (Burst)",
              tooltip = "Use Haste Potion during burst phase instead of Healing Potion." },
        }},
        { header = "Readiness Target", settings = {
            { type = "checkbox", key = "readiness_rapid_fire", default = true, label = "Reset Rapid Fire",
              tooltip = "Use Readiness when Rapid Fire is on long cooldown." },
            { type = "checkbox", key = "readiness_misdirection", default = false, label = "Reset Misdirection",
              tooltip = "Use Readiness when Misdirection is on cooldown." },
        }},
        { header = "Aspect Management", settings = {
            { type = "checkbox", key = "aspect_hawk", default = true, label = "Aspect of the Hawk",
              tooltip = "Auto-switch to Hawk in combat." },
            { type = "checkbox", key = "aspect_cheetah", default = true, label = "Aspect of the Cheetah",
              tooltip = "Auto-switch to Cheetah out of combat." },
            { type = "checkbox", key = "aspect_viper", default = true, label = "Aspect of the Viper",
              tooltip = "Auto-switch to Viper when mana is low." },
        }},
        { header = "Mana Thresholds", settings = {
            { type = "slider", key = "mana_viper_start", default = 10, min = 0, max = 100, label = "Viper On Mana (%)",
              tooltip = "Switch to Viper when mana drops below this.", format = "%d%%" },
            { type = "slider", key = "mana_viper_end", default = 30, min = 0, max = 100, label = "Viper Off Mana (%)",
              tooltip = "Switch off Viper when mana rises above this.", format = "%d%%" },
            { type = "slider", key = "mana_save", default = 30, min = 0, max = 100, label = "Mana Save (%)",
              tooltip = "Don't spend mana on expensive shots (Multi-Shot, Arcane Shot, Stings) below this %. Steady Shot always fires.", format = "%d%%" },
        }},
    }},

    -- Tab 4: PvP
    [4] = { name = "PvP", sections = {
        { header = "Viper Sting Targets", settings = {
            { type = "checkbox", key = "viper_sting_priest", default = true, label = "Priest",
              tooltip = "Use Viper Sting on Priests." },
            { type = "checkbox", key = "viper_sting_paladin", default = true, label = "Paladin",
              tooltip = "Use Viper Sting on Paladins." },
            { type = "checkbox", key = "viper_sting_shaman", default = true, label = "Shaman",
              tooltip = "Use Viper Sting on Shamans." },
            { type = "checkbox", key = "viper_sting_druid", default = true, label = "Druid",
              tooltip = "Use Viper Sting on Druids." },
        }},
        { header = "Viper Sting Targets (cont.)", settings = {
            { type = "checkbox", key = "viper_sting_mage", default = true, label = "Mage",
              tooltip = "Use Viper Sting on Mages." },
            { type = "checkbox", key = "viper_sting_warlock", default = true, label = "Warlock",
              tooltip = "Use Viper Sting on Warlocks." },
            { type = "checkbox", key = "viper_sting_hunter", default = false, label = "Hunter",
              tooltip = "Use Viper Sting on Hunters (not recommended, they use Viper too)." },
        }},
        { header = "Viper Sting Threshold", settings = {
            { type = "slider", key = "viper_sting_hp_threshold", default = 30, min = 0, max = 100, label = "Skip Below HP (%)",
              tooltip = "Skip Viper Sting if target HP below this (focus damage instead).", format = "%d%%" },
        }},
        { header = "Wing Clip Priority", settings = {
            { type = "slider", key = "wing_clip_hp_pvp", default = 20, min = 0, max = 100, label = "Wing Clip PvP HP (%)",
              tooltip = "PvP: Use Wing Clip if target HP >= this.", format = "%d%%" },
            { type = "slider", key = "wing_clip_hp_pve", default = 20, min = 0, max = 100, label = "Wing Clip PvE HP (%)",
              tooltip = "PvE: Use Wing Clip if target HP >= this.", format = "%d%%" },
        }},
    }},

    -- Tab 5: Pet & Diagnostics
    [5] = { name = "Pet & Diag", sections = {
        { header = "Pet Care", settings = {
            { type = "slider", key = "mend_pet_hp", default = 30, min = 0, max = 100, label = "Mend Pet HP (%)",
              tooltip = "Heal pet when HP drops below this.", format = "%d%%" },
            { type = "checkbox", key = "experimental_pet", default = false, label = "Experimental Pet Controller",
              tooltip = "Auto pet-attack controller (experimental)." },
        }},
        { header = "Auto Shot Clip Tracker", settings = {
            { type = "checkbox", key = "clip_tracker_enabled", default = false, label = "Enable Clip Tracker",
              tooltip = "Track auto shot clipping events." },
            { type = "checkbox", key = "show_clip_tracker", default = false, label = "Show Clip Tracker UI",
              tooltip = "Show/hide the clip tracker window." },
            { type = "checkbox", key = "clip_print_summary", default = true, label = "Print Combat Summary",
              tooltip = "Print clip summary to chat after combat." },
        }},
        { header = "Clip Severity Thresholds (ms)", settings = {
            { type = "slider", key = "clip_threshold_1", default = 150, min = 0, max = 1000, label = "Green/Yellow (ms)",
              tooltip = "Clips below this are Green (trivial). Above = Yellow.", format = "%d ms" },
            { type = "slider", key = "clip_threshold_2", default = 250, min = 0, max = 1000, label = "Yellow/Orange (ms)",
              tooltip = "Clips above this are Orange (significant).", format = "%d ms" },
            { type = "slider", key = "clip_threshold_3", default = 500, min = 0, max = 2000, label = "Orange/Red (ms)",
              tooltip = "Clips above this are Red (severe).", format = "%d ms" },
        }},
        { header = "Melee Weave Coach", settings = {
            { type = "checkbox", key = "show_melee_weave_coach", default = false, label = "Show Melee Weave Coach",
              tooltip = "Show a read-only traffic-light timer for manual Raptor Strike melee weaving." },
            { type = "slider", key = "weave_round_trip_ms", default = 900, min = 300, max = 2200, label = "Round Trip Budget (ms)",
              tooltip = "Estimated time to enter melee, queue/land Raptor, and return to ranged distance. Lower for large hitboxes.", format = "%d ms" },
            { type = "slider", key = "weave_exit_buffer_ms", default = 300, min = 0, max = 1000, label = "Exit Safety Buffer (ms)",
              tooltip = "Extra time reserved before ranged Auto Shot windup begins. Raise this if orange/red feels late.", format = "%d ms" },
        }},
        { header = "Debug Panel", settings = {
            { type = "checkbox", key = "show_adaptive_panel", default = false, label = "Show Adaptive Engine Panel",
              tooltip = "Live view of adaptive's per-tick scores, derived stats, and recent fires." },
        }},
    }},
}

print("|cFF00FF00[Menagerie]|r Hunter schema loaded")
