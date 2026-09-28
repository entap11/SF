#!/usr/bin/env python3
"""Download the private beta archive and summarize participants separately by cohort."""
import argparse
import gzip
import hashlib
import json
import os
import statistics
import urllib.request
from collections import defaultdict
from pathlib import Path
from beta_game_report import write_report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", required=True, help="Identity service base, ending /v1")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--label-participant", help="Participant key from archive index; never a name")
    parser.add_argument("--cohort", choices=("owner", "new", "intermediate", "experienced", "unknown"))
    parser.add_argument("--annotations", type=Path, help="Private per-recording review annotations; defaults to output/annotations.json")
    parser.add_argument("--manifest", type=Path, help="Optional exact build manifest for older recordings missing map hashes")
    args = parser.parse_args()
    if not args.url.startswith("https://"):
        parser.error("archive requires HTTPS")
    token = os.environ.get("SF_BETA_ARCHIVE_TOKEN", "")
    if not token:
        parser.error("provide the operator credential through SF_BETA_ARCHIVE_TOKEN")

    def request(path, body=None):
        encoded = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(args.url.rstrip("/") + path, data=encoded,
            headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
            method="PUT" if body is not None else "GET")
        # Never forward the operator credential through a redirect.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *args, **kwargs):
                return None
        with urllib.request.build_opener(NoRedirect).open(req, timeout=30) as response:
            return response.read()

    if args.label_participant:
        if not args.cohort or len(args.label_participant) != 64 or any(c not in "0123456789abcdef" for c in args.label_participant):
            parser.error("labeling requires a valid participant key and --cohort")
        request("/admin/beta-participants/" + args.label_participant, {"cohort": args.cohort})
    args.output.mkdir(parents=True, exist_ok=True)
    recordings = args.output / "recordings"
    recordings.mkdir(exist_ok=True)
    rows = []
    cursor = "0"
    while True:
        page = json.loads(request("/admin/beta-captures?after=" + cursor))
        if page.get("ok") is not True:
            raise RuntimeError("archive listing was not acknowledged")
        entries = page["captures"]
        if not entries:
            break
        rows.extend(entries)
        next_cursor = str(page["next"])
        if int(next_cursor) <= int(cursor):
            raise RuntimeError("archive cursor did not advance")
        cursor = next_cursor
    groups = defaultdict(list)
    for row in rows:
        capture_id = str(row["id"])
        if not capture_id.isdecimal():
            raise RuntimeError("invalid archive id")
        path = recordings / (capture_id + ".json.gz")
        data = path.read_bytes() if path.exists() else request("/admin/beta-captures/" + capture_id)
        if hashlib.sha256(data).hexdigest() != row["sha256"]:
            raise RuntimeError("archive digest mismatch: " + capture_id)
        payload = json.loads(gzip.decompress(data))
        if payload["capture_id"] != row["capture_id"] or payload["owner_key"] != row["participant_key"]:
            raise RuntimeError("archive identity mismatch: " + capture_id)
        if not path.exists():
            temp = path.with_suffix(path.suffix + ".tmp")
            temp.write_bytes(data)
            temp.replace(path)
        groups[(row["cohort"], row["participant_key"])].append(row)
    participants = []
    for (cohort, key), games in sorted(groups.items()):
        finished = [g for g in games if g["status"] == "completed"]
        participants.append({"cohort": cohort, "participant_key": key,
            "recordings": len(games), "completed": len(finished),
            "abandoned_or_interrupted": len(games) - len(finished),
            "raw_median_completed_seconds": statistics.median(float(g["sim_ms"]) / 1000 for g in finished) if finished else None})
    (args.output / "index.json").write_text(json.dumps(rows, indent=2) + "\n")
    (args.output / "participants.json").write_text(json.dumps(participants, indent=2) + "\n")
    manifest_path = args.manifest or Path(__file__).resolve().parents[1] / "data/beta_capture_build.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
    annotations = json.loads(args.annotations.read_text()) if args.annotations else None
    write_report(args.output, annotations=annotations, manifest=manifest)
    print(json.dumps({"recordings": len(rows), "participants": len(participants),
        "cohorts": dict((cohort, sum(p["recordings"] for p in participants if p["cohort"] == cohort))
                        for cohort in sorted({p["cohort"] for p in participants})),
        "note": "Counts are participant recordings, not deduplicated multiplayer matches. Owner remains separate."}, indent=2))


if __name__ == "__main__":
    main()
