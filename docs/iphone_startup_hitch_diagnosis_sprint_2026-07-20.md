# iPhone Startup Hitch Diagnosis Sprint

Date: 2026-07-20

Status: **IN PROGRESS — diagnostic implementation and local validation complete; physical iPhone baseline pending**

Baseline: `main` at `1fb58f844fc3fd21159aa9c347e94aef8fb4288c`

Baseline tree: `80a2a58819a5a63b6b8fcf11ebb395922aa7822b`

Branch: `codex/iphone-startup-hitch-diagnosis`

## Decision this sprint must support

Determine whether the observed 142 ms and 225 ms startup events are reproducible on the iPhone 16 Pro, whether they occur while gameplay is interactive, and which existing startup boundary owns them. This first slice is attribution only. It does not optimize startup or alter production timing.

The sprint remains a hold until physical-device evidence supports one of these outcomes for each signature:

- `FIXED_AND_VERIFIED`
- `MOVED_BEHIND_NONINTERACTIVE_LOADING`
- `NONREPRODUCIBLE_WITH_BOUNDED_EVIDENCE`
- `UNRESOLVED_PLAYER_VISIBLE_HITCH`

No conclusion may be based on desktop, simulator, or headless timing.

## Actual production route

The original draft named `scripts/dev/soak_perf_runner.gd`; that file is not the exported startup owner in this tree. The diagnostic follows the existing production-component route:

1. `Shell._maybe_start_soak_perf()` parses the debug-only request.
2. `Shell._run_soak_perf()` resolves the normal soak fixture and calls the existing Shell match path.
3. Shell loads, instantiates, and adds the production Arena scene, prewarms the requested map model, applies it through `MapApplier`, and reveals the Arena.
4. Arena performs its normal `_enter_tree`, `_ready`, UnitRenderer/VfxManager prewarm, prematch transition, input unlock, and simulation activation.
5. SimRunner performs the canonical tick and exposes its existing phase costs.

There is no duplicate startup flow, synthetic Arena, altered map model, or diagnostic simulation.

## Diagnostic contract

The exact activation pair is:

```text
--soak-perf --startup-hitch-diagnostic
```

The diagnostic:

- is accepted only when `OS.is_debug_build()` is true;
- refuses startup without the existing `--soak-perf` route;
- activates the existing backend deny policy before HTTP is allowed;
- isolates AnalyticsClient before its first session or queue mutation and suppresses external AppLifecycle handling for the dedicated process;
- hashes protected rank, economy, progression, leaderboard, analytics, and related state before and after the window;
- uses monotonic `Time.get_ticks_usec()` intervals;
- records at most 64 markers and 64 hitch events;
- records rendered frames strictly over 50 ms and canonical ticks strictly over 8 ms;
- ignores the diagnostic node's first inherited `_process` delta because that interval began before the node was armed;
- writes one structured JSON report, with unsupported metrics explicitly marked unavailable;
- changes no gameplay rule, canonical simulation result, production threshold, FPS, VSync, map, renderer setting, or presentation timing.

Release requests fail closed with `debug_build_required`. The diagnostic scripts may remain in an export but are inert in release builds.

## Markers at stable code boundaries

Shell records:

- diagnostic invocation;
- match scene load requested, resource loaded, instantiated, and added;
- map prewarm requested, model ready, application started, and application completed;
- Arena presentation visible;
- diagnostic window completed.

Arena records:

- `_enter_tree`;
- `_ready` entered and completed;
- UnitRenderer pool prewarm started and completed;
- VfxManager pool prewarm started and completed;
- simulation activation requested;
- prematch completed and player input unlocked.

SimRunner records:

- first canonical tick started;
- first canonical tick completed, including existing phase timings.

The collector observes the first interactive frame, first authoritative lane activity, and first authoritative unit activity. The codebase has a UnitRenderer pool and a VfxManager pool; the draft's separate renderer and unit-pool markers were therefore collapsed instead of inventing a third pool.

## Hitch record and visibility

Every retained hitch contains the current and next marker, frame/physics/tick indices, frame and engine process timing, last canonical tick and phase costs, rendering counters when the display server exposes them, object/node/resource/static-memory counters, authoritative Arena counts, pool telemetry, and the current loading/input state.

Visibility is classified as:

- `PRE_INPUT_LOADING`: Arena is not yet visibly interactive or a prematch overlay is visible.
- `POST_OVERLAY_PRE_INPUT`: presentation is visible, but input remains locked.
- `INTERACTIVE`: Arena exists, OpsState is running, and input is unlocked.
- `UNKNOWN_VISIBILITY`: runtime state cannot establish one of the above.

A missing Arena always remains input-locked. This prevents an autoload's initial values from falsely classifying pre-Arena frames as interactive.

Godot does not expose all desired iOS counters. Render time, texture/video memory, battery, power, Low Power Mode, storage, and thermal state are never emitted as zero when unavailable; the report names the unavailable source. Battery, power, Low Power Mode, storage, and thermal observations belong in the external run manifest.

## Build and device fingerprint

Prepared host/device inputs:

- Godot: `4.2.2.stable.official.15073afe3`
- Xcode: `26.6 (17F113)`
- Device: iPhone 16 Pro (`iPhone17,1`)
- CoreDevice identifier: `B8F36805-35EE-5AC8-B9A7-4944062B98F7`
- Xcode destination UDID: `00008140-000614482E00401C`
- Observed iOS: `26.5.2`
- Bundle identifier: `com.matthew.swarmfront`
- Development team: `SH6675DXQ5`

At preparation time CoreDevice reported the phone paired and available, while Instruments reported it offline. The baseline must not begin until the phone is awake, unlocked, trusted, visible to `xctrace`, and in the approved thermal/power condition.

Each installable artifact must come from a clean commit-isolated worktree. Record the commit, clean `git status --porcelain`, tree hash, PCK SHA-256, executable SHA-256, Xcode project hash, signing identity, app version/build, and exact arguments in a build manifest under `artifacts/startup_hitch_diagnostic/`.

## Export, sign, install, and launch

Use the diagnostic commit produced by this branch:

```sh
ROOT=/Users/home/SideProjects/SF/project-startup-hitch
DIAGNOSTIC_COMMIT=<diagnostic-commit-sha>
BUILD_WORKTREE=/tmp/sf-startup-hitch-$DIAGNOSTIC_COMMIT
PROJECT="$ROOT/artifacts/startup_hitch_diagnostic/device_build/SwarmfrontStartupHitch.xcodeproj"
DERIVED="$ROOT/artifacts/startup_hitch_diagnostic/device_build/DerivedData"

git worktree add --detach "$BUILD_WORKTREE" "$DIAGNOSTIC_COMMIT"
godot --headless --path "$BUILD_WORKTREE" --export-debug iOS "$PROJECT"

xcodebuild \
  -project "$PROJECT" \
  -scheme SwarmfrontStartupHitch \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM=SH6675DXQ5 \
  CODE_SIGN_STYLE=Automatic \
  'CODE_SIGN_IDENTITY=Apple Development' \
  build

xcrun devicectl device install app \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  "$DERIVED/Build/Products/Debug-iphoneos/SwarmfrontStartupHitch.app"
```

Launch one 20-second diagnostic window inside a soak long enough for the route's initial Arena setup, requested-map prematch, and first canonical tick:

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
  --startup-hitch-launch=cold \
  --startup-hitch-source-commit=<diagnostic-commit-sha> \
  --startup-hitch-build-label=iphone16pro-baseline \
  --startup-hitch-output=user://startup_hitch_diagnostic/cold-01.json
```

The standalone `--` after the bundle identifier is mandatory. Change both launch classification and output filename for every run. A valid console ends with `STARTUP_HITCH_DIAGNOSTIC_REPORT` and zero failed soak rounds.

Copy a report with:

```sh
xcrun devicectl device copy from \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --domain-type appDataContainer \
  --domain-identifier com.matthew.swarmfront \
  --source Documents/startup_hitch_diagnostic/cold-01.json \
  --destination "$ROOT/artifacts/startup_hitch_diagnostic/evidence/"
```

Confirm the displayed `user://` container mapping on the installed build before relying on bulk copy.

## Controlled 20-run baseline

Use this exact build, map, fixture, graphics configuration, portrait/landscape orientation, target FPS, VSync mode, and network policy for all runs.

Cold launch means: reboot the phone, wait until the device is Nominal and otherwise within the approved condition, do not launch this build after that reboot, confirm the app process is absent, then launch the diagnostic once. Ten cold runs therefore require ten controlled reboot cycles. Reinstalling or reloading the Arena alone is not a cold launch.

Warm launch means: on the same build and boot, complete one valid unmeasured priming launch, terminate the app, verify the process is absent, then launch the measured diagnostic. Perform ten measured warm launches; repeat the priming launch after any reboot or build install.

