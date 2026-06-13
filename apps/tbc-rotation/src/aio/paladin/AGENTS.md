# Paladin — Rotation Context

Distilled index for the Paladin rotation. Assumes you've read root + `apps/tbc-rotation/AGENTS.md` (framework). Paladin specifics only; depth in `docs/PALADIN_RESEARCH.md`.

## Playstyles

Registered: `retribution`, `protection`, `holy`. Chosen by **setting**, not detection: `get_active_playstyle` returns `context.settings.playstyle or "retribution"`. No idle playstyle.

## Files

- `class.lua` — spell Actions (seals, judgement, strikes, holy spells, defensives), `Constants` (BUFF_ID / DEBUFF_ID / TWIST window), faction-aware seal selection, `register_class`, `extend_context` (seal/swing tracking), dashboard config.
- `middleware.lua` — recovery + defensive stack (Lay on Hands, Divine Shield/Protection, BoP, blessings, potions) run before strategies.
- `healing.lua` — shared FoL/HL rank selection helpers used by Holy + emergency self-heal.
- `retribution.lua` — 13 Ret strategies + `get_ret_state` (seal-twist DPS).
- `protection.lua` — 14 Prot strategies + `get_prot_state` (tank/threat).
- `holy.lua` — 10 Holy strategies + `get_holy_state` (healing).
- `schema.lua` — settings (includes `playstyle` selector, `ret_twist_window`, `use_auto_tab`).

## Key spell IDs / ranks

Seals: Seal of Blood (Horde) / Seal of the Martyr (Alliance) — selected by faction at load; Seal of Command (R1 + max), Seal of Righteousness, Seal of Vengeance. Judgement 20271. Strikes/damage: Crusader Strike 35395, Consecration 26573, Exorcism 879, Hammer of Wrath 24275, Holy Wrath. Prot: Avenger's Shield 31935, Holy Shield 20925, Righteous Defense 31789, Righteous Fury 25780. Holy: Flash of Light 19750, Holy Light 635, Holy Shock 20473, Lay on Hands 633, Cleanse 4987, Divine Favor 20216, Divine Illumination 31842. Cooldowns/defensives: Avenging Wrath 31884, Divine Shield 642, Divine Protection 5573, Blessing of Protection 1022.

Tracked auras: all seals (Blood, Command, Righteousness, Vengeance, Wisdom, Light, Crusader), Forbearance (debuff — blocks Divine Shield/BoP/LoH reuse), Avenging Wrath, Righteous Fury, Light's Grace, Vengeance talent.

## Rotation theory / priorities

**Retribution** (13): AvengingWrath → Racial → Opener → JudgeSeal → CrusaderStrike → **TwistBlood → PrepCommand → MaintainBlood** → HammerOfWrath → Exorcism → Consecration → HolyWrath → MaintainSealFallback. The core is **seal twisting**: keep Seal of Blood/Martyr up, judge it, then twist in Seal of Command before the next melee swing lands so both seals' damage procs on one swing. This is timing-critical — see Gotchas.

**Protection** (14): ThreatTab (pick up loose mobs first) → RighteousFuryCheck → AvengersShield (pull window, must fire early) → AvengingWrath → Racial → EstablishSeal → HolyShield → Consecration → Judgement → RighteousDefense → Exorcism → HolyWrath → HolyShieldFallback → HammerOfWrath. Threat-first: 96969 (Consecration/Holy Shield/Judgement) with Avenger's Shield as the pull.

**Holy** (10): DivineIllumination → DivineFavor (guaranteed crit) → Racial → HolyShockHeal → LayOnHands (emergency) → LightsGraceProc (cast-time reduction window) → HealTarget (FoL/HL rank selection by deficit) → JudgementMaintain (Judgement of Wisdom/Light for mana/healing return) → SealMaintain → Cleanse. Standard FoL-spam healing with HL for big hits and Holy Shock as the instant.

## Class-specific context extensions

`extend_context` adds: `is_moving`, `is_mounted`, `combat_time`; a full **seal state** block (`seal_blood_active`, `seal_command_active`, …, `has_any_seal`); key buffs/debuffs (`forbearance_active`, `avenging_wrath_active`, `righteous_fury_active`); `enemy_count` (8yd); and **swing-twist tracking**: `time_to_swing` + `in_twist_window` (true when `time_to_swing <= ret_twist_window`). It also syncs the framework's native `AutoTarget` toggle with the `use_auto_tab` setting (disables native auto-target when the smart tab is on).

## Gotchas

- **Faction-aware seal:** Ret uses Seal of Blood (Horde) vs Seal of the Martyr (Alliance) — the Action and required-spell list are picked by faction at load. Don't hardcode one.
- **Swing-timer semantics (documented bug):** `Player:GetSwing(slot)` returns the **time remaining** until the next swing, NOT the swing's total duration. `time_to_swing` IS that value directly. A previous `(swing_start + GetSwing) - now` formula treated it as a duration and opened `in_twist_window` ~1.8s too early (near the swing midpoint), causing Seal of Blood to be cast too soon and overwritten before the swing landed (~18 SoB hits vs ~113 in a clean log). Preserve the current direct-remaining reading.
- **Forbearance** locks out Divine Shield / BoP / Lay on Hands reuse; `forbearance_active` gates those so middleware doesn't waste a press.
- **AutoTarget coupling:** `extend_context` actively writes the framework's `AutoTarget` toggle. If you add targeting logic, account for this two-way sync with `use_auto_tab`.
- **Spec is a setting** (like Mage) — mismatched `playstyle` flags missing spells but won't auto-correct.

## See also

- Framework / registry: `../../AGENTS.md`
- Full research (seal-twisting theory, per-spec rotations, healing/threat models, TBC mechanic notes): `docs/PALADIN_RESEARCH.md`
