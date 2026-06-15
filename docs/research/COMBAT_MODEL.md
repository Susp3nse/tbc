# WoW Combat Model — Core Mechanics & Reusable Primitives

**Date**: 2026-06-14
**Status**: Reference / design rationale (cross-cutting)
**Audience**: anyone building shared rotation code in `src/aio/`

> **Thesis:** every class is the same machine wearing a different costume. A rotation is a
> pure function — `(game state) → (one ability to cast this frame)` — and that function is
> built from a tiny set of repeating patterns. Spell names, resource bars, and class fantasy
> are *data*. The control flow is *universal*. This doc names the universal part so we can keep
> moving it into shared code instead of re-implementing it nine times.

This is the "why" behind the practical catalog in
[`docs/plans/2026-02-22-shared-code-analysis.md`](../plans/2026-02-22-shared-code-analysis.md) and
the per-role behavior in [`BURST_DEFENSIVE_RESEARCH.md`](./BURST_DEFENSIVE_RESEARCH.md). Read those
for *what* to extract; read this for the mental model that tells you *what's even shareable*.

---

## 1. The fundamental loop

Strip away everything and a WoW rotation is one loop, run every frame:

```
read current state  →  walk a priority-ordered list of "if <condition> then cast <ability>"
                     →  return the first castable entry  →  draw it on the next-action icon
```

That is *exactly* our architecture: `create_context()` (main.lua) reads the state, the
`rotation_registry` holds the priority list, and the dispatcher walks middleware → playstyle
strategies and returns the first entry whose `matches()` passes and whose `check_prerequisites()`
clears. There is no per-class loop. There is one loop and nine sets of list entries.

**The GCD is the clock.** The global cooldown (~1.5s, hasted) means you get *one real action per
tick*. So the rotation isn't "do everything that's ready" — it's "of everything that's ready, what's
the single most valuable thing." That's why the list is **priority-ordered**, not a checklist.
Off-GCD abilities (interrupts, some cooldowns, item use) are the exception: they slot in *between*
GCD actions, which is why interrupts and recovery items live in **middleware** (evaluated first,
mostly off-GCD) rather than in the playstyle list.

**Consequence for shared code:** anything that can be phrased as a `matches/execute` entry is, by
definition, a candidate for sharing. The contract *is* the universal interface. If two classes
express the same idea through that contract, the only differences are data (which spell, which
threshold) — and data-only differences belong in a factory, not a copy-paste.

---

## 2. The periodic table of spells

There are thousands of spells and roughly **ten archetypes**. Every ability a class has is one of
these wearing a costume. Learn the archetype and you've learned how to evaluate it for *every*
class, because the archetype *is* the evaluation pattern.

| # | Archetype | The question it answers | Examples across classes | Priority slot |
|---|-----------|-------------------------|--------------------------|---------------|
| 1 | **Filler / spam** | "Nothing better to do — keep the GCD busy." | Frostbolt, Steady Shot, Shadow Bolt, Lightning Bolt, autoattack-gated | Lowest |
| 2 | **Maintained debuff (DoT/debuff)** | "Is it falling off the *target*? Refresh it." | Improved Scorch, Serpent Sting, Rupture, Sunder Armor, curses, Insect Swarm | High |
| 3 | **Maintained buff (self/group)** | "Is it falling off *me/us*? Refresh it." | Slice and Dice, Battle Shout, totems, aspects, auras, Demon Armor | High |
| 4 | **Cooldown / burst** | "Window is open and it's worth it — fire it." | Trinkets, racials, Adrenaline Rush, Combustion, Bestial Wrath | Gated high |
| 5 | **Proc-reactive** | "Buff Y lit up — cast the X it enables." | Brain Freeze-likes (TBC: none), Overpower on dodge, Clearcasting spend | High when live |
| 6 | **Builder → finisher** | "Have I banked enough resource to spend?" | Combo points → Eviscerate/Rupture, Arcane Blast stacks → dump | Conditional |
| 7 | **Reactive recovery/defensive** | "Am I below a survival threshold?" | Healthstone, potions, Ice Block, Shield Wall, emergency heal | Top (interrupts list) |
| 8 | **Interrupt** | "Is the target casting something I can stop?" | Counterspell, Kick, Pummel, Earth Shock, Silencing Shot | Off-GCD, middleware |
| 9 | **AoE swap** | "Are there enough targets to switch tools?" | Arcane Explosion, Seed of Corruption, Whirlwind, Multi-Shot | Gated by count |
| 10 | **Gap / utility / movement** | "Can't act normally — situational tool." | Charge, instant-cast-while-moving, dispels, taunts | Situational |

