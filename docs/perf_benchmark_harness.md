# SF Performance Benchmark Harness

The canonical benchmark entry point is:

`scripts/tests/perf_benchmark_suite.gd`

This is the only supported regression runner. The old `tools/perf_benchmark_suite.gd` entry point is a fail-closed deprecation shim and cannot create output. Migration details and command mappings are recorded in [perf_harness_gate_f_migration.md](perf_harness_gate_f_migration.md).

## Current status

Phase 0, Gates A through F, and Phase 1 Gate P1-A are implemented:

- the canonical runner validates `data/perf/phase1_fixture_catalog_v1.json` before fixture selection or scene setup;
- missing, malformed, duplicate, drifted, over-capacity, or self-approved catalog entries fail closed;
- result schema version 3 adds catalog, measurement-profile, content, and environment-compatibility identity;
- all Phase 1 catalog entries remain design-only and baseline-ineligible; fixture execution begins in later gates;

- debug builds require the exact `--sf-perf-harness` user argument;
- release builds fail closed before fixture setup;
- gate configuration is required and validated;
- the approved target remains 30 FPS;
- every selected scenario completes static preflight before Arena creation;
- maps are loaded through the production `MapLoader`;
- normalized source counts are checked before setup;
- live counts are checked after `MapApplier.apply_map()`;
- map content SHA-256 is included in results;
- renderer visibility is labeled configuration state, not renderer timing;
- the broken No Man's Land `__p24.json` paths now use their verified `__1p.json` resources;
- `canonical_sim_headless` steps the production `SimRunner._tick()` path at an exact 100 ms interval with automatic processing disabled;
- `layer_isolation_noncanonical` is the explicit name for the selective reconstructed phase loop and is never baseline eligible;
- a debug-only, active-harness-only Arena seam applies and reports the requested match seed;
- bots are disabled through production `OpsState` profiles for the Phase 0 fixture;
- fixture configuration, map content, accepted command schedule, and final contract state are SHA-256 hashed;
- `phase0_integrity` runs the same fixed 50-tick fixture three times and fails on any evidence mismatch;
- every repetition snapshots and restores project switches, audio buses, engine pacing, rendering clear color, scene-tree metadata, OpsState, and multiplayer runtime state;
- protected account/progression autoloads and ten production save files are fingerprinted before and after each fixture;
- fixture-created root nodes and signal connections must return to their exact pre-fixture topology;
- discarded `GameState`/`UnitSystem` reference cycles are severed after Arena teardown, preventing ObjectDB/resource leaks;
- backend transport, analytics recording, and analytics flushing are denied while the harness is active;
- `phase0_isolation` runs a sentinel–mutator–sentinel sequence and fails on any cross-fixture contamination;
- result schema version 1 records build, engine, renderer, adapter, display server, viewport, stretch, render scale, pacing, execution mode, collection level, and fixture timing identity;
- every scenario carries a hashed comparison fingerprint covering fixture, map, accepted commands, runtime, renderer, resolution, mode, collection, warm-up, and measurement identity;
- metrics are classified as `DIRECT`, `DERIVED`, `CONFIGURATION_STATE`, `UNAVAILABLE`, or `EXTERNAL_PROFILER_REQUIRED`;
- unavailable GPU and renderer-section timings serialize as JSON `null` with a reason rather than zero;
- canonical comparisons use tick metrics, group repetitions by fixture, and compare the median of repetition summaries;
- schema-invalid or fingerprint-incompatible reports are refused before metric comparison;
- dirty current runs, dirty baseline files, failed/incomplete runs, and Phase 0 fixtures are explicitly refused for baseline approval;
- result schema version 2 requires an explicit bounded collector contract for every scenario;
- `OFF` performs no per-sample collector timing, aggregation, forensic retention, or raw-sample allocation;
- `MINIMAL` streams aggregates, retains a deterministic bounded percentile reservoir and top-N forensic evidence, and stores no raw-sample array;
- `FULL` adds bounded raw timing samples without removing the aggregate, percentile, forensic, or hitch bounds;
- total hitch counts remain streaming while only the bounded worst hitch records are retained;
- `phase0_collector_calibration` runs the same canonical fixture nine times in a staggered order, three repetitions each for `OFF`, `MINIMAL`, and `FULL`;
- the runner and supported offline command share one schema-v3/fingerprint-aware comparator;
- the unversioned runner and fail-open comparator entry points stop before setup or comparison and identify their supported replacements;
- rhythmic-lag isolation and soak runners remain separate forensic tools because their periodic pressure and detailed runtime sampling are not canonical regression fixtures.

