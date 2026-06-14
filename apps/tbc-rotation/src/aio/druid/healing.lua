-- Druid Healing Module
-- Healing utilities, spell rank selection
-- Loads after: core.lua, druid/class.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local NS = _G.Menagerie
if not NS then
   print("|cFFFF0000[Menagerie Healing]|r Core module not loaded!")
   return
end

if not NS.Constants then
   print("|cFFFF0000[Menagerie Healing]|r Constants not found in Core!")
   return
end
if not NS.HEALING_TOUCH_RANKS then
   print("|cFFFF0000[Menagerie Healing]|r Healing ranks not found in Core!")
   return
end

-- Import commonly used references
local Unit = NS.Unit
local cached_settings = NS.cached_settings
local debug_print = NS.debug_print
local round_half = NS.round_half
local safe_heal_cast = NS.safe_heal_cast
local get_spell_mana_cost = NS.get_spell_mana_cost
local predict_effective_deficit = NS.predict_effective_deficit
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local REJUVENATION_BUFF_IDS = NS.REJUVENATION_BUFF_IDS
local REGROWTH_BUFF_IDS = NS.REGROWTH_BUFF_IDS

-- Lua optimizations
local tsort = table.sort

-- ============================================================================
-- PRE-ALLOCATED SPELL OPTION TABLES
-- ============================================================================

local proactive_heal_options = {
   overheal_threshold = 1.3,
   prioritize_speed = false,
   prioritize_efficiency = false,
   mana_floor = 0
}

local emergency_heal_options = {
   overheal_threshold = 1.2,
   prioritize_speed = false,
   prioritize_efficiency = false,
   mana_floor = 0
}

NS.proactive_heal_options = proactive_heal_options
NS.emergency_heal_options = emergency_heal_options

-- ============================================================================
-- MANA AFFORDABILITY CHECK
-- ============================================================================

local function can_afford_spell(spell, context, use_fresh_mana, mana_floor)
   local cost = get_spell_mana_cost(spell)
   if cost == 0 then return true end

   local current_mana = context.mana
   mana_floor = mana_floor or 0

   local cost_with_margin = cost * 1.05
   local can_pay_cost = current_mana >= cost_with_margin

   local mana_after_cast = current_mana - cost
   local stays_above_floor = mana_after_cast >= mana_floor

   local affordable = can_pay_cost and stays_above_floor

   if not affordable and cached_settings.debug_mode and debug_print then
      if not can_pay_cost then
         debug_print("[MANA CHECK] FAILED - Current:", current_mana, "Need:", cost_with_margin, "Spell:", spell:Info())
      elseif not stays_above_floor then
         debug_print("[MANA CHECK] BLOCKED - Would drop below floor. Current:", current_mana, "Cost:", cost, "Floor:", mana_floor, "Spell:", spell:Info())
      end
   end

   return affordable
end

-- ============================================================================
-- HOT DETECTION UTILITIES
-- ============================================================================

local function has_any_rejuv(target)
   return (Unit(target):HasBuffs(REJUVENATION_BUFF_IDS, nil, true) or 0) > 0
end

local function has_any_regrowth(target)
   return (Unit(target):HasBuffs(REGROWTH_BUFF_IDS, nil, true) or 0) > 0
end

local function has_any_lifebloom(target)
   return (Unit(target):HasBuffs(33763, "player", true) or 0) > 0
end

local function has_buff(target, buff_ids, source)
   return (Unit(target):HasBuffs(buff_ids, source, true) or 0) > 0
end

local function missing_buff(target, buff_ids, source)
   return not has_buff(target, buff_ids, source)
end

local function is_player_unit(unit)
   return unit and _G.UnitExists(unit) and _G.UnitIsPlayer(unit)
end

-- ============================================================================
-- PARTY/RAID HEALING SYSTEM
-- ============================================================================

local PARTY_UNITS = {"player", "party1", "party2", "party3", "party4"}
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local healing_targets = {}
local healing_targets_count = 0

local function unit_has_aggro(unit_id)
   local threat = _G.UnitThreatSituation(unit_id)
   return threat and threat >= 2
end

local function health_percent(unit)
   local max_hp = _G.UnitHealthMax(unit) or 0
   if max_hp <= 0 then return 0 end
   return _G.UnitHealth(unit) / max_hp * 100
end

local function is_in_raid()
   return _G.IsInRaid and _G.IsInRaid() or false
end

