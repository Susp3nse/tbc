# Shared (class-agnostic) Debug Panel

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

## Context

Today the rotation has three diagnostic UIs, but only the first two are shared:

| UI | Scope | Opened by | Lives in |
|----|-------|-----------|----------|
| **Debug Log** (`time │ src │ kind │ message` table) | all classes | `/menagerielog` (`/flog`); `debug_mode`/`debug_system` | `core.lua` |
| **Combat Dashboard** (priority/CDs/buffs overlay) | all classes | `/menagerie status` / `show_dashboard` | `dashboard.lua` |
| **Debug Panel** (live Player/Target/Debuffs/PvP/Pet state) | **Hunter only** | `show_debug_panel` checkbox / `/menagerie debug panel` | `hunter/debugui.lua` |
| **Adaptive Engine Panel** | Hunter only | `show_adaptive_panel` | `hunter/adaptivepanel.lua` |

The state **Debug Panel** exists only for Hunter. We want it available to every class.

Analysis of `hunter/debugui.lua` (396 lines): ~20% is reusable *scaffolding* (line layout, 10 Hz
refresh, toggle watcher) and ~80% is Hunter-specific *content* (Serpent/Viper/Concussive/WingClip
debuff timers, the PvP Viper/Concussive/WingClip verdict logic, pet/PetLibrary state). So
"generalize" = pull the refresh/layout scaffolding into a shared renderer and let each class
contribute its own content — exactly the pattern `dashboard.lua` already uses. Note the *window
chrome* (backdrop, drag, title, close-X) is **not** sourced from `debugui.lua` — that file is built
on the rejected bespoke `THEME`. The chrome comes from the log's `DBG_THEME` window via the shared
`NS.CreateDebugWindow` factory (see **Dependency & sequencing**); `debugui.lua` is the source for the
Hunter *content* only.

### Decisions locked in (from owner)

1. **Migrate, don't duplicate.** Move Hunter's Debuffs/PvP/Pet content into a per-class provider
   consumed by the shared renderer, then **delete `hunter/debugui.lua`**. One coherent panel system.
2. **Generic core now, per-class extension later.** Ship a shared generic panel (Player/Target/
   environment) that works for all 9 classes with zero per-class code, plus an optional per-class
   hook. Only Hunter authors custom sections in this pass; the other 8 get the generic core.
3. **Checkbox enables the feature; `/mdebug` opens the panel.** `show_debug_panel` is the master
   *enable* (per-class setting, default off). Ticking it does **not** auto-open the panel — it only
   makes the feature available; the user opens (and toggles) the panel with the **`/mdebug`** slash
   command. `/mdebug` is a no-op-with-hint while the checkbox is off — it never force-enables a
   disabled feature. Disabling the checkbox closes the panel. The checkbox **tooltip points to
   `/mdebug`** ("Enable the debug panel, then use /mdebug to open it"). (See **Visibility model**
   below.) `/mdebug` is a standalone slash like `/mlog` and `/mticks`, not a `/menagerie` subcommand.
