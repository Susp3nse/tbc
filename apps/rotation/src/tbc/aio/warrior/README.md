# Warrior AIO

Contributor notes for the Warrior rotation modules.

## Registration

- Class: `Warrior`
- Version marker: `v1.9.2`
- Registered playstyles: `arms`, `fury`, `kebab`, `protection`
- Idle playstyle: none
- Primary resource: rage

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `arms` | `arms.lua` | Arms DPS, Mortal Strike, Overpower, Execute, and Arms cooldowns. |
| `fury` | `fury.lua` | Fury DPS, Bloodthirst, Whirlwind, Execute, Rampage, and cooldowns. |
| `kebab` | `kebab.lua` | Hybrid Arms/Fury style using Mortal Strike with dual-wield-oriented support. |
| `protection` | `protection.lua` | Protection tanking, Shield Slam/Revenge, mitigation, taunts, and threat tools. |

## Module Map

- `schema.lua`: Warrior settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, stance helpers, class registration, context extensions, gap handler, spell requirements, and dashboard config.
- `middleware.lua`: class-wide stance handling, defensives, interrupts, mobility, cooldowns, and shared pre-rotation behavior.
- `arms.lua`, `fury.lua`, `kebab.lua`, `protection.lua`: playstyle strategy registration.

## Settings Tabs

The Warrior schema is larger than most classes and includes general combat controls, DPS spec settings, Protection tank controls, defensive thresholds, PvP tools, and Kebab-specific options. Keep rage, stance, threat, and execute settings runtime-driven from `context.settings`.

## Change Checklist

- Keep playstyle priority in the matching module.
- Put shared stance, mobility, interrupt, defensive, and cooldown behavior in `middleware.lua`.
- Be careful with stance requirements and rage thresholds; many Warrior actions are stance-gated.
- For rotation behavior changes, increment `dev_revision` during development if one is present; otherwise add or bump it as the active development marker.
- Validate with `pnpm build:rotation` after Lua changes.
