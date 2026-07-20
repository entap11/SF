# Swarmfront Performance Harness V1 Host Recertification Review

Status: `HOST DIAGNOSTIC CONCLUDED`

Branch: `sprint/perf-harness-recertification`

Integration source: `a6e19247a5fa9992e96a8747e140ec9d700a9811`

The Harness V1 integration passes its correctness, determinism, isolation, cleanup, and backend-denial gates. Two clean Apple M2 Pro attempts reproducibly failed the static windowed timing contract before baseline packaging. Those failures are retained, and neither result may be promoted as a host baseline.

They do not, by themselves, block integration of this mobile-only game's performance harness. The original exit and handoff define the windowed package as an exact-fingerprint debug-host regression reference, not a release-device performance claim. Physical iOS or Android evidence is the applicable source for mobile GPU, thermal, energy, and device frame-pacing conclusions.

The machine-readable sprint record is `data/perf/harness_v1_recertification_sprint.json`. It preserves the workflow run IDs, artifact IDs and digests, source commit, timing ranges, and the refusal to promote either result.

Supplemental physical-iOS testing subsequently passed a 150-second production gameplay soak and two bounded Instruments captures on an iPhone 16 Pro. Both valid captures remained at nominal thermal state and exited successfully. See `docs/swarmfront_performance_harness_v1_ios_device_evidence.md` and `data/perf/harness_v1_ios_device_evidence.json`. This evidence supports the existing `HARNESS V1 READY WITH LIMITATIONS` recommendation; it does not make a battery, Android, or full device-matrix claim.

## Frozen failure signature

| Run | Static repetitions | Total hitches | p99 range | Maximum frame | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `29753338264` | 6 | 29 | 41.393–42.438 ms | 43.072 ms | baseline refused |
| `29757697555` | 6 | 32 | 41.577–42.493 ms | 46.386 ms | baseline refused |

Both reports came from clean commit `a6e1924`, Godot 4.2.2 stable, and an Apple M2 Pro. Both passed integrity, determinism, isolation, fixture cleanup, and backend isolation. The enforced timing contract remains p99 at or below 41.67 ms with zero frames above the 41.67 ms hitch threshold.

## Diagnostic conclusion

Subsequent isolated launches, display-awake assertions, focus variants, and LaunchServices foreground launches did not establish a reliable focused Godot window on the self-hosted macOS runner. Some variants still showed periodic host presentation stalls while continuing to pass correctness and isolation. Provisioning another desktop runner is not required for the mobile merge decision.

The host timing contract remains valid for its narrow purpose: a candidate may be promoted only when its complete comparison fingerprint matches and all timing limits pass. A failed or incompatible host capture must still fail closed. This review changes no timing threshold and promotes no new baseline.

## Integration gates

1. Run all 19 focused correctness, determinism, isolation, cleanup, and backend-denial gates.
2. Verify the existing curated package hashes and its 4/4 compatible self-comparisons.
3. Audit the integration diff for the authoritative-state boundary.
4. Run exact-commit Release Readiness.
5. Treat physical-device performance evidence as an explicit merge limitation unless it is collected on a connected device.
6. Merge through a rollback-friendly merge commit only when the applicable gates pass and the documented device-evidence limitation is accepted.
