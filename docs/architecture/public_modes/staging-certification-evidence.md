# Public Modes Staging Certification Evidence

- Status: `IN PROGRESS — P3`
- Public enablement: `HOLD`
- Mutation/economy enablement: `HOLD`
- Branch: `sprint/staging-certification`
- Branch base: `b9c35e5e5b1d238c621fcb0fa39fdbdd72b5ad90`
- Started: 2026-07-20

This is the append-only summary for work performed under
[the staging certification plan](staging-certification-plan.md). `PASS` is used
only for observed evidence. Planned work remains `NOT RUN`.

## Decision matrix

| Phase | Status | Evidence anchor | Blocking item |
| --- | --- | --- | --- |
| P0 repository/control baseline | `PASS` | This document | — |
| P1 environment inventory | `PASS` | Render inventory and immutable candidate below | — |
| P2 database recovery rehearsal | `PASS` | [P2 runbook](staging-certification-p2-runbook.md) | — |
| P3 all-off deployment | `NOT RUN` | — | All-off services not yet created |
| P4 remote config/operations | `NOT RUN` | — | P3 |
| P5 authority/workers | `NOT RUN` | — | P3–P4 |
| P6 physical device matrix | `NOT RUN` | — | P3–P5 and devices |
| P7 canary recommendation | `NOT RUN` | — | P0–P6 |

## P0 repository/control baseline

### Repository identity

| Check | Observed value | Result |
| --- | --- | --- |
| Branch base | `b9c35e5e5b1d238c621fcb0fa39fdbdd72b5ad90` | `PASS` |
| Base contains Public Modes exit handoff | Merge commit `b9c35e5` | `PASS` |
| Base synchronized with `origin/main` at branch creation | Exact SHA match | `PASS` |
| Release Readiness for exact base | GitHub Actions run `29749297605`, SHA `b9c35e5e5b1d238c621fcb0fa39fdbdd72b5ad90` | `PASS` |
| Prior integrated Public Modes certification | Run `29722881367`, SHA `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc` | `PASS` |

The exact-base run remains the P0 gate even though the branch delta from the
previous green revision is documentation-only.

Exact-base run `29749297605` completed successfully on the home runner from
2026-07-20T15:26:16Z through 2026-07-20T15:53:42Z:

- MVP smoke: 26 passed, 0 failed;
- PR contract: 31 passed, 0 failed, 29 delegated runtime rows skipped;
- PR boot/runtime: 24 passed, 0 failed, 5 invalid rows skipped;
- deterministic PR soak: 18 passed, 0 failed, seeds 123–124; and
- final result: `RELEASE_READINESS_PASS`.

Branch-head run `29757549846` independently completed successfully at revision
`e8265616a0ce611b6490d719fc1ad019effaea18` from 2026-07-20T15:59:22Z through
2026-07-20T16:26:48Z. It reported the same result counts and final
`RELEASE_READINESS_PASS`, confirming the certification documentation, timeout,
and redacted preflight changes are green on the published branch.

### Named owners

| Role | Named owner/operator | Status |
| --- | --- | --- |
| Product owner | Matthew Ballou | Accountable |
| Repository operator | Codex, operating under Matthew Ballou's authorization | Acting |
| Environment operator | Matthew Ballou | Accountable |
| Database operator | Matthew Ballou | Accountable |
| Deployment operator | Matthew Ballou | Accountable |
| Security/credential owner | Matthew Ballou | Accountable |
| Device-test operator | Matthew Ballou | Accountable |
| Evidence reviewer | Matthew Ballou | Accountable; independent second reviewer preferred for P7 |

One person may hold multiple roles under the execution plan. Separation of
duties is not a P1 prerequisite, but the P7 recommendation should seek a second
reviewer if one is available before any public `GO` decision.

### Repository-visible default-off checks

