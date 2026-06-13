-- Shaman Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Shaman class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "SHAMAN" then return end
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
            { type = "dropdown", key = "playstyle", default = "elemental", label = "Active Spec",
              tooltip = "Which spec rotation to use.",
              options = {
                  { value = "elemental", text = "Elemental" },
                  { value = "enhancement", text = "Enhancement" },
                  { value = "restoration", text = "Restoration" },
              }},
        }},
        { header = "Shield", settings = {
            { type = "dropdown", key = "shield_type", default = "auto", label = "Shield Type",
              tooltip = "Shield to maintain. Auto = Water Shield for Ele/Resto, Lightning Shield for Enh.",
              options = {
                  { value = "auto", text = "Auto (per spec)" },
                  { value = "water", text = "Water Shield" },
                  { value = "lightning", text = "Lightning Shield" },
              }},
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "aoe_threshold", default = 0, min = 0, max = 8, label = "AoE Threshold",
              tooltip = "Minimum enemies to switch to AoE rotation. Set to 0 to disable.", format = "%d" },
        }},
        { header = "Totem Conditions", settings = {
            { type = "dropdown", key = "totem_fire_condition", default = "always", label = "Fire Totem",
              tooltip = "When to auto-drop fire totems. 'Only in Group' skips fire totems when solo questing.",
              options = {
                  { value = "always", text = "Always Cast" },
                  { value = "group_only", text = "Only in Group" },
              }},
            { type = "dropdown", key = "totem_earth_condition", default = "always", label = "Earth Totem",
              tooltip = "When to auto-drop earth totems. 'Only in Group' skips earth totems when solo questing.",
              options = {
                  { value = "always", text = "Always Cast" },
                  { value = "group_only", text = "Only in Group" },
              }},
            { type = "dropdown", key = "totem_water_condition", default = "always", label = "Water Totem",
              tooltip = "When to auto-drop water totems. 'Only in Group' skips water totems when solo questing.",
              options = {
                  { value = "always", text = "Always Cast" },
                  { value = "group_only", text = "Only in Group" },
              }},
            { type = "dropdown", key = "totem_air_condition", default = "always", label = "Air Totem",
              tooltip = "When to auto-drop air totems. 'Only in Group' skips air totems when solo questing.",
              options = {
                  { value = "always", text = "Always Cast" },
                  { value = "group_only", text = "Only in Group" },
              }},
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, SR, Fire Ele, racial, totems) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_interrupt", default = true, label = "Auto Interrupt",
              tooltip = "Earth Shock interrupt (TBC has no Wind Shear)." },
            { type = "checkbox", key = "interrupt_rank1", default = true, label = "Interrupt Rank 1",
              tooltip = "Use Rank 1 Earth Shock for interrupt to save mana." },
            { type = "checkbox", key = "use_priority_interrupt", default = true, label = "Priority Interrupt (Scan)",
              tooltip = "Scan nearby nameplates (20yd) for dangerous casts and tab-target to interrupt them, then return to your original target. Requires Auto Interrupt enabled." },
            { type = "checkbox", key = "use_cure_poison", default = false, label = "Auto Cure Poison",
              tooltip = "Remove poison from yourself." },
            { type = "checkbox", key = "use_cure_disease", default = false, label = "Auto Cure Disease",
              tooltip = "Remove disease from yourself." },
            { type = "checkbox", key = "use_purge", default = false, label = "Auto Purge",
              tooltip = "Remove magic buffs from enemy target." },
            { type = "checkbox", key = "use_auto_tremor", default = true, label = "Auto Tremor Totem",
              tooltip = "Auto-drop Tremor Totem when fighting bosses/mobs that cast Fear, Charm, or Sleep." },
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

    -- Tab 2: Elemental
    [2] = { name = "Elemental", sections = {
        { header = "Rotation", settings = {
            { type = "dropdown", key = "ele_rotation_type", default = "cl_clearcast", label = "Rotation Type",
              tooltip = "Controls when Chain Lightning is used. CL on Clearcast is most mana-efficient.",
              options = {
                  { value = "cl_clearcast", text = "CL on Clearcast" },
                  { value = "cl_on_cd", text = "CL on Cooldown" },
                  { value = "fixed_ratio", text = "Fixed LB:CL Ratio" },
                  { value = "lb_only", text = "LB Only" },
              }},
            { type = "slider", key = "ele_fixed_lb_per_cl", default = 3, min = 1, max = 6, label = "LBs per CL",
              tooltip = "For Fixed Ratio mode: cast this many Lightning Bolts between each Chain Lightning.", format = "%d" },
        }},
        { header = "Shocks", settings = {
            { type = "checkbox", key = "ele_use_flame_shock", default = true, label = "Use Flame Shock",
              tooltip = "Maintain Flame Shock DoT on target." },
            { type = "checkbox", key = "ele_use_earth_shock", default = true, label = "Use Earth Shock",
              tooltip = "Earth Shock as filler shock when Flame Shock DoT is active." },
            { type = "checkbox", key = "ele_shock_interrupt_only", default = false, label = "Hold Shocks (Interrupts Only)",
              tooltip = "Suppress all rotation shocks so they're only fired by the interrupt middleware on enemy casts. Good for dungeons where you want shocks reserved for kicks. Overrides Flame/Earth Shock toggles." },
        }},
        { header = "Mana Conservation", settings = {
            { type = "slider", key = "ele_mana_stop_shocks", default = 30, min = 0, max = 100, label = "Stop Shocks Mana%",
              tooltip = "Don't use shocks when mana drops below this. 0 = disabled (always use shocks).", format = "%d%%" },
            { type = "slider", key = "ele_fs_min_ttd", default = 12, min = 0, max = 30, label = "Flame Shock Min TTD",
              tooltip = "Don't apply Flame Shock if target dies in fewer seconds than this. 0 = disabled.", format = "%d sec" },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "ele_use_elemental_mastery", default = true, label = "Use Elemental Mastery",
              tooltip = "Use Elemental Mastery on cooldown (guaranteed crit next spell)." },
            { type = "checkbox", key = "ele_em_hold_for_cl", default = true, label = "Hold EM for Chain Lightning",
              tooltip = "Pair Elemental Mastery with Chain Lightning for a guaranteed-crit CL. When disabled, EM fires on cooldown regardless of next spell." },
            { type = "checkbox", key = "ele_use_fire_elemental", default = false, label = "Use Fire Elemental",
              tooltip = "Summon Fire Elemental on long fights (20 min CD)." },
        }},
        { header = "Totems", settings = {
            { type = "dropdown", key = "ele_fire_totem", default = "totem_of_wrath", label = "Fire Totem",
              tooltip = "Default fire totem.",
              options = {
                  { value = "totem_of_wrath", text = "Totem of Wrath" },
                  { value = "searing", text = "Searing Totem" },
                  { value = "magma", text = "Magma Totem" },
                  { value = "flametongue", text = "Flametongue Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "ele_earth_totem", default = "strength_of_earth", label = "Earth Totem",
              tooltip = "Default earth totem. Tremor cancels Fear/Sleep/Charm — useful in fear-heavy fights.",
              options = {
                  { value = "strength_of_earth", text = "Strength of Earth" },
                  { value = "stoneskin", text = "Stoneskin Totem" },
                  { value = "tremor", text = "Tremor Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "ele_water_totem", default = "mana_spring", label = "Water Totem",
              tooltip = "Default water totem.",
              options = {
                  { value = "mana_spring", text = "Mana Spring" },
                  { value = "healing_stream", text = "Healing Stream" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "ele_air_totem", default = "wrath_of_air", label = "Air Totem",
              tooltip = "Default air totem. Grounding absorbs the next hostile spell — useful in caster-heavy fights.",
              options = {
                  { value = "wrath_of_air", text = "Wrath of Air" },
                  { value = "windfury", text = "Windfury" },
                  { value = "tranquil_air", text = "Tranquil Air" },
                  { value = "grounding", text = "Grounding Totem" },
                  { value = "none", text = "None" },
              }},
        }},
    }},

    -- Tab 3: Enhancement
    [3] = { name = "Enhancement", sections = {
        { header = "Swing Sync", settings = {
            { type = "checkbox", key = "enh_auto_resync", default = false, label = "Auto Swing Resync",
              tooltip = "EXPERIMENTAL. Auto-fires the resync macro (/cleartarget + /targetlasttarget + /startattack) when MH/OH stagger drifts outside the Flurry 0.5s window. Convergence works but visual fire rate during drift can be noisy (3-8 fires per drift episode before settling). Sync state is shown on the combat dashboard regardless of this toggle — many players prefer to leave this OFF and press the macro manually when they see the dashboard go red. Logic source: enhanceshaman.com/pages/guide/sync_stagger" },
        }},
        { header = "Rotation", settings = {
            { type = "checkbox", key = "enh_use_stormstrike", default = true, label = "Use Stormstrike",
              tooltip = "Stormstrike on cooldown (10s CD, applies +20%% nature dmg debuff)." },
            { type = "dropdown", key = "enh_primary_shock", default = "earth_shock", label = "Primary Shock",
              tooltip = "Primary shock spell between Flame Shock DoT refreshes.",
              options = {
                  { value = "earth_shock", text = "Earth Shock" },
                  { value = "frost_shock", text = "Frost Shock" },
                  { value = "none", text = "None" },
              }},
            { type = "checkbox", key = "enh_weave_flame_shock", default = true, label = "Weave Flame Shock",
              tooltip = "Maintain Flame Shock DoT between primary shock uses." },
        }},
        { header = "Mana Conservation", settings = {
            { type = "slider", key = "enh_mana_stop_shocks", default = 30, min = 0, max = 100, label = "Stop Shocks Mana%",
              tooltip = "Don't use shocks when mana drops below this. Bypassed when Shamanistic Rage is active or ready. 0 = disabled.", format = "%d%%" },
            { type = "slider", key = "enh_fs_min_ttd", default = 12, min = 0, max = 30, label = "Flame Shock Min TTD",
              tooltip = "Don't apply Flame Shock if target dies in fewer seconds than this. 0 = disabled.", format = "%d sec" },
            { type = "checkbox", key = "enh_shock_interrupt_only", default = false, label = "Hold Shocks (Interrupts Only)",
              tooltip = "Suppress all rotation shocks so they're only fired by the interrupt middleware on enemy casts. Good for dungeons where you want shocks reserved for kicks. Overrides Flame Shock weaving and primary shock choice." },
        }},
        { header = "Cooldowns", settings = {
            { type = "checkbox", key = "enh_use_shamanistic_rage", default = true, label = "Use Shamanistic Rage",
              tooltip = "Mana recovery + 30%% damage reduction (2 min CD)." },
            { type = "slider", key = "enh_shamanistic_rage_pct", default = 50, min = 10, max = 80, label = "SR Mana%",
              tooltip = "Use Shamanistic Rage when mana drops below this.", format = "%d%%" },
            { type = "checkbox", key = "enh_use_fire_elemental", default = false, label = "Use Fire Elemental",
              tooltip = "Summon Fire Elemental on long fights (20 min CD)." },
        }},
        { header = "Totem Twisting", settings = {
            { type = "checkbox", key = "enh_twist_windfury", default = false, label = "Twist Windfury",
              tooltip = "Cycle Windfury + Grace of Air totems to benefit from both buffs. Advanced technique." },
            { type = "checkbox", key = "enh_twist_fire_nova", default = false, label = "Twist Fire Nova",
              tooltip = "Cycle Fire Nova Totem with the Post-FNT totem (default Magma) for sustained AoE damage. Pattern: Nova → wait ~5s for explosion → Post-FNT totem → wait ~10s for Nova CD → repeat." },
            { type = "dropdown", key = "enh_fnt_post_totem", default = "magma", label = "Post-FNT Fire Totem",
              tooltip = "Fire totem to drop after Fire Nova explodes while waiting for FNT's 15s cooldown. Magma ticks AoE damage in the gap; Searing/Flametongue/Totem of Wrath are options for single-target downtime.",
              options = {
                  { value = "magma", text = "Magma Totem" },
                  { value = "searing", text = "Searing Totem" },
                  { value = "flametongue", text = "Flametongue Totem" },
                  { value = "totem_of_wrath", text = "Totem of Wrath" },
              }},
            { type = "dropdown", key = "enh_fnt_single_target", default = "boss", label = "FNT Single-Target",
              tooltip = "When below AoE threshold, still twist FNT on these targets.",
              options = {
                  { value = "off", text = "Off" },
                  { value = "boss", text = "Boss Only" },
                  { value = "elite", text = "Elite+" },
                  { value = "all", text = "Always" },
              }},
        }},
        { header = "Weapon Imbues", settings = {
            { type = "dropdown", key = "enh_mh_imbue", default = "windfury", label = "Main Hand",
              tooltip = "Weapon imbue for main hand.",
              options = {
                  { value = "windfury", text = "Windfury" },
                  { value = "flametongue", text = "Flametongue" },
              }},
            { type = "dropdown", key = "enh_oh_imbue", default = "flametongue", label = "Off Hand",
              tooltip = "Weapon imbue for off hand.",
              options = {
                  { value = "windfury", text = "Windfury" },
                  { value = "flametongue", text = "Flametongue" },
              }},
        }},
        { header = "Totems", settings = {
            { type = "dropdown", key = "enh_fire_totem", default = "searing", label = "Fire Totem",
              tooltip = "Default fire totem.",
              options = {
                  { value = "searing", text = "Searing Totem" },
                  { value = "magma", text = "Magma Totem" },
                  { value = "flametongue", text = "Flametongue Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "enh_earth_totem", default = "strength_of_earth", label = "Earth Totem",
              tooltip = "Default earth totem. Tremor cancels Fear/Sleep/Charm — useful in fear-heavy fights.",
              options = {
                  { value = "strength_of_earth", text = "Strength of Earth" },
                  { value = "stoneskin", text = "Stoneskin Totem" },
                  { value = "tremor", text = "Tremor Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "enh_water_totem", default = "mana_spring", label = "Water Totem",
              tooltip = "Default water totem.",
              options = {
                  { value = "mana_spring", text = "Mana Spring" },
                  { value = "healing_stream", text = "Healing Stream" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "enh_air_totem", default = "windfury", label = "Air Totem",
              tooltip = "Default air totem (used when not twisting). Grounding absorbs the next hostile spell — useful in caster-heavy fights.",
              options = {
                  { value = "windfury", text = "Windfury" },
                  { value = "grace_of_air", text = "Grace of Air" },
                  { value = "grounding", text = "Grounding Totem" },
                  { value = "none", text = "None" },
              }},
        }},
    }},

    -- Tab 4: Restoration
    [4] = { name = "Restoration", sections = {
        { header = "Earth Shield", settings = {
            { type = "checkbox", key = "resto_maintain_earth_shield", default = true, label = "Maintain Earth Shield",
              tooltip = "Keep Earth Shield on focus target (tank)." },
            { type = "slider", key = "resto_earth_shield_refresh", default = 2, min = 1, max = 4, label = "ES Refresh Charges",
              tooltip = "Refresh Earth Shield when charges drop to this many or fewer.", format = "%d" },
        }},
        { header = "Emergency", settings = {
            { type = "checkbox", key = "resto_use_natures_swiftness", default = true, label = "Use Nature's Swiftness",
              tooltip = "Emergency instant Healing Wave when target is critically low (3 min CD)." },
            { type = "slider", key = "resto_ns_hp_threshold", default = 30, min = 10, max = 50, label = "NS Emergency HP%",
              tooltip = "Use Nature's Swiftness + Healing Wave when target drops below this HP.", format = "%d%%" },
        }},
        { header = "Mana Tide", settings = {
            { type = "checkbox", key = "resto_use_mana_tide", default = true, label = "Use Mana Tide",
              tooltip = "Auto-use Mana Tide Totem for mana recovery (5 min CD)." },
            { type = "slider", key = "resto_mana_tide_pct", default = 65, min = 30, max = 90, label = "Mana Tide Mana%",
              tooltip = "Use Mana Tide when mana drops below this.", format = "%d%%" },
        }},
        { header = "Healing", settings = {
            { type = "dropdown", key = "resto_primary_heal", default = "chain_heal", label = "Primary Heal",
              tooltip = "Main healing spell to use.",
              options = {
                  { value = "chain_heal", text = "Chain Heal" },
                  { value = "healing_wave", text = "Healing Wave" },
                  { value = "lesser_healing_wave", text = "Lesser Healing Wave" },
              }},
        }},
        { header = "Totems", settings = {
            { type = "dropdown", key = "resto_fire_totem", default = "searing", label = "Fire Totem",
              tooltip = "Default fire totem.",
              options = {
                  { value = "searing", text = "Searing Totem" },
                  { value = "flametongue", text = "Flametongue Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "resto_earth_totem", default = "strength_of_earth", label = "Earth Totem",
              tooltip = "Default earth totem. Tremor cancels Fear/Sleep/Charm — useful in fear-heavy fights.",
              options = {
                  { value = "strength_of_earth", text = "Strength of Earth" },
                  { value = "stoneskin", text = "Stoneskin Totem" },
                  { value = "tremor", text = "Tremor Totem" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "resto_water_totem", default = "mana_spring", label = "Water Totem",
              tooltip = "Default water totem.",
              options = {
                  { value = "mana_spring", text = "Mana Spring" },
                  { value = "healing_stream", text = "Healing Stream" },
                  { value = "none", text = "None" },
              }},
            { type = "dropdown", key = "resto_air_totem", default = "wrath_of_air", label = "Air Totem",
              tooltip = "Default air totem. Grounding absorbs the next hostile spell — useful in caster-heavy fights.",
              options = {
                  { value = "wrath_of_air", text = "Wrath of Air" },
                  { value = "windfury", text = "Windfury" },
                  { value = "tranquil_air", text = "Tranquil Air" },
                  { value = "grounding", text = "Grounding Totem" },
                  { value = "none", text = "None" },
              }},
        }},
    }},

    -- Tab 5: Cooldowns & Mana
    [5] = { name = "CDs & Mana", sections = {
        S.trinkets("Use racial ability (Blood Fury, Berserking, etc.) during burst."),
        { header = "Mana Recovery", settings = {
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
    }},
}

print("|cFF00FF00[Flux AIO]|r Shaman schema loaded")
