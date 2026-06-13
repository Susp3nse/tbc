# Hunter AIO

Contributor notes for the Hunter rotation modules.

## Registration

- Class: `Hunter`
- Version marker: `v1.8.0 + 1`
- Registered playstyles: `ranged`
- Idle playstyle: none
- Primary resource: mana

## Playstyles

| Playstyle | Module | Role |
| --- | --- | --- |
| `ranged` | `rotation.lua` | Core ranged rotation, shot priority, stings, marks, and combat flow. |

## Module Map

- `schema.lua`: Hunter settings schema used by the generated ProfileUI and custom settings panel.
- `class.lua`: spell/action definitions, class registration, context extensions, spell requirements, and dashboard config.
- `middleware.lua`: class-wide recovery, pet, trap, utility, cooldown, and shared pre-rotation behavior.
- `rotation.lua`: main ranged strategy registration.
- `adaptive.lua`: adaptive shot timing and rotation support.
- `adaptivepanel.lua`: adaptive rotation UI support.
- `cliptracker.lua`: weapon swing and shot clipping tracking.
- `meleeweave.lua`: melee weaving support.
- `debugui.lua`: Hunter-specific diagnostic overlay.

## Settings Tabs

The schema exposes `General`, `Rotation`, `Cooldowns`, `PvP`, and `Pet & Diag` tabs. Keep settings runtime-driven through `context.settings`, especially for shot timing, pet safety, and cooldown controls.

## Change Checklist

- Keep core shot priority in `rotation.lua`; put timing helpers in `adaptive.lua` or `cliptracker.lua`.
- Keep pet and shared utility behavior in `middleware.lua`.
- Update `class.lua` spell requirements when adding required abilities or talents.
- For rotation behavior changes, increment `dev_revision` during development; roll it into `version` only for release.
- Validate with `pnpm build:rotation`; use `pnpm --filter @flux/rotation sim:hunter` when touching supported Hunter sim paths.
