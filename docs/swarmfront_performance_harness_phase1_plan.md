# Swarmfront Performance Harness Phase 1 Plan

Status: `P1-A COMPLETE — P1-B NEXT`

Phase 0 is complete with limitations. Phase 1 begins with the four approved fixture families below. This plan is derived from the current Godot project, not from an abstract benchmark design. It does not approve baselines, gameplay changes, 3-/4-player fixtures, or multi-map/multi-stage async fixtures.

The machine-readable design companion is `res://data/perf/phase1_fixture_catalog_v1.json`.

## Code-derived decisions

### Use the real 1P Centerstrike map

The production-backed fixtures use:

`res://maps/_future/centerstrike/MAP_centerstrike__SBASE__1p.json`

SHA-256: `5f7c582e8a45e2d6df96023216bd9c3be7a9f5e874956786c200e2a662dd0104`

This map is a better first 1v1 topology than the Phase 0 quick map. It has the `1P` bucket, P1/P2 start slots, 12 hives, no authored structures, and two walls. Bots remain disabled for deterministic harness runs. The `1p` name describes the map bucket; the runtime topology still contains P1, P2, and NPC hives.

### Empty arena must be explicitly synthetic

`MapSchema` and `MapLoader` reject maps with no hives. `EMPTY_ARENA_V1` therefore instantiates the production `Arena.tscn` shell without applying a map. It receives a hashed synthetic fixture descriptor and a `content_kind` of `synthetic_scene`; it must never claim a file-backed `map_content_hash`.

### Windowed timing needs a deterministic adapter

The current `render_windowed` mode starts the automatic simulation and schedules commands from elapsed wall time. That is useful investigative evidence, but it is not a deterministic baseline path.

Phase 1 adds `deterministic_windowed_presentation`:

- disable automatic `SimRunner` processing;
- render at the existing 30 FPS target;
- drive one canonical 10 Hz simulation tick every three rendered frames;
- warm up for 60 frames/20 ticks;
- measure 300 frames/100 ticks;
- use the production camera-fit path, wait for it to settle, and hash the resulting camera transform;
- hash cadence, viewport, renderer, display server, VSync state, and camera into the environment compatibility identity.

Static fixtures use the same fixed frame windows but execute zero simulation ticks during measurement. Existing `render_windowed` results remain investigative and baseline-ineligible.

The empty arena is the one camera exception: production map fitting correctly refuses a state with no hives. It uses the authored `Arena.tscn` `Camera2D` transform and hashes it. All production-map windowed fixtures use the settled production map-fit result.

### Unit scale uses production capacity and rendering paths

`UnitSystem.MAX_ACTIVE_UNITS` and `UnitRenderer.UNIT_POOL_SIZE_TOTAL` are both 400. The scale matrix is therefore 50, 100, 200, and 400—not a bypass-capacity stress test.

Setup creates accepted lanes through `OpsState.apply_lane_intent`, waits outside the measurement window until production lane construction reports complete, then injects deterministic units through public `UnitSystem.spawn_unit`. The wait is condition-based with a hard timeout; it is not a fixed sleep and contributes no measured samples. Units are distributed over sorted accepted lanes with deterministic progress values. Initial Phase 1 scale fixtures pause simulation after injection so the exact target remains invariant. A moving-unit profile is a later extension after the static matrix passes.

## Approved fixture catalog

| Fixture | Production path | Initial invariant | First profile |
| --- | --- | --- | --- |
| `EMPTY_ARENA_V1` | `Arena.tscn` shell; no map | 0 hives, lanes, units, structures, walls | Static deterministic windowed |
| `STATIC_BATTLEFIELD_V1` | `MapLoader` + `MapApplier` on 1P Centerstrike | 12 hives, 2 walls, 0 active lanes/units/structures | Static deterministic windowed |
| `NORMAL_MATCH_V1` | Production map + canonical `SimRunner` + fixed commands | Exact accepted-command count and repeatable final state | Canonical headless and deterministic windowed |
| `UNIT_SCALE_050/100/200/400_V1` | Production map + lane intents + public unit spawn | Exact unit target; no pool expansion past configured 400 | Static deterministic windowed |

Seeds are fixed in the catalog. A seed, map, schedule, count, duration, camera, cadence, or profile change creates a new fixture version or compatibility identity; it cannot silently reuse an old baseline.

## Normal-match command schedule

The selector is versioned as `sorted_candidate_pair_v1`, matching the harness's current deterministic sorting by relationship, distance, source, and destination. Phase 1 must run a pilot on the chosen 1P map before freezing pair indexes.

The pilot passes only when:

1. every scheduled intent is accepted through the production command path;
2. accepted command type/count/hash is identical across three repetitions;
3. final-state hash is identical across three repetitions;
4. no bots or unscheduled production mutate the command stream;
5. schedule meaning and exact indexes are recorded in the catalog.

Until that pilot passes, `NORMAL_MATCH_V1` remains `PILOT_REQUIRED_BEFORE_FREEZE` and cannot be baseline-eligible.

## Measurement contract

All first baselines use three repetitions and `MINIMAL` collection. Metrics remain classified as direct, derived, or unavailable; the harness does not fabricate GPU timings.

Canonical simulation records tick average, p50, p95, p99, maximum, phase timings, final-state hash, command evidence, and entity counts.

Windowed profiles record frame p50, p95, p99, maximum, hitch count, draw calls, rendered objects/primitives, object/resource counts, static memory where supported, camera identity, and exact frame/tick cadence. Unit-scale results additionally record target/actual/peak unit count and renderer pool hits, misses, expansions, active count, peak active count, and prewarm evidence.

