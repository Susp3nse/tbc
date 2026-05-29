--- Enhancement Shaman Module
--- Enhancement playstyle strategies: melee DPS, Stormstrike, shock weaving, totem twisting
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "SHAMAN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Enhancement]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Enhancement]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local resolve_totem_spell = NS.resolve_totem_spell
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format
local GetTime = _G.GetTime
local GetTotemInfo = _G.GetTotemInfo
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local UnitGUID = _G.UnitGUID
local IsCurrentSpell = _G.IsCurrentSpell
local C_Timer = _G.C_Timer
local AUTO_ATTACK_SPELL_ID = 6603

-- ============================================================================
-- TOTEM TWIST STATE (module-level, persists across frames)
-- Must be declared before context_builder so check_combat_reset is available
-- ============================================================================
-- Windfury + Grace of Air twist timing
local wf_twist = {
    last_wf_time = 0,       -- GetTime() when WF totem was last dropped
    last_default_time = 0,  -- GetTime() when default air totem was last dropped
    phase = "windfury",     -- "windfury" = WF is down, "default" = GoA/other is down
    initialized = false,
}

-- Fire Nova Totem twist timing
local fnt_twist = {
    last_drop_time = 0,     -- GetTime() when FNT was last dropped
    phase = "idle",         -- "idle" = ready for FNT, "waiting" = FNT fuse ticking, "default" = default fire totem phase
}

-- Reset twist state on combat exit
local last_combat_state = false

local function check_combat_reset(in_combat)
    if last_combat_state and not in_combat then
        -- Exiting combat: reset twist state
        wf_twist.initialized = false
        wf_twist.phase = "windfury"
        wf_twist.last_wf_time = 0
        wf_twist.last_default_time = 0
        fnt_twist.phase = "idle"
        fnt_twist.last_drop_time = 0
    end
    last_combat_state = in_combat
end

-- ============================================================================
-- SWING SYNC TRACKER (Enhancement)
-- ============================================================================
-- Tracks MH/OH swing timestamps to detect when the player has drifted out of
-- "MH leads OH by < 0.5s" stagger. Logic ported from the published WeakAura
-- at enhanceshaman.com/pages/guide/sync_stagger.
--
-- delta semantics:
--   delta == 0          → no data / out of combat / double-hit (hidden in UI)
--   delta < 0           → OH led MH (bad — OH steals WF priority from MH)
--   0 < delta < 0.5     → proper stagger inside Flurry's shared-charge window
--   delta >= 0.5        → MH lead too large, outside Flurry window (bad)
--
-- Exposed via NS.swing_sync so the dashboard custom_line in class.lua can read
-- it without duplicating the CLEU plumbing.
local swing_sync = {
    timeMH = 0,                  -- CLEU server timestamp of last MH event
    timeOH = 0,                  -- CLEU server timestamp of last OH event
    -- Client-time (GetTime()) at each event. CLEU timestamps are server
    -- epoch — different time-base from GetTime() — so we track both. Client
    -- time is used to compute inter-event gaps and to compare against the
    -- framework's GetSwingStart values for diagnostics.
    last_mh_client = 0,
    last_oh_client = 0,
    delta = 0,
    last_resync_at = 0,
    grace_scheduled_until = 0,
}
NS.swing_sync = swing_sync

-- Diagnostic helper: prints to debug log only when debug_mode is on.
-- Keys are static strings ("sync-MH", "sync-OH", etc) so debug_print's
-- 1.5s dedup throttles per-channel output to roughly one line per cycle.
local function sync_dbg(key, msg)
    if not NS.cached_settings or not NS.cached_settings.debug_mode then return end
    NS.debug_print(key, msg)
end

-- Macro-side hook so we can confirm the resync macro actually ran in-game
-- (icon being :Show()n only means we recommended it; the macro fires when
-- the player presses their rotation keybind while the icon is current). The
-- macro's macroafter has "/run if FluxAIO_ResyncFired then FluxAIO_ResyncFired() end"
-- appended — that calls back into this function. Gated on debug_mode so
-- normal play doesn't spam.
_G.FluxAIO_ResyncFired = function()
    if not NS.cached_settings or not NS.cached_settings.debug_mode then return end
    NS.debug_print("sync-macro",
        format("[SYNC] Macro fired @ %.2f (since-show=%.2fs)",
            GetTime(),
            swing_sync.last_resync_at > 0
                and (GetTime() - swing_sync.last_resync_at) or -1))
