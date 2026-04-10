-- Druid Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Druid class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "DRUID" then return end
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
        { header = "Targeting", settings = {
            { type = "checkbox", key = "mouseover", default = false, label = "Use @mouseover", tooltip = "Use mouseover targeting.", hidden = true },
        }},
        { header = "Shared Combat", settings = {
            { type = "dropdown", key = "maintain_faerie_fire", default = "all", label = "Faerie Fire Targets",
              tooltip = "Which targets to maintain Faerie Fire on. All = everything, Elites+ = elites and bosses, Bosses = bosses only, Off = disabled.",
              options = {
                  { value = "all", text = "All" },
                  { value = "elites", text = "Elites+" },
                  { value = "bosses", text = "Bosses Only" },
                  { value = "off", text = "Off" },
              }},
        }},
        { header = "Cooldowns", settings = {
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
            { type = "checkbox", key = "use_racial", default = true, label = "Use Racial Ability", tooltip = "Use racial DPS cooldown (Berserking / Blood Fury)." },
        }},
        { header = "Cooldown Management", settings = {
            { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
              tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.", format = "%d sec" },
        }},
        { header = "Recovery Items", settings = {
            { type = "checkbox", key = "use_healthstone", default = true, label = "Use Healthstone", tooltip = "Use Healthstone when HP drops below threshold." },
            { type = "slider", key = "healthstone_hp", default = 30, min = 15, max = 50, label = "Healthstone HP (%)", tooltip = "Use Healthstone below this HP.", format = "%d%%" },
            { type = "checkbox", key = "use_healing_potion", default = true, label = "Use Healing Potion", tooltip = "Use Healing Potion when HP drops below threshold." },
            { type = "slider", key = "healing_potion_hp", default = 25, min = 10, max = 40, label = "Healing Potion HP (%)", tooltip = "Use Healing Potion below this HP.", format = "%d%%" },
            { type = "checkbox", key = "use_mana_potion", default = true, label = "Use Mana Potion", tooltip = "Use Super Mana Potion when mana drops below threshold." },
            { type = "slider", key = "mana_potion_mana", default = 20, min = 10, max = 50, label = "Mana Potion Mana (%)", tooltip = "Use Mana Potion below this mana %.", format = "%d%%" },
            { type = "checkbox", key = "use_dark_rune", default = true, label = "Use Dark Rune", tooltip = "Use Dark Rune / Demonic Rune when mana drops below threshold. Costs HP.", wide = true },
            { type = "slider", key = "dark_rune_mana", default = 30, min = 15, max = 60, label = "Dark Rune Mana (%)", tooltip = "Use Dark Rune below this mana %.", format = "%d%%" },
            { type = "slider", key = "dark_rune_min_hp", default = 50, min = 25, max = 75, label = "Dark Rune Min HP (%)", tooltip = "Only use Dark Rune if HP is above this (rune costs 600-1000 HP).", format = "%d%%" },
        }},
        { header = "Defensive", settings = {
            { type = "checkbox", key = "use_barkskin", default = true, label = "Use Barkskin", tooltip = "Use Barkskin when HP drops below threshold. Off-GCD, usable in all forms." },
            { type = "slider", key = "barkskin_hp", default = 40, min = 15, max = 70, label = "Barkskin HP (%)", tooltip = "Use Barkskin below this HP.", format = "%d%%" },
        }},
        { header = "Utility", settings = {
            { type = "checkbox", key = "use_innervate_self", default = true, label = "Innervate Self (Solo)", tooltip = "Use Innervate on yourself when low mana and solo." },
            { type = "slider", key = "innervate_mana", default = 30, min = 15, max = 50, label = "Innervate Mana (%)", tooltip = "Use Innervate below this mana %.", format = "%d%%" },
        }},
        S.burst(),
        S.dashboard(),
        S.debug(),
    }},

    -- Tab 2: Cat (Feral DPS)
    [2] = { name = "Cat", sections = {
        { header = "Bleeds", settings = {
            { type = "checkbox", key = "maintain_rip", default = true, label = "Maintain Rip", tooltip = "Keep Rip bleed DoT active." },
            { type = "checkbox", key = "rip_only_elites", default = true, label = "Rip Only Elites/Bosses", tooltip = "Only Rip elite or boss targets." },
            { type = "slider", key = "rip_min_cp", default = 5, min = 4, max = 5, label = "Rip Min Combo Points", tooltip = "Minimum combo points for Rip.", format = "%d" },
            { type = "slider", key = "rip_refresh", default = 0, min = 0, max = 5, label = "Rip Refresh (sec)", tooltip = "Prepare refresh this many seconds before expiry.", format = "%d sec" },
            { type = "slider", key = "rip_min_ttd", default = 12, min = 8, max = 30, label = "Rip Min TTD (sec)", tooltip = "Only Rip if target lives at least this long.", format = "%d sec" },
            { type = "checkbox", key = "maintain_rake", default = false, label = "Maintain Rake", tooltip = "Keep Rake bleed active." },
            { type = "slider", key = "rake_refresh", default = 0, min = 0, max = 4, label = "Rake Refresh (sec)", tooltip = "Refresh Rake with this many seconds remaining.", format = "%d sec" },
        }},
        { header = "Finishers", settings = {
            { type = "slider", key = "fb_min_cp", default = 5, min = 1, max = 5, label = "FB Min Combo Points", tooltip = "Minimum combo points to use Ferocious Bite.", format = "%d" },
            { type = "slider", key = "fb_max_energy", default = 39, min = 35, max = 70, label = "FB Max Energy", tooltip = "Only Bite at or below this energy to save energy for Shred. Does not apply during execute.", format = "%d" },
            { type = "slider", key = "fb_min_energy", default = 35, min = 35, max = 70, label = "FB Min Energy", tooltip = "Only Bite above this energy. 35 is optimal.", format = "%d" },
            { type = "slider", key = "fb_min_rip_duration", default = 6, min = 0, max = 12, label = "FB Min Rip Duration (sec)", tooltip = "Only Bite when Rip has more than this remaining.", format = "%d sec" },
            { type = "checkbox", key = "use_bite_execute", default = false, label = "Bite as Execute", tooltip = "Use Ferocious Bite as an execute finisher when target is low HP or dying soon. Disable to always Rip instead." },
            { type = "slider", key = "bite_execute_hp", default = 25, min = 10, max = 35, label = "Bite Execute HP (%)", tooltip = "Bite aggressively when target HP below this.", format = "%d%%" },
            { type = "slider", key = "bite_execute_ttd", default = 6, min = 4, max = 12, label = "Bite Execute TTD (sec)", tooltip = "Use Bite instead of Rip when target dies within this.", format = "%d sec" },
        }},
        { header = "Opener & Stealth", settings = {
            { type = "checkbox", key = "use_opener", default = true, label = "Use Combat Opener", tooltip = "Optimal opener from stealth (Ravage behind, Shred otherwise)." },
            { type = "checkbox", key = "use_mangle_opener", default = false, label = "Mangle Fallback Opener", tooltip = "Use Mangle as opener when not behind target." },
            { type = "checkbox", key = "focus_prowl", default = false, label = "Prowl on Focus", tooltip = "Auto-Prowl when focus target is nearby." },
            { type = "slider", key = "prowl_distance", default = 30, min = 10, max = 50, label = "Prowl Distance (yards)", tooltip = "Only Prowl within this distance.", format = "%d yd" },
        }},
        { header = "Energy Management", settings = {
            { type = "checkbox", key = "auto_powershift", default = true, label = "Auto Powershift", tooltip = "Shift out/in for energy. Wolfshead Helm auto-detected." },
            { type = "slider", key = "powershift_min_mana", default = 0, min = 0, max = 90, label = "Min Mana for Powershift (%)", tooltip = "Minimum mana % to powershift.", format = "%d%%" },
            { type = "checkbox", key = "use_super_sapper", default = false, label = "Use Super Sapper Charge", tooltip = "Use Super Sapper when shifting vs 3+ enemies or bosses. Requires DMH addon installed." },
            { type = "checkbox", key = "use_goblin_sapper", default = false, label = "Use Goblin Sapper Charge", tooltip = "Use Goblin Sapper when shifting vs 3+ enemies or bosses. Requires DMH addon installed." },
            { type = "checkbox", key = "use_tigers_fury", default = false, label = "Use Tiger's Fury", tooltip = "Normally not worth using rotationally. Enable for casual play." },
            { type = "slider", key = "tigers_fury_energy", default = 100, min = 30, max = 100, label = "Tiger's Fury Min Energy", tooltip = "Only use above this energy.", format = "%d" },
        }},
        { header = "AoE", settings = {
            { type = "checkbox", key = "enable_aoe", default = true, label = "Enable AoE", tooltip = "Enable AoE rotation when multiple enemies detected." },
            { type = "slider", key = "aoe_enemy_count", default = 3, min = 2, max = 6, label = "AoE Enemy Threshold", tooltip = "Switch to AoE with this many enemies.", format = "%d" },
            { type = "checkbox", key = "spread_rake", default = true, label = "Spread Rake", tooltip = "Apply Rake to multiple targets in AoE." },
            { type = "slider", key = "max_rake_targets", default = 4, min = 2, max = 6, label = "Max Rake Targets", tooltip = "Maximum targets to maintain Rake on.", format = "%d" },
        }},
        { header = "Advanced", settings = {
            { type = "checkbox", key = "use_bite_trick", default = true, label = "Use Bite Trick", tooltip = "Low-energy Ferocious Bite dump at 35-39 energy to avoid wasting combo points before powershift." },
            { type = "checkbox", key = "use_rake_trick", default = false, label = "Use Rake Trick", tooltip = "Low-energy Rake filler below Mangle cost to squeeze in damage before powershift." },
            { type = "checkbox", key = "cat_tick_optimization", default = false, label = "Mangle Over Shred (Tick Opt)",
              tooltip = "When enabled, uses Mangle instead of Shred at 60-61 energy if an energy tick is imminent. Two Mangles can fit where one Shred + dead GCD would. Off = always Shred when behind." },
            { type = "checkbox", key = "use_mangle_builder", default = true, label = "Mangle as Builder",
              tooltip = "Use Mangle as a fallback CP builder when not behind target. When disabled, the rotation pauses if you're not behind — reposition and resume." },
            { type = "checkbox", key = "cat_energy_pooling", default = true, label = "Energy Pooling",
              tooltip = "Pool energy for Rip instead of spending on builders. When disabled, always uses builders even if Rip is pending — higher APM but may delay Rip." },
            { type = "checkbox", key = "cat_swing_delay", default = false, label = "Swing Timer Delay",
              tooltip = "Delay ability casts when a melee swing is about to land (within 0.15s). Prevents clipping auto-attacks. Disable if you experience hesitation in the rotation." },
            { type = "checkbox", key = "cat_smart_shift_delay", default = true, label = "Smart Shift Delay",
              tooltip = "Delay powershifts when an energy tick is arriving within 1 second. Saves mana by avoiding unnecessary shifts. Disable if you experience idle time at low energy." },
        }},
    }},

    -- Tab 3: Bear (Feral Tank)
    [3] = { name = "Bear", sections = {
        { header = "Off-Tank Mode", settings = {
            { type = "checkbox", key = "bear_no_taunt", default = false, label = "Disable Taunts (Off-Tank)",
              tooltip = "Disables Growl and Challenging Roar. Use when off-tanking." },
        }},
        { header = "Debuff Maintenance", settings = {
            { type = "checkbox", key = "maintain_lacerate", default = true, label = "Maintain Lacerate", tooltip = "Keep Lacerate at 5 stacks." },
            { type = "checkbox", key = "lacerate_boss_only", default = true, label = "Lacerate Boss Only", tooltip = "Only Lacerate boss targets." },
            { type = "checkbox", key = "maintain_demo_roar", default = true, label = "Maintain Demo Roar", tooltip = "Keep Demoralizing Roar active." },
            { type = "slider", key = "demo_roar_range", default = 7, min = 5, max = 10, label = "Demo Roar Scan Range", tooltip = "Yard radius to scan for enemies. Demo Roar is 10yd PBAoE.", format = "%d yd" },
            { type = "slider", key = "demo_roar_min_bosses", default = 1, min = 1, max = 3, label = "Demo Roar Min Bosses", tooltip = "Min bosses in range to use Demo Roar. Default 1 = always on bosses.", format = "%d" },
            { type = "slider", key = "demo_roar_min_elites", default = 2, min = 1, max = 5, label = "Demo Roar Min Elites", tooltip = "Min elites within 10yd to use Demo Roar. Default 2.", format = "%d" },
            { type = "slider", key = "demo_roar_min_trash", default = 5, min = 2, max = 8, label = "Demo Roar Min Trash", tooltip = "Min trash mobs within 10yd to use Demo Roar. Default 5.", format = "%d" },
        }},
        { header = "Taunts", settings = {
            { type = "checkbox", key = "use_growl", default = true, label = "Auto Growl", tooltip = "Taunt when you lose aggro." },
            { type = "checkbox", key = "use_challenging_roar", default = true, label = "Use Challenging Roar", tooltip = "AoE taunt for emergency multi-target aggro loss. 10min CD." },
            { type = "slider", key = "croar_range", default = 7, min = 5, max = 10, label = "C.Roar Scan Range", tooltip = "Yard radius to scan for loose enemies. C.Roar is 10yd PBAoE.", format = "%d yd" },
            { type = "slider", key = "croar_min_bosses", default = 1, min = 1, max = 3, label = "C.Roar Min Bosses", tooltip = "Min loose bosses in range to use Challenging Roar. Default 1 = any loose boss.", format = "%d" },
            { type = "slider", key = "croar_min_elites", default = 5, min = 1, max = 6, label = "C.Roar Min Elites", tooltip = "Min loose elites within range to use Challenging Roar. Default 5.", format = "%d" },
        }},
        { header = "Threat Management", settings = {
            { type = "checkbox", key = "enable_tab_targeting", default = true, label = "Enable Tab Targeting", tooltip = "Automatically switch targets to spread threat across multiple mobs. Picks up loose mobs, switches off CC'd targets, and spreads Lacerate for DPS optimization." },
            { type = "dropdown", key = "tab_min_priority", default = "all", label = "Min Priority to Tab",
              tooltip = "Only tab-target mobs of this priority or higher. 'All' picks up everything, 'Elites+' ignores trash, 'Bosses Only' only picks up bosses.",
              options = {
                  { value = "all", text = "All" },
                  { value = "elites", text = "Elites+" },
                  { value = "bosses", text = "Bosses Only" },
              }},
            { type = "slider", key = "tab_max_mobs", default = 4, min = 2, max = 8, label = "Max Mobs to Manage", tooltip = "Stop picking up new mobs once you have aggro on this many. Higher = more threat spreading, lower = more focused tanking.", format = "%d" },
            { type = "checkbox", key = "tab_spread_lacerate", default = true, label = "Spread Lacerate", tooltip = "Switch targets to spread Lacerate stacks on 2-3 target packs for DPS optimization." },
        }},
        { header = "Rage Management", settings = {
            { type = "slider", key = "maul_rage_threshold", default = 25, min = 15, max = 80, label = "Maul Rage Threshold", tooltip = "Queue Maul above this rage. Lower = more Maul casts and threat. Higher = preserve rage for GCD abilities. 25 recommended for boss fights.", format = "%d" },
            { type = "slider", key = "mangle_rage_threshold", default = 15, min = 15, max = 80, label = "Mangle Rage Threshold", tooltip = "Mangle is your highest-damage ability. 15 = on cooldown (recommended). Raise only if rage-starved.", format = "%d" },
            { type = "slider", key = "swipe_rage_threshold", default = 15, min = 15, max = 80, label = "Swipe Rage Threshold", tooltip = "Only Swipe above this rage. 15 = on cooldown (minimum cost). Raise to preserve rage for higher-priority abilities.", format = "%d" },
            { type = "slider", key = "swipe_min_targets", default = 2, min = 1, max = 4, label = "Swipe AoE Threshold", tooltip = "At this many enemies, Swipe takes priority over Mangle (AoE mode). Below this, Swipe is used as primary GCD filler between Mangle cooldowns.", format = "%d" },
            { type = "checkbox", key = "swipe_cc_check", default = true, label = "Swipe CC Safety", tooltip = "Skip Swipe when a nearby mob has breakable CC (Polymorph, Trap, Sap, etc). Prevents breaking crowd control." },
        }},
        { header = "Emergency Abilities", settings = {
            { type = "checkbox", key = "use_frenzied_regen", default = true, label = "Use Frenzied Regen", tooltip = "Converts rage to health when HP drops." },
            { type = "checkbox", key = "use_enrage", default = true, label = "Use Enrage", tooltip = "Generate rage when low (reduces armor)." },
            { type = "slider", key = "enrage_rage_threshold", default = 20, min = 10, max = 40, label = "Enrage Below Rage", tooltip = "Use Enrage when rage drops below this.", format = "%d" },
        }},
    }},

    -- Tab 4: Caster (Healing & Recovery)
    [4] = { name = "Caster", sections = {
        { header = "Healing Thresholds", settings = {
            { type = "slider", key = "rejuvenation_hp", default = 80, min = 50, max = 90, label = "Rejuvenation HP (%)", tooltip = "Apply Rejuvenation HoT when HP drops below this.", format = "%d%%" },
            { type = "slider", key = "regrowth_hp", default = 50, min = 30, max = 70, label = "Regrowth HP (%)", tooltip = "Apply Regrowth when HP drops below this.", format = "%d%%" },
            { type = "slider", key = "emergency_heal_hp", default = 30, min = 15, max = 50, label = "Emergency Heal HP (%)", tooltip = "Use Healing Touch below this (shifts out of form).", format = "%d%%" },
            { type = "slider", key = "critical_heal_hp", default = 20, min = 10, max = 35, label = "Critical HP (%)", tooltip = "Critical HP threshold - triggers emergency healing.", format = "%d%%" },
        }},
        { header = "Mana", settings = {
            { type = "slider", key = "mana_reserve", default = 600, min = 400, max = 1500, label = "Mana Reserve", tooltip = "Keep this much mana reserved for form shifts. Bear Form costs ~580.", format = "%d" },
        }},
        { header = "Dispels", settings = {
            { type = "checkbox", key = "auto_remove_curse", default = true, label = "Auto Remove Curse", tooltip = "Automatically remove curses from yourself." },
            { type = "checkbox", key = "auto_remove_poison", default = true, label = "Auto Remove Poison", tooltip = "Automatically remove poisons from yourself." },
        }},
        { header = "Self-Buffs", settings = {
            { type = "checkbox", key = "use_motw", default = true, label = "Mark of the Wild", tooltip = "Auto-apply Mark of the Wild when missing (out of combat)." },
            { type = "checkbox", key = "use_thorns", default = true, label = "Thorns", tooltip = "Auto-apply Thorns when missing (out of combat)." },
            { type = "checkbox", key = "use_ooc", default = true, label = "Omen of Clarity", tooltip = "Auto-apply Omen of Clarity when missing (out of combat)." },
        }},
    }},

    -- Tab 5: Balance (Moonkin)
    [5] = { name = "Balance", sections = {
        { header = "DoT Maintenance", settings = {
            { type = "checkbox", key = "maintain_moonfire", default = true, label = "Maintain Moonfire", tooltip = "Keep Moonfire DoT active." },
            { type = "checkbox", key = "maintain_insect_swarm", default = true, label = "Maintain Insect Swarm", tooltip = "Keep Insect Swarm active." },
            { type = "slider", key = "balance_dot_refresh", default = 0, min = 0, max = 5, label = "DoT Refresh (sec)", tooltip = "Refresh DoTs with this many seconds remaining. 0 = only reapply when fallen off (WoWsims default).", format = "%d sec" },
        }},
        { header = "Force of Nature", settings = {
            { type = "checkbox", key = "use_force_of_nature", default = true, label = "Use Force of Nature", tooltip = "Summon Treants (41pt Balance talent)." },
            { type = "slider", key = "force_of_nature_min_ttd", default = 15, min = 5, max = 45, label = "Treants Min TTD (sec)", tooltip = "Only summon if target lives this long.", format = "%d sec" },
        }},
        { header = "AoE", settings = {
            { type = "slider", key = "hurricane_min_targets", default = 3, min = 2, max = 5, label = "Hurricane Min Targets", tooltip = "Min targets for Hurricane.", format = "%d" },
        }},
        { header = "Proc Optimization", settings = {
            { type = "checkbox", key = "clearcast_starfire", default = true, label = "Clearcast: Starfire Priority", tooltip = "When Clearcast procs, immediately cast Starfire (most expensive spell) before refreshing DoTs." },
            { type = "checkbox", key = "ng_wrath_priority", default = false, label = "Nature's Grace: Wrath Priority", tooltip = "When Nature's Grace procs, cast Wrath (~1.0s) instead of Starfire (~3.0s) for more casts per proc window. Off by default (Starfire is standard)." },
        }},
        { header = "Mana Recovery", settings = {
            { type = "checkbox", key = "balance_use_innervate", default = true, label = "Use Innervate", tooltip = "Use Innervate on yourself when mana drops below threshold." },
            { type = "slider", key = "balance_innervate_mana", default = 20, min = 10, max = 50, label = "Innervate Mana (%)", tooltip = "Use Innervate below this mana %.", format = "%d%%" },
        }},
        { header = "Mana Tiers", settings = {
            { type = "slider", key = "balance_tier1_mana", default = 20, min = 10, max = 60, label = "Full Rotation Mana (%)", tooltip = "Above this: full rotation (Starfire + Moonfire + IS).", format = "%d%%" },
            { type = "slider", key = "balance_tier2_mana", default = 10, min = 5, max = 35, label = "Conserve Mana (%)", tooltip = "Below this: drop Moonfire, only IS + Starfire.", format = "%d%%" },
        }},
    }},

    -- Tab 6: Resto (Tree of Life Healer)
    [6] = { name = "Resto", sections = {
        { header = "Tree of Life Healing", settings = {
            { type = "slider", key = "resto_emergency_hp", default = 30, min = 15, max = 50, label = "Emergency HP (%)", tooltip = "Triggers emergency healing (Swiftmend > NS+HT/Regrowth).", format = "%d%%" },
            { type = "checkbox", key = "resto_ns_healing_touch", default = true, label = "NS + Healing Touch",
              tooltip = "Emergency: leave Tree for NS + max rank Healing Touch (bigger heal, leaves Tree briefly). Disable for NS + Regrowth (stays in Tree)." },
            { type = "slider", key = "resto_tank_heal_hp", default = 50, min = 30, max = 70, label = "Tank Heal HP (%)", tooltip = "Prioritize tank healing below this HP.", format = "%d%%" },
            { type = "slider", key = "resto_standard_heal_hp", default = 80, min = 50, max = 95, label = "Standard Heal HP (%)", tooltip = "Apply Regrowth on targets below this HP.", format = "%d%%" },
            { type = "slider", key = "resto_proactive_hp", default = 90, min = 70, max = 100, label = "Proactive HP (%)", tooltip = "Spread Rejuvenation on targets below this HP.", format = "%d%%" },
        }},
        { header = "Lifebloom", settings = {
            { type = "slider", key = "resto_lifebloom_refresh", default = 2, min = 1, max = 4, label = "Lifebloom Refresh (sec)", tooltip = "Refresh 3-stack Lifebloom when this many seconds remain.", format = "%d sec" },
        }},
        { header = "Swiftmend", settings = {
            { type = "slider", key = "resto_swiftmend_hp", default = 50, min = 25, max = 70, label = "Swiftmend HP (%)", tooltip = "Use Swiftmend for burst healing below this HP (requires Rejuv or Regrowth on target).", format = "%d%%" },
        }},
        { header = "Tank & Mana", settings = {
            { type = "checkbox", key = "resto_prioritize_tank", default = true, label = "Prioritize Tank", tooltip = "Maintain Lifebloom 3-stack and HoTs on tank." },
            { type = "slider", key = "resto_mana_conserve", default = 40, min = 20, max = 60, label = "Mana Conserve (%)", tooltip = "Below this mana: skip Regrowth, focus on Lifebloom + Rejuv only.", format = "%d%%" },
        }},
        { header = "Dispels", settings = {
            { type = "checkbox", key = "resto_auto_dispel_curse", default = true, label = "Auto Remove Curse (Party)", tooltip = "Remove Curse from party members (castable in Tree form)." },
            { type = "checkbox", key = "resto_auto_dispel_poison", default = true, label = "Auto Abolish Poison (Party)", tooltip = "Abolish Poison on party members (castable in Tree form)." },
        }},
    }},
}

print("|cFF00FF00[Flux AIO]|r Druid schema loaded")
