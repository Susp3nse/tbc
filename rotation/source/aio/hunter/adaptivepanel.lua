-- Hunter Adaptive Engine Live Panel
-- Shows the real-time state of the adaptive DPS engine: input stats, derived
-- damage/cast values, the per-tick scoring decision, and a ring buffer of
-- recent actually-fired specials. Read-only — does not affect rotation.
--
-- Toggle via schema setting "show_adaptive_panel" (Tab 5 "Pet & Diag").

local _G, format = _G, string.format

local A = _G.Action
if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter Adaptive Panel]|r Core module not loaded!")
    return
end
-- HunterAdaptive may not be loaded yet (Order 7 unstable sort). Late-bind in Refresh().

local CreateFrame = _G.CreateFrame
local UIParent    = _G.UIParent
local GetTime     = _G.GetTime
local GetCVar     = _G.GetCVar
local UnitRangedDamage = _G.UnitRangedDamage
local UnitRangedAttackPower = _G.UnitRangedAttackPower

-- Match cliptracker palette
local THEME = {
    bg          = { 0.031, 0.031, 0.039, 0.97 },
    bg_light    = { 0.047, 0.047, 0.059, 0.88 },
    bg_widget   = { 0.059, 0.059, 0.075, 1 },
    bg_hover    = { 0.075, 0.075, 0.086, 1 },
    border      = { 0.118, 0.118, 0.149, 1 },
    accent      = { 0.424, 0.388, 1.0, 1 },
    text        = { 0.863, 0.863, 0.894, 1 },
    text_dim    = { 0.580, 0.580, 0.659, 1 },
    text_section= { 0.424, 0.749, 1.0, 1 },
    good        = { 0.4, 0.9, 0.4, 1 },
    warn        = { 1.0, 0.85, 0.3, 1 },
    bad         = { 1.0, 0.4, 0.4, 1 },
    chosen      = { 0.6, 1.0, 0.6, 1 },
}

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local Panel = {
    Frame = nil,
    IsVisible = false,
    rows = {},
    -- pre-built lookup of fire codes for the recent-fires line
}

-- Helper to make a left-anchored fontstring inside a parent
local function fs(parent, anchorTo, dx, dy, justify)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", dx, dy)
    t:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    t:SetJustifyH(justify or "LEFT")
    return t
end

local function colored(t, color)
    t:SetTextColor(color[1], color[2], color[3])
end

local function panelButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(BACKDROP)
    btn:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
    btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    end)

    return btn
end

