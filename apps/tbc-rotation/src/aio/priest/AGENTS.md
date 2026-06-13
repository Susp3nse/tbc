# Priest — Rotation Context

Distilled index for the Priest rotation. Assumes you've read root + `apps/tbc-rotation/AGENTS.md` (framework). Priest specifics only; depth in `docs/PRIEST_RESEARCH.md`.

## Playstyles

Registered: `shadow`, `smite`, `holy`, **`discipline`** (four — the disc healing playstyle is separate from holy; note the framework summary tables sometimes list only shadow/smite/holy). Chosen by **setting**: `get_active_playstyle` returns `context.settings.playstyle or "shadow"`. No idle playstyle.

- `shadow` — Shadowform DPS (DoTs + Mind Blast/Flay).
- `smite` — caster DPS without Shadowform (Smite/Holy Fire), keeps SW:P for Shadow Weaving/Misery.
- `holy` — raid healing (PoM, CoH, Renew, Greater/Flash Heal).
- `discipline` — shield-focused healing (PW:S, Pain Suppression, Power Infusion).

## Files

- `class.lua` — spell Actions, `Constants` (BUFF_ID / DEBUFF_ID / Inner Fire + buff-ID arrays), `register_class`, `extend_context`, dashboard config.
- `middleware.lua` — defensive + sustain + self-buff stack: `Priest_DesperatePrayer`, `Fade`, `Silence`, `DispelMagic`, `AbolishDisease`, `Healthstone`, `HealingPotion`, `Shadowfiend`, `ManaPotion`, `DarkRune`, and self-buffs (`InnerFire`, `Fortitude`, `DivineSpirit`, `ShadowProt`, `FearWard`).
- `healing.lua` — shared heal-rank selection + roster helpers used by holy + discipline.
- `shadow.lua` — 13 Shadow strategies + context builder.
- `smite.lua` — 11 Smite strategies.
- `holy.lua` — 17 Holy strategies (heal roster + idle DPS fillers).
- `discipline.lua` — 14 Discipline strategies.
- `schema.lua` — settings (includes `playstyle` selector + per-spec HP thresholds and toggles).

## Key spell IDs / ranks

Shadow: Shadow Word: Pain 589, Mind Blast 8092, Mind Flay 15407, Vampiric Touch 34914, Shadow Word: Death 32379, Shadowform 15473, Vampiric Embrace 15286, Silence 15487, Devouring Plague 2944 (Undead racial), Shadowfiend 34433. Smite: Smite 585, Holy Fire 14914. Heals: Flash Heal 2061, Greater Heal 2060, Renew 139, Prayer of Healing 596, Power Word: Shield 17, Prayer of Mending 33076, Circle of Healing 34861, Binding Heal 32546. CDs: Inner Focus 14751, Power Infusion 10060, Pain Suppression 33206.

Tracked auras: Shadowform, Inner Focus, Power Infusion, Surge of Light, Holy Concentration (clearcasting), Inner Fire; debuffs SW:P, Vampiric Touch, Shadow Weaving (stacks), Holy Fire DoT, Devouring Plague.

## Rotation theory / priorities

Strategy order = array position. Summary per playstyle:

**Shadow** (13): EnsureShadowform → PreCombatPull (open with VT/MB) → AoE spreads (SWP/VT/VE) → ShadowWordPain → VampiricTouch → ShadowWordDeath → InnerFocus → MindBlast → DevouringPlague → VampiricEmbrace → MindFlay (filler). Core = maintain SW:P + VT DoTs, weave Mind Blast on CD, Mind Flay as filler; Shadowform is enforced first.

**Smite** (11): ShadowWordPain (for Shadow Weaving/Misery) → Starshards → DevouringPlague → MindBlast → ShadowWordDeath → SurgeOfLightSmite (free instant Smite proc) → HolyFireWeave → HolyFire → InnerFocus → Racial → SmiteFiller. Smite-spam with Holy Fire weave; SW:P kept up for the spell-hit debuff.

**Holy** (17): EmergencyPWS → EmergencyFlashHeal → PrayerOfMending → CircleOfHealing → BindingHeal → ClearcastingGreaterHeal → RenewTank → RenewSpread → InnerFocus → GreaterHeal → FlashHeal → PrayerOfHealing → Racial → SurgeOfLightSmite → **Idle fillers (SWP / HolyFire / Smite)** — when nobody needs healing, do DPS. Heal targets come from a roster (`state.lowest`, `state.tank`), not just the current target.

**Discipline** (14): PainSuppression (off-GCD, tank emergency) → EmergencyFlashHeal → BindingHeal → ShieldTank → PrayerOfMending → InnerFocusGreaterHeal → PowerInfusion → Racial → ShieldOthers → RenewTank → GreaterHeal → FlashHeal → RenewSpread → PrayerOfHealing. Shield-centric; PW:S respects Weakened Soul.

## Class-specific context extensions

`extend_context` adds: `is_moving`, `is_mounted`, `combat_time`, `in_shadowform`, `has_inner_focus`, `has_power_infusion`, `has_surge_of_light`, `has_clearcasting` (Holy Concentration), `has_inner_fire`, `enemy_count` (30yd), and `has_valid_enemy_target`. The healing playstyles additionally build a **roster** in their context builders (`state.lowest`, `state.tank`, `effective_hp`, `has_weakened_soul`) — heals target roster members, not `context.target`.

## Gotchas

- **Four playstyles, not three** — `discipline` is a distinct registered healing spec. Don't assume holy is the only healer.
- **PW:S + Weakened Soul:** shield strategies must check `has_weakened_soul` before casting (re-shielding through the debuff does nothing). Emergency PW:S in Holy explicitly skips weakened-soul targets.
- **Surge of Light** gives a free instant Smite/Flash Heal proc; both smite and holy/disc have a `SurgeOfLight*` strategy to consume it — track `has_surge_of_light`.
- **Heal roster, not target:** holy/disc decisions read `state.lowest`/`state.tank` (the party/raid roster), so changing them to use `context.target` would break group healing.
- **Idle DPS in Holy:** when no heal is needed, Holy falls through to SWP/Holy Fire/Smite fillers — intentional, keeps the priest contributing damage.
- **Spec is a setting** (like Mage/Paladin) — mismatched `playstyle` flags missing spells but won't auto-correct.

## See also

- Framework / registry: `../../AGENTS.md`
- Full research (per-spec rotations, healing models, DoT/Shadow Weaving theory, TBC mechanic notes): `docs/PRIEST_RESEARCH.md`
