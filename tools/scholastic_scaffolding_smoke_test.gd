extends SceneTree

const ScholasticStateScript = preload("res://scripts/state/scholastic_state.gd")

func _init() -> void:
	var state: Node = ScholasticStateScript.new()
	state.save_path = "user://scholastic_smoke_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.save_path))
	var school_year: String = "2026-2027"
	var freshman_year: String = "2026-2027"
	get_root().add_child(state)
	await process_frame
	var age_result: Dictionary = state.call("intent_report_age", "p01", 16, "Alpha") as Dictionary
	_assert_ok(age_result, "minor age reports into SFA")
	var age_sfa: Dictionary = (age_result.get("profile", {}) as Dictionary).get("sfa", {}) as Dictionary
	_assert_true(not bool(age_sfa.get("is_user", true)), "SFA requires school enrollment attestation before active membership")
	_assert_ok(state.call("intent_register_high_school", "p01", {
		"school_id": "demo_high",
		"school_name": "Demo High",
		"city": "San Francisco",
		"state": "CA",
		"mascot_name": "Stingers",
		"colors": ["Gold", "Black"],
		"attested_enrolled": true,
		"school_year": school_year,
		"freshman_school_year": freshman_year
	}), "register high school")
	var p01_after_join: Dictionary = state.call("get_player_profile_snapshot", "p01") as Dictionary
	var p01_sfa_after_join: Dictionary = p01_after_join.get("sfa", {}) as Dictionary
	var analytics_entitlements: Array = p01_sfa_after_join.get("analytics_package_entitlements", []) as Array
	_assert_true(analytics_entitlements.has("analytics_pack_tier_1"), "active SFA student receives tier 1 analytics pack entitlement")
	for index: int in range(2, 26):
		var player_id: String = "p%02d" % index
		_assert_ok(state.call("intent_report_age", player_id, 16, "Player %02d" % index), "minor profile %s" % player_id)
		_assert_ok(state.call("intent_join_school_program", player_id, "demo_high", {
			"attested_enrolled": true,
			"school_year": school_year,
			"freshman_school_year": freshman_year
		}), "join school %s" % player_id)
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
	_assert_ok(state.call("intent_review_school_hive", "demo_high", true, {
		"canonical_school_name": "Demo High",
		"school_year": school_year
	}), "approved school hive review")
	var approved_school: Dictionary = state.call("get_school_program_snapshot", "demo_high") as Dictionary
	_assert_true(bool(approved_school.get("hive_bonus_eligible", false)), "approved hive with full roster attestation earns hive bonus")
	_assert_true(str(approved_school.get("public_school_name", "")) == "Demo High", "approved hive can expose canonical school name")
	_assert_ok(state.call("intent_report_age", "p26", 16, "Player 26"), "minor profile p26")
	var invalid_attestation: Dictionary = state.call("intent_attest_school_enrollment", "p26", "demo_high", "2030-2031", freshman_year) as Dictionary
	_assert_true(not bool(invalid_attestation.get("ok", true)), "SFA four school year window blocks fifth-year attestation")
	_assert_ok(state.call("intent_update_recruiting_status", "p01", "SFA_RECRUITABLE"), "minor safe recruiting status")
	var recruiting: Dictionary = state.call("get_safe_recruiting_profile", "p01") as Dictionary
	_assert_true(not recruiting.has("email"), "safe profile excludes email")
	_assert_true(not recruiting.has("phone"), "safe profile excludes phone")
	_assert_ok(state.call("intent_file_school_enrollment_complaint", "p02", "p01", "not enrolled this school year"), "school enrollment complaint")
	var disputed_school: Dictionary = state.call("get_school_program_snapshot", "demo_high") as Dictionary
	_assert_true(not bool(disputed_school.get("hive_bonus_eligible", true)), "open material dispute pauses hive bonus")
	_assert_ok(state.call("intent_create_sfa_tournament", "regional_demo", "REGIONAL", "Regional Demo"), "SFA regional tournament")
	var bad_result: Dictionary = state.call("intent_record_sfa_tournament_result", "p01", {"tournament_type": "REGIONAL", "is_money_game": true}) as Dictionary
	_assert_true(not bool(bad_result.get("ok", true)), "money game cannot count for SFA progression")
	_assert_ok(state.call("intent_register_college_program", {
		"college_program_id": "demo_u",
		"university_name": "Demo University",
		"program_type": "COLLEGE",
		"city": "San Francisco",
		"state": "CA"
	}), "register SFU program")
	var minor_sfu_join: Dictionary = state.call("intent_join_college_program", "p01", "demo_u", {
		"attested_affiliated": true,
		"school_year": school_year
	}) as Dictionary
	_assert_true(not bool(minor_sfu_join.get("ok", true)), "minor cannot join SFU")
	_assert_ok(state.call("intent_report_age", "adult01", 19, "Adult One"), "adult age report")
	_assert_ok(state.call("intent_join_college_program", "adult01", "demo_u", {
		"attested_affiliated": true,
		"school_year": school_year
	}), "adult joins SFU")
	var adult_comms: Dictionary = state.call("get_communication_access", "adult01") as Dictionary
	_assert_true(bool(adult_comms.get("dm_enabled", false)), "SFU adult DMs enabled")
	_assert_true(bool(adult_comms.get("voice_enabled", false)), "SFU adult voice enabled")
	var adult_money: Dictionary = state.call("get_real_money_prize_access", "adult01") as Dictionary
	_assert_true(bool(adult_money.get("can_win_real_money", false)), "SFU adult can use normal money games")
	_assert_ok(state.call("intent_create_sfu_tournament", "campus_no_buffs", "CAMPUS", "Campus No Buffs", {
		"buffs_allowed": false,
		"cash_prizes_allowed": false
	}), "create no-buff SFU tournament")
	var sfu_buff_result: Dictionary = state.call("intent_record_sfu_tournament_result", "adult01", "campus_no_buffs", {
		"buffs_used": true,
		"awards_real_money": false
	}) as Dictionary
	_assert_true(not bool(sfu_buff_result.get("ok", true)), "no-buff SFU tournament rejects buff result")
	_assert_ok(state.call("intent_create_sfu_tournament", "campus_buff_open", "OPEN", "Campus Buff Open", {
		"buffs_allowed": true,
		"cash_prizes_allowed": true
	}), "create buff-enabled SFU tournament")
	_assert_ok(state.call("intent_record_sfu_tournament_result", "adult01", "campus_buff_open", {
		"buffs_used": true,
		"awards_real_money": true
	}), "buff-enabled SFU tournament accepts adult buff cash result")
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
