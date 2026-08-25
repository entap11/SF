> Planning status: DRAFT INPUT ONLY. Preserve for sharpening and later adoption work; do not implement from this document yet.

# ENTaP Reuse-First Tooling Governance

## Adoption and Implementation Plan

## Intended outcome

ENTaP will maintain one discoverable, governed ecosystem of engineering tools across Swarmfront, Operation Fury, OLH, and future projects.

Before building any new:

* Performance harness.
* Diagnostic runner.
* Fixture system.
* Metrics collector.
* Comparator.
* Test framework.
* Smoke suite.
* Build/export script.
* Device-evidence workflow.
* Deployment tool.
* Map validator.
* Replay verifier.
* Debug panel.
* Migration helper.
* Operational dashboard.
* Other engineering plumbing.

the developer or coding agent must first search for and evaluate existing capabilities.

The default path becomes:

**Search → Reuse → Configure → Extend → Adapt → Extract proven common code → Build new only with evidence.**

For OLH, the default assumption is that it will reuse or adapt OF and SF tooling rather than receive a third independent performance system.

---

# Phase 0 — Locate and update the Governance Bible

## Objective

Add the reuse-first rule to the canonical studio governance document rather than leaving it in conversation history or individual Codex prompts.

## Actions

1. Locate the current Governance Bible and confirm:

   * Canonical repository.
   * Canonical file path.
   * Current owner.
   * Whether duplicate governance documents exist.
   * Which document new-project prompts currently reference.

2. Add a new top-level section:

   **Reuse-First Testing and Infrastructure Governance**

3. Include the following binding rules:

   * Mandatory current-repository search.
   * Mandatory cross-project search.
   * Mandatory shared and historical-tool search.
   * Required decision order.
   * New-tool ADR requirement.
   * Canonical-owner requirement.
   * Duplicate-tool classification.
   * Cross-project review for every new title.
   * No speculative shared abstraction.
   * Required final governance confirmation.

4. Add the governing sentence:

   **Search first. Reuse second. Extend third. Extract when proven. Build new only with evidence.**

5. Cross-reference the new section from:

   * New-project governance.
   * Codex operating rules.
   * Testing governance.
   * Performance governance.
   * Release-readiness governance.
   * Build and deployment governance.

## Exit gate

* One Governance Bible is confirmed as canonical.
* The new rule is present and cross-referenced.
* No competing governance document gives contradictory instructions.
* The change is committed independently of any tooling implementation.

---

# Phase 1 — Create the ENTaP Tooling Registry

## Objective

Give Codex and human developers a known place to discover existing engineering capabilities before creating new ones.

## Recommended location

Prefer a studio-level repository or a clearly documented shared location.

Example:

`docs/governance/entap_tooling_registry.md`

If no studio repository exists yet, place the first version in the canonical governance repository rather than duplicating it inside every game.

Each game may contain a short pointer to the canonical registry.

## Registry schema

Each tool entry should include:

* Tool ID.
* Tool name.
* Purpose.
* Canonical status.
* Repository.
* Exact path.
* Canonical invocation.
* Supported projects.
* Current owner.
* Input contract.
* Output contract.
* Build restrictions.
* Device/platform support.
* Production-isolation behavior.
* Known adapters.
* Known limitations.
* Related documentation.
* Replacement or migration path.
* Last verified commit/date.

## Status classifications

Every overlapping implementation must be labeled:

* `CANONICAL`
* `COMPATIBILITY_ADAPTER`
* `TITLE_SPECIFIC_ADAPTER`
* `SPECIALIZED_FORENSIC_TOOL`
* `DEPRECATED`
* `HISTORICAL_EVIDENCE_ONLY`
* `PENDING_MIGRATION`
* `EXPERIMENTAL`

No overlapping infrastructure should remain indefinitely unclassified.

## Exit gate

* The registry exists.
* Its location is referenced from the Governance Bible.
* SF and OF’s major performance/testing tools are inventoried.
* Every discovered duplicate has a provisional classification.
* The registry contains exact paths and commands, not merely descriptions.

---

# Phase 2 — Inventory SF and OF tooling

## Objective

Establish what already exists before making architectural decisions for OLH.

This is an inventory and classification pass, not a consolidation rewrite.

## Swarmfront inventory

At minimum review:

