# WS-10 — Rewrite `NEW_CLASS_GUIDE.md` — Implementation Plan

> **Type:** Implementation (docs-only). **Design:** `2026-06-14-platform-hardening-design.md` §4.10,
> §8 Q3. **Evidence:** `2026-06-14-platform-audit/04-ergonomics.md` (#1).
> **Status (verified 2026-06-15):** not started — the guide actively teaches obsolete/broken patterns.
> **Risk:** Zero (no code). **Payoff:** Highest ergonomic ROI — roughly halves *perceived* boilerplate
> and stops new authors copying dead patterns. This is the most direct lever on the §1 goal: "a class
> author writes only a rotation."

## Timing (resolves §8 Q3)

The guide should teach the **final** declarative platform. Two viable orders:
- **Recommended:** sequence WS-10 **after** WS-2…WS-8 land, so it documents the finished factories
  (`S.immunity/cooldowns/spec`, `register_consumable_actions`, auto-registered trinket/tail, the
  interrupt factory, `apply_common_context`). One rewrite, correct on the first pass.
- **If the hoists slip:** do a *corrective* pass now (fix the outright-wrong items D-1…D-10 below
  against the **current** platform), then a second pass after the hoists. Costs two edits.

Either way, the wrong-today items below must be fixed; the question is only whether to also document the
not-yet-landed factories.

## Method

Rewrite `docs/NEW_CLASS_GUIDE.md` to teach the *current* declarative path, verified against two real
class files (`apps/tbc-rotation/src/aio/mage/` and `rogue/` are the cleanest references) plus
`apps/tbc-rotation/CLAUDE.md` (the authoritative framework contract). Every code block in the guide
must correspond to something a real `class.lua`/`schema.lua` actually does today.

---

## Divergences to fix (guide says X → code does Y)

| # | Guide currently teaches | Reality (fix to this) |
|---|---|---|
| **D-1** | Hand-rolled `local function validate_playstyle_spells(playstyle)` with `if/elseif` chains, assigned to `NS.validate_playstyle_spells` (`guide:261–289`) | **Declarative** `playstyle_spells = { fire = { {spell=, name=, required=}, … } }` passed inside `register_class`. The registry validates (`main.lua:346` calls `rotation_registry:validate_playstyle_spells`). No class sets `NS.validate_playstyle_spells`. See `mage/class.lua:161–190`. |
| **D-2** | `version` is a **required** `register_class` field (`guide:296,326`), example `version = "v1.0.0"` | **No per-class version.** Zero classes pass `version` (`grep '"version"' src/aio/*/class.lua` → none). One platform `NS.VERSION` from `package.json`. Remove `version` from the guide entirely. |
| **D-3** | Hand-written `register_middleware{...}` recovery block with manual `IsReady`/`format` (`guide:393–461`) | `NS.register_recovery_middleware({prefix=, healthstone=, healing_potion=})` factory (`core.lua:1340`), used 8/9 (`mage/middleware.lua:111`). Document the factory. |
| **D-4** | No mention of interrupt middleware | `NS.register_interrupt_middleware({name, spell, setting_key, priority, label})` (`core.lua:1591`), used by 4 classes. Document it (and, post-WS-2, the Paladin HoJ stun-interrupt exception + `NS.target_is_interruptible` Tier-1 helper). |
| **D-5** | Raw inline `{ header=, settings={…} }` table for every schema section (`guide:126–158`) | `local S = _G.Menagerie_SECTIONS` + `S.recovery{}` / `S.burst()` / `S.dashboard()` / `S.debug()` / `S.trinkets()` / `S.mana_recovery{}` (`common.lua`). Post-WS-4 also `S.immunity/cooldowns/spec`. Document the DSL. |
| **D-6** | `node build.js`, `node build.js --sync/--all`, `node dev-watch.js`, `discoverClasses`, `ORDER_MAP` (`guide:68–75`) | `pnpm --filter @menagerie/tbc-rotation build` / `build:sync` / `build:all` / `watch`. `build.ts` (not `.js`); load order is the data-driven `loadOrder` array in `builder.config.json` — no `ORDER_MAP`, no `discoverClasses`. |
| **D-7** | Load-order table wrong (class=4, middleware=6) and omits `theme.lua`/`debug.lua` (`guide:80–95`) | Replace with the real 10-slot order from `apps/tbc-rotation/CLAUDE.md` ("Module load order"): theme/common=1, schema=2, ui=3, core=4, debug=5, class=6, healing/settings=7, middleware/playstyles=8, debugpanel/dashboard=9, main=10. |
| **D-8** | Required-field table lists `version`, omits `playstyle_spells` (`guide:327–334`) | Required: `name`, `playstyles`, `get_active_playstyle` (+ `extend_context`, `dashboard`, `playstyle_spells`). Drop `version`; add `playstyle_spells` — it's the actual validation mechanism. |
| **D-9** | Execution-flow diagram shows `validate_playstyle_spells(active)` as a class callable (`guide:667–676`) | It's a **registry method** (`main.lua:346`) fed the table the class declared. Reframe. |
| **D-10** | Checklist points at `node build.js` + "update version locations (see MEMORY.md)" (`guide:1041–1068`) | `MEMORY.md` is not a project file. Replace checklist with: declare `playstyle_spells`; call the `S.*` tail; call `register_recovery_middleware`; trinket auto-registers (post-WS-8); use `pnpm … build`. Drop per-class version step. |

---

## Structure of the rewritten guide

1. **What you actually write** (lead with the §1 promise): spell IDs in `class.lua`,
   `playstyle_spells`, strategy arrays in playstyle files, the `dashboard` table, a `schema.lua` built
   from `S.*`. Everything else is a one-line declarative call.
2. **The declarative `register_class` contract** — real field table (D-8), real `playstyle_spells`
   shape (D-1), `extend_context` with `NS.apply_common_context(ctx)` (post-WS-7).
3. **Schema via `Menagerie_SECTIONS`** (D-5) — show a full real `schema.lua`; note the auto-appended
   tail (post-WS-8).
4. **Middleware factories** — recovery (D-3), trinket (auto, opt-out, post-WS-8), interrupt + the
   stun-interrupt/escape-hatch pattern (D-4), racial via `create_racial_strategy` + when to hand-roll.
5. **Consumable Actions** via `NS.register_consumable_actions(A)` (post-WS-5).
6. **Build/run** (D-6) and **load order** (D-7) — copy the canonical table from `CLAUDE.md`, don't
   re-derive.
7. **Sharp edges** — Lua 5.1, 200-local limit, no inline tables in combat, never capture settings at
   load, snake_case keys (point at `CLAUDE.md` "Lua / WoW constraints", don't duplicate).
8. **Checklist** (D-10) — the real one.

## Verification

- Every code block traces to a real file (cite mage/rogue line numbers in a reviewer note, not in the
  guide body).
- A reader following the guide would produce a class that **builds** (`pnpm … build`) and registers
  without touching `version` or hand-rolling validation/recovery.
- Cross-check against `apps/tbc-rotation/CLAUDE.md` — the guide must not contradict it. Also fix the
  stale `version = "v1.7.0"` artifact in `rogue/AGENTS.md` noted by the audit (separate small edit).

## Risk

Zero code risk. The only failure mode is documenting a factory before it lands — hence the
"after the hoists" timing recommendation. If written early, mark not-yet-landed sections clearly.
