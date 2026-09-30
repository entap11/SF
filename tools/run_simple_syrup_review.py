"""Run isolated, offline Simple Syrup checks, captures, bot games, or human play.

Examples:
  python3 tools/run_simple_syrup_review.py --check
  python3 tools/run_simple_syrup_review.py --capture
  python3 tools/run_simple_syrup_review.py --bots
  python3 tools/run_simple_syrup_review.py --play --variant start --structure tower
"""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PINNED = ROOT.parent / 'artifacts/toolchains/godot-4.7.1/Godot.app/Contents/MacOS/Godot'
HEADLESS_SHADER_DIAGNOSTIC = 'ERROR: Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)" is true. Continuing.'


def write_review_page(output):
    page = output / 'review.html'
    page.write_text('''<!doctype html>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Simple Syrup structure comparison</title>
<style>
body{background:#121923;color:#ecf0f4;font:16px system-ui;max-width:1000px;margin:auto;padding:24px}
h1{font-size:26px}p{line-height:1.5}select{font:inherit;padding:8px;margin:4px 16px 12px 0}
.boards{display:grid;grid-template-columns:1fr 1fr;gap:18px}img{width:100%;height:auto}
figure{margin:0}figcaption{font-weight:bold;margin:12px 0}a{color:#ffce6b}
</style>
<h1>Simple Syrup — paired structures</h1>
<p>All seven hive positions and legal hive connections are preserved.
Start triangles use the start hive and its two nearby neutrals; inner triangles
use the two nearby neutrals and the contested center hive.</p>
<p><strong>First human playtest: start triangles.</strong> Inner towers still crowd
the grown center hive and need a spacing/presentation pass before promotion.</p>
<label>Candidate <select id="candidate">
<option value="start_tower">Start triangles · towers</option>
<option value="start_barracks">Start triangles · barracks</option>
<option value="center_tower">Inner triangles · towers</option>
<option value="center_barracks">Inner triangles · barracks</option>
</select></label>
<label>Match moment <select id="moment"><option value="opening">Opening</option>
<option value="20s">20 seconds</option><option value="later">60 seconds</option></select></label>
<div class="boards"><figure><figcaption>Original</figcaption><img id="before" alt="Original gameplay capture"></figure>
<figure><figcaption id="caption">Candidate</figcaption><img id="after" alt="Candidate gameplay capture"></figure></div>
<p>Actual desktop Godot rendering at 720 × 1565, scripted local-player commands
against the production medium Balancer. These show real matches, not a human or
phone-device playtest. Later boards differ because gameplay has progressed.</p>
<p><a id="record" href="captures/start_tower.json">Candidate setup and command record</a></p>
<script>
const candidate=document.querySelector('#candidate'), moment=document.querySelector('#moment');
function update(){document.querySelector('#before').src=`captures/original_tower_${moment.value}.png`;
document.querySelector('#after').src=`captures/${candidate.value}_${moment.value}.png`;
document.querySelector('#caption').textContent=candidate.selectedOptions[0].text;
document.querySelector('#record').href=`captures/${candidate.value}.json`;}
candidate.onchange=moment.onchange=update;update();
</script>
''')
    print(f'Review page: {page}', flush=True)


