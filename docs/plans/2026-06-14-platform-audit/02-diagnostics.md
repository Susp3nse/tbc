# Platform Audit — Diagnostics / Coaching / UI Tooling

Read-only audit of class-specific diagnostic + coaching + live-panel tooling that should become
shared `aio/` platform infrastructure. Hunter is currently the only class with any of this; every
other class (Druid, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior) has zero diagnostic UI.
The shared **debug panel** (`debugpanel.lua` + `hunter/diag.lua`) was just extracted and is the
reference pattern: **platform owns the window + chrome + refresh loop; the class supplies a pure
`build(out, ctx)` content callback.**

## The established extension pattern (the model to copy)

`core.lua` ships the chrome primitives, consumed by `debugpanel.lua`:

- **`NS.DBG_THEME`** (core.lua:558) — the Menagerie warm palette (bg/border/accent/text/text_dim).
  This is the *one* theme classes should use. The three Hunter panels each redefine their own
  near-identical `THEME` table (cliptracker.lua:55, meleeweave.lua:39, adaptivepanel.lua:29) in a
  cold blue palette — pre-rebrand drift, see Finding D.
- **`NS.CreateDebugWindow(title)`** (core.lua:674) — a movable, clamped, backdrop'd frame with title +
  `closeBtn` + separator. Returns the frame; caller sets size/position and wires `closeBtn`.
- **`out` writer** (debugpanel.lua:48–91) — a reusable, allocation-free row buffer with three verbs:
  `out:header(text)`, `out:kv(label, value, hex)`, `out:line(text)`. The panel calls `reset_entries()`,
  builds generic core rows, invokes the class callback, then `layout_entries()` diff-renders into a
  pooled set of FontStrings. No per-frame table allocation (respects the combat no-alloc rule).
- **The hook**: `rotation_registry.class_config.debug_panel = build_sections` (diag.lua:161). The
  panel checks `cc.debug_panel` each refresh and calls `cc.debug_panel(out, ctx)` (debugpanel.lua:288).
- **Refresh loop**: one shared `OnUpdate` at 10 Hz gated on `:IsShown()`, plus a 0.5 Hz watcher that
  hides the panel when its setting is turned off (debugpanel.lua:344–364).

That split — **frame/chrome/loop in platform, content callback in class** — is exactly what the three
remaining Hunter tools need but do not yet have.

---

## Ranked summary

| # | Finding | Leverage | Generic mechanism | Hunter-specific content | Future beneficiaries |
|---|---------|----------|-------------------|-------------------------|----------------------|
| **A** | **Generic registered live panel** (`NS.CreateLivePanel` + `class_config.panels`) | **Highest** | Window + section/row scaffold + Export + toggle-watch + refresh loop. `adaptivepanel` and the `out`-style debug panel are the same widget. | Stat/damage/decision row content | **All 9 classes** — any class wanting a "what is the engine thinking" readout |
| **B** | **Shared Export/copy window** (`NS.ShowCopyWindow(title, text)`) | **High** | Modal scrollable EditBox with Select-All highlight | CSV payload string | Every panel that exports (3 Hunter panels already duplicate it 3×) |
| **C** | **Generic GCD timing / clip tracker** (`NS.SwingTracker`) | **Medium-High** | Per-swing interval measurement, severity bucketing, haste-change rejection, cause attribution, combat summary, CSV | Auto-Shot spell IDs, ranged-haste buckets, "clip" framing | Rogue/Warrior/Cat (melee swing weaving), any auto-attack class |
| **D** | **Theme + chrome consolidation** | **Medium** | Use `DBG_THEME` + `CreateDebugWindow` everywhere | none | All future panels (free correctness + visual consistency) |
| **E** | **"Should I do X now" traffic-light coach** (`NS.CreateCoachLight`) | **Low-Medium** | Single big colored light + range badge + ring timer + state→color mapping | Raptor/melee-weave timing math | Rogue (Shiv/Riposte windows), Enhance, Feral weaving — *speculative* |
| **F** | **One shared diagnostic refresh ticker** | **Low** | Replace N per-panel `OnUpdate` frames with one registry-driven tick | none | Perf hygiene across all panels |

---

## Finding A — Generic registered live panel (HIGHEST leverage)

### Evidence
- `adaptivepanel.lua:85–218` builds a window via raw `CreateFrame` + local `header()`/`row()`/`spacer()`
  closures that lay out label/value FontString pairs down a `y` cursor.
- `debugpanel.lua:106–187` does the *same job* — `ensure_row`/`layout_entries` render header + kv rows
  into pooled FontStrings — but generically, driven by the `out` writer, with no class code touching
  frames.

