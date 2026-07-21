# iPhone Startup Hitch Diagnosis — Work Codex Handoff

Date: 2026-07-20

Branch: `codex/iphone-startup-hitch-diagnosis`

Baseline: `main` at `1fb58f844fc3fd21159aa9c347e94aef8fb4288c`

Diagnostic implementation commit: `2c27ac363ffcea658b2fe1415d6b882540329110`

Status: **IMPLEMENTATION AND CLEAN SIGNED BUILD COMPLETE — PHYSICAL DEVICE EXECUTION BLOCKED BY LOCKED IPHONE**

## Pickup objective

Resume at device installation. Do not redesign the collector, optimize startup, or begin attribution variants before completing the controlled physical-iPhone baseline.

The remaining sprint question is whether the previously observed 142 ms and 225 ms startup signatures reproduce on the iPhone 16 Pro, whether they are player-visible, and which existing startup boundary owns them.

The complete protocol and acceptance rules are in [iphone_startup_hitch_diagnosis_sprint_2026-07-20.md](iphone_startup_hitch_diagnosis_sprint_2026-07-20.md).

## What is complete

The branch adds a debug-only `--startup-hitch-diagnostic` mode to the existing production-component `--soak-perf` route.

Actual code ownership was audited before implementation:

- `scripts/shell.gd` owns the exported soak startup, scene load/instantiate/add, requested-map prewarm/application, and presentation boundary.
- `scripts/arena.gd` owns Arena lifecycle, UnitRenderer/VfxManager prewarm, prematch, input unlock, simulation activation, authority counts, and pool snapshots.
- `scripts/systems/sim_runner.gd` owns first canonical-tick timing and existing phase costs.

Implemented capabilities:

- bounded monotonic startup markers and hitch events;
- rendered-frame threshold strictly over 50 ms;
- canonical-tick threshold strictly over 8 ms;
- `PRE_INPUT_LOADING`, `POST_OVERLAY_PRE_INPUT`, `INTERACTIVE`, and `UNKNOWN_VISIBILITY` classification;
- repeated prematch/activation/unlock markers, required because the current soak route initially completes the default Arena startup before applying the requested fixture;
- a 20-second default window, long enough to capture the requested map's first canonical tick;
- explicit unavailable labels for metrics Godot does not expose;
- backend denial and process-lifetime AnalyticsClient/AppLifecycle isolation;
- before/after hashes for protected rank, economy, progression, leaderboard, analytics, and related state;
- release-build refusal and requirement for the exact `--soak-perf` pairing;
- physical-iOS-only run aggregation with cold/warm run-level distributions.

No production performance threshold, graphics default, FPS/VSync setting, gameplay rule, authoritative result, map, presentation timing, or shipping optimization was changed.

## Key files

- `scripts/dev/startup_hitch_diagnostic.gd` — bounded collector and JSON report.
- `scripts/dev/summarize_startup_hitch_runs.py` — physical-iOS eligibility and run-level summaries.
- `tools/startup_hitch_diagnostic_smoke_test.gd` — activation, isolation, hitch, visibility, output, and protected-state contract.
- `scripts/shell.gd` — diagnostic activation and real startup boundaries.
- `scripts/arena.gd` — Arena/prewarm/prematch/runtime context.
- `scripts/systems/sim_runner.gd` — canonical tick timing.
- `scripts/state/test_backend_policy.gd` — early network denial.
- `scripts/state/analytics_client.gd` — process-lifetime analytics isolation.
- `scripts/state/app_lifecycle_state.gd` — external lifecycle isolation.
- `scripts/tests/perf/perf_isolation_guard.gd` — public protected-state hash seam.
- `docs/iphone_startup_hitch_diagnosis_sprint_2026-07-20.md` — authoritative operating plan.

## Validation already completed

Passed:

- `git diff --check`
- startup hitch diagnostic smoke;
- Performance Harness Gate C isolation smoke;
- AppLifecycle isolation smoke;
- production backend refusal smoke;
- MVP smoke: 26 passes, zero failures;
- summarizer calculation smoke;
- 25-second headless integration soak: one round, zero failed rounds;
- integration report protected-state integrity.

