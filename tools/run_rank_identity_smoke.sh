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

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if [ -z "${RANK_DATABASE_URL:-}" ] && [ -z "${DATABASE_URL:-}" ]; then
  echo "RANK_DATABASE_URL or DATABASE_URL is required" >&2
  exit 1
fi

if [ ! -d "$SERVICE_DIR/node_modules" ]; then
  echo "installing rank-service dependencies..."
  (cd "$SERVICE_DIR" && npm install >/dev/null)
fi

mkdir -p "$SERVICE_DIR/var"

SERVICE_PORT="${RANK_SERVICE_PORT:-8790}"
SERVICE_HOST="${RANK_SERVICE_HOST:-127.0.0.1}"
SERVICE_DATABASE_URL="${RANK_DATABASE_URL:-$DATABASE_URL}"
SERVICE_LOG_PATH="${RANK_SERVICE_LOG:-$SERVICE_DIR/var/rank_identity_smoke.log}"
SERVICE_BACKEND_URL="http://$SERVICE_HOST:$SERVICE_PORT/v1/rank"

: > "$SERVICE_LOG_PATH"

(
  cd "$SERVICE_DIR"
  DATABASE_URL="$SERVICE_DATABASE_URL" npm run migrate >>"$SERVICE_LOG_PATH" 2>&1
  PORT="$SERVICE_PORT" \
  BIND_HOST="$SERVICE_HOST" \
  DATABASE_URL="$SERVICE_DATABASE_URL" \
  RANK_API_TOKEN="${RANK_API_TOKEN:-}" \
  RANK_ENABLE_DEBUG_ACTIONS=0 \
  npm run dev >>"$SERVICE_LOG_PATH" 2>&1
) &
SERVICE_PID=$!

cleanup() {
  kill "$SERVICE_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

HEALTH_URL="http://$SERVICE_HOST:$SERVICE_PORT/health"
healthy=0
for _ in $(seq 1 40); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 0.25
done

if [ "$healthy" -ne 1 ]; then
  echo "rank service failed health check: $HEALTH_URL" >&2
  echo "last service log lines:" >&2
  tail -n 80 "$SERVICE_LOG_PATH" >&2 || true
  exit 1
fi

echo "rank identity service started on http://$SERVICE_HOST:$SERVICE_PORT"
echo "log: $SERVICE_LOG_PATH"

(
  cd "$SERVICE_DIR"
  RANK_SMOKE_BASE_URL="$SERVICE_BACKEND_URL" \
  RANK_SMOKE_TOKEN="${RANK_API_TOKEN:-}" \
  npm run smoke:identity
)
