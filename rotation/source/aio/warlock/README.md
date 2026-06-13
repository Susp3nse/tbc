# Warlock AIO

Contributor notes for the Warlock rotation modules.

## Registration

- Class: `Warlock`
- Version marker: `v1.7.0`
- Registered playstyles: `affliction`, `demonology`, `destruction`
- Idle playstyle: none
- Primary resource: mana, health via Life Tap, and pet state

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `affliction` | `affliction.lua` | Affliction DoTs, drains, curses, and Affliction cooldowns. |
| `demonology` | `demonology.lua` | Demonology damage, pet support, and demon cooldown behavior. |
| `destruction` | `destruction.lua` | Destruction nukes, Immolate/Incinerate support, and burst tools. |

## Module Map

- `schema.lua`: Warlock settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, pet context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide Life Tap, pet utility, curses, defensives, cooldowns, and shared pre-rotation behavior.
- `affliction.lua`, `demonology.lua`, `destruction.lua`: playstyle strategy registration.

## Settings Tabs

The schema exposes `General`, `Affliction`, `Demonology`, `Destruction`, and `CDs & Mana` tabs. Keep DoT, curse, Life Tap, and pet controls read from `context.settings` at runtime.

## Change Checklist

- Keep spec priority in the matching playstyle module.
- Put shared curses, Life Tap, pet safety, and defensive behavior in `middleware.lua`.
- Update `class.lua` context extensions when new strategy logic depends on pet state.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