4. **Theme = the Debug Log's `DBG_THEME`** (the palette we just restyled the log + BindPad importer
   toward), not Hunter's slightly-darker bespoke `THEME`. The panel must read as a **sibling of the
   Debug Log** — same chrome construction, fonts, header/accent treatment, close-X, and drag — not a
   separate-looking application window. **To guarantee that (not just approximate it), the panel builds
   its window from the *same* chrome code as the log**, not a re-themed copy of Hunter's. The log
   redesign already owns and rewrites that chrome (`core.lua`'s `DBG_THEME` window: backdrop, drag,
   accent title, close-X, separator at the current `610–644`); this design consumes a shared
   `NS.CreateDebugWindow` factory extracted from it. See **Dependency & sequencing** and **File-by-file
   changes**. (Hunter's `debugui.lua` is *not* the chrome source — it's built on the rejected bespoke
   `THEME`; it's only the source for the Hunter *content* we migrate.)
5. **Adaptive Engine Panel stays Hunter-only** — it's inherently the WoWsims engine view, not a
   generalizable concept.
6. **Clean, scannable layout over a packed dump.** Today's Hunter panel is a fixed 23-line run-on of
   values. The shared panel uses titled sections + aligned `label : value` rows on a narrow, content-
   fit window (not a full-screen overlay). See **UX / layout** below.

## Dependency & sequencing (the log redesign has landed; this owns the chrome extraction)

The Debug Log redesign
([`2026-06-14-debug-log-redesign-impl.md`](./2026-06-14-debug-log-redesign-impl.md)) **has already
landed** in `core.lua` (verified 2026-06-14): the `FauxScrollFrame` + virtualized row pool, the
structured `debug_log(src, kind, forced, fmt, …)` API with `debug_print`/`AddDebugLogLine` shims,
per-line `ctx` hover (`entry.ctx` ← `format_context_log`), and `debug_layer`/`DBG_CAT` coloring are
all present. Its ground-truth line numbers are stale; **re-locate by symbol**. Two things it did
**not** do, which this design now owns:

1. **Shared window chrome (extraction owned here).** The redesign kept the themed window chrome
   (backdrop, drag, accent title, close-X, separator) **inline** in the log-frame builder. This plan
   **extracts it into a reusable `NS.CreateDebugWindow(title) -> frame` factory** (a `DBG_THEME`-
   skinned, movable, closable window) and repoints the log's own frame at it, so the log and this
   panel share one chrome. The alternative — hand-rolling the panel's window — produces a second
   copy that drifts from the log's look. One factory, guaranteed sibling look, no duplication. (This
   is exactly the kind of consolidation the **`debug.lua` extraction** below would absorb.)
2. **Theme export.** The panel needs `DBG_THEME`/`DBG_BACKDROP` (today locals in `core.lua`). The
   factory covers chrome, but the per-row builders still read `DBG_THEME.text` / `text_dim` /
   `accent` directly, so `core.lua` must also **export** them (`NS.DBG_THEME = …`). Additive,
   independent of the landed redesign.

> **Forward note — `debug.lua` subsystem.** There's appetite to relocate the whole debug subsystem
> (theme, timestamp, throttle, `debug_log` API + buffer, the log frame, the window factory) out of
> the 1908-line `core.lua` into a dedicated `debug.lua` module that the log, this panel, and the
> dashboard all consume. If that move happens first, `NS.CreateDebugWindow` and the `DBG_THEME`
> export simply live in `debug.lua` and this plan consumes them from there — the two items above
> become "already provided." Sequencing TBD; see the separate discussion.

## Architecture (mirror `dashboard.lua`)

The dashboard is the precedent for "shared renderer + per-class data": it reads
`rotation_registry.class_config.dashboard` each refresh, renders, and is gated by a shared
`show_dashboard` setting on a 10 Hz `OnUpdate`. The debug panel copies this shape.

```
┌─ debugpanel.lua (NEW, shared) ─────────────────────────────┐
│  • window via NS.CreateDebugWindow() — the SAME factory     │
│    the Debug Log uses (DBG_THEME: drag, close X, separator) │
│  • line POOL (FontStrings created on demand, reused, hidden │
│    when unused) — line count varies, unlike debugui's fixed │
│    23-line layout                                           │
│  • 10 Hz OnUpdate refresh while shown                       │
│  • 0.5 Hz watcher: disable→hide only (NEVER auto-shows)    │
│  • runtime `visible` flag (close X / /mdebug toggle it)    │
│  • owns the /mdebug slash command (gated on the checkbox)  │
│                                                            │
│  each refresh:                                             │
│   1. build GENERIC CORE section(s) from live state         │
│   2. if class_config.debug_panel ~= nil:                   │
│         class_config.debug_panel(out, ctx)  → append       │
│   3. lay out all collected lines, size frame to fit        │
└────────────────────────────────────────────────────────────┘
```

### Visibility model (checkbox enables; `/mdebug` opens)

Two pieces of state, deliberately separate:

- `cached_settings.show_debug_panel` — **persisted** master enable (the checkbox). Gates whether
  `/mdebug` does anything; **does not by itself open the panel**.
- `visible` — **runtime-only** boolean: is the frame currently shown. Only `/mdebug` and the close-X
  set it true/false; the watcher only ever forces it false.

| Trigger | Behavior |
|---------|----------|
| Checkbox **off → on** | Feature enabled. **Panel does NOT appear** — user must run `/mdebug`. |
| Checkbox **on → off** (watcher) | If shown, `visible = false`, hide frame. Feature unavailable. |
| `/mdebug` while checkbox **on** | Flip `visible` → show if hidden, hide if shown. |
| `/mdebug` while checkbox **off** | Print hint: enable **Show Debug Panel** first. No frame. |
| Close **X** on the frame | `visible = false`, hide — **checkbox untouched**; `/mdebug` reopens it. |

