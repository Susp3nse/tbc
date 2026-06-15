# Shaman Class Cleanup — Design (post-2026-06-15 three-agent audit)

> **Type:** Design (rationale + per-tier direction; concrete edits sketched, not exhaustive line-edits).
> **Date:** 2026-06-15. **Risk:** Mixed per tier (see each). **Scope:** the Shaman class only —
> `src/aio/shaman/*.lua` — plus one tiny shared helper added in `core.lua`/`class.lua`. No other class
> or the shared framework dispatch is touched.
> **Source:** a read-only three-agent audit of the Shaman class (framework-duplication lens,
> within-class duplication lens, per-frame hot-path lens). Each finding below was cross-checked against
> the actual source before being written here (framework symbols verified to exist; the resto scanner
> duplication and the totem triplication confirmed by direct read).

---

## 0. Summary & relationship to existing work

The Shaman class is **fundamentally healthy**. Verified-clean and explicitly out of scope: burst gating
(`should_auto_burst`/`is_burst`/force flags used correctly), racials (already shared via
`create_racial_strategy`), immunity (zero per-school npcID tables — the interrupt/fear tables are
legitimate targeting data, not immunity modeling), no load-time settings capture, no `{}` allocations
in any combat path, correct `_*_valid` cache-flag discipline, and no 200-local-limit risk.

The real work clusters into **four tiers**, each a workstream below. Two of them were independently
flagged by **two agents each** (the strongest signal): the restoration healing layer (WS-1) and the
totem-management triplication (WS-2).

**Precedent to follow — do not reinvent:**

| Concern | Established pattern to mirror | Where |
|---|---|---|
| Spec strategies duplicated across specs → factory | `NS.make_*(prefix, opts)` extraction | recent `refactor(warlock)` commit `b11235a` |
| Group-heal scanning + casting | memoized `NS.scan_healing_targets` wrapper + `try_heal_cast_fmt` | `paladin/healing.lua`, `druid/healing.lua`, `priest/holy.lua`, `priest/discipline.lua` |
| Shared middleware priorities | `Constants.MIDDLEWARE.*` / `Priority.MIDDLEWARE.*` | `core.lua:178-193` |

The single highest-value item (WS-1) is *also* the only one that changes rotation **behavior** — it
adopts the framework's incoming-heal-aware target selection. Everything else (WS-2/3/4) is meant to be
behaviorally byte-stable (DRY, perf, constants).

---

## WS-1 — Restoration healing layer  *(FrameworkDup HIGH ×2 + HotPath HIGH; `restoration.lua`)*

The single biggest issue in the class, flagged from two independent angles. `restoration.lua` re-rolls
the framework's group-healing layer with a **strictly weaker** copy, **bypasses** the documented
heal-cast contract, and **re-scans the whole raid 2–4× per frame**.

### 1a. Re-implemented, weaker scanner  *(framework duplication — HIGH)*

**Evidence:** `restoration.lua:40-123` defines its own `PARTY_UNITS`/`RAID_UNITS` (`:40-42`),
pre-allocated `healing_targets` (`:46-50`), `is_in_raid` (`:52`), `scan_healing_targets()` (`:57-108`),
and `get_lowest_target()` (`:114-123`) with a manual insertion sort. Core already ships every one of
these: `NS.scan_healing_targets(context, options)` / `NS.get_lowest_hp_target(threshold)` /
`NS.PARTY_UNITS` / `NS.RAID_UNITS` / `NS.is_in_raid` (`core.lua:695-826`).

The shaman copy is **strictly weaker**: it sorts on raw `hp` (`restoration.lua:87,101`), while the
framework sorts on `effective_hp` from `predict_effective_deficit` (`core.lua:786-787,804`) — which
accounts for incoming heals, HoTs, absorbs, and incoming damage over the cast window. The shaman copy
also omits the `has_aggro`/`is_tank`/`deficit`/`incoming_dps` decoration the framework computes
(`core.lua:782-790`).

### 1b. Bypasses the heal-cast contract  *(correctness — HIGH)*

