--- Kebab Warrior Module (DW Arms)
--- Dual-wield Arms playstyle: Mortal Strike + Whirlwind in Berserker Stance
--- Follows the fury rotation pattern but with MS instead of BT, OP on procs
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Kebab]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Kebab]|r Registry not found!")
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
-- KEBAB STATE (context_builder)
-- ============================================================================
local kebab_state = {
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
    ms_cd = 0,
    ww_cd = 0,
}

local function get_kebab_state(context)
    if context._kebab_valid then return kebab_state end
    context._kebab_valid = true

    kebab_state.target_below_20 = context.target_hp < 20 and context.target_is_elite
    kebab_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    kebab_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    kebab_state.thunder_clap_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    kebab_state.demo_shout_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    kebab_state.ms_cd = A.MortalStrike:GetCooldown() or 0
    kebab_state.ww_cd = A.Whirlwind:GetCooldown() or 0

    return kebab_state
end

-- ============================================================================
-- RAGE CONSTANTS
-- ============================================================================
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_PUMMEL = 10

-- ============================================================================
-- SWEEPING STRIKES RAGE POOLING
-- ============================================================================
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context)
    if context.enemy_count < 2 then return false end
    if not context.settings.kebab_use_sweeping_strikes then return false end
    if not is_spell_available(A.SweepingStrikes) then return false end
    if context.sweeping_strikes_active then return false end
    local ss_cd = A.SweepingStrikes:GetCooldown() or 0
    if ss_cd <= SS_POOL_WINDOW and context.rage < SS_RESERVE_FLOOR then return true end
    return false
end

-- ============================================================================
-- HS/CLEAVE CORE ABILITY STARVATION CHECK
-- ============================================================================
local function would_starve_core_kebab(context, state, cost)
    cost = cost or 15
    -- MS imminent
    if state.ms_cd >= 0 and state.ms_cd <= 1.5 and context.in_melee_range then
        if (context.rage - cost) < RAGE_COST_MS then return true end
    end
    -- WW imminent
    if context.settings.kebab_use_whirlwind then
        if state.ww_cd >= 0 and state.ww_cd <= 1.5 and context.in_melee_range then
            if (context.rage - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Execute (target <20% HP — highest ST priority per sim)
local Kebab_Execute = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_execute_phase",

    matches = function(context, state)
        if not state.target_below_20 then return false end
        local exec_cost = A.Execute:GetSpellPowerCostCache() or 15
        if context.rage < exec_cost then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[KEBAB] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [2] Sweeping Strikes (AoE — before WW to double hits)
local Kebab_SweepingStrikes = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_sweeping_strikes",

    matches = function(context, state)
        if not is_spell_available(A.SweepingStrikes) then return false end
        if context.sweeping_strikes_active then return false end
        if context.enemy_count < 2 then return false end
        if context.rage < 30 then return false end
        return A.SweepingStrikes:IsReady(PLAYER_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        return A.SweepingStrikes:Show(icon), format("[KEBAB] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
    end,
}

-- [3] Whirlwind (Berserker Stance — above MS for DW, guarded by SS reserve)
local Kebab_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_whirlwind",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_use_ww_execute then return false end
        end
        if context.rage < 25 then return false end
        if should_reserve_for_sweeping(context) then return false end
        return A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true)
    end,

    execute = function(icon, context, state)
        if context.stance ~= Constants.STANCE.BERSERKER then
            -- No TM — accept rage loss to access WW (staying in wrong stance is worse)
            if A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), "[KEBAB] → Berserker (for WW)"
            end
            return nil
        end
        return A.Whirlwind:Show(icon), format("[KEBAB] Whirlwind - Rage: %d", context.rage)
    end,
}

-- [4] Mortal Strike (below WW in priority for DW)
local Kebab_MortalStrike = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_use_ms_execute then return false end
        end
        return A.MortalStrike:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.MortalStrike, icon, TARGET_UNIT, "[KEBAB] Mortal Strike")
    end,
}

