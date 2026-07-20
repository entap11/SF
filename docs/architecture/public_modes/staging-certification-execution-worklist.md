# Public Modes Staging Certification Execution Worklist

- Program: Public Modes staging certification
- Branch: `sprint/staging-certification`
- Base revision: `b9c35e5e5b1d238c621fcb0fa39fdbdd72b5ad90`
- Current phase: `P6 BLOCKED / P7 HOLD`
- Public enablement: `HOLD`
- Mutation/economy enablement: `HOLD`

This document turns the
[staging certification plan](staging-certification-plan.md) into an executable
work breakdown. The authoritative results belong in
[staging-certification-evidence.md](staging-certification-evidence.md); checking
an item here does not by itself constitute evidence.

## Completion strategy

Execute the phases in order:

`P0 → P1 → P2 → P3 → P4 → P5 → P6 → P7`

Do not overlap environment-changing phases. Repository preparation for a later
phase may happen early, but no migration, deployment, restart, remote-config
publication, or worker start occurs before the preceding exit gate is recorded.

Use one reviewable commit per phase. Preserve those commits as certification
and rollback boundaries. Large traces, database exports, credentials, and raw
device identifiers stay outside Git; only redacted summaries, immutable
artifact IDs, and digests are committed.

## Roles

One person may hold more than one role, but every role must be named in the
evidence record before P1 exits.

| Role | Responsibility |
| --- | --- |
| Product owner | Scope, risk acceptance, P7 `GO`/`HOLD`, economic boundary |
| Repository operator | Branches, commits, CI, static gates, evidence updates |
| Environment operator | Service settings, immutable deployments, rollbacks |
| Database operator | Clone/snapshot, backup, migration, restore, interruption recovery |
| Security/credential owner | Secret injection, key scope, rotation, redaction review |
| Device-test operator | Signed builds, devices, network/lifecycle matrix |
| Evidence reviewer | Independent check that each claimed pass has an artifact |

Codex may prepare repository changes, non-secret commands, tests, checklists,
artifact schemas, and evidence summaries. A credentialed operator must perform
dashboard actions, secret injection, managed-database operations, deployments,
and physical-device interaction. Codex must not request secret values for the
repository or evidence record.

## Inputs needed from the product/environment owner

These are identifiers and decisions, not secret values:

- [x] Names of the environment, database, deployment, credential, device, and
  evidence owners.
- [x] Staging provider and exact target identifiers for VS, Rank, match
  authority, and PostgreSQL.
- [x] Confirmation that all existing service auto-sync/auto-deploy controls are off.
- [x] Isolated PostgreSQL instance plan and permission to create a separate
  restore target.
- [x] Backup/PITR mechanism, retention window, and external artifact location.
- [x] Manual deployment and rollback access for all three services.
- [x] Alert destination capable of showing a real open and resolve event.
- [ ] Four staging-capable devices, ideally at least two iOS and two Android,
  or an explicit limitation if that inventory cannot be met.
- [ ] Signed staging client build and non-secret build number.
- [x] Exact initial map, ruleset, and simulation revision proposed for Standard
  1v1 certification.

If an input is unavailable, record `BLOCKED` or an accepted limitation. Do not
invent a substitute or convert missing evidence into a pass.

## P0 — Close the repository/control gate

Target outcome: a clean, pushed certification branch based on an exact green
`main`, with every repository-visible public/mutation gate false.

### Repository work

- [x] Create `sprint/staging-certification` from `b9c35e5`.
- [x] Add the staging plan and append-only evidence record.
- [x] Confirm the 16 canonical bundled and sample remote flags are false.
- [x] Confirm `render.yaml` declares `autoDeploy: false` and Rank mutation caps
  are false.
- [x] Record successful Release Readiness for exact base `b9c35e5`.
- [x] Add the run ID, tested SHA, result counts, artifact IDs, digests, and
  retention to the evidence record.
