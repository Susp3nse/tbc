-- Menagerie - Main Module
-- Generic context creation and main rotation dispatcher
-- MUST LOAD LAST - after all strategies are registered

-- ============================================================
-- This is the entry point. It creates the context and dispatches
-- to the appropriate strategies based on active playstyle.
-- All class-specific logic lives in class_config callbacks.
-- ============================================================

local NS = _G.Menagerie
if not NS then
   print("|cFFFF0000[Menagerie Main]|r Core module not loaded!")
   return
end

if not NS.rotation_registry then
   print("|cFFFF0000[Menagerie Main]|r Registry not found!")
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
local debug_log = NS.debug_log
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
local IsResting = _G.IsResting
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local GetTime = _G.GetTime

-- Suggestion system for A[1] icon
local suggestion = { spell = nil }

-- ============================================================================
-- ROTATION REGISTRY EXECUTION METHODS
-- ============================================================================

-- Resolve force-bypass + auto-burst gating for a middleware/strategy entry.
-- Returns: forced (bool), burst_blocked (bool). default_target differs per loop
-- (middleware defaults to "player", strategies to TARGET_UNIT).
local function resolve_forced(entry, context, default_target)
   local forced = (context.force_burst and entry.is_burst)
      or (context.force_defensive and entry.is_defensive)
   -- Safety: even when forced, the spell must still be ready (CD, range, stance)
   if forced and entry.spell then
      if not entry.spell:IsReady(entry.spell_target or default_target) then forced = false end
   end
   local burst_blocked = entry.is_burst and (not forced) and context.auto_burst == false
   return forced, burst_blocked
end

-- Attach a formatted context snapshot to a debug-log entry. Strategy path: the
-- caller already has the playstyle's format_context_log + state in scope, so it
-- passes them in directly. `e` may be nil (debug_log returns nil when throttled).
local function attach_ctx(e, log_context, format_context_log, context, state)
   if e and log_context and format_context_log then
      e.ctx = format_context_log(context, state)
   end
end

-- Middleware path: middleware runs above playstyle selection, so there is no
-- single playstyle/state in scope. Resolve the active playstyle's formatter and
-- state here, then attach. Mirrors attach_ctx for the middleware call sites.
local function attach_mw_ctx(registry, e, log_context, context)
   if not (e and log_context) then return end
   local cc = registry.class_config
   local playstyle = cc and cc.get_active_playstyle and cc.get_active_playstyle(context)
   local config = playstyle and registry.playstyle_config[playstyle]
   local format_context_log = config and config.format_context_log
   if format_context_log then
      e.ctx = format_context_log(context, registry:get_playstyle_state(playstyle, context))
   end
end

--- Executes middleware. Returns: result, log_message (optional)
function rotation_registry:execute_middleware(icon, context)
   local debug_mode = context.settings and context.settings.debug_mode
   local debug_system = context.settings and context.settings.debug_system
   local log_context = context.settings
      and context.settings.log_context
      and context.in_combat
      and context.has_valid_enemy_target

   for _, mw in ipairs(self.middleware) do
      if (not context.on_gcd and mw.is_gcd_gated ~= false)
         or (mw.is_gcd_gated == false) then

         local forced, burst_blocked = resolve_forced(mw, context, "player")
         -- Setting key gate: skip if user disabled this middleware (forced bypasses, same as strategies)
         local setting_ok = forced or not mw.setting_key or context.settings[mw.setting_key]
         local matches = setting_ok and not burst_blocked and (forced or mw.matches(context))

         if matches then
            NS.last_action_target_unit = nil
            local result, log_msg = mw.execute(icon, context)
            if result then
               if debug_mode and log_msg and debug_log then
                  local clean_msg = log_msg:gsub("^%[MW%] ", "")
                  if forced and not clean_msg:find("[FORCED]", 1, true) then
                     clean_msg = "[FORCED] " .. clean_msg
                  end
                  attach_mw_ctx(self, debug_log("MW", "ACT", forced, "%s", clean_msg), log_context, context)
               elseif debug_system and debug_log then
                  attach_mw_ctx(self, debug_log("MW", "EXEC", forced, "%s (P%d)%s",
                     mw.name, mw.priority, forced and " [FORCED]" or ""), log_context, context)
               end
               set_last_action(mw.name, "MW", NS.last_action_target_unit or mw.spell_target or "player")
               return result
            elseif debug_system and debug_log then
               attach_mw_ctx(self, debug_log("MW", "NOOP", forced, "%s (P%d)%s",
                  mw.name, mw.priority, forced and " [FORCED]" or ""), log_context, context)
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
   local src = "STRAT:" .. playstyle:upper()
   local log_context = context.settings
      and context.settings.log_context
      and context.in_combat
      and context.has_valid_enemy_target
   local format_context_log = config and config.format_context_log

   for _, strategy in ipairs(strategies) do
      if not context.on_gcd or strategy.is_gcd_gated == false then
         local forced, burst_blocked = resolve_forced(strategy, context, TARGET_UNIT)
         local passes = not burst_blocked and (forced or (
            self:check_prerequisites(strategy, context)
            and (not config_prereqs or config_prereqs(strategy, context))
            and (not strategy.matches or strategy.matches(context, state))
         ))

         if passes then
            NS.last_action_target_unit = nil
            local result, log_msg = strategy.execute(icon, context, state)

            if result then
               if debug_mode and log_msg and debug_log then
                  attach_ctx(debug_log(src, "ACT", forced, "%s%s", forced and "[FORCED] " or "", log_msg),
                     log_context, format_context_log, context, state)
               elseif debug_system and debug_log then
                  attach_ctx(debug_log(src, "EXEC", forced, "%s%s", strategy.name, forced and " [FORCED]" or ""),
                     log_context, format_context_log, context, state)
               end
               set_last_action(strategy.name, playstyle, NS.last_action_target_unit or strategy.spell_target or TARGET_UNIT)
               return result
            elseif debug_system and debug_log then
               attach_ctx(debug_log(src, "NOOP", forced, "%s%s", strategy.name, forced and " [FORCED]" or ""),
                  log_context, format_context_log, context, state)
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
      rotation_registry:validate_playstyle_spells(active)
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
local build_number = NS.BUILD_NUMBER or "dev"

-- Count strategies per registered playstyle
local strategy_summary = {}
for ps, strats in pairs(rotation_registry.strategy_maps) do
   strategy_summary[#strategy_summary + 1] = ps .. "=" .. #strats
end
local mw_count = rotation_registry.middleware and #rotation_registry.middleware or 0

print(format("|cffe08a3c[Menagerie]|r %s loaded! %s | Build: %s", class_label, class_version, build_number))
print(format("|cFF00FF00[Menagerie]|r Strategies: %s", table.concat(strategy_summary, ", ")))
print(format("|cFF00FF00[Menagerie]|r Middleware: %d handlers registered", mw_count))
