-- Priest Shadow DPS Module
-- DoT management, Shadow Weaving, Mind Flay filler

local _G = _G
local A = _G.Action

if not A then
   return
end
if A.PlayerClass ~= "PRIEST" then
   return
end

local NS = _G.FluxAIO
if not NS then
   print("|cFFFF0000[Flux AIO Priest Shadow]|r Core module not loaded!")
   return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named

local Player = NS.Player
local MultiUnits = A.MultiUnits
local UnitExists = _G.UnitExists

local GetTime = _G.GetTime

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- CLEU-BASED DOT TRACKER
-- ============================================================================
-- Tracks SWP/VT on all targets by GUID via combat log events.
-- Reliable regardless of nameplate visibility or HasDeBuffs rank mismatch.
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local UnitGUID = _G.UnitGUID

local vt_spell_name = _G.GetSpellInfo(A.VampiricTouch.ID)
local swp_spell_name = _G.GetSpellInfo(A.ShadowWordPain.ID)

-- active_dots[guid] = { swp = expiryTime, vt = expiryTime }
local active_dots = {}
local SWP_DURATION = 18
local VT_DURATION = 15
local DOT_REFRESH_WINDOW = 3

-- Build a set of all SWP/VT spell IDs (all ranks) for fast lookup
local swp_ids = {}
local vt_ids = {}
for i = 1, 20 do
   local name = _G.GetSpellInfo(A.ShadowWordPain.ID, i)
   if not name then break end
   local id = select(7, _G.GetSpellInfo(name, nil, i))
   if id then swp_ids[id] = true end
end
for i = 1, 20 do
   local name = _G.GetSpellInfo(A.VampiricTouch.ID, i)
   if not name then break end
   local id = select(7, _G.GetSpellInfo(name, nil, i))
   if id then vt_ids[id] = true end
end
-- Fallback: ensure base IDs are included (GetSpellInfo rank iteration may not work in TBC)
swp_ids[A.ShadowWordPain.ID] = true
vt_ids[A.VampiricTouch.ID] = true

