--- Bear Module
--- Bear (Feral Tank) playstyle strategies
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
   print("|cFFFF0000[Flux AIO Bear]|r Core module not loaded!")
   return
end

-- Validate dependencies
if not NS.rotation_registry then
   print("|cFFFF0000[Flux AIO Bear]|r Registry not found in Core!")
   return
end

-- Import commonly used references
local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast_fmt = NS.try_cast_fmt
local is_spell_available = NS.is_spell_available
local get_debuff_state = NS.get_debuff_state
local get_time_until_swing = NS.get_time_until_swing
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local CONST = A.Const

-- Lua optimizations
local format = string.format

-- Debuff ID tables
local DEMO_ROAR_DEBUFF_IDS = NS.DEMO_ROAR_DEBUFF_IDS
local MANGLE_DEBUFF_IDS = NS.MANGLE_DEBUFF_IDS

-- Utility imports
local get_spell_rage_cost = NS.get_spell_rage_cost
local AddDebugLogLine = NS.AddDebugLogLine
local GetTime = _G.GetTime

-- Import factory functions from Core
local create_faerie_fire_strategy = NS.create_faerie_fire_strategy
local create_combat_strategy = NS.create_combat_strategy
local named = NS.named

-- ============================================================================
-- BEAR (FERAL TANK) STRATEGIES
-- ============================================================================
do
   -- Bear-local helpers
   local function get_swipe_threshold(ctx)
      return ctx.settings.swipe_min_targets or Constants.BEAR.DEFAULT_SWIPE_TARGETS
   end

   local function get_lacerate_info()
      return get_debuff_state(A.Lacerate, TARGET_UNIT, "player")
   end

   -- Check if Lacerate maintenance is enabled (spell available + settings allow it)
   local function should_maintain_lacerate(ctx)
      if not is_spell_available(A.Lacerate) then return false end
      if ctx.settings.maintain_lacerate == false then return false end
      if ctx.settings.lacerate_boss_only and not Unit(TARGET_UNIT):IsBoss() then return false end
      return true
   end

   -- Hold GCD for Mangle: sim explicitly waits for Mangle rather than
   -- wasting a 1.5s GCD on filler when Mangle is almost ready.
   -- Returns true if filler abilities should yield.
   local MANGLE_HOLD_WINDOW = 0.5  -- seconds; only hold when Mangle is truly imminent
   local function should_hold_for_mangle()
      if not is_spell_available(A.MangleBear) then return false end
      local cd = A.MangleBear:GetCooldown()
      return cd > 0 and cd <= MANGLE_HOLD_WINDOW
   end

   local function is_target_cc_locked(threshold)
      local cc_remaining = Unit(TARGET_UNIT):InCC() or 0
      return cc_remaining > threshold
   end

   local function is_targettarget_healer()
      if not _G.UnitExists("targettarget") then return false end
      return Unit("targettarget"):IsHealer() == true
   end

   -- Check if a mob is being tanked by another tank (not us)
   -- Returns true if the mob's target is another player detected as a tank
   local function is_other_tank_target(unitID)
      unitID = unitID or TARGET_UNIT
      local mobTarget = unitID .. "target"
      if not _G.UnitExists(mobTarget) then return false end
      if _G.UnitIsUnit(mobTarget, PLAYER_UNIT) then return false end
      if not _G.UnitIsPlayer(mobTarget) then return false end
      return Unit(mobTarget):IsTank() == true
   end

   -- Threat level helper: returns 0-3 threat status for a unit
   -- 0 = not on threat table, 1 = have threat but not tanking,
   -- 2 = insecurely tanking, 3 = securely tanking (highest threat)
   -- Fallback: if API says 0/1 but mob's target is us, treat as 2
   local function get_target_threat(unitID)
      unitID = unitID or TARGET_UNIT
      local threat = _G.UnitThreatSituation(PLAYER_UNIT, unitID) or 0
      if threat < 2 then
         local tt = unitID .. "target"
         if _G.UnitExists(tt) and _G.UnitIsUnit(tt, PLAYER_UNIT) then
            return 2
         end
      end
      return threat
   end

   -- AoE floor: when swipe_min=1, AoE optimization still kicks in at this enemy count
   local AOE_MIN_ENEMIES = 3

   -- Effective AoE threshold: respects user setting, but floors at AOE_MIN_ENEMIES for swipe_min=1
   -- Bump threshold +1 only when elites/bosses are a MINORITY among trash — i.e. a single
   -- high-value target in a trash pack, where Lacerate focus beats cleave. On elite-heavy
   -- packs (pure elites, or elites >= trash), trust the user's setting and cleave for threat.
   local function get_aoe_threshold(ctx, state)
      local swipe_min = get_swipe_threshold(ctx)
      local base = swipe_min <= 1 and AOE_MIN_ENEMIES or swipe_min
      if state then
         local priority_targets = state.nearby_bosses + state.nearby_elites
         if priority_targets > 0 and priority_targets < state.nearby_trash then
            return base + 1
         end
      end
      return base
   end

   -- CC safety: prevent Swipe from breaking nearby breakable CC
   -- Name-based checks (not "BreakAble" category) so we detect ANY caster's debuffs
   local SWIPE_CC_CHECK_RANGE = 10  -- yards; slightly wider than melee for safety
   local BREAKABLE_CC_NAMES = {
      "Polymorph",            -- Mage
      "Freezing Trap Effect", -- Hunter
      "Repentance",           -- Paladin
      "Blind",                -- Rogue
      "Sap",                  -- Rogue
      "Gouge",                -- Rogue
      "Hibernate",            -- Druid
      "Wyvern Sting",         -- Hunter
      "Scatter Shot",         -- Hunter
      "Shackle Undead",       -- Priest
      "Seduction"            -- Warlock (Succubus)
   }
   local NUM_BREAKABLE_CC = #BREAKABLE_CC_NAMES

   local function has_breakable_cc_nearby()
      local plates = A.MultiUnits:GetActiveUnitPlates()
      for unitID in pairs(plates) do
         if Unit(unitID):GetRange() <= SWIPE_CC_CHECK_RANGE then
            for i = 1, NUM_BREAKABLE_CC do
               if (Unit(unitID):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
                  return true
               end
            end
         end
      end
      return false
   end

   -- =========================================================================
   -- TAB TARGETING (multi-mob threat management)
   -- =========================================================================
   -- Determines when to switch targets to spread threat across multiple mobs.
   -- Priority:
   --   1. Switch OFF CC'd targets to valid ones
   --   2. Pick up loose mobs (not targeting us) when we're not managing too many
   --   3. Spread Lacerate stacks for DPS when below Swipe threshold
   local function is_target_breakable_cc()
      for i = 1, NUM_BREAKABLE_CC do
         if (Unit(TARGET_UNIT):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
            return true
         end
      end
      return false
   end

   -- Forward declaration: populated below, needed by should_tab_target
   local bear_state

   -- Unit priority for tab-targeting: boss > elite > trash
   local PRIO_BOSS = 3
   local PRIO_ELITE = 2
   local PRIO_TRASH = 1
   local function get_unit_priority(unitID)
      local class = _G.UnitClassification(unitID)
      if class == "worldboss" then return PRIO_BOSS end
      if class == "elite" or class == "rareelite" then return PRIO_ELITE end
      return PRIO_TRASH
   end

   local TAB_MAX_ATTEMPTS = 10  -- safety: give up cycling after this many frames
   local MANUAL_TARGET_GRACE = 3  -- seconds: don't tab-target after manual target selection

   -- Convert setting string to minimum priority threshold
   local function get_min_priority_from_setting(setting)
      if setting == "bosses" then return PRIO_BOSS end
      if setting == "elites" then return PRIO_ELITE end
      return PRIO_TRASH  -- "all" or nil
   end

   local function should_tab_target(ctx, state)
      if not ctx.settings.enable_tab_targeting then
         bear_state.tab_target_desired = nil
         return false
      end

      -- Mid-cycle: we're actively cycling toward a desired target
      local desired = bear_state.tab_target_desired
      if desired then
         -- Landed on it → done
         if _G.UnitExists(TARGET_UNIT) and _G.UnitIsUnit(TARGET_UNIT, desired) then
            bear_state.tab_target_desired = nil
            bear_state.tab_target_attempts = 0
            return false
         end
         -- Desired target gone or out of melee → abort
         if not _G.UnitExists(desired) or _G.UnitIsDead(desired)
            or A.MangleBear:IsInRange(desired) ~= true then
            bear_state.tab_target_desired = nil
            bear_state.tab_target_attempts = 0
            return false
         end
         -- Max attempts → give up (prevent infinite cycling)
         bear_state.tab_target_attempts = bear_state.tab_target_attempts + 1
         if bear_state.tab_target_attempts > TAB_MAX_ATTEMPTS then
            bear_state.tab_target_desired = nil
            bear_state.tab_target_attempts = 0
            return false
         end
         return true  -- keep cycling
      end

      -- Respect manual target selection: don't override player clicks for a few seconds
      -- Covers: targeting out-of-range mob to Feral Charge, clicking teammate to Innervate, etc.
      if (GetTime() - bear_state.manual_target_time) < MANUAL_TARGET_GRACE then return false end

      -- Normal evaluation: decide IF and WHERE to switch
      if _G.UnitIsPlayer(TARGET_UNIT) then return false end

      -- Switch if current target is dead or doesn't exist
      if not _G.UnitExists(TARGET_UNIT) or _G.UnitIsDead(TARGET_UNIT) then return true end

      if Unit(TARGET_UNIT):CombatTime() == 0 then return false end

      -- Switch away from CC'd target to find a valid one (no specific target, AUTOTARGET picks)
      if is_target_breakable_cc() then return true end

      -- Current target out of melee or not visible → fall through to scan
      local current_out_of_range = not ctx.in_melee_range or not _G.UnitIsVisible(TARGET_UNIT)
      -- Current target is another tank's mob → need to switch, let scan find our mob
      local current_other_tank = not current_out_of_range and is_other_tank_target()

      -- With only 1 enemy and it's not another tank's mob, nothing to tab to
      if ctx.enemy_count < 2 and not current_other_tank and not current_out_of_range then return false end

      -- Threat-level-aware current-target decision:
      --   other_tank / out_of_range = treat as secure (3) to force scan
      --   0 = stay (urgently need threat here)
      --   1 = stay unless threat-0 mob exists (scan will check)
      --   2 = insecure — scan for threat 0-1 mobs only
      --   3 = secure — scan for threat 0-2 mobs (safe to leave)
      local currentThreat = (current_out_of_range or current_other_tank) and 3 or get_target_threat()
      if currentThreat == 0 then return false end -- absolutely stay, we have zero threat

      -- Scan nameplates: categorize mobs by threat level + unit priority
      -- Threat tiers: 0 (no threat) > 1 (have threat, not tanking) > 2 (insecure)
      -- Within each tier, prefer boss > elite > trash
      local maxMobsToManage = ctx.settings.tab_max_mobs or 4
      local minPriority = get_min_priority_from_setting(ctx.settings.tab_min_priority)
      local secureMobs = 0  -- count of threat-3 mobs (for max-mobs check)
      local mobsWithLowLacerate = 0
      local bestLacUnit, bestLacPriority = nil, 0
      local bestInRangeUnit, bestInRangePriority = nil, 0

      -- Best target per threat tier (primary sort: threat asc, secondary: unit priority desc)
      local bestT0Unit, bestT0Prio = nil, 0  -- threat 0: not on threat table
      local bestT1Unit, bestT1Prio = nil, 0  -- threat 1: have threat, not tanking
      local bestT2Unit, bestT2Prio = nil, 0  -- threat 2: insecurely tanking
      local t0Count, t1Count, t2Count = 0, 0, 0

      -- Threat equalization: among secure (threat 3) mobs, track the one with lowest threatValue
      local lowestSecureUnit = nil
      local lowestSecureThreatVal = math.huge

      local plates = A.MultiUnits:GetActiveUnitPlates()
      for unitID in pairs(plates) do
         if unitID
            and _G.UnitExists(unitID)
            and not _G.UnitIsDead(unitID)
            and not _G.UnitIsPlayer(unitID)
            and not _G.UnitIsUnit(unitID, TARGET_UNIT)
            and Unit(unitID):CombatTime() > 0
            and A.MangleBear:IsInRange(unitID) == true
            and (Unit(unitID):InCC() or 0) == 0
            and not is_other_tank_target(unitID) -- skip mobs another tank is handling
         then
            local unitTTD = Unit(unitID):TimeToDie()
            local unitIsDying = unitTTD > 0 and unitTTD < 5

            if not unitIsDying then
               local unitThreat = get_target_threat(unitID)
               local unitPriority = get_unit_priority(unitID)

               -- Track best in-range unit overall (for out-of-range swap)
               if unitPriority > bestInRangePriority then
                  bestInRangePriority = unitPriority
                  bestInRangeUnit = unitID
               end

               if unitThreat == 3 then
                  secureMobs = secureMobs + 1
                  -- Track lowest-threat secure mob for equalization
                  local _, _, _, tvRaw = _G.UnitDetailedThreatSituation(PLAYER_UNIT, unitID)
                  local tv = tvRaw or 0
                  if tv < lowestSecureThreatVal then
                     lowestSecureThreatVal = tv
                     lowestSecureUnit = unitID
                  end
               elseif unitThreat == 2 then
                  t2Count = t2Count + 1
                  if unitPriority >= minPriority and unitPriority > bestT2Prio then
                     bestT2Prio = unitPriority
                     bestT2Unit = unitID
                  end
               elseif unitThreat == 1 then
                  t1Count = t1Count + 1
                  if unitPriority >= minPriority and unitPriority > bestT1Prio then
                     bestT1Prio = unitPriority
                     bestT1Unit = unitID
                  end
               else -- unitThreat == 0
                  t0Count = t0Count + 1
                  if unitPriority >= minPriority and unitPriority > bestT0Prio then
                     bestT0Prio = unitPriority
                     bestT0Unit = unitID
                  end
               end

               -- Count mobs with low lacerate stacks for DPS optimization
               if is_spell_available(A.Lacerate) then
                  local unitLacerateStacks = Unit(unitID):HasDeBuffsStacks(A.Lacerate.ID, true)
                  if unitLacerateStacks < 3 then
                     mobsWithLowLacerate = mobsWithLowLacerate + 1
                     if unitPriority > bestLacPriority then
                        bestLacPriority = unitPriority
                        bestLacUnit = unitID
                     end
                  end
               end
            end
         end
      end

      -- Select best tab-target based on current threat level:
      -- Lower threat tier = more urgent. Only switch to mobs MORE urgent than current.
      local looseMobs = t0Count + t1Count
      local bestUnit = nil

      if currentThreat == 1 then
         -- We have threat but not tanking: only switch for threat-0 mobs (completely uncontrolled)
         if t0Count > 0 and bestT0Unit then bestUnit = bestT0Unit end
      elseif currentThreat == 2 then
         -- Insecurely tanking: switch for loose mobs (threat 0-1)
         if bestT0Unit then bestUnit = bestT0Unit
         elseif bestT1Unit then bestUnit = bestT1Unit end
      elseif currentThreat >= 3 then
         -- Securely tanking: switch for loose (0-1) or insecure (2) mobs
         if bestT0Unit then bestUnit = bestT0Unit
         elseif bestT1Unit then bestUnit = bestT1Unit
         elseif bestT2Unit then bestUnit = bestT2Unit end
      end

      -- Don't exceed max mobs to manage
      if bestUnit and looseMobs > 0 and secureMobs >= maxMobsToManage then
         -- Only switch if the target is truly loose (threat 0-1), not insecure
         local bestThreat = get_target_threat(bestUnit)
         if bestThreat >= 2 then bestUnit = nil end
      end

      if bestUnit then
         bear_state.tab_target_desired = bestUnit
         bear_state.tab_target_attempts = 0
         return true
      end

      -- Threat equalization: when all mobs securely tanked, rotate to the lowest-threat mob
      -- so Mangle/Maul/Swipe/Lacerate build threat on the weakest link
      if currentThreat >= 3 and not current_out_of_range
         and t0Count == 0 and t1Count == 0 and t2Count == 0
         and lowestSecureUnit
      then
         -- Only switch if the lowest mob has meaningfully less threat than current target
         local _, _, _, currentThreatVal = _G.UnitDetailedThreatSituation(PLAYER_UNIT, TARGET_UNIT)
         currentThreatVal = currentThreatVal or 0
         -- 10% threshold to prevent ping-ponging between similar-threat mobs
         if currentThreatVal > 0 and lowestSecureThreatVal < (currentThreatVal * 0.9) then
            bear_state.tab_target_desired = lowestSecureUnit
            bear_state.tab_target_attempts = 0
            return true
         end
      end

      -- DPS optimization: Spread lacerate on multi-target (but below swipe threshold)
      -- Only do this on non-boss fights to maximize DPS
      if ctx.settings.tab_spread_lacerate ~= false and not ctx.is_boss and ctx.enemy_count >= 2 and ctx.enemy_count < 3 then
         local currentLacerateStacks = state.lacerate_stacks
         if currentLacerateStacks >= 3 and mobsWithLowLacerate > 0 then
            if bestLacUnit then
               bear_state.tab_target_desired = bestLacUnit
               bear_state.tab_target_attempts = 0
            end
            return true
         end
      end

      -- Don't swap off out-of-range target if Feral Charge is available (player may want to charge)
      if current_out_of_range and is_spell_available(A.FeralChargeBear) then
         local charge_cd = A.FeralChargeBear:GetCooldown()
         if charge_cd <= 0 then return false end
      end

      -- Current target out of melee → switch to best in-range target
      if current_out_of_range and bestInRangeUnit then
         bear_state.tab_target_desired = bestInRangeUnit
         bear_state.tab_target_attempts = 0
         return true
      end

      return false
   end

   -- =========================================================================
   -- SHARED BEAR STATE (computed once per frame, cached)
   -- =========================================================================
   bear_state = {
      maul_queued = false,     -- true while we're trying to queue Maul (spamming TMW:Fire)
      maul_confirmed = false,  -- true once IsSpellCurrent() confirms game accepted the queue
      maul_dequeue_logged = false, -- throttle: only log dequeue once per cycle
      lacerate_stacks = 0,
      lacerate_duration = 0,
      nearby_elites = 0,
      nearby_bosses = 0,
      tab_target_desired = nil,   -- nameplate unitID we're cycling toward
      tab_target_attempts = 0,   -- safety counter to prevent infinite cycling
      nearby_trash = 0,
      last_target_guid = nil,    -- GUID of last-seen target (for manual target detection)
      manual_target_time = 0,    -- GetTime() when player last manually changed targets
      last_demo_roar_cast = 0,   -- GetTime() of last Demo Roar cast (throttle tab-target spam)
      last_ff_cast = 0,          -- GetTime() of last Faerie Fire cast (throttle tab-target spam)
      last_swipe_aoe_cast = 0,   -- GetTime() of last AoE Swipe (Mangle weave: open with Swipe, then yield)
   }

   -- Rage costs (untalented base fallbacks; refreshed dynamically in get_bear_state)
   local RAGE_COST_MAUL = 15
   local RAGE_COST_MANGLE = 20
   local RAGE_COST_SWIPE = 15
   local RAGE_COST_LACERATE = 13
   local RAGE_COST_DEMO_ROAR = 10

   -- Throttle: prevent Demo Roar / FF from spamming GCDs on tab-target packs.
   -- Demo Roar is PBAoE (hits all nearby), so one cast covers the pack.
   -- FF is single-target, but burning GCDs on every tab-target hurts DPS.
   local DEMO_ROAR_THROTTLE = 10  -- seconds between casts (PBAoE covers pack)
   local FF_THROTTLE = 6          -- seconds between casts (short enough for new pulls)
   local LACERATE_BUILD_REFRESH = 6  -- reapply Lacerate when duration drops below this while building stacks

   -- =========================================================================
   -- BEAR CLEU TRACKER (swing-event Maul suppression)
   -- =========================================================================
   local player_guid = _G.UnitGUID(PLAYER_UNIT)
   local MAUL_SPELL_NAME = select(1, _G.GetSpellInfo(A.Maul.ID)) or "Maul"
   local cleu_frame = _G.CreateFrame("Frame")
   cleu_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   cleu_frame:SetScript("OnEvent", function()
      local _, event, _, srcGUID, _, _, _, _, destName, _, _, p12, p13, p14, p15, _, _, _, _, p20 = _G.CombatLogGetCurrentEventInfo()
      if srcGUID ~= player_guid then return end
      if event == "SWING_DAMAGE" or event == "SWING_MISSED" then
         if bear_state.maul_queued then
            bear_state.maul_queued = false
            bear_state.maul_confirmed = false
            bear_state.maul_dequeue_logged = false
         end
      elseif p13 == MAUL_SPELL_NAME then
         bear_state.maul_queued = false
         bear_state.maul_confirmed = false
         bear_state.maul_dequeue_logged = false
      end
   end)

   -- =========================================================================
   -- NAMEPLATE SCANNER (enemy classification by range)
   -- =========================================================================
   -- @param max_range: yard radius to check
   -- @param loose_only: if true, only count mobs NOT targeting us
   -- @return elites, bosses, trash
   local function count_nearby_enemies(max_range, loose_only)
      local plates = A.MultiUnits:GetActiveUnitPlates()
      local elites, bosses, trash = 0, 0, 0
      for unitID in pairs(plates) do
         if loose_only then
            local tt = unitID .. "target"
            if not _G.UnitExists(tt) or _G.UnitIsUnit(tt, PLAYER_UNIT) then
               -- Skip: either no target (idle) or already targeting us
               unitID = nil
            elseif is_other_tank_target(unitID) then
               -- Skip: another tank is handling this mob
               unitID = nil
            end
         end
         if unitID then
            local range = Unit(unitID):GetRange()
            if range <= max_range then
               local class = _G.UnitClassification(unitID)
               if class == "worldboss" then
                  bosses = bosses + 1
               elseif class == "elite" or class == "rareelite" then
                  elites = elites + 1
               else
                  trash = trash + 1
               end
            end
         end
      end
      return elites, bosses, trash
   end

   local function get_bear_state(context)
      if context._bear_valid then return bear_state end
      context._bear_valid = true

      -- Manual target detection: if target GUID changed and we didn't cause it, it's manual
      local current_guid = _G.UnitGUID(TARGET_UNIT)
      if current_guid ~= bear_state.last_target_guid then
         if bear_state.last_target_guid ~= nil and not bear_state.tab_target_desired then
            -- Target changed outside of our tab cycle → manual selection
            bear_state.manual_target_time = GetTime()
         end
         bear_state.last_target_guid = current_guid
      end

      if bear_state.maul_queued then
         local isc = A.Maul:IsSpellCurrent()
         if not bear_state.maul_confirmed and isc then
            bear_state.maul_confirmed = true
            AddDebugLogLine(format("[%.3fs] [MAUL] Confirmed by IsSpellCurrent", GetTime()))
         elseif bear_state.maul_confirmed and not isc then
            -- Log once, not every frame (CLEU will clear state authoritatively)
            if not bear_state.maul_dequeue_logged then
               bear_state.maul_dequeue_logged = true
               AddDebugLogLine(format("[%.3fs] [MAUL] Dequeued (IsSpellCurrent lost, awaiting CLEU)", GetTime()))
            end
         end
      end

      -- Refresh rage costs (items/talents may modify base costs)
      local cost
      cost = get_spell_rage_cost(A.Maul)
      if cost > 0 then RAGE_COST_MAUL = cost end
      cost = get_spell_rage_cost(A.MangleBear)
      if cost > 0 then RAGE_COST_MANGLE = cost end
      cost = get_spell_rage_cost(A.Swipe)
      if cost > 0 then RAGE_COST_SWIPE = cost end
      cost = get_spell_rage_cost(A.Lacerate)
      if cost > 0 then RAGE_COST_LACERATE = cost end
      cost = get_spell_rage_cost(A.DemoralizingRoar)
      if cost > 0 then RAGE_COST_DEMO_ROAR = cost end

      -- Cached debuff/buff lookups (avoids repeated queries in matches/execute)
      context.has_frenzied_regen = (Unit(PLAYER_UNIT):HasBuffs(A.FrenziedRegeneration.ID) or 0) > 0
      context.cc_nearby = context.settings.swipe_cc_check ~= false and has_breakable_cc_nearby() or false

      bear_state.lacerate_stacks, bear_state.lacerate_duration = get_lacerate_info()
      -- Classification breakdown at melee range (5yd) for Swipe/Maul/Lacerate decisions
      bear_state.nearby_elites, bear_state.nearby_bosses, bear_state.nearby_trash = count_nearby_enemies(5, false)
      return bear_state
   end

   -- Maul rage reservation: prevent other abilities from de-queuing Maul
   -- Clearcasting = free ability, can't starve anything
   local function would_starve_maul(ctx, rage_cost)
      if ctx.has_clearcasting then return false end
      return bear_state.maul_confirmed and (ctx.rage - rage_cost) < RAGE_COST_MAUL
   end

   -- Mangle rage reservation: returns true if spending rage_cost would leave us
   -- unable to Mangle when it's ready or coming off CD soon.
   local function would_starve_mangle(ctx, rage_cost)
      if ctx.has_clearcasting then return false end -- free cast, safe to spend
      local cd = A.MangleBear:GetCooldown()
      if cd <= 0 then
         -- Mangle ready NOW: if we can afford it, it fires by priority — safe to spend
         if ctx.rage >= RAGE_COST_MANGLE then return false end
         -- Can't afford Mangle — block if spending would keep us unable
         return (ctx.rage - rage_cost) < RAGE_COST_MANGLE
      end
      if cd >= 0.5 then return false end -- Mangle far off, safe to spend
      if (ctx.rage - rage_cost) >= RAGE_COST_MANGLE then return false end -- enough rage for both, safe to spend
      -- Auto-attack landing before Mangle CD means rage is incoming, safe to spend
      -- Unless Maul is queued — it consumes the swing's rage
      if ctx.in_melee_range and not bear_state.maul_queued then
         local swing_remaining = get_time_until_swing()
         if swing_remaining > 0 and swing_remaining < cd then return false end
      end
      return true -- would starve Mangle, hold rage
   end

   -- [1] Frenzied Regeneration (emergency heal)
   -- Smart: standard emergency trigger + proactive use when grouped with high rage
   -- High rage = more healing output; healers supplement, so using at 50% HP is safe
   local Bear_FrenziedRegen = {
      is_gcd_gated = false,
      is_defensive = true,
      requires_combat = true,
      setting_key = "use_frenzied_regen",
      spell = A.FrenziedRegeneration,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         -- FR drains rage for healing; need rage as fuel (not a cast cost, OoC doesn't help)
         if context.rage < 10 then return false end
         -- Standard trigger: emergency HP threshold (works solo and grouped)
         if context.hp <= context.settings.emergency_heal_hp then
            return true
         end
         -- Proactive: skip if fight is ending (save rage for next pull)
         if context.enemy_count <= 1 and context.ttd > 0 and context.ttd < 8 then
            return false
         end
         -- Proactive use: when grouped and rage-rich, use at higher threshold
         -- High rage means more total healing; healers keep us alive while FR ticks
         return context.hp <= Constants.BEAR.FRENZIED_PROACTIVE_HP
            and context.rage >= Constants.BEAR.FRENZIED_PROACTIVE_RAGE
            and _G.IsInGroup()
      end,
      execute = function(icon, context)
         local proactive = context.hp > context.settings.emergency_heal_hp
         local mode = proactive and "Proactive (grouped)" or "Emergency"
         return try_cast_fmt(A.FrenziedRegeneration, icon, PLAYER_UNIT, "[P2]", "Frenzied Regeneration", "%s - HP: %.0f%%, Rage: %d", mode, context.hp, context.rage)
      end,
   }

   -- [3] Enrage (rage generation)
   -- Smart: skips when HP is low (armor reduction ~27% is dangerous during burst)
   -- Exception: allows if Frenzied Regen is active (Enrage feeds it rage for healing)
   local Bear_Enrage = {
      is_gcd_gated = false,
      requires_combat = true,
      setting_key = "use_enrage",
      spell = A.Enrage,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if not (context.rage < (context.settings.enrage_rage_threshold or Constants.BEAR.ENRAGE_RAGE_THRESHOLD)) then return false end
         -- Boss safety: 27% armor reduction is too risky on boss encounters
         -- Exception: allow if Frenzied Regen is active (Enrage feeds rage to FR for healing)
         -- Boss hits generate enough rage naturally; not worth the armor loss
         if Unit(TARGET_UNIT):IsBoss() then
            if not context.has_frenzied_regen then return false end
         end
         -- HP safety: armor reduction is dangerous when low HP (any target)
         if context.hp < Constants.BEAR.ENRAGE_HP_SAFETY then
            if not context.has_frenzied_regen then return false end
         end
         -- Fight ending: don't reduce armor when last mob is dying
         if context.enemy_count <= 1 and context.ttd > 0 and context.ttd < 8 then
            return false
         end
         return true
      end,
      execute = function(icon, context)
         local note = context.has_frenzied_regen and " [FR active]" or ""
         return try_cast_fmt(A.Enrage, icon, PLAYER_UNIT, "[P3]", "Enrage", "Rage: %d, HP: %.0f%%%s", context.rage, context.hp, note)
      end,
   }

   -- [7] Lacerate Urgent Refresh (at 5 stacks, low duration) - skip if phys immune
   local Bear_LacerateUrgent = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Lacerate,
      matches = function(context, state)
         if not should_maintain_lacerate(context) then return false end
         return state.lacerate_stacks >= Constants.BEAR.LACERATE_MAX_STACKS and
               state.lacerate_duration > 0 and
               state.lacerate_duration <= Constants.BEAR.LACERATE_URGENT_REFRESH
      end,
      execute = function(icon, context, state)
         local cc_str = context.has_clearcasting and " [CC]" or ""
         return try_cast_fmt(A.Lacerate, icon, TARGET_UNIT, "[P5]", "Lacerate URGENT", "5 stacks, Duration: %.1fs%s", state.lacerate_duration, cc_str)
      end,
   }

   -- [8] Faerie Fire debuff maintenance
   -- Wrap factory result with bear-specific throttle to prevent tab-target GCD spam
   local Bear_FaerieFire = create_faerie_fire_strategy()
   local _ff_base_matches = Bear_FaerieFire.matches
   local _ff_base_execute = Bear_FaerieFire.execute
   Bear_FaerieFire.matches = function(context)
      if (GetTime() - bear_state.last_ff_cast) < FF_THROTTLE then return false end
      return _ff_base_matches(context)
   end
   Bear_FaerieFire.execute = function(icon, context)
      bear_state.last_ff_cast = GetTime()
      return _ff_base_execute(icon, context)
   end

   -- [5] Growl (single-target taunt when losing aggro - PvE only)
   -- Threat-level-aware:
   --   Threat 0 (not on table): selective — elite/boss only (natural rotation handles trash)
   --   Threat 1 (have threat, not tanking): elite/boss only, TTD gated
   --   Threat 2-3 (tanking): skip
   local Bear_Growl = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      requires_in_range = true,
      setting_key = "use_growl",
      spell = A.Growl,
      matches = function(context)
         if context.settings.bear_no_taunt then return false end
         if _G.UnitIsPlayer(TARGET_UNIT) then return false end
         if context.combat_time < 1.5 then return false end
         if is_target_cc_locked(Constants.BEAR.GROWL_CC_THRESHOLD) then return false end
         local threat = get_target_threat()
         if threat >= 2 then return false end -- already tanking (insecure or secure)
         -- Don't taunt mobs another tank is handling
         if is_other_tank_target() then return false end
         local targeting_healer = is_targettarget_healer()
         if threat == 1 then
            -- Have some threat but not tanking: elite/boss only (save 10s CD)
            local classification = _G.UnitClassification(TARGET_UNIT)
            if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
            -- TTD check: skip dying targets to save CD (exception: targeting healer)
            if not targeting_healer and context.ttd < Constants.BEAR.GROWL_MIN_TTD then return false end
         end
         -- Threat 0: no threat built yet — be selective with taunt CD
         -- Natural rotation (Mangle/Maul) builds threat quickly after tab-target;
         -- only taunt if healer is targeted OR elite/boss with enough TTD
         if threat == 0 and not targeting_healer then
            local classification = _G.UnitClassification(TARGET_UNIT)
            if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then
               return false
            end
            if context.ttd > 0 and context.ttd < 8 then
               return false
            end
         end
         return true
      end,
      execute = function(icon, context)
         local threat = get_target_threat()
         local targeting_healer = is_targettarget_healer()
         local urgency = threat == 0 and "NO THREAT" or "losing aggro"
         local reason = targeting_healer and "HEALER TARGETED" or urgency
         local tt = _G.UnitExists("targettarget") and (_G.UnitName("targettarget") or "?") or "none"
         NS.debug_print(format("[GROWL] threat=%d, targettarget=%s, healer=%s, TTD=%.0f", threat, tt, tostring(targeting_healer), context.ttd))
         return try_cast_fmt(A.Growl, icon, TARGET_UNIT, "[P3]", "Growl", "%s (threat=%d, tt=%s, TTD: %.0fs)", reason, threat, tt, context.ttd)
      end,
   }

   -- [6] Challenging Roar (AoE taunt when losing aggro to multiple enemies OR boss)
   local Bear_ChallengingRoar = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      setting_key = "use_challenging_roar",
      spell = A.ChallengingRoar,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if context.settings.bear_no_taunt then return false end
         local croar_range = context.settings.croar_range or Constants.BEAR.DEFAULT_CROAR_RANGE
         local elites, bosses = count_nearby_enemies(croar_range, true)
         if elites == 0 and bosses == 0 then return false end
         local min_bosses = context.settings.croar_min_bosses or Constants.BEAR.DEFAULT_CROAR_MIN_BOSSES
         local min_elites = context.settings.croar_min_elites or Constants.BEAR.DEFAULT_CROAR_MIN_ELITES
         return bosses >= min_bosses or elites >= min_elites
      end,
      execute = function(icon, context)
         local croar_range = context.settings.croar_range or Constants.BEAR.DEFAULT_CROAR_RANGE
         local elites, bosses = count_nearby_enemies(croar_range, true)
         local reason = bosses >= 1 and format("EMERGENCY - %d boss(es) loose, %d elite(s)", bosses, elites) or format("EMERGENCY - %d loose elite(s)", elites)
         return try_cast_fmt(A.ChallengingRoar, icon, PLAYER_UNIT, "[P4]", "Challenging Roar", reason)
      end,
   }

   -- [5] Tab Target (multi-mob threat management)
   -- Switches targets to spread threat across multiple mobs
   -- Priority: CC'd targets -> loose mobs -> Lacerate spread
   local Bear_TabTarget = {
      is_gcd_gated = false,
      requires_combat = true,
      setting_key = "enable_tab_targeting",
      matches = function(context, state)
         return should_tab_target(context, state)
      end,
      execute = function(icon, context)
         local desired = bear_state.tab_target_desired
         if desired and _G.UnitExists(desired) then
            AddDebugLogLine(format("[%.3fs] [TAB TARGET] Cycling toward %s (%s) [attempt %d]",
               GetTime(), _G.UnitName(desired) or "?", _G.UnitClassification(desired) or "?", bear_state.tab_target_attempts))
         else
            AddDebugLogLine(format("[%.3fs] [TAB TARGET] Auto-targeting", GetTime()))
         end
         return A:Show(icon, CONST.AUTOTARGET)
      end,
   }

   -- Bash (interrupt - 1 min CD stun)
   -- Only fires to interrupt castable spells. Does not stun for CC purposes.
   local Bear_BashInterrupt = {
      requires_combat = true,
      requires_enemy = true,
      requires_in_range = true,
      setting_key = "use_bash_interrupt",
      spell = A.Bash,
      matches = function(context)
         local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
         if not castLeft or castLeft <= 0 then return false end
         if notKickAble then return false end
         -- Need enough cast time remaining to land the GCD
         if castLeft < 0.5 then return false end
         if not context.has_clearcasting then
            local bash_cost = get_spell_rage_cost(A.Bash)
            if bash_cost > 0 and context.rage < bash_cost then return false end
         end
         return true
      end,
      execute = function(icon, context)
         local castLeft = Unit(TARGET_UNIT):IsCastingRemains()
         return try_cast_fmt(A.Bash, icon, TARGET_UNIT, "[P5]", "Bash", "Interrupt - Cast: %.1fs, Rage: %d", castLeft or 0, context.rage)
      end,
   }

   -- Demoralizing Roar (attack power reduction)
   -- Shared logic for both AoE-priority and ST-filler variants
   -- Configurable thresholds: min bosses/elites/trash within 10yd (defaults: 1/1/3)
   -- Smart: skips immune, dying (single target), warrior-shout-covered
   local function demo_roar_matches(context)
      -- Throttle: Demo Roar is PBAoE - one cast hits all nearby mobs.
      if (GetTime() - bear_state.last_demo_roar_cast) < DEMO_ROAR_THROTTLE then return false end
      if not Unit(TARGET_UNIT):IsBoss() then
         if would_starve_maul(context, RAGE_COST_DEMO_ROAR) then return false end
         if would_starve_mangle(context, RAGE_COST_DEMO_ROAR) then return false end
      end
      local demo_range = context.settings.demo_roar_range or Constants.BEAR.DEFAULT_DEMO_ROAR_RANGE
      local elites, bosses, trash = count_nearby_enemies(demo_range, false)
      local min_bosses = context.settings.demo_roar_min_bosses or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_BOSSES
      local min_elites = context.settings.demo_roar_min_elites or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_ELITES
      local min_trash = context.settings.demo_roar_min_trash or Constants.BEAR.DEFAULT_DEMO_ROAR_MIN_TRASH
      if bosses < min_bosses and elites < min_elites and trash < min_trash then return false end
      if context.enemy_count <= 1 and context.ttd < Constants.BEAR.DEMO_ROAR_MIN_TTD then
         return false
      end
      local demo_duration = Unit(TARGET_UNIT):HasDeBuffs(DEMO_ROAR_DEBUFF_IDS) or 0
      if demo_duration > Constants.BEAR.DEMO_ROAR_REFRESH then return false end
      local shout_duration = Unit(TARGET_UNIT):HasDeBuffs("Demoralizing Shout") or 0
      if shout_duration > Constants.BEAR.DEMO_ROAR_REFRESH then return false end
      return true
   end

   local function demo_roar_execute(icon, context)
      bear_state.last_demo_roar_cast = GetTime()
      local demo_range = context.settings.demo_roar_range or Constants.BEAR.DEFAULT_DEMO_ROAR_RANGE
      local elites, bosses, trash = count_nearby_enemies(demo_range, false)
      local cc_str = context.has_clearcasting and " [CC]" or ""
      local reason = bosses >= 1 and format("%d boss(es) + %d elite(s)", bosses, elites) or format("%d elite(s), %d trash", elites, trash)
      return try_cast_fmt(A.DemoralizingRoar, icon, PLAYER_UNIT, "[P7]", "Demoralizing Roar",
         "%s%s", reason, cc_str)
   end

   -- DemoRoar AoE: high priority on 3+ packs (above filler abilities)
   local Bear_DemoRoarAoE = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      setting_key = "maintain_demo_roar",
      spell = A.DemoralizingRoar,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if context.enemy_count < 3 then return false end
         return demo_roar_matches(context)
      end,
      execute = demo_roar_execute,
   }

   -- DemoRoar ST: lowest GCD priority (below filler abilities)
   local Bear_DemoRoar = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      setting_key = "maintain_demo_roar",
      spell = A.DemoralizingRoar,
      spell_target = PLAYER_UNIT,
      matches = function(context)
         if context.enemy_count >= 3 then return false end  -- handled by AoE variant
         return demo_roar_matches(context)
      end,
      execute = demo_roar_execute,
   }

   -- [8] Swipe AoE (fills every GCD between Mangle CDs in AoE)
   -- Mangle fires first via array priority [8]; SwipeAoE [9] fills remaining GCDs.
   -- No yield/hold checks needed — Mangle wins by position when off CD.
   local Bear_SwipeAoE = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Swipe,
      matches = function(context, state)
         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count < aoe_threshold then return false end
         -- Yield to Mangle after we've already opened with Swipe on this pack
         -- First Swipe fires (opener), then Mangle weaves in on CD, Swipe fills the rest
         -- After 8s without AoE Swipe (new pack), opens with Swipe again
         if is_spell_available(A.MangleBear) and A.MangleBear:GetCooldown() == 0
            and not context.target_phys_immune
            and (GetTime() - bear_state.last_swipe_aoe_cast) < 8 then return false end
         -- CC safety (cached in get_bear_state)
         if context.cc_nearby then return false end
         if not context.has_clearcasting then
            local swipe_threshold = context.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
            if context.rage < swipe_threshold then return false end
            if would_starve_maul(context, RAGE_COST_SWIPE) then return false end
         end
         return true
      end,
      execute = function(icon, context)
         bear_state.last_swipe_aoe_cast = GetTime()
         return try_cast_fmt(A.Swipe, icon, TARGET_UNIT, "[P9]", "Swipe (AoE)", "Rage: %d, Targets: %d%s", context.rage, context.enemy_count, context.has_clearcasting and " [CC]" or "")
      end,
   }

   -- [9] Mangle (main single-target damage ability) - skip if target has physical immunity
   local Bear_Mangle = create_combat_strategy({
      spell = A.MangleBear,
      log_name = "Mangle",
      prefix = "[P9]",
      log_fmt = "Rage: %d%s",
      log_args = function(ctx) return ctx.rage, ctx.has_clearcasting and " [CC]" or "" end,
      extra_match = function(ctx)
         -- Skip if target has physical immunity
         if ctx.target_phys_immune then return false end
         -- Clearcasting: Mangle is free, bypass rage check
         if ctx.has_clearcasting then return true end
         -- Mangle is highest DPET ability — use on CD with minimal rage gating
         local mangle_threshold = ctx.settings.mangle_rage_threshold or RAGE_COST_MANGLE
         if ctx.rage < mangle_threshold then return false end
         return true
      end
   })

   -- [12] Swipe single-target filler (conditional: toggle + Lacerate gate)
   -- Only fires when swipe_st_filler is enabled. At level 66+, also requires
   -- 5 Lacerate stacks with >3s remaining (sim's SwipeWithEnoughAP mode).
   -- Default OFF: auto-attack + Maul between Mangles is higher DPS at low AP.
   local Bear_Swipe = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Swipe,
      matches = function(context, state)
         -- AoE is handled by SwipeAoE above Mangle; this is single-target filler only
         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count >= aoe_threshold then return false end

         -- ST filler toggle: user controls whether Swipe fills single-target GCDs
         if not context.settings.swipe_st_filler then return false end

         -- Lacerate gate: if Lacerate is available, only Swipe when fully stacked with safe duration
         if is_spell_available(A.Lacerate) then
            if state.lacerate_stacks < Constants.BEAR.LACERATE_MAX_STACKS then return false end
            if state.lacerate_duration <= Constants.BEAR.LACERATE_URGENT_REFRESH then return false end
         end

         -- Hold for Mangle: don't waste a 1.5s GCD when Mangle is almost ready
         if should_hold_for_mangle() then return false end

         -- CC safety (cached in get_bear_state)
         if context.cc_nearby then return false end

         if not context.has_clearcasting then
            local swipe_threshold = context.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
            if context.rage < swipe_threshold then return false end
            if would_starve_maul(context, RAGE_COST_SWIPE) then return false end
         end

         return true
      end,
      execute = function(icon, context)
         return try_cast_fmt(A.Swipe, icon, TARGET_UNIT, "[P10]", "Swipe", "Rage: %d%s", context.rage, context.has_clearcasting and " [CC]" or "")
      end,
   }

   -- [11] Lacerate Build (primary GCD filler - building and maintaining stacks)
   -- Sim priority: Lacerate is the default filler, Swipe only when conditions met.
   local Bear_LacerateBuild = {
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      spell = A.Lacerate,
      matches = function(context, state)
         if not should_maintain_lacerate(context) then return false end
         if not context.has_clearcasting then
            if context.rage < RAGE_COST_LACERATE then return false end
            if would_starve_maul(context, RAGE_COST_LACERATE) then return false end
            if would_starve_mangle(context, RAGE_COST_LACERATE) then return false end
         end

         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count >= aoe_threshold then return false end

         local stacks, duration = state.lacerate_stacks, state.lacerate_duration

         -- Building stacks: apply immediately at 0, then reapply when duration dips below threshold
         -- Swipe fills GCDs in between; stacks build gradually over the fight
         if stacks < Constants.BEAR.LACERATE_MAX_STACKS then
            return stacks == 0 or duration <= LACERATE_BUILD_REFRESH
         end

         -- At 5 stacks, refreshing as filler — hold for Mangle if it's almost ready
         if should_hold_for_mangle() then return false end

         -- Refresh if above urgent threshold but below swipe threshold
         return duration > Constants.BEAR.LACERATE_URGENT_REFRESH and
            duration <= Constants.BEAR.LACERATE_SWIPE_THRESHOLD
      end,
      execute = function(icon, context, state)
         local cc_str = context.has_clearcasting and " [CC]" or ""
         return try_cast_fmt(A.Lacerate, icon, TARGET_UNIT, "[P11]", "Lacerate", "Stacks: %d/5, Duration: %.1fs%s", state.lacerate_stacks, state.lacerate_duration, cc_str)
      end,
   }

   -- [4] Maul (off-GCD, queues on next melee swing)
   -- Only queue above rage threshold - preserve rage when low (losing aggro = less rage income)
   -- Smart: trash-only packs → raise threshold to save rage for Swipe spam
   local Bear_Maul = {
      is_gcd_gated = false,
      requires_combat = true,
      requires_enemy = true,
      requires_phys_immune = false,
      requires_in_range = true,
      spell = A.Maul,
      matches = function(context, state)
         -- Confirmed queued by game -> wait for CLEU to consume it
         if bear_state.maul_confirmed then return false end
         -- Still queuing (not yet confirmed) -> allow re-entry to keep firing TMW:Fire
         if bear_state.maul_queued then return true end
         -- Idle: normal rage threshold
         local maul_threshold = context.settings.maul_rage_threshold or Constants.BEAR.DEFAULT_MAUL_RAGE
         if context.rage < maul_threshold then return false end
         -- Mangle starvation: Maul consumes rage on next swing (delayed up to 2.5s).
         -- If we can't afford both and Mangle will be ready before our swing lands,
         -- don't queue — Mangle comes off CD with no rage to spend.
         if not context.has_clearcasting
            and context.rage < (RAGE_COST_MAUL + RAGE_COST_MANGLE)
            and is_spell_available(A.MangleBear)
         then
            local mangle_cd = A.MangleBear:GetCooldown()
            local swing_remaining = get_time_until_swing()
            -- Mangle ready before swing lands = Maul would starve it
            if mangle_cd > 0 and swing_remaining > 0 and mangle_cd < swing_remaining then
               return false
            end
            -- Mangle ready NOW and we can't afford both = don't queue
            if mangle_cd <= 0 then return false end
         end
         return true
      end,
      execute = function(icon, context, state)
         bear_state.maul_queued = true
         bear_state.maul_dequeue_logged = false
         return try_cast_fmt(A.Maul, icon, TARGET_UNIT, "[P12]", "Maul", "Rage: %d, Melee: %dB/%dE/%dT", context.rage, state.nearby_bosses, state.nearby_elites, state.nearby_trash)
      end,
   }

   -- Register all Bear strategies (array order = execution priority)
   -- Off-GCD emergencies/taunts first, then GCD rotation, then Maul last.
   -- Maul is off-GCD (swing queue) — placed last so GCD abilities fire first.
   -- During GCD frames, only off-GCD strategies evaluate, so Maul fires then.
   --
   -- KEY: Mangle is highest-priority GCD ability (best DPET, opener).
   -- SwipeAoE sits above ST filler but below Mangle (AoE total > Mangle only at threshold).
   -- DemoRoar is defensive — deferred below core damage abilities.
   rotation_registry:register("bear", {
      named("FrenziedRegen",    Bear_FrenziedRegen),     -- [1]  off-GCD emergency heal
      named("Enrage",           Bear_Enrage),            -- [2]  off-GCD rage gen
      named("Growl",            Bear_Growl),             -- [3]  off-GCD taunt
      named("ChallengingRoar",  Bear_ChallengingRoar),   -- [4]  off-GCD AoE taunt
      named("BashInterrupt",    Bear_BashInterrupt),     -- [5]  GCD - interrupt (1 min CD)
      named("LacerateUrgent",   Bear_LacerateUrgent),    -- [6]  GCD - urgent refresh
      named("TabTarget",        Bear_TabTarget),         -- [7]  off-GCD tab targeting
      named("FaerieFire",       Bear_FaerieFire),        -- [8]  GCD - debuff maintenance
      named("Maul",             Bear_Maul),              -- [9]  off-GCD swing queue (fires during GCD)
      named("SwipeAoE",         Bear_SwipeAoE),          -- [10] GCD - AoE (fires before Mangle on packs)
      named("Mangle",           Bear_Mangle),            -- [11] GCD - main ST damage/threat
      named("DemoRoarAoE",      Bear_DemoRoarAoE),       -- [12] GCD - AP reduction (3+ enemies, high prio)
      named("LacerateBuild",    Bear_LacerateBuild),     -- [13] GCD - stack builder/filler
      named("Swipe",            Bear_Swipe),             -- [14] GCD - ST filler (conditional)
      named("DemoRoar",         Bear_DemoRoar),          -- [15] GCD - AP reduction (ST, lowest priority)
   }, {
      context_builder = get_bear_state,
      format_context_log = function(ctx, state)
         local s = ctx.settings
         local mangle_cd = A.MangleBear:GetCooldown()
         local target_class = _G.UnitClassification(TARGET_UNIT) or "?"

         -- Combat state
         local combat = format("rage=%d hp=%.0f enemies=%d(%dB/%dE/%dT)",
            ctx.rage, ctx.hp, ctx.enemy_count, state.nearby_bosses, state.nearby_elites, state.nearby_trash)

         -- Target & ability state
         local abilities = format("target=%s isBoss=%s cc=%s fr=%s mangle_cd=%.1f lac=%d/5(%.1f) maul_q=%s gcd=%.1f",
            target_class, tostring(ctx.is_boss), tostring(ctx.cc_nearby), tostring(ctx.has_frenzied_regen),
            mangle_cd, state.lacerate_stacks, state.lacerate_duration,
            tostring(state.maul_queued), ctx.gcd_remaining)

         -- Settings
         local settings = format("lac_boss=%s m_lac=%s cc_chk=%s demo=%s aoe=%s",
            tostring(s.lacerate_boss_only), tostring(s.maintain_lacerate), tostring(s.swipe_cc_check),
            tostring(s.maintain_demo_roar), tostring(s.aoe_threshold))

         -- Rage costs (maul/mangle/swipe/lac/demo)
         local costs = format("costs=%d/%d/%d/%d/%d",
            RAGE_COST_MAUL, RAGE_COST_MANGLE, RAGE_COST_SWIPE, RAGE_COST_LACERATE, RAGE_COST_DEMO_ROAR)

         return combat .. " " .. abilities .. " | " .. settings .. " | " .. costs
      end,
   })

end  -- End Bear strategies do...end block

print("|cFF00FF00[Flux AIO Bear]|r 15 Bear strategies registered.")