**Evidence:** resto casts party/raid heals via `A.HealingWave:IsReady(unit)` /
`A.ChainHeal:IsReady(unit)` + `:Show(icon)` directly — `restoration.lua:212,220,244,385,415,444`.
`safe_heal_cast` documents that **`IsReady(party/raid unitID)` is the wrong path** — you must check
`IsReady("player")` (CD + mana) and route *targeting* through `A.HealingEngine:SetTarget(unit)` so TMW
injects `[@unit,help]` into the macro (`core.lua:593-608`, comment at `:596-599`). `NS.try_heal_cast` /
`try_heal_cast_fmt` (`core.lua:644-666`) do exactly this. Today's direct `IsReady(unitID)` likely only
"works" for `player`/`focus` by luck and silently fails to target other party/raid members.

### 1c. Scans 2–4× per combat frame, unmemoized  *(perf — HIGH)*

**Evidence:** `get_lowest_target` (`restoration.lua:114`) calls `scan_healing_targets()`
*unconditionally* and is invoked from 11 sites (`:170,180,219,377,384,401,405,414,430,434,443`). In one
resto frame the active path runs it 2–4× (e.g. `NaturesSwiftness.matches` → `ChainHeal.matches` →
`ChainHeal.execute`). Each scan walks up to 40 raid units with ~4 `Unit*` predicate calls + range +
2 health calls each → up to ~160 unit API calls/frame where one scan would do. The class's largest,
most raid-size-sensitive per-frame cost.

### Direction (one coherent change, mirrors `paladin/healing.lua`)

1. **Delete** the local `PARTY_UNITS`/`RAID_UNITS`/`healing_targets`/`is_in_raid`/`scan_healing_targets`
   (`restoration.lua:40-108`).
2. **Memoize the framework scan once per frame.** Add a module-level pre-allocated
   `RESTO_SCAN_OPTIONS = { range_spell = "Chain Heal" }` and call
   `NS.scan_healing_targets(context, RESTO_SCAN_OPTIONS)` exactly once — inside the already-memoized
   `get_resto_state` (`restoration.lua:138`, gated by `_resto_valid`). Stash the returned
   `(entries, count)` on `resto_state`. This is the paladin/druid/priest pattern (memoized local
   wrapper over `NS.scan_healing_targets`).
3. **Reshape `get_lowest_target(threshold)`** to read the cached sorted entries and return
   `(unit, effective_hp)` (entries are pre-sorted ascending by `effective_hp`, so it's the first entry
   under threshold — O(1)/O(k), no re-scan). Keeps the existing `(unit, hp)` two-value call sites
   working; `hp` simply becomes `effective_hp` for the log strings.
4. **Route every heal cast through `NS.try_heal_cast_fmt`** (`restoration.lua:212-444`), exactly like
   `priest/holy.lua:91-276`. Drop the bare `A.X:IsReady(unit)` + `:Show(icon)` idiom.
5. **Keep** the explicit `focus`-target (tank) priority checks in `Resto_NaturesSwiftnessEmergency`
   (`:174-177`), `Resto_NSHealingWave` (`:209-216`), and `Resto_EarthShieldMaintain` (focus-only by
   design). Those read a single unit's `UnitHealth` (cheap) and encode an intentional tank-first policy;
   leave them. Only the *party/raid lowest* lookups and the *cast path* change.

### Behavior change & risk

**Risk: Med — this is the one tier that changes rotation behavior, intentionally.** Target selection
moves from raw-HP to incoming-heal-aware `effective_hp`. A target with a big incoming heal already in
flight will correctly de-prioritize (no overheal); the thresholds (`90/70/50`) now compare against
`effective_hp`. This is the framework's deliberate model (and what every other healer in the repo
uses), but it *will* change which unit gets picked in some frames.

**Verify:** `build` + `lint:lua`; in-game in a party/raid — confirm Chain Heal/HW/LHW actually land on
the intended (lowest effective-HP) unit, that targeting works for non-focus party members (the bug 1b
likely hid), and that NS-emergency still prioritizes the tank. If a shaman sim path exists, run it;
otherwise this is in-game-verified. ~70 lines deleted, net simpler.

---

