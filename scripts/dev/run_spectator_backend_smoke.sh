#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
PORT="${SPECTATOR_SMOKE_PORT:-8791}"
TOKEN="${SPECTATOR_SMOKE_TOKEN:-spectator_backend_smoke_token}"
LOG_FILE="${SPECTATOR_SMOKE_LOG_FILE:-/tmp/swarmfront_spectator_backend_smoke.log}"
VS_LOG_FILE="${SPECTATOR_SMOKE_VS_LOG_FILE:-/tmp/swarmfront_spectator_vs_service.log}"
BACKEND_URL="http://127.0.0.1:${PORT}/v1"
SERVER_PID=""

cleanup() {
  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" >/dev/null 2>&1; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
    wait "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "${ROOT_DIR}/tools/vs-service"
PORT="${PORT}" \
BIND_HOST="127.0.0.1" \
VS_SPECTATOR_ADMIN_TOKEN="${TOKEN}" \
VS_SPECTATOR_LIVE_ENABLED="1" \
npx tsx src/server.ts >"${VS_LOG_FILE}" 2>&1 &
SERVER_PID="$!"

for _i in $(seq 1 80); do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
  echo "VS service failed to start. Log: ${VS_LOG_FILE}" >&2
  tail -n 80 "${VS_LOG_FILE}" >&2 || true
  exit 1
fi

cd "${ROOT_DIR}"
set +e
SF_VS_BACKEND_URL="${BACKEND_URL}" \
SF_VS_BACKEND_TOKEN="${TOKEN}" \
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "res://tools/spectator_ops_console_backend_smoke_test.gd" >"${LOG_FILE}" 2>&1
RC=$?
set -e

echo "Spectator backend smoke log: ${LOG_FILE}"
tail -n 80 "${LOG_FILE}" || true
echo "VS service log: ${VS_LOG_FILE}"
tail -n 20 "${VS_LOG_FILE}" || true
exit "${RC}"
