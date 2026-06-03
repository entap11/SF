# PvP Authority Audit

Core rule: OpsState/SimState is the only authoritative gameplay state. UI, render, input, networking, prediction, animation, and mobile runtime code may emit requests and render from state, but must not mutate gameplay state directly.

## Authoritative mutation sites

- `scripts/ops/ops_state.gd`
  - `apply_lane_intent(src_hive_id, dst_hive_id, intent)`: authoritative feed/attack/swarm command entry point.
  - `retract_lane(from_id, to_id, owner_id)`: authoritative lane retract entry point.
  - `request_barracks_route(...)`: authoritative barracks route entry point.
  - `reset_state_from_map(map_dict)`: authoritative map/state replacement entry point.
  - `with_remote_replication_apply(...)`: guarded path for applying already accepted replicated commands without re-publishing them.
- `scripts/systems/sim_runner.gd`
  - Owns deterministic simulation ticks against the OpsState-owned GameState.
  - Mutates simulation state only through bound SimState systems.
- `scripts/state/game_state.gd` and state systems under `scripts/systems/`
  - SimState internals used by OpsState/SimRunner. These are not UI/network entry points.
- `scripts/arena.gd`
  - Current PvP command consumption routes accepted commands back through OpsState.
  - Legacy Arena helpers still contain direct lane/swarm mutation code (`_set_intent`, `_set_intent_dev`, `_try_swarm`, `_force_friendly_direction`, and older local `swarm_packets` helpers). The current input/runtime search does not show these as active PvP entry points, but they remain audit targets if any legacy mode re-enables them.
  - Authoritative sim-time mutations in Arena (`_apply_unit_arrival`, `_update_idle_growth`, legacy swarm update helpers) must remain server/sim owned and must not be called by UI/network shortcuts.

## Intent request sites

- `scripts/systems/input_system.gd`
  - Converts pointer/UI gestures into `OpsState.apply_lane_intent(...)` or `OpsState.retract_lane(...)` requests.
- `scripts/state/vs_pvp_runtime.gd`
  - Publishes local PvP intent requests and consumes canonical accepted commands.
  - Must not directly mutate GameState; remote commands are applied only through OpsState entry points.
  - Maintains the accepted PvP command log, state-hash checkpoints, rolling authority snapshots, and desync recovery state.
- `scripts/state/vs_handshake_state.gd`
  - Local authority/transport facade. Assigns canonical `command_seq`, `command_id`, and `execute_tick` for accepted commands in local transport mode.

## PvP lane/swarm lifecycle

Input/UI request -> intent request -> validation -> authority assigns `command_seq` and canonical `execute_tick` -> append to accepted command log -> clients consume same ordered command log -> OpsState applies command deterministically -> state hash/telemetry logged -> render from state.

## Current guardrails

- Local PvP commands are scheduled by `VsPvpRuntime` and then applied via `OpsState.with_remote_replication_apply(...)`.
- Late commands within tolerance are delivered and logged as rebased/late.
- Commands outside tolerance enter `peer_desync_or_lagging`; Arena pauses the sim instead of continuing divergent play.
- State hash mismatch enters `peer_desync_or_lagging` and writes contract diagnostics.
- Hash checkpoints are generated from `OpsState.get_contract_state_hash()`, which includes authoritative map, match timer/outcome, hive, lane, unit, swarm, retract, tower, barracks, and cooldown state. Visual/UI/camera/audio state is excluded.
- `OpsState.get_authority_snapshot()` and `OpsState.restore_authority_snapshot(...)` provide rollback snapshots for authoritative state only.
- On a hash mismatch, Arena freezes match progression, blocks new gameplay intents, restores the latest matching authoritative snapshot, replays the canonical accepted command log, and resumes only if the recovered hash matches the peer hash.
- Failed recovery attempts move to a clean `desync_ended` state instead of allowing both clients to continue divergent games.
- `OS.crash()` is disabled by default for contract violations; diagnostics remain available in `user://vs_contract_violations.jsonl`.
- `OpsState.audit_mutation(...)` and `GameState.audit_mutation(...)` provide mutation-fence logging/assertion hooks for non-authority writes.

## Known follow-up

HTTP backend must return the same canonical command metadata as local `VsHandshake.publish_intent(...)`: `command_seq`, `command_id`, and canonical `execute_tick`. The client now consumes this metadata when available and falls back for compatibility, but production PvP authority depends on the backend preserving the same contract.

The current recovery replay restores a snapshot and reapplies the accepted command log through OpsState. If a future desync requires reconstructing intermediate continuous sim ticks between checkpoints, that replay should be extended to step SimRunner deterministically from the rollback tick to the desync tick using the same command log.
