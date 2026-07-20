# Swarmfront Performance Harness V1 Work-Computer Handoff

Status: `READY FOR REVIEW`

Branch: `codex/perf-harness-v1-completion`

Sprint implementation/exit checkpoint: `d33bbf6`

Recommendation: `HARNESS V1 READY WITH LIMITATIONS`

The sprint is complete and pushed. It has not been merged or deployed. The authoritative review is [swarmfront_performance_harness_v1_exit.md](swarmfront_performance_harness_v1_exit.md); the machine-readable decision is `data/perf/harness_v1_exit.json`.

## Pick up the branch

From an existing Swarmfront clone:

```bash
git fetch origin
git switch codex/perf-harness-v1-completion
git pull --ff-only
git status --short
git rev-parse HEAD
```

If the branch does not exist locally, replace the `git switch` command with:

```bash
git switch --track origin/codex/perf-harness-v1-completion
```

Expected state: the worktree is clean and `HEAD` contains `d33bbf6` plus this documentation handoff commit.

## Five-minute verification

Run from the Godot project root:

```bash
godot --headless --path . --script res://tools/perf_phase2_gate_g_smoke_test.gd
jq '{status,recommendation,exit_matrix}' data/perf/harness_v1_exit.json
jq '{status,source_commit,reports:(.reports | length)}' data/perf/baselines/harness_v1/manifest.json
```

Expected results:

- `PERF_PHASE2_GATE_G_SMOKE: PASS`;
- exit status `COMPLETE` and recommendation `HARNESS V1 READY WITH LIMITATIONS`;
- approved baseline manifest from clean source commit `557a8e5`, containing four reports.

For a representative local execution check:

```bash
godot --headless --path . \
  --script res://scripts/tests/perf_benchmark_suite.gd -- \
  --sf-perf-harness \
  --perf-user-dir=SwarmfrontPerfWorkReview \
  --suite=phase1_normal_match \
  --mode=canonical_sim_headless \
  --collection-level=MINIMAL \
  --output=res://debug_reports/work_review_normal_canonical.json

jq '{pass,run_status,integrity_status,determinism:.determinism.pass,isolation:.isolation.pass,backend:.backend_isolation.pass,git}' \
  debug_reports/work_review_normal_canonical.json
```

That run should pass correctness and isolation. A different work computer will usually have a different environment fingerprint; do not force a timing comparison against the Apple M2 Pro package if the comparator reports `INCOMPATIBLE`.

## Review map

| Artifact | Purpose |
| --- | --- |
| `docs/swarmfront_performance_harness_v1_exit.md` | Complete human-readable evidence, limitations, and merge recommendation |
| `data/perf/harness_v1_exit.json` | Machine-readable decision and exit counts |
| `data/perf/baselines/harness_v1/manifest.json` | Approved clean-tree baseline package and report hashes |
| `data/perf/feature_isolation_registry_v1.json` | Forty-seven code-derived feature classifications and safe controls |
| `tools/perf_phase2_gate_g_smoke_test.gd` | Final package, program, limitation, and workflow gate |
| `docs/swarmfront_performance_harness_v1_completion_plan.md` | Phase-by-phase implementation record |

To review the sprint history and changes relative to the current target branch:

```bash
git log --oneline --decorate origin/main..HEAD
git diff --stat origin/main...HEAD
```

## Decisions still required

1. Accept or reject the documented physical-device GPU, thermal, and energy evidence gap.
2. Decide whether the pre-existing missing `barracks.PNG` and Godot console warnings must be resolved before merge or can remain separate product-quality work.
3. Choose merge-commit or squash policy. The pushed P2-A through P2-G commits provide useful rollback boundaries during review.

The agreed 3-player, 4-player, multi-map async, and multi-stage async work remains deferred. This branch also does not fix Jukebox post-match telemetry; that is separate production work.

## Guardrails

- Do not replace or overwrite `data/perf/baselines/phase1`; it is preserved for audit.
- Do not bypass an `INCOMPATIBLE` comparison or discard fingerprint fields.
- Do not promote Phase 2 diagnostic timings into approved regression baselines.
- Do not infer gameplay, backend, analytics, or post-match telemetry changes from this harness branch.
- Do not merge solely because the focused gates pass; review the explicit limitations first.

## Suggested review outcome

If the device-evidence gap and deferred scope are acceptable, merge the branch as `HARNESS V1 READY WITH LIMITATIONS`. If physical-device evidence is mandatory before integration, leave the branch unmerged, execute the exact iOS/Android workflow in the exit report, and append those artifacts in a separate review checkpoint.
