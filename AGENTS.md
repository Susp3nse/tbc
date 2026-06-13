# Repository Guidelines

## Project Structure & Module Organization

This is a pnpm workspace for Flux AIO TBC.

- `apps/rotation/`: expansion-specific Lua addon source in `apps/rotation/src/<expansion>/aio/`, plus TypeScript build/watch tooling. TBC currently lives in `apps/rotation/src/tbc/aio/`. Builds emit `apps/rotation/output/TellMeWhen.lua`.
- `apps/website/`: Astro documentation site. Pages live in `apps/website/src/pages/`, shared UI in `apps/website/src/layouts/` and `apps/website/src/components/`, data in `apps/website/src/data/`, assets in `apps/website/public/`.
- `apps/discord-bot/`: bot source in `apps/discord-bot/src/`; deployment files in `apps/discord-bot/deploy/`.
- `packages/log-analyzer/`: reusable TypeScript Warcraft Logs analyzer library and CLI; tests in `packages/log-analyzer/test/`.
- `packages/tmw-profile-builder/`: reusable TypeScript build/watch system for compiling rotation source into TMW profiles and syncing SavedVariables.
- `packages/`: shared workspace packages for reusable code.
- `docs/`: research, plans, and API references for class logic and site content.

## Build, Test, and Development Commands

Run `corepack enable` once, then `pnpm install`.

- `pnpm build:rotation`: compile the rotation package and generate TMW output.
- `pnpm --filter @flux/rotation build:sync`: build and sync to a local WoW SavedVariables target; requires `apps/rotation/dev.ini`.
- `pnpm --filter @flux/rotation watch`: rebuild and sync on source changes.
- `pnpm --filter @flux/rotation watch:log`: run watch mode with stdout/stderr written under `apps/rotation/.logs/`.
- `pnpm build:website`: build the site.
- `pnpm --filter @flux/website dev`: run the local website dev server.
- `pnpm build:bot`: compile the Discord bot.
- `pnpm lint`: run Oxlint across TypeScript files in `apps/` and `packages/`.
- `pnpm typecheck`: run available TypeScript checks across workspace packages.
- `pnpm test`: run the log analyzer tests.

## Coding Style & Naming Conventions

Use the existing style in nearby files. TypeScript targets ES modules where package `type` is `module`; prefer named exports, explicit domain names, and focused modules. Lua rotation files are organized by expansion/class/spec, for example `apps/rotation/src/tbc/aio/paladin/retribution.lua`; keep class logic in the matching folder and shared behavior in middleware or common modules. Use kebab-case for scripts and docs, and lowercase class/spec file names.

## Testing Guidelines

Automated tests cover `@flux/log-analyzer` with direct `tsx` files such as `process-fight.test.ts`. Add tests under `packages/log-analyzer/test/` for analyzer behavior changes and run `pnpm test`. For rotation changes, run `pnpm build:rotation` at minimum; use `pnpm --filter @flux/rotation sim:hunter` when touching supported sim paths.

## Commit & Pull Request Guidelines

Commit subjects must use `[<Expansion>] (<Class or Area>) <type of work>: <description>`, for example `[TBC] (Druid) fix: preserve Moonfire refresh timing`. Use the expansion tag for the target game version, the class name for class-specific rotation work, or an area such as `Website`, `Bot`, `Analyzer`, or `Workspace` for non-class changes. Keep descriptions imperative and concise. PRs should describe behavior changes, list validation commands, link related issues or plans, and include screenshots for website UI changes. Note required secrets or local config, but never commit `.env`, `dev.ini`, logs, or credentials.

## Agent-Specific Instructions

Keep this file contributor-focused. Detailed agent workflow and architecture guidance lives in `CLAUDE.md`; consult it before broad code changes and avoid duplicating its full contents here.

For rotation work, update the affected class version marker so in-game reloads can verify the active change. During development/watch mode, keep the released class `version` unchanged and increment `dev_revision` on each completed fix or change, which displays as `<Class> vX.Y.Z + N | Build: dev`. When the work is committed or released, roll the dev revision into the patch version, for example `v1.10.0 + 3` becomes `v1.10.1`, then reset or remove `dev_revision`.
