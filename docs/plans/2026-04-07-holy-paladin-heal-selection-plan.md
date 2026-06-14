# Holy Paladin Smart Heal Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace threshold-based HL/FoL selection with deficit math, downranking, Light's Grace management, and healing reduction awareness.

**Architecture:** Add per-rank spell actions and rank tables to class.lua, enrich healing target entries in healing.lua, build a `select_heal()` decision function in holy.lua that picks spell type + optimal rank based on deficit, then merge the two heal strategies into one.

**Tech Stack:** Lua 5.1 (WoW addon), Node.js build system (`node build.js`)

**Testing:** `cd rotation && node build.js` to compile. In-game verification via `/menagerie` debug logs.

---

### Task 1: Add per-rank spell Actions to class.lua

**Files:**
- Modify: `rotation/source/aio/paladin/class.lua:54-59`

**Step 1: Add rank actions after the existing max-rank entries**

Find lines 54-59 (the healing spell block). After the existing `LayOnHands` line, add the per-rank actions. Keep the existing max-rank entries (used elsewhere).

```lua
    -- Healing rank tables (for downranking)
    HolyLightR1  = Create({ Type = "Spell", ID = 635 }),
    HolyLightR2  = Create({ Type = "Spell", ID = 639 }),
    HolyLightR3  = Create({ Type = "Spell", ID = 647 }),
    HolyLightR4  = Create({ Type = "Spell", ID = 1026 }),
    HolyLightR5  = Create({ Type = "Spell", ID = 1042 }),
    HolyLightR6  = Create({ Type = "Spell", ID = 3472 }),
    HolyLightR7  = Create({ Type = "Spell", ID = 10328 }),
    HolyLightR8  = Create({ Type = "Spell", ID = 10329 }),
    HolyLightR9  = Create({ Type = "Spell", ID = 25292 }),
    HolyLightR10 = Create({ Type = "Spell", ID = 27135 }),
    HolyLightR11 = Create({ Type = "Spell", ID = 27136 }),

    FlashOfLightR1 = Create({ Type = "Spell", ID = 19759 }),
    FlashOfLightR2 = Create({ Type = "Spell", ID = 19939 }),
    FlashOfLightR3 = Create({ Type = "Spell", ID = 19940 }),
    FlashOfLightR4 = Create({ Type = "Spell", ID = 19941 }),
    FlashOfLightR5 = Create({ Type = "Spell", ID = 19942 }),
    FlashOfLightR6 = Create({ Type = "Spell", ID = 19943 }),
    FlashOfLightR7 = Create({ Type = "Spell", ID = 27137 }),
```

**Step 2: Add rank data tables and healing constants**

After the Constants table (around line 184, after `NS.Constants = Constants`), add:

