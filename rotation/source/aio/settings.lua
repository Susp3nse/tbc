-- Flux AIO - Custom Settings UI
-- Tabbed settings frame with minimap button
-- Generic: reads from _G.FluxAIO_SETTINGS_SCHEMA and class_config

-- ============================================================================
-- FRAMEWORK VALIDATION
-- ============================================================================
local _G = _G
local pairs, ipairs, tostring, type = pairs, ipairs, tostring, type
local tinsert = table.insert
local format = string.format
local floor, max, min = math.floor, math.max, math.min
local unpack = unpack

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Settings]|r Core module not loaded!")
    return
end

local A = NS.A
if not A then
    print("|cFFFF0000[Flux AIO Settings]|r Action framework not available!")
    return
end

local GetToggle = A.GetToggle
local rotation_registry = NS.rotation_registry
local cc = rotation_registry and rotation_registry.class_config

-- Derive display name from class config
local class_name = cc and cc.name or "Unknown"
local CLASS_TITLE_COLORS = { Druid = "ff7d0a", Hunter = "abd473", Mage = "69ccf0", Paladin = "f58cba", Priest = "ffffff", Rogue = "fff569", Shaman = "0070dd", Warlock = "9482c9", Warrior = "c79c6e" }
local class_hex = CLASS_TITLE_COLORS[class_name] or "6c63ff"
local addon_title = class_name .. " AIO"
local addon_title_colored = format("|cff%s%s|r |cff6c63ffAIO|r", class_hex, class_name)
local version = cc and cc.version or "v1.0.0"

-- ============================================================================
-- THEME
-- ============================================================================
local THEME = {
    bg          = { 0.031, 0.031, 0.039, 0.97 },   -- #08080a
    bg_light    = { 0.047, 0.047, 0.059, 1 },       -- #0c0c0f
    bg_widget   = { 0.059, 0.059, 0.075, 1 },       -- #0f0f13
    bg_hover    = { 0.075, 0.075, 0.086, 1 },       -- #131316
    border      = { 0.118, 0.118, 0.149, 1 },       -- #1e1e26
    accent      = { 0.424, 0.388, 1.0, 1 },         -- #6c63ff
    accent_dim  = { 0.255, 0.233, 0.6, 1 },         -- #413b99 (dimmed accent)
    accent_bg   = { 0.078, 0.074, 0.154, 1 },       -- accent @ 12% over bg
    text        = { 0.863, 0.863, 0.894, 1 },       -- #dcdce4
    text_dim    = { 0.580, 0.580, 0.659, 1 },       -- #9494a8
    text_header = { 0.863, 0.863, 0.894, 1 },       -- #dcdce4 (primary text)

    frame_w     = 650,
    frame_h     = 520,
    tab_h       = 28,
    row_h       = 24,
    pad         = 15,
    section_gap = 12,
    widget_gap  = 10,
    col_gap     = 15,
    card_pad    = 12,
    slider_w    = 200,
    dropdown_w  = 220,
}

local BACKDROP_THIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- ============================================================================
-- STATE
-- ============================================================================
local settings_frame = nil
local tab_buttons = {}
local tab_panels = {}
local active_tab = 1
local active_dropdown_popup = nil

-- ============================================================================
-- SETTINGS READ / WRITE
-- ============================================================================
local SetToggle = A.SetToggle

local function write_setting(key, value)
    SetToggle({2, key, nil, true}, value)
end

local function read_setting(key, default)
    local val = GetToggle(2, key)
    if val ~= nil then return val end
    return default
end

-- ============================================================================
-- UTILITY
-- ============================================================================
local function close_active_dropdown()
    if active_dropdown_popup and active_dropdown_popup:IsShown() then
        active_dropdown_popup:Hide()
    end
    active_dropdown_popup = nil
end

local function setup_scroll_forward(widget, scroll)
    widget:EnableMouseWheel(true)
    widget:SetScript("OnMouseWheel", function(_, delta)
        local fn = scroll:GetScript("OnMouseWheel")
        if fn then fn(scroll, delta) end
    end)
end

-- ============================================================================
-- WIDGET FACTORY
-- ============================================================================
local content_w = THEME.frame_w - THEME.pad * 2 - 20
local inner_w = content_w - THEME.card_pad * 2
local inner_col_w = floor((inner_w - THEME.col_gap) / 2)

local function create_section_header(parent, y, text)
    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", THEME.pad, y)
    hdr:SetTextColor(THEME.text_header[1], THEME.text_header[2], THEME.text_header[3])
    hdr:SetText(text)

    return y - 24
end

