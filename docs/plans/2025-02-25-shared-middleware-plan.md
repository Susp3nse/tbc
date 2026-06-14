# Shared Middleware Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add three shared middleware modules (recovery, threat, interrupt) that eliminate code duplication and add PvE intelligence across all 9 classes.

**Architecture:** Factory Registration pattern — shared Lua modules in `rotation/source/aio/` provide factory functions, each class opts in from their `middleware.lua`. Build system loads shared files at Order 6 (after core.lua, before class middleware).

**Tech Stack:** Lua 5.1 (WoW embedded), Node.js build system

**Design doc:** `docs/plans/2025-02-25-shared-middleware-design.md`

---

## Task Summary

### Phase 1: Build System + Recovery Consolidation
| # | Task | What it does |
|---|------|-------------|
| 1 | Update build.js | Add recovery.lua, threat.lua, interrupt.lua to ORDER_MAP + LOAD_ORDER (Order 6, shared) |
| 2 | Create recovery.lua | Shared factory: `NS.register_recovery_middleware(class, config)` for Healthstone, Healing Potion, Mana Potion, Dark Rune |
| 3 | Migrate Hunter | Replace 3 recovery MW blocks with factory call (custom tiers: HSMaster1/2/3, stealth check, mana_rune keys) |
| 4 | Migrate Mage | Replace 4 recovery MW blocks with factory call (all defaults) |
| 5 | Migrate Paladin | Replace 4 recovery MW blocks with factory call (custom mana defaults: 40%) |
| 6 | Migrate Priest | Replace 4 recovery MW blocks with factory call (all defaults). Keep Shadowfiend. |
| 7 | Migrate Rogue | Replace 2 recovery MW blocks with factory call (no mana items). Keep Thistle Tea. |
| 8 | Migrate Shaman | Replace 4 recovery MW blocks with factory call (MajorManaPotion fallback tier). |
| 9 | Migrate Warlock | Replace 4 recovery MW blocks with factory call (HealthstoneFel tier, lower mana thresholds). Keep Life Tap, Dark Pact. |
| 10 | Migrate Warrior | Replace 2 recovery MW blocks with factory call (no mana items). Keep Bandages. |

### Phase 2: Threat Awareness System
| # | Task | What it does |
|---|------|-------------|
| 11 | Create threat.lua | Shared factory: `NS.register_threat_middleware(class, config)`. Nameplate scanning, classification counting, TTD awareness, configurable mode (dump/stop/off) + scope (boss/elite/all) |
| 12 | Add threat settings to schemas | Add `threat_mode` + `threat_scope` dropdowns to all 8 DPS class schemas |
| 13 | Register threat + remove old dumps | Register all classes for shared threat. Remove Hunter_FeignDeath, Rogue_Feint, Warlock_Soulshatter, Priest_Fade MW blocks. |

### Phase 3: Interrupt Awareness System
| # | Task | What it does |
|---|------|-------------|
| 14 | Create interrupt.lua | Priority spell DB (44+ spells from Shaman), `NS.should_interrupt()` decision function, tab-target state machine, nameplate scanner, combat log SPELL_INTERRUPT dedup, original target validation on return |
| 15 | Add interrupt settings to schemas | Add `interrupt_priority_only`, `interrupt_scope`, `interrupt_delay` to 6 class schemas (Mage, Paladin, Priest, Rogue, Shaman, Warrior) |
| 16 | Integrate interrupt awareness | Update all 6 class interrupt MW to use `NS.should_interrupt()`. Shaman/Mage/Priest get tab-targeting. Register capabilities with `resolve_spell` pattern. Remove Shaman's local priority table + state machine. |

### Phase 4: Final Verification
| # | Task | What it does |
|---|------|-------------|
| 17 | Build verification + cleanup | Full build, remove dead code (Priest's count_mobs_targeting_me, Shaman's PRIORITY_INTERRUPT_SPELLS, orphaned locals) |

---

## Phase 1: Build System + Recovery Consolidation

### Task 1: Update build.js for new shared files

**Files:**
- Modify: `rotation/build.js` (ORDER_MAP + LOAD_ORDER)

**Step 1: Add new files to ORDER_MAP and LOAD_ORDER**

In `rotation/build.js`, add `recovery.lua`, `threat.lua`, and `interrupt.lua` to both maps. They load at Order 6 (same as `settings.lua` and `healing.lua` — no mutual dependencies).

In `ORDER_MAP` (~line 77), add three entries:

```js
const ORDER_MAP = {
  'common.lua':     1,
  'schema.lua':     2,
  'ui.lua':         3,
  'core.lua':       4,
  'class.lua':      5,
  'healing.lua':    6,
  'settings.lua':   6,
  'recovery.lua':   6,   // NEW: shared recovery item factories
  'threat.lua':     6,   // NEW: shared threat awareness
  'interrupt.lua':  6,   // NEW: shared interrupt decisions
  'middleware.lua':  7,
  'dashboard.lua':  8,
  'main.lua':       9,
};
```

In `LOAD_ORDER` (~line 91), add three shared slots between `settings.lua` and class `middleware.lua`:

```js
const LOAD_ORDER = [
  { slot: 'shared', source: 'common.lua' },
  { slot: 'class', source: 'schema.lua' },
  { slot: 'shared', source: 'ui.lua' },
  { slot: 'shared', source: 'core.lua' },
  { slot: 'class', source: 'class.lua' },
  { slot: 'class', source: 'healing.lua' },
  { slot: 'shared', source: 'settings.lua' },
  { slot: 'shared', source: 'recovery.lua' },   // NEW
  { slot: 'shared', source: 'threat.lua' },      // NEW
  { slot: 'shared', source: 'interrupt.lua' },   // NEW
  { slot: 'class', source: 'middleware.lua' },
  // ... remaining class files (Order 7) inserted here alphabetically ...
  { slot: 'shared', source: 'dashboard.lua' },
  { slot: 'shared', source: 'main.lua' },
];
```

**Step 2: Verify build succeeds**

Run: `cd rotation && node build.js`
Expected: Build succeeds (new shared files don't exist yet, so they're simply skipped — `sharedFiles.includes()` returns false for missing files).

**Step 3: Commit**

```bash
git add rotation/build.js
git commit -m "build: add shared recovery/threat/interrupt to load order"
```

---

### Task 2: Create recovery.lua — shared recovery item factory

**Files:**
- Create: `rotation/source/aio/recovery.lua`

**Step 1: Write the shared recovery module**

