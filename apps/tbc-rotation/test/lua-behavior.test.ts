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

{
  const output = runLua(String.raw`
local frame = {}
function frame:RegisterEvent() end
function frame:SetScript() end

function CreateFrame() return frame end
function print() end

UIParent = {}
SlashCmdList = {}

Menagerie = {
   Theme = {
      state = {},
      text_dim = { 0.7, 0.7, 0.7 },
   },
   Player = {},
   Unit = function() return {} end,
   rotation_registry = {},
}

dofile("src/aio/widgets.lua")
dofile("src/aio/dashboard.lua")

if SLASH_MENAGERIEDASH1 ~= "/mdash" then
   error("expected /mdash slash alias")
end
if SlashCmdList["MENAGERIEDASH"] ~= Menagerie.toggle_dashboard then
   error("expected /mdash to call dashboard toggle")
end

io.write("PASS: dashboard slash alias\n")
`);

  assert.match(output, /PASS: dashboard slash alias/);
}

{
  const output = runLua(String.raw`
local frames = {}
local timer_value_sets = 0
local current_gcd = 1.0
local now = 10

function print() end
function GetTime() return now end
function GetSpellInfo() return nil end
function GetSpellTexture() return "icon" end
function GetInventoryItemTexture() return nil end
function GetInventoryItemCooldown() return 0, 0 end
function UnitRangedDamage() return 2.0 end
function UnitName() return nil end
function UnitGUID(unit) return unit == "player" and "Player-1" or nil end
function UnitDetailedThreatSituation() return nil, nil, nil end
function CombatLogGetCurrentEventInfo() return nil end

local function new_frame(kind, name, parent)
   local f = { kind = kind, name = name, parent = parent, scripts = {}, visible = false }
   function f:SetSize(w, h) self.width = w; self.height = h end
   function f:SetWidth(w) self.width = w end
   function f:SetHeight(h) self.height = h end
   function f:SetPoint(...) self.point = { ... } end
   function f:ClearAllPoints() self.point = nil end
   function f:SetAllPoints() self.allPoints = true end
   function f:SetBackdrop(v) self.backdrop = v end
   function f:SetBackdropColor(...) self.backdropColor = { ... } end
   function f:SetBackdropBorderColor(...) self.borderColor = { ... } end
   function f:SetMovable(v) self.movable = v end
   function f:EnableMouse(v) self.mouse = v end
   function f:SetClampedToScreen(v) self.clamped = v end
   function f:RegisterForDrag(...) self.drag = { ... } end
   function f:RegisterEvent(...) self.events = { ... } end
   function f:SetScript(event, cb) self.scripts[event] = cb end
   function f:GetScript(event) return self.scripts[event] end
   function f:SetFrameStrata(v) self.strata = v end
   function f:SetAlpha(v) self.alpha = v end
   function f:GetCenter() return nil end
   function f:IsShown() return self.visible end
   function f:Show() self.visible = true end
   function f:Hide() self.visible = false end
   function f:StartMoving() self.moving = true end
   function f:StopMovingOrSizing() self.moving = false end
   function f:GetParent() return self.parent end
   function f:GetRegions() return end
   function f:GetChildren() return end
   function f:SetTexture(v) self.texture = v end
   function f:SetTexCoord(...) self.texCoord = { ... } end
   function f:SetVertexColor(...) self.vertexColor = { ... } end
   function f:SetColorTexture(...) self.colorTexture = { ... } end
   function f:SetFont(...) self.font = { ... } end
   function f:SetJustifyH(v) self.justifyH = v end
   function f:SetSpacing(v) self.spacing = v end
   function f:SetTextColor(...) self.textColor = { ... } end
   function f:SetShadowColor(...) self.shadowColor = { ... } end
   function f:SetShadowOffset(...) self.shadowOffset = { ... } end
   function f:SetText(v)
      self.text = v
      if self.kind == "FontString" and v == "1.0" then
         timer_value_sets = timer_value_sets + 1
      end
   end
   function f:CreateTexture(_, layer)
      local texture = new_frame("Texture", nil, self)
      texture.layer = layer
      return texture
   end
   function f:CreateFontString(_, layer)
      local fs = new_frame("FontString", nil, self)
      fs.layer = layer
      return fs
   end
   frames[#frames + 1] = f
   if name then _G[name] = f end
   return f
end

function CreateFrame(kind, name, parent)
   return new_frame(kind, name, parent)
end

local function run_updates(elapsed)
   for i = 1, #frames do
      local cb = frames[i].scripts.OnUpdate
      if cb then cb(frames[i], elapsed) end
   end
end

UIParent = new_frame("Frame", "UIParent")
GameTooltip = {
   SetOwner = function() end,
   SetInventoryItem = function() end,
   SetSpellByID = function() end,
   Show = function() end,
}
function GameTooltip_Hide() end
SlashCmdList = {}

Menagerie = {
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      accent_hex = "ff8800",
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
      state = {
         good = { 0.2, 0.9, 0.2 },
         warn = { 1.0, 0.8, 0.2 },
         bad = { 1.0, 0.2, 0.2 },
      },
   },
   A = {
      GetGCD = function() return 1.5 end,
      GetCurrentGCD = function() return current_gcd end,
   },
   Player = {
      Energy = function() return 0 end,
      EnergyMax = function() return 100 end,
      GetSwingShoot = function() return 0 end,
      GetSwingStart = function() return 0 end,
      GetSwing = function() return 0 end,
   },
   Unit = function()
      return {
         TimeToDie = function() return 0 end,
         GetRange = function() return nil, nil end,
         HasBuffs = function() return 0 end,
         HasDeBuffs = function() return 0 end,
         HasDeBuffsStacks = function() return 0 end,
      }
   end,
   cached_settings = { show_dashboard = false },
   rotation_registry = {
      class_config = {
         name = "Hunter",
         version = "v1.0.0",
         idle_playstyle_name = "ranged",
         get_active_playstyle = function() return "ranged" end,
         dashboard = { swing_label = false },
      },
   },
}

dofile("src/aio/widgets.lua")
dofile("src/aio/dashboard.lua")

Menagerie.toggle_dashboard()
run_updates(0.11)

timer_value_sets = 0
run_updates(0.01)
if timer_value_sets ~= 0 then error("unchanged GCD text should not be rewritten") end

current_gcd = 0
run_updates(0.01)
current_gcd = 1.0
timer_value_sets = 0
run_updates(0.01)
if timer_value_sets ~= 1 then error("GCD text should rewrite after hiding and re-showing") end

io.write("PASS: dashboard timer text updates only on change\n")
`);

  assert.match(output, /PASS: dashboard timer text updates only on change/);
}

