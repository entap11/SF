# Production Reactivation Readiness — 2026-08-17

Status: `PLAN READY — EXTERNAL MUTATION NOT AUTHORIZED`

This is a read-only production topology and data-preservation assessment made
after candidate `sf-4.7.1-b409fc9-20260817.2` passed the all-off certification
deployment. No production service, database, environment setting, secret,
plan, domain, deployment, or capability was changed.

## Current production facts

| Concern | Observed state | Required treatment |
| --- | --- | --- |
| Environment | `Production` / `evm-d7uho167r5hc73b4euhg`; unprotected; network isolation disabled | Protect and isolate under an explicitly authorized change window |
| VS | `SF` / `srv-d7uho16gvqtc73feh9s0`; Free; auto-deploy off; live `dep-d9vjg16gekts73fr8umg` at `be694dd` | Reuse, upgrade plan, bind exact candidate, retain current deploy as rollback anchor |
| VS persistence | Durable core disabled; memory VS/money stores; file Crucible/Honey stores | Bind a Production PostgreSQL durable core; file/memory stores remain non-authoritative |
| VS trust | Player authentication absent; verification disabled; remote ops disabled; admin auth absent | Configure scoped player, admin, Rank, and verifier trust before any public route exists |
| Rank | `entap-identity-rank-staging` / `srv-d8uqramrnols73fjl820`; Starter; outside Production; live `dep-d9akqmlaeets73bp7n6g` at `73fbc03` | Preserve and move/reconfigure at controlled cutover; do not relabel staging silently |
| Rank database | `dpg-d8uqqq6rnols73fjkoag-a`; PostgreSQL 18.4; 15 GB; outside Production | Preserve as source/rollback; migrate into a Production-scoped database |
| Authority | No Production worker | Create one separate exact-candidate worker; never share the certification worker |

The live Production VS still reports every public/economic flag false. Its
private-match compatibility route remains the only player-facing function in
scope before a separately authorized rollout.

## Legacy Rank data boundary

Only aggregate counts and schema identities were read. No player row, public
identifier, credential, key, token, or connection string was printed or
committed.

- Public tables: 5.
- Migration rows: 4, through `004_identity_beta_constraints.sql`.
- Schema SHA-256:
  `3c300c32b12f0ea28898f6a4f0ee5ac68b34505bf2edc6196ff2ec9184dbc8fe`.
- `rank_players`: 14 rows.
- `rank_audit_events`: 154 rows.
- `rank_meta`: 2 rows.
- `rank_processed_events`: 0 rows.

The database is not disposable. It lacks migrations
`005_player_device_sessions.sql` and `006_public_contest_scope.sql`, and it does
not contain the 11-table-family VS durable schema. Existing Rank and identity
records therefore require a controlled logical migration and count/hash/audit
reconciliation rather than a clean reset.

Render documents that services can be moved into project environments and
that protected/network-isolated environments impose security boundaries:
<https://render.com/docs/projects>. The current CLI reference states that a
PostgreSQL database's environment is immutable through the CLI:
<https://render.com/docs/cli-reference>. Until an administrator proves a
supported data-preserving database move, the safe plan is a new
Production-scoped database plus a rehearsed logical migration. The legacy
database remains untouched as the rollback source through certification.

## Minimum all-off target

1. Keep the existing `SF` service as the VS identity and rollback anchor.
2. Upgrade it from Free to a non-suspending production-suitable plan.
3. Protect the existing Production environment and enable network isolation.
4. Create one Production PostgreSQL primary and a separately retained recovery
   target or tested restore destination.
5. Apply the exact 17 ordered Rank/VS migrations and verify schema SHA-256
   `e8cdc990973c29dee564ef4b6756ada0b6c4034cc7d3f6a5a2a4f502b56478c3`.
6. Export, migrate, and reconcile the 14-player legacy Rank dataset without
   enabling Rank/economy mutation.
7. Move/reconfigure the existing Rank service into Production at cutover,
   preserving its domain and the legacy service/database rollback identities.
8. Create a separate Production authority worker bound to the exact certified
   Godot, map, rules, sim, and worker identities.
9. Configure scoped secrets and public keys. Rotate the existing Production
   match-authority credential before it is reused; an operator diagnostic
   displayed its value during this assessment, so it must now be treated as
   exposed. The value is not repeated or committed here.
10. Keep every public, Rank mutation, economy, Honey, Wax, Crucible settlement,
    contest, reward, leaderboard, spectator, CTF, HCTF, and async capability
    false.

This is reuse and migration of the current estate, not a parallel permanent
"Production v2."

## Proposed authorized execution order

### A. Protection and recovery preparation

- Record exact pre-change service deploys, environment settings, plan, domains,
  redacted configuration presence, database timestamps, schema, migrations,
  aggregate counts, and backup identity.
- Create and test a Production-scoped database recovery target.
- Protect/isolate Production and rotate scoped credentials without enabling a
  capability.

### B. Durable data and Rank cutover

- Apply migrations to the new empty Production database.
- Import the legacy Rank rows under a bounded transaction or maintenance
  window; run migration 005/006; reconcile counts, identifiers, audit history,
  and zero processed settlement events.
- Point the existing Rank service at the new database, deploy the superseding
  candidate, run identity/session/auth-negative checks, and observe rollback.

### C. Authority and VS

- Create/deploy the separate Production authority worker and prove deterministic
  managed replay.
- Reconfigure/deploy `SF` with durable core, player auth, verifier trust, remote
  operations, and all public/mutation caps false.
- Prove private-match compatibility, health, authentication negatives,
  persistence, restart, managed replay, and observed rollback/restoration for
  every changed component.

### D. Exit

- Produce an append-only Production Deployment Manifest linked to one immutable
  Candidate Release Manifest.
- Stop with all capabilities off. Public Standard 1v1 requires a later P7
  decision and separate `GO`.

## Pre-authorization blockers

1. The unchanged 1,800-second performance gate is not certified; the current
   host exceeded both thresholds under contention.
2. Physical iOS Secure Enclave and Android Keystore acceptance remains open.
   The plugins are present in both candidate applications, but the runtime
   player-session flow is not yet connected to `ProfileManager`, and
   additional-device/recovery UX remains intentionally unresolved under ADR
   001. A physical pass cannot be manufactured from the existing UI.
3. A newly published low-severity `body-parser <1.20.6` advisory appeared after
   candidate `.2` froze. The working branch now pins 1.20.6 in the VS lockfile;
   build, full smoke, and production audit pass with zero vulnerabilities.
   Because this is post-candidate work, production must use a superseding
   immutable candidate rather than silently changing `.2`.
4. The exposed Production match-authority credential requires an authorized,
   coordinated rotation before Production verification is configured.
5. Production mutation itself still requires explicit product-owner approval
   under ADR 005.
