# Android/iOS Private PvP Smoke — 2026-08-10

This runbook certifies the private invite/relay path only. It does not authorize
public matchmaking, rank settlement, contests, rewards, purchases, or any other
economic mutation.

## Physical-device reconnect result — 2026-08-12

The core reconnect acceptance path passed on Android and iPhone. Both players
received the shared three-second restart countdown and rejoined the same match
successfully. A small host/guest timing difference remains visible and should be
tightened in a later synchronization pass, but it is not blocking this private
reconnect milestone.

The device pass also found that disconnect-strike guidance was absent from the
shared restart countdown or too small to read. The client overlay now uses the
relay-owned strike count and presents:

- a larger waiting-player countdown inside the reconnect win condition;
- the opponent's current `1/3` or `2/3` disconnect count and remaining chances;
  and
- the returning player's own count and remaining chances throughout match
  verification and the shared three-second restart countdown.

Fresh certification clients containing this copy/layout change were built,
installed in place, and launched on both phones on 2026-08-12:

- Android device APK SHA-256
  `f41b44ffcf54ee1b015bcad16f795b2b1220ca50292ae32013caa7dad15fccb9`;
  and
- iOS PCK SHA-256
  `7906083c33ebaf59cdab7f5561a3668600541969033a8e6c91842b9426de801e`.

The new presentation still needs an in-match visual check on both platforms.
Full grace expiry and the third-disconnect immediate forfeit remain
automated-smoke certified but are not recorded here as physical-device passes.

## Night handoff — exact stop point (2026-08-11)

The active repository is the Swarmfront project (`entap11/SF`), not the
cinematic repository. Continue on branch
`codex/android-release-candidate-4.7.1`. The implementation under test is
commit `36614cc` (`Synchronize PvP reconnect restart`), which is pushed to
origin and deployed to the phone-facing Render service. After pulling, the
handoff-document commit will be newer than `36614cc`; do not reset back to it.

Live health was verified immediately after deployment:

- endpoint: `https://sf-zr2m.onrender.com/v1/health`
- live backend build: `36614cc5ac93587e12dd870935d1fef6e584ae71`
- all public matchmaking, rank, contest, reward, settlement, and economy
  mutation flags: `false`
- private certification continues to use the deliberately isolated in-memory
  relay; this deploy does not make PvP public

The latest physical-device builds were exported from `36614cc` with Godot
4.7.1, signed, and installed on both test phones:

- Android `com.entap.swarmfront`, device APK SHA-256
  `f41569faecafd7aec0d2df41fc9cc3f3ad6e89d1780945405b2775ee7e69bd4e`
- iOS `com.matthew.swarmfront`, PCK SHA-256
  `746be8a75867fe2123890b7c5e7ec77027978d2c9207500a98da8cfd32c4a67a`
- Android installed and launched successfully on the connected Samsung
  `SM_A156U` (`R5CY144JM9F`)
- iOS installed successfully on the paired iPhone 16 Pro
  (`B8F36805-35EE-5AC8-B9A7-4944062B98F7`); its final remote launch was denied
  only because the phone auto-locked, so unlock it and open Swarmfront

### What has already passed on the phones

- Private invite creation and joining work with Android as host and iPhone as
  joiner, and with iPhone as host and Android as joiner.
- The loading barrier, minimum seven-second loading/ad window, arena entry, and
  opening countdown now synchronize correctly.
- The test ad is visible. Its placement still needs visual polish, but the
  prior accidental external-browser behavior is fixed.
- Ordinary lane, power-bar, swarm, and match state replication appeared closely
  synchronized. One observed swarm arrived roughly 250 ms later on the peer,
  which was noticeable only while watching both screens side by side.
- Both host directions completed smoothly. Post-match return and menu hero
  recap differences were addressed during the pass and should remain in the
  regression matrix.

### Original unfinished test

The authoritative reconnect implementation is built, deployed, and installed,
and the core return-inside-grace behavior was exercised successfully on both
phones on 2026-08-12. Retain the matrix below for regression coverage and for
the timeout/third-strike rows that still need physical-device evidence.