The watcher is intentionally one-directional now: it only *hides* on disable. Opening is always an
explicit `/mdebug`, so ticking the checkbox is a quiet "feature on" with no surprise window, and a
closed panel stays closed until you ask for it again.

### The line-builder contract (`out`)

The renderer hands the builders a small writer object so neither the generic core nor a class
provider touches FontStrings directly:

```lua
out:header(text)            -- a section title (accent color, extra top padding)
out:kv(label, value, [hex]) -- an ALIGNED row: dim label at left col, value at a
                            --   fixed indent (optional value color). The primary
                            --   primitive — this is what makes the panel scannable.
out:line(text)              -- a free-form line (may contain |cff…|r codes); escape
                            --   hatch for content that isn't label/value shaped.
```

`out` accumulates `{ kind, ... }` entries that are reset each refresh; the renderer then assigns
them to pooled rows (growing the pool as needed, hiding extras) and sets the frame height to
`top_offset + n*lineH + padding`. A `kv` entry lays out two FontStrings per row — a dim label clamped
to a fixed label-column width and a value FontString anchored at a constant x — so values line up in a
column down the whole panel regardless of label length. `header`/`line` use a single FontString.
(FRIZQT digits are equal-width, so numeric values stay visually aligned.)

Per-class provider signature (optional, set on the class config):

```lua
class_config.debug_panel = function(out, ctx) ... end
```

`ctx` is a read-only reference to `NS.last_rotation_context` (what the rotation last saw) for
computed fields (ttd, immune flags, combat_time, ranges); builders also query `NS.Player` / `NS.Unit`
live for always-fresh values out of combat. **Every API access is nil-guarded** — providers must
tolerate "no target", "no pet", spells not yet trained.

### Generic core section (all classes, no per-class code)

Built from `create_context` fields (`main.lua`) + live `Player`/`Unit` queries, emitted as
`out:header` + `out:kv` rows so each section reads as an aligned label/value block:

- **PLAYER** — HP%, Mana% (omit the row for rage/energy classes rather than print a misleading `0`),
  GCD remaining, In-Combat, Combat Time, context (Group/Solo).
- **TARGET** — HP%, Range, In-Melee, TTD, Enemy, Boss/Elite, Phys/Magic immune flags. **Rendered
  only when a target exists**; with no target the section collapses to a single dim
  `Target : none` line, so a solo/idle panel stays short instead of showing a wall of `—`s.

This is genuinely useful for every class on day one and is the "free" payoff of the refactor.

### UX / layout (clean, concise, sibling of the Debug Log)

The owner's complaint about today's Hunter panel is that it's a packed run-on dump. The shared panel
fixes that with structure, not more space:

- **Narrow, content-fit window.** Fixed width (~220 px — wide enough for `label : value`, no wider);
  height is computed each refresh from the line count (`top_offset + n*lineH + padding`), so the
  window is exactly as tall as the current content and never a full-screen overlay. Empty sections
  don't reserve space.
- **Titled sections with breathing room.** `out:header` rows get accent color + extra top padding so
  PLAYER / TARGET / (class) blocks are visually separated, not jammed together.
- **Aligned two-column body.** Every data point is an `out:kv` row: dim label in a fixed-width left
  column, value at a constant indent. Values form a clean vertical column the eye can scan; no more
  hunting through a run-on string.
- **Value emphasis, label de-emphasis.** Labels render dim (`DBG_THEME.text_dim`); values render in
  `DBG_THEME.text`, with optional state color (e.g. red HP when low, orange for a forced/immune flag)
  passed as the `kv` color arg. Color carries meaning sparingly; the default is calm.
- **Same chrome as the Debug Log.** Title bar, separator, close-X, drag, backdrop all built from the
  shared `DBG_THEME`/`DBG_BACKDROP` so the two windows are obviously the same product. A short title
  (`Menagerie Debug`) and a `/mdebug to toggle` hint at the bottom match the log's affordances.

## File-by-file changes