- [x] Record external provider auto-deploy confirmation; all named owners are recorded.
- [x] Push `sprint/staging-certification` and verify remote/local SHA equality.

### Exit artifact

Commit: `Close P0 staging repository gate`.

Pass only when the exact-base workflow is green, the branch is published, the
tree is clean, and all owners/default-off controls are recorded. If the queued
home-runner workflow fails or remains stuck, diagnose the runner/workflow; do
not cancel, replace, or waive the run without an evidence-backed decision.

## P1 — Inventory staging without changing it

Target outcome: one redacted inventory that makes every later command and
rollback target unambiguous.

### Repository work

- [x] Add a redacted repository/environment preflight at
  `scripts/dev/run_staging_certification_preflight.sh`; it prints credential
  presence only and fails if any capability is enabled or malformed.
- [x] Add an evidence table for service name, provider, region, source SHA,
  build/artifact digest, prior rollback revision, and health URL class.
- [x] Add the selected Godot build number plus map, ruleset, simulation, and
  manifest hashes.
- [x] Add a redacted capability matrix showing presence and effective boolean
  values; never copy secret values.
- [x] Add a trust map for player identity, ops admin, match authority, verifier,
  VS-to-Rank, and database roles.
- [x] Add backup/PITR, retention, restore target, alert target, and log retention
  entries.
- [x] Prepare exact preflight and health-check commands with secret placeholders
  supplied only through the operator's secret manager.

### Operator actions

- [x] Confirm external auto-sync/auto-deploy controls are off.
- [x] Confirm every existing VS and Rank capability gate is false by absent,
  explicit-false defaults; targets will set each value explicitly false.
- [x] Confirm services fail closed when required credentials are absent.
- [x] Confirm deployment and database rollback targets still exist.

### Exit artifact

Commit: `Record P1 staging environment inventory`.

Pass only when an evidence reviewer can identify every target, immutable
candidate, trust boundary, backup method, and rollback target without seeing a
secret. No external state changes are part of P1.

## P2 — Prove database migration and recovery

Target outcome: migrations 001–011 for VS and 001–006 for Rank are recoverable
on isolated managed PostgreSQL before any service deployment can run them.

### Repository preparation

- [x] Create a redacted migration run sheet containing source revision,
  database engine/version, clone/snapshot ID, backup ID, migration command
  version, and expected migration list.
- [x] Add schema-fingerprint and bounded row-count comparison commands that do
  not emit row contents.
- [x] Add a migration-result table covering first apply, supported idempotent
  reapply, fresh restore, and controlled interruption recovery.
- [x] Define preservation checks for ops history, match evidence, command
  streams, receipts, outbox, settlement journals, and audit rows.
- [x] Define recovery timing start/end points and the explicit stop condition.

### Operator actions

- [x] Create the isolated source instance and a distinct restore target.
- [x] Verify PITR before applying migrations and preserve logical exports.
- [x] Apply migrations using the exact candidate revision and secret-managed
  database connection.
- [x] Restore into the distinct target and compare fingerprints/counts.
- [x] Exercise one controlled interruption at an agreed safe boundary, then
  follow the written recovery procedure.
- [x] Confirm no existing database or publicly reachable service was touched.

### Exit artifact

Commit: `Record P2 managed database recovery certification`.

Pass requires verified backup, migration, restore, data-preservation checks,
interruption recovery, and measured recovery time. Additive migrations are
preserved for audit; application rollback does not destructively drop them.

## P3 — Deploy and roll back every service with all caps off

Target outcome: immutable Rank, VS, and match-authority candidates can be
manually deployed, health-checked, restarted, and rolled back without exposing
a public route or mutation.

### Deployment order

1. Reconfirm P2 backup and recovery evidence.
2. Deploy Rank under the migration procedure; a Rank restart is a migration
   event.
