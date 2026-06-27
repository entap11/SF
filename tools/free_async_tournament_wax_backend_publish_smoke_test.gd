extends SceneTree

class FakeContestState:
	extends Node

	func build_stage_race_overall_leaderboard(_contest_id: String, _map_count: int = 5, _limit: int = 25) -> Array[Dictionary]:
		return [
			{"rank": 1, "player_id": "async_tournament_backend_player", "player_name": "Async Alpha"},
			{"rank": 2, "player_id": "async_tournament_bot", "player_name": "Bot"}
		]

	func parse_contest_id(_contest_id: String) -> Dictionary:
		return {"scope": "WEEKLY", "time": "2025-W52"}

class FakeProfileManager:
	extends Node

	func get_user_id() -> String:
		return "async_tournament_backend_player"

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const RankRuntimeAwardsScript = preload("res://scripts/state/rank_runtime_awards.gd")

const PLAYER_ID: String = "async_tournament_backend_player"
const CONTEST_ID: String = "WEEKLY_FREE_0_2025-W52"
const RANK_SAVE_PATH: String = "user://free_async_tournament_wax_backend_rank.json"
const SETTINGS_RANK_BACKEND_URL: String = "swarmfront/rank/backend_url"
const SETTINGS_RANK_BACKEND_TOKEN: String = "swarmfront/rank/backend_token"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RANK_SAVE_PATH))
	ProjectSettings.set_setting(SETTINGS_RANK_BACKEND_URL, "")
	ProjectSettings.set_setting(SETTINGS_RANK_BACKEND_TOKEN, "")
	await process_frame

	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	var crucible_state: Node = get_root().get_node_or_null("CrucibleState")
	if handshake == null or crucible_state == null:
		_fail("required autoload missing")
		return
	if str(handshake.call("get_transport_mode")) != "http":
		_fail("VsHandshake must be configured for HTTP backend")
		return
	if crucible_state.has_method("debug_reset_state"):
		crucible_state.call("debug_reset_state")

	var rank_state: Node = RankStateScript.new()
	rank_state.name = "AsyncTournamentSmokeRankState"
	rank_state.set("save_path", RANK_SAVE_PATH)
	get_root().add_child(rank_state)
	await process_frame
	_assert_ok(rank_state.call("intent_register_player", PLAYER_ID, "Async Alpha", "NA", []) as Dictionary, "register local player")
	rank_state.call("intent_debug_set_player_wax", PLAYER_ID, 200.0)

	var contest_state: Node = FakeContestState.new()
	contest_state.name = "AsyncTournamentSmokeContestState"
	get_root().add_child(contest_state)
	var profile_manager: Node = FakeProfileManager.new()
	profile_manager.name = "AsyncTournamentSmokeProfileManager"
	get_root().add_child(profile_manager)

	var runtime_awards: Node = RankRuntimeAwardsScript.new()
	runtime_awards.name = "AsyncTournamentSmokeRuntimeAwards"
	runtime_awards.set("rank_state_path", NodePath("/root/AsyncTournamentSmokeRankState"))
	runtime_awards.set("profile_manager_path", NodePath("/root/AsyncTournamentSmokeProfileManager"))
	runtime_awards.set("contest_state_path", NodePath("/root/AsyncTournamentSmokeContestState"))
	get_root().add_child(runtime_awards)
	await process_frame

	var result: Dictionary = runtime_awards.call("sync_contest_rank_rewards", CONTEST_ID, "WEEKLY", 5) as Dictionary
	_assert_ok(result, "sync contest rank rewards")
	var wax_result: Dictionary = result.get("competitive_wax_result", {}) as Dictionary
	_assert_ok(wax_result, "publish tournament Wax")
	_assert_eq(int(wax_result.get("balance_millis", 0)), 25000, "weekly champion Wax balance")

	var snapshot: Dictionary = handshake.call("debug_get_crucible_snapshot") as Dictionary
	_assert_ok(snapshot, "fetch backend Crucible snapshot")
	var ledger: Dictionary = snapshot.get("ledger", {}) as Dictionary
	var balances: Dictionary = ledger.get("balances_by_player", {}) as Dictionary
	_assert_eq(int(balances.get(PLAYER_ID, 0)), 25000, "backend tournament Wax balance")
	var awards: Dictionary = ledger.get("competitive_wax_awards_by_event", {}) as Dictionary
	if not awards.has("competitive_wax:contest:%s:%s" % [CONTEST_ID, PLAYER_ID]):
		_fail("backend ledger missing tournament Wax award")
		return
	print("FREE_ASYNC_TOURNAMENT_WAX_BACKEND_PUBLISH_SMOKE: PASS")
	quit(0)

func _assert_ok(result: Dictionary, label: String) -> void:
	if bool(result.get("ok", false)):
		return
	_fail("%s failed: %s" % [label, JSON.stringify(result)])

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	_fail("%s expected %d got %d" % [label, expected, actual])

func _fail(message: String) -> void:
	push_error(message)
	print("FREE_ASYNC_TOURNAMENT_WAX_BACKEND_PUBLISH_SMOKE: FAIL %s" % message)
	quit(1)
