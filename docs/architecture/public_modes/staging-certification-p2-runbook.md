# P2 Managed PostgreSQL Recovery Runbook

- Status: `PASS`
- Candidate: `1beb3553f2e619fe41ae88e4cb2be71695b4f3e0`
- Deployment branch: `deploy/staging-cert-20260720`
- Provider: Render
- Environment: `My project` / `Certification`
- Source database: `swarmfront-cert-db` (`dpg-d9f68vn7f7vs73c0tal0-a`)
- Restore database: `swarmfront-cert-db-restore` (`dpg-d9f6chgs116c738bsdv0-a`)
- Engine: PostgreSQL 18
- Pre-change recovery point: PITR `AVAILABLE`, starts at 2026-07-20T18:12:10Z
- Provider logical export: `dpg-d9f68vn7f7vs73c0tal0-a/2026-07-20T18:17Z`
- Public/mutation enablement: `HOLD`

This rehearsal operates only on new certification databases. It must never use
the existing `entap-identity-rank-staging-db` connection string. Connection
strings remain in the Render CLI/provider secret path and are never printed,
committed, or placed in shell history.

## Expected migrations

VS, in lexical order:

1. `001_vs_durable_core.sql`
2. `002_authenticated_1v1.sql`
3. `003_match_verification.sql`
4. `004_standard_1v1_rank_settlement.sql`
5. `005_public_ctf_contracts.sql`
6. `006_public_contest_platform.sql`
7. `007_time_gauntlet_evidence.sql`
8. `008_crucible_settlement.sql`
9. `009_free_async_cohorts.sql`
10. `010_public_multiseat.sql`
11. `011_public_modes_operations.sql`

Rank, in lexical order:

1. `001_rank_init.sql`
2. `002_rank_audit.sql`
3. `003_player_identity.sql`
4. `004_identity_beta_constraints.sql`
5. `005_player_device_sessions.sql`
6. `006_public_contest_scope.sql`

Both runners record distinct filenames in `schema_migrations` and wrap each
individual migration in a transaction. A failed file rolls back before the
runner exits. Reapplication is supported by the filename uniqueness check and
must produce no new `applied migration` lines.

## Evidence sequence

1. Wait for the source database to report `available`.
2. Run `run_staging_db_recovery_checks.sh before`; record engine, empty-schema
   fingerprint, and bounded counts.
3. Trigger a Render logical export and wait until its provider ID and download
   are available. Do not migrate until this succeeds.
4. From an exact detached checkout of the candidate, run VS then Rank migration
   commands with the source connection supplied only through `DATABASE_URL` /
   `VS_DATABASE_URL` in that process.
5. Run the checks as `migrated`, verify all 17 filenames, and record the schema
   fingerprint and every table count.
6. Rerun both migration commands. Pass only if no migration is applied and the
   fingerprint/count summary is unchanged.
7. Trigger a post-migration logical export. Download it into a temporary local
   directory, compute SHA-256, and do not place the export in Git.
8. Create the distinct empty restore target and restore the export with the
   PostgreSQL 18 `pg_restore` client.
9. Run the checks as `restored`; require exact schema fingerprint, migration
   list, and bounded-count equality with `migrated`.
10. Exercise the controlled interruption below and record measured recovery.

## Preservation checks

The bounded-count comparison covers every `public` base table and emits no row
contents. The following evidence families are mandatory even when their count
is zero:

- ops configuration history, reconciliation runs, and alerts;
- match contracts, roster, reconnect state, and lifecycle events;
- command streams and command events;
- terminal results, idempotency receipts, and outbox events;
- verification jobs, runs, and signed receipts;
- Rank settlement jobs and attempts;
- contest evidence, results, placements, and cohort rows;
- Crucible accounts, escrow, transaction, journal, settlement, refund, and
  reversal rows; and
- Rank players, processed events, audit events, identity/device/session rows,
  and metadata.

## Controlled interruption and recovery

Safe boundary: after the restored target matches the source and no application
service points at either database.

1. Record `restart_requested_at` immediately before requesting a provider
   restart of the restore target.
2. Poll provider status until `available`; do not issue writes while status is
   transitional.
3. Record `available_at`, then require `SELECT 1`, rerun both migration runners,
   and run the checks as `recovered`.
4. Record `verified_at`. Recovery time is `verified_at - restart_requested_at`.

Stop immediately if restart targets the wrong database ID, any fingerprint or
count differs, a migration reapplies unexpectedly, credentials appear in
output, or the database does not return within the bounded provider window.
Do not compensate by deleting tables, editing migration history, or touching an
existing service/database.

## Redacted check command

```bash
CERT_DATABASE_URL="$CERT_DATABASE_URL" \
  scripts/dev/run_staging_db_recovery_checks.sh migrated
```

`CERT_DATABASE_URL` is populated in-process from Render's authenticated CLI
output and must never be echoed.

## Observed results

| Check | Result | Evidence |
| --- | --- | --- |
| Empty source baseline | `PASS` | PostgreSQL `18.4`; schema SHA-256 `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`; no tables or migrations |
| Pre-change backup | `PASS` | Render PITR reported `AVAILABLE` from 2026-07-20T18:12:10Z before migration |
| First TLS attempt | `STOPPED SAFE` | Node client rejected the external URL with `SSL/TLS required`; empty fingerprint remained unchanged |
| First migration apply | `PASS` | All 11 VS and 6 Rank files applied from detached candidate `1beb355`; TLS verification explicitly required |
| Idempotent reapply | `PASS` | Both exact runners emitted no `applied migration` lines; fingerprint/counts unchanged |
| Migrated schema | `PASS` | SHA-256 `e8cdc990973c29dee564ef4b6756ada0b6c4034cc7d3f6a5a2a4f502b56478c3`; 17 migration rows |
| Bounded seed counts | `PASS` | `rank_audit_events=1`, `vs_crucible_accounts=2`, all other application tables `0`; no row contents emitted |
| Local PostgreSQL 18 dump | `PASS` | Custom-format SHA-256 `a9e39db57dc449484d6669bc2980277dc746dc516ba7a0c54cf947314ba2039d`; 176,649 bytes; retained outside Git |
| Provider logical export | `PASS` | Export ID above; SHA-256 `e101d71937d2bf4068cc4df5ef713894211beb37ed6b2d275d6239dc4fe022de`; 23,802 bytes |
| Fresh restore | `PASS` | Restore target fingerprint, all 17 filenames, and every bounded count exactly match migrated source |
| Controlled interruption | `PASS WITH OBSERVATION` | Restart requested 18:19:21Z; provider said available 18:19:28Z but TLS was not ready; connectivity 18:20:04Z; full verification 18:20:12Z |
| Existing database isolation | `PASS` | Existing Rank DB remained `available` with unchanged provider `updatedAt` 2026-06-25T22:36:25.431367Z |

Measured recovery was 43 seconds to successful SQL connectivity and 51 seconds
to completed migration/fingerprint verification. Operational readiness must use
a real SQL probe after restart; Render's `available` status alone was seven
seconds early in this rehearsal.
