# Secure Credential Bridge — Build and Device Gate

Date: 2026-07-18; updated 2026-08-12
Godot target: 4.7.1 stable
Native singleton: `SwarmfrontSecureCredentials`

## Contract

The exported client calls the platform implementation only through
`NativeSecureCredentialStore`. The singleton exposes:

- `is_available() -> bool`
- `create_device_key(key_alias) -> JSON string`
- `public_key_jwk(key_alias) -> JSON string`
- `sign_challenge(key_alias, challenge_utf8) -> JSON string`
- `delete_device_key(key_alias) -> JSON string`

Both platforms generate non-exportable ECDSA P-256 keys, publish only the
public JWK, and sign the exact UTF-8 challenge with SHA-256. Signatures are
base64url-encoded ASN.1 DER. The identity service accepts DER and P1363 but
the platform plugins intentionally use the native DER format.

There is no file, `user://`, ProjectSettings, log, or software-private-key
fallback. If the native singleton or protected keystore is unavailable, the
adapter returns `secure_credential_store_unavailable` and registration/resume
must stop.

## Android build and install

Prerequisites: JDK 17, Android SDK 34, and a local Gradle 8.2-compatible
installation. From `native/android/secure-credentials` run:

```bash
gradle :plugin:installDebugPlugin
gradle :plugin:installReleasePlugin
```

The tasks install the AARs under
`addons/swarmfront_secure_credentials/bin/{debug,release}`. Enable
`Swarmfront Secure Credentials` under Project Settings > Plugins, enable a
Godot Gradle build in the Android export preset, and export to a physical
Android 6.0+ device. The AAR manifest registers the Godot v2 plugin metadata.

The implementation uses the `AndroidKeyStore` provider and never requests
private-key encoding. A repeated create is idempotent for the same alias.

## iOS build and install

Prerequisites: Xcode, SCons, and a Godot `4.7.1-stable` source tree whose
generated headers match the export templates. From the repository root run:

```bash
sh native/ios/secure-credentials/build_xcframework.sh /absolute/path/to/godot-4.7.1-stable
```

The script rejects other Godot source versions or missing generated headers.
It builds an arm64 device slice and a universal arm64/x86_64 simulator slice,
creates the XCFramework, and installs it with its `.gdip` in
`ios/plugins/swarmfront_secure_credentials`. Enable
`SwarmfrontSecureCredentials` in the iOS export preset before exporting.

The implementation requests a permanent Secure Enclave P-256 private key
accessible only on the creating device. It deliberately reports unavailable
in the simulator because the simulator cannot supply the production Secure
Enclave guarantee.

## Required physical-device acceptance

Run this matrix before changing the Package 1 release result from `HOLD`:

1. Clean install creates one device key and registers one device record.
2. App termination/reopen issues a new challenge and resumes the same player.
3. Challenge replay is rejected.
4. A signature from device A cannot authenticate device B's challenge.
5. Key deletion makes resume fail closed and starts the approved recovery path.
6. App uninstall/reinstall follows the approved device-link/recovery policy.
7. No private key or access token appears in exported files, backups, logs, or
   support diagnostics.
8. A player token cannot call match-authority, rank mutation, or admin routes.

Desktop/editor smoke coverage uses an injected fake singleton only to validate
the ABI and JSON normalization. It does not claim native keystore coverage.
