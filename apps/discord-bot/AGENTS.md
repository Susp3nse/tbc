# discord-bot — Flux AIO Bot

> Scope: the Discord bot. Read the root `AGENTS.md` first for global behavior + the workspace map.

A Discord bot (discord.js + `@anthropic-ai/sdk`) that lets users request personalized rotation
tweaks via Claude AI and posts release announcements. TypeScript, ESM, run with `tsx` in dev.

## Commands

```bash
pnpm --filter @flux/bot dev        # run with tsx (local)
pnpm --filter @flux/bot build      # tsc → dist/
pnpm --filter @flux/bot start      # node dist/index.js
pnpm --filter @flux/bot register   # register slash commands with Discord
pnpm --filter @flux/bot typecheck
```

## Layout

```
src/
  index.ts             Entry — Discord client + webhook HTTP server
  config.ts            Loads .env, validates required secrets, all tunables
  register-commands.ts Slash-command registration
  commands/            request.ts, status.ts, admin.ts
  services/            builder.ts, claude.ts, admin-claude.ts, guardrails.ts, webhook.ts
deploy/                flux-bot.service (systemd), setup.sh, update.sh
```

## How `/request` builds the addon (key integration fact)

The bot does **not** import the rotation's TS. It shells out to the rotation's **compiled
`dist/build.js`** in an isolated temp workspace (`services/builder.ts`):

1. `createWorkspace()` makes a temp dir and copies in from the rotation app: `src/aio/`,
   `dist/build.js`, `src/tmw-template.lua`, `builder.config.json`, `package.json`, and the
   `@flux/tmw-profile-builder` `dist/` into `node_modules/@flux/tmw-profile-builder/`.
2. `runBuild()` runs `node build.js` with `ROTATION_ROOT` pointed at the temp dir (30s timeout),
   then reads `output/TellMeWhen.lua`.
3. `cleanup()` removes the workspace; `cleanupStaleWorkspaces()` reaps `flux-bot-*` dirs older than 1h.

This is **why the rotation ships a built `dist`** and why `build.ts` honors `ROTATION_ROOT`. If you
change the rotation's build inputs (new top-level file the build needs, renamed config), update the
copy list in `services/builder.ts` to match.

## Secrets / env

`config.ts` loads `apps/discord-bot/.env` and throws if any required var is missing. **Never commit
`.env`** (see `.env.example`).

- Required: `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `ANTHROPIC_API_KEY`.
- Optional: `DISCORD_GUILD_ID` (faster command registration), `WEBHOOK_PORT` (default 3000),
  `WEBHOOK_SECRET` (GitHub release webhook HMAC), `RELEASE_CHANNEL`.
- Models and limits (request length, rate limit, turn caps) are set in `config.ts`.

## Deploy

`.github/workflows/deploy-bot.yml` SSHes to the VPS and runs `deploy/update.sh` on push to `main`
touching `apps/discord-bot/**` (or `workflow_dispatch`). Runs under systemd (`deploy/flux-bot.service`).
**Bot-only changes don't need a rotation version bump or tag** — they ship through this workflow.
