# SF Perf Layer Cost Results

Date: 2026-06-29
Harness: `res://scripts/tests/rhythmic_lag_isolation.gd`
Map: `res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json`
Window: 30 seconds per variant
Hitch threshold: 24 ms
Mode: Godot headless

## Reports

- `debug_reports/rhythm_30s_baseline.json`
- `debug_reports/rhythm_30s_runtime_layers.json`
- `debug_reports/rhythm_30s_sim_layers.json`
- `debug_reports/rhythm_30s_presentation_layers.json`
- `debug_reports/rhythm_30s_floor_budget.json`
- `debug_reports/rhythm_30s_cost_centers.json`
- `debug_reports/rhythm_30s_cost_centers_deep.json`
- `debug_reports/rhythm_30s_cost_centers_cached.json`
- `debug_reports/rhythm_30s_cost_centers_log_emission_fixed.json`
- `debug_reports/rhythm_30s_cost_centers_intent_overhead.json`
- `debug_reports/rhythm_30s_cost_centers_telemetry_optimized.json`
- `debug_reports/rhythm_30s_cost_centers_repeat_snapshot_scope.json`
- `debug_reports/rhythm_30s_cost_centers_telemetry_deep.json`
- `debug_reports/rhythm_30s_cost_centers_source_metrics_scoped.json`
- `debug_reports/rhythm_30s_cost_centers_telemetry_coalesced.json`

Each JSON report includes per-frame samples, worst frames, average, p95, p99, max, hitch count, and the enabled flag set for every variant. Matching `.log` files contain the emitted `RHYTHMIC_HITCH` lines.

## Baseline

| Variant | Hitches | P99 ms | Max ms | Delta vs full |
| --- | ---: | ---: | ---: | ---: |
| A. full game | 116 | 29.984 | 34.129 | 0 |
| B. sim-only visual mode | 114 | 27.554 | 43.919 | -2 |
| C. sim-only + bots off | 113 | 28.226 | 33.194 | -3 |
| D. presentation only, sim paused | 0 | 7.734 | 7.917 | -116 |

Decision: the rhythmic hitch is not primarily presentation, bots, audio, debug HUD, or floating visual clutter. It only disappears when authoritative sim advancement is paused.

## Runtime Toggles

| Variant | Hitches | P99 ms | Max ms | Delta vs full |
| --- | ---: | ---: | ---: | ---: |
| A. full game | 124 | 32.870 | 39.105 | 0 |
| E. full game, bots off | 119 | 32.678 | 40.360 | -5 |
| F. full game, hash/network off | 122 | 32.845 | 37.439 | -2 |
| G. full game, audio off | 121 | 30.588 | 79.878 | -3 |
| H. full game, debug/HUD logging off | 126 | 33.081 | 38.892 | +2 |

Decision: no runtime wrapper toggle materially removes the cadence. Bots and network/hash checks are not the root cause for this scenario.

## Sim Layers

| Variant | Hitches | P99 ms | Max ms | Delta vs full |
| --- | ---: | ---: | ---: | ---: |
| A. full game | 123 | 33.501 | 38.046 | 0 |
| B. sim-only visual mode | 113 | 32.096 | 42.187 | -10 |
| I. sim-only, lane flow off | 0 | 18.661 | 20.987 | -123 |
| J. sim-only, edge cache off | 114 | 30.959 | 37.768 | -9 |
| K. sim-only, units/swarms off | 0 | 17.768 | 20.239 | -123 |
| L. sim-only, towers/control off | 113 | 31.504 | 37.209 | -10 |
| M. sim-only, barracks off | 114 | 31.887 | 41.318 | -9 |

Decision: the rhythmic hitch tracks lane flow and units/swarms. Disabling either removes the hitch completely in this harness. Edge cache, towers/control, and barracks are not sufficient to remove it.

Working hypothesis: unit/swarm movement is feeding periodic lane-flow work. The cadence seen in the logs is around every 30 frames / 5 sim ticks in the deterministic scenario.

Next isolation step: split lane flow into smaller flags, especially lane pressure update, runtime lane creation, lane occupancy/assignment, and any command cadence that fires every 5 ticks. Keep this as instrumentation first; do not optimize or change gameplay behavior until the specific lane-flow substep is identified.

## Cost Centers

| Variant | Hitches | P99 ms | Max ms |
| --- | ---: | ---: | ---: |
| W. full game, cost centers | 124 | 35.471 | 40.428 |
| X. sim-only, cost centers | 114 | 30.382 | 37.381 |

