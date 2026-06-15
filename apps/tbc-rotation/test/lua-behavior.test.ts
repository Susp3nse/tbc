import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');

function runLua(source: string): string {
  const result = spawnSync('lua', ['-'], {
    cwd: root,
    input: source,
    encoding: 'utf8',
  });

  assert.equal(
    result.status,
    0,
    `Lua exited with ${result.status}\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}`,
  );

  return result.stdout;
}

const loadCore = String.raw`
local function aura_key(spell_id, source)
   return tostring(spell_id) .. "|" .. tostring(source or "")
end

TestAuras = {
   debuff = {},
   debuff_stacks = {},
   buff = {},
   buff_stacks = {},
}

local frame = {}
function frame:SetSize() end
function frame:SetPoint() end
function frame:SetFrameStrata() end
function frame:SetScript() end
function frame:RegisterEvent() end
function frame:Hide() end
function frame:Show() end
function frame:CreateFontString()
   local text = {}
   function text:SetPoint() end
   function text:SetFont() end
   function text:GetFont() return "Fonts\\FRIZQT__.TTF" end
   function text:SetText() end
   function text:SetTextColor() end
   function text:SetAlpha() end
   return text
end

Action = {
   CurrentProfile = "test",
   Data = { ProfileEnabled = { test = true } },
   GetToggle = function() return nil end,
   SetToggle = function() return nil end,
   GetSpellInfo = function(spell) return tostring(spell) end,
}

Action.Player = {
   GetSwingStart = function() return 0 end,
   GetSwing = function() return 0 end,
}

local unit = {}
function unit:HasDeBuffs(spell_id, source)
   return TestAuras.debuff[aura_key(spell_id, source)] or 0
end
function unit:HasDeBuffsStacks(spell_id, source)
   return TestAuras.debuff_stacks[aura_key(spell_id, source)] or 0
end
function unit:HasBuffs(spell_id, source)
   return TestAuras.buff[aura_key(spell_id, source)] or 0
end
function unit:HasBuffsStacks(spell_id, source)
   return TestAuras.buff_stacks[aura_key(spell_id, source)] or 0
end
function unit:HealthDeficit()
   if UnitHealthMax and UnitHealth and self.__id then
      return (UnitHealthMax(self.__id) or 0) - (UnitHealth(self.__id) or 0)
   end
   return 0
end
function unit:GetIncomingHeals() return 0 end
function unit:GetHEAL() return 0 end
function unit:GetAbsorb() return 0 end
function unit:GetDMG() return 0 end
function unit:TimeToDie() return 500 end

Action.Unit = function(id)
   unit.__id = id
   return unit
end

function CreateFrame() return frame end
UIParent = {}
function GetTime() return 0 end
function UnitExists() return true end
function GetSpellInfo(spell) return tostring(spell) end
function print() end

dofile("src/aio/core.lua")

function SetDebuff(spell_id, remaining, stacks, source)
   TestAuras.debuff[aura_key(spell_id, source)] = remaining
   TestAuras.debuff_stacks[aura_key(spell_id, source)] = stacks
end

function SetBuff(spell_id, remaining, stacks, source)
   TestAuras.buff[aura_key(spell_id, source)] = remaining
   TestAuras.buff_stacks[aura_key(spell_id, source)] = stacks
end

function ClearAuras()
   for k in pairs(TestAuras.debuff) do TestAuras.debuff[k] = nil end
   for k in pairs(TestAuras.debuff_stacks) do TestAuras.debuff_stacks[k] = nil end
   for k in pairs(TestAuras.buff) do TestAuras.buff[k] = nil end
   for k in pairs(TestAuras.buff_stacks) do TestAuras.buff_stacks[k] = nil end
end
`;

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local item_counts = { [17020] = 3, [17029] = 0 }
local spell_counts = { [1459] = 2, [23028] = 0 }

function GetItemCount(item_id)
   return item_counts[item_id]
end

function GetSpellCount(spell_id)
   return spell_counts[spell_id]
end

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