### `core.lua` — extract `NS.CreateDebugWindow` (prerequisite, owned by the log redesign)
Factor the `DBG_THEME` window chrome (currently inline in `CreateDebugLogFrame` at `610–644`:
backdrop, `EnableMouse`/drag, accent title, close-X button, separator) into a small factory
`NS.CreateDebugWindow(title) -> frame` that returns a skinned, movable, closable window. The log
rewrite consumes it for its own frame; this panel consumes it too. See **Dependency & sequencing**.
If the redesign has already merged without this, do the extraction as step 0 here.

### New: `src/aio/debugpanel.lua` (shared)
The renderer above. Builds its window from **`NS.CreateDebugWindow("Menagerie Debug")`** — the same
factory the Debug Log uses, so the sibling look is structural, not approximated (**do not** re-port
chrome from `debugui.lua`; that file is on the rejected bespoke `THEME`). Adds a dynamic line pool
instead of a fixed 23-line layout. Owns the generic core builder, the `out` writer
(`header`/`kv`/`line`), the 10 Hz refresh, the disable→hide watcher, **and its own `/mdebug` slash
command**. Reads `rotation_registry.class_config.debug_panel` at refresh time.

Visibility wiring (per **Visibility model** above):
- A runtime `visible` flag; `Show()`/`Hide()` set it and the frame state together.
- The frame's **close X** calls `Hide()` (sets `visible = false`) and does **not** write the setting.
- `0.5 Hz watcher`: only acts when the checkbox is *on → off* — if the panel is shown, hide it.
  Ticking the checkbox on does nothing here (no auto-open).
- `NS.toggle_debug_panel()` — the `/mdebug` handler. Guards on `cached_settings.show_debug_panel`:
  if disabled, print the "enable Show Debug Panel first, then /mdebug" hint and return; if enabled,
  flip `visible`. (Same self-contained slash pattern `core.lua` uses for `/mlog`.)

```lua
SLASH_MENAGERIEDEBUG1 = "/mdebug"
SlashCmdList["MENAGERIEDEBUG"] = NS.toggle_debug_panel
```

The `NS.CreateDebugWindow` factory owns the window chrome, so there's no copied palette there. The
per-row builders still read `DBG_THEME` fields directly (`text`, `text_dim`, `accent` for label/value/
header coloring), so **export** `DBG_THEME` / `DBG_BACKDROP` from `core.lua` (`NS.DBG_THEME = …`) and
consume them here. (Hunter's bespoke `THEME` palettes are addressed by the `theme.lua` centralization,
not here.)

The stale `/menagerie debug panel` reference in `debugui.lua`'s header comment is removed with that
file. No `settings.lua` change is needed — the panel module owns its slash command end to end.

### `builder.config.json`
Add one `loadOrder` entry: `{ "slot": "shared", "source": "debugpanel.lua", "order": 8 }` (loads
after `core.lua`, alongside `dashboard.lua`, before `main.lua`). Class files auto-discover, so the
Hunter file swap below needs no config change.

### `common.lua` — one-line schema change
Add `show_debug_panel` (checkbox, default `false`) to the shared `S.debug()` section factory, with a
tooltip that points at the slash command: **"Enable the live state debug panel, then use /mdebug to
open it."** All 9 class schemas already call `S.debug()`, so every class gets the toggle in a single
edit, and every class's settings refresh populates `cached_settings.show_debug_panel` for the gate +
watcher.

### `hunter/schema.lua`
Remove the bespoke `show_debug_panel` checkbox from the "Debug Panel" group on the Pet & Diag tab
(now provided by shared `S.debug()`). **Keep** `show_adaptive_panel`. The toggle relocates from
"Pet & Diag" to the shared "Debug" section — acceptable.