### Command Issue

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| command_issue_total, full | 2426.965 | 132 | 18.386 | 24.478 |
| command_gather_candidate_pairs, full | 1387.371 | 132 | 10.510 | 12.142 |
| command_apply_lane_intent, full | 813.748 | 264 | 3.082 | 12.762 |
| command_issue_swarm, full | 222.546 | 132 | 1.686 | 2.446 |
| command_issue_total, sim-only | 2016.924 | 135 | 14.940 | 19.706 |
| command_gather_candidate_pairs, sim-only | 1421.130 | 135 | 10.527 | 12.459 |
| command_apply_lane_intent, sim-only | 593.251 | 270 | 2.197 | 7.935 |

### Lane Flow

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| calculate_pressure, full | 244.340 | 12027 | 0.020 | 0.834 |
| notify_units_spawn_packet, full | 167.796 | 461 | 0.364 | 0.725 |
| lane_setup, full | 103.967 | 12027 | 0.009 | 0.078 |
| calculate_pressure, sim-only | 356.452 | 12109 | 0.029 | 1.014 |
| notify_units_spawn_packet, sim-only | 261.941 | 649 | 0.404 | 0.760 |
| lane_setup, sim-only | 103.876 | 12109 | 0.009 | 0.068 |

### Unit Flow

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| unit_tick_total, full | 713.940 | 663 | 1.077 | 3.350 |
| unit_update_positions, full | 311.392 | 663 | 0.470 | 0.809 |
| unit_spawn_total, full | 146.405 | 461 | 0.318 | 0.645 |
| unit_tick_total, sim-only | 882.663 | 675 | 1.308 | 2.865 |
| unit_update_positions, sim-only | 430.020 | 675 | 0.637 | 1.055 |
| unit_spawn_total, sim-only | 231.398 | 656 | 0.353 | 0.661 |

Decision: the expensive rhythmic cost center is not the internal lane-flow update. The largest lane-flow tick observed was about 4.1 ms, and the largest unit-flow tick observed was about 2.2 ms. The recurring command issue path is the frame consumer: `command_issue_total` averages 14.9-18.4 ms on command ticks and peaks at 19.7-24.5 ms.

Specific culprit candidates:

- `command_gather_candidate_pairs` costs about 10.5 ms every command tick.
- `command_apply_lane_intent` adds 2.2-3.1 ms on average and can spike to 12.8 ms.
- `command_issue_swarm` is secondary at about 1.7 ms in full mode.

Next decision from this pass was to keep lane-flow/unit update behavior unchanged and split `command_gather_candidate_pairs` plus `OpsState.apply_lane_intent` into their own cost centers. That follow-up pass is captured below.

## Deep Command Split

Report: `debug_reports/rhythm_30s_cost_centers_deep.json`

| Variant | Hitches | P99 ms | Max ms |
| --- | ---: | ---: | ---: |
| W. full game, cost centers | 127 | 36.908 | 46.808 |
| X. sim-only, cost centers | 114 | 35.425 | 42.065 |

### Candidate Gathering

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| command_gather_candidate_pairs, full | 1505.421 | 131 | 11.492 | 13.363 |
| candidate_state_can_connect, full | 1340.453 | 14168 | 0.095 | 0.347 |
| candidate_sort_pairs, full | 13.341 | 131 | 0.102 | 0.158 |
| candidate_destination_filter, full | 12.385 | 15456 | 0.001 | 0.047 |
| command_gather_candidate_pairs, sim-only | 1520.268 | 132 | 11.517 | 13.478 |
| candidate_state_can_connect, sim-only | 1353.695 | 14267 | 0.095 | 0.360 |
| candidate_sort_pairs, sim-only | 13.267 | 132 | 0.101 | 0.158 |
| candidate_destination_filter, sim-only | 12.452 | 15564 | 0.001 | 0.078 |

`candidate_source_enumeration` is an inclusive outer-loop timer, so it largely contains the nested `candidate_state_can_connect` cost. The meaningful exclusive cost is `candidate_state_can_connect`: about 10.2 ms per command tick in both full and sim-only variants.

Decision: the primary rhythmic hitch source is deterministic command candidate gathering repeatedly calling `GameState.can_connect()` across the hive pair matrix every 5 ticks. This is harness command selection work, not lane-flow update work.

### Apply Intent

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| command_apply_lane_intent, full | 878.375 | 262 | 3.353 | 8.049 |
| intent_route_validation, full | 280.782 | 181 | 1.551 | 5.540 |
| intent_runtime_lane_total, full | 262.497 | 96 | 2.734 | 5.588 |
| intent_telemetry_and_action_events, full | 187.465 | 100 | 1.875 | 4.648 |
| intent_pre_apply_snapshots, full | 102.112 | 100 | 1.021 | 1.264 |
| command_apply_lane_intent, sim-only | 895.633 | 264 | 3.393 | 7.785 |
| intent_runtime_lane_total, sim-only | 274.894 | 99 | 2.777 | 5.643 |
| intent_telemetry_and_action_events, sim-only | 240.309 | 119 | 2.019 | 4.650 |
| intent_route_validation, sim-only | 218.743 | 184 | 1.189 | 5.442 |
| intent_pre_apply_snapshots, sim-only | 115.611 | 119 | 0.972 | 1.472 |

