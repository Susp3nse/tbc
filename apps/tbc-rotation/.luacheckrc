-- Static analysis for the hand-written Menagerie rotation Lua.
--
-- Catches the "simple bugs" that otherwise only surface on an in-game reload:
-- typo'd API names, accidental globals, unused/shadowed locals. It does NOT run
-- the rotation; it is pure static analysis against the global surface below.
--
-- Run:  corepack pnpm --filter @menagerie/tbc-rotation lint:lua
-- Needs the `luacheck` binary (brew install luacheck  /  luarocks install luacheck).

std = "lua51" -- WoW's embedded interpreter
codes = true
cache = true
max_line_length = false -- rotation source is intentionally wide

-- The strategy-registry callbacks have fixed signatures —
-- matches(context, state) / execute(icon, context, state) — and most entries
-- legitimately ignore some params. Unused *arguments* are by-design here; unused
-- *locals* (W211) and unused *values* (W311) are still reported, as they should be.
unused_args = false

-- Lint only the hand-written source. The compiled TMW bundle (output/) and the
-- profile template are generated/foreign — never lint them.
include_files = { "src/aio/**/*.lua" }
exclude_files = { "output", "src/tmw-template.lua", "**/dist" }

-- Globals the addon itself owns (read + write). Adding a new `_G.Menagerie*` global
-- or `/menagerie` slash command? Add it here.
globals = {
  "Menagerie",
  "Menagerie_ResyncFired",
  "Menagerie_SECTIONS",
  "Menagerie_SETTINGS_SCHEMA",
  "MenagerieClipDumps",
  "SLASH_MENAGERIE1",
  "SLASH_MENAGERIE2",
  "SLASH_MENAGERIEDEBUG1",
  "SLASH_MENAGERIELOG1",
  "SLASH_MENAGERIELOG2",
  "SLASH_MENAGERIEDASH1",
  "SLASH_MENAGERIETICKS1",
  "SLASH_MBURST1",
  "SLASH_MDEF1",
  "SLASH_MGAP1",
  "SLASH_MHELP1",
  "SLASH_MRAPTOR1",
  "SlashCmdList",
  "UISpecialFrames",
}

-- WoW client + GGL Action/TMW framework API actually referenced bare in the
-- source (read-only). The codebase localizes most WoW calls via `local X =
-- _G.X`, which luacheck never flags; this list covers the bare references.
-- Using a new WoW API bare? Add the exact name here (a missing entry is the
-- intended signal that catches a typo).
read_globals = {
  -- framework handles. Each class.lua registers its spells by writing computed
  -- fields onto Action, so its fields are writable (otherwise W122 fires).
  Action = { read_only = false, other_fields = true },
  "TMW",
  "LibStub",
  "Toaster",
  -- frames / UI
  "CreateFrame",
  "UIParent",
  "Minimap",
  "GameTooltip",
  "GameTooltip_Hide",
  -- engine / timers
  "C_Timer",
  "C_Spell",
  "GetTime",
  "GetFramerate",
  "GetCVar",
  "date",
  "time",
  "wipe",
  "CombatLogGetCurrentEventInfo",
  -- spells / items
  "GetSpellInfo",
  "GetSpellTexture",
  "GetSpellCooldown",
  "GetSpellBonusHealing",
  "GetRangedCritChance",
  "IsCurrentSpell",
  "IsSpellInRange",
  "IsSpellKnown",
  "GetItemCount",
  "GetInventoryItemID",
  "GetInventoryItemTexture",
  "GetInventoryItemCooldown",
  "GetTotemInfo",
  "GetWeaponEnchantInfo",
  -- units
  "UnitExists",
  "UnitName",
  "UnitClass",
  "UnitClassification",
  "UnitCreatureType",
  "UnitGUID",
  "UnitIsUnit",
  "UnitIsPlayer",
  "UnitIsDead",
  "UnitIsDeadOrGhost",
  "UnitIsConnected",
  "UnitIsVisible",
  "UnitHealth",
  "UnitHealthMax",
  "UnitPower",
  "UnitPowerMax",
  "UnitCanAttack",
  "UnitCanAssist",
  "UnitAffectingCombat",
  "UnitInRange",
  "UnitBuff",
  "UnitFactionGroup",
  "UnitRangedDamage",
  "UnitRangedAttackPower",
  "UnitThreatSituation",
  "UnitDetailedThreatSituation",
  "UnitGroupRolesAssigned",
  -- group / misc
  "IsInGroup",
  "IsInRaid",
  "IsResting",
  "GetNumGroupMembers",
}
