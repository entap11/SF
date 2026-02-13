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

