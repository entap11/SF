# SwarmFront build artifacts on Samsung T7

This Mac stores generated artifacts under `/Volumes/Samsung T7/SF Build Artifacts`.
Paths beneath the SF workspace retain their original relative layout, for example
`artifacts/releases/0.1.4-20261002/ios/AppStore/Swarmfront.ipa`.
Original locations remain symbolic links. Prior library transfers remain under
`/Volumes/Samsung T7/SF Build Libraries`; they are not copied again.

Source trees, original game assets, Git recovery/history, credentials, tracked
frameworks and the two tracked `Swarmfront.xcodeproj.pck` files stay internal.
Tracked packs are retained because store-release checks require a clean checkout.
Untracked exports of those packs are on the T7. Historical source snapshots and
Godot toolchain applications stay internal; their selected generated outputs and
downloaded build-template ZIPs are external.
The old Desktop `SF Exports` folder contains iCloud-only data and is left there;
its approximately 1.9 GB of logical contents occupy only 1.7 MB locally.

## New builds

Connect and unlock the drive before using relocated builds or diagnostics.
Check its identity and free space from the project directory:

```sh
python3 scripts/dev/build_storage.py check --required
```

The ignored `.sf-build-storage.json` enables routing on this Mac and pins the
volume UUID. The Python launchers retain their existing explicit-output behavior
when that file is absent; the local Gradle rule below applies across this SF workspace.
The signed Android release launcher defaults to a new dated T7 directory:

```sh
python3 scripts/dev/export_android_play_aab.py
```

Its existing signing, clean-source and readiness gates still apply. An explicit
`--output` under the original SF `artifacts` hierarchy is translated to the same
relative T7 path. Explicit paths on the T7 are also supported. Signing-only
checks do not require the drive. Credentials stay in their original locations.

Export iOS into a fresh dated T7 directory, optionally checking an unsigned build:

```sh
python3 scripts/dev/export_ios_t7.py --build
python3 scripts/dev/export_ios_t7.py --preset 'iOS Bot Playtest' --debug --build
```

These commands validate the mounted drive before creating output. They preserve
existing export versions and place Xcode DerivedData alongside the new export.
They do not install, upload or distribute a build. `GODOT_BIN` can select the
runtime; the default is the existing 4.7.1 SwarmFront toolchain.

`scripts/dev/run_perf_harness_pacing_diagnostic.sh` also defaults its captures,
logs and JSON reports to `project/artifacts/perf_harness_pacing_diagnostic` on the
T7 when this local configuration is present. Its existing explicit output-directory
override remains available.

This Mac's `~/.gradle/init.d/swarmfront-t7.gradle` also validates the T7 and redirects
Gradle build directories for projects under this SF workspace. It survives Godot
reinstalling the Android build template and does not affect other workspaces.
The Android generated asset-pack directory and Godot GUI export destinations use
local symlinks. The iOS presets now write to `artifacts/ios/exports/Swarmfront.xcodeproj`
instead of the old iCloud Desktop folder; Android retains `artifacts/android/release`.
Both directories route to the T7 on this Mac. Xcode's default DerivedData was
already relocated separately.

Prefer the guarded launchers above. Raw historical scripts and Godot GUI exports
use the existing links and may show ordinary file/path errors if the T7 is missing.
Deleting a symlink or recreating a build template can reset that particular alias;
the Gradle routing and guarded launcher output paths still target the T7. Fresh
diagnostic directories created by other scripts may still be internal unless their
output argument points to the external artifact tree.

## Migration records and restoration

Per-item file inventories, SHA-256 checksums, original paths, destinations and
skips are recorded in `SF Build Artifacts/_migration/2026-10-06` on the drive.
Internal originals are removed only after content and metadata verification.
Open or changing artifacts are skipped. The T7 is now required to read or rebuild
relocated artifacts; it should remain connected until builds have finished.

To restore a particular artifact internally, stop its builds, copy the external
target to a temporary internal path, verify it against the saved manifest, then
replace its original symlink with that verified copy. Do not delete the external
copy until the restored path is verified. Do not commit machine-specific symlinks.
