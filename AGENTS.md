# Swarmfront Repository Governance

This file is the mandatory engineering-governance entry point for Swarmfront. It applies to all coding, testing, performance, diagnostic, build, migration, release, deployment, tooling, and documentation work in this repository.

Treat **MUST**, **MUST NOT**, **REQUIRED**, **STOP**, and **NEVER** as governance requirements, not suggestions.

Task-specific instructions may narrow the scope of work. They do not silently waive these rules. If a requested action conflicts with a frozen contract or with this governance, surface the conflict before changing the contract.

## 1. Mandatory Start-of-Work Preflight

Before making a material change:

1. Read this file.
2. Confirm the repository/worktree, current branch, exact `HEAD`, configured upstream, and working-tree status.
3. If the task names a branch, SHA, candidate, or worktree, verify it before editing. A clean but wrong branch is still the wrong starting point.
4. Inspect existing uncommitted changes before touching overlapping files. NEVER discard, reset, overwrite, clean, or silently stash user work.
5. Identify the canonical owner/contract for the behavior being changed.
6. Inspect the existing implementation and relevant tests before designing a replacement.
7. Establish the smallest bounded scope that can satisfy the request.

If repository access, branch identity, candidate identity, or required authority cannot be verified, STOP rather than guessing.

Historical status/evidence documents describe what happened; they do not automatically authorize new mutations or deployments.

## 2. ENTaP Reuse-First Rule — MANDATORY

**Search before build. Reuse before duplicate.**

Before creating a new system, subsystem, helper, service, adapter, abstraction, harness, diagnostic, build script, deployment mechanism, or engineering tool, search the relevant available surfaces in this order:

1. the current Swarmfront repository: runtime code, scripts, tools, tests, workflows, docs, fixtures, adapters, and dormant/legacy paths;
2. sibling ENTaP projects, especially Operation Fury and other accessible proven implementations;
3. shared ENTaP components/libraries/tooling;
4. repository history and previously retired/superseded implementations;
5. engine/platform/vendor-native tooling and established platform capabilities.

Prefer, in order:

- **use as-is**;
- **configure**;
- **extend**;
- **extract/share a proven component**;
- **adapt**;
- only then **build new**.

Do not create a parallel implementation merely because it is easier to understand locally.

If a genuinely new parallel tool/system is required, a **code-grounded ADR or equivalent explicit design record is REQUIRED**. It must state what was searched, what viable candidates were found, why each cannot safely satisfy the requirement, why extension/adaptation is insufficient, the proposed canonical owner, and how duplication/drift will be prevented.

If a required search surface is unavailable, state that limitation. NEVER claim a reuse-first search was completed when it was not.

## 3. Harness and Engineering-Tooling Governance

Testing, performance, diagnostics, builds, deployment, and engineering plumbing are subject to the reuse-first rule with extra scrutiny.

Before adding a new harness or runner:

- inspect existing `tools/`, `scripts/`, test suites, fixtures, GitHub workflows, benchmark suites, artifact formats, and historical harnesses;
- extend the canonical harness when it can represent the new case without corrupting its contract;
- reuse production/runtime paths wherever practical rather than implementing a second fake version of the behavior under test;
- keep test doubles explicitly non-authoritative;
- do not create multiple competing fixture catalogs, baseline authorities, result schemas, launchers, or certification paths without an ADR.

A harness exists to measure or prove the product. The product MUST NOT be distorted merely to make the harness easier to satisfy.

## 4. Canonical Authority and Single Source of Truth

Before writing a mutation, determine **who owns the truth**.

- There MUST be one canonical owner for a given authoritative fact or mutation boundary.
- UI, presentation, animation, input, networking, prediction, and convenience adapters may request, transport, or render authoritative state; they MUST NOT become an accidental second authority.
- `OpsState`/`SimState` remain the only authoritative gameplay-state mutation authority inside Swarmfront simulation unless a later accepted ADR explicitly supersedes that contract.
- Accepted remote commands must return through authoritative state entry points rather than mutating gameplay state from transport/UI shortcuts.
- Persistent competitive/economic state must use its accepted server/durable authority. Client-local ledgers/stores are previews or test doubles only unless a contract explicitly says otherwise.
- Retryable mutating operations that can create duplicate external effects MUST be idempotent at the authoritative boundary.
- Derived UI, reports, telemetry, leaderboards, receipts, and projections SHOULD project from canonical truth rather than create duplicate facts that can drift.
- An unresolved ownership decision remains unresolved. NEVER make a legacy table, cache, file, client mirror, or convenient adapter canonical merely because it already exists.

