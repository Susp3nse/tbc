--- Protection Paladin Module
--- Protection playstyle strategies (spell-based tanking)
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "PALADIN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Protection]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Protection]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- Framework references
local CONST = A.Const
local MultiUnits = A.MultiUnits

-- WoW APIs
local UnitCreatureType = _G.UnitCreatureType
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UnitIsPlayer = _G.UnitIsPlayer
local UnitClassification = _G.UnitClassification
local UnitIsDead = _G.UnitIsDead
local UnitIsVisible = _G.UnitIsVisible
local UnitGUID = _G.UnitGUID
local GetTime = _G.GetTime

-- Pre-allocated Click table for Righteous Defense (must target the friendly being attacked)
local rd_click = { unit = "targettarget" }

-- ============================================================================
-- THREAT HELPERS (for threat-aware tab targeting, ported from Warrior Prot)
-- ============================================================================

-- Threat level: 0=not on table, 1=have threat but not tanking,
-- 2=insecurely tanking, 3=securely tanking (highest threat)
-- Fallback: if API says 0/1 but mob's target is us, treat as 2
local function get_target_threat(unitID)
    unitID = unitID or TARGET_UNIT
    local threat = _G.UnitThreatSituation("player", unitID) or 0
    if threat < 2 then
        local tt = unitID .. "target"
        if UnitExists(tt) and UnitIsUnit(tt, PLAYER_UNIT) then
            return 2
        end
    end
    return threat
end

-- Check if a mob is being tanked by another tank (not us)
local function is_other_tank_target(unitID)
    unitID = unitID or TARGET_UNIT
    local mobTarget = unitID .. "target"
    if not UnitExists(mobTarget) then return false end
    if UnitIsUnit(mobTarget, PLAYER_UNIT) then return false end
    if not UnitIsPlayer(mobTarget) then return false end
    return Unit(mobTarget):IsTank() == true
end

-- Unit priority for tab-targeting: boss > elite > trash
local PRIO_BOSS = 3
local PRIO_ELITE = 2
local PRIO_TRASH = 1

local function get_unit_priority(unitID)
    local class = UnitClassification(unitID)
    if class == "worldboss" then return PRIO_BOSS end
    if class == "elite" or class == "rareelite" then return PRIO_ELITE end
    return PRIO_TRASH
end

local function get_min_priority_from_setting(setting)
    if setting == "bosses" then return PRIO_BOSS end
    if setting == "elites" then return PRIO_ELITE end
    return PRIO_TRASH  -- "all" or nil
end

local TAB_MAX_ATTEMPTS = 10
local MANUAL_TARGET_GRACE = 3

-- ============================================================================
-- PROTECTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local prot_state = {
    righteous_fury_active = false,
    holy_shield_active = false,
    holy_shield_duration = 0,
    target_below_20 = false,
    target_undead_or_demon = false,
    can_exorcism = false,
    -- Threat tab targeting state (persists across frames)
    tab_target_desired = nil,
    tab_target_attempts = 0,
    last_target_guid = nil,
    manual_target_time = 0,
}

local function get_prot_state(context)
    if context._prot_valid then return prot_state end
    context._prot_valid = true

    -- Manual target detection: if target GUID changed and we didn't cause it, it's manual
    local current_guid = UnitGUID(TARGET_UNIT)
    if current_guid ~= prot_state.last_target_guid then
        if prot_state.last_target_guid ~= nil and not prot_state.tab_target_desired then
            prot_state.manual_target_time = GetTime()
        end
        prot_state.last_target_guid = current_guid
    end

    prot_state.righteous_fury_active = context.righteous_fury_active
    prot_state.holy_shield_active = (Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.HOLY_SHIELD) or 0) > 0
    prot_state.holy_shield_duration = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.HOLY_SHIELD) or 0
    prot_state.target_below_20 = context.target_hp < 20

    -- Creature type check for Exorcism
    local ctype = UnitCreatureType(TARGET_UNIT)
    prot_state.target_undead_or_demon = (ctype == "Undead" or ctype == "Demon")

    -- Mana threshold
    prot_state.can_exorcism = context.mana_pct > Constants.MANA.EXORCISM_PCT

    return prot_state
end

-- ============================================================================
-- TAUNT HELPER FUNCTIONS (matching Druid Growl/Warrior Taunt pattern)
-- ============================================================================

-- Reliable aggro check: target is targeting us
local function has_target_aggro()
    return UnitExists("targettarget") and UnitIsUnit("targettarget", PLAYER_UNIT)
