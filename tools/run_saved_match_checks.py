"""Exercise save/resume with isolated, offline player data and the pinned engine."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--test', action='append')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='sf-saved-match-') as folder:
        project = Path(folder)
        for item in ROOT.iterdir():
            if item.name not in {'project.godot', 'override.cfg', '.git'}:
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        settings = (ROOT / 'project.godot').read_text().replace(
            '[application]', '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="SwarmfrontSavedMatchChecks-{project.name}"', 1)
        (project / 'project.godot').write_text(settings)
        (project / 'override.cfg').write_text('[swarmfront]\nrank/backend_url=""\n'
            'identity/backend_url=""\nvs/backend_url=""\nanalytics/enabled=false\n')
        for test in (args.test or ['saved_match_smoke_test', 'saved_match_flow_smoke_test', 'saved_match_modes_smoke_test']):
            phases = ['write', 'restore'] if test == 'saved_match_flow_smoke_test' else ['check']
            for phase in phases:
                log = Path(tempfile.gettempdir()) / f'{test}-{phase}.log'
                cmd = [args.godot, '--headless', '--path', str(project),
                       '--script', f'res://tools/{test}.gd']
                if phase == 'restore':
                    cmd += ['--', '--restore']
                with log.open('w') as stream:
                    result = subprocess.run(cmd, stdout=stream,
                        stderr=subprocess.STDOUT, timeout=180)
                output = log.read_text()
                if result.returncode or 'SCRIPT ERROR' in output or 'PASS' not in output:
                    raise SystemExit(f'FAIL {test} ({phase}): {log}')
                print(f'PASS {test} ({phase}): {log}', flush=True)


if __name__ == '__main__':
    main()
