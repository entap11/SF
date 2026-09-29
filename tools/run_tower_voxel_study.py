"""Run an isolated Godot tower-impact study without game autoloads or services."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    for name in ("check", "stills", "capture", "benchmark"):
        mode.add_argument(f"--{name}", action="store_true")
    args = parser.parse_args()
    out = args.output.resolve()
    runtime = out / "runtime"
    (runtime / "tools").mkdir(parents=True, exist_ok=True)
    (runtime / "assets").mkdir(exist_ok=True)
    source = runtime / "tools/tower_voxel_study"
    if not source.exists():
        source.symlink_to(ROOT / "tools/tower_voxel_study", target_is_directory=True)
    for name in ("unit_v5.png", "towers.png"):
        shutil.copyfile(ROOT / "assets/sprites/sf_skin_v1" / name, runtime / "assets" / name)
    shutil.copyfile(ROOT / "assets/fonts/brand/Iceland/Iceland-Regular.ttf", runtime / "assets/Iceland-Regular.ttf")
    (runtime / "project.godot").write_text('''config_version=5
[application]
config/name="Swarmfront Tower Voxel Study"
config/use_custom_user_dir=true
config/custom_user_dir_name="SwarmfrontTowerVoxelStudy"
[display]
window/size/viewport_width=1440
window/size/viewport_height=960
window/size/window_width_override=1152
window/size/window_height_override=768
window/vsync/vsync_mode=0
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
    env = os.environ.copy()
    env["SF_TOWER_OUTPUT"] = str(out)
    selected = next((name for name in ("check", "stills", "capture", "benchmark") if getattr(args, name)), "live")
    cmd = [args.godot, "--path", str(runtime), "--script", "res://tools/tower_voxel_study/study.gd"]
    if selected == "check":
        cmd.append("--headless")
    if selected != "live":
        cmd.extend(["--", f"--{selected}"])
    log_path = out / f"{selected}.log"
    with log_path.open("w") as log:
        result = subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=600 if selected == "capture" else 90 if selected != "live" else None)
    output = log_path.read_text()
    if selected != "live":
        if result.returncode or "SCRIPT ERROR" in output or "ERROR:" in output or ": PASS" not in output:
            raise SystemExit(output or f"Study exited {result.returncode}")
        print(output)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
