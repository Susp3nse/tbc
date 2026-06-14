# TBC Mage Implementation Research

Comprehensive research for implementing Fire, Frost, and Arcane Mage playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Fire Mage Rotation & Strategies](#2-fire-mage-rotation--strategies)
3. [Frost Mage Rotation & Strategies](#3-frost-mage-rotation--strategies)
4. [Arcane Mage Rotation & Strategies](#4-arcane-mage-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Mana Management System](#7-mana-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Proposed Settings Schema](#9-proposed-settings-schema)
10. [Strategy Breakdown Per Playstyle](#10-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Core Damage Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Fireball (R13) | 27070 | 3.5s | 425 | DoT: 84 dmg over 8s |
| Frostbolt (R13) | 27072 | 3.0s | 330 | 40% slow, 9s |
| Arcane Blast | 30451 | 2.5s | 195 | Stacks 3x: +75% cost, -0.33s cast each |
| Arcane Missiles (R11) | 38699 | 5s channel | 740 | 5 ticks, 1/sec |
| Scorch (R9) | 27074 | 1.5s | 180 | Improved Scorch debuff |
| Fire Blast (R9) | 27079 | Instant | 465 | 8s CD (reduced by talents) |
| Pyroblast (R10) | 33938 | 6.0s | 500 | DoT: 356 over 12s |
| Ice Lance | 30455 | Instant | 140 | 3x damage to frozen targets |

### AoE Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Flamestrike (R7) | 27086 | 3.0s | 1175 | Ground AoE + DoT |
| Blizzard (R7) | 27085 | 8s channel | 1645 | Channeled AoE, Improved Blizzard slows |
| Arcane Explosion (R8) | 27082 | Instant | 545 | PB AoE, low threat w/ Arcane Subtlety |
| Cone of Cold (R6) | 27087 | Instant | 645 | Frontal cone, slows |
| Blast Wave (R7) | 33933 | Instant | 620 | PB AoE + daze, 30s CD (Fire talent) |
| Dragon's Breath (R4) | 33043 | Instant | 700 | Cone, 3s disorient, 20s CD (Fire talent) |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Fireball | 133 | 27070 (R13) | |
| Frostbolt | 116 | 27072 (R13) | |
| Scorch | 2948 | 27074 (R9) | |
| Fire Blast | 2136 | 27079 (R9) | |
| Pyroblast | 11366 | 33938 (R10) | Talent-learned |
| Arcane Missiles | 5143 | 38699 (R11) | |
| Arcane Explosion | 1449 | 27082 (R8) | |
| Flamestrike | 2120 | 27086 (R7) | |
| Blizzard | 10 | 27085 (R7) | |
| Cone of Cold | 120 | 27087 (R6) | |
| Frost Nova | 122 | 27088 (R5) | |
| Ice Barrier | 11426 | 33405 (R6) | Frost talent |
| Mana Shield | 1463 | 27131 (R7) | |
| Arcane Intellect | 1459 | 27126 (R6) | |
| Arcane Brilliance | 23028 | 27127 (R2) | |
| Mage Armor | 6117 | 27125 (R4) | |
| Ice Armor | 7302 | 27124 (R5) | |
| Polymorph | 118 | 12826 (R4) | |
| Dampen Magic | 604 | 33944 (R6) | |
| Amplify Magic | 1008 | 33946 (R6) | |
| Blast Wave | 11113 | 33933 (R7) | Fire talent |
| Dragon's Breath | 31661 | 33043 (R4) | Fire talent |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Arcane Blast | 30451 | TBC ability |
| Ice Lance | 30455 | TBC ability |
| Molten Armor | 30482 | TBC ability (1 rank) |
| Evocation | 12051 | |
| Counterspell | 2139 | |
| Spellsteal | 30449 | TBC ability |
| Remove Curse | 475 | |
| Blink | 1953 | |
| Invisibility | 66 | TBC ability, 5s fade then invis |
| Ice Block | 45438 | Baseline in TBC |
| Combustion | 11129 | Fire talent |
| Arcane Power | 12042 | Arcane talent |
| Icy Veins | 12472 | Frost talent |
| Presence of Mind | 12043 | Arcane talent |
| Cold Snap | 11958 | Frost talent |
| Summon Water Elemental | 31687 | Frost talent (41pt) |
| Slow | 31589 | Arcane talent, utility slow (not rotation-critical) |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Combustion | 11129 | 3 min | Until 3 crits | +10% fire crit per stack |
| Icy Veins | 12472 | 3 min | 20s | +20% haste, pushback immune |
| Arcane Power | 12042 | 3 min | 15s | +30% dmg, +30% mana cost |
| Presence of Mind | 12043 | 3 min | Next spell | Instant cast next spell |
| Cold Snap | 11958 | ~8 min | Instant | Resets all Frost CDs |
| Summon Water Elemental | 31687 | 3 min | 45s | Frost talent, pet DPS |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Ice Block | 45438 | 5 min | 10s immunity, clears debuffs, 30s Hypothermia |
| Ice Barrier | 33405 | 30s | Absorb shield (Frost talent) |
| Mana Shield (R7) | 27131 | — | Absorb dmg using mana |
| Blink | 1953 | 15s | 20yd instant teleport |
| Frost Nova (R5) | 27088 | 25s | Root enemies in place |
| Counterspell | 2139 | 24s | Interrupt + 8s lockout |
| Spellsteal | 30449 | — | Steal enemy buff |
| Remove Curse | 475 | — | Remove curses from friendly |
| Invisibility | 66 | 5 min | 5s fade + invis |
| Evocation | 12051 | 8 min | 60% mana over 8s channel |

### Self-Buffs / Armor
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Molten Armor | 30482 | 30 min | +3% spell crit, 75 fire retaliation |
| Mage Armor (R3) | 22783 | 30 min | +15 all resist, 30% mana regen while casting |
| Ice Armor (R5) | 27124 | 30 min | +armor, +frost resist, melee slow |
| Arcane Intellect (R6) | 27126 | 30 min | +40 intellect (single target) |
| Arcane Brilliance (R2) | 27127 | 1 hr | +40 intellect (group) |

### Conjured Mana Gems
| Gem | Conjure Spell ID | Item ID | Mana Restored | Level |
|-----|------------------|---------|---------------|-------|
| Mana Emerald | 27101 | 22044 | 2340-2460 | 68 |
| Mana Ruby | 10054 | 8008 | 1000-1200 | 58 |
| Mana Citrine | 10053 | 8007 | 775-925 | 48 |
All gems share a 2 min CD. Separate from potion CD. Carry one of each type.

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Blood Elf | Arcane Torrent | 28730 | Silence 2s + mana restore, 2 min CD |
| Troll | Berserking | 26297 | 10-30% haste 10s, 3 min CD |
| Gnome | Escape Artist | 20589 | Removes root/snare |
| Undead | Will of the Forsaken | 7744 | Removes charm/fear/sleep |
| Draenei | Gift of the Naaru | 28880 | HoT heal |

### Debuff IDs (for tracking)
| Debuff | ID | Notes |
|--------|------|-------|
| Improved Scorch (Fire Vulnerability) | 22959 | +3% fire dmg taken, stacks to 5 (30s duration) |
| Winter's Chill | 12579 | +2% frost crit per stack, stacks to 5 (+10% total) |
| Arcane Blast debuff (self) | 36032 | 8s duration, stacks to 3 |
| Ignite | 12654 | Rolling fire DoT from crits (40% of crit dmg over 4s) |

### Buff IDs (for tracking)
| Buff | ID | Notes |
|------|------|-------|
| Clearcasting (Arcane Concentration) | 12536 | Next spell costs no mana |
| Combustion buff | 11129 | +10% fire crit per stack, consumed on 3 crits |
| Arcane Power buff | 12042 | +30% dmg active |
| Icy Veins buff | 12472 | +20% haste active |
| Presence of Mind buff | 12043 | Next spell instant |
| Ice Barrier buff | 33405 | Absorb shield active |
| Hypothermia debuff | 41425 | 30s after Ice Block, prevents re-block |
| Molten Armor buff | 30482 | Armor active check |
| Mage Armor buff | 22783 | Armor active check (R3; R4 max = 27125) |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD) |
| Demonic Rune | 12662 | Same as Dark Rune |
| Flame Cap | 22788 | +80 fire spell power for 1 min (Fire-specific consumable) |
| Destruction Potion | 22839 | +120 SP, +2% spell crit for 15s |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+):
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Fingers of Frost | Wrath (3.0) | No proc-based Shatter on non-frozen targets |
| Brain Freeze | Wrath (3.0) | No free Fireball proc from Frostbolt |
| Deep Freeze | Wrath (3.0) | Stun ability doesn't exist |
| Frostfire Bolt | Wrath (3.0) | Spell doesn't exist |
| Living Bomb | Wrath (3.0) | Fire talent doesn't exist |
| Mirror Image | Wrath (3.0) | Spell doesn't exist |

**What IS new in TBC (vs Classic):**
- Ice Lance (level 66 trained) — but nearly useless in PVE single-target without Fingers of Frost
- Spellsteal (level 70 trained)
- Molten Armor
- Arcane Blast
- Water Elemental (41-point Frost talent)
- Icy Veins (Frost talent)

---

## 2. Fire Mage Rotation & Strategies

### Core Mechanic: Improved Scorch Maintenance
- Scorch applies "Fire Vulnerability" (ID: 22959) debuff on target
- Each Scorch has a chance to add 1 stack (100% at 3/3 Improved Scorch talent)
- Stacks to 5, each stack = +3% fire damage taken (15% total)
- Duration: 30 seconds per application
- **Priority**: Refresh when < 5.5s remaining OR stacks < 5

### Single Target Rotation
From wowsims `doFireRotation()`:
1. **Maintain Improved Scorch** (if talented) — always top priority
2. **Fire Blast** (instant, weave between casts if enabled) — when off CD
3. **Fireball** (primary spell) OR **Scorch** (if configured as primary)

### Rotation Detail
```
Opener:
1. Pre-cast Fireball
2. Scorch x5 to build Improved Scorch stacks
3. Fireball spam (refresh Scorch when < 5.5s left on debuff)
4. Fire Blast on CD (weave between Fireballs, optional setting)

Execute Phase (<20% HP):
- Same rotation but +20% damage from Molten Fury talent
- Prioritize Combustion here if available
```

### Fire Strategies (priority order)
1. **Maintain Improved Scorch** — if stacks < 5 or duration < 5.5s
2. **Combustion** — use on CD, ideally at <20% boss HP (off-GCD)
3. **Icy Veins** — haste CD, use on CD (off-GCD)
4. **Trinkets** — use with Combustion window (off-GCD)
5. **Fire Blast Weave** — instant, use between casts when off CD
6. **Fireball** — primary filler (default primary spell)
7. **Scorch** — alternative primary (user setting: "Scorch Weave" build)

### State Tracking Needed
- `scorch_stacks` — debuff stacks on target (0-5)
- `scorch_duration` — remaining debuff duration
- `combustion_active` — Combustion buff active
- `molten_fury_active` — target below 20% HP (talent check)

---

## 3. Frost Mage Rotation & Strategies

### Core Mechanic: Frostbolt Spam
Frost is the simplest spec — Frostbolt is the overwhelming majority of casts.

### Single Target Rotation
From wowsims `doFrostRotation()`:
1. **Frostbolt** — that's it for single target

### Expanded Rotation (from guides)
1. **Icy Veins** — use on CD, stack with trinkets and Bloodlust (off-GCD)
2. **Cold Snap** — reset Icy Veins + Water Elemental CDs
3. **Summon Water Elemental** — use on CD (pet auto-attacks with Waterbolt)
4. **Frostbolt** — primary cast, always (90%+ of casts)
5. **Cone of Cold** — during movement or when tank has large threat lead
6. **Fire Blast** — during movement fallback
7. **Ice Lance** — movement filler only; nearly useless in PVE single-target
   (no Fingers of Frost in TBC, bosses immune to freeze, base damage only)

### Ice Lance in TBC (Important)
- Ice Lance does 3x damage against FROZEN targets
- Without Fingers of Frost (Wrath-only), targets must be actually frozen
- Bosses are immune to freeze effects → Ice Lance is almost never used in raids
- Only real use: movement filler (instant cast) — still a DPS loss vs Frostbolt
- Shatter combos (Frost Nova → Frostbolt + Ice Lance) only work on trash/adds

### Winter's Chill Debuff
- Frost talent: Frostbolt crits apply Winter's Chill (ID: 12579)
- +2% frost crit chance per stack, stacks to 5 (+10% total)
- Applied passively by Frostbolt crits, no active maintenance needed
- With 5/5 talent, 100% proc rate on crit → stacks naturally in first few casts

### State Tracking Needed
- `water_elemental_active` — pet summoned
- `icy_veins_active` — buff check
- `target_frozen` — for Ice Lance decision

---

## 4. Arcane Mage Rotation & Strategies

### Core Mechanic: Arcane Blast Stack Management + Mana Cycling
Arcane Blast has a unique stacking debuff on the caster:
- Each cast adds 1 stack (max 3)
- Each stack: +75% base mana cost, -0.33s cast time
- Debuff lasts 8 seconds, resets to 0 stacks on expiry
- **At 3 stacks**: cast time ~1.17s but mana cost ~682 (unsustainable)

### Two-Phase Rotation
From wowsims `doArcaneRotation()`:

#### Burn Phase (CDs active, high mana)
- **Spam Arcane Blast** regardless of stacks
- All CDs active: Arcane Power + Icy Veins + trinkets + Destruction Potion
- Use Mana Emerald during burn
- Continue until mana drops below threshold

#### Conserve/Regen Phase (CDs down, low mana)
- Let AB stacks drop (wait for 8s debuff to expire)
- Cast configured filler while waiting:
  - **Frostbolt** (most common filler)
  - **Arcane Missiles** (alternative)
  - **Scorch** (alternative)
  - **Mixed**: AM+Frostbolt alternating, or Scorch+2xFireball pattern
- Once stacks drop, cast N x Arcane Blast then let stacks drop again
- Configurable: `arcane_blasts_between_fillers` (default: 3)

#### Phase Transitions (from wowsims)
- **Enter regen**: when mana% drops below `start_regen_rotation_percent`
  - During Bloodlust: threshold drops to min(10%, normal_threshold)
- **Exit regen**: when mana% rises above `stop_regen_rotation_percent` AND stacks will drop
- **Option**: Disable DPS cooldowns during regen phase

### Rotation Patterns (from guides)
- **3x AB → 3x Frostbolt** (standard conserve pattern)
- **3x AB → 4x Frostbolt** (with more haste gear)
- Frostbolts give time for AB debuff to expire before next AB cycle

### Cooldown Stacking
From Icy Veins guide:
1. Fight start: Icy Veins
2. After 20s: Cold Snap → Icy Veins + Arcane Power + trinkets + Destruction Potion + Mana Emerald
3. Spam AB until OOM
4. Enter conserve phase until CDs come back

### PoM (Presence of Mind) Usage
- Arcane spec: Use for instant Arcane Blast (extends debuff without cast time)
- NOT used for PoM+Pyroblast in Arcane (that's a Fire/hybrid thing)

### State Tracking Needed
- `ab_stacks` — current Arcane Blast debuff stacks (0-3)
- `ab_duration` — remaining debuff duration (for "will drop" prediction)
- `is_burning` — currently in burn phase
- `is_conserving` — currently in conserve phase
- `num_casts_done` — casts in current cycle (for AB-between-fillers count)
- `clearcasting` — Arcane Concentration proc active
- `arcane_power_active` — AP buff active

---

## 5. AoE Rotation (All Specs)

From wowsims `doAoeRotation()`, three options:
1. **Arcane Explosion** — instant, PB AoE, mana-efficient for melee range
2. **Flamestrike** — 3s cast, ground-targeted, DoT component
3. **Blizzard** — 8s channel, with Improved Blizzard talent adds slow

### Spec-Specific AoE Additions
- **Fire**: Blast Wave (instant PB AoE + daze, 30s CD) + Dragon's Breath (cone + 3s disorient, 20s CD)
- **Frost**: Frost Nova → Blizzard (kite pattern); Cone of Cold for burst AoE
- **Arcane**: Arcane Explosion spam (lowest threat with Arcane Subtlety)

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Ice Block** — full immunity 10s, clears debuffs (5 min CD)
   - Use when: HP critically low, about to die
   - Note: Applies 30s Hypothermia debuff (can't re-block)
2. **Mana Shield** — absorb damage using mana (emergency only)
3. **Ice Barrier** — absorb shield (Frost talent, 30s CD)
4. **Blink** — 20yd teleport (escape, not in rotation but awareness)

### Dispel/Utility
1. **Remove Curse** — remove curses from friendly targets
2. **Counterspell** — interrupt enemy casts (24s CD)
3. **Spellsteal** — steal enemy buff (mana-expensive, situational)

### Self-Buffs (OOC)
1. **Armor**: Molten Armor (Fire/Arcane: +3% spell crit) vs Mage Armor (mana regen) vs Ice Armor (Frost: armor+resist)
2. **Arcane Intellect** / **Arcane Brilliance** — intellect buff
3. **Which armor per spec**:
   - Fire → Molten Armor (crit)
   - Arcane → Molten Armor (crit) during burn, Mage Armor during conserve (some swap)
   - Frost → Molten Armor (crit) generally preferred in PVE

---

## 7. Mana Management System

### Mana Recovery Priority
1. **Mana Gem** (Conjure Mana Emerald) — 2340-2460 mana, 3 charges, 2 min CD
   - Use during burn phase, use early and often
2. **Super Mana Potion** — use on CD (2 min shared potion CD)
3. **Dark Rune / Demonic Rune** — mana at HP cost (separate CD from potion)
4. **Evocation** — 60% total mana over 8s channel (8 min CD)
   - Use during conserve phase or between trash packs

### Arcane-Specific Mana Management
- Burn phase: use gems + potions + runes during AP window
- Conserve phase: filler rotation to allow natural regen
- Evocation: plan around 8-min CD, use during conserve
- Key thresholds:
  - Start conserve: configurable (default ~35% mana)
  - Stop conserve: configurable (default ~60% mana)
  - During Bloodlust: lower conserve threshold (burn harder)

---

## 8. Cooldown Management

### Fire Cooldown Priority
1. Combustion — save for <20% boss HP if possible, else use on CD
2. Icy Veins — use on CD
3. Trinkets — pair with Combustion

### Frost Cooldown Priority
1. Icy Veins — use on CD
2. Water Elemental — use on CD
3. Cold Snap — use after Icy Veins + Water Ele expire to double them
4. Trinkets — pair with Icy Veins

### Arcane Cooldown Priority
1. Icy Veins first (for Cold Snap reset)
2. After 20s: Cold Snap → Icy Veins + Arcane Power + trinkets
3. Alternative: Stack everything at once via macro

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `use_arcane_intellect` | checkbox | true | Arcane Intellect | Auto-buff Arcane Intellect OOC |
| `armor_type` | dropdown | "auto" | Armor Selection | Which armor to maintain ("auto", "molten", "mage", "ice") |
| `auto_remove_curse` | checkbox | true | Auto Remove Curse | Automatically Remove Curse on party members |
| `use_counterspell` | checkbox | true | Auto Counterspell | Interrupt enemy casts when available |
| `aoe_mode` | dropdown | "off" | AoE Mode | AoE rotation mode ("off", "arcane_explosion", "flamestrike", "blizzard") |
| `aoe_threshold` | slider | 3 | AoE Enemy Threshold | Minimum enemies to trigger AoE (2-8) |

### Tab 2: Fire
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `fire_maintain_scorch` | checkbox | true | Maintain Imp. Scorch | Keep 5 stacks of Improved Scorch on target |
| `fire_scorch_refresh` | slider | 6 | Scorch Refresh (sec) | Refresh Scorch debuff at this duration remaining (3-10) |
| `fire_primary_spell` | dropdown | "fireball" | Primary Spell | Main filler spell ("fireball", "scorch") |
| `fire_weave_fire_blast` | checkbox | true | Weave Fire Blast | Use Fire Blast between casts when off CD |
| `fire_use_combustion` | checkbox | true | Use Combustion | Use Combustion cooldown |
| `fire_combustion_below_hp` | slider | 25 | Combustion Target HP% | Save Combustion for target below this HP% (0=use on CD) |
| `fire_use_blast_wave` | checkbox | true | Use Blast Wave | Use Blast Wave on CD (if talented) |
| `fire_use_dragons_breath` | checkbox | false | Use Dragon's Breath | Use Dragon's Breath (if talented, may break CC) |

### Tab 3: Frost
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `frost_use_icy_veins` | checkbox | true | Use Icy Veins | Use Icy Veins on cooldown |
| `frost_use_cold_snap` | checkbox | true | Use Cold Snap | Use Cold Snap to reset Frost CDs |
| `frost_use_water_elemental` | checkbox | true | Summon Water Elemental | Summon Water Elemental on cooldown (if talented) |
| `frost_use_ice_lance` | checkbox | true | Use Ice Lance | Use Ice Lance on frozen targets |
| `frost_use_cone_of_cold` | checkbox | false | Use Cone of Cold | Use Cone of Cold during movement |
| `frost_movement_spell` | dropdown | "fire_blast" | Movement Spell | Spell to use while moving ("fire_blast", "ice_lance", "cone_of_cold") |

### Tab 4: Arcane
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `arcane_use_arcane_power` | checkbox | true | Use Arcane Power | Use Arcane Power cooldown |
| `arcane_use_pom` | checkbox | true | Use Presence of Mind | Use Presence of Mind |
| `arcane_use_icy_veins` | checkbox | true | Use Icy Veins | Use Icy Veins (cross-tree talent) |
| `arcane_use_cold_snap` | checkbox | true | Use Cold Snap | Use Cold Snap for double Icy Veins |
| `arcane_filler` | dropdown | "frostbolt" | Filler Spell | Conserve phase filler ("frostbolt", "arcane_missiles", "scorch", "fireball") |
| `arcane_blasts_between_fillers` | slider | 3 | AB Stacks Before Filler | Number of Arcane Blasts before switching to filler (1-4) |
| `arcane_start_conserve_pct` | slider | 35 | Start Conserve Mana% | Enter conserve phase at this mana% (10-80) |
| `arcane_stop_conserve_pct` | slider | 60 | Stop Conserve Mana% | Exit conserve phase at this mana% (20-90) |
| `arcane_disable_cds_conserve` | checkbox | false | Disable CDs in Conserve | Hold DPS cooldowns during conserve phase |

### Tab 5: Cooldowns & Mana
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Berserking/Arcane Torrent/etc.) |
| `use_mana_gem` | checkbox | true | Use Mana Gem | Auto-use Mana Gem for mana recovery |
| `mana_gem_pct` | slider | 70 | Mana Gem Below% | Use Mana Gem when mana below this% (20-90) |
| `use_mana_potion` | checkbox | true | Use Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_pct` | slider | 50 | Mana Potion Below% | Use Mana Potion when mana below this% (10-80) |
| `use_dark_rune` | checkbox | true | Use Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_pct` | slider | 50 | Dark Rune Below% | Use Dark Rune when mana below this% (10-80) |
| `use_evocation` | checkbox | true | Use Evocation | Auto-use Evocation when low on mana |
| `evocation_pct` | slider | 20 | Evocation Below% | Use Evocation when mana below this% (5-40) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use health potion below this HP% |
| `ice_block_hp` | slider | 15 | Ice Block HP% | Use Ice Block below this HP% (0=disable) |
| `mana_shield_hp` | slider | 0 | Mana Shield HP% | Use Mana Shield below this HP% (0=disable) |

---

## 10. Strategy Breakdown Per Playstyle

### Fire Playstyle Strategies (priority order)
```
[1]  MaintainImprovedScorch  — if scorch_stacks < 5 or scorch_duration < refresh_threshold
[2]  Combustion              — off-GCD, use based on target HP% setting
[3]  IcyVeins                — off-GCD, use on CD
[4]  Trinkets                — off-GCD, pair with Combustion window
[5]  BlastWave               — instant AoE, use on CD (if talented + enabled)
[6]  DragonsBreath           — instant cone, use on CD (if talented + enabled)
[7]  FireBlastWeave          — instant, use between casts when off CD
[8]  Fireball                — primary filler (or Scorch if configured)
```

### Frost Playstyle Strategies (priority order)
```
[1]  IcyVeins                — off-GCD, use on CD
[2]  SummonWaterElemental    — use on CD (if talented)
[3]  ColdSnap                — use after Icy Veins + WE expire to double them
[4]  Trinkets                — off-GCD, pair with Icy Veins
[5]  MovementSpell           — during movement: Fire Blast / Ice Lance / CoC (setting)
[6]  Frostbolt               — primary filler (90%+ of all casts)
```
Note: Ice Lance nearly useless vs unfrozen targets in TBC (no Fingers of Frost).
Frost is the simplest PVE rotation — essentially Frostbolt spam + cooldowns.

### Arcane Playstyle Strategies (priority order)
```
[1]  IcyVeins                — off-GCD, use at pull (for Cold Snap reset)
[2]  ColdSnap                — reset Icy Veins CD after it expires
[3]  ArcanePower             — off-GCD, stack with 2nd Icy Veins
[4]  PresenceOfMind          — off-GCD, instant next AB
[5]  Trinkets                — off-GCD, stack with AP window
[6]  ArcaneBlastBurn         — during burn phase, spam AB
[7]  ArcaneBlastConserve     — during conserve, cast N ABs then switch
[8]  FillerSpell             — frostbolt/AM/scorch based on setting
```

### Shared Middleware (all specs)
```
[MW-500]  IceBlock            — emergency self-save at critical HP
[MW-400]  ManaShield          — emergency absorb (if enabled)
[MW-300]  RecoveryItems       — healthstone, health potion
[MW-280]  ManaRecovery        — mana gem, mana potion, dark rune
[MW-250]  Evocation           — channel for mana when critically low + safe
[MW-200]  RemoveCurse         — dispel curse on party member
[MW-150]  Counterspell        — interrupt enemy cast
[MW-100]  SelfBuffArmor       — maintain armor (Molten/Mage/Ice)
[MW-90]   SelfBuffIntellect   — maintain Arcane Intellect OOC
```

### AoE Strategies (toggled by aoe_mode setting)
```
When aoe_mode != "off" and enemy_count >= aoe_threshold:
- "arcane_explosion" → spam Arcane Explosion
- "flamestrike" → cast Flamestrike
- "blizzard" → channel Blizzard
Fire spec additions: Blast Wave + Dragon's Breath before AoE filler
Frost spec additions: Frost Nova before Blizzard (kite setup)
```

---

## Key Implementation Notes

### Playstyle Detection
Mage has NO stances/forms (unlike Druid). Playstyle must be determined by:
- **User setting** (dropdown: "fire", "frost", "arcane")
- Could auto-detect via talent check, but user setting is simpler and more reliable

### No Idle Playstyle
Unlike Druid's "caster" idle form, Mage doesn't shift forms. OOC behavior (buffs, food) handled via middleware with `requires_combat = false`.

### extend_context Fields
```lua
ctx.is_moving = Player:IsMoving()
ctx.has_clearcasting = (Unit("player"):HasBuffs(12536) or 0) > 0
ctx.ab_stacks = Unit("player"):HasBuffsStacks(36032, nil, true) or 0
ctx.ab_duration = Unit("player"):HasBuffs(36032, nil, true) or 0
ctx.is_casting = Player:IsCasting()  -- for Evocation safety
ctx.combustion_active = (Unit("player"):HasBuffs(11129) or 0) > 0
ctx.arcane_power_active = (Unit("player"):HasBuffs(12042) or 0) > 0
ctx.icy_veins_active = (Unit("player"):HasBuffs(12472) or 0) > 0
ctx.pom_active = (Unit("player"):HasBuffs(12043) or 0) > 0
ctx.ice_barrier_active = (Unit("player"):HasBuffs(33405) or 0) > 0
ctx.hypothermia = (Unit("player"):HasDeBuffs(41425) or 0) > 0
```

### Fire State (context_builder)
```lua
fire_state.scorch_stacks = Unit(TARGET):HasDeBuffsStacks(22959) or 0
fire_state.scorch_duration = Unit(TARGET):HasDeBuffs(22959) or 0
fire_state.target_below_20 = context.target_hp < 20  -- Molten Fury
```

### Arcane State (context_builder)
```lua
arcane_state.is_burning = <tracked via phase flag>
arcane_state.is_conserving = <tracked via phase flag>
arcane_state.num_casts_done = <tracked per cycle>
arcane_state.trying_to_drop_stacks = <from wowsims pattern>
arcane_state.ab_will_drop = ab_duration > 0 and ab_duration < ab_cast_time
```

### Frost State (context_builder)
```lua
frost_state.target_frozen = (Unit(TARGET):HasDeBuffs("Frost Nova") or 0) > 0
                         or (Unit(TARGET):HasDeBuffs("Freeze") or 0) > 0
frost_state.water_ele_active = <pet exists check>
```
