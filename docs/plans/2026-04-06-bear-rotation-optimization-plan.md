# Bear Rotation Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix bear rotation to stop Swiping on single target, improve Maul uptime via smarter starvation logic, and future-proof Lacerate integration for level 66+.

**Architecture:** Four surgical changes to bear.lua, one constant fix in class.lua, one new checkbox in schema.lua. No new files. No structural changes.

**Tech Stack:** Lua 5.1 (WoW addon), Node.js build system (`node build.js`)

**Testing:** `cd rotation && node build.js` to compile. In-game verification via `/menagerie` debug logs.

---

### Task 1: Add `swipe_st_filler` checkbox to bear schema

**Files:**
- Modify: `rotation/source/aio/druid/schema.lua:174` (after `swipe_cc_check` line)

**Step 1: Add the checkbox**

Insert after the `swipe_cc_check` line (line 174):

```lua
            { type = "checkbox", key = "swipe_st_filler", default = false, label = "Swipe ST Filler", tooltip = "Use Swipe as single-target filler between Mangle cooldowns. Off = auto-attack + Maul only (recommended for low AP). On = Swipe fills every GCD." },
```

**Step 2: Build to verify no syntax errors**

Run: `cd rotation && node build.js`
Expected: Successful build with no errors.

**Step 3: Commit**

```
feat(bear): add Swipe ST filler toggle (default off)
```

---

### Task 2: Fix `LACERATE_SWIPE_THRESHOLD` constant

**Files:**
- Modify: `rotation/source/aio/druid/class.lua:309`

**Step 1: Change the constant**

```lua
-- Old (line 309):
LACERATE_SWIPE_THRESHOLD = 3,
-- New:
LACERATE_SWIPE_THRESHOLD = 8,
```

This creates a real refresh window: LacerateBuild fires at 8-3s remaining, LacerateUrgent catches below 3s.

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
fix(bear): raise LACERATE_SWIPE_THRESHOLD from 3 to 8
```

---

### Task 3: Gate Swipe ST on toggle + Lacerate state

**Files:**
- Modify: `rotation/source/aio/druid/bear.lua:925-946` (Bear_Swipe matches + execute)

**Step 1: Update Bear_Swipe matches**

Replace the `Bear_Swipe.matches` function (lines 925-946) with:

```lua
      matches = function(context, state)
         -- AoE is handled by SwipeAoE above Mangle; this is single-target filler only
         local aoe_threshold = get_aoe_threshold(context, state)
         if context.enemy_count >= aoe_threshold then return false end

         -- ST filler toggle: user controls whether Swipe fills single-target GCDs
         if not context.settings.swipe_st_filler then return false end

         -- Lacerate gate: if Lacerate is available, only Swipe when fully stacked with safe duration
         if is_spell_available(A.Lacerate) then
            if state.lacerate_stacks < Constants.BEAR.LACERATE_MAX_STACKS then return false end
            if state.lacerate_duration <= 3 then return false end  -- let LacerateUrgent handle it
         end

         -- Hold for Mangle: don't waste a 1.5s GCD when Mangle is almost ready
         if should_hold_for_mangle() then return false end

         -- CC safety (cached in get_bear_state)
         if context.cc_nearby then return false end

         if not context.has_clearcasting then
            local swipe_threshold = context.settings.swipe_rage_threshold or Constants.BEAR.DEFAULT_SWIPE_RAGE
            if context.rage < swipe_threshold then return false end
            if would_starve_maul(context, RAGE_COST_SWIPE) then return false end
         end

         return true
      end,
```

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
feat(bear): gate Swipe ST on toggle + Lacerate state
```

---

### Task 4: Fix Maul starvation logic for delayed consumption

**Files:**
- Modify: `rotation/source/aio/druid/bear.lua:998-1005` (Bear_Maul matches)

**Step 1: Update Bear_Maul matches**

Replace the idle rage check section of `Bear_Maul.matches` (lines 998-1005) with:

