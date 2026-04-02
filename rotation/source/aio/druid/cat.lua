--- Cat Module
--- Cat (Feral DPS) playstyle strategies and utilities
--- Part of the modular AIO rotation system
--- Loads after: core.lua, healing.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Settings can change at runtime (e.g., playstyle switching).
-- Always access settings through context.settings in matches/execute.
-- ============================================================

-- Get namespace from Core module
local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Cat]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Cat]|r Registry not found in Core!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local safe_ability_cast = NS.safe_ability_cast
local try_cast_fmt = NS.try_cast_fmt
local get_form_cost = NS.get_form_cost
local is_swing_landing_soon = NS.is_swing_landing_soon
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Import factory functions from Core
local create_faerie_fire_strategy = NS.create_faerie_fire_strategy
local named = NS.named

-- Lua optimizations
local format = string.format
local GetTime = GetTime
local math_max = math.max
local floor = math.floor

-- ============================================================================
-- ENERGY COST INITIALIZATION
-- ============================================================================
local function get_spell_energy_cost(spell, fallback)
   local cost, power_type = spell:GetSpellPowerCost()
   if cost and cost > 0 and power_type == 3 then return cost end
   return fallback
end

local ENERGY_COST_RIP = get_spell_energy_cost(A.Rip, 30)
local ENERGY_COST_RAKE = get_spell_energy_cost(A.Rake, 35)
local ENERGY_COST_MANGLE = get_spell_energy_cost(A.MangleCat, 40)
local ENERGY_COST_SHRED = get_spell_energy_cost(A.Shred, 42)
local ENERGY_COST_BITE = get_spell_energy_cost(A.FerociousBite, 35)
local ENERGY_COST_RAVAGE = get_spell_energy_cost(A.Ravage, 60)
local ENERGY_COST_TIGERS_FURY = get_spell_energy_cost(A.TigersFury, 30)

print("|cFFFF8800[Flux AIO]|r Energy costs: Rip=" .. ENERGY_COST_RIP .. ", Rake=" .. ENERGY_COST_RAKE .. ", Bite=" .. ENERGY_COST_BITE .. ", Mangle=" .. ENERGY_COST_MANGLE .. ", Shred=" .. ENERGY_COST_SHRED .. ", Ravage=" .. ENERGY_COST_RAVAGE .. ", Tigers=" .. ENERGY_COST_TIGERS_FURY)

-- Tick optimization: prefer Mangle over Shred in this energy range when tick imminent.
-- At these energy levels, Shred leaves you too low to act after the tick, but Mangle doesn't.
-- Formula: lower = 2*mangle_cost - 20, upper = mangle_cost + shred_cost - 21
-- With 2pT6 (mangle=35): 50-56. Without (mangle=40): 60-61. Adapts to actual costs.
local TICK_OPT_MANGLE_LOW = 2 * ENERGY_COST_MANGLE - 20
local TICK_OPT_MANGLE_HIGH = ENERGY_COST_MANGLE + ENERGY_COST_SHRED - 21
local TICK_OPT_THRESHOLD = 1.0  -- seconds until tick

-- ============================================================================
-- CAT DEBUFF ID ARRAYS
-- ============================================================================
-- Mangle: include both Cat (33876-33983) and Bear (33878-33987) IDs
-- so we detect the debuff regardless of which druid applied it
local MANGLE_CAT_DEBUFF_IDS = { 33876, 33982, 33983, 33878, 33986, 33987 }
local FAERIE_FIRE_DEBUFF_IDS = NS.FAERIE_FIRE_DEBUFF_IDS
local RIP_DEBUFF_IDS = { 1079, 9492, 9493, 9752, 9894, 9896, 27008 }
local RAKE_DEBUFF_IDS = { 1822, 1823, 1824, 9904, 27003 }
local TIGERS_FURY_BUFF_IDS = { 5217, 6793, 9845, 9846 }

-- ============================================================================
-- WOLFSHEAD HELM AUTO-DETECTION
-- ============================================================================
local WOLFSHEAD_HELM_ID = 8345
local INVSLOT_HEAD = 1
local wolfshead_cache = { equipped = false, last_check = 0 }
local EQUIPMENT_CHECK_INTERVAL = 2.0

local function is_wolfshead_equipped()
   local now = GetTime()
   if now - wolfshead_cache.last_check < EQUIPMENT_CHECK_INTERVAL then
      return wolfshead_cache.equipped
   end

   local head_item = _G.GetInventoryItemID("player", INVSLOT_HEAD)
   wolfshead_cache.equipped = (head_item == WOLFSHEAD_HELM_ID)
   wolfshead_cache.last_check = now
   return wolfshead_cache.equipped
end

