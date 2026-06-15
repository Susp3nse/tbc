# Platform Audit — Cross-Class Code Duplication (read-only)

Scope: `apps/tbc-rotation/src/aio/` — 9 classes (`druid hunter mage paladin priest rogue shaman warlock warrior`), their `class.lua` / `middleware.lua` / `schema.lua` / per-playstyle files, against the shared platform (`common.lua`, `core.lua`).

**Headline:** the platform is already in good shape. The two biggest recovery surfaces are factored: `NS.register_recovery_middleware` (core.lua:1671) is used by **8/9** classes, `NS.register_trinket_middleware` (core.lua:1838) by **9/9**, the schema `Menagerie_SECTIONS` factories (common.lua) by **9/9**, and `NS.create_racial_strategy` (core.lua:1574) by **5/9**. The remaining duplication is concentrated in: (1) racial strategies that *don't* use the existing factory, (2) consumable-item Action declarations re-typed in every class.lua, (3) three identical General-tab schema sections, (4) the interrupt cast-check idiom, (5) the trivial HP-threshold defensive middleware shape, and (6) the `is_moving`/`is_mounted`/`combat_time` context block.

Risk legend: **L** = mechanical, byte-identical, low blast radius. **M** = needs a small factory + per-class params. **H** = behavioral variance between classes; factoring risks regressions.

## Ranked findings

| # | Finding | Classes | Approx. lines | Payoff | Risk | Hoist target |
|---|---------|---------|---------------|--------|------|--------------|
| 1 | Racial strategy hand-rolled despite `create_racial_strategy` existing | 4 (mage-arcane, paladin×3, priest×3, hunter) ~8 spec files | ~25 lines × 8 = **~200** | High | **L–M** | adopt existing `NS.create_racial_strategy` |
| 2 | Consumable-item Action declarations (Healthstone/potions/runes) re-typed | 9/9 class.lua | ~7 lines × 9 = **~63** + ID-drift risk | High | **L** | `NS.CONSUMABLE_ACTIONS` shared table in core.lua |
| 3 | Identical General-tab schema sections (Immunity Learning, CD Min TTD, Spec Selection) | 9 / 9 / 7 | ~10 lines × ~25 = **~120–150** | High | **L** | add `Menagerie_SECTIONS.immunity()/cooldowns()/spec()` |
| 4 | Interrupt cast-check idiom (`IsCastingRemains` + `notKickAble`) | 6 (mage, paladin, priest, rogue, shaman, warrior) | ~8 lines × ~10 sites = **~80** | Med | **M** | `NS.register_interrupt_middleware` / `NS.target_is_interruptible(unit)` helper |
| 5 | Trivial HP-threshold defensive middleware shape | 5 (mage, paladin, rogue, warlock, warrior) ~10 blocks | ~18 lines × 10 = **~180** but high variance | Med | **M–H** | `NS.register_hp_defensive{spell,setting,...}` |
| 6 | `is_moving`/`is_mounted`/`combat_time` context block | 8/9 class.lua | ~4 lines × 8 = **~32** | Low–Med | **L** | `NS.apply_common_context(ctx)` helper |
| 7 | Racial Action declarations re-typed in class.lua | 9/9 | ~5 lines × 9 = **~45** | Low | **M** | partial — IDs vary by class (see notes) |
| 8 | Party/raid dispel-scan loop | 2 (mage, priest) | ~15 lines × ~6 = **~90** | Med | **M–H** | `NS.scan_dispel_targets(dispel_type, cb)` |

---

## 1. Racial strategy: factory exists, ~8 spec files ignore it — HIGHEST PAYOFF

A racial-firing DPS strategy (`use_racial` checkbox → try BloodFury/Berserking/ArcaneTorrent/WarStomp/GiftOfTheNaaru in order, gated by `ttd_too_short`) appears in **~20 per-playstyle files**. The platform already provides the exact factory for this:

- `create_racial_strategy(opts)` — core.lua:1574-1605. Takes `{ name, prefix, spells = {{action, label}, ...} }`, returns a strategy with `is_burst=true`, `setting_key="use_racial"`, `ttd_too_short` gate, first-ready-wins loop.

**Already adopting it (good):** mage/fire, mage/frost, rogue/{combat,assassination,subtlety}, shaman/{elemental,enhancement}, warlock/{affliction,demonology,destruction} — all call `create_racial_strategy(...)` (verified via grep for `create_racial_strategy(`).

**NOT adopting — hand-rolled, ~25 lines each:**
- `mage/arcane.lua:178-201` — `Arcane_Racial` is a full inline table (matches + execute looping Berserking/ArcaneTorrent), functionally identical to the factory output but with an extra `state.is_burning` gate.
- `paladin/holy.lua`, `paladin/retribution.lua`, `paladin/protection.lua` — each carries a `Racial` strategy (grep: `use_racial` + racial `Show` in all three).
- `priest/holy.lua`, `priest/smite.lua`, `priest/discipline.lua` — each carries one.
- `hunter/rotation.lua` — racial fired inside the imperative strategy build.

