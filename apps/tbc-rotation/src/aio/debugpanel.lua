-- Menagerie - Shared Debug Panel
-- Live Player/Target state plus optional class-provided diagnostic sections.
-- A thin instance of NS.CreateLivePanel: the factory owns the frame, the out
-- writer, the pooled layout, the refresh loop, and the toggle watch. This file
-- only builds the data and wires up the slash command.

local _G = _G
local NS = _G.Menagerie
if not NS then return end

if type(NS.CreateLivePanel) ~= "function" then return end

local GetTime = _G.GetTime
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local UnitPowerType = _G.UnitPowerType
local IsInGroup = _G.IsInGroup
local GetNumGroupMembers = _G.GetNumGroupMembers
local format = string.format

local Player = NS.Player
local Unit = NS.Unit
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

local function fmt_percent(value)
   return format("%.1f%%", tonumber(value) or 0)
end

local function fmt_seconds(value)
   return format("%.1fs", tonumber(value) or 0)
end

local function yes_no(value)
   return value and "yes" or "no"
end

local function fresh_context()
   local ctx = NS.last_rotation_context
   if ctx and (GetTime() - (NS.last_rotation_context_time or 0)) > 0.25 then
      ctx = nil
   end
   return ctx
end

local function player_health_percent(player_unit)
   if player_unit and player_unit.HealthPercent then
      return player_unit:HealthPercent()
   end
   return 0
end

local function player_mana_percent()
   if Player and Player.ManaPercentage then
      return Player:ManaPercentage()
   end
   return 0
end

local function player_gcd_remaining()
   if Player and Player.GCDRemains then
      return Player:GCDRemains()
   end
   return 0
end

local function unit_exists(unit)
   return unit and unit.IsExists and unit:IsExists() or false
end

local function build_generic_core(writer)
   local ctx = fresh_context()
   local player_unit = Unit and Unit(PLAYER_UNIT) or nil
   local target_unit = Unit and Unit(TARGET_UNIT) or nil
   local in_group = false
   if IsInGroup then
      in_group = IsInGroup() or false
   elseif GetNumGroupMembers then
      in_group = (GetNumGroupMembers() or 0) > 0
   end

   writer:header("PLAYER")
   writer:kv("HP", fmt_percent(player_health_percent(player_unit)))
   if not UnitPowerType or UnitPowerType(PLAYER_UNIT) == 0 then
      writer:kv("Mana", fmt_percent(player_mana_percent()))
   end
   writer:kv("GCD", fmt_seconds(player_gcd_remaining()))
   writer:kv("In Combat", yes_no(UnitAffectingCombat and UnitAffectingCombat(PLAYER_UNIT)))
   writer:kv("Combat Time", fmt_seconds(player_unit and player_unit.CombatTime and player_unit:CombatTime() or 0))
   writer:kv("Group", in_group and "group" or "solo")

   writer:header("TARGET")
   if not unit_exists(target_unit) then
      writer:kv("Target", "none", "dim")
      return
   end

   local max_range, min_range = 0, nil
   if target_unit.GetRange then
      max_range, min_range = target_unit:GetRange()
   end
   max_range = max_range or 0

   writer:kv("HP", fmt_percent(target_unit.HealthPercent and target_unit:HealthPercent() or 0))
   writer:kv("Range", format("%.1fy", tonumber(max_range) or 0))
   writer:kv("In Melee", yes_no(min_range and min_range <= 5))
   writer:kv("Enemy", yes_no(UnitCanAttack and UnitCanAttack(PLAYER_UNIT, TARGET_UNIT)))

   if ctx then
      if ctx.ttd then writer:kv("TTD", fmt_seconds(ctx.ttd)) end
      writer:kv("Phys Immune", yes_no(ctx.target_phys_immune))
      writer:kv("Magic Immune", yes_no(ctx.target_magic_immune))
      writer:kv("Boss/Elite", yes_no(ctx.is_boss or ctx.target_is_elite))
   end
end

local panel = NS.CreateLivePanel({
   title = "Menagerie Debug",
   setting_key = "show_debug_panel",
   width = 260,
   min_height = 96,
   manual_toggle = true,
   get_context = fresh_context,
   hint = "/mdebug to toggle",
   anchor = { "TOPLEFT", "TOPLEFT", 50, -140 },
   build = function(out, ctx)
      build_generic_core(out)
      local cc = NS.rotation_registry and NS.rotation_registry.class_config
      if cc and cc.debug_panel then
         cc.debug_panel(out, ctx)
      end
   end,
})

function NS.toggle_debug_panel()
   if not (NS.cached_settings and NS.cached_settings.show_debug_panel) then
      print("|cFFFFCC00[Menagerie]|r Enable \"Show Debug Panel\" first, then use /mdebug.")
      return
   end
   panel:Toggle()
end

SLASH_MENAGERIEDEBUG1 = "/mdebug"
SlashCmdList["MENAGERIEDEBUG"] = NS.toggle_debug_panel
