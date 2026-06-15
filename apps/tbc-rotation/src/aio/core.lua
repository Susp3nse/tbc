-- Menagerie - Core Module
-- Generic rotation engine: namespace, settings, utilities, registry
-- Class-agnostic: class files register via rotation_registry:register_class()

-- ============================================================================
-- FRAMEWORK VALIDATION
-- ============================================================================
local _G, pairs, ipairs, tostring = _G, pairs, ipairs, tostring
local tinsert, tsort = table.insert, table.sort
local floor = math.floor
local format = string.format
local GetTime = _G.GetTime
local A = _G.Action

if not A then
   print("|cFFFF0000[Menagerie]|r Action/Textfiles framework not loaded!")
   return
end

local function compat_get_spell_info(spell)
   if _G.GetSpellInfo then
      return _G.GetSpellInfo(spell)
   end
   if _G.C_Spell and _G.C_Spell.GetSpellInfo then
      local info = _G.C_Spell.GetSpellInfo(spell)
      if info then
         return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID
      end
   end
end

if not A.GetSpellInfo then
   A.GetSpellInfo = compat_get_spell_info
end
if not _G.GetSpellInfo then
   _G.GetSpellInfo = compat_get_spell_info
end

if not A.Data.ProfileEnabled[A.CurrentProfile] then
   print("|cFFFF0000[Menagerie]|r WARNING: ProfileEnabled is not set!")
   print("|cFFFF0000[Menagerie]|r Did you install the schema snippet first?")
   return
end

-- ============================================================================
-- GLOBAL NAMESPACE CREATION
-- ============================================================================
_G.Menagerie = _G.Menagerie or {}
local NS = _G.Menagerie

-- Base framework references (available before class Actions are defined)
local Player = A.Player
local Unit = A.Unit
local function GetToggle(...)
   if A.GetToggle then
      return A.GetToggle(...)
   end
   return nil
end

NS.Player = Player
NS.Unit = Unit
NS.GetToggle = GetToggle
NS.SetToggle = function(...)
   if A.SetToggle then
      return A.SetToggle(...)
   end
   return nil
end
local SetToggle = NS.SetToggle

-- Stub: overridden by dashboard.lua with real implementation
if not NS.set_last_action then
    NS.set_last_action = function() end
end

-- ============================================================================
-- UNIT CONSTANTS
-- ============================================================================
local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"
local RACE_TROLL = "Troll"
local RACE_ORC = "Orc"

NS.PLAYER_UNIT = PLAYER_UNIT
NS.TARGET_UNIT = TARGET_UNIT
NS.RACE_TROLL = RACE_TROLL
NS.RACE_ORC = RACE_ORC

-- The version is a single platform-wide value injected at build time (NS.VERSION, from the app's
-- package.json) — no longer per-class. The class_config arg is accepted for caller compatibility
-- but ignored.
local function format_class_version()
   return NS.VERSION or "v0.0.0"
end

NS.format_class_version = format_class_version

-- ============================================================================
-- FORCE COMMAND FLAGS (set by /menagerie slash commands)
-- ============================================================================
-- Values are expiry timestamps (GetTime() + duration). Zero = inactive.
-- Checked each frame by execute_middleware/execute_strategies in main.lua.
NS.force_burst = 0
NS.force_defensive = 0
NS.force_gap = 0
NS.force_raptor = 0

local FORCE_DURATION = 3.0

local function set_force_flag(flag_name)
   NS[flag_name] = GetTime() + FORCE_DURATION
end

local function is_force_active(flag_name)
   local expiry = NS[flag_name]
   return expiry > 0 and GetTime() < expiry
end

local function clear_force_flag(flag_name)
   NS[flag_name] = 0
end

NS.set_force_flag = set_force_flag
NS.is_force_active = is_force_active
NS.clear_force_flag = clear_force_flag

-- ============================================================================
-- CENTER-SCREEN NOTIFICATION
-- ============================================================================
-- Pre-allocated frame for brief center-screen text notifications.
-- Usage: NS.show_notification("text", duration_seconds, {r, g, b})
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

local notif_frame = CreateFrame("Frame", "MenagerieNotification", UIParent)
notif_frame:SetSize(300, 40)
notif_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
notif_frame:SetFrameStrata("HIGH")

local notif_text = notif_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notif_text:SetPoint("CENTER")
notif_text:SetFont(notif_text:GetFont() or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

local notif_fade_duration = 0.4
local notif_visible_until = 0

notif_frame:SetScript("OnUpdate", function(self, elapsed)
   local now = GetTime()
   if now < notif_visible_until then
      notif_text:SetAlpha(1)
   elseif now < notif_visible_until + notif_fade_duration then
      local progress = (now - notif_visible_until) / notif_fade_duration
      notif_text:SetAlpha(1 - progress)
   else
      notif_text:SetAlpha(0)
      self:Hide()
   end
end)
notif_frame:Hide()

local function show_notification(text, duration, color)
   duration = duration or 1.5
   local r, g, b = 1, 1, 1
   if color then r, g, b = color[1], color[2], color[3] end
   notif_text:SetText(text)
   notif_text:SetTextColor(r, g, b, 1)
   notif_visible_until = GetTime() + duration
   notif_frame:Show()
end

NS.show_notification = show_notification

-- ============================================================================
-- PRIORITY REGISTRY (Middleware Only)
-- Higher number = runs FIRST (descending order)
-- ============================================================================
local Priority = {
   MIDDLEWARE = {
      FORM_RESHIFT = 500,
      EMERGENCY_HEAL = 400,
      PROACTIVE_HEAL = 390,
      DISPEL_CURSE = 350,
      DISPEL_POISON = 340,
      RECOVERY_ITEMS = 300,
      INNERVATE = 290,
      MANA_RECOVERY = 280,
      SELF_BUFF_MOTW = 150,
      SELF_BUFF_THORNS = 145,
      SELF_BUFF_OOC = 140,
      OFFENSIVE_COOLDOWNS = 100,
   },
}

NS.Priority = Priority

-- ============================================================================
-- SPELL COST UTILITIES
-- ============================================================================
-- TBC power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy
local function get_spell_mana_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 0) and cost or 0
end

local function get_spell_rage_cost(spell)
   local cost, power_type = spell:GetSpellPowerCost()
   return (cost and cost > 0 and power_type == 1) and cost or 0
end

NS.get_spell_mana_cost = get_spell_mana_cost
NS.get_spell_rage_cost = get_spell_rage_cost

-- TTD gate: true when target will die sooner than the user's cd_min_ttd setting
-- (so callers can skip major CDs on dying mobs). 0 = disabled.
local function ttd_too_short(context)
   local min_ttd = context.settings.cd_min_ttd or 0
   return min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd
end

NS.ttd_too_short = ttd_too_short

-- ============================================================================
-- IMMUNITY SPELL IDS (from LibAuraTypes.lua TBC section)
-- ============================================================================
local IMMUNITY_TOTAL = { 642, 1020, 45438, 11958, 33786, 710, 18647 }
local IMMUNITY_PHYS = { 1022, 5599, 10278, 3169 }
local IMMUNITY_MAGIC = { 31224, 8178 }
local IMMUNITY_CC = { 19574, 34471, 18499, 1719, 31224, 6346 }
local IMMUNITY_STUN = { 19574, 34471, 18499, 6615, 24364 }
local IMMUNITY_KICK = { 31224 }

local function has_immunity_buff(target, buff_ids)
   if not target or not _G.UnitExists(target) then return false end
   local duration = Unit(target):HasBuffs(buff_ids, nil, true) or 0
   return duration > 0
