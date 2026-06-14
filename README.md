# Flux AIO

A multi-class WoW TBC rotation addon built on the GGL Action/Textfiles framework, covering all nine classes.

**Website & Docs** — [flux-rotations.github.io/tbc](https://flux-rotations.github.io/tbc)

## Project Structure

This is a pnpm monorepo. New here? Start with **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**.

| Package | Description |
|---------|-------------|
| `apps/tbc-rotation/` | TBC rotation addon (Lua source under `src/aio/`; one app per game version) |
| `apps/website/` | Static site for script distribution and documentation (Astro) |
| `apps/discord-bot/` | Discord bot for personalized rotation tweaks via Claude AI |
| `packages/log-analyzer/` | Reusable Warcraft Logs analyzer library and CLI |
| `packages/tmw-profile-builder/` | Reusable TMW profile build, watch, and SavedVariables sync library |

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
pnpm --filter @flux/log-analyzer analyze:report -- --report <code> --fight <id> --player <name> --class Druid --spec Cat
```

### Building the Rotation

```bash
pnpm --filter @flux/tbc-rotation build        # Compile to apps/tbc-rotation/output/TellMeWhen.lua
pnpm --filter @flux/tbc-rotation build:sync   # Build + sync to SavedVariables (requires builder.config.local.json)
pnpm --filter @flux/tbc-rotation build:all    # Build + sync
pnpm --filter @flux/tbc-rotation watch        # Watch mode: auto-rebuild + sync on save
pnpm --filter @flux/tbc-rotation watch:log    # Watch mode with logs in apps/tbc-rotation/.logs/
```

Each game version is its own app. The TBC app holds its compiled rotation tree under `apps/tbc-rotation/src/aio/` and its simulation harness under `apps/tbc-rotation/src/sim/`. Future expansions get their own app (e.g. `apps/mop-rotation`), each with its own template, build, and output.

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

Each class registers itself via `rotation_registry:register_class()` and gates its modules on `A.PlayerClass`. The build system (`apps/tbc-rotation/build.ts`) auto-discovers class modules and compiles them into a single TMW profile.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Supported Classes

All nine TBC classes: **Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior**.
Each lives under `apps/tbc-rotation/src/aio/<class>/` and registers its own specs/forms. See the
[class pages](https://flux-rotations.github.io/tbc) for per-spec coverage.
