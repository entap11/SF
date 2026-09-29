"""Package native buff captures into a local, self-contained visual review."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import html
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    output = args.directory.resolve()
    entries = json.loads((output / "effects/gallery.json").read_text())

    def encode(entry):
        folder = output / "effects" / entry["directory"]
        subprocess.run([
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30",
            "-i", str(folder / "frames/%03d.png"), "-frames:v", str(entry["frames"]),
            "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p",
            "-movflags", "+faststart", str(folder / "preview.mp4")
        ], check=True, timeout=120)

    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(encode, entries))
    cards = []
    navigation = []
    for entry in entries:
        key = html.escape(entry["directory"], quote=True)
        name = html.escape(entry["name"])
        navigation.append(f'<a href="#{key}">{name}</a>')
        stills = "".join(
            f'<figure><img loading="lazy" src="effects/{key}/{stage}.png" alt="{name}: {label}"><figcaption>{label}</figcaption></figure>'
            for stage, label in [("activation", "Activation"), ("expiry", "Expiry / release"), ("reduced", "Reduced VFX")]
        )
        cards.append(f'''<section class="effect" id="{key}"><div class="eyebrow">BUFF PRESENTATION</div>
        <h2>{name}</h2><p>{html.escape(entry["description"])}</p>
        <video controls playsinline loop preload="none" poster="effects/{key}/active.png"><source src="effects/{key}/preview.mp4" type="video/mp4"></video>
        <div class="stills">{stills}</div></section>''')
    menu_cards = "".join(
        f'<figure><img loading="lazy" src="menu-verified/{path}.png" alt="{label}"><figcaption>{label}</figcaption></figure>'
        for path, label in [("loadout-720x1280", "Loadout & owned"), ("store-720x1280", "Store · Classic"), ("lane-premium", "Premium"), ("lane-elite", "Elite")]
    )
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Swarmfront · Buff presentation review</title><style>
    :root{color-scheme:dark;font-family:system-ui,sans-serif;background:#090e15;color:#edf2f7}*{box-sizing:border-box}
    body{margin:0}main{max-width:1100px;margin:auto;padding:44px 24px 80px}h1{font-size:clamp(34px,5vw,60px);margin:14px 0}h2{font-size:30px;margin:10px 0}p{color:#bbc8d8;line-height:1.6;max-width:78ch}
    .eyebrow{font-size:12px;letter-spacing:.18em;color:#e5c573;font-weight:700}nav{display:flex;flex-wrap:wrap;gap:8px;margin:30px 0}a{color:#eed087}nav a{padding:10px 13px;border:1px solid #354258;border-radius:24px;text-decoration:none;font-size:14px}
    .effect{padding:30px 0;border-top:1px solid #2a3545;scroll-margin-top:12px}video{display:block;width:100%;max-height:650px;background:#080d13;border:1px solid #2a3545;border-radius:16px}
    .stills{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}figure{margin:0}img{display:block;max-width:100%;height:auto;border:1px solid #2a3545;border-radius:10px}figcaption{color:#aebfd4;font-size:13px;padding:10px 0}.phones{display:grid;grid-template-columns:repeat(4,1fr);gap:18px}.note{font-size:14px}.hud{max-width:850px;margin:24px auto}footer{border-top:1px solid #2a3545;padding-top:24px;color:#aebfd4}
    @media(max-width:700px){main{padding:24px 16px}.phones{grid-template-columns:repeat(2,1fr)}.stills{grid-template-columns:1fr}h2{font-size:25px}}
    </style><main><div class="eyebrow">SWARMFRONT / SEPTEMBER 25, 2026</div><h1>Know what is active.</h1>
    <p>Eleven more buff families now have distinct target or global cues, simulation-driven countdowns and an ending. Freeze Lane keeps its approved treatment. The buff store and loadout use larger artwork, readable effects, and a persistent Back button.</p>
    <p class="note">These are native desktop captures. Effect clips use the production renderer with staged snapshots; they do not establish phone performance or a completed device playtest. Global hive examples affect the two original hives; the third remains outside that scope.</p>
    <nav><a href="#menus">Catalog & loadout</a><a href="#hud">Player & opponent strips</a><a href="../buff-polish-2026-09-25/freeze-preview/freeze-lane.mp4">Approved Freeze Lane</a>'''
    document += "".join(navigation) + '</nav><section class="effect" id="menus"><div class="eyebrow">PHONE WINDOW REVIEW</div><h2>Room for the artwork and the explanation.</h2><p>Loadout and store have separate views. Classic, Premium and Elite remain explicit; target and actual duration appear with each store item. Existing equip, inventory and cart controls retain their behavior.</p><div class="phones">' + menu_cards + '</div></section>'
    document += '<section class="effect" id="hud"><h2>Readable state, visible medallions.</h2><p>Ready icons have a clear state footer. Active countdowns and the WAIT cooldown follow simulation time, including pause. Opponent strips retain their existing concealed-loadout and used-slot behavior.</p><img class="hud" src="hud/player-opponent-strips.png" alt="Ready, active, cooldown, locked and exhausted player and opponent strips"></section>'
    document += "".join(cards)
    verification = output / "verification.json"
    if verification.exists():
        status = json.loads(verification.read_text()).get("readiness", {}).get("status", "")
        if status == "incomplete_timeout":
            document += '<p class="note">Broader readiness remains incomplete: the player-configuration matrix reached its 15-minute deadline. Focused buff and native UI checks passed.</p>'
        document += '<p class="note"><a href="verification.json">Validation results and source hashes</a></p>'
    document += '<footer>Next: combined iPhone/Android touch, overlap and performance checks; balance proposals from observed play. General menu VFX/UI/UX follows the buff sprint.</footer></main></html>'
    (output / "index.html").write_text(document)
    print(f"Review: {output / 'index.html'} ({len(entries)} effect videos)")


if __name__ == "__main__":
    main()
