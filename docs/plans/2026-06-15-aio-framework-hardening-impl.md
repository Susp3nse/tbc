# AIO Framework Hardening — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-15-aio-framework-hardening-design.md`.
> **Date:** 2026-06-15. **Scope:** shared (non-class) AIO layer only.
> **Ships as:** one PR per workstream (each independently buildable + verifiable).
> **Build/verify gate for every step:** `pnpm --filter @menagerie/tbc-rotation build` succeeds, then in-game
> `/reload` + the per-step visual/behavior check. `pnpm --filter @menagerie/tbc-rotation test` for any step
> touching the lua-behavior suite (none expected except incidental).

Execution order (low-risk/high-clarity first, behavior-changing + doc last):
**WS-2 → WS-4 → WS-1b → WS-6+WS-1c → WS-1a → WS-3 → WS-5.**

---

## WS-2 — Gate `debug_print` / `debug_log` inside the substrate

**File:** `apps/tbc-rotation/src/aio/debug.lua`. **Risk:** Low. **Behavior change:** with `debug_mode`
off, no new log lines accrue and the throttle cache stops growing (intended). Genuine errors use
`print()` (not `debug_log`) and are unaffected.

**Context (verified):** `debug_log(src, kind, forced, fmt, ...)` at `debug.lua:600` already carries a
`forced` flag. It builds `text`/`key` at `:603-604` and inserts at `:630-638`. `debug_print(...)` at
`:664` stringifies args at `:666-668` *before* calling `debug_log(..., false, ...)` at `:672`.
`AddDebugLogLine` (`:650`) calls `debug_log(..., false, ...)`. Setting key `debug_mode`
(`common.lua:30`, default `true`); `NS.cached_settings` is populated by `core.lua` `refresh_settings()`
(slot 4, before `debug.lua` slot 5).

**Edit 1 — gate `debug_log` before any work.** Insert as the first statement of `debug_log`
(after the `function` line `debug.lua:600`, before `src = src or "SYS"` at `:601`):

```lua
   if not forced and not (NS.cached_settings and NS.cached_settings.debug_mode) then return nil end
```

`forced = true` callers (reserved for always-on system/error lines) bypass; everything else is gated.

**Edit 2 — gate `debug_print` before the arg-stringify loop.** Insert as the first statement of
`debug_print` (after `local function debug_print(...)` at `:664`, before `local n = select('#', ...)`):

```lua
   if not (NS.cached_settings and NS.cached_settings.debug_mode) then return end
```

`debug_print` has no always-on path, so a plain gate (no `forced`) — this avoids the `tostring` loop
+ `tconcat` when disabled.

**Decision — `AddDebugLogLine`:** leave it calling `debug_log(..., false, ...)` so it inherits the
gate (consistent with "nothing in the log unless debug mode"). If a caller genuinely needs an always-on
line, it passes `forced = true` explicitly. (Audit flagged `AddDebugLogLine` may be an unused corpse —
confirm call sites; if unused, drop it + the `NS.AddDebugLogLine` export at `:679` in a follow-up, with
approval.)

**Redundant caller-side guards (do NOT bulk-remove):** guards like `druid/healing.lua:265`,
`shaman/enhancement.lua:81/92` now double-gate logging. Only simplify ones that *solely* wrap a
`debug_log`/`debug_print` call. **Keep** `main.lua:76/146` — those gate the playstyle-decoration
*computation*, not just the log. Out of scope for this PR (class files); note for a later pass.

**Verify:** toggle Debug Mode off in `/menagerie` → confirm `/mlog` shows no new lines during combat and
the cache stops growing (temporary `print(#debug_print_cache)` probe, or trust by inspection); toggle on
→ logging resumes. Commit: `fix(app): gate debug_print/debug_log on debug_mode inside the substrate`.

---

## WS-4 — Slash commands: full `/m*` namespace

**Files:** `settings.lua`, `debug.lua`, plus verification of `dashboard.lua` / `debugpanel.lua`
(already correct). **Risk:** Low. **No rotation behavior change.**

**Target (owner-locked):** `/menagerie` = settings UI only; everything else flat `/m*`.

### Edit 1 — `settings.lua:849-913`: strip the dispatcher, register `/m*` combat commands

Replace the `SlashCmdList["MENAGERIE"]` dispatcher body (`:851-913`) so the brand command only toggles
settings:

```lua
SLASH_MENAGERIE1 = "/menagerie"
SlashCmdList["MENAGERIE"] = toggle_settings
```

