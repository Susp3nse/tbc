# AIO Framework Hardening — Round 2 (post-2026-06-15 audit)

> **Type:** Design (rationale + per-workstream direction; concrete edits sketched, not exhaustive line-edits).
> **Date:** 2026-06-15. **Risk:** Mixed per workstream (see each). **Scope:** the **shared** (non-class)
> AIO layer only — `src/aio/*.lua`. Per-class work is out of scope.
> **Source:** the 2026-06-15 three-agent read-only audit of the shared framework (dispatch, UI/panels,
> settings/debug). This doc owns the **gaps** that audit found which no shipped plan covers.

---

## 0. Relationship to existing plans (what this doc does NOT own)

This round is deliberately narrow because most of the obvious shared-layer work is already planned or
shipped. **Do not duplicate these — reference them:**

| Concern | Where it lives | Status |
|---|---|---|
| `NS.Widgets` adoption (route `debug`/`cliptracker`/`settings` chrome onto the shared primitives) | `2026-06-15-ui-rename-and-widgets-impl.md` §3 | Module exists; **Step 3 not done** (audit confirmed zero consumers). Finish *that* plan. |
| `ui.lua` → `profileui.lua` rename | same plan, §Step 1 | **Shipped** (file renamed). |
| `livepanel.lua` / `NS.CreateLivePanel` | `2026-06-15-livepanel-impl.md`, WS-3 | **Shipped** (`debugpanel` + `adaptivepanel` are thin instances). |
| `NS.ShowCopyWindow` single export modal | `2026-06-15-quickwins-impl.md` §2 | Planned/shipped — `debug.lua` owns it. |
| `learned_immune` empty-bucket prune | `2026-06-15-quickwins-impl.md` §3.1 | Covers the immune **leak** — *not* the cross-contamination this doc owns. |
| Hunter `logDecision` gate | `2026-06-15-quickwins-impl.md` §1 | Class-side; the **shared** `debug_print` gate (WS-2 here) is the analogous shared fix. |
| Theme consolidation (`NS.Theme` canonical) | WS-9 | **Shipped.** |

**This doc owns six workstreams the above do not:** dashboard leak + throttle + chrome adoption (WS-1),
shared `debug_print` gating (WS-2), immunity-table de-contamination (WS-3), the full `/m*` slash-command
namespace (WS-4), and the doc sync (WS-5). WS-6 is a small follow-on (widgets adoption hand-off).

---

## WS-1 — Dashboard hardening  *(audit HIGH ×2 + MED; `dashboard.lua`)*

`dashboard.lua` (~1,490 lines) is the one live panel that never migrated onto the shared
panel/chrome infra. Three distinct problems, one file:

### 1a. Frame leak across `/reload`  *(HIGH)*

**Evidence:** `dashboard.lua:335-356`. `create_dashboard()` looks up the previous
`_G["MenagerieDashboard"]` from the last load, hides it, zeroes its alpha, walks all
regions/children/grandchildren, and shoves it to `-5000,5000` — then **builds a brand-new
frame + full subtree** (icon slots, bars, pips, fontstrings). WoW frames never GC, so every
`/reload` abandons a complete widget tree. The module-local `dashboard_frame` guard only dedupes
*within* a single load. Tied: `dash_restorer` one-shot polling OnUpdate (`dashboard.lua:388-406`) is
re-spawned per reload too.

**Direction:** reuse the existing `_G.MenagerieDashboard` + its children when present, instead of
building-and-abandoning. Mirror the create-once pattern `livepanel.lua` already uses (panel built once,
rows pooled). The "shove offscreen + walk all regions" block at `:335-356` should disappear entirely
once we reuse rather than orphan.

**Risk:** Med — must confirm the reused subtree's references (`ui.resource_bg2`, timer bars, icon
slots, threat bar) re-bind correctly. Verify in-game across multiple `/reload`s that exactly **one**
`MenagerieDashboard` frame exists (e.g. `/run print(MenagerieDashboard, MenagerieDashboard:GetName())`
and a frame-count probe).

