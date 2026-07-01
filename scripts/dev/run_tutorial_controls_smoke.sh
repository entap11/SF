#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_FILE="${TUTORIAL_CONTROLS_SMOKE_LOG_FILE:-/tmp/swarmfront_tutorial_controls_smoke.log}"
BOOT_TIMEOUT_MS="${TUTORIAL_CONTROLS_SMOKE_BOOT_TIMEOUT_MS:-7000}"
RUN_TIMEOUT_MS="${TUTORIAL_CONTROLS_SMOKE_RUN_TIMEOUT_MS:-12000}"
END_TIMEOUT_MS="${TUTORIAL_CONTROLS_SMOKE_END_TIMEOUT_MS:-25000}"

set +e
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" \
  -- \
  --mvp-smoke \
  --mvp-tutorial-controls-smoke \
  --mvp-boot-timeout-ms="${BOOT_TIMEOUT_MS}" \
  --mvp-run-timeout-ms="${RUN_TIMEOUT_MS}" \
  --mvp-end-timeout-ms="${END_TIMEOUT_MS}" >"${LOG_FILE}" 2>&1
RC=$?
set -e

echo "Tutorial controls smoke log: ${LOG_FILE}"
tail -n 100 "${LOG_FILE}" || true
exit "${RC}"
