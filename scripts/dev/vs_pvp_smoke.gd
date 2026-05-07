extends SceneTree

const HANDSHAKE_SCRIPT := preload("res://scripts/state/vs_handshake_state.gd")

const ENV_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/vs/backend_timeout_sec"
const SETTINGS_FORCE_RELEASE_GUARD_FOR_SMOKE: String = "swarmfront/vs/force_release_guard_for_smoke"

var _failed: bool = false

func _initialize() -> void:
	await _run()
	quit(1 if _failed else 0)

func _run() -> void:
	if _has_arg("--vs-smoke-release-guard"):
		await _run_release_guard_smoke()
		return
	var backend_url: String = _arg_value("--vs-smoke-backend-url=")
	if not backend_url.is_empty():
		ProjectSettings.set_setting(SETTINGS_BACKEND_URL, backend_url)
		ProjectSettings.set_setting(SETTINGS_BACKEND_TIMEOUT_SEC, 0.25)
	else:
		backend_url = OS.get_environment(ENV_BACKEND_URL).strip_edges()
	if backend_url.is_empty():
		_print_step("backend", "no backend configured, validating local fallback")
	else:
		_print_step("backend", "configured backend", {"url": backend_url})

	var handshake: Node = HANDSHAKE_SCRIPT.new()
	root.add_child(handshake)
	await process_frame

	var transport_mode: String = str(handshake.get("_transport_mode"))
	_print_step("handshake", "service ready", {"transport_mode": transport_mode})
	if not backend_url.is_empty():
		_expect(transport_mode == "http", "expected http transport mode when backend is configured", {
			"backend_url": backend_url,
			"transport_mode": transport_mode
		})
		if _failed:
			return

	var stamp: int = int(Time.get_unix_time_from_system())
	var host_uid: String = "smoke_host_%d" % stamp
	var guest_uid: String = "smoke_guest_%d" % stamp
	var host_profile: Dictionary = {"uid": host_uid, "display_name": "SmokeHost"}
	var guest_profile: Dictionary = {"uid": guest_uid, "display_name": "SmokeGuest"}
	var agreed_stage_map: String = "res://maps/json/MAP_TEST_8x12.json"
	var context: Dictionary = {
		"mode": "PVP",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true,
		"stage_map_paths": [agreed_stage_map]
	}

	var invite: Dictionary = handshake.call("create_invite", host_profile, context) as Dictionary
	_expect(bool(invite.get("ok", false)), "create_invite failed", invite)
	if _failed:
		return
	var session_id: String = str(invite.get("session_id", ""))
	var invite_code: String = str(invite.get("invite_code", ""))
	_expect(not session_id.is_empty(), "session_id missing", invite)
	_expect(not invite_code.is_empty(), "invite_code missing", invite)
	if _failed:
		return

	var join_result: Dictionary = handshake.call("join_invite", invite_code, guest_profile) as Dictionary
	_expect(bool(join_result.get("ok", false)), "join_invite failed", join_result)
	_expect(_session_stage_map(join_result) == agreed_stage_map, "joined session did not preserve stage map context", join_result)

	var host_ready: Dictionary = handshake.call("set_ready", session_id, host_uid, true) as Dictionary
	var guest_ready: Dictionary = handshake.call("set_ready", session_id, guest_uid, true) as Dictionary
	_expect(bool(host_ready.get("ok", false)), "host ready failed", host_ready)
	_expect(bool(guest_ready.get("ok", false)), "guest ready failed", guest_ready)

	var host_can_start: bool = bool(handshake.call("can_start", session_id, host_uid))
	var guest_can_start: bool = bool(handshake.call("can_start", session_id, guest_uid))
	_expect(host_can_start, "host should be allowed to start", {"session_id": session_id})
	_expect(not guest_can_start, "guest should not be allowed to start", {"session_id": session_id})

	var start_result: Dictionary = handshake.call("start_session", session_id, host_uid) as Dictionary
	_expect(bool(start_result.get("ok", false)), "start_session failed", start_result)
	_expect(_session_stage_map(start_result) == agreed_stage_map, "started session did not preserve stage map context", start_result)

	var host_lane_cmd: Dictionary = {
		"kind": "lane_intent",
		"src": 1,
		"dst": 2,
		"intent": "attack",
		"src_owner": 1,
		"dst_owner": 2,
		"issued_ms": Time.get_ticks_msec()
	}
	var publish_host: Dictionary = handshake.call("publish_intent", session_id, host_uid, host_lane_cmd) as Dictionary
	_expect(bool(publish_host.get("ok", false)), "host publish_intent failed", publish_host)

	var guest_poll: Dictionary = handshake.call("poll_intents", session_id, guest_uid, 0) as Dictionary
	_expect(bool(guest_poll.get("ok", false)), "guest poll_intents failed", guest_poll)
	var guest_events_any: Variant = guest_poll.get("events", [])
	_expect(typeof(guest_events_any) == TYPE_ARRAY, "guest poll events should be array", guest_poll)
	var guest_events: Array = guest_events_any as Array if typeof(guest_events_any) == TYPE_ARRAY else []
	_expect(_contains_command_from_uid(guest_events, host_uid, "lane_intent"), "guest did not receive host lane_intent", guest_poll)

	var guest_lane_cmd: Dictionary = {
		"kind": "lane_retract",
		"from_id": 2,
		"to_id": 1,
		"owner_id": 2,
		"issued_ms": Time.get_ticks_msec()
	}
	var publish_guest: Dictionary = handshake.call("publish_intent", session_id, guest_uid, guest_lane_cmd) as Dictionary
	_expect(bool(publish_guest.get("ok", false)), "guest publish_intent failed", publish_guest)

	var host_poll: Dictionary = handshake.call("poll_intents", session_id, host_uid, 0) as Dictionary
	_expect(bool(host_poll.get("ok", false)), "host poll_intents failed", host_poll)
	var host_events_any: Variant = host_poll.get("events", [])
	_expect(typeof(host_events_any) == TYPE_ARRAY, "host poll events should be array", host_poll)
	var host_events: Array = host_events_any as Array if typeof(host_events_any) == TYPE_ARRAY else []
	_expect(_contains_command_from_uid(host_events, guest_uid, "lane_retract"), "host did not receive guest lane_retract", host_poll)

	var leave_guest: Dictionary = handshake.call("leave_session", session_id, guest_uid) as Dictionary
	_expect(bool(leave_guest.get("ok", false)), "guest leave_session failed", leave_guest)
	var leave_host: Dictionary = handshake.call("leave_session", session_id, host_uid) as Dictionary
	_expect(bool(leave_host.get("ok", false)), "host leave_session failed", leave_host)

	if not _failed:
		_print_step("result", "PASS", {
			"session_id": session_id,
			"transport_mode": transport_mode,
			"guest_events": guest_events.size(),
			"host_events": host_events.size()
		})

