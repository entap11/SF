#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${SOAK_LOG_FILE:-/tmp/swarmfront_soak.log}"
SOAK_SECONDS="${SOAK_SECONDS:-1800}"
ROUND_SECONDS="${SOAK_ROUND_SECONDS:-300}"
PAIR_COUNT="${SOAK_PAIR_COUNT:-2}"
SOAK_MAP="${SOAK_MAP:-MAP_TEST}"
MAX_FRAME_MS="${MAX_FRAME_MS:-45.0}"
MAX_TICK_MS="${MAX_TICK_MS:-8.0}"
WARMUP_SAMPLES="${SOAK_WARMUP_SAMPLES:-1}"

if [[ -z "${SOAK_MAP}" ]]; then
  echo "SOAK_GATE_FAIL no soak map provided (set SOAK_MAP or rely on default MAP_TEST)"
  exit 1
fi

echo "Running soak: seconds=${SOAK_SECONDS}, round_seconds=${ROUND_SECONDS}, pairs=${PAIR_COUNT}"
echo "Log: ${LOG_FILE}"
echo "Warmup samples skipped: ${WARMUP_SAMPLES}"

set +e
godot --headless --path "${ROOT_DIR}" \
  -- \
  --soak-perf \
  --soak-seconds="${SOAK_SECONDS}" \
  --soak-round-seconds="${ROUND_SECONDS}" \
  --soak-pairs="${PAIR_COUNT}" \
  --soak-map="${SOAK_MAP}" >"${LOG_FILE}" 2>&1
GODOT_RC=$?
set -e

python3 - "${LOG_FILE}" "${MAX_FRAME_MS}" "${MAX_TICK_MS}" "${GODOT_RC}" "${WARMUP_SAMPLES}" <<'PY'
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
max_frame_limit = float(sys.argv[2])
max_tick_limit = float(sys.argv[3])
godot_rc = int(sys.argv[4])
warmup_samples = max(0, int(sys.argv[5]))

if not log_path.exists():
    print(f"SOAK_GATE_FAIL missing log file: {log_path}")
    sys.exit(1)

text = log_path.read_text(errors="replace")
frame_vals = [float(m.group(1)) for m in re.finditer(r"ARENA_FRAME_HEARTBEAT.*max_frame_ms=([0-9]+(?:\\.[0-9]+)?)", text)]
tick_vals = [float(m.group(1)) for m in re.finditer(r"SIM_HEARTBEAT.*max_tick_ms=([0-9]+(?:\\.[0-9]+)?)", text)]
tick_cost_vals = [float(m.group(1)) for m in re.finditer(r"SIM_TICK_COST\\s+dt_ms=([0-9]+(?:\\.[0-9]+)?)", text)]
if warmup_samples > 0:
    frame_vals = frame_vals[warmup_samples:] if len(frame_vals) > warmup_samples else []
    tick_vals = tick_vals[warmup_samples:] if len(tick_vals) > warmup_samples else []

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
