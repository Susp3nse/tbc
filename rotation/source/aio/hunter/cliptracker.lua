-- Hunter Auto Shot Clip Tracker (AIO)
-- Adapted from standalone Hunter_ClipTracker.lua
--
-- Tracks auto shot clipping: what caused each clip, how long it was,
-- and whether it was worth it. Integrates with the Action framework.
--
-- Settings keys (from schema.lua Tab 5 "Pet & Diag"):
--   clip_tracker_enabled  — master toggle for clip tracking
--   show_clip_tracker     — show/hide the clip tracker UI window
--   clip_print_summary    — print clip summary after combat
--   clip_threshold_1      — green/yellow severity boundary (ms)
--   clip_threshold_2      — yellow/orange severity boundary (ms)
--   clip_threshold_3      — orange/red severity boundary (ms)

local _G, pairs, ipairs, tostring, format, table, wipe =
      _G, pairs, ipairs, tostring, string.format, table, _G.wipe

local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter ClipTracker]|r Core module not loaded!")
    return
end

local Listener              = A.Listener
local GetTime               = _G.GetTime
local GetLatency            = A.GetLatency
local GetPing               = A.GetPing
local CreateFrame           = _G.CreateFrame
local UIParent              = _G.UIParent
local UnitRangedDamage      = _G.UnitRangedDamage
local UnitGUID              = _G.UnitGUID
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local date                  = _G.date
local time                  = _G.time
local print                 = _G.print
local GetSpellInfo          = _G.GetSpellInfo
local GetFramerate          = _G.GetFramerate

-- Melee-only spells that prove the player was in melee range
local MeleeSpellNames = {
    ["Raptor Strike"] = true,
    ["Mongoose Bite"] = true,
    ["Wing Clip"] = true,
    ["Counterattack"] = true,
}

-- ============================================================================
-- THEME (matches settings.lua for visual consistency)
-- ============================================================================
local THEME = {
    bg          = { 0.031, 0.031, 0.039, 0.97 },
    bg_light    = { 0.047, 0.047, 0.059, 1 },
    bg_widget   = { 0.059, 0.059, 0.075, 1 },
    bg_hover    = { 0.075, 0.075, 0.086, 1 },
    border      = { 0.118, 0.118, 0.149, 1 },
    accent      = { 0.424, 0.388, 1.0, 1 },
    text        = { 0.863, 0.863, 0.894, 1 },
    text_dim    = { 0.580, 0.580, 0.659, 1 },
}

local BACKDROP_THIN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local FRAME_WIDTH = 360
local LOG_TEXT_WIDTH = 302

local function create_theme_button(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop(BACKDROP_THIN)
    btn:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
    btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(THEME.bg_hover[1], THEME.bg_hover[2], THEME.bg_hover[3], 1)
        self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
        self:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)
    end)

    return btn
end

-- ============================================================================
-- MODULE STATE
-- ============================================================================

