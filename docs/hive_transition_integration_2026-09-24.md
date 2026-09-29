# Approved hive transition integration and pressure study

Owner approved the September 24 transformation preview and requested production
integration followed by the same quality pass for pressure graphics.

Owner: hive presentation (`HiveRenderer`, `HiveNode`, `HiveVisual` and transition
component). Inputs remain canonical render samples. OpsState/SimState, simulation
thresholds, ownership, lane budgets, capture and RNG are unchanged. Power and lane
indicators show canonical values immediately, independent of transition progress.

Integrate both directions using actual sprite textures, sizes, centers and tint.
Keep two reusable quads; restore final sprite on completion/cancellation, capture,
state/viewer reset, disabled motion, removal and backgrounding. Preserve custom
texture regions and owner/selection presentation. Upgrades suppress distress;
downgrades retain their existing rupture/pressure classification. No invented
pressure trigger or gameplay event. Existing performance metric keys continue to
count the one fitted sweep instead of the former multiple rings.

Validation: canonical render-boundary integration tests, cancellation/lifecycle,
existing pressure classification tests, collision/picking regression, source-only
simulation invariance and native scene captures. Pressure redesign begins as a
separate reviewable candidate driven by the unchanged distress rules.

## Implementation

The approved timings are shared by the study and production component in
`hive_transition_timing.gd`: growth 0.66 s, contraction 0.49 s, low-motion dissolve
0.13 s. All poses are sampled from elapsed presentation seconds. The production
surface uses the real old/new textures, regions, offsets and dimensions, follows
live owner/selection/fade styling, and hands back to the normal sprite at seating.
Rapid reversals preserve the interpolated footprint. No shader TIME, screen copy,
particle emitter, image readback or simulation RNG is used by the transition.

Two reusable quads and their two materials replace the six ring materials. The
component stops processing when quiet. Existing shadow geometry supplies the
contact anchor. Lane/power projections update immediately; the newly available
port receives a brief color confirmation without changing its hit area.

Upward growth alone suppresses distress. Ending a transition no longer replays the
last distress event. Ownership changes, state/viewer resets, animation disable,
backgrounding and removal cancel the proxy and reveal the current canonical art.

A detached SpriteRegistry now checks `is_inside_tree()` before querying its tree
for the existing startup diagnostic; the former call emitted a spurious engine
error during prewarming. The selection source smoke test was also stale: it
expected an ArenaAPI parameter after the renderer had already switched to Object.
Its signature check now matches the existing API, and the transition integration
test exercises live selection/deselection on the animated surface.

## Pressure review candidate

`tools/hive_pressure_study/pressure.gd` subclasses the unchanged production
HiveDistressLight. Only `_ready` material setup and `_draw` differ. It uses one
bounded shader surface, one material, zero children and four fixed ember paths.
A hot crown rim, twin feathered vents and a soft heat pool replace the polygonal
plume. Recovery, rupture counts, pressure hold and critical timers are inherited.

The comparison checks matching current/candidate state, intensities, hold timers,
rupture/entry counters and surge indices at all 576 samples. It shows hostile
6→5→4→3, large→medium loss, medium→small loss and recovery. This candidate remains
in tools; production pressure drawing is unchanged pending visual review.

Reproduce using Godot 4.7.1:

```
python3 tools/run_hive_pressure_study.py --godot /path/to/Godot --output /tmp/hive-pressure --capture
python3 tools/build_hive_pressure_review.py /tmp/hive-pressure
```

Native fixture captures and headless smoke logs are under
`../artifacts/hive-integration-2026-09-24/`. Pressure review is under
`../artifacts/hive-pressure-2026-09-24/index.html`. These are local artifacts, not
shipped game assets. Desktop timings do not certify physical-phone performance.

## Cost controls and evidence

The renderer admits at most six concurrent full-detail transformations, in stable
hive-ID order. Additional simultaneous edges use the same 0.13 s reduced dissolve;
canonical power, tier and lane capacity are applied immediately in either path.
The cap is presentation-only. The surface shades the blended texture once and
skips sweep math when there is no sweep. Live styling is refreshed on changes,
instead of polled every animation frame. Lane ports and budget pips now reuse
fixed three-slot pools, including their static hexagon geometry.

A native HiveRenderer fixture rendered 24 simultaneous upgrades at 1440×1000 on
the local AMD Radeon Pro Vega 48, using Godot 4.7.1 compatibility rendering. Each
phase records 240 samples after warmup. Original versus final bounded treatment:

| Measure | Original | Integrated |
| --- | ---: | ---: |
| Active frame interval, median | 17.937 ms | 18.810 ms |
| Active frame interval, p95 | 58.677 ms | 33.014 ms |
| Idle frame interval, median | 17.623 ms | 21.008 ms |
| Initial / final scene nodes | 1645 / 1645 | 1309 / 1309 |

Evidence: `baseline-benchmark.json` and `integrated-bounded-benchmark.json` under
the integration artifact directory. Variable idle timing demonstrates scheduling
noise; these sequential, forced-draw desktop samples do not establish a phone FPS
or zero overhead. Frame-time tails improved in this fixture while the active
median was close. GPU/draw counters returned zero (unavailable), not zero work.
The engine process monitor is coarsely sampled and is not an effect-only CPU
measurement. Unbounded draft timings are retained for the optimization audit.

Checks: growth/contraction, duplicate samples, reversals, model immutability,
canonical indicators, reused materials/nodes/ports, live selection, cancellation,
viewer/state/ownership changes, reduced preference, full-effect budget and stable
admission order; existing distress rules, hostile capture pressure, picking,
shadow renderer, selection seam and performance harness contract. Native captures
cover both directions, bright ground and the reduced dissolve. No files under
simulation, systems, OpsState or game state were modified.