local function is_in_party()
   if is_in_raid() then return false end
   return _G.IsInGroup and _G.IsInGroup() or false
end

local function scan_healing_targets()
   healing_targets_count = 0

   local in_raid = is_in_raid()
   local in_group = in_raid or is_in_party()
   local units_to_scan = in_raid and RAID_UNITS or PARTY_UNITS
   local max_units = in_raid and 40 or 5

   for i = 1, max_units do
      local unit = units_to_scan[i]
      if unit and _G.UnitExists(unit) and not _G.UnitIsDead(unit) and _G.UnitIsConnected(unit) and _G.UnitCanAssist("player", unit) then
         local in_range
         if _G.UnitIsUnit(unit, "player") then
            in_range = true
         else
            local spell_range = _G.IsSpellInRange("Rejuvenation", unit)
            if spell_range == 1 then
               in_range = true
            elseif spell_range == 0 then
               in_range = false
            else
               local _, unit_in_range = _G.UnitInRange(unit)
               in_range = (unit_in_range == true)
            end
         end

         if in_range then
            healing_targets_count = healing_targets_count + 1
            local idx = healing_targets_count

            if not healing_targets[idx] then
               healing_targets[idx] = {}
            end

            local entry = healing_targets[idx]
            entry.unit = unit
            local max_hp = _G.UnitHealthMax(unit) or 0
            entry.hp = health_percent(unit)
            entry.is_player = is_player_unit(unit)
            entry.has_aggro = unit_has_aggro(unit)
            entry.has_rejuv = has_any_rejuv(unit)
            entry.has_regrowth = has_any_regrowth(unit)

            -- Effective HP accounts for incoming heals, HoTs, absorbs, and damage
            local eff_deficit = predict_effective_deficit(unit, 1.5)
            entry.effective_hp = max_hp > 0 and (100 - (eff_deficit / max_hp) * 100) or entry.hp

            local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit)
            local player_has_aggro = _G.UnitIsUnit(unit, PLAYER_UNIT)
            entry.is_tank = in_group and ((role == "TANK") or (entry.has_aggro and not player_has_aggro))
         end
      end
   end

   for i = healing_targets_count + 1, #healing_targets do
      healing_targets[i] = nil
   end

   if healing_targets_count > 1 then
      tsort(healing_targets, function(a, b)
         if not a or not a.effective_hp then return false end
         if not b or not b.effective_hp then return true end
         return a.effective_hp < b.effective_hp
      end)
   end

   return healing_targets, healing_targets_count
end

local function get_tank_target()
   scan_healing_targets()

   for i = 1, healing_targets_count do
      local entry = healing_targets[i]
      if entry and entry.is_tank then
         return entry
      end
   end

   return nil
end

local function get_player_tank_target()
   scan_healing_targets()

   for i = 1, healing_targets_count do
      local entry = healing_targets[i]
      if entry and entry.is_tank and entry.is_player then
         return entry
      end
   end

   return nil
end

local function get_lowest_hp_target(threshold)
   threshold = threshold or 100
   scan_healing_targets()

   for i = 1, healing_targets_count do
      local entry = healing_targets[i]
      if entry and entry.effective_hp < threshold then
         return entry
      end
   end

   return nil
end

local function all_members_above_hp(threshold)
   scan_healing_targets()

   for i = 1, healing_targets_count do
      local entry = healing_targets[i]
      if entry and entry.effective_hp < threshold then
         return false
      end
   end

   return true
end

-- ============================================================================
-- HEAL RANK SELECTION
-- ============================================================================

