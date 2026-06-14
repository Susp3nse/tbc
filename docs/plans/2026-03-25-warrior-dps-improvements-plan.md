# Warrior DPS Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix warrior DPS gaps: HS/Cleave WW starvation, execute phase, Arms AoE priority, SS rage pooling, and add Kebab (DW Arms) playstyle.

**Architecture:** Surgical changes to existing Arms/Fury strategy files (rage checks in matches functions), new kebab.lua module auto-discovered by build.js, schema/class registration updates. All changes follow existing strategy registry patterns.

**Tech Stack:** Lua 5.1 (WoW addon), Node.js build system

**Reference:** Design doc at `docs/plans/2026-03-25-warrior-dps-improvements-design.md`, wowsims TBC warrior sim, omni rotation comparison.

---

### Task 1: Arms — HS/Cleave WW Starvation Fix + AoE MS Yield + Execute Phase + SS Pooling

**Files:**
- Modify: `rotation/source/aio/warrior/arms.lua`

**Step 1: Add SS rage pooling helper**

After the existing `should_pool_for_core_arms` function (line ~94), add:

```lua
-- ============================================================================
-- SWEEPING STRIKES RAGE POOLING
-- ============================================================================
-- When SS is coming off CD in AoE, hold WW and fillers so we can afford SS+WW.
-- SS (30) + WW (25) = 55 rage. Reserve floor of 60 gives a small buffer.
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0  -- seconds

local function should_reserve_for_sweeping(context)
    if context.enemy_count < 2 then return false end
    if not context.settings.arms_use_sweeping_strikes then return false end
    if not is_spell_available(A.SweepingStrikes) then return false end
    if context.sweeping_strikes_active then return false end
    local ss_cd = A.SweepingStrikes:GetCooldown() or 0
    -- SS ready or coming off CD soon — reserve rage
    if ss_cd <= SS_POOL_WINDOW and context.rage < SS_RESERVE_FLOOR then return true end
    return false
end
```

**Step 2: Add WW starvation check helper**

Below the SS pooling helper, add:

```lua
-- ============================================================================
-- HS/CLEAVE CORE ABILITY STARVATION CHECK
-- ============================================================================
-- Don't queue HS/Cleave if it would starve an imminent core ability (MS or WW).
local function would_starve_core_arms(context, state, cost)
    cost = cost or 15  -- HS base cost
    -- MS imminent and spending cost would starve it
    if state.ms_cd >= 0 and state.ms_cd <= 1.5 and context.in_melee_range then
        if (context.rage - cost) < RAGE_COST_MS then return true end
    end
    -- WW imminent and spending cost would starve it
    if context.settings.arms_use_whirlwind then
        if state.ww_cd >= 0 and state.ww_cd <= 1.5 and context.in_melee_range then
            if (context.rage - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end
```

**Step 3: Modify Arms_MortalStrike to yield to WW in AoE**

In `Arms_MortalStrike.matches()`, add AoE yield check after the execute phase check:

```lua
    matches = function(context, state)
        -- During execute phase, check setting
        if state.target_below_20 and context.settings.arms_execute_phase then
            if not context.settings.arms_use_ms_execute then return false end
        end
        -- AoE: yield to WW when 2+ enemies (WW hits 4 targets, higher priority)
        if context.enemy_count >= 2 and context.rage >= 25
            and context.settings.arms_use_whirlwind
            and A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true) then
            return false
        end
        return A.MortalStrike:IsReady(TARGET_UNIT)
    end,
```

**Step 4: Modify Arms_Whirlwind to respect SS pooling**

In `Arms_Whirlwind.matches()`, add SS reserve check after the rage check:

```lua
        -- 25 rage cost — check explicitly since skipUsable bypasses resource checks
        if context.rage < 25 then return false end
        -- Hold WW if Sweeping Strikes is imminent and we need to pool rage
        if should_reserve_for_sweeping(context) then return false end
```

**Step 5: Modify Arms_Execute to use base cost instead of hardcoded 25**

