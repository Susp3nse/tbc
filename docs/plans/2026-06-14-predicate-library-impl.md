# Predicate Library (in `core.lua`) — Implementation Plan

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

**Date**: 2026-06-14
**Status**: Completed — all phases executed and landed
**Design**: [`2026-06-14-predicate-library-design.md`](./2026-06-14-predicate-library-design.md)
**Why**: [`docs/research/COMBAT_MODEL.md`](../research/COMBAT_MODEL.md) §3c/§4

> This plan turns the design into ordered, build-verifiable steps with concrete file:line targets and
> exact function signatures. It supersedes the design where the two disagree — the design was reviewed
> against the live tree and several of its "facts" were stale. **Corrections from that review are folded
> in and called out inline as `[REVIEW]`.** Read the design for the "why"; follow this doc to build it.

---

## 0. Corrections to the design (read first)

A code-grounded review of the design surfaced six things to fix before writing any code. They change
*what* we implement, not just the prose:

1. **`needs_refresh` default window is NOT `0`.** `[REVIEW]` No maintained-aura strategy in the tree
   defaults to 0 — Scorch=`6` (`Constants.SCORCH.DEFAULT_REFRESH`), Rogue SnD/Rupture/Deadly Poison=`2`,
   Warlock Corruption=`1.5`, UA=`3`, Immolate=`3`. The real driver is **cast-time + GCD + latency
   compensation** (UA/Immolate are ~1.5–2s casts; you must *start* the refresh one cast-length before
   expiry so the new application lands at/before the drop), **not** pandemic. A `0` default would create a
   guaranteed per-cycle downtime gap on every cast-time DoT. **Decision: the factory requires an explicit
   `window`/`window_setting_key` (no silent default); the raw `needs_refresh` predicate treats a nil
   window as 0 only for the "is it simply gone/understacked?" direct-use case.** See §3, §5.

