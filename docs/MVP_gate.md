# Swarmfront MVP Gate

## Purpose
Single low-cost gate to run before coding sessions and before TestFlight packaging.

## Release Readiness Gate

Command:

```bash
scripts/dev/run_release_readiness_gate.sh
```

This runs the MVP smoke plus the fast player config matrix gate. It is the default local gate before packaging or TestFlight work.

Useful variants:

```bash
scripts/dev/run_release_readiness_gate.sh --matrix-gate pr
scripts/dev/run_release_readiness_gate.sh --matrix-gate fast --matrix-no-soak
scripts/dev/run_release_readiness_gate.sh --matrix-gate nightly
scripts/dev/run_release_readiness_gate.sh --include-soak-gate
scripts/dev/run_release_readiness_gate.sh --include-tf-preflight
```

GitHub Actions wiring is available at `.github/workflows/release-readiness.yml` for a self-hosted macOS Godot runner.

## MVP Smoke Only

Command:

```bash
scripts/dev/run_mvp_smoke.sh
```

Optional map override:

```bash
MVP_SMOKE_MAP="res://maps/_future/knifefight/MAP_knifefight__SBASE__1p.json" scripts/dev/run_mvp_smoke.sh
```

Current automated checks (`scripts/dev/run_mvp_smoke.sh`, shell smoke mode):

1. Map preflight loads.
2. Shell spawns game + Arena.
3. Prematch records panel is visible during PREMATCH.
4. Prematch record text is populated.
5. Exactly one HUD prematch countdown label exists.
6. Match phase reaches RUNNING after prematch.
7. Prematch overlay hides after match start.
8. For wall maps: finds a hive pair whose segment crosses a wall and confirms lane intent is rejected (`reason=no_lane`).
9. Deterministic post-match flow on `MAP_TEST` (or override):
   - reaches `ENDED`
   - input lock is asserted in post-match
   - outcome overlay is visible
   - rematch votes trigger restart out of `ENDED`

## Player Config Matrix Gate

Command:

```bash
scripts/dev/run_player_config_matrix_gate.sh --gate fast
```

This validates the PvP configuration manifest, contract parity, topology boot routes, mode runtime routes, and a short deterministic soak sample.

Latest reports:

- `artifacts/player_config_matrix/latest.json`
- `artifacts/player_config_matrix/boot_routes_latest.json`
- `artifacts/player_config_matrix/soak_latest.json`

See `docs/player_config_matrix.md` for matrix details and replay commands.

## Required MVP Gates (tracking list)

1. `DONE` Prematch overlay + W/L by UUID visible and not duplicated.
2. `DONE` Wall authority active in sim (lane intents blocked across wall intersections).
3. `DONE (automated)` Post-match progression baseline:
   - winner resolve
   - end screen visible
   - rematch vote path
   - deterministic transition out of `ENDED` on rematch
4. `PENDING` Map lane generation policy lock:
   - no explicit per-map lane lists
   - blockers only: walls, geometry obstruction, lane budget
5. `PARTIAL (automated)` Perf/determinism soak threshold pass for target maps:
   - player config matrix fast soak is automated
   - broader perf soak still runs through `scripts/dev/run_soak_gate.sh`

## Tomorrow Focus (MVP path)

1. Finish post-match progression flow (Gate 3).
2. Lock lane generation policy and regressions (Gate 4).
3. Run soak + fix top 1-2 hotspots only (Gate 5).
