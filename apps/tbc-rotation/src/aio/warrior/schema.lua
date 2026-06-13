-- Warrior Settings Schema
-- Defines _G.FluxAIO_SETTINGS_SCHEMA for Warrior class
-- Must load before ui.lua, core.lua, and settings.lua

local _G = _G
local A = _G.Action

if not A then
	return
end
if A.PlayerClass ~= "WARRIOR" then
	return
end
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
	[1] = {
		name = "General",
		sections = {
			{
				header = "Spec Selection",
				settings = {
					{
						type = "dropdown",
						key = "playstyle",
						default = "fury",
						label = "Active Spec",
						tooltip = "Which spec rotation to use.",
						options = {
							{ value = "arms", text = "Arms" },
							{ value = "fury", text = "Fury" },
							{ value = "kebab", text = "Kebab" },
							{ value = "protection", text = "Protection" },
						},
					},
				},
			},
			{
				header = "Shouts",
				settings = {
					{
						type = "dropdown",
						key = "shout_type",
						default = "battle",
						label = "Shout Type",
						tooltip = "Which shout to maintain.",
						options = {
							{ value = "battle", text = "Battle Shout" },
							{ value = "commanding", text = "Commanding Shout" },
							{ value = "none", text = "None" },
						},
					},
					{
						type = "checkbox",
						key = "auto_shout",
						default = true,
						label = "Auto Shout",
						tooltip = "Automatically maintain selected shout buff.",
					},
				},
			},
			{
				header = "Debuff Maintenance",
				settings = {
					{
						type = "dropdown",
						key = "sunder_armor_mode",
						default = "none",
						label = "Sunder Armor",
						tooltip = "Sunder Armor maintenance mode.",
						options = {
							{ value = "none", text = "None" },
							{ value = "help_stack", text = "Help Stack (to 5)" },
							{ value = "maintain", text = "Maintain (stack + refresh)" },
						},
					},
					{
						type = "checkbox",
						key = "maintain_thunder_clap",
						default = false,
						label = "Maintain Thunder Clap",
						tooltip = "Keep Thunder Clap debuff on target (requires Battle Stance).",
					},
					{
						type = "checkbox",
						key = "maintain_demo_shout",
						default = false,
						label = "Maintain Demo Shout",
						tooltip = "Keep Demoralizing Shout debuff on target.",
					},
				},
			},
			{
				header = "Utility",
				settings = {
					{
						type = "checkbox",
						key = "use_interrupt",
						default = true,
						label = "Auto Interrupt",
						tooltip = "Interrupt enemy casts (Pummel in Berserker, Shield Bash in Defensive).",
					},
					{
						type = "checkbox",
						key = "use_bloodrage",
						default = true,
						label = "Auto Bloodrage",
						tooltip = "Use Bloodrage on cooldown for rage generation.",
					},
					{
						type = "slider",
						key = "bloodrage_min_hp",
						default = 50,
						min = 20,
						max = 80,
						label = "Bloodrage Min HP (%)",
						tooltip = "Don't use Bloodrage when HP is below this (it costs HP).",
						format = "%d%%",
					},
					{
						type = "checkbox",
						key = "use_berserker_rage",
						default = false,
						label = "Auto Berserker Rage",
						tooltip = "Use Berserker Rage on cooldown when in Berserker Stance (rage gen + fear immunity).",
					},
					{
						type = "checkbox",
						key = "use_loc_breaker",
						default = true,
						label = "LoC Fear/Incap Breaker",
						tooltip = "Reactively use Berserker Rage or Death Wish to break fears and incapacitates.",
					},
					{
						type = "checkbox",
						key = "use_auto_charge",
						default = true,
						label = "Auto Charge",
						tooltip = "Automatically Charge (Battle Stance) or Intercept (Berserker Stance) to close gaps on your target.",
					},
					{
						type = "checkbox",
						key = "use_auto_tab",
						default = true,
						label = "Auto Tab Target",
						tooltip = "Automatically tab to a nearby enemy when your target is dead, out of melee range, or doesn't exist.",
					},
					{
						type = "checkbox",
						key = "auto_tab_execute",
						default = false,
						label = "Tab to Execute Targets",
						tooltip = "Prefer tabbing to enemies below 20% HP for Execute kills.",
					},
				},
			},
			{
				header = "External Buff Management",
				settings = {
					{
						type = "checkbox",
						key = "cancel_pws",
						default = true,
						label = "Cancel PW:S",
						tooltip = "Cancel Power Word: Shield when rage is below 30 (PW:S blocks rage from damage taken).",
					},
					{
						type = "checkbox",
						key = "cancel_bop",
						default = false,
						label = "Cancel BoP",
						tooltip = "Cancel Blessing of Protection when HP > 50% (BoP prevents all attacks).",
					},
				},
			},
			{
				header = "AoE",
				settings = {
					{
						type = "slider",
						key = "aoe_threshold",
						default = 2,
						min = 0,
						max = 8,
						label = "Cleave Threshold",
						tooltip = "Use Cleave instead of Heroic Strike at this many enemies. 0 = never Cleave (HS only).",
						format = "%d",
					},
				},
			},
			{
				header = "Heroic Strike",
				settings = {
					{
						type = "checkbox",
						key = "hs_trick",
						default = true,
						label = "HS Queue Trick (DW)",
						tooltip = "Dual-wield only. Queue HS before off-hand swings to convert them to yellow hits (no glancing blows). Auto-dequeues before main-hand lands if rage is low. Works for all specs.",
					},
				},
			},
			{
				header = "AoE Safety",
				settings = {
					{
						type = "checkbox",
						key = "pvp_cc_break_check",
						default = true,
						label = "CC Break Prevention",
						tooltip = "Prevent AoE abilities (WW, Cleave, TC, Demo Shout) from breaking CC on nearby enemies. Works in both PvP (arena/BG) and PvE (dungeon CC like Polymorph, Sap, Freezing Trap).",
					},
				},
			},
			{
				header = "Cooldown Management",
				settings = {
					{
						type = "slider",
						key = "cd_min_ttd",
						default = 0,
						min = 0,
						max = 60,
						label = "CD Min TTD (sec)",
						tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this. Set to 0 to disable.",
						format = "%d sec",
					},
				},
			},
			{
				header = "Recovery Items",
				settings = {
					{
						type = "slider",
						key = "healthstone_hp",
						default = 35,
						min = 0,
						max = 100,
						label = "Healthstone HP (%)",
						tooltip = "Use Healthstone when HP drops below this. 0 = disable.",
						format = "%d%%",
					},
					{
						type = "checkbox",
						key = "use_healing_potion",
						default = true,
						label = "Use Healing Potion",
						tooltip = "Use Healing Potion when HP drops low in combat.",
					},
					{
						type = "slider",
						key = "healing_potion_hp",
						default = 25,
						min = 10,
						max = 50,
						label = "Healing Potion HP (%)",
						tooltip = "Use Healing Potion when HP drops below this.",
						format = "%d%%",
					},
				},
			},
			{
				header = "Out of Combat",
				settings = {
					{
						type = "checkbox",
						key = "use_auto_bandage",
						default = true,
						label = "Auto Bandage",
						tooltip = "Automatically use bandages out of combat when HP is low.",
					},
					{
						type = "slider",
						key = "bandage_hp",
						default = 70,
						min = 30,
						max = 90,
						label = "Bandage HP (%)",
						tooltip = "Use bandage when HP drops below this (out of combat only).",
						format = "%d%%",
					},
				},
			},
			S.burst(),
			S.dashboard(),
			S.debug(),
		},
	},

	-- Tab 2: Arms
	[2] = {
		name = "Arms",
		sections = {
			{
				header = "Core Abilities",
				settings = {
					{
						type = "checkbox",
						key = "arms_maintain_rend",
						default = false,
						label = "Maintain Rend",
						tooltip = "Keep Rend DoT on target. OFF recommended (Deep Wounds applies Rend on crit).",
					},
					{
						type = "slider",
						key = "arms_rend_refresh",
						default = 4,
						min = 2,
						max = 8,
						label = "Rend Refresh (sec)",
						tooltip = "Refresh Rend when remaining duration is below this.",
						format = "%d sec",
					},
					{
						type = "checkbox",
						key = "arms_use_overpower",
						default = false,
						label = "Use Overpower",
						tooltip = "Use Overpower on dodge procs (Battle Stance only). OFF recommended for 2H Arms (stance dance costs rage, delays MS/WW).",
					},
					{
						type = "slider",
						key = "arms_overpower_rage",
						default = 15,
						min = 10,
						max = 50,
						label = "Overpower Min Rage",
						tooltip = "Minimum rage to use Overpower.",
						format = "%d",
					},
				},
			},
			{
				header = "Rotation",
				settings = {
					{
						type = "checkbox",
						key = "arms_use_whirlwind",
						default = true,
						label = "Use Whirlwind",
						tooltip = "Use Whirlwind on cooldown (Berserker Stance only).",
					},
					{
						type = "checkbox",
						key = "arms_use_slam",
						default = true,
						label = "Use Slam",
						tooltip = "Use Slam as filler (requires Improved Slam 2/2 for 0.5s cast).",
					},
					{
						type = "checkbox",
						key = "arms_use_sweeping_strikes",
						default = true,
						label = "Use Sweeping Strikes",
						tooltip = "Use Sweeping Strikes on cooldown (Battle Stance).",
					},
				},
			},
			{
				header = "Utility",
				settings = {
					{
						type = "checkbox",
						key = "arms_use_victory_rush",
						default = true,
						label = "Use Victory Rush",
						tooltip = "Use Victory Rush (free instant attack after a killing blow, 0 rage).",
					},
				},
			},
			{
				header = "Execute Phase",
				settings = {
					{
						type = "checkbox",
						key = "arms_execute_phase",
						default = true,
						label = "Execute Phase",
						tooltip = "Switch to Execute priority at <20% target HP.",
					},
					{
						type = "checkbox",
						key = "arms_use_ms_execute",
						default = true,
						label = "MS During Execute",
						tooltip = "Use Mortal Strike during execute phase.",
					},
					{
						type = "checkbox",
						key = "arms_use_ww_execute",
						default = true,
						label = "WW During Execute",
						tooltip = "Use Whirlwind during execute phase.",
					},
				},
			},
			{
				header = "Rage Dump",
				settings = {
					{
						type = "slider",
						key = "arms_hs_rage_threshold",
						default = 60,
						min = 30,
						max = 80,
						label = "HS Rage Threshold",
						tooltip = "Queue Heroic Strike above this rage.",
						format = "%d",
					},
					{
						type = "checkbox",
						key = "arms_hs_during_execute",
						default = false,
						label = "HS During Execute",
						tooltip = "Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage).",
					},
				},
			},
			{
				header = "Cooldowns",
				settings = {
					{
						type = "dropdown",
						key = "arms_use_death_wish",
						default = "in_combat",
						label = "Death Wish",
						tooltip = "When to use Death Wish (+20% damage). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
					{
						type = "dropdown",
						key = "arms_use_recklessness",
						default = "in_combat",
						label = "Recklessness",
						tooltip = "When to use Recklessness (+100% crit for 3 charges). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
				},
			},
		},
	},

	-- Tab 3: Fury
	[3] = {
		name = "Fury",
		sections = {
			{
				header = "Core Abilities",
				settings = {
					{
						type = "checkbox",
						key = "fury_use_whirlwind",
						default = true,
						label = "Use Whirlwind",
						tooltip = "Use Whirlwind on cooldown.",
					},
					{
						type = "checkbox",
						key = "fury_use_sweeping_strikes",
						default = true,
						label = "Use Sweeping Strikes",
						tooltip = "Use Sweeping Strikes on cooldown in AoE (Fury talent).",
					},
					{
						type = "slider",
						key = "fury_ww_prio_count",
						default = 2,
						min = 0,
						max = 6,
						label = "WW Prio Mob Count",
						tooltip = "Prioritize Whirlwind over Bloodthirst when this many enemies are nearby. 0 = always BT first.",
						format = "%d",
					},
					{
						type = "checkbox",
						key = "fury_use_slam",
						default = false,
						label = "Use Slam",
						tooltip = "Use Slam weaving (requires Improved Slam 2/2).",
					},
				},
			},
			{
				header = "Rage Dump & Utility",
				settings = {
					{
						type = "checkbox",
						key = "fury_use_heroic_strike",
						default = true,
						label = "Heroic Strike Dump",
						tooltip = "Auto-queue Heroic Strike as rage dump.",
					},
					{
						type = "slider",
						key = "fury_hs_rage_threshold",
						default = 40,
						min = 30,
						max = 80,
						label = "HS Rage Threshold",
						tooltip = "Queue Heroic Strike above this rage.",
						format = "%d",
					},
					{
						type = "checkbox",
						key = "fury_swing_desync",
						default = false,
						label = "Swing Desync (DW)",
						tooltip = "Dual-wield only. When weapons have similar speeds and MH/OH swings are synced, cast a Slam to offset swing timers for smoother rage generation. Requires Slam.",
					},
					{
						type = "checkbox",
						key = "fury_use_hamstring",
						default = false,
						label = "Hamstring Weave",
						tooltip = "Weave Hamstring for Sword Spec procs.",
					},
					{
						type = "slider",
						key = "fury_hamstring_rage",
						default = 50,
						min = 20,
						max = 80,
						label = "Hamstring Min Rage",
						tooltip = "Minimum rage to use Hamstring.",
						format = "%d",
					},
				},
			},
			{
				header = "Rampage",
				settings = {
					{
						type = "slider",
						key = "fury_rampage_threshold",
						default = 5,
						min = 2,
						max = 10,
						label = "Rampage Refresh (sec)",
						tooltip = "Refresh Rampage when duration below this.",
						format = "%d sec",
					},
				},
			},
			{
				header = "Utility",
				settings = {
					{
						type = "checkbox",
						key = "fury_use_victory_rush",
						default = true,
						label = "Use Victory Rush",
						tooltip = "Use Victory Rush (free instant attack after a killing blow, 0 rage).",
					},
				},
			},
			{
				header = "Execute Phase",
				settings = {
					{
						type = "checkbox",
						key = "fury_execute_phase",
						default = true,
						label = "Execute Phase",
						tooltip = "Switch to Execute priority at <20% target HP.",
					},
					{
						type = "checkbox",
						key = "fury_bt_during_execute",
						default = true,
						label = "BT During Execute",
						tooltip = "Use Bloodthirst during execute phase.",
					},
					{
						type = "checkbox",
						key = "fury_ww_during_execute",
						default = true,
						label = "WW During Execute",
						tooltip = "Use Whirlwind during execute phase.",
					},
					{
						type = "checkbox",
						key = "fury_hs_during_execute",
						default = false,
						label = "HS During Execute",
						tooltip = "Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage). Exception: with HS trick, ON keeps yellow OH hits.",
					},
				},
			},
			{
				header = "Cooldowns",
				settings = {
					{
						type = "dropdown",
						key = "fury_use_death_wish",
						default = "in_combat",
						label = "Death Wish",
						tooltip = "When to use Death Wish (+20% damage). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
					{
						type = "dropdown",
						key = "fury_use_recklessness",
						default = "in_combat",
						label = "Recklessness",
						tooltip = "When to use Recklessness (+100% crit for 3 charges). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
				},
			},
		},
	},

	-- Tab 4: Protection
	[4] = {
		name = "Protection",
		sections = {
			{
				header = "Core Abilities",
				settings = {
					{
						type = "checkbox",
						key = "prot_use_revenge",
						default = true,
						label = "Use Revenge",
						tooltip = "Use Revenge when available (highest threat/rage).",
					},
					{
						type = "checkbox",
						key = "prot_use_devastate",
						default = true,
						label = "Use Devastate",
						tooltip = "Use Devastate (requires Prot 41-point talent).",
					},
					{
						type = "checkbox",
						key = "prot_use_execute",
						default = true,
						label = "Use Execute",
						tooltip = "Use Execute on targets below 20% HP (rage-efficient finisher).",
					},
				},
			},
			{
				header = "Utility",
				settings = {
					{
						type = "checkbox",
						key = "prot_use_victory_rush",
						default = true,
						label = "Use Victory Rush",
						tooltip = "Use Victory Rush (free instant attack after a killing blow, 0 rage).",
					},
				},
			},
			{
				header = "Debuffs",
				settings = {
					{
						type = "checkbox",
						key = "prot_use_thunder_clap",
						default = true,
						label = "Use Thunder Clap",
						tooltip = "Maintain Thunder Clap debuff (requires Battle Stance swap).",
					},
					{
						type = "slider",
						key = "prot_tc_min_mobs",
						default = 2,
						min = 1,
						max = 10,
						label = "TC Min Enemies",
						tooltip = "Minimum nearby enemies (or boss) before Thunder Clap is used.",
						format = "%d",
					},
					{
						type = "checkbox",
						key = "prot_use_demo_shout",
						default = true,
						label = "Use Demo Shout",
						tooltip = "Maintain Demoralizing Shout debuff.",
					},
					{
						type = "slider",
						key = "prot_demo_min_mobs",
						default = 6,
						min = 1,
						max = 15,
						label = "Demo Min Enemies",
						tooltip = "Minimum nearby enemies (or boss) before Demoralizing Shout is used.",
						format = "%d",
					},
				},
			},
			{
				header = "Heroic Strike / Cleave",
				settings = {
					{
						type = "slider",
						key = "prot_hs_rage_threshold",
						default = 25,
						min = 15,
						max = 90,
						label = "HS Rage Threshold",
						tooltip = "Queue Heroic Strike/Cleave above this rage. Lower = more HS/Cleave uptime, higher = more rage reserved for abilities.",
						format = "%d",
					},
				},
			},
			{
				header = "Shield Block",
				settings = {
					{
						type = "dropdown",
						key = "prot_sb_mode",
						default = "rage",
						label = "Shield Block Mode",
						tooltip = "How to gate Shield Block usage.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "rage", text = "By Rage" },
							{ value = "threat", text = "By Threat Lead" },
						},
					},
					{
						type = "slider",
						key = "prot_sb_rage_threshold",
						default = 90,
						min = 30,
						max = 100,
						label = "SB Rage Threshold",
						tooltip = "Only use Shield Block above this rage (By Rage mode).",
						format = "%d",
					},
					{
						type = "slider",
						key = "prot_sb_threat_lead",
						default = 110,
						min = 100,
						max = 200,
						label = "SB Threat Lead (%)",
						tooltip = "Only use Shield Block when threat lead exceeds this % (By Threat Lead mode).",
						format = "%d%%",
					},
				},
			},
			{
				header = "Taunts",
				settings = {
					{
						type = "checkbox",
						key = "prot_no_taunt",
						default = false,
						label = "Disable Taunts (Off-Tank)",
						tooltip = "Disables Taunt and Challenging Shout. Use when off-tanking.",
					},
					{
						type = "checkbox",
						key = "prot_use_taunt",
						default = true,
						label = "Auto Taunt",
						tooltip = "Taunt when you lose aggro on an elite or boss.",
					},
					{
						type = "checkbox",
						key = "prot_use_challenging_shout",
						default = true,
						label = "Use Challenging Shout",
						tooltip = "AoE taunt for emergency multi-target aggro loss. 10min CD.",
					},
					{
						type = "slider",
						key = "prot_cshout_min_bosses",
						default = 1,
						min = 1,
						max = 3,
						label = "C.Shout Min Bosses",
						tooltip = "Min loose bosses in range to use Challenging Shout.",
						format = "%d",
					},
					{
						type = "slider",
						key = "prot_cshout_min_elites",
						default = 3,
						min = 1,
						max = 6,
						label = "C.Shout Min Elites",
						tooltip = "Min loose elites in range to use Challenging Shout.",
						format = "%d",
					},
					{
						type = "slider",
						key = "prot_cshout_min_trash",
						default = 5,
						min = 2,
						max = 10,
						label = "C.Shout Min Trash",
						tooltip = "Min loose trash mobs in range to use Challenging Shout.",
						format = "%d",
					},
				},
			},
			{
				header = "Threat Tab Targeting",
				settings = {
					{
						type = "slider",
						key = "prot_tab_max_mobs",
						default = 4,
						min = 1,
						max = 8,
						label = "Max Mobs to Manage",
						tooltip = "Max simultaneous mobs to actively tank. Won't pick up new mobs beyond this count unless they are completely loose (threat 0-1).",
						format = "%d",
					},
					{
						type = "dropdown",
						key = "prot_tab_min_priority",
						default = "all",
						label = "Tab Target Priority",
						tooltip = "Which mob types to tab-target. 'All' tabs to any mob, 'Elites+' only tabs to elites and bosses, 'Bosses' only tabs to bosses.",
						options = {
							{ value = "all", text = "All Mobs" },
							{ value = "elites", text = "Elites+" },
							{ value = "bosses", text = "Bosses Only" },
						},
					},
				},
			},
			{
				header = "Threat Lead Gate",
				settings = {
					{
						type = "slider",
						key = "prot_threat_lead",
						default = 0,
						min = 0,
						max = 200,
						label = "Utility Threat Lead (%)",
						tooltip = "Require this threat % lead before using Shield Block, Demo Shout, and Thunder Clap (single-target). 0 = disabled. Thunder Clap still fires on AoE pulls regardless.",
						format = "%d%%",
					},
				},
			},
		},
	},

	-- Tab 5: CDs & Survival
	[5] = {
		name = "CDs & Survival",
		sections = {
			S.trinkets("Use racial ability (Blood Fury, Berserking, etc.)."),
			{
				header = "Emergency Survival",
				settings = {
					{
						type = "slider",
						key = "last_stand_hp",
						default = 20,
						min = 0,
						max = 50,
						label = "Last Stand HP (%)",
						tooltip = "Use Last Stand below this HP. 0 = disable.",
						format = "%d%%",
					},
					{
						type = "slider",
						key = "shield_wall_hp",
						default = 15,
						min = 0,
						max = 50,
						label = "Shield Wall HP (%)",
						tooltip = "Use Shield Wall below this HP. 0 = disable.",
						format = "%d%%",
					},
					{
						type = "checkbox",
						key = "use_spell_reflection",
						default = true,
						label = "Auto Spell Reflect",
						tooltip = "Use Spell Reflection on incoming spells.",
					},
					{
						type = "checkbox",
						key = "use_retaliation",
						default = false,
						label = "Use Retaliation",
						tooltip = "Use Retaliation when surrounded by many enemies (Battle Stance, 5min CD).",
					},
					{
						type = "slider",
						key = "retaliation_min_enemies",
						default = 3,
						min = 2,
						max = 6,
						label = "Retaliation Min Enemies",
						tooltip = "Minimum nearby enemies to trigger Retaliation.",
						format = "%d",
					},
				},
			},
		},
	},

	-- Tab 6: PvP
	[6] = {
		name = "PvP",
		sections = {
			{
				header = "PvP General",
				settings = {
					{
						type = "checkbox",
						key = "pvp_enabled",
						default = true,
						label = "Enable PvP Mode",
						tooltip = "Enable PvP-specific logic (auto-detected via BG/Arena/PvP flag, but can be disabled here).",
					},
				},
			},
			{
				header = "Offensive",
				settings = {
					{
						type = "checkbox",
						key = "pvp_hamstring",
						default = true,
						label = "Maintain Hamstring",
						tooltip = "Keep Hamstring on enemy players (skips immune targets, evasion, FAP).",
					},
					{
						type = "checkbox",
						key = "pvp_piercing_howl",
						default = true,
						label = "Piercing Howl (AoE Snare)",
						tooltip = "Use Piercing Howl when 2+ enemy players nearby lack a slow (Fury talent).",
					},
					{
						type = "checkbox",
						key = "pvp_rend_stealth",
						default = true,
						label = "Rend Anti-Stealth",
						tooltip = "Apply Rend to Rogues/Druids to prevent stealth re-entry.",
					},
					{
						type = "checkbox",
						key = "pvp_overpower_evasion",
						default = true,
						label = "Overpower vs Evasion",
						tooltip = "Prioritize Overpower against targets with Evasion or Deterrence active.",
					},
					{
						type = "checkbox",
						key = "pvp_shield_slam_purge",
						default = true,
						label = "Shield Slam Purge",
						tooltip = "Use Shield Slam to purge beneficial magic effects (BoP, shields, etc.).",
					},
				},
			},
			{
				header = "CC & Control",
				settings = {
					{
						type = "checkbox",
						key = "pvp_disarm",
						default = true,
						label = "Auto Disarm",
						tooltip = "Disarm enemy melee players (stance dances to Defensive).",
					},
					{
						type = "dropdown",
						key = "pvp_disarm_trigger",
						default = "on_burst",
						label = "Disarm Trigger",
						tooltip = "When to use Disarm.",
						options = {
							{ value = "on_cooldown", text = "On Cooldown" },
							{ value = "on_burst", text = "On Enemy Burst" },
						},
					},
					{
						type = "checkbox",
						key = "pvp_intimidating_shout",
						default = true,
						label = "Intimidating Shout",
						tooltip = "Use Intimidating Shout as interrupt backup or CC.",
					},
					{
						type = "checkbox",
						key = "pvp_concussion_blow",
						default = true,
						label = "Concussion Blow",
						tooltip = "Use Concussion Blow as stun interrupt (Prot talent).",
					},
				},
			},
			{
				header = "Interrupts (PvP)",
				settings = {
					{
						type = "checkbox",
						key = "pvp_interrupt_cc_fallback",
						default = true,
						label = "CC Interrupt Fallback",
						tooltip = "Use ConcussionBlow/IntimidatingShout/WarStomp as backup interrupts when kick is on CD.",
					},
				},
			},
			{
				header = "Defensive",
				settings = {
					{
						type = "checkbox",
						key = "pvp_def_stance_range",
						default = true,
						label = "Def Stance at Range",
						tooltip = "Auto-switch to Defensive Stance when out of melee range (reduces damage taken).",
					},
					{
						type = "checkbox",
						key = "pvp_intervene",
						default = false,
						label = "Auto Intervene",
						tooltip = "Intervene to friendly party members below 40% HP (Defensive Stance).",
					},
				},
			},
		},
	},

	-- Tab 7: Kebab
	[7] = {
		name = "Kebab",
		sections = {
			{
				header = "Core Abilities",
				settings = {
					{
						type = "checkbox",
						key = "kebab_use_overpower",
						default = true,
						label = "Use Overpower",
						tooltip = "Use Overpower on dodge procs when already in Battle Stance (avoids unnecessary stance dance).",
					},
					{
						type = "checkbox",
						key = "kebab_use_whirlwind",
						default = true,
						label = "Use Whirlwind",
						tooltip = "Use Whirlwind on cooldown (Berserker Stance).",
					},
					{
						type = "checkbox",
						key = "kebab_use_sweeping_strikes",
						default = true,
						label = "Use Sweeping Strikes",
						tooltip = "Use Sweeping Strikes on cooldown in AoE.",
					},
				},
			},
			{
				header = "Utility",
				settings = {
					{
						type = "checkbox",
						key = "kebab_use_victory_rush",
						default = true,
						label = "Use Victory Rush",
						tooltip = "Use Victory Rush (free instant attack after a killing blow, 0 rage).",
					},
				},
			},
			{
				header = "Execute Phase",
				settings = {
					{
						type = "checkbox",
						key = "kebab_execute_phase",
						default = true,
						label = "Execute Phase",
						tooltip = "Switch to Execute priority at <20% target HP.",
					},
					{
						type = "checkbox",
						key = "kebab_use_ms_execute",
						default = true,
						label = "MS During Execute",
						tooltip = "Use Mortal Strike during execute phase.",
					},
					{
						type = "checkbox",
						key = "kebab_use_ww_execute",
						default = true,
						label = "WW During Execute",
						tooltip = "Use Whirlwind during execute phase.",
					},
				},
			},
			{
				header = "Rage Dump",
				settings = {
					{
						type = "slider",
						key = "kebab_hs_rage_threshold",
						default = 40,
						min = 25,
						max = 80,
						label = "HS Rage Threshold",
						tooltip = "Queue Heroic Strike above this rage.",
						format = "%d",
					},
					{
						type = "checkbox",
						key = "kebab_hs_during_execute",
						default = false,
						label = "HS During Execute",
						tooltip = "Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage).",
					},
				},
			},
			{
				header = "Cooldowns",
				settings = {
					{
						type = "dropdown",
						key = "kebab_use_death_wish",
						default = "in_combat",
						label = "Death Wish",
						tooltip = "When to use Death Wish (+20% damage). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
					{
						type = "dropdown",
						key = "kebab_use_recklessness",
						default = "in_combat",
						label = "Recklessness",
						tooltip = "When to use Recklessness (+100% crit for 3 charges). Off = never, In Combat = on cooldown, Bloodlust = only during Bloodlust/Heroism.",
						options = {
							{ value = "off", text = "Off" },
							{ value = "in_combat", text = "In Combat" },
							{ value = "boss", text = "Boss Fight" },
							{ value = "bloodlust", text = "During Bloodlust" },
						},
					},
				},
			},
		},
	},
}

print("|cFF00FF00[Flux AIO]|r Warrior schema loaded")
