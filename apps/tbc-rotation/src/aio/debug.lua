-- Menagerie - Debug Module
-- Shared debug/diagnostic substrate and log window.

local _G, pairs, tostring = _G, pairs, tostring
local tinsert, tconcat = table.insert, table.concat
local floor = math.floor
local format = string.format
local strmatch = string.match
local GetTime = _G.GetTime

local NS = _G.Menagerie
if not NS then return end

-- ============================================================================
-- DEBUG SYSTEM
-- ============================================================================
local DebugLogFrame
local debug_log_lines = {}
local MAX_LOG_LINES = 500
local ROW_H = 12
local DBG_ROW_PAD = 4
local DBG_TIME_W = 72
local DBG_SRC_W = 86
local DBG_KIND_W = 44
local DBG_COL_GAP = 6
local MSG_TRUNC_W = 120
local DBG_TOOLTIP_WRAP = 96

local DBG_THEME = NS.Theme
if not DBG_THEME then return end
-- Reuse the one canonical thin backdrop from NS.Widgets (loaded at order 1).
local DBG_BACKDROP = NS.Widgets.BACKDROP_THIN
NS.DBG_THEME = DBG_THEME
NS.DBG_BACKDROP = DBG_BACKDROP

-- Looked up by LAYER for the src cell, and by forced for message tint.
local DBG_CAT = {
   forced = { 1.00, 0.62, 0.22 },  -- orange
   ctx    = { 0.58, 0.58, 0.659 }, -- SYS / plumbing
   mw     = { 0.42, 0.82, 0.95 },  -- middleware
   action = { 0.86, 0.86, 0.894 }, -- STRAT / playstyle action lines
}

local FauxScrollFrame_Update = _G.FauxScrollFrame_Update
local FauxScrollFrame_OnVerticalScroll = _G.FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_GetOffset = _G.FauxScrollFrame_GetOffset
local FauxScrollFrame_SetOffset = _G.FauxScrollFrame_SetOffset

local function debug_layer(src)
   local layer = src and strmatch(src, "^([^:]+)") or nil
   if layer == "MW" then return "mw" end
   if layer == "STRAT" then return "action" end
   return "ctx"
end

local function debug_src_color(src)
   return DBG_CAT[debug_layer(src)] or DBG_CAT.ctx
end

local function utf8_safe_prefix(text, limit)
   if #text <= limit then return text end
   while limit > 0 do
      local byte = string.byte(text, limit)
      if not byte then return "" end
      if byte < 128 then
         return string.sub(text, 1, limit)
      end
      if byte >= 194 then
         return string.sub(text, 1, limit - 1)
      end
      limit = limit - 1
   end
   return ""
end

local function debug_truncate_text(text, width)
   text = text or ""
   local max_chars = math.max(16, floor((width or MSG_TRUNC_W) / 5))
   if #text <= max_chars then return text end
   return utf8_safe_prefix(text, max_chars - 3) .. "..."
end

local function add_wrapped_tooltip_line(text, r, g, b)
   text = tostring(text or "")
   local start = 1
   while start <= #text do
      local line_end = string.find(text, "\n", start, true)
      local line
      if line_end then
         line = string.sub(text, start, line_end - 1)
         start = line_end + 1
      else
         line = string.sub(text, start)
         start = #text + 1
      end

      while #line > DBG_TOOLTIP_WRAP do
         local cut = DBG_TOOLTIP_WRAP
         for i = DBG_TOOLTIP_WRAP, 1, -1 do
            if string.sub(line, i, i) == " " then
               cut = i
               break
            end
         end
         GameTooltip:AddLine(string.sub(line, 1, cut), r, g, b, true)
         line = string.sub(line, cut + 1)
      end
      GameTooltip:AddLine(line, r, g, b, true)
   end
end

