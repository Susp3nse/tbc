-- Hunter Melee Weave Coach
-- Read-only traffic-light UI for manual Raptor Strike weaving.

local _G, string, math = _G, string, math
local format = string.format
local math_max = math.max
local math_min = math.min

local A = _G.Action
if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Hunter Weave]|r Core module not loaded!")
    return
end

local HA               = NS.A
local Player           = NS.Player
local Unit             = NS.Unit
local CreateFrame      = _G.CreateFrame
local UIParent         = _G.UIParent
local GetTime          = _G.GetTime
local GetSpellInfo     = _G.GetSpellInfo
local UnitGUID         = _G.UnitGUID
local UnitRangedDamage = _G.UnitRangedDamage
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local Listener         = A.Listener

local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local RAPTOR_NAME = GetSpellInfo and GetSpellInfo(2973) or "Raptor Strike"

local THEME = {
    bg       = { 0.031, 0.031, 0.039, 0.96 },
    panel    = { 0.059, 0.059, 0.075, 1 },
    border   = { 0.118, 0.118, 0.149, 1 },
    text     = { 0.90, 0.90, 0.94, 1 },
    dim      = { 0.58, 0.58, 0.66, 1 },
    gray     = { 0.30, 0.32, 0.36, 1 },
    green    = { 0.10, 0.78, 0.28, 1 },
    yellow   = { 0.95, 0.82, 0.18, 1 },
    orange   = { 1.00, 0.55, 0.12, 1 },
    red      = { 1.00, 0.18, 0.18, 1 },
}

local RANGE_STATES = {
    UNKNOWN = { color = THEME.gray,   label = "range unknown" },
    IDEAL   = { color = THEME.green,  label = "ideal 5-7yd" },
    FAR     = { color = THEME.red,    label = "too far 7-10yd" },
    MELEE   = { color = THEME.red,    label = "melee <5yd" },
    DEAD    = { color = THEME.red,    label = "deadzone" },
    RANGED  = { color = THEME.gray,   label = "ranged" },
    OUT     = { color = THEME.gray,   label = "out of range" },
}

local STATES = {
    GRAY   = { color = THEME.gray,   title = "HOLD" },
    GREEN  = { color = THEME.green,  title = "GO" },
    ORANGE = { color = THEME.orange, title = "OUT" },
    RED    = { color = THEME.red,    title = "BACK" },
}

local Coach = {
    Frame = nil,
    IsVisible = false,
    State = {},
    LastRaptorPromptAt = nil,
    RaptorPendingUntil = nil,
    RaptorPendingStartedAt = nil,
    LastMeleeRemaining = nil,
}

local function settingSeconds(key, fallbackMs)
    local s = NS.cached_settings or {}
    local v = tonumber(s[key]) or fallbackMs
    return v / 1000
end

local function fmtSeconds(v)
    if not v or v <= 0 then return "0.00s" end
    return format("%.2fs", v)
end

local function cooldownRemaining(spell)
    if not spell or not spell.GetCooldown then return 999 end
    return spell:GetCooldown() or 0
end

local function isReadySoon(spell, unit, lead)
    if not spell then return false end
    if spell.IsReady and spell:IsReady(unit) then return true end
    return cooldownRemaining(spell) <= (lead or 0.15)
end

local function getRangedTiming()
    local adaptive = NS.HunterAdaptive
    if adaptive and adaptive.GetState then
        local st = adaptive.GetState()
        if st and st.rangedSpeed and st.rangedSpeed > 0 and st.rangedWindup and st.rangedWindup > 0 then
            return st.rangedSpeed, st.rangedWindup, st.hasteMult or 1
        end
    end

    local speed = 0
    if UnitRangedDamage then
        speed = select(1, UnitRangedDamage("player")) or 0
    end
    if speed <= 0 then speed = 2.8 end

    local s = NS.cached_settings or {}
    local base = tonumber(s.weapon_speed) or speed
    local haste = base / math_max(0.1, speed)
    return speed, 0.5 / haste, haste
end

