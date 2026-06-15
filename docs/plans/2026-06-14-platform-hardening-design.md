# Platform Hardening — Design Document

> **Type:** Design (the *what* and *why*, API contracts, boundaries, risks). **Not** an
> implementation plan — no step-by-step file edits here. Each workstream below is sized to spin out
> into its own implementation document later (§7).
>
> **Source of findings:** `docs/plans/2026-06-14-platform-audit/` (`00-summary.md` +
> `01-duplication.md` / `02-diagnostics.md` / `03-performance.md` / `04-ergonomics.md`). Read those
> for file:line evidence; this doc designs the fixes.
>
> **Date:** 2026-06-14 · **Branch context:** `rebrand/menagerie`

---

## 1. Purpose

Harden the shared platform (`common` / `core` / `ui` / `settings` / `dashboard` / `debugpanel` /
`main`) so it is "set in stone," and a class author writes **only a rotation** — spell IDs,
`playstyle_spells`, the dashboard table, and strategy arrays. Everything else (recovery, trinkets,
racials, interrupts, settings chrome, live diagnostics, context plumbing) should be a small
*declarative act* against shared infrastructure, with an escape hatch when a class genuinely differs.

The debug-panel extraction already on this branch (platform owns the window + refresh loop; class
supplies a `build(out, ctx)` callback) is the **reference pattern** for everything here.

## 2. Design principles (invariants every workstream must honor)

1. **No new abstraction below 2 real consumers.** If exactly one class needs it today, leave a clean
   *seam*, don't build the framework. (Defers the swing-tracker detector and the coach shell — §5.)
2. **Factory + escape hatch, never factory-only.** Every hoist must let a class opt out and hand-roll
   (warrior/shaman interrupts, druid recovery). Factories absorb the common case; they don't forbid
   the uncommon one.
3. **Combat no-alloc rule is sacred.** Lua 5.1, 200-local limit, no inline table creation in combat,
   never capture settings at load. Shared helpers run on the per-frame path — they must allocate
   nothing per frame (reuse buffers, pre-build option tables at load).
4. **Opt-out beats opt-in for universals.** Things 9/9 classes already call (trinket middleware, the
   `burst/dashboard/debug` schema tail) should auto-register by default, with an opt-out flag.
5. **Single source of truth for player-facing prose and IDs.** Tooltips, item IDs, and theme colors
   live in one place; classes reference, never re-type.
6. **Behavior-preserving.** No rotation behavior change without sim/manual verification. Anything with
   per-class gate variance (HP-defensive factory) is gated behind that bar.

## 3. Workstream map

| WS | Name | Flagship? | Audit findings | Payoff | Risk | Becomes own impl plan? |
|----|------|-----------|----------------|--------|------|------------------------|
| **WS-1** | Quick wins (perf guard, copy window, leak prunes) | — | perf #1/#2/#3, diag B | High | Trivial | No — single small PR |
| **WS-2** | Interrupt middleware (helper + factory) | ★ | dup #4, ergo #5 | Med | Med | **Yes** |
| **WS-3** | Live panel factory (`CreateLivePanel`) | ★ | diag A/D/F, perf #1 | High | Med | **Yes** |
| **WS-4** | Schema `SECTIONS` expansion | — | dup #3, ergo #6 | High | Low | Yes (small) |
| **WS-5** | Shared action injector (consumables + safe racials) | — | dup #2/#7 | Med | Low | Yes (small) |
| **WS-6** | Racial strategy factory adoption | — | dup #1 | Med | Low–Med | Yes (small) |
| **WS-7** | Common context helper + registry-owned cache reset | — | dup #6, ergo #3 | Med | Med | Yes |
| **WS-8** | Auto-register universals (trinket + schema tail, opt-out) | — | dup, ergo #6 | Med | Low | Folds into WS-4/WS-5 |
| **WS-9** | Theme + refresh-ticker consolidation | — | diag D/F | Low | Low | Folds into WS-3 |
| **WS-10** | Rewrite `NEW_CLASS_GUIDE.md` | — | ergo #1 | High | Zero | Yes (docs-only) |

The two ★ flagships get full design treatment (§4.2, §4.3); the rest get contract-level design.

---

## 4. Workstream designs

### 4.1 WS-1 — Quick wins (no architecture, do first)

Three independent, low-risk fixes bundled because none needs design debate:

