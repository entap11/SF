extends Node

signal command_publish_result(payload: Dictionary)
signal match_lifecycle_changed(snapshot: Dictionary)
signal local_transport_interruption_changed(snapshot: Dictionary)

const SFLog := preload("res://scripts/util/sf_log.gd")
const VsHandshakeTransportHttp := preload("res://scripts/state/vs_handshake_transport_http.gd")

const POLL_INTERVAL_SEC: float = 0.10
const TELEMETRY_RATE_INTERVAL_MS: int = 1000
const ENV_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const ENV_BACKEND_TOKEN: String = "SF_VS_BACKEND_TOKEN"
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/vs/backend_timeout_sec"
const SETTINGS_CRASH_ON_CONTRACT_VIOLATION: String = "swarmfront/vs/crash_on_contract_violation"
const SETTINGS_HASH_RECOVERY_PAUSE_ENABLED: String = "swarmfront/vs/hash_recovery_pause_enabled"
const SETTINGS_RUNTIME_TELEMETRY_FILE_ENABLED: String = "swarmfront/vs/runtime_telemetry_file_enabled"
const ENV_RUNTIME_TELEMETRY_FILE_ENABLED: String = "SF_VS_RUNTIME_TELEMETRY_JSONL"
const FEATURE_PRIVATE_PVP_DIAGNOSTICS: String = "private_pvp_diagnostics"
const DEFAULT_BACKEND_TIMEOUT_SEC: float = 6.0
const CRASH_ON_CONTRACT_VIOLATION_DEFAULT: bool = false
const HASH_RECOVERY_PAUSE_ENABLED_DEFAULT: bool = false
const CONTRACT_VERSION: int = 1
const CONTRACT_DIAGNOSTIC_LOG_PATH: String = "user://vs_contract_violations.jsonl"
const RUNTIME_TELEMETRY_LOG_DIR: String = "user://pvp_runtime"
const RUNTIME_TELEMETRY_SAMPLE_INTERVAL_MS: int = 1000
const RUNTIME_TELEMETRY_SLOW_RTT_MS: float = 750.0
const COMMAND_LEAD_TICKS: int = 6
const FALLBACK_AUTH_COMMAND_LEAD_TICKS: int = 6
const COMMAND_LATE_TOLERANCE_TICKS: int = 8
const HASH_INTERVAL_TICKS: int = 5
const HASH_RETENTION_TICKS: int = 180
const HASH_MISMATCH_RECOVERY_THRESHOLD: int = 3
const HASH_STARTUP_GRACE_TICKS: int = 30
const LOCAL_TRANSPORT_GRACE_FALLBACK_SEC: int = 60
const LOCAL_TRANSPORT_STALE_FALLBACK_MS: int = 2500
const LOCAL_TRANSPORT_PAUSE_SAFETY_MS: int = 250
const DEBUG_EVENT_LIMIT: int = 10
const RECOVERY_STATE_RUNNING: String = "running"
const RECOVERY_STATE_WAITING_FOR_PEER: String = "waiting_for_peer"
const RECOVERY_STATE_DESYNC_RECOVERY: String = "desync_recovery"
const RECOVERY_STATE_DESYNC_ENDED: String = "desync_ended"
const RECOVERY_HISTORY_TICKS: int = 120
const RECOVERY_MAX_ATTEMPTS: int = 2
const ALLOWED_LANE_INTENTS: Dictionary = {
	"attack": true,
	"feed": true,
	"swarm": true,
	"none": true
}

var _active: bool = false
var _session_id: String = ""
var _mode: String = ""
var _role: String = ""
var _local_uid: String = ""
var _local_seat: int = 1
var _remote_uid: String = ""
var _remote_seat: int = 2
var _remote_uids: PackedStringArray = PackedStringArray()
var _remote_seat_by_uid: Dictionary = {}
var _last_seq: int = 0
var _match_lifecycle: Dictionary = {"phase": "running", "epoch": 0}
var _match_lifecycle_signature: String = ""
var _last_authoritative_server_unix_ms: int = 0
var _last_authoritative_server_local_ms: int = 0
var _local_transport_interruption: Dictionary = {}
var _local_transport_pause_emitted: bool = false
var _poll_accum: float = 0.0
var _pending_remote_commands: Array[Dictionary] = []
var _local_hash_by_tick: Dictionary = {}
var _remote_hash_by_tick: Dictionary = {}
var _remote_hash_by_peer_tick: Dictionary = {}
var _local_hash_debug_by_tick: Dictionary = {}
var _remote_hash_debug_by_tick: Dictionary = {}
var _packet_tx: int = 0
var _packet_rx: int = 0
var _packet_dropped: int = 0
var _publish_count: int = 0
var _publish_fail_count: int = 0
var _poll_count: int = 0
var _poll_fail_count: int = 0
var _intent_events_tx: int = 0
var _intent_events_rx: int = 0
var _remote_commands_rx: int = 0
var _last_rtt_ms: float = 0.0
var _rtt_ema_ms: float = 0.0
var _server_tick_rate_hz: float = 0.0
var _server_frametime_ms: float = 0.0
var _rate_window_start_ms: int = 0
var _rate_window_rx_events: int = 0
var _snapshot_receive_rate_hz: float = 0.0
var _poll_thread: Thread = null
var _poll_inflight: bool = false
var _poll_generation: int = 0
var _publish_thread: Thread = null
var _publish_inflight: bool = false
var _publish_generation: int = 0
var _publish_queue: Array[Dictionary] = []
var _spectator_snapshot_thread: Thread = null
var _spectator_snapshot_inflight: bool = false
var _spectator_snapshot_generation: int = 0
var _spectator_snapshot_tx: int = 0
var _spectator_snapshot_fail_count: int = 0
var _last_spectator_snapshot_result: Dictionary = {}
var _contract_violation_count: int = 0
var _last_contract_violation: Dictionary = {}
var _contract_current_command_lead_ticks: int = -1
var _contract_min_command_lead_ticks: int = 2147483647
var _contract_missed_scheduled_commands: int = 0
var _contract_late_scheduled_commands: int = 0
var _contract_buffered_lagging_commands: int = 0
var _contract_state_hash_mismatches: int = 0
var _contract_last_violation_reason: String = ""
var _hash_mismatch_consecutive_count: int = 0
var _hash_mismatch_first_tick: int = -1
var _hash_mismatch_last_tick: int = -1
var _hash_mismatch_first_ms: int = 0
var _hash_mismatch_last_ms: int = 0
var _hash_mismatch_last_details: Dictionary = {}
var _peer_desync_or_lagging: bool = false
var _peer_desync_or_lagging_reason: String = ""
var _peer_desync_or_lagging_details: Dictionary = {}
var _recovery_state: String = RECOVERY_STATE_RUNNING
var _recovery_attempts: int = 0
var _recovery_last_outcome: String = ""
var _recovery_desync_tick: int = -1
var _recovery_remote_hash: String = ""
var _recovery_local_hash: String = ""
var _last_matching_checkpoint_tick: int = -1
var _authority_snapshots_by_tick: Dictionary = {}
var _accepted_command_log: Array[Dictionary] = []
var _debug_event_log: Array[Dictionary] = []
var _last_debug_event: Dictionary = {}
var _desync_event_before_divergence: Dictionary = {}
var _last_publish_result: Dictionary = {}
var _client_command_counter: int = 0
var _runtime_telemetry_log_path: String = ""
var _runtime_telemetry_log_started: bool = false
var _runtime_telemetry_last_sample_ms: int = 0
var _runtime_telemetry_write_ms_last: float = 0.0
var _runtime_telemetry_write_ms_max: float = 0.0
var _runtime_telemetry_write_count: int = 0
var _first_mismatch_snapshot_queued: bool = false

func _exit_tree() -> void:
	_poll_generation += 1
	_publish_generation += 1
	_spectator_snapshot_generation += 1
	_finish_poll_thread(true)
	_finish_publish_thread(true)
	_finish_spectator_snapshot_thread(true)

func clear() -> void:
	_poll_generation += 1
	_publish_generation += 1
	_spectator_snapshot_generation += 1
	_finish_poll_thread(true)
	_finish_publish_thread(true)
	_finish_spectator_snapshot_thread(true)
	_active = false
	_session_id = ""
	_mode = ""
	_role = ""
	_local_uid = ""
	_local_seat = 1
	_remote_uid = ""
	_remote_seat = 2
	_remote_uids = PackedStringArray()
	_remote_seat_by_uid.clear()
	_last_seq = 0
	_match_lifecycle = {"phase": "running", "epoch": 0}
	_match_lifecycle_signature = ""
	_last_authoritative_server_unix_ms = 0
	_last_authoritative_server_local_ms = 0
	_local_transport_interruption = {}
	_local_transport_pause_emitted = false
	_poll_accum = 0.0
	_pending_remote_commands.clear()
	_local_hash_by_tick.clear()
	_remote_hash_by_tick.clear()
	_remote_hash_by_peer_tick.clear()
	_local_hash_debug_by_tick.clear()
	_remote_hash_debug_by_tick.clear()
	_debug_event_log.clear()
	_last_debug_event = {}
	_desync_event_before_divergence = {}
	_last_publish_result = {}
	_hash_mismatch_consecutive_count = 0
	_hash_mismatch_first_tick = -1
	_hash_mismatch_last_tick = -1
	_hash_mismatch_first_ms = 0
	_hash_mismatch_last_ms = 0
	_hash_mismatch_last_details = {}
	_peer_desync_or_lagging = false
	_peer_desync_or_lagging_reason = ""
	_peer_desync_or_lagging_details = {}
	_recovery_state = RECOVERY_STATE_RUNNING
	_recovery_attempts = 0
	_recovery_last_outcome = ""
	_recovery_desync_tick = -1
	_recovery_remote_hash = ""
	_recovery_local_hash = ""
	_recovery_state = RECOVERY_STATE_RUNNING
	_recovery_attempts = 0
	_recovery_last_outcome = ""
	_recovery_desync_tick = -1
	_recovery_remote_hash = ""
	_recovery_local_hash = ""
	_last_matching_checkpoint_tick = -1
	_authority_snapshots_by_tick.clear()
	_accepted_command_log.clear()
	_publish_queue.clear()
	_spectator_snapshot_tx = 0
	_spectator_snapshot_fail_count = 0
	_last_spectator_snapshot_result = {}
	_client_command_counter = 0
	_runtime_telemetry_log_path = ""
	_runtime_telemetry_log_started = false
	_runtime_telemetry_last_sample_ms = 0
	_runtime_telemetry_write_ms_last = 0.0
	_runtime_telemetry_write_ms_max = 0.0
	_runtime_telemetry_write_count = 0
	_first_mismatch_snapshot_queued = false
	_reset_contract_diagnostics()
	_reset_telemetry()

func configure_from_tree(tree: SceneTree, roster: Array) -> void:
	clear()
	if tree == null:
		return
	var session_id: String = str(tree.get_meta("vs_handshake_session_id", "")).strip_edges()
	if session_id.is_empty():
		return
	var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
	var local_profile: Dictionary = local_profile_any as Dictionary if typeof(local_profile_any) == TYPE_DICTIONARY else {}
	var local_uid: String = str(local_profile.get("uid", "")).strip_edges()
	if local_uid.is_empty() and ProfileManager != null:
		local_uid = ProfileManager.get_user_id()
	if local_uid.is_empty():
		return
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	_session_id = session_id
	_mode = str(tree.get_meta("vs_mode", "")).strip_edges()
	_role = role
	_local_uid = local_uid
	var required_players: int = int(tree.get_meta("vs_required_players", 2))
	_local_seat = _resolve_local_seat(roster, local_uid, role, _mode, required_players)
	if _local_seat <= 0:
		SFLog.allow_tag("VS_PVP_RUNTIME_CONFIG")
		SFLog.warn("VS_PVP_RUNTIME_CONFIG", {
			"active": false,
			"session_id": _session_id,
			"mode": _mode,
			"local_uid": _local_uid,
			"role": role,
			"reason": "local_seat_unresolved"
		})
		return
	_remote_uid = _resolve_remote_uid(roster, local_uid)
	_remote_seat = _resolve_remote_seat(roster, _local_seat)
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var peer_uid: String = str(entry.get("uid", "")).strip_edges()
		var peer_seat: int = int(entry.get("seat", 0))
		if peer_uid.is_empty() or peer_uid == local_uid or peer_seat < 1 or peer_seat > 4 or not bool(entry.get("active", true)):
			continue
		_remote_uids.append(peer_uid)
		_remote_seat_by_uid[peer_uid] = peer_seat
	_active = true
	SFLog.allow_tag("VS_PVP_RUNTIME_CONFIG")
	SFLog.info("VS_PVP_RUNTIME_CONFIG", {
		"active": _active,
		"session_id": _session_id,
		"mode": _mode,
		"local_uid": _local_uid,
		"local_seat": _local_seat,
		"remote_uid": _remote_uid,
		"remote_seat": _remote_seat,
		"remote_uids": _remote_uids.duplicate(),
		"remote_seat_by_uid": _remote_seat_by_uid.duplicate(true),
		"role": role
	})

func is_active() -> bool:
	return _active and not _session_id.is_empty() and not _local_uid.is_empty()

func get_local_seat() -> int:
	return _local_seat

func get_remote_seat() -> int:
	return _remote_seat

func get_seat_for_uid(uid: String) -> int:
	var clean_uid: String = uid.strip_edges()
	if clean_uid == _local_uid:
		return _local_seat
	if clean_uid == _remote_uid:
		return _remote_seat
	return int(_remote_seat_by_uid.get(clean_uid, 0))