{
  const output = runLua(String.raw`
local frames = {}
local named_counts = {}

function print() end
function GetTime() return 0 end
function GetSpellInfo() return nil end
function GetSpellTexture() return "icon" end
function GetInventoryItemTexture() return nil end
function GetInventoryItemCooldown() return 0, 0 end
function UnitRangedDamage() return 2.0 end
function UnitName() return nil end
function UnitGUID(unit) return unit == "player" and "Player-1" or nil end
function UnitDetailedThreatSituation() return nil, nil, nil end
function CombatLogGetCurrentEventInfo() return nil end

local function new_frame(kind, name, parent)
   local f = { kind = kind, name = name, parent = parent, scripts = {}, visible = false }
   function f:SetSize(w, h) self.width = w; self.height = h end
   function f:SetWidth(w) self.width = w end
   function f:SetHeight(h) self.height = h end
   function f:SetPoint(...) self.point = { ... } end
   function f:ClearAllPoints() self.point = nil end
   function f:SetAllPoints() self.allPoints = true end
   function f:SetBackdrop(v) self.backdrop = v end
   function f:SetBackdropColor(...) self.backdropColor = { ... } end
   function f:SetBackdropBorderColor(...) self.borderColor = { ... } end
   function f:SetMovable(v) self.movable = v end
   function f:EnableMouse(v) self.mouse = v end
   function f:SetClampedToScreen(v) self.clamped = v end
   function f:RegisterForDrag(...) self.drag = { ... } end
   function f:RegisterEvent(...) self.events = { ... } end
   function f:SetScript(event, cb) self.scripts[event] = cb end
   function f:GetScript(event) return self.scripts[event] end
   function f:SetFrameStrata(v) self.strata = v end
   function f:SetAlpha(v) self.alpha = v end
   function f:GetCenter() return nil end
   function f:IsShown() return self.visible end
   function f:Show() self.visible = true end
   function f:Hide() self.visible = false end
   function f:StartMoving() self.moving = true end
   function f:StopMovingOrSizing() self.moving = false end
   function f:GetParent() return self.parent end
   function f:GetRegions() return end
   function f:GetChildren() return end
   function f:SetTexture(v) self.texture = v end
   function f:SetTexCoord(...) self.texCoord = { ... } end
   function f:SetVertexColor(...) self.vertexColor = { ... } end
   function f:SetColorTexture(...) self.colorTexture = { ... } end
   function f:SetFont(...) self.font = { ... } end
   function f:SetJustifyH(v) self.justifyH = v end
   function f:SetSpacing(v) self.spacing = v end
   function f:SetTextColor(...) self.textColor = { ... } end
   function f:SetShadowColor(...) self.shadowColor = { ... } end
   function f:SetShadowOffset(...) self.shadowOffset = { ... } end
   function f:SetText(v) self.text = v end
   function f:CreateTexture(_, layer)
      local texture = new_frame("Texture", nil, self)
      texture.layer = layer
      return texture
   end
   function f:CreateFontString(_, layer)
      local fs = new_frame("FontString", nil, self)
      fs.layer = layer
      return fs
   end
   frames[#frames + 1] = f
   if name then
      named_counts[name] = (named_counts[name] or 0) + 1
      _G[name] = f
   end
   return f
end

function CreateFrame(kind, name, parent)
   return new_frame(kind, name, parent)
end

UIParent = new_frame("Frame", "UIParent")
GameTooltip = {
   SetOwner = function() end,
   SetInventoryItem = function() end,
   SetSpellByID = function() end,
   Show = function() end,
}
function GameTooltip_Hide() end
SlashCmdList = {}

Menagerie = {
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      accent_hex = "ff8800",
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
      state = {
         good = { 0.2, 0.9, 0.2 },
         warn = { 1.0, 0.8, 0.2 },
         bad = { 1.0, 0.2, 0.2 },
      },
   },
   A = {
      GetGCD = function() return 1.5 end,
      GetCurrentGCD = function() return 0 end,
   },
   Player = {
      Energy = function() return 0 end,
      EnergyMax = function() return 100 end,
      GetSwingShoot = function() return 0 end,
      GetSwingStart = function() return 0 end,
      GetSwing = function() return 0 end,
   },
   Unit = function()
      return {
         TimeToDie = function() return 0 end,
         GetRange = function() return nil, nil end,
         HasBuffs = function() return 0 end,
         HasDeBuffs = function() return 0 end,
         HasDeBuffsStacks = function() return 0 end,
      }
   end,
   cached_settings = { show_dashboard = false },
   rotation_registry = {
      class_config = {
         name = "Hunter",
         version = "v1.0.0",
         idle_playstyle_name = "ranged",
         get_active_playstyle = function() return "ranged" end,
         dashboard = { swing_label = false },
      },
   },
}

dofile("src/aio/widgets.lua")
dofile("src/aio/dashboard.lua")
Menagerie.toggle_dashboard()

local first = MenagerieDashboard
if not first then error("first dashboard frame should be named globally") end

dofile("src/aio/dashboard.lua")
Menagerie.toggle_dashboard()

if MenagerieDashboard ~= first then error("dashboard frame should be reused across module re-exec") end
if named_counts.MenagerieDashboard ~= 1 then
   error("expected one MenagerieDashboard frame, got " .. tostring(named_counts.MenagerieDashboard))
end
if not first.ui then error("dashboard should persist child refs on the frame for rebind") end

local ticker_names = {
   "MenagerieDashUpdateFrame",
   "MenagerieDashFrameRateFrame",
   "MenagerieDashWatchFrame",
}
for i = 1, #ticker_names do
   local name = ticker_names[i]
   if not _G[name] then error("missing named ticker " .. name) end
   if named_counts[name] ~= 1 then
      error("expected one " .. name .. ", got " .. tostring(named_counts[name]))
   end
   if not _G[name].scripts.OnUpdate then error(name .. " should have an OnUpdate script") end
end

io.write("PASS: dashboard reuses frame and tickers across re-exec\n")
`);

  assert.match(output, /PASS: dashboard reuses frame and tickers across re-exec/);
}