local function create_checkbox(parent, x, y, w, def, scroll)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(w, THEME.row_h)
    row:SetPoint("TOPLEFT", x, y)

    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop(BACKDROP_THIN)

    local ck = box:CreateTexture(nil, "OVERLAY")
    ck:SetPoint("CENTER", 0, 0)
    ck:SetSize(20, 20)
    ck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    ck:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])
    ck:Hide()

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
    lbl:SetText(def.label)
    lbl:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local checked = read_setting(def.key, def.default) and true or false

    local function refresh()
        if checked then
            ck:Show()
            box:SetBackdropColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.25)
            box:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        else
            ck:Hide()
            box:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
            box:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        end
    end

    row:SetScript("OnClick", function()
        checked = not checked
        refresh()
        write_setting(def.key, checked)
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.label, 1, 1, 1)
        if def.tooltip then GameTooltip:AddLine(def.tooltip, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    if scroll then setup_scroll_forward(row, scroll) end
    refresh()

    row.key = def.key
    row.default = def.default
    row.set_value = function(v) checked = v and true or false; refresh() end
    return row, THEME.row_h + THEME.widget_gap
end

local function create_slider(parent, x, y, w, def, scroll)
    local h = 50
    local ctr = CreateFrame("Frame", nil, parent)
    ctr:SetSize(w, h)
    ctr:SetPoint("TOPLEFT", x, y)

    local lbl = ctr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(def.label)
    lbl:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local fmt = def.format or "%d"
    local val_text = ctr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val_text:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    val_text:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    local slider = CreateFrame("Slider", nil, ctr)
    slider:SetSize(THEME.slider_w, 14)
    slider:SetPoint("TOPLEFT", 0, -22)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(def.min, def.max)
    slider:SetValueStep(def.step or 1)
    slider:EnableMouse(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local thumb_tex = slider:CreateTexture(nil, "OVERLAY")
    thumb_tex:SetSize(10, 18)
    thumb_tex:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    slider:SetThumbTexture(thumb_tex)

    local mn = ctr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mn:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    mn:SetText(tostring(def.min))
    mn:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local mx = ctr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mx:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    mx:SetText(tostring(def.max))
    mx:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local cur = read_setting(def.key, def.default) or def.default
    slider:SetValue(cur)
    val_text:SetText(format(fmt, cur))

    local step = def.step or 1
    slider:SetScript("OnValueChanged", function(_, v)
        v = floor(v / step + 0.5) * step
        if v < def.min then v = def.min end
        if v > def.max then v = def.max end
        val_text:SetText(format(fmt, v))
        write_setting(def.key, v)
    end)

    ctr:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.label, 1, 1, 1)
        if def.tooltip then GameTooltip:AddLine(def.tooltip, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    ctr:SetScript("OnLeave", GameTooltip_Hide)
    ctr:EnableMouse(true)

    if scroll then
        setup_scroll_forward(ctr, scroll)
        setup_scroll_forward(slider, scroll)
    end

    ctr.key = def.key
    ctr.default = def.default
    ctr.set_value = function(v)
        v = v or def.default
        slider:SetValue(v)
        val_text:SetText(format(fmt, v))
    end
    return ctr, h + THEME.widget_gap
end

local function create_dropdown(parent, x, y, w, def, scroll)
    local h = 44
    local dw = w - 4
    local ctr = CreateFrame("Frame", nil, parent)
    ctr:SetSize(w, h)
    ctr:SetPoint("TOPLEFT", x, y)

    local lbl = ctr:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 0, 0)
    lbl:SetText(def.label)
    lbl:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local btn = CreateFrame("Button", nil, ctr, "BackdropTemplate")
    btn:SetSize(dw, 22)
    btn:SetPoint("TOPLEFT", 0, -16)
    btn:SetBackdrop(BACKDROP_THIN)
    btn:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
    btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local btn_text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn_text:SetPoint("LEFT", 8, 0)
    btn_text:SetPoint("RIGHT", -20, 0)
    btn_text:SetJustifyH("LEFT")

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("\226\150\188")
    arrow:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    local popup = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(100)
    popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    popup:SetSize(dw, #def.options * 22 + 4)
    popup:SetBackdrop(BACKDROP_THIN)
    popup:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], 0.98)
    popup:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    popup:Hide()

    local cur_val = read_setting(def.key, def.default) or def.default

    local function update_display()
        for _, opt in ipairs(def.options) do
            if opt.value == cur_val then
                btn_text:SetText(opt.text)
                return
            end
        end
        btn_text:SetText(tostring(cur_val))
    end

    for i, opt in ipairs(def.options) do
        local ob = CreateFrame("Button", nil, popup)
        ob:SetSize(dw - 4, 20)
        ob:SetPoint("TOPLEFT", 2, -(i - 1) * 22 - 2)

        local hbg = ob:CreateTexture(nil, "BACKGROUND")
        hbg:SetAllPoints()
        hbg:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.4)
        hbg:Hide()

        local ot = ob:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ot:SetPoint("LEFT", 6, 0)
        ot:SetText(opt.text)

        ob:SetScript("OnClick", function()
            cur_val = opt.value
            update_display()
            popup:Hide()
            active_dropdown_popup = nil
            write_setting(def.key, cur_val)
        end)
        ob:SetScript("OnEnter", function() hbg:Show() end)
        ob:SetScript("OnLeave", function() hbg:Hide() end)
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
            active_dropdown_popup = nil
        else
            close_active_dropdown()
            popup:Show()
            active_dropdown_popup = popup
        end
    end)

    update_display()

    if scroll then setup_scroll_forward(ctr, scroll) end
    ctr:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(def.label, 1, 1, 1)
        if def.tooltip then GameTooltip:AddLine(def.tooltip, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    ctr:SetScript("OnLeave", GameTooltip_Hide)
    ctr:EnableMouse(true)

    ctr.key = def.key
    ctr.default = def.default
    ctr.set_value = function(v) cur_val = v; update_display() end
    return ctr, h + THEME.widget_gap
end

-- ============================================================================
-- TAB DEFINITIONS (from shared schema)
-- ============================================================================
local TAB_DEFS = _G.FluxAIO_SETTINGS_SCHEMA

-- ============================================================================
-- TAB PANEL BUILDER
-- ============================================================================
local function create_tab_panel(tab_index)
    local tab_def = TAB_DEFS[tab_index]
    if not tab_def then return nil end

    local panel = CreateFrame("Frame", nil, settings_frame)
    panel:SetPoint("TOPLEFT", 0, settings_frame.content_top)
    panel:SetPoint("BOTTOMRIGHT", 0, 24)

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetAllPoints()
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(THEME.frame_w - 10)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx = self:GetVerticalScrollRange()
        self:SetVerticalScroll(max(0, min(mx, cur - delta * 30)))
    end)

    local y_pos = -8
    local widgets = {}

    for _, section in ipairs(tab_def.sections) do
        y_pos = create_section_header(content, y_pos, section.header)

        local cp = THEME.card_pad
        local card_top = y_pos
        local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
        card:SetFrameLevel(content:GetFrameLevel() + 1)
        card:SetBackdrop(BACKDROP_THIN)
        card:SetBackdropColor(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)
        card:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

        y_pos = y_pos - cp
        local col = 0
        local row_max_h = 0
        local ix = THEME.pad + cp

        for _, setting in ipairs(section.settings) do
            if not setting.hidden then
                local is_wide = setting.wide
                if is_wide and col == 1 then
                    y_pos = y_pos - row_max_h
                    col = 0
                    row_max_h = 0
                end

                local x, w
                if is_wide then
                    x = ix
                    w = inner_w
                else
                    x = ix + col * (inner_col_w + THEME.col_gap)
                    w = inner_col_w
                end

                local widget, height
                if setting.type == "checkbox" then
                    widget, height = create_checkbox(content, x, y_pos, w, setting, scroll)
                elseif setting.type == "slider" then
                    widget, height = create_slider(content, x, y_pos, w, setting, scroll)
                elseif setting.type == "dropdown" then
                    widget, height = create_dropdown(content, x, y_pos, w, setting, scroll)
                end

                if widget then
                    tinsert(widgets, widget)
                    if is_wide then
                        y_pos = y_pos - height
                        row_max_h = 0
                    else
                        row_max_h = max(row_max_h, height)
                        if col == 0 then
                            col = 1
                        else
                            y_pos = y_pos - row_max_h
                            col = 0
                            row_max_h = 0
                        end
                    end
                end
            end
        end

        if col == 1 then
            y_pos = y_pos - row_max_h
        end

        y_pos = y_pos - cp
        card:SetPoint("TOPLEFT", THEME.pad, card_top)
        card:SetSize(content_w, math.abs(y_pos - card_top))

        y_pos = y_pos - THEME.section_gap
    end

    content:SetHeight(math.abs(y_pos) + 20)

    panel.widgets = widgets
    panel.scroll = scroll
    panel:Hide()
    return panel
