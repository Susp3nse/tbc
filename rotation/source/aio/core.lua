-- Flux AIO - Core Module
-- Generic rotation engine: namespace, settings, utilities, registry
-- Class-agnostic: class files register via rotation_registry:register_class()

-- ============================================================================
-- FRAMEWORK VALIDATION
-- ============================================================================
local _G, setmetatable, pairs, ipairs, tostring, type = _G, setmetatable, pairs, ipairs, tostring, type
local tinsert, tremove, tconcat, tsort = table.insert, table.remove, table.concat, table.sort
local floor = math.floor
local format = string.format
local GetTime = _G.GetTime
local UnitAffectingCombat = _G.UnitAffectingCombat
local A = _G.Action

if not A then
   print("|cFFFF0000[Flux AIO]|r Action/Textfiles framework not loaded!")
   return
end

if not A.Data.ProfileEnabled[A.CurrentProfile] then
   print("|cFFFF0000[Flux AIO]|r WARNING: ProfileEnabled is not set!")
   print("|cFFFF0000[Flux AIO]|r Did you install the schema snippet first?")
   return
end

-- ============================================================================
-- GLOBAL NAMESPACE CREATION
-- ============================================================================
_G.FluxAIO = _G.FluxAIO or {}
local NS = _G.FluxAIO

-- Base framework references (available before class Actions are defined)
local Player = A.Player
local Unit = A.Unit
local GetToggle = A.GetToggle

NS.Player = Player
NS.Unit = Unit
NS.GetToggle = GetToggle

-- Stub: overridden by dashboard.lua with real implementation
if not NS.set_last_action then
    NS.set_last_action = function() end
end

-- ============================================================================
-- UNIT CONSTANTS
-- ============================================================================
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local RACE_TROLL = "Troll"
local RACE_ORC = "Orc"

NS.PLAYER_UNIT = PLAYER_UNIT
NS.TARGET_UNIT = TARGET_UNIT
NS.RACE_TROLL = RACE_TROLL
NS.RACE_ORC = RACE_ORC

-- ============================================================================
-- FORCE COMMAND FLAGS (set by /flux slash commands)
-- ============================================================================
-- Values are expiry timestamps (GetTime() + duration). Zero = inactive.
-- Checked each frame by execute_middleware/execute_strategies in main.lua.
NS.force_burst = 0
NS.force_defensive = 0
NS.force_gap = 0

local FORCE_DURATION = 3.0

local function set_force_flag(flag_name)
   NS[flag_name] = GetTime() + FORCE_DURATION
end

local function is_force_active(flag_name)
   local expiry = NS[flag_name]
   return expiry > 0 and GetTime() < expiry
end

local function clear_force_flag(flag_name)
   NS[flag_name] = 0
end

NS.set_force_flag = set_force_flag
NS.is_force_active = is_force_active
NS.clear_force_flag = clear_force_flag

-- ============================================================================
-- CENTER-SCREEN NOTIFICATION
-- ============================================================================
-- Pre-allocated frame for brief center-screen text notifications.
-- Usage: NS.show_notification("text", duration_seconds, {r, g, b})
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

local notif_frame = CreateFrame("Frame", "FluxAIONotification", UIParent)
notif_frame:SetSize(300, 40)
notif_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
notif_frame:SetFrameStrata("HIGH")

local notif_text = notif_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notif_text:SetPoint("CENTER")
notif_text:SetFont(notif_text:GetFont() or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

local notif_fade_start = 0
local notif_fade_duration = 0.4
local notif_visible_until = 0

notif_frame:SetScript("OnUpdate", function(self, elapsed)
   local now = GetTime()
   if now < notif_visible_until then
      notif_text:SetAlpha(1)
   elseif now < notif_visible_until + notif_fade_duration then
      local progress = (now - notif_visible_until) / notif_fade_duration
      notif_text:SetAlpha(1 - progress)
   else
      notif_text:SetAlpha(0)
      self:Hide()
   end
end)
notif_frame:Hide()

local function show_notification(text, duration, color)
   duration = duration or 1.5
   color = color or { 1, 1, 1 }
   notif_text:SetText(text)
   notif_text:SetTextColor(color[1], color[2], color[3], 1)
   notif_visible_until = GetTime() + duration
   notif_frame:Show()
end

NS.show_notification = show_notification

-- ============================================================================
-- PRIORITY REGISTRY (Middleware Only)
-- Higher number = runs FIRST (descending order)
-- ============================================================================
local Priority = {
   MIDDLEWARE = {
      FORM_RESHIFT = 500,
      EMERGENCY_HEAL = 400,
      PROACTIVE_HEAL = 390,
      DISPEL_CURSE = 350,
      DISPEL_POISON = 340,
      RECOVERY_ITEMS = 300,
      INNERVATE = 290,
      MANA_RECOVERY = 280,
      SELF_BUFF_MOTW = 150,
      SELF_BUFF_THORNS = 145,
      SELF_BUFF_OOC = 140,
      OFFENSIVE_COOLDOWNS = 100,
   },
}

NS.Priority = Priority

-- ============================================================================
-- SPELL COST UTILITIES
-- ============================================================================
-- TBC power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy
local function get_spell_mana_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 0) and cost or 0
end

