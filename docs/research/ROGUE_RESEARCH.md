# TBC Rogue Implementation Research

Comprehensive research for implementing Combat, Assassination, and Subtlety Rogue playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Combat Rogue Rotation & Strategies](#2-combat-rogue-rotation--strategies)
3. [Assassination Rogue Rotation & Strategies](#3-assassination-rogue-rotation--strategies)
4. [Subtlety Rogue Rotation & Strategies](#4-subtlety-rogue-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Energy Management System](#7-energy-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Proposed Settings Schema](#9-proposed-settings-schema)
10. [Strategy Breakdown Per Playstyle](#10-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Core Damage Spells (Builders)
| Spell | ID | Energy | Notes |
|-------|------|--------|-------|
| Sinister Strike (R10) | 26862 | 45 | +98 dmg, 1 CP. 40 energy w/ Imp SS |
| Backstab (R10) | 26863 | 60 | 150% wep + 255, 1 CP. Requires dagger MH, behind target |
| Mutilate | 34413 | 60 | 2 CP, Assassination 41pt. Requires dagger MH+OH, +50% vs poisoned |
| Hemorrhage (R4) | 26864 | 35 | 110% wep, 1 CP. Debuff: +42 phys dmg (10 charges, 15s) |
| Ghostly Strike | 14278 | 40 | 125% wep, 1 CP, +15% dodge 7s. 20s CD |
| Shiv | 5938 | 20+ | 1 CP, applies OH poison. Energy = 20 + OH speed x 10 |

### Finishers
| Spell | ID | Energy | Notes |
|-------|------|--------|-------|
| Slice and Dice (R2) | 6774 | 25 | +30% attack speed. 6s + 3s/CP (max 21s at 5CP) |
| Eviscerate (R10) | 26865 | 35 | Direct damage, scales with CP |
| Rupture (R7) | 26867 | 25 | DoT, 8s + 2s/CP (max 16s at 5CP), scales with AP |
| Envenom (R2) | 32684 | 35 | Consumes Deadly Poison stacks, 180 dmg/dose. TBC ability |
| Expose Armor (R6) | 26866 | 25 | -2050 armor at 5CP, 30s. Does not stack with Sunder |
| Kidney Shot (R2) | 8643 | 25 | Stun: 2s + 1s/CP (max 6s at 5CP) |

### Stealth Openers
| Spell | ID | Energy | Notes |
|-------|------|--------|-------|
| Cheap Shot | 1833 | 60 | 2 CP, 4s stun |
| Ambush (R7) | 27441 | 60 | 275% wep + 335, 1 CP. Requires dagger MH, behind target |
| Garrote (R8) | 26884 | 50 | 1 CP, 732 DoT over 18s, behind target |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Sinister Strike | 1752 | 26862 (R10) | |
| Backstab | 53 | 26863 (R10) | |
| Eviscerate | 2098 | 26865 (R10) | |
| Slice and Dice | 5171 | 6774 (R2) | |
| Rupture | 1943 | 26867 (R7) | |
| Expose Armor | 8647 | 26866 (R6) | |
| Hemorrhage | 16511 | 26864 (R4) | Subtlety talent |
| Ambush | 8676 | 27441 (R7) | |
| Garrote | 703 | 26884 (R8) | |
| Evasion | 5277 | 26669 (R2) | |
| Sprint | 2983 | 11305 (R3) | |
| Kick | 1766 | 38768 (R5) | |
| Gouge | 1776 | 38764 (R6) | |
| Kidney Shot | 408 | 8643 (R2) | |
| Feint | 1966 | 27448 (R6) | |
| Vanish | 1856 | 26889 (R3) | |
| Stealth | 1784 | 1787 (R4) | |
| Sap | 6770 | 11297 (R3) | |
| Envenom | 32645 | 32684 (R2) | TBC ability |
| Instant Poison | 8679 | 26891 (VII) | Application spell |
| Deadly Poison | 2823 | 27186 (VII) | Application spell |
| Wound Poison | 13218 | 27189 (V) | Application spell |
| Crippling Poison | 3408 | 11201 (II) | Application spell |
| Mind-numbing Poison | 5761 | 11398 (III) | Application spell |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Mutilate | 34413 | Assassination 41pt talent. MH hit: 34419, OH hit: 34418 |
| Shiv | 5938 | TBC ability (learned at 70) |
| Ghostly Strike | 14278 | Subtlety talent |
| Cheap Shot | 1833 | |
| Blade Flurry | 13877 | Combat talent |
| Adrenaline Rush | 13750 | Combat talent |
| Cold Blood | 14177 | Assassination talent |
| Preparation | 14185 | Subtlety talent |
| Shadowstep | 36554 | Subtlety 41pt talent |
| Premeditation | 14183 | Subtlety talent |
| Cloak of Shadows | 31224 | TBC ability, baseline |
| Blind | 2094 | |
| Distract | 1725 | |
| Anesthetic Poison | 26785 | TBC only, single rank |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Blade Flurry | 13877 | 2 min | 15s | +20% attack speed, cleave 1 extra target |
| Adrenaline Rush | 13750 | 5 min | 15s | +100% energy regen (40/2s) |
| Cold Blood | 14177 | 3 min | Next ability | +100% crit on next offensive ability |
| Preparation | 14185 | 10 min | Instant | Resets: Evasion, Sprint, Vanish, Cold Blood, Shadowstep, Premeditation |
| Shadowstep | 36554 | 30s | 10s buff | Teleport behind target, +20% dmg next ability, -50% threat |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Evasion (R2) | 26669 | 5 min | +50% dodge, -25% ranged hit for 15s |
| Sprint (R3) | 11305 | 5 min | +70% speed for 15s |
| Cloak of Shadows | 31224 | 1 min | Remove spells, +90% spell resist 5s |
| Kick (R5) | 38768 | 10s | Interrupt + 5s school lockout, 25 energy |
| Gouge (R6) | 38764 | 10s | 4s incapacitate, 45 energy, 1 CP |
| Blind | 2094 | 3 min | 10s disorient, reagent: Blinding Powder |
| Feint (R6) | 27448 | 10s | Threat reduction, 20 energy |
| Vanish (R3) | 26889 | 5 min | Stealth + break movement impairs |
| Kidney Shot (R2) | 8643 | 20s | Stun finisher, 25 energy |

### Poisons (Weapon enchants, 1 hour duration)
Poisons have two IDs: application (cast on weapon) and proc/debuff (on target).

| Poison | Apply ID | Proc/Debuff ID | Notes |
|--------|----------|----------------|-------|
| Instant Poison VII | 26891 | 26890 | 20% proc, 146-194 Nature dmg |
| Deadly Poison VII | 27186 | 27187 | 30% proc, DoT stacks to 5, 204 total over 12s |
| Wound Poison V | 27189 | 27189 | 30% proc, -10% healing, stacks 5x, 15s |
| Crippling Poison II | 11201 | 11201 | 30% proc, -50% move speed, 12s |
| Mind-numbing Poison III | 11398 | 11398 | 20% proc, +40% cast time, 10s |
| Anesthetic Poison | 26785 | 26785 | 20% proc, Nature dmg, no threat. TBC only |

Note: Rotation addon typically does NOT auto-apply poisons — they are applied manually OOC.
Common setups:
- **Combat**: Instant Poison MH / Deadly Poison OH (or Instant/Instant)
- **Assassination**: Instant Poison MH / Deadly Poison OH (Mutilate + Envenom synergy)
- **Subtlety**: Instant Poison MH / Crippling Poison OH (PVP) or Instant/Deadly (PVE)

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Orc | Blood Fury (melee AP) | 20572 | +AP (level x 4 + 2, ~282 at 70), -50% healing, 2 min CD |
| Troll | Berserking | 26297 | 10-30% attack speed 10s, 3 min CD, costs 10 energy |
| Undead | Will of the Forsaken | 7744 | Removes charm/fear/sleep, 2 min CD |
| Blood Elf | Arcane Torrent (energy) | 25046 | Silence 2s + 10 energy per Mana Tap, 2 min CD |
| Human | Perception | 20600 | +50 stealth detection 20s, 3 min CD |
| Gnome | Escape Artist | 20589 | Removes root/snare, 1m 45s CD |
| Night Elf | Shadowmeld | 20580 | Stealth (out of combat), 10s CD |
| Dwarf | Stoneform | 20594 | Immune Bleed/Poison/Disease + 10% armor 8s, 3 min CD |

### Debuff IDs (for tracking on target)
| Debuff | ID | Notes |
|--------|------|-------|
| Rupture (R7) | 26867 | DoT, same as cast spell ID |
| Expose Armor (R6) | 26866 | Armor reduction, same as cast spell ID |
| Garrote (R8) | 26884 | DoT, same as cast spell ID |
| Hemorrhage debuff | 26864 | +42 phys dmg taken, 10 charges, 15s |
| Deadly Poison VII | 27187 | Proc ID (NOT application ID), stacks 1-5 |
| Wound Poison V | 27189 | -10% healing, stacks 1-5 |
| Find Weakness | 31234 | +10% armor pen, 10s after stealth opener (Assassination talent) |

### Buff IDs (for tracking on player)
| Buff | ID | Notes |
|------|------|-------|
| Slice and Dice | 6774 | Same as cast spell ID |
| Blade Flurry | 13877 | Same as cast spell ID |
| Adrenaline Rush | 13750 | Same as cast spell ID |
| Cold Blood | 14177 | Same as cast spell ID, consumed on next ability |
| Evasion (R2) | 26669 | +50% dodge active |
| Sprint (R3) | 26023 | Speed active (buff ID differs from cast ID 11305) |
| Cloak of Shadows | 31224 | +90% spell resist active |
| Stealth (R4) | 1787 | Stealth active |
| Shadowstep dmg buff | 36563 | +20% damage, 10s (separate from cast ID 36554) |
| Remorseless Attacks | 14143 | +20% crit on next SS/Hemo/Backstab/Ambush after kill |
| Master of Subtlety | 31665 | +10% damage, 6s after leaving Stealth (Sub talent) |
| Cheat Death proc | 45182 | Internal CD tracker (Sub talent) |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Haste Potion | 22838 | +400 haste rating 15s, 2 min potion CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Thistle Tea | 7676 | +100 energy, Rogue-specific, separate CD from potions |
| Adamantite Sharpening Stone | 23528 | +12 damage + 14 crit rating (1 hour weapon buff) |
| Adamantite Weightstone | 28421 | +12 damage + 14 crit rating (blunt weapons) |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+):
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Fan of Knives | Wrath (3.0) | AoE ability doesn't exist |
| Killing Spree | Wrath (3.0) | Combat 51pt talent doesn't exist |
| Shadow Dance | Wrath (3.0) | Subtlety 51pt talent doesn't exist |
| Tricks of the Trade | Wrath (3.0) | Threat redirect doesn't exist |
| Hunger for Blood | Wrath (3.0) | Assassination talent doesn't exist |
| Honor Among Thieves | Wrath (3.0) | Subtlety CP generation doesn't exist |
| Cut to the Chase | Wrath (3.0) | Envenom refreshing SnD doesn't exist |
| Mutilate from front | Wrath (3.0) | TBC Mutilate requires behind target |
| Envenom not consuming DP | Wrath (3.1+) | TBC Envenom CONSUMES Deadly Poison stacks |

**What IS new in TBC (vs Classic):**
- Cloak of Shadows (level 66 baseline)
- Shiv (level 70 trained) — instant poison application
- Envenom (level 62 trained) — consumes Deadly Poison stacks for burst
- Shadowstep (Subtlety 41pt talent) — teleport behind target
- Anesthetic Poison (TBC-only rank)
- Deadly Throw (not implemented — rarely used PVE)
- Cheat Death (Subtlety talent, passive)

---

## 2. Combat Rogue Rotation & Strategies

### Core Mechanic: Slice and Dice Uptime + Sustained DPS
Combat Rogue is the premier PVE DPS spec in TBC. Core identity:
- **Slice and Dice** must be maintained at all times (30% attack speed)
- **Sinister Strike** as primary combo point builder
- High white damage output with Combat talents (+OH damage, +hit, +weapon speed)
- **Blade Flurry** for sustained cleave and attack speed
- **Adrenaline Rush** for burst energy regen windows

### Single Target Rotation
From wowsims `rotation.go` (plan-based state machine) and TBC Classic guides:

**Key wowsims insight**: The sim uses ONE unified rotation for all specs — only the builder spell
differs (SS for Combat, Mutilate for Assassination, Hemorrhage for Subtlety). The finisher
priority and SnD/EA maintenance logic is identical across all three specs.

```
Opener (from Stealth):
1. Garrote (if no positional) OR Cheap Shot (for CP)
2. Slice and Dice at 1-2 CP (get uptime ASAP — "PlanSliceASAP")
3. Build to 5 CP → Rupture (if TTD > duration)
4. Build to 5 CP → Slice and Dice (maximal refresh — "PlanMaximalSlice")
5. Sustained rotation cycle

Sustained Rotation (wowsims "PlanNone" → decision tree):
1. If 0 CP → use builder (Sinister Strike)
2. If SnD not active → "PlanSliceASAP" (SnD at any CP count)
3. If maintaining Expose Armor:
   a. Calculate EA build time remaining
   b. If EA needs refresh soon → "PlanExposeArmor"
   c. If SnD needs refresh soon → "PlanMaximalSlice"
   d. Otherwise → build to 5 CP, use damage finisher, then prep for EA/SnD
4. If not maintaining EA:
   a. If SnD has enough time → "PlanFillBeforeSND" (damage finisher → SnD)
   b. If SnD needs refresh → "PlanMaximalSlice" (build to max CP → SnD)

Damage Finisher Priority (wowsims "tryUseDamageFinisher"):
1. Rupture — if enabled, not active, TTD > duration, and NOT during Blade Flurry multi-target
2. Eviscerate — fallback CP dump
Note: wowsims does NOT use Envenom in the default rotation. Rupture > Eviscerate only.
```

### Shiv for Deadly Poison Maintenance (wowsims `castBuilder`)
```
If UseShiv enabled AND Deadly Poison active on target AND DP duration < 2s:
  → Shiv (refreshes Deadly Poison via OH poison application)
Else:
  → Builder (Sinister Strike)
```

### Energy Pooling (wowsims `canPoolEnergy`)
- **Pool when**: fight > 6s remaining AND energy <= 50
- **During Adrenaline Rush**: pool threshold drops to <= 30
- **Pool before finishers**: if SnD/EA remaining > 2s, wait to pool energy
- **Never pool**: when SnD/EA about to expire (<= 1s remaining — emergency cast)

### Combat Strategies (priority order)
1. **Maintain Slice and Dice** — if not active or < 2s remaining, finisher at any CP count
2. **Blade Flurry** — off-GCD, use on CD
3. **Adrenaline Rush** — off-GCD, use on CD (pair with Blade Flurry)
4. **Trinkets** — off-GCD, pair with AR window
5. **Racial** — off-GCD (Blood Fury/Berserking)
6. **Expose Armor** — at 5 CP if enabled and debuff not active
7. **Rupture** — at 5 CP if debuff not active and TTD > threshold
8. **Eviscerate** — at 5 CP as CP dump
9. **Sinister Strike** — primary builder

### State Tracking Needed
- `snd_active` — Slice and Dice buff present
- `snd_duration` — remaining SnD duration
- `rupture_active` — Rupture debuff on target
- `rupture_duration` — remaining Rupture duration
- `blade_flurry_active` — Blade Flurry buff
- `adrenaline_rush_active` — Adrenaline Rush buff
- `expose_armor_active` — Expose Armor debuff on target

---

## 3. Assassination Rogue Rotation & Strategies

### Core Mechanic: Mutilate + Envenom + Poison Synergy
Assassination in TBC revolves around:
- **Mutilate** as CP builder (2 CP per use, requires daggers both hands)
- **Deadly Poison** stacks on target (up to 5)
- **Envenom** as primary finisher (consumes Deadly Poison stacks for burst damage)
- **Cold Blood** for guaranteed crit on key finishers
- **Find Weakness** talent: +10% armor pen for 10s after stealth opener

### Single Target Rotation
From wowsims `rotation.go` (same unified rotation, Builder=Mutilate) and TBC Classic guides:

**wowsims note**: The sim uses Mutilate as the builder but the same SnD/Rupture/Eviscerate
finisher logic as Combat. Envenom is registered as a spell but NOT used in the default rotation —
the damage finisher path is Rupture > Eviscerate only. Community guides DO recommend Envenom
as an option, so we include it as a configurable setting.

```
Opener (from Stealth):
1. Garrote (applies DoT + Find Weakness proc) OR Cheap Shot (for stunlock)
2. Mutilate → Slice and Dice (at 2+ CP, get uptime ASAP)
3. Mutilate → Mutilate → Rupture at 4-5 CP (if TTD > duration)
4. Sustained rotation cycle

Sustained Rotation (same plan-based logic as Combat):
1. ALWAYS maintain Slice and Dice (highest priority finisher)
2. Maintain Rupture (if TTD > duration) — skipped during Blade Flurry multi-target
3. Mutilate to build combo points (2 CP each, very fast building)
4. Shiv to refresh Deadly Poison if duration < 2s (wowsims pattern)
5. At 4-5 CP: SnD > Rupture > Envenom (optional) > Eviscerate

Finisher Priority (at 4-5 CP):
1. Slice and Dice (if < 2s remaining or not active)
2. Rupture (if not active and TTD > duration)
3. Envenom (optional — when Deadly Poison stacks >= threshold, if enabled)
4. Eviscerate (fallback CP dump)

Envenom Notes (TBC-specific):
- CONSUMES all Deadly Poison stacks on target
- Damage = 60 + (180 + 40 Vile Poisons) × consumed stacks, scales with CP
- Energy cost: 35 (25 with Assassination T5 4pc)
- Must let Deadly Poison restack after each Envenom
- Do NOT Envenom with only 1 stack — wait for 4-5 stacks
- Shiv can be used to rebuild DP stacks faster after Envenom
```

### Assassination Strategies (priority order)
1. **Maintain Slice and Dice** — highest priority finisher
2. **Cold Blood** — off-GCD, pair with Envenom or Eviscerate
3. **Trinkets** — off-GCD, use on CD
4. **Racial** — off-GCD (Blood Fury/Berserking)
5. **Rupture** — at 4-5 CP if debuff not active and TTD > threshold
6. **Envenom** — at 4-5 CP when Deadly Poison stacks >= setting threshold
7. **Eviscerate** — at 4-5 CP if no Deadly Poison stacks or Envenom disabled
8. **Mutilate** — primary builder (2 CP, requires behind target + daggers)

### State Tracking Needed
- `snd_active` — Slice and Dice buff present
- `snd_duration` — remaining SnD duration
- `rupture_active` — Rupture debuff on target
- `rupture_duration` — remaining Rupture duration
- `deadly_poison_stacks` — Deadly Poison stacks on target (0-5)
- `deadly_poison_duration` — remaining DP debuff duration
- `cold_blood_active` — Cold Blood buff active
- `find_weakness_active` — Find Weakness debuff on target

---

## 4. Subtlety Rogue Rotation & Strategies

### Core Mechanic: Hemorrhage + Shadowstep + Opener Burst
Subtlety is primarily PVP in TBC but has a viable PVE build:
- **Hemorrhage** as primary builder (35 energy, cheaper than SS)
- **Shadowstep** for teleport + 20% damage buff on next ability
- **Premeditation** for 2 free CP from stealth
- **Preparation** resets key CDs (Vanish, Sprint, Evasion, Cold Blood, Shadowstep)
- **Master of Subtlety** talent: +10% damage for 6s after leaving stealth

### Single Target Rotation
From TBC Classic guides (Sub is not well-simulated in wowsims):

```
Opener (from Stealth):
1. Premeditation → Shadowstep → Ambush (or Cheap Shot)
   (Premed gives 2 CP, Shadowstep buffs +20%, Ambush crits hard)
2. Slice and Dice at 3+ CP
3. Build with Hemorrhage → Rupture at 5 CP
4. Sustained rotation

Sustained Rotation:
1. ALWAYS maintain Slice and Dice
2. Maintain Hemorrhage debuff on target (10 charges, 15s — very easy to maintain)
3. Maintain Rupture (if TTD > duration)
4. Hemorrhage to build combo points
5. At 5 CP: SnD > Rupture > Eviscerate

Shadowstep Usage (PVE):
- Use on CD for +20% damage on next ability
- Best paired with Hemorrhage or Sinister Strike (instant abilities)
- Teleports behind target (useful for positional requirements)
```

### Subtlety Strategies (priority order)
1. **Maintain Slice and Dice** — highest priority finisher
2. **Shadowstep** — off-GCD(?), use on CD for +20% dmg buff
3. **Preparation** — off-GCD, use to reset Shadowstep/Vanish/Cold Blood
4. **Trinkets** — off-GCD, use on CD
5. **Racial** — off-GCD
6. **Ghostly Strike** — secondary builder on CD (20s CD, 40 energy, +15% dodge 7s, setting-gated)
7. **Rupture** — at 5 CP if debuff not active and TTD > threshold
8. **Eviscerate** — at 5 CP as CP dump
9. **Hemorrhage** — primary builder (keeps debuff active passively)

**Ghostly Strike notes:**
- Subtlety talent (not available to all rogues)
- Use on CD as a secondary builder between Hemorrhage casts
- Grants +15% dodge for 7s — meaningful defensive benefit on bosses
- 40 energy (5 more than Hemorrhage, so only use when energy is sufficient)
- Does NOT require positional requirement (unlike Backstab/Mutilate)
- Setting: `subtlety_use_ghostly_strike` (default true, requires talent)

### State Tracking Needed
- `snd_active` — Slice and Dice buff present
- `snd_duration` — remaining SnD duration
- `rupture_active` — Rupture debuff on target
- `rupture_duration` — remaining Rupture duration
- `hemo_debuff_active` — Hemorrhage debuff on target
- `hemo_debuff_charges` — remaining charges (max 10)
- `shadowstep_buff_active` — +20% damage buff from Shadowstep

---

## 5. AoE Rotation (All Specs)

Rogue has **extremely limited AoE** in TBC. There is NO Fan of Knives (Wrath only).

### Available AoE Options
1. **Blade Flurry** (Combat talent) — strikes 1 extra nearby target for 15s
   - This is the only real "AoE" ability
   - Use on CD when 2+ targets are present
2. **Tab-target Rupture/SnD** — spread bleeds manually
3. **Single-target focus** — Rogue is fundamentally a single-target class in TBC

### Spec-Specific AoE
- **Combat**: Blade Flurry is the strongest cleave. With AR + BF, very strong 2-target DPS
- **Assassination/Subtlety**: No meaningful AoE tools

### AoE Strategy
```
When enemy_count >= 2 and Blade Flurry available:
1. Activate Blade Flurry (cleave for 15s)
2. Continue single-target rotation (cleave happens automatically)
3. Consider Adrenaline Rush + Blade Flurry for max cleave burst
4. SKIP Rupture during Blade Flurry multi-target (wowsims: Eviscerate is better for cleave)
   — Rupture doesn't cleave, Eviscerate front-loads damage that BF copies
```

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Evasion** — +50% dodge, 15s (5 min CD)
   - Use when: taking melee damage, pulling aggro
2. **Cloak of Shadows** — remove spells + 90% spell resist, 5s (1 min CD)
   - Use when: harmful magic effects on player, spell damage incoming
3. **Vanish** — emergency stealth (5 min CD)
   - Use when: HP critically low, need to drop aggro
4. **Feint** — threat reduction (10s CD, 20 energy)
   - Use when: high threat, proactive threat management

### Interrupt
1. **Kick** — interrupt + 5s school lockout (10s CD, 25 energy)
   - Very efficient, low CD interrupt

### Self-Preservation
1. **Sprint** — +70% speed 15s (escape mechanics, positioning)
2. **Blind** — 10s disorient (emergency CC)
3. **Kidney Shot** — stun finisher (emergency stun on add)

### Stealth Openers (Pre-combat only)
- Handled as opening rotation, not middleware
- Garrote (DoT + silence with talent) — default PVE opener
- Cheap Shot (2 CP + stun) — when stun is needed
- Ambush (high burst) — Subtlety/PVP or with Shadowstep

---

## 7. Energy Management System

### Energy Regeneration
- **Base**: 20 energy per 2 seconds (10 energy/tick)
- **Adrenaline Rush**: doubles to 40 energy per 2 seconds
- **Thistle Tea**: instant +100 energy, 5 min CD with 2 min shared conjured CD
- **Combat Potency** (Combat talent): 20% chance for 15 energy on OH hit
- **Relentless Strikes** (talent): 20% per CP to restore 25 energy on finisher (100% at 5 CP)
- No trackable buff for Relentless Strikes (passive energy return)

### Energy Recovery Priority
1. **Thistle Tea** — +100 energy instant (wowsims: use when energy <= 40 to avoid capping)
2. **Haste Potion** — +400 haste rating 15s (more white hits = more Combat Potency procs)
   - Use with AR + BF window for max DPS
3. **Adrenaline Rush** — doubled energy regen for 15s (Combat only)

### Energy Pooling Rules (from wowsims `canPoolEnergy`)
- **Pool threshold**: energy <= 50 (normal), energy <= 30 (during Adrenaline Rush)
- **Only pool when**: fight has > 6 seconds remaining
- **Pool before finishers**: if SnD/EA has > 2s remaining, delay finisher to accumulate energy
- **Emergency cast**: if SnD/EA has <= 1s remaining, cast immediately regardless of energy
- **Never sit at 0 CP**: if 0 CP, always use builder regardless of energy (no useful pooling with 0 CP)
- **No ability costs < 25 energy**: if energy < 25, simply wait (wowsims early exit)

---

## 8. Cooldown Management

### Combat Cooldown Priority
1. **Blade Flurry** + **Adrenaline Rush** — stack together for maximum burst
   - BF CD: 2 min, AR CD: 5 min
   - Use BF on CD, stack AR when both available
2. **Haste Potion** — during BF + AR window
3. **Trinkets** — pair with BF + AR
4. **Blood Fury / Berserking** — pair with BF + AR

### Assassination Cooldown Priority
1. **Cold Blood** — pair with Envenom (at 5 Deadly Poison stacks) for guaranteed crit
2. **Trinkets** — use on CD
3. **Blood Fury / Berserking** — use on CD

### Subtlety Cooldown Priority
1. **Shadowstep** — use on CD (30s CD, +20% damage buff)
2. **Preparation** — use after Shadowstep, Cold Blood, Vanish on CD
3. **Cold Blood** — pair with Eviscerate or Ambush (from Vanish)
4. **Vanish → Opener** — re-apply Find Weakness / Master of Subtlety
5. **Trinkets** — pair with burst windows

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "combat" | Spec / Playstyle | Active rotation playstyle ("combat", "assassination", "subtlety") |
| `use_kick` | checkbox | true | Auto Kick | Interrupt enemy casts with Kick |
| `use_feint` | checkbox | false | Auto Feint | Use Feint for threat reduction |
| `feint_threat_pct` | slider | 90 | Feint Threat% | Use Feint above this threat% (50-100) |
| `use_expose_armor` | checkbox | false | Expose Armor | Use Expose Armor (disable if warrior provides Sunder) |
| `use_shiv` | checkbox | true | Use Shiv | Use Shiv to refresh Deadly Poison when < 2s remaining (wowsims pattern) |
| `opener` | dropdown | "garrote" | Stealth Opener | Opener from stealth ("garrote", "cheap_shot", "ambush", "none") |

### Tab 2: Combat
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `combat_use_blade_flurry` | checkbox | true | Use Blade Flurry | Use Blade Flurry on cooldown |
| `combat_use_adrenaline_rush` | checkbox | true | Use Adrenaline Rush | Use Adrenaline Rush on cooldown |
| `combat_use_rupture` | checkbox | true | Use Rupture | Maintain Rupture on target |
| `combat_rupture_min_ttd` | slider | 12 | Rupture Min TTD (sec) | Only Rupture if target TTD above this (6-30) |
| `combat_snd_refresh` | slider | 2 | SnD Refresh (sec) | Refresh Slice and Dice at this duration remaining (1-5) |
| `combat_rupture_refresh` | slider | 2 | Rupture Refresh (sec) | Refresh Rupture at this duration remaining (1-5) |
| `combat_min_cp_finisher` | slider | 5 | Min CP for Finisher | Minimum combo points before using Eviscerate (3-5) |

### Tab 3: Assassination
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `assassination_use_cold_blood` | checkbox | true | Use Cold Blood | Use Cold Blood with finishers |
| `assassination_use_envenom` | checkbox | true | Use Envenom | Use Envenom (consumes Deadly Poison stacks) |
| `assassination_envenom_min_stacks` | slider | 2 | Envenom Min DP Stacks | Minimum Deadly Poison stacks before using Envenom (1-5) |
| `assassination_use_rupture` | checkbox | true | Use Rupture | Maintain Rupture on target |
| `assassination_rupture_min_ttd` | slider | 12 | Rupture Min TTD (sec) | Only Rupture if target TTD above this (6-30) |
| `assassination_snd_refresh` | slider | 2 | SnD Refresh (sec) | Refresh Slice and Dice at this duration remaining (1-5) |
| `assassination_min_cp_finisher` | slider | 4 | Min CP for Finisher | Minimum combo points before using finisher (3-5) |

### Tab 4: Subtlety
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `subtlety_use_shadowstep` | checkbox | true | Use Shadowstep | Use Shadowstep on cooldown |
| `subtlety_use_preparation` | checkbox | true | Use Preparation | Use Preparation to reset CDs |
| `subtlety_use_rupture` | checkbox | true | Use Rupture | Maintain Rupture on target |
| `subtlety_rupture_min_ttd` | slider | 12 | Rupture Min TTD (sec) | Only Rupture if target TTD above this (6-30) |
| `subtlety_snd_refresh` | slider | 2 | SnD Refresh (sec) | Refresh Slice and Dice at this duration remaining (1-5) |
| `subtlety_min_cp_finisher` | slider | 5 | Min CP for Finisher | Minimum combo points before using Eviscerate (3-5) |

### Tab 5: Cooldowns & Defense
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Blood Fury/Berserking/Arcane Torrent) |
| `use_thistle_tea` | checkbox | true | Use Thistle Tea | Auto-use Thistle Tea for energy |
| `thistle_tea_energy` | slider | 40 | Thistle Tea Below Energy | Use Thistle Tea when energy below this (10-80) |
| `use_haste_potion` | checkbox | true | Use Haste Potion | Auto-use Haste Potion |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use health potion below this HP% |
| `use_evasion` | checkbox | false | Auto Evasion | Use Evasion when taking damage |
| `evasion_hp` | slider | 40 | Evasion HP% | Use Evasion below this HP% (0=disable) |
| `use_cloak_of_shadows` | checkbox | true | Auto Cloak of Shadows | Use Cloak of Shadows to remove magic debuffs |
| `cloak_hp` | slider | 50 | Cloak HP% | Use Cloak of Shadows below this HP% when magic debuffed (0=disable) |
| `use_vanish_emergency` | checkbox | false | Emergency Vanish | Use Vanish as emergency escape at very low HP |
| `vanish_hp` | slider | 10 | Vanish Emergency HP% | Use Vanish below this HP% (0=disable) |

---

## 10. Strategy Breakdown Per Playstyle

### Combat Playstyle Strategies (priority order)
```
[1]  MaintainSliceAndDice  — if SnD not active or duration < refresh_threshold
[2]  BladeFlurry           — off-GCD, use on CD (if talented + enabled)
[3]  AdrenalineRush        — off-GCD, use on CD (if talented + enabled)
[4]  Trinkets              — off-GCD, pair with BF/AR window
[5]  Racial                — off-GCD, pair with BF/AR window
[6]  ExposeArmor           — at 5 CP if enabled and debuff not active on target
[7]  Rupture               — at 5 CP if enabled, debuff not active, TTD > threshold
                              SKIP during Blade Flurry multi-target (Eviscerate better)
[8]  Eviscerate            — at min_cp+ as CP dump
[9]  ShivRefresh           — if Deadly Poison < 2s on target and UseShiv enabled (wowsims)
[10] SinisterStrike        — primary builder (energy permitting)
```

### Assassination Playstyle Strategies (priority order)
```
[1]  MaintainSliceAndDice  — if SnD not active or duration < refresh_threshold
[2]  ColdBlood             — off-GCD, pair with Envenom/Eviscerate
[3]  Trinkets              — off-GCD, use on CD
[4]  Racial                — off-GCD, use on CD
[5]  Rupture               — at 4-5 CP if enabled, debuff not active, TTD > threshold
[6]  Envenom               — at 4-5 CP when Deadly Poison stacks >= threshold (optional)
[7]  Eviscerate            — at min_cp+ as CP dump (no DP stacks or Envenom disabled)
[8]  ShivRefresh           — if Deadly Poison < 2s on target (wowsims pattern)
[9]  Mutilate              — primary builder (2 CP, behind target, daggers required)
Note: wowsims default rotation uses Rupture > Eviscerate only (no Envenom).
      Envenom is optional/configurable for community guide alignment.
```

### Subtlety Playstyle Strategies (priority order)
```
[1]  MaintainSliceAndDice  — if SnD not active or duration < refresh_threshold
[2]  Shadowstep            — use on CD for +20% dmg buff (if talented + enabled)
[3]  Preparation           — off-GCD, reset CDs when key abilities on CD
[4]  Trinkets              — off-GCD, use on CD
[5]  Racial                — off-GCD, use on CD
[6]  GhostlyStrike         — secondary builder, on CD, 20s CD, +15% dodge (if talented + enabled)
[7]  Rupture               — at 5 CP if enabled, debuff not active, TTD > threshold
[8]  Eviscerate            — at min_cp+ as CP dump
[9]  Hemorrhage            — primary builder (also maintains debuff passively)
```

### Shared Middleware (all specs)
```
[MW-500]  EmergencyVanish     — emergency stealth at critical HP (if enabled)
[MW-450]  Evasion             — emergency dodge at low HP (if enabled)
[MW-400]  CloakOfShadows      — remove magic debuffs / spell damage mitigation
[MW-350]  RecoveryItems       — healthstone, health potion
[MW-300]  Kick                — interrupt enemy cast
[MW-280]  Feint               — threat reduction (if enabled + high threat)
[MW-250]  ThistleTea          — energy recovery when low
[MW-200]  HastePotion         — use with burst CDs (or on CD)
```

---

## Key Implementation Notes

### Playstyle Detection
Rogue has NO stances/forms (like Mage). Playstyle must be determined by:
- **User setting** (dropdown: "combat", "assassination", "subtlety")
- Could auto-detect via talent check, but user setting is simpler and more reliable

### No Idle Playstyle
Rogue doesn't shift forms. Unlike Druid's "caster" idle form, Rogue has no separate OOC playstyle. `idle_playstyle_name = nil`.

### Stealth Handling
Stealth is not a "playstyle" — it's a temporary state. Handle via:
- Check `is_stealthed` in context
- Opening abilities check stealth + target conditions
- After opener, fall through to normal rotation
- Stealth openers could be a high-priority strategy that only matches when stealthed + has target

### Energy/Combo Point System
Very similar to Cat Druid — reuse patterns from `cat.lua`:
- Energy pooling before finishers
- Combo point tracking via `Player:ComboPoints()`
- Energy tracking via `Player:Energy()`
- `Player:EnergyTimeToX(target, offset)` for energy prediction

### extend_context Fields
```lua
ctx.energy = Player:Energy()
ctx.cp = Player:ComboPoints()
ctx.is_stealthed = Player:IsStealthed()
ctx.is_behind = Player:IsBehind(0.3)
ctx.in_combat = Unit("player"):CombatTime() > 0
ctx.combat_time = Unit("player"):CombatTime()
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.enemy_count = A.MultiUnits:GetByRange(10)
-- Cache invalidation flags
ctx._combat_valid = false
ctx._assassination_valid = false
ctx._subtlety_valid = false
```

### Combat State (context_builder)
```lua
local combat_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    blade_flurry_active = false,
    adrenaline_rush_active = false,
    expose_armor_active = false,
}

local function get_combat_state(context)
    if context._combat_valid then return combat_state end
    context._combat_valid = true

    combat_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(6774) or 0
    combat_state.snd_active = combat_state.snd_duration > 0
    combat_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(26867) or 0
    combat_state.rupture_active = combat_state.rupture_duration > 0
    combat_state.blade_flurry_active = (Unit(PLAYER_UNIT):HasBuffs(13877) or 0) > 0
    combat_state.adrenaline_rush_active = (Unit(PLAYER_UNIT):HasBuffs(13750) or 0) > 0
    combat_state.expose_armor_active = (Unit(TARGET_UNIT):HasDeBuffs(26866) or 0) > 0

    return combat_state
end
```

### Assassination State (context_builder)
```lua
local assassination_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    deadly_poison_stacks = 0,
    deadly_poison_duration = 0,
    cold_blood_active = false,
    find_weakness_active = false,
}

local function get_assassination_state(context)
    if context._assassination_valid then return assassination_state end
    context._assassination_valid = true

    assassination_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(6774) or 0
    assassination_state.snd_active = assassination_state.snd_duration > 0
    assassination_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(26867) or 0
    assassination_state.rupture_active = assassination_state.rupture_duration > 0
    assassination_state.deadly_poison_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(27187) or 0
    assassination_state.deadly_poison_duration = Unit(TARGET_UNIT):HasDeBuffs(27187) or 0
    assassination_state.cold_blood_active = (Unit(PLAYER_UNIT):HasBuffs(14177) or 0) > 0
    assassination_state.find_weakness_active = (Unit(TARGET_UNIT):HasDeBuffs(31234) or 0) > 0

    return assassination_state
end
```

### Subtlety State (context_builder)
```lua
local subtlety_state = {
    snd_active = false,
    snd_duration = 0,
    rupture_active = false,
    rupture_duration = 0,
    hemo_debuff_active = false,
    shadowstep_buff_active = false,
    master_of_subtlety_active = false,
}

local function get_subtlety_state(context)
    if context._subtlety_valid then return subtlety_state end
    context._subtlety_valid = true

    subtlety_state.snd_duration = Unit(PLAYER_UNIT):HasBuffs(6774) or 0
    subtlety_state.snd_active = subtlety_state.snd_duration > 0
    subtlety_state.rupture_duration = Unit(TARGET_UNIT):HasDeBuffs(26867) or 0
    subtlety_state.rupture_active = subtlety_state.rupture_duration > 0
    subtlety_state.hemo_debuff_active = (Unit(TARGET_UNIT):HasDeBuffs(26864) or 0) > 0
    subtlety_state.shadowstep_buff_active = (Unit(PLAYER_UNIT):HasBuffs(36563) or 0) > 0
    subtlety_state.master_of_subtlety_active = (Unit(PLAYER_UNIT):HasBuffs(31665) or 0) > 0

    return subtlety_state
end
```

### Class Registration
```lua
rotation_registry:register_class({
    name = "Rogue",
    version = "v1.0.0",
    playstyles = { "combat", "assassination", "subtlety" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "combat"
    end,

    get_idle_playstyle = function(context)
        return nil
    end,

    extend_context = function(ctx)
        ctx.energy = Player:Energy()
        ctx.cp = Player:ComboPoints()
        ctx.is_stealthed = Player:IsStealthed()
        ctx.is_behind = Player:IsBehind(0.3)
        ctx.combat_time = Unit("player"):CombatTime()
        ctx.is_moving = Player:IsMoving()
        ctx.is_mounted = Player:IsMounted()
        ctx.enemy_count = A.MultiUnits:GetByRange(10)
        -- Cache invalidation
        ctx._combat_valid = false
        ctx._assassination_valid = false
        ctx._subtlety_valid = false
    end,
})
```

### Similarities to Cat Druid
Rogue shares many patterns with Cat Druid (`cat.lua`):
- Energy resource system (pool → build → spend)
- Combo point management
- Slice and Dice maintenance (equivalent to Cat's Savage Roar in Wrath, but SnD exists in TBC)
- Rupture DoT maintenance
- Behind-target requirements (Backstab/Mutilate like Cat's Shred)
- The `is_behind` check and positional fallbacks

Key differences from Cat:
- No form shifting — always in "rogue form"
- Stealth opener mechanic (Cat can stealth too but less emphasis)
- Envenom mechanic (consume poison stacks) — unique to Rogue
- Poisons as weapon enchants — outside rotation scope
- More cooldowns (Blade Flurry, AR, Cold Blood, Preparation, Shadowstep)
- No powershifting mechanic

### wowsims Architecture Notes
The wowsims TBC rogue sim (`sim/rogue/rotation.go`) uses a **plan-based state machine** with
these states: `PlanNone`, `PlanOpener`, `PlanSliceASAP`, `PlanMaximalSlice`, `PlanExposeArmor`,
`PlanFillBeforeEA`, `PlanFillBeforeSND`. Key implementation details:

1. **Unified rotation**: All specs share ONE rotation — only the builder spell differs
2. **Builder selection**: Configurable (SS/Mutilate/Hemo) — auto-detected from talents+weapons
3. **Shiv as builder override**: When Deadly Poison < 2s remaining, Shiv replaces builder
4. **Energy pooling**: Pool at <= 50 energy (30 during AR), only when fight > 6s remaining
5. **SnD emergency**: Cast at <= 1s remaining regardless of CP count or energy state
6. **EA build time**: Pre-calculated from energy regen rate + builder cost + finisher cost
7. **Rupture during BF**: Skipped on multi-target (Eviscerate cleaves better)
8. **End-of-fight flags**: `doneSND`/`doneEA` — stop refreshing when fight ending soon
9. **MinComboPointsForDamageFinisher**: Configurable minimum CP for using Rupture/Eviscerate
10. **Envenom**: Registered as spell but NOT used in default rotation (Rupture > Eviscerate)
11. **Thistle Tea**: Used when energy <= 40, 5 min CD with 2 min shared conjured CD