1. Pull this branch, confirm a clean tree, warm `/v1/health`, and verify its
   `build` is `36614cc5ac93587e12dd870935d1fef6e584ae71` or a deliberately newer
   handoff-only build.
2. Unlock and open the iPhone app; confirm Android is running the freshly
   installed app. Create a private free 1v1 invite and enter the Arena.
3. Interrupt one phone with an incoming call or actual app backgrounding. Mere
   focus loss is intentionally not a disconnect. The other phone should freeze
   promptly, show that the opponent disconnected, and display the server-owned
   60-second grace countdown.
4. Return inside 60 seconds. Both phones should first show **VERIFYING MATCH**.
   The relay must not schedule the restart until both report the exact same
   authoritative checkpoint tick.
5. Once aligned, both phones should show the same **MATCH RESUMES IN 3**
   countdown. Controls must remain blocked and then unlock together at the
   relay-scheduled timestamp. Confirm lane, power, swarm, timer, and ownership
   state agree immediately after restart.
6. Repeat with the other platform interrupted, then test forced Wi-Fi loss,
   expiry of the full 60-second grace period, and three disconnects. Returns
   one and two must warn 1/3 and 2/3; the third must forfeit immediately.
7. Retain Android logcat, iPhone device logs, invite/session IDs, and health
   snapshots under a dated ignored `artifacts/device-cert/` directory.

The reconnect path intentionally moves the returning phone forward to the
waiting phone's frozen OpsState checkpoint. It does not rewind the waiting
phone: doing so could erase valid commands accepted between the interruption
and relay detection. Explicit background notification should make that window
small; a silent network disappearance can take up to the 2.5-second stale
threshold (about 25 simulation ticks) to detect. Historical authority snapshots
make a future rollback design possible if physical testing proves it necessary,
but rollback is not part of this certification build.

Separately, Android lane creation felt more finicky than iPhone, with more
intended gestures failing to instance a lane. Do not casually tune gameplay
rules or simulation state to mask it. After reconnect certification, add input
telemetry and compare Android touch acquisition/release, hit targets, drag
thresholds, and cancellation paths against iOS before adjusting platform input
constants.

## Candidate identity

- Current phone/backend source: `36614cc` (`Synchronize PvP reconnect restart`)
- Archived phone/backend source: `08c2066` (`Prepare cross-platform PvP release candidates`)
- New phone certification source: `18e0d0c6` (`Expose private PvP certification invites`)
- Live backend build: `36614cc5ac93587e12dd870935d1fef6e584ae71`
- Android application ID: `com.entap.swarmfront`
- iOS application ID: `com.matthew.swarmfront`
- iOS signing team: `SH6675DXQ5`

Archived Android device APK (pre-certification UI):

`artifacts/android/current/release-2abf9b2/swarmfront-0.1.2-rc1-device.apk`

SHA-256: `d485a2b92abf9ec3de431df87bc8694bedcb8b24370787a06cbd234ec72cc8d8`

Archived iOS device app (pre-certification UI):

`artifacts/ios/current/DerivedData-device/Build/Products/Debug-iphoneos/swarmfront-2abf9b2.app`

- executable SHA-256: `45561eb337f917f97199ceca26e2586989041171a84935bfba631d0d3b12fe4c`
- PCK SHA-256: `f46ae659e77e953f6128879c28554abeac246ade1e913bf81309bbd7bf74c3e9`

The artifact filenames retain the pre-commit short hash, but their source tree
matches `08c2066`; that commit records the packaging/resource fixes present at
build time.

## Install and preflight

New physical-device candidates must be exported with the
`private_pvp_certification` feature. Use the **Android Release Device** and
**iOS Private PvP Certification** presets; the archived `08c2066` artifacts
listed above predate the certification UI and must not be used for the
controlled matrix. The feature exposes **Create Invite** and the invite-code
**Join** row only in these certification builds. It also keeps the lobby from
automatically entering Quick Match. Store/public builds omit the feature and
retain the rollout gates.