This module provides `NS.register_recovery_middleware(class_name, config)` which generates Healthstone, Healing Potion, Mana Potion, and Dark Rune middleware entries.

```lua
-- Menagerie - Shared Recovery Item Middleware
-- Provides factory for common consumable middleware (Healthstone, Healing Potion, Mana Potion, Dark Rune)
-- Classes call NS.register_recovery_middleware() from their middleware.lua

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Recovery]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local DetermineUsableObject = A.DetermineUsableObject
local format = string.format

local PLAYER_UNIT = "player"

-- ============================================================================
-- RECOVERY MIDDLEWARE FACTORY
-- ============================================================================

--- Register standard recovery item middleware for a class.
--- @param class_name string  Class display name (e.g. "Mage", "Warrior")
--- @param config table       Items to register. Keys: healthstone, healing_potion, mana_potion, dark_rune
---   Each value is `true` (use defaults) or a table with overrides:
---     healthstone:    { tiers = {spell1, spell2, ...}, extra_match = function(ctx) }
---     healing_potion: { default_hp = number }
---     mana_potion:    { default_pct = number, tiers = {spell1, ...}, priority_offset = number }
---     dark_rune:      { default_pct = number, default_min_hp = number, priority_offset = number,
---                       setting_toggle = string, setting_threshold = string, setting_min_hp = string }
function NS.register_recovery_middleware(class_name, config)
    if not config then return end

    -- HEALTHSTONE
    if config.healthstone then
        local hs_cfg = type(config.healthstone) == "table" and config.healthstone or {}
        local tiers = hs_cfg.tiers or { A.HealthstoneMaster, A.HealthstoneMajor }
        local extra_match = hs_cfg.extra_match

        rotation_registry:register_middleware({
            name = class_name .. "_Healthstone",
            priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,

            matches = function(context)
                if not context.in_combat then return false end
                if extra_match and not extra_match(context) then return false end
                local threshold = context.settings.healthstone_hp or 0
                if threshold <= 0 then return false end
                if context.hp > threshold then return false end
                return true
            end,

            execute = function(icon, context)
                local obj = DetermineUsableObject(PLAYER_UNIT, true, nil, true, nil, unpack(tiers))
                if obj then
                    return obj:Show(icon), format("[MW] Healthstone - HP: %.0f%%", context.hp)
                end
                return nil
            end,
        })
    end

    -- HEALING POTION
    if config.healing_potion then
        local hp_cfg = type(config.healing_potion) == "table" and config.healing_potion or {}
        local default_hp = hp_cfg.default_hp or 25

        rotation_registry:register_middleware({
            name = class_name .. "_HealingPotion",
            priority = Priority.MIDDLEWARE.RECOVERY_ITEMS - 5,
            setting_key = "use_healing_potion",

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings.healing_potion_hp or default_hp
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
    end

    -- MANA POTION
    if config.mana_potion then
        local mp_cfg = type(config.mana_potion) == "table" and config.mana_potion or {}
        local default_pct = mp_cfg.default_pct or 50
        local priority_offset = mp_cfg.priority_offset or 0
        local tiers = mp_cfg.tiers or { A.SuperManaPotion }

        rotation_registry:register_middleware({
            name = class_name .. "_ManaPotion",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY + priority_offset,
            setting_key = "use_mana_potion",

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings.mana_potion_pct or default_pct
                if context.mana_pct > threshold then return false end
                return true
            end,

            execute = function(icon, context)
                for i = 1, #tiers do
                    if tiers[i]:IsReady(PLAYER_UNIT) then
                        return tiers[i]:Show(icon), format("[MW] Mana Potion - Mana: %.0f%%", context.mana_pct)
                    end
                end
                return nil
            end,
        })
    end

    -- DARK / DEMONIC RUNE
    if config.dark_rune then
        local dr_cfg = type(config.dark_rune) == "table" and config.dark_rune or {}
        local default_pct = dr_cfg.default_pct or 50
        local default_min_hp = dr_cfg.default_min_hp or 50
        local priority_offset = dr_cfg.priority_offset or -5
        local setting_toggle = dr_cfg.setting_toggle or "use_dark_rune"
        local setting_threshold = dr_cfg.setting_threshold or "dark_rune_pct"
        local setting_min_hp = dr_cfg.setting_min_hp or "dark_rune_min_hp"

        rotation_registry:register_middleware({
            name = class_name .. "_DarkRune",
            priority = Priority.MIDDLEWARE.MANA_RECOVERY + priority_offset,
            setting_key = setting_toggle,

            matches = function(context)
                if not context.in_combat then return false end
                if context.combat_time < 2 then return false end
                local threshold = context.settings[setting_threshold] or default_pct
                if context.mana_pct > threshold then return false end
                local min_hp = context.settings[setting_min_hp] or default_min_hp
                if context.hp < min_hp then return false end
                return true
            end,

            execute = function(icon, context)
                if A.DarkRune:IsReady(PLAYER_UNIT) then
                    return A.DarkRune:Show(icon), format("[MW] Dark Rune - Mana: %.0f%%", context.mana_pct)
                end
                if A.DemonicRune:IsReady(PLAYER_UNIT) then
                    return A.DemonicRune:Show(icon), format("[MW] Demonic Rune - Mana: %.0f%%", context.mana_pct)
                end
                return nil
            end,
        })
    end
end
```

**Step 2: Verify build succeeds**

Run: `cd rotation && node build.js`
Expected: Build succeeds, recovery.lua included in output.

**Step 3: Commit**

```bash
git add rotation/source/aio/recovery.lua
git commit -m "feat: add shared recovery middleware factory"
```

---

### Task 3: Migrate Hunter to shared recovery

**Files:**
- Modify: `rotation/source/aio/hunter/middleware.lua`

**Step 1: Replace Hunter recovery middleware with factory call**

At the top of the file (after the existing local references), add the factory call. Then remove the 3 individual middleware registrations (Hunter_Healthstone, Hunter_HealingPotion, Hunter_ManaRune).

Add factory call near the top of the middleware registration section:

```lua
-- ============================================================================
-- SHARED RECOVERY ITEMS (Healthstone, Healing Potion, Dark Rune)
-- ============================================================================
NS.register_recovery_middleware("Hunter", {
    healthstone = {
        tiers = { A.HSMaster1, A.HSMaster2, A.HSMaster3 },
        extra_match = function(context) return not Player:IsStealthed() end,
    },
    healing_potion = { default_hp = 35 },
    dark_rune = {
        setting_toggle = "use_mana_rune",
        setting_threshold = "mana_rune_mana",
        default_pct = 20,
    },
})
```