end

local function offhand_stagger_grace()
    -- Fires ~0.49s after an MH swing when OH state was uncertain. Replicates
    -- the WA's grace classification: if OH landed in the window → good; if
    -- not and we have prior OH data and we're still auto-attacking → bad.
    --
    -- Cold-start guard: when timeOH == 0 we've NEVER seen an OH swing yet
    -- (first MH of the combat, or first MH since combat reset). The else
    -- branch must not claim "bad sync" — we literally have no comparison
    -- point. Without this guard, every combat's first MH would flag bad,
    -- trigger a resync, which interrupts swings before OH can land, which
    -- keeps timeOH at 0 forever — a self-sustaining bad-state loop.
    local oh, mh = swing_sync.timeOH, swing_sync.timeMH
    local verdict
    if oh > mh then
        swing_sync.delta = oh - mh
        verdict = "OH-in-window"
    elseif oh == mh then
        -- Double-hit OR cold-start (both 0). delta stays 0.
        verdict = "double/cold"
    else
        -- OH didn't land in the 0.49s window after MH. Previously we set
        -- delta = 0.5 here as a "bad" placeholder, but that triggered fires
        -- based on a fabricated value rather than a confirmed measurement.
        -- Now: leave delta unchanged and let the next OH event provide the
        -- real delta. Drift is still detected — just 1s later when the OH
        -- event lands — but with accurate magnitude rather than a 0.5 guess.
        -- Eliminates the d=500ms placeholder-driven oscillation around the
        -- Flurry window boundary.
        verdict = "no-OH-wait"
    end
    sync_dbg("sync-grace",
        format("[SYNC] grace verdict=%s d=%dms",
            verdict, math.floor(swing_sync.delta * 1000)))
end

local function schedule_grace()
    -- Dedup overlapping grace timers when MH swings come in rapid succession.
    local now = GetTime()
    if now > swing_sync.grace_scheduled_until then
        swing_sync.grace_scheduled_until = now + 0.49
        C_Timer.After(0.49, offhand_stagger_grace)
    end
end

local sync_player_guid = nil
local sync_frame = CreateFrame("Frame")
sync_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
sync_frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- combat start
sync_frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- combat end
sync_frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Fresh slate at combat boundaries — stale swing data is worthless.
        swing_sync.timeMH = 0
        swing_sync.timeOH = 0
        swing_sync.last_mh_client = 0
        swing_sync.last_oh_client = 0
        swing_sync.delta = 0
        swing_sync.last_resync_at = 0
        sync_dbg("sync-combat", format("[SYNC] %s — state reset", event))
        return
    end

    if not sync_player_guid then
        sync_player_guid = UnitGUID("player")
        if not sync_player_guid then return end
    end

    local timestamp, subEvent, _, sourceGUID = CombatLogGetCurrentEventInfo()
    if subEvent ~= "SWING_DAMAGE" and subEvent ~= "SWING_MISSED" then return end
    if sourceGUID ~= sync_player_guid then return end

    -- isOffHand position differs by subevent (CLEU suffix args layout):
    --   SWING_DAMAGE: amount, overkill, school, resisted, blocked, absorbed,
    --                 critical, glancing, crushing, isOffHand     -> arg 21
    --   SWING_MISSED: missType, isOffHand                          -> arg 13
    local isOH
    if subEvent == "SWING_DAMAGE" then
        isOH = select(21, CombatLogGetCurrentEventInfo())
    else
        isOH = select(13, CombatLogGetCurrentEventInfo())
    end

    local client_now = GetTime()

    if isOH then
        local prev_oh_client = swing_sync.last_oh_client
        swing_sync.timeOH = timestamp
        swing_sync.last_oh_client = client_now
        local d = timestamp - swing_sync.timeMH
        if d > 3 then
            swing_sync.delta = 0  -- stale: previous MH was a different combat
        else
            swing_sync.delta = d  -- positive = OH followed MH
        end
        -- Diag: gap since last OH (≈ OH swing duration), framework's view,
        -- and the delta this event produced. Lets us compare framework vs
        -- CLEU-derived swing timing.
        local fw_start = Player:GetSwingStart(2) or 0
        local fw_dur   = Player:GetSwing(2) or 0
        local gap = (prev_oh_client > 0) and (client_now - prev_oh_client) or -1
        sync_dbg("sync-OH",
            format("[SYNC] OH gap=%.2fs fwS=%.2f fwD=%.2f d=%dms",
                gap, fw_start > 0 and (client_now - fw_start) or -1, fw_dur,
                math.floor(swing_sync.delta * 1000)))
    else
        local prev_mh_client = swing_sync.last_mh_client
        swing_sync.timeMH = timestamp
        swing_sync.last_mh_client = client_now
        if swing_sync.timeOH == 0 then
            swing_sync.delta = 0
            schedule_grace()
        else
            local d = timestamp - swing_sync.timeOH
            if d == 0 then
                swing_sync.delta = 0   -- double-hit
            elseif d < 1 then
                -- OH landed within 1s BEFORE this MH → OH leading (bad)
                swing_sync.delta = -d
            elseif d > 3 then
                swing_sync.delta = 0   -- stale
            else
                -- 1-3s gap: can't classify yet, let the grace timer decide
                schedule_grace()
            end
        end
        local fw_start = Player:GetSwingStart(1) or 0
        local fw_dur   = Player:GetSwing(1) or 0
        local gap = (prev_mh_client > 0) and (client_now - prev_mh_client) or -1
        sync_dbg("sync-MH",
            format("[SYNC] MH gap=%.2fs fwS=%.2f fwD=%.2f d=%dms",
                gap, fw_start > 0 and (client_now - fw_start) or -1, fw_dur,
                math.floor(swing_sync.delta * 1000)))
    end
