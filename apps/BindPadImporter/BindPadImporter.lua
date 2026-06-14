--[[
    BindPadImporter - an adapter/extension that runs alongside BindPad.

    It does not edit BindPad's own files. It only calls BindPad's public globals
    (BindPadCore, BindPadVars, BindPadFrame_*), so BindPad can be updated
    independently and this keeps working as long as those entry points exist.

    Public API (callable from /run, other addons, WeakAuras, etc.):
        BindPadImporter.ImportMacro(def)        -> ok, msgOrName
        BindPadImporter.ImportMacros(list)      -> importedCount, total
        BindPadImporter.ImportJSON(jsonString)  -> importedCount or nil,err

    Slash commands:
        /bpi              open the paste-JSON window
        /bpi run          (re)import everything in Macros.lua (BindPadImporterMacros)
        /bpi list         list macros this addon has imported
        /bpi clear        remove all macros this addon imported (with their binds)
--]]

local ADDON_NAME = ...
local Importer = {}
_G.BindPadImporter = Importer

local TYPE_BPMACRO = "CLICK"          -- matches BindPad's internal TYPE_BPMACRO
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function out(msg)
    -- Reuse BindPad's chat printer when present so messages look uniform.
    if _G.BindPadFrame_OutputText then
        _G.BindPadFrame_OutputText(msg)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[BindPadImporter]|r " .. tostring(msg))
    end
end
Importer.Print = out

-- field accessor that tolerates several key spellings
local function field(def, ...)
    for i = 1, select("#", ...) do
        local k = select(i, ...)
        local v = def[k]
        if v ~= nil then return v end
    end
    return nil
end

local function getName(def)        return field(def, "name", "macroName", "Macro name") end
local function getKey(def)         return field(def, "key", "keybind", "Keybind") end
local function getMacroText(def)   return field(def, "macrotext", "text", "body", "Macro text") end
local function getIcon(def)        return field(def, "icon", "texture") end

local function normalizeKey(key)
    if type(key) ~= "string" then return nil end
    key = key:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then return nil end
    return key:upper()
end

-- Accept icons as: a fileID number, a numeric string, a full texture path
-- ("Interface\\Icons\\Foo"), or a bare icon name ("Foo"). SetTexture needs a
-- full path or a number, so a bare name is auto-prefixed with Interface\Icons\.
local function normalizeIcon(icon)
    if type(icon) == "number" then
        return icon
    elseif type(icon) == "string" then
        local s = icon:gsub("^%s+", ""):gsub("%s+$", "")
        if s == "" then return nil end
        if s:match("^%d+$") then
            return tonumber(s)              -- numeric string -> fileID
        end
        if not s:find("[\\/]") then
            s = "Interface\\Icons\\" .. s   -- bare name -> full path
        end
        return s
    end
    return nil
end

-- Whether BindPad is ready to be written into.
local function bindPadReady()
    return _G.BindPadCore ~= nil
        and _G.BindPadVars ~= nil
        and _G.BindPadCore.character ~= nil
        and type(_G.BindPadCore.GetTabInfo) == "function"
end

----------------------------------------------------------------------
-- slot resolution
----------------------------------------------------------------------

-- Find an existing BindPad macro slot by name in tabInfo, else first empty
-- slot, growing the tab if it's full.
-- returns: id, slotTable(or nil), isExisting
local function findSlot(tabInfo, name)
    local firstEmpty
    local n = tabInfo.numSlot or 0
    for id = 1, n do
        local s = tabInfo[id]
        if s and s.type == TYPE_BPMACRO and s.name == name then
            return id, s, true
        end
        if not firstEmpty and (not s or not s.type) then
            firstEmpty = id
        end
    end
    if firstEmpty then
        return firstEmpty, nil, false
    end
    tabInfo.numSlot = n + 1
    return tabInfo.numSlot, nil, false
end

----------------------------------------------------------------------
-- the core: import a single definition
----------------------------------------------------------------------

