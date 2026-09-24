"""Encode the Godot pressure comparison and package the local review player."""
import argparse, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('output',type=Path)
a=p.parse_args();out=a.output.resolve();frames=out/'frames'
assert all((frames/f'{i:04d}.png').is_file() for i in range(576)), 'Incomplete capture'
log=(out/'capture.log').read_text()
assert 'ERROR' not in log, 'Capture contains engine errors'
assert 'HIVE_PRESSURE_REVIEW: PASS' in log, 'Capture did not finish validation'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','60','-i',str(frames/'%04d.png'),'-frames:v','576','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'hive-pressure.mp4')],check=True)
shutil.copyfile(frames/'0038.png',out/'poster.png')
shutil.copyfile(ROOT/'tools/hive_pressure_study/review.html',out/'index.html')
print(out/'index.html')