local function get_spell_rage_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 1) and cost or 0
end

local function get_spell_energy_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 3) and cost or 0
end

local function get_spell_focus_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 2) and cost or 0
end

NS.get_spell_mana_cost = get_spell_mana_cost
NS.get_spell_rage_cost = get_spell_rage_cost
NS.get_spell_energy_cost = get_spell_energy_cost
NS.get_spell_focus_cost = get_spell_focus_cost

-- ============================================================================
-- IMMUNITY SPELL IDS (from LibAuraTypes.lua TBC section)
-- ============================================================================
local IMMUNITY_TOTAL = { 642, 1020, 45438, 11958, 1022, 5599, 10278, 31224, 33786, 710, 18647, 498, 19263 }
local IMMUNITY_PHYS = { 1022, 5599, 10278, 642, 1020, 45438, 11958, 33786, 710, 18647, 3169, 19263 }
local IMMUNITY_MAGIC = { 31224, 8178, 642, 1020, 45438, 11958, 33786 }
local IMMUNITY_CC = { 19574, 34471, 18499, 1719, 31224, 642, 1020, 45438, 11958, 33786, 6346, 12328 }
local IMMUNITY_STUN = { 19574, 34471, 18499, 642, 1020, 45438, 11958, 33786, 6615, 24364 }
local IMMUNITY_KICK = { 31224, 642, 1020, 45438, 11958, 33786 }

local function has_immunity_buff(target, buff_ids)
   if not target or not _G.UnitExists(target) then return false end
   local duration = Unit(target):HasBuffs(buff_ids, nil, true) or 0
   return duration > 0
end

local function has_phys_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_PHYS)
end

local function has_magic_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_MAGIC)
end

local function has_cc_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_CC)
end

local function has_stun_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_STUN)
end

local function has_kick_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_KICK)
end

local function has_total_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_TOTAL)
end

NS.has_phys_immunity = has_phys_immunity
NS.has_magic_immunity = has_magic_immunity
NS.has_cc_immunity = has_cc_immunity
NS.has_stun_immunity = has_stun_immunity
NS.has_kick_immunity = has_kick_immunity
NS.has_total_immunity = has_total_immunity

-- ============================================================================
-- SCHOOL-IMMUNE NPC TABLES (npcID → true)
-- Used by callers to skip school-locked spells against immune mobs.
-- Query npcID via: select(6, Unit(unit):InfoGUID())
-- ============================================================================
NS.ARCANE_IMMUNE = {
   [15691] = true,  -- The Curator (Karazhan)
   [17096] = true,  -- Astral Flare (Curator add)
   [18864] = true,  -- Mana Wraith (Karazhan trash)
   [18865] = true,  -- Warp Aberration (Karazhan trash)
   [20478] = true,  -- Arcane Servant
}

-- ============================================================================
-- SETTINGS SYSTEM
-- ============================================================================
local cached_settings = {}
local last_settings_update = 0
local SETTINGS_CACHE_DURATION = 0.05
local settings_changed_list = {}

NS.cached_settings = cached_settings

