# Druid AIO

Contributor notes for the Druid rotation modules.

## Registration

- Class: `Druid`
- Version marker: `v1.10.0 + 3`
- Registered playstyles: `caster`, `cat`, `bear`, `balance`, `resto`
- Idle playstyle: `caster`
- Primary resource: mana, with energy in Cat Form and rage in Bear Form

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `caster` | `caster.lua` | Caster-form leveling and fallback damage. |
| `cat` | `cat.lua` | Cat Form melee damage, combo points, finishers, and form shifting. |
| `bear` | `bear.lua` | Bear Form tanking, rage spenders, taunts, and mitigation. |
| `balance` | `balance.lua` | Moonkin/caster DPS with DoT and mana controls. |
| `resto` | `resto.lua` | Restoration healing behavior. |

## Module Map

- `schema.lua`: Druid settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, active playstyle detection, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide recovery, utility, cooldown, and shared pre-rotation behavior.
- `healing.lua`: shared Druid healing helpers used by restoration and support behavior.
- `caster.lua`, `cat.lua`, `bear.lua`, `balance.lua`, `resto.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Cat`, `Bear`, `Caster`, `Balance`, and `Resto` tabs. Keep setting keys snake_case and read values from `context.settings` inside strategy logic so runtime UI changes are respected.

## Change Checklist

- Keep form-specific logic in the matching playstyle module unless it is reused by multiple specs.
- Put cross-form utility and emergency behavior in `middleware.lua`.
- Update `class.lua` spell requirements when adding a required talent or ability.
- For rotation behavior changes, increment `dev_revision` during development; roll it into `version` only for release.
- Validate with `pnpm build:rotation` after Lua changes.
