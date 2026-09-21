#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "${ROOT_DIR}" "${GODOT_BIN:-godot}" "${MAP_AUTHORING_LOG_DIR:-/tmp/swarmfront_map_authoring_gate}" <<'PY'
from pathlib import Path
import subprocess, sys
root, godot, output = sys.argv[1:]
folder = Path(output)
folder.mkdir(parents=True, exist_ok=True)
for name, marker in [
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
                                    stdout=target, stderr=subprocess.STDOUT, timeout=90)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f'MAP_AUTHORING_GATE: FAIL {name}: {error}; {log}')
    text = log.read_text(errors='replace')
    if result.returncode or marker not in text or 'ERROR:' in text:
        raise SystemExit(f'MAP_AUTHORING_GATE: FAIL {name}; {log}\n{text[-6000:]}')
    print(f'MAP_AUTHORING_GATE: PASS {name}', flush=True)
print('MAP_AUTHORING_GATE: PASS')
PY
