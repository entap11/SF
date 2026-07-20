# Swarmfront Performance Harness v1 — Phase 0 Evidence

Date: 2026-07-19
Scope: correctness, consolidation, and trustworthiness only
Recommendation: `PHASE 0 READY WITH LIMITATIONS`

## Summary

Phase 0 repaired and consolidated the existing benchmark infrastructure around `scripts/tests/perf_benchmark_suite.gd`. The canonical path now validates fixtures before Arena creation, runs the production `SimRunner._tick()` sequence, applies a real debug-only fixed seed, bounds collection, restores shared state after every repetition, blocks backend and analytics activity, emits schema-v2 comparison identities, and refuses incompatible or dirty baseline approval.

The unversioned runner and fail-open comparator are now refusal shims. Rhythmic-lag isolation and soak testing remain separate forensic tools. No production optimization or broad fixture expansion was performed.

## Architecture audit

### Existing tools and conventions

| Area | Finding |
| --- | --- |
| Newer benchmark runner | `scripts/tests/perf_benchmark_suite.gd`; selected as canonical after repair. |
| Older benchmark runner | `tools/perf_benchmark_suite.gd`; formerly wrote unversioned results with weaker validation and isolation. Now a deprecation shim. |
| Comparison implementations | The runner, `scripts/tools/perf_compare.gd`, and `tools/perf_compare.gd` contained divergent logic. The runner and supported CLI now use `perf_baseline_comparator.gd`; the older CLI refuses. |
| Hitch forensics | `scripts/tests/rhythmic_lag_isolation.gd` already provides detailed frame timelines, periodicity, Godot monitors, and layer toggles. It remains distinct from regression evidence. |
| Soak testing | `scripts/dev/soak_perf_runner.gd` preserves long periodic lane-pair pressure. It remains investigative. |
| Test convention | Headless `SceneTree` scripts under `tools/`, invoked with `godot --headless --path . --script res://...`. |
| Fixture maps | Production `MapLoader` and `MapApplier` are the canonical parse/apply paths. Phase 0 uses existing Centerstrike, No Man's Land, and Quadfight JSON resources. |
| Generated evidence | `res://debug_reports/`; the directory is already gitignored. Historical `docs/perf_layer_cost_results.md` was not overwritten. |
| Deterministic execution | Production simulation ownership is `scripts/systems/sim_runner.gd`; Arena owns match RNG initialization. |
| Existing metrics | `Time.get_ticks_usec()`, SimRunner phase costs, runtime telemetry snapshots, and Godot `Performance` monitors are available. GPU-stage attribution is not available in headless runs. |

### Renderer ownership

| Surface | Primary owner |
| --- | --- |
| Floor | `scripts/renderers/floor_renderer.gd` and floor influence helpers under `scripts/fx/` |
| Units | `scripts/renderers/unit_renderer.gd`; production pool ceiling confirmed as 400 |
| Hives, growth, distress | `scripts/renderers/hive_renderer.gd` and hive scene/controller scripts |
| Lanes | `scripts/renderers/lane_renderer.gd`, `lane_geometry.gd`, and `edge_visual.gd` |
| Towers | `scripts/renderers/tower_renderer.gd` and `tower_ground_glow_renderer.gd` |
| Barracks | `scripts/renderers/barracks_renderer.gd` and `barracks_ground_glow_renderer.gd` |
| Shadows | `scripts/renderers/match_shadow_controller.gd`, `match_shadow_catalog.gd`, and `visual_shadow.gd` |
| Swarm presentation | `scripts/renderers/swarm_bee_renderer.gd` plus `scripts/vfx/vfx_manager.gd` |
| Arena presentation switches | `scripts/renderers/arena_polish_layer.gd` and scene-node visibility controls |
| UI overlays | Arena HUD/UI scene nodes and scripts under `scripts/ui/`; no Phase 0 UI fixture was added |

### Runtime ownership

| Runtime concern | Owner |
| --- | --- |
| Ordered simulation ticks | `scripts/systems/sim_runner.gd` |
| Bot decisions | SimRunner-owned bot system |
| Lanes, units, swarms, towers, barracks | Systems invoked by `SimRunner._tick_systems()` |
| Buff effects | `OpsState.tick_authoritative_buff_effects()` in the canonical tick |
| Statistics and win checks | `SimRunner._update_match_stats()` and `_check_match_win()` |
| Commands and state hashes | `OpsState`; final evidence uses `get_contract_state_hash()` |
| Match RNG | Arena match-seed computation and RNG seeding |
| Networking polling | `VsPvpRuntime`; snapshotted/restored and blocked by harness policy |
| Runtime telemetry | Arena, SimRunner, UnitSystem, OpsState, and VsPvpRuntime |