end

local has_total_immunity

local function has_phys_immunity(target)
   target = target or TARGET_UNIT
   return has_immunity_buff(target, IMMUNITY_PHYS) or has_total_immunity(target)
end

local function has_magic_immunity(target)
   target = target or TARGET_UNIT
   return has_immunity_buff(target, IMMUNITY_MAGIC) or has_total_immunity(target)
end

local function has_cc_immunity(target)
   target = target or TARGET_UNIT
   return has_immunity_buff(target, IMMUNITY_CC) or has_total_immunity(target)
end

local function has_stun_immunity(target)
   target = target or TARGET_UNIT
   return has_immunity_buff(target, IMMUNITY_STUN) or has_total_immunity(target)
end

local function has_kick_immunity(target)
   target = target or TARGET_UNIT
   return has_immunity_buff(target, IMMUNITY_KICK) or has_total_immunity(target)
end

function has_total_immunity(target)
   return has_immunity_buff(target or TARGET_UNIT, IMMUNITY_TOTAL)
end

local REFLECT_BUFF_IDS = {
   23920, -- Spell Reflection (Warrior)
   31533, -- Spell Reflection (NPC, 50%)
   31534, -- Spell Reflection (NPC, 1%)
   33719, -- Perfect Spell Reflection
   35158, -- Reflective Magic Shield
   38592, -- Spell Reflection (NPC, 100%)
}

local function has_spell_reflect(target)
   target = target or TARGET_UNIT
   return (Unit(target):HasBuffs("Reflect") or 0) > 0
      or (Unit(target):HasBuffs(REFLECT_BUFF_IDS, nil, true) or 0) > 0
end

NS.has_phys_immunity = has_phys_immunity
NS.has_magic_immunity = has_magic_immunity
NS.has_cc_immunity = has_cc_immunity
NS.has_stun_immunity = has_stun_immunity
NS.has_kick_immunity = has_kick_immunity
NS.has_total_immunity = has_total_immunity
NS.has_spell_reflect = has_spell_reflect

-- ============================================================================
-- SCHOOL-IMMUNE NPC TABLES (npcID → true)
-- Used by callers to skip school-locked spells against immune mobs.
-- Query npcID via: select(6, Unit(unit):InfoGUID())
-- ============================================================================
NS.ARCANE_IMMUNE = {
   [15691] = true,  -- The Curator (Karazhan)
   [17096] = true,  -- Astral Flare (Curator add)
   [18864] = true,  -- Mana Wraith (Karazhan trash)
   [18865] = true,  -- Warp Aberration (Karazhan trash)
   [20478] = true,  -- Arcane Servant
}

-- ============================================================================
-- SETTINGS SYSTEM
-- ============================================================================
local cached_settings = {}
local settings_changed_list = {}
local settings_dirty = true
local settings_list = {}

NS.cached_settings = cached_settings

local function update_setting(key, value, changed_list, debug_mode)
   local old_value = cached_settings[key]
   cached_settings[key] = value

   if debug_mode and old_value ~= nil and old_value ~= value then
      changed_list[#changed_list + 1] = key .. ": " .. tostring(old_value) .. " -> " .. tostring(value)
   end
end

-- ============================================================================
-- LEARNED SPELL IMMUNITY (observed from the combat log)
-- ----------------------------------------------------------------------------
-- The aura checks above and the ARCANE_IMMUNE seed tables below are PREDICTIVE:
-- they catch immunity we can see or already know. This layer is REACTIVE: when
-- the game reports OUR OWN "SPELL_MISSED ... IMMUNE", we cache it so the rotation
-- stops re-casting a spell a creature has already proven immune to.
--   * Keyed by npcID (creature template), NOT GUID -- so the whole pack and every
--     future spawn of that creature share one lesson (no relearning per mob), and
--     memory stays tiny (creature-types, not spawns).
--   * Keyed by spellID, NOT school -- Faerie Fire immunity (an armor-debuff
--     immunity that happens to be Arcane) must never mute Moonfire/Starfire.
-- Lifetime is the "immune_learn_ttl_min" setting (minutes); entries lazily expire.
-- ============================================================================
local DEFAULT_IMMUNE_TTL_MIN = 5
local learned_immune = {} -- [npcID] = { [spellID] = expiry }

local function npc_id_from_guid(guid)
   -- Field 6 of a "Creature-…"/"Vehicle-…" GUID is the npcID. Player GUIDs have no
   -- 6th field, so this returns nil for them -- PvP immunity stays aura-only.
   if not guid then return nil end
   return tonumber((select(6, _G.strsplit("-", guid))))
end

local function mark_spell_immune(npc_id, spell_id)
   if not npc_id or not spell_id then return end
   local ttl_min = cached_settings.immune_learn_ttl_min or DEFAULT_IMMUNE_TTL_MIN
   local bucket = learned_immune[npc_id]
   if not bucket then
      bucket = {}
      learned_immune[npc_id] = bucket
   end
   bucket[spell_id] = GetTime() + ttl_min * 60
end

-- spell_ids: a single spellID, or an array of ranks (returns true if ANY is immune).
local function is_spell_immune(unit, spell_ids)
   local npc_id = npc_id_from_guid(_G.UnitGUID(unit or TARGET_UNIT))
   if not npc_id then return false end
   local bucket = learned_immune[npc_id]
   if not bucket then return false end
   local now = GetTime()
   if type(spell_ids) == "table" then
      for i = 1, #spell_ids do
         local id = spell_ids[i]
         local expiry = bucket[id]
         if expiry then
            if now < expiry then return true end
            bucket[id] = nil -- lazy prune
         end
      end
      if next(bucket) == nil then learned_immune[npc_id] = nil end
      return false
   end
   local expiry = bucket[spell_ids]
   if not expiry then return false end
   if now >= expiry then
      bucket[spell_ids] = nil -- lazy prune
      if next(bucket) == nil then learned_immune[npc_id] = nil end
      return false
   end
   return true
end

NS.mark_spell_immune = mark_spell_immune
NS.is_spell_immune = is_spell_immune

local immune_learn_frame = _G.CreateFrame("Frame")
immune_learn_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
immune_learn_frame:SetScript("OnEvent", function()
   local _, event, _, srcGUID, _, _, _, destGUID, _, _, _, spellID, _, _, missType = _G.CombatLogGetCurrentEventInfo()
   if event ~= "SPELL_MISSED" or missType ~= "IMMUNE" then return end
   if srcGUID ~= _G.UnitGUID(PLAYER_UNIT) then return end
   -- Only learn about the unit we are actually TARGETING. An AoE that clips an
   -- immune off-target mob reports THAT mob's GUID (not the target's), but we have
   -- no unit token to tell its intrinsic immunity from a transient aura, so we skip
   -- it. Single-target spells -- the ones worth not re-casting -- always land on
   -- the target, so nothing of value is lost and the aura guard below always runs.
   if destGUID ~= _G.UnitGUID(TARGET_UNIT) then return end
   -- Don't learn TRANSIENT immunity (Banish, Ice Block, Divine Shield, boss
   -- damage-immunity phases) as if it were intrinsic -- that is the aura layer's job.
   if has_total_immunity(TARGET_UNIT) then return end
   mark_spell_immune(npc_id_from_guid(destGUID), spellID)
end)

-- ============================================================================
-- SPELL VALIDATION SYSTEM
-- ============================================================================
local unavailable_spells = {}

NS.unavailable_spells = unavailable_spells