assert_equal(NS.item_count(17020), 3, "item_count known")
assert_equal(NS.item_count(17021), 0, "item_count missing")
assert_equal(NS.has_item(17020), true, "has_item default")
assert_equal(NS.has_item(17020, 4), false, "has_item min")
assert_equal(NS.has_item(17029), false, "has_item zero")
assert_equal(NS.spell_charges({ ID = 1459 }), 2, "spell_charges known")
assert_equal(NS.spell_charges({ ID = 23028 }), 0, "spell_charges zero")
assert_equal(NS.has_charges({ ID = 1459 }, 2), true, "has_charges min")
assert_equal(NS.has_charges({ ID = 1459 }, 3), false, "has_charges above min")

io.write("PASS: core item and charge helpers\n")
`,
  );

  assert.match(output, /PASS: core item and charge helpers/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local spell = { ID = 2948 }
local opts = {}

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

ClearAuras()
assert_equal(NS.about_to_expire(spell, "target", 6), false, "missing debuff is not about to expire")
assert_equal(NS.below_stacks(spell, "target", 5), true, "missing debuff is below stacks")
assert_equal(NS.needs_refresh(spell, "target", opts), true, "missing debuff needs refresh")

SetDebuff(2948, 8, 5)
opts.kind = nil
opts.window = 6
opts.min_stacks = 5
opts.source = nil
assert_equal(NS.about_to_expire(spell, "target", 6), false, "healthy debuff not expiring")
assert_equal(NS.below_stacks(spell, "target", 5), false, "healthy debuff not below stacks")
assert_equal(NS.needs_refresh(spell, "target", opts), false, "healthy debuff does not need refresh")

SetDebuff(2948, 5.9, 5)
assert_equal(NS.about_to_expire(spell, "target", 6), true, "debuff inside window expires")
assert_equal(NS.needs_refresh(spell, "target", opts), true, "debuff inside window needs refresh")

SetDebuff(2948, 8, 4)
assert_equal(NS.below_stacks(spell, "target", 5), true, "understacked debuff below stacks")
assert_equal(NS.needs_refresh(spell, "target", opts), true, "understacked debuff needs refresh")

SetDebuff(2948, 0.1, 5)
opts.window = nil
assert_equal(NS.needs_refresh(spell, "target", opts), false, "nil window only refreshes present aura at zero")

SetBuff(2948, 2, 1, "player")
opts.kind = "buff"
opts.window = 3
opts.min_stacks = nil
opts.source = "player"
assert_equal(NS.about_to_expire(spell, "player", 3, "buff", "player"), true, "buff source expires")
assert_equal(NS.needs_refresh(spell, "player", opts), true, "buff source needs refresh")
assert_equal(NS.timer_needs_refresh(false, 0, 10), true, "timer missing needs refresh")
assert_equal(NS.timer_needs_refresh(true, 9.9, 10), true, "timer below window needs refresh")
assert_equal(NS.timer_needs_refresh(true, 10, 10), false, "timer equal window preserves strict totem behavior")
assert_equal(NS.timer_needs_refresh(true, 11, 10), false, "timer above window does not need refresh")
assert_equal(NS.resource_capped({ energy = 95 }, "energy", 5), true, "energy capped with margin")
assert_equal(NS.resource_capped({ rage = 94 }, "rage", 5), false, "rage not capped below margin")
assert_equal(NS.resource_capped({ mana_pct = 98 }, "mana", 2), true, "mana capped uses mana percent")
assert_equal(NS.combo_points_full({ cp = 5 }), true, "combo points full")
assert_equal(NS.combo_points_full({ cp = 4 }), false, "combo points not full")
assert_equal(NS.execute_phase({ target_hp = 19 }), true, "default execute phase")
assert_equal(NS.execute_phase({ target_hp = 20 }), false, "execute phase is below threshold")
SetBuff(2948, 5, 1)
assert_equal(NS.proc_up(spell, "player"), true, "proc_up checks player buff")

io.write("PASS: core maintenance predicates\n")
`,
  );

  assert.match(output, /PASS: core maintenance predicates/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local alive = { player = true, party1 = true, party2 = true }
local connected = { player = true, party1 = true, party2 = true }
local assist = { player = true, party1 = true, party2 = true }
local range = { player = true, party1 = true, party2 = false }
local hp = { player = 900, party1 = 400, party2 = 100 }
local max_hp = { player = 1000, party1 = 1000, party2 = 1000 }

function IsInRaid() return false end
function IsInGroup() return true end
function UnitExists(unit) return alive[unit] == true end
function UnitIsDead(unit) return false end
function UnitIsConnected(unit) return connected[unit] == true end
function UnitCanAssist(_, unit) return assist[unit] == true end
function UnitIsUnit(a, b) return a == b end
function IsSpellInRange(_, unit) return range[unit] and 1 or 0 end
function UnitInRange(unit) return nil, range[unit] == true end
function UnitHealth(unit) return hp[unit] or 0 end
function UnitHealthMax(unit) return max_hp[unit] or 1 end
function UnitThreatSituation(unit) return unit == "party1" and 2 or 0 end
function UnitGroupRolesAssigned(unit) return unit == "party1" and "TANK" or "NONE" end

local group_out = { {}, {}, {}, {}, {} }
local group_count = NS.scan_group(group_out, { range_spell = "Flash Heal" })
if group_count ~= 2 then error("scan_group expected 2, got " .. tostring(group_count)) end
if group_out[1].unit ~= "player" then error("scan_group expected player first") end
if group_out[2].unit ~= "party1" then error("scan_group expected party1 second") end

local heal_out = { {}, {}, {}, {}, {} }
local entries, heal_count = NS.scan_healing_targets({}, {
   range_spell = "Flash Heal",
   out = heal_out,
   decorate_entry = function(entry, unit)
      entry.marked = unit == "party1"
   end,
})
if heal_count ~= 2 then error("scan_healing_targets expected 2, got " .. tostring(heal_count)) end
if entries[1].unit ~= "party1" then error("scan_healing_targets expected injured target first") end
if entries[1].marked ~= true then error("scan_healing_targets decoration missing") end
if entries[1].is_tank ~= true then error("scan_healing_targets tank field missing") end

io.write("PASS: core group healing scanner\n")
`,
  );

  assert.match(output, /PASS: core group healing scanner/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local scorch = { ID = 2948 }
local Constants = { SCORCH = { MAX_STACKS = 5, DEFAULT_REFRESH = 6 } }
local strategy = NS.maintain_aura({
   name = "MaintainScorch",
   log_prefix = "[FIRE]",
   spell = scorch,
   kind = "debuff",
   source = "player",
   min_stacks = Constants.SCORCH.MAX_STACKS,
   window = Constants.SCORCH.DEFAULT_REFRESH,
   window_setting_key = "fire_scorch_refresh",
   setting_key = "fire_maintain_scorch",
   extra_guard = function(context) return not context.is_moving end,
})

local function old_matches(context, state)
   if context.is_moving then return false end
   local refresh = context.settings.fire_scorch_refresh or Constants.SCORCH.DEFAULT_REFRESH
   return state.scorch_stacks < Constants.SCORCH.MAX_STACKS or state.scorch_duration < refresh
end

local function new_matches(context)
   return strategy.matches(context, {})
end

local cases = {
   { remaining = 0, stacks = 0 },
   { remaining = 1, stacks = 0 },
   { remaining = 2, stacks = 1 },
   { remaining = 5.9, stacks = 5 },
   { remaining = 6.1, stacks = 5 },
   { remaining = 999, stacks = 5 },
}

for enabled = 0, 1 do
   for moving = 0, 1 do
      for i = 1, #cases do
         local case = cases[i]
         ClearAuras()
         SetDebuff(2948, case.remaining, case.stacks, "player")
         local context = {
            is_moving = moving == 1,
            settings = { fire_scorch_refresh = enabled == 1 and 6 or nil },
         }
         local state = {
            scorch_duration = case.remaining,
            scorch_stacks = case.stacks,
         }
         local old = old_matches(context, state)
         local new = new_matches(context)
         if old ~= new then
            error("MaintainScorch diff at case " .. i .. ": old=" .. tostring(old) .. " new=" .. tostring(new))
         end
      end
   end
end

io.write("PASS: MaintainScorch predicate diff harness\n")
`,
  );

  assert.match(output, /PASS: MaintainScorch predicate diff harness/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local scorch = { ID = 2948 }

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

local ok = pcall(function()
   NS.maintain_aura({ name = "BadScorch", log_prefix = "[FIRE]", spell = scorch, kind = "debuff" })
end)
assert_equal(ok, false, "factory requires explicit window")

local strategy = NS.maintain_aura({
   name = "MaintainScorch",
   log_prefix = "[FIRE]",
   spell = scorch,
   kind = "debuff",
   source = "player",
   min_stacks = 5,
   window_setting_key = "fire_scorch_refresh",
   setting_key = "fire_maintain_scorch",
   extra_guard = function(context) return not context.is_moving end,
})

assert_equal(strategy.name, "MaintainScorch", "factory name")
assert_equal(strategy.spell, scorch, "factory spell passthrough")
assert_equal(strategy.spell_target, "target", "factory spell target")
assert_equal(strategy.setting_key, "fire_maintain_scorch", "factory setting key passthrough")

ClearAuras()
SetDebuff(2948, 6.1, 5, "player")
local context = { is_moving = false, settings = { fire_scorch_refresh = 6 } }
assert_equal(strategy.matches(context, {}), false, "factory reads setting window")
context.settings.fire_scorch_refresh = 7
assert_equal(strategy.matches(context, {}), true, "factory reads updated setting window live")
context.is_moving = true
assert_equal(strategy.matches(context, {}), false, "factory extra guard")

local cached_strategy = NS.maintain_aura({
   name = "CachedScorch",
   log_prefix = "[FIRE]",
   spell = scorch,
   kind = "debuff",
   source = "player",
   min_stacks = 5,
   window = 6,
   stacks_field = "scorch_stacks",
   remaining_field = "scorch_duration",
})

ClearAuras()
assert_equal(cached_strategy.matches({ settings = {} }, { scorch_stacks = 5, scorch_duration = 6.1 }), false, "factory cache healthy")
assert_equal(cached_strategy.matches({ settings = {} }, { scorch_stacks = 5, scorch_duration = 5.9 }), true, "factory cache expiring")
assert_equal(cached_strategy.matches({ settings = {} }, { scorch_stacks = 4, scorch_duration = 99 }), true, "factory cache understacked")

local shiv = { ID = 5938 }
local deadly_poison = { ID = 27187 }
local shiv_strategy = NS.maintain_aura({
   name = "ShivRefresh",
   log_prefix = "[ROGUE]",
   spell = shiv,
   track_spell = deadly_poison,
   kind = "debuff",
   window = 2,
   setting_key = "use_shiv",
   requires_stealth = false,
   execute = function() return "custom-execute" end,
})

assert_equal(shiv_strategy.requires_stealth, false, "factory stealth passthrough")
assert_equal(shiv_strategy.execute(), "custom-execute", "factory custom execute")
ClearAuras()
SetDebuff(27187, 3, 1)
assert_equal(shiv_strategy.matches({ settings = {} }, {}), false, "factory track spell healthy")
SetDebuff(27187, 1, 1)
assert_equal(shiv_strategy.matches({ settings = {} }, {}), true, "factory track spell expiring")

local manual_spell_strategy = NS.maintain_aura({
   name = "ManualSunder",
   log_prefix = "[WARRIOR]",
   spell = { ID = 7386 },
   kind = "debuff",
   window = 3,
   check_spell = false,
})
assert_equal(manual_spell_strategy.spell, nil, "factory can skip registry spell check")

io.write("PASS: maintain_aura factory contract\n")
`,
  );

  assert.match(output, /PASS: maintain_aura factory contract/);
}