| Check | Source | Result |
| --- | --- | --- |
| Bundled Public Modes flags false | `data/ops/ops_config_defaults.json` | `PASS` |
| Sample remote Public Modes flags false | `data/ops/ops_config_remote_sample.json` | `PASS` |
| Rank staging blueprint auto-deploy disabled | `render.yaml` | `PASS` |
| Rank mutation/reset/verified/public leaderboard caps false | `render.yaml` | `PASS` |
| Release Readiness workflow contains testing/artifact work, not deployment | `.github/workflows/release-readiness.yml` | `PASS` |

These checks describe repository files only. External dashboard settings must be
reconfirmed and recorded during P1; repository evidence cannot prove them.

At 2026-07-20T17:41:45Z, the authenticated Render CLI independently reported
`autoDeploy: no` and `autoDeployTrigger: off` for both existing web services,
`SF` and `entap-identity-rank-staging`. This read-only provider result closes
the external P0 gate. No deployment, restart, or service setting was changed.

### Local PR-tier supplemental evidence

The work Mac ran the same PR-tier workload locally on 2026-07-20. The original
wrapper stopped during soak because its 1,800-second matrix budget expired; no
scenario failure was reported. Boot routes had consumed 1,537.842 seconds,
leaving too little time for the declared two-seed soak workload. This branch
raises only the PR matrix wrapper to a bounded 2,700 seconds and preserves every
scenario and repetition.

The interrupted stages and an independent completion of the soak stage produced:

| Stage | Result | Detail |
| --- | --- | --- |
| MVP smoke | `PASS` | 26 passed, 0 failed |
| PR contract | `PASS` | 31 passed, 0 failed, 29 intentionally skipped delegated runtime rows |
| PR boot/runtime routes | `PASS` | 24 passed, 0 failed, 5 intentionally skipped invalid rows |
| PR deterministic soak | `PASS` | 18 passed, 0 failed, seeds 123–124 |
| Original wrapper | `TIMEOUT` | 1,800-second infrastructure budget; not a scenario failure |
| Updated wrapper syntax/help | `PASS` | PR budget 2,700 seconds |

The local reports are supplemental. The exact-base GitHub push workflow remains
the P0 authority.

### Scheduled nightly diagnostic

Scheduled run `29745742713` exercised the prior integrated revision
`1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc`. Its full matrix passed: 31 contract
checks, 24 boot/runtime rows, and 72 soak runs, all with zero failures. The
workflow then failed the separate legacy performance soak because observed
maximum process time was 54.30 ms against 45.00 ms and maximum tick time was
172.70 ms against 8.00 ms. The Godot process exited normally.

This is a disclosed performance diagnostic, not a Public Modes contract or
determinism failure. Performance Harness V1 remains an independent review; the
nightly result is not used to waive the exact-base push gate.

### P0 open items

- [x] Exact-base Release Readiness run completes successfully.
- [x] Environment owner recorded.
- [x] Database owner recorded.
- [x] Deployment operator recorded.
- [x] Security/credential owner recorded.
- [x] Device-test operator recorded.
- [x] Evidence reviewer recorded.
- [x] External auto-sync/auto-deploy posture reconfirmed without recording secrets.

## P1 environment inventory

Status: `PASS`

Record service/region identifiers, immutable artifact identities, redacted
capability values, credential trust roles, database recovery capabilities,
alert destination, retention, and rollback targets here.

### Render resource inventory

The environment operator authenticated the official Render CLI and selected
`Matt's workspace`. The following provider data was read at
2026-07-20T17:41:45Z. No sensitive connection strings or environment-variable
values were requested or recorded.