end)

-- ============================================================================
-- ENHANCEMENT STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local enh_state = {
    stormstrike_debuff_duration = 0,
    flame_shock_duration = 0,
    shamanistic_rage_active = false,
    shamanistic_focus_active = false,
    flurry_charges = 0,
}

local function get_enh_state(context)
    if context._enh_valid then return enh_state end
    context._enh_valid = true

    -- Reset twist state on combat exit (must be in context_builder, not in
    -- requires_combat strategies which never see in_combat=false)
    check_combat_reset(context.in_combat)

    enh_state.stormstrike_debuff_duration = context.stormstrike_debuff
    enh_state.flame_shock_duration = context.flame_shock_duration
    enh_state.shamanistic_rage_active = context.shamanistic_rage_active
    enh_state.shamanistic_focus_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.SHAMANISTIC_FOCUS) or 0) > 0
    enh_state.flurry_charges = Unit(PLAYER_UNIT):HasBuffsStacks(Constants.BUFF_ID.FLURRY) or 0

    return enh_state
end

-- ============================================================================
-- SWING-TIMER MIDPOINT HELPERS (used by SwingResync gating)
-- ============================================================================
-- The /cleartarget+/targetlasttarget macro can only DELAY a swing — and only
-- if that swing is past its midpoint. Pressing pre-midpoint is a no-op for
-- swing timing (but still costs a frame of icon display). Per the guide:
--   * Drift (OH too far after MH, delta >= 0.5) → press when OH past midpoint
--   * OH-leading (delta < 0)                    → press when MH past midpoint
-- These helpers let matches() skip no-op fires.
--
-- API caveat: Player:GetSwing(slot) returns REMAINING swing time (NOT total
-- duration, despite some codebase usage to the contrary). GetSwingStart(slot)
-- returns the time the current swing CYCLE started. We compute total cycle
-- length as elapsed + remaining, so this works for any weapon speed without
-- needing GetSwingMax.
local function swing_state(slot)
    local start_time = Player:GetSwingStart(slot)
    local remaining = Player:GetSwing(slot)
    if not start_time or start_time <= 0 then return nil end
    local now = GetTime()
    local elapsed = now - start_time
    if elapsed <= 0 then return nil end
    local max_dur = elapsed + (remaining or 0)
    if max_dur <= 0 then return nil end
    return elapsed, max_dur
end

local function swing_past_midpoint(slot)
    local elapsed, max_dur = swing_state(slot)
    if not elapsed then return false end
    return elapsed >= (max_dur * 0.5)
end

