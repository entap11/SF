"""Freeze record comparison inputs into the exported catalog. Use --check in gates."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data/campaign/starter_v1.json"


def expected():
    data = json.loads(CATALOG.read_text())
    # Include simulation, map conversion, policy and constants; exclude UI/art.
    paths = sorted({p for folder in ("scripts/ops", "scripts/sim", "scripts/systems",
                                     "scripts/bot", "scripts/maps")
                    for p in (ROOT / folder).glob("*.gd")
                    if not p.name.startswith("campaign_")})
    paths += [ROOT / "scripts/state/game_state.gd"]
    digest = hashlib.sha256(str(data["rules_revision"]).encode())
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())
    data["rules_fingerprint"] = digest.hexdigest()
    for level in data["levels"]:
        path = ROOT / level["map_path"].removeprefix("res://")
        level["map_fingerprint"] = hashlib.sha256(path.read_bytes()).hexdigest()
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = expected()
    if args.check:
        if CATALOG.read_text() != output:
            raise SystemExit("Campaign fingerprints stale; run tools/refresh_campaign_fingerprints.py")
        print("Campaign fingerprints: PASS")
    else:
        CATALOG.write_text(output)
