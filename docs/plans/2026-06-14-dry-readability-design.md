# Shared-Code DRY & Readability Pass — Design Spec

- **Date:** 2026-06-14
- **Status:** Approved; reconciled with the up-front P3/P4 audit. Decision D1 = B (resolved). The audit refined four findings since the original draft — recovery middleware is **unify + normalize** (not parameterize-per-class), **druid is excluded** from the middleware factory (schema/keys only), **priest racials stay bespoke**, and **R-c is rescoped** (not executable as first written). Authoritative audit tables + rename map live in the implementation plan (`2026-06-14-dry-readability-plan.md` §A/§B); this doc is the reconciled "what & why."
- **Goal in one line:** Remove a *bounded, verified* set of mechanical duplications in the AIO Lua and tighten a few readability hotspots — following patterns the codebase already established (`FluxAIO_SECTIONS`, `register_trinket_middleware`) — **without** introducing speculative abstraction or disrupting saved settings.

---

## 1. Motivation & provenance

This spec is the output of a three-agent review (shared-infra reviewer, cross-class reviewer, independent verifier). Every finding below was **fact-checked against the live code by a verifier agent** — line numbers and counts are real, not estimated. Two findings the owner flagged for extra scrutiny were independently re-investigated and **changed** as a result (see §6 — double-guard confirmed; spell-cost helpers reframed).

The architecture itself rated **8/10** from both reviewers independently. This is *not* a redesign. It is the small set of mechanical patterns that escaped the shared-factory net the codebase already uses, plus four cheap readability wins. Estimated net reduction: **~450–500 lines**, with **no loss of per-class readability**.

## 2. Principles (the guardrails for this work)

- **DRY, but locality wins ties.** Hoist only patterns with *zero class-identity value*. Anything that is class-specific (dispels, spell lists, mechanics) stays local — even if it looks duplicated. The reviews explicitly listed "leave alone" items (§9); honor them.
- **No hyper-optimization.** If a change trades readability or safety for cleverness or a few lines, we don't do it. The boring, obvious helper wins.
- **No silent behavior change.** Saved user settings, log strings users may rely on, and firing conditions must not change unless a change is the *explicit* point of a phase and is called out.
- **One phase = one context window.** Each phase is scoped so a single agent can complete *and verify* it without spanning context windows (which is where drift creeps in). Phases too big for one window are pre-split here with a clean, build-green checkpoint between sub-phases.
- **Every fix is double-gated:** before doing it, confirm it's *actually needed* (the "needed?" gate); after doing it, confirm it *did what it claimed and added no new bug* (the "correct?" gate). See §4.

## 3. Scope

**In scope** (owner-approved findings):

| ID | Finding | Effort | Confidence | Phase |
|----|---------|--------|-----------|-------|
| F1 | TTD-gate one-liner duplicated 40× / 16 files → one predicate | S | High | P1 |
| F4 | Force/burst gating duplicated across the two dispatch loops → one helper | S–M | High | P2 |
| F3 | Recovery **schema** sections inline in all 9 → `S.recovery()` / `S.mana_recovery()` (canonical keys; druid included — schema/key normalization only) | M | High | P3 |
| F2 | Recovery **middleware** re-rolled in **8 classes** (druid bespoke) → `register_recovery_middleware()` — a **unify + normalize** pass, not a pure refactor (see §7 P3) | M | High | P3 |
| F2/F3-migration | Standardize recovery keys + saved-settings migration shim (Decision D1-B) | **L** | High | P3 (P3a′) |
| F5 | Racial strategy skeleton across ~18 sites → `create_racial_strategy()` (common case only); **12 fit cleanly** — priest×3 + paladin×3 stay bespoke | M | **Medium** | P4 |
| R-a | Redundant double-guard on `validate_playstyle_spells` → drop the outer tracker | S | High | P5 |
| R-b | `dash_context` may alias live rotation context → add read-only warning comment | S | High | P5 |
| R-c | `update_dashboard` magic offset `content_y = -40` → ~~derive from named constants~~ **not executable as written → rescope or (recommended) drop** (§6, §7 P5) | M | Low | P5 |
| R-d | "Four identical spell-cost helpers" → **reframed**: dead-code decision, NOT a merge | S | High | P5 |

