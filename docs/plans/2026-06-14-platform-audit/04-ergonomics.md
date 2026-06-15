# Platform Ergonomics Audit — New-Class Author Burden

**Scope:** `apps/tbc-rotation/src/aio/` — how much non-rotation boilerplate a class author must
write, and how the shared platform could absorb it. READ-ONLY analysis.

**Headline:** The platform is *further along than its docs admit*. The schema `SECTIONS` factory
(`common.lua`), the recovery/trinket middleware factories, and the declarative `playstyle_spells`
validation path (`core.lua`) already absorb large swaths of what `NEW_CLASS_GUIDE.md` still
documents as hand-written boilerplate. **The single biggest ergonomic win is not new code — it is
rewriting `NEW_CLASS_GUIDE.md`**, which actively teaches authors to hand-roll machinery the platform
now provides. After that, a handful of small, mechanical absorptions remain.

---

## Ranked Summary

| # | Finding | Burden today | Effort | Barrier-lowering |
| - | ------- | ------------ | ------ | ---------------- |
| 1 | **`NEW_CLASS_GUIDE.md` is stale** — teaches hand-rolled `validate_playstyle_spells`, `version`, manual recovery middleware, all already superseded | Author copies dead patterns; doubles every file | Docs-only | ★★★★★ |
| 2 | **Per-file NS/Action guard boilerplate** (53 occurrences) — same 6-10 line gate at top of every module | ~8 lines × every file | Small (helper or build-injected header) | ★★★★☆ |
| 3 | **`extend_context` cache-flag resets** (26 hand-written `ctx._x_valid = false`) — coupling between playstyle and context, easy to forget → stale-state bug | 1 line per playstyle, manually kept in sync | Medium (registry-owned flag reset) | ★★★★☆ |
| 4 | **`class.lua` setmetatable + `NS.A` dance** (9/9 identical) + the Action-table assembly is pure ceremony | ~3 fixed lines + structural | Small (factory `NS.register_actions`) | ★★★☆☆ |
| 5 | **Interrupt middleware** — 6/9 classes hand-roll a near-identical "interrupt the current cast" block | ~20 lines, copy-paste-rename | Medium (factory; opt-out for warrior/shaman) | ★★★☆☆ |
| 6 | **Trinket middleware is opt-in but universal** (9/9 call `register_trinket_middleware()`) — should be auto-registered, opt-out | 1 line + remembering to add it | Trivial | ★★★☆☆ |
| 7 | **Sharp edges are documented, not enforced** — "never capture settings at load", "no inline tables in combat", snake_case keys. Lint/wrapper could make some impossible | n/a (latent bugs) | Medium | ★★★☆☆ |
| 8 | **`register_class` has no defaults** — every class fills `idle_playstyle_name = nil`, `get_idle_playstyle = nil` etc. explicitly | a few optional fields | Trivial | ★★☆☆☆ |
| 9 | **Schema still needs the four "tail" sections appended by hand** (`S.burst()`, `S.dashboard()`, `S.debug()`, recovery) — a `General`-tab composer could inject them | ~5 lines per class | Small | ★★☆☆☆ |
| 10 | **No "register one settings tab / dashboard row / debug section" one-liner** beyond `SECTIONS` | varies | Larger | ★★☆☆☆ |

---

## Detailed Findings

### 1. `NEW_CLASS_GUIDE.md` is stale and teaches dead boilerplate ★★★★★

This is the highest-leverage finding because the guide *is* the onboarding path, and it currently
instructs authors to write code the platform already eliminated. Concretely, the guide is wrong about:

- **§5f Spell Validation** (`docs/NEW_CLASS_GUIDE.md:260-289`) tells the author to hand-write a
  `validate_playstyle_spells(playstyle)` function with per-playstyle `if/elseif` chains and call
  `NS.validate_playstyle_spells = ...`. **Reality:** zero classes do this. All 9 supply a declarative
  `playstyle_spells = { combat = {...}, ... }` table on `register_class` and the registry runs the
  validation generically (`core.lua:1434-1482`; `rogue/class.lua:162-195`). The hand-rolled version
  is ~30 lines of pure ceremony per class that the guide still actively recommends.