function Panel:Create()
    if self.Frame then return self.Frame end

    local f = CreateFrame("Frame", "HunterAdaptivePanelFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 590)
    f:SetPoint("CENTER", UIParent, "CENTER", -190, 0)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
    f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.title:SetText("Adaptive")
    f.title:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local cx = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cx:SetPoint("CENTER")
    cx:SetText("x")
    cx:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    close:SetScript("OnClick", function() f:Hide() end)

    local export = panelButton(f, 60, 20, "Export")
    export:SetPoint("TOPRIGHT", close, "TOPLEFT", -6, 0)
    export:SetScript("OnClick", function() Panel:ShowDecisionExport() end)

    local clear = panelButton(f, 48, 20, "Clear")
    clear:SetPoint("TOPRIGHT", export, "TOPLEFT", -6, 0)
    clear:SetScript("OnClick", function()
        local HA = NS.HunterAdaptive
        if HA and HA.ClearDecisionLog then
            HA.ClearDecisionLog()
            Panel:Refresh()
        end
    end)

    -- Section helpers
    local y = -34
    local function header(text)
        local band = f:CreateTexture(nil, "ARTWORK")
        band:SetPoint("TOPLEFT", f, "TOPLEFT", 8, y + 2)
        band:SetSize(344, 14)
        band:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], THEME.bg_light[4])
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", 12, y)
        h:SetText(text)
        h:SetTextColor(THEME.text_section[1], THEME.text_section[2], THEME.text_section[3])
        y = y - 17
        return h
    end

    local function row(label)
        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 14, y)
        lbl:SetWidth(88)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(label)
        lbl:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
        local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        val:SetPoint("TOPLEFT", 104, y)
        val:SetWidth(244)
        val:SetJustifyH("LEFT")
        val:SetWordWrap(false)
        val:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
        y = y - 12
        return val
    end

    local function spacer(n) y = y - (n or 5) end

    header("INPUTS")
    self.rows.rap        = row("RAP")
    self.rows.rapRaw     = row("RAP raw")
    self.rows.paperDmg   = row("Paper")
    self.rows.wepDmg     = row("Base dmg")
    self.rows.crit       = row("Crit")
    self.rows.rangedSpd  = row("Speed")
    self.rows.weaponBase = row("Weapon")
    self.rows.haste      = row("Haste")
    self.rows.sqwPing    = row("SQW / Ping")
    self.rows.lat        = row("Flux lat")
    spacer()

    header("API SANITY")
    self.rows.rangedRaw  = row("Ranged")
    self.rows.rangedMods = row("Mods")
    self.rows.auraFirst  = row("Buff")
    self.rows.auraTrack  = row("Tracked")
    self.rows.auraNext   = row("Recheck")
    self.rows.weps       = row("Equip IDs")
    spacer()

    header("DAMAGE")
    self.rows.avgShoot   = row("Auto")
    self.rows.avgSteady  = row("Steady")
    self.rows.avgMulti   = row("Multi")
    self.rows.avgArcane  = row("Arcane")
    self.rows.shootDPS   = row("shootDPS")
    self.rows.steadyDPS  = row("steadyDPS")
    spacer()

    header("CAST TIMES")
    self.rows.steadyCT   = row("steady")
    self.rows.multiCT    = row("multi")
    self.rows.arcaneCT   = row("arcane")
    self.rows.windup     = row("windup")
    self.rows.catchup    = row("catchup")
    spacer()

    header("DECISION")
    self.rows.now        = row("tick")
    self.rows.optShoot   = row(" Shoot")
    self.rows.optSteady  = row(" Steady")
    self.rows.optMulti   = row(" Multi")
    self.rows.optArcane  = row(" Arcane")
    spacer()

    header("FIRES")
    self.rows.fireRing   = row("Last")
    self.rows.fireRate   = row("Per min")
    self.rows.decisionLog = row("Log")

    self.Frame = f
    return f
end

local function fmt(n, dec)
    if n == nil then return "--" end
    if type(n) ~= "number" then return tostring(n) end
    return format("%."..(dec or 0).."f", n)
end

-- Build a colorized status string for an option row
local function optionLine(score, delay, jitterFloor, gated, isChosen)
    if gated then
        return format("%5s  (gated)", "--"), THEME.text_dim
    end
    local clip = ""
    local color = THEME.text
    if delay <= jitterFloor + 0.001 then
        clip = "open"
        color = THEME.good
    elseif delay <= 0.3 then
        clip = format("clips %.2fs", delay)
        color = THEME.warn
    else
        clip = format("clips %.2fs", delay)
        color = THEME.bad
    end
    local line = format("%5d  d=%.2f  %s%s", score, delay, clip, isChosen and "  <" or "")
    if isChosen then color = THEME.chosen end
    return line, color
end