### 1b. Unthrottled per-frame string churn  *(HIGH)*

**Evidence:** `dashboard.lua:1378-1458` — `fr_frame`'s OnUpdate runs **raw every frame** (its siblings
`update_frame` @1363 and `watch_frame` @1467 are throttled to 10Hz / 2Hz). It does `format("%.1f", …)`
+ `SetText` for every timer bar **every frame** (`:1415`, `:1447`) while the dashboard is open. The
sweep-dot position *is* gated by a 0.5px delta (`:1387`, good) — the timer-bar **value text is not**.
This is exactly the hot-path allocation `AGENTS.md` warns against.

**Direction:** gate the `SetText` behind a value-changed check, modeled on the sweep-dot delta gate
already in the same handler. Cache the last-formatted string (or last value) per bar; only `format` +
`SetText` when it changes. No data-structure rewrite — a per-bar `last_text` field.

**Risk:** Low. Verification: open dashboard during a dummy fight; timer text updates visibly identical;
confirm via a temporary counter that `format`/`SetText` calls drop to "on change" frequency.

### 1c. Adopt shared chrome  *(HIGH — the "adopted everywhere" item)*

**Evidence:** `dashboard.lua:141` defines its **own** `local BACKDROP_THIN` (byte-identical to
`widgets.lua:16`); dashboard references neither `NS.Widgets` nor `NS.CreateLivePanel` nor
`NS.CreateDebugWindow`. The frame **shell** (backdrop / drag / close / position-save / toggle-watch) is
duplicated from patterns now living in `livepanel.lua` + `debug.lua`.

**Direction (scoped — do NOT blind-port):** the icon-grid / resource-bar / pip layout is legitimately
dashboard-specific and stays bespoke. What moves:
- Local `BACKDROP_THIN` → `NS.Widgets.BACKDROP_THIN`.
- Close button → `NS.Widgets.themed_button` (via `NS.CreateDebugButton`, consistent with livepanel).
- The window shell (backdrop + drag + position-save + toggle-watch) → consume the shared
  `NS.CreateDebugWindow` shell if 1a's reuse rewrite makes that natural; otherwise at minimum the
  backdrop/button primitives. **Tie this to 1a** — the reuse rewrite and the shell adoption are the
  same edit. The toggle-watch + drag→position-save loop is also the cross-file dup the audit flagged
  (shared with `livepanel.lua:422-448` and the settings movable button); a shared helper is optional
  and can be deferred — don't block 1a/1c on it.

**Risk:** Med (couples to 1a). One PR for 1a+1c (the reuse + shell), a separate trivial PR for 1b.

**Audit also flagged (fold in opportunistically, not blocking):**
- `dashboard.lua:709-719` — `dash_context` aliases the **live** `NS.last_rotation_context`; a class
  callback (`custom_lines[i]`, `extend_context`) that *writes* to it corrupts the next rotation frame.
  Enforced only by a comment today → **document in the dashboard-table contract** (WS-5).
- `dashboard.lua:63-90` — `short_guid_label`/`normalize_target_label` loop `UnitGUID`/`UnitIsUnit` over
  40 raid units per cast (~47 lookups). Early-out solo/party or cache on `GROUP_ROSTER_UPDATE`. *(MED,
  optional this round.)*

---

## WS-2 — Shared `debug_print` / `debug_log` gating  *(audit MED; `debug.lua`)*

**Problem (per owner direction):** `debug_print` may be *called* from anywhere (including hot paths),
but right now there is **no `debug_mode` check inside `debug.lua`** — every call `tostring`s all args,
builds the arg table, `tconcat`s, computes a throttle key, and only *then* checks the throttle
(`debug.lua:664` `debug_print`, `:600` `debug_log`, throttle at `:613-640`). So even fully-throttled
spam pays string + table work every frame, and entries accrue into the log table whether or not the
user has debug mode on. The `AGENTS.md` "enabled via the Debug Mode setting" framing is therefore
**misleading** — gating currently lives ad-hoc at *some* call sites (`shaman/enhancement.lua:81`,
`druid/healing.lua:265`, `main.lua:76`), not in the substrate.

