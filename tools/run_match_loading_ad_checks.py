"""Check pre-game ads with isolated config and no player/network autoloads."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--visual-dir', type=Path)
    parser.add_argument('--test', action='append', help='Run only the named check or preview')
    parser.add_argument('--video-path', type=Path, help='Optional short local VideoStream fixture')
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    if args.visual_dir:
        args.visual_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='sf-loading-ads-') as directory:
        project = Path(directory)
        for name in ['scripts', 'scenes', 'assets', 'data', 'tools', '.godot']:
            (project / name).symlink_to(source / name, target_is_directory=True)
        (project / 'profile_stub.gd').write_text('extends Node\n')
        (project / 'project.godot').write_text('''config_version=5
[application]
config/name="LoadingAdChecks"
[autoload]
ProfileManager="*res://profile_stub.gd"
OpsConfig="*res://scripts/state/ops_config.gd"
AdManager="*res://scripts/state/ad_manager.gd"
MainMenuLoadingCoordinator="*res://scenes/ui/MainMenuLoadingCover.tscn"
[display]
window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=540
window/size/window_height_override=960
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
''')
        env = dict(os.environ)
        for key in ['SF_OPS_CONFIG_URL', 'SF_VS_BACKEND_URL', 'SF_FAKE_ADS',
                    'SF_AD_PLACEHOLDERS', 'SF_BIODYNAMIC_TEST_ADS', 'SF_LOADING_TEST_VIDEO']:
            env.pop(key, None)
        if args.video_path:
            env['SF_LOADING_TEST_VIDEO'] = str(args.video_path.resolve())
        tests = ['match_loading_ads_smoke_test', 'ad_manager_smoke_test',
                 'ad_surface_measurement_smoke_test', 'ad_clipboard_smoke_test',
                 'biodynamic_loading_ad_smoke_test', 'ad_biodynamic_creative_smoke_test',
                 'beta_banner_ads_smoke_test']
        if args.visual_dir:
            tests.append('match_loading_preview')
            tests.append('biodynamic_loading_preview')
        if args.test:
            tests = args.test
        if any(test.endswith('_preview') for test in tests) and not args.visual_dir:
            parser.error('preview checks require --visual-dir')
        for test in tests:
            visual = test.endswith('_preview')
            script = {'match_loading_preview': 'match_loading_ads_smoke_test',
                      'biodynamic_loading_preview': 'biodynamic_loading_ad_smoke_test'}.get(test, test)
            cmd = [args.godot, '--path', str(project), '--script', f'res://tools/{script}.gd']
            if visual:
                filename = 'biodynamic-loading.png' if test == 'biodynamic_loading_preview' else 'match-loading.png'
                cmd += ['--', '--preview-only', f'--visual-path={args.visual_dir.resolve() / filename}']
            else:
                cmd += ['--headless']
            log = (args.visual_dir or Path(tempfile.gettempdir())) / f'{test}.log'
            try:
                with log.open('w') as stream:
                    result = subprocess.run(cmd, env=env, stdout=stream,
                                            stderr=subprocess.STDOUT, timeout=45)
            except subprocess.TimeoutExpired:
                raise SystemExit(f'TIMEOUT {test}: {log}\n{log.read_text()}')
            output = log.read_text()
            if result.returncode or 'ERROR:' in output or 'PASS' not in output:
                raise SystemExit(f'FAIL {test}: {log}\n{output}')
            print(f'PASS {test}: {log}', flush=True)


if __name__ == '__main__':
    main()
