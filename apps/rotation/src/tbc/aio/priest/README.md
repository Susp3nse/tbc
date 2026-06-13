# Priest AIO

Contributor notes for the Priest rotation modules.

## Registration

- Class: `Priest`
- Version marker: `v1.9.0`
- Registered playstyles: `shadow`, `smite`, `holy`, `discipline`
- Idle playstyle: none
- Primary resource: mana

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `shadow` | `shadow.lua` | Shadow DPS, DoTs, Mind Blast, Mind Flay, and Shadowform behavior. |
| `smite` | `smite.lua` | Holy damage caster behavior built around Smite and Holy Fire. |
| `holy` | `holy.lua` | Holy healing behavior. |
| `discipline` | `discipline.lua` | Discipline support and cooldown behavior. |

## Module Map

- `schema.lua`: Priest settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, active playstyle selection, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide buffs, mana tools, defensives, dispels, and shared pre-rotation behavior.
- `healing.lua`: shared healing helpers.
- `shadow.lua`, `smite.lua`, `holy.lua`, `discipline.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Shadow`, `Smite`, `Holy`, `Discipline`, and `CDs & Mana` tabs. Keep healing thresholds and cooldown settings read from `context.settings` at execution time.

## Change Checklist

- Keep DPS and healing priority in the matching playstyle module.
- Use `healing.lua` for reusable healing decisions and `discipline.lua` for discipline support behavior.
- Put shared buffs, dispels, and mana tools in `middleware.lua`.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