local ClipTracker = {
    -- Timing state
    LastAutoShotTime = nil,
    LastExpectedSpeed = nil,
    IsFirstShot = true,

    -- Cast tracking
    CurrentCastSpell = nil,
    CurrentCastStartTime = nil,
    CurrentCastSuggestionLag = nil,
    LastTrackedCastEndTime = nil,
    LastTrackedCastName = nil,
    LastTrackedCastSuggestionLag = nil,

    -- Rotation suggestion tracking
    LastSuggestion = nil,
    LastSuggestionTime = nil,
    LastSuggestionSwing = nil,

    -- Melee/movement interval tracking (between auto shots)
    WasInMeleeInterval = false,
    WasMovingInInterval = false,
    MeleeSpellsDuringInterval = {},
    MoveStartTime = nil,
    IsCurrentlyMoving = false,

    -- Log buffer
    ClipLog = {},
    ClipLogMax = 5000,
    LastAutoResult = nil,

    -- Combat session stats
    CombatStats = {
        totalClips = 0,
        totalClipTime = 0,
        worstClip = 0,
        worstClipCause = "",
        clipsBySpell = {},
        clipsBySeverity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        autoShotCount = 0,
        combatStartTime = 0,
        clipsByHaste = {
            BASE    = { count = 0, totalTime = 0 },
            LIGHT   = { count = 0, totalTime = 0 },
            MAJOR   = { count = 0, totalTime = 0 },
            DOUBLE  = { count = 0, totalTime = 0 },
            PEAK    = { count = 0, totalTime = 0 },
            ULTRA   = { count = 0, totalTime = 0 },
            UNKNOWN = { count = 0, totalTime = 0 },
        },
        autoShotsByHaste = {
            BASE = 0, LIGHT = 0, MAJOR = 0, DOUBLE = 0, PEAK = 0, ULTRA = 0, UNKNOWN = 0,
        },
    },

    -- UI state
    IsVisible = false,
    IsPaused = false,
    Frame = nil,
    ScrollFrame = nil,
    LogText = nil,

    -- Severity filter state
    SeverityEnabled = {
        GREEN = false,
        YELLOW = true,
        ORANGE = true,
        RED = true,
    },

    -- Severity colors
    SeverityColors = {
        GREEN  = { 0, 1, 0 },
        YELLOW = { 1, 1, 0 },
        ORANGE = { 1, 0.54, 0 },
        RED    = { 1, 0, 0 },
    },
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local wallClockOffset = ((time and time()) or 0) - GetTime()

local function RefreshWallClockOffset()
    wallClockOffset = ((time and time()) or 0) - GetTime()
end

local function GetTimestamp()
    local gameTime = GetTime()
    if date and time then
        local wall = wallClockOffset + gameTime
        local sec = math.floor(wall)
        local centis = math.floor((wall - sec) * 100 + 0.5)
        if centis >= 100 then
            sec = sec + 1
            centis = 0
        end
        return format("%s.%02d", date("%H:%M:%S", sec), centis)
    end
    return format("%.3f", gameTime)
end

-- Dynamic jitter floor: filters server-tick + frame quantization + ping variance.
-- Scales with ping so users on worse networks get a wider noise floor automatically.
-- NOT based on SpellQueueWindow — that's input buffer, not jitter, and would make
-- SQW-comparison parses apples-to-oranges.
local function GetJitterFloor()
    local ping = GetPing() or 0
    return math.max(0.05, ping / 2 + 0.04)
end

local function ComputeHasteBucket(rangedSpeed)
    if not rangedSpeed or rangedSpeed == 0 then return "UNKNOWN" end
    if rangedSpeed >= 2.35 then return "BASE"
    elseif rangedSpeed >= 2.00 then return "LIGHT"
    elseif rangedSpeed >= 1.70 then return "MAJOR"
    elseif rangedSpeed >= 1.40 then return "DOUBLE"
    elseif rangedSpeed >= 1.15 then return "PEAK"
    else return "ULTRA"
    end
end

local SHORT_SPELL_NAMES = {
    ["Auto Shot"] = "Auto",
    ["Steady Shot"] = "Steady",
    ["Multi-Shot"] = "Multi",
    ["Arcane Shot"] = "Arcane",
    ["Kill Command"] = "KC",
    ["Bestial Wrath"] = "BW",
    ["Rapid Fire"] = "RF",
}

local SEVERITY_LABELS = {
    GREEN = "G",
    YELLOW = "Y",
    ORANGE = "O",
    RED = "R",
}

local VERDICT_LABELS = {
    TRIVIAL = "trivial",
    NECESSARY = "needed",
    WORTH_IT = "worth",
    QUESTIONABLE = "maybe",
    BAD_CLIP = "bad",
}

local function ShortText(text, maxLen)
    text = tostring(text or "--")
    if string.len(text) <= maxLen then return text end
    return string.sub(text, 1, math.max(1, maxLen - 1)) .. "~"
end

local function ShortSpellName(spellName)
    if not spellName or spellName == "" then return "Unknown" end
    return SHORT_SPELL_NAMES[spellName] or ShortText(spellName, 14)
end

local AUTO_SHOT_SPELL_IDS = {
    [75]   = true, -- Auto Shot combat log spell
    [2480] = true, -- Shoot Bow
    [7919] = true, -- Shoot Crossbow
    [7918] = true, -- Shoot Gun
    [3018] = true, -- Shoot
    [5019] = true, -- Shoot/Wand
}

local AUTO_SHOT_SPELL_NAMES = {
    ["Auto Shot"] = true,
    ["Shoot Bow"] = true,
    ["Shoot Crossbow"] = true,
    ["Shoot Gun"] = true,
    ["Shoot"] = true,
}

local function IsAutoShotSpell(spellID, spellName)
    return (spellID and AUTO_SHOT_SPELL_IDS[spellID]) or (spellName and AUTO_SHOT_SPELL_NAMES[spellName]) or false
end

local function SuggestionLagFor(spellName, now)
    if not spellName or not ClipTracker.LastSuggestionTime then return nil end
    if ClipTracker.LastSuggestion ~= spellName then return nil end
    local lag = now - ClipTracker.LastSuggestionTime
    if lag < 0 or lag > 2.0 then return nil end
    return lag
end

local MIN_GREEN_MS = 150
local MIN_YELLOW_MS = 250
local MIN_ORANGE_MS = 500

local function ThresholdMs(value, fallback)
    value = tonumber(value)
    if not value or value <= 0 then return fallback end
    return value
end

local function GetSeverity(delay)
    local s = NS.cached_settings or {}
    local minFloorMs = GetJitterFloor() * 1000
    local t1ms = math.max(ThresholdMs(s.clip_threshold_1, MIN_GREEN_MS), MIN_GREEN_MS, minFloorMs)
    local t2ms = math.max(ThresholdMs(s.clip_threshold_2, MIN_YELLOW_MS), MIN_YELLOW_MS, t1ms + 50)
    local t3ms = math.max(ThresholdMs(s.clip_threshold_3, MIN_ORANGE_MS), MIN_ORANGE_MS, t2ms + 100)
    local t1 = t1ms / 1000
    local t2 = t2ms / 1000
    local t3 = t3ms / 1000
    if delay <= t1 then return "GREEN"
    elseif delay <= t2 then return "YELLOW"
    elseif delay <= t3 then return "ORANGE"
    else return "RED"
    end
end

local function GetSpellCastTime(spellName)
    if not spellName then return 0 end
    if spellName == "Steady Shot" or spellName == "Multi-Shot" then
        local speed = UnitRangedDamage("player") or 0
        local baseSpeed = (NS.cached_settings and NS.cached_settings.weapon_speed) or speed
        local haste = speed > 0 and baseSpeed > 0 and (baseSpeed / speed) or 1
        if haste <= 0 then haste = 1 end
        if spellName == "Steady Shot" then return 1.5 / haste end
        return 0.5 / haste
    end
    local name, _, _, castTime = GetSpellInfo(spellName)
    if castTime and castTime > 0 then return castTime / 1000 end
    return 0
end

local function EstimatedCastStartLag(spellName, eventTime)
    local castTime = GetSpellCastTime(spellName)
    return SuggestionLagFor(spellName, eventTime - (castTime or 0))
end

local function EvaluateWorth(clipDuration, causeSpell, wasMoving)
    if wasMoving and (not causeSpell or causeSpell == "Movement") then
        return "NECESSARY"
    end

    -- Melee interlude: can't auto shot while in melee range
    if causeSpell and causeSpell:find("^Melee") then
        return "NECESSARY"
    end

    if clipDuration <= GetJitterFloor() then
        return "TRIVIAL"
    end

    if causeSpell and causeSpell ~= "Unknown" and causeSpell ~= "Movement" then
        -- Check always-worth spells by name lookup
        local alwaysWorth = {
            ["Kill Command"] = true,
            ["Bestial Wrath"] = true,
            ["Rapid Fire"] = true,
            ["Intimidation"] = true,
            ["Mend Pet"] = true,
        }
        if alwaysWorth[causeSpell] then
            return "WORTH_IT"
        end

        local castTime = GetSpellCastTime(causeSpell)
        if castTime <= 0 then
            -- Instant cast spell with significant clip
            if clipDuration > 0.2 then
                return "NOT_WORTH"
            else
                return "TRIVIAL"
            end
        end

        -- Overhead ratio: clip time as fraction of cast time
        local ratio = clipDuration / castTime
        if ratio < 0.15 then
            return "WORTH_IT"
        elseif ratio < 0.30 then
            return "MARGINAL"
        else
            return "NOT_WORTH"
        end
    end

    return "UNKNOWN"
end

-- ============================================================================
-- CORE CLIP DETECTION
-- ============================================================================

function ClipTracker:IsEnabled()
    return NS.cached_settings.clip_tracker_enabled or false
end

function ClipTracker:ResetCombatStats()
    self.CombatStats = {
        totalClips = 0,
        totalClipTime = 0,
        worstClip = 0,
        worstClipCause = "",
        clipsBySpell = {},
        clipsBySeverity = { GREEN = 0, YELLOW = 0, ORANGE = 0, RED = 0 },
        autoShotCount = 0,
        combatStartTime = GetTime(),
        clipsByHaste = {
            BASE    = { count = 0, totalTime = 0 },
            LIGHT   = { count = 0, totalTime = 0 },
            MAJOR   = { count = 0, totalTime = 0 },
            DOUBLE  = { count = 0, totalTime = 0 },
            PEAK    = { count = 0, totalTime = 0 },
            ULTRA   = { count = 0, totalTime = 0 },
            UNKNOWN = { count = 0, totalTime = 0 },
        },
        autoShotsByHaste = {
            BASE = 0, LIGHT = 0, MAJOR = 0, DOUBLE = 0, PEAK = 0, ULTRA = 0, UNKNOWN = 0,
        },
    }
    self.IsFirstShot = true
    self.LastAutoShotTime = nil
    self.LastExpectedSpeed = nil
    self.CurrentCastSpell = nil
    self.CurrentCastStartTime = nil
    self.CurrentCastSuggestionLag = nil
    self.LastTrackedCastEndTime = nil
    self.LastTrackedCastName = nil
    self.LastTrackedCastSuggestionLag = nil
    self.LastSuggestion = nil
    self.LastSuggestionTime = nil
    self.LastSuggestionSwing = nil
    self.LastAutoResult = nil
    self:ResetIntervalState()
end

function ClipTracker:ResetIntervalState()
    self.WasInMeleeInterval = false
    self.WasMovingInInterval = false
    wipe(self.MeleeSpellsDuringInterval)
end

function ClipTracker:OnAutoShotFired()
    if not self:IsEnabled() then return end

    local now = GetTime()
    self.CombatStats.autoShotCount = self.CombatStats.autoShotCount + 1

    -- Increment per-bucket auto-shot count using current speed (for per-bucket rate denominator)
    local curSpeed = UnitRangedDamage("player") or 3.0
    local curBucket = ComputeHasteBucket(curSpeed)
    self.CombatStats.autoShotsByHaste[curBucket] = (self.CombatStats.autoShotsByHaste[curBucket] or 0) + 1

    if self.IsFirstShot or not self.LastAutoShotTime or not self.LastExpectedSpeed then
        self.LastAutoShotTime = now
        self.LastExpectedSpeed = curSpeed
        self.IsFirstShot = false
        self.LastAutoResult = {
            rawTime = now,
            clipDuration = 0,
            severity = "GREEN",
            verdict = "SYNC",
            causeSpell = "First Auto",
            haste_bucket = curBucket,
        }
        self:ResetIntervalState()
        return
    end

    local elapsed = now - self.LastAutoShotTime
    local prevSpeed = self.LastExpectedSpeed

    -- Haste changes inside an Auto Shot interval make the expected interval
    -- ambiguous. Drop exactly that transition interval so haste gains/losses
    -- don't show up as player-caused clips.
    if curSpeed and prevSpeed and (curSpeed > prevSpeed + 0.05 or curSpeed < prevSpeed - 0.05) then
        self.LastAutoShotTime = now
        self.LastExpectedSpeed = curSpeed
        self.LastAutoResult = {
            rawTime = now,
            clipDuration = 0,
            severity = "GREEN",
            verdict = "HASTE",
            causeSpell = "Haste",
            haste_bucket = curBucket,
        }
        self:ResetIntervalState()
        return
    end

    local expectedSpeed = prevSpeed
    local delay = elapsed - expectedSpeed

    -- Discard unreasonable values (combat-join gap, target swap, death, etc.).
    -- A real clip is bounded by the slowest cast (~2s) plus headroom; anything > 4s is a tracking artifact.
    if delay > 4 or delay < -1 then
        self.LastAutoShotTime = now
        self.LastExpectedSpeed = curSpeed
        self.LastAutoResult = {
            rawTime = now,
            clipDuration = 0,
            severity = "GREEN",
            verdict = "RESET",
            causeSpell = "Reset",
            haste_bucket = curBucket,
        }
        self:ResetIntervalState()
        return
    end

    -- Record speed at this shot for next comparison
    self.LastAutoShotTime = now
    self.LastExpectedSpeed = curSpeed
    local hasteBucket = ComputeHasteBucket(self.LastExpectedSpeed)

    -- Only record clips above the dynamic jitter floor (server-tick + frame + ping variance)
    if delay <= GetJitterFloor() then
        self.LastAutoResult = {
            timestamp = GetTimestamp(),
            rawTime = now,
            clipDuration = 0,
            expectedSpeed = expectedSpeed,
            actualInterval = elapsed,
            causeSpell = "Clean",
            causeCastTime = 0,
            severity = "GREEN",
            wasMoving = false,
            verdict = "CLEAN",
            haste_bucket = hasteBucket,
        }
        self:ResetIntervalState()
        return
    end

    -- Determine cause (priority: melee > cast-bar spell > movement > instant cast > unknown)
    local causeSpell = nil
    local causeCastTime = 0
    local causeInputLag = nil
    local hadMelee = #self.MeleeSpellsDuringInterval > 0

    -- Priority 1: Melee spells were cast during interval
    if hadMelee or self.WasInMeleeInterval then
        if hadMelee then
            causeSpell = "Melee (" .. self.MeleeSpellsDuringInterval[1].name .. ")"
        else
            causeSpell = "Melee"
        end
        causeCastTime = 0
    end

    -- Priority 2: Cast-bar spell (Steady Shot, etc.)
    if not causeSpell and self.CurrentCastSpell and self.CurrentCastStartTime then
        local castAge = now - self.CurrentCastStartTime
        if castAge < 5 then
            causeSpell = self.CurrentCastSpell
            causeCastTime = GetSpellCastTime(self.CurrentCastSpell)
            causeInputLag = self.CurrentCastSuggestionLag
        end
    end

    -- Priority 3: Movement during interval
    local wasMoving = false
    if self.WasMovingInInterval then
        wasMoving = true
    elseif self.IsCurrentlyMoving and self.MoveStartTime and (now - self.MoveStartTime) >= 0.25 then
        wasMoving = true
    end

    if not causeSpell and wasMoving then
        causeSpell = "Movement"
        causeCastTime = 0
    end

    -- Priority 4: most-recent completed cast (CLEU-tracked LastTrackedCastName is primary;
    -- A.LastPlayerCastName is a backup for any framework-tracked instants we missed).
    -- Freshness gate: max age = min(rangedSpeed, 1.5s) so OOC stale casts don't bleed in.
    if not causeSpell then
        local maxAge = math.min(self.LastExpectedSpeed or 1.5, 1.5)
        local lastEnd = self.LastTrackedCastEndTime or 0
        if lastEnd > 0 and (now - lastEnd) <= maxAge then
            local lastSpell = self.LastTrackedCastName or A.LastPlayerCastName
            if IsAutoShotSpell(nil, lastSpell) then
                lastSpell = nil
            end
            causeSpell = lastSpell
            if causeSpell then
                causeCastTime = GetSpellCastTime(causeSpell)
                causeInputLag = self.LastTrackedCastSuggestionLag
            end
        end
    end

    if wasMoving and not causeSpell then
        causeSpell = "Movement"
        causeCastTime = 0
    end

    if not causeSpell then
        causeSpell = "Unknown"
    end

    local severity = GetSeverity(delay)
    local verdict = EvaluateWorth(delay, causeSpell, wasMoving)

    -- Record clip event
    local sqwAtTime = tonumber(_G.GetCVar and _G.GetCVar("SpellQueueWindow")) or 0
    local latAtTime = GetLatency() or 0
    -- Window covers a full Steady Shot cycle (1.5s cast + buffer) so post-cast clips count as rotational.
    local isRotationalCall = (self.LastSuggestionTime or 0) >= (now - 2.0)

    local entry = {
        timestamp = GetTimestamp(),
        rawTime = now,
        clipDuration = delay,
        expectedSpeed = expectedSpeed,
        actualInterval = elapsed,
        causeSpell = causeSpell,
        causeCastTime = causeCastTime,
        causeInputLag = causeInputLag,
        severity = severity,
        wasMoving = wasMoving,
        verdict = verdict,
        sqw_at_time = sqwAtTime,
        latency_at_time = latAtTime,
        is_rotational_call = isRotationalCall,
        haste_bucket = hasteBucket,
    }

    table.insert(self.ClipLog, entry)
    self.LastAutoResult = entry
    while #self.ClipLog > self.ClipLogMax do
        table.remove(self.ClipLog, 1)
    end

    -- Update stats
    local stats = self.CombatStats
    stats.totalClips = stats.totalClips + 1
    stats.totalClipTime = stats.totalClipTime + delay
    stats.clipsBySeverity[severity] = (stats.clipsBySeverity[severity] or 0) + 1

    if delay > stats.worstClip then
        stats.worstClip = delay
        stats.worstClipCause = causeSpell
    end

    if not stats.clipsBySpell[causeSpell] then
        stats.clipsBySpell[causeSpell] = { count = 0, totalTime = 0 }
    end
    stats.clipsBySpell[causeSpell].count = stats.clipsBySpell[causeSpell].count + 1
    stats.clipsBySpell[causeSpell].totalTime = stats.clipsBySpell[causeSpell].totalTime + delay

    if not stats.clipsByHaste[hasteBucket] then
        stats.clipsByHaste[hasteBucket] = { count = 0, totalTime = 0 }
    end
    stats.clipsByHaste[hasteBucket].count = stats.clipsByHaste[hasteBucket].count + 1
    stats.clipsByHaste[hasteBucket].totalTime = stats.clipsByHaste[hasteBucket].totalTime + delay

    -- Update display
    if self.IsVisible and self.Frame and self.Frame:IsShown() then
        self:RefreshLogDisplay()
        self:UpdateStatsStrip()
    end

    -- Reset interval tracking for next auto shot
    self:ResetIntervalState()
end

function ClipTracker:RecordSuggestion(spellName, swingTimer)
    if not self:IsEnabled() then return end
    self.LastSuggestion = spellName
    self.LastSuggestionTime = GetTime()
    self.LastSuggestionSwing = swingTimer
end

-- ============================================================================
-- COMBAT SUMMARY
-- ============================================================================

function ClipTracker:GetRates()
    local stats = self.CombatStats
    local total = stats.autoShotCount or 0
    if total <= 0 then
        return { headline_rate = 0, real_rate = 0, noise_rate = 0 }
    end
    local sev = stats.clipsBySeverity or {}
    local realCount = (sev.YELLOW or 0) + (sev.ORANGE or 0) + (sev.RED or 0)
    local noiseCount = sev.GREEN or 0
    return {
        headline_rate = (stats.totalClips or 0) / total * 100,
        real_rate     = realCount / total * 100,
        noise_rate    = noiseCount / total * 100,
    }
end

function ClipTracker:PrintCombatSummary()
    if not self:IsEnabled() then return end
    if not NS.cached_settings.clip_print_summary then return end

    local stats = self.CombatStats
    if stats.autoShotCount == 0 then return end

    local combatDuration = GetTime() - stats.combatStartTime
    if combatDuration < 3 then return end

    local rates = self:GetRates()
    local avgPerShot = stats.totalClipTime / stats.autoShotCount
    local avgPerClip = stats.totalClips > 0 and (stats.totalClipTime / stats.totalClips) or 0
    local noiseCount = stats.clipsBySeverity.GREEN or 0

    print(format("|cffFF8000[ClipTracker]|r Combat Summary (%.1fs)", combatDuration))
    print(format("  Real Clip Rate: %.1f%% (Y+) | Total: %d | Noise (G): %d (%.1f%%)",
        rates.real_rate, stats.totalClips, noiseCount, rates.noise_rate))
    print(format("  Auto Shots: %d | Total Clip Time: %.2fs",
        stats.autoShotCount, stats.totalClipTime))
    print(format("  Avg Clip/Shot: %.3fs | Avg Clip (clipped only): %.3fs | Worst: %.3fs (%s)",
        avgPerShot, avgPerClip, stats.worstClip, stats.worstClipCause ~= "" and stats.worstClipCause or "N/A"))
    print(format("  Green: %d | Yellow: %d | Orange: %d | Red: %d",
        stats.clipsBySeverity.GREEN or 0, stats.clipsBySeverity.YELLOW or 0,
        stats.clipsBySeverity.ORANGE or 0, stats.clipsBySeverity.RED or 0))

    -- Clips by cause
    local causes = {}
    for spell, data in pairs(stats.clipsBySpell) do
        table.insert(causes, { spell = spell, count = data.count, totalTime = data.totalTime })
    end
    if #causes > 0 then
        table.sort(causes, function(a, b) return a.totalTime > b.totalTime end)
        print("  Clips by cause:")
        for _, c in ipairs(causes) do
            local avg = c.count > 0 and (c.totalTime / c.count) or 0
            print(format("    %s: %dx (%.2fs total, %.3fs avg)", c.spell, c.count, c.totalTime, avg))
        end
    end

    -- Clips by haste bucket
    local bucketOrder = { "BASE", "LIGHT", "MAJOR", "DOUBLE", "PEAK", "ULTRA", "UNKNOWN" }
    local anyBucket = false
    for _, b in ipairs(bucketOrder) do
        local d = stats.clipsByHaste[b]
        if d and d.count > 0 then anyBucket = true break end
    end
    if anyBucket then
        print("  Clips by haste bucket:")
        for _, b in ipairs(bucketOrder) do
            local d = stats.clipsByHaste[b]
            if d and d.count > 0 then
                local avg = d.totalTime / d.count
                local denom = stats.autoShotsByHaste[b] or 0
                local rate = denom > 0 and (d.count / denom * 100) or 0
                print(format("    %s: %dx (%.2fs total, %.3fs avg, %.1f%% rate)",
                    b, d.count, d.totalTime, avg, rate))
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

local pGUID = nil

local function OnCLEU()
    if not ClipTracker:IsEnabled() then return end
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if not pGUID then pGUID = UnitGUID("player") end
    if sourceGUID ~= pGUID then return end

    if subevent == "SPELL_CAST_START" then
        -- Track in-progress casts via CLEU (UNIT_SPELLCAST_START is unreliable in TBC Anniversary)
        if spellName and not IsAutoShotSpell(spellID, spellName) and not MeleeSpellNames[spellName] then
            local now = GetTime()
            ClipTracker.CurrentCastSpell = spellName
            ClipTracker.CurrentCastStartTime = now
            ClipTracker.CurrentCastSuggestionLag = SuggestionLagFor(spellName, now)
        end
    elseif subevent == "SPELL_CAST_SUCCESS" then
        if spellID == 75 then
            -- Auto Shot fired
            ClipTracker:OnAutoShotFired()
        elseif spellName and MeleeSpellNames[spellName] then
            -- Melee spell cast → proves we were in melee range
            table.insert(ClipTracker.MeleeSpellsDuringInterval, {
                name = spellName,
                time = GetTime(),
            })
            ClipTracker.WasInMeleeInterval = true
        elseif spellName then
            -- Track completed casts so the fallback attribution can find them.
            -- This fires reliably in TBC Anniversary for both instant casts (Arcane Shot, Aspect)
            -- and cast-time casts (Steady Shot, Multi Shot — at cast end).
            local now = GetTime()
            ClipTracker.LastTrackedCastName = spellName
            ClipTracker.LastTrackedCastEndTime = now
            ClipTracker.LastTrackedCastSuggestionLag = ClipTracker.CurrentCastSuggestionLag or EstimatedCastStartLag(spellName, now)
            ClipTracker.CurrentCastSpell = nil
            ClipTracker.CurrentCastStartTime = nil
            ClipTracker.CurrentCastSuggestionLag = nil
        end
    elseif subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
        -- Melee auto-attack → proves we were in melee range
        ClipTracker.WasInMeleeInterval = true
    end
end

local function OnSpellcastStart(unit, _, spellID)
    if unit ~= "player" then return end
    if not ClipTracker:IsEnabled() then return end
    local spellName = GetSpellInfo(spellID)
    if IsAutoShotSpell(spellID, spellName) then return end
    if spellName then
        local now = GetTime()
        ClipTracker.CurrentCastSpell = spellName
        ClipTracker.CurrentCastStartTime = now
        ClipTracker.CurrentCastSuggestionLag = SuggestionLagFor(spellName, now)
    end
end

local function OnSpellcastEnd(unit, _, spellID)
    if unit ~= "player" then return end
    if not ClipTracker:IsEnabled() then return end
    local spellName = GetSpellInfo(spellID)
    if IsAutoShotSpell(spellID, spellName) then return end
    if spellName then
        local now = GetTime()
        ClipTracker.LastTrackedCastEndTime = now
        ClipTracker.LastTrackedCastName = spellName
        ClipTracker.LastTrackedCastSuggestionLag = ClipTracker.CurrentCastSuggestionLag or EstimatedCastStartLag(spellName, now)
    end
    -- Clear current cast so the cast-bar branch doesn't grab a stale cast
    ClipTracker.CurrentCastSpell = nil
    ClipTracker.CurrentCastStartTime = nil
    ClipTracker.CurrentCastSuggestionLag = nil
end

local function OnCombatStart()
    if not ClipTracker:IsEnabled() then return end
    RefreshWallClockOffset()
    ClipTracker:ResetCombatStats()
end

local function OnCombatEnd()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker:PrintCombatSummary()
end

-- Movement tracking via start/stop events with duration filter
local function OnStartMoving()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker.MoveStartTime = GetTime()
    ClipTracker.IsCurrentlyMoving = true
end

local function OnStopMoving()
    if not ClipTracker:IsEnabled() then return end
    ClipTracker.IsCurrentlyMoving = false
    -- Only flag as real movement if we moved for >= 0.25s (filters turning, micro-adjustments)
    if ClipTracker.MoveStartTime and (GetTime() - ClipTracker.MoveStartTime) >= 0.25 then
        ClipTracker.WasMovingInInterval = true
    end
    ClipTracker.MoveStartTime = nil
end

-- Register events via Action Listener
Listener:Add("CLIPTRACKER_CLEU", "COMBAT_LOG_EVENT_UNFILTERED", OnCLEU)
Listener:Add("CLIPTRACKER_CAST", "UNIT_SPELLCAST_START", OnSpellcastStart)
Listener:Add("CLIPTRACKER_CAST_SUCCEEDED", "UNIT_SPELLCAST_SUCCEEDED", OnSpellcastEnd)
Listener:Add("CLIPTRACKER_CAST_STOP", "UNIT_SPELLCAST_STOP", OnSpellcastEnd)
Listener:Add("CLIPTRACKER_COMBAT_START", "PLAYER_REGEN_DISABLED", OnCombatStart)
Listener:Add("CLIPTRACKER_COMBAT_END", "PLAYER_REGEN_ENABLED", OnCombatEnd)
Listener:Add("CLIPTRACKER_MOVE_START", "PLAYER_STARTED_MOVING", OnStartMoving)
Listener:Add("CLIPTRACKER_MOVE_STOP", "PLAYER_STOPPED_MOVING", OnStopMoving)

-- ============================================================================
-- UI CREATION
-- ============================================================================

function ClipTracker:CreateFrame()
    if self.Frame then return self.Frame end

    local f = CreateFrame("Frame", "HunterClipTrackerFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, 430)
    f:SetPoint("CENTER", UIParent, "CENTER", 190, 0)
    f:SetBackdrop(BACKDROP_THIN)
    f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
    f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4])
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:Hide()

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -8)
    f.title:SetText("Clip Tracker")
    f.title:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3])

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -6, -6)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeText:SetPoint("CENTER")
    closeText:SetText("x")
    closeText:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3) end)
    close:SetScript("OnLeave", function() closeText:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]) end)

    -- Separator below title
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 1, -28)
    sep:SetPoint("TOPRIGHT", -1, -28)
    sep:SetHeight(1)
    sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    -- Severity filter buttons
    local severities = { "GREEN", "YELLOW", "ORANGE", "RED" }
    f.filterButtons = {}
    local btnWidth = 32

    for i, sev in ipairs(severities) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(btnWidth, 20)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * (btnWidth + 5), -34)
        btn:SetBackdrop(BACKDROP_THIN)
        btn:SetBackdropColor(THEME.bg_widget[1], THEME.bg_widget[2], THEME.bg_widget[3], 1)
        btn:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], 1)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetText(SEVERITY_LABELS[sev] or sev)
        local color = self.SeverityColors[sev]
        label:SetTextColor(color[1], color[2], color[3])

        btn.severity = sev
        btn.enabled = ClipTracker.SeverityEnabled[sev]
        if not btn.enabled then
            btn:SetAlpha(0.4)
        end

        btn:SetScript("OnClick", function(self)
            self.enabled = not self.enabled
            ClipTracker.SeverityEnabled[self.severity] = self.enabled
            if self.enabled then
                self:SetAlpha(1.0)
            else
                self:SetAlpha(0.4)
            end
            ClipTracker:RefreshLogDisplay()
        end)

        f.filterButtons[sev] = btn
    end

    -- Live stats strip
    local statsBg = f:CreateTexture(nil, "ARTWORK")
    statsBg:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -56)
    statsBg:SetSize(FRAME_WIDTH - 16, 28)
    statsBg:SetColorTexture(THEME.bg_light[1], THEME.bg_light[2], THEME.bg_light[3], 0.88)

    f.statsStrip = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.statsStrip:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -58)
    f.statsStrip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -58)
    f.statsStrip:SetJustifyH("LEFT")
    f.statsStrip:SetWordWrap(false)
    f.statsStrip:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    f.statsStrip:SetText("Real 0.0% | Noise 0.0% | Clips 0/0")

    f.statsStrip2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.statsStrip2:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70)
    f.statsStrip2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -70)
    f.statsStrip2:SetJustifyH("LEFT")
    f.statsStrip2:SetWordWrap(false)
    f.statsStrip2:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    f.statsStrip2:SetText("Worst 0ms N/A | P --ms FPS -- SQW --")

    -- Scroll frame for logs
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -90)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 38)

    -- Log text
    local logText = CreateFrame("EditBox", nil, sf)
    logText:SetMultiLine(true)
    logText:SetFontObject("GameFontHighlightSmall")
    logText:SetWidth(LOG_TEXT_WIDTH)
    logText:SetAutoFocus(false)
    logText:EnableMouse(true)
    logText:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(logText)

    self.ScrollFrame = sf
    self.LogText = logText

    -- Bottom separator
    local sep2 = f:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("BOTTOMLEFT", 1, 34)
    sep2:SetPoint("BOTTOMRIGHT", -1, 34)
    sep2:SetHeight(1)
    sep2:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

    -- Bottom buttons
    local pauseBtn = create_theme_button(f, 60, 22, "Pause")
    pauseBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    pauseBtn:SetScript("OnClick", function(self)
        ClipTracker.IsPaused = not ClipTracker.IsPaused
        if ClipTracker.IsPaused then
            self.label:SetText("Resume")
        else
            self.label:SetText("Pause")
        end
    end)
    f.pauseBtn = pauseBtn

    local clearBtn = create_theme_button(f, 55, 22, "Clear")
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 5, 0)
    clearBtn:SetScript("OnClick", function()
        wipe(ClipTracker.ClipLog)
        ClipTracker:ResetCombatStats()
        ClipTracker:RefreshLogDisplay()
        ClipTracker:UpdateStatsStrip()
    end)

    local exportBtn = create_theme_button(f, 60, 22, "Export")
    exportBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    exportBtn:SetScript("OnClick", function()
        ClipTracker:ShowExportWindow()
    end)

    -- Log count
    f.logCount = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.logCount:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 12)
    f.logCount:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
    f.logCount:SetText("0 clips")

    self.Frame = f
    return f
