# Software Engineering Governance Constitution

**Version:** 2.0  
**Status:** Adopted template for software projects  
**Purpose:** Universal engineering, authority, reliability, release, and collaboration governance  
**Applies to:** New projects and material new workflows in existing projects  
**Project-specific rules:** Must be supplied through a Project Governance Overlay and may be stricter than this Constitution.

---

## 0. Precedence and use

This Constitution defines the universal rules for building, changing, testing, releasing, and operating software.

Every repository using it must also maintain a **Project Governance Overlay** that identifies the project's stack, architecture, authoritative data models, generated files, deployment model, supported devices, domain-specific invariants, and stricter local rules.

Precedence:

1. Safety, security, legal, payroll, financial, and data-integrity requirements.
2. This Constitution.
3. The Project Governance Overlay where it is stricter or more specific.
4. Approved ADRs and module contracts.
5. Implementation plans and prompts.

A project-specific rule may refine this Constitution but may not silently weaken a universal invariant. Any intentional weakening requires a documented waiver under the Exceptions and Waivers section.

Prompts are reinforcement, not governance. Important rules must be checked into the repository and enforced through code, tests, CI, database constraints, release automation, or explicit review gates wherever practical.

---

# PART I — CORE ENGINEERING GOVERNANCE

## 1. Governing engineering principles

### 1.1 Reliability is architectural

Reliability is an architectural requirement and a release property, not a cleanup phase.

No refresh, route failure, network interruption, ambiguous response, authentication transition, deployment, process restart, dependency outage, or user retry may silently:

- discard meaningful entered data;
- duplicate a consequential business effect;
- invent state;
- rewrite governed history;
- leave a consequential action in an unknowable state.

For every meaningful operation, the system must be able to answer:

- What did the user intend?
- Was the intent retained before the risky boundary?
- Did the authoritative business effect occur?
- Can the same operation be replayed safely?
- Can the user and operator see the current state?
- Can the system recover without inventing, duplicating, or silently discarding work?

### 1.2 One authority per material business fact

Every material business fact must have one declared canonical authority.

Examples include:

- effective worked time;
- accepted/sold contract value;
- approved change value;
- project cost;
- invoice obligation;
- cash receipt;
- inventory consumption;
- work completion;
- testing result;
- client publication state;
- simulation state;
- scoring state.

Downstream systems may project, summarize, cache, report, or transform an authority. They may not independently reinterpret the same fact into a competing truth.

When legacy systems temporarily disagree, compatibility or reconciliation logic must:

- identify the destination authority;
- preserve source lineage;
- expose unresolved differences;
- have an exit condition;
- converge toward one authority.

Temporary reconciliation may not institutionalize permanent competing truths.

### 1.3 Enter once, use everywhere

When a fact already exists canonically, downstream workflows consume it rather than asking a user to re-enter it.

Examples:

- field work completion can feed progress, Daily Logs, financial projections, and client-safe updates;
- effective time can feed payroll, Project Time, Project Financials, and executive reporting;
- accepted contract data can feed operational scope, billing, and client financial views.

Convenient duplicated UI is permitted. Duplicated authority is not.

### 1.4 Preserve evidence before correction

When diagnosing or correcting consequential data:

- preserve original evidence;
- do not overwrite the source merely because it appears wrong;
- corrections must be additive, attributable, and auditable;
- effective state may change while original state remains reconstructible.

### 1.5 Bounded changes

Prefer bounded, reviewable, vertically testable changes over broad rewrites.

Do not refactor unrelated domains merely because nearby code is imperfect.

A feature implementation should identify:

- pain point;
- actors;
- authority;
- source of truth;
- states;
- transitions;
- exceptions;
- permissions;
- audit requirements;
- acceptance tests;
- deferred capabilities.

"No giant rewrite unless necessary" is a governance rule, not merely a stylistic preference.

---

## 2. Project-start requirements

Before material feature development, each repository must establish or explicitly track:

1. Supported runtime version and version-manager file.
2. One primary package manager.
3. Committed matching lockfile.
4. Frozen/immutable installation command.
5. Formatting command.
6. Correctness lint command.
7. Type-check command.
8. Unit-test command.
9. Integration-test command.
10. Production build command.
11. CI execution in an isolated environment.
12. Environment validation that fails closed.
13. Health/readiness/version contract.
14. Release/build identity.
15. Authority registry.
16. Mutation/write registry.
17. Data classification policy.
18. Backup, restore, deployment, and rollback procedures.
19. Secret-handling rules.
20. Initial reliability profile and release gates.

New projects should create the skeleton of these controls in the first implementation phase. Existing projects may adopt them incrementally, but field-critical or financially consequential workflows may not rely indefinitely on absent controls.

---

## 3. Runtime and dependency governance

- Pin the supported production runtime major and minor unless the platform contract requires a different form.
- Use the same runtime family in development, CI, preview, migrations, tests, and production unless a documented compatibility exception exists.
- Use exactly one primary package manager.
- Commit the matching lockfile.
- Use frozen/immutable installation in CI and candidate releases.
- Fail checks when conflicting lockfiles or unsupported runtime versions appear.
- Infrastructure-critical dependencies must not use uncontrolled version ranges.
- Dependency upgrades must pass the applicable gated suite.
- Record runtime, package manager, lockfile identity/hash, commit SHA, build ID, schema version, and deployment target in release metadata.

A release must be reproducible from the recorded inputs.

---

## 4. Repository and module boundaries

Every project overlay must document:

- source-tree ownership;
- route/module boundaries;
- generated files;
- persistence authority;
- client/server boundaries;
- integration boundaries;
- canonical entry points;
- prohibited imports;
- deployment-specific configuration.

Feature-owned behavior should live behind stable module boundaries rather than accumulating indefinitely in giant route or controller files.

Routes/controllers should be as thin as practical when business logic can live in governed feature/domain services.

Generated output:

- has one canonical generator;
- has one canonical output path;
- must not be hand-edited unless the generator contract explicitly allows it;
- must be deterministic for identical inputs;
- must fail validation if duplicate/conflict copies are present;
- must not continuously mutate without input changes.

Examples include route trees, generated database types, API clients, schemas, bindings, and compiled metadata.

---

## 5. Client/server separation

- Server secrets must never enter client bundles.
- Client-only libraries must not be imported by server entry modules.
- Heavy PDF, image, spreadsheet, browser-DOM, video, ML, barcode, or document libraries should be dynamically imported at the narrowest runtime boundary.
- CI should report meaningful client/server artifact size regressions.
- Environment-specific URLs, keys, and endpoints belong in governed configuration, not scattered through migrations or source.
- Service-role, private API, database, or signing secrets must never be passed through command-line arguments when they can appear in process listings, crash reports, telemetry, logs, or shell history.

---

## 6. React/UI correctness

For React projects:

- Rules-of-Hooks errors are zero-tolerance blockers.
- Hooks execute unconditionally and in stable order.
- Loading/error/loaded variants should be separate components when this makes Hook order obvious.
- Hook dependency warnings must be corrected or locally suppressed with an explicit reviewed explanation.
- Root routes and material feature boundaries require error handling that preserves recoverable work.
- A failed card/module should not unnecessarily crash the entire application.
- Full-page reloads used merely to repair state are suspect and should be audited.
- Routine releases must not forcibly refresh an active field workflow where a safe delayed-update experience is possible.

Equivalent framework-specific correctness rules apply to non-React projects.

---

# PART II — AUTHORITY AND DATA GOVERNANCE

## 7. Authority Registry

Every repository must maintain an **Authority Registry** for material facts.

Each entry should record:

| Field | Meaning |
|---|---|
| Business fact | What fact is governed |
| Canonical authority | Table/event/service/state object |
| Technical identity | Stable ID/key |
| Authorized writer | Function/RPC/service/role |
| Effective-time semantics | When the fact becomes effective |
| Immutable evidence/version | Source lineage |
| Allowed projections | Downstream consumers |
| Correction model | How errors are corrected |
| Rebuild/reconciliation | How the projection is reproduced |
| Owner | Business/technical owner |

Material downstream systems must cite or consume the declared authority rather than creating hidden parallel calculations.

If a project discovers two active authorities for the same fact, the conflict is architecture debt and must be resolved or explicitly governed as a migration state.

---

## 8. Write classification

Every meaningful mutation must be classified before or during implementation.

