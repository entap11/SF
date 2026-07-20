# Package 12 Evidence Report — Operations and Controlled Rollout

Program mapping: Sharpened readiness Program Package 12; code-grounded execution revision Package 13  
Date: 2026-07-19  
Implementation result: `PASS`  
Public release result: `HOLD`

## Delivered

- Migration `011_public_modes_operations.sql` adds an append-only configuration
  history with one active revision, publication identity/reason, idempotency,
  hash, expiry, minimum client build, previous-revision lineage, and explicit
  rollback lineage. Rollback creates a new audited revision; it never rewrites
  history.
- Remote publication, history, rollback, dashboard, and manual reconciliation
  actions require the configured ops-admin token and role. Missing admin auth or
  a missing PostgreSQL operations store fails closed.
- `GET /v1/public_ops_config` publishes only client-safe effective fields. The
  effective result is the intersection of deployment capabilities and the
  active remote flags, so a remote revision cannot enable code or authority
  infrastructure that was not deployed.
- `VS_ENABLE_REMOTE_OPS_CONFIG` is an outer deployment kill switch. When it is
  enabled, a missing/expired/unavailable active revision disables every public
  mode and mutation. Legacy test/dev deployments can retain static caps while
  this switch is false; production rollout certification requires it true.
- All 16 specified lowercase flags exist in the bundled defaults and remote
  sample and default false. Standard/multi-seat queues, CTF/HCTF, Crucible and
  Wax settlement, rank settlement, public rank reads, contest families, async
  cohorts, bot fallback, and leaderboard reads consume their independent gates.
- Public queue, contest, and rank endpoints enforce the active minimum client
  build. The frozen match contract uses the stricter of the deployment and
  remote minimums.
- Godot now resolves the bundled `vs://public_ops_config` address against the
  configured VS backend instead of shipping an empty remote URL. Release builds
  fail public surfaces closed when config is unavailable, expired, cached
  without an expiry, or above the client build. Debug-only local harnesses retain
  their fixture routes.
- `OpsConfig` exposes the source, version, hash, expiry, minimum build, blocker,
  and every effective public flag for support diagnostics. Main-menu human,
  Crucible, time/gauntlet/async leaderboard, and bot-practice routes consume
  those effective flags.
- Manual and optional scheduled reconciliation expire reconnect grace, reconcile
  public contests, retry rank settlement, verify the Crucible double-entry
  ledger, record a durable run, and maintain a durable critical ledger alert.
  The admin dashboard also reports queues, active matches, verifier/evidence
  backlog, undelivered messages, config history, recent runs, and open alerts.

## Automated evidence

- VS TypeScript build: `PASS`.
- Additive PostgreSQL migrations 001–011 under embedded PostgreSQL: `PASS`.
- Public modes operations repository smoke: `PASS`.
  - All canonical flags fail closed with no active revision.
  - Partial publication normalizes omitted flags false and rejects unknown flags.
  - Idempotent publication, singular-active history, expiry, append-only
    rollback, reconciliation records, and alert open/resolve behavior.
- Public modes operations HTTP smoke: `PASS`.
  - Client config fails closed when the authoritative store is unavailable.
  - Missing credentials and incorrect role cannot publish.
  - Correct credentials still fail closed without managed PostgreSQL.
- Godot public rollout smoke: `PASS`.
  - Bundled defaults all false, fresh eligible config, omitted-flag behavior,
    combined Crucible gates, minimum-client block, expired-cache block, and
    support-visible effective state.
- Focused durable 1v1/CTF, contest platform, rank proxy, Crucible settlement,
  human-PvP boot, and existing OpsConfig regression smokes: `PASS`.

## Operational publication sequence

1. Deploy migrations and authority services with all deployment caps false.
2. Configure admin auth, managed PostgreSQL, `VS_ENABLE_REMOTE_OPS_CONFIG=true`,
   and a non-zero reconciliation interval. Verify the public config source is
   `NO_ACTIVE_REMOTE_CONFIG` and all effective flags are false.
3. Publish an all-false, expiring revision with the production minimum client
   build; exercise history, dashboard, and rollback in staging.
4. Enable only one deployment cap and its matching remote mode flag. Mutation
   flags remain separate; Crucible requires both mode and settlement flags.
5. Watch queue, verification, evidence, outbox, reconciliation, and ledger
   signals. Roll back by publishing an audited copy of the last known-good
   revision, then disable the deployment cap if containment is required.

## Deliberate release gates

- No environment was migrated, no remote revision was published, and no public
  or mutation flag was enabled by this package.
- Managed PostgreSQL migration/backup restore, deployed HTTPS verification,
  configured reconciliation scheduling, alert delivery integration, exercised
  staging rollback, production build-number selection, and the physical device
  matrices from prior packages remain required before any mode is public.
- A successful code regression is not permission to enable Wax, rank, reward,
  or contest mutation flags. Those require their package-specific authority and
  accounting evidence as well as this rollout gate.

## Rollback

- Operational rollback: publish a new revision copied from a prior known-good
  revision, or publish all false. Preserve history, reconciliation runs, alerts,
  contracts, receipts, ledgers, and outbox records.
- Deployment rollback: set `VS_ENABLE_REMOTE_OPS_CONFIG=false` only while every
  static public/mutation cap is also false, then revert this package commit.
  Migration 011 is additive and should remain for audit.

## Proposed next step

Run the complete sprint regression across VS, rank, Godot contracts, migrations,
and package evidence; record known unrelated failures and produce the final
branch-to-main merge checklist. Do not merge or enable flags without explicit
approval.
