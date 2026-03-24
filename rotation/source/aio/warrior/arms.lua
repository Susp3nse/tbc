--- Arms Warrior Module
--- Arms playstyle strategies: Mortal Strike + Overpower + Whirlwind with stance dancing
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Arms]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Arms]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local is_stance_swap_safe = NS.is_stance_swap_safe
local debug_print = NS.debug_print
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- ARMS STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local arms_state = {
    rend_active = false,
    rend_duration = 0,
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
    ms_cd = 0,
    ww_cd = 0,
}

local function get_arms_state(context)
    if context._arms_valid then return arms_state end
    context._arms_valid = true

    arms_state.rend_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.REND) or 0
    arms_state.rend_active = arms_state.rend_duration > 0
    arms_state.target_below_20 = context.target_hp < 20
    arms_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    arms_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    arms_state.thunder_clap_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    arms_state.demo_shout_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    arms_state.ms_cd = A.MortalStrike:GetCooldown() or 0
    arms_state.ww_cd = A.Whirlwind:GetCooldown() or 0

    return arms_state
end

-- ============================================================================
-- RESOURCE POOLING (matches wowsims slamMSWWDelay = 2000ms)
-- ============================================================================
-- Don't waste GCD + rage on Slam when core abilities are imminent.
-- If MS or WW comes off CD within 2s, hold the filler unless we can
-- afford both the filler AND the core ability's rage cost.
local FILLER_HOLD_WINDOW = 2.0  -- seconds
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_SLAM = 15
local RAGE_COST_PUMMEL = 10
local SLAM_MIN_WINDOW = 1.1   -- Improved Slam 1.0s cast + 0.1s latency; only Slam if swing is further away

local function should_pool_for_core_arms(context, state)
    -- MS imminent: hold if spending Slam cost would starve MS
    if state.ms_cd > 0 and state.ms_cd <= FILLER_HOLD_WINDOW then
        if (context.rage - RAGE_COST_SLAM) < RAGE_COST_MS then return true end
    end
    -- WW imminent: hold if spending Slam cost would starve WW
    if context.settings.arms_use_whirlwind
        and state.ww_cd > 0 and state.ww_cd <= FILLER_HOLD_WINDOW then
        if (context.rage - RAGE_COST_SLAM) < RAGE_COST_WW then return true end
    end
    return false
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Maintain Rend (for Blood Frenzy talent — +4% physical damage)
local Arms_MaintainRend = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_maintain_rend",

    matches = function(context, state)
        -- Don't bother rending in execute phase
        if state.target_below_20 and context.settings.arms_execute_phase then return false end
        local refresh = context.settings.arms_rend_refresh or 4
        if state.rend_active and state.rend_duration > refresh then return false end
        -- Rend works in Battle or Defensive Stance
        return A.Rend:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Rend, icon, TARGET_UNIT,
            format("[ARMS] Rend - Duration: %.1fs", state.rend_duration))
    end,
}

-- [2] Overpower (Battle Stance only, dodge proc) — stance dance inline
-- Smart rage protection: prevents stance dancing when it would starve MS, WW, or Execute
local function should_use_overpower(context, state)
    local op_cost = 5  -- Overpower rage cost
    local tm_cap = (A.TacticalMastery:GetTalentRank() or 0) * 5
    local rage_after_swap = context.stance == Constants.STANCE.BATTLE
        and context.rage
        or math.min(context.rage, tm_cap)

    -- Basic affordability: can't cast if we can't pay for it after swap
    if rage_after_swap < op_cost then return false end

    -- High rage: at very high rage, stay in current stance for MS/WW to avoid capping
    if context.rage > 50 then return false end

    -- MS starvation: if MS ready/nearly ready and in melee, reserve rage for it
    if not A.MortalStrike:IsBlockedBySpellBook() then
        local ms_cd = state.ms_cd or 0
        if ms_cd <= 1.5 and context.in_melee_range then
            local ms_cost = A.MortalStrike:GetSpellPowerCostCache() or RAGE_COST_MS
            if rage_after_swap < (op_cost + ms_cost) then return false end
        end
    end

    -- WW starvation: if WW ready/nearly ready, reserve rage for it
    if context.settings.arms_use_whirlwind and not A.Whirlwind:IsBlockedBySpellBook() then
        local ww_cd = state.ww_cd or 0
        if ww_cd <= 1.5 and context.in_melee_range then
            local ww_cost = A.Whirlwind:GetSpellPowerCostCache() or RAGE_COST_WW
            if rage_after_swap < (op_cost + ww_cost) then return false end
        end
    end

    -- Execute starvation: if target <20% and execute phase enabled, reserve for Execute
    if state.target_below_20 and context.settings.arms_execute_phase then
        local exec_cost = A.Execute:GetSpellPowerCostCache() or 15
        if rage_after_swap < (op_cost + exec_cost) then return false end
    end

    return true
end

local Arms_Overpower = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_use_overpower",

    matches = function(context, state)
        -- skipUsable=true: bypass stance check so we can dance to Battle
        if not A.Overpower:IsReady(TARGET_UNIT, nil, nil, nil, true) then return false end

        -- Urgent proc: if OP proc expires very soon, use it or lose it (bypass rage checks)
        local op_remaining = A.Overpower:GetCooldown() or 0
        if op_remaining > 0 and op_remaining <= 1.5 then
            -- Proc expiring — still need basic affordability
            return is_stance_swap_safe(context.rage, 5)
        end

        -- Smart rage protection: check MS/WW/Execute starvation
        return should_use_overpower(context, state)
    end,

    execute = function(icon, context, state)
        -- Swap to Battle Stance if needed (inline stance dance)
        if context.stance ~= Constants.STANCE.BATTLE then
            if A.BattleStance:IsReady(PLAYER_UNIT) then
                return A.BattleStance:Show(icon), "[ARMS] → Battle (for Overpower)"
            end
            return nil
        end
        return try_cast(A.Overpower, icon, TARGET_UNIT,
            format("[ARMS] Overpower - Rage: %d", context.rage))
    end,
}