-- "% of swing completed" — for diagnostic display only.
local function swing_pct(slot)
    local elapsed, max_dur = swing_state(slot)
    if not elapsed then return -1 end
    return math.floor((elapsed / max_dur) * 100)
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [0] Swing Resync — fires the resync macro when MH/OH stagger is bad
-- (OH leading, or OH outside the Flurry 0.5s shared-charge window). Per the
-- enhanceshaman.com guide, overcorrecting can cost an entire OH swing, so we
-- suppress for 0.5s after each fire (one OH-swing window) before re-evaluating.
-- Top priority so a bad-sync frame preempts Stormstrike/Shock — the few-ms
-- delay on an offensive ability is cheaper than ongoing sync drift.
local Enh_SwingResync = {
    requires_combat = true,
    is_gcd_gated = false,    -- macro is /cleartarget+/targetlasttarget; no GCD
    setting_key = "enh_auto_resync",

    matches = function(context, state)
        -- Only meaningful when actually auto-attacking.
        if not IsCurrentSpell(AUTO_ATTACK_SPELL_ID) then return false end

        -- Cold-start guard: need a real OH observation before classifying.
        -- Without this, the grace timer's "no OH yet" verdict would fire
        -- resync on every combat's first MH, starving OH of a chance to land.
        if swing_sync.timeOH == 0 then return false end

        -- Suppression after previous fire. Safety belt — the execute()
        -- resets timeOH/delta anyway, but suppression keeps us from
        -- thrashing if state updates faster than expected.
        local now = GetTime()
        if now - swing_sync.last_resync_at < 0.5 then return false end

        -- Bad sync conditions, WITH HYSTERESIS to prevent boundary oscillation.
        -- Pure ">= 0.5" / "< 0" thresholds cause this pattern in practice:
        --   drift 1300ms → fire → overshoot to -800ms → fire → bounce to
        --   500ms → fire (just over boundary) → bounce again → etc.
        -- The hysteresis dead-zone (0 < d < 0.65 and -0.15 < d <= 0) stops
        -- the bouncing — small mis-stagger is tolerated and naturally stable
        -- with matched-speed weapons. Trade-off: if you settle at, say,
        -- 600ms drift, you stay there (slightly outside Flurry's 0.5s window
        -- = small DPS loss) rather than burn a fire trying to fix it.
        --
        --   delta == 0              → no data, don't fire
        --   -0.15 <= delta < 0.65   → dead zone, don't fire
        --   delta < -0.15           → clear OH-lead, fire
        --   delta >= 0.65           → clear drift, fire
        local d = swing_sync.delta
        if d == 0 then return false end
        if d > -0.15 and d < 0.65 then return false end

        -- Scenario-specific timing gate (per the guide):
        --   Drift: macro only delays OH if OH is past its midpoint. Pressing
        --          pre-midpoint does nothing to swing timing. Gate so we
        --          only fire when the press will actually move OH.
        --   OH-leading: guide says press when MH past midpoint to "flip
        --               priority." Same idea — gate to actionable moments.
        -- Skipping no-op fires roughly halves visual fire rate while making
        -- each fire effective.
        if d < 0 then
            if not swing_past_midpoint(1) then return false end  -- MH
        else
            if not swing_past_midpoint(2) then return false end  -- OH
        end
        return true
    end,

    execute = function(icon, context, state)
        -- Snapshot diagnostic state BEFORE we reset it. MH%/OH% now show
        -- true "% through swing cycle" (computed via elapsed+remaining),
        -- so 50% really is midpoint. rawMH/rawOH show elapsed/total in
        -- seconds, so 1.30/2.60 = midpoint of a 2.6s weapon.
        local d_at_fire = swing_sync.delta
        local now = GetTime()
        local mh_elapsed, mh_total = swing_state(1)
        local oh_elapsed, oh_total = swing_state(2)
        local mh_pct = swing_pct(1)
        local oh_pct = swing_pct(2)

        swing_sync.last_resync_at = now
        -- Invalidate sync state after firing. The macro disrupts swings;
        -- whatever delta we just had is stale. Forcing timeOH back to 0
        -- means the next fire can't happen until a fresh OH event lands
        -- and gives us new data to judge against — natural "fire once,
        -- observe, maybe fire again" without burning DPS on a stuck loop.
        swing_sync.timeOH = 0
        swing_sync.delta = 0

        local oh_gap = (swing_sync.last_oh_client > 0)
            and (now - swing_sync.last_oh_client) or -1
        return A.SwingResync:Show(icon),
            format("[ENH] Resync d=%dms MH=%d%% OH=%d%% rawMH=%.2f/%.2f rawOH=%.2f/%.2f ohGap=%.2f",
                math.floor(d_at_fire * 1000), mh_pct, oh_pct,
                mh_elapsed or -1, mh_total or -1,
                oh_elapsed or -1, oh_total or -1,
                oh_gap)
    end,
}

