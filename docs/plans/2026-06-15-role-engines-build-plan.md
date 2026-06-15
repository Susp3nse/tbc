# Role Engines — Build Plan & Sequencing

**Date:** 2026-06-15
**Status:** Implementation plan — canonical build order for the role-engine work
**Designs this executes:** `2026-06-15-role-services-design.md` (the engines),
`2026-06-15-modes-and-dps-threat-brainstorm.md` (the mode axis)

This is the **canonical build order** for the three role engines (tank / heal / dps) and the mode axis.
The two design docs above own the *what* and *why*; this doc owns the *in what order, and how we know each
step is done*. The staging sections in both designs defer to this plan.

---

## Goal

Build **role engines** — shared, class-agnostic brains that answer "*who do I act on, and how urgently?*"
— so a class only decides "*what do I press?*". Then layer **modes** (solo/dungeon/raid/pvp/leveling) on
top as a policy parameter once the engines exist to consume it.

Two of the three engines already exist informally; the plan finishes and names them, builds the missing
one (DPS), and adds modes last.

---

## Guiding principles (the invariants every phase upholds)

1. **WHO/WHAT boundary.** Engines answer (target/situation/urgency); classes act (which spell, which
   rank, timing tech). Test for every function: *"how should a healer/tank/DPS think"* → engine;
   *"what do I press"* → class.
