# Render Reactivation Reuse Report

- Date: 2026-08-12
- Scope: repository and adjacent-project discovery only
- Live Render inspection: not performed in this phase
- Classification vocabulary: `REUSE`, `CONFIGURE`, `EXTEND`,
  `EXTRACT/ADAPT`, `NOT APPLICABLE`

## Result

Swarmfront already owns most of the release, database, authority, operations,
and native-client machinery needed to certify a restored Render stack. The
work is primarily to bind that machinery to one clean Godot 4.7.1 candidate,
fill the current topology/configuration delta, and rerun certification. There
is no evidence that a replacement deployment framework or a parallel test
runner should be built.

Operation Fury supplies useful general test-evidence conventions but no Render
service, deployment, database, migration, health, rollback, or authority-worker
implementation applicable to this restoration. The shared ENTaP repository is
also not a source of deployable infrastructure for this task.

## Reuse decisions

| Existing capability | Location | Decision | Required treatment |
| --- | --- | --- | --- |
| Fail-closed all-off preflight | `scripts/dev/run_staging_certification_preflight.sh` | `REUSE` | Run against the exact clean candidate and, later, deployment environment names/presence without printing values. Keep repository-only use separate from live Render discovery. |
| Certification topology recipe | `scripts/dev/provision_staging_certification_p3.rb` | `EXTRACT/ADAPT` | Treat as historical service/config inventory only. Do not run it: it creates services, roles, and secrets. Convert only confirmed facts into a reviewed deployment plan after estate discovery. |
| Managed PostgreSQL schema/recovery checks | `scripts/dev/run_staging_db_recovery_checks.sh` and the P2 runbook | `REUSE` | Preserve schema fingerprint, ordered migration list, and bounded counts. A future authorized rehearsal must remove or separately approve restart/export/write steps; none are authorized now. |
| VS migrations | `tools/vs-service/src/sql/migrations/001` through `011` | `REUSE` | Hash and bind the ordered set into the Candidate Release Manifest; apply only in a later authorized deployment phase. |
| Rank/identity migrations | `tools/rank-service/src/sql/migrations/001` through `006` | `REUSE` | Same treatment as VS migrations. |
| Deterministic match authority | `tools/match-authority`, `tools/match_authority_replay.gd`, fixtures | `CONFIGURE` + `EXTEND` | Keep double replay, artifact hash binding, signed receipts, and fail-closed paths. Replace 4.2.2 sample/build identities with the exact 4.7.1 candidate and certify the worker with that binary and artifacts. |
| Durable VS, lifecycle, reconnect, and public-mode smokes | `tools/vs-service` | `REUSE` | Retain existing build/smoke suites. Add the physical host/guest reconnect presentation matrix as separate evidence; automated lifecycle coverage is not a substitute for readable phone UI. |
| Rank/identity service and smokes | `tools/rank-service` | `REUSE` | Retain fail-closed identity and mutation gates. Native device credentials remain a release gate. |
| Release-readiness orchestration | `scripts/dev/run_release_readiness_gate.sh`, `run_beta_ops_gate.sh`, player configuration matrix, `.github/workflows/release-readiness.yml` | `CONFIGURE` + `EXTEND` | Pin Godot 4.7.1 and exact artifact identities, retain all-off checks, and add the candidate/deployment manifest linkage. Do not accept older 4.2.2 CI comments as evidence. |
| Remote operations config, history, reconciliation, alerts, and rollback | VS public-modes operations repository/routes and Package 12 evidence | `REUSE` | Keep history and rollback semantics. Start all public/economy gates false. A future deployment must prove administrative identity and database ownership before any activation. |
| Render blueprint | `render.yaml` | `EXTEND` | It currently describes only the staging Rank service and database. After read-only estate discovery, reconcile it or its successor with the minimum complete all-off topology; do not create a second authoritative topology description. |
| Android export/signing and protected credentials | export presets, Android build scripts, `native/android/secure-credentials` | `CONFIGURE` + `EXTEND` | Preserve keystore isolation and the existing physical-device gate. Confirm plugin/build compatibility with 4.7.1 and bind public signing identity plus artifact hash into the candidate manifest. |
| iOS export/signing and protected credentials | export presets, iOS build scripts, `native/ios/secure-credentials` | `CONFIGURE` + `EXTEND` | Rebuild the 4.2.2-targeted XCFramework against matching 4.7.1 headers/templates, then run the physical Secure Enclave/Keychain matrix. |
| Operation Fury performance/replay tools | `/Users/matthewballou/SideProjects/OMM` | `NOT APPLICABLE` | Do not copy them into this program. Swarmfront already owns its deterministic, soak, device, lifecycle, and authority evidence. |
| Shared ENTaP repository material | `/Users/matthewballou/SideProjects/ENTaP/project` and adjacent ENTaP content | `NOT APPLICABLE` | No deployable Render/service/database tooling was found. Do not invent a shared infrastructure dependency. |
| Render CLI read operations | installed Render CLI 2.22.0 | `REUSE` | Use only list/get/history operations in P2. Avoid interactive service views because they expose mutation actions. No deploy, restart, create, update, suspend, resume, or delete command is authorized. |

## Existing work that must not be rebuilt

1. All-off flag and credential-presence preflight.
2. Durable VS and identity schema migrations.
3. Schema fingerprint, migration-order, bounded-count, restore, and recovery
   evidence format.
4. Deterministic double-replay authority worker with signed receipts.
5. Private and public match lifecycle/reconnect smoke coverage.
6. Release-readiness, beta-ops, player-config, performance, and soak runners.
7. Remote-ops configuration history, reconciliation, alerts, and rollback
   contracts.
8. Android Keystore and iOS Secure Enclave/Keychain client seams.

## Reuse limits and unresolved ownership

- Historical certification evidence proves the earlier candidate only. It is
  methodology and baseline evidence, not proof for a 4.7.1 candidate.
- The authority examples and native credential documentation are explicitly
  pinned to Godot 4.2.2. They cannot be relabeled; they must be rebuilt and
  rerun under 4.7.1.
- `render.yaml` is not a complete stack declaration and cannot establish the
  live estate by itself.
- The historical provisioner is intentionally mutating. Its presence does not
  authorize reuse by execution.
- Normal Wax ownership, Honey production/ledger ownership, administrative
  identity, HCTF scope, and data retention remain unresolved as recorded in
  the ownership matrix. None may be inferred from a legacy file or memory
  implementation.

## P2 handoff

The read-only Render inventory must now determine which live resources can be
reused, reconfigured, upgraded, cloned, migrated, retired, or left untouched.
Only observed service/database/environment/deploy facts belong in that estate
inventory and, eventually, the linked Deployment Manifest.