Before every run record:

- run ID and cold/warm classification;
- battery percentage and external-power state;
- Low Power Mode state;
- initial thermal state;
- available storage if obtainable;
- orientation, display refresh behavior, and network condition;
- whether the run meets the approved condition.

After every run record final thermal state. Reject and repeat a run with a non-Nominal thermal state, changed power policy, unexpected interruption, wrong build/arguments, incomplete JSON, failed protected-state integrity, or a failed soak round.

Summarize only eligible physical-iOS JSON reports:

```sh
python3 scripts/dev/summarize_startup_hitch_runs.py \
  artifacts/startup_hitch_diagnostic/evidence \
  --output artifacts/startup_hitch_diagnostic/evidence/baseline_summary.json
```

The summarizer calculates run-level distributions first, uses nearest-rank P95, separates cold and warm, reports occurrence and interactive-occurrence rates, and rejects headless, non-iOS, incomplete, unclassified, missing-commit, or protected-state-failing reports.

## Attribution decision

Do not implement the draft's A–G variants speculatively. After the baseline:

1. Select the repeated maximum's last/next marker boundary.
2. Capture one focused Time Profiler trace around that interval.
3. If rendering/GPU ownership remains plausible, capture one focused Metal System Trace around the same interval.
4. Choose one variable from the subsystem actually implicated: scene construction, map application, UnitRenderer/VFX prewarm, simulation activation/first tick, first activity, floor/polish rendering, or a nonessential service.
5. Run enough repetitions to show whether that one change moves or removes the same signature.
6. Only then propose the narrowest candidate fix.

Timing correlation does not override the focused trace. A diagnostic timing variant is never silently adopted as shipping behavior.

## Verification after an attributed fix

Repeat the identical 10-cold/10-warm matrix on the baseline diagnostic build and fixed build. Then run the unchanged 150-second production soak, all existing performance gates, and Release Readiness. The Android-dependent readiness stage remains a separately reported hardware blocker; this iPhone sprint does not broaden platform scope or waive it.

Required integrity:

- zero failed soak rounds;
- unchanged deterministic result/state hashes;
- protected-state integrity passes;
- no gameplay/authority change;
- no leak or steady-state regression;
- all existing thresholds remain unchanged;
- release build cannot activate the diagnostic.

Post-input acceptance:

- no frame over 100 ms;
- no abnormal first canonical tick;
- target: no interactive frame over 50 ms.

A successful result must either reduce the repeatable startup maximum by at least 50% with no remaining player-visible signature, move the work wholly behind a truthful bounded noninteractive loading state, or establish bounded nonreproduction across the controlled matrix.

## Evidence status

Implemented and locally exercised:

- debug/release activation contract;
- production `Shell._run_soak_perf` integration;
- bounded marker and hitch JSON;
- pre-input/interactivity classification;
- backend and analytics isolation;
- protected-state hashing;
- run-level summary tooling.

The 20-second headless integration run completed one 25-second soak round with zero failed rounds, captured the requested map's first canonical tick, and passed protected-state integrity. It observed 145.572 ms and 119.253 ms frames between requested-map application and presentation, both classified `PRE_INPUT_LOADING`; the first canonical tick was 2.219 ms. These numbers validate marker plumbing only. The summarizer correctly rejects that report as `not_physical_ios` and `headless`.

## Focused renderer-boundary attribution

Diagnostic commit `3615a4d7ff666d43fb353528995f2c620f85a708` added bounded, diagnostic-only renderer-ready, lane-operation, and post-add process-frame markers. The exact clean device build used tree `5ddc2cc411aa025e3e3bb215176eea495e7a184d`, PCK SHA-256 `d6a337127e695945759f10757fca1cab198832902c924908b917703331ebadc6`, and executable SHA-256 `3c14b4b962492b823866b3e773997722a560c332670e0536ff14e7c18325eba7`. Its ignored build manifest is `artifacts/startup_hitch_diagnostic/device_build_variant_renderer_markers/build_manifest.json`.

The accepted physical-iPhone report is `artifacts/startup_hitch_diagnostic/evidence/variant-renderer-markers-trace-01.json`. It ran on iPhone 16 Pro (`iPhone17,1`), iOS 26.5.2, Godot 4.2.2, with a Nominal thermal state. It completed the soak with zero failed rounds, passed protected-state integrity, retained 58 markers and two pre-input hitches, and recorded:

| Observation | Result |
| --- | ---: |
| Maximum rendered frame | 141.916 ms |
| First canonical tick | 2.304 ms |
| Maximum canonical tick | 4.036 ms |
| Interactive hitches | 0 |
| Lane `_ready` boundary | 305.264 ms |
| UnitRenderer `_ready` boundary | 211.456 ms |
| Match added to deferred queue drained | 480.814 ms |
| Lane rebuild 1 / 2 | 0.010 / 0.007 ms |
| Lane `set_model` 1 / 2 | 0.014 / 0.008 ms |
| Lane anchor snapshot 1 | 0.042 ms |
| Lane first `_process` | 0.006 ms |

The matching focused Time Profiler trace is `artifacts/startup_hitch_diagnostic/traces/iphone16pro-time-profiler-renderer-markers-01.trace`; its exported sample table is `artifacts/startup_hitch_diagnostic/traces/iphone16pro-time-profiler-renderer-markers-01-time-profile.xml`. The trace remained Nominal and contains these main-thread intervals:

| Trace interval | Duration | Attribution |
| --- | ---: | --- |
| Engine/application initialization | 1.351683 s | Before diagnostic ownership |
| Match load request through deferred queue | 2.223201 s | Severe main-thread startup hang |
| Final boot-frame envelope | 259.374 ms | GDScript/deferred-call microhang |

The final 259.374 ms interval begins before `arena_ready_completed`, contains `first_lane_activity`, ends at the second post-add process-frame boundary, and is followed by presentation visibility. Of 255 main-thread samples in this interval, 251 ms are under `Main::iteration`, 243 ms under GDScript calls, and 215 ms under `CallQueue::flush`. This establishes CPU/GDScript deferred work as the owner of the remaining frame envelope. `first_lane_activity` is correlational; the measured lane model, anchor, rebuild, and first-process operations are all sub-millisecond and cannot own the 141.916 ms frame.

Symbolicated samples expose two additional synchronous boot targets that must remain separate from the final-frame attribution:

1. Lane `_ready` spends 305.264 ms under ResourceLoader, image decode/conversion, and texture update. `LaneRenderer._load_lane_textures()` obtains `SpriteRegistry`, whose current `_load_manifest()` loops through every sprite and calls `ResourceLoader.load()` eagerly. The narrow controlled variant is to parse and retain manifest metadata/paths, then load and cache only a requested key in `get_tex()`. Explicit bounded prewarm can remain for asset families that genuinely need it.
2. UnitRenderer `_ready` spends 211.456 ms constructing the fixed 400-node presentation pool in `_pool_build()`. A later controlled variant may phase or resize that presentation allocation, but it must guarantee required capacity before interactivity and must not alter authoritative unit state or simulation timing.
3. To narrow the exact deferred owner beyond engine-level GDScript symbols, add bounded markers around individual Arena deferred callbacks and nonessential post-add scans. Move work only after one callback is shown to own the same interval.

### SpriteRegistry on-demand-load experiment

Commit `7a5bf57b0135804d3328d78364bda984686591c8` implemented the controlled SpriteRegistry experiment. Manifest paths and construction metadata remained eagerly parsed and deterministic, while `has_tex()` and `get_tex()` loaded and cached only the requested texture key. Existing atlas regions, slice construction, colorkey/alpha handling, missing-resource behavior, skin cache invalidation, hive prewarm, and public lookup semantics were preserved. A focused smoke test proved that metadata reads load zero textures, one request creates one cache entry, shared-path siblings remain lazy, repeated requests reuse the cached object, skin changes clear loaded entries, and all 88 manifest keys still resolve.

The exact clean device build used tree `d6ff6a3ebf6abd74ca0e65ccd4fdcc23533fc348`, PCK SHA-256 `6bfd958f1d524a92327518564a6f176a91971f2a8e654ee0272debac1d6b2197`, and executable SHA-256 `dfce550c43d527ae4bd8ecb013d2e1a8b75184692f122b159e1f75e20fa8cd7a`. The copied evidence report is `artifacts/startup_hitch_diagnostic/evidence/variant-sprite-lazy-01.json`; it completed one physical iPhone warm diagnostic and one soak round with zero failed rounds, passed protected-state integrity, and recorded no interactive hitch. External thermal/power fields were not captured, so this is a single physical diagnostic comparison rather than a full controlled-matrix result.

