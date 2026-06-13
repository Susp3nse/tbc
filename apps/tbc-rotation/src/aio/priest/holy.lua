-- Priest Holy Healing Module
-- Reactive healing with Circle of Healing, Prayer of Mending, proc management
-- HealingEngine integration via try_heal_cast_fmt

local _G = _G
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "PRIEST" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Priest Holy]|r Core module not loaded!")
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
-- HOLY STATE (per-frame cache)
-- ============================================================================
local holy_state = {
    lowest = nil,           -- lowest HP entry (structured table)
    lowest_hp = 100,
    tank = nil,             -- tank entry (structured table)
    group_damaged_count = 0,
    surge_of_light = false,
    clearcasting = false,
    pom_ready = false,
    coh_ready = false,
}

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    -- Scan healing targets (structured entries sorted by effective_hp)
    local targets, count = scan_healing_targets()

    holy_state.lowest = (count > 0) and targets[1] or nil
    holy_state.lowest_hp = holy_state.lowest and holy_state.lowest.effective_hp or 100
    holy_state.tank = get_tank_target()
    holy_state.group_damaged_count = count_below_hp(context.settings.holy_aoe_hp or 80)

    -- Proc tracking
    holy_state.surge_of_light = context.has_surge_of_light
    holy_state.clearcasting = context.has_clearcasting
    holy_state.pom_ready = is_spell_available(A.PrayerOfMending) and A.PrayerOfMending:IsReady(PLAYER_UNIT)
    holy_state.coh_ready = is_spell_available(A.CircleOfHealing) and A.CircleOfHealing:IsReady(PLAYER_UNIT)

    return holy_state
end

