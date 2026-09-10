# Swarmfront Constitution v2.0 Adoption Audit

**Audit date:** 2026-09-03  
**Scope:** Current `project` working tree: Godot client/simulation, five Node service packages, migrations, configuration, CI/release scripts, and governance documents.  
**Standard:** `docs/coding_governance.md` plus `docs/project_governance_overlay.md`  
**Evidence level:** Static inspection, dependency audit, TypeScript builds, focused service smoke tests, and Godot parse/smoke checks. This is not field validation or production-readiness approval.

The worktree contained unrelated in-progress changes before this adoption. Those changes were preserved. Findings below describe the current combined working tree and do not attribute pre-existing code to this adoption.

## Executive result

Constitution v2.0 is installed verbatim and Swarmfront's stricter rules are preserved in the required overlay. Five high-confidence issues were corrected during the audit: embedded admin credentials, credential-bearing client URLs/profile persistence, known dependency advisories, unbounded server-to-server HTTP calls, and one shell-layer mutation of authoritative match statistics.

Swarmfront is **not yet Constitution-v2 Production Ready**. Public/economic release flags should remain disabled until the open release blockers below are closed or formally waived. The existing public-mode backend already contains strong authority, idempotency, transaction, immutable-evidence, and fail-closed foundations; the largest new gap is durable client intent/reconciliation across timeouts, restarts, and ambiguous responses.

## Corrected in this adoption

### A-01 — Universal governance and overlay

- Replaced the old 64-line Swarmfront coding governance file with the supplied 1,228-line Constitution v2.0; byte comparison against the supplied file passes.
- Added `docs/project_governance_overlay.md` with project identity, stack, authority and mutation registries, domain invariants, generated-file ownership, tests, release profiles, and collaboration rules.
- Preserved the old governance's one-authority, minimal-mechanic, confirmed-scope, layer-boundary, helper-extraction, state/context, and implementation-discipline rules in the overlay.

### A-02 — Embedded/admin client credential removal — resolved in code; external rotation still required

Evidence found:

- Analytics source and `.env.example` supplied a non-empty bootstrap admin password.
- The setup command passed that password through a command-line argument.
- The Godot `ProfileManager` embedded the same username/password, stored them in `user://profile.cfg`, and the Settings panel could place them in a dashboard URL.

Corrections:

- Analytics bootstrap username/password now default empty and must be supplied by managed environment injection or an untracked `.env` file.
- The bootstrap CLI no longer accepts a password argument.
- The Godot client contains no default dashboard credential, never persists one, migrates legacy profile credential keys away on the next profile save, and opens only the plain dashboard URL so the browser owns authentication.
- Generated analytics JavaScript was rebuilt from the corrected TypeScript.

Required operational follow-up: if the removed credential was ever accepted by any reachable service, treat it as compromised, rotate it, revoke affected sessions/access, and inspect relevant access logs. Removing it from the current tree does not erase Git history or already-built clients.

### A-03 — Dependency vulnerabilities — resolved for current lockfiles

Initial `npm audit` result:

| Package | Initial result |
|---|---:|
| analytics | 1 high, 1 moderate, 2 low |
| VS service | 3 moderate, 1 low |
| Rank service | 3 moderate, 1 low |
| Scholastic service | 3 moderate, 1 low |
| Match authority | 0 |

The affected packages now override vulnerable transitive `qs` and `esbuild` versions to reviewed fixed versions. Lockfiles were refreshed using npm, frozen installs succeeded, all five TypeScript builds passed, and the final audits report zero known vulnerabilities.

### A-04 — Server-side outbound deadlines and telemetry — resolved for current production fetch sites

- Added a hard configurable VS-to-Rank deadline (`VS_RANK_SERVICE_TIMEOUT_MS`, default 5 seconds) to leaderboard, player economy, settlement, and platform-economy requests.
- Added bounded match-authority-to-VS calls (`MATCH_AUTHORITY_HTTP_TIMEOUT_MS`, default 10 seconds).
- Added structured dependency outcome/status/latency events without logging URLs, authorization values, request bodies, or response bodies.
- Durable mutation workers retain their existing lease, retry classification, operation identity, and idempotent server authority; the new helper does not blindly retry writes.
- The public-rank smoke now proves a hanging dependency terminates within a bounded interval and then uses only its bounded stale cache/fail-closed behavior.

### A-05 — Authoritative simulation-state mutation — resolved for the detected direct assignment

