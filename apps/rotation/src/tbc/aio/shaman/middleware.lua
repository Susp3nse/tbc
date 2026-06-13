-- Shaman Middleware Module
-- Cross-playstyle concerns: interrupt, emergency, recovery, shields, dispels, weapon imbues

local _G = _G
local format = string.format
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "SHAMAN" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Shaman Middleware]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local DetermineUsableObject = A.DetermineUsableObject
local MultiUnits = A.MultiUnits
local CONST = A.Const
local GetTime = _G.GetTime
local UnitGUID = _G.UnitGUID

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- PRIORITY INTERRUPT SPELL LIST (dangerous NPC casts to prioritize interrupting)
-- Scanned on all visible nameplates within 20yds; triggers tab-target interrupt
-- ============================================================================
local PRIORITY_INTERRUPT_SPELLS = {
    -- Damage / AoE
    [31472] = true,  -- Arcane Discharge
    [29973] = true,  -- Arcane Explosion
    [44644] = true,  -- Arcane Nova
    [30616] = true,  -- Blast Nova
    [15305] = true,  -- Chain Lightning
    [45342] = true,  -- Conflagration
    [46605] = true,  -- Darkness of a Thousand Souls
    [31258] = true,  -- Death & Decay
    [45737] = true,  -- Flame Dart
    [30004] = true,  -- Flame Wreath
    [44224] = true,  -- Gravity Lapse
    [15785] = true,  -- Mana Burn
    [38253] = true,  -- Poison Bolt
    [36819] = true,  -- Pyroblast
    [45248] = true,  -- Shadow Blades
    [39005] = true,  -- Shadow Nova
    [39193] = true,  -- Shadow Power
    [46680] = true,  -- Shadow Spike
    [38796] = true,  -- Sonic Boom
    [41426] = true,  -- Spirit Shock
    [29969] = true,  -- Summon Blizzard
    -- Healing
    [41455] = true,  -- Circle of Healing
    [30528] = true,  -- Dark Mending
    [30878] = true,  -- Eternal Affection
    [17843] = true,  -- Flash Heal
    [35096] = true,  -- Greater Heal
    [33144] = true,  -- Heal
    [38330] = true,  -- Healing Wave
    [43451] = true,  -- Holy Light
    [46181] = true,  -- Lesser Healing Wave
    [33152] = true,  -- Prayer of Healing
    [8362]  = true,  -- Renew
    -- Crowd Control / Utility
    [41410] = true,  -- Deaden
    [37135] = true,  -- Domination
    [40184] = true,  -- Paralyzing Screech
    [39096] = true,  -- Polarity Shift
    [13323] = true,  -- Polymorph
    [38815] = true,  -- Sightless Touch
    [32424] = true,  -- Summon Avatar
}

-- Pre-allocated state for multi-frame interrupt target switching
local interrupt_state = {
    phase = "idle",       -- "idle" | "seeking" | "returning"
    original_guid = nil,  -- GUID of target before we started tabbing
    target_guid = nil,    -- GUID of the priority caster we want to interrupt
    spell_name = nil,     -- Name of the priority spell (for logging)
    timeout = 0,          -- GetTime() deadline for current phase
}

local INTERRUPT_SEEK_TIMEOUT = 1.0   -- max seconds to tab toward caster
local INTERRUPT_RETURN_TIMEOUT = 1.0 -- max seconds to tab back to original
local PRIORITY_SCAN_INTERVAL = 0.10
local priority_scan_cache = { time = 0, guid = nil, remaining = 0, spell_name = nil }