func get_role() -> String:
	return _role

func get_local_uid() -> String:
	return _local_uid

func get_match_lifecycle() -> Dictionary:
	return _match_lifecycle.duplicate(true)

func get_match_lifecycle_phase() -> String:
	return str(_match_lifecycle.get("phase", "running")).strip_edges().to_lower()

func is_local_transport_interrupted() -> bool:
	return not _local_transport_interruption.is_empty()

func get_local_transport_interruption() -> Dictionary:
	return _local_transport_interruption.duplicate(true)

func get_debug_event_log() -> Array:
	return _debug_event_log.duplicate(true)

func get_last_debug_event() -> Dictionary:
	return _last_debug_event.duplicate(true)

func get_debug_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"session_id": _session_id,
		"mode": _mode,
		"role": _role,
		"local_uid": _local_uid,
		"local_seat": _local_seat,
		"remote_uid": _remote_uid,
		"remote_seat": _remote_seat,
		"remote_uids": _remote_uids.duplicate(),
		"remote_seat_by_uid": _remote_seat_by_uid.duplicate(true),
		"publish_count": _publish_count,
		"publish_fail_count": _publish_fail_count,
		"poll_count": _poll_count,
		"poll_fail_count": _poll_fail_count,
		"intent_events_tx": _intent_events_tx,
		"intent_events_rx": _intent_events_rx,
		"remote_commands_rx": _remote_commands_rx,
		"pending_commands": _pending_remote_commands.size(),
		"publish_in_flight": _publish_inflight,
		"publish_queue_size": _publish_queue.size(),
		"spectator_snapshot_in_flight": _spectator_snapshot_inflight,
		"spectator_snapshot_tx": _spectator_snapshot_tx,
		"spectator_snapshot_fail_count": _spectator_snapshot_fail_count,
		"last_spectator_snapshot_result": _last_spectator_snapshot_result.duplicate(true),
		"events": get_debug_event_log(),
		"last_event": get_last_debug_event(),
		"desync": _peer_desync_or_lagging or _recovery_state != RECOVERY_STATE_RUNNING,
		"desync_event_before_divergence": _desync_event_before_divergence.duplicate(true),
		"hash_mismatch_consecutive_count": _hash_mismatch_consecutive_count,
		"hash_mismatch_last_details": _hash_mismatch_last_details.duplicate(true),
		"peer_desync_or_lagging": _peer_desync_or_lagging,
		"peer_desync_or_lagging_reason": _peer_desync_or_lagging_reason,
		"peer_desync_or_lagging_details": _peer_desync_or_lagging_details.duplicate(true),
		"recovery_state": _recovery_state,
		"recovery_attempts": _recovery_attempts,
		"recovery_last_outcome": _recovery_last_outcome,
		"recovery_desync_tick": _recovery_desync_tick,
		"last_matching_checkpoint_tick": _last_matching_checkpoint_tick,
		"accepted_command_log_size": _accepted_command_log.size(),
		"runtime_telemetry_log_path": _runtime_telemetry_log_path,
		"runtime_telemetry_file_enabled": _runtime_telemetry_file_enabled(),
		"telemetry_write_ms": snappedf(_runtime_telemetry_write_ms_last, 0.1),
		"telemetry_write_ms_max": snappedf(_runtime_telemetry_write_ms_max, 0.1),
		"telemetry_write_count": _runtime_telemetry_write_count,
		"last_rtt_ms": snappedf(_last_rtt_ms, 0.1),
		"rtt_ema_ms": snappedf(_rtt_ema_ms, 0.1),
		"last_publish_result": _last_publish_result.duplicate(true),
		"local_transport_interrupted": is_local_transport_interrupted(),
		"local_transport_interruption": get_local_transport_interruption(),
		"last_contract_violation": _last_contract_violation.duplicate(true),
		"diagnostics": _contract_diagnostics_snapshot()
	}

func is_peer_desync_or_lagging() -> bool:
	return _peer_desync_or_lagging

func get_peer_desync_or_lagging_reason() -> String:
	return _peer_desync_or_lagging_reason

func get_peer_desync_or_lagging_details() -> Dictionary:
	return _peer_desync_or_lagging_details.duplicate(true)

func get_recovery_state() -> String:
	return _recovery_state

func is_recovering_or_ended() -> bool:
	return _recovery_state == RECOVERY_STATE_DESYNC_RECOVERY or _recovery_state == RECOVERY_STATE_DESYNC_ENDED

func can_accept_gameplay_intents() -> bool:
	return is_active() and not is_local_transport_interrupted() \
		and _recovery_state == RECOVERY_STATE_RUNNING and get_match_lifecycle_phase() == "running"

func notify_match_backgrounded(reason: String) -> Dictionary:
	return _send_match_presence("backgrounded", {
		"reason": reason,
		"sim_tick": _current_sim_tick()
	})

func notify_match_foregrounded(reason: String) -> Dictionary:
	return _send_match_presence("foregrounded", {
		"reason": reason,
		"sim_tick": _current_sim_tick()
	})

func publish_reconnect_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {"ok": false, "err": "snapshot_missing"}
	return _send_match_presence("snapshot", {
		"sim_tick": int(snapshot.get("tick", _current_sim_tick())),
		"snapshot": snapshot.duplicate(true)
	})

func acknowledge_reconnect_snapshot() -> Dictionary:
	return _send_match_presence("resume_ack", {"sim_tick": _current_sim_tick()})

func complete_reconnect_snapshot_restore(snapshot_tick: int) -> void:
	var restored_tick: int = maxi(0, snapshot_tick)
	var remaining_commands: Array[Dictionary] = []
	for command_any in _pending_remote_commands:
		var command: Dictionary = command_any as Dictionary
		if int(command.get("execute_tick", -1)) > restored_tick:
			remaining_commands.append(command)
	_pending_remote_commands = remaining_commands
	var remaining_log: Array[Dictionary] = []
	for command_any in _accepted_command_log:
		var command: Dictionary = command_any as Dictionary
		if int(command.get("execute_tick", -1)) > restored_tick:
			remaining_log.append(command)
	_accepted_command_log = remaining_log
	_local_hash_by_tick.clear()
	_remote_hash_by_tick.clear()
	_remote_hash_by_peer_tick.clear()
	_local_hash_debug_by_tick.clear()
	_remote_hash_debug_by_tick.clear()
	_authority_snapshots_by_tick.clear()
	_last_matching_checkpoint_tick = restored_tick

func _send_match_presence(status: String, details: Dictionary = {}) -> Dictionary:
	if not is_active():
		return {"ok": false, "err": "runtime_inactive"}
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("match_presence"):
		return {"ok": false, "err": "match_presence_unavailable"}
	var request_started_local_us: int = Time.get_ticks_usec()
	var result: Dictionary = handshake.call("match_presence", _session_id, _local_uid, status, details) as Dictionary
	var connectivity_current: bool = _observe_transport_connectivity(
		"presence", result, request_started_local_us
	)
	if connectivity_current and bool(result.get("ok", false)):
		_update_match_lifecycle(result.get("match_lifecycle", {}))
	return result

func _current_sim_tick() -> int:
	if OpsState == null or not OpsState.has_method("get_state"):
		return 0
	var state_any: Variant = OpsState.call("get_state")
	if state_any == null:
		return 0
	return maxi(0, int(state_any.get("tick")))

func _update_match_lifecycle(snapshot_any: Variant) -> void:
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		return
	var snapshot: Dictionary = (snapshot_any as Dictionary).duplicate(true)
	if snapshot.is_empty():
		return
	_record_authoritative_server_clock(snapshot)
	var signature: String = "%s|%d|%s|%d|%d|%s|%s|%d|%s" % [
		str(snapshot.get("phase", "running")),
		int(snapshot.get("epoch", 0)),
		str(snapshot.get("disconnected_uid", "")),
		int(snapshot.get("grace_deadline_unix_ms", 0)),
		int(snapshot.get("resume_unix_ms", 0)),
		str(snapshot.get("winner_uid", "")),
		str(snapshot.get("terminal_reason", "")),
		int(snapshot.get("local_disconnect_strikes", 0)),
		str(snapshot.get("resume_snapshot_ready", false))
	]
	_match_lifecycle = snapshot
	if signature == _match_lifecycle_signature:
		return
	_match_lifecycle_signature = signature
	match_lifecycle_changed.emit(snapshot.duplicate(true))

func tick(delta: float) -> void:
	_finish_poll_thread(false)
	_finish_publish_thread(false)
	_finish_spectator_snapshot_thread(false)
	_refresh_local_transport_interruption()
	if not is_active():
		_update_runtime_telemetry()
		return
	_poll_accum += maxf(0.0, delta)
	_roll_telemetry_rates()
	_update_runtime_telemetry()
	if _poll_accum < POLL_INTERVAL_SEC:
		return
	_poll_accum = 0.0
	_poll_remote_intents()

func consume_remote_commands(target_tick: int = -1) -> Array:
	if _recovery_state != RECOVERY_STATE_RUNNING:
		return []
	if _pending_remote_commands.is_empty():
		return []
	if target_tick < 0:
		var all_out: Array = _pending_remote_commands.duplicate(true)
		_pending_remote_commands.clear()
		return all_out
	var out: Array = []
	var remaining: Array[Dictionary] = []
	for command_any in _pending_remote_commands:
		var command: Dictionary = command_any as Dictionary
		var execute_tick: int = int(command.get("execute_tick", -1))
		_observe_command_lead(execute_tick, target_tick)
		if execute_tick <= target_tick:
			if execute_tick < target_tick:
				var late_delta: int = target_tick - execute_tick
				if late_delta > COMMAND_LATE_TOLERANCE_TICKS:
					_record_late_scheduled_command(command, target_tick, late_delta, true)
				else:
					_record_late_scheduled_command(command, target_tick, late_delta, false)
			out.append(command)
		else:
			remaining.append(command)
	_pending_remote_commands = remaining
	out.sort_custom(Callable(self, "_sort_commands_by_contract_order"))
	return out

func record_local_state_hash(tick: int, state_hash: String, authority_snapshot: Dictionary = {}) -> bool:
	if not is_active():
		return true
	var safe_tick: int = int(tick)
	if safe_tick < 0:
		return true
	if safe_tick % HASH_INTERVAL_TICKS != 0:
		return true
	var clean_hash: String = str(state_hash).strip_edges()
	if clean_hash.is_empty():
		return _contract_violation("local_state_hash_empty", {"tick": safe_tick})
	_local_hash_by_tick[safe_tick] = clean_hash
	var state_debug: Dictionary = _certification_hash_debug_snapshot()
	if not state_debug.is_empty():
		_local_hash_debug_by_tick[safe_tick] = state_debug
	_record_authority_snapshot(safe_tick, clean_hash, authority_snapshot)
	_prune_hash_windows(safe_tick)
	_compare_state_hash_if_ready(safe_tick)
	var command: Dictionary = _contract_command_base("state_hash")
	command.merge({
		"hash_tick": safe_tick,
		"state_hash": clean_hash
	})
	if not state_debug.is_empty():
		command["state_debug"] = state_debug.duplicate(true)
	if not _validate_contract_command(command, "outgoing"):
		return false
	return _publish_command(command)

func _record_authority_snapshot(tick: int, state_hash: String, authority_snapshot: Dictionary) -> void:
	if authority_snapshot.is_empty():
		return
	var safe_tick: int = int(tick)
	var snapshot: Dictionary = authority_snapshot.duplicate(true)
	snapshot["tick"] = safe_tick
	snapshot["hash"] = state_hash
	_authority_snapshots_by_tick[safe_tick] = snapshot
	_prune_authority_snapshots(safe_tick)

func _prune_authority_snapshots(latest_tick: int) -> void:
	var min_tick: int = maxi(0, int(latest_tick) - RECOVERY_HISTORY_TICKS)
	for tick_any in _authority_snapshots_by_tick.keys():
		if int(tick_any) < min_tick:
			_authority_snapshots_by_tick.erase(tick_any)

func _sort_commands_by_contract_order(a: Dictionary, b: Dictionary) -> bool:
	var a_seq: int = int(a.get("command_seq", 0))
	var b_seq: int = int(b.get("command_seq", 0))
	if a_seq > 0 and b_seq > 0 and a_seq != b_seq:
		return a_seq < b_seq
	var a_tick: int = int(a.get("execute_tick", 0))
	var b_tick: int = int(b.get("execute_tick", 0))
	if a_tick != b_tick:
		return a_tick < b_tick
	var a_seat: int = int(a.get("sender_seat", a.get("src_owner", a.get("owner_id", 0))))
	var b_seat: int = int(b.get("sender_seat", b.get("src_owner", b.get("owner_id", 0))))
	if a_seat != b_seat:
		return a_seat < b_seat
	var a_ms: int = int(a.get("issued_ms", 0))
	var b_ms: int = int(b.get("issued_ms", 0))
	return a_ms < b_ms

func _queue_scheduled_command(command: Dictionary) -> void:
	var normalized: Dictionary = _normalize_authoritative_command(command, -1)
	var command_id: String = str(normalized.get("command_id", "")).strip_edges()
	var client_command_id: String = _client_command_id(normalized)
	for i in range(_pending_remote_commands.size()):
		var pending: Dictionary = _pending_remote_commands[i] as Dictionary
		if _commands_share_identity(pending, command_id, client_command_id):
			_pending_remote_commands[i] = normalized
			_upsert_accepted_command_log(normalized)
			return
	if _accepted_command_log_has_identity(command_id, client_command_id):
		_upsert_accepted_command_log(normalized)
		return
	_upsert_accepted_command_log(normalized)
	_pending_remote_commands.append(normalized)

