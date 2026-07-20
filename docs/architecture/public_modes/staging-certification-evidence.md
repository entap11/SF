# Public Modes Staging Certification Evidence

- Status: `IN PROGRESS — P0`
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
| P0 repository/control baseline | `IN PROGRESS` | This document | Owners and external auto-deploy posture outstanding |
| P1 environment inventory | `NOT RUN` | — | P0 exit gate |
| P2 database recovery rehearsal | `NOT RUN` | — | P1 and staging clone details |
| P3 all-off deployment | `NOT RUN` | — | P2 and operator approval |
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
- [ ] Environment owner recorded.
- [ ] Database owner recorded.
- [ ] Deployment operator recorded.
- [ ] Evidence reviewer recorded.
- [ ] External auto-sync/auto-deploy posture reconfirmed without recording secrets.

## P1 environment inventory

Status: `NOT RUN`

Record service/region identifiers, immutable artifact identities, redacted
capability values, credential trust roles, database recovery capabilities,
alert destination, retention, and rollback targets here after P0 exits.

### Read-only discovery completed during P0

- GitHub exposes environments named `main - entap-identity-rank-staging` and
  `main - entap-identity-rank-staging-db`.
- The latest repository-visible Rank staging deployment is deployment
  `5431008160`, revision `73fbc032a6c0edb03908d6deb0f50ca10882621b`,
  recorded successful on 2026-07-13. It is not the staging candidate for this
  sprint.
- Repository Actions variables and Actions secrets lists are empty. This says
  nothing about provider-managed secrets.
- This work machine has no Render CLI/API identity and no VS/Rank database or
  staging endpoint variables present.
- No repository-visible VS or match-authority deployment environment was found.
- `scripts/dev/run_staging_certification_preflight.sh` passes the repository and
  local environment checks, reports all local capability variables absent with
  false code defaults, and reports credential presence only as absent. A
  deliberate `VS_ENABLE_PUBLIC_1V1=true` test fails closed as required.

These findings are inventory inputs only. P1 cannot pass until a credentialed
operator confirms provider settings, service identities, rollback targets,
backup/PITR, alert delivery, and the redacted trust map.

## P2 database migration and recovery

Status: `NOT RUN`

No managed database has been changed by this sprint.

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
| Scheduled nightly matrix | GitHub artifact `8466303731` | `e09237236837e5811fb2153d1c00284f2fa3c70b5e402f51492ccac08a93dc05` | 2026-07-20T15:26:07Z | 2026-10-18 | GitHub Actions |
| Scheduled nightly smoke logs | GitHub artifact `8466304673` | `3e9fbd55866cfe4b3242830cf8e9a7f1d58b32ec4c21db9151ad3ecc99f49db8` | 2026-07-20T15:26:09Z | 2026-10-18 | GitHub Actions |

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
