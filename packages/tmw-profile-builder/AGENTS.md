# tmw-profile-builder — Build/Watch/Sync Engine

> Scope: the reusable TMW profile build engine. Read the root `AGENTS.md` first for global behavior +
> the workspace map.

A **content-agnostic** TypeScript engine that bundles a consuming app's per-class Lua modules into a
single TMW profile, watches for changes, and syncs to WoW SavedVariables. It knows **HOW** to build;
it ships **no** naming/load-order/path defaults. The consuming app owns those in its
`builder.config.json` (the WHAT). Today the only consumer is `apps/tbc-rotation`.

## Ships compiled

Built to `dist/` (`pnpm build` = `tsc`) and consumed via the package `exports` map
(`@flux/tmw-profile-builder` → `dist/index.js`, types `dist/index.d.ts`). Consumers run the compiled
output — e.g. the rotation's `build.ts` imports `createBuildContext` + `runCli` from here, and the
discord-bot copies this `dist/` into its temp workspace. **Rebuild `dist/` after changing `src/`** or
consumers run stale code.

```bash
pnpm --filter @flux/tmw-profile-builder build       # tsc → dist/
pnpm --filter @flux/tmw-profile-builder typecheck
```

## The config contract

`createBuildContext({ projectRoot, configPath? })` (`src/context.ts`) loads the consuming app's
`builder.config.json` (default `<projectRoot>/builder.config.json`), splits `paths` from the rest
(naming + load-order conventions), and resolves every path relative to `projectRoot`. It **throws**
if the config is missing. Resulting `BuildContext`: `projectRoot`, `aioDir`, `templatePath`,
`outputPath`, `localConfigPath`, `conventions`. Path fallbacks (`src/aio`, `tmw-template.lua`,
`output/TellMeWhen.lua`, `builder.config.local.json`) exist only as last resort when a `paths` key is
omitted — the canonical values live in the app's config.

## Public API (`src/index.ts`)

| Export | Role |
|--------|------|
| `createBuildContext` | Build the `BuildContext` from the app's config. |
| `runCli` | The build/sync CLI dispatcher (`--sync`, `--all`). |
| `DevWatcher` / `runDevWatch` | Watch `aioDir`, rebuild + sync on change. |
| `ProfileBuilder` | Assembles modules into the TMW profile per `loadOrder` + conventions. |
| `discoverClasses` / `discoverModules` / `getProfileName` | Auto-discover class folders + module files. |
| `getAIODir` / `getSavedVariablesPaths` / `readLocalConfig` | Read the gitignored local sync config. |
| `timestamp` / `writeWithRetry` | IO helpers. |
| types | `BuildContext`, `BuildConventions`, `BuilderPaths`, `BuildMetadata`, `LocalConfig`, `ModuleSlot`, `RotationModule`, `SavedVariablesTarget`, `WatchOptions`, etc. |

## Internals

`src/` modules: `context.ts` (config → context), `discovery.ts` (class/module discovery),
`tmw-profile-builder.ts` + `tmw-profile.ts` + `lua.ts` (profile assembly / Lua emission),
`profile-sync.ts` (SavedVariables sync), `localconfig.ts` (local config reader), `metadata.ts`
(build-number injection), `cli.ts`, `dev-watch.ts`, `io.ts`, `types.ts`.

## See also

- The config it reads + load-order semantics: `apps/tbc-rotation/AGENTS.md` (builder.config.json section).
