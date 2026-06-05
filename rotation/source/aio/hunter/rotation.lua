-- Hunter Rotation Module
-- OOC strategies + full combat rotation for the "ranged" playstyle

local _G, select = _G, select
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Hunter Rotation]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local named = NS.named
local Constants = NS.Constants
local ARCANE_IMMUNE = NS.ARCANE_IMMUNE or (Constants and Constants.ARCANE_IMMUNE) or {}
local Pet = NS.Pet
local AtRange = NS.AtRange
local InMelee = NS.InMelee
local GetRange = NS.GetRange
local CheckImmuneOrDoNotAttack = NS.CheckImmuneOrDoNotAttack
local CheckCCImmune = NS.CheckCCImmune
local ShouldUseWingClip = NS.ShouldUseWingClip
local ShouldUseViperSting = NS.ShouldUseViperSting
local debug_print = NS.debug_print

-- Framework helpers
local CONST = A.Const
local GetGCD = A.GetGCD
local GetCurrentGCD = A.GetCurrentGCD
local GetLatency = A.GetLatency
local BurstIsON = A.BurstIsON
local is_force_active = NS.is_force_active
local IsUnitEnemy = A.IsUnitEnemy
local AuraIsValid = A.AuraIsValid
local MultiUnits = A.MultiUnits

local UnitIsUnit = _G.UnitIsUnit
local UnitExists = _G.UnitExists
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitGUID = _G.UnitGUID
local GetNumGroupMembers = _G.GetNumGroupMembers
local GetTime = _G.GetTime

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local next_pet_attack_at = 0
local next_start_attack_at = 0
local next_hunter_trace_at = 0

local function BurnPhaseActive()
    return Unit(PLAYER_UNIT):HasBuffs(A.Heroism.ID) > 0
        or Unit(PLAYER_UNIT):HasBuffs(A.Bloodlust.ID) > 0
        or Unit(PLAYER_UNIT):HasBuffs(A.Drums.ID) > 0
end

local function BurstWindowOpen(unit, settings)
    local force_burst_on = is_force_active and is_force_active("force_burst")
    local autoSyncCDs = settings.auto_sync_cds

    if not (force_burst_on or BurstIsON(unit) or (not BurstIsON(unit) and autoSyncCDs)) then
        return false
    end

    return force_burst_on or (autoSyncCDs and BurnPhaseActive()) or not autoSyncCDs
end

local function PetNeedsAttack(unit)
    if not UnitExists or not UnitExists("pet") or UnitIsDeadOrGhost("pet") then return false end
    if UnitExists("pettarget") and UnitIsUnit("pettarget", unit) then return false end

    local now = GetTime()
    if now < next_pet_attack_at then return false end
    next_pet_attack_at = now + 1.0
    return true
end

local function ShouldStartMeleeAttack()
    local now = GetTime()
    if now < next_start_attack_at then return false end
    next_start_attack_at = now + 0.75
    return true
end

local function RaptorQueueReady(unit)
    if not A.RaptorStrike then return false end
    if A.RaptorStrike:IsSpellCurrent() then return false end

    local spell = A.RaptorStrikeQueue or A.RaptorStrike
    if spell.IsReady and spell:IsReady(unit) then return true end
    if spell.GetCooldown then return (spell:GetCooldown() or 999) <= 0.15 end
    return false
end