end

-- ============================================================================
-- TAB SWITCHING
-- ============================================================================
local function switch_tab(index)
    close_active_dropdown()

    for i, btn in ipairs(tab_buttons) do
        if i == index then
            btn.bg:SetColorTexture(THEME.bg[1], THEME.bg[2], THEME.bg[3], 1)
            btn.label:SetTextColor(1, 1, 1)
            btn.indicator:Show()
        else
            btn.bg:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)
            btn.label:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
            btn.indicator:Hide()
        end
    end

    if tab_panels[active_tab] then tab_panels[active_tab]:Hide() end

    if not tab_panels[index] then
        tab_panels[index] = create_tab_panel(index)
    end

    if tab_panels[index] then
        for _, w in ipairs(tab_panels[index].widgets) do
            if w.set_value and w.key then
                w.set_value(read_setting(w.key, w.default))
            end
        end
        tab_panels[index]:Show()
    end

    active_tab = index
end

-- ============================================================================
-- MAIN FRAME
-- ============================================================================
local function create_main_frame()
    local f = CreateFrame("Frame", "FluxAIOSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(THEME.frame_w, THEME.frame_h)
    f:SetPoint("CENTER")
    f:SetBackdrop(BACKDROP_THIN)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
    f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4])
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")

    -- Title icon (favicon-style "F")
    local title_icon = CreateFrame("Frame", nil, f, "BackdropTemplate")
    title_icon:SetSize(20, 20)
    title_icon:SetPoint("TOPLEFT", THEME.pad, -8)
    title_icon:SetBackdrop(BACKDROP_THIN)
    title_icon:SetBackdropColor(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)
    title_icon:SetBackdropBorderColor(THEME.accent_dim[1], THEME.accent_dim[2], THEME.accent_dim[3], 0.6)

    local title_icon_txt = title_icon:CreateFontString(nil, "OVERLAY")
    title_icon_txt:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    title_icon_txt:SetPoint("CENTER", 1, 0)
    title_icon_txt:SetText("F")
    title_icon_txt:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", title_icon, "RIGHT", 8, 0)
    title:SetText(addon_title_colored)
    title:SetTextColor(1, 1, 1)

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local cx = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cx:SetPoint("CENTER")
    cx:SetText("x")
    cx:SetTextColor(0.6, 0.6, 0.6)
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() cx:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() cx:SetTextColor(0.6, 0.6, 0.6) end)

    -- Version
    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ver:SetPoint("BOTTOMRIGHT", -THEME.pad, 8)
    ver:SetText(version)
    ver:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

    -- Tab bar
    local tab_y = -32
    local tab_bar = f:CreateTexture(nil, "ARTWORK")
    tab_bar:SetPoint("TOPLEFT", 1, tab_y)
    tab_bar:SetPoint("TOPRIGHT", -1, tab_y)
    tab_bar:SetHeight(THEME.tab_h)
    tab_bar:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)

    local tab_w = (THEME.frame_w - 2) / #TAB_DEFS
    for i, td in ipairs(TAB_DEFS) do
        local tb = CreateFrame("Button", nil, f)
        tb:SetSize(tab_w, THEME.tab_h)
        tb:SetPoint("TOPLEFT", 1 + (i - 1) * tab_w, tab_y)

        local bg = tb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)
        tb.bg = bg

        local ind = tb:CreateTexture(nil, "OVERLAY")
        ind:SetPoint("BOTTOMLEFT", 0, 0)
        ind:SetPoint("BOTTOMRIGHT", 0, 0)
        ind:SetHeight(2)
        ind:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        ind:Hide()
        tb.indicator = ind

        local tl = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tl:SetPoint("CENTER")
        tl:SetText(td.name)
        tl:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
        tb.label = tl

        tb:SetScript("OnClick", function() switch_tab(i) end)
        tb:SetScript("OnEnter", function()
            if i ~= active_tab then
                bg:SetColorTexture(THEME.bg_hover[1], THEME.bg_hover[2], THEME.bg_hover[3], 1)
            end
        end)
        tb:SetScript("OnLeave", function()
            if i ~= active_tab then
                bg:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 1)
            end
        end)

        tab_buttons[i] = tb
    end

    -- Separator below tabs
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 0, tab_y - THEME.tab_h)
    sep:SetPoint("TOPRIGHT", 0, tab_y - THEME.tab_h)
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    f.content_top = tab_y - THEME.tab_h - 1

    tinsert(UISpecialFrames, "FluxAIOSettingsFrame")

    f:SetScript("OnHide", function() close_active_dropdown() end)
    f:Hide()
    return f
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
local function toggle_settings()
    if not settings_frame then
        settings_frame = create_main_frame()
        NS.settings_frame = settings_frame
    end

    if settings_frame:IsShown() then
        settings_frame:Hide()
    else
        settings_frame:Show()
        switch_tab(active_tab)
    end