3. Deploy VS with durable/public/mutation caps false.
4. Deploy match authority without starting public workload consumption.
5. Run health and authentication-negative checks.
6. Roll back authority, VS, and Rank individually to recorded immutable
   revisions, verify health, then restore the candidates.

### Repository work

- [x] Add per-service preflight, deploy, health, rollback, and restore-candidate
  records with UTC timestamps and artifact digests.
- [x] Add a redacted capability assertion showing every effective public and
  mutation value false after each transition.
- [x] Add negative authentication, wrong audience/role, and missing credential
  results.
- [x] Record durable reconnect/restart checks and authoritative state hashes.

### Exit artifact

Commit: `Record P3 all-off deployment and rollback certification`.

Pass requires all three rollback drills, correct immutable identities, and zero
public or economic mutation. Any surprise deployment or migration stops P3.

## P4 — Certify all-false remote operations

Target outcome: remote configuration, reconciliation, dashboards, alerts, and
rollback work while effective features stay false.

### Execution order

- [x] Reconfirm every static deployment capability is false.
- [x] Enable only `VS_ENABLE_REMOTE_OPS_CONFIG` and the agreed non-zero
  reconciliation interval.
- [x] Prove no active revision returns `NO_ACTIVE_REMOTE_CONFIG` and all false.
- [x] Publish one authenticated, expiring, all-false revision with the selected
  minimum client build.
- [x] Verify client-visible source, version, hash, expiry, minimum build, and
  blocker diagnostics.
- [x] Exercise omitted/unknown flags, malformed input, stale cache, expiration,
  history, manual reconciliation, scheduled reconciliation, and alert
  open/resolve delivery.
- [x] Roll back by publishing a new audited all-false revision copied from the
  prior known-good revision.

### Exit artifact

Commit: `Record P4 remote operations fail-closed certification`.

Pass requires effective false values through every path, immutable append-only
history, authenticated rollback, and real alert delivery. Do not enable a mode
flag during P4.

## P5 — Certify authority, verification, and receipts

Target outcome: the trusted replay worker can process exact immutable contracts
and fail closed under identity, replay, restart, and duplication faults while
all mutation stores remain unchanged.

### Repository work

- [x] Produce the exact worker artifact manifest and SHA-256 digest.
- [x] Record map/ruleset/simulation/client hashes and verifier key ID; never
  record the private key.
- [x] Prepare positive replay plus wrong issuer, audience, subject, key ID,
  worker build, map hash, ruleset hash, simulation hash, stale receipt, duplicate
  receipt, lease expiry, restart, forfeit, and no-contest cases.
- [x] Record before/after bounded summaries for Rank, Wax, Honey, contest reward,
  paid-entry, ledger, receipt, and outbox state.

### Operator actions

- [x] Inject scoped worker/verifier credentials through the secret manager.
- [x] Start bounded staging workers and execute the case matrix.
- [x] Stop/restart the worker during an active lease and verify recovery.
- [x] Remove or disable the worker after certification.

### Exit artifact

Commit: `Record P5 authority worker certification`.

Pass requires authenticated/deduplicated receipts, exact contract identities,
restart recovery, event-driven evidence, and no economic mutation.

## P6 — Complete the physical-device matrix

Target outcome: staging clients demonstrate multiplayer seat, lifecycle,
network, reconnect, authority, and rollback behavior on real devices.

### Minimum device inventory

Preferred: two current supported iOS devices and two current supported Android
devices. Record model class and OS version, but redact unique device IDs.

Current blocker (2026-07-20): only one physical iPhone on iOS 26.5.2 is
connected; no Android device and no signed iOS/Android client candidate are
available. Simulators do not satisfy this gate. P6 remains blocked until the
minimum physical inventory and signed builds exist or the product owner accepts
an explicit limitation with impact and follow-up owner.

### Minimum scenario matrix

