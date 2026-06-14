# Burst & Defensive Cooldown Research (TBC Classic)

> Per-playstyle breakdown of what should fire during `/flux burst` and `/flux def`.
> Sources: Wowhead TBC Classic, Icy Veins TBC Classic, Warcraft Tavern, wowtbc.gg
>
> **Burst** = amplify output (DPS → damage, Tank → threat, Healer → healing throughput)
> **Defensive** = amplify survival (DPS/Healer → threat drop + survival stats, Tank → survival stats + healing received)
>
> Generated 2026-02-20

---

## Common Consumables Reference

| Item | ID | Effect | Duration | CD | Notes |
|---|---|---|---|---|---|
| Haste Potion | 22838 | +400 haste rating (~25% attack speed) | 15s | 2 min (potion) | Melee/ranged DPS + tanks for threat |
| Destruction Potion | 22839 | +120 spell power, +2% spell crit | 15s | 2 min (potion) | Caster DPS |
| Super Sapper Charge | 23827 | 900-1500 fire AoE, 675-1125 self-damage | Instant | 5 min | Engineering. Melee use during burst |
| Oil of Immolation | 8956 | 50 fire damage / 3s to nearby enemies | 15s | — | AoE fire aura |
| Flame Cap | 22788 | +80 fire SP, melee/ranged proc 40 fire dmg | 1 min | 3 min | Shares CD with Dark Rune |
| Thistle Tea | 7676 | +100 energy instant | — | 5 min | Rogue only |
| Ironshield Potion | 22849 | +2500 armor | 2 min | 2 min (potion) | Tank defensive |
| Nightmare Seed | 22797 | +2000 max HP | 30s | — | Tank/emergency defensive |
| Super Healing Potion | 22829 | 1500-2500 HP | Instant | 2 min (potion) | Shares CD with Haste/Destruction |
| Super Mana Potion | 22832 | 1800-3000 mana | Instant | 2 min (potion) | Shares CD with Haste/Destruction |
| Dark Rune | 20520 | 900-1500 mana, costs 600-1000 HP | Instant | 2 min | Shares CD with Flame Cap |
| Demonic Rune | 12662 | 900-1500 mana, costs 600-1000 HP | Instant | 2 min | Shares CD with Dark Rune |

**Potion CD tradeoff:** Haste Potion / Destruction Potion / Super Healing Potion / Super Mana Potion ALL share the 2-min potion cooldown. You pick one.

---

## Druid

### Cat (Melee DPS)

**burst on =**
- Tiger's Fury (5217) — +40 damage for 6s
- Trinket (offensive)
- Haste Potion (22838) — during powershift window (briefly in caster form)
- Super Sapper Charge (23827) — during powershift window
- Oil of Immolation (8956) — fire aura, usable during shift
**defensive on =**
- Barkskin (22812) — -20% damage taken 12s, usable in cat form
- Cower (27004) — threat dump, useful to avoid pulling aggro

**Notes:** Trolls cannot be Druids in TBC (Night Elf or Tauren only). Cat has almost no burst CDs. Damage is sustained via powershifting + bleed uptime. The powershift window (brief caster form) enables item use that's normally blocked in cat form.

---

### Bear (Tank — burst = threat)

**burst on =**
- Trinket (offensive / threat)
- Haste Potion (22838) — during powershift window (threat via more swings)
**defensive on =**
- Barkskin (22812) — -20% damage taken 12s, usable in bear form
- Frenzied Regeneration (22842) — converts rage to HP over 10s, 3 min CD
- Nightmare Seed (22797) — +2000 HP for 30s
- Ironshield Potion (22849) — +2500 armor for 2 min (if not armor-capped)

**Notes:** Bear has no real offensive CDs. Threat is sustained via Mangle > Lacerate > Swipe + Maul dump. Enrage (5229, +20 rage, -16% armor) is pre-pull rage gen, not burst.

---

### Balance (Caster DPS)

**burst on =**
- Force of Nature (33831) — summon 3 Treants for 30s, 3 min CD. THE Balance burst CD
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit for 15s
**defensive on =**
- Barkskin (22812) — -20% damage taken 12s

