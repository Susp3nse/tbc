-- Menagerie - Widgets
-- Shared low-level UI chrome primitives (backdrop / button / header). No
-- settings, schema, or panel knowledge -- pure chrome consumed by debug.lua,
-- livepanel.lua, settings.lua, dashboard.lua, and class diagnostic panels.
-- Loads at order 1 alongside theme.lua/common.lua; theme colors are read at
-- call-time, not load-time, so there is no load-order dependency on theme.lua
-- executing first.

local _G = _G
local CreateFrame = _G.CreateFrame

local NS = _G.Menagerie
if not NS then return end

-- The one canonical thin backdrop (WHITE8X8, 1px edge). Pre-allocated once at
-- load so no table is built per call. Carries no colors, so it needs no theme.
local BACKDROP_THIN = {
   bgFile = "Interface\\Buttons\\WHITE8X8",
   edgeFile = "Interface\\Buttons\\WHITE8X8",
   edgeSize = 1,
}

-- Themed hover button: a backdrop'd Button with an accent-on-hover border+bg
-- swap. Union of the old create_debug_button / create_theme_button bodies.
--   opts = { width, height = 22, text, font = "GameFontHighlight", theme = NS.Theme }
-- Returns the button; its label FontString is exposed as btn.label.
local function themed_button(parent, opts)
   opts = opts or {}
   local theme = opts.theme or NS.Theme
   local height = opts.height or 22

   local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
   btn:SetSize(opts.width, height)
   btn:SetBackdrop(BACKDROP_THIN)
   btn:SetBackdropColor(theme.bg_widget[1], theme.bg_widget[2], theme.bg_widget[3], 1)
   btn:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)

   local label = btn:CreateFontString(nil, "OVERLAY", opts.font or "GameFontHighlight")
   label:SetPoint("CENTER")
   label:SetText(opts.text)
   label:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
   btn.label = label

   btn:SetScript("OnEnter", function(self)
      self:SetBackdropColor(theme.bg_hover[1], theme.bg_hover[2], theme.bg_hover[3], 1)
      self:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
   end)
   btn:SetScript("OnLeave", function(self)
      self:SetBackdropColor(theme.bg_widget[1], theme.bg_widget[2], theme.bg_widget[3], 1)
      self:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 1)
   end)

   return btn
end

-- Make a draggable top-level window render as a self-contained block instead of
-- interleaving with sibling panels in the same frame strata. SetToplevel(true)
-- lifts the frame's whole frame-level block above its siblings on mouse-down;
-- the OnShow hook does the same the moment it is shown. Without this, two panels
-- sharing a strata draw interleaved by absolute frame level -- one panel's
-- background can end up over another's widgets. As a bonus this is click-to-front
-- for free. frame.Raise is passed as the hook handler directly (HookScript calls
-- handler(self), and Raise takes only self) to avoid a per-frame closure.
local function make_toplevel(frame)
   frame:SetToplevel(true)
   frame:HookScript("OnShow", frame.Raise)
end

-- Themed section-header FontString. The caller owns positioning and any
-- return-y bookkeeping; this just creates, colors (theme.text_header), and sets
-- the text. Returns the FontString.
--   opts = { font = "GameFontNormal", theme = NS.Theme }
local function section_header(parent, text, opts)
   opts = opts or {}
   local theme = opts.theme or NS.Theme
   local hdr = parent:CreateFontString(nil, "OVERLAY", opts.font or "GameFontNormal")
   hdr:SetTextColor(theme.text_header[1], theme.text_header[2], theme.text_header[3])
   hdr:SetText(text)
   return hdr
end

NS.Widgets = {
   BACKDROP_THIN = BACKDROP_THIN,
   themed_button = themed_button,
   section_header = section_header,
   make_toplevel = make_toplevel,
}