Remove the old `Hunter_Healthstone`, `Hunter_HealingPotion`, and `Hunter_ManaRune` middleware blocks.

**Step 2: Verify build succeeds**

Run: `cd rotation && node build.js`

**Step 3: Commit**

```bash
git add rotation/source/aio/hunter/middleware.lua
git commit -m "refactor(hunter): migrate recovery items to shared factory"
```

---

### Task 4: Migrate Mage to shared recovery

**Files:**
- Modify: `rotation/source/aio/mage/middleware.lua`

**Step 1: Replace Mage recovery middleware with factory call**

Add factory call, remove `Mage_Healthstone`, `Mage_HealingPotion`, `Mage_ManaPotion`, `Mage_DarkRune` blocks:

```lua
-- ============================================================================
-- SHARED RECOVERY ITEMS (Healthstone, Healing Potion, Mana Potion, Dark Rune)
-- ============================================================================
NS.register_recovery_middleware("Mage", {
    healthstone = true,
    healing_potion = true,
    mana_potion = true,
    dark_rune = true,
})
```

Keep Mage-specific items: `Mage_ManaGem`, `Mage_Evocation`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/mage/middleware.lua
git commit -m "refactor(mage): migrate recovery items to shared factory"
```

---

### Task 5: Migrate Paladin to shared recovery

**Files:**
- Modify: `rotation/source/aio/paladin/middleware.lua`

**Step 1: Replace Paladin recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Paladin", {
    healthstone = true,
    healing_potion = true,
    mana_potion = { default_pct = 40 },
    dark_rune = { default_pct = 40 },
})
```

Remove `Paladin_Healthstone`, `Paladin_HealingPotion`, `Paladin_ManaPotion`, `Paladin_DarkRune`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/paladin/middleware.lua
git commit -m "refactor(paladin): migrate recovery items to shared factory"
```

---

### Task 6: Migrate Priest to shared recovery

**Files:**
- Modify: `rotation/source/aio/priest/middleware.lua`

**Step 1: Replace Priest recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Priest", {
    healthstone = true,
    healing_potion = true,
    mana_potion = true,
    dark_rune = true,
})
```

Remove `Priest_Healthstone`, `Priest_HealingPotion`, `Priest_ManaPotion`, `Priest_DarkRune`.
Keep: `Priest_Shadowfiend`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/priest/middleware.lua
git commit -m "refactor(priest): migrate recovery items to shared factory"
```

---

### Task 7: Migrate Rogue to shared recovery

**Files:**
- Modify: `rotation/source/aio/rogue/middleware.lua`

**Step 1: Replace Rogue recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Rogue", {
    healthstone = true,
    healing_potion = true,
})
```

Remove `Rogue_Healthstone`, `Rogue_HealingPotion`.
Keep: `Rogue_ThistleTea`, `Rogue_HastePotion`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/rogue/middleware.lua
git commit -m "refactor(rogue): migrate recovery items to shared factory"
```

---

### Task 8: Migrate Shaman to shared recovery

**Files:**
- Modify: `rotation/source/aio/shaman/middleware.lua`

**Step 1: Replace Shaman recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Shaman", {
    healthstone = true,
    healing_potion = true,
    mana_potion = { tiers = { A.SuperManaPotion, A.MajorManaPotion } },
    dark_rune = true,
})
```

Remove `Shaman_Healthstone`, `Shaman_HealingPotion`, `Shaman_ManaPotion`, `Shaman_DarkRune`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/shaman/middleware.lua
git commit -m "refactor(shaman): migrate recovery items to shared factory"
```

---

### Task 9: Migrate Warlock to shared recovery

**Files:**
- Modify: `rotation/source/aio/warlock/middleware.lua`

**Step 1: Replace Warlock recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Warlock", {
    healthstone = { tiers = { A.HealthstoneFel, A.HealthstoneMaster, A.HealthstoneMajor } },
    healing_potion = true,
    mana_potion = { default_pct = 30, priority_offset = -5 },
    dark_rune = { default_pct = 30, priority_offset = -10 },
})
```

Remove `Warlock_Healthstone`, `Warlock_HealingPotion`, `Warlock_ManaPotion`, `Warlock_DarkRune`.
Keep: `Warlock_DarkPact`, `Warlock_LifeTap`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/warlock/middleware.lua
git commit -m "refactor(warlock): migrate recovery items to shared factory"
```

---

### Task 10: Migrate Warrior to shared recovery

**Files:**
- Modify: `rotation/source/aio/warrior/middleware.lua`

**Step 1: Replace Warrior recovery middleware with factory call**

```lua
NS.register_recovery_middleware("Warrior", {
    healthstone = true,
    healing_potion = true,
})
```

Remove `Warrior_Healthstone`, `Warrior_HealingPotion`.
Keep: `Warrior_AutoBandage`.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/warrior/middleware.lua
git commit -m "refactor(warrior): migrate recovery items to shared factory"
```

---

## Phase 2: Threat Awareness System

### Task 11: Create threat.lua — shared threat awareness module

**Files:**
- Create: `rotation/source/aio/threat.lua`

**Step 1: Write the shared threat module**