The direct `analytics_client_queue_smoke_test.gd` invocation was not used as a pass gate: the baseline AnalyticsClient intentionally isolates all automated script processes, while that older smoke expects to enqueue an event, so it returns `perf_harness_isolated` before any startup-diagnostic-specific behavior is involved.

## Local plumbing observation — not device evidence

The 20-second headless integration captured:

- maximum frame: 145.572 ms;
- second retained frame hitch: 119.253 ms;
- both between requested-map application and Arena presentation;
- both `PRE_INPUT_LOADING`, with input locked and commands not accepted;
- first canonical tick: 2.219 ms;
- maximum canonical tick in the window: 5.593 ms;
- protected-state integrity: pass.

This validates the marker sequence only. The summarizer correctly rejects the report as `not_physical_ios` and `headless`. Do not cite these durations as an iPhone result or infer that the original signatures are resolved.

## Exact signed build available on the current Mac

The implementation was committed before export. A detached, clean worktree at the exact commit was used:

```text
/tmp/sf-startup-hitch-device-2c27ac3
```

Signed application:

```text
/Users/home/SideProjects/SF/project-startup-hitch/artifacts/startup_hitch_diagnostic/device_build/DerivedData/Build/Products/Debug-iphoneos/SwarmfrontStartupHitch.app
```

Ignored build manifest:

```text
/Users/home/SideProjects/SF/project-startup-hitch/artifacts/startup_hitch_diagnostic/device_build/build_manifest.json
```

Fingerprint:

- source commit: `2c27ac363ffcea658b2fe1415d6b882540329110`
- source tree: `7f12abc0bad9306f6a5f7b4bbc971a1b8503bc78`
- PCK SHA-256: `86488a514e736c75bf3eae8ef058980875918eb56675798d52a17d4d7cdd8f4f`
- executable SHA-256: `b23c269d92d35d7a1cfe6614f48df395b65799e711707cca2832a2ea6baef641`
- Xcode project SHA-256: `0c0e5ec2012d8a36682c13d1bfb827f76bb88cadf96e0a1f386f0939bb677482`
- bundle: `com.matthew.swarmfront`
- signing team: `SH6675DXQ5`
- signing verification: pass;
- entitlements: `get-task-allow=true` and `application-identifier=SH6675DXQ5.com.matthew.swarmfront`.

The artifact tree is intentionally Git-ignored. On another Mac, rebuild it from the exact implementation commit using the commands in the sprint document.

Known existing export/build warnings were recorded rather than changed: deprecated launch images and empty camera, microphone, and photo-library usage-description values.

## Physical-device stopping point

Device:

- Matthew's iPhone;
- iPhone 16 Pro (`iPhone17,1`);
- iOS 26.5.2;
- CoreDevice identifier `B8F36805-35EE-5AC8-B9A7-4944062B98F7`;
- Xcode destination UDID `00008140-000614482E00401C`.

At the stopping point:

- `devicectl` reported the phone paired and available;
- `xctrace` reported the phone offline;
- installation reached developer-disk-image setup, then failed with CoreDevice error 10003 because the phone was locked;
- the app was not installed or launched;
- no cold/warm device run or Instruments trace was collected.

## Exact next actions

1. Make the iPhone awake, unlocked, trusted, connected, and visible under the online `xcrun xctrace list devices` section.
2. Confirm thermal state is Nominal, Low Power Mode is off, and the chosen battery/external-power policy is recorded.
3. Verify the branch and source artifact:

```sh
cd /Users/home/SideProjects/SF/project-startup-hitch
git switch codex/iphone-startup-hitch-diagnosis
git status --porcelain
jq . artifacts/startup_hitch_diagnostic/device_build/build_manifest.json
codesign --verify --deep --strict \
  artifacts/startup_hitch_diagnostic/device_build/DerivedData/Build/Products/Debug-iphoneos/SwarmfrontStartupHitch.app
```

4. Retry the already prepared installation:

```sh
xcrun devicectl device install app \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  artifacts/startup_hitch_diagnostic/device_build/DerivedData/Build/Products/Debug-iphoneos/SwarmfrontStartupHitch.app
```

5. Run one non-baseline validation launch first:

```sh
xcrun devicectl device process launch \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --console \
  --terminate-existing \
  com.matthew.swarmfront \
  -- \
  --soak-perf \
  --soak-seconds=25 \
  --soak-round-seconds=25 \
  --soak-pairs=2 \
  --soak-map=res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json \
  --soak-sim-profile \
  --startup-hitch-diagnostic \
  --startup-hitch-window-seconds=20 \
  --startup-hitch-launch=warm \
  --startup-hitch-source-commit=2c27ac363ffcea658b2fe1415d6b882540329110 \
  --startup-hitch-build-label=iphone16pro-validation \
  --startup-hitch-output=user://startup_hitch_diagnostic/validation-01.json
```

The standalone `--` is mandatory. A valid console must show `STARTUP_HITCH_DIAGNOSTIC_REPORT` and a soak summary with zero failed rounds.

6. Copy and validate the report:

```sh
mkdir -p artifacts/startup_hitch_diagnostic/evidence
xcrun devicectl device copy from \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --domain-type appDataContainer \
  --domain-identifier com.matthew.swarmfront \
  --source Documents/startup_hitch_diagnostic/validation-01.json \
  --destination artifacts/startup_hitch_diagnostic/evidence/

jq '{schema,status,configuration,runtime,protected_state_integrity,summary}' \
  artifacts/startup_hitch_diagnostic/evidence/validation-01.json
```

Confirm the installed build's displayed `user://` mapping before automating bulk copies.

7. If validation is sound, execute the documented 10-cold/10-warm matrix. Follow the strict definitions in the sprint document; an Arena reload is never a cold launch. Record battery, power, Low Power Mode, initial/final thermal state, storage where obtainable, orientation, display behavior, and network condition outside the app report.
8. Reject and repeat runs with non-Nominal thermal state, changed power condition, interruption, wrong arguments/build, incomplete JSON, failed protected-state integrity, or any failed soak round.
9. Summarize eligible reports:

```sh
python3 scripts/dev/summarize_startup_hitch_runs.py \
  artifacts/startup_hitch_diagnostic/evidence \
  --output artifacts/startup_hitch_diagnostic/evidence/baseline_summary.json
```

10. Only after the baseline identifies a repeated phase, take one focused Time Profiler capture and, if GPU ownership remains plausible, one focused Metal System Trace around that interval.
11. Select at most one attribution variant matching the evidence. Do not implement the draft A–G variants as a batch and do not adopt a variant as shipping behavior.

## Guardrails for the next Codex

- Stay iPhone-only for this sprint.
- Use the existing production `Shell._run_soak_perf` route.
- Do not build another startup or performance harness.
- Do not change the 50 ms/8 ms diagnostic thresholds or any approved production benchmark gate.
- Do not alter gameplay authority, map content, simulation order, target FPS, VSync, graphics defaults, or steady-state presentation.
- Do not call desktop, headless, or simulator timing device evidence.
- Do not optimize before attribution.
- Do not hide an interactive hitch by adding an untruthful loading delay.
- Keep backend, analytics, lifecycle, and protected-state isolation intact.
- Do not push generated Xcode projects, apps, traces, or raw artifact directories.
- Do not merge, deploy, or enable a public rollout as part of this sprint.

## Separate deferred planning input

`planning_import/ENTaP_Reuse_First_Tooling_Governance_Draft_2026-07-20.md` was added as a draft planning input at the user's request. It requires sharpening and must not be implemented as part of this startup-hitch continuation.

## Expected next handoff result

The next handoff should contain the eligible cold/warm run count, device-condition manifest, per-run distributions, hitch table with visibility, focused trace findings, attributed subsystem or bounded nonreproduction, remaining uncertainty, and the exact next decision. If the physical baseline is incomplete, report `HOLD_INSUFFICIENT_EVIDENCE`; do not infer success from the local plumbing run.