### Coupling findings

- Unit simulation and unit presentation are coupled through the Arena/UnitSystem render-model flow. Phase 0 does not claim a fully independent unit-render toggle.
- Hive growth, distress, shadows, and temporary effects have lifecycle coupling in HiveRenderer and hive nodes. They require dedicated later fixtures, not broad production refactoring.
- The canonical simulation path intentionally runs all production phases. Selective phase execution remains labeled `layer_isolation_noncanonical`.
- UI and full Arena presentation require a windowed display. Headless runs cannot substitute meaningful renderer or GPU zeros.
- Network-adjacent state can be isolated and restored, but a full network laboratory is deferred.

### Presence classification for deferred inventory

| System | Classification | Note |
| --- | --- | --- |
| Unit pool and pool telemetry | `PRESENT_ISOLATABLE` | Fixed pool size 400; scale fixtures deferred |
| Hive transitions/distress | `PRESENT_COUPLED` | Dedicated lifecycle fixtures deferred |
| Dynamic hive shadows | `PRESENT_COUPLED` | Existing controller and setting; no Phase 0 cost claim |
| VFX manager and GPU/CPU preference | `PRESENT_COUPLED` | Production behavior unchanged |
| Arena polish comparison modes | `PRESENT_ISOLATABLE` | Existing switches are snapshotted/restored |
| Production fog renderer | `NOT_PRESENT` | Gameplay fog metadata is not a proved production fog rendering stack |
| Broad bloom/post-processing stack | `NOT_PRESENT` | Individual glow shaders do not establish a broad post stack |
| Winning-move chase camera | `FUTURE` | No fixture or control added |
| Shadow sun sweep | `FUTURE` | No fixture or control added |
| Full deterministic four-player fixture | `FUTURE` | Explicitly deferred pending multiplayer behavior/tests |

## Verified reported findings

| Reported finding | Audit result | Phase 0 disposition |
| --- | --- | --- |
| Two newer-runner map paths ended in nonexistent `__p24.json` files | Correct | References changed to the verified `__1p.json` resources; no runtime substitution |
| Approved benchmark target is 30 FPS | Correct | Gate file remains authoritative and validates at 30 FPS |
| Newer fallback defaults targeted 60 FPS | Correct | Canonical runner has no second fallback; missing/invalid gates fail closed |
| Old `sim_headless` duplicated only part of production simulation | Correct | Canonical mode directly invokes `SimRunner._tick()`; selective mode renamed noncanonical |
| The duplicated loop omitted/differed on buffs, statistics, or win checks | Correct | Canonical tick includes buff effects, match statistics, and win checks |
| Seed metadata did not control Arena RNG | Correct | Debug-only active-harness seam now sets and verifies requested/effective seed |
| Render section timing described visibility state as measured cost | Correct | Visibility is `CONFIGURATION_STATE`; unsupported renderer/GPU values are null with reasons |
| ProjectSettings switches lacked complete restoration | Correct | Snapshot/restore now covers the touched settings plus audio, pacing, clear color, metadata, OpsState, shared runtime, and topology |
| Older runner/comparator remained referenced by live docs | Correct | Supported docs now point to canonical commands; old entry points refuse with replacements |
| Broad inventory contains absent/future systems | Correct | Absent/future systems remain classified and no fake controls were created |

## Canonical runner and migration

The supported CLI is:

`scripts/tests/perf_benchmark_suite.gd`

It owns fixture selection, preflight, seed identity, warm-up and measurement windows, repetitions, collection, cleanup, schema application, result writing, and optional comparison.

Migration classification for the old runner: `DEPRECATED_PARITY_CONFIRMED` for supported regression use. Its unique periodic pressure/runtime-snapshot behavior remains available through the richer rhythmic-lag and soak tools. The full parity record is in `docs/perf_harness_gate_f_migration.md`.

Historical result files were not rewritten, upgraded, deleted, or presented as schema-v2 evidence.

## Correctness work

### Fixture validation

Before Arena creation, preflight now validates:

- stable scenario ID and supported fixture version;
- supported execution mode;
- bounded duration, tick count, warm-up, and repetition count;
- numeric seed;
- systems/renderers array shape;
- supported command schedule kinds, fields, and tick bounds;
- camera schedule shape, with nonempty Phase 0 camera schedules explicitly refused because they are not implemented;
- nonnegative setup/burst counts;
- map existence and SHA-256;
- production `MapLoader` acceptance;
- normalized expected hives, towers, barracks, and structure slots.

