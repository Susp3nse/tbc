# TBC Druid Implementation Research

Comprehensive research for implementing Feral (Cat DPS, Bear Tank), Balance (Moonkin), Restoration (Tree of Life), and Caster (idle/utility) Druid playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Feral Cat Rotation & Strategies](#2-feral-cat-rotation--strategies)
3. [Feral Bear Rotation & Strategies](#3-feral-bear-rotation--strategies)
4. [Balance (Moonkin) Rotation & Strategies](#4-balance-moonkin-rotation--strategies)
5. [Restoration (Tree) Rotation & Strategies](#5-restoration-tree-rotation--strategies)
6. [Caster (Idle) Rotation & Strategies](#6-caster-idle-rotation--strategies)
7. [AoE Rotation (All Specs)](#7-aoe-rotation-all-specs)
8. [Shared Utility & Defensive Strategies](#8-shared-utility--defensive-strategies)
9. [Mana & Energy Management](#9-mana--energy-management)
10. [Cooldown Management](#10-cooldown-management)
11. [Proposed Settings Schema](#11-proposed-settings-schema)
12. [Strategy Breakdown Per Playstyle](#12-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Cat Form Abilities
| Spell | ID | Cast Time | Cost | Notes |
|-------|------|-----------|------|-------|
| Mangle (Cat) (R3) | 33983 | Instant | 45 energy | +30% bleed dmg debuff, 12s. TBC talent. |
| Shred (R7) | 27002 | Instant | 60 energy | Must be behind. High dmg, +30% with bleed debuff. |
| Rip (R7) | 27008 | Instant | 30 energy | DoT finisher, 12s, scales with CP. |
| Ferocious Bite (R6) | 31018 | Instant | 35 energy | Direct finisher, converts excess energy to dmg. |
| Rake (R5) | 27003 | Instant | 40 energy | Bleed DoT, 9s (3 ticks). |
| Claw (R6) | 27000 | Instant | 45 energy | Basic CP builder (replaced by Mangle). |
| Tiger's Fury (R4) | 9846 | Instant | — | +40 dmg for 6s, cannot be used above 0 energy (>0 blocks it). |
| Dash (R3) | 33357 | Instant | — | +70% speed 15s, 5 min CD. |
| Prowl (R3) | 9913 | Instant | — | Stealth. Enables Ravage/Pounce openers. |
| Ravage (R5) | 27005 | Instant | 60 energy | Stealth opener, must be behind. |
| Pounce (R4) | 27006 | Instant | 50 energy | Stealth stun + bleed DoT. |
| Cower (R5) | 27004 | Instant | 20 energy | Threat reduction. |
| Maim (R1) | 22570 | Instant | 35 energy | TBC incapacitate finisher, 1-3s based on CP. |

### Bear Form Abilities
| Spell | ID | Cast Time | Cost | Notes |
|-------|------|-----------|------|-------|
| Mangle (Bear) (R3) | 33987 | Instant | 20 rage | +30% bleed debuff, 6s CD. TBC talent. |
| Maul (R8) | 26996 | Next swing | 15 rage | On-next-swing, high threat. |
| Swipe (R6) | 26997 | Instant | 20 rage | Hits up to 3 nearby targets. |
| Lacerate (R1) | 33745 | Instant | 15 rage | Bleed DoT, stacks to 5, 15s. TBC only. |
| Demoralizing Roar (R6) | 26998 | Instant | 10 rage | -AP on nearby enemies, 30s. |
| Bash (R3) | 8983 | Instant | 10 rage | 4s stun, 1 min CD. |
| Feral Charge | 16979 | Instant | 5 rage | 8-25yd charge, interrupt, 15s CD. Feral talent. |
| Faerie Fire (Feral) (R5) | 27011 | Instant | — | -armor, no cost, no GCD. 40yd range. |
| Growl | 6795 | Instant | — | Single-target taunt, 10s CD. |
| Challenging Roar | 5209 | Instant | 15 rage | AoE taunt, 10 min CD. |
| Enrage | 5229 | Instant | — | +20 rage over 10s, -armor. 1 min CD. |
| Frenzied Regeneration (R4) | 26999 | Instant | — | Converts rage to HP over 10s. 3 min CD. |

### Balance (Caster DPS) Abilities
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Wrath (R10) | 26984 | 2.0s | 255 | Nature nuke, benefits from Nature's Grace. |
| Starfire (R8) | 26986 | 3.5s | 370 | Arcane nuke, highest single-hit. |
| Moonfire (R12) | 26988 | Instant | 495 | Arcane direct + Nature DoT, 12s. |
| Insect Swarm (R6) | 27013 | Instant | 175 | Nature DoT, -2% hit on target, 12s. Balance talent. |
| Hurricane (R4) | 27012 | 10s channel | 1905 | Nature AoE channel, slows. |
| Force of Nature | 33831 | Instant | 457 | Summon 3 Treants for 30s, 3 min CD. Balance 41pt talent. |
| Faerie Fire (R5) | 26993 | Instant | — | -armor, 40yd range, caster version (different from Feral). |

### Healing Abilities
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Healing Touch (R13) | 26979 | 3.5s | 935 | Large direct heal. 13 ranks for downranking. |
| Regrowth (R10) | 26980 | 2.0s | 675 | Direct + HoT (21s), 10 ranks for downranking. |
| Rejuvenation (R13) | 26982 | Instant | 415 | HoT, 12s (4 ticks), 13 ranks for downranking. |
| Lifebloom (R1) | 33763 | Instant | 220 | HoT stacks to 3, blooms on expiry. TBC only. |
| Swiftmend | 18562 | Instant | 351 | Consumes Rejuv/Regrowth for instant heal. Resto talent. 15s CD. |
| Tranquility (R5) | 26983 | 10s channel | 1650 | Group AoE heal. 10 min CD. |
| Nature's Swiftness | 17116 | Instant | — | Next nature spell instant. 3 min CD. Resto/Balance talent. |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Mangle (Cat) | 33876 | 33983 (R3) | TBC talent |
| Shred | 5221 | 27002 (R7) | |
| Rip | 1079 | 27008 (R7) | |
| Ferocious Bite | 22568 | 31018 (R6) | |
| Rake | 1822 | 27003 (R5) | |
| Claw | 1082 | 27000 (R6) | Replaced by Mangle |
| Tiger's Fury | 5217 | 9846 (R4) | |
| Prowl | 5215 | 9913 (R3) | |
| Ravage | 6785 | 27005 (R5) | |
| Mangle (Bear) | 33878 | 33987 (R3) | TBC talent |
| Maul | 6807 | 26996 (R8) | |
| Swipe | 779 | 26997 (R6) | |
| Demoralizing Roar | 99 | 26998 (R6) | |
| Frenzied Regeneration | 22842 | 26999 (R4) | |
| Faerie Fire (Feral) | 16857 | 27011 (R5) | Feral talent |
| Faerie Fire (caster) | 770 | 26993 (R5) | |
| Wrath | 5176 | 26984 (R10) | |
| Starfire | 2912 | 26986 (R8) | |
| Moonfire | 8921 | 26988 (R12) | |
| Insect Swarm | 5570 | 27013 (R6) | Balance talent |
| Hurricane | 16914 | 27012 (R4) | |
| Healing Touch | 5185 | 26979 (R13) | 13 ranks for downranking |
| Regrowth | 8936 | 26980 (R10) | 10 ranks for downranking |
| Rejuvenation | 774 | 26982 (R13) | 13 ranks for downranking |
| Tranquility | 740 | 26983 (R5) | |
| Mark of the Wild | 1126 | 26990 (R8) | |
| Gift of the Wild | 21849 | 26991 (R3) | Group buff |
| Thorns | 467 | 26992 (R7) | |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Lacerate | 33745 | TBC ability, 1 rank in TBC |
| Lifebloom | 33763 | TBC ability, 1 rank in TBC |
| Force of Nature | 33831 | TBC talent (41pt Balance) |
| Swiftmend | 18562 | Resto talent |
| Nature's Swiftness | 17116 | Resto/Balance talent |
| Innervate | 29166 | |
| Barkskin | 22812 | |
| Feral Charge | 16979 | Feral talent |
| Growl | 6795 | |
| Challenging Roar | 5209 | |
| Enrage | 5229 | |
| Remove Curse | 2782 | |
| Abolish Poison | 2893 | |
| Cyclone | 33786 | TBC ability |
| Maim | 22570 | TBC ability |
| Moonkin Form | 24858 | Balance talent |
| Tree of Life | 33891 | Resto talent |
| Omen of Clarity | 16864 | Feral talent (self-buff) |
| Nature's Grasp | 27009 | (R7 max rank, but typically base 16689) |

### Forms
| Form | Spell ID | Stance Index | Notes |
|------|----------|-------------|-------|
| Caster (no form) | — | 0 | Human form |
| Bear / Dire Bear Form | 9634 | 1 | Use Dire Bear (9634) in TBC |
| Cat Form | 768 | 3 | |
| Travel Form | 783 | 4 | |
| Moonkin Form | 24858 | 5 | Balance talent, shares stance 5 |
| Tree of Life | 33891 | 5 | Resto talent, shares stance 5 |
| Flight Form | 33943 | — | TBC, non-combat |
| Swift Flight Form | 40120 | — | TBC Phase 2+, quest chain |

### Healing Touch All Ranks (for downranking)
| Rank | Spell ID | Base Heal (approx) | Mana Cost |
|------|----------|-------------------|-----------|
| R13 | 26979 | 2707-3189 | 935 |
| R12 | 26978 | 2267-2677 | 800 |
| R11 | 25297 | 1893-2237 | 680 |
| R10 | 9889 | 1516-1796 | 600 |
| R9 | 9888 | 1199-1427 | 500 |
| R8 | 9758 | 1050-1252 | 435 |
| R7 | 8903 | 818-984 | 340 |
| R6 | 6778 | 572-694 | 255 |
| R5 | 5189 | 455-559 | 210 |
| R4 | 5188 | 320-399 | 170 |
| R3 | 5187 | 204-253 | 110 |
| R2 | 5186 | 100-118 | 55 |
| R1 | 5185 | 37-52 | 25 |

### Regrowth All Ranks (for downranking)
| Rank | Spell ID | Direct + HoT | Mana Cost |
|------|----------|-------------|-----------|
| R10 | 26980 | 1453-1624 + 1274 HoT | 675 |
| R9 | 9858 | 1215-1355 + 1064 HoT | 580 |
| R8 | 9857 | 1003-1119 + 861 HoT | 485 |
| R7 | 9856 | 857-957 + 742 HoT | 420 |
| R6 | 9750 | 691-773 + 546 HoT | 350 |
| R5 | 8941 | 534-599 + 427 HoT | 280 |
| R4 | 8940 | 431-488 + 343 HoT | 235 |
| R3 | 8939 | 323-371 + 259 HoT | 185 |
| R2 | 8938 | 237-275 + 175 HoT | 145 |
| R1 | 8936 | 93-107 + 98 HoT | 65 |

### Rejuvenation All Ranks (for downranking)
| Rank | Spell ID | Total HoT (12s) | Mana Cost |
|------|----------|-----------------|-----------|
| R13 | 26982 | 1060 | 415 |
| R12 | 26981 | 888 | 355 |
| R11 | 25299 | 756 | 310 |
| R10 | 9841 | 644 | 265 |
| R9 | 9840 | 548 | 230 |
| R8 | 9839 | 400 | 175 |
| R7 | 8910 | 316 | 145 |
| R6 | 3627 | 244 | 115 |
| R5 | 2091 | 200 | 95 |
| R4 | 2090 | 152 | 75 |
| R3 | 1430 | 116 | 60 |
| R2 | 1058 | 56 | 40 |
| R1 | 774 | 32 | 25 |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Innervate | 29166 | 6 min | 20s | +400% mana regen for 20s |
| Barkskin | 22812 | 1 min | 12s | -20% dmg taken, usable in all forms |
| Nature's Swiftness | 17116 | 3 min | Next spell | Instant next nature spell |
| Force of Nature | 33831 | 3 min | 30s | 3 Treants, Balance talent |
| Swiftmend | 18562 | 15s | Instant | Consumes HoT for burst heal |
| Dash | 33357 | 5 min | 15s | +70% movement in Cat |
| Tiger's Fury | 5217 | 1s | 6s | +40 melee dmg (base; cannot use at >0 energy) |
| Enrage | 5229 | 1 min | 10s | +20 rage over 10s, -armor |
| Frenzied Regeneration | 22842 | 3 min | 10s | Rage → HP conversion |
| Growl | 6795 | 10s | Instant | Taunt |
| Challenging Roar | 5209 | 10 min | 6s | AoE taunt |
| Feral Charge | 16979 | 15s | Instant | Bear charge + interrupt |
| Bash | 8983 | 1 min | 4s | Stun |
| Tranquility | 740 | 10 min | 10s channel | AoE heal |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Barkskin | 22812 | 1 min | -20% dmg, usable in all forms and while CC'd |
| Frenzied Regeneration | 26999 | 3 min | Bear: converts rage to HP |
| Nature's Grasp | 27009 | — | Next melee attack roots attacker |
| Cyclone | 33786 | — | 6s CC, PvP-oriented |
| Bash | 8983 | 1 min | 4s stun (Bear form) |
| Feral Charge | 16979 | 15s | Bear charge + 4s interrupt |
| Remove Curse | 2782 | — | Remove curses from friendly |
| Abolish Poison | 2893 | — | Remove poisons from friendly |
| Hibernate | 18658 | — | CC Beasts/Dragonkin |
| Entangling Roots | 339 | — | Root (outdoor only in TBC) |

### Self-Buffs
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Mark of the Wild (R8) | 26990 | 30 min | +stats, +armor, +all resist |
| Gift of the Wild (R3) | 26991 | 1 hr | Group version of MotW |
| Thorns (R7) | 26992 | 10 min | Nature dmg retaliation on melee hit |
| Omen of Clarity | 16864 | Passive | Proc: Clearcasting (next ability free). Feral talent. |

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Night Elf | Shadowmeld | 20580 | Drop combat, pseudo-stealth |
| Tauren | War Stomp | 20549 | 2s AoE stun, 2 min CD |
| Troll | Berserking | 26297 | 10-30% haste 10s, 3 min CD |

Note: Druid is available to Night Elf (Alliance) and Tauren (Horde) in TBC.

### Debuff IDs (for tracking)
| Debuff | ID | Notes |
|--------|------|-------|
| Mangle (bleed debuff) | 33876/33878 | +30% bleed dmg, 12s (Cat) / refreshed by Bear Mangle |
| Faerie Fire (Feral) — all ranks | 16857, 17390, 17391, 17392, 27011 | -armor debuff, track all rank IDs |
| Faerie Fire (caster) — all ranks | 770, 778, 9749, 9907, 26993 | -armor debuff, caster version |
| Demoralizing Roar — all ranks | 99, 1735, 9490, 9747, 9898, 26998 | -AP debuff, track all rank IDs |
| Lacerate | 33745 | Bleed DoT, stacks to 5 |
| Rake | 1822 | Bleed DoT (use base ID for debuff tracking) |
| Rip | 1079 | Bleed DoT finisher (use base ID) |
| Moonfire | 8921 | Nature DoT component |
| Insect Swarm | 5570 | Nature DoT + -2% hit |

### Buff IDs (for tracking)
| Buff | ID | Notes |
|------|------|-------|
| Clearcasting (Omen of Clarity) | 16870 | Next ability costs no resource |
| Nature's Grace | 16886 | -0.5s next cast after spell crit (Balance talent) |
| Lifebloom | 33763 | HoT stacks to 3, track stacks + duration |
| Rejuvenation | 774 | HoT active check (base ID) |
| Regrowth | 8936 | HoT component active check (base ID) |
| Barkskin | 22812 | -20% dmg taken active |
| Innervate | 29166 | +400% mana regen active |
| Enrage | 5229 | Rage generation + armor reduction active |
| Tiger's Fury | 5217 | +40 melee dmg active |
| Frenzied Regeneration | 22842 | Rage-to-HP active |
| Tree of Life aura | 34123 | +healing received aura (Tree form passive) |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Major Healing Potion | 13446 | 1050-1750 HP, 2 min CD (fallback) |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD) |
| Demonic Rune | 12662 | Same as Dark Rune |
| Healthstone (Master) | 22105 | Item ID for Master Healthstone |
| Healthstone (Major) | 22104 | Item ID for Major Healthstone |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+):
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Wild Growth | Wrath (3.0) | Resto AoE HoT doesn't exist yet |
| Savage Roar | Wrath (3.0) | Cat finisher buff doesn't exist |
| Berserk | Wrath (3.0) | Feral CD doesn't exist |
| Survival Instincts | Wrath (3.0) | Bear emergency CD doesn't exist |
| Nourish | Wrath (3.0) | Healing spell doesn't exist |
| Typhoon | Wrath (3.0) | Balance knockback doesn't exist |
| Starfall | Wrath (3.0) | Balance AoE CD doesn't exist |
| Eclipse | Wrath (3.0) | Balance proc mechanic doesn't exist |
| Predatory Strikes instant casts | Wrath (3.0) | No free instant spells from Predatory Strikes |
| Infected Wounds | Wrath (3.0) | Bear/Cat slow doesn't exist |
| Protector of the Pack | Wrath (3.0) | Bear passive DR doesn't exist |

**What IS new in TBC (vs Classic):**
- Mangle (Cat & Bear) — 41-point Feral talent
- Lacerate — Bear bleed DoT (trainable)
- Lifebloom — Resto HoT (trainable)
- Force of Nature — 41-point Balance talent (Treants)
- Tree of Life — 41-point Resto talent (healing form)
- Cyclone — Trainable CC
- Maim — Cat incapacitate finisher
- Flight Form / Swift Flight Form

---

## 2. Feral Cat Rotation & Strategies

### Core Mechanic: Energy Pooling + Bleed Maintenance
Cat DPS is the most complex melee rotation in TBC. Unlike Warriors (spam abilities on CD), Cat Druids must:
- **Maintain bleed debuffs** (Mangle debuff, Rip, Rake) with limited CP generation
- **Pool energy** before key abilities to avoid wasting energy ticks
- **Powershift** (exit/re-enter Cat Form) to gain energy from Furor talent (+40 energy) and Wolfshead Helm (+20 energy)
- **Tiger's Fury timing** — can only be used at exactly 0 energy (blocked if energy > 0)

### Single Target Rotation
From wowsims `doRotation()` and Icy Veins TBC Feral DPS guide:

```
Opener (from stealth):
1. Prowl → Ravage (if behind) or Pounce (if not behind)
2. Mangle (Cat) to apply +30% bleed debuff
3. Build combo points with Shred (behind) or Mangle (not behind)
4. Rip at 5 CP → maintain at all times on long-lived targets

Steady State:
1. Maintain Mangle debuff (+30% bleed dmg, 12s duration)
2. Maintain Rip (12s, 5 CP preferred)
3. Maintain Rake (9s, if enough energy to spare)
4. Maintain Faerie Fire (Feral) — no cost, no GCD
5. Shred as primary CP builder (must be behind target)
6. Ferocious Bite when Rip has ≥3s remaining and at 5 CP
7. Powershift when energy is low (<20) and mana is sufficient

Execute Phase (<25% HP):
- Ferocious Bite becomes higher priority (no need to maintain Rip if target dying)
- Pool to 5 CP → Ferocious Bite for big execute hits
```

### Powershifting Mechanics
- **Furor** talent (5/5): Gain 40 energy when entering Cat Form
- **Wolfshead Helm**: +20 energy on shift (stacks with Furor = 60 energy)
- **Cost**: Cat Form costs mana (~520 mana at 70)
- **When to shift**: Energy < 20 and enough mana for at least one more shift
- **Shift math**: If current energy + 40 (or 60 with Wolfshead) > current energy waiting for tick, shift is worth it
- **Minimum shift energy gain**: Only shift if net gain ≥ 20 energy

### Tiger's Fury Timing (Critical)
- Can ONLY be activated when energy = 0 (WoW blocks it at >0 energy)
- Grants +40 physical damage for 6 seconds
- In TBC, this is NOT an energy grant (that's Wrath) — it's a flat damage bonus
- Best used right before a powershift (energy drops to 0 naturally)
- 1s cooldown means it can be used frequently

### Clearcasting (Omen of Clarity) Optimization
- Procs from auto-attacks (2 PPM)
- Makes next ability free — use on highest-cost ability
- Priority: Shred (60 energy saved) > Rake (40) > Mangle (45)
- Don't waste on Ferocious Bite or Rip if Shred is available

### State Tracking Needed
```lua
-- Pre-allocated at file scope
local cat_state = {
    has_wolfshead = false,           -- Wolfshead Helm equipped
    can_powershift = false,          -- Enough mana to shift
    energy_tick_soon = false,        -- Energy tick arriving within threshold
    cat_form_cost = 0,               -- Mana cost of Cat Form
    shifts_remaining = 0,            -- Shifts before OOM
    mangle_duration = 0,             -- Mangle debuff remaining on target
    rip_duration = 0,                -- Rip remaining on target
    rake_duration = 0,               -- Rake remaining on target
    rip_now = false,                 -- Should Rip this frame
    mangle_now = false,              -- Should refresh Mangle this frame
    rip_needs_refresh_soon = false,  -- Rip expiring soon
    target_qualifies_for_rip = true, -- Target is elite/boss (configurable)
    rip_refresh_threshold = 0,       -- Dynamic refresh window
    energy_after_shift = 0,          -- Projected energy after powershift
    wolfshead_bonus = 0,             -- 20 if Wolfshead equipped, else 0
    pooling = false,                 -- Inter-strategy gate: pooling for high-priority ability
    prefer_mangle_for_tick = false,  -- Prefer Mangle in energy dead zone
    tf_queued = false,               -- Tiger's Fury was just cast
    tf_queued_at = 0,                -- Time Tiger's Fury was cast
}

local function get_cat_state(context)
    if context._cat_valid then return cat_state end
    context._cat_valid = true

    cat_state.pooling = false  -- Reset each frame

    -- Bleed durations
    cat_state.mangle_duration = Unit(TARGET):HasDeBuffs(33876) or 0  -- Mangle debuff
    cat_state.rip_duration = Unit(TARGET):HasDeBuffs(1079) or 0
    cat_state.rake_duration = Unit(TARGET):HasDeBuffs(1822) or 0

    -- Powershifting
    cat_state.cat_form_cost = NS.get_spell_mana_cost(A.CatForm) or 520
    cat_state.can_powershift = context.mana >= cat_state.cat_form_cost
    cat_state.shifts_remaining = math.floor(context.mana / cat_state.cat_form_cost)

    -- Wolfshead detection (check helm slot for item ID 8345)
    cat_state.has_wolfshead = ... -- item check
    cat_state.wolfshead_bonus = cat_state.has_wolfshead and 20 or 0
    cat_state.energy_after_shift = 40 + cat_state.wolfshead_bonus  -- Furor + Wolfshead

    return cat_state
end
```

---

## 3. Feral Bear Rotation & Strategies

### Core Mechanic: Threat Generation + Mitigation
Bear tanking focuses on generating threat (primarily via Mangle and Maul) while maintaining debuffs for survivability. Unlike Warrior tanking, Bears have:
- **No shield block** — rely on armor + dodge
- **Maul** as on-next-swing (off-GCD rage dump)
- **Lacerate** for sustained threat on longer fights (bleed stacking)
- **Limited AoE threat** — only Swipe (3 targets) and tab-targeting

### Single Target Rotation
From wowsims and Icy Veins TBC Bear guide:

```
Priority (single target):
1. Mangle (Bear) on CD (6s CD) — highest threat-per-rage
2. Lacerate to 5 stacks, then refresh before expiry (15s duration)
3. Maul queue on every swing (if rage ≥ threshold)
4. Faerie Fire (Feral) — free, no GCD, keep up for -armor
5. Demoralizing Roar — if boss, keep up for AP reduction (30s)
6. Swipe — filler when Mangle on CD and Lacerate stacked

AoE Priority (3+ targets):
1. Swipe spam (hits 3 targets)
2. Tab-Mangle for threat on secondary targets
3. Maul queue for extra threat on primary
4. Demoralizing Roar for group AP reduction
```

### Rage Management
- **Enrage**: Use when rage < 20 and HP safe (>50%)
- **Maul threshold**: Only queue Maul when rage ≥ 40 (configurable)
- **Prioritize**: Mangle > Lacerate > Swipe with remaining rage
- **Swipe rage threshold**: 15 (configurable) — don't Swipe if saving for Mangle

### Growl / Challenging Roar
- **Growl**: 10s CD single taunt — use when target not on you
- **Challenging Roar**: 10 min CD AoE taunt — emergency only
- **bear_no_taunt** setting disables both (for off-tanks, DPS bears)

### State Tracking Needed
```lua
local bear_state = {
    maul_queued = false,           -- Maul queued on next swing
    maul_confirmed = false,        -- Game accepted Maul queue
    maul_dequeue_logged = false,   -- Throttle dequeue logging
    lacerate_stacks = 0,           -- Lacerate stack count (0-5)
    lacerate_duration = 0,         -- Lacerate remaining duration
    nearby_elites = 0,             -- Elite count in melee range
    nearby_bosses = 0,             -- Boss count in melee range
    nearby_trash = 0,              -- Trash count in melee range
}

local function get_bear_state(context)
    if context._bear_valid then return bear_state end
    context._bear_valid = true

    bear_state.lacerate_stacks = Unit(TARGET):HasDeBuffsStacks(33745) or 0
    bear_state.lacerate_duration = Unit(TARGET):HasDeBuffs(33745) or 0

    -- Nearby unit classification for Swipe/DemoRoar decisions
    -- ... scan nearby units for boss/elite/trash counts

    return bear_state
end
```

---

## 4. Balance (Moonkin) Rotation & Strategies

### Core Mechanic: Nature's Grace + DoT Maintenance + Mana Management
Balance Druid rotates between Wrath and Starfire, maintaining DoTs, and managing mana (Balance is very mana-hungry).

**Key TBC talents:**
- **Nature's Grace** (16886): Spell crit → -0.5s next cast time
- **Moonkin Form** (24858): +5% spell crit to party, +armor
- **Force of Nature** (33831): Summon 3 Treants for 30s
- **Wrath of Cenarius**: +20% Starfire SP scaling, +10% Wrath SP scaling

### Single Target Rotation
From wowsims `doRotation()` and Icy Veins:

```
Priority:
1. Faerie Fire — maintain -armor debuff (free, no GCD in Feral; costs GCD in caster)
2. Force of Nature — on CD (3 min)
3. Insect Swarm — maintain DoT (12s), -2% hit on target
4. Moonfire — maintain DoT (12s) if mana allows
5. Starfire — primary filler (high damage, benefits from Wrath of Cenarius)
6. Wrath — alternative filler (faster, used during Nature's Grace proc window)

Mana Management Tiers:
- Tier 1 (>40% mana): Full rotation (Starfire + both DoTs + Faerie Fire)
- Tier 2 (20-40% mana): Drop Moonfire, use Wrath as filler (more mana-efficient)
- Tier 3 (<20% mana): Wrath only, conserve hard
```

### Nature's Grace Interaction
- After any spell crit: next cast is -0.5s cast time
- Starfire (3.5s → 3.0s) or Wrath (2.0s → 1.5s) benefit
- In TBC, this is a simple proc — no Eclipse mechanic (that's Wrath)
- Practically: just keep casting, the proc applies automatically

### AoE: Hurricane
- 10s channel, Nature damage, slows
- Use Barkskin before Hurricane to prevent pushback
- Threshold: 3+ enemies (configurable)
- Very mana-expensive — use judiciously

### State Tracking Needed
```lua
-- Balance is relatively simple — no complex state machine
-- Key tracking: mana tiers for rotation adjustment, DoT durations
local balance_state = {
    moonfire_duration = 0,
    insect_swarm_duration = 0,
    faerie_fire_duration = 0,
    natures_grace_active = false,
    mana_tier = 1,  -- 1=full, 2=conserve, 3=emergency
}
```

---

## 5. Restoration (Tree) Rotation & Strategies

### Core Mechanic: Lifebloom Rolling + HoT Blanketing
Resto Druid in TBC revolves around Lifebloom (new TBC spell) and efficient HoT management.

**Key TBC mechanics:**
- **Tree of Life** (stance 5): +healing aura to party, limits spells to HoTs + Swiftmend
- **Lifebloom**: Stacks to 3, ticks every 1s, "blooms" (large heal) when expires or stacks drop
- **Swiftmend**: Consumes Rejuv or Regrowth HoT for instant heal burst

### Healing Priority
From Icy Veins and community guides:

```
Priority:
1. Emergency Swiftmend — instant burst on critically low targets (<30% HP)
2. Emergency NS + Regrowth — Nature's Swiftness + max rank Regrowth (instant big heal)
3. Emergency Barkskin — self-defense when taking damage
4. Lifebloom on tank — maintain 3-stack rolling (refresh at <2s remaining)
5. Swiftmend on urgent targets — burst when HoT is present
6. Rejuvenation on tank — keep rolling for Swiftmend readiness
7. Regrowth on low targets — 2s cast direct + HoT
8. Rejuvenation spread — blanket raid with HoTs
9. Dispel Curse / Dispel Poison — party utility
10. Tranquility — emergency AoE heal (10 min CD)
```

### Lifebloom Management (Critical)
- **Rolling**: Refresh at <2s remaining to maintain 3 stacks without bloom
- **Stack building**: 3x Lifebloom on tank = primary healing method
- **Bloom timing**: Let it bloom intentionally for burst heal + mana return
- **Mana cost**: 220 mana per application (3-stack rolling is mana-intensive)

### Spell Downranking
- TBC preserves Classic's spell rank system — lower ranks cost less mana
- **Healing Touch**: Rank 4 (5188) or Rank 7 (8903) common downranks for tank healing
- **Regrowth**: Rank 4 (8940) for efficient HoT maintenance
- **Rejuvenation**: Rank 7 (8910) or higher for mana-efficient blanketing
- Select rank based on HP deficit: bigger deficit → higher rank

### State Tracking Needed
```lua
local resto_state = {
    tank = nil,              -- Tank target (unit, hp, has_aggro, etc.)
    lowest = nil,            -- Lowest HP party member
    emergency_count = 0,     -- Count of targets below emergency HP
    tank_lb_stacks = 0,      -- Lifebloom stacks on tank (0-3)
    tank_lb_duration = 0,    -- Lifebloom remaining on tank
    cursed_target = nil,     -- Party member with Curse debuff
    poisoned_target = nil,   -- Party member with Poison debuff
}

local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    -- Scan party for healing targets
    -- Identify tank (highest threat or role flag)
    -- Track Lifebloom stacks/duration on tank
    resto_state.tank_lb_stacks = Unit(tank_unit):HasBuffsStacks(33763) or 0
    resto_state.tank_lb_duration = Unit(tank_unit):HasBuffs(33763) or 0

    return resto_state
end
```

---

## 6. Caster (Idle) Rotation & Strategies

### Purpose
The "caster" playstyle is the **idle/utility** form — runs when the Druid is in humanoid form (stance 0) or doesn't match any other active playstyle. Handles out-of-combat self-buffs, emergency self-healing, and dispels.

### Strategies
```
Priority:
1. Emergency Heal — self-heal when HP critical (<30%)
2. Proactive Heal — maintain Rejuv/Regrowth HoTs when injured (<85%)
3. Remove Curse — dispel curses on self
4. Abolish Poison — dispel poisons on self
5. Innervate — self-cast when mana low (solo only)
6. Mark of the Wild — self-buff (OOC only)
7. Thorns — self-buff (OOC only)
8. Omen of Clarity — self-buff (OOC only)
```

---

## 7. AoE Rotation (All Specs)

### Cat AoE
- **Rake spread**: Tab-target and apply Rake to multiple targets
- **Swipe (Cat)**: Not available in TBC (added in Wrath)
- Cat AoE is weak in TBC — primarily tab-Rake + single-target priority

### Bear AoE
- **Swipe**: Primary AoE, hits 3 targets
- **Tab-Mangle**: Build threat on multiple targets
- **Demoralizing Roar**: AoE AP reduction
- **Challenging Roar**: Emergency AoE taunt

### Balance AoE
- **Hurricane**: 10s channel, AoE + slow. Use Barkskin to prevent pushback.
- **Moonfire spam**: Tab-DoT spread on multiple targets
- **Starfire/Wrath**: Focus single target between Hurricane channels

### Resto AoE Healing
- **Tranquility**: Emergency AoE heal (10 min CD)
- **Rejuvenation blanket**: Spread Rejuv on multiple targets
- **Lifebloom rolling**: Can maintain stacks on 2 tanks if needed

---

## 8. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Barkskin** — -20% damage taken 12s, usable in ANY form, usable while CC'd (1 min CD)
   - Use when: HP low, about to take big hit, or before Hurricane channel
2. **Frenzied Regeneration** — Bear: converts rage to HP over 10s (3 min CD)
3. **Nature's Grasp** — roots next attacker (PvP-oriented)

### Dispel/Utility
1. **Remove Curse** — remove curses from friendly targets
2. **Abolish Poison** — remove poisons from friendly targets
3. **Innervate** — massive mana regen for self or ally (6 min CD)

### Self-Buffs (OOC)
1. **Mark of the Wild** — +stats, +armor, +resist (30 min)
2. **Thorns** — nature damage retaliation (10 min)
3. **Omen of Clarity** — passive proc: Clearcasting (Feral talent)

### Form-Aware Consumable Usage
Druid consumables require **form-aware casting** — items used in Cat/Bear form need macros with `/cancelform` or form-specific Action.Create entries to handle the form → item → re-form sequence.

---

## 9. Mana & Energy Management

### Cat Energy System
- 100 energy pool, regenerates at 20 energy per 2s tick
- **Powershifting**: Exit/enter Cat Form to gain Furor energy (40) + Wolfshead (20)
- **Tiger's Fury**: +40 physical damage (NOT energy in TBC), only at 0 energy
- **Clearcasting**: Free next ability — use on highest-cost ability (Shred = 60 energy)

### Bear Rage System
- Starts at 0, generated by taking/dealing damage and Enrage
- **Enrage**: +20 rage over 10s but -armor (use when safe)
- **Maul**: On-next-swing rage dump — queue when rage is high
- **Priority**: Keep enough rage for Mangle (20) before spending on Maul

### Balance/Resto Mana
- **Innervate**: +400% mana regen for 20s (6 min CD) — primarily self-use for Balance
- **Mana potion/Dark Rune**: Standard consumable recovery
- **Downranking**: Use lower rank heals for mana efficiency (Resto)
- **Balance tiers**: Adjust rotation based on mana% (full → conserve → emergency)

---

## 10. Cooldown Management

### Feral (Cat) Cooldowns
1. Tiger's Fury — use at 0 energy before powershift
2. Dash — movement speed (situational, not rotation)
3. Trinkets — use on CD for DPS gain

### Feral (Bear) Cooldowns
1. Enrage — rage generation when rage < 20 and HP safe
2. Frenzied Regeneration — emergency HP recovery
3. Barkskin — damage reduction when anticipating big hit
4. Trinkets — use for mitigation or threat

### Balance Cooldowns
1. Force of Nature — on CD (3 min), good opening damage
2. Innervate — self-cast for mana recovery
3. Barkskin — before Hurricane or when under pressure
4. Trinkets — pair with Force of Nature if possible

### Resto Cooldowns
1. Nature's Swiftness — instant emergency heal
2. Swiftmend — 15s CD burst heal
3. Innervate — self-cast or give to mana-hungry caster
4. Barkskin — self-protection
5. Tranquility — emergency AoE (10 min CD)

---

## 11. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `maintain_faerie_fire` | checkbox | true | Maintain Faerie Fire | Keep Faerie Fire debuff on target |
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Berserking/War Stomp) |
| `use_healthstone` | checkbox | true | Use Healthstone | Auto-use Healthstone for HP recovery |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% (10-80) |
| `use_healing_potion` | checkbox | true | Use Healing Potion | Auto-use healing potion |
| `healing_potion_hp` | slider | 25 | Healing Potion HP% | Use healing potion below this HP% (10-80) |
| `use_mana_potion` | checkbox | true | Use Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_mana` | slider | 40 | Mana Potion Mana% | Use mana potion below this mana% (10-80) |
| `use_dark_rune` | checkbox | true | Use Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_mana` | slider | 50 | Dark Rune Mana% | Use Dark Rune below this mana% (10-80) |
| `dark_rune_min_hp` | slider | 50 | Dark Rune Min HP% | Don't use Dark Rune below this HP% (10-80) |
| `use_innervate_self` | checkbox | true | Self Innervate | Auto-use Innervate on self when mana low |
| `innervate_mana` | slider | 30 | Innervate Mana% | Use Innervate below this mana% (10-60) |
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |

### Tab 2: Cat
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `auto_powershift` | checkbox | true | Auto Powershift | Automatically powershift for energy when low |
| `powershift_min_mana` | slider | 20 | Powershift Min Mana% | Minimum mana% to allow powershifting (5-50) |
| `maintain_rip` | checkbox | true | Maintain Rip | Keep Rip DoT on target |
| `rip_only_elites` | checkbox | true | Rip Elites Only | Only use Rip on elite/boss targets |
| `rip_min_cp` | slider | 4 | Rip Min CP | Minimum combo points for Rip (3-5) |
| `rip_refresh` | slider | 2 | Rip Refresh (sec) | Refresh Rip at this duration remaining (1-5) |
| `rip_min_ttd` | slider | 10 | Rip Min TTD (sec) | Minimum time-to-die to use Rip (5-20) |
| `maintain_rake` | checkbox | true | Maintain Rake | Keep Rake DoT on target |
| `rake_refresh` | slider | 1 | Rake Refresh (sec) | Refresh Rake at this duration remaining (0-3) |
| `use_tigers_fury` | checkbox | true | Use Tiger's Fury | Use Tiger's Fury at 0 energy |
| `tigers_fury_energy` | slider | 0 | Tiger's Fury Energy | Use Tiger's Fury at or below this energy (0-10) |
| `fb_min_energy` | slider | 35 | FB Min Energy | Minimum energy for Ferocious Bite (35-65) |
| `fb_min_rip_duration` | slider | 3 | FB Min Rip Duration | Only Bite if Rip has at least this much time left (1-8) |
| `bite_execute_hp` | slider | 25 | Bite Execute HP% | Prioritize Ferocious Bite below this target HP% (10-40) |
| `bite_execute_ttd` | slider | 6 | Bite Execute TTD | Use Bite when TTD below this (3-15) |
| `use_opener` | checkbox | true | Use Stealth Opener | Use Ravage/Shred from stealth |
| `use_mangle_opener` | checkbox | false | Mangle Opener | Use Mangle from stealth (instead of Ravage/Shred) |
| `use_rake_trick` | checkbox | true | Rake Trick | Use Rake to spend low energy before powershift |
| `enable_aoe` | checkbox | false | Enable Cat AoE | Enable Rake spreading in AoE |
| `aoe_enemy_count` | slider | 3 | AoE Enemy Count | Minimum enemies for AoE behavior (2-6) |
| `spread_rake` | checkbox | true | Spread Rake | Tab-Rake in AoE situations |
| `max_rake_targets` | slider | 3 | Max Rake Targets | Maximum targets for Rake spreading (2-5) |
| `focus_prowl` | checkbox | false | Focus Prowl | Prowl when focus target is set (PvP) |
| `prowl_distance` | slider | 30 | Prowl Distance | Maximum distance to prowl toward target (10-40) |

### Tab 3: Bear
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `bear_no_taunt` | checkbox | false | Disable Taunts | Disable Growl and Challenging Roar (for off-tank) |
| `maintain_lacerate` | checkbox | true | Maintain Lacerate | Build and maintain Lacerate stacks |
| `lacerate_boss_only` | checkbox | false | Lacerate Boss Only | Only Lacerate boss/elite targets |
| `maintain_demo_roar` | checkbox | true | Maintain Demo Roar | Keep Demoralizing Roar on enemies |
| `demo_roar_range` | slider | 10 | Demo Roar Range | Range to check enemies for Demo Roar (5-15) |
| `demo_roar_min_bosses` | slider | 1 | Demo Roar Min Bosses | Minimum bosses to use Demo Roar (0-3) |
| `demo_roar_min_elites` | slider | 1 | Demo Roar Min Elites | Minimum elites to use Demo Roar (0-5) |
| `demo_roar_min_trash` | slider | 3 | Demo Roar Min Trash | Minimum trash to use Demo Roar (1-8) |
| `use_growl` | checkbox | true | Use Growl | Auto-taunt with Growl |
| `use_challenging_roar` | checkbox | true | Use Challenging Roar | Auto-use AoE taunt in emergencies |
| `croar_range` | slider | 10 | C. Roar Range | Range for Challenging Roar check (5-15) |
| `croar_min_bosses` | slider | 1 | C. Roar Min Bosses | Minimum bosses for C. Roar (0-3) |
| `croar_min_elites` | slider | 3 | C. Roar Min Elites | Minimum elites for C. Roar (1-8) |
| `maul_rage_threshold` | slider | 40 | Maul Rage Threshold | Queue Maul above this rage (20-80) |
| `mangle_rage_threshold` | slider | 20 | Mangle Rage | Minimum rage for Mangle (10-40) |
| `swipe_rage_threshold` | slider | 15 | Swipe Rage | Minimum rage for Swipe (10-40) |
| `swipe_min_targets` | slider | 3 | Swipe Min Targets | Minimum targets for Swipe priority (2-5) |
| `swipe_cc_check` | checkbox | true | Swipe CC Check | Don't Swipe if nearby enemies are CC'd |
| `use_frenzied_regen` | checkbox | true | Use Frenzied Regen | Auto-use Frenzied Regeneration |
| `use_enrage` | checkbox | true | Use Enrage | Auto-use Enrage for rage |
| `enrage_rage_threshold` | slider | 20 | Enrage Rage | Use Enrage below this rage (10-40) |

### Tab 4: Caster
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `rejuvenation_hp` | slider | 70 | Rejuvenation HP% | Apply Rejuvenation below this HP% (40-95) |
| `regrowth_hp` | slider | 50 | Regrowth HP% | Cast Regrowth below this HP% (20-80) |
| `emergency_heal_hp` | slider | 30 | Emergency Heal HP% | Emergency Healing Touch below this HP% (10-50) |
| `critical_heal_hp` | slider | 15 | Critical Heal HP% | Critical: use Nature's Swiftness below this HP% (5-30) |
| `mana_reserve` | slider | 30 | Mana Reserve% | Reserve mana% before healing (10-60) |
| `auto_remove_curse` | checkbox | true | Auto Remove Curse | Automatically Remove Curse on self |
| `auto_remove_poison` | checkbox | true | Auto Abolish Poison | Automatically Abolish Poison on self |
| `use_motw` | checkbox | true | Mark of the Wild | Auto-buff Mark of the Wild OOC |
| `use_thorns` | checkbox | true | Thorns | Auto-buff Thorns OOC |
| `use_ooc` | checkbox | true | Omen of Clarity | Auto-buff Omen of Clarity OOC |

### Tab 5: Balance
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `maintain_moonfire` | checkbox | true | Maintain Moonfire | Keep Moonfire DoT on target |
| `maintain_insect_swarm` | checkbox | true | Maintain Insect Swarm | Keep Insect Swarm DoT on target |
| `use_force_of_nature` | checkbox | true | Use Force of Nature | Summon Treants on cooldown |
| `force_of_nature_min_ttd` | slider | 20 | Treants Min TTD | Minimum TTD to summon Treants (10-60) |
| `hurricane_min_targets` | slider | 3 | Hurricane Min Targets | Minimum enemies for Hurricane (2-6) |
| `balance_tier1_mana` | slider | 40 | Full Rotation Mana% | Use full rotation above this mana% (20-80) |
| `balance_tier2_mana` | slider | 20 | Conserve Mana% | Drop Moonfire below this mana% (10-50) |

### Tab 6: Resto
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `resto_emergency_hp` | slider | 20 | Emergency HP% | Trigger emergency heals below this (5-40) |
| `resto_tank_heal_hp` | slider | 50 | Tank Heal HP% | Focus-heal tank below this (30-80) |
| `resto_standard_heal_hp` | slider | 70 | Standard Heal HP% | Standard heal targets below this (40-90) |
| `resto_proactive_hp` | slider | 85 | Proactive HP% | Apply HoTs proactively below this (60-95) |
| `resto_lifebloom_refresh` | slider | 2 | Lifebloom Refresh (sec) | Refresh Lifebloom at this duration remaining (1-4) |
| `resto_swiftmend_hp` | slider | 40 | Swiftmend HP% | Use Swiftmend below this HP% (15-60) |
| `resto_prioritize_tank` | checkbox | true | Prioritize Tank | Always prioritize tank healing |
| `resto_mana_conserve` | slider | 30 | Mana Conserve% | Conserve mana below this% (10-50) |
| `resto_auto_dispel_curse` | checkbox | true | Auto Dispel Curse | Remove curses from party members |
| `resto_auto_dispel_poison` | checkbox | true | Auto Dispel Poison | Abolish Poison from party members |

---

## 12. Strategy Breakdown Per Playstyle

### Cat Playstyle Strategies (priority order)
```
[1]   CriticalEnergyShift    — emergency powershift at critical energy (<10) with mana
[2]   StealthSetup           — enter Prowl when not in combat and enabled
[3]   StealthRavage          — Ravage opener from stealth (behind target)
[3b]  StealthShred           — Shred opener from stealth (behind, if Ravage unavailable)
[3c]  StealthMangle          — Mangle opener from stealth (if configured)
[4]   FaerieFire             — maintain -armor debuff (no cost, no GCD)
[5]   Rip                    — 5CP finisher DoT, maintain on long-lived targets
[5b]  RipShift               — powershift for Rip when energy too low
[6]   ExecuteBite            — Ferocious Bite on low-HP targets (<25%)
[7]   FerociousBite          — Ferocious Bite when Rip has ≥3s left and 5 CP
[8]   MangleDebuff           — maintain +30% bleed debuff (12s)
[8b]  MangleShift            — powershift for Mangle when energy too low
[9]   Rake                   — maintain Rake DoT (9s)
[10]  ClearcastingShred      — free Shred on Clearcasting proc
[11]  BiteTrick              — low-energy Ferocious Bite before powershift
[12]  RakeTrick              — low-energy Rake before powershift
[13]  Shred                  — primary CP builder (behind target)
[14]  MangleBuilder          — fallback CP builder (not behind)
[15]  TigersFury             — +40 dmg at 0 energy
[16]  WolfsheadShred         — Shred optimized for Wolfshead shift timing
[17]  EarlyShift             — powershift when energy low and shift is profitable
```

### Bear Playstyle Strategies (priority order)
```
[1]   FrenziedRegen          — off-GCD emergency HP recovery
[2]   Enrage                 — off-GCD rage generation (if safe)
[3]   Growl                  — off-GCD single taunt (if not bear_no_taunt)
[4]   ChallengingRoar        — off-GCD AoE taunt emergency
[5]   LacerateUrgent         — GCD: refresh Lacerate before expiry (<3s, 5 stacks)
[6]   FaerieFire             — free, no GCD: maintain -armor
[7]   DemoRoar               — GCD: maintain AP reduction (30s)
[8]   SwipeAoE               — GCD: Swipe when 3+ targets (priority above Mangle)
[9]   Mangle                 — GCD: primary single-target damage/threat (6s CD)
[10]  Swipe                  — GCD: single-target filler
[11]  LacerateBuild          — GCD: build Lacerate stacks (below 5)
[12]  Maul                   — off-GCD: queue on next swing when rage ≥ threshold
```

### Balance Playstyle Strategies (priority order)
```
[1]   FaerieFire             — maintain -armor debuff (caster version)
[2]   ForceOfNature          — summon Treants on CD (3 min)
[3]   AoE                    — Hurricane when enemies ≥ threshold (Barkskin first)
[4]   Opener                 — pull from max range with Starfire
[5]   DPS                    — main rotation: DoTs + nukes with mana tier gating
        └─ If mana > tier1: Insect Swarm + Moonfire + Starfire
        └─ If mana > tier2: Insect Swarm + Starfire (drop Moonfire)
        └─ If mana < tier2: Wrath only (conserve)
```

### Resto Playstyle Strategies (priority order)
```
[1]   EmergencySwiftmend     — instant burst on critically low target
[2]   EmergencyNSRegrowth    — Nature's Swiftness + Regrowth instant combo
[3]   EmergencyBarkskin      — self-defense (off-GCD)
[4]   LifebloomTank          — maintain 3-stack Lifebloom rolling on tank
[5]   SwiftmendUrgent        — burst heal on moderate-low targets
[6]   RejuvTank              — keep Rejuvenation on tank for Swiftmend readiness
[7]   RegrowthLow            — cast Regrowth on injured targets (mana-gated)
[8]   RejuvSpread            — blanket HoTs on party members below proactive HP%
[9]   DispelCurse            — Remove Curse from party member
[10]  DispelPoison           — Abolish Poison from party member
[11]  Tranquility            — emergency AoE heal (10 min CD, last resort)
```

### Caster (Idle) Playstyle Strategies (priority order)
```
[1]   EmergencyHeal          — critical self-heal (NS + HT if available)
[2]   ProactiveHeal          — HoT maintenance when injured
[3]   RemoveCurse            — self-dispel
[4]   AbolishPoison          — self-dispel
[5]   Innervate              — self-mana recovery (solo)
[6]   MarkOfTheWild          — self-buff (OOC)
[7]   Thorns                 — self-buff (OOC)
[8]   OmenOfClarity          — self-buff (OOC)
```

### Shared Middleware (all playstyles)
```
[MW-500]  FormReshift         — re-enter correct form if accidentally shifted out
[MW-300]  RecoveryItems       — healthstone, healing potion, mana potion
[MW-280]  ManaRecovery        — mana potion, dark rune, innervate
```

---

## Key Implementation Notes

### Playstyle Detection
Druid uses **stance-based** playstyle detection (unlike Mage which uses a dropdown):

```lua
get_active_playstyle = function(context)
    local stance = Player:GetStance()
    if stance == 1 then return "bear" end          -- Bear/Dire Bear Form
    if stance == 3 then return "cat" end            -- Cat Form
    if stance == 5 then
        -- Stance 5 is shared: Moonkin / Tree of Life / Flight Form
        if IsSpellKnown(24858) then return "balance" end  -- Moonkin Form
        if IsSpellKnown(33891) then return "resto" end     -- Tree of Life
        return nil  -- Flight Form or unknown
    end
    if stance == 0 then return "caster" end         -- Human form
    return nil  -- Travel Form (4) or other
end

get_idle_playstyle = function(context)
    -- Caster strategies run as idle when in combat forms
    -- (self-buffs, heals handled here)
    return "caster"
end

idle_playstyle_name = "caster"
```

### Form Respect Pattern
During PVE combat, the rotation **follows the player's current form** — no automatic form-shifting. Instead, the A[1] suggestion icon shows when the player should shift. Auto-form strategies have `is_auto_form = true` and are suppressed during PVE combat in `execute_strategies`.

### extend_context Snippet
```lua
extend_context = function(ctx)
    ctx.stance = Player:GetStance()
    ctx.is_stealthed = Player:IsStealthed()
    ctx.energy = Player:Energy()
    ctx.cp = Player:ComboPoints()
    ctx.rage = Player:Rage()
    ctx.is_behind = Player:IsBehind(1.5)
    ctx.has_clearcasting = (Unit("player"):HasBuffs(16870) or 0) > 0
    ctx.enemy_count = A.MultiUnits:GetByRange(8)
    -- Cache invalidation flags
    ctx._cat_valid = false
    ctx._bear_valid = false
    ctx._resto_valid = false
end
```

### Cat context_builder Snippet
```lua
local cat_state = { ... }  -- Pre-allocated

local function get_cat_state(context)
    if context._cat_valid then return cat_state end
    context._cat_valid = true

    cat_state.pooling = false
    cat_state.mangle_duration = Unit(TARGET):HasDeBuffs(33876) or 0
    cat_state.rip_duration = Unit(TARGET):HasDeBuffs(1079) or 0
    cat_state.rake_duration = Unit(TARGET):HasDeBuffs(1822) or 0

    -- Powershifting calculations
    cat_state.cat_form_cost = NS.get_spell_mana_cost(A.CatForm) or 520
    cat_state.can_powershift = context.mana >= cat_state.cat_form_cost
    cat_state.shifts_remaining = math.floor(context.mana / cat_state.cat_form_cost)
    cat_state.has_wolfshead = ...  -- Helm slot check
    cat_state.wolfshead_bonus = cat_state.has_wolfshead and 20 or 0
    cat_state.energy_after_shift = 40 + cat_state.wolfshead_bonus

    return cat_state
end
```

### Bear context_builder Snippet
```lua
local bear_state = { ... }  -- Pre-allocated

local function get_bear_state(context)
    if context._bear_valid then return bear_state end
    context._bear_valid = true

    bear_state.lacerate_stacks = Unit(TARGET):HasDeBuffsStacks(33745) or 0
    bear_state.lacerate_duration = Unit(TARGET):HasDeBuffs(33745) or 0
    -- Nearby unit scanning for boss/elite/trash counts...

    return bear_state
end
```

### Resto context_builder Snippet
```lua
local resto_state = { ... }  -- Pre-allocated

local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    -- Party scan for healing targets
    -- Lifebloom tracking on tank
    resto_state.tank_lb_stacks = Unit(tank_unit):HasBuffsStacks(33763) or 0
    resto_state.tank_lb_duration = Unit(tank_unit):HasBuffs(33763) or 0
    -- Dispel target scanning...

    return resto_state
end
```

### Form-Aware Item Usage
Items in Cat/Bear form require special handling because using an item cancels the form. The addon creates form-specific Action entries with `Click = { macrobefore = "/cancelform\n/cast Cat Form\n" }` patterns to handle the item → re-form sequence.

### Debuff Tracking: Multi-Rank IDs
Faerie Fire and Demoralizing Roar require tracking ALL rank IDs since any Druid in the raid may have applied a different rank:
```lua
local FAERIE_FIRE_DEBUFF_IDS = { 16857, 17390, 17391, 17392, 27011 }  -- All Feral ranks
local DEMO_ROAR_DEBUFF_IDS = { 99, 1735, 9490, 9747, 9898, 26998 }    -- All ranks
```
