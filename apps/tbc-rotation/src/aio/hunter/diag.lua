-- Hunter diagnostics for the shared Menagerie debug panel.

local _G = _G
local A = _G.Action
if not A then return end
if A.PlayerClass ~= "HUNTER" then return end

local NS = _G.Menagerie
if not NS then return end

local HA = NS.A
local Unit = NS.Unit
if not (HA and Unit) then return end

local LibStub = _G.LibStub
local Pet = LibStub and LibStub("PetLibrary", true) or nil
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local GetNumGroupMembers = _G.GetNumGroupMembers
local format = string.format

local UNIT_TARGET = "target"
local UNIT_PET = "pet"
local WING_CLIP_IMMUNITY = { "TotalImun", "DamagePhysImun", "CCTotalImun" }

local COLOR_GREEN = "|cff00ff00"
local COLOR_RED = "|cffff5555"
local COLOR_RESET = "|r"

local function yn(value)
   if value then return COLOR_GREEN .. "yes" .. COLOR_RESET end
   return COLOR_RED .. "no" .. COLOR_RESET
end

local function fmt(value)
   return format("%.1f", tonumber(value) or 0)
end

local function seconds_or_none(value)
   value = tonumber(value) or 0
   if value > 0 then return COLOR_GREEN .. fmt(value) .. "s" .. COLOR_RESET end
   return COLOR_RED .. "none" .. COLOR_RESET
end

local function unit_handle(unit_id)
   return Unit and Unit(unit_id) or nil
end

local function unit_exists(unit)
   return unit and unit.IsExists and unit:IsExists() or false
end

local function debuff_remaining(unit, spell, fallback_id, mine)
   if not (unit and unit.HasDeBuffs) then return 0 end
   local spell_id = spell and spell.ID or fallback_id
   return unit:HasDeBuffs(spell_id, mine) or 0
end

local function spell_ready(spell, unit_id)
   return spell and spell.IsReady and spell:IsReady(unit_id) or false
end