**Notes:** Balance is largely sustained Starfire spam with DoT maintenance. Align Force of Nature + Destruction Potion + trinket with Bloodlust.

---

### Caster (Idle / OOC)

**burst on =**
- *(nothing meaningful)*

**defensive on =**
- Barkskin (22812) — -20% damage taken 12s

---

### Resto (Healer — burst = amplify heals)

**burst on =**
- Nature's Swiftness (17116) — next nature spell instant, 3 min CD. Macro with max-rank Healing Touch
- Swiftmend (18562) — instant heal consuming Rejuv/Regrowth HoT, 15s CD
- Trinket (offensive / spell power)
**defensive on =**
- Barkskin (22812) — -20% damage taken 12s

**Notes:** Trolls cannot be Druids in TBC. Innervate (29166) is mana sustain, not burst. Tranquility (740) is emergency AoE heal (5 min CD, drops Tree form).

---

## Hunter

### Ranged (DPS)

**burst on =**
- Bestial Wrath (19574) — pet +50% damage, CC immune, 2 min CD (BM)
- Rapid Fire (3045) — +40% ranged attack speed 15s, 5 min CD (3 min w/ Rapid Killing)
- Kill Command (34026) — pet instant attack, 5s CD (proc-gated, requires hunter crit)
- Readiness (23989) — resets ALL hunter CDs, 5 min CD (SV) — primary use: double Rapid Fire
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Racial: Blood Fury (20572, Orc, +282 AP) or Berserking (20554, Troll)

**defensive on =**
- Feign Death (5384) — drops all threat, 30s CD
- Deterrence (19263) — +25% dodge/parry 10s, 5 min CD (SV talent)
- Misdirection (34477) — next 3 attacks redirect threat to target, 2 min CD

**Notes:** Stack ALL CDs during Bloodlust for multiplicative haste (BW + RF + Haste Potion + Blood Fury). SV's identity is double Rapid Fire via Readiness. Haste Potion shares CD with healing potions — core offensive vs defensive tradeoff.

---

## Mage

### Fire (Caster DPS)

**burst on =**
- Combustion (11129) — each fire hit adds +10% crit until 3 crits, 3 min CD. Off-GCD
- Icy Veins (12472) — +20% cast speed, pushback immune, 20s, 3 min CD
- Cold Snap (11958) — resets ALL Frost CDs (Icy Veins, Ice Block), 8 min CD
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Flame Cap (22788) — +80 fire SP 1 min (shares CD with Dark Rune)
- Racial: Berserking (26297, Troll) or Arcane Torrent (28730, Blood Elf)

**defensive on =**
- Ice Block (45438) — full immunity 10s, 5 min CD. Applies Hypothermia (30s reuse block)
- Mana Shield (1463) — absorbs damage using mana

**Notes:** Save Combustion for Molten Fury phase (<20% HP) or stack with Icy Veins on pull. Cold Snap enables a second Icy Veins window. Fire/Arcane do NOT have access to Ice Barrier.

---

### Frost (Caster DPS)

**burst on =**
- Icy Veins (12472) — +20% cast speed 20s, 3 min CD
- Water Elemental (31687) — summon elemental 45s, 3 min CD. **Summon BEFORE Bloodlust** so it gets haste
- Cold Snap (11958) — resets Frost CDs, 8 min CD. Enables double Icy Veins + double Water Ele
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Berserking (26297) or Arcane Torrent (28730)

**defensive on =**
- Ice Block (45438) — full immunity 10s
- Ice Barrier (11426) — absorb shield, 30s CD. **Frost talent only**
- Mana Shield (1463) — absorbs damage using mana

---

### Arcane (Caster DPS)

**burst on =**
- Arcane Power (12042) — +30% spell damage, +30% mana cost, 15s, 3 min CD. Off-GCD. Does NOT stack with Power Infusion
- Presence of Mind (12043) — next spell instant, 3 min CD. Off-GCD
- Icy Veins (12472) — +20% cast speed 20s, 3 min CD
- Cold Snap (11958) — resets Frost CDs, 8 min CD
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Berserking (26297) or Arcane Torrent (28730)

**defensive on =**
- Ice Block (45438) — full immunity 10s
- Mana Shield (1463) — absorbs damage using mana

