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
local AddDebugLogLine = NS.AddDebugLogLine
local GetTime = _G.GetTime

local scan_healing_targets = NS.scan_healing_targets
local HOLY_LIGHT_RANKS = NS.HOLY_LIGHT_RANKS
local FLASH_OF_LIGHT_RANKS = NS.FLASH_OF_LIGHT_RANKS
local HL_COEFFICIENT = NS.HL_COEFFICIENT
local FOL_COEFFICIENT = NS.FOL_COEFFICIENT
local HEALING_LIGHT_MULT = NS.HEALING_LIGHT_MULT
local GetSpellBonusHealing = _G.GetSpellBonusHealing
local IsSpellKnown = _G.IsSpellKnown
local get_spell_mana_cost = NS.get_spell_mana_cost
local Player = NS.Player

-- Rank-safe heal cast: bypasses IsReady (which fails for non-max ranks)
-- Does NOT call HE.SetTarget — the framework's HE auto-targeting (OnUpdate)
-- handles target injection into the icon macro separately.
-- Calling SetTarget here overwrites the ranked macro with max-rank.
local function ranked_heal_cast(ability, icon, target_unit, log_message)
    local result = ability:Show(icon)
    if result then return result, log_message end
    return nil
end

-- ============================================================================
-- HEAL SELECTION (deficit math + rank selection)
-- ============================================================================

-- Check if a specific spell rank is castable: trained + enough mana
local function is_rank_castable(spell_action)
    if not IsSpellKnown(spell_action.ID) then return false end
    local cost = get_spell_mana_cost(spell_action)
    if cost > 0 and Player:Mana() < cost then return false end
    return true
end

-- Compute expected heal for a rank entry given current +healing
local function expected_heal(rank_entry, bonus_healing, coefficient)
    local base_avg = (rank_entry.base_min + rank_entry.base_max) / 2
    return (base_avg + bonus_healing * coefficient) * HEALING_LIGHT_MULT
end

-- Select best rank from a rank table for a given deficit
-- Walk high-to-low, pick first rank that fits the deficit within 30% overheal.
-- When all ranks overheal, pick the most mana-efficient castable rank.
-- skip_overheal_opt: true = use highest trained rank (MS on target, need throughput)
local function select_rank(rank_table, deficit, bonus_healing, coefficient, skip_overheal_opt)
    local best_eff_entry = nil
    local best_eff = 0
    for i = 1, #rank_table do
        local entry = rank_table[i]
        if is_rank_castable(entry.spell) then
            if skip_overheal_opt then
                return entry
            end
            local heal = expected_heal(entry, bonus_healing, coefficient)
            if heal <= deficit * 1.3 then
                return entry
            end
            -- Track most mana-efficient rank as fallback
            local cost = get_spell_mana_cost(entry.spell)
            if cost > 0 then
                local eff = heal / cost
                if eff > best_eff then
                    best_eff = eff
                    best_eff_entry = entry
                end
            elseif not best_eff_entry then
                best_eff_entry = entry
            end
        end
    end
    return best_eff_entry
end

-- Pre-allocated result table (no table creation in combat)
local heal_result = { spell = nil, label = "", spell_type = "" }