**Recommendation:** migrate the 8 hand-rolled sites to `NS.create_racial_strategy`. mage/arcane needs the factory to accept an optional extra `matches` predicate (or keep a thin wrapper) for its `state.is_burning` gate — that's the only behavioral wrinkle. Net ≈ **200 lines** removed, and racial-priority logic lives in one place.

**Risk L–M:** the factory output is already proven in 5 classes; arcane's burn-gate is the only variance.

---

## 2. Consumable-item Action declarations re-typed in every class.lua — LOW RISK, HIGH VALUE

Every `class.lua` re-declares the same item Actions with the same literal item IDs:

| Action | Item ID | Evidence |
|--------|---------|----------|
| `SuperManaPotion` | 22832 | mage:70, paladin:113, shaman:108 |
| `SuperHealingPotion` | 22829 | mage:71, paladin:114, shaman:110 |
| `MajorHealingPotion` | 13446 | mage:72, paladin:115, shaman:111 |
| `MajorManaPotion` | 13444 | shaman:109 |
| `DarkRune` | 20520 | mage:73, paladin:116, shaman:112 |
| `DemonicRune` | 12662 | mage:74, paladin:117, shaman:113 |
| `HealthstoneMaster` | 22105 | mage:80, paladin:120, shaman:116 |
| `HealthstoneMajor` | 22104 | mage:81, paladin:121, shaman:117 |

These are byte-identical (mage/shaman include the explicit `Click = {...}` form; paladin omits it but the framework infers it). The `register_recovery_middleware` calls then reference `A.SuperManaPotion` etc. — so the *consumers* are already shared, only the *declarations* are copy-pasted. This is exactly the kind of spell-ID grouping the task flags as risky: a wrong item ID copied into one class silently breaks recovery there only.

(Druid additionally has Cat/Bear form-variant consumables — 15 lines — that are genuinely druid-specific and should stay.)

**Recommendation:** add a `NS.register_consumable_actions(A)` (or a plain `NS.CONSUMABLE_ITEM_IDS` table the recovery factory itself can `Create`) in core.lua that injects the standard 8 item Actions into a class's `A` table at class-load. Each class.lua drops ~7 declaration lines. Net ≈ **60 lines** and single-source-of-truth on the item IDs.

**Risk L:** declarations are identical; the framework `Create` call is the same shape. Only caveat: the build's per-class `A` table population timing — confirm core.lua runs before class.lua actions are referenced (load order puts core at slot 4, class at slot 5, so a `NS.register_consumable_actions` called from class.lua is safe).

---

## 3. Three identical General-tab schema sections — LOW RISK

Beyond the already-shared `S.dashboard/burst/debug/trinkets/recovery/mana_recovery`, three more sections are copy-pasted verbatim:

### 3a. "Immunity Learning" slider — `immune_learn_ttl_min` — **9/9 classes**
Byte-identical across all 9 (warrior reformats to multiline tabs but same values):
```lua
{ type = "slider", key = "immune_learn_ttl_min", default = 5, min = 1, max = 60,
  label = "Learned Immunity Memory (min)",
  tooltip = "After a spell is resisted as Immune on a creature, remember it for this long...",
  format = "%d min" },
```
Evidence: `druid/schema.lua:30`, `hunter`, `mage`, `paladin`, `priest`, `rogue/schema.lua:30`, `shaman`, `warlock`, `warrior` (all confirmed identical text via grep `-A1`).

### 3b. "CD Min TTD" slider — `cd_min_ttd` — **9/9 classes**
```lua
{ type = "slider", key = "cd_min_ttd", default = 0, min = 0, max = 60, label = "CD Min TTD (sec)",
  tooltip = "Don't use major CDs (trinkets, racial) if target dies sooner than this...", format = "%d sec" },
```
Evidence: present in all 9 `schema.lua` (rogue/schema.lua:63).

### 3c. Spec-selection dropdown — `playstyle` — **7/9 classes**
The `{ header = "Spec Selection", { dropdown key="playstyle" ... } }` block appears in mage, paladin, priest, rogue, shaman, warlock, warrior (the 7 setting-driven classes). Druid/hunter pick playstyle by stance/none. The *options* differ per class, but the wrapper (header, key, label "Active Spec", tooltip) is identical.

**Recommendation:** add to `common.lua`:
- `Menagerie_SECTIONS.immunity()` — zero-arg, returns the immunity slider section.
- `Menagerie_SECTIONS.cooldowns(opts)` — returns the CD Min TTD slider (+ optionally future cd gates).
- `Menagerie_SECTIONS.spec(options)` — takes the per-class `options` array, returns the standard Spec Selection wrapper.

