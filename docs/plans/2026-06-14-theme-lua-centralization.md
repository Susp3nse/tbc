# Centralize styling into `theme.lua`

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> Design doc. **Re-grounded 2026-06-14 against the current tree** (after the log redesign, debug
> extraction, `CreateDebugWindow` factory, and shared debug panel all landed). This is now a
> **standalone** effort — it has no prerequisite plan; everything it touches already exists.

## Current state (verified 2026-06-14, final tree)

The diagnostic UI work is done. The debug subsystem now lives in its own `debug.lua`:

- **`debug.lua`** (shared, `loadOrder` **5**, after `core.lua`) holds the debug substrate **including**
  `DBG_THEME`/`DBG_BACKDROP` (exported `NS.DBG_THEME`/`NS.DBG_BACKDROP`), `DBG_CAT` (log layer colors),
  and the `NS.CreateDebugWindow(title)` chrome factory the log builds on. It opens with
  `local NS = _G.Menagerie; if not NS then return end` — i.e. it **relies on `core.lua` having created
  the namespace**.
- `debugpanel.lua` (shared, order 9) consumes `NS.CreateDebugWindow` + `NS.DBG_THEME`.
  `hunter/diag.lua` is its Hunter provider. `hunter/debugui.lua` is **deleted**.
- The namespace `_G.Menagerie` is created in **`core.lua:48`** (`_G.Menagerie = _G.Menagerie or {}`).
- **`core.lua` is no longer a palette holder or consumer** — `DBG_THEME` moved to `debug.lua`. This
  simplifies the theme load order (below).

### The problem: 6 palettes, 2 looks

| File | Look | Accent | Notes |
|---|---|---|---|
| `debug.lua` `DBG_THEME` | **Warm Menagerie** | `#e08a3c` | exported as `NS.DBG_THEME`; used by log + panel |
| `dashboard.lua` `THEME` | **Warm Menagerie** | `#e08a3c` | + threat/buff semantic colors |
| `settings.lua` `THEME` | **Warm Menagerie** | `#e08a3c` | + layout metrics (frame/tab/row dims) |
| `hunter/adaptivepanel.lua` `THEME` | Cool blue/purple | `#6c63ff` | + `text_section`/good/warn/bad/chosen |
| `hunter/cliptracker.lua` `THEME` | Cool blue/purple | `#6c63ff` | |
| `hunter/meleeweave.lua` `THEME` | Cool, semantic-only | (none) | `panel`/`dim`/`gray` + green/yellow/orange/red |

Two facts drive the plan:

1. **The 3 warm palettes are near-duplicates.** Same `accent` `#e08a3c`, `text` `#ece3d2`, `border`
   `#332b20`, `text_dim` `#b3a587`. They differ only in `bg` (settings/dashboard `#16130f`, the log a
   hair different at `#18140f`) and per-window **alpha** (0.97 / 1.0 / 0.75), plus which keys each
   needs. Centralizing them is a **zero (perceptual) visual change** dedup.
2. **The 3 Hunter palettes were never rebranded.** They're still pre-rebrand blue. "Make everything
   one styling" = **finish the rebrand**: recolor the Hunter panels warm. A real, intended visual
   change, isolated to Hunter's diagnostic windows.

## Goal

One source of truth — `NS.Theme` — so a recolor/reskin is a **one-file edit**, with **per-class
accent** identity layered on top without re-scattering palettes.

## Decisions

1. **Canonical palette = the warm Menagerie look.** Hunter's blue folds onto it (completes the
   rebrand), not the reverse.
2. **`theme.lua` owns colors only** — structural chrome **plus** semantic state colors. Settings-UI
   **layout metrics** (`frame_w`, `tab_h`, `row_h`, `pad`, …) stay local to `settings.lua`; they're
   layout, not styling.
3. **`theme.lua` is pure data, loads first, and self-bootstraps the namespace** so it's available to
   every consumer (`debug.lua` 5, `settings` 7, hunter 8, `dashboard` 9) with **no renumbering** of the
   existing `loadOrder`. See Load order.
4. **Per-class accents (curated).** Structural + semantic are shared; only `accent` swaps per the
   framework's `A.PlayerClass` from a **curated, warm-harmonized** map (not raw `RAID_CLASS_COLORS`).
   Default = Menagerie orange. Additive (Phase 4).

## What `theme.lua` exposes