-- Scan visible nameplates for units casting a priority interrupt spell within 20yds.
-- Returns the GUID with the longest remaining cast (most time to reach it).
local function find_priority_caster(now)
    now = now or GetTime()
    if (now - priority_scan_cache.time) < PRIORITY_SCAN_INTERVAL then
        return priority_scan_cache.guid, priority_scan_cache.remaining, priority_scan_cache.spell_name
    end

    local plates = MultiUnits:GetActiveUnitPlates()
    local best_guid = nil
    local best_remaining = 0
    local best_spell_name = nil

    if plates then
        for unitID in pairs(plates) do
            local unit = Unit(unitID)
            if unit:GetRange() <= 20 then
                local castLeft, _, spellID, spellName, notKickAble = unit:IsCastingRemains()
                if castLeft and castLeft > 0 and not notKickAble and spellID and PRIORITY_INTERRUPT_SPELLS[spellID] then
                    if castLeft > best_remaining then
                        best_guid = UnitGUID(unitID)
                        best_remaining = castLeft
                        best_spell_name = spellName
                    end
                end
            end
        end
    end

    priority_scan_cache.time = now
    priority_scan_cache.guid = best_guid
    priority_scan_cache.remaining = best_remaining
    priority_scan_cache.spell_name = best_spell_name
    return best_guid, best_remaining, best_spell_name
end

