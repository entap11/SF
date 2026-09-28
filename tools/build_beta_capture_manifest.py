#!/usr/bin/env python3
"""Stamp/check the exact gameplay source shipped by a beta capture build."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/beta_capture_build.json"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", default=re.search(r'config/version.beta_capture="([^\"]+)"', (ROOT / "project.godot").read_text()).group(1))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    files = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for folder in ("scripts", "maps", "scenes", "data"):
        files.extend(p for p in (ROOT / folder).rglob("*") if p.suffix in (".gd", ".tscn", ".json", ".tres") and p != OUTPUT)
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
    digest = hashlib.sha256(json.dumps(hashes, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    result = {"build": args.build, "source_sha256": digest, "files": hashes}
    if args.check:
        assert json.loads(OUTPUT.read_text()) == result, "beta capture manifest is stale; regenerate before export"
    else:
        OUTPUT.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"build": args.build, "source_sha256": digest, "checked": args.check}))

if __name__ == "__main__":
    main()
