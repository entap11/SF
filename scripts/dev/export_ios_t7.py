#!/usr/bin/env python3
"""Export an iOS Xcode project to configured external storage; optionally build unsigned."""

import argparse
from datetime import datetime
import os
from pathlib import Path
import subprocess
import sys

from build_storage import ROOT, output_path, storage_root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", default="iOS")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--debug", action="store_true")
    parser.add_argument("--build", action="store_true", help="Also run an unsigned iOS device build.")
    args = parser.parse_args()
    storage_root(required=True)
    project = output_path(args.output, "project/artifacts/ios/exports/" +
                          datetime.now().strftime("%Y%m%d-%H%M%S") + "/Swarmfront.xcodeproj")
    if project.suffix != ".xcodeproj" or project.exists():
        raise RuntimeError("Choose a new .xcodeproj output path; existing versions are preserved.")
    default_godot = (Path.home() / "Library/Application Support/Swarmfront/toolchains/godot/4.7.1/"
                     "Godot.app/Contents/MacOS/Godot")
    godot = os.environ.get("GODOT_BIN", str(default_godot))
    project.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([godot, "--headless", "--path", str(ROOT),
                    "--export-debug" if args.debug else "--export-release",
                    args.preset, str(project)], check=True)
    if not (project / "project.pbxproj").is_file():
        raise RuntimeError("Godot did not produce the requested Xcode project.")
    if args.build:
        storage_root(required=True)
        subprocess.run(["xcodebuild", "-project", str(project), "-scheme", project.stem,
                        "-configuration", "Debug" if args.debug else "Release",
                        "-destination", "generic/platform=iOS", "-derivedDataPath",
                        str(project.parent / "DerivedData"), "CODE_SIGNING_ALLOWED=NO", "build"], check=True)
    print(f"SF_IOS_EXPORT: {project}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as exc:
        print(f"SF_IOS_EXPORT_ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