Export the candidates on the signing machine with Godot 4.7.1:

```sh
scripts/dev/export_android_release_candidate.sh
mkdir -p artifacts/ios/certification
"${GODOT_BIN}" --headless --path . \
  --export-debug "iOS Private PvP Certification" \
  artifacts/ios/certification/swarmfront-private-pvp.xcodeproj
```

The Android script also produces the store AAB and emulator APK, but only the
**Android Release Device** APK carries the certification feature. The AAB and
ordinary iOS preset remain unchanged and must not expose the private controls.

1. Make both phones available for the test. They do not need to be in the same
   room or on the same network: the relay test traverses Render. Connecting
   both to the Mac merely makes installation and log collection easier.
2. Verify that the Render health endpoint is warm before opening either app:

   `curl -fsS https://sf-zr2m.onrender.com/v1/health`
3. Install Android:

   `adb install -r artifacts/android/release/swarmfront-0.1.2-rc1-device.apk`
4. Export **iOS Private PvP Certification**, open the generated Xcode project,
   and run its Swarmfront target on the connected iPhone. Do not use the
   ordinary **iOS** preset for this matrix.
5. Confirm both clients reach the menu without a timeout or loading-screen
   stall.

## Controlled handshake

1. On the designated host, open the free Human 1V1 lobby and tap
   **Create Invite**.
2. Read the displayed `VS...` invite code.
3. On the other phone, open the same free Human 1V1 lobby, enter that code,
   and tap **Join**.
4. Confirm both phones show the opponent and enter the same Arena. Do not use
   Quick Match for the private certification rows.
5. Leave the session cleanly, then repeat with the phone roles reversed.

## Required two-phone matrix

Run every row and retain both device logs.

| Case | Host | Joiner | Required result |
| --- | --- | --- | --- |
| A | Android | iPhone | Invite creates, iPhone joins, both enter Arena |
| B | iPhone | Android | Invite creates, Android joins, both enter Arena |
| C | Android | iPhone | Each side sends intents; both clients agree on state/hash |
| D | iPhone | Android | Each side sends intents; both clients agree on state/hash |
| E | Android | iPhone | Background/foreground each app; session resumes or fails cleanly |
| F | iPhone | Android | Brief Wi-Fi interruption; reconnect succeeds inside grace window |
| G | Either | Either | Stay offline past grace window; both clients reach an explicit terminal state |

For Cases C and D, exercise spawning, lane interaction, capture/power updates,
and a completed match. There must be no client-only ownership or gameplay state
change: both sides must derive the same result from authoritative state.

## Pass criteria and evidence

- No create/join request times out after the backend has been warmed.
- Inputs from each platform are visible on the other exactly once and in order.
- No divergent state hash, duplicate intent, stuck countdown, or ghost session.
- Reconnect within the configured grace period restores the same session.
- Reconnect after the grace period fails closed with a clear UI state.
- After both clients leave, `/v1/health` returns zero live test sessions and no
  stranded queue entry.
- Save Android `adb logcat`, the Xcode device console, health snapshots, and the
  invite/session IDs under a dated, ignored `artifacts/device-cert/` directory.

Any failed row keeps the private phone certification open. Public or economic
features remain disabled regardless of this matrix's result.

## 2026-08-11 device findings and reconnect policy

Android and iPhone now pass the controlled invite flow in both host directions.
The synchronized loading barrier/countdown and ordinary gameplay replication are
visually aligned on both devices. A real iPhone call exposed the remaining
lifecycle gap: iOS suspended the iPhone process while Android continued the
simulation and completed the match.

The certification relay now owns match presence and reconnect adjudication:

- focus loss by itself does not pause or count as a disconnect;
- an actual app-background notification, or 2.5 seconds without relay polling,
  freezes gameplay intents and starts a server-timed 60-second grace period;
- the waiting player sees the opponent-disconnected countdown;
- the waiting client uploads an OpsState authority checkpoint, the returning
  client restores it, and the relay requires both clients to report that exact
  checkpoint tick before scheduling a shared three-second restart countdown;