- **Perf guard (perf #1, HIGH):** `hunter/adaptive.lua` `logDecision` allocates a ~45-field table
  several times/second for the whole fight, **unconditionally**, even when its only consumer
  (`show_adaptive_panel`) is off. Decision: gate the *log append* on
  `NS.cached_settings.show_adaptive_panel`. The live panel reads the separate pre-allocated
  `lastDecision` table, so live readout is unaffected; only the exportable history stops accruing when
  the panel is closed — which is the intended semantics. **Contract:** `logDecision` early-returns
  when the panel setting is off. Also fix the at-cap `table.remove(t, 1)` O(n) shift → ring index.
- **`NS.ShowCopyWindow(title, text)` (diag B):** collapse the two verbatim export windows
  (`cliptracker.lua` `ShowExportWindow`, `adaptivepanel.lua` `ShowDecisionExport`) into one singleton
  built on `NS.CreateDebugWindow`. **Contract:** lazily creates one shared modal, sets EditBox text,
  `HighlightText()`, `SetFocus()`, `Show()`. Both call sites become one line. WS-3 depends on this.
- **Leak prunes (perf #2/#3, MED/LOW):** `learned_immune` clears expired *spell* entries but never the
  empty *bucket* → one tiny table leaks per creature template per session. Add
  `if next(bucket) == nil then learned_immune[npc_id] = nil end` after pruning. `cliptracker` ClipLog
  5000-cap uses `table.remove(t,1)` per insert at cap → wrap index or lower cap.

These can ship as one small PR; no cross-workstream coupling except that `ShowCopyWindow` lands before
WS-3 consumes it.

---

### 4.2 WS-2 — Interrupt middleware ★ (helper + factory, two tiers)

**Problem.** The "is the target casting something kickable and is my interrupt ready" idiom is
hand-written in 6 classes. The kickability check —
`local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()` then
`castLeft and castLeft > 0 and not notKickAble` — is re-derived everywhere, including inside the
*complex* classes. The simple 4 (mage/priest/rogue/paladin) are otherwise near-identical middleware;
warrior/shaman wrap the same check in nameplate-seeking / stance-dancing / reflection state machines.

**Design — two tiers (this is the "specific for some, specific for others" build-out):**

**Tier 1 — `NS.target_is_interruptible(unit)` helper (core.lua).** The single source of truth for the
framework's 5-return `IsCastingRemains` contract. Used by *everyone*, including the bespoke
warrior/shaman code.

```lua
-- Returns remaining cast time (seconds, > 0) if `unit` is casting an interruptible spell,
-- else nil. Encapsulates the IsCastingRemains 5-tuple + notKickAble semantics in one place.
function NS.target_is_interruptible(unit)
   local cast_left, _, _, _, not_kickable = Unit(unit):IsCastingRemains()
   if cast_left and cast_left > 0 and not not_kickable then
      return cast_left
   end
   return nil
end
```

**Tier 2 — `NS.register_interrupt_middleware(opts)` factory (core.lua).** Emits the full simple
middleware for the 4 clean classes.

```lua
-- opts = {
--   name,                       -- e.g. "Mage_Counterspell"
--   spell,                      -- Action (A.Counterspell)
--   setting_key,                -- e.g. "use_counterspell"
--   priority      = Priority.MIDDLEWARE.DISPEL_CURSE,   -- per-class
--   resource_gate = function(context) return context.energy >= Constants.ENERGY.KICK end, -- optional
--   unit          = "target",   -- default "target"
-- }
-- matches:  in_combat AND context.settings[setting_key] AND context.has_valid_enemy_target
-- execute:  cast = NS.target_is_interruptible(unit); if cast and resource_gate(context) ok
--           and spell:IsReady(unit) -> spell:Show(icon), "[MW] <name> - Cast: %.1fs"
```

**Generic-vs-specific boundary.** The factory owns: combat/setting/target gating, the
interruptibility check (via Tier 1), the optional resource gate, readiness, and the standard log line.
The class supplies only: which Action, which setting key, priority, and (rogue only) the energy gate.

**Escape hatch.** Warrior and shaman keep their bespoke middleware entirely — they just replace their
inline `IsCastingRemains` block with a `NS.target_is_interruptible(unit)` call. Tier 1 has value even
where Tier 2 doesn't fit.

**Migration impact.** 4 classes drop a ~12-line middleware to a ~6-line factory call; 2 classes
collapse one line each. ~80 lines net, one canonical kickability contract.

**Risks / open questions (resolve in impl plan, not here):**
- **Paladin is a partial fit.** Hammer of Justice "interrupts" by *stunning*, which is not the same as
  a kick and may not respect `notKickAble`. The impl plan must verify whether HoJ should route through
  this factory or stay a separate stun-interrupt strategy. **Flagged, not assumed.**
- Preserve each class's exact `priority` and rogue's `Constants.ENERGY.KICK` gate.
- Confirm `context.has_valid_enemy_target` is populated for all 4 classes (it's referenced in mage).

---

### 4.3 WS-3 — Live panel factory ★ (`NS.CreateLivePanel`)

**Problem.** `hunter/adaptivepanel.lua` (~460 lines) hand-rolls a window + `header()`/`row()`/
`spacer()` closures + Export window + toggle-watcher + 5 Hz ticker — the *same widget* the shared
debug panel already solved data-driven and alloc-free via the `out` writer (`out:header` /
`out:kv(label, val, hex)` / `out:line`). Row rendering exists twice; the panel uses a stale
pre-rebrand cold-blue theme; there are ~8 near-identical `OnUpdate` tickers across diagnostics.

**Design — one factory, both panels become instances of it.** Extract the debug panel's `out` writer +
pooled-FontString layout engine into a reusable factory. The shared debug panel and the adaptive panel
both become `CreateLivePanel` calls. This dogfoods the factory and delivers theme (diag D) and ticker
(diag F) consolidation for free.

```lua
-- Platform (aio/livepanel.lua, or fold into debugpanel.lua):
-- NS.CreateLivePanel(opts) -> panel
--   opts = {
--     title,                       -- window title
--     setting_key,                 -- NS.cached_settings flag that shows/hides it
--     width        = 240,
--     refresh_interval = 0.1,      -- seconds; one shared 10Hz default
--     build(out, ctx),             -- REQUIRED: the only thing a class writes
--     export       = function(ctx) return csv_string end,  -- optional -> adds Export btn (uses ShowCopyWindow)
--     on_clear     = function() ... end,                   -- optional -> adds Clear btn
--   }
-- The factory owns: frame via NS.CreateDebugWindow (warm theme, movable, close btn),
--   the `out` writer + alloc-free pooled layout, auto-height, Export/Clear buttons,
--   toggle-watch on cached_settings[setting_key], refresh loop gated on :IsShown().
-- `out` contract is IDENTICAL to today's debug panel: out:header / out:kv(label, val, hex) / out:line.
```

**Generic-vs-specific boundary.** Factory owns ~250 lines of adaptivepanel (frame, layout, export,
toggle, ticker). Class keeps ~150 lines of pure `build(out, ctx)` content (which rows, what they read,
hex coloring). `out:kv`'s existing `hex` arg already covers the adaptive panel's colorized option rows
— the `build` callback converts a THEME color to a 6-char hex.

**The unifying refactor.**
- `debugpanel.lua` becomes: `CreateLivePanel{ title="Menagerie Debug", setting_key="show_debug_panel",
  build = function(out, ctx) build_generic_core(out); local cc = registry.class_config; if cc.debug_panel
  then cc.debug_panel(out, ctx) end end }`. `/mdebug` still toggles it.
- `hunter/adaptivepanel.lua` becomes `CreateLivePanel{ title="Adaptive",
  setting_key="show_adaptive_panel", build=..., export=NS.HunterAdaptive.GetDecisionCSV }` — ~150 lines
  of content. Its `ForceRecompute()` / `refresh_settings()` calls move into the `build` callback.
- The class-discoverability question: keep the single `class_config.debug_panel` callback for the
  shared window; classes spin up *additional* named panels by calling `CreateLivePanel` directly at
  load. No registry array needed unless we later want settings-driven discovery — **defer that**, it's
  speculative until a 2nd class adds a panel.

**Dependencies.** Consumes `NS.ShowCopyWindow` (WS-1). Subsumes diag D (theme) and diag F (ticker) for
the panels it touches; dashboard.lua can later point at `NS.DBG_THEME` in the same sweep.

**Risks / open questions:**
- The `out` writer currently lives as locals inside `debugpanel.lua`. Decision needed in impl: new
  `aio/livepanel.lua` module vs. growing `debugpanel.lua` into the factory and having debugpanel be a
  thin instance. Recommendation: **new `livepanel.lua`**, debugpanel becomes a consumer — keeps the
  shared-vs-instance boundary explicit. Load order: factory must load before any panel instance.
- Verify pooled-FontString layout handles the adaptive panel's larger row count / width (360px) and
  its section bands without per-frame allocation.
- Auto-height vs. fixed: adaptive panel is fixed 360×590 today; factory auto-height from `out` entries
  should reproduce it.

**Out of scope (don't generalize yet, §5):** the swing-tracker *detector* in cliptracker and the
traffic-light *coach* in meleeweave. Only the panel/window/export chrome generalizes now.

---

### 4.4 WS-4 — Schema `SECTIONS` expansion

Add three factories to `common.lua` `Menagerie_SECTIONS`, mirroring the 6 already shipped:

```lua
S.immunity()        -- the byte-identical `immune_learn_ttl_min` slider (9/9 classes)
S.cooldowns(opts)   -- the `cd_min_ttd` slider (9/9), opts reserved for future CD gates
S.spec(options)     -- the "Spec Selection" wrapper around a per-class `options` array (7/9)
```

**Contract.** Pure data factories returning section tables; the three schema consumers
(`ui.lua` / `settings.lua` / `core.lua`) don't care how the table was produced. Player-facing
immunity/TTD tooltip prose gets one canonical wording. **Risk Low** — identical to the established
pattern. ~120–150 lines removed across 9 schemas. **WS-8 folds in here:** the universal
`S.burst()/S.dashboard()/S.debug()` tail can be appended by default (opt-out) rather than re-listed per
schema.

### 4.5 WS-5 — Shared action injector (consumables + safe racials)

`NS.register_consumable_actions(A)` (core.lua) injects the 8 standard item Actions (Healthstone
22105/22104, potions 22832/22829/13446/13444, runes 20520/12662) into a class's `A` table at
class-load, so the literal IDs live in one place (wrong-ID-in-one-class is a silent recovery bug
today). **Only the unambiguous racials** (`WarStomp`, `Stoneform`, `EscapeArtist`, `GiftOfTheNaaru`,
base `BloodFury`) ride along; `Berserking`/`ArcaneTorrent`/shaman's split `BloodFury*` stay per-class
because the rank/ID genuinely varies (dup #7 — do **not** collapse blindly). **Risk Low** for
consumables, **Med** for racials (ID variance) — keep the variant racials out of the injector.
Load-order is safe (core slot 4 < class slot 5).

### 4.6 WS-6 — Racial strategy factory adoption

No new code — adopt the existing `NS.create_racial_strategy` in the ~8 spec files that still hand-roll
it (paladin×3, priest×3, mage/arcane, hunter). The factory needs one small extension: an optional
extra `matches` predicate so `mage/arcane` can keep its `state.is_burning` gate. ~200 lines removed,
racial-priority logic in one place. **Risk Low–Med** — factory is proven in 5 classes; arcane's
burn-gate is the only wrinkle. Do arcane last.

### 4.7 WS-7 — Common context helper + registry-owned cache reset

Two related ergonomic fixes on the context path:

- **`NS.apply_common_context(ctx)` (dup #6):** sets the byte-identical `is_moving` / `is_mounted` /
  `combat_time` triple (8/9 classes), centralizing the `IsMoving()` mixed-type truthiness guard.
  Optional `NS.set_enemy_count(ctx, range)` for the range-parameterized enemy count. **Risk Low.**
- **Registry-owned cache reset (ergo #3, the higher-value half):** 26 hand-written
  `ctx._x_valid = false` resets exist across classes; forgetting one silently serves stale combat state
  every frame. The registry already knows which playstyles have a `context_builder`, so it should own
  a per-frame epoch/dirty reset instead of each class doing it by hand. **Design:** an epoch counter
  bumped once per frame in `create_context`; cache lookups compare epoch. Deletes a whole bug class.
  **Risk Med** — touches the per-frame hot path; must stay alloc-free and is behavior-sensitive
  (verify no playstyle relies on cross-frame cache persistence).

### 4.8 WS-8 — Auto-register universals (opt-out)

Trinket middleware is opt-in but called by 9/9; the `burst/dashboard/debug` schema tail is appended by
9/9. Make both **auto-register by default with an opt-out flag** on `register_class` / the schema
builder. **Folds into WS-4 (schema tail) and WS-5/middleware defaults.** Net: a class stops writing a
required-but-identical line. **Risk Low** — opt-out preserves any class that needs to differ.

### 4.9 WS-9 — Theme + refresh-ticker consolidation

Falls out of WS-3. Point `dashboard.lua` and any straggler panels at `NS.DBG_THEME` / `NS.DBG_BACKDROP`
(eliminating the 3 stale cold-blue copies + 1 duplicated warm copy), and replace the ~8 per-panel
`OnUpdate` tickers with the single `CreateLivePanel` refresh loop (nothing needs meleeweave's 20 Hz).
**Risk Low**, mostly mechanical, closes the rebrand gap on the off-brand windows.

### 4.10 WS-10 — Rewrite `NEW_CLASS_GUIDE.md` (docs-only, highest ergonomic ROI)

The guide teaches obsolete boilerplate (hand-rolled `validate_playstyle_spells`, a required per-class
`version`, manual recovery middleware) that the platform already absorbed; 9/9 classes actually use
declarative `playstyle_spells` + the `SECTIONS` factory + `register_recovery/trinket_middleware`, none
documented. Rewrite to teach the *current* declarative path. **Zero code risk**, roughly halves
perceived boilerplate. Should reflect WS-2…WS-8 once they land (so sequence it after, or write it twice
— once now for the existing platform, once after the hoists).

---

## 5. Explicitly deferred (clean seam, do NOT build now)

Per principle #1 (no abstraction below 2 consumers):

- **Swing-tracker detector** (diag C): `cliptracker` measurement core is generalizable to
  Rogue/Warrior/Cat melee weaving, but **no second auto-attack class needs it today.** Extract the
  *UI/export* via WS-3; leave the detector behind an `NS.CreateSwingTracker`-shaped seam.
- **Traffic-light coach shell** (diag E): `meleeweave` is ~95% irreducible Hunter timing math; the
  ~120-line render shell could be shared but has one consumer. Lift it if/when a 2nd coach appears.
- **HP-threshold defensive middleware factory** (dup #5): real ~180-line duplication, but per-class
  gate variance (hypothermia / forbearance / magic-debuff / mana floor / warlock targets the enemy)
  makes it Med–High risk. Needs an `extra_match` predicate + unit param **and** sim/manual verification
  per class. Revisit as its own gated workstream after the safe wins land.
- **Dispel-scan loop** (dup #8): 2 consumers (mage/priest) but framework `AuraIsValid` semantics +
  self-only cleanse variants make it Med–High risk for modest savings. Low priority.

## 6. Sequencing & dependencies

```
WS-1 (quick wins) ───────────────┐  (ShowCopyWindow needed by WS-3)
                                  ▼
WS-4 (schema sections) ──► WS-8 (auto-register tail)        [parallel-safe, low risk]
WS-5 (action injector) ──► WS-8 (auto-register trinket)     [parallel-safe, low risk]
WS-6 (racial adoption)                                      [parallel-safe, low risk]
WS-3 (CreateLivePanel) ──► WS-9 (theme/ticker sweep)        [after WS-1]
WS-2 (interrupt)                                            [independent; verify paladin]
WS-7 (context helper + cache reset)                        [hot-path; verify carefully]
WS-10 (guide rewrite)                                      [after the hoists, or twice]
```

**Recommended order (front-load safe, visible wins; defer behavior-sensitive):**
1. **WS-1** — quick wins (incl. the HIGH perf guard).
2. **WS-4 + WS-5 + WS-6 (+ WS-8)** — pure "apply the pattern that exists," lowest risk, big line wins.
3. **WS-3** — the keystone; unlocks live panels for all 9 classes and absorbs WS-9.
4. **WS-2** — interrupt (resolve the paladin question first).
5. **WS-7** — context/cache (hot-path, verify alloc-free + no cross-frame reliance).
6. **WS-10** — rewrite the guide to match the new platform.

## 7. How this splits into implementation plans

Each ★ flagship and each "Yes" row in §3 becomes its own implementation doc under
`docs/plans/` when scheduled, named `2026-06-14-<ws>-impl.md`. Suggested grouping to avoid plan sprawl:

- `…-quickwins-impl.md` — WS-1 (bundle the three fixes).
- `…-schema-and-actions-impl.md` — WS-4 + WS-5 + WS-6 + WS-8 (the low-risk hoist batch).
- `…-livepanel-impl.md` — WS-3 + WS-9 (flagship).
- `…-interrupt-impl.md` — WS-2 (flagship; opens with the paladin verification).
- `…-context-impl.md` — WS-7 (hot-path; opens with an alloc/behavior audit).
- `…-newclass-guide-impl.md` — WS-10 (docs).

Deferred items (§5) get a plan only when a second consumer materializes.

## 8. Open questions for the human (before any impl plan)

1. **Paladin interrupt (WS-2):** route Hammer of Justice through the interrupt factory, or keep it a
   separate stun-interrupt strategy? (Stun-interrupt ≠ kick.)
2. **`CreateLivePanel` home (WS-3):** new `aio/livepanel.lua` (recommended) vs. grow `debugpanel.lua`?
3. **Guide timing (WS-10):** rewrite once now for the current platform, or once after WS-2…WS-8 land?
4. **Cache-reset scope (WS-7):** is the registry-owned epoch reset worth the hot-path risk now, or
   defer behind the safe wins?
