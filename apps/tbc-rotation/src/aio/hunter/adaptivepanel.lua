-- Hunter Adaptive Engine Live Panel
-- Shows the real-time state of the adaptive DPS engine: input stats, derived
-- damage/cast values, the per-tick scoring decision, and a ring buffer of
-- recent actually-fired specials. Read-only — does not affect rotation.
--
-- Toggle via schema setting "show_adaptive_panel" (Tab 5 "Pet & Diag").
-- Thin instance of NS.CreateLivePanel — the factory owns the frame, layout,
-- Export/Clear buttons, refresh loop, and toggle watch; build() emits content.

local _G, format = _G, string.format

local A = _G.Action
if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Hunter Adaptive Panel]|r Core module not loaded!")
    return
end
-- HunterAdaptive may not be loaded yet (Order 7 unstable sort). Late-bind in build().

local GetTime     = _G.GetTime
local GetCVar     = _G.GetCVar
local UnitRangedDamage = _G.UnitRangedDamage
local UnitRangedAttackPower = _G.UnitRangedAttackPower

local THEME = NS.Theme
if not THEME then
    print("|cFFFF0000[Menagerie Hunter Adaptive Panel]|r Theme module not loaded!")
    return
end
local THEME_STATE = THEME.state

if not NS.CreateLivePanel then
    print("|cFFFF0000[Menagerie Hunter Adaptive Panel]|r Live panel factory not loaded!")
    return
end

local function fmt(n, dec)
    if n == nil then return "--" end
    if type(n) ~= "number" then return tostring(n) end
    return format("%."..(dec or 0).."f", n)
end

-- Build a colorized status string for an option row.
local function optionLine(score, delay, jitterFloor, gated, isChosen)
    if gated then
        return format("%5s  (gated)", "--"), THEME.text_dim
    end
    local clip, color
    if delay <= jitterFloor + 0.001 then
        clip = "open"
        color = THEME_STATE.good
    elseif delay <= 0.3 then
        clip = format("clips %.2fs", delay)
        color = THEME_STATE.warn
    else
        clip = format("clips %.2fs", delay)
        color = THEME_STATE.bad
    end
    local line = format("%5d  d=%.2f  %s%s", score, delay, clip, isChosen and "  <" or "")
    if isChosen then color = THEME_STATE.chosen end
    return line, color
end

-- Reused per-frame scratch for the recent-fires line (avoid per-refresh alloc).
local fireCodes = {}

