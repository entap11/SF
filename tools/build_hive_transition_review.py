"""Encode the actual Godot capture and package its local review player."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('output', type=Path)
args=parser.parse_args()
out=args.output.resolve()
frames=out/'frames'
assert all((frames/f'{i:04d}.png').is_file() for i in range(504)), 'Incomplete capture'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','60','-i',str(frames/'%04d.png'),'-frames:v','504','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'hive-transformation.mp4')],check=True)
shutil.copyfile(frames/'0046.png',out/'poster.png')
shutil.copyfile(ROOT/'tools/hive_transition_study/review.html',out/'index.html')
print(out/'index.html')
