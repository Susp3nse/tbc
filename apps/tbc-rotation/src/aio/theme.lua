-- Menagerie - Theme
-- Shared color palette for addon windows and diagnostic panels.

local _G = _G
local format = string.format
local floor = math.floor

_G.Menagerie = _G.Menagerie or {}
local NS = _G.Menagerie

local DEFAULT_ACCENT = { 0.878, 0.541, 0.235 } -- #e08a3c

-- Curated, warm-harmonized class accents for the shared dark chrome.
local CLASS_ACCENTS = {
   WARRIOR = { 0.78, 0.61, 0.43 },
   PALADIN = { 0.85, 0.55, 0.55 },
   HUNTER = { 0.42, 0.75, 0.35 },
   ROGUE = { 0.88, 0.75, 0.38 },
   PRIEST = { 0.85, 0.79, 0.69 },
   SHAMAN = { 0.31, 0.61, 0.77 },
   MAGE = { 0.31, 0.70, 0.77 },
   WARLOCK = { 0.65, 0.49, 0.77 },
   DRUID = { 0.85, 0.48, 0.24 },
}

local function clamp_color(value)
   if value < 0 then return 0 end
   if value > 1 then return 1 end
   return value
end

local function scale_color(color, r_scale, g_scale, b_scale)
   return {
      clamp_color(color[1] * r_scale),
      clamp_color(color[2] * g_scale),
      clamp_color(color[3] * b_scale),
   }
end

local function color_to_hex(color)
   return format(
      "%02x%02x%02x",
      floor(clamp_color(color[1]) * 255 + 0.5),
      floor(clamp_color(color[2]) * 255 + 0.5),
      floor(clamp_color(color[3]) * 255 + 0.5)
   )
end

local action = _G.Action or _G.A
local accent = (action and CLASS_ACCENTS[action.PlayerClass]) or DEFAULT_ACCENT

local THEME = {
   bg = { 0.086, 0.075, 0.059 },        -- #16130f
   bg_light = { 0.110, 0.094, 0.071 },  -- #1c1812
   bg_widget = { 0.118, 0.102, 0.078 }, -- #1e1a14
   bg_hover = { 0.149, 0.125, 0.102 },  -- #26201a
   border = { 0.200, 0.169, 0.125 },    -- #332b20
   accent = accent,
   -- Preserve the existing orange dim/tint ratios, then apply them to class accents.
   accent_dim = scale_color(accent, 0.880410, 0.826248, 0.702128),
   accent_bg = scale_color(accent, 0.160592, 0.188540, 0.268085),
   text = { 0.925, 0.890, 0.824 },        -- #ece3d2
   text_dim = { 0.702, 0.647, 0.529 },    -- #b3a587
   text_header = { 0.925, 0.890, 0.824 }, -- #ece3d2

   state = {
      good = { 0.20, 0.90, 0.20 },
      warn = { 1.00, 0.67, 0.20 },
      bad = { 1.00, 0.20, 0.20 },
      chosen = { 0.60, 1.00, 0.60 },
      gold = { 0.85, 0.70, 0.20 },
      neutral = { 0.30, 0.32, 0.36 },
   },
}

THEME.accent_hex = color_to_hex(THEME.accent)
NS.Theme = THEME
