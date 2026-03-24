--- Fury Warrior Module
--- Fury playstyle strategies: Bloodthirst + Whirlwind + Rampage + rage dumping
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Fury]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Fury]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local debug_print = NS.debug_print
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- FURY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local fury_state = {
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
    bt_cd = 0,
    ww_cd = 0,
}

local function get_fury_state(context)
    if context._fury_valid then return fury_state end
    context._fury_valid = true

    fury_state.target_below_20 = context.target_hp < 20
    fury_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    fury_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    fury_state.thunder_clap_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    fury_state.demo_shout_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    fury_state.bt_cd = A.Bloodthirst:GetCooldown() or 0
    fury_state.ww_cd = A.Whirlwind:GetCooldown() or 0

    return fury_state
end

-- ============================================================================
-- RESOURCE POOLING (matches wowsims slamMSWWDelay = 2000ms)
-- ============================================================================
-- Don't waste GCD + rage on Slam when core abilities are imminent.
-- If BT or WW comes off CD within 2s, hold the filler unless we can
-- afford both the filler AND the core ability's rage cost.
local FILLER_HOLD_WINDOW = 2.0  -- seconds
local RAGE_COST_BT = 30
local RAGE_COST_WW = 25
local RAGE_COST_SLAM = 15
local RAGE_COST_PUMMEL = 10
local SLAM_MIN_WINDOW = 1.1   -- Improved Slam 1.0s cast + 0.1s latency; only Slam if swing is further away

-- Swing desync: offset MH/OH timers when weapons have matching speeds
local DESYNC_SPEED_TOLERANCE = 0.2   -- weapon speeds must be within 0.2s to be "matching"
local DESYNC_SYNC_THRESHOLD  = 0.3   -- MH/OH remaining within 0.3s = "synced"
local DESYNC_COOLDOWN        = 10    -- seconds between desync attempts
local DESYNC_SLAM_WINDOW     = 1.6   -- base Slam 1.5s + 0.1s latency (no Improved Slam assumed)
local desync_last_attempt    = 0     -- GetTime() of last desync Slam

local function should_pool_for_core_fury(context, state)
    -- BT imminent: hold if spending Slam cost would starve BT
    if state.bt_cd > 0 and state.bt_cd <= FILLER_HOLD_WINDOW then
        if (context.rage - RAGE_COST_SLAM) < RAGE_COST_BT then return true end
    end
    -- WW imminent: hold if spending Slam cost would starve WW
    if context.settings.fury_use_whirlwind
        and state.ww_cd > 0 and state.ww_cd <= FILLER_HOLD_WINDOW then
        if (context.rage - RAGE_COST_SLAM) < RAGE_COST_WW then return true end
    end
    return false
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Rampage maintenance (Fury 41-point talent)
-- Activate after melee crit, refresh when duration is low (stacks build naturally via refreshes)
local Fury_Rampage = {
    requires_combat = true,
    spell = A.Rampage,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not is_spell_available(A.Rampage) then return false end
        -- Activate if buff not present
        if not context.rampage_active then return true end
        -- Still building stacks — always use when available
        if context.rampage_stacks < Constants.RAMPAGE_MAX_STACKS then return true end
        -- At max stacks, only refresh when duration running low
        local threshold = context.settings.fury_rampage_threshold or 5
        return context.rampage_duration < threshold
    end,

    execute = function(icon, context, state)
        return try_cast(A.Rampage, icon, PLAYER_UNIT,
            format("[FURY] Rampage - Stacks: %d, Duration: %.1fs", context.rampage_stacks, context.rampage_duration))
    end,
}

-- [2] Bloodthirst (primary damage, any stance)
local Fury_Bloodthirst = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_bt_during_execute then return false end
        end
        -- Yield to WW when enough enemies are nearby and WW is ready
        -- skipRange=true (PB AoE), skipUsable=true (bypass stance check)
        local ww_prio = context.settings.fury_ww_prio_count or 2
        if ww_prio > 0 and context.enemy_count >= ww_prio
            and context.rage >= 25
            and context.settings.fury_use_whirlwind
            and A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true) then
            return false
        end
        return A.Bloodthirst:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Bloodthirst, icon, TARGET_UNIT, "[FURY] Bloodthirst")
    end,
}