```lua
    matches = function(context, state)
        if not state.target_below_20 then return false end
        -- Fire Execute at base cost — every rage point above cost adds +21 damage
        local exec_cost = A.Execute:GetSpellPowerCostCache() or 15
        if context.rage < exec_cost then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,
```

**Step 6: Modify Arms_Slam to respect SS pooling**

In `Arms_Slam.matches()`, add SS reserve check after core pooling:

```lua
        -- Resource pooling: hold GCD for MS/WW if imminent and rage is tight
        if should_pool_for_core_arms(context, state) then return false end
        -- Hold filler if Sweeping Strikes is imminent in AoE
        if should_reserve_for_sweeping(context) then return false end
```

**Step 7: Modify Arms_HeroicStrike to check core starvation**

In `Arms_HeroicStrike.matches()`, add starvation check before returning true at the threshold check:

```lua
        local threshold = context.settings.arms_hs_rage_threshold or 45
        if context.rage < threshold then return false end
        -- Don't queue HS/Cleave if it would starve an imminent core ability
        if would_starve_core_arms(context, state, 15) then return false end
        -- Smart rage hold: don't dump into HS when an interrupt may be needed soon
```

**Step 8: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds with no errors.

**Step 9: Commit**

```bash
git add rotation/source/aio/warrior/arms.lua
git commit -m "warrior(arms): fix HS/WW starvation, AoE priority, execute phase, SS pooling"
```

---

### Task 2: Fury — HS/Cleave WW Starvation Fix + Execute Phase + SS Pooling

**Files:**
- Modify: `rotation/source/aio/warrior/fury.lua`

**Step 1: Add SS rage pooling helper**

After `should_pool_for_core_fury` (line ~97), add same pattern as arms:

```lua
-- ============================================================================
-- SWEEPING STRIKES RAGE POOLING
-- ============================================================================
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context)
    if context.enemy_count < 2 then return false end
    if not context.settings.fury_use_sweeping_strikes then return false end
    if not is_spell_available(A.SweepingStrikes) then return false end
    if context.sweeping_strikes_active then return false end
    local ss_cd = A.SweepingStrikes:GetCooldown() or 0
    if ss_cd <= SS_POOL_WINDOW and context.rage < SS_RESERVE_FLOOR then return true end
    return false
end
```

**Step 2: Add core starvation check**

```lua
-- ============================================================================
-- HS/CLEAVE CORE ABILITY STARVATION CHECK
-- ============================================================================
local function would_starve_core_fury(context, state, cost)
    cost = cost or 15
    -- BT imminent
    if state.bt_cd >= 0 and state.bt_cd <= 1.5 and context.in_melee_range then
        if (context.rage - cost) < RAGE_COST_BT then return true end
    end
    -- WW imminent
    if context.settings.fury_use_whirlwind then
        if state.ww_cd >= 0 and state.ww_cd <= 1.5 and context.in_melee_range then
            if (context.rage - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end
```

**Step 3: Modify Fury_Whirlwind to respect SS pooling**

In `Fury_Whirlwind.matches()`, after `if context.rage < 25 then return false end`:

```lua
        -- Hold WW if Sweeping Strikes is imminent and we need to pool rage
        if should_reserve_for_sweeping(context) then return false end
```

**Step 4: Modify Fury_Execute to use base cost**

```lua
    matches = function(context, state)
        if not state.target_below_20 then return false end
        -- Fire Execute at base cost — every rage point above cost adds +21 damage
        local exec_cost = A.Execute:GetSpellPowerCostCache() or 15
        if context.rage < exec_cost then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,
```

**Step 5: Modify Fury_Slam to respect SS pooling**

In `Fury_Slam.matches()`, after `should_pool_for_core_fury`:

```lua
        -- Hold filler if Sweeping Strikes is imminent in AoE
        if should_reserve_for_sweeping(context) then return false end
```

**Step 6: Modify Fury_HeroicStrike to check core starvation**

In `Fury_HeroicStrike.matches()`, change the threshold section:

```lua
        local threshold = context.settings.fury_hs_rage_threshold or 40
        -- HS Trick: lower threshold when dual-wielding (the dequeue middleware handles safety)
        if context.settings.hs_trick and context.has_offhand then
            threshold = 30
        end
        if context.rage < threshold then return false end
        -- Don't queue HS/Cleave if it would starve an imminent core ability
        if would_starve_core_fury(context, state, 15) then return false end
        -- Smart rage hold: don't dump into HS when an interrupt may be needed soon
```

**Step 7: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 8: Commit**

```bash
git add rotation/source/aio/warrior/fury.lua
git commit -m "warrior(fury): fix HS/WW starvation, execute phase, SS pooling"
```

---

### Task 3: Schema — HS Threshold Defaults + Execute Defaults + Kebab Tab

**Files:**
- Modify: `rotation/source/aio/warrior/schema.lua`

**Step 1: Update playstyle dropdown to add Kebab**

In Tab 1 → Spec Selection → playstyle dropdown options, add kebab:

```lua
                    options = {
                        { value = "arms", text = "Arms" },
                        { value = "fury", text = "Fury" },
                        { value = "kebab", text = "Kebab (DW Arms)" },
                        { value = "protection", text = "Protection" },
                    },
```

**Step 2: Update Arms HS threshold default**

Change `arms_hs_rage_threshold` default from `50` to `45`.

**Step 3: Update Arms HS during execute default**

Change `arms_hs_during_execute` default from `true` to `false`.
Update tooltip to: `"Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage)."`

**Step 4: Update Fury HS threshold default**

Change `fury_hs_rage_threshold` default from `50` to `40`.

**Step 5: Update Fury HS during execute default**

Change `fury_hs_during_execute` default from `true` to `false`.
Update tooltip to: `"Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage). Exception: with HS trick, ON keeps yellow OH hits."`

**Step 6: Add Tab 7 — Kebab (DW Arms)**

After Tab 6 (PvP), add a new tab:

```lua
    -- Tab 7: Kebab (DW Arms)
    [7] = {
        name = "Kebab (DW Arms)",
        sections = {
            {
                header = "Core Abilities",
                settings = {
                    {
                        type = "checkbox",
                        key = "kebab_use_overpower",
                        default = true,
                        label = "Use Overpower",
                        tooltip = "Use Overpower on dodge procs when already in Battle Stance (avoids unnecessary stance dance).",
                    },
                    {
                        type = "checkbox",
                        key = "kebab_use_whirlwind",
                        default = true,
                        label = "Use Whirlwind",
                        tooltip = "Use Whirlwind on cooldown (Berserker Stance).",
                    },
                    {
                        type = "checkbox",
                        key = "kebab_use_sweeping_strikes",
                        default = true,
                        label = "Use Sweeping Strikes",
                        tooltip = "Use Sweeping Strikes on cooldown in AoE.",
                    },
                },
            },
            {
                header = "Utility",
                settings = {
                    {
                        type = "checkbox",
                        key = "kebab_use_victory_rush",
                        default = true,
                        label = "Use Victory Rush",
                        tooltip = "Use Victory Rush (free instant attack after a killing blow, 0 rage).",
                    },
                },
            },
            {
                header = "Execute Phase",
                settings = {
                    {
                        type = "checkbox",
                        key = "kebab_execute_phase",
                        default = true,
                        label = "Execute Phase",
                        tooltip = "Switch to Execute priority at <20% target HP.",
                    },
                    {
                        type = "checkbox",
                        key = "kebab_use_ms_execute",
                        default = true,
                        label = "MS During Execute",
                        tooltip = "Use Mortal Strike during execute phase.",
                    },
                    {
                        type = "checkbox",
                        key = "kebab_use_ww_execute",
                        default = true,
                        label = "WW During Execute",
                        tooltip = "Use Whirlwind during execute phase.",
                    },
                },
            },
            {
                header = "Rage Dump",
                settings = {
                    {
                        type = "slider",
                        key = "kebab_hs_rage_threshold",
                        default = 40,
                        min = 25,
                        max = 80,
                        label = "HS Rage Threshold",
                        tooltip = "Queue Heroic Strike above this rage.",
                        format = "%d",
                    },
                    {
                        type = "checkbox",
                        key = "kebab_hs_during_execute",
                        default = false,
                        label = "HS During Execute",
                        tooltip = "Allow Heroic Strike during execute phase. OFF recommended (every rage point in Execute = +21 damage).",
                    },
                },
            },
            {
                header = "Cooldowns",
                settings = {
                    {
                        type = "checkbox",
                        key = "kebab_use_death_wish",
                        default = true,
                        label = "Use Death Wish",
                        tooltip = "Use Death Wish cooldown (+20% damage).",
                    },
                },
            },
        },
    },
```

