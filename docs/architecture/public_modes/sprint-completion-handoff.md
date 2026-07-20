# Swarmfront Public Modes Sprint Completion Handoff

- Date: 2026-07-20
- Branch: `sprint/public-modes-readiness`
- Sprint status: `COMPLETE`
- Code implementation: `COMPLETE`
- Integration: `MERGED TO MAIN`
- Repository regression: `PASS — EXACT INTEGRATED REVISION`
- Public enablement: `HOLD`

## Outcome

All 13 sharpened packages (0–12) are represented by evidence reports and the
code-grounded execution program is implemented. The sprint was merged to
`main` by merge commit `b0b7bedd98b24b997fc3f2cd6170bfd4cfc236ba`.
The exact final integrated revision
`1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc` passed Release Readiness. This
completion record is not authorization to turn on a public or mutation flag.
Managed-environment, worker, alert-delivery, and physical-device evidence listed
in the package reports remains part of the next staging-certification sprint.

Every new public and mutation flag defaults false. No staging/production
database was migrated, no remote rollout revision was published, and no
deployment cap was enabled as part of this sprint.

## Branch rollback points

| Commit | Rollback boundary |
| --- | --- |
| `1ee1519` | Completed Packages 0–8 plus the pre-branch workspace checkpoint |
| `56871a2` | Package 9: exact durable Crucible Wax settlement |
| `4cd460a` | Package 10: free async 3/5-map rolling cohorts |
| `0f9a6ff` | Package 11: authenticated 3P FFA, 2v2, and 4P FFA |
| `a45d618` | Package 12: controlled rollout and operations |
| `5eecf19` | Cross-sprint regression record and health-contract stabilization |
| `1fb45b9` | Pre-merge gate evidence and merge authorization record |

Packages 9–12 each have an independent pushed implementation commit. Packages
0–8 were already complete when the dedicated sprint branch was created, so
their rollback boundary is the preserved baseline checkpoint rather than new
synthetic history.

## Full regression result

### VS service

`PASS`: TypeScript build; full service smoke; player authentication; economy
quarantine and fail-closed auth; spectator; multiplayer roster; durable core;
durable public 1v1/CTF; verification; Standard 1v1 release and rank settlement;
public Rank proxy; public contests; Crucible settlement; async cohorts;
multi-seat modes; public-mode operations; migrations 001–011.

The sweep found and corrected one integration mismatch: the quarantine smoke's
strict public-health allowlist now acknowledges the three new safe operations
fields. The quarantine suite was rerun after the correction and passed.

### Rank service

`PASS`: TypeScript build, player-token cryptography/scope, embedded device
session/restart and migrations 001–006, verified settlement, economy quarantine,
and production dependency audit (zero vulnerabilities).

`NOT RUN — ENVIRONMENT INPUT REQUIRED`: `smoke:identity` requires
`RANK_SMOKE_BASE_URL` or `SF_RANK_BACKEND_URL`. No live Rank candidate was
provided, so the test correctly stopped before external access. This is a
staging gate, not a repository regression.

### Match authority

`PASS`: TypeScript build, deterministic real-Godot replay, lifecycle forfeit and
no-contest, visible CTF replay, content/command-binding negatives, ES256 result,
and production dependency audit (zero vulnerabilities).

### Godot client/contracts

`PASS`: project parse/import; credential/session seam; durable 1v1 handshake;
non-1v1 roster; Rank mutation quarantine; outcome overlay; hidden CTF rules;
focused PvP map contract; contest comparator; weekly/monthly/seasonal Time
Puzzle and weekly Gauntlet contract; async cohort content; public contest/Dash
and leaderboard routes; human PvP boot; Crucible rules, escrow, settlement, and
online flow; remote-config success/failure/malformed/sample cases; and the new
public rollout/minimum-client/expired-cache contract.

Known pre-existing diagnostic: `map_mode_contract_smoke_test.gd` reports the
future Corkscrew sandbox fixture as unavailable because owner 2 has no opening
lane. The focused public PvP map contract passes. The Corkscrew fixture is not
selected by any public-mode contract in this sprint, but it should be repaired
or removed from the broad fixture sweep separately.

This diagnosis was reproduced at both the branch's recorded main baseline
`6caae7e` and handoff commit `5eecf19`. Both revisions reported the same failure:

```text
opening_lane_unavailable ... failures=[{ "owner_id": 2, "reason": "no_opening_lane" }]
```

The three inputs that determine this result are also byte-for-byte identical at
both revisions: the Corkscrew fixture blob is `00ecbd6`, the map-loader and
opening-lane validation blob is `0203f4f`, and the broad map-contract smoke blob
is `855d0a1`. This baseline replay proves the failure predates the sprint rather
than merely inferring it from the affected files.

Headless Godot continues to emit the existing NUL-map parsing, shader sampler,
resource UID, and exit-leak warnings in several UI tests. The named contract
tests exit successfully and these diagnostics predate the sprint.

## Final integrated Release Readiness evidence

The final required default-off regression ran against the exact integrated
revision, after the merge and both CI stabilization commits:

