-- Menagerie - Shared Debug Panel
-- Live Player/Target state plus optional class-provided diagnostic sections.

local _G = _G
local NS = _G.Menagerie
if not NS then return end

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GetTime = _G.GetTime
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local UnitPowerType = _G.UnitPowerType
local IsInGroup = _G.IsInGroup
local GetNumGroupMembers = _G.GetNumGroupMembers
local format = string.format
local max = math.max

local DBG_THEME = NS.DBG_THEME
local CreateDebugWindow = NS.CreateDebugWindow
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"

if not (DBG_THEME and CreateDebugWindow) then return end

local UPDATE_INTERVAL = 0.1
local TOGGLE_CHECK_INTERVAL = 0.5
local FRAME_WIDTH = 260
local MIN_FRAME_HEIGHT = 96
local CONTENT_TOP = -40
local LEFT_PAD = 12
local LABEL_W = 82
local VALUE_X = LEFT_PAD + LABEL_W + 8
local LINE_H = 14
local HEADER_TOP_PAD = 5
local BOTTOM_PAD = 28
local HINT_Y = 8

local panel_frame
local visible = false
local rows = {}
local entries = {}
local entry_count = 0

local out = {}

local function alloc_entry(index)
   local entry = entries[index]
   if not entry then
      entry = {}
      entries[index] = entry
   end
   return entry
end

function out:header(text)
   entry_count = entry_count + 1
   local entry = alloc_entry(entry_count)
   entry.kind = "header"
   entry.label = nil
   entry.text = text or ""
   entry.value = nil
   entry.hex = nil
end

function out:kv(label, value, hex)
   entry_count = entry_count + 1
   local entry = alloc_entry(entry_count)
   entry.kind = "kv"
   entry.label = label or ""
   entry.value = tostring(value or "")
   entry.text = nil
   entry.hex = hex
end

function out:line(text)
   entry_count = entry_count + 1
   local entry = alloc_entry(entry_count)
   entry.kind = "line"
   entry.label = nil
   entry.text = text or ""
   entry.value = nil
   entry.hex = nil
end

local function reset_entries()
   entry_count = 0
end

local function value_color(font_string, hex)
   if hex == "dim" then
      font_string:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
      return
   end
   if hex and #hex == 6 then
      local r = tonumber(string.sub(hex, 1, 2), 16)
      local g = tonumber(string.sub(hex, 3, 4), 16)
      local b = tonumber(string.sub(hex, 5, 6), 16)
      if r and g and b then
         font_string:SetTextColor(r / 255, g / 255, b / 255)
         return
      end
   end
   font_string:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
end

local function ensure_row(index)
   local row = rows[index]
   if row then return row end

   row = {}

   row.line = panel_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   row.line:SetJustifyH("LEFT")
   row.line:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
   if row.line.SetWordWrap then row.line:SetWordWrap(false) end

   row.label = panel_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   row.label:SetJustifyH("LEFT")
   row.label:SetWidth(LABEL_W)
   row.label:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
   if row.label.SetWordWrap then row.label:SetWordWrap(false) end

   row.value = panel_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   row.value:SetJustifyH("LEFT")
   row.value:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
   if row.value.SetWordWrap then row.value:SetWordWrap(false) end

   rows[index] = row
   return row
end

local function set_row_point(font_string, y, right_pad)
   font_string:ClearAllPoints()
   font_string:SetPoint("TOPLEFT", panel_frame, "TOPLEFT", LEFT_PAD, y)
   font_string:SetPoint("TOPRIGHT", panel_frame, "TOPRIGHT", -(right_pad or LEFT_PAD), y)
end

local function layout_entries()
   local y = CONTENT_TOP

   for i = 1, entry_count do
      local entry = entries[i]
      local row = ensure_row(i)

      if entry.kind == "kv" then
         row.line:Hide()

         row.label:ClearAllPoints()
         row.label:SetPoint("TOPLEFT", panel_frame, "TOPLEFT", LEFT_PAD, y)
         row.label:SetWidth(LABEL_W)
         row.label:SetText(entry.label)
         row.label:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
         row.label:Show()

         row.value:ClearAllPoints()
         row.value:SetPoint("TOPLEFT", panel_frame, "TOPLEFT", VALUE_X, y)
         row.value:SetPoint("TOPRIGHT", panel_frame, "TOPRIGHT", -LEFT_PAD, y)
         row.value:SetText(entry.value)
         value_color(row.value, entry.hex)
         row.value:Show()
      else
         row.label:Hide()
         row.value:Hide()

         if entry.kind == "header" and i > 1 then
            y = y - HEADER_TOP_PAD
         end

         set_row_point(row.line, y)
         row.line:SetText(entry.text)
         if entry.kind == "header" then
            row.line:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])
         else
            row.line:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
         end
         row.line:Show()
      end

      y = y - LINE_H
   end

   for i = entry_count + 1, #rows do
      local row = rows[i]
      row.line:Hide()
      row.label:Hide()
      row.value:Hide()
   end

   panel_frame:SetHeight(max(MIN_FRAME_HEIGHT, -y + BOTTOM_PAD))
end

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

local function refresh_panel()
   if not (panel_frame and panel_frame:IsShown()) then return end

   reset_entries()
   build_generic_core(out)

   local ctx = fresh_context()
   local cc = rotation_registry and rotation_registry.class_config
   if cc and cc.debug_panel then
      cc.debug_panel(out, ctx)
   end

   layout_entries()
end

local function hide_panel()
   if panel_frame then
      panel_frame:Hide()
   end
   visible = false
end

local function create_panel()
   if panel_frame then return panel_frame end

   local frame = CreateDebugWindow("Menagerie Debug")
   frame:ClearAllPoints()
   frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -140)
   frame:SetSize(FRAME_WIDTH, MIN_FRAME_HEIGHT)
   frame:SetFrameStrata("HIGH")
   frame.closeBtn:SetScript("OnClick", hide_panel)

   local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   hint:SetPoint("BOTTOMLEFT", LEFT_PAD, HINT_Y)
   hint:SetText("/mdebug to toggle")
   hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
   frame.hint = hint

   frame:Hide()
   panel_frame = frame
   NS.DebugPanelFrame = frame
   return frame
end

local function show_panel()
   local frame = create_panel()
   visible = true
   frame:Show()
   refresh_panel()
end

function NS.toggle_debug_panel()
   if not (NS.cached_settings and NS.cached_settings.show_debug_panel) then
      print("|cFFFFCC00[Menagerie]|r Enable \"Show Debug Panel\" first, then use /mdebug.")
      return
   end

   if visible and panel_frame and panel_frame:IsShown() then
      hide_panel()
   else
      show_panel()
   end
end

local update_frame = CreateFrame("Frame")
update_frame.elapsed = 0
update_frame:SetScript("OnUpdate", function(self, elapsed)
   self.elapsed = self.elapsed + elapsed
   if self.elapsed >= UPDATE_INTERVAL then
      self.elapsed = 0
      refresh_panel()
   end
end)

local watch_frame = CreateFrame("Frame")
watch_frame.elapsed = 0
watch_frame:SetScript("OnUpdate", function(self, elapsed)
   self.elapsed = self.elapsed + elapsed
   if self.elapsed >= TOGGLE_CHECK_INTERVAL then
      self.elapsed = 0
      if visible and not (NS.cached_settings and NS.cached_settings.show_debug_panel) then
         hide_panel()
      end
   end
end)

SLASH_MENAGERIEDEBUG1 = "/mdebug"
SlashCmdList["MENAGERIEDEBUG"] = NS.toggle_debug_panel