local function update_setting(key, value, changed_list, debug_mode)
   local old_value = cached_settings[key]
   cached_settings[key] = value

   if debug_mode and old_value ~= nil and old_value ~= value then
      changed_list[#changed_list + 1] = key .. ": " .. tostring(old_value) .. " -> " .. tostring(value)
   end
end

-- ============================================================================
-- SPELL VALIDATION SYSTEM
-- ============================================================================
local unavailable_spells = {}

NS.unavailable_spells = unavailable_spells

local function is_spell_known(spell)
   if not spell then return false, "nil" end
   local spell_id = spell.ID
   if not spell_id then return false, "no ID" end
   local spell_name = _G.GetSpellInfo(spell_id)
   if not spell_name then return false, "ID:" .. tostring(spell_id) end
   if _G.IsSpellKnown and _G.IsSpellKnown(spell_id) then
      return true, spell_name
   end
   -- IsSpellKnown may miss talent-granted spells; fall through to framework check
   return spell:IsExists() == true, spell_name
end

local function check_spell_availability(entries, missing_spells, optional_missing)
   for _, entry in ipairs(entries) do
      local known, name = is_spell_known(entry.spell)
      if not known then
         if entry.spell then
            unavailable_spells[entry.spell] = true
         end
         if entry.required then
            tinsert(missing_spells, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
         else
            tinsert(optional_missing, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
         end
      else
         if entry.spell then
            unavailable_spells[entry.spell] = nil
         end
      end
   end
end

local function is_spell_available(spell)
   if not spell then return false end
   return not unavailable_spells[spell]
end

NS.is_spell_known = is_spell_known
NS.check_spell_availability = check_spell_availability
NS.is_spell_available = is_spell_available

-- ============================================================================
-- REFRESH SETTINGS (schema-driven)
-- ============================================================================
local SETTINGS_SCHEMA = _G.FluxAIO_SETTINGS_SCHEMA

local function refresh_settings()
   local now = GetTime()
   if now - last_settings_update < SETTINGS_CACHE_DURATION then return end

   local debug_mode = GetToggle(2, "debug_mode")
   local changed_list = settings_changed_list
   for i = 1, #changed_list do changed_list[i] = nil end

   for _, tab_def in ipairs(SETTINGS_SCHEMA) do
      for _, section in ipairs(tab_def.sections) do
         for _, s in ipairs(section.settings) do
               local raw = GetToggle(2, s.key)
               local value
               if s.type == "checkbox" then
                  if s.default == true then
                     value = raw ~= false
                  else
                     value = raw == true
                  end
               else
                  value = raw or s.default
               end
               update_setting(s.key, value, changed_list, debug_mode)
         end
      end
   end

   if debug_mode and #changed_list > 0 then
      print("|cFF00FFFF[Flux AIO]|r Settings changed at " .. format("%.1f", now))
      for _, change in ipairs(changed_list) do
         print("|cFF00FFFF[Flux AIO]|r   " .. change)
      end
   end

   last_settings_update = now
end

NS.refresh_settings = refresh_settings

-- ============================================================================
-- DEBUG SYSTEM
-- ============================================================================
local DebugLogFrame
local debug_log_lines = {}
local MAX_LOG_LINES = 500

local DBG_THEME = {
   bg          = { 0.067, 0.067, 0.078, 0.75 },    -- #111114
   bg_widget   = { 0.118, 0.118, 0.141, 1 },       -- #1e1e24
   bg_hover    = { 0.133, 0.133, 0.157, 1 },       -- #222228
   border      = { 0.173, 0.173, 0.204, 1 },       -- #2c2c34
   accent      = { 0.424, 0.388, 1.0, 1 },         -- #6c63ff
   text        = { 0.863, 0.863, 0.894, 1 },       -- #dcdce4
   text_dim    = { 0.580, 0.580, 0.659, 1 },       -- #9494a8
}
local DBG_BACKDROP = {
   bgFile = "Interface\\Buttons\\WHITE8X8",
   edgeFile = "Interface\\Buttons\\WHITE8X8",
   edgeSize = 1,
}

local function create_debug_button(parent, text, width)
   local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
   btn:SetSize(width, 22)
   btn:SetBackdrop(DBG_BACKDROP)
   btn:SetBackdropColor(DBG_THEME.bg_widget[1], DBG_THEME.bg_widget[2], DBG_THEME.bg_widget[3], 1)
   btn:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)

   local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
   label:SetPoint("CENTER")
   label:SetText(text)
   label:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])

   btn:SetScript("OnEnter", function()
      btn:SetBackdropColor(DBG_THEME.bg_hover[1], DBG_THEME.bg_hover[2], DBG_THEME.bg_hover[3], 1)
      btn:SetBackdropBorderColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 1)
   end)
   btn:SetScript("OnLeave", function()
      btn:SetBackdropColor(DBG_THEME.bg_widget[1], DBG_THEME.bg_widget[2], DBG_THEME.bg_widget[3], 1)
      btn:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
   end)
   return btn
end

