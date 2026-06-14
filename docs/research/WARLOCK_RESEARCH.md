# TBC Warlock Implementation Research

Comprehensive research for implementing Affliction, Demonology, and Destruction Warlock playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Affliction Warlock Rotation & Strategies](#2-affliction-warlock-rotation--strategies)
3. [Demonology Warlock Rotation & Strategies](#3-demonology-warlock-rotation--strategies)
4. [Destruction Warlock Rotation & Strategies](#4-destruction-warlock-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Mana Management System](#7-mana-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Proposed Settings Schema](#9-proposed-settings-schema)
10. [Strategy Breakdown Per Playstyle](#10-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

**wowsims/tbc verified IDs**: Shadow Bolt 27209 (420 mana), CoE 27228 (145 mana), CoR 27226 (160 mana), CoT 11719 (110 mana), CoA 27218 (265 mana), CoD 30910 (380 mana), Amplify Curse 18288, Nightfall proc 17941, ISB debuff stacks reset to 4 on SB crit.

### Core Damage Spells (Direct)
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Shadow Bolt (R11) | 27209 | 3.0s (2.5s w/ Bane) | 420 | Primary nuke, all specs |
| Incinerate (R2) | 32231 | 2.5s | 355 | TBC fire nuke, +25% dmg if Immolate on target |
| Searing Pain (R8) | 30459 | 1.5s | 205 | Fast cast, high threat |
| Soul Fire (R4) | 30545 | 6.0s (5.5s w/ Bane) | 250 | Big nuke, costs 1 Soul Shard |
| Shadowburn (R8) | 30546 | Instant | 515 | Destro talent, costs 1 Soul Shard, 15s CD |
| Conflagrate (R6) | 30912 | Instant | 305 | Destro talent, CONSUMES Immolate, 10s CD |
| Death Coil (R4) | 27223 | Instant | 600 | 3s Horror + heal, 2 min CD |

### DoT Spells
| Spell | ID | Cast/Dur | Mana | Notes |
|-------|------|----------|------|-------|
| Corruption (R8) | 27216 | Instant (talented)/18s | 370 | Shadow DoT, core Affliction |
| Immolate (R9) | 27215 | 2.0s (1.5s w/ Bane)/15s | 445 | Fire DoT, Destro priority |
| Curse of Agony (R7) | 27218 | Instant/24s | 265 | Accelerating damage, 12 ticks |
| Curse of Doom (R2) | 30910 | Instant/60s | 380 | Single tick at 60s, 60s CD |
| Curse of the Elements (R4) | 27228 | Instant/5min | 145 | -88 resists, +10% spell dmg taken |
| Unstable Affliction (R3) | 30405 | 1.5s/18s | 400 | 41pt Affliction talent, dmg on dispel |
| Siphon Life (R6) | 30911 | Instant/30s | 410 | Shadow DoT + heal, Affliction talent |
| Seed of Corruption | 27243 | 2.0s | 882 | AoE: explodes at 1044 accumulated dmg |

### Channel Spells
| Spell | ID | Duration | Mana | Notes |
|-------|------|----------|------|-------|
| Drain Life (R8) | 27220 | 5s channel | 355 | HP drain, 5 ticks |
| Drain Soul (R5) | 27217 | 15s channel | 360 | Shard on kill, execute w/ Soul Siphon |
| Drain Mana (R5) | 27221 | 5s channel | 0 | Mana drain (PVP), no mana cost |
| Health Funnel (R8) | 27259 | 10s channel | 693 | Heal pet |

### AoE Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Seed of Corruption | 27243 | 2.0s | 882 | DoT + explosion, primary warlock AoE |
| Rain of Fire (R5) | 27212 | 8s channel | 1480 | Ground AoE channel |
| Hellfire (R4) | 27213 | 15s channel | 1665 | PB AoE, damages self |
| Shadowfury (R3) | 30414 | 0.5s | 710 | 41pt Destro talent, AoE stun |

### Curse Spells
| Spell | ID | Duration | Mana | Notes |
|-------|------|----------|------|-------|
| Curse of the Elements (R4) | 27228 | 5 min | 145 | -88 resists, +10% spell dmg (all schools) |
| Curse of Agony (R7) | 27218 | 24s | 265 | Shadow DoT, accelerating ticks |
| Curse of Doom (R2) | 30910 | 60s | 380 | 7300 dmg at expiry, 60s CD |
| Curse of Recklessness (R5) | 27226 | 2 min | 160 | -800 armor, immune to fear |
| Curse of Tongues (R2) | 11719 | 30s | 110 | +60% cast time |
| Curse of Weakness (R8) | 30909 | 2 min | 150 | -257 melee AP |
| Curse of Exhaustion | 18223 | 12s | 156 | -30% movement (Affliction talent) |
| Amplify Curse | 18288 | — | — | Next CoD/CoA +50% effect, 3 min CD |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Shadow Bolt | 686 | 27209 (R11) | |
| Immolate | 348 | 27215 (R9) | |
| Corruption | 172 | 27216 (R8) | Instant w/ 5/5 Improved Corruption |
| Curse of Agony | 980 | 27218 (R7) | |
| Curse of the Elements | 1490 | 27228 (R4) | |
| Curse of Doom | 603 | 30910 (R2) | |
| Curse of Recklessness | 704 | 27226 (R5) | |
| Curse of Tongues | 1714 | 11719 (R2) | |
| Curse of Weakness | 702 | 30909 (R8) | |
| Siphon Life | 18265 | 30911 (R6) | Affliction talent |
| Drain Life | 689 | 27220 (R8) | |
| Drain Soul | 1120 | 27217 (R5) | |
| Drain Mana | 5138 | 27221 (R5) | |
| Life Tap | 1454 | 27222 (R7) | |
| Dark Pact | 18220 | 27265 (R4) | Affliction talent |
| Searing Pain | 5676 | 30459 (R8) | |
| Soul Fire | 6353 | 30545 (R4) | |
| Shadowburn | 17877 | 30546 (R8) | Destruction talent |
| Conflagrate | 17962 | 30912 (R6) | Destruction talent |
| Rain of Fire | 5740 | 27212 (R5) | |
| Hellfire | 1949 | 27213 (R4) | |
| Health Funnel | 755 | 27259 (R8) | |
| Death Coil | 6789 | 27223 (R4) | |
| Howl of Terror | 5484 | 17928 (R2) | |
| Fear | 5782 | 6215 (R3) | |
| Banish | 710 | 18647 (R2) | |
| Shadow Ward | 6229 | 28610 (R5) | |
| Demon Armor | 706 | 27260 (R6) | |
| Create Healthstone | 6201 | 27230 (Fel) | |
| Create Soulstone | 693 | 27239 (Fel) | |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Incinerate | 29722 | TBC ability (R1); R2 = 32231 |
| Seed of Corruption | 27243 | TBC ability |
| Unstable Affliction | 30108 | Affliction 41pt talent (R1); R2=30404, R3=30405 |
| Soulshatter | 29858 | TBC ability, -50% threat, 3 min CD, 1 shard |
| Ritual of Souls | 29893 | TBC ability, creates Soulwell |
| Fel Armor (R1) | 28176 | TBC ability (+50 spell dmg) |
| Fel Armor (R2) | 28189 | TBC ability (+100 spell dmg) |
| Shadowfury | 30283 | Destro 41pt talent (R1); R2=30413, R3=30414 |
| Curse of Exhaustion | 18223 | Affliction talent |
| Amplify Curse | 18288 | Affliction talent, 3 min CD |
| Demonic Sacrifice | 18788 | Demonology talent |
| Soul Link | 19028 | Demonology talent |
| Fel Domination | 18708 | Demonology talent, 15 min CD |
| Summon Felguard | 30146 | Demonology 41pt talent |

### Pet Summon Spells
| Pet | Summon ID | Notes |
|-----|-----------|-------|
| Imp | 688 | Costs 1 Soul Shard |
| Voidwalker | 697 | Costs 1 Soul Shard |
| Succubus | 712 | Costs 1 Soul Shard |
| Felhunter | 691 | Costs 1 Soul Shard |
| Felguard | 30146 | Costs 1 Soul Shard, Demonology 41pt talent |

### Key Pet Abilities
| Pet | Ability | ID | Notes |
|-----|---------|------|-------|
| Imp | Firebolt (R8) | 27267 | 1.5s cast nuke (base: 3110) |
| Imp | Blood Pact (R5) | 27268 | +66 Stamina party buff (base: 6307) |
| Imp | Phase Shift | 4511 | Invisible/passive mode |
| Succubus | Lash of Pain (R7) | 27274 | Instant, 12s CD (base: 7814) |
| Succubus | Seduction | 6358 | 15s charm CC |
| Felhunter | Spell Lock | 19647 | Interrupt + 6s silence, 24s CD |
| Felhunter | Devour Magic (R6) | 27276 | Purge/dispel (base: 19505) |
| Felguard | Cleave (R1) | 30213 | Hits +1 target, 6s CD |
| Felguard | Intercept | 30151 | Charge + stun, 30s CD |
| Felguard | Anguish | 33698 | Taunt, 10s CD |
| Felguard | Demonic Frenzy | 32851 | Passive: +5% AP per stack, max 10 |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Amplify Curse | 18288 | 3 min | Next curse | +50% CoD/CoA effect |
| Death Coil | 27223 | 2 min | — | 3s Horror + self-heal |
| Howl of Terror | 17928 | 40s | 8s | AoE fear |
| Shadowburn | 30546 | 15s | — | Instant nuke, 1 shard |
| Conflagrate | 30912 | 10s | — | Consumes Immolate |
| Shadowfury | 30414 | 20s | 2s | AoE stun (talent) |
| Soulshatter | 29858 | 3 min | — | -50% threat, 1 shard |
| Fel Domination | 18708 | 15 min | — | Instant pet summon |

### Demonic Sacrifice Buffs
| Pet Sacrificed | Buff Name | Buff ID | Effect | Duration |
|---------------|-----------|---------|--------|----------|
| Imp | Burning Wish | 18789 | +15% fire damage | 30 min |
| Voidwalker | Fel Stamina | 18790 | 2% HP regen per 4s | 30 min |
| Succubus | Touch of Shadow | 18791 | +15% shadow damage | 30 min |
| Felhunter | Fel Energy | 18792 | 3% mana regen per 4s | 30 min |

**wowsims/tbc `warlock.go` confirms**: Succubus sacrifice = `ShadowDamageDealtMultiplier *= 1.15`, Imp sacrifice = `FireDamageDealtMultiplier *= 1.15`, Felguard sacrifice = `ShadowDamageDealtMultiplier *= 1.10`. Felguard sacrifice is strictly inferior to Succubus for shadow builds — Demo warlocks always keep Felguard alive.

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Death Coil (R4) | 27223 | 2 min | 3s Horror + self-heal, instant |
| Howl of Terror (R2) | 17928 | 40s | AoE fear, 1.5s cast |
| Fear (R3) | 6215 | — | Single-target CC, 1.5s cast |
| Banish (R2) | 18647 | — | Demon/elemental CC, 1.5s cast |
| Shadow Ward (R5) | 28610 | — | Absorb shadow damage |
| Soulshatter | 29858 | 3 min | -50% threat, costs 1 shard |
| Health Funnel (R8) | 27259 | — | Channel heal on pet |
| Drain Life (R8) | 27220 | — | Self-heal channel |

### Self-Buffs
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Fel Armor (R2) | 28189 | 30 min | +100 spell damage, 20% of HP regen → spell power |
| Demon Armor (R6) | 27260 | 30 min | +armor, +HP regen, +20% healing received |
| Soul Link | 19028 | While pet alive | 20% dmg transferred to pet (Demo talent) |

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Orc | Blood Fury (caster) | 33702 | +spell power for 15s, 2 min CD |
| Blood Elf | Arcane Torrent | 28730 | Silence 2s + mana restore, 2 min CD |
| Undead | Will of the Forsaken | 7744 | Removes charm/fear/sleep |
| Gnome | Escape Artist | 20589 | Removes root/snare |
| Human | Perception | 20600 | +50 stealth detection for 20s |

### Debuff IDs (for tracking on target)
| Debuff | ID | Notes |
|--------|------|-------|
| Shadow Vulnerability (ISB) | 17800 | +20% shadow dmg, 4 charges, 12s |
| Shadow Embrace | 32386 | -5% phys dmg dealt (from Corruption/SL/CoA/Seed hits) |
| Corruption (R8) | 27216 | Shadow DoT |
| Immolate (R9) | 27215 | Fire DoT |
| Curse of Agony (R7) | 27218 | Shadow DoT |
| Curse of the Elements (R4) | 27228 | -resists, +10% spell dmg |
| Curse of Doom (R2) | 30910 | 60s delayed damage |
| Unstable Affliction (R3) | 30405 | Shadow DoT, 1575 dmg on dispel |
| Siphon Life (R6) | 30911 | Shadow DoT + heal |
| Seed of Corruption | 27243 | Shadow DoT, explodes |

### Buff IDs (for tracking on self)
| Buff | ID | Notes |
|------|------|-------|
| Shadow Trance (Nightfall) | 17941 | Instant Shadow Bolt proc, 10s |
| Backlash | 34936 | Instant SB/Incinerate proc, 8s |
| Fel Armor (R2) | 28189 | +100 spell dmg active |
| Demon Armor (R6) | 27260 | Armor buff active |
| Burning Wish (DS Imp) | 18789 | +15% fire dmg |
| Touch of Shadow (DS Succ) | 18791 | +15% shadow dmg |
| Fel Stamina (DS VW) | 18790 | HP regen |
| Fel Energy (DS FH) | 18792 | Mana regen |
| Soul Link buff | 19028 | Dmg split active |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP |
| Demonic Rune | 12662 | Same as Dark Rune (separate item, shares CD) |
| Destruction Potion | 22839 | +120 SP, +2% spell crit for 15s |
| Flame Cap | 22788 | +80 fire spell power for 1 min |
| Fel Healthstone | 22103 | Warlock-crafted healthstone item |
| Soul Shard | 6265 | Resource item, consumed by certain spells |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+) or later:
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Haunt | Wrath (3.0) | Affliction has no Haunt spell |
| Chaos Bolt | Wrath (3.0) | Destruction nuke doesn't exist |
| Metamorphosis | Wrath (3.0) | No demon form transformation |
| Demonic Empowerment | Wrath (3.0) | No pet empowerment cooldown |
| Demonic Pact | Wrath (3.0) | No raid-wide spell power buff from Demo |
| Decimation | Wrath (3.0) | No Soul Fire execute phase |
| Molten Core (talent) | Wrath (3.0) | No Incinerate proc from Corruption |
| Shadowflame | Wrath (3.0) | Cone spell doesn't exist |
| Fel Flame | Cataclysm (4.0) | Instant filler doesn't exist |
| Pandemic | Cataclysm (4.0) | No DoT crit mechanic |
| Soul Swap | Cataclysm (4.0) | No DoT transfer mechanic |
| Soulburn | Cataclysm (4.0) | No soul shard empowerment mechanic |
| Conflagrate (no consume) | Wrath redesign | In TBC, Conflagrate CONSUMES Immolate from target |
| Fel Intelligence (pet) | Wrath (3.0) | Felhunter has no Int/Spirit buff in TBC |

**What IS new in TBC (vs Classic):**
- Incinerate (level 64 trained) — fire nuke, core Destruction filler
- Seed of Corruption (level 70 trained) — primary warlock AoE
- Unstable Affliction (41-point Affliction talent) — shadow DoT, punishes dispel
- Felguard (41-point Demonology talent) — strongest pet
- Shadowfury (41-point Destruction talent) — AoE stun
- Fel Armor — +spell damage self-buff
- Soulshatter — threat dump
- Ritual of Souls — group healthstone well
- Incinerate + Immolate synergy — +25% Incinerate damage when Immolate is on target

---

## 2. Affliction Warlock Rotation & Strategies

### Core Mechanic: DoT Maintenance + Shadow Bolt Filler
Affliction is a DoT-centric spec. Maintain all DoTs, apply assigned curse, fill with Shadow Bolt. Nightfall (Shadow Trance) procs provide free instant Shadow Bolts.

### Popular Builds
- **SM/Ruin** (Shadow Mastery / Ruin): Affliction/Destruction hybrid — +10% shadow damage + +100% crit bonus
- **UA (Unstable Affliction)**: Deep Affliction — adds UA to DoT rotation, trades Ruin for UA
- Both play nearly identically: DoTs → Shadow Bolt filler

### Improved Shadow Bolt (ISB) Debuff
- Shadow Bolt critical strikes apply "Shadow Vulnerability" (ID: 17800) on target
- +20% shadow damage taken, 4 charges, 12 second duration
- Charges consumed by non-periodic shadow damage sources
- In a raid with multiple warlocks, ISB stays up passively
- Solo: depends on crit rate (~25-30% needed for reliable uptime)

### Shadow Embrace Debuff (Affliction Talent)
- Applied by Corruption, Siphon Life, Curse of Agony, and Seed of Corruption hits (NOT Shadow Bolt)
- Debuff ID: 32386, reduces target's physical damage dealt by 1-5% (depending on talent ranks)
- Duration: 12 seconds, refreshed by each qualifying spell hit
- Passive benefit — DoT maintenance keeps it up automatically, no special action needed
- **Source**: wowsims/tbc `talents.go` confirms: `spell == warlock.Corruption || spell == warlock.SiphonLife || spell == warlock.CurseOfAgony || spell.SameAction(warlock.Seeds[0].ActionID)`

### Single Target Rotation
From wowsims/tbc `rotations.go` (verified priority order):
1. **Curse** (assigned) — Curse of Elements / Curse of Doom / Curse of Agony
   - CoD special: when fight < 60s remaining, falls back to CoA if both DoTs are down
   - Amplify Curse cast before CoD/CoA when available
2. **Unstable Affliction** — maintain (if talented), reapply when dot falls off
3. **Corruption** — maintain (if enabled), reapply when dot falls off
4. **Siphon Life** — maintain (if talented), **BUT only when ISB debuff is active on target**
   - wowsims optimization: don't waste a GCD on Siphon Life without +20% shadow from ISB
5. **Immolate** — maintain (if enabled), reapply when dot falls off
6. **Shadow Bolt** — primary filler (or Incinerate if configured)
7. **Life Tap** — fallback when any spell fails due to insufficient mana
8. **Shadow Trance proc** — instant SB, cast IMMEDIATELY when Nightfall procs (buff ID: 17941)
   - Note: wowsims doesn't explicitly prioritize this (Nightfall makes SB instant via ModifyCast)
9. **Drain Soul execute** — at target < 25% HP with Soul Siphon talent (+4% per affliction effect)
   - Note: not implemented in wowsims sim, but recommended by TBC Classic guides

### DoT Refresh Rules
```
Corruption:   Instant cast → refresh freely when < 1.5s remaining or fallen off
UA:           1.5s cast → start casting when < 3s remaining
Siphon Life:  Instant cast → refresh when < 1.5s remaining
Immolate:     2.0s cast → refresh when < 3s remaining (1.5s w/ Bane)
CoA:          NEVER clip early — accelerating damage (last ticks hit hardest)
CoD:          60s CD — reapply exactly on expiry
CoE:          5 min duration — low maintenance
```

### Life Tap Pattern (Affliction)
- DoTs keep ticking while Life Tapping — less DPS loss than other specs
- Tap when mana < 30%, avoid tapping when HP < 40%
- Dark Pact first if pet alive and pet has mana (Affliction talent)
- Improved Life Tap talent: +20% mana gained

### Pet Choice
- **Imp** — Blood Pact (+66 Stam party buff) + Firebolt DPS. Default raid choice.
- **Succubus** — Higher pet DPS via Lash of Pain. Used if another warlock provides Blood Pact.
- **Felhunter** — Largest mana pool for Dark Pact. Spell Lock interrupt utility.

### State Tracking Needed
```lua
-- Debuffs on target
affliction_state.corruption_duration = Unit(TARGET):HasDeBuffs(27216) or 0
affliction_state.ua_duration = Unit(TARGET):HasDeBuffs(30405) or 0
affliction_state.siphon_duration = Unit(TARGET):HasDeBuffs(30911) or 0
affliction_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0
affliction_state.coa_duration = Unit(TARGET):HasDeBuffs(27218) or 0
affliction_state.cod_duration = Unit(TARGET):HasDeBuffs(30910) or 0
affliction_state.coe_duration = Unit(TARGET):HasDeBuffs(27228) or 0
affliction_state.isb_active = (Unit(TARGET):HasDeBuffs(17800) or 0) > 0

-- Self buffs
affliction_state.shadow_trance = (Unit("player"):HasBuffs(17941) or 0) > 0
```

---

## 3. Demonology Warlock Rotation & Strategies

### Core Mechanic: Felguard Pet DPS + Shadow Bolt
Demonology revolves around the Felguard pet. The warlock provides Shadow Bolt spam while the Felguard contributes ~15-20% of total DPS via melee + Cleave. Soul Link provides survivability.

### Key Talents Affecting Rotation
- **Summon Felguard** (41pt): Strong melee pet with Cleave, Intercept, Demonic Frenzy
- **Soul Link** (19028): 20% of damage taken transferred to pet — requires pet alive
- **Demonic Knowledge**: +spell power based on pet Stamina + Intellect
- **Master Demonologist**: +5% all damage with Felguard out
- **Demonic Sacrifice** (18788): Alternative — sacrifice pet for flat damage buff (different build)

### Build Variants
1. **Felguard Build** — Keep Felguard alive, Shadow Bolt spam + selective DoTs
2. **DS/Ruin Build** — Sacrifice Succubus (+15% shadow via 18791) or Imp (+15% fire via 18789), then Shadow Bolt or Incinerate spam. Technically a Demo/Destro hybrid.

### Felguard Build Single Target Rotation
1. **Curse** (assigned) — Curse of Elements / Curse of Doom / Curse of Agony
2. **Corruption** — maintain (instant w/ Improved Corruption)
3. **Immolate** — maintain (optional, depends on talent points)
4. **Shadow Bolt** — primary filler (majority of casts)
5. **Life Tap** — mana management
6. **Health Funnel** — keep Felguard alive when needed

### DS/Ruin Build Single Target Rotation
1. **Demonic Sacrifice** at start (Succubus for +15% shadow, or Imp for +15% fire)
2. **Curse** (assigned)
3. **Shadow Bolt** spam (shadow build) OR **Incinerate** spam (fire build)
4. **Life Tap** — mana management
5. *Extremely simple rotation* — no DoT maintenance needed, just nuke

### Pet Management (Felguard Build)
- Felguard auto-attacks and uses Cleave on CD
- Monitor pet HP — use Health Funnel if pet drops below threshold
- Fel Domination (18708, 15 min CD) for instant pet resummon if Felguard dies
- Soul Link (19028) means warlock takes less damage but pet takes more — healers need awareness

### State Tracking Needed
```lua
-- Pet state
demo_state.pet_exists = UnitExists("pet")
demo_state.pet_hp = Unit("pet"):HealthPercent() or 0
demo_state.pet_mana = <pet mana check>
demo_state.has_soul_link = (Unit("player"):HasBuffs(19028) or 0) > 0

-- DS/Ruin state
demo_state.has_ds_shadow = (Unit("player"):HasBuffs(18791) or 0) > 0  -- Touch of Shadow
demo_state.has_ds_fire = (Unit("player"):HasBuffs(18789) or 0) > 0    -- Burning Wish

-- Debuffs on target
demo_state.corruption_duration = Unit(TARGET):HasDeBuffs(27216) or 0
demo_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0
```

---

## 4. Destruction Warlock Rotation & Strategies

### Core Mechanic: Nuke Spam + ISB Uptime
Destruction is the simplest warlock spec. Shadow Destruction = Shadow Bolt spam. Fire Destruction = Immolate maintenance + Incinerate spam + Conflagrate.

### Build Variants
1. **Shadow Destruction** — Pure Shadow Bolt spam with Ruin (+100% crit bonus)
2. **Fire Destruction** — Incinerate + Immolate + Conflagrate (usually paired with DS Imp for +15% fire)

**Note**: wowsims/tbc does NOT implement Conflagrate, Shadowburn, or Drain Soul in its rotation. The sim only handles: Curse → DoTs → Shadow Bolt/Incinerate → Life Tap. The Conflagrate/Shadowburn strategies below are from TBC Classic guides and extend beyond the sim.

### Shadow Destruction Single Target Rotation
1. **Curse** (assigned)
2. **Shadow Bolt** — that's it. 95%+ of casts.
3. **Shadowburn** — instant execute at low target HP (costs shard, 15s CD)
4. **Life Tap** — mana management

### Fire Destruction Single Target Rotation
From wowsims/tbc:
1. **Maintain Immolate** — always top priority (Incinerate needs it for +25% damage)
2. **Conflagrate** — instant, use on CD, CONSUMES Immolate (must re-apply after!)
3. **Curse** (assigned)
4. **Incinerate** — primary filler (2.5s cast)
5. **Shadowburn** — execute phase (costs shard)
6. **Life Tap** — mana management

### Conflagrate + Immolate Tension (CRITICAL TBC MECHANIC)
In TBC, Conflagrate **consumes** the Immolate DoT on the target. Rotation must:
1. Cast Immolate
2. Wait for Conflagrate CD (10s)
3. Cast Conflagrate (instant, consumes Immolate)
4. Immediately re-apply Immolate
5. Fill with Incinerate between

This creates a mini-cycle: Immolate → Incinerate x3-4 → Conflagrate → Immolate → repeat

### Backlash Proc (Destruction Talent)
- Buff ID: 34936
- Triggered by being hit by a physical attack (1-3% chance depending on rank)
- Effect: Next Shadow Bolt or Incinerate is instant cast
- Duration: 8 seconds, 8s internal CD
- Cast immediately when proc is active
- Passive bonus: +1-3% spell crit chance (always active)

### Improved Shadow Bolt Maintenance
- Shadow Bolt crits apply ISB debuff (17800) → +20% shadow damage
- For Shadow Destro: ISB uptime is the only "mechanic" beyond SB spam
- For Fire Destro: ISB doesn't benefit fire spells — not relevant
- With ~30%+ crit and constant SB spam, ISB maintains itself

### State Tracking Needed
```lua
-- Fire Destro state
destro_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0
destro_state.conflag_cd = A.Conflagrate:GetCooldown() or 0

-- Shared state
destro_state.backlash_active = (Unit("player"):HasBuffs(34936) or 0) > 0
destro_state.isb_active = (Unit(TARGET):HasDeBuffs(17800) or 0) > 0
destro_state.target_below_25 = context.target_hp < 25
```

---

## 5. AoE Rotation (All Specs)

### Primary: Seed of Corruption (all specs)
- 2.0s cast, applies DoT on target
- When target accumulates 1044+ damage (from any source), seed explodes dealing AoE shadow damage
- One seed per warlock per target
- Multiple warlocks can seed different targets for chain explosions
- **Most efficient AoE**: Apply Seed of Corruption to multiple targets

### AoE Options
| Method | Best For | Notes |
|--------|----------|-------|
| Seed of Corruption | 3+ targets | Primary AoE, all specs |
| Rain of Fire | Stationary AoE | 8s channel, good for stacked enemies |
| Hellfire | Emergency melee AoE | Damages self, dangerous |
| Shadowfury | Burst AoE + stun | Destro 41pt talent, 20s CD |

### Spec-Specific AoE Additions
- **Affliction**: Seed of Corruption → tab-target seeds on multiple mobs
- **Demonology**: Seed of Corruption + Felguard Cleave on melee mobs
- **Destruction**: Shadowfury (instant AoE stun) → Seed of Corruption → Rain of Fire

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Death Coil** (27223) — instant 3s Horror + self-heal, 2 min CD
   - Use when: HP critically low, emergency CC + heal
2. **Drain Life** (27220) — channel self-heal when HP dangerously low
   - Use when: HP low, not at risk of dying instantly
3. **Shadow Ward** (28610) — absorb shadow damage
   - Use when: shadow damage encounter, pre-damage
4. **Soulshatter** (29858) — -50% threat, 3 min CD, costs 1 shard
   - Use when: threat is dangerously high

### Dispel/Utility
1. **Felhunter Spell Lock** (19647) — interrupt + 6s silence, 24s CD
   - Requires Felhunter pet active
2. **Felhunter Devour Magic** (27276) — purge enemy buff / dispel friendly debuff
   - Requires Felhunter pet active

### Self-Buffs (OOC)
1. **Armor**: Fel Armor (28189, +100 spell damage) vs Demon Armor (27260, +armor/HP regen)
   - All DPS specs → Fel Armor (always)
   - Tank/survival scenarios → Demon Armor (rare)
2. **Which pet to summon** (pre-combat):
   - Affliction → Imp (Blood Pact) or Succubus (DPS)
   - Demonology → Felguard (always)
   - Destruction (DS/Ruin) → Succubus (sacrifice for +15% shadow) or Imp (sacrifice for +15% fire)

---

## 7. Mana Management System

### Life Tap: The Warlock's "Evocation"
Warlocks have NO mana regeneration cooldown. Life Tap is the primary and only sustainable mana source. This makes warlock "healer-dependent" for mana.

### Life Tap Details
| Rank | Spell ID | Base HP→Mana |
|------|----------|-------------|
| R7 (max) | 27222 | 582 HP → 582 Mana |

- Scales with spell power at ~0.8 coefficient (80%)
- With ~1000 SP: ~1382 HP → ~1658 Mana (with Improved Life Tap)
- **Improved Life Tap** talent: +10%/+20% mana returned
- Triggers GCD (1.5s)

### Mana Recovery Priority
1. **Dark Pact** (27265, Affliction talent) — drains pet mana, zero HP cost
   - Use first when pet has mana (especially Felhunter — largest mana pool)
   - Falls back to Life Tap when pet is OOM
2. **Life Tap** (27222) — HP → mana conversion
   - Threshold: tap when mana% < `life_tap_mana_pct` (default ~30%)
   - Safety: don't tap when HP < `life_tap_min_hp` (default ~40%)
3. **Super Mana Potion** (22832) — use on CD when mana low
4. **Dark Rune / Demonic Rune** (20520 / 12662) — mana at HP cost, separate from potion CD
5. **Healthstone** (22103) — recover HP after excessive Life Tapping

### Regen Mode (from wowsims/tbc `rotations.go`)
The sim implements an intelligent regen mode for pre-cooldown mana pooling:
```
ENTER regen when ALL of:
  - mana% < 20%
  - next major DPS cooldown ready in < 15 seconds
  - fight remaining > 20 seconds
  - NOT during temporary spell power or haste buffs

DURING regen:
  - Spam Life Tap

EXIT regen when ANY of:
  - mana% > 60%
  - next major CD ready in < 2 seconds (stop regen, start blasting)
```
Life Tap is also the universal fallback — whenever any spell fails to cast (insufficient mana), Life Tap is used instead.

### Spec-Specific Mana Management
- **Affliction**: DoTs tick while Life Tapping → minimal DPS loss. Dark Pact if talented.
- **Demonology**: Life Tap only (Dark Pact would drain Felguard mana). Be careful not to Life Tap when Soul Link is transferring damage to a low-HP pet.
- **Destruction**: Life Tap between Shadow Bolt casts. Simple.

---

## 8. Cooldown Management

### Affliction Cooldown Priority
1. Amplify Curse (18288) — use before Curse of Doom or Agony for +50% effect
2. Trinkets — use on CD, pair with Bloodlust/Heroism if possible
3. Death Coil — emergency only
4. Racial (Blood Fury 33702 / Arcane Torrent 28730) — use on CD

### Demonology Cooldown Priority
1. Fel Domination (18708) — save for emergency pet resummon
2. Trinkets — use on CD
3. Death Coil — emergency only
4. Racial — use on CD

### Destruction Cooldown Priority
1. Shadowburn (30546) — use as execute at low target HP
2. Trinkets — use on CD
3. Destruction Potion (22839) — pair with trinkets
4. Racial — use on CD
5. Death Coil — emergency only

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "affliction" | Playstyle | Active playstyle ("affliction", "demonology", "destruction") |
| `use_fel_armor` | checkbox | true | Fel Armor | Auto-buff Fel Armor OOC |
| `curse_type` | dropdown | "elements" | Curse Assignment | Which curse to maintain ("elements", "agony", "doom", "recklessness", "tongues", "none") |
| `use_soulshatter` | checkbox | true | Auto Soulshatter | Use Soulshatter when threat is high |
| `aoe_mode` | dropdown | "off" | AoE Mode | AoE rotation mode ("off", "seed", "rain_of_fire") |
| `aoe_threshold` | slider | 3 | AoE Enemy Threshold | Minimum enemies to trigger AoE (2-8) |

### Tab 2: Affliction
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `aff_use_corruption` | checkbox | true | Use Corruption | Maintain Corruption DoT |
| `aff_use_ua` | checkbox | true | Use Unstable Affliction | Maintain UA DoT (if talented) |
| `aff_use_siphon_life` | checkbox | true | Use Siphon Life | Maintain Siphon Life DoT (if talented) |
| `aff_use_immolate` | checkbox | false | Use Immolate | Maintain Immolate DoT (some builds skip) |
| `aff_use_shadow_trance` | checkbox | true | Use Shadow Trance | Instant SB on Nightfall proc |
| `aff_use_drain_soul` | checkbox | true | Drain Soul Execute | Use Drain Soul below target HP threshold |
| `aff_drain_soul_hp` | slider | 25 | Drain Soul HP% | Switch to Drain Soul below this target HP% (10-50) |
| `aff_use_dark_pact` | checkbox | true | Use Dark Pact | Prefer Dark Pact over Life Tap (if talented) |
| `aff_use_amplify_curse` | checkbox | true | Use Amplify Curse | Auto-use Amplify Curse (if talented) |

### Tab 3: Demonology
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `demo_use_corruption` | checkbox | true | Use Corruption | Maintain Corruption DoT |
| `demo_use_immolate` | checkbox | false | Use Immolate | Maintain Immolate DoT |
| `demo_pet_heal_hp` | slider | 40 | Pet Heal HP% | Health Funnel pet below this HP% (10-70) |
| `demo_use_fel_domination` | checkbox | true | Use Fel Domination | Auto-use Fel Domination for emergency resummon |
| `demo_use_sacrifice` | checkbox | false | Use Demonic Sacrifice | Sacrifice pet instead of keeping alive (DS/Ruin build) |
| `demo_sacrifice_pet` | dropdown | "succubus" | Sacrifice Pet | Which pet to sacrifice ("succubus", "imp") |

### Tab 4: Destruction
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `destro_primary_spell` | dropdown | "shadow_bolt" | Primary Spell | Main filler spell ("shadow_bolt", "incinerate") |
| `destro_use_immolate` | checkbox | true | Use Immolate | Maintain Immolate (required for Incinerate build) |
| `destro_use_conflagrate` | checkbox | true | Use Conflagrate | Use Conflagrate on CD (if talented, consumes Immolate) |
| `destro_use_shadowburn` | checkbox | true | Use Shadowburn | Use Shadowburn as execute (costs Soul Shard) |
| `destro_shadowburn_hp` | slider | 10 | Shadowburn HP% | Use Shadowburn below this target HP% (5-25) |
| `destro_use_shadowfury` | checkbox | true | Use Shadowfury | Use Shadowfury on CD (if talented) |
| `destro_use_backlash` | checkbox | true | Use Backlash | Instant cast on Backlash proc |

### Tab 5: Cooldowns & Mana
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Blood Fury/Arcane Torrent) |
| `life_tap_mana_pct` | slider | 30 | Life Tap Mana% | Life Tap when mana below this% (10-60) |
| `life_tap_min_hp` | slider | 40 | Life Tap Min HP% | Don't Life Tap below this HP% (20-70) |
| `use_mana_potion` | checkbox | true | Use Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_pct` | slider | 30 | Mana Potion Below% | Use Mana Potion when mana below this% (10-80) |
| `use_dark_rune` | checkbox | true | Use Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_pct` | slider | 30 | Dark Rune Below% | Use Dark Rune when mana below this% (10-80) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use health potion below this HP% |
| `death_coil_hp` | slider | 20 | Death Coil HP% | Use Death Coil below this HP% (0=disable) |

---

## 10. Strategy Breakdown Per Playstyle

### Affliction Playstyle Strategies (priority order)
Matches wowsims/tbc `rotations.go` priority:
```
[1]  ShadowTranceProc        — if Nightfall proc active (buff 17941), instant Shadow Bolt
                               (handled via ModifyCast making SB instant, highest effective priority)
[2]  MaintainCurse           — apply assigned curse if missing/expired
                               CoD: Amplify Curse first if ready; fallback to CoA when fight < 60s
                               CoA: Amplify Curse first if ready
[3]  MaintainUA              — refresh UA when dot falls off (if talented + enabled)
[4]  MaintainCorruption      — refresh Corruption when dot falls off (if enabled)
[5]  MaintainSiphonLife      — refresh when dot falls off, ONLY if ISB debuff (17800) active on target
                               (wowsims optimization: don't waste GCD without +20% shadow bonus)
[6]  MaintainImmolate        — refresh when dot falls off (if enabled)
[7]  DrainSoulExecute        — if target HP < threshold + Drain Soul enabled (guide recommendation)
[8]  ShadowBolt              — primary filler (or Incinerate if configured)
[9]  LifeTap                 — fallback when any spell fails due to mana; also regen mode
```

### Demonology Playstyle Strategies (priority order)

#### Felguard Build
```
[1]  HealthFunnelPet         — if pet HP < threshold, channel Health Funnel
[2]  FelDomination           — if pet dead, instant resummon (off-GCD)
[3]  ResummonPet             — if pet dead and Fel Dom on CD
[4]  MaintainCurse           — apply assigned curse if missing/expired
[5]  MaintainCorruption      — refresh Corruption if < 1.5s remaining (if enabled)
[6]  MaintainImmolate        — refresh Immolate if < 3s remaining (if enabled)
[7]  ShadowBolt              — primary filler
[8]  LifeTap                 — when mana below threshold
```

#### DS/Ruin Build (Demonic Sacrifice active)
```
[1]  DemonicSacrifice        — if no sacrifice buff active, sacrifice configured pet
[2]  MaintainCurse           — apply assigned curse
[3]  ShadowBolt              — primary filler (shadow build)
   OR Incinerate             — primary filler (fire build, requires Immolate)
[4]  MaintainImmolate        — if fire build, maintain Immolate
[5]  LifeTap                 — when mana below threshold
```

### Destruction Playstyle Strategies (priority order)

#### Shadow Build
```
[1]  BacklashProc            — if Backlash proc active (buff 34936), instant SB
[2]  MaintainCurse           — apply assigned curse
[3]  Shadowburn              — if target HP < threshold (instant, costs shard)
[4]  ShadowBolt              — primary filler
[5]  LifeTap                 — when mana below threshold
```

#### Fire Build
```
[1]  BacklashProc            — if Backlash proc active (buff 34936), instant Incinerate
[2]  MaintainImmolate        — ALWAYS top priority (Incinerate needs it)
[3]  Conflagrate             — instant, use on CD (consumes Immolate → re-apply next)
[4]  MaintainCurse           — apply assigned curse
[5]  Shadowfury              — instant AoE stun on CD (if talented + enabled)
[6]  Shadowburn              — if target HP < threshold (instant, costs shard)
[7]  Incinerate              — primary filler (+25% dmg with Immolate active)
[8]  LifeTap                 — when mana below threshold
```

### Shared Middleware (all specs)
```
[MW-500]  DeathCoil           — emergency self-save at critical HP (2 min CD)
[MW-400]  RecoveryItems       — healthstone, health potion
[MW-350]  Soulshatter         — threat reduction when threat is high
[MW-300]  DarkPact            — pet mana → warlock mana (Affliction, if enabled)
[MW-280]  ManaRecovery        — mana potion, dark rune
[MW-250]  LifeTap             — HP → mana when safe to tap
[MW-200]  SelfBuffArmor       — maintain Fel Armor OOC
[MW-150]  PetManagement       — resummon pet if dead + OOC
```

### AoE Strategies (toggled by aoe_mode setting)
```
When aoe_mode != "off" and enemy_count >= aoe_threshold:
- "seed" → cast Seed of Corruption on targets without seed
- "rain_of_fire" → channel Rain of Fire
Destruction addition: Shadowfury before AoE filler (if talented)
```

---

## Key Implementation Notes

### Playstyle Detection
Warlock has NO stances/forms (like Mage). Playstyle must be determined by:
- **User setting** (dropdown: "affliction", "demonology", "destruction")
- Sub-build settings (e.g., `destro_primary_spell` for shadow vs fire)

### No Idle Playstyle
Warlock doesn't shift forms. OOC behavior (Fel Armor, pet summon) handled via middleware with `requires_combat = false`.

### extend_context Fields
```lua
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime()

-- Pet state
ctx.pet_exists = UnitExists("pet")
ctx.pet_hp = ctx.pet_exists and (Unit("pet"):HealthPercent() or 0) or 0
ctx.pet_active = ctx.pet_exists and not Unit("pet"):IsDead()

-- Proc buffs
ctx.has_shadow_trance = (Unit("player"):HasBuffs(17941) or 0) > 0
ctx.has_backlash = (Unit("player"):HasBuffs(34936) or 0) > 0

-- Sacrifice buffs
ctx.has_ds_shadow = (Unit("player"):HasBuffs(18791) or 0) > 0  -- Touch of Shadow
ctx.has_ds_fire = (Unit("player"):HasBuffs(18789) or 0) > 0    -- Burning Wish
ctx.has_ds_any = ctx.has_ds_shadow or ctx.has_ds_fire
    or (Unit("player"):HasBuffs(18790) or 0) > 0
    or (Unit("player"):HasBuffs(18792) or 0) > 0

-- Armor buff
ctx.has_fel_armor = (Unit("player"):HasBuffs(28189) or 0) > 0
    or (Unit("player"):HasBuffs(28176) or 0) > 0

-- Soul shards (for Shadowburn gating)
ctx.soul_shards = GetItemCount(6265) or 0

-- Enemy count
ctx.enemy_count = A.MultiUnits:GetByRange(30) or 0

-- Cache flags (reset per frame)
ctx._affliction_valid = false
ctx._demo_valid = false
ctx._destro_valid = false
```

### Affliction State (context_builder)
```lua
local affliction_state = {
    corruption_duration = 0,
    ua_duration = 0,
    siphon_duration = 0,
    immolate_duration = 0,
    curse_duration = 0,
    shadow_trance = false,
    isb_active = false,
}

local function get_affliction_state(context)
    if context._affliction_valid then return affliction_state end
    context._affliction_valid = true

    affliction_state.corruption_duration = Unit(TARGET):HasDeBuffs(27216) or 0
    affliction_state.ua_duration = Unit(TARGET):HasDeBuffs(30405) or 0
    affliction_state.siphon_duration = Unit(TARGET):HasDeBuffs(30911) or 0
    affliction_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0
    affliction_state.isb_active = (Unit(TARGET):HasDeBuffs(17800) or 0) > 0

    -- Curse tracking based on assigned curse
    local curse_type = context.settings.curse_type
    if curse_type == "elements" then
        affliction_state.curse_duration = Unit(TARGET):HasDeBuffs(27228) or 0
    elseif curse_type == "agony" then
        affliction_state.curse_duration = Unit(TARGET):HasDeBuffs(27218) or 0
    elseif curse_type == "doom" then
        affliction_state.curse_duration = Unit(TARGET):HasDeBuffs(30910) or 0
    elseif curse_type == "recklessness" then
        affliction_state.curse_duration = Unit(TARGET):HasDeBuffs(27226) or 0
    elseif curse_type == "tongues" then
        affliction_state.curse_duration = Unit(TARGET):HasDeBuffs(11719) or 0
    else
        affliction_state.curse_duration = 999  -- "none" — always satisfied
    end

    return affliction_state
end
```

### Destruction State (context_builder)
```lua
local destro_state = {
    immolate_duration = 0,
    conflag_ready = false,
    backlash_active = false,
    isb_active = false,
    target_below_25 = false,
}

local function get_destro_state(context)
    if context._destro_valid then return destro_state end
    context._destro_valid = true

    destro_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0
    destro_state.conflag_ready = A.Conflagrate:IsReady(TARGET) or false
    destro_state.backlash_active = context.has_backlash
    destro_state.isb_active = (Unit(TARGET):HasDeBuffs(17800) or 0) > 0
    destro_state.target_below_25 = context.target_hp < 25

    return destro_state
end
```

### Demonology State (context_builder)
```lua
local demo_state = {
    pet_exists = false,
    pet_hp = 0,
    has_sacrifice = false,
    corruption_duration = 0,
    immolate_duration = 0,
    curse_duration = 0,
}

local function get_demo_state(context)
    if context._demo_valid then return demo_state end
    context._demo_valid = true

    demo_state.pet_exists = context.pet_active
    demo_state.pet_hp = context.pet_hp
    demo_state.has_sacrifice = context.has_ds_any
    demo_state.corruption_duration = Unit(TARGET):HasDeBuffs(27216) or 0
    demo_state.immolate_duration = Unit(TARGET):HasDeBuffs(27215) or 0

    -- Curse tracking (same logic as affliction)
    local curse_type = context.settings.curse_type
    if curse_type == "elements" then
        demo_state.curse_duration = Unit(TARGET):HasDeBuffs(27228) or 0
    elseif curse_type == "agony" then
        demo_state.curse_duration = Unit(TARGET):HasDeBuffs(27218) or 0
    elseif curse_type == "doom" then
        demo_state.curse_duration = Unit(TARGET):HasDeBuffs(30910) or 0
    else
        demo_state.curse_duration = 999
    end

    return demo_state
end
```

### Curse Helper Pattern
Since all three specs need curse tracking with the same logic, extract a shared helper:
```lua
local CURSE_DEBUFF_IDS = {
    elements = 27228,
    agony = 27218,
    doom = 30910,
    recklessness = 27226,
    tongues = 11719,
}

local function get_curse_duration(context)
    local curse_type = context.settings.curse_type
    if curse_type == "none" then return 999 end
    local debuff_id = CURSE_DEBUFF_IDS[curse_type]
    if not debuff_id then return 999 end
    return Unit(TARGET):HasDeBuffs(debuff_id) or 0
end
```

### Curse Spell Mapping
```lua
local CURSE_SPELLS = {
    elements = A.CurseOfElements,
    agony = A.CurseOfAgony,
    doom = A.CurseOfDoom,
    recklessness = A.CurseOfRecklessness,
    tongues = A.CurseOfTongues,
}

-- In MaintainCurse strategy:
local function get_curse_spell(context)
    return CURSE_SPELLS[context.settings.curse_type]
end
```

### Soul Shard Tracking
```lua
-- Gate Shadowburn on having shards
matches = function(context, state)
    if context.soul_shards < 1 then return false end
    if not state.target_below_25 then return false end
    return context.settings.destro_use_shadowburn
end
```

### Pet Choice Per Spec
```lua
-- In class.lua or middleware.lua, map spec to default pet
local SPEC_DEFAULT_PET = {
    affliction = A.SummonImp,       -- Blood Pact default
    demonology = A.SummonFelguard,  -- Always Felguard
    destruction = A.SummonSuccubus, -- For DS sacrifice
}
```