-- ============================================================================
-- ENERGY TICK TRACKER (for powershift optimization)
-- ============================================================================
-- Energy ticks every 2s in TBC (20 energy per tick).
-- Detects ticks by watching for energy increases in cat form, filtering out
-- Furor energy (40+20 on form shift). Strategies can check time_until_next_tick()
-- to delay powershifts and capture an imminent tick before shifting.
-- ============================================================================
local ENERGY_TICK_INTERVAL = 2.0
local SHIFT_ENERGY_IGNORE_WINDOW = 0.6  -- Ignore energy increases within 0.6s of a shift
local TICK_WAIT_THRESHOLD = 0.4         -- Wait for tick if arriving within this window

local energy_tick_last_shift = 0

local energy_tick = {
   last_energy = 0,
   last_tick_time = 0,
   confident = false,  -- True once we've detected at least one tick
}

-- Expose to NS so the dashboard can prefer this frame-level tracker over its own 10Hz one
NS.energy_tick_tracker = energy_tick

--- Update tick tracker each frame
--- @param current_energy number Current player energy
--- @param stance number Current stance ID
function energy_tick:update(current_energy, stance)
   -- Only track in Cat form
   if stance ~= Constants.STANCE.CAT then
      self.last_energy = 0
      self.confident = false
      return
   end

   local now = GetTime()
   local delta = current_energy - self.last_energy

   -- Detect energy tick: positive increase, not from a recent form shift
   -- Ticks are 20 energy; filter out Furor (40) + Wolfshead (20) by checking shift window
   if delta > 0 and delta <= 25 and
      (now - energy_tick_last_shift) > SHIFT_ENERGY_IGNORE_WINDOW then
      self.last_tick_time = now
      self.confident = true
   end

   self.last_energy = current_energy
end

--- Get time until next energy tick (seconds)
--- @return number Estimated seconds until next tick (1.0 if unknown)
function energy_tick:time_until_next_tick()
   if not self.confident or self.last_tick_time == 0 then return 1.0 end
   local elapsed = GetTime() - self.last_tick_time
   local remaining = ENERGY_TICK_INTERVAL - (elapsed % ENERGY_TICK_INTERVAL)
   return remaining
end

--- Check if powershifting should be delayed for an imminent energy tick
--- @return boolean True if a tick is arriving soon and we should wait
function energy_tick:should_delay_shift()
   if not self.confident then return false end
   return self:time_until_next_tick() <= TICK_WAIT_THRESHOLD
end

-- ============================================================================
-- CAT FORM UTILITIES
-- ============================================================================

--- Check if energy will reach target amount within threshold time
--- @param target_energy number Energy threshold to reach
--- @param threshold number|nil Time threshold in seconds (default 0.5)
--- @param context table|nil Optional context for current energy
--- @return boolean True if energy will reach target soon
local function will_reach_energy_soon(target_energy, threshold, context)
   threshold = threshold or 0.5
   local current_energy = context and context.energy or Player:Energy()
   if current_energy >= target_energy then return true end
   local time_to_target = Player:EnergyTimeToX(target_energy, 0)
   return time_to_target > 0 and time_to_target <= threshold
end

--- Safe Cat Form shift with ready check
--- CatForm has /cancelform macro built-in for powershift support
--- Note: GCD is already checked at main entry point (A[3])
--- @param icon table The icon to show
--- @return any|nil The cast result or nil
local function safe_cat_form_shift(icon, context)
   -- Record shift time so energy tick tracker can ignore Furor energy
   energy_tick_last_shift = GetTime()

   -- Use Sapper Charges when shifting vs 3+ enemies or bosses (requires DMH addon)
   local use_sappers = (context.enemy_count >= 3) or context.is_boss
   if use_sappers then
      if context.settings.use_super_sapper and A.SuperSapperCharge:IsExists() and A.SuperSapperCharge:IsReady("player") and A.CatSuperSapperChargeAndShift:IsReady("player") then
         return A.CatSuperSapperChargeAndShift:Show(icon)
      end
      if context.settings.use_goblin_sapper and A.GoblinSapperCharge:IsExists() and A.GoblinSapperCharge:IsReady("player") and A.CatGoblinSapperChargeAndShift:IsReady("player") then
         return A.CatGoblinSapperChargeAndShift:Show(icon)
      end
   end

   -- Fallback to normal cat form shift
   return A.CatForm:Show(icon)
end


--- Calculate dynamic DoT refresh threshold (accounts for GCD and pandemic)
--- @param user_setting number User-configured refresh threshold
--- @param max_duration number|nil Maximum DoT duration for pandemic window calculation
--- @return number Adjusted refresh threshold
local function get_dot_refresh_threshold(user_setting, max_duration)
   local threshold = user_setting + Player:GCDRemains()
   if max_duration then
      threshold = math_max(threshold, max_duration * 0.3)
   end
   return threshold