```lua
_G.Menagerie = _G.Menagerie or {}          -- self-bootstrap: theme.lua loads first (order 1)
local NS = _G.Menagerie

NS.Theme = {
  -- structural chrome (canonical warm; alpha applied at the call site, NOT stored here)
  bg          = { 0.086, 0.075, 0.059 },   -- #16130f
  bg_light    = { 0.110, 0.094, 0.071 },   -- #1c1812
  bg_widget   = { 0.118, 0.102, 0.078 },   -- #1e1a14
  bg_hover    = { 0.149, 0.125, 0.102 },   -- #26201a
  border      = { 0.200, 0.169, 0.125 },   -- #332b20
  accent      = { 0.878, 0.541, 0.235 },   -- #e08a3c  (DEFAULT; class-resolved in Phase 4)
  accent_dim  = { 0.773, 0.447, 0.165 },   -- #c5722a  (derived from accent)
  accent_bg   = { 0.141, 0.102, 0.063 },   -- #241a10  (derived from accent)
  text        = { 0.925, 0.890, 0.824 },   -- #ece3d2
  text_dim    = { 0.702, 0.647, 0.529 },   -- #b3a587
  text_header = { 0.925, 0.890, 0.824 },   -- #ece3d2

  -- semantic state (consolidated from dashboard threat_* + adaptivepanel good/warn/bad + meleeweave)
  state = {
    good   = { 0.20, 0.90, 0.20 },   -- threat_green / good / meleeweave green
    warn   = { 1.00, 0.67, 0.20 },   -- threat_orange / warn / orange
    bad    = { 1.00, 0.20, 0.20 },   -- threat_red / bad / red
    chosen = { 0.60, 1.00, 0.60 },   -- adaptivepanel "chosen"
    gold   = { 0.85, 0.70, 0.20 },   -- dashboard buff_active
  },
}
```

### Alpha is a call-site concern, not palette identity

The 3 warm copies hard-code different `bg` alphas. Store RGB once; pass alpha where used:
`SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.75)`. This reproduces each window's current
translucency exactly. (Avoid a `{r,g,b,a}` allocator in hot/combat paths per the Lua/WoW rules.)

Canonicalizing `bg` to `#16130f` shifts the **log** window's bg by ~0.008 RGB (`#18140f`→`#16130f`) —
perceptually nil; Phase 1's "looks identical" check covers it.

## Per-class accents (class themes)

Shared chrome + semantic; only `accent` varies, so a class gets identity without re-scattering.

```lua
-- curated, warm-harmonized — reads against the warm dark bg, NOT raw RAID_CLASS_COLORS
local CLASS_ACCENTS = {
  WARRIOR = { 0.78, 0.61, 0.43 },  -- #c79c6e  tan
  PALADIN = { 0.85, 0.55, 0.55 },  -- #d98c8c  warm rose
  HUNTER  = { 0.42, 0.75, 0.35 },  -- #6cbf5a  warm green
  ROGUE   = { 0.88, 0.75, 0.38 },  -- #e0c060  warm amber
  PRIEST  = { 0.85, 0.79, 0.69 },  -- #d8c9b0  warm bone
  SHAMAN  = { 0.31, 0.61, 0.77 },  -- #4f9bc4  warm blue
  MAGE    = { 0.31, 0.70, 0.77 },  -- #4fb3c4  warm teal
  WARLOCK = { 0.65, 0.49, 0.77 },  -- #a584c4  warm mauve
  DRUID   = { 0.85, 0.48, 0.24 },  -- #d97b3c  burnt orange
}
local class = _G.A and _G.A.PlayerClass    -- framework global; NS.A isn't set this early
NS.Theme.accent = (class and CLASS_ACCENTS[class]) or { 0.878, 0.541, 0.235 }  -- default Menagerie orange
```

- **`accent_dim`/`accent_bg` must derive from the resolved accent** (a class accent with an orange
  dim/bg would mismatch). Derive at load: `accent_dim` ≈ accent × 0.82 luminance; `accent_bg` = accent
  darkened to a low-value tint. One helper keeps the three in sync.
- **`A.PlayerClass` timing:** read the **framework global `_G.A`**, not `NS.A` (which isn't populated
  when `theme.lua` runs first). If even `_G.A` isn't ready that early, resolve `accent` lazily on first
  read or in an early `PLAYER_LOGIN` hook. The `class and` guard above already no-ops to the default.
- Swatches are **starting points** — tune in-game. They're deliberately desaturated/warmed vs
  Blizzard's class colors so windows stay cohesive.

## Load order & namespace

The earliest consumer is `debug.lua` (order **5**); `core.lua` (4) creates `_G.Menagerie` but is **no
longer a consumer**. So `theme.lua` just needs to run **before order 5** with the namespace available.
Cleanest, lowest-churn: load it **first** and have it **self-bootstrap** the namespace with the same
idempotent one-liner `core.lua:48` already uses (`_G.Menagerie = _G.Menagerie or {}`) — `core.lua`'s
line then becomes a harmless no-op and `NS.Theme` survives (`or {}` never overwrites).

- Add `{ "slot": "shared", "source": "theme.lua", "order": 1 }` to `builder.config.json` `loadOrder`.
  Tie with `common.lua` at order 1 is fine — neither depends on the other, and `theme.lua` self-creates
  the namespace it needs. **No other entry is renumbered.**
- Update the **CLAUDE.md load-order list** to insert `theme.lua` at the top (it currently starts at
  `common.lua`).
- **Alternative (convention-strict):** instead of self-bootstrapping, renumber `debug.lua` 5→6 and
  everything after by +1, and slot `theme.lua` at 5 right after `core.lua` so it can use the standard
  `local NS = _G.Menagerie; if not NS then return end`. Rejected as the default — it churns 6
  `loadOrder` entries plus the just-updated CLAUDE.md list for no functional gain.

