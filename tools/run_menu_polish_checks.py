"""Review menu presentation with isolated player data and offline services."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HEADLESS_SHADER_DIAGNOSTIC = 'ERROR: Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)" is true. Continuing.'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--capture", action="store_true")
    parser.add_argument("--test", action="append", required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ("SF_ALLOW_LIVE_BACKEND_TESTS", "SF_RANK_BACKEND_URL", "SF_VS_BACKEND_URL", "SF_OPS_CONFIG_URL"):
        env.pop(key, None)
    env["SF_MENU_CAPTURE_DIR"] = str(output) if args.capture else ""
    env["SF_CAMPAIGN_CAPTURE_DIR"] = str(output) if args.capture else ""
    with tempfile.TemporaryDirectory(prefix="sf-menu-") as folder:
        project = Path(folder)
        for item in ROOT.iterdir():
            if item.name not in {"project.godot", "override.cfg", ".git"}:
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        settings = (ROOT / "project.godot").read_text().replace(
            "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="SwarmfrontCampaignChecks-{project.name}"', 1)
        (project / "project.godot").write_text(settings)
        (project / "override.cfg").write_text(
            '[swarmfront]\nrank/backend_url=""\nidentity/backend_url=""\n'
            'vs/backend_url=""\nops_config/remote_url=""\nanalytics/enabled=false\n')
        for test in args.test:
            if not test.replace("_", "").isalnum() or not (ROOT / "tools" / f"{test}.gd").is_file():
                raise SystemExit(f"Unknown menu check: {test}")
            cmd = [args.godot, "--path", str(project), "--script", f"res://tools/{test}.gd"]
            cmd += ["--rendering-method", "gl_compatibility"] if args.capture else ["--headless"]
            log = output / f"{test}.log"
            with log.open("w") as stream:
                result = subprocess.run(cmd, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=240)
            text = log.read_text()
            errors = [line for line in text.splitlines() if "ERROR:" in line and
                      (args.capture or line.strip() != HEADLESS_SHADER_DIAGNOSTIC)]
            if result.returncode or errors or "PASS" not in text:
                raise SystemExit(f"FAIL {test}: {log}\n{text[-5000:]}")
            print(f"PASS {test}: {log}", flush=True)


if __name__ == "__main__":
    main()