func _append_accepted_command_log(command: Dictionary) -> void:
	_upsert_accepted_command_log(command)

func _upsert_accepted_command_log(command: Dictionary) -> void:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	if kind.is_empty() or kind == "state_hash":
		return
	var normalized: Dictionary = _normalize_authoritative_command(command, int(command.get("command_seq", -1)))
	var command_id: String = str(normalized.get("command_id", "")).strip_edges()
	var client_command_id: String = _client_command_id(normalized)
	for i in range(_accepted_command_log.size()):
		var existing: Dictionary = _accepted_command_log[i] as Dictionary
		if _commands_share_identity(existing, command_id, client_command_id):
			_accepted_command_log[i] = normalized.duplicate(true)
			_accepted_command_log.sort_custom(Callable(self, "_sort_commands_by_contract_order"))
			_prune_accepted_command_log()
			return
	_accepted_command_log.append(normalized.duplicate(true))
	_accepted_command_log.sort_custom(Callable(self, "_sort_commands_by_contract_order"))
	_prune_accepted_command_log()

func _accepted_command_log_has_identity(command_id: String, client_command_id: String) -> bool:
	for existing_any in _accepted_command_log:
		var existing: Dictionary = existing_any as Dictionary
		if _commands_share_identity(existing, command_id, client_command_id):
			return true
	return false

func _commands_share_identity(command: Dictionary, command_id: String, client_command_id: String) -> bool:
	if not client_command_id.is_empty() and _client_command_id(command) == client_command_id:
		return true
	if not command_id.is_empty() and str(command.get("command_id", "")).strip_edges() == command_id:
		return true
	return false

func _client_command_id(command: Dictionary) -> String:
	return str(command.get("client_command_id", "")).strip_edges()

func _prune_accepted_command_log() -> void:
	if _last_matching_checkpoint_tick < 0:
		return
	var min_tick: int = maxi(0, _last_matching_checkpoint_tick - RECOVERY_HISTORY_TICKS)
	var kept: Array[Dictionary] = []
	for command_any in _accepted_command_log:
		var command: Dictionary = command_any as Dictionary
		if int(command.get("execute_tick", -1)) >= min_tick:
			kept.append(command)
	_accepted_command_log = kept

func _canonical_command_from_publish_result(request_command: Dictionary, result: Dictionary) -> Dictionary:
	var command_any: Variant = result.get("canonical_command", result.get("command", {}))
	if typeof(command_any) == TYPE_DICTIONARY:
		return _normalize_authoritative_command(command_any as Dictionary, int(result.get("seq", -1)))
	var fallback: Dictionary = request_command.duplicate(true)
	var seq: int = int(result.get("command_seq", result.get("seq", -1)))
	if seq > 0:
		fallback["command_seq"] = seq
		if not fallback.has("command_id"):
			fallback["command_id"] = "%s:%d" % [_session_id, seq]
	return _normalize_authoritative_command(fallback, seq)

func _normalize_authoritative_command(command: Dictionary, event_seq: int) -> Dictionary:
	var normalized: Dictionary = command.duplicate(true)
	var seq: int = int(normalized.get("command_seq", event_seq))
	if seq > 0:
		normalized["command_seq"] = seq
		if str(normalized.get("command_id", "")).strip_edges().is_empty():
			normalized["command_id"] = "%s:%d" % [_session_id, seq]
	var requested_execute_tick: int = int(normalized.get("requested_execute_tick", normalized.get("execute_tick", -1)))
	if not normalized.has("requested_execute_tick"):
		normalized["requested_execute_tick"] = requested_execute_tick
	if normalized.has("canonical_execute_tick"):
		normalized["execute_tick"] = int(normalized.get("canonical_execute_tick", normalized.get("execute_tick", -1)))
	elif normalized.has("execute_tick"):
		var issued_tick: int = int(normalized.get("issued_tick", normalized.get("local_issued_tick", -1)))
		var fallback_execute_tick: int = int(normalized.get("execute_tick", -1))
		if issued_tick >= 0 and fallback_execute_tick < issued_tick + FALLBACK_AUTH_COMMAND_LEAD_TICKS:
			fallback_execute_tick = issued_tick + FALLBACK_AUTH_COMMAND_LEAD_TICKS
			normalized["authority_action"] = "rebased"
		normalized["canonical_execute_tick"] = fallback_execute_tick
		normalized["execute_tick"] = fallback_execute_tick
	return normalized

func _record_local_command_accepted(command: Dictionary) -> void:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	var intent: String = str(command.get("intent", "")).strip_edges().to_lower()
	var event_type: String = "command_sent"
	if kind == "lane_intent":
		event_type = "swarm_intent_sent" if intent == "swarm" else "lane_intent_sent"
	elif kind == "lane_retract":
		event_type = "lane_retract_sent"
	elif kind == "buff_activate":
		event_type = "buff_activation_sent"
	_push_debug_event(event_type, _command_debug_payload(command, "accepted"))

func _next_client_command_id(kind: String, issued_tick: int) -> String:
	_client_command_counter += 1
	var session_token: String = _sanitize_log_token(_session_id)
	var uid_token: String = _sanitize_log_token(_local_uid)
	return "%s:%s:%s:%d:%d:%d" % [
		session_token,
		uid_token,
		str(kind).strip_edges().to_lower(),
		int(issued_tick),
		Time.get_ticks_msec(),
		_client_command_counter
	]

func _command_needs_local_pending_accept(command: Dictionary) -> bool:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	return kind == "lane_intent" or kind == "lane_retract" or kind == "barracks_route"

func _queue_local_pending_command_for_async_publish(command: Dictionary) -> void:
	var pending: Dictionary = _normalize_authoritative_command(command, -1)
	var client_command_id: String = _client_command_id(pending)
	if str(pending.get("command_id", "")).strip_edges().is_empty():
		pending["command_id"] = "%s:pending:%s" % [_sanitize_log_token(_session_id), client_command_id]
	if not pending.has("authority_action"):
		pending["authority_action"] = "local_pending"
	_queue_scheduled_command(pending)
	_record_local_command_accepted(pending)

func record_debug_input_rejected(src_hive_id: int, dst_hive_id: int, intent: String, reason: String, lane_id: int = -1) -> void:
	_push_debug_event("rejected_input", {
		"src": int(src_hive_id),
		"dst": int(dst_hive_id),
		"intent": str(intent).strip_edges().to_lower(),
		"reason": str(reason).strip_edges(),
		"lane_id": int(lane_id)
	})

func record_debug_intent_applied(src_hive_id: int, dst_hive_id: int, intent: String, lane_id: int = -1) -> void:
	var clean_intent: String = str(intent).strip_edges().to_lower()
	var event_type: String = "swarm_intent_applied_by_host" if clean_intent == "swarm" else "lane_intent_applied_by_host"
	_push_debug_event(event_type, {
		"src": int(src_hive_id),
		"dst": int(dst_hive_id),
		"intent": clean_intent,
		"lane_id": int(lane_id)
	})

func record_stale_ownership_reject(details: Dictionary) -> void:
	var payload: Dictionary = details.duplicate(true)
	payload["recovery_state"] = _recovery_state
	payload["last_mismatch_info"] = _hash_mismatch_last_details.duplicate(true)
	_push_debug_event("stale_ownership_reject", payload)
	_write_runtime_telemetry_event("stale_ownership_reject", payload)

func _record_input_blocked_runtime_state(command: Dictionary) -> void:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	var payload: Dictionary = command.duplicate(true)
	payload["active"] = is_active()
	payload["recovery_state"] = _recovery_state
	payload["sim_tick"] = int(st.tick) if st != null else -1
	payload["last_mismatch_info"] = _hash_mismatch_last_details.duplicate(true)
	payload["last_recovery_reason"] = _peer_desync_or_lagging_reason
	payload["last_publish_result"] = _last_publish_result.duplicate(true)
	_push_debug_event("input_blocked_runtime_state", payload)
	_write_runtime_telemetry_event("input_blocked_runtime_state", payload)

func _handle_remote_state_hash(command: Dictionary) -> void:
	var hash_tick: int = int(command.get("hash_tick", -1))
	var state_hash: String = str(command.get("state_hash", "")).strip_edges()
	if hash_tick < 0 or state_hash.is_empty():
		_contract_violation("bad_remote_state_hash", {"command": command.duplicate(true)})
		return
	var sender_uid: String = str(command.get("sender_uid", "")).strip_edges()
	if not sender_uid.is_empty():
		var peer_hashes: Dictionary = (_remote_hash_by_peer_tick.get(hash_tick, {}) as Dictionary).duplicate(true)
		peer_hashes[sender_uid] = state_hash
		_remote_hash_by_peer_tick[hash_tick] = peer_hashes
	_remote_hash_by_tick[hash_tick] = state_hash
	var state_debug_any: Variant = command.get("state_debug", {})
	if typeof(state_debug_any) == TYPE_DICTIONARY and not (state_debug_any as Dictionary).is_empty():
		_remote_hash_debug_by_tick[hash_tick] = (state_debug_any as Dictionary).duplicate(true)
	_prune_hash_windows(hash_tick)
	_compare_state_hash_if_ready(hash_tick)

func _record_hash_match(hash_tick: int) -> void:
	if _hash_mismatch_consecutive_count <= 0:
		return
	var now_ms: int = Time.get_ticks_msec()
	var payload: Dictionary = _hash_mismatch_last_details.duplicate(true)
	payload["healed_tick"] = int(hash_tick)
	payload["healed_ms"] = now_ms
	payload["duration_ticks"] = maxi(0, int(hash_tick) - _hash_mismatch_first_tick)
	payload["duration_ms"] = maxi(0, now_ms - _hash_mismatch_first_ms)
	payload["mismatched_samples"] = _hash_mismatch_consecutive_count
	_push_debug_event("hash_mismatch_self_healed", payload)
	_write_runtime_telemetry_event("hash_mismatch_self_healed", payload)
	_reset_hash_mismatch_tracking()