```lua
      matches = function(context, state)
         -- Confirmed queued by game -> wait for CLEU to consume it
         if bear_state.maul_confirmed then return false end
         -- Still queuing (not yet confirmed) -> allow re-entry to keep firing TMW:Fire
         if bear_state.maul_queued then return true end
         -- Idle: normal rage threshold
         local maul_threshold = context.settings.maul_rage_threshold or Constants.BEAR.DEFAULT_MAUL_RAGE
         if context.rage < maul_threshold then return false end
         -- Mangle starvation: Maul consumes rage on next swing (delayed up to 2.5s).
         -- If we can't afford both and Mangle will be ready before our swing lands,
         -- don't queue — Mangle comes off CD with no rage to spend.
         if not context.has_clearcasting
            and context.rage < (RAGE_COST_MAUL + RAGE_COST_MANGLE)
            and is_spell_available(A.MangleBear)
         then
            local mangle_cd = A.MangleBear:GetCooldown()
            local swing_remaining = get_time_until_swing()
            -- Mangle ready before swing lands = Maul would starve it
            if mangle_cd > 0 and swing_remaining > 0 and mangle_cd < swing_remaining then
               return false
            end
            -- Mangle ready NOW and we can't afford both = don't queue
            if mangle_cd <= 0 then return false end
         end
         return true
      end,
```

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
fix(bear): prevent Maul from starving Mangle via swing-timing check
```

---

### Task 5: Reorder strategy registration

**Files:**
- Modify: `rotation/source/aio/druid/bear.lua:1022-1035` (registration block)

**Step 1: Reorder the array**

Replace lines 1022-1035 with:

```lua
   rotation_registry:register("bear", {
      named("FrenziedRegen",    Bear_FrenziedRegen),     -- [1]  off-GCD emergency heal
      named("Enrage",           Bear_Enrage),            -- [2]  off-GCD rage gen
      named("Growl",            Bear_Growl),             -- [3]  off-GCD taunt
      named("ChallengingRoar",  Bear_ChallengingRoar),   -- [4]  off-GCD AoE taunt
      named("LacerateUrgent",   Bear_LacerateUrgent),    -- [5]  GCD - urgent refresh
      named("TabTarget",        Bear_TabTarget),         -- [6]  off-GCD tab targeting
      named("FaerieFire",       Bear_FaerieFire),        -- [7]  GCD - debuff maintenance
      named("Maul",             Bear_Maul),              -- [8]  off-GCD swing queue (fires during GCD)
      named("SwipeAoE",         Bear_SwipeAoE),          -- [9]  GCD - AoE (fires before Mangle on packs)
      named("Mangle",           Bear_Mangle),            -- [10] GCD - main ST damage/threat
      named("LacerateBuild",    Bear_LacerateBuild),     -- [11] GCD - stack builder/filler
      named("Swipe",            Bear_Swipe),             -- [12] GCD - ST filler (conditional)
      named("DemoRoar",         Bear_DemoRoar),          -- [13] GCD - AP reduction (lowest priority)
   }, {
```

**Step 2: Build to verify**

Run: `cd rotation && node build.js`
Expected: Successful build.

**Step 3: Commit**

```
refactor(bear): reorder GCD priorities — Lacerate above Swipe, DemoRoar lowest
```

---

### Task 6: Update comments and log prefixes

**Files:**
- Modify: `rotation/source/aio/druid/bear.lua` (various strategy comments)

**Step 1: Update the Bear_Swipe comment block** (above the strategy, ~line 917)

```lua
   -- [12] Swipe single-target filler (conditional: toggle + Lacerate gate)
   -- Only fires when swipe_st_filler is enabled. At level 66+, also requires
   -- 5 Lacerate stacks with >3s remaining (sim's SwipeWithEnoughAP mode).
   -- Default OFF: auto-attack + Maul between Mangles is higher DPS at low AP.
```

**Step 2: Update Bear_LacerateBuild comment** (above the strategy, ~line 949)

```lua
   -- [11] Lacerate Build (primary GCD filler — building and maintaining stacks)
   -- Sim priority: Lacerate is the default filler, Swipe only when conditions met.
```

**Step 3: Update the DemoRoar comment priority number** (~line 816)

The `[P7]` log prefix in DemoRoar execute stays — it indicates internal priority context, not array position.

**Step 4: Build and commit**

Run: `cd rotation && node build.js`

```
docs(bear): update strategy comments to match new priority order
```

---

### Task 7: In-game verification

**Verification steps (no code changes):**

1. Build and sync: `cd rotation && node build.js --all`
2. `/reload` in-game
3. **Single target test:** Pull one mob in bear form
   - Expected: Mangle on CD, Maul queuing, NO Swipe (log should show only `[P9] Mangle` and `[P12] Maul`)
   - Verify via `/menagerie` debug log: zero `[P10] Swipe` lines on ST
4. **Multi-target test:** Pull 3+ mobs
   - Expected: SwipeAoE fires normally, Mangle weaves in
   - Verify: `[P9] Swipe (AoE)` lines appear with `Targets: N`
5. **Maul uptime test:** Watch rage on ST boss/elite
   - Expected: Maul queues more frequently, no long gaps where Mangle sits off-CD with no rage
6. **Toggle test:** Enable `Swipe ST Filler` in settings
   - Expected: Swipe returns as ST filler between Mangles
   - Disable again, verify it stops
