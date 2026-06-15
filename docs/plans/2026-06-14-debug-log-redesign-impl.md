# Debug Log Redesign — Implementation Plan (granular, with file/line targets)

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> Companion to the design doc [`2026-06-14-debug-log-redesign.md`](./2026-06-14-debug-log-redesign.md).
> That doc carries the *why* and the locked-in decisions (the revised **LAYER/OWNER/KIND** taxonomy +
> per-line attached context). This doc is the *how*: an ordered, per-step build sheet with **current**
> file/line targets and a pass/fail acceptance check per step. **No code is written here.**

## The model in one screen (so this plan is self-contained)

- **Row:** `time │ src │ kind │ message`. Single-line, fixed-height (FauxScroll math stays exact).
- **`src`** = compound `LAYER:OWNER`. LAYER ∈ `MW` · `STRAT` · `SYS`; OWNER = a class/playstyle or none
  (`:OWNER` omitted when none). E.g. `STRAT:BM`, `MW:WAR`, `MW`, `SYS`.
- **`kind`** ∈ `ACT` · `EXEC` · `NOOP` · `TRACE`.
- **`forced`** = flag → orange message tint + inline `[FORCED]` marker.
- **`ctx`** = optional **string** = `config.format_context_log(context, state)` output (the same curated
  summary the old CTX line printed), captured at insert, shown on **hover** + **copy**, never inline. The
  old periodic CTX dump line is **deleted**.
- **API:** `NS.debug_log(src, kind, forced, fmt, ...) -> entry | nil`. Throttle key = `src|kind|text`; on
  pass it **returns the inserted entry**, on suppress it returns `nil` and does nothing. The caller
  attaches `entry.ctx` (the `format_context_log` string) only when an entry comes back — no `ctx` param,
  no refresh-on-suppress.
- **Thread `src` everywhere** — no untouched sites. Shims (`debug_print`/`AddDebugLogLine`) stay as a
  safety net defaulting `src="SYS", kind="TRACE"` (no `ctx`).

## How to use this plan

- Steps are ordered so the tree **builds at every phase boundary** (shims keep the old API alive while
  internals change). Don't reorder across phase boundaries.
- Line numbers were ground-truthed on 2026-06-14 (branch `rebrand/menagerie`). They drift as you edit
  earlier steps in the same file — **re-locate by symbol name once you've started editing.**
- Each step has an **Accept** check. Don't advance until it passes. Phase gates (`lint:lua`, `build`)
  are explicit.

## Ground-truth reference (verified current state)

### `apps/tbc-rotation/src/aio/core.lua`

| Symbol | Current line(s) | Notes |
|---|---|---|
| `debug_log_lines = {}` | 546 | plain strings today → structured entries |
| `MAX_LOG_LINES` | 547 | `= 500` (unchanged) |
| `DBG_THEME` | 549–557 | `bg, bg_widget, bg_hover, border, accent, text, text_dim` |
| `DBG_BACKDROP` | 558–562 | |
| `DBG_CAT` | 566–571 | keys: `forced`, `ctx`, `mw`, `action` — reused per LAYER (`mw`→MW, `action`→STRAT, `ctx`→SYS, `forced`→tint) |
| `sfind` + `debug_line_color` | 573–579 | **DELETE** |
| `CreateDebugLogFrame` | 604–822 | **REWRITE** |
| → SMF creation | 649–659 | delete |
| → Slider + track + thumb | 662–680 | delete |
| → `LINE_H = 11` | 685 | **DELETE** |
| → `sync_scrollbar()` | 687–696 | **DELETE** |
| → SMF `OnMouseWheel` | 705–712 | **DELETE** |
| → Clear button | 715 | keep, rewire |
| → Copy button / popup / EditBox / OnClick | 718 / 722–731 / 766–775 / 777–783 | keep popup; rewire source (header + ctx) |
| → resize grip + `SetResizeBounds(300,150,800,600)` | 792–803 / 809 | keep; add repaint on resize |
| → hint text | 812–815 | keep |
| `NS.DebugLogFrame = f` | 820 | |
| `trim_debug_log` | 824–833 | unchanged (FIFO @ 500) |
| `AddDebugLogLine(text)` | 835–847 | → **shim**; `AtBottom()` follow at 841 |
| `RefreshDebugLogFrame` | 849–860 | → `FauxScrollFrame_Update` + `repaint` |
| `NS.CreateDebugLogFrame` / `NS.RefreshDebugLogFrame` | 862 / 863 | |
| slash `/menagerielog` + `/mlog` | 866–878 | |
| `debug_timestamp()` | 884–886 | **exists**, exported 887; returns `HH:MM:SS.t` |
| throttle cache + consts | 889–894 | `debug_print_cache`, `DEBUG_CACHE_TTL=60`, `DEBUG_CACHE_PRUNE_INTERVAL=30` |
| `debug_print(...)` | 896–922 | → **shim**; 1.5s window lives here today (moves into `debug_log`) |
| `NS.debug_print` / `NS.AddDebugLogLine` | 924 / 925 | |