local function CreateDebugLogFrame()
   if DebugLogFrame then return DebugLogFrame end

   local f = CreateFrame("Frame", "FluxAIODebugFrame", UIParent, "BackdropTemplate")
   f:SetSize(500, 300)
   f:SetPoint("TOPLEFT", 50, -100)
   f:SetBackdrop(DBG_BACKDROP)
   f:SetBackdropColor(DBG_THEME.bg[1], DBG_THEME.bg[2], DBG_THEME.bg[3], DBG_THEME.bg[4])
   f:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], DBG_THEME.border[4])
   f:SetMovable(true)
   f:SetResizable(true)
   f:EnableMouse(true)
   f:SetClampedToScreen(true)
   f:RegisterForDrag("LeftButton")
   f:SetScript("OnDragStart", f.StartMoving)
   f:SetScript("OnDragStop", f.StopMovingOrSizing)

   -- Title
   local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   title:SetPoint("TOPLEFT", 12, -8)
   title:SetText("Flux AIO Debug Log")
   title:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])

   -- Close button
   local closeBtn = CreateFrame("Button", nil, f)
   closeBtn:SetSize(22, 22)
   closeBtn:SetPoint("TOPRIGHT", -6, -6)
   local closeX = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   closeX:SetPoint("CENTER")
   closeX:SetText("x")
   closeX:SetTextColor(0.6, 0.6, 0.6)
   closeBtn:SetScript("OnClick", function() f:Hide() end)
   closeBtn:SetScript("OnEnter", function() closeX:SetTextColor(1, 0.3, 0.3) end)
   closeBtn:SetScript("OnLeave", function() closeX:SetTextColor(0.6, 0.6, 0.6) end)

   -- Separator
   local sep = f:CreateTexture(nil, "ARTWORK")
   sep:SetPoint("TOPLEFT", 1, -28)
   sep:SetPoint("TOPRIGHT", -1, -28)
   sep:SetHeight(1)
   sep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)

   -- Action buttons
   local copyBtn = create_debug_button(f, "Copy", 60)
   copyBtn:SetPoint("TOPRIGHT", -70, -5)

   local clearBtn = create_debug_button(f, "Clear", 60)
   clearBtn:SetPoint("TOPRIGHT", -6, -5)

   -- Scroll frame
   local scrollFrame = CreateFrame("ScrollFrame", nil, f)
   scrollFrame:SetPoint("TOPLEFT", 8, -32)
   scrollFrame:SetPoint("BOTTOMRIGHT", -8, 28)
   scrollFrame:EnableMouseWheel(true)
   f.scrollFrame = scrollFrame

   local contentFrame = CreateFrame("Frame", nil, scrollFrame)
   contentFrame:SetWidth(scrollFrame:GetWidth() or 460)
   contentFrame:SetHeight(1)
   scrollFrame:SetScrollChild(contentFrame)
   f.contentFrame = contentFrame

   scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local cur = self:GetVerticalScroll()
      local mx = self:GetVerticalScrollRange()
      self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
   end)

   local textDisplay = contentFrame:CreateFontString(nil, "OVERLAY")
   textDisplay:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
   textDisplay:SetPoint("TOPLEFT", 4, 0)
   textDisplay:SetPoint("TOPRIGHT", -4, 0)
   textDisplay:SetJustifyH("LEFT")
   textDisplay:SetJustifyV("TOP")
   textDisplay:SetWordWrap(true)
   textDisplay:SetSpacing(2)
   textDisplay:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
   f.textDisplay = textDisplay

   -- Copy popup
   local copyPopup = CreateFrame("Frame", "FluxAIOCopyPopup", UIParent, "BackdropTemplate")
   copyPopup:SetSize(450, 200)
   copyPopup:SetPoint("CENTER")
   copyPopup:SetBackdrop(DBG_BACKDROP)
   copyPopup:SetBackdropColor(DBG_THEME.bg[1], DBG_THEME.bg[2], DBG_THEME.bg[3], 0.98)
   copyPopup:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
   copyPopup:SetFrameStrata("DIALOG")
   copyPopup:EnableMouse(true)
   copyPopup:Hide()
   f.copyPopup = copyPopup

   local copyTitle = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
   copyTitle:SetPoint("TOP", 0, -10)
   copyTitle:SetText("Press Ctrl+C to copy, then Escape to close")
   copyTitle:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])

   local copyCloseBtn = CreateFrame("Button", nil, copyPopup)
   copyCloseBtn:SetSize(22, 22)
   copyCloseBtn:SetPoint("TOPRIGHT", -6, -6)
   local copyCloseX = copyCloseBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   copyCloseX:SetPoint("CENTER")
   copyCloseX:SetText("x")
   copyCloseX:SetTextColor(0.6, 0.6, 0.6)
   copyCloseBtn:SetScript("OnClick", function() copyPopup:Hide() end)
   copyCloseBtn:SetScript("OnEnter", function() copyCloseX:SetTextColor(1, 0.3, 0.3) end)
   copyCloseBtn:SetScript("OnLeave", function() copyCloseX:SetTextColor(0.6, 0.6, 0.6) end)

   local copySep = copyPopup:CreateTexture(nil, "ARTWORK")
   copySep:SetPoint("TOPLEFT", 1, -28)
   copySep:SetPoint("TOPRIGHT", -1, -28)
   copySep:SetHeight(1)
   copySep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)

   local copyScrollFrame = CreateFrame("ScrollFrame", nil, copyPopup)
   copyScrollFrame:SetPoint("TOPLEFT", 8, -32)
   copyScrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)
   copyScrollFrame:EnableMouseWheel(true)

   copyScrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local cur = self:GetVerticalScroll()
      local mx = self:GetVerticalScrollRange()
      self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
   end)

   local copyEditBox = CreateFrame("EditBox", nil, copyScrollFrame)
   copyEditBox:SetMultiLine(true)
   copyEditBox:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
   copyEditBox:SetWidth(420)
   copyEditBox:SetAutoFocus(false)
   copyEditBox:EnableMouse(true)
   copyEditBox:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
   copyEditBox:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
   copyScrollFrame:SetScrollChild(copyEditBox)
   f.copyEditBox = copyEditBox

   copyBtn:SetScript("OnClick", function()
      local logText = tconcat(debug_log_lines, "\n")
      copyEditBox:SetText(logText)
      copyPopup:Show()
      copyEditBox:SetFocus()
      copyEditBox:HighlightText()
   end)

   clearBtn:SetScript("OnClick", function()
      debug_log_lines = {}
      textDisplay:SetText("")
      contentFrame:SetHeight(1)
   end)

   -- Resize grip
   local resizeBtn = CreateFrame("Button", nil, f)
   resizeBtn:SetSize(12, 12)
   resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
   local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
   resizeTex:SetAllPoints()
   resizeTex:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 0.6)
   resizeBtn:SetScript("OnEnter", function()
      resizeTex:SetColorTexture(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 0.8)
   end)
   resizeBtn:SetScript("OnLeave", function()
      resizeTex:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 0.6)
   end)
   resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
   resizeBtn:SetScript("OnMouseUp", function()
      f:StopMovingOrSizing()
      contentFrame:SetWidth(scrollFrame:GetWidth() - 10)
      textDisplay:SetWidth(scrollFrame:GetWidth() - 10)
   end)
   f:SetResizeBounds(300, 150, 800, 600)

   -- Hint text
   local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   hint:SetPoint("BOTTOMLEFT", 8, 8)
   hint:SetText("/fluxlog to toggle")
   hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])

   f:Hide()
   DebugLogFrame = f
   NS.DebugLogFrame = f
   return f