-- ============================================================================
-- EARTH SHOCK INTERRUPT (highest priority — TBC's ONLY shaman interrupt!)
-- Supports: current-target interrupt + priority nameplate scan with tab-targeting
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Interrupt",
    priority = Priority.MIDDLEWARE.FORM_RESHIFT,  -- 500 (highest — TBC's only shaman interrupt)

    matches = function(context)
        -- Reset state when not in combat or interrupt disabled
        if not context.in_combat or not context.settings.use_interrupt then
            interrupt_state.phase = "idle"
            return false
        end

        local phase = interrupt_state.phase
        local now = GetTime()

        -- RETURNING phase: tabbing back to original target
        if phase == "returning" then
            if now > interrupt_state.timeout then
                interrupt_state.phase = "idle"
                return false
            end
            -- No original target to return to (had no target before seeking)
            if not interrupt_state.original_guid then
                interrupt_state.phase = "idle"
                return false
            end
            -- Back on original target — done
            if UnitGUID(TARGET_UNIT) == interrupt_state.original_guid then
                interrupt_state.phase = "idle"
                return false
            end
            return true
        end

        -- SEEKING phase: tabbing toward priority caster
        if phase == "seeking" then
            if now > interrupt_state.timeout then
                -- Gave up seeking → try to return to original
                interrupt_state.phase = "returning"
                interrupt_state.timeout = now + INTERRUPT_RETURN_TIMEOUT
                return true
            end
            return true
        end

        -- IDLE phase: scan for interrupt targets

        -- 1. Priority interrupt scan (nameplates within 20yds for priority spells)
        if context.settings.use_priority_interrupt then
            local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
            if spell:GetCooldown() <= 0 then
                local caster_guid, _, spell_name = find_priority_caster(now)
                if caster_guid then
                    local current_guid = UnitGUID(TARGET_UNIT)
                    if caster_guid == current_guid then
                        -- Priority caster IS current target → interrupt immediately
                        return true
                    end
                    -- Different unit → start seeking
                    interrupt_state.phase = "seeking"
                    interrupt_state.original_guid = current_guid
                    interrupt_state.target_guid = caster_guid
                    interrupt_state.spell_name = spell_name
                    interrupt_state.timeout = now + INTERRUPT_SEEK_TIMEOUT
                    return true
                end
            end
        end

        -- 2. Fallback: interrupt any kickable cast on current target
        if not context.has_valid_enemy_target then return false end
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            return true
        end

        return false
    end,

    execute = function(icon, context)
        local phase = interrupt_state.phase

        -- SEEKING: tab toward caster, or interrupt if we've arrived
        if phase == "seeking" then
            if UnitGUID(TARGET_UNIT) == interrupt_state.target_guid then
                -- Landed on the caster — try to interrupt
                local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
                if castLeft and castLeft > 0 and not notKickAble then
                    local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
                    if spell:IsReady(TARGET_UNIT) then
                        interrupt_state.phase = "returning"
                        interrupt_state.timeout = GetTime() + INTERRUPT_RETURN_TIMEOUT
                        return spell:Show(icon), format("[MW] PRIORITY Interrupt (%s) - %.1fs", interrupt_state.spell_name or "?", castLeft)
                    end
                end
                -- Can't interrupt (stopped casting or not ready) → return to original
                interrupt_state.phase = "returning"
                interrupt_state.timeout = GetTime() + INTERRUPT_RETURN_TIMEOUT
                return A:Show(icon, CONST.AUTOTARGET), "[MW] Interrupt target done, returning"
            end
            -- Not on caster yet → tab
            return A:Show(icon, CONST.AUTOTARGET), format("[MW] Seeking %s caster", interrupt_state.spell_name or "?")
        end

        -- RETURNING: tab back toward original target
        if phase == "returning" then
            return A:Show(icon, CONST.AUTOTARGET), "[MW] Returning to original target"
        end

        -- IDLE: standard interrupt on current target
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
            if spell:IsReady(TARGET_UNIT) then
                return spell:Show(icon), format("[MW] Earth Shock Interrupt - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})

-- ============================================================================
-- HEALTHSTONE (Recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Healthstone",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,  -- 300

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
    name = "Shaman_HealingPotion",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,  -- 295

    matches = function(context)
        if not context.settings.use_healing_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.healing_potion_hp or 25
        if context.hp > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperHealingPotion:IsExists() and A.SuperHealingPotion:IsReady(PLAYER_UNIT) then
            return A.SuperHealingPotion:Show(icon), format("[MW] Super Healing Potion - HP: %.0f%%", context.hp)
        end
        if A.MajorHealingPotion:IsExists() and A.MajorHealingPotion:IsReady(PLAYER_UNIT) then
            return A.MajorHealingPotion:Show(icon), format("[MW] Major Healing Potion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- ============================================================================
-- MANA POTION (Mana recovery)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_ManaPotion",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY,  -- 280

    matches = function(context)
        if not context.settings.use_mana_potion then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.mana_potion_pct or 50
        if context.mana_pct > threshold then return false end
        return true
    end,

    execute = function(icon, context)
        if A.SuperManaPotion:IsExists() and A.SuperManaPotion:IsReady(PLAYER_UNIT) then
            return A.SuperManaPotion:Show(icon), format("[MW] Super Mana Potion - Mana: %.0f%%", context.mana_pct)
        end
        if A.MajorManaPotion:IsExists() and A.MajorManaPotion:IsReady(PLAYER_UNIT) then
            return A.MajorManaPotion:Show(icon), format("[MW] Major Mana Potion - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- DARK/DEMONIC RUNE (Mana recovery — separate CD from potion)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_DarkRune",
    priority = Priority.MIDDLEWARE.MANA_RECOVERY - 5,  -- 275

    matches = function(context)
        if not context.settings.use_dark_rune then return false end
        if not context.in_combat then return false end
        if context.combat_time < 2 then return false end
        local threshold = context.settings.dark_rune_pct or 50
        if context.mana_pct > threshold then return false end
        local min_hp = context.settings.dark_rune_min_hp or 50
        if context.hp < min_hp then return false end
        return true
    end,

    execute = function(icon, context)
        if A.DarkRune:IsExists() and A.DarkRune:IsReady(PLAYER_UNIT) then
            return A.DarkRune:Show(icon), format("[MW] Dark Rune - Mana: %.0f%%", context.mana_pct)
        end
        if A.DemonicRune:IsExists() and A.DemonicRune:IsReady(PLAYER_UNIT) then
            return A.DemonicRune:Show(icon), format("[MW] Demonic Rune - Mana: %.0f%%", context.mana_pct)
        end
        return nil
    end,
})

-- ============================================================================
-- SHIELD MAINTENANCE (Water Shield for Ele/Resto, Lightning Shield for Enh)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_ShieldMaintain",
    priority = 250,

    matches = function(context)
        if context.is_mounted then return false end
        local shield = context.settings.shield_type or "auto"
        local playstyle = context.settings.playstyle or "elemental"

        -- Determine which shield we want
        local want_water
        if shield == "auto" then
            want_water = (playstyle ~= "enhancement")
        elseif shield == "water" then
            want_water = true
        else
            want_water = false
        end

        if want_water then
            -- Refresh if missing or charges low (1 or fewer)
            if not context.has_water_shield or context.water_shield_charges <= 1 then
                return true
            end
        else
            if not context.has_lightning_shield then
                return true
            end
        end

        return false
    end,

    execute = function(icon, context)
        local shield = context.settings.shield_type or "auto"
        local playstyle = context.settings.playstyle or "elemental"

        local want_water
        if shield == "auto" then
            want_water = (playstyle ~= "enhancement")
        elseif shield == "water" then
            want_water = true
        else
            want_water = false
        end

        if want_water then
            if A.WaterShield:IsReady(PLAYER_UNIT) then
                return A.WaterShield:Show(icon), format("[MW] Water Shield - Charges: %d", context.water_shield_charges)
            end
        else
            if A.LightningShield:IsReady(PLAYER_UNIT) then
                return A.LightningShield:Show(icon), "[MW] Lightning Shield"
            end
        end

        return nil
    end,
})

-- ============================================================================
-- CURE POISON (Self-dispel)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_CurePoison",
    priority = 350,

    matches = function(context)
        if not context.settings.use_cure_poison then return false end
        if context.is_mounted then return false end
        local hasPoison = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Poison")
        if not hasPoison then return false end
        return true
    end,

    execute = function(icon, context)
        if A.CurePoison:IsReady(PLAYER_UNIT) then
            return A.CurePoison:Show(icon), "[MW] Cure Poison"
        end
        return nil
    end,
})