local function getMeleeSwingRemaining()
    if not Player then return 0, 0 end

    local now = GetTime()
    local start = Player.GetSwingStart and Player:GetSwingStart(1) or 0
    local duration = Player.GetSwing and Player:GetSwing(1) or 0

    if start and start > 0 and duration and duration > 0 then
        local remaining = (start + duration) - now
        if remaining > 0 and remaining <= 10 then
            return remaining, duration
        end
    end

    if duration and duration > 0 and duration <= 10 then
        return duration, Player.GetSwingMax and (Player:GetSwingMax(1) or duration) or duration
    end

    return 0, Player.GetSwingMax and (Player:GetSwingMax(1) or 0) or 0
end

local function getTargetRange(unit)
    if NS.GetRange then
        return NS.GetRange(unit) or 0
    end
    if Unit and Unit(unit) and Unit(unit).GetRange then
        return Unit(unit):GetRange() or 0
    end
    return 0
end

local function getRangeBucket(range, inMelee, atRange, deadzone)
    if inMelee then
        return "melee"
    end
    if deadzone then
        return "deadzone"
    end
    if not range or range <= 0 then
        return "range unknown"
    end
    if range >= 5 and range <= 7 then
        return "ideal 5-7"
    end
    if range > 7 and range <= 10 then
        return "too far 7-10"
    end
    if atRange then
        return "ranged"
    end
    return "far"
end

local function getRangeState(range, inMelee, atRange, deadzone, farRange)
    if inMelee then
        return "MELEE", RANGE_STATES.MELEE
    end
    if deadzone then
        return "DEAD", RANGE_STATES.DEAD
    end
    if not range or range <= 0 then
        return "UNKNOWN", RANGE_STATES.UNKNOWN
    end
    if range >= 5 and range <= 7 then
        return "IDEAL", RANGE_STATES.IDEAL
    end
    if range > 7 and range <= 10 then
        return "FAR", RANGE_STATES.FAR
    end
    if farRange then
        return "OUT", RANGE_STATES.OUT
    end
    if atRange then
        return "RANGED", RANGE_STATES.RANGED
    end
    return "OUT", RANGE_STATES.OUT
end

local function rangeBudgetMultiplier(rangeState)
    if rangeState == "IDEAL" then
        return 0.55
    end
    if rangeState == "FAR" then
        return 0.80
    end
    return 1
end

local function severityColor(severity)
    if severity == "RED" then return THEME.red end
    if severity == "ORANGE" then return THEME.orange end
    if severity == "YELLOW" then return THEME.yellow end
    if severity == "GREEN" then return THEME.green end
    return THEME.gray
end

local function getLastAutoBadge()
    local tracker = NS.HunterClipTracker
    if not tracker or not tracker.GetLastAutoResult then
        return "AUTO --", THEME.gray
    end

    local result = tracker:GetLastAutoResult()
    if not result then
        return "AUTO --", THEME.gray
    end

    local clip = result.clipDuration or 0
    if clip <= 0.001 then
        if result.verdict == "HASTE" then
            return "AUTO HASTE RESET", THEME.gray
        elseif result.verdict == "SYNC" or result.verdict == "RESET" then
            return "AUTO SYNC", THEME.gray
        end
        return "AUTO CLEAN", THEME.green
    end

    return format("CLIP +%.2fs", clip), severityColor(result.severity)
end

local function setTextColor(t, color)
    t:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function setFrameColor(f, color)
    f:SetBackdropColor(color[1], color[2], color[3], 0.94)
    f:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

function Coach:MarkRaptorPending(now, meleeRemaining)
    now = now or GetTime()
    local hold = math_max(0.45, math_min(3, (meleeRemaining or 0) + 0.35))
    self.RaptorPendingStartedAt = self.RaptorPendingStartedAt or now
    self.RaptorPendingUntil = now + hold
end

function Coach:ClearRaptorPending()
    self.RaptorPendingUntil = nil
    self.RaptorPendingStartedAt = nil
end

function Coach:IsRaptorPending(now)
    return self.RaptorPendingUntil and self.RaptorPendingUntil > (now or GetTime())
end