func _run_release_guard_smoke() -> void:
	var blocked_backend_url: String = _arg_value("--vs-smoke-backend-url=")
	if blocked_backend_url.is_empty():
		blocked_backend_url = "http://127.0.0.1:8799/v1"
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, blocked_backend_url)
	ProjectSettings.set_setting(SETTINGS_BACKEND_TIMEOUT_SEC, 0.1)
	ProjectSettings.set_setting(SETTINGS_FORCE_RELEASE_GUARD_FOR_SMOKE, true)
	_print_step("release_guard", "validating fake multiplayer refusal", {"url": blocked_backend_url})

	var handshake: Node = HANDSHAKE_SCRIPT.new()
	root.add_child(handshake)
	await process_frame

	var blocker: String = ""
	if handshake.has_method("get_authoritative_transport_blocker"):
		blocker = str(handshake.call("get_authoritative_transport_blocker"))
	_expect(not blocker.strip_edges().is_empty(), "release guard should expose a user-facing blocker", {"blocker": blocker})
	_expect(not bool(handshake.call("is_authoritative_transport_online")), "release guard should not treat fake/local backend as authoritative", {
		"transport_mode": str(handshake.get_transport_mode()) if handshake.has_method("get_transport_mode") else str(handshake.get("_transport_mode"))
	})

	var result: Dictionary = handshake.call("create_invite", {"uid": "release_guard_host", "display_name": "Host"}, {
		"mode": "PVP",
		"map_count": 1,
		"price_usd": 0,
		"free_roll": true
	}) as Dictionary
	_expect(not bool(result.get("ok", false)), "release guard must refuse fake create_invite", result)
	_expect(bool(result.get("transport_error", false)), "release guard refusal should be a transport error", result)
	_expect(str(result.get("session_id", "")).is_empty(), "release guard must not create local session", result)
	if not _failed:
		_print_step("result", "PASS", {"blocker": blocker, "transport_mode": str(handshake.call("get_transport_mode"))})

func _contains_command_from_uid(events: Array, uid: String, kind: String) -> bool:
	for e_any in events:
		if typeof(e_any) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_any as Dictionary
		if str(e.get("uid", "")) != uid:
			continue
		var command_any: Variant = e.get("command", {})
		if typeof(command_any) != TYPE_DICTIONARY:
			continue
		if str((command_any as Dictionary).get("kind", "")) == kind:
			return true
	return false

func _session_stage_map(result: Dictionary) -> String:
	var session_any: Variant = result.get("session", {})
	if typeof(session_any) != TYPE_DICTIONARY:
		return ""
	var session: Dictionary = session_any as Dictionary
	var context_any: Variant = session.get("context", {})
	if typeof(context_any) != TYPE_DICTIONARY:
		return ""
	var context: Dictionary = context_any as Dictionary
	var paths_any: Variant = context.get("stage_map_paths", [])
	if typeof(paths_any) != TYPE_ARRAY:
		return ""
	var paths: Array = paths_any as Array
	if paths.is_empty():
		return ""
	return str(paths[0])

func _expect(condition: bool, message: String, details: Variant = null) -> void:
	if condition:
		return
	_failed = true
	if details == null:
		print("[VS_PVP_SMOKE][FAIL] %s" % message)
	else:
		print("[VS_PVP_SMOKE][FAIL] %s :: %s" % [message, str(details)])

func _print_step(step: String, message: String, details: Dictionary = {}) -> void:
	if details.is_empty():
		print("[VS_PVP_SMOKE][%s] %s" % [step, message])
		return
	print("[VS_PVP_SMOKE][%s] %s :: %s" % [step, message, str(details)])

func _arg_value(prefix: String) -> String:
	for arg in OS.get_cmdline_args():
		var value: String = str(arg)
		if not value.begins_with(prefix):
			continue
		return value.substr(prefix.length()).strip_edges()
	return ""

func _has_arg(flag: String) -> bool:
	for arg in OS.get_cmdline_args():
		if str(arg) == flag:
			return true
	return false