**Step 7: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 8: Commit**

```bash
git add rotation/source/aio/warrior/schema.lua
git commit -m "warrior(schema): add Kebab tab, lower HS defaults, disable HS during execute"
```

---

### Task 4: Class Registration — Add Kebab Playstyle

**Files:**
- Modify: `rotation/source/aio/warrior/class.lua`

**Step 1: Add kebab to playstyles array**

Change line 252:
```lua
    playstyles = { "arms", "fury", "kebab", "protection" },
```

**Step 2: Add kebab to PREFERRED_STANCE**

```lua
    PREFERRED_STANCE = {
        arms       = 1,  -- Battle
        fury       = 3,  -- Berserker
        kebab      = 3,  -- Berserker (DW Arms)
        protection = 2,  -- Defensive
    },
```

**Step 3: Add playstyle_spells.kebab**

After the `fury` entry in `playstyle_spells`:

```lua
        kebab = {
            { spell = A.MortalStrike, name = "Mortal Strike", required = true, note = "Arms talent" },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Overpower, name = "Overpower", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.SweepingStrikes, name = "Sweeping Strikes", required = false, note = "Fury talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
        },
```

**Step 4: Add kebab dashboard entries**

In `dashboard.cooldowns`, add:
```lua
            kebab = { A.SweepingStrikes, A.DeathWish, A.Trinket1, A.Trinket2 },
```

In `dashboard.buffs`, add:
```lua
            kebab = {
                { id = Constants.BUFF_ID.SWEEPING_STRIKES, label = "SS" },
                { id = Constants.BUFF_ID.DEATH_WISH, label = "DW" },
                { id = Constants.BUFF_ID.ENRAGE, label = "Enr" },
                { id = Constants.BUFF_ID.FLURRY, label = "Flurry" },
            },
```

In `dashboard.debuffs`, add:
```lua
            kebab = {
                { id = Constants.DEBUFF_ID.SUNDER_ARMOR, label = "Sunder", target = true, show_stacks = true },
            },
```

**Step 5: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds.

**Step 6: Commit**

```bash
git add rotation/source/aio/warrior/class.lua
git commit -m "warrior(class): register kebab playstyle, stance, spells, dashboard"
```

---

### Task 5: Kebab Module — New Playstyle File

**Files:**
- Create: `rotation/source/aio/warrior/kebab.lua`

**Step 1: Create the full kebab.lua module**

Create `rotation/source/aio/warrior/kebab.lua` with the complete rotation. This file follows the same patterns as arms.lua and fury.lua but with:

- Home stance: Berserker
- Priority: Execute > WW > MS > OP (Battle stance only) > VR > Sunder > TC > Demo > HS/Cleave
- AoE: SS (with pooling) > WW > MS > Cleave
- No Slam, no Rend
- Overpower only when already in Battle Stance (no proactive stance dance)
- HS/Cleave with core starvation check

The full file content:

```lua
--- Kebab Warrior Module (DW Arms)
--- Dual-wield Arms playstyle: Mortal Strike + Whirlwind in Berserker Stance
--- Follows the fury rotation pattern but with MS instead of BT, OP on procs
--- Part of the modular AIO rotation system

-- ============================================================
-- IMPORTANT: NEVER capture settings values at load time!
-- Always access settings through context.settings in matches/execute.
-- ============================================================

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Kebab]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Menagerie Kebab]|r Registry not found!")
    return
end

local A = NS.A
local Constants = NS.Constants
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local is_stance_swap_safe = NS.is_stance_swap_safe
local debug_print = NS.debug_print
local PLAYER_UNIT = NS.PLAYER_UNIT or "player"
local TARGET_UNIT = NS.TARGET_UNIT or "target"
local format = string.format

-- ============================================================================
-- KEBAB STATE (context_builder)
-- ============================================================================
local kebab_state = {
    target_below_20 = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    thunder_clap_duration = 0,
    demo_shout_duration = 0,
    ms_cd = 0,
    ww_cd = 0,
}

local function get_kebab_state(context)
    if context._kebab_valid then return kebab_state end
    context._kebab_valid = true

    kebab_state.target_below_20 = context.target_hp < 20
    kebab_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    kebab_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.SUNDER_ARMOR) or 0
    kebab_state.thunder_clap_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.THUNDER_CLAP) or 0
    kebab_state.demo_shout_duration = Unit(TARGET_UNIT):HasDeBuffs(Constants.DEBUFF_ID.DEMO_SHOUT) or 0
    kebab_state.ms_cd = A.MortalStrike:GetCooldown() or 0
    kebab_state.ww_cd = A.Whirlwind:GetCooldown() or 0

    return kebab_state
end

-- ============================================================================
-- RAGE CONSTANTS
-- ============================================================================
local RAGE_COST_MS = 30
local RAGE_COST_WW = 25
local RAGE_COST_PUMMEL = 10

-- ============================================================================
-- SWEEPING STRIKES RAGE POOLING
-- ============================================================================
local SS_RESERVE_FLOOR = 60
local SS_POOL_WINDOW = 2.0

local function should_reserve_for_sweeping(context)
    if context.enemy_count < 2 then return false end
    if not context.settings.kebab_use_sweeping_strikes then return false end
    if not is_spell_available(A.SweepingStrikes) then return false end
    if context.sweeping_strikes_active then return false end
    local ss_cd = A.SweepingStrikes:GetCooldown() or 0
    if ss_cd <= SS_POOL_WINDOW and context.rage < SS_RESERVE_FLOOR then return true end
    return false
end

-- ============================================================================
-- HS/CLEAVE CORE ABILITY STARVATION CHECK
-- ============================================================================
local function would_starve_core_kebab(context, state, cost)
    cost = cost or 15
    -- MS imminent
    if state.ms_cd >= 0 and state.ms_cd <= 1.5 and context.in_melee_range then
        if (context.rage - cost) < RAGE_COST_MS then return true end
    end
    -- WW imminent
    if context.settings.kebab_use_whirlwind then
        if state.ww_cd >= 0 and state.ww_cd <= 1.5 and context.in_melee_range then
            if (context.rage - cost) < RAGE_COST_WW then return true end
        end
    end
    return false
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do

-- [1] Execute (target <20% HP — highest ST priority per sim)
local Kebab_Execute = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_execute_phase",

    matches = function(context, state)
        if not state.target_below_20 then return false end
        local exec_cost = A.Execute:GetSpellPowerCostCache() or 15
        if context.rage < exec_cost then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[KEBAB] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- [2] Sweeping Strikes (AoE — before WW to double hits)
local Kebab_SweepingStrikes = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_sweeping_strikes",

    matches = function(context, state)
        if not is_spell_available(A.SweepingStrikes) then return false end
        if context.sweeping_strikes_active then return false end
        if context.enemy_count < 2 then return false end
        if context.rage < 30 then return false end
        return A.SweepingStrikes:IsReady(PLAYER_UNIT, nil, nil, nil, true)
    end,

    execute = function(icon, context, state)
        return A.SweepingStrikes:Show(icon), format("[KEBAB] Sweeping Strikes - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
    end,
}

-- [3] Whirlwind (Berserker Stance — above MS for DW, guarded by SS reserve)
local Kebab_Whirlwind = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_whirlwind",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_use_ww_execute then return false end
        end
        if context.rage < 25 then return false end
        if should_reserve_for_sweeping(context) then return false end
        return A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true)
    end,

    execute = function(icon, context, state)
        if context.stance ~= Constants.STANCE.BERSERKER then
            if not is_stance_swap_safe(context.rage, 25) then return nil end
            if A.BerserkerStance:IsReady(PLAYER_UNIT) then
                return A.BerserkerStance:Show(icon), "[KEBAB] → Berserker (for WW)"
            end
            return nil
        end
        return A.Whirlwind:Show(icon), format("[KEBAB] Whirlwind - Rage: %d", context.rage)
    end,
}

-- [4] Mortal Strike (below WW in priority for DW)
local Kebab_MortalStrike = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_use_ms_execute then return false end
        end
        return A.MortalStrike:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.MortalStrike, icon, TARGET_UNIT, "[KEBAB] Mortal Strike")
    end,
}

-- [5] Overpower (only if already in Battle Stance with dodge proc)
-- No proactive stance dance — Kebab lives in Berserker, uses OP opportunistically
local Kebab_Overpower = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "kebab_use_overpower",

    matches = function(context, state)
        -- Only use if already in Battle Stance (from a stance swap for other reasons)
        if context.stance ~= Constants.STANCE.BATTLE then return false end
        return A.Overpower:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.Overpower, icon, TARGET_UNIT,
            format("[KEBAB] Overpower - Rage: %d", context.rage))
    end,
}

-- [6] Victory Rush (free instant after killing blow)
local Kebab_VictoryRush = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.VictoryRush,
    setting_key = "kebab_use_victory_rush",

    execute = function(icon, context, state)
        return try_cast(A.VictoryRush, icon, TARGET_UNIT, "[KEBAB] Victory Rush")
    end,
}

-- [7] Sunder Armor maintenance (if configured)
local Kebab_SunderMaintain = {
    requires_combat = true,
    requires_enemy = true,

    matches = function(context, state)
        local mode = context.settings.sunder_armor_mode or "none"
        if mode == "none" then return false end

        if mode == "help_stack" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS then return false end
        elseif mode == "maintain" then
            if state.sunder_stacks >= Constants.SUNDER_MAX_STACKS
                and state.sunder_duration > Constants.SUNDER_REFRESH_WINDOW then
                return false
            end
        end

        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then return true end
        return A.SunderArmor:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        if is_spell_available(A.Devastate) and A.Devastate:IsReady(TARGET_UNIT) then
            return try_cast(A.Devastate, icon, TARGET_UNIT,
                format("[KEBAB] Devastate (Sunder) - Stacks: %d", state.sunder_stacks))
        end
        return try_cast(A.SunderArmor, icon, TARGET_UNIT,
            format("[KEBAB] Sunder Armor - Stacks: %d", state.sunder_stacks))
    end,
}

-- [8] Thunder Clap maintenance
local Kebab_ThunderClap = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_thunder_clap",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if state.thunder_clap_duration > 2 then return false end
        return A.ThunderClap:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.ThunderClap, icon, PLAYER_UNIT,
            format("[KEBAB] Thunder Clap - Duration: %.1fs", state.thunder_clap_duration))
    end,
}

-- [9] Demoralizing Shout maintenance
local Kebab_DemoShout = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "maintain_demo_shout",

    matches = function(context, state)
        if context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check then return false end
        if not context.in_melee_range then return false end
        if state.demo_shout_duration > 3 then return false end
        return A.DemoralizingShout:IsReady(PLAYER_UNIT)
    end,

    execute = function(icon, context, state)
        return try_cast(A.DemoralizingShout, icon, PLAYER_UNIT,
            format("[KEBAB] Demo Shout - Duration: %.1fs", state.demo_shout_duration))
    end,
}

-- [10] Heroic Strike / Cleave (off-GCD rage dump with core starvation check)
local Kebab_HeroicStrike = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,

    matches = function(context, state)
        if A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent() then return false end
        if state.target_below_20 and context.settings.kebab_execute_phase then
            if not context.settings.kebab_hs_during_execute then return false end
        end
        -- HS Trick: proactively queue when OH swing is imminent
        if context.settings.hs_trick and context.has_offhand then
            local oh_remaining = context.oh_remain or 0
            local mh_remaining = context.mh_remain or 0
            if oh_remaining > 0 and oh_remaining <= 0.4 then
                if mh_remaining > oh_remaining + 0.3 then
                    return true
                end
            end
        end
        local threshold = context.settings.kebab_hs_rage_threshold or 40
        if context.settings.hs_trick and context.has_offhand then
            threshold = 30
        end
        if context.rage < threshold then return false end
        if would_starve_core_kebab(context, state, 15) then return false end
        if context.settings.use_interrupt then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                if (context.rage - 15) < RAGE_COST_PUMMEL then return false end
            end
        end
        return true
    end,

    execute = function(icon, context, state)
        local cleave_at = context.settings.aoe_threshold or 2
        local cc_safe = not (context.has_breakable_cc_nearby and context.settings.pvp_cc_break_check)
        if cc_safe and cleave_at > 0 and context.enemy_count >= cleave_at and A.Cleave:IsReady(TARGET_UNIT) then
            return A.Cleave:Show(icon), format("[KEBAB] Cleave - Rage: %d, Enemies: %d", context.rage, context.enemy_count)
        end

        if A.HeroicStrike:IsReady(TARGET_UNIT) then
            return A.HeroicStrike:Show(icon), format("[KEBAB] Heroic Strike - Rage: %d", context.rage)
        end
        return nil
    end,
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================
rotation_registry:register("kebab", {
    named("Execute",         Kebab_Execute),          -- Highest ST priority per sim
    named("SweepingStrikes", Kebab_SweepingStrikes),  -- Before WW to double hits in AoE
    named("Whirlwind",       Kebab_Whirlwind),        -- Above MS for DW (more damage per rage)
    named("MortalStrike",    Kebab_MortalStrike),
    named("Overpower",       Kebab_Overpower),         -- Opportunistic (Battle Stance only)
    named("VictoryRush",     Kebab_VictoryRush),
    named("SunderMaintain",  Kebab_SunderMaintain),
    named("ThunderClap",     Kebab_ThunderClap),
    named("DemoShout",       Kebab_DemoShout),
    named("HeroicStrike",    Kebab_HeroicStrike),
}, {
    context_builder = get_kebab_state,
})

end -- scope block

-- ============================================================================
-- MODULE LOADED
-- ============================================================================
print("|cFF00FF00[Menagerie Warrior]|r Kebab module loaded")
```

