#!/usr/bin/env python3
"""Summarize validated round-robin artifacts without altering simulation inputs."""
import argparse
from collections import Counter, defaultdict
import csv
import gzip
import hashlib
import itertools
import json
from pathlib import Path
import random
import statistics

LABELS = {"balancer": "Balancer v3", "turtle": "Turtle", "raider": "Raider", "greedy": "Greedy", "swarm_lord": "Swarm Lord"}
FEED_REVERSAL_WINDOW_MS = 5000


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quantile(values, fraction):
    values = sorted(values)
    if not values:
        return None
    position = fraction * (len(values) - 1)
    low = int(position)
    high = min(low + 1, len(values) - 1)
    return values[low] + (values[high] - values[low]) * (position - low)


def tally(entries):
    counts = Counter(e["result"] for e in entries)
    seconds = sum(e["duration_s"] for e in entries)
    commands = sum(e["applied"] for e in entries)
    rejections = sum(e["rejected"] for e in entries)
    n = len(entries)
    if not n:
        return {}
    first_orders = [e["first_applied_ms"] / 1000 for e in entries if e["first_applied_ms"] is not None]
    return {"games": n, "wins": counts["win"], "losses": counts["loss"], "draws": counts["draw"],
            "win_fraction": counts["win"] / n, "score_fraction": (counts["win"] + counts["draw"] / 2) / n,
            "median_duration_s": statistics.median(e["duration_s"] for e in entries),
            "p90_duration_s": quantile([e["duration_s"] for e in entries], .9),
            "median_first_order_s": statistics.median(first_orders) if first_orders else None,
            "matches_with_no_applied_orders": n - len(first_orders),
            "time_limit_matches": sum(e["time_limit"] for e in entries),
            "quiet_final_minute_time_limit_matches": sum(e["quiet_time_limit"] for e in entries),
            "applied_commands": commands, "applied_commands_per_minute": commands / (seconds / 60),
            "rejections": rejections, "rejected_fraction": rejections / max(1, commands + rejections),
            "rejection_reasons": dict(sum((Counter(e["rejection_reasons"]) for e in entries), Counter())),
            "matches_with_rejection_run_at_least_3": sum(e["max_rejection_run"] >= 3 for e in entries),
            "max_rejection_run": max(e["max_rejection_run"] for e in entries),
            "max_match_rejections": max(e["rejected"] for e in entries),
            "quick_feed_reversals": sum(e["quick_feed_reversals"] for e in entries),
            "matches_with_feed_reversal_run_at_least_3": sum(e["max_feed_reversal_run"] >= 3 for e in entries),
            "max_feed_reversal_run": max(e["max_feed_reversal_run"] for e in entries),
            "early_idle_productive_hive_fraction": sum(e["early_idle"] for e in entries) / max(1, sum(e["early_owned"] for e in entries)),
            "early_lane_utilization": sum(e["early_used"] for e in entries) / max(1, sum(e["early_budget"] for e in entries)),
            "intents": dict(sum((Counter(e["intents"]) for e in entries), Counter()))}


def seed_interval(entries):
    # Resample whole seeds, keeping both seats, all opponents and all fixed maps
    # together. This estimates seed variability conditional on this map panel.
    blocks = defaultdict(list)
    for entry in entries:
        blocks[entry["seed"]].append({"win": 1, "draw": .5, "loss": 0}[entry["result"]])
    values = [statistics.mean(blocks[seed]) for seed in sorted(blocks)]
    if len(values) < 2:
        return None
    rng = random.Random(20260922)
    samples = [sum(rng.choices(values, k=len(values))) / len(values) for _ in range(5000)]
    return [quantile(samples, .025), quantile(samples, .975)]


