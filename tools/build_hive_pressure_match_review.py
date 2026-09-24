"""Build a local video review from a complete production-match pressure capture."""
import argparse
import html
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    folder = args.capture.resolve()
    evidence = json.loads((folder / "match-evidence.json").read_text())
    frames = evidence["frames"]
    if frames != 240 or evidence["first_pressure_ms"] < 0:
        raise SystemExit("Require a complete eight-second pressure sequence")
    expected = {f"{frame:04d}.png" for frame in range(frames)}
    if {p.name for p in (folder / "frames").glob("*.png")} != expected:
        raise SystemExit("Capture frames are incomplete or contain stale extras")
    log = (folder / "hive_pressure_match_capture.log").read_text()
    if "HIVE_PRESSURE_MATCH_CAPTURE: PASS" not in log or "ERROR:" in log:
        raise SystemExit("Capture must finish validation and clean shutdown")
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        raise SystemExit("ffmpeg and ffprobe are required")
    video = folder / "pressure-match.mp4"
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                    "-framerate", str(evidence["fps"]), "-i", str(folder / "frames/%04d.png"),
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", "-c:v", "libx264", "-crf", "18",
                    "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(video)], check=True)
    probe = json.loads(subprocess.check_output([
        ffprobe, "-v", "error", "-select_streams", "v:0", "-count_frames",
        "-show_entries", "stream=nb_read_frames,duration,r_frame_rate,width,height", "-of", "json", str(video)], text=True))["streams"][0]
    if int(probe["nb_read_frames"]) != frames or probe["r_frame_rate"] != "30/1":
        raise SystemExit("Encoded video does not match the capture")
    (folder / "video-verification.json").write_text(json.dumps(probe, indent=2) + "\n")
    name = html.escape(folder.name, quote=True)
    page = """<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Swarmfront · Pressure in play</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#11171c;color:#ecf0f1;font:16px/1.6 system-ui,sans-serif}
main{max-width:1080px;margin:auto;padding:40px 24px}small{color:#d7ac61;letter-spacing:.13em}
h1{font-size:clamp(32px,5vw,56px);line-height:1.1;margin:18px 0}p{max-width:720px;color:#aebbc4}
.review{display:grid;grid-template-columns:minmax(260px,420px) 1fr;gap:32px;margin-top:32px}
video{width:100%;max-height:78vh;background:#080b0d;border:1px solid #364149;border-radius:12px}
button,a{font:inherit;color:#f5d491}button{background:#202a32;border:1px solid #50606b;border-radius:8px;padding:9px 13px;cursor:pointer;margin:0 6px 8px 0}
.note{border-top:1px solid #364149;padding-top:18px;font-size:14px}.stamp{font-variant-numeric:tabular-nums;color:#d7ac61}
@media(max-width:700px){.review{grid-template-columns:1fr}main{padding:28px 18px}}
</style><main><small>SWARMFRONT / ARENA VISUAL FINISH</small><h1>Pressure, in play.</h1>
<p>The stronger crown warning is now in the game. This capture follows real combat in Campaign's Center Axis, with the production bot and scripted player lane commands.</p>
<div class="review"><video id="v" controls loop playsinline preload="metadata" poster="CAPTURE/frames/0004.png" src="CAPTURE/pressure-match.mp4"></video>
<div><h2>Watch the lower central hive</h2><p>The vents rise on either side of the power number as hostile units arrive. The effect clears when ownership changes or pressure recovers. Lanes and units continue through the same scene.</p>
<button data-speed="1">1×</button><button data-speed="0.5">½ speed</button><button data-speed="0.25">¼ speed</button><br>
<button id="back">← Frame</button><button id="next">Frame →</button><p class="stamp" id="time">0.00 / 8.00 s</p>
<p><a href="CAPTURE/pressure-match.mp4">Open video</a> · <a href="CAPTURE/match-evidence.json">Match evidence</a></p>
<p class="note">Native Godot 4.7.1 desktop capture, 30 frames per second. Forced rendering and image readback make this a visual review, not a performance test. Physical iPhone and Android profiling remains open.</p></div></div></main>
<script>const v=document.querySelector('#v');document.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>v.playbackRate=Number(b.dataset.speed));
function step(d){v.pause();v.currentTime=Math.max(0,Math.min((v.duration||8)-1/30,v.currentTime+d/30))}
document.querySelector('#back').onclick=()=>step(-1);document.querySelector('#next').onclick=()=>step(1);
v.ontimeupdate=()=>document.querySelector('#time').textContent=v.currentTime.toFixed(2)+' / 8.00 s';</script></html>
""".replace("CAPTURE", name)
    if evidence.get("interaction_review"):
        page = page.replace("Pressure in play", "Selection and capture")
        page = page.replace("Pressure, in play.", "Selection. Capture. Clear.")
        page = page.replace("The stronger crown warning is now in the game. This capture follows real combat in Campaign's Center Axis, with the production bot and scripted player lane commands.",
                            "A quick selection lock and a short sweep in the new owner's color, alongside the approved pressure treatment. Recorded in Campaign's Center Axis with the production bot and scripted player commands.")
        page = page.replace("The vents rise on either side of the power number as hostile units arrive. The effect clears when ownership changes or pressure recovers. Lanes and units continue through the same scene.",
                            "Selection seats into steady white brackets at the skirt. Ownership changes trigger a fitted team-colored sweep; power and owner color update immediately. Selection clears midway, returns, then moves to the upper-left hive. Pressure, traffic and tier changes continue through the same scene.")
        fixture = folder.parent / "fixture"
        if all((fixture / f"{mode}.png").exists() for mode in ("full", "reduced", "none")):
            gallery = '<section style="margin-top:40px"><h2>All tiers and motion settings</h2><p>Native presentation fixtures. These images use explicit samples to compare the three hive sizes; the video above records a running match.</p>'
            for mode, title in (("full", "Full motion"), ("reduced", "Reduced motion"), ("none", "Animations disabled")):
                gallery += f'<details><summary style="cursor:pointer;padding:12px 0">{title}</summary><a href="fixture/{mode}.png"><img style="width:100%;border-radius:12px" src="fixture/{mode}.png" alt="{title}: selection and capture across small, medium and large hives"></a></details>'
            page = page.replace("</main>", gallery + "</section></main>")
    (folder.parent / "index.html").write_text(page)
    print(f"Review: {folder.parent / 'index.html'}; verified {frames} frames")


if __name__ == "__main__":
    main()
