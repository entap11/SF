#!/usr/bin/env python3
"""Validate optional local build storage and route generated output there."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / ".sf-build-storage.json"


def storage_root(required=False, minimum_free=1024 ** 3):
    if not CONFIG.exists():
        if required:
            raise RuntimeError("External SF build storage is not configured (.sf-build-storage.json).")
        return None
    config = json.loads(CONFIG.read_text())
    volume = Path(config["volume"])
    message = f"Connect and unlock Samsung T7 at {volume} before building SwarmFront."
    if not os.path.ismount(volume):
        raise RuntimeError(message)
    result = subprocess.run(["/usr/sbin/diskutil", "info", "-plist", str(volume)],
                            capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(message)
    info = plistlib.loads(result.stdout)
    if info.get("VolumeUUID") != config["volume_uuid"] or not info.get("Writable"):
        raise RuntimeError(f"SF build storage is the wrong drive or is read-only. {message}")
    destination = volume / config["artifact_directory"]
    if not destination.resolve().is_relative_to(volume.resolve()):
        raise RuntimeError("SF artifact directory must stay on the configured external volume.")
    if shutil.disk_usage(volume).free < minimum_free:
        raise RuntimeError("Samsung T7 has insufficient free space for this build.")
    return destination


def output_path(requested, default_relative):
    """Honor explicit T7 paths; translate old workspace artifact paths when configured."""
    destination = storage_root()
    if destination is None:
        if requested is None:
            raise RuntimeError("Specify --output, or configure external SF build storage.")
        return Path(requested).expanduser().resolve()
    if requested is None:
        result = destination / default_relative
    else:
        result = Path(requested).expanduser().absolute()
        if result.is_relative_to(ROOT.parent):
            relative = result.relative_to(ROOT.parent)
            if "artifacts" not in relative.parts:
                raise RuntimeError("Build output must be in an artifact directory, not source.")
            result = destination / relative
    result = result.resolve()
    if not result.is_relative_to(destination.resolve()):
        raise RuntimeError(f"Build output must be under {destination} while T7 storage is configured.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "path"])
    parser.add_argument("relative", nargs="?")
    parser.add_argument("--required", action="store_true")
    args = parser.parse_intermixed_args()
    destination = storage_root(required=args.required)
    if args.command == "path":
        if destination is None or not args.relative:
            raise RuntimeError("Configure external storage and supply a relative artifact path.")
        print(output_path(None, args.relative))
    else:
        print(f"SF_BUILD_STORAGE: {destination or 'not configured; existing paths apply'}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError) as exc:
        print(f"SF_BUILD_STORAGE_ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
