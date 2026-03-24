-- Warrior Middleware Module
-- Cross-playstyle concerns: emergency, recovery, interrupts, shouts, cooldowns

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Warrior Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local MultiUnits = A.MultiUnits
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local Constants = NS.Constants
local debug_print = NS.debug_print
local DetermineUsableObject = A.DetermineUsableObject
local LoC = A.LossOfControl

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local CONST = A.Const

-- Pre-allocated LoC type arrays (avoid inline table creation in combat)
local LOC_FEAR_INCAP = { "FEAR", "INCAPACITATE" }
local LOC_FEAR = { "FEAR" }

-- Tactical Mastery: returns max rage preserved after stance swap (5 per rank, 0-25)
local function get_tactical_mastery_cap()
    return (A.TacticalMastery:GetTalentRank() or 0) * 5
end

-- Check if rage would be wasted by a stance swap
-- Returns true if the swap is rage-safe (won't lose significant rage)
local function is_stance_swap_safe(current_rage, ability_cost)
    local tm_cap = get_tactical_mastery_cap()
    local rage_after_swap = current_rage <= tm_cap and current_rage or tm_cap
    return rage_after_swap >= ability_cost
end

-- Expose for spec modules (arms.lua Overpower dance, etc.)
NS.is_stance_swap_safe = is_stance_swap_safe

-- ============================================================================
-- HS/CLEAVE QUEUE TRICK (highest priority — dequeue before MH swing lands)
-- In TBC, queuing HS/Cleave converts both MH and OH swings to "yellow" hits
-- (no glancing blows, better hit table). The trick: queue HS to get yellow
-- OH hit, then dequeue before MH lands if rage is insufficient.
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_HSQueueDequeue",
    priority = 999,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.hs_trick then return false end
        if not context.has_valid_enemy_target then return false end
        -- Only meaningful when dual-wielding (Fury with OH weapon)
        if not context.has_offhand then return false end
        -- Check if HS or Cleave is currently queued
        return A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent()
    end,

    execute = function(icon, context)
        local mh_remaining = NS.get_time_until_swing()
        local should_dequeue = false
        local reason = ""

        -- 1. MH swing landing soon and not enough rage for HS cost
        --    But keep queued if OH lands first (we want the yellow OH hit)
        if mh_remaining > 0 and mh_remaining <= 0.4 then
            local hs_cost = 15  -- HS base cost in TBC
            if context.rage < hs_cost then
                local oh_remaining = context.oh_remain or 999
                if oh_remaining <= 0 then oh_remaining = 999 end
                -- Only dequeue if MH lands before OH (preserve yellow OH hit)
                if mh_remaining <= oh_remaining then
                    should_dequeue = true
                    reason = format("Low rage (%d)", context.rage)
                end
            end
        end

        -- 2. Target casting a kickable spell — hold rage for Pummel
        if not should_dequeue and context.has_valid_enemy_target then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                local hs_cost = 15
                local pummel_cost = 10
                if context.rage < (hs_cost + pummel_cost) then
                    should_dequeue = true
                    reason = format("Hold for interrupt (rage: %d)", context.rage)
                end
            end
        end

        -- 3. Target entered execute phase — Execute is better DPS
        if not should_dequeue then
            local target_hp = context.target_hp or 100
            if target_hp <= 20 then
                local playstyle = context.settings.playstyle or "fury"
                local exec_key = playstyle .. "_execute_phase"
                local hs_exec_key = playstyle .. "_hs_during_execute"
                if context.settings[exec_key] and not context.settings[hs_exec_key] then
                    should_dequeue = true
                    reason = "Execute phase"
                end
            end
        end

        if should_dequeue then
            return A:Show(icon, CONST.STOPCAST), format("[MW] HS Dequeue - %s", reason)
        end

        return nil
    end,
})

-- ============================================================================
-- LAST STAND (Emergency — highest priority, Prot talent)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_LastStand",
    priority = 500,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.last_stand_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.LastStand:IsReady(PLAYER_UNIT) then
            return A.LastStand:Show(icon), format("[MW] Last Stand - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- SHIELD WALL (Emergency DR)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_ShieldWall",
    priority = 490,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.shield_wall_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        -- Shield Wall requires Defensive Stance
        if context.stance ~= Constants.STANCE.DEFENSIVE then return false end
        return true
    end,

    execute = function(icon, context)
        if A.ShieldWall:IsReady(PLAYER_UNIT) then
            return A.ShieldWall:Show(icon), format("[MW] Shield Wall - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- LOSS OF CONTROL BREAKERS (Reactive fear/incap removal)
-- ============================================================================
-- BerserkerRage breaks fear and incapacitate (Berserker Stance only).
-- DeathWish's enrage effect also breaks fear.
-- These fire reactively only when the player IS feared/incapacitated.
rotation_registry:register_middleware({
    name = "Warrior_LoCBreaker",
    priority = 485,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_loc_breaker then return false end
        -- Check if we're currently feared or incapacitated
        local ok = LoC:IsValid(LOC_FEAR_INCAP)
        return ok
    end,

    execute = function(icon, context)
        -- BerserkerRage: breaks fear + incap, requires Berserker Stance
        if context.stance == Constants.STANCE.BERSERKER and A.BerserkerRage:IsReady(PLAYER_UNIT) then
            return A.BerserkerRage:Show(icon), "[MW] Berserker Rage (FEAR/INCAP BREAK)"
        end

        -- DeathWish: enrage breaks fear (any stance, Fury talent)
        local fear_remain = LoC:Get("FEAR")
        if fear_remain and fear_remain > 0 and A.DeathWish:IsReady(PLAYER_UNIT) then
            return A.DeathWish:Show(icon), "[MW] Death Wish (FEAR BREAK)"
        end

        return nil
    end,
})

-- ============================================================================
-- EXTERNAL BUFF CANCELAURA (Remove rage-blocking / attack-preventing buffs)
-- ============================================================================
-- PW:S blocks rage generation from damage taken.
-- BoP prevents attacking entirely.
rotation_registry:register_middleware({
    name = "Warrior_CancelExternalBuff",
    priority = 475,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        return true
    end,

    execute = function(icon, context)
        -- Cancel Power Word: Shield when rage is low (blocks rage from damage taken)
        if context.settings.cancel_pws then
            local pws_dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.POWER_WORD_SHIELD) or 0
            if pws_dur > 0 and context.rage < 30 then
                Player:CancelBuff((A.PowerWordShield:Info()))
                return A.PowerWordShield:Show(icon), format("[MW] Cancel PW:S - Rage: %d", context.rage)
            end
        end

        -- Cancel Blessing of Protection when HP is safe (prevents all attacks)
        if context.settings.cancel_bop then
            local bop_dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BUFF_ID.BLESSING_OF_PROT) or 0
            if bop_dur > 0 and context.hp > 50 then
                Player:CancelBuff((A.BlessingOfProtection:Info()))
                return A.BlessingOfProtection:Show(icon), format("[MW] Cancel BoP - HP: %.0f%%", context.hp)
            end
        end

        return nil
    end,
})

