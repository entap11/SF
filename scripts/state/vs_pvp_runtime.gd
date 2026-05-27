extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const VsHandshakeTransportHttp := preload("res://scripts/state/vs_handshake_transport_http.gd")

const POLL_INTERVAL_SEC: float = 0.10
const TELEMETRY_RATE_INTERVAL_MS: int = 1000
const ENV_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const ENV_BACKEND_TOKEN: String = "SF_VS_BACKEND_TOKEN"
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/vs/backend_timeout_sec"
const DEFAULT_BACKEND_TIMEOUT_SEC: float = 6.0

var _active: bool = false
var _session_id: String = ""
var _mode: String = ""
var _local_uid: String = ""
var _local_seat: int = 1
var _remote_uid: String = ""
var _remote_seat: int = 2
var _last_seq: int = 0
var _poll_accum: float = 0.0
var _pending_remote_commands: Array[Dictionary] = []
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

func _exit_tree() -> void:
	_poll_generation += 1
	_publish_generation += 1
	_finish_poll_thread(true)
	_finish_publish_thread(true)

func clear() -> void:
	_poll_generation += 1
	_publish_generation += 1
	_finish_poll_thread(true)
	_finish_publish_thread(true)
	_active = false
	_session_id = ""
	_mode = ""
	_local_uid = ""
	_local_seat = 1
	_remote_uid = ""
	_remote_seat = 2
	_last_seq = 0
	_poll_accum = 0.0
	_pending_remote_commands.clear()
	_publish_queue.clear()
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
	_local_uid = local_uid
	_local_seat = _resolve_local_seat(roster, local_uid, role)
	_remote_uid = _resolve_remote_uid(roster, local_uid)
	_remote_seat = _resolve_remote_seat(roster, _local_seat)
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
		"role": role
	})

func is_active() -> bool:
	return _active and not _session_id.is_empty() and not _local_uid.is_empty()

func get_local_seat() -> int:
	return _local_seat

func get_remote_seat() -> int:
	return _remote_seat

func tick(delta: float) -> void:
	_finish_poll_thread(false)
	_finish_publish_thread(false)
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

func consume_remote_commands() -> Array:
	if _pending_remote_commands.is_empty():
		return []
	var out: Array = _pending_remote_commands.duplicate(true)
	_pending_remote_commands.clear()
	return out

func record_local_lane_intent(src_hive_id: int, dst_hive_id: int, intent: String, src_owner_id: int, dst_owner_id: int) -> void:
	if not is_active():
		return
	if src_owner_id != _local_seat:
		return
	_publish_command({
		"kind": "lane_intent",
		"src": int(src_hive_id),
		"dst": int(dst_hive_id),
		"intent": str(intent),
		"src_owner": int(src_owner_id),
		"dst_owner": int(dst_owner_id),
		"issued_ms": Time.get_ticks_msec()
	})

func record_local_lane_retract(from_id: int, to_id: int, owner_id: int) -> void:
	if not is_active():
		return
	if owner_id != _local_seat:
		return
	_publish_command({
		"kind": "lane_retract",
		"from_id": int(from_id),
		"to_id": int(to_id),
		"owner_id": int(owner_id),
		"issued_ms": Time.get_ticks_msec()
	})

func record_local_barracks_route(barracks_id: int, route_hive_ids: Array, owner_id: int) -> void:
	if not is_active():
		return
	if owner_id != _local_seat:
		return
	_publish_command({
		"kind": "barracks_route",
		"barracks_id": int(barracks_id),
		"route_hive_ids": route_hive_ids.duplicate(),
		"owner_id": int(owner_id),
		"issued_ms": Time.get_ticks_msec()
	})

func _publish_command(command: Dictionary) -> void:
	if _should_publish_on_worker_thread():
		_publish_queue.append(command.duplicate(true))
		_start_async_publish_commands()
		return
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("publish_intent"):
		return
	var t0_us: int = Time.get_ticks_usec()
	var result: Dictionary = handshake.call("publish_intent", _session_id, _local_uid, command) as Dictionary
	_handle_publish_result(command, result, t0_us)

func _handle_publish_result(command: Dictionary, result: Dictionary, t0_us: int) -> void:
	_record_transport_result("publish", result, t0_us)
	if not bool(result.get("ok", false)):
		SFLog.allow_tag("VS_PVP_PUBLISH_FAIL")
		SFLog.warn("VS_PVP_PUBLISH_FAIL", {
			"session_id": _session_id,
			"kind": str(command.get("kind", "")),
			"err": str(result.get("err", "unknown"))
		}, "", 500)
		return
	_intent_events_tx += 1
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
	var result: Dictionary = handshake.call("poll_intents", _session_id, _local_uid, after_seq) as Dictionary
	_handle_remote_intent_poll_result(result, t0_us, after_seq)

func _handle_remote_intent_poll_result(result: Dictionary, t0_us: int, after_seq: int) -> void:
	_record_transport_result("poll", result, t0_us)
	if not bool(result.get("ok", false)):
		_update_runtime_telemetry()
		return
	var latest_seq: int = int(result.get("latest_seq", _last_seq))
	var events_any: Variant = result.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		if latest_seq > _last_seq:
			_last_seq = latest_seq
		_update_runtime_telemetry()
		return
	var events: Array = events_any as Array
	_record_received_events(events.size())
	var missing_seq_count: int = maxi(0, (latest_seq - after_seq) - events.size())
	if missing_seq_count > 0:
		_packet_dropped += missing_seq_count
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
		if _remote_uid.is_empty():
			_remote_uid = sender_uid
		elif sender_uid != _remote_uid:
			continue
		var command_any: Variant = event.get("command", {})
		if typeof(command_any) != TYPE_DICTIONARY:
			continue
		var command: Dictionary = (command_any as Dictionary).duplicate(true)
		_pending_remote_commands.append(command)
		_remote_commands_rx += 1
	_update_runtime_telemetry()

func _should_poll_on_worker_thread() -> bool:
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("get_transport_mode"):
		return false
	return str(handshake.call("get_transport_mode")) == "http" and not _configured_backend_url().is_empty()

func _should_publish_on_worker_thread() -> bool:
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("get_transport_mode"):
		return false
	return str(handshake.call("get_transport_mode")) == "http" and not _configured_backend_url().is_empty()

func _start_async_publish_commands() -> void:
	_finish_publish_thread(false)
	if _publish_inflight or _publish_queue.is_empty():
		return
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		return
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
				_publish_queue.append(command_any as Dictionary)

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
		"after_seq": _last_seq
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
	_update_runtime_telemetry()

func _record_transport_result(kind: String, result: Dictionary, t0_us: int) -> void:
	var rtt_ms: float = float(Time.get_ticks_usec() - t0_us) / 1000.0
	_packet_tx += 1
	if kind == "publish":
		_publish_count += 1
	elif kind == "poll":
		_poll_count += 1
	var ok: bool = bool(result.get("ok", false))
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
	OpsState.call("update_runtime_telemetry", {
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
		"poll_count": _poll_count,
		"poll_fail_count": _poll_fail_count,
		"intent_events_tx": _intent_events_tx,
		"intent_events_rx": _intent_events_rx,
		"remote_commands_rx": _remote_commands_rx,
		"waiting_for_remote": false,
		"waiting_for_remote_reason": "not_lockstep"
	})

func _resolve_local_seat(roster: Array, local_uid: String, role: String) -> int:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if str(entry.get("uid", "")).strip_edges() != local_uid:
			continue
		var seat: int = int(entry.get("seat", 0))
		if seat >= 1 and seat <= 4:
			return seat
	if role == "guest":
		return 2
	return 1

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
