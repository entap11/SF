#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "${ROOT_DIR}" "${GODOT_BIN:-godot}" "${LANE_GRAB_LOG_DIR:-/tmp/swarmfront_lane_grab_regression}" <<'PY'
import pathlib
import re
import subprocess
import sys

root, godot, log_dir = sys.argv[1:]
logs = pathlib.Path(log_dir)
logs.mkdir(parents=True, exist_ok=True)
tests = {
    "lane_grab_gesture": "LANE_GRAB_GESTURE_SMOKE: PASS",
    "lane_grab_throw_presentation": "LANE_GRAB_THROW_PRESENTATION_SMOKE: PASS",
    "input_controls": "INPUT_CONTROLS_SMOKE: PASS",
    "combat_readability": "COMBAT_READABILITY_SMOKE: PASS",
    "battlefield_screen_angle_input": "BATTLEFIELD_SCREEN_ANGLE_INPUT_SMOKE: PASS",
}
for name, marker in tests.items():
    path = logs / (name + ".log")
    with path.open("w") as output:
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", root, "--script", f"tools/{name}_smoke_test.gd"],
                stdout=output, stderr=subprocess.STDOUT, timeout=120, check=False,
            )
        except (subprocess.TimeoutExpired, OSError) as error:
            print(f"LANE_GRAB_REGRESSION: FAIL {name}: {error}; log={path}", flush=True)
            sys.exit(1)
    text = re.sub(r"\x1b\[[0-9;]*m", "", path.read_text(errors="replace"))
    if result.returncode or marker not in text or "ERROR:" in text:
        print(f"LANE_GRAB_REGRESSION: FAIL {name}; log={path}\n{text[-6000:]}", flush=True)
        sys.exit(1)
    print(f"LANE_GRAB_REGRESSION: PASS {name}; log={path}", flush=True)
print("LANE_GRAB_REGRESSION: PASS all five checks", flush=True)
PY