-- ============================================================================
-- SPELL REFLECTION (Proactive defense)
-- ============================================================================
-- PvP: whitelist-only — reflect high-value CC and burst spells
-- PvE: reflect any interruptible non-channel cast targeting us

-- PvP whitelist: only reflect these spells (matched by name, English client)
-- Tier 1: CC — always reflect, game-changing
-- Tier 2: Big damage nukes
-- Tier 3: Moderate value
local PVP_REFLECTABLE_SPELLS = {
    -- Tier 1: CC
    ["Polymorph"]         = true,  -- Mage (8s full CC)
    ["Fear"]              = true,  -- Warlock (full CC)
    ["Death Coil"]        = true,  -- Warlock (3s Horror + self-heal)
    ["Cyclone"]           = true,  -- Druid (6s full CC, unique DR)
    ["Mind Control"]      = true,  -- Priest (channeled but initial cast reflectable)
    ["Hammer of Justice"] = true,  -- Paladin (6s stun)

    -- Tier 2: Big damage
    ["Pyroblast"]         = true,  -- Mage (massive crit burst)
    ["Mind Blast"]        = true,  -- Priest (high damage + Shadowform synergy)
    ["Aimed Shot"]        = true,  -- Hunter (big burst)
    ["Shadow Bolt"]       = true,  -- Warlock (primary nuke)

    -- Tier 3: Moderate value
    ["Frostbolt"]         = true,  -- Mage (damage + slow)
    ["Fireball"]          = true,  -- Mage (solid damage)
    ["Lightning Bolt"]    = true,  -- Shaman (damage)
    ["Chain Lightning"]   = true,  -- Shaman (first target hit)
    ["Starfire"]          = true,  -- Druid (slow cast, big hit)
    ["Wrath"]             = true,  -- Druid (fast cast)
    ["Incinerate"]        = true,  -- Warlock (TBC nuke)
    ["Immolate"]          = true,  -- Warlock (DoT component)
    ["Holy Fire"]         = true,  -- Priest (damage + DoT)
    ["Hammer of Wrath"]   = true,  -- Paladin (execute range)
}

-- PvP: scan enemy nameplates for whitelisted casts targeting us
local function pvp_find_reflectable_caster()
    local plates = MultiUnits:GetActiveUnitPlates()
    if not plates then return false end
    for unitID in pairs(plates) do
        if unitID and UnitExists(unitID) and not UnitIsDead(unitID) and UnitIsPlayer(unitID) then
            local castLeft, _, _, spellName, notKickAble, isChannel = Unit(unitID):IsCastingRemains()
            if castLeft and castLeft > 0 and castLeft < 2.0 and not notKickAble and not isChannel then
                if spellName and PVP_REFLECTABLE_SPELLS[spellName] then
                    local targetOfUnit = unitID .. "target"
                    if UnitExists(targetOfUnit) and UnitIsUnit(targetOfUnit, PLAYER_UNIT) then
                        return true, castLeft, spellName
                    end
                end
            end
        end
    end
    return false
end

-- PvE: check if any enemy nameplate or target is casting at us (any interruptible spell)
local function pve_find_reflectable_caster(has_target)
    -- Check target first (most common case)
    if has_target then
        local castLeft, _, _, spellName, notKickAble, isChannel = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble and not isChannel then
            local targetOfTarget = TARGET_UNIT .. "target"
            if UnitExists(targetOfTarget) and UnitIsUnit(targetOfTarget, PLAYER_UNIT) then
                return true, castLeft, spellName
            end
        end
    end

    -- Scan nameplates for other casters targeting us (e.g. trash packs)
    local plates = MultiUnits:GetActiveUnitPlates()
    if not plates then return false end
    for unitID in pairs(plates) do
        if unitID and UnitExists(unitID) and not UnitIsDead(unitID) then
            local castLeft, _, _, spellName, notKickAble, isChannel = Unit(unitID):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble and not isChannel then
                local targetOfUnit = unitID .. "target"
                if UnitExists(targetOfUnit) and UnitIsUnit(targetOfUnit, PLAYER_UNIT) then
                    return true, castLeft, spellName
                end
            end
        end
    end
    return false
end