Relevant current authority contracts include:

- `docs/pvp_authority_audit.md`
- `docs/architecture/public_modes/README.md` and its accepted ADRs
- `docs/architecture/render_reactivation/ownership-matrix.md`
- `docs/money_game_ledger_contract.md`

Read the domain-specific contract before changing that domain.

## 5. Contract, Product, and Scope Protection

Do the requested sprint, not every adjacent improvement you notice.

- Prefer the smallest correct change that preserves existing contracts.
- No opportunistic architecture rewrite, broad cleanup, renaming campaign, feature addition, economy change, gameplay rebalance, or monetization change unless it is required by the approved scope.
- Locked product/spec language and accepted ADRs are contracts, not suggestions. Do not silently reinterpret them.
- When older documents conflict with a later accepted ADR/contract, follow the explicit supersession chain; do not invent a compromise.
- Do not convert a TODO, parking-lot idea, dormant code path, or test scaffold into a product decision.
- Do not resolve open product/authority questions by implementation convenience.
- Competitive-integrity, economy, payout, wagering, ranking, and player-trust rules require explicit authority and must fail closed when their prerequisites are absent.

`SF-v1-LOCKED.md` contains locked historical/core product constraints. More recent accepted contracts may explicitly supersede portions of older design documents; preserve those supersession boundaries.

## 6. Change Safety and Git Discipline

- NEVER erase or rewrite user work to obtain a clean tree.
- NEVER use destructive reset/clean, force-push, history rewrite, or broad file replacement as a convenience without explicit authorization.
- Keep unrelated user changes intact.
- If a dirty file materially overlaps the requested change and safe integration is unclear, STOP and report the conflict.
- Keep commits bounded by concern when practical.
- Do not claim a commit, push, clean tree, merge, or branch state without verifying it.
- A generated artifact is not proof that the source tree producing it is the intended source tree; bind evidence to exact source identity where certification matters.

## 7. Tests, Gates, and Evidence Integrity

Tests and certification are truth-finding mechanisms, not obstacles to be negotiated away.

- Run the relevant existing baseline before a material change when practical.
- Add or update regression coverage for the behavior being changed.
- NEVER delete, weaken, bypass, skip, loosen, or reword a test, threshold, gameplay rule, security check, or certification gate merely to manufacture a pass.
- NEVER raise a performance threshold merely because the implementation misses it unless the product owner explicitly authorizes a threshold change.
- Preserve original failure evidence before remediation/rerun when the evidence matters to diagnosis or certification.
- Distinguish **automated**, **simulated**, **packaging**, **local-device**, **physical-device**, **staging**, **certification**, and **Production** evidence. One does not silently prove another.
- A binary containing a plugin/class proves packaging; it does not prove protected hardware/keychain/keystore behavior.
- A short probe proves the short probe. It does not prove a required long soak.
- A stable run can provide endurance evidence even when a performance gate fails; record those conclusions separately.
- Known unrelated baseline failures must be called out explicitly rather than hidden inside an overall “pass” claim.
- State exactly what was tested, against which SHA/artifact/configuration, and what was not tested.

If a test repeatedly returns the same deterministic failure, diagnose it rather than burning time repeatedly asking the same test the same question.

## 8. Critical-Path Placement — The Oven Rule (MANDATORY)

A constrained execution path is the oven: only work required to produce the current authoritative result belongs inside it.

Predictable work that can safely be done before the critical moment should be prepared before it is needed. Work that does not need to block the current authoritative result should leave the critical path and finish afterward or elsewhere.

**Before optimizing measured hot-path code in place, first ask: _Does this work belong on the critical path at all?_**

### Required placement test

Before changing a measured hot or constrained path, classify each meaningful operation as one of:

1. **MUST HAPPEN NOW** — required for correctness, determinism, safety, authoritative ordering, or the current authoritative result.
2. **CAN HAPPEN BEFORE** — predictable work that can safely be preloaded, prewarmed, precomputed, cached, pooled, reserved, staged, or otherwise prepared before the time-critical moment.
3. **CAN HAPPEN AFTER / ELSEWHERE** — presentation, persistence, telemetry, analytics, cleanup, notifications, serialization, or other work that does not need to block the current authoritative result.