end

-- ============================================================================
-- SHARED CAT DPS STATE (computed once per frame, cached)
-- ============================================================================

-- Pre-allocated table for shared cat DPS state (avoids GC in combat)
local cat_state = {
   -- Cat-specific context
   has_wolfshead = false,
   can_powershift = false,
   energy_tick_soon = false,
   cat_form_cost = 0,
   shifts_remaining = 0,
   -- DPS state
   mangle_duration = 0,
   rip_duration = 0,
   rake_duration = 0,
   rip_now = false,
   mangle_now = false,
   rip_needs_refresh_soon = false,
   target_qualifies_for_rip = true,
   rip_refresh_threshold = 0,
   energy_after_shift = 0,
   wolfshead_bonus = 0,
   -- Inter-strategy communication: set by Rip/MangleDebuff, checked by lower priorities
   pooling = false,
   -- Tick optimization: prefer Mangle over Shred to avoid dead GCD after tick
   prefer_mangle_for_tick = false,
   tf_queued = false,
   tf_queued_at = 0,
}

--- Compute shared cat DPS state once per frame (lazy, cached via context._cat_valid)
local function get_cat_state(context)
   if context._cat_valid then return cat_state end
   context._cat_valid = true

   local settings = context.settings
   local cp = context.cp
   local energy = context.energy
   local ttd = context.ttd

   -- Reset mutable inter-strategy flags
   cat_state.pooling = false

   -- Cat-specific context
   local wh = is_wolfshead_equipped()
   local auto_ps = settings.auto_powershift or false
   local ps_min_mana = settings.powershift_min_mana or 25
   local form_cost = get_form_cost(A.CatForm)
   cat_state.has_wolfshead = wh
   cat_state.cat_form_cost = form_cost
   -- can_powershift: mana % floor AND enough mana for at least one shift
   cat_state.can_powershift = auto_ps and context.mana_pct >= ps_min_mana
      and (form_cost == 0 or context.mana >= form_cost)
   cat_state.shifts_remaining = (form_cost > 0) and floor(context.mana / form_cost) or 0

   -- Energy tick tracking
   energy_tick:update(energy, context.stance)
   cat_state.energy_tick_soon = energy_tick:should_delay_shift()

   local has_cc = context.has_clearcasting

   -- Debuff durations (3 API calls, done once per frame)
   cat_state.mangle_duration = Unit(TARGET_UNIT):HasDeBuffs(MANGLE_CAT_DEBUFF_IDS) or 0
   cat_state.rip_duration = Unit(TARGET_UNIT):HasDeBuffs(RIP_DEBUFF_IDS, nil, true) or 0
   cat_state.rake_duration = Unit(TARGET_UNIT):HasDeBuffs(RAKE_DEBUFF_IDS, nil, true) or 0

   -- Powershift helpers
   cat_state.wolfshead_bonus = wh and Constants.POWERSHIFT.WOLFSHEAD_BONUS or 0
   cat_state.energy_after_shift = Constants.POWERSHIFT.FUROR_ENERGY + cat_state.wolfshead_bonus

   -- Rip qualification (elite/boss check)
   cat_state.target_qualifies_for_rip = true
   if settings.rip_only_elites then
      local classification = Unit(TARGET_UNIT):Classification() or ""
      cat_state.target_qualifies_for_rip = classification == "worldboss" or classification == "elite" or classification == "rareelite"
   end

   -- Rip refresh threshold
   cat_state.rip_refresh_threshold = get_dot_refresh_threshold(settings.rip_refresh)

   -- rip_now: should we cast Rip this frame?
   local rip_now = settings.maintain_rip and cat_state.target_qualifies_for_rip
                   and cp >= settings.rip_min_cp and ttd >= Constants.TTD.RIP_MIN
                   and not context.target_phys_immune
                   and (cat_state.rip_duration == 0 or cat_state.rip_duration < cat_state.rip_refresh_threshold)

   -- Mangle debuff awareness: defer Rip one GCD if Mangle debuff is missing
   -- 30% bleed damage bonus on the FULL Rip duration is worth one GCD delay
   if rip_now and cat_state.mangle_duration == 0 and A.MangleCat:IsReady(TARGET_UNIT)
      and (energy >= ENERGY_COST_MANGLE or has_cc) then
      rip_now = false
   end
   cat_state.rip_now = rip_now

   -- Guard: don't spend CPs on Bite if Rip needs renewal soon
   -- Conservative estimate: 1 CP per GCD (~1.5s), no crits assumed
   cat_state.rip_needs_refresh_soon = not rip_now and settings.maintain_rip
      and cat_state.target_qualifies_for_rip
      and not context.target_phys_immune and ttd >= Constants.TTD.RIP_MIN
      and cat_state.rip_duration > 0 and cat_state.rip_duration < settings.rip_min_cp * 1.5

   -- Tick optimization: prefer Mangle over Shred when energy is in the dead zone
   -- and a tick arrives within 1s (avoids a dead GCD after Shred + tick)
   -- Note: no is_behind gate — when not behind, MangleBuilder fires anyway via its own check
   cat_state.prefer_mangle_for_tick = settings.cat_tick_optimization
      and energy >= TICK_OPT_MANGLE_LOW and energy <= TICK_OPT_MANGLE_HIGH
      and energy_tick.confident and energy_tick:time_until_next_tick() < TICK_OPT_THRESHOLD

   -- mangle_now: should we refresh Mangle debuff?
   cat_state.mangle_now = not rip_now and cat_state.mangle_duration == 0 and not context.target_phys_immune

   if cat_state.tf_queued then
      if (Unit(PLAYER_UNIT):HasBuffs(TIGERS_FURY_BUFF_IDS, nil, true) or 0) > 0 then
         cat_state.tf_queued = false
      elseif GetTime() - cat_state.tf_queued_at > 5.0 then
         cat_state.tf_queued = false  -- Safety timeout
      end
   end

      -- Tiger's Fury cast tracking (Maul-style IsSpellCurrent pattern)
   -- IsSpellCurrent confirms the game accepted the cast → set queued
   if not cat_state.tf_queued and A.TigersFury:IsSpellCurrent() then
      cat_state.tf_queued = true
      cat_state.tf_queued_at = GetTime()
   end

   return cat_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- ---- PRE-COMBAT & STEALTH ------------------------------------------------