Secondary costs are inside `OpsState.apply_lane_intent()`: route validation, runtime lane handling, telemetry/action events, and pre-apply snapshots. Runtime lane creation is not dominated by `rebuild_indexes()` in this run; `intent_ensure_runtime_lane_rebuild_indexes` is only about 1.2-1.6 ms total across the whole 30 seconds.

Decision: optimize or cache command candidate selection first. Then consider reducing `apply_lane_intent()` overhead by avoiding duplicate route validation and pre-apply snapshots when the command is idempotent or no state change is possible.

Recommended next change: for deterministic perf harness commands, precompute valid attack pairs once per scenario or refresh them only when map/lane topology changes. If this command picker mirrors real bot/input logic, introduce a `GameState` connection cache keyed by hive-pair/topology version so `can_connect()` is not recomputed for every candidate every 5 ticks.

## Command Candidate Cache Pass

Change: the rhythmic-lag harness now precomputes deterministic attack candidate pairs once per variant and reuses that list on command ticks. This is harness-local and can be disabled per variant with `disable_command_cache = true`.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_cached.json`
Full report: `debug_reports/rhythm_30s_cost_centers_cached.json`

| Variant | Hitches | P99 ms | Max ms | Cache hits | Fallback gathers |
| --- | ---: | ---: | ---: | ---: | ---: |
| W. full game, cost centers | 22 | 22.434 | 27.664 | 140 | 0 |
| X. sim-only, cost centers | 4 | 20.760 | 29.886 | 141 | 0 |

### Command Issue After Cache

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| command_gather_candidate_pairs, full | 0.765 | 140 | 0.005 | 0.007 |
| candidate_state_can_connect, full | 3.297 | 44 | 0.075 | 0.102 |
| command_issue_total, full | 986.000 | 140 | 7.043 | 10.673 |
| command_gather_candidate_pairs, sim-only | 0.723 | 141 | 0.005 | 0.027 |
| candidate_state_can_connect, sim-only | 3.396 | 44 | 0.077 | 0.105 |
| command_issue_total, sim-only | 784.739 | 141 | 5.566 | 8.277 |

Decision: the candidate-pair scan was a harness-induced hitch amplifier. Caching removes roughly 10-11 ms from every scripted command tick and reduces hitches from 127 to 22 in full mode and from 114 to 4 in sim-only mode compared with the deep split run.

Remaining decision: after removing candidate gathering, the main command-tick cost is `OpsState.apply_lane_intent()`, especially runtime lane handling, telemetry/action events, and pre-apply snapshots. Full mode also showed hitches near `RUNTIME_LANE_CREATED` and `BOT_INTENT` warning output, so the next reversible pass should isolate debug/warning emission from intent application before changing gameplay logic.

## Log Emission Isolation

Change: added a harness-only `debug_warning_emission` flag so log output can be toggled independently of debug HUD/UI visibility. The expanded cost-center group now includes:

- `Y_full_cost_centers_logs_off`: full game with `debug_warning_emission = false`
- `Z_sim_only_cost_centers_logs_on`: sim-only visuals with `debug_warning_emission = true`

Smoke report: `debug_reports/rhythm_smoke_cost_centers_log_emission_fixed.json`
Full report: `debug_reports/rhythm_30s_cost_centers_log_emission_fixed.json`

| Variant | Log emission | Hitches | P99 ms | Max ms |
| --- | --- | ---: | ---: | ---: |
| W. full game, cost centers | on | 38 | 23.753 | 34.513 |
| X. sim-only, cost centers | off | 8 | 22.189 | 27.845 |
| Y. full game, cost centers, log emission off | off | 28 | 23.525 | 28.991 |
| Z. sim-only, cost centers, log emission on | on | 7 | 21.278 | 34.460 |

### Intent Costs With Log Toggle

| Stage | Variant | Total ms | Calls | Avg ms | Max ms |
| --- | --- | ---: | ---: | ---: | ---: |
| intent_runtime_lane_total | W full logs on | 408.260 | 136 | 3.002 | 6.677 |
| intent_telemetry_and_action_events | W full logs on | 238.764 | 143 | 1.670 | 6.086 |
| intent_pre_apply_snapshots | W full logs on | 154.862 | 143 | 1.083 | 1.614 |
| intent_ensure_runtime_lane_log | W full logs on | 0.536 | 7 | 0.077 | 0.096 |
| intent_runtime_lane_total | Y full logs off | 448.019 | 141 | 3.177 | 7.947 |
| intent_telemetry_and_action_events | Y full logs off | 251.506 | 135 | 1.863 | 6.147 |
| intent_pre_apply_snapshots | Y full logs off | 148.843 | 135 | 1.103 | 1.671 |
| intent_ensure_runtime_lane_log | Y full logs off | 0.031 | 4 | 0.008 | 0.008 |

Decision: warning/debug emission is not the dominant remaining hitch source. Disabling log emission in full mode reduced hitch count from 38 to 28 in this run, but p99 stayed effectively the same and command/intent costs remained high. The direct runtime-lane log stage was only 0.536 ms total with logs on and 0.031 ms total with logs off.

Next decision: keep logs quiet for perf tests, but do not spend the next optimization pass on `SFLog`. The remaining expensive path is still `OpsState.apply_lane_intent()`, especially runtime lane handling, telemetry/action events, and pre-apply snapshots. The next reversible test should split or gate telemetry/action-event recording and snapshot creation, while leaving the authoritative lane mutation unchanged.

## Intent Overhead Isolation

Change: added `OpsState.set_intent_cost_switches()` with defaults enabled, plus harness flags for:

- `intent_telemetry`
- `intent_action_events`
- `intent_pre_apply_snapshots`

These switches are diagnostic. Normal gameplay defaults remain enabled, and the harness resets the switches after each variant.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_intent_overhead.json`
Full report: `debug_reports/rhythm_30s_cost_centers_intent_overhead.json`

