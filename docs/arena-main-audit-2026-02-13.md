# Arena/Main Audit - 2026-02-13

## Scope
- Files reviewed for bloat, runtime cost, and authority model drift:
  - `scripts/arena.gd`
  - `scripts/main.gd`
  - `scripts/shell.gd`
  - `scripts/systems/input_system.gd`

## Current Size Snapshot
- Total GDScript LOC (scripts + scenes scripts): `45445`
- Top files by LOC:
  - `scripts/arena.gd`: `8681`
  - `scripts/renderers/unit_renderer.gd`: `2940`
  - `scripts/ui/main_menu.gd`: `2497`
  - `scripts/systems/input_system.gd`: `1915`
  - `scripts/shell.gd`: `1905`
  - `scripts/main.gd`: `265`

## Governance Check (Single Authority)
- Canonical governance is explicitly documented in:
  - `scripts/ops/ops_state.gd`
  - `scripts/arena.gd`
- Ops mutations are generally fenced via `OpsState.sim_mutate(...)` + `audit_mutation(...)`.
- Risk to track: `arena.gd` still carries a large surface area mixing orchestration, sim-adjacent flow, rendering/UI glue, and diagnostics in one file.

## Runtime Cost Findings
- `main.gd` had per-frame polling (`_process`) for Miss-N-Out banner state, including contest lookups.
- `arena.gd` had repeated subtree scans (`find_child("WorldViewport"...`) in runtime paths.
- `arena.gd` main process loop was monolithic, making hot-path reasoning and debugging harder.

## Changes Applied in This Tranche
- `scripts/main.gd`
  - Added throttled banner polling (`MISS_N_OUT_BANNER_POLL_SEC = 0.25`).
  - Added runtime signature cache to skip redundant banner recomputation.
  - Added cached `ContestState` node lookup.
- `scripts/arena.gd`
  - Added cached world viewport/container resolution helpers:
    - `_resolve_world_viewport_container_cached()`
    - `_resolve_world_subviewport_cached()`
  - Updated `_resize_world_viewport()` to use caches.
  - Split `_process(...)` into single-purpose helpers:
    - `_maybe_debug_camera_probe(...)`
    - `_tick_arena_heartbeat(...)`
    - `_tick_arena_runtime(...)`

## Tranche 2 Follow-up (Current)
- `scripts/arena.gd`
  - Extracted controls hint overlay lifecycle to `scripts/arena_helpers/controls_hint_controller.gd`.
  - Extracted world viewport lookup cache to `scripts/arena_helpers/world_viewport_cache.gd`.
  - `arena.gd` now orchestrates these helpers instead of owning all inline implementation.
- `scripts/main.gd`
  - Extracted Miss-N-Out banner runtime-state decision logic to `scripts/main_helpers/miss_n_out_banner_runtime.gd`.
  - `main.gd` now focuses on orchestration + polling cadence only.

## Tranche 3 Follow-up (Current)
- `scripts/shell.gd`
  - Extracted startup request resolution to `scripts/shell_helpers/startup_launch_request_resolver.gd`.
  - Extracted MVP async wait logic to `scripts/shell_helpers/mvp_waiter.gd`.
  - Extracted MVP map listing utility to `scripts/shell_helpers/mvp_map_utils.gd`.
  - `shell.gd` now delegates these responsibilities via helper wrappers.
- `scripts/systems/input_system.gd`
  - Extracted event and dev-mouse utility logic to `scripts/systems/input_helpers/input_event_utils.gd`.
  - `input_system.gd` now delegates pointer/world-pos and dev button mapping through the helper.

## Tranche 4 Follow-up (Current)
- `scripts/arena.gd`
  - Extracted stage runtime/match-flow utility logic to `scripts/arena_helpers/stage_runtime_flow.gd`:
    - stage mode detection
    - stage map/result runtime meta reads+writes
    - stage round upsert
    - owned-hive counts / opponent resolution / cumulative rank snapshot
  - Extracted prematch team-line formatting logic to `scripts/arena_helpers/prematch_team_ui_formatter.gd`.
  - Extracted input bridge utility logic to `scripts/arena_helpers/input_bridge_utils.gd`:
    - dev mouse override gating
    - dev pid mapping
    - canonical screen->world + pointer local conversion helpers
  - `arena.gd` now delegates these responsibilities via wrappers.

## Baseline Gate Status (2026-02-17)
- MVP smoke (`scripts/dev/run_mvp_smoke.sh`)
  - Outcome check now resolves overlay after runtime reparenting.
  - Summary observed: `passes=18`, `fails=0`.
- Soak gate (`scripts/dev/run_soak_gate.sh`)
  - Runner now boots through normal shell flow (`--soak-perf`) so autoloads are present.
  - Gate parser now supports warmup exclusion via `SOAK_WARMUP_SAMPLES` (default: `1`) to ignore the startup spike sample.
  - Latest 10-round equivalent example: `SOAK_SECONDS=100`, `SOAK_ROUND_SECONDS=10` -> `SOAK_GATE_PASS` with:
    - `max_frame_ms=7.00` (limit `45.00`)
    - `max_tick_ms=1.00` (limit `8.00`)
    - heartbeat samples `103` frame / `97` tick.

## Next Tranche (Recommended)
1. Extract UI overlay builders out of `arena.gd`:
   - post-match, prematch, controls hint.
2. Split `arena.gd` by responsibility:
   - match_flow
   - ui_flow
   - input_bridge
   - viewport_fit
   - diagnostics/debug
3. Move remaining heavy diagnostics under explicit debug gates and compile-time flags.
4. Add light perf telemetry around:
   - `_tick_arena_runtime`
   - input handling
   - overlay updates
5. Start same treatment for:
   - `scripts/shell.gd`
   - `scripts/systems/input_system.gd`
   - `scripts/ui/main_menu.gd`