- **§5g `version` field** (`docs/NEW_CLASS_GUIDE.md:296`, `:326`) is listed as **required**. Per the
  root CLAUDE.md "Build versioning" rule there are **no per-class versions** — one `NS.VERSION` from
  `package.json` covers the whole platform. `settings.lua:36` already prefers
  `NS.format_class_version(cc)`. The per-class `version = "v1.0.0"` is vestigial; the guide should
  drop it.
- **§6 middleware** (`docs/NEW_CLASS_GUIDE.md:393-461`) walks the author through hand-writing a
  `register_middleware` block for recovery items. **Reality:** 8/9 classes call
  `NS.register_recovery_middleware{...}` (declarative; `core.lua:1671`) and 9/9 call
  `NS.register_trinket_middleware()`. The guide never mentions either factory.
- **§2 build commands** (`:68-75`) reference `node build.js`/`dev-watch.js` and a `discoverClasses`
  auto-discovery model. **Reality:** the build is `pnpm --filter @menagerie/tbc-rotation build` driven
  by an explicit `loadOrder` in `builder.config.json` — there is no `ORDER_MAP` or auto-discovery in
  `build.ts` anymore (per `apps/tbc-rotation/AGENTS.md`).
- **§3 / §16** reference `_G.Menagerie` collisions with the old namespace and a `MEMORY.md`, and the
  `SECTIONS` factory (`S.recovery/S.burst/S.dashboard/S.debug/S.trinkets`) — the *actual* schema DSL
  every class uses — is **not documented at all**.

**Recommendation:** rewrite the guide around the real surface: (a) `SECTIONS` schema factory, (b)
`playstyle_spells` declarative validation, (c) `register_recovery_middleware` /
`register_trinket_middleware`, (d) drop `version`. This alone roughly halves the perceived
boilerplate for a new author with zero code changes.

---

### 2. Per-file NS/Action guard boilerplate (53 occurrences) ★★★★☆

Every module repeats a gate like (`rogue/middleware.lua:4-20`):

```lua
local _G = _G
local format = string.format
local A = _G.Action
if not A then return end
if A.PlayerClass ~= "ROGUE" then return end
local NS = _G.Menagerie
if not NS then
    print("|cFFFF0000[Menagerie Rogue Middleware]|r Core module not loaded!")
    return
end
A = NS.A
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
```

`grep -c "Core module not loaded"` → **53** copies across the class tree. The
`A.PlayerClass ~= "X"` check and the imports vary only by class string and which `NS.*` handles the
file happens to use.

**What they should write:** nothing for the gate. Two viable absorptions:

- **Build-injected header.** The build already controls module wrapping/ordering. It knows the class
  name (folder) and slot. It could prepend the standard guard + the common `local NS, A, Unit,
  rotation_registry = ...` preamble, and skip the body if the gate fails. Authors write only the
  meaningful code.
- **Or a runtime helper:** `local NS, A, Unit, rr = require_menagerie("ROGUE")` returning `nil` to
  bail. Less clean in Lua-5.1/WoW (no real `require`), so the build-injection route is preferred.

**Caveat (surface honestly):** build-injected headers add magic that isn't visible in the source
file, which cuts against "the human watches every line." A middle ground is a single documented
one-liner helper authors paste once per file (`if not NS.guard("ROGUE") then return end`) that does
the gate + stashes handles on a returned table.

---

### 3. `extend_context` cache-flag resets are an un-enforced coupling ★★★★☆

The `context_builder` pattern requires each playstyle to reset its own cache flag every frame, and
that reset lives in `class.lua`'s `extend_context`, far from the playstyle file that *owns* the flag
(`rogue/class.lua:209-212`):

```lua
ctx._combat_valid = false
ctx._assassination_valid = false
ctx._subtlety_valid = false
```