Net ≈ **120–150 lines** across schemas, and the immunity/TTD tooltips (player-facing prose) get one canonical wording. **Risk L** — these are pure data factories exactly like the 6 already shipped in common.lua; the pattern is established and the schema consumers (ui.lua/settings.lua/core.lua) don't care how the section table was produced.

---

## 4. Interrupt cast-check idiom — MED PAYOFF

The "is the target casting something kickable, and is my interrupt ready" idiom is hand-written in **6 classes**:
```lua
local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
if castLeft and castLeft > 0 and not notKickAble then
    if A.<Interrupt>:IsReady(TARGET_UNIT) then
        return A.<Interrupt>:Show(icon), format("[MW] <Name> - Cast: %.1fs", castLeft)
```
Evidence (the `notKickAble` token count per file): mage:2 (`Counterspell`, middleware.lua:116), paladin:2 (`HammerOfJustice`, :170), priest:2 (`Silence`, :120), rogue:2 (`Kick`, :118), shaman:8 (`Earth Shock` interrupt + nameplate-seek state machine, :202/241), warrior:13 (`Pummel`/`ShieldBash` + Spell Reflection PvE/PvP scanners, :113/321/352/466).

The **simple** form (mage/paladin/priest/rogue) is a clean ~12-line middleware that differs only in: the interrupt Action, the `setting_key`, and an optional energy/rage gate. Shaman and warrior are genuinely more complex (nameplate priority-seeking, stance dancing, reflection) and should stay bespoke.

**Recommendation:** two options, in increasing ambition:
- Minimal: `NS.target_is_interruptible(unit) → castLeft|nil` helper (the `IsCastingRemains` + `notKickAble` line) in core.lua. Used everywhere, including inside shaman/warrior. ~6 callers collapse one line each, plus it documents the framework's 5-return contract in one place.
- Fuller: `NS.register_interrupt_middleware{ name, spell, setting_key, priority, resource_gate }` that emits the simple middleware. Migrates mage/paladin/priest/rogue (4 classes). **Risk M** — must preserve rogue's `Constants.ENERGY.KICK` gate and each class's `priority`.

---

## 5. Trivial HP-threshold defensive middleware — MED PAYOFF, HIGHER RISK

The "fire a defensive when HP ≤ a configurable threshold, threshold 0 disables" shape repeats across **~10 middleware blocks in 5 classes**:
- mage: `Mage_IceBlock` (mw:35, + `hypothermia` gate), `Mage_ManaShield` (mw:60, + `mana_pct≥20` gate)
- paladin: `Paladin_DivineShield` (mw:34, + `forbearance_active` gate), `Paladin_LayOnHands` (mw:59, same gate)
- rogue: `Rogue_EmergencyVanish` (mw:33), `Rogue_Evasion` (mw:58), `Rogue_CloakOfShadows` (mw:83, + magic-debuff gate)
- warlock: `Warlock_DeathCoil` (mw:34, casts on TARGET_UNIT not player)
- warrior: 2 blocks

All share: `if not context.in_combat return false / threshold = settings[key] or 0 / if threshold<=0 return false / if context.hp > threshold return false`, then `if A.X:IsReady(unit) then Show + format("[MW] Name - HP: %.0f%%")`. Verified by `grep "threshold <= 0 then return false"` → 13 hits.

**Recommendation:** `NS.register_hp_defensive{ name, priority, spell, threshold_key, unit (default player), extra_match }`. The `extra_match(context)` callback covers the per-class gates (hypothermia, forbearance, has-magic-debuff, mana floor). **Risk M–H:** each block has a slightly different extra gate and warlock targets the enemy; the factory must take a unit param and an optional predicate. Worth it (~180 lines) but needs careful per-class verification, ideally with the sim harness where applicable.

---

## 6. `is_moving` / `is_mounted` / `combat_time` context block — LOW RISK

In **8/9** `class.lua` `extend_context`, this exact triple appears:
```lua
local moving = Player:IsMoving()
ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
ctx.is_mounted = Player:IsMounted()
ctx.combat_time = Unit("player"):CombatTime() or 0
```
Evidence: mage/class.lua:193-196, rogue:205-207, warlock:247-249, plus hunter:431, priest:218, shaman:312, paladin:318, warrior:308 (`combat_time` line confirmed identical in all 8; the `is_moving`/`is_mounted` pair confirmed identical in mage/rogue/warlock).

`enemy_count` is *almost* shared but parameterized by range only: `MultiUnits:GetByRangeInCombat(N)` with N ∈ {8,10,30} (druid uses `GetByRange(8)`). Evidence: druid:764, paladin:340(8), priest:225(30), shaman:333(30), warrior:311(8), warlock:278(30), rogue:208(10).

