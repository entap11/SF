extends SceneTree

const ScholasticStateScript = preload("res://scripts/state/scholastic_state.gd")

func _init() -> void:
	var state: Node = ScholasticStateScript.new()
	state.save_path = "user://scholastic_smoke_test.json"
	get_root().add_child(state)
	await process_frame
	_assert_ok(state.call("intent_report_age", "p01", 16, "Alpha"), "minor age reports into SFA")
	_assert_ok(state.call("intent_register_high_school", "p01", {
		"school_id": "demo_high",
		"school_name": "Demo High",
		"city": "San Francisco",
		"state": "CA",
		"mascot_name": "Stingers",
		"colors": ["Gold", "Black"]
	}), "register high school")
	for index: int in range(2, 26):
		var player_id: String = "p%02d" % index
		_assert_ok(state.call("intent_report_age", player_id, 16, "Player %02d" % index), "minor profile %s" % player_id)
		_assert_ok(state.call("intent_join_school_program", player_id, "demo_high"), "join school %s" % player_id)
		var mmr: float = 1000.0 + float(index)
		if index == 25:
			mmr = 5000.0
		_assert_ok(state.call("intent_update_player_competitive_profile", player_id, {"mmr": mmr, "tier_index": 1, "rank_position": index}), "rank update %s" % player_id)
	var p01_comms: Dictionary = state.call("get_communication_access", "p01") as Dictionary
	_assert_true(not bool(p01_comms.get("dm_enabled", true)), "SFA DM disabled")
	_assert_true(not bool(p01_comms.get("in_game_chat_enabled", true)), "SFA chat disabled")
	_assert_true(not bool(p01_comms.get("voice_enabled", true)), "SFA voice disabled")
	var p01_money: Dictionary = state.call("get_real_money_prize_access", "p01") as Dictionary
	_assert_true(not bool(p01_money.get("can_win_real_money", true)), "SFA real money prizes disabled")
	var school: Dictionary = state.call("get_school_program_snapshot", "demo_high") as Dictionary
	var teams: Array = school.get("teams", []) as Array
	_assert_true(teams.size() == 3, "25 eligible players create Varsity/JV/JVII")
	_assert_true(str((teams[0] as Dictionary).get("team_label", "")) == "Varsity", "team 0 Varsity")
	_assert_true(str((teams[1] as Dictionary).get("team_label", "")) == "JV", "team 1 JV")
	_assert_true(str((teams[2] as Dictionary).get("team_label", "")) == "JVII", "team 2 JVII")
	var p25: Dictionary = state.call("get_player_profile_snapshot", "p25") as Dictionary
	var sfa25: Dictionary = p25.get("sfa", {}) as Dictionary
	_assert_true(str(sfa25.get("team_label", "")) == "Varsity", "MMR sorting can move late signup to Varsity")
	_assert_ok(state.call("intent_update_recruiting_status", "p01", "SFA_RECRUITABLE"), "minor safe recruiting status")
	var recruiting: Dictionary = state.call("get_safe_recruiting_profile", "p01") as Dictionary
	_assert_true(not recruiting.has("email"), "safe profile excludes email")
	_assert_true(not recruiting.has("phone"), "safe profile excludes phone")
	_assert_ok(state.call("intent_create_sfa_tournament", "regional_demo", "REGIONAL", "Regional Demo"), "SFA regional tournament")
	var bad_result: Dictionary = state.call("intent_record_sfa_tournament_result", "p01", {"tournament_type": "REGIONAL", "is_money_game": true}) as Dictionary
	_assert_true(not bool(bad_result.get("ok", true)), "money game cannot count for SFA progression")
	print("scholastic_scaffolding_smoke_test: PASS")
	quit(0)

func _assert_ok(result_any: Variant, label: String) -> void:
	var result: Dictionary = result_any as Dictionary
	_assert_true(bool(result.get("ok", false)), label)

func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("Assertion failed: %s" % label)
	quit(1)