**The payoff:** these ten archetypes correspond to ~ten reusable `matches()` shapes. Most class code
*is* archetypes 1–4 repeated with different spells. That's why the registry, `try_cast`, the
recovery/trinket/racial factories, and the debuff/buff helpers already exist — they're the
materialized form of rows 1–8.

---

## 3. Every cast decision is three questions

No matter the archetype, deciding "cast this now?" decomposes into exactly three checks, in order of
how shareable they are:

### a. Affordability — *can I pay for it?*
Resource cost vs current resource. Universal and mechanical. The resource bar differs per class but
the question is identical:

| Resource | Behavior | "Now?" pressure |
|----------|----------|------------------|
| **Mana** | Large pool, slow regen, finite over a fight | Don't go OOM; spend efficiently |
| **Rage** | Generated *by* combat (dealing/taking hits), decays out of combat | Spend it or waste it; capped at 100 |
| **Energy** | Small pool, fast steady regen, capped at 100 | Don't cap (wasted regen); pool for finishers |
| **Combo points** | Per-*target* builder currency (TBC: **lost on target swap**) | Bank to 5, then finish; don't overcap |
| **Soul shards** | Item-like inventory currency | Stockpile, consume on demand |
| **Health-as-resource** | Spend HP for power (Life Tap, Dark Rune, Hysteria) | Only when HP headroom exists |

These are already partly modeled in `create_context` (`mana`, `rage`, `energy`, `cp`, `hp`) and in
helpers like `get_spell_mana_cost` / `get_spell_rage_cost`. The *kinds* are few; the predicates
(`resource >= cost`, `resource_capped`, `hp_headroom_for_cost`) are reusable across every class that
shares a resource.

### b. Availability — *is it legal to cast right now?*
Known/trained, off cooldown, in range, target valid, not immune, correct stance/form. **100%
mechanical, 100% shareable, and already shared** via `check_prerequisites` auto-checks
(`requires_combat`, `requires_enemy`, `requires_in_range`, `spell` → `IsReady` + availability) and
the two-layer immunity model (`has_*_immunity` aura layer + `is_spell_immune` learned layer). This is
the least class-specific part of the entire system — it should *never* be hand-rolled in a class.

### c. Worth-it — *is now the right moment?*
This is the only layer with real class identity, and even it collapses into a short list of reusable
**predicates**:

- **about-to-expire** — a maintained aura within a GCD+latency of dropping (archetypes 2, 3)
- **below-stacks** — a stacking debuff under its target count (Improved Scorch ≤ 4, etc.)
- **resource-capped / -banked** — energy near 100, combo points at 5 (archetypes 1, 6)
- **proc-up** — a reactive buff is active (archetype 5)
- **execute-phase** — target below an HP% (`burst_on_execute`, Execute, hammer of wrath)
- **ttd-worth-it** — time-to-die long enough to recoup a DoT's ramp (`ttd_too_short`, `get_time_to_die`)
- **proc/window-open** — burst cooldown alignment (`should_auto_burst`)

**Design takeaway:** (a) and (b) are pure plumbing and belong entirely to shared code. (c) is "the
rotation's brain," but it's assembled from ~7 named predicates, not from bespoke per-class logic. The
class supplies the *parameters* (which spell, which window, which threshold); the predicate is shared.