func _record_hash_mismatch(hash_tick: int, local_hash: String, remote_hash: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if _hash_mismatch_consecutive_count <= 0:
		_hash_mismatch_first_tick = int(hash_tick)
		_hash_mismatch_first_ms = now_ms
	_hash_mismatch_consecutive_count += 1
	_hash_mismatch_last_tick = int(hash_tick)
	_hash_mismatch_last_ms = now_ms
	_contract_state_hash_mismatches += 1
	var payload: Dictionary = _hash_mismatch_payload(hash_tick, local_hash, remote_hash)
	_hash_mismatch_last_details = payload.duplicate(true)
	var in_startup_grace: bool = int(hash_tick) <= HASH_STARTUP_GRACE_TICKS
	if in_startup_grace:
		_push_debug_event("startup_hash_mismatch_grace", payload)
		_write_runtime_telemetry_event("startup_hash_mismatch_grace", payload)
		return
	if _hash_mismatch_consecutive_count < HASH_MISMATCH_RECOVERY_THRESHOLD:
		var event_type: String = "hash_mismatch_warning" if _hash_mismatch_consecutive_count >= 2 else "hash_mismatch_diagnostic"
		_push_debug_event(event_type, payload)
		_write_runtime_telemetry_event(event_type, payload)
		return
	_defer_first_mismatch_authority_snapshot(hash_tick)
	if not _hash_recovery_pause_enabled():
		payload["recovery_suppressed"] = true
		_push_debug_event("state_hash_mismatch_recovery_suppressed", payload)
		_write_runtime_telemetry_event("state_hash_mismatch_recovery_suppressed", payload)
		_contract_violation("state_hash_mismatch", payload)
		return
	_mark_peer_desync_or_lagging("state_hash_mismatch", payload)
	_contract_violation("state_hash_mismatch", payload)

func _defer_first_mismatch_authority_snapshot(hash_tick: int) -> void:
	if _first_mismatch_snapshot_queued or not _runtime_telemetry_file_enabled():
		return
	var snapshot_any: Variant = _authority_snapshots_by_tick.get(int(hash_tick), {})
	if typeof(snapshot_any) != TYPE_DICTIONARY or (snapshot_any as Dictionary).is_empty():
		return
	_first_mismatch_snapshot_queued = true
	var evidence: Dictionary = {
		"hash_tick": int(hash_tick),
		"authority_snapshot": (snapshot_any as Dictionary).duplicate(true)
	}
	# Full recovery snapshots are diagnostic evidence, not gameplay work. Keep
	# serialization and file I/O outside the authoritative simulation tick.
	call_deferred(
		"_write_runtime_telemetry_event",
		"first_hash_mismatch_authority_snapshot",
		evidence,
		false
	)

func _reset_hash_mismatch_tracking() -> void:
	_hash_mismatch_consecutive_count = 0
	_hash_mismatch_first_tick = -1
	_hash_mismatch_last_tick = -1
	_hash_mismatch_first_ms = 0
	_hash_mismatch_last_ms = 0
	_hash_mismatch_last_details = {}

func _hash_mismatch_payload(hash_tick: int, local_hash: String, remote_hash: String) -> Dictionary:
	var payload: Dictionary = {
		"tick": int(hash_tick),
		"local_hash": local_hash,
		"remote_hash": remote_hash,
		"peer_uid": _remote_uid,
		"peer_seat": _remote_seat,
		"recovery_state": _recovery_state,
		"consecutive_count": _hash_mismatch_consecutive_count,
		"threshold": HASH_MISMATCH_RECOVERY_THRESHOLD,
		"startup_grace_ticks": HASH_STARTUP_GRACE_TICKS,
		"in_startup_grace": int(hash_tick) <= HASH_STARTUP_GRACE_TICKS,
		"first_mismatch_tick": _hash_mismatch_first_tick,
		"last_mismatch_tick": _hash_mismatch_last_tick,
		"duration_ticks": maxi(0, int(hash_tick) - _hash_mismatch_first_tick),
		"duration_ms": maxi(0, Time.get_ticks_msec() - _hash_mismatch_first_ms),
		"command_log": _command_log_edge_snapshot(),
		"late_command_diagnostics": {
			"missed": _contract_missed_scheduled_commands,
			"late": _contract_late_scheduled_commands,
			"buffered": _contract_buffered_lagging_commands,
			"current_lead_ticks": _contract_current_command_lead_ticks,
			"min_lead_ticks": -1 if _contract_min_command_lead_ticks == 2147483647 else _contract_min_command_lead_ticks
		},
		"last_event": _last_debug_event.duplicate(true)
	}
	var local_debug_any: Variant = _local_hash_debug_by_tick.get(hash_tick, {})
	if typeof(local_debug_any) == TYPE_DICTIONARY and not (local_debug_any as Dictionary).is_empty():
		payload["local_state_debug"] = (local_debug_any as Dictionary).duplicate(true)
	var remote_debug_any: Variant = _remote_hash_debug_by_tick.get(hash_tick, {})
	if typeof(remote_debug_any) == TYPE_DICTIONARY and not (remote_debug_any as Dictionary).is_empty():
		payload["remote_state_debug"] = (remote_debug_any as Dictionary).duplicate(true)
	return payload

func _command_log_edge_snapshot() -> Dictionary:
	var size: int = _accepted_command_log.size()
	var head: Array = []
	var tail: Array = []
	var head_count: int = mini(3, size)
	for i in range(head_count):
		head.append(_command_log_summary(_accepted_command_log[i] as Dictionary))
	var tail_start: int = maxi(head_count, size - 3)
	for i in range(tail_start, size):
		tail.append(_command_log_summary(_accepted_command_log[i] as Dictionary))
	return {
		"size": size,
		"head": head,
		"tail": tail
	}

func _command_log_summary(command: Dictionary) -> Dictionary:
	return {
		"command_id": str(command.get("command_id", "")),
		"command_seq": int(command.get("command_seq", -1)),
		"kind": str(command.get("kind", "")),
		"issued_tick": int(command.get("issued_tick", -1)),
		"execute_tick": int(command.get("execute_tick", -1)),
		"sender_seat": int(command.get("sender_seat", 0)),
		"src": int(command.get("src", command.get("from_id", command.get("barracks_id", -1)))),
		"dst": int(command.get("dst", command.get("to_id", -1))),
		"intent": str(command.get("intent", "")),
		"activation_id": str(command.get("activation_id", "")),
		"buff_id": str(command.get("buff_id", "")),
		"target_type": str(command.get("target_type", "")),
		"target_id": command.get("target_id", null)
	}

func _compare_state_hash_if_ready(hash_tick: int) -> void:
	if not _local_hash_by_tick.has(hash_tick) or not _remote_hash_by_tick.has(hash_tick):
		return
	var local_hash: String = str(_local_hash_by_tick.get(hash_tick, ""))
	var remote_hash: String = str(_remote_hash_by_tick.get(hash_tick, ""))
	var all_remote_hashes_match: bool = local_hash == remote_hash
	var peer_hashes_any: Variant = _remote_hash_by_peer_tick.get(hash_tick, {})
	if typeof(peer_hashes_any) == TYPE_DICTIONARY and not (peer_hashes_any as Dictionary).is_empty():
		all_remote_hashes_match = true
		for peer_hash_any in (peer_hashes_any as Dictionary).values():
			var peer_hash: String = str(peer_hash_any)
			if peer_hash == local_hash:
				continue
			all_remote_hashes_match = false
			remote_hash = peer_hash
			break
	if all_remote_hashes_match:
		_record_hash_match(hash_tick)
		_last_matching_checkpoint_tick = maxi(_last_matching_checkpoint_tick, int(hash_tick))
		if _recovery_state == RECOVERY_STATE_WAITING_FOR_PEER:
			_set_recovery_state(RECOVERY_STATE_RUNNING, "hashes_matched")
			_peer_desync_or_lagging = false
			_peer_desync_or_lagging_reason = ""
			_peer_desync_or_lagging_details = {}
		_prune_accepted_command_log()
		return
	_record_hash_mismatch(hash_tick, local_hash, remote_hash)

func build_desync_recovery_plan() -> Dictionary:
	if _recovery_state != RECOVERY_STATE_DESYNC_RECOVERY:
		return {"ok": false, "reason": "not_in_desync_recovery", "state": _recovery_state}
	if _recovery_desync_tick < 0:
		return {"ok": false, "reason": "desync_tick_missing"}
	var rollback_tick: int = _find_latest_matching_snapshot_tick(_recovery_desync_tick)
	if rollback_tick < 0:
		return {
			"ok": false,
			"reason": "matching_checkpoint_missing",
			"desync_tick": _recovery_desync_tick
		}
	var snapshot_any: Variant = _authority_snapshots_by_tick.get(rollback_tick, {})
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"reason": "snapshot_missing",
			"rollback_tick": rollback_tick,
			"desync_tick": _recovery_desync_tick
		}
	var commands: Array = []
	for command_any in _accepted_command_log:
		var command: Dictionary = command_any as Dictionary
		var execute_tick: int = int(command.get("execute_tick", -1))
		if execute_tick > rollback_tick and execute_tick <= _recovery_desync_tick:
			commands.append(command.duplicate(true))
	commands.sort_custom(Callable(self, "_sort_commands_by_contract_order"))
	return {
		"ok": true,
		"match_id": _session_id,
		"rollback_tick": rollback_tick,
		"desync_tick": _recovery_desync_tick,
		"target_hash": _recovery_remote_hash,
		"local_hash": _recovery_local_hash,
		"snapshot": (snapshot_any as Dictionary).duplicate(true),
		"commands": commands,
		"attempt": _recovery_attempts + 1
	}

func complete_desync_recovery(recovered_tick: int, recovered_hash: String, replayed_count: int) -> Dictionary:
	var clean_hash: String = str(recovered_hash).strip_edges()
	var success: bool = clean_hash != "" and clean_hash == _recovery_remote_hash
	_recovery_attempts += 1
	var payload: Dictionary = {
		"match_id": _session_id,
		"checkpoint_tick": _last_matching_checkpoint_tick,
		"desync_tick": _recovery_desync_tick,
		"recovered_tick": int(recovered_tick),
		"local_hash": clean_hash,
		"remote_hash": _recovery_remote_hash,
		"replayed_count": int(replayed_count),
		"recovery_attempts": _recovery_attempts,
		"success": success
	}
	if success:
		_recovery_last_outcome = "recovered"
		_set_recovery_state(RECOVERY_STATE_RUNNING, "recovery_success")
		_peer_desync_or_lagging = false
		_peer_desync_or_lagging_reason = ""
		_peer_desync_or_lagging_details = {}
		_local_hash_by_tick[_recovery_desync_tick] = clean_hash
		_last_matching_checkpoint_tick = maxi(_last_matching_checkpoint_tick, _recovery_desync_tick)
		_push_debug_event("desync_recovery_success", payload)
		_write_contract_violation_report({"reason": "desync_recovery_success", "payload": payload, "session_id": _session_id, "report_path": _contract_diagnostic_log_path()})
		_update_runtime_telemetry()
		return {"ok": true, "recovered": true, "payload": payload}
	_recovery_last_outcome = "failed"
	_push_debug_event("desync_recovery_failed", payload)
	_write_contract_violation_report({"reason": "desync_recovery_failed", "payload": payload, "session_id": _session_id, "report_path": _contract_diagnostic_log_path()})
	if _recovery_attempts >= RECOVERY_MAX_ATTEMPTS:
		_set_recovery_state(RECOVERY_STATE_DESYNC_ENDED, "recovery_failed")
		_mark_peer_desync_or_lagging("desync_recovery_failed", payload)
	_update_runtime_telemetry()
	return {"ok": false, "recovered": false, "payload": payload, "ended": _recovery_state == RECOVERY_STATE_DESYNC_ENDED}

func mark_desync_unrecoverable(reason: String, details: Dictionary) -> void:
	var payload: Dictionary = details.duplicate(true)
	payload["reason"] = reason
	payload["match_id"] = _session_id
	payload["desync_tick"] = _recovery_desync_tick
	payload["checkpoint_tick"] = _last_matching_checkpoint_tick
	_recovery_last_outcome = "unrecoverable"
	_set_recovery_state(RECOVERY_STATE_DESYNC_ENDED, reason)
	_mark_peer_desync_or_lagging(reason, payload)
	_push_debug_event("desync_recovery_unrecoverable", payload)
	_write_contract_violation_report({"reason": "desync_recovery_unrecoverable", "payload": payload, "session_id": _session_id, "report_path": _contract_diagnostic_log_path()})

func _find_latest_matching_snapshot_tick(max_tick: int) -> int:
	var best_tick: int = -1
	for tick_any in _authority_snapshots_by_tick.keys():
		var tick_value: int = int(tick_any)
		if tick_value > int(max_tick):
			continue
		if tick_value > _last_matching_checkpoint_tick:
			continue
		if not _local_hash_by_tick.has(tick_value) or not _remote_hash_by_tick.has(tick_value):
			continue
		if str(_local_hash_by_tick.get(tick_value, "")) != str(_remote_hash_by_tick.get(tick_value, "")):
			continue
		if tick_value > best_tick:
			best_tick = tick_value
	return best_tick

func _prune_hash_windows(latest_tick: int) -> void:
	var min_tick: int = maxi(0, latest_tick - HASH_RETENTION_TICKS)
	for tick_any in _local_hash_by_tick.keys():
		if int(tick_any) < min_tick:
			_local_hash_by_tick.erase(tick_any)
	for tick_any in _remote_hash_by_tick.keys():
		if int(tick_any) < min_tick:
			_remote_hash_by_tick.erase(tick_any)
	for tick_any in _remote_hash_by_peer_tick.keys():
		if int(tick_any) < min_tick:
			_remote_hash_by_peer_tick.erase(tick_any)
	for tick_any in _local_hash_debug_by_tick.keys():
		if int(tick_any) < min_tick:
			_local_hash_debug_by_tick.erase(tick_any)
	for tick_any in _remote_hash_debug_by_tick.keys():
		if int(tick_any) < min_tick:
			_remote_hash_debug_by_tick.erase(tick_any)

func _certification_hash_debug_snapshot() -> Dictionary:
	if not OS.has_feature("private_pvp_certification"):
		return {}
	if OpsState == null or not OpsState.has_method("get_pvp_debug_state_snapshot"):
		return {}
	var snapshot_any: Variant = OpsState.call("get_pvp_debug_state_snapshot")
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		return {}
	return (snapshot_any as Dictionary).duplicate(true)

func get_last_contract_violation() -> Dictionary:
	return _last_contract_violation.duplicate(true)

func get_contract_violation_count() -> int:
	return _contract_violation_count

func get_contract_diagnostics_snapshot() -> Dictionary:
	return _contract_diagnostics_snapshot()

func record_local_lane_intent(src_hive_id: int, dst_hive_id: int, intent: String, src_owner_id: int, dst_owner_id: int) -> bool:
	if not is_active():
		return true
	if not can_accept_gameplay_intents():
		_record_input_blocked_runtime_state({
			"kind": "lane_intent",
			"src": int(src_hive_id),
			"dst": int(dst_hive_id),
			"intent": str(intent)
		})
		return false
	if src_owner_id != _local_seat:
		return true
	var clean_intent: String = str(intent).strip_edges().to_lower()
	var command: Dictionary = _contract_command_base("lane_intent")
	command.merge({
		"src": int(src_hive_id),
		"dst": int(dst_hive_id),
		"intent": clean_intent,
		"src_owner": int(src_owner_id),
		"dst_owner": int(dst_owner_id)
	})
	if not _validate_contract_command(command, "outgoing"):
		return false
	return _publish_command(command)

func record_local_lane_retract(from_id: int, to_id: int, owner_id: int) -> bool:
	if not is_active():
		return true
	if not can_accept_gameplay_intents():
		_record_input_blocked_runtime_state({
			"kind": "lane_retract",
			"from_id": int(from_id),
			"to_id": int(to_id)
		})
		return false
	if owner_id != _local_seat:
		return true
	var command: Dictionary = _contract_command_base("lane_retract")
	command.merge({
		"from_id": int(from_id),
		"to_id": int(to_id),
		"owner_id": int(owner_id)
	})
	if not _validate_contract_command(command, "outgoing"):
		return false
	return _publish_command(command)

func record_local_barracks_route(barracks_id: int, route_hive_ids: Array, owner_id: int) -> bool:
	if not is_active():
		return true
	if not can_accept_gameplay_intents():
		_record_input_blocked_runtime_state({
			"kind": "barracks_route",
			"barracks_id": int(barracks_id)
		})
		return false
	if owner_id != _local_seat:
		return true
	var command: Dictionary = _contract_command_base("barracks_route")
	command.merge({
		"barracks_id": int(barracks_id),
		"route_hive_ids": route_hive_ids.duplicate(),
		"owner_id": int(owner_id)
	})
	if not _validate_contract_command(command, "outgoing"):
		return false
	return _publish_command(command)