-- Split `text` on a literal separator into an array of the pieces between it.
local function split_on(text, sep)
   local parts, start, sep_len = {}, 1, #sep
   while true do
      local i = string.find(text, sep, start, true)
      if not i then
         parts[#parts + 1] = string.sub(text, start)
         return parts
      end
      parts[#parts + 1] = string.sub(text, start, i - 1)
      start = i + sep_len
   end
end

-- A section "looks like" key=value tokens when (almost) every whitespace token
-- contains an '='. One stray label token is tolerated; anything looser is treated
-- as free text and rendered as a wrapped paragraph instead.
local function section_is_kv(section)
   local total, kv = 0, 0
   for token in string.gmatch(section, "%S+") do
      total = total + 1
      if string.find(token, "=", 1, true) then kv = kv + 1 end
   end
   return total > 0 and kv >= total - 1
end

-- Render a class context blob as aligned key -> value rows instead of one wrapped
-- paragraph. The blob convention (see e.g. druid bear's format_context_log) is
-- " | "-separated sections of space-separated `key=value` tokens; sections render
-- as grouped rows separated by a blank line. A formatter that emits free text
-- falls back to a wrapped line per section, so nothing renders worse than before.
local function add_structured_ctx_tooltip(ctx_text)
   local kr, kg, kb = DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3]
   local vr, vg, vb = DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3]
   local sections = split_on(ctx_text, " | ")
   for si = 1, #sections do
      local section = sections[si]
      if si > 1 then GameTooltip:AddLine(" ") end
      if section_is_kv(section) then
         for token in string.gmatch(section, "%S+") do
            local key, value = string.match(token, "^([^=]+)=(.+)$")
            if key then
               GameTooltip:AddDoubleLine(key, value, kr, kg, kb, vr, vg, vb)
            else
               add_wrapped_tooltip_line(token, kr, kg, kb)
            end
         end
      else
         add_wrapped_tooltip_line(section, kr, kg, kb)
      end
   end
end

-- Thin wrapper over the shared widget so the (width, height=22, GameFontHighlight)
-- debug-button signature and the NS.CreateDebugButton export stay byte-stable.
local function create_debug_button(parent, text, width)
   return NS.Widgets.themed_button(parent, { width = width, text = text, theme = DBG_THEME })
end
NS.CreateDebugButton = create_debug_button

local function CreateDebugWindow(title_text)
   local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
   f:SetSize(320, 240)
   f:SetPoint("TOPLEFT", 50, -100)
   f:SetBackdrop(DBG_BACKDROP)
   f:SetBackdropColor(DBG_THEME.bg[1], DBG_THEME.bg[2], DBG_THEME.bg[3], 0.75)
   f:SetBackdropBorderColor(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
   f:SetMovable(true)
   f:SetResizable(true)
   f:EnableMouse(true)
   f:SetClampedToScreen(true)
   f:RegisterForDrag("LeftButton")
   f:SetScript("OnDragStart", f.StartMoving)
   f:SetScript("OnDragStop", f.StopMovingOrSizing)

   local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
   title:SetPoint("TOPLEFT", 12, -8)
   title:SetText(title_text or "Menagerie Debug")
   title:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])
   f.title = title

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
   f.closeBtn = closeBtn

   local sep = f:CreateTexture(nil, "ARTWORK")
   sep:SetPoint("TOPLEFT", 1, -28)
   sep:SetPoint("TOPRIGHT", -1, -28)
   sep:SetHeight(1)
   sep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
   f.separator = sep

   NS.Widgets.make_toplevel(f)
   return f
end
NS.CreateDebugWindow = CreateDebugWindow

