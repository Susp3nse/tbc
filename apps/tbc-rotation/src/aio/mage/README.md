# Mage AIO

Contributor notes for the Mage rotation modules.

## Registration

- Class: `Mage`
- Version marker: `v1.7.0`
- Registered playstyles: `fire`, `frost`, `arcane`
- Idle playstyle: none
- Primary resource: mana

## Playstyles

| Playstyle | Module       | Role                                                                |
| --------- | ------------ | ------------------------------------------------------------------- |
| `fire`    | `fire.lua`   | Fire DPS, Scorch/Fireball behavior, and Fire cooldown usage.        |
| `frost`   | `frost.lua`  | Frostbolt-based DPS, Frost utility, and Water Elemental support.    |
| `arcane`  | `arcane.lua` | Arcane Blast priority, filler selection, and Arcane cooldown usage. |

## Module Map

- `schema.lua`: Mage settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, active playstyle selection, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide recovery, shields, mana tools, cooldowns, interrupts, and shared pre-rotation behavior.
- `fire.lua`, `frost.lua`, `arcane.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Fire`, `Frost`, `Arcane`, and `CDs & Mana` tabs. Keep per-spec toggles local to the matching strategy module and shared mana/cooldown behavior in middleware.

## Change Checklist

- Keep spec-specific priority in the matching playstyle module.
- Put common defensive, mana, interrupt, and cooldown behavior in `middleware.lua`.
- Update `class.lua` spell requirements when changing required talents or filler assumptions.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