### New: `hunter/diag.lua` (replaces `debugui.lua`)
Loads at default order 7 (after `class.lua` order 5, so `class_config` exists). Defines the Hunter
provider — the **Debuffs / PvP / Pet** sections only (Player/Target now come from the generic core,
so we don't duplicate them). Port the **data-gathering** faithfully from `debugui.lua` lines 225–323,
but re-express the **formatting** with `out:header` + `out:kv` (one row per debuff timer / verdict /
pet field) instead of the old packed lines — this is where Hunter's content gets the same scannable
treatment as the generic core. Late-binds onto the live config:

```lua
if NS.rotation_registry and NS.rotation_registry.class_config then
    NS.rotation_registry.class_config.debug_panel = build_hunter_sections
end
```

(Late-binding from a separate file post-`register_class` is the same pattern `adaptivepanel.lua`
already uses for `NS.HunterAdaptive`.)

### Delete: `hunter/debugui.lua`
After migration. Nothing else references `NS.HunterDebug` / `HunterDebugPanel` (verified by grep).

## Execution order

> **Prerequisite:** the Debug Log redesign
> ([`2026-06-14-debug-log-redesign-impl.md`](./2026-06-14-debug-log-redesign-impl.md)) lands first and
> extracts `NS.CreateDebugWindow` during its frame rewrite. If it merged without the extraction, do
> step 0 below before anything else.

0. (If not already done by the log redesign) Extract the `DBG_THEME` window chrome from
   `CreateDebugLogFrame` into `NS.CreateDebugWindow(title)`; repoint the log's own frame at it.
1. Export `DBG_THEME`/`DBG_BACKDROP` from `core.lua`.
2. Write `src/aio/debugpanel.lua` (window via `NS.CreateDebugWindow` + line pool + `out` writer incl. `kv` + generic core +
   refresh + disable→hide watcher + `visible` flag + close-X + `NS.toggle_debug_panel` + the
   `/mdebug` slash registration).
3. Register it in `builder.config.json` `loadOrder`.
4. Add `show_debug_panel` (+ `/mdebug` tooltip) to `S.debug()` in `common.lua`.
5. Write `hunter/diag.lua` (Debuffs/PvP/Pet provider, `header`/`kv` formatting, late-bound).
6. Remove `show_debug_panel` from `hunter/schema.lua`.
7. Delete `hunter/debugui.lua`.
8. `pnpm --filter @menagerie/tbc-rotation lint:lua` + `build`.

## Verification

- `lint:lua` clean; `build` succeeds (output regenerates).
- In-game (`/reload`): ticking **Show Debug Panel** does **not** open anything; `/mdebug` then opens
  the generic panel for every class. Unticking the checkbox hides an open panel (0.5 s watcher).
- **Slash command + close/reopen:** with the checkbox ticked, `/mdebug` opens the panel and `/mdebug`
  again hides it; closing via X also hides it and `/mdebug` reopens it (the watcher never re-opens on
  its own). With the checkbox unticked, `/mdebug` prints the "enable Show Debug Panel first" hint and
  opens nothing.
- **Layout reads clean:** titled PLAYER / TARGET (+ Hunter) sections, aligned `label : value`
  columns, narrow window that fits its content (not full-screen). No target → TARGET collapses to a
  single line and the window shrinks.
- Hunter panel still shows Debuffs/PvP/Pet detail (migrated), now under the generic Player/Target
  core, and is visually a sibling of the Debug Log (built from the same `NS.CreateDebugWindow` chrome).
- Out of combat, generic values are still live (not frozen at last combat snapshot).
- Cannot test WoW from CI — manual `/reload` check required.

## Risks / open questions

- **Line-pool sizing.** Panels are short; no scrollbar planned (unlike the log). If a future class
  authors a very long provider, revisit (add a scroll or cap).
- **`last_rotation_context` staleness.** It only updates while the rotation runs. The generic core
  mitigates by live-querying Player/Unit for basics; computed fields (ttd, immune) shown from
  context are best-effort and may lag out of combat. Acceptable for a debug tool; document it in the
  panel if it confuses.
- **`core.lua` surface changes.** Two: exporting `DBG_THEME`/`DBG_BACKDROP` (additive) and the
  `NS.CreateDebugWindow` extraction (owned by the log redesign, repointing its own frame at the
  factory). Neither alters the log's behavior — the extraction is a pure refactor of existing chrome.
  If the log redesign hasn't shipped the factory, this plan does the extraction itself (Execution
  step 0). See **Dependency & sequencing**.

## Out of scope

- Generalizing the **Adaptive Engine Panel** (Hunter-only by nature).
- Authoring custom `debug_panel` providers for the other 8 classes (they get generic core; can be
  added incrementally later via the same hook).
- Palette unification — now owned by [`2026-06-14-theme-lua-centralization.md`](./2026-06-14-theme-lua-centralization.md).
  Once `theme.lua` lands, the panel reads `NS.Theme` and the `DBG_THEME` export step here is superseded.
- A `kv`-grid (multiple value cells per row). The single-value `out:kv` column is enough for the
  current content; revisit only if a section needs side-by-side metrics.