### `apps/tbc-rotation/src/aio/main.lua` (dispatcher)

Locals at top: `debug_print` (33), `AddDebugLogLine` (56), `debug_timestamp` (57). **Add** `debug_log`.
`context` table is in scope at all dispatcher decisions (`create_context` l.200; `NS.last_rotation_context`
l.284). `CONTEXT_LOG_INTERVAL = 2.0` (l.61), CTX gate at l.138.

| Line | Current | Target |
|---|---|---|
| 105 | `debug_print(format("[MW] %s%s", forced and "[FORCED] " or "", log_msg))` | `local e = debug_log("MW", "ACT", forced, "%s", (log_msg:gsub("^%[MW%] ","")))` then `attach_ctx(e)` |
| 107 | `debug_print(format("[MW] EXECUTED %s (P%d)%s", mw.name, mw.priority, …))` | `local e = debug_log("MW", "EXEC", forced, "%s (P%d)%s", mw.name, mw.priority, forced and " [FORCED]" or "")` then `attach_ctx(e)` |
| 112 | `debug_print(format("[MW] NO_ACTION %s (P%d)%s", …))` | `local e = debug_log("MW", "NOOP", forced, "%s (P%d)%s", mw.name, mw.priority, forced and " [FORCED]" or "")` then `attach_ctx(e)` |
| 158 | `AddDebugLogLine(format("[%s] [%s CTX] %s", debug_timestamp(), playstyle:upper(), msg))` | **DELETE the line.** The `format_context_log(context, state)` string it printed is now attached as `e.ctx` on the decisions at 105/107/112/177/179/184. The `CONTEXT_LOG_INTERVAL` gate (138) and `msg` builder become dead — remove them too if nothing else uses them. |
| 177 | `debug_print(format("[%s] %s%s", playstyle:upper(), forced and "[FORCED] " or "", log_msg))` | `local e = debug_log(src, "ACT", forced, "%s%s", forced and "[FORCED] " or "", log_msg)` then `attach_ctx(e)` |
| 179 | `debug_print(format("[%s] EXECUTED %s%s", playstyle:upper(), strategy.name, …))` | `local e = debug_log(src, "EXEC", forced, "%s%s", strategy.name, forced and " [FORCED]" or "")` then `attach_ctx(e)` |
| 184 | `debug_print(format("[%s] NO_ACTION %s%s", playstyle:upper(), strategy.name, …))` | `local e = debug_log(src, "NOOP", forced, "%s%s", strategy.name, forced and " [FORCED]" or "")` then `attach_ctx(e)` |

where `src = "STRAT:"..playstyle:upper()` (computed once, l.84) and `attach_ctx(e)` is the insert-only
context capture, written **inline** at each site (no per-frame closure):

```lua
local e = debug_log(src, "ACT", forced, "%s%s", ...)
if e and log_context and format_context_log then
  e.ctx = format_context_log(context, state)   -- curated string, frozen at insert
end
```

`context` and `state` are already in scope at every dispatcher decision (they fed the old CTX line at
141–142); hoist `log_context` / `format_context_log` to locals once at the top of the dispatch so the
guard is a cheap field-free check. The `if e` short-circuits the whole capture on a throttle-suppressed
repeat — zero work when nothing was inserted.