def describe(row, seat, file_name):
    actions = [event for event in row["trace"] if event["seat"] == seat and event["event"] in ("applied", "rejected")]
    applied = [event for event in actions if event["event"] == "applied"]
    rejected = [event for event in actions if event["event"] == "rejected"]
    streak = maximum = 0
    for event in actions:
        streak = streak + 1 if event["event"] == "rejected" else 0
        maximum = max(maximum, streak)
    # A review cue: successive successful feeds on one hive pair alternate
    # direction within five seconds. Other orders on that pair break the run.
    last_by_pair = {}
    quick_feed_reversals = max_feed_reversal_run = 0
    for event in applied:
        pair = tuple(sorted((event["src"], event["dst"])))
        previous, run = last_by_pair.get(pair, ({}, 0))
        reversal = (event["intent"] == previous.get("intent") == "feed"
                    and event["src"] == previous.get("dst")
                    and event["lane_id"] == previous.get("lane_id")
                    and 0 < event["sim_ms"] - previous["sim_ms"] <= FEED_REVERSAL_WINDOW_MS)
        run = run + 1 if reversal else 0
        quick_feed_reversals += int(reversal)
        max_feed_reversal_run = max(max_feed_reversal_run, run)
        last_by_pair[pair] = (event, run)
    early_owned = early_idle = early_budget = early_used = 0
    for sample in row["board_samples"]:
        if sample["sim_ms"] > 60000:
            continue
        owned = [hive for hive in sample["hives"] if hive["owner"] == seat]
        early_owned += len(owned)
        early_idle += sum(hive["outgoing"] == 0 and hive["power"] >= 10 for hive in owned)
        early_used += sum(hive["outgoing"] for hive in owned)
        early_budget += sum(hive["budget"] for hive in owned)
    last_change = row["diagnostics"]["last_ownership_change_ms"]
    no_change_ms = row["sim_ms"] - max(0, last_change)
    time_limit = row["reason"] == "time"
    style = (row["a"] if seat == 1 else row["b"]).split(":")[0]
    opponent = (row["b"] if seat == 1 else row["a"]).split(":")[0]
    outcome = "draw" if row["winner_team"] == 0 else "win" if row["winner_team"] == seat else "loss"
    return {"style": style, "opponent": opponent, "seat": seat, "map": row["map_id"], "seed": row["seed"],
            "result": outcome, "duration_s": row["sim_ms"] / 1000, "reason": row["reason"], "time_limit": time_limit,
            "quiet_time_limit": time_limit and no_change_ms >= 60000,
            "last_ownership_change_ms": last_change, "ownership_changes": row["diagnostics"]["ownership_changes"],
            "applied": len(applied), "rejected": len(rejected), "max_rejection_run": maximum,
            "quick_feed_reversals": quick_feed_reversals, "max_feed_reversal_run": max_feed_reversal_run,
            "rejection_reasons": dict(Counter(e.get("reason", "unknown") for e in rejected)),
            "intents": dict(Counter(e["intent"] for e in applied)),
            "first_applied_ms": applied[0]["sim_ms"] if applied else None,
            "early_owned": early_owned, "early_idle": early_idle, "early_used": early_used, "early_budget": early_budget,
            "artifact": file_name}


def load_entries(folder, partial):
    plan = json.loads((folder / "plan.json").read_text())
    completion_path = folder / "completion.json"
    if not partial:
        completion = json.loads(completion_path.read_text())
        if not completion["passed"] or completion["plan_sha256"] != sha(folder / "plan.json"):
            raise RuntimeError("Completion does not certify this plan")
        manifests = completion["results"]
    else:
        manifests = [json.loads(p.read_text()) for p in sorted((folder / "jobs").glob("*.manifest.json"))]
    signature = hashlib.sha256(json.dumps(plan["source_hashes"], sort_keys=True).encode()).hexdigest()
    entries = []
    seen = set()
    profiles = {}
    for manifest in manifests:
        path = Path(manifest["result_path"])
        if sha(path) != manifest["result_sha256"] or manifest["source_signature"] != signature:
            raise RuntimeError(f"Artifact/provenance mismatch: {path}")
        payload = json.loads(gzip.decompress(path.read_bytes()))
        for row in payload["results"]:
            key = row["map_id"], row["seed"], row["a"], row["b"]
            if key in seen or not row["completed"]:
                raise RuntimeError("Duplicate or incomplete match")
            seen.add(key)
            for event in row["trace"]:
                if event["event"] == "applied":
                    style = (row["a"] if event["seat"] == 1 else row["b"]).split(":")[0]
                    expected_policy = "human_balancer_v3" if style == "balancer" else "baseline_v3"
                    if event.get("policy") != expected_policy:
                        raise RuntimeError("Applied command used an unexpected policy")
                if event["event"] == "started":
                    profile_key = (event["profile"]["style"], event["seat"])
                    if profile_key in profiles and profiles[profile_key] != event["profile"]:
                        raise RuntimeError("A persona's pinned profile changed between maps/seeds")
                    profiles[profile_key] = event["profile"]
            entries += [describe(row, seat, str(path.relative_to(folder))) for seat in (1, 2)]
    expected = {(m, seed, a + ":medium", b + ":medium") for m in plan["maps"] for seed in plan["seeds"]
                for a, b in itertools.permutations(plan["styles"], 2)}
    if not seen <= expected or (not partial and seen != expected):
        raise RuntimeError("Actual match coverage differs from the declared schedule")
    return plan, entries, profiles


