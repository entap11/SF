# Package 1 Evidence Report — Authenticated Standard 1v1 Slice

Date: 2026-07-18
Implementation result: `PASS WITH PHYSICAL-DEVICE GATES`
Public release result: `HOLD`

## Delivered

- Rank-service migration `005_player_device_sessions.sql` for registered P-256 device keys, single-use challenges, short-lived sessions, revocation, and audit references.
- Atomic device-backed identity registration with UUIDv7 player/device/challenge IDs and zero starting Wax while economy is quarantined.
- Device challenge proof accepting ECDSA P-256 SHA-256 signatures in standard DER or IEEE-P1363 form.
- ES256 player JWT issuance with issuer, audience, subject, session, device, scope, timing, token ID, version, key ID, and signed display snapshots.
- Public JWKS endpoint containing no private key material.
- New VS `enqueue_public_1v1` action deriving identity only from JWT `sub`, rejecting conflicting body identity, requiring `match:queue`, and discarding client rank/economy hints.
- Forced slice policy: Standard 1v1, non-economic, unranked, `RELAY_ATTESTED`.
- Fail-closed separation between player, match-authority, and administrative credentials.
- Godot in-memory player-session seam and fail-closed non-exportable credential-store interface.
- Godot native-singleton adapter and platform factory with one ABI for iOS and Android.
- Android Keystore P-256 plugin source, Godot v2 plugin manifest, Gradle build, and export-plugin installer.
- iOS Secure Enclave/Keychain P-256 plugin source, Godot `.gdip`, SCons build, and XCFramework installer.

## Flags and release posture

- `VS_AUTHENTICATED_1V1_SLICE_ENABLED` defaults false.
- The health contract reports `public_1v1_enabled=false` unconditionally in Package 1.
- Rank/economy/contest/public flags were not enabled.
- The existing legacy matchmaking actions remain internal compatibility routes; Package 1 protects only the new bounded action.

## Automated evidence

- Rank TypeScript build: `PASS`.
- ES256 sign/verify, JWKS redaction, expiry, audience, scope, tamper, and canonical-base64url smoke: `PASS`.
- VS TypeScript build: `PASS`.
- Authenticated queue smoke: `PASS` for missing/forged claims, scope denial, audience denial, body-identity mismatch, two authenticated seats, signed display snapshots, unranked relay policy, and player-token rejection at admin/match-authority routes.
- Existing VS full service smoke, economy/auth quarantine smoke, and spectator smoke: `PASS`.
- Existing rank economy-quarantine smoke: `PASS`.
- Godot credential/session seam smoke: `PASS`; token material is absent from the debug snapshot and cleared on local revocation.
- Embedded PostgreSQL migration/session smoke: `PASS`; migrations 001–005 apply in order and the durable lifecycle covers idempotent registration, idempotency conflict, native DER and P1363 signatures, single-use challenges, token verification, idempotent revocation, audit rows, and resume through a fresh store instance.
- Rank and VS production dependency audit (`npm audit --omit=dev`): `PASS`, zero reported vulnerabilities after lockfile refresh.

## Environment and device gates

The repository-level PostgreSQL gate now runs with PGlite and `pgcrypto`:

```bash
cd tools/rank-service
npm run smoke:session:embedded
```

PGlite exercises PostgreSQL schema and transaction semantics, but a deployment rehearsal against the actual managed PostgreSQL version is still required. Run `npm run migrate` and the live `npm run smoke:session` against an isolated staging database.

This workstation has Xcode but no JDK, Android SDK/Gradle, SCons, or matching Godot iOS generated headers. Native source and build wiring are present, but the Android AAR and iOS XCFramework could not be compiled here. More importantly, protected-key behavior cannot be accepted without physical iOS and Android devices. Follow `secure-credential-bridge.md`. These gates keep the program at `HOLD`.

## Remaining release blockers

- Native plugins require compile/export verification and the physical-device acceptance matrix.
- Registration anti-abuse/rate limiting and device-link/recovery UX are not implemented.
- VS validates short-lived JWTs offline; revocation takes full effect at token expiry until a revocation-distribution mechanism is added.
- Legacy VS actions still trust body identity and must remain non-public until Package 2 endpoint migration.
- VS queue/session/commands remain in memory until Package 2.
- Results remain client/relay-attested and therefore unranked until Package 4.

## Rollback

- Keep `VS_AUTHENTICATED_1V1_SLICE_ENABLED=false` to disable the new VS action.
- Remove player-token issuer secrets to make identity-session endpoints fail closed with HTTP 503.
- Migration 005 is additive; rollback should preserve audit data and disable routes rather than destructively dropping identity/session tables.
