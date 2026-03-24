-- Paladin Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Paladin class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PALADIN" then return end
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
            { type = "dropdown", key = "playstyle", default = "retribution", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "retribution", text = "Retribution" },
                  { value = "protection", text = "Protection" },
                  { value = "holy", text = "Holy" },
              }},
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_cleanse", default = true, label = "Auto Cleanse",
              tooltip = "Automatically Cleanse poison, disease, and magic (if talented) from yourself." },
            { type = "checkbox", key = "use_hammer_of_justice", default = false, label = "Hammer of Justice",
              tooltip = "Use Hammer of Justice to interrupt enemy casts (stun, may break CC)." },
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
        { header = "Emergency", settings = {
            { type = "slider", key = "divine_shield_hp", default = 0, min = 0, max = 40, label = "Divine Shield HP (%)",
              tooltip = "Use Divine Shield when HP drops below this. Set to 0 to disable. Blocked by Forbearance.", format = "%d%%" },
            { type = "slider", key = "lay_on_hands_hp", default = 0, min = 0, max = 40, label = "Lay on Hands HP (%)",
              tooltip = "Use Lay on Hands when HP drops below this. Set to 0 to disable. Drains all mana. Blocked by Forbearance.", format = "%d%%" },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Retribution
    [2] = { name = "Retribution", sections = {
        { header = "Seal Twisting", settings = {
            { type = "checkbox", key = "ret_seal_twist", default = true, label = "Seal Twist",
              tooltip = "Enable Command -> Blood seal twisting for max DPS. Requires swing timer. Disable for simpler rotation." },
        }},
        { header = "Abilities", settings = {
            { type = "checkbox", key = "ret_use_crusader_strike", default = true, label = "Crusader Strike",
              tooltip = "Use Crusader Strike on cooldown (6s CD, 41-pt Ret talent)." },
            { type = "checkbox", key = "ret_use_judgement", default = true, label = "Auto Judgement",
              tooltip = "Automatically Judge off cooldown (off-GCD in TBC)." },
            { type = "dropdown", key = "ret_judge_seal", default = "blood", label = "Judge Seal",
              tooltip = "Which seal debuff to apply when Judging.",
              options = {
                  { value = "blood", text = "Blood (Damage)" },
                  { value = "crusader", text = "Crusader (+3% Crit)" },
                  { value = "wisdom", text = "Wisdom (Mana)" },
                  { value = "light", text = "Light (Healing)" },
              }},
        }},
        { header = "Execute & Fillers", settings = {
            { type = "checkbox", key = "ret_use_hammer_of_wrath", default = true, label = "Hammer of Wrath",
              tooltip = "Use Hammer of Wrath on targets below 20% HP (6s CD, 30yd range)." },
            { type = "checkbox", key = "ret_use_exorcism", default = true, label = "Exorcism",
              tooltip = "Use Exorcism on Undead/Demon targets (only when mana > 40%)." },
            { type = "checkbox", key = "ret_use_consecration", default = false, label = "Consecration",
              tooltip = "Use Consecration as filler (heavy mana cost, only when mana > 60%). Off by default." },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "ret_aoe_threshold", default = 0, min = 0, max = 8, label = "AoE Threshold",
              tooltip = "Min enemies for Consecration auto-use. Set to 0 to disable auto-AoE.", format = "%d" },
        }},
    }},

    -- Tab 3: Protection
    [3] = { name = "Protection", sections = {
        { header = "Core", settings = {
            { type = "checkbox", key = "prot_use_holy_shield", default = true, label = "Holy Shield",
              tooltip = "Maintain 100% Holy Shield uptime (crushing blow prevention)." },
            { type = "checkbox", key = "prot_prioritize_holy_shield", default = true, label = "Prioritize Holy Shield",
              tooltip = "Cast Holy Shield before Consecration in the priority (recommended for boss tanking)." },
            { type = "checkbox", key = "prot_use_consecration", default = true, label = "Consecration",
              tooltip = "Use Consecration on cooldown for threat." },
            { type = "checkbox", key = "prot_use_judgement", default = true, label = "Auto Judgement",
              tooltip = "Judge off cooldown for threat (off-GCD)." },
        }},
        { header = "Seal & Judgement", settings = {
            { type = "dropdown", key = "prot_seal_choice", default = "righteousness", label = "Seal Choice",
              tooltip = "Primary seal for tanking.",
              options = {
                  { value = "righteousness", text = "Righteousness (Flat)" },
                  { value = "vengeance", text = "Vengeance (Stacking)" },
                  { value = "wisdom", text = "Wisdom (Mana)" },
              }},
        }},
        { header = "Abilities", settings = {
            { type = "checkbox", key = "prot_use_avengers_shield", default = true, label = "Avenger's Shield",
              tooltip = "Use Avenger's Shield for pull/snap threat (41-pt Prot talent)." },
            { type = "checkbox", key = "prot_use_exorcism", default = true, label = "Exorcism",
              tooltip = "Use Exorcism on Undead/Demon targets (only when mana > 40%)." },
            { type = "checkbox", key = "prot_use_hammer_of_wrath", default = true, label = "Hammer of Wrath",
              tooltip = "Use Hammer of Wrath on targets below 20% HP." },
        }},
        { header = "Taunts", settings = {
            { type = "checkbox", key = "prot_no_taunt", default = false, label = "Disable Taunts (Off-Tank)",
              tooltip = "Disables Righteous Defense. Use when off-tanking." },
            { type = "checkbox", key = "prot_use_righteous_defense", default = true, label = "Auto Taunt",
              tooltip = "Auto-taunt elite/boss enemies off friendly targets with Righteous Defense. Only fires on elites/bosses, skips CC'd and dying mobs." },
        }},
        { header = "Threat Tab Targeting", settings = {
            { type = "checkbox", key = "use_auto_tab", default = true, label = "Auto Tab Target",
              tooltip = "Automatically switch targets to pick up loose mobs and spread threat. Scans nameplates by threat level: picks up loose mobs first, stabilizes insecure threat, then equalizes across secure mobs." },
            { type = "slider", key = "prot_tab_max_mobs", default = 4, min = 1, max = 8, label = "Max Mobs to Manage",
              tooltip = "Max simultaneous mobs to actively tank. Won't pick up new mobs beyond this count unless they are completely loose (threat 0-1).", format = "%d" },
            { type = "dropdown", key = "prot_tab_min_priority", default = "all", label = "Tab Target Priority",
              tooltip = "Which mob types to tab-target. 'All' tabs to any mob, 'Elites+' only tabs to elites and bosses, 'Bosses' only tabs to bosses.",
              options = {
                  { value = "all", text = "All Mobs" },
                  { value = "elites", text = "Elites+" },
                  { value = "bosses", text = "Bosses Only" },
              }},
        }},
    }},

    -- Tab 4: Holy
    [4] = { name = "Holy", sections = {
        { header = "Healing Thresholds", settings = {
            { type = "slider", key = "holy_holy_light_hp", default = 90, min = 50, max = 100, label = "Holy Light HP (%)",
              tooltip = "Use Holy Light when target below this HP%. Primary heal — spam this.", format = "%d%%" },
            { type = "slider", key = "holy_flash_of_light_hp", default = 95, min = 70, max = 100, label = "Flash of Light HP (%)",
              tooltip = "Use Flash of Light when target below this HP%. Light damage filler when HL would overheal.", format = "%d%%" },
            { type = "checkbox", key = "holy_use_holy_shock", default = true, label = "Holy Shock",
              tooltip = "Use Holy Shock as instant heal (21s CD, 41-pt Holy talent)." },
            { type = "slider", key = "holy_holy_shock_hp", default = 50, min = 20, max = 80, label = "Holy Shock HP (%)",
              tooltip = "Use Holy Shock instant heal when target below this HP%.", format = "%d%%" },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "holy_use_divine_favor", default = true, label = "Divine Favor",
              tooltip = "Use Divine Favor for guaranteed crit heal (2 min CD)." },
            { type = "checkbox", key = "holy_use_divine_illumination", default = true, label = "Divine Illumination",
              tooltip = "Use Divine Illumination for -50% mana cost (3 min CD, 41-pt Holy talent)." },
            { type = "slider", key = "holy_divine_illumination_pct", default = 60, min = 30, max = 80, label = "DI Mana Threshold (%)",
              tooltip = "Use Divine Illumination when mana drops below this percent.", format = "%d%%" },
        }},
        { header = "Utility", settings = {
            { type = "dropdown", key = "holy_seal_choice", default = "wisdom", label = "Seal Choice",
              tooltip = "Which seal to maintain. None = don't cast any seal.",
              options = {
                  { value = "wisdom", text = "Seal of Wisdom" },
                  { value = "light", text = "Seal of Light" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "holy_judge_debuff", default = "light", label = "Judge Debuff",
              tooltip = "Which Judgement debuff to maintain on the boss when safe. Requires a seal active.",
              options = {
                  { value = "light", text = "Light (Healing)" },
                  { value = "wisdom", text = "Wisdom (Mana)" },
                  { value = "none", text = "None" },
              }},
            { type = "checkbox", key = "holy_use_cleanse", default = true, label = "Auto Cleanse Party",
              tooltip = "Automatically Cleanse debuffs from party members." },
        }},
    }},

    -- Tab 5: Cooldowns & Mana
    [5] = { name = "CDs & Mana", sections = {
        { header = "Offensive Cooldowns", settings = {
            { type = "checkbox", key = "use_avenging_wrath", default = true, label = "Avenging Wrath",
              tooltip = "Use Avenging Wrath on cooldown (+30% damage, 20s). Note: causes Forbearance." },
        }},
        S.trinkets("Use racial ability (Stoneform, Gift of the Naaru, etc.) during combat."),
        { header = "Mana Recovery", settings = {
            { type = "checkbox", key = "use_mana_potion", default = true, label = "Use Mana Potion",
              tooltip = "Auto-use Super Mana Potion for mana recovery." },
            { type = "slider", key = "mana_potion_pct", default = 40, min = 10, max = 80, label = "Mana Potion Below%",
              tooltip = "Use Mana Potion when mana drops below this.", format = "%d%%" },
            { type = "checkbox", key = "use_dark_rune", default = true, label = "Use Dark Rune",
              tooltip = "Auto-use Dark/Demonic Rune for mana (costs HP)." },
            { type = "slider", key = "dark_rune_pct", default = 40, min = 10, max = 80, label = "Dark Rune Below%",
              tooltip = "Use Dark Rune when mana drops below this.", format = "%d%%" },
            { type = "slider", key = "dark_rune_min_hp", default = 50, min = 25, max = 75, label = "Dark Rune Min HP (%)",
              tooltip = "Only use Dark Rune when HP is above this (it costs HP).", format = "%d%%" },
            { type = "checkbox", key = "use_seal_of_wisdom_low_mana", default = false, label = "Seal of Wisdom (Low Mana)",
              tooltip = "Auto-switch to Seal of Wisdom when mana is low for mana regen." },
            { type = "slider", key = "seal_of_wisdom_mana_pct", default = 20, min = 5, max = 50, label = "Seal of Wisdom Below%",
              tooltip = "Switch to Seal of Wisdom when mana drops below this.", format = "%d%%" },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Paladin schema loaded")