> **`[FORCED]` (decision: flag + marker, both).** Pass `forced` so the row tints, **and** keep the
> `[FORCED]` text in the message so copy retains it. For the middleware `log_msg` path (105), if the
> inner `log_msg` already carries `[FORCED]`, don't double it — pass `forced` and leave the marker that's
> already in the text.
> **Compute `src` once per decision** (`local src = "STRAT:"..playstyle:upper()`) to avoid re-concatting
> on the hot path; reuse for ACT/EXEC/NOOP at that site.

### Peripheral + generic sites (now ALL threaded — decision 7)

| File:line | Current | Target |
|---|---|---|
| `warrior/middleware.lua:1509–1510` | `debug_print(format("[MW] Auto Tab → … (HP: %.0f%%) …", …))` | `debug_log("MW:WAR", "ACT", false, "Auto Tab → … (HP: %.0f%%) …", …)`; drop `[MW]` (volatile HP% won't collapse — accepted) |
| `druid/bear.lua:558` | `AddDebugLogLine(format("[%.3fs] [MAUL] …", GetTime()))` | `debug_log("STRAT:BEAR", "ACT", false, "[MAUL] …")`; drop `[%.3fs]`/GetTime |
| `druid/bear.lua:563` | same shape | same |
| `druid/bear.lua:811–812` | `AddDebugLogLine(format("[%.3fs] [TAB TARGET] …", GetTime(), …))` | `debug_log("STRAT:BEAR", "ACT", false, "[TAB TARGET] …", …)` |
| `druid/bear.lua:814` | same shape | same |
| `druid/bear.lua:768` | `NS.debug_print(format("[GROWL] …", …))` | `debug_log("STRAT:BEAR", "TRACE", false, "[GROWL] …", …)` |
| `druid/healing.lua:82,84,287,317,386` | bare multi-arg `debug_print(...)` | `debug_log("STRAT:DRUID", "TRACE", false, "%s", <joined>)` (class-level module → owner `DRUID`) |
| `priest/shadow.lua:97` | bare `debug_print(<preformatted>)` | `debug_log("STRAT:SHADOW", "TRACE", false, "%s", <text>)` |
| `hunter/rotation.lua:123` | bare `debug_print(format(…))` | `debug_log("STRAT:HUNTER", "TRACE", false, "%s", <formatted>)` (class rotation path → owner `HUNTER`) |
| `shaman/enhancement.lua:80` | `NS.debug_print(key, msg)` (2-arg, throttle helper) | `debug_log("STRAT:ENH", "TRACE", false, "%s", key.." "..msg)` — join both args into the body; the join is value-stable, so the throttle key is unchanged from today |
| `shaman/enhancement.lua:91` | `NS.debug_print("sync-macro", <fmt w/ GetTime>)` | same shape; volatile GetTime won't collapse (unchanged from today) |

> **Owner = the file's home (resolved).** A playstyle file logs that playstyle (`bear.lua`→`BEAR`,
> `enhancement.lua`→`ENH`, `shadow.lua`→`SHADOW`); a class-level module logs the class
> (`healing.lua`→`DRUID`, `rotation.lua`→`HUNTER`). The folder/file already encodes ownership — read
> it in place; don't invent a label. `SYS` is kept as-is for plumbing (not renamed to `AIO`).
> **⚠ Site count.** `grep -rn "debug_print\|AddDebugLogLine" apps/tbc-rotation/src/aio` and reconcile —
> the recon pass had a small off-by-one on the healing tally. Every hit should end up either threaded to
> an explicit `debug_log` or knowingly left on a shim.

---

## Phase 0 — Pre-flight (no edits)

**0.1 — Read area docs.** `apps/tbc-rotation/AGENTS.md`, plus the `druid`/`warrior`/`shaman`/`priest`/
`hunter` folder `AGENTS.md`s for the files you'll touch.
**Accept:** you can state the `build` + `lint:lua` commands.

**0.2 — Baseline green.** `pnpm --filter @menagerie/tbc-rotation lint:lua` + `build`.
**Accept:** both succeed on the untouched tree.

---

## Phase 1 — Data model + logging API (`core.lua` internals)

