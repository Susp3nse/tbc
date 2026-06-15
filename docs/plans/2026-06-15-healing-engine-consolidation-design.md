# Healing Engine — Consolidation & Druid Fix (Design)

> **Type:** Design (rationale + target contract + phased migration; concrete edits sketched, not exhaustive line-edits).
> **Date:** 2026-06-15. **Risk:** Mixed — Phase 0 is a crash hotfix (low risk); Phases 1–3 change
> shared behavior for all four healers (medium risk, sim/in-game gated).
> **Scope:** the four healing specs — Druid (resto + caster self-heal), Paladin (holy), Priest
> (holy + discipline), Shaman (restoration) — and the shared scanner in `core.lua`. DPS/tank engines
> are out of scope.

---

## 0. Relationship to existing plans (what this doc does and does NOT own)

This is **the detailed design behind `role-engines-build-plan.md` Phase 3 ("Name the healing engine")**
and `role-services-design.md` §4a ("Healing service — already shipped; just name it"). Read those first
for the `NS.Roles` vision and the WHO/WHAT-vs-actor boundary; this doc does not restate them.

**Where this doc corrects them.** Both existing docs assert Phase 3 is a *"pure rename — sim/in-game
confirms no behavior change for all four healers."* **That is not true today**, and that's the reason
this doc exists:

1. **Druid is crashing, not "shadowing."** `role-services-design.md` §4a calls the per-class wrapper a
   "wart" where "others shadow `NS.scan_healing_targets`." Druid does not merely shadow it — it
   **self-recurses into a stack overflow** and **clobbers the shared scanner with an argument-ignoring
   wrapper**. This is the same bug already fixed for Priest (commit `9bfbeac`) and Paladin (`2f566a6`);
   Druid was never brought in line.
2. **Behavior is not actually uniform.** `is_tank` is computed four different ways, per-frame caching
   exists in two of four, and the roster-query helper surface differs per class. Naming the engine
   without reconciling these would freeze four behaviors under one label.

So Phase 3 is **a rename + a real bug fix + a behavior unification**, not a no-op rename. This doc owns
that reconciliation. When this ships, update `role-engines-build-plan.md` Phase 3's "pure rename / no
behavior change" wording to point here.

---

## 1. Current state (verified 2026-06-15)

All four healers build on one engine: `core.lua`'s `scan_healing_targets(context, options)`
(`core.lua:775`), which runs `scan_group` over `PARTY_UNITS`/`RAID_UNITS`, decorates each living,
in-range, assistable unit with `hp / effective_hp / deficit / incoming_dps / has_aggro / is_tank`
(via `predict_effective_deficit`), sorts ascending by `effective_hp`, and reuses a pre-allocated pool.
That core is good and stays. The **divergence is entirely in the per-class wrapper layer.**

| Concern | Paladin | Priest | Shaman | Druid |
|---|---|---|---|---|
| Has `<class>/healing.lua` | yes | yes | **no** (inlined in `restoration.lua`) | yes |
| Captures core scan before publishing | ✅ yes | ✅ yes | n/a (calls core directly) | ❌ **no → recursion** |
| Export key | `scan_paladin_healing_targets` | `scan_priest_healing_targets` | uses core directly | ❌ **clobbers `NS.scan_healing_targets`** |
| Wrapper honors `context`/`options` | n/a | n/a | ✅ passes `RESTO_SCAN_OPTIONS` | ❌ takes no args, ignores them |
| Per-frame scan cache | none | `scan_frame` guard | `_resto_valid` ctx flag | none |
| `is_tank` source | `Unit():IsTank()` | `has_aggro or role=="TANK"` | core default | `in_group and (role=="TANK" or (has_aggro and not self))` |
| Roster query helpers exposed | scanner only (callers walk roster inline) | `get_tank_target`, `count_below_hp` | local `get_lowest_target` | `get_tank_target`, `get_player_tank_target`, `get_lowest_hp_target`, `all_members_above_hp` |
| Generic downrank selector | inline in `holy.lua` | inline in `holy.lua`/`discipline.lua` | inline (3 spells) | `cast_best_heal_rank` (data-driven, reusable) |