rotation_registry:register_middleware({
    name = "Warrior_SpellReflection",
    priority = 400,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_spell_reflection then return false end
        -- Spell Reflect works in Battle or Defensive Stance only
        if context.stance == Constants.STANCE.BERSERKER then return false end

        -- PvP: whitelist-only, scan all enemy nameplates
        if context.is_pvp and context.settings.pvp_enabled then
            local found, castLeft, spellName = pvp_find_reflectable_caster()
            if found then
                context._sr_cast_left = castLeft
                context._sr_spell_name = spellName
            end
            return found
        end

        -- PvE: reflect any interruptible non-channel cast targeting us
        local found, castLeft, spellName = pve_find_reflectable_caster(context.has_valid_enemy_target)
        if found then
            context._sr_cast_left = castLeft
            context._sr_spell_name = spellName
        end
        return found
    end,

    execute = function(icon, context)
        if A.SpellReflection:IsReady(PLAYER_UNIT) then
            local castLeft = context._sr_cast_left or 0
            local spellName = context._sr_spell_name or "?"
            return A.SpellReflection:Show(icon), format("[MW] Spell Reflection - %s (%.1fs)", spellName, castLeft)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.healthstone_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local HealthStoneObject = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HealthstoneMaster, A.HealthstoneMajor)
        if HealthStoneObject then
            return HealthStoneObject:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- HEALING POTION (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,

    matches = function(context)
        if not context.settings.use_healing_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.healing_potion_hp or 25
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperHealingPotion:IsReady(PLAYER_UNIT) then
            return A.SuperHealingPotion:Show(icon), format("[MW] Super Healing Potion - HP: %.0f%%", context.hp)
        end
        if A.MajorHealingPotion:IsReady(PLAYER_UNIT) then
            return A.MajorHealingPotion:Show(icon), format("[MW] Major Healing Potion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- INTERRUPT (Pummel / Shield Bash — with stance dancing + PvP CC fallbacks)
-- ============================================================================
-- Pummel: Berserker Stance only. If in Battle Stance, dance to Berserker first.
-- Shield Bash: Defensive Stance only (requires shield equipped).
-- Priority: Pummel > stance dance for Pummel > Shield Bash (no dance to Defensive).
-- PvP: immunity-aware, CC fallback chain when kick on CD (ConcBlow → IntimShout → WarStomp).
rotation_registry:register_middleware({
    name = "Warrior_Interrupt",
    priority = 250,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_interrupt then return false end
        if not context.has_valid_enemy_target then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if not castLeft or castLeft <= 0 then return nil end

        local is_pvp_mode = context.is_pvp and context.settings.pvp_enabled

        -- PvP AntiFake: use humanized random kick timing (CanInterrupt)
        -- Randomizes between 15-67% of cast bar so opponents can't predict our kick window
        -- PvE: kick ASAP (no delay)
        local kick_allowed = true
        if is_pvp_mode then
            kick_allowed = Unit(TARGET_UNIT):CanInterrupt(true, nil, 15, 67)
        end

        -- PvP: Check kick immunity before committing
        if is_pvp_mode and notKickAble then
            -- Target immune to kicks — skip to CC fallbacks below
            kick_allowed = false
        elseif kick_allowed then
            if notKickAble then return nil end

            -- PvP: Verify target isn't immune to physical interrupts
            if is_pvp_mode and not A.Pummel:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForInterrupt) then
                return nil
            end

            -- Already in Berserker → Pummel directly
            if context.stance == Constants.STANCE.BERSERKER and A.Pummel:IsReady(TARGET_UNIT) then
                return A.Pummel:Show(icon), format("[MW] Pummel - Cast: %.1fs", castLeft)
            end

            -- Already in Defensive → Shield Bash (requires shield)
            if context.stance == Constants.STANCE.DEFENSIVE and A.ShieldBash:IsReady(TARGET_UNIT) then
                return A.ShieldBash:Show(icon), format("[MW] Shield Bash - Cast: %.1fs", castLeft)
            end

            -- In Battle Stance: dance to Berserker for Pummel (enough time to swap + kick)
            if context.stance == Constants.STANCE.BATTLE and castLeft > 0.5 then
                local pummel_cd = A.Pummel:GetCooldown() or 0
                if pummel_cd <= 0 and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                    return A.BerserkerStance:Show(icon), format("[MW] → Berserker (for Pummel) - Cast: %.1fs", castLeft)
                end
            end
        end

        -- PvP CC fallback chain: when kick is on CD, not in correct stance, or waiting for AntiFake timing
        if is_pvp_mode and context.settings.pvp_interrupt_cc_fallback and castLeft > 0.3 then
            -- Concussion Blow (stun, Prot talent) — check stun immunity
            if context.in_melee_range
                and A.ConcussionBlow:IsReady(TARGET_UNIT)
                and A.ConcussionBlow:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForStun)
                and Unit(TARGET_UNIT):IsControlAble("stun")
            then
                return A.ConcussionBlow:Show(icon), format("[MW] Concussion Blow (interrupt) - Cast: %.1fs", castLeft)
            end

            -- Intimidating Shout (fear) — check fear immunity
            if context.in_melee_range
                and A.IntimidatingShout:IsReady(TARGET_UNIT)
                and A.IntimidatingShout:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForFear)
                and Unit(TARGET_UNIT):IsControlAble("fear")
            then
                return A.IntimidatingShout:Show(icon), format("[MW] Intimidating Shout (interrupt) - Cast: %.1fs", castLeft)
            end

            -- War Stomp (Tauren racial, PBAoE stun) — check stun immunity
            if context.in_melee_range
                and A.WarStomp:IsReady(PLAYER_UNIT)
                and A.WarStomp:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForStun)
            then
                return A.WarStomp:Show(icon), format("[MW] War Stomp (interrupt) - Cast: %.1fs", castLeft)
            end
        end

        return nil
    end,
})

-- ============================================================================
-- BLOODRAGE (Rage generation)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Bloodrage",
    priority = 200,
    is_gcd_gated = false,

    matches = function(context)
        if not context.settings.use_bloodrage then return false end
        if not context.in_combat then return false end
        -- Don't waste Bloodrage if rage is already high
        if context.rage > 80 then return false end
        -- Bloodrage costs HP, don't use at low HP
        local min_hp = context.settings.bloodrage_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Bloodrage:IsReady(PLAYER_UNIT) then
            return A.Bloodrage:Show(icon), format("[MW] Bloodrage - Rage: %d", context.rage)
        end
        return nil
    end,
})