**Owner decision (locked):** the gate moves **inside** the substrate. Callers can keep calling
`debug_print(...)` unconditionally; nothing is built or injected into the debug system unless
`debug_mode` is on. This also retires the need to keep/grow the throttle cache while disabled (WS feeds
the audit's separate unbounded-cache concern, `debug.lua:613-640`).

**Design — gate at the single choke point, before any work:**
- `debug_log(src, kind, forced, fmt, ...)` **already has a `forced` flag** (`debug.lua:600`). Add, as
  the **first** statement:
  ```lua
  if not forced and not (NS.cached_settings and NS.cached_settings.debug_mode) then return end
  ```
  Placed before `format`/`tconcat`/key-building so disabled-mode cost is ~one table lookup + boolean.
- `debug_print(...)` funnels through `debug_log` with `forced = false`, so it inherits the gate for
  free. Genuine always-on system/error messages (e.g. the `ProfileEnabled`/registry load errors,
  `AddDebugLogLine`) pass `forced = true` and bypass — that's exactly what the existing param is for.
- Setting key is `debug_mode` (`common.lua:30`, default `true`); `NS.cached_settings` is populated by
  `core.lua` `refresh_settings()` (slot 4, before `debug.lua` slot 5 — safe).

**Cleanup that falls out:** the ad-hoc caller-side `debug_mode` guards (shaman/druid/main) become
redundant for *logging* purposes. Leave them where they also guard **other** work (e.g. `main.lua:76`
gates the playstyle-decoration computation, not just the log — keep those); only the ones that solely
gate a `debug_log` call can be simplified. List explicitly before removing (scope discipline).

**Risk:** Low–Med. The behavior change is intended: with `debug_mode` off, `/mlog` shows nothing new.
Verify: toggle debug mode off, confirm no new log lines accrue and the throttle cache stops growing;
toggle on, confirm logging resumes; confirm `forced` system errors still print when off.

---

## WS-3 — Immunity-table de-contamination  *(audit MED; `core.lua`)*

**Problem:** `core.lua:226-231` — the per-category immunity spell-ID tables cross-contaminate. Divine
Shield / Divine Protection ranks (642, 1020, 45438, 11958, 33786) appear in **`IMMUNITY_PHYS` AND
`IMMUNITY_MAGIC` AND the CC/STUN/KICK tables** simultaneously. Result: a target under Divine Shield
reads phys-immune *and* magic-immune *and* kick-immune, and `has_phys_immunity` cannot distinguish
"physical-only immune" from "totally immune." Live over-suppression risk for casters that gate on
`target_magic_immune` / `target_phys_immune` (druid balance, cat).

**Direction:** decide the intended semantics, then make the data match it:
- Factor genuine **total-immunity** IDs (Divine Shield, Ice Block, etc.) out of the per-school tables
  into the existing total bucket, and have `has_phys_immunity`/`has_magic_immunity` **OR-in**
  `has_total_immunity` at query time. That keeps per-category helpers correct supersets without
  duplicating IDs across every table.
- Re-verify the ID lists against the cited LibAuraTypes source (the `-- from LibAuraTypes.lua` banner
  at `:226`).
- Separately confirm `has_immunity_buff` → `Unit(target):HasBuffs(ids, nil, true)` (`core.lua:233-237`)
  — if the 3rd positional (match-by-ID) signature is wrong it silently returns "never immune" forever.
  Needs an in-game/framework-doc check; flagged here so it's verified in the same pass.

**Risk:** Med — touches live rotation gating. Verify against the existing sim harness where immunity
paths are exercised; spot-check Divine Shield (should read total, not phys-only) and a known
single-school case.

**Do NOT** start maintaining per-school npcID tables — the learned tracker + aura layer is the model
(`AGENTS.md` "Immunity model"). This WS only de-duplicates the **aura** ID tables.

---

## WS-4 — Slash commands: full `/m*` namespace  *(owner decision; `settings.lua` + `debug.lua` + `dashboard.lua` + `debugpanel.lua`)*

**Owner decision (locked):** `/menagerie` opens the **settings UI only** (no subcommands). Everything
else is a flat top-level `/m*` command.

**Current state (verified):**
| Command | Registered in | Action |
|---|---|---|
| `/menagerie`, `/maio` | `settings.lua:849-851` | dispatcher: bare→settings; subcommands `burst`/`def`/`gap`/`status`/`help` (+ Hunter `raptor`) |
| `/mticks` | `settings.lua:917` | toggle cat energy-tick print |
| `/mdash` | `dashboard.lua:1355` | toggle dashboard (`toggle_dashboard`) |
| `/mdebug` | `debugpanel.lua:143` | toggle debug panel |
| `/mlog`, `/menagerielog` | `debug.lua:682-684` | toggle debug log window |

**Target state:**
| Command | Action | Change |
|---|---|---|
| `/menagerie` | open settings UI **only** | strip subcommand dispatch from `settings.lua:851-913`; bare → `toggle_settings()` |
| `/mlog` | debug log | keep; **drop** the `/menagerielog` legacy alias (`debug.lua:682`) |
| `/mdebug` | debug panel | keep (already top-level) |
| `/mdash` | toggle dashboard | keep |
| `/mticks` | energy ticks | keep (Hunter/cat-gated message stays) |
| `/mburst` | force offensive CDs | **new** — move from `/menagerie burst` |
| `/mdef` | force defensive CDs | **new** — move from `/menagerie def`/`defensive` |
| `/mgap` | gap closer | **new** — move from `/menagerie gap` |
| `/mraptor` | Hunter manual Raptor | **new** — move from `/menagerie raptor` (Hunter-gated) |
| `/mhelp` | print command list | **new** — replaces `/menagerie help`; lists the full `/m*` set, class-gating `/mticks`/`/mraptor` |

**Notes / decisions baked in:**
- **`/mstatus` is intentionally dropped** — `status` only ever toggled the dashboard, which `/mdash`
  already does. One command, one action. (Surfaced in the question; `/mstatus` would be a redundant
  alias.) If muscle memory matters, make `/mstatus` a thin alias of `/mdash` — but default is drop.
- `/maio` second alias for settings: keep as a convenience alias of `/menagerie`, or drop for
  cleanliness. **Recommend drop** (one brand command). Low stakes; call it in review.
- The combat commands (`burst`/`def`/`gap`/`raptor`) currently live in `settings.lua` because that's
  where `class_hex`/`class_name`/`NS.set_force_flag` are in scope. Keep their registration there (just
  re-key to `SLASH_M*` top-level), or relocate to `main.lua` near the force-flag logic — **recommend
  leaving in `settings.lua`** to minimize churn; they only need the existing locals.

**Risk:** Low (additive + removal of a dispatcher). No rotation behavior change. Verify each command
in-game; verify `/menagerie burst` etc. no longer do anything (or error helpfully) so users notice the
move; update help.

---

## WS-5 — Documentation sync  *(audit MED/LOW; `apps/tbc-rotation/AGENTS.md` + `CLAUDE.md` symlink)*

`AGENTS.md`/`CLAUDE.md` is the canonical AIO doc (one level above `src/aio/`). **No new
`src/aio/AGENTS.md`/`CLAUDE.md`** (owner-confirmed — a 4th drift surface is the problem, not the cure).
Fix the drift in the existing doc:

1. **`livepanel.lua` is entirely absent** — add it to the Shared-modules table and the load-order
   narrative. It's **load-order-critical**: captures `NS.CreateDebugWindow`/`NS.CreateDebugButton` at
   load, so it must sit after `debug.lua` (slot 5) and before the slot-9 panels that hard-return if
   `NS.CreateLivePanel` is missing. Currently it's at order 6 in `builder.config.json` but undocumented
   → a silent-no-op trap (load it too early and `debugpanel` + `adaptivepanel` quietly die, no error).
2. **"Context object" section overstates core** — `create_context` (`main.lua:205-259`) does **not**
   set stance/energy/rage/cp/is_stealthed/is_behind/enemy_count; those come from each class's
   `extend_context`. Split the doc list into "always set by core" vs "added by `extend_context`."
   A class author trusting the current list reads `nil`.
3. **`widgets.lua` header comment** claims consumers (`debug`/`livepanel`/`settings`/panels) that don't
   exist yet — reconcile after WS-6 (widgets adoption) lands; until then the comment describes intent,
   not reality.
4. **`common.lua`** is described as "low-level helpers"; it's actually settings-schema section
   factories (`Menagerie_SECTIONS`). Reword.
5. **Slash-command table** — replace with the WS-4 `/m*` table once it lands.
6. **Dashboard-table contract** — document the `dash_context`-is-live-and-read-only constraint
   (WS-1 fold-in).
7. **Add a "what to reuse when writing/updating a class" checklist** — the single highest-leverage
   addition: point at `NS.Widgets`, `NS.CreateLivePanel`, `Constants.MIDDLEWARE.*`, the context fields,
   `register_class`, `Menagerie_SECTIONS`. This is what actually stops the next person re-rolling
   `BACKDROP_THIN` a 6th time.

**Risk:** Zero (docs). Do this **last** so it reflects WS-1..4 as shipped, not as planned.

---

## WS-6 — Finish `NS.Widgets` adoption (hand-off, not re-plan)

The widgets module exists but has **zero consumers** (audit-confirmed); `BACKDROP_THIN` is redefined in
5 places (`widgets.lua:16`, `debug.lua:31`, `dashboard.lua:141`, `settings.lua:59`,
`hunter/cliptracker.lua:58`). The migration is **already specified** in
`2026-06-15-ui-rename-and-widgets-impl.md` §3 (debug → cliptracker → settings, one consumer per commit,
byte-stable visuals). **Execute that plan's Step 3.** WS-1c adds `dashboard.lua` as a consumer (which
that plan deliberately excluded). After both, `widgets.lua`'s header comment becomes true and WS-5 #3
resolves.