local function build_hunter_sections(out, ctx)
   local target = unit_handle(UNIT_TARGET)
   local pet = unit_handle(UNIT_PET)
   local target_exists = unit_exists(target)
   local target_hp = target_exists and target.HealthPercent and target:HealthPercent() or 0
   local gcd = A.GetGCD and A.GetGCD() or 0
   local target_range = target_exists and NS.GetRange and NS.GetRange(UNIT_TARGET) or 0
   local in_pvp = HA.IsInPvP or false
   local in_group = GetNumGroupMembers and (GetNumGroupMembers() or 0) > 0
   local context_label = in_pvp and "PvP" or (in_group and "PvE Group" or "PvE Solo")

   local serpent_sting = 0
   local hunters_mark = 0
   local wing_clip = 0
   local concussive = 0
   local viper_sting = 0

   if target_exists then
      serpent_sting = debuff_remaining(target, HA.SerpentSting, 1978, true)
      hunters_mark = debuff_remaining(target, HA.HuntersMark, 1130, nil)
      wing_clip = debuff_remaining(target, HA.WingClip, 2974, true)
      concussive = debuff_remaining(target, HA.ConcussiveShot, 5116, true)
      viper_sting = debuff_remaining(target, HA.ViperSting, 3034, true)
   end

   local settings = NS.cached_settings
   local concussive_range_ok = target_range > 0 and (target_range < 10 or target_range > 25)
   local concussive_ready = target_exists and spell_ready(HA.ConcussiveShot, UNIT_TARGET)
   local concussive_debuff_ok = concussive < 2
   local should_concussive = in_pvp and concussive_range_ok and concussive_debuff_ok and concussive_ready

   local viper_hp_threshold = settings and settings.viper_sting_hp_threshold or 30
   local wing_clip_hp_pvp = settings and settings.wing_clip_hp_pvp or 20
   local wing_clip_hp_pve = settings and settings.wing_clip_hp_pve or 20
   local wing_clip_hp_active = in_pvp and wing_clip_hp_pvp or wing_clip_hp_pve
   local target_class = target_exists and target.Class and target:Class() or "NONE"
   local target_is_player = target_exists and target.IsPlayer and target:IsPlayer() or false
   local target_power_type = target_exists and target.PowerType and target:PowerType() or "NONE"
   local is_mana_user = target_power_type == "MANA"
   local viper_hp_ok = target_hp >= viper_hp_threshold
   local viper_debuff_ok = viper_sting <= gcd
   local viper_ready = target_exists and spell_ready(HA.ViperSting, UNIT_TARGET)
   local viper_priority = target_exists and HA.ShouldUseViperSting and HA.ShouldUseViperSting(UNIT_TARGET) or false
   local should_viper = in_pvp and viper_priority and viper_debuff_ok and viper_ready

   local wing_clip_ready = target_exists and spell_ready(HA.WingClip, UNIT_TARGET)
   local wing_clip_immunity_ok = target_exists and HA.WingClip and HA.WingClip.AbsentImun
      and HA.WingClip:AbsentImun(UNIT_TARGET, WING_CLIP_IMMUNITY) or false
   local wing_clip_priority = target_exists and HA.ShouldUseWingClip and HA.ShouldUseWingClip(UNIT_TARGET) or false

   local pet_exists = unit_exists(pet)
   local pet_hp = pet_exists and pet.HealthPercent and pet:HealthPercent() or 0
   local pet_dead_api = UnitIsDeadOrGhost and UnitIsDeadOrGhost(UNIT_PET) or false
   local pet_dead_unit = pet_exists and pet.IsDead and pet:IsDead() or false
   local pet_lib_active = Pet and Pet.IsActive and Pet:IsActive() or false
   local pet_lib_can_call = Pet and Pet.CanCall and Pet:CanCall() or false
   local pet_lib_attacking = Pet and Pet.IsAttacking and Pet:IsAttacking() or false
   local pet_alive = pet_lib_active or (pet_exists and not pet_dead_api)
   local mend_pet = pet_exists and HA.MendPet and pet.HasBuffs and pet:HasBuffs(HA.MendPet.ID, true) or 0

   if not target_exists then
      out:header("HUNTER PET")
      if not pet_exists and not pet_lib_active then
         out:kv("Pet", "none", "dim")
         out:kv("Can Call", yn(pet_lib_can_call))
      else
         out:kv("Exists", yn(pet_exists))
         out:kv("HP", fmt(pet_hp) .. "%")
         out:kv("Mend Pet", seconds_or_none(mend_pet))
         out:kv("Dead API", yn(pet_dead_api))
         out:kv("Dead Unit", yn(pet_dead_unit))
         out:kv("Pet Active", yn(pet_lib_active))
         out:kv("Can Call", yn(pet_lib_can_call))
         out:kv("Attacking", yn(pet_lib_attacking))
         out:kv("Alive", yn(pet_alive))
      end
      return
   end

   out:header("HUNTER DEBUFFS")
   out:kv("Serpent", seconds_or_none(serpent_sting))
   out:kv("Mark", seconds_or_none(hunters_mark))
   out:kv("Wing Clip", seconds_or_none(wing_clip))
   out:kv("Concussive", seconds_or_none(concussive))
   out:kv("Viper", seconds_or_none(viper_sting))

   out:header("HUNTER PVP")
   out:kv("Context", context_label)
   out:kv("Target", target_class .. "  Player " .. yn(target_is_player) .. "  Mana " .. yn(is_mana_user))
   out:kv("Viper", "HP>=" .. fmt(viper_hp_threshold) .. "% " .. yn(viper_hp_ok) .. "  Prio " .. yn(viper_priority) .. "  Ready " .. yn(viper_ready))
   out:kv("Viper Use", "Debuff<=" .. fmt(gcd) .. "s " .. yn(viper_debuff_ok) .. "  => " .. yn(should_viper))
   out:kv("Concuss", "Range " .. yn(concussive_range_ok) .. "  Ready " .. yn(concussive_ready) .. "  => " .. yn(should_concussive))
   out:kv("WC HP", "PvP " .. fmt(wing_clip_hp_pvp) .. "%  PvE " .. fmt(wing_clip_hp_pve) .. "%  Active " .. fmt(wing_clip_hp_active) .. "%")
   out:kv("WC Use", "Prio " .. yn(wing_clip_priority) .. "  Ready " .. yn(wing_clip_ready) .. "  Immune " .. yn(wing_clip_immunity_ok))

   out:header("HUNTER PET")
   if not pet_exists and not pet_lib_active then
      out:kv("Pet", "none", "dim")
      out:kv("Can Call", yn(pet_lib_can_call))
   else
      out:kv("Exists", yn(pet_exists) .. "  Active " .. yn(pet_lib_active))
      out:kv("HP", fmt(pet_hp) .. "%  Mend " .. seconds_or_none(mend_pet))
      out:kv("Dead", "API " .. yn(pet_dead_api) .. "  Unit " .. yn(pet_dead_unit))
      out:kv("Library", "Call " .. yn(pet_lib_can_call) .. "  Attack " .. yn(pet_lib_attacking))
      out:kv("Alive", yn(pet_alive))
   end
end

if NS.rotation_registry and NS.rotation_registry.class_config then
   NS.rotation_registry.class_config.debug_panel = build_hunter_sections
end
