-- Flux AIO - Main Module
-- Generic context creation and main rotation dispatcher
-- MUST LOAD LAST - after all strategies are registered

-- ============================================================
-- This is the entry point. It creates the context and dispatches
-- to the appropriate strategies based on active playstyle.
-- All class-specific logic lives in class_config callbacks.
-- ============================================================

local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Main]|r Core module not loaded!")
   return
end

if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Main]|r Registry not found!")
   return
end

-- Import commonly used references
local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local cached_settings = NS.cached_settings
local refresh_settings = NS.refresh_settings
local get_time_to_die = NS.get_time_to_die
local has_phys_immunity = NS.has_phys_immunity
local has_magic_immunity = NS.has_magic_immunity
local has_spell_reflect = NS.has_spell_reflect
local debug_print = NS.debug_print
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

-- Force command system
local is_force_active = NS.is_force_active
local clear_force_flag = NS.clear_force_flag
local should_auto_burst = NS.should_auto_burst
local show_notification = NS.show_notification
local set_last_action = NS.set_last_action

-- Lua optimizations
local format = string.format
local ipairs = ipairs
local pairs = pairs
local type = type
local tostring = tostring
local table_sort = table.sort
local table_concat = table.concat
local IsResting = _G.IsResting
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local GetTime = _G.GetTime
local AddDebugLogLine = NS.AddDebugLogLine

-- Context logging
local last_context_log_time = 0
local CONTEXT_LOG_INTERVAL = 2.0
-- Pre-allocated table for default context dump (avoids per-frame allocation)
local ctx_dump_parts = {}

-- Suggestion system for A[1] icon
local suggestion = { spell = nil }
local last_validated_active = nil

-- ============================================================================
-- ROTATION REGISTRY EXECUTION METHODS
-- ============================================================================

--- Executes middleware. Returns: result, log_message (optional)
function rotation_registry:execute_middleware(icon, context)
   local debug_mode = context.settings and context.settings.debug_mode
   local debug_system = context.settings and context.settings.debug_system
   local force_burst = context.force_burst
   local force_defensive = context.force_defensive
   local auto_burst = context.auto_burst

   for _, mw in ipairs(self.middleware) do
      if (not context.on_gcd and mw.is_gcd_gated ~= false)
         or (mw.is_gcd_gated == false) then

      -- Force-bypass: skip matches() for tagged middleware when force flag active
      local forced = (force_burst and mw.is_burst) or (force_defensive and mw.is_defensive)
      -- Safety: even when forced, spell must still be ready (CD, range, stance)
      if forced and mw.spell then
         local target = mw.spell_target or "player"
         if not mw.spell:IsReady(target) then forced = false end
      end
      -- Auto-burst gate: skip burst middleware when conditions configured but unmet
      local burst_blocked = mw.is_burst and (not forced) and auto_burst == false
      -- Setting key gate: skip if user disabled this middleware (forced bypasses, same as strategies)
      local setting_ok = forced or not mw.setting_key or context.settings[mw.setting_key]
      local matches = setting_ok and not burst_blocked and (forced or mw.matches(context))

      if matches then
         NS.last_action_target_unit = nil
         local result, log_msg = mw.execute(icon, context)
         if result then
            if debug_mode and log_msg and debug_print then
                debug_print(format("[MW] %s%s", forced and "[FORCED] " or "", log_msg))
            elseif debug_system and debug_print then
               debug_print(format("[MW] EXECUTED %s (P%d)%s", mw.name, mw.priority, forced and " [FORCED]" or ""))
            end
            set_last_action(mw.name, "MW", NS.last_action_target_unit or mw.spell_target or "player")
            return result
         elseif debug_system and debug_print then
            debug_print(format("[MW] NO_ACTION %s (P%d)%s", mw.name, mw.priority, forced and " [FORCED]" or ""))
         end
      end
      end
   end

   return nil
end

