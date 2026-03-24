#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/indgas-express"
SOURCE_DIR="$APP_ROOT/source"
API_DIR="$APP_ROOT/api"
WEB_DIR="/var/www/express/build/web"
GIT_DIR="/var/repo/site.git"
FLUTTER_DIR="/opt/flutter"
SERVICE_NAME="indgas-express-api.service"
LOG_PREFIX="[indgas-deploy]"

umask 002

echo "$LOG_PREFIX starting deploy from main"

mkdir -p "$SOURCE_DIR" "$API_DIR" "$WEB_DIR"

echo "$LOG_PREFIX checkout source"
git --work-tree="$SOURCE_DIR" --git-dir="$GIT_DIR" checkout -f main

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "$LOG_PREFIX flutter build web"
pushd "$SOURCE_DIR" >/dev/null
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=/api --no-wasm-dry-run
popd >/dev/null

echo "$LOG_PREFIX sync backend"
rsync -a --delete \
  --exclude=".env" \
  --exclude="data/store.json" \
  "$SOURCE_DIR/server/" "$API_DIR/"

if [[ ! -f "$API_DIR/.env" && -f "$API_DIR/.env.example" ]]; then
  cp "$API_DIR/.env.example" "$API_DIR/.env"
fi

if grep -q '^APP_SECRET=change-me-for-production$' "$API_DIR/.env" 2>/dev/null; then
  secret="$(openssl rand -hex 32)"
  sed -i "s/^APP_SECRET=.*/APP_SECRET=$secret/" "$API_DIR/.env"
fi

echo "$LOG_PREFIX sync web bundle"
rsync -a --delete "$SOURCE_DIR/build/web/" "$WEB_DIR/"

echo "$LOG_PREFIX restart backend"
sudo systemctl restart "$SERVICE_NAME"

echo "$LOG_PREFIX health check"
curl -fsS http://127.0.0.1:8787/api/health >/dev/null
curl -fsSI https://express.indgas.ru/api/health >/dev/null

echo "$LOG_PREFIX deploy completed"