> Keep the old SMF render path alive against the structured buffer (a temporary bridge) so the tree
> builds at the phase boundary. You delete the bridge in Phase 3.

**1.1 — Structured buffer.** `core.lua:546` — entries `{ ts, src, kind, forced, text, ctx }`.
`trim_debug_log` (824–833) is index-based; no change.
**Accept:** every push stores a table; every read (repaint/copy/tooltip) reads fields.

**1.2 — Add `NS.debug_log(src, kind, forced, fmt, ...) -> entry | nil`** (near 887). Body:
1. `local text = select("#", ...) > 0 and format(fmt, ...) or fmt` — built **every** call (the key
   needs it; this is not "deferred").
2. `local key = src .. "|" .. kind .. "|" .. text`
3. throttle: reuse `debug_print_cache` + prune (889–894) + **1.5s** window — **move** the throttle out
   of `debug_print` (896–922) so this is the single throttle.
4. **on suppress:** `return nil`. No refresh, no map — a suppressed repeat does nothing (its already-
   inserted entry keeps its first-insert `ctx`; ≤1.5s stale, by design).
5. **on pass:** `local e = { ts = debug_timestamp(), src = src, kind = kind, forced = forced or nil, text = text }`, `tinsert(debug_log_lines, e)`, `trim_debug_log()`, follow-tail repaint (Phase 3 wires the real repaint; bridge uses the SMF append), then **`return e`** so the caller can set `e.ctx`.
**Accept:** two identical calls within 1.5s → one insert, first returns a table, second returns `nil`;
after 1.5s, two inserts (two non-nil returns). No `ctx` param exists; no `key→entry` map exists.

**1.3 — `debug_print` → shim.** `core.lua:896–922`. Join args with space via `tostring` (keep the
existing `debug_string_args` reuse — shaman depends on it), then
`debug_log("SYS", "TRACE", false, "%s", joined)` (ignore the return). Remove the baked `[%s]` timestamp
and the in-function throttle (now in `debug_log`).
**Accept:** `debug_print("a","b")` → text `a b`, `src=SYS`, `kind=TRACE`, throttled; no double timestamp.

**1.4 — `AddDebugLogLine` → shim.** `core.lua:835–847` → `debug_log("SYS","TRACE",false,"%s",text)`
(ignore the return). Old SMF-append body moves into `repaint` (Phase 3); bridge drives the SMF from
`debug_log`'s insert.
**Accept:** a bare string lands as `{ ts, src="SYS", kind="TRACE", forced=nil, text }` (no `ctx`), throttled.

**1.5 — Delete the classifier.** Remove `sfind` + `debug_line_color` (573–579). Keep `DBG_CAT` (566–571);
refresh its stale comment to "looked up by LAYER for the src cell, `forced` for message tint." Update the
bridge render + 849–860 to color by `DBG_CAT[layer_of(entry.src)]` instead of scanning.
**Accept:** `grep -n debug_line_color core.lua` empty; lint:lua clean.

**1.6 — `main.lua` alias.** Add `local debug_log = NS.debug_log` by lines 33/56/57.
**Accept:** alias resolves.

**🚦 Phase 1 gate:** `lint:lua` clean + `build` succeeds. Lines flow through one throttle; context
refresh works; log still renders via the bridge.

---

## Phase 2 — Migrate call sites (now: all of them)

> Pure call-site rewrites to explicit `debug_log(src, kind, forced, fmt, ...)`. Use the target column in
> the ground-truth tables above. Keep `[FORCED]` markers; drop `[MW]`/`[PS]`/baked timestamps. For the
> dispatcher decisions, capture the returned entry and attach `format_context_log` ctx inline (the
> `attach_ctx` snippet above); peripheral/generic sites attach no ctx.

**2.1 — `main.lua` middleware (105, 107, 112).** Per table; strip `^%[MW%] ` from `log_msg` at 105;
thread `forced`; capture `local e =` and attach `e.ctx` inline (guarded by `log_context`).
**Accept:** no `[MW]` literal remains; doubled `[MW] [MW]` gone; `kind` is ACT/EXEC/NOOP; with
`log_context` on, an inserted entry has `e.ctx` = the `format_context_log` string.

