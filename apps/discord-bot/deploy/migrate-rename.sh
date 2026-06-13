#!/usr/bin/env bash
set -euo pipefail

# ─── Flux AIO Discord Bot — One-time Migration Script ───
# Migrates from diddy-bot → flux-bot, renames /root/tbc-aio → /root/tbc.
# Run once on the VPS, then delete this script.
#
# Usage: bash /root/tbc-aio/apps/discord-bot/deploy/migrate-rename.sh

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
header() { echo -e "\n${BOLD}$*${NC}"; }

OLD_SERVICE="diddy-bot"
NEW_SERVICE="flux-bot"
OLD_DIR="/root/tbc-aio"
NEW_DIR="/root/tbc"

# Load nvm if present
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

NODE_PATH="$(which node)"

header "Flux AIO — Rebrand Migration"
echo "Old dir:  $OLD_DIR"
echo "New dir:  $NEW_DIR"
echo ""

# ─── 1. Stop old service ───
header "[1/6] Stopping old service"
if systemctl is-active --quiet "$OLD_SERVICE" 2>/dev/null; then
    sudo systemctl stop "$OLD_SERVICE"
    sudo systemctl disable "$OLD_SERVICE"
    ok "Stopped and disabled $OLD_SERVICE"
else
    info "$OLD_SERVICE not running (skipping)"
fi

if [ -f "/etc/systemd/system/${OLD_SERVICE}.service" ]; then
    sudo rm "/etc/systemd/system/${OLD_SERVICE}.service"
    sudo systemctl daemon-reload
    ok "Removed old service file"
fi

# ─── 2. Rename directory ───
header "[2/6] Renaming directory"
cd /root
if [ -d "$NEW_DIR" ]; then
    err "$NEW_DIR already exists! Aborting."
    exit 1
fi
mv "$OLD_DIR" "$NEW_DIR"
ok "Renamed $OLD_DIR → $NEW_DIR"

# ─── 3. Update git remote ───
header "[3/6] Updating git remote"
cd "$NEW_DIR"
git remote set-url origin git@github.com:flux-rotations/tbc.git
ok "Remote updated to flux-rotations/tbc"

# ─── 4. Pull latest ───
header "[4/6] Pulling latest code"
git pull
ok "Code updated"

# ─── 5. Install deps & rebuild ───
header "[5/6] Installing dependencies & rebuilding"
corepack enable
pnpm install --frozen-lockfile
cd "$NEW_DIR/apps/rotation"
pnpm run build
cd "$NEW_DIR/apps/discord-bot"
pnpm run build
ok "Dependencies installed, rotation built"

# ─── 6. Install new service & start ───
header "[6/6] Installing flux-bot service"

BOT_DIR="$NEW_DIR/apps/discord-bot"
SERVICE_FILE="/etc/systemd/system/${NEW_SERVICE}.service"

cat <<UNIT | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Flux AIO Discord Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$BOT_DIR
ExecStart=$NODE_PATH dist/index.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/tmp
PrivateTmp=true

StandardOutput=journal
StandardError=journal
SyslogIdentifier=$NEW_SERVICE

[Install]
WantedBy=multi-user.target
UNIT

sudo chmod 644 "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo systemctl enable "$NEW_SERVICE"
sudo systemctl start "$NEW_SERVICE"

sleep 2
if systemctl is-active --quiet "$NEW_SERVICE"; then
    ok "Bot is running!"
else
    err "Bot failed to start. Check logs:"
    echo "  journalctl -u $NEW_SERVICE -n 30 --no-pager"
    exit 1
fi

header "Migration complete!"
echo ""
echo "  Old: $OLD_DIR ($OLD_SERVICE) → removed"
echo "  New: $NEW_DIR ($NEW_SERVICE) → running"
echo ""
echo "Check logs: journalctl -u $NEW_SERVICE -f"
