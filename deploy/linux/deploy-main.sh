#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="/opt/indgas-express"
SOURCE_DIR="$APP_ROOT/source"
API_DIR="$APP_ROOT/api"
WEB_DIR="/var/www/express/build/web"
WEB_RELEASES_DIR="/var/www/express/releases"
INCOMING_DIR="/home/gitdeploy/incoming"
GIT_DIR="/var/repo/site.git"
SERVICE_NAME="indgas-express-api.service"
LOG_PREFIX="[indgas-deploy]"

MODE="backend-only"
WEB_ARCHIVE=""

wait_for_health() {
  local url="$1"
  local attempts="${2:-15}"
  local pause="${3:-1}"

  for ((i = 1; i <= attempts; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$pause"
  done

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-only)
      MODE="backend-only"
      shift
      ;;
    --web-archive)
      MODE="with-web"
      WEB_ARCHIVE="${2:-}"
      if [[ -z "$WEB_ARCHIVE" ]]; then
        echo "$LOG_PREFIX missing archive path after --web-archive" >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "$LOG_PREFIX unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

umask 002

echo "$LOG_PREFIX starting deploy ($MODE)"

mkdir -p "$SOURCE_DIR" "$API_DIR" "$WEB_DIR" "$WEB_RELEASES_DIR" "$INCOMING_DIR"

echo "$LOG_PREFIX checkout source"
git --work-tree="$SOURCE_DIR" --git-dir="$GIT_DIR" checkout -f main

echo "$LOG_PREFIX sync backend"
rsync -r --delete --omit-dir-times --no-perms --no-owner --no-group \
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

if [[ "$MODE" == "with-web" ]]; then
  if [[ ! -f "$WEB_ARCHIVE" ]]; then
    echo "$LOG_PREFIX web archive not found: $WEB_ARCHIVE" >&2
    exit 1
  fi

  echo "$LOG_PREFIX unpack web archive"
  ts="$(date +%Y%m%d%H%M%S)"
  if [[ -d "$WEB_DIR" && -w "$WEB_RELEASES_DIR" ]]; then
    rm -rf "$WEB_RELEASES_DIR/web-$ts"
    mkdir -p "$WEB_RELEASES_DIR"
    cp -a "$WEB_DIR" "$WEB_RELEASES_DIR/web-$ts"
  elif [[ -d "$WEB_DIR" ]]; then
    echo "$LOG_PREFIX skip backup copy: $WEB_RELEASES_DIR is not writable"
  fi

  rm -rf "$WEB_DIR"
  mkdir -p "$WEB_DIR"
  tar -xzf "$WEB_ARCHIVE" -C "$WEB_DIR"
  rm -f "$WEB_ARCHIVE"
fi

echo "$LOG_PREFIX restart backend"
sudo systemctl restart "$SERVICE_NAME"

echo "$LOG_PREFIX health check"
wait_for_health "http://127.0.0.1:8787/api/health"
wait_for_health "https://express.indgas.ru/api/health"

echo "$LOG_PREFIX deploy completed"