Gates B and C prove that the canonical fixture is repeatable and isolated. Gate D makes the evidence self-describing and comparisons fail closed. Gate E bounds collection and characterizes its overhead. Gate F establishes one supported regression path without deleting or rewriting historical output. Phase 0 timing remains `NOT_GATED` and baseline-ineligible; production baseline approval requires a later clean-tree package and explicitly eligible fixtures.

## Commands

Run commands from the project root. Do not embed a developer-specific absolute path in scripts or documentation.

Focused Gate A contract test:

```bash
godot --headless --path . --script res://tools/perf_gate_a_smoke_test.gd
```

Focused Phase 1 Gate P1-A catalog/schema test:

```bash
godot --headless --path . --script res://tools/perf_phase1_gate_a_smoke_test.gd
```

Focused Gate B contract test:

```bash
godot --headless --path . --script res://tools/perf_gate_b_smoke_test.gd
```

Focused Gate C contract test:

```bash
godot --headless --path . --script res://tools/perf_gate_c_smoke_test.gd
```

Focused Gate D contract test:

```bash
godot --headless --path . --script res://tools/perf_gate_d_smoke_test.gd
```

Focused Gate E collector test:

```bash
godot --headless --path . --script res://tools/perf_gate_e_smoke_test.gd
```

Focused Gate F migration test:

```bash
godot --headless --path . --script res://tools/perf_gate_f_smoke_test.gd
```

Three-repetition canonical integrity proof:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=phase0_integrity \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/perf_gate_b_integrity.json
```

Back-to-back isolation proof:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=phase0_isolation \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/perf_gate_c_isolation.json
```

Repeated collector-overhead calibration:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=phase0_collector_calibration \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/perf_gate_e_calibration.json
```

Short investigative simulation run:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=quick \
  --scenario=sim_bootstrap_5s \
  --mode=canonical_sim_headless \
  --output=res://debug_reports/perf_benchmark_latest.json
```

Windowed renderer run:

```bash
godot --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=quick \
  --mode=render_windowed \
  --output=res://debug_reports/perf_benchmark_render_latest.json
```

Compatible investigative comparison:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --suite=quick \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --baseline=res://debug_reports/perf_benchmark_previous.json \
  --output=res://debug_reports/perf_benchmark_compared.json
```

Offline comparison of two compatible schema-v3 reports:

```bash
godot --headless --path . \
  --script res://scripts/tools/perf_compare.gd -- \
  res://debug_reports/perf_benchmark_previous.json \
  res://debug_reports/perf_benchmark_latest.json