---

## 4. The uptime pattern (the single most-reused thing in the game)

Archetypes 2 and 3 — maintained debuffs and buffs — are roughly **half of every rotation**. They all
run the same micro-loop:

```
if aura is missing OR (remaining ≤ refresh_window) [OR stacks < target_stacks]:
    recast it
```

A few mechanics make this subtler than it looks, and they're worth encoding once:

- **TBC has no "pandemic" window.** (Pandemic — refreshing a DoT in its last 30% rolls the
  leftover duration into the new application — is a *Mists+* mechanic. See the "mechanics that don't
  exist in TBC" section of each class research file.) In TBC, refreshing early simply **clips** the
  remainder and wastes it. So `refresh_window` is tight: "expiring within GCD + latency," not "in the
  last 30%." Encode this as a shared default, not a per-class magic number.
- **Debuffs are per-target; buffs are per-source.** A DoT tracked on target A says nothing about
  target B — hence "multi-dotting" is just the uptime pattern run across several targets (and is the
  honest definition of caster AoE; see §7). Self/group buffs are tracked once, on the caster.
- **Clip cost vs reapply cost.** Refreshing a 21-energy SnD a half-second early is cheap; clipping a
  full-duration DoT for one tick is not. The predicate is the same (`about_to_expire`); the
  *tolerance* is the per-class parameter.

We already have the substrate: `is_debuff_active`, `get_debuff_state`, `is_buff_active`. The missing
shared piece is the **decision** wrapped around them — an `about_to_expire(state, window)` /
`needs_refresh(state, window, target_stacks)` predicate that every maintained-aura strategy could call
instead of re-deriving "remaining ≤ X" inline. That's the natural next factory after recovery/racial.

---

## 5. Role changes the objective, not the machine

DPS, Tank, and Healer feel like different games. They are the *same loop with a different objective
function* — which is precisely why `is_burst` / `is_defensive` are universal flags that mean different
things per role (documented per-spec in `BURST_DEFENSIVE_RESEARCH.md`):

| Role | Objective | What "the target" is | What `is_burst` means | What `is_defensive` means |
|------|-----------|----------------------|------------------------|----------------------------|
| **DPS** | maximize damage | the enemy | more damage (CDs, trinkets) | self-preservation, reactive |
| **Tank** | threat + survival | the enemy (threat) | **threat** cooldowns | survival CDs, *proactive* |
| **Healer** | effective healing | **an ally** (lowest-HP) | throughput / amplify (e.g. healer trinket, Nature's Swiftness) | personal survival |

The only structural difference is the **healer's target selection**: the loop iterates over *allies*
and picks one (usually lowest effective HP) before choosing an ability. That's a target-scanner
problem, not a different loop — and it's exactly the duplicated `scan_healing_targets` flagged in the
shared-code analysis (four near-identical copies colliding on one `NS` key). Consolidating it is the
"healer adapter" for the same machine: replace "the target" with "the chosen ally," and archetypes
2/3/4/7 all still apply (HoTs are maintained buffs; emergency heals are reactive-defensive on someone
else's HP bar).

---

## 6. PvE vs PvP — same abilities, different weights

This trips people up: PvP is not a different rotation. It's the **same priority list re-weighted, plus
a few gating predicates.** The abilities don't change; their *order* and *guards* do.

| Axis | PvE | PvP |
|------|-----|-----|
| **Target** | predictable; bosses have long, known TTD (tank-and-spank) | players: short TTD, reactive, dodge/LoS/kite |
| **Dominant verbs** | sustained throughput, threat, multi-dot packs | **interrupt, CC, dispel, burst windows, survival** |
| **Immunity** | creature-*intrinsic* (use the **learned** layer, `is_spell_immune`) | **aura-based** (Ice Block, Divine Shield, Cloak) → `has_*_immunity` |
| **AoE** | common (packs) | rare and *dangerous* — breaks CC (see §7) |
| **Defensive trigger** | boss mechanic / DoT tick | enemy burst, incoming CC; trinket the stun |
| **Positioning** | mostly static | range/LoS/kiting is half the game |

**The reusable insight:** PvP support is mostly **adding gating predicates** to existing entries and
**reprioritizing**, not writing new strategies:

- *don't break CC* → the `has_breakable_cc_nearby` / `unit_has_breakable_cc` gate (Appendix A of the
  shared-code analysis) demotes/blocks AoE and hard-hitting single-target near a sheep.
- *target is CC/kick/stun-immune* → already answered by the immunity helpers; in PvP they fire on
  *auras* (bubble, block) rather than creature data.
- *enemy is casting* → the interrupt archetype (middleware) becomes top-priority instead of incidental.

So a "PvP mode" is largely a **weighting + a handful of guards** layered onto the same list — not a
parallel rotation. Worth stating explicitly so nobody forks a class to add PvP behavior.

---

## 7. AoE is single-target with a counter

AoE is not a separate rotation. It is the **same priority list with two extra gates**:

1. **A target-count gate.** Archetype-9 entries carry `if enemy_count < aoe_threshold then return
   false`. Above the threshold, AoE tools out-prioritize single-target fillers. That's the entire
   "AoE rotation" for most specs.
2. **A CC-safety gate.** Above the threshold *and* no breakable CC in the splash radius (Appendix A).

Two honest sub-cases:
- **"AoE" via maintained debuff = multi-dotting.** For DoT classes, "AoE" is just §4's uptime pattern
  applied to N targets. No new archetype — `enemy_count` decides how many targets are worth the
  per-target GCDs.
- **Splash radius matters.** The CC gate's range parameter must match the ability: point-blank
  (Whirlwind, Consecration, Arcane Explosion ≈ 8–10y) vs cleave/bounce (Multi-Shot, Chain Lightning,
  Seed ≈ 30y). That's data on the entry, not new control flow.

`enemy_count` already lives in `create_context`; `aoe_threshold` and the proposed `aoe_cc_check` are
the only knobs. The "AoE rotation" is a property of the *same* list, parameterized.

---

## 8. The reusable surface — theory mapped to code

Where each universal mechanic already lives (or should), so this doc stays actionable:

| Universal mechanic (this doc) | Concrete primitive | State |
|-------------------------------|--------------------|-------|
| The loop / priority list (§1) | `rotation_registry`, dispatcher in `main.lua` | ✅ shared |
| State snapshot (§1, §3) | `create_context()` in `main.lua` | ✅ shared |
| Affordability (§3a) | `get_spell_mana_cost`, `get_spell_rage_cost`, ctx resource fields | ✅ partial |
| Availability — prereqs (§3b) | `check_prerequisites` auto-checks, `spell` IsReady | ✅ shared |
| Availability — immunity (§3b, §6) | `has_*_immunity` (aura) + `is_spell_immune` (learned) | ✅ shared |
| Cast a spell + log (all) | `try_cast`, `try_cast_fmt`, `try_heal_cast*` | ✅ shared |
| Filler / archetype 1 | `create_combat_strategy` | ✅ shared |
| Maintained aura uptime (§4) | `is_debuff_active`, `get_debuff_state`, `is_buff_active` | ⚠️ substrate only — needs an `about_to_expire`/`needs_refresh` predicate |
| Cooldown / burst gating (§3c) | `should_auto_burst`, `is_force_active`, `is_burst` flag | ✅ shared |
| Recovery/defensive (archetype 7) | `register_recovery_middleware` factory | ✅ shared |
| Trinkets (archetype 4) | `register_trinket_middleware` factory | ✅ shared |
| Racial (archetype 4) | `create_racial_strategy` factory | ✅ shared |
| Interrupt (archetype 8) | proposed `NS.try_interrupt` helper | ❌ proposed (analysis §6) |
| Healer target selection (§5) | `scan_healing_targets` | ⚠️ 4 colliding copies — consolidate (analysis §4) |
| TTD / worth-it (§3c) | `get_time_to_die`, `ttd_too_short` | ✅ shared |
| AoE count gate (§7) | `ctx.enemy_count`, `aoe_threshold` setting | ✅ shared |
| AoE CC safety (§6, §7) | proposed `has_breakable_cc_nearby` | ❌ proposed (analysis Appendix A) |

Pattern: the **mechanical** rows (loop, prereqs, immunity, cast, resources) are done. The open work is
the **worth-it predicate library** (§4) and the last two archetype factories (interrupt, CC-safety).

---

## 9. Design principles for new shared code

Distilled from what's already worked here (recovery/trinket/racial factories) and what hasn't (four
copies of the healing scanner):

1. **Class identity lives in data, not control flow.** If two classes differ only in *which spell* or
   *which threshold*, that's a factory parameter. Reach for copy-paste only when the *control flow*
   genuinely differs (Shaman's interrupt state machine, Bear's form-shifting — legitimately bespoke).
2. **Factory over copy.** The proven shape: `NS.register_X_middleware(config)` /
   `NS.create_X_strategy(params)`. New shared behavior should mimic the existing factories'
   ergonomics, not invent a new convention.
3. **Build the predicate library.** The highest-leverage missing piece isn't a big system — it's a
   handful of small, composable `matches()` helpers: `about_to_expire(state, window)`,
   `below_stacks(state, n)`, `resource_capped(ctx, kind)`, `execute_phase(ctx, pct)`, `proc_up(...)`.
   These are the materialized §3c predicates and they compose into 80% of every `matches()`.
4. **The `matches/execute` contract is the boundary.** Anything expressible in it is shareable across
   classes; anything that needs to escape it is a real special case. Use that as the litmus test.
5. **One canonical owner per concept.** The `scan_healing_targets` NS-key collision is the
   anti-pattern: four classes writing to one global, last-loader-wins. Shared concepts get one
   implementation with options, not N implementations racing for a key.
6. **Don't model what the framework already knows** — e.g. the immunity model deliberately *learns*
   creature immunity instead of maintaining per-school npcID tables. Prefer self-maintaining
   mechanisms over hand-curated data (see the immunity section in `apps/tbc-rotation/CLAUDE.md`).

---

## 10. The model in one paragraph

A WoW rotation is a function from game state to a single ability, evaluated every frame by walking a
priority-ordered list of conditional casts. Every ability is one of ~ten archetypes (filler,
maintained debuff, maintained buff, cooldown, proc-reactive, builder→finisher, recovery/defensive,
interrupt, AoE, utility), and every "cast it now?" decision is three questions — *can I afford it?*,
*is it legal?*, *is now the moment?* — of which only the third holds any class identity, and even that
reduces to about seven named predicates. Roles change the objective (damage / threat / healing) and
the healer's target (an ally, not the enemy), but not the loop. PvP and AoE don't add rotations — they
add gating predicates and re-weight the same list. So most classes really *are* the same: the
shareable surface is the loop, the prerequisite/immunity/cast plumbing, and a small predicate library;
the per-class part is data (which spells, which thresholds) plugged into shared factories. Build the
factories and the predicate library, keep class files to data + genuine special cases, and nine
rotations collapse toward one engine.

---

## See also

- [`docs/plans/2026-02-22-shared-code-analysis.md`](../plans/2026-02-22-shared-code-analysis.md) —
  the concrete duplication catalog and extraction proposals (the "what to build" companion to this "why").
- [`BURST_DEFENSIVE_RESEARCH.md`](./BURST_DEFENSIVE_RESEARCH.md) — per-spec burst/defensive behavior
  (role-specific objective functions, §5).
- `docs/research/<CLASS>_RESEARCH.md` — per-class spell data, rotation priorities, and the
  "mechanics that do NOT exist in TBC" sections referenced in §4.
- `apps/tbc-rotation/CLAUDE.md` — the registry/middleware/context architecture and the two-layer
  immunity model that materialize this model in code.
