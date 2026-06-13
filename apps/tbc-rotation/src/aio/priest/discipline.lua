-- Priest Discipline Healing Module
-- Damage prevention with PW:S, Pain Suppression, Power Infusion
-- HealingEngine integration via try_heal_cast_fmt

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Disc]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Constants = NS.Constants
local is_spell_available = NS.is_spell_available
local try_cast_fmt = NS.try_cast_fmt
local try_heal_cast_fmt = NS.try_heal_cast_fmt
local named = NS.named
local scan_healing_targets = NS.scan_healing_targets
local get_tank_target = NS.get_tank_target
local count_below_hp = NS.count_below_hp

local PLAYER_UNIT = "player"

-- ============================================================================
-- DISCIPLINE STATE (per-frame cache)
-- ============================================================================
local disc_state = {
    lowest = nil,           -- lowest HP entry (structured table)
    lowest_hp = 100,
    tank = nil,             -- tank entry (structured table)
    group_damaged_count = 0,
    inner_focus_ready = false,
    pain_suppression_ready = false,
    power_infusion_ready = false,
    pom_ready = false,
}

local function get_disc_state(context)
    if context._disc_valid then return disc_state end
    context._disc_valid = true

    disc_state.inner_focus_ready = is_spell_available(A.InnerFocus) and A.InnerFocus:IsReady(PLAYER_UNIT)
    disc_state.pain_suppression_ready = is_spell_available(A.PainSuppression) and (A.PainSuppression:GetCooldown() or 0) < 0.5
    disc_state.power_infusion_ready = is_spell_available(A.PowerInfusion) and (A.PowerInfusion:GetCooldown() or 0) < 0.5
    disc_state.pom_ready = is_spell_available(A.PrayerOfMending) and A.PrayerOfMending:IsReady(PLAYER_UNIT)

    -- Scan healing targets (structured entries sorted by effective_hp)
    local targets, count = scan_healing_targets()
    disc_state.lowest = (count > 0) and targets[1] or nil
    disc_state.lowest_hp = disc_state.lowest and disc_state.lowest.effective_hp or 100
    disc_state.tank = get_tank_target()
    disc_state.group_damaged_count = count_below_hp(context.settings.disc_shield_hp or 90)

    return disc_state
end

