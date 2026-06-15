# Shared Racial / Auto-Attack Action Factories — Implementation Plan

> **Type:** Implementation (concrete file edits to `core.lua` + 9 `class.lua`).
> **Status:** Not started (drafted 2026-06-15). **Risk:** Low-medium — touches every class, and
> collapses several divergent racial spell IDs to one source of truth (see §ID table; IDs need a
> human sign-off before merge).
> **Ships as:** one PR, ideally split into two commits (racials, then auto-attacks).
> **Meta-engine note:** this is V1 groundwork, not the meta engine. The point is to make every class
> expose racials / auto-attacks through the *same declarative factory* so a future one-button engine
> can enumerate `A.*` actions without per-class knowledge. Spec rotation spells stay per-class.

## Goal

Mirror the existing `register_consumable_actions(A)` pattern (`core.lua:1288–1315`) for the two
remaining cross-class action families that are currently hand-duplicated in all 9 `class.lua` files:

1. **Racials** — `BloodFury`, `Berserking`, `WarStomp`, `Stoneform`, `ArcaneTorrent`, `Shadowmeld`,
   `Perception`, `WilloftheForsaken`, `EscapeArtist`, `GiftOfTheNaaru`.
2. **Auto-attack toggle** — the `6603` melee swing toggle (`StartAttack`).

Outcome: each class drops its racial block and calls `NS.register_racial_actions(A, opts)`; the
factory owns the canonical IDs and the standard `Click = { unit="player", type="spell", spell=id }`
spec. This removes ~50 duplicated lines and kills the ID drift documented below.

---

## Why now: the duplication is already buggy

The same racial is defined with **different spell IDs** across classes. Some divergence is
legitimate (resource-/power-dependent), some looks like a plain copy/paste bug:

| Racial | IDs currently in tree | Assessment |
| --- | --- | --- |
| **Berserking** (troll) | hunter `20554`, warrior `26296`, mage/priest/rogue/shaman/druid `26297` | ⚠️ **Likely bug** — pick one canonical ID. |
| **Blood Fury** (orc) | most `20572` (AP), druid `33697` (SP), warlock `33702`, shaman splits `BloodFuryAP=20572`/`BloodFurySP=33697` | ⚠️ **Half-intentional** — AP vs SP is real; only shaman models it. Factory should resolve by `opts.power`. |
| **Arcane Torrent** (blood elf) | `28730` (mana), rogue `25046` (energy) | ✅ Legit — resolve by `opts.resource`. |
| **Stoneform** (dwarf) | `20594` | ✅ consistent |
| **War Stomp** (tauren) | `20549` | ✅ consistent |
| **Shadowmeld** (night elf) | `20580` | ✅ |
| **Perception** (human) | `20600` (hunter adds `FixedTexture = CONST.HUMAN`) | ✅ — see edge case below |
| **Will of the Forsaken** (undead) | `7744` | ✅ |
| **Escape Artist** (gnome) | `20589` | ✅ |
| **Gift of the Naaru** (draenei) | `28880` | ✅ — heal-over-time, off-GCD, self-cast for now |

**These IDs are my best read of the current tree, NOT verified against a TBC spell DB.** Per your
note: review the canonical column before merge and correct any I got wrong — the whole point of
centralizing is that there's then exactly one line to fix per racial.

---

## Step 1 — `NS.register_racial_actions(A, opts)` in `core.lua`

**File:** `apps/tbc-rotation/src/aio/core.lua` (next to `register_consumable_actions`, ~line 1288).

Add a canonical table + factory, structurally identical to `CONSUMABLE_ACTIONS` /
`register_consumable_actions`:

```lua
-- One source of truth for racial spell IDs. Created unconditionally per class
-- (same as consumables) — IsReady()/IsExists() gate at runtime, so a dwarf simply
-- never sees Berserking fire.
--   Blood Fury  -> ALWAYS create both BloodFuryAP (20572) + BloodFurySP (33697),
--                  because different specs reference each by name (see §handle audit);
--                  BloodFury is a default alias selected by opts.power ("AP" | "SP").
--   ArcaneTorrent -> opts.resource ("MANA" default | "ENERGY"); MANA + ENERGY covers
--                    every blood-elf-capable class (rogue is the only ENERGY one).
local RACIAL_ACTIONS = {
   { "Berserking",        26297 },
   { "WarStomp",          20549 },
   { "Stoneform",         20594 },
   { "Shadowmeld",        20580 },
   { "Perception",        20600 },
   { "WilloftheForsaken", 7744  },
   { "EscapeArtist",      20589 },
   { "GiftOfTheNaaru",    28880 },
}
local BLOODFURY_AP, BLOODFURY_SP = 20572, 33697
local ARCANE_TORRENT_BY_RES = { MANA = 28730, ENERGY = 25046 }

local function racial(Create, id)
   return Create({ Type = "Spell", ID = id,
      Click = { unit = "player", type = "spell", spell = id } })
end

local function register_racial_actions(A_class, opts)
   if not A_class or not A_class.Create then return end
   opts = opts or {}
   local Create = A_class.Create

   for i = 1, #RACIAL_ACTIONS do
      A_class[RACIAL_ACTIONS[i][1]] = racial(Create, RACIAL_ACTIONS[i][2])
   end

   -- Blood Fury: both named handles always; plain alias picks the spec's default.
   A_class.BloodFuryAP = racial(Create, BLOODFURY_AP)
   A_class.BloodFurySP = racial(Create, BLOODFURY_SP)
   A_class.BloodFury   = (opts.power == "SP") and A_class.BloodFurySP or A_class.BloodFuryAP

   A_class.ArcaneTorrent = racial(Create, ARCANE_TORRENT_BY_RES[opts.resource or "MANA"])
end

NS.register_racial_actions = register_racial_actions
```

**Handle audit (why Blood Fury must expose both):** verified references in the tree —
`A.BloodFurySP` (`shaman/restoration.lua:363`, `shaman/elemental.lua:103`), `A.BloodFuryAP`
(`shaman/enhancement.lua:420`), and plain `A.BloodFury` (`hunter/rotation.lua:467`,
`warlock/{destruction,affliction,demonology}.lua`). Always creating `BloodFuryAP`/`BloodFurySP` plus
the `BloodFury` alias means **no strategy-list edits in any class, including shaman.**

**Decisions baked in (call them out / override if wrong):**
- **Create all racials regardless of the player's actual race**, exactly like consumables. Avoids a
  `UnitRace` branch and matches the existing pattern; runtime `IsReady` gates firing. The downside is
  a few never-ready `A.*` handles per character — acceptable and already true for consumables.
- **Shaman migrates cleanly now** — it just uses the factory's `BloodFuryAP`/`BloodFurySP` names. Its
  explicit block in `shaman/class.lua:27–30` is deleted like every other class. (This is the
  correction from draft v1, which wrongly suggested shaman might stay bespoke.)
- **`opts.resource` / `opts.power`** carry the only legitimate per-class differences; defaults
  (`MANA`, `AP`) cover the common case.

---

## Step 2 — Migrate each `class.lua`

For each of the 9 classes: delete the hand-written racial `Create` block and replace with one call,
placed where `register_consumable_actions(A)` is already called (so ordering/`A` availability is
already proven correct):

```lua
NS.register_racial_actions(A, { power = "AP" })                       -- melee specs
NS.register_racial_actions(A, { power = "SP" })                       -- caster specs
NS.register_racial_actions(A, { power = "AP", resource = "ENERGY" })  -- rogue
```

Suggested `power`/`resource` per class (verify against how each spec actually uses Blood Fury):

| Class | power | resource | Notes |
| --- | --- | --- | --- |
| warrior | AP | MANA | |
| rogue | AP | ENERGY | Arcane Torrent = energy variant |
| hunter | AP | MANA | |
| paladin | AP | MANA | (ret AP; holy/prot rarely fire BF) |
| druid | AP | MANA | **racials are dead today — see finding below.** Pick AP (cat) for the `BloodFury` alias; feral is the only spec likely to fire it. |
| shaman | — | MANA | uses `BloodFuryAP`/`BloodFurySP` names directly; alias irrelevant |
| priest | SP | MANA | |
| mage | SP | MANA | |
| warlock | SP | MANA | currently `33702` — replaced by canonical `33697` (verify) |

