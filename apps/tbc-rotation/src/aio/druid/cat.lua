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
-- Energy ticks every 2s in TBC (20 energy per tick), driven by a server-side
-- timer that is INDEPENDENT of player actions (does not reset on shift).
--
-- Detection is event-driven via UNIT_POWER_FREQUENT (Replus-style), with a
-- tick-alignment rule: a power gain only registers as a tick if it lands at
-- least (TICK_INTERVAL - 0.25)s after the previously detected tick. This
-- single rule naturally filters Furor (fires within ~0s of shift, well inside
-- the alignment window), Tiger's Fury, and any other off-tick energy events.
-- The 0.3s post-shift skip below is belt-and-suspenders for the cold-start
-- case where last_tick_time is stale (first cat-form entry of the fight).
-- ============================================================================
local ENERGY_TICK_INTERVAL = 2.0
local TICK_ALIGNMENT_WINDOW = 0.25      -- Replus rule: gain > (interval - this) since last tick
local POST_SHIFT_SKIP_WINDOW = 0.3      -- Drop the first energy event right after a shift (Furor surge)
local SHIFT_DELAY_TICK_THRESHOLD = 1.0  -- Wait up to 1.0s for tick before shifting (sim: MaxWaitTime = 1.0s)

-- Tick proximity thresholds for trick abilities (sim-matched)
-- Bite trick: fire unless tick is nearly instant (sim: > latency, ~0.1s)
-- Rake trick: only fire when tick is far away (sim: > 1s + latency)
local BITE_TRICK_TICK_THRESHOLD = 0.1
local RAKE_TRICK_TICK_THRESHOLD = 1.0

local energy_tick = {
   last_energy = 0,
   last_tick_time = 0,
   last_shift_time = 0,
   confident = false,  -- True once we've detected at least one tick
   debug = false,             -- off by default; toggle on with /fticks (prints "TICK NOW!" on each detection)
}

-- Expose to NS so the dashboard can prefer this frame-level tracker over its own 10Hz one
NS.energy_tick_tracker = energy_tick

-- Event-driven tick detection: fires the instant the game updates player energy,
-- with no frame-rate jitter and no risk of missing ticks between rotation frames.
local tick_listener = CreateFrame("Frame")
tick_listener:RegisterEvent("UNIT_POWER_FREQUENT")
tick_listener:SetScript("OnEvent", function(self, event, unit, ptype)
   if unit ~= "player" then return end
   if ptype ~= "ENERGY" then return end

   -- Out of Cat Form: druids don't generate energy ticks in caster/bear/etc.,
   -- so don't track anything. We deliberately do NOT clear last_tick_time —
   -- server ticks continue across forms, so the prior anchor is still useful
   -- when we shift back in.
   if Player:GetStance() ~= Constants.STANCE.CAT then
      energy_tick.last_energy = 0
      energy_tick.confident = false
      return
   end

   local now = GetTime()
   local cur = UnitPower("player", 3) or 0   -- 3 = SPELL_POWER_ENERGY

   -- Skip the Furor surge that fires immediately after a shift. After
   -- POST_SHIFT_SKIP_WINDOW the alignment rule below takes over.
   if now - energy_tick.last_shift_time < POST_SHIFT_SKIP_WINDOW then
      energy_tick.last_energy = cur
      return
   end

   -- Capped: can't infer a tick because the gain would be clamped. Sync the
   -- energy reading but don't update tick time.
   local maxp = UnitPowerMax("player", 3) or 100
   if cur >= maxp then
      energy_tick.last_energy = cur
      return
   end

   local has_gained = cur > energy_tick.last_energy
   local is_aligned = (now - energy_tick.last_tick_time) > (ENERGY_TICK_INTERVAL - TICK_ALIGNMENT_WINDOW)
   if has_gained and is_aligned then
      energy_tick.last_tick_time = now
      energy_tick.confident = true
      if energy_tick.debug then
         print("|cFF55FF55[TICK]|r TICK NOW!")
      end
   end
   energy_tick.last_energy = cur
end)

-- Cat-form-entry detector: ensures the 0.3s POST_SHIFT_SKIP_WINDOW fires for
-- ALL shifts (manual keybind, addon-driven, /cancelform+CatForm macro), not
-- just our rotation's safe_cat_form_shift. Without this, the Furor energy
-- surge that follows a manual shift is misread as a server tick.
local form_listener = CreateFrame("Frame")
form_listener:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
form_listener:SetScript("OnEvent", function()
   if Player:GetStance() == Constants.STANCE.CAT then
      energy_tick.last_shift_time = GetTime()
   end
end)

