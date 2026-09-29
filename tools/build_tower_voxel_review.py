"""Validate and encode the Godot capture, then package a local review player."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FRAMES = 1080
FPS = 60


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    frames = out / "frames"
    missing = [i for i in range(FRAMES) if not (frames / f"{i:04d}.png").is_file()]
    if missing:
        raise SystemExit(f"Incomplete capture: {len(missing)} frames missing; first {missing[:8]}")
    log = (out / "capture.log").read_text()
    if f"PASS {FRAMES} frames" not in log or "ERROR:" in log or "SCRIPT ERROR" in log:
        raise SystemExit("Capture did not finish cleanly")
    video = out / "tower-voxel-impact.mp4"
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(FPS), "-i", str(frames / "%04d.png"), "-frames:v", str(FRAMES), "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
    probe = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=width,height,r_frame_rate,nb_read_frames,duration", "-of", "json", str(video)], check=True, text=True, capture_output=True)
    report = json.loads(probe.stdout)["streams"][0]
    if int(report["nb_read_frames"]) != FRAMES or report["r_frame_rate"] != "60/1" or (report["width"], report["height"]) != (1440, 960):
        raise SystemExit(f"Encoded capture does not match expected frames/size: {report}")
    (out / "video-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    shutil.copyfile(frames / "0086.png", out / "poster.png")
    shutil.copyfile(ROOT / "tools/tower_voxel_study/review.html", out / "index.html")
    print(out / "index.html")


if __name__ == "__main__":
    main()