**Notes:** Arcane uses burn/conserve phases. Burn = pop ALL CDs + Arcane Blast spam until ~35% mana. Conserve = AB×3 → Frostbolt filler until ~60% mana. Mana Gems (22044) share CD with Flame Cap.

---

## Paladin

### Retribution (Melee DPS)

**burst on =**
- Avenging Wrath (31884) — +30% all damage 20s, 3 min CD. **Causes Forbearance** (1 min)
- Trinket (offensive)
- Haste Potion (22838) — more swings = more SoB procs + more twist opportunities
- Racial: Arcane Torrent (28730, Blood Elf)

**defensive on =**
- Divine Shield (642/1020) — full immunity 12s. **Causes Forbearance**
- Lay on Hands (633/2800) — full heal, drains all mana, 60 min CD (20 min talented). **Causes Forbearance**

**Notes:** AW and DS/LoH all cause Forbearance — using AW blocks DS/LoH for 1 min, and vice versa. Key tradeoff. Paladins cannot be Orcs or Trolls — Blood Fury/Berserking are unusable.

---

### Protection (Tank — burst = threat)

**burst on =**
- Avenging Wrath (31884) — +30% damage/threat 20s. **Causes Forbearance**
- Trinket (offensive / threat)
- Racial: Arcane Torrent (28730, Blood Elf)

**defensive on =**
- Divine Shield (642/1020) — full immunity 12s. **Causes Forbearance**
- Lay on Hands (633/2800) — full heal. **Causes Forbearance**
- Holy Shield (20925) — +30% block chance, reactive Holy damage. Rotational, not emergency
- Ardent Defender (passive) — up to -30% damage below 35% HP

**Notes:** Ironshield Potion (22849, +2500 armor 2 min) is the standard tank potion. AW vs DS Forbearance tradeoff is critical for Prot.

---

### Holy (Healer — burst = amplify heals)

**burst on =**
- Divine Favor (20216) — next Holy Light/Flash of Light/Holy Shock guaranteed crit, 2 min CD
- Divine Illumination (31842) — -50% mana cost 15s, 3 min CD. 41pt Holy talent
- Trinket (offensive / spell power)
- Racial: Arcane Torrent (28730, Blood Elf — mana restore)

**defensive on =**
- Divine Shield (642/1020) — full immunity 12s. **Causes Forbearance**
- Lay on Hands (633/2800) — full heal. **Causes Forbearance**

**Notes:** Combine Divine Favor + Divine Illumination for guaranteed crit heal at half mana cost. Holy Shock (20473, 15s CD) is the instant emergency heal.

---

## Priest

### Shadow (Caster DPS)

**burst on =**
- Inner Focus (14751) — next spell free + 25% crit, 3 min CD. Off-GCD. Pair with Mind Blast
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Berserking (26297, Troll), Devouring Plague (25467, Undead, 3 min CD)

**defensive on =**
- Fade (25429) — temporary threat reduction, 30s CD
- Desperate Prayer (25437) — instant self-heal 1637-1924, 0 mana, 10 min CD (Human/Dwarf racial)
- Power Word: Shield (25218) — instant absorb, 15s Weakened Soul CD

**Notes:** Shadowfiend (34433, 5 min CD) is mana sustain, not burst. Use during Heroism for maximum mana return.

---

### Smite (Caster DPS)

**burst on =**
- Inner Focus (14751) — free cast + 25% crit, 3 min CD. Off-GCD
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP 15s
- Racial: Berserking (26297, Troll)

**defensive on =**
- Fade (25429) — threat reduction
- Desperate Prayer (25437) — instant self-heal (Human/Dwarf)

---

### Holy (Healer — burst = amplify heals)

**burst on =**
- Inner Focus (14751) — free cast + 25% crit, 3 min CD. Off-GCD. Pair with Greater Heal for guaranteed crit
- Trinket (offensive / spell power)
- Racial: Berserking (26297, Troll — cast speed for faster heals)

**defensive on =**
- Fade (25429) — threat reduction
- Desperate Prayer (25437) — instant self-heal (Human/Dwarf)

**Notes:** Circle of Healing (34861, 6s CD) and Prayer of Mending (33076, 10s CD) are rotational throughput, not burst CDs.