function Panel:Refresh()
    if not self.Frame or not self.Frame:IsShown() then return end
    local HA = NS.HunterAdaptive
    if not HA or not HA.GetState then return end
    local State = HA.GetState()
    if not State or not State.lastDecision then return end

    -- Walk the schema to populate cached_settings (covers default values for keys
    -- the user never toggled). Then ForceRecompute reads fresh stats + uses real settings.
    if NS.refresh_settings then NS.refresh_settings() end
    if HA.ForceRecompute then HA.ForceRecompute() end

    local d = State.lastDecision

    -- INPUTS
    self.rows.rap:SetText(fmt(State.rap, 0))
    local rapBase, rapPos, rapNeg = 0, 0, 0
    if UnitRangedAttackPower then
        rapBase, rapPos, rapNeg = UnitRangedAttackPower("player")
    end
    self.rows.rapRaw:SetText(format("%s +%s %s = %s",
        fmt(rapBase or 0, 0), fmt(rapPos or 0, 0), fmt(rapNeg or 0, 0), fmt(State.rap, 0)))
    self.rows.paperDmg:SetText(fmt(State.rangedDmgAvg, 1))
    self.rows.wepDmg:SetText(fmt(State.weaponDmgAvg, 1))
    self.rows.crit:SetText(format("%.1f%%", State.critPct or 0))
    self.rows.rangedSpd:SetText(format("%.3fs", State.rangedSpeed or 0))
    self.rows.weaponBase:SetText(format("%.2fs", State.weaponBaseSpd or 0))
    self.rows.haste:SetText(format("%.3fx", State.hasteMult or 1))

    local sqwMs = tonumber(GetCVar and GetCVar("SpellQueueWindow")) or 0
    local pingMs = math.floor(((A.GetPing and A.GetPing() or 0) * 1000) + 0.5)
    self.rows.sqwPing:SetText(format("%dms / %dms", sqwMs, pingMs))
    self.rows.lat:SetText(format("%.3fs", (A.GetLatency and A.GetLatency() or 0)))

    -- API SANITY
    local rawSpeed, lowDmg, hiDmg, physicalBonusPos, physicalBonusNeg, percent
    if UnitRangedDamage then
        rawSpeed, lowDmg, hiDmg, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
    end
    self.rows.rangedRaw:SetText(format("speed %s low %s high %s",
        fmt(rawSpeed, 3), fmt(lowDmg, 1), fmt(hiDmg, 1)))
    self.rows.rangedMods:SetText(format("pos %s neg %s pct %s",
        fmt(physicalBonusPos or 0, 1), fmt(physicalBonusNeg or 0, 1), fmt(percent or 1, 3)))

    -- Equipped weapon item IDs (MH=16, OH=17, Ranged=18). Used to verify the
    -- Infinity Blade (30312) gate on the Mind-Control-break middleware.
    local getID = _G.GetInventoryItemID
    local mh  = (getID and getID("player", 16)) or 0
    local oh  = (getID and getID("player", 17)) or 0
    local rng = (getID and getID("player", 18)) or 0
    self.rows.weps:SetText(format("MH:%d OH:%d Rng:%d%s",
        mh, oh, rng, (mh == 30312 or oh == 30312) and "  BLADE!" or ""))
    colored(self.rows.weps, (mh == 30312 or oh == 30312) and THEME.good or THEME.text)

    local auraDebug = HA.GetAuraDebug and HA.GetAuraDebug()
    if auraDebug then
        self.rows.auraFirst:SetText(auraDebug.firstLine or "--")
        self.rows.auraTrack:SetText(auraDebug.trackedLine or "--")
        local nextIn = auraDebug.nextRecomputeIn or 0
        self.rows.auraNext:SetText(format("%s in %.1fs (%d buffs)",
            auraDebug.recomputeDue and "due" or "scheduled",
            math.max(0, nextIn),
            auraDebug.buffCount or 0))
        colored(self.rows.auraNext, auraDebug.recomputeDue and THEME.warn or THEME.good)
    else
        self.rows.auraFirst:SetText("--")
        self.rows.auraTrack:SetText("--")
        self.rows.auraNext:SetText("--")
        colored(self.rows.auraNext, THEME.text_dim)
    end

    -- DERIVED
    self.rows.avgShoot:SetText(fmt(State.avgShootDmg, 0))
    self.rows.avgSteady:SetText(fmt(State.avgSteadyDmg, 0))
    self.rows.avgMulti:SetText(fmt(State.avgMultiDmg, 0))
    self.rows.avgArcane:SetText(fmt(State.avgArcaneDmg, 0))
    self.rows.shootDPS:SetText(fmt(State.shootDPS, 0))
    self.rows.steadyDPS:SetText(fmt(State.steadyDPS, 0))

    -- CAST TIMES
    self.rows.steadyCT:SetText(format("%.3fs", State.steadyCastTime or 0))
    self.rows.multiCT:SetText(format("%.3fs", State.multiCastTime or 0))
    self.rows.arcaneCT:SetText(format("%.3fs", State.arcaneCastTime or 0))
    self.rows.windup:SetText(format("%.3fs", State.rangedWindup or 0))
    self.rows.catchup:SetText(State.useMultiForCatchup and "true" or "false")
    if State.useMultiForCatchup then
        colored(self.rows.catchup, THEME.text)
    else
        colored(self.rows.catchup, THEME.warn)
    end

    -- LIVE DECISION
    local jitter = 0.075
    local timerMode = tostring(d.shootTimerMode or "?")
    local timerState = tostring(d.shootTimerState or "?")
    timerMode = timerMode:gsub("inhouse", "ih")
    timerState = timerState:gsub("known:", "k:")
    timerState = timerState:gsub("action_fallback", "af")
    self.rows.now:SetText(format("g%.2f s%.2f %s/%s -> %s",
        d.gcdRemaining or 0, d.shootRemaining or 0,
        timerMode, timerState,
        (d.chosenOpt or "?"):upper()))

    local function paint(rowKey, score, delay, gated, optName)
        local txt, color = optionLine(score, delay, jitter, gated, d.chosenOpt == optName)
        self.rows[rowKey]:SetText(txt)
        colored(self.rows[rowKey], color)
    end
    paint("optShoot",  d.rShoot,  d.shootGCDDelay,  false,        "shoot")
    paint("optSteady", d.rSteady, d.steadyShootDelay, d.steadyClipGated, "steady")
    paint("optMulti",  d.rMulti,  d.multiShootDelay,  d.multiGated or d.multiClipGated or not d.expensiveManaOk, "multi")
    paint("optArcane", d.rArcane, d.arcaneShootDelay, d.arcaneGated or d.arcaneClipGated, "arcane")

    -- RECENT FIRES
    local codes = {}
    for _, e in ipairs(State.fireHistory or {}) do
        codes[#codes + 1] = e.code or "?"
    end
    self.rows.fireRing:SetText(table.concat(codes, " "))

    local now = GetTime()
    local elapsed = math.max(1, now - (State.fireCombatStart or now))
    local mins = elapsed / 60
    local fc = State.fireCounts or {}
    self.rows.fireRate:SetText(format("S%.0f M%.0f A%.0f K%.0f St%.0f",
        (fc.steady or 0) / mins, (fc.multi or 0) / mins, (fc.arcane or 0) / mins,
        (fc.kc or 0) / mins, (fc.sting or 0) / mins))
    self.rows.decisionLog:SetText(format("%d rows", #(State.decisionLog or {})))
end

function Panel:ShowDecisionExport()
    local HA = NS.HunterAdaptive
    local text = HA and HA.GetDecisionCSV and HA.GetDecisionCSV() or "-- Adaptive decision log unavailable --"

    local f = _G["HunterAdaptiveDecisionExportFrame"]
    if not f then
        f = CreateFrame("Frame", "HunterAdaptiveDecisionExportFrame", UIParent, "BackdropTemplate")
        f:SetSize(760, 460)
        f:SetPoint("CENTER")
        f:SetBackdrop(BACKDROP)
        f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
        f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT", 12, -8)
        f.title:SetText("Export Adaptive Decisions")
        f.title:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])

        local close = panelButton(f, 52, 22, "Close")
        close:SetPoint("BOTTOMRIGHT", -10, 8)
        close:SetScript("OnClick", function() f:Hide() end)

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPRIGHT", -12, -12)
        hint:SetText("Ctrl+C to copy")
        hint:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -34)
        sf:SetPoint("BOTTOMRIGHT", -30, 42)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(700)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.editBox = eb
    end

    f.editBox:SetText(text)
    f.editBox:HighlightText()
    f.editBox:SetFocus()
    f:Show()
end

function Panel:Show()
    self:Create()
    self.Frame:Show()
    self.IsVisible = true
    self:Refresh()
end

function Panel:Hide()
    if self.Frame then self.Frame:Hide() end
    self.IsVisible = false
end

NS.HunterAdaptivePanel = Panel

-- Toggle watcher + refresh ticker
local lastToggle = nil
local watch = CreateFrame("Frame")
watch.elapsed = 0
watch:SetScript("OnUpdate", function(self, e)
    self.elapsed = self.elapsed + e
    if self.elapsed >= 0.2 then
        self.elapsed = 0
        local show = NS.cached_settings and NS.cached_settings.show_adaptive_panel or false
        if show ~= lastToggle then
            lastToggle = show
            if show then Panel:Show() else Panel:Hide() end
        end
        if show then Panel:Refresh() end
    end
end)

print("|cFF00FF00[Flux AIO Hunter]|r Adaptive panel loaded")