-- Prowl when near an enemy target (out of combat, already in cat form)
local Cat_StealthSetup = {
   is_gcd_gated = false,
   requires_combat = false,
   requires_enemy = true,
   requires_stealth = false,
   spell = A.Prowl,
   spell_target = PLAYER_UNIT,
   setting_key = "focus_prowl",
   matches = function(context)
      local prowl_distance = context.settings.prowl_distance
      return context.target_range and context.target_range <= prowl_distance
   end,
   execute = function(icon, context)
      local result = A.Prowl:Show(icon)
      if result then
         return result, format("[P0] Prowl - Stealth setup, Distance: %.0f", context.target_range or 0)
      end
      return nil
   end,
}

-- Ravage from stealth (highest priority opener, requires behind)
local Cat_StealthRavage = {
   requires_enemy = true,
   requires_stealth = true,
   requires_in_range = true,
   requires_behind = true,
   requires_phys_immune = false,
   requires_combat = false,
   min_energy = ENERGY_COST_RAVAGE,
   setting_key = "use_opener",
   spell = A.Ravage,
   execute = function(icon, context)
      return try_cast_fmt(A.Ravage, icon, TARGET_UNIT, "[P1]", "Ravage", "Stealth opener, Energy: %d", context.energy)
   end,
}

-- Shred from stealth (behind target, fallback when Ravage unavailable)
local Cat_StealthShred = {
   requires_enemy = true,
   requires_stealth = true,
   requires_in_range = true,
   requires_behind = true,
   requires_phys_immune = false,
   requires_combat = false,
   min_energy = ENERGY_COST_SHRED,
   spell = A.Shred,
   execute = function(icon, context)
      return try_cast_fmt(A.Shred, icon, TARGET_UNIT, "[P1]", "Shred", "Stealth opener, Energy: %d", context.energy)
   end,
}

-- Mangle from stealth (not behind, off by default)
local Cat_StealthMangle = {
   requires_enemy = true,
   requires_stealth = true,
   requires_in_range = true,
   requires_phys_immune = false,
   requires_combat = false,
   min_energy = ENERGY_COST_MANGLE,
   setting_key = "use_mangle_opener",
   spell = A.MangleCat,
   execute = function(icon, context)
      return try_cast_fmt(A.MangleCat, icon, TARGET_UNIT, "[P1]", "Mangle", "Stealth opener (not behind), Energy: %d", context.energy)
   end,
}

-- ---- DEBUFF MAINTENANCE ---------------------------------------------------

-- Faerie Fire (armor reduction + 3% hit for melee)
local Cat_FaerieFire = create_faerie_fire_strategy()

-- ---- FINISHERS ------------------------------------------------------------

-- Rip - Bleed finisher DoT (sets pooling gate when can't cast)
local Cat_Rip = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.Rip,
   matches = function(context, state)
      return state.rip_now
   end,
   execute = function(icon, context, state)
      local energy = context.energy
      local has_cc = context.has_clearcasting

      if (energy >= ENERGY_COST_RIP or has_cc) and A.Rip:IsReady(TARGET_UNIT) then
         local result = safe_ability_cast(A.Rip, icon, TARGET_UNIT)
         if result then
            local cc_str = has_cc and " [CC]" or ""
            return result, format("[P2] Rip - %d CP, Energy: %d, Duration: %.1f%s", context.cp, energy, state.rip_duration, cc_str)
         end
      end

      state.pooling = true
      return nil
   end,
}

