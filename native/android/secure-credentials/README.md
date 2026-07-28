# Android development build

This lane produces a disposable, debug-signed Android APK. It does not define
production application identity or release signing.

## Pinned toolchain

- Godot 4.7.1 with the matching export templates
- JDK 17
- Android SDK platform 36
- Android SDK build-tools 36.1.0
- Android NDK 29.0.14206865
- Gradle 8.11.1 (repository wrapper)
- Android Gradle Plugin 8.6.1
- Kotlin 2.1.21

Configure Godot's Android SDK and Java SDK paths in Editor Settings before the
first export. Command-line builds also require `JAVA_HOME` to identify JDK 17
and `ANDROID_HOME` to identify the Android SDK. Keep keystores and passwords
outside the repository.

## Build

From this directory, rebuild and install both secure-credentials plugin AARs:

```sh
./gradlew --no-daemon clean installDebugPlugin installReleasePlugin
```

From the repository root, install Godot's stock Gradle build template and
export the physical-device debug APK. Confirm the selected executable reports
Godot 4.7.1 before exporting:

```sh
godot --version
godot --headless --path . --install-android-build-template
godot --headless --path . --export-debug "Android Development" \
  artifacts/android/swarmfront-dev-debug.apk
```

On an Intel Mac, export the x86_64 emulator APK:

```sh
godot --headless --path . --export-debug "Android Emulator" \
  artifacts/android/swarmfront-emulator-debug.apk
```

Boot an x86_64 Android virtual device with software-backed graphics, then
install the emulator APK:

```sh
emulator -avd <avd-name> -gpu lavapipe
adb install -r artifacts/android/swarmfront-emulator-debug.apk
```

The generated `android/` tree, plugin AARs, and `artifacts/` output are ignored.
Both presets use API 24 minimum and API 36 target. `Android Development` uses
package ID `com.entap.swarmfront.dev`, arm64, and the mobile renderer.
`Android Emulator` uses package ID `com.entap.swarmfront.emulator`, x86_64, and
the compatibility renderer to avoid host-specific Vulkan emulator failures.

## Release candidate

The signed ARM64 AAB and x86_64 release-mode certification APK use separate
release presets and environment-injected signing credentials. See
[`docs/android_release_candidate.md`](../../../docs/android_release_candidate.md)
for the signing contract, application identity, and export command.