-- At-cap tick predictor: while energy is at max, the event handler can't see
-- ticks (the +20 gets clamped to 0). To keep the [TICK] log running for
-- verification — and to avoid stale predictions while parked at cap — we
-- extrapolate from the last detected tick at the expected 2.0s cadence.
-- Re-anchors itself as time passes so smart-shift-delay stays accurate when
-- energy drops back below cap.
local tick_predictor_frame = CreateFrame("Frame")
tick_predictor_frame:SetScript("OnUpdate", function()
   if not energy_tick.confident then return end
   if Player:GetStance() ~= Constants.STANCE.CAT then return end
   local cur = UnitPower("player", 3) or 0
   local maxp = UnitPowerMax("player", 3) or 100
   if cur < maxp then return end

   local now = GetTime()
   local predicted_next = energy_tick.last_tick_time + ENERGY_TICK_INTERVAL
   if now >= predicted_next then
      energy_tick.last_tick_time = predicted_next
      if energy_tick.debug then
         print("|cFF55FF55[TICK]|r TICK NOW! (predicted @ cap)")
      end
   end
end)

--- Get time until next energy tick (seconds)
--- @return number Estimated seconds until next tick (1.0 if unknown)
function energy_tick:time_until_next_tick()
   if not self.confident or self.last_tick_time == 0 then return 1.0 end
   local elapsed = GetTime() - self.last_tick_time
   local remaining = ENERGY_TICK_INTERVAL - (elapsed % ENERGY_TICK_INTERVAL)
   return remaining
end

--- Check if powershifting should be delayed for an imminent energy tick
--- @param current_energy number Current energy level
--- @param min_useful_energy number Minimum energy needed to cast something useful
--- @return boolean True if a tick is arriving soon and would reach a useful threshold
function energy_tick:should_delay_shift(current_energy, min_useful_energy)
   if not self.confident then return false end
   if current_energy + 20 < min_useful_energy then return false end
   return self:time_until_next_tick() <= SHIFT_DELAY_TICK_THRESHOLD
end

--- Check if bite trick should be skipped for an imminent energy tick
--- @return boolean True if a tick is arriving too soon for bite trick
function energy_tick:should_skip_bite_trick()
   if not self.confident then return false end
   return self:time_until_next_tick() < BITE_TRICK_TICK_THRESHOLD
end

--- Check if rake trick should be skipped because an energy tick is coming
--- @return boolean True if a tick is arriving too soon for rake trick
function energy_tick:should_skip_rake_trick()
   if not self.confident then return false end
   return self:time_until_next_tick() < RAKE_TRICK_TICK_THRESHOLD
end

-- ============================================================================
-- CAT FORM UTILITIES
-- ============================================================================