{
  const output = runLua(String.raw`
local frames = {}
local printed = {}
function print(msg) printed[#printed + 1] = tostring(msg or "") end

local function new_frame(kind, name, parent)
   local f = { kind = kind, name = name, parent = parent, scripts = {}, visible = false }
   function f:SetSize(w, h) self.width = w; self.height = h end
   function f:SetFrameStrata(v) self.strata = v end
   function f:SetFrameLevel(v) self.level = v end
   function f:SetClampedToScreen(v) self.clamped = v end
   function f:SetMovable(v) self.movable = v end
   function f:EnableMouse(v) self.mouse = v end
   function f:EnableMouseWheel(v) self.mouseWheel = v end
   function f:RegisterForDrag(...) self.drag = { ... } end
   function f:RegisterForClicks(...) self.clicks = { ... } end
   function f:SetScript(event, cb) self.scripts[event] = cb end
   function f:GetScript(event) return self.scripts[event] end
   function f:SetPoint(...) self.point = { ... } end
   function f:ClearAllPoints() self.point = nil end
   function f:SetBackdrop(v) self.backdrop = v end
   function f:SetBackdropColor(...) self.backdropColor = { ... } end
   function f:SetBackdropBorderColor(...) self.borderColor = { ... } end
   function f:SetAllPoints() self.allPoints = true end
   function f:SetTexture(v) self.texture = v end
   function f:SetVertexColor(...) self.vertexColor = { ... } end
   function f:SetFont(...) self.font = { ... } end
   function f:SetText(v) self.text = v end
   function f:SetTextColor(...) self.textColor = { ... } end
   function f:SetJustifyH(v) self.justifyH = v end
   function f:SetWidth(v) self.width = v end
   function f:SetHeight(v) self.height = v end
   function f:GetCenter() return nil end
   function f:IsShown() return self.visible end
   function f:Show() self.visible = true end
   function f:Hide() self.visible = false end
   function f:StartMoving() self.moving = true end
   function f:StopMovingOrSizing() self.moving = false end
   function f:CreateTexture(_, layer)
      local texture = new_frame("Texture", nil, self)
      texture.layer = layer
      return texture
   end
   function f:CreateFontString(_, layer)
      local fs = new_frame("FontString", nil, self)
      fs.layer = layer
      return fs
   end
   frames[#frames + 1] = f
   if name then _G[name] = f end
   return f
end

function CreateFrame(kind, name, parent)
   return new_frame(kind, name, parent)
end

UIParent = new_frame("Frame", "UIParent")
Minimap = new_frame("Frame", "Minimap")
GameTooltip = {
   SetOwner = function() end,
   SetText = function() end,
   AddLine = function() end,
   Show = function() end,
}
function GameTooltip_Hide() end
C_Timer = { After = function(_, cb) cb() end }
SlashCmdList = {}
Action = {}

local forced = {}
local notifications = {}
Menagerie = {
   A = Action,
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      accent_hex = "ff8800",
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
   },
   GetToggle = function() return nil end,
   SetToggle = function() end,
   set_force_flag = function(key) forced[#forced + 1] = key end,
   show_notification = function(label) notifications[#notifications + 1] = label end,
   rotation_registry = {
      class_config = { name = "Hunter", version = "v1.0.0" },
   },
}

dofile("src/aio/widgets.lua")
dofile("src/aio/settings.lua")

if SLASH_MENAGERIE1 ~= "/menagerie" then error("brand slash should be /menagerie") end
if SLASH_MENAGERIE2 ~= nil then error("legacy /maio alias should be removed") end
if SlashCmdList["MENAGERIE"] ~= Menagerie.toggle_settings then error("/menagerie should toggle settings only") end

if SLASH_MBURST1 ~= "/mburst" then error("missing /mburst") end
if SLASH_MDEF1 ~= "/mdef" then error("missing /mdef") end
if SLASH_MGAP1 ~= "/mgap" then error("missing /mgap") end
if SLASH_MRAPTOR1 ~= "/mraptor" then error("missing /mraptor") end
if SLASH_MHELP1 ~= "/mhelp" then error("missing /mhelp") end
if SLASH_MSTATUS1 ~= nil or SlashCmdList["MSTATUS"] ~= nil then error("/mstatus should not be registered") end

SlashCmdList["MBURST"]()
SlashCmdList["MDEF"]()
SlashCmdList["MGAP"]()
SlashCmdList["MRAPTOR"]()

if table.concat(forced, ",") ~= "force_burst,force_defensive,force_gap,force_raptor" then
   error("unexpected force command sequence: " .. table.concat(forced, ","))
end
if table.concat(notifications, ",") ~= "BURST,DEFENSIVE,RAPTOR" then
   error("unexpected notifications: " .. table.concat(notifications, ","))
end

printed = {}
SlashCmdList["MHELP"]()
local help = table.concat(printed, "\n")
if not help:find("/mraptor", 1, true) then error("Hunter help should include /mraptor") end
if help:find("/mticks", 1, true) then error("Hunter help should not advertise cat tick debug") end
if help:find("/menagerie burst", 1, true) then error("help should not advertise old /menagerie subcommands") end

io.write("PASS: settings slash commands use flat m namespace\n")
`);

  assert.match(output, /PASS: settings slash commands use flat m namespace/);
}

