-- Mage Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Mage class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "MAGE" then return end
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
            { type = "dropdown", key = "playstyle", default = "fire", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "fire", text = "Fire" },
                  { value = "frost", text = "Frost" },
                  { value = "arcane", text = "Arcane" },
              }},
        }},
        { header = "Armor", settings = {
            { type = "dropdown", key = "armor_type", default = "auto", label = "Armor Selection",
              tooltip = "Which armor spell to maintain. Auto = Molten Armor for all specs (best PvE).",
              options = {
                  { value = "auto", text = "Auto (Molten)" },
                  { value = "molten", text = "Molten Armor" },
                  { value = "mage", text = "Mage Armor" },
                  { value = "ice", text = "Ice Armor" },
              }},
        }},
        { header = "Self-Buffs", settings = {
            { type = "checkbox", key = "use_arcane_intellect", default = true, label = "Arcane Intellect",
              tooltip = "Auto-buff Arcane Intellect (or Brilliance if grouped) out of combat." },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "aoe_threshold", default = 0, min = 0, max = 8, label = "AoE Threshold",
              tooltip = "Minimum enemies to switch to AoE rotation. Set to 0 to disable.", format = "%d" },
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_counterspell", default = true, label = "Auto Counterspell",
              tooltip = "Automatically interrupt enemy casts with Counterspell." },
            { type = "checkbox", key = "auto_remove_curse", default = true, label = "Auto Remove Curse",
              tooltip = "Automatically Remove Curse on yourself." },
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
            { type = "slider", key = "ice_block_hp", default = 15, min = 0, max = 40, label = "Ice Block HP (%)",
              tooltip = "Use Ice Block when HP drops below this. Set to 0 to disable.", format = "%d%%" },
            { type = "slider", key = "mana_shield_hp", default = 0, min = 0, max = 40, label = "Mana Shield HP (%)",
              tooltip = "Use Mana Shield when HP drops below this. Set to 0 to disable.", format = "%d%%" },
            { type = "checkbox", key = "use_ice_barrier", default = false, label = "Use Ice Barrier",
              tooltip = "Maintain Ice Barrier absorb shield in combat (requires Frost talent)." },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Fire
    [2] = { name = "Fire", sections = {
        { header = "Improved Scorch", settings = {
            { type = "checkbox", key = "fire_maintain_scorch", default = true, label = "Maintain Imp. Scorch",
              tooltip = "Keep 5 stacks of Improved Scorch (Fire Vulnerability) on the target." },
            { type = "slider", key = "fire_scorch_refresh", default = 6, min = 3, max = 10, label = "Scorch Refresh (sec)",
              tooltip = "Refresh Scorch debuff when remaining duration is below this.", format = "%d sec" },
        }},
        { header = "Primary Spell", settings = {
            { type = "dropdown", key = "fire_primary_spell", default = "fireball", label = "Primary Spell",
              tooltip = "Main filler spell between Scorch refreshes.",
              options = {
                  { value = "fireball", text = "Fireball" },
                  { value = "scorch", text = "Scorch" },
              }},
        }},
        { header = "Abilities", settings = {
            { type = "checkbox", key = "fire_weave_fire_blast", default = true, label = "Weave Fire Blast",
              tooltip = "Use Fire Blast between casts when off cooldown." },
            { type = "checkbox", key = "fire_use_blast_wave", default = true, label = "Use Blast Wave",
              tooltip = "Use Blast Wave on cooldown (requires Fire talent)." },
            { type = "checkbox", key = "fire_use_dragons_breath", default = false, label = "Use Dragon's Breath",
              tooltip = "Use Dragon's Breath on cooldown (requires Fire talent, may break CC)." },
            { type = "slider", key = "fire_melee_aoe_min_enemies", default = 2, min = 1, max = 5, label = "Melee AoE Min Enemies",
              tooltip = "Minimum melee-range enemies for Blast Wave / Dragon's Breath.", format = "%d" },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "fire_use_combustion", default = true, label = "Use Combustion",
              tooltip = "Use Combustion cooldown." },
            { type = "slider", key = "fire_combustion_below_hp", default = 25, min = 0, max = 100, label = "Combustion Target HP%",
              tooltip = "Save Combustion for when target HP is below this. Set to 0 to use on CD.", format = "%d%%" },
            { type = "checkbox", key = "fire_use_icy_veins", default = true, label = "Use Icy Veins",
              tooltip = "Use Icy Veins on cooldown (cross-tree Frost talent)." },
        }},
        { header = "Movement", settings = {
            { type = "checkbox", key = "fire_move_fire_blast", default = true, label = "Fire Blast",
              tooltip = "Use Fire Blast while moving." },
            { type = "checkbox", key = "fire_move_ice_lance", default = false, label = "Ice Lance",
              tooltip = "Use Ice Lance while moving." },
            { type = "checkbox", key = "fire_move_cone_of_cold", default = false, label = "Cone of Cold",
              tooltip = "Use Cone of Cold while moving." },
            { type = "checkbox", key = "fire_move_arcane_explosion", default = true, label = "Arcane Explosion",
              tooltip = "Use Arcane Explosion while moving (melee range)." },
        }},
    }},

    -- Tab 3: Frost
    [3] = { name = "Frost", sections = {
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "frost_use_icy_veins", default = true, label = "Use Icy Veins",
              tooltip = "Use Icy Veins on cooldown." },
            { type = "checkbox", key = "frost_use_cold_snap", default = true, label = "Use Cold Snap",
              tooltip = "Use Cold Snap to reset Icy Veins and Water Elemental cooldowns." },
            { type = "checkbox", key = "frost_use_water_elemental", default = true, label = "Summon Water Elemental",
              tooltip = "Summon Water Elemental on cooldown (requires 41pt Frost talent)." },
        }},
        { header = "Movement", settings = {
            { type = "checkbox", key = "frost_move_fire_blast", default = true, label = "Fire Blast",
              tooltip = "Use Fire Blast while moving." },
            { type = "checkbox", key = "frost_move_ice_lance", default = true, label = "Ice Lance",
              tooltip = "Use Ice Lance while moving." },
            { type = "checkbox", key = "frost_move_cone_of_cold", default = false, label = "Cone of Cold",
              tooltip = "Use Cone of Cold while moving." },
            { type = "checkbox", key = "frost_move_arcane_explosion", default = true, label = "Arcane Explosion",
              tooltip = "Use Arcane Explosion while moving (melee range)." },
        }},
    }},

    -- Tab 4: Arcane
    [4] = { name = "Arcane", sections = {
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "arcane_use_arcane_power", default = true, label = "Use Arcane Power",
              tooltip = "Use Arcane Power during burn phase." },
            { type = "checkbox", key = "arcane_use_pom", default = true, label = "Use Presence of Mind",
              tooltip = "Use Presence of Mind for instant Arcane Blast." },
            { type = "checkbox", key = "arcane_use_icy_veins", default = true, label = "Use Icy Veins",
              tooltip = "Use Icy Veins on cooldown (cross-tree talent)." },
            { type = "checkbox", key = "arcane_use_cold_snap", default = true, label = "Use Cold Snap",
              tooltip = "Use Cold Snap to reset Icy Veins cooldown." },
        }},
        { header = "Rotation", settings = {
            { type = "dropdown", key = "arcane_filler", default = "frostbolt", label = "Filler Spell",
              tooltip = "Spell to cast during conserve phase while Arcane Blast stacks drop.",
              options = {
                  { value = "frostbolt", text = "Frostbolt" },
                  { value = "fireball", text = "Fireball" },
                  { value = "arcane_missiles", text = "Arcane Missiles" },
                  { value = "scorch", text = "Scorch" },
              }},
            { type = "slider", key = "arcane_blasts_between_fillers", default = 3, min = 1, max = 4, label = "AB Stacks Before Filler",
              tooltip = "Number of Arcane Blasts to cast before switching to filler in conserve phase.", format = "%d" },
        }},
        { header = "Movement", settings = {
            { type = "checkbox", key = "arcane_move_fire_blast", default = true, label = "Fire Blast",
              tooltip = "Use Fire Blast while moving." },
            { type = "checkbox", key = "arcane_move_ice_lance", default = false, label = "Ice Lance",
              tooltip = "Use Ice Lance while moving." },
            { type = "checkbox", key = "arcane_move_cone_of_cold", default = false, label = "Cone of Cold",
              tooltip = "Use Cone of Cold while moving." },
            { type = "checkbox", key = "arcane_move_arcane_explosion", default = true, label = "Arcane Explosion",
              tooltip = "Use Arcane Explosion while moving (melee range)." },
        }},
        { header = "Mana Phases", settings = {
            { type = "slider", key = "arcane_start_conserve_pct", default = 35, min = 10, max = 80, label = "Start Conserve Mana%",
              tooltip = "Enter conserve phase when mana drops below this.", format = "%d%%" },
            { type = "slider", key = "arcane_stop_conserve_pct", default = 60, min = 20, max = 90, label = "Stop Conserve Mana%",
              tooltip = "Exit conserve phase when mana rises above this.", format = "%d%%" },
        }},
    }},

    -- Tab 5: Cooldowns & Mana
    [5] = { name = "CDs & Mana", sections = {
        S.trinkets("Use racial ability (Berserking, Arcane Torrent, etc.) during burst."),
        { header = "Mana Recovery", settings = {
            { type = "checkbox", key = "use_mana_gem", default = true, label = "Use Mana Gem",
              tooltip = "Auto-use Mana Emerald for mana recovery." },
            { type = "slider", key = "mana_gem_pct", default = 70, min = 20, max = 90, label = "Mana Gem Below%",
              tooltip = "Use Mana Gem when mana drops below this.", format = "%d%%" },
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
        { header = "Evocation", settings = {
            { type = "checkbox", key = "use_evocation", default = true, label = "Use Evocation",
              tooltip = "Auto-use Evocation when mana is critically low." },
            { type = "slider", key = "evocation_pct", default = 20, min = 5, max = 40, label = "Evocation Below%",
              tooltip = "Use Evocation when mana drops below this.", format = "%d%%" },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Mage schema loaded")