--- Safe Cat Form shift with ready check
--- CatForm has /cancelform macro built-in for powershift support
--- Note: GCD is already checked at main entry point (A[3])
--- @param icon table The icon to show
--- @return any|nil The cast result or nil
local function safe_cat_form_shift(icon, context)
   -- Record shift time so energy tick tracker can ignore Furor energy in the
   -- 0.6s post-shift window. Do NOT touch last_tick_time or confident:
   -- TBC energy ticks are server-side and continue across form shifts, so the
   -- prior detection is still the best estimate. The regular tick detector
   -- self-corrects on the first real post-shift tick (outside the Furor window).
   energy_tick.last_shift_time = GetTime()

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
   should_delay_shift = false,
   cat_form_cost = 0,
   shifts_remaining = 0,
   -- DPS state
   mangle_duration = 0,
   rip_duration = 0,
   rake_duration = 0,
   rip_now = false,
   rip_next = false,   -- Rip is queued for the imminent tick (sim: ripNext)
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

   -- Energy tick tracking is now event-driven via UNIT_POWER_FREQUENT
   -- (see tick_listener above); no frame-level update needed here.

   local has_cc = context.has_clearcasting

   -- Debuff durations (3 API calls, done once per frame).
   -- Rip and Rake are per-caster DoTs: with multiple ferals in the raid, the
   -- default "any caster" filter would return another feral's longer-remaining
   -- Rip/Rake and prevent us from refreshing our own. Pass "player" so the
   -- framework filters to PLAYER-applied auras only (HARMFUL PLAYER filter).
   -- Mangle (Cat/Bear) shares a single non-stacking bleed-amp slot across all
   -- druids, so reading any caster's Mangle is correct.
   cat_state.mangle_duration = Unit(TARGET_UNIT):HasDeBuffs(MANGLE_CAT_DEBUFF_IDS) or 0
   cat_state.rip_duration = Unit(TARGET_UNIT):HasDeBuffs(RIP_DEBUFF_IDS, "player", true) or 0
   cat_state.rake_duration = Unit(TARGET_UNIT):HasDeBuffs(RAKE_DEBUFF_IDS, "player", true) or 0

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

   -- rip_min_ttd: user-configured floor below which Bite > Rip in expected damage.
   -- Default 14s (≈ Bite vs Rip damage breakeven). Slider min=0 means "always Rip".
   -- Lua's `or` is safe here because 0 is truthy — only nil falls through to the constant.
   local rip_min_ttd = settings.rip_min_ttd or Constants.TTD.RIP_MIN

   -- rip_now: should we cast Rip this frame?
   local rip_now = settings.maintain_rip and cat_state.target_qualifies_for_rip
                   and cp >= settings.rip_min_cp and ttd >= rip_min_ttd
                   and not context.target_phys_immune
                   and (cat_state.rip_duration == 0 or cat_state.rip_duration < cat_state.rip_refresh_threshold)

   -- Mangle debuff awareness: defer Rip one GCD if Mangle debuff is missing
   -- 30% bleed damage bonus on the FULL Rip duration is worth one GCD delay
   if rip_now and cat_state.mangle_duration == 0 and A.MangleCat:IsReady(TARGET_UNIT)
      and (energy >= ENERGY_COST_MANGLE or has_cc) then
      rip_now = false
   end
   cat_state.rip_now = rip_now

   -- mangle_now: should we refresh Mangle debuff?
   -- Computed BEFORE smart-shift-delay so the delay logic can use it to pick
   -- the right min_useful_energy threshold (sim-aligned).
   cat_state.mangle_now = not rip_now and cat_state.mangle_duration == 0 and not context.target_phys_immune

   -- rip_next: approximation of sim's `ripNext`. True when the current Rip will
   -- expire within the next tick window AND we have CP to refresh it. Used by
   -- MangleShift to suppress a force-shift at very low energy (sim's !ripNext
   -- gate): waiting one tick instead lands us at Rip-castable energy directly.
   -- (Strict sim: rip_duration <= time_until_next_tick. We use 2.0s as a fixed
   -- upper bound on tick interval — simpler and only ~0.5s off on average.)
   cat_state.rip_next = settings.maintain_rip
      and cat_state.target_qualifies_for_rip
      and not context.target_phys_immune
      and ttd >= rip_min_ttd
      and cp >= settings.rip_min_cp
      and cat_state.rip_duration > 0
      and cat_state.rip_duration <= 2.0

   -- Smart shift delay: compute minimum useful energy threshold for tick-waiting.
   -- Sim-aligned (wowsims rotation.go mangleNow branch): when Mangle debuff is
   -- missing, MangleCost (40) is the relevant threshold — a tick that lands us
   -- at >=40 lets us cast Mangle, no shift needed. Without this, the default
   -- ShredCost (42) caused us to shift at energy 20-21 even though one tick
   -- would have unlocked a Mangle.
   local min_useful_energy = ENERGY_COST_SHRED
   local min_cp = settings.fb_min_cp or 5
   if rip_now then
      min_useful_energy = ENERGY_COST_RIP
   elseif cat_state.mangle_now then
      min_useful_energy = ENERGY_COST_MANGLE
   elseif context.cp >= min_cp then
      -- Regular Ferocious Bite finisher is a real next-action when we have CP;
      -- not gated on use_bite_trick (the trick is a separate strategy). Without
      -- this, energy 15-19 + 5 CP would default min_useful_energy to Shred (42)
      -- and miss the fact that a tick lands us at 35-39 (Bite-eligible).
      min_useful_energy = ENERGY_COST_BITE
   elseif settings.use_rake_trick then
      min_useful_energy = ENERGY_COST_RAKE
   end
   cat_state.should_delay_shift = energy_tick:should_delay_shift(energy, min_useful_energy)

   -- Guard: don't spend CPs on Bite if Rip needs renewal soon
   -- Conservative estimate: 1 CP per GCD (~1.5s), no crits assumed
   cat_state.rip_needs_refresh_soon = not rip_now and settings.maintain_rip
      and cat_state.target_qualifies_for_rip
      and not context.target_phys_immune and ttd >= rip_min_ttd
      and cat_state.rip_duration > 0 and cat_state.rip_duration < settings.rip_min_cp * 1.5

   -- Mangle Trick (sim-matched, wowsims TBC sim/druid/feral/rotation.go):
   --   energy in [2*MangleCost-20, 22+MangleCost) AND tick <=1s AND UseMangleTrick
   --   AND (NOT UseRakeTrick OR MangleCost == 35).
   -- Last clause: when Rake Trick is on and Mangle isn't fully discounted by 2pT6
   -- (so Mangle > 35 energy), the cheap-filler slot belongs to Rake — skip the
   -- Mangle Trick to avoid stepping on it.
   -- Also gated on A.MangleCat:IsReady so when Mangle is on its 6s CD we don't
   -- block Shred for nothing (the sim's structure achieves the same fall-through
   -- implicitly; we need the explicit check because the preference flag and the
   -- execute call are separated here).
   cat_state.prefer_mangle_for_tick = settings.use_mangle_trick
      and A.MangleCat:IsReady(TARGET_UNIT)
      and energy >= TICK_OPT_MANGLE_LOW and energy <= TICK_OPT_MANGLE_HIGH
      and energy_tick.confident and energy_tick:time_until_next_tick() < TICK_OPT_THRESHOLD
      and (not settings.use_rake_trick or ENERGY_COST_MANGLE == 35)

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

      if context.settings.cat_energy_pooling then
         state.pooling = true
      end
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
      if context.settings.cat_smart_shift_delay and state.should_delay_shift then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[P2] Shift for Rip - Energy: %d -> ~%d (%d shifts left)", context.energy, state.energy_after_shift, state.shifts_remaining)
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
      if settings.use_bite_execute then
         local bite_execute_ttd = settings.bite_execute_ttd or Constants.TTD.BITE_EXECUTE
         local bite_execute_hp = settings.bite_execute_hp or Constants.HP.EXECUTE
         if ttd < bite_execute_ttd and energy >= ENERGY_COST_BITE then
            bite_now = true
            bite_reason = "Target dying soon"
         elseif (target_hp <= bite_execute_hp or ttd < Constants.TTD.SHORT_FIGHT) and state.rip_duration > Constants.DURATION.BITE_MIN_RIP and energy >= ENERGY_COST_BITE then
            bite_now = true
            bite_reason = "Execute/Short fight"
         end
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
      if not state.mangle_now then return false end
      if not state.can_powershift then return false end
      if context.has_clearcasting then return false end
      if context.energy >= ENERGY_COST_MANGLE then return false end
      -- Sim's !ripNext gate: at very low energy, suppress force-shift if Rip is
      -- queued for the next tick. Waiting one tick gets us to Rip-castable
      -- energy (~30+) without spending a shift.
      if context.energy < ENERGY_COST_MANGLE - 20 and state.rip_next then return false end
      return true
   end,

   execute = function(icon, context, state)
      if context.settings.cat_smart_shift_delay and state.should_delay_shift then return nil end
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
            if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
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
            if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
            local result = safe_ability_cast(A.Rake, icon, TARGET_UNIT)
            if result then
               return result, format("[AoE] Rake - Primary target, Duration: %.1fs, TTD: %.1fs", rake_duration, ttd)
            end
         end

         -- Spread to nearby targets missing Rake
         if A.MultiUnits:GetByRangeMissedDoTs(Constants.AOE.RAKE_SPREAD_NEARBY, 10, A.Rake.ID) > 0 and A.Rake:IsReady(TARGET_UNIT) then
            if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
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
      if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
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
      return true
   end,
   execute = function(icon, context, state)
      if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
      local result = safe_ability_cast(A.Shred, icon, TARGET_UNIT)
      if result then
         return result, format("[P6] Shred - Builder, Energy: %d, CP: %d", context.energy, context.cp)
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
      -- Setting gates "not behind" and "can't afford Shred" fallbacks; tick-opt always allowed
      if not state.prefer_mangle_for_tick and not context.settings.use_mangle_builder then return false end
      return (not_behind or context.energy < ENERGY_COST_SHRED or state.prefer_mangle_for_tick)
         and (context.energy >= ENERGY_COST_MANGLE or context.has_clearcasting)
   end,
   execute = function(icon, context, state)
      if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
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
   spell = A.FerociousBite,
   setting_key = "use_bite_trick",
   matches = function(context, state)
      local min_cp = context.settings.fb_min_cp or 5
      if context.cp < min_cp then return false end
      if state.pooling then return false end
      if state.rip_needs_refresh_soon then return false end
      if energy_tick:should_skip_bite_trick() then return false end
      return context.energy <= Constants.ENERGY.BITE_TRICK_MAX
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
      if energy_tick:should_skip_rake_trick() then return false end
      return context.energy < ENERGY_COST_MANGLE
         and state.mangle_duration > 0 and state.rake_duration == 0
         and context.ttd >= Constants.TTD.RAKE_MIN
   end,
   execute = function(icon, context, state)
      if context.settings.cat_swing_delay and is_swing_landing_soon(0.15) then return nil end
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
      if context.settings.cat_smart_shift_delay and state.should_delay_shift then return nil end
      local result = safe_cat_form_shift(icon, context)
      if result then
         return result, format("[P0] Critical Energy Shift - Energy: %d -> %d, Mana: %.0f%% (%d shifts left)", context.energy, state.energy_after_shift, context.mana_pct, state.shifts_remaining)
      end
      return nil
   end,
}

