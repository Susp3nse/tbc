-- Menagerie - Combat Dashboard
-- Shared, data-driven dashboard — classes register configs, this module renders.
-- Toggle via "Show Dashboard" setting or /menagerie status

local _G = _G
local format = string.format
local floor = math.floor
local tostring = tostring
local select = select
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local GameTooltip_Hide = _G.GameTooltip_Hide
local GetSpellTexture = _G.GetSpellTexture
local GetSpellInfo = _G.GetSpellInfo
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local GetInventoryItemCooldown = _G.GetInventoryItemCooldown
local UnitRangedDamage = _G.UnitRangedDamage
local GetTime = _G.GetTime
local UnitName = _G.UnitName
local UnitGUID = _G.UnitGUID
local UnitIsUnit = _G.UnitIsUnit
local UnitDetailedThreatSituation = _G.UnitDetailedThreatSituation
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Dashboard]|r Core module not loaded!")
    return
end

local THEME = NS.Theme
if not THEME then
    print("|cFFFF0000[Menagerie Dashboard]|r Theme module not loaded!")
    return
end
local THEME_STATE = THEME.state
local Unit = NS.Unit
local Player = NS.Player
local rotation_registry = NS.rotation_registry

-- Last action state (updated by main.lua via set_last_action)
-- Tracks what the rotation RECOMMENDS (for Priority text label only)
local last_action = { name = nil, source = nil, target = nil }

local function short_unit_label(unit)
    if not unit then return nil end
    if unit == "player" then return "P0" end
    local party_idx = unit:match("^party(%d+)$")
    if party_idx then return "P" .. party_idx end
    local raid_idx = unit:match("^raid(%d+)$")
    if raid_idx then return "R" .. raid_idx end
    if unit == "target" then return "T" end
    if unit == "focus" then return "F" end
    return unit
end

local function short_guid_label(guid)
    if not guid then return nil end
    if guid == UnitGUID("player") then return "P0" end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitGUID(unit) == guid then return "P" .. i end
    end
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitGUID(unit) == guid then return "R" .. i end
    end
    if UnitGUID("target") == guid then return "T" end
    if UnitGUID("focus") == guid then return "F" end
    return nil
end

local function normalize_target_label(unit)
    if not unit then return nil end
    if unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$") or unit == "target" or unit == "focus" then
        return short_unit_label(unit)
    end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return "P0" end
    for i = 1, 4 do
        local party = "party" .. i
        if UnitIsUnit and UnitIsUnit(unit, party) then return "P" .. i end
    end
    for i = 1, 40 do
        local raid = "raid" .. i
        if UnitIsUnit and UnitIsUnit(unit, raid) then return "R" .. i end
    end
    return short_unit_label(unit)
end

function NS.set_last_action(name, source, target)
    last_action.name = name
    last_action.source = source
    last_action.target = normalize_target_label(target)
end

-- Action history ring buffer — driven by CLEU (actual casts, not recommendations)
local MAX_HISTORY = 6
local action_history = {}
for i = 1, MAX_HISTORY do
    action_history[i] = { name = nil, texture = nil, spell_id = nil, target = nil }
end
local history_count = 0

-- CLEU handler: tracks spells that ACTUALLY cast (ground truth)
local player_guid = nil
local cleu_frame = CreateFrame("Frame")
cleu_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
cleu_frame:SetScript("OnEvent", function()
    if not player_guid then
        player_guid = UnitGUID("player")
        if not player_guid then return end
    end

    local _, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= player_guid then return end
    if subevent ~= "SPELL_CAST_SUCCESS" then return end

    local texture = select(3, GetSpellInfo(spellId)) or GetSpellTexture(spellId)
    if not texture then return end

    -- Push to history (every real cast, no dedup — shows actual sequence)
    for i = MAX_HISTORY, 2, -1 do
        action_history[i].name = action_history[i - 1].name
        action_history[i].texture = action_history[i - 1].texture
        action_history[i].spell_id = action_history[i - 1].spell_id
        action_history[i].target = action_history[i - 1].target
    end
    action_history[1].name = spellName
    action_history[1].texture = texture
    action_history[1].spell_id = spellId
    action_history[1].target = short_guid_label(destGUID)
    if history_count < MAX_HISTORY then
        history_count = history_count + 1
    end
end)

local BACKDROP_THIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================
local MAX_COOLDOWNS = 8
local MAX_BUFFS = 6
local MAX_DEBUFFS = 6
local MAX_CUSTOM_LINES = 6
local UPDATE_INTERVAL = 0.1
local TOGGLE_CHECK_INTERVAL = 0.5

local FRAME_WIDTH = 200
local ICON_SIZE = 20
local ICON_GAP = 4
local ICON_STEP = ICON_SIZE + ICON_GAP   -- 24px per icon cell
local ICONS_PER_ROW = 6
local ICON_X = 10             -- left padding for icon grid

local MAX_TIMER_BARS = 3
local TIMER_BAR_HEIGHT = 8
local THREAT_BAR_H = 8
local PIP_SIZE = 8
local PIP_GAP = 3
local MAX_COMBO_PIPS = 5

local READY_BORDER  = { 0.30, 0.65, 0.30, 1 }
local DARK_BORDER   = { 0.15, 0.15, 0.15, 1 }
local ACTIVE_BORDER = { 0.70, 0.45, 0.15, 1 }   -- warm orange: debuff active
local EXPIRY_BORDER = { 0.85, 0.15, 0.15, 1 }   -- red: debuff about to expire
local EXPIRY_THRESHOLD = 3                         -- seconds before expiry flash

local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local RESOURCE_COLORS = {
    rage   = { 0.90, 0.15, 0.15 },
    energy = { 1.00, 0.86, 0.00 },
    mana   = { 0.15, 0.35, 0.90 },
}

-- Energy tick tracker (detects 2s server-side energy regen ticks for sweep dot)
local ENERGY_TICK_INTERVAL = 2.0
local energy_tick_tracker = {
    last_energy = 0,
    last_tick_time = 0,
    confident = false,
    last_stance = -1,
    stance_change_at = 0,
}

-- ============================================================================
-- ICON HELPERS
-- ============================================================================

local function get_action_icon(spell)
    -- Framework trinkets (TrinketBySlot) store inventory slot in SlotID
    if spell.SlotID then
        local inv = GetInventoryItemTexture("player", spell.SlotID)
        if inv then return inv end
    end
    -- Direct slot IDs (13/14) or item IDs
    local inv = GetInventoryItemTexture("player", spell.ID)
    if inv then return inv end
    return GetSpellTexture(spell.ID) or ICON_FALLBACK
end

