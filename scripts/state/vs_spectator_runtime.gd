class_name VsSpectatorRuntime
extends Node

signal spectator_state_changed(snapshot: Dictionary)
signal spectator_events_received(events: Array)
signal spectator_snapshots_received(snapshots: Array)

const DEFAULT_POLL_INTERVAL_SEC: float = 1.0
const MAX_EVENT_BUFFER: int = 256
const MAX_SNAPSHOT_BUFFER: int = 128

var _handshake: Node = null
var _active: bool = false
var _polling: bool = false
var _poll_interval_sec: float = DEFAULT_POLL_INTERVAL_SEC
var _poll_accum: float = 0.0
var _session_id: String = ""
var _grant_token: String = ""
var _spectator_uid: String = ""
var _display_name: String = ""
var _last_seq: int = 0
var _last_snapshot_seq: int = 0
var _delay_sec: int = 0
var _live: bool = false
var _event_buffer: Array[Dictionary] = []
var _snapshot_buffer: Array[Dictionary] = []
var _last_result: Dictionary = {}
var _poll_count: int = 0
var _poll_fail_count: int = 0

func _ready() -> void:
	set_process(false)

func configure(session_id: String, grant_token: String, spectator_uid: String = "", display_name: String = "", handshake_node: Node = null) -> void:
	clear(false)
	_session_id = session_id.strip_edges()
	_grant_token = grant_token.strip_edges()
	_spectator_uid = spectator_uid.strip_edges()
	_display_name = display_name.strip_edges()
	_handshake = handshake_node
	_active = not _session_id.is_empty() and not _grant_token.is_empty()
	_emit_state()

func clear(emit_state: bool = true) -> void:
	_active = false
	_polling = false
	_poll_accum = 0.0
	_session_id = ""
	_grant_token = ""
	_spectator_uid = ""
	_display_name = ""
	_last_seq = 0
	_last_snapshot_seq = 0
	_delay_sec = 0
	_live = false
	_event_buffer.clear()
	_snapshot_buffer.clear()
	_last_result = {}
	_poll_count = 0
	_poll_fail_count = 0
	set_process(false)
	if emit_state:
		_emit_state()

func is_active() -> bool:
	return _active and not _session_id.is_empty() and not _grant_token.is_empty()

func join() -> Dictionary:
	if not is_active():
		return _record_result({"ok": false, "err": "spectator_not_configured"})
	var handshake: Node = _resolve_handshake()
	if handshake == null or not handshake.has_method("join_spectate"):
		return _record_result({"ok": false, "err": "spectator_transport_missing"})
	var result: Dictionary = handshake.call("join_spectate", _grant_token, _session_id, _spectator_uid) as Dictionary
	if bool(result.get("ok", false)):
		_apply_spectator_meta(result.get("spectator", {}) as Dictionary)
	return _record_result(result)

func poll_once() -> Dictionary:
	if not is_active():
		return _record_result({"ok": false, "err": "spectator_not_configured"})
	var handshake: Node = _resolve_handshake()
	if handshake == null or not handshake.has_method("poll_spectator_events"):
		return _record_result({"ok": false, "err": "spectator_transport_missing"})
	_poll_count += 1
	var result: Dictionary = handshake.call("poll_spectator_events", _grant_token, _session_id, _last_seq) as Dictionary
	if not bool(result.get("ok", false)):
		_poll_fail_count += 1
		return _record_result(result)
	_delay_sec = int(result.get("delay_sec", _delay_sec))
	_live = bool(result.get("live", _live))
	var events: Array = result.get("events", []) as Array
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = (event_any as Dictionary).duplicate(true)
		_last_seq = maxi(_last_seq, int(event.get("seq", 0)))
		_event_buffer.append(event)
	while _event_buffer.size() > MAX_EVENT_BUFFER:
		_event_buffer.remove_at(0)
	if result.has("latest_seq"):
		_last_seq = maxi(_last_seq, int(result.get("latest_seq", _last_seq)))
	if not events.is_empty():
		emit_signal("spectator_events_received", events)
	return _record_result(result)

