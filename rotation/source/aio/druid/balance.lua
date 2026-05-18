--- Balance Module
--- Balance (Moonkin DPS) playstyle strategies
--- Part of the modular rotation system
--- Loads after: core.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime (e.g., playstyle switching).
-- Always access settings through context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Balance]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Balance]|r Registry not found in Core!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local is_buff_active = NS.is_buff_active
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Import factory functions from Core
local create_faerie_fire_strategy = NS.create_faerie_fire_strategy
local create_combat_strategy = NS.create_combat_strategy
local named = NS.named

-- Immunity check functions
local has_magic_immunity = NS.has_magic_immunity
local ARCANE_IMMUNE = NS.ARCANE_IMMUNE
local has_nordrassil_4p = NS.has_nordrassil_4p
local Player = NS.Player
local get_spell_mana_cost = NS.get_spell_mana_cost
local IsSpellKnown = _G.IsSpellKnown

-- Lua optimizations
local format = string.format
local select = select

local function target_is_arcane_immune(unit)
   local npc_id = select(6, Unit(unit):InfoGUID())
   return npc_id and ARCANE_IMMUNE[npc_id] or false
end

-- Rank-safe cast for downranked nukes (e.g. Starfire6).
-- The framework's IsReady() check inside try_cast/safe_ability_cast returns
-- false for actions tagged with isRank = N (max-rank-only path), so we mirror
-- the holy paladin pattern: bypass IsReady and gate manually on
-- trained + mana + range. Show() builds the rank-specific macro for TMW.
local function ranked_dps_cast(spell, icon, target, prefix, name, info_fmt, ...)
   if not IsSpellKnown(spell.ID) then return nil end
   if get_spell_mana_cost(spell) > Player:Mana() then return nil end
   if spell:IsInRange(target) ~= true then return nil end
   local result = spell:Show(icon)
   if not result then return nil end
   if info_fmt then
      return result, format("%s %s - " .. info_fmt, prefix, name, ...)
   end
   return result, format("%s %s", prefix, name)
end

-- Mirrors maintain_faerie_fire dropdown semantics for Insect Swarm.
-- Returns true when the current target passes the user's IS target filter.
local function is_swarm_target_eligible(mode)
   if mode == "off" or mode == false or mode == nil then return false end
   if mode == "bosses" or mode == "elites" then
      local classification = _G.UnitClassification(TARGET_UNIT)
      if mode == "bosses" then
         return classification == "worldboss"
      end
      return classification == "worldboss" or classification == "elite" or classification == "rareelite"
   end
   return true  -- "all" or legacy boolean true
end