--- Executes strategies for playstyle. Returns: result, log_message (optional)
function rotation_registry:execute_strategies(playstyle, icon, context)
   local debug_mode = context.settings and context.settings.debug_mode
   local debug_system = context.settings and context.settings.debug_system
   local strategies = self.strategy_maps[playstyle]

   if not strategies then
      return nil
   end

   local config = self.playstyle_config[playstyle]
   local config_prereqs = config and config.check_prerequisites
   local state = self:get_playstyle_state(playstyle, context)
   local force_burst = context.force_burst
   local force_defensive = context.force_defensive
   local auto_burst = context.auto_burst

   -- Periodic context dump (gated by "Log Context" checkbox)
   if context.settings.log_context and context.in_combat and context.has_valid_enemy_target then
      local now = GetTime()
      if (now - last_context_log_time) >= CONTEXT_LOG_INTERVAL then
         last_context_log_time = now
         local msg
         if config and config.format_context_log then
            msg = config.format_context_log(context, state)
         else
            -- Default: dump all scalar context fields
            local n = 0
            for k, v in pairs(context) do
               local t = type(v)
               if t ~= "function" and t ~= "table" and t ~= "userdata" then
                  n = n + 1
                  ctx_dump_parts[n] = k .. "=" .. tostring(v)
               end
            end
            -- Clear stale entries from previous frame
            for i = n + 1, #ctx_dump_parts do ctx_dump_parts[i] = nil end
            table_sort(ctx_dump_parts)
            msg = table_concat(ctx_dump_parts, " ")
         end
         AddDebugLogLine(format("[%.1fs] [%s CTX] %s", now, playstyle:upper(), msg))
      end
   end

   for _, strategy in ipairs(strategies) do
      if not context.on_gcd or strategy.is_gcd_gated == false then
         -- Force-bypass: skip prerequisites and matches() for tagged strategies
         local forced = (force_burst and strategy.is_burst) or (force_defensive and strategy.is_defensive)
         -- Safety: even when forced, spell must still be ready (CD, range, stance)
         if forced and strategy.spell then
            local target = strategy.spell_target or TARGET_UNIT
            if not strategy.spell:IsReady(target) then forced = false end
         end
         -- Auto-burst gate: skip burst strategies when conditions configured but unmet
         local burst_blocked = strategy.is_burst and (not forced) and auto_burst == false
         local passes = not burst_blocked and (forced or (
            self:check_prerequisites(strategy, context)
            and (not config_prereqs or config_prereqs(strategy, context))
            and (not strategy.matches or strategy.matches(context, state))
         ))

         if passes then
            NS.last_action_target_unit = nil
            local result, log_msg = strategy.execute(icon, context, state)

            if result then
               if debug_mode and log_msg and debug_print then
                  debug_print(format("[%s] %s%s", playstyle:upper(), forced and "[FORCED] " or "", log_msg))
               elseif debug_system and debug_print then
                  debug_print(format("[%s] EXECUTED %s%s", playstyle:upper(), strategy.name, forced and " [FORCED]" or ""))
               end
               set_last_action(strategy.name, playstyle, NS.last_action_target_unit or strategy.spell_target or TARGET_UNIT)
               return result
            elseif debug_system and debug_print then
               debug_print(format("[%s] NO_ACTION %s%s", playstyle:upper(), strategy.name, forced and " [FORCED]" or ""))
            end
         end
      end
   end
   return nil
end

-- ============================================================================
-- CONTEXT CREATION
-- ============================================================================

--- Reusable context table (avoid allocation every frame)
local reusable_context = {}

--- Creates rotation context (reused table, do not hold references)
local function create_context(icon)
   local ctx = reusable_context
   for k in pairs(ctx) do
      ctx[k] = nil
   end
   local player_unit = Unit(PLAYER_UNIT)
   local target_unit = Unit(TARGET_UNIT)
   local gcd_remaining = Player:GCDRemains()
   local on_gcd = gcd_remaining > 0.1

   local combat_time = player_unit:CombatTime()
   local combat_status = combat_time > 0

   local mana_pct = Player:ManaPercentage()

   -- GetRange returns (maxRange, minRange) - use minRange for accurate melee detection
   local max_range, min_range = target_unit:GetRange()

   -- Generic fields (all classes)
   ctx.on_gcd = on_gcd
   ctx.icon = icon
   ctx.in_combat = (combat_status == 1 or combat_status == true)
   ctx.hp = player_unit:HealthPercent()
   ctx.mana_pct = mana_pct
   ctx.mana = Player:Mana()
   ctx.target_exists = target_unit:IsExists()
   ctx.target_dead = target_unit:IsDead()
   ctx.target_enemy = ctx.target_exists and UnitCanAttack and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT) or false
   ctx.has_valid_enemy_target = ctx.target_exists and not ctx.target_dead and ctx.target_enemy
   ctx.target_hp = target_unit:HealthPercent()
   ctx.ttd = get_time_to_die(TARGET_UNIT)
   ctx.target_range = max_range or 0
   ctx.in_melee_range = (min_range and min_range <= 5) or false
   ctx.target_phys_immune = has_phys_immunity(TARGET_UNIT)
   ctx.target_magic_immune = has_magic_immunity(TARGET_UNIT)
   ctx.target_spell_reflect = has_spell_reflect(TARGET_UNIT)
   ctx.is_boss = ctx.has_valid_enemy_target and target_unit:IsBoss()
   if ctx.has_valid_enemy_target then
       local c = _G.UnitClassification(TARGET_UNIT)
       ctx.target_is_elite = ctx.is_boss or c == "elite" or c == "worldboss" or c == "rareelite"
   else
       ctx.target_is_elite = false
   end
   ctx.combat_time = combat_time
   ctx.settings = cached_settings
   ctx.gcd_remaining = gcd_remaining

   -- Class-specific context extension (stance, energy, rage, cp, etc.)
   local cc = rotation_registry.class_config
   if cc and cc.extend_context then
      cc.extend_context(ctx)
   end

   return ctx