2. **Healing NS-key collision is 3 classes, not 4.** `[REVIEW]` Paladin, Druid, Priest assign
   `NS.scan_healing_targets`/`NS.get_lowest_hp_target`; **Shaman's is file-local** (`local function
   scan_healing_targets` in `shaman/restoration.lua:56`) and does **not** collide. Consolidation touches
   3 NS callers + optionally folds Shaman's local in.

3. **Priest does NOT return 6 values.** `[REVIEW]` `priest/healing.lua:144 scan_healing_targets` returns
   `(healing_targets, healing_targets_count)` — same `table, count` shape as Paladin/Druid. The design's
   "Priest 6-value return must converge" risk is a ghost. The **real** healer risk is the divergent
   per-class **entry field-sets** (Priest: `has_renew`/`has_pws`/`has_weakened_soul`; Druid: `has_hots`;
   Paladin: dispel tracking) that must survive consolidation via the options/predicate hooks. See §7.

4. **Reagent fix ships FIRST, standalone.** `[REVIEW]` It is a confirmed live spam bug and has zero
   dependency on the predicates/factory. The design buried it as phase 3 while admitting it "can ship
   first." Stop hedging — it is **Phase 1** here. See §4.

5. **Stale snippets / keys.** `[REVIEW]` Mage Fire setting keys are `fire_maintain_scorch` /
   `fire_scorch_refresh` (not `maintain_scorch`/`scorch_refresh`); default refresh is `6` via
   `Constants.SCORCH.DEFAULT_REFRESH` (not `5.5`). §5e doc citation is
   `TheAction_ActionsLua_HelperFunctions.md:143` (not :142); the real call chain is
   `:IsReady → :IsCastable → :IsUsable → IsUsableSpell(self.ID)` (design omitted `:IsCastable`).

6. **Druid single-MotW spam stays out of scope — but must not be conflated in release notes.** `[REVIEW]`
   Confirmed: `druid/caster.lua:323 create_self_buff_strategy` casts single Mark of the Wild (ID 1126, no
   reagent); there is **no** Gift of the Wild action in the tree. A reagent gate cannot fix it; root cause
   is `missing_buff()` / `MOTW_GOTW_BUFF_IDS` detection (`caster.lua:321-328`, the mine-only `HasBuffs`
   flag). See §4 (changelog boundary) and §10.

**Verified-accurate anchors** (safe to build against): aura helpers at `core.lua:689-691`
(`is_debuff_active`/`get_debuff_state`/`is_buff_active`); `NS.predict_effective_deficit` at
`core.lua:668`; load order `core.lua = 4`, `class = 6`, `middleware = 8`, `dashboard = 9`, `main = 10`
(`builder.config.json`); warlock soul shards `_G.GetItemCount(6265)` at `warlock/class.lua:275`.

---

## 1. Scope & sequencing (revised)

Six phases, each independently shippable and build-verifiable. **Reagent bugfix is pulled to the front.**

| Phase | Deliverable | Why this order |
|---|---|---|
| **1** | Reagent + item-count helpers; fix the 4 live group-buff spam sites | Live bug, zero deps — ship now |
| **2** | Maintenance predicates (`needs_refresh`/`about_to_expire`/`below_stacks`) + behavioral-diff harness | Foundation for the factory |
| **3** | `maintain_aura` factory; migrate the Mage Fire pilot | Proves the shape on the hardest path |
| **4** | Roll factory across Warlock / Rogue / Warrior / Shaman | Bulk duplication win |
| **5** | Resource + optional thin predicates (`resource_capped`/`combo_points_full`; `execute_phase`/`proc_up`) | Low-risk, adopt opportunistically |
| **6** | Healing consolidation (`scan_group` + `scan_healing_targets`) | Largest surface, do last |

Restructuring `core.lua` into modules is a **separate plan** (design §3 / §12.8), not in this scope.

---

## 2. Global constraints (every phase honors these)

From `apps/tbc-rotation/CLAUDE.md`:
- **Lua 5.1**, no `goto`, no `//`, no bitops beyond `bit` lib.
- **No table allocation in hot paths.** Predicates take primitives/context and return booleans/numbers.
- **Never capture `settings` at load.** Read `context.settings[key]` inside `matches`/`execute` every
  frame. The factory closes over the *key string*, never the value.
- **File naming**: lowercase single words, no separators.
- **Verify per phase**: `pnpm --filter @menagerie/tbc-rotation build` must pass; `pnpm lint:lua`
  (luacheck) clean; run the behavioral-diff harness (§9) for any migrated `matches()`.

---

## 3. The `opts` / allocation invariant (hard rule) `[REVIEW]`

The factory's safety depends on this; state it so an implementer can't misread it:

> **`maintain_opts` and the strategy table are allocated *inside* each `NS.maintain_aura(...)` call and
> captured in that strategy's own closure. They are NEVER hoisted to a single module-level shared table.**

`core.lua`'s existing habit is one module-level pre-alloc reused everywhere; that habit is **wrong here**
because two factory-built strategies would alias the same opts table and corrupt each other's reads. The
dispatcher (`main.lua:164-193`) is a plain sequential `for _, strategy in ipairs(strategies)` loop —
`matches()` is never nested or re-entrant — so a **per-strategy** opts table mutated in place is safe.
A **shared** one is not.

Corollary for the predicate contract: **`needs_refresh` must read `opts` synchronously and never retain a
reference to it past the call.**

---

## 4. Phase 1 — Reagent fix (the live bug, ships first)

### 4.1 Add to `core.lua` (near the aura helpers, ~`core.lua:691`)

```lua
-- Bag count of a known reagent/consumable item. Allocation-free.
function NS.item_count(item_id)
    return _G.GetItemCount(item_id) or 0
end

function NS.has_item(item_id, min_count)
    return (_G.GetItemCount(item_id) or 0) >= (min_count or 1)
end

-- Charge-spells ONLY (not reagent buffs — GetSpellCount reports charges, not reagent counts).
function NS.spell_charges(spell)
    return _G.GetSpellCount(spell.ID) or 0
end

function NS.has_charges(spell, min_count)
    return (_G.GetSpellCount(spell.ID) or 0) >= (min_count or 1)
end
```

