"""Run signup regressions using isolated player data and offline service seams."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TESTS = [
    "onboarding_backend_identity_success_smoke_test",
    "onboarding_restart_smoke_test",
    "onboarding_debug_offline_unblock_smoke_test",
    "onboarding_rank_registration_smoke_test",
    "onboarding_requires_backend_identity_smoke_test",
    "onboarding_panel_smoke_test",
    "onboarding_panel_readability_smoke_test",
    "player_session_auth_seam_smoke_test",
    "account_deletion_ui_smoke_test",
]
# Godot 4.7.1's dummy renderer reports this for existing menu shaders. Keep
# the diagnostic in the log; it is unrelated to account behavior. All other
# engine errors, script errors, assertion failures and missing passes fail.
HEADLESS_SHADER_DIAGNOSTIC = 'ERROR: Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)" is true. Continuing.'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--logs", type=Path, default=Path(tempfile.gettempdir()) / "sf-signup-checks")
    parser.add_argument("--test", action="append", choices=TESTS)
    args = parser.parse_args()
    args.logs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ("SF_ALLOW_LIVE_BACKEND_TESTS", "SF_RANK_BACKEND_URL", "SF_VS_BACKEND_URL", "SF_OPS_CONFIG_URL"):
        env.pop(key, None)
    for test in args.test or TESTS:
        with tempfile.TemporaryDirectory(prefix="sf-signup-") as folder:
            project = Path(folder)
            for item in ROOT.iterdir():
                if item.name not in {"project.godot", "override.cfg", ".git"}:
                    (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
            settings = (ROOT / "project.godot").read_text().replace(
                "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
                f'config/custom_user_dir_name="SwarmfrontSignupChecks-SwarmfrontDeletionTest-{project.name}"', 1)
            (project / "project.godot").write_text(settings)
            (project / "override.cfg").write_text(
                '[swarmfront]\nrank/backend_url=""\nidentity/backend_url=""\n'
                'vs/backend_url=""\nops_config/remote_url=""\nanalytics/enabled=false\n')
            phases = ["signup", "offline_restart", "online_restart", "second_online_restart"] if test == "onboarding_restart_smoke_test" else [None]
            evidence = []
            for phase in phases:
                label = f"{test}-{phase}" if phase else test
                log = args.logs / f"{label}.log"
                with log.open("w") as stream:
                    result = subprocess.run(
                        [args.godot, "--headless", "--path", str(project), "--script", f"res://tools/{test}.gd"],
                        env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
                output = log.read_text()
                missing_pass = "PASS" not in output and test != "player_session_auth_seam_smoke_test"
                errors = [line for line in output.splitlines()
                          if "ERROR:" in line and line.strip() != HEADLESS_SHADER_DIAGNOSTIC]
                if result.returncode or errors or missing_pass:
                    raise SystemExit(f"FAIL {label}: {log}\n{output[-6000:]}")
                if phase:
                    prefix = "ONBOARDING_RESTART_EVIDENCE: "
                    record = json.loads(next(line[len(prefix):] for line in output.splitlines() if line.startswith(prefix)))
                    if not record["passed"] or record["phase"] != phase or record["process_id"] in {row["process_id"] for row in evidence}:
                        raise SystemExit(f"FAIL {label}: restart evidence invalid")
                    evidence.append(record)
                    (args.logs / "onboarding_restart_evidence.json").write_text(json.dumps(evidence, indent=2) + "\n")
                print(f"PASS {label}: {log}", flush=True)


if __name__ == "__main__":
    main()
