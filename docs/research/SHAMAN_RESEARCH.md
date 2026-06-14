# TBC Shaman Implementation Research

Comprehensive research for implementing Elemental, Enhancement, and Restoration Shaman playstyles.
Sources: wowsims/tbc simulator (Go source: elemental/rotation.go, enhancement/rotation.go, shaman.go, stormstrike.go, shocks.go, totems.go, weapon_imbues.go, shamanistic_rage.go, talents.go), Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Elemental Shaman Rotation & Strategies](#2-elemental-shaman-rotation--strategies)
3. [Enhancement Shaman Rotation & Strategies](#3-enhancement-shaman-rotation--strategies)
4. [Restoration Shaman Rotation & Strategies](#4-restoration-shaman-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Mana Management System](#7-mana-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Totem System](#9-totem-system)
10. [Proposed Settings Schema](#10-proposed-settings-schema)
11. [Strategy Breakdown Per Playstyle](#11-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Core Damage Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Lightning Bolt (R12) | 25449 | 2.5s | 300 | Nature. 571-652 dmg. 0.794 SP coeff. Lightning Overload proc (20% at 5/5) |
| Chain Lightning (R6) | 25442 | 2.0s | 760 | Nature. 6s CD, 3 targets, -30% per jump. 0.651 SP coeff |
| Earth Shock (R8) | 25454 | Instant | 535 | Nature. 661-696 dmg. 0.386 SP coeff. 2s interrupt lockout. Shared 6s shock CD |
| Flame Shock (R7) | 25457 | Instant | 500 | Fire. 377 DD + 420 DoT/12s (4 ticks). 0.214 SP coeff (DD). Shared shock CD |
| Frost Shock (R5) | 25464 | Instant | 525 | Frost. 640-676 dmg. 50% slow 8s. 2x threat. Shared shock CD |
| Stormstrike | 17364 | Instant | 237 | Physical MH+OH. 10s CD. +20% nature dmg debuff (2 charges, 12s) |

### AoE Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Fire Nova Totem (R7) | 25547 | Instant | 595 | Totem explodes after ~4s for AoE fire. Replaces fire totem |
| Magma Totem (R5) | 25552 | Instant | 620 | 20s pulse AoE fire every 2s. Replaces fire totem |
| Chain Lightning (R6) | 25442 | 2.0s | 760 | 3 targets, -30% per jump, 6s CD |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Lightning Bolt | 403 | 25449 (R12) | |
| Chain Lightning | 421 | 25442 (R6) | |
| Earth Shock | 8042 | 25454 (R8) | Also interrupt |
| Flame Shock | 8050 | 25457 (R7) | |
| Frost Shock | 8056 | 25464 (R5) | |
| Lightning Shield | 324 | 25472 (R9) | |
| Healing Wave | 331 | 25396 (R12) | |
| Lesser Healing Wave | 8004 | 25420 (R7) | |
| Chain Heal | 1064 | 25423 (R5) | |
| Earth Shield | 974 | 32594 (R3) | `[VERIFY]` Resto talent |
| Water Shield | 24398 | 33736 (R2) | TBC ability |
| Searing Totem | 3599 | 25533 (R7) | |
| Fire Nova Totem | 1535 | 25547 (R7) | |
| Magma Totem | 8190 | 25552 (R5) | |
| Flametongue Totem | 8227 | 25557 (R5) | |
| Strength of Earth | 8075 | 25528 (R6) | |
| Stoneskin Totem | 8071 | 25509 (R8) | |
| Mana Spring Totem | 5675 | 25570 (R5) | |
| Healing Stream Totem | 5394 | 25567 (R6) | |
| Windfury Totem | 8512 | 25587 (R5) | |
| Grace of Air Totem | 8835 | 25359 (R3) | |
| Nature Resistance Totem | 10595 | 25574 (R4) | |
| Windwall Totem | 15107 | 25577 (R4) | |
| Fire Resistance Totem | 8184 | 25563 (R4) | |
| Frost Resistance Totem | 8181 | 25560 (R4) | |
| Windfury Weapon | 8232 | 25505 (R5) | |
| Flametongue Weapon | 8024 | 25489 (R7) | `[VERIFY]` |
| Rockbiter Weapon | 8017 | 25485 (R9) | |
| Frostbrand Weapon | 8033 | 25500 (R6) | |
| Purge | 370 | 8012 (R2) | |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Stormstrike | 17364 | Enhancement talent (40pt) |
| Shamanistic Rage | 30823 | Enhancement talent (41pt) |
| Totem of Wrath | 30706 | Elemental talent (41pt), +3% spell hit/crit |
| Wrath of Air Totem | 3738 | TBC ability (level 64), +101 spell power to party |
| Mana Tide Totem | 16190 | Restoration talent (31pt) |
| Elemental Mastery | 16166 | Elemental talent (21pt), +100% crit next spell |
| Nature's Swiftness | 16188 | Restoration talent (21pt), instant next Nature spell |
| Bloodlust | 2825 | Horde only, 10 min CD |
| Heroism | 32182 | Alliance only, 10 min CD |
| Earth Elemental Totem | 2062 | TBC ability (level 66), 20 min CD |
| Fire Elemental Totem | 2894 | TBC ability (level 68), 20 min CD |
| Tremor Totem | 8143 | Removes fear/charm/sleep every 3s |
| Earthbind Totem | 2484 | AoE slow |
| Grounding Totem | 8177 | Absorb next harmful spell |
| Tranquil Air Totem | 25908 | -20% party threat |
| Poison Cleansing Totem | 8166 | Removes poison every 5s |
| Disease Cleansing Totem | 8170 | Removes disease every 5s |
| Ghost Wolf | 2645 | 3s cast (NOT instant in TBC) |
| Cure Poison | 526 | |
| Cure Disease | 2870 | |
| Water Walking | 546 | |
| Water Breathing | 131 | |
| Reincarnation | 20608 | Passive, triggers on death, requires Ankh reagent |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Elemental Mastery | 16166 | 3 min | Next spell | +100% crit on next Nature/Fire/Frost spell |
| Nature's Swiftness | 16188 | 3 min | Next spell | Instant cast next Nature spell |
| Shamanistic Rage | 30823 | 2 min | 15s | -30% dmg taken, mana = 30% AP per melee hit (15 PPM) |
| Bloodlust | 2825 | 10 min | 40s | +30% haste to party (Horde) |
| Heroism | 32182 | 10 min | 40s | +30% haste to party (Alliance) |
| Mana Tide Totem | 16190 | 5 min | 12s | 24% party max mana over 12s (4 ticks of 6%) |
| Earth Elemental Totem | 2062 | 20 min | 2 min | Summon Earth Elemental tank pet |
| Fire Elemental Totem | 2894 | 20 min | 2 min | Summon Fire Elemental DPS pet |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Earth Shock (interrupt) | 8042 | 6s (shared) | **TBC's ONLY shaman interrupt** — 2s school lockout. Use R1 for interrupt-only |
| Grounding Totem | 8177 | 15s | Absorb next harmful spell (air totem slot) |
| Tremor Totem | 8143 | — | Removes fear/charm/sleep from party every 3s (earth slot) |
| Earthbind Totem | 2484 | — | AoE slow (earth slot) |
| Cure Poison | 526 | — | Remove 1 poison from friendly target |
| Cure Disease | 2870 | — | Remove 1 disease from friendly target |
| Purge (R2) | 8012 | — | Remove 2 magic buffs from enemy |
| Ghost Wolf | 2645 | — | +40% run speed, 3s cast (NOT instant in TBC unless talented via Improved Ghost Wolf) |
| Reincarnation | 20608 | 60 min (30 talented) | Self-rez on death, requires Ankh reagent |

### Self-Buffs / Shields
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Water Shield (R2) | 33736 | 10 min | +50 MP5, restores mana when hit (3 charges). No mana cost. Elemental/Resto primary |
| Lightning Shield (R9) | 25472 | 10 min | Deals nature dmg to melee attackers (3 charges). Enhancement primary |
| Earth Shield (R3) | 32594 | 10 min / 6 charges | Heals target when hit, -30% pushback. Resto talent. One active per shaman |

**Shield exclusivity**: Water Shield and Lightning Shield are mutually exclusive. Only one can be active.

### Weapon Imbues
| Imbue | Base ID | Max Rank ID | Duration | Notes |
|-------|---------|-------------|----------|-------|
| Windfury Weapon | 8232 | 25505 (R5) | 30 min | 20% proc, +475 AP, 3s ICD. Enhancement MH |
| Flametongue Weapon | 8024 | 25489 (R7) | 30 min | Fire on every hit (speed*35 + 0.1 SP coeff). Enhancement OH |
| Rockbiter Weapon | 8017 | 25485 (R9) | 30 min | +AP, extra threat. Rarely used at 70 |
| Frostbrand Weapon | 8033 | 25500 (R6) | 30 min | 9 PPM frost proc + slow. PVP only |

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Orc | Blood Fury (AP) | 20572 | +AP for 15s, 2 min CD. Enhancement |
| Orc | Blood Fury (SP) | 33697 | +SP for 15s, 2 min CD. Elemental/Resto `[VERIFY]` |
| Troll | Berserking | 26297 | 10-30% haste 10s, 3 min CD |
| Tauren | War Stomp | 20549 | 2s AoE stun, 0.5s cast, 2 min CD |
| Draenei | Gift of the Naaru | 28880 | HoT heal, 3 min CD |
| Draenei | Heroic Presence | — | Passive +1% hit to party (no spell ID needed) |

### Debuff IDs (for tracking on target)
| Debuff | ID | Notes |
|--------|------|-------|
| Stormstrike debuff | 17364 | +20% nature dmg, 2 charges, 12s. `[VERIFY]` debuff ID may differ from spell ID |
| Flame Shock DoT | 25457 | 12s DoT (track via max rank ID) |
| Frost Shock slow | 25464 | 50% movement slow, 8s |

### Buff IDs (for tracking on player)
| Buff | ID | Notes |
|------|------|-------|
| Water Shield | 33736 | Max rank. Charges + passive MP5 |
| Lightning Shield | 25472 | Max rank. 3 charges |
| Elemental Focus (Clearcasting) | 16246 | 2 charges, -40% mana cost. Procs on spell crit `[VERIFY]` |
| Elemental Mastery | 16166 | Next spell +100% crit, consumed on cast |
| Nature's Swiftness | 16188 | Next Nature spell instant, consumed on cast |
| Shamanistic Rage | 30823 | -30% dmg + mana regen, 15s |
| Flurry | 16280 | +30% melee haste, 3 charges. Enh talent `[VERIFY]` |
| Unleashed Rage | 30802 | +10% party melee AP, 10s. Enh talent `[VERIFY]` |
| Shamanistic Focus | 43339 | -60% shock mana cost after melee crit `[VERIFY]` |
| Elemental Devastation | 29180 | +9% melee crit after spell crit, 10s `[VERIFY]` |
| Bloodlust buff | 2825 | +30% haste, 40s |
| Heroism buff | 32182 | +30% haste, 40s |
| Earth Shield | 32594 | Max rank. Track charges on target |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD from potions) |
| Demonic Rune | 12662 | Same as Dark Rune |
| Destruction Potion | 22839 | +120 SP, +2% spell crit for 15s (Elemental burst) |
| Haste Potion | 22838 | +400 haste rating for 15s (Enhancement burst) |
| Fel Mana Potion | 31677 | 3200 mana/24s, -25 spell dmg 15 min debuff |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+) or later:
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Wind Shear | Wrath (3.0) | **Use Earth Shock for interrupt in TBC** |
| Lava Burst | Wrath (3.0) | No execute-style nuke for Elemental |
| Riptide | Wrath (3.0) | No instant HoT for Restoration |
| Hex | Wrath (3.0) | No CC spell |
| Thunderstorm | Wrath (3.0) | No AoE knockback + mana restore |
| Feral Spirit / Spirit Wolves | Wrath (3.0) | No Enhancement wolf pet |
| Maelstrom Weapon | Wrath (3.0) | No instant-cast LB/HW proc for Enhancement |
| Lava Lash | Wrath (3.0) | No off-hand fire attack for Enhancement |
| Fire Nova (direct cast) | Wrath (3.0) | TBC has Fire Nova **Totem** (drop & explode), NOT direct cast |
| Flame Shock spreading | Wrath+ | No FS spread via Fire Nova |
| Totem Call / Totemic Recall | Wrath (3.0) | Cannot recall totems in TBC |
| Multi-totem drop | Wrath (3.0) | Each totem placed individually |
| Spirit Link Totem | Cataclysm | Does not exist |
| Ancestral Swiftness | Wrath (3.0) | No instant Ghost Wolf (unless talented via Improved Ghost Wolf 2/2 = -2s cast, still 1s) |
| Elemental Oath | Wrath (3.0) | Does not exist |
| Improved Stormstrike | Wrath (3.0) | Does not exist |
| Earthquake | Cataclysm | Does not exist |
| Unleash Elements | Cataclysm | Does not exist |

**What IS new in TBC (vs Classic):**
- Water Shield (level 62) — huge mana sustain
- Earth Shield (Resto 41pt talent) — protect + heal on damage
- Totem of Wrath (Elemental 41pt talent) — +3% spell hit/crit to party
- Wrath of Air Totem (level 64) — +101 spell power to party
- Earth Elemental Totem (level 66)
- Fire Elemental Totem (level 68)
- Bloodlust/Heroism (level 70) — the iconic party haste buff
- Shamanistic Rage (Enhancement 41pt talent) — mana recovery + damage reduction
- Dual Wield (Enhancement talent tree) — enables off-hand
- Mental Quickness (Enhancement talent) — 30% AP → spell power conversion

---

## 2. Elemental Shaman Rotation & Strategies

### Core Mechanic: Lightning Bolt + Chain Lightning + Shock Weaving
Elemental is a caster DPS built around Lightning Bolt as primary filler, Chain Lightning on cooldown (or clearcast), and shock weaving (Flame Shock DoT + Earth Shock filler). Key talent interactions:

- **Lightning Mastery (5/5)**: -1.0s cast time on LB/CL (LB: 2.5s → effectively ~1.5-1.7s with haste)
- **Elemental Focus**: Spell crit grants 2 charges of Clearcasting (-40% mana cost)
- **Lightning Overload (5/5)**: 20% chance LB procs a free half-damage extra LB (no mana, no GCD). CL has ~6.67% chance (20%/3)
- **Totem of Wrath**: +3% spell hit, +3% spell crit to party (41pt talent, fire totem slot)

### Single Target Rotation
From wowsims `elemental/rotation.go`, five configurable rotation types:

1. **LB Only** (`LBOnlyRotation`) — Lightning Bolt exclusively. Maximum mana efficiency.
2. **CL on Cooldown** (`CLOnCDRotation`) — If CL ready, cast CL; else LB. Highest DPS, most mana-intensive.
3. **Fixed LB:CL Ratio** (`FixedRotation`) — Cast N Lightning Bolts then 1 Chain Lightning. Configurable N (default 3). Initializes to cast CL first. During haste buffs (Bloodlust, Quag's Eye), adds extra LBs instead of waiting for CL CD.
4. **CL on Clearcast** (`CLOnClearcastRotation`) — Cast CL when the **second-to-last** spell procced Clearcasting (ensures fresh 2-stack for CL) AND CL off CD. Otherwise LB. Initializes to allow CL first cast. Most mana-efficient DPS option.
5. **Adaptive** (`AdaptiveRotation`) — Uses a presim to determine base vs surplus rotations. Single-target: compares DPET dynamically: `LB = (612 + SP*0.794)*1.2 / (2*castSpeed)` vs `CL = (786 + SP*0.651)*1.0666 / max(1.5*castSpeed, 1)`. If LB+10 >= CL, casts LB only. Multi-target: if OOM 3%+ of fight, base=LB only + surplus=CL on clearcast; else base=CL on clearcast + surplus=CL on CD. T6 4pc: 5% LB damage bonus factored in.

### Rotation Detail
```
GCD Priority (from wowsims tryUseGCD):
1. TryDropTotems — totem management runs FIRST on every GCD
2. rotation.DoAction — then the selected rotation type fires

Opener:
1. Pre-pull: Ensure totems are down (Totem of Wrath, Wrath of Air, Mana Spring, SoE)
2. Elemental Mastery (off-GCD) → Lightning Bolt (guaranteed crit)
3. Flame Shock → maintain DoT
4. Chain Lightning per rotation type
5. Earth Shock as shock filler (when FS DoT is ticking)
6. Lightning Bolt spam (primary filler)

Shock Rotation (handled separately from main rotation in wowsims):
- All shocks share 6s CD (reduced by Reverberation talent: -0.2s/rank, max -1.0s = 5s CD)
- Flame Shock priority: apply DoT when not active
- Earth Shock: filler when FS DoT is ticking
- Using Earth Shock to interrupt costs the shared shock CD
- NOTE: Shocks are NOT in elemental/rotation.go — handled in shocks.go or base shaman
```

### Elemental Strategies (priority order)
1. **Elemental Mastery** — off-GCD, use on CD (guaranteed crit next spell)
2. **Trinkets** — off-GCD, pair with Elemental Mastery
3. **Fire Elemental Totem** — if enabled, early on long fights
4. **Flame Shock** — if DoT not active on target
5. **Chain Lightning** — per rotation type setting (clearcast / on CD / fixed ratio)
6. **Earth Shock** — filler shock when FS DoT is ticking
7. **Lightning Bolt** — primary filler (majority of casts)

### Lightning Overload (Passive — No Action Needed)
- 5/5 talent: 20% chance LB triggers a free extra LB at 50% damage, no mana cost, no GCD
- CL has ~6.67% overload chance (20%/3)
- Purely passive proc; no rotation adjustment needed

### Movement Handling
- **No instant damage spells except shocks** (no Lava Burst, no Thunderstorm, no instant LB procs)
- During movement: Flame Shock (if DoT down) or Earth Shock
- Fire Nova Totem can be dropped while moving (instant GCD)

### State Tracking Needed
```lua
local ele_state = {
    clearcasting_charges = 0,       -- 0, 1, or 2 (Elemental Focus)
    elemental_mastery_active = false,
    flame_shock_duration = 0,       -- remaining DoT duration on target
    chain_lightning_cd = 0,         -- remaining CD
    lb_casts_since_cl = 0,          -- for fixed ratio mode
}

local function get_ele_state(context)
    if context._ele_valid then return ele_state end
    context._ele_valid = true

    ele_state.clearcasting_charges = Unit(PLAYER_UNIT):HasBuffsStacks(16246) or 0
    ele_state.elemental_mastery_active = (Unit(PLAYER_UNIT):HasBuffs(16166) or 0) > 0
    ele_state.flame_shock_duration = Unit(TARGET_UNIT):HasDeBuffs(25457) or 0
    ele_state.chain_lightning_cd = A.ChainLightning:GetCooldown() or 0

    return ele_state
end
```

---

## 3. Enhancement Shaman Rotation & Strategies

### Core Mechanic: Dual-Wield Melee + Stormstrike + Shock Weaving
Enhancement dual-wields with Windfury Weapon (MH) + Flametongue Weapon (OH). Rotation revolves around Stormstrike on CD and shock weaving to consume the +20% nature damage debuff.

### Key Talent Effects
- **Flurry (5/5)**: +30% melee haste for 3 charges after crit
- **Dual Wield + DW Specialization (3/3)**: Enable off-hand, +6% OH hit
- **Stormstrike**: 10s CD melee (MH+OH), applies +20% nature dmg debuff (2 charges, 12s)
- **Shamanistic Rage**: -30% dmg + mana = 30% AP per melee hit (15 PPM), 2 min CD, 15s
- **Unleashed Rage**: Melee crit → +10% AP to party, 10s
- **Shamanistic Focus**: Melee crit → -60% next shock mana cost
- **Mental Quickness**: 30% AP → spell power (makes shocks scale with AP)

### Weapon Imbues (from wowsims weapon_imbues.go)
- **MH: Windfury Weapon R5** (25505) — 20% proc, +475 AP, 3s ICD, 2 extra attacks
- **OH: Flametongue Weapon R7** (25489) — fire damage on every hit (speed*35 + 10% SP coeff)

### Single Target Rotation
From wowsims `enhancement/rotation.go` (scheduler-based, pre-plans all GCD usage):
```
Scheduled Abilities (time-based, not simple priority):
1. Stormstrike — scheduled every 10s with configurable FirstStormstrikeDelay.
   If cast fails (OOM), calls WaitForMana.
2. Shocks — scheduled on shared shock CD interval:
   a. If WeaveFlameShock enabled AND FlameShock DoT NOT active → Flame Shock
   b. Else if PrimaryShock == Earth → Earth Shock
   c. Else if PrimaryShock == Frost → Frost Shock
   d. If PrimaryShock == None but WeaveFlameShock → FS-only every 12s (DoT duration)
3. Totem drops — scheduled on totem-specific intervals (see Totem Twisting)
4. Auto-attack — continues between GCDs (no clipping)

Configurable Settings (from wowsims proto):
- Rotation.FirstStormstrikeDelay — delay before first SS
- Rotation.PrimaryShock — Earth / Frost / None
- Rotation.WeaveFlameShock — boolean
- Totems.TwistFireNova — boolean
- Totems.TwistWindfury — boolean
- Totems.Fire — Magma / Searing / TotemOfWrath
- Totems.Air — GraceOfAir / TranquilAir / Windfury / WrathOfAir
- Totems.Earth — StrengthOfEarth / Tremor
- Totems.Water — ManaSpring
```

### Stormstrike Mechanics (from wowsims stormstrike.go)
- Instant attack with both weapons (MH + OH), physical damage
- Applies debuff: +20% nature damage taken, 2 charges, 12s duration
- Charges consumed by ANY nature spells hitting the target (your Earth Shock, party LBs, etc.)
- Refreshed to 2 charges on each Stormstrike hit
- 10s CD, 237 mana cost

### Shamanistic Rage (from wowsims shamanistic_rage.go)
- 2 min CD, 15s duration
- -30% damage taken
- Mana regen: 30% AP as mana per melee hit, 15 PPM
- wowsims triggers at mana < 1000
- For addon: configurable mana% threshold (default ~30%)

### Totem Twisting (Critical Enhancement Mechanic)
Enhancement shamans "twist" air totems to benefit from BOTH Windfury Totem and Grace of Air Totem:

**Windfury + Grace of Air Twist (from wowsims `TwistWindfury`):**
1. Drop Windfury Totem (air slot) — party gets WF buff (~10s duration on players)
2. After 10s, drop default air totem (GoA/WoA/etc) — replaces WF in slot, WF buff still active
3. Before WF buff expires, re-drop Windfury Totem
4. Result: party benefits from BOTH WF (+extra attacks) and GoA (+77 agility) simultaneously
5. **wowsims timing**: WF scheduled every **10s** with DesiredCastAt windows (MinCastAt = desired-8s, MaxCastAt = desired+20s). Uses `ScheduleGroup` to pair WF + default air totem in sequence.
6. **OOM protection**: Skips WF twist if `Metrics.WentOOM && CurrentManaPercent() < 0.2` (20%)
7. Default air totem skip: If `NextTotemDrops[AirTotem] > CurrentTime + 10s`, skips redundant default drop

**Fire Nova Totem Twist (from wowsims `TwistFireNova`):**
1. Drop Fire Nova Totem (fire slot) — 4s fuse then AoE explosion
2. After explosion (`FireNovaTickLength`), drop default fire totem (Magma/Searing/ToW)
3. Next FNT available after **15s** cooldown from last cast
4. Default fire totem checks: won't drop if `SearingTotemDot.IsActive() || MagmaTotemDot.IsActive() || FireNovaTotemDot.IsActive()`
5. **OOM protection**: Same 20% mana threshold — skips FNT if mana < 20% and went OOM
6. If no default fire totem configured, just cycles FNT every 15s

### Enhancement Strategies (priority order)
**Note**: wowsims uses a scheduler model (pre-planned GCD timeslots), not a simple priority check. For the addon, we translate this to a priority system that produces equivalent results:
1. **Shamanistic Rage** — off-GCD, at mana threshold (not in wowsims rotation.go, likely auto-used)
2. **Trinkets** — off-GCD
3. **Racial** — off-GCD (Blood Fury AP / Berserking)
4. **TotemManagement** — drop/refresh/twist (scheduled in wowsims)
5. **Stormstrike** — on CD (10s), top melee priority
6. **Shock** — Flame Shock if weaving + DoT down; else primary shock (Earth/Frost per setting)
7. **Fire Nova Totem Twist** — if enabled, 15s cycle
8. **Fire Elemental** — if enabled, long fights

### State Tracking Needed
```lua
local enh_state = {
    stormstrike_cd = 0,
    stormstrike_debuff_duration = 0,
    stormstrike_charges = 0,          -- 0-2
    flame_shock_duration = 0,
    shamanistic_rage_active = false,
    shamanistic_focus_active = false,  -- -60% shock cost after melee crit
    flurry_charges = 0,               -- 0-3
}

local function get_enh_state(context)
    if context._enh_valid then return enh_state end
    context._enh_valid = true

    enh_state.stormstrike_cd = A.Stormstrike:GetCooldown() or 0
    enh_state.stormstrike_debuff_duration = Unit(TARGET_UNIT):HasDeBuffs(17364) or 0
    enh_state.stormstrike_charges = Unit(TARGET_UNIT):HasDeBuffsStacks(17364) or 0
    enh_state.flame_shock_duration = Unit(TARGET_UNIT):HasDeBuffs(25457) or 0
    enh_state.shamanistic_rage_active = (Unit(PLAYER_UNIT):HasBuffs(30823) or 0) > 0
    enh_state.shamanistic_focus_active = (Unit(PLAYER_UNIT):HasBuffs(43339) or 0) > 0
    enh_state.flurry_charges = Unit(PLAYER_UNIT):HasBuffsStacks(16280) or 0

    return enh_state
end
```

---

## 4. Restoration Shaman Rotation & Strategies

### Core Mechanic: Chain Heal + Earth Shield Maintenance
Resto is a raid healer focused on Chain Heal bouncing to injured party members, with Earth Shield maintained on the tank for passive healing and pushback protection.

### Key Talents
- **Improved Healing Wave (5/5)**: -0.5s Healing Wave cast time (3.0s → 2.5s)
- **Nature's Swiftness**: Instant next Nature spell, 3 min CD
- **Mana Tide Totem**: 24% max mana to party over 12s (4 ticks of 6%), 5 min CD
- **Earth Shield**: 6 charges, heals target when hit (~270 + coefficient), -30% pushback. 41pt talent
- **Improved Chain Heal (2/2)**: +20% Chain Heal healing

### Healing Spells
| Spell | Cast Time | Mana | Notes |
|-------|-----------|------|-------|
| Healing Wave (R12) | 2.5s (talented) | 620 | Big slow heal. Good downrank target |
| Lesser Healing Wave (R7) | 1.5s | 380 | Fast small heal |
| Chain Heal (R5) | 2.5s | 540 | 3 targets, -50% per jump. Smart targeting. Primary raid heal |
| Earth Shield (R3) | Instant | 570 | 6 charges, heal-on-hit, -30% pushback. Maintain on tank |

### Healing Priority
```
1. Nature's Swiftness + Healing Wave — emergency instant big heal (3 min CD)
2. Earth Shield maintenance — refresh when charges <= threshold (default 2)
3. Chain Heal (target tank or injured cluster) — primary heal (80%+ of casts in raids)
4. Lesser Healing Wave — fast emergency single-target
5. Healing Wave (max rank) — heavy single-target damage
6. Healing Wave (downranked) — mana-efficient for moderate damage
```

### Earth Shield Mechanics
- 6 charges, heals target (~270 HP + spell power coefficient) each time they take damage
- Only one Earth Shield per shaman (can't stack on multiple targets)
- 10 min duration or until charges consumed
- Reduces spell pushback by 30% on shielded target
- Keep on main tank at all times
- Refresh when charges run low (configurable threshold)

### Mana Tide Totem
- 12s duration, 5 min CD, 4 ticks of 6% max mana each (24% total)
- Replaces Mana Spring Totem temporarily (water totem slot)
- Use proactively at ~65-70% mana on intensive fights
- After Mana Tide expires, re-drop Mana Spring

### State Tracking Needed
```lua
local resto_state = {
    earth_shield_charges = 0,
    earth_shield_duration = 0,
    natures_swiftness_active = false,
    natures_swiftness_cd = 0,
    mana_tide_cd = 0,
}

local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    -- Earth Shield tracked on "focus" or configurable target (typically tank)
    resto_state.earth_shield_charges = Unit("focus"):HasBuffsStacks(32594) or 0
    resto_state.earth_shield_duration = Unit("focus"):HasBuffs(32594) or 0
    resto_state.natures_swiftness_active = (Unit(PLAYER_UNIT):HasBuffs(16188) or 0) > 0
    resto_state.natures_swiftness_cd = A.NaturesSwiftness:GetCooldown() or 0
    resto_state.mana_tide_cd = A.ManaTideTotem:GetCooldown() or 0

    return resto_state
end
```

---

## 5. AoE Rotation (All Specs)

### Elemental AoE
1. **Chain Lightning** — 3 targets, use on CD
2. **Fire Nova Totem** — drop for AoE burst (4s fuse)
3. **Magma Totem** — sustained AoE (20s, pulses every 2s)
4. **Lightning Bolt** filler on primary target between CL cooldowns
5. **Earth Shock** — only for interrupt during AoE

### Enhancement AoE
Very limited AoE capability:
1. **Fire Nova Totem** — primary AoE tool
2. **Magma Totem** — sustained AoE alternative
3. Continue Stormstrike + shock rotation on primary target
4. Totem twisting with Fire Nova adds some AoE DPS

### Restoration AoE Healing
Chain Heal is inherently AoE (3 targets, smart targeting). It IS the AoE healing rotation.
1. **Chain Heal** spam on most injured target — bounces handle AoE healing
2. **Healing Stream Totem** — passive AoE healing supplement

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Healthstone** — HP critically low
2. **Super Healing Potion** — HP critically low (shared potion CD)
3. **Shamanistic Rage** — Enhancement: -30% dmg + mana recovery

### Interrupt
- **Earth Shock** — TBC's ONLY shaman interrupt (2s nature school lockout)
- Shares 6s shock CD with Flame/Frost Shock
- Can use R1 (ID: 8042) for interrupt-only (saves mana)
- **Wind Shear does NOT exist in TBC**

### Dispel/Utility
1. **Cure Poison** — remove poison from friendly target
2. **Cure Disease** — remove disease from friendly target
3. **Purge** — remove 1-2 magic buffs from enemy target
4. **Poison Cleansing Totem** — passive poison removal (water slot)
5. **Disease Cleansing Totem** — passive disease removal (water slot)

### Self-Buffs (OOC/Maintenance)
1. **Shield**: Water Shield (Ele/Resto: mana sustain) vs Lightning Shield (Enh: damage)
2. **Weapon Imbues**: Windfury MH + Flametongue OH (Enh), or Flametongue MH (Ele caster weapon)
3. **Which shield per spec**:
   - Elemental → Water Shield (mana sustain)
   - Enhancement → Lightning Shield (damage on hit)
   - Restoration → Water Shield (mana sustain)

---

## 7. Mana Management System

### Mana Recovery Priority
1. **Water Shield** (Ele/Resto) — +50 MP5 passive + mana on damage taken (free)
2. **Shamanistic Rage** (Enh) — 30% AP as mana per melee hit over 15s (2 min CD)
3. **Mana Spring Totem** — ~25 MP5 to party
4. **Mana Tide Totem** (Resto) — 24% max mana over 12s (5 min CD)
5. **Super Mana Potion** — on CD (2 min shared potion CD)
6. **Dark Rune / Demonic Rune** — mana at HP cost (separate CD from potion)
7. **Elemental Focus / Clearcasting** (Ele) — -40% mana cost on 2 spells after crit (passive)
8. **Shamanistic Focus** (Enh) — -60% shock cost after melee crit (passive)

### Elemental Mana Management
Water Shield (+50 MP5) + Elemental Focus Clearcasting (-40% cost on crits) + Mana Spring Totem + potions/runes. CL-on-Clearcast rotation is the most mana-efficient approach. Key: don't run OOM by spamming Chain Lightning too aggressively.

### Enhancement Mana Management
Shamanistic Rage is the primary mana tool (30% AP as mana on hits). Shamanistic Focus gives -60% shock cost after melee crits. Mana Spring Totem for passive regen. Enhancement is mana-hungry without SR.

### Restoration Mana Management
Water Shield + Mana Spring + Mana Tide (24% max mana, 5 min CD) + downranking heals + potions/runes. Chain Heal is already fairly mana-efficient due to multi-target healing.

---

## 8. Cooldown Management

### Elemental Cooldown Priority
1. **Elemental Mastery** (3 min) — guaranteed crit, pair with trinkets
2. **Fire Elemental Totem** (20 min) — early on long fights
3. **Trinkets** — pair with EM window
4. **Destruction Potion** — pair with EM if desired

### Enhancement Cooldown Priority
1. **Shamanistic Rage** (2 min) — use at mana threshold or when damage incoming
2. **Fire Elemental Totem** (20 min) — early on long fights
3. **Trinkets + Blood Fury/Berserking** — pair together on CD

### Restoration Cooldown Priority
1. **Mana Tide Totem** (5 min) — proactive at ~65-70% mana on intensive fights
2. **Nature's Swiftness** (3 min) — save for emergency (instant max rank HW)
3. **Earth Elemental Totem** (20 min) — emergency tank support

---

## 9. Totem System

### Overview
Shamans can place one totem per element (Fire, Earth, Water, Air) simultaneously. Totems are placed at the shaman's feet, have limited HP, a fixed radius (~20-30 yards), and most last 2 minutes.

**WoW API**: `GetTotemInfo(slot)` returns `haveTotem, name, startTime, duration`
- Slot 1 = Fire, Slot 2 = Earth, Slot 3 = Water, Slot 4 = Air

**Important TBC limitations:**
- NO Totemic Recall (Wrath+) — can't recall totems
- NO multi-totem drop (Wrath+) — each totem placed individually (costs GCD each)
- Totems don't move — must re-drop if fight moves

### Recommended Totems Per Spec

| Slot | Elemental | Enhancement | Restoration |
|------|-----------|-------------|-------------|
| Fire | Totem of Wrath | Searing Totem | Searing Totem |
| Earth | Strength of Earth | Strength of Earth | Strength of Earth / Stoneskin |
| Water | Mana Spring | Mana Spring | Mana Spring / Mana Tide |
| Air | Wrath of Air | Windfury (twist w/ GoA) | Wrath of Air |

### Fire Totems
| Totem | Base ID | Max Rank ID | Duration | Notes |
|-------|---------|-------------|----------|-------|
| Searing Totem | 3599 | 25533 (R7) | 60s | Auto-attacks nearest enemy every ~2.2s |
| Fire Nova Totem | 1535 | 25547 (R7) | ~4s | AoE explosion after fuse, then despawns |
| Magma Totem | 8190 | 25552 (R5) | 20s | AoE pulse every 2s |
| Totem of Wrath | 30706 | 30706 | 120s | +3% spell hit/crit. Elemental 41pt talent |
| Flametongue Totem | 8227 | 25557 (R5) | 120s | +spell damage to party melee |
| Fire Elemental Totem | 2894 | 2894 | 120s | Summon Fire Elemental. 20 min CD |
| Fire Resistance Totem | 8184 | 25563 (R4) | 120s | +fire resist to party |

### Earth Totems
| Totem | Base ID | Max Rank ID | Duration | Notes |
|-------|---------|-------------|----------|-------|
| Strength of Earth | 8075 | 25528 (R6) | 120s | +86 STR to party |
| Stoneskin Totem | 8071 | 25509 (R8) | 120s | Reduce melee damage taken |
| Tremor Totem | 8143 | 8143 | 120s | Remove fear/charm/sleep every 3s |
| Earthbind Totem | 2484 | 2484 | 45s | 50% AoE slow |
| Earth Elemental Totem | 2062 | 2062 | 120s | Summon Earth Elemental. 20 min CD |

### Water Totems
| Totem | Base ID | Max Rank ID | Duration | Notes |
|-------|---------|-------------|----------|-------|
| Mana Spring Totem | 5675 | 25570 (R5) | 120s | ~25 MP5 to party |
| Healing Stream Totem | 5394 | 25567 (R6) | 120s | Heal party every 2s |
| Mana Tide Totem | 16190 | 16190 | 12s | 24% party mana over 12s. Resto talent. 5 min CD |
| Poison Cleansing | 8166 | 8166 | 120s | Remove poison every 5s |
| Disease Cleansing | 8170 | 8170 | 120s | Remove disease every 5s |
| Frost Resistance | 8181 | 25560 (R4) | 120s | +frost resist to party |

### Air Totems
| Totem | Base ID | Max Rank ID | Duration | Notes |
|-------|---------|-------------|----------|-------|
| Windfury Totem | 8512 | 25587 (R5) | 120s | Party melee Windfury proc |
| Grace of Air Totem | 8835 | 25359 (R3) | 120s | +77 Agility to party |
| Wrath of Air Totem | 3738 | 3738 | 120s | +101 spell power to party (TBC) |
| Grounding Totem | 8177 | 8177 | 45s | Absorb one harmful spell |
| Tranquil Air Totem | 25908 | 25908 | 120s | -20% party threat |
| Nature Resistance | 10595 | 25574 (R4) | 120s | +nature resist to party |
| Windwall Totem | 15107 | 25577 (R4) | 120s | Reduce ranged damage taken |

### Totem State Tracking
```lua
-- Pre-allocated totem state table
local totem_state = {
    fire_active = false,
    fire_name = "",
    fire_remaining = 0,
    earth_active = false,
    earth_name = "",
    earth_remaining = 0,
    water_active = false,
    water_name = "",
    water_remaining = 0,
    air_active = false,
    air_name = "",
    air_remaining = 0,
}

-- Totem slot constants
local TOTEM_FIRE  = 1
local TOTEM_EARTH = 2
local TOTEM_WATER = 3
local TOTEM_AIR   = 4

local function refresh_totem_state()
    local now = GetTime()
    for slot, key in pairs({[1]="fire", [2]="earth", [3]="water", [4]="air"}) do
        local have, name, start, dur = GetTotemInfo(slot)
        local active = have and name ~= ""
        totem_state[key .. "_active"] = active
        totem_state[key .. "_name"] = active and name or ""
        totem_state[key .. "_remaining"] = active and ((start + dur) - now) or 0
    end
end
```

### Totem Twisting State (Enhancement)
```lua
-- Track twist timing for WF + GoA
local twist_state = {
    last_wf_drop_time = 0,     -- GetTime() when WF totem last dropped
    last_goa_drop_time = 0,    -- GetTime() when GoA totem last dropped
    current_air = "none",       -- "windfury" | "grace_of_air" | "none"
    wf_buff_remaining = 0,      -- estimated WF buff time remaining on party
}

-- WF totem buff persists ~10s on players after totem is replaced
-- wowsims twist cycle: drop WF → 10s later drop GoA → 10s later drop WF → ...
-- OOM protection: skip twist if CurrentManaPercent() < 0.2
```

---

## 10. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "elemental" | Spec / Playstyle | Active spec ("elemental", "enhancement", "restoration") |
| `use_interrupt` | checkbox | true | Auto Interrupt | Earth Shock interrupt (TBC has no Wind Shear) |
| `interrupt_rank1` | checkbox | true | Interrupt Rank 1 | Use R1 Earth Shock for interrupt (saves mana) |
| `use_cure_poison` | checkbox | false | Auto Cure Poison | Remove poison from party members |
| `use_cure_disease` | checkbox | false | Auto Cure Disease | Remove disease from party members |
| `use_purge` | checkbox | false | Auto Purge | Remove enemy magic buffs |
| `shield_type` | dropdown | "auto" | Shield Type | Shield to maintain ("auto", "water", "lightning") |

### Tab 2: Elemental
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `ele_rotation_type` | dropdown | "cl_clearcast" | Rotation Type | CL usage pattern ("cl_clearcast", "cl_on_cd", "fixed_ratio", "lb_only") |
| `ele_fixed_lb_per_cl` | slider | 3 | LBs per CL | For Fixed Ratio mode (1-6) |
| `ele_use_flame_shock` | checkbox | true | Use Flame Shock | Maintain Flame Shock DoT |
| `ele_use_earth_shock` | checkbox | true | Use Earth Shock | Earth Shock as filler shock |
| `ele_use_elemental_mastery` | checkbox | true | Use Elemental Mastery | Use EM on cooldown |
| `ele_use_fire_elemental` | checkbox | false | Use Fire Elemental | Summon Fire Elemental on long fights |
| `ele_fire_totem` | dropdown | "totem_of_wrath" | Fire Totem | Default fire totem ("totem_of_wrath", "searing", "flametongue") |
| `ele_earth_totem` | dropdown | "strength_of_earth" | Earth Totem | Default earth totem ("strength_of_earth", "stoneskin") |
| `ele_water_totem` | dropdown | "mana_spring" | Water Totem | Default water totem ("mana_spring", "healing_stream") |
| `ele_air_totem` | dropdown | "wrath_of_air" | Air Totem | Default air totem ("wrath_of_air", "windfury", "tranquil_air") |

### Tab 3: Enhancement
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `enh_use_stormstrike` | checkbox | true | Use Stormstrike | Stormstrike on cooldown |
| `enh_primary_shock` | dropdown | "earth_shock" | Primary Shock | Primary shock spell ("earth_shock", "flame_shock") |
| `enh_weave_flame_shock` | checkbox | true | Weave Flame Shock | Maintain FS DoT between Earth Shocks |
| `enh_use_shamanistic_rage` | checkbox | true | Use Shamanistic Rage | Mana recovery + damage reduction |
| `enh_shamanistic_rage_pct` | slider | 30 | SR Mana% | Use Shamanistic Rage below this mana% (10-80) |
| `enh_twist_windfury` | checkbox | false | Twist Windfury | WF + Grace of Air totem twist |
| `enh_twist_fire_nova` | checkbox | false | Twist Fire Nova | Fire Nova Totem twist with fire totem |
| `enh_use_fire_elemental` | checkbox | false | Use Fire Elemental | Summon Fire Elemental |
| `enh_fire_totem` | dropdown | "searing" | Fire Totem | Default fire totem ("searing", "magma", "flametongue") |
| `enh_earth_totem` | dropdown | "strength_of_earth" | Earth Totem | Default earth totem ("strength_of_earth", "stoneskin") |
| `enh_water_totem` | dropdown | "mana_spring" | Water Totem | Default water totem ("mana_spring", "healing_stream") |
| `enh_air_totem` | dropdown | "windfury" | Air Totem | Default air totem ("windfury", "grace_of_air") |

### Tab 4: Restoration
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `resto_maintain_earth_shield` | checkbox | true | Maintain Earth Shield | Keep Earth Shield on focus/tank target |
| `resto_earth_shield_refresh` | slider | 2 | ES Refresh Charges | Refresh Earth Shield at N charges remaining (1-4) |
| `resto_use_natures_swiftness` | checkbox | true | Use Nature's Swiftness | Emergency instant Healing Wave |
| `resto_ns_hp_threshold` | slider | 30 | NS Emergency HP% | Use NS+HW when target below this HP% (10-50) |
| `resto_use_mana_tide` | checkbox | true | Use Mana Tide | Auto-use Mana Tide Totem |
| `resto_mana_tide_pct` | slider | 65 | Mana Tide Mana% | Use Mana Tide below this mana% (30-90) |
| `resto_primary_heal` | dropdown | "chain_heal" | Primary Heal | Main healing spell ("chain_heal", "healing_wave", "lesser_healing_wave") |
| `resto_fire_totem` | dropdown | "searing" | Fire Totem | Default fire totem ("searing", "flametongue") |
| `resto_earth_totem` | dropdown | "strength_of_earth" | Earth Totem | Default earth totem ("strength_of_earth", "stoneskin") |
| `resto_water_totem` | dropdown | "mana_spring" | Water Totem | Default water totem ("mana_spring", "healing_stream") |
| `resto_air_totem` | dropdown | "wrath_of_air" | Air Totem | Default air totem ("wrath_of_air", "windfury", "tranquil_air") |

### Tab 5: Cooldowns & Mana
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Blood Fury/Berserking/etc.) |
| `use_mana_potion` | checkbox | true | Use Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_pct` | slider | 50 | Mana Potion Below% | Use mana potion when mana below this% (10-80) |
| `use_dark_rune` | checkbox | true | Use Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_pct` | slider | 40 | Dark Rune Below% | Use dark rune when mana below this% (10-80) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use health potion below this HP% |

---

## 11. Strategy Breakdown Per Playstyle

### Elemental Playstyle Strategies (priority order)
```
[1]  ElementalMastery        — off-GCD, use on CD (guaranteed crit next spell)
[2]  Trinkets                — off-GCD, pair with EM window
[3]  Racial                  — off-GCD, pair with EM
[4]  TotemManagement         — drop/refresh totems (ToW, WoA, Mana Spring, SoE)
[5]  FlameShock              — if DoT not active on target
[6]  ChainLightning          — per rotation type setting (clearcast/on_cd/fixed_ratio)
[7]  EarthShock              — filler shock when FS DoT is ticking
[8]  LightningBolt           — primary filler (majority of casts)
[9]  FireElemental           — summon if enabled (long fights)
```

### Enhancement Playstyle Strategies (priority order)
```
[1]  ShamanisticRage         — off-GCD, at mana threshold
[2]  Trinkets                — off-GCD
[3]  Racial                  — off-GCD (Blood Fury AP / Berserking)
[4]  TotemManagement         — drop/refresh/twist totems (wowsims: scheduled on timers)
[5]  Stormstrike             — on CD (10s), top melee priority (wowsims: FirstStormstrikeDelay configurable)
[6]  Shock                   — FS if weaving + DoT down; else primary shock (ES/Frost per setting)
[7]  FireNovaTotemTwist      — if twist enabled, 15s cycle, skip if mana < 20%
[8]  FireElemental           — if enabled (long fights)
```

### Restoration Playstyle Strategies (priority order)
```
[1]  NaturesSwiftnessEmerg   — instant HW when target critically low (3 min CD)
[2]  EarthShieldMaintenance  — refresh when charges <= threshold
[3]  ManaTide                — use when mana below threshold (5 min CD)
[4]  TotemManagement         — maintain totems (Mana Spring, SoE, WoA, Searing)
[5]  ChainHeal               — primary heal (target most injured, bounces)
[6]  LesserHealingWave       — fast emergency single-target
[7]  HealingWave             — big single-target heal
```

### Shared Middleware (all specs)
```
[MW-500]  Interrupt           — Earth Shock interrupt (TBC's ONLY shaman interrupt!)
[MW-400]  RecoveryItems       — healthstone, health potion at low HP
[MW-350]  CurePoison          — remove poison from party (if enabled)
[MW-340]  CureDisease         — remove disease from party (if enabled)
[MW-300]  ManaRecovery        — mana potion, dark rune at low mana
[MW-250]  ShieldMaintenance   — Water Shield (Ele/Resto) or Lightning Shield (Enh)
[MW-200]  Purge               — remove enemy buffs (if enabled)
[MW-150]  TotemRefresh        — refresh expiring 2-min totems
[MW-100]  WeaponImbue         — maintain weapon imbues OOC (WF MH, FT OH for Enh)
```

### AoE Strategies (per-spec additions)
```
When enemy_count >= aoe_threshold:
- Elemental: CL on CD + Fire Nova Totem / Magma Totem
- Enhancement: Fire Nova Totem twist + continue melee rotation
- Restoration: Chain Heal is already AoE (3 targets)
```

---

## Key Implementation Notes

### Playstyle Detection
Shaman has NO stances/forms (unlike Druid). Playstyle must be determined by:
- **User setting** (dropdown: "elemental", "enhancement", "restoration")
- Could auto-detect via talent check, but user setting is simpler and more reliable

### No Idle Playstyle
Unlike Druid's "caster" idle form, Shaman doesn't shift forms. OOC behavior (buffs, totems, imbues) handled via middleware with `requires_combat = false`. `idle_playstyle_name = nil`.

### Shared Shock Cooldown — Critical Design Consideration
All three shocks (Earth, Flame, Frost) share a single 6s cooldown (reduced by Reverberation talent). This means:
- Using Earth Shock to interrupt puts ALL shocks on cooldown
- Strategies must check the shared shock CD, not individual spell CDs
- Interrupt priority must be weighed against DPS loss from missing shock rotation

### Totem Management — Unique to Shaman
Totems are a major complexity factor not present in other classes:
- Four totem slots, each with multiple options
- Totems expire (mostly 2 min) and need refreshing
- Totems are stationary (re-drop on movement)
- Enhancement totem twisting requires precise timing
- `GetTotemInfo(slot)` API for state tracking
- Each totem drop costs a GCD — don't spam-refresh

### class_config Registration
```lua
rotation_registry:register_class({
    name = "Shaman",
    version = "v1.0.0",
    playstyles = { "elemental", "enhancement", "restoration" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle
    end,

    get_idle_playstyle = function(context)
        return nil
    end,

    extend_context = function(ctx)
        ctx.is_moving = Player:IsMoving()
        ctx.is_mounted = Player:IsMounted()
        ctx.combat_time = Unit(PLAYER_UNIT):CombatTime()

        -- Shield state
        ctx.has_water_shield = (Unit(PLAYER_UNIT):HasBuffs(33736) or 0) > 0
        ctx.water_shield_charges = Unit(PLAYER_UNIT):HasBuffsStacks(33736) or 0
        ctx.has_lightning_shield = (Unit(PLAYER_UNIT):HasBuffs(25472) or 0) > 0

        -- Proc/buff state
        ctx.has_clearcasting = (Unit(PLAYER_UNIT):HasBuffs(16246) or 0) > 0
        ctx.clearcasting_charges = Unit(PLAYER_UNIT):HasBuffsStacks(16246) or 0
        ctx.has_elemental_mastery = (Unit(PLAYER_UNIT):HasBuffs(16166) or 0) > 0
        ctx.has_natures_swiftness = (Unit(PLAYER_UNIT):HasBuffs(16188) or 0) > 0
        ctx.shamanistic_rage_active = (Unit(PLAYER_UNIT):HasBuffs(30823) or 0) > 0

        -- Target state
        ctx.flame_shock_duration = Unit(TARGET_UNIT):HasDeBuffs(25457) or 0
        ctx.stormstrike_debuff = Unit(TARGET_UNIT):HasDeBuffs(17364) or 0
        ctx.stormstrike_charges = Unit(TARGET_UNIT):HasDeBuffsStacks(17364) or 0

        -- Multi-target
        ctx.enemy_count = A.MultiUnits:GetByRange(30) or 1

        -- Cache invalidation flags
        ctx._ele_valid = false
        ctx._enh_valid = false
        ctx._resto_valid = false
    end,
})
```

### Totem Tracking in extend_context
```lua
-- Add to extend_context for totem state (called every frame)
local now = GetTime()
for slot = 1, 4 do
    local have, name, start, dur = GetTotemInfo(slot)
    local key = ({ "fire", "earth", "water", "air" })[slot]
    ctx["totem_" .. key .. "_active"] = have and name ~= ""
    ctx["totem_" .. key .. "_remaining"] = (have and name ~= "") and ((start + dur) - now) or 0
end
```

**Note**: The totem tracking loop creates strings via concatenation. For combat performance, pre-compute field names at load time or use a pre-allocated totem state table refreshed by the extend_context function.

### Elemental State (context_builder)
```lua
ele_state.clearcasting_charges = Unit(PLAYER_UNIT):HasBuffsStacks(16246) or 0
ele_state.elemental_mastery_active = (Unit(PLAYER_UNIT):HasBuffs(16166) or 0) > 0
ele_state.flame_shock_duration = Unit(TARGET_UNIT):HasDeBuffs(25457) or 0
ele_state.chain_lightning_cd = A.ChainLightning:GetCooldown() or 0
ele_state.lb_casts_since_cl = <tracked via module-level counter>
```

### Enhancement State (context_builder)
```lua
enh_state.stormstrike_cd = A.Stormstrike:GetCooldown() or 0
enh_state.stormstrike_debuff_duration = Unit(TARGET_UNIT):HasDeBuffs(17364) or 0
enh_state.stormstrike_charges = Unit(TARGET_UNIT):HasDeBuffsStacks(17364) or 0
enh_state.flame_shock_duration = Unit(TARGET_UNIT):HasDeBuffs(25457) or 0
enh_state.shamanistic_rage_active = (Unit(PLAYER_UNIT):HasBuffs(30823) or 0) > 0
enh_state.shamanistic_focus_active = (Unit(PLAYER_UNIT):HasBuffs(43339) or 0) > 0
enh_state.flurry_charges = Unit(PLAYER_UNIT):HasBuffsStacks(16280) or 0
```

### Restoration State (context_builder)
```lua
resto_state.earth_shield_charges = Unit("focus"):HasBuffsStacks(32594) or 0
resto_state.earth_shield_duration = Unit("focus"):HasBuffs(32594) or 0
resto_state.natures_swiftness_active = (Unit(PLAYER_UNIT):HasBuffs(16188) or 0) > 0
resto_state.natures_swiftness_cd = A.NaturesSwiftness:GetCooldown() or 0
resto_state.mana_tide_cd = A.ManaTideTotem:GetCooldown() or 0
```

---

## Items That Need `[VERIFY]` Before Implementation

These IDs have lower confidence and should be checked against Wowhead TBC Classic or the game client:

1. **Earth Shield base ID** (974) and rank progression (R2=32593, R3=32594)
2. **Flametongue Weapon R7** (25489) — TBC max rank ID
3. **Orc Blood Fury SP** (33697) — Spell power version for caster specs
4. **Stormstrike debuff tracking ID** — May differ from spell cast ID 17364
5. **Elemental Focus (Clearcasting) buff ID** (16246) — Might be talent ID not buff aura
6. **Unleashed Rage buff ID** (30802) — The party AP aura
7. **Flurry buff ID** (16280) — May vary by talent rank
8. **Shamanistic Focus buff ID** (43339) — Post-crit shock cost reduction
9. **Elemental Devastation buff ID** (29180) — +melee crit after spell crit