**Finding — druid racials are currently dead code (decide before/while migrating):**
`druid/class.lua:202–204` defines `Berserking`/`BloodFury` with **no `Click` table**, and nothing in
the druid tree dispatches them — there is no `create_racial_strategy` call and the `use_racial`
schema checkbox (`druid/schema.lua:57`) has **zero consumers**. So today druid racials neither arm a
keybind nor fire. Migrating druid to the factory makes the handles *correct* (and gives them a
`Click`), but they still won't fire without a racial strategy. **Two options:**
- **(a) Scope-clean:** migrate druid like everyone else (handles become correct), and note that
  wiring an actual druid racial strategy is a separate follow-up. *Recommended* — keeps this PR a
  pure refactor.
- **(b) Bundle the fix:** also add a `DRUID_RACIAL_SPELLS` + `create_racial_strategy` so the existing
  `use_racial` checkbox finally does something. This is new behavior, not a refactor — only if you
  want it in the same PR.

**Edge cases to preserve, not drop:**
- **`FixedTexture = CONST.HUMAN` on hunter's Perception** — minor cosmetic. Either drop it (simplest)
  or add an optional `fixed_texture` field to the racial table. Recommend **drop** unless it's load-
  bearing for the icon display; flag in PR.
- Any racial referenced by a spec's `RACIAL_SPELLS` strategy list (e.g. `{ A.BloodFury, "Blood Fury" }`
  in `warlock/destruction.lua:210`, `mage/fire.lua:99`) keeps working unchanged — the handle name is
  identical, only its definition moved. **No strategy-layer edits needed.** Grep to confirm:
  `grep -rn "A\.\(BloodFury\|Berserking\|ArcaneTorrent\|WarStomp\|Stoneform\)" src/aio` — every hit
  should still resolve.

---

## Step 3 — Auto-attack / auto-shoot (smaller, scoped deliberately)

This family is **not** uniform across all classes, so resist forcing it into one factory:

- **Melee swing toggle (`6603`)** — genuinely shared (warrior, shaman, hunter's `StartAttack`). Add a
  small `NS.register_autoattack_action(A, opts)` that creates a base `StartAttack` =
  `Create({ Type="Spell", ID=6603, Click={ autounit="harm", type="spell", spell=6603,
  macrobefore="/stopcasting\n/startattack\n" } })`, with `opts.macrobefore`/`opts.macroafter`
  overridable.
- **Hunter ranged auto-shots** (`ShootBow 2480` / `ShootCrossbow 7919` / `ShootGun 7918` /
  `Throw 2764`) — **hunter-only.** Optionally `NS.register_autoshot_actions(A)` for uniform creation,
  but flag that it's a single-consumer factory (mild YAGNI). Fine to leave in `hunter/class.lua` for
  V1 and only lift it if a second ranged user appears.
- **Shaman `SwingResync`** (`6603` with the bespoke `/cleartarget`/`/targetlasttarget`/`/run` macro)
  is **not** a plain auto-attack — leave it bespoke in `shaman/class.lua`. Do not fold it into the
  shared factory.

**Recommendation:** ship Step 3's melee `register_autoattack_action` only if ≥2 classes will actually
adopt it this pass; otherwise defer Step 3 entirely and land Steps 1–2 alone. The racial factory is
where the duplication and the bugs are — that's the high-value change.

---

## Verification

- `pnpm --filter @menagerie/tbc-rotation build` succeeds (output compiles).
- `pnpm lint:lua` clean (catches a fat-fingered racial handle name / accidental global).
- For one melee + one caster class in-game: `/menagerie burst` fires the correct racial; the icon
  arms the keybind (cast actually lands), confirming the `Click` spec survived the move.
- Grep check from Step 2 shows every `A.<Racial>` strategy reference still resolves.
- Spot-check that a non-Orc character no longer errors and simply never fires Blood Fury.

## Open questions for you

1. **Canonical IDs** — confirm/correct the ID table, especially Berserking (`26297`?) and warlock
   Blood Fury (today `33702`; the factory makes warlock's plain `A.BloodFury` alias = `33697` (SP) via
   `power="SP"`). Confirm `33697` is the intended warlock value.
2. **Druid racials** — option (a) scope-clean migrate (handles correct, firing deferred), or (b) also
   wire the missing racial strategy so the dormant `use_racial` checkbox works? (See Step 2 finding.)
3. **Step 3 scope** — land the melee auto-attack factory now, or defer and ship racials only?