## WS-2 — Totem management: DRY the triplication  *(CrossSpec HIGH + HotPath MED; all spec files + `class.lua`)*

`TotemManagement` is the most-duplicated logic in the class — three near-byte-identical ~85-line
strategies — and the per-frame totem-identity checks re-call `GetTotemInfo` because the once-per-frame
refresh throws away the totem name.

### 2a. `TotemManagement` triplicated  *(CrossSpec HIGH)*

**Evidence:** `Ele_TotemManagement` (`elemental.lua:109-196`), `Enh_TotemManagement`
(`enhancement.lua:427-522`), `Resto_TotemManagement` (`restoration.lua:273-359`). The four-slot
drop-and-refresh matches+execute are structurally identical (same `Constants.TOTEM_REFRESH_THRESHOLD`,
same `NS.totem_allowed`, same fire/earth/water/air guard shape, the earth/Tremor block is byte-identical
across all three). The *only* real per-spec differences are:

| Axis | elemental | enhancement | restoration |
|---|---|---|---|
| setting-key prefix | `ele_*` | `enh_*` | `resto_*` |
| fire default | `totem_of_wrath` | `searing` | `searing` |
| air default | `wrath_of_air` | `windfury` | `wrath_of_air` |
| log tag | `[ELE]` | `[ENH]` | `[RESTO]` |
| skip fire when… | (never) | `enh_twist_fire_nova` | (never) |
| skip air when… | (never) | `enh_twist_windfury` | (never) |
| respect `is_moving` | yes (`:113`) | **no** (melee drops while moving) | yes (`:277`) |

**Direction:** extract `NS.make_totem_management(opts)` in `class.lua` (next to `refresh_totem_state` /
`resolve_totem_spell` / `totem_allowed`, which it already uses), mirroring the warlock `make_*`
factories. `opts` carries: `prefix` (log tag), per-slot setting keys + defaults, optional
`skip_fire(s)` / `skip_air(s)` predicates, and a `respect_is_moving` boolean. Returns a strategy table.
Three call sites collapse to one line each. ~255 lines (3×85) → one ~55-line factory + 3 calls. **Bonus:**
`shaman/AGENTS.md:36` already *claims* totem management "is shared across specs" — today that's false;
this makes the doc true (WS-5).

### 2b. `refresh_totem_state` discards the totem name → re-reads everywhere  *(HotPath MED; the linchpin)*

**Evidence:** `refresh_totem_state` (`class.lua:190-198`) calls `GetTotemInfo(slot)` for all four slots
once/frame but stores only active/remaining — it **throws away `name`**. So every consumer that needs
totem *identity* re-calls `GetTotemInfo` + a fragile `name:find(...)` substring search:
- Tremor-in-earth-slot check, **7 copies**: `elemental.lua:125,161`, `enhancement.lua:446,486`,
  `restoration.lua:288,323`, `middleware.lua:508`.
- Fire-Elemental-in-fire-slot: `class.lua:340-341` re-calls `GetTotemInfo(1)` *immediately after*
  `refresh_totem_state` just ran on slot 1.
- Windfury/Fire-Nova twist identity: `enhancement.lua:553-559,581-582,618-619,649-650`.

**Direction:** have `refresh_totem_state` stash the slot names (or precomputed booleans
`earth_is_tremor` / `fire_is_fire_elemental` / `air_is_windfury` / `fire_is_fire_nova`) into
`totem_state` once/frame. Add `NS.tremor_active_in_earth_slot()` (reads the cached boolean). Every
consumer reads the cached value; the 7 `name:find("Tremor")` copies and the `class.lua:340-341` re-read
collapse. This is the linchpin that resolves both the cross-spec dup *and* HotPath M1/M2.

### 2c. `FireElemental` byte-identical ele/enh  *(CrossSpec LOW)*

**Evidence:** `Ele_FireElemental` (`elemental.lua:199-214`) and `Enh_FireElemental`
(`enhancement.lua:764-779`) differ only in setting key (`ele_`/`enh_use_fire_elemental`) and log tag.
**Direction:** fold into a tiny `NS.make_fire_elemental(prefix, setting_key)` (or absorb as an opt of
the totem factory). Low — two sites.

