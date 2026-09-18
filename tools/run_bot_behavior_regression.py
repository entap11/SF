#!/usr/bin/env python3
"""Run behavior contracts and repeat canonical matches; retain reviewable artifacts."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SMOKES = [
    ("bot_runtime_smoke_test", "BOT_RUNTIME_SMOKE: PASS"),
    ("bot_style_separation_smoke_test", "BOT_STYLE_SEPARATION_SMOKE: PASS"),
    ("progressive_bot_grace_smoke_test", "PROGRESSIVE_BOT_GRACE_SMOKE: PASS"),
    ("match_telemetry_hooks_smoke_test", "MATCH_TELEMETRY_HOOKS_SMOKE: PASS"),
    ("player_telemetry_report_smoke_test", "PLAYER_TELEMETRY_REPORT_SMOKE: PASS"),
    ("authoritative_buff_state_smoke_test", "AUTHORITATIVE_BUFF_STATE_SMOKE: PASS"),
]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def run(godot, artifacts, name, script, args=(), marker=None, expected_rc=0):
    log = artifacts / f"{name}.log"
    command = [godot, "--headless", "--path", str(ROOT), "--script", f"res://tools/{script}.gd"]
    if args:
        command += ["--", *args]
    with log.open("w") as output:
        process = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=180)
    content = ANSI.sub("", log.read_text(errors="replace"))
    if process.returncode != expected_rc or (marker and marker not in content):
        raise RuntimeError(f"{name} failed (exit {process.returncode}); see {log}")
    if expected_rc == 0 and re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", content):
        raise RuntimeError(f"{name} logged an engine/script error despite its exit code; see {log}")
    print(f"PASS {name}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--artifacts", type=Path, default=ROOT / "artifacts/bot-behavior-regression")
    options = parser.parse_args()
    artifacts = options.artifacts.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    # A failed rerun must not leave a stale success summary.
    summary = artifacts / "summary.json"
    summary.unlink(missing_ok=True)
    for script, marker in SMOKES:
        run(options.godot, artifacts, script, script, marker=marker)
    common = ["--styles=balancer,raider", "--variants=1p", "--max-maps=1", "--max-pairs=2", "--seed=4101"]
    runs = []
    for number in (1, 2):
        output = artifacts / f"tournament_{number}.json"
        output.unlink(missing_ok=True)
        run(options.godot, artifacts, f"tournament_{number}", "bot_tournament_runner", [*common, "--duration-ms=420000", f"--output={output}"], marker="BOT_TOURNAMENT: COMPLETE")
        runs.append(json.loads(output.read_text()))
    if runs[0] != runs[1]:
        raise RuntimeError("Repeated canonical tournaments differ; compare tournament_1.json and tournament_2.json")
    results = runs[0]["results"]
    if len(results) != 2 or any(not row["completed"] or not row["trace"] for row in results):
        raise RuntimeError("Canonical tournament did not finish both seat-swapped matches with real CPU decisions")
    if not any(event.get("policy") == "human_balancer_v2" and event["event"] == "applied" for row in results for event in row["trace"]):
        raise RuntimeError("Canonical tournament never exercised the human-behavior pilot")
    print("PASS repeated canonical match results and decision traces", flush=True)
    horizon = artifacts / "horizon.json"
    horizon.unlink(missing_ok=True)
    run(options.godot, artifacts, "horizon", "bot_tournament_runner", [*common, "--max-pairs=1", "--duration-ms=1000", f"--output={horizon}"], marker="BOT_TOURNAMENT: COMPLETE games=0 skipped=1")
    row = json.loads(horizon.read_text())["results"][0]
    if row["completed"] or row["reason"] != "horizon_limit" or row["diagnostics"]["timeout_or_draw"]:
        raise RuntimeError("An unfinished evaluation was presented as a completed match")
    run(options.godot, artifacts, "reject_scaled_clock", "bot_tournament_runner", ["--timing-scale=0.08"], expected_rc=2)
    summary.write_text(json.dumps({"passed": True, "smokes": [item[0] for item in SMOKES], "identical_repeated_matches": len(results), "seed": 4101, "engine": runs[0]["engine"]}, indent=2) + "\n")
    print(f"BOT_BEHAVIOR_REGRESSION: PASS — artifacts: {artifacts}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.TimeoutExpired, OSError, ValueError) as error:
        print(f"BOT_BEHAVIOR_REGRESSION: FAIL — {error}", file=sys.stderr)
        sys.exit(1)
