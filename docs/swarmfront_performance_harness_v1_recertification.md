# Swarmfront Performance Harness V1 Recertification Sprint

Status: `P0 EVIDENCE FROZEN`

Branch: `sprint/perf-harness-recertification`

Integration source: `a6e19247a5fa9992e96a8747e140ec9d700a9811`

The Harness V1 integration passes its correctness, determinism, isolation, cleanup, and backend-denial gates. It is not ready to merge because two clean Apple M2 Pro recertification attempts reproducibly failed the static windowed timing contract before baseline packaging.

The machine-readable sprint record is `data/perf/harness_v1_recertification_sprint.json`. It preserves the workflow run IDs, artifact IDs and digests, source commit, timing ranges, and the refusal to promote either result.

## Frozen failure signature

| Run | Static repetitions | Total hitches | p99 range | Maximum frame | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `29753338264` | 6 | 29 | 41.393–42.438 ms | 43.072 ms | baseline refused |
| `29757697555` | 6 | 32 | 41.577–42.493 ms | 46.386 ms | baseline refused |

Both reports came from clean commit `a6e1924`, Godot 4.2.2 stable, and an Apple M2 Pro. Both passed integrity, determinism, isolation, fixture cleanup, and backend isolation. The enforced timing contract remains p99 at or below 41.67 ms with zero frames above the 41.67 ms hitch threshold.

## Sequential execution gates

1. P1 must isolate whether runner state, VSync/display cadence, warmup, or preceding workload causes the failure.
2. P2 may implement only the smallest evidence-backed correction. A timing-contract change must be versioned and explicitly reviewed.
3. P3 requires all focused gates plus three consecutive clean arm64 recertifications on one exact commit.
4. P4 may promote only one passing four-report package with verified hashes and 4/4 self-comparisons.
5. P5 requires exact-commit Release Readiness and an authority-boundary audit.
6. P6 merges through a rollback-friendly merge commit and requires the exact main merge SHA to pass post-merge readiness.

No phase may advance after an unresolved failure.