```lua
-- ============================================================================
-- HEALING RANK TABLES
-- Sorted high-to-low for downranking (first viable rank wins)
-- { spell = Action, base_min = N, base_max = N, label = "R11" }
-- ============================================================================
local HOLY_LIGHT_RANKS = {
    { spell = A.HolyLightR11, base_min = 2196, base_max = 2446, label = "R11" },
    { spell = A.HolyLightR10, base_min = 1773, base_max = 1971, label = "R10" },
    { spell = A.HolyLightR9,  base_min = 1619, base_max = 1799, label = "R9" },
    { spell = A.HolyLightR8,  base_min = 1272, base_max = 1414, label = "R8" },
    { spell = A.HolyLightR7,  base_min = 968,  base_max = 1076, label = "R7" },
    { spell = A.HolyLightR6,  base_min = 717,  base_max = 799,  label = "R6" },
    { spell = A.HolyLightR5,  base_min = 506,  base_max = 569,  label = "R5" },
    { spell = A.HolyLightR4,  base_min = 322,  base_max = 368,  label = "R4" },
    { spell = A.HolyLightR3,  base_min = 167,  base_max = 196,  label = "R3" },
    { spell = A.HolyLightR2,  base_min = 81,   base_max = 96,   label = "R2" },
    { spell = A.HolyLightR1,  base_min = 42,   base_max = 51,   label = "R1" },
}

local FLASH_OF_LIGHT_RANKS = {
    { spell = A.FlashOfLightR7, base_min = 458, base_max = 513, label = "R7" },
    { spell = A.FlashOfLightR6, base_min = 356, base_max = 396, label = "R6" },
    { spell = A.FlashOfLightR5, base_min = 278, base_max = 310, label = "R5" },
    { spell = A.FlashOfLightR4, base_min = 206, base_max = 231, label = "R4" },
    { spell = A.FlashOfLightR3, base_min = 153, base_max = 171, label = "R3" },
    { spell = A.FlashOfLightR2, base_min = 102, base_max = 117, label = "R2" },
    { spell = A.FlashOfLightR1, base_min = 67,  base_max = 77,  label = "R1" },
}

-- Healing coefficients (base, before Healing Light talent)
local HL_COEFFICIENT = 0.7143   -- 2.5 / 3.5
local FOL_COEFFICIENT = 0.4286  -- 1.5 / 3.5
local HEALING_LIGHT_MULT = 1.12 -- +12% from Healing Light talent (assumed)

-- Healing reduction debuff names (MS and similar effects)
local HEALING_REDUCTION_DEBUFFS = {
    "Mortal Strike",
    "Aimed Shot",
    "Wound Poison",
    "Mortal Cleave",
}

NS.HOLY_LIGHT_RANKS = HOLY_LIGHT_RANKS
NS.FLASH_OF_LIGHT_RANKS = FLASH_OF_LIGHT_RANKS
NS.HL_COEFFICIENT = HL_COEFFICIENT
NS.FOL_COEFFICIENT = FOL_COEFFICIENT
NS.HEALING_LIGHT_MULT = HEALING_LIGHT_MULT
NS.HEALING_REDUCTION_DEBUFFS = HEALING_REDUCTION_DEBUFFS
```

**Step 3: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 4: Commit**

```
feat(holy): add per-rank HL/FoL spell actions and rank tables
```

---

### Task 2: Enrich healing target entries

**Files:**
- Modify: `rotation/source/aio/paladin/healing.lua:38-114`

**Step 1: Import healing reduction debuff list**

At the top of the file, after the existing imports (~line 27), add:

```lua
local HEALING_REDUCTION_DEBUFFS = NS.HEALING_REDUCTION_DEBUFFS
```

**Step 2: Add new fields to pre-allocated target pool**

Update both pre-allocation blocks (lines 41-43 and 93-95) to include new fields:

```lua
{ unit = nil, hp = 100, is_player = false, has_aggro = false,
  is_tank = false, has_poison = false, has_disease = false,
  has_magic = false, needs_cleanse = false,
  has_healing_reduction = false, incoming_dps = 0, deficit = 0 }
```

**Step 3: Populate new fields in scan loop**

After the `entry.is_tank` line (~line 108), add:

```lua
                entry.deficit = _G.UnitHealthMax(unit) - _G.UnitHealth(unit)
                entry.incoming_dps = Unit(unit):GetDMG() or 0

                -- Check for healing reduction debuffs (MS, Aimed Shot, etc.)
                entry.has_healing_reduction = false
                for k = 1, #HEALING_REDUCTION_DEBUFFS do
                    if (Unit(unit):HasDeBuffs(HEALING_REDUCTION_DEBUFFS[k]) or 0) > 0 then
                        entry.has_healing_reduction = true
                        break
                    end
                end
```

**Step 4: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 5: Commit**

```
feat(holy): enrich healing targets with deficit, incoming DPS, healing reduction
```

---

### Task 3: Build `select_heal()` function in holy.lua

**Files:**
- Modify: `rotation/source/aio/paladin/holy.lua`

**Step 1: Import rank tables and constants**

After the existing imports (~line 41), add:

```lua
local HOLY_LIGHT_RANKS = NS.HOLY_LIGHT_RANKS
local FLASH_OF_LIGHT_RANKS = NS.FLASH_OF_LIGHT_RANKS
local HL_COEFFICIENT = NS.HL_COEFFICIENT
local FOL_COEFFICIENT = NS.FOL_COEFFICIENT
local HEALING_LIGHT_MULT = NS.HEALING_LIGHT_MULT
local GetSpellBonusHealing = _G.GetSpellBonusHealing
```