-- Rip Shift - Powershift to afford Rip when energy-starved
local Cat_RipShift = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      return state.rip_now and state.can_powershift
         and context.energy < ENERGY_COST_RIP and not context.has_clearcasting
   end,
   execute = function(icon, context, state)
      if will_reach_energy_soon(ENERGY_COST_RIP, 0.5, context) then return nil end
      if state.energy_tick_soon then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[P2] Shift for Rip - Energy: %d -> ~%d (%d shifts left)", context.energy, state.energy_after_shift, state.shifts_remaining)
      end
      return nil
   end,
}

-- Execute Bite - FB when target will die before we can build more CPs
local Cat_ExecuteBite = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.FerociousBite,
   requires_phys_immune = false,
   min_energy = ENERGY_COST_BITE,
   min_cp = 1,
   matches = function(context, state)
      if state.pooling then return false end
      -- Bite scales with CP: 1 CP bite only if mob dies in 1 GCD, 5 CP bite with 7.5s left
      return context.ttd <= context.cp * 1.5
   end,
   execute = function(icon, context, state)
      local result = safe_ability_cast(A.FerociousBite, icon, TARGET_UNIT)
      if result then
         return result, format("[P2.5] Ferocious Bite - Execute, CP: %d, TTD: %.1fs, HP: %.1f%%", context.cp, context.ttd, context.target_hp)
      end
      return nil
   end,
}

-- Ferocious Bite - Standard finisher at 5 CP (excess energy, execute, short fight)
local Cat_FerociousBite = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.FerociousBite,
   requires_phys_immune = false,
   matches = function(context, state)
      if state.pooling then return false end
      -- Dynamic min CP from settings (replaces hardcoded min_cp = 5)
      local min_cp = context.settings.fb_min_cp or 5
      if context.cp < min_cp then return false end
      return true
   end,

   execute = function(icon, context, state)
      local settings = context.settings
      local energy = context.energy
      local ttd = context.ttd
      local target_hp = context.target_hp
      local bite_now = false
      local bite_reason = ""
      local fb_max_energy = settings.fb_max_energy or 39

      -- Not maintaining Rip on this target: Bite freely
      local not_maintaining_rip = not settings.maintain_rip or not state.target_qualifies_for_rip
      if not_maintaining_rip and energy >= ENERGY_COST_BITE and energy <= fb_max_energy then
         bite_now = true
         bite_reason = "No Rip target"
      end

      if state.rip_duration > settings.fb_min_rip_duration and energy >= settings.fb_min_energy and energy <= fb_max_energy then
         bite_now = true
         bite_reason = "Excess energy"
      end

      -- Execute/Short fight (configurable thresholds) — ignore max energy cap, bite freely
      local bite_execute_ttd = settings.bite_execute_ttd or Constants.TTD.BITE_EXECUTE
      local bite_execute_hp = settings.bite_execute_hp or Constants.HP.EXECUTE
      if ttd < bite_execute_ttd and energy >= ENERGY_COST_BITE then
         bite_now = true
         bite_reason = "Target dying soon"
      elseif (target_hp <= bite_execute_hp or ttd < Constants.TTD.SHORT_FIGHT) and state.rip_duration > Constants.DURATION.BITE_MIN_RIP and energy >= ENERGY_COST_BITE then
         bite_now = true
         bite_reason = "Execute/Short fight"
      end

      if bite_now then
         local result = safe_ability_cast(A.FerociousBite, icon, TARGET_UNIT)
         if result then
            return result, format("[P3] Ferocious Bite - %s, Energy: %d, Rip: %.1fs, TTD: %.1fs, HP: %.1f%%", bite_reason, energy, state.rip_duration, context.ttd, context.target_hp)
         end
      end
      return nil
   end,
}

-- ---- DEBUFF & DOT MAINTENANCE ---------------------------------------------

-- Mangle Debuff - Bleed debuff maintenance (sets pooling gate when can't cast)
local Cat_MangleDebuff = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   matches = function(context, state)
      if state.pooling then return false end
      return state.mangle_now
   end,

   execute = function(icon, context, state)
      local energy = context.energy
      local has_cc = context.has_clearcasting

      if (energy >= ENERGY_COST_MANGLE or has_cc) and A.MangleCat:IsReady(TARGET_UNIT) then
         local result = safe_ability_cast(A.MangleCat, icon, TARGET_UNIT)
         if result then
            local cc_str = has_cc and " [CC]" or ""
            return result, format("[P4] Mangle - Debuff maintenance, CP: %d, Energy: %d%s", context.cp, energy, cc_str)
         end
      end

      state.pooling = true
      return nil
   end,
}

