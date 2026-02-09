#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${MVP_SMOKE_LOG_FILE:-/tmp/swarmfront_mvp_smoke.log}"
SMOKE_MAP="${MVP_SMOKE_MAP:-}"
SMOKE_WIN_MAP="${MVP_SMOKE_WIN_MAP:-}"
BOOT_TIMEOUT_MS="${MVP_SMOKE_BOOT_TIMEOUT_MS:-7000}"
RUN_TIMEOUT_MS="${MVP_SMOKE_RUN_TIMEOUT_MS:-12000}"
END_TIMEOUT_MS="${MVP_SMOKE_END_TIMEOUT_MS:-25000}"

set +e
godot --headless --path "${ROOT_DIR}" \
  -- \
  --mvp-smoke \
  --mvp-boot-timeout-ms="${BOOT_TIMEOUT_MS}" \
  --mvp-run-timeout-ms="${RUN_TIMEOUT_MS}" \
  --mvp-end-timeout-ms="${END_TIMEOUT_MS}" \
  ${SMOKE_WIN_MAP:+--mvp-win-map="${SMOKE_WIN_MAP}"} \
  ${SMOKE_MAP:+--mvp-map="${SMOKE_MAP}"} >"${LOG_FILE}" 2>&1
RC=$?
set -e

echo "MVP smoke log: ${LOG_FILE}"
tail -n 80 "${LOG_FILE}" || true
exit "${RC}"
