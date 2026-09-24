"""Build a local review of native setup/lobby captures."""
import argparse
import html
from pathlib import Path

SCREENS = [
    ("free-setup", "Free Roll · setup"),
    ("flag-setup", "Capture the Flag · setup"),
    ("free-lobby", "Free Roll · lobby"),
    ("free-searching-fixture", "Searching · presentation fixture"),
    ("free-offline", "Free Roll · offline feedback"),
    ("paid-locked-setup", "Paid entry unavailable"),
    ("paid-setup", "Money Games · setup fixture"),
    ("paid-lobby", "Money Games · lobby fixture"),
    ("paid-offline", "Money Games · offline feedback"),
    ("paid-stage-race", "Stage Race · entry choices"),
    ("paid-contest-details", "Stage Race · contest details"),
    ("public-contests-offline", "Public contests · unavailable and retry"),
    ("insufficient-funds", "Insufficient balance · available exits"),
    ("free-setup-short-stress", "Setup · shorter logical viewport"),
    ("free-lobby-short-stress", "Lobby · shorter logical viewport"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    folder = parser.parse_args().folder.resolve()
    for name, _ in SCREENS:
        if not (folder / "native" / f"{name}.png").is_file():
            raise SystemExit(f"Missing native capture: {name}")
    options = "\n".join(f'<option value="{name}">{html.escape(label)}</option>' for name, label in SCREENS)
    page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Swarmfront · Setup and lobby readability</title>
<style>
:root{color-scheme:dark;font:17px/1.5 system-ui;background:#0e1015;color:#ebedf3;--preview:390px}body{max-width:1000px;margin:auto;padding:32px 24px}h1{font-size:clamp(28px,5vw,44px);line-height:1.15}p{max-width:750px;color:#b7bfcc}a{color:#f7ba30}select,button{font:inherit;color:inherit;background:#18202a;border:1px solid #64718a;border-radius:8px;padding:10px;min-height:44px;max-width:100%;margin:4px 8px 4px 0}figure{margin:24px 0;width:var(--preview);max-width:100%}img{display:block;width:100%;border:1px solid #414b5d;border-radius:12px}figcaption{margin-top:12px}.note{font-size:14px}footer{border-top:1px solid #384354;margin-top:32px;padding-top:12px}
</style><body>
<h1>Choose a game.<br>See the next step.</h1>
<p>Larger setup choices, readable game details, and primary actions with Back outside the scrolling content. These are native captures from the running game.</p>
<p>The existing insufficient-balance background and Cancel art are retained. Restoring and enlarging the home and mode-button artwork remains required before finalizing the menus.</p>
<label for="screen">Screen</label><br><select id="screen" onchange="showScreen()">OPTIONS</select>
<div><label for="width">Preview width</label> <select id="width" onchange="document.documentElement.style.setProperty('--preview',this.value+'px')"><option>360</option><option selected>390</option><option>430</option></select></div>
<figure><a id="original" href="native/free-setup.png"><img id="preview" src="native/free-setup.png" alt="Free Roll setup with larger mode choices and fixed Continue and Back buttons"></a><figcaption id="caption">Free Roll · setup</figcaption></figure>
<footer><p class="note">Disposable player data and offline services. Search, paid-entry and wallet views use local fixtures; they do not establish live matchmaking, paid availability or real settlement. Short-view captures explicitly stress a 1080×1500 logical viewport; production scaling is unchanged. Preview widths are for comparison. Physical touch sizes, safe areas and performance remain in the combined device pass.</p><p><a href="verification.json">Verification record</a></p></footer>
<script>
function showScreen(){const s=document.getElementById('screen');const source='native/'+s.value+'.png';const label=s.selectedOptions[0].textContent;document.getElementById('preview').src=source;document.getElementById('preview').alt=label;document.getElementById('original').href=source;document.getElementById('caption').textContent=label;}
</script></body></html>'''.replace("OPTIONS", options)
    (folder / "index.html").write_text(page)
    print(folder / "index.html")


if __name__ == "__main__":
    main()