`grep "_valid = false" */class.lua` → **26** of these. Add a playstyle, forget the reset → the
builder's `if context._x_valid then return state end` short-circuit never clears → **stale combat
state silently served every frame.** This is exactly the "make the mistake impossible" target: the
flag's existence is implied by `register(playstyle, …, { context_builder = … })`, so the registry
already has everything it needs to own the reset.

**What they should write:** nothing. When `register` is called with a `context_builder`, the registry
records the playstyle; `create_context` / `get_playstyle_state` invalidates that playstyle's cached
state once per frame automatically (e.g. bump a per-frame epoch counter and compare, instead of a
boolean the author must clear). The author keeps only the *interesting* part of `extend_context`
(real per-class fields like `energy`, `cp`).

**Effort:** medium — touches `core.lua` registry + `main.lua` `create_context`. But it deletes a
whole bug class.

---

### 4. `class.lua` Action-table + `setmetatable` ceremony (9/9 identical) ★★★☆☆

Every class ends its action defs with the same three lines (`rogue/class.lua:81-88`):

```lua
A = setmetatable(Action[A.PlayerClass], { __index = Action })
NS.A = A
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
```

`grep -c` confirms the `setmetatable(Action[A.PlayerClass], …)` line is present in all 9 `class.lua`.
The metatable fallback is load-bearing (so `A.Fireball` and `A.GetToggle` both resolve) but it is
100% mechanical.

**What they should write:**

```lua
local A = NS.register_actions({ Fireball = ..., Frostbolt = ... })  -- does setmetatable + NS.A = A
```

A `NS.register_actions(tbl)` factory that assigns `Action[A.PlayerClass] = tbl`, wraps the metatable,
sets `NS.A`, and returns it. Pairs naturally with finding #2.

---

### 5. Interrupt middleware: 6/9 hand-roll a near-identical block ★★★☆☆

`mage/middleware.lua:105-124` (`Mage_Counterspell`) and `rogue/middleware.lua:105-126`
(`Rogue_Kick`) are structurally identical — only the spell, the `setting_key`, and the log string
differ:

```lua
matches: in_combat and settings.use_X and has_valid_enemy_target
execute:
    local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
    if castLeft and castLeft > 0 and not notKickAble and A.X:IsReady(TARGET_UNIT) then
        return A.X:Show(icon), format("[MW] X - Cast: %.1fs", castLeft)
    end
```

6 of 9 classes carry a copy (mage, rogue, priest, paladin, shaman, warrior — though **warrior and
shaman are genuinely class-unique**: warrior does stance-dancing + PvP CC fallback chains
(`warrior/middleware.lua:448-454`), shaman gates Earth Shock on the GCD).

**What they should write:**

```lua
NS.register_interrupt_middleware({
    name = "Mage_Counterspell", spell = A.Counterspell,
    setting_key = "use_counterspell", priority = ...,
})
```

A factory that emits the canonical "interrupt the current cast" middleware. Warrior/shaman simply
**don't call it** and keep their bespoke versions — opt-out by omission, same pattern as the recovery
factory. Lowers the floor for the simple 4 while leaving the complex 2 untouched.

---

### 6. Trinket middleware is universal but still opt-in ★★★☆☆

`grep -c "register_trinket_middleware()"` → **9/9** classes call it, always identically, always after
`NS.A` is set. A line that every class always writes is a default, not a choice. The matching schema
section (`S.trinkets()`) is likewise in every schema.

