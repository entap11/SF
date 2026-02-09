# Swarmfront MVP Gate

## Purpose
Single low-cost gate to run before coding sessions and before TestFlight packaging.

## Automated Gate (run first)

Command:

```bash
scripts/dev/run_mvp_smoke.sh
```

Optional map override:

```bash
MVP_SMOKE_MAP="res://maps/json/MAP_RACE_WALLS_8x12_v1xy.json" scripts/dev/run_mvp_smoke.sh
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
5. `PENDING` Perf/determinism soak threshold pass for target maps.

## Tomorrow Focus (MVP path)

1. Finish post-match progression flow (Gate 3).
2. Lock lane generation policy and regressions (Gate 4).
3. Run soak + fix top 1-2 hotspots only (Gate 5).
