"""Compare native captures of the accepted menu layout with restored button art."""
import argparse
import json
from pathlib import Path


SCREENS = {
    "home-1080x1920": "Home",
    "free-roll-0": "Free Roll · Live matches",
    "free-roll-1": "Free Roll · Contests",
    "free-roll-2": "Free Roll · Bot modes",
    "free-roll-cluster-3-2": "Free Roll · Three-over-two comparison",
    "money-games-live": "Money Games · Live matches",
    "money-games-contests": "Money Games · Contests",
    "money-games-add-funds": "Money Games · Add-funds state",
    "home-944x2048": "Home · Tall portrait",
    "money-games-944x2048": "Money Games · Tall portrait",
    "home-720x1280": "Home · Small window",
    "money-games-720x1280": "Money Games · Small window",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    folder = parser.parse_args().folder.resolve()
    for screen in SCREENS:
        for stage in ("baseline", "final"):
            path = folder / stage / f"{screen}.png"
            if not path.is_file():
                raise SystemExit(f"Missing native capture: {path}")
    page = '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Swarmfront · Artwork fit</title>
<style>
:root{color-scheme:dark;--phone:390px;font:16px/1.5 system-ui;background:#0e1015;color:#ebedf3}
body{max-width:1180px;margin:auto;padding:28px 24px 60px}h1{font-size:clamp(30px,5vw,46px);line-height:1.1;margin:12px 0 18px}
p{max-width:800px;color:#b5bfcd}.eyebrow{color:#f7ba30;font-size:13px;letter-spacing:.13em}
button,select{font:inherit;padding:10px 14px;background:#171c24;color:inherit;border:1px solid #596576;border-radius:8px;min-height:44px}
button{cursor:pointer}button[aria-pressed=true]{border-color:#f7ba30;color:#ffe1a1}.controls{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:22px 0}
.pair{display:flex;gap:28px;flex-wrap:wrap;align-items:flex-start}figure{width:var(--phone);max-width:100%;margin:0}figcaption{margin:0 0 12px;color:#b5bfcd}
img{width:100%;display:block;border:1px solid #404a59;border-radius:12px}a{color:#f7cf76}.note{font-size:14px}.gallery{display:flex;gap:18px;flex-wrap:wrap}.gallery figure{width:180px}.gallery figcaption{margin:8px 0;font-size:14px}
details{margin-top:32px}summary{cursor:pointer;min-height:44px}footer{margin-top:40px;border-top:1px solid #343c48;padding-top:16px}
</style><body>
<div class="eyebrow">SWARMFRONT · SEPTEMBER 25, 2026</div>
<h1>Original artwork. Current layout.</h1>
<p>The existing button sprites are back at larger sizes. Home badges sit beside the live labels; mode plates fill the cluster width above their labels and entry details. Each sprite keeps its original proportions.</p>
<p>Review the fit and spacing before the next menu pass. Campaign retains its live heading: the older sprite says “Map Jukebox” and belongs to a different destination.</p>
<div class="controls"><label for="screen">Screen</label><select id="screen"></select></div>
<div class="controls" id="widths"><span>Preview width</span><button data-width="360" aria-pressed="false">360 px</button><button data-width="390" aria-pressed="true">390 px</button><button data-width="430" aria-pressed="false">430 px</button></div>
<div class="pair"><figure><figcaption>Accepted layout · placeholders</figcaption><a id="before-link"><img id="before" alt="Previous menu layout with placeholder surfaces"></a></figure><figure><figcaption>Restored artwork · fit review</figcaption><a id="after-link"><img id="after" alt="The same menu with its original button artwork restored"></a></figure></div>
<details><summary>All restored screens</summary><div class="gallery" id="gallery"></div></details>
<footer><p class="note">These are native Godot captures with isolated player data. Money Games uses a local wallet fixture. Phone usability and performance remain for the combined device pass. Preview widths do not establish physical target size; existing game viewport scaling is unchanged.</p><p class="note"><a href="verification.json">Verification record</a></p></footer>
<script>
const screens=SCREEN_DATA;
const select=document.getElementById('screen');
for(const [name,label] of Object.entries(screens)){
  select.add(new Option(label,name));
  const figure=document.createElement('figure'),a=document.createElement('a'),img=document.createElement('img'),caption=document.createElement('figcaption');
  a.href='final/'+name+'.png';img.src=a.href;img.alt=label;img.loading='lazy';caption.textContent=label;
  a.append(img);figure.append(a,caption);document.getElementById('gallery').append(figure);
}
function show(){for(const [id,stage] of [['before','baseline'],['after','final']]){const url=stage+'/'+select.value+'.png';document.getElementById(id).src=url;document.getElementById(id+'-link').href=url;}}
select.addEventListener('change',show);select.value='free-roll-0';show();
document.querySelectorAll('[data-width]').forEach(button=>button.addEventListener('click',()=>{document.documentElement.style.setProperty('--phone',button.dataset.width+'px');document.querySelectorAll('[data-width]').forEach(other=>other.setAttribute('aria-pressed',String(other===button)));}));
</script></body></html>'''
    (folder / "index.html").write_text(page.replace("SCREEN_DATA", json.dumps(SCREENS)))
    print(folder / "index.html")


if __name__ == "__main__":
    main()