-- [3] Sweeping Strikes (Battle or Berserker Stance — Fury talent in TBC)
local Fury_SweepingStrikes = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_use_sweeping_strikes",

    matches = function(context, state)
        if context.sweeping_strikes_active then return false end
        if context.enemy_count < 2 then return false end
        -- 30 rage cost — check explicitly since skipUsable bypasses resource checks
        if context.rage < 30 then return false end
        -- skipUsable=true: bypass IsUsableSpell stance check
        return A.SweepingStrikes:IsReady(PLAYER_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        return A.SweepingStrikes:Show(icon), format("[FURY] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
    end,
}

-- [4] Whirlwind (Berserker Stance) — handles stance swap inline
local Fury_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_use_whirlwind",

    matches = function(context, state)
        -- PvP CC break prevention: WW is PBAoE, skip if breakable CC nearby
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_ww_during_execute then return false end
        end
        -- 25 rage cost — check explicitly since skipUsable bypasses resource checks
        if context.rage < 25 then return false end
        -- skipRange=true (PB AoE), skipUsable=true (bypass stance check) — matches old rotation pattern
        return A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true)
    end,

    execute = function(icon, context, state)
        -- Swap to Berserker Stance if needed (inline stance dance)
        if context.stance ~= Constants.STANCE.BERSERKER then
            if A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), "[FURY] → Berserker (for WW)"
            end
            return nil
        end
        -- Direct Show — range/usability already validated in matches (PB AoE)
        return A.Whirlwind:Show(icon), format("[FURY] Whirlwind - Rage: %d", context.rage)
    end,
}

-- [4] Execute (target <20% HP)
local Fury_Execute = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_execute_phase",

    matches = function(context, state)
        if not state.target_below_20 then return false end
        -- Pool extra rage for bigger Executes (+21 dmg per extra rage point)
        if context.rage < 25 then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[FURY] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [6] Sunder Armor maintenance (if configured)
local Fury_SunderMaintain = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local mode = context.settings.sunder_armor_mode or "none"
        if mode == "none" then return false end

        if mode == "help_stack" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS then return false end
        elseif mode == "maintain" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS
                and state.sunder_duration > Constants.SUNDER_REFRESH_WINDOW then
                return false
            end
        end

        -- Sunder/Devastate require Defensive Stance
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[FURY] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[FURY] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [7] Thunder Clap maintenance (Battle/Defensive Stance)
local Fury_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_thunder_clap",

    matches = function(context, state)
        -- PvP CC break prevention: TC is PBAoE
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if state.thunder_clap_duration > 2 then return false end
        -- TC is PBAoE — use PLAYER_UNIT for range check (self-cast)
        return A.ThunderClap:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ThunderClap, icon, PLAYER_UNIT,
            format("[FURY] Thunder Clap - Duration: %.1fs", state.thunder_clap_duration))
    end,
}

-- [8] Demoralizing Shout maintenance (all stances)
local Fury_DemoShout = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_demo_shout",

    matches = function(context, state)
        -- PvP CC break prevention: Demo Shout is PBAoE
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if not context.in_melee_range then return false end
        if state.demo_shout_duration > 3 then return false end
        return A.DemoralizingShout:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, PLAYER_UNIT,
            format("[FURY] Demo Shout - Duration: %.1fs", state.demo_shout_duration))
    end,
}

-- [9] Slam (filler, any stance)
local Fury_Slam = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_use_slam",

    matches = function(context, state)
        if context.is_moving then return false end
        -- Don't Slam in execute phase
        if state.target_below_20 and context.settings.fury_execute_phase then return false end
        -- Resource pooling: hold GCD for BT/WW if imminent and rage is tight
        if should_pool_for_core_fury(context, state) then return false end
        -- Slam weaving: only Slam if the cast fits before next auto-attack
        if NS.get_time_until_swing() < SLAM_MIN_WINDOW then return false end
        return A.Slam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Slam, icon, TARGET_UNIT, "[FURY] Slam")
    end,
}

-- [12] Hamstring weave (for Sword Spec procs)
local Fury_Hamstring = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_use_hamstring",

    matches = function(context, state)
        local min_rage = context.settings.fury_hamstring_rage or 50
        if context.rage < min_rage then return false end
        return A.Hamstring:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Hamstring, icon, TARGET_UNIT,
            format("[FURY] Hamstring - Rage: %d", context.rage))
    end,
}

-- [13] Swing Desync (Slam injection to offset MH/OH timers)
-- When both weapons have matching speeds and swings are synced, a single Slam
-- resets the MH swing timer without affecting OH, creating a timing offset.
-- This smooths rage generation and lets Flurry/WF procs benefit both hands.
local abs = math.abs