**Step 2: Add helper function to compute expected heal for a rank entry**

Place after the imports, before `get_holy_state`:

```lua
-- Compute expected heal for a rank entry given current +healing
local function expected_heal(rank_entry, bonus_healing, coefficient)
    local base_avg = (rank_entry.base_min + rank_entry.base_max) / 2
    return (base_avg + bonus_healing * coefficient) * HEALING_LIGHT_MULT
end

-- Select best rank from a rank table for a given deficit
-- Returns rank_entry or nil if no rank is trained
-- overheal_mult: how much overheal is acceptable (1.3 = 30% overheal OK)
local function select_rank(rank_table, deficit, bonus_healing, coefficient, skip_overheal_opt)
    local best = nil
    for i = 1, #rank_table do
        local entry = rank_table[i]
        if entry.spell:IsReady("player") then
            local heal = expected_heal(entry, bonus_healing, coefficient)
            if skip_overheal_opt then
                -- MS on target: just use highest trained rank (need throughput)
                return entry
            end
            if heal <= deficit * 1.3 then
                -- This rank fits (heals up to 130% of deficit)
                return entry
            end
            -- This rank overheals, but remember it as fallback (lowest trained rank)
            best = entry
        end
    end
    -- All ranks overheal — use lowest trained rank to minimize waste
    return best
end
```

**Step 3: Add the main `select_heal()` function**

Place after `select_rank`:

```lua
-- Pre-allocated result table (no table creation in combat)
local heal_result = { spell = nil, label = "", spell_type = "" }

-- select_heal: picks spell type (HL vs FoL) and best rank for target
-- Returns heal_result table or nil
local function select_heal(context, state, target)
    if context.is_moving then return nil end

    local bonus_healing = GetSpellBonusHealing() or 0
    local deficit = target.deficit or 0

    -- Determine spell type: HL or FoL
    local use_hl = false

    -- MS/healing reduction → HL (FoL is useless at 50% reduced)
    if target.has_healing_reduction then
        use_hl = true
    -- Divine Favor active → HL (maximize guaranteed crit value)
    elseif state.divine_favor_active then
        use_hl = true
    -- High incoming DPS → HL (FoL throughput can't keep up)
    elseif target.incoming_dps and target.incoming_dps > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        local fol_hps = max_fol / 1.5  -- FoL cast time
        if target.incoming_dps > fol_hps then
            use_hl = true
        end
    end

    -- Deficit math (only if not already forced to HL)
    if not use_hl and deficit > 0 then
        local max_fol = expected_heal(FLASH_OF_LIGHT_RANKS[1], bonus_healing, FOL_COEFFICIENT)
        if deficit > max_fol * 1.3 then
            use_hl = true
        end
    end

    -- Tank proactive: FoL even at full HP in combat (mana floor gated)
    if not use_hl and deficit == 0 and target.is_tank and context.in_combat then
        local mana_floor = context.settings.proactive_fol_mana_floor or 30
        if context.mana_pct < mana_floor then return nil end
        -- Use lowest trained FoL rank for minimal mana waste
        for i = #FLASH_OF_LIGHT_RANKS, 1, -1 do
            local entry = FLASH_OF_LIGHT_RANKS[i]
            if entry.spell:IsReady("player") then
                heal_result.spell = entry.spell
                heal_result.label = "FoL " .. entry.label
                heal_result.spell_type = "FoL"
                return heal_result
            end
        end
        return nil
    end

    -- No deficit and not proactive → don't heal
    if deficit == 0 then return nil end

    -- Select best rank
    local skip_overheal = target.has_healing_reduction
    if use_hl then
        local rank = select_rank(HOLY_LIGHT_RANKS, deficit, bonus_healing, HL_COEFFICIENT, skip_overheal)
        if not rank then return nil end
        heal_result.spell = rank.spell
        heal_result.label = "HL " .. rank.label
        heal_result.spell_type = "HL"
    else
        local rank = select_rank(FLASH_OF_LIGHT_RANKS, deficit, bonus_healing, FOL_COEFFICIENT, skip_overheal)
        if not rank then return nil end
        heal_result.spell = rank.spell
        heal_result.label = "FoL " .. rank.label
        heal_result.spell_type = "FoL"
    end

    return heal_result
end
```