**Out of scope / deliberately NOT touched** — see §9. Includes the `try_heal_cast`/`try_cast` split, `warrior/middleware.lua`'s size, dispel/cure middleware, and module preambles. These were reviewed and judged "leave local."

## 4. Verification protocol (applies to every phase)

Each phase carries **two gates**. A phase is not "done" until both pass.

### Gate A — "Was this actually needed?" (run *before* writing code)
- Re-confirm the duplication/issue still exists at the cited file:line (code drifts).
- Confirm the change removes real duplication or a real defect — not cosmetic churn.
- If the audit reveals the premise is weaker than stated (as happened with R-d), **stop and re-scope** rather than forcing the change.

### Gate B — "Is it correct and bug-free?" (run *after* writing code)
1. **Build:** `corepack pnpm --filter @flux/tbc-rotation build` must succeed (compiles to `output/TellMeWhen.lua`).
2. **Lua lint:** `corepack pnpm --filter @flux/tbc-rotation lint:lua` (luacheck) — catches accidental globals, typo'd API names, unused/shadowed locals. Must be clean for files touched.
3. **Sim (where applicable):** `pnpm --filter @flux/tbc-rotation sim:hunter` for any change touching the hunter dispatch path (P1, P2). The sim is a regression oracle — a passing sim before/after with identical output proves no behavior change.
4. **Behavioral equivalence proof** — the anti-new-bug gate. For "pure refactor" phases (P1, P2, P4, R-a), the bar is **byte-identical runtime behavior**. The reviewer/verifier must articulate *why* the new code is equivalent to the old (same inputs → same outputs, same firing order, same log strings), not just "it builds." A diff that builds but changes a log string or a guard order is a FAIL.
5. **In-game smoke (owner):** bump the touched class `dev_revision` so a `/reload` confirms the active build; spot-check the affected class still casts as before.

### Independent re-review
After each phase's diff is ready, it goes through a **fresh review pass** (a reviewer agent that did not write it) checking Gate B item 4 specifically: "does this diff change any observable behavior?" Only then does it reach the owner. This mirrors the review→verify→synthesize loop that produced this doc.

## 5. Decision D1 — RESOLVED: Standardize + migrate (Option B)

> **Owner decision (2026-06-14): Option B — standardize the recovery keys to one vocabulary and add a saved-settings migration shim.** (Recommendation had been A; owner chose B for long-term key consistency. Recorded and designed below.)

The recovery middleware looks identical across classes, but the **setting keys differ**. Verified:
- Hunter (`hunter/schema.lua:46-49`, `hunter/middleware.lua:120-123`): `use_mana_rune` / `mana_rune_mana`.
- Mage (`mage/schema.lua`, `mage/middleware.lua:235+`): `use_dark_rune` / `dark_rune_pct`, plus a separate `use_mana_potion` / `mana_potion_pct`.

Option B means: pick canonical key names, rename every class to them, and migrate users' saved values so nobody's config silently resets. This is **higher effort and higher risk than A** — it touches saved user data — so P3 grows a migration sub-phase and a release-blocking migration verification step (§7, §10; verified manually in-game, as no Lua harness exists). The payoff is a single uniform key vocabulary that the factory can assume.

### D1.1 — Canonical key vocabulary (AUDITED — see plan §A.3 for the authoritative map)
The up-front audit (done before the plan was written) **corrected the original proposal**: the majority convention is `use_dark_rune`/`dark_rune_pct` (5–6 classes), so we standardize to *that* and rename only the minority — far less churn than renaming 6 classes to `use_mana_rune`.

