# Swarmfront Public Modes Exit Report and Work-Machine Handoff

- Exit date: 2026-07-20
- Program: Public Modes Readiness, Packages 0–12
- Sprint status: `COMPLETE`
- Code integration: `MERGED TO MAIN`
- Repository certification: `GREEN`
- Public enablement: `HOLD`
- Evidence branch: `sprint/public-modes-readiness` — retain remotely

## Executive handoff

The Public Modes Readiness implementation sprint is complete. All 13 packages
are represented by versioned evidence reports, the implementation was merged
non-destructively to `main`, and the exact final integrated revision passed the
default-off Release Readiness workflow.

This is a code-sprint completion, not a public-launch authorization. No public
mode, mutation/economy capability, migration, or remote rollout configuration
should be enabled merely because the repository gate is green. The next body of
work is staging certification under manual operational control.

## Canonical repository anchors

| Purpose | Commit |
| --- | --- |
| Public Modes sprint merge | `b0b7bedd98b24b997fc3f2cd6170bfd4cfc236ba` |
| CI import preparation | `1ab84f72d54ccfef084feeaf1e0249f3d58e6b11` |
| Final certified `main` | `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc` |
| Pre-exit evidence branch head | `faa47cfa938a24e098151517df5b1cee0d559529` |

At exit, local `main`, `origin/main`, and the GitHub remote `main` ref all
resolved to `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc`. Both the main and Public
Modes sprint worktrees were clean. The commit containing this report is the next
commit on the retained evidence branch and is identifiable directly from that
branch's history; no self-referential hash placeholder is used in this file.

The independent `codex/perf-harness-v1-completion` branch is not part of this
sprint. Do not merge or rewrite it as part of Public Modes staging work without
reviewing its own handoff and scope.

## Final certification evidence