-- ============================================================================
-- CURE DISEASE (Self-dispel)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_CureDisease",
    priority = 340,

    matches = function(context)
        if not context.settings.use_cure_disease then return false end
        if context.is_mounted then return false end
        local hasDisease = A.AuraIsValid(PLAYER_UNIT, "UseDispel", "Disease")
        if not hasDisease then return false end
        return true
    end,

    execute = function(icon, context)
        if A.CureDisease:IsReady(PLAYER_UNIT) then
            return A.CureDisease:Show(icon), "[MW] Cure Disease"
        end
        return nil
    end,
})

-- ============================================================================
-- PURGE (Remove enemy buffs)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_Purge",
    priority = 200,

    matches = function(context)
        if not context.settings.use_purge then return false end
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        local hasStealable = A.AuraIsValid(TARGET_UNIT, "UseExpelEnrage", "Magic")
        if not hasStealable then return false end
        return true
    end,

    execute = function(icon, context)
        if A.Purge:IsReady(TARGET_UNIT) then
            return A.Purge:Show(icon), "[MW] Purge"
        end
        return nil
    end,
})

-- ============================================================================
-- WEAPON IMBUES (Out of combat — Enhancement only)
-- ============================================================================
rotation_registry:register_middleware({
    name = "Shaman_WeaponImbues",
    priority = Priority.MIDDLEWARE.SELF_BUFF_OOC,  -- 140

    matches = function(context)
        if context.in_combat then return false end
        if context.is_mounted then return false end
        local playstyle = context.settings.playstyle or "elemental"
        if playstyle ~= "enhancement" and playstyle ~= "elemental" then return false end
        local hasMH, _, _, _, hasOH = _G.GetWeaponEnchantInfo()
        if playstyle == "enhancement" then
            if not hasMH or not hasOH then return true end
        else
            -- Ele: MH only
            if not hasMH then return true end
        end
        return false
    end,

    execute = function(icon, context)
        local playstyle = context.settings.playstyle or "elemental"
        local hasMH, _, _, _, hasOH = _G.GetWeaponEnchantInfo()
        if playstyle == "enhancement" then
            local mh_imbue = context.settings.enh_mh_imbue or "windfury"
            local oh_imbue = context.settings.enh_oh_imbue or "flametongue"
            -- MH imbue
            if not hasMH then
                local mh_spell = (mh_imbue == "windfury") and A.WindfuryWeapon or A.FlametongueWeapon
                if mh_spell:IsReady(PLAYER_UNIT) then
                    return mh_spell:Show(icon), format("[MW] %s (MH)", mh_imbue == "windfury" and "Windfury" or "Flametongue")
                end
            end
            -- OH imbue
            if not hasOH then
                local oh_spell = (oh_imbue == "windfury") and A.WindfuryWeapon or A.FlametongueWeapon
                if oh_spell:IsReady(PLAYER_UNIT) then
                    return oh_spell:Show(icon), format("[MW] %s (OH)", oh_imbue == "windfury" and "Windfury" or "Flametongue")
                end
            end
        else
            -- Ele: MH Flametongue only (caster weapon)
            if not hasMH and A.FlametongueWeapon:IsReady(PLAYER_UNIT) then
                return A.FlametongueWeapon:Show(icon), "[MW] Flametongue Weapon (MH)"
            end
        end
        return nil
    end,
})