---

### Discipline (Healer — burst = amplify heals)

**burst on =**
- Power Infusion (10060) — target gets +20% haste, -20% mana cost 15s, 3 min CD. Off-GCD. Cast on self or top DPS caster
- Inner Focus (14751) — free cast + 25% crit, 3 min CD. Pair with Greater Heal
- Trinket (offensive / spell power)
- Racial: Berserking (26297, Troll)

**defensive on =**
- Pain Suppression (33206) — target takes -40% damage 8s, 2 min CD. **Only external tank DR CD in TBC**
- Fade (25429) — threat reduction
- Desperate Prayer (25437) — instant self-heal (Human/Dwarf)

---

## Rogue

### Combat (Melee DPS)

**burst on =**
- Blade Flurry (13877) — +20% attack speed, attacks hit additional target, 15s, 2 min CD. 25 energy
- Adrenaline Rush (13750) — +100% energy regen 15s, 5 min CD
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Thistle Tea (7676) — +100 energy instant, 5 min CD. Rogue only
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (20572, Orc, +282 AP) or Berserking (26297, Troll)

**defensive on =**
- Cloak of Shadows (31224) — removes harmful spells, +90% spell resist 5s, 1 min CD
- Evasion (26669) — +50% dodge 15s, 5 min CD
- Vanish (26889) — emergency stealth escape, drops all threat, 5 min CD

**Notes:** Pool to 65-85 energy before burst window to avoid wasting AR energy ticks. Stack BF + AR + Haste Potion + trinkets during Bloodlust.

---

### Assassination (Melee DPS)

**burst on =**
- Cold Blood (14177) — +100% crit on next finisher, 3 min CD. Off-GCD. Does NOT consume on miss/dodge/parry
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Thistle Tea (7676) — +100 energy instant
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (20572, Orc) or Berserking (26297, Troll)

**defensive on =**
- Cloak of Shadows (31224) — spell removal + resist
- Evasion (26669) — +50% dodge 15s
- Vanish (26889) — emergency escape

**Notes:** Always pair Cold Blood with 5 CP Envenom at max Deadly Poison stacks for guaranteed crit.

---

### Subtlety (Melee DPS)

**burst on =**
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Thistle Tea (7676) — +100 energy instant
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (20572, Orc) or Berserking (26297, Troll)

**defensive on =**
- Cloak of Shadows (31224) — spell removal + resist
- Evasion (26669) — +50% dodge 15s
- Vanish (26889) — emergency escape

**Notes:** Shadowstep (36554, 30s CD, +20% damage on next ability) and Preparation (14185, 10 min CD, resets CDs) are part of normal rotation flow, not burst-tagged. Cheat Death (31230) is passive.

---

## Shaman

### Elemental (Caster DPS)

**burst on =**
- Elemental Mastery (16166) — next damage spell: 100% crit + 0 mana, 3 min CD. 21pt Ele talent
- Fire Elemental Totem (2894) — summon Fire Elemental 2 min, 20 min CD. Benefits from ~55% of caster SP
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Blood Fury (33697, Orc — AP+SP variant, +282 AP +142 SP) or Berserking (26297, Troll)

**defensive on =**
- Nature's Swiftness (16188) + Healing Wave — instant emergency self-heal, 3 min CD (if specced into Resto)
- Earth Elemental Totem (2062) — emergency off-tank, 20 min CD. **Shares CD with Fire Elemental**
- Grounding Totem (8177) — absorbs one harmful spell, 15s CD

**Notes:** EM guarantees the first spell crits — should be Lightning Bolt (highest single-hit). The free mana is a bonus. Orc Shamans get the special Blood Fury variant (33697) that gives BOTH AP and SP.

---

### Enhancement (Melee DPS)

**burst on =**
- Shamanistic Rage (30823) — mana regen via melee (30% AP), 2 min CD. Enables sustained burst by preventing OOM
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s. More swings = more Windfury procs = exponential damage
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (33697, Orc — AP+SP variant) or Berserking (26297, Troll)

**defensive on =**
- Shamanistic Rage (30823) — -30% ALL damage taken 15s. **Dual-purpose burst/defensive**
- Nature's Swiftness (16188) + Healing Wave — instant self-heal (if specced)
- Grounding Totem (8177) — absorbs one harmful spell