| Variant | Disabled cost center | Hitches | P99 ms | Max ms | command_issue avg ms |
| --- | --- | ---: | ---: | ---: | ---: |
| Y. full game, log emission off | none, control | 3 | 19.862 | 29.470 | 3.971 |
| AA. full game, intent telemetry off | telemetry | 1 | 16.872 | 33.408 | 1.612 |
| AB. full game, intent action events off | action events | 7 | 19.949 | 28.007 | 5.409 |
| AC. full game, intent snapshots off | source metrics/full restore snapshot | 15 | 20.597 | 32.597 | 5.865 |
| AD. full game, intent overhead off | telemetry + action events + snapshots | 0 | 15.718 | 20.132 | 0.702 |

### Intent Stages

| Stage | Control total ms | Telemetry off total ms | Combined off total ms |
| --- | ---: | ---: | ---: |
| intent_apply_total | 448.986 | 227.905 | 88.477 |
| intent_runtime_lane_total | 156.433 | 6.552 | 7.218 |
| intent_pre_apply_snapshots | 120.158 | 153.256 | 1.739 |
| intent_telemetry_and_action_events | 56.770 | 1.489 | 1.843 |
| intent_swarm_total | 40.937 | 6.490 | 7.792 |

Decision: intent telemetry is the largest single lever. Turning telemetry off cut average scripted command cost from 3.971 ms to 1.612 ms and reduced hitches from 3 to 1 in this run. Turning action events off alone did not help, which means match action-event recording is not the main cost inside the combined telemetry/action stage. Turning snapshots off alone also did not help because telemetry/runtime-lane work still dominated, but the combined overhead-off variant removed hitches entirely and dropped command issue average to 0.702 ms.

Next decision: do not ship the broad `AD` switch as a gameplay optimization; it intentionally disables analytics/debug safeguards. The production-safe path is to make intent telemetry cheaper and/or buffered: avoid per-intent execution metric rebuilds, cache static telemetry context per match, batch bot telemetry writes, and keep pre-apply snapshots only for the implicit-replacement validation path that actually needs restore data.

## Telemetry Optimization Pass

Change: kept telemetry enabled by default, but made the safe parts cheaper:

- Cached static intent telemetry context per map/state.
- Cached per-seat actor identity labels/styles/tiers.
- Invalidated telemetry caches on map/state reset and bot profile changes.
- Batched bot telemetry JSONL writes instead of opening/appending/closing the file per intent.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_telemetry_optimized.json`
Full report: `debug_reports/rhythm_30s_cost_centers_telemetry_optimized.json`

| Variant | Hitches | P99 ms | Max ms | command_issue avg ms | intent_apply total ms | telemetry/actions total ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Y. control, logs off, before opt | 3 | 19.862 | 29.470 | 3.971 | 448.986 | 56.770 |
| Y. control, logs off, after opt | 1 | 18.897 | 25.882 | 4.569 | 520.693 | 50.059 |
| AA. telemetry off, before opt | 1 | 16.872 | 33.408 | 1.612 | 227.905 | 1.489 |
| AA. telemetry off, after opt | 0 | 17.082 | 20.416 | 1.859 | 261.962 | 1.796 |
| AD. overhead off, after opt | 0 | 15.954 | 19.838 | 0.699 | 88.041 | 1.850 |

Decision: this is a safe cleanup but not the whole fix. It trims the telemetry/action stage slightly in the control run, and the telemetry-off diagnostic still shows telemetry is a major lever, but full telemetry-on cost is now dominated by `intent_pre_apply_snapshots` and `intent_runtime_lane_total`. Bot telemetry file batching is still worth keeping because it removes per-intent file I/O risk outside the profiler, but the remaining frame cost is mostly CPU work before telemetry write-out.

Next decision: focus on pre-apply snapshot scope and source execution metrics. The safest next production change is to avoid collecting full execution metrics and full lane restore snapshots for idempotent repeat intents where no lane direction can be lost, while preserving the implicit-replacement validation path.

## Repeat Intent Snapshot Scope Pass

Change: repeat attack/feed commands on an already-active route now skip the expensive pre-apply source execution metrics and full lane-direction restore snapshot. New lane opens, lane closes, and implicit-replacement validation still keep the validation/restore path. The telemetry recorder also accepts an explicit `include_source_exec_metrics` flag so repeat intents do not immediately recompute the metrics after the pre-apply skip.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_repeat_snapshot_scope.json`
Full report: `debug_reports/rhythm_30s_cost_centers_repeat_snapshot_scope.json`

| Variant | Hitches | P99 ms | Max ms | command_issue avg ms | intent_apply total ms | pre-apply snapshots total ms | telemetry/actions total ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Y. logs off, before scope pass | 1 | 18.897 | 25.882 | 4.569 | 520.693 | 166.514 | 50.059 |
| Y. logs off, after scope pass | 4 | 18.141 | 27.994 | 3.451 | 358.940 | 17.950 | 47.031 |
| AA. telemetry off, before scope pass | 0 | 17.082 | 20.416 | 1.859 | 261.962 | 179.564 | 1.796 |
| AA. telemetry off, after scope pass | 0 | 14.540 | 17.597 | 0.423 | 53.977 | 2.006 | 1.251 |
| AD. overhead off, after scope pass | 0 | 15.458 | 21.384 | 0.624 | 78.049 | 2.492 | 1.512 |

### Pre-Apply Breakdown

| Stage | Y total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| intent_pre_apply_snapshots | 17.950 | 149 | 0.120 | 2.324 |
| intent_pre_apply_source_metrics | 15.019 | 149 | 0.101 | 2.232 |
| intent_pre_apply_restore_snapshot | 0.501 | 149 | 0.003 | 0.060 |
| intent_pre_apply_target_snapshot | 0.197 | 149 | 0.001 | 0.015 |
| intent_pre_apply_repeat_skipped | 0.036 | 136 | 0.000 | 0.003 |

Decision: keep this change. It is narrow, reversible, and preserves the mutation paths that need restore validation. It removes most of the broad pre-apply snapshot cost: the logs-off control dropped from 166.514 ms to 17.950 ms, and the telemetry-off diagnostic dropped from 179.564 ms to 2.006 ms. The remaining hitches do not track restore snapshots anymore; they still track telemetry-enabled variants.

Next decision: the next target is not lane-flow stage logic or full restore snapshots. It is the telemetry/runtime-lane reporting path, especially `intent_runtime_lane_total`, `intent_swarm_telemetry`, and the successful intent telemetry event construction path. `AA_full_intent_telemetry_off` remained clean at 0 hitches with max 17.597 ms, while `Y_full_cost_centers_logs_off` and `AC_full_intent_snapshots_off` still hit 4 and 3 hitches respectively.

## Deep Telemetry Split

Change: split telemetry timing into lower-level stages:

- `_record_intent_telemetry()`: PvP debug event, guard checks, context lookup, source execution metrics, event dictionary construction, bot telemetry store recording, match context construction, and match collector call.
- Successful lane telemetry: log event, intent telemetry recording, and action events.
- Swarm telemetry: intent telemetry recording and action event.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_telemetry_deep.json`
Full report: `debug_reports/rhythm_30s_cost_centers_telemetry_deep.json`

| Variant | Hitches | P99 ms | Max ms | command_issue avg ms | intent_apply total ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Y. logs off, telemetry on | 1 | 17.949 | 24.274 | 3.896 | 408.398 |
| AA. telemetry off | 0 | 16.323 | 18.973 | 0.746 | 95.032 |
| AB. action events off | 1 | 18.065 | 26.447 | 3.943 | 413.928 |
| AC. snapshots off | 2 | 18.322 | 26.180 | 4.025 | 428.864 |
| AD. overhead off | 1 | 17.035 | 28.679 | 0.704 | 90.931 |

### Telemetry Breakdown, Y Logs Off

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| intent_record_total | 452.498 | 435 | 1.040 | 2.615 |
| intent_record_source_metrics | 306.417 | 435 | 0.704 | 1.733 |
| intent_runtime_lane_total | 225.544 | 143 | 1.577 | 2.662 |
| intent_record_bot_store | 80.793 | 435 | 0.186 | 1.117 |
| intent_telemetry_and_action_events | 64.095 | 149 | 0.430 | 1.420 |
| intent_success_record_intent_telemetry | 61.343 | 149 | 0.412 | 1.401 |
| intent_record_context | 25.852 | 435 | 0.059 | 0.147 |
| intent_swarm_telemetry | 21.823 | 18 | 1.212 | 1.429 |
| intent_swarm_record_intent_telemetry | 21.615 | 18 | 1.201 | 1.416 |
| intent_record_pvp_debug_event | 10.072 | 435 | 0.023 | 0.064 |
| intent_record_event_build | 9.340 | 435 | 0.021 | 0.050 |
| intent_record_match_context_build | 3.926 | 435 | 0.009 | 0.032 |
| intent_record_match_collector | 2.055 | 435 | 0.005 | 0.012 |
| intent_success_log_event | 1.253 | 149 | 0.008 | 0.012 |
| intent_swarm_action_event | 0.104 | 18 | 0.006 | 0.010 |

### Runtime Lane Breakdown, Y Logs Off

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| intent_runtime_lane_total | 225.544 | 143 | 1.577 | 2.662 |
| intent_runtime_lane_budget_check | 1.706 | 143 | 0.012 | 0.019 |
| intent_runtime_lane_ensure | 1.072 | 4 | 0.268 | 0.279 |
| intent_runtime_can_create_can_connect | 0.912 | 8 | 0.114 | 0.126 |
| intent_runtime_lane_can_create | 0.597 | 4 | 0.149 | 0.159 |
| intent_ensure_runtime_lane_can_create | 0.542 | 4 | 0.136 | 0.139 |
| intent_ensure_runtime_lane_rebuild_indexes | 0.277 | 4 | 0.069 | 0.077 |
| intent_ensure_runtime_lane_log | 0.028 | 4 | 0.007 | 0.007 |

Decision: action events are not the culprit. Turning action events off still hitches, and their measured cost is tiny. Runtime lane creation/rebuild/logging is also not the culprit: the actual ensure/rebuild/log stages are below 2 ms total in the 30-second control run. The large `intent_runtime_lane_total` number is mostly nested telemetry from early/runtime-lane intent outcomes.

Next decision: target `intent_record_source_metrics`. It is the largest measured substage by a wide margin: 306.417 ms of the 452.498 ms telemetry total in the logs-off control. The safest production change is to stop collecting full source execution metrics for telemetry events that do not represent a durable lane state change, especially repeat/blocked/runtime-lane command attempts and swarm telemetry. Keep metrics for lane opens, disables, reverses, and explicit replacement-risk cases.

## Source Metrics Scope Pass

Change: source execution metrics are now opt-in for intent telemetry. Lightweight telemetry still records the event, actor, target, reason, lane id, tick, and match context, but it does not rebuild source execution metrics unless the event represents a durable lane state change. Full metrics are kept for lane opens, disables, reverses, and replacement-risk validation. Swarm telemetry and blocked/no-op/runtime attempt telemetry now stay lightweight.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_source_metrics_scoped.json`
Full report: `debug_reports/rhythm_30s_cost_centers_source_metrics_scoped.json`

| Variant | Hitches | P99 ms | Max ms | command_issue avg ms | intent_apply total ms | intent_record total ms | record source metrics total ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| W. full, before scope | 1 | 17.820 | 24.244 | 3.448 | 341.053 | 401.095 | 269.783 |
| W. full, after scope | 0 | 16.956 | 22.344 | 1.899 | 235.849 | 155.775 | 0.238 |
| Y. logs off, before scope | 1 | 17.949 | 24.274 | 3.896 | 408.398 | 452.498 | 306.417 |
| Y. logs off, after scope | 1 | 16.662 | 28.990 | 1.724 | 216.230 | 144.721 | 0.213 |
| AB. action events off, before scope | 1 | 18.065 | 26.447 | 3.943 | 413.928 | 457.300 | 310.418 |
| AB. action events off, after scope | 0 | 16.471 | 22.298 | 1.506 | 185.585 | 127.939 | 0.204 |
| AC. snapshots off, before scope | 2 | 18.322 | 26.180 | 4.025 | 428.864 | 470.164 | 322.530 |
| AC. snapshots off, after scope | 1 | 16.499 | 28.264 | 1.433 | 177.775 | 121.033 | 0.202 |