local function get_buff_icon(id)
    local spell_id = type(id) == "table" and id[1] or id
    if not spell_id then return ICON_FALLBACK end
    return select(3, GetSpellInfo(spell_id)) or ICON_FALLBACK
end

local function format_timer(seconds)
    if seconds >= 1e9 then return "" end  -- inf / permanent buff guard
    if seconds > 60 then
        return format("%dm", floor(seconds / 60))
    end
    return format("%d", floor(seconds))
end

--- Resolve a config that may be flat (array/table) or per-playstyle keyed
local function resolve_list(cfg, playstyle)
    if not cfg then return nil end
    if #cfg > 0 then return cfg end                    -- flat array
    if playstyle and cfg[playstyle] then return cfg[playstyle] end
    return nil
end

--- Resolve a single config object (has .type key) or per-playstyle lookup
local function resolve_config(cfg, playstyle)
    if not cfg then return nil end
    if cfg.type then return cfg end                    -- direct config
    if playstyle and cfg[playstyle] then return cfg[playstyle] end
    return nil
end

--- Create a reusable icon slot (pre-allocated at load time)
local function create_icon_slot(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:EnableMouse(true)

    -- Border (subtle dark, 1px)
    local border = f:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(0.15, 0.15, 0.15, 1)

    -- Spell icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Dark tint overlay
    local tint = f:CreateTexture(nil, "OVERLAY", nil, 1)
    tint:SetAllPoints()
    tint:SetColorTexture(0, 0, 0, 0.6)
    tint:Hide()

    -- Timer/status text (centered, outline font with shadow)
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    text:SetPoint("CENTER", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:Hide()

    -- Tooltip on hover
    f:SetScript("OnEnter", function(self)
        if self.slot_id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetInventoryItem("player", self.slot_id)
            GameTooltip:Show()
        elseif self.spell_id then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spell_id)
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", GameTooltip_Hide)

    f:Hide()

    return { frame = f, icon = icon, border = border, tint = tint, text = text }
end

-- ============================================================================
-- STATE (packed into single table to stay under 60-upvalue Lua 5.1 limit)
-- ============================================================================
local dashboard_frame = nil
local last_valid_ps = nil
local ui = {
    cd_slots = {},
    buff_slots = {},
    debuff_slots = {},
    custom_lines = {},
    timer_bars = {},
    history_icon_slots = {},
    priority_text = nil,
    resource_bar = nil,
    resource_text = nil,
    resource_bg2 = nil,
    resource_bar2 = nil,
    resource_text2 = nil,
    header_text = nil,
    version_text = nil,
    sep2_tex = nil,
    cd_label_fs = nil,
    buff_label_fs = nil,
    debuff_label_fs = nil,
    recent_label_fs = nil,
    target_info_fs = nil,
    tick_marker = nil,
    tick_marker2 = nil,
    sweep_dot = nil,
    sweep_dot2 = nil,
    accent_stripe = nil,
    section_seps = {},
    combo_pips = {},
    threat_bg = nil,
    threat_fill = nil,
    threat_text = nil,
}

local dash_context = { settings = nil }

-- ============================================================================
-- FRAME CREATION
-- ============================================================================
local function create_dashboard()
    if dashboard_frame then return dashboard_frame end

    -- Aggressively clean up stale frame from previous /reload
    local stale = _G["MenagerieDashboard"]
    if stale then
        stale:Hide()
        stale:SetAlpha(0)
        -- Hide all child regions (fontstrings, textures) that may ghost-render
        local regions = { stale:GetRegions() }
        for _, r in pairs(regions) do r:Hide() end
        local children = { stale:GetChildren() }
        for _, c in pairs(children) do
            c:Hide()
            c:SetAlpha(0)
            -- Hide grandchildren (fontstrings parented to sub-frames like bar_bg)
            local sub = { c:GetRegions() }
            for _, s in pairs(sub) do s:Hide() end
        end
        stale:ClearAllPoints()
        stale:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
    end

    local f = CreateFrame("Frame", "MenagerieDashboard", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, 300)
    f:SetBackdrop(BACKDROP_THIN)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
    f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.6)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Capture position immediately after stop, before any other calls
        local cx, cy = self:GetCenter()
        if cx and cy then
            local SetToggle = NS.SetToggle
            if SetToggle then
                SetToggle({2, "_dash_x", nil, true}, floor(cx + 0.5))
                SetToggle({2, "_dash_y", nil, true}, floor(cy + 0.5))
            end
        end
    end)
    f:SetFrameStrata("HIGH")
    f:Hide()

    -- Default position until DB is ready
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)

    -- Poll until pActionDB is initialized, then restore saved position
    local GetToggle = NS.GetToggle
    local dash_restorer = CreateFrame("Frame")
    dash_restorer:SetScript("OnUpdate", function(self)
        if not GetToggle then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            return
        end
        local sx = GetToggle(2, "_dash_x")
        if sx == nil then return end
        self:SetScript("OnUpdate", nil)
        self:Hide()
        if sx > 0 then
            local sy = GetToggle(2, "_dash_y") or -1
            if sy > 0 then
                f:ClearAllPoints()
                f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
            end
        end
    end)

    -- Class-color accent stripe (left edge)
    ui.accent_stripe = f:CreateTexture(nil, "OVERLAY")
    ui.accent_stripe:SetWidth(2)
    ui.accent_stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    ui.accent_stripe:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    ui.accent_stripe:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)

    local y = -6

    -- Header (class name + playstyle, compact)
    ui.header_text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.header_text:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
    ui.header_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -82, y)

    ui.version_text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.version_text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.version_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, y + 1)
    ui.version_text:SetJustifyH("RIGHT")
    ui.version_text:SetTextColor(1, 1, 1, 0.9)

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -4)
    local close_txt = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    close_txt:SetPoint("CENTER")
    close_txt:SetText("x")
    close_txt:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() close_txt:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() close_txt:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]) end)

    y = y - 18

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", f, "TOPLEFT", 1, y)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, y)
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    y = y - 4

    -- Resource bar
    local RES_BAR_H = 12
    local bar_bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bar_bg:SetSize(FRAME_WIDTH - 16, RES_BAR_H)
    bar_bg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
    bar_bg:SetBackdrop(BACKDROP_THIN)
    bar_bg:SetBackdropColor(0, 0, 0, 0.6)
    bar_bg:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)

    ui.resource_bar = bar_bg:CreateTexture(nil, "ARTWORK")
    ui.resource_bar:SetPoint("TOPLEFT", 1, -1)
    ui.resource_bar:SetHeight(RES_BAR_H - 2)
    ui.resource_bar:SetTexture("Interface\\Buttons\\WHITE8X8")

    ui.resource_text = bar_bg:CreateFontString(nil, "OVERLAY")
    ui.resource_text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.resource_text:SetPoint("CENTER", bar_bg)
    ui.resource_text:SetTextColor(1, 1, 1)

    -- Energy tick marker (thin vertical line showing where +20 lands)
    ui.tick_marker = bar_bg:CreateTexture(nil, "OVERLAY")
    ui.tick_marker:SetSize(1, RES_BAR_H - 2)
    ui.tick_marker:SetColorTexture(1, 1, 1, 0.6)
    ui.tick_marker:Hide()

    -- Energy tick sweep dot (animated left-to-right over 2s tick cycle)
    ui.sweep_dot = bar_bg:CreateTexture(nil, "OVERLAY")
    ui.sweep_dot:SetSize(2, RES_BAR_H - 2)
    ui.sweep_dot:SetColorTexture(1, 1, 1, 0.8)
    ui.sweep_dot:Hide()

    y = y - (RES_BAR_H + 3)

    -- Secondary resource bar (positioned dynamically in update)
    ui.resource_bg2 = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ui.resource_bg2:SetSize(FRAME_WIDTH - 16, RES_BAR_H)
    ui.resource_bg2:SetBackdrop(BACKDROP_THIN)
    ui.resource_bg2:SetBackdropColor(0, 0, 0, 0.6)
    ui.resource_bg2:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.5)
    ui.resource_bg2:Hide()

    ui.resource_bar2 = ui.resource_bg2:CreateTexture(nil, "ARTWORK")
    ui.resource_bar2:SetPoint("TOPLEFT", 1, -1)
    ui.resource_bar2:SetHeight(RES_BAR_H - 2)
    ui.resource_bar2:SetTexture("Interface\\Buttons\\WHITE8X8")

    ui.resource_text2 = ui.resource_bg2:CreateFontString(nil, "OVERLAY")
    ui.resource_text2:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.resource_text2:SetPoint("CENTER", ui.resource_bg2)
    ui.resource_text2:SetTextColor(1, 1, 1)

    -- Energy tick marker for secondary bar
    ui.tick_marker2 = ui.resource_bg2:CreateTexture(nil, "OVERLAY")
    ui.tick_marker2:SetSize(1, RES_BAR_H - 2)
    ui.tick_marker2:SetColorTexture(1, 1, 1, 0.6)
    ui.tick_marker2:Hide()

    -- Energy tick sweep dot for secondary bar
    ui.sweep_dot2 = ui.resource_bg2:CreateTexture(nil, "OVERLAY")
    ui.sweep_dot2:SetSize(2, RES_BAR_H - 2)
    ui.sweep_dot2:SetColorTexture(1, 1, 1, 0.8)
    ui.sweep_dot2:Hide()

    -- Don't advance y — positioned dynamically in update

    -- Timer bars (GCD + class timers, thin progress bars)
    for i = 1, MAX_TIMER_BARS do
        local tbg = CreateFrame("Frame", nil, f, "BackdropTemplate")
        tbg:SetSize(FRAME_WIDTH - 16, TIMER_BAR_HEIGHT)
        tbg:SetBackdrop(BACKDROP_THIN)
        tbg:SetBackdropColor(0, 0, 0, 0.4)
        tbg:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.3)
        tbg:Hide()

        local tbar = tbg:CreateTexture(nil, "ARTWORK")
        tbar:SetPoint("TOPLEFT", 1, -1)
        tbar:SetHeight(TIMER_BAR_HEIGHT - 2)
        tbar:SetTexture("Interface\\Buttons\\WHITE8X8")

        local tlabel = tbg:CreateFontString(nil, "OVERLAY")
        tlabel:SetFont("Fonts\\FRIZQT__.TTF", 7, "")
        tlabel:SetPoint("LEFT", tbg, "LEFT", 2, 0)
        tlabel:SetTextColor(1, 1, 1, 0.9)
        tlabel:SetShadowColor(0, 0, 0, 1)
        tlabel:SetShadowOffset(1, -1)

        local tvalue = tbg:CreateFontString(nil, "OVERLAY")
        tvalue:SetFont("Fonts\\FRIZQT__.TTF", 7, "")
        tvalue:SetPoint("RIGHT", tbg, "RIGHT", -2, 0)
        tvalue:SetTextColor(1, 1, 1, 0.9)
        tvalue:SetShadowColor(0, 0, 0, 1)
        tvalue:SetShadowOffset(1, -1)

        ui.timer_bars[i] = { bg = tbg, bar = tbar, label = tlabel, value = tvalue }
    end

    -- Current Priority (inline label + value, positioned dynamically)
    ui.priority_text = f:CreateFontString(nil, "OVERLAY")
    ui.priority_text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.priority_text:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    ui.priority_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, y)
    ui.priority_text:SetJustifyH("LEFT")
    ui.priority_text:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    y = y - 16

    -- Recent cast label (small, dim — matches Cooldowns/Buffs/Debuffs pattern)
    ui.recent_label_fs = f:CreateFontString(nil, "OVERLAY")
    ui.recent_label_fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.recent_label_fs:SetText("Recent")
    ui.recent_label_fs:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 0.7)

    -- Action history icon slots (CLEU-confirmed casts)
    for i = 1, MAX_HISTORY do
        ui.history_icon_slots[i] = create_icon_slot(f)
    end

    -- Target info (label + name + stats on separate lines, positioned dynamically)
    ui.target_info_fs = f:CreateFontString(nil, "OVERLAY")
    ui.target_info_fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.target_info_fs:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    ui.target_info_fs:SetJustifyH("LEFT")
    ui.target_info_fs:SetSpacing(3)

    -- Separator (positioned dynamically in update)
    ui.sep2_tex = f:CreateTexture(nil, "ARTWORK")
    ui.sep2_tex:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
    ui.sep2_tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, y)
    ui.sep2_tex:SetHeight(1)
    ui.sep2_tex:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.25)

    -- Section labels (small, dim — unobtrusive category headers)
    ui.cd_label_fs = f:CreateFontString(nil, "OVERLAY")
    ui.cd_label_fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.cd_label_fs:SetText("Cooldowns")
    ui.cd_label_fs:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 0.7)

    ui.buff_label_fs = f:CreateFontString(nil, "OVERLAY")
    ui.buff_label_fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.buff_label_fs:SetText("Buffs")
    ui.buff_label_fs:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 0.7)

    ui.debuff_label_fs = f:CreateFontString(nil, "OVERLAY")
    ui.debuff_label_fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    ui.debuff_label_fs:SetText("Debuffs")
    ui.debuff_label_fs:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3], 0.7)

    -- Pre-allocate all icon slots
    for i = 1, MAX_COOLDOWNS do
        ui.cd_slots[i] = create_icon_slot(f)
    end
    for i = 1, MAX_BUFFS do
        ui.buff_slots[i] = create_icon_slot(f)
    end
    for i = 1, MAX_DEBUFFS do
        ui.debuff_slots[i] = create_icon_slot(f)
    end

    -- Custom lines (text-based)
    for i = 1, MAX_CUSTOM_LINES do
        local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", f, "TOPLEFT", 8, 0)
        line:SetWidth(FRAME_WIDTH - 16)
        line:SetJustifyH("LEFT")
        line:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
        line:Hide()
        ui.custom_lines[i] = line
    end

    -- Section separators (thin lines between CD/Buff/Debuff sections)
    for i = 1, 3 do
        local section_sep = f:CreateTexture(nil, "ARTWORK")
        section_sep:SetHeight(1)
        section_sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.25)
        section_sep:Hide()
        ui.section_seps[i] = section_sep
    end

    -- Combo point pips (label + 5 small squares)
    ui.combo_label = f:CreateFontString(nil, "OVERLAY")
    ui.combo_label:SetFont("Fonts\\FRIZQT__.TTF", 7, "")
    ui.combo_label:SetTextColor(0.55, 0.30, 0.90, 0.9)
    ui.combo_label:SetText("CP")
    ui.combo_label:Hide()

    for i = 1, MAX_COMBO_PIPS do
        local pip = CreateFrame("Frame", nil, f)
        pip:SetSize(PIP_SIZE, PIP_SIZE)

        local pip_border = pip:CreateTexture(nil, "BACKGROUND")
        pip_border:SetPoint("TOPLEFT", -1, 1)
        pip_border:SetPoint("BOTTOMRIGHT", 1, -1)
        pip_border:SetColorTexture(0.1, 0.1, 0.1, 1)

        local pip_fill = pip:CreateTexture(nil, "ARTWORK")
        pip_fill:SetAllPoints()
        pip_fill:SetColorTexture(1, 1, 1, 1)

        pip:Hide()
        ui.combo_pips[i] = { frame = pip, fill = pip_fill, border = pip_border }
    end

    -- Threat bar (small progress bar below target info)
    ui.threat_bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    ui.threat_bg:SetSize(FRAME_WIDTH - 16, THREAT_BAR_H)
    ui.threat_bg:SetBackdrop(BACKDROP_THIN)
    ui.threat_bg:SetBackdropColor(0, 0, 0, 0.5)
    ui.threat_bg:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 0.3)
    ui.threat_bg:Hide()

    ui.threat_fill = ui.threat_bg:CreateTexture(nil, "ARTWORK")
    ui.threat_fill:SetPoint("TOPLEFT", 1, -1)
    ui.threat_fill:SetHeight(THREAT_BAR_H - 2)
    ui.threat_fill:SetTexture("Interface\\Buttons\\WHITE8X8")

    ui.threat_text = ui.threat_bg:CreateFontString(nil, "OVERLAY")
    ui.threat_text:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
    ui.threat_text:SetPoint("CENTER", ui.threat_bg)
    ui.threat_text:SetTextColor(1, 1, 1)

    dashboard_frame = f
    return f
