# Druid — Rotation Context

Distilled index for the Druid rotation. Assumes you've read the root + `apps/tbc-rotation/AGENTS.md` (framework: Strategy Registry, middleware vs strategies, `register_class`, context object, force-bypass). This file covers only Druid specifics. For depth, see `docs/DRUID_RESEARCH.md`.

## Playstyles

Registered: `caster`, `cat`, `bear`, `balance`, `resto`. Active playstyle is chosen by **stance/form**, not spec:

- `cat` — Cat Form (stance 3). Feral DPS.
- `bear` — Bear/Dire Bear Form (stance 1). Feral tank.
- `balance` — Moonkin Form; disambiguated from Tree by `IsSpellKnown(24858 Moonkin)`.
- `resto` — Tree of Life Form; shares stance slot 5 with Moonkin, disambiguated by `IsSpellKnown(33891 ToL)`.
- `caster` — idle playstyle (stance 0 or Moonkin-with-no-target). Caster-form leveling/fallback + self-buff upkeep.

Moonkin (5) and Tree (5) collide on stance index, so detection uses `IsSpellKnown` on the mutually-exclusive 41pt talents (avoids reading another druid's aura). Bear (1) and Cat (3) are reliable fixed indices.

## Files

- `class.lua` — all spell/item Actions, `Constants`, `register_class`, playstyle detection, `extend_context`, dashboard config, Faerie Fire immunity query (via the shared learned-immunity tracker in `core.lua`), Nordrassil 4pT5 set detection, healing rank tables, gap handler (Feral Charge → Dash).
- `middleware.lua` — `FormReshift`, `RecoveryItems`, `ManaRecovery`, `Barkskin` (cross-form, run before strategies).
- `healing.lua` — shared Druid healing helpers (rank selection) used by resto + self-heal strategies.
- `cat.lua` — 20 Cat strategies + energy-tick tracker.
- `bear.lua` — 15 Bear strategies + rage-cost constants + Maul swing-queue logic.
- `balance.lua` — 6 Balance strategies.
- `resto.lua` — 13 Tree-of-Life strategies (+ a tree-reshift helper).
- `caster.lua` — 8 caster-form upkeep/heal strategies.
- `schema.lua` — settings (tabs: General, Cat, Bear, Caster, Balance, Resto).

## Key spell IDs / ranks

Base IDs (max rank auto-selected via `useMaxRank`): Cat — Shred 5221, Rake 1822, Rip 1079, Ferocious Bite 22568, Mangle(Cat) 33876, Tiger's Fury 5217, Prowl 5215, Ravage 6785. Bear — Mangle(Bear) 33878, Maul 6807, Swipe 779, Lacerate 33745, Demoralizing Roar 99, Frenzied Regen 22842, Enrage 5229, Growl 6795. Balance — Starfire 2912 (+ explicit rank-6 `Starfire6` 9876 for the mana-conserving tier, mirroring WoWsims), Wrath 5176, Moonfire 8921, Insect Swarm 5570, Hurricane 16914, Force of Nature 33831. Forms — Cat 768, Bear 9634, Moonkin 24858, Travel 783, Tree 33891.

Healing spells use **downranking tables** (high→low, with healed-amount estimates) in `class.lua`: Healing Touch (13 ranks, base 26979), Regrowth (10 ranks, 26980), Rejuvenation (13 ranks, 26982). Self-cast mirrors exist (`Self*` variants with `Click.unit = "player"`). Multi-rank **debuff/buff ID arrays** (e.g. `RIP_DEBUFF_IDS`, `MANGLE_DEBUFF_IDS`, `FAERIE_FIRE_DEBUFF_IDS`, `MOTW_BUFF_IDS`) are pre-built for `HasDeBuffs`/`HasBuffs` tracking across all ranks.

## Rotation theory / priorities

Strategy order is array position (first = highest priority). The priority comments in each `register(...)` call are the source of truth; summary:

**Cat** (`cat.lua`, 20): CriticalEnergyShift (emergency powershift) → Stealth openers (Setup/Ravage/Shred/Mangle) → FaerieFire → Rip (finisher DoT) / RipShift → FerociousBite → Bite/Rake low-energy "tricks" → Mangle debuff + MangleShift → Rake → ClearcastingShred (free OoC proc) → Shred (primary builder) → MangleBuilder (fallback when not behind) → Tiger's Fury → Wolfshead/Early powershift. Core loop = energy-pool + maintain bleeds, spend combo points on Rip (then Bite). **Powershifting** (shift out/in to dump+regenerate energy) is a real TBC mechanic here, gated by Furor (40-energy refund) and Wolfshead Helm bonus.

**Bear** (`bear.lua`, 15): FrenziedRegen (off-GCD emergency heal) → Enrage (off-GCD rage) → Growl / ChallengingRoar (taunts) → BashInterrupt → LacerateUrgent (refresh before fall-off) → TabTarget → FaerieFire → Maul (off-GCD, fires _during_ the GCD via swing queue) → SwipeAoE → Mangle (main ST threat) → DemoRoarAoE → LacerateBuild → Swipe → DemoRoar. Threat + mitigation; Maul is queued off-GCD so it overlaps the GCD spender.

**Balance** (`balance.lua`, 6): FaerieFire → ForceOfNature → Innervate → AoE (Hurricane, 3+ targets) → Opener → DPS. DPS core = Moonfire/Insect Swarm DoT upkeep + Starfire (Nature's Grace crit→cast-speed), with mana tiers (`Constants.BALANCE.MANA_TIER*`) that downrank Starfire when conserving. The Nordrassil 4pT5 check force-enables Insect Swarm while mana-conserving.

**Resto** (`resto.lua`, 13): Emergency Swiftmend → Emergency NS+HealingTouch → NS+Regrowth fallback → Emergency Barkskin → LifebloomTank (roll a 3-stack on the tank — core mechanic) → SwiftmendUrgent → RejuvTank (keep Rejuv up so Swiftmend has a HoT to consume) → RegrowthTank → RegrowthLow → RejuvSpread (HoT blanket) → DispelCurse → DispelPoison → Tranquility. Operates in Tree of Life; the NS+HealingTouch emergency briefly leaves and re-shifts Tree.

**Caster** (`caster.lua`, 8): EmergencyHeal → ProactiveHeal → RemoveCurse → AbolishPoison → Innervate → MarkOfTheWild → Thorns → OmenOfClarity. Idle upkeep + survival when not in a combat form.

## Class-specific context extensions

`extend_context` adds: `stance` (`Player:GetStance()`), `is_stealthed`, `energy`, `cp` (combo points), `rage`, `has_clearcasting`, `enemy_count` (units within 8yd), and `is_behind`.

`is_behind` has two modes: target-focus proxy (`use_target_focus_behind` → `not UnitIsUnit("targettarget","player")`) or a **debounced positional check** — a 5-frame ring buffer requiring 4-of-5 false reads before flipping to "not behind." Rationale: `IsBehind()` flickers (~50–200ms client/server lag) on bosses with rotations/knockbacks; a failed Shred is free (errors, no GCD, no energy), so biasing toward "behind = true" avoids wasting a paid Mangle. Don't "simplify" this away.

## Gotchas

- **Stance disambiguation:** Moonkin and Tree both report stance 5 — never branch on stance index alone for those two; use `IsSpellKnown`.
- **Faerie Fire immunity:** FF immunity is spell-specific (an armor-debuff immunity), so it's tracked by spellID via the shared learned-immunity tracker in `core.lua` — `is_spell_immune(TARGET_UNIT, FAERIE_FIRE_SPELL_IDS)`. The CLEU learning/recording lives in `core.lua` (keyed by npcID, TTL = `immune_learn_ttl_min` setting); the druid only queries it. Don't re-add a per-class GUID tracker here.
- **Form-aware consumables:** items used in Cat/Bear must be wrapped in shift macros (`HealthstoneMasterCat`, `...Bear`, sapper-shift sequences) — you can't `/use` a potion mid-form without shifting.
- **Powershift energy math** lives in `Constants.POWERSHIFT` (Furor 40, Wolfshead +20); secure-combat rules mean these thresholds are pre-allocated constants, not inline tables.
- `dashboard.secondary_resource` is per-playstyle (Cat=energy, Bear=rage); combo points show only for Cat.

## See also

- Framework / registry / `register_class` contract: `../../AGENTS.md`
- Full research (spell tables, rotation theory, TBC mechanic notes, "mechanics that do NOT exist in TBC"): `docs/DRUID_RESEARCH.md`
