# Package 10 Evidence Report — Free Async Cohorts

Program mapping: Sharpened readiness Program Package 10; code-grounded execution revision Package 11  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- Free 3-map and 5-map contests are separate rolling cohort families:
  `ASYNC_3_ROLLING_4P_V1` and `ASYNC_5_ROLLING_4P_V1`.
- Migration `009_free_async_cohorts.sql` adds durable cohort capacity, lock,
  qualification, finalization, and immutable closure-snapshot state. Both
  families require exactly four authenticated players and have no escrow or
  payout fields.
- Cohort entry transactionally freezes the first four unique roster identities.
  A fifth player is rejected, while a roster member may retry within the
  attempt limit without changing their frozen identity.
- Only trusted result commits can qualify a run. Each player's best result is
  retained, and the fourth distinct qualifying result atomically closes the
  cohort, creates all placements and messages, freezes one closure snapshot,
  and opens the next generation.
- Timeout reconciliation closes a locked cohort with explicit DNF placements
  and messages. Every roster member receives a result message; the first three
  receive top-three copy. No Wax, money, or reward mutation is performed.
- Definitions freeze map order, map and pack hashes, rules/simulation hashes,
  attempt policy, cohort family/version, and the four-player closure policy.
  The client validates those hashes and policies before launch.
- Free 3-map and 5-map buttons now open the authenticated rolling-cohort Dash
  instead of starting a local fixture. Arena evidence submission supports the
  dedicated async map-set schema and remains behind the trusted verifier.
- `VS_ENABLE_PUBLIC_ASYNC_3MAP` and `VS_ENABLE_PUBLIC_ASYNC_5MAP` are
  independent, default-false gates exposed by health diagnostics.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–009 under embedded PostgreSQL: `PASS`.
- Durable async-cohort smoke: `PASS`.
  - Separate 3-map and 5-map definitions and contamination rejection.
  - Four real authenticated UUID identities, immutable roster, and fifth-player
    rejection.
  - Best-per-player retry behavior and atomic fourth-result closure.
  - One closure snapshot, four placements, four messages, three top-three
    messages, zero payouts, and automatic next generation.
  - Deadline DNF finalization and recovery through a new repository instance.
- Existing public-contest and economy-quarantine regressions: `PASS`.
- Godot rolling-cohort route, content hash/policy, and legacy time-puzzle route
  smokes: `PASS`.

## Authority and safety boundaries

- Player-authenticated callers can enter and submit evidence but cannot commit
  a trusted result, close a cohort, choose placements, or create messages.
- Roster identity is taken from authenticated entry and cannot be renamed by a
  retry request.
- Closure and rollover occur in the same serialized PostgreSQL transaction as
  the fourth best-result commit; unique keys keep retries idempotent.
- The free families reject payout definitions and produce an empty payout list.

## Deliberate release gates

- No environment was migrated and neither async feature flag was enabled.
- Managed-PostgreSQL concurrency/restart testing, production verifier-worker
  certification, outbox delivery observation, and mixed physical-device runs
  remain required before public release.
- The implementation is suitable for an internal/beta deployment after those
  environment-specific checks, but this repository-only pass cannot classify
  it as public ready.

## Rollback

- Keep both async cohort flags false. Preserve migration 009 and finalized
  snapshots for audit. Revert the package commit to restore the prior local
  free-roll route while server publication remains disabled.

## Proposed next package

Implement Package 11: durable authenticated 3-player FFA, friend-first 2v2
team assignment with rank balancing, and 4-player FFA over the synchronized
command and verifier path.