**Notes:** Enhancement burst = stack haste to maximize Windfury proc chances. Shamanistic Rage is both burst (mana sustain) AND defensive (-30% DR) — fires in both contexts.

---

### Restoration (Healer — burst = amplify heals)

**burst on =**
- Nature's Swiftness (16188) — next Nature spell instant, 3 min CD. Macro with max-rank Healing Wave
- Mana Tide Totem (16190) — restores 24% total mana over 12s to group, 5 min CD
- Trinket (offensive / spell power)
- Racial: Berserking (26297, Troll — cast speed for faster heals)

**defensive on =**
- Nature's Swiftness (16188) + Healing Wave — on self
- Earth Elemental Totem (2062) — emergency off-tank
- Grounding Totem (8177) — absorbs one harmful spell

**Notes:** Earth Shield (32594, 6 charges, 41pt talent) is maintained on tank, not a burst/defensive trigger. Mana Tide is sustain that enables more throughput during intense phases.

---

## Warlock

### Affliction (Caster DPS)

**burst on =**
- Amplify Curse (18288) — +50% damage on next CoA or CoD, 3 min CD. Off-GCD. Affliction talent
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Blood Fury (33702, Orc — +143 spell damage 15s). **THE single biggest burst CD Warlocks have**

**defensive on =**
- Death Coil (6789/27223) — 526 shadow damage + 3s Horror, heals caster 100% of damage, 2 min CD
- Soulshatter (29858) — -50% threat to all enemies, 5 min CD. Costs 1 Soul Shard

**Notes:** Affliction has **zero real burst CDs**. Damage is entirely ramp-based (DoTs reaching full uptime). Shadow Trance (17941) procs are RNG. Burst is 100% external: trinkets + Destruction Potion + Blood Fury. Pre-pull Hellfire to stack Darkmoon Card: Crusade.

---

### Demonology (Caster DPS)

**burst on =**
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Racial: Blood Fury (33702, Orc — +143 spell damage)

**defensive on =**
- Death Coil (6789/27223) — damage + horror + self-heal, 2 min CD
- Soulshatter (29858) — -50% threat, 5 min CD
- Fel Domination (18708) — emergency pet resummon (-5.5s cast, -50% mana), 15 min CD. Restores Soul Link if pet died

**Notes:** Soul Link (19028, toggle, 20% damage to pet, +5% damage) is passive — not a burst/defensive trigger. Felguard does steady damage, no burst CDs. DS/Ruin build = sacrifice Succubus → Shadow Bolt spam.

---

### Destruction (Caster DPS)

**burst on =**
- Trinket (offensive)
- Destruction Potion (22839) — +120 SP, +2% crit 15s
- Flame Cap (22788) — +80 fire SP 1 min (fire build only, shares CD with Dark Rune)
- Racial: Blood Fury (33702, Orc — +143 spell damage)

**defensive on =**
- Death Coil (6789/27223) — damage + horror + self-heal, 2 min CD
- Soulshatter (29858) — -50% threat, 5 min CD

**Notes:** Shadowburn (30546, 15s CD) and Conflagrate (17962, 10s CD) are situational instants, not burst CDs. Destro's "burst" is just consistent high Shadow Bolt/Incinerate damage amplified by external items. Nether Protection (30302, Destro talent) is a passive defensive proc — cannot be triggered.

---

## Warrior

### Arms (Melee DPS)

**burst on =**
- Death Wish (12292) — +20% physical damage, fear immune, +5% damage taken, 30s, 3 min CD. 10 rage
- Recklessness (1719) — +100% crit, fear immune, +20% damage taken, 15s, 30 min CD. **Berserker Stance only**. Shares CD with Shield Wall
- Sweeping Strikes (12328) — next 10 melee attacks hit additional target, 30s CD. 30 rage. **Battle/Berserker Stance**
- Bloodrage (2687) — +10 rage instant, +10 over 10s, costs HP, 1 min CD. Does NOT put in combat (pre-pull)
- Berserker Rage (18499) — fear immune, +100% rage from damage, 30s CD. **Berserker Stance**. Triggers Enrage talent
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (20572, Orc, +282 AP) or Berserking (26296, Troll)

