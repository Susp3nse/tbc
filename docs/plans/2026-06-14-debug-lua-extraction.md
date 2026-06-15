# Extract the debug subsystem into `debug.lua`

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> Design doc. Companion to the Debug Log redesign
> ([`2026-06-14-debug-log-redesign-impl.md`](./2026-06-14-debug-log-redesign-impl.md), **landed**) and
> the Shared Debug Panel ([`2026-06-14-shared-debug-panel-design.md`](./2026-06-14-shared-debug-panel-design.md),
> **upcoming**). This move lands **between** them: the log redesign stabilized the debug code into one
> coherent block; this relocates that block out of `core.lua` so the panel (and later the dashboard)
> consume it from a dedicated home instead of from a 1908-line god-file.

## Context

`core.lua` is **1908 lines** and ~30% of it is one self-contained concern: the debug/diagnostic
subsystem, freshly rewritten by the log redesign into a stable, cohesive block (theme, structured
`debug_log` API, FauxScroll log frame, throttle, shims, slash commands). It is a textbook extraction
candidate — a single concern, a clean public surface (`NS.debug_*`, `NS.*DebugLogFrame`,
`NS.debug_timestamp`), and **no inbound coupling**: everything outside `core.lua` already reaches the
subsystem only through `NS.*`, and nothing that loads before `core.lua` (order 4) calls it.

### Decisions locked in (from owner)

1. **Scope = substrate + log frame.** Move the whole debug block: theme/backdrop/cat, timestamp,
   throttle, `debug_log` API + buffer + trim, the FauxScroll log frame and its helpers, the shims, and
   the slash commands. `dashboard.lua` is **left alone** this pass (it can adopt the shared theme +
   window factory later — out of scope here).
2. **Behavior-preserving first.** Phase 1 is a pure relocation: same symbols, same `NS.*` names, same
   behavior, green `lint:lua` + `build`. Reviewable as "no logic changed, only moved." The one small
   *refactor* (the `CreateDebugWindow` factory + theme export the panel needs) is a clearly-separated
   **Phase 2**, not smuggled into the move.
3. **`debug.lua` becomes the home of `NS.CreateDebugWindow` + the `DBG_THEME` export.** This subsumes
   the two `core.lua` changes the panel plan currently owns — once this lands, the panel consumes both
   from `debug.lua` and the panel's "extract the factory / export the theme" steps disappear.

## The cut (current symbols — re-locate by name, line numbers drift)

Verified 2026-06-14 on `rebrand/menagerie`. The region is ~`547–1180` of `core.lua` and is
near-contiguous. **Moves to `debug.lua`:**

| Symbol(s) | Current line(s) | Notes |
|---|---|---|
| `debug_log_lines`, `MAX_LOG_LINES` | 547–548 | the structured buffer |
| `DBG_THEME`, `DBG_BACKDROP`, `DBG_CAT` | 558–579 | palette + category colors |
| `FauxScrollFrame_*` `_G` aliases | 581–584 | log-frame scroll plumbing |
| `debug_layer`, `debug_cat_for` (the `DBG_CAT[debug_layer(src)]` helper) | 586–594 | src→color |
| `utf8_safe_prefix`, `debug_truncate_text`, `add_wrapped_tooltip_line`, `create_debug_button` | 597–671 | log-frame view helpers |
| `CreateDebugLogFrame` | 672–~1058 | the FauxScroll log window (row pool, hover ctx, copy/clear/resize) |
| `trim_debug_log` | 1060–~1074 | FIFO @ 500 |
| `debug_timestamp` (+ `NS.debug_timestamp`) | 1075–1078 | `HH:MM:SS.t` |
| throttle: `debug_print_cache`, `debug_string_args`, `DEBUG_CACHE_TTL`, `DEBUG_CACHE_PRUNE_INTERVAL`, `last_debug_cache_prune` | 1080–1085 | the single throttle state |
| `debug_log` | 1087–~1135 | the API |
| `AddDebugLogLine`, `RefreshDebugLogFrame`, `debug_print` (shims/view) | 1137–1160 | |
| `NS.*` exports (`CreateDebugLogFrame`, `RefreshDebugLogFrame`, `debug_log`, `debug_print`, `AddDebugLogLine`, `debug_timestamp`) | 1078, 1162–1166 | unchanged names |
| `/menagerielog` + `/mlog` slash registration | 1169–~1180 | self-contained |

**Stays in `core.lua`:** everything else, including `safe_ability_cast(ability, icon, target,
debug_context)` (1191) — it merely has a parameter *named* `debug_context`; it's rotation logic, not
part of the subsystem.

### Pre-move audit (the only real risk)

The region cross-references **only within itself** (e.g. the frame's `OnEnter` calls
`add_wrapped_tooltip_line`; `debug_log` calls `trim_debug_log`/`debug_timestamp`). Before cutting,
confirm **two directions** with grep:

1. **No debug symbol is referenced by non-debug `core.lua` code** that stays behind. Suspect the
   generic-sounding helpers: `grep -n "utf8_safe_prefix\|debug_truncate_text\|add_wrapped_tooltip_line\|create_debug_button\|debug_timestamp\|DBG_THEME" core.lua` and verify every hit is inside the moved
   region. If a helper is shared (e.g. `utf8_safe_prefix` used by non-debug code), either leave it in
   `core.lua` and have `debug.lua` call it via `NS`, or duplicate-and-rename — decide per case.
2. **No moved symbol depends on a `core.lua` local** defined outside the region. The subsystem uses
   only WoW globals + `NS` + its own locals, so this should come back clean; confirm anyway.

## Load order

`debug.lua` must load **before any caller**. Callers are classes (order 5–7), `dashboard.lua` (8),
`main.lua` (9); nothing at order 1–3 (`common`, `schema`, `ui`) calls debug, and `core.lua` itself
only *defines* the subsystem. So:

- Add `{ "slot": "shared", "source": "debug.lua", "order": 4 }` and **renumber `core.lua` → order 5**
  and everything after by +1 — *or*, to minimize churn, insert `debug.lua` at the **current
  `core.lua` slot** and bump only `core.lua`. Pick whichever keeps the `builder.config.json` diff
  smallest; the only hard constraint is `debug.lua` < every consumer.
- Verify `core.lua` does not call any `NS.debug_*` at **file-scope** (top-level, at load time). It
  doesn't today (debug is called from runtime callbacks, not load), so `core.lua` loading *after*
  `debug.lua` is safe even though `core.lua` is where the rotation engine lives.

## Phase 1 — Pure relocation (behavior-preserving)

1. Create `apps/tbc-rotation/src/aio/debug.lua` with the standard module preamble (same `local NS =
   select(2, ...)` / addon-namespace bootstrap the other shared files use — copy from `dashboard.lua`).
2. **Move** every symbol in the cut table, in dependency order, preserving names and bodies verbatim.
3. Keep all `NS.*` exports identical. The slash registration moves wholesale.
4. Delete the moved block from `core.lua`.
5. Add the `loadOrder` entry + renumber (above).
6. `pnpm --filter @menagerie/tbc-rotation lint:lua` + `build`.

**Accept:** `build` regenerates `output/TellMeWhen.lua` with identical debug behavior; `grep -n
"debug_log\|DBG_THEME\|CreateDebugLogFrame\|FauxScroll" core.lua` is empty; `lint:lua` clean. Diff is
"lines moved file-to-file," no logic delta.

## Phase 2 — `CreateDebugWindow` factory + theme export (small refactor)

Now that the chrome lives in `debug.lua`, do the consolidation the panel needs **here**, at its home:

1. Extract the inline window chrome from `CreateDebugLogFrame` (backdrop, `EnableMouse`/drag, accent
   title, close-X button, separator) into `NS.CreateDebugWindow(title) -> frame`. Repoint the log
   frame to build on it. (Behavior-preserving: the log window looks and acts the same.)
2. Export the palette: `NS.DBG_THEME = DBG_THEME`, `NS.DBG_BACKDROP = DBG_BACKDROP` for the panel's
   per-row builders.

**Accept:** log window unchanged in-game; `NS.CreateDebugWindow` and `NS.DBG_THEME` resolve;
`lint:lua` + `build` green. After this, the panel plan's `core.lua` prerequisites are satisfied **by
`debug.lua`**.

## Verification

- `lint:lua` clean; `build` regenerates output.
- In-game (`/reload`): `/mlog` opens the log; FauxScroll, hover-ctx, copy/clear/resize, throttle,
  follow-tail, forced tint — **all behave exactly as before the move** (this is a relocation, not a
  redesign).
- `NS.CreateDebugWindow("…")` produces a `DBG_THEME` window matching the log's chrome.
- Cannot test WoW from CI — manual `/reload` check required.

## Relationship to the other two plans

- **Log redesign** (landed): unchanged in behavior; its code simply now lives in `debug.lua`.
- **Shared Debug Panel** (upcoming): its **Dependency & sequencing** section already anticipates this
  — once `debug.lua` ships Phase 2, the panel's "extract `NS.CreateDebugWindow`" (Execution step 0)
  and "export `DBG_THEME`" (step 1) become no-ops; it just `require`s them from `debug.lua`. Update
  the panel doc to point at `debug.lua` once this lands.

## Out of scope

- Repointing `dashboard.lua` onto `DBG_THEME` / `CreateDebugWindow` (separate, opt-in later).
- Any change to debug *behavior*, the log layout, or the throttle window — pure relocation + the one
  factory refactor.
- Palette unification — now owned by [`2026-06-14-theme-lua-centralization.md`](./2026-06-14-theme-lua-centralization.md)
  (which `debug.lua`'s `DBG_THEME` becomes a consumer of). Sequence: **`theme.lua` → `debug.lua`**.