-- returns ok(boolean), messageOrName(string)
function Importer.ImportMacro(def)
    if type(def) ~= "table" then
        return false, "definition is not a table"
    end

    local name = getName(def)
    local macrotext = getMacroText(def)
    if type(name) ~= "string" or name == "" then
        return false, "missing 'name'"
    end
    if type(macrotext) ~= "string" then
        return false, ("macro '%s' is missing 'macrotext'"):format(name)
    end

    if not bindPadReady() then
        return false, "BindPad is not ready yet"
    end
    if InCombatLockdown() then
        return false, "cannot import during combat"
    end

    local BindPadCore = _G.BindPadCore
    local key = normalizeKey(getKey(def))
    local tab = tonumber(field(def, "tab")) or 1

    local tabInfo = BindPadCore.GetTabInfo(tab)
    if not tabInfo then
        return false, ("could not access BindPad tab %d"):format(tab)
    end

    local id, slot, existing = findSlot(tabInfo, name)
    slot = slot or {}
    tabInfo[id] = slot

    slot.type = TYPE_BPMACRO
    if not existing then
        -- NewBindPadMacroName guarantees a unique name across all tabs;
        -- it skips the current slot, so an in-place update keeps its name.
        slot.name = BindPadCore.NewBindPadMacroName(slot, name)
    end
    slot.macrotext = macrotext

    local icon = normalizeIcon(getIcon(def))
    if icon ~= nil then
        slot.texture = icon
    elseif not slot.texture then
        slot.texture = DEFAULT_ICON
    end

    -- General-tab "for all characters" flag (ignored on other tabs by BindPad).
    if field(def, "forAllCharacters") then
        slot.isForAllCharacters = true
    else
        slot.isForAllCharacters = nil
    end

    slot.action = BindPadCore.CreateBindPadMacroAction(slot)

    -- Register the secure macro attribute so the bind actually fires.
    BindPadCore.UpdateMacroText(slot)

    -- BindKey reads BindPadCore.selectedSlot for the "all characters" flag.
    BindPadCore.selectedSlot = slot

    if key then
        BindPadCore.BindKey(slot, key)
    elseif existing then
        -- Definition has no key now -> drop any binding it previously had.
        BindPadCore.UnbindSlot(slot)
    end

    -- Remember what we created, for /bpi list and /bpi clear.
    BindPadImporterDB = BindPadImporterDB or {}
    BindPadImporterDB.imported = BindPadImporterDB.imported or {}
    BindPadImporterDB.imported[slot.name] = { tab = tab, key = key }

    return true, slot.name
end

-- Import a list of definitions. returns importedCount, total
function Importer.ImportMacros(list)
    if type(list) ~= "table" then
        out("import data is not a list/table")
        return 0, 0
    end
    -- Accept either an array of defs or a single def.
    if getName(list) and getMacroText(list) then
        list = { list }
    end

    local total, ok = 0, 0
    for _, def in ipairs(list) do
        total = total + 1
        local success, msg = Importer.ImportMacro(def)
        if success then
            ok = ok + 1
        else
            out("|cffff5555skip|r " .. tostring(msg))
        end
    end

    if ok > 0 then
        -- Persist binding changes and refresh BindPad's UI/hotkeys.
        if _G.BindPadCore.DoSaveAllKeys then _G.BindPadCore.DoSaveAllKeys() end
        if _G.BindPadCore.UpdateAllHotkeys then _G.BindPadCore.UpdateAllHotkeys() end
        if _G.BindPadFrame and _G.BindPadFrame:IsShown() then
            _G.BindPadFrame_OnShow()
        end
    end

    out(("imported %d/%d macro(s)"):format(ok, total))
    return ok, total
end

-- Import from a JSON string. returns importedCount or nil,err
function Importer.ImportJSON(str)
    local Json = _G.BindPadImporterJson
    if not Json then
        return nil, "JSON decoder not loaded"
    end
    local data, err = Json.decode(str)
    if data == nil then
        out("|cffff5555JSON error:|r " .. tostring(err))
        return nil, err
    end
    local ok = Importer.ImportMacros(data)
    return ok
end

----------------------------------------------------------------------
-- removal of everything this addon imported
----------------------------------------------------------------------

function Importer.ClearImported()
    if not bindPadReady() then out("BindPad not ready") return end
    if InCombatLockdown() then out("cannot clear during combat") return end
    local BindPadCore = _G.BindPadCore
    local db = BindPadImporterDB.imported or {}
    local removed = 0
    for name, info in pairs(db) do
        local tabInfo = BindPadCore.GetTabInfo(info.tab or 1)
        if tabInfo then
            for id = 1, (tabInfo.numSlot or 0) do
                local s = tabInfo[id]
                if s and s.type == TYPE_BPMACRO and s.name == name then
                    BindPadCore.selectedSlot = s
                    BindPadCore.UnbindSlot(s)
                    BindPadCore.DeleteBindPadMacroID(s)
                    table.wipe(s)
                    removed = removed + 1
                    break
                end
            end
        end
    end
    BindPadImporterDB.imported = {}
    if _G.BindPadCore.UpdateAllHotkeys then _G.BindPadCore.UpdateAllHotkeys() end
    if _G.BindPadFrame and _G.BindPadFrame:IsShown() then _G.BindPadFrame_OnShow() end
    out(("removed %d imported macro(s)"):format(removed))