end

-- ============================================================================
-- ICON GRID HELPERS
-- ============================================================================

--- Position an icon in a grid within a column
local function position_icon(slot, parent, col_x, base_y, index)
    local col = (index - 1) % ICONS_PER_ROW
    local row = floor((index - 1) / ICONS_PER_ROW)
    local x = col_x + col * ICON_STEP
    local icon_y = base_y - row * ICON_STEP
    slot.frame:ClearAllPoints()
    slot.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, icon_y)
end

--- Calculate how many rows N icons occupy
local function icon_rows(count)
    if count <= 0 then return 0 end
    return floor((count - 1) / ICONS_PER_ROW) + 1
end

-- ============================================================================
-- UPDATE
-- ============================================================================
local function update_dashboard()
    if not dashboard_frame or not dashboard_frame:IsShown() then return end

    local cc = rotation_registry and rotation_registry.class_config
    if not cc then return end

    local dash_config = cc.dashboard
    if not dash_config then return end

    -- Reuse the full rotation context when it is fresh; fall back to a lightweight
    -- dashboard context only when the rotation has not run recently.
    local source_context = NS.last_rotation_context
    local source_time = NS.last_rotation_context_time or 0
    if source_context and (GetTime() - source_time) <= 0.25 then
        -- NOTE: when fresh, dash_context aliases the live reusable rotation context
        -- (NS.last_rotation_context). Treat as READ-ONLY here -- writing it corrupts the
        -- next rotation frame within the 0.25s window.
        dash_context = source_context
    else
        dash_context.settings = NS.cached_settings
        if cc.extend_context then
            cc.extend_context(dash_context)
        end
    end

    -- Header: class name + playstyle in one line
    -- Fall back to last valid playstyle when current returns nil (e.g. Druid flight form)
    local accent_hex = THEME.accent_hex or "e08a3c"
    local active_ps = cc.get_active_playstyle and cc.get_active_playstyle(dash_context)
    if active_ps then
        last_valid_ps = active_ps
    else
        active_ps = last_valid_ps or cc.idle_playstyle_name or "?"
    end
    local ps_display = active_ps:sub(1, 1):upper() .. active_ps:sub(2)
    ui.header_text:SetText(format("|cff%s%s|r |cffb3a587\194\183|r |cff%s%s|r", accent_hex, cc.name or "Unknown", accent_hex, ps_display))
    if ui.version_text then
        local class_version = NS.format_class_version and NS.format_class_version(cc) or (cc.version or "")
        ui.version_text:SetText(class_version)
    end

    -- Update accent stripe to the shared class-resolved accent.
    if ui.accent_stripe then
        ui.accent_stripe:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)
    end

    local f = dashboard_frame
    local bar_max = FRAME_WIDTH - 18

    -- Energy tick tracker: prefer class-provided frame-level tracker (e.g. cat.lua),
    -- fall back to dashboard's own 10Hz tracker for classes without one (e.g. future Rogue)
    local now = GetTime()
    local ett = NS.energy_tick_tracker or energy_tick_tracker
    if not NS.energy_tick_tracker then
        -- Dashboard-local fallback: update our own tracker
        local cur_stance = dash_context.stance or -1
        if cur_stance ~= ett.last_stance then
            ett.last_stance = cur_stance
            ett.stance_change_at = now
            ett.confident = false
        end
        local cur_energy = Player:Energy() or 0
        local delta_e = cur_energy - ett.last_energy
        if delta_e > 0 and delta_e <= 25 and (now - ett.stance_change_at) > 1.0 then
            ett.last_tick_time = now
            ett.confident = true
        end
        ett.last_energy = cur_energy
    end

    -- Primary resource bar
    local res = resolve_config(dash_config.resource, active_ps)
    if res then
        local value = 0
        local max_value = 100
        local label = res.label or "Resource"

        if res.type == "rage" then
            value = Player:Rage() or 0
        elseif res.type == "energy" then
            value = Player:Energy() or 0
            max_value = Player:EnergyMax() or 100
        elseif res.type == "mana" then
            value = Player:ManaPercentage() or 0
            label = format("%s (%.0f%%)", res.label or "Mana", value)
        end

        local pct = max_value > 0 and (value / max_value) or 0
        local bw = bar_max * pct
        if bw < 1 then bw = 1 end
        ui.resource_bar:SetWidth(bw)

        local color = res.color or RESOURCE_COLORS[res.type] or { 1, 1, 1 }
        ui.resource_bar:SetVertexColor(color[1], color[2], color[3])
        ui.resource_text:SetText(res.type == "mana" and label or format("%s: %d", res.label or res.type, value))

        -- Energy tick marker: show where next +20 tick lands
        if res.type == "energy" and value < max_value then
            local next_tick = value + 20
            if next_tick > max_value then next_tick = max_value end
            local tick_x = bar_max * (next_tick / max_value)
            ui.tick_marker:ClearAllPoints()
            ui.tick_marker:SetPoint("TOPLEFT", ui.resource_bar:GetParent(), "TOPLEFT", tick_x, -1)
            ui.tick_marker:Show()
        else
            ui.tick_marker:Hide()
        end

        -- Energy tick sweep dot visibility (positioning runs at frame rate)
        if res.type == "energy" and ett.confident and value < max_value then
            ui.sweep_dot:Show()
        else
            ui.sweep_dot:Hide()
        end
    else
        ui.tick_marker:Hide()
        ui.sweep_dot:Hide()
    end

    -- Secondary resource bar (e.g., energy/rage when primary is mana)
    -- Hand-tuned start for dynamically-positioned content, approximating the
    -- setup-layout y after the primary resource bar: header (-6, then -18) +
    -- separator (-4) + RES_BAR_H (12) + gap. Keep in sync if those constants change.
    local content_y = -40
    local res2 = resolve_config(dash_config.secondary_resource, active_ps)
    if res2 then
        local value = 0
        local max_value = 100

        if res2.type == "rage" then
            value = Player:Rage() or 0
        elseif res2.type == "energy" then
            value = Player:Energy() or 0
            max_value = Player:EnergyMax() or 100
        elseif res2.type == "mana" then
            value = Player:ManaPercentage() or 0
        end

        local pct = max_value > 0 and (value / max_value) or 0
        local bw = bar_max * pct
        if bw < 1 then bw = 1 end

        ui.resource_bg2:ClearAllPoints()
        ui.resource_bg2:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
        ui.resource_bar2:SetWidth(bw)
        local color = res2.color or RESOURCE_COLORS[res2.type] or { 1, 1, 1 }
        ui.resource_bar2:SetVertexColor(color[1], color[2], color[3])
        ui.resource_text2:SetText(res2.type == "mana"
            and format("%s (%.0f%%)", res2.label or "Mana", value)
            or format("%s: %d", res2.label or res2.type, value))
        -- Energy tick marker on secondary bar
        if res2.type == "energy" and value < max_value then
            local next_tick = value + 20
            if next_tick > max_value then next_tick = max_value end
            local tick_x = bar_max * (next_tick / max_value)
            ui.tick_marker2:ClearAllPoints()
            ui.tick_marker2:SetPoint("TOPLEFT", ui.resource_bg2, "TOPLEFT", tick_x, -1)
            ui.tick_marker2:Show()
        else
            ui.tick_marker2:Hide()
        end

        -- Energy tick sweep dot visibility (positioning runs at frame rate)
        if res2.type == "energy" and ett.confident and value < max_value then
            ui.sweep_dot2:Show()
        else
            ui.sweep_dot2:Hide()
        end

        ui.resource_bg2:Show()
        content_y = content_y - 15
    else
        ui.resource_bg2:Hide()
        ui.tick_marker2:Hide()
        ui.sweep_dot2:Hide()
    end

    -- Combo point pips (shown for playstyles that register combo_points)
    local cp_playstyles = dash_config.combo_points
    local show_pips = false
    if cp_playstyles then
        for ci = 1, #cp_playstyles do
            if cp_playstyles[ci] == active_ps then
                show_pips = true
                break
            end
        end
    end

    if show_pips then
        local cp = dash_context.cp or 0
        ui.combo_label:ClearAllPoints()
        ui.combo_label:SetPoint("TOPLEFT", f, "TOPLEFT", ICON_X, content_y - 1)
        ui.combo_label:Show()
        local pip_x = ICON_X + 16
        for i = 1, MAX_COMBO_PIPS do
            local pip = ui.combo_pips[i]
            pip.frame:ClearAllPoints()
            pip.frame:SetPoint("TOPLEFT", f, "TOPLEFT", pip_x + (i - 1) * (PIP_SIZE + PIP_GAP), content_y)
            if i <= cp then
                pip.fill:SetColorTexture(0.90, 0.15, 0.15, 1)
                pip.border:SetColorTexture(0.65, 0.10, 0.10, 1)
            else
                pip.fill:SetColorTexture(0.15, 0.15, 0.15, 0.9)
                pip.border:SetColorTexture(0.20, 0.20, 0.20, 1)
            end
            pip.frame:Show()
        end
        content_y = content_y - (PIP_SIZE + 3)
    else
        ui.combo_label:Hide()
        for i = 1, MAX_COMBO_PIPS do
            ui.combo_pips[i].frame:Hide()
        end
    end

    -- Timer bars (GCD built-in + class timers)
    local timer_idx = 1
    local class_A = NS.A

    -- GCD bar (layout only — fill + value updated at frame rate)
    if class_A then
        local tb = ui.timer_bars[1]
        tb.bg:ClearAllPoints()
        tb.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
        tb.label:SetText("GCD")
        tb.bar:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])
        tb.bar_role = "gcd"
        tb.bg:Show()
        timer_idx = 2
        content_y = content_y - (TIMER_BAR_HEIGHT + 2)
    end

    -- Swing / shoot timer bar (driven by swing_label in class dashboard config)
    -- Defaults to "Swing" when not configured so all classes get a swing timer
    local sl = dash_config.swing_label
    local swing_label
    if sl == nil then
        swing_label = "Swing"
    elseif type(sl) == "string" then
        swing_label = sl
    elseif type(sl) == "table" then
        swing_label = sl[active_ps]
    end
    if swing_label and timer_idx <= MAX_TIMER_BARS then
        -- Layout only — fill + value updated at frame rate
        local shoot = Player:GetSwingShoot() or 0
        local lbl = shoot > 0 and swing_label or "Swing"
        local ctb = ui.timer_bars[timer_idx]
        ctb.bg:ClearAllPoints()
        ctb.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
        ctb.label:SetText(lbl)
        ctb.bar:SetVertexColor(1.00, 0.49, 0.04)
        ctb.bar_role = "swing"
        ctb.bg:Show()
        content_y = content_y - (TIMER_BAR_HEIGHT + 2)
        timer_idx = timer_idx + 1
    end

    -- Hide unused timer bars
    for i = timer_idx, MAX_TIMER_BARS do
        ui.timer_bars[i].bg:Hide()
        ui.timer_bars[i].bar_role = nil
    end

    content_y = content_y - 4

    -- Separator: resources/timers → priority
    local sep_idx = 0
    sep_idx = sep_idx + 1
    local sep_top = ui.section_seps[sep_idx]
    sep_top:ClearAllPoints()
    sep_top:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
    sep_top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, content_y)
    sep_top:Show()
    content_y = content_y - 4

    -- Current Priority (inline)
    local la = last_action
    if la and la.name then
        local target_text = la.target and format(" |cffb3a587[%s]|r", la.target) or ""
        ui.priority_text:SetText(format("|cff%sPriority|r  > %s%s", accent_hex, la.name, target_text))
    else
        ui.priority_text:SetText(format("|cff%sPriority|r  |cff444444Idle|r", accent_hex))
    end
    ui.priority_text:ClearAllPoints()
    ui.priority_text:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
    ui.priority_text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, content_y)
    content_y = content_y - 11

    -- Recent cast icons (CLEU-confirmed) — collapses when no history
    if history_count > 0 then
        ui.recent_label_fs:ClearAllPoints()
        ui.recent_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
        ui.recent_label_fs:Show()
        content_y = content_y - 12

        for i = 1, MAX_HISTORY do
            local hs = ui.history_icon_slots[i]
            if i <= history_count and action_history[i].texture then
                local entry = action_history[i]
                local alpha = i == 1 and 1.0 or (0.8 - (i - 2) * 0.12)
                if alpha < 0.3 then alpha = 0.3 end
                hs.icon:SetTexture(entry.texture)
                hs.frame.spell_id = entry.spell_id
                hs.frame.slot_id = nil
                hs.frame:SetAlpha(alpha)
                hs.tint:Hide()
                if entry.target then
                    hs.text:SetText(entry.target)
                    hs.text:SetTextColor(1, 1, 1)
                    hs.text:Show()
                else
                    hs.text:Hide()
                end
                position_icon(hs, f, ICON_X, content_y, i)
                hs.frame:Show()
            else
                hs.frame:Hide()
            end
        end
        content_y = content_y - ICON_STEP - 2
    else
        ui.recent_label_fs:Hide()
        for i = 1, MAX_HISTORY do
            ui.history_icon_slots[i].frame:Hide()
        end
    end

    ui.sep2_tex:ClearAllPoints()
    ui.sep2_tex:SetPoint("TOPLEFT", f, "TOPLEFT", 8, content_y)
    ui.sep2_tex:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, content_y)
    local sections_y = content_y - 3
    local tname = UnitName("target")
    local cd_list = resolve_list(dash_config.cooldowns, active_ps)
    local buff_list = resolve_list(dash_config.buffs, active_ps)
    local debuff_list = resolve_list(dash_config.debuffs, active_ps)
    local num_cds = cd_list and math_min(#cd_list, MAX_COOLDOWNS) or 0
    local num_buffs = buff_list and math_min(#buff_list, MAX_BUFFS) or 0
    local num_debuffs = debuff_list and math_min(#debuff_list, MAX_DEBUFFS) or 0

    -- Collapse debuffs when no target and all debuffs are target-based
    local show_debuffs = num_debuffs > 0
    if show_debuffs and not tname then
        local all_target = true
        for di = 1, num_debuffs do
            if not debuff_list[di].target then
                all_target = false
                break
            end
        end
        if all_target then show_debuffs = false end
    end

    local y = sections_y

    -- ---- COOLDOWNS SECTION ----
    if num_cds > 0 then
        local label_y = y - 1
        local icons_y = y - 13

        ui.cd_label_fs:ClearAllPoints()
        ui.cd_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, label_y)
        ui.cd_label_fs:Show()

        for i = 1, MAX_COOLDOWNS do
            local slot = ui.cd_slots[i]
            if i <= num_cds then
                local spell = cd_list[i]
                local equip_slot = spell.SlotID or (GetInventoryItemTexture("player", spell.ID) and spell.ID) or nil
                local cd_remain
                if equip_slot then
                    local start, duration = GetInventoryItemCooldown("player", equip_slot)
                    cd_remain = (start and duration and start > 0) and (start + duration - GetTime()) or 0
                    if cd_remain < 0 then cd_remain = 0 end
                else
                    cd_remain = spell:GetCooldown() or 0
                end
                slot.frame.spell_id = not equip_slot and spell.ID or nil
                slot.frame.slot_id = equip_slot
                slot.icon:SetTexture(get_action_icon(spell))
                position_icon(slot, f, ICON_X, icons_y, i)

                if cd_remain > 600 then
                    slot.border:SetColorTexture(DARK_BORDER[1], DARK_BORDER[2], DARK_BORDER[3], DARK_BORDER[4])
                    slot.tint:SetAlpha(0.7)
                    slot.tint:Show()
                    slot.text:SetText("N/A")
                    slot.text:SetTextColor(0.5, 0.5, 0.5)
                    slot.text:Show()
                elseif cd_remain > 0 then
                    slot.border:SetColorTexture(DARK_BORDER[1], DARK_BORDER[2], DARK_BORDER[3], DARK_BORDER[4])
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:SetText(format_timer(cd_remain))
                    slot.text:SetTextColor(1, 1, 1)
                    slot.text:Show()
                else
                    slot.border:SetColorTexture(READY_BORDER[1], READY_BORDER[2], READY_BORDER[3], READY_BORDER[4])
                    slot.tint:Hide()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_cds) * ICON_STEP - 3
    else
        ui.cd_label_fs:Hide()
        for i = 1, MAX_COOLDOWNS do ui.cd_slots[i].frame:Hide() end
    end

    -- Separator: Cooldowns → Buffs
    if num_cds > 0 and num_buffs > 0 then
        sep_idx = sep_idx + 1
        local sep = ui.section_seps[sep_idx]
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
        sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, y)
        sep:Show()
        y = y - 3
    end

    -- ---- BUFFS SECTION ----
    if num_buffs > 0 then
        local label_y = y - 1
        local icons_y = y - 13

        ui.buff_label_fs:ClearAllPoints()
        ui.buff_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, label_y)
        ui.buff_label_fs:Show()

        for i = 1, MAX_BUFFS do
            local slot = ui.buff_slots[i]
            if i <= num_buffs then
                local b = buff_list[i]
                local dur = Unit("player"):HasBuffs(b.id) or 0

                slot.frame.spell_id = type(b.id) == "table" and b.id[1] or b.id
                slot.icon:SetTexture(get_buff_icon(b.id))
                position_icon(slot, f, ICON_X, icons_y, i)

                if dur > 0 then
                    slot.border:SetColorTexture(THEME_STATE.gold[1], THEME_STATE.gold[2], THEME_STATE.gold[3], 1)
                    slot.tint:Hide()
                    slot.text:SetText(format_timer(dur))
                    -- Urgency color: white >60s, yellow 30-60s, red <30s
                    if dur < 1e9 and dur <= 30 then
                        slot.text:SetTextColor(1, 0.3, 0.3)
                    elseif dur < 1e9 and dur <= 60 then
                        slot.text:SetTextColor(1, 0.85, 0.3)
                    else
                        slot.text:SetTextColor(1, 1, 1)
                    end
                    slot.text:Show()
                else
                    slot.border:SetColorTexture(DARK_BORDER[1], DARK_BORDER[2], DARK_BORDER[3], DARK_BORDER[4])
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_buffs) * ICON_STEP - 3
    else
        ui.buff_label_fs:Hide()
        for i = 1, MAX_BUFFS do ui.buff_slots[i].frame:Hide() end
    end

    -- Separator: Buffs → Target
    if num_buffs > 0 or num_cds > 0 then
        sep_idx = sep_idx + 1
        local sep = ui.section_seps[sep_idx]
        sep:ClearAllPoints()
        sep:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
        sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, y)
        sep:Show()
        y = y - 3
    end

    -- Hide unused separators
    for si = sep_idx + 1, 3 do
        ui.section_seps[si]:Hide()
    end

    -- Target info
    if tname then
        local stats = ""
        local ttd = Unit("target"):TimeToDie() or 0
        if ttd > 0 then
            stats = format("TTD: %s", format_timer(ttd))
        end
        local max_range, min_range = Unit("target"):GetRange()
        if max_range and max_range < 1000 then
            if stats ~= "" then stats = stats .. "  " end
            if min_range and min_range > 0 and min_range < 1000 then
                stats = stats .. format("Dist: %d-%dyd", min_range, max_range)
            else
                stats = stats .. format("Dist: %dyd", max_range)
            end
        end
        local text = format("|cff%sTarget|r  |cffcccccc%s|r", accent_hex, tname)
        text = text .. "\n|cffb3a587" .. (stats ~= "" and stats or " ") .. "|r"
        ui.target_info_fs:SetText(text)
    else
        ui.target_info_fs:SetText(format("|cff%sTarget|r  |cff444444N/A|r\n ", accent_hex))
    end
    ui.target_info_fs:ClearAllPoints()
    ui.target_info_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
    ui.target_info_fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, y)
    ui.target_info_fs:Show()
    y = y - 24

    -- Threat bar (progress bar below target info)
    local _, _, threat_pct = UnitDetailedThreatSituation("player", "target")
    if tname and threat_pct and threat_pct > 0 then
        local capped = threat_pct > 130 and 130 or threat_pct
        local tbw = bar_max * (capped / 130)
        if tbw < 1 then tbw = 1 end
        ui.threat_fill:SetWidth(tbw)
        local tc = threat_pct >= 100 and THEME_STATE.bad
            or (threat_pct >= 80 and THEME_STATE.warn or THEME_STATE.good)
        ui.threat_fill:SetVertexColor(tc[1], tc[2], tc[3])
        ui.threat_fill:Show()
        ui.threat_text:SetText(format("%d%%", threat_pct))
        ui.threat_bg:ClearAllPoints()
        ui.threat_bg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y)
        ui.threat_bg:Show()
        y = y - (THREAT_BAR_H + 2)
    else
        ui.threat_bg:Hide()
    end

    -- ---- DEBUFFS SECTION ----
    if show_debuffs then
        local label_y = y - 1
        local icons_y = y - 13

        ui.debuff_label_fs:ClearAllPoints()
        ui.debuff_label_fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, label_y)
        ui.debuff_label_fs:Show()

        for i = 1, MAX_DEBUFFS do
            local slot = ui.debuff_slots[i]
            if i <= num_debuffs then
                local d = debuff_list[i]
                local dur
                if d.target then
                    local owned = d.owned ~= false
                    dur = Unit("target"):HasDeBuffs(d.id, nil, owned or nil) or 0
                else
                    dur = Unit("player"):HasDeBuffs(d.id) or 0
                end

                slot.frame.spell_id = type(d.id) == "table" and d.id[1] or d.id
                slot.icon:SetTexture(get_buff_icon(d.id))
                position_icon(slot, f, ICON_X, icons_y, i)

                if dur > 0 then
                    -- Border: red if expiring, orange if active
                    if dur < 1e9 and dur <= EXPIRY_THRESHOLD then
                        slot.border:SetColorTexture(EXPIRY_BORDER[1], EXPIRY_BORDER[2], EXPIRY_BORDER[3], EXPIRY_BORDER[4])
                    else
                        slot.border:SetColorTexture(ACTIVE_BORDER[1], ACTIVE_BORDER[2], ACTIVE_BORDER[3], ACTIVE_BORDER[4])
                    end
                    slot.tint:Hide()
                    if d.show_stacks then
                        local stacks
                        if d.target then
                            local owned = d.owned ~= false
                            stacks = Unit("target"):HasDeBuffsStacks(d.id, owned or nil) or 0
                        else
                            stacks = Unit("player"):HasDeBuffsStacks(d.id) or 0
                        end
                        slot.text:SetText(format("%d", stacks))
                        slot.text:SetTextColor(1, 0.8, 0.3)
                    else
                        slot.text:SetText(format_timer(dur))
                        -- Urgency color: white >10s, yellow 5-10s, red <5s
                        if dur < 1e9 and dur <= 5 then
                            slot.text:SetTextColor(1, 0.3, 0.3)
                        elseif dur < 1e9 and dur <= 10 then
                            slot.text:SetTextColor(1, 0.85, 0.3)
                        else
                            slot.text:SetTextColor(1, 1, 1)
                        end
                    end
                    slot.text:Show()
                else
                    slot.border:SetColorTexture(DARK_BORDER[1], DARK_BORDER[2], DARK_BORDER[3], DARK_BORDER[4])
                    slot.tint:SetAlpha(0.6)
                    slot.tint:Show()
                    slot.text:Hide()
                end

                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end

        y = icons_y - icon_rows(num_debuffs) * ICON_STEP - 3
    else
        ui.debuff_label_fs:Hide()
        for i = 1, MAX_DEBUFFS do ui.debuff_slots[i].frame:Hide() end
    end

    -- Custom lines (text-based)
    local cl = dash_config.custom_lines
    local num_custom = 0
    for i = 1, MAX_CUSTOM_LINES do
        local line = ui.custom_lines[i]
        if cl and cl[i] then
            local clabel, cvalue = cl[i](dash_context)
            if clabel then
                line:SetText(format("|cffb3a587%s:|r %s", clabel, tostring(cvalue or "")))
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y - num_custom * 14)
                line:Show()
                num_custom = num_custom + 1
            else
                line:Hide()
            end
        else
            line:Hide()
        end
    end
    if num_custom > 0 then
        y = y - num_custom * 14 - 2
    end

    -- Auto-resize frame height
    dashboard_frame:SetHeight(math_max(-y + 10, 80))
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
local function toggle_dashboard()
    if not dashboard_frame then
        create_dashboard()
    end
    if dashboard_frame:IsShown() then
        dashboard_frame:Hide()
    else
        dashboard_frame:Show()
    end