func poll_snapshots_once() -> Dictionary:
	if not is_active():
		return _record_result({"ok": false, "err": "spectator_not_configured"})
	var handshake: Node = _resolve_handshake()
	if handshake == null or not handshake.has_method("poll_spectator_snapshots"):
		return _record_result({"ok": false, "err": "spectator_snapshot_transport_missing"})
	var result: Dictionary = handshake.call("poll_spectator_snapshots", _grant_token, _session_id, _last_snapshot_seq) as Dictionary
	if not bool(result.get("ok", false)):
		return _record_result(result)
	_delay_sec = int(result.get("delay_sec", _delay_sec))
	_live = bool(result.get("live", _live))
	var snapshots: Array = result.get("snapshots", []) as Array
	for snapshot_any in snapshots:
		if typeof(snapshot_any) != TYPE_DICTIONARY:
			continue
		var snapshot_event: Dictionary = (snapshot_any as Dictionary).duplicate(true)
		_last_snapshot_seq = maxi(_last_snapshot_seq, int(snapshot_event.get("seq", 0)))
		_snapshot_buffer.append(snapshot_event)
	while _snapshot_buffer.size() > MAX_SNAPSHOT_BUFFER:
		_snapshot_buffer.remove_at(0)
	if result.has("latest_seq"):
		_last_snapshot_seq = maxi(_last_snapshot_seq, int(result.get("latest_seq", _last_snapshot_seq)))
	if not snapshots.is_empty():
		emit_signal("spectator_snapshots_received", snapshots)
	return _record_result(result)

func start_polling(interval_sec: float = DEFAULT_POLL_INTERVAL_SEC) -> void:
	_poll_interval_sec = maxf(0.25, interval_sec)
	_poll_accum = 0.0
	_polling = is_active()
	set_process(_polling)
	_emit_state()

func stop_polling() -> void:
	_polling = false
	set_process(false)
	_emit_state()

func leave() -> Dictionary:
	if _grant_token.is_empty():
		clear()
		return {"ok": true, "closed": true}
	var handshake: Node = _resolve_handshake()
	var result: Dictionary = {"ok": true, "closed": true}
	if handshake != null and handshake.has_method("leave_spectate"):
		result = handshake.call("leave_spectate", _grant_token) as Dictionary
	clear(false)
	return _record_result(result)

func get_event_buffer() -> Array[Dictionary]:
	return _event_buffer.duplicate(true)

func get_snapshot_buffer() -> Array[Dictionary]:
	return _snapshot_buffer.duplicate(true)

func get_latest_snapshot() -> Dictionary:
	if _snapshot_buffer.is_empty():
		return {}
	return (_snapshot_buffer[_snapshot_buffer.size() - 1] as Dictionary).duplicate(true)

func get_debug_snapshot() -> Dictionary:
	return {
		"active": is_active(),
		"polling": _polling,
		"session_id": _session_id,
		"spectator_uid": _spectator_uid,
		"display_name": _display_name,
		"last_seq": _last_seq,
		"last_snapshot_seq": _last_snapshot_seq,
		"delay_sec": _delay_sec,
		"live": _live,
		"event_count": _event_buffer.size(),
		"snapshot_count": _snapshot_buffer.size(),
		"poll_count": _poll_count,
		"poll_fail_count": _poll_fail_count,
		"last_result": _last_result.duplicate(true)
	}

func _process(delta: float) -> void:
	if not _polling or not is_active():
		return
	_poll_accum += delta
	if _poll_accum < _poll_interval_sec:
		return
	_poll_accum = 0.0
	poll_once()

func _resolve_handshake() -> Node:
	if _handshake != null and is_instance_valid(_handshake):
		return _handshake
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	_handshake = tree.root.get_node_or_null("VsHandshake")
	return _handshake

func _apply_spectator_meta(meta: Dictionary) -> void:
	_delay_sec = int(meta.get("delay_sec", _delay_sec))
	_live = bool(meta.get("live", _live))
	if _spectator_uid.is_empty():
		_spectator_uid = str(meta.get("spectator_uid", "")).strip_edges()
	if _display_name.is_empty():
		_display_name = str(meta.get("display_name", "")).strip_edges()

func _record_result(result: Dictionary) -> Dictionary:
	_last_result = result.duplicate(true)
	_emit_state()
	return result

func _emit_state() -> void:
	emit_signal("spectator_state_changed", get_debug_snapshot())
