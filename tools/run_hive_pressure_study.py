"""Build the offline current/refined pressure comparison; no game autoloads."""
import argparse, os, shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot',required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--motion',choices=['full','reduced','none'],default='full')
p.add_argument('--capture',action='store_true')
p.add_argument('--stills',action='store_true')
a=p.parse_args()
out=a.output.resolve(); runtime=out/'runtime'
for folder in ['tools','scripts/hive','scripts/sim','assets','shaders']: (runtime/folder).mkdir(parents=True,exist_ok=True)
for name in ['hive_transition_study','hive_pressure_study']:
 dest=runtime/'tools'/name
 if not dest.exists(): dest.symlink_to(ROOT/'tools'/name,target_is_directory=True)
for name in ['hive_distress_light.gd','hive_distress_rules.gd','hive_transition_timing.gd']:
 shutil.copyfile(ROOT/'scripts/hive'/name,runtime/'scripts/hive'/name)
shutil.copyfile(ROOT/'shaders/hive_pressure.gdshader',runtime/'shaders/hive_pressure.gdshader')
shutil.copyfile(ROOT/'scripts/sim/hive_growth_rules.gd',runtime/'scripts/sim/hive_growth_rules.gd')
for name in ['hive_small_flatop.png','hive_medium_flatop.png','hive_large_flatop_alpha.png']:
 shutil.copyfile(ROOT/'assets/sprites/sf_skin_v1'/name,runtime/'assets'/name)
shutil.copyfile(ROOT/'assets/fonts/brand/Iceland/Iceland-Regular.ttf',runtime/'assets/Iceland-Regular.ttf')
(runtime/'project.godot').write_text('''config_version=5
[application]
config/name="Swarmfront Pressure Study"
config/use_custom_user_dir=true
config/custom_user_dir_name="SwarmfrontPressureStudy"
[display]
window/size/viewport_width=1440
window/size/viewport_height=1000
window/size/window_width_override=1152
window/size/window_height_override=800
window/vsync/vsync_mode=0
[rendering]
renderer/rendering_method="gl_compatibility"
''')
automated=a.capture or a.stills
with tempfile.TemporaryDirectory(prefix='.pressure-capture-',dir=out) as staging:
 env=os.environ.copy(); env['SF_PRESSURE_OUTPUT']=staging if automated else str(out); env['SF_PRESSURE_MOTION']=a.motion
 cmd=[a.godot,'--path',str(runtime),'--script','res://tools/hive_pressure_study/study.gd']
 if automated: cmd+=['--minimized','--','--capture' if a.capture else '--stills']
 with (out/'capture.log').open('w') as log:
  r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300 if automated else None)
 text=(out/'capture.log').read_text()
 if r.returncode or 'ERROR' in text: raise SystemExit(text)
 if automated:
  if 'HIVE_PRESSURE_REVIEW: PASS' not in text: raise SystemExit('Capture ended before validation completed.\n'+text)
  expected=range(576) if a.capture else [15,38,85,153,173,300,325,475,500]
  frames=Path(staging)/'frames'
  if not all((frames/f'{i:04d}.png').is_file() for i in expected): raise SystemExit('Incomplete capture')
  if (out/'frames').exists(): shutil.rmtree(out/'frames')
  shutil.move(str(frames),str(out/'frames'))
 print(text)
