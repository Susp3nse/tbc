# Shaman AIO

Contributor notes for the Shaman rotation modules.

## Registration

- Class: `Shaman`
- Version marker: `v1.8.1`
- Registered playstyles: `elemental`, `enhancement`, `restoration`
- Idle playstyle: none
- Primary resource: mana

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `elemental` | `elemental.lua` | Elemental caster DPS, shocks, lightning spells, and caster cooldowns. |
| `enhancement` | `enhancement.lua` | Enhancement melee priority, shocks, weapon imbues, and melee cooldowns. |
| `restoration` | `restoration.lua` | Restoration healing behavior. |

## Module Map

- `schema.lua`: Shaman settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, totem context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide totems, shields, weapon imbues, cooldowns, dispels, interrupts, and shared pre-rotation behavior.
- `elemental.lua`, `enhancement.lua`, `restoration.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Elemental`, `Enhancement`, `Restoration`, and `CDs & Mana` tabs. Keep totem, shock, healing, and cooldown controls read from `context.settings` inside strategy logic.

## Change Checklist

- Keep spec priority in the matching playstyle module.
- Put common totem, shield, weapon imbue, interrupt, and cooldown behavior in `middleware.lua`.
- Update `class.lua` context extensions when new strategy logic depends on totem state.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