**Step 4: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 5: Commit**

```
feat(holy): add select_heal() with deficit math and rank selection
```

---

### Task 4: Add Light's Grace proc strategy

**Files:**
- Modify: `rotation/source/aio/paladin/holy.lua`

**Step 1: Add the strategy**

Place after the `Holy_LayOnHands` strategy (around line 202), before the existing `Holy_HolyLight`:

```lua
-- [6] Light's Grace proc (HL R1 to activate -0.5s HL cast time buff)
-- Luxury cast: only when nobody is in danger
local Holy_LightsGraceProc = {
    spell = A.HolyLightR1,
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not context.in_combat then return false end
        if state.lights_grace_active then return false end
        if state.divine_favor_active then return false end
        -- Safety: skip if anyone is critically low
        if state.emergency_count > 0 then return false end
        local targets, count = scan_healing_targets()
        for i = 1, count do
            if targets[i] and targets[i].hp < 30 then return false end
        end
        -- Need a healing target (someone not at 100%)
        if not state.lowest then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        return safe_heal_cast(A.HolyLightR1, icon, target.unit,
            format("[HOLY] HL R1 (Light's Grace proc) -> %s (%.0f%%)", target.unit, target.hp))
    end,
}
```

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
feat(holy): add Light's Grace proc strategy (HL R1 when safe)
```

---

### Task 5: Fix Holy Shock range + replace HL/FoL with HealTarget

**Files:**
- Modify: `rotation/source/aio/paladin/holy.lua`

**Step 1: Fix Holy Shock range check**

In `Holy_HolyShockHeal.matches` (around line 171), add range check after the lowest check:

```lua
    matches = function(context, state)
        if not state.lowest then return false end
        -- Range check: Holy Shock is 20yd, skip if target is out of range
        local in_range = _G.IsSpellInRange("Holy Shock", state.lowest.unit)
        if in_range ~= 1 then return false end
        local threshold = context.settings.holy_holy_shock_hp or 50
        if state.lowest.hp > threshold then return false end
        return true
    end,
```

**Step 2: Replace Holy_HolyLight and Holy_FlashOfLight with Holy_HealTarget**

Delete both strategy definitions (HolyLight ~lines 204-228 and FlashOfLight ~lines 230-249). Replace with:

```lua
-- [7] HealTarget (smart HL/FoL selection with downranking)
-- Replaces separate HolyLight and FlashOfLight strategies.
-- Uses select_heal() for spell type + rank based on deficit, incoming damage,
-- healing reduction, Divine Favor, and Light's Grace state.
local Holy_HealTarget = {
    spell_target = PLAYER_UNIT,

    matches = function(context, state)
        if not state.lowest then return false end
        -- Proactive FoL on tank: allow even at 100% HP
        if state.lowest.is_tank and context.in_combat then return true end
        -- Otherwise: only heal if not at max HP
        if state.lowest.hp >= 100 then return false end
        if context.is_moving then return false end
        return true
    end,

    execute = function(icon, context, state)
        local target = state.lowest
        local result = select_heal(context, state, target)
        if not result or not result.spell then return nil end
        return safe_heal_cast(result.spell, icon, target.unit,
            format("[HOLY] %s -> %s (%.0f%%, deficit: %d)", result.label, target.unit, target.hp, target.deficit or 0))
    end,
}
```

**Step 3: Update registration array**

Replace the registration block (around line 335) with:

```lua
rotation_registry:register("holy", {
    named("DivineIllumination",  Holy_DivineIllumination),
    named("DivineFavor",         Holy_DivineFavor),
    named("Racial",              Holy_Racial),
    named("HolyShockHeal",       Holy_HolyShockHeal),
    named("LayOnHands",          Holy_LayOnHands),
    named("LightsGraceProc",    Holy_LightsGraceProc),
    named("HealTarget",          Holy_HealTarget),
    named("JudgementMaintain",   Holy_JudgementMaintain),
    named("SealMaintain",        Holy_SealMaintain),
    named("Cleanse",             Holy_Cleanse),
}, {
    context_builder = get_holy_state,
})
```

**Step 4: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 5: Commit**

```
feat(holy): merge HL/FoL into HealTarget with smart selection, fix Holy Shock range
```

---

### Task 6: Update holy state to pass target data through

**Files:**
- Modify: `rotation/source/aio/paladin/holy.lua`

**Step 1: Pass full target entry (not just unit+hp) through holy_state**

The current `holy_lowest_entry` only has `unit` and `hp`. The `select_heal()` function needs `deficit`, `is_tank`, `has_healing_reduction`, `incoming_dps` from the scan entry.

Update `get_holy_state()` to copy the needed fields from the scan entry into `holy_lowest_entry`:

```lua
local holy_lowest_entry = { unit = nil, hp = 100, is_tank = false,
    deficit = 0, has_healing_reduction = false, incoming_dps = 0 }
