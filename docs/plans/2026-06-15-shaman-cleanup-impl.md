# Shaman Class Cleanup — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-15-shaman-cleanup-design.md`.
> **Date:** 2026-06-15. **Scope:** `src/aio/shaman/*.lua` + small helpers in `core.lua` / `class.lua`.
> **Ships as:** one PR per workstream (each independently buildable + verifiable).
> **Build/verify gate for every step:** `corepack pnpm --filter @menagerie/tbc-rotation build` succeeds,
> then `corepack pnpm --filter @menagerie/tbc-rotation lint:lua` is clean, then the per-step in-game
> check. WS-1 additionally needs in-game (and sim, if a shaman path exists) verification because it is
> the only behavior change.

Execution order (highest-value isolated first; totem name-stash before the perf pass that needs it;
docs last): **WS-1 → WS-2 → WS-3 → WS-4.**

All line numbers below were read from source on 2026-06-15; re-confirm before editing if the files have
moved.

---

## WS-1 — Restoration: adopt the framework healing layer

**File:** `apps/tbc-rotation/src/aio/shaman/restoration.lua`. **Risk:** Med (only behavior change —
incoming-heal-aware target selection). **Pattern to mirror:** `paladin/healing.lua:66-90` (memoized
scan wrapper + `get_lowest_hp_target`) and `priest/holy.lua` (cast via `try_heal_cast_fmt`).

**Context (verified):** `NS.scan_healing_targets(context, options)` (`core.lua:769-807`) returns
`(out_array, count)` sorted ascending by `effective_hp`; entries carry
`.unit/.hp/.is_player/.has_aggro/.deficit/.incoming_dps/.effective_hp/.is_tank`. Options honor
`range_spell`, `cast_time`, `include_player`, `out`. `NS.try_heal_cast_fmt(spell, icon, target_unit,
prefix, name, info_fmt, ...)` (`core.lua:652-663`) does `IsReady("player")` + `HE.SetTarget(unit)` +
`Show`. Only one class is active at a time (`PlayerClass` gate), so sharing core's default
`core_healing_targets` buffer is safe; still, scan **once/frame** by memoizing in `get_resto_state`.

### Edit 1 — delete the local scanner, add memoized state

