extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

class FakeContestState:
	extends Node

	func build_stage_race_overall_leaderboard(_contest_id: String, _map_count: int = 5, _limit: int = 25) -> Array[Dictionary]:
		return [
			{"rank": 1, "player_id": "u_aaaaaaaaaaaa", "player_name": "Alpha"},
			{"rank": 2, "player_id": "bot_000001", "player_name": "Bot"}
		]

	func parse_contest_id(contest_id: String) -> Dictionary:
		var parts: PackedStringArray = contest_id.split("_")
		return {
			"scope": parts[0] if not parts.is_empty() else "",
			"time": parts[3] if parts.size() > 3 else ""
		}

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const RankRuntimeAwardsScript = preload("res://scripts/state/rank_runtime_awards.gd")
const ProfileManagerScript = preload("res://scripts/profile/profile_manager.gd")

const RANK_SAVE_PATH: String = "user://rank_runtime_awards.smoke.json"
const PROFILE_PATH: String = "user://profile.cfg"
const SETTINGS_BACKEND_URL: String = "swarmfront/rank/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/rank/backend_token"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RANK_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_TOKEN, "")

	var profile_manager: Node = ProfileManagerScript.new()
	profile_manager.name = "SmokeProfileManager"
	get_root().add_child(profile_manager)
	await process_frame
	profile_manager.set("_user_id", "u_aaaaaaaaaaaa")
	profile_manager.set("_display_name", "Alpha")
	profile_manager.set("_created_at_unix", int(Time.get_unix_time_from_system()))
	profile_manager.call("set_honey_balance", 0)

	var rank_state: Node = RankStateScript.new()
	rank_state.name = "SmokeRankState"
	rank_state.set("save_path", RANK_SAVE_PATH)
	get_root().add_child(rank_state)
	await process_frame

	_assert_ok(rank_state.call("intent_register_player", "u_aaaaaaaaaaaa", "Alpha", "NA", []) as Dictionary, "register local")
	_assert_ok(rank_state.call("intent_register_player", "bot_000001", "Bot", "NA", []) as Dictionary, "register bot")
	rank_state.call("intent_debug_set_player_wax", "u_aaaaaaaaaaaa", 200.0)
	rank_state.call("intent_debug_set_player_wax", "bot_000001", 200.0)

	var contest_state: Node = FakeContestState.new()
	contest_state.name = "SmokeContestState"
	get_root().add_child(contest_state)

	var runtime_awards: Node = RankRuntimeAwardsScript.new()
	runtime_awards.name = "SmokeRankRuntimeAwards"
	runtime_awards.set("rank_state_path", NodePath("/root/SmokeRankState"))
	runtime_awards.set("profile_manager_path", NodePath("/root/SmokeProfileManager"))
	runtime_awards.set("contest_state_path", NodePath("/root/SmokeContestState"))
	get_root().add_child(runtime_awards)
	await process_frame

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame

	set_meta("vs_mode", "1V1")
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("vs_assigned_players", [
		{"uid": "u_aaaaaaaaaaaa", "seat": 1},
		{"uid": "bot_000001", "seat": 2}
	])
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame

	var local_after_free: Dictionary = rank_state.call("get_player_snapshot", "u_aaaaaaaaaaaa") as Dictionary
	var opponent_after_free: Dictionary = rank_state.call("get_player_snapshot", "bot_000001") as Dictionary
	_assert_eq(int(round(float(local_after_free.get("wax_score", 0.0)))), 210, "runtime free pvp win should add 10 wax")
	_assert_eq(int(round(float(opponent_after_free.get("wax_score", 0.0)))), 196, "runtime free pvp loss should subtract 4 wax")

	rank_state.call("intent_debug_set_player_wax", "u_aaaaaaaaaaaa", 200.0)
	rank_state.call("intent_debug_set_player_wax", "bot_000001", 200.0)
	set_meta("vs_free_roll", false)
	set_meta("vs_price_usd", 5)
	remove_meta("rank_runtime_nonce")
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame

	var local_after_money: Dictionary = rank_state.call("get_player_snapshot", "u_aaaaaaaaaaaa") as Dictionary
	var opponent_after_money: Dictionary = rank_state.call("get_player_snapshot", "bot_000001") as Dictionary
	_assert_eq(int(round(float(local_after_money.get("wax_score", 0.0)))), 216, "runtime money tier 2 win should add 16 wax")
	_assert_eq(int(round(float(opponent_after_money.get("wax_score", 0.0)))), 193, "runtime money tier 2 loss should subtract 7 wax")

	var contest_result: Dictionary = runtime_awards.call("sync_contest_rank_rewards", "WEEKLY_USD_1_2025-W52", "WEEKLY", 5) as Dictionary
	_assert_ok(contest_result, "contest sync")
	var after_contest: Dictionary = rank_state.call("get_player_snapshot", "u_aaaaaaaaaaaa") as Dictionary
	_assert_eq(int(round(float(after_contest.get("wax_score", 0.0)))), 226, "contest sync should add weekly first-place wax")

	var now_local: Dictionary = Time.get_datetime_dict_from_system()
	var current_month_contest_id: String = "MONTHLY_USD_1_%04d-%02d" % [int(now_local.get("year", 1970)), int(now_local.get("month", 1))]
	var open_month_result: Dictionary = runtime_awards.call("sync_contest_rank_rewards", current_month_contest_id, "MONTHLY", 5) as Dictionary
	_assert_ok(open_month_result, "open monthly sync")
	_assert_true(not bool(open_month_result.get("awarded", false)), "current month should not award before month end")
	var after_open_month: Dictionary = rank_state.call("get_player_snapshot", "u_aaaaaaaaaaaa") as Dictionary
	_assert_eq(int(round(float(after_open_month.get("wax_score", 0.0)))), 226, "open monthly should not change wax")

	print("RANK_RUNTIME_AWARDS_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	push_error("RANK_RUNTIME_AWARDS_SMOKE: %s failed -> %s" % [label, result])
	quit(1)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("RANK_RUNTIME_AWARDS_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("RANK_RUNTIME_AWARDS_SMOKE: %s" % label)
	quit(1)