Cold first-use cost is a separate diagnostic. Baseline measurements prewarm their declared assets before the warmup window.

## Baseline eligibility

Catalog membership means `baseline_candidate`, not `baseline_eligible`. Eligibility is false by default and is computed at runtime. Approval requires all of the following:

- debug harness invocation with no release/public entry point;
- clean worktree and exact catalog/fixture/result-schema versions;
- `MINIMAL` collection and three completed repetitions;
- exact setup counts and fixture-specific invariants;
- scenario, determinism, isolation, backend-isolation, and compatibility checks pass;
- the selected profile is explicitly eligible for that fixture;
- renderer, display server, viewport, stretch, VSync, camera, cadence, and environment match the baseline key;
- no unsupported or missing required metric;
- all configured performance gates pass.

The baseline key includes both fixture and measurement profile. Canonical-simulation evidence is never compared with windowed-presentation evidence. `OFF`, Phase 0, existing `render_windowed`, dirty-tree, and design-only results remain ineligible.

Phase 1 requires result schema v3 because it adds synthetic content identity, catalog identity, measurement profiles, camera/cadence compatibility, and fixture-registry evidence. Schema v2 evidence remains readable historical evidence but is not comparison-compatible.

## Implementation gates

### P1-A — Registry and fail-closed validation

Status: `COMPLETE`

Implement the catalog loader and schema-v3 result fields. Validate unique IDs, supported profiles, content identity, map hash, target counts, capacity ceilings, durations, and baseline defaults. The initial catalog loads only as design-approved; no fixture runs yet.

Pass evidence:

- positive catalog smoke test;
- malformed/duplicate/unknown-profile/map-hash/capacity-negative tests;
- every catalog entry reports `baseline_eligible=false` before runtime approval.

Stop if a registry error can degrade to a warning or fall back to an ad hoc fixture.

Implemented evidence:

- `PerfFixtureCatalog` validates the catalog before runner fixture selection or scene setup;
- missing/malformed JSON, duplicate IDs, unknown profiles, map-hash drift, target-capacity overflow, and attempted baseline preapproval are refused;
- the selected production map is checked through `MapLoader`, with authored identity and normalized counts;
- schema v3/fingerprint v2 carries catalog, measurement-profile, content, and environment-compatibility identity;
- a missing-catalog runner probe exits 2 with zero selected scenarios;
- the P1-A smoke suite, Phase 0 Gates A–F, a schema-v3 runner probe, and the three-repetition Phase 0 integrity suite pass.

### P1-B — Deterministic windowed execution

Add the manual frame/tick adapter without changing production gameplay defaults. Capture camera and cadence identity and preserve the existing investigative mode.

Pass evidence:

- exact frame and tick counts across three repetitions;
- identical final-state hashes when simulation is active;
- headless refusal;
- camera-settle and camera-hash checks;
- interrupted-run cleanup and Phase 0 isolation suites still pass.

Stop if elapsed wall time changes the number or ordering of simulation ticks.

### P1-C — Empty and static fixtures

Implement `EMPTY_ARENA_V1` and `STATIC_BATTLEFIELD_V1`. Keep synthetic and production-map content identities distinct.

Pass evidence:

- exact runtime counts and renderer visibility;
- production map hash and loader/applier evidence for static battlefield;
- no MapLoader claim for empty arena;
- stable camera/config hashes over three repetitions.

Stop if the empty fixture requires weakening production map validation.

### P1-D — Normal match

Run the command pilot, freeze the schedule, then implement canonical-headless and deterministic-windowed profiles.

Pass evidence:

- exact accepted command evidence;
- three identical final-state hashes per profile;
- 20 warmup and 100 measured canonical ticks;
- 60 warmup and 300 measured presentation frames;
- no automatic bots or wall-time-derived commands.

Stop if deterministic selector resolution changes between repetitions or the schedule cannot be expressed through production command paths.

### P1-E — Static unit-scale matrix

Implement exact 50/100/200/400 unit fixtures using accepted lanes and public unit spawning. Measure while paused.

Pass evidence:

- target equals actual throughout every measurement window;
- no capacity bypass;
- every injection references an accepted, fully built production lane;
- no unexpected renderer pool expansion;
- stable injection and configuration hashes;
- monotonic workload sanity across the matrix, reported as diagnostic rather than a fabricated pass guarantee.

Stop if lane construction times out, an injection is rejected, or the target cannot be represented by both the production active-unit limit and the renderer pool.

### P1-F — Candidate baselines and Phase 1 exit

Run all implemented profiles from a clean worktree on a recorded environment. Produce comparison-compatible candidate artifacts, run regression gates, and review diagnostics before explicitly approving baselines.

Pass evidence:

- complete A–E test suite plus Phase 0 regression suite;
- three-repetition candidate package for each approved profile;
- no ineligible result is promoted;
- baseline manifests contain fixture, profile, content, configuration, environment, camera, and cadence identities.

Phase 1 exits only after approved clean-tree baselines exist. Completing P1-A alone does not approve or execute a product fixture.

## Explicit deferrals

- moving-unit scale profile;
- hive-upgrade storm and super-swarm chain;
- 3-player and 4-player fixtures;
- multi-map or multi-stage async fixtures;
- device thermals, energy, and external GPU profiling;
- broad UI, lifecycle soak, networking, and public-mode load fixtures.

These require later, separately approved fixture and test work.

## Current sprint position

Phase 0: complete with documented limitations.

Phase 1 design: complete. The catalog, production map hash, fixture matrix, and current Phase 0 validator contract have been checked against the repository.

Phase 1 implementation: P1-A complete. The next executable increment is P1-B, deterministic windowed execution.