**What they should write:** nothing. `register_class` (or `main.lua` post-registration) auto-registers
trinket middleware unless the class passes `auto_trinkets = false`. Same logic applies to the
universal `S.burst()` / `S.dashboard()` / `S.debug()` schema tail (see #9). **Trade-off:** the
factory currently runs from `middleware.lua` because it needs `NS.A` (set in `class.lua`, which loads
earlier). Auto-registration would move the call into the dispatcher's first-frame init or a
post-`register_class` hook so `NS.A` is guaranteed present.

---

### 7. Sharp edges are documented, not enforced ★★★☆☆

The AGENTS gotchas — *never capture settings at load*, *no inline `{}` in combat*, *snake_case keys
everywhere*, *load-order late-binding* (`schema.lua` can't see `NS`) — are all "you'll be told in the
docs, then find out at runtime." Some are enforceable:

- **Captured settings:** a lint rule (the repo already runs `luacheck` via `pnpm lint:lua`) flagging
  module-level `A.GetToggle(` outside a `matches`/`execute` closure would catch the classic bug the
  guide warns about at `docs/NEW_CLASS_GUIDE.md:819`.
- **snake_case keys:** `ui.lua`/`core.lua` iterate the schema at load; a one-time assert that every
  `key` matches `^[a-z0-9_]+$` turns a silent "setting never reads back" into a load error.
- **Inline tables in combat:** hardest to enforce statically; leave documented but call it out in the
  rewritten guide with the `context_builder` pre-alloc pattern front-and-center.

These don't lower keystroke count but they convert latent runtime bugs into load-time/lint errors —
high value for *iteration* speed.

---

### 8. `register_class` optional-field defaults ★★☆☆☆

`register_class` (`core.lua:1425-1430`) stores the config verbatim; callers consistently write
`idle_playstyle_name = nil`, `get_idle_playstyle = nil`, sometimes `gap_handler = nil`. These are
already optional in the dispatcher (it nil-checks `cc.extend_context`, `cc.gap_handler`, etc.), so the
explicit `= nil` assignments are author noise the guide encourages. **Fix:** document them as
omittable and stop listing `nil` defaults in the guide's example. No code change needed — purely
"don't make authors type nils."

---

### 9. Schema "General-tab tail" is hand-appended per class ★★☆☆☆

Every General tab ends with the same four shared sections (`rogue/schema.lua:66-76`):

```lua
S.recovery({...}), S.burst(), S.dashboard(), S.debug(),
```

The `SECTIONS` factory already makes each a one-liner — good. But the *sequence* is identical across
classes and easy to forget one (e.g. omit `S.debug()` → no debug panel toggle). A composer like
`S.general_tail({ recovery = {...} })` returning the four-section array, or having `ui.lua`/the
registry auto-append `burst/dashboard/debug` to tab 1 if absent, removes the "did I include all
four?" checklist item. Low effort, modest payoff.

---

### 10. No higher-level "register a tab / dashboard row / debug section" API ★★☆☆☆

The owner's goal mentions "adding to the UI should be a small declarative act." Today the schema
*tabs* are declarative tables and `SECTIONS` covers shared sections, but there is no
`NS.add_settings_tab(...)` / `NS.add_dashboard_row(...)` / `NS.add_debug_section(...)` one-liner — a
class composes raw tables. For the dashboard this is already quite declarative (`register_class`'s
`dashboard` table, `rogue/class.lua:225-263`), so the gap is mainly settings tabs. This is the
largest-effort item and the least urgent: the existing table-composition model is fine; the win is
mostly more `SECTIONS`-style factories for *common* sections (interrupts, defensives, CD-min-TTD)
that recur across classes, not a new registration API.

---

## What a Class Author *Legitimately* Must Customize (the irreducible core)

After the absorptions above, the genuinely class-unique surface is small and appropriate:

- **`class.lua`:** the `Action[...]` spell/item table (real WoW IDs — irreducibly unique) and
  `Constants` (BUFF_ID/DEBUFF_ID/resource costs).
- **`register_class`:** `name`, `playstyles`, `get_active_playstyle`, the *real* fields in
  `extend_context`, `playstyle_spells`, `dashboard`, optional `gap_handler`.
- **`schema.lua`:** the class-specific tabs/sections (spec toggles, thresholds). The shared tail is
  factories.
- **playstyle files:** the actual rotation — strategy arrays + `context_builder`. **This is the only
  thing the author should be spending real thought on**, which is the stated goal.
- **`middleware.lua`:** only genuinely bespoke middleware (warrior stance-dance interrupt, shaman GCD
  shock). Recovery/trinket/simple-interrupt become factory calls.

The platform architecture is sound; the boilerplate that remains is mostly *ceremony the docs
perpetuate* (#1) plus a few mechanical absorptions (#2–#6). Nothing here requires re-architecting the
registry.