The critical path MUST contain only category 1 work unless moving an operation would change correctness, determinism, safety, authoritative ordering, or an explicit product contract.

**Placement comes before micro-optimization.** Do not spend engineering effort making category 2 or category 3 work faster in the oven until its presence in the oven has been justified.

### Implementation rules

- Known recurring work SHOULD be moved earlier when safe: preload, prewarm, precompute, cache, pool, reserve, or stage it before the time-critical moment.
- Non-authoritative or non-immediate work SHOULD be moved later or elsewhere when safe: defer, queue, batch, asynchronously execute, post-process, persist, or present it after authoritative state is settled.
- Authoritative gameplay/state work MUST retain deterministic ordering and correctness. NEVER move work merely to improve a benchmark if doing so changes game truth or creates races.
- Prefer removing unnecessary work from the critical path over shaving milliseconds from work that does not belong there.
- Apply this rule anywhere a scarce serialized path exists, not only simulation ticks: startup, scene/round transitions, spawning/production, rendering preparation, networking, persistence, asset loading, backend workflows, and other latency-sensitive paths.

### Performance diagnosis and certification

Long soak/certification runs prove a candidate; they are not a substitute for diagnosis.

- Instrument phases/events when aggregate timing does not identify the blocker.
- Once repeated evidence establishes the same over-budget failure, STOP blindly repeating long soak/certification runs.
- After a repeatable failure is established, switch to targeted/event-driven profiling, form a concrete hypothesis, remediate it, run a focused validation, and only then return to full certification.
- Do not spend hours repeatedly asking a test a question it has already answered.
- Stability evidence gathered during a failed performance soak remains useful and should be recorded separately from performance-gate status.

### Required evidence for material critical-path remediation

Record:

- the measured blocker and where it occurred;
- which expensive operations stayed on the critical path, moved earlier, or moved later/outside;
- why the new placement preserves correctness, authority, determinism, and safety;
- before/after timing under the same performance contract;
- the focused test/probe used to validate the change;
- the final soak/certification result when certification is required.

### Required preflight questions

Before changing a hot path, answer:

- Does this operation truly need to happen now?
- Could it happen before?
- Could it happen after?
- Could it be cached, pooled, precomputed, prewarmed, or staged?
- If moved, does authority/determinism/correctness remain identical?
- Have we measured before and after under the same performance contract?

### Swarmfront examples

- Predictable unit-production and lane-rendering resources should be prepared before active play when safe rather than first-created during a critical gameplay moment.
- Once an authoritative match result is settled, round-end presentation, persistence, analytics, and similar non-authoritative work must not block authoritative simulation when they can safely be deferred.

The mental model is simple: **cook in the oven; cool on the counter. Keep the scarce critical path available for work that only the critical path can do.**

## 9. Default-Off Capability and Release Governance

Certification is not activation.

Current public/economic reactivation governance requires a default-off posture. Unless an accepted later contract explicitly changes this:

- public, Rank mutation, Honey, Wax, Crucible, contest, reward, leaderboard, settlement, and other externally mutating capabilities default false;
- restoring infrastructure or proving a candidate does not authorize player-facing or economic activation;
- a verified match result does not by itself authorize Rank/economy/contest side effects; each consumer requires its own authority, idempotency, and kill switch;
- development/private compatibility stores must not silently become Production durable authority;
- certification and Production remain distinct environments.

`docs/architecture/render_reactivation/adr-005-render-reactivation-contract.md` is the current reactivation contract and must be read before Render/release work.

## 10. Production and External-Mutation Boundary

Production is not a test surface.

Without explicit authorization for the specific action, do not:

- deploy or activate Production;
- run Production data migrations;
- enable public/economic capabilities;
- rotate secrets/credentials;
- change provider plans, topology, networking, domains, databases, environment values, or auto-deploy posture;
- reset, relabel, wipe, or replace durable player/economic/audit data;
- create a new Production authority to bypass an unresolved ownership decision.

Read-only discovery does not imply mutation authorization. Certification authorization does not imply Production authorization.

For changed externally deployed components, preserve rollback identity and obtain the required rollback evidence before an activation decision when the governing release contract requires it.

## 11. Candidate and Deployment Evidence Governance

When work is release/certification scoped:

### Candidate Release Manifest