-- [1] Shamanistic Rage (off-GCD — mana recovery + damage reduction)
local Enh_ShamanisticRage = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.ShamanisticRage,
    spell_target = PLAYER_UNIT,
    setting_key = "enh_use_shamanistic_rage",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local threshold = context.settings.enh_shamanistic_rage_pct or 30
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShamanisticRage, icon, PLAYER_UNIT,
            format("[ENH] Shamanistic Rage - Mana: %.0f%%", context.mana_pct))
    end,
}

-- [2] Racial (off-GCD)
local Enh_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        -- Enhancement uses AP Blood Fury or Berserking
        if A.BloodFuryAP:IsReady(PLAYER_UNIT) then return true end
        if A.Berserking:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.BloodFuryAP:IsReady(PLAYER_UNIT) then
            return A.BloodFuryAP:Show(icon), "[ENH] Blood Fury (AP)"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[ENH] Berserking"
        end
        return nil
    end,
}

-- [4] Totem Management — base totems (fire, earth, water)
-- Does NOT handle air slot if WF twist is active
local Enh_TotemManagement = {
    requires_combat = true,

    matches = function(context, state)
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD
        local totem_ok = NS.totem_allowed

        -- Fire totem (skip if fire nova twist, Fire Elemental active, "none", or group-only while solo)
        local skip_fire = s.enh_twist_fire_nova or context.fire_elemental_active
        if not skip_fire and (s.enh_fire_totem or "searing") ~= "none" and totem_ok(s.totem_fire_condition, context.in_group) then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then return true end
        end

        -- Earth totem (skip if "none", Tremor active, or group-only while solo)
        local earth_setting = s.enh_earth_totem or "strength_of_earth"
        if earth_setting ~= "none" and totem_ok(s.totem_earth_condition, context.in_group) then
            local skip_earth = false
            if s.use_auto_tremor and context.totem_earth_active then
                local have, name = GetTotemInfo(2)
                if have and name and name:find("Tremor") then skip_earth = true end
            end
            if not skip_earth then
                if not context.totem_earth_active or context.totem_earth_remaining < threshold then return true end
            end
        end

        -- Water totem (skip if "none" or group-only while solo)
        if (s.enh_water_totem or "mana_spring") ~= "none" and totem_ok(s.totem_water_condition, context.in_group) then
            if not context.totem_water_active or context.totem_water_remaining < threshold then return true end
        end

        -- Air totem (only if NOT twisting WF, not "none", and not group-only while solo)
        if not s.enh_twist_windfury and (s.enh_air_totem or "windfury") ~= "none" and totem_ok(s.totem_air_condition, context.in_group) then
            if not context.totem_air_active or context.totem_air_remaining < threshold then return true end
        end

        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings
        local threshold = Constants.TOTEM_REFRESH_THRESHOLD
        local totem_ok = NS.totem_allowed

        -- Fire totem (skip if FNT twist active, Fire Elemental active, "none", or group-only while solo)
        if not s.enh_twist_fire_nova and not context.fire_elemental_active and (s.enh_fire_totem or "searing") ~= "none" and totem_ok(s.totem_fire_condition, context.in_group) then
            if not context.totem_fire_active or context.totem_fire_remaining < threshold then
                local spell = resolve_totem_spell(s.enh_fire_totem or "searing", NS.FIRE_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[ENH] Fire Totem"
                end
            end
        end

        -- Earth totem (skip if "none", Tremor active, or group-only while solo)
        local earth_setting = s.enh_earth_totem or "strength_of_earth"
        if earth_setting ~= "none" and totem_ok(s.totem_earth_condition, context.in_group) then
            local skip_earth = false
            if s.use_auto_tremor and context.totem_earth_active then
                local have, name = GetTotemInfo(2)
                if have and name and name:find("Tremor") then skip_earth = true end
            end
            if not skip_earth then
                if not context.totem_earth_active or context.totem_earth_remaining < threshold then
                    local spell = resolve_totem_spell(earth_setting, NS.EARTH_TOTEM_SPELLS)
                    if spell and spell:IsReady(PLAYER_UNIT) then
                        return spell:Show(icon), "[ENH] Earth Totem"
                    end
                end
            end
        end

        -- Water totem (skip if "none" or group-only while solo)
        if (s.enh_water_totem or "mana_spring") ~= "none" and totem_ok(s.totem_water_condition, context.in_group) then
            if not context.totem_water_active or context.totem_water_remaining < threshold then
                local spell = resolve_totem_spell(s.enh_water_totem or "mana_spring", NS.WATER_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[ENH] Water Totem"
                end
            end
        end

        -- Air totem (only if NOT twisting, not "none", and not group-only while solo)
        if not s.enh_twist_windfury and (s.enh_air_totem or "windfury") ~= "none" and totem_ok(s.totem_air_condition, context.in_group) then
            if not context.totem_air_active or context.totem_air_remaining < threshold then
                local spell = resolve_totem_spell(s.enh_air_totem or "windfury", NS.AIR_TOTEM_SPELLS)
                if spell and spell:IsReady(PLAYER_UNIT) then
                    return spell:Show(icon), "[ENH] Air Totem"
                end
            end
        end

        return nil
    end,
}

-- [5] Windfury Twist — cycle WF ↔ default air totem (GoA/WoA) every ~10s
-- WF buff persists ~10s on players after totem is replaced, so both buffs can be active simultaneously
local Enh_WindfuryTwist = {
    requires_combat = true,

    matches = function(context, state)
        -- Group-only check for air totems
        if not NS.totem_allowed(context.settings.totem_air_condition, context.in_group) then return false end

        if not context.settings.enh_twist_windfury then
            -- Not twisting: just ensure air totem is up if needed
            if not context.totem_air_active or context.totem_air_remaining < Constants.TOTEM_REFRESH_THRESHOLD then
                return true
            end
            return false
        end

        -- OOM protection: skip twist below threshold
        if context.mana_pct < Constants.TWIST.OOM_THRESHOLD * 100 then
            -- Just keep whatever air totem is up
            if not context.totem_air_active then return true end
            return false
        end

        local now = GetTime()

        -- First time entering combat: drop WF immediately
        if not wf_twist.initialized then
            return true
        end

        -- Phase-specific durations so the full cycle is ~10s (matches WF buff
        -- duration), not 20s. WF holds for one GCD just to apply the buff,
        -- then Grace runs for the rest of the buff window before we refresh.
        if wf_twist.phase == "windfury" then
            local elapsed = now - wf_twist.last_wf_time
            if elapsed >= Constants.TWIST.WF_PHASE_DURATION then return true end
        elseif wf_twist.phase == "default" then
            local elapsed = now - wf_twist.last_default_time
            if elapsed >= Constants.TWIST.DEFAULT_PHASE_DURATION then return true end
        end

        return false
    end,

    execute = function(icon, context, state)
        local now = GetTime()

        -- If not twisting, just drop configured air totem
        if not context.settings.enh_twist_windfury then
            local spell = resolve_totem_spell(context.settings.enh_air_totem or "windfury", NS.AIR_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), "[ENH] Air Totem (no twist)"
            end
            return nil
        end

        -- Initialize: start with WF
        if not wf_twist.initialized then
            if A.WindfuryTotem:IsReady(PLAYER_UNIT) then
                wf_twist.initialized = true
                wf_twist.phase = "windfury"
                wf_twist.last_wf_time = now
                return A.WindfuryTotem:Show(icon), "[ENH] Windfury Totem (twist init)"
            end
            return nil
        end

        -- Phase transitions
        if wf_twist.phase == "windfury" then
            -- Switch to default air totem (Grace of Air typically)
            -- The WF buff will persist on party members for ~10s
            local default_key = context.settings.enh_air_totem or "grace_of_air"
            -- When twisting, the "default" air totem should be Grace of Air (not WF again)
            if default_key == "windfury" then default_key = "grace_of_air" end
            local spell = resolve_totem_spell(default_key, NS.AIR_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                wf_twist.phase = "default"
                wf_twist.last_default_time = now
                return spell:Show(icon), format("[ENH] %s (twist phase 2)", default_key)
            end
        elseif wf_twist.phase == "default" then
            -- Switch back to WF before the buff expires on party
            if A.WindfuryTotem:IsReady(PLAYER_UNIT) then
                wf_twist.phase = "windfury"
                wf_twist.last_wf_time = now
                return A.WindfuryTotem:Show(icon), "[ENH] Windfury Totem (twist refresh)"
            end
        end

        return nil
    end,
}

-- [6] Fire Nova Totem Twist — cycle FNT (AoE burst) with default fire totem
local Enh_FireNovaTotemTwist = {
    requires_combat = true,
    setting_key = "enh_twist_fire_nova",

    matches = function(context, state)
        -- Don't overwrite Fire Elemental Totem
        if context.fire_elemental_active then return false end
        -- Group-only check for fire totems
        if not NS.totem_allowed(context.settings.totem_fire_condition, context.in_group) then return false end
        -- OOM protection
        if context.mana_pct < Constants.TWIST.OOM_THRESHOLD * 100 then return false end

        local now = GetTime()

        if fnt_twist.phase == "idle" then
            -- Don't start a new FNT cycle on a dead target
            if context.target_dead then return false end
            -- Respect AoE threshold — allow single-target bypass based on setting
            local threshold = context.settings.aoe_threshold or 0
            if threshold > 0 and (context.enemy_count or 1) < threshold then
                local bypass = context.settings.enh_fnt_single_target or "boss"
                if bypass == "off" then return false end
                if bypass ~= "all" then
                    local classification = UnitClassification("target") or ""
                    if bypass == "boss" then
                        if classification ~= "worldboss" then return false end
                    elseif bypass == "elite" then
                        if classification ~= "worldboss" and classification ~= "rareelite" and classification ~= "elite" then return false end
                    end
                end
            end
            -- Ready to drop FNT
            return true
        elseif fnt_twist.phase == "waiting" then
            -- FNT fuse is ~4s, then it explodes and disappears
            local elapsed = now - fnt_twist.last_drop_time
            if elapsed >= 5 then
                -- FNT has exploded, drop default fire totem
                fnt_twist.phase = "default"
                return true
            end
        elseif fnt_twist.phase == "default" then
            -- FNT has a 15s CD; check if it's ready again
            if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
                fnt_twist.phase = "idle"
                return true
            end
        end

        return false
    end,

    execute = function(icon, context, state)
        local now = GetTime()

        if fnt_twist.phase == "idle" then
            -- Drop Fire Nova Totem
            if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
                fnt_twist.phase = "waiting"
                fnt_twist.last_drop_time = now
                return A.FireNovaTotem:Show(icon), "[ENH] Fire Nova Totem (twist)"
            end
        elseif fnt_twist.phase == "default" then
            -- Drop the configured post-FNT totem (default Magma) during the gap
            -- between FNT explosion and the next FNT off CD. Falls back to the
            -- default fire totem setting if the post-FNT slot is left blank.
            local post_key = context.settings.enh_fnt_post_totem
                or context.settings.enh_fire_totem
                or "magma"
            local spell = resolve_totem_spell(post_key, NS.FIRE_TOTEM_SPELLS)
            if spell and spell:IsReady(PLAYER_UNIT) then
                return spell:Show(icon), format("[ENH] %s (post-FNT)", post_key)
            end
        end

        return nil
    end,
}

-- [7] Stormstrike — top melee priority, 10s CD
local Enh_Stormstrike = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Stormstrike,
    setting_key = "enh_use_stormstrike",

    execute = function(icon, context, state)
        return try_cast(A.Stormstrike, icon, TARGET_UNIT, "[ENH] Stormstrike")
    end,
}

-- [8] Shock — Flame Shock weaving + primary shock (Earth/Frost)
local Enh_Shock = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local s = context.settings
        local primary = s.enh_primary_shock or "earth_shock"

        -- Hold-shocks: rotation skips shocks entirely; the interrupt middleware
        -- (priority 510) still fires shocks on enemy casts independently.
        if s.enh_shock_interrupt_only then return false end

        -- Mana conservation gate (bypassed when SR active or SR ready)
        local mana_stop = s.enh_mana_stop_shocks or 0
        if mana_stop > 0 and context.mana_pct < mana_stop then
            -- Shamanistic Focus proc = nearly free shock, always allow
            if not state.shamanistic_focus_active then
                local sr_exempt = state.shamanistic_rage_active or (A.ShamanisticRage:GetCooldown() or 99) <= 0
                if not sr_exempt then return false end
            end
        end

        -- Flame Shock weaving: apply DoT when not active
        if s.enh_weave_flame_shock and state.flame_shock_duration <= 2 then
            -- TTD gate for Flame Shock DoT
            local fs_ttd = s.enh_fs_min_ttd or 0
            if fs_ttd <= 0 or not context.ttd or context.ttd <= 0 or context.ttd >= fs_ttd then
                return true
            end
        end

        -- Primary shock filler (when FS DoT is ticking or weaving disabled)
        if primary ~= "none" then
            return true
        end

        return false
    end,

    execute = function(icon, context, state)
        local s = context.settings

        -- Flame Shock weaving takes priority — maintain DoT before spending shocks on filler
        -- (Shamanistic Focus mana reduction applies to Flame Shock too, so no waste)
        if s.enh_weave_flame_shock and state.flame_shock_duration <= 2 then
            local fs_ttd = s.enh_fs_min_ttd or 0
            local ttd_ok = fs_ttd <= 0 or not context.ttd or context.ttd <= 0 or context.ttd >= fs_ttd
            if ttd_ok then
                local result = try_cast(A.FlameShock, icon, TARGET_UNIT,
                    format("[ENH] Flame Shock - DoT: %.1fs", state.flame_shock_duration))
                if result then return result end
            end
        end

        -- Shamanistic Focus: nearly free shock — use on Earth Shock when DoT is already ticking
        if state.shamanistic_focus_active then
            local result = try_cast(A.EarthShock, icon, TARGET_UNIT, "[ENH] Earth Shock (Sham. Focus)")
            if result then return result end
        end

        -- Stormstrike synergy: prefer Earth Shock when SS +20% nature debuff is active
        if state.stormstrike_debuff_duration > 0 then
            local result = try_cast(A.EarthShock, icon, TARGET_UNIT, "[ENH] Earth Shock (SS synergy)")
            if result then return result end
        end

        -- Primary shock
        local primary = s.enh_primary_shock or "earth_shock"
        if primary == "earth_shock" then
            return try_cast(A.EarthShock, icon, TARGET_UNIT, "[ENH] Earth Shock")
        elseif primary == "frost_shock" then
            return try_cast(A.FrostShock, icon, TARGET_UNIT, "[ENH] Frost Shock")
        end

        return nil
    end,
}

-- [9] Fire Elemental (long CD summon)
local Enh_FireElemental = {
    requires_combat = true,
    is_burst = true,
    spell = A.FireElementalTotem,
    spell_target = PLAYER_UNIT,
    setting_key = "enh_use_fire_elemental",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.FireElementalTotem, icon, PLAYER_UNIT, "[ENH] Fire Elemental Totem")
    end,
}

