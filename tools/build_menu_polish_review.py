"""Build a local review page from native menu captures."""
import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    args = parser.parse_args()
    folder = args.folder.resolve()
    required = ["home-1080x1920", "free-roll-0", "free-roll-cluster-3-2", "free-roll-1", "free-roll-2", "money-games-live", "money-games-contests", "money-games-add-funds"]
    for name in required:
        if not (folder / "final" / (name + ".png")).is_file():
            raise SystemExit(f"Missing native capture: {name}")
    page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Swarmfront · Menu readability</title>
<style>
:root{color-scheme:dark;font:17px/1.5 system-ui;background:#0b0e13;color:#ebedf3;--phone:390px}
body{max-width:1100px;margin:auto;padding:36px 24px}h1{font-size:clamp(28px,5vw,48px);line-height:1.12;margin:12px 0 20px}h2{margin-top:48px;font-size:24px}p{max-width:760px;color:#bfc7d4}a{color:#f7c96a}button,select{font:inherit;color:inherit;border:1px solid #505e73;background:#171e29;border-radius:8px;padding:10px 16px;margin:4px 6px 4px 0;min-height:44px}button[aria-pressed=true]{border-color:#f7ba30;color:#ffe1a1}.row{display:flex;gap:28px;flex-wrap:wrap;align-items:flex-start}.phone{width:var(--phone);max-width:100%;margin:0}.phone img{width:100%;height:auto;display:block;border:1px solid #414c5d;border-radius:16px;background:#101319}.phone figcaption{margin:12px 0 20px;color:#bec8d5}.label{font-size:13px;letter-spacing:.12em;color:#e4bd63}.controls{margin:24px 0}.note{font-size:14px}.single{margin-top:24px}.gallery{display:flex;flex-wrap:wrap;gap:24px}.gallery img{width:190px;border-radius:8px}details{margin-top:30px}summary{cursor:pointer;padding:12px 0}footer{margin-top:48px;padding-top:20px;border-top:1px solid #333e4e}
</style>
<body>
<div class="label">SWARMFRONT · SEPTEMBER 24, 2026</div>
<h1>Five choices.<br>Room to read.</h1>
<p>Large hex buttons, related choices together, and a Back action that stays in reach. These are captures from the running game.</p>
<p><strong>Recommended for portrait: two–one–two.</strong> The wider buttons leave more room for names. Three-over-two condenses the cluster further; both use the same text size. The seven live-match choices fit on this reference screen without scrolling.</p>
<div class="controls"><span>Preview width: </span><button onclick="setPreviewWidth(360,this)" aria-pressed="false">360 px</button><button onclick="setPreviewWidth(390,this)" aria-pressed="true">390 px</button><button onclick="setPreviewWidth(430,this)" aria-pressed="false">430 px</button></div>
<div class="row">
<figure class="phone"><a href="final/free-roll-0.png"><img src="final/free-roll-0.png" alt="Free Roll: wide hex buttons arranged two, one, two, with two flag matches below"></a><figcaption>Two–one–two · wider labels</figcaption></figure>
<figure class="phone"><a href="final/free-roll-cluster-3-2.png"><img src="final/free-roll-cluster-3-2.png" alt="Free Roll: five hex buttons arranged three above two"></a><figcaption>Three-over-two · shorter cluster</figcaption></figure>
</div>
<h2>The rest of the path</h2>
<p>Campaign leads on home. Free Roll and Money Games have larger entries. Inside each hub, categories keep related modes together. Money Games displays the selected entry and existing access states.</p>
<label for="screen">Screen </label><select id="screen" onchange="showMenuScreen(this.value)">
<option value="home-1080x1920">Home</option><option value="free-roll-1">Free Roll · Contests</option><option value="free-roll-2">Free Roll · Bot modes</option><option value="money-games-live">Money Games · Live matches</option><option value="money-games-contests">Money Games · Contests</option><option value="money-games-add-funds">Money Games · Add-funds state</option>
</select>
<figure class="phone single"><a id="screen-link" href="final/home-1080x1920.png"><img id="screen-image" src="final/home-1080x1920.png" alt="Selected native menu screen"></a><figcaption id="screen-caption">Home</figcaption></figure>
<details><summary>Previous home</summary><figure class="phone"><a href="baseline/main.png"><img loading="lazy" src="baseline/main.png" alt="Previous home with a large replay area and small bottom mode buttons"></a><figcaption>Captured before this pass with isolated player data.</figcaption></figure></details>
<details><summary>Window-size references</summary><p class="note">Requested window sizes use the game's existing viewport scaling. The short and 720×1280 references retain the 1080×1920 render surface; the tall reference expands it to 1080×2343. These captures do not establish physical touch-target sizes.</p><div class="gallery">
<a href="final/home-944x2048.png"><img loading="lazy" src="final/home-944x2048.png" alt="Home: tall portrait"></a>
<a href="final/home-720x1280.png"><img loading="lazy" src="final/home-720x1280.png" alt="Home: small portrait"></a>
<a href="final/home-1080x1500.png"><img loading="lazy" src="final/home-1080x1500.png" alt="Home render surface at the short window reference"></a>
<a href="final/money-games-1080x1500.png"><img loading="lazy" src="final/money-games-1080x1500.png" alt="Money Games render surface at the short window reference"></a>
</div></details>
<footer><p class="note">Money Games uses an isolated local wallet fixture. No purchase or real settlement was performed. Preview widths help compare density; physical-device readability, safe areas and performance remain in the combined validation pass.</p><p class="note"><a href="verification.json">Verification record</a> · Native Godot 4.7.1 captures · No gameplay or economy rule changes.</p></footer>
<script>
function setPreviewWidth(n,b){document.documentElement.style.setProperty('--phone',n+'px');document.querySelectorAll('.controls button').forEach(x=>x.setAttribute('aria-pressed',x===b?'true':'false'));}
function showMenuScreen(name){const src='final/'+name+'.png';document.getElementById('screen-image').src=src;document.getElementById('screen-link').href=src;document.getElementById('screen-caption').textContent=document.getElementById('screen').selectedOptions[0].textContent;}
</script>
</body></html>'''
    (folder / "index.html").write_text(page)
    print(f"Review: {folder / 'index.html'}")


if __name__ == "__main__":
    main()
