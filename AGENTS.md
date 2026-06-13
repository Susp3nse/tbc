# Repository Guidelines

## Project Structure & Module Organization

This is a pnpm workspace for Flux AIO TBC.

- `rotation/`: Lua addon source in `rotation/source/aio/`, plus TypeScript build/watch tooling. Builds emit `rotation/output/TellMeWhen.lua`.
- `website/`: Astro documentation site. Pages live in `website/src/pages/`, shared UI in `website/src/layouts/` and `website/src/components/`, data in `website/src/data/`, assets in `website/public/`.
- `log-analyzer/`: TypeScript CLI and utilities in `log-analyzer/src/`; tests in `log-analyzer/test/`.
- `discord-bot/`: bot source in `discord-bot/src/`; deployment files in `discord-bot/deploy/`.
- `docs/`: research, plans, and API references for class logic and site content.

## Build, Test, and Development Commands

Run `corepack enable` once, then `pnpm install`.

- `pnpm build:rotation`: compile the rotation package and generate TMW output.
- `pnpm --filter @flux/rotation build:sync`: build and sync to a local WoW SavedVariables target; requires `rotation/dev.ini`.
- `pnpm --filter @flux/rotation watch`: rebuild and sync on source changes.
- `pnpm build:website`: build the site.
- `pnpm --filter @flux/website dev`: run the local website dev server.
- `pnpm build:bot`: compile the Discord bot.
- `pnpm typecheck`: run available TypeScript checks across workspace packages.
- `pnpm test`: run the log analyzer tests.

## Coding Style & Naming Conventions

Use the existing style in nearby files. TypeScript targets ES modules where package `type` is `module`; prefer named exports, explicit domain names, and focused modules. Lua rotation files are organized by class/spec, for example `rotation/source/aio/paladin/retribution.lua`; keep class logic in the matching folder and shared behavior in middleware or common modules. Use kebab-case for scripts and docs, and lowercase class/spec file names.

## Testing Guidelines

Automated tests cover `@flux/log-analyzer` with direct `tsx` files such as `process-fight.test.ts`. Add tests under `log-analyzer/test/` for analyzer behavior changes and run `pnpm test`. For rotation changes, run `pnpm build:rotation` at minimum; use `pnpm --filter @flux/rotation sim:hunter` when touching supported sim paths.

## Commit & Pull Request Guidelines

Commit subjects must use `[<Expansion>] (<Class or Area>) <type of work>: <description>`, for example `[TBC] (Druid) fix: preserve Moonfire refresh timing`. Use the expansion tag for the target game version, the class name for class-specific rotation work, or an area such as `Website`, `Bot`, `Analyzer`, or `Workspace` for non-class changes. Keep descriptions imperative and concise. PRs should describe behavior changes, list validation commands, link related issues or plans, and include screenshots for website UI changes. Note required secrets or local config, but never commit `.env`, `dev.ini`, logs, or credentials.

## Agent-Specific Instructions

Keep this file contributor-focused. Detailed agent workflow and architecture guidance lives in `CLAUDE.md`; consult it before broad code changes and avoid duplicating its full contents here.

For rotation work, update the affected class version marker so in-game reloads can verify the active change. During development/watch mode, keep the released class `version` unchanged and increment `dev_revision` on each completed fix or change, which displays as `<Class> vX.Y.Z + N | Build: dev`. When the work is committed or released, roll the dev revision into the patch version, for example `v1.10.0 + 3` becomes `v1.10.1`, then reset or remove `dev_revision`.
