# ADR 001 — Player Identity and Session Authority

Status: Accepted for Package 1
Date: 2026-07-18

## Context

The historical `tools/rank-service` now creates canonical UUIDv7 player IDs and public ENTaP IDs. Ordinary VS routes still trust a client-provided `uid`, and the current profile contains identity facts but no credential that proves continued ownership of the UUID.

A public competitive player must be able to prove identity without embedding a shared backend secret in the app. Offline/dev play must remain possible without impersonating a public session.

## Decision

### Identity/session issuer

For the first public-mode implementation, `tools/rank-service` is the canonical player identity and session issuer. The directory name is historical and will not be renamed during Package 1.

It owns:

- UUIDv7 player identity.
- Public ENTaP ID and call sign.
- Registered player devices.
- Device public keys.
- Session issuance, expiry, rotation, and revocation.
- Player-token signing keys and public JWKS publication.

VS owns matchmaking/session state but never creates or accepts an authoritative player identity from a body field.

### Device credential

The durable player credential is a device-bound, non-exportable ECDSA P-256 key pair:

- iOS: Keychain/Secure Enclave when supported.
- Android: Android Keystore with hardware backing when supported.
- Editor/desktop development: an explicit debug credential adapter, blocked in release exports.

Godot accesses the key through a narrow platform credential-store interface. The private key is never returned to GDScript and is never uploaded.

At first account registration:

1. The device creates its key pair.
2. Registration submits the public key and a client request ID.
3. The identity service atomically creates the UUIDv7 identity and registered-device row.
4. The service returns the identity plus an authentication challenge/session bootstrap receipt.
5. The device signs the challenge and receives a short-lived access token.

### Session proof

Player access tokens are short-lived asymmetric JWTs with, at minimum:

- `iss`: ENTaP identity issuer.
- `aud`: intended Swarmfront service audience.
- `sub`: canonical UUIDv7 player ID.
- `sid`: revocable session ID.
- `did`: registered device ID.
- `scp`: allowed player scopes.
- `iat`, `nbf`, `exp`.
- `jti`.
- `ver`: token contract version.
- `kid`: signing-key identifier in the JWT header.

Recommended access-token lifetime is 10 minutes. Services must enforce issuer, audience, signature, expiry, session status, and required scope.

Session renewal uses a server nonce signed by the registered device key. Package 1 does not introduce a long-lived bearer refresh secret.

### Identity derivation

For player-authenticated routes:

- The service derives `player_id` exclusively from token `sub`.
- A legacy `uid`/`player_id` body field may remain temporarily for compatibility, but if present it must exactly match `sub` or the request is rejected with `identity_mismatch`.
- Display name, ENTaP ID, rank, friends, color, balance, and party data supplied by the client are hints only. Their authoritative values come from server state or a trusted service.

### Existing beta identities

Existing profiles have no cryptographic proof of UUID ownership. Therefore:

- A client-supplied UUID or public ENTaP ID is not sufficient to claim a competitive credential.
- No automatic public-competition upgrade is permitted from those fields alone.
- Existing local identities remain valid for offline/dev use.
- A beta identity may become authenticated only through a server-authorized one-time migration receipt or by creating a new authenticated identity.
- Migration tooling must run before rank/economic mutations are enabled and must produce an audit record.

### Additional devices and recovery

The initial supported additional-device flow uses a one-time link grant authorized by an already authenticated device. The new device registers its own public key; private keys are never copied.

If all registered devices are lost and no separately approved account-recovery factor exists, self-service recovery is unavailable. A support-reviewed recovery path may be added, but open public rollout remains `HOLD` until recovery UX and policy are approved.

### Local/offline identity

`ProfileManager.get_user_id()` remains for compatibility. New public-mode code consumes an identity/session snapshot that clearly distinguishes:

- `offline_local`.
- `authenticated_backend`.
- `expired`.
- `revoked`.
- `migration_required`.

An offline/local identity can never enter a public queue or public contest.

## Required Package 1 repository seams

Tentative, not yet implemented:

- Identity migrations under `tools/rank-service/src/sql/migrations/`.
- Session/token modules under `tools/rank-service/src/identity/`.
- `scripts/platform/secure_credential_store.gd` as the GDScript-facing abstraction.
- Native iOS/Android implementations or a vetted Godot plugin.
- Session lifecycle integration in `scripts/profile/profile_manager.gd`.

## Consequences

- Package 1 includes native/platform credential work, not only HTTP middleware.
- Existing beta identities cannot be treated as authenticated merely because their UUID format is valid.
- A new-device recovery experience is a later release gate.
- Identity and public competition can advance without requiring a broader ENTaP social-platform implementation.

## Rejected alternatives

- Trusting body `uid`: impersonable.
- Shipping `RANK_API_TOKEN` or `VS_MATCH_AUTHORITY_TOKEN`: grants every client shared service authority.
- A persistent bearer refresh token in a normal Godot config file: exportable and replayable.
- Treating public ENTaP ID or call sign as authentication: both are display identifiers.