end

-- Check if target is CC'd above a threshold
local function is_target_cc_locked(threshold)
    local cc_remaining = Unit(TARGET_UNIT):InCC() or 0
    return cc_remaining > threshold
end

-- Check if targettarget (the friendly being attacked) is a healer
local function is_targettarget_healer()
    if not UnitExists("targettarget") then return false end
    return Unit("targettarget"):IsHealer() == true
end

-- ============================================================================
-- SEAL RESOLUTION HELPER
-- ============================================================================
-- Returns the appropriate seal Action based on prot_seal_choice setting
local function get_prot_seal(context)
    local choice = context.settings.prot_seal_choice or "righteousness"
    if choice == "vengeance" and A.SealOfVengeance then
        return A.SealOfVengeance, "Seal of Vengeance"
    elseif choice == "wisdom" then
        return A.SealOfWisdom, "Seal of Wisdom"
    end
    return A.SealOfRighteousness, "Seal of Righteousness"
end

-- Returns true if the currently configured seal is active
local function has_configured_seal(context)
    local choice = context.settings.prot_seal_choice or "righteousness"
    
    -- During mana recovery mode, Seal of Wisdom is acceptable even if not configured
    local threshold = context.settings.seal_of_wisdom_mana_pct or 20
    if context.mana_pct <= threshold and context.seal_wisdom_active then
        return true
    end
    
    if choice == "vengeance" then return context.seal_vengeance_active end
    if choice == "wisdom" then return context.seal_wisdom_active end
    return context.seal_righteousness_active
end

