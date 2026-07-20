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
| P0 repository/control baseline | `IN PROGRESS` | This document | Exact-base Release Readiness queued |
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
| Release Readiness for exact base | GitHub Actions run `29749297605` | `QUEUED` |
| Prior integrated Public Modes certification | Run `29722881367`, SHA `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc` | `PASS` |

The exact-base run remains the P0 gate even though the branch delta from the
previous green revision is documentation-only.

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

### P0 open items

- [ ] Exact-base Release Readiness run completes successfully.
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
| None yet | — | — | — | — | — |

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
