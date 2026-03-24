--- Protection Warrior Module
--- Protection playstyle strategies: Shield Slam + Revenge + Devastate threat rotation
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

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
local is_spell_available = NS.is_spell_available
local is_stance_swap_safe = NS.is_stance_swap_safe
local debug_print = NS.debug_print
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- WoW APIs for taunt logic + threat tab targeting
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UnitIsPlayer = _G.UnitIsPlayer
local UnitClassification = _G.UnitClassification
local UnitIsDead = _G.UnitIsDead
local UnitIsVisible = _G.UnitIsVisible
local UnitGUID = _G.UnitGUID
local GetTime = _G.GetTime
local MultiUnits = A.MultiUnits
local CONST = A.Const

-- ============================================================================
-- TAUNT HELPER FUNCTIONS (matching Druid Growl/Challenging Roar pattern)
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

-- Check if target's target is a healer (for Taunt exception)
local function is_targettarget_healer()
    if not UnitExists("targettarget") then return false end
    return Unit("targettarget"):IsHealer() == true
end

-- Count nearby enemies by classification
-- @param max_range: yard radius to check
-- @param loose_only: if true, only count mobs NOT targeting us
-- @return elites, bosses, trash
local function count_nearby_enemies(max_range, loose_only)
    local plates = MultiUnits:GetActiveUnitPlates()
    local elites, bosses, trash = 0, 0, 0
    if not plates then return 0, 0, 0 end
    for unitID in pairs(plates) do
        local skip = false
        if loose_only then
            local tt = unitID .. "target"
            if not UnitExists(tt) or UnitIsUnit(tt, PLAYER_UNIT) then
                skip = true
            end
        end
        if not skip then
            local range = Unit(unitID):GetRange()
            if range and range <= max_range then
                local class = UnitClassification(unitID)
                if class == "worldboss" then
                    bosses = bosses + 1
                elseif class == "elite" or class == "rareelite" then
                    elites = elites + 1
                else
                    trash = trash + 1
                end
            end
        end
    end
    return elites, bosses, trash
end

-- ============================================================================
-- THREAT HELPERS (for threat-aware tab targeting, ported from Druid Bear)
-- ============================================================================

-- Threat level helper: returns 0-3 threat status for a unit
-- 0 = not on threat table, 1 = have threat but not tanking,
-- 2 = insecurely tanking, 3 = securely tanking (highest threat)
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

-- Threat lead check: gate utility abilities behind a configurable threat % lead
-- threshold=0 disables the check; otherwise requires tanking (status>=3) + lead% >= threshold
local function has_threat_lead(context, threshold)
    if threshold <= 0 then return true end  -- 0 = disabled
    return context.threat_status >= 3 and context.threat_percent >= threshold
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

local TAB_MAX_ATTEMPTS_PROT = 10
local MANUAL_TARGET_GRACE = 3

