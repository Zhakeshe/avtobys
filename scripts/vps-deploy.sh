#!/usr/bin/env bash
# VPS-те репо түбінен іске қосыңыз: bash scripts/vps-deploy.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/avtobys-web/backend"

cd "$REPO_ROOT"
git pull --ff-only

cd "$BACKEND_DIR"
if [[ ! -f .env ]]; then
  echo "Қате: $BACKEND_DIR/.env жоқ. Алдымен .env.example көшіріп толтырыңыз."
  exit 1
fi

npm ci --omit=dev

if pm2 describe avtobys-backend >/dev/null 2>&1; then
  pm2 reload ecosystem.config.cjs --update-env
else
  pm2 start ecosystem.config.cjs
fi

pm2 save
echo "Бэкенд жаңартылды. Flutter web статикасын жаңалағанда build/web → $BACKEND_DIR/public/ көшіріңіз."