```lua
-- Menagerie - Shared Threat Awareness Middleware
-- Monitors threat levels and takes configurable action (dump, stop DPS, or ignore)
-- Classes call NS.register_threat_middleware() from their middleware.lua

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Threat]|r Core module not loaded!")
    return
end

local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local Priority = NS.Priority
local format = string.format
local GetTime = _G.GetTime
local UnitClassification = _G.UnitClassification
local UnitGUID = _G.UnitGUID

local PLAYER_UNIT = "player"
local TARGET_UNIT = "target"

-- ============================================================================
-- UNIT CLASSIFICATION HELPERS
-- ============================================================================

local CLASSIFICATION_RANK = {
    worldboss = 3,
    elite     = 2,
    rareelite = 2,
    rare      = 1,
    normal    = 1,
    trivial   = 0,
    minus     = 0,
}

local SCOPE_THRESHOLD = {
    boss  = 3,    -- worldboss only
    elite = 2,    -- elite + worldboss
    all   = 0,    -- everything
}

local function target_meets_scope(scope)
    local classification = UnitClassification(TARGET_UNIT) or "normal"
    local rank = CLASSIFICATION_RANK[classification] or 1
    local threshold = SCOPE_THRESHOLD[scope] or 0
    return rank >= threshold
end

-- ============================================================================
-- NAMEPLATE ENEMY COUNTING
-- ============================================================================

-- Pre-allocated state to avoid combat table creation
local enemy_counts = { bosses = 0, elites = 0, trash = 0, total = 0 }

local function count_enemies_targeting_player()
    enemy_counts.bosses = 0
    enemy_counts.elites = 0
    enemy_counts.trash = 0
    enemy_counts.total = 0

    local player_guid = UnitGUID(PLAYER_UNIT)
    if not player_guid then return enemy_counts end

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if _G.UnitExists(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
            local target_of = unit .. "target"
            if _G.UnitExists(target_of) and UnitGUID(target_of) == player_guid then
                local class = UnitClassification(unit) or "normal"
                if class == "worldboss" then
                    enemy_counts.bosses = enemy_counts.bosses + 1
                elseif class == "elite" or class == "rareelite" then
                    enemy_counts.elites = enemy_counts.elites + 1
                else
                    enemy_counts.trash = enemy_counts.trash + 1
                end
                enemy_counts.total = enemy_counts.total + 1
            end
        end
    end
    return enemy_counts
end

-- Export for use by other modules
NS.count_enemies_targeting_player = count_enemies_targeting_player

-- ============================================================================
-- THREAT MIDDLEWARE FACTORY
-- ============================================================================

--- Register threat awareness middleware for a DPS class.
--- @param class_name string  Class display name (e.g. "Rogue")
--- @param config table       Configuration:
---   dump_spell:       Action spell for threat dump (nil if class has no dump)
---   dump_ready_check: function(context) → bool, extra conditions (e.g. energy >= 20)
function NS.register_threat_middleware(class_name, config)
    if not config then return end

    local dump_spell = config.dump_spell
    local dump_ready_check = config.dump_ready_check

    rotation_registry:register_middleware({
        name = class_name .. "_ThreatAwareness",
        priority = Priority.MIDDLEWARE.DISPEL_CURSE,  -- 350
        is_defensive = true,

        matches = function(context)
            if not context.in_combat then return false end

            -- Check threat_mode setting
            local mode = context.settings.threat_mode or "dump"
            if mode == "off" then return false end

            -- Check TTD — don't waste dump on dying target
            if context.ttd and context.ttd > 0 and context.ttd < 3 then return false end

            -- Check unit classification scope
            local scope = context.settings.threat_scope or "elite"
            if not target_meets_scope(scope) then return false end

            -- Count enemies and populate context for downstream use
            local counts = count_enemies_targeting_player()
            context.threat_bosses = counts.bosses
            context.threat_elites = counts.elites
            context.threat_trash = counts.trash
            context.threat_total = counts.total

            -- Check if we actually have threat
            -- Use IsTanking as primary check (matches existing class behavior)
            local is_tanking = Unit(PLAYER_UNIT):IsTanking(TARGET_UNIT)
            if not is_tanking then return false end

            return true
        end,

        execute = function(icon, context)
            local mode = context.settings.threat_mode or "dump"

            -- Try threat dump first (if mode is "dump" and class has a dump spell)
            if mode == "dump" and dump_spell then
                local can_dump = true
                if dump_ready_check and not dump_ready_check(context) then
                    can_dump = false
                end
                if can_dump and dump_spell:IsReady(PLAYER_UNIT) then
                    return dump_spell:Show(icon), format("[MW] %s - Threat dump (targeting %d enemies)", class_name, context.threat_total or 0)
                end
            end

            -- Suppress DPS: return GCD/wait signal
            -- Show the "stop" by returning a GCD-like pause
            if A.StopCast and A.StopCast:IsReady(PLAYER_UNIT) then
                return A.StopCast:Show(icon), format("[MW] %s - Threat: STOP DPS (%s mode)", class_name, mode)
            end

            -- Fallback: return nil to let rotation continue (dump on CD, can't stop)
            return nil
        end,
    })
end
```

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/threat.lua
git commit -m "feat: add shared threat awareness middleware factory"
```

---

### Task 12: Add threat settings to class schemas

**Files:**
- Modify: `rotation/source/aio/hunter/schema.lua`
- Modify: `rotation/source/aio/mage/schema.lua`
- Modify: `rotation/source/aio/paladin/schema.lua`
- Modify: `rotation/source/aio/priest/schema.lua`
- Modify: `rotation/source/aio/rogue/schema.lua`
- Modify: `rotation/source/aio/shaman/schema.lua`
- Modify: `rotation/source/aio/warlock/schema.lua`
- Modify: `rotation/source/aio/warrior/schema.lua`

For each class schema, add a "Threat Management" section with two settings:

```lua
{ header = "Threat Management", settings = {
    { type = "dropdown", key = "threat_mode", default = "dump", label = "Threat Mode",
      tooltip = "How to handle threat. Dump uses class ability, Stop pauses DPS, Off ignores threat.",
      options = {
          { text = "Dump + Stop", value = "dump" },
          { text = "Stop DPS Only", value = "stop" },
          { text = "Off", value = "off" },
      },
    },
    { type = "dropdown", key = "threat_scope", default = "elite", label = "Threat Scope",
      tooltip = "Which targets to manage threat on. Elite includes bosses and elites.",
      options = {
          { text = "All Targets", value = "all" },
          { text = "Elites + Bosses", value = "elite" },
          { text = "Bosses Only", value = "boss" },
      },
    },
}},
```

Place this section in the "Utility" or "General" tab of each class schema, near existing defensive/utility settings.

**Note:** For classes with no threat dump (Mage, Shaman Ele/Enh, Paladin Ret, Warrior Arms/Fury), the "Dump + Stop" mode behaves the same as "Stop DPS Only" — they have no dump ability to use.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/*/schema.lua
git commit -m "feat: add threat management settings to all class schemas"
```

---

### Task 13: Register threat middleware for each class + remove old threat dumps

**Files:**
- Modify: `rotation/source/aio/hunter/middleware.lua` (add threat registration, remove Hunter_FeignDeath)
- Modify: `rotation/source/aio/mage/middleware.lua` (add threat registration)
- Modify: `rotation/source/aio/paladin/middleware.lua` (add threat registration)
- Modify: `rotation/source/aio/priest/middleware.lua` (add threat registration, remove Priest_Fade)
- Modify: `rotation/source/aio/rogue/middleware.lua` (add threat registration, remove Rogue_Feint)
- Modify: `rotation/source/aio/shaman/middleware.lua` (add threat registration)
- Modify: `rotation/source/aio/warlock/middleware.lua` (add threat registration, remove Warlock_Soulshatter)
- Modify: `rotation/source/aio/warrior/middleware.lua` (add threat registration)