-- Mangle Shift - Powershift to afford Mangle debuff when energy-starved
local Cat_MangleShift = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      return state.mangle_now and state.can_powershift
         and context.energy < ENERGY_COST_MANGLE and not context.has_clearcasting
   end,

   execute = function(icon, context, state)
      if will_reach_energy_soon(ENERGY_COST_MANGLE, 0.5, context) then return nil end
      if state.energy_tick_soon then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[P4] Shift for Mangle - Energy: %d -> ~%d (%d shifts left)", context.energy, state.energy_after_shift, state.shifts_remaining)
      end
      return nil
   end,
}

-- Rake - DoT maintenance (single-target and AoE spread)
local Cat_Rake = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_phys_immune = false,
   requires_stealth = false,
   min_energy = ENERGY_COST_RAKE,
   setting_key = "maintain_rake",
   matches = function(context, state)
      return not state.pooling
   end,
   execute = function(icon, context, state)
      local settings = context.settings
      local ttd = context.ttd
      local rake_duration = state.rake_duration
      local rake_refresh_threshold = get_dot_refresh_threshold(settings.rake_refresh)

      local is_aoe_situation = settings.enable_aoe and context.enemy_count >= settings.aoe_enemy_count

      -- Single-target Rake maintenance
      if not is_aoe_situation and context.cp <= 4 then
         if ttd >= Constants.TTD.RAKE_MIN and (rake_duration == 0 or rake_duration < rake_refresh_threshold) and A.Rake:IsReady(TARGET_UNIT) then
            if is_swing_landing_soon(0.15) then return nil end
            local result = safe_ability_cast(A.Rake, icon, TARGET_UNIT)
            if result then
               return result, format("[P4.5] Rake - DoT maintenance, Duration: %.1fs, CP: %d, Energy: %d", rake_duration, context.cp, context.energy)
            end
         end
         return nil
      end

      -- AoE Rake spreading
      if is_aoe_situation and settings.spread_rake then
         -- Primary target first
         if ttd >= Constants.TTD.RAKE_MIN and (rake_duration == 0 or rake_duration < rake_refresh_threshold) and A.Rake:IsReady(TARGET_UNIT) then
            if is_swing_landing_soon(0.15) then return nil end
            local result = safe_ability_cast(A.Rake, icon, TARGET_UNIT)
            if result then
               return result, format("[AoE] Rake - Primary target, Duration: %.1fs, TTD: %.1fs", rake_duration, ttd)
            end
         end

         -- Spread to nearby targets missing Rake
         if A.MultiUnits:GetByRangeMissedDoTs(Constants.AOE.RAKE_SPREAD_NEARBY, 10, A.Rake.ID) > 0 and A.Rake:IsReady(TARGET_UNIT) then
            if is_swing_landing_soon(0.15) then return nil end
            local result = safe_ability_cast(A.Rake, icon, TARGET_UNIT)
            if result then
               return result, "[AoE] Rake - Spread to other targets"
            end
         end
      end
      return nil
   end,
}

-- ---- CP BUILDERS ----------------------------------------------------------

-- Clearcasting Shred - Free Shred on Omen of Clarity proc
local Cat_ClearcastingShred = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_behind = true,
   requires_phys_immune = false,
   spell = A.Shred,
   requires_stealth = false,
   requires_clearcasting = true,
   matches = function(context, state)
      return not state.pooling
   end,

   execute = function(icon, context, state)
      if is_swing_landing_soon(0.15) then return nil end
      local result = safe_ability_cast(A.Shred, icon, TARGET_UNIT)
      if result then
         return result, format("[P5] Shred - Clearcasting, Energy: %d, CP: %d", context.energy, context.cp)
      end
      return nil
   end,
}

-- Shred - Primary CP builder (must be behind target)
local Cat_Shred = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   spell = A.Shred,
   requires_behind = true,
   requires_stealth = false,
   requires_phys_immune = false,
   min_energy = ENERGY_COST_SHRED,
   matches = function(context, state)
      if state.pooling then return false end
      if state.prefer_mangle_for_tick then return false end
      return context.cp < 5
   end,
   execute = function(icon, context, state)
      if is_swing_landing_soon(0.15) then return nil end
      local result = safe_ability_cast(A.Shred, icon, TARGET_UNIT)
      if result then
         return result, format("[P8] Shred - Builder, Energy: %d, CP: %d", context.energy, context.cp)
      end
      return nil
   end,
}