### Remaining Telemetry Breakdown, Y Logs Off

| Stage | Total ms | Calls | Avg ms | Max ms |
| --- | ---: | ---: | ---: | ---: |
| intent_record_total | 144.721 | 438 | 0.330 | 1.583 |
| intent_record_bot_store | 80.996 | 438 | 0.185 | 1.384 |
| intent_telemetry_and_action_events | 57.092 | 149 | 0.383 | 1.337 |
| intent_runtime_lane_total | 54.984 | 134 | 0.410 | 1.638 |
| intent_success_record_intent_telemetry | 54.547 | 149 | 0.366 | 1.316 |
| intent_record_context | 25.184 | 438 | 0.057 | 0.141 |
| intent_pre_apply_source_metrics | 15.316 | 149 | 0.103 | 1.610 |
| intent_swarm_telemetry | 6.298 | 24 | 0.262 | 0.403 |
| intent_record_event_build | 8.868 | 438 | 0.020 | 0.069 |
| intent_record_source_metrics | 0.213 | 438 | 0.000 | 0.002 |

Decision: keep this change. It removes the largest telemetry substage without dropping telemetry events or changing authoritative sim behavior. The prior dominant `intent_record_source_metrics` cost is effectively gone in the telemetry recorder: 306.417 ms to 0.213 ms in the logs-off control. The command issue average dropped by more than half in the same control run.

Remaining decision: the next measurable telemetry cost is `intent_record_bot_store`, not source metrics. The current store is buffered for file I/O, so the remaining cost is event serialization/summary update/call overhead. If one more pass is needed, coalesce repeated lightweight intent telemetry by `(actor, src, dst, intent, reason)` and flush counts periodically, while preserving full individual events for durable lane state changes.

## Telemetry Coalescing Probe

