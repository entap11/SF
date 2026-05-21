#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${SOAK_LOG_FILE:-/tmp/swarmfront_soak.log}"
SOAK_SECONDS="${SOAK_SECONDS:-1800}"
ROUND_SECONDS="${SOAK_ROUND_SECONDS:-300}"
PAIR_COUNT="${SOAK_PAIR_COUNT:-2}"
SOAK_MAP="${SOAK_MAP:-MAP_TEST}"
MAX_FRAME_MS="${MAX_FRAME_MS:-45.0}"
MAX_PROCESS_MS="${MAX_PROCESS_MS:-45.0}"
MAX_TICK_MS="${MAX_TICK_MS:-8.0}"
WARMUP_SAMPLES="${SOAK_WARMUP_SAMPLES:-1}"
SIM_PROFILE="${SOAK_SIM_PROFILE:-0}"

if [[ -z "${SOAK_MAP}" ]]; then
  echo "SOAK_GATE_FAIL no soak map provided (set SOAK_MAP or rely on default MAP_TEST)"
  exit 1
fi

echo "Running soak: seconds=${SOAK_SECONDS}, round_seconds=${ROUND_SECONDS}, pairs=${PAIR_COUNT}"
echo "Log: ${LOG_FILE}"
echo "Warmup samples skipped: ${WARMUP_SAMPLES}"

SOAK_PROFILE_ARG=""
if [[ "${SIM_PROFILE}" == "1" || "${SIM_PROFILE}" == "true" ]]; then
  SOAK_PROFILE_ARG="--soak-sim-profile"
fi

set +e
godot --headless --path "${ROOT_DIR}" \
  -- \
  --soak-perf \
  --soak-seconds="${SOAK_SECONDS}" \
  --soak-round-seconds="${ROUND_SECONDS}" \
  --soak-pairs="${PAIR_COUNT}" \
  --soak-map="${SOAK_MAP}" \
  ${SOAK_PROFILE_ARG:+${SOAK_PROFILE_ARG}} >"${LOG_FILE}" 2>&1
GODOT_RC=$?
set -e

python3 - "${LOG_FILE}" "${MAX_FRAME_MS}" "${MAX_PROCESS_MS}" "${MAX_TICK_MS}" "${GODOT_RC}" "${WARMUP_SAMPLES}" <<'PY'
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
max_frame_limit = float(sys.argv[2])
max_process_limit = float(sys.argv[3])
max_tick_limit = float(sys.argv[4])
godot_rc = int(sys.argv[5])
warmup_samples = max(0, int(sys.argv[6]))

if not log_path.exists():
    print(f"SOAK_GATE_FAIL missing log file: {log_path}")
    sys.exit(1)

text = log_path.read_text(errors="replace")
frame_vals = [float(m.group(1)) for m in re.finditer(r"ARENA_FRAME_HEARTBEAT.*max_frame_ms=([0-9]+(?:\.[0-9]+)?)", text)]
process_vals = [float(m.group(1)) for m in re.finditer(r"ARENA_FRAME_HEARTBEAT.*max_process_ms=([0-9]+(?:\.[0-9]+)?)", text)]
engine_process_vals = [float(m.group(1)) for m in re.finditer(r"ARENA_FRAME_HEARTBEAT.*max_engine_process_ms=([0-9]+(?:\.[0-9]+)?)", text)]
renderer_process_vals = [float(m.group(1)) for m in re.finditer(r"RENDER_PROCESS_HEARTBEAT.*max_process_ms=([0-9]+(?:\.[0-9]+)?)", text)]
tick_vals = [float(m.group(1)) for m in re.finditer(r"SIM_HEARTBEAT.*max_tick_ms=([0-9]+(?:\.[0-9]+)?)", text)]
tick_cost_vals = [float(m.group(1)) for m in re.finditer(r"SIM_TICK_COST\s+dt_ms=([0-9]+(?:\.[0-9]+)?)", text)]
if warmup_samples > 0:
    frame_vals = frame_vals[warmup_samples:] if len(frame_vals) > warmup_samples else []
    process_vals = process_vals[warmup_samples:] if len(process_vals) > warmup_samples else []
    engine_process_vals = engine_process_vals[warmup_samples:] if len(engine_process_vals) > warmup_samples else []
    renderer_process_vals = renderer_process_vals[warmup_samples:] if len(renderer_process_vals) > warmup_samples else []
    tick_vals = tick_vals[warmup_samples:] if len(tick_vals) > warmup_samples else []

max_frame = max(frame_vals) if frame_vals else 0.0
max_arena_process = max(process_vals) if process_vals else 0.0
max_engine_process = max(engine_process_vals) if engine_process_vals else 0.0
max_renderer_process = max(renderer_process_vals) if renderer_process_vals else 0.0
max_process = max(max_arena_process, max_renderer_process)
if max_process <= 0.0:
    max_process = max_frame
max_tick_hb = max(tick_vals) if tick_vals else 0.0
max_tick_cost = max(tick_cost_vals) if tick_cost_vals else 0.0
max_tick = max(max_tick_hb, max_tick_cost)

print("SOAK_GATE_SUMMARY")
print(f"  godot_rc={godot_rc}")
print(f"  max_frame_delta_ms={max_frame:.2f} (info limit {max_frame_limit:.2f})")
print(f"  max_process_ms={max_process:.2f} (limit {max_process_limit:.2f})")
print(f"  max_arena_process_ms={max_arena_process:.2f}")
print(f"  max_renderer_process_ms={max_renderer_process:.2f}")
print(f"  max_engine_process_ms={max_engine_process:.2f} (info)")
print(f"  max_tick_ms={max_tick:.2f} (limit {max_tick_limit:.2f})")
print(f"  heartbeat_samples={len(frame_vals)} frame / {len(process_vals)} arena / {len(renderer_process_vals)} renderer / {len(tick_vals)} tick")

failed = False
if godot_rc != 0:
    print("SOAK_GATE_FAIL godot returned non-zero")
    failed = True
if not frame_vals or not process_vals or not renderer_process_vals or not tick_vals:
    print("SOAK_GATE_FAIL missing heartbeat samples")
    failed = True
if max_process > max_process_limit:
    print("SOAK_GATE_FAIL process limit exceeded")
    failed = True
if max_tick > max_tick_limit:
    print("SOAK_GATE_FAIL tick limit exceeded")
    failed = True

if failed:
    sys.exit(1)
print("SOAK_GATE_PASS")
PY