| Concern | Canonical key(s) | Renames needed |
|---------|------------------|----------------|
| Healthstone | `healthstone_hp` | none (uniform) — druid's extra `use_healthstone` bool kept (druid stays bespoke) |
| Healing potion | `use_healing_potion`, `healing_potion_hp` | none (uniform) |
| Mana **rune** (Dark/Demonic Rune) | `use_dark_rune`, `dark_rune_pct` | **Hunter:** `use_mana_rune→use_dark_rune`, `mana_rune_mana→dark_rune_pct`. **Druid:** `dark_rune_mana→dark_rune_pct` |
| Mana **potion** | `use_mana_potion`, `mana_potion_pct` | **Druid:** `mana_potion_mana→mana_potion_pct` |

> **Authoritative rename map + per-class audit tables live in the plan (`2026-06-14-dry-readability-plan.md` §A).** Two corrections the audit forced: (1) canonical rune key is `dark_rune` not `mana_rune`; (2) **Druid is excluded from the recovery middleware factory** (its recovery is embedded in form-aware middleware) — only its schema keys are normalized. The recovery middleware factory therefore covers **8 classes**, and Mage's `ManaGem` stays bespoke.

### D1.2 — Migration shim design
Saved settings live in the framework profile store, read/written via `GetToggle(2, key)` / `SetToggle({2, key, ...})` and surfaced through `cached_settings` (built by `refresh_settings` in `core.lua`).

