# Menagerie

A multi-class WoW TBC rotation addon built on the GGL Action/Textfiles framework, covering all nine classes.

**Website & Docs** — [menagerie.dev](https://menagerie.dev)

## Project Structure

This is a pnpm monorepo. New here? Start with **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**.

| Package | Description |
|---------|-------------|
| `apps/tbc-rotation/` | TBC rotation addon (Lua source under `src/aio/`; one app per game version) |
| `apps/website/` | Static site for script distribution and documentation (Astro) |
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
pnpm --filter @menagerie/log-analyzer analyze:report -- --report <code> --fight <id> --player <name> --class Druid --spec Cat
```

### Building the Rotation

```bash
pnpm --filter @menagerie/tbc-rotation build        # Compile to apps/tbc-rotation/output/TellMeWhen.lua
pnpm --filter @menagerie/tbc-rotation build:sync   # Build + sync to SavedVariables (requires builder.config.local.json)
pnpm --filter @menagerie/tbc-rotation build:all    # Build + sync
pnpm --filter @menagerie/tbc-rotation watch        # Watch mode: auto-rebuild + sync on save
pnpm --filter @menagerie/tbc-rotation watch:log    # Watch mode with logs in apps/tbc-rotation/.logs/
```

Each game version is its own app. The TBC app holds its compiled rotation tree under `apps/tbc-rotation/src/aio/` and its simulation harness under `apps/tbc-rotation/src/sim/`. Future expansions get their own app (e.g. `apps/mop-rotation`), each with its own template, build, and output.

### Running the Website

```bash
pnpm --filter @menagerie/website dev
pnpm --filter @menagerie/website build
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
[class pages](https://menagerie.dev) for per-spec coverage.

## Credits

**Menagerie is a fork of the original [Flux AIO](https://github.com/flux-rotations/tbc)** TBC rotation
addon. Full attribution to the upstream project and its author(s) lives in [`NOTICE`](NOTICE). The
rebrand changed the name, namespace, and hosting; the rotation logic descends directly from that
work — credit for the foundation belongs upstream.
