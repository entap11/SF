# Android/iOS Private PvP Smoke — 2026-08-10

This runbook certifies the private invite/relay path only. It does not authorize
public matchmaking, rank settlement, contests, rewards, purchases, or any other
economic mutation.

## Candidate identity

- Source commit: `08c2066` (`Prepare cross-platform PvP release candidates`)
- Backend contract/build source: the same branch and commit
- Android application ID: `com.entap.swarmfront`
- iOS application ID: `com.matthew.swarmfront`
- iOS signing team: `SH6675DXQ5`

Android device APK:

`artifacts/android/current/release-2abf9b2/swarmfront-0.1.2-rc1-device.apk`

SHA-256: `d485a2b92abf9ec3de431df87bc8694bedcb8b24370787a06cbd234ec72cc8d8`

iOS device app:

`artifacts/ios/current/DerivedData-device/Build/Products/Debug-iphoneos/swarmfront-2abf9b2.app`

- executable SHA-256: `45561eb337f917f97199ceca26e2586989041171a84935bfba631d0d3b12fe4c`
- PCK SHA-256: `f46ae659e77e953f6128879c28554abeac246ade1e913bf81309bbd7bf74c3e9`

The artifact filenames retain the pre-commit short hash, but their source tree
matches `08c2066`; that commit records the packaging/resource fixes present at
build time.

## Install and preflight

1. Make both phones available for the test. They do not need to be in the same
   room or on the same network: the relay test traverses Render. Connecting
   both to the Mac merely makes installation and log collection easier.
2. Verify that the Render health endpoint is warm before opening either app:

   `curl -fsS https://sf-zr2m.onrender.com/v1/health`
3. Install Android:

   `adb install -r artifacts/android/current/release-2abf9b2/swarmfront-0.1.2-rc1-device.apk`
4. Open the generated Xcode project and run the `swarmfront-2abf9b2` target on
   the connected iPhone, or install the signed `.app` with Xcode's Devices and
   Simulators window.
5. Confirm both clients reach the menu without a timeout or loading-screen
   stall.

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