| Role | Render target | Placement / region | Current live revision | Prior rollback revision | Observed posture |
| --- | --- | --- | --- | --- | --- |
| VS | `SF` (`srv-d7uho16gvqtc73feh9s0`) | `My project` / `Production`; Oregon | Deploy `dep-d90aqv8jo6nc73cgdae0`; `676b70e839377b18aed9d2ff1cd5c8c0906c575f` | Deploy `dep-d905p6e7r5hc73b6ktn0`; `9bba4153fe726f88ba3b7aa3fae770faf2c64a53` | Free web service; branch `main`; auto-deploy off; public ingress; no configured health path |
| Rank | `entap-identity-rank-staging` (`srv-d8uqramrnols73fjl820`) | Not assigned to a project environment; Oregon | Deploy `dep-d9akqmlaeets73bp7n6g`; `73fbc032a6c0edb03908d6deb0f50ca10882621b` | Deploy `dep-d8uqrb6rnols73fjl8u0`; `2c9d8c2911f7bbc57f5cd2e119c67752c7b1d81b` | Starter web service; branch `main`; auto-deploy off; public ingress; health path `/health` |
| PostgreSQL | `entap-identity-rank-staging-db` (`dpg-d8uqqq6rnols73fjkoag-a`) | Not assigned to a project environment; Oregon | PostgreSQL 18; status `available` | PITR/backup details not yet exercised | `basic_256mb`; 15 GB; no HA; disk autoscaling off; external allow list currently `0.0.0.0/0` |
| Match authority | None found | — | — | — | `MISSING` for certification topology |

The VS service's two newest deployment attempts failed; the currently live
revision is the older successful `676b70e8` deployment shown above. Rank's
current deployment is live. These are inventory facts, not candidates approved
for P3.

The only Render project environment is `My project` / `Production`. It is
unprotected, cross-environment network isolation is disabled, and it contains
only the VS service. Rank and PostgreSQL are workspace-level resources outside
that environment. This confirms that the existing layout is not the isolated
certification topology proposed for P2–P6.

### Immutable certification candidate

The deployment branch `deploy/staging-cert-20260720` is pinned at
`1beb3553f2e619fe41ae88e4cb2be71695b4f3e0`. It is not advanced with the
certification evidence branch. Its runtime tree differs from the exact green
base `b9c35e5` only by release-readiness timeout and staging-preflight scripts;
gameplay, service, map, configuration, and Render runtime files are unchanged.

| Candidate input | Selected identity | SHA-256 |
| --- | --- | --- |
| VS source archive | Git tree under `tools/vs-service` at `1beb355` | `55cccabc683055d8fb5d460cdfffb878d9bd94b25d20be4313b8a53928327760` |
| Rank source archive | Git tree under `tools/rank-service` at `1beb355` | `474a226f3286042b6d347f43f4799522c428aa47e69e4ef70f51d48e326711ca` |
| Authority source archive | `tools/match-authority` plus replay entrypoint at `1beb355` | `1aab33cd811fdce38ea7f51fefb3c86d40e6a0d33e13398da9888eec38a1055a` |
| Godot simulation archive | `project.godot`, `scripts`, and replay entrypoint at `1beb355` | `01e2166ddf471d8bb494d3ec80699e12b41cdc2d57c60344200e987d5f083578` |
| Client source archive | project, export settings, scripts, scenes, data, and maps at `1beb355` | `93cf3b5d06c355a2ca2edb7cc40fb56c8bb03de29d4d6ab04240af19db983a2e` |
| Client build | Export build `2026071701`; short version `0.1.1` | Source archive above; signed binary digest deferred to P6 |
| Simulation build | Godot `4.2.stable.official.46dc27791`; ID `sf-sim-1beb355` | Simulation archive above |
| Standard 1v1 map | `MAP_closequarters__CQ2__1p` | `325e97a6677eb32e2f396fa9077b614c76a2150dad960243e8ae00b55909d14a` |
| Standard rules | `standard-v1` | `d7a78887b71c7d010db1b8ea1af84aa847ca877644878f6c3a0d96aed26aa57c` |
| Authority worker | ID `authority-worker-1beb355` | Authority source archive above; deployed artifact ID deferred to P5 |