```

And in the scan loop where `holy_state.lowest` is set (~line 80-83):

```lua
            if not holy_state.lowest then
                holy_lowest_entry.unit = entry.unit
                holy_lowest_entry.hp   = entry.effective_hp
                holy_lowest_entry.is_tank = entry.is_tank
                holy_lowest_entry.deficit = entry.deficit or 0
                holy_lowest_entry.has_healing_reduction = entry.has_healing_reduction or false
                holy_lowest_entry.incoming_dps = entry.incoming_dps or 0
                holy_state.lowest = holy_lowest_entry
            end
```

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
feat(holy): pass full target data through holy_state for select_heal
```

---

### Task 7: Schema cleanup

**Files:**
- Modify: `rotation/source/aio/paladin/schema.lua:151-164`

**Step 1: Replace Healing Thresholds section**

Replace lines 152-164 (the entire "Healing Thresholds" section) with:

```lua
    [4] = { name = "Holy", sections = {
        { header = "Healing", settings = {
            { type = "checkbox", key = "holy_use_holy_shock", default = true, label = "Holy Shock",
              tooltip = "Use Holy Shock as instant heal when target in range (20yd, 15s CD)." },
            { type = "slider", key = "proactive_fol_mana_floor", default = 30, min = 10, max = 60, label = "Proactive FoL Mana Floor (%)",
              tooltip = "Stop proactive FoL on tank when mana drops below this percent.", format = "%d%%" },
        }},
```

This removes `holy_holy_light_hp`, `holy_hl_nontank_hp`, `holy_flash_of_light_hp`, `holy_holy_shock_hp` and adds `proactive_fol_mana_floor`.

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
refactor(holy): simplify schema - remove threshold sliders, add mana floor
```

---

### Task 8: In-game verification

**Verification steps (no code changes):**

1. Build and sync: `cd rotation && node build.js --all`
2. `/reload` in-game
3. **Deficit math test:** Damage a party member to ~50% HP
   - Expected: HL fires (deficit > FoL max heal)
   - Log shows: `[HOLY] HL R8 -> party1 (50%, deficit: 2500)` (rank varies by gear)
4. **Downranking test:** Damage a party member to ~95% HP
   - Expected: FoL low rank fires (small deficit = low rank)
   - Log shows: `[HOLY] FoL R2 -> party1 (95%, deficit: 300)`
5. **Light's Grace proc test:** Let LG buff expire, nobody critical
   - Expected: `[HOLY] HL R1 (Light's Grace proc)` fires
   - Next HL should have reduced cast time
6. **Holy Shock range test:** Heal target at 35yd
   - Expected: Holy Shock skipped, HL/FoL fires instead (no GCD waste)
7. **Tank proactive test:** Tank at 100% HP in combat
   - Expected: FoL R1 keeps casting on tank
   - Below 30% mana: stops proactive casting
8. **Settings check:** Open `/menagerie` settings
   - Expected: Old threshold sliders gone, new "Proactive FoL Mana Floor" visible