{
  const output = runLua(String.raw`
local created_actions = {}

Action = {
   PlayerClass = "PALADIN",
   MultiUnits = {},
   Create = function(args)
      created_actions[#created_actions + 1] = args
      return args
   end,
}

Menagerie = {
   Player = {},
   Unit = function() return {} end,
   register_consumable_actions = function() end,
   rotation_registry = {
      register_class = function(_, config)
         Menagerie.registered_class = config
      end,
   },
}

function UnitFactionGroup() return "Horde" end
function print() end

dofile("src/aio/paladin/class.lua")

local A = Menagerie.A
local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

assert_equal(A.FlashOfLight.ID, 19750, "Flash of Light base spell")
assert_equal(A.FlashOfLight.useMaxRank, true, "Flash of Light uses max rank")
assert_equal(A.FlashOfLightR1.ID, 19750, "Flash of Light rank 1 spell")
assert_equal(A.FlashOfLightR6.ID, 19943, "Flash of Light rank 6 spell")
assert_equal(A.FlashOfLightR7.ID, 27137, "Flash of Light rank 7 spell")

local seen_desc = {}
for _, entry in ipairs(Menagerie.FLASH_OF_LIGHT_RANKS) do
   local desc = entry.spell.Desc
   if not desc then
      error("Flash of Light rank " .. entry.label .. " is missing unique Desc metadata")
   end
   if seen_desc[desc] then
      error("duplicate Flash of Light rank Desc: " .. desc)
   end
   seen_desc[desc] = true
end

io.write("PASS: Paladin Flash of Light ranks\n")
`);

  assert.match(output, /PASS: Paladin Flash of Light ranks/);
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
   RegisterWeaponOffHand = function() end,
}

Menagerie_SETTINGS_SCHEMA = {
   {
      name = "General",
      sections = {
         {
            header = "Shared",
            settings = {
               { type = "slider", key = "immune_learn_ttl_min", default = 5, min = 1, max = 60, label = "Immune TTL", tooltip = "", format = "%d min" },
               { type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD", tooltip = "", format = "%d sec" },
            },
         },
      },
   },
}

local unit = {}
local function aura_remaining(store, spell_id, source)
   if type(spell_id) == "table" then
      for i = 1, #spell_id do
         local remaining = aura_remaining(store, spell_id[i], source)
         if remaining > 0 then return remaining end
      end
      return 0
   end
   return store[aura_key(spell_id, source)] or 0
end
function unit:HasDeBuffs(spell_id, source)
   return aura_remaining(TestAuras.debuff, spell_id, source)
end
function unit:HasDeBuffsStacks(spell_id, source)
   return TestAuras.debuff_stacks[aura_key(spell_id, source)] or 0
end
function unit:HasBuffs(spell_id, source, byID)
   unit.last_has_buffs_by_id = byID
   return aura_remaining(TestAuras.buff, spell_id, source)
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

NS.refresh_settings(true)

if NS.cached_settings.immune_learn_ttl_min ~= 5 then
   error("expected immune_learn_ttl_min default in cached_settings")
end
if NS.cached_settings.cd_min_ttd ~= 0 then
   error("expected cd_min_ttd default in cached_settings")
end

io.write("PASS: core cached shared settings\n")
`,
  );

  assert.match(output, /PASS: core cached shared settings/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

ClearAuras()
SetBuff(10278, 5)
if not NS.has_phys_immunity("target") then error("Blessing of Protection should be physical immunity") end
if NS.has_total_immunity("target") then error("Blessing of Protection should not be total immunity") end
if NS.has_magic_immunity("target") then error("Blessing of Protection should not be magic immunity") end
if unit.last_has_buffs_by_id ~= true then error("immunity checks should match buffs by spell ID") end

ClearAuras()
SetBuff(642, 5)
if not NS.has_total_immunity("target") then error("Divine Shield should be total immunity") end
if not NS.has_phys_immunity("target") then error("total immunity should satisfy physical immunity") end
if not NS.has_magic_immunity("target") then error("total immunity should satisfy magic immunity") end
if not NS.has_cc_immunity("target") then error("total immunity should satisfy CC immunity") end
if not NS.has_stun_immunity("target") then error("total immunity should satisfy stun immunity") end
if not NS.has_kick_immunity("target") then error("total immunity should satisfy kick immunity") end

ClearAuras()
SetBuff(31224, 5)
if not NS.has_magic_immunity("target") then error("Cloak of Shadows should be magic immunity") end
if NS.has_total_immunity("target") then error("Cloak of Shadows should not be total immunity") end
if NS.has_phys_immunity("target") then error("Cloak of Shadows should not be physical immunity") end

io.write("PASS: immunity aura categories are decontaminated\n")
`,
  );

  assert.match(output, /PASS: immunity aura categories are decontaminated/);
}