**2.2 — `main.lua` DELETE the CTX line (158).** Remove the `AddDebugLogLine(...)` CTX dump and its
`CONTEXT_LOG_INTERVAL` gate (138) + `msg` builder if now unused. **Keep** `format_context_log` itself —
it's now called by `attach_ctx`, not deleted. Verify `config.format_context_log` and the `log_context`
setting (`common.lua:34`) are still referenced (by `attach_ctx`) and not orphaned.
**Accept:** no standalone CTX line is emitted; `grep -n "CTX" main.lua` shows none reachable; the state
formerly dumped is now reachable via the `e.ctx` on the surrounding decisions; `format_context_log` +
`log_context` still have a live reference.

**2.3 — `main.lua` strategies (177, 179, 184).** Per table; `src="STRAT:"..playstyle:upper()` (compute
once), `kind` ACT/EXEC/NOOP, thread `forced`; capture `local e =` and attach `e.ctx` inline.
**Accept:** `[%s]` playstyle prefix gone from the message; `src` carries `STRAT:<PS>`; `[FORCED]` marker
preserved for copy; inserted decisions carry `e.ctx` when `log_context` is on.

**2.4 — `warrior/middleware.lua:1509`.** → `debug_log("MW:WAR", "ACT", false, …)`; drop `[MW]`. (No ctx
— it logs directly, no `context`/`state` in scope.)
**Accept:** no `[MW]` literal; `src` is `MW:WAR`; builds.

**2.5 — `druid/bear.lua` (558, 563, 811–812, 814, 768).** All five → `debug_log("STRAT:BEAR", kind,
false, …)`; drop the `[%.3fs]` GetTime on the four `AddDebugLogLine` sites. `kind="ACT"` for the
MAUL/TAB action lines, `"TRACE"` for `[GROWL]`. Keep the `[MAUL]`/`[TAB TARGET]`/`[GROWL]` tags **in
the text** (content, not axes). (Freeform traces — no ctx.)
**Accept:** `grep -n "%.3fs" bear.lua` empty; all five route through `debug_log` with `src=STRAT:BEAR`.