-- ============================================================================
-- DISCIPLINE STRATEGIES
-- ============================================================================
rotation_registry:register("discipline", {

    -- [1] Pain Suppression (tank critically low, off-GCD)
    named("PainSuppression", {
        is_gcd_gated = false,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_pain_suppression then return false end
            if not state.pain_suppression_ready then return false end
            if not state.tank then return false end
            local threshold = context.settings.disc_pain_suppression_hp or 20
            return state.tank.effective_hp < threshold
        end,
        execute = function(icon, context, state)
            local target = state.tank
            if not target then return nil end
            return try_heal_cast_fmt(A.PainSuppression, icon, target.unit, "[P15]", "Pain Suppression",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [2] Emergency Flash Heal (critically low target)
    named("EmergencyFlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            local threshold = context.settings.disc_emergency_hp or 25
            return state.lowest_hp < threshold and state.lowest ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.FlashHeal, icon, target.unit, "[P14]", "EMERGENCY FH",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [3] Binding Heal (self + target both damaged)
    named("BindingHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if context.hp > 80 then return false end
            if not state.lowest then return false end
            if state.lowest.is_player then return false end
            return is_spell_available(A.BindingHeal)
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.BindingHeal, icon, target.unit, "[P13]", "Binding Heal",
                "on %s (self: %.0f%%)", target.unit, context.hp)
        end,
    }),

    -- [4] PW:S on tank (pre-pull capable)
    named("ShieldTank", {
        matches = function(context, state)
            if not state.tank then return false end
            -- Pre-pull: gate OOC usage on setting
            if not context.in_combat then
                if not context.settings.disc_prepull_shield then return false end
            end
            if state.tank.has_weakened_soul then return false end
            local threshold = context.settings.disc_shield_hp or 90
            if state.tank.effective_hp > threshold then
                -- Pre-pull: always shield tank regardless of HP
                if context.in_combat then return false end
            end
            return A.PowerWordShield:IsReady(PLAYER_UNIT)
        end,
        execute = function(icon, context, state)
            local target = state.tank
            if not target then return nil end
            return try_heal_cast_fmt(A.PowerWordShield, icon, target.unit, "[P12]", "PW:S (tank)",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [5] Prayer of Mending (instant, 10s CD)
    named("PrayerOfMending", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.pom_ready then return false end
            return state.tank ~= nil or state.lowest ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.tank or state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.PrayerOfMending, icon, target.unit, "[P11]", "Prayer of Mending",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [6] Inner Focus + Greater Heal (off-GCD trigger + free GH)
    named("InnerFocusGreaterHeal", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_inner_focus then return false end
            if not state.inner_focus_ready then return false end
            if context.has_inner_focus then return false end
            if not state.lowest then return false end
            return state.lowest_hp < 80
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.InnerFocus, icon, PLAYER_UNIT, "[P10]", "Inner Focus",
                "(+ Greater Heal)")
        end,
    }),

    -- [7] Power Infusion (off-GCD, self)
    named("PowerInfusion", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.disc_use_power_infusion then return false end
            if not state.power_infusion_ready then return false end
            if context.has_power_infusion then return false end
            return true
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.PowerInfusion, icon, PLAYER_UNIT, "[P9]", "Power Infusion",
                "(self)")
        end,
    }),

    -- [8] Racial (off-GCD)
    named("Racial", {
        is_gcd_gated = false,
        setting_key = "use_racial",
        matches = function(context, state)
            if not context.in_combat then return false end
            if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then return true end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then return true end
            return false
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.Berserking) and A.Berserking:IsReady(PLAYER_UNIT) then
                return A.Berserking:Show(icon), "[DISC] Berserking"
            end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
                return A.ArcaneTorrent:Show(icon), "[DISC] Arcane Torrent"
            end
            return nil
        end,
    }),

    -- [9] PW:S on non-tank (if not tank-only mode)
    named("ShieldOthers", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.settings.disc_shield_tank_only then return false end
            if not state.lowest then return false end
            if state.tank and state.lowest.unit == state.tank.unit then return false end
            if state.lowest.has_weakened_soul then return false end
            local threshold = context.settings.disc_shield_hp or 90
            return state.lowest_hp < threshold
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.PowerWordShield, icon, target.unit, "[P8]", "PW:S",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [10] Renew on tank (pre-pull capable)
    named("RenewTank", {
        matches = function(context, state)
            if not state.tank then return false end
            -- Pre-pull: gate OOC usage on setting
            if not context.in_combat then
                if not context.settings.disc_prepull_renew then return false end
            end
            if Unit(state.tank.unit):IsDead() then return false end
            local threshold = context.settings.disc_renew_hp or 85
            if state.tank.effective_hp > threshold then
                if context.in_combat then return false end
            end
            if state.tank.has_renew then return false end
            return true
        end,
        execute = function(icon, context, state)
            local target = state.tank
            if not target then return nil end
            return try_heal_cast_fmt(A.Renew, icon, target.unit, "[P7]", "Renew (tank)",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [11] Greater Heal (sustained healing, with Inner Focus buff if active)
    named("GreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest then return false end
            local flash_hp = context.settings.disc_flash_heal_hp or 50
            return state.lowest_hp < (context.settings.disc_renew_hp or 85) and state.lowest_hp >= flash_hp
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.GreaterHeal, icon, target.unit, "[P6]", "Greater Heal",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [12] Flash Heal (moderate urgency)
    named("FlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest then return false end
            local flash_hp = context.settings.disc_flash_heal_hp or 50
            return state.lowest_hp < flash_hp
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.FlashHeal, icon, target.unit, "[P5]", "Flash Heal",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [13] Renew on injured (HoT spread)
    named("RenewSpread", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.lowest then return false end
            local threshold = context.settings.disc_renew_hp or 85
            if state.lowest_hp > threshold then return false end
            if state.lowest.has_renew then return false end
            return true
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.Renew, icon, target.unit, "[P4]", "Renew",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [14] Prayer of Healing (group damage)
    named("PrayerOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            return state.group_damaged_count >= (context.settings.disc_aoe_count or 3)
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.PrayerOfHealing) and A.PrayerOfHealing:IsReady(PLAYER_UNIT) then
                return try_cast_fmt(A.PrayerOfHealing, icon, PLAYER_UNIT, "[P3]", "Prayer of Healing",
                    "%d hurt", state.group_damaged_count)
            end
            return nil
        end,
    }),

}, {
    context_builder = get_disc_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Discipline rotation loaded")
