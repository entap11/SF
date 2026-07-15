# Buff Targeting Loop 5 — iPhone Device Preparation and Evidence Plan

Date: 2026-07-15

Automated-hardening checkpoint: `256b13afbd4c7299c95d1967c5ae58e522c10099`

Checkpoint message: `test: add buff targeting Loop 5 hardening evidence`

Rollout status: **on hold**

Loop 5 status: **OPEN — automated hardening and device preparation are complete; physical-device evidence and the rollout recommendation remain pending**

Production gate: `const MATCH_BUFF_TARGETING_ENABLED: bool = false`

## Preparation boundary

The Xcode project is exported to the untracked `artifacts/` tree. The commit-isolated debug app at `b0b6880eb1c6ca1841e148fca06f97a9d7bb5345` was signed, installed, and launched on the connected iPhone. Nothing was pushed, deployed, or used to enable rollout. The production gate remained false.

The device harness uses the production Shell, buff strips, Arena controllers, presentation controllers, command bridge, and canonical-outcome bridge. It changes only the runtime decision that exposes those existing production components in a debug build. It does not mutate OpsState/SimState, bypass command validation, synthesize canonical outcomes, or create a second gameplay state.

The debug override is fail-closed:

- `--buff-targeting-device-harness` is honored only when `OS.is_debug_build()` is true.
- `--buff-targeting-device-heavy-fixture` is honored only when `OS.is_debug_build()` is true, and the fixture has its own release-build refusal.
- A release build ignores both arguments while the production constant is false.
- The override does not read environment variables, OpsConfig, remote configuration, or a persisted setting.
- No in-app control exposes the override.

The harness scripts can remain physically present in an exported release resource pack, but they are inert there: Shell requires the production constant or a debug build with the exact argument, and the heavy fixture independently refuses non-debug execution. The smoke test exercises the release decision with `is_debug_build=false`. This is the approved “inert in release exports” behavior; the plan does not claim the scripts are absent from the pack.

Automated contract coverage: `tools/buff_targeting_device_harness_smoke_test.gd` proves debug enablement, release inertness, the unchanged production constant, the allowed role set, production-controller use, the 64-lane/640-segment dimensions, and no more than one geometry rebuild in a rendered frame.

## Prepared build inputs

- Godot: `4.2.stable.official.46dc27791`
- iOS export template: installed for Godot 4.2 stable
- Xcode: 26.3 (17C529)
- `devicectl`: 506.7
- Project: `artifacts/buff_targeting_loop5_device/SwarmfrontLoop5.xcodeproj`
- Unsigned compile output: `artifacts/buff_targeting_loop5_device/DerivedData/Build/Products/Debug-iphoneos/SwarmfrontLoop5.app`
- Commit-isolated signed output: `artifacts/buff_targeting_loop5_device/b0b6880eb1c6ca1841e148fca06f97a9d7bb5345/SignedDerivedData/Build/Products/Debug-iphoneos/SwarmfrontLoop5.app`
- Scheme and target: `SwarmfrontLoop5`
- Product: `SwarmfrontLoop5.app`
- Bundle identifier: `com.matthew.swarmfront`
- Export team: `SH6675DXQ5`
- Connected hardware: iPhone 16 Pro, iOS 26.5
- Xcode destination UDID: `00008140-000614482E00401C`
- CoreDevice identifier: `B8F36805-35EE-5AC8-B9A7-4944062B98F7`
- Target family: iPhone and iPad (`TARGETED_DEVICE_FAMILY=1,2`)

The signing audit established `SH6675DXQ5` as the intended Swarmfront team. The committed export preset has used that team with `com.matthew.swarmfront` since its introduction; Xcode's configured individual team matches it; the installed development profile authorizes `SH6675DXQ5.com.matthew.swarmfront` and includes the connected iPhone; and the development certificate's signed subject has `OU=SH6675DXQ5`. The `GP77ZSW359` suffix displayed in the Keychain identity label is not the certificate's team identifier.

The commit-isolated generic iOS build succeeded using command-line automatic signing with the existing local profile. No team, bundle identifier, Godot export preset, or generated Xcode project setting was rewritten. `codesign --verify --deep --strict` passes, and the signed entitlements report:

- `application-identifier=SH6675DXQ5.com.matthew.swarmfront`
- `com.apple.developer.team-identifier=SH6675DXQ5`
- `get-task-allow=true`

The first installation attempt stopped while enabling developer disk image services because the iPhone was locked (`kAMDMobileImageMounterDeviceLocked`). After the phone was unlocked, the exact signed app installed successfully as `com.matthew.swarmfront`.

## First physical pass and remediation

The first corrected physical harness run proved attribution and release-gate isolation, but it did not produce targeting evidence. It found:

- The original documented launch omitted Godot's standalone `--` user-argument separator. That run never enabled the harness. The commands below are corrected.
- The corrected process printed the harness start marker and periodic attributed JSON, but the persisted profile had no usable buff loadout. No pointer movement, receipt, canonical outcome, or latency sample occurred.
- Phone-scale match and diagnostic text were not acceptably readable.
- Three decorative text shaders failed on iOS because stage-only built-ins were referenced from helper functions.
- The inactive CTF sample reached p50 `31.67 ms`, p95 `43.07 ms`, p99 `51.63 ms`, and maximum `143.01 ms` over approximately 135 seconds. This blocks rollout and requires a remediated-build retest with the added CPU/render counters.
- The inactive presentation controller set remained stable at three nodes with zero measured node or material growth; that is not active-targeting evidence.

The remediation keeps the production gate false, supplies match-scoped evidence charges from Arena without changing persisted inventory, fails loudly if the expected strip is absent, enlarges targeting controls/treatments for the phone canvas, removes the iOS shader-helper incompatibility, and reduces collector work to a 4 Hz diagnostic cadence. None of these results counts as passed physical evidence until the rebuilt app is rerun.

The safe compile-only verification command already run was:

```sh
xcodebuild \
  -project artifacts/buff_targeting_loop5_device/SwarmfrontLoop5.xcodeproj \
  -scheme SwarmfrontLoop5 \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath artifacts/buff_targeting_loop5_device/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

It completed successfully without provisioning or device access. Do not attempt to install that unsigned output; the approved signed build command below must replace it first.

The compile reported existing export warnings for deprecated launch images and empty camera, microphone, and photo-library usage-description keys. They do not affect the debug-only targeting route, but the plist keys should be removed or populated before a release build, according to the app's actual capability use.

## Exact commands

Every installable evidence artifact must be rebuilt from a clean detached worktree at the focused evidence-harness commit. Record `git rev-parse HEAD`, `git status --porcelain`, the PCK SHA-256, the executable SHA-256, the Xcode project hash, and signing state in a build manifest. The working tree used for the build must report no changes.

The reproducible export command is:

```sh
EVIDENCE_COMMIT=<focused-evidence-harness-commit-sha>
EVIDENCE_WORKTREE=/tmp/sf-loop5-device-build-$EVIDENCE_COMMIT

git worktree add --detach "$EVIDENCE_WORKTREE" "$EVIDENCE_COMMIT"
godot --headless \
  --path "$EVIDENCE_WORKTREE" \
  --export-debug iOS \
  /Users/matthewballou/SideProjects/SF/project/artifacts/buff_targeting_loop5_device/SwarmfrontLoop5.xcodeproj
```

The successful commit-isolated signing command was:

```sh
ROOT=/Users/matthewballou/SideProjects/SF/project
EVIDENCE_COMMIT=b0b6880eb1c6ca1841e148fca06f97a9d7bb5345
PROJECT="$ROOT/artifacts/buff_targeting_loop5_device/$EVIDENCE_COMMIT/SwarmfrontLoop5.xcodeproj"
DERIVED="$ROOT/artifacts/buff_targeting_loop5_device/$EVIDENCE_COMMIT/SignedDerivedData"

xcodebuild \
  -project "$PROJECT" \
  -scheme SwarmfrontLoop5 \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM=SH6675DXQ5 \
  CODE_SIGN_STYLE=Automatic \
  'CODE_SIGN_IDENTITY=Apple Development' \
  build
```

No `-allowProvisioningUpdates` option was needed or used. The existing local certificate and Xcode-managed development profile were sufficient.

The exact installation retry command, after the phone is unlocked and awake, is:

```sh
xcrun devicectl device install app \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  /Users/matthewballou/SideProjects/SF/project/artifacts/buff_targeting_loop5_device/b0b6880eb1c6ca1841e148fca06f97a9d7bb5345/SignedDerivedData/Build/Products/Debug-iphoneos/SwarmfrontLoop5.app
```

Launch a production-component evidence role with:

```sh
xcrun devicectl device process launch \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --console \
  --terminate-existing \
  com.matthew.swarmfront \
  -- \
  --buff-targeting-device-harness \
  --buff-targeting-device-role=local \
  --buff-targeting-device-build=<focused-evidence-harness-commit-sha>
```

Replace `local` with exactly one of `pvp_host`, `pvp_guest`, `async_first`, or `async_second` for the other evidence buckets. Use a fresh app process for every role so the bounded latency window and frame window cannot mix roles.

Launch the heavy fixture with:

```sh
xcrun devicectl device process launch \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --console \
  --terminate-existing \
  com.matthew.swarmfront \
  -- \
  --buff-targeting-device-heavy-fixture \
  --buff-targeting-device-build=<focused-evidence-harness-commit-sha>
```

Each run prints periodic single-line JSON prefixed by `BUFF_TARGETING_DEVICE_EVIDENCE` or `BUFF_TARGETING_DEVICE_HEAVY_EVIDENCE` and writes the latest snapshot under `user://`. Console capture is the primary evidence path. If a file copy is needed, use the app data container after confirming the displayed path with `devicectl`:

The standalone `--` after the bundle identifier is mandatory. Godot exposes only arguments after that separator through `OS.get_cmdline_user_args()`. A production-component run is invalid unless the console prints `BUFF_TARGETING_DEVICE_HARNESS_STARTED` followed, once the Arena exists, by `BUFF_TARGETING_DEVICE_HARNESS_READY`. `BUFF_TARGETING_DEVICE_HARNESS_BLOCKED` is a fail-loud result; do not continue the matrix on that process.

The debug evidence session supplies a bounded, match-scoped loadout containing one hive, one lane, and one global buff. Arena—the simulation owner—creates and commits those ephemeral evidence charges through the existing resolver, reservation, canonical command, effect, and outcome paths. The session never grants, revokes, consumes, or rewrites persisted ProfileManager inventory or loadouts. Release builds cannot create the session.

```sh
xcrun devicectl device copy from \
  --device B8F36805-35EE-5AC8-B9A7-4944062B98F7 \
  --domain-type appDataContainer \
  --domain-identifier com.matthew.swarmfront \
  --source Documents/buff_targeting_device_evidence_local.json \
  --destination /Users/matthewballou/SideProjects/SF/project/artifacts/buff_targeting_loop5_device/evidence/
```

## Production-component hands-on matrix

Run each target type through the real player buff strip and release flow:

- Hive, lane, and global buffs.
- Normal layout, crowded layout, screen edge, and camera motion while the finger is stationary.
- Slow thumb movement, fast movement followed by immediate release, nearby candidates, and lane crossings.
- Valid release, invalid release, snap-back, cancellation, and release after a candidate becomes stale.
- App background, foreground return, match exit, scene replacement, and new-match cleanup.
- Async first use, second use, and third-use rejection.
- PvP host and guest canonical success/rejection outcomes through the real event bridge.

For every case record pass/fail for:

- The stable target always agrees with the visible preview.
- Invalid or rejected activation consumes nothing.
- Valid activation consumes exactly once.
- No duplicate command or confirmation effect occurs.
- No halo, lane glow, overlay, snap-back tween, or canonical confirmation remains stuck.
- Captured touch produces no lane drawing, hive command, camera movement, or unrelated HUD activation.
- Backgrounding or scene replacement cannot cause a late flash from an expired/old presentation receipt.
- Async behavior is exactly use one accepted, use two accepted, use three rejected.
- Host and guest receive the correct canonical outcome without handshake, hash, or replay regression.

Capture a screen recording for each target family and retain console JSON for each role. Include at least one slow acquisition, one fast release, one invalid snap-back, one moving-camera case, one background/return case, and one complete cleanup frame.

## Latency evidence

Collect at least 30 successful canonical samples per applicable role; 50 is preferred:

| Role | Launch role | Minimum samples | Required report |
|---|---|---:|---|
| Local/debug authoritative | `local` | 30 | min, p50, p95, max, count |
| PvP host | `pvp_host` | 30 | min, p50, p95, max, count |
| PvP guest | `pvp_guest` | 30 | min, p50, p95, max, count |
| Async first use | `async_first` | 30 | min, p50, p95, max, count |
| Async second use | `async_second` | 30 | min, p50, p95, max, count |

The collector also reports p99 and receipt handled-reason counts. A role is not complete if successful outcomes, rejections, expired receipts, or multiple network roles are mixed into one process. Preserve raw samples/console output as well as the summary. Do not add pending presentation unless physical observation plus measured latency demonstrates a perceptible need.

## Heavy presentation fixture

Run the debug-only fixture on the iPhone for at least two minutes after warm-up while continuously dragging across lanes and allowing its synthetic camera/canvas motion to run.

Required evidence:

- 64 lanes and 640 rendered segments are reported.
- A screen recording shows no visible hitch during continuous camera motion and target acquisition.
- Frame time is reported as min, p50, p95, p99, max, and sample count.
- `maximum_geometry_rebuilds_per_frame` is at most one.
- Stable target acquisition continues while the transform changes.
- Node and unique-material baseline/current/maximum counts show zero steady-state growth after warm-up.

Any visible hitch, target instability, rebuild count above one in a rendered frame, or sustained node/material growth blocks rollout regardless of the average CPU microbenchmark.

## Tablet and platform scope

The current generated target supports iPad as well as iPhone. If iPad is in the supported beta set, physical iPad readability, cleanup, and frame-pacing sign-off remains mandatory before production-gate approval. If the beta is explicitly narrowed to iPhone, record that scope decision in the final evidence. Android hardware is a blocker only if Android is included in the current release scope.

## Loop 5 exit review

Do not turn on the production gate until review confirms:

- zero incorrect stable targets;
- zero accidental consumption;
- zero duplicate activations;
- zero stale or stuck presentation;
- exact Async 1/2/3 behavior;
- correct host and guest canonical outcomes;
- no handshake/hash/replay regression;
- acceptable physical-device frame pacing;
- separate real-role latency evidence;
- physical-device visual/readability sign-off; and
- physical tablet sign-off if tablets remain supported.

This preparation does not claim any physical-device result or Loop 5 completion. Loop 5 remains open until the isolated, signed evidence build completes the matrix and an evidence-based rollout recommendation is reviewed.