-- ============================================================================
-- STANCE CORRECTION (Switch to spec's home stance when in melee)
-- ============================================================================
-- Pre-allocated lookup: stance ID → stance spell action
local STANCE_SPELL = {
    [Constants.STANCE.BATTLE]    = A.BattleStance,
    [Constants.STANCE.DEFENSIVE] = A.DefensiveStance,
    [Constants.STANCE.BERSERKER] = A.BerserkerStance,
}

rotation_registry:register_middleware({
    name = "Warrior_StanceCorrection",
    priority = 195,

    matches = function(context)
        if context.is_mounted then return false end
        if not context.has_valid_enemy_target then return false end
        -- Out of combat at range: don't correct stance — let AutoCharge or manual approach handle it
        if not context.in_combat and not context.in_melee_range then return false end
        local spec = context.settings.playstyle or "fury"
        local preferred = Constants.PREFERRED_STANCE[spec]
        if not preferred then return false end
        if context.stance == preferred then return false end
        -- Don't fight inline stance dances: Arms WW needs Berserker — yield while WW is ready
        if spec == "arms" and context.stance == Constants.STANCE.BERSERKER
            and context.settings.arms_use_whirlwind
            and context.rage >= 25
            and (A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true)) then
            return false
        end
        -- Don't fight inline stance dances: Prot TC needs Battle — yield while TC debuff needs refresh
        if spec == "protection" and context.stance == Constants.STANCE.BATTLE
            and context.settings.prot_use_thunder_clap then
            local tc_debuff = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
            if tc_debuff <= Constants.TC_REFRESH_WINDOW then
                return false
            end
        end
        -- Don't fight inline stance dances: Prot Mocking Blow needs Battle — yield while aggro lost & Taunt on CD
        if spec == "protection" and context.stance == Constants.STANCE.BATTLE
            and context.settings.prot_use_taunt
            and not context.settings.prot_no_taunt then
            if _G.UnitExists("targettarget") and not _G.UnitIsUnit("targettarget", "player") then
                local taunt_cd = A.Taunt:GetCooldown() or 0
                if taunt_cd > 0 and (A.MockingBlow:GetCooldown() or 0) <= 0 then
                    return false
                end
            end
        end
        -- TM check: don't swap if we'd lose significant rage
        local tm_cap = get_tactical_mastery_cap()
        -- Arms needs to return to Battle often (MS/Overpower) — tolerate more rage waste
        local waste_tolerance = spec == "arms" and 20 or 5
        if context.rage > tm_cap + waste_tolerance then return false end
        return true
    end,

    execute = function(icon, context)
        local spec = context.settings.playstyle or "fury"
        local preferred = Constants.PREFERRED_STANCE[spec]
        local spell = STANCE_SPELL[preferred]
        if spell and spell:IsReady(PLAYER_UNIT) then
            return spell:Show(icon), format("[MW] Stance → %s", preferred == 1 and "Battle" or preferred == 2 and "Defensive" or "Berserker")
        end
        return nil
    end,
})

-- ============================================================================
-- PVP DEFENSIVE STANCE AT RANGE (Damage reduction when kiting/kited)
-- ============================================================================
-- In PvP, when out of melee and Intercept is on CD, switch to Defensive Stance
-- for the 10% damage reduction. Re-entering melee triggers StanceCorrection (195)
-- to swap back to the spec's preferred stance automatically.
rotation_registry:register_middleware({
    name = "Warrior_PvPDefStanceRange",
    priority = 192,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_def_stance_range then return false end
        if not context.has_valid_enemy_target then return false end
        -- Only when out of melee range
        if context.in_melee_range then return false end
        -- Already in Defensive
        if context.stance == Constants.STANCE.DEFENSIVE then return false end
        -- Don't switch if Intercept is available (we want to close gap via Berserker)
        local intercept_cd = A.Intercept:GetCooldown() or 0
        if intercept_cd <= 0 then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DefensiveStance:IsReady(PLAYER_UNIT) then
            return A.DefensiveStance:Show(icon), "[MW] Defensive Stance (PvP at range)"
        end
        return nil
    end,
})

-- ============================================================================
-- BERSERKER RAGE (Rage gen + Fear immunity)
-- ============================================================================
-- PvE: Use on CD for rage generation and enrage effects
-- PvP: Save for reactive fear/incap breaks (handled by LoC breaker at priority 485)
rotation_registry:register_middleware({
    name = "Warrior_BerserkerRage",
    priority = 150,
    is_burst = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_berserker_rage then return false end
        -- Berserker Rage requires Berserker Stance
        if context.stance ~= Constants.STANCE.BERSERKER then return false end
        if context.berserker_rage_active then return false end
        -- PvP: don't burn on CD — save for LoC breaks (prio 485 handles reactive usage)
        if context.is_pvp and context.settings.pvp_enabled then return false end
        return true
    end,

    execute = function(icon, context)
        if A.BerserkerRage:IsReady(PLAYER_UNIT) then
            return A.BerserkerRage:Show(icon), "[MW] Berserker Rage"
        end
        return nil
    end,
})

-- ============================================================================
-- SHOUT MAINTAIN (Battle Shout / Commanding Shout)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_ShoutMaintain",
    priority = 140,

    matches = function(context)
        if not context.settings.auto_shout then return false end
        if context.is_mounted then return false end
        -- Don't waste a GCD on shout if target is about to die
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.in_combat and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local shout_type = context.settings.shout_type or "battle"
        if shout_type == "none" then return false end

        -- Refresh if missing or duration < 30s (2 min buff, refresh early)
        -- Use all-rank arrays so we detect shouts from any party member at any rank
        if shout_type == "battle" then
            if not context.has_battle_shout then return true end
            local dur = Unit(PLAYER_UNIT):HasBuffs(Constants.BATTLE_SHOUT_IDS) or 0
            if dur < 30 then return true end
        end
        if shout_type == "commanding" then
            if not context.has_commanding_shout then return true end
            local dur = Unit(PLAYER_UNIT):HasBuffs(Constants.COMMANDING_SHOUT_IDS) or 0
            if dur < 30 then return true end
        end
        return false
    end,

    execute = function(icon, context)
        local shout_type = context.settings.shout_type or "battle"

        if shout_type == "battle" and A.BattleShout:IsReady(PLAYER_UNIT) then
            return A.BattleShout:Show(icon), "[MW] Battle Shout"
        end

        if shout_type == "commanding" and A.CommandingShout:IsReady(PLAYER_UNIT) then
            return A.CommandingShout:Show(icon), "[MW] Commanding Shout"
        end

        return nil
    end,
})