These are two implementations of one widget: **a vertical list of `HEADER` / `label: value` rows that
a class populates each refresh.** The debug panel already solved it the right way (data-driven, pooled,
no per-frame alloc). `adaptivepanel` is the older hand-rolled version with hardcoded rows and its own
frame, toggle watcher (adaptivepanel.lua:445–459), and Export button.

### Generic vs. specific
- **Generic**: the window, the section/row layout engine, the Export button, the `show_*` toggle
  watcher, the refresh-on-visible loop, auto-height. (~250 of adaptivepanel's ~460 lines.)
- **Hunter-specific**: *which* rows exist and what they read (`State.rap`, `State.shootDPS`, the
  `optionLine` scoring colorizer, fire-history codes). ~150 lines of pure content.

### Proposed shared API (`aio/livepanel.lua`, or fold into `debugpanel.lua`)
Generalize the debug panel's `out` writer into a reusable factory so a class can register *named*
panels beyond the single shared debug panel:

```lua
-- Platform: NS.CreateLivePanel(opts) -> panel
--   opts = { title, width, setting_key, build(out, ctx), export(ctx) (optional) }
-- Returns a panel object that owns its frame, Export button (only if opts.export given),
-- toggle-watch on NS.cached_settings[setting_key], and a 10Hz refresh that calls build(out, ctx).
-- `out` is the SAME writer contract as the debug panel: out:header / out:kv(label,val,hex) / out:line.

-- Class side (e.g. hunter/adaptivepanel.lua shrinks to content only):
NS.CreateLivePanel({
   title = "Adaptive",
   width = 360,
   setting_key = "show_adaptive_panel",
   build = function(out, ctx)
      local s = NS.HunterAdaptive and NS.HunterAdaptive.GetState()
      if not s then return end
      out:header("INPUTS")
      out:kv("RAP", fmt(s.rap))
      out:kv("Speed", format("%.3fs", s.rangedSpeed))
      -- ...decision rows with hex coloring via out:kv(label, val, hex)
   end,
   export = function() return NS.HunterAdaptive.GetDecisionCSV() end,
})
```

Registration shape mirrors what's already there: keep the single `class_config.debug_panel` callback
for the *shared* debug window, and let classes spin up **additional** named panels via
`CreateLivePanel` for richer per-class readouts. No registry array needed if classes just call the
factory at load — but if you want them discoverable/toggleable from settings, add
`class_config.panels = { {...}, {...} }` and have one platform module instantiate them.

### Refactor impact
`adaptivepanel.lua` drops from ~460 → ~150 lines (content only). The frame, the `header`/`row`/`spacer`
closures, the Export button, the toggle watcher, and the refresh ticker all vanish into the factory.

### Beneficiaries
All 9 classes. The moment any class wants to surface engine internals (mana-tick prediction, DoT
clip windows, combo-point math), they get a themed, toggleable, exportable panel for ~30 lines of
`build()`.

### Caution / scope
Don't over-generalize the *widgets*. The debug panel's `out` model (header / kv / line) covers ~95%
of adaptivepanel. The one thing it lacks is **per-cell colorization for kv values** — but `out:kv`
already takes a `hex` arg (debugpanel.lua:69), so that's covered. Resist adding bars/sparklines to the
generic panel until a second class actually asks; `out:line` with a text bar is enough.

---

## Finding B — Shared Export / copy window (HIGH leverage, trivial)

### Evidence — duplicated 3×, near-identical
- `cliptracker.lua:1180–1259` `ShowExportWindow` — creates a 600×400 modal, scroll frame, multiline
  EditBox, highlights all, Ctrl+C hint.
- `adaptivepanel.lua:377–428` `ShowDecisionExport` — same modal (760×460), same EditBox + highlight.
- (meleeweave has no export, but would want one.)

Each re-creates the frame, backdrop, title, close button, scroll frame, EditBox, and highlight logic.
~50 lines × 2, soon ×N.

### Proposed shared API (add to `core.lua` next to `CreateDebugWindow`)
```lua
function NS.ShowCopyWindow(title, text)
   -- lazily creates ONE shared singleton frame keyed by NS, reuses it.
   -- sets EditBox text, HighlightText(), SetFocus(), Show().
end
```
Built on `NS.CreateDebugWindow(title)` for the chrome so it inherits the warm theme automatically.

### Refactor impact
Both Hunter export functions collapse to one line: `NS.ShowCopyWindow("Export Clip Data", csv)`.
Removes ~100 duplicated lines today.

### Beneficiaries
Any panel that exports. This is the cheapest, highest-certainty extraction — pure dedup, no behavior
change, no per-class abstraction risk.

---

## Finding C — Generic per-GCD/per-swing timing & clip tracker (MEDIUM-HIGH leverage)

### Evidence
`cliptracker.lua` is 1360 lines. The bulk is a **generic auto-attack interval analyzer**:
- swing-interval measurement against expected speed (`OnAutoShotFired`, cliptracker.lua:443–666)
- haste-change interval rejection (cliptracker.lua:476–489)
- dynamic ping/jitter noise floor (cliptracker.lua:212–215)
- severity bucketing G/Y/O/R against settable thresholds (cliptracker.lua:303–317)
- cause attribution by priority: melee > cast-bar > movement > last-cast > unknown (cliptracker.lua:535–600)
- per-cause / per-severity / per-haste-bucket stats + combat summary + CSV export (cliptracker.lua:679–1178)
- a filterable scrolling log window (cliptracker.lua:878–1110)

### Generic vs. specific
- **Generic mechanism**: "measure the gap between successive auto-attacks, attribute what filled it,
  classify how bad it was, accumulate stats, render a log." This is identical math for a Rogue/Warrior
  melee main-hand swing or a Cat-form auto.
- **Hunter-specific content**: `AUTO_SHOT_SPELL_IDS` (cliptracker.lua:264), ranged-haste buckets keyed
  to ranged-weapon speeds (cliptracker.lua:217–226), the word "clip" + the "don't delay Auto Shot"
  framing, `MeleeSpellNames` proving melee range, and the `RecordSuggestion` hook the Hunter rotation
  calls (rotation.lua:507+).

### Proposed shared API (`aio/swingtracker.lua`)
```lua
-- NS.CreateSwingTracker(opts) -> tracker
--   opts = {
--     swing_event_spell_ids = {...},   -- which CLEU SPELL_CAST_SUCCESS ids count as "a swing fired"
--     get_expected_speed = function() return UnitRangedDamage("player") end,
--     haste_buckets = {...} (optional),
--     thresholds = { t1_key="clip_threshold_1", ... },  -- settings keys
--     melee_proof_spells = {...} (optional),
--     enabled = function() return NS.cached_settings.clip_tracker_enabled end,
--   }
-- tracker exposes :OnSwingFired internally (wired via Listener), :GetLastResult(),
-- :GetRates(), :GetCSV(), and a log window via NS.CreateLivePanel/ShowCopyWindow.
```

### Pragmatic recommendation
This is the **biggest single file** and the most Hunter-entangled (suggestion correlation, ranged
windup). Extracting the *log window + Export + stats-strip* (Findings A+B) is high-value and low-risk
**now**. Extracting the *measurement core* is worth it **only when a second auto-attack class
(Rogue/Warrior/Cat) actually wants swing-clip tracking** — until then, generalizing the attribution
heuristics risks building an abstraction with one consumer (violates the "2+ classes" bar). Flag it,
don't build it speculatively. Recommended split: do the UI extraction with Finding A; leave the
detector in Hunter behind a clean `NS.CreateSwingTracker`-shaped seam for later.

### Beneficiaries
Rogue (main-hand/off-hand swing weaving), Warrior (slam/heroic-strike timing), Feral cat (auto
between specials) — all real future cases, but none implemented today.

---

## Finding D — Theme + chrome consolidation (MEDIUM leverage, correctness win)

### Evidence
All three Hunter panels hardcode a **cold-blue** palette that predates the Menagerie warm rebrand:
- cliptracker.lua:55 `accent = { 0.424, 0.388, 1.0 }` (blue-violet)
- meleeweave.lua:39, adaptivepanel.lua:29–43 same family.

Meanwhile the platform ships `NS.DBG_THEME` (warm orange `#e08a3c`, core.lua:558) and the dashboard
ships its own copy of the *warm* palette (dashboard.lua:138). So there are currently **three** theme
tables: `DBG_THEME` (warm, shared), dashboard `THEME` (warm, duplicated), and the Hunter-panel cold
palette (stale). The recent rebrand commits (`015433c`, `30216ec`) migrated the in-game UI to warm but
missed these three panels.

### Proposal
- Make `NS.DBG_THEME` + `NS.DBG_BACKDROP` (already exported, core.lua:572–573) the single source of
  truth. Have dashboard.lua and any extracted panel read from it instead of redefining.
- Route all panel frames through `NS.CreateDebugWindow` (or the `CreateLivePanel` factory) so they
  inherit the theme, the movable/clamped behavior, and the standard close button for free.

### Beneficiaries
Every panel — and it closes the rebrand gap (the three Hunter windows are visibly off-brand today).
Note: this naturally falls out of Findings A+B; extracting the panels *through* the shared factory
fixes the theme as a side effect.

---

## Finding E — "Should I do X now" traffic-light coach (LOW-MEDIUM, speculative)

### Evidence
`meleeweave.lua` is a read-only coach: a single big colored light (GRAY/GREEN/ORANGE/RED) with a
title (HOLD/GO/OUT/BACK), an action label, a range badge, a cooldown ring, and a status bar
(meleeweave.lua:438–565). The `Evaluate` function (meleeweave.lua:267–436) is one giant
decision tree producing `{ state, action, reason, color, ... }`.

### Generic vs. specific
- **Generic mechanism**: a state→color traffic light with a ring timer + two badges + status bar.
  The *rendering* (`Coach:Create`/`Coach:Refresh`) is reusable; it's basically a single-cell version
  of the dashboard.
- **Specific**: ~95% of the file is Hunter melee-weave timing math (range buckets 5–7yd, ranged
  windup, deadzone, raptor-pending tracking). This is **not** reusable; it's the entire point.

### Proposal (defer)
The render chrome (`CreateCoachLight(opts)` → a frame with `:SetLight(color, title, action, timer,
ring)`) *could* be shared, but the content is irreducibly per-mechanic and **no second class needs a
traffic light today.** Rogue Shiv/Riposte windows or Enhance weaving are plausible future consumers,
but speculative. Recommendation: **do not extract now.** If/when a second coach appears, lift the
~120-line render shell then. Lowest leverage of the findings precisely because the reusable surface is
small and the consumer count is currently one.

---

## Finding F — Consolidate the refresh tickers (LOW leverage, hygiene)

### Evidence — every diagnostic owns its own `OnUpdate` frame
- debugpanel.lua:344 (10 Hz) + :354 (0.5 Hz watcher)
- dashboard.lua:1388 (10 Hz) + :1404 (frame-rate animator) + :1490 (0.5 Hz watcher)
- cliptracker.lua:1314 (0.5 Hz)
- meleeweave.lua:608 (20 Hz!)
- adaptivepanel.lua:446 (5 Hz)

That's ~8 independent `OnUpdate` frames, each re-reading `NS.cached_settings` and re-checking
`:IsShown()`. The pattern is identical: "every N seconds, if my setting is on, show+refresh; if off,
hide." meleeweave runs at 20 Hz (every 0.05s) which is the heaviest and least justified.

### Proposal
A single platform `NS.RegisterDiagnostic({ setting_key, interval, on_show, on_hide, on_refresh })`
ticker that owns *one* `OnUpdate` and fans out. Falls out naturally if Findings A+B land (the
`CreateLivePanel` factory already needs exactly this loop — so build it once there and have everything
register). Pure perf/consistency; no user-visible change. Also lets you standardize refresh rates
(nothing needs 20 Hz).

### Beneficiaries
All panels; mild frame-time savings and one obvious place to gate diagnostics off entirely.

---

## Duplication callouts (answering "three separate OnUpdate frames?")

1. **Yes — ~8 `OnUpdate` frames** across the diagnostics, all doing the same toggle-watch + refresh
   dance (Finding F).
2. **Row rendering is implemented twice**: the data-driven pooled renderer in `debugpanel.lua`
   (correct) and the hand-rolled `header`/`row` closures in `adaptivepanel.lua` (legacy). They should
   be one helper (Finding A).
3. **Export window implemented 2× verbatim** (cliptracker + adaptivepanel), Finding B.
4. **Theme table defined 3× (stale) + 2× (warm)**, Finding D.
5. **`getRangedTiming` / haste math** appears in cliptracker (`GetSpellCastTime`, cliptracker.lua:319),
   meleeweave (`getRangedTiming`, meleeweave.lua:101), and adaptive — three slightly different
   reconstructions of ranged speed/haste/windup. This is Hunter-internal and out of scope for *shared*
   extraction, but worth a Hunter-local helper. Noting it for completeness, not proposing platform work.

---

## Recommended sequencing (do the cheap, high-certainty wins first)

1. **Finding B** (ShowCopyWindow) — ~1 hour, pure dedup, zero risk.
2. **Finding A** (CreateLivePanel) — extract the panel factory from the union of debugpanel + adaptivepanel;
   migrate adaptivepanel onto it. This *also* delivers D (theme) and F (ticker) for those panels.
3. **Finding D** sweep — point dashboard + any stragglers at `DBG_THEME`.
4. **Leave C and E behind clean seams.** Don't generalize the swing detector or the coach shell until a
   second class (Rogue/Warrior/Feral) creates real demand — generalizing them now would be a
   one-consumer abstraction, which the repo's own guidance warns against.