Add the spell→reagent map as a module-level constant (this one IS safe to share — it's read-only):

```lua
-- base spell ID → reagent item ID. Group buffs consume a reagent; single-target versions don't.
local REAGENT_ITEM = {
    -- [<GiftOfTheWild base IDs>]      = 17021, -- Wild Quillvine (no GotW action exists today; reserved)
    -- [<ArcaneBrilliance base IDs>]   = 17020, -- Arcane Powder
    -- [<PrayerOfFortitude base IDs>]  = 17029, -- Holy Candle
    -- [<PrayerOfSpirit base IDs>]     = 17028, -- Sacred Candle
    -- [<PrayerOfShadowProt base IDs>] = 17028, -- Sacred Candle
}
NS.REAGENT_ITEM = REAGENT_ITEM
```

> `[REVIEW]` The item IDs are net-new constants (not currently in the tree); confirm each against an
> item DB before filling them in. Soul-shard precedent (`GetItemCount(6265)`) is verified.

### 4.2 Fix the four live sites (one-line guard each)

Each currently gates on in-group + `:IsReady(PLAYER_UNIT)` with **no reagent check**, so it re-fires
every frame when the reagent slot is empty → observed spam. Add `and NS.has_item(<id>)` so the group buff
isn't offered without its reagent (falls through to the single-target version, which needs none):

| Site (verified) | Spell | Guard to add |
|---|---|---|
| `mage/middleware.lua:298` | SelfArcaneBrilliance | `and NS.has_item(17020)` |
| `priest/middleware.lua:286` | PrayerOfFortitude | `and NS.has_item(17029)` |
| `priest/middleware.lua:313` | PrayerOfSpirit | `and NS.has_item(17028)` |
| `priest/middleware.lua:341` | PrayerOfShadowProtection | `and NS.has_item(17028)` |

> `[REVIEW2]` The three Priest sites already carry an `is_spell_available(...)` guard alongside
> `:IsReady(PLAYER_UNIT)` — append the `and NS.has_item(...)` to that existing branch. (Mage's is
> `in_group and IsReady` only.) Cosmetic to the fix; noted so you append to the right expression.

> `[REVIEW2]` `REAGENT_ITEM` stays **empty in Phase 1** — the four fixes above use literal IDs directly,
> not the map. The map and its `REAGENT_ITEM[spell.ID]` auto-fill only matter in Phase 3, and resolving
> `A.Spell` base IDs (spell identity here is the Action object's `.ID`) is a **Phase-3 prerequisite**, not
> a Phase-1 task. Leave the table stubbed/commented until then.

`druid/caster.lua:323 create_self_buff_strategy` gains an **optional** `reagent_item` parameter for
future-proofing (auto-gates `NS.has_item(reagent_item)` when set). **It is not wired to anything today**
— the Druid only casts single MotW (no reagent). Document that this does **not** fix the single-MotW
spam.

### 4.3 Changelog boundary `[REVIEW]`

The release note for this phase must say **"group buff (Arcane Brilliance / Prayer of …) spam with an
empty reagent slot"** — NOT "self-buff spam fixed." The single-MotW self-buff spam is a **separate,
still-open** issue (§10). Do not let the two conflate, or we'll get "still spamming" reports against this
fix.

### 4.4 Verify
- `pnpm --filter @menagerie/tbc-rotation build` + `pnpm lint:lua`.
- Manual: with the reagent removed from bags, the group buff is no longer offered; single-target still is.

---

## 5. Phase 2 — Maintenance predicates + diff harness

### 5.1 Add to `core.lua`

```lua
-- exists AND remaining <= window. kind: "debuff"(default)|"buff". source: "player" => mine-only.
function NS.about_to_expire(spell, unit, window, kind, source) ... end

-- stacks < n (absent aura counts as 0). Same kind/source axes.
function NS.below_stacks(spell, unit, n, kind, source) ... end

-- The workhorse: "missing OR expiring OR understacked" in one call.
-- opts is an OPTIONAL pre-allocated table (no inline {} in combat):
--   opts.kind       = "debuff"(default) | "buff"
--   opts.window     = refresh seconds; NIL => 0 (treat as "only when gone") for direct use [REVIEW]
--   opts.min_stacks = refresh if stacks < this
--   opts.source     = "player" to count only the player's aura
--   opts.unit       = unit-id (default target for debuff, player for buff)
function NS.needs_refresh(spell, unit, opts) ... end
```

Build all three on the existing `core.lua:689-691` aura helpers. `needs_refresh` must **not retain
`opts`** past the call (§3).

**Pin the exact boolean** `[REVIEW2]` (the precedence is the whole ballgame — an implementer must not
guess it, and it must match the pilot's `stacks < MAX or duration < refresh` OR-semantics):
```lua
-- needs_refresh = missing OR understacked OR expiring  (any one => refresh)
function NS.needs_refresh(spell, unit, opts)
    local stacks, remaining = <read aura via the §5a helpers, honoring opts.kind/opts.source>
    if stacks == 0 then return true end                                  -- missing
    if opts.min_stacks and stacks < opts.min_stacks then return true end -- understacked
    return remaining <= (opts.window or 0)                               -- expiring (nil window => 0)
end
```

> `[REVIEW]` `window = nil → 0` is acceptable for the **raw predicate** (direct "is it gone?" use). The
> **factory** does NOT inherit this — it *requires* an explicit window so a careless migration can't
> silently turn "refresh at 6s" into "refresh at 0s" (§6, §0.1).

### 5.2 Behavioral-diff harness (NEW — the real regression net) `[REVIEW]`

`build` + `luacheck` prove it compiles; they prove **nothing** about decisions. Threshold-translation
drift stays green through both. The harness feeds identical synthetic states into the **old** `matches()`
and the **new** factory/predicate `matches()` and asserts identical boolean output. **This is the gate for
every migration in phases 3–6** — so it has to be *real*, not aspirational.

> `[REVIEW2]` **The existing test pipeline cannot run this.** `test/guardrails.test.ts` is a static
> regex-over-source check; the sim (`src/sim/*`) *re-implements* the timing model in TypeScript and never
> executes the addon Lua. `pnpm test` = `tsx test/guardrails.test.ts`. So "run old vs new `matches()`
> side by side" has **no existing mechanism** — building it is part of Phase 2, scoped here:

**Substrate.** Run the predicate/matches logic as Lua via the system `lua` binary from a small Node test
(spawn + compare), OR add a Lua test runner. Note the machine's `lua` is 5.5 while the addon targets
**Lua 5.1** (CLAUDE.md hard constraint) — for pure-boolean predicates the gap is immaterial, but pin the
interpreter explicitly and avoid 5.1-incompatible constructs in the harness fixtures.

**WoW-API stub module** (the work the design hid). `core.lua` binds these from `_G.Action` at load
(`core.lua:13/52/53`); the harness must provide stubbed `_G`:
- `_G.Action` with `Unit(id):HasDeBuffs / HasDeBuffsStacks / HasBuffs / HasBuffsStacks` returning the
  case's synthetic `(stacks, remaining)`.
- `_G.UnitExists`, `_G.GetItemCount`, `_G.GetSpellCount`.
- a fake `context` (`.settings[key]`, resources) and a fake `state` table.

**Reconcile the two read paths** `[REVIEW2]` — the subtle trap: old `MaintainScorch` reads **cached**
`state.scorch_stacks/scorch_duration` (populated by `get_fire_state` via the live API); the new factory
reads the aura **live** via `needs_refresh`. For each case the harness must drive **both** the live stub
**and** the cached `state` fields to the same synthetic value, or it reports false diffs. (This is exactly
the cached-vs-live equivalence the design §11 asserts "can never disagree" — the harness is what *proves*
it.)

**Cases per migrated aura strategy:** aura remaining ∈ {0, 1, 2, 5.9, 6.1, ∞}; stacks ∈ {0..max};
reagent present/absent where relevant; setting on/off.

**Deliverable before Phase 3:** one fully worked example — `MaintainScorch` old body vs new factory
config — passing end to end through the stub. Until that exists, "diff harness green" is **not** a
checkable DoD item.

### 5.3 Verify
- New predicate unit tests (truth tables) green.
- `build` + `lint:lua` clean.

---

## 6. Phase 3 — `maintain_aura` factory + Mage Fire pilot

### 6.1 `NS.maintain_aura(config) → strategy table`

Config fields (design §6 + `[REVIEW]` additions):

| field | meaning |
|---|---|
| `name`, `log_prefix` | strategy name + log tag |
| `spell` | `A.Spell` to cast (auto `:IsReady` via the `spell` field) |
| `kind` | `"debuff"` (track on target) / `"buff"` (track on player) |
| `unit` | override unit (default per kind) |
| **`source`** `[REVIEW]` | `"player"` for mine-only aura tracking — **required for Corruption/UA** or they refresh off another lock's DoT and never fire. Real gap in the design. |
| `window` **or** `window_setting_key` | **one is REQUIRED** `[REVIEW]` — no silent default (§0.1). `window_setting_key` reads `context.settings[key]` live. |
| `min_stacks` | refresh below this many stacks (Improved Scorch = 5) |
| `setting_key` | enable/disable toggle (auto-checked) |
| `reagent_item` | optional item ID → `matches` adds `NS.has_item(...)`. Auto-filled from `REAGENT_ITEM[spell.ID]` |
| **`stacks_field` / `remaining_field`** `[REVIEW]` | optional cache field names; when set, read the cached `state.<field>` instead of a live aura read. **Built in from the start** (design deferred this; review promotes it) so the decision and the dashboard share one source of truth. Defaults to live read. |
| `is_burst` / `is_defensive` | passthrough flags |
| `extra_guard` | `function(context, state) → bool` for class-specific gating |

**Boundary (state it explicitly)** `[REVIEW]`: `maintain_aura` is for **fixed-spell, fixed-unit,
threshold-driven upkeep**. Dynamic spell selection (rank/mana-tier) or dynamic target selection
(multi-dot) stays **bespoke** — do not grow a `spell_selector` callback onto the factory later.

`resolve_unit` `[REVIEW2]` (referenced below; define it — don't make the implementer guess):
```lua
-- cfg.unit override wins; else default by kind.
local function resolve_unit(cfg, context)
    if cfg.unit then return cfg.unit end
    return cfg.kind == "buff" and PLAYER_UNIT or context.target -- match how target/PLAYER_UNIT are named in core.lua
end
```

Generated `matches` (per-strategy `opts` table, closure-owned, mutated in place — §3):
```lua
matches = function(context, state)
    if cfg.extra_guard and not cfg.extra_guard(context, state) then return false end
    if cfg.reagent_item and not NS.has_item(cfg.reagent_item) then return false end
    local window = cfg.window_setting_key and context.settings[cfg.window_setting_key] or cfg.window
    -- opts is THIS strategy's pre-allocated table, mutated here, read synchronously by needs_refresh
    opts.kind, opts.window, opts.min_stacks, opts.source, opts.unit =
        cfg.kind, window, cfg.min_stacks, cfg.source, resolve_unit(cfg, context)
    return NS.needs_refresh(cfg.spell, opts.unit, opts)
end
```

### 6.2 Pilot: Mage Fire / Improved Scorch (`mage/fire.lua:61-77`, registered :253)

Hardest path (exercises both `min_stacks` and `window`). **Carry forward the existing constants exactly**
`[REVIEW]`:

```lua
local MaintainScorch = NS.maintain_aura({
    name = "MaintainScorch", log_prefix = "[FIRE]", spell = A.Scorch, kind = "debuff",
    source = "player",                          -- mine-only (don't refresh off another mage's Scorch)
    min_stacks = Constants.SCORCH.MAX_STACKS,   -- = 5
    window_setting_key = "fire_scorch_refresh", -- [REVIEW] real key (was "scorch_refresh")
    setting_key = "fire_maintain_scorch",       -- [REVIEW] real key (was "maintain_scorch")
})
-- Existing schema default for fire_scorch_refresh = Constants.SCORCH.DEFAULT_REFRESH = 6 (NOT 5.5). [REVIEW]
```

Gate the migration on the §5.2 harness: old vs new `matches()` must be bit-identical across the case
matrix **before** the bespoke body is deleted.

### 6.3 Pre-migration grep `[REVIEW]`
Before deleting any cached `state.scorch_*` writes, grep for cross-strategy ordering coupling: confirm no
*other* strategy reads a cached aura field that this strategy's old `matches`/`execute` populated as a
side effect. (Dashboard reads are fine — same frame, same value.)

**Dead-code decision** `[REVIEW2]`: after migration the cached `state.scorch_*` (from `get_fire_state`)
is still read by the **dashboard**, so `get_fire_state` is **not** dead — but the decision path no longer
uses it. Decide explicitly per migrated class whether the cache stays (dashboard-only) or the dashboard
also moves to the factory's optional `stacks_field`/`remaining_field` read. Don't leave it half-used and
unstated. (This is the single-source-of-truth choice from §6.1's `stacks_field`/`remaining_field`.)

### 6.4 Verify
- Diff harness green; `build` + `lint:lua`; `pnpm --filter @menagerie/tbc-rotation sim:mage` if a Fire sim
  path exists.

---

## 7. Phase 4 — Roll the factory out

Convert, one class per change, each behind the diff harness, **carrying each class's existing numeric
constant** into `window`/`min_stacks` (do **not** use any default):

| Class | Strategies | Existing constant to preserve `[REVIEW]` |
|---|---|---|
| Warlock | Corruption, Unstable Affliction, Immolate | `1.5` / `3` / `3`; **`source="player"`** mandatory |
| Rogue | Slice and Dice, Rupture, Deadly Poison | `SND_MIN_DURATION=2` (class.lua:141) / Rupture bare `or 2` / `DP_REFRESH_THRESHOLD=2` (class.lua:142) |
| Warrior | Sunder Armor | `SUNDER_MAX_STACKS=5` (class.lua:197) → `min_stacks`; `SUNDER_REFRESH_WINDOW=3` (class.lua:198) → `window` `[REVIEW2]` |
| Shaman | totems **only** | `TOTEM_REFRESH_THRESHOLD=10` (class.lua:162) → `window`. **Shields do NOT migrate** `[REVIEW2]` — they're charge-based (`water_shield_charges <= 1`, middleware.lua:306), not duration-based; they don't fit the `window`-seconds model. Use `has_charges` (§8), not `maintain_aura`. |

Each class keeps genuine special cases via `extra_guard` (e.g. Affliction Amplify Curse path). Anything
needing dynamic spell/target selection — or charge-based upkeep like Shaman shields — does **not** migrate
(§6.1 boundary).

---

## 8. Phase 5 — Resource + thin predicates

```lua
NS.resource_capped(context, kind, margin)  -- cap - margin (encodes the cap fact)
NS.combo_points_full(context)              -- cp >= 5  (most-repeated rogue/cat check)
-- Optional, adopt ONLY to name a magic number — never force-replace clear inline comparisons:
NS.execute_phase(context, pct)             -- target_hp < pct (default 20)
NS.proc_up(spell, unit)                    -- sugar over is_buff_active
```

**Excluded by design (and review agrees):** `resource_at_least(ctx, kind, n)` — wraps a bare comparison,
clearer inlined. Most classes precompute proc booleans in `extend_context`; keep reading those.
Migrate Warlock's soul-shard read to `NS.item_count(6265)` here.

---

## 9. Phase 6 — Healing consolidation (largest surface, last)

### 9.1 Two layers in `core.lua`
```lua
-- Layer 1 — generic, any class. Fills caller-owned out-table; no combat allocation.
NS.scan_group(out, options) -- → count
--   options.range_spell / range_yd, options.predicate(unit), options.include_player/include_pets

-- Layer 2 — healer specialization, built on scan_group; sorted by HP asc.
NS.scan_healing_targets(context, options) -- → (entries, count)   [REVIEW] table+count, matches today
NS.get_lowest_hp_target(threshold)        -- → unit-id or nil
```

### 9.2 What actually has to converge `[REVIEW]`
- **NS-key collision = 3 classes**, not 4: `paladin/healing.lua:206/208`, `druid/healing.lua:418/421`,
  `priest/healing.lua:193/195`. Optionally fold in Shaman's **file-local** `scan_healing_targets`
  (`shaman/restoration.lua:56`) — it does **not** collide, so it's a cleanup, not a conflict fix.
- **No return-arity change.** Priest already returns `(entries, count)` — same as the others. The design's
  "6-value → 2" risk does **not** exist; do not chase it.
- **The real breakage surface is per-class entry fields.** Preserve them via the `options`/`predicate`
  hooks (verified exact field names) `[REVIEW2]`:
  - Priest: `has_renew` / `has_pws` / `has_weakened_soul` (`priest/healing.lua:122-124`).
  - Druid: `has_rejuv` + `has_regrowth` (`druid/healing.lua:201-202`) — **not** `has_hots`, which does
    not exist (corrected error).
  - Paladin: `has_poison` / `has_disease` / `has_magic` / `needs_cleanse` / `has_healing_reduction`
    (`paladin/healing.lua:43-44`).
  Classes extend returned entries with their own fields after the scan; the scan/sort is shared, the
  field-population and final spell choice stay local.

`NS.predict_effective_deficit` (`core.lua:668`) stays. The `heal_select` factory remains **out of scope**
(design §7) — build the scanner, observe the converged shape, decide later.

### 9.3 Verify
Diff harness comparing each old healer's target list/order against the consolidated owner for identical
group states, **including the class-specific entry fields**.

---

## 10. Out of scope (tracked, not closed here)

- **Druid single-MotW self-buff spam** `[REVIEW]` — root cause is buff-detection (`missing_buff()` /
  `MOTW_GOTW_BUFF_IDS` + the mine-only `HasBuffs(..., nil, true)` flag at `caster.lua:321-328`), NOT
  reagents. Needs its own reproduction + fix. Keep it out of this work's changelog narrative (§4.3).
- **`core.lua` module split** ("little cookies") — separate plan (design §3/§12.8).
- **`NS.try_interrupt` / AoE CC-safety helpers** — future; same `core.lua` home, extracted with the split.
- **`heal_select` factory** — after the healer shape converges (§9.2).

---

## 11. Definition of done (per phase)

1. `pnpm --filter @menagerie/tbc-rotation build` passes.
2. `pnpm lint:lua` clean (no globals, no typo'd `NS.*`).
3. New predicate unit tests + the behavioral-diff harness (§5.2) green for everything migrated.
4. **Migration checklist** `[REVIEW]` for each converted strategy: the old numeric constant is cited in
   the PR and carried verbatim into the factory config ("do not change the number").
5. Sim path run where one exists for the touched class.
6. Changelog scoped accurately (esp. the reagent/MotW boundary, §4.3).
