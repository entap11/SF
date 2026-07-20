# Package 7 Evidence Report — Durable Non-economic Contest Platform

Program mapping: Sharpened readiness Program Package 7; code-grounded execution revision Package 8  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- Migration `006_public_contest_platform.sql` adds server-authored contest
  definitions, immutable leaderboard IDs and definition hashes, authenticated
  roster entries, HMAC-bound attempt grants, verifier-authoritative results,
  best-per-player projections, final placements, and durable outbox messages.
- The non-economic contest repository is PostgreSQL-only. Public routes reject
  the memory adapter, and no code path imports `MoneyLedger`, bundled `.tres`
  contest resources, `ContestState.runtime_leaderboards`, or `user://` files.
- Server-owned definitions support the frozen `TIME_PUZZLE`, `GAUNTLET`, and
  `ASYNC_MAP_SET` families; weekly/monthly/seasonal/rolling scopes; 3/5/other
  map counts; exact content hashes; simulation build; comparator; attempt,
  closure, and eligibility policies; explicit UTC boundaries; and generation.
- `list_public_contests` filters the current open definitions by family, scope,
  and map count. `get_public_contest_roster` reads actual persisted entrants.
  Every public definition/board response is labeled
  `SERVER_PUBLIC_CONTEST_STORE`.
- `enter_public_contest` requires a player token with `contest:play`, derives
  the player UUID and display identity from that token, rejects a conflicting
  identity body, writes the real roster, and returns an idempotent server-issued
  attempt with a deadline, seed, pinned definition hash, and HMAC grant hash.
- `submit_public_contest_result` is isolated behind the existing match-authority
  service credential. A player/local client cannot write a public score. The
  repository validates attempt ownership, definition/grant hashes, server
  deadline, complete per-map timing, aggregate timing, and comparator inputs.
- `TIME_TOTAL_V1` and `GAUNTLET_STARS_V1` are implemented as server comparators.
  Worse later attempts remain in the immutable result log but cannot replace a
  player's best row. A board version increases only when its best projection
  changes, and deterministic tie ordering uses qualified time and player UUID.
- Server-time reconciliation opens scheduled definitions, closes elapsed
  definitions, snapshots placement, and can create the next fixed-interval
  generation without rewriting the historical board. Explicit weekly,
  monthly, and seasonal publication calendars remain Package 8 adapter work.
- Contest close and placement-message insertion share one PostgreSQL
  transaction. Top-three messages use the existing durable outbox with stable
  dedupe keys; read and acknowledgement are recipient-bound and acknowledgement
  is idempotent.
- Independent configuration was added for the contest API, grant secret, and
  leaderboard limit. `VS_ENABLE_PUBLIC_CONTESTS` defaults false and does not
  change any production or staging environment.

## API surface

Public server reads:

- `list_public_contests`
- `get_public_contest_roster`
- `get_public_contest_leaderboard`

Authenticated player actions:

- `enter_public_contest`
- `list_public_contest_messages`
- `ack_public_contest_message`

Trusted service/admin actions:

- `submit_public_contest_result` — match-authority credential
- `publish_public_contest` — admin credential and role
- `reconcile_public_contests` — admin credential and role

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–006 under embedded PostgreSQL: `PASS`.
- Public-contest platform smoke: `PASS`.
  - Two independent repository instances returned byte-equivalent boards.
  - A fresh repository instance restored roster, attempts, results, best rows,
    versions, receipts, and historical placement.
  - Same-key retries returned the original attempt/result; changed content
    produced `idempotency_conflict`.
  - A worse retry did not replace the player's best row or increment the board.
  - Server UTC closed generation 1 and opened generation 2; generation 1
    remained readable with final placement.
  - Top placement messages survived in the durable outbox and acknowledgement
    remained stable on retry.
  - Public output contained no `.tres` or `user://` provenance.
- Full VS regression pass: economy quarantine/fail-closed, player auth, durable
  core, durable 1v1/CTF, trusted verification, Standard 1v1 release settlement,
  public Rank, and public contest platform all `PASS` after migration 006.

Embedded evidence counts for the contest proof:

- 2 contest generations.
- 2 real roster entrants.
- 3 server-issued attempts and 3 immutable qualified results.
- 2 best-player rows and 2 final placements.
- 6 durable contest idempotency receipts.
- 2 durable placement messages.

## Deliberate boundaries and release gates

- This is the shared service layer; no Time Puzzle, Gauntlet, async, or Dash
  screen is publicly routed to it yet.
- The trusted commit boundary is present, but Package 8 must connect actual
  gameplay evidence to the service. No client-supplied clock, stars, completion,
  or aggregate time is public authority.
- Weekly/monthly/seasonal definitions, explicit season boundaries, 3/5-map
  content publication, and the frozen 18-stage Gauntlet plan are not seeded by
  this package. Fixed-interval rollover exists for platform/recovery proof; the
  product calendar adapter must publish explicit UTC periods.
- Rolling four-player closure on the fourth distinct qualified player is
  intentionally deferred to the async cohort package. The schema already keeps
  family, map count, roster, best policy, and closure policy separate.
- No managed PostgreSQL migration, backup/restore exercise, deployed service
  restart, or two-physical-device certification was performed. The embedded
  two-repository test proves storage semantics, not network/device readiness.
- No public flag was enabled. The release posture remains `HOLD`.

## Rollback

- Keep `VS_ENABLE_PUBLIC_CONTESTS=false`.
- If a staged adapter is stopped, block new entry/result commits while retaining
  definitions, attempts, results, projections, placements, receipts, and outbox
  records for support and reconciliation. Do not drop migration 006.
- Contest enablement is independent of public Rank, rank mutations, all
  economic mutation gates, and the existing CTF/1v1 controls.

## Proposed next package

Implement Package 8, Time Puzzles and weekly Gauntlet: publish explicit
weekly/monthly/seasonal 3-map and 5-map definitions, freeze actual map and
18-stage-plan hashes, connect trusted gameplay evidence to contest attempts,
reproduce the GDScript comparators with shared golden fixtures, and make Dash
the primary navigation and leaderboard surface.

