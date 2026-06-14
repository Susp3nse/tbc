# Shared-Code DRY & Readability Pass — Implementation Plan

- **Date:** 2026-06-14
- **Status:** Ready to execute (derived from `2026-06-14-dry-readability-design.md`; Decision D1 = B)
- **Companion design doc:** `2026-06-14-dry-readability-design.md` (the "what & why"). This doc is the "how" — junior-proof numbered steps.
- **Audit status:** The P3 recovery audit and P4 racial audit were performed up front and are baked into §A/§B below as **verified tables** (real keys, defaults, line numbers). No step depends on an unaudited assumption.

---

## How to use this plan

- **Phases are context-window-sized.** Do one phase (or labeled sub-phase) per working session. Each ends at a build-green checkpoint. Do **not** start the next sub-phase in the same session if context is getting long — stop at the checkpoint.
- **Every step has two gates** (full definitions in design doc §4):
  - **Gate A (before):** confirm the duplication/issue still exists at the cited line; confirm the change is actually needed.
  - **Gate B (after):** `build` green + `lint:lua` clean on touched files + (dispatch-path phases) `sim:hunter` identical before/after + **articulated behavioral equivalence** (say *why* old≡new) + dev_revision bump for in-game smoke.
- **The bar for refactor phases is byte-identical runtime behavior.** A diff that builds but changes a log string, a guard order, or a firing threshold is a FAIL. **Exception — P3 recovery is an intentional "unify + normalize" phase, not a pure refactor:** it standardizes a small, explicitly-listed set of recovery-behavior divergences to one common behavior (see "Deliberate normalizations" under §A). Those listed changes are *expected*; any change **not** on that list is still a FAIL. P1, P2, P4, and P5/R-a remain strict byte-identical.
- **Commands:**
  - Build: `corepack pnpm --filter @flux/tbc-rotation build`
  - Lua lint: `corepack pnpm --filter @flux/tbc-rotation lint:lua`
  - Sim: `corepack pnpm --filter @flux/tbc-rotation sim:hunter`
- **Independent re-review:** after each phase's diff is ready, a reviewer who did not write it confirms Gate B item 4 before it reaches the owner.

## ⚠️ Corrections to the design doc (from the up-front audit)

The design doc's Decision D1.1 table was explicitly tentative ("the P3a audit produces the authoritative map"). The audit is done; these supersede it:

1. **Canonical mana-rune key = `use_dark_rune` / `dark_rune_pct`** (majority convention), NOT `use_mana_rune`/`mana_rune_pct`. Renaming the minority is lower churn + smaller migration surface. **Only Hunter (rune keys) and Druid (`_mana`→`_pct` suffix) get migrated.**
2. **Druid is excluded from the middleware factory (F2).** Druid has no standalone `Druid_Healthstone`/`Druid_HealingPotion` middleware — recovery is embedded in form-aware `RecoveryItems`/`ManaRecovery` combined middleware (`druid/middleware.lua:183-352`). Migrating it would mean restructuring form logic = out of scope / over-reach. **Druid keeps its bespoke recovery middleware; only its schema keys are normalized (F3 + suffix migration).** F2 therefore covers **8 classes**.
3. **Mage's `Mage_ManaGem` stays bespoke** (mage-unique item); the recovery factory's mana config is optional and does not absorb it.
4. **Recovery is "unify + normalize," not parameterize-every-difference** (review audit + owner decision 2026-06-14). The blocks diverge on 6 axes, but they split cleanly into **per-class DATA** (prefix/log strings, hp_default, pct defaults, Healthstone Action tier list — pure values, no branching) and **behavior** (stealth guard, `in_combat` guard, `:IsExists()` gating, `dark_rune_min_hp`). The behavior axes are **accidental drift**, so we **standardize them to one common behavior** rather than preserve per-class flags — making the factory pure data-driven (like `register_trinket_middleware`). See "Deliberate normalizations" in §A for the exact behavior changes. This is why P3 recovery is exempt from the byte-identical bar.
5. **Racial counts corrected** (review audit). The design doc's "~20 playstyle files" is the raw racial *site* count; the *clean-fit* count is **12** (mage×3, rogue×3, warlock×3, shaman×3). **Priest×3 is now audited → bespoke** (no TTD gate + availability guards), joining the 3 paladin outliers. F2 covers **8 classes** (druid excluded) — where the design doc still says "9 classes" / "classes 6-9," the plan supersedes it.

---

## §A. Recovery audit (verified) — drives P3

### A.1 Healthstone + Healing Potion (standalone middleware)
8 classes have standalone named middleware with the **same shape**. Druid is embedded (excluded from F2).

