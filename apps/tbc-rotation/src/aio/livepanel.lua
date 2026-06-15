-- Menagerie - Live Panel Factory
-- Reusable diagnostic-panel engine: a framed window whose layout is built once and
-- only RE-laid-out when its structure changes, while per-frame refreshes update only
-- the value cells. Extracted from the shared debug panel so both it and class panels
-- (e.g. Hunter's adaptive panel) are thin instances.
--
-- Contract:
--   NS.CreateLivePanel(opts) -> panel
--   opts = {
--     title,                      -- window title
--     setting_key,                -- NS.cached_settings flag that shows/hides it
--     width            = 240,
--     refresh_interval = 0.1,     -- seconds; one shared ~10Hz default
--     build(out, ctx),            -- REQUIRED: the only thing an instance writes
--     section_bands    = false,   -- draw a tinted band behind each header
--     manual_toggle    = false,   -- true: setting is permission only, visibility via panel:Toggle()
--                                 -- false: setting drives visibility directly
--     get_context      = fn,      -- optional -> value passed to build/export as ctx
--     export(ctx)      = csv,     -- optional -> Export btn (uses NS.ShowCopyWindow)
--     export_title,               -- optional copy-window title (defaults to `title`)
--     on_clear()       = fn,      -- optional -> Clear btn
--     hint,                       -- optional bottom-left hint text
--     anchor           = {point, relPoint, x, y},  -- initial position
--     label_width, value_x, line_h, header_top_pad, content_top, bottom_pad,
--     min_height, width          -- geometry overrides
--   }
--
-- `out` writer (identical surface to the legacy debug panel, plus :spacer):
--   out:header(text)              -- section header line (+ band if section_bands)
--   out:kv(label, value, color)   -- label + value row; color = nil | "dim" | "RRGGBB" | {r,g,b}
--   out:line(text)                -- full-width line
--   out:spacer(px)                -- vertical gap (px, default 5)
--
-- Layout depends ONLY on the sequence of (kind, spacer amount) — never on text —
-- so a stable structure (the common case) re-anchors zero widgets per frame; only the
-- value cells are rewritten. The frame auto-heights from the laid-out content.

local _G = _G
local NS = _G.Menagerie
if not NS then return end

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local max = math.max
local tonumber = tonumber
local tostring = tostring
local type = type
local sub = string.sub

local DBG_THEME = NS.DBG_THEME or NS.Theme
local CreateDebugWindow = NS.CreateDebugWindow
local CreateDebugButton = NS.CreateDebugButton
if not (DBG_THEME and CreateDebugWindow) then return end

local TOGGLE_CHECK_INTERVAL = 0.5

function NS.CreateLivePanel(opts)
   opts = opts or {}
   local build = opts.build
   if type(build) ~= "function" then
      return nil
   end

   -- Geometry (debug-panel defaults; instances override per-opts).
   local title = opts.title or "Menagerie"
   local setting_key = opts.setting_key
   local width = opts.width or 260
   local left_pad = opts.left_pad or 12
   local label_w = opts.label_width or 82
   local value_x = opts.value_x or (left_pad + label_w + 8)
   local line_h = opts.line_h or 14
   local header_top_pad = opts.header_top_pad or 5
   local content_top = opts.content_top or -40
   local bottom_pad = opts.bottom_pad or 28
   local min_height = opts.min_height or 96
   local refresh_interval = opts.refresh_interval or 0.1
   local section_bands = opts.section_bands == true
   local manual_toggle = opts.manual_toggle == true
   local get_context = opts.get_context
   local export_fn = opts.export
   local export_title = opts.export_title or title
   local on_clear = opts.on_clear

   -- Per-panel state (closure-private — each panel is fully isolated).
   local panel = {}
   local frame
   local visible = false
   local entries = {}
   local entry_count = 0
   local rows = {}
   local sig = {}
   local sig_count = 0

   ----------------------------------------------------------------------------
   -- out writer
   ----------------------------------------------------------------------------
   local out = {}

   local function alloc_entry()
      entry_count = entry_count + 1
      local e = entries[entry_count]
      if not e then
         e = {}
         entries[entry_count] = e
      end
      return e
   end

   function out:header(text)
      local e = alloc_entry()
      e.kind = "header"
      e.text = text or ""
      e.label = nil
      e.value = nil
      e.color = nil
      e.amount = nil
   end

   function out:kv(label, value, color)
      local e = alloc_entry()
      e.kind = "kv"
      e.label = label or ""
      e.value = value == nil and "" or tostring(value)
      e.text = nil
      e.color = color
      e.amount = nil
   end

   function out:line(text)
      local e = alloc_entry()
      e.kind = "line"
      e.text = text or ""
      e.label = nil
      e.value = nil
      e.color = nil
      e.amount = nil
   end

   function out:spacer(px)
      local e = alloc_entry()
      e.kind = "spacer"
      e.amount = px or 5
      e.text = nil
      e.label = nil
      e.value = nil
      e.color = nil
   end

   ----------------------------------------------------------------------------
   -- value coloring
   ----------------------------------------------------------------------------
   local function apply_color(fs, color)
      if color == nil then
         fs:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
      elseif color == "dim" then
         fs:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
      elseif type(color) == "table" then
         fs:SetTextColor(color[1], color[2], color[3])
      elseif type(color) == "string" and #color == 6 then
         local r = tonumber(sub(color, 1, 2), 16)
         local g = tonumber(sub(color, 3, 4), 16)
         local b = tonumber(sub(color, 5, 6), 16)
         if r and g and b then
            fs:SetTextColor(r / 255, g / 255, b / 255)
         else
            fs:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
         end
      else
         fs:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
      end
   end

   ----------------------------------------------------------------------------
   -- row widget pool
   ----------------------------------------------------------------------------
   local function ensure_row(index)
      local row = rows[index]
      if row then return row end
      row = {}

      row.line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.line:SetJustifyH("LEFT")
      if row.line.SetWordWrap then row.line:SetWordWrap(false) end

      row.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.label:SetJustifyH("LEFT")
      row.label:SetWidth(label_w)
      if row.label.SetWordWrap then row.label:SetWordWrap(false) end

      row.value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      row.value:SetJustifyH("LEFT")
      if row.value.SetWordWrap then row.value:SetWordWrap(false) end

      if section_bands then
         row.band = frame:CreateTexture(nil, "ARTWORK")
         row.band:SetColorTexture(DBG_THEME.bg_light[1], DBG_THEME.bg_light[2], DBG_THEME.bg_light[3], 0.88)
         row.band:Hide()
      end

      rows[index] = row
      return row
   end

   ----------------------------------------------------------------------------
   -- structure-change detection (layout depends only on kind + spacer amount)
   ----------------------------------------------------------------------------
   local function structure_changed()
      if entry_count ~= sig_count then return true end
      for i = 1, entry_count do
         local e = entries[i]
         local s = sig[i]
         if not s or s.kind ~= e.kind or s.amount ~= e.amount then
            return true
         end
      end
      return false
   end

   local function record_structure()
      for i = 1, entry_count do
         local s = sig[i]
         if not s then
            s = {}
            sig[i] = s
         end
         s.kind = entries[i].kind
         s.amount = entries[i].amount
      end
      sig_count = entry_count
   end

   ----------------------------------------------------------------------------
   -- layout (anchors + show/hide + static text + height) — only on structural change
   ----------------------------------------------------------------------------
   local function layout()
      local y = content_top
      for i = 1, entry_count do
         local e = entries[i]
         local row = ensure_row(i)

         if e.kind == "spacer" then
            row.line:Hide()
            row.label:Hide()
            row.value:Hide()
            if row.band then row.band:Hide() end
            y = y - e.amount
         elseif e.kind == "kv" then
            row.line:Hide()
            if row.band then row.band:Hide() end

            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", frame, "TOPLEFT", left_pad, y)
            row.label:SetText(e.label)
            row.label:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
            row.label:Show()

            row.value:ClearAllPoints()
            row.value:SetPoint("TOPLEFT", frame, "TOPLEFT", value_x, y)
            row.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -left_pad, y)
            row.value:Show()

            y = y - line_h
         else -- header / line
            row.label:Hide()
            row.value:Hide()

            if e.kind == "header" and i > 1 then
               y = y - header_top_pad
            end

            if row.band then
               if e.kind == "header" then
                  row.band:ClearAllPoints()
                  row.band:SetPoint("TOPLEFT", frame, "TOPLEFT", left_pad - 4, y + 2)
                  row.band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(left_pad - 4), y + 2)
                  row.band:SetHeight(line_h)
                  row.band:Show()
               else
                  row.band:Hide()
               end
            end

            row.line:ClearAllPoints()
            row.line:SetPoint("TOPLEFT", frame, "TOPLEFT", left_pad, y)
            row.line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -left_pad, y)
            row.line:SetText(e.text)
            if e.kind == "header" then
               row.line:SetTextColor(DBG_THEME.accent[1], DBG_THEME.accent[2], DBG_THEME.accent[3])
            else
               row.line:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
            end
            row.line:Show()

            y = y - line_h
         end
      end

      -- Hide any leftover pooled rows from a previously larger structure.
      for i = entry_count + 1, #rows do
         local row = rows[i]
         row.line:Hide()
         row.label:Hide()
         row.value:Hide()
         if row.band then row.band:Hide() end
      end

      frame:SetHeight(max(min_height, -y + bottom_pad))
   end

   ----------------------------------------------------------------------------
   -- per-frame value update (cheap: only kv value cells)
   ----------------------------------------------------------------------------
   local function update_values()
      for i = 1, entry_count do
         local e = entries[i]
         if e.kind == "kv" then
            local row = rows[i]
            row.value:SetText(e.value)
            apply_color(row.value, e.color)
         end
      end
   end

   ----------------------------------------------------------------------------
   -- refresh
   ----------------------------------------------------------------------------
   local function refresh()
      if not (frame and frame:IsShown()) then return end
      entry_count = 0
      local ctx = get_context and get_context() or nil
      build(out, ctx)
      if structure_changed() then
         layout()
         record_structure()
      end
      update_values()
   end
   panel.Refresh = refresh

   ----------------------------------------------------------------------------
   -- frame construction
   ----------------------------------------------------------------------------
   local function create_frame()
      if frame then return frame end

      frame = CreateDebugWindow(title)
      frame:ClearAllPoints()
      local a = opts.anchor
      if a then
         frame:SetPoint(a[1] or "TOPLEFT", UIParent, a[2] or a[1] or "TOPLEFT", a[3] or 0, a[4] or 0)
      else
         frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -140)
      end
      frame:SetSize(width, min_height)
      frame:SetFrameStrata("HIGH")
      frame.closeBtn:SetScript("OnClick", function() panel:Hide() end)

      local anchor_btn = frame.closeBtn
      if export_fn and CreateDebugButton then
         local export_btn = CreateDebugButton(frame, "Export", 60)
         export_btn:SetHeight(20)
         export_btn:SetPoint("TOPRIGHT", anchor_btn, "TOPLEFT", -6, 0)
         export_btn:SetScript("OnClick", function()
            local ctx = get_context and get_context() or nil
            local text = export_fn(ctx) or ""
            if NS.ShowCopyWindow then NS.ShowCopyWindow(export_title, text) end
         end)
         anchor_btn = export_btn
      end
      if on_clear and CreateDebugButton then
         local clear_btn = CreateDebugButton(frame, "Clear", 48)
         clear_btn:SetHeight(20)
         clear_btn:SetPoint("TOPRIGHT", anchor_btn, "TOPLEFT", -6, 0)
         clear_btn:SetScript("OnClick", function()
            on_clear()
            refresh()
         end)
      end

      if opts.hint then
         local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
         hint:SetPoint("BOTTOMLEFT", left_pad, 8)
         hint:SetText(opts.hint)
         hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])
      end

      frame:Hide()
      panel.frame = frame
      return frame
   end

   ----------------------------------------------------------------------------
   -- visibility
   ----------------------------------------------------------------------------
   function panel:Show()
      create_frame()
      visible = true
      frame:Show()
      refresh()
   end

   function panel:Hide()
      if frame then frame:Hide() end
      visible = false
   end

   function panel:IsShown()
      return visible and frame and frame:IsShown() or false
   end

   function panel:Toggle()
      if self:IsShown() then self:Hide() else self:Show() end
   end

   local function setting_on()
      return setting_key and NS.cached_settings and NS.cached_settings[setting_key] or false
   end

   ----------------------------------------------------------------------------
   -- single loop: toggle-watch (0.5Hz) + refresh (refresh_interval)
   ----------------------------------------------------------------------------
   local loop = CreateFrame("Frame")
   loop.refresh_elapsed = 0
   loop.toggle_elapsed = 0
   loop:SetScript("OnUpdate", function(self, elapsed)
      self.toggle_elapsed = self.toggle_elapsed + elapsed
      if self.toggle_elapsed >= TOGGLE_CHECK_INTERVAL then
         self.toggle_elapsed = 0
         local want = setting_on()
         if manual_toggle then
            -- Setting is a permission gate: auto-hide if it goes off, never auto-show.
            if not want and visible then panel:Hide() end
         else
            if want and not visible then
               panel:Show()
            elseif not want and visible then
               panel:Hide()
            end
         end
      end
      if visible then
         self.refresh_elapsed = self.refresh_elapsed + elapsed
         if self.refresh_elapsed >= refresh_interval then
            self.refresh_elapsed = 0
            refresh()
         end
      end
   end)

   return panel
end
