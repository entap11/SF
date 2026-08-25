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
	var force_local: bool = _has_arg("--vs-smoke-local")
	var backend_url: String = _arg_value("--vs-smoke-backend-url=")
	if force_local:
		ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
		backend_url = ""
	elif not backend_url.is_empty():
		ProjectSettings.set_setting(SETTINGS_BACKEND_URL, backend_url)
		ProjectSettings.set_setting(SETTINGS_BACKEND_TIMEOUT_SEC, 30.0)
	else:
		backend_url = OS.get_environment(ENV_BACKEND_URL).strip_edges()
		if backend_url.is_empty() and ProjectSettings.has_setting(SETTINGS_BACKEND_URL):
			backend_url = str(ProjectSettings.get_setting(SETTINGS_BACKEND_URL, "")).strip_edges()
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
	var agreed_stage_map: String = "res://maps/_future/nomansland/MAP_nomansland__545__v01_top2_sides__1p.json"
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
	_expect(_session_status(join_result) == "started", "joined session did not auto-start", join_result)

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

	await _run_quick_match_smoke(handshake, context, stamp)
	if _failed:
		return
	await _run_friend_invite_smoke(handshake, context, stamp)
	if _failed:
		return

	if not _failed:
		_print_step("result", "PASS", {
			"session_id": session_id,
			"transport_mode": transport_mode,
			"guest_events": guest_events.size(),
			"host_events": host_events.size()
		})

func _run_quick_match_smoke(handshake: Node, context: Dictionary, stamp: int) -> void:
	var p1_uid: String = "smoke_quick_a_%d" % stamp
	var p2_uid: String = "smoke_quick_b_%d" % stamp
	var p1: Dictionary = {"uid": p1_uid, "display_name": "QuickA", "tier_id": "WORKER", "rank_position": 100}
	var p2: Dictionary = {"uid": p2_uid, "display_name": "QuickB", "tier_id": "WORKER", "rank_position": 101}
	var first: Dictionary = handshake.call("enqueue_quick_match", p1, context) as Dictionary
	_expect(bool(first.get("ok", false)), "quick enqueue first failed", first)
	_expect(not bool(first.get("matched", false)), "quick first should wait for match", first)
	var ticket_id: String = str(first.get("ticket_id", ""))
	_expect(not ticket_id.is_empty(), "quick first ticket missing", first)
	if _failed:
		return
	var second: Dictionary = handshake.call("enqueue_quick_match", p2, context) as Dictionary
	_expect(bool(second.get("ok", false)), "quick enqueue second failed", second)
	_expect(bool(second.get("matched", false)), "quick second did not match", second)
	var quick_session_id: String = str(second.get("session_id", ""))
	_expect(not quick_session_id.is_empty(), "quick session missing", second)
	_expect(_session_status(second) == "started", "quick match did not auto-start", second)
	var poll: Dictionary = handshake.call("poll_quick_match", ticket_id) as Dictionary
	_expect(bool(poll.get("ok", false)), "quick poll failed", poll)
	_expect(bool(poll.get("matched", false)), "quick poll did not resolve first ticket", poll)
	_expect(str(poll.get("session_id", "")) == quick_session_id, "quick poll returned wrong session", poll)
	if not quick_session_id.is_empty():
		handshake.call("leave_session", quick_session_id, p2_uid)
		handshake.call("leave_session", quick_session_id, p1_uid)

func _run_friend_invite_smoke(handshake: Node, context: Dictionary, stamp: int) -> void:
	var friend_a_uid: String = "smoke_friend_a_%d" % stamp
	var friend_b_uid: String = "smoke_friend_b_%d" % stamp
	var friend_a: Dictionary = {"uid": friend_a_uid, "display_name": "FriendA"}
	var friend_b: Dictionary = {"uid": friend_b_uid, "display_name": "FriendB"}
	var heartbeat: Dictionary = handshake.call("heartbeat", friend_a) as Dictionary
	_expect(bool(heartbeat.get("ok", false)), "friend heartbeat failed", heartbeat)
	var online: Dictionary = handshake.call("list_online_friends", friend_b_uid, [friend_a_uid]) as Dictionary
	_expect(bool(online.get("ok", false)), "friend list failed", online)
	var online_any: Variant = online.get("online", [])
	_expect(typeof(online_any) == TYPE_ARRAY and (online_any as Array).size() == 1, "friend presence missing", online)
	var invite: Dictionary = handshake.call("create_friend_invite", friend_a, friend_b_uid, context) as Dictionary
	_expect(bool(invite.get("ok", false)), "create_friend_invite failed", invite)
	var invite_dict: Dictionary = invite.get("invite", {}) as Dictionary
	var invite_id: String = str(invite_dict.get("id", ""))
	_expect(not invite_id.is_empty(), "friend invite id missing", invite)
	var pending: Dictionary = handshake.call("poll_friend_invites", friend_b_uid) as Dictionary
	_expect(bool(pending.get("ok", false)), "poll_friend_invites failed", pending)
	var pending_any: Variant = pending.get("invites", [])
	_expect(typeof(pending_any) == TYPE_ARRAY and (pending_any as Array).size() >= 1, "friend invite not visible to target", pending)
	var accepted: Dictionary = handshake.call("respond_friend_invite", invite_id, friend_b, true) as Dictionary
	_expect(bool(accepted.get("ok", false)), "respond_friend_invite accept failed", accepted)
	_expect(bool(accepted.get("accepted", false)), "friend invite was not accepted", accepted)
	_expect(_session_status(accepted) == "started", "friend invite did not auto-start", accepted)
	var friend_session_id: String = str(accepted.get("session_id", ""))
	if not friend_session_id.is_empty():
		handshake.call("leave_session", friend_session_id, friend_b_uid)
		handshake.call("leave_session", friend_session_id, friend_a_uid)

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

func _session_status(result: Dictionary) -> String:
	var session_any: Variant = result.get("session", {})
	if typeof(session_any) != TYPE_DICTIONARY:
		return ""
	return str((session_any as Dictionary).get("status", ""))

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
