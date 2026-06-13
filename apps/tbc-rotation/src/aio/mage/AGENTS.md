# Mage — Rotation Context

Distilled index for the Mage rotation. Assumes you've read root + `apps/tbc-rotation/AGENTS.md` (framework). Mage specifics only; depth in `docs/MAGE_RESEARCH.md`.

## Playstyles

Registered: `fire`, `frost`, `arcane`. Playstyle is chosen by **setting**, not stance or talents: `get_active_playstyle` returns `context.settings.playstyle or "fire"`. No idle playstyle. The user picks their spec in settings; the rotation does not auto-detect it.

## Files

- `class.lua` — spell Actions (damage, AoE, defensive, cooldowns, armors, self-buffs), `Constants` (BUFF_ID / DEBUFF_ID / armor + intellect buff-ID arrays), `register_class`, `extend_context`, dashboard config, gap handler (Blink).
- `middleware.lua` — defensive + sustain stack run before strategies: `Mage_IceBlock`, `Mage_ManaShield`, `Mage_IceBarrier`, `Mage_Counterspell`, `Mage_Healthstone`, `Mage_HealingPotion`, `Mage_ManaGem`, `Mage_ManaPotion`, `Mage_DarkRune`, `Mage_Evocation`, `Mage_RemoveCurse`, `Mage_SelfBuffArmor`, `Mage_SelfBuffIntellect`.
- `fire.lua` — 10 Fire strategies + `get_fire_state` context builder.
- `frost.lua` — 7 Frost strategies + `get_frost_state`.
- `arcane.lua` — 10 Arcane strategies + `get_arcane_state`.
- `schema.lua` — settings (includes the `playstyle` selector that drives spec).

## Key spell IDs / ranks

Fillers (max rank): Fireball 133, Frostbolt 116, Scorch 2948, Arcane Missiles 5143. Arcane Blast 30451 (rank-agnostic), Ice Lance 30455. Fire Blast 2136, Blast Wave 11113, Dragon's Breath 31661. AoE: Arcane Explosion 1449, Flamestrike 2120, Blizzard 10, Cone of Cold 120. Cooldowns: Combustion 11129, Icy Veins 12472, Arcane Power 12042, Presence of Mind 12043, Cold Snap 11958, Water Elemental 31687, Evocation 12051. Defensive/utility: Ice Block 45438, Ice Barrier 11426, Mana Shield 1463, Blink 1953, Counterspell 2139, Remove Curse 475. Armors: Molten 30482, Mage 6117, Ice 7302. Self-buffs: Arcane Intellect 1459, Arcane Brilliance 23028.

Tracked auras (`Constants.BUFF_ID`/`DEBUFF_ID`): Clearcasting, Icy Veins, Arcane Power, Combustion, Presence of Mind, Arcane Blast (stacking debuff), Improved Scorch, Hypothermia.

## Rotation theory / priorities

Strategy order = array position. Per-playstyle:

**Fire** (10): MaintainScorch (Improved Scorch stack upkeep) → Combustion → Icy Veins → Racial → Blast Wave → Dragon's Breath → FireBlastWeave → AoE → MovementSpell → PrimarySpell (Fireball). Core = keep Improved Scorch debuff up, weave Fire Blast, spam Fireball; instants used while moving.

**Frost** (7): Icy Veins → Water Elemental → Cold Snap (resets Frost CDs) → Racial → AoE → MovementSpell → Frostbolt. Frostbolt-spam core with pet + CD layering.

**Arcane** (10): Icy Veins → Cold Snap → Arcane Power → Presence of Mind → Racial → AoE → MovementSpell → **BurnAB → ConserveAB → Filler**. The Arcane Blast burn/conserve split is the spec's heart: `BurnAB` stacks Arcane Blast (each stack raises damage + mana cost) during burn windows, `ConserveAB` caps the stack and drops to Filler (Frostbolt/Missiles/Scorch) when mana-conserving. The AB stack count + remaining duration drive the decision (`ab_stacks`, `ab_duration`).

**Movement:** every spec has a `MovementSpell` strategy — while moving, cast an instant (Fire Blast / Ice Lance / etc.) instead of a hardcast. Gated by `ctx.is_moving`.

## Class-specific context extensions

`extend_context` adds: `is_moving`, `is_mounted`, `combat_time`, `ab_stacks` + `ab_duration` (Arcane Blast debuff stacks/duration — the Arcane economy), `hypothermia` (Ice Block lockout), `enemy_count_melee` (10yd) + `enemy_count_ranged` (40yd) for AoE thresholds, and CD-buff states: `has_clearcasting`, `icy_veins_active`, `arcane_power_active`, `combustion_active`, `pom_active`.

## Gotchas

- **Spec is a setting, not detection.** If the user's `playstyle` setting doesn't match their actual talents, required-spell validation will flag the missing spells — but the rotation won't auto-correct. This is by design.
- **Arcane Blast stack economy:** AB stacks increase both damage and mana cost; burning too long OOMs. The `ab_stacks`/`ab_duration` context fields gate BurnAB vs ConserveAB — don't bypass them.
- **Hypothermia** prevents re-casting Ice Block; `ctx.hypothermia` exists so emergency Ice Block middleware doesn't try during the lockout.
- **Two enemy-count ranges:** AoE decisions use melee (10yd) for Arcane Explosion/Cone vs ranged (40yd) for Blizzard/Flamestrike — pick the right one for the spell.
- `IcyVeins`/`ColdSnap` appear in Fire and Arcane playstyles too (cross-spec Frost talent CDs), so they're not Frost-exclusive.

## See also

- Framework / registry: `../../AGENTS.md`
- Full research (spell tables, per-spec rotations, mana management, TBC mechanic notes): `docs/MAGE_RESEARCH.md`
