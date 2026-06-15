# Role Services — Architecture & Philosophy

**Date:** 2026-06-15
**Status:** Draft / philosophy — not yet approved for implementation
**Scope:** A shared, class-agnostic layer that owns *who to heal / who to tank / who to hit* (role-level
situational assessment), so classes only own *what to press*. Sets the foundation for community-authored
classes and modules.

> **Note (2026-06-15):** Druid Bear has since been migrated onto the shared `make_threat_tab` factory
> (commit `c7f5d1b`) — §2's table, §4b, and §11's "migrate Bear" step describe a *pre-migration*
> snapshot. The remaining tanking work is the `tank_auto_tab` key reconciliation + naming; see
> `2026-06-15-role-engines-build-plan.md` Phase 2 for the current state.

---

## 1. The vision (in plain terms)

Today a class file is two things tangled together:

1. **Role brain** — "who is the lowest party member?", "which loose mob should I grab?", "am I about to
   pull threat?", "how many enemies are clustered for AoE?". This is *situational assessment*. It is
   **the same job** whether you're a Holy Paladin or a Resto Shaman, a Prot Warrior or a Bear Druid.
2. **Class hands** — "given that target, cast Flash of Light R7 vs Holy Light R4", "twist Seal of Blood
   into Seal of Command before the swing lands". This is *irreducibly class-specific*.

The proposal: **lift the role brain out of the class into shared Role Services.** A class then becomes
small — it declares its spells, registers its strategies, and *asks* the role service the hard
situational questions instead of re-deriving them. New classes plug in by writing a thin **adapter**, not
by re-implementing target selection. Over time, those services (and even whole classes) become shareable
units a community can author and PR.

This is the same hierarchy idea as `dashboard.lua`: it lives *above* any single class, reads the world,
and is consumed by classes — it is out of class scope in the load order.

---

## 2. Where we already are (mostly built — this doc is naming + finishing it)

**This is not greenfield.** Two of the three services already exist informally and are in production
use. The job is less "design a new layer" and more "name the pattern you've already converged on, finish
the one stragglers, and apply it to the one role that's missing (DPS)."

| Role | Shared mechanism today | Consumers | Status |
|------|------------------------|-----------|--------|
| **Healing** | `NS.scan_healing_targets` + `decorate_entry`/`range_spell` adapter | Druid, Paladin, Priest, Shaman-resto (**all 4 healers**) | **Shipped** — informal, unnamed |
| **Tanking** | `NS.make_threat_tab(opts)` + `NS.update_manual_target_tracking(st)` | Paladin Prot, Warrior Prot | **Shipped factory, 2/3 migrated** |
| **DPS targeting** | only `enemy_count` (`MultiUnits:GetByRangeInCombat`) | — | **Not started** (the real gap) |

**Healing — already the full adapter pattern, just unnamed.** `core.lua` owns the engine
(`scan_group` → `scan_healing_targets`, decorating each unit with `effective_hp` via
`predict_effective_deficit`, sorted ascending; plus `get_lowest_hp_target`, `healing_hp_asc`). Every
healing class is a thin adapter over it through `options.decorate_entry` + `options.range_spell`:
`decorate_paladin_heal_entry`, `decorate_druid_heal_entry`, `decorate_priest_heal_entry`, Shaman's
`RESTO_SCAN_OPTIONS`. The "Role Service" for healing is **functionally complete** — it lacks only a name
(`NS.Roles.Healing`) and a single documented contract. (One wart: each class re-exports its own
`scan_*_healing_targets` wrapper — Paladin uses `scan_paladin_healing_targets`, others shadow
`NS.scan_healing_targets` — so the "contract" is currently convention, not enforced.)

