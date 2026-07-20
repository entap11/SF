# Performance Harness Gate F Migration

Gate F establishes a single supported regression pipeline while preserving specialized forensic tools and all historical result files. It does not claim that differently shaped fixtures are statistically equivalent.

## Ownership

| Purpose | Supported entry point | Status |
| --- | --- | --- |
| Deterministic regression run | `scripts/tests/perf_benchmark_suite.gd` | Canonical |
| Offline current-schema comparison | `scripts/tools/perf_compare.gd` | Canonical comparator client; schema v3 after P1-A |
| Periodic hitch isolation | `scripts/tests/rhythmic_lag_isolation.gd` | Preserved forensic tool |
| Long periodic pressure/soak | `scripts/dev/soak_perf_runner.gd` | Preserved forensic tool |
| Old regression run | `tools/perf_benchmark_suite.gd` | Deprecated refusal shim |
| Old offline comparison | `tools/perf_compare.gd` | Deprecated refusal shim |

## Capability audit

| Capability | Canonical runner | Old runner | Preserved location or decision |
| --- | --- | --- | --- |
| Debug-only explicit activation | Required | No | Canonical only |
| Gate validation | Required, fail closed | Built-in fallback | Canonical only |
| Deterministic map, seed, fixture, and commands | Required and hashed | Partial | Canonical only |
| Production canonical simulation tick | Yes | Arena process loop | Canonical only |
| Windowed presentation measurement | Yes | Yes | Canonical `render_windowed` |
| State/backend isolation | Asserted and restored | No | Canonical only |
| Bounded OFF/MINIMAL/FULL collection | Yes | Unbounded frames/hitches | Canonical only |
| Schema, environment identity, fingerprint | Schema v3 (schema v2 at Phase 0 exit) | Unversioned | Canonical only |
| Median repetition comparison | Shared fail-closed comparator | No | Canonical only |
| Periodic attack-pair reapplication | Fixed schedules instead | Yes | Rhythmic-lag and soak tools |
| Detailed runtime telemetry snapshots | Bounded contract evidence | Yes | Rhythmic-lag tool for forensics |

The old runner's periodic pressure and runtime snapshots are useful for diagnosis, but they are not deterministic baseline evidence. The richer rhythmic-lag isolation tool covers short frame/hitch investigations, and the soak runner covers sustained periodic lane pressure. They stay separate so their investigative semantics are not mislabeled as canonical regression fixtures.

## Invocation mapping

All commands run from the project root.

| Retired intent | Supported command or replacement | Parity note |
| --- | --- | --- |
| Old `quick` headless run | `godot --headless --path . --script res://scripts/tests/perf_benchmark_suite.gd -- --sf-perf-harness --suite=quick --mode=canonical_sim_headless` | Deterministic replacement, not a rewrite of the old fixture |
| Old `quick` windowed run | `godot --path . --script res://scripts/tests/perf_benchmark_suite.gd -- --sf-perf-harness --suite=quick --mode=render_windowed` | Supported presentation path |
| Old `sprint_layers` run | Canonical `--suite=layers`; use `--scenario=stress_30s` for the stress target | Fixture definitions differ; compare only compatible fingerprints |
| Old `arena_headless` frame forensics | `scripts/tests/rhythmic_lag_isolation.gd` | Forensic replacement, not baseline evidence |
| Old long periodic pair pressure | `scripts/dev/soak_perf_runner.gd` | Preserves sustained pressure behavior |
| Old offline comparison | `godot --headless --path . --script res://scripts/tools/perf_compare.gd -- res://baseline.json res://current.json` | Requires valid compatible current-schema reports |

Approximate scenario lineage is informational only: old `boot_5s` maps to canonical `sim_bootstrap_5s`, old `duel_10s` maps to canonical `arena_lane_unit_10s`, and old `stress_30s` maps to canonical `stress_30s`. Old `pressure_20s` has no one-to-one canonical fixture; use the layer suite or a forensic runner according to the question being investigated.

## Evidence and deprecation policy

- Legacy unversioned results remain historical forensic artifacts and are incompatible with current-schema comparisons.
- Schema v1 Gate D and schema v2 Phase 0 results remain historical and are incompatible with schema v3 by design.
- No migration command rewrites, upgrades, moves, or deletes historical output.
- The old runner exits with code 2 before map/Arena setup and before selecting an output path.
- The old comparator exits with code 2 before loading or comparing reports.
- The canonical offline comparator returns 0 for PASS, 1 for WARN, and 2 for FAIL, incompatible input, invalid gates, or unreadable input.

## Sprint disposition

Gate F completes the six planned Phase 0 harness gates. The complete exit evidence and formal recommendation are in [swarmfront_performance_harness_v1.md](swarmfront_performance_harness_v1.md). This establishes trustworthy mechanics, not an approved product baseline: the current development worktree is dirty, Phase 0 fixtures are explicitly baseline-ineligible, and windowed timing still requires clean controlled runs before performance budgets can be approved.
