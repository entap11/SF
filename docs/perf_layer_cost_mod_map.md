# SF Performance Layer Cost Mod Map

Purpose: understand SF's runtime costs layer by layer without destabilizing online play. This is a measurement roadmap, not an optimization plan. Every experiment should be easy to revert, isolated behind harness flags or local-only switches, and produce comparable reports.

## Guardrails

- Do not change online gameplay behavior to test performance.
- Prefer harness-level kill switches over production code edits.
- If a production switch is needed, add it as an opt-in debug/project setting with default current behavior.
- Keep each test variant deterministic: same map, seed, scripted intents, duration, camera, and match phase.
- Measure before and after every switch. Do not combine switches until single-layer cost is known.
- Store raw frame samples and summary tables. Averages are not enough for rhythmic hitches.
- Treat `A_full_game` as the control for every run.

## Core Harnesses

Use two complementary tools:

- `scripts/tests/rhythmic_lag_isolation.gd`
  - 30-second frame recorder and hitch detector.
  - Best for periodic hitch source isolation.
  - Produces per-frame JSON and comparison table.

- `scripts/tests/perf_benchmark_suite.gd`
  - Longer-term benchmark/gate harness.
  - Best for stable regression targets after a suspect layer is understood.

Recommended first command:

```bash
godot --headless --path . --script res://scripts/tests/rhythmic_lag_isolation.gd -- --duration 30 --output res://debug_reports/rhythmic_lag_isolation_latest.json
```

## Test Matrix

Start with the four baseline variants:

| Variant | Purpose |
| --- | --- |
| `A_full_game` | Realistic control with all layers on. |
| `B_sim_only` | Keeps authoritative sim moving, strips heavy presentation. |
| `C_sim_only_bots_off` | Separates bot decision cost from sim-only baseline. |
| `D_presentation_only` | Pauses sim and measures scene/render/UI presentation cost. |

Then add one-layer deltas. Each row should differ from the closest baseline by exactly one layer.

## Layer Map

| Layer | Primary Question | Switch Strategy | Key Metrics |
| --- | --- | --- | --- |
| Bots | Are bot think intervals creating rhythmic spikes? | Compare `B_sim_only` vs `C_sim_only_bots_off`; add bot-only interval probes if needed. | hitch count, p99, sim tick ms, tick period. |
| Lane flow | Are lane fronts/path state updates periodic? | Sim-only with lane flow on/off in a dedicated variant. | sim tick ms, worst sim tick sections. |
| Edge cache | Is cache rebuild periodic or map-size sensitive? | Edge-cache-only and full-stack-with-edge-off variants. | sim tick ms, hitch period, lane count. |
| Units/swarms | Are unit spawn/update/render queues spiking? | Unit sim on with unit visuals off; then visuals on. | sim tick ms, object count, unit count, render estimate. |
| Towers | Are tower targeting or projectile visuals costly? | Structure/tower sim on, combat visuals off, then projectile/VFX on. | sim tick ms, draw count, object count. |
| Barracks | Are route selection/spawn bursts costly? | Barracks routes seeded, barracks sim isolated. | sim tick ms, unit count, hitch period. |
| Floor base | What is the cost of the current floor renderer alone? | Presentation-only with floor visible vs hidden. | p95/p99, draw count, render objects. |
| Dynamic floor overlays | How much budget exists for future overlays? | Add synthetic overlay variants at increasing resolution/update cadence. | p99, max frame, memory, draw count. |
| Territory visuals | Are influence texture updates causing periodic hitches? | Territory sim on/off separately from floor influence visuals. | p99, max, memory, render estimate. |
| Fog visuals | Does fog redraw cadence match the hitch period? | Fog sim on with visuals off, then visuals on. | hitch period, draw count, texture/memory counters. |
| Combat visuals | Are unit sprites/VFX/projectiles the render spike? | Sim-only visual mode, then enable unit sprites, then VFX. | render estimate, draw count, object count. |
| HUD/debug labels | Is UI refresh/logging periodic? | Full game with HUD/debug/logging off. | p99, update ms, object count. |
| Hash/desync checks | Are integrity snapshots creating uniform ticks? | Full sim with hash/desync checks off. | sim tick ms, hitch period. |
| Network emit/resend | Are async publish/snapshot paths contributing? | Local/offline full game with network runtime disabled. | p99, max, runtime counters. |
| Audio | Are stream creation/playback events spiking? | Full game with audio bus muted and audio nodes process-disabled. | p99, max, hitch coincidence with events. |
| Path previews/orders overlay | Are input affordance overlays redrawing too much? | Presentation-only and full game with previews hidden. | render estimate, draw count. |

## Dynamic Floor Overlay Budget Tests

Do not build the final overlay first. Add synthetic probes that approximate likely cost.

1. Static overlay visible, no per-frame update.
2. Overlay redraw every 1000ms.
3. Overlay redraw every 250ms.
4. Overlay redraw every frame.
5. Low resolution influence texture.
6. Medium resolution influence texture.
7. Target production resolution.

For each step, record:

- p95/p99/max frame time
- hitch count and hitch period
- draw calls
- render objects/primitives
- memory counters
- whether the hitch period aligns with update cadence

Stop increasing fidelity when p99 or hitch count crosses the current gate. The output should be a budget envelope, not a final feature implementation.

## Rollback Plan

Every experiment should be reversible by deleting or disabling one of:

- a harness variant
- a debug/project setting
- a local-only visibility/process toggle
- a synthetic test node

Avoid migrations, asset rewrites, gameplay refactors, and permanent scene changes during measurement. If a test needs production code, isolate it behind a clearly named flag such as `swarmfront/perf_experiment/<name>` with default `false`.

## Reporting Template

Each run should produce a table like:

| Variant | Hitches | P99 ms | Max ms | Delta vs Full | Read |
| --- | ---: | ---: | ---: | ---: | --- |
| A full game |  |  |  |  | control |
| B sim-only |  |  |  |  | presentation removed |
| C sim-only bots off |  |  |  |  | bot cost isolated |
| D presentation-only |  |  |  |  | sim removed |

Then add a short conclusion:

- `Likely source:` one layer or "not isolated yet".
- `Evidence:` hitch count/p99/max/period changes.
- `Next test:` exactly one new switch or probe.
- `Rollback:` what to delete/disable.

## Suggested Sequence

1. Run the four baseline variants for 30 seconds.
2. If presentation-only still hitches, isolate render/UI/audio/floor first.
3. If sim-only still hitches, isolate bots, lane flow, edge cache, units, towers, barracks.
4. If only full game hitches, test interaction layers: unit visuals, territory visuals, fog visuals, VFX, HUD.
5. Once the culprit layer is known, add a focused benchmark scenario for it.
6. Only after the layer is measured and repeatable, discuss optimization or feature budget.

## Done Criteria

The layer-cost pass is complete when:

- The 30-second matrix has raw JSON and a summary table.
- At least one switch clearly removes/reduces the rhythmic hitch, or the data shows the hitch is outside the tested layers.
- Each expensive layer has an approximate p99/max/hitch contribution.
- Dynamic floor overlays have a tested budget envelope.
- No online behavior was changed by default.
