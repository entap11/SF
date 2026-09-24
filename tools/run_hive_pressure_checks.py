"""Check production hive effects with isolated offline player data."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TESTS = [
    "hive_distress_light_smoke_test",
    "hive_hostile_capture_pressure_smoke_test",
    "hive_growth_transition_smoke_test",
    "hive_pick_radius_smoke_test",
    "async_selection_white_hot_smoke_test",
    "hive_interaction_light_smoke_test",
]
HEADLESS_SHADER_DIAGNOSTIC = 'ERROR: Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)" is true. Continuing.'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--capture", action="store_true", help="Record a real Campaign match using scripted player intents")
    parser.add_argument("--interactions", action="store_true", help="Include selection changes and capture-event evidence in the match review")
    parser.add_argument("--test", action="append", choices=TESTS + ["hive_interaction_visual_harness"])
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ("SF_ALLOW_LIVE_BACKEND_TESTS", "SF_RANK_BACKEND_URL", "SF_VS_BACKEND_URL", "SF_OPS_CONFIG_URL"):
        env.pop(key, None)
    env["SF_PRESSURE_MATCH_OUTPUT"] = str(output)
    with tempfile.TemporaryDirectory(prefix="sf-pressure-") as folder:
        project = Path(folder)
        for item in ROOT.iterdir():
            if item.name not in {"project.godot", "override.cfg", ".git"}:
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        settings = (ROOT / "project.godot").read_text().replace(
            "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="SwarmfrontPressureChecks-{project.name}"', 1)
        (project / "project.godot").write_text(settings)
        (project / "override.cfg").write_text(
            '[swarmfront]\nrank/backend_url=""\nidentity/backend_url=""\n'
            'vs/backend_url=""\nops_config/remote_url=""\nanalytics/enabled=false\n')
        tests = args.test or (["hive_pressure_match_capture"] if args.capture else TESTS)
        for test in tests:
            cmd = [args.godot, "--path", str(project), "--script", f"res://tools/{test}.gd"]
            cmd += ["--rendering-method", "gl_compatibility", "--fixed-fps", "30"] if args.capture else ["--headless"]
            if args.interactions:
                cmd += ["--", "--interaction-review"]
            log = output / f"{test}.log"
            with log.open("w") as stream:
                result = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=600 if args.capture else 120)
            text = log.read_text()
            errors = [line for line in text.splitlines() if "ERROR:" in line and
                      (args.capture or line.strip() != HEADLESS_SHADER_DIAGNOSTIC)]
            if result.returncode or errors or "PASS" not in text:
                raise SystemExit(f"FAIL {test}: {log}\n{text[-6000:]}")
            print(f"PASS {test}: {log}", flush=True)


if __name__ == "__main__":
    main()