```

Generated output remains under the gitignored `debug_reports/` directory. Gate A through Gate F output is investigative and is not an approvable performance baseline.

## Gate A validation order

1. Parse arguments.
2. Enforce the debug-build and exact-argument policy.
3. Load and validate `data/perf/benchmark_gates.json`.
4. Build every selected scenario definition.
5. Run static preflight for every scenario.
6. Stop the entire suite if any static preflight fails.
7. Instantiate Arena and apply the preflighted map.
8. Validate live runtime counts.
9. Begin the scenario only after post-apply validation succeeds.

Static preflight validates resource existence, production map loading, execution mode, duration, seed shape, scenario arrays, command cadence, declared counts, and map hashing. Post-apply validation checks hives, towers, barracks, and structure slots against the normalized preflight model.

## Gate B integrity contract

The approved Phase 0 fixture is `PHASE0_INTEGRITY_CENTERSTRIKE_V1`. Each repetition uses Centerstrike, requested/effective seed `4101`, 50 exact canonical ticks, 10 timing warmup ticks, disabled bot profiles, and a fixed command schedule. A run passes only when every repetition accepts at least eight commands, observes both `attack` and `swarm`, remains in the running match phase, and matches on:

- fixture configuration hash;
- map content hash;
- requested seed;
- effective seed;
- accepted command-schedule hash;
- final `OpsState.get_contract_state_hash()` value.

## Gate C isolation contract

Each scenario captures its global and protected-state fingerprint before Arena creation. Cleanup is idempotent and runs for successful scenarios, setup failures, and missing canonical adapters. It:

1. clears the benchmark seed override and telemetry collector reference;
2. disables and queues the fixture scene root;
3. removes root children created by the fixture, including the Arena-only fallback HUD;
4. waits for deferred node/signal cleanup;
5. breaks the discarded fixture state's `GameState`/`UnitSystem` reference cycle;
6. restores project settings, audio buses, engine pacing, clear color, scene metadata, OpsState, and shared multiplayer autoload state;
7. waits for deferred restoration work and compares exact hashes and topology.

Protected state is asserted, not rewritten. The guard fingerprints profile, contest, rank, Honey, Hive, Battle Pass, achievement, Crucible, analytics, and Jukebox autoload state plus the following save locations:

- `profile.cfg`;
- contest entries and leaderboard cache;
- rank, Honey, Hive, Battle Pass, and Crucible state;
- analytics queue and analytics state.

Any protected-state change, surviving fixture node, signal difference, project/global mismatch, or allowed backend transport is a harness-integrity failure.

## Gate D result and comparison contract

Schema v1 was the first comparison-safe Gate D format. Gate E advanced the contract to schema v2 for mandatory bounded-collector behavior. Phase 1 Gate P1-A advances the current contract to `result_schema_version: 3` and fingerprint version 2. Schema v3 adds catalog schema/version/hash and registration state, measurement profile, synthetic-or-map content identity, and an environment-compatibility hash covering renderer/display, viewport/stretch/render scale, pacing/VSync, camera identity, and cadence identity. Historical unversioned, v1, and v2 output remains preserved and comparison-incompatible by design.

All three collection levels are implemented. The scenario fingerprint makes the selected level comparison-critical, so reports from different levels cannot be compared as if their instrumentation were identical.

Comparisons proceed only when both schemas validate and every comparison-critical field matches for every fixture repetition. Canonical simulation compares `average_tick_ms`, `p95_tick_ms`, `p99_tick_ms`, and `max_tick_ms`. Windowed and noncanonical layer modes use their frame/iteration fields. Missing comparison metrics never default to zero.

Baseline approval is separate from investigative comparison. Approval is refused when either report is dirty, schema validation or compatibility fails, run integrity fails, the run fails, or any selected scenario is not explicitly baseline eligible. All current Phase 0 scenarios intentionally remain ineligible.

## Gate E bounded collection contract

`OFF` executes the same fixture and integrity checks but skips per-sample collector clock reads. Timing summaries and timing metric values serialize as unavailable/null. One outer wall-clock interval surrounds the measured canonical window only when running the calibration suite; that common interval exists in every level and is not a per-tick collector sample.

`MINIMAL` maintains exact streaming count, sum/average, minimum, maximum, and total hitch count. It retains at most 4,096 deterministic reservoir samples for percentile calculation plus at most the configured top-N worst and hitch records, capped at 64. The default top-N is 10 because the current gate file does not override `worst_frame_limit`. It does not retain raw samples.

`FULL` uses the same streaming aggregates and forensic bounds, raises the percentile reservoir bound to 16,384, and retains at most 12,000 raw `{sample_index, duration_ms}` records. Every result reports retained/dropped counts, whether percentiles are exact for that run, and whether any bounded history was truncated.

The canonical calibration order is `OFF, MINIMAL, FULL, FULL, OFF, MINIMAL, MINIMAL, FULL, OFF`. Each repetition uses the same fixture seed, commands, tick window, and cleanup contract. The calibration fails if any mode is missing three repetitions or exhibits the wrong timing/raw-capture behavior. Normal determinism evidence separately requires identical fixture, map, seed, command, and final-state hashes.

The Gate E verification run on the current dirty Apple M2 Pro development tree observed median measured-window durations of 39.980 ms (`OFF`), 40.261 ms (`MINIMAL`), and 40.304 ms (`FULL`). Those corresponded to observed median deltas of +0.70% and +0.81% versus `OFF`. They are directional evidence from one staggered nine-run set, not an exact instrumentation-cost claim or an approvable baseline.

## Gate F migration contract

The canonical runner and `scripts/tools/perf_compare.gd` call the same comparator implementation. That comparator validates schema and comparison fingerprints before reading mode-correct metrics, rejects missing metrics instead of substituting zero, and aggregates repeated fixture summaries by median. The retired commands exit with code 2 and cannot write benchmark output.

Historical result files remain untouched and retain their original meaning. Unversioned legacy output and schema v1, v2, and v3 output are distinct evidence classes; migration does not rewrite one class into another. The full capability and invocation audit is in [perf_harness_gate_f_migration.md](perf_harness_gate_f_migration.md).

## Phase 1 status

The Phase 0 evidence package remains recorded in [swarmfront_performance_harness_v1.md](swarmfront_performance_harness_v1.md). Phase 1 Gates P1-A through P1-F are complete, with approved clean-tree baselines under `data/perf/baselines/phase1/`. The formal environment, evidence, package, verification, diagnostics, limitations, and recommendation are in [swarmfront_performance_harness_phase1_exit.md](swarmfront_performance_harness_phase1_exit.md). Multiplayer 3- and 4-player fixtures remain deferred until their production behavior and tests are established.
