# TestFlight Beta Readiness

## Current State
- iOS export preset exists locally in `export_presets.cfg` (gitignored by design).
- Godot iOS export template is installed at:
  - `~/Library/Application Support/Godot/export_templates/4.2.2.stable/ios.zip`
- Export currently fails until Apple signing values are configured on the machine.
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

## Beta Backend Mode (Recommendation)
Recommended for closed TF beta: **Hybrid Local-Authoritative**
- Match simulation remains local-authoritative for moment-to-moment gameplay.
- Competitive progression writes (rank/pass/economy) are gated behind server/transport calls when available.
- If backend unavailable, queue writes and mark them as provisional until confirmed.

Why this mode:
- Keeps current gameplay responsiveness.
- Avoids blocking beta on full dedicated-match backend.
- Prevents direct client trust for persistent competitive values.

Implemented visibility for beta users:
- Runtime flags are exposed by `VsHandshake` (`transport_mode`, progression authority, provisional status).
- A top-of-screen provisional banner is shown when competitive progression is local/provisional.

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
1. Run smoke tests:
   - `res://tools/economy_buff_smoke_test.gd`
   - `res://tools/swarm_pass_smoke_test.gd`
   - `res://tools/rank_system_smoke_test.gd`
   - `res://tools/floor_influence_smoke_test.gd`
2. Export iOS project from Godot.
3. Build/archive in Xcode.
4. Upload to TestFlight.
