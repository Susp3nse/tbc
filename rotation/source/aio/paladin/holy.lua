--- Holy Paladin Module
--- Holy playstyle strategies (tank/party healing)
--- Part of the modular AIO rotation system
--- Loads after: core.lua, paladin/class.lua, paladin/healing.lua

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "PALADIN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Holy]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Holy]|r Registry not found!")
    return
end

if not NS.scan_healing_targets then
    print("|cFFFF0000[Flux AIO Holy]|r Healing module not loaded!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local safe_heal_cast = NS.safe_heal_cast
local named = NS.named
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

local scan_healing_targets = NS.scan_healing_targets

-- ============================================================================
-- HOLY STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local holy_state = {
    lights_grace_active = false,
    divine_favor_active = false,
    divine_illumination_active = false,
    lowest = nil,           -- lowest HP target (unit string + hp number)
    emergency_count = 0,    -- targets below critical threshold
    cleanse_target = nil,   -- first target needing dispel
}
-- Pre-allocated lowest entry — reused each frame, no table creation in combat
local holy_lowest_entry = { unit = nil, hp = 100 }

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    -- Buff tracking
    holy_state.lights_grace_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.LIGHTS_GRACE) or 0) > 0
    holy_state.divine_favor_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.DIVINE_FAVOR) or 0) > 0
    holy_state.divine_illumination_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.DIVINE_ILLUMINATION) or 0) > 0

    -- Reset
    holy_state.lowest = nil
    holy_state.emergency_count = 0
    holy_state.cleanse_target = nil

    -- Scan party/raid for healing targets.
    -- scan_healing_targets() uses PARTY_UNITS in a party, RAID_UNITS (up to 40) in a raid.
    -- safe_heal_cast() calls HE.SetTarget(unit) before Show() so TMW injects [@unit,help]
    -- into the icon macro. Our job here is to decide WHICH spell and WHICH unit.
    local targets, count = scan_healing_targets()
    for i = 1, count do
        local entry = targets[i]
        if entry then
            if not holy_state.lowest then
                holy_lowest_entry.unit = entry.unit
                holy_lowest_entry.hp   = entry.effective_hp
                holy_state.lowest = holy_lowest_entry
            end
            if entry.effective_hp < 40 then
                holy_state.emergency_count = holy_state.emergency_count + 1
            end
            if not holy_state.cleanse_target and entry.needs_cleanse then
                holy_state.cleanse_target = entry
            end
        end
    end

    return holy_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Divine Illumination (off-GCD, -50% mana cost 15s)
local Holy_DivineIllumination = {
    is_gcd_gated = false,
    spell = A.DivineIllumination,
    spell_target = PLAYER_UNIT,
    setting_key = "holy_use_divine_illumination",

    matches = function(context, state)
        -- Use when mana is getting low to save on HL spam
        local di_pct = context.settings.holy_divine_illumination_pct or 60
        if context.mana_pct > di_pct then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DivineIllumination, icon, PLAYER_UNIT,
            format("[HOLY] Divine Illumination - Mana: %.0f%%", context.mana_pct))
    end,
}

-- [2] Divine Favor (off-GCD, next heal guaranteed crit)
-- Use on cooldown for mana sustain: guaranteed crit = Illumination mana refund on next HL
local Holy_DivineFavor = {
    is_gcd_gated = false,
    spell = A.DivineFavor,
    spell_target = PLAYER_UNIT,
    setting_key = "holy_use_divine_favor",

    matches = function(context, state)
        -- Use on CD whenever someone needs healing (crit refund = mana sustain)
        if not state.lowest then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.DivineFavor, icon, PLAYER_UNIT, "[HOLY] Divine Favor (crit + mana refund)")
    end,
}

-- [3] Racial (off-GCD — Stoneform defensive, Gift of the Naaru heal)
local Holy_Racial = {
    is_gcd_gated = false,
    setting_key = "use_racial",

    matches = function(context, state)
        if A.Stoneform:IsReady(PLAYER_UNIT) then return true end
        if A.GiftOfTheNaaru and state.lowest and state.lowest.hp < 60 then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[HOLY] Stoneform"
        end
        if A.GiftOfTheNaaru and state.lowest and state.lowest.hp < 60 then
            return safe_heal_cast(A.GiftOfTheNaaru, icon, state.lowest.unit,
                format("[HOLY] Gift of the Naaru -> %s (%.0f%%)", state.lowest.unit, state.lowest.hp))
        end
        return nil
    end,
}

-- [4] Holy Shock heal (instant, 15s CD)
local Holy_HolyShockHeal = {
    spell = A.HolyShock,
    spell_target = PLAYER_UNIT,
    setting_key = "holy_use_holy_shock",

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_holy_shock_hp or 50
        if state.lowest.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return safe_heal_cast(A.HolyShock, icon, target.unit,
            format("[HOLY] Holy Shock -> %s (%.0f%%)", target.unit, target.hp))
    end,
}