| Boundary or outcome | Renderer-marker build | Lazy-load variant | Change |
| --- | ---: | ---: | ---: |
| Lane `_ready` | 305.264 ms | 23.965 ms | -281.299 ms (-92.1%) |
| Hive-ready to UnitRenderer-ready | 211.456 ms | 291.352 ms | +79.896 ms |
| Match added to deferred queue drained | 480.814 ms | 651.883 ms | +171.069 ms |
| Arena presentation visible | 2529.068 ms | 2713.801 ms | +184.733 ms |
| Maximum rendered frame | 141.916 ms | 142.287 ms | +0.371 ms |
| Second retained boot frame | 116.667 ms | 124.973 ms | +8.306 ms |
| First canonical tick | 2.304 ms | 2.018 ms | -0.286 ms |
| Interactive hitches | 0 | 0 | unchanged |

Decision: reject the lazy-load variant as a candidate fix. It proves the 305 ms Lane-ready interval came from eager manifest loading, but it redistributes resource work into UnitRenderer and later deferred startup, delays presentation, and leaves the exact 142 ms signature unchanged. The experiment must remain in history for reproducibility but must not remain enabled at the branch tip or ship.

The next controlled step is bounded instrumentation around individual Arena deferred callbacks and post-add scans inside the 259 ms `CallQueue::flush` interval. That work directly targets the unchanged maximum instead of moving resource loading between startup boundaries.

### Arena deferred-callback attribution

Diagnostic commit `72622b9da20aabe5b3a30bbb73244eb833547a1a` added paired, first-occurrence-only markers around the Arena `_ready` continuation, its six post-add diagnostic scans, all five immediate Arena deferred callbacks, and the camera/canvas/match-flow callbacks that resume across later process frames. The report cap increased from 64 to 96 but remains fixed; the physical report used 91 markers. No callback was moved, removed, or rescheduled, and no authoritative state or gameplay timing changed.

The exact clean device build used tree `6f4db21b3bf5f03fa55d381789526c9cb1eae9b1`, PCK SHA-256 `4c16f6985c92038997d1f1c718af7373979ff71c18a1d51b6fa0a968c6d840ac`, and executable SHA-256 `8352d9514a91a6313d30a9405d002f89c7e4a8295992077239e2ee2796406de7`. Its ignored build manifest is `artifacts/startup_hitch_diagnostic/device_build_variant_arena_deferred/build_manifest.json`, and its ignored physical report is `artifacts/startup_hitch_diagnostic/evidence/variant-arena-deferred-01.json`.

The single warm iPhone run completed one 25-second soak round with zero failed rounds, passed protected-state integrity, and recorded no interactive hitch. The maximum boot frame was 150.000 ms, consistent with the prior 141.916 ms signature rather than an improvement. External thermal and power fields were not captured, so the run is attribution evidence rather than a controlled-matrix timing claim.

| Measured boundary | Duration |
| --- | ---: |
| Arena `_ready` continuation | 25.986 ms |
| Six post-add diagnostic scans combined | 8.559 ms |
| Five immediate Arena deferred callbacks combined | 0.988 ms |
| Deferred camera scan after its frame resume | 1.489 ms |
| Deferred canvas scan after its frame resume | 0.011 ms |
| Deferred match-flow work after its second frame resume | 6.376 ms |
| Unattributed interval after `post_add_first_process_frame_completed` and before the first Arena deferred callback | 213.239 ms |

Decision: the Arena deferred callbacks and diagnostic scans do not own the retained hitch. Every immediate Arena deferred callback completed in less than 1 ms individually, and all six synchronous scans completed before the 213.239 ms interval began. The interval sits ahead of `arena_deferred_in_game_ad_started` in the same process frame, matching deferred work that Shell queued earlier during `_enter_game()`.

The next controlled step is paired instrumentation around Shell `_sync_power_bar_buffer_placement`, `_sync_buff_ui`, `_stabilize_shell_camera_presentation`, and the deferred `Main.start_game` / camera-fit handoff. Move or remove work only after one of those earlier callbacks is shown to own the retained interval.

Not yet claimed:

- repeatability across the full controlled cold/warm matrix;
- an accepted before/after device improvement from a candidate optimization;
- removal of the 259 ms deferred-call microhang;
- 150-second post-fix soak or Release Readiness completion;
- final pass/hold recommendation.

No production threshold, gameplay rule, authority result, or shipping timing has been changed. No public deployment or rollout is part of this sprint.
