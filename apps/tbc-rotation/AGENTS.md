# tbc-rotation — Menagerie Addon

> Scope: the WoW TBC rotation addon and its build layer. Read the root `AGENTS.md` first for
> global behavior + the workspace map. Per-class rotation detail lives in each class folder's
> own `AGENTS.md` under `src/aio/<class>/` — this doc covers the **addon-wide** machinery only.

## What this is

A multi-class WoW TBC rotation addon written in **Lua**, built on the GGL Action/Textfiles
framework. The TypeScript here (`build.ts`, `dev-watch.ts`) is **only a build layer** — it bundles
the per-class Lua modules into one TMW profile. The single output is `output/TellMeWhen.lua`
(gitignored). This is **not** a TS/React app; do not treat `output/` as product code.

## Build / watch / sync

```bash
corepack pnpm --filter @menagerie/tbc-rotation build       # compile → output/TellMeWhen.lua
corepack pnpm --filter @menagerie/tbc-rotation build:sync   # build + sync to SavedVariables
corepack pnpm --filter @menagerie/tbc-rotation build:all    # build + sync
corepack pnpm --filter @menagerie/tbc-rotation watch        # auto-rebuild + sync on save
corepack pnpm --filter @menagerie/tbc-rotation watch:log    # watch, logs in .logs/
```

`build`/`watch` first run `build:engine` (builds the `@menagerie/tmw-profile-builder` package, whose
compiled `dist/` is consumed here), then run `build.ts` / `dev-watch.ts` directly via `tsx` — the app
itself no longer compiles to a `dist/`. `build.ts` is a thin wrapper: it builds a `BuildContext` via
`createBuildContext({ projectRoot })` and dispatches to the package's `runCli`. The build/watch/sync
**engine itself** lives in `packages/tmw-profile-builder/` — see that package's `AGENTS.md`. This app
only owns the _config_ (below) and the Lua source.

- Sync targets (SavedVariables paths) live in `builder.config.local.json` (gitignored;
  see `builder.config.local.example.json`). Never commit real local paths.

## builder.config.json (the build contract)

`builder.config.json` (committed) is the **WHAT** of the build; the package is the **HOW** and
ships no defaults. It declares:

- `modulePrefix` / `profileNamePrefix` / `nameOverrides` — TMW module + profile naming.
- `paths` — root-relative `aioDir`, `template`, `output`, `local`. Note `template` is
  `src/tmw-template.lua` (the TMW profile template — icons, groups, bars; lives in `src/`).
- `loadOrder` — the module load order (see below).
- `metadata` — the build-number injection marker/anchor/template.

Rename a source `.lua`? Update the matching `loadOrder.source`. Different game version? Point
`paths` at a different template/output.

## Module load order

Each class folder contributes files into shared slots; the order is data-driven from
`builder.config.json` `loadOrder` (the package reads it — there is no longer an `ORDER_MAP` in
`build.ts`). Shared and class modules interleave by `order`:

1. `theme.lua` (shared) **/** `common.lua` (shared) **/** `widgets.lua` (shared) — shared theme self-bootstraps namespace; common helpers and UI chrome primitives load in the same slot (widgets reads theme colors at call-time, not load-time)
2. `schema.lua` (class) — settings schema, `ProfileEnabled`
3. `ui.lua` (shared) — ProfileUI generator (framework backing store)
4. `core.lua` (shared) — namespace, settings, registry, constants, force flags, burst context
5. `debug.lua` (shared) — debug log substrate, shared debug chrome/theme, `/mlog`
6. `class.lua` (class) — actions, constants, `register_class()`
7. `healing.lua` (class) **/** `settings.lua` (shared) — same order slot, no mutual deps
8. `middleware.lua` (class) — shared middleware strategies
9. `debugpanel.lua` (shared) **/** `dashboard.lua` (shared) — diagnostic and combat overlays
10. `main.lua` (shared, **always last**) — context creation, dispatcher, force-bypass

Remaining playstyle files in a class folder load at the class default order (`defaultModuleOrder`,
currently 8) in filename order.

## AIO architecture

All modules share the `_G.Menagerie` namespace (aliased `local NS = _G.Menagerie`). `NS.A`, `NS.Player`,
`NS.Unit`, `NS.rotation_registry`, `NS.Constants` are the common handles.