end

----------------------------------------------------------------------
-- auto-import on login
----------------------------------------------------------------------

local function runAutoImport()
    local data = _G.BindPadImporterMacros
    if type(data) ~= "table" or #data == 0 then
        return
    end
    Importer.ImportMacros(data)
end

-- Wait until BindPad has initialized (its character/profile is set up on
-- PLAYER_ENTERING_WORLD) and we're out of combat, then import.
local pending = false
local function tryAuto(attempt)
    attempt = attempt or 1
    if pending and attempt == 1 then return end
    pending = true
    if not bindPadReady() or InCombatLockdown() then
        if attempt <= 40 then           -- ~20s of retries, then stop
            C_Timer.After(0.5, function() tryAuto(attempt + 1) end)
        else
            pending = false
        end
        return
    end
    pending = false
    runAutoImport()
end

----------------------------------------------------------------------
-- shared visual theme (mirrors the Menagerie rotation debug frame so the
-- two windows feel like one product)
----------------------------------------------------------------------

local UI_THEME = {
    bg        = { 0.067, 0.067, 0.078, 0.92 },   -- #111114, a touch more opaque than the log (this is an input surface)
    bg_widget = { 0.118, 0.118, 0.141, 1 },      -- #1e1e24
    bg_hover  = { 0.133, 0.133, 0.157, 1 },       -- #222228
    bg_input  = { 0.043, 0.043, 0.051, 1 },       -- #0b0b0d -- recessed well behind the editbox
    border    = { 0.173, 0.173, 0.204, 1 },       -- #2c2c34
    accent    = { 0.424, 0.388, 1.0,  1 },        -- #6c63ff
    text      = { 0.863, 0.863, 0.894, 1 },       -- #dcdce4
    text_dim  = { 0.580, 0.580, 0.659, 1 },       -- #9494a8
}
local UI_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function themedButton(parent, text, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 22)
    btn:SetBackdrop(UI_BACKDROP)
    btn:SetBackdropColor(UI_THEME.bg_widget[1], UI_THEME.bg_widget[2], UI_THEME.bg_widget[3], 1)
    btn:SetBackdropBorderColor(UI_THEME.border[1], UI_THEME.border[2], UI_THEME.border[3], 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(UI_THEME.text[1], UI_THEME.text[2], UI_THEME.text[3])

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(UI_THEME.bg_hover[1], UI_THEME.bg_hover[2], UI_THEME.bg_hover[3], 1)
        btn:SetBackdropBorderColor(UI_THEME.accent[1], UI_THEME.accent[2], UI_THEME.accent[3], 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(UI_THEME.bg_widget[1], UI_THEME.bg_widget[2], UI_THEME.bg_widget[3], 1)
        btn:SetBackdropBorderColor(UI_THEME.border[1], UI_THEME.border[2], UI_THEME.border[3], 1)
    end)
    return btn
end

----------------------------------------------------------------------
-- paste-JSON window (built in Lua; touches none of BindPad's frames)
----------------------------------------------------------------------

local pasteFrame
local function getPasteFrame()
    if pasteFrame then return pasteFrame end

    local f = CreateFrame("Frame", "BindPadImporterPasteFrame", UIParent, "BackdropTemplate")
    f:SetSize(520, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(UI_BACKDROP)
    f:SetBackdropColor(UI_THEME.bg[1], UI_THEME.bg[2], UI_THEME.bg[3], UI_THEME.bg[4])
    f:SetBackdropBorderColor(UI_THEME.border[1], UI_THEME.border[2], UI_THEME.border[3], 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "BindPadImporterPasteFrame") -- close on ESC

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.title:SetText("BindPad Importer")
    f.title:SetTextColor(UI_THEME.accent[1], UI_THEME.accent[2], UI_THEME.accent[3])

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
    sep:SetColorTexture(UI_THEME.border[1], UI_THEME.border[2], UI_THEME.border[3], 1)

    -- Hint
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 12, -34)
    hint:SetText("Paste a JSON macro, or an array of macros, then Import.")
    hint:SetTextColor(UI_THEME.text_dim[1], UI_THEME.text_dim[2], UI_THEME.text_dim[3])

    -- Recessed input well behind the editbox
    local well = CreateFrame("Frame", nil, f, "BackdropTemplate")
    well:SetPoint("TOPLEFT", 12, -52)
    well:SetPoint("BOTTOMRIGHT", -12, 44)
    well:SetBackdrop(UI_BACKDROP)
    well:SetBackdropColor(UI_THEME.bg_input[1], UI_THEME.bg_input[2], UI_THEME.bg_input[3], 1)
    well:SetBackdropBorderColor(UI_THEME.border[1], UI_THEME.border[2], UI_THEME.border[3], 1)
    well:EnableMouse(true)

    -- Scroll + editbox
    local scroll = CreateFrame("ScrollFrame", "BindPadImporterPasteScroll", well)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -18, 6)
    scroll:EnableMouseWheel(true)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    edit:SetWidth(468)
    edit:SetHeight(320)               -- initial; Blizzard helper grows it with content
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetTextColor(UI_THEME.text[1], UI_THEME.text[2], UI_THEME.text[3])
    edit:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    -- Blizzard helpers keep the editbox sized to its text and the cursor visible
    -- inside the scroll frame (resizes the scroll child as you type/paste).
    if _G.ScrollingEdit_OnTextChanged then
        edit:SetScript("OnTextChanged", function(self)
            ScrollingEdit_OnTextChanged(self, self:GetParent())
        end)
        edit:SetScript("OnCursorChanged", _G.ScrollingEdit_OnCursorChanged)
    end
    scroll:SetScrollChild(edit)
    f.edit = edit

    -- click anywhere in the well to focus the editbox
    well:SetScript("OnMouseDown", function() edit:SetFocus() end)

    -- Themed scrollbar (matches the debug log: dark track, accent thumb)
    local scrollbar = CreateFrame("Slider", nil, well)
    scrollbar:SetPoint("TOPRIGHT", -4, -6)
    scrollbar:SetPoint("BOTTOMRIGHT", -4, 6)
    scrollbar:SetWidth(8)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetValueStep(1)
    scrollbar:SetObeyStepOnDrag(true)
    scrollbar:SetMinMaxValues(0, 0)
    scrollbar:SetValue(0)

    local track = scrollbar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(UI_THEME.bg_widget[1], UI_THEME.bg_widget[2], UI_THEME.bg_widget[3], 0.6)

    local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(UI_THEME.accent[1], UI_THEME.accent[2], UI_THEME.accent[3], 0.85)
    thumb:SetSize(8, 40)
    scrollbar:SetThumbTexture(thumb)

    local sb_syncing = false
    local function syncBar()
        if sb_syncing then return end
        sb_syncing = true
        local range = scroll:GetVerticalScrollRange() or 0
        scrollbar:SetMinMaxValues(0, range)
        scrollbar:SetValue(math.min(scroll:GetVerticalScroll() or 0, range))
        if range <= 0 then scrollbar:Hide() else scrollbar:Show() end
        sb_syncing = false
    end
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if sb_syncing then return end
        sb_syncing = true
        scroll:SetVerticalScroll(value)
        sb_syncing = false
    end)
    scroll:SetScript("OnScrollRangeChanged", syncBar)
    scroll:SetScript("OnVerticalScroll", syncBar)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
    end)

    -- Bottom toolbar
    local importBtn = themedButton(f, "Import", 110)
    importBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    importBtn:SetScript("OnClick", function()
        local txt = edit:GetText()
        if txt and txt:gsub("%s", "") ~= "" then
            Importer.ImportJSON(txt)
        else
            out("paste some JSON first")
        end
    end)

    local clearBtn = themedButton(f, "Clear box", 110)
    clearBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
    clearBtn:SetScript("OnClick", function() edit:SetText("") edit:SetFocus() end)

    pasteFrame = f
    return f
