extends Node

signal session_changed(session_id: String, session: Dictionary)
signal queue_changed(queue_size: int)

const SFLog := preload("res://scripts/util/sf_log.gd")
const VsHandshakeTransportHttp := preload("res://scripts/state/vs_handshake_transport_http.gd")

const SESSION_TTL_SEC: int = 15 * 60
const QUEUE_TTL_SEC: int = 90
const INTENT_STREAM_MAX_EVENTS: int = 512
const ENV_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const ENV_BACKEND_TOKEN: String = "SF_VS_BACKEND_TOKEN"
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/vs/backend_timeout_sec"
const DEFAULT_BACKEND_TIMEOUT_SEC: float = 2.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sessions: Dictionary = {}
var _invite_to_session: Dictionary = {}
var _queue: Array[Dictionary] = []
var _intent_streams: Dictionary = {}
var _transport_http: VsHandshakeTransportHttp = null
var _transport_mode: String = "local"
var _transport_error_logged: bool = false

func _ready() -> void:
	_rng.randomize()
	_configure_transport()

func _configure_transport() -> void:
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		_transport_http = null
		_transport_mode = "local"
		return
	_transport_http = VsHandshakeTransportHttp.new()
	_transport_http.configure(
		backend_url,
		_configured_backend_timeout_sec(),
		_configured_backend_token()
	)
	_transport_mode = "http"
	SFLog.allow_tag("VS_TRANSPORT_CONFIG")
	SFLog.info("VS_TRANSPORT_CONFIG", {"mode": _transport_mode, "url": backend_url})

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
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TIMEOUT_SEC):
		return maxf(0.1, float(ProjectSettings.get_setting(SETTINGS_BACKEND_TIMEOUT_SEC, DEFAULT_BACKEND_TIMEOUT_SEC)))
	return DEFAULT_BACKEND_TIMEOUT_SEC

func _call_transport(action: String, payload: Dictionary) -> Dictionary:
	if _transport_http == null or not _transport_http.configured():
		return {"handled": false}
	var result: Dictionary = _transport_http.call_action(action, payload)
	if bool(result.get("ok", false)):
		_transport_error_logged = false
		return {"handled": true, "result": result}
	if bool(result.get("transport_error", false)):
		if not _transport_error_logged:
			_transport_error_logged = true
			SFLog.allow_tag("VS_TRANSPORT_FALLBACK")
			SFLog.warn("VS_TRANSPORT_FALLBACK", {
				"action": action,
				"err": str(result.get("err", "transport_error")),
				"mode": _transport_mode
			}, "", 3000)
		return {"handled": false}
	return {"handled": true, "result": result}

