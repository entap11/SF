# Swarmfront Performance Harness Phase 1 Exit

Status: `PHASE 1 COMPLETE — APPROVED BASELINES`

Phase 1 is complete for the approved catalog fixture matrix. The baseline package was generated from clean source commit `521b1b5` on branch `codex/perf-harness-sprint`, validated through schema v3 and the shared comparator, and explicitly approved by the Phase 1 packager.

## Approved scope

- `EMPTY_ARENA_V1`: static deterministic windowed presentation;
- `STATIC_BATTLEFIELD_V1`: static deterministic windowed presentation;
- `NORMAL_MATCH_V1`: canonical headless simulation and deterministic windowed presentation;
- `UNIT_SCALE_050_V1`, `100`, `200`, and `400`: static deterministic windowed presentation with exact unit invariants.

Every profile uses three repetitions and `MINIMAL` bounded collection. Windowed profiles use 60 warmup plus 300 measured frames at 30 FPS. The normal-match profiles use 20 warmup plus 100 measured 10 Hz simulation ticks. Automatic bots and wall-time-derived commands are disabled.

## Baseline environment

| Identity | Approved value |
| --- | --- |
| Godot | 4.2.2 stable official, debug build |
| OS / architecture | macOS / arm64, 10 logical processors |
| Windowed adapter | Apple M2 Pro, Forward+, Vulkan driver |
| Windowed viewport | 1080 × 1920, viewport stretch, keep-width |
| Pacing | 30 FPS benchmark target, VSync enabled, physics 60 Hz |
| Fixture catalog | schema v1, 7 implemented fixtures, hash `03d9fb566b3e88d20418c8fb34ddcef8c3f7a1e0ffc525273ee3bd078c696bb7` |

Comparisons remain fail-closed across fixture, content, configuration, environment, camera, cadence, renderer, viewport, collection, and pacing identities. A different identity requires a new compatible baseline; it must not be compared by discarding fingerprint mismatches.

## Approved evidence

| Fixture/profile | Repetitions | Mean average ms | Highest p99 ms | Highest max ms | Hitches |
| --- | ---: | ---: | ---: | ---: | ---: |
| Empty arena / static windowed | 3 | 33.222 | 35.193 | 35.306 | 0 |
| Static battlefield / static windowed | 3 | 33.217 | 35.208 | 35.324 | 0 |
| Normal match / canonical simulation | 3 | 0.583 tick | 1.645 tick | 1.657 tick | 0 |
| Normal match / deterministic windowed | 3 | 33.233 | 35.451 | 35.612 | 0 |
| Unit scale 50 / static windowed | 3 | 33.311 | 35.155 | 35.345 | 0 |
| Unit scale 100 / static windowed | 3 | 33.315 | 35.177 | 35.332 | 0 |
| Unit scale 200 / static windowed | 3 | 33.318 | 35.188 | 35.292 | 0 |
| Unit scale 400 / static windowed | 3 | 33.317 | 35.055 | 35.324 | 0 |

The exact unit target held from measurement start through measurement end in every scale repetition. Every injection used a fully built accepted production lane and public `UnitSystem.spawn_unit` with no capacity bypass. The 400-unit case used all 400 production pool objects with zero pool misses and zero expansion.

Active pooled-object workload was exactly monotonic at 50/100/200/400. Mean frame time was effectively pinned to the 30 FPS pacing target and dipped by about 0.001 ms from 200 to 400. That diagnostic is explicitly non-gating and is not presented as proof that rendering cost cannot grow.

## Package

The approved manifest is [manifest.json](../data/perf/baselines/phase1/manifest.json). It records the clean source commit, catalog identity, report hashes, and per-repetition fixture/profile/content/configuration/environment/camera/cadence identities.

| Report | Scope |
| --- | --- |
| `static_fixtures_windowed.json` | Empty arena and static battlefield |
| `normal_match_canonical.json` | Canonical normal match |
| `normal_match_windowed.json` | Deterministic windowed normal match |
| `unit_scale_windowed.json` | Exact 50/100/200/400 static unit matrix |

All four packaged reports self-compare as compatible `PASS` through `scripts/tools/perf_compare.gd`, and baseline approval remains `ELIGIBLE`.

## Exit verification

- Phase 0 focused Gates A–F: all pass;
- Phase 1 focused Gates P1-A–P1-F: all pass;
- Phase 0 canonical integrity: completed, integrity/determinism/isolation/backend PASS, 3/3 scenarios pass;
- Phase 0 sentinel–mutator–sentinel isolation: completed, all isolation hashes and fixture cleanup pass;
- Phase 0 collector calibration: completed, OFF/MINIMAL/FULL behavior and nine-run calibration pass;
- packaged baseline self-comparisons: 4/4 compatible PASS and ELIGIBLE.

Checkpoint history on `codex/perf-harness-sprint`:

- `186201e` — P1-A foundation;
- `ddc6dce` — P1-B deterministic windowed execution;
- `aebb7f2` — P1-C static fixtures;
- `55d741e` — P1-D normal-match profiles;
- `cfdb603` — P1-E static unit-scale matrix;
- `521b1b5` — P1-F clean-tree promotion gate and packager.

## Governance and limitations

- No gameplay rule or production feature default was changed for the harness.
- Baselines are approved only for their exact fingerprints and this controlled debug environment; they are not release-device, thermal, energy, or external GPU baselines.
- Static unit-scale fixtures pause simulation. A moving-unit scale profile remains deferred.
- The engine render-object monitor reported zero on this macOS path, so exact production pool counts provide the workload sanity evidence; external GPU attribution remains unavailable.
- 3-player, 4-player, multi-map, and multi-stage async fixtures remain deferred until their production behavior has dedicated tests.
- Hive-upgrade storm, super-swarm chain, broad UI/lifecycle soak, networking, and device profiling remain outside Phase 1.

## Final recommendation

`PHASE 1 COMPLETE — APPROVED BASELINES`

The sub-branch is ready to fold into the target branch after review. Preserve the phase commits during review; once accepted, a merge or squash policy can be chosen without losing the pushed rollback points.
