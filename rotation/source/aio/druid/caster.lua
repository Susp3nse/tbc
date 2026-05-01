--- Caster Module
--- Self-care strategies for caster form (heals, dispels, innervate, self-buffs)
--- Part of the modular AIO rotation system
--- Loads after: core.lua, healing.lua

-- ============================================================
-- This module defines the "caster" playstyle strategies.
-- The dispatcher runs these whenever the player is in caster
-- form (before the active playstyle's strategies), so any spec
-- that shifts to caster gets self-care automatically.
--
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime. Always access through
-- context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
	print("|cFFFF0000[Flux AIO Caster]|r Core module not loaded!")
	return
end

-- Validate dependencies
if not NS.rotation_registry then
	print("|cFFFF0000[Flux AIO Caster]|r Registry not found in Core!")
	return
end
-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local safe_ability_cast = NS.safe_ability_cast
local safe_self_cast = NS.safe_self_cast
local get_spell_mana_cost = NS.get_spell_mana_cost
local get_form_cost = NS.get_form_cost
local has_any_rejuv = NS.has_any_rejuv
local has_any_regrowth = NS.has_any_regrowth
local cast_best_heal_rank = NS.cast_best_heal_rank
local proactive_heal_options = NS.proactive_heal_options
local emergency_heal_options = NS.emergency_heal_options
local HEALING_TOUCH_RANKS = NS.HEALING_TOUCH_RANKS
local REGROWTH_RANKS = NS.REGROWTH_RANKS
local REJUVENATION_RANKS = NS.REJUVENATION_RANKS
-- Self-cast rank tables have Click = { unit = "player" } baked in at creation time
-- This reliably forces @player targeting regardless of current target selection
local SELF_HEALING_TOUCH_RANKS = NS.SELF_HEALING_TOUCH_RANKS
local SELF_REGROWTH_RANKS = NS.SELF_REGROWTH_RANKS
local SELF_REJUVENATION_RANKS = NS.SELF_REJUVENATION_RANKS
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Framework utilities
local AuraIsValid = A.AuraIsValid

-- Lua optimizations
local named = NS.named
local format = string.format
local ipairs = ipairs

-- ============================================================================
-- CASTER SELF-CARE STRATEGIES
-- ============================================================================
do
	-- [1] Emergency Healing (critical/emergency HP)
	local Caster_EmergencyHeal = {
		suggestion_spell = A.Regrowth5,
		matches = function(context)
			if context.stance ~= Constants.STANCE.CASTER then return false end
			local settings = context.settings
			local emergency_hp, critical_hp = settings.emergency_heal_hp, settings.critical_heal_hp
			local is_critical = critical_hp and context.hp <= critical_hp
			local is_emergency = emergency_hp and context.hp <= emergency_hp
			if not (is_critical or is_emergency) then
				return false
			end
			if not is_critical and context.mana_pct < 10 then
				return false
			end
			for _, rank in ipairs(REGROWTH_RANKS) do
				if rank.spell:IsExists() then
					return true
				end
			end
			for _, rank in ipairs(HEALING_TOUCH_RANKS) do
				if rank.spell:IsExists() then
					return true
				end
			end
			for _, rank in ipairs(REJUVENATION_RANKS) do
				if rank.spell:IsExists() then
					return true
				end
			end
			return false
		end,
		should_suggest = function(context)
			local settings = context.settings
			local emergency_hp, critical_hp = settings.emergency_heal_hp, settings.critical_heal_hp
			return (critical_hp and context.hp <= critical_hp) or (emergency_hp and context.hp <= emergency_hp) or false
		end,
		execute = function(icon, context)
			local settings = context.settings
			local emergency_hp, critical_hp = settings.emergency_heal_hp, settings.critical_heal_hp
			local severity = (critical_hp and context.hp <= critical_hp) and "crit" or "emrg"
			local is_low_mana = context.mana_pct < 20
			local has_rejuv, has_regrowth = has_any_rejuv(PLAYER_UNIT), has_any_regrowth(PLAYER_UNIT)
			emergency_heal_options.prioritize_efficiency = is_low_mana
			emergency_heal_options.prioritize_speed = (severity == "crit") and not is_low_mana
			emergency_heal_options.mana_floor = 0
			-- Standard emergency healing (SELF_ rank tables have Click = { unit = "player" } baked in)
			if not has_rejuv then
				local result, spell_info = cast_best_heal_rank(
					SELF_REJUVENATION_RANKS,
					icon,
					PLAYER_UNIT,
					context,
					"Rejuv",
					emergency_heal_options
				)
				if result then
					return result, format("[HEAL] HP: %.1f M: %.1f -> %s", context.hp, context.mana_pct, spell_info)
				end
			end
			if not has_regrowth then
				local result, spell_info = cast_best_heal_rank(
					SELF_REGROWTH_RANKS,
					icon,
					PLAYER_UNIT,
					context,
					"Regrowth",
					emergency_heal_options
				)
				if result then
					return result, format("[HEAL] HP: %.1f M: %.1f -> %s", context.hp, context.mana_pct, spell_info)
				end
			end
			if has_rejuv or has_regrowth then
				local result, spell_info = cast_best_heal_rank(
					SELF_HEALING_TOUCH_RANKS,
					icon,
					PLAYER_UNIT,
					context,
					"HT",
					emergency_heal_options
				)
				if result then
					return result, format("[HEAL] HP: %.1f M: %.1f -> %s", context.hp, context.mana_pct, spell_info)
				end
			end
			return nil
		end,
	}

	-- [2] Proactive Healing (HoT maintenance)
	local Caster_ProactiveHeal = {
		suggestion_spell = A.Rejuvenation7,
		matches = function(context)
			if context.stance ~= Constants.STANCE.CASTER then return false end
			local settings = context.settings
			local rejuv_hp, regrowth_hp = settings.rejuvenation_hp, settings.regrowth_hp
			if not rejuv_hp and not regrowth_hp then
				return false
			end
			local needs_rejuv = rejuv_hp and context.hp <= rejuv_hp and not has_any_rejuv(PLAYER_UNIT)
			local needs_regrowth = regrowth_hp and context.hp <= regrowth_hp and not has_any_regrowth(PLAYER_UNIT)
			if not (needs_rejuv or needs_regrowth) then
				return false
			end
			local mana_reserve = settings.mana_reserve
			local heal_cost = get_spell_mana_cost(A.Rejuvenation7) or 260
			local shift_buffer = get_form_cost(A.BearForm)
			if context.mana < (mana_reserve + heal_cost + shift_buffer) then
				return false
			end
			return true
		end,
		should_suggest = function(context)
			local settings = context.settings
			local rejuv_hp, regrowth_hp = settings.rejuvenation_hp, settings.regrowth_hp
			if not rejuv_hp and not regrowth_hp then
				return false
			end
			local needs_rejuv = rejuv_hp and context.hp <= rejuv_hp and not has_any_rejuv(PLAYER_UNIT)
			local needs_regrowth = regrowth_hp and context.hp <= regrowth_hp and not has_any_regrowth(PLAYER_UNIT)
			return (needs_rejuv or needs_regrowth) or false
		end,
		execute = function(icon, context)
			local settings = context.settings
			local rejuv_hp, regrowth_hp = settings.rejuvenation_hp, settings.regrowth_hp
			local has_rejuv, has_regrowth = has_any_rejuv(PLAYER_UNIT), has_any_regrowth(PLAYER_UNIT)
			proactive_heal_options.prioritize_speed = false
			proactive_heal_options.prioritize_efficiency = false
			proactive_heal_options.mana_floor = 0
			-- SELF_ rank tables have Click = { unit = "player" } baked in
			if rejuv_hp and context.hp <= rejuv_hp and not has_rejuv then
				local result, spell_info = cast_best_heal_rank(
					SELF_REJUVENATION_RANKS,
					icon,
					PLAYER_UNIT,
					context,
					"Rejuv",
					proactive_heal_options
				)
				if result then
					return result,
						format("[PROACTIVE] HP: %.0f%% <= %d -> %s", context.hp, rejuv_hp, spell_info or "Rejuv")
				end
			end
			if regrowth_hp and context.hp <= regrowth_hp and not has_regrowth then
				local result, spell_info = cast_best_heal_rank(
					SELF_REGROWTH_RANKS,
					icon,
					PLAYER_UNIT,
					context,
					"Regrowth",
					proactive_heal_options
				)
				if result then
					return result,
						format("[PROACTIVE] HP: %.0f%% <= %d -> %s", context.hp, regrowth_hp, spell_info or "Regrowth")
				end
			end
			return nil
		end,
	}

	-- [3] Remove Curse (uses framework AuraIsValid whitelist for smart dispel filtering)
	local Caster_RemoveCurse = {
		suggestion_spell = A.SelfRemoveCurse,
		matches = function(context)
			if context.stance ~= Constants.STANCE.CASTER then return false end
			if not context.settings.auto_remove_curse then
				return false
			end
			return AuraIsValid(PLAYER_UNIT, "UseDispel", "Curse") and A.SelfRemoveCurse:IsReady(PLAYER_UNIT)
		end,
		should_suggest = function(context)
			if not context.settings.auto_remove_curse then
				return false
			end
			return AuraIsValid(PLAYER_UNIT, "UseDispel", "Curse") and A.SelfRemoveCurse:IsReady(PLAYER_UNIT)
		end,
		execute = function(icon, context)
			local result = safe_ability_cast(A.SelfRemoveCurse, icon, PLAYER_UNIT)
			if result then
				return result, "[DISPEL] Casting Remove Curse"
			end
			return nil
		end,
	}

	-- [4] Abolish Poison (uses framework AuraIsValid whitelist for smart dispel filtering)
	local Caster_AbolishPoison = {
		suggestion_spell = A.SelfAbolishPoison,
		matches = function(context)
			if context.stance ~= Constants.STANCE.CASTER then return false end
			if not context.settings.auto_remove_poison then
				return false
			end
			return AuraIsValid(PLAYER_UNIT, "UseDispel", "Poison") and A.SelfAbolishPoison:IsReady(PLAYER_UNIT)
		end,
		should_suggest = function(context)
			if not context.settings.auto_remove_poison then
				return false
			end
			return AuraIsValid(PLAYER_UNIT, "UseDispel", "Poison") and A.SelfAbolishPoison:IsReady(PLAYER_UNIT)
		end,
		execute = function(icon, context)
			local result = safe_ability_cast(A.SelfAbolishPoison, icon, PLAYER_UNIT)
			if result then
				return result, "[DISPEL] Casting Abolish Poison"
			end
			return nil
		end,
	}

	-- [5] Innervate (solo only)
	local Caster_Innervate = {
		suggestion_spell = A.SelfInnervate,
		matches = function(context)
			local settings = context.settings
			if not settings.use_innervate_self then
				return false
			end
			if _G.IsInRaid() or _G.GetNumGroupMembers() > 0 then
				return false
			end
			if (Unit(PLAYER_UNIT):HasBuffs(A.SelfInnervate.ID) or 0) > 0 then
				return false
			end
			return context.mana_pct <= settings.innervate_mana and A.SelfInnervate:IsReady(PLAYER_UNIT)
		end,
		should_suggest = function(context)
			local settings = context.settings
			if not settings.use_innervate_self then
				return false
			end
			if not A.SelfInnervate:IsReady(PLAYER_UNIT) then
				return false
			end
			if _G.IsInRaid() or _G.GetNumGroupMembers() > 0 then
				return false
			end
			if (Unit(PLAYER_UNIT):HasBuffs(A.SelfInnervate.ID) or 0) > 0 then
				return false
			end
			return context.mana_pct <= settings.innervate_mana
		end,
		execute = function(icon, context)
			local result = safe_ability_cast(A.SelfInnervate, icon, PLAYER_UNIT)
			if result then
				return result, format("[BUFF] Innervate - Mana: %.1f%% (solo)", context.mana_pct)
			end
			return nil
		end,
	}

	-- Self-buff helpers
	-- 24752
	local MOTW_GOTW_BUFF_IDS = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991 }

	local function create_self_buff_strategy(spell, name, buff_ids, settings_key, caster_only)
		local function missing_buff()
			if buff_ids then
				return (Unit(PLAYER_UNIT):HasBuffs(buff_ids, nil, true) or 0) == 0
			end
			return (Unit(PLAYER_UNIT):HasBuffs(spell.ID) or 0) == 0
		end

		return {
			suggestion_spell = spell,
			matches = function(context)
				if settings_key and not context.settings[settings_key] then
					return false
				end
				if context.in_combat then
					return false
				end
				if caster_only and context.stance ~= Constants.STANCE.CASTER then
					return false
				end
				if not spell:IsReady(PLAYER_UNIT) then
					return false
				end
				return missing_buff()
			end,
			should_suggest = function(context)
				if settings_key and not context.settings[settings_key] then
					return false
				end
				if context.in_combat then
					return false
				end
				if caster_only and context.stance ~= Constants.STANCE.CASTER then
					return false
				end
				if not spell:IsReady(PLAYER_UNIT) then
					return false
				end
				return missing_buff()
			end,
			execute = function(icon, context)
				local result = safe_self_cast(spell, icon)
				if result then
					return result, format("[BUFF] Casting %s (Mana: %d)", name, context.mana)
				end
				return nil
			end,
		}
	end

	-- [6-8] Self-buffs (OOC only)
	local Caster_MotW =
		create_self_buff_strategy(A.SelfMarkOfTheWild, "Mark of the Wild", MOTW_GOTW_BUFF_IDS, "use_motw", true)
	local Caster_Thorns = create_self_buff_strategy(A.SelfThorns, "Thorns", NS.THORNS_BUFF_IDS, "use_thorns")
	local Caster_OoC = create_self_buff_strategy(A.SelfOmenOfClarity, "Omen of Clarity", nil, "use_ooc")

	-- Register all caster strategies (array order = execution priority)
	rotation_registry:register("caster", {
		named("EmergencyHeal", Caster_EmergencyHeal),
		named("ProactiveHeal", Caster_ProactiveHeal),
		named("RemoveCurse", Caster_RemoveCurse),
		named("AbolishPoison", Caster_AbolishPoison),
		named("Innervate", Caster_Innervate),
		named("MarkOfTheWild", Caster_MotW),
		named("Thorns", Caster_Thorns),
		named("OmenOfClarity", Caster_OoC),
	})
end

print("|cFF00FF00[Flux AIO Caster]|r 8 Caster strategies registered.")
