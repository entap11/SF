extends RefCounted

const Fields = preload("res://scripts/persistence/checkpoint_fields.gd")
const OPS_FIELDS = ["timer_visible_started", "input_locked", "input_locked_reason", "match_over", "match_end_reason", "prematch_remaining_ms"]
const STATE_FIELDS = ["lane_sim_by_key", "_arrival_q", "production_event_receipt_tick", "production_event_local_ordinal_by_producer", "production_event_receipts_this_tick", "_available_lane_unattended_ms_by_hive", "_max_available_lane_unattended_ms_by_hive", "_high_power_idle_ms_by_hive", "_max_high_power_idle_ms_by_hive", "_execution_metrics_accum_ms"]
const SYSTEM_FIELDS = {
	"unit_system": ["units_set_version", "spawn_accum_by_lane", "_next_external_unit_id", "_next_uid", "_pass_through_queue_by_key", "_pass_through_emit_accum_ms_by_key", "_contested_capture_block_until_us_by_hive", "arrival_counts_by_hive_owner", "_pending_tower_hits"],
	"swarm_system": ["_next_swarm_id", "_recent_landed_swarms_by_hive"],
	"tower_system": ["tower_control_ms"],
	"barracks_system": ["barracks_control_ms"],
	"lane_system": ["_established_by_lane_id", "_next_lane_id"],
}
const RUNNER_FIELDS = ["_tick_accum", "_had_player_control_during_match", "_had_multiple_teams_during_match"]

static func capture(runner: Node, ops: Node) -> Dictionary:
	var systems: Dictionary = {}
	for key in SYSTEM_FIELDS:
		systems[key] = Fields.capture(runner.get(key), SYSTEM_FIELDS[key])
	return {
		"authority": ops.get_authority_snapshot(),
		"ops": Fields.capture(ops, OPS_FIELDS),
		"state": Fields.capture(ops.state, STATE_FIELDS),
		"systems": systems,
		"runner": Fields.capture(runner, RUNNER_FIELDS),
		"capture_flag_rng": ops.get("_capture_flag_rng").state,
	}

static func restore(runner: Node, ops: Node, saved: Dictionary) -> bool:
	if saved.get("authority", {}).is_empty():
		SFLog.error("SAVED_MATCH_RESTORE_REJECTED", {"reason": "missing_authority", "keys": saved.keys()})
		return false
	if ops.state == null:
		SFLog.error("SAVED_MATCH_RESTORE_REJECTED", {"reason": "missing_live_state"})
		return false
	runner.set_running(false, "saved_match_restore")
	if not ops.restore_authority_snapshot(saved.authority, false):
		return false
	Fields.restore(ops, OPS_FIELDS, saved.get("ops", {}))
	Fields.restore(ops.state, STATE_FIELDS, saved.get("state", {}))
	for key in SYSTEM_FIELDS:
		Fields.restore(runner.get(key), SYSTEM_FIELDS[key], saved.get("systems", {}).get(key, {}))
	Fields.restore(runner, RUNNER_FIELDS, saved.get("runner", {}))
	ops.get("_capture_flag_rng").state = int(saved.get("capture_flag_rng", 0))
	# Reconnect aliases after OpsState replaces its arrays. Do not bind/reset systems.
	runner.swarm_system.swarm_packets = ops.state.swarm_packets
	runner.tower_system.towers = ops.state.towers
	runner.barracks_system.barracks = ops.state.barracks
	runner.lane_system.bind_state(ops.state)
	Fields.restore(runner.lane_system, SYSTEM_FIELDS.lane_system, saved.get("systems", {}).get("lane_system", {}))
	runner.structure_control_system.bind_state(ops.state)
	runner.edge_cache_system.rebuild_edge_cache(ops)
	runner.win_system.bind_state(ops.state, ops)
	ops.prepare_saved_match_countdown()
	runner.set("_last_stats_ms", -200)
	runner.call("_update_match_stats", 0)
	return true