-- [4] Lay on Hands (emergency, full heal, drains all mana)
local Holy_LayOnHands = {
    spell = A.LayOnHands,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.lowest then return false end
        if state.lowest.hp > 15 then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return safe_heal_cast(A.LayOnHands, icon, target.unit,
            format("[HOLY] Lay on Hands -> %s (%.0f%%)", target.unit, target.hp))
    end,
}

-- [5] Holy Light (PRIMARY heal — spam on assigned target)
-- TBC Holy Paladin's bread and butter. HL is the default heal, not FoL.
local Holy_HolyLight = {
    spell = A.HolyLight,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_holy_light_hp or 90
        if state.lowest.hp > threshold then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return safe_heal_cast(A.HolyLight, icon, target.unit,
            format("[HOLY] Holy Light -> %s (%.0f%%)", target.unit, target.hp))
    end,
}

-- [6] Flash of Light (light damage only — rare use when HL would overheal)
local Holy_FlashOfLight = {
    spell = A.FlashOfLight,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.lowest then return false end
        local threshold = context.settings.holy_flash_of_light_hp or 90
        if state.lowest.hp > threshold then return false end
        -- FoL is the fallback when HL threshold isn't met or while moving
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return safe_heal_cast(A.FlashOfLight, icon, target.unit,
            format("[HOLY] Flash of Light -> %s (%.0f%%)", target.unit, target.hp))
    end,
}

-- [7] Judgement maintain (off-GCD, keep JoL/JoW on boss when safe)
local Holy_JudgementMaintain = {
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        local judge_type = context.settings.holy_judge_debuff or "light"
        if judge_type == "none" then return false end
        -- Don't judge during emergencies (Judgement is off-GCD but still costs GCD equivalent)
        if state.emergency_count > 0 then return false end
        -- Check if judgement debuff is already on target
        if judge_type == "light" then
            local has_jol = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.JUDGEMENT_LIGHT) or 0) > 0
            if has_jol then return false end
        elseif judge_type == "wisdom" then
            local has_jow = (Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.JUDGEMENT_WISDOM) or 0) > 0
            if has_jow then return false end
        end
        -- Need a seal active to judge
        if not context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        local judge_type = context.settings.holy_judge_debuff or "light"
        -- Ensure correct seal is active before judging (judgement consumes current seal)
        if judge_type == "light" and not context.seal_light_active then
            if A.SealOfLight:IsReady(PLAYER_UNIT) then
                return A.SealOfLight:Show(icon), "[HOLY] Seal of Light (for JoL)"
            end
            return nil
        elseif judge_type == "wisdom" and not context.seal_wisdom_active then
            if A.SealOfWisdom:IsReady(PLAYER_UNIT) then
                return A.SealOfWisdom:Show(icon), "[HOLY] Seal of Wisdom (for JoW)"
            end
            return nil
        end
        return try_cast(A.Judgement, icon, TARGET_UNIT, "[HOLY] Judgement (maintain debuff)")
    end,
}

-- [8] Seal maintain (keep chosen seal active)
local Holy_SealMaintain = {
    matches = function(context, state)
        local seal = context.settings.holy_seal_choice or "wisdom"
        if seal == "none" then return false end
        if seal == "wisdom" and context.seal_wisdom_active then return false end
        if seal == "light" and context.seal_light_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        local seal = context.settings.holy_seal_choice or "wisdom"
        if seal == "wisdom" and A.SealOfWisdom:IsReady(PLAYER_UNIT) then
            return A.SealOfWisdom:Show(icon), "[HOLY] Seal of Wisdom"
        elseif seal == "light" and A.SealOfLight:IsReady(PLAYER_UNIT) then
            return A.SealOfLight:Show(icon), "[HOLY] Seal of Light"
        end
        return nil
    end,
}

-- [9] Cleanse party members
local Holy_Cleanse = {
    spell = A.Cleanse,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.settings.holy_use_cleanse then return false end
        if not state.cleanse_target then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.cleanse_target
        return safe_heal_cast(A.Cleanse, icon, target.unit,
            format("[HOLY] Cleanse -> %s", target.unit))
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("holy", {
    named("DivineIllumination",  Holy_DivineIllumination),
    named("DivineFavor",         Holy_DivineFavor),
    named("Racial",              Holy_Racial),
    named("HolyShockHeal",       Holy_HolyShockHeal),
    named("LayOnHands",          Holy_LayOnHands),
    named("HolyLight",           Holy_HolyLight),
    named("FlashOfLight",        Holy_FlashOfLight),
    named("JudgementMaintain",   Holy_JudgementMaintain),
    named("SealMaintain",        Holy_SealMaintain),
    named("Cleanse",             Holy_Cleanse),
}, {
    context_builder = get_holy_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Paladin]|r Holy module loaded")