-- ============================================================================
-- PROTECTION STATE (context_builder)
-- ============================================================================
-- Pre-allocated state table — no inline {} in combat
local prot_state = {
    revenge_available = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_debuff = 0,
    demo_shout_debuff = 0,
    target_below_20 = false,
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

    prot_state.revenge_available = A.Revenge:IsReady(TARGET_UNIT)
    prot_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    prot_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    prot_state.thunder_clap_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    prot_state.demo_shout_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    prot_state.target_below_20 = context.target_hp < 20

    return prot_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- ============================================================================
-- THREAT-AWARE TAB TARGETING (ported from Druid Bear tank)
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
            or A.Rend:IsInRange(desired) ~= true then
            prot_state.tab_target_desired = nil
            prot_state.tab_target_attempts = 0
            return false
        end
        prot_state.tab_target_attempts = prot_state.tab_target_attempts + 1
        if prot_state.tab_target_attempts > TAB_MAX_ATTEMPTS_PROT then
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

    -- Current target out of melee range or not visible
    local current_out_of_range = not ctx.in_melee_range or not UnitIsVisible(TARGET_UNIT)
    -- Current target is another tank's mob
    local current_other_tank = not current_out_of_range and is_other_tank_target()

    -- Single enemy, no reason to tab
    if ctx.enemy_count < 2 and not current_other_tank and not current_out_of_range then return false end

    -- Threat-level assessment of current target:
    --   other_tank / out_of_range = treat as secure (3) to force scan
    --   0 = stay (urgently need threat here)
    --   1 = stay unless threat-0 mob exists
    --   2 = insecure — scan for threat 0-1 mobs
    --   3 = secure — scan for threat 0-2 mobs (safe to leave)
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
                and A.Rend:IsInRange(unitID) == true
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
                    else -- unitThreat == 0
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

    -- Select best tab-target based on current threat level:
    -- Lower threat tier = more urgent. Only switch to mobs MORE urgent than current.
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
        -- 10% threshold to prevent ping-ponging between similar-threat mobs
        if currentThreatVal > 0 and lowestSecureThreatVal < (currentThreatVal * 0.9) then
            prot_state.tab_target_desired = lowestSecureUnit
            prot_state.tab_target_attempts = 0
            return true
        end
    end

    -- Current target out of melee → switch to best in-range target
    if current_out_of_range and bestInRangeUnit then
        prot_state.tab_target_desired = bestInRangeUnit
        prot_state.tab_target_attempts = 0
        return true
    end

    return false
end

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

-- [1] Shield Block (crush prevention, off-GCD, Defensive Stance)
local Prot_ShieldBlock = {
    requires_combat = true,
    is_gcd_gated = false,
    setting_key = "prot_use_shield_block",

    matches = function(context, state)
        if context.shield_block_active then return false end
        -- Threat lead gate: don't waste off-GCD on Shield Block when threat is thin
        if not has_threat_lead(context, context.settings.prot_threat_lead or 0) then return false end
        -- Shield Block requires Defensive Stance — IsReady handles check
        return A.ShieldBlock:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ShieldBlock, icon, PLAYER_UNIT, "[PROT] Shield Block")
    end,
}

-- [2] Shield Slam (highest single-target threat, 6s CD)
local Prot_ShieldSlam = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ShieldSlam,

    execute = function(icon, context, state)
        return try_cast(A.ShieldSlam, icon, TARGET_UNIT, "[PROT] Shield Slam")
    end,
}

-- [3] Revenge (proc-based, highest threat/rage, Defensive Stance)
local Prot_Revenge = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_revenge",

    matches = function(context, state)
        -- Revenge requires Defensive Stance + block/dodge/parry proc
        return state.revenge_available
    end,

    execute = function(icon, context, state)
        return try_cast(A.Revenge, icon, TARGET_UNIT, "[PROT] Revenge")
    end,
}

-- [4] Devastate (filler, applies Sunder Armor, Prot 41-point talent)
local Prot_Devastate = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_devastate",

    matches = function(context, state)
        if not is_spell_available(A.Devastate) then return false end
        -- Devastate requires Defensive Stance
        return A.Devastate:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Devastate, icon, TARGET_UNIT,
            format("[PROT] Devastate - Sunder: %d stacks", state.sunder_stacks))
    end,
}

-- [5] Sunder Armor (if Devastate not available, build/maintain stacks)
local Prot_SunderArmor = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        -- Only use if Devastate is not available (not talented or not learned)
        if is_spell_available(A.Devastate) then return false end
        -- Maintain up to 5 stacks, refresh at low duration
        if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS
            and state.sunder_duration > Constants.SUNDER_REFRESH_WINDOW then
            return false
        end
        -- Sunder Armor requires Defensive Stance
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[PROT] Sunder Armor - Stacks: %d, Duration: %.1fs", state.sunder_stacks, state.sunder_duration))
    end,
}

-- [6] Thunder Clap maintenance (requires Battle Stance — stance dance from Defensive)
local RAGE_COST_TC = 20  -- Thunder Clap rage cost in TBC
local Prot_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_thunder_clap",

    matches = function(context, state)
        -- PvP CC break prevention: TC is PBAoE
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        -- Min enemies threshold (always use on bosses)
        local tc_min = context.settings.prot_tc_min_mobs or 3
        if not context.is_boss and context.enemy_count < tc_min then return false end
        -- Threat lead gate: bypass on AoE pulls (TC *is* the threat tool for multi-mob)
        local is_aoe_pull = context.enemy_count >= tc_min or context.is_boss
        if not is_aoe_pull and not has_threat_lead(context, context.settings.prot_threat_lead or 0) then return false end
        -- Only refresh when debuff is missing or about to expire
        if state.thunder_clap_debuff > Constants.TC_REFRESH_WINDOW then return false end
        -- TC requires Battle Stance — check if we have enough rage to cast TC
        -- Note: don't use is_stance_swap_safe here — it checks post-swap rage which
        -- is too conservative for tanks (rage from incoming hits covers the gap)
        if context.stance ~= Constants.STANCE.BATTLE then
            if context.rage < RAGE_COST_TC then return false end
        end
        -- TC is PBAoE — use PLAYER_UNIT for range check (self-cast), skipUsable for stance dance
        return A.ThunderClap:IsReady(PLAYER_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        -- Swap to Battle Stance if needed (StanceCorrection middleware returns us to Defensive)
        if context.stance ~= Constants.STANCE.BATTLE then
            if A.BattleStance:IsReady(PLAYER_UNIT) then
                return A.BattleStance:Show(icon), "[PROT] → Battle (for Thunder Clap)"
            end
            return nil
        end
        return try_cast(A.ThunderClap, icon, PLAYER_UNIT,
            format("[PROT] Thunder Clap - Debuff: %.1fs", state.thunder_clap_debuff))
    end,
}