end

NS.toggle_settings = toggle_settings

-- ============================================================================
-- SETTINGS BUTTON (Free-floating, draggable anywhere)
-- ============================================================================
local function create_settings_button()
    local btn = CreateFrame("Button", nil, UIParent)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)

    -- Circular border (slightly larger, rendered behind)
    local border = btn:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
    border:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)

    -- Circular background
    local bg = btn:CreateTexture(nil, "BORDER")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
    bg:SetVertexColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], 0.95)

    -- Icon letter
    local txt = btn:CreateFontString(nil, "ARTWORK")
    txt:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetText("F")
    txt:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    -- Movable + draggable
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp")

    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Capture position immediately after stop, before any other calls
        local cx, cy = self:GetCenter()
        C_Timer.After(0.05, function() self.dragging = false end)
        if cx and cy then
            write_setting("_btn_x", floor(cx + 0.5))
            write_setting("_btn_y", floor(cy + 0.5))
        end
    end)

    btn:SetScript("OnClick", function(self)
        if not self.dragging then
            toggle_settings()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(addon_title_colored, 1, 1, 1)
        GameTooltip:AddLine("Left-click to open settings", 1, 1, 1)
        GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/flux help for commands", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    -- Default position until DB is ready
    btn:SetPoint("CENTER", Minimap, "CENTER", 80, 0)

    -- Poll until pActionDB is initialized, then restore saved position
    local restorer = CreateFrame("Frame")
    restorer:SetScript("OnUpdate", function(self)
        local sx = GetToggle(2, "_btn_x")
        if sx == nil then return end
        self:SetScript("OnUpdate", nil)
        self:Hide()
        if sx > 0 then
            local sy = GetToggle(2, "_btn_y") or -1
            if sy > 0 then
                btn:ClearAllPoints()
                btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
            end
        end
    end)

    return btn
end

local settings_btn = create_settings_button()

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================
SLASH_FLUXAIO1 = "/flux"
SLASH_FLUXAIO2 = "/faio"
SlashCmdList["FLUXAIO"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "" then
        toggle_settings()
        return
    end

    if msg == "burst" then
        NS.set_force_flag("force_burst")
        NS.show_notification("BURST", 3.0, { 1.0, 0.5, 0.1 })
        print(format("|cff%s[Flux AIO]|r |cFFFFFF00Burst|r cooldowns activated!", class_hex))
        return
    end

    if msg == "defensive" or msg == "def" then
        NS.set_force_flag("force_defensive")
        NS.show_notification("DEFENSIVE", 3.0, { 0.3, 0.7, 1.0 })
        print(format("|cff%s[Flux AIO]|r |cFFFFFF00Defensive|r cooldowns activated!", class_hex))
        return
    end

    if msg == "gap" then
        NS.set_force_flag("force_gap")
        print(format("|cff%s[Flux AIO]|r |cFFFFFF00Gap closer|r activated!", class_hex))
        return
    end

    if msg == "status" then
        if NS.toggle_dashboard then
            NS.toggle_dashboard()
        else
            print(format("|cff%s[Flux AIO]|r Dashboard not yet loaded.", class_hex))
        end
        return
    end

    if msg == "help" then
        print(format("|cff%s[Flux AIO]|r Slash commands:", class_hex))
        print("  /flux           - Open settings")
        print("  /flux burst     - Force burst cooldowns")
        print("  /flux def       - Force defensive cooldowns")
        print("  /flux gap       - Use gap closer")
        print("  /flux status    - Toggle combat dashboard")
        print("  /fticks         - Toggle cat energy-tick debug print")
        print("  /flux help      - Show this help")
        return
    end

    -- Unknown subcommand: fallback to settings toggle
    toggle_settings()
end

-- Dedicated tick-debug toggle (kept as its own slash so it can't be intercepted
-- by /flux's default-to-open-UI behaviour).
SLASH_FLUXTICKS1 = "/fticks"
SlashCmdList["FLUXTICKS"] = function()
    local ett = NS.energy_tick_tracker
    if not ett then
        print(format("|cff%s[Flux AIO]|r Energy tick tracker not loaded (cat only).", class_hex))
        return
    end
    ett.debug = not ett.debug
    print(format("|cff%s[Flux AIO]|r Tick debug print %s.", class_hex,
        ett.debug and "|cFF55FF55ON|r" or "|cFFFF5555OFF|r"))
end

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Settings]|r Custom UI loaded! Use minimap button or /flux")