**Step 2: Build and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds, kebab.lua auto-discovered at order 7.

**Step 3: Commit**

```bash
git add rotation/source/aio/warrior/kebab.lua
git commit -m "warrior: add Kebab (DW Arms) playstyle module"
```

---

### Task 6: Class Registration — Add Kebab Context Cache Flag

**Files:**
- Modify: `rotation/source/aio/warrior/class.lua`

**Step 1: Add `_kebab_valid` cache flag**

In `extend_context`, alongside the existing cache flags (line ~366-368):

```lua
        ctx._arms_valid = false
        ctx._fury_valid = false
        ctx._kebab_valid = false
        ctx._prot_valid = false
```

**Step 2: Build full project and verify**

Run: `cd rotation && node build.js`
Expected: Build succeeds. All modules load in correct order.

**Step 3: Commit**

```bash
git add rotation/source/aio/warrior/class.lua
git commit -m "warrior(class): add kebab context cache flag"
```

---

### Task 7: Final Build Verification

**Step 1: Full build**

Run: `cd rotation && node build.js`
Expected: Build succeeds with all warrior modules loaded.

**Step 2: Verify kebab module is included in output**

Run: `grep -c "Kebab" rotation/output/TellMeWhen.lua`
Expected: Multiple matches (module print, strategy names, etc.)

**Step 3: Verify no broken references**

Run: `grep "kebab" rotation/output/TellMeWhen.lua | head -5`
Expected: kebab references appear correctly in compiled output.