local Fury_SwingDesync = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if not context.settings.fury_swing_desync then return false end
        -- Must be dual-wielding
        if not context.has_offhand then return false end
        -- Can't Slam while moving
        if context.is_moving then return false end
        -- Cooldown between desync attempts
        local now = _G.GetTime()
        if (now - desync_last_attempt) < DESYNC_COOLDOWN then return false end
        -- Weapon speeds must be similar (identical or near-identical = sync risk)
        local mh_speed = Player:GetSwingMax(1) or 0
        local oh_speed = Player:GetSwingMax(2) or 0
        if mh_speed <= 0 or oh_speed <= 0 then return false end
        if abs(mh_speed - oh_speed) > DESYNC_SPEED_TOLERANCE then return false end
        -- Both hands must be actively swinging
        local mh_remaining = Player:GetSwing(1) or 0
        local oh_remaining = Player:GetSwing(2) or 0
        if mh_remaining <= 0 or oh_remaining <= 0 then return false end
        -- Check if swings are synced (remaining times close together)
        if abs(mh_remaining - oh_remaining) > DESYNC_SYNC_THRESHOLD then return false end
        -- Need enough swing time left for base Slam (1.5s) to land before next auto
        if mh_remaining < DESYNC_SLAM_WINDOW then return false end
        -- Don't starve BT/WW if they're coming off CD soon
        if should_pool_for_core_fury(context, state) then return false end
        return A.Slam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        desync_last_attempt = _G.GetTime()
        return try_cast(A.Slam, icon, TARGET_UNIT, "[FURY] Slam (swing desync)")
    end,
}

-- [14] Heroic Strike / Cleave (off-GCD rage dump)
local Fury_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    setting_key = "fury_use_heroic_strike",

    matches = function(context, state)
        -- Already queued — yield the icon so GCD abilities can show
        if A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent() then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_hs_during_execute then return false end
        end
        -- HS Trick: proactively queue when OH swing is imminent (before rage threshold)
        if context.settings.hs_trick and context.has_offhand then
            local oh_remaining = context.oh_remain or 0
            local mh_remaining = context.mh_remain or 0
            if oh_remaining > 0 and oh_remaining <= 0.4 then
                if mh_remaining > oh_remaining + 0.3 then
                    return true  -- queue HS now; dequeue middleware handles MH safety
                end
            end
        end
        local threshold = context.settings.fury_hs_rage_threshold or 50
        -- HS Trick: lower threshold when dual-wielding (the dequeue middleware handles safety)
        if context.settings.hs_trick and context.has_offhand then
            threshold = 30  -- keep enough for BT (30 rage) — dequeue middleware handles safety
        end
        if context.rage < threshold then return false end
        -- Smart rage hold: don't dump into HS when an interrupt may be needed soon
        if context.settings.use_interrupt then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                -- Hold enough rage for Pummel (10 rage)
                if (context.rage - 15) < RAGE_COST_PUMMEL then return false end
            end
        end
        return true
    end,

    execute = function(icon, context, state)
        -- Auto Cleave/HS: use Cleave at threshold, HS otherwise
        local cleave_at = context.settings.aoe_threshold or 2
        -- PvP CC break prevention: Cleave can hit CC'd target
        local cc_safe = not (context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check)
        if cc_safe and cleave_at > 0 and context.enemy_count >= cleave_at and A.Cleave:IsReady(TARGET_UNIT) then
            return A.Cleave:Show(icon), format("[FURY] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return A.HeroicStrike:Show(icon), format("[FURY] Heroic Strike - Rage: %d", context.rage)
        end
        return nil
    end,
}

-- [11] Victory Rush (free instant after killing blow, 0 rage)
local Fury_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,
    setting_key = "fury_use_victory_rush",

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[FURY] Victory Rush")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("fury", {
    named("Rampage",         Fury_Rampage),
    named("Bloodthirst",     Fury_Bloodthirst),
    named("SweepingStrikes", Fury_SweepingStrikes),  -- before WW to double hits in AoE (if talented)
    named("Whirlwind",       Fury_Whirlwind),
    named("Execute",         Fury_Execute),
    named("VictoryRush",     Fury_VictoryRush),
    named("SunderMaintain",  Fury_SunderMaintain),
    named("ThunderClap",     Fury_ThunderClap),
    named("DemoShout",       Fury_DemoShout),
    named("Slam",            Fury_Slam),
    named("Hamstring",       Fury_Hamstring),
    named("SwingDesync",     Fury_SwingDesync),
    named("HeroicStrike",    Fury_HeroicStrike),
}, {
    context_builder = get_fury_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Fury module loaded")