-- [5] Overpower (only if already in Battle Stance with dodge proc)
-- No proactive stance dance — Kebab lives in Berserker, uses OP opportunistically
local Kebab_Overpower = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_overpower",

    matches = function(context, state)
        -- Only use if already in Battle Stance (from a stance swap for other reasons)
        if context.stance ~= Constants.STANCE.BATTLE then return false end
        return A.Overpower:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Overpower, icon, TARGET_UNIT,
            format("[KEBAB] Overpower - Rage: %d", context.rage))
    end,
}

-- [6] Victory Rush (free instant after killing blow)
local Kebab_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,
    setting_key = "kebab_use_victory_rush",

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[KEBAB] Victory Rush")
    end,
}

-- [7] Sunder Armor maintenance (if configured)
local Kebab_SunderMaintain = {
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

        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[KEBAB] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[KEBAB] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [8] Thunder Clap maintenance
local Kebab_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_thunder_clap",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if state.thunder_clap_duration > 2 then return false end
        return A.ThunderClap:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ThunderClap, icon, PLAYER_UNIT,
            format("[KEBAB] Thunder Clap - Duration: %.1fs", state.thunder_clap_duration))
    end,
}

-- [9] Demoralizing Shout maintenance
local Kebab_DemoShout = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_demo_shout",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if not context.in_melee_range then return false end
        if state.demo_shout_duration > 3 then return false end
        return A.DemoralizingShout:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, PLAYER_UNIT,
            format("[KEBAB] Demo Shout - Duration: %.1fs", state.demo_shout_duration))
    end,
}

-- [10] Heroic Strike / Cleave (off-GCD rage dump with core starvation check)
local Kebab_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent() then return false end
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_hs_during_execute then return false end
        end
        -- HS Trick: proactively queue when OH swing is imminent
        if context.settings.hs_trick and context.has_offhand then
            local oh_remaining = context.oh_remain or 0
            local mh_remaining = context.mh_remain or 0
            if oh_remaining > 0 and oh_remaining <= 0.4 then
                if mh_remaining > oh_remaining + 0.3 then
                    return true
                end
            end
        end
        local threshold = context.settings.kebab_hs_rage_threshold or 40
        if context.settings.hs_trick and context.has_offhand then
            threshold = 30
        end
        if context.rage < threshold then return false end
        if would_starve_core_kebab(context, state, 15) then return false end
        if context.settings.use_interrupt then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                if (context.rage - 15) < RAGE_COST_PUMMEL then return false end
            end
        end
        return true
    end,

    execute = function(icon, context, state)
        local cleave_at = context.settings.aoe_threshold or 2
        local cc_safe = not (context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check)
        if cc_safe and cleave_at > 0 and context.enemy_count >= cleave_at and A.Cleave:IsReady(TARGET_UNIT) then
            return A.Cleave:Show(icon), format("[KEBAB] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return A.HeroicStrike:Show(icon), format("[KEBAB] Heroic Strike - Rage: %d", context.rage)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("kebab", {
    named("Execute",         Kebab_Execute),          -- Highest ST priority per sim
    named("SweepingStrikes", Kebab_SweepingStrikes),  -- Before WW to double hits in AoE
    named("Whirlwind",       Kebab_Whirlwind),        -- Above MS for DW (more damage per rage)
    named("MortalStrike",    Kebab_MortalStrike),
    named("Overpower",       Kebab_Overpower),         -- Opportunistic (Battle Stance only)
    named("VictoryRush",     Kebab_VictoryRush),
    named("SunderMaintain",  Kebab_SunderMaintain),
    named("ThunderClap",     Kebab_ThunderClap),
    named("DemoShout",       Kebab_DemoShout),
    named("HeroicStrike",    Kebab_HeroicStrike),
}, {
    context_builder = get_kebab_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Kebab module loaded")
