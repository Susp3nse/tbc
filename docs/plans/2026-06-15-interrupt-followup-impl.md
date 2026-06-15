# WS-2 Interrupt Follow-up — Tier-1 Helper + Paladin HoJ Split — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md`
> §4.2 (WS-2), §8 Q1. **Supersedes the open question in** `2026-06-14-interrupt-middleware-impl.md`.
> **Evidence:** `2026-06-14-platform-audit/01-duplication.md` (#4), `04-ergonomics.md` (#5).
> **Status (verified 2026-06-15):** Tier-2 factory DONE (4 simple classes migrated). This plan covers
> the **remaining** WS-2 work: Tier-1 helper + the warrior/shaman/hunter/druid escape-hatch adoption +
> the **Paladin Hammer-of-Justice split** (human decision: HoJ becomes a dedicated stun-interrupt,
> NOT routed through the kick-gated factory).
> **Risk:** Low (Tier-1 helper), **Med (HoJ split — it changes live shipped behavior; verify).**

## Current state

- `NS.register_interrupt_middleware(opts)` is declared at `core.lua:1634` (exported at `core.lua:1679`)
  and is used by `mage/middleware.lua:103`, `rogue/middleware.lua:105`, `priest/middleware.lua:108`,
  `paladin/middleware.lua:157`.
- The factory's `execute` (`core.lua:1668–1669`) hard-codes the 5-tuple kickability check inline:
  `local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()` then
  `castLeft and castLeft > 0 and not notKickAble`. The spell-availability gate follows at
  `core.lua:1670`: `if (not require_available or is_spell_available(spell)) and spell:IsReady(TARGET_UNIT) then`.
- **Paladin HoJ is currently routed through this factory** (`paladin/middleware.lua:157`), so it
  self-suppresses on `notKickAble == true` casts — i.e. it won't stun a non-kickable caster even
  though a stun *would* land. **This is the behavior we are changing.**
- The standalone `NS.target_is_interruptible(unit)` Tier-1 helper was never added. Warrior (6 sites:
  `warrior/middleware.lua:113,321,352,372,466,996`; +`arms.lua:480`,`fury.lua:463`,`kebab.lua:330`),
  shaman (`shaman/middleware.lua:109,202,217,241`), hunter (`rotation.lua:157,163`), and druid
  (`bear.lua:829,841`) all still hand-write the 5-tuple.

---

## Step 1 — Add the Tier-1 helper `NS.target_is_interruptible(unit)` (core.lua)

Single source of truth for the framework's 5-return `IsCastingRemains` kickability contract:

```lua
-- Returns remaining cast time (seconds, > 0) if `unit` is casting an interruptible (kickable) spell,
-- else nil. Encapsulates the IsCastingRemains 5-tuple + notKickAble semantics in one place.
function NS.target_is_interruptible(unit)
   local cast_left, _, _, _, not_kickable = Unit(unit):IsCastingRemains()
   if cast_left and cast_left > 0 and not not_kickable then
      return cast_left
   end
   return nil
end
```

Place it above `register_interrupt_middleware` so the factory can use it too.

## Step 2 — Route the Tier-2 factory through the helper

In `register_interrupt_middleware.execute` (`core.lua:1668`), replace the inline 5-tuple block with:
```lua
local cast_left = NS.target_is_interruptible(opts.unit or TARGET_UNIT)
if cast_left then
   if (not require_available or is_spell_available(spell)) and spell:IsReady(opts.unit or TARGET_UNIT) then
      return spell:Show(icon), format(log_format, cast_left)
   end
end
```
(Add the optional `opts.unit` while here — defaults to `TARGET_UNIT`; harmless, keeps parity with the
design contract.) The 4 migrated classes are unaffected — pure internal refactor.

**Verification:** mage Counterspell / rogue Kick / priest Silence still fire identically against a
kickable dummy cast. No behavior change expected.

---

## Step 3 — Paladin HoJ split: dedicated stun-interrupt (the human-chosen behavior change)

**Decision:** a *stun* interrupts a cast regardless of the `notKickAble` flag, so HoJ must **not** be
gated by kickability. Pull it out of the kick factory and hand-roll a small bespoke middleware. Per
design principle #1 (no abstraction below 2 real consumers), HoJ is the only stun-interrupt today —
**do not** build a `register_stun_interrupt` factory; keep it inline in `paladin/middleware.lua`.

First add a HoJ rank-ID array near the top of `paladin/middleware.lua` (mirrors druid's
`FAERIE_FIRE_SPELL_IDS` at `druid/class.lua:240`). **Why an array, not the single base ID:** HoJ is
`useMaxRank = true` (`paladin/class.lua:86`, base ID 853), and the learned-immune tracker keys on the
*actual cast spellID* — which will be the max rank the player has, **not** 853. Gating on a single ID
would silently miss the recorded lesson. Pass every rank:
```lua
-- Hammer of Justice ranks 1-4 (TBC). The learned-immune tracker keys on the cast spellID, and
-- useMaxRank means we may cast any of these, so query all ranks. VERIFY these IDs before shipping.
local HAMMER_OF_JUSTICE_SPELL_IDS = { 853, 5588, 5589, 10308 }
```

Then replace the factory call at `paladin/middleware.lua:157–163` with:
```lua
-- HAMMER OF JUSTICE (Interrupt via STUN — fires on ANY in-progress cast, not just kickable ones,
-- because a stun lands regardless of the notKickAble flag. Stun-immune targets are gated by the
-- explicit is_spell_immune() check in matches() — NOT by the kickability flag and NOT by IsReady().)
rotation_registry:register_middleware({
   name = "Paladin_HammerOfJustice",
   priority = 150,
   matches = function(context)
      if not context.in_combat then return false end
      if not context.settings.use_hammer_of_justice then return false end
      if not context.has_valid_enemy_target then return false end
      -- Stun-immune mobs: IsReady() does NOT consult the learned-immune tracker, so gate here
      -- explicitly (same pattern as druid Faerie Fire). One IMMUNE miss is recorded per npcID and
      -- suppresses future attempts; without this, HoJ re-fires every frame at a stun-immune boss.
      if NS.is_spell_immune(TARGET_UNIT, HAMMER_OF_JUSTICE_SPELL_IDS) then return false end
      return true
   end,
   execute = function(icon, context)
      local cast_left = select(1, Unit(TARGET_UNIT):IsCastingRemains())
      if cast_left and cast_left > 0 and A.HammerOfJustice:IsReady(TARGET_UNIT) then
         return A.HammerOfJustice:Show(icon), format("[MW] Hammer of Justice (stun-interrupt) - Cast: %.1fs", cast_left)
      end
      return nil
   end,
})
```

Key differences from the factory path:
- **No `notKickAble` check** — fires on any cast in progress. This is the intended new behavior.
- **Explicit `NS.is_spell_immune` gate in `matches()`** — `A.HammerOfJustice:IsReady(TARGET_UNIT)`
  gates on CD/range/usability only; it does **not** consult the learned-immune tracker (that tracker
  is a standalone `core.lua:354` function, reached only by explicit call — see `druid/class.lua:591`).
  Without the `matches()` gate, HoJ re-fires every frame at a stun-immune boss (no GCD burned, but the
  icon/log spam). The first IMMUNE miss is recorded per-npcID by the shared CLEU frame, after which
  this gate suppresses it.
- Preserve the exact `priority = 150` and `use_hammer_of_justice` setting key.

> **Open sub-question to confirm during impl, not blocking:** should HoJ also fire as a *general*
> stun opener (target casting nothing) when the player wants a lockdown? No — keep it interrupt-only
> (`cast_left > 0`) to match its current intent and setting label. If the user later wants a pure-stun
> mode, that's a separate strategy.

**Verification (this is the behavior-sensitive part):**
1. Dummy/target casting a **kickable** spell → HoJ fires (unchanged).
2. Target casting a **non-kickable** spell (find one flagged `notKickAble`) → HoJ **now fires** where
   it previously did not. Confirm this is the desired outcome on a real cast.
3. Stun-immune boss → HoJ attempts once, the CLEU frame records the IMMUNE miss, the `matches()`
   `is_spell_immune` gate then suppresses it — confirm no icon/log spam on subsequent frames. (This is
   the path that breaks if the explicit gate is omitted; do not rely on `IsReady` for it.)
4. `use_hammer_of_justice` off → never fires.

---

## Step 4 — Escape-hatch adoption: replace inline 5-tuples with the Tier-1 helper

Pure dedup, behavior-preserving. Replace each hand-written
`local castLeft, _, _, _, notKickAble = Unit(unit):IsCastingRemains()` + the
`castLeft and castLeft > 0 and not notKickAble` test with `local cast_left = NS.target_is_interruptible(unit)`.

Sites (one collapse each):
- **Warrior:** `middleware.lua:113,321,352,372,466,996`; `arms.lua:480`; `fury.lua:463`; `kebab.lua:330`.
- **Shaman:** `middleware.lua:109,202,217,241`.
- **Hunter:** `rotation.lua:157,163` (note: it calls `IsCastingRemains` twice per frame — once in
  `matches`, once in `execute`; the helper collapses both, and consider caching the result on context
  if both reads are in the same frame).
- **Druid:** `bear.lua:829,841`.

Warrior/shaman keep their surrounding state machines (nameplate-seeking, stance-dancing, reflection) —
**only** the kickability sub-expression changes. These were correctly left bespoke at the middleware
level; Tier-1 has value even where Tier-2 doesn't fit.

**Verification:** each class's interrupt still fires against a kickable cast and holds against a
non-kickable one. Run any available sim path (`pnpm --filter @menagerie/tbc-rotation sim:hunter`).

---

## Risks / sequencing

- **Step 3 is the only true behavior change** and it's live-shipped code — do it as its own commit
  (`fix(paladin): split Hammer of Justice into stun-interrupt`) so it bisects cleanly and can be
  reverted independently of the dedup.
- Steps 1–2 and 4 are behavior-preserving refactors; safe to batch.
- ~~Confirm `context.has_valid_enemy_target` is populated for paladin.~~ **Resolved (2026-06-15):** it's
  set in the universal context builder at `main.lua:233`
  (`ctx.has_valid_enemy_target = ctx.target_exists and not ctx.target_dead and ctx.target_enemy`) and
  paladin's `extend_context` doesn't override it — guaranteed available.
