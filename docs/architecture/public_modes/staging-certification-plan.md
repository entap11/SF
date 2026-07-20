# Public Modes Staging Certification Plan

- Program: Public Modes staging certification
- Start date: 2026-07-20
- Branch: `sprint/staging-certification`
- Base revision: `b9c35e5e5b1d238c621fcb0fa39fdbdd72b5ad90`
- Public enablement: `HOLD`
- Mutation/economy enablement: `HOLD`
- Current phase: `P0 — repository and control baseline`

## Objective

Certify the already-implemented Public Modes stack in an isolated staging
environment while every public-mode and mutation/economy capability remains
off. This sprint proves infrastructure, recovery, authentication, immutable
artifact identity, remote-config rollback, worker correctness, device behavior,
and operational containment. It does not authorize a public launch.

The living result record is
[staging-certification-evidence.md](staging-certification-evidence.md). Evidence
must describe what actually ran; placeholders and planned commands are never
recorded as passes.

The phase-by-phase assignments, prerequisites, execution order, and commit
checkpoints are maintained in
[staging-certification-execution-worklist.md](staging-certification-execution-worklist.md).

## Authority and safety invariants

1. `OpsState`/`SimState` remains the only gameplay-state authority. Staging
   clients, input, UI, renderers, services, and evidence collectors may not
   create a second gameplay state or infer authoritative state from visuals.
2. All bundled Public Modes flags remain false. All remote Public Modes flags
   remain false through P0–P6.
3. All rank, Wax, contest reward, Honey, paid-entry, and reset mutation gates
   remain false for the entire sprint. Economic certification requires a
   separate program and explicit authorization.
4. No staging service is deployed or restarted until its immutable revision,
   environment diff, owner, rollback target, and health checks are recorded.
5. A Rank deploy or restart is a migration event because Rank initializes its
   store and runs migrations on startup. It requires the database rehearsal and
   recovery gates below.
6. No credential, private key, bearer token, connection string, device ID, or
   unredacted user identifier is committed to Git or copied into evidence.
7. Failed, missing, expired, or malformed remote configuration must resolve to
   all public and mutation flags false.
8. Evidence artifacts are append-only. Rollback creates a new recorded action;
   it does not erase configuration, migration, match, ledger, receipt, outbox,
   or alert history.

## Required default-off posture

Before every environment-changing phase, capture a redacted configuration
inventory proving these deployment capabilities are false:

- VS: `VS_ECONOMY_MUTATIONS_ENABLED`, `VS_ECONOMY_RESET_ENABLED`,
  `VS_DURABLE_CORE_ENABLED`, `VS_DURABLE_PUBLIC_1V1_ENABLED`, every
  `VS_ENABLE_PUBLIC_*` value, `VS_ENABLE_CRUCIBLE_WAX_SETTLEMENT`,
  `VS_ENABLE_RANK_MUTATIONS`, `VS_ENABLE_CONTEST_REWARDS`, and bot fallback.
- Rank: `RANK_ECONOMY_MUTATIONS_ENABLED`, `RANK_ECONOMY_RESET_ENABLED`,
  `RANK_VERIFIED_MATCH_MUTATIONS_ENABLED`, and
  `RANK_PUBLIC_LEADERBOARDS_ENABLED`.
- Client/remote config: all 16 canonical flags from Package 12 remain false.
- Deployment automation: auto-sync and auto-deploy remain disabled for every
  staging service.

`VS_ENABLE_REMOTE_OPS_CONFIG` may become true only in P4, after the deployment
caps above are proven false. Its first active revision must be expiring and
all-false.

## Phase plan and gates

### P0 — Repository and control baseline

Deliverables:

- Current `main` and branch SHAs, clean-tree state, and successful Release
  Readiness run for the exact branch base.
- Versioned staging plan and evidence record.
- Static confirmation that bundled and sample remote Public Modes flags are
  false and `render.yaml` keeps `autoDeploy: false`.
- Named environment owner, database owner, deployment operator, and evidence
  reviewer before P1 closes.

Exit gate: exact-base Release Readiness is green and the evidence record has no
unresolved default-off violation.

### P1 — Environment inventory and immutable identities

Record without changing external state:

- Staging service names and regions for VS, Rank, match authority, and database.
- Immutable source revision, build ID, image/artifact digest, Godot client build,
  map hash, ruleset hash, and simulation hash selected for certification.
- Redacted environment-variable presence and capability values.
- Credential trust map for player, ops admin, VS-to-Rank, authority worker,
  verifier signing, and database roles. Values are never recorded.
- Backup/PITR capability, retention, restore target, alert destination, and
  rollback target for each service.

Exit gate: inventory is complete; every capability is false; missing secrets or
services fail closed; deployment remains manual.

### P2 — Managed PostgreSQL migration and recovery rehearsal

Use an isolated clone/snapshot, never the production database:

1. Record engine/version, source snapshot identifier, schema-before digest, and
   row-count summary with no sensitive rows.
2. Take and verify a restorable backup.
3. Apply VS migrations 001–011 and Rank migrations 001–006 using the exact
   candidate revision.