local debug_print = NS.debug_print
local player_guid = nil
local dot_tracker_frame = _G.CreateFrame("Frame")
dot_tracker_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
dot_tracker_frame:SetScript("OnEvent", function()
   if not player_guid then
      player_guid = UnitGUID("player")
      if not player_guid then return end
   end

   local _, subevent, _, srcGUID, _, _, _, dstGUID, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()

   -- Clean up dead mobs (srcGUID won't be player for deaths)
   if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
      if active_dots[dstGUID] then
         active_dots[dstGUID] = nil
      end
      return
   end

   if srcGUID ~= player_guid then return end

   -- Match by spell name (CLEU provides it directly, avoids rank ID issues)
   local is_swp = spellName == swp_spell_name
   local is_vt = spellName == vt_spell_name
   if not is_swp and not is_vt then return end

   -- SPELL_CAST_SUCCESS: dot was cast, assume it lands (proven reliable by dashboard.lua)
   -- Also handle SPELL_AURA_APPLIED/REFRESH as backup
   if subevent == "SPELL_CAST_SUCCESS"
      or subevent == "SPELL_AURA_APPLIED"
      or subevent == "SPELL_AURA_REFRESH" then
      if not active_dots[dstGUID] then
         active_dots[dstGUID] = { swp = 0, vt = 0 }
      end
      local now = GetTime()
      if is_swp then
         active_dots[dstGUID].swp = now + SWP_DURATION
      else
         active_dots[dstGUID].vt = now + VT_DURATION
      end
      if debug_print then
         debug_print(("[DOT_TRACK] %s %s on %s (%.0fs)"):format(
            subevent, spellName, dstGUID:sub(-6), is_swp and SWP_DURATION or VT_DURATION))
      end
   elseif subevent == "SPELL_AURA_REMOVED" then
      local entry = active_dots[dstGUID]
      if entry then
         if is_swp then entry.swp = 0
         else entry.vt = 0 end
         if entry.swp == 0 and entry.vt == 0 then
            active_dots[dstGUID] = nil
         end
      end
   end
end)

-- Query: get dot remaining on a nameplate unitID (maps to GUID internally)
local function get_dot_remaining(unitID, dot_key)
   local guid = UnitGUID(unitID)
   if not guid then return 0 end
   local entry = active_dots[guid]
   if not entry then return 0 end
   local expiry = entry[dot_key] or 0
   local remaining = expiry - GetTime()
   return remaining > 0 and remaining or 0
end

-- AoE spread rate limiting
local AOE_GCD_GUARD = 1.6
local last_aoe_swp_show = 0
local last_aoe_vt_show = 0

-- Pre-allocated Click table for AoE targeting (avoids inline table creation in combat)
-- Set .unit before Show() to cast on a specific nameplate unit instead of current target
local aoe_click = { unit = nil }

-- Cast a spell on a specific nameplate unit by temporarily setting its Click handler
local function cast_on_nameplate(spell, icon, unitID)
   local original_click = spell.Click
   aoe_click.unit = unitID
   spell.Click = aoe_click
   local result = spell:Show(icon)
   spell.Click = original_click
   return result
end

-- ============================================================================
-- SHADOW STATE (per-frame cache)
-- ============================================================================
local shadow_state = {
   vt_remaining = 0,
   swp_active = false,
   ve_remaining = 0,
   mb_ready = false,
   swd_ready = false,
   swd_safe = false,
   dp_ready = false,
   inner_focus_ready = false,
   in_aoe = false,
   execute_phase = false,
}

local function get_shadow_state(context)
   if context._shadow_valid then
      return shadow_state
   end
   context._shadow_valid = true

   -- VT: use spell ID to detect correct rank (useMaxRank = true means ID changes per rank)
   shadow_state.vt_remaining = Unit(TARGET_UNIT):HasDeBuffs(A.VampiricTouch.ID, "player", true) or 0
   shadow_state.swp_active = (Unit(TARGET_UNIT):HasDeBuffs(A.ShadowWordPain.ID, "player", true) or 0) > 0
   -- VE: use spell ID (15286) not party buff ID (15290) for target debuff check
   shadow_state.ve_remaining = Unit(TARGET_UNIT):HasDeBuffs(A.VampiricEmbrace.ID, "player", true) or 0
   shadow_state.mb_ready = is_spell_available(A.MindBlast) and A.MindBlast:IsReady(TARGET_UNIT)
   shadow_state.swd_ready = is_spell_available(A.ShadowWordDeath) and A.ShadowWordDeath:IsReady(TARGET_UNIT)
   shadow_state.swd_safe = context.hp > (context.settings.shadow_swd_hp or 40)
   local dp_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEVOURING_PLAGUE, "player", true) or 0
   shadow_state.dp_ready = is_spell_available(A.DevouringPlague) and A.DevouringPlague:IsReady(TARGET_UNIT) and dp_debuff <= 3
   shadow_state.inner_focus_ready = is_spell_available(A.InnerFocus) and A.InnerFocus:IsReady(PLAYER_UNIT)

   -- AoE mode: enough enemies for blanket DoT spreading
   shadow_state.in_aoe = context.enemy_count >= (context.settings.shadow_aoe_count or 4)

   -- Execute phase: target dying soon, skip DoTs and nuke
   local execute_ttd = context.settings.shadow_execute_ttd or 10
   shadow_state.execute_phase = context.ttd > 0 and context.ttd <= execute_ttd

   return shadow_state
end