end

-- ============================================================================
-- DISPLAY REFRESH
-- ============================================================================

function ClipTracker:UpdateStatsStrip()
    if not self.Frame or not self.Frame.statsStrip then return end

    local stats = self.CombatStats
    local rates = self:GetRates()
    local worstCause = stats.worstClipCause ~= "" and ShortText(stats.worstClipCause, 18) or "N/A"
    local pingMs = math.floor(((GetPing() or 0) * 1000) + 0.5)
    local fps = math.floor((GetFramerate and GetFramerate() or 0) + 0.5)
    local sqw = tonumber(_G.GetCVar and _G.GetCVar("SpellQueueWindow")) or 0

    self.Frame.statsStrip:SetText(format(
        "Real %.1f%% | Noise %.1f%% | Clips %d/%d",
        rates.real_rate, rates.noise_rate, stats.totalClips, stats.autoShotCount))
    if self.Frame.statsStrip2 then
        self.Frame.statsStrip2:SetText(format(
            "Worst %dms %s | P %dms FPS %d SQW %d",
            math.floor((stats.worstClip or 0) * 1000 + 0.5), worstCause, pingMs, fps, sqw))
    end
end

function ClipTracker:RefreshLogDisplay()
    if not self.LogText then return end

    local lines = {}
    for _, entry in ipairs(self.ClipLog) do
        if self.SeverityEnabled[entry.severity] then
            local color = self.SeverityColors[entry.severity]
            local colorHex = format("|cff%02x%02x%02x",
                math.floor(color[1] * 255 + 0.5),
                math.floor(color[2] * 255 + 0.5),
                math.floor(color[3] * 255 + 0.5))

            local causeDetail = ShortSpellName(entry.causeSpell)
            if entry.causeCastTime and entry.causeCastTime > 0 then
                causeDetail = format("%s %.2fs", causeDetail, entry.causeCastTime)
            end
            causeDetail = ShortText(causeDetail, 16)
            local verdict = VERDICT_LABELS[entry.verdict] or ShortText(entry.verdict, 8)
            local clipMs = math.floor((entry.clipDuration or 0) * 1000 + 0.5)
            local severity = SEVERITY_LABELS[entry.severity] or entry.severity

            local line = format("%s%s  +%dms  %s  %-16s %s|r",
                colorHex, entry.timestamp or "?", clipMs, severity, causeDetail, verdict)
            table.insert(lines, line)
        end
    end

    self.LogText:SetText(table.concat(lines, "\n"))

    -- Update count
    if self.Frame and self.Frame.logCount then
        self.Frame.logCount:SetText(#self.ClipLog .. " clips")
    end

    -- Auto-scroll to bottom
    if self.ScrollFrame then
        C_Timer.After(0.01, function()
            if self.ScrollFrame then
                self.ScrollFrame:SetVerticalScroll(self.ScrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

-- ============================================================================
-- EXPORT WINDOW
-- ============================================================================

function ClipTracker:GetCSVExport()
    local lines = {}
    -- CSV header (new columns appended at end to preserve old-export parsers)
    table.insert(lines, "timestamp,clip_duration,expected_speed,actual_interval,cause_spell,cause_cast_time,severity,was_moving,verdict,sqw_at_time,latency_at_time,is_rotational_call,haste_bucket,raw_time,cause_input_lag")

    for _, entry in ipairs(self.ClipLog) do
        table.insert(lines, format("%s,%.4f,%.4f,%.4f,%s,%.4f,%s,%s,%s,%d,%.4f,%s,%s,%.3f,%.4f",
            entry.timestamp, entry.clipDuration, entry.expectedSpeed, entry.actualInterval,
            entry.causeSpell, entry.causeCastTime or 0, entry.severity,
            tostring(entry.wasMoving), entry.verdict,
            entry.sqw_at_time or 0, entry.latency_at_time or 0,
            tostring(entry.is_rotational_call or false),
            entry.haste_bucket or "UNKNOWN",
            entry.rawTime or 0,
            entry.causeInputLag or -1))
    end

    -- Append summary block
    local stats = self.CombatStats
    if stats.autoShotCount > 0 then
        local combatDuration = GetTime() - stats.combatStartTime
        local clipRate = stats.totalClips / stats.autoShotCount * 100
        local avgPerShot = stats.totalClipTime / stats.autoShotCount
        local avgPerClip = stats.totalClips > 0 and (stats.totalClipTime / stats.totalClips) or 0

        table.insert(lines, "")
        table.insert(lines, "--- COMBAT SUMMARY ---")
        table.insert(lines, format("Combat Duration: %.1fs", combatDuration))
        table.insert(lines, format("Auto Shots: %d", stats.autoShotCount))
        table.insert(lines, format("Clips: %d (%.1f%%)", stats.totalClips, clipRate))
        table.insert(lines, format("Total Clip Time: %.3fs", stats.totalClipTime))
        table.insert(lines, format("Avg Clip/Shot: %.4fs", avgPerShot))
        table.insert(lines, format("Avg Clip (clipped only): %.4fs", avgPerClip))
        table.insert(lines, format("Worst Clip: %.4fs (%s)", stats.worstClip, stats.worstClipCause))
        table.insert(lines, format("Green: %d | Yellow: %d | Orange: %d | Red: %d",
            stats.clipsBySeverity.GREEN or 0, stats.clipsBySeverity.YELLOW or 0,
            stats.clipsBySeverity.ORANGE or 0, stats.clipsBySeverity.RED or 0))

        for spell, data in pairs(stats.clipsBySpell) do
            local avg = data.count > 0 and (data.totalTime / data.count) or 0
            table.insert(lines, format("  %s: %dx (%.3fs total, %.4fs avg)", spell, data.count, data.totalTime, avg))
        end

        -- Per-haste-bucket summary
        table.insert(lines, "")
        table.insert(lines, "--- HASTE BUCKETS ---")
        local bucketOrder = { "BASE", "LIGHT", "MAJOR", "DOUBLE", "PEAK", "ULTRA", "UNKNOWN" }
        for _, b in ipairs(bucketOrder) do
            local d = stats.clipsByHaste[b]
            local denom = stats.autoShotsByHaste[b] or 0
            if (d and d.count > 0) or denom > 0 then
                local count = d and d.count or 0
                local totalTime = d and d.totalTime or 0
                local avg = count > 0 and (totalTime / count) or 0
                local rate = denom > 0 and (count / denom * 100) or 0
                table.insert(lines, format("  %s: %dx clips / %d shots (%.1f%% rate, %.3fs total, %.4fs avg)",
                    b, count, denom, rate, totalTime, avg))
            end
        end
    end

    return table.concat(lines, "\n")
end

function ClipTracker:ShowExportWindow()
    local text = self:GetCSVExport()
    if text == "" then
        text = "-- No clip data to export --"
    end

    local f = _G["HunterClipTrackerExportFrame"]
    if not f then
        f = CreateFrame("Frame", "HunterClipTrackerExportFrame", UIParent, "BackdropTemplate")
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetBackdrop(BACKDROP_THIN)
        f:SetBackdropColor(THEME.bg[1], THEME.bg[2], THEME.bg[3], THEME.bg[4])
        f:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4])
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT", 12, -8)
        f.title:SetText("Export Clip Data")
        f.title:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])

        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPRIGHT", -12, -12)
        hint:SetText("Select All (Ctrl+A) & Copy (Ctrl+C)")
        hint:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])

        -- Close button
        local closeBtn = CreateFrame("Button", nil, f)
        closeBtn:SetSize(22, 22)
        closeBtn:SetPoint("TOPRIGHT", -6, -6)
        local cx = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        cx:SetPoint("CENTER")
        cx:SetText("x")
        cx:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3])
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        closeBtn:SetScript("OnEnter", function() cx:SetTextColor(1, 0.3, 0.3) end)
        closeBtn:SetScript("OnLeave", function() cx:SetTextColor(THEME.text_dim[1], THEME.text_dim[2], THEME.text_dim[3]) end)

        -- Separator
        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("TOPLEFT", 1, -28)
        sep:SetPoint("TOPRIGHT", -1, -28)
        sep:SetHeight(1)
        sep:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 10, -34)
        sf:SetPoint("BOTTOMRIGHT", -30, 42)

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(540)
        eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.editBox = eb

        -- Bottom separator
        local sep2 = f:CreateTexture(nil, "ARTWORK")
        sep2:SetPoint("BOTTOMLEFT", 1, 36)
        sep2:SetPoint("BOTTOMRIGHT", -1, 36)
        sep2:SetHeight(1)
        sep2:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 1)

        local btn = create_theme_button(f, 100, 25, "Close")
        btn:SetPoint("BOTTOM", 0, 8)
        btn:SetScript("OnClick", function() f:Hide() end)
    end

    f.editBox:SetText(text)
    f.editBox:HighlightText()
    f.editBox:SetFocus()
    f:Show()
