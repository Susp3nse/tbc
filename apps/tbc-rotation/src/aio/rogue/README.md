# Rogue AIO

Contributor notes for the Rogue rotation modules.

## Registration

- Class: `Rogue`
- Version marker: `v1.7.0`
- Registered playstyles: `combat`, `assassination`, `subtlety`
- Idle playstyle: none
- Primary resource: energy and combo points

## Playstyles

| Playstyle       | Module              | Role                                                                         |
| --------------- | ------------------- | ---------------------------------------------------------------------------- |
| `combat`        | `combat.lua`        | Combat DPS, Sinister Strike, Slice and Dice, finishers, and major cooldowns. |
| `assassination` | `assassination.lua` | Mutilate-focused DPS, poison finishers, and Assassination cooldowns.         |
| `subtlety`      | `subtlety.lua`      | Hemorrhage-focused DPS, Subtlety utility, and opener support.                |

## Module Map

- `schema.lua`: Rogue settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, active playstyle selection, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide defensives, interrupts, cooldowns, stealth utility, and shared pre-rotation behavior.
- `combat.lua`, `assassination.lua`, `subtlety.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Combat`, `Assassination`, `Subtlety`, and `CDs & Defense` tabs. Keep finisher, energy, and combo-point thresholds runtime-driven from `context.settings`.

## Change Checklist

- Keep builder and finisher priority in the matching playstyle module.
- Put shared interrupts, stealth utility, defensives, and cooldowns in `middleware.lua`.
- Update `class.lua` spell requirements when changing required talents or baseline assumptions.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