func record_local_buff_activation(reservation: Dictionary) -> bool:
	if not is_active():
		return true
	if not can_accept_gameplay_intents():
		_record_input_blocked_runtime_state({
			"kind": "buff_activate",
			"activation_id": str(reservation.get("activation_id", ""))
		})
		return false
	var owner_id: int = int(reservation.get("owner_id", 0))
	if owner_id != _local_seat:
		return false
	var command: Dictionary = _contract_command_base("buff_activate")
	command.merge({
		"match_id": str(reservation.get("match_id", _session_id)),
		"activation_id": str(reservation.get("activation_id", "")).strip_edges(),
		"owner_id": owner_id,
		"buff_id": str(reservation.get("buff_id", "")).strip_edges(),
		"tier": str(reservation.get("tier", "")).strip_edges().to_lower(),
		"target_type": str(reservation.get("target_type", "")).strip_edges().to_lower(),
		"target_id": reservation.get("target_id", "global"),
		"source_kind": str(reservation.get("source_kind", "")).strip_edges().to_lower(),
		"source_use_ordinal": int(reservation.get("source_use_ordinal", 1)),
		"source_slot_index": int(reservation.get("slot_index", -1))
	})
	if not _validate_contract_command(command, "outgoing"):
		return false
	return _publish_command(command)

func _publish_command(command: Dictionary) -> bool:
	if not _validate_contract_command(command, "publish"):
		return false
	if _should_publish_on_worker_thread(command):
		if _command_needs_local_pending_accept(command):
			_queue_local_pending_command_for_async_publish(command)
		_enqueue_async_publish_command(command)
		return _start_async_publish_commands()
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("publish_intent"):
		_contract_violation("publish_transport_missing", {"command": command.duplicate(true)})
		return false
	var t0_us: int = Time.get_ticks_usec()
	var result: Dictionary = handshake.call("publish_intent", _session_id, _local_uid, command) as Dictionary
	_handle_publish_result(command, result, t0_us)
	return bool(result.get("ok", false))

func _handle_publish_result(command: Dictionary, result: Dictionary, t0_us: int) -> void:
	_record_transport_result("publish", result, t0_us)
	_last_publish_result = {
		"ok": bool(result.get("ok", false)),
		"err": str(result.get("err", "")),
		"seq": int(result.get("seq", result.get("command_seq", -1))),
		"kind": str(command.get("kind", "")),
		"command_id": str(command.get("command_id", "")),
		"tick_ms": Time.get_ticks_msec()
	}
	if not bool(result.get("ok", false)):
		_write_runtime_telemetry_event("publish_failed", {
			"command": _command_debug_payload(command, "publish_failed"),
			"result": result.duplicate(true)
		})
		SFLog.allow_tag("VS_PVP_PUBLISH_FAIL")
		SFLog.warn("VS_PVP_PUBLISH_FAIL", {
			"session_id": _session_id,
			"kind": str(command.get("kind", "")),
			"err": str(result.get("err", "unknown"))
		}, "", 500)
		if str(command.get("kind", "")).strip_edges().to_lower() != "buff_activate":
			_contract_violation("publish_failed_after_local_mutation", {
				"command": command.duplicate(true),
				"result": result.duplicate(true)
			})
		command_publish_result.emit({
			"ok": false,
			"kind": str(command.get("kind", "")),
			"activation_id": str(command.get("activation_id", "")),
			"owner_id": int(command.get("owner_id", 0)),
			"reason": str(result.get("err", "publish_rejected")),
			"request_command": command.duplicate(true),
			"transport_result": result.duplicate(true)
		})
		return
	_intent_events_tx += 1
	var canonical_command: Dictionary = _canonical_command_from_publish_result(command, result)
	_queue_scheduled_command(canonical_command)
	if not (_should_publish_on_worker_thread(command) and _command_needs_local_pending_accept(command)):
		_record_local_command_accepted(canonical_command)
	command_publish_result.emit({
		"ok": true,
		"kind": str(command.get("kind", "")),
		"activation_id": str(command.get("activation_id", "")),
		"owner_id": int(command.get("owner_id", 0)),
		"canonical_command": canonical_command.duplicate(true),
		"transport_result": result.duplicate(true)
	})
	_update_runtime_telemetry()

func _poll_remote_intents() -> void:
	if _should_poll_on_worker_thread():
		_start_async_remote_intent_poll()
		return
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("poll_intents"):
		return
	var after_seq: int = _last_seq
	var t0_us: int = Time.get_ticks_usec()
	var result: Dictionary = handshake.call("poll_intents", _session_id, _local_uid, after_seq, _current_sim_tick()) as Dictionary
	_handle_remote_intent_poll_result(result, t0_us, after_seq)

func _handle_remote_intent_poll_result(result: Dictionary, t0_us: int, after_seq: int) -> void:
	var connectivity_current: bool = _record_transport_result("poll", result, t0_us)
	if not connectivity_current:
		return
	if not bool(result.get("ok", false)):
		_write_runtime_telemetry_event("poll_failed", {
			"after_seq": int(after_seq),
			"result": result.duplicate(true)
		}, false)
		_update_runtime_telemetry()
		return
	var latest_seq: int = int(result.get("latest_seq", _last_seq))
	var events_any: Variant = result.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		if latest_seq > _last_seq:
			_last_seq = latest_seq
		_update_match_lifecycle(result.get("match_lifecycle", {}))
		_update_runtime_telemetry()
		return
	var events: Array = events_any as Array
	_record_received_events(events.size())
	var missing_seq_count: int = maxi(0, (latest_seq - after_seq) - events.size())
	if missing_seq_count > 0:
		_packet_dropped += missing_seq_count
		_write_runtime_telemetry_event("poll_sequence_gap", {
			"after_seq": int(after_seq),
			"latest_seq": int(latest_seq),
			"events_received": events.size(),
			"missing_seq_count": missing_seq_count
		})
	if events.size() > 0:
		_write_runtime_telemetry_event("poll_events_received", {
			"after_seq": int(after_seq),
			"latest_seq": int(latest_seq),
			"events_received": events.size()
		}, false)
	if latest_seq > _last_seq:
		_last_seq = latest_seq
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		var seq: int = int(event.get("seq", 0))
		if seq > _last_seq:
			_last_seq = seq
		var sender_uid: String = str(event.get("uid", "")).strip_edges()
		if sender_uid.is_empty() or sender_uid == _local_uid:
			continue
		if _remote_uids.is_empty() and _remote_uid.is_empty():
			_remote_uid = sender_uid
			_remote_uids.append(sender_uid)
		elif not _remote_uids.has(sender_uid) and sender_uid != _remote_uid:
			continue
		var command_any: Variant = event.get("command", {})
		if typeof(command_any) != TYPE_DICTIONARY:
			_contract_violation("remote_command_not_dictionary", {"event": event.duplicate(true)})
			continue
		var command: Dictionary = _normalize_authoritative_command(command_any as Dictionary, seq)
		command["sender_uid"] = sender_uid
		if not _validate_contract_command(command, "remote"):
			continue
		var expected_sender_seat: int = int(_remote_seat_by_uid.get(sender_uid, 0))
		if expected_sender_seat > 0 and int(command.get("sender_seat", 0)) != expected_sender_seat:
			_contract_violation("remote_sender_seat_mismatch", {
				"sender_uid": sender_uid,
				"expected_seat": expected_sender_seat,
				"command_seat": int(command.get("sender_seat", 0))
			})
			continue
		if str(command.get("kind", "")).strip_edges().to_lower() == "state_hash":
			_handle_remote_state_hash(command)
			continue
		_append_accepted_command_log(command)
		_pending_remote_commands.append(command)
		_remote_commands_rx += 1
		_record_remote_command_received(command)
	_update_match_lifecycle(result.get("match_lifecycle", {}))
	_update_runtime_telemetry()

func _record_remote_command_received(command: Dictionary) -> void:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	match kind:
		"lane_intent":
			var intent: String = str(command.get("intent", "")).strip_edges().to_lower()
			var event_type: String = "swarm_update_received" if intent == "swarm" else "lane_update_received"
			_push_debug_event(event_type, command)
		"lane_retract":
			_push_debug_event("lane_update_received", command)
		"buff_activate":
			_push_debug_event("buff_activation_received", command)
		_:
			return

func _contract_command_base(kind: String) -> Dictionary:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	var issued_tick: int = int(st.tick) if st != null else -1
	var requested_execute_tick: int = (issued_tick + COMMAND_LEAD_TICKS) if issued_tick >= 0 else -1
	var clean_kind: String = str(kind).strip_edges().to_lower()
	var client_command_id: String = _next_client_command_id(clean_kind, issued_tick)
	return {
		"kind": clean_kind,
		"contract_version": CONTRACT_VERSION,
		"client_command_id": client_command_id,
		"issued_ms": Time.get_ticks_msec(),
		"issued_tick": issued_tick,
		"local_issued_tick": issued_tick,
		"requested_execute_tick": requested_execute_tick,
		"execute_tick": requested_execute_tick,
		"issued_sim_us": int(st.get("_sim_time_us")) if st != null else -1,
		"sender_seat": int(_local_seat),
		"sender_uid": _local_uid
	}

func _validate_contract_command(command: Dictionary, direction: String) -> bool:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	if int(command.get("contract_version", 0)) != CONTRACT_VERSION:
		return _contract_violation("bad_contract_version", {
			"direction": direction,
			"expected": CONTRACT_VERSION,
			"command": command.duplicate(true)
		})
	if int(command.get("issued_ms", 0)) <= 0:
		return _contract_violation("missing_issued_ms", {"direction": direction, "command": command.duplicate(true)})
	if int(command.get("issued_tick", -1)) < 0:
		return _contract_violation("missing_issued_tick", {"direction": direction, "command": command.duplicate(true)})
	if int(command.get("issued_sim_us", -1)) < 0:
		return _contract_violation("missing_issued_sim_us", {"direction": direction, "command": command.duplicate(true)})
	match kind:
		"state_hash":
			if int(command.get("hash_tick", -1)) < 0:
				return _contract_violation("bad_state_hash_tick", {"direction": direction, "command": command.duplicate(true)})
			if str(command.get("state_hash", "")).strip_edges().is_empty():
				return _contract_violation("bad_state_hash_value", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("sender_seat", 0)) <= 0:
				return _contract_violation("bad_state_hash_sender", {"direction": direction, "command": command.duplicate(true)})
		"lane_intent":
			if int(command.get("execute_tick", -1)) < 0:
				return _contract_violation("missing_execute_tick", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("src", -1)) <= 0 or int(command.get("dst", -1)) <= 0:
				return _contract_violation("bad_lane_intent_hives", {"direction": direction, "command": command.duplicate(true)})
			var intent: String = str(command.get("intent", "")).strip_edges().to_lower()
			if not bool(ALLOWED_LANE_INTENTS.get(intent, false)):
				return _contract_violation("bad_lane_intent_kind", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("src_owner", 0)) <= 0:
				return _contract_violation("bad_lane_intent_owner", {"direction": direction, "command": command.duplicate(true)})
		"lane_retract":
			if int(command.get("execute_tick", -1)) < 0:
				return _contract_violation("missing_execute_tick", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("from_id", -1)) <= 0 or int(command.get("to_id", -1)) <= 0:
				return _contract_violation("bad_lane_retract_hives", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("owner_id", 0)) <= 0:
				return _contract_violation("bad_lane_retract_owner", {"direction": direction, "command": command.duplicate(true)})
		"barracks_route":
			if int(command.get("execute_tick", -1)) < 0:
				return _contract_violation("missing_execute_tick", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("barracks_id", -1)) <= 0:
				return _contract_violation("bad_barracks_id", {"direction": direction, "command": command.duplicate(true)})
			if int(command.get("owner_id", 0)) <= 0:
				return _contract_violation("bad_barracks_owner", {"direction": direction, "command": command.duplicate(true)})
			var route_any: Variant = command.get("route_hive_ids", [])
			if typeof(route_any) != TYPE_ARRAY:
				return _contract_violation("bad_barracks_route_type", {"direction": direction, "command": command.duplicate(true)})
		"buff_activate":
			if int(command.get("execute_tick", -1)) < 0:
				return _contract_violation("missing_execute_tick", {"direction": direction, "command": command.duplicate(true)})
			if str(command.get("activation_id", "")).strip_edges().is_empty():
				return _contract_violation("bad_buff_activation_id", {"direction": direction, "command": command.duplicate(true)})
			var owner_id: int = int(command.get("owner_id", 0))
			if owner_id <= 0 or owner_id != int(command.get("sender_seat", 0)):
				return _contract_violation("bad_buff_owner", {"direction": direction, "command": command.duplicate(true)})
			if str(command.get("buff_id", "")).strip_edges().is_empty() or str(command.get("tier", "")).strip_edges().is_empty():
				return _contract_violation("bad_buff_identity", {"direction": direction, "command": command.duplicate(true)})
			var target_type: String = str(command.get("target_type", "")).strip_edges().to_lower()
			if target_type != "hive" and target_type != "lane" and target_type != "global":
				return _contract_violation("bad_buff_target_type", {"direction": direction, "command": command.duplicate(true)})
			if target_type == "global":
				if str(command.get("target_id", "")).strip_edges().to_lower() != "global":
					return _contract_violation("bad_global_buff_target", {"direction": direction, "command": command.duplicate(true)})
			elif int(command.get("target_id", -1)) <= 0:
				return _contract_violation("bad_buff_target_id", {"direction": direction, "command": command.duplicate(true)})
			for forbidden_key in ["world_pos", "local_pos", "grid_pos", "touch_id", "screen_pos"]:
				if command.has(forbidden_key):
					return _contract_violation("buff_command_contains_transient_target", {"direction": direction, "key": forbidden_key, "command": command.duplicate(true)})
			var source_kind: String = str(command.get("source_kind", "")).strip_edges().to_lower()
			var ordinal: int = int(command.get("source_use_ordinal", 0))
			if source_kind != "inventory" and source_kind != "vs" and source_kind != "async":
				return _contract_violation("bad_buff_source_kind", {"direction": direction, "command": command.duplicate(true)})
			if ((source_kind == "inventory" or source_kind == "vs") and ordinal != 1) or (source_kind == "async" and (ordinal < 1 or ordinal > 2)):
				return _contract_violation("bad_buff_source_ordinal", {"direction": direction, "command": command.duplicate(true)})
		_:
			return _contract_violation("unknown_command_kind", {"direction": direction, "command": command.duplicate(true)})
	return true