-- [7] Demoralizing Shout maintenance
local Prot_DemoShout = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "prot_use_demo_shout",

    matches = function(context, state)
        -- PvP CC break prevention: Demo Shout is PBAoE
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if not context.in_melee_range then return false end
        -- Threat lead gate: Demo Shout is utility, don't use when threat is thin
        if not has_threat_lead(context, context.settings.prot_threat_lead or 0) then return false end
        -- Min enemies threshold (always use on bosses)
        local demo_min = context.settings.prot_demo_min_mobs or 6
        if not context.is_boss and context.enemy_count < demo_min then return false end
        -- Only refresh when debuff is missing or about to expire
        if state.demo_shout_debuff > 3 then return false end
        return A.DemoralizingShout:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, PLAYER_UNIT,
            format("[PROT] Demoralizing Shout - Debuff: %.1fs", state.demo_shout_debuff))
    end,
}

-- [8] Taunt (single-target taunt — smart: classification filtering, CC/TTD checks)
local Prot_Taunt = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    spell = A.Taunt,
    setting_key = "prot_use_taunt",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        -- Only taunt NPCs, not players
        if UnitIsPlayer(TARGET_UNIT) then return false end
        -- Skip if target is CC'd (taunting wastes 10s CD)
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        -- Skip if we already have aggro
        if has_target_aggro() then return false end
        -- Only taunt elites and bosses — don't waste 10s CD on trash
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        -- TTD check: skip dying elites to save taunt CD
        -- Exception: ALWAYS taunt if elite is hitting a healer
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and (context.ttd or 999) < Constants.TAUNT.MIN_TTD then return false end
        return true
    end,

    execute = function(icon, context, state)
        local targeting_healer = is_targettarget_healer()
        local reason = targeting_healer and "HEALER TARGETED" or "taunting"
        return try_cast(A.Taunt, icon, TARGET_UNIT,
            format("[PROT] Taunt - Lost aggro - %s (TTD: %.0fs)", reason, context.ttd or 0))
    end,
}

-- [9] Challenging Shout (AoE taunt — fires when enough loose enemies by classification)
local Prot_ChallengingShout = {
    requires_combat = true,
    is_gcd_gated = false,
    spell = A.ChallengingShout,
    spell_target = PLAYER_UNIT,
    setting_key = "prot_use_challenging_shout",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        local scan_range = Constants.TAUNT.CSHOUT_RANGE
        local elites, bosses, trash = count_nearby_enemies(scan_range, true)
        if elites == 0 and bosses == 0 and trash == 0 then return false end
        local min_bosses = context.settings.prot_cshout_min_bosses or Constants.TAUNT.CSHOUT_MIN_BOSSES
        local min_elites = context.settings.prot_cshout_min_elites or Constants.TAUNT.CSHOUT_MIN_ELITES
        local min_trash  = context.settings.prot_cshout_min_trash or Constants.TAUNT.CSHOUT_MIN_TRASH
        return bosses >= min_bosses or elites >= min_elites or trash >= min_trash
    end,

    execute = function(icon, context, state)
        local scan_range = Constants.TAUNT.CSHOUT_RANGE
        local elites, bosses, trash = count_nearby_enemies(scan_range, true)
        return try_cast(A.ChallengingShout, icon, PLAYER_UNIT,
            format("[PROT] Challenging Shout - EMERGENCY - %d boss, %d elite, %d trash loose", bosses, elites, trash))
    end,
}