- **Mechanism:** a one-time `migrate_recovery_keys()` that runs **once at load, before `refresh_settings` builds `cached_settings`**, iterating the rename map: for each `old → new`, if the stored profile has a value for `old` and not for `new`, copy it to `new` and clear `old`. Idempotent (clearing `old` means a second run is a no-op).
- **Placement:** the migration must run after the profile store exists but before settings are cached. Exact hook point is a P3a design step (candidate: a guarded call early in `core.lua`'s settings init, or a dedicated migration block ordered before `refresh_settings`). **No setting may be read at load and captured** — the migration writes the store, it does not capture gameplay settings.
- **One-shot guard:** a stored `recovery_keys_migrated` flag (or version stamp) so the migration is attempted once per profile, not every load. Decide flag-vs-version in P3a.
- **Safety:** "copy only if `new` is unset" guarantees we never clobber a value a user already set under the new key (e.g. after a partial rollout).

### D1.3 — New consequences vs Option A (must be honored)
- P3 effort rises **M → L**; it gains sub-phase **P3a′ (migration shim + test)**.
- **New Gate B requirement:** migration verification — seed a profile with old keys at non-default values, run the migration, confirm new keys hold those values, old keys are cleared, and a second run is a no-op. **There is no Lua test harness today** (`src/sim/` is a TypeScript damage sim and cannot exercise `GetToggle`/`SetToggle`), so this is verified **manually in-game** and treated as a release-blocking checklist item. A mocked-toggle Lua harness that could automate it is deferred to its own plan.
- Per-class landing stays **atomic** (schema + middleware + the class's slice of the rename map move together), but the migration shim itself must land in P3a′ **before** any class is renamed, or the first renamed class loses settings on the first reload.

## 6. The flagged / re-investigated findings

The owner asked to verify the double-guard "actually has a double guard," and flagged the spell-cost helpers as needing more investigation; a third item (R-c) collapsed under the plan's up-front audit. All were re-checked directly against code:

### R-a — Double-guard: **CONFIRMED redundant.**
- `main.lua:349-352` wraps the validate call in `if active ~= last_validated_active then ... last_validated_active = active end`.
- `core.lua:1003-1005` *already* opens `validate_playstyle_spells` with `if playstyle == last_validated_playstyle then return end`.
- Two independent change-trackers for one concern. The outer one (`last_validated_active`) is dead weight; core's guard already no-ops repeat calls. Note the outer tracker also only covers the *active* playstyle, so the two can subtly track different things — benign today, latent confusion.
- **Action:** delete the `last_validated_active` local + its `if` wrapper; call `validate_playstyle_spells(active)` unconditionally. **Plan must grep `last_validated_active` for any other reader before removal** (Gate A).

### R-d — "Four identical spell-cost helpers": **PREMISE WAS WRONG — reframed.**
Investigation result (verified): the four helpers at `core.lua:202-220` are *not* four live duplicates worth merging:
- `get_spell_mana_cost` — **used** (paladin, druid). Keep.
- `get_spell_rage_cost` — **used** (druid/bear). Keep.
- `get_spell_energy_cost` (the `NS` export) — **zero external callers.** `druid/cat.lua:51` deliberately defines its *own* variant with a `fallback` param (different signature) and uses that.
- `get_spell_focus_cost` — **zero callers anywhere.** Effectively dead.

So this is **not a DRY-merge** (merging two used helpers + two dead ones into one clever private function is exactly the over-abstraction the repo rejects). The honest finding is **dead-code hygiene**:
- **Action (recommended):** delete `get_spell_focus_cost` (definitely dead) and its `NS` export. Flag the `NS.get_spell_energy_cost` export for a keep-or-remove decision (dead today, but cheap, and "spell cost by power type" is a plausible intentional API surface). Leave `mana`/`rage` untouched. Do **not** merge.
- This is the smallest item and the one most likely to be "actually, just leave it" — that's a fine outcome.

### R-c — Magic offset: **NOT executable as designed.**
The plan's up-front audit found `dashboard.lua:845` `content_y = -40` is real, but the 842-845 "keep in sync" comment lists `-6 / -18 / -4` as **bare prose numbers, not named constants**. The only named value (`RES_BAR_H` = 12) is a `local` scoped inside the dashboard *setup* function (~`dashboard.lua:479`) — **not in scope at line 845** — and `6+18+4+12 = 40` only by dropping the trailing "+ gap" term the comment itself calls "hand-tuned." So "derive from named constants" cannot be done as written: there are no in-scope named constants to derive from.
- **Recommended: drop it** — lowest-value of the five readability items; "leave it" is a fine outcome.
- **If the owner still wants it:** first hoist `-6/-18/-4/RES_BAR_H` to named constants visible at line 845 (a real S–M sub-step), *then* express `content_y` in terms of them. Not a one-liner.

## 7. Phase breakdown (each phase = one context window)

> Ordered by ascending risk-of-drift and to front-load the highest-confidence, most-independent wins. P1, P2, P5 are independent of each other and of P3/P4. P3 and P4 share Decision D1 and are sequenced together.

### Phase P1 — TTD predicate (F1) · *High confidence · ~1 window*
- **Files:** `core.lua` (add helper) + 16 files with the gate (mage×3, paladin×2, rogue×3, shaman×3, warlock×3, warrior/middleware, and the core trinket factory itself). 40 call sites verified.
- **Change:** add `function NS.ttd_too_short(context) ... end` near the spell-cost utilities in `core.lua`. Replace each site:
  ```lua
  -- before
  local min_ttd = context.settings.cd_min_ttd or 0
  if min_ttd > 0 and context.ttd and context.ttd > 0 and context.ttd < min_ttd then return false end
  -- after
  if NS.ttd_too_short(context) then return false end
  ```
- **Design note:** the predicate must read `context.settings.cd_min_ttd or 0` *inside* itself (never capture at load — see hard constraints). It is called in hot paths but is a handful of comparisons; no allocation. Behavior must be **identical** including the `min_ttd > 0` disable path.
- **Risk:** low logical, but it's a wide mechanical edit (16 files). Main risk is a missed/garbled site. Mitigation: after edit, `grep` for the old pattern must return **only** the predicate definition.
- **Gate B emphasis:** sim:hunter unaffected (hunter has no TTD gate sites — good null check), build + luacheck across all 16, and the grep-residue check.
- **Window fit:** comfortably one window; mechanical.

### Phase P2 — Force/burst gating helper (F4) · *High confidence · ~1 window*
- **Files:** `main.lua` only (`execute_middleware` 84-95, `execute_strategies` 164-177).
- **Change:** extract a local helper:
  ```lua
  -- returns: forced (bool), burst_blocked (bool)
  local function resolve_forced(entry, context, default_target)
     local forced = (context.force_burst and entry.is_burst)
                 or (context.force_defensive and entry.is_defensive)
     if forced and entry.spell then
        if not entry.spell:IsReady(entry.spell_target or default_target) then forced = false end
     end
     local burst_blocked = entry.is_burst and (not forced) and context.auto_burst == false
     return forced, burst_blocked
  end
  ```
  Call with `default_target = "player"` (middleware) and `default_target = TARGET_UNIT` (strategies). Strategy loop keeps folding in `check_prerequisites`/`config_prereqs`/`matches` itself; middleware keeps its own `setting_ok`. The helper only owns the force/burst-block computation that is currently duplicated verbatim.
- **Why needed:** this is **correctness-sensitive** — burst semantics live in two copies today and can drift silently. Single source of truth is the real payoff (more than the ~10 lines saved).
- **Design note:** helper is a module-level local in `main.lua` (not on the hot per-frame path beyond what's already there; same work, one place). No new allocation.
- **Gate B emphasis:** byte-identical behavior is the bar. Verifier must confirm the `forced` value, the IsReady re-check, and `burst_blocked` are computed identically for both loops, and that the only intended difference (default target) is preserved. sim:hunter before/after must match exactly.
- **Window fit:** one window; single file, tight.

### Phase P3 — Recovery feature: standardize keys, factories, migration (F3 + F2, Decision D1-B) · *gated on D1 (resolved=B) · split into P3a / P3a′ / P3b / P3c*
The largest unit. Schema + middleware move **together** per class as one coherent "recovery" feature. **Decision D1-B adds key standardization + a migration shim**, so the order is: audit → build factories → land migration → rename classes. Pre-split to keep each step inside one window. **P3 is the one phase that is *not* byte-identical:** the audit found the 8 standalone middleware blocks diverge on 6 axes that split into **per-class DATA** (prefix/log strings, hp/pct defaults, Healthstone Action tier list) and **accidental behavior drift** (stealth guard, `in_combat` guard, `:IsExists()` gating, rune `min_hp` floor). We **normalize** the behavior axes to one standard rather than parameterize them — so the factory stays pure data-driven (like `register_trinket_middleware`) and a small, explicitly-listed set of behavior changes is *expected*. Everything else stays byte-identical.

- **P3a — Audit + build the factories (no class wired, no rename yet).**
  - **Gate A audit (do this FIRST):** enumerate all 9 classes' exact recovery keys, defaults, log strings, potion/rune Action names, and guards into a table, **and produce the authoritative old→new rename map** (finalizing the D1.1 vocabulary). Classify every divergence as **DATA** (passed as opts) or **BEHAVIOR** (normalized to one standard). Every later step is generated from this table. **Do not write factory signatures until the audit is complete** — the hunter-vs-mage divergence proves assumptions are unsafe. *(Audit complete — results baked into plan §A.)*
  - `common.lua`: add `S.recovery(opts)` and `S.mana_recovery(opts)` mirroring the existing `S.trinkets` factory (returns a `{ header, settings = {...} }` section table). Sections emit the **canonical** keys; `opts` carries per-class defaults / which sub-settings apply (incl. hunter's new `dark_rune_min_hp`, default 50).
  - `core.lua`: add `register_recovery_middleware(opts)` next to `register_trinket_middleware` (same shape: reads `NS.A`, registers via `rotation_registry:register_middleware`). **`opts` is pure DATA** — `prefix` (→ middleware names + `[MW]` log strings), per-class Healthstone Action tier list (hunter `{HSMaster1,2,3}`, warlock has the Fel tier, others 2-tier), healing-potion `hp_default` (hunter 35, others 25) + Actions, and optional mana config (rune/potion Actions + per-class `pct_default`s). The **3 behavior axes are baked into the factory body, not parameterized**: skip while `context.is_stealthed`, require `context.in_combat`, and wrap every consumable Action in `:IsExists() and :IsReady(...)`; rune use also honors the `dark_rune_min_hp` floor. Covers **8 classes** (druid's recovery is embedded form-aware middleware → stays bespoke; mage's `ManaGem` stays bespoke).
  - **No class migrated, no key renamed in P3a.** Build stays green with factories defined-but-unused. Gate B = build + luacheck.
  - **Deliberate normalizations (the *only* allowed P3 behavior changes):** (1) stealth guard → all classes (today hunter only); (2) `in_combat` guard → all incl. hunter (today all but hunter); (3) `:IsExists()` on all consumable Actions (today paladin+shaman only); (4) hunter's dark/demonic rune gains the `dark_rune_min_hp` floor (default 50) it currently lacks — closing a latent self-damage hole. Anything *not* on this list is still a FAIL.
- **P3a′ — Migration shim + verification (lands BEFORE any rename).** Implement `migrate_recovery_keys()` per D1.2: one-time, idempotent, runs before `refresh_settings` caches settings, guarded by a stored flag/version stamp, copies `old → new` only when `new` is unset, clears `old`. **Verify per D1.3 — manually in-game** (no Lua harness exists; see §5/§10): seed a profile with old keys at non-default values → `/reload` → confirm new keys hold them, old keys cleared, and a second `/reload` changes nothing. Because it rewrites saved user data with no automated guard, treat this as a **release-blocking checklist item**. This sub-phase MUST land before P3b or the first renamed class loses settings on reload. Gate B = build + luacheck + manual migration verified.
- **P3b — Migrate classes 1–5 (schema + middleware + rename atomically per class).** Order: hunter, mage, warlock, paladin, warrior. For each class, in one step: swap inline recovery schema for `S.recovery(...)`/`S.mana_recovery(...)` emitting canonical keys; swap hand-rolled recovery middleware for `NS.register_recovery_middleware(...)` reading canonical keys; ensure the class's slice of the rename map is covered by the shim. Hunter additionally picks up the deliberate normalizations (now in-combat/stealth/`IsExists` gated + a `dark_rune_min_hp` floor) — *expected*, not regressions. Build + luacheck + dev_revision bump per class. Checkpoint after class 5.
- **P3c — Migrate the remaining 3 factory classes (priest, shaman, rogue)** identically, **then druid (schema/key normalization only — middleware stays bespoke):** rename druid's `mana_potion_mana→mana_potion_pct` and `dark_rune_mana→dark_rune_pct` and update the 4 reads in `druid/middleware.lua`. Final build + luacheck + spot-check + a full-profile migration smoke (old → new across a realistic saved profile).
- **Why per-class-atomic:** schema (key definition) and middleware (key consumer) for a class must not be half-migrated, or recovery silently misbehaves. Factories + migration exist once (P3a/P3a′); wiring + rename is per-class and independently verifiable.
- **Gate B emphasis:** for each migrated class, registered middleware names (`<Class>_Healthstone` etc.), priorities, firing thresholds, and `[MW] ...` log strings stay **unchanged**. The **only** intended observable changes are (a) the renamed setting keys (made seamless by the shim) and (b) the four **Deliberate normalizations** listed in P3a — anything else is a FAIL. Equivalence-against-the-normalization-list proof per class + manual migration verification.
- **Window fit:** P3a (audit + factories) one window; P3a′ (shim + test) one window; P3b ~5 classes one window; P3c ~4 classes one window. Unusually divergent classes get their own sub-step.

### Phase P4 — Racial strategy factory, common case only (F5) · *Medium confidence · ~1 window + audit*
- **Files:** `core.lua` (add factory) + the **12** clean-fit playstyle files (mage×3, rogue×3, warlock×3, shaman×3).
- **Lowest-confidence hoist — and the most likely to be partially deferred.** Verified divergence in the skeleton, not just the spell list:
  - Some use the framework `setting_key = "use_racial"` auto-check (`mage/fire.lua:124`); others inline `if not context.settings.use_racial then return false end` (`paladin/retribution.lua:179`).
  - Some probe `IsReady` in `matches` *and* `execute` (mage); others always-return-true in `matches` and probe only in `execute` (ret).
  - Some entries are **HP-gated** (`paladin/retribution.lua:189` Gift of the Naaru at `hp < 60`; Stoneform).
- **Change:** `NS.create_racial_strategy({ prefix, spells = { {Action, "Label"}, ... } })` producing the **common** skeleton (off-GCD, `is_burst`, `setting_key="use_racial"`, TTD gate via P1's `ttd_too_short`, try-each-`IsReady` in order). Migrate only the playstyle files that match the common shape exactly.
- **LEAVE the outliers bespoke (audit-confirmed):** **paladin×3** (HP-gated naaru/stoneform) and **priest×3** (no TTD gate, `is_spell_available` guards, inline combat gate; smite diverges further). Do **not** add `gate`/`condition`/availability params to force them through — that's the over-abstraction trap.
- **Gate A is decisive here:** audit done — **12 of ~18 sites (~67%) fit cleanly**, clearing the ">half fit" bar, so P4 proceeds with priest + paladin excluded. (If a re-read shrinks this below ~half, descope P4.) This remains an explicit "maybe we don't do this" phase.
- **Gate B emphasis:** racial firing order and labels unchanged per migrated file; depends on P1 landing first (uses `ttd_too_short`).
- **Window fit:** audit + common-case migrations fit one window; if the audit shows >~12 clean cases, split migrations into two windows.

### Phase P5 — Readability cleanups (R-a, R-b, R-c, R-d) · *Mixed · ~1 window, independently revertible*
Four small, independent items bundled into one window; each is its own commit so any can be dropped:
- **R-a** (verified, §6): remove the redundant `last_validated_active` guard in `main.lua:349-352`. Grep-confirm no other reader first.
- **R-b** (safe, comment-only): add a one-line warning at `dashboard.lua:737-738` that `dash_context` may alias the live reusable rotation context and must be treated read-only. **No code change.**
- **R-c** (rescoped — see §6): "derive from named constants" is **not executable as written** (the offset's components are bare prose numbers, not in-scope named constants). **Recommended: drop it.** If the owner wants it, it first requires hoisting those values to real named constants visible at line 845 — a real sub-step, not a one-liner. Do **not** rewrite `update_dashboard`.
- **R-d** (reframed, §6): delete dead `get_spell_focus_cost` + export; decide keep/remove on `NS.get_spell_energy_cost` export. No merge.

## 8. Sequencing & dependencies

```
P1 (TTD predicate) ──────────────┐ (provides ttd_too_short, used by P4)
P2 (force/burst helper) ─ independent
                                  ├──> P4 (racial; uses ttd_too_short)
D1=B ──> P3a (audit+factories) ─> P3a′ (migration shim+test) ─> P3b ─> P3c
P5 (readability) ─ independent (R-a/b/c/d each standalone)
```
- **P1 before P4** (P4 reuses the predicate).
- **P3 ordering is strict:** P3a (audit + factories) → **P3a′ (migration shim + test) → P3b/P3c renames.** The shim must exist before the first rename.
- **P2 and P5 can go any time** (fully independent).
- Recommended execution order: **P1 → P2 → P5 → (D1) → P3 → P4.** Front-loads the certain, independent wins; defers the medium-confidence racial hoist last so we can descope it cheaply if its audit disappoints.

## 9. Deliberately NOT done (reviewed, leave-local verdicts)

Recorded so a future pass doesn't "DRY" these and break something:
- **`try_heal_cast`/`try_heal_cast_fmt` vs `try_cast`/`try_cast_fmt`** (`core.lua:818-866`): the heal variant's player-unit readiness check + `HE.SetTarget` injection is meaningful and commented. Merging breaks party/raid targeting in a hot path. **Keep split.**
- **`warrior/middleware.lua` (1563 lines, 31 middleware):** verified as genuinely warrior-unique mechanics (stance-dancing, spell reflection + PvP nameplate scan, ~12 PvP entries), not duplication. Only its Healthstone/HealingPotion overlap is covered by P3. An optional PvP-split is organizational taste, not in scope.
- **Dispel/cure middleware** (mage RemoveCurse, paladin Cleanse, priest DispelMagic/AbolishDisease, shaman CurePoison/CureDisease): class-specific spells + debuff-type targeting. **Leave local.**
- **Module preambles** (`if not A then return end` / NS-handle aliasing, ~54 files): the standard flat-load idiom; a helper would obscure the load contract. **Leave local.**
- **Dashboard tables, burst gating (`should_auto_burst`), `try_cast`/`is_spell_available`/cost helpers:** already shared at the right altitude. No action.

## 10. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Wide mechanical edits (P1, P3) miss/garble a site | Grep-residue check after each (old pattern must be gone); per-class build + luacheck. |
| Recovery key rename silently resets saved settings (Decision D1-B) | Migration shim lands in P3a′ **before** any rename; idempotent, copy-only-if-unset; **manual in-game migration verification** (no Lua harness) treated as release-blocking + full-profile smoke; per-class atomic schema+middleware+rename; log-string + name equivalence proof. |
| P3 normalization changes behavior beyond intent | Only the **4 listed Deliberate normalizations** (stealth / `in_combat` / `:IsExists()` / hunter rune `min_hp`) are allowed; Gate B proves the diff matches that list and nothing else; independent re-review confirms. |
| "Refactor" introduces a behavior change | Gate B item 4 (articulated equivalence) + independent re-review + sim:hunter before/after for dispatch-path phases. |
| Racial factory over-abstracts to fit outliers | Audit-gated; common-case only; descope if <~half fit. |
| Phase spans multiple context windows → drift | Phases pre-split with build-green checkpoints; each sub-phase independently verifiable. |

## 11. Deliverables

1. This design doc (approved).
2. A derived **implementation plan** (`2026-06-14-dry-readability-plan.md`) that expands each phase into airtight, junior-proof numbered steps with exact edits, the per-class audit tables + old→new rename map (P3), the migration-shim spec + test (P3a′), the racial audit (P4), and per-step Gate A/Gate B checklists. **Decision D1 is resolved (Option B)**, so the recovery phase is written concrete, not conditional.

## Appendix A — Verified evidence (counts re-checked by grep)

| Claim | Verified value |
|-------|----------------|
| TTD-gate exact line occurrences | 40 (`context.ttd < min_ttd`), 16 files; 39 preceding `local min_ttd = ...` |
| `register_trinket_middleware` call sites | 9/9 class middleware files (the pattern P2/P3 mirror) |
| `FluxAIO_SECTIONS` consumers | 9/9 schema.lua |
| Recovery keys inline in schemas (not via SECTIONS) | `healthstone_hp`, `use_healing_potion`, `healing_potion_hp`, `cd_min_ttd` in 9/9 |
| Recovery key divergence (Decision D1) | hunter `use_mana_rune`/`mana_rune_mana` vs mage `use_dark_rune`/`dark_rune_pct` |
| Force/burst gating duplicate | `main.lua:84-95` ≈ `main.lua:164-177` (only default target differs) |
| Double-guard | `main.lua:349-352` wraps a call `core.lua:1004` already early-returns |
| Spell-cost helpers | `mana`/`rage` used; `energy` (NS) + `focus` zero external callers; cat.lua:51 has its own |
| Racial strategy spread | ~18 sites; **12 fit cleanly** (mage×3, rogue×3, warlock×3, shaman×3); priest×3 + paladin×3 bespoke (HP gates / no-TTD + availability guards) |
| `update_dashboard` size + magic offset | 641 lines (724-1364); `content_y = -40` at 845 with "keep in sync" comment 842-844 |
