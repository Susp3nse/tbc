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
local ARCANE_IMMUNE = NS.ARCANE_IMMUNE
local Pet = NS.Pet
local AtRange = NS.AtRange
local InMelee = NS.InMelee
local GetRange = NS.GetRange
local CheckImmuneOrDoNotAttack = NS.CheckImmuneOrDoNotAttack
local CheckCCImmune = NS.CheckCCImmune
local ShouldUseWingClip = NS.ShouldUseWingClip
local ShouldUseViperSting = NS.ShouldUseViperSting
local num = NS.num

-- Framework helpers
local CONST = A.Const
local GetGCD = A.GetGCD
local GetCurrentGCD = A.GetCurrentGCD
local GetLatency = A.GetLatency
local BurstIsON = A.BurstIsON
local IsUnitEnemy = A.IsUnitEnemy
local AuraIsValid = A.AuraIsValid
local MultiUnits = A.MultiUnits

local UnitIsUnit = _G.UnitIsUnit
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local GetNumGroupMembers = _G.GetNumGroupMembers

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

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

            -- [R-1] Stop attacking if target is immune
            if CheckImmuneOrDoNotAttack(unit) then
                return A.PoolResource:Show(icon)
            end

            -- TTD gate for burst CDs (cd_min_ttd setting)
            local min_ttd = s.cd_min_ttd or 0
            local ttd_ok = min_ttd == 0 or not context.ttd or context.ttd <= 0 or context.ttd >= min_ttd

            -- [R-2] Tranquilizing Shot (enrage dispel)
            if A.TranquilizingShot:IsReady(unit) and AuraIsValid(unit, nil, "Enrage") then
                return A.TranquilizingShot:Show(icon), "[RANGED] Tranq Shot"
            end

            -- [R-3] Misdirection on focus target
            if A.Misdirection:IsReady(PLAYER_UNIT) and Unit("focus"):IsExists() and not Unit("focus"):IsDead() then
                if context.combat_time < 6 then
                    return A.Misdirection:Show(icon), "[RANGED] Misdirection (pull)"
                end
                if context.combat_time > 6 and not Unit("targettarget"):IsTank() then
                    return A.Misdirection:Show(icon), "[RANGED] Misdirection (aggro)"
                end
            end

            -- [R-4] Aspect of the Hawk (in combat)
            if s.aspect_hawk then
                local manaViperEnd = s.mana_viper_end or 30
                local viperOff = (context.mana_pct > manaViperEnd and s.aspect_viper) or not s.aspect_viper
                if A.AspectoftheHawk:IsReady(PLAYER_UNIT) and Unit(PLAYER_UNIT):HasBuffs(A.AspectoftheHawk.ID, true) == 0
                   and (context.in_combat or IsUnitEnemy(unit)) and viperOff and not context.is_mounted then
                    return A.AspectoftheHawk:Show(icon), "[RANGED] Aspect of the Hawk"
                end
            end

            -- [R-5] Readiness controller (outside burst)
            if s.use_readiness and A.Readiness:IsReady(PLAYER_UNIT) then
                if s.readiness_rapid_fire and ttd_ok then
                    if A.RapidFire:GetCooldown() >= 120 - (30 * num(A.RapidKilling1:IsTalentLearned())) - (30 * num(A.RapidKilling2:IsTalentLearned())) then
                        return A.Readiness:Show(icon), "[RANGED] Readiness (Rapid Fire)"
                    end
                end
                if s.readiness_misdirection then
                    if A.Misdirection:GetCooldown() >= 10 then
                        return A.Readiness:Show(icon), "[RANGED] Readiness (Misdirection)"
                    end
                end
            end

            -- [R-6] Protect frozen target (auto-switch)
            if s.protect_freeze and Unit("target"):HasDeBuffs(A.FreezingTrapDebuff.ID) > 0 and MultiUnits:GetActiveEnemies() >= 2 then
                return A:Show(icon, CONST.AUTOTARGET)
            end

            -- [R-7] Freezing Trap on adds
            if A.FreezingTrap:IsReady(PLAYER_UNIT) and s.freezing_trap_pve and MultiUnits:GetActiveEnemies() >= 2 and MultiUnits:GetByRangeInCombat(5, 1, 5) >= 1 and not CheckCCImmune(unit) then
                return A.FreezingTrap:Show(icon), "[RANGED] Freezing Trap"
            end

            -- [R-8] Mend Pet
            local mendPetHP = s.mend_pet_hp or 30
            if A.MendPet:IsReady(PLAYER_UNIT) and context.pet_hp < mendPetHP and context.pet_active and Unit("pet"):HasBuffs(A.MendPet.ID, true) == 0 then
                return A.MendPet:Show(icon), "[RANGED] Mend Pet"
            end

            -- [R-9] Hunter's Mark
            if A.HuntersMark:IsReady(unit) and Unit(unit):HasDeBuffs(A.HuntersMark.ID) == 0
               and ((Player:GetDeBuffsUnitCount(A.HuntersMark.ID) == 0 and s.static_mark) or not s.static_mark)
               and Unit(unit):TimeToDie() > 2
               and not ARCANE_IMMUNE[npcID]
               and ((Unit(unit):IsBoss() and s.boss_mark) or not s.boss_mark) then
                return A.HuntersMark:Show(icon), "[RANGED] Hunter's Mark"
            end

            -- [R-10] Experimental pet controller
            if s.experimental_pet and context.pet_active then
                if not Pet:IsAttacking() and context.pet_hp > mendPetHP - 20 then
                    return A.PetAttack:Show(icon), "[RANGED] Pet Attack"
                end
            end

            -- [R-11] Kill Command (off-GCD, 5s CD — highest DPS priority)
            if ttd_ok and A.KillCommand:IsReady(unit) then
                return A.KillCommand:Show(icon), "[RANGED] Kill Command"
            end

            -- ============================================
            -- RANGED ROTATION (at range)
            -- ============================================
            if AtRange(unit) then
                -- [R-12] Auto Shoot
                if not Player:IsShooting() then
                    return A:Show(icon, CONST.AUTOSHOOT)
                end

                -- [R-13] Intimidation (PvE aggro)
                if A.Intimidation:IsReady(unit) and s.intimidation_pve and UnitIsUnit("targettarget", PLAYER_UNIT) and Unit("target"):IsControlAble("stun") and not CheckCCImmune(unit) then
                    return A.Intimidation:Show(icon), "[RANGED] Intimidation"
                end

                -- [R-14] Concussive Shot (PvE)
                if A.ConcussiveShot:IsReady(unit) and s.concussive_shot_pve and not Unit(unit):IsBoss()
                   and Unit("target"):IsMelee() and UnitIsUnit("targettarget", PLAYER_UNIT)
                   and A.LastPlayerCastName ~= A.Intimidation:Info()
                   and (not A.Intimidation:IsReady(unit) or Unit("pet"):HasBuffs(A.Intimidation.ID) == 0 or not s.intimidation_pve)
                   and Unit(unit):HasDeBuffs(A.WingClip.ID) < GetGCD()
                   and not ARCANE_IMMUNE[npcID] and not CheckCCImmune(unit) then
                    return A.ConcussiveShot:Show(icon), "[RANGED] Concussive Shot (PvE)"
                end

                -- [R-14b] PvP Concussive Shot
                if A.IsInPvP and A.ConcussiveShot:IsReady(unit) and not CheckCCImmune(unit) and Unit(unit):HasDeBuffs(A.WingClip.ID) < GetGCD() then
                    local range = GetRange(unit)
                    if range > 0 and (range < 10 or range > 25) then
                        if Unit(unit):HasDeBuffs(A.ConcussiveShot.ID, true) < 2 then
                            return A.ConcussiveShot:Show(icon), "[RANGED] Concussive Shot (PvP)"
                        end
                    end
                end

                -- [R-15] PvP Viper Sting
                if A.IsInPvP and A.ViperSting:IsReady(unit) then
                    if ShouldUseViperSting(unit) then
                        if Unit(unit):HasDeBuffs(A.ViperSting.ID, true) <= GetGCD() then
                            return A.ViperSting:Show(icon), "[RANGED] Viper Sting (PvP)"
                        end
                    end
                end

                -- [R-16] Burst Cooldowns
                local useAoE = s.aoe
                local autoSyncCDs = s.auto_sync_cds
                local BurnPhase = Unit(PLAYER_UNIT):HasBuffs(A.Heroism.ID) > 0 or Unit(PLAYER_UNIT):HasBuffs(A.Bloodlust.ID) > 0 or Unit(PLAYER_UNIT):HasBuffs(A.Drums.ID) > 0

                if BurstIsON(unit) or (not BurstIsON(unit) and autoSyncCDs) then
                    if (autoSyncCDs and BurnPhase) or not autoSyncCDs then
                        if ttd_ok and A.BestialWrath:IsReady(PLAYER_UNIT) and s.use_bestial_wrath and context.pet_active and (Unit(unit):TimeToDie() > 5 or Unit(unit):IsBoss()) then
                            return A.BestialWrath:Show(icon), "[BURST] Bestial Wrath"
                        end

                        if ttd_ok and A.RapidFire:IsReady(PLAYER_UNIT) and s.use_rapid_fire and Unit(PLAYER_UNIT):HasBuffs(A.RapidFire.ID, true) == 0 and (Unit(unit):TimeToDie() > 5 or Unit(unit):IsBoss()) then
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

                        if ttd_ok and A.BloodFury:IsReady(PLAYER_UNIT) and s.use_racial and (Unit(unit):TimeToDie() > 5 or Unit(unit):IsBoss()) then
                            return A.BloodFury:Show(icon), "[BURST] Blood Fury"
                        end

                        if ttd_ok and A.Berserking:IsReady(PLAYER_UNIT) and s.use_racial and (Unit(unit):TimeToDie() > 5 or Unit(unit):IsBoss()) then
                            return A.Berserking:Show(icon), "[BURST] Berserking"
                        end

                        if s.use_haste_potion and A.HastePotion:IsReady(PLAYER_UNIT) then
                            return A:Show(icon, CONST.POTION), "[BURST] Haste Potion"
                        end
                    end
                end

                -- [R-17] Moving Arcane Shot
                local useArcane = s.use_arcane
                local arcaneShotMana = s.arcane_shot_mana or 15
                local manaSave = s.mana_save or 30

                if context.is_moving and A.ArcaneShot:IsReady(unit) and not ARCANE_IMMUNE[npcID] and context.mana_pct > arcaneShotMana then
                    return A.ArcaneShot:Show(icon), "[RANGED] Arcane Shot (moving)"
                end

                -- [R-18] Shot Weaving
                local ShootTimer = context.shoot_timer
                local speed = context.weapon_speed
                local latency = GetLatency()
                local SteadyAfterHaste = A.SteadyShot:GetSpellCastTimeCache()
                local MultiAfterHaste = A.MultiShot:GetSpellCastTimeCache()

                -- Fallback: if GetSpellInfo returned base (unhasted) cast time, use manual calc
                if SteadyAfterHaste >= 1.5 then
                    local WpnSpeedSld = s.weapon_speed or 3
                    local haste = WpnSpeedSld / speed
                    SteadyAfterHaste = 1.5 / haste
                    MultiAfterHaste = 0.5 / haste
                end

                if s.warces then
                    -- Warces haste-adjusted version
                    local gcdLeft = GetCurrentGCD() or 0
                    local available = ShootTimer - gcdLeft - latency

                    if GetGCD() <= speed then
                        if available >= MultiAfterHaste and available < SteadyAfterHaste and A.MultiShot:IsReady(unit) and useAoE and context.mana_pct > manaSave then
                            if CT then CT:RecordSuggestion("Multi-Shot", ShootTimer) end
                            return A.MultiShot:Show(icon), "[RANGED] Multi-Shot (warces)"
                        end
                        if ShootTimer > 0 and available < MultiAfterHaste and A.ArcaneShot:IsReady(unit) and useArcane and not ARCANE_IMMUNE[npcID] and context.mana_pct > arcaneShotMana then
                            if CT then CT:RecordSuggestion("Arcane Shot", ShootTimer) end
                            return A.ArcaneShot:Show(icon), "[RANGED] Arcane Shot (warces)"
                        end
                        if available >= SteadyAfterHaste and A.SteadyShot:IsReady(unit) and A.LastPlayerCastName == A.ArcaneShot:Info() then
                            if CT then CT:RecordSuggestion("Steady Shot", ShootTimer) end
                            return A.SteadyShot:Show(icon), "[RANGED] Steady Shot (warces post-arcane)"
                        end
                        if available >= SteadyAfterHaste and A.SteadyShot:IsReady(unit) then
                            if CT then CT:RecordSuggestion("Steady Shot", ShootTimer) end
                            return A.SteadyShot:Show(icon), "[RANGED] Steady Shot (warces)"
                        end
                    end

                    if GetGCD() > speed then
                        if available >= MultiAfterHaste and available < SteadyAfterHaste and A.MultiShot:IsReady(unit) and useAoE and context.mana_pct > manaSave then
                            if CT then CT:RecordSuggestion("Multi-Shot", ShootTimer) end
                            return A.MultiShot:Show(icon), "[RANGED] Multi-Shot (warces slow)"
                        end
                        if ShootTimer > 0 and available < MultiAfterHaste and A.ArcaneShot:IsReady(unit) and useArcane and not ARCANE_IMMUNE[npcID] and context.mana_pct > arcaneShotMana then
                            if CT then CT:RecordSuggestion("Arcane Shot", ShootTimer) end
                            return A.ArcaneShot:Show(icon), "[RANGED] Arcane Shot (warces slow)"
                        end
                        if available >= SteadyAfterHaste and A.SteadyShot:IsReady(unit) then
                            if CT then CT:RecordSuggestion("Steady Shot", ShootTimer) end
                            return A.SteadyShot:Show(icon), "[RANGED] Steady Shot (warces slow)"
                        end
                    end
                end

                -- Standard version (swing timer based)
                -- Gate: only weave when there's a window between auto shots
                if not s.warces then
                    local steadyCast = Player:Execute_Time(A.SteadyShot.ID)
                    local multiCast = Player:Execute_Time(A.MultiShot.ID)
                    local canWeave = ShootTimer < steadyCast and (ShootTimer > multiCast or ShootTimer <= latency)

                    if canWeave then
                        -- Multi-Shot (gated by mana_save)
                        if A.MultiShot:IsReady(unit) and useAoE and context.mana_pct > manaSave then
                            if CT then CT:RecordSuggestion("Multi-Shot", ShootTimer) end
                            return A.MultiShot:Show(icon), "[RANGED] Multi-Shot"
                        end

                        -- Stings (gated by mana_save — expensive at 275 mana)
                        if context.mana_pct > manaSave then
                            if s.use_serpent_sting then
                                if A.SerpentSting:IsReady(unit) and Unit(unit):HasDeBuffs(A.SerpentSting.ID, true) <= GetGCD() and Unit(unit):TimeToDie() >= 4 then
                                    if CT then CT:RecordSuggestion("Serpent Sting", ShootTimer) end
                                    return A.SerpentSting:Show(icon), "[RANGED] Serpent Sting"
                                end
                            end

                            if s.use_scorpid_sting then
                                if A.ScorpidSting:IsReady(unit) and Unit(unit):HasDeBuffs(A.ScorpidSting.ID, true) <= GetGCD() + 0.5 and Unit(unit):IsBoss() then
                                    if CT then CT:RecordSuggestion("Scorpid Sting", ShootTimer) end
                                    return A.ScorpidSting:Show(icon), "[RANGED] Scorpid Sting"
                                end
                            end

                            if s.use_viper_sting_pve then
                                if A.ViperSting:IsReady(unit) and Unit(unit):PowerType() == "MANA" and Unit(unit):Power() >= 10 then
                                    if CT then CT:RecordSuggestion("Viper Sting", ShootTimer) end
                                    return A.ViperSting:Show(icon), "[RANGED] Viper Sting (PvE)"
                                end
                            end
                        end

                        -- Arcane Shot (gated by its own mana threshold)
                        if A.ArcaneShot:IsReady(unit) and useArcane and not ARCANE_IMMUNE[npcID] and context.mana_pct > arcaneShotMana then
                            if CT then CT:RecordSuggestion("Arcane Shot", ShootTimer) end
                            return A.ArcaneShot:Show(icon), "[RANGED] Arcane Shot"
                        end
                    end

                    -- Steady Shot: always castable (cheap at 110 mana), fires when window allows
                    if (ShootTimer >= steadyCast or (ShootTimer <= latency and ShootTimer > 0)) then
                        if A.SteadyShot:IsReady(unit) then
                            if CT then CT:RecordSuggestion("Steady Shot", ShootTimer) end
                            return A.SteadyShot:Show(icon), "[RANGED] Steady Shot"
                        end
                    end
                end
            end -- end AtRange

            -- ============================================
            -- MELEE ROTATION (in melee range)
            -- ============================================
            if InMelee(unit) then
                -- [R-19] Disengage (PvE, when mob is on us)
                if not A.IsInPvP and A.Disengage:IsReady(unit) and UnitIsUnit("targettarget", PLAYER_UNIT)
                   and (not A.Intimidation:IsReady(unit) or Unit("pet"):HasBuffs(A.Intimidation.ID) == 0 or not s.intimidation_pve) then
                    return A.Disengage:Show(icon), "[MELEE] Disengage"
                end

                -- [R-20] Explosive Trap (AoE in melee)
                if A.ExplosiveTrap:IsReady(unit) and MultiUnits:GetByRange(5, 3) > 2 and s.aoe then
                    return A.ExplosiveTrap:Show(icon), "[MELEE] Explosive Trap"
                end

                -- [R-21] Wing Clip
                if ShouldUseWingClip(unit) and A.WingClip:IsReady(unit) and Unit(unit):HasDeBuffs(A.WingClip.ID, true) <= GetGCD()
                   and A.WingClip:AbsentImun(unit, Constants.Temp.TotalAndPhysAndCC) and not CheckCCImmune(unit) then
                    return A.WingClip:Show(icon), "[MELEE] Wing Clip"
                end

                -- [R-22] Mongoose Bite
                if A.MongooseBite:IsReady(unit) then
                    return A.MongooseBite:Show(icon), "[MELEE] Mongoose Bite"
                end

                -- [R-23] Raptor Strike
                if A.RaptorStrike:IsReady(unit) and not A.RaptorStrike:IsSpellCurrent() and not Player:IsShooting() then
                    return A.RaptorStrike:Show(icon), "[MELEE] Raptor Strike"
                end

                -- [R-24] Auto Attack
                if not Player:IsAttacking() then
                    return A:Show(icon, CONST.AUTOATTACK)
                end
            end -- end InMelee

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
