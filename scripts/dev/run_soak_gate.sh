#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${SOAK_LOG_FILE:-/tmp/swarmfront_soak.log}"
SOAK_SECONDS="${SOAK_SECONDS:-1800}"
ROUND_SECONDS="${SOAK_ROUND_SECONDS:-300}"
PAIR_COUNT="${SOAK_PAIR_COUNT:-2}"
SOAK_MAP="${SOAK_MAP:-}"
MAX_FRAME_MS="${MAX_FRAME_MS:-45.0}"
MAX_TICK_MS="${MAX_TICK_MS:-8.0}"

if [[ -z "${SOAK_MAP}" ]]; then
  FIRST_JSON="$(ls "${ROOT_DIR}"/maps/json/*.json 2>/dev/null | sort | head -n 1 || true)"
  if [[ -n "${FIRST_JSON}" ]]; then
    SOAK_MAP="res://${FIRST_JSON#${ROOT_DIR}/}"
  fi
fi

if [[ -z "${SOAK_MAP}" ]]; then
  echo "SOAK_GATE_FAIL no map found under ${ROOT_DIR}/maps/json and SOAK_MAP not provided"
  exit 1
fi

echo "Running soak: seconds=${SOAK_SECONDS}, round_seconds=${ROUND_SECONDS}, pairs=${PAIR_COUNT}"
echo "Log: ${LOG_FILE}"

set +e
godot --headless --path "${ROOT_DIR}" \
  --script scripts/dev/soak_perf_runner.gd -- \
  --seconds="${SOAK_SECONDS}" \
  --round-seconds="${ROUND_SECONDS}" \
  --pairs="${PAIR_COUNT}" \
  --map="${SOAK_MAP}" >"${LOG_FILE}" 2>&1
GODOT_RC=$?
set -e

python3 - "${LOG_FILE}" "${MAX_FRAME_MS}" "${MAX_TICK_MS}" "${GODOT_RC}" <<'PY'
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
max_frame_limit = float(sys.argv[2])
max_tick_limit = float(sys.argv[3])
godot_rc = int(sys.argv[4])

if not log_path.exists():
    print(f"SOAK_GATE_FAIL missing log file: {log_path}")
    sys.exit(1)

text = log_path.read_text(errors="replace")
frame_vals = [float(m.group(1)) for m in re.finditer(r"ARENA_FRAME_HEARTBEAT.*max_frame_ms=([0-9]+(?:\\.[0-9]+)?)", text)]
tick_vals = [float(m.group(1)) for m in re.finditer(r"SIM_HEARTBEAT.*max_tick_ms=([0-9]+(?:\\.[0-9]+)?)", text)]
tick_cost_vals = [float(m.group(1)) for m in re.finditer(r"SIM_TICK_COST\\s+dt_ms=([0-9]+(?:\\.[0-9]+)?)", text)]

max_frame = max(frame_vals) if frame_vals else 0.0
max_tick_hb = max(tick_vals) if tick_vals else 0.0
max_tick_cost = max(tick_cost_vals) if tick_cost_vals else 0.0
max_tick = max(max_tick_hb, max_tick_cost)

print("SOAK_GATE_SUMMARY")
print(f"  godot_rc={godot_rc}")
print(f"  max_frame_ms={max_frame:.2f} (limit {max_frame_limit:.2f})")
print(f"  max_tick_ms={max_tick:.2f} (limit {max_tick_limit:.2f})")
print(f"  heartbeat_samples={len(frame_vals)} frame / {len(tick_vals)} tick")

failed = False
if godot_rc != 0:
    print("SOAK_GATE_FAIL godot returned non-zero")
    failed = True
if not frame_vals or not tick_vals:
    print("SOAK_GATE_FAIL missing heartbeat samples")
    failed = True
if max_frame > max_frame_limit:
    print("SOAK_GATE_FAIL frame limit exceeded")
    failed = True
if max_tick > max_tick_limit:
    print("SOAK_GATE_FAIL tick limit exceeded")
    failed = True

if failed:
    sys.exit(1)
print("SOAK_GATE_PASS")
PY
