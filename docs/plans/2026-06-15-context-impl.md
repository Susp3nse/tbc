# WS-7 — Common Context Helper + Registry-Owned Cache Reset — Implementation Plan

> **Type:** Implementation (concrete file edits). **Design:** `2026-06-14-platform-hardening-design.md`
> §4.7 (WS-7), §8 Q4. **Evidence:** `2026-06-14-platform-audit/01-duplication.md` (#6),
> `04-ergonomics.md` (#3).
> **Status (verified 2026-06-15):** both halves not started. 26 hand-written `_valid = false` resets
> remain across 8 classes. **Risk:** Low (context helper) · **Med (cache-reset — per-frame hot path,
> behavior-sensitive).**
> **Recommendation:** do the helper now; gate the epoch reset behind the safe wins and an explicit
> alloc/behavior audit (it touches every frame).

## Why this is the higher-risk workstream

Both edits live on the per-frame context path. The context-triple helper is mechanical and
behavior-preserving. The **registry-owned cache reset** changes how *every* playstyle's per-frame
state cache is invalidated — get it wrong and the rotation serves stale combat state every frame, or
allocates on the hot path. Treat the two halves as separate commits with separate verification.

---

## Part A — `NS.apply_common_context(ctx)` (Low risk)

**File:** `apps/tbc-rotation/src/aio/core.lua` (new helper); call from each `class.lua` `extend_context`.

8/9 classes hand-write the identical triple. Centralize it (and the `IsMoving()` mixed-type truthiness
guard) in one place:

```lua
-- Sets the byte-identical is_moving / is_mounted / combat_time triple on ctx.
-- Canonicalizes the IsMoving() return (it can be nil / false / 0 / number).
function NS.apply_common_context(ctx)
   local moving = Player:IsMoving()
   ctx.is_moving = moving ~= nil and moving ~= false and moving ~= 0
   ctx.is_mounted = ...      -- match the existing per-class expression
   ctx.combat_time = ...     -- match the existing per-class expression
end
```

**Fix a latent divergence while here:** hunter (`hunter/class.lua:432`) assigns
`ctx.is_moving = Player:IsMoving()` **raw**, skipping the truthiness normalization the other 7 apply.
Routing hunter through the helper canonicalizes it. Confirm no hunter strategy relies on the raw
(possibly `0`/number) value before switching — it shouldn't, but check `grep is_moving src/aio/hunter`.

**Call sites to replace** (the inline triple): `mage/class.lua:193–196`, `paladin/class.lua:316–318`,
`priest/class.lua:216–218`, `rogue/class.lua:204–207`, `shaman/class.lua:310–312`,
`warlock/class.lua:247–249`, `warrior/class.lua:306–308`, `hunter/class.lua:431–433`. **Druid** is the
9th exception (no triple in `class.lua`; `balance.lua:162` calls `IsMoving()` locally) — leave druid
alone unless adding the triple is a deliberate behavior addition.

**Optional:** `NS.set_enemy_count(ctx, range)` for the range-parameterized enemy count, if ≥2 classes
share the exact expression. Verify before adding (principle #1).

**Verification:** alloc-free (boolean/number assignment into the existing ctx table). Confirm
`is_moving`-gated behavior (e.g. mage Scorch-while-moving logic, paladin movement gates) is unchanged.
`pnpm --filter @menagerie/tbc-rotation build`.

---

## Part B — Registry-owned per-frame cache reset (Med risk — gate behind safe wins)

**Problem.** 26 hand-written `ctx._<spec>_valid = false` resets live in `class.lua` `extend_context`,
decoupled from the playstyle files that own the flags. Forget one when adding a playstyle → the
short-circuit cache never clears → stale state served every frame. Counts:
druid 3, mage 3, paladin 3, priest 4, rogue 3, shaman 3, warlock 3, warrior 4.

**Design — epoch counter (deletes the whole bug class):**
- `create_context` (in `main.lua`) bumps a per-frame `ctx._epoch` (or a module-level `frame_epoch`)
  **once per frame**.
- Each cached lookup compares the stored epoch to the current epoch instead of reading a boolean:
  ```lua
  -- before: if not ctx._fire_valid then ...compute...; ctx._fire_valid = true end
  -- after:  if ctx._fire_epoch ~= frame_epoch then ...compute...; ctx._fire_epoch = frame_epoch end
  ```
- No class ever writes a reset again — a new playstyle's cache is automatically stale each frame
  because its stored epoch lags.

**Migration is mechanical but wide:** touch every cached-state getter across all 8 classes (the
`get_<spec>_state` functions that today read/write `_<spec>_valid`). The 26 `= false` reset lines in
the `extend_context` bodies are **deleted**.

**Hot-path constraints (must hold):**
- **Alloc-free:** epoch is a number compare + number store — no new tables/strings. Confirm no
  inadvertent allocation in the rewritten getters.
- **No cross-frame cache reliance:** the current `_valid` scheme is explicitly per-frame (reset at the
  top of each frame). Before switching, **audit every playstyle** to confirm none relies on the cache
  persisting across frames (e.g. a value computed once and intentionally reused next frame). If any
  does, that flag stays bespoke — the epoch reset is for the per-frame caches only.
- **Epoch wraparound:** use a monotonically increasing integer; Lua 5.1 numbers are doubles, so
  practical wraparound is a non-issue, but initialize stored epochs to a sentinel (`-1` / `nil`) so the
  first frame always computes.

**Verification (behavior-sensitive — do not skip):**
1. Run every available sim path (`pnpm --filter @menagerie/tbc-rotation sim:*`) and diff the decision
   trace against pre-change — must be identical.
2. For classes without a sim, dummy-test each spec's core rotation for one minute; confirm no stale
   state (e.g. a seal/aura/proc flag that "sticks" a frame too long).
3. Instrument a temporary per-frame alloc counter during a fight; confirm zero growth attributable to
   the context path.

**Ship discipline:** one commit for Part A, a **separate** commit per class (or small group) for Part
B so a regression bisects to a single class. Do not convert all 8 classes in one commit.

---

## Open question carried from design §8 Q4

> Is the registry-owned epoch reset worth the hot-path risk now, or defer behind the safe wins?

**Recommendation:** ship Part A now (trivial). Defer Part B until WS-1/WS-4/WS-5/WS-6/WS-3 have landed
and stabilized — it's the single most behavior-sensitive change in the whole hardening effort and
deserves its own focused PR with full sim verification, not a bundled one.