| Class | Healthstone mw | HS gate | Healing Potion mw | HP gate | HP default |
|-------|----------------|---------|-------------------|---------|-----------|
| hunter | `Hunter_Healthstone` (mw:64) | `healthstone_hp or 0`, +`IsStealthed` guard | `Hunter_HealingPotion` (mw:89) | `use_healing_potion`+`healing_potion_hp` | 35 |
| mage | `Mage_Healthstone` (mw:131) | `healthstone_hp or 0` | `Mage_HealingPotion` (mw:156) | same | 25 |
| warlock | `Warlock_Healthstone` (mw:55) | `healthstone_hp or 0` | `Warlock_HealingPotion` (mw:80) | same | 25 |
| paladin | `Paladin_Healthstone` (mw:81) | `healthstone_hp or 0` | `Paladin_HealingPotion` (mw:106) | same | 25 |
| warrior | `Warrior_Healthstone` (mw:437) | `healthstone_hp or 0` | `Warrior_HealingPotion` (mw:462) | same | 25 |
| priest | `Priest_Healthstone` (mw:211) | `healthstone_hp or 0` | `Priest_HealingPotion` (mw:236) | same | 25 |
| shaman | `Shaman_Healthstone` (mw:257) | `healthstone_hp or 0` | `Shaman_HealingPotion` (mw:282) | same | 25 |
| rogue | `Rogue_Healthstone` (mw:134) | `healthstone_hp or 0` | `Rogue_HealingPotion` (mw:159) | same | 25 |
| **druid** | **embedded `RecoveryItems` mw:183** | `use_healthstone`+`healthstone_hp` | embedded | `use_healing_potion`+`healing_potion_hp` | — |

> **Gate A note for P3a (the blocks are NOT "identical except prefix" — but the divergences split into DATA vs BEHAVIOR):** read each of the 8 standalone blocks and classify every divergence. The audit found **6 axes**:
> - **DATA (per-class — pass as values, no branching):**
>   1. **prefix** — middleware names + `[MW]` log strings.
>   2. **healing-potion `hp_default`** — hunter 35, others 25.
>   3. **Healthstone Action tier list** — hunter `{HSMaster1, HSMaster2, HSMaster3}`; warlock `{HealthstoneFel, HealthstoneMaster, HealthstoneMajor}` (Fel tier); other 6 `{HealthstoneMaster, HealthstoneMajor}`.
> - **BEHAVIOR (accidental drift → NORMALIZE to one standard; see "Deliberate normalizations" below):**
>   4. **stealth guard** — currently hunter Healthstone only → **make uniform (all classes).**
>   5. **`in_combat` guard** — currently all except hunter → **make uniform (all classes, incl. hunter).**
>   6. **`:IsExists()` Action guard** — currently paladin+shaman only → **make uniform (all classes).**
>
> Because the behavior axes are standardized (not parameterized), the factory carries **only the DATA axes as opts** — it stays pure data-driven like `register_trinket_middleware`, with the 3 standard behaviors baked into its body. Verify the exact `[MW] ...` log strings (e.g. `format("[MW] Healthstone - HP: %.0f%%", context.hp)`) match per class — those stay identical.

> ### Deliberate normalizations (P3 recovery is exempt from byte-identical — these are the *only* allowed behavior changes)
> P3 recovery intentionally standardizes the general recovery system to one common behavior. Every item below is an **expected** behavior change; anything else is still a FAIL. Verified manually in-game (no automated harness — see P3a′).
> 1. **Stealth guard → all classes.** Skip recovery items while `context.is_stealthed` (already computed each frame, so free). Today only hunter does this; rogue/druid gain it (don't break stealth with a healthstone), others are unaffected (can't stealth).
> 2. **`in_combat` guard → all classes (incl. hunter).** Recovery only fires in combat. Today hunter alone could pop recovery out of combat; this aligns it with the other 7.
> 3. **`:IsExists() and :IsReady()` → all consumable Actions.** The framework's `IsReady` does **not** guarantee an item-existence check (`docs/api/method_types.lua`: `IsReady` = "full ready check"; `IsExists` = "item available" — separate; `core.lua:337` relies on this split). Majority (druid/shaman/paladin) already guard; standardize the safe/defensive pattern everywhere. Harmless where redundant; closes a "fire a recovery for an item not in bags" hole where not.
> 4. **Hunter rune gains the `dark_rune_min_hp` gate (default 50).** Hunter's "mana rune" *is* the dark/demonic rune (drains health for mana). It currently has no HP floor — a latent self-damage hole. Normalizing the rune behavior fixes it. (This is also why §A.2's hunter row picks up `dark_rune_min_hp`.)