end

-- ============================================================================
-- SHOW / HIDE
-- ============================================================================

function ClipTracker:Show()
    if not self.Frame then
        self:CreateFrame()
    end
    self.Frame:Show()
    self.IsVisible = true
    self:RefreshLogDisplay()
    self:UpdateStatsStrip()
end

function ClipTracker:Hide()
    if self.Frame then
        self.Frame:Hide()
    end
    self.IsVisible = false
end

function ClipTracker:Toggle()
    if not self.Frame then
        self:CreateFrame()
    end
    if self.Frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ClipTracker:GetLastAutoResult()
    return self.LastAutoResult
end

-- ============================================================================
-- AUTO SHOW/HIDE FROM SCHEMA TOGGLE (show_clip_tracker)
-- ============================================================================

local lastToggleState = nil
local function CheckToggleState()
    local showTracker = NS.cached_settings.show_clip_tracker or false
    if showTracker ~= lastToggleState then
        lastToggleState = showTracker
        if showTracker then
            ClipTracker:Show()
        else
            ClipTracker:Hide()
        end
    end
end

local watchFrame = CreateFrame("Frame")
watchFrame.elapsed = 0
watchFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        CheckToggleState()
        -- Keep ping/fps live in the stats strip even when no clips are firing.
        if ClipTracker.IsVisible and ClipTracker.Frame and ClipTracker.Frame:IsShown() then
            ClipTracker:UpdateStatsStrip()
        end
    end
end)

-- ============================================================================
-- OFFLINE DUMP API
-- ============================================================================

local function deepcopy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local copy = {}
    seen[t] = copy
    for k, v in pairs(t) do
        copy[deepcopy(k, seen)] = deepcopy(v, seen)
    end
    return copy
end

function ClipTracker:DumpToSavedVar()
    _G.FluxAIOClipDumps = _G.FluxAIOClipDumps or {}
    table.insert(_G.FluxAIOClipDumps, {
        time    = date("%Y-%m-%d %H:%M:%S"),
        entries = deepcopy(self.ClipLog),
        stats   = deepcopy(self.CombatStats),
    })
    return #_G.FluxAIOClipDumps
end

-- ============================================================================
-- NAMESPACE REGISTRATION
-- ============================================================================

NS.HunterClipTracker = ClipTracker

print("|cFF00FF00[Flux AIO Hunter]|r Clip Tracker loaded")
