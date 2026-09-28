#!/usr/bin/env python3
"""Retrieve only the bot-playtest recordings from a paired development iPhone."""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    destination = args.output / "recordings"
    result = subprocess.run([
        "xcrun", "devicectl", "device", "copy", "from", "--device", args.device,
        "--domain-type", "appDataContainer", "--domain-identifier", "com.matthew.swarmfront",
        "--source", "Documents/bot_evaluation", "--destination", str(destination),
        "--json-output", str(args.output / "transfer.json"),
    ])
    if result.returncode:
        raise SystemExit("No recordings retrieved. The folder is created after a game's first checkpoint (15 seconds); check the device connection and transfer.json before retrying.")
    rows = []
    for file in sorted(destination.rglob("*.json")):
        data = json.loads(file.read_text())
        metadata = data.get("metadata", {})
        evaluation = metadata.get("bot_evaluation", {})
        if not evaluation:
            continue
        events = data.get("events", [])
        starts = [event for event in events if event.get("k") == "bot_started"]
        profiles = [event.get("profile", {}) for event in starts]
        expected = evaluation["expected_policy"]
        rows.append({
            "file": str(file), "run_id": evaluation["run_id"],
            "opponent": evaluation["style"], "completed": evaluation["completed"],
            "sim_ms": metadata.get("recorded_sim_ms", 0),
            "build": evaluation["build"], "source_sha256": evaluation.get("source", {}).get("source_sha256"),
            "winner_seat": metadata.get("winner_player_id"),
            "profiles_verified": bool(profiles) and all(profile.get("policy") == expected for profile in profiles),
            "human_intents": sum(event.get("e") == 9 and event.get("p") == 1 for event in events),
            "human_decision_contexts": sum(event.get("k") == "human_evaluation_intent" for event in events),
            "bot_choices": sum(event.get("k") == "bot_evaluation_choice" for event in events),
            "bot_commands": sum(event.get("k") == "bot_applied" for event in events),
            "replay_frames": len(data.get("replay", {}).get("frames", [])),
            "dropped_witnesses": metadata.get("evaluation_witnesses_dropped", 0),
        })
    (args.output / "summary.json").write_text(json.dumps(rows, indent=2) + "\n")
    print(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