### Risk

**Risk: Low-Med — behavior must stay byte-stable.** The factory must reproduce each spec's exact
guards, especially: enhancement's `respect_is_moving = false` (it drops totems mid-move) and its
twist-skip predicates, and the per-slot defaults. **Verify:** `build` + `lint:lua`; in-game per spec —
totems drop/refresh exactly as before (same totem in each slot, same skip behavior under Tremor / WF
twist / FNT twist / solo-vs-group). Diff the compiled output's totem logic if feasible.

---

## WS-3 — `extend_context` per-frame waste  *(HotPath HIGH/MED; `class.lua` + spec builders)*

`extend_context` (`class.lua:300-350`) runs every frame for every spec and does more than it needs to.

1. **~13 redundant `Unit("player")` / `Unit("target")` calls** (`class.lua:301-322`). Each
   shield/proc/debuff field re-invokes `Unit(unitID):...` fresh (10× player, 3× target).
   **Direction:** hoist `local pu = Unit(PLAYER_UNIT); local tu = Unit(TARGET_UNIT)` once, reuse.
2. **All-spec aura state computed regardless of active spec** (`class.lua:308-322`). Stormstrike
   debuff/stacks (`:321-322`, enh-only) and `has_natures_swiftness` (`:316`, resto-only) are read every
   frame even in, e.g., pure Elemental — then the spec builders just copy them
   (`restoration.lua:151` copies `has_natures_swiftness`). **Direction:** move spec-only aura reads into
   the matching `context_builder` (which already runs once/frame and is the documented home for spec
   state); keep only genuinely shared fields (mana, shields, clearcasting, flame_shock) in
   `extend_context`. ⚠ **Pre-check:** grep that no cross-spec consumer (dashboard `buffs` table,
   debugpanel, `/mdash`) reads `ctx.stormstrike_*` / `ctx.has_natures_swiftness` directly — if one does,
   leave that field in `extend_context` or expose via the builder. (Design decision deferred to the
   pre-check; default is move.)
3. **`enemy_count` range scan every frame even when AoE disabled** (`class.lua:325`).
   `MultiUnits:GetByRangeInCombat(30)` runs unconditionally but is only consumed by AoE strategies that
   early-out when `aoe_threshold == 0` (default). **Direction:** gate the assignment on
   `cached_settings.aoe_threshold and aoe_threshold > 0` (settings are refreshed before context build);
   default `enemy_count = 1` otherwise.
4. **`ctx.combat_time` recomputed** (`class.lua:304`) though `create_context` already sets it from the
   same `CombatTime()` call (`main.lua`). **Direction:** delete the line; core's value stands.

### Risk

**Risk: Low — no behavior change intended; purely "compute once / compute only when needed."** Item 2
is the only one with a sharp edge (the consumer pre-check). **Verify:** `build` + `lint:lua`; in-game —
each spec behaves identically; dashboard still shows the right buff/debuff state; AoE still triggers
when `aoe_threshold > 0` and `enemy_count` reads 1 when AoE is off.

---

## WS-4 — Small cleanups & doc sync  *(FrameworkDup MED + CrossSpec MED; `middleware.lua`, spec files, docs)*

Low-risk tidy-ups; bundle or do opportunistically.

1. **Middleware magic numbers → constants** *(FrameworkDup MED).* `Shaman_CurePoison` priority `350`
   (`middleware.lua:353`) and `Shaman_CureDisease` `340` (`:378`) re-type literals that exist as
   `Priority.MIDDLEWARE.DISPEL_CURSE` (`core.lua:183` = 350) and `DISPEL_POISON` (`:184` = 340) —
   reference the constants. `ShieldMaintain` (250, `:290`), `Purge` (200, `:399`), `AutoTremor`
   (260, `:497`) have **no** matching constant; either add named `Priority.MIDDLEWARE` entries or leave
   with an explanatory comment (recommend: add constants for consistency, low stakes — call in review).