### The Druid bug, concretely

- `druid/healing.lua:168` — the wrapper calls `NS.scan_healing_targets(nil, options)` as a **live table
  lookup**, not a captured local.
- `druid/healing.lua:361` — then publishes `NS.scan_healing_targets = scan_healing_targets` (its own wrapper).
- Load order: `healing.lua` (slot 7) loads before `resto.lua` (slot 8), so `druid/resto.lua:43`'s
  `local scan_healing_targets = NS.scan_healing_targets` captures the **druid wrapper**. At runtime the
  wrapper calls `NS.scan_healing_targets` → itself → **stack overflow on the first in-combat scan.**
- Independently, the clobber replaces the shared generic scanner with a no-arg wrapper, so any generic
  caller (recovery middleware, `get_lowest_hp_target`) silently gets druid's hard-coded options.

---

## 2. Target architecture

One named engine, thin class adapters. Same shape `role-services-design.md` §4a sketched, with the
behavioral gaps closed.

### 2a. The engine (`core.lua`, exposed as `NS.Roles.Healing`)

Owns everything that answers *"who needs healing, how urgently, and which rank covers it"* — query-only,
never casts.

```lua
NS.Roles = NS.Roles or {}
NS.Roles.Healing = {
   register   = function(adapter) ... end,   -- { range_spell, decorate, include_player? }
   targets    = function(context) ... end,    -- ranked entry pool + count (frame-cached)
   lowest     = function(context, threshold) ... end,   -- ranked #1 below threshold, or nil
   tank       = function(context) ... end,    -- first is_tank entry
   count_below= function(context, threshold) ... end,
   all_above  = function(context, threshold) ... end,
   first_needing = function(context, flag) ... end,      -- e.g. "needs_cleanse"
   select_rank = function(ranks, target, context, opts) ... end,  -- generic downranking
}
```

What moves **up** into the engine (today scattered or duplicated):

1. **One per-frame scan cache for everyone.** Lift Priest's `scan_frame`/`TMW.time` guard into the
   engine so every `targets(context)` call within a frame returns the cached pool. This deletes the
   N-scans-per-frame waste in Druid (every helper re-scans) and removes per-class cache bookkeeping
   (`_resto_valid`, `scan_frame`). Engine owns the cache key.
