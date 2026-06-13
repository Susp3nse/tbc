# Paladin AIO

Contributor notes for the Paladin rotation modules.

## Registration

- Class: `Paladin`
- Version marker: `v1.12.0`
- Registered playstyles: `retribution`, `protection`, `holy`
- Idle playstyle: none
- Primary resource: mana

## Playstyles

| Playstyle     | Module            | Role                                                                  |
| ------------- | ----------------- | --------------------------------------------------------------------- |
| `retribution` | `retribution.lua` | Ret DPS, seal logic, Judgement, Crusader Strike, and execute tools.   |
| `protection`  | `protection.lua`  | Tanking, Consecration, Holy Shield, Righteous Fury, and threat tools. |
| `holy`        | `holy.lua`        | Holy healing behavior with support damage and utility.                |

## Module Map

- `schema.lua`: Paladin settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, faction-aware seal actions, class registration, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide blessings, defensives, cooldowns, dispels, taunts, and shared pre-rotation behavior.
- `healing.lua`: shared Paladin healing helpers used by Holy and support behavior.
- `retribution.lua`, `protection.lua`, `holy.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Retribution`, `Protection`, `Holy`, and `CDs & Mana` tabs. Keep seal, blessing, and cooldown settings runtime-driven from `context.settings`.

## Change Checklist

- Keep spec priority in the matching playstyle module.
- Put shared blessings, emergency buttons, dispels, and taunts in `middleware.lua`.
- Be careful with faction-specific seal behavior in `class.lua`.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
