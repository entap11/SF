#!/usr/bin/env python3
"""Summarize run-level iPhone startup hitch diagnostic reports."""

from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "sf_startup_hitch_diagnostic_v1"


def _percentile(values: list[float], percentile: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    rank = max(1, math.ceil((percentile / 100.0) * len(ordered)))
    return round(ordered[rank - 1], 3)


def _distribution(values: Iterable[float | int | None]) -> dict[str, Any]:
    measured = [float(value) for value in values if value is not None]
    return {
        "measured_run_count": len(measured),
        "median": round(statistics.median(measured), 3) if measured else None,
        "p95_nearest_rank": _percentile(measured, 95.0),
        "worst": round(max(measured), 3) if measured else None,
    }


def _collect_paths(inputs: list[Path]) -> list[Path]:
    paths: set[Path] = set()
    for input_path in inputs:
        if input_path.is_dir():
            paths.update(path for path in input_path.rglob("*.json") if path.is_file())
        elif input_path.is_file():
            paths.add(input_path)
    return sorted(paths)


def _eligibility_reasons(report: dict[str, Any]) -> list[str]:
    reasons: list[str] = []
    runtime = report.get("runtime", {})
    config = report.get("configuration", {})
    if report.get("schema") != SCHEMA:
        reasons.append("wrong_schema")
    if report.get("status") != "COMPLETE":
        reasons.append("incomplete")
    if runtime.get("platform") != "iOS":
        reasons.append("not_physical_ios")
    if runtime.get("display_server") == "headless":
        reasons.append("headless")
    if config.get("launch_classification") not in ("cold", "warm"):
        reasons.append("missing_launch_classification")
    if config.get("source_commit") in (None, "", "unavailable"):
        reasons.append("missing_source_commit")
    if not report.get("protected_state_integrity", {}).get("pass", False):
        reasons.append("protected_state_integrity_failed")
    return reasons


def _maximum_owner(report: dict[str, Any]) -> str | None:
    frame_hitches = [
        hitch for hitch in report.get("hitches", [])
        if hitch.get("kind") == "rendered_frame"
    ]
    if not frame_hitches:
        return None
    maximum = max(frame_hitches, key=lambda hitch: float(hitch.get("duration_ms", 0.0)))
    return str(maximum.get("last_completed_marker") or maximum.get("startup_phase") or "unknown")


def _run_row(path: Path, report: dict[str, Any]) -> dict[str, Any]:
    summary = report.get("summary", {})
    hitches = report.get("hitches", [])
    frame_hitches = [h for h in hitches if h.get("kind") == "rendered_frame"]
    interactive = [h for h in frame_hitches if h.get("visibility") == "INTERACTIVE"]
    return {
        "path": str(path),
        "launch": report.get("configuration", {}).get("launch_classification"),
        "source_commit": report.get("configuration", {}).get("source_commit"),
        "maximum_rendered_frame_ms": summary.get("maximum_rendered_frame_ms"),
        "maximum_canonical_tick_ms": summary.get("maximum_canonical_tick_ms"),
        "first_canonical_tick_ms": summary.get("first_canonical_tick_ms"),
        "rendered_hitch_count": len(frame_hitches),
        "interactive_rendered_hitch_count": len(interactive),
        "maximum_owner_marker": _maximum_owner(report),
    }


def _summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    count = len(rows)
    frame_occurrences = sum(row["rendered_hitch_count"] > 0 for row in rows)
    interactive_occurrences = sum(row["interactive_rendered_hitch_count"] > 0 for row in rows)
    owners = Counter(
        row["maximum_owner_marker"] for row in rows if row["maximum_owner_marker"] is not None
    )
    return {
        "run_count": count,
        "rendered_hitch_occurrence_rate": round(frame_occurrences / count, 4) if count else None,
        "interactive_hitch_occurrence_rate": round(interactive_occurrences / count, 4) if count else None,
        "per_run_maximum_rendered_frame_ms": _distribution(
            row["maximum_rendered_frame_ms"] for row in rows
        ),
        "per_run_maximum_canonical_tick_ms": _distribution(
            row["maximum_canonical_tick_ms"] for row in rows
        ),
        "first_canonical_tick_ms": _distribution(
            row["first_canonical_tick_ms"] for row in rows
        ),
        "maximum_owner_marker_counts": dict(owners.most_common()),
    }


def build_summary(paths: list[Path]) -> dict[str, Any]:
    eligible_rows: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    parse_errors: list[dict[str, str]] = []
    for path in paths:
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            parse_errors.append({"path": str(path), "error": str(error)})
            continue
        if not isinstance(report, dict):
            parse_errors.append({"path": str(path), "error": "root_not_object"})
            continue
        reasons = _eligibility_reasons(report)
        if reasons:
            rejected.append({"path": str(path), "reasons": reasons})
            continue
        eligible_rows.append(_run_row(path, report))

    cold = [row for row in eligible_rows if row["launch"] == "cold"]
    warm = [row for row in eligible_rows if row["launch"] == "warm"]
    return {
        "schema": "sf_startup_hitch_run_summary_v1",
        "percentile_method": "nearest_rank_on_per_run_values",
        "input_file_count": len(paths),
        "eligible_physical_iphone_run_count": len(eligible_rows),
        "rejected_run_count": len(rejected),
        "parse_error_count": len(parse_errors),
        "combined": _summarize(eligible_rows),
        "cold": _summarize(cold),
        "warm": _summarize(warm),
        "cold_minus_warm_median_maximum_rendered_frame_ms": _cold_warm_delta(cold, warm),
        "runs": eligible_rows,
        "rejected": rejected,
        "parse_errors": parse_errors,
    }


def _cold_warm_delta(cold: list[dict[str, Any]], warm: list[dict[str, Any]]) -> float | None:
    cold_values = [float(row["maximum_rendered_frame_ms"]) for row in cold if row["maximum_rendered_frame_ms"] is not None]
    warm_values = [float(row["maximum_rendered_frame_ms"]) for row in warm if row["maximum_rendered_frame_ms"] is not None]
    if not cold_values or not warm_values:
        return None
    return round(statistics.median(cold_values) - statistics.median(warm_values), 3)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", type=Path, help="JSON report files or directories")
    parser.add_argument("--output", type=Path, help="also write the summary JSON to this path")
    args = parser.parse_args()
    paths = _collect_paths(args.inputs)
    summary = build_summary(paths)
    rendered = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 0 if summary["parse_error_count"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