- **Drop `SLASH_MENAGERIE2 = "/maio"`** (recommended — one brand command). *Open decision: keep as alias
  if desired.*
- Move the former subcommands to dedicated top-level commands (place after the block, reusing the
  existing `class_hex` / `class_name` / `NS.set_force_flag` / `NS.show_notification` locals already in
  this file's scope):

```lua
SLASH_MBURST1 = "/mburst"
SlashCmdList["MBURST"] = function()
    NS.set_force_flag("force_burst")
    NS.show_notification("BURST", 3.0, { 1.0, 0.5, 0.1 })
    print(format("|cff%s[Menagerie]|r |cFFFFFF00Burst|r cooldowns activated!", class_hex))
end

SLASH_MDEF1 = "/mdef"
SlashCmdList["MDEF"] = function()
    NS.set_force_flag("force_defensive")
    NS.show_notification("DEFENSIVE", 3.0, { 0.3, 0.7, 1.0 })
    print(format("|cff%s[Menagerie]|r |cFFFFFF00Defensive|r cooldowns activated!", class_hex))
end

SLASH_MGAP1 = "/mgap"
SlashCmdList["MGAP"] = function()
    NS.set_force_flag("force_gap")
    print(format("|cff%s[Menagerie]|r |cFFFFFF00Gap closer|r activated!", class_hex))
end

SLASH_MHELP1 = "/mhelp"
SlashCmdList["MHELP"] = function()
    print(format("|cff%s[Menagerie]|r Commands:", class_hex))
    print("  /menagerie  - Open settings")
    print("  /mlog       - Toggle debug log")
    print("  /mdebug     - Toggle debug panel")
    print("  /mdash      - Toggle combat dashboard")
    print("  /mburst     - Force burst cooldowns")
    print("  /mdef       - Force defensive cooldowns")
    print("  /mgap       - Use gap closer")
    if class_name == "Hunter" then
        print("  /mraptor    - Force one manual Raptor queue window")
        print("  /mticks     - Toggle cat energy-tick debug print")  -- cat/druid; shown for relevant classes
    end
end
```

- **Hunter `raptor`** → `/mraptor` (Hunter-gated, same pattern). Keep its existing
  `class_name == "Hunter"` guard.
- **`status` is dropped** — it only called `NS.toggle_dashboard()`, which `/mdash` already does. (No
  `/mstatus`. *Open decision: add `SlashCmdList["MSTATUS"] = SlashCmdList["MDASH"]` alias if muscle
  memory matters.*)
- Make `/mhelp` class-aware for `/mticks` (cat/druid) and `/mraptor` (Hunter) so it doesn't advertise
  commands a class can't use.

### Edit 2 — `debug.lua:682`: drop the legacy `/menagerielog` alias

```lua
SLASH_MENAGERIELOG1 = "/mlog"
SlashCmdList["MENAGERIELOG"] = function() ... end   -- body unchanged
```

(Remove `SLASH_MENAGERIELOG2`; promote `/mlog` to slot 1. The global table key `"MENAGERIELOG"` can
stay — it's an internal name, not user-facing.)

### Already correct (no edit, just confirm):
`/mdash` (`dashboard.lua:1355`), `/mdebug` (`debugpanel.lua:143`), `/mticks` (`settings.lua:917`).

**Verify:** in-game — `/menagerie` opens settings; `/mburst`/`/mdef`/`/mgap`/`/mhelp` work; old
`/menagerie burst` does nothing (or opens settings — acceptable); `/mlog` works, `/menagerielog` no
longer registered. Commit: `feat(app): flatten slash commands to /m* namespace`.

---

## WS-1b — Dashboard timer-bar text throttle

**File:** `dashboard.lua`. **Risk:** Low. **Isolated from WS-1a.**

**Context (verified):** `fr_frame` OnUpdate (`dashboard.lua:1378`) runs raw every frame. `SetWidth` is
the intended smooth animation — keep it. The churn is `tb.value:SetText(format("%.1f", x))` at `:1415`
(gcd) and `:1447` (swing), called every frame though the value only changes at 0.1s granularity.

**Edit — cache last text per bar, format/SetText only on change.** Both sites currently read:

```lua
                tb.value:SetText(format("%.1f", gcd_rem))   -- :1415
                tb.value:Show()
```
```lua
                tb.value:SetText(format("%.1f", rem))       -- :1447
                tb.value:Show()
```

Replace each with the change-gated form (mirrors the sweep-dot delta gate already in this handler):

```lua
                local vt = format("%.1f", gcd_rem)   -- (rem for the swing branch)
                if tb._last_value_text ~= vt then
                    tb._last_value_text = vt
                    tb.value:SetText(vt)
                end
                tb.value:Show()
```

(The `:Hide()` branches at `:1419`/`:1451` should also clear `tb._last_value_text = nil` so re-showing
re-renders — one line each.)

**Verify:** open dashboard during a dummy fight; GCD/swing text visually identical and smooth; confirm
(temporary counter) `format`/`SetText` now fire ~10×/s not per-frame. Commit:
`perf(app): throttle dashboard timer-bar text to on-change`.

---

## WS-6 + WS-1c — Finish `NS.Widgets` adoption (incl. dashboard chrome)

**WS-6 is the existing plan's Step 3** — `2026-06-15-ui-rename-and-widgets-impl.md` §3. Execute it as
written (one consumer per commit, byte-stable visuals): **3a** `debug.lua` (+ transitive `livepanel`
via `NS.CreateDebugButton`), **3b** `hunter/cliptracker.lua`, **3c** `settings.lua`. Do not re-spec here.

**WS-1c adds dashboard as the consumer that plan excluded.** **File:** `dashboard.lua`. **Risk:** Low
(visual). **Pairs with WS-1a** (same frame edits).

- `dashboard.lua:141` local `BACKDROP_THIN` → delete; use `NS.Widgets.BACKDROP_THIN` at the
  `f:SetBackdrop(...)` call (`:360`) and any other `SetBackdrop(BACKDROP_THIN)` sites (`:455`, `:486`,
  `:519`, `:654` per audit).
- Close button → `NS.CreateDebugButton` / `NS.Widgets.themed_button` (whichever the §3a re-point
  settles on), matching how livepanel's buttons render.
- **Load-order:** `widgets.lua` is slot 1, `dashboard.lua` is slot 9 — safe (widgets defined long
  before). No `builder.config.json` change.

**Dead code after:** `dashboard.lua` local `BACKDROP_THIN` (`:141`). Remove once all `SetBackdrop` sites
point at `NS.Widgets.BACKDROP_THIN`. After WS-6 + WS-1c, `widgets.lua`'s header comment becomes true
(resolves WS-5 #3).

**Verify:** `/mdash` — backdrop/close button pixel-identical to before. Commit:
`refactor(app): route dashboard chrome through NS.Widgets`.

---

## WS-1a — Dashboard frame-reuse (stop the re-exec leak)

**File:** `dashboard.lua`. **Risk:** Med-High (highest-touch edit). **Do last among dashboard items;
pair with WS-1c.**

**Root cause (verified):** the leak is **not** from `/reload` (that resets the VM). It's from
**module re-execution in a live session** (TMW re-running the profile string). On re-exec, the module
locals (`dashboard_frame`, `ui`) reset to nil so the `if dashboard_frame then return` guard
(`:336`) misses, and `CreateFrame("Frame", "MenagerieDashboard", ...)` (`:358`) builds a **new** frame
while orphaning the prior `_G.MenagerieDashboard` (frames never GC). The three module-scope ticker
frames (`update_frame` `:1361`, `fr_frame` `:1377`, `watch_frame` `:1463`) and the per-create
`dash_restorer` (`:388`) leak the same way. The offscreen-shove cleanup (`:338-356`) is a band-aid that
hides the orphan instead of reusing it.

**Fix strategy — reuse named frames across re-exec; re-bind child refs via `f.ui`.**

**Edit 1 — reuse the dashboard frame + rebind `ui`.** Replace the stale-cleanup block
(`dashboard.lua:338-356`) and the `CreateFrame` at `:358` with reuse:

```lua
local function create_dashboard()
    if dashboard_frame then return dashboard_frame end

    -- Reuse the frame from a prior module re-exec (same session) instead of orphaning it.
    local existing = _G["MenagerieDashboard"]
    if existing then
        dashboard_frame = existing
        ui = existing.ui or ui          -- rebind child-widget references captured last build
        return dashboard_frame
    end

    local f = CreateFrame("Frame", "MenagerieDashboard", UIParent, "BackdropTemplate")
    ...
```

At the **end** of `create_dashboard` (after all `ui.*` children are built, before `return f`), persist
the child table on the frame so a future re-exec can rebind:

```lua
    f.ui = ui
    dashboard_frame = f
    return f
```

> Why this works: `ui`, `dashboard_frame` are file-scope upvalues shared by every closure
> (`update_dashboard`, the ticker OnUpdates). Reassigning them on reuse updates the upvalue all closures
> see. Storing `ui` on the frame survives the local reset.

**Edit 2 — name + reuse the three ticker frames; re-`SetScript` each exec.** For `update_frame`
(`:1361`), `fr_frame` (`:1377`), `watch_frame` (`:1463`), change creation to reuse-by-name:

```lua
local update_frame = _G.MenagerieDashUpdateFrame or CreateFrame("Frame", "MenagerieDashUpdateFrame")
-- ... then SetScript as before (re-binds the closure to current upvalues on re-exec)
```
```lua
local fr_frame = _G.MenagerieDashFrameRateFrame or CreateFrame("Frame", "MenagerieDashFrameRateFrame")
```
```lua
local watch_frame = _G.MenagerieDashWatchFrame or CreateFrame("Frame", "MenagerieDashWatchFrame")
```

Re-calling `:SetScript("OnUpdate", function...)` on the reused frame replaces the stale closure with one
bound to the new upvalues — no orphaned tickers. (Reset `update_frame.elapsed`/`watch_frame.elapsed` to
0 on the reused frame, as the current code does at creation.)

**Edit 3 — `dash_restorer`** (`:388`, created inside `create_dashboard`): now only runs on first build
(create_dashboard early-returns on reuse), so it no longer multiplies. Leave as-is, or name+reuse it for
symmetry (optional). The `sx > 0`/`sy > 0` position-restore guard (`:399-401`) rejects valid edge
positions at 0 — note it but don't change here (cosmetic, separate from the leak).

**Verify (the critical step):** in a live session, trigger the module to re-execute (TMW profile
reload, no `/reload`) several times, then probe frame count — exactly **one** `MenagerieDashboard` and
one of each named ticker should exist; the dashboard renders correctly with live data (resource bars,
timer bars, pips, threat) after re-exec, confirming `ui` rebind worked. Then a real `/reload` still
builds cleanly. Commit: `fix(app): reuse dashboard frames across re-exec to stop leak`.

> **Fold-in (WS-5, doc only):** `dash_context` (`dashboard.lua:709-719`) aliases the live
> `NS.last_rotation_context`; document in the dashboard-table contract that class `custom_lines` /
> `extend_context` callbacks receive a **read-only** view. No code change.

---

## WS-3 — Immunity-table de-contamination

**File:** `core.lua:226-261`. **Risk:** Med (live rotation gating). **Requires LibAuraTypes
verification before merge** — this is a spell-ID *classification* fix, not just de-dup.

**Context (verified):** `core.lua:226-231` defines six tables. The contamination is concrete:
`IMMUNITY_TOTAL` (`:226`) currently includes `1022, 5599, 10278` — these are **Blessing/Hand of
Protection ranks (physical-immunity only, NOT total)**. Meanwhile Divine Shield/Protection ranks
(`642, 1020, 45438, 11958, 33786`) are copied into **every** per-school table. The helpers
(`has_phys_immunity` `:239` … `has_total_immunity` `:259`) each query exactly one table, so a
Divine-Shield target reads phys-immune AND magic-immune AND kick-immune, and callers can't compute
"physical-only" vs "total."

**Fix mechanism (two parts):**

1. **Make per-school tables school-specific only**, and **OR-in total** at the helper. Pattern for each
   school helper:
   ```lua
   local function has_phys_immunity(target)
      target = target or TARGET_UNIT
      return has_immunity_buff(target, IMMUNITY_PHYS) or has_immunity_buff(target, IMMUNITY_TOTAL)
   end
   ```
   Apply to `has_phys_immunity`, `has_magic_immunity`, `has_cc_immunity`, `has_stun_immunity`,
   `has_kick_immunity`. `has_total_immunity` stays single-table. Then a caller wanting "school-only"
   computes `has_magic_immunity(t) and not has_total_immunity(t)`.

2. **Re-partition the IDs** so `IMMUNITY_TOTAL` contains only genuine total-immunity auras and each
   school table contains only that school's specific auras. **This table must be verified against
   `LibAuraTypes.lua` (the cited source) before merge** — proposed corrected partition (⚠ = confirm ID):

   | ID | Spell | Belongs in |
   |----|-------|-----------|
   | 642, 1020, 45438, 11958 | Divine Shield (ranks) | TOTAL only |
   | 33786 | Cyclone | TOTAL (CC-total) — ⚠ confirm |
   | 1022, 5599, 10278 | Blessing/Hand of Protection | **PHYS** only (remove from TOTAL) |
   | 498, 5573 | Divine Protection | ⚠ phys+magic? confirm |
   | 31224 | Cloak of Shadows | MAGIC only |
   | 8178 | Grounding Totem effect | MAGIC — ⚠ confirm |
   | 19263 | Deterrence | PHYS/ranged — ⚠ confirm (dodge/deflect, not true immunity) |
   | 3169 | Limited Invulnerability Potion | PHYS — ⚠ confirm |
   | 19574/34471 | Bestial Wrath/The Beast Within | CC/STUN immunity |
   | 1719/18499 | Recklessness/Berserker Rage | STUN/fear (CC) |
   | 6615/24364 | Free Action / Living Action | STUN/movement |

   Do **not** ship the re-partition on guesswork — the verification IS the work item. The mechanism
   (part 1) is safe regardless; part 2's correctness depends on the source.

**Also verify (same pass):** `has_immunity_buff` → `Unit(target):HasBuffs(buff_ids, nil, true)`
(`core.lua:235`). Confirm the 3rd positional (match-by-ID) is the real signature — if wrong it silently
returns "never immune." Check against the framework Unit API in-game.

**Out of scope:** the `ARCANE_IMMUNE` npcID seed (`:291`) and the learned tracker — untouched. Do NOT
add per-school npcID tables (`AGENTS.md` immunity model).

**Verify:** sim harness paths that exercise immunity; in-game spot-check — Divine Shield target reads
`has_total_immunity` true and (via OR-in) phys+magic true; a Cloak-of-Shadows target reads
`has_magic_immunity` true but `has_total_immunity` false. Commit:
`fix(core): de-contaminate immunity spell-ID tables`.

---

## WS-5 — Documentation sync (do last)

**Files:** `apps/tbc-rotation/AGENTS.md` (+ `CLAUDE.md` symlink). **Risk:** Zero. **No new
`src/aio/`-level docs** (owner-confirmed).

1. **Add `livepanel.lua`** to the Shared-modules table and load-order narrative (slot 6, after
   `debug.lua`/before slot-9 panels). Note it captures `NS.CreateDebugWindow`/`NS.CreateDebugButton` at
   load → loading it before `debug.lua` silently no-ops `debugpanel` + `adaptivepanel`.
2. **Fix "Context object"** — split into "always set by `create_context` (core)" vs "added by class
   `extend_context`." Move stance/energy/rage/cp/is_stealthed/is_behind/enemy_count to the latter
   (verified: `main.lua:205-259` does not set them).
3. **`widgets.lua` header comment** — reconcile to reality after WS-6/WS-1c land (then it's true).
4. **`common.lua`** description → "shared settings-schema section factories (`Menagerie_SECTIONS`)."
5. **Slash-command table** → replace with the WS-4 `/m*` table.
6. **Dashboard-table contract** → document the `dash_context` read-only constraint (WS-1a fold-in).
7. **Add a "what to reuse when writing/updating a class" checklist** → `NS.Widgets`,
   `NS.CreateLivePanel`, `Constants.MIDDLEWARE.*`, the context fields, `register_class`,
   `Menagerie_SECTIONS`.

Commit: `docs(app): sync AGENTS.md with livepanel, context, slash commands, reuse checklist`.

---

## Summary — commits / sequencing

| Order | WS | Commit | Risk | Behavior change |
|------|----|--------|------|-----------------|
| 1 | WS-2 | `fix(app): gate debug_print/debug_log on debug_mode…` | Low | log accrual only when debug on |
| 2 | WS-4 | `feat(app): flatten slash commands to /m* namespace` | Low | command names |
| 3 | WS-1b | `perf(app): throttle dashboard timer-bar text…` | Low | none (visual identical) |
| 4 | WS-6 | (execute `ui-rename-and-widgets-impl.md` §3, 3 commits) | Low | none (visual identical) |
| 5 | WS-1c | `refactor(app): route dashboard chrome through NS.Widgets` | Low | none |
| 6 | WS-1a | `fix(app): reuse dashboard frames across re-exec…` | Med-High | none (fixes leak) |
| 7 | WS-3 | `fix(core): de-contaminate immunity spell-ID tables` | Med | rotation gating — **sim-verify** |
| 8 | WS-5 | `docs(app): sync AGENTS.md…` | Zero | docs |

Only WS-3 changes rotation behavior; it's the one that must pass the sim harness + LibAuraTypes ID
verification before merge. Everything else is visually/behaviorally byte-stable except the two
intended changes (debug log gating, command names).
```