For each class, add the threat registration call and remove the old class-specific threat dump middleware:

**Hunter:**
```lua
NS.register_threat_middleware("Hunter", {
    dump_spell = A.FeignDeath,
})
```
Remove: `Hunter_FeignDeath` middleware block. Also remove the `use_feign_death` setting_key reference (threat system uses `threat_mode` now).

**Mage:**
```lua
NS.register_threat_middleware("Mage", {})
```

**Paladin:**
```lua
NS.register_threat_middleware("Paladin", {})
```

**Priest:**
```lua
NS.register_threat_middleware("Priest", {
    dump_spell = A.Fade,
})
```
Remove: `Priest_Fade` middleware block and its `count_mobs_targeting_me` local function (functionality moved to shared `NS.count_enemies_targeting_player`).

**Rogue:**
```lua
NS.register_threat_middleware("Rogue", {
    dump_spell = A.Feint,
    dump_ready_check = function(context)
        return context.energy >= Constants.ENERGY.FEINT
    end,
})
```
Remove: `Rogue_Feint` middleware block.

**Shaman:**
```lua
NS.register_threat_middleware("Shaman", {})
```

**Warlock:**
```lua
NS.register_threat_middleware("Warlock", {
    dump_spell = A.Soulshatter,
    dump_ready_check = function(context)
        return context.soul_shards >= 1
    end,
})
```
Remove: `Warlock_Soulshatter` middleware block.

