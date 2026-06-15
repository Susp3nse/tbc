# WS-4 + WS-5 + WS-6 + WS-8 — Schema & Actions Hoist Batch — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md`
> §4.4 (WS-4), §4.5 (WS-5), §4.6 (WS-6), §4.8 (WS-8).
> **Evidence:** `2026-06-14-platform-audit/01-duplication.md` (#1/#2/#3/#7), `04-ergonomics.md` (#6).
> **Status (verified 2026-06-15):** WS-4 not started · WS-5 not started · WS-6 partial (10/19 spec
> files on the factory) · WS-8 not started. **Risk:** Low (WS-4/5/8), Low–Med (WS-6 arcane/paladin).
>
> Bundled because all four are "apply a pattern that already exists." Net ~330 lines removed across
> 9 classes. No rotation-behavior change except WS-6 racial migrations (verify each).
>
> **Heads-up (2026-06-15):** `ui.lua` was renamed to **`profileui.lua`** (see
> `2026-06-15-ui-rename-and-widgets-impl.md`). The WS-4 schema-tail auto-append lands in
> `src/aio/profileui.lua` — the references to `ui.lua` below (incl. `ui.lua:15-21`) now mean that file.

## Sequencing within this batch

WS-4 and WS-5 are independent and parallel-safe. WS-8 *folds into* WS-4 (schema tail) and WS-5/the
trinket factory once those land. WS-6 is independent. Recommended: WS-4 → WS-5 → WS-8 → WS-6.

---

## WS-4 — Schema `SECTIONS` expansion

**File:** `apps/tbc-rotation/src/aio/common.lua` (`_G.Menagerie_SECTIONS`, currently 6 factories:
`dashboard`, `burst`, `debug`, `trinkets`, `recovery`, `mana_recovery`).

Add three pure-data factories mirroring the existing pattern (each returns a `{ header, settings }`
table; the three consumers `ui.lua`/`settings.lua`/`core.lua` don't care how it was built):

```lua
immunity = function(opts)   -- the immune_learn_ttl_min slider (9/9 classes)
cooldowns = function(opts)  -- the cd_min_ttd slider (9/9 classes); opts reserved for future CD gates
spec = function(opts)       -- "Spec Selection" header; opts = { default = "fire", options = {...} } (7/9)
```

**Hand-roll counts to eliminate** (replace each inline block with the factory call):
- `immune_learn_ttl_min` — **9/9**: druid/hunter/mage/paladin/priest/rogue/shaman `schema.lua:30`,
  warrior `schema.lua:40`. All 9 tooltips are **byte-identical** (warrior's differs only in
  whitespace/indent) — hardcode one canonical wording in the factory; **no per-class `opts` override
  needed.**
- `cd_min_ttd` — **9/9**: druid:63, hunter:40, mage:61, paladin:49, priest:72, rogue:63, shaman:82,
  warlock:63, warrior:250.
- "Spec Selection" — **7/9** (not druid/hunter, which have no spec dropdown): mage:33, paladin:33,
  priest:33, rogue:33, shaman:33, warlock:33, warrior:51. The per-class `options` array **and its
  default** (mage `fire`, warrior `fury`, …) stay in the class; the wrapper moves to
  `S.spec({ default = ..., options = ... })`. The factory **must take the default**, not just `options`.

**Verification:** `pnpm --filter @menagerie/tbc-rotation build`; open settings in-game for two classes
(one with a spec dropdown, one without) and confirm the General tab renders identically. Confirm
`cached_settings.immune_learn_ttl_min` and `cd_min_ttd` still resolve.

---

## WS-5 — Shared consumable action injector

**File:** `apps/tbc-rotation/src/aio/core.lua` (new `NS.register_consumable_actions(A)`); call from each
`class.lua` **after** the `Action[A.PlayerClass]` table literal is built and `A` is reassigned to it
via `setmetatable` (e.g. `mage/class.lua:87`). At that point `A` is the class table, so
`A.SuperHealingPotion = ...` lands on it and `A.Create` resolves through the `__index = Action`
metatable. Core is slot 4, class slot 6 — load-order safe.

Inject the standard item Actions so literal IDs live in **one** place (wrong-ID-in-one-class is a
silent recovery bug today). The injector provides the **Action objects only**; each class's
`*/middleware.lua` keeps its own `actions = { ... }` recovery list — **order is a per-class priority**
(warlock fires `Fel` first at `middleware.lua:54`, hunter fires `Master` first at `middleware.lua:61`)
and must not be centralized.

Inject **8** consumables — all instant-use → all `QueueForbidden = true`, all with a player-target `Click`:

| Name | ID | Type |
|------|----|------|
| `SuperHealingPotion` | 22829 | `Potion` |
| `MajorHealingPotion` | 13446 | `Potion` |
| `SuperManaPotion`    | 22832 | `Potion` |
| `DarkRune`           | 20520 | `Item`   |
| `DemonicRune`        | 12662 | `Item`   |
| `HealthstoneMaster`  | 22105 | `Item`   |
| `HealthstoneMajor`   | 22104 | `Item`   |
| `HealthstoneFel`     | 22103 | `Item`   |

**Decisions forced by the audit:**
- **Three healthstone tiers, canonical names `HealthstoneMaster`/`Major`/`Fel`.** `Fel` (22103) is the
  real TBC item name — warlock already uses it; hunter's `HSMaster3` was the inaccurate one. The 7
  two-tier classes only list `{ Master, Major }` in their recovery middleware; the injected `Fel` goes
  unused for them (harmless — settings-gated, never fires).
- **`QueueForbidden = true` on all 8** — correct for instant-use consumables (excludes them from the
  framework's predictive cast queue). Today warrior sets it on all its consumables; hunter only on
  `SuperHealingPotion`; the other 7 omit it. Hardcoding it in the injector (one place) harmonizes them.
  **No per-item toggle** — nothing in the codebase needs `false`.
- **All three potions are `Type = "Potion"`** (`SuperHealingPotion`, `MajorHealingPotion`,
  `SuperManaPotion`). The framework keys the shared healing/mana potion cooldown off `Type = "Potion"`,
  so the existing `Type = "Item"` mana-potion declarations were wrong — this corrects them. Healthstones
  and runes stay `Type = "Item"`.
- **Inject all 8 unconditionally.** Rogue/warrior (energy/rage) and hunter never declared
  `SuperManaPotion`/`DarkRune`/`DemonicRune`; the extra Actions cost nothing and recovery middleware
  gates on settings, so they never fire.
- **`MajorManaPotion 13444` stays out** — only shaman declares it; keep it shaman-local.
- **`Click` handler now uniform.** paladin/warrior/druid declared their healthstones *without* a `Click`
  block; the injected form adds one. Verify **paladin/warrior** still cast (for druid the self-target
  Click is harmless-but-unused — druid only casts via `form_action`). Druid Cat/Bear form-shift variants
  (`druid/class.lua:~192–207`) stay per-class. **Load-order note:** druid's base→variant mapping tables
  (`druid/middleware.lua:84-100`) are keyed by the **base Action object**, so the injector (slot 6) must
  run before druid middleware builds them (slot 8) — it does, but the dependency is non-obvious. Druid's
  per-item `Desc` strings are not reproduced by the injector (cosmetic — confirm nothing reads them).

**Steps:**
1. Add `NS.register_consumable_actions(A)` to `core.lua` (uses `A.Create`); call it in each `class.lua`
   right after the `setmetatable` reassignment of `A`.
2. Delete the matching per-class `A.X = Create{...}` declarations for the 8 IDs above. Keep shaman's
   `MajorManaPotion`, warlock's nothing-extra, and druid's form-shift variants.
3. **Hunter rename:** `HSMaster1/2/3` → `HealthstoneMaster/Major/Fel` in `hunter/class.lua:134-136`
   **and** `hunter/middleware.lua:61`.
4. **Warlock:** delete only its 3 healthstone declarations — `middleware.lua:54` already references
   `HealthstoneFel/Master/Major`, so no middleware edit.

**Verification:** for each class, confirm Healthstone + healing-potion recovery still fires in a sim or
on a dummy (gated by `healthstone_hp` / `use_healing_potion`). **Grep that no `HSMaster1`/`HSMaster2`/
`HSMaster3` references remain anywhere.** Spot-check paladin/warrior (newly gained `Click`) actually
cast the healthstone, and that warlock still tries `Fel` first.

---

## WS-8 — Auto-register universals (opt-out)

Both halves are "called identically 9/9" today; make them default-on with an opt-out.

**8a — Schema tail.** `S.burst()` / `S.dashboard()` / `S.debug()` are hand-appended to the General tab
in all 9 `schema.lua`. Provide a composer so a class stops re-listing them:
- Option A: `S.general_tail(opts)` returning the 3 sections as an array the schema spreads.
- Option B (preferred): have `ui.lua` / the schema-load path auto-append the tail if absent, with an
  opt-out `_G.Menagerie_SETTINGS_SCHEMA.no_default_tail = true`.

Pick A if you want the append explicit/visible per class; pick B for true zero-boilerplate. **Recommend
B** to match the §1 goal ("a class writes only a rotation"). Implement it in `ui.lua` (first consumer
after schema, before the `generate` at `:106`), appending the tail as **new section entries** — do
**not** merge into `sections[1]`, which `ui.lua:15-21` already mutates for the hidden toggle-button
position. Remove the 3 trailing calls from each `schema.lua` once the auto-append lands.

**8b — Trinket middleware.** `NS.register_trinket_middleware()` (`core.lua:1507`) is opt-in but called
by 9/9 (`*/middleware.lua`). Auto-register it from `register_class` with an opt-out field
`auto_trinkets = false`. Timing: it reads `NS.A` (`core.lua:1508`, early-returns if unset), but **`NS.A`
is already set before `register_class` runs in all 9 classes** (e.g. `mage/class.lua:88` sets `NS.A`,
`:150` calls `register_class`) and `register_class` itself never touches `NS.A` — so registering
directly inside `register_class`, gated on `config.auto_trinkets ~= false`, works today. A
deferred/post-class step is optional future-proofing, not a requirement. Remove the 9 explicit
`NS.register_trinket_middleware()` calls.

**Verification:** confirm trinket middleware still fires (set a trinket to Offensive, `/menagerie
burst`). Confirm every class's settings still shows Burst/Dashboard/Debug sections. Confirm the opt-out
flag actually suppresses each.

---

## WS-6 — Racial strategy factory adoption (finish the partial)

**File:** `apps/tbc-rotation/src/aio/core.lua` (`create_racial_strategy`, `core.lua:1243`) + 9 spec files.

**Blocking change first (two parts).** `create_racial_strategy`'s `matches` closure (`core.lua:1255-1262`)
has **no `extra_match` hook** (unlike `create_combat_strategy`, which ANDs `config.extra_match` at
`core.lua:1231`). Add **both**:
1. **Strategy-wide** `opts.extra_match(context)` — nil-guarded, ANDed into `matches` (no-op for the 10
   already-migrated callers). Unblocks **arcane**.
2. **Per-spell** predicate on each `spells[]` entry (`spells[i][3] = fn(ctx)`), checked inside the
   existing readiness loop (`core.lua:1257-1260` / `1265-1267`): `if entry[3] and not entry[3](context)
   then` skip. This is what **paladin ret/prot** need — a strategy-wide gate can't express "Stoneform
   always, GiftOfTheNaaru only at `hp<60`." It also gets the deferred holy escape halfway there (holy
   still needs a per-spell *unit* param — defer that).

**Migrate (9 hand-rolled spec files):**
| File | Wrinkle | Action |
|------|---------|--------|
| `mage/arcane.lua:178` | `state.is_burning` gate | `extra_match = function(ctx) return ... is_burning end` — **do last** |
| `priest/discipline.lua:196`, `holy.lua:293`, `smite.lua:207` | `is_spell_available()` guard; `smite` also *always-matches* (checks readiness only in `execute`) | factory's `if action and action:IsReady` is equivalent (the 10 migrated specs already rely on it). Migrating **adds** a `ttd_too_short` gate priest lacks today — desirable (matches every other spec), but call it out in verify. `smite` gating `matches` on readiness is strictly better, not a regression. |
| `shaman/restoration.lua:362` | `A.BloodFurySP` (ID 33697 — spellpower Blood Fury variant) | pass the variant Action as a spell entry; SP→Berserking order preserved by array order |
| `paladin/retribution.lua:173`, `protection.lua:437` | Stoneform (unconditional) + GiftOfTheNaaru (`hp<60`) — a **per-spell** gate, not strategy-wide | use the per-spell predicate: `{ A.GiftOfTheNaaru, "Gift", function(ctx) return ctx.hp < 60 end }`, Stoneform ungated. `ret` checks `use_racial` inline (no `setting_key`); `prot` has it (`:441`) — factory's hardcoded key preserves both. Verify first-ready-wins order matches. |

**Do NOT migrate (genuine escapes):**
- `paladin/holy.lua:312` — GiftOfTheNaaru targets `state.lowest.unit` (a party member), not self, **and**
  is `hp<60`-gated. The new per-spell predicate covers the HP gate, but the factory is still
  player-unit-only — full migration also needs a per-spell `unit` param. Defer (small follow-up once the
  per-spell predicate lands).
- `hunter/rotation.lua:467` — imperative inline inside a burst block, not a strategy entry; would need
  extraction first. Defer.
- `warrior/middleware.lua:824` — it's *middleware* with a PvP CC guard, not a strategy. Leave bespoke.

**Verification per migrated spec:** racial fires under the same conditions as before. Where a sim path
exists, run it; otherwise dummy-test the burst window. Do arcane last and confirm the burn-gate still
holds.

---

## Risks / rollback

- WS-4/8 are mechanical and behavior-preserving; the risk is a typo in a moved tooltip/ID. The build
  + a settings-render spot check catches it.
- WS-5 is *mostly* mechanical but has two deliberate behavior touches to verify on a dummy: paladin/
  warrior/druid healthstones gain a `Click` handler, and all three potions move to `Type = "Potion"`
  (correcting the mana potion, which was wrongly `Type = "Item"` and so escaped the shared potion
  cooldown). Confirm potions + healthstones still cast and that the potion CD is now shared. The hunter
  `HSMaster1/2/3` rename is the one rename-everything-or-it-breaks step — grep proves it's clean.
- WS-6 is the behavior-sensitive part: each migration must preserve the exact racial priority and gate.
  Migrate one spec, verify, commit; don't batch all 9 blind.
- Each WS can ship as its own commit (`feat(builder): …` / `refactor(<class>): …`) so a regression
  bisects cleanly.
