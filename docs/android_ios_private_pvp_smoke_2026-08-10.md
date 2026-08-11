# Android/iOS Private PvP Smoke — 2026-08-10

This runbook certifies the private invite/relay path only. It does not authorize
public matchmaking, rank settlement, contests, rewards, purchases, or any other
economic mutation.

## Candidate identity

- Archived phone/backend source: `08c2066` (`Prepare cross-platform PvP release candidates`)
- New phone certification source: `18e0d0c6` (`Expose private PvP certification invites`)
- Live backend build: `08c2066` from the same release-candidate branch
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

## Work-machine handoff

The implementation prerequisite is pushed to
`origin/codex/android-release-candidate-4.7.1` at `18e0d0c6`. That commit:

- adds a `private_pvp_certification` policy that permits only free private 1v1;
- exposes **Create Invite**, the invite-code field, and **Join** in
  certification exports;
- suppresses automatic Quick Match so host and joiner roles are controlled;
- adds a separate **iOS Private PvP Certification** preset;
- enables the feature on **Android Release Device** only, leaving the Android
  store AAB and ordinary iOS preset unchanged; and
- adds `tools/private_pvp_certification_ui_smoke_test.gd`.

Validation completed before handoff:

- private certification UI smoke: PASS;
- live Render create/join/intent/leave relay smoke: PASS;
- release guard against unsafe/fake multiplayer: PASS;
- durable-public 1v1 isolation smoke: PASS; and
- 1v1 map-contract smoke: PASS.

The home Mac cannot produce the signed candidates. It has Godot 4.2.2 and only
4.2.2 export templates, no Android SDK, and no Android release-keystore
environment. Its available Apple Development identity is team `GP77ZSW359`,
while this project is configured for team `SH6675DXQ5`. The paired iPhone still
has the older `0.1.1` app, and the Android phone was not visible through ADB.

Resume on the configured office signing machine:

```sh
git switch codex/android-release-candidate-4.7.1
git pull --ff-only
git status --short --branch

curl -fsS https://sf-zr2m.onrender.com/v1/health
scripts/dev/export_android_release_candidate.sh

mkdir -p artifacts/ios/certification
"${GODOT_BIN}" --headless --path . \
  --export-debug "iOS Private PvP Certification" \
  artifacts/ios/certification/swarmfront-private-pvp.xcodeproj
```

Before installation, verify that the source contains `18e0d0c6`, Godot and its
export templates are 4.7.1, the Android signing variables resolve without
printing their values, and the Apple signing identity covers `SH6675DXQ5`.
Install the new APK with the command above, run the generated iOS Xcode project
on the paired iPhone, and execute Cases A through G. Do not reuse either
archived `08c2066` phone artifact because neither exposes the controlled invite
UI.

## Current rollout boundary

As of 2026-08-10, build `08c2066` is live on both the isolated certification VS
service and the phone-facing `https://sf-zr2m.onrender.com` service. The private
create/join relay smoke passes on both. Production reports all public, rank,
contest, reward, Crucible-settlement, and economy-mutation flags disabled.

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
- The two-physical-device matrix above remains outstanding.
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