{
  const output = runLua(String.raw`
function print() end

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

local function has_section(sections, header)
   for i = 1, #sections do
      if sections[i].header == header then return true end
   end
   return false
end

local function has_setting(sections, key)
   for i = 1, #sections do
      local settings = sections[i].settings or {}
      for j = 1, #settings do
         if settings[j].key == key then return true end
      end
   end
   return false
end

local function load_schema(player_class, file, expects_spec)
   Action = {
      PlayerClass = player_class,
      CurrentProfile = "test",
      Data = { ProfileEnabled = {}, ProfileUI = {} },
   }
   Menagerie_SETTINGS_SCHEMA = nil
   dofile("src/aio/common.lua")
   dofile(file)
   dofile("src/aio/profileui.lua")

   local sections = Menagerie_SETTINGS_SCHEMA[1].sections
   assert_equal(has_section(sections, "Burst Conditions"), true, player_class .. " burst tail")
   assert_equal(has_section(sections, "Dashboard"), true, player_class .. " dashboard tail")
   assert_equal(has_section(sections, "Debug"), true, player_class .. " debug tail")
   assert_equal(has_setting(sections, "immune_learn_ttl_min"), true, player_class .. " immunity setting")
   assert_equal(has_setting(sections, "cd_min_ttd"), true, player_class .. " cd setting")
   assert_equal(has_setting(sections, "playstyle"), expects_spec, player_class .. " spec selector")
   if not Action.Data.ProfileUI[2] then error(player_class .. " ProfileUI was not generated") end
end

load_schema("MAGE", "src/aio/mage/schema.lua", true)
load_schema("HUNTER", "src/aio/hunter/schema.lua", false)

io.write("PASS: real class schema UI generation\n")
`);

  assert.match(output, /PASS: real class schema UI generation/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

Action.Create = function(args) return args end
Action.MultiUnits = {}

function UnitFactionGroup() return "Horde" end

Action.PlayerClass = "PALADIN"
dofile("src/aio/paladin/class.lua")

if NS.A.HealthstoneMaster.Type ~= "Item" then error("paladin healthstone type mismatch") end
if NS.A.HealthstoneMaster.QueueForbidden ~= true then error("paladin healthstone must be queue-forbidden") end
if not NS.A.HealthstoneMaster.Click or NS.A.HealthstoneMaster.Click.unit ~= "player" then
   error("paladin healthstone must have player click target")
end
if NS.A.SuperManaPotion.Type ~= "Potion" then error("paladin mana potion must use Potion type") end

Action.PlayerClass = "WARRIOR"
dofile("src/aio/warrior/class.lua")

if NS.A.HealthstoneMaster.Type ~= "Item" then error("warrior healthstone type mismatch") end
if NS.A.HealthstoneMaster.QueueForbidden ~= true then error("warrior healthstone must be queue-forbidden") end
if not NS.A.HealthstoneMaster.Click or NS.A.HealthstoneMaster.Click.unit ~= "player" then
   error("warrior healthstone must have player click target")
end
if NS.A.SuperHealingPotion.Type ~= "Potion" then error("warrior healing potion must use Potion type") end

io.write("PASS: class consumable click injection\n")
`,
  );

  assert.match(output, /PASS: class consumable click injection/);
}

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

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local cast_left = nil
local not_kickable = false

function unit:IsCastingRemains()
   return cast_left, nil, nil, nil, not_kickable
end

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

assert_equal(NS.target_is_interruptible("target"), nil, "missing cast is not interruptible")
cast_left = 1.2
not_kickable = false
assert_equal(NS.target_is_interruptible("target"), 1.2, "kickable cast returns remaining time")
not_kickable = true
assert_equal(NS.target_is_interruptible("target"), nil, "notKickAble cast is suppressed")

local shown = 0
local kick = {
   IsReady = function(_, unit_id)
      assert_equal(unit_id, "focus", "factory uses configured unit for readiness")
      return true
   end,
   Show = function()
      shown = shown + 1
      return "kick"
   end,
}

NS.A = Action
NS.register_interrupt_middleware({
   name = "TestInterrupt",
   spell = kick,
   unit = "focus",
})

local strategy = NS.rotation_registry.middleware[1]
local context = {
   in_combat = true,
   has_valid_enemy_target = true,
   settings = {},
}

not_kickable = true
local result = strategy.execute({}, context)
assert_equal(result, nil, "factory suppresses notKickAble casts")
assert_equal(shown, 0, "factory does not show suppressed notKickAble cast")

not_kickable = false
result = strategy.execute({}, context)
assert_equal(result, "kick", "factory fires for kickable casts")
assert_equal(shown, 1, "factory shows kickable cast")

io.write("PASS: interrupt helper and factory contract\n")
`,
  );

  assert.match(output, /PASS: interrupt helper and factory contract/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie
local registered = nil
local cast_left = 1.4
local not_kickable = true
local immune = false
local ready_unit = nil
local shown = 0

function unit:IsCastingRemains()
   return cast_left, nil, nil, nil, not_kickable
end

NS.is_spell_immune = function(unit_id, spell_ids)
   if unit_id ~= "target" then error("expected target immunity unit, got " .. tostring(unit_id)) end
   local expected = { 853, 5588, 5589, 10308 }
   for i = 1, #expected do
      if spell_ids[i] ~= expected[i] then
         error("HoJ immunity spell id " .. i .. " expected " .. expected[i] .. ", got " .. tostring(spell_ids[i]))
      end
   end
   return immune
end

Action.PlayerClass = "PALADIN"
Action.MultiUnits = {}
NS.A = {
   HammerOfJustice = {
      IsReady = function(_, unit_id)
         ready_unit = unit_id
         return true
      end,
      Show = function()
         shown = shown + 1
         return "hoj"
      end,
   },
}

NS.rotation_registry.register_middleware = function(_, entry)
   if entry.name == "Paladin_HammerOfJustice" then
      registered = entry
   end
end

dofile("src/aio/paladin/middleware.lua")

if not registered then error("expected Paladin_HammerOfJustice middleware") end

local context = {
   in_combat = true,
   has_valid_enemy_target = true,
   settings = { use_hammer_of_justice = true },
}

if not registered.matches(context) then error("HoJ should match a valid non-immune target") end
local result, log_msg = registered.execute({}, context)
if result ~= "hoj" then error("HoJ should fire on a non-kickable cast, got " .. tostring(result)) end
if ready_unit ~= "target" then error("HoJ readiness should check target, got " .. tostring(ready_unit)) end
if not string.find(log_msg, "stun%-interrupt") then error("HoJ log should identify stun-interrupt path") end
if shown ~= 1 then error("HoJ should show once, got " .. tostring(shown)) end

not_kickable = false
result = registered.execute({}, context)
if result ~= "hoj" then error("HoJ should still fire on a kickable cast, got " .. tostring(result)) end
if shown ~= 2 then error("HoJ should show for kickable and non-kickable casts, got " .. tostring(shown)) end

immune = true
if registered.matches(context) then error("HoJ should be suppressed by learned stun immunity") end

context.settings.use_hammer_of_justice = false
immune = false
if registered.matches(context) then error("HoJ should respect use_hammer_of_justice setting") end

io.write("PASS: Paladin HoJ stun-interrupt middleware\n")
`,
  );

  assert.match(output, /PASS: Paladin HoJ stun-interrupt middleware/);
}

{
  const output = runLua(String.raw`
function print() end

local created = {}
local function new_frame(kind, name)
   local f = { kind = kind, name = name, scripts = {}, visible = false }
   function f:SetSize(w, h) self.width = w; self.height = h end
   function f:SetPoint(...) self.point = { ... } end
   function f:ClearAllPoints() self.point = nil end
   function f:SetBackdrop(backdrop) self.backdrop = backdrop end
   function f:SetBackdropColor(...) self.backdropColor = { ... } end
   function f:SetBackdropBorderColor(...) self.borderColor = { ... } end
   function f:SetMovable(v) self.movable = v end
   function f:SetResizable(v) self.resizable = v end
   function f:EnableMouse(v) self.mouse = v end
   function f:EnableMouseWheel(v) self.mouseWheel = v end
   function f:SetClampedToScreen(v) self.clamped = v end
   function f:RegisterForDrag(...) self.drag = { ... } end
   function f:SetScript(event, cb) self.scripts[event] = cb end
   function f:SetFrameStrata(strata) self.strata = strata end
   function f:SetScrollChild(child) self.scrollChild = child end
   function f:SetMultiLine(v) self.multiLine = v end
   function f:SetFontObject(obj) self.fontObject = obj end
   function f:SetWidth(w) self.width = w end
   function f:SetAutoFocus(v) self.autoFocus = v end
   function f:SetText(text) self.text = text end
   function f:SetTextColor(...) self.textColor = { ... } end
   function f:HighlightText() self.highlighted = true end
   function f:SetFocus() self.focused = true end
   function f:Hide() self.visible = false end
   function f:Show() self.visible = true end
   function f:CreateFontString()
      return new_frame("FontString")
   end
   function f:CreateTexture()
      local texture = new_frame("Texture")
      function texture:SetHeight(h) self.height = h end
      function texture:SetColorTexture(...) self.color = { ... } end
      return texture
   end
   created[#created + 1] = f
   return f
end

function CreateFrame(kind, name)
   return new_frame(kind, name)
end

UIParent = {}
SlashCmdList = {}
Menagerie = {
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
   },
}

dofile("src/aio/widgets.lua")
dofile("src/aio/debug.lua")

local first = Menagerie.ShowCopyWindow("First Export", "alpha")
local second = Menagerie.ShowCopyWindow("Second Export", "beta")

if not first then error("ShowCopyWindow should return the shared frame") end
if first ~= second then error("ShowCopyWindow should reuse a singleton frame") end
if first.title.text ~= "Second Export" then error("ShowCopyWindow should update the title") end
if first.editBox.text ~= "beta" then error("ShowCopyWindow should update edit text") end
if first.editBox.highlighted ~= true then error("ShowCopyWindow should select the text") end
if first.editBox.focused ~= true then error("ShowCopyWindow should focus the edit box") end
if first.visible ~= true then error("ShowCopyWindow should show the frame") end

io.write("PASS: shared copy window singleton\n")
`);

  assert.match(output, /PASS: shared copy window singleton/);
}

{
  const output = runLua(String.raw`
local now = 1
function GetTime() return now end
function date() return "12:34:56" end
function print() end

SlashCmdList = {}
Menagerie = {
   cached_settings = { debug_mode = false },
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
   },
}

dofile("src/aio/widgets.lua")
dofile("src/aio/debug.lua")

local tostring_calls = 0
local expensive = setmetatable({}, {
   __tostring = function()
      tostring_calls = tostring_calls + 1
      return "expensive"
   end,
})

Menagerie.debug_print(expensive)
if tostring_calls ~= 0 then error("debug_print should not stringify args when debug_mode is off") end

local hidden = Menagerie.debug_log("TEST", "TRACE", false, "%s", "hidden")
if hidden ~= nil then error("debug_log should skip non-forced entries when debug_mode is off") end

local forced = Menagerie.debug_log("TEST", "ERROR", true, "%s", "visible")
if not forced then error("forced debug_log should still emit when debug_mode is off") end
if forced.text ~= "visible" then error("forced debug_log should format text") end
if SLASH_MENAGERIELOG1 ~= "/mlog" then error("debug log primary slash should be /mlog") end
if SLASH_MENAGERIELOG2 ~= nil then error("legacy /menagerielog alias should not be registered") end

io.write("PASS: debug substrate respects debug_mode gate\n")
`);

  assert.match(output, /PASS: debug substrate respects debug_mode gate/);
}

{
  const output = runLua(String.raw`
function print() end

local now = 1
TMW = { time = now, UPD_INTV = 0.05 }

Action = {
   PlayerClass = "HUNTER",
   Listener = { Add = function() end },
   GetCurrentGCD = function() return 0 end,
   GetLatency = function() return 0 end,
}

local function never_ready() return false end

Menagerie = {
   cached_settings = {
      weapon_speed = 2.9,
      inhouse_swingshot = false,
      mana_save = 30,
      aoe = false,
      use_arcane = false,
      show_adaptive_panel = false,
   },
   A = {
      Listener = Action.Listener,
      GetCurrentGCD = Action.GetCurrentGCD,
      GetLatency = Action.GetLatency,
      MortalShots = { GetTalentRank = function() return 0 end },
      MultiShot = { IsReady = never_ready },
      ArcaneShot = { IsReady = never_ready },
   },
   Player = {
      GetSwingShoot = function() return 1.0 end,
      ManaPercentage = function() return 100 end,
   },
}

function GetTime() return now end
function UnitRangedAttackPower() return 1200, 0, 0 end
function UnitRangedDamage() return 2.9, 500, 600, 0, 0, 1 end
function GetRangedCritChance() return 25 end
function UnitBuff() return nil end
function UnitGUID() return "Player-1" end
function GetCVar() return "400" end
function CombatLogGetCurrentEventInfo() return nil end

dofile("src/aio/hunter/adaptive.lua")

local HA = Menagerie.HunterAdaptive
if not HA then error("adaptive module did not load") end

HA.ChooseAction("target", { useMulti = false, useArcane = false, manaPct = 100 })
local state = HA.GetState()
if state.lastDecision.now ~= 1 then error("lastDecision should update while panel is closed") end
if #state.decisionLog ~= 0 then error("decisionLog should not accrue while panel is closed") end

now = 2
TMW.time = now
Menagerie.cached_settings.show_adaptive_panel = true
HA.ChooseAction("target", { useMulti = false, useArcane = false, manaPct = 100 })
if #state.decisionLog ~= 1 then error("decisionLog should accrue while panel is open") end

now = 3
TMW.time = now
Menagerie.cached_settings.show_adaptive_panel = false
HA.ChooseAction("target", { useMulti = false, useArcane = false, manaPct = 100 })
if state.lastDecision.now ~= 3 then error("lastDecision should keep updating after panel closes") end
if #state.decisionLog ~= 1 then error("decisionLog should stop accruing after panel closes") end

io.write("PASS: adaptive decision log panel gate\n")
`);

  assert.match(output, /PASS: adaptive decision log panel gate/);
}

{
  const output = runLua(String.raw`
function print() end
function wipe(t) for k in pairs(t) do t[k] = nil end end

local frame = { scripts = {}, elapsed = 0 }
function frame:SetScript(event, cb) self.scripts[event] = cb end
function frame:IsShown() return false end

function CreateFrame() return frame end
UIParent = {}

Action = {
   PlayerClass = "HUNTER",
   Listener = { Add = function() end },
   GetLatency = function() return 0 end,
   GetPing = function() return 0 end,
}

Menagerie = {
   Theme = {
      bg = { 0, 0, 0 },
      bg_widget = { 0.1, 0.1, 0.1 },
      bg_hover = { 0.2, 0.2, 0.2 },
      border = { 0.3, 0.3, 0.3 },
      accent = { 1, 0.8, 0.4 },
      text = { 1, 1, 1 },
      text_dim = { 0.7, 0.7, 0.7 },
      state = {},
   },
   cached_settings = {},
}

function GetTime() return 0 end
function UnitRangedDamage() return 2.9 end
function UnitGUID() return "Player-1" end
function CombatLogGetCurrentEventInfo() return nil end
function date() return "2026-06-15 00:00:00" end
function time() return 0 end
function GetSpellInfo(spell) return tostring(spell) end
function GetFramerate() return 60 end

dofile("src/aio/widgets.lua")
dofile("src/aio/hunter/cliptracker.lua")

if Menagerie.HunterClipTracker.ClipLogMax ~= 500 then
   error("ClipLogMax expected 500, got " .. tostring(Menagerie.HunterClipTracker.ClipLogMax))
end

io.write("PASS: clip log cap\n")
`);

  assert.match(output, /PASS: clip log cap/);
}

{
  const output = runLua(String.raw`
function print() end

dofile("src/aio/common.lua")

local S = Menagerie_SECTIONS

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

local immunity = S.immunity()
assert_equal(immunity.header, "Immunity Learning", "immunity header")
assert_equal(immunity.settings[1].key, "immune_learn_ttl_min", "immunity setting key")
assert_equal(immunity.settings[1].default, 5, "immunity ttl default")

local cooldowns = S.cooldowns()
assert_equal(cooldowns.header, "Cooldown Management", "cooldowns header")
assert_equal(cooldowns.settings[1].key, "cd_min_ttd", "cooldown setting key")

local spec_options = {
   { value = "fire", text = "Fire" },
   { value = "arcane", text = "Arcane" },
}
local spec = S.spec({ default = "arcane", options = spec_options })
assert_equal(spec.header, "Spec Selection", "spec header")
assert_equal(spec.settings[1].key, "playstyle", "spec setting key")
assert_equal(spec.settings[1].default, "arcane", "spec default")
assert_equal(spec.settings[1].options, spec_options, "spec options passthrough")

io.write("PASS: schema section factories\n")
`);

  assert.match(output, /PASS: schema section factories/);
}

{
  const output = runLua(String.raw`
function print() end

Action = {
   Data = {},
}

dofile("src/aio/common.lua")

Menagerie_SETTINGS_SCHEMA = {
   {
      name = "General",
      sections = {
         { header = "General", settings = {} },
      },
   },
}

dofile("src/aio/profileui.lua")

local sections = Menagerie_SETTINGS_SCHEMA[1].sections
if #sections ~= 4 then
   error("expected 4 General sections after default tail, got " .. tostring(#sections))
end
if sections[2].header ~= "Burst Conditions" then error("expected Burst tail section") end
if sections[3].header ~= "Dashboard" then error("expected Dashboard tail section") end
if sections[4].header ~= "Debug" then error("expected Debug tail section") end

io.write("PASS: default schema tail append\n")
`);

  assert.match(output, /PASS: default schema tail append/);
}

{
  const output = runLua(String.raw`
function print() end

Action = {
   Data = {},
}

dofile("src/aio/common.lua")

Menagerie_SETTINGS_SCHEMA = {
   no_default_tail = true,
   {
      name = "General",
      sections = {
         { header = "General", settings = {} },
      },
   },
}

dofile("src/aio/profileui.lua")

local sections = Menagerie_SETTINGS_SCHEMA[1].sections
if #sections ~= 1 then
   error("expected opt-out to preserve 1 section, got " .. tostring(#sections))
end

io.write("PASS: default schema tail opt-out\n")
`);

  assert.match(output, /PASS: default schema tail opt-out/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

local created = {}
Action.Create = function(args)
   created[#created + 1] = args
   return args
end

local A = { Create = Action.Create }
setmetatable(A, { __index = Action })

NS.register_consumable_actions(A)

local function assert_equal(actual, expected, label)
   if actual ~= expected then
      error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

assert_equal(A.SuperHealingPotion.ID, 22829, "super healing potion id")
assert_equal(A.SuperHealingPotion.Type, "Potion", "super healing potion type")
assert_equal(A.SuperManaPotion.Type, "Potion", "super mana potion type")
assert_equal(A.DarkRune.Type, "Item", "dark rune type")
assert_equal(A.HealthstoneFel.ID, 22103, "fel healthstone id")
assert_equal(A.HealthstoneFel.QueueForbidden, true, "fel healthstone queue forbidden")
assert_equal(A.HealthstoneFel.Click.unit, "player", "fel healthstone click unit")
assert_equal(#created, 8, "injected consumable count")

io.write("PASS: consumable action injector\n")
`,
  );

  assert.match(output, /PASS: consumable action injector/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

local function ready_action(name)
   return {
      name = name,
      IsReady = function() return true end,
      Show = function() return "show:" .. name end,
   }
end

local skipped = ready_action("skipped")
local used = ready_action("used")

local strategy = NS.create_racial_strategy({
   prefix = "TEST",
   extra_match = function() return false end,
   spells = {
      { skipped, "Skipped" },
   },
})

if strategy.matches({ settings = {}, target_ttd = 500 }) then
   error("strategy-wide extra_match should suppress ready racial")
end

strategy = NS.create_racial_strategy({
   prefix = "TEST",
   spells = {
      { skipped, "Skipped", function() return false end },
      { used, "Used" },
   },
})

local context = { settings = {}, target_ttd = 500 }
if not strategy.matches(context) then
   error("per-spell predicate should allow later ready racial")
end

local result, log_msg = strategy.execute({}, context)
if result ~= "show:used" then
   error("expected second racial action, got " .. tostring(result))
end
if log_msg ~= "[TEST] Used" then
   error("expected second racial log, got " .. tostring(log_msg))
end

io.write("PASS: racial strategy predicates\n")
`,
  );

  assert.match(output, /PASS: racial strategy predicates/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

local ready = { IsReady = function() return false end }
NS.A = { Trinket1 = ready, Trinket2 = ready }

NS.rotation_registry:register_class({ playstyles = { "test" } })
if #NS.rotation_registry.middleware ~= 2 then
   error("expected auto trinkets to register 2 middleware entries, got " .. tostring(#NS.rotation_registry.middleware))
end

io.write("PASS: trinket auto-registration\n")
`,
  );

  assert.match(output, /PASS: trinket auto-registration/);
}

{
  const output = runLua(
    loadCore +
      String.raw`
local NS = Menagerie

local ready = { IsReady = function() return false end }
NS.A = { Trinket1 = ready, Trinket2 = ready }

NS.rotation_registry:register_class({ playstyles = { "test" }, auto_trinkets = false })
if #NS.rotation_registry.middleware ~= 0 then
   error("expected trinket opt-out to register nothing, got " .. tostring(#NS.rotation_registry.middleware))
end

io.write("PASS: trinket auto-registration opt-out\n")
`,
  );

  assert.match(output, /PASS: trinket auto-registration opt-out/);
}
