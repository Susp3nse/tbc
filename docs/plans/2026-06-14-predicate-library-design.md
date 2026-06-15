# Predicate Library (in `core.lua`) — Design

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

**Date**: 2026-06-14
**Status**: Completed — implemented and landed
**Related**: [`docs/research/COMBAT_MODEL.md`](../research/COMBAT_MODEL.md) §3c/§4 (the "why"),
[`docs/plans/2026-02-22-shared-code-analysis.md`](./2026-02-22-shared-code-analysis.md) (the duplication catalog)

> **Placement decision (2026-06-14):** these predicates land in **`core.lua`** as flat `NS.*`
> functions, alongside the aura helpers that already live there. **No new `utils.lua` file and no
> `NS.Utils` table for now.** Pulling `core` apart into small single-purpose modules ("little cookies")
> is a deliberate *later* conversation — see §3 (Deferred restructuring). We add the logic where it
> belongs today and restructure once the reusable surface is actually settled.

---

## 1. Motivation

`COMBAT_MODEL.md` showed that every "cast this now?" decision reduces to three questions, and only the
third — *is now the moment?* — carries class identity. That third question is itself built from a tiny
set of repeating predicates (about-to-expire, below-stacks, resource-capped, execute-phase, proc-up).
Today those predicates are **inlined, by hand, in dozens of `matches()` functions**, with drifting
thresholds and subtle inconsistencies. Examples from the current tree:

```lua
-- mage/fire.lua  — maintained-debuff refresh, hand-rolled
return state.scorch_stacks < Constants.SCORCH.MAX_STACKS or state.scorch_duration < refresh

-- rogue/*.lua    — combo-point cap, repeated ~6×
if context.cp >= 5 then return false end

-- everywhere     — execute phase, magic 20 repeated
if context.target_hp < 20 then ...
```

The maintained-aura pattern alone (archetypes 2 & 3 in the combat model — DoTs, debuffs, self/group
buffs) is roughly **half of every rotation**, and each class re-implements "missing OR remaining ≤
window OR stacks < N" in its own words.

This design adds a **predicate library** plus a **maintained-aura strategy factory** to `core.lua`, so
a class expresses *which* spell and *what* threshold (data) and the shared code owns the *logic*
(control flow). It also folds in two adjacent wins the shared-code analysis already flagged: a
**reagent/count** check and **healing-scan consolidation**.

---

## 2. Goals / Non-goals

**Goals**
- A set of pure, allocation-free predicates in `core.lua` for the recurring "is now the moment?" checks.
- A `maintain_aura` strategy factory that collapses the DoT/buff-uptime duplication.
- A correct, count-aware reagent check ("don't cast if the ingredient isn't in the bag") that does
  **not** duplicate what the framework's `IsReady` already does.
- Consolidate the 3–4 colliding `scan_healing_targets` implementations into one canonical owner.

**Non-goals**
- **No new module / no `NS.Utils` table now.** Everything lands in `core.lua`, flat `NS.*` (§3).
- Not changing the registry/dispatcher, force-bypass, or `check_prerequisites` contract.
- Not renaming the existing aura helpers (`is_debuff_active`, `get_debuff_state`, `is_buff_active`) —
  they stay; new predicates are added alongside them.
- Not a per-class rotation rewrite. Migration is mechanical and incremental (§8).

---

## 3. Placement: flat `NS.*` in `core.lua` (and the deferred restructuring)

The predicates, the `maintain_aura` factory, and the reagent helpers are added to `core.lua` as flat
`NS.foo` functions — the same convention the existing aura helpers and `try_cast` already use. No new
file, no grouping table, no migration. `core.lua` already loads at order 4 (before any `class.lua`/
playstyle/`middleware.lua`), and already owns the aura-reading foundation these build on, so it is the
correct home today.

**Why not `utils.lua` / `NS.Utils` (for now):**
- A new grouping table *inside* `core` would clash with core's own flat style and give the new
  convention without the file-separation benefit — a half-measure.
