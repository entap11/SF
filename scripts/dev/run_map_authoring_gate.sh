#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "${ROOT_DIR}" "${GODOT_BIN:-godot}" "${MAP_AUTHORING_LOG_DIR:-/tmp/swarmfront_map_authoring_gate}" <<'PY'
from pathlib import Path
import os, subprocess, sys
root, godot, output = sys.argv[1:]
folder = Path(output)
folder.mkdir(parents=True, exist_ok=True)
with (folder / 'candidate_freshness.log').open('w') as target:
    result = subprocess.run([godot, '--headless', '--path', root, '--script',
                             'res://tools/build_simple_syrup_candidates.gd', '--', '--check'],
                            stdout=target, stderr=subprocess.STDOUT, timeout=90)
text = (folder / 'candidate_freshness.log').read_text(errors='replace')
if result.returncode or 'SIMPLE_SYRUP_BUILD: PASS' not in text or 'ERROR:' in text:
    raise SystemExit(f'MAP_AUTHORING_GATE: FAIL candidate_freshness\n{text[-6000:]}')
print('MAP_AUTHORING_GATE: PASS candidate_freshness', flush=True)
for name, marker in [
    ('simple_syrup_map', 'SIMPLE_SYRUP_MAP_SMOKE: PASS'),
    ('match_setup_randomizer', 'MATCH_SETUP_RANDOMIZER_SMOKE: PASS'),
    ('structure_control_assignment', 'STRUCTURE_CONTROL_ASSIGNMENT_SMOKE: PASS'),
    ('map_symmetry', 'MAP_SYMMETRY_SMOKE: PASS'),
    ('map_studio', 'MAP_STUDIO_SMOKE: PASS'),
    ('map_authoring_finalize', 'MAP_AUTHORING_FINALIZE_SMOKE: PASS'),
    ('wall_renderer', 'WALL_RENDERER_SMOKE: PASS'),
]:
    log = folder / (name + '.log')
    try:
        with log.open('w') as target:
            result = subprocess.run([godot, '--headless', '--path', root, '--script',
                                     f'res://tools/{name}_smoke_test.gd'],
                                    stdout=target, stderr=subprocess.STDOUT, timeout=90,
                                    env={**os.environ, 'SF_MAP_SANDBOX': '0'} if name == 'structure_control_assignment' else None)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f'MAP_AUTHORING_GATE: FAIL {name}: {error}; {log}')
    text = log.read_text(errors='replace')
    if result.returncode or marker not in text or 'ERROR:' in text:
        raise SystemExit(f'MAP_AUTHORING_GATE: FAIL {name}; {log}\n{text[-6000:]}')
    print(f'MAP_AUTHORING_GATE: PASS {name}', flush=True)
print('MAP_AUTHORING_GATE: PASS')
PY