-- Wolfshead Shred Shift - Aggressive WH-only shift when a Shred-cost builder
-- is reachable post-shift. Position-agnostic: MangleBuilder consumes the
-- post-shift energy if we end up in front.
local Cat_WolfsheadShred = {
   requires_combat = true,
   requires_enemy = true,
   requires_in_range = true,
   requires_stealth = false,
   spell = A.CatForm,
   spell_target = PLAYER_UNIT,
   matches = function(context, state)
      if context.has_clearcasting then return false end
      if state.pooling or state.rip_now or state.mangle_now then return false end
      -- Sim's !ripNext gate: don't burn a shift if a tick is about to drop us
      -- into Rip range. Mirrors EarlyShift behavior.
      if state.rip_next then return false end
      return state.has_wolfshead and state.can_powershift
         and (state.energy_after_shift - context.energy) >= Constants.POWERSHIFT.MIN_SHIFT_ENERGY_GAIN
         and state.energy_after_shift >= ENERGY_COST_SHRED
         and context.energy < ENERGY_COST_SHRED
   end,

   execute = function(icon, context, state)
      if context.settings.cat_smart_shift_delay and state.should_delay_shift then return nil end
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
      -- Sim's !ripNext gate (rotation.go low-energy fallback): don't burn a
      -- shift if a tick is about to drop us into Rip range. Wait one tick.
      if state.rip_next then return false end
      local shift_threshold = state.has_wolfshead and Constants.ENERGY.EARLY_SHIFT_WOLFSHEAD or Constants.ENERGY.EARLY_SHIFT
      return context.energy < shift_threshold
   end,

   execute = function(icon, context, state)
      if context.settings.cat_smart_shift_delay and state.should_delay_shift then return nil end
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
   named("FerociousBite",       Cat_FerociousBite),          -- P3: Standard finisher
   named("BiteTrick",           Cat_BiteTrick),              -- P3.5: Low-energy Bite trick
   named("RakeTrick",           Cat_RakeTrick),              -- P3.7: Low-energy Rake trick
   named("MangleDebuff",        Cat_MangleDebuff),           -- P4: Bleed debuff maintenance
   named("MangleShift",         Cat_MangleShift),            -- P4: Powershift for Mangle
   named("Rake",                Cat_Rake),                   -- P4.5: Rake DoT maintenance
   named("ClearcastingShred",   Cat_ClearcastingShred),      -- P5: Free Shred (OoC proc)
   named("Shred",               Cat_Shred),                  -- P6: Primary builder
   named("MangleBuilder",       Cat_MangleBuilder),          -- P7: Fallback builder
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

print("|cFF00FF00[Flux AIO Cat]|r 20 Cat strategies registered.")
print("|cFFFF55FF[Flux AIO Cat]|r LATEST VERSION!! tick_debug=" .. tostring(energy_tick.debug) .. " (build 2026-05-11)")