## Consumers & per-file migration

Each consumer drops its local palette table and reads `NS.Theme`; normalize key names.

| File | Change | Visual delta |
|---|---|---|
| `debug.lua` | `DBG_THEME` table → `local DBG_THEME = NS.Theme`; keep `NS.DBG_THEME = NS.Theme` as an alias so `debugpanel.lua` keeps working. `CreateDebugWindow` + the log already read `DBG_THEME`. Leave `DBG_CAT` and `DBG_BACKDROP` as-is (see below). | none (≤0.008 bg) |
| `debugpanel.lua` | `local DBG_THEME = NS.DBG_THEME` → optionally `NS.Theme` (alias makes this a no-op) | none |
| `dashboard.lua` | `THEME` → `NS.Theme`; `threat_*`/`buff_active` → `NS.Theme.state.*` | none |
| `settings.lua` | `THEME` colors → `NS.Theme`; **keep** the layout-metrics block as a local | none |
| `hunter/cliptracker.lua` | blue `THEME` → `NS.Theme` | **blue → warm** |
| `hunter/adaptivepanel.lua` | blue `THEME` (+ `text_section`/good/warn/bad/chosen) → `NS.Theme` (+ `state.*`); map `text_section`→`accent` | **blue → warm** |
| `hunter/meleeweave.lua` | semantic `THEME` (`panel`/`dim`/`gray`/`green`/…) → `NS.Theme` + `state.*`; normalize key names (`panel`→`bg_widget`, `dim`→`text_dim`) | **blue → warm** |

**`DBG_THEME` alias decision:** `debug.lua` keeps `NS.DBG_THEME = NS.Theme`, so `debugpanel.lua` needs
no edit. (Repointing `debugpanel` at `NS.Theme` and dropping the alias is a fine cleanup, but optional.)

**Left in `debug.lua` (out of scope this pass):**
- `DBG_CAT` — the log's per-LAYER src-cell colors (`forced`/`ctx`/`mw`/`action`). Log-internal semantic
  coloring, not general chrome. Could later map `forced`→`state.warn`, but leave it for now.
- `DBG_BACKDROP` — a backdrop *template* (edge/bg files + insets), not a palette.

## Phasing

**Phase 1 — Create `theme.lua` + migrate the warm group (zero visual change).**
1. Write `theme.lua` (`NS.Theme` above + the namespace self-bootstrap one-liner); add
   `{ "slot": "shared", "source": "theme.lua", "order": 1 }` to `builder.config.json`; add `theme.lua`
   to the CLAUDE.md load-order list.
2. Repoint `debug.lua` (`DBG_THEME` → `NS.Theme`, keep the `NS.DBG_THEME` alias), `dashboard.lua`,
   `settings.lua` at `NS.Theme`; apply alpha at call sites; keep settings layout metrics local.
3. `lint:lua` + `build`. **Accept:** settings / dashboard / debug log / debug panel look **identical**.

**Phase 2 — Recolor the Hunter panels (intended blue → warm).**
4. Repoint `cliptracker.lua`, `adaptivepanel.lua`, `meleeweave.lua` at `NS.Theme` + `state.*`;
   normalize key names.
5. `lint:lua` + `build`. **Accept:** Hunter panels render warm, consistent with the rest;
   `grep -rn "0.424, 0.388\|0.031, 0.031, 0.039" src/aio` empty.

**Phase 3 — Verify single source.**
6. `grep -rn "THEME = {" src/aio` returns only `theme.lua`. Any new window reads `NS.Theme`.

**Phase 4 — Per-class accents (additive).**
7. Add `CLASS_ACCENTS`; resolve `NS.Theme.accent` from `A.PlayerClass`; derive `accent_dim`/`accent_bg`.
   **Accept:** each class tints accents to its curated color; chrome + semantic unchanged across
   classes; unknown class → orange. No consumer edits (they already read `Theme.accent`).

## Risks / open questions

- **Alpha regressions.** Mis-porting a `bg` alpha shifts a window's translucency. Phase 1's identical-
  look check targets exactly this.
- **Hunter semantic shade shifts.** `meleeweave`/`adaptivepanel` use their own state shades (e.g.
  meleeweave `green` `{0.10,0.78,0.28}` vs `state.good` `{0.20,0.90,0.20}`). Consolidating nudges those
  shades — intended (unification), but call it out so it isn't read as a bug.
- **`A.PlayerClass` availability** at theme load (Phase 4) — resolve lazily if it isn't ready that early.
- **`DBG_BACKDROP`** is a backdrop template (edge/bg files + insets), not colors — left as-is.

## Out of scope

- Settings layout metrics centralization (stays local to `settings.lua`).
- A runtime theme **engine** (user-selectable palettes / live switching). `NS.Theme` is a static table;
  a picker is cheaply enabled later by swapping it.
- Fonts, textures, `DBG_BACKDROP` — colors only this pass.