-- select_heal: picks spell type (HL vs FoL) and best rank for target
local function select_heal(context, state, target)
    if context.is_moving then return nil end

    local bonus_healing = GetSpellBonusHealing() or 0
    local deficit = target.deficit or 0

    -- Determine spell type: HL or FoL
    local use_hl = false

    -- MS/healing reduction -> HL (FoL is useless at 50% reduced)
    if target.has_healing_reduction then
        use_hl = true
    -- Divine Favor active -> HL (maximize guaranteed crit value)
    elseif state.divine_favor_active then
        use_hl = true
    -- High incoming DPS -> HL (FoL throughput can't keep up)
    elseif target.incoming_dps and target.incoming_dps > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        local fol_hps = max_fol / 1.5
        if target.incoming_dps > fol_hps then
            use_hl = true
        end
    end

    -- Deficit math (only if not already forced to HL)
    if not use_hl and deficit > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        if deficit > max_fol * 1.3 then
            use_hl = true
        end
    end

    -- Tank proactive: FoL even at full HP in combat (mana floor gated)
    if not use_hl and deficit == 0 and target.is_tank and context.in_combat then
        local mana_floor = context.settings.proactive_fol_mana_floor or 30
        if context.mana_pct < mana_floor then return nil end
        for i = #FLASH_OF_LIGHT_RANKS, 1, -1 do
            local entry = FLASH_OF_LIGHT_RANKS[i]
            if is_rank_castable(entry.spell) then
                heal_result.spell = entry.spell
                heal_result.label = "FoL " .. entry.label
                heal_result.spell_type = "FoL"
                return heal_result
            end
        end
        return nil
    end

    -- No deficit and not proactive -> don't heal
    if deficit == 0 then return nil end

    -- Select best rank
    local skip_overheal = target.has_healing_reduction
    if use_hl then
        local hl_rank = select_rank(HOLY_LIGHT_RANKS, deficit, bonus_healing, HL_COEFFICIENT, skip_overheal)
        if not hl_rank then return nil end
        -- Sanity check: if the chosen HL rank is less efficient than FoL,
        -- fall back to FoL (unless forced to HL by MS/DF)
        if not target.has_healing_reduction and not state.divine_favor_active then
            local fol_rank = select_rank(FLASH_OF_LIGHT_RANKS, deficit, bonus_healing, FOL_COEFFICIENT, false)
            if fol_rank then
                local hl_cost = get_spell_mana_cost(hl_rank.spell)
                local fol_cost = get_spell_mana_cost(fol_rank.spell)
                local hl_heal = expected_heal(hl_rank, bonus_healing, HL_COEFFICIENT)
                local fol_heal = expected_heal(fol_rank, bonus_healing, FOL_COEFFICIENT)
                -- FoL also gets cast time advantage (1.5s vs 2.5s) — compare HPS/mana
                local hl_eff = hl_cost > 0 and (hl_heal / 2.5) / hl_cost or 0
                local fol_eff = fol_cost > 0 and (fol_heal / 1.5) / fol_cost or 0
                if fol_eff > hl_eff then
                    heal_result.spell = fol_rank.spell
                    heal_result.label = "FoL " .. fol_rank.label
                    heal_result.spell_type = "FoL"
                    return heal_result
                end
            end
        end
        heal_result.spell = hl_rank.spell
        heal_result.label = "HL " .. hl_rank.label
        heal_result.spell_type = "HL"
    else
        local rank = select_rank(FLASH_OF_LIGHT_RANKS, deficit, bonus_healing, FOL_COEFFICIENT, skip_overheal)
        if not rank then return nil end
        heal_result.spell = rank.spell
        heal_result.label = "FoL " .. rank.label
        heal_result.spell_type = "FoL"
    end

    return heal_result
end

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
local holy_lowest_entry = { unit = nil, hp = 100, is_tank = false,
    deficit = 0, has_healing_reduction = false, incoming_dps = 0 }

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
                holy_lowest_entry.is_tank = entry.is_tank
                holy_lowest_entry.deficit = entry.deficit or 0
                holy_lowest_entry.has_healing_reduction = entry.has_healing_reduction or false
                holy_lowest_entry.incoming_dps = entry.incoming_dps or 0
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
        if not context.in_combat then return false end
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
        local in_range = _G.IsSpellInRange("Holy Shock", state.lowest.unit)
        if in_range ~= 1 then return false end
        if state.lowest.hp >= 100 then return false end
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

-- [6] Light's Grace proc (HL R1 to activate -0.5s HL cast time buff)
-- Luxury cast: only when nobody is in danger
local Holy_LightsGraceProc = {
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.in_combat then return false end
        if state.lights_grace_active then return false end
        if state.divine_favor_active then return false end
        if not is_rank_castable(A.HolyLightR1) then return false end
        if state.emergency_count > 0 then return false end
        -- Safety: skip if lowest target is critically low (use real heal instead)
        if not state.lowest then return false end
        if state.lowest.hp < 30 then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return ranked_heal_cast(A.HolyLightR1, icon, target.unit,
            format("[HOLY] HL R1 (Light's Grace proc) -> %s (%.0f%%)", target.unit, target.hp))
    end,
}

-- [7] HealTarget (smart HL/FoL selection with downranking)
-- Uses select_heal() for spell type + rank based on deficit, incoming damage,
-- healing reduction, Divine Favor, and Light's Grace state.
local Holy_HealTarget = {
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.lowest then return false end
        if state.lowest.is_tank and context.in_combat then return true end
        if state.lowest.hp >= 100 then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        local result = select_heal(context, state, target)
        if not result or not result.spell then return nil end
        return ranked_heal_cast(result.spell, icon, target.unit,
            format("[HOLY] %s -> %s (%.0f%%, deficit: %d)", result.label, target.unit, target.hp, target.deficit or 0))
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
    named("LightsGraceProc",    Holy_LightsGraceProc),
    named("HealTarget",          Holy_HealTarget),
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