- successful returns warn at disconnect 1/3 and 2/3;
- disconnect 3/3 is an immediate forfeit; and
- expiry of the 60-second grace awards the match to the connected player.

Physical-device certification is still required for: incoming-call return,
manual app switching on each platform, a forced Wi-Fi interruption, the full
60-second timeout, and the 3/3 forfeit. A suspended iOS process cannot continue
executing the simulation; pausing the peer and restoring one shared checkpoint
is the deterministic behavior for that platform state.

The Android client also felt less reliable when instancing lanes, with more
intended gestures failing to create a lane than on iPhone. Treat Android touch
targeting/gesture telemetry and tuning as a separate follow-up; no gameplay or
input thresholds were changed during the reconnect pass.

## Work-machine handoff

The full private-PvP implementation through synchronized reconnect is pushed to
`origin/codex/android-release-candidate-4.7.1`. On any machine, resume with:

```sh
git switch codex/android-release-candidate-4.7.1
git pull --ff-only
git status --short --branch

curl -fsS https://sf-zr2m.onrender.com/v1/health
```

The home machine should use this document to understand state and can inspect or
change code, but signed phone rebuilds still belong on the configured signing
machine unless its Godot 4.7.1, Android SDK/keystore, and Apple team
`SH6675DXQ5` environment have been reproduced. The current phones already have
the `36614cc` candidates, so no rebuild is required for the first reconnect
test. Execute the unfinished test above before making unrelated changes.

Automated validation completed at `36614cc`:

- VS service TypeScript build and relay lifecycle smoke: PASS, including a
  rejected mismatched-tick resume acknowledgement and a minimum three-second
  scheduled restart;
- `pvp_reconnect_lifecycle_smoke_test.gd`: PASS;
- `arena_lifecycle_pause_source_smoke_test.gd`: PASS;
- `vs_swarm_replication_smoke_test.gd`: PASS; and
- `human_pvp_boot_smoke_test.gd`: PASS.

Known Godot NUL-import, custom-sampler, and shutdown leak/resource warnings were
present before this change and did not fail these smokes.

## Current rollout boundary

As of 2026-08-11, build `36614cc5ac93587e12dd870935d1fef6e584ae71` is
live on the phone-facing `https://sf-zr2m.onrender.com` service. The private
create/join relay and reconnect lifecycle smokes pass. Production reports all
public, rank, contest, reward, Crucible-settlement, and economy-mutation flags
disabled.

The phone-facing service still reports the Render `free` instance type. Render
accepted `/health` as its health-check path but returned HTTP 500 for the
Free-to-Starter transition through both CLI 2.21 and 2.22. Until that account or
billing transition is completed in the Render dashboard, warm `/health` before
a test because the service may sleep while idle.

Private relay testing is intentionally narrower than a public launch:

- Production uses the legacy in-memory relay path; durable public 1v1, trusted
  match verification, and authenticated public 1v1 are disabled there.
- The iOS build is Apple Development signed and suitable for a connected-device
  test, not App Store distribution.
- The iOS secure-credential plugin has source in the repository but has not yet
  been rebuilt and export-integrated against Godot 4.7.1. Android's corresponding
  native plugin is integrated.
- Invite/gameplay Cases A through D have passed informally on the physical
  devices; reconnect/timeout/forfeit Cases E through G remain outstanding and
  must be captured with logs before certification closes.
- Staging certification phases P6 and P7 remain BLOCKED/HOLD in
  `docs/architecture/public_modes/staging-certification-evidence.md`.

Before enabling public play, complete the device matrix, integrate and certify
the iOS credential bridge, provision production durable storage and service
identity/verification dependencies, run restart/reconnect and authority-failure
drills on that production topology, complete observability and rollback
evidence, produce store-distribution signed builds, and stage feature flags from
authenticated free 1v1 outward. Rank/economy/contest mutations require their
own settlement, reconciliation, security, compliance, and operational sign-off;
they must not be enabled as a consequence of private PvP passing.