function Coach:Evaluate(unit)
    unit = unit or "target"
    local now = GetTime()
    local s = NS.cached_settings or {}

    local targetExists = Unit and Unit(unit):IsExists() or false
    local atRange = targetExists and HA.ArcaneShot and HA.ArcaneShot:IsInRange(unit) or false
    local inMelee = targetExists and HA.WingClip and HA.WingClip:IsInRange(unit) or false
    local targetRange = targetExists and getTargetRange(unit) or 0
    local deadzone = targetExists and (not atRange) and (not inMelee) and (targetRange <= 0 or targetRange <= 8)
    local farRange = targetExists and (not atRange) and (not inMelee) and targetRange > 8
    local rangeBucket = getRangeBucket(targetRange, inMelee, atRange, deadzone)
    local rangeState, rangeInfo = getRangeState(targetRange, inMelee, atRange, deadzone, farRange)

    local shootRemaining = Player and Player.GetSwingShoot and (Player:GetSwingShoot() or 0) or 0
    local rangedSpeed, rangedWindup, haste = getRangedTiming()
    local exitBuffer = settingSeconds("weave_exit_buffer_ms", 300)
    local roundTrip = settingSeconds("weave_round_trip_ms", 900)
    local rangedDeadline = shootRemaining - rangedWindup - exitBuffer
    local safeWindow = math_max(0, rangedDeadline)
    local requiredWindow = roundTrip * rangeBudgetMultiplier(rangeState)
    local warningWindow = requiredWindow * 0.55

    local raptorCD = cooldownRemaining(HA.RaptorStrike)
    local raptorReady = targetExists and isReadySoon(HA.RaptorStrike, unit, 0.15)
    local raptorQueued = HA.RaptorStrike and HA.RaptorStrike.IsSpellCurrent and HA.RaptorStrike:IsSpellCurrent() or false
    local meleeRemaining, meleeDuration = getMeleeSwingRemaining()
    local shooting = Player and Player.IsShooting and Player:IsShooting() or false
    local recentRaptorPrompt = self.LastRaptorPromptAt and (now - self.LastRaptorPromptAt) <= 1.2

    if inMelee and raptorQueued then
        self:MarkRaptorPending(now, meleeRemaining)
    elseif inMelee and recentRaptorPrompt and raptorCD > 0.15 and meleeRemaining > 0.05 then
        self:MarkRaptorPending(now, meleeRemaining)
    elseif self.RaptorPendingUntil and self.RaptorPendingUntil <= now then
        self:ClearRaptorPending()
    end

    local raptorPending = self:IsRaptorPending(now)
    if raptorPending and self.LastMeleeRemaining and meleeRemaining > self.LastMeleeRemaining + 0.35
       and now - (self.RaptorPendingStartedAt or now) > 0.10 then
        self:ClearRaptorPending()
        raptorPending = false
    end

    local state = "GRAY"
    local action = "HOLD RANGE"
    local reason

    if not s.show_melee_weave_coach then
        reason = "Disabled"
    elseif not targetExists then
        reason = "No target"
    elseif (inMelee or deadzone) and rangedDeadline <= 0 and not raptorPending then
        state = "RED"
        action = "BACK OUT"
        reason = "Ranged Auto deadline"
    elseif deadzone then
        state = "RED"
        action = "MOVE OUT"
        reason = "Deadzone"
    elseif inMelee then
        if raptorPending or raptorQueued then
            state = "ORANGE"
            action = "WAIT HIT"
            reason = "Raptor queued - hold melee"
        elseif raptorReady and safeWindow > 0.05 and (meleeRemaining <= 0 or meleeRemaining <= safeWindow + 0.20) then
            state = "GREEN"
            action = "RAPTOR"
            reason = "Queue Raptor now"
            self.LastRaptorPromptAt = now
        else
            state = "RED"
            action = "BACK OUT"
            if raptorCD > 0.15 then
                reason = "Raptor cooldown - leave melee"
            elseif meleeRemaining > safeWindow then
                reason = "Melee swing too late"
            else
                reason = "Bad melee window"
            end
        end
    elseif farRange then
        state = "GRAY"
        action = "HOLD RANGE"
        reason = "Out of range"
    elseif not shooting then
        state = "GRAY"
        action = "START AUTO"
        reason = "Auto Shot is not active"
    elseif atRange then
        if raptorCD > 0.15 then
            state = "GRAY"
            action = "HOLD RANGE"
            reason = "Raptor cooldown"
        elseif rangeState == "FAR" then
            state = "RED"
            action = "CLOSER"
            reason = "Need 5-7yd"
        elseif safeWindow >= requiredWindow then
            state = "GREEN"
            action = "GO IN"
            reason = "Safe weave window"
        elseif safeWindow >= warningWindow then
            state = "ORANGE"
            action = "READY"
            reason = "Window soon"
        elseif rangedDeadline > 0 then
            state = "GRAY"
            action = "HOLD RANGE"
            reason = "Window too small"
        else
            state = "GRAY"
            action = "HOLD RANGE"
            reason = "Waiting for Auto"
        end
    else
        state = "GRAY"
        action = "HOLD RANGE"
        reason = "Out of range"
    end

    local ringTotal = math_max(0.1, rangedSpeed - rangedWindup - exitBuffer)
    local ringRemaining = math_min(ringTotal, safeWindow)
    local ringLabel = "Ranged deadline"
    if state == "GRAY" and raptorCD > 0.15 and raptorCD < 999 then
        ringTotal = 6
        ringRemaining = math_min(6, raptorCD)
        ringLabel = "Raptor cooldown"
    end

    self.State = {
        now = now,
        state = state,
        action = action,
        reason = reason,
        color = STATES[state].color,
        targetExists = targetExists,
        atRange = atRange,
        inMelee = inMelee,
        deadzone = deadzone,
        farRange = farRange,
        targetRange = targetRange,
        rangeBucket = rangeBucket,
        rangeState = rangeState,
        rangeColor = rangeInfo.color,
        rangeLabel = rangeInfo.label,
        shootRemaining = shootRemaining,
        rangedSpeed = rangedSpeed,
        rangedWindup = rangedWindup,
        haste = haste,
        exitBuffer = exitBuffer,
        roundTrip = roundTrip,
        requiredWindow = requiredWindow,
        warningWindow = warningWindow,
        rangedDeadline = rangedDeadline,
        safeWindow = safeWindow,
        raptorCD = raptorCD,
        raptorReady = raptorReady,
        raptorQueued = raptorQueued,
        raptorPending = raptorPending,
        meleeRemaining = meleeRemaining,
        meleeDuration = meleeDuration,
        ringTotal = ringTotal,
        ringRemaining = ringRemaining,
        ringLabel = ringLabel,
    }
    self.LastMeleeRemaining = meleeRemaining
    return self.State