Remove `restoration.lua:37-123` (the `PARTY/RAID_UNITS`, `healing_targets`, `is_in_raid`,
`scan_healing_targets`, `get_lowest_target` block). Replace the local resolver locals (`:31-35` keep
`format`; you can drop `GetTotemInfo` only if WS-2's name-stash lands first — keep for now) and add:

```lua
-- Pre-allocated scan options (no {} in combat). range_spell gates by Chain Heal reach.
local RESTO_SCAN_OPTIONS = { range_spell = "Chain Heal" }
local scan_healing_targets = NS.scan_healing_targets
local try_heal_cast_fmt = NS.try_heal_cast_fmt
```

Extend the pre-allocated `resto_state` (`:129-134`) with cached scan results:

```lua
local resto_state = {
    earth_shield_charges = 0,
    earth_shield_duration = 0,
    natures_swiftness_active = false,
    mana_tide_cd = 0,
    heal_entries = nil,   -- sorted (asc effective_hp) array from the once/frame scan
    heal_count = 0,
}
```

In `get_resto_state` (`:138-155`), after the `_resto_valid` guard, scan exactly once and cache:

```lua
local function get_resto_state(context)
    if context._resto_valid then return resto_state end
    context._resto_valid = true

    resto_state.heal_entries, resto_state.heal_count =
        scan_healing_targets(context, RESTO_SCAN_OPTIONS)
    -- ... existing earth_shield / natures_swiftness / mana_tide_cd reads unchanged ...
    return resto_state
end
```

Add a local `get_lowest_target(state, threshold)` that reads the **cached** sorted entries (no re-scan),
returning `(unit, effective_hp)` to preserve the existing two-value call sites:

```lua
-- Entries are pre-sorted ascending by effective_hp; first under threshold is the most injured.
local function get_lowest_target(state, threshold)
    local entries, count = state.heal_entries, state.heal_count
    if entries and count > 0 then
        local entry = entries[1]
        if entry and entry.unit and entry.effective_hp < threshold then
            return entry.unit, entry.effective_hp
        end
    end
    return nil, 100
end
```

### Edit 2 — re-point every consumer to `(state, threshold)` + cast via `try_heal_cast_fmt`

Each strategy already receives `state`. Replace `get_lowest_target(N)` → `get_lowest_target(state, N)`
at `:180,219,377,384,401,405,414,430,434,443`, and replace the bare cast idiom. Representative — Chain
Heal (`:382-389`):

```lua
    execute = function(icon, context, state)
        local unit, hp = get_lowest_target(state, 90)
        if not unit then return nil end
        return try_heal_cast_fmt(A.ChainHeal, icon, unit, "[RESTO]", "Chain Heal",
            "(%s) - HP: %.0f%%", unit, hp)
    end,
```

Apply the same shape to `Resto_LesserHealingWave.execute` (`:411-419`), `Resto_HealingWave.execute`
(`:440-448`), and `Resto_NSHealingWave` (`:218-222`, the party-member branch). The `focus`-branch casts
(`:212`, `:209-216` and the NS-emergency focus check `:174-177`) **stay** — they target a single known
unit; just swap their `A.X:IsReady(FOCUS_UNIT) + :Show` to `try_heal_cast_fmt(A.X, icon, FOCUS_UNIT,
...)` for the contract (HE.SetTarget). `Resto_EarthShieldMaintain` (`:243-249`) similarly →
`try_heal_cast_fmt(A.EarthShield, icon, FOCUS_UNIT, ...)`.

**Dead code after:** the entire `:37-123` block, and the local `format`/`GetTotemInfo` if no longer
referenced (check — `GetTotemInfo` is still used by `Resto_TotemManagement` until WS-2). List before
removing.

**Verify:** `build` + `lint:lua`; in a party/raid — Chain Heal/HW/LHW land on the lowest-effective-HP
unit, targeting works for **non-focus** party members (the bug 1b likely hid), NS-emergency still
tank-first. Commit: `fix(shaman): adopt framework healing scanner + cast contract in restoration`.

---

## WS-2 — Totem management factory + `refresh_totem_state` name-stash

**Files:** `class.lua` (factory + refresh), `elemental.lua` / `enhancement.lua` / `restoration.lua`
(call sites), `middleware.lua` (tremor reader). **Risk:** Low-Med (must stay byte-stable). **Mirror:**
the warlock `make_*(prefix, opts)` factories.

### Edit 1 — `refresh_totem_state` stashes identity (the linchpin, do first)

`class.lua:175-198`. Extend `totem_state` with name/identity fields and populate them in the existing
once/frame loop (the loop already calls `GetTotemInfo(slot)` and currently discards `name`):

```lua
local totem_state = {
    fire_active = false, fire_remaining = 0,
    earth_active = false, earth_remaining = 0,
    water_active = false, water_remaining = 0,
    air_active = false, air_remaining = 0,
    earth_is_tremor = false,
    fire_is_fire_elemental = false,
    -- (add fire_is_fire_nova / air_is_windfury here if WS folds in the twist identity reads)
}

local function refresh_totem_state()
    local now = GetTime()
    for slot = 1, 4 do
        local have, name, start, dur = GetTotemInfo(slot)
        local active = have and name ~= "" and name ~= nil
        totem_state[SLOT_ACTIVE_KEYS[slot]] = active
        totem_state[SLOT_REMAINING_KEYS[slot]] = active and ((start + dur) - now) or 0
        if slot == 1 then totem_state.fire_is_fire_elemental = active and name:find("Fire Elemental") ~= nil end
        if slot == 2 then totem_state.earth_is_tremor = active and name:find("Tremor") ~= nil end
    end
end

NS.tremor_active_in_earth_slot = function() return totem_state.earth_is_tremor end
```

Then in `extend_context` (`class.lua:338-344`) drop the redundant `GetTotemInfo(1)` re-read and use the
cached flag:

```lua
        ctx.fire_elemental_active = ctx.totem_fire_active and totem_state.fire_is_fire_elemental
```

### Edit 2 — `NS.make_totem_management(opts)` factory in `class.lua`

Add next to `resolve_totem_spell`/`totem_allowed` (`class.lua:236-257`). The body is the resto/ele block
generalized — per-slot setting key + default from `opts`, log tag from `opts.prefix`, optional
`skip_fire`/`skip_air` predicates, optional `respect_is_moving`, and the earth/Tremor skip via the new
`NS.tremor_active_in_earth_slot()`:

```lua
-- opts = {
--   prefix, respect_is_moving,
--   fire = {key, default}, earth = {key, default}, water = {key, default}, air = {key, default},
--   skip_fire = function(s) ... end,   -- optional (enh: s.enh_twist_fire_nova)
--   skip_air  = function(s) ... end,   -- optional (enh: s.enh_twist_windfury)
-- }
function NS.make_totem_management(opts)
    local prefix = opts.prefix
    local function drop_slot(icon, context, slot_opt, lookup, slot_active, slot_remaining, is_earth)
        local s = context.settings
        local setting = s[slot_opt.key] or slot_opt.default
        if setting == "none" then return nil end
        if not NS.totem_allowed(s[slot_opt.condition], context.in_group) then return nil end
        if is_earth and s.use_auto_tremor and context.totem_earth_active
            and NS.tremor_active_in_earth_slot() then return nil end
        if NS.timer_needs_refresh(slot_active, slot_remaining, Constants.TOTEM_REFRESH_THRESHOLD) then
            local spell = NS.resolve_totem_spell(setting, lookup)
            if spell and spell:IsReady(NS.PLAYER_UNIT) then
                return spell:Show(icon)
            end
        end
        return nil
    end
    -- matches mirrors the same gating without casting; execute walks fire→earth→water→air calling
    -- drop_slot, honoring opts.skip_fire/opts.skip_air and the fire_elemental_active guard, returning
    -- the first non-nil + "<prefix> <Slot> Totem" log. (~55 lines total.)
    return { requires_combat = true, matches = ..., execute = ... }
end
```

> Implementation note: keep the per-slot `condition` keys (`totem_fire_condition` etc.) — they are
> **shared** across specs already (not prefixed), so they live in `opts.<slot>.condition` pointing at
> the same shared key. Reproduce enhancement's exact fire/air skip and `respect_is_moving = false`.

### Edit 3 — replace the three call sites

`elemental.lua:109-196`, `enhancement.lua:427-522`, `restoration.lua:273-359` each become:

```lua
-- elemental.lua
local Ele_TotemManagement = NS.make_totem_management({
    prefix = "[ELE]", respect_is_moving = true,
    fire  = { key = "ele_fire_totem",  default = "totem_of_wrath", condition = "totem_fire_condition",  lookup = NS.FIRE_TOTEM_SPELLS },
    earth = { key = "ele_earth_totem", default = "strength_of_earth", condition = "totem_earth_condition", lookup = NS.EARTH_TOTEM_SPELLS },
    water = { key = "ele_water_totem", default = "mana_spring",  condition = "totem_water_condition", lookup = NS.WATER_TOTEM_SPELLS },
    air   = { key = "ele_air_totem",   default = "wrath_of_air", condition = "totem_air_condition",  lookup = NS.AIR_TOTEM_SPELLS },
})
```

Enhancement adds `respect_is_moving = false`, `skip_fire = function(s) return s.enh_twist_fire_nova end`,
`skip_air = function(s) return s.enh_twist_windfury end`, and `enh_*` keys with `searing`/`windfury`
defaults. Restoration uses `resto_*` keys with `searing`/`wrath_of_air` defaults, `respect_is_moving =
true`. (Exact opts table per the design's WS-2 diff matrix.)

### Edit 4 — middleware Tremor reader + fold the twist identity reads (optional, same PR)

`middleware.lua:508` `GetTotemInfo(2)`+`:find("Tremor")` → `NS.tremor_active_in_earth_slot()`. If folding
in HotPath M2, add `air_is_windfury`/`fire_is_fire_nova` to `refresh_totem_state` and re-point
`enhancement.lua:553-559,581-582,618-619,649-650` to the cached flags.

### Edit 5 — `FireElemental` factory (WS-2c, optional)

`NS.make_fire_elemental(prefix, setting_key)` in `class.lua`; replace `elemental.lua:199-214` and
`enhancement.lua:764-779`.

**Dead code after:** the three inline `TotemManagement` bodies, the 7 `name:find("Tremor")` copies, the
`class.lua:340-341` re-read, the two `FireElemental` bodies (if Edit 5 done). List explicitly.

**Verify:** `build` + `lint:lua`; in-game per spec — totems drop/refresh identically (same totem per
slot; correct skips under Tremor, WF twist, FNT twist, solo vs group; enh still drops while moving).
Commit: `refactor(shaman): extract make_totem_management + cache totem identity`.

---

## WS-3 — `extend_context` per-frame trims

**File:** `class.lua:300-350`. **Risk:** Low (no behavior change). **Do item-2 pre-check first.**

**Pre-check (item 2):** before moving spec-only aura reads, confirm no shared consumer reads them
directly:

```bash
grep -rn -E "stormstrike_debuff|stormstrike_charges|has_natures_swiftness" apps/tbc-rotation/src/aio \
  --include="*.lua" | grep -vE "shaman/(enhancement|restoration)\.lua|class\.lua:3(1|2)"
```
If `dashboard.lua` / `debugpanel.lua` hit, keep that field in `extend_context` (or expose via the
builder); otherwise move it.

### Edits

1. **Hoist Unit handles** (`:300-322`): `local pu = Unit(PLAYER_UNIT); local tu = Unit(TARGET_UNIT)` once,
   replace the 10 `Unit("player"):` and 3 `Unit("target"):` calls with `pu:` / `tu:`.
2. **Move spec-only reads** (pending pre-check): cut `ctx.stormstrike_debuff`/`stormstrike_charges`
   (`:321-322`) into `get_enh_state`; cut `ctx.has_natures_swiftness` (`:316`) into `get_resto_state`
   (it already copies it at `restoration.lua:151` — read it directly there instead). Keep mana, shields,
   clearcasting, `flame_shock_duration` shared.
3. **Gate `enemy_count`** (`:325`):
   ```lua
   local aoe_t = NS.cached_settings and NS.cached_settings.aoe_threshold
   ctx.enemy_count = (aoe_t and aoe_t > 0 and MultiUnits:GetByRangeInCombat(30)) or 1
   ```
4. **Delete `ctx.combat_time = Unit("player"):CombatTime() or 0`** (`:304`) — `create_context` already
   sets `ctx.combat_time` (main.lua). Confirm core sets it (it does) before deleting.

**Verify:** `build` + `lint:lua`; in-game per spec identical; dashboard buff/debuff state correct; AoE
fires when `aoe_threshold > 0`, `enemy_count == 1` when off. Commit:
`perf(shaman): trim redundant per-frame work in extend_context`.

---

## WS-4 — Constants, helpers, doc sync

**Files:** `middleware.lua`, `core.lua` (helper), spec files, `shaman/AGENTS.md` (+ `CLAUDE.md`).
**Risk:** Low/Zero.

1. **Dispel constants** — `middleware.lua:353` priority `350` → `Priority.MIDDLEWARE.DISPEL_CURSE`;
   `:378` `340` → `Priority.MIDDLEWARE.DISPEL_POISON`. (Open decision: add
   `Priority.MIDDLEWARE.SHIELD/PURGE/TREMOR` for `:290/:399/:497` or leave commented literals.)
2. **`NS.ttd_below(context, seconds)` helper** in `core.lua` (near `ttd_too_short` at `:216`):
   ```lua
   local function ttd_below(context, seconds)
      return seconds and seconds > 0 and context.ttd and context.ttd > 0 and context.ttd < seconds
   end
   NS.ttd_below = ttd_below
   ```
   Re-point `elemental.lua:230,359` and `enhancement.lua:711,731` to `NS.ttd_below(context,
   context.settings.ele_fs_min_ttd)` (resp. `enh_fs_min_ttd`), matching the existing boolean sense at
   each site.
3. **`NS.try_aoe_fire_totem(icon, context)`** (only if touching these files) — extract the fire-totem
   tail shared by `elemental.lua:327-336` / `enhancement.lua:796-806`; call from both `Enh_AoE`/`Ele_AoE`
   executes. Keep the strategies otherwise separate.
4. **Doc sync** (last): in `shaman/AGENTS.md` keep the "totem management shared across specs" line
   (`:36`) and point it at `NS.make_totem_management`; rewrite the shock-CD gotcha (`:50`) to state the
   6s shared CD is enforced **server-side by WoW**, not modeled in code (no DRY target). Mirror into the
   `CLAUDE.md` symlink (same file).

**Verify:** `build` + `lint:lua`; middleware priority order unchanged; `/mlog` shows identical FS-weave
decisions. Commit(s): `refactor(shaman): use dispel priority constants + ttd_below helper` and
`docs(shaman): correct totem-sharing and shock-CD notes`.

---

## Summary — commits / sequencing

| Order | WS | Commit | Risk | Behavior change |
|------|----|--------|------|-----------------|
| 1 | WS-1 | `fix(shaman): adopt framework healing scanner + cast contract in restoration` | Med | **yes** — incoming-heal-aware targeting (intended) |
| 2 | WS-2 | `refactor(shaman): extract make_totem_management + cache totem identity` | Low-Med | none (byte-stable) |
| 3 | WS-3 | `perf(shaman): trim redundant per-frame work in extend_context` | Low | none |
| 4 | WS-4 | `refactor(shaman): dispel constants + ttd_below helper` / `docs(shaman): …` | Low/Zero | none |

Only **WS-1** changes rotation behavior; it's the one to verify in-game (and sim, if a shaman path
exists) before merge. WS-2/3/4 must come out behaviorally byte-stable — the verification for each is
"acts identically, just faster / less duplicated."
