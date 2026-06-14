# Menagerie API Reference

> **Auto-generated from source** — `rotation/source/aio/core.lua`, `main.lua`, `common.lua`, `dashboard.lua`, `settings.lua`
>
> Last updated: 2026-02-25

---

## Table of Contents

1. [Namespace Overview](#namespace-overview)
2. [Framework References](#framework-references)
3. [Constants](#constants)
4. [Spell Cost Utilities](#spell-cost-utilities)
5. [Immunity Detection](#immunity-detection)
6. [Aura Helpers](#aura-helpers)
7. [Swing Timer](#swing-timer)
8. [Combat Utilities](#combat-utilities)
9. [Casting Helpers](#casting-helpers)
10. [Generic Utilities](#generic-utilities)
11. [Settings System](#settings-system)
12. [Spell Availability](#spell-availability)
13. [Force Flag System](#force-flag-system)
14. [Burst Context](#burst-context)
15. [Notifications](#notifications)
16. [Debug System](#debug-system)
17. [Rotation Registry](#rotation-registry)
18. [Strategy Contract](#strategy-contract)
19. [Middleware Contract](#middleware-contract)
20. [Strategy Factory](#strategy-factory)
21. [Trinket Middleware Factory](#trinket-middleware-factory)
22. [Context Object](#context-object)
23. [Execution Model](#execution-model)
24. [Class Registration](#class-registration)
25. [Settings Schema](#settings-schema)
26. [Dashboard](#dashboard)
27. [Settings UI](#settings-ui)
28. [Shared Middleware Factories (Planned)](#shared-middleware-factories-planned)

---

## Namespace Overview

All Menagerie modules share the `_G.Menagerie` namespace, aliased as `NS` locally in every file:

```lua
local NS = _G.Menagerie
local A = NS.A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
```

Class modules gate on `A.PlayerClass`:
```lua
if A.PlayerClass ~= "DRUID" then return end
```

---

## Framework References

Aliases to the GGL Action framework, set once during initialization.

| Key | Value | Description |
|-----|-------|-------------|
| `NS.A` | `Action` | The Action framework root (set by class.lua) |
| `NS.Player` | `A.Player` | Player resource/state queries |
| `NS.Unit` | `A.Unit` | Unit constructor `Unit(unitID)` |
| `NS.GetToggle` | `A.GetToggle` | Read setting: `GetToggle(2, "key")` |

---

## Constants

### Unit IDs

```lua
NS.PLAYER_UNIT = "player"
NS.TARGET_UNIT = "target"
```

### Race Constants

```lua
NS.RACE_TROLL = "Troll"
NS.RACE_ORC = "Orc"
```

### Priority Table

Controls middleware execution order. Higher = runs first.

```lua
NS.Priority = {
    MIDDLEWARE = {
        FORM_RESHIFT       = 500,
        EMERGENCY_HEAL     = 400,
        PROACTIVE_HEAL     = 390,
        DISPEL_CURSE       = 350,
        DISPEL_POISON      = 340,
        RECOVERY_ITEMS     = 300,
        INNERVATE          = 290,
        MANA_RECOVERY      = 280,
        SELF_BUFF_MOTW     = 150,
        SELF_BUFF_THORNS   = 145,
        SELF_BUFF_OOC      = 140,
        OFFENSIVE_COOLDOWNS = 100,
    }
}
```

### Per-Class Constants

Defined in `core.lua` under `NS.Constants` (varies by class). Common entries:

```lua
NS.Constants = {
    STANCE = { CASTER = 0, BEAR = 1, CAT = 3, MOONKIN = 5 },  -- Druid
    -- Warrior: BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3
    TTD = { ... },       -- Time-to-die thresholds
    ENERGY = { ... },    -- Energy thresholds (Rogue/Druid)
    BEAR = { ... },      -- Bear rotation settings
    BALANCE = { ... },   -- Moonkin mana tiers
}
```

---

## Spell Cost Utilities

Query the resource cost of a spell. Returns 0 if the spell doesn't use that resource.

```lua
NS.get_spell_mana_cost(spell)    --> number
NS.get_spell_rage_cost(spell)    --> number
NS.get_spell_energy_cost(spell)  --> number
NS.get_spell_focus_cost(spell)   --> number
```

**Parameters:**
- `spell` — `Action.Spell` object

---

## Immunity Detection

Check if a target has specific immunity buffs (Bubble, DI, Ice Block, etc.).

```lua
NS.has_total_immunity(target)   --> boolean
NS.has_phys_immunity(target)    --> boolean
NS.has_magic_immunity(target)   --> boolean
NS.has_cc_immunity(target)      --> boolean
NS.has_stun_immunity(target)    --> boolean
NS.has_kick_immunity(target)    --> boolean
```

**Parameters:**
- `target` — unit string (default `"target"`)

---

## Aura Helpers

Simplified buff/debuff queries that wrap the framework's `HasBuffs`/`HasDeBuffs`.

```lua
NS.is_debuff_active(spell, target, source)  --> boolean
NS.get_debuff_state(spell, target, source)  --> stacks, duration
NS.is_buff_active(spell, target, source)    --> boolean
```

**Parameters:**
- `spell` — `Action.Spell` object
- `target` — unit string
- `source` — (optional) source unit filter

---

## Swing Timer

Melee swing timing for abilities that interact with auto-attacks (Heroic Strike, Seal Twisting).

```lua
NS.is_swing_landing_soon(threshold)  --> boolean
```
Returns `true` if next melee swing lands within `threshold` seconds (default 0.15).

```lua
NS.get_time_until_swing()  --> number
```
Returns seconds until next melee swing, or 0.

---

## Combat Utilities

```lua
NS.get_time_to_die(unit_id)  --> number
```
- `unit_id` — unit string (default `"target"`)
- Returns estimated seconds to death, or 500 if unavailable

---

## Casting Helpers

Safe wrappers that check spell availability and `IsReady()` before casting.

### try_cast

```lua
NS.try_cast(spell, icon, target, log_message)  --> result, log_message | nil
```
Checks `is_spell_available()` and `IsReady()`, then calls `safe_ability_cast()`.

### try_cast_fmt

```lua
NS.try_cast_fmt(spell, icon, target, prefix, name, info_fmt, ...)  --> result, formatted_msg | nil
```
Like `try_cast` but builds a formatted log message: `"[prefix] name - info_fmt"`.

### safe_ability_cast

```lua
NS.safe_ability_cast(ability, icon, target, debug_context)  --> result | nil
```
Checks `unavailable_spells`, calls `IsReady()`, shows via `ability:Show(icon)`.

### safe_self_cast

```lua
NS.safe_self_cast(ability, icon)  --> result | nil
```
Forces `Click = {unit = "player"}` for self-targeted spells.

### safe_heal_cast

```lua
NS.safe_heal_cast(ability, icon, target_unit, log_message)  --> result, log_message | nil
```
Uses `A.HealingEngine.SetTarget()` to inject `[@unit,help]` macro targeting.

---

## Generic Utilities

```lua
NS.round_half(num)  --> number
```
Rounds to nearest 0.5 (e.g., 3.7 -> 3.5, 4.3 -> 4.5).

---

## Settings System

### cached_settings

```lua
NS.cached_settings  -- table
```
Contains all current settings as `snake_case` keys. Refreshed every 0.05s from the schema.

**Never capture at load time.** Always access via `context.settings` inside `matches()`/`execute()`:

```lua
-- WRONG: captured once at load
local my_val = A.GetToggle(2, "my_key")

-- CORRECT: read every frame via context
matches = function(context)
    return context.settings.my_key
end
```

### refresh_settings

```lua
NS.refresh_settings()
```
Rebuilds `cached_settings` from `_G.Menagerie_SETTINGS_SCHEMA`. Called every frame by `main.lua`. Throttled to 0.05s intervals.

---

## Spell Availability

Track which spells the player knows (handles talents, level gating).

```lua
NS.unavailable_spells  -- set of unknown spell objects
```

```lua
NS.is_spell_known(spell)  --> known: boolean, name: string
```
Checks `IsSpellKnown()` or `spell:IsExists()`.

```lua
NS.is_spell_available(spell)  --> boolean
```
Returns `true` if spell is known by the player.

```lua
NS.check_spell_availability(entries, missing, optional)
```
Batch validation. Each entry: `{spell, name, required, note}`. Populates `unavailable_spells`.

---

## Force Flag System

Supports `/menagerie burst`, `/menagerie def`, `/menagerie gap` slash commands. Flags expire after 3 seconds.

```lua
NS.force_burst = 0       -- expiry timestamp
NS.force_defensive = 0   -- expiry timestamp
NS.force_gap = 0         -- expiry timestamp
```

```lua
NS.set_force_flag(flag_name)     -- sets to GetTime() + 3.0
NS.is_force_active(flag_name)    --> boolean
NS.clear_force_flag(flag_name)   -- immediately deactivates
```

**flag_name:** `"force_burst"` | `"force_defensive"` | `"force_gap"`

**Force-bypass behavior:**
- When active, skips `matches()` and `check_prerequisites()` on tagged entries
- But if `spell` is set on the entry, `IsReady()` is **still checked** (CD, range, stance)
- Entries without `spell` must check `IsReady()` inside `execute()`

---

## Burst Context

```lua
NS.should_auto_burst(context)  --> true | false | nil
```

Returns:
- `nil` — no burst conditions configured (fire freely)
- `true` — at least one configured condition is met
- `false` — conditions configured but none currently met

Checks schema settings:
- `burst_on_bloodlust` — Bloodlust/Heroism buff active
- `burst_on_pull` — `combat_time < 5s`
- `burst_on_execute` — `target_hp < 20%`
- `burst_in_combat` — always if in combat

---

## Notifications

```lua
NS.show_notification(text, duration, color)
```
- `text` — string to display
- `duration` — seconds (default 1.5)
- `color` — `{r, g, b}` table (default white)

Shows a brief center-screen notification that fades out.

---

## Debug System

```lua
NS.debug_print(...)
```
Throttled print (1.5s per unique message). Only fires when debug mode is enabled in settings.

```lua
NS.CreateDebugLogFrame()   --> frame
NS.RefreshDebugLogFrame()
NS.AddDebugLogLine(text)
NS.DebugLogFrame           -- frame reference (after creation)
```

Toggle with `/menagerielog` or `/mlog`.

---

## Rotation Registry

The central registry managing class config, middleware, and per-playstyle strategies.

```lua
NS.rotation_registry  -- registry object
```

### register_class

```lua
rotation_registry:register_class(config)
```

Called once per class during load. See [Class Registration](#class-registration) for full config shape.

### register

```lua
rotation_registry:register(playstyle, strategies, config)
```

- `playstyle` — string (e.g., `"cat"`, `"fire"`)
- `strategies` — array of strategy tables. Position determines priority (first = highest, auto-assigned 1000 descending)
- `config` — optional `{context_builder, check_prerequisites, format_context_log}`

**Replaces** previous strategies for that playstyle (does not append).

### register_middleware

```lua
rotation_registry:register_middleware(middleware)
```

- `middleware` — middleware table (see [Middleware Contract](#middleware-contract))
- Auto-sorted by `priority` descending (higher = runs first)

### execute_middleware

```lua
rotation_registry:execute_middleware(icon, context)  --> result, log_msg | nil
```

Runs all middleware in priority order. Returns first non-nil result.

### execute_strategies

```lua
rotation_registry:execute_strategies(playstyle, icon, context)  --> result, log_msg | nil
```

Runs all strategies for a playstyle in priority order. Calls `get_playstyle_state()` for `state` parameter.

### check_prerequisites

```lua
rotation_registry:check_prerequisites(strategy, context)  --> boolean
```

Auto-checks these strategy fields (do **not** duplicate inside `matches()`):
- `requires_combat` — `context.in_combat`
- `requires_enemy` — `context.has_valid_enemy_target`
- `requires_in_range` — range check
- `setting_key` — `context.settings[key]` is truthy
- `spell` — `spell:IsReady(spell_target)` passes

### validate_playstyle_spells

```lua
rotation_registry:validate_playstyle_spells(playstyle)
```

Validates all spells in `playstyle_spells[playstyle]`, prints missing to chat.

### get_playstyle_state

```lua
rotation_registry:get_playstyle_state(playstyle, context)  --> state | nil
```

Calls the playstyle's `context_builder(context)` to get playstyle-specific state.

---

## Strategy Contract

A strategy is a table registered via `rotation_registry:register(playstyle, strategies)`.

```lua
{
    name = "StrategyName",              -- identifier for logging
    matches = function(context, state)  -- gate: return truthy to execute
        return boolean
    end,
    execute = function(icon, context, state)  -- action: cast spell
        return result, log_message
    end,

    -- Optional fields (auto-checked by check_prerequisites):
    setting_key = "key",         -- skips if context.settings[key] is falsy
    spell = A.SomeSpell,         -- auto-checks IsReady()
    spell_target = "target",     -- target for IsReady check (default "target")
    requires_combat = true,      -- skips if not in combat
    requires_enemy = true,       -- skips if no valid enemy target

    -- Optional behavior flags:
    is_burst = true,             -- /menagerie burst force-fires (bypasses matches)
    is_defensive = true,         -- /menagerie def force-fires
    is_gcd_gated = true,         -- default true; false for off-GCD abilities
    is_auto_form = true,         -- suppressed during PVE combat

    -- Optional suggestion system (for A[1] icon):
    should_suggest = function(context) return boolean end,
    suggestion_spell = A.SomeSpell,
}
```

**Key rules:**
- `matches()` receives `(context, state)` where `state` comes from `context_builder`
- `execute()` must return a truthy first value on success (usually `spell:Show(icon)`)
- Second return value is an optional log message string
- `setting_key` is auto-checked — do NOT duplicate in `matches()`

---

## Middleware Contract

Middleware is a table registered via `rotation_registry:register_middleware()`.

```lua
{
    name = "MiddlewareName",
    priority = 300,                    -- higher = runs first
    matches = function(context)        -- gate (no state param)
        return boolean
    end,
    execute = function(icon, context)  -- action (no state param)
        return result, log_message
    end,

    -- Optional:
    is_burst = true,                   -- /menagerie burst force-fires
    is_defensive = true,               -- /menagerie def force-fires
    is_gcd_gated = true,               -- default true
    spell = A.SomeSpell,               -- auto-checks IsReady()
    spell_target = "player",           -- target for IsReady (default "player")
    setting_key = "key",               -- auto-checked; uses == false comparison
}
```

**Differences from strategies:**
- No `state` parameter (middleware is playstyle-independent)
- `spell_target` defaults to `"player"` (not `"target"`)
- `setting_key` uses `== false` comparison (middleware check at `core.lua:801`)

---

## Strategy Factory

### create_combat_strategy

```lua
NS.create_combat_strategy(config)  --> strategy table
```

Factory for simple spell-based strategies:

```lua
local strat = NS.create_combat_strategy({
    spell = A.Mangle,            -- required
    name = "Mangle",
    target = "target",           -- default "target"
    prefix = "[P3]",             -- default "[P?]"
    setting_key = "use_mangle",  -- optional
    extra_match = function(context) return context.energy >= 40 end,
    log_fmt = "Energy: %d",
    log_args = function(context) return context.energy end,
})
```

### named

```lua
NS.named(name, strategy)  --> strategy
```

Sets `strategy.name = name` and returns the strategy. Convenience for inline definitions:

```lua
NS.named("MyStrat", {
    matches = function(ctx) return true end,
    execute = function(icon, ctx) return A.Spell:Show(icon) end,
})
```

---

## Trinket Middleware Factory

```lua
NS.register_trinket_middleware()
```

Must be called from class `middleware.lua`. Registers two middleware entries:
- **Trinkets_Burst** (priority 80) — fires offensive trinkets during burst
- **Trinkets_Defensive** (priority 290) — fires defensive trinkets at low HP

Respects `trinket1_mode` and `trinket2_mode` settings (`"burst"`, `"defensive"`, `"off"`).

---

## Context Object

Built every frame by `create_context(icon)` in `main.lua`. Passed to all `matches()`/`execute()` functions.

**This table is reused.** Do not hold references across frames.

### Base Fields

| Field | Type | Description |
|-------|------|-------------|
| `icon` | frame | TMW icon object |
| `on_gcd` | boolean | GCD remaining > 0.1s |
| `gcd_remaining` | number | Seconds of GCD remaining |
| `in_combat` | boolean | Player in combat |
| `combat_time` | number | Seconds since entering combat (0 if OOC) |
| `hp` | number | Player health percent (0-100) |
| `mana` | number | Current mana (absolute) |
| `mana_pct` | number | Mana percent (0-100) |
| `target_exists` | boolean | Target exists |
| `target_dead` | boolean | Target is dead |
| `target_enemy` | boolean | Target is enemy |
| `has_valid_enemy_target` | boolean | exists AND !dead AND enemy |
| `target_hp` | number | Target health percent |
| `ttd` | number | Target time-to-die (seconds) |
| `target_range` | number | Max range to target |
| `in_melee_range` | boolean | Min range <= 5yd |
| `target_phys_immune` | boolean | Target has physical immunity |
| `is_boss` | boolean | Target is boss (if valid target) |
| `settings` | table | Alias to `NS.cached_settings` |

### Class-Extended Fields

Added by `class_config.extend_context(ctx)`. Common patterns:

| Field | Classes | Description |
|-------|---------|-------------|
| `stance` | Druid, Warrior | Current form/stance number |
| `energy` | Druid, Rogue | Current energy |
| `rage` | Druid, Warrior | Current rage |
| `cp` | Rogue | Combo points |
| `is_stealthed` | Druid, Rogue | In stealth |
| `is_behind` | Rogue | Behind target (0.3 tolerance) |
| `is_moving` | All | Player is moving |
| `is_mounted` | Most | Player is mounted |
| `enemy_count` | Most | Nearby enemy count |
| `pet_hp` | Hunter, Warlock | Pet health percent |
| `pet_active` | Hunter, Warlock | Pet alive and active |
| `weapon_speed` | Hunter | Auto-shot attack speed |
| `shoot_timer` | Hunter | Auto-shot CD remaining |

### Playstyle State

Strategies receive a `state` parameter built by the playstyle's `context_builder`:

```lua
-- Example: cat state (from get_cat_state)
state.has_wolfshead      -- boolean
state.can_powershift     -- boolean
state.pooling            -- boolean (set by high-priority strategies)

-- Example: fire mage state (from get_fire_state)
state.scorch_stacks      -- number
state.scorch_duration    -- number
```

State is **per-playstyle** and only available to strategies, not middleware.

---

## Execution Model

Every frame, TMW calls `A[3](icon)`:

```
1. refresh_settings()           -- sync UI toggles -> cached_settings (0.05s throttle)
2. create_context(icon)         -- build base context table
3. extend_context(ctx)          -- class adds stance, energy, etc.
4. /menagerie gap check              -- if active, call gap_handler and return
5. execute_middleware(icon, ctx) -- shared: recovery, CDs, dispels, self-buffs
   |                              returns first non-nil result
   |-- for each middleware (priority desc):
       |-- skip if on_gcd (unless is_gcd_gated=false)
       |-- force-bypass if /menagerie burst + is_burst (skip matches, check spell)
       |-- force-bypass if /menagerie def + is_defensive (skip matches, check spell)
       |-- call matches(context) -> if truthy, call execute(icon, context)
6. get_active_playstyle(ctx)    -- determine combat form/spec
7. get_idle_playstyle(ctx)      -- determine idle form
8. Populate A[1] suggestions    -- scan idle strategies for should_suggest()
9. execute_strategies(idle)     -- if in idle form
10. execute_strategies(active)  -- if in active form
    |-- get_playstyle_state(playstyle, context) -> state
    |-- for each strategy (priority desc):
        |-- skip if on_gcd (unless is_gcd_gated=false)
        |-- check_prerequisites(strategy, context) -> auto-checks
        |-- force-bypass if /menagerie burst/def + tagged
        |-- call matches(context, state) -> if truthy, call execute(icon, context, state)
```

---

## Class Registration

```lua
rotation_registry:register_class({
    name = "Druid",
    version = "v1.0.0",
    playstyles = {"caster", "cat", "bear", "balance", "resto"},
    idle_playstyle_name = "caster",    -- nil for dropdown-based classes

    get_active_playstyle = function(context)
        -- Return playstyle string or nil
        -- Druid: reads stance. Mage/Shaman/etc: reads settings dropdown
    end,

    get_idle_playstyle = function(context)
        -- Return idle playstyle string or nil
    end,

    extend_context = function(ctx)
        -- Add class-specific fields to the shared context object
        ctx.stance = Player:GetStance()
        ctx.energy = Player:Energy()
    end,

    gap_handler = function(icon, context)
        -- /menagerie gap handler. Return spell:Show(icon) or nil
    end,

    dashboard = {
        resource = { text = "Energy", value_fn = fn, max_fn = fn },
        cooldowns = { {name, spell, color}, ... },
        buffs = { {name, ids_or_spell, color}, ... },
        debuffs = { {name, ids_or_spell, color}, ... },
        custom_lines = { fn, ... },
    },

    -- Optional:
    playstyle_spells = {
        ["cat"] = {
            {spell = A.Mangle, name = "Mangle", required = true},
            {spell = A.Rake, name = "Rake", required = false, note = "Skipping"},
        },
    },
    playstyle_labels = { ["cat"] = "Cat DPS" },
    check_prerequisites = function(strategy, context) return bool end,
    format_context_log = function(context, state) return string end,
})
```

### Playstyle Detection Patterns

**Stance-based (Druid):**
```lua
get_active_playstyle = function(context)
    local stance = context.stance
    if stance == 1 then return "bear" end
    if stance == 3 then return "cat" end
    -- ...
end
```

**Dropdown-based (Mage, Shaman, Warlock, Paladin, Priest, Rogue, Warrior):**
```lua
get_active_playstyle = function(context)
    return context.settings.playstyle  -- reads UI dropdown
end
```

---

## Settings Schema

Settings are defined in per-class `schema.lua` files via `_G.Menagerie_SETTINGS_SCHEMA`.

### Schema Structure

```lua
_G.Menagerie_SETTINGS_SCHEMA = {
    class = "DRUID",
    tabs = {
        {
            name = "General",
            sections = {
                {
                    header = "Recovery",
                    description = "Optional description text",
                    settings = {
                        { type = "checkbox", key = "use_healthstone", default = true,
                          label = "Use Healthstone", tooltip = "Use healthstone when low HP" },
                        { type = "slider", key = "healthstone_hp", default = 25,
                          min = 5, max = 95, step = 5, format = "%d%%",
                          label = "Healthstone HP%", tooltip = "HP threshold" },
                        { type = "dropdown", key = "playstyle", default = "fire",
                          label = "Playstyle",
                          options = {
                              { text = "Fire", value = "fire" },
                              { text = "Frost", value = "frost" },
                          },
                        },
                    },
                },
            },
        },
    },
}
```

### Setting Types

| Type | Fields | Description |
|------|--------|-------------|
| `checkbox` | `key, default, label, tooltip` | Boolean toggle |
| `slider` | `key, default, min, max, step, format, label, tooltip` | Numeric range |
| `dropdown` | `key, default, options, label, tooltip` | Select from options |

### Common Shared Sections

`_G.Menagerie_SECTIONS` (defined in `common.lua`) provides reusable section factories:

```lua
_G.Menagerie_SECTIONS.dashboard()           --> { header, settings } for dashboard toggle
_G.Menagerie_SECTIONS.burst()               --> { header, settings } for burst conditions
_G.Menagerie_SECTIONS.debug()               --> { header, settings } for debug toggles
_G.Menagerie_SECTIONS.trinkets(tooltip)     --> { header, settings } for trinket/racial modes
```

### Keys Are snake_case Everywhere

```lua
-- Schema
{ key = "use_mangle" }

-- Read via context
context.settings.use_mangle

-- Read directly (avoid in hot paths)
A.GetToggle(2, "use_mangle")

-- Write
A.SetToggle({2, "use_mangle", nil, true}, value)
--          ^ array positional: {tab, key, text, silence}
```

---

## Dashboard

The combat dashboard is a shared overlay driven by the `dashboard` config in `register_class()`.

### Public API

```lua
NS.set_last_action(name, source)
```
- `name` — strategy/middleware name
- `source` — `"MW"`, playstyle string, or `"CMD"`

Called by `main.lua` every frame to populate the "Priority" display.

```lua
NS.toggle_dashboard()
```
Toggles dashboard visibility. Creates frame on first call. Used by `/menagerie status`.

---

## Settings UI

```lua
NS.toggle_settings()
```
Toggles the custom tabbed settings frame. Used by `/menagerie` command and minimap button.

```lua
NS.settings_frame  -- frame reference (after creation)
```

---

## Shared Middleware Factories (Planned)

> **Status: NOT YET IMPLEMENTED.** These three modules are designed and approved but not yet created.
> See `docs/plans/2025-02-25-shared-middleware-design.md` for full design doc.

### Recovery Middleware Factory

**File:** `rotation/source/aio/recovery.lua` (planned)

Eliminates ~560 lines of duplicated recovery item code across 8 classes.

```lua
NS.register_recovery_middleware(class_name, config)
```

**Parameters:**
- `class_name` — string (e.g., `"Mage"`, `"Warrior"`)
- `config` — table of items to register:

```lua
-- Standard (all defaults)
NS.register_recovery_middleware("Mage", {
    healthstone = true,
    healing_potion = true,
    mana_potion = true,
    dark_rune = true,
})

-- Custom tiers / thresholds
NS.register_recovery_middleware("Warlock", {
    healthstone = { tiers = { A.HealthstoneFel, A.HealthstoneMaster, A.HealthstoneMajor } },
    healing_potion = true,
    mana_potion = { default_pct = 30, priority_offset = -5 },
    dark_rune = { default_pct = 30, priority_offset = -10 },
})

-- No mana items
NS.register_recovery_middleware("Rogue", {
    healthstone = true,
    healing_potion = true,
})
```

**Generated Middleware:**

| Item | Priority | Setting Keys | Conditions |
|------|----------|-------------|------------|
| Healthstone | `RECOVERY_ITEMS` (300) | `healthstone_hp` | In combat, HP < threshold |
| Healing Potion | 295 | `use_healing_potion`, `healing_potion_hp` | In combat, combat_time >= 2s, HP < threshold |
| Mana Potion | `MANA_RECOVERY` (280) | `use_mana_potion`, `mana_potion_pct` | In combat, combat_time >= 2s, mana% < threshold |
| Dark Rune | 275 | `use_dark_rune`, `dark_rune_pct`, `dark_rune_min_hp` | In combat, combat_time >= 2s, mana% < threshold, HP > min |

**Config overrides per item:**

| Item | Override Fields |
|------|----------------|
| `healthstone` | `tiers` (spell array), `extra_match` (function) |
| `healing_potion` | `default_hp` (number, default 25) |
| `mana_potion` | `default_pct` (number, default 50), `tiers` (spell array), `priority_offset` (number) |
| `dark_rune` | `default_pct`, `default_min_hp`, `priority_offset`, `setting_toggle`, `setting_threshold`, `setting_min_hp` |

---

### Threat Awareness Factory

**File:** `rotation/source/aio/threat.lua` (planned)

Adds configurable threat management for all DPS specs.

```lua
NS.register_threat_middleware(class_name, config)
```

**Parameters:**
- `class_name` — string
- `config`:
  - `dump_spell` — `Action.Spell` for threat dump (nil if class has no dump)
  - `dump_ready_check` — `function(context) -> bool` for extra conditions

```lua
-- Class with dump ability
NS.register_threat_middleware("Rogue", {
    dump_spell = A.Feint,
    dump_ready_check = function(context)
        return context.energy >= 20
    end,
})

-- Class with no dump
NS.register_threat_middleware("Mage", {})
```

**User Settings (added to schemas):**

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `threat_mode` | dropdown | `"dump"` | `"dump"` = use ability + stop DPS, `"stop"` = stop DPS only, `"off"` = ignore |
| `threat_scope` | dropdown | `"elite"` | `"all"` / `"elite"` / `"boss"` — which targets to manage threat on |

**Additional exports:**

```lua
NS.count_enemies_targeting_player()  --> { bosses, elites, trash, total }
```
Scans nameplates. Populates context fields: `context.threat_bosses`, `context.threat_elites`, `context.threat_trash`, `context.threat_total`.

---

### Interrupt Awareness Module

**File:** `rotation/source/aio/interrupt.lua` (planned)

Adds a priority cast database, smart interrupt decisions, and tab-target state machine.

#### Priority Database

```lua
NS.INTERRUPT_PRIORITY  -- table: [spellID] = "heal" | "cc" | "damage"
```

44+ spells categorized by danger level. Spells not in the table are treated as `"normal"`.

#### Decision Function

```lua
NS.should_interrupt(context)  --> "priority" | "normal" | false
```

Checks:
1. Target is casting and kickable
2. Not recently interrupted (dedup via combat log)
3. TTD > 2s (don't waste kick on dying target)
4. Target meets `interrupt_scope` classification
5. Cast has progressed past `interrupt_delay`
6. Returns `"priority"` if spell is in DB, `"normal"` if not

**Usage in class interrupt middleware:**

```lua
matches = function(context)
    if not context.in_combat then return false end
    local decision = NS.should_interrupt(context)
    if not decision then return false end
    if decision == "normal" and context.settings.interrupt_priority_only then
        return false
    end
    return true
end,
```

#### Tab-Target State Machine

For classes with ranged interrupts (Shaman, Mage, Priest Shadow):

```lua
NS.interrupt_tab_matches(class_name, context, interrupt_spell, max_range)  --> boolean
NS.interrupt_tab_execute(class_name, icon, context, interrupt_spell)  --> result, log
```

State machine phases: `idle` -> `seeking` (tab toward caster) -> `returning` (tab back to original target).

#### Priority Caster Scanner

```lua
NS.find_priority_caster(max_range)  --> guid, castLeft, spellName | nil
```

Scans nameplates for enemies casting priority spells. Picks the caster with the most remaining cast time.

#### Capability Registration

```lua
NS.register_interrupt_capability(class_name, config)
```

- `config.supports_tab_target` — boolean
- `config.resolve_spell` — `function(context) -> Action.Spell`

**User Settings (added to schemas):**

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `interrupt_priority_only` | checkbox | `false` | Only kick heals, CC, big damage |
| `interrupt_scope` | dropdown | `"all"` | `"all"` / `"elite"` / `"boss"` |
| `interrupt_delay` | slider | `0` | Seconds to wait before kicking (0-1s) |

---

## Slash Commands Reference

| Command | Handler | Description |
|---------|---------|-------------|
| `/menagerie` | `NS.toggle_settings()` | Toggle settings UI |
| `/menagerie burst` | `NS.set_force_flag("force_burst")` | Force offensive CDs for 3s |
| `/menagerie def` | `NS.set_force_flag("force_defensive")` | Force defensive CDs for 3s |
| `/menagerie gap` | `NS.set_force_flag("force_gap")` | Fire gap closer (consumed on first success) |
| `/menagerie status` | `NS.toggle_dashboard()` | Toggle combat dashboard |
| `/menagerie help` | — | Print command list |
| `/menagerielog` | `NS.CreateDebugLogFrame()` | Toggle debug log window |