**Warrior:**
```lua
NS.register_threat_middleware("Warrior", {})
```

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/*/middleware.lua
git commit -m "feat: register threat middleware for all classes, remove old threat dumps"
```

---

## Phase 3: Interrupt Awareness System

### Task 14: Create interrupt.lua — shared interrupt decision module with tab-targeting

**Files:**
- Create: `rotation/source/aio/interrupt.lua`

**Step 1: Write the shared interrupt module**

This module provides:
1. Priority cast database (`NS.INTERRUPT_PRIORITY`)
2. Smart interrupt decision function (`NS.should_interrupt()`) for current-target kicks
3. Tab-target state machine (`NS.interrupt_tab_target`) extracted from Shaman — classes opt in
4. Priority caster nameplate scanner (`NS.find_priority_caster()`) — shared across all classes

```lua
-- Menagerie - Shared Interrupt Awareness
-- Provides priority cast database, smart interrupt decisions, and tab-target state machine
-- Classes keep their own kick implementation but use shared decision/targeting logic

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Interrupt]|r Core module not loaded!")
    return
end

local A = NS.A
local Unit = NS.Unit
local UnitClassification = _G.UnitClassification
local UnitGUID = _G.UnitGUID
local GetTime = _G.GetTime
local CONST = A.Enum

local TARGET_UNIT = "target"
local PLAYER_UNIT = "player"
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo

-- ============================================================================
-- COMBAT LOG: DUPLICATE INTERRUPT PREVENTION
-- Tracks SPELL_INTERRUPT events to avoid double-kicking targets
-- Covers both self and teammate interrupts
-- ============================================================================

local recent_interrupts = {}  -- [destGUID] = timestamp
local INTERRUPT_DEDUP_WINDOW = 0.5  -- seconds to suppress kicks after an interrupt

local interrupt_frame = _G.CreateFrame("Frame")
interrupt_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
interrupt_frame:SetScript("OnEvent", function()
    local _, event, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if event == "SPELL_INTERRUPT" then
        recent_interrupts[destGUID] = GetTime()
    end
end)

local function was_recently_interrupted(guid)
    if not guid then return false end
    local last_kick = recent_interrupts[guid]
    if not last_kick then return false end
    if (GetTime() - last_kick) < INTERRUPT_DEDUP_WINDOW then
        return true
    end
    recent_interrupts[guid] = nil
    return false
end

-- ============================================================================
-- UNIT CLASSIFICATION HELPERS (shared with threat.lua)
-- ============================================================================

local CLASSIFICATION_RANK = {
    worldboss = 3,
    elite     = 2,
    rareelite = 2,
    rare      = 1,
    normal    = 1,
    trivial   = 0,
    minus     = 0,
}

local SCOPE_THRESHOLD = {
    boss  = 3,
    elite = 2,
    all   = 0,
}

-- ============================================================================
-- PRIORITY INTERRUPT SPELL DATABASE
-- Migrated from Shaman middleware + expanded for all TBC dungeon/raid content
-- Categories: "heal", "cc", "damage"
-- Spells NOT in this table are treated as "normal" (low priority)
-- ============================================================================

NS.INTERRUPT_PRIORITY = {
    -- ============================
    -- HEALING (always interrupt)
    -- ============================
    [41455] = "heal",   -- Circle of Healing
    [30528] = "heal",   -- Dark Mending
    [30878] = "heal",   -- Eternal Affection
    [17843] = "heal",   -- Flash Heal
    [35096] = "heal",   -- Greater Heal
    [33144] = "heal",   -- Heal
    [38330] = "heal",   -- Healing Wave
    [43451] = "heal",   -- Holy Light
    [46181] = "heal",   -- Lesser Healing Wave
    [33152] = "heal",   -- Prayer of Healing
    [8362]  = "heal",   -- Renew

    -- ============================
    -- CROWD CONTROL (always interrupt)
    -- ============================
    [41410] = "cc",     -- Deaden
    [37135] = "cc",     -- Domination
    [40184] = "cc",     -- Paralyzing Screech
    [39096] = "cc",     -- Polarity Shift
    [13323] = "cc",     -- Polymorph
    [38815] = "cc",     -- Sightless Touch

    -- ============================
    -- DANGEROUS DAMAGE (interrupt if possible)
    -- ============================
    [31472] = "damage", -- Arcane Discharge
    [29973] = "damage", -- Arcane Explosion
    [44644] = "damage", -- Arcane Nova
    [30616] = "damage", -- Blast Nova
    [15305] = "damage", -- Chain Lightning
    [45342] = "damage", -- Conflagration
    [46605] = "damage", -- Darkness of a Thousand Souls
    [31258] = "damage", -- Death & Decay
    [45737] = "damage", -- Flame Dart
    [30004] = "damage", -- Flame Wreath
    [44224] = "damage", -- Gravity Lapse
    [15785] = "damage", -- Mana Burn
    [38253] = "damage", -- Poison Bolt
    [36819] = "damage", -- Pyroblast
    [45248] = "damage", -- Shadow Blades
    [39005] = "damage", -- Shadow Nova
    [39193] = "damage", -- Shadow Power
    [46680] = "damage", -- Shadow Spike
    [38796] = "damage", -- Sonic Boom
    [41426] = "damage", -- Spirit Shock
    [29969] = "damage", -- Summon Blizzard
    [32424] = "damage", -- Summon Avatar
}

-- ============================================================================
-- INTERRUPT DECISION FUNCTION (current target)
-- ============================================================================

--- Determine whether the current target's cast should be interrupted.
--- @param context table  The rotation context object
--- @return string|false  "priority" for important casts, "normal" for filler, false for don't kick
function NS.should_interrupt(context)
    -- Basic cast detection (real-time, not cached on context)
    local castLeft, _, _, castSpellID, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
    if not castLeft or castLeft <= 0 or notKickAble then return false end

    -- Dedup: don't kick a target that was just interrupted (by anyone)
    local target_guid = UnitGUID(TARGET_UNIT)
    if was_recently_interrupted(target_guid) then return false end

    -- TTD check — don't waste kick on dying target
    if context.ttd and context.ttd > 0 and context.ttd < 2 then return false end

    -- Unit classification scope
    local scope = context.settings.interrupt_scope or "all"
    local classification = UnitClassification(TARGET_UNIT) or "normal"
    local rank = CLASSIFICATION_RANK[classification] or 1
    local threshold = SCOPE_THRESHOLD[scope] or 0
    if rank < threshold then return false end

    -- Optional delay — don't kick too early
    local delay = context.settings.interrupt_delay or 0
    if delay > 0 then
        local _, castDuration = Unit(TARGET_UNIT):IsCastingRemains()
        local elapsed = (castDuration or 0) - (castLeft or 0)
        if elapsed < delay then return false end
    end

    -- Check priority database
    local category = NS.INTERRUPT_PRIORITY[castSpellID]
    if category then
        return "priority"
    end

    return "normal"
end

-- ============================================================================
-- PRIORITY CASTER NAMEPLATE SCANNER
-- Scans visible nameplates for enemies casting priority spells
-- Extracted from Shaman middleware — now available to all classes
-- ============================================================================

--- Scan nameplates for priority casters within range.
--- @param max_range number  Maximum range to consider (e.g. 20 for Earth Shock, 30 for Counterspell)
--- @return string|nil guid, number|nil castLeft, string|nil spellName  Best priority caster found
function NS.find_priority_caster(max_range)
    local best_guid = nil
    local best_cast_left = 0
    local best_spell_name = nil

    for i = 1, 40 do
        local unit = "nameplate" .. i
        if _G.UnitExists(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
            local unit_guid = UnitGUID(unit)
            -- Skip recently interrupted targets (teammate or self already got it)
            if not was_recently_interrupted(unit_guid) then
                local castLeft, _, spellName, spellID, notKickAble = Unit(unit):IsCastingRemains()
                if castLeft and castLeft > 0 and not notKickAble and spellID then
                    if NS.INTERRUPT_PRIORITY[spellID] then
                        -- Pick the caster with the most remaining cast time (easier to reach)
                        if castLeft > best_cast_left then
                            best_guid = unit_guid
                            best_cast_left = castLeft
                            best_spell_name = spellName
                        end
                    end
                end
            end
        end
    end

    return best_guid, best_cast_left, best_spell_name
end

-- ============================================================================
-- TAB-TARGET INTERRUPT STATE MACHINE
-- Extracted from Shaman — provides seek→interrupt→return flow for any class
-- Classes opt in via supports_tab_target = true in capability registration
-- ============================================================================

local SEEK_TIMEOUT = 1.0   -- seconds to tab toward priority caster
local RETURN_TIMEOUT = 1.0 -- seconds to tab back to original target

-- Per-class interrupt state tables (pre-allocated to avoid combat allocation)
-- Each class that opts in gets its own state table
local class_interrupt_states = {}

local function get_interrupt_state(class_name)
    if not class_interrupt_states[class_name] then
        class_interrupt_states[class_name] = {
            phase = "idle",           -- "idle" | "seeking" | "returning"
            original_guid = nil,      -- GUID of original target before tab
            target_guid = nil,        -- GUID of priority caster we're seeking
            spell_name = nil,         -- Name of spell being cast
            timeout = 0,             -- GetTime deadline for current phase
        }
    end
    return class_interrupt_states[class_name]
end

--- Check if tab-target interrupt should activate (called from matches).
--- Returns true if the class should enter the interrupt flow, false otherwise.
--- @param class_name string  The class using this
--- @param context table      Rotation context
--- @param interrupt_spell Action  The kick spell (for CD check)
--- @param max_range number   Max interrupt range
--- @return boolean
function NS.interrupt_tab_matches(class_name, context, interrupt_spell, max_range)
    if not context.in_combat then
        local state = get_interrupt_state(class_name)
        state.phase = "idle"
        return false
    end

    local state = get_interrupt_state(class_name)
    local now = GetTime()

    -- RETURNING phase: tabbing back to original target
    if state.phase == "returning" then
        if now > state.timeout then
            state.phase = "idle"
            return false
        end
        if not state.original_guid then
            state.phase = "idle"
            return false
        end
        -- Already back on original target
        if UnitGUID(TARGET_UNIT) == state.original_guid then
            state.phase = "idle"
            return false
        end
        -- Validate original target is still alive and attackable
        -- Scan nameplates/units to confirm GUID still exists
        local original_valid = false
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if _G.UnitExists(unit) and UnitGUID(unit) == state.original_guid then
                if not _G.UnitIsDead(unit) and _G.UnitCanAttack(PLAYER_UNIT, unit) then
                    original_valid = true
                end
                break
            end
        end
        if not original_valid then
            -- Original target died or despawned — just go idle
            state.phase = "idle"
            return false
        end
        return true
    end

    -- SEEKING phase: tabbing toward priority caster
    if state.phase == "seeking" then
        if now > state.timeout then
            state.phase = "returning"
            state.timeout = now + RETURN_TIMEOUT
            return true
        end
        return true
    end

    -- IDLE phase: scan for priority casters
    if not context.settings.use_priority_interrupt then return false end

    -- Check if our kick is off cooldown before scanning
    if interrupt_spell and interrupt_spell:GetCooldown() > 0 then return false end

    local caster_guid, cast_left, spell_name = NS.find_priority_caster(max_range or 30)
    if caster_guid then
        local current_guid = UnitGUID(TARGET_UNIT)
        if caster_guid == current_guid then
            -- Priority caster IS current target — let normal interrupt handle it
            return false
        end
        -- Different unit → start seeking
        state.phase = "seeking"
        state.original_guid = current_guid
        state.target_guid = caster_guid
        state.spell_name = spell_name
        state.timeout = now + SEEK_TIMEOUT
        return true
    end

    return false
end

--- Execute tab-target interrupt flow (called from execute).
--- @param class_name string
--- @param icon any           TMW icon
--- @param context table
--- @param interrupt_spell Action  The kick spell to use
--- @return any result, string log
function NS.interrupt_tab_execute(class_name, icon, context, interrupt_spell)
    local state = get_interrupt_state(class_name)

    -- SEEKING: tab toward caster, or interrupt if we've arrived
    if state.phase == "seeking" then
        if UnitGUID(TARGET_UNIT) == state.target_guid then
            -- Landed on the caster — try to interrupt
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                if interrupt_spell:IsReady(TARGET_UNIT) then
                    state.phase = "returning"
                    state.timeout = GetTime() + RETURN_TIMEOUT
                    return interrupt_spell:Show(icon), ("[MW] PRIORITY Interrupt (" .. (state.spell_name or "?") .. ")")
                end
            end
            -- Can't interrupt → return to original
            state.phase = "returning"
            state.timeout = GetTime() + RETURN_TIMEOUT
        end
        -- Not on caster yet → tab
        return A:Show(icon, CONST.AUTOTARGET), ("[MW] Seeking " .. (state.spell_name or "?") .. " caster")
    end

    -- RETURNING: tab back toward original target
    if state.phase == "returning" then
        return A:Show(icon, CONST.AUTOTARGET), "[MW] Returning to original target"
    end

    return nil
end

-- ============================================================================
-- CAPABILITY REGISTRATION
-- ============================================================================

NS.interrupt_capabilities = {}

--- Register a class's interrupt capability.
--- @param class_name string
--- @param config table  { lockout_duration, cooldown, range, supports_tab_target }
function NS.register_interrupt_capability(class_name, config)
    NS.interrupt_capabilities[class_name] = config
end
```

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/interrupt.lua
git commit -m "feat: add shared interrupt awareness with priority DB and tab-targeting"
```

---

### Task 15: Add interrupt settings to class schemas

**Files:**
- Modify: `rotation/source/aio/mage/schema.lua`
- Modify: `rotation/source/aio/paladin/schema.lua`
- Modify: `rotation/source/aio/priest/schema.lua`
- Modify: `rotation/source/aio/rogue/schema.lua`
- Modify: `rotation/source/aio/shaman/schema.lua`
- Modify: `rotation/source/aio/warrior/schema.lua`

For each class that has an interrupt, add interrupt awareness settings near the existing interrupt toggle:

```lua
{ type = "checkbox", key = "interrupt_priority_only", default = false, label = "Priority Casts Only",
  tooltip = "Only interrupt dangerous casts (heals, CC, big damage). Skip filler casts." },
{ type = "dropdown", key = "interrupt_scope", default = "all", label = "Interrupt Scope",
  tooltip = "Which targets to interrupt based on classification.",
  options = {
      { text = "All Targets", value = "all" },
      { text = "Elites + Bosses", value = "elite" },
      { text = "Bosses Only", value = "boss" },
  },
},
{ type = "slider", key = "interrupt_delay", default = 0, min = 0, max = 1, step = 0.1, label = "Interrupt Delay",
  tooltip = "Seconds to wait before interrupting (0 = instant). Prevents wasting kicks on short casts." },
```

**Note:** Hunter, Druid, and Warlock have NO interrupt — skip them.

**Step 2: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/*/schema.lua
git commit -m "feat: add interrupt awareness settings to class schemas"
```

---

### Task 16: Integrate interrupt awareness into class middleware

**Files:**
- Modify: `rotation/source/aio/mage/middleware.lua` (Counterspell)
- Modify: `rotation/source/aio/rogue/middleware.lua` (Kick)
- Modify: `rotation/source/aio/warrior/middleware.lua` (Pummel/Shield Bash)
- Modify: `rotation/source/aio/priest/middleware.lua` (Silence)
- Modify: `rotation/source/aio/paladin/middleware.lua` (Hammer of Justice)
- Modify: `rotation/source/aio/shaman/middleware.lua` (Earth Shock — update priority DB reference)

For each class's interrupt middleware, update the `matches` function to use `NS.should_interrupt()`:

**Mage (Counterspell):**
```lua
matches = function(context)
    if not context.in_combat then return false end
    if not context.settings.use_counterspell then return false end
    if not context.has_valid_enemy_target then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,
