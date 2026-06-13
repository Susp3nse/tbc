# Flux AIO

A multi-class WoW TBC rotation addon built on the GGL Action/Textfiles framework. Currently supports **Druid** (all forms) and **Hunter**.

**Website & Docs** — [flux-rotations.github.io/tbc](https://flux-rotations.github.io/tbc)

## Project Structure

This is a monorepo with four app packages:

| Package | Description |
|---------|-------------|
| `apps/rotation/` | Core WoW rotation addon (expansion source under `src/<expansion>/`) |
| `apps/website/` | Static site for script distribution and documentation (Astro) |
| `apps/discord-bot/` | Discord bot for personalized rotation tweaks via Claude AI |
| `packages/log-analyzer/` | Reusable Warcraft Logs analyzer library and CLI |
| `packages/tmw-profile-builder/` | Reusable TMW profile build, watch, and SavedVariables sync library |
| `packages/` | Shared workspace packages |

## Getting Started

```bash
corepack enable
pnpm install
```

### Quality Checks

```bash
pnpm lint
pnpm typecheck
pnpm test
```

### Rotation Log Analysis

```bash
pnpm --filter @flux/rotation analyze:report -- --report <code> --fight <id> --player <name> --class Druid --spec Cat
```

### Building the Rotation

```bash
pnpm --filter @flux/rotation build        # Compile to apps/rotation/output/TellMeWhen.lua
pnpm --filter @flux/rotation build:sync   # Build + sync to SavedVariables (requires dev.ini)
pnpm --filter @flux/rotation build:all    # Build + sync
pnpm --filter @flux/rotation watch        # Watch mode: auto-rebuild + sync on save
pnpm --filter @flux/rotation watch:log    # Watch mode with logs in apps/rotation/.logs/
```

Rotation source is organized by expansion: `apps/rotation/src/tbc/{aio,sim}` and `apps/rotation/src/mop/{aio,sim}`. TBC is the default build expansion.

### Running the Website

```bash
pnpm --filter @flux/website dev
pnpm --filter @flux/website build
```

### Running the Discord Bot

```bash
pnpm --filter @flux/bot register   # Register slash commands
pnpm --filter @flux/bot start      # Start the bot
```

## Architecture

The rotation uses a **Strategy Registry** pattern:

1. **Middleware** — shared logic (recovery, cooldowns, buffs, dispels) that runs first, priority-ordered
2. **Strategies** — playstyle-specific rotations registered per form/spec

Each class registers itself via `rotation_registry:register_class()` and gates its modules on `A.PlayerClass`. The build system (`apps/rotation/build.ts`) auto-discovers class modules and compiles them into a single TMW profile.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Supported Classes

- **Druid** — Caster, Cat, Bear, Balance (Moonkin), Resto (Tree of Life)
- **Hunter** — Ranged DPS with auto-shot clip tracking