end

-- ============================================================================
-- MAIN ROTATION DISPATCHER
-- ============================================================================

-- Main rotation entry point (A[3])
A[3] = function(icon)
   local cc = rotation_registry.class_config
   if not cc then return end

   refresh_settings()

   -- Reset suggestion each frame
   suggestion.spell = nil

   -- Auto-disable in rested zones (inns/cities) before building full context.
   if IsResting() and not UnitAffectingCombat(PLAYER_UNIT) then
      set_last_action(nil, nil)
      NS.last_rotation_context = nil
      NS.last_rotation_context_time = 0
      return
   end

   local context = create_context(icon)
   -- Hoist per-frame force/burst state onto the context so the dispatch path
   -- (middleware + idle + active) reads it once instead of recomputing 3x/frame.
   context.force_burst = is_force_active("force_burst")
   context.force_defensive = is_force_active("force_defensive")
   context.auto_burst = should_auto_burst(context)
   NS.last_rotation_context = context
   NS.last_rotation_context_time = GetTime()

   -- Reset last action each frame
   set_last_action(nil, nil)

   -- Gap closer: keeps showing gap spell on icon for 3s window.
   -- Once spell fires (goes on CD), handler returns nil → normal rotation resumes.
   if is_force_active("force_gap") then
      if not context.has_valid_enemy_target then
         clear_force_flag("force_gap")
      elseif cc.gap_handler then
         local result = cc.gap_handler(icon, context)
         if result then
            set_last_action("Gap Closer", "CMD")
            return result
         end
      else
         clear_force_flag("force_gap")
         show_notification("No gap closer available", 1.5, { 1.0, 0.4, 0.4 })
      end
   end

   -- Run middleware first (shared concerns: recovery items, CDs)
   local mw_result = rotation_registry:execute_middleware(icon, context)
   if mw_result then
      return mw_result
   end

   -- Determine active and idle playstyles via class callbacks
   local active = cc.get_active_playstyle(context)
   local idle = cc.get_idle_playstyle and cc.get_idle_playstyle(context)

   -- Populate suggestions when NOT in idle form
   -- A[1] icon shows the most important idle-form ability the player would want
   if not idle and cc.idle_playstyle_name then
      local idle_strategies = rotation_registry.strategy_maps[cc.idle_playstyle_name]
      if idle_strategies then
         for _, strategy in ipairs(idle_strategies) do
            if strategy.should_suggest and strategy.should_suggest(context) and strategy.suggestion_spell then
               suggestion.spell = strategy.suggestion_spell
               break
            end
         end
      end
   end

   -- Run idle playstyle strategies (e.g., caster self-care when in caster form)
   if idle then
      local result = rotation_registry:execute_strategies(idle, icon, context)
      if result then
         return result
      end
   end

   -- Run active playstyle strategies (cat, bear, balance, resto, etc.)
   if active then
      if active ~= last_validated_active then
         rotation_registry:validate_playstyle_spells(active)
         last_validated_active = active
      end
      local result = rotation_registry:execute_strategies(active, icon, context)
      if result then
         return result
      end
   end
end

-- Suggestion icon (A[1]) - shows what spell to cast if player shifts to idle form
A[1] = function(icon)
   if suggestion.spell then
      return suggestion.spell:Show(icon)
   end
end
A[4] = nil
A[5] = nil
A[6] = nil
A[7] = nil
A[8] = nil

-- ============================================================================
-- INITIALIZATION COMPLETE
-- ============================================================================

-- Print load summary (dynamic from class_config)
local cc = rotation_registry.class_config
local class_label = cc and cc.name or "Unknown"
local class_version = NS.format_class_version and NS.format_class_version(cc) or (cc and cc.version or "?")
local build_label = NS.BUILD_LABEL or "dev"

-- Count strategies per registered playstyle
local strategy_summary = {}
for ps, strats in pairs(rotation_registry.strategy_maps) do
   strategy_summary[#strategy_summary + 1] = ps .. "=" .. #strats
end
local mw_count = rotation_registry.middleware and #rotation_registry.middleware or 0

print(format("|cff6c63ff[Flux AIO]|r %s %s loaded successfully! Build: %s", class_label, class_version, build_label))
print(format("|cFF00FF00[Flux AIO]|r Strategies: %s", table.concat(strategy_summary, ", ")))
print(format("|cFF00FF00[Flux AIO]|r Middleware: %d handlers registered", mw_count))