**Strategy Registry pattern** (`rotation_registry` in `core.lua`, dispatched in `main.lua`):

- **Middleware** runs first — recovery items, offensive CDs, self-buffs, dispels. Registered via
  `rotation_registry:register_middleware()` with explicit `priority` (higher = first;
  `Constants.MIDDLEWARE.*`).
- **Strategies** are playstyle-specific. Registered via `rotation_registry:register(playstyle,
strategies_array)`. Array order = priority (first = highest).

Each entry is a table: `name`, `matches(context, state)`, `execute(icon, context, state) →
result, log_msg`, plus optional `is_burst`, `is_defensive`, `setting_key` (auto-checked by
`check_prerequisites`), `spell` (auto-checked `IsReady` + availability).

**`register_class(config)`** — each `class.lua` registers `name`, `playstyles`,
`idle_playstyle_name`, `get_active_playstyle(context)`, `get_idle_playstyle(context)`,
`extend_context(ctx)`, optional `gap_handler(icon, ctx)`, and a declarative `dashboard` table.

**Context object** — `create_context(icon)` in `main.lua` rebuilds a reusable table each frame:
player state (stance/hp/mana/energy/rage/cp/in_combat/is_stealthed), target state
(target_exists/target_dead/target_enemy/target_hp/ttd), positioning (in_melee_range/is_behind/
enemy_count), `context.settings` (cached from UI toggles), plus per-class fields from
`extend_context`.

**Force-bypass & burst context** — `/menagerie burst` and `/menagerie def` set force flags
(`is_force_active`) that skip `matches()` + `check_prerequisites()` for tagged entries, but if a
`spell` is set `IsReady()` is still checked (CD/range/stance respected). `should_auto_burst(context)`
gates _automatic_ burst from schema checkboxes (`burst_on_bloodlust`, `burst_on_pull`,
`burst_on_execute`, `burst_in_combat`): `nil` = fire freely, `true` = met, `false` = configured but
unmet (burst held).

**Dashboard** — shared combat overlay (`dashboard.lua`), driven by the `dashboard` table passed to
`register_class()`. Toggled via the `show_dashboard` setting or `/menagerie status`.

## Shared modules (`src/aio/*.lua`)

| File            | Owns                                                                                                                                                              |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `theme.lua`     | Shared warm Menagerie color palette (`NS.Theme`), semantic state colors, and curated per-class accent resolution.                                                 |
| `common.lua`    | First-slot shared low-level helpers used before core.                                                                                                             |
| `widgets.lua`   | Shared low-level UI chrome primitives (`NS.Widgets`): `BACKDROP_THIN`, `themed_button`, `section_header`. Pure chrome — no settings/schema/panel knowledge.        |
| `core.lua`      | Namespace, settings cache, utilities, `Constants`, the `rotation_registry`, force flags, burst context, trinket middleware factory, immunity helpers (see below). |
| `debug.lua`     | Shared debug substrate: structured debug log, log window, throttled `debug_print`, debug chrome/theme exports, `/mlog`.                                      |
| `ui.lua`        | Generates `A.Data.ProfileUI[2]` from the active class schema (framework backing store).                                                                           |
| `settings.lua`  | Custom tabbed settings UI, movable toggle button, `/menagerie` slash commands.                                                                                    |
| `debugpanel.lua`| Shared live diagnostic panel (`/mdebug`) with class-provided sections.                                                                                            |
| `dashboard.lua` | Data-driven combat overlay.                                                                                                                                       |
| `main.lua`      | Loads last. Builds context, dispatches middleware → strategies, applies force-bypass.                                                                             |

### Immunity model (two layers — don't build per-school tables)

Immunity is handled in two complementary layers; reach for the right one and **do not** start
maintaining `FIRE_IMMUNE`/`FROST_IMMUNE`/… npcID lists per school — the learned tracker exists
precisely so that's unnecessary.

1. **Aura-based (predictive).** Transient immunity from a _buff/debuff_ — Divine Shield, Ice Block,
   Banish, boss damage-immunity phases. Use `NS.has_phys_immunity` / `has_magic_immunity` /
   `has_total_immunity` / … (core.lua, backed by the `IMMUNITY_*` spell-ID tables), or the Action
   framework's own `spell:AbsentImun(unit, category)` + `Action.GetAuraList("TotalImun"/"CCTotalImun")`.
   These overlap — both watch auras. The framework has **no** PvE creature/school immunity data.