end

function Importer.OpenPasteWindow()
    local f = getPasteFrame()
    f:Show()
    f.edit:SetFocus()
end

----------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------

SLASH_BINDPADIMPORTER1 = "/bpi"
SLASH_BINDPADIMPORTER2 = "/bindpadimporter"
SlashCmdList["BINDPADIMPORTER"] = function(msg)
    local cmd = (msg or ""):match("^%s*(%S*)"):lower()
    if cmd == "" or cmd == "open" then
        Importer.OpenPasteWindow()
    elseif cmd == "run" or cmd == "import" then
        runAutoImport()
    elseif cmd == "clear" then
        Importer.ClearImported()
    elseif cmd == "list" then
        local db = BindPadImporterDB.imported or {}
        local any = false
        for name, info in pairs(db) do
            any = true
            out(("- %s (tab %s%s)"):format(name, tostring(info.tab or 1),
                info.key and (", key " .. info.key) or ""))
        end
        if not any then out("nothing imported yet") end
    else
        out("usage: /bpi [open | run | list | clear]")
    end
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        BindPadImporterDB = BindPadImporterDB or {}
        BindPadImporterDB.imported = BindPadImporterDB.imported or {}
    elseif event == "PLAYER_ENTERING_WORLD" then
        tryAuto(1)
    end
end)
