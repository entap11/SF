#!/usr/bin/env python3
"""Paired v1/current pilot evaluation with fixed maps, opponents, seeds and clocks."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MAPS = ["MAP_centerstrike__CS2__1p", "MAP_closequarters__SBASE__1p", "MAP_corridors__SBASE__1p"]
OPPONENTS = ["raider", "turtle", "greedy"]
SEED = 4101
ITERATIONS = 2
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SOURCES = ["tools/fixtures/bot/human_balancer_v1.gd", "scripts/bot/human_bot_policy.gd",
           "scripts/bot/bot_observation.gd", "scripts/systems/bot_system.gd",
           "scripts/systems/sim_runner.gd", "scripts/ops/ops_state.gd",
           "tools/bot_tournament_runner.gd", "tools/run_bot_calibration.py"]


def source_hashes():
    return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in SOURCES}


def key(row):
    return row["map_id"], row["a"], row["b"], row["seed"]


def evaluate(godot, folder, arm):
    hashes = source_hashes()
    manifest = folder / f"{arm}_manifest.json"
    manifest.unlink(missing_ok=True)
    (folder / "comparison.json").unlink(missing_ok=True)
    output = folder / f"{arm}_final.json"
    output.unlink(missing_ok=True)
    log = folder / f"{arm}_final.log"
    args = [godot, "--headless", "--path", str(ROOT), "--script", "res://tools/bot_tournament_runner.gd", "--",
            "--styles=balancer," + ",".join(OPPONENTS), "--focus-style=balancer", "--variants=1p",
            "--map-ids=" + ",".join(MAPS), f"--iterations={ITERATIONS}", f"--seed={SEED}",
            "--report-samples", f"--output={output}"]
    if arm == "control":
        args.append("--pilot-control")
    with log.open("w") as handle:
        process = subprocess.run(args, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT, timeout=1200)
    content = ANSI.sub("", log.read_text(errors="replace"))
    if process.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", content) or "BOT_TOURNAMENT: COMPLETE" not in content:
        raise RuntimeError(f"{arm} failed; see {log}")
    payload = json.loads(output.read_text())
    expected = {(m, a + ":medium", b + ":medium", s)
                for m in MAPS for opponent in OPPONENTS
                for a, b in [("balancer", opponent), (opponent, "balancer")]
                for s in range(SEED, SEED + ITERATIONS)}
    if {key(row) for row in payload["results"]} != expected or len(payload["results"]) != len(expected):
        raise RuntimeError(f"{arm} silently omitted or duplicated requested matchups")
    if any(not row["completed"] for row in payload["results"]):
        raise RuntimeError(f"{arm} contains incomplete matches; do not count them as completed results")
    expected_controller = "v1_control" if arm == "control" else "current"
    if any(row["pilot_controller"] != expected_controller for row in payload["results"]):
        raise RuntimeError(f"{arm} ran the wrong pilot controller")
    if source_hashes() != hashes:
        raise RuntimeError(f"Source changed during {arm}; rerun against a fixed revision")
    manifest.write_text(json.dumps({"source_hashes": hashes, "result_sha256": hashlib.sha256(output.read_bytes()).hexdigest()}, indent=2) + "\n")
    print(f"PASS {arm}: {len(expected)} completed matches", flush=True)


def summarize(rows):
    counts = Counter()
    by_map = defaultdict(Counter)
    by_opponent = defaultdict(Counter)
    timing = []
    early_idle = early_owned = 0
    early_used = early_budget = 0
    early_actions = 0
    goals = Counter()
    rejections = Counter()
    rejections_by_map = defaultdict(Counter)
    for row in rows:
        seat = 1 if row["a"] == "balancer:medium" else 2
        opponent = row["b"] if seat == 1 else row["a"]
        result = "win" if row["winner_profile"] == "balancer:medium" else ("draw" if row["winner_team"] == 0 else "loss")
        counts[result] += 1
        by_map[row["map_id"]][result] += 1
        by_opponent[opponent][result] += 1
        for event in row["trace"]:
            if event["seat"] != seat:
                continue
            if event["event"] == "applied":
                goals[event.get("goal", "unknown")] += 1
                if event["sim_ms"] <= 60000:
                    early_actions += 1
            if event["event"] == "rejected":
                reason = event.get("reason", "unknown")
                rejections[reason] += 1
                rejections_by_map[row["map_id"]][reason] += 1
            if event["event"] == "scheduled":
                timing.append(event["execute_ms"] - event["observed_ms"])
        for sample in row["board_samples"]:
            if sample["sim_ms"] > 60000:
                continue
            owned = [h for h in sample["hives"] if h["owner"] == seat]
            early_owned += len(owned)
            early_idle += sum(h["outgoing"] == 0 and h["power"] >= 10 for h in owned)
            early_used += sum(h["outgoing"] for h in owned)
            early_budget += sum(h["budget"] for h in owned)
    return {"results": dict(counts), "by_map": dict(by_map), "by_opponent": dict(by_opponent),
            "goals": dict(goals), "first_minute_actions_per_match": early_actions / max(1, len(rows)),
            "rejected_commands": dict(rejections), "rejections_by_map": dict(rejections_by_map),
            "rejected_command_fraction": sum(rejections.values()) / max(1, sum(goals.values()) + sum(rejections.values())),
            "defensive_action_fraction": goals["defend"] / max(1, sum(goals.values())),
            "first_minute_idle_productive_hive_fraction": early_idle / max(1, early_owned),
            "first_minute_lane_utilization": early_used / max(1, early_budget),
            "minimum_scheduled_observation_to_execution_ms": min(timing, default=None)}


def compare(folder):
    paths = [folder / f"{arm}_final.json" for arm in ("control", "candidate")]
    if not all(path.exists() for path in paths):
        raise RuntimeError("Both evaluation arms must finish before comparison")
    manifests = [json.loads((folder / f"{arm}_manifest.json").read_text()) for arm in ("control", "candidate")]
    for path, manifest in zip(paths, manifests):
        if hashlib.sha256(path.read_bytes()).hexdigest() != manifest["result_sha256"]:
            raise RuntimeError("Evaluation output changed after validation")
    if manifests[0]["source_hashes"] != manifests[1]["source_hashes"]:
        raise RuntimeError("Control and candidate were evaluated against different source revisions")
    control, candidate = [json.loads(path.read_text())["results"] for path in paths]
    if {key(row) for row in control} != {key(row) for row in candidate}:
        raise RuntimeError("Control/candidate schedules differ")
    old = {key(row): row for row in control}
    for row in candidate:
        previous = old[key(row)]
        if previous["map_hash"] != row["map_hash"] or previous["team_by_seat"] != row["team_by_seat"]:
            raise RuntimeError("Control/candidate map or team configuration differs")
        # Tactical fixes must not gain their advantage by thinking or acting faster.
        for seat, profile in previous["profiles"].items():
            current = row["profiles"][seat]
            for field in ("human_timing", "opening_delay_ms", "opening_stagger_ms"):
                if profile.get(field) != current.get(field):
                    raise RuntimeError(f"Timing changed: {field}")
    report = {"maps": MAPS, "opponents": OPPONENTS, "seeds": list(range(SEED, SEED + ITERATIONS)),
              "control": summarize(control), "candidate": summarize(candidate),
              "source_hashes": manifests[0]["source_hashes"],
              "report_source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (folder / "comparison.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--arm", choices=["control", "candidate", "both", "compare"], default="both")
    parser.add_argument("--artifacts", type=Path, default=ROOT / "artifacts/bot-calibration")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    options = parser.parse_args()
    folder = options.artifacts.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    for arm in (["control", "candidate"] if options.arm == "both" else ([] if options.arm == "compare" else [options.arm])):
        evaluate(options.godot, folder, arm)
    if options.arm in ("both", "compare"):
        compare(folder)


if __name__ == "__main__":
    main()
