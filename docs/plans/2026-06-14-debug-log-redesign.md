# Debug Log Redesign — readable layout + a scrollbar that tracks content

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> **Taxonomy revised 2026-06-14 (brainstorm).** The original `cat`(ACT/MW/CTX) + nullable-`ps` model
> is **superseded**. A log line now has three orthogonal axes — **LAYER**, **OWNER**, **KIND** — plus
> a `forced` flag, and **context is a per-line attached payload, not a log line**. The frame
> architecture (FauxScrollFrame + virtualized row pool) is unchanged from the first draft; only the
> data model and what renders in the columns changed. See **Taxonomy** below.

## Context

The Debug Log is the text stream opened by `/menagerielog` (`/mlog`), built entirely in
`core.lua`. It is the all-class diagnostic stream — `debug_print(...)` lines, middleware traces,
strategy decisions, periodic state. It is **not** the Combat Dashboard and **not** the state Debug
Panel (that one is covered by `2026-06-14-shared-debug-panel-design.md` — different UI, don't conflate).

Two concrete complaints from the owner drive this redesign:

1. **The scrollbar does not track the content.** You can keep wheeling up after the thumb is already
   pinned to the top; the thumb position/size is misaligned with the real content extent.
2. **The log is an unreadable run-on dump** — lines are shoved together with no structure. It should
   read like a log: scannable, with the time, source, and event visually separated from the message.

The owner's real end-goal for copy: **paste the log somewhere and have everything needed to debug a
problem** — the decision stream *and* the state behind each decision, in clean text.

### Root cause of the scroll bug (why it can't just be patched)

`sync_scrollbar()` computes the slider's range from a **hardcoded line height**:

```lua
local LINE_H = 11
local visible    = math.floor((smf:GetHeight() or 200) / LINE_H)
local max_offset = math.max(0, num - visible)
scrollbar:SetMinMaxValues(0, max_offset)
```

`LINE_H = 11` is a guess at the rendered height of the size-9 font. It does not match what the
`ScrollingMessageFrame` (SMF) uses internally, so `visible` — and therefore `max_offset` — diverges
from the SMF's *real* maximum scroll. The mouse wheel drives the SMF directly (`ScrollUp`/`ScrollDown`),
which scrolls past the slider's computed max. Result: the thumb sits at the top while the content
keeps moving. The SMF exposes no clean API to read its true max scroll, so the slider can't be reliably
synced to it. **The widget choice is the bug.**

Separately, an SMF is single-justify text — it **cannot** render aligned columns. So both complaints
resolve to the same conclusion: move off the SMF.

## Taxonomy — three orthogonal axes + a flag

The first draft used a `cat` column (`ACT`/`MW`/`CTX`) plus a nullable `ps` column. That conflated two
different questions: `MW` answers *"which layer?"* while `ACT`/`CTX` answer *"what kind of event?"* —
and `ps` was a second, incomplete copy of the *"who?"* question. The **warrior auto-tab** line is the
counterexample that breaks the old model: it is *middleware by layer* **and** *warrior by owner* at the
same time, so "MW" and "WAR" can't be mutually-exclusive values in one column.

The clean decomposition is three independent axes:

| Axis | Question | Values | Always present? |
|------|----------|--------|-----------------|
| **LAYER** | which pipeline phase emitted it | `MW` (middleware) · `STRAT` (rotation/strategy) · `SYS` (core/plumbing) | yes |
| **OWNER** | whose code | a class/playstyle (`BM`, `BEAR`, `WAR`, `ENH`, `SHADOW`…) or **none** | optional |
| **KIND** | what happened | `ACT` (action chosen) · `EXEC` (executed) · `NOOP` (no action) · `TRACE` (freeform diagnostic) | yes |

Plus one orthogonal flag:

- **`forced`** — any layer/kind can be forced. It is **not** a value on any axis; it tints the message
  orange and keeps an inline `[FORCED]` marker (so it survives plain-text copy).

**OWNER = the file's home.** The codebase already encodes ownership by where a file lives, so the
emitting site reads its owner from its location — never invents it:

- A **playstyle file** logs that playstyle: `druid/bear.lua` → `BEAR`, `shaman/enhancement.lua` →
  `ENH`, `priest/shadow.lua` → `SHADOW`.
- A **class-level module** logs the class: `druid/healing.lua` → `DRUID` (the Druid healing module),
  `hunter/rotation.lua` → `HUNTER` (the class rotation path).
- **Class-wide middleware** logs the class (`warrior/middleware.lua` auto-tab → `WAR`).
- **Generic/shared plumbing** has no owner (`SYS`, or `MW` for dispatcher-logged middleware).

So OWNER is "the most-specific scope the file represents" — a playstyle when the file *is* a
playstyle, the class when it's a class-level module. Not forced to one or the other.

### The `src` column = `LAYER:OWNER` (compound)

LAYER and OWNER render together in **one** column as `LAYER:OWNER`, with the `:OWNER` suffix **omitted
when there's no owner**:

- `MW:WAR` — warrior auto-tab (middleware layer, warrior-owned)
- `STRAT:BM` — a BM hunter rotation decision
- `MW` — generic/shared middleware the dispatcher logs (no class owner)
- `SYS` — core plumbing, no owner

This keeps the row at **four columns** (`time │ src │ kind │ message`) while encoding all three axes,
and it stays filterable on either sub-axis (`MW:*` for all middleware, `*:WAR` for all warrior).

## Decisions locked in

1. **Replace the ScrollingMessageFrame.** The SMF + hand-rolled `Slider` go away.
2. **Aligned columns — `time │ src │ kind │ message`.** `src` is the compound `LAYER:OWNER` (LAYER-
   colored); `kind` is the event (neutral — no `DBG_CAT` color). Both survive plain-text copy. `forced`
   is a flag (orange message tint + inline `[FORCED]`), not a column value.
3. **Full clean copy, with per-line context.** Copy yields verbatim `[ts] [SRC] [KIND] message` text
   with **no color codes**, and each line's attached context indented beneath it. This is the owner's
   "everything I need to debug" in one paste. (No "minified" mode.)
4. **Theme = the existing `DBG_THEME`** warm palette — unchanged.
5. **The log owns the timestamp.** Callers stop baking their own (today they're inconsistent:
   wall-clock in `debug_print`, `[%.3fs]` GetTime in `bear.lua`). One format (`HH:MM:SS.t`), one column.
6. **Explicit `src`/`kind`/`forced`, killing the classifier.** All three are passed into a new
   `NS.debug_log(src, kind, forced, fmt, ...)` entry point, not inferred by `string.find` on the
   rendered line. The call **returns the inserted entry** (or `nil` when throttle-suppressed) so the
   caller can attach this line's context to it (decision #8). The fragile `debug_line_color` scan is
   deleted.
7. **Thread `src` at every call site.** Because OWNER is only knowable at the emitting code (the
   warrior file knows it's warrior), every call site passes its own `src` explicitly. There are **no
   "untouched" generic sites** — the shims remain only as a safety net (default `SYS`/`TRACE`).
8. **Context is a per-line attached payload, not a log line.** The periodic CTX dump line is
   **removed**. Each dispatcher decision (`ACT`/`EXEC`/`NOOP`) captures the context it saw as the
   **curated string `config.format_context_log(context, state)` already produces** — the same
   playstyle-authored summary the old CTX line rendered — attached to the entry and surfaced on
   **hover** and in **copy**, never inline. Capturing the *formatted string* (not the live table)
   freezes the snapshot, so the reused `reusable_context` table can't retro-mutate history. This reuses
   `format_context_log` + the `log_context` setting (otherwise orphaned) and dissolves the old CTX-line
   truncation + time-correlation problems (state travels *with* the decision that used it).
9. **Throttling is uniform and content-keyed.** The throttle lives in `debug_log` so every entry point
   throttles identically, keyed on `src|kind|text`. A throttle-suppressed repeat returns `nil` and does
   **no** work — the row stays collapsed and its context is **not** refreshed (the snapshot is from
   first insert; hover can be up to one throttle-window — ~1.5s — stale). Refreshing every suppressed
   frame would recompute the curated string ~120×/s for a sub-second freshness gain; the staleness is
   bounded by the window and not worth that cost. See "Throttling".

## Architecture — `FauxScrollFrame` + a virtualized row pool

The fix for "scrollbar tracks content" is to stop computing the range by hand and let Blizzard's own
scroll machinery do it. `FauxScrollFrameTemplate` is the standard idiom: you tell it the item count,
the visible count, and the row height, and `FauxScrollFrame_Update` sizes and positions the thumb
correctly **by construction**. It ships with the real `UIPanelScrollBarTemplate` scrollbar (up/down
arrows + draggable thumb), which we lightly skin to `DBG_THEME`.

It is also **virtualized**: only ~`numToDisplay` row widgets exist (enough to fill the viewport). On
scroll, those rows are repainted from the backing entry buffer at the new offset. A 500-line cap costs
~25 row frames, not 500 — cheaper than the SMF, and it gives us real per-row column FontStrings (which
the SMF could never do).

```
┌─ Debug Log frame (DBG_THEME chrome: drag, close X, resize, toolbar) ─────┐
│  Title: "Menagerie Debug Log"                              [x]           │
│ ──────────────────────────────────────────────────────────────────────  │
│  ┌─ ScrollFrame (FauxScrollFrameTemplate) ────────────────┐  ║          │
│  │ 18:42:01.3 │ MW:WAR   │ ACT  │ Auto Tab → cycling …    │  ║  ← real  │
│  │ 18:42:01.4 │ MW       │ EXEC │ Trinket (haste) ready   │  ║   Bliz   │
│  │ 18:42:02.0 │ STRAT:BM │ ACT  │ [FORCED] Bestial Wrath  │  ║   bar    │
│  │ 18:42:02.1 │ STRAT:BM │ NOOP │ (waiting on focus)      │  ║          │
│  │  …repainted from entry buffer at current offset…        │  ║          │
│  └────────────────────────────────────────────────────────┘            │
│ ──────────────────────────────────────────────────────────────────────  │
│  /menagerielog to toggle                          [ Copy ] [ Clear ]    │
└──────────────────────────────────────────────────────────────────────────┘
   └ time ┘└ src=LAYER:OWNER ┘└ kind ┘└ message (orange tint when forced) ┘
```

(Row 3 is forced → message tinted orange + `[FORCED]` kept inline; `src`/`kind` columns stay clean.
Generic middleware (row 2) has no owner, so its `src` is just `MW`. Hovering any row reveals that
line's attached context.)

### Row layout (the "aligned columns")

Each visible row is a small `Frame` with four `FontString`s at fixed x-offsets:

- **time** — left-anchored, `DBG_THEME.text_dim`, the centrally-stamped `HH:MM:SS.t`. FRIZQT digit
  glyphs are equal-width, so the column aligns down the rows even in a proportional font.
- **src** — fixed-width column after time, the compound `LAYER:OWNER` string. Colored by LAYER (look
  up `DBG_CAT` by layer: `MW` cyan, `STRAT` text, `SYS` dim); the `:OWNER` suffix renders in the same
  cell. Always present (no column-drop — generic lines simply show `MW`/`SYS` with no suffix).
- **kind** — fixed-width column after src, the event tag `ACT`/`EXEC`/`NOOP`/`TRACE`.
- **message** — anchored after kind, `SetWordWrap(false)` + truncated to the row width with an
  ellipsis. Color is `DBG_THEME.text`, or `DBG_CAT.forced` (orange) when `entry.forced`. The full line
  and its context are always available via Copy and the row hover tooltip (below).

Keep `src` and `kind` short so the columns stay narrow; fixed row height (e.g. 12px) is what makes
virtualization + the FauxScrollFrame math exact.

### Per-line context — the hover tooltip + copy (first-class)

Context is no longer a line. It's the **curated string `config.format_context_log(context, state)`
returns** — captured at insert time and attached to the entry as `entry.ctx`. It surfaces two ways:

- **Hover tooltip.** `GameTooltip` anchored to the row: a dim header line (`ts │ SRC │ KIND`), the full
  untruncated **message** word-wrapped at a comfortable width (~400px), then — if the entry has
  context — the `ctx` string rendered beneath it (its own lines preserved; the playstyle already
  formats it readably). Forced lines keep their orange message tint in the tooltip.
- **Copy.** Each entry copies as `[ts] [SRC] [KIND] message`, and if it has context, the `ctx` string is
  indented beneath it (see "Follow-tail + copy"). Clean text, no `|cff` codes.

**The caller owns context; the renderer just displays it.** `format_context_log` is the playstyle's own
summary (the same function that fed the old CTX line), so capturing its output preserves the existing
curated layout — no reformatting, no `pairs()` ordering concerns. The string is captured **once, on the
insert that creates the row** (the caller attaches it to the returned entry), gated by the existing
`log_context` setting. Because strings are immutable, the snapshot is frozen at insert — it can't be
retro-mutated by the reused `reusable_context` table the way a captured *reference* would. A playstyle
without a `format_context_log` simply attaches no `ctx` (the line still logs; hover omits the block).

**Pooled-row safe.** Rows are reused, so `OnEnter` reads `buffer[FauxScrollFrame_GetOffset(scrollFrame)
+ rowIndex]` at hover time (the entry is derived from the row's live offset — `rowIndex` is stored on
the row frame), never closing over a fixed entry.

### Data model — structured entries

The buffer holds pre-split, pre-categorized entries so repaint is pure layout (no scanning):

```lua
-- each entry: {
--   ts     = "18:42:01.3",         -- stamped centrally at insert
--   src    = "STRAT:BM" | "MW" | "MW:WAR" | "SYS",  -- compound LAYER:OWNER
--   kind   = "ACT" | "EXEC" | "NOOP" | "TRACE",
--   forced = true | nil,           -- flag: tints message + inline [FORCED]
--   text   = "Steady Shot",
--   ctx    = "focus 72 · ttd 14.2 · range 8" | nil,  -- format_context_log() string, attached on insert
-- }
```

`ts` is stamped at insert; `src`/`kind`/`forced` are supplied by the caller, and `ctx` is attached to
the **returned** entry on insert (decision #8); color comes from `DBG_CAT` (keyed by LAYER for the
`src` cell, `forced` for a forced message tint). Repaint just reads these.

### Categorization — explicit and threaded everywhere

`src`/`kind`/`forced`/`ctx` are passed in at the call site. The dispatcher in `main.lua` owns the
high-frequency categorized lines and already has `playstyle`, `forced`, and the `context` table in
scope, so threading them is free:

| Site | Today | New `src` / `kind` / `forced` (+ `ctx` attached on insert) |
|------|-------|----------------------------------------|
| `main.lua` middleware (×3) | `[MW] …` / `[MW] EXECUTED/NO_ACTION …` | `src="MW"`, `kind=ACT/EXEC/NOOP`, `forced`; if inserted & `log_context`, `e.ctx = format_context_log(context, state)` |
| `main.lua` context dump (×1) | `[PLAYSTYLE CTX] …` | **removed as a line** — its `format_context_log` string becomes the `ctx` attached to the dispatcher decisions |
| `main.lua` strategies (×3) | `[PLAYSTYLE] …` / `EXECUTED/NO_ACTION` | `src="STRAT:"..playstyle:upper()`, `kind=ACT/EXEC/NOOP`, `forced`; same `format_context_log` attach on insert |
| `warrior/middleware.lua` auto-tab | `[MW] Auto Tab …` (logs directly) | `src="MW:WAR"`, `kind=ACT`, `forced=false` |
| `druid/bear.lua` ×5 | `[%.3fs] [MAUL] / [TAB TARGET] / [GROWL] …` | `src="STRAT:BEAR"`, `kind=ACT/TRACE`, drop the GetTime stamp (freeform traces — no `ctx`) |
| generic sites (healing, shadow, hunter/rotation, shaman) | plain | thread their real `src` (e.g. `STRAT:SHADOW`), `kind=TRACE` (no `ctx`) |

Middleware the dispatcher logs is class-agnostic plumbing → `src="MW"` (no owner). Middleware a class
file logs directly (warrior auto-tab) knows its owner → `src="MW:WAR"`. This owner distinction is the
whole reason for threading `src` explicitly.

### New API

```lua
NS.debug_log(src, kind, forced, fmt, ...) -> entry | nil
--   src    = "STRAT:BM" | "MW" | "MW:WAR" | "SYS"   (compound LAYER:OWNER)
--   kind   = "ACT" | "EXEC" | "NOOP" | "TRACE"
--   forced = boolean                                (orthogonal flag)
--   fmt,…  = format string + args for the message body
-- stamps ts, throttles on src|kind|text; on PASS stores { ts, src, kind, forced, text }
-- and RETURNS the entry; on throttle-suppress returns nil and does nothing else.
```

Context is attached **by the caller**, only when an entry comes back:

```lua
local e = NS.debug_log("STRAT:BM", "ACT", forced, "%s", action)
if e and config.log_context and config.format_context_log then
  e.ctx = config.format_context_log(context, state)   -- curated string, frozen at insert
end
```

This keeps `ctx` out of the hot signature, computes the curated string **only on inserts that survive
the throttle**, and respects the `log_context` toggle for free.

`debug_print(...)` and `AddDebugLogLine(text)` become thin **back-compat shims** onto `debug_log`
(`debug_log("SYS", "TRACE", false, "%s", joined/text)`, ignoring the return) so any caller we don't
explicitly thread still works and still throttles. Most call sites *are* threaded (decision 7); the
shims are a net, not the main path. `debug_line_color` and its `sfind` scans are **deleted**.

### Throttling — uniform, content-keyed

The throttle lives in `debug_log` so **all** lines pass through it:

- **One throttle, one window.** `debug_log` computes `key = src.."|"..kind.."|"..text`, checks it
  against the existing throttle cache (unchanged 1.5s window + 30s prune / 60s TTL), and **only on
  pass** stamps `ts`, inserts the structured entry, trims, repaints, and **returns the entry**. A line
  stuck on the same code path inserts at most once per 1.5s; suppressed repeats return `nil`.
- **Context is captured on insert only — no refresh.** A suppressed repeat does no work, so its attached
  `ctx` keeps the snapshot from first insert (hover may be up to one throttle-window — ~1.5s — stale).
  Deliberate: refreshing the curated string on every suppressed frame would recompute
  `format_context_log` ~120×/s for a sub-second freshness gain. The throttle window bounds the staleness.
- **The message text is built *before* the throttle.** The key includes `text`, so `format(fmt, …)`
  runs on every call (cheap). Only the entry insert and the `ctx` capture are gated to throttle-pass —
  the string build is **not** "deferred."
- **No magic-string keys.** The content *is* the key. `EXEC Steady Shot` renders identical text every
  frame → collapses cleanly.
- **Known edge (same as today): volatile text doesn't collapse.** A line that bakes a changing value
  into its text (`Auto Tab → … (HP: 45%)`, attempt counters) produces a new key each frame and won't
  batch. These sites are event-driven or low-frequency; acceptable. The fix, if ever needed, is to
  round/drop the volatile field in the format string — not a key constant.
- **`shaman/enhancement.lua`** calls `debug_print(key, msg)` with two args. The two strings are joined
  for the body; the join is *value*-stable (same inputs → same text → same key), so the migration
  doesn't change its throttle behavior — no special-casing needed.

**Color table — `src` only.** `DBG_CAT` already has the keys for the **`src`** cell: `mw` (cyan) for
the `MW` layer, `action` (text) for `STRAT`, `ctx` (dim) for `SYS`, and `forced` (orange) for a forced
message tint. The `:OWNER` suffix renders in the same cell as its LAYER. The **`kind`** cell has **no**
`DBG_CAT` entry — it renders neutral (`DBG_THEME.text_dim`), a distinct column but not per-kind colored.
Per-kind tints (e.g. NOOP dimmer than ACT) are an easy follow-up but are **out of scope here** — so
acceptance must not assert "kind is color-coded."

### Central timestamp (enabler for the time column)

`debug_timestamp()` already exists (`HH:MM:SS.t`, exported). The log stamps every entry with it;
callers stop prepending timestamps:

- `debug_print` / `debug_log`: stamp `debug_timestamp()` into `entry.ts`; callers pass only the body.
- `main.lua` context dump: removed as a line (its state becomes attached `ctx`).
- `bear.lua` (×4 `AddDebugLogLine`): drop the `[%.3fs]` GetTime prefix; use the shared tenths column.

### Follow-tail + copy (preserve current UX, add context)

- **Newest at bottom + auto-follow.** Items render oldest→newest, **always in insert/timestamp order.**
  There is **no column sorting** — the columns are read-only labels, never click-to-sort headers; the
  log's order is the chronology. On a new line, if the view is at the bottom, snap the FauxScrollFrame
  offset to max; if the user has scrolled up, leave it put.
- **Copy** builds a `tconcat` over the buffer into the existing copy-popup EditBox for `Ctrl+C`:
  - one header line per entry: `[ts] [SRC] [KIND] message`;
  - if the entry has `ctx`, the `format_context_log` string indented beneath it.
  Full, clean, no color codes — the owner's "everything to debug" paste.
- **Clear** empties the buffer and repaints (one `FauxScrollFrame_Update` with 0 items).

## File-by-file changes

All display changes are confined to `core.lua`. `builder.config.json` is **unchanged** (no new
module). Files outside `core.lua`: `main.lua` (dispatcher src/kind/ctx + remove CTX line),
`warrior/middleware.lua` (auto-tab), `druid/bear.lua` (src/kind + timestamp), and the generic sites
(`druid/healing.lua`, `priest/shadow.lua`, `hunter/rotation.lua`, `shaman/enhancement.lua`) which now
thread their `src` explicitly. Exact line targets live in the companion impl plan
(`2026-06-14-debug-log-redesign-impl.md`).

### `core.lua` — the debug-log block

**Data + logging API:**
- `debug_log_lines` → structured entries (`{ ts, src, kind, forced, text, ctx }`); `trim_debug_log` /
  `MAX_LOG_LINES` (cap 500, FIFO) unchanged.
- Add `NS.debug_log(src, kind, forced, fmt, ...) -> entry|nil`: format text, throttle-check on
  `src|kind|text`; on pass stamp `ts`, store the entry, `FauxScrollFrame_Update`, follow-tail, and
  **return the entry**; on suppress return `nil` (no work). Callers attach `entry.ctx` (the
  `format_context_log` string) when an entry is returned.
- `debug_print(...)` / `AddDebugLogLine(text)` → thin shims onto `debug_log("SYS","TRACE",false,…)`.
- **Delete** `debug_line_color` + the `sfind` classifier. Keep `DBG_CAT` (reuse keys per LAYER).

**Frame rewrite** — replace SMF + Slider with:
1. A `ScrollFrame` (`FauxScrollFrameTemplate`) inside the existing themed chrome (title, close X,
   separator, resize grip, toolbar — all kept).
2. A fixed pool of row frames, each with `time` + `src` + `kind` + `message` FontStrings, and an
   `OnEnter`/`OnLeave` driving the hover tooltip (header + wrapped message + the `ctx` string) off
   `buffer[FauxScrollFrame_GetOffset(scrollFrame) + rowIndex]`.
3. A `repaint(offset)` that fills visible rows, hides spares, colors/justifies the columns (forced →
   orange message tint); wired to `OnVerticalScroll` and `OnSizeChanged` (recompute `numToDisplay` +
   truncation width on resize).
4. Skin the template's scrollbar + thumb to `DBG_THEME`.
5. `RefreshDebugLogFrame` → `FauxScrollFrame_Update` + `repaint`.
6. `Copy` builds the header+context `tconcat`; `Clear` empties + updates.
7. **Delete** `sync_scrollbar`, the custom `Slider`/track/thumb, the SMF `OnMouseWheel` handler, `LINE_H`.

### `main.lua` — dispatcher src/kind + per-decision ctx; remove the CTX line
- Middleware (×3): `local e = debug_log("MW", kind, forced, …)`; strip a leading `^%[MW%] ` from
  `log_msg` (kills the doubled `[MW] [MW]`); drop the prepended `[MW]`. If `e` and `log_context`,
  `e.ctx = config.format_context_log(context, state)`.
- Context dump (×1): **delete the line** (`CONTEXT_LOG_INTERVAL` gate + call). The string it built via
  `format_context_log(context, state)` now rides along as the `ctx` on the middleware/strategy decisions.
- Strategies (×3): `local e = debug_log("STRAT:"..playstyle:upper(), kind, forced, …)`; `[PLAYSTYLE]`
  moves to `src`; keep the `[FORCED]` text marker so it survives copy. Same `e.ctx` attach on insert.

### `warrior/middleware.lua` — auto-tab
- `debug_print(…)` → `debug_log("MW:WAR", "ACT", false, …)`.

### `druid/bear.lua` — src/kind + timestamp (×5)
- The four `AddDebugLogLine` + one `NS.debug_print` route through `debug_log("STRAT:BEAR", kind, false,
  …)` and drop the `[%.3fs]` GetTime prefix. (Freeform traces — no `ctx` attached.)

### generic sites — thread `src` (×~9)
Owner comes from the file's home (see **Taxonomy → OWNER**):
- `druid/healing.lua` → `STRAT:DRUID`, `priest/shadow.lua` → `STRAT:SHADOW`,
  `hunter/rotation.lua` → `STRAT:HUNTER`, `shaman/enhancement.lua` → `STRAT:ENH`. All `kind="TRACE"`.
  (Shaman's 2-arg `debug_print(key, msg)` joins both strings for the body; the join is value-stable, so
  the migration doesn't change its throttle behavior.)

## Execution order

1. Switch the buffer to structured entries; add `NS.debug_log` with the content-keyed throttle
   (`src|kind|text`) **returning entry-or-nil**; retarget `debug_print`/`AddDebugLogLine` onto it as
   shims; delete `debug_line_color`.
2. Migrate categorized call sites: `main.lua` dispatcher (middleware ×3, strategies ×3, **delete** the
   CTX line, attach the `format_context_log` `ctx` on insert), `warrior/middleware.lua`, `bear.lua` ×5,
   and the generic sites (thread `src`). Drop baked timestamps.
3. Rebuild `CreateDebugLogFrame` on `FauxScrollFrameTemplate` with the row pool + `repaint`, wiring
   `repaint` to `OnVerticalScroll` and `OnSizeChanged`, plus the per-row hover tooltip (wrapped
   message + the `ctx` string), reading the entry via `FauxScrollFrame_GetOffset + rowIndex`.
4. Skin the Blizzard scrollbar to `DBG_THEME`.
5. Rewire `RefreshDebugLogFrame` / `Copy` (header + indented context) / `Clear`.
6. Delete dead SMF/Slider code (`sync_scrollbar`, custom thumb, `LINE_H`, SMF wheel handler).
7. `pnpm --filter @menagerie/tbc-rotation lint:lua` + `build`.

## Verification

- `lint:lua` clean; `build` succeeds (`output/TellMeWhen.lua` regenerates).
- In-game (`/reload`):
  - **Scroll tracks content** — wheel to the very top: the thumb reaches the top exactly when the
    oldest line is shown, and cannot wheel past it. Thumb size reflects visible/total ratio.
  - **Readable layout** — four aligned columns: `time │ src │ kind │ message`; `src` shows
    `LAYER:OWNER` (`STRAT:BM`, `MW:WAR`, bare `MW`/`SYS`) and is LAYER-colored; messages start at a
    consistent x; no run-on shove.
  - **Per-line context** — hovering a row shows its message wrapped + the `format_context_log` string
    that drove it; no standalone CTX dump line in the stream.
  - **Context capture** — decisions logged while `log_context` is on carry a context snapshot on hover;
    a throttle-suppressed repeat keeps its first-insert snapshot (no per-frame refresh — staleness ≤ the
    ~1.5s throttle window).
  - **Follow-tail** — at the bottom, new lines auto-scroll in; scrolled up, the view stays.
  - **Throttle** — a rotation stuck firing the same action does not flood; the repeated line appears at
    most ~once/1.5s; the 500-line cap isn't churned away in seconds.
  - **Resize** — drag the grip: rows/columns reflow; thumb still tracks at the new size.
  - **Copy** yields clean `[ts] [SRC] [KIND] message` with the `ctx` string indented beneath lines that
    have it; no `|cff` codes; no doubled `[MW] [MW]`.
  - **Clear** empties and the thumb resets.
  - **Colors/forced** — layers color-code; forced lines tint the message orange and keep `[FORCED]`
    (readable in copied text).
- Cannot test WoW from CI — manual `/reload` check required.

## Risks / open questions

- **Message truncation.** Fixed-height virtualized rows can't word-wrap (that fixed height is what
  keeps the thumb math exact), so long messages truncate in-row. The read path is the **hover tooltip**
  (wrapped message + the `ctx` string) plus full-buffer Copy.
- **Context memory.** Up to 500 entries may each hold a `ctx` string (already-formatted, typically a
  short line). For a debug tool this is fine; the 500-line FIFO cap bounds it, and gating on
  `log_context` means zero retention when the owner isn't debugging context.
- **Context capture cost.** `format_context_log` runs **only** on inserts that survive the 1.5s throttle
  **and** only when `log_context` is on — never per frame. There is no refresh-on-suppress path to
  re-allocate. The captured string is immutable, so no aliasing of the reused `reusable_context` table.
- **Client API target.** This addon already calls DF-era APIs (`SetResizeBounds` at the resize grip), so
  the runtime is **not** vanilla 2.4.3 — validate `FauxScrollFrame*` / `UIPanelScrollBarTemplate` /
  `FauxScrollFrame_GetOffset` against the modern client API, not the TBC reference.
- **Time-column alignment** relies on FRIZQT digits being equal-width (they are). If a future font swap
  breaks this, give the time column its own right-anchored block.

## Decisions resolved this pass

- **Three-axis taxonomy (LAYER/OWNER/KIND) + forced flag**, with `src` as the compound `LAYER:OWNER`
  column — replacing the conflated `cat`/`ps` model. The warrior auto-tab case drove this.
- **Context as per-line attached payload**, not a log line — killing the periodic CTX dump and its
  truncation special-case; captured as the `format_context_log` string on insert (frozen, gated by
  `log_context`); surfaced on hover + copy. No refresh-on-suppress (≤1.5s stale, by design).
- **Thread `src` at every site** (no untouched generic sites); shims kept only as a safety net.
- **`STRAT`** (not `ROT`) for the rotation layer label — matches the code's "strategies" terminology.
- **Owner = the file's home** — playstyle files use the playstyle, class-level modules use the class
  (`healing.lua`→`DRUID`, `hunter/rotation.lua`→`HUNTER`); `SYS` kept (not renamed `AIO`).
- **No column sorting; rows fixed in timestamp order.** Context renders as the playstyle's own
  `format_context_log` string (no `pairs()` reordering to worry about), so tooltip/copy stay stable.

## Out of scope

- The state **Debug Panel** (separate doc: `2026-06-14-shared-debug-panel-design.md`).
- The Combat **Dashboard** (`dashboard.lua`).
- Layer/kind **filter toggles** and a **minified copy** mode (owner deferred both).
- Unifying the theme palettes (`DBG_THEME` / Hunter `THEME` / BindPad `UI_THEME`).
