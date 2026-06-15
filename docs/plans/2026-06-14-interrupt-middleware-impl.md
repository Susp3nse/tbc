# Impl Plan — `register_interrupt_middleware` factory (platform audit #8)

**Status:** Completed (2026-06-14) — landed on `rebrand/menagerie`.

> Date: 2026-06-14. Execute-ready plan for ranked-action item **#8** in
> `docs/plans/2026-06-14-platform-audit/00-summary.md` (flagged by dup #4 + ergo #5).
> Not blocked by the theme/rebrand work (that touches Hunter panels, #12). Do this when ready
> to resume platform-hardening — ideally after the quick wins (#1–#3) but it is independent.

## Goal

Collapse the 4 byte-similar "interrupt the current cast" middleware blocks (mage/rogue/priest/
paladin) onto a single shared factory in `core.lua`, mirroring `register_recovery_middleware`
(core.lua:1018) and `register_trinket_middleware` (core.lua:1185). Warrior + shaman stay bespoke
(opt-out by not calling it).

**Net:** ~80 lines of duplicated middleware → 4 single-call registrations + a ~40-line factory.
Single source of truth for the `IsCastingRemains` + `notKickAble` 5-return contract.

## Verified variance (the only things that differ across the 4)

| Class | `name` | `spell` | `setting_key` | `priority` | `label` | extra gate |
|---|---|---|---|---|---|---|
| mage | `Mage_Counterspell` | `A.Counterspell` | `use_counterspell` | `Priority.MIDDLEWARE.DISPEL_CURSE` (350) | `Counterspell` | — |
| rogue | `Rogue_Kick` | `A.Kick` | `use_kick` | `350` (literal) | `Kick` | energy `>= Constants.ENERGY.KICK` |
| priest | `Priest_Silence` | `A.Silence` | `shadow_use_silence` | `Priority.MIDDLEWARE.DISPEL_CURSE` (350) | `Silence` | `is_spell_available(A.Silence)` (talent-gated) |
| paladin | `Paladin_HammerOfJustice` | `A.HammerOfJustice` | `use_hammer_of_justice` | `150` (literal) | `Hammer of Justice` | — |

Current source blocks: `mage/middleware.lua:104-124`, `rogue/middleware.lua:105-126`,
`priest/middleware.lua:108-128`, `paladin/middleware.lua:158-178`.

Two real wrinkles to parameterize: **rogue's energy gate** and **priest's `is_spell_available`**.
`is_spell_available` is already shared (`NS.is_spell_available`, core.lua:448).

## Step 1 — add the factory to `core.lua`

Place next to the other middleware factories (after `register_trinket_middleware`, ~line 1262).

```lua
-- ============================================================================
-- INTERRUPT MIDDLEWARE FACTORY
-- ============================================================================
-- Emits the canonical "interrupt the current cast" middleware: if the target is
-- casting something kickable (IsCastingRemains, notKickAble == false) and the
-- interrupt is ready, fire it. Covers the simple 4 (mage/rogue/priest/paladin).
-- Warrior/shaman are bespoke (stance-dance, nameplate-seek, reflection) — they
-- simply do not call this.
--
-- opts:
--   name             (string)  middleware name, e.g. "Mage_Counterspell"
--   spell            (Action)  the interrupt, e.g. A.Counterspell  [required]
--   setting_key      (string)  enable toggle, e.g. "use_counterspell"
--   priority         (number)  defaults to Priority.MIDDLEWARE.DISPEL_CURSE
--   label            (string)  log label; defaults to name
--   resource_gate    (fn(context) -> bool)  optional; true = allowed (rogue energy)
--   require_available(bool)    optional; also gate on is_spell_available (priest talent)
local function register_interrupt_middleware(opts)
   opts = opts or {}
   if not NS.A then
      print("|cFFFF6600[Menagerie Interrupt]|r Factory skipped: NS.A not available")
      return
   end
   local spell = opts.spell
   if not spell then
      print("|cFFFF6600[Menagerie Interrupt]|r Skipped: no spell for " .. tostring(opts.name))
      return
   end

   local setting_key       = opts.setting_key
   local priority          = opts.priority or Priority.MIDDLEWARE.DISPEL_CURSE
   local log_format        = "[MW] " .. (opts.label or opts.name) .. " - Cast: %.1fs"
   local resource_gate     = opts.resource_gate
   local require_available = opts.require_available

   rotation_registry:register_middleware({
      name = opts.name,
      priority = priority,

      matches = function(context)
         if not context.in_combat then return false end
         if setting_key and not context.settings[setting_key] then return false end
         if not context.has_valid_enemy_target then return false end
         if resource_gate and not resource_gate(context) then return false end
         return true
      end,

      execute = function(icon, context)
         local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
         if castLeft and castLeft > 0 and not notKickAble then
            if (not require_available or is_spell_available(spell)) and spell:IsReady(TARGET_UNIT) then
               return spell:Show(icon), format(log_format, castLeft)
            end
         end
         return nil
      end,
   })
end
NS.register_interrupt_middleware = register_interrupt_middleware
```

Rule compliance: captures only the **Action handle** (stable across runtime) and reads the toggle
through `context.settings[setting_key]` inside `matches` — never captures a setting at load. Matches
the recovery factory's own pattern of capturing `actions`/handles at registration.

## Step 2 — migrate the 4 call sites

Replace each inline block with one call. Factory is called from `middleware.lua` (loads after
`class.lua` sets `NS.A`), same slot as the existing recovery/trinket factory calls.

**mage/middleware.lua** (replace 104-124):
```lua
NS.register_interrupt_middleware({
   name = "Mage_Counterspell", spell = A.Counterspell,
   setting_key = "use_counterspell", priority = Priority.MIDDLEWARE.DISPEL_CURSE,
   label = "Counterspell",
})
```

**rogue/middleware.lua** (replace 105-126):
```lua
NS.register_interrupt_middleware({
   name = "Rogue_Kick", spell = A.Kick,
   setting_key = "use_kick", priority = 350, label = "Kick",
   resource_gate = function(context) return context.energy >= Constants.ENERGY.KICK end,
})
```

**priest/middleware.lua** (replace 108-128):
```lua
NS.register_interrupt_middleware({
   name = "Priest_Silence", spell = A.Silence,
   setting_key = "shadow_use_silence", priority = Priority.MIDDLEWARE.DISPEL_CURSE,
   label = "Silence", require_available = true,
})
```

**paladin/middleware.lua** (replace 158-178):
```lua
NS.register_interrupt_middleware({
   name = "Paladin_HammerOfJustice", spell = A.HammerOfJustice,
   setting_key = "use_hammer_of_justice", priority = 150, label = "Hammer of Justice",
})
```

Confirm each file's local aliases exist before use: `Priority` (priest/mage), `Constants` (rogue),
`A`, `Unit` — all are already aliased at the top of these middleware files (they used the same
handles in the inline blocks). No new aliases needed.

## Step 3 — verify

1. `corepack pnpm --filter @menagerie/tbc-rotation build` — must succeed (output compiles).
2. `corepack pnpm lint:lua` — no new luacheck warnings (unused locals if a block was removed
   incompletely, typo'd globals).
3. In-game smoke (no sim coverage for these — sim is hunter-centric):
   - Each of mage/rogue/priest/paladin: enable the interrupt toggle, let a caster mob cast,
     confirm the interrupt fires and the debug log line reads exactly `[MW] <label> - Cast: N.Ns`.
   - Rogue: confirm it holds when energy < kick cost.
   - Priest: confirm it stays silent (pun intended) when Silence is untalented.
   - Toggle off → confirms `setting_key` gate.

## Risks / non-goals

- **Behavioral risk is confined to the two wrinkles** (energy gate, talent availability), both
  explicitly parameterized — no silent regression path. Preserve the exact log labels (paladin's
  has spaces) via `label`.
- **`setting_key`-absent branch is dead today.** The `if setting_key and ...` guard means an
  always-on interrupt (no toggle) is supported but unexercised — all 4 callers pass a `setting_key`.
  Keep it as a defensive default; don't assume it's tested.
- **Do NOT touch warrior/shaman** — their interrupts are genuinely complex (stance-dancing, PvP CC
  fallback chains, nameplate priority-seek, Spell Reflection scanners). Opt-out by omission.
- **Optional follow-up, not in scope here:** the read-only `NS.target_is_interruptible(unit)` helper
  (dup #4 "minimal" option) that warrior/shaman could also adopt internally. Defer — the factory
  above is the higher-payoff half and stands alone.

## Done when

Factory in core.lua, 4 classes migrated, build + lint green, in-game smoke confirms all 4 interrupts
fire with identical behavior and log output to today.