end

local function AddDebugLogLine(text)
   tinsert(debug_log_lines, text)
   while #debug_log_lines > MAX_LOG_LINES do
      tremove(debug_log_lines, 1)
   end

   if DebugLogFrame and DebugLogFrame:IsShown() then
      local logText = tconcat(debug_log_lines, "\n")
      DebugLogFrame.textDisplay:SetText(logText)
      local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
      DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
      C_Timer.After(0.01, function()
         if DebugLogFrame and DebugLogFrame.scrollFrame then
            DebugLogFrame.scrollFrame:SetVerticalScroll(DebugLogFrame.scrollFrame:GetVerticalScrollRange())
         end
      end)
   end
end

local function RefreshDebugLogFrame()
   if DebugLogFrame and DebugLogFrame.textDisplay then
      local logText = tconcat(debug_log_lines, "\n")
      DebugLogFrame.textDisplay:SetText(logText)
      local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
      DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
      C_Timer.After(0.05, function()
         if DebugLogFrame and DebugLogFrame.scrollFrame then
            DebugLogFrame.scrollFrame:SetVerticalScroll(DebugLogFrame.scrollFrame:GetVerticalScrollRange())
         end
      end)
   end
end

NS.CreateDebugLogFrame = CreateDebugLogFrame
NS.RefreshDebugLogFrame = RefreshDebugLogFrame

-- /fluxlog slash command
SLASH_FLUXLOG1 = "/fluxlog"
SLASH_FLUXLOG2 = "/flog"
SlashCmdList["FLUXLOG"] = function()
   if not DebugLogFrame then
      CreateDebugLogFrame()
   end
   if DebugLogFrame:IsShown() then
      DebugLogFrame:Hide()
   else
      RefreshDebugLogFrame()
      DebugLogFrame:Show()
   end
end

local debug_print_cache = {}
local debug_string_args = {}
local select = select

local function debug_print(...)
   local n = select('#', ...)
   for i = 1, n do
      debug_string_args[i] = tostring(select(i, ...))
   end
   for i = n + 1, #debug_string_args do
      debug_string_args[i] = nil
   end
   local key = tconcat(debug_string_args, "|")

   local now = GetTime()
   local last_print = debug_print_cache[key]

   if not last_print or (now - last_print) >= 1.5 then
      local message = format("[%.1fs] %s", now, tconcat(debug_string_args, " "))
      AddDebugLogLine(message)
      debug_print_cache[key] = now
   end
end

NS.debug_print = debug_print
NS.AddDebugLogLine = AddDebugLogLine

-- ============================================================================
-- GENERIC UTILITIES
-- ============================================================================
local function round_half(num)
   if not num then return 0 end
   return floor(num * 2 + 0.5) / 2
end

local function safe_ability_cast(ability, icon, target, debug_context)
   if unavailable_spells[ability] then return nil end
   if not ability:IsReady(target) then return nil end
   return ability:Show(icon)
end

-- Pre-allocated Click table for self-targeting (safe for combat use)
local self_target_click = { unit = "player" }

local function safe_self_cast(ability, icon, _target)
   if unavailable_spells[ability] then return nil end
   if not ability:IsReady("player") then return nil end
   ability.Click = self_target_click
   return ability:Show(icon)
end

local function safe_heal_cast(ability, icon, target_unit, log_message)
   if unavailable_spells[ability] then return nil end
   -- IsReady(target_unit) fails for party/raid unit IDs — check on "player" instead.
   if not ability:IsReady("player") then return nil end
   -- Tell HE which unit to target. TMW reads HE.GetTarget() when Show() is called
   -- to inject [@unit,help] into the icon macro.
   local HE = A.HealingEngine
   if HE and HE.SetTarget then HE.SetTarget(target_unit) end
   local result = ability:Show(icon)
   if result then return result, log_message end
   return nil