-- ============================================================================
-- THREAT-AWARE TAB TARGETING (ported from Warrior Prot / Druid Bear)
-- ============================================================================
-- Scans nameplates, categorizes mobs by threat tier (0=loose, 1=not tanking,
-- 2=insecure, 3=secure), and intelligently cycles targets to:
--   1. Pick up loose mobs (threat 0-1)
--   2. Stabilize insecure situations (threat 2)
--   3. Equalize threat on secure mobs (threat 3)
-- Respects manual target selections and other tank assignments.
local function should_prot_tab(ctx, state)
    -- Mid-cycle: actively cycling toward a desired target
    local desired = prot_state.tab_target_desired
    if desired then
        if UnitExists(TARGET_UNIT) and UnitIsUnit(TARGET_UNIT, desired) then
            prot_state.tab_target_desired = nil
            prot_state.tab_target_attempts = 0
            return false
        end
        if not UnitExists(desired) or UnitIsDead(desired)
            or A.Judgement:IsInRange(desired) ~= true then
            prot_state.tab_target_desired = nil
            prot_state.tab_target_attempts = 0
            return false
        end
        prot_state.tab_target_attempts = prot_state.tab_target_attempts + 1
        if prot_state.tab_target_attempts > TAB_MAX_ATTEMPTS then
            prot_state.tab_target_desired = nil
            prot_state.tab_target_attempts = 0
            return false
        end
        return true
    end

    -- Respect manual target selection
    if (GetTime() - prot_state.manual_target_time) < MANUAL_TARGET_GRACE then return false end

    -- Normal evaluation
    if UnitIsPlayer(TARGET_UNIT) then return false end

    -- Switch if current target dead or doesn't exist
    if not UnitExists(TARGET_UNIT) or UnitIsDead(TARGET_UNIT) then return true end

    -- Not in combat yet, skip
    if Unit(TARGET_UNIT):CombatTime() == 0 then return false end

    -- Current target out of range or not visible
    local current_out_of_range = not ctx.in_melee_range or not UnitIsVisible(TARGET_UNIT)
    -- Current target is another tank's mob
    local current_other_tank = not current_out_of_range and is_other_tank_target()

    -- Single enemy, no reason to tab
    if ctx.enemy_count < 2 and not current_other_tank and not current_out_of_range then return false end

    -- Threat-level assessment of current target
    local currentThreat = (current_out_of_range or current_other_tank) and 3 or get_target_threat()
    if currentThreat == 0 then return false end

    -- Scan nameplates: categorize mobs by threat level + unit priority
    local maxMobsToManage = ctx.settings.prot_tab_max_mobs or 4
    local minPriority = get_min_priority_from_setting(ctx.settings.prot_tab_min_priority)
    local secureMobs = 0

    local bestT0Unit, bestT0Prio = nil, 0
    local bestT1Unit, bestT1Prio = nil, 0
    local bestT2Unit, bestT2Prio = nil, 0
    local t0Count, t1Count, t2Count = 0, 0, 0

    -- Threat equalization: track lowest-threat secure mob
    local lowestSecureUnit = nil
    local lowestSecureThreatVal = math.huge

    -- Best in-range unit (for out-of-range swap fallback)
    local bestInRangeUnit, bestInRangePriority = nil, 0

    local plates = MultiUnits:GetActiveUnitPlates()
    if plates then
        for unitID in pairs(plates) do
            if unitID
                and UnitExists(unitID)
                and not UnitIsDead(unitID)
                and not UnitIsPlayer(unitID)
                and not UnitIsUnit(unitID, TARGET_UNIT)
                and Unit(unitID):CombatTime() > 0
                and A.Judgement:IsInRange(unitID) == true
                and (Unit(unitID):InCC() or 0) == 0
                and not is_other_tank_target(unitID)
            then
                local unitTTD = Unit(unitID):TimeToDie()
                local unitIsDying = unitTTD > 0 and unitTTD < 5

                if not unitIsDying then
                    local unitThreat = get_target_threat(unitID)
                    local unitPriority = get_unit_priority(unitID)

                    if unitPriority > bestInRangePriority then
                        bestInRangePriority = unitPriority
                        bestInRangeUnit = unitID
                    end

                    if unitThreat == 3 then
                        secureMobs = secureMobs + 1
                        local _, _, _, tvRaw = _G.UnitDetailedThreatSituation(PLAYER_UNIT, unitID)
                        local tv = tvRaw or 0
                        if tv < lowestSecureThreatVal then
                            lowestSecureThreatVal = tv
                            lowestSecureUnit = unitID
                        end
                    elseif unitThreat == 2 then
                        t2Count = t2Count + 1
                        if unitPriority >= minPriority and unitPriority > bestT2Prio then
                            bestT2Prio = unitPriority
                            bestT2Unit = unitID
                        end
                    elseif unitThreat == 1 then
                        t1Count = t1Count + 1
                        if unitPriority >= minPriority and unitPriority > bestT1Prio then
                            bestT1Prio = unitPriority
                            bestT1Unit = unitID
                        end
                    else
                        t0Count = t0Count + 1
                        if unitPriority >= minPriority and unitPriority > bestT0Prio then
                            bestT0Prio = unitPriority
                            bestT0Unit = unitID
                        end
                    end
                end
            end
        end
    end

    -- Select best tab-target: lower threat tier = more urgent
    local looseMobs = t0Count + t1Count
    local bestUnit = nil

    if currentThreat == 1 then
        if t0Count > 0 and bestT0Unit then bestUnit = bestT0Unit end
    elseif currentThreat == 2 then
        if bestT0Unit then bestUnit = bestT0Unit
        elseif bestT1Unit then bestUnit = bestT1Unit end
    elseif currentThreat >= 3 then
        if bestT0Unit then bestUnit = bestT0Unit
        elseif bestT1Unit then bestUnit = bestT1Unit
        elseif bestT2Unit then bestUnit = bestT2Unit end
    end

    -- Don't exceed max mobs to manage
    if bestUnit and looseMobs > 0 and secureMobs >= maxMobsToManage then
        local bestThreat = get_target_threat(bestUnit)
        if bestThreat >= 2 then bestUnit = nil end
    end

    if bestUnit then
        prot_state.tab_target_desired = bestUnit
        prot_state.tab_target_attempts = 0
        return true
    end

    -- Threat equalization: when all mobs securely tanked, rotate to lowest-threat mob
    if currentThreat >= 3 and not current_out_of_range
        and t0Count == 0 and t1Count == 0 and t2Count == 0
        and lowestSecureUnit
    then
        local _, _, _, currentThreatVal = _G.UnitDetailedThreatSituation(PLAYER_UNIT, TARGET_UNIT)
        currentThreatVal = currentThreatVal or 0
        if currentThreatVal > 0 and lowestSecureThreatVal < (currentThreatVal * 0.9) then
            prot_state.tab_target_desired = lowestSecureUnit
            prot_state.tab_target_attempts = 0
            return true
        end
    end

    -- Current target out of range → switch to best in-range target
    if current_out_of_range and bestInRangeUnit then
        prot_state.tab_target_desired = bestInRangeUnit
        prot_state.tab_target_attempts = 0
        return true
    end

    return false
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [0] Threat-aware tab targeting (first: pick up loose mobs before spending GCDs)
local Prot_ThreatTab = {
    is_gcd_gated = false,
    requires_combat = true,
    setting_key = "use_auto_tab",

    matches = function(context, state)
        return should_prot_tab(context, state)
    end,

    execute = function(icon, context, state)
        return A:Show(icon, CONST.AUTOTARGET), "[PROT] Threat Tab"
    end,
}