-- ============================================================================
-- DEATH WISH (+20% damage, Arms/Fury only)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_DeathWish",
    priority = 100,
    is_burst = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if context.death_wish_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end

        local ps = context.settings.playstyle or "fury"
        if ps == "arms" and not context.settings.arms_use_death_wish then return false end
        if ps == "fury" and not context.settings.fury_use_death_wish then return false end
        if ps == "protection" then return false end
        -- PvP: don't waste CDs on CC'd or physically immune targets
        if context.is_pvp and context.settings.pvp_enabled and context.target_is_player then
            local cc_remain = Unit(TARGET_UNIT):InCC() or 0
            if cc_remain > 2 then return false end
            if not A.DeathWish:AbsentImun(TARGET_UNIT, Constants.PVP.AttackTypes) then return false end
        end
        return true
    end,

    execute = function(icon, context)
        if A.DeathWish:IsReady(PLAYER_UNIT) then
            return A.DeathWish:Show(icon), "[MW] Death Wish"
        end
        return nil
    end,
})

-- ============================================================================
-- RECKLESSNESS (+100% crit, Fury only, Berserker Stance)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_Recklessness",
    priority = 90,
    is_burst = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if context.recklessness_active then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        local ps = context.settings.playstyle or "fury"
        if ps ~= "fury" then return false end
        if not context.settings.fury_use_recklessness then return false end
        -- Recklessness requires Berserker Stance
        if context.stance ~= Constants.STANCE.BERSERKER then return false end
        -- PvP: don't waste CDs on CC'd or physically immune targets
        if context.is_pvp and context.settings.pvp_enabled and context.target_is_player then
            local cc_remain = Unit(TARGET_UNIT):InCC() or 0
            if cc_remain > 2 then return false end
            if not A.Recklessness:AbsentImun(TARGET_UNIT, Constants.PVP.AttackTypes) then return false end
        end
        return true
    end,

    execute = function(icon, context)
        if A.Recklessness:IsReady(PLAYER_UNIT) then
            return A.Recklessness:Show(icon), "[MW] Recklessness"
        end
        return nil
    end,
})

-- ============================================================================
-- RACIAL (Blood Fury / Berserking / War Stomp / etc.)
-- ============================================================================
-- Offensive racials (Blood Fury, Berserking) fire as burst CDs.
-- Stoneform / Will of the Forsaken / Escape Artist fire as defensives.
-- War Stomp fires as a defensive interrupt (PBAoE stun).
rotation_registry:register_middleware({
    name = "Warrior_Racial",
    priority = 70,
    is_burst = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.settings.use_racial then return false end
        local min_ttd = context.settings.cd_min_ttd or 0
        if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
        -- PvP: don't waste burst racials on CC'd or immune targets
        if context.is_pvp and context.settings.pvp_enabled and context.target_is_player then
            local cc_remain = Unit(TARGET_UNIT):InCC() or 0
            if cc_remain > 2 then return false end
        end
        return true
    end,

    execute = function(icon, context)
        -- Offensive racials (burst)
        if A.BloodFury:IsReady(PLAYER_UNIT) then
            return A.BloodFury:Show(icon), "[MW] Blood Fury"
        end
        if A.Berserking:IsReady(PLAYER_UNIT) then
            return A.Berserking:Show(icon), "[MW] Berserking"
        end
        return nil
    end,
})

-- ============================================================================
-- DISARM (PvP — remove melee weapon, Defensive Stance required)
-- ============================================================================
-- Disarms target, requiring Defensive Stance. Stance-dances if needed.
-- Only targets player melee classes. Checks disarm immunity and DR.
-- Trigger modes: on_cooldown or on_burst (enemy has damage buffs).
local UnitClass = _G.UnitClass

-- Pre-allocated melee class set (WARRIOR, ROGUE, PALADIN, SHAMAN enh)
local DISARM_TARGET_CLASSES = {
    WARRIOR = true,
    ROGUE   = true,
    PALADIN = true,
    SHAMAN  = true,
}

rotation_registry:register_middleware({
    name = "Warrior_Disarm",
    priority = 258,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_disarm then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.target_is_player then return false end
        if not context.in_melee_range then return false end

        -- Check target class is melee
        local _, targetClass = UnitClass(TARGET_UNIT)
        if not targetClass or not DISARM_TARGET_CLASSES[targetClass] then return false end

        -- Trigger mode: on_burst requires enemy to have damage buffs
        local trigger = context.settings.pvp_disarm_trigger or "on_burst"
        if trigger == "on_burst" then
            local has_dmg_buffs = Unit(TARGET_UNIT):HasBuffs("DamageBuffs") or 0
            if has_dmg_buffs <= 0 then return false end
        end

        -- Check disarm immunity
        if not A.Disarm:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForDisarm) then return false end

        -- Check DR on disarm category
        if not Unit(TARGET_UNIT):IsControlAble("disarm") then return false end

        return true
    end,

    execute = function(icon, context)
        -- Disarm requires Defensive Stance — stance dance if needed
        if context.stance ~= Constants.STANCE.DEFENSIVE then
            if is_stance_swap_safe(context.rage, 20) and A.DefensiveStance:IsReady(PLAYER_UNIT) then
                return A.DefensiveStance:Show(icon), "[MW] Defensive Stance (for Disarm)"
            end
            return nil
        end

        if A.Disarm:IsReady(TARGET_UNIT) then
            return A.Disarm:Show(icon), "[MW] Disarm"
        end
        return nil
    end,
})

-- ============================================================================
-- RETALIATION (AoE counter-attack, Battle Stance only, 5 min CD)
-- ============================================================================
-- Reflects 30 melee attacks over 15s. Best when surrounded by many enemies.
rotation_registry:register_middleware({
    name = "Warrior_Retaliation",
    priority = 265,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_retaliation then return false end
        if not context.has_valid_enemy_target then return false end
        -- Only worth using when surrounded
        local min_enemies = context.settings.retaliation_min_enemies or 3
        if context.enemy_count < min_enemies then return false end
        -- Retaliation requires Battle Stance
        if context.stance ~= Constants.STANCE.BATTLE then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Retaliation:IsReady(PLAYER_UNIT) then
            return A.Retaliation:Show(icon), format("[MW] Retaliation - %d enemies", context.enemy_count)
        end
        return nil
    end,
})

