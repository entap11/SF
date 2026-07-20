# Swarmfront Performance Harness V1 Exit

Status: `SPRINT COMPLETE`

Recommendation: `HARNESS V1 READY WITH LIMITATIONS`

Harness V1 is complete on `codex/perf-harness-v1-completion`. The branch is suitable for merge evaluation: deterministic correctness, isolation, bounded collection, lifecycle cleanup, feature controls, and clean-tree baseline promotion all pass. No merge, deployment, gameplay change, or optimization is included.

For pickup on another computer, use [swarmfront_performance_harness_v1_handoff.md](swarmfront_performance_harness_v1_handoff.md).

## What passed

The final exit exercise completed 95 real scenario runs with zero failed scenarios, in addition to all 18 focused Phase 0–2-F gates. Gate G then passed, bringing the final focused-gate total to 19:

| Evidence | Runs | Result |
| --- | ---: | --- |
| Phase 0 integrity | 3 | determinism, protected state, cleanup, backend isolation PASS |
| Phase 0 sentinel/mutator/sentinel isolation | 3 | matching state hashes and freed fixture roots PASS |
| Phase 0 collector calibration | 9 | OFF/MINIMAL/FULL repeated behavior PASS |
| Phase 1 clean baseline candidates | 24 | all eligible, clean, and three-repetition stable |
| P2-B moving units | 12 | 50/100/200/400 production movement and pool evidence PASS |
| P2-C upgrade/Super Swarm | 6 | production event, transition, renderer, and cleanup evidence PASS |
| P2-D battlefield/UI | 21 | all seven windowed fixtures PASS |
| P2-E lifecycle | 8 | all bounded setup/run/cleanup cycles PASS |
| P2-F feature isolation | 9 | off/production/exaggerated one-variable evidence PASS |

All Phase 2 reports passed determinism, isolation, protected-state restoration, fixture cleanup, and backend/analytics denial. The latest 56 Phase 2 scenario runs recorded zero hitches; that observation is diagnostic, not a promoted timing guarantee.

Lifecycle exit evidence returned node and resource counts exactly, left zero orphan nodes, grew object count by one against a limit of 64, and grew retained static memory by 1,749,676 bytes against a 32 MiB ceiling. The eight cycles retained exactly 720 percentile and 720 raw samples, with 273,566 total report bytes.

Collector calibration observed median wall-duration deltas of 0.749% for MINIMAL and 1.242% for FULL versus OFF. This is repeated directional evidence only and is not an exact instrumentation-cost claim.

## Curated baseline package

The approved Harness V1 package is [manifest.json](../data/perf/baselines/harness_v1/manifest.json). It contains only the four Phase 1 profile families that the runtime eligibility policy permits:

| Report | Mode | Runs | SHA-256 |
| --- | --- | ---: | --- |
| `static_fixtures_windowed.json` | static deterministic windowed | 6 | `ede3f41bdb42f9ca33b71e488847382c746102dc933078940e41439d35202aba` |
| `normal_match_canonical.json` | canonical simulation headless | 3 | `301d13f6d905a0bc488b7da7b7f2719b1706da971ce5b5be4b1337109f260168` |
| `normal_match_windowed.json` | deterministic windowed presentation | 3 | `1599e89b9d6480b4efade5ad261e6ea1590112fd1ed6aa3daf6bb737424ccb7f` |
| `unit_scale_windowed.json` | static deterministic windowed | 12 | `1bb8f5ce7a1a85c07a42fb200686cde357911b09b05c026745496736469514e2` |

The package was generated from clean commit `557a8e5`, uses MINIMAL bounded collection and three repetitions, and passed 4/4 self-comparisons as compatible and baseline-eligible. Phase 2 reports are correctness/diagnostic evidence and are intentionally excluded.

The older `data/perf/baselines/phase1` package is preserved for audit but superseded. Comparing it to the Harness V1 package correctly refuses with `fixture_config_hash` mismatches because the finalized renderer-isolation configuration changed the comparison identity. Do not bypass that refusal.

## Environment boundary

