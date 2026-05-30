# TBC Paladin Implementation Research

Comprehensive research for implementing Retribution, Protection, and Holy Paladin playstyles.
Sources: wowsims/tbc simulator, Wowhead TBC, Icy Veins TBC Classic, wowtbc.gg

---

## Table of Contents

1. [Spell IDs (Max Rank TBC)](#1-spell-ids-max-rank-tbc)
2. [Retribution Paladin Rotation & Strategies](#2-retribution-paladin-rotation--strategies)
3. [Protection Paladin Rotation & Strategies](#3-protection-paladin-rotation--strategies)
4. [Holy Paladin Rotation & Strategies](#4-holy-paladin-rotation--strategies)
5. [AoE Rotation (All Specs)](#5-aoe-rotation-all-specs)
6. [Shared Utility & Defensive Strategies](#6-shared-utility--defensive-strategies)
7. [Mana Management System](#7-mana-management-system)
8. [Cooldown Management](#8-cooldown-management)
9. [Proposed Settings Schema](#9-proposed-settings-schema)
10. [Strategy Breakdown Per Playstyle](#10-strategy-breakdown-per-playstyle)

---

## 1. Spell IDs (Max Rank TBC)

### Holy Damage Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Judgement | 20271 | Instant | varies | 10s CD (8s w/ Imp. Judgement); unleashes active seal; does NOT trigger GCD |
| Consecration (R6) | 27173 | Instant | 660 | 8yd ground AoE, 8s duration, 8s CD |
| Holy Shock (R5) | 33072 | Instant | 650 | Damage OR heal depending on target; 15s CD; 31-pt Holy talent |
| Exorcism (R7) | 27138 | 1.5s | 295 | Undead/Demon ONLY; 15s CD |
| Hammer of Wrath (R4) | 27180 | 1.0s | 295 | Target must be below 20% HP; 6s CD; 30yd range |
| Avenger's Shield (R3) | 32700 | 1.0s | 780 | Bounces to 3 targets, 6s daze; 30s CD; 41-pt Prot talent |
| Holy Wrath (R3) | 27139 | 2.0s | 805 | Undead/Demon AoE, 20yd radius; 60s CD |

### Seal Spells
| Spell | ID | Mana | Duration | Notes |
|-------|------|------|----------|-------|
| Seal of Righteousness (R9) | 27155 | 260 | 30s | Flat Holy dmg per melee hit; scales with spell power; proc ID: 27156 |
| Seal of Command (R6) | 27170 | 280 | 30s | 7 PPM proc: 70% weapon dmg as Holy; proc ID: 20424; Ret talent |
| Seal of Command (R1) | 20375 | 65 | 30s | Use R1 for seal twisting (same proc, lower mana cost) |
| Seal of Blood | 31892 | 210 | 30s | Horde only; +35% weapon dmg as Holy per hit, 10% self-dmg; proc ID: 31893 |
| Seal of the Martyr | 348700 | 210 | 30s | Alliance SoB equivalent (TBC Classic 2.5.1+); verify ID in-game |
| Seal of Vengeance | 31801 | 250 | 30s | Alliance only; Holy DoT stacks to 5 (15s each); at 5 stacks: +33% weapon dmg; DoT ID: 31803 |
| Seal of Wisdom (R4) | 27166 | 270 | 30s | Melee hits restore ~74 mana (50% proc rate) |
| Seal of Light (R5) | 27160 | 280 | 30s | Melee hits restore ~95 HP (50% proc rate) |
| Seal of the Crusader (R7) | 27158 | 210 | 30s | +295 AP; judging applies +3% crit debuff (w/ Imp SotC talent) |
| Seal of Justice | 20164 | 135 | 30s | Chance to stun target on hit; PVP |

### Healing Spells
| Spell | ID | Cast Time | Mana | Notes |
|-------|------|-----------|------|-------|
| Holy Light (R11) | 27136 | 2.5s | 840 | 2551-2837 HP; Light's Grace: -0.5s next HL |
| Flash of Light (R7) | 27137 | 1.5s | 180 | 448-502 HP; most mana-efficient heal |
| Holy Shock (heal, R5) | 33072 | Instant | 650 | 931-987 HP; same spell as damage; 15s CD |
| Lay on Hands (R4) | 27154 | Instant | ALL | Full HP heal; drains all mana; 60 min CD (20 min talented) |

### Blessings (Single Target, 10 min)
| Spell | ID | Notes |
|-------|------|-------|
| Blessing of Might (R8) | 27140 | +220 AP |
| Blessing of Wisdom (R7) | 27142 | +41 mp5 |
| Blessing of Kings | 20217 | +10% all stats; Prot talent; single rank |
| Blessing of Salvation | 1038 | -30% threat; single rank |
| Blessing of Sanctuary (R5) | 27168 | Reduce dmg taken + Holy dmg on block; Prot talent |
| Blessing of Light (R4) | 27144 | +400 HL / +115 FoL healing received |
| Blessing of Protection (R3) | 10278 | 10s physical immunity; cannot attack; 5 min CD; Forbearance |
| Blessing of Freedom | 1044 | Immune to movement impairment; 10s; 25s CD; single rank |
| Blessing of Sacrifice (R2) | 27147 | Transfer up to 480 dmg to Paladin; 30s CD |

### Greater Blessings (30 min, class-wide, require Symbol of Kings reagent)
| Spell | ID | Notes |
|-------|------|-------|
| Greater Blessing of Might (R3) | 27141 | +220 AP class-wide |
| Greater Blessing of Wisdom (R3) | 27143 | +41 mp5 class-wide |
| Greater Blessing of Kings | 25898 | +10% all stats class-wide; single rank |
| Greater Blessing of Salvation | 25895 | -30% threat class-wide; single rank |
| Greater Blessing of Sanctuary (R2) | 27169 | DR + Holy retaliation class-wide |
| Greater Blessing of Light (R2) | 27145 | +HL/FoL healing received class-wide |

### Auras
| Spell | ID | Notes |
|-------|------|-------|
| Devotion Aura (R8) | 27149 | +861 armor to party |
| Retribution Aura (R6) | 27150 | 26 Holy dmg to melee attackers |
| Concentration Aura | 19746 | 35% pushback resistance; single rank |
| Shadow Resistance Aura (R4) | 27151 | +70 shadow resist |
| Frost Resistance Aura (R4) | 27152 | +70 frost resist |
| Fire Resistance Aura (R4) | 27153 | +70 fire resist |
| Sanctity Aura | 20218 | +10% Holy dmg; 21-pt Ret talent; single rank |
| Crusader Aura | 32223 | +20% mounted speed; TBC new; single rank |

### Base Spell IDs (for Action.Create with useMaxRank = true)
The framework resolves to max known rank automatically. Use these base IDs:
| Spell | Base ID | Max Rank ID | Notes |
|-------|---------|-------------|-------|
| Consecration | 26573 | 27173 (R6) | |
| Exorcism | 879 | 27138 (R7) | |
| Hammer of Wrath | 24275 | 27180 (R4) | |
| Holy Wrath | 2812 | 27139 (R3) | |
| Holy Light | 635 | 27136 (R11) | |
| Flash of Light | 19750 | 27137 (R7) | |
| Holy Shock | 20473 | 33072 (R5) | Holy talent |
| Avenger's Shield | 31935 | 32700 (R3) | Prot talent |
| Holy Shield | 20925 | 27179 (R4) | Prot talent |
| Seal of Righteousness | 20154 | 27155 (R9) | |
| Seal of Command | 20375 | 27170 (R6) | Ret talent |
| Seal of the Crusader | 21082 | 27158 (R7) | |
| Seal of Wisdom | 20166 | 27166 (R4) | |
| Seal of Light | 20165 | 27160 (R5) | |
| Devotion Aura | 465 | 27149 (R8) | |
| Retribution Aura | 7294 | 27150 (R6) | |
| Shadow Resistance Aura | 19876 | 27151 (R4) | |
| Frost Resistance Aura | 19888 | 27152 (R4) | |
| Fire Resistance Aura | 19891 | 27153 (R4) | |
| Blessing of Might | 19740 | 27140 (R8) | |
| Blessing of Wisdom | 19742 | 27142 (R7) | |
| Blessing of Light | 19977 | 27144 (R4) | |
| Blessing of Sanctuary | 20911 | 27168 (R5) | Prot talent |
| Blessing of Protection | 1022 | 10278 (R3) | |
| Blessing of Sacrifice | 6940 | 27147 (R2) | |
| Greater Blessing of Might | 25782 | 27141 (R3) | |
| Greater Blessing of Wisdom | 25894 | 27143 (R3) | |
| Greater Blessing of Light | 25890 | 27145 (R2) | |
| Greater Blessing of Sanctuary | 25899 | 27169 (R2) | |
| Lay on Hands | 633 | 27154 (R4) | |
| Hammer of Justice | 853 | 10308 (R4) | |
| Turn Evil | 10326 | 10326 (R2) | |

Single-rank spells (no useMaxRank needed):
| Spell | ID | Notes |
|-------|------|-------|
| Judgement | 20271 | No GCD in TBC |
| Crusader Strike | 35395 | TBC 41-pt Ret talent, 6s CD |
| Seal of Blood | 31892 | TBC, Horde only |
| Seal of the Martyr | 348700 | TBC Classic 2.5.1+, Alliance SoB; verify ID in-game |
| Seal of Vengeance | 31801 | TBC, Alliance only |
| Seal of Justice | 20164 | |
| Blessing of Kings | 20217 | Prot talent |
| Blessing of Salvation | 1038 | |
| Blessing of Freedom | 1044 | |
| Greater Blessing of Kings | 25898 | |
| Greater Blessing of Salvation | 25895 | |
| Concentration Aura | 19746 | |
| Sanctity Aura | 20218 | Ret talent |
| Crusader Aura | 32223 | TBC new |
| Avenging Wrath | 31884 | TBC, +30% dmg 20s, 3 min CD |
| Divine Illumination | 31842 | TBC, 41-pt Holy talent |
| Divine Favor | 20216 | Holy talent |
| Repentance | 20066 | 31-pt Ret talent, 1 min CD |
| Righteous Defense | 31789 | TBC taunt, 8s CD |
| Righteous Fury | 25780 | Toggle: +90% Holy threat |
| Cleanse | 4987 | |
| Purify | 1152 | |
| Divine Intervention | 19752 | |
| Divine Shield | 642 | 12s immunity, 5 min CD |
| Divine Protection | 5573 | -50% dmg taken, 5 min CD |
| Spiritual Attunement | 33776 | Passive: 10% of heals received = mana |

### Cooldown Abilities
| Spell | ID | CD | Duration | Notes |
|-------|------|----|----------|-------|
| Avenging Wrath | 31884 | 3 min | 20s | +30% all dmg; causes Forbearance |
| Divine Shield | 642 | 5 min | 12s | Full immunity, can't attack; causes Forbearance |
| Divine Protection | 5573 | 5 min | 12s | -50% all dmg taken; causes Forbearance |
| Lay on Hands (R4) | 27154 | 60 min (20 min talented) | Instant | Full HP heal, drains all mana; causes Forbearance |
| Blessing of Protection (R3) | 10278 | 5 min | 10s | Physical immunity on target; causes Forbearance |
| Hammer of Justice (R4) | 10308 | 60s (40s talented) | 6s stun | 10yd range |
| Holy Shield (R4) | 27179 | 10s | 10s (4 charges, 8 w/ Improved) | +30% block, Holy dmg on block; Prot talent |
| Avenger's Shield (R3) | 32700 | 30s | 1.0s cast | 3 targets, 6s daze; Prot talent |
| Crusader Strike | 35395 | 6s | Instant | 110% weapon dmg + refreshes all Judgements; Ret talent |
| Holy Shock (R5) | 33072 | 15s | Instant | Dmg or heal; Holy talent |
| Consecration (R6) | 27173 | 8s | 8s | Ground AoE; CD = duration |
| Exorcism (R7) | 27138 | 15s | 1.5s cast | Undead/Demon only |
| Hammer of Wrath (R4) | 27180 | 6s | 1.0s cast | Execute only (<20% HP) |
| Holy Wrath (R3) | 27139 | 60s | 2.0s cast | Undead/Demon AoE |
| Righteous Defense | 31789 | 8s | Instant | Taunt 3 mobs off friendly target |
| Blessing of Freedom | 1044 | 25s | 10s | Movement immunity |
| Blessing of Sacrifice (R2) | 27147 | 30s | 30s | Transfer up to 480 dmg |
| Divine Illumination | 31842 | 3 min | 15s | -50% mana cost; Holy talent |
| Divine Favor | 20216 | 2 min | Next spell | 100% crit next HL/FoL/HS; Holy talent |
| Repentance | 20066 | 1 min | 6s | Incapacitate Humanoid; Ret talent |
| Turn Evil (R2) | 10326 | 30s | 1.5s cast | Fear Undead/Demon 20s |

### Defensive & Utility
| Spell | ID | CD | Notes |
|-------|------|----|-------|
| Divine Shield | 642 | 5 min | 12s immunity; can't attack; Forbearance 1 min |
| Divine Protection | 5573 | 5 min | -50% all dmg 12s; Forbearance; -50% attack speed |
| Lay on Hands (R4) | 27154 | 60/20 min | Full HP heal; drains all mana; Forbearance |
| Blessing of Protection (R3) | 10278 | 5 min | 10s physical immunity on target; Forbearance |
| Blessing of Freedom | 1044 | 25s | 10s immune to movement impairment |
| Blessing of Sacrifice (R2) | 27147 | 30s | Transfer 480 dmg from target to paladin |
| Hammer of Justice (R4) | 10308 | 60/40s | 6s stun, 10yd |
| Righteous Defense | 31789 | 8s | Taunt 3 mobs off friendly |
| Cleanse | 4987 | — | Remove 1 poison + 1 disease + 1 magic (magic w/ talent) |
| Purify | 1152 | — | Remove 1 poison + 1 disease (no talent needed) |
| Righteous Fury | 25780 | — | Toggle: +90% Holy threat; +6% DR w/ Improved RF |
| Divine Intervention | 19752 | — | Sacrifice self to protect target (wipe mechanic) |

### Self-Buffs
| Spell | ID | Duration | Notes |
|-------|------|----------|-------|
| Righteous Fury | 25780 | Toggle | +90% Holy spell threat; +6% DR with Improved RF talent |
| Devotion Aura (R8) | 27149 | Persistent | +861 armor to party |
| Retribution Aura (R6) | 27150 | Persistent | 26 Holy dmg to melee attackers |
| Concentration Aura | 19746 | Persistent | 35% pushback resistance |
| Sanctity Aura | 20218 | Persistent | +10% Holy dmg; Ret talent |
| Blessing of Might (R8) | 27140 | 10 min | +220 AP (self or group) |
| Blessing of Kings | 20217 | 10 min | +10% all stats (Prot talent) |
| Blessing of Wisdom (R7) | 27142 | 10 min | +41 mp5 |

### Conjured / Class Items
Paladin has no conjured items. Uses standard consumables only.

### Racial Spell IDs
| Race | Racial | ID | Notes |
|------|--------|------|-------|
| Blood Elf | Arcane Torrent | 28730 | Silence 2s in 8yd + 6% mana, 2 min CD |
| Blood Elf | Mana Tap | 28734 | Drain mana from target, 30s CD |
| Human | Perception | 20600 | +Stealth detection 20s, 3 min CD (PVP) |
| Human | The Human Spirit | 20598 | Passive +10% spirit |
| Human | Sword Specialization | 20597 | Passive +5 expertise with swords |
| Human | Mace Specialization | 20864 | Passive +5 expertise with maces |
| Dwarf | Stoneform | 20594 | Remove bleed/poison/disease + 10% armor, 2 min CD |
| Draenei | Gift of the Naaru | 28880 | HoT heal over 15s, 3 min CD |
| Draenei | Symbol of Hope | 32548 | Party-wide mana restore, 5 min CD |

### Consumable Item IDs
| Item | ID | Notes |
|------|------|-------|
| Super Mana Potion | 22832 | 1800-3000 mana, 2 min CD |
| Super Healing Potion | 22829 | 1500-2500 HP, 2 min CD |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP (separate CD) |
| Demonic Rune | 12662 | Same as Dark Rune (shared CD with Dark Rune) |
| Haste Potion | 22838 | +400 haste rating 15s, shares potion CD (Ret) |
| Ironshield Potion | 22849 | +2500 armor 2 min, shares potion CD (Prot) |
| Destruction Potion | 22839 | +120 SP, +2% spell crit 15s, shares potion CD |
| Master Healthstone | 22104 | 2496 HP |

### Debuff IDs (for tracking on target)
| Debuff | ID | Duration | Notes |
|--------|------|----------|-------|
| Judgement of the Crusader | 27159 | 20s | +3% crit to all attacks (w/ Imp SotC talent) |
| Judgement of Wisdom | 27164 | 20s | Attacks restore ~74 mana to attacker |
| Judgement of Light | 27163 | 20s | Attacks restore ~95 HP to attacker |
| Judgement of Righteousness | 27157 | — | Direct Holy dmg (no persistent debuff) |
| Judgement of Blood | 31898 | — | Direct Holy dmg (Horde) |
| Judgement of Vengeance | 31804 | — | Direct Holy dmg per SoV stack (Alliance) |
| Judgement of Command | 29386 | — | Direct Holy dmg (double if stunned) |
| Seal of Vengeance DoT | 31803 | 15s per stack | Stacks to 5 on target |
| Vindication | 26016 | 10s | -15% AP on target; Ret talent |

### Buff IDs (for tracking on player)
| Buff | ID | Notes |
|------|------|-------|
| Seal of Righteousness | 27155 | Active seal check (max rank) |
| Seal of Command | 27170 | Active seal check (max rank; R1 = 20375) |
| Seal of Blood | 31892 | Active seal check |
| Seal of the Martyr | 348700 | Active seal check (verify in-game) |
| Seal of Vengeance | 31801 | Active seal check |
| Seal of Wisdom | 27166 | Active seal check |
| Seal of Light | 27160 | Active seal check |
| Seal of the Crusader | 27158 | Active seal check |
| Avenging Wrath | 31884 | +30% dmg active |
| Vengeance (Ret talent) | 20059 | +5% phys+Holy per stack, max 3 stacks, 30s (5/5 talent) |
| Divine Shield | 642 | Immunity active |
| Divine Protection | 5573 | -50% dmg active |
| Divine Favor | 20216 | Next heal guaranteed crit |
| Divine Illumination | 31842 | -50% mana cost active |
| Holy Shield | 27179 | +30% block active (charges) |
| Righteous Fury | 25780 | Holy threat increase active |
| Light's Grace | 31834 | -0.5s next HL cast, 15s |
| Forbearance (debuff) | 25771 | 1 min; prevents DS/DP/BoP/LoH |
| Redoubt (talent proc) | 20137 | +30% block chance after being crit |
| Reckoning (talent proc) | 20182 | Extra attack after being crit |

### IMPORTANT: Mechanics That Do NOT Exist in TBC
Do NOT implement these — they are Wrath of the Lich King (3.0+) or later:
| Mechanic | Expansion | Notes |
|----------|-----------|-------|
| Divine Storm | Wrath (3.0) | Ret AoE ability does not exist |
| Beacon of Light | Wrath (3.0) | Heal transfer does not exist |
| Sacred Shield | Wrath (3.0) | Absorb shield does not exist |
| Art of War | Wrath (3.0) | Instant FoL/Exorcism proc does not exist |
| Hammer of the Righteous | Wrath (3.0) | Prot AoE ability does not exist |
| Shield of Righteousness | Wrath (3.0) | Prot shield slam does not exist |
| Hand spells | Wrath (3.0) | In TBC these are "Blessing of ..." not "Hand of ..." |
| Seal of Corruption | Wrath (3.0) | Horde has Seal of Blood, not Corruption |
| Divine Plea | Wrath (3.0) | Mana recovery spell does not exist |
| Judgements of the Pure | Wrath (3.0) | Haste from judging does not exist |
| Judgements of the Wise | Wrath (3.0) | Mana return on judge does not exist |
| Aura Mastery | Wrath (3.0) | Does not exist |
| Avenger's Shield silence | Wrath (3.0) | In TBC it only dazes, NOT silence |
| Crusader Strike baseline | Wrath (3.0) | In TBC: 41-pt Ret talent ONLY |
| Judgement split into 3 | Wrath (3.0) | In TBC: single "Judgement" spell unleashes active seal |
| Holy Power resource | Cataclysm (4.0) | Paladin uses ONLY mana in TBC |
| Templar's Verdict | Cataclysm (4.0) | Does not exist |
| Word of Glory | Cataclysm (4.0) | Does not exist |
| Inquisition | Cataclysm (4.0) | Does not exist |
| Guardian of Ancient Kings | Cataclysm (4.0) | Does not exist |
| Exorcism on all targets | Wrath (3.3) | In TBC, Exorcism is Undead/Demon ONLY |

**What IS new in TBC (vs Classic):**
- Crusader Strike (41-pt Ret talent)
- Avenger's Shield (41-pt Prot talent)
- Seal of Blood / Seal of Vengeance (new faction-specific seals)
- Seal of the Martyr (TBC Classic 2.5.1+, Alliance parity with SoB)
- Avenging Wrath (+30% damage CD)
- Spiritual Attunement (passive: 10% of heals received = mana)
- Righteous Defense (Paladin taunt — didn't exist in Classic!)
- Divine Illumination (41-pt Holy talent)
- Fanaticism (Ret: -25% threat)
- Crusader Aura (+20% mounted speed)
- Greater Blessings (30 min class-wide versions)
- Cleanse can remove magic (with Sacred Cleansing Holy talent)
- Blood Elf Paladins (Horde Paladin access)
- Seal twisting (exploit/mechanic: two seals proc per swing)

---

## 2. Retribution Paladin Rotation & Strategies

### ⚠️ API Caveat: `Player:GetSwing()` returns REMAINING time, not duration
**This bug silently broke seal twisting (only ~18 SoB hits vs ~113 in a clean log).**

`Player:GetSwing(slot)` returns the time **remaining** until the next swing — NOT the
swing's total duration. `Player:GetSwingStart(slot)` returns the timestamp the current
swing cycle started. Therefore:
- **time until next swing = `Player:GetSwing(slot)` directly** (guard for 0/nil).
- total cycle length, if needed = `(GetTime() - swingStart) + GetSwing(slot)`.

The broken pattern (treating `GetSwing` as duration):
```lua
-- WRONG: evaluates to (remaining - elapsed) = total - 2*elapsed
local t = (swingStart + GetSwing(1)) - GetTime()
```
This bottoms out near the swing's **midpoint** (~1.8s too early on a 3.6s weapon), so
the twist window opened mid-cycle: Seal of Blood/Martyr was cast far too soon and then
overwritten by the Prep-SoC step before the swing landed. The surrounding twist guards
were correct — they were just fed a garbage timer.

Confirmed empirically via the Shaman swing-sync work — see the authoritative comment and
`swing_state()` in `rotation/source/aio/shaman/enhancement.lua` (~line 266). The Ret fix
lives in `rotation/source/aio/paladin/class.lua` `extend_context` (`time_to_swing`).

**Still buggy elsewhere:** the shared helpers `get_time_until_swing` / `is_swing_landing_soon`
in `rotation/source/aio/core.lua` use the same wrong formula and are consumed by Warrior
(fury/arms/middleware) and Druid (cat/bear). Their thresholds may be tuned around the
wrong behavior, so re-verify each class before "fixing" the shared helpers.

### Core Mechanic: Seal Twisting
Seal twisting is THE defining mechanic of TBC Ret Paladin. It exploits the ~0.4s server batching window to proc two seals on a single auto-attack swing.

> **IMPORTANT — twisting is UNIDIRECTIONAL (Command → Blood only):** You can only twist
> *from* Seal of Command *into* Seal of Blood/Martyr, not the reverse. So Command is the
> **"prep" seal** (you must be on Command to twist) and Blood/Martyr is the **"twist"
> seal** (what you twist into, right before the swing). After the twist, you **leave
> Blood up** — it rides through CS / fillers / Judgement as the resident seal until you
> prep Command again shortly before the next swing.
>
> This means **Blood/Martyr has the dominant UPTIME** (it's up most of the cycle) even
> though **Command is the seal you twist *from***. A good ret parse: Martyr ~64% /
> Command ~41%. Two wrong implementations to avoid:
> 1. **Command resident the whole cycle** (old PrepSoC re-sealed Command after every
>    Judgement) → Command ~62% / Martyr ~38%. Wrong: Blood barely up.
> 2. **Flashing Command in while Blood is resident** (a brief mistaken "inversion") →
>    that's the Blood→Command direction, which does NOT twist. The swing ends on Command.
>
> Correct: Blood resident → briefly prep Command in the ~1.5s before the swing → twist
> into Blood in the 0.4s window → Blood rides again.

**How it works:**
1. Seal of Blood/Martyr is up (resident) for most of the swing cycle
2. ~1.5s before the swing (one GCD + the window), cast **Seal of Command** (prep)
3. ~0.4s before the swing, cast **Seal of Blood/Martyr** (the twist into Blood)
4. The swing processes BOTH seals: Command via the overlap + Blood's guaranteed +35% weapon dmg
5. Blood stays up after the swing (Judge it, CS, fillers) until the next prep
6. This is approximately a 13% DPS increase over non-twisting

**Key rules:**
- **Command → Blood only** (unidirectional). Command is the prep/"from" seal; Blood is what you twist into and then keep up.
- **Blood/Martyr should have the dominant uptime.** Don't let the rotation keep Command resident between twists (the original bug, around Judgement/CS).
- Use **Seal of Command Rank 1** (base ID 20375) for the prep — saves mana (65 vs 280); proc damage comes from the proc itself, not seal rank. (Configurable: `ret_twist_seal_rank`, default R1.)
- Never Judge Seal of Command — only Judge Seal of Blood
- Requires a swing timer for the 0.4s window (see the GetSwing caveat above)
- wowsims constant: `twistWindow = 399 * time.Millisecond`
- Only Judge Blood during its resident phase, not inside the pre-twist lead (Judgement consumes the seal and would fight the prep → twist sequence).

**Seal Twist Cycle (corrected — Command preps, twist INTO Blood, Blood rides):**
```
Seal of Blood/Martyr resident (up most of the cycle)
  → Judge Seal of Blood when off CD during the resident phase (off-GCD!) → re-apply Blood
  → ~1.5s before the swing: cast Seal of Command  (PREP — the "from" seal)
  → ~0.4s before the swing: cast Seal of Blood     (TWIST — Command -> Blood)
  → Swing lands (both seals proc: Command via overlap + Blood guaranteed)
  → Blood stays up (resident) through CS / fillers
  → Repeat
```

Flux implementation: `Ret_MaintainBlood` (resident Blood), `Ret_PrepCommand` (prep in the
short lead, gated by `PREP_LEAD_BUFFER`), `Ret_TwistBlood` (Command → Blood in the window).

### Vengeance Talent
- Each melee/spell crit grants +1 stack of Vengeance buff (ID: 20059)
- Per stack: +5% physical and Holy damage (at 5/5 talent)
- Stacks to 3 max = +15% total damage
- Duration: 30 seconds per stack
- 100% proc rate on any crit — with ~30% crit rate, near-100% uptime

### Single Target Rotation (from wowsims `rotation.go`)

> **NOTE:** The wowsims priority below describes the same unidirectional Command → Blood
> twist, but its phrasing ("Prep Twist → cast Seal of Command" whenever Command is
> inactive) reads as if Command is held as the default seal. In a SIM that's harmless —
> it hits the 0.4s window every swing, so Blood is always twisted back in. **Live**, the
> rotation must only prep Command in the short lead before the swing and keep Blood
> resident the rest of the time (see the corrected cycle above), otherwise Command ends
> up resident and Blood's uptime craters. Same mechanic, stricter timing live.

The wowsims retribution rotation operates in three phases: opener, main rotation, and low-mana fallback.

```
OPENER:
1. Cast selected Judgement (Wisdom or Crusader depending on config)
2. Cast Seal of Command (R1)
3. Cast Seal of Blood → enable auto-attacks → begin twist cycle

MAIN ROTATION (priority order, on GCD ready):
1. Complete Seal Twist — if SoC active AND in twist window → cast Seal of Blood
2. Crusader Strike — if ready AND not about to twist AND (SoB active OR GCD < time_to_swing)
3. Prep Twist — if SoC inactive AND next Judge CD > latest twist start → cast Seal of Command (R1)
4. Judgement of Blood — when SoB active AND about to twist (Judge → lose SoB → apply SoC → twist back)
5. Reapply Seal of Blood — if no seal active AND not about to twist (catch-all)
6. Fillers (only when no twist planned AND won't clip CS or twist):
   a. Exorcism — if demon/undead target AND mana > 40% max
   b. Consecration — if configured AND mana > 60% max

LOW MANA MODE (mana ≤ 1000 AND SoC not active):
- Roll Seal of Blood with Judgement when expiring
- Cast Crusader Strike on CD (unless seal would expire mid-cast)
- Avoid actions that cause seal drops
- No twisting — just maintain SoB + CS
```

### Rotation Variants (from wowsims)
- **Normal**: 1 Crusader Strike + 1 Seal Twist per auto-attack cycle
- **Under Bloodlust**: 1 Crusader Strike + 2 Seal Twists per cycle (faster swing speed = more GCDs between swings)

### Twist Scheduling Logic (from wowsims)
The sim schedules actions for the next occurrence of:
- Auto-attack swing landing
- Twist window opening (swing_time - 0.399s)
- GCD becoming ready
- Judgement coming off CD
- Crusader Strike coming off CD

**Will-twist condition**: `time_to_swing > spell_GCD + ability_GCD` AND `next_swing + spell_GCD <= next_CS_CD + delay`

### Execute Phase (target <20% HP)
- Same rotation but add Hammer of Wrath on CD (1.0s cast, 6s CD, 30yd range)
- Hammer of Wrath is a ranged spell — use between melee swings
- Priority: Judgement > CS > Hammer of Wrath > Twist > Fillers

### Mana Thresholds (from wowsims)
- **Exorcism**: only cast when `current_mana > max_mana * 0.40`
- **Consecration**: only cast when `current_mana > max_mana * 0.60`
- **Low mana mode**: triggers when `mana ≤ 1000` — drops twisting entirely

### State Tracking Needed
```lua
-- Pre-allocated state table
local ret_state = {
    seal_blood_active = false,
    seal_command_active = false,
    jotc_on_target = false,
    jotc_duration = 0,
    jow_on_target = false,
    jol_on_target = false,
    vengeance_stacks = 0,
    vengeance_duration = 0,
    target_below_20 = false,
    -- Swing timer for seal twisting
    swing_timer_remaining = 0,
    in_twist_window = false,   -- within 0.4s of swing
}

local function get_ret_state(context)
    if context._ret_valid then return ret_state end
    context._ret_valid = true

    -- Seal tracking
    ret_state.seal_blood_active = (Unit(PLAYER_UNIT):HasBuffs(31892) or 0) > 0
                               or (Unit(PLAYER_UNIT):HasBuffs(348700) or 0) > 0  -- Martyr
    ret_state.seal_command_active = (Unit(PLAYER_UNIT):HasBuffs(20375) or 0) > 0
                                 or (Unit(PLAYER_UNIT):HasBuffs(27170) or 0) > 0

    -- Judgement tracking
    ret_state.jotc_on_target = (Unit(TARGET_UNIT):HasDeBuffs(27159) or 0) > 0
    ret_state.jotc_duration = Unit(TARGET_UNIT):HasDeBuffs(27159) or 0
    ret_state.jow_on_target = (Unit(TARGET_UNIT):HasDeBuffs(27164) or 0) > 0
    ret_state.jol_on_target = (Unit(TARGET_UNIT):HasDeBuffs(27163) or 0) > 0

    -- Vengeance
    ret_state.vengeance_stacks = Unit(PLAYER_UNIT):HasBuffsStacks(20059) or 0
    ret_state.vengeance_duration = Unit(PLAYER_UNIT):HasBuffs(20059) or 0

    -- Execute
    ret_state.target_below_20 = context.target_hp < 20

    -- Execute
    ret_state.target_below_20 = context.target_hp < 20

    -- Mana thresholds (from wowsims)
    ret_state.low_mana = context.mana <= 1000
    ret_state.can_exorcism = context.mana_pct > 40
    ret_state.can_consecration = context.mana_pct > 60

    -- Swing timer
    local swing_duration = Player:GetSwing(1) or 0
    local swing_start = Player:GetSwingStart(1) or 0
    local now = GetTime()
    local elapsed = now - swing_start
    ret_state.swing_timer_remaining = swing_duration - elapsed
    ret_state.in_twist_window = ret_state.swing_timer_remaining > 0
                            and ret_state.swing_timer_remaining <= 0.4

    return ret_state
end
```

---

## 3. Protection Paladin Rotation & Strategies

### Core Mechanic: Spell-Based Threat
Prot Paladin generates threat primarily through Holy spell damage, not melee. All Holy threat is amplified by Righteous Fury (+90%, +6% DR with Improved RF talent). This makes Prot the **best AoE tank** in TBC.

### Holy Shield Mechanics
- **Duration**: 10s / **Cooldown**: 10s (100% uptime possible)
- **Charges**: 4 baseline, **8 with Improved Holy Shield** (2/2 Prot talent)
- **Block chance**: +30% while active
- **Damage per block**: 155 Holy (R4) scaled by ~5% spell power coefficient
- **Threat**: +35% additional threat on Holy Shield block damage
- **Mana**: 280
- **CRITICAL**: Must maintain 100% uptime for crushing blow prevention (need 102.4% total avoidance+block)

### Spiritual Attunement (Primary Mana Source)
- Passive: 10% of healing received from OTHER players = mana (R2 at level 66)
- Post-patch 2.1: overhealing does NOT count
- This transforms mana into a "rage-like" resource: take damage → receive heals → get mana
- Key implication: if not taking damage (offtanking), mana can be a problem

### Single Target (Boss) Threat Priority (from wowsims `rotation.go`)
The wowsims protection rotation uses this `OnGCDReady()` priority:

```
PRE-CHECK: Righteous Fury — ALWAYS active (toggle check; never let it drop)

SEAL & JUDGEMENT CYCLING:
  If using Seal of Wisdom judgement:
    → Judge (applies JoW debuff) → switch to Seal of Righteousness
  If using Seal of Light judgement:
    → Judge (applies JoL debuff) → switch to Seal of Righteousness

MAIN PRIORITY:
1. Establish Seal of Righteousness (base seal for threat)
2. Holy Shield — if PrioritizeHolyShield enabled (100% uptime)
3. Consecration — on CD (8s)
4. Judgement of Righteousness + re-seal SoR combo
5. Exorcism — if target is undead/demon AND mana > 40% max
6. Holy Shield — if not prioritized earlier (fallback slot)

ON OOM: Mark out-of-mana, pause 5 seconds before retrying
```

**Key insight from wowsims**: Avenger's Shield is NOT in the `OnGCDReady()` rotation — it's used as a pull ability only, not part of the sustained threat rotation. The `nextCDAt()` function only tracks Holy Shield, Judgement, and Consecration readiness.

**`PrioritizeHolyShield` setting**: When enabled, Holy Shield fires before Consecration. When disabled, it falls to a lower priority slot. Default should be enabled (crushing blow prevention).

### Seal Choice for Tanking
- **Primary**: Seal of Righteousness — flat Holy per swing, consistent threat
- **Judgement cycling**: Seal of Wisdom → Judge → Seal of Righteousness (for mana); or Seal of Light → Judge → SoR (for healing)
- **Long fights (Alliance)**: Seal of Vengeance — stacking DoT, superior TPS at 5 stacks
- **Mana recovery**: Seal of Wisdom judging cycle (from wowsims pattern)
- **Never**: Seal of Blood — self-damage is counterproductive for tanks

### AoE Tanking (Prot Paladin Specialty)
```
Pull:
1. Avenger's Shield (3 targets, 6s daze)
2. Consecration immediately (8yd AoE, 8s)
3. Holy Shield (block dmg from all attackers)

Sustain:
4. Re-Consecrate on CD (8s)
5. Re-Holy Shield on CD (10s)
6. Tab-target Judgement for snap threat
7. Seal of Wisdom for mana sustain on large packs
8. Retribution Aura (passive retaliation dmg)
```

### State Tracking Needed
```lua
local prot_state = {
    righteous_fury_active = false,
    holy_shield_active = false,
    holy_shield_duration = 0,
    sov_stacks = 0,       -- Seal of Vengeance DoT stacks on target (0-5)
    sov_duration = 0,
    below_ardent_defender = false,  -- HP < 35%
}

local function get_prot_state(context)
    if context._prot_valid then return prot_state end
    context._prot_valid = true

    prot_state.righteous_fury_active = (Unit(PLAYER_UNIT):HasBuffs(25780) or 0) > 0
    prot_state.holy_shield_active = (Unit(PLAYER_UNIT):HasBuffs(27179) or 0) > 0
    prot_state.holy_shield_duration = Unit(PLAYER_UNIT):HasBuffs(27179) or 0

    -- Seal of Vengeance tracking (Alliance)
    prot_state.sov_stacks = Unit(TARGET_UNIT):HasDeBuffsStacks(31803) or 0
    prot_state.sov_duration = Unit(TARGET_UNIT):HasDeBuffs(31803) or 0

    prot_state.below_ardent_defender = context.hp < 35

    return prot_state
end
```

---

## 4. Holy Paladin Rotation & Strategies

### Core Mechanic: Efficient Single-Target Healing
Holy Paladin is primarily a tank healer in TBC. The "rotation" is reactive — choosing between Flash of Light (efficient) and Holy Light (powerful) based on damage intake.

### Flash of Light vs Holy Light
- **Flash of Light (R7)**: 1.5s cast, 180 mana, 448-502 HP. Very mana-efficient. Use for moderate damage.
- **Holy Light (R11)**: 2.5s cast (2.0s with Light's Grace), 840 mana, 2551-2837 HP. Use for heavy damage.
- **Rule of thumb**: FoL when target is above 60% HP; HL when below 60% or big hits incoming.

### Light's Grace Talent
- After casting Holy Light, next HL cast time reduced by 0.5s for 15s (2.5s → 2.0s)
- Maintain this buff by casting HL periodically — even one HL every 15s keeps it rolling
- Buff ID: 31834

### Illumination Talent (Critical for Mana)
- 5/5: 100% chance that critical heals return 60% of base mana cost
- FoL crit: ~108 mana returned; HL crit: ~504 mana returned
- Makes crit an extremely valuable stat for Holy Paladins

### Divine Favor + Holy Shock Combo
- Divine Favor (20216): Next heal is guaranteed crit, 2 min CD
- Best used with Holy Light for maximum healing + Illumination mana return
- Or with Holy Shock for instant guaranteed crit heal in emergencies

### Divine Illumination (TBC 41-pt Talent)
- 50% mana cost reduction for all spells for 15s, 3 min CD
- Use during periods of heavy Holy Light spam for massive mana savings

### Judgement Usage While Healing
- Maintain Judgement of Light (27163) or Wisdom (27164) on boss when safe to do so
- Keep Seal of Wisdom active for passive mana from own melee hits (if in melee range)
- Only judge when it won't cost healing uptime — raid survival always takes priority

### Healing Priority
```
Emergency:
1. Divine Favor + Holy Light — guaranteed crit big heal (2 min CD)
2. Holy Shock — instant emergency (15s CD, 931-987 HP)
3. Lay on Hands — last resort full heal (60/20 min CD)

Normal:
4. Holy Light — target below HL HP% threshold (heavy damage)
5. Flash of Light — target below FoL HP% threshold (moderate damage)

Utility:
6. Cleanse — remove debuffs from party
7. Judgement of Light/Wisdom — maintain on boss when safe
8. Seal of Wisdom — maintain for mana recovery
```

### State Tracking Needed
```lua
local holy_state = {
    lights_grace_active = false,
    lights_grace_duration = 0,
    divine_favor_active = false,
    divine_illumination_active = false,
    jol_on_target = false,
    jol_duration = 0,
    jow_on_target = false,
    jow_duration = 0,
}

local function get_holy_state(context)
    if context._holy_valid then return holy_state end
    context._holy_valid = true

    holy_state.lights_grace_active = (Unit(PLAYER_UNIT):HasBuffs(31834) or 0) > 0
    holy_state.lights_grace_duration = Unit(PLAYER_UNIT):HasBuffs(31834) or 0
    holy_state.divine_favor_active = (Unit(PLAYER_UNIT):HasBuffs(20216) or 0) > 0
    holy_state.divine_illumination_active = (Unit(PLAYER_UNIT):HasBuffs(31842) or 0) > 0

    -- Judgement tracking on target
    holy_state.jol_on_target = (Unit(TARGET_UNIT):HasDeBuffs(27163) or 0) > 0
    holy_state.jol_duration = Unit(TARGET_UNIT):HasDeBuffs(27163) or 0
    holy_state.jow_on_target = (Unit(TARGET_UNIT):HasDeBuffs(27164) or 0) > 0
    holy_state.jow_duration = Unit(TARGET_UNIT):HasDeBuffs(27164) or 0

    return holy_state
end
```

---

## 5. AoE Rotation (All Specs)

### Retribution AoE
Limited options. Consecration (660 mana, 8s CD) is the primary and only real AoE ability.
- Consecration on CD
- Continue Seal twisting + Judging for single-target damage on priority target
- Very mana-expensive; avoid on long AoE packs unless mana is healthy

### Protection AoE (BEST AoE Tank in TBC)
```
1. Avenger's Shield on pull (3 targets, 6s daze)
2. Consecration immediately (8yd AoE)
3. Holy Shield (block dmg from all attackers — charges consumed by blocks)
4. Retribution Aura (passive retaliation to all melee attackers)
5. Seal of Wisdom for mana sustain on large packs
6. Tab-target Judgement for snap threat on stragglers
7. Re-Consecrate + Re-Holy Shield on CD
8. Holy Wrath vs Undead/Demon packs (60s CD, AoE stun)
```

### Holy AoE
Not applicable — healers don't AoE.

---

## 6. Shared Utility & Defensive Strategies

### Emergency Defense (Middleware candidates)
1. **Divine Shield** (642) — 12s full immunity; 5 min CD; can't attack; Forbearance
   - Use when: about to die and no other option
   - Note: Forbearance (25771) prevents DS/DP/BoP/LoH for 1 min
2. **Lay on Hands** (27154) — full HP heal; drains all mana; 60/20 min CD; Forbearance
   - Use when: critically low HP and LoH will save a wipe
3. **Divine Protection** (5573) — -50% all dmg 12s; 5 min CD; Forbearance
   - Prot spec: use when damage is heavy but still need to tank
4. **Blessing of Protection** (10278) — 10s physical immunity on target; Forbearance
   - Not for self (can't attack); use on friendly targets

### Dispel/Utility
1. **Cleanse** (4987) — remove poison + disease + magic (magic w/ Holy talent)
2. **Hammer of Justice** (10308) — 6s stun interrupt, 60/40s CD
3. **Righteous Defense** (31789) — taunt 3 mobs off friendly, 8s CD

### Forbearance Mechanic (Critical Implementation Note)
- Debuff ID: 25771, 1 min duration
- Applied by: Divine Shield, Divine Protection, Blessing of Protection, Lay on Hands, Avenging Wrath
- While active: CANNOT use any of the above abilities
- Must track Forbearance to prevent attempting blocked abilities
- Ret consideration: Avenging Wrath causes Forbearance → no emergency DS for 1 min

---

## 7. Mana Management System

### Retribution Mana (thresholds from wowsims)
1. **Spiritual Attunement**: SoB self-damage → healer tops you off → mana. Primary mana source.
2. **Seal of Command R1** for twisting: 65 mana vs 280 for max rank
3. **Sanctified Judgement** (talent): 33% chance to return 80% of Judgement mana
4. **Exorcism gate**: only when `mana > 40% max` (wowsims)
5. **Consecration gate**: only when `mana > 60% max` (wowsims)
6. **Low mana mode**: at `mana ≤ 1000` — drop twisting, just SoB + CS (wowsims)
7. **Judge Wisdom** on target if mana-starved on long fights (opener option in wowsims)
8. **Super Mana Potion** + **Dark Rune** on CD if mana is critical

### Protection Mana (from wowsims)
1. **Spiritual Attunement**: Primary mana source (taking damage + heals = mana)
2. **Seal of Wisdom → Judge → re-seal SoR** cycle: wowsims pattern for mana recovery
3. **Exorcism gate**: only when `mana > 40% max` (wowsims)
4. **OOM handling**: wowsims pauses rotation for 5 seconds on failed cast, then retries
5. **Priority trade-off**: Holy Shield > Consecration > Judgement when mana is low
   - Never drop Holy Shield uptime (crushing blow prevention)
   - Drop Consecration before Holy Shield if mana is critical

### Holy Mana
1. **Illumination**: 60% base mana on crit heals (strongest mana tool)
2. **Divine Illumination**: 50% cost for 15s, 3 min CD — use during HL spam phases
3. **Divine Favor + HL**: Guaranteed crit = guaranteed Illumination mana return
4. **Super Mana Potion** at ~70% mana (don't wait until empty)
5. **Dark Rune** on separate CD from potions
6. **Seal of Wisdom** + melee hits for passive mana when safe to be in melee
7. **Downrank**: Lower ranks of HL/FoL cost less mana for smaller heals

---

## 8. Cooldown Management

### Ret Cooldown Priority
1. **Avenging Wrath** — use on CD (+30% dmg 20s); pair with trinkets
   - Note: causes Forbearance → no emergency DS for 1 min
2. **Trinkets** — pair with Avenging Wrath window
3. **Haste Potion** — pair with AW for burst
4. **Racial** — Arcane Torrent (Blood Elf: mana + silence) or Stoneform (Dwarf)

### Prot Cooldown Priority
1. **Holy Shield** — 100% uptime first, always (10s/10s)
2. **Avenger's Shield** — on CD for threat (30s)
3. **Avenging Wrath** — optional for threat burst; costs Forbearance
4. **Trinkets** — pair with threat needs or defensive needs
5. **Ironshield Potion** — for heavy physical damage phases

### Holy Cooldown Priority
1. **Divine Illumination** — on CD during heavy healing phases (3 min, 15s)
2. **Divine Favor + Holy Light** — guaranteed crit big heal (2 min CD)
3. **Trinkets** — pair with healing-intensive phases
4. **Lay on Hands** — emergency only (60/20 min CD)

---

## 9. Proposed Settings Schema

### Tab 1: General
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `debug_mode` | checkbox | false | Debug Mode | Enable debug output |
| `debug_system` | checkbox | false | Debug Logging | Enable detailed logging |
| `playstyle` | dropdown | "retribution" | Active Spec | Which spec rotation to use ("retribution", "protection", "holy") |
| `use_avenging_wrath` | checkbox | true | Avenging Wrath | Use Avenging Wrath on CD |
| `use_trinket1` | checkbox | true | Use Trinket 1 | Auto-use top trinket slot |
| `use_trinket2` | checkbox | true | Use Trinket 2 | Auto-use bottom trinket slot |
| `use_racial` | checkbox | true | Use Racial | Use racial ability (Arcane Torrent / Stoneform / etc.) |
| `use_hammer_of_justice` | checkbox | false | Hammer of Justice | Use HoJ as interrupt (may break CC) |
| `use_cleanse` | checkbox | true | Auto Cleanse | Auto-dispel on self |

### Tab 2: Retribution
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `ret_seal_twist` | checkbox | true | Seal Twist | Enable Command → Blood twisting (requires swing timer) |
| `ret_use_crusader_strike` | checkbox | true | Crusader Strike | Use Crusader Strike on CD (6s) |
| `ret_use_judgement` | checkbox | true | Auto Judgement | Automatically Judge off CD |
| `ret_judge_seal` | dropdown | "blood" | Judge Seal | Which seal to Judge ("blood", "crusader", "wisdom", "light") |
| `ret_use_hammer_of_wrath` | checkbox | true | Hammer of Wrath | Use HoW on targets below 20% HP |
| `ret_use_consecration` | checkbox | false | Consecration | Use Consecration (heavy mana cost) |
| `ret_use_exorcism` | checkbox | true | Exorcism | Use Exorcism on Undead/Demon targets |
| `ret_aoe_threshold` | slider | 0 | AoE Threshold | Min enemies for Consecration (0=manual only) |

### Tab 3: Protection
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `prot_use_holy_shield` | checkbox | true | Holy Shield | Maintain 100% uptime |
| `prot_prioritize_holy_shield` | checkbox | true | Prioritize Holy Shield | Cast HS before Consecration (from wowsims) |
| `prot_use_consecration` | checkbox | true | Consecration | Use on CD for threat |
| `prot_use_avengers_shield` | checkbox | true | Avenger's Shield | Use on pull (not in sustained rotation) |
| `prot_use_judgement` | checkbox | true | Auto Judgement | Judge off CD |
| `prot_seal_choice` | dropdown | "righteousness" | Seal Choice | Primary seal ("righteousness", "vengeance", "wisdom") |
| `prot_judge_cycle` | dropdown | "none" | Judgement Cycle | Cycle JoW/JoL with SoR ("none", "wisdom", "light") |
| `prot_use_exorcism` | checkbox | true | Exorcism | Use on Undead/Demon targets (mana > 40%) |
| `prot_use_hammer_of_wrath` | checkbox | true | Hammer of Wrath | Use below 20% HP |
| `prot_use_righteous_defense` | checkbox | true | Auto Taunt | Auto-taunt enemies off friendlies |

### Tab 4: Holy
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `holy_primary_heal` | dropdown | "auto" | Primary Heal | Healing mode ("auto", "holy_light", "flash_of_light") |
| `holy_use_holy_shock` | checkbox | true | Holy Shock | Use instant heal on CD |
| `holy_use_divine_favor` | checkbox | true | Divine Favor | Use guaranteed crit CD |
| `holy_use_divine_illumination` | checkbox | true | Divine Illumination | Use mana savings CD |
| `holy_judge_debuff` | dropdown | "light" | Judge Debuff | Judgement to maintain ("light", "wisdom", "none") |
| `holy_use_cleanse` | checkbox | true | Auto Cleanse | Dispel debuffs on party |
| `holy_flash_of_light_hp` | slider | 90 | FoL HP% | Use Flash of Light when target below this HP% (50-100) |
| `holy_holy_light_hp` | slider | 60 | HL HP% | Use Holy Light when target below this HP% (20-80) |
| `holy_holy_shock_hp` | slider | 50 | HS HP% | Use Holy Shock when target below this HP% (20-80) |

### Tab 5: Cooldowns & Mana
| Key | Type | Default | Label | Tooltip |
|-----|------|---------|-------|---------|
| `use_mana_potion` | checkbox | true | Mana Potion | Auto-use Super Mana Potion |
| `mana_potion_pct` | slider | 40 | Mana Pot Below% | Use Mana Potion when mana below this% (10-80) |
| `use_dark_rune` | checkbox | true | Dark Rune | Auto-use Dark/Demonic Rune |
| `dark_rune_pct` | slider | 40 | Dark Rune Below% | Use Dark Rune when mana below this% (10-80) |
| `healthstone_hp` | slider | 35 | Healthstone HP% | Use Healthstone below this HP% |
| `health_potion_hp` | slider | 25 | Health Potion HP% | Use Health Potion below this HP% |
| `divine_shield_hp` | slider | 0 | Divine Shield HP% | Use Divine Shield below this HP% (0=disable) |
| `lay_on_hands_hp` | slider | 0 | Lay on Hands HP% | Use Lay on Hands below this HP% (0=disable) |

---

## 10. Strategy Breakdown Per Playstyle

### Retribution Playstyle Strategies (priority order, from wowsims `rotation.go`)
```
[1]  AvengingWrath          — off-GCD, use on CD (+30% dmg 20s)
[2]  Trinkets               — off-GCD, pair with AW window
[3]  Racial                 — off-GCD (Arcane Torrent / Stoneform)
[4]  CompleteSealTwist      — if SoC active + in twist window → cast SoB
[5]  JudgeSealOfBlood       — off-GCD, when SoB active AND about to twist
[6]  CrusaderStrike         — 6s CD, if not about to twist; refreshes all Judgement debuffs
[7]  PrepSealTwist          — cast SoC(R1) if twist planned AND SoC inactive AND Judge won't interfere
[8]  HammerOfWrath          — target below 20% HP (filler slot)
[9]  Exorcism               — Undead/Demon only, mana > 40% (filler slot)
[10] Consecration           — if enabled, mana > 60% (filler slot, won't clip CS or twist)
[11] MaintainSealFallback   — re-seal Blood if no seal active AND not twisting (catch-all)
```
Note: Low-mana mode (≤1000 mana) drops twisting entirely — just SoB + Judge + CS.
Fillers [8-10] only fire when no twist is planned AND sufficient time before next event.

### Protection Playstyle Strategies (priority order, from wowsims `rotation.go`)
```
[1]  RighteousFuryCheck     — ensure RF buff active (toggle on)
[2]  SealJudgeCycle         — if using JoW/JoL: Judge utility seal → switch to SoR
[3]  EstablishSeal          — ensure Seal of Righteousness active (base seal)
[4]  HolyShield             — 100% uptime (if PrioritizeHolyShield); 10s/10s
[5]  Consecration           — on CD (8s) for threat
[6]  JudgeRighteousness     — Judge SoR for damage + re-seal SoR
[7]  Exorcism               — Undead/Demon only, mana > 40%
[8]  HolyShieldFallback     — if not prioritized earlier (lower slot)
[9]  AvengingWrath          — optional threat burst (off-GCD)
[10] Trinkets               — with threat needs (off-GCD)
[11] Racial                 — off-GCD (Arcane Torrent / Stoneform)
```
Note: Avenger's Shield is NOT in the wowsims sustained rotation — it's a pull-only ability.
The sim tracks next CD via: Holy Shield, Judgement, Consecration readiness only.
OOM handling: pause 5 seconds before retrying rotation.

### Holy Playstyle Strategies (priority order)
```
[1]  DivineIllumination     — off-GCD, -50% mana cost 15s (when mana below threshold)
[2]  DivineFavor            — off-GCD, guaranteed crit next heal (when emergency_count > 0)
[3]  Racial                 — off-GCD (Arcane Torrent / Stoneform)
[4]  HolyShockHeal          — instant emergency (15s CD, < HS HP% threshold)
[5]  LayOnHands             — emergency full heal on target below 15% HP (check Forbearance!)
[6]  HolyLight              — target below HL HP% threshold (heavy damage)
[7]  FlashOfLight           — target below FoL HP% threshold (moderate damage)
[8]  JudgementMaintain      — maintain JoL/JoW on boss when safe (off-GCD; blocks during emergencies)
[9]  SealMaintain           — keep Seal of Wisdom active
[10] Cleanse                — dispel debuffs on party
```
Note: DivineFavor fires when emergency_count > 0 (someone below ~40% HP), not on a simple HP threshold.
JudgementMaintain ensures the correct seal is active before judging (consumes the current seal).
LayOnHands is in-strategy (not middleware) for Holy — Holy has direct heal access to the lowest target.

### Shared Middleware (all specs)
```
[MW-500]  DivineShield        — emergency self-save at critical HP (check Forbearance!)
[MW-450]  LayOnHands          — emergency full heal (check Forbearance!)
[MW-400]  RecoveryItems       — healthstone, healing potion
[MW-300]  ManaRecovery        — mana potion, dark rune
[MW-200]  Cleanse             — dispel on self (poison/disease/magic)
[MW-150]  HammerOfJustice     — interrupt enemy cast (stun, 60s/40s CD)
[MW-100]  SelfBuffAura        — maintain configured aura OOC
[MW-90]   SelfBuffBlessing    — maintain self-blessing OOC
[MW-80]   SelfBuffSeal        — ensure a seal is active
```

---

## Key Implementation Notes

### Playstyle Detection
Paladin has NO stances/forms (unlike Druid). Playstyle must be determined by:
- **User setting** (dropdown: "retribution", "protection", "holy")
- Could auto-detect via talent check (Crusader Strike = Ret, Avenger's Shield = Prot, Holy Shock = Holy), but user setting is simpler and more reliable

### No Idle Playstyle
Like Mage, Paladin doesn't shift forms. OOC behavior (buffs, seals, auras) handled via middleware with `requires_combat = false`.
`idle_playstyle_name = nil`

### extend_context Fields
```lua
ctx.is_moving = Player:IsMoving()
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime()

-- Seal tracking (check all possible seal buff IDs)
ctx.seal_blood_active = (Unit("player"):HasBuffs(31892) or 0) > 0
                     or (Unit("player"):HasBuffs(348700) or 0) > 0  -- Martyr
ctx.seal_command_active = (Unit("player"):HasBuffs(20375) or 0) > 0
                       or (Unit("player"):HasBuffs(27170) or 0) > 0
ctx.seal_righteousness_active = (Unit("player"):HasBuffs(27155) or 0) > 0
ctx.seal_vengeance_active = (Unit("player"):HasBuffs(31801) or 0) > 0
ctx.seal_wisdom_active = (Unit("player"):HasBuffs(27166) or 0) > 0
ctx.seal_light_active = (Unit("player"):HasBuffs(27160) or 0) > 0
ctx.seal_crusader_active = (Unit("player"):HasBuffs(27158) or 0) > 0
ctx.has_any_seal = ctx.seal_blood_active or ctx.seal_command_active
    or ctx.seal_righteousness_active or ctx.seal_vengeance_active
    or ctx.seal_wisdom_active or ctx.seal_light_active
    or ctx.seal_crusader_active

-- Key buffs/debuffs
ctx.avenging_wrath_active = (Unit("player"):HasBuffs(31884) or 0) > 0
ctx.forbearance_active = (Unit("player"):HasDeBuffs(25771) or 0) > 0
ctx.righteous_fury_active = (Unit("player"):HasBuffs(25780) or 0) > 0
ctx.vengeance_stacks = Unit("player"):HasBuffsStacks(20059) or 0

-- Judgement tracking on target
ctx.jotc_on_target = (Unit("target"):HasDeBuffs(27159) or 0) > 0
ctx.jow_on_target = (Unit("target"):HasDeBuffs(27164) or 0) > 0
ctx.jol_on_target = (Unit("target"):HasDeBuffs(27163) or 0) > 0

-- enemy count for AoE decisions
ctx.enemy_count = A.MultiUnits:GetByRange(8) or 0

-- Cache invalidation flags
ctx._ret_valid = false
ctx._prot_valid = false
ctx._holy_valid = false
```

### Seal Twisting Implementation Notes (from wowsims `rotation.go`)
Seal twisting is the most complex mechanic to implement in a rotation addon.

**Core timing** (from wowsims):
1. **Swing timer**: Use `Player:GetSwing(1)` + `Player:GetSwingStart(1)` to track melee auto-attack timing
2. **Twist window**: 0.399 seconds before swing lands (`twistWindow = 399ms`)
3. **In twist window check**: `current_time >= next_swing - 0.399 AND current_time < next_swing`
4. **Will-twist condition**: `time_to_swing > spell_GCD + ability_GCD` (enough time to prep)

**State machine** (derived from wowsims event scheduling):
- BLOOD_ACTIVE → Judge SoB (off-GCD) → Cast SoC(R1) → COMMAND_ACTIVE
- COMMAND_ACTIVE → wait for twist window → Cast SoB → TWIST_PENDING
- TWIST_PENDING → swing lands (both seals proc) → BLOOD_ACTIVE → repeat

**Interaction with Crusader Strike**:
- CS fires between twists when GCD allows
- CS must NOT fire if it would miss the twist window
- wowsims checks: `SoB active OR spell_GCD < time_to_swing` before allowing CS

**Low-mana fallback** (mana ≤ 1000):
- Drop twisting entirely — just roll SoB + Judge when expiring + CS on CD
- Avoid seal drops (don't Judge if it would leave you sealless)

**Edge cases**:
- Haste effects (Bloodlust) change swing speed → shorter twist windows, more GCDs between swings
- Parry haste from boss can shift timing
- wowsims schedules pending actions at: next swing, twist window start, GCD ready, Judge ready, CS ready

**Fallback**: If user disables twisting, just maintain Seal of Blood and Judge on CD

### Judgement is Off-GCD
In TBC, Judgement (20271) does NOT trigger the GCD. This means:
- `is_gcd_gated = false` for Judgement strategies
- Can be cast between other abilities without losing DPS
- Judge immediately after CS or between seal swaps

### Forbearance Tracking
Critical to check Forbearance (25771) before attempting:
- Divine Shield (642)
- Divine Protection (5573)
- Blessing of Protection (10278)
- Lay on Hands (27154)
- Avenging Wrath (31884)

All of these apply Forbearance and are blocked by it. The middleware must check `context.forbearance_active` before showing these abilities.

### Paladin Class Color
```lua
Paladin = "f58cba"  -- Pink/rose (standard WoW class color)
```

### Faction-Specific Seal Handling
- **Horde**: Seal of Blood (31892) — primary DPS seal
- **Alliance**: Seal of the Martyr (348700, TBC Classic 2.5.1+) — SoB equivalent
- **Alliance (original TBC)**: Seal of Vengeance (31801) — stacking DoT, weaker for Ret
- Implementation must detect faction and offer the appropriate seal
- Use `UnitFactionGroup("player")` to detect Horde/Alliance

### Holy Paladin Healing Target
Unlike DPS specs which target enemies, Holy targets friendly units:
- Context needs to reference healing target (tank/mouseover/focus) not enemy target
- `spell:IsReady("target")` when target is friendly for heals
- Holy Shock can both damage (enemy target) and heal (friendly target)
- Cleanse targets friendly units

### Consecration All Ranks (for mana-efficient downranking in Prot)
| Rank | Spell ID | Mana | Notes |
|------|----------|------|-------|
| R1 | 26573 | 120 | Minimal threat, lowest mana |
| R2 | 20116 | 235 | |
| R3 | 20922 | 320 | |
| R4 | 20923 | 435 | |
| R5 | 20924 | 545 | |
| R6 | 27173 | 660 | Max rank, max threat |

### Flash of Light Rank Table (for downranking)
| Rank | Spell ID | Mana |
|------|----------|------|
| R7 | 27137 | 180 |
| R6 | 19943 | 220 |
| R5 | 19942 | 185 |
| R4 | 19941 | 155 |
| R3 | 19940 | 115 |
| R2 | 19939 | 85 |
| R1 | 19750 | 60 |

### Holy Light Rank Table (for downranking)
| Rank | Spell ID | Mana |
|------|----------|------|
| R11 | 27136 | 840 |
| R10 | 25292 | 750 |
| R9 | 10329 | 660 |
| R8 | 10328 | 580 |
| R7 | 3472 | 465 |
| R6 | 1042 | 365 |
| R5 | 1026 | 275 |
| R4 | 647 | 190 |
| R3 | 639 | 110 |
| R2 | 648 | 60 |
| R1 | 635 | 35 |