local CopyWindowFrame
local function CreateCopyWindow()
   if CopyWindowFrame then return CopyWindowFrame end

   local f = CreateDebugWindow("Export")
   f:SetSize(760, 460)
   f:ClearAllPoints()
   f:SetPoint("CENTER")
   f:SetFrameStrata("DIALOG")

   local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   hint:SetPoint("TOPRIGHT", -12, -12)
   hint:SetText("Ctrl+C to copy")
   hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
   f.copyHint = hint

   local scrollframe = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
   scrollframe:SetPoint("TOPLEFT", 10, -34)
   scrollframe:SetPoint("BOTTOMRIGHT", -30, 42)
   f.copyScrollFrame = scrollframe

   local editBox = CreateFrame("EditBox", nil, scrollframe)
   editBox:SetMultiLine(true)
   editBox:SetFontObject("ChatFontNormal")
   editBox:SetWidth(700)
   editBox:SetAutoFocus(false)
   editBox:SetScript("OnEscapePressed", function() f:Hide() end)
   scrollframe:SetScrollChild(editBox)
   f.editBox = editBox

   local bottom_sep = f:CreateTexture(nil, "ARTWORK")
   bottom_sep:SetPoint("BOTTOMLEFT", 1, 36)
   bottom_sep:SetPoint("BOTTOMRIGHT", -1, 36)
   bottom_sep:SetHeight(1)
   bottom_sep:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 1)
   f.copyBottomSeparator = bottom_sep

   local close = create_debug_button(f, "Close", 100)
   close:SetPoint("BOTTOM", 0, 8)
   close:SetScript("OnClick", function() f:Hide() end)
   f.copyCloseButton = close

   CopyWindowFrame = f
   return f
end

function NS.ShowCopyWindow(title, text)
   local f = CreateCopyWindow()
   f.title:SetText(title or "Export")
   f.editBox:SetText(text or "")
   f.editBox:HighlightText()
   f.editBox:SetFocus()
   f:Show()
   return f
end

