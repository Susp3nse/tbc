# Hunter — Rotation Context

Distilled index for the Hunter rotation. Assumes you've read root + `apps/tbc-rotation/AGENTS.md` (framework). Hunter specifics only; depth in `docs/HUNTER_RESEARCH.md`.

## Playstyles

Single registered playstyle: `ranged` (no idle playstyle). `get_active_playstyle` always returns `"ranged"`; spec (BM/MM/SV) is **not** branched on — the adaptive engine adapts to whatever stats/talents are present. All three specs run through the same shot-weaving logic.

## Files

- `class.lua` — spell/aspect/shot/trap Actions, `register_class`, `extend_context`, dashboard config.
- `middleware.lua` — `Hunter_MCBreak`, `Hunter_Healthstone`, `Hunter_HealingPotion`, `Hunter_ManaRune`, `Hunter_FeignDeath` (recovery + emergencies, run before strategies).
- `rotation.lua` — builds the `strategies` array imperatively: `Interrupt`, out-of-combat upkeep (`OOC_AspectViper`/`AspectCheetah`/`TrueshotAura`/`CallPet`/`RevivePet`), and one big `CombatRotation` strategy that delegates per-frame shot selection to the adaptive engine.
- `adaptive.lua` — **the sole ranged DPS engine.** A direct port of WoWsims' TBC adaptive rotation: scores shoot/steady/multi/arcane by expected damage each tick, picks max. `NS.HunterAdaptive.ChooseAction(unit)` → `"shoot"|"steady"|"multi"|"arcane"|"none"`.
- `cliptracker.lua` — Auto Shot clip tracker (`NS.HunterClipTracker`): measures what clipped each auto shot, how long, whether it was worth it. Drives shot timing and a diagnostic UI.
- `meleeweave.lua` — read-only traffic-light coach for manual Raptor Strike weaving (`NS.HunterMeleeWeaveCoach:Evaluate`). Coaching only; does not auto-cast melee.
- `adaptivepanel.lua` — read-only live panel showing the adaptive engine's inputs/decisions (`show_adaptive_panel`).
- `debugui.lua` — Hunter-specific diagnostic overlay.
- `schema.lua` — settings (tabs: General, Rotation, Cooldowns, PvP, Pet & Diag).

## Key spell IDs / ranks

Shots: Steady Shot 34120, Arcane Shot 3044, Multi-Shot 2643, Aimed Shot 19434, Serpent Sting 1978, Scorpid Sting 3043, Viper Sting 3034, Silencing Shot 34490, Scatter Shot 19503, Concussive 5116, Kill Command 34026, Volley 1510. Auto shoot is weapon-typed: Bow 2480, Crossbow 7919, Gun 7918, Throw 2764 (all `QueueForbidden`/`BlockForbidden`). Cooldowns: Rapid Fire 3045, Bestial Wrath 19574, Readiness 23989, Misdirection 34477 (cast on focus). Aspects: Hawk 13165, Viper 34074, Cheetah 5118, Monkey 13163, Wild 20043. Pet: Call 883, Revive 982, Mend 136, Intimidation 19577. Traps: Freezing 1499, Frost 13809, Explosive 13813, Immolation 13795. Hunter's Mark 1130, Trueshot Aura 19506, Feign Death 5384.

Dashboard tracks RF buff 3045 and The Beast Within 34471.

## Rotation theory / priorities

The **core innovation is `adaptive.lua`**, not a fixed priority list. Each tick it computes the expected damage of every shot option (subtracting DPS lost by delaying the others) and picks the max — so the math rebalances as ranged swing speed, haste procs, and talents change. There are no threshold gates or burst-mode branches in the shot selection itself. The expensive recompute (stats → avg damages → DPS rates → cast times) only fires when a tracked aura applies/refreshes/expires; per-tick cost is ~20 float ops.

Around that engine, `CombatRotation` (in `rotation.lua`) layers: pool-resource gating (don't clip Auto Shot), Tranquilizing Shot on enrage, aspect correction, Readiness (resets Rapid Fire / Misdirection), pet attack/Mend Pet, Hunter's Mark, Kill Command when off-GCD and not mid-melee-recover, and optional manual melee-weave coaching. Interrupt + out-of-combat upkeep strategies sit above it.

**Clip tracking** (`cliptracker.lua`) is the heartbeat of shot timing: Auto Shot must not be delayed ("clipped") by specials, so the engine uses swing/shoot timers (`shoot_timer`, `weapon_speed`) to decide whether a special fits before the next auto.

## Class-specific context extensions

`extend_context` adds: `weapon_speed` (`UnitRangedDamage`), `combat_time`, `is_moving`, `is_mounted`, `shoot_timer` (`Player:GetSwingShoot()` — the Auto Shot timer), and pet state: `pet_exists`, `pet_dead`, `pet_active`, `pet_hp`. Shot weaving lives or dies on `shoot_timer` + `weapon_speed`.

## Gotchas

- **Don't clip Auto Shot.** The bulk of Hunter DPS is Auto Shot; the entire adaptive/clip system exists so specials are only cast when they fit before the next auto. Changes to shot selection must respect `shoot_timer`.
- **Adaptive is a WoWsims port** — if you change shot priority logic, you're diverging from a validated simulation. Treat `adaptive.lua` as the source of truth and prefer `pnpm --filter @menagerie/tbc-rotation sim:hunter` to validate.
- **Order-7 late binding:** `adaptivepanel.lua` and others may load before `adaptive.lua` (Order 7 alphabetical sort is unstable), so they late-bind `NS.HunterAdaptive` at refresh time rather than at load.
- **Weapon-type shoot:** there are separate Bow/Crossbow/Gun/Throw auto-shoot Actions; the right one is selected by equipped ranged weapon.
- Melee weave is **coach-only** (read-only traffic light) — it does not automate Raptor Strike; the rotation only queues a manual raptor when the user opts in.

## See also

- Framework / registry: `../../AGENTS.md`
- Full research (shot-weaving ratios, per-spec rotations, AoE, TBC mechanic notes): `docs/HUNTER_RESEARCH.md`
- Adaptive engine origin: WoWsims TBC `sim/hunter/rotation.go`.