end

NS.round_half = round_half
NS.safe_ability_cast = safe_ability_cast
NS.safe_self_cast = safe_self_cast
NS.safe_heal_cast = safe_heal_cast

-- ============================================================================
-- CASTING HELPERS
-- ============================================================================
local function try_cast(spell, icon, target, log_message)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(target) then return nil end
   local result = safe_ability_cast(spell, icon, target)
   if result then return result, log_message end
   return nil
end

local function try_cast_fmt(spell, icon, target, prefix, name, info_fmt, ...)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(target) then return nil end
   local result = safe_ability_cast(spell, icon, target)
   if result then
      if info_fmt then
         return result, format("%s %s - " .. info_fmt, prefix, name, ...)
      end
      return result, format("%s %s", prefix, name)
   end
   return nil
end

NS.try_cast = try_cast
NS.try_cast_fmt = try_cast_fmt

-- Healing variants: IsReady("player") + HE.SetTarget for party/raid targeting.
-- scan_healing_targets() already handles range, so "player" check (CD + mana) is sufficient.
local function try_heal_cast(spell, icon, target_unit, log_message)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(PLAYER_UNIT) then return nil end
   local result = safe_heal_cast(spell, icon, target_unit)
   if result then return result, log_message end
   return nil
end

local function try_heal_cast_fmt(spell, icon, target_unit, prefix, name, info_fmt, ...)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(PLAYER_UNIT) then return nil end
   local result = safe_heal_cast(spell, icon, target_unit)
   if result then
      if info_fmt then
         return result, format("%s %s - " .. info_fmt, prefix, name, ...)
      end
      return result, format("%s %s", prefix, name)
   end
   return nil
end

NS.try_heal_cast = try_heal_cast
NS.try_heal_cast_fmt = try_heal_cast_fmt

-- ============================================================================
-- HEAL PREDICTION
-- Estimates effective health deficit accounting for incoming heals, HoTs,
-- absorbs, and incoming damage over a cast-time window.
-- Uses LibHealComm/framework APIs: GetIncomingHeals, GetHEAL, GetDMG, GetAbsorb.
-- ============================================================================
local function predict_effective_deficit(unitID, castTime)
   castTime = castTime or 1.5
   local deficit = Unit(unitID):HealthDeficit() or 0
   if deficit <= 0 then return 0 end

   local inc_heal = Unit(unitID):GetIncomingHeals(castTime) or 0
   local hot_hps = Unit(unitID):GetHEAL() or 0
   local hot_heal = hot_hps * castTime
   local absorb = Unit(unitID):GetAbsorb() or 0
   local inc_dmg_dps = Unit(unitID):GetDMG() or 0
   local inc_dmg = inc_dmg_dps * castTime

   local effective = deficit - inc_heal - hot_heal - absorb + inc_dmg
   return effective > 0 and effective or 0
end

NS.predict_effective_deficit = predict_effective_deficit

-- ============================================================================
-- DEBUFF/BUFF HELPERS
-- ============================================================================
local function is_debuff_active(spell, target, source)
   if not _G.UnitExists(target) then return false end
   return (Unit(target):HasDeBuffs(spell.ID, source) or 0) > 0
end

local function get_debuff_state(spell, target, source)
   if not _G.UnitExists(target) then return 0, 0 end
   return Unit(target):HasDeBuffsStacks(spell.ID, source) or 0,
          Unit(target):HasDeBuffs(spell.ID, source) or 0
end

local function is_buff_active(spell, target, source)
   if not _G.UnitExists(target) then return false end
   return (Unit(target):HasBuffs(spell.ID, source) or 0) > 0
end

NS.is_debuff_active = is_debuff_active
NS.get_debuff_state = get_debuff_state
NS.is_buff_active = is_buff_active

-- ============================================================================
-- SWING TIMER UTILITIES
-- ============================================================================
local function is_swing_landing_soon(threshold)
   threshold = threshold or 0.15
   local swing_start = Player:GetSwingStart(1)
   local swing_duration = Player:GetSwing(1)
   if swing_start == 0 or swing_duration == 0 then return false end
   local swing_end = swing_start + swing_duration
   local time_until_swing = swing_end - _G.GetTime()
   return time_until_swing > 0 and time_until_swing <= threshold
end

local function get_time_until_swing()
   local swing_start = Player:GetSwingStart(1)
   local swing_duration = Player:GetSwing(1)
   if swing_start == 0 or swing_duration == 0 then return 0 end
   local remaining = (swing_start + swing_duration) - _G.GetTime()
   return remaining > 0 and remaining or 0
end

NS.is_swing_landing_soon = is_swing_landing_soon
NS.get_time_until_swing = get_time_until_swing