Render native builds do not have a provider artifact or deploy ID before they
exist. P3 and P5 must bind each service to the pinned deployment branch and add
its actual deploy ID to this record. The signed Godot binary remains a P6
artifact. These are staged evidence handoffs, not mutable identity gaps.

### Isolated target topology

| Role | Exact target | Required posture before first use |
| --- | --- | --- |
| Environment | `My project` / `Certification` | Protected; network isolation requested; provider-plan rejection is a hard stop |
| VS | `swarmfront-cert-vs` | Oregon; `deploy/staging-cert-20260720`; manual deploy; all capabilities false |
| Rank | `swarmfront-cert-rank` | Oregon; same pinned branch; manual deploy; all mutation/public caps false |
| Match authority | `swarmfront-cert-authority` | Oregon background worker; pinned worker/sim/content manifest; no public ingress |
| Primary rehearsal database | `swarmfront-cert-db` | Paid PostgreSQL 18; isolated from existing Rank data; external access restricted |
| Fresh restore target | `swarmfront-cert-db-restore` | Empty paid PostgreSQL 18; temporary P2 restore/comparison target |

No existing service or database is moved into this environment. The existing
`SF`, `entap-identity-rank-staging`, and
`entap-identity-rank-staging-db` resources are read-only reference inventory
and are not migration, deployment, or recovery targets.

### Capability and credential posture

The Render API was queried locally and filtered before output so secret values
were never printed. All 27 VS capability variables and all four Rank capability
variables are absent on the existing services and therefore use their explicit
false code defaults. The target services will set every one of these values to
`false` rather than relying on absence.

Credential presence on the existing services is redacted:

| Service | Present | Absent |
| --- | --- | --- |
| VS | Legacy match-authority token | Database URL, admin token, verifier worker token/public key, player public key, VS-to-Rank private key |
| Rank | Database URL, Rank API token | Player signing pair, VS-to-Rank public key, verifier public key |

The target uses newly generated, certification-only credentials. No existing
credential is copied. Production-mode Rank refuses to start without its API
token and database URL; protected VS routes reject empty admin, authority, and
worker credentials; the authority worker exits with
`match_authority_not_configured` when any required worker/signing/artifact
credential is missing. This is the required fail-closed posture.

### Credential trust map

| Trust boundary | Private credential holder | Verifier / consumer | Scope |
| --- | --- | --- | --- |
| Player identity | Certification Rank only | VS receives public key only | Short-lived player/session JWTs |
| Ops admin | Environment operator only; injected into VS | VS admin endpoints | P4 config, reconciliation, rollback |
| VS-to-Rank | VS settlement worker only | Rank receives public key only | Verified result settlement |
| Authority worker lease | VS and authority worker | VS verification endpoints | Lease/complete/fail jobs only |
| Verifier signing | Authority worker only | VS and Rank receive public key only | Detached ES256 result receipts |
| Database | Render secret manager; service-specific roles | VS and Rank migration/runtime clients | Separate schemas/permissions; no client access |

Player, admin, authority, verifier, VS-to-Rank, and database credentials are
distinct. Godot clients receive only public player-verification material and
public service URLs; they never receive admin, worker, signing-private, Rank, or
database credentials.

### Recovery, alerting, retention, and commands

- P2 source is a new empty paid PostgreSQL 18 certification database, not a
  clone of live user data. A provider logical export and PITR recovery instance
  are the backup/restore evidence. Paid Render PostgreSQL provides PITR; use the
  conservative Hobby minimum of three days unless the Billing page proves the
  seven-day Pro window. Provider logical exports retain for seven days.
- The restore target is `swarmfront-cert-db-restore`. Database exports remain
  outside Git; only provider IDs, timestamps, bounded counts, and SHA-256
  digests enter this evidence record.
- Platform alert destination is the Render workspace-owner email with all
  notifications selected for certification services. Application alert rows
  remain support-visible in the authenticated P4 dashboard and must prove a
  real open/resolve cycle there.