**2.6 — generic sites (healing, shadow, hunter/rotation, shaman).** Thread each `src` per table; resolve
the owner labels by reading the file (don't invent). No ctx at these sites. Shaman: join the 2-arg
`key msg` into the body (the join is value-stable, so the throttle key is unchanged).
**Accept:** every generic site is either an explicit `debug_log` with a real `src`, or knowingly left on
a shim; the grep reconcile (above) matches.

**🚦 Phase 2 gate:** `lint:lua` clean + `build` succeeds. `grep -rn "\[MW\] \[MW\]"` finds nothing;
`grep -rn "debug_print\|AddDebugLogLine" src/aio` shows only intentional shim usages remain.

---

## Phase 3 — Frame rewrite: `FauxScrollFrame` + virtualized row pool

> Replace SMF + Slider (`CreateDebugLogFrame`, 604–822), keeping the themed chrome.

**3.1 — Constants.** `ROW_H` (e.g. 12), column x-offsets for `time │ src │ kind │ message`,
`numToDisplay` from viewport height, `MSG_TRUNC_W`. `ROW_H` is the single source for pool + FauxScroll math.
**Accept:** constants exist; `ROW_H` used by both pool sizing and the scroll math.

**3.2 — ScrollFrame on `FauxScrollFrameTemplate`.** Replace 649–659. Wire `OnVerticalScroll` →
`FauxScrollFrame_OnVerticalScroll(self, delta, ROW_H, repaint)`.
**Accept:** frame opens; scrolling fires `repaint` (stub OK here).

**3.3 — Row pool.** `numToDisplay + 1` row `Frame`s, each with `time` (dim) + `src` + `kind` +
`message` FontStrings; `message` = `SetWordWrap(false)` + truncate to `MSG_TRUNC_W`. Store on `f.rows`.
**Accept:** pool size ≈ `floor(viewportH/ROW_H)`; pool count constant regardless of buffer size.

**3.4 — `repaint(offset)`.** For each visible row `i`: `entry = buffer[offset+i]`; nil → hide row; else
`time=entry.ts` (dim), `src=entry.src` colored by its LAYER (`DBG_CAT[layer_of(entry.src)]`),
`kind=entry.kind` (neutral `DBG_THEME.text_dim` — no `DBG_CAT` entry; not per-kind colored),
`message=entry.text` (`DBG_THEME.text`, or `DBG_CAT.forced` orange when `entry.forced`). Store the
row's absolute index (`row.entryIndex = offset+i`) for the hover read. Call
`FauxScrollFrame_Update(scrollframe, #buffer, numToDisplay, ROW_H)`.
**Accept:** four columns align; `src` shows `STRAT:BM`/`MW:WAR`/`MW`/`SYS` LAYER-colored; forced rows
tint orange. (Do **not** assert `kind` is colored — it's intentionally neutral.)

**3.5 — Hover tooltip (`OnEnter`/`OnLeave`).** Read the entry **at hover time** (pooled-safe) via
`buffer[FauxScrollFrame_GetOffset(scrollframe) + rowIndex]` — or the `row.entryIndex` stamped in 3.4;
do **not** reference an undefined `currentOffset`. `GameTooltip` on the row: header `ts │ SRC │ KIND`
(dim), then the full message word-wrapped (~400px), then — if `entry.ctx` — add the `ctx` **string**
beneath it (it's already the curated `format_context_log` summary; `AddLine` with `wrap=true`, or split
on `\n` if multi-line). Forced → orange message.
**Accept:** hovering shows the full wrapped message; entries with context show the `format_context_log`
string beneath; after scrolling, hover shows the correct line; entries without ctx show just the message.

**3.6 — Resize hook.** On the resizable frame (`SetResizeBounds` 809), `OnSizeChanged`: recompute
`numToDisplay` + `MSG_TRUNC_W`, grow/shrink the pool, `FauxScrollFrame_Update` + `repaint`.
**Accept:** dragging the grip reflows rows + truncation; no stale count; thumb still tracks.

**3.7 — Follow-tail.** In `debug_log`'s insert path (1.2), if at max offset before insert, snap to new
max after; else leave put. (Replaces SMF `AtBottom()` at 841.)
**Accept:** at bottom, new lines auto-scroll in; scrolled up, view stays.

**🚦 Phase 3 gate:** `lint:lua` clean + `build` succeeds. Remove the Phase-1 SMF bridge — the real
`repaint` replaces it.

---

## Phase 4 — Skin the Blizzard scrollbar to `DBG_THEME`

**4.1 — Theme the template scrollbar** (`<name>ScrollBar`, a `UIPanelScrollBarTemplate`): accent thumb,
`bg_widget` track, tint arrows. Keep Blizzard behavior.
**Accept:** scrollbar reads as warm-palette; arrows + drag still work.

---

## Phase 5 — Rewire `Refresh` / `Copy` / `Clear`

**5.1 — `RefreshDebugLogFrame` (849–860).** Replace SMF clear+re-add with one `FauxScrollFrame_Update` +
`repaint`. No re-classification.
**Accept:** opening paints the buffer once; no `debug_line_color` ref.

**5.2 — Copy (777–783).** Build the `tconcat` source: per entry, a header `"[ts] [SRC] [KIND] text"`
(single-space joins), and **if `entry.ctx`**, append the `ctx` **string** indented (e.g. 4 spaces) on
the following line(s) — split on `\n` and indent each if it's multi-line. Feed the existing copy-popup
EditBox (722–731 / 766–775) unchanged.
**Accept:** copied text is clean (`[18:42:02.0] [STRAT:BM] [ACT] Steady Shot` + the indented
`format_context_log` summary beneath); no `|cff` codes; entries without ctx are a single line.

**5.3 — Clear (715).** Empty `debug_log_lines` + `FauxScrollFrame_Update` with 0 items + repaint. (No
`key→entry` map exists to clear.)
**Accept:** Clear empties the view; thumb resets.

---

## Phase 6 — Delete dead SMF/Slider code

**6.1 — Remove corpses.** Delete: custom `Slider`/track/thumb (662–680), `LINE_H` (685),
`sync_scrollbar` (687–696), SMF `OnMouseWheel` (705–712), and any remaining SMF refs (`f.smf`,
`SyncScrollbar`, `smf:AddMessage/Clear/ScrollToBottom/AtBottom`).
**Accept:** `grep -n "smf\|sync_scrollbar\|LINE_H\|ScrollingMessageFrame\|SyncScrollbar" core.lua` empty.
List anything removed in the change summary.

---

## Phase 7 — Final verification

**7.1 — Static gates.** `lint:lua` clean; `build` regenerates `output/TellMeWhen.lua`.

**7.2 — Manual `/reload` checklist** (no WoW in CI):
- [ ] **Scroll tracks content** — wheel to the very top; thumb reaches top exactly at the oldest line,
      can't wheel past. Thumb size ≈ visible/total.
- [ ] **Readable columns** — `time │ src │ kind │ message` aligned; `src` = `STRAT:BM` / `MW:WAR` /
      bare `MW` / `SYS`, LAYER-colored; `kind` is a distinct (neutral) column; consistent message x.
- [ ] **Per-line context** — hover shows message wrapped + the `format_context_log` string beneath;
      **no standalone CTX dump line** in the stream.
- [ ] **Context capture** — with `log_context` on, dispatcher decisions carry a context snapshot on
      hover; a throttled-repeating line keeps its first-insert snapshot (≤1.5s stale, by design).
- [ ] **Follow-tail** — at bottom new lines auto-scroll in; scrolled up, view stays.
- [ ] **Throttle** — repeated action floods at most ~once/1.5s; 500-cap not churned away.
- [ ] **Resize** — grip reflows rows/columns; thumb tracks.
- [ ] **Copy** — clean `[ts] [SRC] [KIND] message` with the indented `format_context_log` string
      beneath ctx-bearing lines; no `|cff`.
- [ ] **Clear** — empties; thumb resets.
- [ ] **Colors/forced** — layers color-code; forced lines tint orange + keep `[FORCED]` in copy; no
      doubled `[MW] [MW]`.
- [ ] **bear.lua** lines use the shared tenths timestamp (no `[%.3fs]`).

**7.3 — Change summary** (per CLAUDE.md): files changed + why; any sites knowingly left on shims;
residual concerns (truncation read-path = tooltip; context memory; FRIZQT digit-width for time align).

---

## Resolved decisions (settled with owner)

1. **Owner = the file's home.** Playstyle files → playstyle tag (`BEAR`/`ENH`/`SHADOW`); class-level
   modules → class tag (`healing.lua`→`DRUID`, `rotation.lua`→`HUNTER`). Read the file; don't invent.
   `SYS` kept (not `AIO`).
2. **No column sorting; rows fixed in timestamp order.** The columns are read-only labels, never
   click-to-sort headers — the log's order is always the chronology (Step 3.4 paints `buffer` in order;
   nothing reorders it). Context renders as the playstyle's own `format_context_log` **string** (Step
   3.5 / 5.2), so there's no `pairs()` key-ordering to stabilize — the author already formatted it.
3. **`ctx` = `format_context_log` string, captured on insert only.** No `ctx` param on `debug_log`, no
   `key→entry` refresh map, no refresh-on-suppress. The caller attaches `e.ctx` to the returned entry
   (gated by `log_context`); strings are immutable so the snapshot can't be aliased by `reusable_context`.
   Hover is ≤1.5s stale by design — the throttle window bounds it. `format_context_log` + the
   `log_context` setting (`common.lua:34`) are **preserved** (repurposed as the ctx source), not orphaned.
4. **Client API target is the modern client, not vanilla TBC.** The addon already calls DF-era APIs
   (`SetResizeBounds`, core.lua:809), so validate `FauxScrollFrame*` / `UIPanelScrollBarTemplate` /
   `FauxScrollFrame_GetOffset` against the current client reference.

## Out of scope (unchanged from design doc)

State **Debug Panel** (`2026-06-14-shared-debug-panel-design.md`), Combat **Dashboard**
(`dashboard.lua`), layer/kind **filter toggles**, **minified copy** mode, theme-palette unification.
