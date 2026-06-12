# Flux AIO Discord Bot

A Discord bot that lets users request personalized rotation tweaks via Claude AI, and posts automatic release announcements from GitHub webhooks.

## Features

- **`/request`** — Users describe a rotation change in plain English. The bot spins up an isolated workspace, sends the request to Claude AI (with full context of the addon's architecture), validates the changes, builds the addon, and DMs the compiled `.lua` file back.
- **`/status`** — Shows bot uptime, current request activity, and the user's recent request history.
- **Release announcements** — An HTTP webhook endpoint receives GitHub release events and posts formatted embeds to a configured Discord channel.

## Prerequisites

- **Node.js 20+** (22 recommended)
- A **Discord bot application** with a token ([Discord Developer Portal](https://discord.com/developers/applications))
- An **Anthropic API key** ([Anthropic Console](https://console.anthropic.com/settings/keys))

## Quick Start (Local)

1. **Install dependencies** from the repo root:
   ```bash
   corepack enable
   pnpm install
   ```

2. **Create your `.env`** file:
   ```bash
   cp discord-bot/.env.example discord-bot/.env
   ```

3. **Fill in the required values** in `discord-bot/.env`:
   ```env
   DISCORD_TOKEN=your-bot-token
   DISCORD_CLIENT_ID=your-application-id
   DISCORD_GUILD_ID=your-test-guild-id   # optional, speeds up command registration
   ANTHROPIC_API_KEY=sk-ant-...
   ```

4. **Register slash commands** with Discord:
   ```bash
   pnpm --filter @flux/bot register
   ```
   > Guild-scoped commands (with `DISCORD_GUILD_ID` set) appear instantly. Global commands take up to 1 hour to propagate.

5. **Start the bot**:
   ```bash
   pnpm --filter @flux/bot start
   ```

## VPS Deployment

The `deploy/` directory has scripts for a systemd-based Linux deployment:

```bash
# First-time setup (interactive — prompts for all credentials)
bash discord-bot/deploy/setup.sh

# Pull updates and restart
bash discord-bot/deploy/update.sh
```

`setup.sh` handles:
1. Installing Node.js via nvm (if needed)
2. Prompting for all environment variables
3. Writing `.env` with secure permissions (600)
4. Installing pnpm dependencies
5. Registering Discord slash commands
6. Creating and starting a systemd service

### Useful systemd commands

```bash
systemctl status flux-bot        # Check status
journalctl -u flux-bot -f        # Follow live logs
sudo systemctl restart flux-bot  # Restart
sudo systemctl stop flux-bot     # Stop
```

## GitHub Release Webhook

The bot can automatically post to a Discord channel when a new GitHub release is published.

### 1. Configure the bot

Add these to your `discord-bot/.env`:

```env
WEBHOOK_PORT=3000                # Port for the HTTP server (default: 3000)
WEBHOOK_SECRET=your-secret-here  # Shared secret for signature verification
RELEASE_CHANNEL=1234567890       # Discord channel ID to post to
```

If `WEBHOOK_SECRET` or `RELEASE_CHANNEL` are not set, the webhook server won't start (the bot still works normally).

### 2. Create the GitHub webhook

1. Go to your repo **Settings > Webhooks > Add webhook**
2. Set **Payload URL** to `http://your-server:3000/webhook/github`
3. Set **Content type** to `application/json`
4. Set **Secret** to the same value as `WEBHOOK_SECRET` in your `.env`
5. Under **Which events would you like to trigger this webhook?**, select **Let me select individual events** and check only **Releases**
6. Click **Add webhook**

### 3. Firewall

Make sure your server's firewall allows inbound traffic on the webhook port:

```bash
# UFW example
sudo ufw allow 3000/tcp

# Or restrict to GitHub's webhook IPs
# See: https://api.github.com/meta (look for the "hooks" array)
```

### 4. Verify it works

You can test with a curl command:

```bash
PAYLOAD='{"action":"published","release":{"tag_name":"v2.5.1","name":"v2.5.1","body":"Test release notes","author":{"login":"testuser","avatar_url":"","html_url":"https://github.com/testuser"},"html_url":"https://github.com/test/repo/releases/tag/v2.5.1","published_at":"2026-01-01T00:00:00Z"}}'
SECRET="your-secret-here"
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print "sha256="$2}')

curl -X POST http://localhost:3000/webhook/github \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: $SIG" \
  -H "X-GitHub-Event: release" \
  -d "$PAYLOAD"
```

You should see `OK` and a formatted embed in your Discord channel.

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `DISCORD_TOKEN` | Yes | — | Bot token from Discord Developer Portal |
| `DISCORD_CLIENT_ID` | Yes | — | Application ID (numeric snowflake) |
| `DISCORD_GUILD_ID` | No | — | Guild ID for guild-scoped command registration |
| `ANTHROPIC_API_KEY` | Yes | — | Claude API key |
| `WEBHOOK_PORT` | No | `3000` | Port for the GitHub webhook HTTP server |
| `WEBHOOK_SECRET` | No | — | Shared secret for webhook signature verification |
| `RELEASE_CHANNEL` | No | — | Discord channel ID for release announcements |

## Project Structure

```
discord-bot/
├── src/
│   ├── index.ts                 # Bot startup, event routing, webhook init
│   ├── config.ts                # Environment config loader
│   ├── register-commands.ts     # One-time slash command registration
│   ├── commands/
│   │   ├── request.ts           # /request command handler
│   │   └── status.ts            # /status command handler
│   └── services/
│       ├── claude.ts            # Claude API integration (agentic loop)
│       ├── builder.ts           # Temp workspace creation & build execution
│       ├── guardrails.ts        # Input validation & safety checks
│       └── webhook.ts           # GitHub release webhook HTTP server
├── deploy/
│   ├── setup.sh                 # First-time VPS setup (interactive)
│   ├── update.sh                # Pull & restart
│   └── flux-bot.service        # systemd unit template
├── .env.example                 # Environment variable template
└── package.json
```