- Use the conservative Hobby log and metric retention of seven days unless the
  provider reports a longer plan window. Evidence needed beyond that window is
  hashed and indexed outside raw service logs.
- Rollback revisions are the pinned candidate's immediately preceding live
  deploys recorded in the Render inventory. New certification services have no
  prior deploy until P3; their first known-good all-off deploy becomes the
  rollback target before any P4 configuration publication.

Exact redacted preflight and health commands:

```bash
scripts/dev/run_staging_certification_preflight.sh --environment
curl --fail --silent --show-error "$VS_HEALTH_URL/health"
curl --fail --silent --show-error "$RANK_HEALTH_URL/health"
```

Capability and credential variables for the preflight are supplied only by the
operator's local environment or provider secret manager. URLs and secrets are
never committed.

### Read-only discovery completed during P0

- GitHub exposes environments named `main - entap-identity-rank-staging` and
  `main - entap-identity-rank-staging-db`.
- The latest repository-visible Rank staging deployment is deployment
  `5431008160`, revision `73fbc032a6c0edb03908d6deb0f50ca10882621b`,
  recorded successful on 2026-07-13. It is not the staging candidate for this
  sprint.
- Repository Actions variables and Actions secrets lists are empty. This says
  nothing about provider-managed secrets.
- At initial discovery this work machine had no Render CLI/API identity and no
  VS/Rank database or staging endpoint variables present. The CLI is now
  authenticated; no secrets have been copied into the repository or evidence.
- No repository-visible VS or match-authority deployment environment was found.
- `scripts/dev/run_staging_certification_preflight.sh` passes the repository and
  local environment checks, reports all local capability variables absent with
  false code defaults, and reports credential presence only as absent. A
  deliberate `VS_ENABLE_PUBLIC_1V1=true` test fails closed as required.

The P1 inventory is complete. Actual environment/resource creation begins in
P2 under the explicit product-owner authorization issued on 2026-07-20.

## P2 database migration and recovery

Status: `PASS`

The protected, network-isolated `Certification` environment was created as
`evm-d9f68mos116c738bmf60`. Two new paid PostgreSQL 18 instances were created
inside it; no existing service or database was changed:

| Role | Provider ID | Result |
| --- | --- | --- |
| Migration source | `dpg-d9f68vn7f7vs73c0tal0-a` | `PASS` |
| Fresh restore/interruption target | `dpg-d9f6chgs116c738bsdv0-a` | `PASS` |

All 11 VS and six Rank migrations applied from exact candidate `1beb355`, then
reapplied idempotently. Source, restored, and recovered schema fingerprints are
identical at
`e8cdc990973c29dee564ef4b6756ada0b6c4034cc7d3f6a5a2a4f502b56478c3`.
All bounded table counts matched. The only seed rows are one Rank audit row and
two Crucible account rows created by the migrations.

The controlled restore-target restart took 43 seconds to real SQL connectivity
and 51 seconds to complete verification. Render reported `available` after
seven seconds while TLS connections still failed; future restart checks must
use SQL connectivity rather than provider status alone. Full commands, backup
digests, preservation families, failure history, and timing are recorded in the
[P2 runbook](staging-certification-p2-runbook.md).

## P3 manual all-off deployment

Status: `NOT RUN`

No service has been deployed or restarted by this sprint.

## P4 remote configuration and operations

Status: `NOT RUN`

No remote configuration revision has been published by this sprint.

## P5 authority and workers

Status: `NOT RUN`

No external worker has been started or modified by this sprint.

## P6 physical devices

Status: `NOT RUN`

No physical-device certification evidence has been collected by this sprint.

## P7 decision

Status: `HOLD`

No public mode or mutation/economy capability is authorized.

## Artifact index