local function build(out)
    local HA = NS.HunterAdaptive
    if not HA or not HA.GetState then
        out:header("Adaptive")
        out:kv("Status", "waiting for engine", "dim")
        return
    end
    local State = HA.GetState()
    if not State or not State.lastDecision then
        out:header("Adaptive")
        out:kv("Status", "waiting for engine", "dim")
        return
    end

    -- Walk the schema to populate cached_settings (covers default values for keys
    -- the user never toggled). Then ForceRecompute reads fresh stats + uses real settings.
    if NS.refresh_settings then NS.refresh_settings() end
    if HA.ForceRecompute then HA.ForceRecompute() end

    local d = State.lastDecision

    -- INPUTS
    out:header("INPUTS")
    out:kv("RAP", fmt(State.rap, 0))
    local rapBase, rapPos, rapNeg = 0, 0, 0
    if UnitRangedAttackPower then
        rapBase, rapPos, rapNeg = UnitRangedAttackPower("player")
    end
    out:kv("RAP raw", format("%s +%s %s = %s",
        fmt(rapBase or 0, 0), fmt(rapPos or 0, 0), fmt(rapNeg or 0, 0), fmt(State.rap, 0)))
    out:kv("Paper", fmt(State.rangedDmgAvg, 1))
    out:kv("Base dmg", fmt(State.weaponDmgAvg, 1))
    out:kv("Crit", format("%.1f%%", State.critPct or 0))
    out:kv("Speed", format("%.3fs", State.rangedSpeed or 0))
    out:kv("Weapon", format("%.2fs", State.weaponBaseSpd or 0))
    out:kv("Haste", format("%.3fx", State.hasteMult or 1))

    local sqwMs = tonumber(GetCVar and GetCVar("SpellQueueWindow")) or 0
    local pingMs = math.floor(((A.GetPing and A.GetPing() or 0) * 1000) + 0.5)
    out:kv("SQW / Ping", format("%dms / %dms", sqwMs, pingMs))
    out:kv("Menagerie lat", format("%.3fs", (A.GetLatency and A.GetLatency() or 0)))
    out:spacer()

    -- API SANITY
    out:header("API SANITY")
    local rawSpeed, lowDmg, hiDmg, physicalBonusPos, physicalBonusNeg, percent
    if UnitRangedDamage then
        rawSpeed, lowDmg, hiDmg, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
    end
    out:kv("Ranged", format("speed %s low %s high %s",
        fmt(rawSpeed, 3), fmt(lowDmg, 1), fmt(hiDmg, 1)))
    out:kv("Mods", format("pos %s neg %s pct %s",
        fmt(physicalBonusPos or 0, 1), fmt(physicalBonusNeg or 0, 1), fmt(percent or 1, 3)))

    local auraDebug = HA.GetAuraDebug and HA.GetAuraDebug()
    if auraDebug then
        out:kv("Buff", auraDebug.firstLine or "--")
        out:kv("Tracked", auraDebug.trackedLine or "--")
        local nextIn = auraDebug.nextRecomputeIn or 0
        out:kv("Recheck", format("%s in %.1fs (%d buffs)",
            auraDebug.recomputeDue and "due" or "scheduled",
            math.max(0, nextIn),
            auraDebug.buffCount or 0),
            auraDebug.recomputeDue and THEME_STATE.warn or THEME_STATE.good)
    else
        out:kv("Buff", "--")
        out:kv("Tracked", "--")
        out:kv("Recheck", "--", "dim")
    end

    -- Equipped weapon item IDs (MH=16, OH=17, Ranged=18). Used to verify the
    -- Infinity Blade (30312) gate on the Mind-Control-break middleware.
    local getID = _G.GetInventoryItemID
    local mh  = (getID and getID("player", 16)) or 0
    local oh  = (getID and getID("player", 17)) or 0
    local rng = (getID and getID("player", 18)) or 0
    out:kv("Equip IDs", format("MH:%d OH:%d Rng:%d%s",
        mh, oh, rng, (mh == 30312 or oh == 30312) and "  BLADE!" or ""),
        (mh == 30312 or oh == 30312) and THEME_STATE.good or THEME.text)
    out:spacer()

    -- DAMAGE
    out:header("DAMAGE")
    out:kv("Auto", fmt(State.avgShootDmg, 0))
    out:kv("Steady", fmt(State.avgSteadyDmg, 0))
    out:kv("Multi", fmt(State.avgMultiDmg, 0))
    out:kv("Arcane", fmt(State.avgArcaneDmg, 0))
    out:kv("shootDPS", fmt(State.shootDPS, 0))
    out:kv("steadyDPS", fmt(State.steadyDPS, 0))
    out:spacer()

    -- CAST TIMES
    out:header("CAST TIMES")
    out:kv("steady", format("%.3fs", State.steadyCastTime or 0))
    out:kv("multi", format("%.3fs", State.multiCastTime or 0))
    out:kv("arcane", format("%.3fs", State.arcaneCastTime or 0))
    out:kv("windup", format("%.3fs", State.rangedWindup or 0))
    out:kv("catchup", State.useMultiForCatchup and "true" or "false",
        State.useMultiForCatchup and THEME.text or THEME_STATE.warn)
    out:spacer()

    -- DECISION
    out:header("DECISION")
    local jitter = 0.075
    local timerMode = tostring(d.shootTimerMode or "?")
    local timerState = tostring(d.shootTimerState or "?")
    timerMode = timerMode:gsub("inhouse", "ih")
    timerState = timerState:gsub("known:", "k:")
    timerState = timerState:gsub("action_fallback", "af")
    out:kv("tick", format("g%.2f s%.2f %s/%s -> %s",
        d.gcdRemaining or 0, d.shootRemaining or 0,
        timerMode, timerState,
        (d.chosenOpt or "?"):upper()))

    local shootTxt, shootCol = optionLine(d.rShoot, d.shootGCDDelay, jitter, false, d.chosenOpt == "shoot")
    out:kv(" Shoot", shootTxt, shootCol)
    local steadyTxt, steadyCol = optionLine(d.rSteady, d.steadyShootDelay, jitter, d.steadyClipGated, d.chosenOpt == "steady")
    out:kv(" Steady", steadyTxt, steadyCol)
    local multiTxt, multiCol = optionLine(d.rMulti, d.multiShootDelay, jitter,
        d.multiGated or d.multiClipGated or not d.expensiveManaOk, d.chosenOpt == "multi")
    out:kv(" Multi", multiTxt, multiCol)
    local arcaneTxt, arcaneCol = optionLine(d.rArcane, d.arcaneShootDelay, jitter,
        d.arcaneGated or d.arcaneClipGated, d.chosenOpt == "arcane")
    out:kv(" Arcane", arcaneTxt, arcaneCol)
    out:spacer()

    -- FIRES
    out:header("FIRES")
    local n = 0
    for _, e in ipairs(State.fireHistory or {}) do
        n = n + 1
        fireCodes[n] = e.code or "?"
    end
    for i = #fireCodes, n + 1, -1 do
        fireCodes[i] = nil
    end
    out:kv("Last", table.concat(fireCodes, " "))

    local now = GetTime()
    local elapsed = math.max(1, now - (State.fireCombatStart or now))
    local mins = elapsed / 60
    local fc = State.fireCounts or {}
    out:kv("Per min", format("S%.0f M%.0f A%.0f K%.0f St%.0f",
        (fc.steady or 0) / mins, (fc.multi or 0) / mins, (fc.arcane or 0) / mins,
        (fc.kc or 0) / mins, (fc.sting or 0) / mins))
    out:kv("Log", format("%d rows", #(State.decisionLog or {})))
end

local panel = NS.CreateLivePanel({
    title        = "Adaptive",
    setting_key  = "show_adaptive_panel",
    width        = 360,
    left_pad     = 12,
    label_width  = 88,
    value_x      = 104,
    min_height   = 560,
    section_bands = true,
    anchor       = { "CENTER", "CENTER", -190, 0 },
    build        = build,
    export       = function()
        local HA = NS.HunterAdaptive
        return HA and HA.GetDecisionCSV and HA.GetDecisionCSV() or "-- Adaptive decision log unavailable --"
    end,
    export_title = "Adaptive Decisions",
    on_clear     = function()
        local HA = NS.HunterAdaptive
        if HA and HA.ClearDecisionLog then HA.ClearDecisionLog() end
    end,
})

NS.HunterAdaptivePanel = panel

print("|cFF00FF00[Menagerie Hunter]|r Adaptive panel loaded")
