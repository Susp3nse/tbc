# Creating a New Class: Complete Implementation Guide

This document captures every pattern, contract, and gotcha needed to add a new class (e.g. Mage) to the Flux AIO rotation system. It was written by exhaustively reading every file in the codebase.

---

## Table of Contents

1. [Files You Must Create](#1-files-you-must-create)
2. [File Naming & Build System](#2-file-naming--build-system)
3. [Load Order (Critical)](#3-load-order-critical)
4. [Step-by-Step: schema.lua](#4-step-by-step-schemalua)
5. [Step-by-Step: class.lua](#5-step-by-step-classlua)
6. [Step-by-Step: middleware.lua](#6-step-by-step-middlewarelua)
7. [Step-by-Step: Playstyle Modules](#7-step-by-step-playstyle-modules)
8. [The Shared Modules (Do NOT Touch)](#8-the-shared-modules-do-not-touch)
9. [Strategy & Middleware Contracts](#9-strategy--middleware-contracts)
10. [Context Object Reference](#10-context-object-reference)
11. [Settings System](#11-settings-system)
12. [Registration API Reference](#12-registration-api-reference)
13. [Common Utility Functions](#13-common-utility-functions)
14. [Lua 5.1 Gotchas](#14-lua-51-gotchas)
15. [Framework API Quick Reference](#15-framework-api-quick-reference)
16. [Checklist](#16-checklist)

---

## 1. Files You Must Create

All files go under `rotation/source/aio/<classname>/`. For a Mage:

```
rotation/source/aio/mage/
  schema.lua        # Settings schema (MUST load first)
  class.lua         # Spell definitions, constants, class registration
  middleware.lua     # Recovery items, shared combat middleware
  <playstyle>.lua    # One file per playstyle (e.g. fire.lua, frost.lua, arcane.lua)
```

**File naming rule**: Lowercase single words ONLY. No underscores, hyphens, or spaces. Enforced by `build.js` — build will fail with a hard error on bad names.

Good: `frost.lua`, `arcane.lua`, `fire.lua`, `cliptracker.lua`
Bad: `frost_mage.lua`, `fire-rotation.lua`, `Arcane.lua`

---

## 2. File Naming & Build System

The build system (`rotation/build.js`) auto-discovers class directories under `source/aio/`. Simply creating a `mage/` directory with `.lua` files is enough — no configuration needed.

**How it works:**
1. `discoverClasses(aioDir)` scans for subdirectories → finds `druid/`, `hunter/`, `mage/`
2. `discoverModules(className, aioDir)` collects shared modules + class modules
3. Each module gets a `Name` (e.g. `Flux_Mage_Schema`) and an `Order` value
4. Modules are compiled into TMW CodeSnippets in the output `TellMeWhen.lua`

**Profile naming**: By default, `"Flux Mage"` (capitalized class name). Override in `builder.config.local.json` under `"profiles"`.

**Build commands**:
```bash
cd rotation
node build.js              # Build output/TellMeWhen.lua
node build.js --sync       # Sync to SavedVariables
node build.js --all        # Build + sync
node dev-watch.js          # Auto-rebuild on file changes
```

---

## 3. Load Order (Critical)

The build system enforces this order via `ORDER_MAP`. You cannot change it without modifying `build.js`.

| Order | File | Slot | What It Does |
|-------|------|------|-------------|
| 1 | `schema.lua` | class | Defines `_G.FluxAIO_SETTINGS_SCHEMA`, enables profile |
| 2 | `ui.lua` | shared | Generates `A.Data.ProfileUI[2]` from schema |
| 3 | `core.lua` | shared | Creates `_G.FluxAIO` namespace, registry, utilities |
| 4 | `class.lua` | class | Defines `Action[PlayerClass]`, registers class, sets `NS.A` |
| 5 | `healing.lua` | class | Healing utilities (if needed, same order as settings) |
| 5 | `settings.lua` | shared | Custom tabbed settings UI + minimap button |
| 6 | `middleware.lua` | class | Recovery items, cross-playstyle middleware |
| 7 | `dashboard.lua` | shared | Shared combat dashboard overlay |
| 7 | *(remaining)* | class | Playstyle modules (alphabetical within order 7) |
| 8 | `main.lua` | shared | Context creation, rotation dispatcher (ALWAYS LAST) |

**Key insight**: `schema.lua` loads BEFORE `core.lua`. This means:
- `schema.lua` can only use `_G.Action` (the base framework), NOT `_G.FluxAIO`
- `class.lua` loads AFTER `core.lua`, so it CAN use `_G.FluxAIO`
- All playstyle modules load after `class.lua` and can use everything

---

## 4. Step-by-Step: schema.lua

This is the first file loaded for your class. It does exactly three things:

### 4a. Gate on PlayerClass
```lua
local _G = _G
local A = _G.Action
if not A then return end
if A.PlayerClass ~= "MAGE" then return end
```

Every class file must gate on `A.PlayerClass`. This is how the system ensures only one class's code runs.

### 4b. Enable the Profile
```lua
A.Data.ProfileEnabled[A.CurrentProfile] = true
```

This is **required**. Without it, `core.lua` will refuse to load and print an error.

### 4c. Define the Settings Schema
```lua
_G.FluxAIO_SETTINGS_SCHEMA = {
    [1] = { name = "General", sections = {
        { header = "Section Name", settings = {
            { type = "checkbox", key = "setting_key", default = true,
              label = "Display Label", tooltip = "Tooltip text." },
            { type = "slider", key = "slider_key", default = 50, min = 0, max = 100,
              label = "Slider Label", tooltip = "Tooltip text.", format = "%d%%" },
            { type = "dropdown", key = "dropdown_key", default = "value1",
              label = "Dropdown Label", tooltip = "Tooltip text.",
              options = {
                  { value = "value1", text = "Option 1" },
                  { value = "value2", text = "Option 2" },
              }},
        }},
    }},
    [2] = { name = "Tab 2 Name", sections = { ... }},
    -- ... more tabs
}
```

**Schema rules:**
- Array indices `[1]`, `[2]`, etc. correspond to UI tabs
- Each tab has a `name` (displayed on tab button) and `sections` array
- Each section has a `header` string and `settings` array
- Setting types: `"checkbox"`, `"slider"`, `"dropdown"`
- All keys are **snake_case** — this exact string is used everywhere in the system
- `wide = true` on a setting makes it span the full width (not paired in a 2-column row)
- `format` on sliders controls display (e.g. `"%d%%"`, `"%d sec"`, `"%d yd"`)
- `debug_mode` and `debug_system` keys are expected by the debug system — include them

**This schema drives three systems automatically:**
1. `ui.lua` → generates `A.Data.ProfileUI[2]` (framework backing store with defaults)
2. `settings.lua` → renders the tabbed Settings UI with checkboxes/sliders/dropdowns
3. `core.lua` → `refresh_settings()` iterates the schema to populate `cached_settings`

---

## 5. Step-by-Step: class.lua

This is where the meat of your class is defined. It has several critical sections:

### 5a. Boilerplate & Gating
```lua
local _G, setmetatable, pairs, ipairs, tostring = _G, setmetatable, pairs, ipairs, tostring
local tinsert = table.insert
local format = string.format
local GetTime = _G.GetTime
local A = _G.Action

if not A then return end
if A.PlayerClass ~= "MAGE" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Mage]|r Core module not loaded!")
    return
end
```

### 5b. Action Definitions (Spell/Item Creation)

This is where you define ALL spells for your class:

```lua
local Create = A.Create

Action[A.PlayerClass] = {
    -- Spells
    Fireball = Create({ Type = "Spell", ID = 133, useMaxRank = true }),
    Frostbolt = Create({ Type = "Spell", ID = 116, useMaxRank = true }),
    ArcaneBlast = Create({ Type = "Spell", ID = 30451 }),

    -- Self-buffs (note Click = { unit = "player" })
    SelfArcaneIntellect = Create({ Type = "Spell", ID = 1459, useMaxRank = true,
        Click = { unit = "player" } }),

    -- Items
    SuperManaPotion = Create({ Type = "Item", ID = 22832, Desc = "Super Mana Potion" }),

    -- Trinkets (always slot 13 and 14)
    Trinket1 = Create({ Type = "Trinket", ID = 13 }),
    Trinket2 = Create({ Type = "Trinket", ID = 14 }),

    -- Racials
    Berserking = Create({ Type = "Spell", ID = 26297 }),
    BloodFury = Create({ Type = "Spell", ID = 33697 }),
}
```

**Action.Create options:**
- `Type`: `"Spell"`, `"Item"`, `"Trinket"`, `"Potion"`, `"Talent"`
- `ID`: WoW Spell ID or Item ID
- `useMaxRank = true`: Auto-selects highest known rank (Classic/TBC has ranks)
- `Click = { unit = "player" }`: Forces self-cast
- `Click = { autounit = "harm" }`: Auto-targets harmful unit (Hunter pattern)
- `Click = { macrobefore = "/cast !SpellName\n" }`: Macro prefix (Druid form shifting)
- `Desc`: Description string
- `QueueForbidden = true`: Prevents TMW from queuing this action
- `FixedTexture`: Override icon texture

### 5c. Set Up Class-Specific Framework Reference

```lua
-- THIS IS CRITICAL: creates the class-specific A with metatable fallback
local A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A  -- All other modules import A from NS.A
```

This line makes `A.Fireball` work while also falling back to `Action.GetToggle`, `Action.Player`, etc.

### 5d. Import Namespace References
```lua
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local is_spell_known = NS.is_spell_known
local check_spell_availability = NS.check_spell_availability
local unavailable_spells = NS.unavailable_spells
local PLAYER_UNIT = NS.PLAYER_UNIT
local TARGET_UNIT = NS.TARGET_UNIT
```

### 5e. Define Constants
```lua
local Constants = {
    STANCE = { ... },     -- If applicable
    BUFF_ID = { ... },    -- Important buff spell IDs
    TTD = { ... },        -- Time-to-die thresholds
    -- ... class-specific constants
}
NS.Constants = Constants
```

### 5f. Spell Validation Function
```lua
local last_validated_playstyle = nil

local function validate_playstyle_spells(playstyle)
    if playstyle == last_validated_playstyle then return end
    last_validated_playstyle = playstyle

    for k in pairs(unavailable_spells) do unavailable_spells[k] = nil end

    local missing_spells = {}
    local optional_missing = {}

    if playstyle == "fire" then
        local core = {
            { spell = A.Fireball, name = "Fireball", required = true },
            { spell = A.Scorch, name = "Scorch", required = false },
            -- ...
        }
        check_spell_availability(core, missing_spells, optional_missing)
    elseif playstyle == "frost" then
        -- ...
    end

    -- Print results (copy pattern from Druid/Hunter)
    print("|cFF00FF00[Flux AIO]|r Switched to " .. playstyle .. " playstyle")
    -- ... print missing/optional
end

NS.validate_playstyle_spells = validate_playstyle_spells
```

### 5g. Class Registration (THE MOST IMPORTANT PART)

```lua
rotation_registry:register_class({
    name = "Mage",
    version = "v1.0.0",
    playstyles = { "fire", "frost", "arcane" },
    idle_playstyle_name = nil,  -- or "idle" if you have an idle playstyle

    get_active_playstyle = function(context)
        -- Return the current playstyle string based on game state
        -- For Mage, might be based on talent spec detection
        return "fire"  -- or detect from talents/buffs
    end,

    get_idle_playstyle = function(context)
        -- Return idle playstyle when out of combat, or nil
        return nil
    end,

    extend_context = function(ctx)
        -- Add class-specific fields to the context table
        -- Called every frame by main.lua's create_context()
        ctx.is_moving = Player:IsMoving()
        ctx.has_clearcasting = (Unit("player"):HasBuffs(12536) or 0) > 0
        -- ... any class-specific state
    end,
})
```

**`register_class` config fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | YES | Display name ("Mage") |
| `version` | string | YES | Version string for display |
| `playstyles` | string[] | YES | All possible playstyle names |
| `idle_playstyle_name` | string/nil | NO | Idle form playstyle (Druid="caster", Hunter=nil) |
| `get_active_playstyle` | function(context) → string/nil | YES | Returns active playstyle based on game state |
| `get_idle_playstyle` | function(context) → string/nil | NO | Returns idle playstyle or nil |
| `extend_context` | function(ctx) | NO | Adds class fields to context each frame |
| `gap_handler` | function(icon, ctx) → result | NO | Called by `/flux gap` — fires best gap closer |
| `dashboard` | table | NO | Dashboard config (see [Combat Dashboard](#combat-dashboard)) |

### gap_handler

Optional function for classes with gap closers. Called when `/flux gap` is active. Returns a result if successful (consumed on first fire), nil otherwise.

```lua
gap_handler = function(icon, context)
    if A.Charge:IsReady(TARGET_UNIT) then
        return A.Charge:Show(icon)
    end
    if A.Intercept:IsReady(TARGET_UNIT) then
        return A.Intercept:Show(icon)
    end
    return nil
end,
```

### Combat Dashboard

Optional declarative config that drives the shared combat dashboard overlay. The dashboard module renders from this config — no class-specific UI code needed.

```lua
dashboard = {
    resource = { type = "rage", label = "Rage", color = {0.78, 0.25, 0.25} },
    cooldowns = { A.DeathWish, A.Recklessness, A.Trinket1, A.Trinket2 },
    buffs = {
        { id = DEATH_WISH_ID, label = "DW" },
        { id = RECKLESSNESS_ID, label = "Reck" },
    },
    debuffs = {
        { id = SUNDER_ID, label = "Sunder", target = true, show_stacks = true },
    },
    custom_lines = {
        function(context) return "Stance", STANCE_NAMES[context.stance] end,
    },
},
```

| Dashboard Field | Type | Description |
|----------------|------|-------------|
| `resource` | table | `{ type, label, color }` — resource bar config |
| `cooldowns` | Action[] | Array of spell Actions to show in CD grid |
| `buffs` | table[] | `{ id, label }` — player buffs to track |
| `debuffs` | table[] | `{ id, label, target?, show_stacks? }` — target debuffs |
| `custom_lines` | function[] | `function(context) → label, value` — extra text lines |

All panels are optional — omit a field and that section doesn't render.

**How playstyle selection works (main.lua dispatcher):**
1. `get_active_playstyle(context)` is called → returns e.g. `"fire"`
2. `get_idle_playstyle(context)` is called → returns e.g. `nil`
3. If idle playstyle returned, its strategies run FIRST
4. Then active playstyle strategies run
5. Middleware always runs before both

**For classes without stances/forms** (like Mage), `get_active_playstyle` always returns the same string, and `get_idle_playstyle` returns `nil`.

---

## 6. Step-by-Step: middleware.lua

Middleware runs every frame BEFORE playstyle strategies. Use it for cross-playstyle concerns:
- Recovery items (healthstones, potions, runes)
- Emergency abilities that work in any spec
- Cooldowns that aren't spec-specific

### Boilerplate
```lua
local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Mage Middleware]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Mage Middleware]|r Registry not found!")
    return
end

local A = NS.A
local Priority = NS.Priority
local rotation_registry = NS.rotation_registry
local PLAYER_UNIT = "player"
```

### Registering Middleware
```lua
rotation_registry:register_middleware({
    name = "Mage_RecoveryItems",
    priority = Priority.MIDDLEWARE.RECOVERY_ITEMS,  -- Use predefined priorities
    is_defensive = true,  -- Optional: tagged for /flux def force-fire

    matches = function(context)
        -- Return true if this middleware should execute
        if not context.in_combat then return false end
        if context.hp > context.settings.healthstone_hp then return false end
        return true
    end,

    execute = function(icon, context)
        -- Return result, log_message on success
        -- Return nil on failure (next middleware/strategy runs)
        if A.SuperHealingPotion:IsReady(PLAYER_UNIT) then
            return A.SuperHealingPotion:Show(icon),
                   format("[MW] Healing Potion - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})
```

### Available Priority Constants
```lua
Priority.MIDDLEWARE = {
    FORM_RESHIFT = 500,        -- Druid-specific
    EMERGENCY_HEAL = 400,
    PROACTIVE_HEAL = 390,
    DISPEL_CURSE = 350,
    DISPEL_POISON = 340,
    RECOVERY_ITEMS = 300,
    INNERVATE = 290,           -- Druid-specific
    MANA_RECOVERY = 280,
    SELF_BUFF_MOTW = 150,      -- Druid-specific
    SELF_BUFF_THORNS = 145,    -- Druid-specific
    SELF_BUFF_OOC = 140,       -- Druid-specific
    OFFENSIVE_COOLDOWNS = 100,
}
```

You can use these values or define your own (higher = runs first).

---

## 7. Step-by-Step: Playstyle Modules

Each playstyle (e.g. `fire.lua`, `frost.lua`) contains strategies for that spec.

### Boilerplate
```lua
local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Fire]|r Core module not loaded!")
    return
end
if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO Fire]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local try_cast_fmt = NS.try_cast_fmt
local named = NS.named
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format
```

### Defining Strategies

Strategies are plain Lua tables with `matches` and `execute` functions:

```lua
do  -- Scope block (keeps locals contained)

local Fire_Scorch = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.Scorch,
    matches = function(context, state)
        -- Return true if this strategy should execute
        -- `state` is from the playstyle's context_builder (if any)
        return true
    end,
    execute = function(icon, context, state)
        -- Return result, log_message on success
        -- Return nil to fall through to next strategy
        return try_cast(A.Scorch, icon, TARGET_UNIT, "[FIRE] Scorch")
    end,
}

-- Register strategies as an ordered array
rotation_registry:register("fire", {
    named("Scorch", Fire_Scorch),
    named("Fireball", Fire_Fireball),
    -- ... more strategies in priority order (first = highest)
}, {
    -- Optional config (3rd argument)
    context_builder = get_fire_state,  -- Function that returns per-frame cached state
    check_prerequisites = function(strategy, context)
        -- Additional prerequisite checks beyond the built-in ones
        return true
    end,
})

end  -- End scope block
```

### Strategy Fields Reference

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Set by `named()` helper. For logging. |
| `matches` | function(context, state) → bool | Should this strategy execute? |
| `execute` | function(icon, context, state) → result, log | Cast the spell. Return result + log string. |
| `requires_combat` | bool/nil | If set, context.in_combat must match |
| `requires_enemy` | bool/nil | If set, context.has_valid_enemy_target must match |
| `requires_in_range` | bool/nil | If set, context.in_melee_range must match |
| `requires_phys_immune` | bool/nil | If set, context.target_phys_immune must match |
| `setting_key` | string/nil | If set, context.settings[key] must be truthy |
| `spell` | Action/nil | If set, spell must not be in unavailable_spells AND must be :IsReady() |
| `spell_target` | string/nil | Target for the spell readiness check (default: TARGET_UNIT) |
| `is_gcd_gated` | bool/nil | If false, strategy runs even during GCD (for off-GCD abilities) |
| `should_suggest` | function(context) → bool | For idle playstyle suggestion system (A[1] icon) |
| `suggestion_spell` | Action | Spell to show on A[1] when should_suggest returns true |
| `is_burst` | bool/nil | If true, `/flux burst` force-fires this strategy (bypasses `matches()`) |
| `is_defensive` | bool/nil | If true, `/flux def` force-fires this strategy (bypasses `matches()`) |

**Built-in prerequisite checks** (from `rotation_registry:check_prerequisites`):
- `requires_combat` — checked against `context.in_combat`
- `requires_enemy` — checked against `context.has_valid_enemy_target`
- `requires_in_range` — checked against `context.in_melee_range`
- `requires_phys_immune` — checked against `context.target_phys_immune`
- `setting_key` — checked against `context.settings[key]`
- `spell` — checked against `unavailable_spells` and `spell:IsReady(target)`

### Playstyle Config (3rd arg to `register`)

| Field | Type | Description |
|-------|------|-------------|
| `context_builder` | function(context) → state | Called once per frame, returns cached state table |
| `check_prerequisites` | function(strategy, context) → bool | Extra prerequisite checks |

### The context_builder Pattern

For complex playstyles, compute expensive state once per frame:

```lua
-- Pre-allocated state table (avoids GC in combat)
local fire_state = {
    scorch_stacks = 0,
    scorch_duration = 0,
    -- ...
}

local function get_fire_state(context)
    if context._fire_valid then return fire_state end
    context._fire_valid = true

    -- Compute state (API calls done once, cached for all strategies)
    fire_state.scorch_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(22959) or 0
    fire_state.scorch_duration = Unit(TARGET_UNIT):HasDeBuffs(22959) or 0

    return fire_state
end
```

**Key rules:**
- Use `context._<name>_valid` as the cache flag
- Set it to `true` immediately
- Pre-allocate the state table at file scope (no inline `{}` in combat)
- Reset mutable flags in the builder (e.g. `fire_state.pooling = false`)
- Add the cache flag reset in `extend_context`: `ctx._fire_valid = false`

---

## 8. The Shared Modules (Do NOT Touch)

These files are class-agnostic and serve all classes:

| File | Purpose |
|------|---------|
| `core.lua` | Namespace (`_G.FluxAIO`), settings cache, registry, utilities, force flags, burst context |
| `main.lua` | Context creation, rotation dispatcher (A[3]), suggestion icon (A[1]), force-bypass logic |
| `ui.lua` | Generates `A.Data.ProfileUI[2]` from `_G.FluxAIO_SETTINGS_SCHEMA` |
| `settings.lua` | Custom tabbed settings UI, movable settings button, `/flux` slash commands |
| `dashboard.lua` | Shared combat dashboard overlay (data-driven, reads class `dashboard` config) |

**You should not need to modify these** when adding a new class. They read from the schema and class config dynamically.

The one exception: if you need a new `Priority.MIDDLEWARE.*` constant, add it to `core.lua`.

### Slash Commands (`/flux`)

| Command | Behavior |
|---|---|
| `/flux` | Toggle settings UI |
| `/flux burst` | Force offensive CDs for 3s (fires all `is_burst` tagged entries) |
| `/flux def` | Force defensive CDs for 3s (fires all `is_defensive` tagged entries) |
| `/flux gap` | Fire best gap closer (consumed on first success, uses `gap_handler`) |
| `/flux status` | Toggle combat dashboard |
| `/flux help` | Print command list |

### Burst Context System

Automatic burst conditions — users configure **when** burst CDs fire via schema checkboxes. Shared utility `NS.should_auto_burst(context)` in core.lua checks:

| Setting Key | Condition |
|---|---|
| `burst_on_bloodlust` | Bloodlust/Heroism buff detected |
| `burst_on_pull` | First 5s of combat |
| `burst_on_execute` | Target < 20% HP |
| `burst_in_combat` | Always in combat with valid target |

These settings go in a "Dashboard" tab of each class's schema. Burst-tagged middleware/strategies can check `NS.should_auto_burst(context)` in their `matches()` to fire automatically under these conditions.

### Force-Bypass Dispatch (main.lua)

When `/flux burst` or `/flux def` is active:
1. The dispatch loop checks `is_burst`/`is_defensive` on each middleware and strategy
2. If tagged and flag active: **bypasses `matches()` and `check_prerequisites()`**
3. If the entry has a `spell` property, `IsReady()` is still checked at dispatch level (CD, range, stance respected). Entries without `spell` rely on `execute()` checking `IsReady()` internally via `try_cast` or explicit guard
4. Burst/defensive flags last 3 seconds (dumps all CDs over multiple GCDs)
5. Gap closer flag is consumed on first successful fire

---

## 9. Strategy & Middleware Contracts

### Execution Flow (every frame)

```
A[3] called by TMW
  └─ refresh_settings()
  └─ create_context(icon)
     └─ extend_context(ctx)          ← your class adds fields here
  └─ execute_middleware(icon, context)
     └─ for each middleware (priority desc):
        └─ if matches(context) → execute(icon, context)
  └─ get_idle_playstyle(context) → if idle:
     └─ execute_strategies(idle, icon, context)
  └─ get_active_playstyle(context) → if active:
     └─ validate_playstyle_spells(active)
     └─ execute_strategies(active, icon, context)
        └─ get_playstyle_state (context_builder)
        └─ for each strategy (priority desc):
           └─ check_prerequisites
           └─ check_prerequisites (config)
           └─ if matches(context, state) → execute(icon, context, state)
```

### CRITICAL: check_prerequisites — Strategies vs Middleware

**Strategies** go through `check_prerequisites()` (core.lua:743-755) BEFORE `matches()` is called. This means the following strategy table properties are auto-checked and should NOT be duplicated inside `matches()`:

| Property | What it checks | Don't duplicate in matches |
|----------|---------------|---------------------------|
| `requires_combat` | `context.in_combat` must match | `if not context.in_combat` |
| `requires_enemy` | `context.has_valid_enemy_target` must match | `if not context.has_valid_enemy_target` |
| `requires_in_range` | `context.in_melee_range` must match | `if not context.in_melee_range` |
| `setting_key` | `context.settings[key]` must be truthy | `if not context.settings[key]` |
| `spell` | `spell:IsReady(spell_target or TARGET_UNIT)` + availability | `if not spell:IsReady(target)` |

For self-cast spells (totems, self-buffs), set `spell_target = PLAYER_UNIT` so the `IsReady()` check uses the correct target.

```lua
-- GOOD: let check_prerequisites handle everything, matches only has real logic
local MyStrategy = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.MySpell,
    spell_target = PLAYER_UNIT,  -- for self-cast
    setting_key = "use_my_spell",

    -- matches only needed for logic NOT covered by properties above
    matches = function(context, state)
        if state.dot_duration > 2 then return false end
        return true
    end,

    execute = function(icon, context, state) ... end,
}

-- BAD: redundant checks that check_prerequisites already handles
local MyStrategy = {
    requires_combat = true,
    spell = A.MySpell,
    setting_key = "use_my_spell",

    matches = function(context, state)
        if not context.in_combat then return false end        -- REDUNDANT (requires_combat)
        if not context.settings.use_my_spell then return false end  -- REDUNDANT (setting_key)
        return A.MySpell:IsReady(TARGET_UNIT)                 -- REDUNDANT (spell)
    end,
}
```

**Buff-active checks on cooldown abilities are also redundant.** For any ability where the buff duration is shorter than the cooldown (e.g., Icy Veins: 20s buff / 3min CD), the buff being active guarantees the spell is on cooldown, so `IsReady()` returns false. Don't add "if buff_active then return false" — the `spell` property handles it. This applies to: Icy Veins, Combustion, Arcane Power, Presence of Mind, Cold Blood, Elemental Mastery, Shamanistic Rage, Nature's Swiftness, Avenging Wrath, Divine Illumination, Divine Favor, Water Elemental, etc.

**Exception:** Permanent toggle buffs with no cooldown (e.g., Righteous Fury) — `IsReady()` always returns true, so you DO need the buff check. Also, external debuffs like Forbearance that block casting are NOT checked by `IsReady()` — those checks are real logic and must stay in `matches()`.

**Middleware does NOT go through `check_prerequisites`.** The `execute_middleware()` function (main.lua:48-72) calls `mw.matches(context)` directly. This means:
- ALL checks inside middleware `matches()` are necessary — nothing is auto-checked
- Properties like `spell`, `setting_key`, `requires_combat` on middleware tables are **ignored** during execution (only `priority` and `is_gcd_gated` are used)
- Middleware must manually check combat state, settings, spell readiness, etc.

### Return Contract

Both `matches` and `execute` follow the same pattern:

- `matches(context, state)` → `boolean`
  - `true`: proceed to execute
  - `false`: skip this strategy

- `execute(icon, context, state)` → `result, log_message`
  - `result` truthy + `log_message` string: spell was cast, rotation stops for this frame
  - `nil`: spell couldn't cast, fall through to next strategy

### GCD Gating

By default, strategies only run when NOT on GCD. Set `is_gcd_gated = false` for off-GCD abilities (trinkets, racials, next-swing abilities like Maul).

```lua
-- Runs during GCD (off-GCD ability)
local Mage_Trinket = {
    is_gcd_gated = false,
    -- ...
}
```

---

## 10. Context Object Reference

The context table is created fresh each frame by `main.lua:create_context()` and extended by your class's `extend_context()`.

### Base Fields (all classes get these)

| Field | Type | Source |
|-------|------|--------|
| `on_gcd` | bool | `Player:GCDRemains() > 0.1` |
| `icon` | table | The TMW icon being evaluated |
| `in_combat` | bool | `Unit("player"):CombatTime() > 0` |
| `hp` | number | `Unit("player"):HealthPercent()` |
| `mana_pct` | number | `Player:ManaPercentage()` |
| `mana` | number | `Player:Mana()` |
| `target_exists` | bool | `Unit("target"):IsExists()` |
| `target_dead` | bool | `Unit("target"):IsDead()` |
| `target_enemy` | bool | `Unit("target"):IsEnemy()` |
| `has_valid_enemy_target` | bool | exists AND not dead AND enemy |
| `target_hp` | number | `Unit("target"):HealthPercent()` |
| `ttd` | number | `Unit("target"):TimeToDie()` |
| `target_range` | number | `Unit("target"):GetRange()` max range |
| `in_melee_range` | bool | `target_range <= 5` |
| `target_phys_immune` | bool | Physical immunity check |
| `settings` | table | Reference to `cached_settings` |
| `gcd_remaining` | number | `Player:GCDRemains()` |

### Class Extension Examples

**Druid** adds: `stance`, `is_stealthed`, `energy`, `cp`, `rage`, `is_behind`, `has_clearcasting`, `enemy_count`, `_cat_valid`, `_bear_valid`, `_resto_valid`

**Hunter** adds: `weapon_speed`, `combat_time`, `is_moving`, `is_mounted`, `shoot_timer`, `pet_exists`, `pet_dead`, `pet_active`, `pet_hp`

---

## 11. Settings System

### How Settings Flow

```
schema.lua defines _G.FluxAIO_SETTINGS_SCHEMA
    ↓
ui.lua reads schema → generates A.Data.ProfileUI[2] (framework backing store)
    ↓
core.lua refresh_settings() → reads GetToggle(2, key) → writes cached_settings[key]
    ↓
context.settings = cached_settings (set each frame in create_context)
    ↓
Strategies access via context.settings.key_name
```

### Reading Settings in Strategies

**ALWAYS** access via `context.settings` inside `matches`/`execute`. NEVER capture at load time.

```lua
-- CORRECT: read from context each frame
matches = function(context)
    return context.settings.use_fireball
end

-- WRONG: captured at load time (won't update when user changes setting)
local use_fireball = A.GetToggle(2, "use_fireball")  -- BAD!
```

### Writing Settings (rare, only in UI code)

```lua
A.SetToggle({2, "key_name", nil, true}, value)
-- Args: {tab_number, key, display_text, silence_flag}
-- MUST be positional array, NOT named keys
```

---

## 12. Registration API Reference

### `rotation_registry:register_class(config)`

Called once in `class.lua`. Registers the class with the rotation system.

### `rotation_registry:register(playstyle, strategies, config)`

Called once per playstyle module. `strategies` is an array of strategy tables (array order = priority, first = highest).

```lua
rotation_registry:register("fire", {
    named("Strategy1", strategy1_table),
    named("Strategy2", strategy2_table),
}, { context_builder = get_fire_state })
```

**WARNING**: `register` REPLACES the strategy list for that playstyle. Don't call it twice for the same playstyle.

### `rotation_registry:register_middleware(middleware)`

Called for each middleware handler (usually in `middleware.lua`).

```lua
rotation_registry:register_middleware({
    name = "UniqueMiddlewareName",
    priority = 300,  -- Higher = runs first
    matches = function(context) ... end,
    execute = function(icon, context) ... end,
})
```

---

## 13. Common Utility Functions

All available on `NS` (the `_G.FluxAIO` namespace):

### Casting Helpers
```lua
-- Simple cast with log message
NS.try_cast(spell, icon, target, "log message")
    → result, log_message | nil

-- Formatted cast with dynamic log
NS.try_cast_fmt(spell, icon, target, prefix, name, format_str, ...)
    → result, log_message | nil

-- Low-level cast (checks unavailable_spells + IsReady)
NS.safe_ability_cast(ability, icon, target, debug_context)
    → result | nil

-- Self-cast (forces unit="player")
NS.safe_self_cast(ability, icon)
    → result | nil
```

### Buff/Debuff Helpers
```lua
NS.is_debuff_active(spell, target, source) → bool
NS.get_debuff_state(spell, target, source) → stacks, duration
NS.is_buff_active(spell, target, source) → bool
```

### Immunity Helpers
```lua
NS.has_phys_immunity(target) → bool
NS.has_magic_immunity(target) → bool
NS.has_cc_immunity(target) → bool
NS.has_stun_immunity(target) → bool
NS.has_kick_immunity(target) → bool
NS.has_total_immunity(target) → bool
```

### Spell Helpers
```lua
NS.is_spell_known(spell) → known, name
NS.is_spell_available(spell) → bool  -- not in unavailable_spells
NS.check_spell_availability(entries, missing, optional)  -- bulk check
```

### Resource Cost Helpers
```lua
NS.get_spell_mana_cost(spell) → number
NS.get_spell_rage_cost(spell) → number
NS.get_spell_energy_cost(spell) → number
NS.get_spell_focus_cost(spell) → number
```

### Combat Helpers
```lua
NS.get_time_to_die(unit_id) → number
NS.is_swing_landing_soon(threshold) → bool
NS.get_time_until_swing() → number
```

### Factory Functions
```lua
-- Create a simple combat strategy
NS.create_combat_strategy(config) → strategy_table

-- Set strategy name (used at registration)
NS.named(name, strategy) → strategy  -- sets strategy.name, returns it
```

### Debug
```lua
NS.debug_print(...)  -- Throttled debug output (1.5s per unique message)
NS.AddDebugLogLine(text)  -- Raw log line to debug frame
```

---

## 14. Lua 5.1 Gotchas

1. **No `goto` statement** — use nested ifs or early returns instead
2. **No inline table creation in combat** — WoW secure execution blocks `{}` during combat. Pre-allocate all tables at load time.
3. **200 local variable limit** per function scope — split large functions
4. **No `continue` in loops** — use `if not condition then` wrapper or restructure
5. **`select('#', ...)` for vararg count** — `#arg` doesn't work in Lua 5.1 varargs
6. **Table length operator `#`** only works on arrays (sequential integer keys from 1)
7. **No bitwise operators** — use `bit.band`, `bit.bor`, etc. if needed

---

## 15. Framework API Quick Reference

```lua
-- Unit state
Unit("target"):HealthPercent()
Unit("target"):HasDeBuffs(spellID_or_table, source, exact)  → duration
Unit("target"):HasDeBuffsStacks(spellID, source, exact)      → stacks
Unit("target"):HasBuffs(spellID_or_table, source, exact)     → duration
Unit("target"):HasBuffsStacks(spellID, source, exact)        → stacks
Unit("target"):TimeToDie()
Unit("target"):GetRange()                                     → max, min
Unit("target"):IsExists()
Unit("target"):IsDead()
Unit("target"):IsEnemy()
Unit("target"):IsBoss()
Unit("target"):Classification()                               → "worldboss"/"elite"/"rareelite"/"normal"
Unit("target"):CombatTime()
Unit("target"):InCC()                                         → cc_remaining
Unit("target"):IsMoving()
Unit("target"):IsCastingRemains()                             → castLeft, _, _, _, notKickAble

-- Player state
Player:Mana()
Player:ManaPercentage()
Player:Energy()
Player:Rage()
Player:ComboPoints()
Player:GetStance()                     → 0=Caster, 1=Bear, 3=Cat, 5=Moonkin
Player:IsStealthed()
Player:IsBehind(tolerance)
Player:IsMoving()
Player:IsMounted()
Player:GCDRemains()
Player:GetSwing(1)                     → melee swing duration
Player:GetSwingStart(1)                → melee swing start time
Player:GetSwingShoot()                 → ranged shoot timer
Player:EnergyTimeToX(target, offset)   → seconds until energy reaches target
Player:IsShooting()
Player:IsAttacking()

-- Spell actions
spell:IsReady(target)
spell:IsInRange(target)
spell:Show(icon)                       → result (truthy = success)
spell:GetCooldown()                    → seconds remaining
spell:GetSpellCastTimeCache()          → cast time
spell:GetSpellPowerCostCache()         → cost, powerType
spell:IsExists()                       → bool
spell:IsSpellCurrent()                 → bool (queued/active)
spell:Info()                           → spell name string
spell:AbsentImun(unit, immuneTable)    → bool

-- Settings
A.GetToggle(2, "key")                  → value
A.SetToggle({2, "key", nil, true}, value)

-- Multi-target
A.MultiUnits:GetByRange(yards)                     → count
A.MultiUnits:GetByRangeMissedDoTs(range, duration, spellID)  → count
A.MultiUnits:GetActiveUnitPlates()                 → table of unitIDs
A.MultiUnits:GetActiveEnemies()                    → count

-- Framework
A.AuraIsValid(unit, category, auraType)  → bool (smart dispel filtering)
A.BurstIsON(unit)                        → bool
A.IsUnitEnemy(unit)                      → bool
A.GetGCD()                               → seconds
A.GetCurrentGCD()                        → seconds remaining
A.GetLatency()                           → seconds
A.LossOfControl                          → LoC library
A.IsInPvP                                → bool
```

---

## 16. Checklist

When adding a new class (e.g. Mage):

- [ ] Create `rotation/source/aio/mage/` directory
- [ ] Create `schema.lua` — gate on PlayerClass, enable profile, define settings schema
- [ ] Create `class.lua` — define all spells, constants, class registration
- [ ] Create `middleware.lua` — recovery items (healthstones, potions, runes)
- [ ] Create playstyle files (e.g. `fire.lua`, `frost.lua`, `arcane.lua`)
- [ ] Each file has `if A.PlayerClass ~= "MAGE" then return end` gate
- [ ] Each file validates NS/dependencies before proceeding
- [ ] Settings keys are all **snake_case**
- [ ] No settings captured at load time (always `context.settings.key`)
- [ ] No inline table creation `{}` in combat code paths
- [ ] Pre-allocated state tables for `context_builder` pattern
- [ ] Cache invalidation flags in `extend_context` (e.g. `ctx._fire_valid = false`)
- [ ] `extend_context` adds all class-specific context fields
- [ ] All file names are lowercase single words (no underscores/hyphens/spaces)
- [ ] Tag burst strategies/middleware with `is_burst = true`
- [ ] Tag defensive strategies/middleware with `is_defensive = true`
- [ ] Add `gap_handler` to `register_class()` (if class has gap closers)
- [ ] Add `dashboard` config to `register_class()` (cooldowns, buffs, debuffs to display)
- [ ] Add "Dashboard" tab to schema with `show_dashboard` + 4 burst context checkboxes
- [ ] Run `node build.js` — should discover and compile the new class
- [ ] Update version locations if doing a release (see MEMORY.md)
- [ ] Add class color to `settings.lua` `CLASS_TITLE_COLORS` table

### settings.lua Color Registration

In `rotation/source/aio/settings.lua`, add your class color:

```lua
local CLASS_TITLE_COLORS = { Druid = "ff7d0a", Hunter = "abd473", Mage = "69ccf0" }
```

This controls the colored class name in the settings UI title bar.
