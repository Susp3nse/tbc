# Cross-Class Framework De-Duplication — Design

> **Type:** Design (rationale + per-workstream direction; concrete edits sketched, not exhaustive
> line-edits).
> **Date:** 2026-06-15. **Risk:** Low per workstream except WS-1 (mixed). **Scope:** the per-class
> rotation modules under `src/aio/<class>/` plus small additive hoists in `core.lua` / `common.lua`.
> No change to the framework dispatch (`main.lua`) or the registry contract.
> **Source:** a read-only de-duplication sweep of all 9 classes against the framework's shared
> surface (the ~60 `NS.*` exports + the per-frame `context` fields). Every finding below was
> cross-checked against the actual source — symbols verified to exist, claimed duplication confirmed
> by direct read, and **two of my first-pass claims were corrected after verification** (see §0).

---

## 0. Summary & relationship to existing work

This sweep is the cross-class sibling of two efforts already in flight:

- **Phase 1–4 (this branch, uncommitted → now committed):** paladin bug fixes + the shared
  **`NS.make_threat_tab`** melee-tank factory (`core.lua`) adopted by paladin/warrior/druid-bear.
  That established the **"hoist the engine, parameterize the divergences as hooks"** pattern this doc
  reuses for healing.
- **`2026-06-15-shaman-cleanup-design.md` (WS-1):** independently found that `shaman/restoration.lua`
  re-rolls the framework's group-healing scanner with a strictly weaker copy. **WS-1 below subsumes
  that** — the shaman resto scanner is one instance of a cross-class pattern, and the unification here
  is the general fix.

**Verified CLEAN — explicitly out of scope** (stated so the coverage is auditable):

- **Immunity:** every class reads `context.target_phys/magic_immune` + `NS.ARCANE_IMMUNE` +
  `NS.is_spell_immune`. Zero per-school npcID tables anywhere. ✅
- **Interrupt primitive:** `NS.target_is_interruptible` is reused by every interrupting class. Shaman's
  seek-and-return priority-scan state machine (`shaman/middleware.lua`) and warrior's stance-dance
  (`warrior/middleware.lua:455+`) are genuine single-class complexity, **not** duplication. ✅