**Recommendation:** `NS.apply_common_context(ctx)` in core.lua that sets `is_moving`/`is_mounted`/`combat_time`; each class calls it at the top of `extend_context`. Optionally `NS.set_enemy_count(ctx, range)` for the parameterized count. **Risk L** — pure context-population, no behavioral branch. Saves ~32 lines and centralizes the `IsMoving()` truthiness dance (the `~= nil and ~= false and ~= 0` guard exists because the framework returns mixed types — worth documenting once).

---

## 7. Racial Action declarations — PARTIAL (note the ID variance)

Every class.lua declares racial Actions, but **the IDs are not uniform**, so this is only partly hoistable:
- `BloodFury` 20572 is shared, BUT shaman splits it into `BloodFuryAP` 20572 / `BloodFurySP` 33697 (class.lua:27-28).
- `Berserking` differs by class: rogue 26297 (class.lua:24), hunter 20554 (:28), warrior 26296 (:24), mage/arcane via 26297. These look like the troll Berserking rank chosen per class — **do not collapse blindly.**
- `ArcaneTorrent` differs: rogue 25046, hunter 28730 (energy vs mana/rage variants).
- `Stoneform` 20594, `WarStomp` 20549, `EscapeArtist` 20589, `GiftOfTheNaaru` 28880 are uniform.

**Recommendation:** hoist only the unambiguous racials (`WarStomp`, `Stoneform`, `EscapeArtist`, `GiftOfTheNaaru`, base `BloodFury`) into the same `NS.register_consumable_actions`-style injector as finding #2. Leave `Berserking`/`ArcaneTorrent`/shaman's split `BloodFury*` per-class since the ID genuinely varies. **Risk M** — easy to introduce a wrong-ID regression if the variance isn't respected. Lower priority than #1–3.

---

## 8. Party/raid dispel-scan loop — MED, with caveats

The "check self, then iterate party/raid members, dispel first valid target" loop appears in **mage** (`Mage_RemoveCurse`, middleware.lua:211-241) and **priest** (`Priest_DispelMagic` :133-166 and `Priest_AbolishDisease` :171-204 — two copies). Priest's version is the more complete (handles raid vs party prefix, dead-unit skip). The roster-iteration boilerplate (`prefix = members>5 and "raid" or "party"`, the `for i=1,count` loop, `UnitExists`+`IsDead` guards) is ~15 lines repeated 3×.

**Recommendation:** `NS.scan_dispel_targets(dispel_kind, action)` helper in core.lua returning the first unit with a valid dispellable aura the action can hit (self-first). **Risk M–H** — paladin/shaman use *self-only* cleanse variants (no roster scan), so the helper must support a self-only mode, and the framework's `A.AuraIsValid(unit, "UseDispel", kind)` semantics must be preserved exactly. Modest line savings (~60–90) but it removes a genuinely error-prone loop (the priest copies already diverge slightly from the mage one).

---

## What is already well-factored (do NOT touch)

- **Recovery items** — `register_recovery_middleware` (core.lua:1671): 8/9 classes (all but druid, which needs form-shift wrappers). The factory is comprehensive (healthstone/healing-potion/mana-potion/dark-rune, per-action `require_exists`, label tables, custom priorities). Druid's hand-rolled version is justified by Cat/Bear reshift logic — leave it.
- **Trinkets** — `register_trinket_middleware` (core.lua:1838): 9/9. Burst + defensive, schema-driven via `trinket1_mode`/`trinket2_mode`. Fully shared.
- **Schema SECTIONS** — `dashboard/burst/debug/trinkets/recovery/mana_recovery` (common.lua): 9/9 adoption.
- **`ttd_too_short`** (core.lua:217) and **`create_racial_strategy`/`named`/`create_combat_strategy`** (core.lua:1574-1612) — defined once, locally aliased per spec file (correct Lua perf practice; the per-file `local x = NS.x` lines are not duplication to remove).
- Spec-file header guards (`if A.PlayerClass ~= ... return`, NS-nil checks) — idiomatic boilerplate, not worth a macro.

## Suggested execution order

1. **#3 (schema sections)** and **#2 (consumable actions)** first — pure-data, byte-identical, lowest risk, immediate single-source-of-truth wins on player-facing tooltips and item IDs.
2. **#1 (racial factory adoption)** — biggest line win, factory already battle-tested; do mage/arcane last (burn-gate wrinkle).
3. **#6 (common context helper)** — trivial.
4. **#4 (interrupt helper)** — start with the read-only `target_is_interruptible` helper, defer the full middleware factory.
5. **#5 (HP-defensive factory)** and **#8 (dispel scan)** — highest behavioral variance; gate behind sim/manual verification.
