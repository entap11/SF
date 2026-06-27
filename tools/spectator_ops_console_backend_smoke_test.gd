extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"
const DEFAULT_BACKEND_URL: String = "http://127.0.0.1:8791/v1"
const DEFAULT_BACKEND_TOKEN: String = "spectator_backend_smoke_token"

var _failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var backend_url: String = OS.get_environment("SF_VS_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = DEFAULT_BACKEND_URL
	var backend_token: String = OS.get_environment("SF_VS_BACKEND_TOKEN").strip_edges()
	if backend_token.is_empty():
		backend_token = DEFAULT_BACKEND_TOKEN
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, backend_url)
	ProjectSettings.set_setting(SETTINGS_BACKEND_TOKEN, backend_token)
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake == null:
		_fail("VsHandshake autoload missing")
		return
	if handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	if handshake.has_method("clear"):
		handshake.call("clear")
	_assert_eq(str(handshake.call("get_transport_mode")), "http", "spectator backend smoke requires HTTP transport")
	if _failed:
		return

	var stamp: int = Time.get_ticks_msec()
	var host_uid: String = "spectator_host_%d" % stamp
	var guest_uid: String = "spectator_guest_%d" % stamp
	var invite: Dictionary = handshake.call(
		"create_invite",
		{"uid": host_uid, "display_name": "Spectator Host"},
		{"mode": "PVP_SPECTATOR_E2E", "map_count": 1, "price_usd": 0, "free_roll": true}
	) as Dictionary
	_assert_ok(invite, "create spectator smoke invite")
	if _failed:
		return
	var join_result: Dictionary = handshake.call(
		"join_invite",
		str(invite.get("invite_code", "")),
		{"uid": guest_uid, "display_name": "Spectator Guest"}
	) as Dictionary
	_assert_ok(join_result, "join spectator smoke invite")
	if _failed:
		return
	var session_id: String = str(join_result.get("session_id", "")).strip_edges()
	var before_session: Dictionary = handshake.call("get_session", session_id) as Dictionary
	var before_signature: String = _session_signature(before_session)

	get_root().set_meta("ops_console_spectator_tab_only", true)
	var console_scene: PackedScene = load("res://scenes/ops/ops_console.tscn") as PackedScene
	if console_scene == null:
		_fail("ops console scene missing")
		return
	var console: Control = console_scene.instantiate() as Control
	if console == null:
		_fail("ops console instantiate failed")
		return
	get_root().add_child(console)
	await process_frame
	var spectate: Control = console.get_node_or_null("RootPanel/RootVBox/Tabs/Spectate") as Control
	if spectate == null:
		_fail("ops console Spectate tab missing")
		return
	var session_id_input: LineEdit = spectate.get_node_or_null("SpectateVBox/Session ID/SpectatorSessionId") as LineEdit
	var uid_input: LineEdit = spectate.get_node_or_null("SpectateVBox/Spectator UID/SpectatorUid") as LineEdit
	var live_check: CheckButton = spectate.get_node_or_null("SpectateVBox/SpectatorOptions/SpectatorLiveAdmin") as CheckButton
	var join_button: Button = spectate.get_node_or_null("SpectateVBox/SpectatorButtons/SpectatorJoin") as Button
	var poll_button: Button = spectate.get_node_or_null("SpectateVBox/SpectatorButtons/SpectatorPoll") as Button
	var events_text: TextEdit = spectate.get_node_or_null("SpectateVBox/SpectatorEvents") as TextEdit
	var map_view: Control = spectate.get_node_or_null("SpectateVBox/SpectatorMapView") as Control
	var status_label: Label = spectate.get_node_or_null("SpectateVBox/SpectatorStatus") as Label
	if session_id_input == null or uid_input == null or live_check == null or join_button == null or poll_button == null or events_text == null or map_view == null or status_label == null:
		_fail("ops console Spectate controls missing")
		return
	session_id_input.text = session_id
	uid_input.text = "ops_observer_%d" % stamp
	live_check.button_pressed = true
	join_button.pressed.emit()
	await process_frame
	if not status_label.text.contains("SPECTATING"):
		_fail("ops console did not join spectate: %s" % status_label.text)
		return

	var publish: Dictionary = handshake.call(
		"publish_intent",
		session_id,
		host_uid,
		{"kind": "lane_intent", "src": 1, "dst": 6, "intent": "attack", "issued_tick": 1}
	) as Dictionary
	_assert_ok(publish, "host publish spectator-visible intent")
	if _failed:
		return
	var visual_publish: Dictionary = handshake.call(
		"publish_spectator_snapshot",
		session_id,
		host_uid,
		_sample_visual_snapshot()
	) as Dictionary
	_assert_ok(visual_publish, "host publish spectator visual snapshot")
	if _failed:
		return
	poll_button.pressed.emit()
	await process_frame
	if not events_text.text.contains("lane_intent"):
		_fail("spectator event feed did not render lane intent: %s" % events_text.text)
		return
	if not map_view.has_method("frame_count") or int(map_view.call("frame_count")) < 1:
		_fail("spectator visual map did not render a replay frame")
		return
	if not status_label.text.contains("LIVE ADMIN"):
		_fail("spectator status should show live admin: %s" % status_label.text)
		return

	var after_session: Dictionary = handshake.call("get_session", session_id) as Dictionary
	_assert_eq(_session_signature(after_session), before_signature, "spectator flow must not alter host/guest session")
	if _failed:
		return
	handshake.call("leave_session", session_id, guest_uid)
	handshake.call("leave_session", session_id, host_uid)
	print("SPECTATOR_OPS_CONSOLE_BACKEND_SMOKE: PASS")
	quit(0)

func _session_signature(session: Dictionary) -> String:
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	return JSON.stringify({
		"status": str(session.get("status", "")),
		"host_uid": str(host.get("uid", "")),
		"host_ready": bool(host.get("ready", false)),
		"guest_uid": str(guest.get("uid", "")),
		"guest_ready": bool(guest.get("ready", false))
	})

func _sample_visual_snapshot() -> Dictionary:
	return {
		"frame_index": 0,
		"replay": {
			"map": {
				"hives": [[1, 0.0, 0.0, 1], [2, 100.0, 0.0, 2], [3, 50.0, 80.0, 0]],
				"lane_candidates": [[1, 2], [1, 3], [2, 3]]
			},
			"frames": [
				{
					"t": 0,
					"h": [[1, 1, 24], [2, 2, 22], [3, 0, 10]],
					"l": [[1, 1, 3, 1, 0]],
					"u": [[1, 1, 0.35, 6]]
				}
			]
		}
	}

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, str(result)])

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	_failed = true
	push_error("SPECTATOR_OPS_CONSOLE_BACKEND_SMOKE: %s" % message)
	quit(1)
