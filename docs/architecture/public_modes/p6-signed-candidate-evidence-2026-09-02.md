# P6 Signed Candidate Evidence — 2026-09-02

Status: **PARTIALLY ADVANCED — P6 remains BLOCKED**

This supplement records new build evidence against the current game source. It
does not replace the multi-device P6 acceptance matrix and does not authorize a
public-mode rollout.

## Candidate identity

- Source commit: `23c8961` (`Remove obsolete economy buff authority`)
- Marketing version: `0.1.1`
- Build number: `2026090201`
- Godot editor used for export: `4.2.stable.official.46dc27791`
- Xcode: `26.3` (`17C529`)
- iOS engine template: custom Godot 4.2.2 debug/release archive containing the
  documented deferred-audio-start and Xcode 26 compatibility changes
- Engine-template SHA-256:
  `57a7cfee4844fd2ddf6867d14f6ddc20953133576173481bb3328bf4e2f973b`

The export used the exact local template archive above. Generated projects,
archives, signing material, and the IPA remain under the ignored `artifacts/`
tree; private signing and device identifiers are not recorded here.

## Build and signature result

Godot exported the iOS Xcode project successfully. A generic physical-iOS
Debug build succeeded with automatic development signing. A Release archive
then succeeded after explicitly selecting the Apple Development identity to
resolve the generated project's automatic-signing/Distribution-identity
conflict. Xcode exported a development IPA successfully.

| Artifact | SHA-256 |
| --- | --- |
| Release development IPA | `894eddfb4c483ab531cfd3f8de7972e976a6fb40af79357c65ea675784f20355` |
| Release arm64 executable | `da74055c26480629678c9a2037dfbe56e25897bbfa8114f0f822f0cdb6e6ed1d` |
| Exported PCK | `4fcae45e17916a8e2a446a5025049d9dcb48c486559916a135b0abf31d00bdd8` |

`codesign --verify --deep --strict` passed for both the generic Debug app and
the archived Release app. The development provisioning profile covers one
registered device and expires March 2, 2027.

This is a signed development candidate, not an App Store Connect/TestFlight
distribution artifact. Distribution signing still needs a clean archive/export
configuration rather than the command-line development-identity override.

## Verification performed before export

The full fast Release Readiness gate passed on the candidate source:

- MVP smoke suite: `26 passed, 0 failed`
- Fast configuration contract matrix: `15 passed, 0 failed, 13 skipped`
- Boot/runtime matrix: `8 passed, 0 failed, 5 skipped`
- Soak matrix: `3 passed, 0 failed`
- Final result: `RELEASE_READINESS_PASS`

The known Godot teardown/ObjectDB diagnostics remain non-fatal. No authoritative
gameplay rule or public feature gate was changed for this build.

## Physical-device result

One paired physical iPhone was visible and available. The first installation
attempt could not mount the developer disk image while the device was locked
(`kAMDMobileImageMounterDeviceLocked`). The CoreDevice command returned process
exit code zero while printing that error, so acceptance must parse the operation
result and may not rely on the exit code alone.

After the phone was unlocked, the exact archived Release app installed
successfully. It launched in the foreground by bundle identifier and remained
present in the physical device process list after 15 seconds. This proves the
candidate can install, launch, and remain alive for a short startup observation;
it is not a gameplay, interaction, thermal, interruption, or soak result.

No Android device is attached. The Android SDK and `adb` are installed, but no
Java runtime is currently available. No physical iPad or second iOS/Android
device was available.

## Decision and remaining work

The former “no signed IPA” and local install/launch blockers are resolved for a
development candidate. P6 remains blocked because interaction and match evidence
has not been recorded and the required two-iOS, two-Android, mixed-platform, and
four-seat cells are still incomplete.

Next actions:

1. Exercise this installed candidate on the paired iPhone and retain observed
   interaction, match, interruption, and startup evidence.
2. Remove or correctly populate unused privacy usage-description keys and
   modernize the launch/icon configuration before a distribution archive.
3. Produce and verify an App Store Connect/TestFlight-signed archive.
4. Restore an Android Java/Gradle toolchain and attach representative Android
   hardware.
5. Execute the unchanged P6 matrix. Keep P7 at `HOLD` until that evidence and a
   separate product-owner decision exist.
