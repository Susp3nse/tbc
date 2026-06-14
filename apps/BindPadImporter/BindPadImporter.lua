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
-- paste-JSON window (built in Lua; touches none of BindPad's frames)
----------------------------------------------------------------------

local pasteFrame
local function getPasteFrame()
    if pasteFrame then return pasteFrame end

    local f = CreateFrame("Frame", "BindPadImporterPasteFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(520, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "BindPadImporterPasteFrame") -- close on ESC

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText("BindPad Importer - paste a JSON macro or array of macros")

    local scroll = CreateFrame("ScrollFrame", "BindPadImporterPasteScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -32)
    scroll:SetPoint("BOTTOMRIGHT", -34, 44)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(460)
    edit:SetHeight(340)               -- initial; grows with content below
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetTextInsets(4, 4, 4, 4)
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

    -- click anywhere in the scroll area to focus the editbox
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(110, 22)
    importBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local txt = edit:GetText()
        if txt and txt:gsub("%s", "") ~= "" then
            Importer.ImportJSON(txt)
        else
            out("paste some JSON first")
        end
    end)

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(110, 22)
    clearBtn:SetPoint("RIGHT", importBtn, "LEFT", -8, 0)
    clearBtn:SetText("Clear box")
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