- MUST exist before external deployment when required by the release contract.
- MUST bind exact clean Git source, engine/tool versions, build artifacts, content/schema/config identity, tests, limitations, and declared capability posture.
- Dirty source trees are ineligible for a frozen candidate.
- Once approved/deployed, the candidate manifest is immutable.
- Any source/artifact/config change creates a new candidate identity rather than editing history.

### Deployment Manifest

- Is separate from candidate identity.
- Links to exactly one candidate.
- Records what actually happened in an environment, including mismatches, failures, rollback, restoration, and deviations.
- Is append-only evidence; historical failures are not rewritten into success.

Canonical contracts:

- `docs/architecture/render_reactivation/candidate-release-manifest-v1.md`
- `docs/architecture/render_reactivation/deployment-manifest-v1.md`

## 12. Security, Secrets, and Sensitive Evidence

- NEVER commit secret values, private keys, access tokens, database URLs containing credentials, or other authentication material.
- Never paste secret values into committed evidence just because an operator tool displayed them.
- Unique physical device identifiers and player PII do not belong in normal committed certification evidence.
- Preserve public fingerprints/key IDs when needed for artifact identity; preserve private material only in its designated secure system.
- Device private keys intended for secure hardware/store MUST NOT be moved into GDScript, logs, committed files, or backend storage.
- Do not weaken authentication, authorization, trust boundaries, certificate checks, or security gates to get a test passing.
- Security/economic mutations fail closed when authority or prerequisites are uncertain.

## 13. Documentation and ADR Discipline

Documentation must identify truth, not create a second truth.

- Update the existing canonical contract/status/evidence document when that is the proper owner; do not make a near-duplicate “new canonical” file because editing the original is inconvenient.
- Use ADRs for material authority, architecture, ownership, or deliberate parallel-tool decisions.
- An ADR must identify the existing implementation/contract it supersedes or extends and why.
- Status reports record observed state and evidence; they do not silently change frozen architecture.
- Preserve unresolved decisions explicitly instead of filling them with assumptions.
- When a new contract supersedes an old one, state the supersession boundary.

## 14. Completion and Handoff Standard

A material implementation handoff should report, as applicable:

- starting branch/SHA and ending branch/SHA;
- working-tree status;
- files changed and migrations/artifacts created;
- canonical authority/function/path changed;
- reuse-first findings, especially when a new tool/system was introduced;
- tests/diagnostics/certification runs executed and their exact results;
- known failures, limitations, untested physical/external requirements, and deferred work;
- whether anything was deployed, migrated, activated, rotated, or otherwise mutated outside the local repository;
- rollback identity/evidence when release work requires it.

Do not say “done,” “certified,” “Production-ready,” “secure,” or “passed” more broadly than the evidence supports.

## 15. Stop Conditions

STOP and report rather than improvising when any of the following is true:

- required repository/remote/branch/candidate access is unavailable;
- the worktree contains overlapping user changes that cannot be safely preserved;
- the requested implementation would create a second authority/source of truth without an accepted design;
- reuse-first discovery finds an existing canonical implementation that materially changes the proposed plan;
- a new parallel harness/tool/system appears necessary but has no code-grounded ADR;
- a required Production/external mutation has not been explicitly authorized;
- passing requires weakening an existing test, threshold, security rule, authority boundary, product contract, or certification gate;
- the task would resolve an explicitly unresolved ownership/product decision by assumption.

## Canonical Reference Index

This index is an entry map, not a substitute for reading the relevant contract:

- Gameplay authority: `docs/pvp_authority_audit.md`
- Public modes contract freeze + ADR index: `docs/architecture/public_modes/README.md`
- Render reactivation contract: `docs/architecture/render_reactivation/adr-005-render-reactivation-contract.md`
- Render/Production ownership matrix: `docs/architecture/render_reactivation/ownership-matrix.md`
- Candidate manifest contract: `docs/architecture/render_reactivation/candidate-release-manifest-v1.md`
- Deployment manifest contract: `docs/architecture/render_reactivation/deployment-manifest-v1.md`
- Money-game ledger authority: `docs/money_game_ledger_contract.md`
- Locked/core historical product spec: `SF-v1-LOCKED.md`
- Current observed project status: `docs/current_project_status.md` — status/evidence only, not automatic mutation authority

If future accepted ADRs/contracts supersede these documents, update this index as part of that acceptance so future agents do not follow stale governance.