After `MapApplier.apply_map()`, live counts must match the normalized preflight model. Any failure is an invalid/integrity result and cannot be represented as a successful benchmark.

### Gate governance

`data/perf/benchmark_gates.json` is required and validated. Its approved target is 30 FPS. Missing, malformed, incomplete, or 60-FPS substitute configuration is refused. The runner does not mutate production `Engine.max_fps` to meet the gate.

### Simulation path

`canonical_sim_headless` disables SimRunner's automatic processing and invokes its production `_tick(0.1)` method exactly once per scheduled tick. This preserves production phase ordering and delta semantics. `layer_isolation_noncanonical` remains available only for investigative selective-phase work and is never baseline eligible.

### Seed contract

Arena exposes a narrow seam that requires all of:

- debug build;
- active `sf_perf_harness_active` SceneTree marker;
- explicit fixture seed.

The seam recomputes and seeds Arena RNG, reports the effective seed, and is cleared during cleanup. Production RNG derivation is unchanged outside the active harness.

### State restoration and interrupted exit

Every repetition captures and restores:

- touched ProjectSettings keys;
- every audio bus's volume, mute, solo, bypass, and effect-enable state;
- `Engine.time_scale`, physics ticks, and max FPS;
- RenderingServer clear color;
- SceneTree metadata;
- OpsState script properties and RNG states;
- AppLifecycle, VsHandshake, and VsPvpRuntime script state;
- protected autoload fingerprints and ten production save-file fingerprints;
- root/Arena node topology and selected OpsState signal connections.

Normal cleanup disables and frees fixture roots, removes other fixture-created root nodes, clears seed/telemetry seams, breaks discarded GameState/UnitSystem cycles, restores state, settles deferred cleanup, and verifies exact hashes/topology. Cleanup is idempotent.

The SceneTree `_finalize()` path now performs synchronous recovery for an armed repetition and clears analytics isolation and the harness marker. A forced OS `SIGKILL` cannot execute application cleanup; no stale persistent marker is used because harness overrides are process-local and the harness is prohibited from writing protected state. The next run re-fingerprints protected files before setup.

### Release and backend guard

The runner checks `OS.is_debug_build()` plus the exact `--sf-perf-harness` user argument before any harness marker, analytics isolation, Arena, fixture, or output setup. Release policy returns `release_build_refused`. Arena's seed seam separately enforces the same debug/active-harness boundary.

While active, `TestBackendPolicy` denies live and loopback transport, and AnalyticsClient refuses record, flush, and file-sink work. Every suite result records backend-isolation status.

## Metrics and collection

Schema v2 requires each metric to be classified as `DIRECT`, `DERIVED`, `CONFIGURATION_STATE`, `UNAVAILABLE`, or `EXTERNAL_PROFILER_REQUIRED`.

- Canonical tick duration and frame deltas are direct CPU wall-clock measurements.
- Percentiles and comparison deltas are derived.
- Renderer visibility/switch state is configuration state.
- Headless render/GPU values are unavailable, never meaningful zeroes.
- GPU stage time, Metal overdraw, shader occupancy, and device energy/thermal behavior require Xcode/Metal, Android tooling, RenderDoc where supported, or the Godot profiler.

Collection levels:

| Level | Behavior |
| --- | --- |
| `OFF` | No per-sample collector clock reads, aggregates, forensics, raw allocation, or timing values |
| `MINIMAL` | Streaming aggregates, deterministic bounded percentile reservoir, bounded worst/hitch evidence, no raw samples |
| `FULL` | MINIMAL behavior plus bounded raw timing records |

The staggered nine-run calibration observed medians of 39.980 ms (`OFF`), 40.261 ms (`MINIMAL`), and 40.304 ms (`FULL`) for the common measured window: +0.70% and +0.81% versus OFF. This is directional dirty-tree evidence, not an exact overhead claim.

## Result and comparison contract

Every schema-v2 result records the build/git identity, environment, renderer/display, viewport/stretch/render scale, pacing, suite/mode/collection, fixture version/config hash, map path/hash, requested/effective seed, accepted command hash, final state hash, timing windows, repetition index, collection retention, metric classifications, run status, and cleanup evidence.

Comparison-critical fingerprints include schema, fixture/version/config, map, accepted commands, Godot/build, renderer/driver/adapter, viewport/stretch, execution mode, collection level, timing windows, target FPS, and physics tick rate.

The shared comparator:

- validates both schemas and fingerprints before reading metrics;
- uses tick metrics for canonical simulation and frame/iteration metrics elsewhere;
- refuses missing metrics instead of substituting zero;
- groups repetitions by fixture and compares medians of repetition summaries;
- returns PASS/WARN/FAIL/INCOMPATIBLE with exit codes 0/1/2.

Baseline approval is separate. Dirty reports, dirty baselines, invalid/incomplete/failed runs, incompatible fingerprints, or noneligible fixtures are refused. All Phase 0 fixtures are intentionally baseline-ineligible.

## Determinism evidence

Latest acceptance evidence: `debug_reports/perf_phase0_exit_integrity.json`

| Field | Repetitions 1–3 |
| --- | --- |
| Fixture | `PHASE0_INTEGRITY_CENTERSTRIKE_V1` |
| Requested/effective seed | `4101 / 4101` |
| Fixture config hash | `2e0593d0fa66bfdeaa1f551f55ce523fdec762863008563540abdc782df498bd` |
| Map content hash | `f474c9e6aad7b5761c6ff07f1d6407448b9899d0c06472aa9a895d39163df78a` |
| Accepted command hash | `243e49798fcac7537289f9296fcbed6b51a7057a8029e69a19a36efc2a24663d` |
| Final state hash | `95acf8167a53593014b7a2dbcfa5fac268db6b6b0430e2fcc87f34f39e9f31ac` |
| Match across all repetitions | Yes |

Each repetition independently warmed up for 10 ticks, measured 40 ticks, accepted the required attack/swarm schedule, remained in the running phase, freed its fixture root, and restored matching global/protected-state hashes.

## Required test coverage

| Required area | Evidence |
| --- | --- |
| Invalid/missing resource and malformed gates | Gate A |
| Invalid production map/schema | Gate A production MapLoader preflight |
| Incorrect expected counts | Gate A |
| Unsupported mode/version/command/camera schedule | Gate A |
| Release refusal | Gate A policy plus runner/Arena source contracts |
| Backend and analytics isolation | Gate C plus suite backend evidence |
| Progression/rank/economy/save isolation | Gate C protected-state hashes and full suite cleanup evidence |
| ProjectSettings/audio/pacing/Ops restoration | Gate C and isolation suite |
| Seed/commands/final-state repeatability | Gate B and three-repetition integrity suite |
| Warm-up exclusion | Canonical result contract and measured-tick counts |
| Percentile correctness and bounded storage | Gate E collector tests |
| Unsupported metric serialization | Gate D |
| Schema/version/fingerprint validation | Gate D |
| Incompatible and dirty baseline refusal | Gate D/F |
| Fixture cleanup and topology leaks | Gate C and isolation suite |
| Interrupted-exit recovery | Gate C shutdown source contract plus idempotent guard behavior |
| Collector modes/calibration | Gate E and nine-run calibration |
| Duplicate runner/comparator migration | Gate F and real command-boundary checks |

## Commands and results

All commands run from the project root.

Focused contracts:

```bash
godot --headless --path . --script res://tools/perf_gate_a_smoke_test.gd
godot --headless --path . --script res://tools/perf_gate_b_smoke_test.gd
godot --headless --path . --script res://tools/perf_gate_c_smoke_test.gd
godot --headless --path . --script res://tools/perf_gate_d_smoke_test.gd
godot --headless --path . --script res://tools/perf_gate_e_smoke_test.gd
godot --headless --path . --script res://tools/perf_gate_f_smoke_test.gd
```

Result: Gates A–F passed together on Godot 4.2.2.

Canonical integrity:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=phase0_integrity \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/perf_gate_f_integrity.json
```

Result: completed, integrity PASS, determinism PASS, backend isolation PASS, three repetitions PASS. The final fixture, map, command, and state hashes match the table above.

Isolation sequence:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=phase0_isolation \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/perf_phase0_exit_isolation.json
```

Result: completed, integrity PASS, backend isolation PASS, and all three sentinel–mutator–sentinel cleanup hashes matched with every fixture root freed.

Offline comparison:

```bash
godot --headless --path . \
  --script res://scripts/tools/perf_compare.gd -- \
  res://debug_reports/perf_gate_e_minimal.json \
  res://debug_reports/perf_gate_e_comparison.json
```

Result: compatible PASS; baseline approval correctly refused for dirty/noneligible evidence.

## Phase 0 file manifest

Phase 0-owned files or hunks:

| Path | Purpose |
| --- | --- |
| `scripts/tests/perf_benchmark_suite.gd` | Canonical controller/runner |
| `scripts/tests/perf/perf_run_policy.gd` | Debug/release/argument governance |
| `scripts/tests/perf/perf_fixture_validator.gd` | Gates and fixture preflight/post-apply checks |
| `scripts/tests/perf/perf_deterministic_hash.gd` | Stable evidence hashing |
| `scripts/tests/perf/perf_isolation_guard.gd` | Snapshot, restoration, protected state, topology |
| `scripts/tests/perf/perf_metrics_collector.gd` | Bounded OFF/MINIMAL/FULL collection |
| `scripts/tests/perf/perf_result_contract.gd` | Schema v2, classifications, fingerprints, approval |
| `scripts/tests/perf/perf_baseline_comparator.gd` | Shared fail-closed comparison |
| `scripts/tools/perf_compare.gd` | Supported offline comparator client |
| `scripts/arena.gd` | Narrow benchmark-only seed override hunk; file also contains unrelated worktree changes |
| `scripts/state/analytics_client.gd` | Harness analytics-denial seam; file may contain adjacent worktree changes |
| `scripts/state/test_backend_policy.gd` | Deny all backend transport while harness marker is active |
| `tools/perf_benchmark_suite.gd` | Old-runner refusal shim |
| `tools/perf_compare.gd` | Old-comparator refusal shim |
| `tools/perf_gate_a_smoke_test.gd` through `perf_gate_f_smoke_test.gd` | Focused Phase 0 contracts |
| `docs/perf_benchmark_harness.md` | Supported operating guide |
| `docs/perf_harness_gate_f_migration.md` | Capability/invocation/schema migration record |
| `docs/perf_layer_cost_mod_map.md` | Portable command correction only |
| `docs/swarmfront_performance_harness_v1.md` | This final evidence and exit record |

Audited but intentionally unchanged: `data/perf/benchmark_gates.json`, map JSON resources, `scripts/systems/sim_runner.gd`, `scripts/tests/rhythmic_lag_isolation.gd`, `scripts/dev/soak_perf_runner.gd`, and `docs/perf_layer_cost_results.md`.

## Generated evidence policy

Runtime reports are written under the gitignored `debug_reports/` directory. Current runs are investigative because the worktree is dirty and every Phase 0 fixture declares itself baseline-ineligible. No generated report should be committed or promoted as an approved baseline.

## Risks and limitations

- The working tree includes substantial unrelated changes; Phase 0 hunks must be reviewed/staged selectively.
- No clean-tree production baseline exists.
- A real exported release binary was not launched; release refusal is covered by policy tests and duplicate guards in the runner/Arena seam.
- Windowed renderer runs are environment-sensitive and have not produced an approved gate result.
- Headless runs cannot provide GPU time, draw attribution, overdraw, device thermals, or energy evidence.
- The interrupted-exit path runs for orderly MainLoop shutdown; a forced process kill cannot execute cleanup.
- The full feature registry and fixture catalog are deliberately deferred.
- Multiplayer 3-/4-player, multi-stage async, broad UI, lifecycle soak, networking, and device fixtures are not Phase 0 evidence.
- Existing Godot output includes NUL-decoding warnings plus an asset UID fallback and shader-compiler diagnostic during Arena loading; they did not fail the integrity suite but should be tracked independently.

## Deferred fixture roadmap

After separate approval, the first fixture program remains:

1. `EMPTY_ARENA`
2. `STATIC_BATTLEFIELD`
3. `NORMAL_MATCH`
4. `UNIT_SCALE` at 50/100/200/400
5. `HIVE_UPGRADE_STORM`
6. `SUPER_SWARM_CHAIN`

Later work includes distress, capture, lane, structure, UI, lifecycle-soak, network/device, and eventual multiplayer fixtures. This document does not authorize that expansion.

## Governance confirmation

- No gameplay rule was changed for the harness.
- No production feature was optimized, reduced, or disabled by default.
- No rank, economy, progression, inventory, contest, public leaderboard, or match-history mutation was added.
- No public harness flag or player-facing entry point was enabled.
- No backend deployment or external message occurred.
- Historical performance evidence was preserved.
- Generated dirty-tree evidence remains investigative.

## Final recommendation

`PHASE 0 READY WITH LIMITATIONS`

The correctness foundation, migration, evidence package, and bounded exit verification are complete. Phase 0 is ready to exit with the limitations above. When committing, stage the manifest paths and the Phase 0 hunks in shared files selectively so unrelated worktree changes are not swept into the package. Do not begin the deferred fixture expansion without separate approval.
