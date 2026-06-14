# TBC Priest Implementation Research

Comprehensive research for implementing Shadow, Smite, Holy, and Discipline Priest playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Shadow Priest Rotation & Strategies](#2-shadow-priest-rotation--strategies)
3. [Smite Priest Rotation & Strategies](#3-smite-priest-rotation--strategies)
4. [Holy Priest Rotation & Strategies](#4-holy-priest-rotation--strategies)
5. [Discipline Priest Rotation & Strategies](#5-discipline-priest-rotation--strategies)
6. [AoE Rotation (All Specs)](#6-aoe-rotation-all-specs)
7. [Shared Utility & Defensive Strategies](#7-shared-utility--defensive-strategies)
8. [Mana Management System](#8-mana-management-system)
9. [Cooldown Management](#9-cooldown-management)
10. [Proposed Settings Schema](#10-proposed-settings-schema)
11. [Strategy Breakdown Per Playstyle](#11-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Core Shadow Damage Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Shadow Word: Pain (R10) | 25368 | Instant | 575 | 18s DoT, 6 ticks (3s apart) |
| Mind Blast (R11) | 25375 | 1.5s | 450 | 8s CD (5.5s w/ 5/5 Imp MB) |
| Mind Flay (R7) | 25387 | 3s channel | 230 | 3 ticks, 50% snare |
| Vampiric Touch (R3) | 34917 | 1.5s | 400 | 15s DoT, 5 ticks, 5% shadow dmg → party mana |
| Shadow Word: Death (R2) | 32996 | Instant | 309 | 12s CD, self-damage if target survives |
| Devouring Plague (R7) | 25467 | Instant | 985 | 24s DoT, heals caster. **Undead racial only** |

### Holy Damage Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Smite (R10) | 25364 | 2.5s | 385 | Holy damage nuke |
| Holy Fire (R9) | 25384 | 3.5s | 290 | Holy dmg + 7s DoT, 10s CD |
| Holy Nova (R7) | 25331 | Instant | 750 | PB AoE damage + AoE heal. Cannot use in Shadowform |

### Core Healing Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Flash Heal (R9) | 25235 | 1.5s | 470 | Fast heal |
| Greater Heal (R7) | 25213 | 3.0s (2.5s w/ Divine Fury) | 710 | Big heal |
| Renew (R12) | 25222 | Instant | 450 | 15s HoT, 5 ticks |
| Prayer of Healing (R6) | 25308 | 3.0s | 1255 | Heals entire party |
| Power Word: Shield (R12) | 25218 | Instant | 600 | Absorb, 15s Weakened Soul |
| Prayer of Mending | 33076 | Instant | 390 | 10s CD, bounces 5 times on dmg taken |
| Circle of Healing (R5) | 34866 | Instant | 450 | 6s CD, heals 5 lowest HP (Holy talent) |
| Binding Heal | 32546 | 1.5s | 705 | Heals target + self |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Shadow Word: Pain | 589 | 25368 (R10) | |
| Mind Blast | 8092 | 25375 (R11) | |
| Mind Flay | 15407 | 25387 (R7) | Shadow talent |
| Vampiric Touch | 34914 | 34917 (R3) | Shadow 41pt talent |
| Shadow Word: Death | 32379 | 32996 (R2) | |
| Devouring Plague | 2944 | 25467 (R7) | Undead racial only |
| Smite | 585 | 25364 (R10) | |
| Holy Fire | 14914 | 25384 (R9) | |
| Holy Nova | 15237 | 25331 (R7) | |
| Flash Heal | 2061 | 25235 (R9) | |
| Greater Heal | 2060 | 25213 (R7) | |
| Renew | 139 | 25222 (R12) | |
| Prayer of Healing | 596 | 25308 (R6) | |
| Power Word: Shield | 17 | 25218 (R12) | |
| Circle of Healing | 34861 | 34866 (R5) | Holy 41pt talent |
| Lightwell | 724 | 27871 (R4) | Holy talent |
| Inner Fire | 588 | 25431 (R7) | |
| Power Word: Fortitude | 1243 | 25389 (R7) | |
| Prayer of Fortitude | 21562 | 25392 (R3) | |
| Divine Spirit | 14752 | 25312 (R5) | Disc talent |
| Prayer of Spirit | 27681 | 32999 (R2) | Disc talent |
| Shadow Protection | 976 | 25433 (R4) | |
| Prayer of Shadow Protection | 27683 | 39374 (R2) | |
| Fade | 586 | 25429 (R7) | |
| Psychic Scream | 8122 | 10890 (R4) | |
| Dispel Magic | 527 | 988 (R2) | |
| Shackle Undead | 9484 | 10955 (R3) | |
| Mana Burn | 8129 | 32860 (R5) | |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Shadowform | 15473 | Shadow talent toggle |
| Vampiric Embrace | 15286 | Shadow talent, applies debuff on target |
| Shadowfiend | 34433 | TBC trained (66), 5 min CD |
| Prayer of Mending | 33076 | TBC trained (68), 10s CD |
| Binding Heal | 32546 | TBC trained (64) |
| Mass Dispel | 32375 | TBC trained (70), 1.5s cast, 789 mana |
| Fear Ward | 6346 | Trainable by all priests in TBC |
| Inner Focus | 14751 | Disc talent, 3 min CD |
| Power Infusion | 10060 | Disc talent, 3 min CD, +20% haste 15s |
| Pain Suppression | 33206 | TBC Disc talent (41pt), 5 min CD |
| Silence | 15487 | Shadow talent, 45s CD, 5s silence |
| Abolish Disease | 552 | Single rank |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Inner Focus | 14751 | 3 min | Next spell | Free + 25% crit on next spell |
| Power Infusion | 10060 | 3 min | 15s | +20% spell haste (Disc talent) |
| Pain Suppression | 33206 | 5 min | 8s | -40% dmg taken on target (41pt Disc) |
| Shadowfiend | 34433 | 5 min | 15s | Mana return pet (~5% max mana per hit, ~50% total) |
| Shadow Word: Death | 32996 | 12s | — | Instant execute, self-damage on non-kill |
| Mind Blast | 25375 | 8s (5.5s talented) | — | Primary nuke |
| Prayer of Mending | 33076 | 10s | — | Bouncing heal, 5 charges |
| Circle of Healing | 34866 | 6s | — | Instant smart AoE heal (Holy talent) |
| Psychic Scream | 10890 | 30s | 8s fear | AoE fear, dangerous in PvE |
| Fade | 25429 | 30s | 10s | Temporary threat reduction |
| Silence | 15487 | 45s | 5s | Shadow talent interrupt |
| Fear Ward | 6346 | 3 min | 10 min | Anti-fear buff |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Power Word: Shield (R12) | 25218 | 4s GCD | Absorb, applies 15s Weakened Soul |
| Fade (R7) | 25429 | 30s | Temp threat reduction, 10s |
| Fear Ward | 6346 | 3 min | Anti-fear buff, trainable in TBC |
| Dispel Magic (R2) | 988 | — | Removes 2 magic effects from friendly |
| Mass Dispel | 32375 | — | AoE dispel, removes immunities (Pally bubble, Ice Block) |
| Abolish Disease | 552 | — | Disease cleanse + ticks every 5s for 25s |
| Psychic Scream (R4) | 10890 | 30s | AoE fear 8s, dangerous in PvE |
| Silence | 15487 | 45s | Shadow talent, 5s silence |
| Shackle Undead (R3) | 10955 | — | CC undead, 50s |
| Mind Control | 605 | — | Channel, control humanoid |
| Mana Burn (R5) | 32860 | — | Burns mana, deals half as damage |
| Desperate Prayer (R8) | 25437 | 10 min | Instant self-heal (Dwarf/Human racial) |

### Self-Buffs
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Inner Fire (R7) | 25431 | 10 min | +1580 armor, 20 charges |
| Power Word: Fortitude (R7) | 25389 | 30 min | +79 stamina (single) |
| Prayer of Fortitude (R3) | 25392 | 1 hr | +79 stamina (group) |
| Divine Spirit (R5) | 25312 | 30 min | +50 spirit (Disc talent) |
| Prayer of Spirit (R2) | 32999 | 1 hr | +50 spirit (group, Disc talent) |
| Shadow Protection (R4) | 25433 | 10 min | +70 shadow resist |
| Prayer of Shadow Protection (R2) | 39374 | 20 min | +70 shadow resist (group) |
| Shadowform | 15473 | Toggle | +15% shadow dmg, -15% phys dmg taken |
| Fear Ward | 6346 | 10 min | Anti-fear buff |

### Racial Priest Spells
Priests have unique spells per race in TBC:
| Race | Spell | ID | Notes |
|------|--------|------|-------|
| Dwarf | Desperate Prayer (R8) | 25437 | Instant self-heal, 10 min CD |
| Human | Desperate Prayer (R8) | 25437 | Same as Dwarf |
| Human | Feedback (R6) | 25441 | Mana burn shield, 15s buff |
| Night Elf | Starshards (R8) | 25446 | Channel arcane dmg, 30s CD |
| Night Elf | Elune's Grace (R5) | 19293 | Dodge+hit reduction, 5 min CD |
| Draenei | Symbol of Hope | 32548 | Channel party mana, 5 min CD |
| Draenei | Chastise (R6) | 44047 | Holy dmg + 2s incap, 30s CD |
| Undead | Devouring Plague (R7) | 25467 | Shadow DoT + heals caster, 3 min CD |
| Undead | Touch of Weakness (R7) | 25461 | -35 AP on attacker, self-buff |
| Troll | Shadowguard (R7) | 25477 | Shadow dmg on hit taken, 3 charges |
| Troll | Hex of Weakness (R2) | 25470 | -35 dmg + healing debuff, 2 min |
| Blood Elf | Consume Magic | 32676 | Dispel own buff for mana, 2 min CD |
| Blood Elf | Touch of Weakness (R7) | 25461 | Same as Undead |

Also relevant non-priest racials:
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Troll | Berserking | 26297 | 10-30% haste 10s, 3 min CD |
| Blood Elf | Arcane Torrent | 28730 | Silence 2s + mana restore, 2 min CD |
| Draenei | Gift of the Naaru | 28880 | HoT heal |
| Undead | Will of the Forsaken | 7744 | Removes charm/fear/sleep |
| Gnome | Escape Artist | 20589 | Removes root/snare (Gnomes can't be priests, listed for reference) |

### Debuff IDs (for tracking)
| Debuff | ID | Notes |
|--------|------|-------|
| Shadow Word: Pain | 25368 | DoT on target (track max rank ID) |
| Vampiric Touch | 34917 | DoT on target (max rank) |
| Shadow Weaving | 15258 | +2% shadow dmg per stack, max 5 (10% total), 15s duration |
| Misery | 33200 | +5% spell hit (5/5 talent), 24s duration. Ranks: 33196-33200 |
| Devouring Plague | 25467 | DoT on target (Undead racial, max rank) |
| Holy Fire DoT | 25384 | 7s DoT component |
| Weakened Soul | 6788 | 15s after PW:S, prevents re-shielding |
| Vampiric Embrace debuff | 15290 | On target, 1 min duration, party heals from shadow dmg |

### Buff IDs (for tracking)
| Buff | ID | Notes |
|------|------|-------|
| Shadowform | 15473 | Shadow form active |
| Inner Focus | 14751 | Next spell free + 25% crit |
| Power Infusion | 10060 | +20% spell haste, 15s |
| Pain Suppression | 33206 | -40% dmg taken, 8s |
| Inner Fire | 25431 | Armor buff (max rank for tracking) |
| Power Word: Shield | 25218 | Absorb shield active (max rank) |
| Fear Ward | 6346 | Anti-fear active |
| Surge of Light | 33151 | Proc: next Smite instant + free (cannot crit) |
| Holy Concentration (Clearcasting) | 34754 | Proc: next FH/BH/GH free. Lasts 15s |
| Inspiration | 15363 | -25% phys dmg taken on healed target, 15s |
| Shadowguard | 25477 | Troll racial, shadow dmg on hit taken |
| Heroism | 32182 | Shaman haste (Alliance) |
| Bloodlust | 2825 | Shaman haste (Horde) |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD) |
| Demonic Rune | 12662 | Same as Dark Rune |
| Destruction Potion | 22839 | +120 SP, +2% spell crit for 15s (Shadow DPS) |
| Master Healthstone | 22105 | Best warlock healthstone |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+) or later:
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Penance | Wrath (3.0) | Disc channeled heal/damage does NOT exist |
| Guardian Spirit | Wrath (3.0) | Holy prevent-death CD does NOT exist |
| Divine Hymn | Wrath (3.0) | Channeled AoE heal does NOT exist |
| Hymn of Hope | Wrath (3.0) | Mana recovery channel does NOT exist |
| Mind Sear | Wrath (3.0) | Shadow AoE channel does NOT exist |
| Dispersion | Wrath (3.0) | Shadow mana recovery CD does NOT exist |
| Borrowed Time | Wrath (3.0) | Haste after PW:S does NOT exist |
| Body and Soul | Wrath (3.0) | Speed boost from PW:S does NOT exist |
| Rapture | Wrath (3.0) | Mana return on PW:S absorb does NOT exist |
| Grace | Wrath (3.0) | Stacking healing buff does NOT exist |
| Serendipity | Wrath (3.0) | FH reduces GH/PoH cast time does NOT exist |
| Renewed Hope | Wrath (3.0) | Crit buff from PW:S does NOT exist |
| Pain and Suffering | Wrath (3.0) | Auto-refresh SW:P via Mind Flay does NOT exist |
| Psychic Horror | Wrath (3.0) | Horror ability does NOT exist |
| Devouring Plague (baseline) | Wrath (3.0) | Undead racial only in TBC, Wrath made it baseline |
| Power Word: Barrier | Cata (4.0) | AoE damage reduction dome does NOT exist |
| Chakra / Holy Words | Cata (4.0) | Holy stance system does NOT exist |
| Leap of Faith | Cata (4.0) | Life Grip does NOT exist |
| Atonement healing | Wrath+ | Smite healing allies does NOT exist in TBC |
| Mind Spike | Cata (4.0) | Spell does NOT exist |

**What IS new in TBC (vs Classic):**
- Vampiric Touch (41-point Shadow talent) — THE defining TBC Shadow Priest ability
- Shadow Word: Death (level 62 trained) — instant nuke with self-damage
- Shadowfiend (level 66 trained) — mana recovery pet
- Prayer of Mending (level 68 trained) — bouncing heal
- Binding Heal (level 64 trained) — heals self + target
- Circle of Healing (41-point Holy talent) — instant party smart heal
- Pain Suppression (41-point Disc talent) — damage reduction CD
- Mass Dispel (level 70 trained) — AoE dispel, removes immunities
- Fear Ward trainable by all Priest races (was Dwarf-only in Classic)
- PW:S now scales with +healing gear (new in TBC)

---

## 2. Shadow Priest Rotation & Strategies

### Core Mechanic: DoT Management + Shadow Weaving
Shadow Priest is a DoT-based spec that provides massive raid utility through Vampiric Touch (mana return) and Shadow Weaving (+10% shadow damage taken).

**Shadow Weaving**:
- Debuff ID: 15258 (on target)
- Each shadow damage event has 100% chance (at 5/5 talent) to apply/refresh a stack
- Stacks to 5 at +2% shadow damage taken each = 10% total
- Duration: 15 seconds, refreshed on each application
- Applied by: Mind Blast, Mind Flay (each tick), SW:P (each tick), VT (each tick), SW:D
- Benefits ALL shadow damage dealers in the raid (Warlocks especially)

**Misery** (shadow talent):
- Debuff ID: 33200 (at 5/5 talent)
- Applied by SW:P, Mind Flay, Vampiric Touch
- +5% spell hit chance against the target (raid-wide benefit)

### Single Target Rotation
From wowsims `shadow/rotation.go` (`tryUseGCD`):

```
Opener (wowsims PrecastVt option):
1. Pre-cast Vampiric Touch (1.5s, lands at pull timer 0)
2. Shadow Word: Pain (instant, immediately after VT lands)
3. Mind Blast (1.5s cast, on CD)
4. Mind Flay (channeled filler)
5. Resume priority rotation

Priority (from wowsims source):
1. Vampiric Touch     — if remaining duration <= vtCastTime (haste-aware)
2. Shadow Word: Pain  — if NOT active (reapply only when it falls off entirely)
3. Starshards         — if Night Elf + enabled + off CD (before MB/SWD!)
4. Devouring Plague   — if Undead + enabled + off CD (before MB/SWD!)
5. Mind Blast         — on cooldown (Inner Focus fired first if ready)
6. Shadow Word: Death — on cooldown
7. Mind Flay          — filler (1-3 ticks, optimized by rotation type)
```

**Critical wowsims detail**: SW:P is only reapplied when it falls off entirely (`!IsActive()`),
NOT refreshed early. VT is refreshed when remaining <= cast time (accounting for haste).
Starshards and Devouring Plague are checked BEFORE MB/SWD in the priority.

### Mind Flay Rotation Types (from wowsims)
The wowsims simulator implements three Mind Flay strategies:

**Basic** (`ShadowPriest_Rotation_Basic`):
- Always cast full 3-tick Mind Flay
- Only skip MF if next CD comes before GCD completes
- Simplest, lowest skill floor

**Clipping** (`ShadowPriest_Rotation_Clipping`):
- Clips MF to cast MB/SWD as soon as they come off CD
- Calculates ticks available before next CD (accounting for latency setting)
- Uses MF1, MF2, or MF3 depending on time until next CD
- Tick optimization: 1 tick → MF1, 2 or 4 ticks → MF2, 3+ ticks → MF3

**Ideal** (`ShadowPriest_Rotation_Ideal`):
- DPS-optimal tick calculation considering spell damage values
- Compares DPS of waiting vs casting extra MF ticks
- Evaluates which upcoming spell (MB, SWD, VT refresh, SW:P refresh) yields highest DPS per time
- May choose to MF toward a non-nearest CD if it yields better DPS
- Most complex, highest theoretical DPS

```
Mind Flay Clipping (all types):
- MF tick length = 1s base (reduced by haste: ApplyCastSpeed(1000ms))
- MF GCD = max(1.5s base, tick_count * tick_length)
- Clip decision: check time until MB/SWD ready
- Tick count → MF variant: 1→MF1, 2 or 4→MF2, 3 or 5+→MF3
- Framework should track MB/SWD cooldown and suggest optimal MF tick count
```

### Shadow Strategies (priority order)
1. **Ensure Shadowform** — if not in Shadowform, enter it (OOC only)
2. **Vampiric Embrace** — if missing on target (long 60s duration, low priority reapply)
3. **Vampiric Touch** — if remaining <= cast time (haste-aware refresh)
4. **Shadow Word: Pain** — if NOT active (reapply only when it falls off)
5. **Starshards** — if Night Elf + enabled + off CD
6. **Devouring Plague** — if Undead + enabled + off CD
7. **Inner Focus + Mind Blast** — if both ready (IF fires off-GCD, MB follows)
8. **Mind Blast** — on cooldown (5.5s CD with talents)
9. **Shadow Word: Death** — on CD if HP > threshold setting
10. **Mind Flay** — filler (1-3 ticks based on rotation type + CD timing)
11. **Trinkets / Racial** — off-GCD, use on CD

### State Tracking Needed
- `vt_remaining` — Vampiric Touch duration on target
- `vt_cast_time` — current VT cast time (haste-aware, for refresh comparison)
- `swp_active` — Shadow Word: Pain active on target (boolean, NOT duration)
- `ve_remaining` — Vampiric Embrace duration on target
- `shadow_weaving_stacks` — stacks on target (0-5)
- `mb_cd_remaining` — Mind Blast cooldown remaining (for MF tick optimization)
- `swd_cd_remaining` — Shadow Word: Death cooldown remaining
- `mb_ready` — Mind Blast off cooldown
- `swd_ready` — Shadow Word: Death off cooldown
- `in_shadowform` — Shadowform active
- `inner_focus_ready` — Inner Focus off cooldown
- `player_hp_safe` — HP above SW:D threshold

---

## 3. Smite Priest Rotation & Strategies

### Core Mechanic: Holy DPS with Shadow Utility
Smite Priest is a hybrid Holy DPS spec supported by wowsims/tbc. It deals primarily Holy damage via Smite and Holy Fire while maintaining SW:P for Shadow Weaving stacks (benefiting Warlocks) and Misery (+5% spell hit). The spec is talent-heavy in Holy (Divine Fury for faster casts, Searing Light for +10% Smite/Holy Fire damage, Surge of Light for instant free Smite procs) with enough Shadow for Shadow Weaving.

**Surge of Light** (Holy talent):
- Buff ID: 33151
- 50% chance on any spell critical strike
- Next Smite becomes instant cast, costs no mana (cannot crit)
- Duration: 10 seconds
- Critical for Smite DPS throughput — weave instant Smites between other casts

**Key Talent Assumptions**:
- **Divine Fury** (5/5): Reduces Smite cast time from 2.5s → 2.0s, Holy Fire from 3.5s → 3.0s
- **Searing Light** (2/2): +10% damage to Smite and Holy Fire
- **Shadow Weaving** (5/5): SW:P ticks apply Shadow Weaving stacks (raid utility)
- **Misery** (5/5): SW:P applies +5% spell hit debuff

### Single Target Rotation
From wowsims `smite/rotation.go` (`tryUseGCD`):

```
Priority (from wowsims source):
1. Shadow Word: Pain  — if NOT active (reapply when it falls off; maintains Shadow Weaving + Misery)
2. Starshards         — if Night Elf + enabled + off CD
3. Devouring Plague   — if Undead + enabled + off CD
4. Mind Blast         — if enabled + off CD (optional, some builds skip)
5. Shadow Word: Death — if enabled + off CD (optional, some builds skip)
6. Holy Fire (Weave)  — if rotation type is HolyFireWeave AND timing window open
7. Smite              — filler (2.0s cast with Divine Fury)
```

**Holy Fire Weave Mechanic** (from wowsims):
The key optimization for Smite Priest is the Holy Fire Weave. Holy Fire has a 10s CD and 3.0s cast time (talented). The wowsims logic weaves HF into the rotation when SW:P won't fall off during the longer cast:

```
Condition (wowsims logic):
  swpRemaining > smiteCastTime AND swpRemaining < hfCastTime
  → Cast Holy Fire instead of Smite

In practice (with haste):
  smiteCastTime = ApplyCastSpeed(2000ms)  -- 2.0s base (Divine Fury)
  hfCastTime = ApplyCastSpeed(3000ms)     -- 3.0s base (Divine Fury)

  If SW:P has 2.5s remaining:
    - Too short for HF (3.0s cast) → cast Smite (2.0s)
    - SW:P refreshes after Smite, then HF in next window

  If SW:P has 4.0s remaining:
    - swpRemaining (4.0) > smiteCast (2.0) ✓
    - swpRemaining (4.0) < hfCast (3.0)  ✗ → NOT in weave window
    - Cast Smite

  If SW:P has 2.3s remaining:
    - swpRemaining (2.3) > smiteCast (2.0) ✓
    - swpRemaining (2.3) < hfCast (3.0)  ✓ → IN weave window
    - Cast Holy Fire (it'll finish after SW:P falls off, then reapply SW:P next GCD)
```

**Why this works**: The weave window targets the exact gap where Smite would finish but HF wouldn't — meaning you can "fit" HF into the rotation without losing SW:P uptime, since you'll reapply SW:P right after HF completes.

### Smite vs Shadow DPS
- Smite Priest deals less personal DPS than Shadow Priest
- Brings Shadow Weaving + Misery utility like Shadow (via SW:P)
- Surge of Light procs provide burst windows
- Holy Fire Weave optimizes HF's high damage-per-cast into tight windows
- Viable in guilds that already have a Shadow Priest for VT mana but want another shadow debuff maintainer

### Smite Strategies (priority order)
1. **ShadowWordPain** — if NOT active (reapply only when it falls off)
2. **Starshards** — if Night Elf + enabled + off CD
3. **DevouringPlague** — if Undead + enabled + off CD
4. **MindBlast** — if enabled + off CD (optional per setting)
5. **ShadowWordDeath** — if enabled + off CD + HP safe (optional per setting)
6. **SurgeOfLightSmite** — if Surge of Light proc active (instant free Smite)
7. **HolyFireWeave** — if HF off CD + SW:P in weave window
8. **HolyFire** — if off CD + not using weave mode (simple rotation type)
9. **Smite** — filler (2.0s cast)
10. **Trinkets / Racial** — off-GCD, use on CD

### State Tracking Needed
- `swp_active` — Shadow Word: Pain active on target (boolean)
- `swp_remaining` — SW:P remaining duration (for weave window calculation)
- `smite_cast_time` — current Smite cast time (haste-aware, base 2.0s with Divine Fury)
- `hf_cast_time` — current Holy Fire cast time (haste-aware, base 3.0s with Divine Fury)
- `hf_ready` — Holy Fire off cooldown (10s CD)
- `mb_ready` — Mind Blast off cooldown (if using MB)
- `swd_ready` — Shadow Word: Death off cooldown (if using SWD)
- `surge_of_light` — Surge of Light proc active (buff 33151)
- `in_weave_window` — swpRemaining > smiteCastTime AND swpRemaining < hfCastTime
- `player_hp_safe` — HP above SW:D threshold

---

## 4. Holy Priest Rotation & Strategies

### Core Mechanic: Reactive Healing + Proc Management
Holy Priest is a reactive healer that excels at group healing with Circle of Healing and single-target throughput with Greater Heal. Key procs to track:

**Surge of Light** (Holy talent):
- Buff ID: 33151
- 50% chance on any spell critical strike
- Next Smite becomes instant cast, costs no mana (cannot crit)
- Duration: 10 seconds
- Note: In TBC this affects Smite only, NOT Flash Heal

**Holy Concentration (Clearcasting)** (Holy talent):
- Buff ID: 34754
- Procs on critical heals
- Next Flash Heal, Binding Heal, or Greater Heal costs no mana
- Duration: 15 seconds
- Best used on Greater Heal for maximum mana savings

**Inspiration** (Holy talent):
- Buff ID: 15363
- Heal crits give target +25% armor for 15 seconds
- Passive, makes crit rating valuable for tank healing

### Single Target Healing Priority
```
Emergency (target < 30% HP):
1. Flash Heal spam (fastest throughput)
2. Inner Focus + Greater Heal if IF ready

Normal Healing:
1. Prayer of Mending on CD (best HPM, bouncing heal)
2. Clearcasting proc → Greater Heal (free heal)
3. Surge of Light proc → Smite (free damage, low priority)
4. Circle of Healing when 3+ party members damaged (if talented)
5. Renew on tank (maintain HoT)
6. Binding Heal when self + target both damaged
7. Greater Heal for sustained tank healing
8. Flash Heal for moderate urgency
9. Prayer of Healing when 3+ party members below threshold
10. Renew on injured targets without one
```

### Key Healing Decisions
- **Greater Heal vs Flash Heal**: GH when target has 2.5s before dying (bigger, more efficient). FH when urgent.
- **Prayer of Mending**: Always on CD on the tank. Most mana-efficient heal.
- **Circle of Healing**: Instant, 6s CD, heals 5 lowest HP targets. Use during group damage.
- **Binding Heal**: Use when both you AND your target are damaged — more efficient than healing separately.
- **Renew**: Maintain on tank. Apply to damaged targets during light-damage phases.
- **Prayer of Healing**: Only when 3+ party members are below AoE threshold HP%.
- **Lightwell**: Rarely used in raids (requires player interaction). Default off.

### Downranking (TBC)
TBC introduces a coefficient penalty for spells 20+ levels below character level:
- Greater Heal R4+ (level 48+) still efficient at 70
- Flash Heal R4+ (level 38+) usable
- Renew R7+ (level 44+) decent coefficients
- Rank selection: sorted tables, pick based on HP deficit + mana + overheal threshold

### State Tracking Needed
- `surge_of_light` — Surge of Light proc active
- `clearcasting` — Holy Concentration proc active
- `pom_on_cd` — Prayer of Mending cooldown check
- `coh_on_cd` — Circle of Healing cooldown check
- `lowest_target` — lowest HP party/raid member
- `tank_target` — designated tank
- `emergency_count` — number of targets below emergency HP%
- `group_damaged_count` — targets below AoE heal threshold
- `magic_debuff_target` — party member with dispellable magic debuff
- `disease_target` — party member with dispellable disease

---

## 5. Discipline Priest Rotation & Strategies

### Core Mechanic: Damage Prevention + Power Word: Shield
Discipline excels at preventing damage through PW:S and using cooldowns (Pain Suppression, Power Infusion) to support the raid.

**Weakened Soul** tracking:
- Debuff ID: 6788
- Applied when PW:S is cast on any target
- 15 second duration (always, regardless of shield rank)
- Prevents new PW:S until it expires
- MUST track on all shielded targets, especially the tank

**Pain Suppression** (41pt Disc talent):
- Spell ID: 33206
- Reduces target's damage taken by 40% for 8 seconds
- 5 min CD — THE defining Disc emergency cooldown
- Off-GCD

**Power Infusion** (Disc talent):
- Spell ID: 10060
- +20% spell haste for 15 seconds
- 3 min CD
- Can cast on self (healing throughput) or a DPS ally (raid DPS boost)
- Off-GCD

### Single Target Healing Priority
```
Emergency (target < 25% HP):
1. Pain Suppression on tank (off-GCD, if critically low)
2. Flash Heal spam
3. Inner Focus + Greater Heal

Normal Healing:
1. PW:S on tank (if no Weakened Soul)
2. Prayer of Mending on CD
3. Inner Focus + Greater Heal (free + 25% crit)
4. Power Infusion (self or DPS ally, off-GCD)
5. PW:S on non-tank targets without Weakened Soul
6. Renew on tank (maintain HoT)
7. Greater Heal for sustained healing
8. Flash Heal for moderate urgency
9. Renew on injured targets
10. Prayer of Healing for group damage
```

### Key Disc Decisions
- **PW:S priority**: Tank first, then anyone about to take damage. Track Weakened Soul to avoid wasting GCDs.
- **Pain Suppression**: Save for dangerous boss mechanics or tank near death. Off-GCD.
- **Power Infusion**: On self during heavy healing or on a top DPS during burn phases. Configurable target.
- **Inner Focus**: Always pair with Greater Heal (max mana savings + crit = Inspiration proc on tank).
- **Healing throughput**: Disc heals slightly less than Holy but prevents more damage. Shield first, heal second.

### State Tracking Needed
- `tank_weakened_soul` — Weakened Soul remaining on tank
- `tank_has_shield` — PW:S active on tank
- `shield_target` — next target eligible for PW:S (no Weakened Soul + injured)
- `inner_focus_ready` — Inner Focus off cooldown
- `pain_suppression_ready` — Pain Suppression off cooldown
- `power_infusion_ready` — Power Infusion off cooldown
- `lowest_target` — lowest HP party/raid member
- `tank_target` — designated tank
- `magic_debuff_target` — party member with dispellable magic debuff
- `disease_target` — party member with dispellable disease

---

## 6. AoE Rotation (All Specs)

### Shadow AoE
Shadow Priest has **extremely limited AoE** in TBC. Mind Sear does NOT exist (Wrath).
- **Multi-dot SW:P**: Tab-target SW:P on 3-4 targets for sustained multi-target damage
- **Multi-dot VT**: On 2-3 targets if they live long enough (1.5s cast per target)
- **Holy Nova**: Cannot use in Shadowform — requires dropping form (loses 15% damage, costs a GCD). Not worth it.
- **Practical AoE**: Multi-dot with SW:P, maintain VT on primary, Mind Flay primary. Shadow is a single-target specialist.

### Holy/Disc AoE Healing
Three primary AoE healing options:
1. **Circle of Healing** (Holy talent) — instant, 6s CD, heals 5 lowest HP targets in target's party
2. **Prayer of Healing** — 3.0s cast, heals entire party (5 members)
3. **Prayer of Mending** — bouncing heal, most mana-efficient
4. **Holy Nova** — instant PB AoE heal + damage, weak but instant and good during movement

### AoE Decision Matrix
```
Group damage (3+ members hurt):
  Holy: Circle of Healing → Prayer of Mending → Prayer of Healing
  Disc: Prayer of Mending → PW:S on most damaged → Prayer of Healing

Heavy group damage (3+ members < 50%):
  Holy: CoH on CD + Prayer of Healing + Flash Heal spam lowest
  Disc: PW:S rotation + Prayer of Healing + Flash Heal lowest

Movement:
  Holy: Circle of Healing + Renew + Holy Nova (if stacked)
  Disc: PW:S + Renew + Prayer of Mending
```

---

## 7. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Desperate Prayer** — instant self-heal, 10 min CD (Dwarf/Human racial)
   - Use when: HP critically low, faster than casting a heal on self
2. **Fade** — threat reduction for 10s, 30s CD
   - Use when: pulling healing aggro
3. **Power Word: Shield** on self — absorb incoming damage
   - Note: costs a Weakened Soul application on yourself
4. **Psychic Scream** — AoE fear, 30s CD
   - **Dangerous** in PvE (fears mobs into other groups). Default OFF.

### Dispel/Utility
1. **Dispel Magic** — remove 2 magic debuffs from a friendly target
   - Use `A.AuraIsValid(unit, "UseDispel", "Magic")` for smart filtering
2. **Abolish Disease** — remove diseases + ticking cleanse every 5s for 25s
   - Use `A.AuraIsValid(unit, "UseDispel", "Disease")` for smart filtering
3. **Mass Dispel** — AoE dispel, removes normally undispellable effects
   - Expensive (789 mana), situational. Default OFF.
4. **Fear Ward** — anti-fear buff on tank, 3 min CD, 10 min duration
   - Maintain on tank before fear mechanics
5. **Silence** — 5s silence on enemy caster, 45s CD (Shadow talent)
   - Use as interrupt for Shadow spec

### Self-Buffs (OOC)
1. **Inner Fire** — +1580 armor, 20 charges, 10 min duration. Always maintain.
2. **Power Word: Fortitude** / **Prayer of Fortitude** — stamina buff
3. **Divine Spirit** / **Prayer of Spirit** — spirit buff (Disc talent)
4. **Shadow Protection** / **Prayer of Shadow Protection** — shadow resist (optional)
5. **Shadowform** — Shadow spec toggle, always on during combat
6. **Fear Ward** — on tank before pulls with fear mechanics

---

## 8. Mana Management System

### Mana Recovery Priority (All Specs)
1. **Shadowfiend** — ~50% max mana over 15s, 5 min CD (biggest single recovery)
   - Use when below ~50% mana or on CD in long fights
   - Pet benefits from Heroism/Bloodlust haste (attacks faster = more mana)
2. **Inner Focus** — saves one spell's mana cost + 25% crit, 3 min CD
   - Best paired with Greater Heal or Mind Blast
3. **Super Mana Potion** — 1800-3000 mana, 2 min shared potion CD
4. **Dark Rune / Demonic Rune** — 900-1500 mana, costs 600-1000 HP (separate CD from potion)
   - VE healing covers HP cost for Shadow
   - Check HP threshold before using for healers
5. **Spirit-based regen** — stop casting between damage spikes (5-second rule)
   - Meditation (Disc 3/3): 30% of spirit regen continues while casting

### Shadow-Specific Mana
- **Vampiric Touch**: 5% of all shadow damage dealt returns as mana to the priest's party
- This is THE reason Shadow Priests are brought to TBC raids
- More damage = more mana return (positive feedback loop with gear)
- In early T4 gear, Shadow Priests can be mana-starved; by T6 they are self-sustaining
- **Spirit Tap** (talent): Killing blow grants 100% bonus Spirit + 50% mana regen continues while casting for 15s
  - Useful in 5-man content, rarely relevant in raids (bosses don't die to your SW:D)

### Healer-Specific Mana
- **Downranking**: Use lower-rank heals when full-rank would overheal significantly
  - TBC penalty: spells 20+ levels below character level get reduced +healing coefficient
  - Practical cutoff: rank learned at level 48+ still has good coefficient at 70
- **5-Second Rule (FSR)**: After casting, spirit regen pauses for 5 seconds
  - Meditation (Disc): 30% regen continues while casting
  - Holy Concentration: free spell does NOT restart the FSR timer
  - Strategy: stop casting between damage spikes to let spirit regen tick
- **Key Thresholds**:
  - Start conserving: ~30% mana (switch to efficient ranks)
  - Shadowfiend: ~50% mana
  - Mana Potion: ~50% mana
  - Dark Rune: ~50% mana (check HP threshold)

---

## 9. Cooldown Management

### Shadow Cooldown Priority
1. **Inner Focus + Mind Blast** — pair for free nuke + 25% crit, on CD
2. **Shadowfiend** — at ~50% mana, safe melee target available
3. **Trinkets** — use on CD, align with Heroism/Bloodlust
4. **Racial** (Berserking, Arcane Torrent, etc.) — use on CD

### Smite Cooldown Priority
1. **Holy Fire** — on CD, weave into rotation (10s CD)
2. **Shadowfiend** — at ~50% mana
3. **Trinkets** — use on CD, align with Heroism/Bloodlust
4. **Racial** (Berserking, Arcane Torrent, etc.) — use on CD

### Holy Cooldown Priority
1. **Inner Focus + Greater Heal** — pair for free big heal + 25% crit → Inspiration proc
2. **Shadowfiend** — at ~50% mana
3. **Trinkets** — pair with heavy healing phases
4. **Desperate Prayer** — emergency self-heal (racial)

### Discipline Cooldown Priority
1. **Pain Suppression** — save for dangerous boss mechanics (off-GCD)
2. **Inner Focus + Greater Heal** — pair for efficiency (off-GCD trigger)
3. **Power Infusion** — self during heavy healing OR ally DPS during burn (off-GCD)
4. **Shadowfiend** — at ~50% mana
5. **Trinkets** — pair with PI or heavy healing phases

---

## 10. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "shadow" | Spec | Active spec ("shadow", "smite", "holy", "discipline") |
| `use_inner_fire` | checkbox | true | Inner Fire | Maintain Inner Fire buff |
| `use_fortitude` | checkbox | true | PW: Fortitude | Maintain Fortitude buff OOC |
| `use_divine_spirit` | checkbox | true | Divine Spirit | Maintain Divine Spirit buff OOC (if talented) |
| `use_shadow_protection` | checkbox | false | Shadow Protection | Maintain Shadow Protection buff OOC |
| `use_fear_ward` | checkbox | true | Fear Ward | Maintain Fear Ward on tank |
| `auto_dispel_magic` | checkbox | true | Dispel Magic | Auto-dispel magic debuffs on party |
| `auto_abolish_disease` | checkbox | true | Abolish Disease | Auto-cleanse diseases on party |
| `use_mass_dispel` | checkbox | false | Mass Dispel | Use Mass Dispel (high mana cost) |
| `use_psychic_scream` | checkbox | false | Psychic Scream | Emergency fear (DANGEROUS in PvE) |
| `use_fade` | checkbox | true | Auto Fade | Use Fade when pulling threat |

### Tab 2: Shadow
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `shadow_use_swd` | checkbox | true | Shadow Word: Death | Use SW:D on cooldown (self-damage risk) |
| `shadow_swd_hp` | slider | 40 | SW:D Min HP% | Minimum player HP% to use SW:D (20-80) |
| `shadow_use_inner_focus` | checkbox | true | Use Inner Focus | Auto Inner Focus + Mind Blast |
| `shadow_use_starshards` | checkbox | true | Use Starshards | Use Starshards if Night Elf (off CD) |
| `shadow_use_devouring_plague` | checkbox | true | Devouring Plague | Use Devouring Plague if available (Undead) |
| `shadow_ve_maintain` | checkbox | true | Maintain VE | Auto-maintain Vampiric Embrace on target |
| `shadow_use_silence` | checkbox | true | Auto Silence | Interrupt enemy casts (if talented) |
| `shadow_multidot_swp` | checkbox | false | Multi-DoT SW:P | Tab-dot SW:P on nearby enemies |
| `shadow_multidot_count` | slider | 3 | Multi-DoT Max | Maximum targets for multi-dotting (2-5) |

### Tab 3: Smite
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `smite_use_mb` | checkbox | false | Use Mind Blast | Include Mind Blast in rotation (optional) |
| `smite_use_swd` | checkbox | false | Use Shadow Word: Death | Include SW:D in rotation (optional) |
| `smite_swd_hp` | slider | 40 | SW:D Min HP% | Minimum player HP% to use SW:D (20-80) |
| `smite_use_starshards` | checkbox | true | Use Starshards | Use Starshards if Night Elf (off CD) |
| `smite_use_devouring_plague` | checkbox | true | Use Devouring Plague | Use Devouring Plague if Undead (off CD) |
| `smite_holy_fire_weave` | checkbox | true | Holy Fire Weave | Weave Holy Fire based on SW:P timing window |

### Tab 4: Holy
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `holy_emergency_hp` | slider | 30 | Emergency HP% | Flash Heal spam below this HP% (10-60) |
| `holy_flash_heal_hp` | slider | 50 | Flash Heal HP% | Flash Heal below this%, Greater Heal above (20-80) |
| `holy_renew_hp` | slider | 90 | Renew HP% | Apply Renew when target below this% (50-100) |
| `holy_aoe_hp` | slider | 80 | AoE Heal HP% | AoE heals when members below this% (40-100) |
| `holy_aoe_count` | slider | 3 | AoE Heal Count | Minimum damaged members for AoE heal (2-5) |
| `holy_use_coh` | checkbox | true | Circle of Healing | Use CoH on CD during group damage (if talented) |
| `holy_use_binding_heal` | checkbox | true | Binding Heal | Use Binding Heal when self + target damaged |
| `holy_binding_self_hp` | slider | 80 | Binding Self HP% | Use Binding Heal when self HP below this% (40-95) |
| `holy_use_poh` | checkbox | true | Prayer of Healing | Use Prayer of Healing for group damage |
| `holy_use_holy_nova` | checkbox | false | Holy Nova | Use Holy Nova for instant AoE heal (weak) |
| `holy_downrank` | checkbox | true | Downrank Heals | Allow lower rank heals for mana efficiency |
| `holy_conserve_pct` | slider | 30 | Mana Conserve% | Use efficient heals below this mana% (10-60) |

### Tab 5: Discipline
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `disc_emergency_hp` | slider | 25 | Emergency HP% | Emergency heal below this HP% (10-50) |
| `disc_flash_heal_hp` | slider | 50 | Flash Heal HP% | Flash Heal below this%, Greater Heal above (20-80) |
| `disc_shield_hp` | slider | 90 | Shield HP% | Apply PW:S when target below this% (50-100) |
| `disc_shield_tank_only` | checkbox | false | Shield Tank Only | Only PW:S the tank |
| `disc_use_pain_suppression` | checkbox | true | Pain Suppression | Use PS on critical tank (if talented) |
| `disc_pain_suppression_hp` | slider | 20 | Pain Suppression HP% | PS below this HP% (10-40) |
| `disc_use_power_infusion` | checkbox | true | Power Infusion | Use Power Infusion (if talented) |
| `disc_pi_target` | dropdown | "self" | PI Target | Power Infusion target ("self", "focus") |
| `disc_use_inner_focus` | checkbox | true | Inner Focus | Use Inner Focus with Greater Heal |
| `disc_renew_hp` | slider | 85 | Renew HP% | Apply Renew below this% (50-100) |
| `disc_downrank` | checkbox | true | Downrank Heals | Allow lower rank heals for mana efficiency |
| `disc_conserve_pct` | slider | 25 | Mana Conserve% | Use efficient heals below this mana% (10-60) |

### Tab 6: Cooldowns & Mana
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Berserking/Arcane Torrent/etc.) |
| `use_shadowfiend` | checkbox | true | Use Shadowfiend | Auto-use Shadowfiend for mana |
| `shadowfiend_pct` | slider | 50 | Shadowfiend Mana% | Use when mana below this% (20-80) |
| `use_mana_potion` | checkbox | true | Use Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_pct` | slider | 50 | Mana Potion Below% | Mana potion trigger% (10-80) |
| `use_dark_rune` | checkbox | true | Use Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_pct` | slider | 50 | Dark Rune Below% | Dark Rune trigger% (10-80) |
| `dark_rune_min_hp` | slider | 50 | Dark Rune Min HP% | Don't use Dark Rune below this HP% (20-80) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% (10-60) |
| `healing_potion_hp` | slider | 25 | Healing Potion HP% | Use healing potion below this HP% (10-50) |
| `use_desperate_prayer` | checkbox | true | Desperate Prayer | Racial self-heal when HP low |
| `desperate_prayer_hp` | slider | 30 | Desperate Prayer HP% | Trigger HP% (10-50) |

---

## 11. Strategy Breakdown Per Playstyle

### Shadow Playstyle Strategies (priority order)
```
[1]  EnsureShadowform       — if not in Shadowform (OOC check)
[2]  VampiricEmbrace        — if missing on target (60s duration, reapply)
[3]  VampiricTouch          — if remaining <= cast time (haste-aware refresh)
[4]  ShadowWordPain         — if NOT active (reapply only when it falls off)
[5]  Starshards             — Night Elf + enabled + off CD (before MB/SWD!)
[6]  DevouringPlague        — Undead + enabled + off CD (before MB/SWD!)
[7]  InnerFocus             — off-GCD, fire immediately before MB (if both ready)
[8]  MindBlast              — on cooldown (5.5s CD)
[9]  ShadowWordDeath        — on CD if player HP > swd_hp setting
[10] Trinkets               — off-GCD, use on CD
[11] Racial                 — off-GCD, use on CD (Berserking, Arcane Torrent)
[12] MindFlay               — filler (1-3 ticks based on rotation type + CD timing)
```

### Smite Playstyle Strategies (priority order)
```
[1]  ShadowWordPain         — if NOT active (reapply when fallen off; Shadow Weaving + Misery)
[2]  Starshards             — Night Elf + enabled + off CD
[3]  DevouringPlague        — Undead + enabled + off CD
[4]  MindBlast              — if enabled + off CD (optional per setting)
[5]  ShadowWordDeath        — if enabled + off CD + HP safe (optional per setting)
[6]  SurgeOfLightSmite      — Surge of Light proc: instant free Smite
[7]  HolyFireWeave          — HF off CD + in weave window (swpRemaining > smiteCast && < hfCast)
[8]  HolyFire               — HF off CD, non-weave mode (simple rotation)
[9]  Smite                  — filler (2.0s cast with Divine Fury)
[10] Trinkets               — off-GCD, use on CD
[11] Racial                 — off-GCD, use on CD (Berserking, Arcane Torrent)
```

### Holy Playstyle Strategies (priority order)
```
[1]  PrayerOfMending         — instant, 10s CD, keep bouncing (best HPM)
[2]  SurgeOfLightSmite       — proc: instant free Smite (use if no healing needed)
[3]  CircleOfHealing         — instant, 6s CD, group_damaged >= threshold
[4]  EmergencyFlashHeal      — target below emergency_hp (spam FH)
[5]  BindingHeal             — self HP low + target HP low (heals both)
[6]  InnerFocusGreaterHeal   — IF ready: free GH + 25% crit (off-GCD trigger)
[7]  ClearcastingGreaterHeal — Holy Concentration proc: free GH
[8]  RenewTank               — maintain HoT on tank
[9]  RenewLow                — HoT on injured targets without one
[10] GreaterHeal             — primary sustained heal (target HP > flash_heal_hp)
[11] FlashHeal               — urgent heal (target HP < flash_heal_hp)
[12] PrayerOfHealing         — 3+ party members below aoe_hp
[13] HolyNova                — instant AoE heal (weak, movement, if enabled)
```

### Discipline Playstyle Strategies (priority order)
```
[1]  PainSuppression         — tank below pain_suppression_hp (off-GCD)
[2]  PowerWordShieldTank     — tank has no Weakened Soul
[3]  PrayerOfMending         — instant, 10s CD, keep bouncing
[4]  InnerFocusGreaterHeal   — IF ready: free GH + 25% crit (off-GCD trigger)
[5]  PowerInfusion           — off-GCD, self or focus target
[6]  EmergencyFlashHeal      — target below emergency_hp
[7]  PowerWordShieldOthers   — PW:S on non-tank without Weakened Soul (if not tank-only)
[8]  RenewTank               — maintain HoT on tank
[9]  GreaterHeal             — sustained tank healing
[10] FlashHeal               — moderate urgency
[11] RenewLow                — HoT on injured targets
[12] PrayerOfHealing         — group damage response
```

### Shared Middleware (all specs)
```
[MW-500]  DesperatePrayer     — racial emergency self-heal at critical HP
[MW-450]  Fade                — threat reduction when aggro pulled
[MW-400]  FearWard            — maintain on tank OOC/between pulls
[MW-350]  DispelMagic         — dispel magic debuffs on party members
[MW-340]  AbolishDisease      — cleanse diseases on party members
[MW-300]  RecoveryItems       — healthstone, healing potion (self HP low)
[MW-290]  Shadowfiend         — mana recovery (mana below threshold)
[MW-280]  ManaPotion          — Super Mana Potion
[MW-275]  DarkRune            — Dark/Demonic Rune (check HP threshold)
[MW-150]  SelfBuffInnerFire   — maintain Inner Fire
[MW-145]  SelfBuffFortitude   — maintain PW:Fortitude OOC
[MW-140]  SelfBuffDivineSpirit — maintain Divine Spirit OOC (if talented)
[MW-135]  SelfBuffShadowProt  — maintain Shadow Protection OOC (if enabled)
```

---

## Key Implementation Notes

### Playstyle Detection
Priest has NO stances/forms for Holy/Disc (unlike Druid). Shadow has Shadowform but it's a toggle, not a WoW stance. Playstyle must be determined by user setting (dropdown: "shadow", "smite", "holy", "discipline").

```lua
get_active_playstyle = function(context)
    return context.settings.playstyle or "shadow"
end,
idle_playstyle_name = nil,
get_idle_playstyle = nil,
```

### No Idle Playstyle
Unlike Druid's "caster" idle form, Priest doesn't shift forms. OOC behavior (buffs, Inner Fire) handled via middleware with `requires_combat = false`.

### extend_context Fields
```lua
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime() or 0
ctx.in_shadowform = (Unit("player"):HasBuffs(15473) or 0) > 0
ctx.has_inner_focus = (Unit("player"):HasBuffs(14751) or 0) > 0
ctx.has_power_infusion = (Unit("player"):HasBuffs(10060) or 0) > 0
ctx.has_surge_of_light = (Unit("player"):HasBuffs(33151) or 0) > 0
ctx.has_clearcasting = (Unit("player"):HasBuffs(34754) or 0) > 0
ctx.has_inner_fire = (Unit("player"):HasBuffs(25431) or 0) > 0
ctx.enemy_count = A.MultiUnits:GetByRange(30) or 1

-- Cache invalidation for per-playstyle builders
ctx._shadow_valid = false
ctx._smite_valid = false
ctx._holy_valid = false
ctx._disc_valid = false
```

### Shadow State (context_builder)
```lua
local shadow_state = {
    vt_remaining = 0,
    swp_active = false,
    swp_remaining = 0,
    ve_remaining = 0,
    shadow_weaving_stacks = 0,
    mb_ready = false,
    swd_ready = false,
    mb_cd_remaining = 0,
    swd_cd_remaining = 0,
    swd_safe = false,
    inner_focus_ready = false,
}

local function get_shadow_state(context)
    if context._shadow_valid then return shadow_state end
    context._shadow_valid = true

    shadow_state.vt_remaining = Unit(TARGET_UNIT):HasDeBuffs(34917, "player", true) or 0
    local swp_dur = Unit(TARGET_UNIT):HasDeBuffs(25368, "player", true) or 0
    shadow_state.swp_active = swp_dur > 0
    shadow_state.swp_remaining = swp_dur
    shadow_state.ve_remaining = Unit(TARGET_UNIT):HasDeBuffs(15290, "player", true) or 0
    shadow_state.shadow_weaving_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(15258) or 0
    shadow_state.mb_ready = A.MindBlast:IsReady(TARGET_UNIT)
    shadow_state.swd_ready = A.ShadowWordDeath:IsReady(TARGET_UNIT)
    shadow_state.mb_cd_remaining = A.MindBlast:GetCooldown() or 0
    shadow_state.swd_cd_remaining = A.ShadowWordDeath:GetCooldown() or 0
    shadow_state.swd_safe = context.hp > (context.settings.shadow_swd_hp or 40)
    shadow_state.inner_focus_ready = A.InnerFocus:IsReady(PLAYER_UNIT)

    return shadow_state
end
```

### Smite State (context_builder)
```lua
local smite_state = {
    swp_active = false,
    swp_remaining = 0,
    smite_cast_time = 2.0,
    hf_cast_time = 3.0,
    hf_ready = false,
    mb_ready = false,
    swd_ready = false,
    swd_safe = false,
    surge_of_light = false,
    in_weave_window = false,
}

local function get_smite_state(context)
    if context._smite_valid then return smite_state end
    context._smite_valid = true

    local swp_dur = Unit(TARGET_UNIT):HasDeBuffs(25368, "player", true) or 0
    smite_state.swp_active = swp_dur > 0
    smite_state.swp_remaining = swp_dur
    smite_state.surge_of_light = context.has_surge_of_light

    -- Haste-aware cast times (framework provides ApplyCastSpeed or similar)
    -- Base: Smite 2.0s (with Divine Fury), Holy Fire 3.0s (with Divine Fury)
    smite_state.smite_cast_time = 2.0  -- TODO: apply haste
    smite_state.hf_cast_time = 3.0     -- TODO: apply haste

    smite_state.hf_ready = A.HolyFire:IsReady(TARGET_UNIT)
    smite_state.mb_ready = A.MindBlast:IsReady(TARGET_UNIT)
    smite_state.swd_ready = A.ShadowWordDeath:IsReady(TARGET_UNIT)
    smite_state.swd_safe = context.hp > (context.settings.smite_swd_hp or 40)

    -- Holy Fire Weave window: swpRemaining > smiteCastTime AND swpRemaining < hfCastTime
    smite_state.in_weave_window = smite_state.swp_active
        and swp_dur > smite_state.smite_cast_time
        and swp_dur < smite_state.hf_cast_time

    return smite_state
end
```

### Holy State (context_builder)
```lua
local holy_state = {
    lowest = nil,
    tank = nil,
    emergency_count = 0,
    group_damaged_count = 0,
    surge_of_light_active = false,
    clearcasting_active = false,
    pom_on_cd = false,
    coh_on_cd = false,
    magic_debuff_target = nil,
    disease_target = nil,
}

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    holy_state.surge_of_light_active = context.has_surge_of_light
    holy_state.clearcasting_active = context.has_clearcasting
    holy_state.pom_on_cd = (A.PrayerOfMending:GetCooldown() or 0) > 1.5
    holy_state.coh_on_cd = (A.CircleOfHealing:GetCooldown() or 0) > 1.5
    holy_state.lowest = nil
    holy_state.tank = nil
    holy_state.emergency_count = 0
    holy_state.group_damaged_count = 0
    holy_state.magic_debuff_target = nil
    holy_state.disease_target = nil

    -- Scan healing targets (reuse shared scanning utility)
    -- ... populate lowest, tank, counts, dispel targets

    return holy_state
end
```

### Disc State (context_builder)
```lua
local disc_state = {
    lowest = nil,
    tank = nil,
    emergency_count = 0,
    tank_weakened_soul = 0,
    tank_has_shield = false,
    shield_target = nil,
    inner_focus_ready = false,
    pain_suppression_ready = false,
    power_infusion_ready = false,
    magic_debuff_target = nil,
    disease_target = nil,
}

local function get_disc_state(context)
    if context._disc_valid then return disc_state end
    context._disc_valid = true

    disc_state.inner_focus_ready = (A.InnerFocus:GetCooldown() or 0) < 0.5
    disc_state.pain_suppression_ready = (A.PainSuppression:GetCooldown() or 0) < 0.5
    disc_state.power_infusion_ready = (A.PowerInfusion:GetCooldown() or 0) < 0.5
    disc_state.lowest = nil
    disc_state.tank = nil
    disc_state.emergency_count = 0
    disc_state.tank_weakened_soul = 0
    disc_state.tank_has_shield = false
    disc_state.shield_target = nil
    disc_state.magic_debuff_target = nil
    disc_state.disease_target = nil

    -- Scan healing targets, check Weakened Soul on tank, etc.
    -- ... populate state fields

    return disc_state
end
```

### Greater Heal Rank Chain (for downranking)
```lua
-- Greater Heal ranks for downranking system
-- R7=25213, R6=25210, R5=25314, R4=10965, R3=10964, R2=10963, R1=2060
local GREATER_HEAL_RANKS = {
    { id = 25213, level = 68 },  -- R7
    { id = 25210, level = 63 },  -- R6
    { id = 25314, level = 60 },  -- R5
    { id = 10965, level = 54 },  -- R4
    { id = 10964, level = 48 },  -- R3 (good coefficient at 70)
    { id = 10963, level = 44 },  -- R2
    { id = 2060,  level = 40 },  -- R1 (penalized at 70)
}
```

### Healing Target Scanning
Both Holy and Disc need a party/raid scanning utility similar to Druid's `healing.lua`. Key considerations:
- Scan party/raid for lowest HP members
- Identify tank(s) — by role or focus target
- Count members below emergency/AoE thresholds
- Check for dispellable debuffs (magic, disease)
- Pre-allocate scan results table (no inline `{}` in combat)

### Class Color for Settings UI
In `rotation/source/aio/settings.lua` CLASS_TITLE_COLORS:
```lua
Priest = "ffffff"  -- White (standard WoW Priest class color)
```
