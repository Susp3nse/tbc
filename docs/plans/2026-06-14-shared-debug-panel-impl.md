# Shared Debug Panel — Implementation Plan (granular, with file/line targets)

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> Companion to the design doc [`2026-06-14-shared-debug-panel-design.md`](./2026-06-14-shared-debug-panel-design.md).
> That doc carries the *why* + the locked-in decisions (migrate-don't-duplicate, generic core now /
> per-class hook later, checkbox-enables + `/mdebug`-opens, `DBG_THEME` sibling look). This doc is the
> *how*: an ordered, per-step build sheet with **current** file/line targets and a pass/fail acceptance
> check per step. **No code is written here.**

## Ground-truth reconciliation (verified 2026-06-14, branch `rebrand/menagerie`)

The design doc was written before the chrome extraction landed. Reconciled against the real tree:

| Design-doc claim | Reality | Consequence for this plan |
|---|---|---|
| Log redesign landed (FauxScroll + `debug_log` + `ctx` hover) | **True** — `debug_log` at `core.lua:1087`, FauxScroll pool in `CreateDebugLogFrame` | We consume `debug_timestamp`/theme as-is; we don't touch the log's render path |
| `NS.CreateDebugWindow` extracted by the log redesign | **False** — chrome is still **inline** in `CreateDebugLogFrame` (`core.lua:675–712`) | **Phase 1 owns the extraction** (design's "step 0"). Not optional. |
| `DBG_THEME`/`DBG_BACKDROP` available to the panel | **False** — both are file-locals (`core.lua:558`/`567`) | **Phase 1 exports them** (`NS.DBG_THEME`/`NS.DBG_BACKDROP`) |
| Chrome at `core.lua:610–644` | Stale — real block is **675–712** | Re-locate by symbol; numbers below are current |

## The model in one screen (so this plan is self-contained)

- **One shared module** `debugpanel.lua` (mirrors `dashboard.lua`): builds its window from the *shared*
  `NS.CreateDebugWindow("Menagerie Debug")` factory, holds a **dynamic FontString pool**, refreshes at
  10 Hz while shown, and reads `rotation_registry.class_config.debug_panel` at refresh time.
- **Two pieces of visibility state, deliberately separate:**
  - `cached_settings.show_debug_panel` — **persisted** master enable (the checkbox). Gates whether
    `/mdebug` does anything; **does not itself open the panel**.
  - `visible` — **runtime-only**: is the frame shown. Only `/mdebug` + close-X set it; the 0.5 Hz
    watcher only ever forces it **false** (disable→hide; **never** auto-shows).
- **`out` writer contract** (builders never touch FontStrings):
  `out:header(text)` · `out:kv(label, value, [hex])` · `out:line(text)`. `kv` is the aligned
  two-FontString row (dim label clamped to a label column, value at a constant x).
- **Generic core** (all 9 classes, zero per-class code): PLAYER + TARGET sections read **live
  `NS.Player`/`NS.Unit`** as the primary source (fresh in/out of combat), with the rotation `ctx`
  (`main.lua:205–259`) used only as **fresh-guarded enrichment** for computed fields (TTD, immune) — see
  2.3, this is the key correction the review surfaced. TARGET collapses to a single `Target : none` line
  when no target.
- **Per-class hook** (optional): `class_config.debug_panel = function(out, ctx) ... end`, late-bound
  from a separate file (same pattern `adaptivepanel.lua` uses for `NS.HunterAdaptive`). Only Hunter
  authors one this pass (`hunter/diag.lua`: Debuffs/PvP/Pet).
- **`/mdebug`** is a standalone slash (like `/mlog`), owned end-to-end by `debugpanel.lua`.

## Ground-truth reference (verified current state)

### `apps/tbc-rotation/src/aio/core.lua`

| Symbol | Current line(s) | Notes |
|---|---|---|
| `DBG_THEME` | 558–566 | `bg, bg_widget, bg_hover, border, accent, text, text_dim` — **local; export it** |
| `DBG_BACKDROP` | 567–571 | **local; export it** |
| `CreateDebugLogFrame` | 672–1058 | **window chrome inline at 675–712** — extract |
| → frame create + backdrop + movable/drag | 675–687 | factory body |
| → title (accent) | 690–693 | factory body (title text is the `title` arg) |
| → close-X button | 695–705 | factory body (factory's close-X calls `f:Hide()`; panel overrides to also clear `visible`) |
| → separator | 707–712 | factory body |
| → FauxScroll + rows + scrollbar skin | 714–755 | **stays in the log builder** (not chrome) |
| `debug_timestamp()` | 1075–1078 | exported `NS.debug_timestamp` (unused by panel, noted for parity) |
| slash `/menagerielog` + `/mlog` | 1169–1171 | `SLASH_*` + `SlashCmdList` pattern to mirror for `/mdebug` (1168 is a comment) |

### `apps/tbc-rotation/src/aio/main.lua`

| Symbol | Line | Notes |
|---|---|---|
| `create_context(icon)` | 205–259 | generic-core field source (see below) |
| `NS.last_rotation_context` set | 289 | the read-only `ctx` handed to providers |
| `local Player = NS.Player` / `Unit = NS.Unit` | 24 / 25 | live queries for out-of-combat freshness |

**Generic-core fields available on `ctx` / live** (`create_context`): `in_combat`, `hp`, `mana_pct`,
`mana`, `gcd_remaining`, `combat_time`, `target_exists`, `target_dead`, `target_enemy`,
`has_valid_enemy_target`, `target_hp`, `ttd`, `target_range`, `in_melee_range`, `target_phys_immune`,
`target_magic_immune`, `is_boss`, `target_is_elite`. (No `Group/Solo` field exists — derive from
`GetNumGroupMembers`/`IsInGroup` live, or drop the row; see 2.2.)

### Other files

| File | Symbol / line | Notes |
|---|---|---|
| `dashboard.lua` | `update_dashboard` 724; `rotation_registry.class_config` read 727; 0.25 s ctx-freshness guard 737; `UPDATE_INTERVAL=0.1` 164 + 10 Hz `OnUpdate` 417 | the renderer-shape + freshness-guard precedent |
| `common.lua` | `_G.Menagerie_SECTIONS.debug` factory, 28–39 | add `show_debug_panel` checkbox here (one edit → all 9 classes) |
| `hunter/schema.lua` | `S.debug()` 65; bespoke `show_debug_panel` **239**; `show_adaptive_panel` **241** ("Debug Panel" group, Tab 5) | remove 239, **keep** 241 |
| `hunter/debugui.lua` | 395 lines; bespoke `THEME` 34; `UpdateDisplay` body (Debuffs/PvP/Pet data-gather) **198–323**; `Show`/`Hide`/watcher **330–391**; `NS.HunterDebug` 393 | **content source for migration, then DELETE** |
| `hunter/adaptivepanel.lua` | `NS.HunterAdaptive` namespace-global reads 123/249/378 | precedent for a *separate* Hunter UI file; note its mechanism differs from `diag.lua`'s `class_config` write (see 4.1) |
| `builder.config.json` | `loadOrder` 14–25; `dashboard.lua` order 8 (23); `main.lua` order 9 (24) | add `debugpanel.lua` |

> **⚠ Watcher behavior change.** Today `debugui.lua`'s 0.5 Hz watcher (`CheckToggleState`, 365–381)
> **auto-shows** when `show_debug_panel` flips on. The new design **forbids auto-show** — the watcher
> is disable→hide **only**. Do not port the show branch.

---

## Phase 0 — Pre-flight (no edits)

**0.1 — Read area docs.** Root `AGENTS.md`, `apps/tbc-rotation/AGENTS.md`, `hunter/AGENTS.md`.
**Accept:** you can state the `build` + `lint:lua` commands and the load-order slot numbers.

**0.2 — Baseline green.** `pnpm --filter @menagerie/tbc-rotation lint:lua` + `build`.
**Accept:** both succeed on the untouched tree.

**0.3 — Confirm no stale references.** `grep -rn "CreateDebugWindow\|NS.DBG_THEME\|/mdebug\|debug_panel\|HunterDebug" src/aio`.
**Accept:** only the existing `hunter/debugui.lua` `HunterDebug` hits + the `show_debug_panel` schema
hits appear; no `CreateDebugWindow`, no `NS.DBG_THEME`, no `/mdebug`, no `class_config.debug_panel`.

---

## Phase 1 — Chrome factory + theme export (`core.lua`, pure refactor)

> Net behavior change to the log = **zero**. This is extraction + an additive export. The phase gate is
> "the Debug Log still looks and behaves identically."

**1.1 — Extract `NS.CreateDebugWindow(title) -> frame`.** Lift the chrome block (`core.lua:675–712`:
`CreateFrame` + `DBG_BACKDROP`/`DBG_THEME` colors + `SetMovable`/`SetResizable`/`EnableMouse`/
`SetClampedToScreen`/drag scripts + the accent title + the close-X button + the separator) into a new
local factory **above** `CreateDebugLogFrame`. Parameterize the **title text** (today hardcoded
`"Menagerie Debug Log"` at 692). Be explicit about three seams the callers depend on:
- **Unnamed frame.** `CreateFrame("Frame", nil, UIParent, "BackdropTemplate")` — drop the global name.
  Named frames (`MenagerieDebugFrame` 675, `HunterDebugPanel`) persist across `/reload` and can
  ghost-render unless cleaned up the way `dashboard.lua:367` does; an unnamed frame sidesteps that whole
  class. The panel needs no global handle (it holds `panel_frame`). The log re-grabs via its own
  upvalue guard, so dropping the name doesn't change the log either.
- **Keep `SetResizable(true)` (682) inside the factory.** The log's resize grip + `SetResizeBounds` +
  `OnSizeChanged=repaint` (core.lua:1027–1045) stay in the log builder and anchor to the returned `f`,
  so the log keeps full resizability. The panel simply ships no grip (content-fit height), so the flag
  is inert for it — harmless.
- **Assign the close-X to the frame: `f.closeBtn = closeBtn`** (today an unexposed local at 696). The
  factory's default handler is `function() f:Hide() end`; a caller re-points it with `SetScript`, which
  replaces the handler wholesale (the panel's new closure references the panel's own frame, not the
  factory `f`).
Return the frame; export `NS.CreateDebugWindow = CreateDebugWindow`.
**Accept:** `CreateDebugWindow("X")` returns an **unnamed**, movable, resizable, themed, closable frame
with `f.closeBtn` exposed; lint clean.

**1.2 — Repoint the log at the factory.** In `CreateDebugLogFrame`, replace the inlined 675–712 with
`local f = CreateDebugWindow("Menagerie Debug Log")`. Keep everything from the FauxScroll frame down
(714+) unchanged — it anchors to `f`. The log's size (`SetSize(500, 300)`) + start point belong to the
log; decide whether the factory sets a default size (panel will override via content-fit height) or the
caller sets it. **Recommendation:** factory sets a neutral default; each caller `SetSize`s after.
**Accept:** `CreateDebugLogFrame` no longer constructs its own backdrop/title/close/separator; the log
opens identically (drag, close-X, separator, accent title all present).

**1.3 — Export the theme tables.** After the `DBG_THEME`/`DBG_BACKDROP` definitions (566/571), add
`NS.DBG_THEME = DBG_THEME` and `NS.DBG_BACKDROP = DBG_BACKDROP`. (Additive; the locals stay for the
in-file callers.)
**Accept:** `grep -n "NS.DBG_THEME\|NS.DBG_BACKDROP" core.lua` shows both; lint clean.

**🚦 Phase 1 gate:** `lint:lua` clean + `build` succeeds. Manual `/reload` later must show the Debug
Log unchanged. The factory + theme are now consumable by `debugpanel.lua`.

---

## Phase 2 — The shared panel module (`src/aio/debugpanel.lua`)

> New file. Mirrors `dashboard.lua`'s shape (shared renderer + per-class data, 10 Hz `OnUpdate`,
> gated by a setting). Builds from `NS.CreateDebugWindow` — **do not** port chrome from `debugui.lua`
> (rejected bespoke `THEME`).

**2.1 — File skeleton + window.** `local NS = _G.Menagerie`; pull `DBG_THEME = NS.DBG_THEME`,
`CreateDebugWindow = NS.CreateDebugWindow`, `Player = NS.Player`, `Unit = NS.Unit`,
`rotation_registry = NS.rotation_registry`. Lazily `create_panel()` → `CreateDebugWindow("Menagerie
Debug")`, fixed width (~220 px per design), `SetSize` width + a placeholder height. Store
`panel_frame`. Guard re-entry (`if panel_frame then return panel_frame end`).
**Accept:** module loads; `create_panel()` returns a themed, narrow, sibling-of-the-log window.

**2.2 — The `out` writer + line pool.** A pooled FontString system (count varies, unlike debugui's
fixed 23). Each refresh: reset an accumulator **count to 0** (do not rebuild the table); builders fill
**pre-allocated, reused** entry tables in place — `out:header/out:kv/out:line` set fields on
`entries[++n]` (allocating a fresh `{}` only when the pool must grow past its high-water mark), never
emit `{kind=..., ...}` literals. This runs 10×/s **during combat**: while the panel is a plain
(non-secure) frame so a `{}` literal wouldn't *error* under the secure-environment rule (dashboard
allocates freely in its 10 Hz update), the CLAUDE.md "avoid allocations in hot paths" rule still applies
— pool the entry tables like `dashboard.lua` pools its `ui.*` slots. After building, assign the `n`
filled entries to pooled rows (grow on demand, hide extras), then set frame height =
`top_offset + n*lineH + padding`.
- `header`: one FontString, accent color, extra top padding.
- `kv`: **two** FontStrings — dim label (`text_dim`) clamped to a fixed label-column width, value at a
  constant x (optional hex color). This is the aligned-column primitive.