**Tanking — already extracted into a factory.** What I called a "smoking gun" in an earlier draft is
already fixed: the ~170-line threat brain lives in `core.lua` as `NS.make_threat_tab(opts)` (opts =
`range_spell` Action + a `state` table) with `NS.update_manual_target_tracking(st)` called from the
class context_builder. **Paladin Prot and Warrior Prot both consume it** — each is now ~6 lines
(`make_threat_tab{ range_spell = A.Judgement / A.Rend, state = prot_state }`). **The one holdout is Druid
Bear** (`bear.lua:214` `should_tab_target`), which still carries a near-identical *inline duplicate*
(its own `get_unit_priority`, `get_min_priority_from_setting`, `TAB_MAX_ATTEMPTS`, `MANUAL_TARGET_GRACE`)
and even a *different setting key* (`enable_tab_targeting` vs the factory consumers' `use_auto_tab`).
Bear is the concrete leftover to retire (§11).

**DPS targeting** is the least-built: `enemy_count` is the only shared piece; execute detection
(`execute_phase`), focus/assist, and threat suppression are either per-class or only sketched (see §8).
This is where the *new* work actually is.

**Prior art / precedent:** `docs/plans/2025-02-25-shared-middleware-design.md` (Approved) already pulled
recovery items into a factory and proposed a shared `threat.lua`. The Role Services layer is the natural
continuation of that same "shared PvE intelligence" arc — generalized from *acting* (middleware) to
*answering* (services).

---

## 3. The central reframe: three distinct kinds of shared code

The single most important design decision. We must not collapse these into one "module" concept, because
they have different shapes and different boundaries.

| Kind | Question it answers | Shape | Already exists as |
|------|---------------------|-------|-------------------|
| **Strategy** | "What do I press *right now*?" | Decides + executes a spell | `register(playstyle, [...])` |
| **Middleware** | "Should I interrupt this shared concern?" | Decides + executes, runs first | `register_middleware{...}` — recovery, dispels, interrupts |
| **Role Service** | "*Who* needs me, and *how urgently*?" | **Answers a query; does not cast** | `scan_healing_targets` (informal) |

**Role Services are query services, not actors.** The class still presses the button. This boundary is
what keeps the design from collapsing:

> **The role layer owns WHO + HOW URGENT. The class owns WHAT to cast.**

`holy.lua`'s `select_heal` (FoL vs HL by deficit/incoming-DPS, downranking within ±30% overheal,
Light's Grace / Divine Favor interactions) is the canonical example of what must **stay in the class**. If
a "healing module" tried to own spell choice it would need a hook for every class's coefficients, ranks,
and procs — it would become a god-object with a thousand callbacks. Keep the seam at the *target*, not the
*spell*.

The user's phrasing — *"the tanking system handles everything internally and just says yes or no"* — is
true for the **assessment** ("yes, you should be tanking mob X; here it is") and false for the **action**
("cast Shield Slam vs Devastate"). Split on that line.

---

## 4. The three services (concrete contracts, derived from existing code)

Two of these already exist as functions on `NS` (`scan_healing_targets`, `make_threat_tab`). The contracts
below are mostly a *naming pass* — gathering the existing helpers under `NS.Roles.<role>` so the seam is
discoverable and enforced, not invented from scratch. Whether they move to dedicated
`src/aio/roles/*.lua` files or stay in `core.lua` under an `NS.Roles` table is a packaging detail (§6); the
contract matters more than the file.

### 4a. Healing service — already shipped; just name it

This is a *rename + lock-the-contract* of what `core.lua` + the four `<class>/healing.lua` adapters already
do today. No behavior change.

```lua
-- Class side (adapter), in <class>/healing.lua:
NS.Roles.Healing.register({
   range_spell   = "Flash of Light",          -- range gate for candidacy
   decorate      = decorate_paladin_heal_entry, -- class debuff/dispel/tank flags
   -- optional: cast_time hint for effective-deficit prediction
})

-- Strategy side, in holy.lua:
local lowest = NS.Roles.Healing.lowest(context)      -- ranked #1 (effective HP)
local emergencies = NS.Roles.Healing.count_below(context, 40)
local cleanse_target = NS.Roles.Healing.first_needing(context, "cleanse")
-- class decides spell/rank from `lowest.deficit`, `lowest.incoming_dps`, etc.
```

Returns **ranked, decorated target entries** (the existing `effective_hp`-sorted pool). The class reads
fields and picks the spell. The only real cleanup: the four classes currently each re-export their own
`scan_*_healing_targets` wrapper (Paladin's is class-namespaced; others shadow `NS.scan_healing_targets`).
A single `NS.Roles.Healing.register(adapter)` + `NS.Roles.Healing.targets(context)` would replace that
convention with one enforced entry point.

### 4b. Tanking service — factory shipped, one class left to migrate

The threat brain is **already** lifted into `core.lua` as `NS.make_threat_tab(opts)` +
`NS.update_manual_target_tracking(st)` (with `get_target_threat`, `is_other_tank_target`,
`get_unit_priority`, nameplate scan, threat equalization, manual-target grace all already shared). Paladin
Prot and Warrior Prot consume it as-is:

```lua
-- Class side today (already real, in paladin/protection.lua + warrior/protection.lua):
local should_prot_tab = NS.make_threat_tab({
   range_spell = A.Judgement,   -- warrior passes A.Rend
   state       = prot_state,    -- carries tab_target_desired / _attempts / last_target_guid / manual_target_time
})
-- Strategy: matches = function(context) return should_prot_tab(context) end
```

So §4b's remaining work is **not** an extraction — it's:
1. **Migrate Druid Bear** off its inline `should_tab_target` duplicate onto `make_threat_tab` (reconciling
   the `enable_tab_targeting` vs `use_auto_tab` setting key, §10).
2. Optionally fold `make_threat_tab` under the `NS.Roles.Tanking` name for consistency, and add the
   *taunt-decision* query (`taunt_target(context)` — "who lost aggro to whom", the `RighteousDefense`/
   `Growl`/`Taunt` trigger) which is still per-class today.

### 4c. DPS-targeting service (mostly new; build last)

The thinnest today. Consolidates the scattered/sketched pieces:

- **AoE assessment** — cluster counting (already `enemy_count`), "is AoE worth it" threshold.
- **Execute** — `execute_phase` exists; promote to a uniform `is_execute(context)`.
- **Threat suppression** — the `threat.lua` design (dump vs stop vs off, scope by classification, TTD
  guard) belongs here as a *query* ("am I overthreat, should I back off?") plus the existing
  dump-middleware as the *actor*.
- **Focus/assist & target validity** — immunity-aware "is my current target worth a GCD" (already have
  `is_spell_immune`, `target_phys_immune`).

```lua
if NS.Roles.DPS.should_aoe(context) then ... end
if NS.Roles.DPS.overthreat(context) then ... end   -- class decides: dump spell vs suppress
```

> **The threat-management half of this service is specced in depth** in
> `2026-06-15-modes-and-dps-threat-brainstorm.md` (§3) — the "should I hit this target?" query, its
> `UnitDetailedThreatSituation` primitive, and how its policy is tuned by **mode** (dungeon/raid/pvp).
> That doc also introduces the **mode axis** (`context.mode`), which threads through *all three* services
> as a policy parameter — it's the natural generalization of §8's "PvP = a flag on the query."

---

## 5. The load hierarchy (where this sits)

Role services are class-agnostic and consumed by class strategy files, so they load **after `core.lua`
(which provides the scanners they build on) and before the class strategy files that call them** — the
same "above the class" position the user describes, mirroring how `dashboard.lua` sits outside class
scope.

Concretely in `builder.config.json` `loadOrder` terms (see `apps/tbc-rotation/AGENTS.md` §"Module load
order"): a new shared slot around **order 6–7**, after `core.lua`/`debug.lua`/`livepanel.lua`, alongside
or just before the class `healing.lua`/`middleware.lua` slot, so adapters can register and strategies
(slot 8+) can query. Healing service must load before class `healing.lua` adapters; class strategy files
already load after that. No change to `main.lua` dispatch — services are libraries, not a new dispatch
stage.

**Critical: services do not add a dispatch stage.** Middleware → playstyle strategies is unchanged. A role
service is a *library a strategy calls inside its `matches`/`execute`*. This avoids inventing a competing
priority hierarchy that could fight the existing one.

---

## 6. The adapter contract *is* the extension point

This is the answer to "how does it scale to people building their own classes." A new class author does
**not** touch the role services. They:

1. Declare spells/Actions + `register_class(config)` (already the contract).
2. For each role they play, register a **role adapter** — a small table of class-specific probes:
   - Healing: `range_spell`, `decorate`.
   - Tanking: `in_range`, taunt action, threat-dump action.
   - DPS: AoE spell-readiness, execute spell, threat-dump action.
3. Write strategies that *query the service* and decide spells.

A class is then genuinely small: objects + adapters + a spell-priority list. Everything hard about
*reading the situation* is borrowed. This is the "you're already set up for success, just build the
rotation" outcome the user wants — and it's enforceable: the role service defines the interface, the
adapter fills the blanks.

**Swap-ability falls out for free.** Because a service is just `NS.Roles.Healing`, a class that wants
bespoke behavior can register its *own* service implementation (or wrap the default) and call that
instead — exactly the "build a whole module just for that tank and call it instead" escape hatch. The
default is shared; overriding is one indirection, not a fork.

---

## 7. Encounter / raid scripting (the "Karazhan module" idea)

The user wants per-encounter behavior ("stop attacking on this, start on that"). **Do this as data
consumed by the services, not as a parallel middleware stack.** A bolted-on "Karazhan DPS middleware"
that races the class strategies invites priority conflicts and double-casts.

Instead: an optional **encounter table** keyed by zone/npcID that the DPS/tanking services consult while
ranking targets:

```lua
NS.Roles.Encounters["Karazhan"] = {
   [npcID_shade]   = { priority = "kill_first" },
   [npcID_addX]    = { priority = "ignore" },     -- skip in target ranking
   [npcID_curator] = { dps = "burn_on_evocation" },
}
```

The service already loops candidate units; it just biases the ranking using this table. This keeps
encounter knowledge as *content* (PR-able, frozen TBC data) and the *mechanism* shared — no new dispatch
path, no conflict surface. Treat it as **v2+**: ship the services first; encounter biasing is an additive
read on top.

---

## 8. PvP and other axes — stage it, don't build it now

The user floated PvP healing / PvP targeting as parallel roles. **Push-back:** introducing a PvP axis now
is speculative and the content is frozen TBC PvE-first. Concretely:

- Don't model "role × PvP" as a matrix of modules up front (YAGNI; combinatorial blowup).
- The clean future shape is a **mode flag** on the *query*, not a new module:
  `NS.Roles.Healing.lowest(context, { mode = "pvp" })`, where PvP swaps the *ranking heuristic*
  (focus enemy healers, line-of-sight, dispel priority) inside the same service.
- Build that only when a PvP playstyle actually ships. Note it as a designed-for extension, leave it
  unbuilt.

> **Update:** PvP is now understood as one value of a broader **mode** axis
> (`solo | dungeon | raid | pvp | leveling`) — a policy parameter on `context.mode` that all three
> services read, not a parallel module tree. See `2026-06-15-modes-and-dps-threat-brainstorm.md`. The
> push-back above still holds (don't build pvp until a pvp style ships); the mode mechanism is what makes
> it cheap when we do.

---

## 9. What explicitly stays in the class (the boundary, by example)

To keep §3 concrete — these must **not** migrate into role services:

- **Spell & rank selection.** `holy.lua` `select_heal` / `select_rank` (FoL vs HL coefficients,
  downranking, Light's Grace, Divine Favor). The service hands over the *target + deficit*; the class
  picks the spell.
- **Timing-critical class mechanics.** Ret seal-twisting, Enhancement Windfury/Fire Nova twisting,
  `SwingResync`. These are swing-timer choreography, not target selection.
- **Class resource economy.** Mana-floor gates, Seal of Wisdom swaps, energy/rage pooling.
- **Class-specific taunt/threat *actions*.** Righteous Defense vs Growl vs Taunt — the *decision* ("we
  lost aggro on mob attacking the healer") is shared; the *button* is the class's.

If a piece reads "the raid/the pack/the party and ranks units" → service. If it reads "my class's
spells/resources/procs" → class.

---

## 10. Settings & the shared-key question (an open issue to resolve)

The divergence is **already real and live**: the `make_threat_tab` consumers gate on `use_auto_tab`
(Paladin/Warrior), while Druid Bear's inline copy gates on `enable_tab_targeting` — two keys for one
behavior. So when Bear migrates (§11), we must pick one. To make the tanking service truly shared we want
**role-scoped setting keys** (e.g. `tank_tab_max_mobs`, `tank_auto_tab`) defined once in a shared schema
section (`common.lua` `Menagerie_SECTIONS` already hosts shared sections) and surfaced in each tanking
class's schema — the same shape the recovery factory already relies on (shared keys read via
`context.settings`). **Decision needed:** new shared `Menagerie_SECTIONS.tanking` / `.healing` / `.dps`
section factories, adopted as classes migrate. Until a class migrates, it keeps its own keys; no big-bang
schema change. (Watch for the user-facing rename: changing a saved setting key resets that toggle unless a
migration entry is added — see `RECOVERY_KEY_MIGRATIONS` in `core.lua` for the established pattern.)

---

## 11. Migration path (incremental, lowest-risk-first)

Do **not** do this as one sweep. The two existing services need *finishing*, not building; the new work
is DPS. Order by *value ÷ ambiguity*:

1. **Finish tanking — migrate Druid Bear** onto `NS.make_threat_tab` (retire the inline `should_tab_target`
   duplicate; reconcile `enable_tab_targeting` → shared key per §10). Smallest, highest-confidence win:
   the factory is proven on two classes, this just deletes a duplicate. Validate with sim + in-game threat
   meter. *(Then optionally add the shared `taunt_target` query.)*
2. **Name the two shipped services** — gather `scan_healing_targets` and `make_threat_tab` under
   `NS.Roles.Healing` / `NS.Roles.Tanking`, lock one adapter contract each, retire the per-class
   `scan_*_healing_targets` re-export convention. Pure rename/consolidation, no behavior change. (Optional
   but it's what makes the pattern *discoverable* for the community story in §6.)
3. **DPS-targeting service — the actual new build.** AoE/execute/threat-suppression/focus. Fold the
   `threat.lua` design in here as the query half.
4. **Encounter biasing (v2+)**, then **PvP mode flag (when a PvP style ships)**.

Each step is behavior-preserving for already-shipped classes and *unlocks* the next class. Ship and
validate one role service end-to-end before starting the next.

---

## 12. Risks & open questions

| Risk / question | Note |
|---|---|
| Service becomes a god-object | Mitigated by the WHO/WHAT boundary (§3, §9). Review every proposed service method: does it *answer* or *act*? Acting → it's middleware/strategy, not a service. |
| Hot-path cost | Scanners already run per frame and pre-allocate pools (`core_healing_targets`, `healing_targets`). Services must keep the no-`{}`-in-combat rule; reuse the existing pools, don't allocate per query. |
| Adapter contract churn | Lock the three adapter shapes before migrating the 2nd class onto each, or every class re-edits. |
| Shared setting keys (§10) | `use_auto_tab` (Paladin/Warrior) vs `enable_tab_targeting` (Bear) already diverge for one behavior — must reconcile when Bear migrates, with a `RECOVERY_KEY_MIGRATIONS`-style entry so saved toggles survive the rename. |
| Live-context aliasing | Dashboard already warns `NS.last_rotation_context` is a live alias — services returning ranked pools must document them read-only too. |
| Encounter scope creep | Keep encounters as *data biasing a ranking*, never a parallel dispatch stage (§7). |

---

## 13. Assumptions I'm making

```
1. The goal is target/situation ASSESSMENT shared across classes — not shared spell selection.
   (I'm drawing the seam at WHO, not WHAT. If you actually want spell choice centralized too,
    that's a much larger, hook-heavy design — say so and I'll rethink.)
2. "Role" ≈ existing "playstyle" for most classes (Holy=healer, Prot=tank, Ret=DPS). Role services
   are a LIBRARY playstyles consume, NOT a new dispatch axis competing with playstyle selection.
3. PvP is a future heuristic-mode on the same services, not a parallel module tree (build when needed).
4. This is a philosophy/architecture doc to align on direction — not yet an approved impl plan.
   The concrete first step (tanking-service extraction) would get its own -impl.md when greenlit.
→ Correct any of these and I'll revise before any code is written.
```

## See also

- `2026-06-15-modes-and-dps-threat-brainstorm.md` — the **mode axis** (`context.mode`) + the **DPS threat
  service** that build on this layer.
- `docs/plans/2025-02-25-shared-middleware-design.md` — the recovery/threat/interrupt precedent this extends.
- `apps/tbc-rotation/AGENTS.md` — Strategy Registry, middleware vs strategies, context object, load order.
- `core.lua` `scan_healing_targets` / `predict_effective_deficit` — the existing healing service in embryo.
- `paladin/protection.lua` `should_prot_tab` — the tanking brain to extract first.