end

function Coach:Create()
    if self.Frame then return self.Frame end

    local f = CreateFrame("Frame", "HunterMeleeWeaveCoachFrame", UIParent, "BackdropTemplate")
    f:SetSize(204, 246)
    f:SetPoint("CENTER", UIParent, "CENTER", 270, 0)
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

    local close = CreateFrame("Button", nil, f)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", -4, -4)
    close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    close.text:SetPoint("CENTER")
    close.text:SetText("x")
    setTextColor(close.text, THEME.dim)
    close:SetScript("OnClick", function() f:Hide() end)

    f.rangeBadge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.rangeBadge:SetSize(184, 26)
    f.rangeBadge:SetPoint("TOP", f, "TOP", 0, -8)
    f.rangeBadge:SetBackdrop(BACKDROP)
    setFrameColor(f.rangeBadge, THEME.gray)

    f.rangeText = f.rangeBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.rangeText:SetPoint("CENTER")
    f.rangeText:SetText("RANGE ?")
    setTextColor(f.rangeText, THEME.text)

    f.light = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.light:SetSize(144, 144)
    f.light:SetPoint("TOP", f.rangeBadge, "BOTTOM", 0, -7)
    f.light:SetBackdrop(BACKDROP)
    setFrameColor(f.light, THEME.gray)

    f.cooldown = CreateFrame("Cooldown", nil, f.light, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f.light)
    if f.cooldown.SetReverse then f.cooldown:SetReverse(true) end
    if f.cooldown.SetDrawEdge then f.cooldown:SetDrawEdge(false) end
    if f.cooldown.SetDrawBling then f.cooldown:SetDrawBling(false) end
    if f.cooldown.SetDrawSwipe then f.cooldown:SetDrawSwipe(true) end

    f.big = f.light:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.big:SetPoint("CENTER", f.light, "CENTER", 0, 18)
    f.big:SetScale(1.8)
    f.big:SetText("HOLD")
    setTextColor(f.big, THEME.text)

    f.action = f.light:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.action:SetPoint("TOP", f.big, "BOTTOM", 0, -4)
    f.action:SetText("HOLD RANGE")
    setTextColor(f.action, THEME.text)

    f.timer = f.light:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.timer:SetPoint("TOP", f.action, "BOTTOM", 0, -6)
    f.timer:SetText("0.00s")
    setTextColor(f.timer, THEME.text)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetSize(184, 8)
    f.bar:SetPoint("TOP", f.light, "BOTTOM", 0, -8)
    f.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(0)

    f.barBg = f.bar:CreateTexture(nil, "BACKGROUND")
    f.barBg:SetAllPoints(f.bar)
    f.barBg:SetColorTexture(0, 0, 0, 0.65)

    f.clipBadge = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.clipBadge:SetSize(184, 24)
    f.clipBadge:SetPoint("TOP", f.bar, "BOTTOM", 0, -7)
    f.clipBadge:SetBackdrop(BACKDROP)
    setFrameColor(f.clipBadge, THEME.gray)

    f.clipText = f.clipBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.clipText:SetPoint("CENTER")
    f.clipText:SetText("AUTO --")
    setTextColor(f.clipText, THEME.text)

    self.Frame = f
    return f