- `line`: one FontString, free-form (may carry `|cff…|r`).
**Accept:** a hand-written 3-section dummy builder renders aligned `label : value` rows in a column;
extra pooled rows hide; frame height tracks line count.

**2.3 — Generic core builder.** `build_generic_core(out)`.

> **Source-of-truth: read LIVE, not `ctx`.** `NS.last_rotation_context` is **stale or nil exactly when
> the panel is most used** — the dispatcher only refreshes it while the TMW icon is evaluating, and
> `main.lua:278` **nils it** in rested zones (inns/cities). `dashboard.lua:737` only trusts it within a
> **0.25 s** freshness window and otherwise falls back. So the generic core queries **live
> `NS.Player`/`NS.Unit`** as its **primary** source (always fresh, in or out of combat) and treats
> `ctx` as **optional enrichment** for computed fields that have no cheap live equivalent — and only
> when fresh. Mirror the dashboard guard: `local ctx = NS.last_rotation_context; if ctx and
> (GetTime() - (NS.last_rotation_context_time or 0)) > 0.25 then ctx = nil end`. This is why the
> builder takes no `ctx` arg — it reads the guarded handle itself.

- **PLAYER** (`out:header "PLAYER"`): HP% (`Player:HealthPercent()`), Mana% (`Player:ManaPercentage()`)
  — **omit the mana row for non-mana power types** (`UnitPowerType("player") == 0`, else skip rather
  than print a misleading `0`), GCD remaining (`Player:GCDRemains()`), In-Combat
  (`UnitAffectingCombat("player")`), Combat Time (`Unit("player"):CombatTime()`), Group/Solo
  (`IsInGroup()`).