def markdown(summary):
    prefix = "partial_" if summary["partial"] else ""
    lines = ["# Medium-bot round robin — September 22, 2026", "",
             ("**PARTIAL: do not use these rankings for tuning.**" if summary["partial"] else "**Complete, validated evaluation. Gameplay rules and rates were held fixed.**"), "",
             f"{summary['games']} games; five fixed maps; {len(summary['observed_seeds'])} of {len(summary['seeds'])} planned sampled seeds represented; both seat assignments.",
             "Roster: experimental Balancer v3 plus the four existing baseline personalities, all medium.", "",
             "## Overall results", "",
             "Score is wins plus half of draws. Every personality faces the same opponents, maps and seats.", "",
             "| Bot | W / L / D | Win % | Score % | Seed-bootstrap 95% interval | Median seconds | Time-limit games |",
             "| --- | --- | ---: | ---: | --- | ---: | ---: |"]
    ordered = sorted(summary["overall"], key=lambda s: (-summary["overall"][s]["score_fraction"], s))
    for style in ordered:
        row = summary["overall"][style]
        interval = row.get("score_seed_bootstrap_95")
        interval_text = f"{interval[0]:.1%}–{interval[1]:.1%}" if interval else "—"
        lines.append(f"| {LABELS[style]} | {row['wins']} / {row['losses']} / {row['draws']} | {100*row['win_fraction']:.1f} | {100*row['score_fraction']:.1f} | {interval_text} | {row['median_duration_s']:.1f} | {row['time_limit_matches']} |")
    lines += ["", "## Head-to-head score", "", "Rows score against columns; a draw counts as half a point.", "",
              "| Bot | " + " | ".join(LABELS[s] for s in summary["styles"]) + " |",
              "| --- | " + " | ".join("---:" for _ in summary["styles"]) + " |"]
    for style in summary["styles"]:
        lines.append("| " + LABELS[style] + " | " + " | ".join(
            "—" if opponent == style else f"{100*summary['matchups'][style][opponent]['score_fraction']:.1f}%"
            for opponent in summary["styles"]) + " |")
    lines += ["", "## Map dependence", "", "Score against all four opponents on each fixed map.", "",
              "| Map | " + " | ".join(LABELS[s] for s in summary["styles"]) + " |",
              "| --- | " + " | ".join("---:" for _ in summary["styles"]) + " |"]
    for map_id in summary["maps"]:
        if map_id in summary["by_map"]:
            lines.append("| " + map_id + " | " + " | ".join(f"{100*summary['by_map'][map_id][s]['score_fraction']:.1f}%" for s in summary["styles"]) + " |")
    lines += ["", "## Seat dependence", "", "Both seats face the same opponents, maps and seeds.", "",
              "| Bot | Seat 1 score | Seat 2 score |",
              "| --- | ---: | ---: |"]
    for style in ordered:
        seats = summary["by_seat"][style]
        lines.append(f"| {LABELS[style]} | {seats['1']['score_fraction']:.1%} | {seats['2']['score_fraction']:.1%} |")
    lines += ["", "## Duration and behavior", "",
              f"Actual draws: {summary['outcomes']['draws']}. Time-limit decisions: {summary['outcomes']['time_limit_wins']}. Conquest wins: {summary['outcomes']['conquest_wins']}.",
              f"Time-ended matches with no ownership change in the final 60 seconds: {summary['outcomes']['quiet_final_minute_time_limit_matches']}.",
              "This last measure is a stalemate proxy; a territorial leader can be deliberately holding a winning position. Ownership is compared before/after each 100ms canonical tick, so multiple transitions within one tick can cancel out.", "",
              "| Bot | Applied orders/min | Rejected orders | Rejected % | Matches with ≥3 consecutive rejections | Early lane use | Early idle productive hives |",
              "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
    for style in ordered:
        row = summary["overall"][style]
        lines.append(f"| {LABELS[style]} | {row['applied_commands_per_minute']:.2f} | {row['rejections']} | {100*row['rejected_fraction']:.2f} | {row['matches_with_rejection_run_at_least_3']} | {100*row['early_lane_utilization']:.1f}% | {100*row['early_idle_productive_hive_fraction']:.1f}% |")
    lines += ["", "Early samples cover the first minute. Idle means power ≥10 and no outgoing route, divided by all owned-hive samples. It does not establish that a useful legal route was available.", "",
              "| Bot | Median first order (s) | Quick feed reversals | Matches with ≥3 reversals in a run | Longest run |",
              "| --- | ---: | ---: | ---: | ---: |"]
    for style in ordered:
        row = summary["overall"][style]
        first = row["median_first_order_s"]
        first_text = f"{first:.1f}" if first is not None else "—"
        lines.append(f"| {LABELS[style]} | {first_text} | {row['quick_feed_reversals']} | {row['matches_with_feed_reversal_run_at_least_3']} | {row['max_feed_reversal_run']} |")
    lines += ["", "A quick feed reversal is a successful feed in the opposite direction to the previous successful feed on that pair, within five seconds. Another order on that pair breaks the run. Three reversals require four alternating orders. This is a review cue, not proof that each reversal was unnecessary; changing threats can justify redirects.", "",
              "## Limits", "",
              "The bootstrap resamples whole seeds, preserving the paired seats, opponents and fixed maps within each block. Its interval describes seed variability on this map panel; it does not cover uncertainty from choosing other maps or human opponents. Zero-width intervals can occur when every sampled seed has the same result.", "",
              "The map panel is fixed and equally weighted, with two Centerstrike variants. It is not a random sample of all current or future maps. Authored medium-persona timing differences remain intact. Only Balancer uses the new human-behavior controller. Results do not establish human likeness, equal difficulty across tiers, or release readiness.", "",
              f"Full per-map/per-pair/seat results are in [{prefix}summary.json]({prefix}summary.json); individual bot appearances are in [{prefix}appearances.csv]({prefix}appearances.csv); [{prefix}review_candidates.json]({prefix}review_candidates.json) identifies exact traces for further review."]
    return "\n".join(lines) + "\n"


def plot(summary, folder):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    styles = summary["styles"]
    values = np.array([[np.nan if a == b else 100 * summary["matchups"][a][b]["score_fraction"] for b in styles] for a in styles])
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.5), gridspec_kw={"width_ratios": [1.15, 1]})
    fig.patch.set_facecolor("#f7f8fa")
    ax = axes[0]
    heat = ax.imshow(values, cmap="RdYlBu", vmin=0, vmax=100)
    ax.set_xticks(range(5), [LABELS[s] for s in styles], rotation=30, ha="right")
    ax.set_yticks(range(5), [LABELS[s] for s in styles])
    for i in range(5):
        for j in range(5):
            value = values[i, j]
            ax.text(j, i, "—" if np.isnan(value) else f"{value:.1f}%", ha="center", va="center",
                    color="white" if value < 20 or value > 80 else "#20252d", fontsize=12)
    ax.set_title("Head-to-head score\nRow versus column", pad=15)
    fig.colorbar(heat, ax=ax, shrink=.75, label="Win + ½ draw (%)")
    ax = axes[1]
    ordered = sorted(styles, key=lambda s: summary["overall"][s]["score_fraction"])
    scores = [100 * summary["overall"][s]["score_fraction"] for s in ordered]
    intervals = [summary["overall"][s]["score_seed_bootstrap_95"] for s in ordered]
    errors = [[max(0, score - 100 * ci[0]) for score, ci in zip(scores, intervals)],
              [max(0, 100 * ci[1] - score) for score, ci in zip(scores, intervals)]]
    ax.barh([LABELS[s] for s in ordered], scores, color="#267aa1", xerr=errors, capsize=3)
    ax.set_xlim(0, 105)
    ax.axvline(50, color="#8c95a1", linestyle="--", linewidth=1)
    ax.set_xlabel("Score against the other four bots (%)")
    ax.set_title("Overall score\n95% bootstrap interval across seeds", pad=15)
    for i, score in enumerate(scores):
        ax.text(min(max(score, 100 * intervals[i][1]) + 2, 99), i, f"{score:.1f}%", va="center", fontsize=10)
    fig.suptitle(f"Swarmfront medium bots · {summary['games']:,} games · fixed gameplay rates", fontsize=16)
    fig.text(.5, .025, f"5 fixed maps · {len(summary['seeds'])} sampled seeds · both seats · Balancer v3 pilot + four existing policies\nConditional bot-vs-bot evidence; human likeness and other maps are not measured.", ha="center", fontsize=9)
    fig.tight_layout(rect=[0, .10, 1, .92])
    fig.savefig(folder / "matchup_summary.png", dpi=180, bbox_inches="tight", pad_inches=.15)
    fig.savefig(folder / "matchup_summary.svg", bbox_inches="tight", pad_inches=.15)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("--partial", action="store_true")
    parser.add_argument("--plot", action="store_true")
    args = parser.parse_args()
    folder = args.artifacts.resolve()
    plan, entries, profiles = load_entries(folder, args.partial)
    if not entries:
        raise RuntimeError("No validated batches available")
    styles = plan["styles"]
    by_style = {s: [e for e in entries if e["style"] == s] for s in styles}
    overall = {s: tally(rows) for s, rows in by_style.items()}
    matchups = {s: {o: tally([e for e in by_style[s] if e["opponent"] == o]) for o in styles if o != s} for s in styles}
    for s in styles:
        overall[s]["score_seed_bootstrap_95"] = seed_interval(by_style[s]) if not args.partial else None
        for o in matchups[s]:
            assert abs(matchups[s][o]["score_fraction"] + matchups[o][s]["score_fraction"] - 1) < 1e-12
    by_map = {m: {s: tally([e for e in by_style[s] if e["map"] == m]) for s in styles}
              for m in plan["maps"] if any(e["map"] == m for e in entries)}
    seat_one = [e for e in entries if e["seat"] == 1]
    outcomes = {"draws": sum(e["result"] == "draw" for e in seat_one),
                "time_limit_wins": sum(e["time_limit"] and e["result"] != "draw" for e in seat_one),
                "conquest_wins": sum(e["reason"] == "conquest" for e in seat_one),
                "quiet_final_minute_time_limit_matches": sum(e["quiet_time_limit"] for e in seat_one)}
    assert sum(outcomes[key] for key in ("draws", "time_limit_wins", "conquest_wins")) == len(seat_one)
    assert sum(r["wins"] for r in overall.values()) == sum(r["losses"] for r in overall.values())
    summary = {"partial": args.partial, "games": len(seat_one), "styles": styles, "maps": plan["maps"], "seeds": plan["seeds"],
               "observed_seeds": sorted({e["seed"] for e in entries}),
               "overall": overall, "matchups": matchups, "by_map": by_map, "outcomes": outcomes,
               "by_seat": {s: {str(seat): tally([e for e in by_style[s] if e["seat"] == seat]) for seat in (1, 2)} for s in styles},
               "matchups_by_map": {m: {s: {o: tally([e for e in by_style[s] if e["map"] == m and e["opponent"] == o]) for o in styles if o != s} for s in styles} for m in by_map},
               "profiles": {f"{s}:seat{seat}": profile for (s, seat), profile in profiles.items()},
               "plan_sha256": sha(folder / "plan.json"), "report_source_sha256": sha(Path(__file__)),
               "bootstrap": {"replicates": 5000, "resampling_unit": "whole seed", "sampling_seed": 20260922, "maps": "fixed"}}
    summary["exploratory_diagnostics"] = {"quick_feed_reversal_window_ms": FEED_REVERSAL_WINDOW_MS,
                                          "note": "Added after trace review during the sweep; does not affect outcomes or the declared match schedule."}
    suffix = "partial_" if args.partial else ""
    (folder / f"{suffix}summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    (folder / f"{suffix}report.md").write_text(markdown(summary))
    with (folder / f"{suffix}appearances.csv").open("w") as handle:
        columns = [k for k in entries[0] if k not in ("rejection_reasons", "intents")]
        writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(entries)
    candidates = {"rejection_runs": sorted([e for e in entries if e["max_rejection_run"] >= 3], key=lambda e: (-e["max_rejection_run"], -e["rejected"]))[:20],
                  "feed_reversal_runs": sorted([e for e in entries if e["max_feed_reversal_run"] >= 3], key=lambda e: (-e["max_feed_reversal_run"], -e["quick_feed_reversals"]))[:20],
                  "quiet_draws": [e for e in seat_one if e["quiet_time_limit"] and e["result"] == "draw"][:20],
                  "quiet_time_limit_wins": [e for e in seat_one if e["quiet_time_limit"] and e["result"] != "draw"][:20],
                  "highest_early_idle_fraction": sorted(entries, key=lambda e: -(e["early_idle"] / max(1, e["early_owned"])))[:20]}
    (folder / f"{suffix}review_candidates.json").write_text(json.dumps(candidates, indent=2) + "\n")
    if args.plot and not args.partial:
        plot(summary, folder)
    print(json.dumps({"games": summary["games"], "partial": args.partial, "outcomes": outcomes,
                      "standings": {s: {k: overall[s][k] for k in ("wins", "losses", "draws", "score_fraction", "rejections")} for s in styles}}, indent=2))


if __name__ == "__main__":
    main()
