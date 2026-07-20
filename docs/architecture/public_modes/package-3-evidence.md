# Package 3 Evidence Report — Durable Authenticated Standard 1v1

Date: 2026-07-18
Implementation result: `PASS WITH STAGING GATES`
Public release result: `HOLD`

## Delivered

- Additive PostgreSQL migration `002_authenticated_1v1.sql` for authenticated Standard 1v1 queue tickets, request/compatibility hashes, expiry, atomic match assignment, and contract references.
- One durable repository slice covering queue, poll, cancel, canonical roster reads, ready, start, command publish/replay, leave, reconnect grace, and resume.
- Atomic PostgreSQL pairing with `FOR UPDATE SKIP LOCKED`; the winning transaction creates the frozen contract, roster v2 rows, command stream, and lifecycle evidence before acknowledging the match.
- Server-owned protocol/content policy, UUIDv7 contract/match IDs, seats, teams, colors, command sender, command sequence, and execution tick.
- JWT-subject ownership on every route. Conflicting body identity is rejected, signed display identity is retained, and outsiders cannot read or act on a match.
- Canonical `roster[]` responses with derived `host`/`guest` compatibility projections. Standard 1v1 remains explicitly unranked, non-economic, and `RELAY_ATTESTED`.
- Idempotent queue, lifecycle, and command receipts. A fresh PostgreSQL repository instance restores the matched ticket, readiness, running lifecycle, command stream, reconnect deadline, and original seat.
- Godot durable-route seam with strict protocol-v2 roster normalization. A remembered durable ticket/match transparently redirects existing lobby/runtime session and intent calls without changing the legacy local/private adapters.
- Separate `VS_DURABLE_PUBLIC_1V1_ENABLED` gate. It and `VS_DURABLE_CORE_ENABLED` default to `false`; `public_1v1_enabled` remains `false`.

## Automated evidence

- TypeScript build: `PASS`.
- Embedded PostgreSQL durable 1v1 lifecycle: `PASS`; two tickets produced one contract, six lifecycle events, one canonical command, and successful recovery through two fresh repository instances.
- Authenticated HTTP lifecycle: `PASS`; protocol/build rejection, token-owned roster, outsider denial, strict ready type, ready/start gating, sender/seat enforcement, command retry, contiguous opponent replay, leave, and resume all passed.
- Godot durable handshake seam: `PASS`; token gate, roster-canonical projection, server allocation preservation, and fail-closed malformed/roster-v1 decoding passed.
- Existing local multi-seat compatibility smoke: `PASS`.
- Existing VS service, player-auth, quarantine/fail-closed auth, spectator, multiplayer roster, and durable-core suites: `PASS`.
- Production dependency audit: `PASS`; zero reported vulnerabilities.

## Deliberate boundaries

- This package migrates only the authenticated Standard 1v1 route slice. Legacy quick match, invitations, and private/local flows are unchanged and do not claim durability.
- The durable slice does not verify a winner and cannot mutate Rank or Wax. Package 4 must add trusted result authority before any competitive settlement.
- The memory repository is a test adapter only. Production mode rejects an enabled durable core unless PostgreSQL is selected.
- No public flag was enabled and no production/staging database was mutated.

## Staging gates

- Apply both migrations to an isolated instance of the managed PostgreSQL version used by staging.
- Run concurrent queue/command load with forced process termination and database disconnects; prove no acknowledged match or command is lost and no player is paired twice.
- Run two physical authenticated devices through search, ready, start, play, background/foreground reconnect, and leave while forcing a VS restart.
- Pin the real client build, simulation build, ruleset hash, and map hash; a `dev` or empty content policy must remain rejected.
- Keep Rank/economy mutations quarantined until a trusted verifier returns an authority-signed terminal receipt.

## Rollback

- Keep `VS_DURABLE_PUBLIC_1V1_ENABLED=false` and `VS_DURABLE_CORE_ENABLED=false`.
- Preserve migration 002 rows for replay/audit; disable the route consumer rather than dropping evidence tables.
- The existing legacy/private adapters remain independent and are unaffected by disabling this slice.
