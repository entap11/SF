# Swarmfront Performance Harness V1 Physical iOS Evidence

Status: `PASS WITH LIMITATIONS`

Capture date: `2026-07-20`

Source commit under test: `eaea2fccc79b51591eb7acdf7c41dffcefdd6af4`

This supplemental review confirms that the integrated Harness V1 branch can build, sign, install, launch, and sustain the production gameplay soak route on a physical iPhone. It adds real mobile renderer, CPU sampling, display-cadence, and thermal evidence to the merge review. It does not replace the historical exit record, and it is not a complete release-device performance certification.

The machine-readable record is `data/perf/harness_v1_ios_device_evidence.json`. Instruments trace bundles are retained outside Git because they are large binary artifacts; their deterministic tree digests are recorded below.

## Device and build identity

| Field | Value |
| --- | --- |
| Device | iPhone 16 Pro |
| OS | iOS 26.5.2 (23F84) |
| GPU | Apple A18 Pro GPU |
| Device UDID | `00008140-000614482E00401C` |
| Bundle identifier | `com.matthew.swarmfront` |
| App version/build | 0.1.1 / 2026071701 |
| Signing team | `SH6675DXQ5` |
| Executable SHA-256 | `4d6a8558a0d1950298f17765201b47eb0bd224369340f5eebf0ffabff65f2d16` |
| PCK SHA-256 | `9deaddd3078526263bdbf73257b8d7cef1705906c5a5110335c0b4ea276bf1bd` |

The debug app passed strict deep code-signature verification before installation.

## Production soak results

The exported app does not expose the development-only SceneTree `--script` runner used by the desktop Harness V1 fixture matrix. Device execution therefore used the existing debug-only `--soak-perf` route in the production Shell. That route exercises the real Shell, authoritative simulation, and mobile renderer without moving gameplay mutation into input, UI, or rendering code.

All runs used `res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json` and requested eight lane pairs. The map initially exposed four eligible pairs; normal production play expanded the active lanes during the run.

| Run | Duration | Instrumentation | Result | Observed behavior |
| --- | ---: | --- | --- | --- |
| Extended soak | 150 s | device console and simulation profiling | `SOAK_SUMMARY` with 1 round, 0 failed | After warmup, approximately 115–120 FPS initially and approximately 90–100 FPS as lanes and units accumulated; simulation ticks were generally 2–7.9 ms, with a small number of greater-than-8 ms warnings. |
| Metal soak | 45 s | 10 s Metal System Trace | `SOAK_SUMMARY` with 1 round, 0 failed | Mostly 114–120 FPS during the captured interval. The trace recorded 86 startup-second surface swaps and 110–118 swaps in each subsequent complete second. |
| CPU soak | 45 s | 20 s Time Profiler | `SOAK_SUMMARY` with 1 round, 0 failed | Mostly 114–120 FPS during the captured interval; the trace exported 7,803 profiler sample rows. |

Startup included one approximately 142 ms rendered frame and one approximately 225 ms early simulation hitch. These observations are retained rather than excluded. The extended run also showed occasional simulation-tick cost warnings around 8.5 ms under accumulated load.

## Trace validation

| Trace | Instruments duration | Size | Deterministic tree SHA-256 | Validation |
| --- | ---: | ---: | --- | --- |
| Metal System Trace | 11.395343 s | 141 MB | `35a9f95c8c07c8046eb046da83ea2c6910ca6455e3790eb5a2b8253c507f4e14` | Correct iPhone and app process; attached process exit 0; thermal state nominal for the full trace. |
| Time Profiler | 21.009884 s | 12 MB | `ab519e8f64c8a2ebeb662ddb368008a58246b60e5492a89e1c7149c190b50155` | Correct iPhone and app process; attached process exit 0; thermal state nominal for the full trace. |

A first 90-second Metal capture produced about 4.2 GB of trace data but did not finish Instruments post-processing in a reasonable bounded interval. It was terminated after the 150-second gameplay soak itself completed successfully and is classified `ABORTED_TOOLING_POSTPROCESS`; it is not counted as valid trace evidence. The subsequent bounded Metal trace completed and exported successfully.

## Limitations and merge interpretation

- This is one iOS device class and one map, not the repeated selected-fixture device matrix described by the original handoff.
- The exported app ran the production soak route, not the development-only direct fixture runner, so canonical per-fixture report comparisons were not generated on-device.
- No beginning/end battery measurement or Energy Log capture was collected; no battery or energy claim is made.
- Android and additional low-/mid-tier iOS device classes remain untested.
- Audio, SSL-module, icon-format, and Unicode-NUL startup warnings were observed. They were non-fatal during these runs and are disclosed, not classified here as performance-harness regressions.

Within those boundaries, the physical iOS results support `HARNESS V1 READY WITH LIMITATIONS`. They remove the complete absence of device evidence as a merge concern, but they do not justify changing the recommendation to an unqualified `READY`.
