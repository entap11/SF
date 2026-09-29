# Tower voxel impact study — September 24, 2026

Scope authorized: develop and show an isolated visual prototype; production
integration follows visual approval. This worktree is based on `bc87d9f` from the
mobile/campaign checkout. Only study tools and this document are added. There are
no changes to production renderers, simulation, account services, project settings,
gameplay RNG or authoritative state.

## Review

Open `../artifacts/tower-voxel-slide-study-2026-09-24/index.html`. The player includes an
18-second, 1440×960, 60 fps Godot capture, quarter/half speed, frame stepping,
scrubbing, and section loops. The left view enlarges the artwork 2.25×. The right
uses the production bee texture-box size (63.86688 canvas pixels), but its layout,
tower sizes, camera and incoming units are a synthetic fixture, not an actual
match. Preview is silent.

The initial breakup samples `unit_v5.png` on a 12×12 grid, retaining 30 occupied
cells. CPU sample tint and live sprite tint share the same study recoloring rule.
The white-hot bolt travels for 140 ms in this fixture; this duration does not
change or establish production projectile timing. Fragments occupy the source
silhouette on the hit sample, then tumble and move along the shot direction.

Each fragment has explicit launch velocity/height, gravity, restitution, two
smaller rebounds, friction, a finite slide, and a stable resting orientation.
Revision 2 retains 92% of horizontal speed at first contact and 94% on entering
the final skid. Main fragments launch at 110–150 pixels/second; about 10% have a
smaller impulse. The skid lasts 1.15–1.75 seconds after the last bounce and ends
at exactly zero speed under constant floor friction. Flattening follows the
bounces while yaw continues settling during the skid.
Projection and lighting give instanced cubes three-dimensional faces without
adding physics bodies. Contact shadows follow their floor positions. Crowding
adds a shallow resting-height variation for the impression of accumulation;
pieces do not collide with each other or form physically simulated stacks.

Quiet-area fade starts 4.5–6.7 seconds after a hit and lasts 0.85 seconds. New nearby
hits shorten older pieces' life, but cannot start their decay until the full
bounce and slide plus 1.3 seconds of rest. Fragment fades are staggered. There are fixed
budgets of 128 chunks for detail and 640 for the field, with whole-bee admission;
extreme overload skips additional visual breakups instead of replacing fresh
pieces halfway through their animation. Normal fixture traffic fits the budget.

The cube and shadow renderers use two fixed MultiMesh nodes per stage. No scene
nodes are allocated per hit or per chunk. Presentation dictionaries are still
sampled/allocated on the CPU; this is a review prototype, not a finished mobile
optimization pass. Shader motion uses explicit instance data, not `TIME`.

`towers.png` includes a baked checkerboard and grey ground shadow. The fixture
applies the existing registry's white-key thresholds and a study-only polygon
contour around the small tower. Source artwork is not modified.

## Longer-slide revision

The requested revision sends most fragments into open floor while leaving a few
heavy pieces near the hit. The force remains aligned with the shot; there is no
mid-flight lane steering, snapping, or gameplay-state inference. The detail view
now includes the path and has room for the full spill. Fade scheduling preserves
the entire skid before the minimum resting interval begins. The original video
and player remain at `../artifacts/tower-voxel-study-2026-09-24/index.html` for
comparison; its captured footage is unchanged.

`slide-clearance.json` samples all 26 fixture hits (780 fragments): 696, or 89.2%,
finish fully outside both visible 14-pixel lane corridors, including each cube's
projected extent. Median travel after the final bounce is 43.2 pixels. The weakest
individual hit still clears 60%; this is a statistical motion treatment, not a
guarantee that every hit clears every path. Measurements use the fixture lanes,
not a claim about arbitrary production maps.

Added checks cover continuous transitions into the slide, zero drift after
stopping, minimum median slide distance, at least 80% aggregate lane clearance,
and keeping the full detail spill inside the panel. Existing event/capacity,
density/decay, replay/timing and cleanup checks pass again.

## Reproduction

From this worktree:

```sh
python3 tools/run_tower_voxel_study.py --output ../artifacts/tower-voxel-slide-study-2026-09-24 --check
python3 tools/run_tower_voxel_study.py --output ../artifacts/tower-voxel-slide-study-2026-09-24 --capture
python3 tools/build_tower_voxel_review.py ../artifacts/tower-voxel-slide-study-2026-09-24
python3 tools/run_tower_voxel_study.py --output ../artifacts/tower-voxel-slide-study-2026-09-24 --benchmark
```

Omit the final mode switch to launch the live prototype. Space pauses; S toggles
quarter speed; R restarts; arrows step frames; Escape exits. `--stills` produces
representative inspection frames. `--godot /path/to/Godot` selects another engine.
The runner builds a separate minimal project with no autoloads or network service
dependencies and loads copied assets at startup.

## Validation evidence

- `check.log`: silhouette alignment, forward force, continuous contacts at every
  bounce, identical motion at equal elapsed time under 30/60/120 Hz sampling,
  adaptive life, preserved minimum rest, 200-event overload, bounded records and
  fixed nodes, seek/replay equivalence, and complete end-of-sequence cleanup pass.
- `capture.log`: all 1,080 frames rendered successfully; no script/shader errors.
- `video-validation.json`: the encoded MP4 decodes to 1,080 frames at 60 fps,
  1440×960, exactly 18 seconds.
- `player-validation.json`: headless Chrome loaded and decoded the local video;
  quarter speed, chapter seeking, forward/backward frame steps and the blue-bee
  chapter pass. The 390-pixel layout has no horizontal overflow. Inspected both
  rendered frames and a screenshot of the actual review player.

Available engine: Godot 4.2 stable official, macOS Compatibility/ANGLE Metal,
AMD Radeon Pro Vega 48. Existing engine uniform-buffer and camera-deprecation
warnings remain in logs. This is not a target Godot 4.7.1 or phone acceptance run.

Original revision 1 desktop measurements, 240 samples per phase after 30 warmup
samples (retained as historical evidence; not remeasured for the longer slide):

| Measurement | Idle | Sustained fire |
| --- | ---: | ---: |
| Presentation update median | 0.081 ms | 3.102 ms |
| Presentation update p95 | 0.121 ms | 5.091 ms |
| Frame interval median | 6.912 ms | 8.854 ms |
| Frame interval p95 | 9.140 ms | 12.470 ms |
| Active chunks at phase end | 0 | 293 |

These include the study fixture and enlarged view, with forced drawing. Frame
intervals include scheduling and presentation; this is an observational desktop
measurement, not a controlled full-game A/B or physical-device result. CPU cost
is material and should be profiled/optimized before integrating into a mobile
match. The offline video playback rate does not establish device frame rate.

## After visual approval

Use confirmed simulation `tower_hit` events for impact and existing `tower_fire`
events for the shot. Obtain the victim's displayed pose/color before its visual
is released, so the sprite-to-chunk handoff has no lag or duplicate bee. Keep
the authoritative removal entirely in `UnitSystem`; the presentation may only
consume events. Production work also needs settings/pause/match-reset handling,
target-engine testing, renderer pose alignment and phone performance evaluation.