-- ============================================================================
-- COMBAT UTILITIES
-- ============================================================================
local function get_time_to_die(unit_id)
   unit_id = unit_id or TARGET_UNIT
   if not _G.UnitExists(unit_id) then return 500 end
   return Unit(unit_id):TimeToDie()
end

NS.get_time_to_die = get_time_to_die

-- ============================================================================
-- BURST CONTEXT SYSTEM
-- ============================================================================
-- Pre-allocated Bloodlust/Heroism buff IDs for detection
local BLOODLUST_IDS = { 2825, 32182 }

--- Check if auto-burst conditions are met (schema-driven).
-- Returns true if ANY enabled burst condition is satisfied.
local function should_auto_burst(context)
   local s = context.settings
   if not s then return nil end

   -- If no burst conditions are configured, return nil (CDs fire freely)
   local any_configured = s.burst_in_combat or s.burst_on_pull or s.burst_on_execute or s.burst_on_bloodlust
   if not any_configured then return nil end

   -- At least one condition is configured; must be in combat with a target
   if not context.in_combat then return false end
   if not context.has_valid_enemy_target then return false end

   if s.burst_in_combat then return true end
   if s.burst_on_pull and context.combat_time and context.combat_time < 5 then return true end
   if s.burst_on_execute and context.target_hp and context.target_hp < 20 then return true end
   if s.burst_on_bloodlust and (Unit(PLAYER_UNIT):HasBuffs(BLOODLUST_IDS) or 0) > 0 then return true end

   return false  -- conditions configured but none met
end

NS.should_auto_burst = should_auto_burst

-- ============================================================================
-- ROTATION REGISTRY INFRASTRUCTURE
-- ============================================================================
local function priority_desc_comparator(a, b)
   return a.priority > b.priority
end

local rotation_registry = {
   middleware = {},
   strategy_maps = {},   -- populated by register_class()
   playstyle_config = {},
   class_config = nil,   -- set by register_class()
}

function rotation_registry:register_class(config)
   self.class_config = config
   for _, ps in ipairs(config.playstyles) do
      self.strategy_maps[ps] = self.strategy_maps[ps] or {}
   end
end

local last_validated_playstyle = nil

function rotation_registry:validate_playstyle_spells(playstyle)
   if playstyle == last_validated_playstyle then return end
   last_validated_playstyle = playstyle

   for k in pairs(unavailable_spells) do
      unavailable_spells[k] = nil
   end

   local cc = self.class_config
   if not cc or not cc.playstyle_spells then return end

   local entries = cc.playstyle_spells[playstyle]
   if not entries then return end

   local missing_spells = {}
   local optional_missing = {}

   check_spell_availability(entries, missing_spells, optional_missing)

   if cc.validate_playstyle_extra then
      cc.validate_playstyle_extra(playstyle, missing_spells, optional_missing)
   end

   local label = (cc.playstyle_labels and cc.playstyle_labels[playstyle]) or playstyle
   print("|cFF00FF00[Flux AIO]|r Switched to " .. label .. " playstyle")

   if #missing_spells > 0 then
      print("|cFFFF0000[Flux AIO]|r MISSING REQUIRED SPELLS:")
      for _, spell_name in ipairs(missing_spells) do
         print("|cFFFF0000[Flux AIO]|r   - " .. spell_name)
      end
   end

   if #optional_missing > 0 then
      print("|cFFFF8800[Flux AIO]|r Optional spells not available (will be skipped):")
      for _, spell_name in ipairs(optional_missing) do
         print("|cFFFF8800[Flux AIO]|r   - " .. spell_name)
      end
   end

   if #missing_spells == 0 and #optional_missing == 0 then
      print("|cFF00FF00[Flux AIO]|r All spells available!")
   end
end