| Evidence | Recorded value |
| --- | --- |
| Sprint merge commit | `b0b7bedd98b24b997fc3f2cd6170bfd4cfc236ba` |
| Final tested `main` revision | `1e03a70dd9c5a63351e8f09a09d93bfabe06a4dc` |
| GitHub Actions run | [Release Readiness 29722881367](https://github.com/entap11/SF/actions/runs/29722881367) |
| Result | `success` |
| Job interval | `2026-07-20T06:52:23Z`–`2026-07-20T07:20:18Z` |
| MVP smoke | 26 passed, 0 failed |
| PR manifest validation | 31 contract/schema/parity checks passed, 0 failed; 29 runtime-route rows delegated to the separate route matrix |
| Boot/runtime route matrix | 50 passed, 0 failed |
| Deterministic soak | 18 passed, 0 failed; seeds 123–124 across 9 PR configurations |

The workflow checked out the final SHA, verified Godot, prepared required import
sidecars, ran the complete Release Readiness gate, collected smoke logs, and
uploaded both artifact sets. Every workflow step completed successfully on the
self-hosted `sf-macos-godot-home` runner (`macOS`, `ARM64`, `godot`).

Uploaded evidence metadata:

| Artifact | Artifact ID | SHA-256 digest | GitHub expiry |
| --- | --- | --- | --- |
| `player-config-matrix-29722881367` | `8453581958` | `b4bc5487ed495682dbde7bbba1a5e8536e6a984b771c70ba58f305b0a7c8db95` | 2026-10-18 |
| `smoke-logs-29722881367` | `8453582428` | `0358f02ee4ab4b1379453c1670d27289b07c0751029b7361522f5f3e7a768f13` | 2026-10-18 |

The result counts, exact revision, run URL, artifact identifiers, and artifact
digests are preserved here so the permanent sprint record does not depend on
the downloadable artifacts remaining within their retention window. Package
reports remain versioned on this branch.

## Public rollout prerequisites

- Apply migrations to an isolated managed-PostgreSQL clone; prove backup/restore
  and service interruption recovery before production migration.
- Deploy immutable VS, Rank, and authority-worker builds with distinct player,
  admin, match-authority, verifier, and service credentials.
- Set all deployment mode/mutation caps false, then enable
  `VS_ENABLE_REMOTE_OPS_CONFIG=true`; publish an expiring all-false revision and
  exercise authenticated rollback before opening one mode.
- Configure the production minimum client build and a reconciliation interval;
  integrate durable alerts with an actual paging/notification destination.
- Complete the package device matrix: iOS/iOS, Android/Android, mixed platform,
  Wi-Fi/cellular transition, background/foreground, terminate/reopen,
  reconnect inside/outside grace, and three/four-device multi-seat runs.
- Certify contest and match replay workers against the exact immutable map,
  rules, simulation, and client hashes selected for deployment.
- Import/reconcile production Wax balances before Crucible; keep
  `enable_crucible_wax_settlement`, `enable_rank_mutations`, and
  `enable_contest_rewards` false until their independent mutation evidence is
  accepted.

## Merge and deployment-safety record

The product owner explicitly approved the merge after confirming in the Render
dashboard that all auto-sync, auto-deploy, and similar automatic publication
controls had been disabled before the sprint began. The branch was merged
non-destructively; its second parent is the recorded sprint tip `1fb45b9`.

The GitHub deployments API returns no deployment record for the final tested
revision. That repository-visible check does not prove third-party settings by
itself, so it is recorded together with the product owner's Render-dashboard
attestation rather than used as a substitute for it.

### Repository-visible deployment audit

- A push to `main` triggers `.github/workflows/release-readiness.yml`, which
  checks out the revision, runs the release-readiness test gate, and uploads test
  artifacts. It contains no service deployment, worker publication, migration,
  or remote-config publication step.
- The only repository Render blueprint is `render.yaml`. It describes the Rank
  staging service and sets `autoDeploy: false`; it does not describe the VS
  service or match-authority worker.
- The VS start command starts the HTTP service and does not call its migration
  runner. The match-authority start command starts the worker and has no schema
  migration path. Remote configuration changes require an authenticated publish
  action and are not performed on process startup.
- The Rank service **does call `RankStore.init()` on startup, and that method
  runs Rank migrations**. This is harmless on merge while Render auto-deploy is
  genuinely disabled, but it makes any later Rank deployment/restart a migration
  event that must be explicitly scheduled and backed up.
- Repository files cannot prove settings in an externally configured Render,
  GitHub App, or other deployment dashboard. For this merge, the account owner
  supplied that external confirmation before the push.

The remote `sprint/public-modes-readiness` branch is intentionally retained as
the package-by-package rollback and evidence branch. It must not be deleted
without a future explicit reason and product-owner direction.

## Proposed next step

Open a staging-certification sprint. Keep every public-mode and mutation/economy
flag false; use manual, controlled deployments; capture managed-database
migration and restore evidence; use real service-to-service credentials; run the
physical device matrix; and prove rollback. This is staging certification, not
public enablement.
