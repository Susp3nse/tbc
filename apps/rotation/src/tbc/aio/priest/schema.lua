-- Priest Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Priest class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end
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
            { type = "dropdown", key = "playstyle", default = "shadow", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "shadow", text = "Shadow" },
                  { value = "smite", text = "Smite" },
                  { value = "holy", text = "Holy" },
                  { value = "discipline", text = "Discipline" },
              }},
        }},
        { header = "Self-Buffs", settings = {
            { type = "checkbox", key = "use_inner_fire", default = true, label = "Inner Fire",
              tooltip = "Maintain Inner Fire buff out of combat." },
            { type = "checkbox", key = "use_fortitude", default = true, label = "PW: Fortitude",
              tooltip = "Maintain Power Word: Fortitude buff out of combat." },
            { type = "checkbox", key = "use_divine_spirit", default = true, label = "Divine Spirit",
              tooltip = "Maintain Divine Spirit buff out of combat (if talented)." },
            { type = "checkbox", key = "use_shadow_protection", default = false, label = "Shadow Protection",
              tooltip = "Maintain Shadow Protection buff out of combat." },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_fear_ward", default = true, label = "Fear Ward",
              tooltip = "Maintain Fear Ward on focus/self." },
            { type = "checkbox", key = "auto_dispel_magic", default = true, label = "Dispel Magic",
              tooltip = "Auto-dispel magic debuffs on party members." },
            { type = "checkbox", key = "auto_abolish_disease", default = true, label = "Abolish Disease",
              tooltip = "Auto-cleanse diseases on party members." },
            { type = "checkbox", key = "use_fade", default = true, label = "Auto Fade",
              tooltip = "Use Fade when pulling healing threat." },
            { type = "checkbox", key = "fade_group_only", default = true, label = "Fade Group Only",
              tooltip = "Only use Fade when in a party or raid (solo Fade is pointless)." },
            { type = "slider", key = "fade_min_bosses", default = 1, min = 1, max = 3, label = "Fade Boss Count",
              tooltip = "Fade if this many bosses are targeting you.", format = "%d" },
            { type = "slider", key = "fade_min_elites", default = 1, min = 1, max = 5, label = "Fade Elite Count",
              tooltip = "Fade if this many elites are targeting you.", format = "%d" },
            { type = "slider", key = "fade_min_trash", default = 3, min = 1, max = 10, label = "Fade Trash Count",
              tooltip = "Fade if this many trash mobs are targeting you.", format = "%d" },
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Recovery Items", settings = {
            { type = "slider", key = "healthstone_hp", default = 35, min = 0, max = 100, label = "Healthstone HP (%)",
              tooltip = "Use Healthstone when HP drops below this. Set to 0 to disable.", format = "%d%%" },
            { type = "checkbox", key = "use_healing_potion", default = true, label = "Use Healing Potion",
              tooltip = "Use Healing Potion when HP drops low in combat." },
            { type = "slider", key = "healing_potion_hp", default = 25, min = 10, max = 50, label = "Healing Potion HP (%)",
              tooltip = "Use Healing Potion when HP drops below this.", format = "%d%%" },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Shadow
    [2] = { name = "Shadow", sections = {
        { header = "Core Rotation", settings = {
            { type = "checkbox", key = "shadow_ve_maintain", default = false, label = "Maintain VE",
              tooltip = "Auto-maintain Vampiric Embrace debuff on target." },
            { type = "checkbox", key = "shadow_use_inner_focus", default = true, label = "Use Inner Focus",
              tooltip = "Use Inner Focus before Mind Blast when available." },
        }},
        { header = "Shadow Word: Death", settings = {
            { type = "checkbox", key = "shadow_use_swd", default = true, label = "Shadow Word: Death",
              tooltip = "Use SW:D on cooldown (self-damage risk)." },
            { type = "slider", key = "shadow_swd_hp", default = 40, min = 20, max = 80, label = "SW:D Min HP%",
              tooltip = "Minimum player HP% to use Shadow Word: Death.", format = "%d%%" },
        }},
        { header = "Racials", settings = {
            { type = "checkbox", key = "shadow_use_devouring_plague", default = true, label = "Devouring Plague",
              tooltip = "Use Devouring Plague if Undead (off cooldown)." },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "shadow_aoe_count", default = 4, min = 2, max = 8, label = "AoE Target Count",
              tooltip = "Spread DoTs on multiple targets when this many enemies in combat.", format = "%d" },
            { type = "checkbox", key = "shadow_dot_spread", default = true, label = "Enable DoT Spreading",
              tooltip = "Spread SW:P and VT to nearby enemies during AoE." },
            { type = "slider", key = "shadow_swp_spread_max", default = 8, min = 1, max = 15, label = "Max SW:P Targets",
              tooltip = "Maximum number of enemies to spread SW:P on.", format = "%d" },
            { type = "slider", key = "shadow_vt_spread_max", default = 5, min = 1, max = 15, label = "Max VT Targets",
              tooltip = "Maximum number of enemies to spread VT on.", format = "%d" },
        }},
        { header = "Execute Phase", settings = {
            { type = "slider", key = "shadow_execute_ttd", default = 10, min = 5, max = 15, label = "Execute TTD (sec)",
              tooltip = "Skip DoTs when target dies within this many seconds. Uses MB > SW:D > MF only.", format = "%d sec" },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "shadow_use_silence", default = true, label = "Auto Silence",
              tooltip = "Interrupt enemy casts with Silence (if talented)." },
        }},
    }},

    -- Tab 3: Smite
    [3] = { name = "Smite", sections = {
        { header = "Core Rotation", settings = {
            { type = "checkbox", key = "smite_holy_fire_weave", default = true, label = "Holy Fire Weave",
              tooltip = "Weave Holy Fire based on SW:P timing window for optimal DPS." },
        }},
        { header = "Optional Spells", settings = {
            { type = "checkbox", key = "smite_use_mb", default = false, label = "Use Mind Blast",
              tooltip = "Include Mind Blast in rotation (optional)." },
            { type = "checkbox", key = "smite_use_swd", default = false, label = "Use SW:D",
              tooltip = "Include Shadow Word: Death in rotation (optional)." },
            { type = "slider", key = "smite_swd_hp", default = 40, min = 20, max = 80, label = "SW:D Min HP%",
              tooltip = "Minimum player HP% to use Shadow Word: Death.", format = "%d%%" },
        }},
        { header = "Racials", settings = {
            { type = "checkbox", key = "smite_use_starshards", default = true, label = "Use Starshards",
              tooltip = "Use Starshards if Night Elf (off cooldown)." },
            { type = "checkbox", key = "smite_use_devouring_plague", default = true, label = "Devouring Plague",
              tooltip = "Use Devouring Plague if Undead (off cooldown)." },
        }},
    }},

    -- Tab 4: Holy
    [4] = { name = "Holy", sections = {
        { header = "Healing Thresholds", settings = {
            { type = "slider", key = "holy_emergency_hp", default = 30, min = 10, max = 60, label = "Emergency HP%",
              tooltip = "Flash Heal spam below this HP%.", format = "%d%%" },
            { type = "slider", key = "holy_flash_heal_hp", default = 50, min = 20, max = 80, label = "Flash Heal HP%",
              tooltip = "Flash Heal below this%, Greater Heal above.", format = "%d%%" },
            { type = "slider", key = "holy_renew_hp", default = 90, min = 50, max = 100, label = "Renew HP%",
              tooltip = "Apply Renew when target below this%.", format = "%d%%" },
        }},
        { header = "AoE Healing", settings = {
            { type = "slider", key = "holy_aoe_hp", default = 80, min = 40, max = 100, label = "AoE Heal HP%",
              tooltip = "AoE heals when members below this%.", format = "%d%%" },
            { type = "slider", key = "holy_aoe_count", default = 3, min = 2, max = 5, label = "AoE Heal Count",
              tooltip = "Minimum damaged members for AoE heal.", format = "%d" },
        }},
        { header = "Emergency", settings = {
            { type = "checkbox", key = "holy_use_pws", default = true, label = "PW:S Emergency",
              tooltip = "Use Power Word: Shield on critically low targets (no Weakened Soul)." },
            { type = "slider", key = "holy_pws_hp", default = 30, min = 15, max = 50, label = "PW:S HP%",
              tooltip = "Apply PW:S below this HP%.", format = "%d%%" },
        }},
        { header = "Abilities", settings = {
            { type = "checkbox", key = "holy_use_coh", default = true, label = "Circle of Healing",
              tooltip = "Use CoH on CD during group damage (if talented)." },
            { type = "checkbox", key = "holy_use_binding_heal", default = true, label = "Binding Heal",
              tooltip = "Use Binding Heal when self + target damaged." },
            { type = "slider", key = "holy_binding_self_hp", default = 80, min = 40, max = 95, label = "Binding Self HP%",
              tooltip = "Use Binding Heal when self HP below this%.", format = "%d%%" },
            { type = "checkbox", key = "holy_use_poh", default = true, label = "Prayer of Healing",
              tooltip = "Use Prayer of Healing for group damage." },
            { type = "checkbox", key = "holy_use_inner_focus", default = true, label = "Inner Focus",
              tooltip = "Use Inner Focus before Greater Heal for free cast + 25% crit." },
        }},
        { header = "Pre-Pull & Idle", settings = {
            { type = "checkbox", key = "holy_prepull_pom", default = true, label = "Pre-Pull PoM",
              tooltip = "Cast Prayer of Mending on tank before pull. Disable if PoM bounce generates unwanted threat." },
            { type = "checkbox", key = "holy_prepull_renew", default = true, label = "Pre-Pull Renew",
              tooltip = "Cast Renew on tank before pull (between pulls)." },
            { type = "checkbox", key = "holy_dps_when_idle", default = false, label = "DPS When Idle",
              tooltip = "Cast damage spells when everyone is healthy and mana is above floor." },
            { type = "slider", key = "holy_dps_mana_floor", default = 70, min = 40, max = 90, label = "DPS Mana Floor%",
              tooltip = "Only DPS when mana above this%.", format = "%d%%" },
        }},
    }},

    -- Tab 5: Discipline
    [5] = { name = "Discipline", sections = {
        { header = "Healing Thresholds", settings = {
            { type = "slider", key = "disc_emergency_hp", default = 25, min = 10, max = 50, label = "Emergency HP%",
              tooltip = "Emergency heal below this HP%.", format = "%d%%" },
            { type = "slider", key = "disc_flash_heal_hp", default = 50, min = 20, max = 80, label = "Flash Heal HP%",
              tooltip = "Flash Heal below this%, Greater Heal above.", format = "%d%%" },
        }},
        { header = "Power Word: Shield", settings = {
            { type = "slider", key = "disc_shield_hp", default = 90, min = 50, max = 100, label = "Shield HP%",
              tooltip = "Apply PW:S when target below this%.", format = "%d%%" },
            { type = "checkbox", key = "disc_shield_tank_only", default = false, label = "Shield Tank Only",
              tooltip = "Only PW:S the tank." },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "disc_use_pain_suppression", default = true, label = "Pain Suppression",
              tooltip = "Use Pain Suppression on critical tank (if talented)." },
            { type = "slider", key = "disc_pain_suppression_hp", default = 20, min = 10, max = 40, label = "Pain Suppression HP%",
              tooltip = "Use Pain Suppression below this HP%.", format = "%d%%" },
            { type = "checkbox", key = "disc_use_power_infusion", default = true, label = "Power Infusion",
              tooltip = "Use Power Infusion (if talented)." },
            { type = "checkbox", key = "disc_use_inner_focus", default = true, label = "Inner Focus",
              tooltip = "Use Inner Focus with Greater Heal." },
        }},
        { header = "HoTs", settings = {
            { type = "slider", key = "disc_renew_hp", default = 85, min = 50, max = 100, label = "Renew HP%",
              tooltip = "Apply Renew below this%.", format = "%d%%" },
        }},
        { header = "AoE Healing", settings = {
            { type = "slider", key = "disc_aoe_count", default = 3, min = 2, max = 5, label = "PoH Min Count",
              tooltip = "Minimum injured group members to use Prayer of Healing.", format = "%d" },
        }},
        { header = "Pre-Pull", settings = {
            { type = "checkbox", key = "disc_prepull_shield", default = true, label = "Pre-Pull PW:S",
              tooltip = "Cast PW:S on tank before pull (between pulls)." },
            { type = "checkbox", key = "disc_prepull_renew", default = true, label = "Pre-Pull Renew",
              tooltip = "Cast Renew on tank before pull (between pulls)." },
        }},
    }},

    -- Tab 6: Cooldowns & Mana
    [6] = { name = "CDs & Mana", sections = {
        S.trinkets("Use racial ability (Berserking, Arcane Torrent, etc.)."),
        { header = "Mana Recovery", settings = {
            { type = "checkbox", key = "use_shadowfiend", default = true, label = "Use Shadowfiend",
              tooltip = "Auto-use Shadowfiend for mana recovery." },
            { type = "slider", key = "shadowfiend_pct", default = 50, min = 20, max = 80, label = "Shadowfiend Mana%",
              tooltip = "Use when mana below this%.", format = "%d%%" },
            { type = "checkbox", key = "use_mana_potion", default = true, label = "Use Mana Potion",
              tooltip = "Auto-use Super Mana Potion for mana recovery." },
            { type = "slider", key = "mana_potion_pct", default = 50, min = 10, max = 80, label = "Mana Potion Below%",
              tooltip = "Use Mana Potion when mana drops below this.", format = "%d%%" },
        }},
        { header = "Mana Recovery (cont.)", settings = {
            { type = "checkbox", key = "use_dark_rune", default = true, label = "Use Dark Rune",
              tooltip = "Auto-use Dark/Demonic Rune for mana (costs HP)." },
            { type = "slider", key = "dark_rune_pct", default = 50, min = 10, max = 80, label = "Dark Rune Below%",
              tooltip = "Use Dark Rune when mana drops below this.", format = "%d%%" },
            { type = "slider", key = "dark_rune_min_hp", default = 50, min = 25, max = 75, label = "Dark Rune Min HP (%)",
              tooltip = "Only use Dark Rune when HP is above this (it costs HP).", format = "%d%%" },
        }},
        { header = "Emergency", settings = {
            { type = "checkbox", key = "use_desperate_prayer", default = true, label = "Desperate Prayer",
              tooltip = "Use Desperate Prayer racial self-heal when HP low." },
            { type = "slider", key = "desperate_prayer_hp", default = 30, min = 10, max = 50, label = "Desperate Prayer HP%",
              tooltip = "Use Desperate Prayer below this HP%.", format = "%d%%" },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Priest schema loaded")