- Workflow: [Release Readiness run 29722881367](https://github.com/entap11/SF/actions/runs/29722881367)
- Tested SHA: `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc`
- Conclusion: `success`
- Job interval: `2026-07-20T06:52:23Z`–`2026-07-20T07:20:18Z`
- MVP smoke: 26 passed, 0 failed
- PR manifest contract/schema/parity checks: 31 passed, 0 failed
- Boot/runtime route matrix: 50 passed, 0 failed
- Deterministic PR soak: 18 passed, 0 failed across seeds 123–124

The workflow uploaded matrix and smoke-log artifacts. Their artifact IDs,
SHA-256 digests, and retention dates are recorded in
[the sprint completion handoff](sprint-completion-handoff.md), so the permanent
record does not depend on GitHub retaining the downloadable archives.

## Deployment and mutation posture

The repository remains default-off:

- every Public Modes flag defaults false;
- every mutation/economy flag defaults false;
- `render.yaml` declares `autoDeploy: false` for the repository-managed Rank
  staging service;
- the Release Readiness workflow tests and uploads artifacts but contains no
  deployment, worker publication, migration, or remote-config publication step;
- the GitHub deployments API returned zero deployments for both the sprint merge
  SHA and final certified SHA; and
- the product owner confirmed in Render before the sprint and again before the
  merge that auto-sync, auto-deploy, and similar automatic publication controls
  were disabled.

The external-dashboard confirmation matters: repository files and the GitHub
deployments API cannot independently prove every third-party control.

Do not casually deploy or restart Rank. Rank calls `RankStore.init()` during
startup, and that path runs Rank migrations. Any future Rank deployment or
restart must therefore be treated as a scheduled migration event with backup,
restore, and rollback preparation.

## Home runner dependency

Release Readiness currently targets `[self-hosted, macOS, godot]`. The registered
runner is `sf-macos-godot-home`, installed on the home Mac under
`/Users/home/actions-runner-sf` and launched as a user LaunchAgent. At exit it
was online with `self-hosted`, `macOS`, `ARM64`, and `godot` labels.

A push or pull request started from the work machine does not move execution to
that machine. The job will use the home runner. If the home Mac is asleep,
offline, logged out in a way that stops the LaunchAgent, or occupied by another
job, GitHub Actions will queue the run. Do not cancel and replace a queued run
until runner availability and other legitimate in-progress work have been
checked.

The workflow also has a daily scheduled run. The GitHub runner reported a
non-blocking Node.js 20 action deprecation annotation on the green certification
run; updating action versions is maintenance work, not a Public Modes sprint
failure.

## Known disclosed diagnostics

- The broad map-contract sweep reports the future Corkscrew sandbox fixture as
  unavailable because owner 2 has no opening lane. The same failure was
  reproduced at the branch's recorded baseline and handoff revisions with
  identical determining blobs. The focused Public PvP map contract passes, and
  no Public Modes contract selects Corkscrew.
- Headless Godot still emits existing shader sampler, resource UID, NUL-map
  parsing, and exit-leak diagnostics in several passing UI tests.
- These diagnostics are recorded, bounded, and not reasons to enable or disable
  staging features. Repairing or removing the Corkscrew fixture is separate
  maintenance work.

## Resume from the work machine

For a new clone:

```sh
git clone git@github.com:entap11/SF.git
cd SF
git fetch origin
git switch main
git pull --ff-only origin main
```

For an existing clone:

```sh
git status --short
git fetch origin
git switch main
git pull --ff-only origin main
```

Before starting new work, compare the remote to the certified anchor:

```sh
git rev-parse origin/main
git log --oneline 1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc..origin/main
```

At the time of this report, the first command should print the certified SHA and
the second should print nothing. If `origin/main` has advanced by pickup time,
review every intervening commit before creating the staging branch.

The retained evidence can be read without checking it out:

```sh
git show origin/sprint/public-modes-readiness:docs/architecture/public_modes/exit-report-and-work-handoff-2026-07-20.md
git show origin/sprint/public-modes-readiness:docs/architecture/public_modes/sprint-completion-handoff.md
```

After reviewing any newer `main` commits, create the next sprint from the latest
accepted remote `main`:

```sh
git switch main
git pull --ff-only origin main
git switch -c sprint/staging-certification
git push -u origin sprint/staging-certification
```

Do not delete `sprint/public-modes-readiness`. It is the retained package-by-
package rollback and evidence branch and should remain remote unless the product
owner later provides an explicit reason to remove it.

## Staging-certification entry contract

Begin staging certification with all of these controls intact:

1. Every public-mode flag remains off.
2. Every mutation/economy flag remains off.
3. Deployments are manual, controlled, and tied to immutable revisions.
4. Managed-database migration, backup, restore, and interruption-recovery
   evidence is captured before any production-equivalent migration.
5. Services use real, distinct service-to-service credentials with the intended
   scopes and trust boundaries.
6. The physical device matrix covers iOS/iOS, Android/Android, mixed platform,
   Wi-Fi/cellular transition, background/foreground, terminate/reopen,
   reconnect inside/outside grace, and three/four-device multi-seat runs.
7. Rollback is exercised and proven for service revisions, workers, database
   changes, and remote configuration.

Only after those controls are evidenced should a separate decision be made
about opening one non-economic mode. Economic mutation gates, including
Crucible Wax settlement, require their own explicit evidence and authorization.

## Source evidence index

- [Public Modes evidence index](README.md)
- [Sprint completion handoff](sprint-completion-handoff.md)
- [Package 0 evidence](package-0-evidence.md) through
  [Package 12 evidence](package-12-evidence.md)
- [Public match contracts v1](public-match-contracts-v1.md)
- [Public contest contracts v1](public-contest-contracts-v1.md)
- [Registries v1](registries-v1.md)

## Exit decision

The Public Modes Readiness sprint is closed as complete. The repository is
green at the recorded exact revision, the evidence branch is retained, and no
public enablement is authorized. The next authorized planning target is the
default-off staging-certification sprint described above.