- The right time to introduce grouping is when we actually split files, not before.

### Deferred restructuring ("little cookies")

`core.lua` is already large and will grow with this work. That is **accepted, temporarily.** Once the
reusable surface is settled (predicates + factory + reagent + healing + the upcoming interrupt and
AoE-CC helpers all proven and stable), there is a planned follow-up to **break `core.lua` into small,
single-purpose modules** — e.g. a predicates module, an auras module, a healing module, an immunity
module — each cohesive and independently readable. At that point grouping/namespacing (whether
`NS.Utils.*`, per-module tables, or staying flat) is decided *with the file boundaries*, not ahead of
them. This doc deliberately does **not** pre-commit that structure; it only notes the predicate library
and healing scanner are the prime first candidates to extract, because they are the most self-contained.

---

## 4. Load order & constraints

- **Home**: `core.lua` (load order **4**). No build-config change — it already loads before all class
  files, and the aura helpers it already exports prove the ordering works.
- **Constraints honored** (from `apps/tbc-rotation/CLAUDE.md`): Lua 5.1 only; **no table allocation in
  combat** — predicates take primitives/context and return booleans/numbers; the factory allocates its
  strategy table + option table **once at load time**; **never capture settings at load** — the factory
  reads `context.settings.<key>` inside `matches`/`execute`; allocation-free in hot paths.

---

## 5. The predicate API

All flat `NS.*`, allocation-free, side-effect-free. `spell` is an `A.Spell` object, `unit` a unit-id
string, `context` the per-frame context table.

### 5a. Aura foundation (already in `core.lua` — unchanged)

These exist today and the new predicates build on them. **No rename, no move:**
```lua
NS.is_debuff_active(spell, target, source)   -- → bool
NS.get_debuff_state(spell, target, source)   -- → stacks, remaining
NS.is_buff_active(spell, target, source)     -- → bool
```

### 5b. Maintenance predicates (the high-value core)

```lua
-- The maintained-aura workhorse: "missing OR expiring OR understacked" in one call.
-- opts is an OPTIONAL pre-allocated table (no inline {} in combat).
--   opts.kind       = "debuff" (default) | "buff"
--   opts.window     = refresh seconds (aura ending within this → refresh)
--   opts.min_stacks = refresh if stacks < this
--   opts.source     = "player" to only count the player's aura
--   opts.unit       = unit-id (default target for debuff, player for buff)
NS.needs_refresh(spell, unit, opts) -- → bool

-- Lower-level pieces (used directly when needs_refresh is overkill):
NS.about_to_expire(spell, unit, window, kind, source) -- exists AND remaining ≤ window
NS.below_stacks(spell, unit, n, kind, source)         -- stacks < n (absent counts as 0)
```

`needs_refresh` is the single most-reused predicate (every Maintain* strategy). TBC-specific:
no pandemic window exists in TBC (see `COMBAT_MODEL.md` §4), so refreshing early just clips and wastes.
**Default `window` = `0`** — refresh only when the aura is actually gone (no early reapply). Classes
that want a small pre-expiry buffer override via their existing refresh slider (several already expose
one, also defaulting to 0). Trade-off of `0`: reapply happens the frame *after* the aura drops, so a
brief gap is possible under latency; classes that can't tolerate the gap set a small window. This
matches the current per-class defaults rather than imposing a new one.

### 5c. Resource predicates

```lua
NS.resource_capped(context, kind, margin)  -- energy/rage/cp near cap (cap - margin)
NS.combo_points_full(context)              -- cp >= 5  (the most-repeated rogue/cat check)
```

> **Push-back / scope note.** `resource_at_least(ctx, kind, n)` is *not* included: it wraps
> `context.energy >= n`, which is clearer inlined. Wrapping a bare comparison adds indirection for zero
> logic. We keep predicates that encode a *fact* (the cap is 100; "full" is 5) and leave trivial
> comparisons inline.

### 5d. Phase / proc predicates (thin — optional)

