#!/usr/bin/env bash
set -euo pipefail

# ─── Flux AIO Discord Bot — Update Script ───
# Pulls latest code, reinstalls deps, rebuilds rotation, restarts bot.

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }
header() { echo -e "\n${BOLD}$*${NC}"; }

SERVICE_NAME="flux-bot"

# Load nvm if present (needed for non-interactive SSH sessions)
export NVM_DIR="${HOME}/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$BOT_DIR/.." && pwd)"
ROTATION_DIR="$REPO_DIR/rotation"

header "Flux AIO Discord Bot — Update"

# ─── 1. Pull latest ───
header "[1/4] Pulling latest code"
cd "$REPO_DIR"
git checkout -- .
git pull
ok "Code updated"

# ─── 2. Install deps ───
header "[2/4] Installing dependencies"
corepack enable
pnpm install --frozen-lockfile
ok "Dependencies up to date"

# ─── 3. Rebuild rotation (so the bot has fresh source to copy) ───
header "[3/4] Rebuilding rotation"
cd "$ROTATION_DIR"
pnpm run build
ok "Rotation built"

header "[3b/4] Building bot"
cd "$BOT_DIR"
pnpm run build
ok "Bot built"

# ─── 4. Restart service ───
header "[4/4] Restarting bot"
sudo systemctl restart "$SERVICE_NAME"

sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Bot restarted successfully!"
    echo ""
    echo "Check logs: journalctl -u $SERVICE_NAME -f"
else
    err "Bot failed to start after update. Check logs:"
    echo "  journalctl -u $SERVICE_NAME -n 30 --no-pager"
    exit 1
fi