-- Defensive racials: Stoneform (Dwarf), WotF (Undead), Escape Artist (Gnome)
rotation_registry:register_middleware({
    name = "Warrior_RacialDefensive",
    priority = 260,
    is_defensive = true,
    is_gcd_gated = false,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_racial then return false end
        return true
    end,

    execute = function(icon, context)
        -- Stoneform: removes bleed/poison/disease + 10% armor for 8s
        if A.Stoneform:IsReady(PLAYER_UNIT) then
            return A.Stoneform:Show(icon), "[MW] Stoneform"
        end
        -- Will of the Forsaken: removes fear/sleep/charm
        if A.WillOfTheForsaken:IsReady(PLAYER_UNIT) then
            return A.WillOfTheForsaken:Show(icon), "[MW] Will of the Forsaken"
        end
        -- Escape Artist: removes snare/root (useful when not in melee)
        if not context.in_melee_range and A.EscapeArtist:IsReady(PLAYER_UNIT) then
            return A.EscapeArtist:Show(icon), "[MW] Escape Artist"
        end
        return nil
    end,
})

-- War Stomp: PBAoE stun (Tauren) — useful as interrupt/CC
-- PvP: War Stomp is handled by the Interrupt MW CC fallback chain; this is PvE-only
rotation_registry:register_middleware({
    name = "Warrior_WarStomp",
    priority = 245,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_racial then return false end
        if not context.has_valid_enemy_target then return false end
        -- PvP: skip here, handled by Interrupt CC fallback chain
        if context.is_pvp and context.settings.pvp_enabled then return false end
        return true
    end,

    execute = function(icon, context)
        -- Use War Stomp as an interrupt when target is casting and other kicks unavailable
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0.5 and not notKickAble then
            -- Only if Pummel is on CD and we're in melee range
            local pummel_cd = A.Pummel:GetCooldown() or 0
            if pummel_cd > 0 and context.in_melee_range and A.WarStomp:IsReady(PLAYER_UNIT) then
                return A.WarStomp:Show(icon), format("[MW] War Stomp (interrupt) - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: HAMSTRING MAINTENANCE (keep snare on enemy players)
-- ============================================================================
-- Maintain Hamstring on enemy players. Checks slow immunity and existing debuff.
-- Skips targets with Evasion (will just dodge), Free Action Potion, or Freedom.
rotation_registry:register_middleware({
    name = "Warrior_PvPHamstring",
    priority = 65,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_hamstring then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.target_is_player then return false end
        if not context.in_melee_range then return false end
        -- Check slow immunity (Freedom, FAP, CCTotalImun)
        if not A.Hamstring:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForSlow) then return false end
        -- Skip if Hamstring already active (> 1s remaining for refresh window)
        local hamstring_dur = Unit(TARGET_UNIT):HasDeBuffs(A.Hamstring.ID, true) or 0
        if hamstring_dur > 1 then return false end
        -- Skip if target has Evasion active (will dodge)
        local evasion_dur = Unit(TARGET_UNIT):HasBuffs(A.Evasion.ID) or 0
        if evasion_dur > 0 then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Hamstring:IsReady(TARGET_UNIT) then
            return A.Hamstring:Show(icon), "[MW] Hamstring (PvP snare)"
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: PIERCING HOWL (AoE snare, Fury talent)
-- ============================================================================
-- AoE slow when 2+ enemy players nearby lack a slow. Instant, no stance req.
rotation_registry:register_middleware({
    name = "Warrior_PvPPiercingHowl",
    priority = 64,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_piercing_howl then return false end
        if not context.has_valid_enemy_target then return false end
        -- Need 2+ nearby enemies for AoE snare to be worth it
        if context.enemy_count < 2 then return false end
        -- CC break prevention
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        return true
    end,

    execute = function(icon, context)
        if A.PiercingHowl:IsReady(PLAYER_UNIT) then
            return A.PiercingHowl:Show(icon), format("[MW] Piercing Howl (PvP) - %d enemies", context.enemy_count)
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: REND ANTI-STEALTH (prevent Rogue/Druid restealth)
-- ============================================================================
-- Apply Rend to Rogues and Druids to keep them in combat and prevent stealth.
-- Rend is a bleed, so it ticks even through Evasion and ignores armor.
local STEALTH_CLASSES = { ROGUE = true, DRUID = true }

rotation_registry:register_middleware({
    name = "Warrior_PvPRendStealth",
    priority = 63,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_rend_stealth then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.target_is_player then return false end
        if not context.in_melee_range then return false end
        -- Only on stealth-capable classes
        local _, targetClass = UnitClass(TARGET_UNIT)
        if not targetClass or not STEALTH_CLASSES[targetClass] then return false end
        -- Rend requires Battle or Defensive Stance
        if context.stance == Constants.STANCE.BERSERKER then return false end
        -- Skip if Rend already active
        local rend_dur = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.REND, true) or 0
        if rend_dur > 2 then return false end
        -- Check immunity
        if not A.Rend:AbsentImun(TARGET_UNIT, Constants.PVP.AttackTypes) then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Rend:IsReady(TARGET_UNIT) then
            return A.Rend:Show(icon), "[MW] Rend (anti-stealth)"
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: OVERPOWER VS EVASION (high-priority Overpower when Evasion active)
-- ============================================================================
-- When target has Evasion or Deterrence, Overpower can't be dodged and should
-- be prioritized over other melee attacks. Requires Battle Stance.
rotation_registry:register_middleware({
    name = "Warrior_PvPOverpower",
    priority = 62,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_overpower_evasion then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.target_is_player then return false end
        if not context.in_melee_range then return false end
        -- Overpower requires Battle Stance
        if context.stance ~= Constants.STANCE.BATTLE then return false end
        -- Only when target has Evasion or Deterrence
        local evasion = Unit(TARGET_UNIT):HasBuffs(A.Evasion.ID) or 0
        local deterrence = Unit(TARGET_UNIT):HasBuffs(A.Deterrence.ID) or 0
        if evasion <= 0 and deterrence <= 0 then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Overpower:IsReady(TARGET_UNIT) then
            return A.Overpower:Show(icon), "[MW] Overpower (vs Evasion)"
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: SHIELD SLAM PURGE (remove magic buffs, Prot talent)
-- ============================================================================
-- Shield Slam dispels 1 magic buff. Useful vs BoP, PW:S, Ice Barrier, etc.
-- Requires a shield equipped (Defensive Stance or equipped in any stance).
rotation_registry:register_middleware({
    name = "Warrior_PvPShieldSlamPurge",
    priority = 61,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_shield_slam_purge then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.target_is_player then return false end
        if not context.in_melee_range then return false end
        -- Target must have a purgeable magic buff
        local has_purge = Unit(TARGET_UNIT):HasBuffs("DeffBuffs") or 0
        if has_purge <= 0 then
            has_purge = Unit(TARGET_UNIT):HasBuffs("ImportantPurje") or 0
            if has_purge <= 0 then return false end
        end
        return true
    end,

    execute = function(icon, context)
        -- Shield Slam requires Defensive Stance for guaranteed use
        if context.stance ~= Constants.STANCE.DEFENSIVE then
            -- Only stance dance if we can afford it
            if is_stance_swap_safe(context.rage, 20) and A.DefensiveStance:IsReady(PLAYER_UNIT) then
                return A.DefensiveStance:Show(icon), "[MW] Defensive Stance (for purge)"
            end
            return nil
        end
        if A.ShieldSlam:IsReady(TARGET_UNIT) then
            return A.ShieldSlam:Show(icon), "[MW] Shield Slam (purge)"
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: INTERVENE (protect a teammate under pressure)
-- ============================================================================
-- Intervene charges to a friendly party/raid member, intercepting the next melee/ranged
-- attack made against them. Requires Defensive Stance + 25yd range.
-- Targets the lowest-HP visible teammate in range.
rotation_registry:register_middleware({
    name = "Warrior_PvPIntervene",
    priority = 59,
    is_defensive = true,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        if not context.settings.pvp_intervene then return false end
        return true
    end,

    execute = function(icon, context)
        -- Find lowest-HP friendly teammate within 25yd (Intervene range)
        local unitID = A.FriendlyTeam(nil):GetUnitID(25)
        if not unitID or unitID == "none" then return nil end

        -- Only intervene if teammate is under pressure (below 50% HP)
        local ally_hp = Unit(unitID):HealthPercent()
        if not ally_hp or ally_hp > 50 then return nil end

        -- Must be in Defensive Stance for Intervene
        if context.stance ~= Constants.STANCE.DEFENSIVE then
            if is_stance_swap_safe(context.rage, 10) and A.DefensiveStance:IsReady(PLAYER_UNIT) then
                return A.DefensiveStance:Show(icon), format("[MW] Defensive Stance (for Intervene) - Ally HP: %.0f%%", ally_hp)
            end
            return nil
        end

        if A.Intervene:IsReady(unitID) then
            return A.Intervene:Show(icon), format("[MW] Intervene - Ally HP: %.0f%%", ally_hp)
        end
        return nil
    end,
})

-- ============================================================================
-- PVP: PERCEPTION (Human racial — detect stealthed enemies)
-- ============================================================================
-- Pop Perception when enemy Rogues/Druids are stealthed in arena.
-- Uses EnemyTeam API to detect invisible units.
rotation_registry:register_middleware({
    name = "Warrior_PvPPerception",
    priority = 57,

    matches = function(context)
        if not context.is_pvp or not context.settings.pvp_enabled then return false end
        -- Only useful in arena (BGs are too chaotic for stealth detection value)
        if not context.is_arena then return false end
        return true
    end,

    execute = function(icon, context)
        if not A.Perception:IsReady(PLAYER_UNIT) then return nil end

        -- Check if any enemy Rogues/Druids are stealthed
        local has_invis = A.EnemyTeam(nil):HasInvisibleUnits(true)
        if not has_invis then return nil end

        return A.Perception:Show(icon), "[MW] Perception (stealth detection)"
    end,
})

-- ============================================================================
-- AUTO CHARGE / INTERCEPT (Gap closer)
-- ============================================================================
-- Suppress Intercept to the SAME target we just Charged to (avoid intercepting mid-flight).
-- Target-aware: tracks the GUID of the Charge target so Intercept to a DIFFERENT mob is allowed.
local UnitGUID = _G.UnitGUID
local last_charge_time = 0
local last_charge_guid = nil
local CHARGE_INTERCEPT_COOLDOWN = 3  -- seconds
local CHARGE_TOTAL_CD = 15           -- Charge base CD in TBC

local function recently_charged_same_target(now)
    local within_window = (now - last_charge_time) < CHARGE_INTERCEPT_COOLDOWN

    -- Addon-triggered Charge: we have a recorded GUID — use target-aware check
    if within_window and last_charge_guid then
        local target_guid = UnitGUID(TARGET_UNIT)
        -- Same target we charged → suppress (still mid-flight / landing)
        if target_guid and target_guid == last_charge_guid then return true end
        -- Different target → allow Intercept immediately
        return false
    end

    -- Fallback: Charge freshly on CD without recorded GUID (manual charge)
    -- Blanket suppress since we can't know which mob was charged
    local charge_cd = A.Charge:GetCooldown() or 0
    if charge_cd > (CHARGE_TOTAL_CD - CHARGE_INTERCEPT_COOLDOWN) then return true end
    return false
end

rotation_registry:register_middleware({
    name = "Warrior_AutoCharge",
    priority = 160,
    -- NOTE: setting_key is NOT auto-checked for middleware (only strategies).
    -- Must check manually in matches().

    matches = function(context)
        if not context.settings.use_auto_charge then return false end
        if context.is_mounted then return false end
        if not context.has_valid_enemy_target then return false end
        -- Don't charge if already in melee range
        if context.in_melee_range then return false end
        return true
    end,

    execute = function(icon, context)
        local now = _G.GetTime()
        -- Charge: Battle Stance, out of combat
        if not context.in_combat then
            -- Need Battle Stance for Charge — swap first if needed
            if context.stance ~= Constants.STANCE.BATTLE and A.BattleStance:IsReady(PLAYER_UNIT) then
                return A.BattleStance:Show(icon), "[MW] Battle Stance (for Charge)"
            end
            if A.Charge:IsReady(TARGET_UNIT) then
                last_charge_time = now
                last_charge_guid = UnitGUID(TARGET_UNIT)
                return A.Charge:Show(icon), "[MW] Charge"
            end
        end
        -- Intercept: Berserker Stance, in combat
        -- Suppress Intercept to same target we just Charged to (travel time + landing)
        if context.in_combat and not recently_charged_same_target(now) then
            -- Need Berserker Stance for Intercept — swap first if needed
            if context.stance ~= Constants.STANCE.BERSERKER then
                -- Check TM: Intercept costs 10 rage, don't swap if we'd lose too much
                if is_stance_swap_safe(context.rage, 10) and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                    return A.BerserkerStance:Show(icon), "[MW] Berserker Stance (for Intercept)"
                end
            end
            if A.Intercept:IsReady(TARGET_UNIT) then
                return A.Intercept:Show(icon), format("[MW] Intercept - Rage: %d", context.rage)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO BANDAGE (Out of combat healing)
-- NOTE: Visual recommendation only. MetaEngine does not pre-allocate secure
-- buttons for bandages, so :Show(icon) displays the icon but cannot auto-use.
-- ============================================================================
rotation_registry:register_middleware({
    name = "Warrior_AutoBandage",
    priority = 50,

    matches = function(context)
        if context.in_combat then return false end
        if not context.settings.use_auto_bandage then return false end
        if context.is_mounted then return false end
        if context.is_moving then return false end
        local threshold = context.settings.bandage_hp or 70
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        local bandage = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil,
            A.HeavyNetherweaveBandage, A.NetherweaveBandage,
            A.HeavyRuneclothBandage, A.RuneclothBandage,
            A.HeavyMageweaveBandage, A.MageweaveBandage,
            A.HeavySilkBandage, A.SilkBandage,
            A.HeavyWoolBandage, A.WoolBandage,
            A.HeavyLinenBandage, A.LinenBandage)
        if bandage then
            return bandage:Show(icon), format("[MW] Bandage - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO TAB TARGET (Smart target switching)
-- ============================================================================
-- Tabs to nearby enemy when current target is dead, missing, or out of range.
-- Picks the lowest HP target and cycles AUTOTARGET until it lands on it.
-- Optional: prioritize executable (<20% HP) targets for Execute kills.
local UnitExists = _G.UnitExists
local UnitIsDead = _G.UnitIsDead
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local UnitName = _G.UnitName

local TAB_MAX_ATTEMPTS = 10

-- Pre-allocated cycling state (no inline tables in combat)
local tab_state = {
    desired_unit = nil,
    attempts = 0,
}

-- Scan nameplates for the lowest HP enemy within melee range
-- Returns unitID, hp (or nil if none found)
local function find_lowest_hp_nearby()
    local plates = MultiUnits:GetActiveUnitPlates()
    if not plates then return nil end

    local best_unit = nil
    local best_hp = 101

    for unitID in pairs(plates) do
        if unitID
            and UnitExists(unitID)
            and not UnitIsDead(unitID)
            and not UnitIsPlayer(unitID)
            and not UnitIsUnit(unitID, TARGET_UNIT)
            and Unit(unitID):CombatTime() > 0
            and A.Rend:IsInRange(unitID) == true
        then
            local hp = Unit(unitID):HealthPercent()
            if hp and hp > 0 and hp < best_hp then
                best_hp = hp
                best_unit = unitID
            end
        end
    end

    return best_unit, best_hp
end

rotation_registry:register_middleware({
    name = "Warrior_AutoTab",
    priority = 55,

    matches = function(context)
        if not context.settings.use_auto_tab then return false end
        -- Protection uses its own threat-aware tab targeting (Prot_ThreatTab strategy)
        if (context.settings.playstyle or "fury") == "protection" then return false end
        if A.IsInPvP then return false end
        if context.is_mounted then return false end
        if not context.in_combat then
            tab_state.desired_unit = nil
            tab_state.attempts = 0
            return false
        end
        -- Grace period: don't override manual targeting in the first 3s of combat
        if context.combat_time < 3 then return false end

        -- Mid-cycle: keep tabbing until we land on desired target
        if tab_state.desired_unit then
            -- Landed on it
            if context.has_valid_enemy_target and UnitIsUnit(TARGET_UNIT, tab_state.desired_unit) then
                tab_state.desired_unit = nil
                tab_state.attempts = 0
                return false
            end
            -- Desired target gone or dead
            if not UnitExists(tab_state.desired_unit) or UnitIsDead(tab_state.desired_unit) then
                tab_state.desired_unit = nil
                tab_state.attempts = 0
                return false
            end
            -- Max attempts reached
            tab_state.attempts = tab_state.attempts + 1
            if tab_state.attempts > TAB_MAX_ATTEMPTS then
                tab_state.desired_unit = nil
                tab_state.attempts = 0
                return false
            end
            return true
        end

        -- Only tab if enemies are nearby (8yd range check)
        if context.enemy_count < 1 then return false end

        -- Tab if no valid target — pick lowest HP nearby
        if not context.has_valid_enemy_target then
            local best = find_lowest_hp_nearby()
            if best then
                tab_state.desired_unit = best
                tab_state.attempts = 0
                return true
            end
            return true -- no nameplates but enemy_count > 0, blind tab
        end

        -- Tab if current target is out of melee range
        if not context.in_melee_range then
            local best = find_lowest_hp_nearby()
            if best then
                tab_state.desired_unit = best
                tab_state.attempts = 0
            end
            return true
        end

        -- Execute-priority tabbing: switch if a nearby mob is executable and current isn't
        if context.settings.auto_tab_execute and context.target_hp >= 20 then
            local best, best_hp = find_lowest_hp_nearby()
            if best and best_hp < 20 then
                tab_state.desired_unit = best
                tab_state.attempts = 0
                return true
            end
        end

        return false
    end,

    execute = function(icon, context)
        local desired = tab_state.desired_unit
        if desired and UnitExists(desired) then
            debug_print(format("[MW] Auto Tab → cycling toward %s (HP: %.0f%%) [attempt %d]",
                UnitName(desired) or "?", Unit(desired):HealthPercent() or 0, tab_state.attempts))
        end
        return A:Show(icon, CONST.AUTOTARGET), "[MW] Auto Tab"
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Warrior]|r Middleware module loaded")
