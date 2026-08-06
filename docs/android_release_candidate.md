# Android release candidate

The Android release-candidate lane produces:

- an ARM64 AAB for store-side validation;
- an x86_64 release APK for emulator certification;
- an ARM64 release APK for direct installation on physical devices.

Both artifacts use application ID `com.entap.swarmfront`, version code `2`,
and version name `0.1.2-rc1`. Confirm the application ID with the Play Console
owner before the first upload because a Play application ID cannot be changed
after publication.

## Signing contract

Release signing material must remain outside the repository. The export
presets intentionally leave their release keystore fields empty. Godot 4.7.1
reads the credentials from:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

The keystore password and key password must match. Do not use the Android
debug keystore for either artifact.

## Export

Use the pinned Godot 4.7.1 binary and JDK 17:

```sh
export GODOT_BIN="/absolute/path/to/Godot"
export JAVA_HOME="/absolute/path/to/jdk-17"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="/absolute/path/to/upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="upload-key-alias"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<secret>"
scripts/dev/export_android_release_candidate.sh
```

Artifacts are written under `artifacts/android/release/`, which is ignored by
Git. The script refuses to export with a Godot version other than 4.7.1 and
verifies the keystore, password, and alias before building.

The emulator APK is a release-mode companion built with the `emulator` feature,
x86_64 ABI, and compatibility renderer. The device APK uses the ARM64 ABI and
the same release configuration as the AAB. Both exercise the same project
resources and release template as the AAB, but neither APK is uploaded to Play.