function rotation_registry:register(playstyle, strategies, config)
   local map = self.strategy_maps[playstyle]
   if not map then
      print("|cFFFF0000[Flux AIO]|r ERROR: Unknown playstyle: " .. tostring(playstyle))
      return
   end

   if config then
      self.playstyle_config[playstyle] = config
   end

   local is_array = strategies[1] ~= nil and strategies.name == nil and strategies.matches == nil

   if is_array then
      for i, strategy in ipairs(strategies) do
         strategy.priority = 1000 - i
         strategy.name = strategy.name or (playstyle .. "_" .. i)
         map[#map + 1] = strategy
      end
   else
      strategies.priority = strategies.priority or 50
      map[#map + 1] = strategies
   end

   tsort(map, priority_desc_comparator)
end

function rotation_registry:register_middleware(middleware)
   if not middleware.priority then
      middleware.priority = 100
   end

   self.middleware[#self.middleware + 1] = middleware
   tsort(self.middleware, priority_desc_comparator)
end

function rotation_registry:check_prerequisites(strategy, context)
   if strategy.requires_combat ~= nil and strategy.requires_combat ~= context.in_combat then return false end
   if strategy.requires_enemy ~= nil and strategy.requires_enemy ~= context.has_valid_enemy_target then return false end
   if strategy.requires_in_range ~= nil and strategy.requires_in_range ~= context.in_melee_range then return false end
   if strategy.requires_phys_immune ~= nil and strategy.requires_phys_immune ~= context.target_phys_immune then return false end
   if strategy.setting_key and not context.settings[strategy.setting_key] then return false end
   if strategy.spell then
      if unavailable_spells[strategy.spell] then return false end
      local target = strategy.spell_target or TARGET_UNIT
      if not strategy.spell:IsReady(target) then return false end
   end
   return true
end

function rotation_registry:get_playstyle_state(playstyle, context)
   local config = self.playstyle_config[playstyle]
   if config and config.context_builder then
      return config.context_builder(context)
   end
   return nil
end

NS.rotation_registry = rotation_registry

-- ============================================================================
-- STRATEGY FACTORY FUNCTIONS
-- ============================================================================

--- Factory for simple combat strategies (single spell, standard checks)
local function create_combat_strategy(config)
   local spell = config.spell
   local target = config.target or TARGET_UNIT
   local stance = config.stance
   local prefix = config.prefix or "[P?]"
   local log_name = config.log_name or config.name

   return {
      matches = function(context)
         if stance and context.stance ~= stance then return false end
         if not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if config.setting_key and context.settings[config.setting_key] == false then return false end
         if config.extra_match and not config.extra_match(context) then return false end
         return spell:IsReady(target)
      end,
      execute = function(icon, context)
         if config.log_fmt and config.log_args then
            return try_cast_fmt(spell, icon, target, prefix, log_name, config.log_fmt, config.log_args(context))
         end
         return try_cast(spell, icon, target, format("%s %s", prefix, log_name))
      end,
   }
end

--- Name wrapper: sets strategy.name at registration site
local function named(n, s) s.name = n; return s end

NS.create_combat_strategy = create_combat_strategy
NS.named = named

-- ============================================================================
-- TRINKET MIDDLEWARE FACTORY
-- ============================================================================
-- Called from each class's middleware.lua after NS.A is available.
-- Uses the framework's auto-created A.Trinket1/A.Trinket2 (TrinketBySlot)
-- directly — same pattern as Triptastic's working implementation.
-- IMPORTANT: class.lua must NOT Create({ Type = "Trinket" }) as that
-- overwrites the framework's proper TrinketBySlot versions.

local DEFENSIVE_TRINKET_HP = 35
local PLAYER_UNIT = "player"

local function register_trinket_middleware()
   local A_class = NS.A
   if not A_class then
      print("|cFFFF6600[Flux Trinket]|r Factory skipped: NS.A not available")
      return
   end

   local Trinket1 = A_class.Trinket1
   local Trinket2 = A_class.Trinket2

   if not Trinket1 and not Trinket2 then
      print("|cFFFF6600[Flux Trinket]|r No framework trinkets found (A.Trinket1/A.Trinket2)")
      return
   end

   -- Offensive trinkets: fire during burst windows or /flux burst
   rotation_registry:register_middleware({
      name = "Trinkets_Burst",
      priority = 80,
      is_burst = true,
      is_gcd_gated = false,

      matches = function(context)
         if not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if not should_auto_burst(context) then return false end
         -- TTD gate: skip trinkets on dying mobs (cd_min_ttd setting; 0 = disabled)
         local min_ttd = context.settings.cd_min_ttd or 0
         if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
         local s = context.settings
         if s.trinket1_mode == "offensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then return true end
         if s.trinket2_mode == "offensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then return true end
         return false
      end,

      execute = function(icon, context)
         local s = context.settings
         if s.trinket1_mode == "offensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then
            return Trinket1:Show(icon), "[MW] Trinket 1 (Burst)"
         end
         if s.trinket2_mode == "offensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then
            return Trinket2:Show(icon), "[MW] Trinket 2 (Burst)"
         end
         return nil
      end,
   })

   -- Defensive trinkets: fire at low HP or /flux def
   rotation_registry:register_middleware({
      name = "Trinkets_Defensive",
      priority = 290,
      is_defensive = true,
      is_gcd_gated = false,

      matches = function(context)
         if not context.in_combat then return false end
         if context.hp > DEFENSIVE_TRINKET_HP then return false end
         local s = context.settings
         if s.trinket1_mode == "defensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then return true end
         if s.trinket2_mode == "defensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then return true end
         return false
      end,

      execute = function(icon, context)
         local s = context.settings
         if s.trinket1_mode == "defensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then
            return Trinket1:Show(icon), "[MW] Trinket 1 (Defensive)"
         end
         if s.trinket2_mode == "defensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then
            return Trinket2:Show(icon), "[MW] Trinket 2 (Defensive)"
         end
         return nil
      end,
   })

   print("|cFF00FF00[Flux Trinket]|r Middleware registered")
end

NS.register_trinket_middleware = register_trinket_middleware

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Core]|r Module loaded")
