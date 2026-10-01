#!/usr/bin/env python3
"""Run the quest panel in a temporary Godot project with no player autoloads or network."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--godot', default='godot')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='sf-quest-panel-') as directory:
    root = Path(directory)
    for name in ['scripts/ui/quest_panel.gd', 'scripts/dev/quest_panel_smoke.gd',
                 'scripts/ui/ui_battle_pass_screen.gd', 'scripts/ui/ui_typography.gd',
                 'scripts/state/buff_catalog.gd', 'scripts/state/buff_definitions.gd']:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / name, target)
    (root / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="QuestSmoke"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    result = subprocess.run([args.godot, '--headless', '--path', str(root), '--script',
        'res://scripts/dev/quest_panel_smoke.gd'], capture_output=True, text=True, timeout=45)
    print(result.stdout, end='')
    print(result.stderr, end='')
    raise SystemExit(result.returncode or int('ERROR:' in result.stderr or 'ERROR:' in result.stdout))
