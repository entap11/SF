# Swarmfront Repository Governance

These instructions apply to all engineering work in this repository. Treat **MUST**, **MUST NOT**, **REQUIRED**, and **NEVER** as governance requirements, not suggestions.

## Critical-Path Placement — The Oven Rule (MANDATORY)

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
- Performance thresholds are contracts. MUST NOT raise or weaken a threshold merely to make a regression pass unless the user explicitly authorizes a threshold change.
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