local function HunterTrace(context, unit, reason, atRange, inMeleeRange)
    local settings = context.settings
    if not (settings and (settings.debug_mode or settings.debug_system) and debug_print) then return end

    local now = GetTime()
    if now < next_hunter_trace_at then return end
    next_hunter_trace_at = now + 0.50

    local raptorReady = A.RaptorStrike and A.RaptorStrike:IsReady(unit)
    local raptorCurrent = A.RaptorStrike and A.RaptorStrike:IsSpellCurrent()
    local petOnUnit = UnitExists and UnitExists("pettarget") and UnitIsUnit("pettarget", unit)
    local playerAggro = UnitExists and UnitExists("targettarget") and UnitIsUnit("targettarget", PLAYER_UNIT)
    local petAggro = UnitExists and UnitExists("targettarget") and UnitIsUnit("targettarget", "pet")
    local targetTargetGUID = UnitGUID and UnitGUID("targettarget") or "none"

    debug_print(format(
        "[HUNTER PATH] %s unit=%s atRange=%s inMelee=%s ctxMelee=%s targetRange=%s shoot=%.3f gcd=%.3f attacking=%s shooting=%s playerAggro=%s petAggro=%s targetTargetGUID=%s petOnUnit=%s raptorReady=%s raptorCurrent=%s",
        reason,
        unit,
        tostring(atRange),
        tostring(inMeleeRange),
        tostring(context.in_melee_range),
        tostring(context.target_range),
        context.shoot_timer or -1,
        context.gcd_remaining or -1,
        tostring(Player:IsAttacking()),
        tostring(Player:IsShooting()),
        tostring(playerAggro),
        tostring(petAggro),
        tostring(targetTargetGUID),
        tostring(petOnUnit),
        tostring(raptorReady),
        tostring(raptorCurrent)
    ))
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
local strategies = {}

-- ============================================================================
-- 1. INTERRUPT (highest priority in combat)
-- ============================================================================
strategies[#strategies + 1] = named("Interrupt", {
    requires_combat = true,

    matches = function(context)
        if not context.has_valid_enemy_target then return false end
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft <= GetGCD() + GetLatency() then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()

        if not notKickAble and A.SilencingShot:IsReadyByPassCastGCD(TARGET_UNIT, nil, nil, true) and A.SilencingShot:IsInRange() then
            return A.SilencingShot:Show(icon), "[INT] Silencing Shot"
        end

        if A.ScatterShot:IsReadyByPassCastGCD(TARGET_UNIT, nil, nil, true) and A.ScatterShot:IsInRange() and not CheckCCImmune(TARGET_UNIT) then
            return A.ScatterShot:Show(icon), "[INT] Scatter Shot"
        end

        return nil
    end,
})

-- ============================================================================
-- 2. OOC: ASPECT OF VIPER (mana recovery)
-- ============================================================================
strategies[#strategies + 1] = named("OOC_AspectViper", {
    matches = function(context)
        if not context.settings.aspect_viper then return false end
        if context.is_mounted then return false end
        if Unit(PLAYER_UNIT):HasBuffs(A.AspectoftheViper.ID, true) > 0 then return false end
        local manaViperStart = context.settings.mana_viper_start or 10
        if context.mana_pct >= manaViperStart then return false end
        return A.AspectoftheViper:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context)
        return A.AspectoftheViper:Show(icon), "[OOC] Aspect of the Viper"
    end,
})

-- ============================================================================
-- 3. OOC: ASPECT OF CHEETAH (travel)
-- ============================================================================
strategies[#strategies + 1] = named("OOC_AspectCheetah", {
    requires_combat = false,

    matches = function(context)
        if not context.settings.aspect_cheetah then return false end
        if context.is_mounted then return false end
        if context.in_combat then return false end
        if IsUnitEnemy(TARGET_UNIT) then return false end
        if Unit(PLAYER_UNIT):HasBuffs(A.AspectoftheCheetah.ID, true) > 0 then return false end
        -- Don't use cheetah if we should be in viper
        if context.settings.aspect_viper then
            local manaViperEnd = context.settings.mana_viper_end or 30
            if context.mana_pct <= manaViperEnd then return false end
        end
        return A.AspectoftheCheetah:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context)
        return A.AspectoftheCheetah:Show(icon), "[OOC] Aspect of the Cheetah"
    end,
})

-- ============================================================================
-- 3b. OOC: TRUESHOT AURA (maintain buff)
-- ============================================================================
strategies[#strategies + 1] = named("OOC_TrueshotAura", {
    matches = function(context)
        if context.is_mounted then return false end
        if (Unit(PLAYER_UNIT):HasBuffs(A.TrueshotAura.ID, true) or 0) > 0 then return false end
        return A.TrueshotAura:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context)
        return A.TrueshotAura:Show(icon), "[OOC] Trueshot Aura"
    end,
})