```

The `execute` function stays unchanged — it still does `Unit(TARGET_UNIT):IsCastingRemains()` and fires the kick.

**Rogue (Kick):** Same pattern, plus keep energy gate:
```lua
matches = function(context)
    if not context.in_combat then return false end
    if not context.settings.use_kick then return false end
    if not context.has_valid_enemy_target then return false end
    if context.energy < Constants.ENERGY.KICK then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,
```

**Warrior (Pummel/Shield Bash):** Same pattern. Execute stays unchanged (stance dance logic untouched):
```lua
matches = function(context)
    if not context.in_combat then return false end
    if not context.settings.use_interrupt then return false end
    if not context.has_valid_enemy_target then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,
```

**Priest (Silence):**
```lua
matches = function(context)
    if not context.in_combat then return false end
    if not context.settings.shadow_use_silence then return false end
    if not context.has_valid_enemy_target then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,
```

**Paladin (Hammer of Justice):**
```lua
matches = function(context)
    if not context.in_combat then return false end
    if not context.settings.use_hammer_of_justice then return false end
    if not context.has_valid_enemy_target then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,
```

**Shaman (Earth Shock):** The Shaman's interrupt is the BIGGEST change. Its entire 3-phase state machine (idle→seeking→returning) and `PRIORITY_INTERRUPT_SPELLS` table move to shared `interrupt.lua`. Replace the entire Shaman_Interrupt middleware with a new implementation that delegates to the shared tab-target system:

```lua
rotation_registry:register_middleware({
    name = "Shaman_Interrupt",
    priority = Priority.MIDDLEWARE.FORM_RESHIFT,  -- 500

    matches = function(context)
        if not context.settings.use_interrupt then return false end

        -- Check tab-target priority interrupt first (replaces old state machine)
        local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
        if NS.interrupt_tab_matches("Shaman", context, spell, 20) then
            return true
        end

        -- Fallback: current-target interrupt
        if not context.has_valid_enemy_target then return false end
        local decision = NS.should_interrupt(context)
        if not decision then return false end
        if decision == "normal" and context.settings.interrupt_priority_only then return false end
        return true
    end,

    execute = function(icon, context)
        local spell = context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock

        -- Tab-target flow (seeking/returning phases)
        local tab_result, tab_log = NS.interrupt_tab_execute("Shaman", icon, context, spell)
        if tab_result then return tab_result, tab_log end

        -- Standard current-target interrupt
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 and not notKickAble then
            if spell:IsReady(TARGET_UNIT) then
                return spell:Show(icon), format("[MW] Earth Shock Interrupt - Cast: %.1fs", castLeft)
            end
        end
        return nil
    end,
})
```

Remove: the old `Shaman_Interrupt` middleware block, the local `PRIORITY_INTERRUPT_SPELLS` table, the local `interrupt_state` table, the local `find_priority_caster()` function, and the `INTERRUPT_SEEK_TIMEOUT`/`INTERRUPT_RETURN_TIMEOUT` constants.

**Other classes with tab-targeting:** Any class that wants priority nameplate scanning can follow the same pattern. For example, Mage (Counterspell has 30yd range — excellent for tab-target interrupts):

```lua
-- Mage: opt into tab-target interrupts
matches = function(context)
    if not context.settings.use_counterspell then return false end

    -- Tab-target priority interrupt
    if NS.interrupt_tab_matches("Mage", context, A.Counterspell, 30) then
        return true
    end

    -- Current-target interrupt
    if not context.has_valid_enemy_target then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then return false end
    return true