func _contract_violation(reason: String, payload: Dictionary) -> bool:
	_contract_violation_count += 1
	_contract_last_violation_reason = reason
	if reason == "command_missed_execute_tick":
		_contract_missed_scheduled_commands += 1
	elif reason == "state_hash_mismatch":
		if _desync_event_before_divergence.is_empty():
			_desync_event_before_divergence = _last_debug_event.duplicate(true)
	var report: Dictionary = {
		"reason": reason,
		"payload": payload.duplicate(true),
		"session_id": _session_id,
		"local_uid": _local_uid,
		"local_seat": _local_seat,
		"remote_uid": _remote_uid,
		"remote_seat": _remote_seat,
		"unix_ms": int(round(Time.get_unix_time_from_system() * 1000.0)),
		"report_path": _contract_diagnostic_log_path()
	}
	_last_contract_violation = report.duplicate(true)
	_write_contract_violation_report(report)
	_update_runtime_telemetry()
	_push_debug_event("contract_violation", {
		"reason": reason,
		"payload": payload.duplicate(true)
	})
	push_error("VS_CONTRACT_VIOLATION: %s %s" % [reason, str(payload)])
	if _crash_on_contract_violation():
		OS.crash("VS_CONTRACT_VIOLATION: " + reason)
	return false

func _write_contract_violation_report(report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(CONTRACT_DIAGNOSTIC_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(CONTRACT_DIAGNOSTIC_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(report))
	file.close()

func _crash_on_contract_violation() -> bool:
	if ProjectSettings.has_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION):
		return bool(ProjectSettings.get_setting(SETTINGS_CRASH_ON_CONTRACT_VIOLATION, CRASH_ON_CONTRACT_VIOLATION_DEFAULT))
	return CRASH_ON_CONTRACT_VIOLATION_DEFAULT

func _hash_recovery_pause_enabled() -> bool:
	if ProjectSettings.has_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED):
		return bool(ProjectSettings.get_setting(SETTINGS_HASH_RECOVERY_PAUSE_ENABLED, HASH_RECOVERY_PAUSE_ENABLED_DEFAULT))
	return HASH_RECOVERY_PAUSE_ENABLED_DEFAULT

func _runtime_telemetry_file_enabled() -> bool:
	if OS.has_feature(FEATURE_PRIVATE_PVP_DIAGNOSTICS):
		return true
	var env_value: String = OS.get_environment(ENV_RUNTIME_TELEMETRY_FILE_ENABLED).strip_edges().to_lower()
	if env_value == "1" or env_value == "true" or env_value == "yes" or env_value == "on":
		return true
	if ProjectSettings.has_setting(SETTINGS_RUNTIME_TELEMETRY_FILE_ENABLED):
		return bool(ProjectSettings.get_setting(SETTINGS_RUNTIME_TELEMETRY_FILE_ENABLED, false))
	return false

func _reset_contract_diagnostics() -> void:
	_contract_violation_count = 0
	_last_contract_violation = {}
	_contract_current_command_lead_ticks = -1
	_contract_min_command_lead_ticks = 2147483647
	_contract_missed_scheduled_commands = 0
	_contract_late_scheduled_commands = 0
	_contract_buffered_lagging_commands = 0
	_contract_state_hash_mismatches = 0
	_contract_last_violation_reason = ""
	_desync_event_before_divergence = {}
	_hash_mismatch_consecutive_count = 0
	_hash_mismatch_first_tick = -1
	_hash_mismatch_last_tick = -1
	_hash_mismatch_first_ms = 0
	_hash_mismatch_last_ms = 0
	_hash_mismatch_last_details = {}
	_peer_desync_or_lagging = false
	_peer_desync_or_lagging_reason = ""
	_peer_desync_or_lagging_details = {}

func _push_debug_event(event_type: String, payload: Dictionary) -> void:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	var event: Dictionary = {
		"type": event_type,
		"ms": Time.get_ticks_msec(),
		"unix_ms": int(round(Time.get_unix_time_from_system() * 1000.0)),
		"tick": int(st.tick) if st != null else -1,
		"role": _role,
		"local_seat": int(_local_seat),
		"payload": payload.duplicate(true)
	}
	_last_debug_event = event.duplicate(true)
	_debug_event_log.append(event)
	while _debug_event_log.size() > DEBUG_EVENT_LIMIT:
		_debug_event_log.pop_front()
	_write_runtime_telemetry_event(event_type, event)

func _observe_command_lead(execute_tick: int, target_tick: int) -> void:
	if target_tick < 0 or execute_tick < 0:
		return
	var lead_ticks: int = execute_tick - target_tick
	_contract_current_command_lead_ticks = lead_ticks
	if _contract_min_command_lead_ticks == 2147483647 or lead_ticks < _contract_min_command_lead_ticks:
		_contract_min_command_lead_ticks = lead_ticks

func _record_late_scheduled_command(command: Dictionary, target_tick: int, late_delta: int, outside_tolerance: bool = false) -> void:
	_contract_missed_scheduled_commands += 1
	_contract_late_scheduled_commands += 1
	SFLog.allow_tag("VS_COMMAND_LATE_EXECUTE")
	var payload: Dictionary = _command_debug_payload(command, "rebased")
	payload["received_tick"] = int(target_tick)
	payload["applied_tick"] = int(target_tick)
	payload["late_delta"] = int(late_delta)
	payload["late_tolerance"] = COMMAND_LATE_TOLERANCE_TICKS
	payload["outside_tolerance"] = bool(outside_tolerance)
	SFLog.warn("VS_COMMAND_LATE_EXECUTE", payload)
	_push_debug_event("late_scheduled_command", payload)
	_update_runtime_telemetry()

func _buffer_lagging_command(command: Dictionary, target_tick: int, late_delta: int) -> void:
	_contract_missed_scheduled_commands += 1
	_contract_buffered_lagging_commands += 1
	var payload: Dictionary = _command_debug_payload(command, "paused")
	payload["received_tick"] = int(target_tick)
	payload["applied_tick"] = -1
	payload["late_delta"] = int(late_delta)
	payload["late_tolerance"] = COMMAND_LATE_TOLERANCE_TICKS
	_mark_peer_desync_or_lagging("command_outside_late_tolerance", payload)
	SFLog.allow_tag("VS_COMMAND_BUFFERED_LAGGING")
	SFLog.warn("VS_COMMAND_BUFFERED_LAGGING", payload)
	_push_debug_event("buffered_lagging_command", payload)
	_update_runtime_telemetry()

func _set_recovery_state(next_state: String, reason: String) -> void:
	if _recovery_state == next_state:
		return
	var previous_state: String = _recovery_state
	_recovery_state = next_state
	_push_debug_event("recovery_state_changed", {
		"from": previous_state,
		"to": next_state,
		"reason": reason,
		"desync_tick": _recovery_desync_tick,
		"checkpoint_tick": _last_matching_checkpoint_tick
	})

func _mark_peer_desync_or_lagging(reason: String, details: Dictionary) -> void:
	_peer_desync_or_lagging = true
	_peer_desync_or_lagging_reason = reason
	_peer_desync_or_lagging_details = details.duplicate(true)
	if reason == "state_hash_mismatch":
		_recovery_desync_tick = int(details.get("tick", -1))
		_recovery_local_hash = str(details.get("local_hash", ""))
		_recovery_remote_hash = str(details.get("remote_hash", ""))
		_set_recovery_state(RECOVERY_STATE_DESYNC_RECOVERY, reason)
	elif _recovery_state == RECOVERY_STATE_RUNNING:
		_set_recovery_state(RECOVERY_STATE_WAITING_FOR_PEER, reason)

func _command_debug_payload(command: Dictionary, action_taken: String) -> Dictionary:
	var st: GameState = OpsState.get_state() if OpsState != null and OpsState.has_method("get_state") else null
	var state_hash: String = ""
	if OpsState != null and OpsState.has_method("get_contract_state_hash"):
		state_hash = str(OpsState.call("get_contract_state_hash"))
	return {
		"match_id": _session_id,
		"command_id": str(command.get("command_id", "")),
		"command_seq": int(command.get("command_seq", -1)),
		"player_id": int(command.get("sender_seat", command.get("src_owner", command.get("owner_id", 0)))),
		"kind": str(command.get("kind", "")),
		"intent": str(command.get("intent", "")),
		"issued_tick": int(command.get("issued_tick", -1)),
		"requested_tick": int(command.get("requested_execute_tick", -1)),
		"canonical_execute_tick": int(command.get("execute_tick", -1)),
		"local_tick": int(st.tick) if st != null else -1,
		"action_taken": action_taken,
		"state_hash": state_hash,
		"src": int(command.get("src", command.get("from_id", -1))),
		"dst": int(command.get("dst", command.get("to_id", -1))),
		"activation_id": str(command.get("activation_id", "")),
		"buff_id": str(command.get("buff_id", "")),
		"target_type": str(command.get("target_type", "")),
		"target_id": command.get("target_id", null)
	}

func _contract_diagnostics_snapshot() -> Dictionary:
	return {
		"contract_version": CONTRACT_VERSION,
		"contract_command_lead_ticks": _contract_current_command_lead_ticks,
		"contract_min_command_lead_ticks": -1 if _contract_min_command_lead_ticks == 2147483647 else _contract_min_command_lead_ticks,
		"contract_missed_scheduled_commands": _contract_missed_scheduled_commands,
		"contract_late_scheduled_commands": _contract_late_scheduled_commands,
		"contract_buffered_lagging_commands": _contract_buffered_lagging_commands,
		"contract_state_hash_mismatches": _contract_state_hash_mismatches,
		"hash_mismatch_consecutive_count": _hash_mismatch_consecutive_count,
		"hash_mismatch_threshold": HASH_MISMATCH_RECOVERY_THRESHOLD,
		"hash_startup_grace_ticks": HASH_STARTUP_GRACE_TICKS,
		"hash_recovery_pause_enabled": _hash_recovery_pause_enabled(),
		"hash_mismatch_last_details": _hash_mismatch_last_details.duplicate(true),
		"contract_violation_count": _contract_violation_count,
		"contract_last_violation_reason": _contract_last_violation_reason,
		"contract_report_path": _contract_diagnostic_log_path(),
		"contract_pending_commands": _pending_remote_commands.size(),
		"peer_desync_or_lagging": _peer_desync_or_lagging,
		"peer_desync_or_lagging_reason": _peer_desync_or_lagging_reason,
		"peer_desync_or_lagging_details": _peer_desync_or_lagging_details.duplicate(true),
		"recovery_state": _recovery_state,
		"recovery_attempts": _recovery_attempts,
		"recovery_last_outcome": _recovery_last_outcome,
		"recovery_desync_tick": _recovery_desync_tick,
		"last_matching_checkpoint_tick": _last_matching_checkpoint_tick,
		"authority_snapshot_count": _authority_snapshots_by_tick.size(),
		"accepted_command_log_size": _accepted_command_log.size()
	}

func _contract_diagnostic_log_path() -> String:
	return ProjectSettings.globalize_path(CONTRACT_DIAGNOSTIC_LOG_PATH)

func _should_poll_on_worker_thread() -> bool:
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("get_transport_mode"):
		return false
	return str(handshake.call("get_transport_mode")) == "http" and not _configured_backend_url().is_empty()

func _should_publish_on_worker_thread(command: Dictionary) -> bool:
	var kind: String = str(command.get("kind", "")).strip_edges().to_lower()
	if kind.is_empty():
		return false
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("get_transport_mode"):
		return false
	return str(handshake.call("get_transport_mode")) == "http" and not _configured_backend_url().is_empty()

func _enqueue_async_publish_command(command: Dictionary) -> void:
	var copy: Dictionary = command.duplicate(true)
	var kind: String = str(copy.get("kind", "")).strip_edges().to_lower()
	if kind == "state_hash":
		var kept: Array[Dictionary] = []
		for queued_any in _publish_queue:
			var queued: Dictionary = queued_any as Dictionary
			if str(queued.get("kind", "")).strip_edges().to_lower() == "state_hash":
				continue
			kept.append(queued)
		_publish_queue = kept
	_publish_queue.append(copy)

func _start_async_publish_commands() -> bool:
	_finish_publish_thread(false)
	if _publish_inflight or _publish_queue.is_empty():
		return true
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		_contract_violation("publish_backend_missing", {})
		return false
	var batch: Array = _publish_queue.duplicate(true)
	_publish_queue.clear()
	_publish_inflight = true
	_publish_thread = Thread.new()
	var generation: int = _publish_generation
	var err: Error = _publish_thread.start(Callable(self, "_publish_commands_thread").bind(
		backend_url,
		_configured_backend_timeout_sec(),
		_configured_backend_token(),
		_session_id,
		_local_uid,
		batch,
		generation
	))
	if err != OK:
		_publish_inflight = false
		_publish_thread = null
		for command_any in batch:
			if typeof(command_any) == TYPE_DICTIONARY:
				_enqueue_async_publish_command(command_any as Dictionary)
		_contract_violation("publish_thread_start_failed", {"err": int(err), "batch_size": batch.size()})
		return false
	return true