```lua
NS.execute_phase(context, pct)  -- context.target_hp and target_hp < pct   (default 20)
NS.proc_up(spell, unit)         -- sugar over is_buff_active
```

Intentionally thin and **optional**. `execute_phase` earns its place only by naming the magic `20`;
`proc_up` is sugar. Most classes already precompute proc booleans in `extend_context`
(`has_clearcasting`, `backlash_active`, …) and should keep reading those — `proc_up` is for ad-hoc
checks, not a mandate to re-derive what the context already has.

### 5e. Reagent check (the "ingredients in the bag" requirement) — a REAL gate, not redundant

**Correction (verified 2026-06-14).** An earlier draft claimed `IsReady` already covers reagents.
**It does not.** The framework chain is `:IsReady` → `:IsUsable` → `IsUsableSpell(self.ID)`
(`TheAction_ActionsLua_HelperFunctions.md:142`), and `IsUsableSpell` does **not** reliably report
missing reagents. The Textfiles note "(mana, reagents, etc.)" oversold it.

**This is a live bug.** `druid/caster.lua:323` `create_self_buff_strategy` gates a self-buff on
`setting → not in_combat → form → spell:IsReady() → buff missing` with **no reagent check**. With the
reagent absent, `IsReady` still returns true, the cast is issued, the game silently rejects it (no
reagent), the buff is still missing, and the strategy re-fires next frame → **observed spam of Gift of
the Wild with an empty reagent slot.** Every reagent-consuming buff strategy has this hole.

**Which spells need it:** the *group* buffs consume a reagent; the single-target versions don't.

| Spell | Reagent | Item ID |
|---|---|---|
| Gift of the Wild | Wild Quillvine | 17021 |
| Arcane Brilliance | Arcane Powder | 17020 |
| Prayer of Fortitude | Holy Candle | 17029 |
| Prayer of Spirit | Sacred Candle | 17028 |
| Prayer of Shadow Protection | Sacred Candle | 17028 |

**The reliable check is item-count**, not `GetSpellCount` (which returns spell *charges*, not reagent
counts, and reads 0 for ordinary buffs):

```lua
-- Primary: bag count of a known reagent item.
NS.item_count(item_id)            -- → GetItemCount(item_id) or 0
NS.has_item(item_id, min_count)   -- → item_count >= (min_count or 1)

-- Secondary, for genuine charge-spells only (NOT reagent buffs):
NS.spell_charges(spell)           -- → GetSpellCount(spell.ID) or 0
NS.has_charges(spell, min_count)  -- → spell_charges >= (min_count or 1)
```