The tutorial smoke helper in `scripts/shell.gd` assigned `OpsState.stats_by_team` directly. It now requests `OpsState.add_team_units_killed`, and `OpsState` owns validation and mutation. Static rescanning found no remaining direct `OpsState.<field> =` assignment in UI, renderer, input, or shell code. Existing explicit `sim_mutate` smoke seams remain tracked under F-08.

## Open release blockers and adoption debt

Priority meanings: **P0** requires immediate security/authority action; **P1** blocks enabling the affected field-critical workflow; **P2** is controlled adoption debt that must not expand.

### F-01 — P0: rotate the formerly embedded admin credential

Code remediation is complete, but repository history and prior builds may contain the credential. Rotation and access-log review require control of the deployed service/secret store and therefore were not performed by this code-only audit.

Exit evidence:

- replacement credential stored only in the deployment secret store;
- old credential rejected;
- session/access review recorded;
- decision recorded on whether history rewriting is necessary for any distributed repository.

### F-02 — P1: durable client intent and ambiguous-outcome reconciliation are incomplete

The backend public-mode path has strong idempotency and durable receipts, and `PublicContestState` queues failed evidence using the same request ID. However:

- several `VsHandshakeState` public operations generate request/command IDs in memory immediately before the request;
- the generic operation is not retained durably before the first network boundary;
- a generated command ID is added to a duplicate payload, so the caller does not necessarily retain it after a lost response;
- public contest evidence is persisted after a failed request, not before it;
- there is no single user-scoped durable operation state machine covering retained/sending/pending/confirmed/conflict/needs-attention;
- logout/account-switch and queued older-schema behavior are not governed end to end.

Affected paths include public queue/session lifecycle, command publication, terminal reports, contest entry/evidence, and client-initiated economy operations. Current disabled-by-default public/economy flags are the compensating containment, not a waiver.

Required code/design change before enabling an affected workflow:

1. Add one user-scoped durable operation queue owned by a state/service module, not UI.
2. Create and persist the operation ID plus exact canonical payload before sending.
3. Replay the same ID, never manufacture a replacement after uncertainty.
4. Reconcile by operation/result ID after timeout or app restart.
5. Preserve actionable validation/auth/concurrency conflicts rather than retrying forever.
6. Add lost-response-after-commit, process restart, logout/account switch, storage failure, and concurrent-submit tests.

### F-03 — P1: exact runtime and reproducible build inputs are not fully pinned

- Godot `project.godot` declares the 4.2 feature family, while evidence references both 4.2 stable editor and a custom/accepted 4.2.2 mobile template.
- CI prints `${GODOT_BIN} --version` but does not reject an unexpected build hash.
- No repository-wide Node version-manager file exists.
- three packages declare only `node >=20`; analytics and Rank declare no Node engine; no npm version is pinned.
- the audit host ran Node 24.5.0/npm 11.5.1, which is not itself a checked-in production contract.

Required decision: choose the supported Node major/minor and exact package-manager version, pin them for local/CI/Render use, and record the exact accepted Godot editor/export-template/custom-engine hashes. If editor and mobile runtimes intentionally differ, document and test the compatibility exception.

### F-04 — P1: CI/release gates do not cover the full candidate

`.github/workflows/release-readiness.yml` exercises substantial Godot smoke, matrix, and performance work, but it does not currently enforce the Constitution's complete candidate contract:

- no frozen install/build/smoke/audit for all five Node packages;
- no separate formatting, correctness lint, typecheck, generated-output, secret, or mutation-registry gates;
- no exact Node/npm or Godot build-hash enforcement;
- no migration-forward test for every service in the ordinary pull-request job;
- no exact deployable game/service artifact retained and promoted through environments;
- no artifact manifest tying commit, runtime, lockfiles, schema, environment, and flags together.

Required change: add fast and protected-integration jobs first, then make the artifact-producing release path depend on them. Do not make every expensive device/soak gate a normal local edit loop; retain tiered time budgets.

### F-05 — P1: liveness, readiness, version identity, and request observability are inconsistent

- Analytics `/health` always returns success and omits build/schema/database readiness.
- Scholastic health returns an `ok` boolean but does not return HTTP 503 on failed readiness and omits build/schema identity.
- VS health exposes useful build/config state but does not prove required PostgreSQL/dependency readiness; liveness and readiness share the same contract.
- Rank `/health` checks the database and carries build identity, but there is no cheap separate liveness contract.
- Services do not consistently assign/propagate correlation IDs, include build IDs in request logs, or return correlation IDs in errors.
- Alert ownership, backup/restore verification, queue-age alerts, and incident runbooks are not unified as release evidence.

