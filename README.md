# Flux AIO

A multi-class WoW TBC rotation addon built on the GGL Action/Textfiles framework. Currently supports **Druid** (all forms) and **Hunter**.

**Website & Docs** — [flux-rotations.github.io/tbc](https://flux-rotations.github.io/tbc)

## Project Structure

This is a monorepo with three packages:

| Package | Description |
|---------|-------------|
| `rotation/` | Core WoW rotation addon (Lua source + Node.js build system) |
| `website/` | Static site for script distribution and documentation (Astro) |
| `discord-bot/` | Discord bot for personalized rotation tweaks via Claude AI |

## Getting Started

```bash
corepack enable
pnpm install
```

### Building the Rotation

```bash
pnpm --filter @flux/rotation build        # Compile to rotation/output/TellMeWhen.lua
pnpm --filter @flux/rotation build:sync   # Build + sync to SavedVariables (requires dev.ini)
pnpm --filter @flux/rotation build:all    # Build + sync
pnpm --filter @flux/rotation watch        # Watch mode: auto-rebuild + sync on save
```

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

Each class registers itself via `rotation_registry:register_class()` and gates its modules on `A.PlayerClass`. The build system (`rotation/build.js`) auto-discovers class modules and compiles them into a single TMW profile.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Supported Classes

- **Druid** — Caster, Cat, Bear, Balance (Moonkin), Resto (Tree of Life)
- **Hunter** — Ranged DPS with auto-shot clip tracking
