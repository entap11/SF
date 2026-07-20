# Package 4 Evidence Report — Trusted Standard 1v1 Result Authority

Date: 2026-07-18
Implementation result: `PASS WITH STAGING GATES`
Public release result: `HOLD`

## Delivered

- Additive PostgreSQL migration `003_match_verification.sql` for authenticated
  client terminal diagnostics, stable verification jobs, expiring leases,
  attempt/run evidence, and detached ES256 signed receipts.
- One semantic verification repository with memory and PostgreSQL adapters.
  PostgreSQL report quorum, job creation, lease, signed completion, terminal
  receipt, and contract transition are durable and transactional.
- Player-owned terminal-report and result-read routes. Token `sub` owns access;
  an outsider cannot read the result and a player credential cannot cross the
  verifier-worker boundary.
- A separately deployable `tools/match-authority` worker. It checks the pinned
  worker/simulation IDs and raw SHA-256 map/rules artifacts, runs the same
  `OpsState`/`SimRunner` headless replay twice from tick zero, derives placements,
  and signs canonical sync-result-v1 evidence with a private key unavailable to
  VS and Godot.
- Exact receipt binding to stable result ID, contract/match/epoch/hash, authority
  method, command high-water/hash, simulation build, worker build, issued time,
  and key ID. Unknown/forged signatures, stale epochs, changed verification
  input, malformed placements, and wrong content fail closed.
- Trusted replay disagreement produces signed `NO_CONTEST` with no placements.
  Client winner, elapsed time, and state-hash disagreement remain diagnostic and
  cannot select the authoritative result.
- Worker support for trusted `SERVER_LIFECYCLE` forfeit and no-contest events.
  Disconnect-expiry event creation remains server lifecycle authority and is
  deliberately scheduled with the later reconnect/forfeit release package.
- Stable completion retry: a fresh PostgreSQL repository returns the original
  terminal result and signed receipt and cannot insert a second result.
- Godot client seams to submit diagnostic terminal evidence and retrieve the
  existing verification state/receipt after reconnect or application restart.
- Independent `VS_MATCH_VERIFICATION_ENABLED` and server-owned authority-tier
  configuration. Every new and existing public, rank, and economy flag remains
  false by default.

## Automated evidence

- TypeScript builds for VS and match authority: `PASS`.
- Embedded PostgreSQL verification lifecycle: `PASS`; two reports, one job, one
  accepted run, one terminal result, and one signed receipt persisted.
- Signature and binding negatives: `PASS` for forged ES256 signature and signed
  stale epoch.
- Authenticated HTTP lifecycle: `PASS`; client claims named Player B, trusted
  receipt placed Player A first, outsider read failed, player worker access
  failed, and the signed receipt was retrievable.
- Real headless Godot replay: `PASS`; two runs ended at tick 18 with identical
  state hash `1f1b5b8c77cc57fce7623ed6b5cd1a28ea176fcd95b1bd275f1517e54ebaab33`.
- Worker negatives: `PASS` for wrong map bytes/hash and trusted replay
  disagreement to no-contest.
- Lifecycle fixtures: `PASS` for disconnect forfeit and server no-contest.
- Existing durable core, roster-v2 Standard 1v1, auth, quarantine, spectator,
  multiplayer, and legacy VS suites: `PASS`.
- Production dependency audits for VS and match authority: `PASS`; zero reported
  vulnerabilities at the configured audit threshold.

## Deliberate boundaries

- This package produces trusted Standard 1v1 result evidence only. It does not
  mutate Rank, Wax, escrow, contest boards, or rewards. Those are separate
  idempotent consumers in later packages.
- Disconnect grace is persisted, and the verifier understands trusted lifecycle
  terminal events, but the grace-expiry scheduler/authority-issued forfeit is not
  introduced here. No client can create a forfeit.
- Version 1 accepts one active verifier key. Rotation-overlap operations and
  retired-key rejection remain a staging/release requirement before public use.
- The supplied artifact manifest is an operational input, not an artifact
  registry/deployment pipeline. Production must publish immutable content and a
  reproducible worker image.
- The memory repository is test-only. No production or staging database was
  mutated, and no remote feature flag was enabled.

## Staging gates

- Apply migrations 001–003 to an isolated instance of the managed PostgreSQL
  version, then repeat completion across forced VS and worker termination.
- Publish a reproducible pinned worker image and immutable artifact manifest;
  prove map/rules/simulation artifacts are retained for the full evidence window.
- Run golden replays on every supported worker host and at production build
  settings; prove identical hashes and declared replay queue-delay/throughput SLO.
- Exercise command/map/rules/seed/contract mutation fixtures, all supported
  forfeit/no-contest reason codes, lease exhaustion, and operator alerting.
- Implement and test verifier-key overlap rotation, revocation, secret-store
  access policy, and audit trail.
- Complete two-physical-device terminal submission, app termination/reopen, and
  receipt recovery against staging while Rank/economy remain disabled.

## Rollback

- Keep `VS_MATCH_VERIFICATION_ENABLED=false` and
  `VS_PUBLIC_1V1_AUTHORITY_TIER=RELAY_ATTESTED`; keep every public/rank/economy
  mutation flag false.
- Stop the match-authority worker. Preserve jobs, runs, terminal results, and
  receipts for audit; do not drop migration 003 tables.
- The authenticated durable 1v1 lifecycle remains independently gated and can
  continue only as explicitly unranked/internal `RELAY_ATTESTED` testing.

## Proposed next package

Add the Standard 1v1 verified-result consumer and release-candidate layer:
server-to-server idempotent Rank settlement, pending/retry/reconciliation state,
authority-issued disconnect grace expiry, public Global Rank read/cache state,
and independent remote flags—still default false.