2. **Query-only.** A role engine **never casts.** It returns answers. The actor is a class strategy or a
   middleware. (Acting code that looks "shared" → it's middleware, not an engine.)
3. **Our engine ≠ the framework's `A.HealingEngine`.** `A.HealingEngine` is a *targeting actuator*
   (`HE.SetTarget` injects `[@unit,help]` into the macro). Our `NS.Roles.Healing` decides *which* unit;
   it sits above HE and keeps using HE to land the cast. Don't reuse the name.
4. **Read `context` live.** No capturing settings or mode at load (existing hard rule).
5. **No allocation in combat.** Reuse the existing pre-allocated pools (`core_healing_targets`,
   `prot_state`, etc.); engines must not `{}` per query.

### Definition of "engine is done" (per role)

1. Named `NS.Roles.<X>` table.  2. One documented adapter contract.  3. ≥2 classes consuming it.
4. Query-only.  5. Reads context live.

Current standing: **Healing** = 3,4,5 ✓ (needs 1,2). **Tanking** = 3,4,5 ✓ (all three melee tanks
already share `make_threat_tab`; needs 1,2 + the `tank_auto_tab` key reconciliation). **DPS** = starts at 0.

---

## Why this order (the sequencing rationale)

- **Engines before modes — it's a dependency, not a preference.** A mode is a *policy parameter on an
  engine*. With no engine, a mode has nothing to tune. Building modes first = an abstraction with zero
  consumers (speculative; would churn twice). So: build engines, let the need for situational policy
  emerge, then extract `context.mode` as the thing that removes the resulting ad-hoc group-checks.
- **DPS before the cosmetic renames.** DPS is the only *missing* engine and the highest user value (it
  prevents threat-pull wipes). Naming the two shipped engines is polish — valuable, but it must not gate
  the DPS work.
- **DPS does not wait for modes.** Its v1 threat gate needs only a binary "am I grouped?" — which already
  exists (`is_in_party` / `is_in_raid`). Modes later refine the *ceiling* (raid stricter than dungeon);
  they don't block the engine.

---

## Phases

### Phase 0 — `NS.Roles` namespace scaffold (tiny)

- Add `NS.Roles = NS.Roles or {}` early in `core.lua` (engines already live in core; this is just the
  shared table they hang off). **No file moves** — aliasing, not relocating, avoids churn.
- **Done when:** `NS.Roles` exists and the build passes. Behavior-neutral.

### Phase 1 — DPS engine v1: threat management (the real build)

The high-value slice. Query-only; the dump is separate middleware.

- **New:** `NS.Roles.DPS` with:
  - `threat_headroom(context)` → `scaledPercent` (3rd return of
    `UnitDetailedThreatSituation("player","target")`), or `nil` when ungrouped / no valid target.
  - `should_attack(context)` → `false` only when **grouped, not tanking, and headroom ≥ hard ceiling**;
    `true` otherwise (so solo is always true).
- **Gate signal (v1):** `is_in_party()` / `is_in_raid()` — **not** modes yet.
- **Settings:** `dps_threat_throttle` (toggle, default on), `dps_threat_soft` (80), `dps_threat_hard`
  (90). Add to **Paladin Ret's schema** first (one spec; we're already in that tree). Promote to a
  shared `dps` role-scoped section only when a 2nd DPS spec consumes them — mirroring the tanking
  `tank_auto_tab` rollout (don't build the shared section speculatively for one consumer).
- **Consumer:** gate only the *threat-generating filler* strategies in Ret (`retribution.lua:523`):
  wrap `Consecration`, `HolyWrath`, `Exorcism`, `HammerOfWrath` with
  `if not NS.Roles.DPS.should_attack(context) then return false end`. **Do not** gate the
  timing-/rotation-essential entries — seal-twisting (`TwistBlood`, `PrepCommand`, `MaintainBlood`,
  `MaintainSealFallback`), `JudgeSeal`, `CrusaderStrike` — throttling those breaks the twist and the
  core loop (design §9).
- **Behavior when over ceiling:** strategy yields the GCD (returns false). The actual **threat dump**
  (Feign/Soulshatter/Feint/Fade) stays the existing/planned middleware from
  `2025-02-25-shared-middleware-design.md` §2 — wire it as Phase 1b, not blocking v1.
- **Validation:** `build` passes; `lint:lua`; then **in a real 5-man with a threat meter** — confirm the
  spec holds under the tank and resumes when threat drops. **No sim path for Ret** (DPS spec, no sim
  harness) — in-game with a threat meter is the only behavioral gate.
- **Done when:** DPS engine hits all 5 DoD points for one consuming spec, and demonstrably caps threat.

### Phase 2 — Finish the tanking engine: reconcile tab keys + name it

> **The Bear migration is already done.** Commit `c7f5d1b` hoisted the shared melee-tank threat-tab
> factory; `bear.lua:203` already calls `NS.make_threat_tab{ range_spell = A.MangleBear, state =
> bear_state, ... }` with its three hooks (`tab_away_check`, `scan_unit`, `tail_hook`). **All three
> melee tanks — Bear, Paladin Prot, Warrior Prot — already share one brain.** The two design docs
> describe a *pre-migration* snapshot; that part is stale. What's left is the setting-key reconciliation
> and the name.

- **New role-scoped key `tank_auto_tab`.** Define it once in a shared schema section (`common.lua`
  `Menagerie_SECTIONS`) and surface it in each tanking class's schema. It replaces the three divergent
  keys the threat-tab consumers gate on today:
  - Druid Bear: `enable_tab_targeting` (`druid/bear.lua:591`, `druid/schema.lua:166`)
  - Paladin Prot: `use_auto_tab` (`paladin/protection.lua:148`, `paladin/schema.lua:150`)
  - Warrior Prot: `use_auto_tab` (`warrior/protection.lua:148`, `warrior/schema.lua:150`)
- **Migrations (one per class — but Warrior is special).** Ship `RECOVERY_KEY_MIGRATIONS`-style entries
  so saved toggles survive. Note the existing `migrate_recovery_keys` is **destructive** (copies old →
  new, then clears old, `core.lua:495`):
  - **Druid:** `enable_tab_targeting → tank_auto_tab` — clean rename (move + clear).
  - **Paladin:** `use_auto_tab → tank_auto_tab` — clean rename; on Paladin `use_auto_tab` only gates the
    prot threat-tab.
  - **Warrior:** `use_auto_tab → tank_auto_tab` must be a **copy, not a move.** `use_auto_tab` is
    *overloaded* on Warrior — it also gates the DPS `Warrior_AutoTab` middleware
    (`warrior/middleware.lua:1437`). Clearing it would strip the DPS auto-tab's toggle. **Extend the
    migration helper with a non-destructive (`copy = true`) variant** that seeds `tank_auto_tab` from
    `use_auto_tab` and leaves the source intact.
- **Warrior cleanup (the disentangle).** After migration, `use_auto_tab` on Warrior means exactly one
  thing — the DPS lowest-HP/execute auto-tab (`Warrior_AutoTab`, a *DPS-targeting* concern, **not**
  threat). Repoint `Prot_ThreatTab`'s `setting_key` to `tank_auto_tab` and update the `class.lua`
  framework-AutoTarget sync (`warrior/class.lua:318`, `paladin/class.lua:359`) to read the right key per
  role. `Warrior_AutoTab` stays on `use_auto_tab` and is **out of scope here** — flag it as a future
  `NS.Roles.DPS` targeting consumer (execute / target-validity, design §4c); do **not** fold it into the
  threat brain (different question — it picks the lowest-HP/executable target, not the threat spread).
- **Name the engine.** Alias `make_threat_tab` under `NS.Roles.Tanking.should_switch` (keep the old name
  as the implementation; the alias is the public face). Lock one adapter contract.
- **Validation:** all three tanks' tab behavior identical pre/post except the key rename (A/B in a 5-man
  with 2+ mobs). Specifically confirm a player's saved Warrior `use_auto_tab` **still drives the DPS
  auto-tab** after migration while `tank_auto_tab` drives prot.