-- [10] Mocking Blow (2-min CD taunt fallback — stance-dances to Battle Stance)
-- Fires when we lose aggro on an elite/boss AND Taunt is on CD.
-- Stance-dances to Battle Stance to cast, then StanceCorrection returns us to Defensive.
local Prot_MockingBlow = {
    requires_combat = true,
    requires_enemy = true,
    -- No spell = A.MockingBlow here: IsReady fails in Defensive Stance.
    -- We use skipUsable=true in matches and handle stance dance in execute.
    setting_key = "prot_use_taunt",

    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        if UnitIsPlayer(TARGET_UNIT) then return false end
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        if has_target_aggro() then return false end
        -- Only fire when Taunt is on CD (Mocking Blow is the backup)
        local taunt_cd = A.Taunt:GetCooldown() or 0
        if taunt_cd <= 0 then return false end
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and (context.ttd or 999) < Constants.TAUNT.MIN_TTD then return false end
        -- skipUsable=true: bypass stance restriction so we can detect readiness before swapping
        return A.MockingBlow:IsReady(TARGET_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        -- Stance dance to Battle if needed (StanceCorrection returns us to Defensive)
        if context.stance ~= Constants.STANCE.BATTLE then
            if A.BattleStance:IsReady(PLAYER_UNIT) then
                return A.BattleStance:Show(icon), "[PROT] → Battle (for Mocking Blow)"
            end
            return nil
        end
        local targeting_healer = is_targettarget_healer()
        local reason = targeting_healer and "HEALER TARGETED" or "taunting"
        return try_cast(A.MockingBlow, icon, TARGET_UNIT,
            format("[PROT] Mocking Blow - Lost aggro - %s (Taunt on CD)", reason))
    end,
}

-- [11] Execute (target <20% HP — rage-efficient finisher)
local Prot_Execute = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Execute,
    setting_key = "prot_use_execute",

    matches = function(context, state)
        if context.target_hp > 20 then return false end
        return true
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT, format("[PROT] Execute (%.0f%%)", context.target_hp))
    end,
}

-- [12] Victory Rush (free instant after killing blow, 0 rage)
local Prot_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,
    setting_key = "prot_use_victory_rush",

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[PROT] Victory Rush")
    end,
}

-- [13] Heroic Strike / Cleave (off-GCD rage dump)
local Prot_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        -- Already queued — yield the icon so GCD abilities can show
        if A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent() then return false end
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
        local threshold = context.settings.prot_hs_rage_threshold or 60
        if context.rage < threshold then return false end
        return true
    end,

    execute = function(icon, context, state)
        -- Auto Cleave/HS: use Cleave at threshold, HS otherwise
        local cleave_at = context.settings.aoe_threshold or 2
        -- PvP CC break prevention: Cleave can hit CC'd target
        local cc_safe = not (context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check)
        if cc_safe and cleave_at > 0 and context.enemy_count >= cleave_at and A.Cleave:IsReady(TARGET_UNIT) then
            return A.Cleave:Show(icon), format("[PROT] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return A.HeroicStrike:Show(icon), format("[PROT] Heroic Strike - Rage: %d", context.rage)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("protection", {
    -- Threat-aware tab targeting (first: pick up loose mobs before spending GCDs)
    named("ThreatTab",         Prot_ThreatTab),
    -- Off-GCD: crush prevention
    named("ShieldBlock",       Prot_ShieldBlock),
    -- Core threat: Shield Slam > Revenge
    named("ShieldSlam",        Prot_ShieldSlam),
    named("Revenge",           Prot_Revenge),
    -- Debuff maintenance: above fillers per guide/sim priority
    named("ThunderClap",       Prot_ThunderClap),
    named("DemoShout",         Prot_DemoShout),
    -- Fillers
    named("Devastate",         Prot_Devastate),
    named("SunderArmor",       Prot_SunderArmor),
    named("Execute",           Prot_Execute),
    named("VictoryRush",       Prot_VictoryRush),
    -- Off-GCD: taunts
    named("Taunt",             Prot_Taunt),
    named("ChallengingShout",  Prot_ChallengingShout),
    named("MockingBlow",       Prot_MockingBlow),
    -- Off-GCD: rage dump
    named("HeroicStrike",      Prot_HeroicStrike),
}, {
    context_builder = get_prot_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Protection module loaded")
