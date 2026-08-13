# iOS Secure Credentials 4.7.1 Build Evidence — 2026-08-12

Status: `BUILD/LINK PASS — PHYSICAL DEVICE ACCEPTANCE PENDING`

This evidence closes the known Godot-version and simulator-architecture build
gaps. It does not certify Keychain or Secure Enclave behavior, signing, install,
registration, resume, recovery, or a release candidate.

## Bound inputs

- Godot editor/export binary: `4.7.1.stable.official.a13da4feb`.
- Godot source: official tag `4.7.1-stable`, commit
  `a13da4feb8d8aefc283c3763d33a2f170a18d541`.
- The build script requires the exact 4.7.1 stable `version.py` fields and the
  generated `core/extension/gdextension_interface.gen.h` and
  `core/disabled_classes.gen.h` headers.
- Target plugin singleton: `SwarmfrontSecureCredentials`.

## Built plugin

| Artifact | Architecture | SHA-256 |
| --- | --- | --- |
| Device static library | arm64 iOS | `25641ca26f411eb0c08e8ce7cb9de605a56b0d003bacd70b2c8f0694cb25fc81` |
| Simulator static library | arm64 + x86_64 iOS Simulator | `56706932162f8a009b01871aa1d8e9cdd9f886b2e3439217338783544a4fa29f` |
| XCFramework `Info.plist` | device + simulator declarations | `922fcf78a0fff46d82827faf3bd2fff985e84157a9d60ea0dcf1e30b8344551b` |
| Godot plugin descriptor | `.gdip` | `57786273bc6f7e241b6c9fc8cf94d86d6b05607ec7ca66a239d15a10d6acf5bd` |

Universal plugin rebuild log:
`/tmp/swarmfront_ios_secure_plugin_universal_rebuild_2026-08-12.log`, SHA-256
`4e0243176920242c4d6c1ffd9a62101c4d267fca596c311646de30167bc57419`.

## Export and unsigned link evidence

The iOS and iOS Private PvP Certification presets both explicitly enable the
plugin. A fresh 4.7.1 Private PvP project export succeeded and included the
XCFramework, `Security.framework`, and plugin initialization wiring.

| Check | Result | Evidence SHA-256 |
| --- | --- | --- |
| Godot 4.7.1 project export | PASS | `3a1954640303ec0ed67bfcdb25a3cb4db671a904ad36a0786c8962c66351548b` |
| Xcode arm64 device link, unsigned | PASS | `185fbb042d414125ecd699f0a41609bee1259fd51f0a727a5be52b30491dedf2` |
| Xcode x86_64 simulator link, unsigned | PASS | `2ca3bb63ea2bef67d7bc0946556fbcaa1f9fa5685bafe3454bb0c9df3b3efb8e` |

The linked device executable is arm64 with SHA-256
`50106d9cbd81884d5d64629b5111534ebeacfd917f1a4d4515bea42ed0021df6`.
The linked simulator executable is x86_64 with SHA-256
`aeaa27bd3137916f41d0129b91f2504c7bddbff8116b6a496f46da7c40117419`.
Both contain the plugin singleton and `ECDSA_P256_SHA256` implementation.

The first simulator attempt is retained as failure evidence at
`/tmp/swarmfront_ios_secure_universal_xcodebuild_simulator_2026-08-12.log`
(SHA-256
`328e15cf4c3f265f6903694455cccbfbf5c4fcc3de55c5b367e4db63da467f26`):
the exported project requested arm64 on this Intel host while the bundled Godot
simulator template was x86_64. The subsequent link explicitly selected x86_64,
which is present in the corrected universal plugin slice.

## Eligibility boundary

These export/link checks were performed from the shared dirty integration
worktree and are diagnostic native-build evidence only. Their app artifacts
are not eligible for the Candidate Release Manifest. Candidate artifacts must
be rebuilt from the eventual clean, exact tested commit.

The release gate remains open until a signed build from that clean commit is
installed on the paired physical iPhone and passes the complete protected-key
matrix in `secure-credential-bridge.md`. Simulator behavior cannot satisfy that
gate because the production Secure Enclave guarantee is intentionally
unavailable there.