-- ============================================================================
-- BALANCE (MOONKIN) STRATEGIES
-- ============================================================================
do
   -- [1] Faerie Fire debuff maintenance (with refresh window)
   local Balance_FaerieFire = create_faerie_fire_strategy(Constants.BALANCE.FAERIE_FIRE_REFRESH, A.FaerieFireCaster, true)

   -- [3] Force of Nature (Treants cooldown)
   local Balance_ForceOfNature = create_combat_strategy({
      stance = Constants.STANCE.MOONKIN,
      spell = A.ForceOfNature,
      prefix = "[P2]",
      log_name = "Force of Nature",
      log_fmt = "Treants summoned, TTD: %.1fs",
      log_args = function(ctx) return ctx.ttd end,
      setting_key = "use_force_of_nature",
      extra_match = function(ctx)
         local fon_min_ttd = ctx.settings.force_of_nature_min_ttd or Constants.TTD.FORCE_OF_NATURE_MIN
         return ctx.ttd > fon_min_ttd
      end
   })
   Balance_ForceOfNature.is_burst = true

   -- [4] Innervate (mana recovery — fires when low mana in Moonkin form)
   local Balance_Innervate = {
      setting_key = "balance_use_innervate",
      matches = function(context)
         if context.stance ~= Constants.STANCE.MOONKIN then return false end
         if not context.in_combat then return false end
         if (Unit(PLAYER_UNIT):HasBuffs(A.SelfInnervate.ID) or 0) > 0 then return false end
         local threshold = context.settings.balance_innervate_mana or 20
         if context.mana_pct > threshold then return false end
         return A.SelfInnervate:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context)
         return try_cast_fmt(A.SelfInnervate, icon, PLAYER_UNIT, "[P3]", "Innervate",
                             "Mana: %.0f%%", context.mana_pct)
      end,
   }

   -- [5] AoE (Hurricane with Barkskin protection) - skip if target has magic immunity
   local Balance_AoE = {
      matches = function(context)
         if context.stance ~= Constants.STANCE.MOONKIN or not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         -- Skip if target has magic immunity (Divine Shield, Ice Block, Cloak, etc.)
         if has_magic_immunity(TARGET_UNIT) then return false end
         local min_targets = context.settings.hurricane_min_targets or Constants.AOE.HURRICANE_MIN_TARGETS
         return context.enemy_count >= min_targets and A.Hurricane:IsReady(TARGET_UNIT)
      end,
      execute = function(icon, context)
         -- Use Barkskin to protect Hurricane channel
         if A.Barkskin:IsReady(PLAYER_UNIT) and not is_buff_active(A.Barkskin, PLAYER_UNIT) then
            local bark_result = try_cast(A.Barkskin, icon, PLAYER_UNIT, "[P3] Barkskin - Protecting Hurricane channel")
            if bark_result then return bark_result end
         end
         return try_cast_fmt(A.Hurricane, icon, TARGET_UNIT, "[P3]", "Hurricane", "AoE on %d targets", context.enemy_count)
      end,
   }

   -- [5] Pull opener (initiates combat from range when not yet in combat)
   local Balance_Opener = {
      matches = function(context)
         if context.stance ~= Constants.STANCE.MOONKIN then return false end
         if context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if has_magic_immunity(TARGET_UNIT) then return false end
         return true
      end,
      execute = function(icon, context)
         local arcane_immune = target_is_arcane_immune(TARGET_UNIT)
         local is_moving = Unit(PLAYER_UNIT):IsMoving()
         if not is_moving then
            if not arcane_immune then
               -- Starfire: highest damage opener (Arcane school — skip vs arcane-immune)
               local result, msg = try_cast_fmt(A.Starfire, icon, TARGET_UNIT, "[P0]", "Starfire", "Opening pull")
               if result then return result, msg end
            end
            -- Wrath: Nature school fallback (always safe vs arcane-immune)
            local result, msg = try_cast_fmt(A.Wrath, icon, TARGET_UNIT, "[P0]", "Wrath", "Opening pull")
            if result then return result, msg end
         end
         -- Moonfire: instant cast fallback (Arcane school — skip vs arcane-immune)
         if not arcane_immune then
            local mf_on_target = (Unit(TARGET_UNIT):HasDeBuffs(A.Moonfire.ID) or 0) > 0
            if not mf_on_target then
               return try_cast_fmt(A.Moonfire, icon, TARGET_UNIT, "[P0]", "Moonfire", "Opening pull (moving)")
            end
         end
         return nil
      end,
   }

   -- [6] Main DPS rotation (DoTs + Nukes with mana tiers) - skip damage if target has magic immunity
   local Balance_DPS = {
      matches = function(context)
         return context.stance == Constants.STANCE.MOONKIN and context.in_combat and
                context.has_valid_enemy_target
      end,
      execute = function(icon, context)
         local settings = context.settings
         local mana_pct = context.mana_pct

         -- Check magic immunity (Divine Shield, Ice Block, Cloak, Grounding Totem, etc.)
         if has_magic_immunity(TARGET_UNIT) then return nil end

         -- Arcane immunity (Curator, Astral Flares, Mana Wraiths, etc.):
         -- skip Starfire/Moonfire (Arcane school), keep Wrath/Insect Swarm/Hurricane (Nature).
         local arcane_immune = target_is_arcane_immune(TARGET_UNIT)

         -- Mana tier system mirrors WoWsims adaptive hierarchy:
         --   Tier 1 (high mana)   -> sim T0: SF rank 8 + MF + IS
         --   Tier 2 (medium mana) -> sim T1: SF rank 6 + MF + IS
         --   Tier 3 (low mana)    -> sim T2: SF rank 6 + IS only (drop MF)
         local tier1_mana = settings.balance_tier1_mana or Constants.BALANCE.MANA_TIER1
         local tier2_mana = settings.balance_tier2_mana or Constants.BALANCE.MANA_TIER2
         local mana_tier = (mana_pct < tier2_mana) and 3 or (mana_pct < tier1_mana) and 2 or 1

         -- Pick Starfire rank: rank 8 in tier 1, rank 6 in tier 2/3 (when downrank enabled).
         -- Rank 6 must use ranked_dps_cast — the framework's IsReady() returns false for
         -- isRank actions, so try_cast_fmt would silently no-op.
         local downrank_enabled = settings.balance_downrank_starfire ~= false
         local use_sf6 = downrank_enabled and mana_tier >= 2

         -- 4p T5 (Nordrassil Regalia) override: force IS on at lowest mana tier
         local t5_4p_override = (mana_tier == 3) and has_nordrassil_4p()

         -- Track Nature's Grace proc
         local has_ng = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.NATURES_GRACE) or 0) > 0
         local ng_info = has_ng and " [NG]" or ""

         -- Clearcast optimization: Starfire is most expensive, cast it while free
         -- Always max rank when free (rank cost doesn't matter when cast is free).
         -- Skip vs arcane-immune (Starfire is Arcane school) — let Wrath consume Clearcast instead.
         if context.has_clearcasting and settings.clearcast_starfire ~= false and not arcane_immune then
            local result, msg = try_cast_fmt(A.Starfire, icon, TARGET_UNIT, "[P4]", "Starfire",
                                             "FREE CAST (Clearcast)%s", ng_info)
            if result then return result, msg end
         end

         -- DoT maintenance (priority over nukes)
         -- Default 0 = only reapply when absent (WoWsims behavior)
         local dot_refresh = settings.balance_dot_refresh or 0

         -- Insect Swarm (Nature school — safe vs arcane-immune).
         -- Always-on per WoWsims; user dropdown narrows by target classification.
         -- 4p T5 in tier 3 force-overrides the dropdown (mirrors sim mana-conservation rotation).
         local is_eligible = is_swarm_target_eligible(settings.maintain_insect_swarm) or t5_4p_override
         if is_eligible then
            local is_duration = Unit(TARGET_UNIT):HasDeBuffs(A.InsectSwarm.ID) or 0
            if is_duration <= dot_refresh then
               local result, msg = try_cast_fmt(A.InsectSwarm, icon, TARGET_UNIT, "[P4]", "Insect Swarm",
                                                is_duration > 0 and "REFRESH (%.1fs)" or "DoT missing, Mana: %.0f%%",
                                                is_duration > 0 and is_duration or mana_pct)
               if result then return result, msg end
            end
         end

         -- Moonfire (Arcane school — skip vs arcane-immune).
         -- Maintained in tiers 1-2 (sim T0/T1); dropped in tier 3 (sim T2 mana-conservation).
         if settings.maintain_moonfire ~= false and mana_tier <= 2 and not arcane_immune then
            local mf_duration = Unit(TARGET_UNIT):HasDeBuffs(A.Moonfire.ID) or 0
            if mf_duration <= dot_refresh then
               local result, msg = try_cast_fmt(A.Moonfire, icon, TARGET_UNIT, "[P5]", "Moonfire",
                                                mf_duration > 0 and "REFRESH (%.1fs)" or "DoT missing, Mana: %.0f%%",
                                                mf_duration > 0 and mf_duration or mana_pct)
               if result then return result, msg end
            end
         end

         -- Nukes
         local tier_info = mana_tier == 1 and "Tier1" or (mana_tier == 2 and "Tier2" or "Tier3")

         -- Nature's Grace optimization: Wrath becomes near-instant (~1.0s) during NG proc.
         -- Also forced when arcane-immune (Wrath is the only viable nuke).
         if (arcane_immune or (has_ng and settings.ng_wrath_priority)) then
            local result, msg = try_cast_fmt(A.Wrath, icon, TARGET_UNIT, "[P6]", "Wrath",
                                             arcane_immune and "%s Mana: %.0f%% [ARCANE IMMUNE]" or "%s Mana: %.0f%% [NG PROC]",
                                             tier_info, mana_pct)
            if result then return result, msg end
         end

         -- Starfire: Primary nuke (rank-aware; Arcane school — skip vs arcane-immune)
         if not arcane_immune then
            local result, msg
            if use_sf6 then
               result, msg = ranked_dps_cast(A.Starfire6, icon, TARGET_UNIT, "[P6]", "Starfire-R6",
                                             "%s Mana: %.0f%%%s", tier_info, mana_pct, ng_info)
            else
               result, msg = try_cast_fmt(A.Starfire, icon, TARGET_UNIT, "[P6]", "Starfire",
                                          "%s Mana: %.0f%%%s", tier_info, mana_pct, ng_info)
            end
            if result then return result, msg end
         end

         -- Wrath: Fallback (faster cast, lower damage per mana)
         return try_cast_fmt(A.Wrath, icon, TARGET_UNIT, "[P7]", "Wrath",
                             "Fallback cast%s", ng_info)
      end,
   }

   -- Register all Balance strategies (array order = execution priority)
   rotation_registry:register("balance", {
      named("FaerieFire",      Balance_FaerieFire),
      named("ForceOfNature",   Balance_ForceOfNature),
      named("Innervate",       Balance_Innervate),
      named("AoE",             Balance_AoE),
      named("Opener",          Balance_Opener),
      named("DPS",             Balance_DPS),
   })

end  -- End Balance strategies do...end block

print("|cFF00FF00[Flux AIO Balance]|r 6 Balance strategies registered.")