**Do not rewrite the widgets plan here** — it's complete and correct; this is just the pointer so the
two efforts converge instead of forking.

---

## Sequencing

Front-load the independent, low-risk, high-clarity items; defer the doc sync to the end so it's
accurate.

1. **WS-2** (debug gate) — one file, low risk, immediate hot-path + cache win.
2. **WS-4** (slash commands) — additive, no behavior change, visible.
3. **WS-1b** (dashboard throttle) — one-file, low risk, isolated from 1a.
4. **WS-6 / widgets §3** + **WS-1c** (chrome adoption) — do the existing widgets plan's Step 3, then
   pull dashboard onto the primitives.
5. **WS-1a** (dashboard frame reuse) — the highest-risk single edit; pair with 1c shell adoption.
6. **WS-3** (immunity) — needs sim/in-game verification; do deliberately.
7. **WS-5** (doc sync) — last, reflecting everything above.

Each WS is its own small PR with the conventional scope (`fix(app)` / `refactor(app)` / `docs`).
None changes rotation *behavior* except WS-3 (immunity gating) — which is the one to sim-verify.

## Open decisions for the human

- **`/maio` and `/mstatus`:** drop both (recommended) vs keep as aliases. (WS-4.)
- **Immunity semantics:** confirm per-category helpers should be supersets of total (OR-in
  `has_total_immunity`) vs strictly single-school. (WS-3.)
- **Dashboard shell:** full adoption of `NS.CreateDebugWindow` shell vs primitives-only. Depends on how
  cleanly 1a's reuse rewrite lands; decide during 1a. (WS-1.)
