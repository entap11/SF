# Package 5 Evidence Report — Standard 1v1 Rank Settlement Candidate

Program mapping: Code-grounded readiness Program Package 6  
Date: 2026-07-19  
Implementation result: `PASS WITH DEVICE/STAGING GATES`  
Public release result: `HOLD`

## Delivered

- Additive PostgreSQL migration `004_standard_1v1_rank_settlement.sql` for one
  durable settlement job per verified result, expiring leases, retry alert
  thresholds, attempt evidence, error detail, and the committed Rank receipt.
- Reconciliation consumes only signed terminal receipts from frozen
  `STANDARD_1V1`, `AUTHORITY_VERIFIED` contracts whose rank policy is explicitly
  enabled. `NO_CONTEST` is retained as `NOT_APPLICABLE` and cannot mutate rank.
- Short-lived ES256 server-to-server authorization. Rank checks the exact VS
  issuer, audience, subject, key ID, scope, token lifetime, signature, and JTI.
  The public client has no service private key.
- A second independent trust check at Rank: the detached authority receipt is
  signature-verified and bound to result/match/contract/epoch/hash, authority
  method, terminal reason, placements, command evidence, simulation/worker
  builds, verification time, and verifier key before settlement.
- Rank event identity is the immutable verifier `result_id`. The existing Rank
  processed-event ledger and transaction boundary guarantee at-most-once mutation
  and audit creation across network retry or worker restart.
- Recoverable `rank_players_missing` behavior. A verified settlement remains in
  retry state until both canonical player identities exist in Rank; failure does
  not convert into a client-selected or locally calculated award.
- Authority-owned reconnect expiry. Durable server time converts an expired
  grace record into exactly one `MATCH_FORFEITED` lifecycle event and one
  `SERVER_LIFECYCLE` verification job; the client cannot declare the winner.
  If both players' grace periods have expired before resolution, the server
  issues `NO_CONTEST` instead of choosing an order-dependent winner.
- Public Global Rank primary and VS proxy reads with generation/cache-age,
  source, and stale labels. The proxy serves only a bounded server snapshot and
  returns unavailable when no eligible snapshot exists.
- The visible Rank panel's Global tab now consumes that shared board and states
  explicitly when no server snapshot is available; it does not substitute the
  local RankState leaderboard.
- Independent `enable_public_1v1`, `enable_rank_mutations`, and
  `enable_public_leaderboards` server flags. All default false. Public 1v1 also
  fails closed unless durable PostgreSQL, trusted verification, and
  `AUTHORITY_VERIFIED` contract configuration are active.
- A separately runnable VS settlement/reconciliation worker. No deployment,
  external database write, secret publication, or flag enablement was performed.

## Automated evidence

- Rank TypeScript build: `PASS`.
- VS TypeScript build: `PASS`.
- Embedded Rank settlement: `PASS`; ES256 service identity and authority receipt
  accepted, one mutation and one audit committed, and duplicate delivery created
  no second processed event or audit.
- Embedded Standard 1v1 release lifecycle: `PASS`; one expired disconnect grace,
  one server forfeit, simultaneous-expiry no-contest, two signed terminal
  results and settlement dispositions, a durable
  retry across a fresh repository instance (including beyond its alert
  threshold), and one idempotent settlement.
- Public Global Rank proxy: `PASS`; live primary labeling, bounded stale-server
  cache labeling, and fail-closed no-cache behavior.
- Durable authenticated Standard 1v1 embedded and HTTP suites: `PASS` after the
  public flag and trusted-authority preconditions were enforced.
- Godot project parse/import check: `PASS`; the public Rank panel changes load
  under the pinned Godot 4.2.2 editor build.
- Existing verification, durable-core, authentication, quarantine, spectator,
  multiplayer, legacy VS, Rank identity/session, and real-Godot
  authority-worker suites: `PASS`.
- Production dependency audits for VS, Rank, and match authority: `PASS`; zero
  reported vulnerabilities at the configured audit threshold.

## Deliberate boundaries and outstanding release evidence

- This is a code-level beta candidate, not public release authorization. The
  required two-physical-device search/play/disconnect/reconnect/finish/retrieve
  exercise has not been performed in this workspace, so the program exit gate
  remains open and the release posture remains `HOLD`.
- The three controls are environment-backed server flags in the current repo.
  Authenticated remote-config publication, history, and rollback remain Program
  Package 13 work. Their default-off behavior is already enforced here.
- No staging Rank or VS database was migrated. Managed-PostgreSQL migration,
  forced service termination, queue recovery, and settlement reconciliation
  still require isolated staging evidence.
- Version 1 pins one VS service key and one verifier key. Rotation overlap,
  revocation, secret-store policy, and operator audit remain staging blockers.
- The worker records retry state, but production metrics/alerts for pending age,
  attempt exhaustion, reconnect forfeits, and leaderboard cache age remain an
  operations package requirement.
- This package covers Standard 1v1 only. CTF/HCTF, bot fallback, contests,
  Crucible, and multi-seat modes are not authorized to use this rank consumer.

## Staging and physical-device gates

- Apply migrations 001–004 to an isolated managed-PostgreSQL clone; exercise
  migration backup/restore or a compensating migration plan before rollout.
- Deploy pinned VS, authority-worker, and Rank candidates with distinct service
  and verifier keys; verify negative issuer/audience/scope/key/build fixtures.
- Kill VS, Rank, and the settlement worker independently before and after the
  Rank commit; prove reconciliation returns the same event and no second award.
- Run iOS/iOS, Android/Android, and mixed iOS/Android Standard 1v1, including
  reconnect within grace, expiry outside grace, app termination/reopen, and
  retrieval of the same signed result and settlement status.
- Exercise live-board outage beyond the configured stale bound and verify the
  client displays unavailable; capture cache-age and pending-settlement metrics.
- Exercise one rollback with all three release flags independently returned to
  false while preserving contracts, results, settlement evidence, and audits.

## Rollback

- Keep `VS_ENABLE_PUBLIC_1V1=false`, `VS_ENABLE_RANK_MUTATIONS=false`,
  `VS_ENABLE_PUBLIC_LEADERBOARDS=false`,
  `RANK_VERIFIED_MATCH_MUTATIONS_ENABLED=false`, and
  `RANK_PUBLIC_LEADERBOARDS_ENABLED=false`.
- Stop the rank-settlement worker. Preserve pending jobs, attempts, signed
  results, and Rank audit rows for later reconciliation; do not drop migration
  004 tables.
- Match verification and the durable internal Standard 1v1 proof remain
  independently gated. Rank and economy mutations remain quarantined.

## Proposed next package

Implement human CTF/HCTF on the certified two-player contract/result path, keep
them initially unranked, and add an explicitly disclosed bot fallback only after
a bounded human-search timeout. Human and bot leaderboards must remain separate.