**defensive on =**
- Shield Wall (871) — -75% ALL damage 10-15s, 30 min CD. **Defensive Stance + shield required. Shares CD with Recklessness**
- Last Stand (12975) — +30% max HP 20s, 8 min CD. Prot talent (if cross-specced)
- Spell Reflection (23920) — reflects next spell, 10s CD. **Battle/Defensive Stance + shield**. Off-GCD

**Notes:** Sweeping Strikes + Recklessness is Arms' signature combo — guaranteed AoE crits. Death Wish and Recklessness both trigger GCD — cannot activate simultaneously. DW fires first (any stance), then Recklessness next GCD (Berserker Stance).

---

### Fury (Melee DPS)

**burst on =**
- Death Wish (12292) — +20% damage 30s, 3 min CD
- Recklessness (1719) — +100% crit 15s, 30 min CD. **Berserker Stance only**
- Bloodrage (2687) — rage gen, 1 min CD
- Berserker Rage (18499) — rage gen + fear immune, 30s CD. **Berserker Stance**
- Trinket (offensive)
- Haste Potion (22838) — +400 haste 15s
- Super Sapper Charge (23827) — AoE fire damage
- Racial: Blood Fury (20572, Orc, +282 AP) or Berserking (26296, Troll)

**defensive on =**
- Shield Wall (871) — -75% damage. **Shares CD with Recklessness** — using Reck blocks Shield Wall for 30 min
- Last Stand (12975) — +30% HP (if cross-specced into Prot)
- Spell Reflection (23920) — reflects next spell. Requires shield swap

**Notes:** Rampage (29801, 41pt Fury, +50 AP/stack up to 250 AP) is a sustained buff maintained via crits, not a burst trigger. Fury lives in Berserker Stance for Recklessness + Berserker Rage access.

---

### Protection (Tank — burst = threat)

**burst on =**
- Bloodrage (2687) — rage gen, 1 min CD. Pre-pull
- Berserker Rage (18499) — rage gen + fear immune. Stance-dance to Berserker and back
- Trinket (offensive / threat)
- Haste Potion (22838) — more swings = more Heroic Strikes = more threat
- Racial: Blood Fury (20572, Orc) or Berserking (26296, Troll)

**defensive on =**
- Shield Wall (871) — -75% ALL damage 10-15s, 30 min CD. **Defensive Stance + shield**
- Last Stand (12975) — +30% max HP 20s, 8 min CD. Prot talent
- Shield Block (2565) — +75% block chance 5-6s, 5s CD. Off-GCD. **Must maintain for crush prevention**
- Spell Reflection (23920) — reflects next spell, 10s CD. Off-GCD
- Ironshield Potion (22849) — +2500 armor 2 min
- Nightmare Seed (22797) — +2000 HP 30s

**Notes:** Recklessness and Shield Wall share the 30-min CD. Prot **NEVER** uses Recklessness — always saves for Shield Wall. Shield Block is rotational (near-100% uptime on bosses to prevent crushing blows), not just an emergency button.

---

## Shared Systems (All 9 Classes)

### Trinkets
- `trinket1_mode` / `trinket2_mode`: `"off"` | `"offensive"` | `"defensive"`
- **Offensive:** fires during `/flux burst` (before named burst entries + racial)
- **Defensive:** fires during `/flux def` (after named defensive entries)
- Centralized in `core.lua` via `try_burst_trinket` / `try_defensive_trinket`

### Racials (auto-fired after burst entries)
- Blood Fury (Orc) — AP and/or SP depending on class
- Berserking (Troll) — attack/cast speed
- Centralized in `core.lua` via `try_racial`

### Auto-Burst Conditions
Schema checkboxes control when burst fires automatically without `/flux burst`:
- `burst_in_combat` — always burst
- `burst_on_pull` — first 5s of combat
- `burst_on_execute` — target HP < 20%
- `burst_on_bloodlust` — during Bloodlust/Heroism/Drums

### Execution Order
**`/flux burst`:** Offensive trinket → Named burst entries → DPS racial
**`/flux def`:** Named defensive entries → Defensive trinket
