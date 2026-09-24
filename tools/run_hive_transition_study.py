"""Build an offline minimal Godot project for the hive transformation visual study."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    project = output / 'runtime'
    (project / 'tools').mkdir(parents=True, exist_ok=True)
    (project / 'assets').mkdir(exist_ok=True)
    (project / 'scripts/hive').mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'scripts/hive/hive_transition_timing.gd',project/'scripts/hive/hive_transition_timing.gd')
    source = project / 'tools/hive_transition_study'
    if not source.exists():
        source.symlink_to(ROOT / 'tools/hive_transition_study', target_is_directory=True)
    asset_root = ROOT / 'assets/sprites/sf_skin_v1'
    for name in ['hive_small_flatop.png', 'hive_medium_flatop.png', 'hive_large_flatop_alpha.png']:
        shutil.copyfile(asset_root/name, project/'assets'/name)
    shutil.copyfile(ROOT/'assets/fonts/brand/Iceland/Iceland-Regular.ttf', project/'assets/Iceland-Regular.ttf')
    (project/'project.godot').write_text('''config_version=5
[application]
config/name="Swarmfront Transformation Study"
config/use_custom_user_dir=true
config/custom_user_dir_name="SwarmfrontTransformationStudy"
[display]
window/size/viewport_width=1440
window/size/viewport_height=1000
window/size/window_width_override=1152
window/size/window_height_override=800
window/vsync/vsync_mode=0
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
''')
    env = os.environ.copy()
    env['SF_TRANSITION_OUTPUT'] = str(output)
    cmd=[args.godot,'--path',str(project),'--script','res://tools/hive_transition_study/study.gd']
    if args.check:
        cmd+=['--headless','--','--check']
    elif args.capture:
        cmd+=['--','--capture']
    with (output/('check.log' if args.check else 'capture.log' if args.capture else 'live.log')).open('w') as log:
        result=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT, timeout=300 if args.capture else 60 if args.check else None)
    if args.check or args.capture:
        output_text=(output/("check.log" if args.check else "capture.log")).read_text()
        if "SCRIPT ERROR" in output_text or "ERROR:" in output_text or ": PASS" not in output_text:
            raise SystemExit(output_text)
        print(output_text)
    raise SystemExit(result.returncode)

if __name__=='__main__':
    main()