local function CreateDebugLogFrame()
   if DebugLogFrame then return DebugLogFrame end

   local f = CreateDebugWindow("Menagerie Debug Log")
   f:SetSize(500, 300)
   f:ClearAllPoints()
   f:SetPoint("TOPLEFT", 50, -100)

   local scrollframe = CreateFrame("ScrollFrame", "MenagerieDebugScrollFrame", f, "FauxScrollFrameTemplate")
   scrollframe:SetPoint("TOPLEFT", 10, -34)
   scrollframe:SetPoint("BOTTOMRIGHT", -28, 30)
   scrollframe:EnableMouseWheel(true)
   f.scrollframe = scrollframe

   local rowHost = CreateFrame("Frame", nil, f)
   rowHost:SetPoint("TOPLEFT", scrollframe, "TOPLEFT", 0, 0)
   rowHost:SetPoint("BOTTOMRIGHT", scrollframe, "BOTTOMRIGHT", -2, 0)
   f.rowHost = rowHost
   f.rows = {}
   f.numToDisplay = 1
   f.msgWidth = MSG_TRUNC_W

   local scrollbar = _G.MenagerieDebugScrollFrameScrollBar
   f.scrollbar = scrollbar

   if scrollbar then
      local track = scrollbar:CreateTexture(nil, "BACKGROUND")
      track:SetAllPoints()
      track:SetColorTexture(DBG_THEME.bg_widget[1], DBG_THEME.bg_widget[2], DBG_THEME.bg_widget[3], 0.6)
      scrollbar.track = track

      if scrollbar.GetThumbTexture then
         local thumb = scrollbar:GetThumbTexture()
         if thumb and thumb.SetColorTexture then
            thumb:SetColorTexture(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 0.85)
         elseif thumb and thumb.SetVertexColor then
            thumb:SetVertexColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 0.85)
         end
      end

      local function tint_scroll_button(btn)
         if not (btn and btn.GetNormalTexture) then return end
         local normal = btn:GetNormalTexture()
         if normal and normal.SetVertexColor then
            normal:SetVertexColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3], 0.85)
         end
      end
      tint_scroll_button(_G.MenagerieDebugScrollFrameScrollBarScrollUpButton)
      tint_scroll_button(_G.MenagerieDebugScrollFrameScrollBarScrollDownButton)
   end

   local function current_offset()
      if FauxScrollFrame_GetOffset then
         return FauxScrollFrame_GetOffset(scrollframe) or 0
      end
      return scrollframe.offset or 0
   end

   local function set_offset(offset)
      offset = math.max(0, floor(offset or 0))
      local scroll_value = offset * ROW_H
      f.settingLogOffset = true
      if FauxScrollFrame_SetOffset then
         FauxScrollFrame_SetOffset(scrollframe, offset)
      else
         scrollframe.offset = offset
      end
      if scrollbar and scrollbar.SetValue then
         scrollbar:SetValue(scroll_value)
      end
      if scrollframe.SetVerticalScroll then
         scrollframe:SetVerticalScroll(scroll_value)
      end
      f.settingLogOffset = nil
   end

   local function update_scrollbar()
      if FauxScrollFrame_Update then
         FauxScrollFrame_Update(scrollframe, #debug_log_lines, f.numToDisplay, ROW_H)
      end
      if scrollbar then
         if #debug_log_lines <= f.numToDisplay then scrollbar:Hide() else scrollbar:Show() end
      end
   end

   local function configure_font_string(fs, width)
      fs:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
      fs:SetJustifyH("LEFT")
      fs:SetWordWrap(false)
      fs:SetWidth(width)
   end

   local function create_row(index)
      local row = CreateFrame("Frame", nil, rowHost, "BackdropTemplate")
      row:SetHeight(ROW_H)
      row:SetPoint("TOPLEFT", rowHost, "TOPLEFT", 0, -(index - 1) * ROW_H)
      row:SetPoint("TOPRIGHT", rowHost, "TOPRIGHT", 0, -(index - 1) * ROW_H)
      row:EnableMouse(true)
      row:EnableMouseWheel(true)

      local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      timeText:SetPoint("LEFT", DBG_ROW_PAD, 0)
      configure_font_string(timeText, DBG_TIME_W)
      timeText:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
      row.timeText = timeText

      local srcText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      srcText:SetPoint("LEFT", timeText, "RIGHT", DBG_COL_GAP, 0)
      configure_font_string(srcText, DBG_SRC_W)
      row.srcText = srcText

      local kindText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      kindText:SetPoint("LEFT", srcText, "RIGHT", DBG_COL_GAP, 0)
      configure_font_string(kindText, DBG_KIND_W)
      kindText:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
      row.kindText = kindText

      local messageText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      messageText:SetPoint("LEFT", kindText, "RIGHT", DBG_COL_GAP, 0)
      messageText:SetPoint("RIGHT", row, "RIGHT", -DBG_ROW_PAD, 0)
      configure_font_string(messageText, f.msgWidth)
      row.messageText = messageText

      row:SetScript("OnEnter", function(self)
         local entry = debug_log_lines[self.entryIndex or 0]
         if not entry then return end
         GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
         GameTooltip:ClearLines()
         if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(400) end
         GameTooltip:AddLine(format("%s | %s | %s", entry.ts or "", entry.src or "", entry.kind or ""),
            DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
         local msg_color = entry.forced and DBG_CAT.forced or DBG_THEME.text
         add_wrapped_tooltip_line(entry.text, msg_color[1], msg_color[2], msg_color[3])
         if entry.ctx then
            GameTooltip:AddLine(" ")
            add_structured_ctx_tooltip(entry.ctx)
         end
         GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row:SetScript("OnMouseWheel", function(_, delta)
         local on_wheel = scrollframe:GetScript("OnMouseWheel")
         if on_wheel then on_wheel(scrollframe, delta) end
      end)
      row:Hide()
      return row
   end

   local function ensure_rows()
      local needed = f.numToDisplay + 1
      for i = #f.rows + 1, needed do
         f.rows[i] = create_row(i)
      end
      for i = needed + 1, #f.rows do
         f.rows[i]:Hide()
         f.rows[i].entryIndex = nil
      end
   end

   local function update_metrics()
      local height = rowHost:GetHeight() or 0
      local width = rowHost:GetWidth() or 0
      f.numToDisplay = math.max(1, floor(height / ROW_H))
      f.msgWidth = math.max(MSG_TRUNC_W,
         width - (DBG_ROW_PAD * 2) - DBG_TIME_W - DBG_SRC_W - DBG_KIND_W - (DBG_COL_GAP * 3))
      ensure_rows()
      for _, row in ipairs(f.rows) do
         row.messageText:SetWidth(f.msgWidth)
      end
   end

   local function repaint()
      update_metrics()
      update_scrollbar()

      local max_offset = math.max(0, #debug_log_lines - f.numToDisplay)
      local offset = math.min(current_offset(), max_offset)
      set_offset(offset)

      for i, row in ipairs(f.rows) do
         if i <= f.numToDisplay then
            local entry_index = offset + i
            local entry = debug_log_lines[entry_index]
            if entry then
               local src_color = debug_src_color(entry.src)
               local msg_color = entry.forced and DBG_CAT.forced or DBG_THEME.text
               row.entryIndex = entry_index
               row.timeText:SetText(entry.ts or "")
               row.srcText:SetText(entry.src or "")
               row.srcText:SetTextColor(src_color[1], src_color[2], src_color[3])
               row.kindText:SetText(entry.kind or "")
               row.messageText:SetText(debug_truncate_text(entry.text, f.msgWidth))
               row.messageText:SetTextColor(msg_color[1], msg_color[2], msg_color[3])
               row:Show()
            else
               row.entryIndex = nil
               row:Hide()
            end
         else
            row.entryIndex = nil
            row:Hide()
         end
      end
   end

   f.repaint = repaint
   f.setLogOffset = set_offset
   f.getLogOffset = current_offset
   f.updateLogMetrics = update_metrics

   scrollframe:SetScript("OnVerticalScroll", function(self, offset)
      if f.settingLogOffset then return end
      if FauxScrollFrame_OnVerticalScroll then
         FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, repaint)
      else
         set_offset((offset or 0) / ROW_H)
         repaint()
      end
   end)

   scrollframe:SetScript("OnMouseWheel", function(_, delta)
      local max_offset = math.max(0, #debug_log_lines - f.numToDisplay)
      set_offset(math.min(max_offset, math.max(0, current_offset() - (delta * 3))))
      repaint()
   end)

   -- Action buttons live in the bottom toolbar (clear of the close X and resize grip)
   local clearBtn = create_debug_button(f, "Clear", 58)
   clearBtn:SetPoint("BOTTOMRIGHT", -18, 5)

   local copyBtn = create_debug_button(f, "Copy", 58)
   copyBtn:SetPoint("BOTTOMRIGHT", -80, 5)

   -- Copy popup
   local copyPopup = CreateFrame("Frame", "MenagerieCopyPopup", UIParent, "BackdropTemplate")
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
      local copy_lines = {}
      for i = 1, #debug_log_lines do
         local entry = debug_log_lines[i]
         copy_lines[#copy_lines + 1] = format("[%s] [%s] [%s] %s",
            entry.ts or "", entry.src or "", entry.kind or "", entry.text or "")
         if entry.ctx then
            local start = 1
            while start <= #entry.ctx do
               local line_end = string.find(entry.ctx, "\n", start, true)
               if line_end then
                  copy_lines[#copy_lines + 1] = "    " .. string.sub(entry.ctx, start, line_end - 1)
                  start = line_end + 1
               else
                  copy_lines[#copy_lines + 1] = "    " .. string.sub(entry.ctx, start)
                  break
               end
            end
         end
      end
      copyEditBox:SetText(tconcat(copy_lines, "\n"))
      copyPopup:Show()
      copyEditBox:SetFocus()
      copyEditBox:HighlightText()
   end)

   clearBtn:SetScript("OnClick", function()
      for i = 1, #debug_log_lines do debug_log_lines[i] = nil end
      set_offset(0)
      repaint()
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
      repaint()
   end)
   f:SetResizeBounds(300, 150, 800, 600)
   f:SetScript("OnSizeChanged", repaint)

   -- Hint text
   local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
   hint:SetPoint("BOTTOMLEFT", 8, 8)
   hint:SetText("/mlog to toggle")
   hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])

   repaint()
   f:Hide()
   DebugLogFrame = f
   NS.DebugLogFrame = f
   return f
end

local function trim_debug_log()
   local extra = #debug_log_lines - MAX_LOG_LINES
   if extra <= 0 then return end
   for i = 1, MAX_LOG_LINES do
      debug_log_lines[i] = debug_log_lines[i + extra]
   end
   for i = MAX_LOG_LINES + 1, MAX_LOG_LINES + extra do
      debug_log_lines[i] = nil
   end
end

-- Wall-clock timestamp for the debug log. GetTime() (system uptime) is perfect for
-- deltas/throttling but reads like "18130.6s" -- useless as a clock. Show local time
-- of day, with tenths (from GetTime's fractional part) so sub-second cast ordering
-- is still visible.
local function debug_timestamp()
   return date("%H:%M:%S") .. format(".%d", floor((GetTime() * 10) % 10))
end
NS.debug_timestamp = debug_timestamp

local debug_print_cache = {}
local debug_string_args = {}
local DEBUG_CACHE_TTL = 60
local DEBUG_CACHE_PRUNE_INTERVAL = 30
local last_debug_cache_prune = 0
local select = select

local function debug_log(src, kind, forced, fmt, ...)
   if not forced and not (NS.cached_settings and NS.cached_settings.debug_mode) then return nil end

   src = src or "SYS"
   kind = kind or "TRACE"
   local text = select("#", ...) > 0 and format(fmt, ...) or tostring(fmt or "")
   local key = src .. "|" .. kind .. "|" .. text

   local now = GetTime()
   if (now - last_debug_cache_prune) >= DEBUG_CACHE_PRUNE_INTERVAL then
      for cache_key, cache_time in pairs(debug_print_cache) do
         if (now - cache_time) > DEBUG_CACHE_TTL then
            debug_print_cache[cache_key] = nil
         end
      end
      last_debug_cache_prune = now
   end

   local last_print = debug_print_cache[key]
   if last_print and (now - last_print) < 1.5 then
      return nil
   end
   debug_print_cache[key] = now

   local f = DebugLogFrame
   local follow_tail = false
   if f and f:IsShown() and f.updateLogMetrics and f.getLogOffset then
      f.updateLogMetrics()
      local old_max = math.max(0, #debug_log_lines - (f.numToDisplay or 1))
      follow_tail = f.getLogOffset() >= old_max
   end

   local e = {
      ts = debug_timestamp(),
      src = src,
      kind = kind,
      forced = forced or nil,
      text = text,
   }
   tinsert(debug_log_lines, e)
   trim_debug_log()

   if f and f:IsShown() and f.repaint then
      if follow_tail and f.setLogOffset then
         f.setLogOffset(math.max(0, #debug_log_lines - (f.numToDisplay or 1)))
      end
      f.repaint()
   end

   return e
end

local function AddDebugLogLine(text)
   debug_log("SYS", "TRACE", false, "%s", tostring(text or ""))
end

local function RefreshDebugLogFrame()
   local f = DebugLogFrame
   if not f then return end
   if f.updateLogMetrics then f.updateLogMetrics() end
   if f.setLogOffset then
      f.setLogOffset(math.max(0, #debug_log_lines - (f.numToDisplay or 1)))
   end
   if f.repaint then f.repaint() end
end

local function debug_print(...)
   if not (NS.cached_settings and NS.cached_settings.debug_mode) then return end

   local n = select('#', ...)
   for i = 1, n do
      debug_string_args[i] = tostring(select(i, ...))
   end
   for i = n + 1, #debug_string_args do
      debug_string_args[i] = nil
   end
   debug_log("SYS", "TRACE", false, "%s", tconcat(debug_string_args, " "))
end

NS.CreateDebugLogFrame = CreateDebugLogFrame
NS.RefreshDebugLogFrame = RefreshDebugLogFrame
NS.debug_log = debug_log
NS.debug_print = debug_print
NS.AddDebugLogLine = AddDebugLogLine

-- /mlog slash command
SLASH_MENAGERIELOG1 = "/mlog"
SLASH_MENAGERIELOG2 = nil
SlashCmdList["MENAGERIELOG"] = function()
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
