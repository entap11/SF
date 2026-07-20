# Swarmfront Performance Harness V1 Completion Plan

Status: `P2-B COMPLETE — P2-C NEXT`

Branch: `codex/perf-harness-v1-completion`

Base: Phase 1 approved baseline package at `5588c4b`.

## Objective

Complete the safe, production-grounded Harness V1 inventory without optimizing the game or changing gameplay authority. Work advances only after the current phase passes its focused gate plus every earlier performance-harness regression gate. Each completed phase receives one reviewable commit and is pushed before the next phase starts.

The machine-readable phase contract is `res://data/perf/harness_v1_completion_program.json`.

## Code-derived ownership

- `scripts/tests/perf_benchmark_suite.gd` remains the sole regression harness controller. No third harness is permitted.
- `scripts/tests/rhythmic_lag_isolation.gd` remains the forensic timeline tool. Proven controls may be extracted into shared infrastructure only when exact restoration is covered.
- Canonical simulation remains `SimRunner._tick(0.1)`. Selective subsystem ticking is investigative and baseline-ineligible.
- Unit movement and capacity remain owned by `UnitSystem`; the production active and renderer-pool ceiling is 400.
- Hive tier identity comes from production power thresholds and `HiveGrowthRules`; presentation lifecycle is owned by `HiveRenderer` and hive nodes.
- Super Swarm behavior is the production `SwarmSystem` request, pickup, growth, pass-through, and landing path. No `MEGASWARM` fixture terminology is used.
- UI and renderer fixtures require deterministic windowed execution. Headless renderer values remain unavailable, never zero-filled.
- Feature controls must target exact owners or exact scene paths. Broad name-fragment hiding is forensic-only and cannot be promoted as a comparison-safe registry control.

## Phase gates

### P2-A — Program contract

Freeze phase order, exclusions, ownership, stop conditions, and required evidence. The contract must fail review if a phase is missing, duplicated, pre-approved, or expands into 3P/4P or async work.

### P2-B — Moving unit scale

Add deterministic moving profiles for 50, 100, 200, and 400 units. Setup continues to use accepted, fully built production lanes and public `UnitSystem.spawn_unit`. Measurement advances canonical simulation; it must prove starting scale, bounded evolution, repeatable final state, no capacity bypass, no renderer-pool expansion, and exact cleanup.

Implemented evidence:

- `phase2_moving_unit_scale` runs all four exact scales through production `UnitSystem` movement and canonical `SimRunner._tick(0.1)`.
- Three repetitions compare configuration, seed, schedule, final state, lane setup, pool state, unit-count timeline, and unit-motion hashes.
- The 12-run acceptance matrix completed with integrity, determinism, protected-state restoration, analytics isolation, and backend denial all passing; renderer pool misses and expansions remained zero.
- Moving-unit frame timing remains diagnostic and baseline-ineligible until P2-G reviews device-stable thresholds. Observed hitches are retained in the reports and are not converted into correctness failures.
- `--perf-user-dir=<safe-name>` redirects harness save files into a dedicated namespace before capture, preventing a concurrently running game from invalidating protected-state evidence. The runner validates the namespace, creates it explicitly, and records it in the report.

### P2-C — Hive upgrade and Super Swarm stress

Add `HIVE_UPGRADE_STORM_V1` and `SUPER_SWARM_CHAIN_V1` through production state and command paths. Fixed schedules must prove exact transition/swarm events and stable hashes across three repetitions. If production APIs cannot express the state safely, the fixture remains blocked rather than gaining a test-only gameplay shortcut.

### P2-D — Battlefield and UI stress

Implement late-match, lane, structure, distress, capture, camera, and UI fixtures. File-backed fixtures use production `MapLoader`/`MapApplier`; synthetic presentation fixtures must declare and hash their synthetic identity. Camera/UI evidence is windowed-only.

### P2-E — Lifecycle soak

Run bounded repeated setup, measurement, and cleanup cycles. Compare protected-state, topology, node/object/resource, pool, sample-retention, and memory evidence. No unbounded arrays or report growth are allowed.

### P2-F — Feature isolation

Complete the requested feature inventory. Every entry is classified as `PRESENT_ISOLATABLE`, `PRESENT_COUPLED`, `NOT_PRESENT`, or `FUTURE`, records its exact owner, and declares whether off/production/exaggerated variants are comparison-safe. Only exact, reversible controls enter the regression harness.

### P2-G — Baselines and exit

Run all Phase 0–2 focused gates, deterministic suites, isolation sequences, collector calibration, lifecycle checks, and clean-tree candidate profiles. Package only compatible and eligible evidence. Device GPU, thermal, and energy evidence is collected only when tooling is available; otherwise the exact external workflow and missing evidence are reported.

## Explicit exclusions

- 3-player and 4-player fixtures;
- multi-map and multi-stage async fixtures;
- gameplay, authority, RNG-default, feature-default, cap, renderer-quality, or pacing changes;
- public matchmaking, backend writes, analytics history, production telemetry, rank, economy, progression, achievements, contests, match history, or leaderboards;
- optimization based only on measured suspicion.

## Commit and test policy

For each phase:

1. run its focused fail-closed gate;
2. run all earlier Phase 2 gates;
3. run Phase 0 A–F and Phase 1 P1-A–P1-F;
4. run relevant real three-repetition fixtures and isolation checks;
5. require a clean tracked diff and `git diff --check`;
6. commit once with the phase identifier and push the completion branch;
7. continue automatically unless a machine-readable stop condition is reached.

## Exit recommendation

The final report will choose exactly one:

- `HOLD`;
- `HARNESS V1 READY WITH LIMITATIONS`;
- `HARNESS V1 READY`.

No merge or deployment is part of this sprint.