local function is_spell_known(spell)
   if not spell then return false, "nil" end
   local spell_id = spell.ID
   if not spell_id then return false, "no ID" end
   local spell_name = _G.GetSpellInfo(spell_id)
   if not spell_name then return false, "ID:" .. tostring(spell_id) end
   if _G.IsSpellKnown and _G.IsSpellKnown(spell_id) then
      return true, spell_name
   end
   -- IsSpellKnown may miss talent-granted spells; fall through to framework check
   return spell:IsExists() == true, spell_name
end

local function check_spell_availability(entries, missing_spells, optional_missing)
   for _, entry in ipairs(entries) do
      local known = is_spell_known(entry.spell)
      if not known then
         if entry.spell then
            unavailable_spells[entry.spell] = true
         end
         if entry.required then
            tinsert(missing_spells, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
         else
            tinsert(optional_missing, entry.name .. (entry.note and " (" .. entry.note .. ")" or ""))
         end
      else
         if entry.spell then
            unavailable_spells[entry.spell] = nil
         end
      end
   end
end

local function is_spell_available(spell)
   if not spell then return false end
   return not unavailable_spells[spell]
end

NS.is_spell_known = is_spell_known
NS.check_spell_availability = check_spell_availability
NS.is_spell_available = is_spell_available

-- ============================================================================
-- REFRESH SETTINGS (schema-driven)
-- ============================================================================
local SETTINGS_SCHEMA = _G.Menagerie_SETTINGS_SCHEMA

local function build_settings_list()
   for i = 1, #settings_list do settings_list[i] = nil end
   if not SETTINGS_SCHEMA then return end
   for _, tab_def in ipairs(SETTINGS_SCHEMA) do
      if tab_def.sections then
         for _, section in ipairs(tab_def.sections) do
            if section.settings then
               for _, s in ipairs(section.settings) do
                  settings_list[#settings_list + 1] = s
               end
            end
         end
      end
   end
end

build_settings_list()

local RECOVERY_KEY_MIGRATIONS = {
   { class = "HUNTER", old = "use_mana_rune", new = "use_dark_rune" },
   { class = "HUNTER", old = "mana_rune_mana", new = "dark_rune_pct" },
   { class = "DRUID", old = "mana_potion_mana", new = "mana_potion_pct" },
   { class = "DRUID", old = "dark_rune_mana", new = "dark_rune_pct" },
}

local function migrate_recovery_keys()
   local player_class = A.PlayerClass
   for _, migration in ipairs(RECOVERY_KEY_MIGRATIONS) do
      if migration.class == player_class then
         local v = GetToggle(2, migration.old)
         if v ~= nil then
            if GetToggle(2, migration.new) == nil then
               SetToggle({ 2, migration.new, nil, true }, v)
            end
            SetToggle({ 2, migration.old, nil, true }, nil)
         end
      end
   end
end

migrate_recovery_keys()

local function mark_settings_dirty()
   settings_dirty = true
   NS.settings_dirty = true
end

NS.mark_settings_dirty = mark_settings_dirty
NS.settings_dirty = settings_dirty

local function refresh_settings(force)
   if not force and not settings_dirty then return end
   if #settings_list == 0 then build_settings_list() end

   local now = GetTime()
   local debug_mode = GetToggle(2, "debug_mode")
   local changed_list = settings_changed_list
   for i = 1, #changed_list do changed_list[i] = nil end

   for _, s in ipairs(settings_list) do
      local raw = GetToggle(2, s.key)
      local value
      if s.type == "checkbox" then
         if s.default == true then
            value = raw ~= false
         else
            value = raw == true
         end
      else
         value = raw or s.default
      end
      update_setting(s.key, value, changed_list, debug_mode)
   end

   if debug_mode and #changed_list > 0 then
      print("|cFF00FFFF[Menagerie]|r Settings changed at " .. format("%.1f", now))
      for _, change in ipairs(changed_list) do
         print("|cFF00FFFF[Menagerie]|r   " .. change)
      end
   end

   settings_dirty = false
   NS.settings_dirty = false
end

NS.refresh_settings = refresh_settings

-- ============================================================================
-- GENERIC UTILITIES
-- ============================================================================
local function round_half(num)
   if not num then return 0 end
   return floor(num * 2 + 0.5) / 2
end

local function safe_ability_cast(ability, icon, target, debug_context)
   if unavailable_spells[ability] then return nil end
   if not ability:IsReady(target) then return nil end
   local result = ability:Show(icon)
   if result then NS.last_action_target_unit = target end
   return result
end

-- Pre-allocated Click table for self-targeting (safe for combat use)
local self_target_click = { unit = "player" }
local heal_target_click = { unit = "player" }

local function safe_self_cast(ability, icon, _target)
   if unavailable_spells[ability] then return nil end
   if not ability:IsReady("player") then return nil end
   ability.Click = self_target_click
   local result = ability:Show(icon)
   if result then NS.last_action_target_unit = PLAYER_UNIT end
   return result
end

local function safe_heal_cast(ability, icon, target_unit, log_message)
   if unavailable_spells[ability] then return nil end
   if not target_unit or not _G.UnitExists(target_unit) or _G.UnitIsDead(target_unit) or not _G.UnitCanAssist(PLAYER_UNIT, target_unit) then return nil end
   -- IsReady(target_unit) fails for party/raid unit IDs — check on "player" instead.
   if not ability:IsReady("player") then return nil end
   -- Tell HE which unit to target. TMW reads HE.GetTarget() when Show() is called
   -- to inject [@unit,help] into the icon macro.
   local HE = A.HealingEngine
   if HE and HE.SetTarget then HE.SetTarget(target_unit) end
   heal_target_click.unit = target_unit
   ability.Click = heal_target_click
   local result = ability:Show(icon)
   if result then NS.last_action_target_unit = target_unit end
   if result then return result, log_message end
   return nil
end

NS.round_half = round_half
NS.safe_ability_cast = safe_ability_cast
NS.safe_self_cast = safe_self_cast
NS.safe_heal_cast = safe_heal_cast

-- ============================================================================
-- CASTING HELPERS
-- ============================================================================
local function try_cast(spell, icon, target, log_message)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(target) then return nil end
   local result = safe_ability_cast(spell, icon, target)
   if result then return result, log_message end
   return nil
end

local function try_cast_fmt(spell, icon, target, prefix, name, info_fmt, ...)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(target) then return nil end
   local result = safe_ability_cast(spell, icon, target)
   if result then
      if info_fmt then
         return result, format("%s %s - " .. info_fmt, prefix, name, ...)
      end
      return result, format("%s %s", prefix, name)
   end
   return nil
end

NS.try_cast = try_cast
NS.try_cast_fmt = try_cast_fmt

-- Healing variants: IsReady("player") + HE.SetTarget for party/raid targeting.
-- scan_healing_targets() already handles range, so "player" check (CD + mana) is sufficient.
local function try_heal_cast(spell, icon, target_unit, log_message)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(PLAYER_UNIT) then return nil end
   local result = safe_heal_cast(spell, icon, target_unit)
   if result then return result, log_message end
   return nil
end

local function try_heal_cast_fmt(spell, icon, target_unit, prefix, name, info_fmt, ...)
   if not is_spell_available(spell) then return nil end
   if not spell:IsReady(PLAYER_UNIT) then return nil end
   local result = safe_heal_cast(spell, icon, target_unit)
   if result then
      if info_fmt then
         return result, format("%s %s - " .. info_fmt, prefix, name, ...)
      end
      return result, format("%s %s", prefix, name)
   end
   return nil
end

NS.try_heal_cast = try_heal_cast
NS.try_heal_cast_fmt = try_heal_cast_fmt

-- ============================================================================
-- HEAL PREDICTION
-- Estimates effective health deficit accounting for incoming heals, HoTs,
-- absorbs, and incoming damage over a cast-time window.
-- Uses LibHealComm/framework APIs: GetIncomingHeals, GetHEAL, GetDMG, GetAbsorb.
-- ============================================================================
local function predict_effective_deficit(unitID, castTime)
   castTime = castTime or 1.5
   local deficit = Unit(unitID):HealthDeficit() or 0
   if deficit <= 0 then return 0 end

   local inc_heal = Unit(unitID):GetIncomingHeals(castTime) or 0
   local hot_hps = Unit(unitID):GetHEAL() or 0
   local hot_heal = hot_hps * castTime
   local absorb = Unit(unitID):GetAbsorb() or 0
   local inc_dmg_dps = Unit(unitID):GetDMG() or 0
   local inc_dmg = inc_dmg_dps * castTime

   local effective = deficit - inc_heal - hot_heal - absorb + inc_dmg
   return effective > 0 and effective or 0
end

NS.predict_effective_deficit = predict_effective_deficit

-- ============================================================================
-- GROUP / HEALING SCANNERS
-- ============================================================================
local PARTY_UNITS = { "player", "party1", "party2", "party3", "party4" }
local RAID_UNITS = {}
for i = 1, 40 do RAID_UNITS[i] = "raid" .. i end

local EMPTY_SCAN_OPTIONS = {}
local core_healing_targets = {}
for i = 1, 40 do core_healing_targets[i] = {} end

local function unit_has_aggro(unit_id)
   local threat = _G.UnitThreatSituation(unit_id)
   return threat and threat >= 2
end

local function is_in_raid()
   return _G.IsInRaid and _G.IsInRaid() or false
end

local function is_in_party()
   if is_in_raid() then return false end
   return _G.IsInGroup and _G.IsInGroup() or false
end

local function unit_passes_range(unit, options)
   if _G.UnitIsUnit(unit, PLAYER_UNIT) then return true end
   if options.range_spell then
      local spell_range = _G.IsSpellInRange(options.range_spell, unit)
      if spell_range == 1 then return true end
      if spell_range == 0 then return false end
   end
   if options.range_yd then
      local max_range = Unit(unit):GetRange()
      return max_range and max_range <= options.range_yd
   end
   local _, unit_in_range = _G.UnitInRange(unit)
   return unit_in_range == true
end

local function healing_hp_asc(a, b)
   if not a or not a.effective_hp then return false end
   if not b or not b.effective_hp then return true end
   return a.effective_hp < b.effective_hp
end

local function scan_group(out, options)
   options = options or EMPTY_SCAN_OPTIONS
   local count = 0
   local in_raid = is_in_raid()
   local units_to_scan = in_raid and RAID_UNITS or PARTY_UNITS
   local max_units = in_raid and 40 or 5

   for i = 1, max_units do
      local unit = units_to_scan[i]
      if unit
         and (options.include_player ~= false or not _G.UnitIsUnit(unit, PLAYER_UNIT))
         and _G.UnitExists(unit)
         and not _G.UnitIsDead(unit)
         and _G.UnitIsConnected(unit)
         and _G.UnitCanAssist(PLAYER_UNIT, unit)
         and unit_passes_range(unit, options)
         and (not options.predicate or options.predicate(unit, options.context))
      then
         count = count + 1
         local entry = out[count]
         if not entry then
            entry = {}
            out[count] = entry
         end
         entry.unit = unit
      end
   end

   return count
end

local function scan_healing_targets(context, options)
   options = options or EMPTY_SCAN_OPTIONS
   options.context = context
   local out = options.out or core_healing_targets
   local count = scan_group(out, options)

   for i = 1, count do
      local entry = out[i]
      local unit = entry.unit
      local max_hp = _G.UnitHealthMax(unit) or 0
      local hp = _G.UnitHealth(unit) or 0
      entry.hp = max_hp > 0 and hp / max_hp * 100 or 0
      entry.is_player = _G.UnitIsUnit(unit, PLAYER_UNIT)
      entry.has_aggro = unit_has_aggro(unit)
      entry.deficit = max_hp - hp
      entry.incoming_dps = Unit(unit):GetDMG() or 0

      local eff_deficit = predict_effective_deficit(unit, options.cast_time or 1.5)
      entry.effective_hp = max_hp > 0 and (100 - (eff_deficit / max_hp) * 100) or entry.hp

      local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit)
      entry.is_tank = entry.has_aggro or role == "TANK"

      if options.decorate_entry then
         options.decorate_entry(entry, unit, context)
      end
   end

   for i = count + 1, #out do
      if out[i] then
         out[i].unit = nil
         out[i].effective_hp = 999
      end
   end

   if count > 1 then tsort(out, healing_hp_asc) end
   options.context = nil
   return out, count
end

local function get_lowest_hp_target(threshold)
   threshold = threshold or 100
   local entries, count = scan_healing_targets(nil, EMPTY_SCAN_OPTIONS)
   for i = 1, count do
      local entry = entries[i]
      if entry and entry.effective_hp < threshold then return entry.unit end
   end
   return nil
end

NS.PARTY_UNITS = PARTY_UNITS
NS.RAID_UNITS = RAID_UNITS
NS.unit_has_aggro = unit_has_aggro
NS.is_in_raid = is_in_raid
NS.is_in_party = is_in_party
NS.scan_group = scan_group
NS.scan_healing_targets = scan_healing_targets
NS.get_lowest_hp_target = get_lowest_hp_target

-- ============================================================================
-- DEBUFF/BUFF HELPERS
-- ============================================================================
local function is_debuff_active(spell, target, source)
   if not _G.UnitExists(target) then return false end
   return (Unit(target):HasDeBuffs(spell.ID, source) or 0) > 0
end

local function get_debuff_state(spell, target, source)
   if not _G.UnitExists(target) then return 0, 0 end
   return Unit(target):HasDeBuffsStacks(spell.ID, source) or 0,
          Unit(target):HasDeBuffs(spell.ID, source) or 0
end

local function is_buff_active(spell, target, source)
   if not _G.UnitExists(target) then return false end
   return (Unit(target):HasBuffs(spell.ID, source) or 0) > 0
end

NS.is_debuff_active = is_debuff_active
NS.get_debuff_state = get_debuff_state
NS.is_buff_active = is_buff_active

local function read_aura_state(spell, unit, kind, source)
   if not _G.UnitExists(unit) then return 0, 0 end
   if kind == "buff" then
      return Unit(unit):HasBuffsStacks(spell.ID, source) or 0,
             Unit(unit):HasBuffs(spell.ID, source) or 0
   end
   return Unit(unit):HasDeBuffsStacks(spell.ID, source) or 0,
          Unit(unit):HasDeBuffs(spell.ID, source) or 0
end

-- exists AND remaining <= window. kind: "debuff"(default) | "buff"; source: "player" for mine-only.
function NS.about_to_expire(spell, unit, window, kind, source)
   local _, remaining = read_aura_state(spell, unit, kind or "debuff", source)
   return remaining > 0 and remaining <= (window or 0)
end

-- stacks < n; absent aura counts as 0.
function NS.below_stacks(spell, unit, n, kind, source)
   local stacks = read_aura_state(spell, unit, kind or "debuff", source)
   return stacks < n
end

-- missing OR understacked OR expiring. opts is optional and is read synchronously only.
function NS.needs_refresh(spell, unit, opts)
   local kind = (opts and opts.kind) or "debuff"
   local aura_unit = (opts and opts.unit) or unit or (kind == "buff" and PLAYER_UNIT or TARGET_UNIT)
   local stacks, remaining = read_aura_state(spell, aura_unit, kind, opts and opts.source)
   if stacks == 0 then return true end
   if opts and opts.min_stacks and stacks < opts.min_stacks then return true end
   return remaining <= ((opts and opts.window) or 0)
end

function NS.timer_needs_refresh(active, remaining, window)
   return not active or (remaining or 0) < (window or 0)
end

function NS.resource_capped(context, kind, margin)
   local value
   if kind == "mana" then
      value = context.mana_pct
   else
      value = context[kind]
   end
   if not value then return false end
   return value >= 100 - (margin or 0)
end

function NS.combo_points_full(context)
   return (context.cp or 0) >= 5
end

function NS.execute_phase(context, pct)
   return (context.target_hp or 100) < (pct or 20)
end

function NS.proc_up(spell, unit)
   return is_buff_active(spell, unit or PLAYER_UNIT)
end

-- Bag count of a known reagent/consumable item. Allocation-free.
function NS.item_count(item_id)
   return _G.GetItemCount(item_id) or 0
end

function NS.has_item(item_id, min_count)
   return (_G.GetItemCount(item_id) or 0) >= (min_count or 1)
end

-- Charge-spells ONLY (not reagent buffs; GetSpellCount reports charges, not reagent counts).
function NS.spell_charges(spell)
   return _G.GetSpellCount(spell.ID) or 0
end

function NS.has_charges(spell, min_count)
   return (_G.GetSpellCount(spell.ID) or 0) >= (min_count or 1)
end

-- base spell ID -> reagent item ID. Group buffs consume a reagent; single-target versions don't.
local REAGENT_ITEM = {
   -- [<GiftOfTheWild base IDs>]      = 17021, -- Wild Quillvine (no GotW action exists today; reserved)
   -- [<ArcaneBrilliance base IDs>]   = 17020, -- Arcane Powder
   -- [<PrayerOfFortitude base IDs>]  = 17029, -- Holy Candle
   -- [<PrayerOfSpirit base IDs>]     = 17028, -- Sacred Candle
   -- [<PrayerOfShadowProt base IDs>] = 17028, -- Sacred Candle
}
NS.REAGENT_ITEM = REAGENT_ITEM

local function resolve_maintain_unit(cfg, context)
   if cfg.unit then return cfg.unit end
   if cfg.kind == "buff" then return PLAYER_UNIT end
   return (context and context.target) or TARGET_UNIT
end

local function cached_aura_needs_refresh(cfg, state, window)
   local remaining = cfg.remaining_field and state and state[cfg.remaining_field] or 0
   local stacks
   if cfg.stacks_field then
      stacks = state and state[cfg.stacks_field] or 0
   else
      stacks = remaining > 0 and 1 or 0
   end

   if stacks == 0 then return true end
   if cfg.min_stacks and stacks < cfg.min_stacks then return true end
   return remaining <= (window or 0)
end

local function get_cached_aura_state(cfg, state, fallback_unit)
   if cfg.stacks_field or cfg.remaining_field then
      local remaining = cfg.remaining_field and state and state[cfg.remaining_field] or 0
      local stacks
      if cfg.stacks_field then
         stacks = state and state[cfg.stacks_field] or 0
      else
         stacks = remaining > 0 and 1 or 0
      end
      return stacks, remaining
   end

   return read_aura_state(cfg.track_spell, fallback_unit, cfg.kind, cfg.source)
end

function NS.maintain_aura(config)
   if not config then error("maintain_aura requires config") end
   if not config.name then error("maintain_aura requires name") end
   if not config.spell then error("maintain_aura requires spell") end
   if config.window == nil and not config.window_setting_key then
      error("maintain_aura requires window or window_setting_key")
   end

   local cfg = config
   cfg.kind = cfg.kind or "debuff"
   cfg.track_spell = cfg.track_spell or cfg.spell
   local reagent_item = cfg.reagent_item or REAGENT_ITEM[cfg.spell.ID]
   local opts = {}
   local use_cached_state = cfg.stacks_field or cfg.remaining_field
   local spell_target = cfg.spell_target or cfg.unit or (cfg.kind == "buff" and PLAYER_UNIT or TARGET_UNIT)
   local checked_spell = cfg.spell
   if cfg.check_spell == false then checked_spell = nil end

   return {
      name = cfg.name,
      spell = checked_spell,
      spell_target = spell_target,
      setting_key = cfg.setting_key,
      requires_combat = cfg.requires_combat,
      requires_enemy = cfg.requires_enemy,
      requires_in_range = cfg.requires_in_range,
      requires_stealth = cfg.requires_stealth,
      requires_behind = cfg.requires_behind,
      min_cp = cfg.min_cp,
      is_gcd_gated = cfg.is_gcd_gated,
      is_burst = cfg.is_burst,
      is_defensive = cfg.is_defensive,

      matches = function(context, state)
         if cfg.extra_guard and not cfg.extra_guard(context, state) then return false end
         if reagent_item and not NS.has_item(reagent_item) then return false end

         local window = cfg.window
         if cfg.window_setting_key and context.settings and context.settings[cfg.window_setting_key] ~= nil then
            window = context.settings[cfg.window_setting_key]
         end

         if use_cached_state then
            return cached_aura_needs_refresh(cfg, state, window)
         end

         opts.kind = cfg.kind
         opts.window = window
         opts.min_stacks = cfg.min_stacks
         opts.source = cfg.source
         opts.unit = resolve_maintain_unit(cfg, context)
         return NS.needs_refresh(cfg.track_spell, opts.unit, opts)
      end,

      execute = cfg.execute or function(icon, context, state)
         local unit = resolve_maintain_unit(cfg, context)
         local stacks, remaining = get_cached_aura_state(cfg, state, unit)
         local prefix = cfg.log_prefix or "[AURA]"
         return try_cast(cfg.spell, icon, unit,
            format("%s %s - Stacks: %d, Duration: %.1fs", prefix, cfg.name, stacks, remaining))
      end,
   }
end

-- ============================================================================
-- SWING TIMER UTILITIES
-- ============================================================================
local function is_swing_landing_soon(threshold)
   threshold = threshold or 0.15
   local swing_start = Player:GetSwingStart(1)
   local swing_duration = Player:GetSwing(1)
   if swing_start == 0 or swing_duration == 0 then return false end
   local swing_end = swing_start + swing_duration
   local time_until_swing = swing_end - _G.GetTime()
   return time_until_swing > 0 and time_until_swing <= threshold
end

local function get_time_until_swing()
   local swing_start = Player:GetSwingStart(1)
   local swing_duration = Player:GetSwing(1)
   if swing_start == 0 or swing_duration == 0 then return 0 end
   local remaining = (swing_start + swing_duration) - _G.GetTime()
   return remaining > 0 and remaining or 0
end

NS.is_swing_landing_soon = is_swing_landing_soon
NS.get_time_until_swing = get_time_until_swing

-- ============================================================================
-- COMBAT UTILITIES
-- ============================================================================
local function get_time_to_die(unit_id)
   unit_id = unit_id or TARGET_UNIT
   if not _G.UnitExists(unit_id) then return 500 end
   return Unit(unit_id):TimeToDie()
end

NS.get_time_to_die = get_time_to_die

-- ============================================================================
-- BURST CONTEXT SYSTEM
-- ============================================================================
-- Pre-allocated Bloodlust/Heroism buff IDs for detection
local BLOODLUST_IDS = { 2825, 32182 }

--- Check if auto-burst conditions are met (schema-driven).
-- Returns true if ANY enabled burst condition is satisfied.
local function should_auto_burst(context)
   local s = context.settings
   if not s then return nil end

   -- If no burst conditions are configured, return nil (CDs fire freely)
   local any_configured = s.burst_in_combat or s.burst_on_pull or s.burst_on_execute or s.burst_on_bloodlust
   if not any_configured then return nil end

   -- At least one condition is configured; must be in combat with a target
   if not context.in_combat then return false end
   if not context.has_valid_enemy_target then return false end

   if s.burst_in_combat then return true end
   if s.burst_on_pull and context.combat_time and context.combat_time < 5 then return true end
   if s.burst_on_execute and context.target_hp and context.target_hp < 20 then return true end
   if s.burst_on_bloodlust and (Unit(PLAYER_UNIT):HasBuffs(BLOODLUST_IDS) or 0) > 0 then return true end

   return false  -- conditions configured but none met
end

NS.should_auto_burst = should_auto_burst

-- ============================================================================
-- ROTATION REGISTRY INFRASTRUCTURE
-- ============================================================================
local function priority_desc_comparator(a, b)
   return a.priority > b.priority
end

local rotation_registry = {
   middleware = {},
   strategy_maps = {},   -- populated by register_class()
   playstyle_config = {},
   class_config = nil,   -- set by register_class()
}

function rotation_registry:register_class(config)
   self.class_config = config
   for _, ps in ipairs(config.playstyles) do
      self.strategy_maps[ps] = self.strategy_maps[ps] or {}
   end
   if config.auto_trinkets ~= false and NS.register_trinket_middleware then
      NS.register_trinket_middleware()
   end
end

local last_validated_playstyle = nil

function rotation_registry:validate_playstyle_spells(playstyle)
   if playstyle == last_validated_playstyle then return end
   last_validated_playstyle = playstyle

   for k in pairs(unavailable_spells) do
      unavailable_spells[k] = nil
   end

   local cc = self.class_config
   if not cc or not cc.playstyle_spells then return end

   local entries = cc.playstyle_spells[playstyle]
   if not entries then return end

   local missing_spells = {}
   local optional_missing = {}

   check_spell_availability(entries, missing_spells, optional_missing)

   if cc.validate_playstyle_extra then
      cc.validate_playstyle_extra(playstyle, missing_spells, optional_missing)
   end

   local label = (cc.playstyle_labels and cc.playstyle_labels[playstyle]) or playstyle
   print("|cFF00FF00[Menagerie]|r Switched to " .. label .. " playstyle")

   -- Spell-availability chatter is opt-out (handy while leveling). The
   -- unavailable_spells table is already populated above, so is_spell_available
   -- keeps working even when these messages are silenced.
   if cached_settings.suppress_spell_warnings then return end

   if #missing_spells > 0 then
      print("|cFFFF0000[Menagerie]|r MISSING REQUIRED SPELLS:")
      for _, spell_name in ipairs(missing_spells) do
         print("|cFFFF0000[Menagerie]|r   - " .. spell_name)
      end
   end

   if #optional_missing > 0 then
      print("|cFFFF8800[Menagerie]|r Optional spells not available (will be skipped):")
      for _, spell_name in ipairs(optional_missing) do
         print("|cFFFF8800[Menagerie]|r   - " .. spell_name)
      end
   end

   if #missing_spells == 0 and #optional_missing == 0 then
      print("|cFF00FF00[Menagerie]|r All spells available!")
   end
end

function rotation_registry:register(playstyle, strategies, config)
   local map = self.strategy_maps[playstyle]
   if not map then
      print("|cFFFF0000[Menagerie]|r ERROR: Unknown playstyle: " .. tostring(playstyle))
      return
   end

   if config then
      self.playstyle_config[playstyle] = config
   end

   local is_array = strategies[1] ~= nil and strategies.name == nil and strategies.matches == nil

   if is_array then
      for i, strategy in ipairs(strategies) do
         strategy.priority = 1000 - i
         strategy.name = strategy.name or (playstyle .. "_" .. i)
         map[#map + 1] = strategy
      end
   else
      strategies.priority = strategies.priority or 50
      map[#map + 1] = strategies
   end

   tsort(map, priority_desc_comparator)
end

function rotation_registry:register_middleware(middleware)
   if not middleware.priority then
      middleware.priority = 100
   end

   self.middleware[#self.middleware + 1] = middleware
   tsort(self.middleware, priority_desc_comparator)
end

function rotation_registry:check_prerequisites(strategy, context)
   if strategy.requires_combat ~= nil and strategy.requires_combat ~= context.in_combat then return false end
   if strategy.requires_enemy ~= nil and strategy.requires_enemy ~= context.has_valid_enemy_target then return false end
   if strategy.requires_in_range ~= nil and strategy.requires_in_range ~= context.in_melee_range then return false end
   if strategy.requires_phys_immune ~= nil and strategy.requires_phys_immune ~= context.target_phys_immune then return false end
   if strategy.setting_key and not context.settings[strategy.setting_key] then return false end
   if strategy.spell then
      if unavailable_spells[strategy.spell] then return false end
      local target = strategy.spell_target or TARGET_UNIT
      if not strategy.spell:IsReady(target) then return false end
   end
   return true
end

function rotation_registry:get_playstyle_state(playstyle, context)
   local config = self.playstyle_config[playstyle]
   if config and config.context_builder then
      return config.context_builder(context)
   end
   return nil
end

NS.rotation_registry = rotation_registry

-- ============================================================================
-- STRATEGY FACTORY FUNCTIONS
-- ============================================================================

--- Factory for simple combat strategies (single spell, standard checks)
local function create_combat_strategy(config)
   local spell = config.spell
   local target = config.target or TARGET_UNIT
   local stance = config.stance
   local prefix = config.prefix or "[P?]"
   local log_name = config.log_name or config.name

   return {
      matches = function(context)
         if stance and context.stance ~= stance then return false end
         if not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if config.setting_key and context.settings[config.setting_key] == false then return false end
         if config.extra_match and not config.extra_match(context) then return false end
         return spell:IsReady(target)
      end,
      execute = function(icon, context)
         if config.log_fmt and config.log_args then
            return try_cast_fmt(spell, icon, target, prefix, log_name, config.log_fmt, config.log_args(context))
         end
         return try_cast(spell, icon, target, format("%s %s", prefix, log_name))
      end,
   }
end

local function create_racial_strategy(opts)
   opts = opts or {}
   local prefix = opts.prefix or "RACIAL"
   local spells = opts.spells or {}

   return {
      name = opts.name,
      requires_combat = true,
      is_gcd_gated = false,
      is_burst = true,
      setting_key = "use_racial",

      matches = function(context, state)
         if NS.ttd_too_short(context) then return false end
         if opts.extra_match and not opts.extra_match(context, state) then return false end
         for i = 1, #spells do
            local entry = spells[i]
            local predicate = entry[3]
            if not predicate or predicate(context, state) then
               local action = entry[1]
               if action and action:IsReady(PLAYER_UNIT) then return true end
            end
         end
         return false
      end,

      execute = function(icon, context, state)
         for i = 1, #spells do
            local entry = spells[i]
            local predicate = entry[3]
            if not predicate or predicate(context, state) then
               local action = entry[1]
               if action and action:IsReady(PLAYER_UNIT) then
                  return action:Show(icon), "[" .. prefix .. "] " .. entry[2]
               end
            end
         end
         return nil
      end,
   }
end

local CONSUMABLE_ACTIONS = {
   { "SuperHealingPotion", 22829, "Potion" },
   { "MajorHealingPotion", 13446, "Potion" },
   { "SuperManaPotion",    22832, "Potion" },
   { "DarkRune",           20520, "Item" },
   { "DemonicRune",        12662, "Item" },
   { "HealthstoneMaster",  22105, "Item" },
   { "HealthstoneMajor",   22104, "Item" },
   { "HealthstoneFel",     22103, "Item" },
}

local function register_consumable_actions(A_class)
   if not A_class or not A_class.Create then return end

   local Create = A_class.Create
   for i = 1, #CONSUMABLE_ACTIONS do
      local entry = CONSUMABLE_ACTIONS[i]
      local item_id = entry[2]
      A_class[entry[1]] = Create({
         Type = entry[3],
         ID = item_id,
         QueueForbidden = true,
         Click = { unit = "player", type = "item", item = item_id },
      })
   end
end

NS.register_consumable_actions = register_consumable_actions

--- Name wrapper: sets strategy.name at registration site
local function named(n, s) s.name = n; return s end

NS.create_combat_strategy = create_combat_strategy
NS.create_racial_strategy = create_racial_strategy
NS.named = named

-- ============================================================================
-- RECOVERY MIDDLEWARE FACTORY
-- ============================================================================

local DEFAULT_HEALING_POTION_LABELS = { "Super Healing Potion", "Major Healing Potion" }
local DEFAULT_MANA_POTION_LABELS = { "Super Mana Potion", "Major Mana Potion" }
local DEFAULT_RUNE_LABELS = { "Dark Rune", "Demonic Rune" }

local function recovery_opt(opts, block, key, default_value)
   if block and block[key] ~= nil then return block[key] end
   if opts and opts[key] ~= nil then return opts[key] end
   return default_value
end

local function recovery_threshold(context, key, default_value)
   local value = context.settings[key]
   if value ~= nil then return value end
   return default_value or 0
end

local function recovery_context_ready(context, opts, block, use_combat_time)
   if recovery_opt(opts, block, "skip_stealthed", true) and context.is_stealthed then return false end
   if recovery_opt(opts, block, "require_combat", true) and not context.in_combat then return false end
   if use_combat_time and recovery_opt(opts, block, "require_combat_time", true)
      and (context.combat_time or 0) < 2 then
      return false
   end
   if opts.extra_match and not opts.extra_match(context) then return false end
   if block.extra_match and not block.extra_match(context) then return false end
   return true
end

local function recovery_action(entry)
   if not entry then return nil end
   if entry.IsReady then return entry end
   return entry.action or entry[1]
end

local function recovery_label(entry, labels, index, fallback)
   if entry and not entry.IsReady then
      return entry.label or entry[2] or (labels and labels[index]) or fallback
   end
   return (labels and labels[index]) or fallback
end

local function first_ready_recovery_action(actions, require_exists, labels, fallback)
   if not actions then return nil end
   for i = 1, #actions do
      local entry = actions[i]
      local action = recovery_action(entry)
      if action and (not require_exists or action:IsExists()) and action:IsReady(PLAYER_UNIT) then
         return action, recovery_label(entry, labels, i, fallback)
      end
   end
   return nil
end

local function register_recovery_middleware(opts)
   opts = opts or {}
   local A_class = NS.A
   if not A_class then
      print("|cFFFF6600[Menagerie Recovery]|r Factory skipped: NS.A not available")
      return
   end

   local prefix = opts.prefix or "Recovery"
   local healthstone = opts.healthstone
   local healing_potion = opts.healing_potion
   local mana = opts.mana

   if healthstone then
      rotation_registry:register_middleware({
         name = healthstone.name or (prefix .. "_Healthstone"),
         priority = healthstone.priority or Priority.MIDDLEWARE.RECOVERY_ITEMS,
         is_gcd_gated = healthstone.is_gcd_gated,

         matches = function(context)
            if not recovery_context_ready(context, opts, healthstone, false) then return false end
            local threshold = recovery_threshold(context, healthstone.threshold_key or "healthstone_hp",
               healthstone.hp_default)
            if threshold <= 0 then return false end
            if context.hp > threshold then return false end
            return first_ready_recovery_action(healthstone.actions,
               recovery_opt(opts, healthstone, "require_exists", true)) ~= nil
         end,

         execute = function(icon, context)
            local threshold = recovery_threshold(context, healthstone.threshold_key or "healthstone_hp",
               healthstone.hp_default)
            if threshold <= 0 or context.hp > threshold then return nil end
            local action = first_ready_recovery_action(healthstone.actions,
               recovery_opt(opts, healthstone, "require_exists", true))
            if action then
               return action:Show(icon), format(healthstone.log_format or "[MW] Healthstone - HP: %.0f%%", context.hp)
            end
            return nil
         end,
      })
   end

   if healing_potion then
      rotation_registry:register_middleware({
         name = healing_potion.name or (prefix .. "_HealingPotion"),
         priority = healing_potion.priority or (Priority.MIDDLEWARE.RECOVERY_ITEMS - 5),
         is_gcd_gated = healing_potion.is_gcd_gated,

         matches = function(context)
            if not context.settings[healing_potion.enabled_key or "use_healing_potion"] then return false end
            if not recovery_context_ready(context, opts, healing_potion, true) then return false end
            local threshold = recovery_threshold(context, healing_potion.threshold_key or "healing_potion_hp",
               healing_potion.hp_default)
            if context.hp > threshold then return false end
            return first_ready_recovery_action(healing_potion.actions,
               recovery_opt(opts, healing_potion, "require_exists", true),
               healing_potion.labels or DEFAULT_HEALING_POTION_LABELS, healing_potion.default_label) ~= nil
         end,

         execute = function(icon, context)
            if not context.settings[healing_potion.enabled_key or "use_healing_potion"] then return nil end
            local threshold = recovery_threshold(context, healing_potion.threshold_key or "healing_potion_hp",
               healing_potion.hp_default)
            if context.hp > threshold then return nil end
            local action, label = first_ready_recovery_action(healing_potion.actions,
               recovery_opt(opts, healing_potion, "require_exists", true),
               healing_potion.labels or DEFAULT_HEALING_POTION_LABELS, healing_potion.default_label)
            if action then
               return action:Show(icon), format(healing_potion.log_format or "[MW] %s - HP: %.0f%%",
                  label, context.hp)
            end
            return nil
         end,
      })
   end

   if mana and mana.potion then
      local potion = mana.potion
      rotation_registry:register_middleware({
         name = potion.name or (prefix .. "_ManaPotion"),
         priority = potion.priority,
         is_gcd_gated = potion.is_gcd_gated,

         matches = function(context)
            if not context.settings[potion.enabled_key or "use_mana_potion"] then return false end
            if not recovery_context_ready(context, opts, potion, true) then return false end
            local threshold = recovery_threshold(context, potion.threshold_key or "mana_potion_pct",
               potion.pct_default)
            if context.mana_pct > threshold then return false end
            return first_ready_recovery_action(potion.actions,
               recovery_opt(opts, potion, "require_exists", true),
               potion.labels or DEFAULT_MANA_POTION_LABELS, potion.default_label) ~= nil
         end,

         execute = function(icon, context)
            if not context.settings[potion.enabled_key or "use_mana_potion"] then return nil end
            local threshold = recovery_threshold(context, potion.threshold_key or "mana_potion_pct",
               potion.pct_default)
            if context.mana_pct > threshold then return nil end
            local action, label = first_ready_recovery_action(potion.actions,
               recovery_opt(opts, potion, "require_exists", true),
               potion.labels or DEFAULT_MANA_POTION_LABELS, potion.default_label)
            if action then
               return action:Show(icon), format(potion.log_format or "[MW] %s - Mana: %.0f%%",
                  label, context.mana_pct)
            end
            return nil
         end,
      })
   end

   if mana and mana.rune then
      local rune = mana.rune
      rotation_registry:register_middleware({
         name = rune.name or (prefix .. "_DarkRune"),
         priority = rune.priority,
         is_gcd_gated = rune.is_gcd_gated,

         matches = function(context)
            if not context.settings[rune.enabled_key or "use_dark_rune"] then return false end
            if not recovery_context_ready(context, opts, rune, true) then return false end
            local threshold = recovery_threshold(context, rune.threshold_key or "dark_rune_pct",
               rune.pct_default)
            if context.mana_pct > threshold then return false end
            local min_hp = recovery_threshold(context, rune.min_hp_key or "dark_rune_min_hp",
               rune.min_hp_default or 50)
            if context.hp < min_hp then return false end
            return first_ready_recovery_action(rune.actions,
               recovery_opt(opts, rune, "require_exists", true),
               rune.labels or DEFAULT_RUNE_LABELS, rune.default_label) ~= nil
         end,

         execute = function(icon, context)
            if not context.settings[rune.enabled_key or "use_dark_rune"] then return nil end
            local threshold = recovery_threshold(context, rune.threshold_key or "dark_rune_pct",
               rune.pct_default)
            local min_hp = recovery_threshold(context, rune.min_hp_key or "dark_rune_min_hp",
               rune.min_hp_default or 50)
            if context.mana_pct > threshold or context.hp < min_hp then return nil end
            local action, label = first_ready_recovery_action(rune.actions,
               recovery_opt(opts, rune, "require_exists", true),
               rune.labels or DEFAULT_RUNE_LABELS, rune.default_label)
            if action then
               return action:Show(icon), format(rune.log_format or "[MW] %s - Mana: %.0f%%",
                  label, context.mana_pct)
            end
            return nil
         end,
      })
   end

end

NS.register_recovery_middleware = register_recovery_middleware

-- ============================================================================
-- TRINKET MIDDLEWARE FACTORY
-- ============================================================================
-- Auto-registered by register_class() after NS.A is available.
-- Uses the framework's auto-created A.Trinket1/A.Trinket2 (TrinketBySlot)
-- directly — same pattern as Triptastic's working implementation.
-- IMPORTANT: class.lua must NOT Create({ Type = "Trinket" }) as that
-- overwrites the framework's proper TrinketBySlot versions.

local DEFENSIVE_TRINKET_HP = 35

local function register_trinket_middleware()
   local A_class = NS.A
   if not A_class then
      print("|cFFFF6600[Menagerie Trinket]|r Factory skipped: NS.A not available")
      return
   end

   local Trinket1 = A_class.Trinket1
   local Trinket2 = A_class.Trinket2

   if not Trinket1 and not Trinket2 then
      print("|cFFFF6600[Menagerie Trinket]|r No framework trinkets found (A.Trinket1/A.Trinket2)")
      return
   end

   -- Offensive trinkets: fire during burst windows or /mburst
   rotation_registry:register_middleware({
      name = "Trinkets_Burst",
      priority = 80,
      is_burst = true,
      is_gcd_gated = false,

      matches = function(context)
         if not context.in_combat then return false end
         if not context.has_valid_enemy_target then return false end
         if should_auto_burst(context) == false then return false end
         -- TTD gate: skip trinkets on dying mobs (cd_min_ttd setting; 0 = disabled)
         if ttd_too_short(context) then return false end
         local s = context.settings
         if s.trinket1_mode == "offensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then return true end
         if s.trinket2_mode == "offensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then return true end
         return false
      end,

      execute = function(icon, context)
         local s = context.settings
         if s.trinket1_mode == "offensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then
            return Trinket1:Show(icon), "[MW] Trinket 1 (Burst)"
         end
         if s.trinket2_mode == "offensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then
            return Trinket2:Show(icon), "[MW] Trinket 2 (Burst)"
         end
         return nil
      end,
   })

   -- Defensive trinkets: fire at low HP or /mdef
   rotation_registry:register_middleware({
      name = "Trinkets_Defensive",
      priority = 290,
      is_defensive = true,
      is_gcd_gated = false,

      matches = function(context)
         if not context.in_combat then return false end
         if context.hp > DEFENSIVE_TRINKET_HP then return false end
         local s = context.settings
         if s.trinket1_mode == "defensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then return true end
         if s.trinket2_mode == "defensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then return true end
         return false
      end,

      execute = function(icon, context)
         local s = context.settings
         if s.trinket1_mode == "defensive" and Trinket1 and Trinket1:IsReady(PLAYER_UNIT) then
            return Trinket1:Show(icon), "[MW] Trinket 1 (Defensive)"
         end
         if s.trinket2_mode == "defensive" and Trinket2 and Trinket2:IsReady(PLAYER_UNIT) then
            return Trinket2:Show(icon), "[MW] Trinket 2 (Defensive)"
         end
         return nil
      end,
   })

   print("|cFF00FF00[Menagerie Trinket]|r Middleware registered")
end

NS.register_trinket_middleware = register_trinket_middleware

-- ============================================================================
-- INTERRUPT MIDDLEWARE FACTORY
-- ============================================================================
-- Returns remaining cast time when `unit` is casting a kickable spell.
function NS.target_is_interruptible(unit)
   local cast_left, _, _, _, not_kickable = Unit(unit):IsCastingRemains()
   if cast_left and cast_left > 0 and not not_kickable then
      return cast_left
   end
   return nil
end

-- Emits the canonical "interrupt the current cast" middleware. Warrior/shaman
-- stay bespoke and opt out by not calling this.
local function register_interrupt_middleware(opts)
   opts = opts or {}
   local A_class = NS.A
   if not A_class then
      print("|cFFFF6600[Menagerie Interrupt]|r Factory skipped: NS.A not available")
      return
   end

   local name = opts.name or "Interrupt"
   local spell = opts.spell
   if not spell then
      print("|cFFFF6600[Menagerie Interrupt]|r Skipped: no spell for " .. tostring(name))
      return
   end

   local setting_key = opts.setting_key
   local priority = opts.priority or Priority.MIDDLEWARE.DISPEL_CURSE
   local log_format = "[MW] " .. (opts.label or name) .. " - Cast: %.1fs"
   local resource_gate = opts.resource_gate
   local require_available = opts.require_available
   local unit = opts.unit or TARGET_UNIT

   rotation_registry:register_middleware({
      name = name,
      priority = priority,

      matches = function(context)
         if not context.in_combat then return false end
         if setting_key and not context.settings[setting_key] then return false end
         if not context.has_valid_enemy_target then return false end
         if resource_gate and not resource_gate(context) then return false end
         return true
      end,

      execute = function(icon, context)
         local cast_left = NS.target_is_interruptible(unit)
         if cast_left then
            if (not require_available or is_spell_available(spell)) and spell:IsReady(unit) then
               return spell:Show(icon), format(log_format, cast_left)
            end
         end
         return nil
      end,
   })
end

NS.register_interrupt_middleware = register_interrupt_middleware

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Core]|r Module loaded")