def prepare(output):
    runtime = output / 'runtime'
    runtime.mkdir(parents=True, exist_ok=True)
    for item in ROOT.iterdir():
        if item.name in {'.git', '.godot', 'project.godot', 'override.cfg', 'artifacts'}:
            continue
        link = runtime / item.name
        if not link.exists():
            link.symlink_to(item, target_is_directory=item.is_dir())
        elif link.resolve() != item.resolve():
            raise SystemExit(f'Review runtime belongs to a different checkout: {link}')
    if not (runtime / '.godot').exists() and (ROOT / '.godot').exists():
        shutil.copytree(ROOT / '.godot', runtime / '.godot')
    settings = (ROOT / 'project.godot').read_text().replace(
        '[application]', '[application]\nconfig/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="SwarmfrontMapReview-{hashlib.sha256(str(output).encode()).hexdigest()[:12]}"', 1)
    (runtime / 'project.godot').write_text(settings)
    (runtime / 'override.cfg').write_text(
        '[swarmfront]\nrank/backend_url=""\nidentity/backend_url=""\n'
        'vs/backend_url=""\nops_config/remote_url=""\nanalytics/enabled=false\n'
        '[editor_plugins]\nenabled=PackedStringArray()\n')
    return runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', str(PINNED)))
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/simple_syrup_review')
    modes = parser.add_mutually_exclusive_group(required=True)
    for mode in ['check', 'capture', 'bots', 'play']:
        modes.add_argument('--' + mode, action='store_true')
    parser.add_argument('--variant', choices=['start', 'center', 'original'], default='start')
    parser.add_argument('--structure', choices=['tower', 'barracks'], default='tower')
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    if not version.startswith('4.7.1.stable.'):
        raise SystemExit(f'Use the pinned Godot 4.7.1 runtime; found {version}')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    runtime = prepare(output)
    env = os.environ.copy()
    for key in ['SF_ALLOW_LIVE_BACKEND_TESTS', 'SF_RANK_BACKEND_URL', 'SF_VS_BACKEND_URL', 'SF_OPS_CONFIG_URL', 'SF_MAP_SANDBOX']:
        env.pop(key, None)
    base = [args.godot, '--path', str(runtime)]

    def run(name, command, marker=None, timeout=180, graphical=False, extra_env=None):
        log = output / f'{name}.log'
        with log.open('w') as stream:
            proc = subprocess.run(command, env={**env, **(extra_env or {})}, stdout=stream, stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text(errors='replace')
        errors = [line for line in text.splitlines() if 'ERROR:' in line and
                  (graphical or line.strip() != HEADLESS_SHADER_DIAGNOSTIC)]
        if proc.returncode or errors or (marker and marker not in text):
            raise SystemExit(f'FAIL {name}: {log}\n{text[-5000:]}')
        print(f'PASS {name}: {log}', flush=True)

    run('import', base + ['--headless', '--editor', '--import'])
    run('candidate_freshness', base + ['--headless', '--script', 'res://tools/build_simple_syrup_candidates.gd', '--', '--check'], 'SIMPLE_SYRUP_BUILD: PASS')
    if args.check:
        for name, marker in [
            ('simple_syrup_map', 'SIMPLE_SYRUP_MAP_SMOKE: PASS'),
            ('match_setup_randomizer', 'MATCH_SETUP_RANDOMIZER_SMOKE: PASS'),
            ('structure_control_assignment', 'STRUCTURE_CONTROL_ASSIGNMENT_SMOKE: PASS'),
            ('map_symmetry', 'MAP_SYMMETRY_SMOKE: PASS'),
            ('map_studio', 'MAP_STUDIO_SMOKE: PASS'),
            ('map_authoring_finalize', 'MAP_AUTHORING_FINALIZE_SMOKE: PASS'),
            ('wall_renderer', 'WALL_RENDERER_SMOKE: PASS'),
            ('map_lane_availability', 'MAP_LANE_AVAILABILITY_SMOKE: PASS'),
            ('map_layout_rules', 'MAP_LAYOUT_RULES_SMOKE: PASS'),
            ('pvp_1v1_map_contract', 'PVP_1V1_MAP_CONTRACT_SMOKE: PASS'),
        ]:
            run(name, base + ['--headless', '--script', f'res://tools/{name}_smoke_test.gd'], marker, timeout=180,
                extra_env={'SF_MAP_SANDBOX': '0'} if name == 'structure_control_assignment' else None)
    elif args.bots:
        ids = ','.join(f'MAP_simple_syrup__{region}_{kind}__1p' for region in ['START', 'CENTER'] for kind in ['T', 'B'])
        run('bot_playtests', base + ['--headless', '--script', 'res://tools/bot_tournament_runner.gd', '--',
            '--map-ids=' + ids, '--variants=1p', '--styles=balancer,raider', '--tiers=medium',
            '--iterations=2', '--duration-ms=300000', '--seed=9292026', '--report-samples',
            '--output=' + str(output / 'bot_playtests.json')], 'BOT_TOURNAMENT: COMPLETE games=16 skipped=0', timeout=1200, extra_env={'SF_MAP_SANDBOX': '0'})
    else:
        combinations = [(args.variant, args.structure)] if args.play else [('original', 'tower')] + [(v, s) for v in ['start', 'center'] for s in ['tower', 'barracks']]
        for variant, structure in combinations:
            cmd = base + ['--rendering-method', 'gl_compatibility', '--script', 'res://tools/simple_syrup_playtest.gd']
            if args.capture:
                cmd += ['--fixed-fps', '30']
            cmd += ['--', '--variant=' + variant, '--structure=' + structure, '--output=' + str(output / 'captures')]
            if args.capture:
                cmd += ['--capture']
            print(f'Opening {variant} / {structure}', flush=True)
            run(f'{variant}_{structure}', cmd, 'SIMPLE_SYRUP_PLAYTEST: PASS' if args.capture else None,
                timeout=300 if args.capture else None, graphical=True, extra_env={'SF_MAP_SANDBOX': '0'})
        if args.capture:
            write_review_page(output)


if __name__ == '__main__':
    main()