-- ============================================================================
-- AUTO TREMOR TOTEM (Fear/Charm/Sleep protection)
-- ============================================================================
-- TBC NPC IDs that cast Fear, Charm, or Sleep effects
local FEAR_CASTER_IDS = {
    -- Raids
    [17225] = true,  -- Nightbane (Karazhan) — Bellowing Roar
    [17968] = true,  -- Archimonde (Hyjal) — Fear
    [17808] = true,  -- Anetheron (Hyjal) — Carrion Swarm (sleep)
    [22855] = true,  -- Illidari Nightlord (BT) — Fear (AoE)
    [23420] = true,  -- Essence of Anger (BT RoS) — Seethe
    -- Dungeon bosses
    [18731] = true,  -- Ambassador Hellmaw (Shadow Lab) — Fear (45yd AoE)
    [18667] = true,  -- Blackheart the Inciter (Shadow Lab) — Incite Chaos (charm)
    [17308] = true,  -- Omor the Unscarred (Ramparts) — Fear
    [17536] = true,  -- Nazan (Ramparts) — Bellowing Roar
    [16807] = true,  -- Grand Warlock Nethekurse (Shattered Halls) — Death Coil
    -- Trash
    [20883] = true,  -- Coilfang Fathom-Witch (SSC) — Domination (charm)
    [21956] = true,  -- Bonechewer Taskmaster (BT) — Fear
    [22960] = true,  -- Ashtongue Primalist (BT) — Wyvern Sting (sleep)
}

local GetTotemInfo = _G.GetTotemInfo

rotation_registry:register_middleware({
    name = "Shaman_AutoTremor",
    priority = 260,  -- above shield maintain (250), below recovery (300)
    setting_key = "use_auto_tremor",

    matches = function(context)
        if not context.settings.use_auto_tremor then return false end
        if not context.in_combat then return false end
        if not context.has_valid_enemy_target then return false end
        -- Check target NPC ID against fear caster list
        local npc_id = select(6, Unit(TARGET_UNIT):InfoGUID())
        if not npc_id or not FEAR_CASTER_IDS[tonumber(npc_id)] then return false end
        -- Fear caster targeted — check if Tremor is already active in earth slot
        local have, name = GetTotemInfo(2)
        if have and name and name:find("Tremor") and context.totem_earth_remaining > 5 then
            return false  -- tremor already active with good duration
        end
        return true
    end,

    execute = function(icon, context)
        if A.TremorTotem:IsReady(PLAYER_UNIT) then
            return A.TremorTotem:Show(icon), "[MW] Tremor Totem (fear boss)"
        end
        return nil
    end,
})

-- Shared trinket middleware (burst + defensive, schema-driven)
NS.register_trinket_middleware()

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Flux AIO Shaman]|r Middleware module loaded")
