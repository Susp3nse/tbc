--- Resto Module
--- Tree of Life (Restoration) playstyle strategies
--- Part of the modular rotation system
--- Loads after: core.lua, healing.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime (e.g., playstyle switching).
-- Always access settings through context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Resto]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Resto]|r Registry not found in Core!")
   return
end
if not NS.scan_healing_targets then
   print("|cFFFF0000[Flux AIO Resto]|r Healing module not loaded!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Priority = NS.Priority
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast_fmt = NS.try_cast_fmt
local try_heal_cast_fmt = NS.try_heal_cast_fmt
local is_spell_available = NS.is_spell_available
local cast_best_heal_rank = NS.cast_best_heal_rank
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local REGROWTH_RANKS = NS.REGROWTH_RANKS

-- Import from Healing module
local scan_healing_targets = NS.scan_healing_targets

-- Framework utilities
local AuraIsValid = A.AuraIsValid

-- Lua optimizations
local named = NS.named
local format = string.format

-- Lifebloom spell ID (single rank in TBC)
local LIFEBLOOM_ID = 33763
local NATURES_SWIFTNESS_ID = 17116

-- ============================================================================
-- PRE-ALLOCATED SPELL OPTION TABLES
-- WoW secure execution: no inline table creation in combat paths
-- ============================================================================
local regrowth_heal_options = {
   overheal_threshold = 1.3,
   prioritize_speed = false,
   prioritize_efficiency = false,
   mana_floor = 0,
}

-- ============================================================================
-- SHARED RESTO STATE (context_builder pattern)
-- Pre-allocated, reused each frame via context._resto_valid cache flag
-- ============================================================================
local resto_state = {
   tank = nil,               -- tank target entry from scan_healing_targets
   lowest = nil,             -- lowest HP target overall
   emergency_target = nil,   -- lowest target below emergency threshold
   swiftmend_target = nil,   -- lowest target below Swiftmend threshold with a HoT
   regrowth_target = nil,    -- lowest target below standard threshold without Regrowth
   rejuv_target = nil,       -- lowest target below proactive threshold without Rejuv
   emergency_count = 0,      -- count of targets below emergency_hp
   tank_lb_stacks = 0,       -- Lifebloom stack count on tank (0-3)
   tank_lb_duration = 0,     -- Lifebloom remaining duration on tank (seconds)
   cursed_target = nil,      -- first party member with a Curse debuff
   poisoned_target = nil,    -- first party member with Poison (no Abolish active)
}

local function get_resto_state(context)
   if context._resto_valid then return resto_state end
   context._resto_valid = true

   local targets, count = scan_healing_targets()
   local settings = context.settings
   local emergency_hp = settings.resto_emergency_hp or Constants.RESTO.EMERGENCY_HP
   local swiftmend_hp = settings.resto_swiftmend_hp or Constants.RESTO.SWIFTMEND_HP
   local standard_hp = settings.resto_standard_heal_hp or Constants.RESTO.STANDARD_HEAL_HP
   local proactive_hp = settings.resto_proactive_hp or Constants.RESTO.PROACTIVE_HP

   -- Reset state
   resto_state.tank = nil
   resto_state.lowest = nil
   resto_state.emergency_target = nil
   resto_state.swiftmend_target = nil
   resto_state.regrowth_target = nil
   resto_state.rejuv_target = nil
   resto_state.emergency_count = 0
   resto_state.tank_lb_stacks = 0
   resto_state.tank_lb_duration = 0
   resto_state.cursed_target = nil
   resto_state.poisoned_target = nil

   if not NS.is_in_party() and not NS.is_in_raid() and not context.has_valid_enemy_target then
      return resto_state
   end

   for i = 1, count do
      local entry = targets[i]
      if entry then
         -- Lowest HP (targets sorted ascending by HP, first = lowest)
         if not resto_state.lowest then
            resto_state.lowest = entry
         end

         -- Emergency count (use effective_hp to avoid overcounting when heals are incoming)
         if entry.effective_hp < emergency_hp then
            resto_state.emergency_count = resto_state.emergency_count + 1
            if not resto_state.emergency_target then
               resto_state.emergency_target = entry
            end
         end

         if not resto_state.swiftmend_target
            and entry.effective_hp < swiftmend_hp
            and (entry.has_rejuv or entry.has_regrowth) then
            resto_state.swiftmend_target = entry
         end

         if not resto_state.regrowth_target
            and entry.effective_hp < standard_hp
            and not entry.has_regrowth then
            resto_state.regrowth_target = entry
         end

         if not resto_state.rejuv_target
            and entry.effective_hp < proactive_hp
            and not entry.has_rejuv then
            resto_state.rejuv_target = entry
         end

         -- Tank identification + Lifebloom tracking
         if entry.is_tank and not resto_state.tank then
            resto_state.tank = entry
            local lb_dur = Unit(entry.unit):HasBuffs(LIFEBLOOM_ID, "player", true) or 0
            if lb_dur > 0 then
               resto_state.tank_lb_stacks = Unit(entry.unit):HasBuffsStacks(LIFEBLOOM_ID, "player", true) or 0
               resto_state.tank_lb_duration = lb_dur
            end
         end

         -- Dispel tracking (uses framework AuraIsValid whitelist for smart filtering)
         if settings.resto_auto_dispel_curse and not resto_state.cursed_target then
            if AuraIsValid(entry.unit, "UseDispel", "Curse") then
               resto_state.cursed_target = entry
            end
         end
         if settings.resto_auto_dispel_poison and not resto_state.poisoned_target then
            -- Only flag if Abolish Poison is not already ticking
            local abolish_active = (Unit(entry.unit):HasBuffs(2893, nil, true) or 0) > 0
            if not abolish_active and AuraIsValid(entry.unit, "UseDispel", "Poison") then
               resto_state.poisoned_target = entry
            end
         end
      end
   end

   return resto_state
end

-- ============================================================================
-- TREE RESHIFT MIDDLEWARE (NS+HT leaves Tree; this gets us back)
-- ============================================================================
local pending_tree_reshift = false

rotation_registry:register_middleware({
   name = "Resto_TreeReshift",
   priority = Priority.MIDDLEWARE.FORM_RESHIFT,

   matches = function(context)
      if not pending_tree_reshift then return false end
      -- Already back in a form (or never left)? Clear flag
      if context.stance ~= Constants.STANCE.CASTER then
         pending_tree_reshift = false
         return false
      end
      return true
   end,

   execute = function(icon, context)
      if A.TreeOfLifeForm:IsReady(PLAYER_UNIT) then
         pending_tree_reshift = false
         return A.TreeOfLifeForm:Show(icon), "[RESTO] Reshifting to Tree of Life"
      end
      return nil
   end,
})

-- ============================================================================
-- TREE OF LIFE RESTORATION STRATEGIES
-- ============================================================================
do
   -- [1] Emergency Swiftmend (instant burst on critically low target with HoT)
   local Resto_EmergencySwiftmend = {
      matches = function(context, state)
         if not state.emergency_target then return false end
         if not is_spell_available(A.Swiftmend) then return false end
         local target = state.emergency_target
         return (target.has_rejuv or target.has_regrowth) and A.Swiftmend:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.emergency_target
         if not target then return nil end
         return try_heal_cast_fmt(A.Swiftmend, icon, target.unit, "[P15]", "EMERGENCY Swiftmend",
                             "on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [2] Emergency NS + Healing Touch (leave Tree for biggest instant heal)
   -- Macro: /cast NS (off-GCD) → /cancelform → Healing Touch (instant from NS). One frame.
   -- TreeReshift middleware handles getting back to Tree on the next frame.
   local Resto_EmergencyNSHealingTouch = {
      matches = function(context, state)
         if not state.emergency_target then return false end
         if not context.settings.resto_ns_healing_touch then return false end
         if not is_spell_available(A.NaturesSwiftness) then return false end
         if state.emergency_target.hp >= (context.settings.resto_emergency_hp or Constants.RESTO.EMERGENCY_HP) then return false end
         return A.NaturesSwiftness:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.emergency_target
         if not target then return nil end
         -- Flag reshift so middleware returns us to Tree next frame
         pending_tree_reshift = true
         -- Manual HE targeting (bypass safe_heal_cast IsReady — HT not usable in Tree,
         -- but macrobefore handles /cancelform before the spell fires)
         local HE = A.HealingEngine
         if HE and HE.SetTarget then HE.SetTarget(target.unit) end
         A.NSHealingTouch13.Click.unit = target.unit
         return A.NSHealingTouch13:Show(icon), format("[P14] EMERGENCY NS+HT on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [3] Emergency NS + Regrowth (instant big heal, both castable in Tree form)
   local Resto_EmergencyNSRegrowth = {
      matches = function(context, state)
         if not state.emergency_target then return false end
         if not is_spell_available(A.NaturesSwiftness) then return false end
         if not is_spell_available(A.Regrowth10) then return false end
         if (Unit(PLAYER_UNIT):HasBuffs(NATURES_SWIFTNESS_ID) or 0) > 0 then
            return A.Regrowth10:IsReady(PLAYER_UNIT)
         end
         return A.NaturesSwiftness:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.emergency_target
         if not target then return nil end
         if (Unit(PLAYER_UNIT):HasBuffs(NATURES_SWIFTNESS_ID) or 0) == 0 then
            return try_cast_fmt(A.NaturesSwiftness, icon, PLAYER_UNIT, "[P14]", "Nature's Swiftness",
                                "prep Regrowth on %s (%.0f%%)", target.unit, target.hp)
         end
         return try_heal_cast_fmt(A.Regrowth10, icon, target.unit, "[P14]", "EMERGENCY NS+Regrowth",
                             "on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [3] Emergency Barkskin (self-defense when taking heavy damage)
   local Resto_EmergencyBarkskin = {
      requires_combat = true,
      is_gcd_gated = false, -- off-GCD ability
      matches = function(context, state)
         local emergency_hp = context.settings.resto_emergency_hp or Constants.RESTO.EMERGENCY_HP
         return context.hp < emergency_hp and A.Barkskin:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.Barkskin, icon, PLAYER_UNIT, "[P13]", "EMERGENCY Barkskin",
                             "Self HP %.0f%%", context.hp)
      end,
   }

   -- [4] Lifebloom Tank (core Tree mechanic: maintain 3-stack rolling on tank)
   local Resto_LifebloomTank = {
      matches = function(context, state)
         if not state.tank then return false end
         if not is_spell_available(A.Lifebloom) then return false end
         if not context.settings.resto_prioritize_tank then return false end
         local stacks = state.tank_lb_stacks
         local duration = state.tank_lb_duration
         local refresh = context.settings.resto_lifebloom_refresh or Constants.RESTO.LIFEBLOOM_REFRESH
         -- Cast if: no Lifebloom yet, building stacks, or 3-stack expiring soon
         if stacks == 0 then return true end
         if stacks < 3 then return true end
         return duration > 0 and duration <= refresh
      end,
      execute = function(icon, context, state)
         local tank = state.tank
         if not tank or not A.Lifebloom:IsReady(PLAYER_UNIT) then return nil end
         local action = (state.tank_lb_stacks >= 3) and "Refresh"
            or format("Stack %d->%d", state.tank_lb_stacks, state.tank_lb_stacks + 1)
         return try_heal_cast_fmt(A.Lifebloom, icon, tank.unit, "[P10]", "Tank Lifebloom",
                             "%s on %s (%.0f%%) [%.0fs left]",
                             action, tank.unit, tank.hp, state.tank_lb_duration)
      end,
   }

   -- [5] Swiftmend Urgent (burst heal on moderate-low target with HoT)
   local Resto_SwiftmendUrgent = {
      matches = function(context, state)
         if not is_spell_available(A.Swiftmend) then return false end
         return state.swiftmend_target and A.Swiftmend:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.swiftmend_target
         if not target then return nil end
         return try_heal_cast_fmt(A.Swiftmend, icon, target.unit, "[P8]", "Swiftmend",
                             "on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [6] Rejuvenation on Tank (keep HoT up for Swiftmend and steady healing)
   local Resto_RejuvTank = {
      matches = function(context, state)
         if not state.tank then return false end
         if not context.settings.resto_prioritize_tank then return false end
         return not state.tank.has_rejuv
      end,
      execute = function(icon, context, state)
         local tank = state.tank
         if not tank or not A.Rejuvenation13:IsReady(PLAYER_UNIT) then return nil end
         return try_heal_cast_fmt(A.Rejuvenation13, icon, tank.unit, "[P7]", "Tank Rejuv",
                             "on %s (%.0f%%)", tank.unit, tank.hp)
      end,
   }

   -- [8] Regrowth on Tank (maintain max rank Regrowth HoT per TBC guide)
   local Resto_RegrowthTank = {
      matches = function(context, state)
         if not state.tank then return false end
         if not context.settings.resto_prioritize_tank then return false end
         if state.tank.has_regrowth then return false end
         local mana_conserve = context.settings.resto_mana_conserve or 40
         if context.mana_pct < mana_conserve then return false end
         return A.Regrowth10:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local tank = state.tank
         if not tank then return nil end
         return try_heal_cast_fmt(A.Regrowth10, icon, tank.unit, "[P6]", "Tank Regrowth",
                             "on %s (%.0f%%)", tank.unit, tank.hp)
      end,
   }

   -- [9] Regrowth on low HP targets (direct heal + HoT, mana-gated)
   local Resto_RegrowthLow = {
      matches = function(context, state)
         local mana_conserve = context.settings.resto_mana_conserve or 40
         if context.mana_pct < mana_conserve then return false end
         return state.regrowth_target ~= nil
      end,
      execute = function(icon, context, state)
         local target = state.regrowth_target
         if not target or target.has_regrowth then return nil end
         local result, rank_info = cast_best_heal_rank(REGROWTH_RANKS, icon, target.unit, context, "Regrowth", regrowth_heal_options)
         if result then
            return result, format("[P6] Regrowth %s on %s (%.0f%%)", rank_info or "", target.unit, target.hp)
         end
         return nil
      end,
   }

   -- [8] Rejuvenation spread (HoT blanketing on injured members)
   local Resto_RejuvSpread = {
      matches = function(context, state)
         return state.rejuv_target ~= nil
      end,
      execute = function(icon, context, state)
         local target = state.rejuv_target
         if not target then return nil end
         if A.Rejuvenation13:IsReady(PLAYER_UNIT) then
            return try_heal_cast_fmt(A.Rejuvenation13, icon, target.unit, "[P4]", "Rejuv Spread",
                                "on %s (%.0f%%)", target.unit, target.hp)
         end
         return nil
      end,
   }

   -- [9] Remove Curse (party-wide, castable in Tree form)
   local Resto_DispelCurse = {
      matches = function(context, state)
         return state.cursed_target ~= nil and A.RemoveCurse:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.cursed_target
         if not target then return nil end
         return try_heal_cast_fmt(A.RemoveCurse, icon, target.unit, "[P3]", "Remove Curse",
                             "on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [10] Abolish Poison (party-wide, castable in Tree form)
   local Resto_DispelPoison = {
      matches = function(context, state)
         return state.poisoned_target ~= nil and A.AbolishPoison:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         local target = state.poisoned_target
         if not target then return nil end
         return try_heal_cast_fmt(A.AbolishPoison, icon, target.unit, "[P2]", "Abolish Poison",
                             "on %s (%.0f%%)", target.unit, target.hp)
      end,
   }

   -- [11] Tranquility (emergency AoE heal, 10min CD, castable in Tree form)
   local Resto_Tranquility = {
      matches = function(context, state)
         if state.emergency_count < 3 then return false end
         if not is_spell_available(A.Tranquility) then return false end
         return A.Tranquility:IsReady(PLAYER_UNIT)
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.Tranquility, icon, PLAYER_UNIT, "[P1]", "Tranquility",
                             "%d members critical", state.emergency_count)
      end,
   }

   -- Register all Resto strategies (array order = execution priority)
   rotation_registry:register("resto", {
      named("EmergencySwiftmend",      Resto_EmergencySwiftmend),      -- [1]  Instant emergency burst (consumes HoT)
      named("EmergencyNSHealingTouch", Resto_EmergencyNSHealingTouch), -- [2]  NS+HT (leaves Tree briefly)
      named("EmergencyNSRegrowth",     Resto_EmergencyNSRegrowth),     -- [3]  NS+Regrowth fallback (stays in Tree)
      named("EmergencyBarkskin",       Resto_EmergencyBarkskin),       -- [4]  Self-defense (off-GCD)
      named("LifebloomTank",           Resto_LifebloomTank),           -- [5]  Core mechanic: roll 3-stack on tank
      named("SwiftmendUrgent",         Resto_SwiftmendUrgent),         -- [6]  Burst heal on moderate-low targets
      named("RejuvTank",               Resto_RejuvTank),               -- [7]  Keep Rejuv on tank for Swiftmend
      named("RegrowthTank",            Resto_RegrowthTank),            -- [8]  Keep Regrowth on tank (TBC guide)
      named("RegrowthLow",             Resto_RegrowthLow),             -- [9]  Regrowth on injured (mana-gated)
      named("RejuvSpread",             Resto_RejuvSpread),             -- [10] HoT blanketing
      named("DispelCurse",             Resto_DispelCurse),             -- [11] Party curse removal
      named("DispelPoison",            Resto_DispelPoison),            -- [12] Party poison removal
      named("Tranquility",             Resto_Tranquility),             -- [13] Emergency AoE heal (long CD)
   }, { context_builder = get_resto_state })

end  -- End Resto strategies do...end block

print("|cFF00FF00[Flux AIO Resto]|r 13 Tree of Life strategies + 1 middleware registered.")