local function cast_best_heal_rank(ranks, icon, target, context, context_msg, options)
   options = options or {}
   local max_hp = Unit(target):HealthMax()
   local hp_deficit = predict_effective_deficit(target, options.cast_time or 1.5)
   -- Fallback: if prediction says fully covered but target is visibly injured, use raw deficit
   if hp_deficit <= 0 then
      local raw = Unit(target):HealthDeficit() or 0
      if raw > max_hp * 0.05 then hp_deficit = raw end
   end
   if hp_deficit <= 0 then
      if cached_settings.debug_mode and debug_print then
         debug_print("[HEAL] Skipped", context_msg, "- no health deficit on", target)
      end
      return nil, nil
   end
   local overheal_threshold = options.overheal_threshold or 1.2
   local mana_floor = options.mana_floor or 0
   local cast_fn = options.cast_fn or safe_heal_cast
   local num_ranks = #ranks
   local debug_mode = cached_settings.debug_mode

   local function is_viable(rank_data)
      return hp_deficit > 0 and rank_data.heal / hp_deficit <= overheal_threshold
   end

   local function can_afford(rank_data)
      return can_afford_spell(rank_data.spell, context, true, mana_floor)
   end

   local function try_cast(i, rank_data)
      local rank_num = num_ranks + 1 - i
      return cast_fn(rank_data.spell, icon, target), context_msg .. " R" .. rank_num
   end

   local function debug_rank_check(i, rank_data, spell_name)
      if not debug_mode or not debug_print then return end
      local rank_num = num_ranks + 1 - i
      local viable = is_viable(rank_data)
      local affordable = can_afford(rank_data)
      local ready = rank_data.spell:IsReady("player")
      if not (viable and affordable and ready) then
         debug_print("[HEAL CHECK]", spell_name, "R" .. rank_num,
                     "viable:", viable, "affordable:", affordable, "ready:", ready)
      end
   end

   local any_viable = false
   for i = 1, num_ranks do
      if is_viable(ranks[i]) then
         any_viable = true
         break
      end
   end
   if not any_viable and hp_deficit > 0 then
      return cast_fn(ranks[num_ranks].spell, icon, target), context_msg .. " R1"
   end

   if options.prioritize_speed then
      local fallback_i, fallback_data
      for i = 1, num_ranks do
         local rank_data = ranks[i]
         if is_viable(rank_data) then
            fallback_i, fallback_data = i, rank_data
            if can_afford(rank_data) and rank_data.spell:IsReady("player") then
               return try_cast(i, rank_data)
            end
         end
      end
      if fallback_data then return try_cast(fallback_i, fallback_data) end
      return nil, nil
   end

   if options.prioritize_efficiency then
      local best_eff, best_i, best_data = 0, nil, nil
      for i = 1, num_ranks do
         local rank_data = ranks[i]
         if is_viable(rank_data) and can_afford(rank_data) and rank_data.spell:IsReady("player") then
            local eff = rank_data.heal / get_spell_mana_cost(rank_data.spell)
            if eff > best_eff then
               best_eff, best_i, best_data = eff, i, rank_data
            end
         end
      end
      if best_data then return try_cast(best_i, best_data) end
      return nil, nil
   end

   for i = num_ranks, 1, -1 do
      local rank_data = ranks[i]
      if is_viable(rank_data) and can_afford(rank_data) and rank_data.spell:IsReady("player") then
         if rank_data.heal >= hp_deficit * 0.8 then
            return try_cast(i, rank_data)
         end
      end
   end

   local best_eff, best_i, best_data = 0, nil, nil
   for i = num_ranks, 1, -1 do
      local rank_data = ranks[i]
      debug_rank_check(i, rank_data, context_msg)
      if is_viable(rank_data) and can_afford(rank_data) and rank_data.spell:IsReady("player") then
         local eff = rank_data.heal / get_spell_mana_cost(rank_data.spell)
         if eff > best_eff then
            best_eff, best_i, best_data = eff, i, rank_data
         end
      end
   end
   if best_data then return try_cast(best_i, best_data) end

   if debug_mode and debug_print and round_half then
      debug_print("[HEAL] No viable rank found for", context_msg, "- deficit:", round_half(hp_deficit))
   end
   return nil, nil
end

-- ============================================================================
-- EXPORT TO NAMESPACE
-- ============================================================================

NS.can_afford_spell = can_afford_spell

NS.has_any_rejuv = has_any_rejuv
NS.has_any_regrowth = has_any_regrowth
NS.has_any_lifebloom = has_any_lifebloom
NS.has_buff = has_buff
NS.missing_buff = missing_buff
NS.is_player_unit = is_player_unit
NS.health_percent = health_percent

NS.is_in_raid = is_in_raid
NS.is_in_party = is_in_party
NS.scan_healing_targets = scan_healing_targets
NS.get_tank_target = get_tank_target
NS.get_player_tank_target = get_player_tank_target
NS.get_lowest_hp_target = get_lowest_hp_target
NS.all_members_above_hp = all_members_above_hp
NS.unit_has_aggro = unit_has_aggro

NS.cast_best_heal_rank = cast_best_heal_rank

NS.PARTY_UNITS = PARTY_UNITS
NS.RAID_UNITS = RAID_UNITS

print("|cFF00FF00[Menagerie Healing]|r Healing utilities loaded.")