A small pre-allocated `REAGENT_ITEM` map (spell base ID → reagent item ID, the table above) lets the
self-buff / `maintain_aura` factory add the gate automatically (§6). `item_count`/`has_item` also serve
the count-aware cases (Warlock's `soul_shards = GetItemCount(6265)`, "hold the last shard").

#### Affected sites & concrete remediation

Verified by grep — the reagent-consuming buffs the addon actually casts, gated only on `IsReady` and
therefore vulnerable to the spam, are the **group** buffs in Mage and Priest middleware:

| Site | Spell | Reagent (item) | Fix |
|---|---|---|---|
| `mage/middleware.lua:298` | `SelfArcaneBrilliance` | Arcane Powder (17020) | add `NS.has_item(17020)` to the in-group branch |
| `priest/middleware.lua:286` | `PrayerOfFortitude` | Holy Candle (17029) | add `NS.has_item(17029)` |
| `priest/middleware.lua:313` | `PrayerOfSpirit` | Sacred Candle (17028) | add `NS.has_item(17028)` |
| `priest/middleware.lua:341` | `PrayerOfShadowProtection` | Sacred Candle (17028) | add `NS.has_item(17028)` |

Each is a one-line guard in the existing `matches`/branch: don't offer the group buff when its reagent
count is 0 (fall through to the single-target version, which needs none).

`druid/caster.lua` `create_self_buff_strategy` also gains an optional `reagent_item` parameter for
correctness and future-proofing — **but note:** the Druid only casts *single* Mark of the Wild
(`SelfMarkOfTheWild`, ID 1126), which requires **no reagent**, and the addon defines no Gift of the Wild
action. So a reagent gate will **not** explain any observed single-MotW spam; that symptom has a
separate root cause (buff-detection `missing_buff()` against `MOTW_GOTW_BUFF_IDS`, or a non-reagent
cast failure) and is tracked as its own open item (§11), not closed by this work.

---

## 6. The `maintain_aura` strategy factory (the biggest single win)

Archetypes 2 & 3 (maintained debuff / buff) are the most duplicated *strategies* in the tree:
Mage Improved Scorch, Warlock Corruption / Unstable Affliction, Rogue Slice and Dice / Rupture,
Warrior Sunder Armor, Shaman totems, Druid HoTs… all the same shape. A factory builds the whole
strategy table from data:

```lua
NS.maintain_aura(config) -- → a strategy table { name, matches, execute, ... }
```

`config` fields:

| field | meaning |
|---|---|
| `name`, `log_prefix` | strategy name + log tag |
| `spell` | the `A.Spell` to cast (auto-checked `IsReady` via the `spell` field) |
| `kind` | `"debuff"` (track on target) or `"buff"` (track on player) |
| `unit` | override unit (default target for debuff, player for buff) |
| `window` | refresh seconds; or `window_setting_key` to read from `context.settings` |
| `min_stacks` | refresh below this many stacks (e.g. Improved Scorch = 5) |
| `setting_key` | enable/disable toggle (auto-checked) |
| `reagent_item` | optional item ID; `matches` adds `NS.has_item(reagent_item)` so reagent-less casts are blocked (fixes the §5e bug). Auto-filled from `REAGENT_ITEM[spell.ID]` when present. |
| `is_burst` / `is_defensive` | passthrough flags |
| `extra_guard` | optional `function(context, state) → bool` for class-specific gating |

Generated `matches` is essentially:
```lua
matches = function(context, state)
    if cfg.extra_guard and not cfg.extra_guard(context, state) then return false end
    local window = cfg.window_setting_key and context.settings[cfg.window_setting_key] or cfg.window
    return NS.needs_refresh(cfg.spell, resolve_unit(cfg, context), maintain_opts(cfg, window))
end
```
(`maintain_opts` is a per-strategy pre-allocated table mutated in place — no combat allocation.)

**Before** (mage/fire.lua, ~12 lines of bespoke matches + execute):
```lua
local MaintainScorch = {
    name = "MaintainScorch", spell = A.Scorch, setting_key = "maintain_scorch",
    matches = function(context, state)
        local refresh = context.settings.scorch_refresh or 5.5
        return state.scorch_stacks < Constants.SCORCH.MAX_STACKS or state.scorch_duration < refresh
    end,
    execute = function(icon, context, state)
        return NS.try_cast(A.Scorch, icon, ...)
    end,
}
```
**After**:
```lua
local MaintainScorch = NS.maintain_aura({
    name = "MaintainScorch", log_prefix = "[FIRE]", spell = A.Scorch, kind = "debuff",
    min_stacks = Constants.SCORCH.MAX_STACKS, window_setting_key = "scorch_refresh",
    setting_key = "maintain_scorch",
})
```

The class keeps any genuinely special case via `extra_guard` (e.g. Affliction's Amplify Curse path) —
exactly the "data + real special cases" split the combat model argues for.

---

## 7. Group scanning + healing consolidation

The shared-code analysis (§4) flagged 3–4 near-identical `scan_healing_targets` / `get_lowest_hp_target`
implementations (Druid, Paladin, Priest, Shaman) that **collide on the same `NS` key** — last-loaded
wins, load-order-dependent. Rather than just dedupe the healer copies, build it in two layers so the
**target scan is reusable by every class** (dispel targets, Innervate/buff targets, group checks), with
healing as a specialization on top. All in `core.lua` for now; prime candidate to extract during the
deferred restructuring.

**Layer 1 — generic group scanner (any class):**
```lua
-- Iterate party/raid (auto-detects via GetNumGroupMembers), apply a filter, fill a
-- pre-allocated out-table. No combat allocation; `out` is owned by the caller.
NS.scan_group(out, options)  -- → count
--   options.range_spell / options.range_yd  → range filter
--   options.predicate(unit) → bool          → custom include test (dispellable, in-form, etc.)
--   options.include_player / options.include_pets
```

**Layer 2 — healing specialization (healers):**
```lua
NS.scan_healing_targets(context, options)  -- builds on scan_group; entries sorted by HP asc → (entries, count)
NS.get_lowest_hp_target(threshold)         -- → unit-id or nil
-- (NS.predict_effective_deficit already exists in core and stays.)
```

`options` (pre-allocated per class): `range_spell` (Druid="Rejuvenation", Paladin="Flash of Light",
Priest="Flash Heal", Shaman="Chain Heal"), `track_dispels` (Paladin), `track_hots` (Druid). Classes
extend the returned entries with class-specific fields after the scan; **per-class differences survive**
(this is the "data + real special cases" split again — the scan/sort is shared, the class-specific
fields and final spell choice stay local). The four current healers all collapse onto one canonical
owner, fixing the NS-key collision.

> Future (not this design): a `heal_select` factory — emergency / tank / lowest-HP tiers as data — could
> do for healing what `maintain_aura` does for DoTs, boiling each healer down further. Noted as the
> natural follow-on; out of scope here.

> Scope: lowest priority / largest surface (§9). The four return-shapes differ today (Priest returns 6
> values vs others' table+count) and must converge on `(entries, count)` — more design surface than the
> predicates.

---

## 8. Migration (trivial now)

Because everything lands in `core.lua` and the aura helpers **stay put**, there is no move, no
re-export shim, and no rename churn. Steps reduce to: add the new `NS.*` functions to `core.lua`, then
migrate class `matches()` bodies to call them, one class at a time. `pnpm lint:lua` (luacheck) catches
typo'd names / accidental globals before any in-game reload.

---

## 9. Phased rollout

Each phase is independently shippable and build-verifiable (`pnpm --filter @menagerie/tbc-rotation build`
must pass; touch sim paths where they exist):

1. **Maintenance predicates.** Add `needs_refresh` / `about_to_expire` / `below_stacks` to `core.lua`.
   Migrate one pilot class's Maintain* strategies (Mage Fire — Improved Scorch) to prove the shape.
2. **`maintain_aura` factory.** Build it on the phase-1 predicates; convert the pilot, then roll across
   Warlock (Corruption/UA), Rogue (SnD/Rupture), Warrior (Sunder), Shaman totems.
3. **Reagent + resource predicates (fixes a live bug).** Add `item_count`/`has_item` + the
   `REAGENT_ITEM` map. Apply the concrete one-line guards at the four §5e sites
   (`mage/middleware.lua:298`, `priest/middleware.lua:286/313/341`) so group buffs aren't offered with
   an empty reagent slot. Add the optional `reagent_item` parameter to `druid/caster.lua`
   `create_self_buff_strategy` (correctness/future-proofing). Add `spell_charges`/`has_charges`
   (charge-spells only), `resource_capped`/`combo_points_full`. Migrate Warlock's soul-shard read.
   This phase is self-contained and can ship first if the reagent fix is wanted on its own.
4. **Optional thin predicates.** `execute_phase` / `proc_up` — adopt only where they standardize a
   magic number; do not force-replace clear inline comparisons.
5. **Healing consolidation.** One canonical `scan_healing_targets` in core with a unified signature;
   delete the per-class copies and the NS-key collision. (Largest design surface — do last.)
6. **Deferred restructuring (separate plan).** Once the above is stable, split `core.lua` into small
   single-purpose modules and decide grouping/namespacing *then* (§3).

---

## 10. Composition with upcoming work

The same `core.lua` home absorbs the two still-unbuilt items from the shared-code analysis, keeping one
predicate surface:

- **Interrupt helper** (`analysis §6`) → `NS.try_interrupt(icon, spells, opts)`. Off-GCD,
  middleware-facing; simple cases (Mage/Paladin/Priest/Rogue) collapse to one call, complex cases
  (Shaman state machine, Hunter API) stay bespoke.
- **AoE CC-safety** (`analysis Appendix A`) → `NS.has_breakable_cc_nearby(range)` /
  `NS.unit_has_breakable_cc(unit)`. Gates AoE archetypes (combat model §6/§7).

Both are pure predicates/helpers; both later extract cleanly during the §3 restructuring.

---

## 11. Risks & open questions

- **`needs_refresh` default window.** Resolved: default `0` (refresh only when the aura is gone — no
  early clip), `window_setting_key` overrides per class (matches current per-class defaults). See §5b.
- **`maintain_aura` and per-class state tables — resolved.** Some classes precompute aura state in
  `extend_context` (Mage `fire_state.scorch_*`) and both the decision and the **dashboard** read it.
  The factory reads the aura **live** via `needs_refresh`. Decision: **keep both.** A converted class
  reads the aura twice per frame (live for the decision, cached for the dashboard) — an aura read is
  cheap, and both reads see the same frame's state so they can never disagree. Not worth coupling the
  factory to the cache. (If profiling ever flags it, the factory can take an optional
  `stacks_field`/`remaining_field` to read the cache instead — premature now.)
- **Healer return-shape unification.** Priest's 6-value return must converge on `(entries, count)`;
  isolate this in phase 5 so callers don't silently break.
- **`spell_charges` semantics.** `GetSpellCount` returns reagent-allowed casts for *some* spells and
  charge counts for others; confirm per spell before relying on it for a hard gate (`IsReady` remains
  the primary castability check).
- **`core.lua` size.** Accepted temporarily; §3 deferred restructuring is the release valve.
- **Druid single-MotW spam (separate from reagents).** A reported Druid self-buff spam cannot be a
  reagent issue — single Mark of the Wild needs none and the addon defines no Gift of the Wild. Root
  cause is likely `missing_buff()` not detecting the active buff (the `MOTW_GOTW_BUFF_IDS` array + the
  `HasBuffs(..., nil, true)` "mine-only" flag) or a non-reagent cast failure. Needs its own
  reproduction + fix; **not** closed by the reagent work. Tracked here so it isn't lost.

---

## 12. Decisions locked

1. Predicates, the `maintain_aura` factory, reagent helpers, and healing consolidation land in
   **`core.lua`** as flat `NS.*`. **No new `utils.lua` file, no `NS.Utils` table** for now.
2. Existing aura helpers stay put — no rename, no move, no re-export shim.
3. Lead with logic-bearing pieces: `needs_refresh` + `maintain_aura`, then reagent, then healing.
   Trivial wrappers (`execute_phase`, `resource_at_least`) stay optional/inline.
4. **`needs_refresh` default window = `0`** (refresh only when the aura is gone); per-class refresh
   sliders override.
5. **Reagent checks are a real, necessary gate** (corrected) — `IsReady` does *not* cover reagents.
   The reagent phase fixes the live Druid self-buff spam bug via item-count + the `REAGENT_ITEM` map.
6. Healing is built in two layers: a **generic group scanner usable by any class** + a healing
   specialization. Per-class healer differences survive. Kept in `core.lua` for now.
7. `maintain_aura` reads auras live; classes keep their precomputed `state` fields for the dashboard.
8. Splitting `core.lua` into small single-purpose modules ("little cookies") is a **deliberate later
   plan**; grouping/namespacing is decided *with* those file boundaries, not now.
9. `core.lua` is the interim home for the future interrupt helper and AoE CC-safety gate.