end

NS.toggle_dashboard = toggle_dashboard

SLASH_MENAGERIEDASH1 = "/mdash"
SlashCmdList["MENAGERIEDASH"] = toggle_dashboard

-- ============================================================================
-- UPDATE TIMER (10 Hz when visible)
-- ============================================================================
local update_frame = CreateFrame("Frame")
update_frame.elapsed = 0
update_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= UPDATE_INTERVAL then
        self.elapsed = self.elapsed - UPDATE_INTERVAL
        update_dashboard()
    end
end)

-- ============================================================================
-- FRAME-RATE UPDATER (smooth animation for sweep dots + timer bars)
-- ============================================================================
local fr_bar_max = FRAME_WIDTH - 18
local fr_sweep_max = FRAME_WIDTH - 19  -- bar_max minus 1px left padding
local fr_dim = { THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3] }
local fr_frame = CreateFrame("Frame")
fr_frame:SetScript("OnUpdate", function()
    if not dashboard_frame or not dashboard_frame:IsShown() then return end

    -- Sweep dots
    local ett = NS.energy_tick_tracker or energy_tick_tracker
    if ett.confident then
        local elapsed = GetTime() - ett.last_tick_time
        local frac = (elapsed % ENERGY_TICK_INTERVAL) / ENERGY_TICK_INTERVAL
        local dot_x = 1 + fr_sweep_max * frac
        if ui._last_sweep_dot_x == nil or math_abs(dot_x - ui._last_sweep_dot_x) >= 0.5 then
            ui._last_sweep_dot_x = dot_x
            if ui.sweep_dot and ui.sweep_dot:IsShown() then
                ui.sweep_dot:ClearAllPoints()
                ui.sweep_dot:SetPoint("TOPLEFT", ui.sweep_dot:GetParent(), "TOPLEFT", dot_x, -1)
            end
            if ui.sweep_dot2 and ui.sweep_dot2:IsShown() then
                ui.sweep_dot2:ClearAllPoints()
                ui.sweep_dot2:SetPoint("TOPLEFT", ui.sweep_dot2:GetParent(), "TOPLEFT", dot_x, -1)
            end
        end
    end

    -- Timer bars (GCD + Swing fill + value text)
    for i = 1, MAX_TIMER_BARS do
        local tb = ui.timer_bars[i]
        if tb.bar_role and tb.bg:IsShown() then
          if tb.bar_role == "gcd" then
            local a = NS.A
            local gcd_total = a and a.GetGCD and a.GetGCD() or 1.5
            local gcd_rem = a and a.GetCurrentGCD and a.GetCurrentGCD() or 0
            local pct = (gcd_total > 0 and gcd_rem > 0) and (gcd_rem / gcd_total) or 0
            if pct > 1 then pct = 1 end
            if pct > 0 then
                local bw = fr_bar_max * pct
                if bw < 1 then bw = 1 end
                tb.bar:SetWidth(bw)
                tb.bar:Show()
                tb.value:SetText(format("%.1f", gcd_rem))
                tb.value:Show()
                tb.label:SetTextColor(1, 1, 1, 0.9)
            else
                tb.bar:Hide()
                tb.value:Hide()
                tb.label:SetTextColor(fr_dim[1], fr_dim[2], fr_dim[3], 0.4)
            end
        elseif tb.bar_role == "swing" then
            local shoot = Player:GetSwingShoot() or 0
            local rem, dur
            if shoot > 0 then
                rem = shoot
                dur = UnitRangedDamage("player") or 1.5
            else
                local s = Player:GetSwingStart(1) or 0
                local d = Player:GetSwing(1) or 0
                if s > 0 and d > 0 then
                    local r = (s + d) - GetTime()
                    rem = r > 0 and r or 0
                else
                    rem = 0
                end
                dur = d > 0 and d or 2.0
            end
            local pct = (dur > 0 and rem > 0) and (rem / dur) or 0
            if pct > 1 then pct = 1 end
            if pct > 0 then
                local bw = fr_bar_max * pct
                if bw < 1 then bw = 1 end
                tb.bar:SetWidth(bw)
                tb.bar:Show()
                tb.value:SetText(format("%.1f", rem))
                tb.value:Show()
                tb.label:SetTextColor(1, 1, 1, 0.9)
            else
                tb.bar:Hide()
                tb.value:Hide()
                tb.label:SetTextColor(fr_dim[1], fr_dim[2], fr_dim[3], 0.4)
            end
          end
        end
    end
end)

-- ============================================================================
-- TOGGLE WATCHER (checks setting every 0.5s)
-- ============================================================================
local watch_frame = CreateFrame("Frame")
watch_frame.elapsed = 0
local last_toggle_state = nil

watch_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= TOGGLE_CHECK_INTERVAL then
        self.elapsed = 0
        local show = NS.cached_settings.show_dashboard or false
        if show ~= last_toggle_state then
            last_toggle_state = show
            if not dashboard_frame then
                create_dashboard()
            end
            if show then
                dashboard_frame:Show()
            else
                dashboard_frame:Hide()
            end
        end
    end
end)

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Dashboard]|r Module loaded")