-- Mangle Builder - Fallback CP builder (not behind or can't afford Shred)
local Cat_MangleBuilder = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   spell = A.MangleCat,
   requires_stealth = false,
   requires_phys_immune = false,
   matches = function(context, state)
      if state.pooling then return false end
      local not_behind = not context.is_behind
      -- Setting gates the "not behind" fallback; energy/tick reasons still fire
      if not_behind and not context.settings.use_mangle_builder then return false end
      return (not_behind or context.energy < ENERGY_COST_SHRED or state.prefer_mangle_for_tick)
         and (context.energy >= ENERGY_COST_MANGLE or context.has_clearcasting)
         and context.cp < 5
   end,
   execute = function(icon, context, state)
      if is_swing_landing_soon(0.15) then return nil end
      local result = safe_ability_cast(A.MangleCat, icon, TARGET_UNIT)
      if result then
         local cc_str = context.has_clearcasting and " [CC]" or ""
         local tick_str = state.prefer_mangle_for_tick and " [tick-opt]" or ""
         return result, format("[P9] Mangle - Builder, Energy: %d, CP: %d%s%s (behind: %s)", context.energy, context.cp, cc_str, tick_str, tostring(context.is_behind))
      end
      return nil
   end,
}

-- ---- ENERGY TRICKS --------------------------------------------------------

-- Bite Trick - Low-energy FB dump to avoid energy waste
local Cat_BiteTrick = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   requires_phys_immune = false,
   requires_clearcasting = false,
   min_energy = ENERGY_COST_BITE,
   min_cp = 3,
   spell = A.FerociousBite,
   setting_key = "use_bite_trick",
   matches = function(context, state)
      if state.pooling then return false end
      if state.rip_needs_refresh_soon then return false end
      return context.energy <= Constants.ENERGY.BITE_TRICK_MAX
         and context.ttd >= Constants.TTD.BITE_EXECUTE
   end,
   execute = function(icon, context, state)
      local result = safe_ability_cast(A.FerociousBite, icon, TARGET_UNIT)
      if result then
         return result, format("[P6] Ferocious Bite - Bite Trick, Energy: %d, CP: %d", context.energy, context.cp)
      end
      return nil
   end,
}

-- Rake Trick - Low-energy Rake filler in the energy dead zone
local Cat_RakeTrick = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   requires_phys_immune = false,
   requires_clearcasting = false,
   min_energy = ENERGY_COST_RAKE,
   setting_key = "use_rake_trick",
   spell = A.Rake,
   matches = function(context, state)
      if state.pooling then return false end
      return context.energy < ENERGY_COST_MANGLE
         and state.mangle_duration > 0 and state.rake_duration == 0
         and context.ttd >= Constants.TTD.RAKE_MIN
   end,
   execute = function(icon, context, state)
      if is_swing_landing_soon(0.15) then return nil end
      local result = safe_ability_cast(A.Rake, icon, TARGET_UNIT)
      if result then
         return result, format("[P7] Rake - Rake Trick, Energy: %d", context.energy)
      end
      return nil
   end,
}

-- Tiger's Fury - Energy boost cooldown
local Cat_TigersFury = {
   is_gcd_gated = false,
   is_burst = true,
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   min_energy = ENERGY_COST_TIGERS_FURY,
   setting_key = "use_tigers_fury",
   spell = A.TigersFury,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      if state.pooling then return false end
      if context.ttd < 4 then return false end
      if state.tf_queued then return false end
      if (Unit(PLAYER_UNIT):HasBuffs(TIGERS_FURY_BUFF_IDS, nil, true) or 0) > 0 then return false end
      return context.energy >= context.settings.tigers_fury_energy
   end,
   execute = function(icon, context, state)
      -- Don't cast if we're about to powershift (shift first, then TF for max pooling)
      local shift_threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
      if state.can_powershift and context.energy < shift_threshold then
         return nil
      end
      local result = safe_ability_cast(A.TigersFury, icon, PLAYER_UNIT)
      if result then
         return result, format("[CD] Tiger's Fury - Energy boost, Energy: %d", context.energy)
      end
      return nil
   end,
}

-- ---- POWERSHIFT -----------------------------------------------------------

-- Critical Energy Shift - Emergency powershift at very low energy
local Cat_CriticalEnergyShift = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      if context.has_clearcasting then return false end
      return context.energy < Constants.ENERGY.CRITICAL and state.can_powershift
   end,
   execute = function(icon, context, state)
      if will_reach_energy_soon(Constants.ENERGY.CRITICAL + 10, 0.5, context) then
         return nil
      end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[P0] Critical Energy Shift - Energy: %d -> %d, Mana: %.0f%% (%d shifts left)", context.energy, state.energy_after_shift, context.mana_pct, state.shifts_remaining)
      end
      return nil
   end,
}