-- ============================================================================
-- SHADOW STRATEGIES
-- ============================================================================
rotation_registry:register("shadow", {

   -- [1] Ensure Shadowform (OOC or if dropped)
   named("EnsureShadowform", {
      matches = function(context, state)
         if context.in_shadowform then
            return false
         end
         if context.is_mounted then
            return false
         end
         return is_spell_available(A.Shadowform)
      end,
      execute = function(icon, context, state)
         return try_cast(A.Shadowform, icon, PLAYER_UNIT, "[SHADOW] Shadowform")
      end,
   }),

   -- [2] Pre-Combat Pull (start combat with VT or MB)
   named("PreCombatPull", {
      matches = function(context, state)
         if context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         if not context.in_shadowform then
            return false
         end
         -- Only pull if we have a valid enemy and are in range
         if not A.VampiricTouch:IsInRange(TARGET_UNIT) then
            return false
         end
         -- Don't re-pull if VT already on target (cast completed but combat hasn't started)
         if state.vt_remaining > 0 then
            return false
         end
         -- Don't re-cast while already casting VT
         if Player:IsCasting() == vt_spell_name then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         -- Prefer VT for pull (applies DoT immediately), fallback to MB
         if is_spell_available(A.VampiricTouch) and A.VampiricTouch:IsReady(TARGET_UNIT) then
            return try_cast(A.VampiricTouch, icon, TARGET_UNIT, "[SHADOW] Pull: Vampiric Touch")
         end
         if state.mb_ready then
            return try_cast(A.MindBlast, icon, TARGET_UNIT, "[SHADOW] Pull: Mind Blast")
         end
         return nil
      end,
   }),

   -- [3] AoE SW:P Spread (blanket enemies with SW:P)
   named("AoESWPSpread", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.shadow_dot_spread then
            return false
         end
         if context.enemy_count < (context.settings.shadow_aoe_count or 4) then
            return false
         end
         -- Don't flip targets during GCD from previous SWP
         if GetTime() - last_aoe_swp_show < AOE_GCD_GUARD then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         local max_targets = context.settings.shadow_swp_spread_max or 8
         local plates = MultiUnits:GetActiveUnitPlates()
         for unitID in pairs(plates) do
            if UnitExists(unitID) and not Unit(unitID):IsDead() then
               local unit_ttd = Unit(unitID):TimeToDie() or 0
               local survives = unit_ttd == 0 or unit_ttd >= 6
               local cc_remaining = Unit(unitID):InCC() or 0
               if not survives or cc_remaining > 0 or Unit(unitID):CombatTime() == 0 then
                  -- skip dying, CC'd, or out-of-combat mobs
               else
                  local swp_remaining = get_dot_remaining(unitID, "swp")
                  if swp_remaining > DOT_REFRESH_WINDOW then
                     max_targets = max_targets - 1
                  elseif max_targets > 0 and A.ShadowWordPain:IsReady(unitID) then
                     local result = cast_on_nameplate(A.ShadowWordPain, icon, unitID)
                     if result then
                        last_aoe_swp_show = GetTime()
                        return result, ("[SHADOW] AoE SW:P on %s"):format(unitID)
                     end
                  end
               end
               if max_targets <= 0 then return nil end
            end
         end
         return nil
      end,
   }),

   -- [4] AoE VT Spread (blanket enemies with VT)
   named("AoEVTSpread", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.shadow_dot_spread then
            return false
         end
         if context.is_moving then
            return false
         end
         if context.enemy_count < (context.settings.shadow_aoe_count or 4) then
            return false
         end
         -- VT is a 1.5s cast — don't flip targets mid-cast
         if GetTime() - last_aoe_vt_show < 2.0 then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         local max_targets = context.settings.shadow_vt_spread_max or 5
         local plates = MultiUnits:GetActiveUnitPlates()
         for unitID in pairs(plates) do
            if UnitExists(unitID) and not Unit(unitID):IsDead() then
               local unit_ttd = Unit(unitID):TimeToDie() or 0
               local survives = unit_ttd == 0 or unit_ttd >= 6
               local cc_remaining = Unit(unitID):InCC() or 0
               if not survives or cc_remaining > 0 or Unit(unitID):CombatTime() == 0 then
                  -- skip dying, CC'd, or out-of-combat mobs
               else
                  local vt_remaining = get_dot_remaining(unitID, "vt")
                  if vt_remaining > DOT_REFRESH_WINDOW then
                     max_targets = max_targets - 1
                  elseif max_targets > 0 and A.VampiricTouch:IsReady(unitID) then
                     local result = cast_on_nameplate(A.VampiricTouch, icon, unitID)
                     if result then
                        last_aoe_vt_show = GetTime()
                        return result, ("[SHADOW] AoE VT on %s"):format(unitID)
                     end
                  end
               end
               if max_targets <= 0 then return nil end
            end
         end
         return nil
      end,
   }),

   -- [5] AoE VE (apply to main target after blanket DoTs are spread)
   named("AoEVE", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not state.in_aoe then
            return false
         end
         if not context.settings.shadow_ve_maintain then
            return false
         end
         if state.ve_remaining >= 3 then
            return false
         end
         if not A.VampiricEmbrace:IsInRange(TARGET_UNIT) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.VampiricEmbrace, icon, TARGET_UNIT, "[SHADOW] AoE VE (main target)")
      end,
   }),

   -- [6] Shadow Word: Pain (reapply when fallen off — instant, get it ticking first)
   named("ShadowWordPain", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if state.execute_phase then
            return false
         end
         if state.in_aoe then
            return false
         end
         if state.swp_active then
            return false
         end
         -- Don't apply if target will die soon (need 2 ticks = 6s minimum)
         if context.ttd and context.ttd > 0 and context.ttd < 6 then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.ShadowWordPain, icon, TARGET_UNIT, "[SHADOW] SW:P")
      end,
   }),

   -- [7] Vampiric Touch (refresh when remaining < cast time)
   named("VampiricTouch", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if state.execute_phase then
            return false
         end
         if state.in_aoe then
            return false
         end
         if context.is_moving then
            return false
         end
         -- Don't re-cast while already casting VT
         if Player:IsCasting() == vt_spell_name then
            return false
         end
         -- Don't apply on dying targets (1.5s cast + 15s DoT, need 2 ticks = 6s minimum)
         if context.ttd and context.ttd > 0 and context.ttd < 6 then
            return false
         end
         if state.vt_remaining == 0 then return true end
         return state.vt_remaining < 1.8
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.VampiricTouch, icon, TARGET_UNIT, "[SHADOW]", "VT", "rem: %.1fs", state.vt_remaining)
      end,
   }),

   -- [8] Shadow Word: Death (high priority nuke when DoTs are active)
   named("ShadowWordDeath", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_use_swd then
            return false
         end
         if not state.swd_safe then
            return false
         end
         -- Only fire when DoTs are healthy (SWP/VT strategies above handle refresh)
         if not state.swp_active then
            return false
         end
         if state.vt_remaining < 1.8 then
            return false
         end
         return state.swd_ready
      end,
      execute = function(icon, context, state)
         return try_cast_fmt(A.ShadowWordDeath, icon, TARGET_UNIT, "[SHADOW]", "SW:D", "HP: %.0f%%", context.hp)
      end,
   }),

   -- [9] Inner Focus (off-GCD, pair with MB or DP)
   named("InnerFocus", {
      is_gcd_gated = false,
      is_burst = true,
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.settings.shadow_use_inner_focus then
            return false
         end
         if not state.inner_focus_ready then
            return false
         end
         if context.has_inner_focus then
            return false
         end
         return state.mb_ready or state.dp_ready
      end,
      execute = function(icon, context, state)
         return try_cast(A.InnerFocus, icon, PLAYER_UNIT, "[SHADOW] Inner Focus")
      end,
   }),

   -- [10] Mind Blast (on cooldown)
   named("MindBlast", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         return state.mb_ready
      end,
      execute = function(icon, context, state)
         return try_cast(A.MindBlast, icon, TARGET_UNIT, "[SHADOW] Mind Blast")
      end,
   }),

   -- [11] Devouring Plague (Undead racial)
   named("DevouringPlague", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_use_devouring_plague then
            return false
         end
         -- Don't waste 3min CD on dying targets
         if context.ttd and context.ttd > 0 and context.ttd < 8 then
            return false
         end
         return state.dp_ready
      end,
      execute = function(icon, context, state)
         return try_cast(A.DevouringPlague, icon, TARGET_UNIT, "[SHADOW] Devouring Plague")
      end,
   }),

   -- [12] Vampiric Embrace (maintain debuff on target — optional, off by default)
   named("VampiricEmbrace", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if not context.settings.shadow_ve_maintain then
            return false
         end
         if state.execute_phase then
            return false
         end
         -- Don't apply on dying targets (wastes a GCD)
         if context.ttd and context.ttd > 0 and context.ttd < 6 then
            return false
         end
         if state.ve_remaining >= 3 then
            return false
         end
         if not A.VampiricEmbrace:IsInRange(TARGET_UNIT) then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.VampiricEmbrace, icon, TARGET_UNIT, "[SHADOW] Vampiric Embrace")
      end,
   }),

   -- [13] Mind Flay (filler)
   named("MindFlay", {
      matches = function(context, state)
         if not context.in_combat then
            return false
         end
         if not context.has_valid_enemy_target then
            return false
         end
         if context.is_moving then
            return false
         end
         return true
      end,
      execute = function(icon, context, state)
         return try_cast(A.MindFlay, icon, TARGET_UNIT, "[SHADOW] Mind Flay")
      end,
   }),

}, {
   context_builder = get_shadow_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Shadow rotation loaded")