* Canonical performance benchmark runner.
* Older performance runner.
* Baseline comparators.
* Rhythmic lag isolation.
* Startup hitch diagnostic.
* Fixture registry.
* Metrics collection.
* Protected-state isolation.
* Result serialization.
* Percentile and comparison logic.
* Device-build and evidence workflows.
* Release-readiness suites.
* Smoke-test conventions.
* Deterministic simulation/replay tools.
* Map validation.
* Pool telemetry.
* Lifecycle soak tooling.

Record which SF components provide:

* Deterministic execution.
* Regression comparison.
* P50/P95/P99 calculations.
* Build/device fingerprinting.
* Protected-state guards.
* Physical-device evidence.
* Startup-phase markers.
* Lifecycle and cleanup validation.

## Operation Fury inventory

At minimum review:

* Stripped-component performance harness.
* Component enable/disable model.
* Rendering-layer isolation.
* GPU/CPU attribution method.
* Scene or fixture construction.
* Device collection workflow.
* Result/report format.
* Quality-tier or degradation testing.
* Any Blender or asset validation tooling relevant across projects.

Record which OF components provide:

* Fine-grained component isolation.
* Static versus transition cost testing.
* Layer-by-layer visual attribution.
* Scene-specific diagnostic controls.
* Presentation stress construction.

## Required output

Create a capability matrix:

| Capability             | SF     | OF     | Reuse candidate | Notes |
| ---------------------- | ------ | ------ | --------------- | ----- |
| Deterministic fixtures | Yes/No | Yes/No | SF/OF/Shared    |       |
| Component isolation    | Yes/No | Yes/No | SF/OF/Shared    |       |
| Percentile metrics     | Yes/No | Yes/No |                 |       |
| Device fingerprint     | Yes/No | Yes/No |                 |       |
| State isolation        | Yes/No | Yes/No |                 |       |
| Lifecycle soak         | Yes/No | Yes/No |                 |       |
| GPU attribution        | Yes/No | Yes/No |                 |       |
| Baseline comparison    | Yes/No | Yes/No |                 |       |
| Report schema          | Yes/No | Yes/No |                 |       |

## Exit gate

* Actual code paths have been inspected.
* Documentation claims have been verified against code.
* No new common framework has been created.
* The stable overlap and title-specific differences are documented.

---

# Phase 3 — Declare canonical ownership

## Objective

Prevent SF, OF, and OLH from each inventing their own version of every engineering capability.

## Recommended initial ownership

Subject to the code audit:

### Swarmfront likely owns

* Deterministic fixture execution.
* P50/P95/P99 and hitch aggregation.
* Baseline fingerprinting and comparison.
* Protected-state isolation.
* Lifecycle and cleanup evidence.
* Build/device metadata.
* Regression-oriented benchmark reporting.

### Operation Fury likely owns

* Stripped-component methodology.
* Presentation-layer isolation.
* Component-cost experiments.
* Visual-system enable/disable patterns.
* Static, scaling, and burst comparison methodology.

### Shared studio governance owns

* Result schema conventions.
* Metric classifications.
* Device/build fingerprint requirements.
* Release-build refusal requirements.
* Evidence-report sections.
* Baseline-approval rules.
* Reuse-first discovery process.
* Tool registry.

### Individual titles retain

* Scene construction.
* Map fixtures.
* Simulation adapters.
* Entity counters.
* Renderer-specific controls.
* Gameplay-specific stress cases.
* Title-specific authority and protected-state rules.

## Important limit

Do not force SF and OF into one giant runner.

The goal is:

* Shared proven components.
* Consistent evidence.
* Narrow game-specific adapters.

The goal is not:

* One monolithic studio harness that understands every game internally.

## Exit gate

* Every shared capability has one declared canonical owner.
* Title-specific responsibilities are explicit.
* No capability is declared shared merely because two scripts have similar names.

---

# Phase 4 — Define the shared performance evidence contract

## Objective

Allow SF, OF, OLH, and future projects to produce comparable evidence without requiring identical scenes or gameplay architecture.

## Shared result envelope

Define a versioned result schema containing:

* Schema version.
* Project/title ID.
* Fixture ID and version.
* Fixture configuration hash.
* Git commit.
* Dirty/clean state.
* Build type.
* Godot version.
* Platform.
* OS version.
* Device model.
* CPU/GPU information where available.
* Renderer/display server.
* Resolution.
* Render scale.
* VSync and FPS target.
* Warm-up duration.
* Measurement duration.
* Repetition index.
* Metric classifications.
* P50/P95/P99/max frame time.
* Simulation timing.
* Memory and object deltas.
* Available renderer counters.
* Protected-state status.
* Cleanup status.
* Errors and unsupported metrics.

## Shared metric classifications

Use:

* `DIRECT`
* `DERIVED`
* `CONFIGURATION_STATE`
* `UNAVAILABLE`
* `EXTERNAL_PROFILER_REQUIRED`

## Shared baseline rules

A baseline may not be approved when:

* The working tree is dirty.
* Fixture validation fails.
* Required fingerprints are missing.
* Protected-state isolation fails.
* Cleanup fails.
* Deterministic hashes differ.
* Unsupported metrics are represented as zero.
* Device evidence is required but unavailable.

## Exit gate

* The shared schema is documented and versioned.
* SF and OF can map their existing results into it without losing title-specific evidence.
* No current historical evidence is rewritten.

---

# Phase 5 — Add the reuse gate to Codex prompt templates

## Objective

Ensure the rule appears automatically in future engineering prompts rather than depending on memory or manual insertion.

## Standard prompt section

Add a mandatory block to engineering prompts involving testing or plumbing:

### Existing-capability discovery

Before implementation:

1. Search this repository for equivalent tools.
2. Search the ENTaP Tooling Registry.
3. Review relevant SF and OF implementations.
4. Identify the current canonical owner.
5. Classify any overlapping tools.
6. State whether the request should:

   * Reuse.
   * Configure.
   * Extend.
   * Adapt.
   * Extract proven common code.
   * Or create a new implementation.

Do not create a new parallel tool without a code-grounded ADR.

## Required planning response

Codex must report:

* Existing tools found.
* Paths and commands.
* Capability overlap.
* Reuse decision.
* Gaps.
* Proposed canonical owner.
* Duplicate/deprecation impact.
* Why a new implementation is necessary, when applicable.

## Required completion confirmation

Every applicable Codex completion must confirm:

* Current-repository tools were searched.
* Cross-project tools were reviewed.
* No unnecessary parallel implementation was created.
* Canonical documentation was updated.
* Retained duplicates were classified.
* Historical evidence was preserved.

## Exit gate

The block is present in:

* General Codex project initialization.
* Performance-work prompts.
* Test-harness prompts.
* Build/export prompts.
* Deployment prompts.
* New-title setup prompts.
* Release-readiness prompts.

---

# Phase 6 — Create the OLH engineering bootstrap review

## Objective

Prevent OLH from accumulating independent infrastructure before gameplay work expands.

## OLH bootstrap questions

Before OLH receives new performance or test plumbing, determine:

1. What engine and repository structure does OLH use?
2. Which SF deterministic/regression components apply?
3. Which OF component-isolation patterns apply?
4. Which parts require title-specific adapters?
5. What existing build/export tooling applies?
6. What existing device-evidence process applies?
7. What fixture types will OLH actually need?
8. Which SF or OF tools are inappropriate, and why?
9. Does OLH require any genuinely new capability?
10. Where will OLH-specific adapters live?

## Presumptive architecture

Begin with:

* Shared evidence schema.
* Shared percentile/comparator code where portable.
* Shared build/device fingerprint.
* Shared release-build guards.
* Shared protected-state conventions.
* SF-style deterministic fixture execution when appropriate.
* OF-style component isolation when appropriate.
* OLH-specific scene and simulation adapters.

## New-harness prohibition

A third independent OLH harness may not be approved merely because:

* Porting looks inconvenient.
* Existing tools use title-specific names.
* A clean rewrite would be aesthetically preferable.
* The implementing agent is unfamiliar with the existing code.
* The new game has different entities.

A new OLH harness requires an ADR proving:

* SF cannot safely provide the regression foundation.
* OF cannot safely provide the component-isolation foundation.
* Shared extraction would be riskier than a new implementation.
* The new implementation has a clear canonical scope.
* It will not become a third copy of shared metric and reporting logic.

## Exit gate

* OLH has a documented tooling architecture.
* Existing SF/OF components are explicitly assigned or rejected.
* No OLH-specific harness implementation begins without approval.

