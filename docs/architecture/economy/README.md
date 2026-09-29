# Economy Architecture

Status: Platform authority implemented and deployed to certification; four
non-Crucible capabilities passed bounded canaries and are active there.

Authoritative documents:

- [ADR 001: Platform Economy and Progression Authority](adr-001-platform-economy-authority.md)
- [Current-to-Target Writer Matrix](current-target-writer-matrix.md)
- [Beta Certification Report — 2026-08-17](beta-certification-report-2026-08-17.md)
- [Canary Rollout Evidence — 2026-09-02](canary-rollout-evidence-2026-09-02.md)

Historical economy documents may still describe implemented code, but ADR 001
controls target ownership, idempotency, epoch/reset behavior, and the Crucible
`1000 + 1000 -> 1800 + 200` contract.

The August 17 report is the authoritative pre-canary baseline. The September 2
supplement records the later Honey/Nectar/Standard Wax rollout and the current
green reconciliation. Crucible Wax remains independently disabled.