-- [1] Righteous Fury check (MUST always be active for tanking)
local Prot_RighteousFuryCheck = {
    spell = A.RighteousFury,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if state.righteous_fury_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.RighteousFury, icon, PLAYER_UNIT, "[PROT] Righteous Fury (activate)")
    end,
}

-- [2] Avenging Wrath (off-GCD, optional threat burst)
local Prot_AvengingWrath = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    spell = A.AvengingWrath,
    spell_target = PLAYER_UNIT,
    setting_key = "use_avenging_wrath",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if context.forbearance_active then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.AvengingWrath, icon, PLAYER_UNIT, "[PROT] Avenging Wrath")
    end,
}

-- [3] Racial (off-GCD — Stoneform defensive, Gift of the Naaru heal)
local Prot_Racial = {
    requires_combat = true,
    is_gcd_gated = false,
    is_burst = true,
    setting_key = "use_racial",

    matches = function(context, state)
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        if A.Stoneform:IsReady(PLAYER_UNIT) then return true end
        if context.hp < 60 and A.GiftOfTheNaaru and A.GiftOfTheNaaru:IsReady(PLAYER_UNIT) then return true end
        return false
    end,

    execute = function(icon, context, state)
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[PROT] Stoneform"
        end
        if context.hp < 60 and A.GiftOfTheNaaru and A.GiftOfTheNaaru:IsReady(PLAYER_UNIT) then
            return A.GiftOfTheNaaru:Show(icon), "[PROT] Gift of the Naaru"
        end
        return nil
    end,
}

-- [6] Establish configured seal (ensure primary seal is always active)
local Prot_EstablishSeal = {
    requires_combat = true,

    matches = function(context, state)
        if has_configured_seal(context) then return false end
        return true
    end,

    execute = function(icon, context, state)
        local seal, name = get_prot_seal(context)
        if seal:IsReady(PLAYER_UNIT) then
            return seal:Show(icon), format("[PROT] %s", name)
        end
        return nil
    end,
}

-- [6] Holy Shield — HIGH priority (if prioritize enabled)
-- 100% uptime is critical for crushing blow prevention
local Prot_HolyShield = {
    requires_combat = true,
    spell = A.HolyShield,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.settings.prot_use_holy_shield then return false end
        if not context.settings.prot_prioritize_holy_shield then return false end
        -- Refresh when buff is about to expire (< 2s remaining) or not active
        if state.holy_shield_active and state.holy_shield_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyShield, icon, PLAYER_UNIT,
            format("[PROT] Holy Shield (%.1fs remaining)", state.holy_shield_duration))
    end,
}

-- [7] Consecration (primary AoE threat, 8s CD)
local Prot_Consecration = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Consecration,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.settings.prot_use_consecration then return false end
        if context.mana_pct < Constants.MANA.PROT_CONSEC_PCT then return false end
        -- During low mana mode, only use Consecration on 2+ targets
        local threshold = context.settings.seal_of_wisdom_mana_pct or 20
        if context.mana_pct <= threshold and context.enemy_count < 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Consecration, icon, PLAYER_UNIT, "[PROT] Consecration")
    end,
}

-- [8] Judgement (off-GCD, threat + seal refresh cycle)
local Prot_Judgement = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Judgement,

    matches = function(context, state)
        if not context.settings.prot_use_judgement then return false end
        if not context.has_any_seal then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Judgement, icon, TARGET_UNIT, "[PROT] Judgement")
    end,
}

-- [9] Exorcism (Undead/Demon, mana > 40%)
local Prot_Exorcism = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Exorcism,

    matches = function(context, state)
        if not context.settings.prot_use_exorcism then return false end
        if context.is_moving then return false end
        if not state.target_undead_or_demon then return false end
        if not state.can_exorcism then return false end
        -- Skip during low mana mode (non-essential for threat)
        local threshold = context.settings.seal_of_wisdom_mana_pct or 20
        if context.mana_pct <= threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Exorcism, icon, TARGET_UNIT, "[PROT] Exorcism")
    end,
}

