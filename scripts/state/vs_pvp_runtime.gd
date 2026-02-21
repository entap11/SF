extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

const POLL_INTERVAL_SEC: float = 0.10

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

func clear() -> void:
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
	if not is_active():
		return
	_poll_accum += maxf(0.0, delta)
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
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("publish_intent"):
		return
	var result: Dictionary = handshake.call("publish_intent", _session_id, _local_uid, command) as Dictionary
	if not bool(result.get("ok", false)):
		SFLog.allow_tag("VS_PVP_PUBLISH_FAIL")
		SFLog.warn("VS_PVP_PUBLISH_FAIL", {
			"session_id": _session_id,
			"kind": str(command.get("kind", "")),
			"err": str(result.get("err", "unknown"))
		}, "", 500)

func _poll_remote_intents() -> void:
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("poll_intents"):
		return
	var result: Dictionary = handshake.call("poll_intents", _session_id, _local_uid, _last_seq) as Dictionary
	if not bool(result.get("ok", false)):
		return
	var latest_seq: int = int(result.get("latest_seq", _last_seq))
	if latest_seq > _last_seq:
		_last_seq = latest_seq
	var events_any: Variant = result.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		return
	for event_any in events_any as Array:
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