| Scenario | Devices | Required variation |
| --- | ---: | --- |
| Standard 1v1 | 2 | iOS/iOS, Android/Android, mixed |
| Standard 3P FFA | 3 | Mixed platforms, seat restore |
| Standard 2v2 | 4 | Mixed platforms, team/seat restore |
| Standard 4P FFA | 4 | Mixed platforms, all seat restores |
| Network transition | 2 | Wi-Fi→cellular and cellular→Wi-Fi |
| App lifecycle | 2 | Background/foreground and terminate/reopen |
| Reconnect timing | 2 | Inside and outside grace |
| Authority interruption | 2+ | Worker stop/restart during bounded match |
| Service rollback | 2+ | One immutable service rollback during bounded test |

This is a minimum coverage set, not a full Cartesian product. Run a failed cell
again only after preserving the first failure artifacts and recording the exact
change that justifies a rerun.

### Evidence per cell

- [ ] Client build and contract hashes.
- [ ] Redacted device/OS and network classes.
- [ ] UTC start/end, expected result, actual result, and authoritative receipt.
- [ ] Reconnect/seat/team outcome and server event identifiers.
- [ ] Relevant logs or traces with external artifact ID, digest, retention, and
  owner.
- [ ] Confirmation that effective public/mutation flags remained false or the
  test used an authenticated non-public staging route.

### Exit artifact

Commit: `Record P6 physical device certification`.

Pass requires every minimum cell or an explicit product-owner limitation with
impact and follow-up owner. Visual success alone is insufficient; authoritative
state hashes, receipts, and server events are required.

## P7 — Produce the canary go/hold package

Target outcome: a decision-ready summary, not an automatic rollout.

### Repository work

- [ ] Summarize P0–P6 status, limitations, failure history, artifact retention,
  measured rollback/recovery times, support readiness, and alert delivery.
- [ ] Verify the candidate source/build/map/ruleset/simulation identities still
  match the certified artifacts.
- [ ] Confirm all economic and non-candidate mode flags remain false.
- [ ] Propose bounded audience, duration, monitoring thresholds, rollback owner,
  and termination conditions.
- [ ] Record product-owner decision as `GO` or `HOLD`; default is `HOLD`.

### Recommended first candidate

Use non-economic Standard 1v1 because it has the narrowest roster, strongest
existing contract evidence, and smallest operational blast radius. This is a
recommendation only. Do not enable `enable_public_1v1` or its deployment cap
without a separate explicit `GO` after this package is reviewed.

Rank mutations, Wax, Crucible settlement, contest rewards, Honey, paid entries,
leaderboards, bot fallback, and every other mode remain off.

### Exit artifact

Commit: `Complete P7 public modes canary decision`.

The sprint is complete when the decision, all evidence links/digests, rollback
timing, limitations, and follow-up owners are committed and reviewed. A `GO`
authorizes only the separately defined bounded canary action; a `HOLD`
authorizes no environment change.

## Expected execution blocks

These are planning ranges, not deadlines:

| Block | Scope | Typical dependency |
| --- | --- | --- |
| 1 | Close P0 | Home runner and named owners |
| 2 | Complete P1 | Dashboard/read-only environment access |
| 3–4 | Complete P2 | Isolated database clone and database operator |
| 5 | Complete P3 | Manual deploy/rollback access |
| 6 | Complete P4 | Ops admin identity and alert destination |
| 7 | Complete P5 | Worker/verifier credentials and immutable manifest |
| 8–10 | Complete P6 | Four devices and signed staging build |
| 11 | Complete P7 | Evidence review and product-owner decision |

P2 is the highest-risk block. P6 is likely the longest. Do not compress either
by substituting embedded database tests, simulators, or visual observation for
the required managed-environment and physical-device evidence.

## Next executable action

Begin P5 by packaging the pinned headless Godot runtime and exact map/rules
manifest for `swarmfront-cert-authority`. Keep public, rank, reward, and economy
caps false while exercising authenticated lease ownership, duplicate delivery,
wrong worker/build/key/content identities, replay disagreement, receipt
verification, and worker interruption recovery.
