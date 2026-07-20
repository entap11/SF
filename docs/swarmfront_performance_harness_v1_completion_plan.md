# Swarmfront Performance Harness V1 Completion Plan

Status: `SPRINT COMPLETE — MERGE EVALUATION READY`

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

Implemented evidence:

- Both fixtures build deterministic topology and starting power only; every lane and swarm action is accepted through production `OpsState.apply_lane_intent`, and every simulation advance uses canonical `SimRunner._tick(0.1)`.
- `HIVE_UPGRADE_STORM_V1` drives six concurrent six-unit Super Swarms into six exact production tier crossings. The acceptance matrix observed six active swarm renderers, six active growth transitions, 15 visible growth rings, 78 growth materials, and complete active-transition/swarm cleanup.
- `SUPER_SWARM_CHAIN_V1` proves the production landing ledger and carry consumption across two consecutive six-unit swarms, including renderer creation, tier crossing, and final cleanup.
- Three repetitions per fixture produced identical command, event, and final-state hashes. All six repetitions restored the same protected-state hash and passed analytics/backend isolation.
- The runner disables only the existing process-local automatic GPU-VFX fallback while a benchmark is active, then restores the environment. Full GPU VFX remain enabled and the isolated profile remains unchanged; ordinary game behavior is unaffected.
- Windowed timing remains diagnostic for P2-C. This acceptance run exposed periodic roughly one-second presentation stalls (9–12 hitches per repetition, maximum 1039.421 ms), retained as a P2-G investigation item rather than hidden or promoted to a correctness failure.

### P2-D — Battlefield and UI stress

Implement late-match, lane, structure, distress, capture, camera, and UI fixtures. File-backed fixtures use production `MapLoader`/`MapApplier`; synthetic presentation fixtures must declare and hash their synthetic identity. Camera/UI evidence is windowed-only.

Implemented evidence:

- The deterministic windowed suite contains the exact seven-fixture inventory: late match, lane, structure, distress, capture, camera, and UI stress. Production-map fixtures retain their `MapLoader` content hash; synthetic fixtures declare a hashed `sf_perf_synthetic_scene_v1` descriptor.
- Late-match stress reached 200 moving units through public `UnitSystem` injection without bypassing the 400-unit capacity or expanding the renderer pool. Lane stress retained eight active lanes and exercised production Super Swarm commands.
- Structure stress applied two towers and two barracks through the production state/renderer path. Distress stress observed six simultaneous active, pressure, and rupture render states; capture stress recorded six exact ownership transitions.
- Camera stress targeted the exact `Arena/Camera2D` node, and UI stress targeted exact Main-scene paths. Both schedules are fail-closed against the deterministic frame cadence and are windowed-only.
- The 21-run acceptance matrix completed three repetitions per fixture with identical event and final-state hashes, zero integrity failures, exact protected-state restoration, every fixture root freed, and analytics/backend isolation passing.

### P2-E — Lifecycle soak

Run bounded repeated setup, measurement, and cleanup cycles. Compare protected-state, topology, node/object/resource, pool, sample-retention, and memory evidence. No unbounded arrays or report growth are allowed.

Implemented evidence:

- `LIFECYCLE_SOAK_V1` runs eight bounded deterministic-windowed setup, canonical measurement, and cleanup cycles through the existing harness controller. The global harness repetition ceiling remains 10.
- Every cycle moved 100 production units, retained the fixed 400-object renderer pool with zero misses or expansions, restored the same protected-state and tree-topology hashes, and freed its fixture root.
- After the first warmed cleanup, node and resource counts returned exactly, orphan nodes remained zero, object count grew by one, and retained static memory grew by 1,716,716 bytes against a 32 MiB fail-closed ceiling.
- FULL collection retained exactly 90 percentile and 90 raw samples per cycle. Total retained report payload was 255,456 bytes; each report is independently capped at 1 MiB and every collector array is checked against its declared limit.
- The focused Gate E exercise mutates engine state, installs a disposable fixture `GameState`, and adds a fixture root, then invokes the same isolation release/restore primitives used by synchronous interruption recovery. Protected state and topology verify exactly afterward.

### P2-F — Feature isolation

Complete the requested feature inventory. Every entry is classified as `PRESENT_ISOLATABLE`, `PRESENT_COUPLED`, `NOT_PRESENT`, or `FUTURE`, records its exact owner, and declares whether off/production/exaggerated variants are comparison-safe. Only exact, reversible controls enter the regression harness.

Implemented evidence:

- `feature_isolation_registry_v1.json` inventories 47 code-derived feature groups across every requested domain: 13 `PRESENT_ISOLATABLE`, 24 `PRESENT_COUPLED`, five `NOT_PRESENT`, and five `FUTURE`. Every present entry names its exact scene/script owner and every entry resolves an explicit off/production/exaggerated policy.
- Registry validation rejects unknown classifications, missing owners/sources, duplicate IDs, incomplete categories, unsafe scene paths, broad/fragment controls, and supported variants on absent/future features. Unknown CLI switches refuse before fixture setup.
- Whole renderer-layer controls use exact Arena paths; tower and barracks controls include their exact ground-glow companions. Coupled subvisuals remain production-only rather than acquiring test-only seams.
- `phase2_feature_isolation` runs arena polish at `baseline`, production `settings`, and diagnostic `tower_150`. Three repetitions per variant preserve all non-target identities, restore global state, and produce stable variant configuration hashes.
- The current production setting resolves polish disabled; the report states this explicitly. The exaggerated variant resolves polish enabled at exactly 1.5×. Timing remains diagnostic and is not promoted to a performance claim.

### P2-G — Baselines and exit

Run all Phase 0–2 focused gates, deterministic suites, isolation sequences, collector calibration, lifecycle checks, and clean-tree candidate profiles. Package only compatible and eligible evidence. Device GPU, thermal, and energy evidence is collected only when tooling is available; otherwise the exact external workflow and missing evidence are reported.

Implemented evidence:

- All 18 Phase 0–2-F focused gates passed before Gate G. The exit exercise completed 95 real scenario runs with zero failures: 15 Phase 0 integrity/isolation/calibration runs, 24 clean Phase 1 candidates, and 56 Phase 2 correctness/diagnostic runs.
- Four clean-tree candidate profile families from commit `557a8e5` were approved into `data/perf/baselines/harness_v1`. All use MINIMAL bounded collection, three repetitions, eligible runtime identities, and 4/4 compatible self-comparisons.
- The older Phase 1 package is retained for audit but correctly compares as incompatible because finalized renderer-isolation configuration changed `fixture_config_hash`. Phase 2 diagnostics remain baseline-ineligible and were not packaged.
- Collector calibration passed nine staggered repetitions. Observed median deltas versus OFF were 0.749% for MINIMAL and 1.242% for FULL, retained only as directional evidence.
- Xcode 26.6 provides Metal System Trace and Time Profiler, but the physical iPhone was offline; Android `adb` is unavailable. The exit report records exact iOS and Android follow-up workflows and does not fabricate GPU, thermal, or energy values.
- The machine-readable decision and full merge evaluation are `data/perf/harness_v1_exit.json` and `docs/swarmfront_performance_harness_v1_exit.md`. Final recommendation: `HARNESS V1 READY WITH LIMITATIONS`.

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

The final report chooses exactly one:

- `HOLD`;
- `HARNESS V1 READY WITH LIMITATIONS`;
- `HARNESS V1 READY`.

Selected: `HARNESS V1 READY WITH LIMITATIONS`.

No merge or deployment is part of this sprint.