2. **One canonical `is_tank`.** Adopt Druid's formula — `in_group and (role=="TANK" or (has_aggro and
   not player_is_unit))` — as the engine default. It's the most correct (excludes the healer's own
   aggro, requires a real group). Paladin's `Unit():IsTank()` and Priest's redundant re-derivation
   collapse into this. (Adapters may still *override* via `decorate` if a class genuinely needs to, but
   none currently does once this is the default.)
3. **The roster-query helpers** (`lowest`/`tank`/`count_below`/`all_above`/`first_needing`) become
   engine methods, replacing the four divergent per-class sets. Callers stop walking the pool inline.
4. **The generic downranking algorithm** (`select_rank`) — Druid's `cast_best_heal_rank` is already
   fully data-driven (takes a `ranks` array + `overheal_threshold`/`prioritize_speed`/`efficiency`/
   `mana_floor` options). Promote that algorithm to the engine. **The rank tables themselves and the
   "which spell" choice stay class-side** (see §3) — only the *selection math* is shared.

### 2b. The class adapter (`<class>/healing.lua`)

Shrinks to registration + class-specific decoration + class rank tables:

```lua
-- paladin/healing.lua, after the consolidation
NS.Roles.Healing.register({
   range_spell = "Flash of Light",
   decorate    = decorate_paladin_heal_entry,   -- cleanse/healing-reduction/tank flags
})
```

No scanner wrapper, no captured-core dance, no clobber, no re-implemented roster helpers. Strategy files
call `NS.Roles.Healing.lowest(context, …)` / `.tank(context)` instead of a class-local
`scan_*_healing_targets`. **Druid's crash and clobber both disappear as a consequence** — it stops owning
a wrapper at all.

---

## 3. What explicitly stays in the class (the boundary)

Per the `role-services-design.md` §9 boundary, and confirmed against the actual code, these are *not*
pushed up — they are legitimately class knowledge:

- **`decorate_<class>_heal_entry`** — the class-specific per-unit flags the engine can't know:
  Druid `has_rejuv`/`has_regrowth`/`is_player`; Priest `has_renew`/`has_pws`/`has_weakened_soul`;
  Paladin `needs_cleanse`/`has_poison`/`has_disease`/`has_magic`/`has_healing_reduction`. The engine
  calls `decorate(entry, unit, context)`; the class fills the fields. This **is** the extension point.
- **Rank tables** — Healing Touch / Regrowth / Rejuvenation ladders, FoL vs HL, Chain Heal / HW / LHW.
  Coefficients, IDs, ranks, self-cast mirrors all stay in `class.lua`/`healing.lua`. Only the *selector*
  that walks a table is shared.
- **"Which spell, when" strategy logic** — `holy.lua`/`resto.lua`/`discipline.lua`/`restoration.lua`
  strategy arrays. Chain Heal bounce assumptions, Lifebloom-roll mechanics, Earth Shield upkeep,
  PW:S + Weakened Soul gating, seal/Judgement mana-return — all class.
- **Class HoT/shield detection helpers** (`has_any_rejuv`, `has_pws`, `has_weakened_soul`, …) — used by
  decoration and strategies; they reference class spell IDs, so they stay (but get *called by* the
  shared decorate hook, not by a class scanner wrapper).
- **Emergency thresholds & setting keys** — `resto_ns_hp_threshold`, per-spec HP cutoffs. Settings
  consolidation (`Menagerie_SECTIONS.healing`) is an open question owned by `role-services-design.md`
  §10, not this doc.

**Litmus test for "up or stays":** if the function would need a per-class hook to know spell
coefficients/ranks/IDs → it stays. If it only needs the decorated entry pool (HP, deficit, flags, tank)
→ it's engine. `cast_best_heal_rank` passes the engine test *because* the ranks come in as a parameter.

---

## 4. Migration (incremental, lowest-risk-first)

### Phase 0 — Stop the Druid crash (ship immediately, independent of the engine)
Mirror the Priest/Paladin hotfix exactly, nothing more:
- Capture `local core_scan_healing_targets = NS.scan_healing_targets` at the top of `druid/healing.lua`.
- Make the wrapper call that captured local.
- Publish as `NS.scan_druid_healing_targets`; **stop** assigning `NS.scan_healing_targets`.
- Repoint `druid/resto.lua:43` (and any `caster.lua`/helper refs) to `NS.scan_druid_healing_targets`.

**Risk: low.** It's the established fix pattern, scoped to Druid. Commit:
`fix(druid): prevent healing-scan self-recursion + stop clobbering shared scanner`. This buys time and
de-risks the engine work — after Phase 0 all four are at least *correct*, just not *uniform*.

### Phase 1 — Stand up `NS.Roles.Healing` in `core.lua`
- Add `NS.Roles = NS.Roles or {}` early (shared with the tank/DPS engines per the build plan).
- Wrap the existing `scan_healing_targets` as `NS.Roles.Healing.targets(context)` **with the per-frame
  cache built in** (lift Priest's `scan_frame` guard up). Add `lowest/tank/count_below/all_above/
  first_needing` as engine methods over the cached pool. Add the canonical `is_tank`.
- Keep the old `NS.scan_healing_targets` name as a thin alias during migration (no big-bang rename).
- **No class touched yet.** Validate the engine in isolation.

### Phase 2 — Migrate classes onto the engine, one at a time
Order: **Shaman → Priest → Paladin → Druid** (cleanest first, most-divergent last).
- Each class: replace its wrapper/inline scan with `NS.Roles.Healing.register({...})` + swap strategy
  call sites to `NS.Roles.Healing.*`. Delete the now-dead per-class scanner, frame cache, roster
  helpers, and `is_tank` derivation.
- After each class: sim (`sim:*` where supported) + in-game `/reload` smoke. One commit per class so a
  regression bisects cleanly.

### Phase 3 — Promote `select_rank`; delete duplication
- Move Druid's `cast_best_heal_rank` algorithm to `NS.Roles.Healing.select_rank`. Repoint Druid.
- Migrate Paladin/Priest/Shaman inline rank pickers to call it with their own rank tables (optional per
  class — only where it's a clean win; do not force a worse fit).

### Phase 4 — Retire the aliases
- Remove the `NS.scan_healing_targets` compatibility alias and the `scan_*_healing_targets` names once no
  consumer references them. Update the AGENTS docs and `role-engines-build-plan.md` Phase 3 wording.

---

## 5. Behavior changes this introduces (be honest — it is NOT a no-op)

- **Druid:** stops crashing; no longer clobbers the shared scanner. (Strictly a fix.)
- **`is_tank` unifies on Druid's formula.** Paladin (was `Unit():IsTank()`) and Shaman (was core
  default `has_aggro or role`) may now classify the tank slightly differently in edge cases (solo, no
  group, healer holding aggro). This is the *intended* correction, but it **must** be called out in the
  changelog and validated per spec — a healer that suddenly sees "no tank" solo is correct behavior, not
  a regression.
- **Caching:** Paladin and Druid go from re-scan-per-call to once-per-frame. Pure win, but it means a
  heal decision now uses a frame-consistent snapshot (it already did for Priest/Shaman).
- **Helper surface:** strategy files change call sites; any class relying on a subtle quirk of its old
  inline roster walk needs a look (notably Paladin/Shaman, which walked the pool by hand).

---

## 6. Risks & open questions

- **Tank-detection edge cases (medium).** The unified `is_tank` is the riskiest behavioral change.
  Mitigation: migrate per-class with sim + in-game tank-on-focus checks; keep the adapter `decorate`
  override escape hatch.
- **`select_rank` fit (low–medium).** Druid's selector has Druid-flavored options
  (`prioritize_speed`/`efficiency`). Confirm Paladin's FoL-vs-HL and Priest's Flash-vs-Greater map onto
  it cleanly before forcing them onto it; Phase 3 is explicitly *optional per class*.
- **Shaman has no `healing.lua` (open decision).** Two choices: (a) give Shaman a `healing.lua` adapter
  for symmetry with the other three, or (b) let `restoration.lua` call `NS.Roles.Healing.register`
  inline. Recommendation: **(b)** — a separate file earns its keep only when there are multiple
  healing playstyles sharing it (Priest holy+disc, Druid resto+caster). Shaman has one. Don't add a file
  for symmetry alone.
- **Load order.** The engine lives in `core.lua` (slot 4), so it's available before any class
  `healing.lua` (slot 7) registers and before strategy files (slot 8) query — no new ordering
  constraint. `role-services-design.md` §5 already assumes this.
- **Settings keys** (`Menagerie_SECTIONS.healing`) are explicitly **out of scope** — owned by
  `role-services-design.md` §10.

---

## 7. Assumptions I'm making

1. The four specs above are the complete set of group healers; no other class scans the party/raid for
   healing. (Verified: only paladin/priest/druid/shaman reference the scanner.)
2. `NS.Roles.Healing` is the agreed name (from the existing role-services design); this doc adopts it
   rather than inventing a parallel `NS.HealEngine`.
3. Phase 0 (Druid hotfix) ships first and separately — we are not blocking the crash fix on the full
   engine consolidation.
4. The core `scan_group`/`predict_effective_deficit`/sort machinery is correct and stays; only the
   wrapper/helper layer is being consolidated.

→ Correct me on any of these — especially #2 (name) and #3 (ship Phase 0 standalone) — before build.

## See also

- `2026-06-15-role-services-design.md` §4a, §9 — the engine vision + class boundary (this doc is its detail).
- `2026-06-15-role-engines-build-plan.md` Phase 3 — the build sequencing this doc fills in (and corrects).
- Prior art: commits `9bfbeac` (priest fix), `2f566a6` (paladin fix) — the Phase 0 pattern.