- **Consumables:** all 9 classes use `NS.register_consumable_actions`. ✅
- **Recovery middleware:** 8/9 use `NS.register_recovery_middleware`; druid's custom path is
  form-shift-macro driven (legit — you can't `/use` a potion mid-form). ✅
- **Per-unit re-derivation** of `CombatTime()` / `TimeToDie()` / `GetRange()` (priest/shadow, warrior,
  hunter) is always on **scanned nameplate units**, which `context` only covers for the *current*
  target — not duplication. ✅

**Two first-pass claims CORRECTED during verification** (recorded so the doc is trustworthy):

1. *"`register_trinket_middleware` has zero consumers (dead factory)."* **Wrong.** It is auto-wired by
   `register_class()` (`core.lua:1147-1148`, gated by `config.auto_trinkets ~= false`). The real issue
   is narrower (WS-2).
2. *"Priest re-exports clobber four shared `NS.*` healing keys."* The clobber is real, but the only
   one that also caused a **runtime stack overflow** was `NS.scan_healing_targets` (WS-0). The others
   were a dead export + two no-op re-exports (cleaned up in WS-0).

The work clusters into **one behavior-affecting hoist (WS-1)** and **three byte-stable cleanups
(WS-2/3/4)**. WS-0 is already done in this batch.

---

## WS-0 — Priest healing-scan self-recursion  *(DONE this batch — `fix(priest)`)*

**Bug (HIGH, latent crash).** `priest/healing.lua` defined a local `scan_healing_targets()` whose body
called `NS.scan_healing_targets(...)` **by name**, then re-exported that same local over
`NS.scan_healing_targets` at the bottom. Post-load the field pointed at the wrapper, so the wrapper
recursed into itself; the once-per-frame cache only short-circuits when `count > 0`, so the **first
in-combat heal scan** (count 0) recursed unbounded → stack overflow. Both Holy and Discipline capture
the wrapper at load, so both healing specs crashed on first heal.

This is the **identical defect Phase 1 fixed in paladin**, which priest never received.

**Fix applied (mirrors `paladin/healing.lua`):**
- Capture `local core_scan_healing_targets = NS.scan_healing_targets` before the wrapper.
- Wrapper now calls that captured reference.
- Namespaced the export → **`NS.scan_priest_healing_targets`** (never clobbers the shared scanner);
  updated `priest/holy.lua` + `priest/discipline.lua` to capture the namespaced key.
- Removed the dead `get_lowest_hp_target` (defined, exported, **never consumed**, and it clobbered
  core's shared `NS.get_lowest_hp_target`) and the two no-op `NS.is_in_raid`/`NS.is_in_party`
  re-exports (they just re-assigned core's own identical values).

Validated: luacheck 0/0, full 9-class build green.

---

## WS-1 — Healing roster-helper unification  *(FrameworkDup HIGH; behavior-affecting for shaman)*

**The headline hoist — same recipe as `NS.make_threat_tab`.** Core already ships the heavy engine:
`NS.scan_healing_targets(context, options)` (group iteration, `effective_hp` via
`predict_effective_deficit`, `decorate_entry` hook, `out` array). Every healer correctly delegates the
*scan* to it — but then each **re-implements the same roster-query helpers** on top of the scan output:

| Class | Re-rolled on top of the shared scan | Evidence |
|---|---|---|
| priest | `get_tank_target`, `count_below_hp` (+ removed dead `get_lowest_hp_target`) | `priest/healing.lua` |
| druid | `get_tank_target` (re-exported, clashes with priest's key) | `druid/healing.lua:362` |
| paladin | own `scan_paladin_healing_targets` wrapper + roster walk | `paladin/healing.lua` |
| shaman | **full re-implementation** of scanner + `get_lowest_target` insertion-sort, **weaker** (sorts raw `hp`, not `effective_hp`) | `shaman/restoration.lua:40-123` (see shaman WS-1) |

Two distinct problems:
1. **Duplicated walkers.** `get_tank_target` / `get_lowest_hp_target` / `count_below_hp` are the same
   loop over the scan's `out` array, copy-pasted per class (and `NS.get_tank_target` is exported by
   both druid and priest — they clobber each other; benign only because one class is active per
   profile).
2. **Shaman's weaker re-scan** ignores the framework's incoming-heal/absorb-aware `effective_hp`.

**Direction.** Hoist a small shared **roster-query helper set** that operates on a scan result, leaving
each class only its `decorate_entry` hook:

```
-- core.lua (additive), operating on the array core.scan already fills:
NS.heal_roster_tank(out, count)              -- first entry with is_tank
NS.heal_roster_lowest(out, count, threshold) -- first/min entry under threshold (effective_hp)
NS.heal_roster_count_below(out, count, threshold)
```

Each healer keeps its class `decorate_*_heal_entry` (legit — Weakened Soul, HoT presence, cleanse
flags differ) and drops its private walkers. Shaman additionally **switches to the shared scanner**
(adopting `effective_hp` selection — this is the one **behavior change**, and it's an improvement
already endorsed by the shaman design doc).

**Risk:** Low for druid/paladin/priest (byte-stable walker swap). **Behavior change for shaman resto**
(better target selection) — coordinate with `2026-06-15-shaman-cleanup-design.md` WS-1 so it's done
once, not twice. Validate each class build + (where available) sim.

---

## WS-2 — Trinket coverage + hunter inline duplication  *(byte-stable cleanup)*

**Corrected finding (see §0).** The shared trinket path is fully built and auto-wired:
`Menagerie_SECTIONS.trinkets()` (schema, `common.lua:71`) defines `trinket1_mode`/`trinket2_mode`;
`register_trinket_middleware` (auto-registered by `register_class`, `core.lua:1147`) fires them
(offensive on burst, defensive < 35% HP). The gap is **adoption, not absence**:

- Only **hunter** and **druid** schemas expose `trinket1_mode`/`trinket2_mode`. For the **other 7
  classes** the middleware registers but `context.settings.trinket*_mode` is nil → permanently inert.
- **Hunter double-handles:** it *also* fires offensive trinkets inline inside its burst block
  (`hunter/rotation.lua:480-484`), redundant with the auto-registered middleware.

**Direction.**
1. Add `Menagerie_SECTIONS.trinkets()` to the remaining classes' schemas so trinket control is uniform
   and the already-registered middleware becomes functional everywhere (1-line schema include each).
2. Resolve hunter's double path. **Investigate first:** the inline firing is tagged "legacy
   Hunter_Goob_opt parity" and lives inside hunter's tightly-ordered adaptive burst sequence — it may
   be intentional ordering relative to Rapid Fire / Bestial Wrath / potion. If intentional, hunter
   should pass **`auto_trinkets = false`** to `register_class` (so the generic middleware doesn't also
   fire) and keep the inline path. If not, delete the inline block and let the middleware own it.

**Risk:** Low. Pure adoption + removing one redundant firing path. No behavior change for the 7 inert
classes until a user sets a trinket mode.

---

## WS-3 — Racial firing unification  *(byte-stable cleanup; investigate first)*

`NS.create_racial_strategy` is used by 6 specs (mage/rogue/priest/paladin/shaman/warlock). **Hunter**
(`hunter/rotation.lua:467-472`, Blood Fury / Berserking) and **druid** fire racials by hand instead —
the same shape as the WS-2 hunter trinket case.

**Direction.** Same decision as WS-2: if the inline racial is intentionally sequenced inside the class
burst block, leave it and document why; otherwise fold into `create_racial_strategy` (which already
supports an `extra_match` predicate for burst-window gating). Lowest priority — confirm intent before
touching.

**Risk:** Low, but burst-ordering sensitive — verify against a sim/log before changing hunter.

---

## WS-4 — Warrior threat read via shared helper  *(cosmetic; optional)*

`warrior/class.lua:308` calls `_G.UnitThreatSituation("player","target")` directly in `extend_context`
to set `ctx.threat_status`. Core now exports `NS.get_target_threat` (the tier read, with the
mob-targets-us fallback). Warrior could reuse it for the tier; it still needs
`UnitDetailedThreatSituation` for the threat **percent** (`:311`), so this is partial consolidation,
not a full de-dup. **Optional / consistency only.**

---

## Sequencing & risk

| WS | What | Risk | Behavior change | Depends on |
|----|------|------|-----------------|------------|
| WS-0 | Priest recursion fix | — (done) | none | — |
| WS-1 | Healing roster-helper hoist | Low (×3) / Mixed (shaman) | shaman target selection only | coordinate w/ shaman WS-1 |
| WS-2 | Trinket schema coverage + hunter de-dup | Low | none (opt-in) | investigate hunter intent |
| WS-3 | Racial firing unification | Low | none if intent confirmed | investigate hunter intent |
| WS-4 | Warrior threat via `NS.get_target_threat` | Trivial | none | WS / threat factory (done) |

**Recommended order:** WS-0 (done) → WS-2 (cheapest, highest "consistency" payoff) → WS-1 (the real
hoist, jointly with shaman WS-1) → WS-3 → WS-4 (optional).

Every workstream is gated on `luacheck … --config .luacheckrc` 0/0 + a full 9-class build, plus a sim
pass where one exists (hunter especially, for WS-2/WS-3 burst ordering).
