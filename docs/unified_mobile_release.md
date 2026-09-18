# Unified mobile release candidate — September 18, 2026

## Scope and authority

One clean source commit must produce both iOS and Android store candidates.
Gameplay remains owned by OpsState/GameState. The website stays in its separate
repository at `50ae299`; its account-deletion route is the app's help destination.
No backend deployment, store upload or feature rollout is part of this task.

## Inspected source and reuse decisions

| Input | Decision |
| --- | --- |
| Local main `f72bbaa` (remote main `b834a91`) | Integration base; preserve local economy, soak and rollout fixes. |
| Latest app `cd5259f` | Merge all five unique commits, preserving latest gameplay, UI, backend hardening, identity and Swarmfront-only deletion. |
| Android branch `99702f9` | Selectively reuse Gradle wrapper, SDK/JDK settings, native Android plugin build, AAB preset and exact Godot 4.7.1 toolchain. Do not merge older gameplay or certification UI. |
| Engine migration `4a2c138` | Adapt numeric JSON/map-ID compatibility and its regression test for both platforms. Regenerate import metadata with the pinned importer. |
| Android branch iOS plugin | Do not replace current iOS implementation: its Keychain tag differs. Rebuild current iOS plugin against 4.7.1 and preserve the existing tag and API. |
| Other dirty worktrees | Leave unfinished bot work, engine-import experiments and sprite evidence untouched. They are not release-approved inputs. |

The merge retains both the lane-grab regression gate and main's soak-launch
contract. TestFlight preflight retains main's local smoke/read-only hosted health
checks; only its runtime selection/version detection is adapted.

## Store configuration

- iOS bundle ID: `com.matthew.swarmfront`; Apple team: `SH6675DXQ5`.
- Android application ID: `com.entap.swarmfront`; release AAB, ARM64, API 24–36.
- Both presets use the same `store_release` feature. Fake/development ads are
  disabled in configuration and rejected at runtime in release builds.
- Paid cash entries remain disabled even if remote operations request activation.
- Existing HTTPS certification Rank/identity and VS endpoints remain intentional
  beta destinations. They are not represented as production-certified services.
- Signing credentials stay outside source control. The permanent Play upload key
  is distinct from the old local RC key, which is not used by this release lane.

## Permanent Google Play upload signing

The owner requested a new permanent RSA 4096-bit key on September 18, 2026.

- Keystore: `~/Library/Application Support/Swarmfront/signing/android/swarmfront-play-upload.keystore`
- Alias: `swarmfront-play-upload`
- Keychain service: `com.entap.swarmfront.android.play.upload`
- Keychain account: `swarmfront-play-upload`
- Certificate SHA-256: `C7:5C:4E:8C:5E:84:53:79:E8:76:BA:79:1D:0E:1B:B9:31:F1:E5:52:02:6B:39:46:4B:DA:93:B6:61:D0:2A:35`
- Validity: September 18, 2026, 14:02:29 PDT through September 18, 2056, 14:02:29 PDT.

Use `python3 scripts/dev/export_android_play_aab.py --check-signing` to verify
the configuration, Keychain password and pinned certificate without building.
For an approved, clean release candidate, use the same launcher with
`--output /absolute/external/release/path/swarmfront.aab`. It runs the canonical
PR/TestFlight gate, retrieves the password at build time, sets all three
`GODOT_ANDROID_KEYSTORE_RELEASE_*` values, exports a temporary unsigned release AAB,
signs the final AAB with `jarsigner` using environment-password arguments, and
verifies its signer. This avoids Godot's built-in Gradle signing path, which puts
the password in process arguments. It never uploads. Inherited RC signing values are replaced;
there is no fallback to the RC key. No password is stored in source or argv.

The export preset deliberately leaves its keystore fields empty and built-in
signing disabled: the launcher supplies credentials securely to the final signing
step. A raw Godot export alone is not the signed Play artifact. The old Android
branch's RC export command is not this
unified Play release lane. Google Play enrollment/upload has not been performed.

## Required acceptance

Run `scripts/dev/run_release_readiness_gate.sh --matrix-gate pr --include-tf-preflight`
with the pinned runtime, plus native plugin builds, store-configuration checks,
account-deletion/session/economy tests and release exports from the recorded commit.
Record exact engine/template hashes, versions, source SHA, artifacts and signing
results outside tracked source. Real-device identity and gameplay evidence must
be distinguished from headless tests and native link/signature checks.

## Known external release blockers discovered during preparation

- Hosted Rank and VS report `761e2d8`; the deletion-health field is absent.
  Local deletion tests cannot establish functional hosted deletion. Follow
  `docs/account_deletion.md` before enabling intake or making store declarations.
- Versions: shared marketing version `0.1.2`, iOS build `2026091801`, Android
  versionName `0.1.2` and versionCode `26091801`. The newest local Xcode archive
  is `0.1.1 (2026082501)` from August 25; Organizer's cached store record is
  `0.1.1 (2026071701)`. No newer Transporter record was found. The owner approved
  these next numbers and confirmed no previous upload to this Play listing.
- The owner explicitly approved the existing protected certification Rank,
  identity and VS URLs for this internal beta. Public-production backend cutover
  remains separate; local/mock/test-double services are not release destinations.
- The new permanent upload certificate still needs enrollment with Google Play;
  no store upload or Play App Signing configuration was performed locally.
- No physical Android device was attached at inspection. A paired iPhone is
  available, but installing a candidate must preserve its existing device key.

Artifact generation does not clear these acceptance requirements.
