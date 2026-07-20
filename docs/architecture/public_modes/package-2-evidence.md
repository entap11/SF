# Package 2 Evidence Report — Non-Economic Durable VS Core

Date: 2026-07-18
Implementation result: `PASS WITH STAGING GATES`
Public release result: `HOLD`

## Delivered

- PostgreSQL migration `001_vs_durable_core.sql` with durable match contracts, roster v2 entries, reconnect state and fixed grace deadlines, lifecycle events, canonical command streams/events, terminal result receipts, idempotency receipts, and player outbox events.
- Contract creation with UUIDv7 contract/match IDs, canonical sorted JSON, SHA-256 contract hash, immutable roster snapshot, content hashes, exact schema versions, authority tier, and server-owned policy snapshots.
- Atomic `match.queue.v1` idempotency receipt and contract/roster/stream creation transaction.
- Atomic command sequence allocation under a locked stream row. A command is returned only after the event insert and high-water update commit.
- `match.command.v1` retry behavior: identical client command content returns the original sequence/execute-tick receipt; conflicting content returns `idempotency_conflict`.
- Monotonic execute-tick rebasing and contiguous replay validation. Missing sequence evidence returns `command_stream_gap`.
- Restart-safe reconnect records; stored grace deadlines are not recomputed by repository construction.
- Idempotent terminal result receipt bound to contract ID/hash, epoch, and the exact durable command high-water mark.
- Durable outbox dedupe and idempotent delivery acknowledgement.
- `PostgresDurableCoreRepository` and parity-oriented `MemoryDurableCoreRepository` behind one interface.
- VS configuration and health posture for the core store, with a concrete 120-day retention floor and no deletion job.

## Deliberate integration boundary

ADR 003 assigns Package 2 the repository and restart behavior; Package 3 makes Standard 1v1 consume it. The existing `create_invite`, quick-match, `publish_intent`, and related legacy routes still acknowledge their in-memory maps. Package 2 does not shadow-write those routes because a split durable/in-memory acknowledgement would create false durability.

`VS_DURABLE_CORE_ENABLED=false`, `VS_DURABLE_STORE=memory`, and `public_1v1_enabled=false` remain the defaults. No rank, contest, economy, Crucible, or public-mode flag was enabled.

## Automated evidence

- VS TypeScript build: `PASS`.
- Embedded PostgreSQL migration with `pgcrypto`: `PASS`.
- Memory/PostgreSQL repository contract parity: `PASS` for contract creation, idempotency conflict, canonical command assignment, replay, reconnect state, and outbox creation.
- Fresh-repository restart proof: `PASS`; the second repository recovered the same contract/roster, contiguous commands 1–2, command high-water 2, original retry receipts, reconnect grace state, and pending outbox event.
- Terminal `NO_CONTEST` receipt and conflicting-result rejection: `PASS`.
- Repeated outbox acknowledgement: `PASS`; delivery attempts remained exactly one.
- Production dependency audit (`npm audit --omit=dev`): `PASS`, zero reported vulnerabilities.
- Existing VS player-auth, full service, quarantine/auth, spectator, and multiplayer suites: `PASS`.

## Staging gates

- Apply `npm run migrate` to an isolated instance of the same managed PostgreSQL version used in staging.
- Force VS process restarts and database connection loss while commands are being submitted; prove zero acknowledged-command loss.
- Run a concurrency test against command sequence allocation and contract idempotency. PGlite proves PostgreSQL semantics but not managed-database network or lock behavior under load.
- Pin backup/PITR, appeal, and final evidence-retention operations before implementing cleanup. No Package 2 cleanup path exists today, so it cannot prematurely delete evidence.
- Package 3 must migrate authenticated Standard 1v1 reads and writes as one route slice before `VS_DURABLE_CORE_ENABLED` can be considered for staging.

## Rollback

- Keep `VS_DURABLE_CORE_ENABLED=false`; the repository remains unreachable from gameplay routes.
- Use `VS_DURABLE_STORE=memory` only for repository tests, never as a public durability claim.
- Migration 001 is additive. Disable consumers and preserve rows for audit/replay rather than dropping tables.