func _finish_publish_thread(force_wait: bool) -> void:
	if _publish_thread == null:
		_publish_inflight = false
		return
	if _publish_thread.is_alive():
		if not force_wait:
			return
	var completed: Variant = _publish_thread.wait_to_finish()
	_publish_thread = null
	_publish_inflight = false
	if typeof(completed) != TYPE_DICTIONARY:
		_contract_violation("publish_thread_bad_result", {"result_type": typeof(completed)})
		_start_async_publish_commands()
		return
	var payload: Dictionary = completed as Dictionary
	if int(payload.get("generation", -1)) == _publish_generation and is_active():
		var entries_any: Variant = payload.get("entries", [])
		if typeof(entries_any) == TYPE_ARRAY:
			var entries: Array = entries_any as Array
			for entry_any in entries:
				if typeof(entry_any) != TYPE_DICTIONARY:
					continue
				var entry: Dictionary = entry_any as Dictionary
				var command_any: Variant = entry.get("command", {})
				var result_any: Variant = entry.get("result", {})
				if typeof(command_any) != TYPE_DICTIONARY or typeof(result_any) != TYPE_DICTIONARY:
					continue
				_handle_publish_result(
					command_any as Dictionary,
					result_any as Dictionary,
					int(entry.get("t0_us", Time.get_ticks_usec()))
				)
	_start_async_publish_commands()

func _publish_commands_thread(
	backend_url: String,
	timeout_sec: float,
	auth_token: String,
	session_id: String,
	uid: String,
	commands: Array,
	generation: int
) -> Dictionary:
	var transport: VsHandshakeTransportHttp = VsHandshakeTransportHttp.new()
	transport.configure(backend_url, timeout_sec, auth_token)
	var entries: Array = []
	for command_any in commands:
		if typeof(command_any) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = (command_any as Dictionary).duplicate(true)
		var t0_us: int = Time.get_ticks_usec()
		var result: Dictionary = transport.call_action("publish_intent", {
			"session_id": session_id,
			"uid": uid,
			"command": command
		})
		entries.append({
			"command": command,
			"t0_us": t0_us,
			"result": result
		})
	return {
		"generation": generation,
		"entries": entries
	}

func publish_spectator_snapshot_async(snapshot: Dictionary) -> bool:
	_finish_spectator_snapshot_thread(false)
	if not is_active():
		return false
	if _spectator_snapshot_inflight:
		return false
	if snapshot.is_empty():
		return false
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		return false
	_spectator_snapshot_inflight = true
	_spectator_snapshot_thread = Thread.new()
	var generation: int = _spectator_snapshot_generation
	var err: Error = _spectator_snapshot_thread.start(Callable(self, "_publish_spectator_snapshot_thread").bind(
		backend_url,
		_configured_backend_timeout_sec(),
		_configured_backend_token(),
		_session_id,
		_local_uid,
		snapshot.duplicate(true),
		generation
	))
	if err != OK:
		_spectator_snapshot_inflight = false
		_spectator_snapshot_thread = null
		_spectator_snapshot_fail_count += 1
		_last_spectator_snapshot_result = {"ok": false, "err": "spectator_snapshot_thread_start_failed", "code": int(err)}
		SFLog.allow_tag("VS_SPECTATOR_SNAPSHOT_FAIL")
		SFLog.warn("VS_SPECTATOR_SNAPSHOT_FAIL", _last_spectator_snapshot_result, "", 1000)
		return false
	return true

func _finish_spectator_snapshot_thread(force_wait: bool) -> void:
	if _spectator_snapshot_thread == null:
		_spectator_snapshot_inflight = false
		return
	if _spectator_snapshot_thread.is_alive():
		if not force_wait:
			return
	var completed: Variant = _spectator_snapshot_thread.wait_to_finish()
	_spectator_snapshot_thread = null
	_spectator_snapshot_inflight = false
	if typeof(completed) != TYPE_DICTIONARY:
		_spectator_snapshot_fail_count += 1
		_last_spectator_snapshot_result = {"ok": false, "err": "spectator_snapshot_bad_result", "result_type": typeof(completed)}
		return
	var payload: Dictionary = completed as Dictionary
	if int(payload.get("generation", -1)) != _spectator_snapshot_generation or not is_active():
		return
	var result_any: Variant = payload.get("result", {})
	if typeof(result_any) != TYPE_DICTIONARY:
		_spectator_snapshot_fail_count += 1
		_last_spectator_snapshot_result = {"ok": false, "err": "spectator_snapshot_result_missing"}
		return
	var result: Dictionary = result_any as Dictionary
	_last_spectator_snapshot_result = result.duplicate(true)
	if bool(result.get("ok", false)):
		_spectator_snapshot_tx += 1
	else:
		_spectator_snapshot_fail_count += 1

func _publish_spectator_snapshot_thread(
	backend_url: String,
	timeout_sec: float,
	auth_token: String,
	session_id: String,
	uid: String,
	snapshot: Dictionary,
	generation: int
) -> Dictionary:
	var transport: VsHandshakeTransportHttp = VsHandshakeTransportHttp.new()
	transport.configure(backend_url, timeout_sec, auth_token)
	var result: Dictionary = transport.call_action("publish_spectator_snapshot", {
		"session_id": session_id,
		"uid": uid,
		"snapshot": snapshot
	})
	return {
		"generation": generation,
		"result": result
	}

func _start_async_remote_intent_poll() -> void:
	_finish_poll_thread(false)
	if _poll_inflight:
		return
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		return
	var payload: Dictionary = {
		"session_id": _session_id,
		"uid": _local_uid,
		"after_seq": _last_seq,
		"sim_tick": _current_sim_tick()
	}
	_poll_inflight = true
	_poll_thread = Thread.new()
	var generation: int = _poll_generation
	var err: Error = _poll_thread.start(Callable(self, "_poll_remote_intents_thread").bind(
		backend_url,
		_configured_backend_timeout_sec(),
		_configured_backend_token(),
		payload,
		generation
	))
	if err != OK:
		_poll_inflight = false
		_poll_thread = null

func _finish_poll_thread(force_wait: bool) -> void:
	if _poll_thread == null:
		_poll_inflight = false
		return
	if _poll_thread.is_alive():
		if not force_wait:
			return
	var completed: Variant = _poll_thread.wait_to_finish()
	_poll_thread = null
	_poll_inflight = false
	if typeof(completed) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = completed as Dictionary
	if int(payload.get("generation", -1)) != _poll_generation:
		return
	if not is_active():
		return
	var result_any: Variant = payload.get("result", {})
	if typeof(result_any) != TYPE_DICTIONARY:
		return
	_handle_remote_intent_poll_result(
		result_any as Dictionary,
		int(payload.get("t0_us", Time.get_ticks_usec())),
		int(payload.get("after_seq", _last_seq))
	)

func _poll_remote_intents_thread(
	backend_url: String,
	timeout_sec: float,
	auth_token: String,
	payload: Dictionary,
	generation: int
) -> Dictionary:
	var transport: VsHandshakeTransportHttp = VsHandshakeTransportHttp.new()
	transport.configure(backend_url, timeout_sec, auth_token)
	var t0_us: int = Time.get_ticks_usec()
	var result: Dictionary = transport.call_action("poll_intents", payload)
	return {
		"generation": generation,
		"after_seq": int(payload.get("after_seq", 0)),
		"t0_us": t0_us,
		"result": result
	}

func _reset_telemetry() -> void:
	_packet_tx = 0
	_packet_rx = 0
	_packet_dropped = 0
	_publish_count = 0
	_publish_fail_count = 0
	_poll_count = 0
	_poll_fail_count = 0
	_intent_events_tx = 0
	_intent_events_rx = 0
	_remote_commands_rx = 0
	_last_rtt_ms = 0.0
	_rtt_ema_ms = 0.0
	_server_tick_rate_hz = 0.0
	_server_frametime_ms = 0.0
	_rate_window_start_ms = Time.get_ticks_msec()
	_rate_window_rx_events = 0
	_snapshot_receive_rate_hz = 0.0
	_runtime_telemetry_last_sample_ms = 0
	_runtime_telemetry_write_ms_last = 0.0
	_runtime_telemetry_write_ms_max = 0.0
	_runtime_telemetry_write_count = 0
	_first_mismatch_snapshot_queued = false
	_update_runtime_telemetry()

func _record_transport_result(kind: String, result: Dictionary, t0_us: int) -> bool:
	var rtt_ms: float = float(Time.get_ticks_usec() - t0_us) / 1000.0
	_packet_tx += 1
	if kind == "publish":
		_publish_count += 1
	elif kind == "poll":
		_poll_count += 1
	var ok: bool = bool(result.get("ok", false))
	var connectivity_current: bool = _observe_transport_connectivity(kind, result, t0_us)
	if ok:
		_packet_rx += 1
	else:
		_packet_dropped += 1
		if kind == "publish":
			_publish_fail_count += 1
		elif kind == "poll":
			_poll_fail_count += 1
	_last_rtt_ms = rtt_ms
	if _rtt_ema_ms <= 0.0:
		_rtt_ema_ms = rtt_ms
	else:
		_rtt_ema_ms = lerpf(_rtt_ema_ms, rtt_ms, 0.20)
	_server_tick_rate_hz = maxf(0.0, float(result.get("server_tick_rate_hz", _server_tick_rate_hz)))
	_server_frametime_ms = maxf(0.0, float(result.get("server_frametime_ms", result.get("request_ms", _server_frametime_ms))))
	if not ok:
		_write_runtime_telemetry_event("transport_failed", {
			"kind": kind,
			"rtt_ms": snappedf(rtt_ms, 0.1),
			"result": result.duplicate(true)
		}, false)
	elif rtt_ms >= RUNTIME_TELEMETRY_SLOW_RTT_MS:
		_write_runtime_telemetry_event("transport_slow", {
			"kind": kind,
			"rtt_ms": snappedf(rtt_ms, 0.1),
			"threshold_ms": RUNTIME_TELEMETRY_SLOW_RTT_MS
		}, false)
	return connectivity_current

func _observe_transport_connectivity(
	kind: String,
	result: Dictionary,
	request_started_local_us: int = -1
) -> bool:
	if not bool(result.get("transport_error", false)):
		if not _local_transport_interruption.is_empty():
			var detected_local_us: int = int(_local_transport_interruption.get(
				"detected_local_us", 0
			))
			if request_started_local_us >= 0 and detected_local_us > 0 \
			and request_started_local_us <= detected_local_us:
				_write_runtime_telemetry_event("transport_recovery_stale_response_ignored", {
					"kind": kind,
					"request_started_local_us": request_started_local_us,
					"detected_local_us": detected_local_us
				}, false)
				return false
		var lifecycle_any: Variant = result.get("match_lifecycle", {})
		if typeof(lifecycle_any) == TYPE_DICTIONARY:
			_record_authoritative_server_clock(lifecycle_any as Dictionary)
		_clear_local_transport_interruption(kind, result)
		return true
	var now_local_ms: int = Time.get_ticks_msec()
	if _local_transport_interruption.is_empty():
		var estimated_server_now_ms: int = _estimated_authoritative_server_unix_ms(now_local_ms)
		var stale_ms: int = maxi(0, int(_match_lifecycle.get(
			"presence_stale_ms", LOCAL_TRANSPORT_STALE_FALLBACK_MS
		)))
		var grace_sec: int = maxi(1, int(_match_lifecycle.get(
			"reconnect_grace_sec", LOCAL_TRANSPORT_GRACE_FALLBACK_SEC
		)))
		var estimated_grace_start_ms: int = estimated_server_now_ms + stale_ms
		var estimate_source: String = "local_clock_fallback"
		if _last_authoritative_server_unix_ms > 0:
			estimated_grace_start_ms = _last_authoritative_server_unix_ms + stale_ms
			estimate_source = "last_server_clock_plus_stale_window"
		_local_transport_interruption = {
			"active": true,
			"kind": kind,
			"err": str(result.get("err", "transport_error")),
			"detected_local_ms": now_local_ms,
			"detected_local_us": Time.get_ticks_usec(),
			"estimated_server_unix_ms_at_detection": estimated_server_now_ms,
			"estimated_grace_start_server_unix_ms": estimated_grace_start_ms,
			"estimated_grace_deadline_server_unix_ms": estimated_grace_start_ms + grace_sec * 1000,
			"presence_stale_ms": stale_ms,
			"reconnect_grace_sec": grace_sec,
			"estimate_source": estimate_source,
			"should_pause": false
		}
		_local_transport_pause_emitted = false
		_refresh_local_transport_interruption(now_local_ms, true)
		return true
	_local_transport_interruption["kind"] = kind
	_local_transport_interruption["err"] = str(result.get("err", "transport_error"))
	_refresh_local_transport_interruption(now_local_ms)
	return true

func _refresh_local_transport_interruption(now_local_ms: int = -1, force_emit: bool = false) -> void:
	if _local_transport_interruption.is_empty():
		return
	var safe_now_local_ms: int = Time.get_ticks_msec() if now_local_ms < 0 else now_local_ms
	var estimated_server_now_ms: int = _estimated_authoritative_server_unix_ms(safe_now_local_ms)
	var grace_start_ms: int = int(_local_transport_interruption.get(
		"estimated_grace_start_server_unix_ms", estimated_server_now_ms
	))
	var should_pause: bool = estimated_server_now_ms >= grace_start_ms + LOCAL_TRANSPORT_PAUSE_SAFETY_MS
	_local_transport_interruption["estimated_server_unix_ms"] = estimated_server_now_ms
	_local_transport_interruption["should_pause"] = should_pause
	if not force_emit and (not should_pause or _local_transport_pause_emitted):
		return
	_local_transport_pause_emitted = should_pause
	local_transport_interruption_changed.emit(_local_transport_interruption.duplicate(true))

