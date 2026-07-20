extends SceneTree

const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"

var _failed: bool = false

func _init() -> void:
	OS.set_environment("SF_VS_BACKEND_URL", "")
	OS.set_environment("SF_VS_BACKEND_TOKEN", "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	await process_frame
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	var runtime: Node = get_root().get_node_or_null("VsPvpRuntime")
	if handshake == null or runtime == null:
		_fail("required autoloads are missing")
		quit(1)
		return
	handshake.call("_configure_transport")
	_test_menu_contract_options()
	_test_invite_contract(handshake, "CAPTURE_FLAG", 2)
	_test_invite_contract(handshake, "HIDDEN_CAPTURE_FLAG", 2)
	_test_invite_contract(handshake, "2V2", 4)
	_test_invite_contract(handshake, "3P FFA", 3)
	var four_player_session: Dictionary = _test_invite_contract(handshake, "4P FFA", 4)
	_test_runtime_accepts_every_remote_seat(handshake, runtime, four_player_session)
	_test_group_quick_match(handshake)
	if not _failed:
		print("NON_1V1_MULTIPLAYER_HANDSHAKE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_menu_contract_options() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_expect(source.contains("_open_human_pvp_lobby(\"CAPTURE_FLAG\"") and source.contains("_open_human_pvp_lobby(\"HIDDEN_CAPTURE_FLAG\""), "CTF menu routes use the shared PvP lobby", {})
	_expect(source.contains("func _human_pvp_required_players") and source.contains("\"2V2\", \"4P FFA\":") and source.contains("\"3P FFA\":"), "group menu routes derive 4/3/4 player contracts", {})
	_expect(source.contains("\"session_contract_version\": 2"), "human PvP menu requests roster contract v2", {})

func _test_invite_contract(handshake: Node, mode: String, required_players: int) -> Dictionary:
	handshake.call("clear")
	var invite: Dictionary = handshake.call("create_invite", _profile(mode, 1), {
		"mode": mode,
		"map_count": 1,
		"human_pvp": true,
		"free_roll": true,
		"required_players": 2
	}) as Dictionary
	_expect(bool(invite.get("ok", false)), "%s invite is created" % mode, invite)
	var session: Dictionary = invite.get("session", {}) as Dictionary
	_expect(int(session.get("contract_version", 0)) == 2, "%s uses roster contract v2" % mode, session)
	_expect(int(session.get("required_players", 0)) == required_players, "%s derives the correct seat count" % mode, session)
	_expect((session.get("roster", []) as Array).size() == 1, "%s starts with one canonical roster entry" % mode, session)
	var code: String = str(invite.get("invite_code", ""))
	for seat in range(2, required_players + 1):
		var joined: Dictionary = handshake.call("join_invite", code, _profile(mode, seat)) as Dictionary
		_expect(bool(joined.get("ok", false)), "%s seat %d can join" % [mode, seat], joined)
		session = joined.get("session", {}) as Dictionary
		_expect((session.get("roster", []) as Array).size() == seat, "%s roster reaches seat %d" % [mode, seat], session)
		var expected_status: String = "started" if seat == required_players else "waiting"
		_expect(str(session.get("status", "")) == expected_status, "%s has %s status at %d/%d" % [mode, expected_status, seat, required_players], session)
	_assert_roster(mode, session, required_players)
	var overflow: Dictionary = handshake.call("join_invite", code, _profile(mode, required_players + 1)) as Dictionary
	_expect(not bool(overflow.get("ok", false)) and str(overflow.get("err", "")) == "invite_full", "%s rejects a roster overflow" % mode, overflow)
	return session

func _test_group_quick_match(handshake: Node) -> void:
	handshake.call("clear")
	var context: Dictionary = {
		"mode": "3P FFA",
		"map_count": 1,
		"human_pvp": true,
		"free_roll": true,
		"required_players": 3
	}
	var first: Dictionary = handshake.call("enqueue_quick_match", _profile("quick", 1), context) as Dictionary
	var second: Dictionary = handshake.call("enqueue_quick_match", _profile("quick", 2), context) as Dictionary
	var third: Dictionary = handshake.call("enqueue_quick_match", _profile("quick", 3), context) as Dictionary
	_expect(bool(first.get("ok", false)) and not bool(first.get("matched", true)), "3P quick queue creates the first ticket", first)
	_expect(bool(second.get("matched", false)) and str((second.get("session", {}) as Dictionary).get("status", "")) == "waiting", "3P quick queue forms a partial waiting roster", second)
	_expect(bool(third.get("matched", false)) and str((third.get("session", {}) as Dictionary).get("status", "")) == "started", "3P quick queue starts only when the third player joins", third)
	var first_poll: Dictionary = handshake.call("poll_quick_match", str(first.get("ticket_id", ""))) as Dictionary
	_expect(bool(first_poll.get("matched", false)) and ((first_poll.get("session", {}) as Dictionary).get("roster", []) as Array).size() == 3, "first quick ticket resolves to the complete roster", first_poll)

func _test_runtime_accepts_every_remote_seat(handshake: Node, runtime: Node, session: Dictionary) -> void:
	if session.is_empty():
		_fail("4P runtime fixture session is empty")
		return
	var session_id: String = str(session.get("id", ""))
	var roster: Array = (session.get("roster", []) as Array).duplicate(true)
	for i in range(roster.size()):
		var entry: Dictionary = roster[i] as Dictionary
		entry["active"] = true
		entry["is_local"] = i == 0
		entry["is_cpu"] = false
		roster[i] = entry
	set_meta("vs_handshake_session_id", session_id)
	set_meta("vs_handshake_role", "host")
	set_meta("vs_mode", "4P FFA")
	set_meta("vs_required_players", 4)
	set_meta("vs_local_profile", (roster[0] as Dictionary).duplicate(true))
	runtime.call("configure_from_tree", self, roster)
	var snapshot: Dictionary = runtime.call("get_debug_snapshot") as Dictionary
	_expect(bool(snapshot.get("active", false)), "4P runtime activates from the canonical roster", snapshot)
	_expect((snapshot.get("remote_uids", PackedStringArray()) as PackedStringArray).size() == 3, "4P runtime tracks all three remote peers", snapshot)
	for seat in range(2, 5):
		var uid: String = str((roster[seat - 1] as Dictionary).get("uid", ""))
		var publish: Dictionary = handshake.call("publish_intent", session_id, uid, _lane_command(uid, seat)) as Dictionary
		_expect(bool(publish.get("ok", false)), "seat %d publishes through the shared intent contract" % seat, publish)
	runtime.call("_poll_remote_intents")
	var commands: Array = runtime.call("consume_remote_commands", 100) as Array
	var sender_seats: Array[int] = []
	for command_any in commands:
		if typeof(command_any) == TYPE_DICTIONARY:
			sender_seats.append(int((command_any as Dictionary).get("sender_seat", 0)))
	sender_seats.sort()
	_expect(sender_seats == [2, 3, 4], "runtime accepts commands from seats 2, 3, and 4", {"sender_seats": sender_seats, "commands": commands})
	runtime.call("clear")
	for key in ["vs_handshake_session_id", "vs_handshake_role", "vs_mode", "vs_required_players", "vs_local_profile"]:
		if has_meta(key):
			remove_meta(key)

func _assert_roster(mode: String, session: Dictionary, required_players: int) -> void:
	var roster: Array = session.get("roster", []) as Array
	var uids: Dictionary = {}
	for i in range(roster.size()):
		var player: Dictionary = roster[i] as Dictionary
		var uid: String = str(player.get("uid", ""))
		_expect(int(player.get("seat", 0)) == i + 1, "%s seat ordering is canonical" % mode, player)
		_expect(not uid.is_empty() and not uids.has(uid), "%s roster identities are unique" % mode, player)
		uids[uid] = true
		if mode == "2V2":
			var expected_team: int = 1 if i + 1 == 1 or i + 1 == 3 else 2
			_expect(int(player.get("team_id", 0)) == expected_team, "2V2 seat %d has immutable team %d" % [i + 1, expected_team], player)
	_expect(roster.size() == required_players, "%s final roster is complete" % mode, session)
	_expect(not str(session.get("contract_hash", "")).is_empty(), "%s contract hash is present" % mode, session)

func _profile(prefix: String, seat: int) -> Dictionary:
	var clean_prefix: String = prefix.to_lower().replace(" ", "_")
	return {"uid": "%s_p%d" % [clean_prefix, seat], "display_name": "%s P%d" % [prefix, seat]}

func _lane_command(uid: String, seat: int) -> Dictionary:
	return {
		"kind": "lane_intent",
		"contract_version": 1,
		"client_command_id": "%s-command" % uid,
		"issued_ms": Time.get_ticks_msec(),
		"issued_tick": 10,
		"local_issued_tick": 10,
		"issued_sim_us": 1_000_000,
		"requested_execute_tick": 13,
		"execute_tick": 13,
		"sender_seat": seat,
		"sender_uid": uid,
		"src": seat,
		"dst": 1,
		"intent": "attack",
		"src_owner": seat,
		"dst_owner": 1
	}

func _expect(condition: bool, message: String, details: Dictionary = {}) -> void:
	if condition:
		return
	_fail("%s | %s" % [message, str(details)])

func _fail(message: String) -> void:
	_failed = true
	push_error("NON_1V1_MULTIPLAYER_HANDSHAKE_SMOKE: %s" % message)
