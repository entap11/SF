# ADR 002 — Service Trust and Endpoint Classes

Status: Accepted for Package 1/2
Date: 2026-07-18

## Context

The current VS service distinguishes admin and match-authority operations using static secrets, but ordinary player traffic is unauthenticated. The rank service gates most operations with one bearer token that the current Godot transport is capable of holding.

Public player authentication and privileged service authority must be separate.

## Decision

### Trust mechanisms

1. Player calls use the short-lived player token defined by ADR 001.
2. VS verifies player tokens from the identity issuer's pinned JWKS. It does not call the identity database for every request.
3. Service-to-service calls use short-lived asymmetric service JWTs with unique service identities, audiences, scopes, `kid`, and rotation. Service private keys exist only in service secret storage.
4. Match-verifier receipts are signed by a dedicated verifier key and are independently verifiable by VS/rank/ledger consumers.
5. Administrative access must move to a separately authenticated ops identity/role. Existing static admin tokens remain staging/development compatibility only and cannot satisfy the public operational gate.
6. TLS is required for all non-loopback traffic.

Player access tokens never authorize service, verifier, or administrative scopes.

### Endpoint classes

Every route/action must declare exactly one class:

| Class | Caller identity | Examples |
|---|---|---|
| `IDENTITY_BOOTSTRAP` | Unauthenticated device plus anti-abuse controls and device public key | register identity, issue challenge |
| `PLAYER_AUTHENTICATED` | Valid player token; player derived from `sub` | queue, invite, ready, intents, reconnect, contest enter/submit, outbox ack |
| `PUBLIC_READ` | No player authority; sanitized and rate limited | health, published rules/config, published public leaderboard |
| `MATCH_AUTHORITY` | Trusted VS lifecycle or verifier service identity | verified result receipt, authoritative forfeit/no-contest |
| `SERVICE_TO_SERVICE` | Scoped trusted service identity | rank mutation, contest settlement request, ledger mutation |
| `ADMINISTRATIVE` | Authenticated ops identity and role | debug state, corrections, reversals, private transactions, config publication |
| `DISABLED_DEBUG` | Loopback/test only; unavailable in production | synthetic players, balance setters, reset helpers |

### VS target classification

`PLAYER_AUTHENTICATED`:

- Create/join/cancel/poll matchmaking and invitations.
- Session reads for a participant.
- Ready, start request, leave, heartbeat, presence, friends.
- Publish/poll intents and state hashes.
- Reconnect and participant acknowledgement.
- Free bot-fill request.
- Free contest enter, attempt, result, leaderboard context, outbox read/ack.

`PUBLIC_READ`:

- Health and protocol compatibility.
- Published, non-sensitive contest/mode configuration.
- Sanitized public leaderboard snapshots.

`MATCH_AUTHORITY` or `SERVICE_TO_SERVICE`:

- Verified terminal result.
- Rank-result mutation.
- Crucible escrow/settlement/refund/reserve movement.
- Future contest reward settlement.

`ADMINISTRATIVE`:

- Debug snapshots and private ledger reads.
- Balance mutation and corrections.
- Contest/config publication/deletion.
- Review resolution and reversals.
- Synthetic fill in non-production environments.

### Rank target classification

- Identity registration/challenge/session endpoints: `IDENTITY_BOOTSTRAP` or `PLAYER_AUTHENTICATED` as appropriate.
- Own profile/rank view: `PLAYER_AUTHENTICATED`.
- Sanitized global leaderboard: `PUBLIC_READ` or `PLAYER_AUTHENTICATED` by final privacy policy.
- Friends/region/call-sign mutation: `PLAYER_AUTHENTICATED`, subject derived from token.
- Match/contest rank mutation and decay jobs: `SERVICE_TO_SERVICE`.
- Debug/recompute/audit/private player inspection: `ADMINISTRATIVE`.

### Authorization rules

- Authentication establishes caller identity; authorization still checks session/contest membership and lifecycle state.
- Polling a known match/contest ID does not grant access.
- A service JWT is audience-bound and cannot be replayed against another service.
- A verifier receipt signature proves result origin but does not itself grant arbitrary API access.
- All privileged requests produce an audit event containing caller service/role, action, subject, resource ID, and request/event ID.

## Compatibility

During Package 1, exactly one Standard 1v1 queue action moves to `PLAYER_AUTHENTICATED`. Legacy routes remain internal-only and public flags remain false. Package 2 completes the endpoint migration before any public mode can advance.

## Rejected alternatives

- One shared bearer for player and service traffic.
- Treating HTTPS alone as player identity.
- Using knowledge of a match/contest ID as authorization.
- Embedding verifier or admin credentials in Godot.