-- [10] AoE rotation (when enough enemies)
local Enh_AoE = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local threshold = context.settings.aoe_threshold or 0
        if threshold == 0 then return false end
        if (context.enemy_count or 1) < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Skip fire totems if FNT twist is managing the fire slot or Fire Elemental is active
        local min_ttd = context.settings.cd_min_ttd or 0
        local ttd_ok = min_ttd <= 0 or not context.ttd or context.ttd <= 0 or context.ttd >= min_ttd
        if ttd_ok and not context.settings.enh_twist_fire_nova and not context.fire_elemental_active then
            -- Only drop fire totems if fire slot is empty/expiring
            if not context.totem_fire_active or context.totem_fire_remaining < Constants.TOTEM_REFRESH_THRESHOLD then
                if A.FireNovaTotem:IsReady(PLAYER_UNIT) then
                    return try_cast(A.FireNovaTotem, icon, PLAYER_UNIT, "[ENH] Fire Nova Totem (AoE)")
                end
                if A.MagmaTotem:IsReady(PLAYER_UNIT) then
                    return try_cast(A.MagmaTotem, icon, PLAYER_UNIT, "[ENH] Magma Totem (AoE)")
                end
            end
        end
        -- Fall through to regular melee rotation (no CL — 2s cast breaks melee momentum)
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("enhancement", {
    named("SwingResync",         Enh_SwingResync),         -- top: bad-sync preempts everything
    named("ShamanisticRage",     Enh_ShamanisticRage),
    named("Racial",              Enh_Racial),
    named("TotemManagement",     Enh_TotemManagement),
    named("WindfuryTwist",       Enh_WindfuryTwist),       -- time-sensitive: must precede damage spells
    named("FireNovaTotemTwist",  Enh_FireNovaTotemTwist),  -- time-sensitive: must precede damage spells
    named("AoE",                 Enh_AoE),
    named("Stormstrike",         Enh_Stormstrike),
    named("Shock",               Enh_Shock),
    named("FireElemental",       Enh_FireElemental),
}, {
    context_builder = get_enh_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Shaman]|r Enhancement module loaded")
