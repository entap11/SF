# TestFlight Beta Readiness

## Current State
- The repository contains an iOS preset in `export_presets.cfg`; signing
  identities, provisioning material, and custom-template locations remain
  machine-local concerns.
- The exact custom Godot 4.2.2 debug/release template used for current iOS work
  contains the documented deferred-audio-start and Xcode 26 compatibility
  changes.
- A current Release archive and development IPA build and pass strict signature
  verification. The exact evidence and remaining distribution/device boundaries
  are in
  [P6 Signed Candidate Evidence — 2026-09-02](architecture/public_modes/p6-signed-candidate-evidence-2026-09-02.md).
- App Store Connect/TestFlight distribution signing is not yet certified.
- Crash reporting provider for TF beta is locked to **Sentry** (solo free tier).

## Apple/Xcode Prerequisites (Per Machine)
1. Xcode installed and signed in with Apple Developer account.
2. Valid signing identities in keychain (`Apple Development` / `Apple Distribution`).
3. App Store Team ID available.
4. iOS bundle identifier reserved in Apple Developer portal.
5. Provisioning profile available for target bundle ID.

## Files/Config Required for TestFlight Upload
1. `export_presets.cfg` (local; includes iOS preset and signing mode).
2. App icon set (including 1024x1024 App Store icon).
3. Launch screen configuration (storyboard is enabled now).
4. Privacy metadata in App Store Connect (and privacy manifest if SDK use requires it).
5. Versioning policy:
   - `short_version` (marketing version, e.g. `0.1.0`)
   - `version` (build number, increment every upload)

## Beta Backend Mode

The former hybrid/local-authoritative recommendation is superseded for
persistent competitive and economic state.

- OpsState/SimState remain authoritative for gameplay simulation.
- Platform services are authoritative for Honey, Wax, Nectar, entitlements, and
  competitive progression.
- The client may cache verified projections and emit intents, but it may not
  commit a local fallback mutation when Platform authority is unavailable.
- Unavailable authority fails closed. Presentation may show pending transport
  state, but it must not label a client-calculated balance or award as committed.

## Persistence Policy (Recommendation)
1. **Authoritative on server (or authoritative transport endpoint):**
   - rank / wax / leaderboard position
   - paid economy state
   - tournament/contest entry + results
2. **Client-local with sync:**
   - graphics/settings preferences
   - non-competitive UX state (tutorial flags, device toggles)
3. **Conflict policy:**
   - competitive fields: server wins
   - local UX fields: newest timestamp wins
4. **Write safety:**
   - idempotency key per reward/progression event
   - monotonic sequence per profile for anti-duplication

## Pre-Upload Gate
1. Run release readiness:

```bash
scripts/dev/run_release_readiness_gate.sh --matrix-gate pr --include-tf-preflight
```

For a faster local pre-check:

```bash
scripts/dev/run_release_readiness_gate.sh --matrix-gate fast
```

2. Run smoke tests not yet covered by the readiness script, as needed for the target build:
   - `res://tools/money_game_ledger_smoke_test.gd`
   - `res://tools/async_money_game_ledger_smoke_test.gd`
   - `res://tools/vs_money_game_start_smoke_test.gd`
   - `res://tools/main_menu_async_money_escrow_smoke_test.gd`
   - `res://tools/money_game_backend_transport_smoke_test.gd` with local `tools/vs-service` running
   - `res://tools/buff_inventory_wiring_smoke_test.gd`
   - `res://tools/swarm_pass_smoke_test.gd`
   - `res://tools/rank_system_smoke_test.gd`
   - `res://tools/floor_influence_smoke_test.gd`
3. Export iOS project from Godot.
4. Build/archive in Xcode.
5. Upload to TestFlight.

Do not treat a development-signed IPA as completion of step 5. The distribution
archive, upload, processing result, and installed TestFlight build must all be
recorded separately.