- **Done when:** the three threat-tab consumers read `tank_auto_tab`; Warrior's DPS vs tank tab keys are
  disentangled; `NS.Roles.Tanking` name exists (DoD 1,2 — tanking already had 3,4,5).

### Phase 3 — Name the healing engine (rename/consolidation)

- Alias the existing scanner + adapter as `NS.Roles.Healing.register(adapter)` /
  `NS.Roles.Healing.targets(context)` / `NS.Roles.Healing.lowest(context)`.
- Retire the per-class `scan_*_healing_targets` re-export convention (Paladin's
  `scan_paladin_healing_targets`, the others shadowing `NS.scan_healing_targets`) → one registration per
  class.
- **Validation:** pure rename — sim/in-game confirms no behavior change for all four healers.
- **Done when:** healing engine hits DoD 1,2 (already has 3,4,5).

> After Phase 3 all three engines satisfy the full Definition of Done. **This is the "engines clean and in
> a good spot" checkpoint** — the gate before modes.

### Phase 4 — Modes: `context.mode` + rules engine

- Resolve once per frame in `create_context` (`main.lua`):
  `context.mode = resolve_mode(setting, IsInInstance(), group comp)` — primary signal `IsInInstance()`
  instanceType (`party`→dungeon, `raid`→raid, `arena`/`pvp`→pvp, `none`→solo/leveling by level), with
  outdoor-group / world-boss fallbacks (brainstorm doc §2).
- **Setting:** `rotation_mode` dropdown — `Auto | Solo | Dungeon | Raid | PvP | Leveling` (default Auto;
  manual always wins).
- **Dashboard/debug:** show the resolved mode (cheap, high "why is it doing that?" value).
- **Refactor Phase 1's binary gate** to read `context.mode` (solo/leveling → throttle off; dungeon/raid →
  on). Behavior-neutral if defaults match the old binary.
- **Done when:** `context.mode` is live, displayed, and the DPS engine reads it instead of raw
  `is_in_party`.

### Phase 5 — Mode-tune the engines (ongoing)

- **DPS:** raid ceiling stricter than dungeon (`dps_threat_hard` per mode).
- **Healing:** 5-man triage vs 25-man assignment heuristics.
- **Tanking:** dungeon pickup vs raid threat-equalization (partly present already).
- **PvP branch:** only when a pvp playstyle ships (heuristic = target priority, not threat).
- Each is an additive policy branch on an existing engine — never a forked implementation.

---

## The first PR (smallest shippable increment)

**Phase 0 + Phase 1 for one spec.** Concretely: `NS.Roles` table, `NS.Roles.DPS.{threat_headroom,
should_attack}`, the three `dps_threat_*` settings on Paladin Ret's schema, and Ret's filler strategies
gated on `should_attack`. Ships real value (Ret stops pulling off the tank) with a crisp validation
(threat meter in a 5-man) and zero dependency on modes or the renames.

---

## Validation gates (every phase)

- `corepack pnpm --filter @menagerie/tbc-rotation build` succeeds.
- `pnpm --filter @menagerie/tbc-rotation lint:lua` clean (catches typo'd globals/API).
- Behavior-preserving phases (2, 3): A/B the affected class in-game; sim where a path exists.
- New-behavior phases (1, 4, 5): in-game with a threat meter (DPS/tank) or party/raid (heal).

## Risks (carried from the designs)

- **Engine → god-object.** Police with the query-only invariant; acting code is middleware.
- **Mode combinatorial blowup.** Modes are threshold/heuristic *params*, never separate modules.
- **Setting-key migrations** — the three tanks → `tank_auto_tab` must ship `RECOVERY_KEY_MIGRATIONS`
  entries or players silently lose toggles. **Warrior's `use_auto_tab` is overloaded** (prot threat-tab
  *and* the DPS `Warrior_AutoTab`): its migration must **copy** into `tank_auto_tab`, not move, or the
  DPS auto-tab loses its toggle — the current helper clears the old key, so it needs a non-destructive
  variant.
- **Hot path.** Engines run per frame — reuse pre-allocated pools, no per-query allocation.
