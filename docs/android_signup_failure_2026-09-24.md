# Android beta signup failure — September 24, 2026

The reported screen is consistent with a deterministic first-run client bug.
The packaged 0.1.2 configuration disables `enable_rank_backend`, but Continue
still called `RankState.intent_register_player(..., authoritative_required=true)`.
That returns `rank_backend_not_configured`, which the panel described as an
unavailable account service and suggested checking the player's connection.

Read-only health checks returned HTTP 200 from both hosted certification services.
An empty, invalid registration probe confirmed that the old
`/v1/rank/register_player` route returns HTTP 410
`player_identity_authority_required`; `/v1/identity/register` instead returns
HTTP 400 `invalid_request_id`, as expected for that invalid body. The probes
created no accounts. Enabling the Rank flag would therefore not fix signup.
No tester device logs were available, so this does not exclude a separate
device/network problem on that phone.

## Correction

- The panel sends the chosen call sign to `PlayerIdentityRuntime`, which uses
  the existing native device key and identity registration/session endpoints.
  The menu no longer attempts legacy Rank registration.
- Startup and the refresh timer authenticate existing devices. New registration
  starts only when the player submits onboarding.
- A successful device session and its server identity are required before the
  release flow completes. Debug fallback remains unavailable in store exports.
- Persist the request ID, call sign and device ID atomically. An uncertain
  response retains the same request across retries and restarts. A definitive
  name rejection permits a different choice.
- A previously registered device resumes the same account. If it has a different
  call sign, show that name and require Continue again to confirm it. There is
  no new rename API or account replacement.
- Bootstrap files from older builds are read compatibly. An old rejected
  default name is reconciled before submitting the player's chosen name.
- Account deletion also removes the temporary bootstrap file.
- Physical Android testing found a second blocker: the credentials plugin was
  loaded, but its JNI methods were rejected by `Object.has_method()`. The adapter
  now also checks Godot's `has_java_method()` registry. Ordinary native bindings
  continue to use the existing lookup, and unregistered methods remain blocked.

## Verification and release status

`tools/run_onboarding_identity_checks.py` runs the actual panel and identity
runtime with isolated player data and replacements only for native credentials
and HTTP. Coverage includes fresh signup with Rank disabled, network failure,
restart, name changes after uncertain responses, name conflicts, legacy
bootstrap recovery, session retry, existing devices and storage failures. It
also runs existing onboarding, session-adapter and deletion UI checks. The
release readiness gate now includes these checks. All eight checks passed on
Godot `4.7.1.stable.official.a13da4feb`; logs are in
`../artifacts/signup-fix-20260924/` relative to the source worktree.

The pinned Godot 4.7.1 headless renderer emits a known custom-sampler diagnostic
for existing menu shaders. The runner retains that exact diagnostic in logs;
other errors and failed assertions fail the checks. This is functional signup
coverage, not Android rendering or native-keystore certification.

The backend's embedded device-session smoke test also passed. It exercises migrations, real
P-256 proof, session issuance, revocation and resume against disposable storage.
No backend deployment or store upload is part of this correction. An updated
Android release still needs fresh-install and existing-install verification on
a physical device before rollout.

## Call sign and signup persistence

The follow-up regression `onboarding_restart_smoke_test` launches four separate
processes against one isolated installation: signup, an offline restart, an
online restart, and a second online restart. It uses the real profile save/load,
identity runtime, onboarding panel and main menu. It does not prefill or reset
profile fields between processes. All four desktop phases passed.

Each restart asserts that the chosen call sign, completed-signup flag and device
ID were loaded before authentication; the menu displays `Welcome BetaPersist_35`
and hides signup; the account and key remain the same; and no registration is
sent again. The offline case simulates a service timeout. Restarts also verify
that access tokens are not persisted and online launches authenticate the saved
device again. This regression is included in the release readiness gate.

Desktop evidence is in
`../artifacts/signup-restart-20260924/desktop/onboarding_restart_evidence.json`.

The Android test uses a separate `com.entap.swarmfront.signupcheck` installation,
the real native plugin and AndroidKeyStore, and controlled account-service
responses. Its exported settings contain no hosted Rank/VS URLs. The normal
`com.entap.swarmfront` installation is not upgraded, cleared or used for fixture
data. This checks actual Android profile/key persistence without creating
hosted accounts; it does not replace live-service acceptance of the beta build.

After the JNI lookup correction, all four Android phases passed on the connected
SM-A156U running Android 16, with four distinct process IDs and one unchanged
device public-key fingerprint. Each phase displayed `Welcome BetaPersist_35`
with signup hidden. There was exactly one registration, during initial signup;
online restarts used device challenges and sessions, and the offline restart
retained the completed profile without authenticating. The method-registry and
signup regressions also passed after the correction.

Native results and the verified APK/source hashes are in
`../artifacts/signup-restart-20260924/android-restart-evidence.json` and
`android-package-verification.json` in that directory. The temporary test app
was uninstalled after verification. The existing Swarmfront installation still
reports its original version and September 2 update timestamp.