end,

execute = function(icon, context)
    -- Tab-target flow
    local tab_result, tab_log = NS.interrupt_tab_execute("Mage", icon, context, A.Counterspell)
    if tab_result then return tab_result, tab_log end

    -- Standard current-target interrupt
    local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
    if castLeft and castLeft > 0 and not notKickAble then
        if A.Counterspell:IsReady(TARGET_UNIT) then
            return A.Counterspell:Show(icon), format("[MW] Counterspell - Cast: %.1fs", castLeft)
        end
    end
    return nil
end,
```

**Tab-targeting opt-in per class:**
- Shaman: YES (existing behavior, 20yd range)
- Mage: YES (30yd Counterspell — best tab-target interrupter)
- Warrior: NO (melee range — tab-targeting to distant caster is impractical)
- Rogue: NO (melee range)
- Priest: YES if Shadow (20yd Silence range)
- Paladin: NO (10yd HoJ range — too short for tab-targeting)

**Step 2: Register interrupt capabilities**

Add to each class's middleware.lua. Only include data that can't be derived at runtime:
- `resolve_spell(context)` — returns the best available interrupt spell (handles multi-spell, stance, rank selection)
- `supports_tab_target` — whether to scan nameplates for priority casters

Cooldown and range are derived from the resolved spell at runtime. No hardcoded values.

```lua
-- Mage (tab-target: YES — Counterspell has long range)
NS.register_interrupt_capability("Mage", {
    supports_tab_target = true,
    resolve_spell = function() return A.Counterspell end,
})

-- Rogue (tab-target: NO — melee only)
NS.register_interrupt_capability("Rogue", {
    supports_tab_target = false,
    resolve_spell = function() return A.Kick end,
})

-- Warrior (tab-target: NO — melee, stance dance can't work mid-tab)
NS.register_interrupt_capability("Warrior", {
    supports_tab_target = false,
    resolve_spell = function(context)
        if context.stance == Constants.STANCE.BERSERKER then return A.Pummel end
        if context.stance == Constants.STANCE.DEFENSIVE then return A.ShieldBash end
        if (A.Pummel:GetCooldown() or 0) <= 0 then return A.Pummel end
        return nil
    end,
})

-- Priest (tab-target: YES for Shadow — Silence has 20yd range)
NS.register_interrupt_capability("Priest", {
    supports_tab_target = true,
    resolve_spell = function()
        if is_spell_available(A.Silence) then return A.Silence end
        return nil
    end,
})

-- Paladin (tab-target: NO — HoJ range too short)
NS.register_interrupt_capability("Paladin", {
    supports_tab_target = false,
    resolve_spell = function() return A.HammerOfJustice end,
})

-- Shaman (tab-target: YES — existing behavior)
NS.register_interrupt_capability("Shaman", {
    supports_tab_target = true,
    resolve_spell = function(context)
        return context.settings.interrupt_rank1 and A.EarthShockR1 or A.EarthShock
    end,
})
```

**Step 3: Build and commit**

```bash
cd rotation && node build.js
git add rotation/source/aio/interrupt.lua rotation/source/aio/*/middleware.lua rotation/source/aio/*/schema.lua
git commit -m "feat: integrate shared interrupt awareness into all class interrupts"
```

---

## Phase 4: Final Verification

### Task 17: Full build verification and cleanup

**Step 1: Full build**

```bash
cd rotation && node build.js
```

Expected: Clean build with all classes, no errors.

**Step 2: Check for dead code**

Review each class middleware.lua for any orphaned local variables or helper functions that were only used by the removed middleware blocks:
- Priest: `count_mobs_targeting_me` helper → should be removed (replaced by `NS.count_enemies_targeting_player`)
- Shaman: `PRIORITY_INTERRUPT_SPELLS` table → should be removed (replaced by `NS.INTERRUPT_PRIORITY`)
- Any unused `DetermineUsableObject` locals in classes that had it only for recovery items

**Step 3: Final commit**

```bash
git add -A
git commit -m "chore: clean up dead code from shared middleware migration"
```

---

## Summary of Changes

### New Files Created
- `rotation/source/aio/recovery.lua` — Shared recovery item factory
- `rotation/source/aio/threat.lua` — Shared threat awareness factory
- `rotation/source/aio/interrupt.lua` — Shared interrupt priority DB + decision function

### Files Modified
- `rotation/build.js` — Added 3 shared files to ORDER_MAP + LOAD_ORDER
- 8× `rotation/source/aio/<class>/middleware.lua` — Factory calls replace duplicated code
- 8× `rotation/source/aio/<class>/schema.lua` — New threat + interrupt settings

### Code Removed (per class)
- ~60-80 lines recovery item middleware (8 classes × ~70 avg = ~560 lines)
- ~20-30 lines threat dump middleware (4 classes)
- Shaman's local PRIORITY_INTERRUPT_SPELLS table (~44 lines)
- Priest's local count_mobs_targeting_me function (~20 lines)

### New Features
- **Threat awareness** — configurable threat management for all DPS specs
- **Interrupt intelligence** — priority cast database, TTD awareness, classification scoping
- **Enemy classification counting** — shared nameplate scan available to all modules
