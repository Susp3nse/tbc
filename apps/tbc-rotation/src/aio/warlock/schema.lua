-- Warlock Settings Schema
-- Defines _G.Menagerie_SETTINGS_SCHEMA for Warlock class
-- Must load before profileui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARLOCK" then return end
local S = _G.Menagerie_SECTIONS

-- Enable this profile
A.Data.ProfileEnabled[A.CurrentProfile] = true

-- ============================================================================
-- SETTINGS SCHEMA (Single Source of Truth)
-- ============================================================================
-- All setting metadata lives here. Used by:
--   1. aio/profileui.lua: generates A.Data.ProfileUI[2] (framework backing store)
--   2. aio/settings.lua: renders the custom tabbed Settings UI
--   3. aio/core.lua: refresh_settings() iterates to build cached_settings
--
-- Keys are snake_case -- the same string used everywhere:
--   GetToggle(2, key), SetToggle({2, key, ...}), cached_settings[key], context.settings[key]

_G.Menagerie_SETTINGS_SCHEMA = {
    -- Tab 1: General
    [1] = { name = "General", sections = {
        S.immunity(),
        S.spec({ default = "affliction", options = {
            { value = "affliction", text = "Affliction" },
            { value = "demonology", text = "Demonology" },
            { value = "destruction", text = "Destruction" },
        }}),
        { header = "Curse Assignment", settings = {
            { type = "dropdown", key = "curse_type", default = "elements", label = "Curse",
              tooltip = "Which curse to maintain on the target.",
              options = {
                  { value = "elements", text = "Curse of Elements" },
                  { value = "agony", text = "Curse of Agony" },
                  { value = "doom", text = "Curse of Doom" },
                  { value = "recklessness", text = "Curse of Recklessness" },
                  { value = "tongues", text = "Curse of Tongues" },
                  { value = "none", text = "None" },
              }},
        }},
        { header = "Self-Buffs", settings = {
            { type = "checkbox", key = "use_fel_armor", default = true, label = "Fel Armor",
              tooltip = "Auto-buff Fel Armor (+100 spell damage) out of combat." },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "aoe_threshold", default = 0, min = 0, max = 8, label = "AoE Threshold",
              tooltip = "Minimum enemies to switch to AoE rotation (Seed of Corruption). Set to 0 to disable.", format = "%d" },
        }},
        S.cooldowns(),
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_soulshatter", default = true, label = "Auto Soulshatter",
              tooltip = "Use Soulshatter when threat is high (costs 1 Soul Shard)." },
        }},
        S.recovery({
            header = "Recovery Items",
            healthstone_hp = 35,
            healing_potion_hp = 25,
            healing_potion_min = 10,
            healing_potion_max = 50,
            healing_potion_toggle_tooltip = "Use Healing Potion when HP drops low in combat.",
            healing_potion_tooltip = "Use Healing Potion when HP drops below this.",
        }),
        { header = "Emergency", settings = {
            { type = "slider", key = "death_coil_hp", default = 20, min = 0, max = 50, label = "Death Coil HP (%)",
              tooltip = "Use Death Coil when HP drops below this (3s Horror + self-heal). Set to 0 to disable.", format = "%d%%" },
        }},
    }},

    -- Tab 2: Affliction
    [2] = { name = "Affliction", sections = {
        { header = "DoTs", settings = {
            { type = "checkbox", key = "aff_use_corruption", default = true, label = "Use Corruption",
              tooltip = "Maintain Corruption DoT on the target." },
            { type = "checkbox", key = "aff_use_ua", default = true, label = "Use Unstable Affliction",
              tooltip = "Maintain Unstable Affliction DoT (requires 41pt Affliction talent)." },
            { type = "checkbox", key = "aff_use_siphon_life", default = true, label = "Use Siphon Life",
              tooltip = "Maintain Siphon Life DoT (only when ISB debuff is active on target)." },
            { type = "checkbox", key = "aff_use_immolate", default = false, label = "Use Immolate",
              tooltip = "Maintain Immolate DoT (some builds skip this)." },
        }},
        { header = "Procs & Execute", settings = {
            { type = "checkbox", key = "aff_use_shadow_trance", default = true, label = "Use Shadow Trance",
              tooltip = "Cast instant Shadow Bolt when Nightfall procs." },
            { type = "checkbox", key = "aff_use_drain_soul", default = true, label = "Drain Soul Execute",
              tooltip = "Use Drain Soul below target HP threshold (Soul Siphon bonus)." },
            { type = "slider", key = "aff_drain_soul_hp", default = 25, min = 10, max = 50, label = "Drain Soul HP%",
              tooltip = "Switch to Drain Soul when target HP drops below this.", format = "%d%%" },
        }},
        { header = "Amplify Curse", settings = {
            { type = "checkbox", key = "aff_use_amplify_curse", default = true, label = "Use Amplify Curse",
              tooltip = "Auto-use Amplify Curse before Curse of Doom/Agony (requires Affliction talent)." },
        }},
    }},

    -- Tab 3: Demonology
    [3] = { name = "Demonology", sections = {
        { header = "DoTs", settings = {
            { type = "checkbox", key = "demo_use_corruption", default = true, label = "Use Corruption",
              tooltip = "Maintain Corruption DoT on the target." },
            { type = "checkbox", key = "demo_use_immolate", default = false, label = "Use Immolate",
              tooltip = "Maintain Immolate DoT on the target." },
        }},
        { header = "Pet Management", settings = {
            { type = "slider", key = "demo_pet_heal_hp", default = 40, min = 10, max = 70, label = "Pet Heal HP%",
              tooltip = "Use Health Funnel when pet HP drops below this.", format = "%d%%" },
            { type = "checkbox", key = "demo_use_fel_domination", default = true, label = "Use Fel Domination",
              tooltip = "Use Fel Domination for instant pet resummon if pet dies (requires Demo talent)." },
            { type = "checkbox", key = "demo_use_soul_link", default = true, label = "Use Soul Link",
              tooltip = "Maintain Soul Link buff (shares 20%% damage with pet, requires Demo talent)." },
        }},
        { header = "Demonic Sacrifice", settings = {
            { type = "checkbox", key = "demo_use_sacrifice", default = false, label = "Use Demonic Sacrifice",
              tooltip = "Sacrifice pet for damage buff (DS/Ruin build). Disables pet management." },
            { type = "dropdown", key = "demo_sacrifice_pet", default = "succubus", label = "Sacrifice Pet",
              tooltip = "Which pet to sacrifice for the buff.",
              options = {
                  { value = "succubus", text = "Succubus (+15% shadow)" },
                  { value = "imp", text = "Imp (+15% fire)" },
              }},
        }},
    }},

    -- Tab 4: Destruction
    [4] = { name = "Destruction", sections = {
        { header = "Primary Spell", settings = {
            { type = "dropdown", key = "destro_primary_spell", default = "shadow_bolt", label = "Primary Spell",
              tooltip = "Main filler spell for Destruction.",
              options = {
                  { value = "shadow_bolt", text = "Shadow Bolt" },
                  { value = "incinerate", text = "Incinerate" },
              }},
        }},
        { header = "Abilities", settings = {
            { type = "checkbox", key = "destro_use_immolate", default = true, label = "Use Immolate",
              tooltip = "Maintain Immolate (required for Incinerate +25% damage bonus)." },
            { type = "checkbox", key = "destro_use_conflagrate", default = true, label = "Use Conflagrate",
              tooltip = "Use Conflagrate on CD (consumes Immolate, requires Destro talent)." },
            { type = "checkbox", key = "destro_use_shadowburn", default = true, label = "Use Shadowburn",
              tooltip = "Use Shadowburn as execute (instant, costs 1 Soul Shard)." },
            { type = "slider", key = "destro_shadowburn_hp", default = 10, min = 5, max = 25, label = "Shadowburn HP%",
              tooltip = "Use Shadowburn when target HP drops below this.", format = "%d%%" },
            { type = "checkbox", key = "destro_use_shadowfury", default = true, label = "Use Shadowfury",
              tooltip = "Use Shadowfury on CD (AoE stun, requires 41pt Destro talent)." },
            { type = "checkbox", key = "destro_use_backlash", default = true, label = "Use Backlash",
              tooltip = "Cast instant Shadow Bolt/Incinerate on Backlash proc." },
        }},
    }},

    -- Tab 5: CDs & Mana
    [5] = { name = "CDs & Mana", sections = {
        S.trinkets("Use racial ability (Blood Fury, Arcane Torrent, etc.) during combat."),
        { header = "Life Tap & Dark Pact", settings = {
            { type = "slider", key = "life_tap_mana_pct", default = 30, min = 10, max = 60, label = "Life Tap Mana%",
              tooltip = "Use Life Tap when mana drops below this.", format = "%d%%" },
            { type = "slider", key = "life_tap_min_hp", default = 40, min = 20, max = 70, label = "Life Tap Min HP%",
              tooltip = "Don't Life Tap when HP is below this (safety threshold).", format = "%d%%" },
            { type = "checkbox", key = "use_dark_pact", default = true, label = "Use Dark Pact",
              tooltip = "Prefer Dark Pact over Life Tap for mana (drains pet mana, requires the talent). Works in any spec." },
        }},
        S.mana_recovery({
            mana_potion = true,
            mana_potion_pct = 30,
            mana_potion_min = 10,
            mana_potion_max = 80,
            mana_potion_toggle_tooltip = "Auto-use Super Mana Potion for mana recovery.",
            mana_potion_tooltip = "Use Mana Potion when mana drops below this.",
            dark_rune = true,
            dark_rune_pct = 30,
            dark_rune_min = 10,
            dark_rune_max = 80,
            dark_rune_toggle_tooltip = "Auto-use Dark/Demonic Rune for mana (costs HP).",
            dark_rune_tooltip = "Use Dark Rune when mana drops below this.",
            dark_rune_min_hp = 50,
            dark_rune_min_hp_min = 25,
            dark_rune_min_hp_max = 75,
            dark_rune_min_hp_tooltip = "Only use Dark Rune when HP is above this (it costs HP).",
        }),
    }},
}

print("|cFF00FF00[Menagerie]|r Warlock schema loaded")