Required change: standardize `/live`, `/ready`, and `/version` (or platform equivalents), add strict dependency deadlines to readiness, and add redacted correlation/build/operation identity to request and error telemetry.

### F-06 — P1 before deployment: Scholastic production configuration does not fail closed

The Scholastic service currently permits empty database and auth token configuration at module load and exposes write routes behind token helpers. It also handles student/school-related information, which requires an explicit privacy classification and retention/access policy before production use.

Required change: define production-mode detection; require database, API token, and admin token as applicable; reject debug actions in production; return 503 readiness when the database is unavailable; and document/export/delete/retention rules. No current Render deployment for this service was found in `render.yaml`, which limits current exposure but is not a release approval.

### F-07 — P2: local save files are generally direct overwrite operations

Multiple Class 1/2 client stores open their canonical `user://` file with `WRITE` and replace it directly. This includes profiles, public-contest pending evidence, battle pass, Honey progression, clans, moderation, scholastic state, and local/test economy adapters. A crash, full disk, or interrupted write can leave missing/corrupt state; account scoping and visible recovery vary by store.

Required change: create one bounded, tested atomic-save helper (temporary file, flush/close, validated replacement, optional last-known-good copy), then migrate the highest-integrity stores first. Server-authoritative facts must still reconcile from the server rather than treating a local backup as authority.

### F-08 — P2: large orchestration modules and generic smoke mutation seams remain

Current sizes include approximately 16.5k lines in `arena.gd`, 5.7k in `shell.gd`, 2.9k in `vs_handshake_state.gd`, and 2.8k in the VS server. The repository already has helper extraction, but these entry modules still own many responsibilities. `shell.gd` also contains several test-only calls to generic `OpsState.sim_mutate` closures that directly alter selection/hive/swarm state.

Required change: extract only when touching a stable responsibility; do not launch a giant rewrite. Replace generic smoke mutations with named authority-owned test seams or fixture setup APIs as those tests are changed.

### F-09 — P2: generated-file freshness is not enforced

Analytics commits `tools/analytics/dist`, whereas other Node packages ignore `dist`. The overlay now declares that asymmetry, but CI does not rebuild analytics and fail on a diff. Godot imports and other generated evidence likewise have partial, domain-specific checks rather than one `check:generated` contract.

Required change: either stop committing analytics `dist` and build it only as an artifact, or keep it committed and enforce deterministic freshness. Add registry-backed checks for every committed generated artifact.

### F-10 — P2: bounded response size is not universal in client transports

The Godot Rank, VS, analytics, and remote-ops HTTP clients use deadlines, but several accumulate response chunks without a maximum byte count. Their endpoints are governed configuration rather than arbitrary user URLs, reducing SSRF exposure, yet a compromised or misconfigured dependency can still exhaust client memory.

Required change: give each transport an expected content-type and response-byte cap, reject oversized declared lengths early, enforce the cap while streaming, and test chunked/no-content-length overflow.

## Strong existing controls confirmed

- One declared simulation authority and deterministic state-hash/replay infrastructure.
- Ordered checked-in SQL migrations for Analytics, Rank, Scholastic, and VS.
- PostgreSQL uniqueness/transactions/row locks and durable idempotency receipts for public match, verification, settlement, contests, and platform economy.
- Stable protocol, comparator, release-flag, and idempotency namespace registries for public modes.
- Separate player/admin/service/verifier credentials and disabled-by-default public/economic capability gates.
- Bounded JSON request sizes in all Express services inspected.
- Signed result receipts and double replay for trusted match verification.
- Reconciliation workers with durable leases/retry evidence for Rank and platform-economy delivery.
- Performance harnesses, matrix gates, deterministic seeds, and physical-iPhone evidence with explicit distinction between implementation and field validation.

## Verification record

The final handoff should record exact command results. At audit authoring time, the completed checks were:

- supplied Constitution byte comparison: pass;
- `npm ci && npm run build` in all five Node packages: pass;
- final `npm audit --audit-level=low` in all five Node packages: zero known vulnerabilities;
- `npm run smoke:public-rank` in the VS package: pass, including a hanging upstream terminated by the configured deadline;
- `npm run test:highlights` in Analytics: pass;
- `npm run smoke` in Match Authority: pass, including deterministic double replay, signed result, path escape rejection, and no-contest cases;
- Godot editor-wide parse/import scan: exit 0 on Godot `4.2.stable.official.46dc27791`; known binary-text and missing-Blender-path warnings remain;
- direct Godot `--check-only` parse for `ProfileManager` and `OpsState`: pass.

The verification above is not a substitute for the open field/release gates.