func _clear_local_transport_interruption(kind: String, result: Dictionary) -> void:
	if _local_transport_interruption.is_empty():
		return
	var recovered: Dictionary = _local_transport_interruption.duplicate(true)
	recovered["active"] = false
	recovered["recovered_local_ms"] = Time.get_ticks_msec()
	recovered["recovered_by"] = kind
	recovered["server_err"] = str(result.get("err", ""))
	var lifecycle_any: Variant = result.get("match_lifecycle", {})
	if typeof(lifecycle_any) == TYPE_DICTIONARY:
		recovered["match_lifecycle"] = (lifecycle_any as Dictionary).duplicate(true)
	_local_transport_interruption = {}
	_local_transport_pause_emitted = false
	local_transport_interruption_changed.emit(recovered)

func _record_authoritative_server_clock(snapshot: Dictionary) -> void:
	var server_unix_ms: int = int(snapshot.get("server_unix_ms", 0))
	if server_unix_ms <= 0 or server_unix_ms <= _last_authoritative_server_unix_ms:
		return
	_last_authoritative_server_unix_ms = server_unix_ms
	_last_authoritative_server_local_ms = Time.get_ticks_msec()

func _estimated_authoritative_server_unix_ms(now_local_ms: int = -1) -> int:
	var safe_now_local_ms: int = Time.get_ticks_msec() if now_local_ms < 0 else now_local_ms
	if _last_authoritative_server_unix_ms <= 0 or _last_authoritative_server_local_ms <= 0:
		return int(round(Time.get_unix_time_from_system() * 1000.0))
	return _last_authoritative_server_unix_ms + maxi(
		0, safe_now_local_ms - _last_authoritative_server_local_ms
	)

func _record_received_events(count: int) -> void:
	var safe_count: int = maxi(0, count)
	_intent_events_rx += safe_count
	_rate_window_rx_events += safe_count
	_roll_telemetry_rates()

func _roll_telemetry_rates() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if _rate_window_start_ms <= 0:
		_rate_window_start_ms = now_ms
		return
	var elapsed_ms: int = now_ms - _rate_window_start_ms
	if elapsed_ms < TELEMETRY_RATE_INTERVAL_MS:
		return
	_snapshot_receive_rate_hz = (float(_rate_window_rx_events) * 1000.0) / float(maxi(1, elapsed_ms))
	_rate_window_start_ms = now_ms
	_rate_window_rx_events = 0

func _update_runtime_telemetry() -> void:
	if OpsState == null or not OpsState.has_method("update_runtime_telemetry"):
		return
	var handshake: Node = _handshake()
	var transport_mode: String = "local"
	if handshake != null and handshake.has_method("get_transport_mode"):
		transport_mode = str(handshake.call("get_transport_mode"))
	var telemetry: Dictionary = {
		"transport_active": is_active(),
		"transport_mode": transport_mode,
		"server_tick_rate_hz": snappedf(_server_tick_rate_hz, 0.1),
		"server_frametime_ms": snappedf(_server_frametime_ms, 0.1),
		"snapshot_receive_rate_hz": snappedf(_snapshot_receive_rate_hz, 0.1),
		"ping_rtt_ms": snappedf(_last_rtt_ms, 0.1),
		"ping_rtt_ema_ms": snappedf(_rtt_ema_ms, 0.1),
		"packet_tx": _packet_tx,
		"packet_rx": _packet_rx,
		"packet_dropped": _packet_dropped,
		"publish_count": _publish_count,
		"publish_fail_count": _publish_fail_count,
		"publish_in_flight": _publish_inflight,
		"publish_queue_size": _publish_queue.size(),
		"last_publish_result": _last_publish_result.duplicate(true),
		"poll_count": _poll_count,
		"poll_fail_count": _poll_fail_count,
		"intent_events_tx": _intent_events_tx,
		"intent_events_rx": _intent_events_rx,
		"remote_commands_rx": _remote_commands_rx,
		"waiting_for_remote": false,
		"waiting_for_remote_reason": "not_lockstep"
	}
	telemetry.merge(_contract_diagnostics_snapshot(), true)
	telemetry["runtime_telemetry_log_path"] = _runtime_telemetry_log_path
	telemetry["runtime_telemetry_file_enabled"] = _runtime_telemetry_file_enabled()
	telemetry["telemetry_write_ms"] = snappedf(_runtime_telemetry_write_ms_last, 0.1)
	telemetry["telemetry_write_ms_max"] = snappedf(_runtime_telemetry_write_ms_max, 0.1)
	telemetry["telemetry_write_count"] = _runtime_telemetry_write_count
	OpsState.call("update_runtime_telemetry", telemetry)
	_maybe_write_runtime_telemetry_sample(telemetry)

func _maybe_write_runtime_telemetry_sample(telemetry: Dictionary) -> void:
	if not is_active():
		return
	if not _runtime_telemetry_file_enabled():
		return
	var now_ms: int = Time.get_ticks_msec()
	if _runtime_telemetry_last_sample_ms > 0 and now_ms - _runtime_telemetry_last_sample_ms < RUNTIME_TELEMETRY_SAMPLE_INTERVAL_MS:
		return
	_runtime_telemetry_last_sample_ms = now_ms
	if not _runtime_telemetry_log_started:
		_begin_runtime_telemetry_log()
	if _runtime_telemetry_log_path.is_empty():
		return
	var telemetry_for_log: Dictionary = telemetry.duplicate(true)
	telemetry_for_log["runtime_telemetry_log_path"] = _runtime_telemetry_log_path
	var sample: Dictionary = _runtime_telemetry_base_payload("sample")
	sample["telemetry"] = telemetry_for_log
	sample["runtime"] = get_debug_snapshot()
	var ops_runtime: Dictionary = _ops_runtime_telemetry_snapshot()
	if not ops_runtime.is_empty():
		sample["ops_runtime"] = ops_runtime
	var state_snapshot: Dictionary = _runtime_authority_state_snapshot()
	if not state_snapshot.is_empty():
		sample["state"] = state_snapshot
	_append_runtime_telemetry_line(sample)

func _begin_runtime_telemetry_log() -> void:
	_runtime_telemetry_log_started = true
	var dir_path: String = ProjectSettings.globalize_path(RUNTIME_TELEMETRY_LOG_DIR)
	var make_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if make_err != OK:
		SFLog.allow_tag("VS_RUNTIME_TELEMETRY_FILE")
		SFLog.warn("VS_RUNTIME_TELEMETRY_FILE", {
			"event": "mkdir_failed",
			"path": RUNTIME_TELEMETRY_LOG_DIR,
			"error": int(make_err)
		})
		return
	var filename: String = "pvp_runtime_%s_%s_%d.jsonl" % [
		_sanitize_log_token(_session_id),
		_sanitize_log_token(_local_uid),
		int(Time.get_unix_time_from_system() * 1000.0) + Time.get_ticks_msec()
	]
	_runtime_telemetry_log_path = "%s/%s" % [RUNTIME_TELEMETRY_LOG_DIR, filename]
	_append_runtime_telemetry_line(_runtime_telemetry_base_payload("session_start"))

func _runtime_telemetry_base_payload(event_type: String) -> Dictionary:
	return {
		"event": str(event_type),
		"unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"app_ms": Time.get_ticks_msec(),
		"match_id": _session_id,
		"mode": _mode,
		"role": _role,
		"local_uid": _local_uid,
		"local_seat": _local_seat,
		"remote_uid": _remote_uid,
		"remote_seat": _remote_seat,
		"last_seq": _last_seq,
		"recovery_state": _recovery_state,
		"peer_desync_or_lagging": _peer_desync_or_lagging,
		"peer_desync_or_lagging_reason": _peer_desync_or_lagging_reason
	}

func _runtime_authority_state_snapshot() -> Dictionary:
	var out: Dictionary = {}
	if OpsState == null:
		return out
	if OpsState.has_method("get_pvp_debug_state_snapshot"):
		var debug_any: Variant = OpsState.call("get_pvp_debug_state_snapshot")
		if typeof(debug_any) == TYPE_DICTIONARY:
			out.merge(debug_any as Dictionary, true)
	if OpsState.has_method("get_contract_state_hash"):
		out["hash"] = str(OpsState.call("get_contract_state_hash"))
	var state_any: Variant = OpsState.get("state") if OpsState != null else null
	if state_any != null:
		var tick_any: Variant = state_any.get("tick") if state_any is Object else null
		if tick_any != null:
			out["tick"] = int(tick_any)
	return out

func _ops_runtime_telemetry_snapshot() -> Dictionary:
	if OpsState == null or not OpsState.has_method("get_runtime_telemetry_snapshot"):
		return {}
	var snapshot_any: Variant = OpsState.call("get_runtime_telemetry_snapshot")
	if typeof(snapshot_any) == TYPE_DICTIONARY:
		return snapshot_any as Dictionary
	return {}

func _write_runtime_telemetry_event(event_type: String, payload: Dictionary, include_state: bool = true) -> void:
	if not is_active():
		return
	if not _runtime_telemetry_file_enabled():
		return
	if not _runtime_telemetry_log_started:
		_begin_runtime_telemetry_log()
	if _runtime_telemetry_log_path.is_empty():
		return
	var event: Dictionary = _runtime_telemetry_base_payload(event_type)
	event["payload"] = payload.duplicate(true)
	event["diagnostics"] = _contract_diagnostics_snapshot()
	if include_state:
		var state_snapshot: Dictionary = _runtime_authority_state_snapshot()
		if not state_snapshot.is_empty():
			event["state"] = state_snapshot
	_append_runtime_telemetry_line(event)

func _append_runtime_telemetry_line(payload: Dictionary) -> void:
	if _runtime_telemetry_log_path.is_empty():
		return
	var t0_us: int = Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(_runtime_telemetry_log_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_runtime_telemetry_log_path, FileAccess.WRITE_READ)
	if file == null:
		SFLog.allow_tag("VS_RUNTIME_TELEMETRY_FILE")
		SFLog.warn("VS_RUNTIME_TELEMETRY_FILE", {
			"event": "open_failed",
			"path": _runtime_telemetry_log_path,
			"error": int(FileAccess.get_open_error())
		})
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()
	_runtime_telemetry_write_ms_last = float(Time.get_ticks_usec() - t0_us) / 1000.0
	_runtime_telemetry_write_ms_max = maxf(_runtime_telemetry_write_ms_max, _runtime_telemetry_write_ms_last)
	_runtime_telemetry_write_count += 1

func _sanitize_log_token(value: String) -> String:
	var clean: String = str(value).strip_edges()
	if clean.is_empty():
		clean = "unknown"
	var out: String = ""
	for index in range(clean.length()):
		var character: String = clean.substr(index, 1)
		var code: int = character.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		var is_upper: bool = code >= 65 and code <= 90
		var is_lower: bool = code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or character == "-" or character == "_":
			out += character
		else:
			out += "_"
	if out.length() > 72:
		out = out.substr(0, 72)
	return out

func _resolve_local_seat(roster: Array, local_uid: String, role: String, mode: String = "", required_players: int = 2) -> int:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if str(entry.get("uid", "")).strip_edges() != local_uid:
			continue
		var seat: int = int(entry.get("seat", 0))
		if seat >= 1 and seat <= 4:
			return seat
	if not _mode_allows_two_player_seat_fallback(mode, required_players):
		return 0
	if role == "guest":
		return 2
	return 1

func _mode_allows_two_player_seat_fallback(mode: String, required_players: int) -> bool:
	if int(required_players) > 2:
		return false
	var clean_mode: String = str(mode).strip_edges().to_upper()
	if clean_mode == "2V2" or clean_mode == "3P FFA" or clean_mode == "3P_FFA" or clean_mode == "4P FFA" or clean_mode == "4P_FFA":
		return false
	return true

func _resolve_remote_uid(roster: Array, local_uid: String) -> String:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var uid: String = str(entry.get("uid", "")).strip_edges()
		if uid.is_empty() or uid == local_uid:
			continue
		return uid
	return ""

func _resolve_remote_seat(roster: Array, local_seat: int) -> int:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		if seat < 1 or seat > 4 or seat == local_seat:
			continue
		if not bool(entry.get("active", seat <= 2)):
			continue
		return seat
	return 2 if local_seat == 1 else 1

func _handshake() -> Node:
	return get_node_or_null("/root/VsHandshake")

func _configured_backend_url() -> String:
	var env_url: String = OS.get_environment(ENV_BACKEND_URL).strip_edges()
	if not env_url.is_empty():
		return env_url
	if ProjectSettings.has_setting(SETTINGS_BACKEND_URL):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_URL, "")).strip_edges()
	return ""

func _configured_backend_token() -> String:
	var env_token: String = OS.get_environment(ENV_BACKEND_TOKEN).strip_edges()
	if not env_token.is_empty():
		return env_token
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TOKEN):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_TOKEN, "")).strip_edges()
	return ""

func _configured_backend_timeout_sec() -> float:
	var configured_timeout: float = DEFAULT_BACKEND_TIMEOUT_SEC
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TIMEOUT_SEC):
		configured_timeout = float(ProjectSettings.get_setting(SETTINGS_BACKEND_TIMEOUT_SEC, DEFAULT_BACKEND_TIMEOUT_SEC))
	return maxf(0.1, configured_timeout)