-- ============================================================================
-- 4. OOC: CALL PET
-- ============================================================================
strategies[#strategies + 1] = named("OOC_CallPet", {
    matches = function(context)
        if Pet:IsActive() then return false end
        if UnitIsDeadOrGhost("pet") then return false end
        if not Pet:CanCall() then return false end
        return A.CallPet:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context)
        return A.CallPet:Show(icon), "[OOC] Call Pet"
    end,
})

-- ============================================================================
-- 5. OOC: REVIVE PET
-- ============================================================================
strategies[#strategies + 1] = named("OOC_RevivePet", {
    matches = function(context)
        if not (UnitIsDeadOrGhost("pet") or Unit("pet"):IsDead()) then return false end
        return A.RevivePet:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context)
        return A.RevivePet:Show(icon), "[OOC] Revive Pet"
    end,
})

-- ============================================================================
-- 6. COMBAT ROTATION (the full EnemyRotation as one strategy)
-- ============================================================================
strategies[#strategies + 1] = named("CombatRotation", {
    matches = function(context)
        -- Need either a mouseover enemy or target enemy
        if context.settings.mouseover and IsUnitEnemy("mouseover") then return true end
        if IsUnitEnemy(TARGET_UNIT) then return true end
        return false
    end,

    execute = function(icon, context)
        local s = context.settings
        local CT = NS.HunterClipTracker

        -- Internal EnemyRotation for a given unit
        local function EnemyRotation(unit)
            local npcID = select(6, Unit(unit):InfoGUID())
            local atRange = AtRange(unit)
            local inMeleeRange = InMelee(unit)
            local targetRange = context.target_range or math.huge
            local shouldMeleeRecover = (not atRange) and (inMeleeRange == true or targetRange <= 5)
            local weave = nil

            -- [R-1] Stop attacking if target is immune
            if CheckImmuneOrDoNotAttack(unit) then
                return A.PoolResource:Show(icon)
            end

            -- TTD gate for burst CDs (cd_min_ttd setting)
            local min_ttd = s.cd_min_ttd or 0
            local ttd_ok = min_ttd == 0 or not context.ttd or context.ttd <= 0 or context.ttd >= min_ttd

            -- [R-2] Tranquilizing Shot (enrage dispel) — Flux by-ID list (enrages
            -- are self-buffs on the creature) OR the framework's "Enrage" category.
            if A.TranquilizingShot:IsReady(unit)
               and ((Unit(unit):HasBuffs(Constants.TRANQ_ENRAGE, nil, true) or 0) > 0
                    or AuraIsValid(unit, nil, "Enrage")) then
                return A.TranquilizingShot:Show(icon), "[RANGED] Tranq Shot"
            end

            -- [R-3] Aspect of the Hawk (in combat)
            if s.aspect_hawk then
                local manaViperEnd = s.mana_viper_end or 30
                local viperOff = (context.mana_pct > manaViperEnd and s.aspect_viper) or not s.aspect_viper
                if A.AspectoftheHawk:IsReady(PLAYER_UNIT) and Unit(PLAYER_UNIT):HasBuffs(A.AspectoftheHawk.ID, true) == 0
                   and (context.in_combat or IsUnitEnemy(unit)) and viperOff and not context.is_mounted then
                    return A.AspectoftheHawk:Show(icon), "[RANGED] Aspect of the Hawk"
                end
            end

            -- [R-4] Readiness controller (outside burst)
            if s.use_readiness and A.Readiness:IsReady(PLAYER_UNIT) then
                if s.readiness_rapid_fire and ttd_ok then
                    local rkRank = (A.RapidKilling1.GetTalentRank and A.RapidKilling1:GetTalentRank()) or 0
                    if A.RapidFire:GetCooldown() >= 300 - (60 * rkRank) then
                        return A.Readiness:Show(icon), "[RANGED] Readiness (Rapid Fire)"
                    end
                end
                if s.readiness_misdirection then
                    if A.Misdirection:GetCooldown() >= 10 then
                        return A.Readiness:Show(icon), "[RANGED] Readiness (Misdirection)"
                    end
                end
            end

            -- [R-5] Protect frozen target (auto-switch)
            if s.protect_freeze and Unit("target"):HasDeBuffs(A.FreezingTrapDebuff.ID) > 0 and MultiUnits:GetActiveEnemies() >= 2 then
                return A:Show(icon, CONST.AUTOTARGET)
            end

            -- [R-6] Freezing Trap on adds
            if A.FreezingTrap:IsReady(PLAYER_UNIT) and s.freezing_trap_pve and MultiUnits:GetActiveEnemies() >= 2 and MultiUnits:GetByRangeInCombat(5, 1, 5) >= 1 and not CheckCCImmune(unit) then
                return A.FreezingTrap:Show(icon), "[RANGED] Freezing Trap"
            end

            -- [R-7] Mend Pet
            local mendPetHP = s.mend_pet_hp or 30
            if A.MendPet:IsReady(PLAYER_UNIT) and context.pet_hp < mendPetHP and context.pet_active and Unit("pet"):HasBuffs(A.MendPet.ID, true) == 0 then
                return A.MendPet:Show(icon), "[RANGED] Mend Pet"
            end

            -- [R-8] Hunter's Mark — refresh "mark_refresh" sec before expiry so
            -- the ramping AP bonus isn't lost on drop. 0 = re-apply only once
            -- fully gone. markRemaining is 0 when the mark is absent, so a fresh
            -- cast still passes the <= test. Static Mark only guards re-marking a
            -- *different* target (markRemaining == 0), never the current refresh.
            local markRemaining = Unit(unit):HasDeBuffs(A.HuntersMark.ID, true)
            if A.HuntersMark:IsReady(unit) and markRemaining <= (s.mark_refresh or 0)
               and (markRemaining > 0 or not s.static_mark
                    or Player:GetDeBuffsUnitCount(A.HuntersMark.ID) == 0)
               and Unit(unit):TimeToDie() > 2
               and not ARCANE_IMMUNE[npcID]
               and ((Unit(unit):IsBoss() and s.boss_mark) or not s.boss_mark) then
                return A.HuntersMark:Show(icon), "[RANGED] Hunter's Mark"
            end

            -- [R-9] Experimental pet controller. Do not let pet attack block
            -- melee recovery; if we are in melee, player startattack/Raptor owns it.
            if s.experimental_pet and context.pet_active and not shouldMeleeRecover then
                if PetNeedsAttack(unit) and context.pet_hp > mendPetHP - 20 then
                    HunterTrace(context, unit, "return_petattack", atRange, inMeleeRange)
                    return A.PetAttack:Show(icon), "[RANGED] Pet Attack"
                end
            end

            -- [R-10] Kill Command is off-GCD, but the single-key clicker can only
            -- fire one icon per press. Prefer real GCD shots when the GCD is open;
            -- show KC while locked out or as a fallback below.
            local gcdRemainingForKC = GetCurrentGCD() or 0
            if not shouldMeleeRecover and ttd_ok and gcdRemainingForKC > 0.05 and A.KillCommand:IsReady(unit) then
                return A.KillCommand:Show(icon), "[RANGED] Kill Command"
            end

            if shouldMeleeRecover then
                HunterTrace(context, unit, "melee_precheck", atRange, inMeleeRange)
            elseif context.in_melee_range and atRange then
                HunterTrace(context, unit, "ctx_melee_ignored_ranged_ok", atRange, inMeleeRange)
            end

            if s.show_melee_weave_coach and NS.HunterMeleeWeaveCoach then
                weave = NS.HunterMeleeWeaveCoach:Evaluate(unit)
            end

            -- Manual-only Raptor queue window. The main rotation must not
            -- auto-prequeue Raptor from fuzzy close range; use /flux raptor
            -- when intentionally weaving in.
            if is_force_active and is_force_active("force_raptor") and RaptorQueueReady(unit)
                and (inMeleeRange == true or (targetRange > 0 and targetRange <= 7)) then
                HunterTrace(context, unit, "return_manual_raptor_queue", atRange, inMeleeRange)
                return (A.RaptorStrikeQueue or A.RaptorStrike):Show(icon), "[WEAVE] Manual Raptor Queue"
            end

            -- ============================================
            -- RANGED ROTATION (at range)
            -- ============================================
            if atRange then
                -- [R-11] Auto Shoot
                if not Player:IsShooting() then
                    HunterTrace(context, unit, "return_autoshoot", atRange, inMeleeRange)
                    return A:Show(icon, CONST.AUTOSHOOT), "[RANGED] Auto Shoot"
                end

                -- [R-12] Intimidation (PvE aggro)
                if A.Intimidation:IsReady(unit) and s.intimidation_pve and UnitIsUnit("targettarget", PLAYER_UNIT) and Unit("target"):IsControlAble("stun") and not CheckCCImmune(unit) then
                    return A.Intimidation:Show(icon), "[RANGED] Intimidation"
                end

                -- [R-13] Concussive Shot (PvE)
                if A.ConcussiveShot:IsReady(unit) and s.concussive_shot_pve and not Unit(unit):IsBoss()
                   and Unit("target"):IsMelee() and UnitIsUnit("targettarget", PLAYER_UNIT)
                   and A.LastPlayerCastName ~= A.Intimidation:Info()
                   and (not A.Intimidation:IsReady(unit) or Unit("pet"):HasBuffs(A.Intimidation.ID) == 0 or not s.intimidation_pve)
                   and Unit(unit):HasDeBuffs(A.WingClip.ID) < GetGCD()
                   and not ARCANE_IMMUNE[npcID] and not CheckCCImmune(unit) then
                    HunterTrace(context, unit, "return_concussive_pve_player_aggro", atRange, inMeleeRange)
                    return A.ConcussiveShot:Show(icon), "[RANGED] Concussive Shot (PvE)"
                end

                -- [R-13b] PvP Concussive Shot
                if A.IsInPvP and A.ConcussiveShot:IsReady(unit) and not CheckCCImmune(unit) and Unit(unit):HasDeBuffs(A.WingClip.ID) < GetGCD() then
                    local range = GetRange(unit)
                    if range > 0 and (range < 10 or range > 25) then
                        if Unit(unit):HasDeBuffs(A.ConcussiveShot.ID, true) < 2 then
                            return A.ConcussiveShot:Show(icon), "[RANGED] Concussive Shot (PvP)"
                        end
                    end
                end

                -- [R-14] PvP Viper Sting
                if A.IsInPvP and A.ViperSting:IsReady(unit) then
                    if ShouldUseViperSting(unit) then
                        if Unit(unit):HasDeBuffs(A.ViperSting.ID, true) <= GetGCD() then
                            return A.ViperSting:Show(icon), "[RANGED] Viper Sting (PvP)"
                        end
                    end
                end

                -- [R-15] Burst Cooldowns
                local useAoE = s.aoe
                if BurstWindowOpen(unit, s) then
                    if ttd_ok and A.BestialWrath:IsReady(PLAYER_UNIT) and s.use_bestial_wrath and context.pet_active then
                        return A.BestialWrath:Show(icon), "[BURST] Bestial Wrath"
                    end

                    if ttd_ok and A.RapidFire:IsReady(PLAYER_UNIT) and s.use_rapid_fire and Unit(PLAYER_UNIT):HasBuffs(A.RapidFire.ID, true) == 0 then
                        return A.RapidFire:Show(icon), "[BURST] Rapid Fire"
                    end

                    if ttd_ok and A.Readiness:IsReady(PLAYER_UNIT) and s.use_readiness then
                        if s.readiness_rapid_fire then
                            if A.RapidFire:GetCooldown() >= 60 then
                                return A.Readiness:Show(icon), "[BURST] Readiness (Rapid Fire)"
                            end
                        end
                        if s.readiness_misdirection then
                            if A.Misdirection:GetCooldown() > 30 then
                                return A.Readiness:Show(icon), "[BURST] Readiness (Misdirection)"
                            end
                        end
                    end

                    if ttd_ok and A.BloodFury:IsReady(PLAYER_UNIT) and s.use_racial then
                        return A.BloodFury:Show(icon), "[BURST] Blood Fury"
                    end

                    if ttd_ok and A.Berserking:IsReady(PLAYER_UNIT) and s.use_racial then
                        return A.Berserking:Show(icon), "[BURST] Berserking"
                    end

                    if ttd_ok and s.use_haste_potion and A.HastePotion:IsReady(PLAYER_UNIT) then
                        return A.HastePotion:Show(icon), "[BURST] Haste Potion"
                    end

                    -- Trinkets (legacy Hunter_Goob_opt parity: fire inline on GGL Burst)
                    if ttd_ok and s.trinket1_mode == "offensive" and A.Trinket1 and A.Trinket1:IsReady(PLAYER_UNIT) then
                        return A.Trinket1:Show(icon), "[BURST] Trinket 1"
                    end
                    if ttd_ok and s.trinket2_mode == "offensive" and A.Trinket2 and A.Trinket2:IsReady(PLAYER_UNIT) then
                        return A.Trinket2:Show(icon), "[BURST] Trinket 2"
                    end
                end

                -- [R-16] Moving Arcane Shot
                local useArcane = s.use_arcane
                local arcaneShotMana = s.arcane_shot_mana or 15
                local manaSave = s.mana_save or 30

                if context.is_moving and useArcane and A.ArcaneShot:IsReady(unit) and not ARCANE_IMMUNE[npcID] and context.mana_pct > arcaneShotMana then
                    return A.ArcaneShot:Show(icon), "[RANGED] Arcane Shot (moving)"
                end

                -- [R-17] Shot Weaving
                local ShootTimer = context.shoot_timer

                -- [R-17a] Adaptive DPS Rotation (port of wowsims rotation.go:139-280).
                -- Per-tick DPS-weighted shot choice. Stings get pre-priority.
                -- On shoot/none, no special is cast and auto-shot continues.
                if NS.HunterAdaptive then
                    if s.use_serpent_sting and A.SerpentSting:IsReady(unit)
                       and Unit(unit):HasDeBuffs(A.SerpentSting.ID, true) <= GetGCD()
                       and Unit(unit):TimeToDie() >= 4 and context.mana_pct > manaSave then
                        if CT then CT:RecordSuggestion("Serpent Sting", ShootTimer) end
                        return A.SerpentSting:Show(icon), "[ADAPT] Serpent Sting"
                    end
                    if s.use_scorpid_sting and A.ScorpidSting:IsReady(unit)
                       and Unit(unit):HasDeBuffs(A.ScorpidSting.ID, true) <= GetGCD() + 0.5
                       and Unit(unit):IsBoss() and context.mana_pct > manaSave then
                        if CT then CT:RecordSuggestion("Scorpid Sting", ShootTimer) end
                        return A.ScorpidSting:Show(icon), "[ADAPT] Scorpid Sting"
                    end
                    if s.use_viper_sting_pve and A.ViperSting:IsReady(unit)
                       and Unit(unit):PowerType() == "MANA" and Unit(unit):Power() >= 10
                       and context.mana_pct > manaSave then
                        if CT then CT:RecordSuggestion("Viper Sting", ShootTimer) end
                        return A.ViperSting:Show(icon), "[ADAPT] Viper Sting"
                    end

                    local choice = NS.HunterAdaptive.ChooseAction(unit, {
                        useMulti = useAoE,
                        useArcane = useArcane,
                        arcaneImmune = ARCANE_IMMUNE[npcID],
                        manaPct = context.mana_pct,
                        manaSaveFloor = manaSave,
                        arcaneManaFloor = arcaneShotMana,
                    })
                    local sqw = tonumber(_G.GetCVar and _G.GetCVar("SpellQueueWindow")) or 0
                    local queueWindow = math.max(0.10, math.min(0.40, sqw / 1000))
                    local gcdLeftForQueue = context.gcd_remaining or GetCurrentGCD() or 0
                    local steadyQueueable = (not context.is_moving) and gcdLeftForQueue <= queueWindow
                    if choice == "steady" and (A.SteadyShot:IsReady(unit) or steadyQueueable) then
                        if CT then CT:RecordSuggestion("Steady Shot", ShootTimer) end
                        return A.SteadyShot:Show(icon), "[ADAPT] Steady Shot"
                    elseif choice == "multi" and A.MultiShot:IsReady(unit) and useAoE and context.mana_pct > manaSave then
                        if CT then CT:RecordSuggestion("Multi-Shot", ShootTimer) end
                        return A.MultiShot:Show(icon), "[ADAPT] Multi-Shot"
                    elseif choice == "arcane" and A.ArcaneShot:IsReady(unit)
                           and not ARCANE_IMMUNE[npcID]
                           and context.mana_pct > arcaneShotMana then
                        if CT then CT:RecordSuggestion("Arcane Shot", ShootTimer) end
                        return A.ArcaneShot:Show(icon), "[ADAPT] Arcane Shot"
                    end
                    -- choice == "shoot"/"none" -> no special; auto-shot continues
                end
            end -- end AtRange

            -- Off-GCD fallback after ranged GCD shots had first chance.
            if (atRange or not shouldMeleeRecover) and ttd_ok and A.KillCommand:IsReady(unit) then
                return A.KillCommand:Show(icon), "[RANGED] Kill Command"
            end

            -- ============================================
            -- MELEE ROTATION (in melee range)
            -- ============================================
            if shouldMeleeRecover then
                HunterTrace(context, unit, "melee_branch", atRange, inMeleeRange)

                -- [R-18] Explosive Trap (AoE in melee)
                if A.ExplosiveTrap:IsReady(unit) and MultiUnits:GetByRange(5, 3) > 2 and s.aoe then
                    return A.ExplosiveTrap:Show(icon), "[MELEE] Explosive Trap"
                end

                -- [R-19] Raptor Strike queue for deliberate melee weaving
                if s.show_melee_weave_coach and A.RaptorStrikeQueue and NS.HunterMeleeWeaveCoach then
                    weave = weave or NS.HunterMeleeWeaveCoach:Evaluate(unit)
                    if weave and weave.state == "GREEN" and weave.action == "RAPTOR"
                       and A.RaptorStrikeQueue:IsReady(unit) and not A.RaptorStrike:IsSpellCurrent() then
                        return A.RaptorStrikeQueue:Show(icon), "[WEAVE] Raptor Strike Queue"
                    end
                end

                -- [R-20] Wing Clip
                if ShouldUseWingClip(unit) and A.WingClip:IsReady(unit) and Unit(unit):HasDeBuffs(A.WingClip.ID, true) <= GetGCD()
                   and A.WingClip:AbsentImun(unit, Constants.Temp.TotalAndPhysAndCC) and not CheckCCImmune(unit) then
                    HunterTrace(context, unit, "return_wingclip", atRange, inMeleeRange)
                    return A.WingClip:Show(icon), "[MELEE] Wing Clip"
                end

                -- [R-21] Raptor Strike. In melee recovery, this should be allowed
                -- even if Auto Shot still reports active; Raptor itself is the
                -- important queued action once we are truly in melee range.
                if A.RaptorStrike:IsReady(unit) and not A.RaptorStrike:IsSpellCurrent() then
                    HunterTrace(context, unit, "return_raptor", atRange, inMeleeRange)
                    return A.RaptorStrike:Show(icon), "[MELEE] Raptor Strike"
                end

                -- [R-22] Auto Attack
                if A.StartAttack and not Player:IsAttacking() and not Player:IsShooting()
                    and ShouldStartMeleeAttack() then
                    HunterTrace(context, unit, "return_startattack_melee_fallback", atRange, inMeleeRange)
                    return A.StartAttack:Show(icon), "[MELEE] Start Attack"
                elseif not Player:IsAttacking() and Player:IsShooting() then
                    HunterTrace(context, unit, "skip_startattack_while_shooting", atRange, inMeleeRange)
                end
            end -- end InMelee

            if shouldMeleeRecover or atRange then
                HunterTrace(context, unit, "return_nil", atRange, inMeleeRange)
            end
            return nil
        end -- end EnemyRotation

        -- Check mouseover first, then target
        if s.mouseover and IsUnitEnemy("mouseover") then
            local result, log = EnemyRotation("mouseover")
            if result then return result, log end
        end

        if IsUnitEnemy(TARGET_UNIT) then
            local result, log = EnemyRotation(TARGET_UNIT)
            if result then return result, log end
        end

        return nil
    end,
})

-- ============================================================================
-- REGISTER ALL STRATEGIES
-- ============================================================================
rotation_registry:register("ranged", strategies)

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Hunter]|r Rotation module loaded (" .. #strategies .. " strategies)")
