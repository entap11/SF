#!/usr/bin/env python3
"""Run a reproducible, resumable medium-bot round robin through production SimRunner."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import gzip
import hashlib
import itertools
import json
import os
from pathlib import Path
import queue
import random
import re
import shutil
import subprocess
import time

STYLES = ["balancer", "turtle", "raider", "greedy", "swarm_lord"]
MAPS = ["MAP_centerstrike__CS2__1p", "MAP_centerstrike__CS3__1p",
        "MAP_closequarters__SBASE__1p", "MAP_corridors__SBASE__1p",
        "MAP_nomansland__444__v01_pinched_spine__1p"]
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, data):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def fingerprint(project):
    paths = [project / "project.godot", project / "tools/bot_tournament_runner.gd"]
    for directory in ("scripts", "data", "scenes"):
        paths += [p for p in (project / directory).rglob("*") if p.is_file() and p.suffix in (".gd", ".json", ".tres", ".tscn", ".cfg")]
    paths += [p for p in (project / "maps").rglob("*.json")]
    return {str(p.relative_to(project)): digest(p.read_bytes()) for p in sorted(set(paths))}


def make_workers(project, folder, count):
    workers = []
    for number in range(count):
        worker = folder / "worker_projects" / f"worker-{number + 1:02d}"
        worker.mkdir(parents=True, exist_ok=True)
        for source in project.iterdir():
            if source.name in (".git", "project.godot", "override.cfg"):
                continue
            target = worker / source.name
            if not target.exists():
                target.symlink_to(source, target_is_directory=source.is_dir())
        shutil.copy2(project / "project.godot", worker / "project.godot")
        user_directory = f"SwarmfrontBotBalance/{folder.name}/{worker.name}"
        (worker / "override.cfg").write_text(
            '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="{user_directory}"\n'
            '[debug]\nfile_logging/enable_file_logging=false\n')
        workers.append((worker, user_directory))
    return workers


def validate(payload, job, styles, user_directory):
    if payload["engine"]["hash"] != "a13da4feb8d8aefc283c3763d33a2f170a18d541":
        raise RuntimeError("Evaluation used a different engine build")
    if payload["canonical_tick_ms"] != 100:
        raise RuntimeError("Evaluation used a noncanonical clock")
    if not payload["user_data_dir"].replace("\\", "/").endswith(user_directory):
        raise RuntimeError("Worker did not use its isolated user-data directory")
    rows = payload["results"]
    expected = {(a + ":medium", b + ":medium") for a, b in itertools.permutations(styles, 2)}
    if len(rows) != len(expected) or {(r["a"], r["b"]) for r in rows} != expected:
        raise RuntimeError("Missing or duplicate personality/seat pairings")
    map_hashes = set()
    for row in rows:
        if row["seed"] != job["seed"] or row["map_id"] != job["map"]:
            raise RuntimeError("Wrong map or seed")
        if not row["ok"] or not row["completed"] or row["reason"] not in ("conquest", "time"):
            raise RuntimeError("Incomplete or invalid match outcome")
        if row["active_seats"] != [1, 2] or row["team_by_seat"] != {"1": 1, "2": 2}:
            raise RuntimeError("Expected two independent seats")
        if row["winner_team"] not in (0, 1, 2) or row["pilot_controller"] != "current":
            raise RuntimeError("Invalid winner or controller")
        expected_winner = {0: "", 1: row["a"], 2: row["b"]}[row["winner_team"]]
        if row["winner_profile"] != expected_winner:
            raise RuntimeError("Winner label disagrees with authoritative winner")
        if not 0 < row["sim_ms"] <= 420000 or row["sim_ms"] % 100:
            raise RuntimeError("Invalid canonical match duration")
        if row["reason"] == "time" and row["sim_ms"] not in (300000, 360000):
            raise RuntimeError("Regulation/overtime clock changed")
        if not row["board_samples"] or "last_ownership_change_ms" not in row["diagnostics"]:
            raise RuntimeError("Missing requested behavior diagnostics")
        starts = [e for e in row["trace"] if e["event"] == "started"]
        if len(starts) != 2 or {e["seat"] for e in starts} != {1, 2}:
            raise RuntimeError("A CPU controller did not start")
        for event in starts:
            style = (row["a"] if event["seat"] == 1 else row["b"]).split(":")[0]
            profile = event["profile"]
            if event["seed"] != job["seed"] or profile["style"] != style or profile["tier"] != "medium" or not profile["enabled"]:
                raise RuntimeError("Wrong CPU profile")
            if style == "balancer" and profile.get("policy") != "human_balancer_v3":
                raise RuntimeError("Balancer pilot was not selected")
        for event in row["trace"]:
            if event["event"] != "applied":
                continue
            style = (row["a"] if event["seat"] == 1 else row["b"]).split(":")[0]
            if style == "balancer" and event.get("policy") != "human_balancer_v3":
                raise RuntimeError("Balancer executed another policy")
            if style != "balancer" and str(event.get("policy", "")).startswith("human_"):
                raise RuntimeError("Unexpected human-policy substitution")
        map_hashes.add(row["map_hash"])
    if len(map_hashes) != 1:
        raise RuntimeError("Pairings did not use the same map configuration")


def load_result(path):
    return json.loads(gzip.decompress(path.read_bytes()))


def execute(godot, project, folder, job, worker_info, source_hashes, engine, styles=STYLES):
    worker, user_directory = worker_info
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{job['map']}__seed_{job['seed']}"
    output = folder / f"{name}.json"
    packed = folder / f"{name}.json.gz"
    manifest = folder / f"{name}.manifest.json"
    log = folder / f"{name}.log"
    signature = digest(json.dumps(source_hashes, sort_keys=True).encode())
    if manifest.exists() and packed.exists():
        saved = json.loads(manifest.read_text())
        if saved["source_signature"] != signature or saved["result_sha256"] != digest(packed.read_bytes()) or saved["engine"] != engine:
            raise RuntimeError(f"Stale or modified cached result: {name}")
        validate(load_result(packed), job, styles, saved["user_directory"])
        return saved
    command = [godot, "--headless", "--path", str(worker), "--script", "res://tools/bot_tournament_runner.gd", "--",
               "--styles=" + ",".join(styles), "--tiers=medium", "--variants=1p", "--map-ids=" + job["map"],
               f"--seed={job['seed']}", "--iterations=1", "--duration-ms=420000", "--report-samples", f"--output={output}"]
    started = time.monotonic()
    with log.open("w") as handle:
        process = subprocess.run(command, cwd=project, stdout=handle, stderr=subprocess.STDOUT, timeout=1800)
    text = ANSI.sub("", log.read_text(errors="replace"))
    if process.returncode or re.search(r"(?m)^(ERROR:|SCRIPT ERROR:)", text) or "BOT_TOURNAMENT: COMPLETE" not in text:
        raise RuntimeError(f"Failed job {name}; see {log}")
    payload = json.loads(output.read_text())
    validate(payload, job, styles, user_directory)
    if payload["engine"]["string"] != engine:
        raise RuntimeError("Engine changed during evaluation")
    if fingerprint(project) != source_hashes:
        raise RuntimeError("Frozen source changed during a job")
    packed.write_bytes(gzip.compress(output.read_bytes(), mtime=0))
    output.unlink()
    saved = {"job": job, "games": len(payload["results"]), "engine": engine,
             "source_signature": signature, "result_sha256": digest(packed.read_bytes()),
             "result_path": str(packed), "log_path": str(log), "user_directory": user_directory,
             "command": command, "elapsed_seconds": round(time.monotonic() - started, 2)}
    write_json(manifest, saved)
    return saved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--seeds", type=int, default=20)
    parser.add_argument("--sampling-seed", type=int, default=20260922)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--preflight-only", action="store_true")
    parser.add_argument("--reference", type=Path)
    args = parser.parse_args()
    if not 1 <= args.workers <= 8 or not 1 <= args.seeds <= 1000:
        parser.error("Require 1–8 workers and 1–1000 seeds")
    project, folder = args.project.resolve(), args.artifacts.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    hashes = fingerprint(project)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    # Use the engine's structured version string for comparison with each output.
    engine = "4.7.1-stable (official)"
    if version != "4.7.1.stable.official.a13da4feb":
        raise RuntimeError("This baseline requires the pinned Godot 4.7.1 runtime")
    seeds = random.Random(args.sampling_seed).sample(range(10000, 2147483647), args.seeds)
    jobs = [{"map": map_id, "seed": seed} for seed in seeds for map_id in MAPS]
    plan = {"schema": 1, "styles": STYLES, "tier": "medium", "maps": MAPS, "seeds": seeds,
            "sampling_seed": args.sampling_seed, "planned_games": len(jobs) * 20,
            "project": str(project), "engine": version, "engine_sha256": digest(Path(args.godot).read_bytes()),
            "source_hashes": hashes, "orchestrator_sha256": digest(Path(__file__).read_bytes()),
            "roster": "experimental human_balancer_v3; four existing baseline personas",
            "stalemate_proxy": "time-ended match with no hive ownership change in final 60000 canonical ms"}
    plan_path = folder / "plan.json"
    if plan_path.exists() and json.loads(plan_path.read_text()) != plan:
        raise RuntimeError("Existing plan differs; use a new artifact directory")
    write_json(plan_path, plan)
    workers = make_workers(project, folder, max(2, args.workers))
    preflight_job = {"map": MAPS[0], "seed": 4101}
    preflight = [execute(args.godot, project, folder / f"preflight-{i + 1}", preflight_job,
                         workers[i], hashes, engine, ["balancer", "raider"]) for i in range(2)]
    first, second = [load_result(Path(item["result_path"])) for item in preflight]
    if first["results"] != second["results"]:
        raise RuntimeError("Repeated matches differ across isolated worker user data")
    if args.reference:
        previous = json.loads(args.reference.read_text())["results"]
        comparable = json.loads(json.dumps(first["results"]))
        for row in comparable:
            row["diagnostics"].pop("ownership_changes")
            row["diagnostics"].pop("last_ownership_change_ms")
            row.pop("board_samples")
        for row in previous:
            row.pop("board_samples")
        if comparable != previous:
            raise RuntimeError("Evaluation diagnostics or isolated user data changed the previous gameplay/traces")
    write_json(folder / "preflight.json", {"passed": True, "repeated_matches": 2,
               "isolated_user_directories": [item["user_directory"] for item in preflight],
               "reference_matched": bool(args.reference), "result_hashes": [item["result_sha256"] for item in preflight]})
    print("PREFLIGHT PASS: exact repeated gameplay/traces across isolated workers", flush=True)
    if args.preflight_only:
        return
    available = queue.Queue()
    for worker in workers[:args.workers]:
        available.put(worker)

    def task(job):
        worker = available.get()
        try:
            return execute(args.godot, project, folder / "jobs", job, worker, hashes, engine)
        finally:
            available.put(worker)

    completion = folder / "completion.json"
    completion.unlink(missing_ok=True)
    started = time.monotonic()
    done = []
    print(f"ROUND_ROBIN START: {len(jobs)} batches, {plan['planned_games']} games, {args.workers} workers", flush=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(task, job) for job in jobs]
        try:
            for future in as_completed(futures):
                done.append(future.result())
                progress = {"completed_games": sum(r["games"] for r in done), "planned_games": plan["planned_games"],
                            "completed_batches": len(done), "elapsed_seconds": round(time.monotonic() - started, 1)}
                write_json(folder / "progress.json", progress)
                print("ROUND_ROBIN PROGRESS " + json.dumps(progress), flush=True)
        except BaseException:
            for future in futures:
                future.cancel()
            raise
    if fingerprint(project) != hashes or sum(r["games"] for r in done) != plan["planned_games"]:
        raise RuntimeError("Source or final coverage mismatch")
    if len({(r["job"]["map"], r["job"]["seed"]) for r in done}) != len(jobs):
        raise RuntimeError("Missing or duplicate batches")
    write_json(completion, {"passed": True, "games": plan["planned_games"], "batches": len(done),
                           "plan_sha256": digest(plan_path.read_bytes()), "elapsed_seconds": round(time.monotonic() - started, 1),
                           "results": sorted(done, key=lambda r: (r["job"]["map"], r["job"]["seed"]))})
    print(f"ROUND_ROBIN PASS: {plan['planned_games']} validated complete matches", flush=True)


if __name__ == "__main__":
    main()