| Identity | Exit value |
| --- | --- |
| Godot/build | 4.2.2 stable official / debug |
| Host | macOS arm64, 10 logical processors |
| Adapter | Apple M2 Pro, Forward+, Vulkan |
| Viewport | 1080 × 1920, viewport stretch, keep-width |
| Pacing | 30 FPS benchmark target, VSync enabled, physics 60 Hz |
| Feature registry | 47 entries, hash `fa50fd59704f6b487216da1e9ab7ae21be9296aaa9e1e4517f333ed5300ec978` |

Baseline approval applies only when the full comparison fingerprint matches. These results are not release-device performance claims.

## Device evidence and exact follow-up

Physical-device GPU, thermal, and energy evidence could not be collected. Xcode 26.6 is installed and exposes `Metal System Trace` and `Time Profiler`, but the registered iPhone was offline. Android `adb` is not installed. The missing evidence is explicit; no in-engine substitute or zero value was fabricated.

For iOS, connect, unlock, and trust the device; install and launch the same Swarmfront build; then verify and capture:

```bash
xcrun xctrace list devices
xcrun xctrace record --template 'Metal System Trace' --device '<device-UDID>' --time-limit 2m --output 'Swarmfront-Metal.trace' --attach 'Swarmfront'
xcrun xctrace record --template 'Time Profiler' --device '<device-UDID>' --time-limit 2m --output 'Swarmfront-Time.trace' --attach 'Swarmfront'
```

Run one warmup and three captures for the late-match, 400-moving-unit, upgrade-storm, and UI-stress schedules. Record device model, OS, build commit, initial/final battery percentage, initial/final thermal state, and ambient/power conditions. If `Energy Log` is available in Instruments on the connected Xcode/device combination, capture the same schedules there; otherwise use Xcode Organizer energy metrics from a signed distribution build and label the evidence source.

For Android, install platform tools and Android GPU Inspector, connect a production-class device, and use the real application ID in this sequence:

```bash
adb devices -l
adb shell dumpsys batterystats --reset
adb shell dumpsys thermalservice > thermal-before.txt
adb shell dumpsys gfxinfo '<application-id>' reset
# Run one warmup and three copies of each selected harness schedule.
adb shell dumpsys gfxinfo '<application-id>' framestats > gfx-framestats.txt
adb shell dumpsys thermalservice > thermal-after.txt
adb shell dumpsys batterystats '<application-id>' > battery-after.txt
```

Capture a matching Android GPU Inspector trace for GPU stage attribution and preserve the device/build fingerprint beside every artifact.

## Limitations and review risks

- Physical-device GPU, thermal, energy, overdraw, and shader-occupancy evidence remains outstanding.
- The approved timing baselines are for this exact debug-host fingerprint only.
- 3-player, 4-player, multi-map async, and multi-stage async fixtures remain deferred as agreed.
- The repository still emits pre-existing missing `assets/sprites/sf_skin_v1/barracks.PNG`, Godot shader-cache teardown, and Unicode NUL warnings. Structured reports pass and remain authoritative, but the missing asset should be handled as a separate product-quality issue.
- No optimization conclusion should be drawn solely from the Phase 2 diagnostic timings.

## Rollback checkpoints

| Phase | Commit |
| --- | --- |
| P2-A program contract | `792ee31` |
| P2-B moving scale | `ac2cadb` |
| P2-C upgrade/Super Swarm | `755f555` |
| P2-D battlefield/UI | `dccce88` |
| P2-E lifecycle | `e2dd4ce` |
| P2-F feature isolation | `557a8e5` |
| P2-G baselines and exit | `d33bbf6` |

The final P2-G commit adds the exit package, machine-readable decision, Gate G, and this report. Review can preserve these commits for rollback and then choose merge-commit or squash policy separately.

## Merge evaluation

`HARNESS V1 READY WITH LIMITATIONS`

Recommended review action: inspect the P2-G package/decision files, run Gate G plus one representative clean candidate on the reviewer’s machine, and merge only if the documented device-evidence gap and deferred 3P/4P/async scope are acceptable. Further performance optimization or production telemetry work should start in a separate branch after that decision.