### A.2 Mana recovery (standalone middleware)
| Class | Mana middleware present | Keys used |
|-------|------------------------|-----------|
| hunter | `Hunter_ManaRune` (mw:116) — DarkRune→DemonicRune | **`use_mana_rune` / `mana_rune_mana`** ⟵ rename |
| mage | `Mage_ManaGem`(183, **bespoke-keep**), `Mage_ManaPotion`(212), `Mage_DarkRune`(236) | `use_mana_gem`/`mana_gem_pct`, `use_mana_potion`/`mana_potion_pct`, `use_dark_rune`/`dark_rune_pct` |
| warlock | `Warlock_ManaPotion`(181), `Warlock_DarkRune`(205) | `use_mana_potion`/`mana_potion_pct`, `use_dark_rune`/`dark_rune_pct` |
| paladin | `Paladin_ManaPotion`(133), `Paladin_DarkRune`(157) | same as warlock |
| priest | `Priest_ManaPotion`(287), `Priest_DarkRune`(311) | same |
| shaman | `Shaman_ManaPotion`(309), `Shaman_DarkRune`(336) | same |
| **druid** | embedded `ManaRecovery`(269) | `use_mana_potion`/**`mana_potion_mana`**, `use_dark_rune`/**`dark_rune_mana`** ⟵ suffix rename |
| warrior, rogue | none (no mana) | — |

> **Gate A note for P3a (mana axes the table above doesn't show — audit-found):**
> - **`dark_rune_min_hp` gate (default 50) → standard for ALL rune users, including hunter.** Present today on every mana class's DarkRune block + schema (mage/warlock/paladin/priest/shaman + druid); **hunter currently lacks it**. Per "Deliberate normalization #4," hunter's migrated rune **gains** this gate (it's the same self-damaging dark/demonic rune). So `min_hp` is a uniform standard behavior, not a per-class opt — the only per-class piece is the default value (50 everywhere).
> - **Per-class `dark_rune_pct` defaults (DATA):** mage 50 / warlock 30 / paladin 40 / priest 50 / shaman 50; hunter rune 20 (post-rename).
> - **Per-class `mana_potion_pct` defaults (DATA):** mage 50 / priest 50 / shaman 50 / warlock 30 / paladin 40. Hunter has no mana potion.

### A.3 Authoritative old→new rename map (Decision D1-B, corrected)
Only these keys change. Everything else is already canonical.

| Class | Old key | New (canonical) key | Migration action |
|-------|---------|---------------------|------------------|
| hunter | `use_mana_rune` | `use_dark_rune` | copy value, clear old |
| hunter | `mana_rune_mana` | `dark_rune_pct` | copy value, clear old |
| druid | `mana_potion_mana` | `mana_potion_pct` | copy value, clear old |
| druid | `dark_rune_mana` | `dark_rune_pct` | copy value, clear old |
| druid | `use_healthstone` (bool) | *(drop)* | if `false`, set `healthstone_hp = 0`; clear `use_healthstone`. (Preserves "disabled" intent under the threshold-0 convention.) |

> Note: druid's healthstone-boolean removal only applies **if** druid's schema is normalized to the threshold-0 convention. Druid keeps bespoke *middleware*, so this is optional — see P3 step 7. If druid middleware keeps reading `use_healthstone`, leave the boolean and skip this row. **Decide in P3a; default = keep druid's `use_healthstone` to minimize druid churn.**

---

## §B. Racial audit (verified) — drives P4

**Common skeleton (FITS the factory):** `setting_key = "use_racial"`, `is_gcd_gated = false`, `is_burst = true`, `requires_combat = true`; `matches` = TTD gate then try-each-`IsReady`→true; `execute` = try-each-`IsReady`→Show. Spell list = data.

| File | Spells (in order) | Fits? |
|------|-------------------|-------|
| mage/{fire,frost,arcane} | Berserking, ArcaneTorrent | ✅ |
| rogue/{assassination,combat,subtlety} | BloodFury, Berserking, ArcaneTorrent | ✅ |
| warlock/{affliction,demonology,destruction} | BloodFury, ArcaneTorrent | ✅ |
| shaman/elemental, shaman/restoration | BloodFurySP, Berserking | ✅ |
| shaman/enhancement | BloodFuryAP, Berserking | ✅ (different Blood Fury variant — just data) |
| **priest/{discipline,holy,smite}** | Berserking, ArcaneTorrent (disc:196, holy:293) — but smite:207 differs further | ❌ **does NOT fit — leave bespoke** (audited) |
| **paladin/retribution** | inline `use_racial` check (not setting_key); Stoneform + GiftOfTheNaaru @ `hp<60` | ❌ outlier — leave bespoke |
| **paladin/protection** | Stoneform + GiftOfTheNaaru @ `context.hp<60` | ❌ outlier — leave bespoke |
| **paladin/holy** | Stoneform + GiftOfTheNaaru @ `state.lowest.hp<60` via `safe_heal_cast` | ❌ outlier — leave bespoke |

> **Priest audited → leave bespoke (do NOT migrate):** disc/holy racial blocks have **no TTD gate**, wrap each `IsReady` in `is_spell_available(...)`, and gate combat via an inline `if not context.in_combat` instead of the `requires_combat`/`is_burst` flags; smite diverges further (inline `use_racial`, `matches` returns true and probes only in `execute`). The common factory (mandatory TTD gate, no availability guard, flag-based combat gate) **cannot absorb them without changing behavior** — migrating priest would silently *add* a TTD gate and *drop* the availability guards. Honor the "leave outliers bespoke" principle.

**Verdict (corrected count):** **12 files fit cleanly** — mage×3, rogue×3, warlock×3, shaman×3. (The earlier "~14–17" was overstated.) **Priest×3 and paladin×3 stay bespoke.** Of ~18 racial sites, 12 fit = ~67% → clears the ">half fit" bar, so **P4 proceeds** with priest **and** paladin excluded. (Hunter has no standalone racial strategy — its racial is inline in `hunter/rotation.lua`; warrior's racial is middleware `Warrior_Racial` — both correctly out of scope.)

---

## Phase P1 — TTD predicate (F1)

**Goal:** replace 40 copies of the TTD gate with one predicate. **Files:** `core.lua` + 16 files (mage×3, paladin×2, rogue×3, shaman×3, warlock×3, warrior/middleware, core trinket factory).

1. **Gate A:** `grep -rn "context.ttd < min_ttd" apps/tbc-rotation/src/aio` → confirm 40 hits / 16 files still present.
2. In `core.lua`, after the spell-cost utilities (~line 225), add:
   ```lua
   -- TTD gate: true when target will die sooner than the user's cd_min_ttd setting
   -- (so callers can skip major CDs on dying mobs). 0 = disabled.
   local function ttd_too_short(context)
      local min_ttd = context.settings.cd_min_ttd or 0
      return min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd
   end
   NS.ttd_too_short = ttd_too_short
   ```
   ⚠️ Read `cd_min_ttd` *inside* the function (never capture at load). Returns truthy/falsey identical to the inline expression.
3. At each of the 40 sites, replace the two lines:
   ```lua
   local min_ttd = context.settings.cd_min_ttd or 0
   if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
   ```
   with:
   ```lua
   if NS.ttd_too_short(context) then return false end
   ```
   - Where a file already aliases NS handles, prefer a local `local ttd_too_short = NS.ttd_too_short` at the top and call bare. Match each file's existing aliasing idiom (don't introduce a new one).
   - In `core.lua`'s own trinket factory, the inline gate is at **lines 1185-1186** (the cited 1188 is the trinket `IsReady` line) — `ttd_too_short` is in scope as a file-level local there, so call it directly. Re-grep to confirm before editing.
   - **Watch:** some sites keep `min_ttd` for other uses (e.g. paladin/ret:153 uses it only for this gate — safe). Grep each site's surrounding ~5 lines; if `min_ttd` is used again below, keep the local and only replace the `if`. (Audit: ret only uses it for the gate.)
4. **Gate B:**
   - `grep -rn "context.ttd < min_ttd"` → returns **0** (predicate uses `context.ttd < min_ttd`? No — predicate body has it; so expect exactly **1** hit: the definition. Confirm only the def remains.)
   - `build` green; `lint:lua` clean across 16 files (watch for now-unused `min_ttd` locals → luacheck will flag; remove them).
   - `sim:hunter` runs (hunter has no TTD sites — null check that nothing else broke).
   - Equivalence: predicate returns the same boolean as the inline expression for all inputs incl. the `min_ttd<=0` disable path and `context.ttd == nil`.
5. dev_revision bump on touched classes; in-game smoke.

**Window fit:** one session.

---

## Phase P2 — Force/burst gating helper (F4)

**Goal:** single source of truth for force/burst-block computation. **File:** `main.lua` only.

1. **Gate A:** confirm `main.lua:84-95` (middleware loop) and `main.lua:164-177` (strategy loop) still hold the duplicated `forced`/IsReady-recheck/`burst_blocked` logic.
2. Add a module-level local in `main.lua` (near other helpers, before `execute_middleware`):
   ```lua
   -- Resolve force-bypass + auto-burst gating for a middleware/strategy entry.
   -- Returns: forced (bool), burst_blocked (bool). default_target differs per loop
   -- (middleware defaults to "player", strategies to TARGET_UNIT).
   local function resolve_forced(entry, context, default_target)
      local forced = (context.force_burst and entry.is_burst)
                  or (context.force_defensive and entry.is_defensive)
      -- Safety: even when forced, the spell must still be ready (CD, range, stance)
      if forced and entry.spell then
         if not entry.spell:IsReady(entry.spell_target or default_target) then forced = false end
      end
      local burst_blocked = entry.is_burst and (not forced) and context.auto_burst == false
      return forced, burst_blocked
   end
   ```
3. In `execute_middleware` (84-95), replace the inline block with:
   ```lua
   local forced, burst_blocked = resolve_forced(mw, context, "player")
   local setting_ok = forced or not mw.setting_key or context.settings[mw.setting_key]
   local matches = setting_ok and not burst_blocked and (forced or mw.matches(context))
   ```
   (Keep the surrounding `for`/gcd guard and the downstream use of `forced` in logging unchanged.)
4. In `execute_strategies` (164-177), replace the inline block with:
   ```lua
   local forced, burst_blocked = resolve_forced(strategy, context, TARGET_UNIT)
   local passes = not burst_blocked and (forced or (
      self:check_prerequisites(strategy, context)
      and (not config_prereqs or config_prereqs(strategy, context))
      and (not strategy.matches or strategy.matches(context, state))
   ))
   ```
5. **Gate B:**
   - Verify `force_burst`/`force_defensive`/`auto_burst` are read off `context` inside the helper (they are hoisted onto context at main.lua:289-291) — so the helper needs no extra params beyond entry/context/default_target. Confirm the two loops previously read the same `context.*` (they read locals `force_burst` etc. that alias `context.force_burst` — equivalence holds).
   - `build` green; `lint:lua` clean.
   - `sim:hunter` output **byte-identical** before/after (capture before editing).
   - Equivalence statement: `forced`, the IsReady re-check (with correct per-loop default target), and `burst_blocked` are computed identically; only the default target differs, preserved via the param.
6. dev_revision bump (any one touched class is enough — this is shared); in-game smoke: `/flux burst` and `/flux def` still fire tagged entries; auto-burst still gated.

**Window fit:** one session.

---

## Phase P3 — Recovery: standardize keys + factories + migration (F2 + F3, D1-B)

> Strict order: **P3a → P3a′ → P3b → P3c.** Druid is NOT in the middleware factory. Mage ManaGem stays bespoke.

### P3a — Build factories (no class wired, no rename)
1. **Gate A:** re-read the 8 standalone Healthstone/HealingPotion blocks (§A.1) + the mana blocks (§A.2); confirm shapes match the audit. Lock the canonical vocabulary (§A.3) and the §A.3 druid decision (default: keep druid `use_healthstone`).
2. In `common.lua`, add `S.recovery(opts)` and `S.mana_recovery(opts)` mirroring `S.trinkets` (return `{ header=..., settings={...} }`). They emit **canonical** keys: `healthstone_hp`, `use_healing_potion`, `healing_potion_hp` (+ optional mana: `use_mana_potion`/`mana_potion_pct`, `use_dark_rune`/`dark_rune_pct`/**`dark_rune_min_hp`**). `opts` carries per-class defaults (e.g. hunter `healing_potion_hp` default 35, `dark_rune_min_hp` default 50) and which sub-settings to include. **Note:** hunter's schema now gains `dark_rune_min_hp` (default 50) as part of normalization #4 — it didn't have one before.
3. In `core.lua`, add `register_recovery_middleware(opts)` next to `register_trinket_middleware` (read `NS.A`, register via `rotation_registry:register_middleware`). **`opts` is pure DATA** — the 3 behavior axes (stealth guard, `in_combat` guard, `:IsExists()` gating) are **standardized in the factory body**, not parameterized (see "Deliberate normalizations"). So `opts` carries only:
   - `prefix` (e.g. `"Hunter"`) → middleware names + `[MW]` log prefixes must reproduce existing strings.
   - `healthstone = { actions = { A.HealthstoneFel?, A.HealthstoneMaster, A.HealthstoneMajor } }` — per-class tier list (hunter `{HSMaster1,2,3}`, warlock has the Fel tier, others 2-tier).
   - `healing_potion = { hp_default = 35|25, actions = {A.SuperHealingPotion, A.MajorHealingPotion} }`.
   - `mana = nil | { potion = { pct_default = N }, rune = { actions = {A.DarkRune, A.DemonicRune}, pct_default = N } }` — optional; absent for warrior/rogue. Per-class `pct_default`s from the §A.2 note (warlock 30, paladin 40, mage/priest/shaman 50; hunter rune 20).
   - **Baked into the factory body (uniform, not opts):** skip if `context.is_stealthed`; require `context.in_combat`; wrap every consumable Action in `:IsExists() and :IsReady(...)`; apply the `dark_rune_min_hp` (default 50) floor to all rune use. These are the deliberate normalizations — they apply to every class the factory wires (hunter included).
   - Reproduce exactly otherwise: priorities (`Priority.MIDDLEWARE.RECOVERY_ITEMS`, `-5`, `MANA_RECOVERY`), thresholds, `combat_time<2` guard, and `[MW] ...` log strings.
4. **No class wired. No key renamed.** `build` green + `lint:lua` clean (factories defined-but-unused is fine).

### P3a′ — Migration shim + test (MUST land before any rename)
5. Implement `migrate_recovery_keys()` in `core.lua` (or a small dedicated block ordered before `refresh_settings`):
   - Iterate the §A.3 rename map. For each `old → new`: if profile has `old` set and `new` unset → `SetToggle({2,new,GetToggle(2,old)})`, then clear `old`.
   - Idempotent; guard with a stored `recovery_keys_migrated` flag (or a version stamp — decide here).
   - Runs **once at load, before `cached_settings` is built**. Never capture gameplay settings at load — this only rewrites the store.
6. **Migration verification — manual, in-game (owner decision 2026-06-14).** `src/sim/` is a TypeScript damage simulator (`hunter-adaptive-sim.ts`); it has **no Lua test harness, no profile/settings fixture, and cannot exercise `GetToggle`/`SetToggle`**. A proper automated migration test requires a Lua mocked-toggle harness — that is **deliberately out of scope here and tracked as its own separate implementation plan** (a general testing-harness effort). For this phase, verify the migration **manually in-game** and write the exact reproduction steps into the phase notes. Because the migration rewrites saved user data with no automated guard, treat this as a **release-blocking checklist item**, not a nice-to-have.
   - **Scenario (manual):** seed a profile with `use_mana_rune=false`/`mana_rune_mana=15` (hunter) and `dark_rune_mana=22` (druid) → `/reload` → confirm `use_dark_rune=false`, `dark_rune_pct=15`, druid `dark_rune_pct=22`, old keys cleared, and a **second `/reload` changes nothing** (idempotent).
   - **Keep the shim frozen and minimal** (it's 4 keys) and make the one-shot guard a hard precondition — the narrower it stays, the less the missing automated test costs.
7. **Druid decision:** default = keep druid `use_healthstone` boolean and its bespoke middleware reading it; only migrate druid's `_mana`→`_pct` suffix keys. (If owner later wants druid normalized, that's a separate follow-up.)
8. `build` green + `lint:lua` + migration manually verified (step 6 scenario).

### P3b — Migrate classes 1–5 (atomic per class: schema + middleware)
9. For **hunter, mage, warlock, paladin, warrior** (order chosen: hunter first since it has the rune rename; warrior is healthstone+potion only):
   - Replace inline recovery schema section with `S.recovery(...)` / `S.mana_recovery(...)` (canonical keys, per-class defaults).
   - Replace the class's standalone recovery middleware blocks with `NS.register_recovery_middleware({ prefix=..., ... })`. **Mage:** leave `Mage_ManaGem` bespoke; only fold Healthstone/HealingPotion/ManaPotion/DarkRune into the factory.
   - **Hunter:** factory `mana = { rune = {A.DarkRune, A.DemonicRune}, pct_default=20 }` reading canonical `use_dark_rune`/`dark_rune_pct` (post-migration). No mana potion. **Hunter picks up the deliberate normalizations** (now `in_combat`-gated, stealth-gated, `:IsExists()`-guarded, and a `dark_rune_min_hp=50` floor) — these are *expected* changes per the normalization list, not regressions.
   - Per class: `build` + `lint:lua` + dev_revision bump. Confirm middleware **names + priorities + log strings unchanged**; the **only** behavior deltas are the listed normalizations (most classes: none observable; hunter: the four above).
10. Checkpoint after class 5: full `build` + `lint:lua` + a profile migration smoke (set old hunter keys, reload, confirm settings preserved + recovery fires).

### P3c — Migrate classes 6–8
11. For **priest, shaman, rogue** identically (rogue = healthstone+potion only; priest/shaman = +ManaPotion+DarkRune).
12. **Druid:** schema key suffix normalization only (`mana_potion_mana`→`mana_potion_pct`, `dark_rune_mana`→`dark_rune_pct`) so its schema matches canonical; **middleware left bespoke**. Confirm druid middleware reads the renamed keys (update the 4 reads at druid/middleware.lua:285,292,314,325) — these are part of druid's atomic step.
13. **Gate B (whole phase):** for every migrated class, registered names/priorities/thresholds/log strings unchanged. Observable changes are limited to (a) renamed keys, made seamless by the shim, and (b) the **Deliberate normalizations** list (stealth/in_combat/IsExists uniform; hunter rune gains `min_hp`). Anything else is a FAIL. `build` + `lint:lua` + full-profile migration smoke + spot-check each class's recovery still fires at its thresholds.

**Window fit:** P3a, P3a′, P3b (5 classes), P3c (3 classes + druid) = four sessions.

---

## Phase P4 — Racial factory, common case only (F5)

> Depends on P1 (uses `ttd_too_short`). Paladin excluded (HP-gated outliers).

1. **Gate A:** confirm the §B audit. **Priest ⚠️ is already resolved → leave bespoke** (no TTD gate + `is_spell_available` guards + inline combat gate; see §B note). The clean-fit set is the **12 files** in §B's ✅ rows (mage×3, rogue×3, warlock×3, shaman×3). 12/18 ≈ 67% clears the ">half fit" bar → proceed. (If a re-read somehow shrinks this below ~half, descope P4 and stop.)
2. In `core.lua`, add:
   ```lua
   -- Build a standard off-GCD racial burst strategy. spells = { {Action, "Label"}, ... }
   -- tried in order. Honors use_racial (setting_key) + the shared TTD gate.
   function NS.create_racial_strategy(opts)
      local prefix, spells = opts.prefix, opts.spells
      return {
         requires_combat = true, is_gcd_gated = false, is_burst = true,
         setting_key = "use_racial",
         matches = function(context)
            if NS.ttd_too_short(context) then return false end
            for i = 1, #spells do if spells[i][1] and spells[i][1]:IsReady(PLAYER_UNIT) then return true end end
            return false
         end,
         execute = function(icon)
            for i = 1, #spells do
               local a = spells[i][1]
               if a and a:IsReady(PLAYER_UNIT) then return a:Show(icon), "[" .. prefix .. "] " .. spells[i][2] end
            end
         end,
      }
   end
   ```
   ⚠️ Verify the existing log prefixes (`[FIRE]`, `[RET]`, `[HOLY]` etc.) — `prefix` must reproduce each playstyle's exact tag, and labels (`"Berserking"`, `"Blood Fury"`, `"Arcane Torrent"`) must match the originals verbatim.
3. Migrate the fitting files (§B ✅ rows) — replace the hand-rolled racial table with `NS.create_racial_strategy({ prefix="FIRE", spells={ {A.Berserking,"Berserking"}, {A.ArcaneTorrent,"Arcane Torrent"} } })`. Keep each strategy's position in its playstyle's strategies array identical.
   - Pre-allocate the `spells` table at load (no inline table creation in combat — these are built once at file load, safe).
4. **Leave bespoke (confirmed by audit):** paladin ret/prot/holy (HP-gated outliers) **and** priest disc/holy/smite (no TTD gate + availability guards). Do **not** add `gate`/`condition`/availability params to force any of these through — that's the over-abstraction trap.
5. **Gate B:** per migrated file, racial firing order + labels + log tags unchanged; `build` + `lint:lua`; dev_revision bumps. If >~12 files migrate, split into two sessions.

**Window fit:** audit + migrations one session (split if large).

---

## Phase P5 — Readability cleanups (R-a, R-b, R-c, R-d)

Four independent commits in one session; any can be dropped.

1. **R-a — drop redundant double-guard.** Gate A: `grep -rn "last_validated_active" apps/tbc-rotation/src/aio` → confirm it's only `main.lua` (def + the 349-352 use). Then in `main.lua`, replace 348-352:
   ```lua
   if active then
      rotation_registry:validate_playstyle_spells(active)   -- core.lua:1004 already no-ops repeats
      local result = rotation_registry:execute_strategies(active, icon, context)
   ```
   Remove the `last_validated_active` local declaration. Gate B: `build`; `sim:hunter` identical; equivalence = core's `last_validated_playstyle` guard makes the unconditional call a no-op on repeats.
2. **R-b — dash_context aliasing comment** (no code change). At `dashboard.lua:737-738`, add:
   ```lua
   -- NOTE: when fresh, dash_context aliases the live reusable rotation context
   -- (NS.last_rotation_context). Treat as READ-ONLY here — writing it corrupts the
   -- next rotation frame within the 0.25s window.
   ```
3. **R-c — derive the magic offset. ⚠️ NOT executable as originally written — rescope or drop.** Audit finding: at `dashboard.lua:845` `content_y = -40` is real, but the 842-845 comment lists `-6 / -18 / -4` as **bare prose magic numbers, not named constants**. The only named value is `RES_BAR_H` (12), and it is a `local` defined inside the **setup** function (~`dashboard.lua:479`) — **not in scope at line 845**. So "derive from named setup-time constants" cannot be done: there are no in-scope named constants, and `6+18+4+12=40` only by dropping the trailing "+ gap" term the comment itself appends (the comment calls -40 "hand-tuned"/"approximating" — deliberately not an exact derivation). The plan's original Gate A ("constants exist and sum to 40") would FAIL on inspection.
   - **Option 1 (drop):** lowest-value of the five items; "actually, leave it" is a fine outcome. Recommended unless the owner wants it.
   - **Option 2 (rescope, only if owner wants it):** first hoist the `-6/-18/-4/RES_BAR_H` values to **named module-level (or shared-scope) constants visible at line 845**, then express `content_y` in terms of them. This is a real (S–M) sub-step, not a one-liner — it must precede the substitution, or you'll reference an out-of-scope local and trip luacheck (accidental global). Gate B: `build`; value must still resolve to -40 today; visually confirm dashboard layout unchanged in-game.
4. **R-d — spell-cost dead code.** Gate A (verified): `get_spell_focus_cost` + `NS.get_spell_energy_cost` have zero callers; `druid/cat.lua:51` defines its own 2-arg energy variant (with `fallback`) and uses that. **⚠️ Line numbers below were re-grepped — the original cite was stale by ~2-3 (the energy helper sits between mana and focus, shifting them); re-grep before deleting, do not trust any single cite.** Action: delete `get_spell_focus_cost` (core.lua **215-218**) + its export (**223**). For `get_spell_energy_cost`/its export (**210-213, 222**): **owner micro-decision** — delete (truly unused) or keep as intentional API. Default recommendation: delete both dead exports; keep `mana`+`rage` (`get_spell_mana_cost` used by paladin+druid; `get_spell_rage_cost` used by druid/bear). Do **not** merge. Gate B: `grep` confirms no remaining callers; `build`; `lint:lua`.

**Window fit:** one session.

---

## Sequencing recap

```
P1 ─┐ (ttd_too_short)
P2 ─┤
P5 ─┤ (independent)
    └─> P4 (needs P1)
D1=B ─> P3a ─> P3a′ ─> P3b ─> P3c
```
Recommended: **P1 → P2 → P5 → P3a → P3a′ → P3b → P3c → P4.**

## Definition of done (whole effort)
- `pnpm check` green; `lint:lua` clean; `build` produces `output/TellMeWhen.lua`.
- `sim:hunter` identical to pre-change baseline for the strict-equivalence phases (P1/P2/R-a touch the dispatch path). (Note: `sim:hunter` is a weak oracle for P4 — hunter has no racial strategy — and N/A for P3 recovery, which is verified manually.)
- Recovery key migration verified **manually in-game** (P3a′ scenario + full-profile smoke); no user setting silently reset. The recovery **Deliberate normalizations** (stealth/in_combat/IsExists uniform; hunter rune gains `min_hp`) are the *only* recovery behavior changes — confirmed against that list, nothing else.
- All "leave alone" items (design doc §9) untouched.
- Each phase independently re-reviewed before reaching the owner: strict byte-identical equivalence for P1/P2/P4/P5-R-a; "changes match the normalization list and nothing else" for P3 recovery.
- Net ~450–500 lines removed; per-class readability preserved.

## Related future work (out of scope here — separate plans)
These came up while finalizing this plan but are **not** part of the DRY/readability pass. Tracked so they aren't lost:
- **General line-of-sight gate** — a shared gate the dispatcher consults before any cast *at a unit*, so the rotation doesn't spam attacks/heals into a target it has no LOS to (relevant to hunter, druid, casters/healers generally). This is **net-new behavior**, not a refactor — it gets its own brief implementation plan. (Quick scoping note: in TBC essentially every spell cast at an enemy or ally needs LOS; instant self-buffs with no target don't, so the gate applies only to unit-targeted casts.)
- **Lua test harness** — a mocked-toggle / in-memory profile-store harness that could actually unit-test `migrate_recovery_keys()` (and other Lua logic). Deliberately deferred (P3a′ uses manual verification instead); it's a complete effort of its own and should be its own plan.