-- [10] Holy Wrath (Undead/Demon AoE)
local Prot_HolyWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HolyWrath,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.target_undead_or_demon then return false end
        if context.enemy_count < 3 then return false end
        if context.mana_pct < 40 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyWrath, icon, PLAYER_UNIT, "[PROT] Holy Wrath")
    end,
}

-- [11] Holy Shield — LOW priority (fallback if not prioritized above)
local Prot_HolyShieldFallback = {
    requires_combat = true,
    spell = A.HolyShield,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.settings.prot_use_holy_shield then return false end
        -- Only fire if NOT prioritized (handled by [6] if prioritized)
        if context.settings.prot_prioritize_holy_shield then return false end
        if state.holy_shield_active and state.holy_shield_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HolyShield, icon, PLAYER_UNIT,
            format("[PROT] Holy Shield fallback (%.1fs remaining)", state.holy_shield_duration))
    end,
}

-- [11] Hammer of Wrath (execute phase, target < 20%)
local Prot_HammerOfWrath = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.HammerOfWrath,

    matches = function(context, state)
        if not context.settings.prot_use_hammer_of_wrath then return false end
        if not state.target_below_20 then return false end
        -- Skip during low mana mode (non-essential for threat)
        local threshold = context.settings.seal_of_wisdom_mana_pct or 20
        if context.mana_pct <= threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.HammerOfWrath, icon, TARGET_UNIT, "[PROT] Hammer of Wrath")
    end,
}

-- [12] Avenger's Shield (pull/snap threat, early combat only)
local Prot_AvengersShield = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.AvengersShield,

    matches = function(context, state)
        if not context.settings.prot_use_avengers_shield then return false end
        -- Only use as a pull ability (first 3 seconds of combat)
        if context.combat_time > 3 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.AvengersShield, icon, TARGET_UNIT, "[PROT] Avenger's Shield")
    end,
}

-- [13] Righteous Defense (smart taunt — classification filtering, CC/TTD checks)
-- RD targets a FRIENDLY unit and taunts up to 3 enemies attacking that friendly.
-- Flow: our target (enemy) lost aggro on us → cast RD on targettarget (the friendly it's attacking).
local Prot_RighteousDefense = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_righteous_defense",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        -- Only taunt NPCs, not players
        if UnitIsPlayer(TARGET_UNIT) then return false end
        -- Skip if target is CC'd (taunting wastes 15s CD)
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        -- Skip if we already have aggro
        if has_target_aggro() then return false end
        -- Only taunt elites and bosses — don't waste 15s CD on trash
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        -- Need a valid friendly to cast RD on (targettarget = the party member our target is attacking)
        if not UnitExists("targettarget") then return false end
        -- TTD check: skip dying mobs to save taunt CD
        -- Exception: ALWAYS taunt if mob is attacking a healer
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and context.ttd < Constants.TAUNT.MIN_TTD then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Cast RD on the friendly being attacked (targettarget)
        if A.RighteousDefense:IsReady("targettarget") then
            A.RighteousDefense.Click = rd_click
            local targeting_healer = is_targettarget_healer()
            local reason = targeting_healer and "HEALER TARGETED" or "taunting"
            return A.RighteousDefense:Show(icon),
                format("[PROT] Righteous Defense - Lost aggro - %s (TTD: %.0fs)", reason, context.ttd)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("protection", {
    -- Threat-aware tab targeting (first: pick up loose mobs before spending GCDs)
    named("ThreatTab",           Prot_ThreatTab),
    named("RighteousFuryCheck",  Prot_RighteousFuryCheck),
    named("AvengersShield",      Prot_AvengersShield),       -- pull window (3s) — must fire early
    named("AvengingWrath",       Prot_AvengingWrath),        -- off-GCD
    named("Racial",              Prot_Racial),               -- off-GCD
    named("EstablishSeal",       Prot_EstablishSeal),
    named("HolyShield",          Prot_HolyShield),
    named("Consecration",        Prot_Consecration),
    named("Judgement",           Prot_Judgement),             -- off-GCD
    named("RighteousDefense",    Prot_RighteousDefense),
    named("Exorcism",            Prot_Exorcism),
    named("HolyWrath",           Prot_HolyWrath),
    named("HolyShieldFallback",  Prot_HolyShieldFallback),
    named("HammerOfWrath",       Prot_HammerOfWrath),
}, {
    context_builder = get_prot_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Paladin]|r Protection module loaded")