end

function Coach:Refresh()
    if not self.Frame or not self.Frame:IsShown() then return end
    if NS.refresh_settings then NS.refresh_settings() end

    local d = self:Evaluate("target")
    local f = self.Frame
    local st = STATES[d.state] or STATES.GRAY
    local color = d.color or THEME.gray
    local rangeColor = d.rangeColor or THEME.gray
    local clipText, clipColor = getLastAutoBadge()

    setFrameColor(f.light, color)
    setFrameColor(f.rangeBadge, rangeColor)
    setFrameColor(f.clipBadge, clipColor)
    f.big:SetText(st.title)
    f.action:SetText(d.action)
    f.timer:SetText(fmtSeconds(d.ringRemaining))
    f.rangeText:SetText(format("%.1f YD  %s", d.targetRange or 0, d.rangeLabel or "range unknown"))
    f.clipText:SetText(clipText)

    f.bar:SetMinMaxValues(0, d.ringTotal or 1)
    f.bar:SetValue(d.ringRemaining or 0)
    f.bar:SetStatusBarColor(color[1], color[2], color[3], 1)

    if f.cooldown then
        if d.ringRemaining and d.ringRemaining > 0 and d.ringTotal and d.ringTotal > 0 then
            local start = GetTime() - ((d.ringTotal or 0) - (d.ringRemaining or 0))
            f.cooldown:SetCooldown(start, d.ringTotal)
        else
            f.cooldown:SetCooldown(0, 0)
        end
        if f.cooldown.SetSwipeColor then
            f.cooldown:SetSwipeColor(0, 0, 0, 0.42)
        end
    end
end

function Coach:Show()
    self:Create()
    self.Frame:Show()
    self.IsVisible = true
    self:Refresh()
end

function Coach:Hide()
    if self.Frame then self.Frame:Hide() end
    self.IsVisible = false
end

function Coach:GetState()
    return self.State
end

NS.HunterMeleeWeaveCoach = Coach

local playerGUID = nil
local function OnCLEU()
    if not (NS.cached_settings and NS.cached_settings.show_melee_weave_coach) then return end
    if not CombatLogGetCurrentEventInfo then return end
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if not playerGUID and UnitGUID then playerGUID = UnitGUID("player") end
    if sourceGUID ~= playerGUID then return end

    local now = GetTime()
    if (spellID == 2973 or spellName == RAPTOR_NAME)
       and (subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED" or subevent == "SPELL_ABSORBED") then
        Coach:ClearRaptorPending()
    elseif Coach:IsRaptorPending(now) and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED")
       and now - (Coach.RaptorPendingStartedAt or now) > 0.10 then
        Coach:ClearRaptorPending()
    end
end

if Listener and Listener.Add then
    Listener:Add("MENAGERIE_HUNTER_WEAVE_CLEU", "COMBAT_LOG_EVENT_UNFILTERED", OnCLEU)
end

local lastToggle = nil
local watch = CreateFrame("Frame")
watch.elapsed = 0
watch:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.05 then
        self.elapsed = 0
        local show = NS.cached_settings and NS.cached_settings.show_melee_weave_coach or false
        if show ~= lastToggle then
            lastToggle = show
            if show then Coach:Show() else Coach:Hide() end
        end
        if show then Coach:Refresh() end
    end
end)

print("|cFF00FF00[Menagerie Hunter]|r Melee weave coach loaded")