Change tested: lightweight telemetry events were grouped in memory by match, actor, source, target, intent, result, reason, lane id, and destination owner. Full events with source metrics remained individual. Summary counters still counted every event.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_telemetry_coalesced.json`
Full report: `debug_reports/rhythm_30s_cost_centers_telemetry_coalesced.json`
Rollback smoke after rejecting coalescing: `debug_reports/rhythm_smoke_cost_centers_store_rollback.json`

| Variant | Hitches | P99 ms | Max ms | command_issue avg ms | intent_record total ms | bot_store total ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Y. source metrics scoped | 1 | 16.662 | 28.990 | 1.724 | 144.721 | 80.996 |
| Y. coalescing probe | 1 | 16.946 | 27.027 | 1.935 | 170.153 | 103.869 |
| W. source metrics scoped | 0 | 16.956 | 22.344 | 1.899 | 155.775 | 88.473 |
| W. coalescing probe | 0 | 16.790 | 22.203 | 1.844 | 162.651 | 97.126 |
| AB. source metrics scoped | 0 | 16.471 | 22.298 | 1.506 | 127.939 | 71.678 |
| AB. coalescing probe | 0 | 16.692 | 23.508 | 2.017 | 174.062 | 103.353 |

Decision: do not keep this coalescing implementation. It did not reduce the measured store cost; it increased `intent_record_bot_store` and `intent_record_total` in the important telemetry-on controls. The aggregate dictionary/key maintenance cost outweighed the savings from fewer JSONL rows in this 30-second harness. The code was rolled back to the buffered JSONL store path, with only the `telemetry_detail` / `source_metrics_included` markers kept so downstream consumers can distinguish full vs lightweight events.

Next decision: stop optimizing telemetry store writes until there is a real profile showing file or serialization pressure in windowed/runtime play. The remaining hitch behavior is now small and noisy enough that the next practical step is to clean up the harness lambda-capture error and run a fresh 60-second confirmation pass, rather than adding another speculative telemetry abstraction.

## 60-Second Cost-Center Confirmation

Change: cleaned up the remaining inline `sort_custom(func...)` comparators in the harness-related paths so the headless run no longer emits the lambda-capture error. Replaced them with named comparator methods in `rhythmic_lag_isolation.gd`, `game_state.gd`, `unit_system.gd`, and `ops_state.gd`.

Smoke report: `debug_reports/rhythm_smoke_cost_centers_lambda_all_fixed.json`
Full report: `debug_reports/rhythm_60s_cost_centers_confirm.json`

| Variant | Hitches | P99 ms | Max ms | Decision |
| --- | ---: | ---: | ---: | --- |
| W. full game, cost centers | 15 | 19.853 | 39.237 | Still hitches |
| X. sim-only, cost centers | 6 | 17.770 | 36.344 | Visual stripdown helps but does not remove |
| Y. full game, log emission off | 5 | 18.784 | 38.521 | Warning emission is not the remaining root cause |
| Z. sim-only, log emission on | 8 | 18.434 | 31.406 | Warning emission adds noise, not sole cause |
| AA. full game, intent telemetry off | 3 | 17.405 | 28.369 | Telemetry payload path is not the remaining root cause |
| AB. full game, action events off | 7 | 19.550 | 37.560 | Action events are not the remaining root cause |
| AC. full game, snapshots off | 14 | 20.027 | 36.585 | Snapshot switch is not a remedy |
| AD. full game, intent overhead off | 6 | 18.569 | 34.217 | Residual hitch remains outside intent overhead |

### Remaining Cost Centers

| Variant | Unit tick total | Unit update positions | Unit spawn total | Lane pressure | Spawn packet notify |
| --- | ---: | ---: | ---: | ---: | ---: |
| W. full game | 2909.141 ms | 1454.963 ms | 778.530 ms | 790.825 ms | 602.676 ms |
| X. sim-only | 2597.733 ms | 1313.865 ms | 644.246 ms | 743.466 ms | 571.172 ms |
| AA. intent telemetry off | 2302.716 ms | 1117.896 ms | 583.526 ms | 716.893 ms | 542.844 ms |
| AD. intent overhead off | 2374.756 ms | 1135.226 ms | 582.504 ms | 657.017 ms | 496.609 ms |

Worst-event samples point at active-unit/lane scale rather than telemetry. In the full-game run, worst `unit_tick_total` samples reached 7.705 ms with 128 active units. In the all-intent-overhead-off run, worst `unit_tick_total` samples reached 5.897 ms with 92 active units. Worst lane ticks in that same all-intent-off run were about 3.5-3.9 ms, split mostly between `calculate_pressure` and `notify_units_spawn_packet`, with 18-22 affected lanes and 2-5 spawn-packet calls.

Decision: stop telemetry refactors for this pass. Telemetry functionality was not reduced: events remain recorded, buffered JSONL storage remains active, and full source metrics are still included for durable lane state changes. The retained telemetry change only makes non-durable/repeat/no-op events lightweight and labels each event with `telemetry_detail` plus `source_metrics_included`.

Next decision: if the manual windowed pass confirms the same late-match hiccup, profile or optimize unit flow first, not telemetry. The highest-value targets are `unit_update_positions`, `unit_spawn_total`, `unit_drain_pass_through`, and the lane `calculate_pressure` / `notify_units_spawn_packet` pair under high active-unit counts.

## Presentation Layers

| Variant | Hitches | P99 ms | Max ms | Delta vs full |
| --- | ---: | ---: | ---: | ---: |
| A. full game | 125 | 33.510 | 43.649 | 0 |
| N. full game, fog visuals off | 124 | 33.651 | 39.260 | -1 |
| O. full game, territory visuals off | 126 | 34.152 | 40.986 | +1 |
| P. full game, combat visuals off | 113 | 33.228 | 38.112 | -12 |
| Q. full game, VFX/floating text off | 124 | 33.626 | 51.765 | -1 |
| R. full game, previews/orders off | 118 | 33.748 | 40.289 | -7 |

Decision: presentation systems add some cost, but none removes the cadence. Combat visuals and previews/orders have the largest measurable effect in this pass, but they are secondary to the sim-layer issue.

## Floor Overlay Budget

| Variant | Hitches | P99 ms | Max ms | Delta vs full |
| --- | ---: | ---: | ---: | ---: |
| A. full game | 125 | 34.581 | 38.652 | 0 |
| D. presentation only, sim paused | 0 | 7.735 | 7.882 | -125 |
| S. presentation only, floor off | 0 | 7.747 | 7.947 | -125 |
| T. synthetic floor overlay static | 0 | 7.739 | 7.907 | -125 |
| U. synthetic floor overlay 250ms | 0 | 7.716 | 7.929 | -125 |
| V. synthetic floor overlay every frame | 0 | 11.443 | 12.266 | -125 |

Decision: static and 250 ms dynamic floor overlay probes are effectively free in this headless presentation-only harness. The every-frame 256 px synthetic texture update is still below the 24 ms hitch threshold, but it raises p99 by roughly 3.7 ms over presentation-only.

Recommendation: dynamic floor overlays look viable if updated at a coarse cadence or dirty-region cadence. Avoid every-frame full-surface texture updates until windowed/GPU-visible validation confirms there is enough render-thread headroom.

## Notes

- These runs were headless, so use them for deterministic layer isolation, not final GPU/render cost.
- Godot emitted ObjectDB/resource cleanup warnings at process exit. The runs still exited with code 0 and wrote complete JSON reports.
- The harness emitted one Godot lambda-capture warning during a couple of report transitions, after the affected variant had completed. The summaries were still written; this should be cleaned up before making the harness a CI gate.
