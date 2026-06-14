# Warlock — Rotation Context

> Assumes you've read the root `AGENTS.md` (behavior) and `apps/tbc-rotation/AGENTS.md` (Strategy Registry, middleware vs strategies, context object, force-bypass, dashboard). This doc covers only Warlock specifics.

Mana class that trades HP→mana (Life Tap) and depends on a pet. Registered as `Warlock` (`version = "v1.7.0"`). No idle playstyle — `get_active_playstyle` reads `context.settings.playstyle` (default `"affliction"`).

## Playstyles

| Playstyle     | When active                                  | Core engine                                                                     |
| ------------- | -------------------------------------------- | ------------------------------------------------------------------------------- |
| `affliction`  | settings.playstyle == "affliction" (default) | DoT stacking (Corruption, UA, Siphon Life, Immolate), Curse, Shadow Bolt filler |
| `demonology`  | settings.playstyle == "demonology"           | Pet support (Felguard), Demonic Sacrifice, Soul Link, Shadow Bolt               |
| `destruction` | settings.playstyle == "destruction"          | Immolate → Conflagrate, Incinerate/Shadow Bolt nuke, Shadowburn, Backlash procs |

## Files

- `schema.lua` — settings. Tabs: `General`, `Affliction`, `Demonology`, `Destruction`, `CDs & Mana`. DoT/curse/Life Tap/pet controls.
- `class.lua` — actions, `Constants`, `register_class()`, pet/proc `extend_context`, dashboard. **No `gap_handler`.**
- `middleware.lua` — Life Tap, Death Coil, Soulshatter, Dark Pact, pet safety, self-armor, recovery.
- `affliction.lua` / `demonology.lua` / `destruction.lua` — per-playstyle strategy arrays.

## Key spell IDs / ranks

Nukes (base→max via `useMaxRank`): Shadow Bolt `686`, Incinerate `29722` (TBC), Soul Fire `6353`, Searing Pain `5676`, Shadowburn `17877`, Conflagrate `17962`, Death Coil `6789`.
DoTs/curses: Corruption `172`, Immolate `348`, Curse of Agony `980`, Curse of Doom `603`, Curse of the Elements `1490`, Curse of Recklessness `704`, Curse of Tongues `1714`, Unstable Affliction `30108` (41pt Affliction), Siphon Life `18265`, Seed of Corruption `27243`.
Drains: Drain Life `689`, Drain Soul `1120`, Drain Mana `5138`, Health Funnel `755`.
AoE: Rain of Fire `5740`, Hellfire `1949`, Shadowfury `30283` (41pt Destro).
Mana/utility: Life Tap `1454`, Dark Pact `18220`, Soulshatter `29858`, Amplify Curse `18288`.
Pet/demo: Summon Imp/Voidwalker/Succubus/Felhunter/Felguard (`688`/`697`/`712`/`691`/`30146`), Demonic Sacrifice `18788`, Soul Link `19028`, Fel Domination `18708`.
Armor: **`FelArmor` `28189` (R2) + `FelArmorR1` `28176` are separate actions** (the context checks both buff IDs); Demon Armor `706`.

## Rotation theory / priorities

- **affliction**: ShadowTrance (Nightfall instant-SB proc) → MaintainCurse → MaintainUA → MaintainCorruption → MaintainSiphonLife → MaintainImmolate → DrainSoul → AoE → Racial → **ShadowBolt (filler)** → LifeTap. The whole spec is **DoT-uptime first** — all the `Maintain*` strategies sit above the AoE/filler so DoTs are never allowed to drop. ShadowTrance fires Shadow Bolt instantly when the proc is up.
- **demonology**: FelDomResummon → SoulLink → HealthFunnel → DemonicSacrifice → MaintainCurse → MaintainCorruption → MaintainImmolate → AoE → Racial → PrimarySpell → LifeTap. Pet health/uptime (FelDomResummon, HealthFunnel, SoulLink) is gated above damage — the demon is the damage source. PrimarySpell resolves to Shadow Bolt.
- **destruction**: **Backlash (instant-cast proc) → MaintainImmolate → Conflagrate (consumes Immolate) → MaintainCurse → Shadowfury → Shadowburn → AoE → Racial → PrimarySpell → LifeTap.** Immolate must be up before Conflagrate (Conflagrate consumes the Immolate DoT). PrimarySpell is Incinerate (if known/Immolate up) or Shadow Bolt.

**Life Tap** appears both as the lowest-priority strategy in every spec (top off mana when nothing else to do) **and** as middleware (emergency mana). Tune via `context.settings`.

Middleware (priority high→low): DeathCoil (`EMERGENCY_HEAL`, escape/heal) → Healthstone/HealingPotion (RECOVERY_ITEMS) → Soulshatter (`DISPEL_CURSE`, threat drop) → DarkPact (`INNERVATE`, mana from pet) → LifeTap (`MANA_RECOVERY-15`) → ManaPotion / DarkRune → SelfBuffArmor (`SELF_BUFF_OOC+10`).

## Class-specific context extensions

`extend_context(ctx)` adds: `is_moving`, `is_mounted`, `combat_time`; **pet state** (`pet_exists`, `pet_hp`, `pet_active` — uses raw `_G.UnitExists`/`UnitIsDeadOrGhost` on `"pet"`); proc buffs (`has_shadow_trance` = Nightfall, `has_backlash`); **Demonic Sacrifice** buffs (`has_ds_shadow`, `has_ds_fire`, `has_ds_any` covering all four DS variants); `has_fel_armor` (checks R1+R2 IDs); `has_soul_link`; `soul_shards` (`GetItemCount(6265)`); `enemy_count` (`MultiUnits:GetByRangeInCombat(30)`).

Per-playstyle cache flags `_affliction_valid` / `_demo_valid` / `_destro_valid` reset to `false` each frame.

## Gotchas

- **Pet is load-bearing for demonology** — `pet_active` distinguishes "exists" from "alive & not ghost". Demo damage assumes a live demon; FelDomResummon handles a dead pet.
- **Conflagrate consumes Immolate** — order matters: MaintainImmolate must precede Conflagrate, or you waste the DoT.
- **Two Fel Armor ranks are distinct actions** (`FelArmor`/`FelArmorR1`) and both buff IDs are checked; don't collapse them.
- **Soul shard count** is read from inventory (`GetItemCount(6265)`), not a resource API.
- **Demonic Sacrifice removes the pet** for a self-buff — `has_ds_any` exists so demonology strategies don't try to use pet abilities while sacrificed.
- Settings runtime-mutable: read via `context.settings.<key>`; per-frame state tables pre-allocated (no `{}` in combat).

## See also

- Framework / registry / context: `../../AGENTS.md` (app), `../../../AGENTS.md` (root behavior)
- Deep dive (sim sources, DoT clipping, mana/Life-Tap math, AoE): `docs/WARLOCK_RESEARCH.md`