-- Wolfshead Shred Shift - Smart shift when Shred is needed but energy is low
local Cat_WolfsheadShred = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_behind = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      if context.has_clearcasting then return false end
      if state.pooling or state.rip_now or state.mangle_now then return false end
      return state.has_wolfshead and state.can_powershift
         and (state.energy_after_shift - context.energy) >= Constants.POWERSHIFT.MIN_SHIFT_ENERGY_GAIN
         and context.cp < 5
         and state.energy_after_shift >= ENERGY_COST_SHRED
         and context.energy < ENERGY_COST_SHRED
   end,

   execute = function(icon, context, state)
      if will_reach_energy_soon(ENERGY_COST_SHRED, 0.5, context) then return nil end
      if state.energy_tick_soon then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[WOLFSHEAD] Shift -> Shred, Energy: %d -> %d (%d shifts left)", context.energy, state.energy_after_shift, state.shifts_remaining)
      end
      return nil
   end,
}

-- Early Shift - Powershift when energy is low and not pooling for anything
local Cat_EarlyShift = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      if context.has_clearcasting then return false end
      if state.pooling or state.rip_now or state.mangle_now then return false end
      if not state.can_powershift then return false end
      local shift_threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
      return context.energy < shift_threshold
   end,

   execute = function(icon, context, state)
      -- Don't shift if tricks are available in this energy range
      if context.settings.use_rake_trick and context.energy >= Constants.ENERGY.RAKE_TRICK_MIN then
         return nil
      end
      local shift_threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
      if will_reach_energy_soon(shift_threshold + 10, 0.5, context) then return nil end
      if state.energy_tick_soon then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         local info = state.has_wolfshead and format(" -> %d", state.energy_after_shift) or ""
         return result, format("[SHIFT] Early shift - Energy: %d%s, Mana: %.0f%% (%d shifts left)", context.energy, info, context.mana_pct, state.shifts_remaining)
      end
      return nil
   end,
}

-- ============================================================================
-- REGISTRATION (array order = execution priority)
-- ============================================================================
rotation_registry:register("cat", {
   named("CriticalEnergyShift", Cat_CriticalEnergyShift),    -- P0: Emergency powershift
   named("StealthSetup",        Cat_StealthSetup),           -- P0: Pre-combat prowl
   named("StealthRavage",       Cat_StealthRavage),          -- P1: Stealth opener (Ravage)
   named("StealthShred",        Cat_StealthShred),           -- P1: Stealth opener (Shred)
   named("StealthMangle",       Cat_StealthMangle),          -- P1: Stealth opener (Mangle)
   named("FaerieFire",          Cat_FaerieFire),             -- Debuff: Faerie Fire
   named("Rip",                 Cat_Rip),                    -- P2: Finisher DoT
   named("RipShift",            Cat_RipShift),               -- P2: Powershift for Rip
   named("ExecuteBite",         Cat_ExecuteBite),            -- P2.5: Execute finisher
   named("FerociousBite",       Cat_FerociousBite),          -- P3: Standard finisher
   named("MangleDebuff",        Cat_MangleDebuff),           -- P4: Bleed debuff maintenance
   named("MangleShift",         Cat_MangleShift),            -- P4: Powershift for Mangle
   named("Rake",                Cat_Rake),                   -- P4.5: Rake DoT maintenance
   named("ClearcastingShred",   Cat_ClearcastingShred),      -- P5: Free Shred (OoC proc)
   named("BiteTrick",           Cat_BiteTrick),              -- P6: Low-energy Bite trick
   named("RakeTrick",           Cat_RakeTrick),              -- P7: Low-energy Rake trick
   named("Shred",               Cat_Shred),                  -- P8: Primary builder
   named("MangleBuilder",       Cat_MangleBuilder),          -- P9: Fallback builder
   named("TigersFury",          Cat_TigersFury),             -- CD: Energy boost
   named("WolfsheadShred",      Cat_WolfsheadShred),         -- Shift: Wolfshead optimization
   named("EarlyShift",          Cat_EarlyShift),             -- Shift: Low-energy powershift
}, {
   context_builder = get_cat_state,
   check_prerequisites = function(strategy, context)
      if strategy.requires_stealth ~= nil and strategy.requires_stealth ~= context.is_stealthed then return false end
      if strategy.requires_behind ~= nil and strategy.requires_behind ~= context.is_behind then return false end
      if strategy.requires_clearcasting ~= nil and strategy.requires_clearcasting ~= context.has_clearcasting then return false end
      if strategy.min_energy and context.energy < strategy.min_energy then return false end
      if strategy.min_cp and context.cp < strategy.min_cp then return false end
      return true
   end,
})

end  -- End Cat strategies scope block

print("|cFF00FF00[Flux AIO Cat]|r 21 Cat strategies registered.")
