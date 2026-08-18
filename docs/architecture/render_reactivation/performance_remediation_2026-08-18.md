# Godot 4.7.1 Performance Remediation — 2026-08-18

Status: `TARGETED PROBE PASS — FULL GATE PENDING`

This record follows the unchanged-threshold failures documented in
`performance_certification_2026-08-17.md`. It diagnoses and removes one
repeatable simulation-tick contaminant without changing gameplay rules, the
authoritative state boundary, or the 45.0/8.0 ms release limits.

Candidate `sf-4.7.1-b409fc9-20260817.2` remains immutable. These changes are
post-candidate work and require a superseding candidate after the complete
1,800-second gate passes.

## Overnight evidence boundary

The macOS background job completed seven 1,800-second exact-candidate runs and
then began an eighth. Every completed Godot process exited normally, but no run
passed the performance gate. Three runs met the 45 ms process limit at 18.9,
19.6, and 32.0 ms; all seven missed the 8 ms simulation limit, with best-run
maximums between 141.7 and 154.4 ms. The final two attempts experienced much
larger host stalls.

The job launcher incorrectly retried after each nonzero gate result. That was
an operator automation defect, not intended soak policy. The job and final
orphan were removed. Since every retry reused the same detailed-log path, only
the runner summaries and the final partial-run detail remain. The repeated
summaries are useful diagnosis evidence but are not seven independent release
certifications.

## Phase attribution

`SimRunner` already measured the slowest named phase in each heartbeat window,
but quiet-mode formatting discarded `hotspot_phase` and `hotspot_ms`. The
formatter now preserves those two bounded fields. Additional timing labels
cover match statistics, win detection, post-match authority, finalization,
signal emission, and post-match action, and split the previous coarse
simulation groups into their existing constituent calls.

No state mutation moved out of `OpsState`/`SimState`, and no render or input
system gained gameplay authority.

The first fully attributed 220-second run reproduced a natural conquest and
restart:

| Metric | Observed | Limit | Result |
| --- | ---: | ---: | --- |
| Process | 25.50 ms | 45.00 ms | PASS |
| Simulation tick | 175.10 ms | 8.00 ms | FAIL |
| `match_end_emit` phase | 170.40 ms | diagnostic | dominant |

The expensive work was not authoritative simulation. Arena's presentation,
persistence, audio, and settlement-preparation match-end handler was connected
synchronously to `SimRunner.match_ended`, so it executed inside the measured
authoritative tick.

## Remediation

Arena now connects that non-authoritative handler with `CONNECT_DEFERRED`.
`SimRunner` still establishes the authoritative terminal state and emits the
same match-end signal in the same deterministic order. Arena reacts on the next
idle cycle instead of extending the simulation tick.

The same 220-second natural-conquest scenario then crossed the restart with a
5.0 ms transition heartbeat; its measured hotspot was 4.1 ms of post-match
ghost unit work. The prior repeatable 170 ms match-end emission cost was gone.
Two unrelated isolated host-active spikes kept that diagnostic from being a
release pass, which is why a quieter bounded probe followed.

The final 150-second probe passed unchanged limits while VS Code remained open:

| Metric | Observed | Limit | Result |
| --- | ---: | ---: | --- |
| Process | 23.90 ms | 45.00 ms | PASS |
| Simulation tick | 7.90 ms | 8.00 ms | PASS |
| Informational frame delta | 43.20 ms | 45.00 ms | informational |

There were 158 post-warmup arena heartbeats, 317 renderer heartbeats, and 142
simulation heartbeats. The finer groups identified `edge_cache` as the largest
early hotspot and `unit_state` as the largest unit subphase; neither exceeded
the total tick limit in this probe.

## Verification

- `SF_LOG_HEARTBEAT_FORMAT_SMOKE_PASS`.
- `HITCH_OPTIMIZATION_SMOKE_PASS`.
- `ARENA_LIFECYCLE_PAUSE_SOURCE_SMOKE: PASS`.
- `POST_MATCH_STATS_SNAPSHOT_SMOKE: PASS`.
- `MATCH_CLOCK_PAUSE_SMOKE: PASS`.
- `AUTHORITATIVE_BUFF_STATE_SMOKE: PASS`.
- `PVP_RECONNECT_LIFECYCLE_SMOKE: PASS`.
- Repository all-off staging preflight: PASS.
- Immutable candidate manifest verification: PASS.

## Local artifacts

Artifacts are retained locally under `artifacts/performance_diagnostic_20260818/`
and are intentionally excluded from release source.

| Artifact | SHA-256 |
| --- | --- |
| Initial bounded hotspot diagnostic | `9826c254e3b60ae2d8c191827eea0cb923e72212c6ee7da9d8a85f5de47323ec` |
| Fully attributed pre-fix transition | `35cab6fb9ae70ae3acb467eb3eacfd32d8af3f21d45403595866639f0be981f2` |
| Deferred-handler transition diagnostic | `ee3a1725d83f51ed697e50f3a5f43c27fbd59b474552d322f0f5130a97b73266` |
| Passing split-phase probe | `11585ce470959aaaf1bfaf251117a9cf12e322b0975cc0d8316673e18890755b` |

## Remaining gate

Run the full 1,800-second soak once on an idle host with Colima and heavy
desktop applications stopped. Do not change thresholds. If it passes, freeze a
superseding immutable candidate containing both this remediation and the
post-candidate VS dependency update; rerun the required candidate verification
matrix before any Production authorization request.
