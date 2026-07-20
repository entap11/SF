extends SceneTree

var _failed: bool = false

func _init() -> void:
	await process_frame
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	if handshake == null:
		_fail("VsHandshake autoload is missing", {})
		quit(1)
		return
	_test_token_gate(handshake)
	_test_canonical_roster_normalization(handshake)
	_test_canonical_bot_normalization(handshake)
	_test_public_ctf_mode_mapping(handshake)
	_test_invalid_contracts_fail_closed(handshake)
	_test_lobby_opt_in_is_explicit()
	if not _failed:
		print("DURABLE_PUBLIC_1V1_HANDSHAKE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_token_gate(handshake: Node) -> void:
	handshake.call("clear_player_access_token")
	var denied: Dictionary = handshake.call("enqueue_public_1v1", {}, {}) as Dictionary
	_expect(not bool(denied.get("ok", false)) and str(denied.get("err", "")) == "player_token_required",
		"durable queue requires a player token", denied)

func _test_canonical_roster_normalization(handshake: Node) -> void:
	var player_a: String = "0190f47a-1234-7abc-8def-123456789abc"
	var player_b: String = "0190f47a-2234-7abc-8def-123456789abc"
	var normalized: Dictionary = handshake.call("_normalize_public_session", {
		"protocol_version": 2,
		"match_id": "0190f47a-a234-7abc-8def-123456789abc",
		"required_players": 2,
		"host": {"uid": "forged-host"},
		"guest": {"uid": "forged-guest"},
		"roster": [
			{
				"player_id": player_a,
				"display_name": "Verified A",
				"seat_id": 1,
				"team_id": 1,
				"color_id": "GREEN",
				"ready_state": "READY",
				"ready": true,
				"connection_state": "CONNECTED"
			},
			{
				"player_id": player_b,
				"display_name": "Verified B",
				"seat_id": 2,
				"team_id": 2,
				"color_id": "PURPLE",
				"ready_state": "NOT_READY",
				"ready": false,
				"connection_state": "CONNECTED"
			}
		]
	}) as Dictionary
	var roster: Array = normalized.get("roster", []) as Array
	_expect(roster.size() == 2, "canonical roster is retained", normalized)
	if roster.size() != 2:
		return
	var first: Dictionary = roster[0] as Dictionary
	var second: Dictionary = roster[1] as Dictionary
	_expect(first.get("uid") == player_a and first.get("seat") == 1 and first.get("color_id") == "GREEN",
		"seat one aliases preserve server allocation", first)
	_expect(second.get("uid") == player_b and second.get("seat") == 2 and second.get("color_id") == "PURPLE",
		"seat two aliases preserve server allocation", second)
	_expect((normalized.get("host", {}) as Dictionary).get("uid") == player_a
		and (normalized.get("guest", {}) as Dictionary).get("uid") == player_b,
		"host/guest are derived from roster rather than trusted", normalized)

func _test_invalid_contracts_fail_closed(handshake: Node) -> void:
	var base: Dictionary = {
		"protocol_version": 2,
		"match_id": "0190f47a-a234-7abc-8def-123456789abc",
		"required_players": 2,
		"roster": [
			{"player_id": "0190f47a-1234-7abc-8def-123456789abc", "seat_id": 1},
			{"player_id": "0190f47a-2234-7abc-8def-123456789abc", "seat_id": 2}
		]
	}
	var old_protocol: Dictionary = base.duplicate(true)
	old_protocol["protocol_version"] = 1
	_expect((handshake.call("_normalize_public_session", old_protocol) as Dictionary).is_empty(),
		"roster-v1 contract is rejected", old_protocol)
	var forged_seat: Dictionary = base.duplicate(true)
	(forged_seat["roster"] as Array)[1]["seat_id"] = 1
	_expect((handshake.call("_normalize_public_session", forged_seat) as Dictionary).is_empty(),
		"duplicate/non-contiguous server seat is rejected", forged_seat)
	var missing_player: Dictionary = base.duplicate(true)
	(missing_player["roster"] as Array)[1]["player_id"] = ""
	_expect((handshake.call("_normalize_public_session", missing_player) as Dictionary).is_empty(),
		"roster without authenticated identity is rejected", missing_player)

func _test_canonical_bot_normalization(handshake: Node) -> void:
	var normalized: Dictionary = handshake.call("_normalize_public_session", {
		"protocol_version": 2,
		"match_id": "0190f47a-e234-7abc-8def-123456789abc",
		"required_players": 2,
		"roster": [
			{"player_id": "0190f47a-1234-7abc-8def-123456789abc", "uid": "forged", "seat_id": 1, "participant_type": "HUMAN"},
			{"player_id": null, "uid": "bot_ctf-practice-v1", "seat_id": 2, "participant_type": "BOT"}
		]
	}) as Dictionary
	var roster: Array = normalized.get("roster", []) as Array
	_expect(roster.size() == 2 and str((roster[1] as Dictionary).get("uid", "")) == "bot_ctf-practice-v1",
		"server canonical bot identity survives public contract normalization", normalized)

func _test_public_ctf_mode_mapping(handshake: Node) -> void:
	_expect(str(handshake.call("_public_duel_mode_id", {"mode": "CAPTURE_FLAG"})) == "CTF_1V1",
		"visible CTF selects its durable queue mode", {})
	_expect(str(handshake.call("_public_duel_mode_id", {"mode": "HIDDEN_CAPTURE_FLAG"})) == "HCTF_1V1",
		"hidden CTF selects its separately gated durable queue mode", {})

func _test_lobby_opt_in_is_explicit() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/vs_lobby.gd")
	_expect(source.contains("durable_public_1v1") and source.contains("enqueue_public_1v1")
		and source.contains("poll_public_1v1") and source.contains("cancel_public_1v1")
		and source.contains("get_public_bot_fallback_offer") and source.contains("accept_public_bot_fallback")
		and source.contains("Cancel Search"),
		"lobby has the disabled-by-default durable 1v1 seam", {})
	var handshake_source: String = FileAccess.get_file_as_string("res://scripts/state/vs_handshake_state.gd")
	_expect(handshake_source.contains("submit_public_1v1_terminal_report")
		and handshake_source.contains("get_public_1v1_result"),
		"handshake exposes terminal report/recovery seams", {})
	var arena_source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect(arena_source.contains("_submit_durable_terminal_report")
		and arena_source.contains("_poll_durable_verification_until_terminal"),
		"durable matches submit and recover their certified result from live gameplay", {})
	var rank_source: String = FileAccess.get_file_as_string("res://scripts/state/rank_runtime_awards.gd")
	_expect(rank_source.contains("durable_contract") and rank_source.contains("client_award_blocked")
		and rank_source.contains("vs_practice"),
		"durable and practice matches cannot enter the client rank award path", {})

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_fail(message, details)

func _fail(message: String, details: Dictionary) -> void:
	_failed = true
	push_error("DURABLE_PUBLIC_1V1_HANDSHAKE_SMOKE: %s :: %s" % [message, JSON.stringify(details)])