| Write class | Examples | Minimum contract |
|---|---|---|
| Ephemeral UI | filters, expanded panels | May be memory-only; no governed business effect |
| Durable Draft | notes, form composition, pending files | Local persistence where loss is meaningful; visible recovery; explicit discard |
| Reversible Write | preference, low-risk metadata | No blind mutation retry; refetch/reconcile after uncertainty |
| Consequential Event | punch, submit, completion, financial event | Persist intent; stable operation ID; server idempotency; reconcile unknown outcome |
| Final Transition | issue, approve, accept, close, publish, pay | Consequential-event controls plus authorization, concurrency/version control, immutable audit, explicit intent |

No field-critical mutation may remain unclassified.

The repository should maintain a machine-readable or reviewable mutation registry. CI should reject new consequential/final mutations that lack the required classification or tests where practical.

---

## 9. Data integrity classification

Write class and data integrity class are separate dimensions.

| Data class | Examples | Expected treatment |
|---|---|---|
| Class 0 — Disposable | filters, visual preferences | Loss acceptable |
| Class 1 — Recoverable Draft | unsent notes, estimate draft | Recover after refresh/restart where practical |
| Class 2 — Operational Evidence | photos, completion evidence, test reports | Strong durability, provenance, recovery, controlled deletion |
| Class 3 — Financial/Payroll/Legal Authority | punches, accepted contracts, COs, invoices, cash, governed costs | Strongest audit, idempotency, backup, correction, reconciliation, authorization |

The combination of write class and data class determines the control strength.

A Final Transition affecting Class 3 data receives the strongest controls.

---

## 10. Privacy and sensitivity classification

Integrity importance is not the same as confidentiality.

Projects must classify sensitive data separately, including where applicable:

- public;
- internal;
- confidential;
- financial;
- HR/payroll;
- client-private;
- legal;
- regulated/health-related;
- credential/secret.

Permissions, logs, telemetry, exports, analytics, and backups must honor both integrity and privacy classification.

A user having permission to see time detail does not automatically imply permission to see loaded labor cost, correction evidence, or HR detail.

---

## 11. Consequential-operation protocol

Consequential and final operations should follow a durable state model conceptually equivalent to:

```text
draft -> retained -> sending -> confirmed
                    |          |
                    |          -> conflict / needs_attention
                    -> pending -> sending
```

Required behavior:

1. Generate an operation ID once.
2. Retain the operation and required files before the first risky request when the workflow/data class requires it.
3. Replay using the same operation ID.
4. Enforce idempotency/uniqueness inside the authoritative transaction.
5. Return authoritative result plus operation identity.
6. Remove local evidence only after exact confirmation.
7. Treat validation, authorization, and concurrency errors as actionable states rather than infinite retries.
8. After timeout/lost response, reconcile by operation ID before asking the user to repeat the action.
9. Expose pending/sending/confirmed/conflict/needs-attention states where user action matters.
10. Prove through automated tests that repeated and concurrent submissions create the intended number of business effects—normally exactly one.

Retries are not a substitute for idempotency.

---

## 12. Database governance

- Declare one authoritative persistent database/state store per environment.
- All production schema changes must be checked-in and ordered.
- Migration tooling must identify target environment and fail closed.
- Production schema must not normally be repaired by ad hoc manual changes.
- Migration tests should prove forward application from a representative prior schema.
- Destructive resets require target verification, authorization, backup, and restore evidence.
- Disposable clones are valid for tests; they never become source of truth.
- Authorization, uniqueness, idempotency, auditability, and concurrency for final transitions belong at the authoritative boundary, not only in UI code.
- Rollback must preserve writes made after deployment; reverting code while deleting newer valid data is not rollback.
- Generated database/client types must be regenerated using the canonical generator rather than hand-edited.
- Effective-dated rules, rates, policies, and prices must preserve historical behavior when current values change.

Project overlays may impose stricter migration commands and database-safety procedures.

---

## 13. Historical truth and corrections

Historical governed records must not silently change because a current rule, rate, employee position, catalog price, policy, or configuration changes.

Use, where appropriate:

- immutable snapshots;
- effective-dated records;
- versioned authorities;
- correction overlays;
- append-only events;
- supersession/replacement lineage.

Examples:

- changing an employee's current loaded rate must not rewrite prior project cost;
- changing a catalog item price must not rewrite signed historical estimates;
- correcting a punch changes effective payroll time without erasing the raw punch;
- a warranty child project must not rewrite the original project as though it never completed.

---

# PART III — RELIABILITY PROFILES

## 14. Reliability profile selection

Each workflow must be assigned a reliability profile.

### Baseline

For ordinary low-consequence software behavior:

- deterministic runtime/build;
- bounded network calls;
- error handling;
- basic telemetry;
- unit/integration coverage;
- environment identity.

### Transactional

For persistent business writes:

- authority definition;
- mutation classification;
- validation;
- permission enforcement;
- reconciliation after ambiguous response;
- integration/database tests;
- concurrency awareness.

### Field Critical

For payroll, money, contracts, approvals, evidence, inventory custody, client publication, safety/compliance, or workflows users must trust in poor connectivity:

- durable intent;
- stable operation IDs;
- local recovery/offline behavior when needed;
- idempotent server authority;
- conflict handling;
- immutable audit;
- device/network failure handling;
- fault injection;
- real UI + authoritative DB tests;
- real-device validation before production reliance.

Project overlays may define additional profiles.

---

## 15. Durable drafts and offline behavior

For meaningful drafts:

- persistence must occur before risky transitions when loss would frustrate users or damage operations;
- locally retained data must be scoped to the authenticated user/workflow/record;
- drafts must recover visibly after refresh/restart;
- discard must be explicit;
- successful server save must be distinguishable from local-only save.

For files/evidence:

- retain actual bytes, not merely filenames;
- local copies remain until cloud storage and authoritative attachment are confirmed;
- retries must not duplicate assets;
- account switching must not expose another user's local queue;
- storage-full/private-browsing/site-data risks must be disclosed or mitigated.

Do not promise capabilities the browser/platform cannot guarantee.

---

## 16. Device loss and business continuity

Offline persistence alone is not a complete continuity plan.

For each integrity class, define acceptable behavior for:

- lost/destroyed device;
- browser storage eviction;
- cleared site data;
- storage exhaustion;
- prolonged total outage;
- backend outage;
- device replacement;
- logout with pending operations;
- app update with queued older-schema operations.

Each project must define appropriate:

- Recovery Point Objective (RPO);
- Recovery Time Objective (RTO);
- manual fallback;
- post-restoration reconciliation;
- independent backup/redundancy requirements.

Class 3 data requires especially strong continuity planning.

No governance document may imply that IndexedDB or local browser storage alone is a guaranteed backup.

---

## 17. External calls and resource limits

Every server-side network call must have at minimum:

- deadline/timeout;
- bounded retry policy;
- classified failure behavior;
- basic latency/failure telemetry.

Untrusted external content or user-supplied URLs require stronger controls as applicable:

- protocol allowlist;
- destination/host restrictions;
- redirect limit;
- expected content type;
- maximum response bytes;
- streaming byte counting;
- concurrency/fan-out limit;
- sanitized error contract;
- SSRF review.

Prohibited for untrusted/unbounded content:

- unbounded `arrayBuffer()`;
- unbounded `text()`;
- unrestricted archive extraction;
- unchecked decompression;
- arbitrary redirect chains.

Reject early where possible, but do not rely on `Content-Length` as the only enforcement.

---

## 18. Retry and concurrency rules

- Read retries may be automatic when safe and bounded.
- Mutating requests must not be blindly retried unless idempotency makes replay safe.
- Concurrent writes to governed records require optimistic concurrency, transaction serialization, uniqueness, version checks, or another explicit conflict model.
- Last-write-wins is not acceptable for consequential records unless the domain explicitly defines it.
- Two tabs/devices/users must not silently overwrite each other's final transitions.

---

# PART IV — OBSERVABILITY, TESTING, RELEASE, AND OPERATIONS

## 19. Observability requirements

### Requests and operations

Record, with sensitive fields redacted where applicable:

- correlation/request ID;
- release/build ID;
- route/operation name;
- timestamp;
- duration;
- outcome/status class;
- dependency calls and durations;
- operation ID for consequential writes;
- environment/server/isolate identity where available.

Error pages and API error responses should surface a correlation ID where useful.