---

# Phase 7 — Pilot the governance on one real task

## Objective

Prove the governance works before declaring it complete.

Use an actual bounded task, preferably one of:

* The next SF performance fixture.
* An OF profiling extension.
* The first OLH performance requirement.
* A shared device-evidence improvement.

## Pilot requirements

The task must:

1. Consult the registry.
2. Identify existing tools.
3. Make a documented reuse decision.
4. Avoid building parallel infrastructure.
5. Update the registry if a capability changes.
6. Produce a completion confirmation against the new governance.

## Success criteria

* Discovery takes bounded effort.
* The registry points to working code and commands.
* The selected existing tool can be reused or extended.
* No unnecessary third implementation appears.
* The prompt was materially improved by having the registry.
* Any registry gaps discovered are corrected.

---

# Phase 8 — Consolidate only where evidence supports it

## Objective

Pay down known duplication without launching a speculative studio-framework rewrite.

## Candidate consolidation areas

After the inventory and pilot, evaluate:

* Percentile calculations.
* Result serialization.
* Baseline fingerprinting.
* Metric classification.
* Device/build metadata.
* Release-build guards.
* Evidence-summary generation.
* Protected-state comparison interfaces.

## Extraction rules

Extract code only when:

* At least two projects already use substantially equivalent behavior.
* The shared contract is stable.
* Parity tests exist.
* The extraction does not force title-specific state into the shared layer.
* A migration plan exists.
* The old implementations are classified.
* Historical evidence remains readable.

Do not create a shared abstraction simply because OLH might use it later.

## Exit gate

* Every extraction has two proven consumers.
* Title-specific adapters remain narrow.
* No “shared” package merely wraps duplicate implementations without replacing them.

---

# Phase 9 — Maintenance governance

## Registry update triggers

Update the registry whenever:

* A new tool is approved.
* A canonical command changes.
* A tool gains another supported project.
* A tool is deprecated.
* A duplicate is discovered.
* A result schema changes.
* A project adopts a shared adapter.
* A major engine upgrade affects compatibility.

## Periodic review

At major milestones:

* New game start.
* Beta readiness.
* Engine upgrade.
* Deployment architecture change.
* Performance sprint.
* Release-readiness sprint.

review:

* Canonical ownership.
* Duplicate implementations.
* Broken commands.
* Stale documentation.
* Unsupported projects.
* Migration status.

## Ownership

Assign one named or functional owner for:

* Governance Bible.
* Tooling Registry.
* Shared evidence schema.
* Performance infrastructure.
* Build/deployment infrastructure.

Ownership means maintaining discoverability and canonical status—not personally implementing every change.

---

# Recommended execution order

## Immediate

1. Update the Governance Bible.
2. Create the registry schema.
3. Inventory SF performance/testing tools.
4. Inventory OF performance/testing tools.
5. Classify canonical and overlapping tools.

## Next

6. Define the shared evidence contract.
7. Add the reuse gate to Codex prompt templates.
8. Create the OLH bootstrap review.
9. Pilot the rule on one real task.

## Later

10. Extract only proven common components.
11. Deprecate true duplicates after parity.
12. Maintain the registry at major project milestones.

---

# Required artifacts

1. Updated Governance Bible.
2. ENTaP Tooling Registry.
3. SF tooling inventory.
4. OF tooling inventory.
5. SF/OF capability comparison matrix.
6. Canonical ownership decision record.
7. Shared performance evidence schema.
8. Reuse-first Codex prompt block.
9. OLH tooling bootstrap decision.
10. Pilot evidence report.
11. Duplicate migration/deprecation list.

---

# Final acceptance criteria

This governance outcome is complete when:

* The reuse-first rule is in the canonical Governance Bible.
* Future Codex prompts automatically include the discovery gate.
* SF and OF tooling is discoverable by purpose and command.
* Every overlapping tool is classified.
* OLH has a reuse/adaptation architecture before new harness work begins.
* No third performance harness is created without a code-grounded ADR.
* Shared code is extracted only from proven overlap.
* Historical evidence remains intact.
* The registry has a named owner and maintenance trigger.
* One real engineering task has successfully followed the process.

## Final governing principle

**Before ENTaP builds new engineering plumbing, it must prove that the required capability does not already exist in usable, extensible, or adaptable form.**
