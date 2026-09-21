"""Run campaign checks with isolated, offline player data and optional captures."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--captures", type=Path, help="Use a graphics window and save screenshots here")
    parser.add_argument("--test", action="append", choices=["campaign_progress_smoke_test", "campaign_ui_smoke_test", "campaign_flow_smoke_test", "match_chrome_smoke_test", "match_hud_layout_smoke_test", "match_exit_intent_smoke_test", "player_buff_strip_touch_source_smoke_test", "buff_pointer_coordinate_smoke_test", "buff_strip_visibility_policy_smoke_test", "ad_manager_smoke_test", "ad_surface_smoke_test", "ad_surface_measurement_smoke_test", "ad_surface_placement_smoke_test", "outcome_overlay_smoke_test"])
    args = parser.parse_args()
    env = os.environ.copy()
    if args.captures:
        args.captures.mkdir(parents=True, exist_ok=True)
        env["SF_CAMPAIGN_CAPTURE_DIR"] = str(args.captures.resolve())
    else:
        env.pop("SF_CAMPAIGN_CAPTURE_DIR", None)
    with tempfile.TemporaryDirectory(prefix="sf-campaign-") as folder:
        project = Path(folder)
        for item in ROOT.iterdir():
            if item.name not in {"project.godot", "override.cfg", ".git"}:
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        settings = (ROOT / "project.godot").read_text()
        settings = settings.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\n'
                                    f'config/custom_user_dir_name="SwarmfrontCampaignChecks-{project.name}"', 1)
        (project / "project.godot").write_text(settings)
        (project / "override.cfg").write_text('[swarmfront]\nrank/backend_url=""\n'
                                               'identity/backend_url=""\nvs/backend_url=""\nanalytics/enabled=false\n')
        subprocess.run(["python3", str(ROOT / "tools/refresh_campaign_fingerprints.py"), "--check"], check=True)
        for test in (args.test or ["campaign_progress_smoke_test", "campaign_ui_smoke_test", "campaign_flow_smoke_test"]):
            cmd = [args.godot, "--path", str(project), "--script", f"res://tools/{test}.gd"]
            cmd += ["--rendering-method", "gl_compatibility"] if args.captures else ["--headless"]
            if test == "match_chrome_smoke_test":
                cmd += ["--", "--buff-targeting-device-harness"]
            log = (args.captures or Path(tempfile.gettempdir())) / f"{test}.log"
            with log.open("w") as stream:
                result = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT, text=True, timeout=240)
            output = log.read_text()
            if result.returncode or "SCRIPT ERROR" in output or "PASS" not in output:
                raise SystemExit(f"FAIL {test}: {log}")
            print(f"PASS {test}: {log}", flush=True)


if __name__ == "__main__":
    main()
