# Shaman — Rotation Context

> Assumes you've read the root `AGENTS.md` (behavior) and `apps/tbc-rotation/AGENTS.md` (Strategy Registry, middleware vs strategies, context object, force-bypass, dashboard). This doc covers only Shaman specifics.

Mana class with a totem system spanning all four elements. Registered as `Shaman` (`version = "v1.8.1"`). No idle playstyle — `get_active_playstyle` reads `context.settings.playstyle` (default `"elemental"`).

## Playstyles

| Playstyle     | When active                                 | Core engine                                                                                  |
| ------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `elemental`   | settings.playstyle == "elemental" (default) | Lightning Bolt filler, Chain Lightning, shock weaving, Flame Shock DoT, Fire Elemental       |
| `enhancement` | settings.playstyle == "enhancement"         | Stormstrike, shock, weapon-imbue twisting, Shamanistic Rage                                  |
| `restoration` | settings.playstyle == "restoration"         | Chain Heal / Healing Wave / Lesser Healing Wave, Earth Shield, Mana Tide, Nature's Swiftness |

## Files

- `schema.lua` — settings. Tabs: `General`, `Elemental`, `Enhancement`, `Restoration`, `CDs & Mana`. Totem/shock/heal/CD controls.
- `class.lua` — actions (huge totem roster), `Constants`, `register_class()`, totem-state tracking, `extend_context`, dashboard. **No `gap_handler`.**
- `middleware.lua` — totems, shields, weapon imbues, dispels, the single interrupt, recovery (large file — most shared behavior lives here).
- `elemental.lua` / `enhancement.lua` / `restoration.lua` — per-playstyle strategy arrays.

## Key spell IDs / ranks

Damage (base→max via `useMaxRank`): Lightning Bolt `403`→R12 `25449`, Chain Lightning `421`→`25442`, Earth Shock `25454` (R8, damage), Flame Shock `8050`→`25457`, Frost Shock `8056`→`25464`, Stormstrike `17364` (fixed).
**`EarthShockR1` = `8042`** is a deliberate separate action — R1 Earth Shock is used _interrupt-only_ to save mana (don't replace it with max-rank).
Shields: Water Shield `24398`, Lightning Shield `324`, Earth Shield `974`. Heals: Healing Wave `331`, Lesser Healing Wave `8004`, Chain Heal `1064`.
Totems (one per element slot): Searing/Magma/FireNova/TotemOfWrath/Flametongue/FireElemental (fire); StrengthOfEarth/Stoneskin/Tremor/Earthbind/EarthElemental (earth); ManaSpring/HealingStream/ManaTide (water); Windfury/GraceOfAir/WrathOfAir/Grounding/TranquilAir (air).
CDs: Elemental Mastery `16166`, Nature's Swiftness `16188`, Shamanistic Rage `30823`, Bloodlust `2825`/Heroism `32182`. `SwingResync` `6603` is a dummy action used to re-sync the auto-attack swing timer.

## Rotation theory / priorities

- **elemental**: ElementalMastery → Racial → TotemManagement → FireElemental → FlameShock → AoE → ChainLightning → EarthShock → MovementSpell → **LightningBolt (always last = primary filler)**. Flame Shock DoT is maintained before fillers; Earth Shock weaves on the shared 6s shock CD; Chain Lightning is the multi-target nuke. MovementSpell handles instant casts while moving.
- **enhancement**: **SwingResync (top — a bad swing sync preempts everything)** → ShamanisticRage → Racial → TotemManagement → **WindfuryTwist → FireNovaTotemTwist (both time-sensitive, must precede damage spells)** → AoE → Stormstrike → Shock → FireElemental. The twist strategies are the heart of enhancement: they re-imbue/re-cast on precise timing windows, so they sit above Stormstrike/Shock.
- **restoration**: NaturesSwiftness (emergency) → NSHealingWave (instant via NS proc) → EarthShieldMaintain → ManaTide → TotemManagement → Racial → ChainHeal → LesserHealingWave → HealingWave. Spell rank is chosen by HP deficit / mana efficiency (see framework healing downranking).

**Totem management** is shared across specs via `NS.make_totem_management` plus middleware — totems are tracked per element slot with remaining-time and identity flags, so the rotation only recasts when a slot is empty or expiring and avoids overwriting Tremor / Fire Elemental / twist-managed slots.

Middleware (priority high→low): Interrupt (500, `FORM_RESHIFT` — TBC's _only_ shaman interrupt, so it's top) → CurePoison (350) → CureDisease (340) → Healthstone/HealingPotion (RECOVERY_ITEMS 300/295) → ManaPotion (280) → DarkRune (275) → AutoTremor (260) → ShieldMaintain (250) → Purge (200) → WeaponImbues (`SELF_BUFF_OOC` 140).

## Class-specific context extensions

`extend_context(ctx)` adds: `is_moving`, `is_mounted`, `combat_time`, `in_group`; shield state (`has_water_shield`, `water_shield_charges`, `has_lightning_shield`); proc/buff state (`has_clearcasting` + `clearcasting_charges` via Elemental Focus, `has_elemental_mastery`, `has_natures_swiftness`, `shamanistic_rage_active`); target debuffs (`flame_shock_duration`, `stormstrike_debuff` + `stormstrike_charges`); `enemy_count` (`MultiUnits:GetByRangeInCombat(30)`).

**Totem state** (`refresh_totem_state()` once per frame) exposes per-element `totem_<fire|earth|water|air>_active` + `_remaining`. It also sets `ctx.fire_elemental_active` by reading `GetTotemInfo(1)` and matching the name — this is **protection so the rotation never overwrites a manually cast Fire Elemental** with a Searing/Magma totem.

Per-playstyle cache flags `_ele_valid` / `_enh_valid` / `_resto_valid` reset to `false` each frame.

## Gotchas

- **Shared 6s shock cooldown** — Earth/Flame/Frost Shock all share one server-side WoW cooldown; the rotation chooses which shock to recommend in that window but does not need to model a separate local shock cooldown.
- **R1 Earth Shock for interrupts** — use `A.EarthShockR1` (`8042`) for the interrupt-only path; max-rank Earth Shock wastes mana on a kick.
- **Fire totem slot is contested** — Searing/Magma/Fire Nova/Totem of Wrath/Flametongue all occupy the fire slot. The `fire_elemental_active` guard prevents clobbering a player-cast Fire Elemental.
- **Enhancement twisting is timing-critical** — WindfuryTwist / FireNovaTotemTwist depend on swing-timer alignment; `SwingResync` exists to fix a desynced swing and is intentionally the highest enhancement priority.
- Settings runtime-mutable: read via `context.settings.<key>`; per-frame state tables pre-allocated (no `{}` in combat).

## See also

- Framework / registry / context: `../../AGENTS.md` (app), `../../../AGENTS.md` (root behavior)
- Deep dive (sim sources, totem system, mana management, twisting math): `docs/SHAMAN_RESEARCH.md`