### Process/runtime lifecycle

Record where the platform exposes it:

- runtime identity;
- release/schema identity;
- startup readiness;
- graceful shutdown reason;
- exit code/signal;
- restart count;
- peak RSS;
- heap/external memory;
- event-loop lag or equivalent.

### Alerts

At minimum for production/field-critical systems, govern alerts for:

- sustained 5xx;
- process crash/restart/OOM;
- readiness failure;
- latency degradation;
- durable queue backlog age;
- dependency timeout;
- connection exhaustion;
- failed scheduled jobs;
- failed backup/restore verification.

An alert must have an owner, severity, and response procedure.

---

## 20. Health, readiness, and identity

Provide separate checks or platform equivalents:

- **Liveness:** process/runtime can respond; avoid expensive dependency checks.
- **Readiness:** release is initialized and can reach dependencies required to accept normal traffic; use strict deadlines.
- **Version/Identity:** application name, environment, build/commit ID, runtime version, and compatible schema range without secrets.

Tests and monitors must verify application/build identity, not merely that "something answered on the expected port."

---

## 21. Test architecture

Use the layers appropriate to the reliability profile:

1. Unit tests — deterministic rules/state machines.
2. Component tests — loading/error/success/recovery.
3. Contract tests — request/response/error schemas.
4. Database tests — migrations, permissions, idempotency, concurrency, audit.
5. Browser/UI tests — real flow, refresh, reconnect, auth transitions.
6. Fault-injection tests — lost response after commit, timeout, partial upload, restart, dependency outage, corrupt local state.
7. Soak/load tests — memory plateau, latency, error rate, queue drain, restart count.
8. Real-device pilot — supported devices/networks/roles.

Source-regex/static tests may protect structure but cannot be the sole evidence for runtime behavior of critical workflows.

Flaky tests are defects. Quarantine requires:

- owner;
- issue;
- reason;
- expiry;
- compensating gate.

---

## 22. Test integrity

- CI starts the exact candidate server/app in an isolated environment or allocated port.
- CI may not silently reuse an arbitrary existing server.
- Readiness verifies expected application/build identity.
- Tests may not silently skip required fixtures/credentials.
- Failure artifacts such as traces, screenshots, logs, and correlation IDs should be retained.
- Critical workflows require at least one behavioral test through the real UI and authoritative database where technically feasible.
- Test harness defects must be distinguished from application defects before assigning root cause.

---

## 23. Soak and resource behavior

A long-lived process must demonstrate bounded resource behavior appropriate to its platform.

Soak/load tests should measure:

- request count;
- throughput;
- latency;
- error rate;
- RSS/heap/external memory where available;
- connection count;
- queue backlog;
- process/isolate count;
- restart count;
- post-load recovery/quiescence.

A process returning HTTP 200 while memory grows without a stable plateau has not proven reliability.

Harness/platform memory behavior must be isolated from application retention before declaring an application leak.

---

## 24. Lint, formatting, and static analysis

Use separate gates:

- `format:check`
- `lint:correctness`
- `typecheck`
- `lint:advisory`
- `check:generated`

Do not bury correctness defects under tens of thousands of formatting findings.

For legacy repositories:

1. Record exact baseline debt.
2. Immediately prohibit new correctness errors.
3. Make zero-tolerance rules blocking now.
4. Assign ownership/dates to burn down remaining debt.
5. Reach zero correctness errors before General Availability unless explicitly waived.

Rules-of-Hooks, invalid suppressions, unsafe unreachable logic, and other high-signal correctness rules are zero-tolerance for supported code.

---

## 25. Command contract

Every project should expose equivalents of:

```json
{
  "scripts": {
    "format:check": "<formatting only>",
    "lint:correctness": "<zero-error correctness lint>",
    "typecheck": "<type checker>",
    "test:unit": "<unit tests>",
    "test:integration": "<isolated integration tests>",
    "test:browser:isolated": "<start exact build + browser tests>",
    "test:db-replay": "<idempotency/concurrency tests>",
    "test:server-soak": "<target-relevant soak>",
    "check:fast": "<format + lint + typecheck + unit>",
    "check:field": "<fast + integration + db + browser + build + artifact checks>",
    "check:release": "<field + hosted smoke + release manifest verification>"
  }
}
```

