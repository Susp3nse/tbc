# TBC Hunter Implementation Research

Comprehensive research for implementing Beast Mastery, Marksmanship, and Survival Hunter playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Beast Mastery Hunter Rotation & Strategies](#2-beast-mastery-hunter-rotation--strategies)
3. [Marksmanship Hunter Rotation & Strategies](#3-marksmanship-hunter-rotation--strategies)
4. [Survival Hunter Rotation & Strategies](#4-survival-hunter-rotation--strategies)
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
| Auto Shot | 75 | Special | — | Ranged auto-attack, fires on swing timer |
| Steady Shot | 34120 | 1.5s/haste | 110 | Primary filler, weaved between auto shots. Cast time = 1500ms / rangedSwingSpeed. GCD fixed at 1.5s (haste does NOT reduce GCD) |
| Aimed Shot (R7) | 27065 | 2.5s | 370 | High-damage shot, 6s CD. Post-2.3: instant reset on CD. Used as precast opener |
| Arcane Shot (R9) | 27019 | Instant | 230 | Instant magic damage, 6s CD |
| Multi-Shot (R6) | 27021 | 0.5s/haste | 275 | Hits up to 3 targets, 10s CD. Cast time = 500ms / rangedSwingSpeed |
| Serpent Sting (R10) | 27016 | Instant | 275 | 15s DoT, 5 ticks |
| Kill Command | 34026 | Instant | 75 | Pet attack, 5s CD, off-GCD |

### Shoot Spells (weapon-type specific)
| Spell | ID | Notes |
|-------|------|-------|
| Shoot Bow | 2480 | Initiates auto shot with bows |
| Shoot Crossbow | 7919 | Initiates auto shot with crossbows |
| Shoot Gun | 7918 | Initiates auto shot with guns |
| Throw | 2764 | Initiates auto attack with thrown |

### Sting Spells
| Spell | ID | Mana | Duration | Notes |
|-------|------|------|----------|-------|
| Serpent Sting (R10) | 27016 | 275 | 15s | Nature DoT, 5 ticks every 3s |
| Scorpid Sting | 3043 | 100 | 20s | -AP on target, single rank |
| Viper Sting (R4) | 27018 | 108 | 8s | Mana drain, PvP utility |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Aimed Shot | 19434 | 27065 (R7) | Talent-learned (MM) |
| Arcane Shot | 3044 | 27019 (R9) | |
| Multi-Shot | 2643 | 27021 (R6) | |
| Serpent Sting | 1978 | 27016 (R10) | |
| Viper Sting | 3034 | 27018 (R4) | |
| Hunter's Mark | 1130 | 14325 (R4) | |
| Aspect of the Hawk | 13165 | 27044 (R8) | +155 RAP at max rank |
| Aspect of the Wild | 20043 | 27045 (R3) | |
| Mend Pet | 136 | 27046 (R8) | HoT on pet |
| Revive Pet | 982 | 27173 (R6) | |
| Distracting Shot | 20736 | 27020 (R7) | High-threat shot |
| Raptor Strike | 2973 | 27014 (R9) | Next-melee-attack, 120 mana |
| Mongoose Bite | 1495 | 36916 (R5) | Melee, 40 mana, 5s CD |
| Wing Clip | 2974 | 14267 (R3) | Melee, 40 mana, 50% slow |
| Explosive Trap | 13813 | 27025 (R4) | |
| Immolation Trap | 13795 | 27023 (R6) | |
| Freezing Trap | 1499 | 14311 (R3) | CC trap |
| Scare Beast | 1513 | 14327 (R3) | |
| Volley | 1510 | 27022 (R4) | Channeled AoE |
| Counterattack | 19306 | 27067 (R3) | Survival talent |
| Disengage | 781 | 27015 (R3) | Melee threat reduction |
| Wyvern Sting | 19386 | 27068 (R3) | Survival 41pt talent |
| Trueshot Aura | 19506 | 27066 (R4) | MM talent, party buff |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Steady Shot | 34120 | TBC ability (level 62 trained) |
| Kill Command | 34026 | TBC ability, 5s CD, 75 mana |
| Misdirection | 34477 | TBC ability, 30s CD, redirect threat |
| Aspect of the Viper | 34074 | TBC ability, mana recovery |
| Snake Trap | 34600 | TBC ability |
| Silencing Shot | 34490 | MM 41pt talent, 20s CD |
| Scatter Shot | 19503 | MM talent, 30s CD, 4s disorient |
| Bestial Wrath | 19574 | BM 41pt talent, 2 min CD |
| Intimidation | 19577 | BM talent, 1 min CD, 3s stun |
| Readiness | 23989 | MM 21pt talent, resets all Hunter CDs |
| Deterrence | 19263 | +25% dodge/parry, 10s, 5 min CD |
| Feign Death | 5384 | Threat drop |
| Concussive Shot | 5116 | Instant, 12s CD, 4s daze |
| Tranquilizing Shot | 19801 | Dispels enrage, 20s CD |
| Scorpid Sting | 3043 | -AP debuff |
| Rapid Fire | 3045 | +40% ranged haste, 15s, 5 min CD |
| Frost Trap | 13809 | Ground slow |
| Call Pet | 883 | |
| Dismiss Pet | 2641 | |
| Feed Pet | 6991 | |
| Beast Lore | 1462 | |
| Eyes of the Beast | 1002 | |
| Eagle Eye | 6197 | |
| Flare | 1543 | Reveals stealth |
| Aspect of the Monkey | 13163 | +8% dodge |
| Aspect of the Cheetah | 5118 | +30% move speed |
| Aspect of the Beast | 13161 | Untrackable |
| Aspect of the Pack | 13159 | Party +30% move speed |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Bestial Wrath | 19574 | 2 min | 18s | Pet +50% dmg, immune to CC; Hunter gets The Beast Within (+10% all dmg) |
| Rapid Fire | 3045 | 5 min | 15s | +40% ranged haste. CD reduced by 1 min per Rapid Killing talent rank |
| Readiness | 23989 | 5 min | Instant | Resets ALL Hunter ability cooldowns |
| Kill Command | 34026 | 5s | — | Pet melee attack, off-GCD |
| Intimidation | 19577 | 1 min | 3s | Pet stun |
| Misdirection | 34477 | 30s | 30s | Next 3 attacks redirect threat to focus target |
| Deterrence | 19263 | 5 min | 10s | +25% dodge and parry |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Feign Death | 5384 | 30s | Drops all threat, can fail at low level enemies |
| Deterrence | 19263 | 5 min | +25% dodge/parry for 10s |
| Disengage (R3) | 27015 | — | Melee, reduces threat |
| Freezing Trap (R3) | 14311 | 30s | 20s CC, shares trap CD |
| Frost Trap | 13809 | 30s | Ground slow, shares trap CD |
| Scatter Shot | 19503 | 30s | 4s disorient (MM talent) |
| Concussive Shot | 5116 | 12s | 4s daze |
| Wyvern Sting (R3) | 27068 | 2 min | 12s sleep (SV 41pt talent) |
| Wing Clip (R3) | 14267 | — | 50% slow, melee range |
| Tranquilizing Shot | 19801 | 20s | Removes 1 enrage effect |
| Flare | 1543 | 20s | Reveals stealth in area |

### Self-Buffs / Aspects
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Aspect of the Hawk (R8) | 27044 | Permanent | +155 RAP. Imp. Hawk: 10% chance for Quick Shots (15% haste, 12s) |
| Aspect of the Viper | 34074 | Permanent | Mana regen based on intellect and mana%. TBC-only |
| Aspect of the Monkey | 13163 | Permanent | +8% dodge |
| Aspect of the Cheetah | 5118 | Permanent | +30% move speed, dazed if hit |
| Aspect of the Wild (R3) | 27045 | Permanent | +70 nature resist (party) |
| Aspect of the Beast | 13161 | Permanent | Untrackable |
| Aspect of the Pack | 13159 | Permanent | Party +30% move speed, dazed if hit |
| Trueshot Aura (R4) | 27066 | Permanent | +125 AP (party), MM talent |

### Racial Spell IDs
Hunter races in TBC: Orc, Troll, Tauren, Blood Elf (Horde); Night Elf, Dwarf, Draenei (Alliance)
Note: Gnome, Human, Undead cannot be Hunters in TBC.
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Orc | Blood Fury | 20572 | +282 AP for 15s, 2 min CD |
| Troll | Berserking | 20554 | 10-30% haste for 10s, 3 min CD |
| Tauren | War Stomp | 20549 | 2s AoE stun, 2 min CD |
| Blood Elf | Arcane Torrent | 28730 | 2s AoE silence + mana, 2 min CD |
| Night Elf | Shadowmeld | 20580 | Stealth while stationary |
| Dwarf | Stoneform | 20594 | Remove bleed/poison/disease, +10% armor 8s, 2 min CD |
| Draenei | Gift of the Naaru | 28880 | HoT heal, 3 min CD |

### Debuff IDs (for tracking)
| Debuff | ID | Notes |
|--------|------|-------|
| Hunter's Mark (R4) | 14325 | +110 RAP debuff on target |
| Serpent Sting (R10) | 27016 | Nature DoT |
| Scorpid Sting | 3043 | -AP debuff |
| Viper Sting (R4) | 27018 | Mana drain |
| Concussive Shot | 5116 | 4s daze |
| Wing Clip (R3) | 14267 | 50% slow |
| Freezing Trap | 3355 | CC effect (trap debuff, NOT trap spell ID) |
| Expose Weakness | 34503 | SV talent proc, +AP based on agility |
| Improved Hunter's Mark | 14325 | Same debuff ID, enhanced by talent |

### Buff IDs (for tracking)
| Buff | ID | Notes |
|------|------|-------|
| Rapid Fire | 3045 | +40% ranged haste active |
| Bestial Wrath (on pet) | 19574 | +50% pet dmg |
| The Beast Within (on hunter) | 34471 | +10% all dmg, immune to CC (BM 41pt) |
| Quick Shots (Imp. Hawk proc) | 6150 | +15% ranged haste for 12s |
| Expose Weakness (proc) | 34503 | SV talent, adds RAP to party based on agility |
| Aspect of the Hawk | 27044 | Active aspect check |
| Aspect of the Viper | 34074 | Active aspect check |
| Mend Pet (HoT) | 27046 | Max rank HoT on pet |
| Kill Command (pet) | 34027 | Pet's KC attack buff |
| Deterrence | 19263 | Dodge/parry buff active |
| Feign Death | 5384 | Threat drop active |
| Misdirection | 34477 | Threat redirect active |
| Heroism | 32182 | Shaman haste buff |
| Bloodlust | 2825 | Shaman haste buff |
| Drums of Battle | 35476 | Leatherworking drums buff |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Haste Potion | 22838 | +400 haste rating for 15s, shares potion CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Major Healing Potion | 13446 | 1050-1750 HP, 2 min CD (budget option) |
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD) |
| Demonic Rune | 12662 | Same as Dark Rune |
| Adamantite Stinger | 28056 | 43 DPS ammo |
| Timeless Arrow | 34581 | 53 DPS ammo (Sunwell) |
| Mysterious Arrow | 29784 | 46.5 DPS ammo |
| Scroll of Agility V | 27498 | +20 agility |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+) or later:
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Lock and Load | Wrath (3.0) | No trap-triggered free shots |
| Explosive Shot | Wrath (3.0) | Spell doesn't exist |
| Kill Shot | Wrath (3.0) | No execute ability for Hunter |
| Chimera Shot | Wrath (3.0) | Spell doesn't exist |
| Black Arrow | Wrath (3.0) | Spell doesn't exist |
| Aspect of the Dragonhawk | Wrath (3.0) | Combined Hawk+Monkey doesn't exist |
| Steady Shot refreshing Serpent Sting | Wrath (3.0) | Must manually reapply SS |
| Focus (resource) | Cataclysm (4.0) | Hunters use MANA in TBC, not Focus |
| Cobra Shot | Cataclysm (4.0) | Spell doesn't exist |
| Camouflage | Cataclysm (4.0) | Spell doesn't exist |
| Aimed Shot as instant | Cataclysm (4.0) | In TBC it has a 2.5s cast time |
| Disengage as backward leap | Wrath (3.0) | In TBC, Disengage is a melee threat-reduction ability |

**What IS new in TBC (vs Classic):**
- Steady Shot (level 62 trained) — THE defining TBC Hunter ability
- Kill Command (level 66 trained)
- Misdirection (level 70 trained)
- Aspect of the Viper (level 64 trained)
- Snake Trap (level 68 trained)
- Silencing Shot (MM 41pt talent)
- Aimed Shot becomes an instant-reset 6s CD (changed from Classic's cast-time version in patch 2.3)

---

## 2. Beast Mastery Hunter Rotation & Strategies

### Core Mechanic: Auto Shot + Steady Shot Weaving
The fundamental TBC Hunter mechanic across ALL specs is weaving Steady Shot (1.5s cast) between Auto Shot cycles without clipping (delaying) the next Auto Shot. This accounts for ~95% of rotation complexity.

**Auto Shot Clipping**: If Steady Shot is cast too late in the Auto Shot cycle, it delays the next Auto Shot. The rotation must track the ranged swing timer to time casts precisely.

### Shot Weaving Ratios
Weapon speed determines the optimal rotation pattern:

**1:1 Ratio** (faster weapons, ~2.2-2.4s hasted speed):
```
Auto Shot → Steady Shot → Auto Shot → Steady Shot → ...
One Steady Shot per Auto Shot cycle. Tight timing.
```

**1:1.5 Ratio** (slower weapons, ~2.8-3.0s base speed):
```
Auto Shot → Steady Shot → [instant] → Auto Shot → Steady Shot → Auto Shot → ...
One Steady Shot + one instant (Multi-Shot or Arcane Shot) per 2 Auto Shots.
```

### Single Target Rotation
From wowsims `rotation.go` (adaptive rotation):
1. **Kill Command** — off-GCD, use on every 5s CD when pet is attacking (highest priority)
2. **Bestial Wrath** — use on CD (pet DPS burst, 2 min CD)
3. **Auto Shot** — never clip, always fire on time
4. **Multi-Shot** — weave between auto shots when off CD (10s CD), replaces a Steady Shot
5. **Steady Shot** — primary filler, weaved between auto shots
6. **Arcane Shot** — only when Steady Shot would clip next auto shot (tight window filler)

### BM-Specific Priorities
- **Pet DPS is paramount**: BM pet does 30-40% of total DPS. Keep pet attacking at all times
- **Kill Command on CD**: Off-GCD, 5s CD, essentially free damage
- **Bestial Wrath early**: 2 min CD, don't hold for burn phases unless syncing with Bloodlust
- **The Beast Within** (41pt talent): Hunter gets +10% all damage and CC immunity during Bestial Wrath

### Opener (from Icy Veins)
```
1. Hunter's Mark (if assigned)
2. Misdirection on tank
3. Pre-cast Aimed Shot before pull timer hits 0
4. Bestial Wrath + Blood Fury/Berserking (racials)
5. Rapid Fire
6. Begin Steady Shot weaving rotation
```

### State Tracking Needed
- `weapon_speed` — current ranged weapon speed (for weave timing)
- `shoot_timer` — time until next auto shot fires
- `pet_active` — pet is alive and attacking
- `bestial_wrath_active` — BW buff on pet
- `beast_within_active` — TBW buff on hunter (34471)
- `rapid_fire_active` — haste buff active
- `quick_shots_active` — Imp. Hawk proc active (6150)

---

## 3. Marksmanship Hunter Rotation & Strategies

### Core Mechanic: Steady Shot Weaving + Aimed Shot
Same weaving core as BM, but with Aimed Shot as an additional high-damage cooldown ability and Readiness for CD resets.

### Single Target Rotation
1. **Kill Command** — off-GCD, use on CD (still important even as MM)
2. **Aimed Shot** — use on CD (6s CD, instant post-2.3 patch, high damage)
3. **Auto Shot** — never clip
4. **Multi-Shot** — weave between auto shots when off CD
5. **Silencing Shot** — weave as DPS filler when off CD (20s CD, instant, no GCD waste)
6. **Steady Shot** — primary filler
7. **Arcane Shot** — tight-window filler (when Steady Shot would clip)

### MM-Specific Priorities
- **Trueshot Aura**: Party-wide +125 AP buff, always maintain
- **Aimed Shot**: Post-2.3 patch makes this instant with 6s CD — treat as high-priority weave
- **Readiness**: Resets ALL Hunter CDs. Primary use: double Rapid Fire. Secondary: emergency Misdirection reset
- **Silencing Shot**: Functions as a DPS ability (instant, no GCD) beyond its interrupt utility

### Opener
```
1. Hunter's Mark
2. Misdirection on tank
3. Pre-cast Aimed Shot
4. Rapid Fire + racial
5. Begin rotation
6. After Rapid Fire expires: Readiness → Rapid Fire again
```

### State Tracking Needed
- Same as BM base, plus:
- `aimed_shot_cd` — Aimed Shot cooldown tracking
- `silencing_shot_cd` — for DPS weaving
- `readiness_cd` — for double Rapid Fire planning

---

## 4. Survival Hunter Rotation & Strategies

### Core Mechanic: Steady Shot Weaving + Expose Weakness
Same weaving core. SV brings Expose Weakness proc (+AP to party based on agility) and optional melee weaving with Raptor Strike.

### Single Target Rotation
1. **Kill Command** — off-GCD, use on CD
2. **Auto Shot** — never clip
3. **Multi-Shot** — weave when off CD
4. **Raptor Strike** — optional melee weave (significant DPS if executed perfectly, risky)
5. **Steady Shot** — primary filler
6. **Arcane Shot** — tight-window filler

### Melee Weaving (Advanced, Optional)
From wowsims `rotation.go`:
Raptor Strike can be weaved into the rotation by running into melee range during the auto-shot wait window:
```
Auto Shot → Steady Shot → [run to melee → Raptor Strike → run back] → Auto Shot
```
- **Percentage-based**: wowsims uses `PercentWeaved` to control how often to attempt weaving
- **Timing**: Must complete melee + movement before next auto shot fires
- **Risk**: If mistimed, delays auto shot significantly
- Icy Veins: "at best will be a tiny DPS increase when done optimally, but is nearly impossible to do optimally"

### SV-Specific Priorities
- **Expose Weakness**: Passive proc from crits, +25% of agility as RAP for party. No active management needed
- **Raptor Strike weave**: Only if user explicitly enables it (high skill cap)
- **Wyvern Sting**: Utility CC, not part of DPS rotation

### State Tracking Needed
- Same as BM base, plus:
- `expose_weakness_active` — proc buff active (34503)
- `in_melee_for_weave` — tracking melee weave state
- `raptor_strike_cd` — for weave timing

---

## 5. AoE Rotation (All Specs)

### AoE Options
1. **Multi-Shot** — cleave (up to 3 targets), already part of single-target rotation
2. **Explosive Trap** — melee-range AoE DoT (requires being in melee), use on 3+ targets
3. **Volley** — channeled ranged AoE, use on 4+ targets (heavy mana cost)
4. **Snake Trap** — minor AoE DoT + slow, situational

### AoE Priority (by target count)
```
2 targets:  Multi-Shot on CD + normal rotation
3-6 targets: Multi-Shot on CD + Explosive Trap (if safe to melee)
7+ targets:  Volley (replaces entire rotation, very mana-intensive)
10+ targets: Volley spam (only option)
```

### Spec-Specific AoE Additions
- **BM**: Pet with cleave ability (Gore/Claw) contributes to AoE naturally
- **MM**: No special AoE additions
- **SV**: Improved traps talent makes Explosive Trap better; Snake Trap with Entrapment can root

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Feign Death** — threat drop (30s CD), critical for aggro management
   - Use when: taking aggro from tank, emergency threat wipe
   - Note: Can resist/fail on skull-level mobs
2. **Deterrence** — +25% dodge/parry for 10s (5 min CD)
   - Use when: taking heavy melee damage
3. **Freezing Trap** — 20s CC on add (30s trap CD)
   - Use when: multiple enemies on hunter, need to CC an add

### Interrupt/Control
1. **Silencing Shot** — 6s silence + interrupt (20s CD, MM talent)
2. **Scatter Shot** — 4s disorient (30s CD, MM talent)
3. **Intimidation** — 3s pet stun (1 min CD, BM talent)
4. **Concussive Shot** — 4s daze (12s CD) — slow runners/kiting
5. **Wing Clip** — 50% melee slow — emergency kiting

### Dispel/Utility
1. **Tranquilizing Shot** — removes 1 enrage effect (20s CD)
2. **Misdirection** — redirect next 3 attacks' threat to focus target (30s CD)

### Pet Care
1. **Mend Pet** — HoT on pet, channel
2. **Revive Pet** — resurrect dead pet (10s cast, OOC only practical)
3. **Call Pet** — summon dismissed pet

### Self-Buffs (Managed by Aspect System)
- **Aspect of the Hawk** — primary combat aspect (+155 RAP)
- **Aspect of the Viper** — mana recovery
- **Aspect of the Cheetah** — OOC travel
- **Trueshot Aura** — maintain if MM spec (party +125 AP)

---

## 7. Mana Management System

### Aspect of the Viper
TBC Hunter mana management revolves around Aspect swapping:
- **Aspect of the Hawk**: +155 RAP, primary combat aspect
- **Aspect of the Viper**: Restores mana based on intellect and current mana deficit

From wowsims: Viper mana return rate = `22.0/35.0 * (0.9 - percentMana) + 0.11`
This means Viper returns more mana the lower your mana pool is.

### Mana Thresholds
- **Switch to Viper**: When mana drops below configurable threshold (default ~10-15%)
- **Switch back to Hawk**: When mana rises above configurable threshold (default ~30%)
- During Bloodlust/Heroism: Stay on Hawk longer (the haste is worth more than the mana)

### Mana Recovery Priority
1. **Aspect of the Viper** — primary sustain tool (swap and keep DPSing)
2. **Dark Rune / Demonic Rune** — 900-1500 mana at HP cost (separate CD from potion)
3. **Super Mana Potion** — 1800-3000 mana (2 min potion CD)
4. **Mana-efficient shot selection**: Skip Arcane Shot when mana is low

### Hunter-Specific Mana Concerns
- Steady Shot is cheap (110 mana) — always castable
- Multi-Shot is expensive (275 mana) — skip when low on mana
- Arcane Shot is expensive (230 mana) — skip when low on mana
- Serpent Sting is expensive (275 mana) — only maintain when mana is healthy
- `mana_save` threshold: below this mana%, only cast Steady Shot + Auto Shot

---

## 8. Cooldown Management

### All-Spec Cooldown Priority
1. **Kill Command** — 5s CD, off-GCD, use on every cooldown (all specs)
2. **Rapid Fire** — +40% haste for 15s, 5 min CD (reduced by Rapid Killing talent)
3. **Trinkets** — pair with Rapid Fire / Bestial Wrath window

### BM Cooldown Priority
1. Kill Command — on CD always
2. Bestial Wrath — on CD (2 min), sync with Bloodlust if `auto_sync_cds` enabled
3. Rapid Fire — on CD
4. Racials (Blood Fury/Berserking) — with Bestial Wrath
5. Haste Potion — during BW + Rapid Fire + Bloodlust window

### MM Cooldown Priority
1. Kill Command — on CD always
2. Rapid Fire — on CD
3. Readiness — use to reset Rapid Fire when RF is on long CD (>60s remaining)
4. Aimed Shot — on CD (part of rotation, not a "cooldown" per se)
5. Racials — with Rapid Fire
6. Haste Potion — during burst windows

### SV Cooldown Priority
1. Kill Command — on CD always
2. Rapid Fire — on CD
3. Racials — with Rapid Fire
4. Expose Weakness — passive, no CD management needed

### Readiness Usage (MM-specific)
- Primary: Reset Rapid Fire when it has >60s remaining on CD
- Secondary: Reset Misdirection when needed for emergency threat
- **Never waste on Kill Command** — KC has only a 5s CD

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed system logging |
| `mouseover` | checkbox | true | Use @mouseover | Check mouseover target before current target |
| `aoe` | checkbox | true | Enable AoE | Enable multi-target abilities (Multi-Shot, Explosive Trap) |
| `healthstone_hp` | slider | 40 | Healthstone HP (%) | Use Healthstone when HP drops below this. 0=disable |
| `use_healing_potion` | checkbox | true | Use Healing Potion | Use Healing Potion when HP drops low in combat |
| `healing_potion_hp` | slider | 35 | Healing Potion HP (%) | Use Healing Potion below this HP% |
| `use_mana_rune` | checkbox | true | Use Mana Rune | Use Dark/Demonic Rune when mana is low |
| `mana_rune_mana` | slider | 20 | Mana Rune Mana (%) | Use Rune when mana drops below this |

### Tab 2: Rotation
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `warces` | checkbox | false | Warces Haste Mode | Haste-adjusted timing for shot weaving |
| `weapon_speed` | slider | 3 | Weapon Speed (sec) | Your ranged weapon speed (for warces mode) |
| `use_arcane` | checkbox | false | Use Arcane Shot | Weave Arcane Shot into rotation (mana-intensive) |
| `arcane_shot_mana` | slider | 15 | Arcane Shot Min Mana (%) | Only use Arcane Shot above this mana% |
| `use_serpent_sting` | checkbox | false | Serpent Sting | Maintain Serpent Sting DoT |
| `use_scorpid_sting` | checkbox | false | Scorpid Sting (Boss Only) | Apply Scorpid Sting on boss targets |
| `use_viper_sting_pve` | checkbox | false | Viper Sting (PvE) | Apply Viper Sting on mana-using PvE targets |
| `static_mark` | checkbox | true | Static Mark | Don't switch Hunter's Mark until it expires |
| `boss_mark` | checkbox | false | Boss Only Mark | Only apply Hunter's Mark on boss targets |
| `freezing_trap_pve` | checkbox | true | Freezing Trap on Adds | Drop Freezing Trap when multiple enemies are on you |
| `protect_freeze` | checkbox | true | Protect Frozen Target | Auto-switch target away from frozen enemies |
| `concussive_shot_pve` | checkbox | true | Concussive Shot (PvE) | Slow mobs running at you |
| `intimidation_pve` | checkbox | true | Intimidation (PvE) | Use Intimidation stun on aggro swap |

### Tab 3: Cooldowns
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_bestial_wrath` | checkbox | true | Bestial Wrath | Use BW on cooldown during burst |
| `use_rapid_fire` | checkbox | true | Rapid Fire | Use Rapid Fire on cooldown |
| `use_readiness` | checkbox | true | Readiness | Use Readiness to reset cooldowns |
| `use_racial` | checkbox | true | Racial | Use racial DPS cooldown during burst |
| `auto_sync_cds` | checkbox | false | Sync CDs with Bloodlust/Drums | Only pop burst CDs during haste buffs |
| `use_haste_potion` | checkbox | false | Use Haste Potion (Burst) | Use Haste Potion during burst phase |
| `readiness_rapid_fire` | checkbox | true | Reset Rapid Fire | Use Readiness when RF is on long CD |
| `readiness_misdirection` | checkbox | false | Reset Misdirection | Use Readiness when Misdirection is on CD |
| `aspect_hawk` | checkbox | true | Aspect of the Hawk | Auto-switch to Hawk in combat |
| `aspect_cheetah` | checkbox | true | Aspect of the Cheetah | Auto-switch to Cheetah OOC |
| `aspect_viper` | checkbox | true | Aspect of the Viper | Auto-switch to Viper when mana is low |
| `mana_viper_start` | slider | 10 | Viper On Mana (%) | Switch to Viper below this mana% |
| `mana_viper_end` | slider | 30 | Viper Off Mana (%) | Switch off Viper above this mana% |
| `mana_save` | slider | 30 | Mana Save (%) | Don't spend mana on expensive shots below this% |

### Tab 4: PvP
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `viper_sting_priest` | checkbox | true | Priest | Use Viper Sting on Priests |
| `viper_sting_paladin` | checkbox | true | Paladin | Use Viper Sting on Paladins |
| `viper_sting_shaman` | checkbox | true | Shaman | Use Viper Sting on Shamans |
| `viper_sting_druid` | checkbox | true | Druid | Use Viper Sting on Druids |
| `viper_sting_mage` | checkbox | true | Mage | Use Viper Sting on Mages |
| `viper_sting_warlock` | checkbox | true | Warlock | Use Viper Sting on Warlocks |
| `viper_sting_hunter` | checkbox | false | Hunter | Use Viper Sting on Hunters |
| `viper_sting_hp_threshold` | slider | 30 | Skip Below HP (%) | Skip Viper Sting if target HP below this |
| `wing_clip_hp_pvp` | slider | 20 | Wing Clip PvP HP (%) | Use Wing Clip if target HP >= this |
| `wing_clip_hp_pve` | slider | 20 | Wing Clip PvE HP (%) | Use Wing Clip if target HP >= this |

### Tab 5: Pet & Diagnostics
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `mend_pet_hp` | slider | 30 | Mend Pet HP (%) | Heal pet below this HP% |
| `experimental_pet` | checkbox | false | Experimental Pet Controller | Auto pet-attack controller |
| `clip_tracker_enabled` | checkbox | false | Enable Clip Tracker | Track auto shot clipping events |
| `show_clip_tracker` | checkbox | false | Show Clip Tracker UI | Show/hide the clip tracker window |
| `clip_print_summary` | checkbox | true | Print Combat Summary | Print clip summary after combat |
| `clip_threshold_1` | slider | 125 | Green/Yellow (ms) | Trivial clip threshold |
| `clip_threshold_2` | slider | 250 | Yellow/Orange (ms) | Significant clip threshold |
| `clip_threshold_3` | slider | 500 | Orange/Red (ms) | Severe clip threshold |
| `show_debug_panel` | checkbox | false | Show Debug Panel | Show real-time debug information |

---

## 10. Strategy Breakdown Per Playstyle

### Architecture Note
Unlike Mage (which has three completely different rotations), TBC Hunter has ONE core rotation across all three specs: **Steady Shot weaving between Auto Shots**. The specs differ primarily in:
- Which cooldowns are available (BM: Bestial Wrath; MM: Readiness + Silencing Shot; SV: Expose Weakness passive)
- Pet DPS contribution (BM >> MM/SV)
- Minor shot priority differences

The existing implementation uses a single `"ranged"` playstyle for all specs, which is the correct approach. Spec detection is not needed — the rotation uses `IsReady()` checks on talent-dependent abilities (Bestial Wrath, Readiness, Silencing Shot) which naturally handle spec differences.

### Ranged Playstyle Strategies (priority order)
```
[1]  Interrupt              — Silencing Shot / Scatter Shot on enemy casts
[2]  OOC_AspectViper        — switch to Viper when mana low (any combat state)
[3]  OOC_AspectCheetah      — switch to Cheetah OOC for travel
[4]  OOC_CallPet            — summon pet if not active
[5]  OOC_RevivePet          — revive dead pet
[6]  CombatRotation         — the full EnemyRotation (see below)
```

### Inside CombatRotation (EnemyRotation priority)
```
[R-1]  ImmuneCheck          — stop attacking immune targets
[R-2]  TranquilizingShot    — dispel enrage effects
[R-3]  Misdirection         — threat redirect on pull or aggro
[R-4]  AspectOfTheHawk      — ensure correct combat aspect
[R-5]  Readiness            — reset Rapid Fire / Misdirection CDs
[R-6]  ProtectFrozenTarget  — auto-switch off CC'd target
[R-7]  FreezingTrap         — CC adds
[R-8]  MendPet              — heal pet
[R-9]  HuntersMark          — maintain debuff
[R-10] PetAttack            — ensure pet is attacking
[R-11] KillCommand          — off-GCD, on 5s CD
--- RANGED SECTION (at range) ---
[R-12] AutoShoot            — ensure auto-shooting
[R-13] Intimidation         — stun on aggro swap
[R-14] ConcussiveShot       — slow runners
[R-15] ViperSting           — PvP mana drain
[R-16] BurstCooldowns       — Bestial Wrath, Rapid Fire, Readiness, racials, trinkets, Haste Potion
[R-17] MovingArcaneShot     — instant while moving
[R-18] ShotWeaving          — Steady Shot / Multi-Shot / Arcane Shot / Stings timing
--- MELEE SECTION (in melee) ---
[R-19] Disengage            — threat reduction
[R-20] ExplosiveTrap        — AoE in melee
[R-21] WingClip             — slow target
[R-22] MongooseBite         — melee damage
[R-23] RaptorStrike         — melee damage
[R-24] AutoAttack           — ensure auto-attacking in melee
```

### Shared Middleware (all specs)
```
[MW-300]  Hunter_Healthstone     — emergency healthstone at HP threshold
[MW-295]  Hunter_HealingPotion   — healing potion at HP threshold
[MW-280]  Hunter_ManaRune        — Dark/Demonic Rune at mana threshold
```

### Shot Weaving Logic (inside CombatRotation)
The shot weaving section is the most complex part. Two modes:

**Standard Mode** (swing timer based):
```lua
if ShootTimer < SteadyCastTime and (ShootTimer > MultiCastTime or ShootTimer <= latency) then
    -- Window between auto shots: can fit a shot
    Priority: Multi-Shot > Stings > Arcane Shot > Steady Shot
end
```

**Warces Haste Mode** (GCD + latency adjusted):
```lua
available = ShootTimer - gcdLeft - latency
if GCD <= weaponSpeed then
    -- Fast weapon: 1:1 ratio
    Multi-Shot (if available >= MultiCast and < SteadyCast)
    Arcane Shot (if available < MultiCast and > 0)
    Steady Shot (if available >= SteadyCast)
end
if GCD > weaponSpeed then
    -- Slow weapon: extended ratio
    Same priorities but with different timing windows
end
```

---

## Key Implementation Notes

### Playstyle Detection
Hunter uses a **single "ranged" playstyle** for all specs. This is correct because:
- All specs use the same core Steady Shot weaving rotation
- Spec-specific abilities are handled by `IsReady()` checks (talent-dependent spells return false if not talented)
- No stances or forms to detect
- No need for a user dropdown — the rotation naturally adapts

### No Idle Playstyle
Hunter has `idle_playstyle_name = nil`. OOC behaviors (Aspect of Cheetah, Call Pet, Revive Pet) are handled as strategies within the "ranged" playstyle with `requires_combat = false` checks.

### extend_context Fields
```lua
ctx.weapon_speed = UnitRangedDamage("player") or 3.0
ctx.combat_time = Unit("player"):CombatTime() or 0
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.shoot_timer = Player:GetSwingShoot()
ctx.pet_exists = Unit("pet"):IsExists()
ctx.pet_dead = UnitIsDeadOrGhost("pet") or Unit("pet"):IsDead()
ctx.pet_active = Pet:IsActive() or (ctx.pet_exists and not ctx.pet_dead)
ctx.pet_hp = Unit("pet"):HealthPercent() or 0
```

### Range Functions (cached)
```lua
-- AtRange: can use ranged abilities (Arcane Shot range check)
AtRange = A.MakeFunctionCachedDynamic(function(unit) return A.ArcaneShot:IsInRange(unit) end)

-- InMelee: in melee range (Wing Clip range check)
InMelee = A.MakeFunctionCachedDynamic(function(unit) return A.WingClip:IsInRange(unit) end)

-- GetRange: exact range in yards
GetRange = A.MakeFunctionCachedDynamic(function(unit) return Unit(unit):GetRange() or 0 end)
```

### Auto Shot Clip Tracker
The existing implementation includes a sophisticated clip tracking system (`cliptracker.lua`) that:
- Monitors COMBAT_LOG_EVENT_UNFILTERED for Auto Shot (spell ID 75)
- Measures delay between expected and actual auto shot timing
- Categorizes clips by severity (Green/Yellow/Orange/Red)
- Attributes clips to causes (cast-bar spells, movement, melee, instant casts)
- Provides combat summaries and CSV export
- Tracks melee interlude detection (Raptor Strike, Mongoose Bite, Wing Clip events)

### Immunity Handling
The existing implementation has comprehensive immunity tables:
```lua
-- PvP immunities
Constants.TOTAL_IMUN = { 642, 1020, 45438, 11958, 1022, 5599, 10278, 31224, 33786, 710, 18647 }
Constants.PHYS_IMUN = { ... }
Constants.MAGIC_IMUN = { ... }
Constants.CC_IMUN = { 19574, 34471, 18499, 1719, 31224, 642, 1020, 45438, 11958, 33786 }

-- PvE boss immunity phases (e.g., Illidan transitions)
Constants.PVE_IMMUNITY_BUFFS = { 39872, 41450, 41451, ... }

-- Arcane-immune NPCs (skip Arcane Shot/Hunter's Mark on these)
Constants.ARCANE_IMMUNE = { [18864]=true, [18865]=true, [15691]=true, [20478]=true }
```

### Pet Library Integration
```lua
local Pet = LibStub("PetLibrary")
Pet:AddActionsSpells(3, {
    -- Bite ranks: 17253-27050
    -- Claw ranks: 16827-27049
    -- Gore ranks: 35290-35298
}, true)
```

### Pet Stat Inheritance (from wowsims)
```
Stamina:     30% of owner
Armor:       35% of owner
Attack Power: 22% of owner's RAP
Spell Power:  12.8% of owner's RAP
```

Pet damage multipliers by type:
| Pet | Damage Mult | Abilities |
|-----|-------------|-----------|
| Cat | 1.10 | Bite + Claw |
| Raptor | 1.10 | Bite + Claw |
| Ravager | 1.10 | Bite + Gore |
| Wind Serpent | 1.07 | Bite + Lightning Breath |
| Bat | 1.07 | Bite + Screech |
| Owl | 1.07 | Claw + Screech |
| Crab | 0.95 | Claw only |
| Bear | 0.91 | Bite + Claw |

---

## WoWSims Rotation Mechanics (Detailed)

### Two Rotation Modes in wowsims

**Lazy Rotation** (simple priority):
1. Priority GCDs: Aspect swap (Hawk↔Viper), Scorpid/Serpent Sting refresh
2. Melee Weave: If weaving enabled and mainhand swing available and no auto shot or GCD ready
3. Auto Shot: If auto shot ready before GCD, or waiting for mana
4. Multi-Shot: If enabled and ready
5. Arcane Shot: If enabled AND Steady Shot would clip auto shot (`gcdAt + steadyShotCastTime > shootAt`)
6. Steady Shot: Default filler

**Adaptive Rotation** (DPS optimization):
Calculates expected net damage for each option:
```
net_damage = avg_ability_damage - (DPS_of_delayed_abilities * delay_caused)
```
Options: Shoot, Weave, Steady, Multi, Arcane — highest net damage wins.
Uses a presimulation with the lazy rotation to calibrate damage values.

### Critical Timing Facts
1. **GCD is fixed at 1.5s** — haste does NOT reduce Hunter GCD
2. **Steady Shot cast time** = `1500ms / rangedSwingSpeed` (scales with haste)
3. **Multi-Shot cast time** = `500ms / rangedSwingSpeed` (faster than Steady Shot)
4. **Arcane Shot is instant** (only adds latency) — best filler when Steady would clip
5. **Kill Command is BLOCKED during Steady Shot cast** — cannot fire KC mid-cast
6. **Aimed Shot is precast-only** in wowsims — used at time=0, never during rotation

### Melee Weave Modes (from wowsims)
| Mode | Value | Description |
|------|-------|-------------|
| WeaveNone | 0 | No melee weaving |
| WeaveAutosOnly | 1 | Melee auto attacks only (no Raptor Strike) |
| WeaveRaptorOnly | 2 | Only weave when Raptor Strike is off CD |
| WeaveFull | 3 | Both melee autos and Raptor Strike |

Weave conditions: weaving enabled + Raptor Strike ready (if RaptorOnly) + mainhand available + auto shot not ready + (GCD not ready OR waiting for mana)

### Viper Mana Regeneration Formula (from wowsims)
```
percentMana = clamp(currentManaPercent, 0.2, 0.9)
scaling = (22/35) * (0.9 - percentMana) + 0.11
bonusPer5 = Intellect * scaling + 0.35 * 70
manaGain = bonusPer5 * 2 / 5  (per 2-second tick)
```

### Damage Formulas (from wowsims)
| Ability | Formula |
|---------|---------|
| Steady Shot | `RAP * 0.2 + (baseDamage * 2.8 / swingSpeed) + 150` |
| Multi-Shot | `RAP * 0.2 + baseDamage + ammoDmg + bonusWeaponDmg + 205` |
| Arcane Shot | `RAP * 0.15 + 273` |
| Aimed Shot | `RAP * 0.2 + baseDamage + ammoDmg + bonusWeaponDmg + 870` |
| Serpent Sting/tick | `(132 + RAP * 0.02) * (1 + 0.06 * ImpStings)` |
| Kill Command (pet) | 127 base melee + Focused Fire crit bonus |

### Mana Cost Reduction Talents
- **Efficiency** (all shots): -2% per rank (5 ranks = -10%)
- **Demon Stalker 4pc** (Multi-Shot): additional -10%
- **Resourcefulness** (Raptor Strike, traps): -20% per rank

### Known Codebase Issues
- **Typo**: `WyvernString` in `class.lua` line 100 should be `WyvernSting`
