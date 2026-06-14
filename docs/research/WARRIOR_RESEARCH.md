# TBC Warrior Implementation Research

Comprehensive research for implementing Arms, Fury, and Protection Warrior playstyles.
Sources: wowsims/tbc simulator (Go source: dps/rotation.go, dps/dps_warrior.go, heroic_strike_cleave.go, execute.go, slam.go, overpower.go, bloodthirst.go, mortal_strike.go, whirlwind.go, shield_slam.go, rampage.go, deep_wounds.go, talents.go), Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Arms Warrior Rotation & Strategies](#2-arms-warrior-rotation--strategies)
3. [Fury Warrior Rotation & Strategies](#3-fury-warrior-rotation--strategies)
4. [Protection Warrior Rotation & Strategies](#4-protection-warrior-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Rage Management System](#7-rage-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Proposed Settings Schema](#9-proposed-settings-schema)
10. [Strategy Breakdown Per Playstyle](#10-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Core Damage Spells
| Spell | ID | Cast Time | Rage | Notes |
|-------|------|-----------|------|-------|
| Heroic Strike (R10) | 29707 | Next swing | 15 | On-next-attack, NOT on GCD, rage dump |
| Cleave (R6) | 25231 | Next swing | 20 | On-next-attack, hits 2 targets |
| Mortal Strike (R6) | 30330 | Instant | 30 | Arms talent, 6s CD, -50% healing debuff |
| Bloodthirst (R4) | 30335 | Instant | 30 | Fury talent, 6s CD, 45% AP as damage |
| Whirlwind | 1680 | Instant | 25 | 10s CD (8s w/ Improved WW), Berserker Stance |
| Execute (R7) | 25236 | Instant | 15 (+extra) | <20% HP target, converts excess rage to damage |
| Overpower (R4) | 11585 | Instant | 5 | 5s CD, requires dodge, Battle Stance |
| Slam (R6) | 25242 | 1.5s cast | 15 | 0.5s w/ Improved Slam talent |
| Revenge (R8) | 30357 | Instant | 5 | 5s CD, requires block/dodge/parry, Defensive |
| Shield Slam (R6) | 30356 | Instant | 20 | Prot talent, 6s CD, dispels 1 magic buff |
| Devastate (R3) | 30022 | Instant | 15 | Prot 41-point talent, applies Sunder + weapon dmg |
| Thunder Clap (R7) | 25264 | Instant | 20 | 4s CD, AoE attack speed debuff, Battle Stance |
| Victory Rush | 34428 | Instant | 0 | Free after honor/XP kill, 20s window, Battle Stance |

### Shouts
| Spell | ID | Duration | Rage | Notes |
|-------|------|----------|------|-------|
| Battle Shout (R7) | 2048 | 2 min | 10 | +305 AP to party |
| Commanding Shout (R1) | 469 | 2 min | 10 | +1080 HP to party (TBC ability) |
| Demoralizing Shout (R7) | 25203 | 30s | 10 | -300 AP on enemies |
| Intimidating Shout | 5246 | 8s | 25 | AoE fear, 3 min CD |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Heroic Strike | 78 | 29707 (R10) | |
| Cleave | 845 | 25231 (R6) | |
| Mortal Strike | 12294 | 30330 (R6) | Arms talent |
| Bloodthirst | 23881 | 30335 (R4) | Fury talent |
| Execute | 5308 | 25236 (R7) | |
| Overpower | 7384 | 11585 (R4) | |
| Slam | 1464 | 25242 (R6) | |
| Revenge | 6572 | 30357 (R8) | |
| Shield Slam | 23922 | 30356 (R6) | Prot talent |
| Devastate | 20243 | 30022 (R3) | Prot 41-point talent |
| Thunder Clap | 6343 | 25264 (R7) | |
| Rend | 772 | 25208 (R9) | |
| Hamstring | 1715 | 25212 (R4) | |
| Sunder Armor | 7386 | 25225 (R6) | |
| Battle Shout | 6673 | 2048 (R7) | |
| Commanding Shout | 469 | 469 (R1) | TBC, single rank |
| Demoralizing Shout | 1160 | 25203 (R7) | |
| Shield Bash | 72 | 29704 (R4) | |
| Mocking Blow | 694 | 25266 (R6) | |
| Charge | 100 | 11578 (R3) | |
| Intercept | 20252 | 25275 (R5) | |
| Rampage | 29801 | 30033 (R3) | Fury 41-point talent |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Whirlwind | 1680 | Single rank |
| Victory Rush | 34428 | TBC ability, single rank |
| Taunt | 355 | |
| Bloodrage | 2687 | HP cost, generates rage |
| Berserker Rage | 18499 | Fear immune, rage gen if talented |
| Death Wish | 12292 | Arms/Fury talent, +20% damage |
| Sweeping Strikes | 12328 | Arms talent |
| Shield Block | 2565 | |
| Shield Wall | 871 | 75% DR, 30 min CD |
| Spell Reflection | 23920 | TBC ability, requires shield |
| Intervene | 3411 | TBC ability, party protection |
| Last Stand | 12975 | Prot talent |
| Recklessness | 1719 | +100% crit, 30 min CD |
| Disarm | 676 | |
| Intimidating Shout | 5246 | AoE fear |
| Pummel | 6552 | Berserker Stance interrupt |

### Stance Spell IDs (for stance switching)
| Stance | ID | Notes |
|--------|------|-------|
| Battle Stance | 2457 | GetStance() returns 1 |
| Defensive Stance | 71 | GetStance() returns 2 |
| Berserker Stance | 2458 | GetStance() returns 3 |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Death Wish | 12292 | 3 min | 30s | +20% damage, immune to Fear, +5% dmg taken |
| Recklessness | 1719 | 30 min | 15s | +100% crit chance, Berserker Stance |
| Shield Wall | 871 | 30 min | 10s | 75% damage reduction, Defensive Stance |
| Last Stand | 12975 | 10 min | 20s | +30% max HP, Prot talent |
| Retaliation | 20230 | 30 min | 15s | Counter-attack melee hits, Battle Stance |
| Sweeping Strikes | 12328 | 30s | 5 attacks | Next 5 melee attacks cleave, Arms talent |
| Bloodrage | 2687 | 1 min | 10s | Generates 10 rage + 10 over time, costs HP |
| Berserker Rage | 18499 | 30s | 10s | Fear/Sap/Incap immune, rage gen if talented |
| Intimidating Shout | 5246 | 3 min | 8s | AoE fear |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Shield Block | 2565 | 5s | Block next 1-2 attacks (talent) in 5s, Defensive |
| Shield Wall | 871 | 30 min | 75% DR for 10s, Defensive Stance |
| Last Stand | 12975 | 10 min | +30% max HP for 20s, Prot talent |
| Spell Reflection | 23920 | 10s | Reflect next spell, 5s duration, requires shield |
| Shield Bash (R4) | 29704 | 12s | Interrupt + 6s lockout, Defensive, requires shield |
| Pummel | 6552 | 10s | Interrupt, Berserker Stance |
| Disarm | 676 | 1 min | 10s disarm, Defensive Stance |
| Intervene | 3411 | 30s | Charge to ally, intercept next hit, Defensive |
| Charge (R3) | 11578 | 15s | OOC only, Battle Stance, generates 15 rage |
| Intercept (R5) | 25275 | 25-30s | In-combat charge + stun, Berserker Stance |
| Taunt | 355 | 10s | Force target to attack you, Defensive Stance |
| Mocking Blow (R6) | 25266 | 2 min | 6s taunt, Battle Stance |

### Self-Buffs / Shouts
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Battle Shout (R7) | 2048 | 2 min | +305 AP to party |
| Commanding Shout (R1) | 469 | 2 min | +1080 HP to party |
| Berserker Rage | 18499 | 10s | Fear immune, generates rage if talented |
| Death Wish | 12292 | 30s | +20% damage, talent |
| Recklessness | 1719 | 15s | +100% crit chance |

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Orc | Blood Fury | 20572 | +AP for 15s, -healing received, 2 min CD |
| Troll | Berserking | 26296 | 10-30% attack speed for 10s, 3 min CD |
| Tauren | War Stomp | 20549 | AoE stun 2s, 2 min CD |
| Undead | Will of the Forsaken | 7744 | Remove charm/fear/sleep |
| Human | Perception | 20600 | +stealth detection (PvP utility) |
| Gnome | Escape Artist | 20589 | Remove root/snare |
| Dwarf | Stoneform | 20594 | Remove poison/disease/bleed, +10% armor |
| Night Elf | Shadowmeld | 20580 | Stealth while stationary (OOC only) |
| Draenei | Gift of the Naaru | 28880 | HoT heal |

Note: Blood Elf cannot be Warrior in TBC.

### Debuff IDs (for tracking)
| Debuff | ID | Notes |
|--------|------|-------|
| Mortal Strike healing debuff | 12294 | -50% healing received (use base ID for detection) |
| Sunder Armor debuff | 25225 | Stacks to 5, -520 armor each (max rank ID) |
| Thunder Clap debuff | 25264 | -10% attack speed |
| Demoralizing Shout debuff | 25203 | -300 AP on enemies |
| Rend debuff | 25208 | Bleed DoT, 15s |
| Hamstring debuff | 25212 | 60% slow |
| Blood Frenzy debuff | 29859 | +4% physical damage taken (Arms talent) |
| Deep Wounds debuff | 12867 | Bleed on crit: 20% weapon avg dmg × rank, 12s (4 ticks @ 3s) |

### Buff IDs (for tracking)
| Buff | ID | Notes |
|------|------|-------|
| Battle Shout buff | 2048 | +305 AP active (max rank) |
| Commanding Shout buff | 469 | +1080 HP active |
| Rampage buff | 30033 | +50 AP/stack (max 5), 30s, Fury 41-point talent |
| Flurry buff | 12974 | +25% attack speed for 3 swings (Fury talent, max rank) |
| Enrage buff | 14202 | +25% damage after being crit (Fury talent, max rank) |
| Death Wish buff | 12292 | +20% damage active |
| Sweeping Strikes buff | 12328 | Next 5 attacks cleave |
| Berserker Rage buff | 18499 | Fear immune active |
| Recklessness buff | 1719 | +100% crit active |
| Shield Block buff | 2565 | Blocking next attacks |
| Last Stand buff | 12975 | +30% max HP active |
| Spell Reflection buff | 23920 | Reflecting next spell |
| Bloodrage buff | 29131 | Generating rage over time (the periodic effect) |
| Sword Specialization proc | 12815 | Extra attack proc (Arms talent) |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Ironshield Potion | 22849 | +2500 armor for 2 min |
| Haste Potion | 22838 | +400 haste rating for 15s |
| Insane Strength Potion | 22828 | +120 strength for 15s |
| Destruction Potion | 22839 | +120 SP +2% spell crit (NOT useful for Warriors) |
| Healthstone (Master) | 22105 | ~2496 HP, warlock conjured |

Note: Warriors don't use mana potions or Dark Runes. Consumable focus is healing potions, armor potions (tanking), and haste/strength potions (DPS).

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+):
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Titan's Grip | Wrath (3.0) | Fury dual-wield 2H weapons — does NOT exist |
| Bladestorm | Wrath (3.0) | Arms 51-point talent — does NOT exist |
| Shockwave | Wrath (3.0) | Prot 51-point cone stun — does NOT exist |
| Heroic Throw | Wrath (3.0) | Ranged throw ability — does NOT exist |
| Enraged Regeneration | Wrath (3.0) | Self-heal using Enrage — does NOT exist |
| Shattering Throw | Wrath (3.0) | Ranged anti-immunity — does NOT exist |
| Warbringer | Wrath (3.0) | Charge in any stance — does NOT exist |
| Juggernaut | Wrath (3.0) | Charge in combat — does NOT exist |
| Sudden Death | Wrath (3.0) | Execute procs — does NOT exist |
| Taste for Blood | Wrath (3.0) | Overpower procs from Rend — does NOT exist |
| Sword and Board | Wrath (3.0) | Shield Slam procs — does NOT exist |
| Vigilance | Wrath (3.0) | Threat transfer talent — does NOT exist |
| Damage Shield | Wrath (3.0) | Reflect damage talent — does NOT exist |
| Bloodthirst healing | Wrath (3.0) | BT does NOT heal in TBC |

**What IS new in TBC (vs Classic):**
- Spell Reflection (level 64 trained)
- Intervene (level 70 trained)
- Victory Rush (level 62 trained)
- Commanding Shout (level 68 trained)
- Devastate (Prot 41-point talent)
- Rampage (Fury 41-point talent)
- Endless Rage (Arms 41-point talent, passive)

**Critical TBC differences from Wrath:**
- Shield Wall = 75% DR, **30 min CD** (Wrath: 60% DR, 5 min CD)
- Recklessness = +100% crit, **30 min CD** (Wrath: 5 min CD)
- Charge = Battle Stance + out-of-combat ONLY (no Warbringer)
- Thunder Clap = Battle Stance ONLY (Wrath: any stance)
- Sunder Armor = Defensive Stance ONLY (Wrath: any stance)
- Bloodthirst does NOT heal (Wrath added 0.5% max HP heal)
- Talent trees max 41 points (Wrath: 51 points)
- Crushing blows exist on bosses (removed in Wrath)

---

## 2. Arms Warrior Rotation & Strategies

### Core Mechanic: Mortal Strike + Stance Dancing
Arms is the most mechanically complex Warrior spec due to stance-dependent abilities:
- **Mortal Strike** (any stance) — primary damage ability, 6s CD
- **Overpower** (Battle Stance only) — procs on target dodge, 5s CD, very high damage/rage
- **Whirlwind** (Berserker Stance only) — strong AoE/ST hit, 10s CD
- **Slam** (any stance) — filler between MS/WW/OP, 0.5s cast with Improved Slam

### Stance Dancing
Arms Warriors constantly swap between Battle and Berserker Stances:
- **Battle Stance**: For Overpower procs and Thunder Clap
- **Berserker Stance**: For Whirlwind and +3% crit
- **Tactical Mastery talent**: Retains up to 25 rage on stance swap (critical)
- Without Tactical Mastery, ALL rage is lost on swap

### Single Target Rotation
From wowsims and TBC Classic guides:
1. **Maintain Rend** (if Blood Frenzy talented — +4% physical damage for raid)
2. **Mortal Strike** on CD (6s, highest priority damage ability)
3. **Overpower** when available (after target dodge, switch to Battle if in Berserker)
4. **Whirlwind** on CD (switch to Berserker if in Battle)
5. **Slam** as filler (with Improved Slam: 0.5s cast, fits between auto-attacks)
6. **Execute** at <20% target HP (converts all extra rage into damage)
7. **Heroic Strike** as rage dump (>50+ rage, careful not to starve MS/WW)

### Slam Weaving
With Improved Slam (2/2), Slam has a 0.5s cast time. The technique:
- After an auto-attack lands, immediately Slam (0.5s cast)
- This fits between auto-attack swings without significantly delaying the next swing
- Only worth it with sufficient rage and between other ability cooldowns
- Stop Slam weaving when rage-starved or MS/WW coming off CD

### Execute Phase (<20% HP)
```
1. Execute (dump all rage into it)
2. Mortal Strike on CD (still higher priority if rage is limited)
3. More Execute
4. Heroic Strike queue if rage is overflowing (>80+)
```

### Arms State Tracking Needed
- `rend_active` — Rend debuff on target (for Blood Frenzy)
- `rend_duration` — remaining Rend duration
- `overpower_available` — target recently dodged (Overpower usable)
- `ms_cd` — Mortal Strike cooldown remaining
- `ww_cd` — Whirlwind cooldown remaining
- `target_below_20` — Execute phase check
- `slam_enabled` — Is Improved Slam talented (worth using)

---

## 3. Fury Warrior Rotation & Strategies

### Core Mechanic: Bloodthirst + Whirlwind + Rage Dumping
Fury is the simpler DPS spec. Lives primarily in Berserker Stance for +3% crit and Whirlwind access.

### Key Mechanics
- **Bloodthirst** (any stance): 45% AP as damage, 6s CD. Does NOT heal in TBC.
- **Whirlwind** (Berserker only): AoE melee, 10s CD (8s with Improved WW)
- **Rampage** (Fury 41-point, ID 30033): After melee crit, 5s window to activate. +50 AP per stack (max 5), 30s duration, 20 rage cost. Refresh when stacks < 5 or duration low.
- **Flurry** (talent): +25% attack speed for 3 swings after crit, maintains itself with dual-wield crits
- **Heroic Strike**: On-next-attack rage dump, NOT on GCD — queue it constantly when rage allows

### Dual Wield and Hit Rating
- TBC dual-wield has 19% miss penalty on off-hand (24% base miss vs boss)
- Hit cap for special attacks (Bloodthirst/WW): 9% (142 hit rating)
- Soft cap for dual-wield white hits: ~28% (additional hit beyond 9% helps)
- Precision talent (+3% hit) is critical

### Heroic Strike Queuing (Critical Mechanic)
Heroic Strike is NOT on the GCD. It replaces the next auto-attack:
- **Queue HS when rage > threshold** (~50-60 rage)
- **Cancel HS queue if rage drops** (avoid rage-starving BT/WW)
- HS removes the off-hand miss penalty for that swing (bug/feature in TBC)
- This makes HS queuing a DPS increase even ignoring the HS damage itself

### Single Target Rotation
From wowsims `normalRotation()`:
1. **Rampage** (maintain buff — if crit in last 5s AND stacks < 5 or duration low)
2. **Whirlwind** on CD (if PrioritizeWw enabled, before BT)
3. **Bloodthirst** on CD (6s, highest non-Rampage priority)
4. **Whirlwind** on CD (if PrioritizeWw disabled, after BT)
5. **Slam** as filler during auto-attack window (if Improved Slam 2/2)
6. **Overpower** on dodge proc (if enabled, rage ≥ threshold)
7. **Heroic Strike** queue as rage dump (when rage ≥ HsRageThreshold)
8. **Hamstring** — weave for Sword Spec procs (optional, rage ≥ threshold)

### Standard Rotation Cycle
```
BT → WW → BT → HS/wait → repeat
     (6s)  (10s)  (6s)

With Improved WW (8s CD):
BT → WW → BT → WW → BT → ...
```

### Execute Phase (<20% HP)
From wowsims `executeRotation()`:
```
1. Rampage (maintain buff even during execute)
2. Bloodthirst on CD (if UseBtDuringExecute)
3. Whirlwind on CD (if UseWwDuringExecute)
4. Execute (dump all rage — 925 + 21 × extraRage)
5. Heroic Strike ONLY if UseHsDuringExecute enabled (usually disabled)
```

### Fury State Tracking Needed
- `bt_cd` — Bloodthirst cooldown remaining
- `ww_cd` — Whirlwind cooldown remaining
- `rampage_active` — Rampage buff up
- `rampage_duration` — Rampage duration remaining
- `flurry_stacks` — Flurry buff stacks (3 swings)
- `target_below_20` — Execute phase check
- `hs_queued` — Heroic Strike is queued on next swing

---

## 4. Protection Warrior Rotation & Strategies

### Core Mechanic: Threat Priority + Shield Block Uptime
Protection is about maximizing threat-per-second (TPS) while maintaining survivability.

### Defensive Stance Threat Modifier
- Defensive Stance: +130% threat (1.3x multiplier)
- Combined with Defiance talent (+15%): effective ~1.495x threat multiplier
- Revenge has massive innate threat, making it highest TPS-per-rage

### Crushing Blow Prevention (TBC-Specific)
- Level 73 bosses (raid bosses) can land crushing blows (+50% damage)
- Shield Block pushes crushes off the attack table when combined with avoidance+block
- **Shield Block uptime is critical** on boss fights
- Shield Block: 5s duration, 5s CD → can maintain 100% uptime
- With Improved Shield Block: blocks 1 additional attack (2 total per Shield Block)

### Single Target Threat Rotation
From wowsims and TBC Protection guides:
1. **Shield Slam** on CD (highest single-target threat per use, 6s CD)
2. **Revenge** when available (proc-based: requires block/dodge/parry, highest threat/rage)
3. **Devastate** filler (applies/refreshes Sunder Armor + weapon damage, Prot talent)
4. **Sunder Armor** (if Devastate not talented, to build/maintain 5 stacks)
5. **Shield Block** on CD (crush prevention + Revenge proc enabler)
6. **Thunder Clap** debuff maintenance (requires Battle Stance swap!)
7. **Demoralizing Shout** if AP debuff not covered by another source
8. **Heroic Strike** as rage dump (only when rage > 60+, threat filler)

### Stance Swapping for Prot
Protection Warriors occasionally swap to Battle Stance for:
- **Thunder Clap** — attack speed debuff, important for damage reduction
- **Spell Reflection** — can also be used in Defensive Stance (requires shield)
- Swap back to Defensive immediately

### Shield Block Usage
```
On boss fights:
- Shield Block on CD (5s/5s — maintain 100% uptime)
- This is THE reason tanks can survive bosses in TBC

On trash:
- Less critical, use when expecting heavy damage
- Save rage for threat abilities if threat is an issue
```

### Prot State Tracking Needed
- `shield_slam_cd` — Shield Slam cooldown remaining
- `revenge_available` — Revenge proc active
- `sunder_stacks` — Sunder Armor stacks on target (0-5)
- `sunder_duration` — Sunder Armor duration remaining
- `shield_block_active` — Shield Block buff up
- `shield_block_cd` — Shield Block cooldown remaining
- `thunder_clap_debuff` — Thunder Clap debuff on target
- `demo_shout_debuff` — Demoralizing Shout debuff on target
- `has_shield` — Shield equipped check

---

## 5. AoE Rotation (All Specs)

### Arms AoE
1. **Sweeping Strikes** (Battle Stance, 30s CD) — next 5 melee attacks hit an additional target
2. Switch to Berserker → **Whirlwind** — with Sweeping Strikes up, massive AoE
3. **Thunder Clap** (Battle Stance) — AoE attack speed debuff
4. **Cleave** as rage dump instead of Heroic Strike (hits 2 targets)

### Fury AoE
1. **Whirlwind** on CD (Berserker Stance) — hits up to 4 targets
2. **Cleave** instead of Heroic Strike (2 targets, on-next-swing)
3. **Bloodthirst** on CD (single target but still highest priority)
4. Tab-target and maintain threat

### Protection AoE (AoE Tanking)
1. **Thunder Clap** (requires Battle Stance swap) — AoE slow + threat
2. **Demoralizing Shout** — AoE threat baseline
3. **Cleave** as rage dump (hits 2 targets, more AoE threat than HS)
4. **Devastate/Sunder** — tab-target to spread threat
5. **Revenge** when available — high threat even on single
6. **Shield Block** — maintain for survival
7. **Challenging Shout** (3 min CD) — AoE taunt emergency

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Last Stand** — +30% max HP for 20s (Prot talent, 10 min CD)
   - Use when: HP critically low, about to die
2. **Shield Wall** — 75% DR for 10s (30 min CD, Defensive Stance)
   - Use when: major damage incoming, tank buster mechanic
3. **Spell Reflection** — reflect next spell (10s CD, requires shield)
   - Use when: dangerous spell incoming, proactive defense
4. **Intimidating Shout** — AoE fear (3 min CD, emergency CC)

### Interrupts
1. **Pummel** — 10s CD, Berserker Stance
2. **Shield Bash** — 12s CD, Defensive Stance, requires shield
Note: Stance requirement means interrupt availability depends on current stance

### Utility
1. **Hamstring** — movement slow (10 rage, any stance)
2. **Disarm** — disarm target weapon (1 min CD, Defensive Stance)

### Self-Buff Maintenance (OOC)
1. **Battle Shout** — +305 AP (maintain at all times)
2. **Commanding Shout** — +1080 HP (alternative to Battle Shout)

---

## 7. Rage Management System

### Rage Generation
Warriors generate rage from:
1. **Damage dealt** (white hits, scaled by weapon damage and speed)
2. **Damage taken** (flat amount per hit received)
3. **Bloodrage** — 10 rage instant + 10 rage over 10s, 1 min CD, costs HP
4. **Berserker Rage** — generates rage if Improved Berserker Rage talented
5. **Charge** — generates 15 rage (OOC, Battle Stance)

### Rage Normalization Formula (TBC)
```
Rage = 15 * damage / (4 * weapon_speed * level_factor)
```
- Slower weapons generate more rage per hit (same rage per second on average)
- Instant attacks generate rage based on weapon damage component

### Rage Dump Thresholds (from wowsims)
- **Fury HS threshold**: Queue Heroic Strike when rage > 50-60
- **Arms HS threshold**: Queue Heroic Strike when rage > 50+ (after MS/WW budget)
- **Prot HS threshold**: Queue Heroic Strike when rage > 60+ (after Shield Slam/Revenge)
- **Execute phase**: Stop HS, dump all rage into Execute instead

### Stance Swap Rage Loss
- **Without Tactical Mastery**: ALL rage is lost on stance swap
- **With Tactical Mastery (max rank)**: Retain up to 25 rage
- This makes stance dancing expensive — minimize unnecessary swaps
- Budget swaps carefully: swap → use ability → swap back

---

## 8. Cooldown Management

### Arms Cooldown Priority
1. Death Wish — +20% damage for 30s, use on CD
2. Sweeping Strikes — use on CD (especially before WW on multiple targets)
3. Recklessness — save for execute phase or burn windows (30 min CD!)
4. Trinkets — pair with Death Wish
5. Racial (Blood Fury/Berserking) — pair with Death Wish
6. Bloodrage — use on CD for rage generation

### Fury Cooldown Priority
1. Death Wish — +20% damage for 30s, use on CD
2. Recklessness — save for burn windows (30 min CD!)
3. Trinkets — pair with Death Wish
4. Racial (Blood Fury/Berserking) — pair with Death Wish
5. Bloodrage — use on CD for rage generation
6. Berserker Rage — use on CD (rage gen if talented, Fear immunity)

### Protection Cooldown Priority
1. Shield Block — maintain on CD (crush prevention)
2. Shield Wall — emergency major damage (30 min CD)
3. Last Stand — emergency HP boost (10 min CD)
4. Bloodrage — use on CD for rage generation
5. Berserker Rage — use for Fear immunity (swap to Berserker → back to Defensive)
6. Trinkets — defensive trinkets for survival windows

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "fury" | Spec / Playstyle | Active playstyle ("arms", "fury", "protection") |
| `shout_type` | dropdown | "battle" | Shout Type | Which shout to maintain ("battle", "commanding", "none") |
| `auto_shout` | checkbox | true | Auto Shout | Automatically maintain selected shout buff |
| `use_interrupt` | checkbox | true | Auto Interrupt | Interrupt enemy casts (Pummel/Shield Bash) |
| `use_bloodrage` | checkbox | true | Auto Bloodrage | Use Bloodrage on CD for rage generation |
| `sunder_armor_mode` | dropdown | "none" | Sunder Armor | Sunder Armor maintenance ("none", "help_stack", "maintain") |
| `maintain_thunder_clap` | checkbox | false | Maintain Thunder Clap | Keep Thunder Clap debuff on target (stance swap) |
| `maintain_demo_shout` | checkbox | false | Maintain Demo Shout | Keep Demoralizing Shout debuff on target |

### Tab 2: Arms
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `arms_maintain_rend` | checkbox | true | Maintain Rend | Keep Rend DoT on target (for Blood Frenzy) |
| `arms_rend_refresh` | slider | 4 | Rend Refresh (sec) | Refresh Rend at this duration remaining (2-8) |
| `arms_use_slam` | checkbox | true | Use Slam | Use Slam as filler (requires Improved Slam 2/2) |
| `arms_use_overpower` | checkbox | true | Use Overpower | Use Overpower on dodge procs |
| `arms_overpower_rage` | slider | 25 | Overpower Rage Min | Min rage to use Overpower (10-50) |
| `arms_use_whirlwind` | checkbox | true | Use Whirlwind | Use Whirlwind on CD (stance swap if needed) |
| `arms_prioritize_ww` | checkbox | false | Prioritize WW over MS | Use Whirlwind before Mortal Strike in priority |
| `arms_use_ms_execute` | checkbox | true | MS During Execute | Use Mortal Strike during execute phase |
| `arms_use_ww_execute` | checkbox | true | WW During Execute | Use Whirlwind during execute phase |
| `arms_use_death_wish` | checkbox | true | Use Death Wish | Use Death Wish cooldown |
| `arms_use_sweeping_strikes` | checkbox | true | Use Sweeping Strikes | Use Sweeping Strikes on CD |
| `arms_hs_rage_threshold` | slider | 55 | HS Rage Threshold | Queue Heroic Strike above this rage (30-80) |
| `arms_execute_phase` | checkbox | true | Execute Phase | Switch to Execute priority at <20% target HP |
| `arms_hs_during_execute` | checkbox | false | HS During Execute | Allow Heroic Strike during execute phase |

### Tab 3: Fury
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `fury_use_whirlwind` | checkbox | true | Use Whirlwind | Use Whirlwind on CD |
| `fury_prioritize_ww` | checkbox | false | Prioritize WW over BT | Use Whirlwind before Bloodthirst in priority |
| `fury_use_slam` | checkbox | false | Use Slam | Use Slam weaving (requires Improved Slam 2/2) |
| `fury_use_heroic_strike` | checkbox | true | Heroic Strike Dump | Auto-queue Heroic Strike as rage dump |
| `fury_hs_rage_threshold` | slider | 50 | HS Rage Threshold | Queue Heroic Strike above this rage (30-80) |
| `fury_use_overpower` | checkbox | false | Use Overpower | Use Overpower on dodge procs |
| `fury_overpower_rage` | slider | 25 | Overpower Rage Min | Min rage to use Overpower (10-50) |
| `fury_use_hamstring` | checkbox | false | Hamstring Weave | Weave Hamstring for Sword Spec procs |
| `fury_hamstring_rage` | slider | 50 | Hamstring Rage Min | Min rage to use Hamstring (20-80) |
| `fury_use_death_wish` | checkbox | true | Use Death Wish | Use Death Wish cooldown |
| `fury_use_recklessness` | checkbox | true | Use Recklessness | Use Recklessness during burn windows |
| `fury_execute_phase` | checkbox | true | Execute Phase | Switch to Execute priority at <20% target HP |
| `fury_bt_during_execute` | checkbox | true | BT During Execute | Use Bloodthirst during execute phase |
| `fury_ww_during_execute` | checkbox | true | WW During Execute | Use Whirlwind during execute phase |
| `fury_hs_during_execute` | checkbox | false | HS During Execute | Allow Heroic Strike during Execute phase |
| `fury_rampage_threshold` | slider | 5 | Rampage Refresh (sec) | Refresh Rampage when duration below this (2-10) |

### Tab 4: Protection
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `prot_use_shield_block` | checkbox | true | Auto Shield Block | Maintain Shield Block on CD (crush prevention) |
| `prot_use_devastate` | checkbox | true | Use Devastate | Use Devastate (requires talent) |
| `prot_use_revenge` | checkbox | true | Use Revenge | Use Revenge when available |
| `prot_use_thunder_clap` | checkbox | true | Use Thunder Clap | Maintain Thunder Clap debuff (stance swaps) |
| `prot_use_demo_shout` | checkbox | true | Use Demo Shout | Maintain Demoralizing Shout debuff |
| `prot_hs_rage_threshold` | slider | 60 | HS Rage Threshold | Queue Heroic Strike above this rage (40-90) |
| `prot_no_taunt` | checkbox | false | Disable Taunt | Disable Taunt (off-tank / DPS warrior in tank gear) |

### Tab 5: Cooldowns & Survival
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Blood Fury/Berserking/etc.) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use health potion below this HP% |
| `haste_potion` | checkbox | true | Use Haste Potion | Use Haste Potion during DPS burn (Arms/Fury) |
| `ironshield_potion` | checkbox | false | Use Ironshield Potion | Use Ironshield Potion for tanking (Prot) |
| `last_stand_hp` | slider | 20 | Last Stand HP% | Use Last Stand below this HP% (0=disable) |
| `shield_wall_hp` | slider | 15 | Shield Wall HP% | Use Shield Wall below this HP% (0=disable) |
| `spell_reflection` | checkbox | true | Auto Spell Reflect | Use Spell Reflection on incoming spells |

---

## 10. Strategy Breakdown Per Playstyle

### Arms Playstyle Strategies (priority order)
From wowsims normalRotation() with MS as primary:
```
[1]  MaintainRend         — if Blood Frenzy talented and (rend not active or duration < refresh)
[2]  Whirlwind            — on CD, if PrioritizeWw (before MS), Berserker Stance
[3]  MortalStrike         — on CD (6s), primary damage ability
[4]  WhirlwindLow         — on CD, if !PrioritizeWw (after MS), Berserker Stance
[5]  SunderMaintain       — maintain 5 stacks Sunder Armor (if configured)
[6]  ThunderClapMaintain  — maintain TC debuff (requires Battle Stance swap)
[7]  Overpower            — on dodge proc (if enabled, rage ≥ threshold)
[8]  SlamWeave            — filler during auto-attack window (if Improved Slam 2/2)
[9]  Execute              — target <20% HP, dump all rage
[10] HamstringWeave       — optional, for Sword Spec procs (if enabled)
[11] HeroicStrikeQueue    — off-GCD, rage dump when rage ≥ threshold
```

### Fury Playstyle Strategies (priority order)
```
[1]  RampageMaintain      — maintain Rampage buff (after crit, stacks < 5 or duration low)
[2]  Whirlwind            — on CD, if PrioritizeWw (before BT), Berserker Stance
[3]  Bloodthirst          — on CD (6s), primary damage ability
[4]  WhirlwindLow         — on CD, if !PrioritizeWw (after BT), Berserker Stance
[5]  SunderMaintain       — maintain 5 stacks Sunder Armor (if configured)
[6]  Execute              — target <20% HP, dump all rage
[7]  Overpower            — on dodge proc (if enabled, rage ≥ threshold)
[8]  HamstringWeave       — optional, for Sword Spec procs (if enabled)
[9]  HeroicStrikeQueue    — off-GCD, rage dump when rage ≥ HsRageThreshold
```

### Protection Playstyle Strategies (priority order)
```
[1]  ShieldBlock           — maintain on CD (crush prevention, off-GCD-ish)
[2]  ShieldSlam            — on CD (6s), highest single-target threat
[3]  Revenge               — when available (proc-based), highest threat/rage
[4]  Devastate             — filler, applies/refreshes Sunder Armor
[5]  SunderArmor           — if Devastate not talented, build/maintain 5 stacks
[6]  ThunderClapMaintain   — debuff maintenance, requires Battle Stance swap
[7]  DemoShoutMaintain     — AP debuff maintenance
[8]  Taunt                 — smart single-target taunt (elite/boss only, lost aggro)
[9]  MockingBlow           — 2-min CD taunt fallback from Battle Stance (when Taunt on CD)
[10] HeroicStrikeQueue     — off-GCD, rage dump when rage > threshold
```

**Mocking Blow notes:**
- ID 25266, 2 min CD, Battle Stance only
- Used as a taunt fallback when the main Taunt (10s CD, Defensive Stance) is on cooldown
- Respects `prot_no_taunt` setting — disabled when taunt is globally disabled
- Same classification filtering as Taunt (elite/boss only, not CC'd targets)
- Since the addon does NOT auto-swap stances, this fires naturally when the Warrior
  happens to be in Battle Stance (e.g., during/after Thunder Clap stance swap window)
- IsReady() handles the Battle Stance requirement check internally

### Shared Middleware (all specs)
```
[MW-500]  LastStand            — emergency HP boost at critical HP (Prot talent)
[MW-490]  ShieldWall           — emergency DR at critical HP (Prot)
[MW-400]  SpellReflection      — reflect incoming spell (if enabled)
[MW-300]  RecoveryItems        — healthstone, health potion
[MW-250]  Interrupt            — Pummel (Berserker) or Shield Bash (Defensive)
[MW-200]  Bloodrage            — rage generation on CD
[MW-150]  BerserkerRage        — rage gen + Fear immunity
[MW-100]  ShoutMaintain        — Battle Shout or Commanding Shout uptime
[MW-90]   DeathWish            — +20% damage CD (Arms/Fury)
[MW-80]   Recklessness         — +100% crit (Fury burn window)
[MW-70]   Trinkets             — auto-use trinkets
[MW-60]   Racial               — Blood Fury / Berserking / etc.
```

### AoE Strategies (triggered by enemy_count threshold)
```
When enemy_count >= aoe_threshold (configurable, default 3):
Arms: Sweeping Strikes → Whirlwind → Cleave dump
Fury: Whirlwind on CD → Cleave dump (instead of HS)
Prot: Thunder Clap → Demo Shout → Cleave dump → tab-Devastate
All specs: Cleave replaces Heroic Strike as rage dump
```

---

## Wowsims Verified Rotation Logic

Cross-referenced from `wowsims/tbc/sim/warrior/dps/rotation.go` and ability files.

### Wowsims DPS Rotation Architecture
The sim uses three main entry points:
- `OnGCDReady()` — main rotation when GCD is free
- `OnAutoAttack()` — Slam queuing + HS/Cleave queuing on auto-attack events
- `doRotation()` — orchestration: Thunder Clap stance swap → Sunder maintenance → normal/execute routing

### Wowsims normalRotation() Priority (Verified)
```
1. Rampage         — if talent learned AND crit in last 5s AND (stacks < 5 OR duration ≤ RampageCdThreshold)
2. Whirlwind       — if Rotation.PrioritizeWw enabled
3. Bloodthirst     — primary Fury ability
4. Mortal Strike   — primary Arms ability
5. Shield Slam     — (Prot hybrid? rarely used in DPS)
6. Whirlwind       — if Rotation.PrioritizeWw disabled (lower priority than BT/MS)
7. Debuff maintenance — Sunder Armor + Thunder Clap (skipped if highPrioSpellsOnly)
8. Overpower       — if UseOverpower AND rage ≥ OverpowerRageThreshold
9. Berserker Rage  — rage gen / fear immunity
10. Hamstring      — if UseHamstring AND rage ≥ HamstringRageThreshold
```

### Wowsims executeRotation() Priority (Verified)
```
1. Rampage         — maintain buff even during execute
2. Whirlwind       — if PrioritizeWw AND UseWwDuringExecute
3. Bloodthirst     — if UseBtDuringExecute
4. Mortal Strike   — if UseMsDuringExecute
5. Whirlwind       — if !PrioritizeWw AND UseWwDuringExecute
6. Debuff maintenance — (skipped if highPrioSpellsOnly)
7. Execute         — dump all rage (925 + 21 × extraRage base damage)
8. Berserker Rage  — rage gen
```

### Wowsims Configuration Fields
| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `UseSlam` | bool | — | Disabled if ImprovedSlam ≠ 2 |
| `UseSlamDuringExecute` | bool | — | Allow Slam in execute phase |
| `PrioritizeWw` | bool | — | WW before BT/MS in priority |
| `UseWwDuringExecute` | bool | — | Allow WW in execute phase |
| `UseBtDuringExecute` | bool | — | Allow BT in execute phase |
| `UseMsDuringExecute` | bool | — | Allow MS in execute phase |
| `UseHsDuringExecute` | bool | — | Allow HS queue in execute phase |
| `SunderArmor` | enum | — | None / HelpStack / Maintain |
| `UseOverpower` | bool | — | Use Overpower on dodge procs |
| `OverpowerRageThreshold` | int | — | Min rage for Overpower |
| `UseHamstring` | bool | — | Hamstring weave for procs |
| `HamstringRageThreshold` | int | — | Min rage for Hamstring |
| `MaintainDemoShout` | bool | — | Keep Demo Shout on target |
| `MaintainThunderClap` | bool | — | Keep TC on target (stance swaps!) |
| `HsRageThreshold` | int | — | Min rage to queue HS/Cleave |
| `RampageCdThreshold` | dur | — | Refresh Rampage below this duration |
| `slamLatency` | ms | — | User-configured reaction time |
| `slamGCDDelay` | ms | 400 | GCD overlap buffer for Slam |
| `slamMSWWDelay` | ms | 2000 | Don't Slam if MS/WW ready within this |

### Wowsims Slam Timing Logic
Slam is queued during auto-attack windows (NOT on GCD ready):
1. `OnAutoAttack()` fires → check `slamInRotation()` → `tryQueueSlam()`
2. Slam queues at `sim.CurrentTime + slamLatency` (simulates player reaction)
3. **Skip Slam if**: MS or WW comes off CD within `slamMSWWDelay` (default 2s)
4. **highPrioSpellsOnly flag**: Set when GCD overlaps with Slam timing window → only cast highest-priority abilities (BT/MS/WW), skip fillers
5. Slam delays auto-attacks: next swing = current time + cast time + swing speed

### Wowsims HS/Cleave Queue Logic
From `heroic_strike_cleave.go`:
- **HS cost**: `15 - ImprovedHeroicStrike - FocusedRage` (80% refund on miss)
- **Cleave cost**: `20 - FocusedRage`
- **Queue condition**: `CurrentRage() >= max(abilityCost, HsRageThreshold)`
- **Dequeue condition**: rage drops below cost on main-hand swing
- **Key TBC mechanic**: Queuing HS removes dual-wield miss penalty for that swing
- **Execute phase**: Only queue if `UseHsDuringExecute` enabled

### Wowsims Debuff Maintenance
- **Sunder Armor**: Maintain 5 stacks, refresh at ≤ 3s remaining (`SunderWindow`)
  - `HelpStack` mode: only help stack to 5, don't maintain duration
  - `Maintain` mode: keep stacks AND refresh timer
  - Uses Devastate if talented, otherwise Sunder Armor
- **Thunder Clap**: Refresh at ≤ 2s remaining (`DebuffRefreshWindow`)
  - Requires Battle Stance → sets `thunderClapNext` flag → swap → TC → 300ms delay → swap back
- **Demoralizing Shout**: Maintained if `MaintainDemoShout` enabled

### Wowsims Ability Formulas (Verified)
| Ability | Formula | Threat | Notes |
|---------|---------|--------|-------|
| Execute | 925 + 21 × extraRage | 1.25x | Consumes all rage, base cost 15 |
| Shield Slam | 420-440 + BlockValue | 305 flat bonus | 1.0x threat mult |
| Slam | 140% weapon damage | 70 flat bonus | 1.5s - 0.5s×ImprovedSlam |
| Overpower | weapon + 35 base | 0.75x | Reduced threat |
| Bloodthirst | 45% of AP | 1.0x | 80% refund on miss |
| Mortal Strike | weapon + 210 base | 1.0x | 80% refund on miss |
| Whirlwind | 100% weapon damage | 1.25x | Up to 4 targets, MH+OH |
| Rampage | — (buff, not damage) | — | 50 AP/stack, max 5, 20 rage |
| Deep Wounds | 20% × weapon avg × rank | 1.0x | 4 ticks @ 3s = 12s |

---

## Key Implementation Notes

### Playstyle Detection
Warrior has NO auto-detection via stances (unlike Druid). Playstyle must be determined by:
- **User setting** (dropdown: "arms", "fury", "protection")
- Warriors switch stances constantly within a playstyle, so stance ≠ spec
- Could auto-detect via talent check (MS=Arms, BT=Fury, Devastate=Prot) but user setting is more reliable

### Stance Constants
```lua
Constants.STANCE = {
    BATTLE = 1,      -- Player:GetStance() == 1
    DEFENSIVE = 2,   -- Player:GetStance() == 2
    BERSERKER = 3,   -- Player:GetStance() == 3
}

-- Wowsims-verified thresholds
Constants.SUNDER_REFRESH_WINDOW = 3    -- refresh Sunder at ≤ 3s remaining
Constants.TC_REFRESH_WINDOW = 2        -- refresh Thunder Clap at ≤ 2s remaining
Constants.STANCE_SWAP_DELAY = 0.3      -- 300ms delay after TC stance swap
Constants.EXECUTE_BASE_DAMAGE = 925    -- Execute: 925 + 21 × extraRage
Constants.EXECUTE_RAGE_SCALING = 21    -- per extra rage point
Constants.SUNDER_MAX_STACKS = 5
Constants.RAMPAGE_MAX_STACKS = 5
Constants.RAMPAGE_AP_PER_STACK = 50
```
Framework docs confirm: Warrior: 1=Battle, 2=Defensive, 3=Berserker

### No Idle Playstyle
Like Mage, Warrior doesn't need an idle playstyle. OOC behavior (shout maintenance, Bloodrage) handled via middleware with `requires_combat = false`.

### extend_context Fields
```lua
ctx.stance = Player:GetStance()
ctx.rage = Player:Rage()
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime()
ctx.enemy_count = A.MultiUnits:GetByRange(8) or 0
-- Buff tracking
ctx.has_battle_shout = (Unit("player"):HasBuffs(2048) or 0) > 0
ctx.has_commanding_shout = (Unit("player"):HasBuffs(469) or 0) > 0
ctx.death_wish_active = (Unit("player"):HasBuffs(12292) or 0) > 0
ctx.recklessness_active = (Unit("player"):HasBuffs(1719) or 0) > 0
ctx.sweeping_strikes_active = (Unit("player"):HasBuffs(12328) or 0) > 0
ctx.berserker_rage_active = (Unit("player"):HasBuffs(18499) or 0) > 0
ctx.enrage_active = (Unit("player"):HasBuffs(14202) or 0) > 0
ctx.flurry_active = (Unit("player"):HasBuffs(12974) or 0) > 0
ctx.rampage_active = (Unit("player"):HasBuffs(30033) or 0) > 0
ctx.rampage_stacks = Unit("player"):HasBuffsStacks(30033) or 0
ctx.rampage_duration = Unit("player"):HasBuffs(30033) or 0
-- Shield (Prot)
ctx.shield_block_active = (Unit("player"):HasBuffs(2565) or 0) > 0
ctx.has_shield = true  -- TODO: check equipped shield (API: GetInventoryItemID("player", 17))
-- Cache invalidation
ctx._arms_valid = false
ctx._fury_valid = false
ctx._prot_valid = false
```

### Arms State (context_builder)
```lua
local arms_state = {
    rend_active = false,
    rend_duration = 0,
    overpower_available = false,
    ms_cd = 0,
    ww_cd = 0,
    target_below_20 = false,
}

local function get_arms_state(context)
    if context._arms_valid then return arms_state end
    context._arms_valid = true

    arms_state.rend_duration = Unit(TARGET_UNIT):HasDeBuffs(25208) or 0
    arms_state.rend_active = arms_state.rend_duration > 0
    arms_state.ms_cd = A.MortalStrike:GetCooldown() or 0
    arms_state.ww_cd = A.Whirlwind:GetCooldown() or 0
    arms_state.target_below_20 = context.target_hp < 20
    -- Overpower availability: check if Overpower is usable
    -- (framework may track dodge events internally)
    arms_state.overpower_available = A.Overpower:IsReady(TARGET_UNIT)

    return arms_state
end
```

### Fury State (context_builder)
```lua
local fury_state = {
    bt_cd = 0,
    ww_cd = 0,
    target_below_20 = false,
    rampage_duration = 0,
    rampage_stacks = 0,
    rampage_active = false,
}

local function get_fury_state(context)
    if context._fury_valid then return fury_state end
    context._fury_valid = true

    fury_state.bt_cd = A.Bloodthirst:GetCooldown() or 0
    fury_state.ww_cd = A.Whirlwind:GetCooldown() or 0
    fury_state.target_below_20 = context.target_hp < 20
    fury_state.rampage_duration = Unit("player"):HasBuffs(30033) or 0
    fury_state.rampage_stacks = Unit("player"):HasBuffsStacks(30033) or 0
    fury_state.rampage_active = fury_state.rampage_duration > 0

    return fury_state
end
```

### Protection State (context_builder)
```lua
local prot_state = {
    shield_slam_cd = 0,
    revenge_available = false,
    sunder_stacks = 0,
    sunder_duration = 0,
    shield_block_active = false,
    shield_block_cd = 0,
    thunder_clap_debuff = 0,
    demo_shout_debuff = 0,
    target_below_20 = false,
}

local function get_prot_state(context)
    if context._prot_valid then return prot_state end
    context._prot_valid = true

    prot_state.shield_slam_cd = A.ShieldSlam:GetCooldown() or 0
    prot_state.revenge_available = A.Revenge:IsReady(TARGET_UNIT)
    prot_state.sunder_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(25225) or 0
    prot_state.sunder_duration = Unit(TARGET_UNIT):HasDeBuffs(25225) or 0
    prot_state.shield_block_active = context.shield_block_active
    prot_state.shield_block_cd = A.ShieldBlock:GetCooldown() or 0
    prot_state.thunder_clap_debuff = Unit(TARGET_UNIT):HasDeBuffs(25264) or 0
    prot_state.demo_shout_debuff = Unit(TARGET_UNIT):HasDeBuffs(25203) or 0
    prot_state.target_below_20 = context.target_hp < 20

    return prot_state
end
```

### Heroic Strike / Cleave as Next-Swing (Special Handling)
Heroic Strike and Cleave are unique — they are **on-next-attack** abilities:
- NOT on the GCD (can be queued at any time)
- Replace the next auto-attack swing with a special attack
- Can be cancelled before the swing lands
- Strategies should set `is_gcd_gated = false` for these
- Implementation note: need to track if HS/Cleave is already queued (`IsSpellCurrent()`)
```lua
-- Check if Heroic Strike is already queued
local hs_queued = A.HeroicStrike:IsSpellCurrent()
-- Only queue if not already queued and rage > threshold
if not hs_queued and context.rage > context.settings.fury_hs_rage_threshold then
    return A.HeroicStrike:Show(icon)
end
```

### Stance Requirements Table
Strategies must check stance before casting restricted abilities:
```lua
-- Stance requirements for key abilities
local STANCE_REQUIREMENTS = {
    -- Battle Stance (1) only
    Overpower = Constants.STANCE.BATTLE,
    ThunderClap = Constants.STANCE.BATTLE,
    Charge = Constants.STANCE.BATTLE,
    MockingBlow = Constants.STANCE.BATTLE,
    VictoryRush = Constants.STANCE.BATTLE,

    -- Defensive Stance (2) only
    Revenge = Constants.STANCE.DEFENSIVE,
    ShieldBlock = Constants.STANCE.DEFENSIVE,
    ShieldWall = Constants.STANCE.DEFENSIVE,
    ShieldBash = Constants.STANCE.DEFENSIVE,
    Taunt = Constants.STANCE.DEFENSIVE,
    SunderArmor = Constants.STANCE.DEFENSIVE,
    Devastate = Constants.STANCE.DEFENSIVE,
    Disarm = Constants.STANCE.DEFENSIVE,
    Intervene = Constants.STANCE.DEFENSIVE,

    -- Berserker Stance (3) only
    Whirlwind = Constants.STANCE.BERSERKER,
    Pummel = Constants.STANCE.BERSERKER,
    Intercept = Constants.STANCE.BERSERKER,
    BerserkerRage = Constants.STANCE.BERSERKER,
    Recklessness = Constants.STANCE.BERSERKER,

    -- Battle OR Defensive
    SpellReflection = {Constants.STANCE.BATTLE, Constants.STANCE.DEFENSIVE},
}

-- Any stance: Heroic Strike, Cleave, Execute, Slam, Hamstring, Rend,
--             Mortal Strike, Bloodthirst, Shield Slam,
--             Battle Shout, Commanding Shout, Demo Shout,
--             Bloodrage, Intimidating Shout
```

### Stance Swap Suggestion System
Like Druid form suggestions, the addon should NOT auto-swap stances but CAN suggest:
- Arms in Berserker → suggest Battle for Overpower (when dodge proc)
- Arms in Battle → suggest Berserker for Whirlwind (when WW off CD)
- Prot in Defensive → suggest Battle for Thunder Clap (when debuff expires)
- Use the A[1] suggestion icon pattern from the existing codebase