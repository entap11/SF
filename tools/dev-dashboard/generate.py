#!/usr/bin/env python3
"""Export repository definitions for the disconnected dashboard. Never writes game catalogs."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='/usr/local/bin/godot')
args = parser.parse_args()
quest = subprocess.run([str(ROOT / 'tools/rank-service/node_modules/.bin/tsx'), str(HERE / 'export-quests.ts')],
                       cwd=ROOT, text=True, capture_output=True, check=True,
                       env={**os.environ, "DATABASE_URL": "postgres://preview:preview@127.0.0.1:1/preview"})
quest_data = json.loads(quest.stdout)
with tempfile.TemporaryDirectory(prefix='sf-dashboard-export-') as directory:
    temp = Path(directory)
    (temp / 'data/battle_pass').mkdir(parents=True)
    shutil.copyfile(ROOT / 'scripts/state/battle_pass_config.gd', temp / 'config.gd')
    shutil.copyfile(ROOT / 'data/battle_pass/battle_pass_config.json', temp / 'data/battle_pass/battle_pass_config.json')
    (temp / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="DashboardCatalogExport"\n')
    (temp / 'export.gd').write_text('''extends SceneTree
func _initialize():
    var config = load("res://config.gd").new()
    var file = FileAccess.open("res://export.json", FileAccess.WRITE)
    file.store_string(JSON.stringify({"levels": config.get_levels(), "summary": config.get_reward_summary()}))
    file.close()
    quit()
''')
    result = subprocess.run([args.godot, '--headless', '--path', str(temp), '--script', 'res://export.gd'],
                            capture_output=True, text=True, timeout=40)
    if result.returncode or 'ERROR:' in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)
    battlepath = json.loads((temp / 'export.json').read_text())
battlepath['config'] = json.loads((ROOT / 'data/battle_pass/battle_pass_config.json').read_text())

def source_ids(path, constant):
    source = (ROOT / path).read_text()
    block = re.search(r'const ' + constant + r': Array\[String\] = \[(.*?)\]', source, re.S)
    if not block:
        raise RuntimeError('Cannot locate canonical map list: ' + constant)
    return re.findall(r'"([^"]+)"', block.group(1))

time_ids = source_ids('scripts/state/public_contest_content.gd', 'TIME_MAP_IDS')
gauntlet_ids = source_ids('scripts/state/progressive_config.gd', 'DEFAULT_STAGE_MAP_IDS')
# Export referenced maps only; keep future-library provenance visible.
map_files = {}
for path in sorted((ROOT / 'maps').rglob('*.json')):
    if path.stem not in set(time_ids + gauntlet_ids):
        continue
    map_files.setdefault(path.stem, []).append(path)
maps = []
for map_id in dict.fromkeys(time_ids + gauntlet_ids):
    matches = map_files.get(map_id, [])
    if len(matches) != 1:
        raise RuntimeError('Map must resolve unambiguously for preview: ' + map_id)
    path = matches[0]
    definition = json.loads(path.read_text())
    maps.append({'id': map_id, 'name': map_id.removeprefix('MAP_').replace('__', ' · ').replace('_', ' '),
                 'source': str(path.relative_to(ROOT)), 'future_library': '_future' in path.parts,
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'definition': definition})
inputs = ['tools/rank-service/src/platformQuestCatalog.ts', 'scripts/state/battle_pass_config.gd',
          'data/battle_pass/battle_pass_config.json', 'scripts/state/public_contest_content.gd',
          'scripts/state/progressive_config.gd']
sources = [{'path': name, 'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()} for name in inputs]
data = {**quest_data, 'battlepath': battlepath, 'maps': maps, 'time_map_ids': time_ids, 'gauntlet_map_ids': gauntlet_ids,
        'sources': sources, 'generated_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'schema': 'swarmfront.dev_dashboard.catalog.v1'}
(HERE / 'data.js').write_text('window.SF_CATALOG = ' + json.dumps(data, separators=(',', ':')).replace('<', '\\u003c') + ';\n')
(HERE / 'assets').mkdir(exist_ok=True)
for source, target in [('assets/branding/swarmfront_logo_1024.png', 'logo.png'),
                       ('assets/fonts/brand/Iceland/Iceland-Regular.ttf', 'Iceland-Regular.ttf'),
                       ('assets/fonts/brand/Iceland/OFL.txt', 'OFL.txt')]:
    shutil.copyfile(ROOT / source, HERE / 'assets' / target)
print(json.dumps({'ok': True, 'quests': len(data['quests']), 'battlepath_levels': len(battlepath['levels']), 'maps': len(maps)}))
