#!/usr/bin/env bash
set -euo pipefail

# ─── Flux AIO Discord Bot — Setup Script ───
# Run on a fresh Linux VPS: bash discord-bot/deploy/setup.sh

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

NODE_VERSION="22"
SERVICE_NAME="flux-bot"

info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
header() { echo -e "\n${BOLD}$*${NC}"; }

# ─── Resolve paths ───
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$BOT_DIR/.." && pwd)"
ENV_FILE="$BOT_DIR/.env"

header "Flux AIO Discord Bot — Setup"
echo "Bot directory:  $BOT_DIR"
echo "Repo root:      $REPO_DIR"
echo ""

# ─── 1. Node.js ───
header "[1/6] Checking Node.js"

install_node_nvm() {
    info "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

    info "Installing Node.js $NODE_VERSION via nvm..."
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    ok "Node.js $(node -v) installed"
}

if command -v node &>/dev/null; then
    CURRENT_NODE="$(node -v)"
    MAJOR="${CURRENT_NODE#v}"
    MAJOR="${MAJOR%%.*}"
    if [ "$MAJOR" -ge 20 ]; then
        ok "Node.js $CURRENT_NODE found (meets minimum v20)"
    else
        warn "Node.js $CURRENT_NODE is too old (need v20+)"
        install_node_nvm
    fi
else
    warn "Node.js not found"
    install_node_nvm
fi

# Ensure nvm node is in PATH for systemd later
NODE_PATH="$(which node)"
info "Using node at: $NODE_PATH"
corepack enable

# ─── 2. Environment variables ───
header "[2/6] Configuring environment"

if [ -f "$ENV_FILE" ]; then
    warn "Existing .env found at $ENV_FILE"
    read -rp "Overwrite it? [y/N] " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        ok "Keeping existing .env"
        SKIP_ENV=true
    fi
fi

if [ "${SKIP_ENV:-}" != "true" ]; then
    echo ""
    echo "You'll need these from the Discord Developer Portal:"
    echo "  https://discord.com/developers/applications"
    echo ""

    # DISCORD_TOKEN (required, masked)
    while true; do
        read -rsp "DISCORD_TOKEN (required): " DISCORD_TOKEN
        echo ""
        if [ -n "$DISCORD_TOKEN" ]; then break; fi
        err "Token cannot be empty"
    done

    # DISCORD_CLIENT_ID (required, numeric)
    while true; do
        read -rp "DISCORD_CLIENT_ID (required): " DISCORD_CLIENT_ID
        if [[ "$DISCORD_CLIENT_ID" =~ ^[0-9]+$ ]]; then break; fi
        err "Client ID must be a numeric snowflake (e.g. 1234567890123456789)"
    done

    # DISCORD_GUILD_ID (optional, numeric if provided)
    read -rp "DISCORD_GUILD_ID (optional, press Enter to skip): " DISCORD_GUILD_ID
    if [ -n "$DISCORD_GUILD_ID" ] && [[ ! "$DISCORD_GUILD_ID" =~ ^[0-9]+$ ]]; then
        warn "Invalid guild ID format — skipping"
        DISCORD_GUILD_ID=""
    fi

    echo ""
    echo "Get your Anthropic API key from:"
    echo "  https://console.anthropic.com/settings/keys"
    echo ""

    # ANTHROPIC_API_KEY (required, masked)
    while true; do
        read -rsp "ANTHROPIC_API_KEY (required): " ANTHROPIC_API_KEY
        echo ""
        if [ -n "$ANTHROPIC_API_KEY" ]; then break; fi
        err "API key cannot be empty"
    done

    echo ""
    echo "GitHub release webhook (optional — posts release announcements to Discord):"
    echo ""

    # WEBHOOK_SECRET (optional, masked)
    read -rsp "WEBHOOK_SECRET (optional, press Enter to skip): " WEBHOOK_SECRET
    echo ""

    # WEBHOOK_PORT (optional, numeric, default 3000)
    WEBHOOK_PORT=""
    if [ -n "$WEBHOOK_SECRET" ]; then
        read -rp "WEBHOOK_PORT (default 3000): " WEBHOOK_PORT
        if [ -n "$WEBHOOK_PORT" ] && [[ ! "$WEBHOOK_PORT" =~ ^[0-9]+$ ]]; then
            warn "Invalid port — using default 3000"
            WEBHOOK_PORT=""
        fi
    fi

    # RELEASE_CHANNEL (optional)
    RELEASE_CHANNEL=""
    if [ -n "$WEBHOOK_SECRET" ]; then
        read -rp "RELEASE_CHANNEL (Discord channel name, e.g. releases): " RELEASE_CHANNEL
    fi

    # Write .env
    cat > "$ENV_FILE" <<EOF
DISCORD_TOKEN=$DISCORD_TOKEN
DISCORD_CLIENT_ID=$DISCORD_CLIENT_ID
DISCORD_GUILD_ID=$DISCORD_GUILD_ID
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
WEBHOOK_PORT=${WEBHOOK_PORT:-3000}
WEBHOOK_SECRET=$WEBHOOK_SECRET
RELEASE_CHANNEL=$RELEASE_CHANNEL
EOF
    chmod 600 "$ENV_FILE"
    ok ".env written to $ENV_FILE (permissions: 600)"
fi

# ─── 3. Install dependencies ───
header "[3/6] Installing dependencies"
info "Running pnpm install from repo root..."
cd "$REPO_DIR"
pnpm install --frozen-lockfile
ok "Dependencies installed"

# ─── 4. Register Discord commands ───
header "[4/6] Registering Discord slash commands"
info "Running register-commands..."
cd "$BOT_DIR"
"$NODE_PATH" src/register-commands.js
ok "Slash commands registered"

# ─── 5. Install systemd service ───
header "[5/6] Installing systemd service"

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Generate the unit file
UNIT_CONTENTS="[Unit]
Description=Flux AIO Discord Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$BOT_DIR
ExecStart=$NODE_PATH src/index.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/tmp
PrivateTmp=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target"

echo "$UNIT_CONTENTS" | sudo tee "$SERVICE_FILE" > /dev/null
sudo chmod 644 "$SERVICE_FILE"
sudo systemctl daemon-reload
ok "Service installed at $SERVICE_FILE"

# ─── 6. Start the service ───
header "[6/6] Starting bot"
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# Brief wait then check status
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Bot is running!"
else
    err "Bot failed to start. Check logs:"
    echo "  journalctl -u $SERVICE_NAME -n 30 --no-pager"
    exit 1
fi

# ─── Done ───
header "Setup complete!"
echo ""
echo "Useful commands:"
echo "  systemctl status $SERVICE_NAME        — Check bot status"
echo "  journalctl -u $SERVICE_NAME -f        — Follow live logs"
echo "  sudo systemctl restart $SERVICE_NAME  — Restart bot"
echo "  sudo systemctl stop $SERVICE_NAME     — Stop bot"
echo "  bash $SCRIPT_DIR/update.sh            — Pull updates & restart"
echo ""