-- [3] Mortal Strike (primary damage, any stance)
local Arms_MortalStrike = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_use_ms_execute then return false end
        end
        return A.MortalStrike:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.MortalStrike, icon, TARGET_UNIT, "[ARMS] Mortal Strike")
    end,
}

-- [4] Whirlwind (Berserker Stance only) — handles stance swap inline
local Arms_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_use_whirlwind",

    matches = function(context, state)
        -- PvP CC break prevention: WW is PBAoE, skip if breakable CC nearby
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_use_ww_execute then return false end
        end
        -- 25 rage cost — check explicitly since skipUsable bypasses resource checks
        if context.rage < 25 then return false end
        -- skipRange=true (PB AoE), skipUsable=true (bypass stance check) — matches old rotation pattern
        return A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true)
    end,

    execute = function(icon, context, state)
        -- Swap to Berserker Stance if needed (inline stance dance)
        if context.stance ~= Constants.STANCE.BERSERKER then
            -- TM check: WW costs 25 rage, don't dance if we'd waste too much
            if not is_stance_swap_safe(context.rage, 25) then return nil end
            if A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), "[ARMS] → Berserker (for WW)"
            end
            return nil
        end
        -- Direct Show — range/usability already validated in matches (PB AoE)
        return A.Whirlwind:Show(icon), format("[ARMS] Whirlwind - Rage: %d", context.rage)
    end,
}

-- [5] Sweeping Strikes (Battle or Berserker Stance — Fury talent in TBC)
-- Only available if Arms build has 20+ points in Fury (uncommon)
local Arms_SweepingStrikes = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_use_sweeping_strikes",

    matches = function(context, state)
        if not is_spell_available(A.SweepingStrikes) then return false end
        if context.sweeping_strikes_active then return false end
        if context.enemy_count < 2 then return false end
        -- 30 rage cost — check explicitly since skipUsable bypasses resource checks
        if context.rage < 30 then return false end
        -- skipUsable=true: bypass IsUsableSpell stance check
        return A.SweepingStrikes:IsReady(PLAYER_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        return A.SweepingStrikes:Show(icon), format("[ARMS] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
    end,
}

-- [6] Execute (target <20% HP, dump rage)
local Arms_Execute = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_execute_phase",

    matches = function(context, state)
        if not state.target_below_20 then return false end
        -- Pool extra rage for bigger Executes (+21 dmg per extra rage point)
        if context.rage < 25 then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[ARMS] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [7] Sunder Armor maintenance (if configured)
local Arms_SunderMaintain = {
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

        -- Sunder Armor requires Defensive Stance; Devastate also Defensive
        -- Try Devastate first if talented, fall back to Sunder
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[ARMS] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[ARMS] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [8] Thunder Clap maintenance (Battle/Defensive Stance)
local Arms_ThunderClap = {
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
            format("[ARMS] Thunder Clap - Duration: %.1fs", state.thunder_clap_duration))
    end,
}

-- [9] Demoralizing Shout maintenance (all stances)
local Arms_DemoShout = {
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
            format("[ARMS] Demo Shout - Duration: %.1fs", state.demo_shout_duration))
    end,
}

-- [10] Slam (filler, any stance)
local Arms_Slam = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "arms_use_slam",

    matches = function(context, state)
        if context.is_moving then return false end
        -- Don't Slam in execute phase (Execute is better use of rage)
        if state.target_below_20 and context.settings.arms_execute_phase then return false end
        -- Resource pooling: hold GCD for MS/WW if imminent and rage is tight
        if should_pool_for_core_arms(context, state) then return false end
        -- Slam weaving: only Slam if the cast fits before next auto-attack
        if NS.get_time_until_swing() < SLAM_MIN_WINDOW then return false end
        return A.Slam:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Slam, icon, TARGET_UNIT, "[ARMS] Slam")
    end,
}

-- [12] Heroic Strike / Cleave (off-GCD rage dump)
local Arms_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        -- Already queued — yield the icon so GCD abilities can show
        if A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent() then return false end
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_hs_during_execute then return false end
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
        local threshold = context.settings.arms_hs_rage_threshold or 55
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
            return A.Cleave:Show(icon), format("[ARMS] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return A.HeroicStrike:Show(icon), format("[ARMS] Heroic Strike - Rage: %d", context.rage)
        end
        return nil
    end,
}

-- [11] Victory Rush (free instant after killing blow, 0 rage)
local Arms_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,
    setting_key = "arms_use_victory_rush",

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[ARMS] Victory Rush")
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("arms", {
    named("MaintainRend",    Arms_MaintainRend),
    named("MortalStrike",    Arms_MortalStrike),     -- #1 damage ability, always on CD
    named("SweepingStrikes", Arms_SweepingStrikes),   -- before WW to double hits in AoE
    named("Whirlwind",       Arms_Whirlwind),
    named("Overpower",       Arms_Overpower),         -- reactive dodge proc (5s window) — below WW per wowsims APL
    named("Execute",         Arms_Execute),
    named("VictoryRush",     Arms_VictoryRush),
    named("SunderMaintain",  Arms_SunderMaintain),
    named("ThunderClap",     Arms_ThunderClap),
    named("DemoShout",       Arms_DemoShout),
    named("Slam",            Arms_Slam),
    named("HeroicStrike",    Arms_HeroicStrike),
}, {
    context_builder = get_arms_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Arms module loaded")
