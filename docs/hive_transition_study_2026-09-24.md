# Hive transformation study — September 24, 2026

Authorized deliverable: a runnable and captured visual study of small/medium/large
upgrades and downgrades, using existing hive artwork. Target: integrated shell
lighting, one fitted energy sweep, deliberate assembly and controlled settling.

Presentation owns disposable time, materials and geometry. The fixture consumes
explicit tier samples only: no simulation state, gameplay RNG, account data or
network services. Labels describe the supplied target tier immediately. Repeated
changes replace the active presentation; reduced motion shows a short dissolve.

Scope: isolated Godot study, reusable presentation component, shaders, review
video/gallery, bounded lifecycle/timing checks and desktop cost measurements.
Production integration, changes to gameplay thresholds, sound assets and phone
certification are outside this first visual study. Physical device performance
must be measured before claiming a mobile performance budget is satisfied.

Acceptance: all four adjacent transitions; repeated/reversed transitions; stable
power/slot indicators; fixed allocation count; cleanup; equal sampled appearance
at equal elapsed time under different update schedules; gameplay-sized and enlarged
captures; recorded engine and rendering backend. No per-frame scene allocation,
full-screen postprocessing, physics, unseeded randomness or simulation writes.

## Delivered study

- `tools/hive_transition_study/presenter.gd`: time-sampled presentation with
  reusable body/contact quads, 0.66-second growth, 0.49-second contraction and
  0.13-second reduced-motion dissolve. The existing textures are aligned at the
  ground; the shell changes size during the directional reveal. Tier information
  is supplied by the fixture and is never inferred from the animation.
- `transform.gdshader`: body recoloring, neutral crown, localized shell response,
  fitted front/rear sweep, charge and cap glint. The crown limits and fade prevent
  the sweep detaching into a halo. Every animation parameter is explicit; the
  shader reads neither `TIME` nor a screen texture.
- `contact.gdshader`: local contact shadow and restrained energy spill.
- `study.gd`: enlarged detail and synthetic compact battlefield, all four owner
  colors, normal/quarter-speed controls, direct transition keys and reduced motion.
  The battlefield is a visual fixture, not a recorded authoritative match.
- The preview is silent. Production tier triggers, textures, current indicators,
  shaders and simulation remain unchanged.

Artifacts: `../artifacts/hive-transformation-2026-09-24/index.html` (relative to the
worktree), with an 8.4-second, 1440×1000, 60-fps MP4, frame stepping and per-transition
loop selection. The live fixture accepts Space, 1–4, S, R, A (all), and Escape.

Reproduction:

```sh
python3 tools/run_hive_transition_study.py --godot /path/to/Godot --output /path/to/review --check
python3 tools/run_hive_transition_study.py --godot /path/to/Godot --output /path/to/review --capture
python3 tools/build_hive_transition_review.py /path/to/review
```

Omit `--capture`/`--check` to open the live study. Its separate minimal project has
no autoloads, backends or access to ordinary player data. Study images/fonts load
at startup from copied sources; production export/import integration is deferred.

## Evidence and limits

Actual available renderer used: Godot **4.2.stable.official.46dc27791**, macOS,
Compatibility/ANGLE Metal, AMD Radeon Pro Vega 48. This is a local rendering study;
it does **not** certify the mobile lane's pinned Godot 4.7.1 or physical devices.
The initial headless import attempt was replaced with direct fixture asset loading;
the final runner does not require an editor/import pass.

Passed four adjacent transitions, 400 replacement/reversal lifecycle checks,
equivalent sampled poses at equal elapsed time (direct sample vs 60-Hz updates),
reduced-motion constraints, final-state cleanup and fixed child counts. These
checks establish lifecycle behavior, not seamless visual continuity under every
possible rapid tier reversal. Video decode verifies 504 frames at 60 fps.

A separate desktop scene rendered 24 hives at 1440×1000 with 300 measured samples
per phase after warmup, with forced rendering to avoid occluded-window skipping:

| Measurement | Idle | Transforming |
| --- | --- | --- |
| Frame interval median | 6.885 ms | 7.997 ms |
| Frame interval p95 | 7.386 ms | 10.485 ms |
| Presenter uniform-update CPU median | 0.001 ms | 0.218 ms |
| Presenter uniform-update CPU p95 | 0.001 ms | 0.343 ms |
| Scene nodes | 75 | 75 |

GPU timer and draw-call counters returned zero on this engine/backend and are
unavailable, not evidence of zero cost. Frame intervals include scheduling and
presentation; sequential phases are a cost observation, not a controlled
production A/B benchmark. The shader adds measurable work. Full-game headroom,
phone frame pacing, target-engine compatibility, settings/lifecycle integration,
owner changes, rapid reversal appearance and indicator placement need validation
before production adoption. The capture's 60-fps playback is not a performance
measurement. Logs retain the engine's uniform-buffer and camera-deprecation
warnings; no script/shader errors appeared in the final captures or checks.