Names may vary.

The artifact-producing release path must depend on the required gates. Documentation asking a human to remember separate commands is insufficient.

### Time budgets

Projects should set expected execution-time targets for gates so developers actually use them.

Time budgets never justify deleting critical validation. If a gate becomes too slow, improve it using:

- caching;
- sharding;
- affected-test selection;
- parallelization;
- candidate-only suites;
- better fixtures.

---

## 26. CI and release governance

### Pull Request

At minimum as applicable:

- frozen install;
- pinned runtime;
- formatting;
- correctness lint;
- typecheck;
- unit/component/contract tests;
- migration/database safety checks;
- build;
- generated-file verification;
- mutation-registry verification;
- artifact-size regression report.

### Protected Integration

For transactional/field-critical projects:

- disposable DB integration tests;
- concurrency/replay tests;
- isolated browser tests;
- fault injection for affected workflows;
- exact artifact retained with manifest.

### Candidate Release

- deploy retained artifact to target-like/target environment;
- verify release/schema identity;
- authenticated smoke;
- required soak;
- synthetic telemetry/alert verification;
- backup and rollback readiness;
- recorded approver/evidence/residual risk.

### Field Beta / Production

- deploy the exact approved artifact; do not rebuild it from source;
- use progressive exposure when practical;
- monitor error/latency/memory/restart/backlog gates;
- halt expansion or roll back on declared thresholds;
- retain previous artifact through observation window.

---

## 27. Completion states

Do not collapse implementation and field validation into one label.

### Implementation Complete

- code is complete;
- automated gates pass;
- authority, security, and reliability contracts are satisfied at implementation level.

### Field Validated

- actual supported device/network/workflow pilot completed;
- field-specific recovery and usability evidence collected.

### Production Ready

- Implementation Complete;
- Field Validated where required;
- release/observability/backup/rollback gates satisfied;
- residual risk accepted.

A developer may finish implementation before the real-device pilot. A field-critical feature may not be called Production Ready until required field evidence exists.

---

## 28. Service-level objectives

Projects must define measurable SLOs appropriate to the platform and business consequence.

Potential field-operations starting targets:

- 99.9% successful interactive availability, excluding validated user errors;
- 99% of normal interactive reads within 2 seconds under defined expected conditions;
- 99% of consequential operations reach confirmed or actionable state within 30 seconds after connectivity is available;
- zero silently lost protected drafts;
- zero duplicate effects for the same valid operation ID;
- zero unalerted process restarts;
- explicitly approved RPO/RTO per integrity class.

These are examples, not universal numbers.

Data safety and outcome certainty may be more important than raw page availability for offline-first field systems.

---

## 29. Incident governance

For Severity 1/2 incidents:

1. Preserve logs, release ID, schema ID, metrics, crash evidence, and correlation IDs.
2. Establish impact.
3. Stop release expansion where appropriate.
4. Restore service using the safest proven procedure.
5. Reconcile ambiguous consequential operations before instructing users to repeat them.
6. Produce a blameless timeline/root-cause analysis.
7. Distinguish trigger, contributing factors, missing detection, and missing containment.
8. Add a regression/fault test or document why the failure is not representable.
9. Assign actions, owners, deadlines.
10. Review whether governance/release gates must change.

"Restarted the server" resolves a symptom; it does not close the incident.

---

## 30. Backup, restore, and rollback

For governed data:

- backups must exist at a frequency appropriate to integrity class;
- restore procedures must be tested;
- recovery tests must verify usable data, not merely successful backup jobs;
- rollback must preserve writes created after deployment;
- destructive recovery requires explicit target verification;
- previous deployable artifacts must remain available through the defined observation/recovery window.

---

## 31. Secrets governance

Secrets must not appear in:

- source control;
- client bundles;
- command-line arguments where process listings can expose them;
- crash reports;
- logs;
- screenshots;
- test artifacts;
- shell history when avoidable.

Use platform secret stores/environment injection with least privilege.

Service/admin keys must never ship to the client.

CI should scan for obvious secret exposures where practical.

---

## 32. Exceptions and waivers

A rule may be waived only through a written record containing:

- exact rule;
- scoped component/workflow;
- business reason;
- user/data impact;
- compensating control;
- owner;
- approval authority;
- expiry;
- objective exit criteria.

No waiver may permit:

- silent loss of Class 2/3 data;
- duplicate final business effects;
- secret exposure;
- unknown production database target;
- intentionally unobservable critical failure.

---

# PART V — GOVERNANCE ENFORCEMENT

## 33. Enforcement classes

Every governance rule should be tagged conceptually as:

### Automated

Enforced by:

- CI;
- lint;
- tests;
- DB constraints;
- build scripts;
- schema validation;
- artifact checks.

### Reviewed

Requires architecture/code review, e.g.:

- authority ownership;
- business semantics;
- data-class selection;
- privacy classification;
- compatibility migration design.

### Operational

Verified by release/operations evidence, e.g.:

- device pilot;
- alert ownership;
- backup restore;
- rollback exercise;
- incident response.

The goal is to convert as many objective rules as practical into Automated controls while recognizing that some business and operational rules require review.

A rule that exists only in prose should be treated as less mature than one enforced automatically.

---

## 34. Required design record for material modules

Before or during implementation of a material module, record:

- Problem/pain point
- Actors
- Reliability profile
- Write classifications
- Data integrity classes
- Privacy classes
- Canonical authority
- Authorized writers
- Read consumers
- State machine
- Error/failure states
- Offline/recovery behavior
- Concurrency behavior
- Audit/evidence
- Tests
- Observability
- Deferred capabilities

This may be an ADR, module contract, plan, or checked-in design file.

---

# PART VI — OPTIONAL PARALLEL-AGENT AND GENERATED-FILE PROFILE

## 35. Parallel-agent development

Repositories using multiple coding agents concurrently should adopt this profile.

- One substantive agent task should normally use one branch/worktree.
- Agents touching materially adjacent/shared authority files should not silently edit the same working tree.
- Isolated agents may run isolated development servers on assigned ports.
- Only the integration owner/worktree may run shared persistent generators or mutate the authoritative shared local database unless explicit ownership is transferred.
- Agent tasks should prefer finite tests/builds over redundant persistent watchers.
- Agents must report shared/generated/authority files touched before integration.
- Integration occurs through commits/merges/cherry-picks with tests on the combined state.
- The integration environment, not an arbitrary agent worktree, is the place where cross-feature behavior is accepted.
- Parallel speed does not justify bypassing migration ordering, generated-file authority, or release gates.

---

## 36. Generated-file ownership

For every generated artifact, the project overlay records:

- generator command;
- source inputs;
- canonical output;
- whether the output is committed;
- whether CI verifies freshness.

No agent manually edits generated output as a normal implementation path.

Duplicate conflict copies, numbered generated files, or divergent generated artifacts are release blockers when they can affect build/runtime behavior.

---

# PART VII — PROJECT GOVERNANCE OVERLAY CONTRACT

## 37. Every project must maintain an overlay

A Project Governance Overlay preserves domain-specific rules that should not be copied blindly into unrelated projects.

The overlay should define:

### Project identity
- Project/repository name
- Purpose
- Supported environments
- Supported platforms/devices

### Stack
- Runtime
- Framework
- Package manager
- Persistence
- Hosting/deployment
- External integrations

### Architecture
- Operational/domain spine
- Module boundaries
- Canonical source tree
- Generated files
- Server/client boundaries

### Authority Registry additions
- Domain-specific canonical facts
- Writers/consumers
- Version/effective-time rules

### Domain invariants
Examples:
- accepted contract never rewritten;
- UI never mutates simulation state;
- Project is operational spine;
- scene-per-purpose;
- payroll time preserved as immutable events plus correction overlay.

### Database/state rules
- Migration commands
- Safety gates
- RLS/capability rules
- Backup/restore constraints

### Testing
- Required domain tests
- Simulation determinism tests
- Field-device tests
- Financial reconciliation tests
- Performance targets

### Release profile
- Baseline / Transactional / Field Critical
- SLOs
- Required field pilot
- Target hosting behavior

### Collaboration profile
- Parallel-agent rules
- Generated-file rules
- integration owner/process

---

# PART VIII — EXISTING PROJECT ADOPTION

## 38. Existing repositories

Adopt in this order:

1. Preserve the existing project-specific governance.
2. Add this Constitution without deleting stricter local rules.
3. Inventory current authorities and competing truths.
4. Pin runtime/package manager/lockfile.
5. Separate formatting from correctness gates.
6. Make high-signal correctness rules zero-tolerance.
7. Establish build/release identity.
8. Inventory mutations and classify field-critical actions first.
9. Add `check:fast`, `check:field`, and release gates appropriate to the project.
10. Add observability/health.
11. Add missing idempotency/reconciliation for consequential actions.
12. Add soak/fault/device evidence where the reliability profile requires it.
13. Burn down legacy waivers with named owners.

Do not halt all product development merely to perfect historical governance debt. Prevent new debt immediately, then remediate the highest-consequence existing paths first.

---

## 39. New repositories

The first project scaffolding should establish:

- runtime/package manager;
- lockfile;
- CI;
- health/version identity;
- authority registry;
- mutation registry;
- data/privacy classification;
- generated-file rules;
- base observability;
- initial release pipeline.

The first consequential workflow should become the reference implementation for durability, idempotency, concurrency, audit, and fault testing.

---

# PART IX — DEFINITION OF DONE

## 40. Field-critical workflow

A Field Critical workflow is Implementation Complete only when:

- authority is documented;
- write/data/privacy classification is documented;
- permissions are enforced at authoritative boundary;
- meaningful drafts/evidence survive required refresh/restart conditions;
- operation replay is safe;
- concurrent conflicts are explicit;
- lost-response-after-commit behavior is reconciled;
- original evidence remains reconstructible after corrections;
- auth expiry does not silently discard work;
- offline/reconnect behavior is safe or explicitly actionable;
- error outcomes are observable;
- required browser/database/fault tests pass;
- generated artifacts are current;
- release identity is verifiable.

It becomes Field Validated only after the required supported-device/network pilot.

It becomes Production Ready only after release, monitoring, backup, rollback, and residual-risk gates are satisfied.

---

## 41. Governance outcome

This Constitution succeeds when software is no longer accepted on confidence, memory, or "it worked on my machine."

A release is accepted by:

- one declared authority for each material fact;
- explicit invariants;
- classified writes and data;
- reproducible runtime/build;
- automated and reviewed gates;
- observable behavior;
- recoverable failure;
- retained evidence;
- exact release identity.

The operating principle is:

> **Bound failures. Preserve meaningful intent. Keep one truth. Make outcomes observable and reconcilable. Promote only exact artifacts backed by repeatable evidence.**

---

# APPENDIX A — Project Governance Overlay Template

```markdown
# Project Governance Overlay — <Project Name>

## 1. Identity
- Repository:
- Purpose:
- Supported environments:
- Supported devices/platforms:
- Reliability profile(s):

## 2. Stack
- Runtime:
- Package manager:
- Lockfile:
- Framework:
- Persistence:
- Hosting:
- Integrations:

## 3. Architecture
- Domain/operational spine:
- Primary module boundaries:
- Client/server boundary:
- Generated files and generators:
- Prohibited manual edits:
- Persistent development processes:

## 4. Authority Registry
| Business fact | Canonical authority | Writer | Effective semantics | Consumers | Correction/rebuild |
|---|---|---|---|---|---|

## 5. Domain invariants
- ...
- ...

## 6. Mutation registry
| Mutation | Write class | Data class | Privacy class | Authority | Idempotency/recovery |
|---|---|---|---|---|---|

## 7. Database/state governance
- Canonical environment:
- Migration command:
- Database safety command:
- RLS/capability rules:
- Backup/restore rules:

## 8. Generated-file governance
| Artifact | Generator | Inputs | Output | Committed? | CI freshness check |
|---|---|---|---|---|---|

## 9. Test/release contract
- check:fast:
- check:field:
- check:release:
- required domain suites:
- soak/load:
- supported-device pilot:
- SLOs:

## 10. Parallel-agent profile
- Integration owner:
- Shared DB owner:
- Assigned-port policy:
- Shared generator ownership:
- Merge/integration workflow:

## 11. Active waivers
| Rule | Scope | Reason | Compensating control | Owner | Expiry | Exit criteria |
|---|---|---|---|---|---|---|
```

---
