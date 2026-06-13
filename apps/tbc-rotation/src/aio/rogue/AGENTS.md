# Rogue — Rotation Context

> Assumes you've read the root `AGENTS.md` (behavior) and `apps/tbc-rotation/AGENTS.md` (Strategy Registry, middleware vs strategies, context object, force-bypass, dashboard). This doc covers only Rogue specifics.

Energy + combo-point class. Registered as `Rogue` (`version = "v1.7.0"`). No idle playstyle — `get_active_playstyle` reads `context.settings.playstyle` (default `"combat"`).

## Playstyles

| Playstyle | When active | Core engine |
|---|---|---|
| `combat` | settings.playstyle == "combat" (default) | Sinister Strike builder, SnD/Rupture/Eviscerate finishers, Blade Flurry + Adrenaline Rush |
| `assassination` | settings.playstyle == "assassination" | Mutilate builder (dagger MH+OH), Envenom/Rupture finishers, Cold Blood |
| `subtlety` | settings.playstyle == "subtlety" | Hemorrhage builder, Shadowstep/Preparation utility, opener support |

Selection is a pure settings lookup — there is no auto-detect by stance/stealth.

## Files

- `schema.lua` — settings schema. Tabs: `General`, `Combat`, `Assassination`, `Subtlety`, `CDs & Defense`. Finisher/energy/CP thresholds live here.
- `class.lua` — action defs, `Constants` (BUFF_ID/DEBUFF_ID/ENERGY/ROGUE), `register_class()`, `extend_context`, `gap_handler`, dashboard config.
- `middleware.lua` — class-wide defensives/utility, priority-ordered (see below).
- `combat.lua` / `assassination.lua` / `subtlety.lua` — per-playstyle strategy arrays (first = highest priority).

## Key spell IDs / ranks

Builders create with base IDs + `useMaxRank` (framework resolves to TBC max rank): Sinister Strike `1752`→R10 `26862`, Backstab `53`→`26863`, Mutilate `34413` (fixed, no ranks), Hemorrhage `16511`→`26864`, Ghostly Strike `14278`, Shiv `5938`.
Finishers: Slice and Dice `5171`→buff `6774`, Eviscerate `2098`→`26865`, Rupture `1943`→debuff `26867`, Envenom `32645`, Expose Armor `8647`→`26866`, Kidney Shot `408`.
Openers: Ambush `8676`, Garrote `703`→`26884`, Cheap Shot `1833`, Premeditation `14183`.
CDs: Blade Flurry `13877`, Adrenaline Rush `13750`, Cold Blood `14177`, Preparation `14185`, Shadowstep `36554` (buff `36563`).

Watch the **buff/debuff ID ≠ cast ID** cases (in `Constants`): Sprint cast `2983` but buff `26023`; Shadowstep cast `36554` but +20% dmg buff `36563`; Deadly Poison proc/debuff `27187` (NOT application `27186`). Energy costs are in `Constants.ENERGY`.

## Rotation theory / priorities

All three specs share the same skeleton: **stealth opener → maintain Slice and Dice → cooldowns/racials → debuffs (Expose Armor, Rupture) → finisher → builder.** SnD uptime is the top DPS lever (+30% attack speed), so it sits at priority 2 in every spec, refreshed below `combat_snd_refresh` (default `SND_MIN_DURATION = 2s`).

- **combat** (priority order): StealthOpener → MaintainSnD → BladeFlurry → AdrenalineRush → Racial → ExposeArmor → Rupture → Eviscerate → ShivRefresh → SinisterStrike. Builder caps at 5 CP; finishers fire at `combat_min_cp_finisher` (default 5). Rupture is **skipped during Blade Flurry with ≥2 enemies** (Eviscerate cleaves via BF, Rupture does not).
- **assassination**: StealthOpener → MaintainSnD → ColdBlood → Racial → ExposeArmor → Rupture → Envenom → Eviscerate → ShivRefresh → Mutilate. Mutilate gives 2 CP/cast. Cold Blood is paired with the finisher for a guaranteed crit.
- **subtlety**: StealthOpener → MaintainSnD → Shadowstep → Preparation → Racial → GhostlyStrike → ExposeArmor → Rupture → Eviscerate → Hemorrhage. Hemorrhage builder also applies the physical-damage debuff.

**Energy pooling**: strategies set `state.pooling = true` when they want to fire but lack energy; downstream lower-priority strategies then short-circuit so energy accumulates for the higher-priority action instead of being spent on a builder. **ShivRefresh deliberately bypasses the pooling gate** — Deadly Poison must be refreshed (< `DP_REFRESH_THRESHOLD = 2s`) even while pooling.

Middleware (runs before strategies, priority high→low): EmergencyVanish (500) → Evasion (450) → CloakOfShadows (400) → Kick (350, interrupt) → Healthstone/HealingPotion (RECOVERY_ITEMS) → Feint (280) → ThistleTea (250) → HastePotion (200).

## Class-specific context extensions

`extend_context(ctx)` adds: `energy`, `cp` (combo points), `is_stealthed`, `is_behind` (`IsBehind(0.3)`), `combat_time`, `is_moving`, `is_mounted`, `enemy_count` (`MultiUnits:GetByRangeInCombat(10)`). It also resets per-playstyle cache flags `_combat_valid` / `_assassination_valid` / `_subtlety_valid` to `false` each frame — each playstyle's `context_builder` (e.g. `get_combat_state`) populates a pre-allocated state table and flips its flag, so the heavy buff/debuff queries run once per frame.

`gap_handler` (for `/flux gap`): Shadowstep if ready, else Sprint.

## Gotchas

- **Positional & weapon requirements aren't enforced by the rotation** — Backstab/Ambush/Garrote need *behind* (`is_behind`), and Mutilate/Backstab/Ambush need a dagger. The opener strategies gate Garrote/Ambush on `context.is_behind`, but builders rely on `IsReady` + the player's spec being correct.
- **`useMaxRank` everywhere** — never hardcode a rank ID in new code; pass the base ID and let the framework resolve.
- Per-frame state tables are **pre-allocated at module load** (`combat_state` etc.) and mutated in place — do not create `{}` inside `matches`/`execute` (secure-combat constraint).
- Settings are runtime-mutable: always read via `context.settings.<key>`, never capture at load.

## See also

- Framework / registry / context: `../../AGENTS.md` (app), `../../../AGENTS.md` (root behavior)
- Deep dive (sim sources, full rotation theory, AoE, energy math): `docs/ROGUE_RESEARCH.md`
