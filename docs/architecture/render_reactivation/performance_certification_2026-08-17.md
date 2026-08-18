# Godot 4.7.1 Performance Certification Attempt — 2026-08-17

Status: `SHORT PROBE PASS — FULL GATE NOT CERTIFIED`

Update: targeted diagnosis and the post-candidate remediation are recorded in
`performance_remediation_2026-08-18.md`. A bounded follow-up probe passes, but
the complete 1,800-second superseding-candidate gate remains pending.

This record preserves the unchanged-threshold performance work performed after
the all-off certification-estate deployment. It does not convert the release
status from `HOLD`.

## Bound inputs

- Git revision:
  `b409fc9797274c4a8a3cf895de7ba3d2d968197a`.
- Godot: `4.7.1.stable.official.a13da4feb`.
- Runner: `scripts/dev/run_soak_gate.sh` from the bound revision.
- Map: `res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json`.
- Pair count: 2.
- Unchanged maximum process time: 45.0 ms.
- Unchanged maximum simulation tick time: 8.0 ms.
- One heartbeat sample skipped as warmup, exactly as declared by the runner.

A detached exact-revision worktree was used. The first probe was stopped before
valid performance collection because a fresh worktree had no imported Godot
assets or generated global-class cache. The worktree was then prepared with
the same 224-class registry used by the certified candidate and imported under
the exact 4.7.1 editor. This is retained as setup failure evidence, not counted
as a performance result.

## Two-minute eligibility probe

The prepared 120-second probe exited normally and passed the unchanged gate:

| Metric | Observed | Limit | Result |
| --- | ---: | ---: | --- |
| Process | 29.50 ms | 45.00 ms | PASS |
| Simulation tick | 8.00 ms | 8.00 ms | PASS |
| Informational frame delta | 50.50 ms | 45.00 ms | informational only |

Required arena, renderer, and simulation heartbeat samples were present.

## Full-gate attempt

The 1,800-second gate was started with the same exact inputs and thresholds. It
was stopped after roughly five minutes because post-warmup maximums had already
irreversibly exceeded both release limits:

| Metric | Observed | Limit | Result |
| --- | ---: | ---: | --- |
| Arena process | 22.50 ms | 45.00 ms | PASS |
| Renderer process | 67.70 ms | 45.00 ms | FAIL |
| Combined process | 67.70 ms | 45.00 ms | FAIL |
| Simulation tick | 183.10 ms | 8.00 ms | FAIL |
| Informational frame delta | 144.60 ms | 45.00 ms | informational |

At stop time the retained log contained 353 post-warmup arena heartbeats, 706
renderer heartbeats, and 313 simulation heartbeats. Because these are maximum
limits, additional samples could not make the run pass. Stopping avoided
misrepresenting an already-failed host run as useful certification time.

The host had 16 logical CPUs and load averages around 2.6–3.8. An active macOS
virtualization process, WindowServer, editors, browsers, and the operator agent
were consuming CPU during the run. Virtualization is the likely source of the
largest stalls, but that is an inference and is not used to waive the failure.

## Retained artifacts

Artifacts are retained locally under
`artifacts/performance_certification_20260817/` and are intentionally not
committed as release source.

| Artifact | SHA-256 |
| --- | --- |
| Prepared two-minute probe | `65962b09c88b07f8b3265067402f055c480bde1d46b49f9d4bd3ba6e29c1fa18` |
| Stopped full-gate log | `17d4ac17f66fd58f4fd47b87dfeb031319cfc27dd57780a0978dd7a9a1be35c3` |

## Required rerun

The complete 1,800-second gate must be rerun without changing thresholds after
the virtualization workload and other avoidable CPU consumers are closed. The
host must remain otherwise idle for the entire run. A valid pass requires the
process to exit normally, all required heartbeat classes to be present, and
both maximums to remain within 45.0/8.0 ms after the declared warmup exclusion.
