# Warrior — Rotation Context

> Assumes you've read the root `AGENTS.md` (behavior) and `apps/tbc-rotation/AGENTS.md` (Strategy Registry, middleware vs strategies, context object, force-bypass, dashboard). This doc covers only Warrior specifics.

Rage class with **three stances** that gate most abilities. Registered as `Warrior` (`version = "v1.9.2"`). The largest middleware file in the addon (~67 KB — stances, defensives, PvP toolkit). No idle playstyle — `get_active_playstyle` reads `context.settings.playstyle` (default `"fury"`).

## Playstyles

| Playstyle | When active | Preferred stance | Core engine |
|---|---|---|---|
| `arms` | settings.playstyle == "arms" | Berserker (3) | 2H Mortal Strike, Slam (sim's #1 filler), Rend, Overpower, Execute |
| `fury` | settings.playstyle == "fury" (default) | Berserker (3) | DW Bloodthirst, Whirlwind, Rampage, Execute, Heroic Strike dump |
| `kebab` | settings.playstyle == "kebab" | Berserker (3) | **Dual-wield Arms** hybrid — MS + WW, OP on procs. Addon-original spec (not in research doc) |
| `protection` | settings.playstyle == "protection" | Defensive (2) | Shield Slam / Revenge, Devastate, Sunder, threat + mitigation toolkit |

`Constants.PREFERRED_STANCE` maps each spec → stance ID; the stance-correction middleware shifts you there.

## Files

- `schema.lua` — settings (largest in the addon): general combat, DPS spec, Prot tank, defensives, PvP tools, Kebab options.
- `class.lua` — actions, `Constants` (STANCE, PREFERRED_STANCE, shout-ID arrays, BUFF_ID), `register_class()`, `extend_context`, `gap_handler`, dashboard.
- `middleware.lua` — stance correction, defensives, interrupt, shouts, Bloodrage, the HS-queue trick, and the full PvP suite (priority-ordered, below).
- `arms.lua` / `fury.lua` / `kebab.lua` / `protection.lua` — per-playstyle strategy arrays.

## Key spell IDs / ranks

Builders/strikes (base→max via `useMaxRank`): Mortal Strike `12294`, Bloodthirst `23881`, Whirlwind `1680` (fixed), Slam `1464`, Overpower `7384`, Execute `5308`, Heroic Strike `78`, Cleave `845`, Rend `772`, Hamstring `1715`, Sunder Armor `7386`, Thunder Clap `6343`.
Prot: Shield Slam `23922`, Revenge `6572`, Devastate `20243`, Shield Block `2565`, Shield Wall `871`, Last Stand `12975`, Spell Reflection `23920`.
Stances: **Battle `2457`, Defensive `71`, Berserker `2458`** (and `Constants.STANCE` = BATTLE 1 / DEFENSIVE 2 / BERSERKER 3 matching `Player:GetStance()`).
CDs: Death Wish `12292`, Recklessness `1719`, Sweeping Strikes `12328`, Bloodrage `2687`, Berserker Rage `18499`, Rampage `29801`.
Shouts: Battle Shout `6673`, Commanding Shout `469`, Demo Shout `1160`. `Constants.BATTLE_SHOUT_IDS` is an **all-rank array** so the rotation detects the buff from any source/rank.
Mobility/utility: Charge `100`, Intercept `20252`, Intervene `3411`, Pummel `6552`, Shield Bash `72`, Disarm `676`, Intimidating Shout `5246`.

## Rotation theory / priorities

Per-spec priority arrays (first = highest):

- **arms**: MaintainRend → SweepingStrikes → **Slam (sim #1 filler, above MS for 2H)** → MortalStrike → Whirlwind → Execute → Overpower (reactive dodge proc, off by default for 2H) → VictoryRush → SunderMaintain → ThunderClap → DemoShout → HeroicStrike.
- **fury**: Rampage → Bloodthirst → SweepingStrikes → Whirlwind → Execute → VictoryRush → SunderMaintain → ThunderClap → DemoShout → Slam → Hamstring → **SwingDesync** → HeroicStrike. SwingDesync deliberately offsets MH/OH for HS-trick timing.
- **kebab** (DW Arms): Execute (highest ST per sim) → SweepingStrikes → **Whirlwind above MS** (more damage per rage when dual-wielding) → MortalStrike → Overpower (Battle Stance only) → VictoryRush → SunderMaintain → ThunderClap → DemoShout → HeroicStrike.
- **protection**: ThreatTab → ShieldBlock → ShieldSlam → Revenge → ThunderClap → DemoShout → HeroicStrike → Devastate → SunderArmor → Execute → VictoryRush → Taunt → ChallengingShout → MockingBlow.

**Heroic Strike / Cleave are off-GCD rage dumps** queued onto the next swing (not a normal cast). The HS-queue trick converts MH+OH to yellow hits; `Warrior_HSQueueDequeue` (priority 999, top of everything) dequeues HS before the MH swing lands if rage is insufficient — only active when dual-wielding with `hs_trick` enabled.

Middleware (priority high→low, abridged): HSQueueDequeue (999) → LastStand (500) → ShieldWall (490) → LoCBreaker (485) → CancelExternalBuff (475) → SpellReflection (400) → Retaliation (265) → RacialDefensive (260) → Disarm (258) → Interrupt (250, Pummel/Shield Bash) → WarStomp (245) → Healthstone/HealingPotion (RECOVERY_ITEMS) → Bloodrage (200) → **StanceCorrection (195)** → PvPDefStanceRange (192) → BerserkerRage (150) → ShoutMaintain (140) → DeathWish (100) → Recklessness (90) → Racial (70) → then the PvP suite (Hamstring 65, PiercingHowl 64, RendStealth 63, Overpower 62, ShieldSlamPurge 61, Intervene 59, …).

`gap_handler` (`/flux gap`): Charge if ready, else Intercept.

## Class-specific context extensions

`extend_context(ctx)` adds: `stance` (`Player:GetStance()`, 1/2/3), `rage`, `is_moving`, `is_mounted`, `combat_time`, `enemy_count` (`MultiUnits:GetByRangeInCombat(8)`).
Threat: `threat_status`, `threat_percent` (for prot threat-lead gating of utility abilities).
PvP: `is_pvp`, `is_arena`, `is_battleground`, `target_is_player`, and `has_breakable_cc_nearby` (gates AoE so WW/Cleave/TC/Demo Shout don't break crowd control — PvP uses `EnemyTeam:IsBreakAble(8)`, PvE uses a local scan).
Buffs: `has_battle_shout`, `has_commanding_shout`, `death_wish_active`, `recklessness_active`, `sweeping_strikes_active`, `berserker_rage_active`, `rampage_active`/`_stacks`/`_duration`, `shield_block_active`, `enrage_active`, `flurry_active`.
Swing timing (for HS trick): `has_offhand`, `oh_start`/`oh_speed`/`oh_remain`, `mh_remain`.

It also **syncs the framework's native AutoTarget toggle with `settings.use_auto_tab`** — when our smart Auto Tab is on, it disables the framework's auto-target (we manage targeting), and re-enables it when ours is off. Per-playstyle cache flags `_arms_valid`/`_fury_valid`/`_kebab_valid`/`_prot_valid` reset to `false` each frame.

## Gotchas

- **Stance-gating is everywhere.** Many abilities only work in specific stances (Overpower/Charge = Battle, Berserker abilities = Berserker, defensive tools = Defensive). `StanceCorrection` (mw priority 195) shifts to `PREFERRED_STANCE`; strategies still check `context.stance`. Changing stance wipes most rage and re-applies a cooldown — don't shift gratuitously.
- **HS/Cleave are queued, not cast** — they ride the next white swing and are off-GCD. The 999-priority dequeue logic and `SwingDesync`/`oh_remain` exist for this; treat the swing-timer fields as load-bearing, not debug cruft.
- **`kebab` is an addon-original spec** — there is no `kebab` section in `docs/WARRIOR_RESEARCH.md`; it derives from the Arms/Fury sim logic (DW Arms). Document changes here, not in the research doc.
- **Stances reported 1/2/3** via `Player:GetStance()` — matches `Constants.STANCE`; `STANCE_NAMES` (Battle/Defensive/Berserker) is for the dashboard.
- Settings runtime-mutable: read via `context.settings.<key>`; per-frame state tables pre-allocated (no `{}` in combat).

## See also

- Framework / registry / context: `../../AGENTS.md` (app), `../../../AGENTS.md` (root behavior)
- Deep dive (sim sources, rage math, HS-trick theory, Deep Wounds, per-spec breakdowns — Arms/Fury/Prot only): `docs/WARRIOR_RESEARCH.md`
