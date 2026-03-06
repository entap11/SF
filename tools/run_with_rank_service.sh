#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_DIR="$ROOT_DIR/tools/rank-service"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required" >&2
  exit 1
fi

if ! command -v godot >/dev/null 2>&1; then
  echo "godot is required in PATH" >&2
  exit 1
fi

if [ ! -d "$SERVICE_DIR/node_modules" ]; then
  echo "installing rank-service dependencies..."
  (cd "$SERVICE_DIR" && npm install >/dev/null)
fi

mkdir -p "$SERVICE_DIR/var"

SERVICE_PORT="${RANK_SERVICE_PORT:-8790}"
SERVICE_HOST="${RANK_SERVICE_HOST:-127.0.0.1}"
SERVICE_STATE_PATH="${RANK_STATE_PATH:-$SERVICE_DIR/var/rank_state.json}"
SERVICE_DATABASE_URL="${RANK_DATABASE_URL:-postgres://postgres:postgres@127.0.0.1:5433/swarmfront_rank}"
SERVICE_LOG_PATH="${RANK_SERVICE_LOG:-$SERVICE_DIR/var/rank_service.log}"
SERVICE_BACKEND_URL="http://$SERVICE_HOST:$SERVICE_PORT/v1/rank"

: > "$SERVICE_LOG_PATH"

(
  cd "$SERVICE_DIR"
  PORT="$SERVICE_PORT" \
  BIND_HOST="$SERVICE_HOST" \
  DATABASE_URL="$SERVICE_DATABASE_URL" \
  RANK_STATE_PATH="$SERVICE_STATE_PATH" \
  npm run dev >>"$SERVICE_LOG_PATH" 2>&1
) &
SERVICE_PID=$!

cleanup() {
  kill "$SERVICE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

sleep 1

if command -v curl >/dev/null 2>&1; then
  HEALTH_URL="http://$SERVICE_HOST:$SERVICE_PORT/health"
  healthy=0
  for _ in $(seq 1 20); do
    if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
      healthy=1
      break
    fi
    sleep 0.25
  done
  if [ "$healthy" -ne 1 ]; then
    echo "rank service failed health check: $HEALTH_URL" >&2
    echo "last service log lines:" >&2
    tail -n 40 "$SERVICE_LOG_PATH" >&2 || true
    exit 1
  fi
fi

echo "rank service started on http://$SERVICE_HOST:$SERVICE_PORT (pid=$SERVICE_PID)"
echo "log: $SERVICE_LOG_PATH"
echo "rank database url: $SERVICE_DATABASE_URL"
echo "rank backend url: $SERVICE_BACKEND_URL"

export SF_RANK_BACKEND_URL="$SERVICE_BACKEND_URL"
if [ -n "${RANK_API_TOKEN:-}" ]; then
  export SF_RANK_BACKEND_TOKEN="$RANK_API_TOKEN"
fi

godot "$@"