func create_invite(profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("create_invite", {
		"profile": profile,
		"context": context
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var host: Dictionary = _normalize_profile(profile)
	if host.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var session: Dictionary = _new_session(host, context, "invite")
	var session_id: String = str(session.get("id", ""))
	if session_id.is_empty():
		return {"ok": false, "err": "session_create_failed"}
	_sessions[session_id] = session
	_invite_to_session[str(session.get("invite_code", ""))] = session_id
	_emit_session_changed(session_id)
	return {
		"ok": true,
		"session_id": session_id,
		"invite_code": str(session.get("invite_code", "")),
		"session": _dup_session(session)
	}

func join_invite(invite_code: String, profile: Dictionary) -> Dictionary:
	var transport := _call_transport("join_invite", {
		"invite_code": invite_code,
		"profile": profile
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var code: String = invite_code.strip_edges().to_upper()
	if code.is_empty():
		return {"ok": false, "err": "invite_code_empty"}
	if not _invite_to_session.has(code):
		return {"ok": false, "err": "invite_not_found"}
	var session_id: String = str(_invite_to_session.get(code, ""))
	if session_id.is_empty() or not _sessions.has(session_id):
		return {"ok": false, "err": "session_not_found"}
	var guest: Dictionary = _normalize_profile(profile)
	if guest.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var session: Dictionary = _sessions.get(session_id, {}) as Dictionary
	if not _is_session_live(session):
		_close_session_internal(session_id, "expired")
		return {"ok": false, "err": "session_expired"}
	var host: Dictionary = session.get("host", {}) as Dictionary
	if str(host.get("uid", "")) == str(guest.get("uid", "")):
		return {"ok": false, "err": "cannot_join_own_invite"}
	var existing_guest: Dictionary = session.get("guest", {}) as Dictionary
	var existing_guest_uid: String = str(existing_guest.get("uid", ""))
	if existing_guest_uid != "" and existing_guest_uid != str(guest.get("uid", "")):
		return {"ok": false, "err": "invite_full"}
	session["guest"] = {
		"uid": str(guest.get("uid", "")),
		"display_name": str(guest.get("display_name", "Player 2")),
		"ready": bool(existing_guest.get("ready", false))
	}
	_session_refresh_status(session)
	_sessions[session_id] = session
	_emit_session_changed(session_id)
	return {"ok": true, "session_id": session_id, "session": _dup_session(session)}

func enqueue_quick_match(profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("enqueue_quick_match", {
		"profile": profile,
		"context": context
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var player: Dictionary = _normalize_profile(profile)
	if player.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var uid: String = str(player.get("uid", ""))
	for ticket in _queue:
		if str(ticket.get("uid", "")) == uid:
			return {
				"ok": true,
				"matched": false,
				"ticket_id": str(ticket.get("id", ""))
			}
	for i in range(_queue.size()):
		var other: Dictionary = _queue[i] as Dictionary
		if str(other.get("uid", "")) == uid:
			continue
		if not _contexts_compatible(context, other.get("context", {}) as Dictionary):
			continue
		var host: Dictionary = {
			"uid": str(other.get("uid", "")),
			"display_name": str(other.get("display_name", "Player 1")),
			"ready": false,
			"ticket_id": str(other.get("id", ""))
		}
		var session: Dictionary = _new_session(host, context, "quick")
		session["guest"] = {
			"uid": uid,
			"display_name": str(player.get("display_name", "Player 2")),
			"ready": false,
			"ticket_id": ""
		}
		_session_refresh_status(session)
		var session_id: String = str(session.get("id", ""))
		_sessions[session_id] = session
		_invite_to_session[str(session.get("invite_code", ""))] = session_id
		_queue.remove_at(i)
		emit_signal("queue_changed", _queue.size())
		_emit_session_changed(session_id)
		return {
			"ok": true,
			"matched": true,
			"session_id": session_id,
			"session": _dup_session(session)
		}
	var ticket_id: String = _next_ticket_id()
	_queue.append({
		"id": ticket_id,
		"uid": uid,
		"display_name": str(player.get("display_name", "Player")),
		"context": context.duplicate(true),
		"created_unix": int(Time.get_unix_time_from_system())
	})
	emit_signal("queue_changed", _queue.size())
	return {
		"ok": true,
		"matched": false,
		"ticket_id": ticket_id
	}

func poll_quick_match(ticket_id: String) -> Dictionary:
	var transport := _call_transport("poll_quick_match", {
		"ticket_id": ticket_id
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for session_any in _sessions.values():
		var session: Dictionary = session_any as Dictionary
		var source: String = str(session.get("source", ""))
		if source != "quick":
			continue
		var host: Dictionary = session.get("host", {}) as Dictionary
		var guest: Dictionary = session.get("guest", {}) as Dictionary
		if str(host.get("ticket_id", "")) == tid or str(guest.get("ticket_id", "")) == tid:
			return {
				"ok": true,
				"matched": true,
				"session_id": str(session.get("id", "")),
				"session": _dup_session(session)
			}
	for ticket_any in _queue:
		var ticket: Dictionary = ticket_any as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		return {"ok": true, "matched": false, "ticket_id": tid}
	return {"ok": false, "err": "ticket_not_found"}

func cancel_quick_match(ticket_id: String, uid: String = "") -> Dictionary:
	var transport := _call_transport("cancel_quick_match", {
		"ticket_id": ticket_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for i in range(_queue.size()):
		var ticket: Dictionary = _queue[i] as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		var owner_uid: String = str(ticket.get("uid", ""))
		if uid.strip_edges() != "" and owner_uid != uid:
			return {"ok": false, "err": "ticket_owner_mismatch"}
		_queue.remove_at(i)
		emit_signal("queue_changed", _queue.size())
		return {"ok": true}
	return {"ok": false, "err": "ticket_not_found"}

func debug_fill_quick_match(ticket_id: String, bot_name: String = "Rival") -> Dictionary:
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for i in range(_queue.size()):
		var ticket: Dictionary = _queue[i] as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		var host: Dictionary = {
			"uid": str(ticket.get("uid", "")),
			"display_name": str(ticket.get("display_name", "Player")),
			"ready": false,
			"ticket_id": tid
		}
		var context: Dictionary = ticket.get("context", {}) as Dictionary
		var session: Dictionary = _new_session(host, context, "quick")
		session["guest"] = {
			"uid": _next_bot_uid(),
			"display_name": bot_name,
			"ready": true
		}
		_session_refresh_status(session)
		var session_id: String = str(session.get("id", ""))
		_sessions[session_id] = session
		_invite_to_session[str(session.get("invite_code", ""))] = session_id
		_queue.remove_at(i)
		emit_signal("queue_changed", _queue.size())
		_emit_session_changed(session_id)
		return {"ok": true, "session_id": session_id, "session": _dup_session(session)}
	return {"ok": false, "err": "ticket_not_found"}

func debug_fill_session(session_id: String, bot_name: String = "Rival") -> Dictionary:
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty() or not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	if str(guest.get("uid", "")) == "":
		session["guest"] = {
			"uid": _next_bot_uid(),
			"display_name": bot_name,
			"ready": false
		}
	_session_refresh_status(session)
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session_id": sid, "session": _dup_session(session)}

func get_session(session_id: String) -> Dictionary:
	var transport := _call_transport("get_session", {"session_id": session_id})
	if bool(transport.get("handled", false)):
		var result: Dictionary = transport.get("result", {}) as Dictionary
		var session_v: Variant = result.get("session", {})
		if typeof(session_v) == TYPE_DICTIONARY:
			return session_v as Dictionary
		if bool(result.get("ok", false)):
			return result
		return {}
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty() or not _sessions.has(sid):
		return {}
	return _dup_session(_sessions.get(sid, {}) as Dictionary)

func set_ready(session_id: String, uid: String, ready: bool) -> Dictionary:
	var transport := _call_transport("set_ready", {
		"session_id": session_id,
		"uid": uid,
		"ready": ready
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	if not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var host_uid: String = str(host.get("uid", ""))
	var guest_uid: String = str(guest.get("uid", ""))
	if player_uid == host_uid:
		host["ready"] = ready
		session["host"] = host
	elif player_uid == guest_uid and guest_uid != "":
		guest["ready"] = ready
		session["guest"] = guest
	else:
		return {"ok": false, "err": "player_not_in_session"}
	_session_refresh_status(session)
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session": _dup_session(session)}

func can_start(session_id: String, uid: String) -> bool:
	var transport := _call_transport("can_start", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		var result: Dictionary = transport.get("result", {}) as Dictionary
		return bool(result.get("can_start", result.get("ok", false)))
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty() or not _sessions.has(sid):
		return false
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if str(session.get("status", "")) != "ready":
		return false
	var host: Dictionary = session.get("host", {}) as Dictionary
	return str(host.get("uid", "")) == player_uid

func start_session(session_id: String, uid: String) -> Dictionary:
	var transport := _call_transport("start_session", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	if not can_start(sid, uid):
		return {"ok": false, "err": "not_ready_or_not_host"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	session["status"] = "started"
	session["started_unix"] = int(Time.get_unix_time_from_system())
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session": _dup_session(session)}

func leave_session(session_id: String, uid: String) -> Dictionary:
	var transport := _call_transport("leave_session", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty() or not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	if str(host.get("uid", "")) == player_uid:
		_close_session_internal(sid, "host_left")
		return {"ok": true, "closed": true}
	if str(guest.get("uid", "")) == player_uid:
		session["guest"] = {"uid": "", "display_name": "", "ready": false}
		host["ready"] = false
		session["host"] = host
		_session_refresh_status(session)
		_sessions[sid] = session
		_emit_session_changed(sid)
		return {"ok": true, "closed": false, "session": _dup_session(session)}
	return {"ok": false, "err": "player_not_in_session"}

func publish_intent(session_id: String, uid: String, command: Dictionary) -> Dictionary:
	var transport := _call_transport("publish_intent", {
		"session_id": session_id,
		"uid": uid,
		"command": command
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var sender_uid: String = uid.strip_edges()
	if sid.is_empty() or sender_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if session.is_empty():
		return {"ok": false, "err": "session_not_found"}
	if not _session_has_player_uid(session, sender_uid):
		return {"ok": false, "err": "player_not_in_session"}
	var stream: Dictionary = _intent_streams.get(sid, {"next_seq": 1, "events": []}) as Dictionary
	var seq: int = int(stream.get("next_seq", 1))
	if seq <= 0:
		seq = 1
	stream["next_seq"] = seq + 1
	var events_any: Variant = stream.get("events", [])
	var events: Array = events_any as Array if typeof(events_any) == TYPE_ARRAY else []
	var event: Dictionary = {
		"seq": seq,
		"uid": sender_uid,
		"command": command.duplicate(true),
		"ts_unix": int(Time.get_unix_time_from_system())
	}
	events.append(event)
	while events.size() > INTENT_STREAM_MAX_EVENTS:
		events.remove_at(0)
	stream["events"] = events
	_intent_streams[sid] = stream
	return {"ok": true, "seq": seq}

func poll_intents(session_id: String, uid: String, after_seq: int = 0) -> Dictionary:
	var transport := _call_transport("poll_intents", {
		"session_id": session_id,
		"uid": uid,
		"after_seq": after_seq
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var viewer_uid: String = uid.strip_edges()
	if sid.is_empty() or viewer_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if session.is_empty():
		return {"ok": false, "err": "session_not_found"}
	if not _session_has_player_uid(session, viewer_uid):
		return {"ok": false, "err": "player_not_in_session"}
	var stream: Dictionary = _intent_streams.get(sid, {}) as Dictionary
	if stream.is_empty():
		return {"ok": true, "events": [], "latest_seq": maxi(0, after_seq)}
	var events_any: Variant = stream.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		return {"ok": true, "events": [], "latest_seq": maxi(0, after_seq)}
	var events: Array = events_any as Array
	var out: Array = []
	var latest_seq: int = maxi(0, after_seq)
	for e_any in events:
		if typeof(e_any) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_any as Dictionary
		var seq: int = int(e.get("seq", 0))
		if seq > latest_seq:
			latest_seq = seq
		if seq <= after_seq:
			continue
		out.append(e.duplicate(true))
	return {"ok": true, "events": out, "latest_seq": latest_seq}

func _session_has_player_uid(session: Dictionary, uid: String) -> bool:
	if session.is_empty():
		return false
	var target_uid: String = uid.strip_edges()
	if target_uid.is_empty():
		return false
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	return str(host.get("uid", "")) == target_uid or str(guest.get("uid", "")) == target_uid

func _new_session(host: Dictionary, context: Dictionary, source: String) -> Dictionary:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var session_id: String = _next_session_id()
	var invite_code: String = _next_invite_code()
	var host_copy: Dictionary = {
		"uid": str(host.get("uid", "")),
		"display_name": str(host.get("display_name", "Player 1")),
		"ready": false
	}
	if host.has("ticket_id"):
		host_copy["ticket_id"] = str(host.get("ticket_id", ""))
	return {
		"id": session_id,
		"invite_code": invite_code,
		"source": source,
		"context": context.duplicate(true),
		"created_unix": now_unix,
		"expires_unix": now_unix + SESSION_TTL_SEC,
		"status": "waiting",
		"host": host_copy,
		"guest": {
			"uid": "",
			"display_name": "",
			"ready": false
		},
		"close_reason": ""
	}

func _session_refresh_status(session: Dictionary) -> void:
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var guest_uid: String = str(guest.get("uid", ""))
	var host_ready: bool = bool(host.get("ready", false))
	var guest_ready: bool = bool(guest.get("ready", false))
	if guest_uid == "":
		session["status"] = "waiting"
		return
	if host_ready and guest_ready:
		session["status"] = "ready"
		return
	session["status"] = "matched"

func _contexts_compatible(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("mode", "")) == str(b.get("mode", "")) \
		and int(a.get("map_count", 0)) == int(b.get("map_count", 0)) \
		and int(a.get("price_usd", 0)) == int(b.get("price_usd", 0)) \
		and bool(a.get("free_roll", false)) == bool(b.get("free_roll", false))

func _normalize_profile(profile: Dictionary) -> Dictionary:
	var uid: String = str(profile.get("uid", "")).strip_edges()
	if uid.is_empty():
		return {}
	var display_name: String = str(profile.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = "Player"
	return {
		"uid": uid,
		"display_name": display_name
	}

func _is_session_live(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var status: String = str(session.get("status", ""))
	if status == "started":
		return true
	var now_unix: int = int(Time.get_unix_time_from_system())
	return now_unix <= int(session.get("expires_unix", 0))

func _close_session_internal(session_id: String, reason: String) -> void:
	if not _sessions.has(session_id):
		return
	var session: Dictionary = _sessions.get(session_id, {}) as Dictionary
	var code: String = str(session.get("invite_code", ""))
	session["status"] = "closed"
	session["close_reason"] = reason
	_emit_session_changed(session_id, session)
	_sessions.erase(session_id)
	_intent_streams.erase(session_id)
	if not code.is_empty() and _invite_to_session.get(code, "") == session_id:
		_invite_to_session.erase(code)

func _dup_session(session: Dictionary) -> Dictionary:
	return session.duplicate(true)

func _next_session_id() -> String:
	for _i in range(64):
		var sid: String = "S%08d" % int(_rng.randi() % 100000000)
		if not _sessions.has(sid):
			return sid
	return "S%08d" % int(Time.get_ticks_msec() % 100000000)

func _next_ticket_id() -> String:
	for _i in range(64):
		var tid: String = "Q%08d" % int(_rng.randi() % 100000000)
		var exists: bool = false
		for ticket_any in _queue:
			var ticket: Dictionary = ticket_any as Dictionary
			if str(ticket.get("id", "")) == tid:
				exists = true
				break
		if not exists:
			return tid
	return "Q%08d" % int(Time.get_ticks_msec() % 100000000)

func _next_invite_code() -> String:
	for _i in range(32):
		var code: String = "VS%05d" % int(_rng.randi() % 100000)
		if not _invite_to_session.has(code):
			return code
	return "VS%05d" % int(int(Time.get_unix_time_from_system()) % 100000)

func _next_bot_uid() -> String:
	return "bot_%06d" % int(_rng.randi() % 1000000)

func _emit_session_changed(session_id: String, session_override: Dictionary = {}) -> void:
	var payload: Dictionary = session_override
	if payload.is_empty():
		payload = _sessions.get(session_id, {}) as Dictionary
	emit_signal("session_changed", session_id, _dup_session(payload))

func _prune() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	for i in range(_queue.size() - 1, -1, -1):
		var ticket: Dictionary = _queue[i] as Dictionary
		if now_unix - int(ticket.get("created_unix", 0)) > QUEUE_TTL_SEC:
			_queue.remove_at(i)
	var remove_ids: Array[String] = []
	for sid_any in _sessions.keys():
		var sid: String = str(sid_any)
		var session: Dictionary = _sessions.get(sid, {}) as Dictionary
		if str(session.get("status", "")) == "started":
			continue
		if now_unix > int(session.get("expires_unix", 0)):
			remove_ids.append(sid)
	for sid in remove_ids:
		_close_session_internal(sid, "expired")
	emit_signal("queue_changed", _queue.size())