-- ============================================================================
-- HOLY STRATEGIES
-- ============================================================================
rotation_registry:register("holy", {

    -- [1] Emergency PW:S (instant shield on critically low target)
    named("EmergencyPWS", {
        matches = function(context, state)
            if not context.settings.holy_use_pws then return false end
            if not state.lowest then return false end
            local threshold = context.settings.holy_pws_hp or 30
            if state.lowest_hp > threshold then return false end
            if state.lowest.has_weakened_soul then return false end
            return A.PowerWordShield:IsReady(PLAYER_UNIT)
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.PowerWordShield, icon, target.unit, "[P15]", "EMERGENCY PW:S",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [2] Emergency Flash Heal (critically low target)
    named("EmergencyFlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            local threshold = context.settings.holy_emergency_hp or 30
            return state.lowest_hp < threshold and state.lowest ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.FlashHeal, icon, target.unit, "[P14]", "EMERGENCY FH",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [3] Prayer of Mending (instant, on CD, tank priority — PRE-PULL capable)
    named("PrayerOfMending", {
        matches = function(context, state)
            if not state.pom_ready then return false end
            -- Pre-pull: gate OOC usage on setting
            if not context.in_combat then
                if not context.settings.holy_prepull_pom then return false end
            end
            return state.tank ~= nil or state.lowest ~= nil
        end,
        execute = function(icon, context, state)
            local target = state.tank or state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.PrayerOfMending, icon, target.unit, "[P13]", "Prayer of Mending",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [4] Circle of Healing (instant AoE, group damage)
    named("CircleOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.holy_use_coh then return false end
            if not state.coh_ready then return false end
            local min_count = context.settings.holy_aoe_count or 3
            return state.group_damaged_count >= min_count
        end,
        execute = function(icon, context, state)
            local target = state.lowest or state.tank
            if not target then return nil end
            return try_heal_cast_fmt(A.CircleOfHealing, icon, target.unit, "[P12]", "Circle of Healing",
                "on %s (%d hurt)", target.unit, state.group_damaged_count)
        end,
    }),

    -- [5] Binding Heal (self + target both damaged)
    named("BindingHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_use_binding_heal then return false end
            local self_threshold = context.settings.holy_binding_self_hp or 80
            if context.hp > self_threshold then return false end
            if not state.lowest then return false end
            if state.lowest.is_player then return false end
            return is_spell_available(A.BindingHeal)
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.BindingHeal, icon, target.unit, "[P11]", "Binding Heal",
                "on %s (self: %.0f%%)", target.unit, context.hp)
        end,
    }),

    -- [6] Clearcasting Greater Heal (free heal from Holy Concentration)
    named("ClearcastingGreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.clearcasting then return false end
            if not state.lowest then return false end
            return state.lowest_hp < 95
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.GreaterHeal, icon, target.unit, "[P10]", "Clearcasting GH",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [7] Renew on tank (maintain HoT — PRE-PULL capable)
    named("RenewTank", {
        matches = function(context, state)
            if not state.tank then return false end
            -- Pre-pull: gate OOC usage on setting
            if not context.in_combat then
                if not context.settings.holy_prepull_renew then return false end
            end
            if Unit(state.tank.unit):IsDead() then return false end
            local threshold = context.settings.holy_renew_hp or 90
            if state.tank.effective_hp > threshold then
                -- Pre-pull: always renew tank regardless of HP
                if context.in_combat then return false end
            end
            if state.tank.has_renew then return false end
            return true
        end,
        execute = function(icon, context, state)
            local target = state.tank
            if not target then return nil end
            return try_heal_cast_fmt(A.Renew, icon, target.unit, "[P9]", "Renew (tank)",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [8] Renew on injured (HoT spread — instant, before cast-time heals)
    named("RenewSpread", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.lowest then return false end
            local threshold = context.settings.holy_renew_hp or 90
            if state.lowest_hp > threshold then return false end
            if state.lowest.has_renew then return false end
            return true
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.Renew, icon, target.unit, "[P8]", "Renew",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [9] Inner Focus (off-GCD, fire before Greater Heal)
    named("InnerFocus", {
        is_gcd_gated = false,
        is_burst = true,
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.holy_use_inner_focus then return false end
            if context.has_inner_focus then return false end
            if not is_spell_available(A.InnerFocus) then return false end
            if not A.InnerFocus:IsReady(PLAYER_UNIT) then return false end
            if not state.lowest then return false end
            return state.lowest_hp < (context.settings.holy_renew_hp or 90)
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.InnerFocus, icon, PLAYER_UNIT, "[P7]", "Inner Focus",
                "(+ Greater Heal)")
        end,
    }),

    -- [10] Greater Heal (sustained healing, between flash and renew thresholds)
    named("GreaterHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            local renew_hp = context.settings.holy_renew_hp or 90
            return state.lowest_hp < renew_hp and state.lowest_hp >= flash_hp
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.GreaterHeal, icon, target.unit, "[P6]", "Greater Heal",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [11] Flash Heal (urgent healing, below flash threshold)
    named("FlashHeal", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not state.lowest then return false end
            local flash_hp = context.settings.holy_flash_heal_hp or 50
            return state.lowest_hp < flash_hp
        end,
        execute = function(icon, context, state)
            local target = state.lowest
            if not target then return nil end
            return try_heal_cast_fmt(A.FlashHeal, icon, target.unit, "[P5]", "Flash Heal",
                "on %s (%.0f%%)", target.unit, target.effective_hp)
        end,
    }),

    -- [12] Prayer of Healing (channeled AoE heal)
    named("PrayerOfHealing", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_use_poh then return false end
            local min_count = context.settings.holy_aoe_count or 3
            return state.group_damaged_count >= min_count
        end,
        execute = function(icon, context, state)
            if is_spell_available(A.PrayerOfHealing) and A.PrayerOfHealing:IsReady(PLAYER_UNIT) then
                return try_cast_fmt(A.PrayerOfHealing, icon, PLAYER_UNIT, "[P4]", "Prayer of Healing",
                    "%d hurt", state.group_damaged_count)
            end
            return nil
        end,
    }),

    -- [13] Racial (off-GCD, Berserking/Arcane Torrent)
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
                return A.Berserking:Show(icon), "[HOLY] Berserking"
            end
            if is_spell_available(A.ArcaneTorrent) and A.ArcaneTorrent:IsReady(PLAYER_UNIT) then
                return A.ArcaneTorrent:Show(icon), "[HOLY] Arcane Torrent"
            end
            return nil
        end,
    }),

    -- [14] Surge of Light Smite (free instant Smite proc — only if no urgent healing)
    named("SurgeOfLightSmite", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not state.surge_of_light then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_flash_heal_hp or 50) then return false end
            return true
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.Smite, icon, "target", "[P3]", "Surge of Light Smite", "")
        end,
    }),

    -- [15] Idle SW:P (DPS when everyone healthy)
    named("IdleSWP", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            -- Only if SW:P not already on target
            if (Unit("target"):HasDeBuffs(Constants.DEBUFF_ID.SHADOW_WORD_PAIN, "player", true) or 0) > 0 then return false end
            return A.ShadowWordPain:IsReady("target")
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.ShadowWordPain, icon, "target", "[P2]", "Idle SW:P", "")
        end,
    }),

    -- [16] Idle Holy Fire (DPS when everyone healthy)
    named("IdleHolyFire", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            if (Unit("target"):HasDeBuffs(Constants.DEBUFF_ID.HOLY_FIRE_DOT, "player", true) or 0) > 0 then return false end
            return is_spell_available(A.HolyFire) and A.HolyFire:IsReady("target")
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.HolyFire, icon, "target", "[P1]", "Idle Holy Fire", "")
        end,
    }),

    -- [17] Idle Smite (filler DPS when everyone healthy)
    named("IdleSmite", {
        matches = function(context, state)
            if not context.in_combat then return false end
            if context.is_moving then return false end
            if not context.settings.holy_dps_when_idle then return false end
            if not context.has_valid_enemy_target then return false end
            if state.lowest_hp < (context.settings.holy_renew_hp or 90) then return false end
            if context.mana_pct < (context.settings.holy_dps_mana_floor or 70) then return false end
            return A.Smite:IsReady("target")
        end,
        execute = function(icon, context, state)
            return try_cast_fmt(A.Smite, icon, "target", "[P1]", "Idle Smite", "")
        end,
    }),

}, {
    context_builder = get_holy_state,
})

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Priest]|r Holy rotation loaded (17 strategies)")