2. **TTD predicate written out 4× → helper** *(CrossSpec MED / FrameworkDup M5).* The shape
   `fs_ttd <= 0 or not context.ttd or context.ttd <= 0 or context.ttd >= fs_ttd` (and its inverse)
   appears at `elemental.lua:230,359`, `enhancement.lua:711,731`. These use a per-spec setting key
   (`ele_fs_min_ttd` / `enh_fs_min_ttd`), so they can't call the existing `NS.ttd_too_short` (which
   reads the fixed `cd_min_ttd`). **Direction:** add a tiny `NS.ttd_below(context, seconds)` helper in
   `core.lua` and call it with the per-spec value. Keep the FS *strategies* separate (ele has FS as a
   standalone priority entry; enh folds FS weaving inside `Enh_Shock` — merging would force one spec's
   concerns on the other).
3. **AoE fire-totem fallback dup'd ele/enh** *(CrossSpec MED).* The "Fire Nova else Magma if fire slot
   empty/expiring and no Fire Elemental" tail is near-identical at `elemental.lua:327-336` and
   `enhancement.lua:796-806`. **Direction:** extract `NS.try_aoe_fire_totem(icon, context)` for just
   that tail; **keep the two AoE strategies separate** (ele weaves Chain Lightning; enh deliberately
   avoids CL — a 2s cast breaks melee momentum). Only if already touching these files.
4. **`want_water` re-derived within `ShieldMaintain`** *(CrossSpec LOW).* `middleware.lua:296-306`
   (matches) and `:321-332` (execute) recompute the same `want_water` intra-strategy. Optional local
   helper; only if already editing the file.
5. **Doc sync** *(do last).* Update `shaman/AGENTS.md` (+ `CLAUDE.md` symlink): the "totem management is
   shared across specs" claim (`:36`) becomes true after WS-2 — keep it and point at
   `NS.make_totem_management`. Clarify the **shared 6s shock CD** gotcha (`:50`): it is **not** modeled
   in code anywhere — Earth/Flame/Frost Shock share a cooldown enforced *server-side* by WoW; the
   rotation relies on each spell's `:IsReady()`/`:GetCooldown()`. Nothing to DRY there; the gotcha is
   about *behavior*, not a code path. (This corrects a wrong assumption the audit brief carried in.)

### Risk

**Risk: Low/Zero.** Items 1-4 are behaviorally byte-stable; item 5 is docs. **Verify:** `build` +
`lint:lua`; spot-check middleware priorities still order the same; `/mlog` shows the same FS-weave
decisions.

---

## Sequencing

Front-load the highest-value isolated item; land the totem-name refactor before the perf pass that
depends on it; docs last.

1. **WS-1** (restoration healing) — highest value, isolated to `restoration.lua`, the one behavior
   change → verify carefully first while it's its own PR.
2. **WS-2** (totem DRY + `refresh_totem_state` name-stash) — touches all spec files + `class.lua`; the
   name-stash (2b) is the linchpin for WS-3's totem-identity wins, so land it here.
3. **WS-3** (`extend_context` perf) — depends on 2b for the totem-identity reads; do the consumer
   pre-check for item 2 first.
4. **WS-4** (constants, helpers, docs) — small, independent; docs sub-item last so it reflects WS-2 as
   shipped.

Each WS is its own PR with class scope: `refactor(shaman)` / `fix(shaman)` / `perf(shaman)` /
`docs(shaman)`. Only **WS-1** changes rotation behavior (intended: incoming-heal-aware targeting) — it's
the one to verify in-game/sim before merge. WS-2/3/4 are behaviorally byte-stable.

## Open decisions for the human

- **WS-1 thresholds:** the `90/70/50` heal thresholds now compare against `effective_hp` instead of raw
  `hp`. Keep the same numbers (recommended — matches other healers) or re-tune after in-game testing?
- **WS-3 item 2:** if the dashboard/debugpanel reads `ctx.stormstrike_*` / `ctx.has_natures_swiftness`
  directly, do we keep those in `extend_context` (simplest) or expose them through the spec builder?
  Decide after the pre-check grep.
- **WS-4 item 1:** add new `Priority.MIDDLEWARE` constants for Shield/Purge/Tremor (consistency) vs
  leave as commented literals (less churn in shared `core.lua`)?