| Artifact | External ID | SHA-256 | Created UTC | Retention | Owner |
| --- | --- | --- | --- | --- | --- |
| Local MVP smoke log | `/tmp/swarmfront_mvp_smoke.log` | `65ceaf30d5a3502c42f0f451577af66fc7fb2e1989a014125e179c80c8957fb7` | 2026-07-20T15:07:08Z | Ephemeral work machine | Repository operator |
| Local PR contract report | `artifacts/player_config_matrix/latest.json` | `99ecf4846a6464bcd8bc9b5590dd43f19bb9d4ab8d2be5afb0d33b201262473d` | 2026-07-20T14:51:44Z | Ephemeral work machine | Repository operator |
| Local PR boot report | `artifacts/player_config_matrix/boot_routes_latest.json` | `0b712221c9fe3ebfa83b115f43f3c41daa70b2a08ced809411300ddeebecd7e2` | 2026-07-20T15:17:39Z | Ephemeral work machine | Repository operator |
| Local PR soak report | `artifacts/player_config_matrix/soak_latest.json` | `1a351cd52f389f525f06cec12164ff42e76494461d981c37ea838af30a990c50` | 2026-07-20T15:37:27Z | Ephemeral work machine | Repository operator |
| Exact-base PR matrix | GitHub artifact `8467182728` | `7ac3f3aa69b67cd10adc6e63e315eefe82ae1e9d546f64891705bc62faa95d60` | 2026-07-20T15:53:36Z | 2026-10-18 | GitHub Actions |
| Exact-base smoke logs | GitHub artifact `8467183582` | `8f937c28c43288429d163fa86e468bd6faca8d599cdcb027ebcfc55e761ebf9c` | 2026-07-20T15:53:37Z | 2026-10-18 | GitHub Actions |
| Branch-head PR matrix | GitHub artifact `8468173706` | `52ee41c38098216305fda12d7e2730313bba57012d40557fb23a693027d4a656` | 2026-07-20T16:26:42Z | 2026-10-18 | GitHub Actions |
| Branch-head smoke logs | GitHub artifact `8468174477` | `8411b73458477a5512be5d2822d58cd6ad9445a8f4bf6a412a847e7359bc6286` | 2026-07-20T16:26:44Z | 2026-10-18 | GitHub Actions |
| Scheduled nightly matrix | GitHub artifact `8466303731` | `e09237236837e5811fb2153d1c00284f2fa3c70b5e402f51492ccac08a93dc05` | 2026-07-20T15:26:07Z | 2026-10-18 | GitHub Actions |
| Scheduled nightly smoke logs | GitHub artifact `8466304673` | `3e9fbd55866cfe4b3242830cf8e9a7f1d58b32ec4c21db9151ad3ecc99f49db8` | 2026-07-20T15:26:09Z | 2026-10-18 | GitHub Actions |
| P2 local PostgreSQL 18 dump | Temporary external file; source `dpg-d9f68vn7f7vs73c0tal0-a` | `a9e39db57dc449484d6669bc2980277dc746dc516ba7a0c54cf947314ba2039d` | 2026-07-20T18:17Z | Ephemeral; provider export/PITR are retained copies | Database operator |
| P2 Render logical export | `dpg-d9f68vn7f7vs73c0tal0-a/2026-07-20T18:17Z` | `e101d71937d2bf4068cc4df5ef713894211beb37ed6b2d275d6239dc4fe022de` | 2026-07-20T18:17Z | Render 7-day export window | Database operator |

Never put credentials, private keys, connection strings, raw database exports,
unredacted device identifiers, or user identifiers in this index.

## Limitations and maintenance outside this sprint

- Performance Harness V1 remains on its independent review branch and is not
  part of this staging branch.
- The future Corkscrew fixture opening-lane diagnostic remains separate map
  maintenance and is not selected by a Public Modes contract.
- Pre-existing Godot shader, resource UID, NUL-map, and teardown diagnostics are
  tracked separately unless their behavior changes during certification.
- GitHub action-version maintenance is separate unless it prevents the exact
  certification workflow from running.