2. **Learned (reactive).** Intrinsic per-creature spell immunity the game only reveals on cast.
   `NS.is_spell_immune(unit, spellID_or_array)` queries it; a single CLEU frame records the player's
   `SPELL_MISSED … IMMUNE` events, **keyed by npcID (creature template, not GUID) and spellID (not
   school)** so one lesson covers the whole pack and every future spawn. Recording is **target-only**
   and skips transient (aura) immunity. Lifetime = the `immune_learn_ttl_min` setting (per class
   General tab). This is the general, self-maintaining net for fire/frost/debuff/etc. immunity.
   - **Seed exception:** `NS.ARCANE_IMMUNE` (npcID → true) pre-covers the handful of genuine
     _Arcane-school_-immune mobs (Curator et al.) so they cost zero wasted GCDs from the first cast.
     It's frozen TBC content, not a pattern to replicate for other schools.

## Settings schema mechanics

Per-class `schema.lua` defines `_G.Menagerie_SETTINGS_SCHEMA`. One schema drives **three** consumers:
`ui.lua` (ProfileUI backing store), `settings.lua` (tabbed UI), and `core.lua`
(`refresh_settings()` → `cached_settings`). Keys are **snake_case everywhere**: `GetToggle(2, key)`,
`SetToggle({2, key, ...})`, `cached_settings[key]`, `context.settings[key]`.

## Lua / WoW constraints (do not violate)

- **Lua 5.1** syntax only (WoW's embedded interpreter).
- **200 local-variable limit** per function scope.
- **No inline table creation in combat** — WoW's secure environment forbids it. Pre-allocate
  option tables at load time.
- **Never capture settings at load time** — settings change at runtime. Read through
  `context.settings.<key>` inside `matches`/`execute`, never `A.GetToggle(...)` at module level.
- Frame-rate sensitive: the rotation runs every frame; avoid allocations in hot paths.
- Class modules gate on `A.PlayerClass`; shared modules gate on `_G.Menagerie` existing.
- **File naming**: lowercase single words only — no underscores/hyphens/spaces (e.g. `cat.lua`,
  `cliptracker.lua`). Enforced by the build.

## Slash commands (`/menagerie`)

| Command             | Behavior                                                             |
| ------------------- | -------------------------------------------------------------------- |
| `/menagerie`        | Toggle settings UI                                                   |
| `/menagerie burst`  | Force offensive CDs for 3s (fires `is_burst` entries)                |
| `/menagerie def`    | Force defensive CDs for 3s (fires `is_defensive` entries)            |
| `/menagerie gap`    | Fire best gap closer (consumed on first success, uses `gap_handler`) |
| `/menagerie status` | Toggle combat dashboard                                              |
| `/menagerie help`   | Print command list                                                   |

## Debugging

- `debug_print(...)` (`debug.lua`) — throttled per unique message; enable via the "Debug Mode"
  setting checkbox.
- Debug log (`/mlog`) — structured log frame with copy/clear/resize and hover context.
- Debug panel (`/mdebug`) — live state panel, enabled by the "Show Debug Panel" setting.
- Combat dashboard (`/menagerie status`) — live priority/CDs/buffs overlay.
- `src/sim/` — simulation harness that regression-checks rotation logic (`pnpm sim:hunter`, etc.).
- `pnpm lint:lua` — static analysis of `src/aio` via `luacheck` (catches typo'd API names,
  accidental globals, unused/shadowed locals before an in-game reload). Config + the WoW/Action
  global allowlist live in `.luacheckrc`; needs the `luacheck` binary (`brew install luacheck`).

## Releases

Rotation code changes need a version bump + changelog + tag. That cross-area release workflow lives
in the **root** `AGENTS.md`. The website changelog substep is documented in
`apps/website/AGENTS.md`.

## See also

- Build/watch/sync engine: `packages/tmw-profile-builder/AGENTS.md`
- Per-class rotation context: `src/aio/<class>/AGENTS.md`
- Class research: `docs/<CLASS>_RESEARCH.md`; adding a class: `docs/NEW_CLASS_GUIDE.md`
