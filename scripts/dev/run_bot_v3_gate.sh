#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_FILE="${BOT_V3_GATE_LOG_FILE:-/tmp/swarmfront_bot_v3_gate.log}"

gates=(
  tools/bot_runtime_contract_smoke_test.gd
  tools/bot_style_separation_smoke_test.gd
  tools/adaptive_bot_v3_smoke_test.gd
  tools/bot_v3_certification_gate.gd
)

: >"${LOG_FILE}"
for gate in "${gates[@]}"; do
  gate_log="$(mktemp /tmp/swarmfront_bot_v3_gate.XXXXXX.log)"
  echo "BOT_V3_GATE_BEGIN ${gate}" | tee -a "${LOG_FILE}"
  set +e
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "res://${gate}" 2>&1 \
    | tee -a "${LOG_FILE}" \
    | tee "${gate_log}"
  gate_rc=${PIPESTATUS[0]}
  set -e
  script_error=0
  if grep -Eq "SCRIPT ERROR|Parse Error|Compile Error|Failed to load script" "${gate_log}"; then
    script_error=1
  fi
  rm -f "${gate_log}"
  if [[ "${gate_rc}" -ne 0 || "${script_error}" -ne 0 ]]; then
    echo "BOT_V3_GATE_FAIL ${gate} rc=${gate_rc}" | tee -a "${LOG_FILE}"
    if [[ "${gate_rc}" -ne 0 ]]; then
      exit "${gate_rc}"
    fi
    exit 1
  fi
  echo "BOT_V3_GATE_PASS ${gate}" | tee -a "${LOG_FILE}"
done

echo "BOT_V3_GATE_COMPLETE count=${#gates[@]}" | tee -a "${LOG_FILE}"