4. Prove idempotent reapplication where the migration runners support it.
5. Restore into a fresh target and compare schema and bounded row-count
   summaries.
6. Exercise one controlled interruption and document the recovery procedure.
7. Verify append-only public-ops history, match evidence, receipts, outbox,
   settlement journals, and audit rows are preserved.

Exit gate: migrate, restore, and interruption recovery all pass with immutable
artifacts and a tested rollback procedure. No production-equivalent migration
may occur before this gate passes.

### P3 — Manual all-off service deployment

Deploy immutable staging candidates for VS, Rank, and match authority under
manual control. Rank is deployed only under the P2 migration procedure.

Required checks:

- Health endpoints report the intended revision and all public/mutation
  capabilities false.
- Authentication-negative tests fail closed.
- Service-to-service credentials have distinct subjects, scopes, audiences,
  keys, and rotation owners.
- Restart/reconnect behavior preserves durable state and does not create a
  client or renderer gameplay authority.
- Roll back each service to its recorded prior immutable revision, verify
  health, then restore the candidate.

Exit gate: deploy/restart/rollback evidence passes for all three services with
no enabled public surface or mutation path.

### P4 — All-false remote configuration and operations

With all deployment caps still false:

1. Enable `VS_ENABLE_REMOTE_OPS_CONFIG` and a non-zero reconciliation interval.
2. Prove missing active config fails closed.
3. Publish an expiring all-false revision with the selected minimum client
   build and an authenticated operator identity.
4. Verify client source/version/hash/expiry/minimum-build diagnostics.
5. Exercise history, expiry, malformed input, stale cache, append-only rollback,
   manual reconciliation, scheduled reconciliation, and alert open/resolve.
6. Prove rollback by publishing a new all-false revision copied from the prior
   known-good revision.

Exit gate: effective flags remain false through every success and failure path;
rollback and alert delivery are evidenced end to end.

### P5 — Authority and worker certification

- Run the trusted Godot replay worker against the selected map, ruleset,
  simulation, and client hashes.
- Verify command binding, ES256 receipt verification, lease/retry behavior,
  duplicate delivery, restart recovery, forfeit/no-contest, and evidence
  retention.
- Verify Rank rejects wrong issuer, audience, subject, key, worker build, and
  stale or duplicate receipts.
- Confirm no rank, Wax, Honey, contest reward, or paid-entry mutation occurs.

Exit gate: worker and verifier correctness pass against exact immutable hashes;
all mutation stores remain unchanged.

### P6 — Physical device and network matrix

Use staging-only accounts and non-economic modes while effective public flags
remain false or through a local authenticated test route that is not reachable
by public clients.

Required cells:

- iOS/iOS, Android/Android, and iOS/Android.
- Standard 1v1 plus 3-player FFA, 2v2, and 4-player FFA seat restoration.
- Wi-Fi to cellular and cellular to Wi-Fi transition.
- Background/foreground and terminate/reopen.
- Reconnect inside and outside the configured grace interval.
- Authority-worker interruption/recovery and service revision rollback during a
  bounded test.

Each cell records client builds, device/OS classes, network class, selected
contract hashes, timestamps, expected outcome, actual outcome, server receipt,
and redacted artifact links.

Exit gate: every required cell passes or has an explicitly accepted limitation;
no visual observation substitutes for authoritative state/receipt evidence.

### P7 — Non-economic canary recommendation

P7 is a decision package, not an automatic enablement step. Summarize P0–P6,
open limitations, support/alert readiness, rollback timing, and the exact one
non-economic mode proposed for a bounded canary. Rank, Wax, Crucible settlement,
contest rewards, Honey, paid entries, and all other modes remain off.

Exit gate: product owner issues a separate explicit `GO` or `HOLD`. Without that
decision, the result is `HOLD`.

## Stop conditions

Immediately stop environment-changing work and return every effective flag to
false if any of these occurs:

- an unexpected deployment, migration, public route, or mutation;
- an authority hash mismatch or evidence that UI/render/input mutated gameplay;
- a secret appears in logs or artifacts;
- backup restore cannot be proven;
- immutable build, map, ruleset, simulation, or client identity is unknown;
- remote configuration does not fail closed;
- worker receipts cannot be authenticated or deduplicated;
- alert delivery or rollback cannot be exercised;
- the exact branch revision fails Release Readiness.

## Evidence handling

- Store durable summaries in
  [staging-certification-evidence.md](staging-certification-evidence.md).
- Store large/redacted artifacts outside Git and record immutable IDs, SHA-256
  digests, creation time, retention expiry, and access owner.
- Use UTC timestamps and full Git SHAs.
- Record `NOT RUN`, `BLOCKED`, and `FAIL` explicitly; never use a blank field to
  imply success.
- Do not commit generated environment dumps, `.env` files, traces containing
  identifiers, database exports, or credentials.

## Sprint exit criteria

Staging certification is complete only when P0–P6 pass, the evidence index is
reviewed, rollback timing is known, and every disclosed limitation has an owner.
Completion authorizes preparation of a P7 canary decision only. It does not
authorize public or economic enablement.