- **TARGET** (`out:header "TARGET"`): rendered **only when** `Unit("target"):IsExists()`; otherwise a
  single dim `out:kv("Target", "none")`. When present: HP% (`Unit("target"):HealthPercent()`), Range
  (`Unit("target"):GetRange()`), In-Melee (min-range ≤ 5 from `GetRange`), Enemy
  (`UnitCanAttack("player","target")`). **Computed fields from the fresh `ctx` only** (no cheap live
  form): TTD (`ctx.ttd`), Phys/Magic immune (`ctx.target_phys_immune`/`ctx.target_magic_immune`),
  Boss/Elite (`ctx.is_boss`/`ctx.target_is_elite`) — each shown only when `ctx` passed the freshness
  guard, else omitted (or dimmed `—`).
- **Every access nil-guarded** (no target / no pet / `ctx == nil` → safe defaults).
**Accept:** with no target the panel shows PLAYER + a one-line `Target : none` and the window is short;
with a target the TARGET block fills in; **PLAYER/TARGET basics stay live out of combat and in a rested
zone** (they come from live `Player`/`Unit`, not the nilled `last_rotation_context`); the `ctx`-only
computed rows (TTD/immune) gracefully drop when the snapshot is stale rather than showing frozen values.

**2.4 — Refresh loop.** A 10 Hz `OnUpdate` frame: when `panel_frame` shown, reset the `out` accumulator,
run `build_generic_core(out)` (it reads its own fresh-guarded handle, 2.3), then compute the same
fresh-guarded `ctx` to hand the per-class provider — `local ctx = NS.last_rotation_context; if ctx and
(GetTime() - (NS.last_rotation_context_time or 0)) > 0.25 then ctx = nil end` — and
`local cc = rotation_registry.class_config; if cc and cc.debug_panel then cc.debug_panel(out, ctx) end`,
then lay out + size. (Read `class_config` at refresh time, like `dashboard.lua:727` — **not** captured at
load.) The provider signature stays `debug_panel(out, ctx)` per the design; `ctx` may be `nil` (stale or
no rotation yet), so providers nil-guard it (Hunter's does — 4.1).
**Accept:** open panel updates ~10×/s; a registered `class_config.debug_panel` appends below the
generic core; no error when none is registered or when `ctx` is `nil`.

**2.5 — Visibility wiring** (per design's Visibility model):
- `visible` runtime boolean. `Show()` sets `visible = true` + `panel_frame:Show()`; `Hide()` sets
  `visible = false` + `panel_frame:Hide()`.
- Re-point the factory close-X (`panel_frame.closeBtn:SetScript("OnClick", ...)`) to call `Hide()` —
  **does not** write the setting.
- 0.5 Hz watcher frame: **disable→hide only**. `if not NS.cached_settings.show_debug_panel and visible
  then Hide() end`. **No show branch** (do not port `debugui.lua`'s auto-show).
- `NS.toggle_debug_panel()` — the `/mdebug` handler: if `not NS.cached_settings.show_debug_panel`,
  print the hint (`enable "Show Debug Panel" first, then /mdebug`) and return; else flip `visible`
  (Show if hidden, Hide if shown), creating the panel lazily on first Show.

> **Read `NS.cached_settings` LIVE everywhere** (watcher + handler) — exactly as `dashboard.lua:1498`,
> `debugui.lua:367`, `adaptivepanel.lua:452` do. Do **not** introduce a module-local
> `local cached_settings = NS.cached_settings`: capturing it at load violates the CLAUDE.md "never
> capture settings at load time" rule and would read a stale table after the next `refresh_settings()`.
**Accept:** checkbox on → nothing opens; `/mdebug` opens; `/mdebug` again hides; close-X hides +
`/mdebug` reopens; checkbox off while shown → hidden within ~0.5 s; `/mdebug` while off → hint, no frame.

**2.6 — Slash registration.** Mirror `core.lua:1169–1171`:
```lua
SLASH_MENAGERIEDEBUG1 = "/mdebug"
SlashCmdList["MENAGERIEDEBUG"] = NS.toggle_debug_panel
```
Add a bottom hint on the panel (`/mdebug to toggle`), matching the log's affordance.
**Accept:** `/mdebug` resolves to `NS.toggle_debug_panel`; no clash with existing slashes.

**2.7 — Register in `builder.config.json`.** Add `{ "slot": "shared", "source": "debugpanel.lua",
"order": 8 }` to `loadOrder` (after `core.lua` order 4, alongside `dashboard.lua` order 8, before
`main.lua` order 9). Two shared files at order 8 is fine — no mutual deps, both before `main`.
**Accept:** `build` includes `debugpanel.lua` in `output/TellMeWhen.lua` between core and main.

**🚦 Phase 2 gate:** `lint:lua` clean + `build` succeeds. The panel works for **all 9 classes** with the
generic core only (no per-class hook yet). The checkbox doesn't exist yet (Phase 3), so test 2.5 by
temporarily forcing `cached_settings.show_debug_panel = true` in-game, or land Phase 3 first.

---

## Phase 3 — Settings schema (`common.lua`, `hunter/schema.lua`)

**3.1 — Add the shared checkbox.** In `common.lua` `_G.Menagerie_SECTIONS.debug` (28–39), add:
```lua
{ type = "checkbox", key = "show_debug_panel", default = false, label = "Show Debug Panel",
  tooltip = "Enable the live state debug panel, then use /mdebug to open it." },
```
All 9 schemas call `S.debug()`, so every class gets the toggle in one edit, and every settings refresh
populates `cached_settings.show_debug_panel` for the gate + watcher.
**Accept:** `grep -rn "show_debug_panel" common.lua` shows the new key; building any class surfaces a
"Show Debug Panel" checkbox on the Debug section.

**3.2 — Remove Hunter's bespoke checkbox.** In `hunter/schema.lua`, delete the `show_debug_panel` entry
(line **239**) from the "Debug Panel" group on Tab 5. **Keep `show_adaptive_panel` (241).** If that
leaves the "Debug Panel" group with only the adaptive toggle, that's fine (rename to taste is optional,
out of scope).
**Accept:** `grep -n "show_debug_panel" hunter/schema.lua` empty; `show_adaptive_panel` remains; Hunter
gets the toggle once (from the shared section), not twice.

**🚦 Phase 3 gate:** `lint:lua` + `build`. The shared checkbox drives the Phase-2 gate + watcher for
every class. Re-run the 2.5 acceptance for real now.

---

## Phase 4 — Hunter provider (`hunter/diag.lua`) + delete `debugui.lua`

**4.1 — Write `hunter/diag.lua`.** New file at the class default load order (7, after `class.lua`
order 5 so `class_config` exists). Port the **Debuffs / PvP / Pet** data-gathering faithfully from
`debugui.lua:198–323` (the `UpdateDisplay` body) — Serpent/Viper/Concussive/WingClip debuff timers,
the PvP Viper/Concussive/WingClip verdict logic, pet/PetLibrary state. **Do not** port Player/Target
(now the generic core) and **do not** port the bespoke `THEME`/frame/`Show`/`Hide`/watcher (the shared
renderer owns all of that). Re-express formatting with `out:header` + `out:kv` (one row per debuff
timer / verdict / pet field) instead of the old packed `L[n]:SetText(...)` lines. Register the provider
by **writing it onto the live `class_config` at load**:
```lua
if NS.rotation_registry and NS.rotation_registry.class_config then
    NS.rotation_registry.class_config.debug_panel = build_hunter_sections
end
```
> **Mechanism note (not adaptivepanel's pattern).** `adaptivepanel.lua` binds a *namespace global*
> (`NS.HunterAdaptive`) and reads it at refresh; this instead **writes a field onto `class_config`**.
> The write is safe at load because `register_class` sets `rotation_registry.class_config` from
> `class.lua` (order 5) and `diag.lua` loads at order 7 — so `class_config` is guaranteed non-nil; the
> guard is belt-and-suspenders. The *read* side is the dashboard pattern: the panel reads
> `class_config.debug_panel` at **refresh** time (2.4, like `dashboard.lua:727`), so load-order between
> `diag.lua` and `debugpanel.lua` is irrelevant.
**Accept:** on Hunter, `/mdebug` shows the generic PLAYER/TARGET core **plus** Debuffs/PvP/Pet
sections, in aligned `label : value` rows; every API access is nil-guarded (no target / no pet / spell
not trained → no error).

**4.2 — Delete `hunter/debugui.lua`.** After 4.1 verifies. No `builder.config.json` change needed
(class files auto-discover; removing the file removes it from the build).
**Accept:** `grep -rn "HunterDebug\b\|HunterDebugPanel\|debugui" src/aio` empty; `build` succeeds
(output regenerates without the file); the stale `/menagerie debug panel` comment is gone with it.

**🚦 Phase 4 gate:** `lint:lua` clean + `build` succeeds. Hunter content fully migrated; one coherent
panel system.

---

## Phase 5 — Final verification

**5.1 — Static gates.** `lint:lua` clean; `build` regenerates `output/TellMeWhen.lua`.

**5.2 — Manual `/reload` checklist** (no WoW in CI):
- [ ] **Log unchanged** — the Debug Log (`/mlog`) opens identically post-extraction (drag, close-X,
      separator, accent title, scrollbar). The factory was a pure refactor.
- [ ] **Enable ≠ open** — ticking **Show Debug Panel** opens **nothing**; `/mdebug` then opens the
      generic panel. Works on a non-Hunter class (generic core only) and on Hunter.
- [ ] **Toggle + close/reopen** — `/mdebug` toggles open/closed; close-X hides and `/mdebug` reopens;
      the watcher never re-opens on its own.
- [ ] **Disable hides** — unticking the checkbox hides an open panel within ~0.5 s.
- [ ] **Hint when off** — `/mdebug` with the checkbox off prints the "enable Show Debug Panel first"
      hint and opens nothing.
- [ ] **Layout reads clean** — titled PLAYER / TARGET (+ Hunter) sections, aligned `label : value`
      columns, narrow content-fit window (not full-screen). No target → TARGET collapses to one line
      and the window shrinks.
- [ ] **Live out of combat + rested** — PLAYER/TARGET basics update while idle out of combat **and in
      an inn/city** (where `last_rotation_context` is nilled), proving they read live `Player`/`Unit`;
      the `ctx`-only computed rows (TTD/immune) drop gracefully when the snapshot is stale, not freeze.
- [ ] **No /reload ghost** — open the panel, `/reload`, reopen: no doubled/ghost frame (unnamed frame).
- [ ] **Hunter parity** — Debuffs/PvP/Pet detail still shown (migrated), now under the generic core,
      visually a sibling of the Debug Log.
- [ ] **Sibling look** — panel chrome (backdrop/title/close-X/drag) matches the log because both come
      from `NS.CreateDebugWindow`.

**5.3 — Change summary** (per CLAUDE.md): files changed + why; the `debugui.lua` deletion called out;
residual concerns (line-pool has no scrollbar — fine for short panels; `last_rotation_context`
staleness mitigated by live `Player`/`Unit` queries for basics).

---

## Resolved decisions (from the design doc — settled with owner)

1. **Migrate, don't duplicate** — Hunter content → `class_config.debug_panel`; `debugui.lua` deleted.
2. **Generic core now, per-class hook later** — only Hunter authors a provider this pass; the other 8
   get the free generic core.
3. **Checkbox enables; `/mdebug` opens** — `show_debug_panel` is a quiet master enable (no auto-open);
   the watcher is disable→hide only; close-X never writes the setting.
4. **Theme = the log's `DBG_THEME`, via the shared `NS.CreateDebugWindow` factory** — sibling look is
   structural, not approximated; Hunter's bespoke `THEME` + BindPad's `UI_THEME` are left alone.
5. **Adaptive Engine Panel stays Hunter-only.**

## Out of scope (unchanged from design doc)

- Generalizing the **Adaptive Engine Panel** (`adaptivepanel.lua`).
- Authoring `debug_panel` providers for the other 8 classes (generic core only; add later via the hook).
- A `kv`-grid (multiple value cells per row) — single-value column is enough.
- Relocating the debug subsystem into a dedicated `debug.lua` (the design's forward note; if it lands
  first, `NS.CreateDebugWindow` + the `DBG_THEME` export simply live there and Phase 1 is "already
  provided").
- Unifying the three theme palettes beyond the `DBG_THEME` export this needs.
