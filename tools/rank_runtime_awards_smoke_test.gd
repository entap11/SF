extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

class FakeContestState:
	extends Node

	func build_stage_race_overall_leaderboard(_contest_id: String, _map_count: int = 5, _limit: int = 25) -> Array[Dictionary]:
		return [{"rank": 1, "player_id": LOCAL_ID, "player_name": "Alpha"}]

	func parse_contest_id(contest_id: String) -> Dictionary:
		var parts: PackedStringArray = contest_id.split("_")
		return {"scope": parts[0] if not parts.is_empty() else "", "time": parts[3] if parts.size() > 3 else ""}

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const RankRuntimeAwardsScript = preload("res://scripts/state/rank_runtime_awards.gd")
const ProfileManagerScript = preload("res://scripts/profile/profile_manager.gd")

const LOCAL_ID: String = "018f2b2c-1234-7abc-8def-123456789abc"
const BOT_ID: String = "bot_000001"
const RANK_SAVE_PATH: String = "user://rank_runtime_awards_quarantine.smoke.json"
const PROFILE_PATH: String = "user://profile.cfg"

var _failed: bool = false

func _init() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RANK_SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	OS.set_environment("SF_RANK_BACKEND_URL", "")
	OS.set_environment("SF_RANK_BACKEND_TOKEN", "")
	OS.set_environment("SF_VS_BACKEND_URL", "")
	OS.set_environment("SF_VS_BACKEND_TOKEN", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_url", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_token", "")
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	ProjectSettings.set_setting("swarmfront/vs/backend_token", "")
	_force_local_rank_debug_fallback(false)

	var profile_manager: Node = ProfileManagerScript.new()
	profile_manager.name = "SmokeProfileManager"
	get_root().add_child(profile_manager)
	await process_frame
	profile_manager.call("smoke_force_identity_state", LOCAL_ID, "ABC 123", "Alpha", true, true)

	var rank_state: Node = RankStateScript.new()
	rank_state.name = "SmokeRankState"
	rank_state.set("save_path", RANK_SAVE_PATH)
	get_root().add_child(rank_state)
	await process_frame
	_assert_ok(rank_state.call("intent_register_player", LOCAL_ID, "Alpha", "NA", []) as Dictionary, "register local identity")
	_assert_ok(rank_state.call("intent_register_player", BOT_ID, "Bot", "NA", []) as Dictionary, "register bot identity")
	_seed_cached_wax(rank_state, LOCAL_ID, 200.0)
	_seed_cached_wax(rank_state, BOT_ID, 200.0)

	var direct_match: Dictionary = rank_state.call("intent_record_match_result", LOCAL_ID, BOT_ID, true, "STANDARD", {
		"event_id": "fabricated-runtime-award",
		"duration_sec": 60.0,
		"completed": true,
		"minimum_quality_met": true
	}, 0) as Dictionary
	_assert_quarantined(direct_match, "fabricated match award")
	_assert_cached_wax(rank_state, LOCAL_ID, 200, "fabricated match preserved local Wax")
	_assert_cached_wax(rank_state, BOT_ID, 200, "fabricated match preserved opponent Wax")

	var contest_result: Dictionary = rank_state.call("intent_record_contest_result", LOCAL_ID, "WEEKLY", 1, {
		"event_id": "fabricated-contest-award"
	}) as Dictionary
	_assert_quarantined(contest_result, "fabricated contest award")
	_assert_quarantined(rank_state.call("intent_apply_decay_tick") as Dictionary, "local decay")
	_assert_quarantined(rank_state.call("intent_debug_set_player_wax", LOCAL_ID, 999.0) as Dictionary, "local debug Wax")
	_assert_cached_wax(rank_state, LOCAL_ID, 200, "blocked local operations preserved cached Wax")

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
	runtime_awards.call("_connect_sim_runner", fake_runner)

	set_meta("vs_mode", "1V1")
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	set_meta("vs_price_usd", 0)
	set_meta("match_elapsed_ms", 60_000)
	set_meta("vs_assigned_players", [
		{"uid": LOCAL_ID, "seat": 1},
		{"uid": BOT_ID, "seat": 2}
	])
	fake_runner.emit_signal("match_ended", 1, "timeout")
	await process_frame
	_assert_cached_wax(rank_state, LOCAL_ID, 200, "runtime award preserved cached Wax")
	_expect(str(get_meta("canonical_wax_status", "")) == "quarantined", "runtime award did not expose quarantined status")
	_expect(int(round(float(get_meta("canonical_wax_delta", -1.0)))) == 0, "runtime quarantine fabricated a Wax delta")
	_expect(int(round(float(get_meta("canonical_wax_balance", 0.0)))) == 200, "runtime quarantine erased cached Wax")

	for key in ["canonical_wax_status", "canonical_wax_delta", "canonical_wax_balance"]:
		if has_meta(key):
			remove_meta(key)
	set_meta("vs_mode", "CAPTURE_FLAG")
	set_meta("practice", true)
	set_meta("ranked", false)
	fake_runner.emit_signal("match_ended", 1, "flag_capture")
	await process_frame
	_expect(not has_meta("canonical_wax_status"), "practice CTF reached the client rank mutation path")
	remove_meta("practice")
	remove_meta("ranked")

	var synced_contest: Dictionary = runtime_awards.call("sync_contest_rank_rewards", "WEEKLY_USD_1_2025-W52", "WEEKLY", 5) as Dictionary
	_assert_quarantined(synced_contest, "runtime contest award")
	_assert_cached_wax(rank_state, LOCAL_ID, 200, "runtime contest preserved cached Wax")

	if not _failed:
		print("RANK_RUNTIME_AWARDS_QUARANTINE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _force_local_rank_debug_fallback(enabled: bool) -> void:
	var ops_config: Node = get_root().get_node_or_null("OpsConfig")
	if ops_config == null or not ops_config.has_method("force_config_for_smoke"):
		return
	var snapshot: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	var flags: Dictionary = (snapshot.get("feature_flags", {}) as Dictionary).duplicate(true)
	flags["enable_rank_local_beta_fallback"] = enabled
	snapshot["feature_flags"] = flags
	ops_config.call("force_config_for_smoke", snapshot)

func _seed_cached_wax(rank_state: Node, player_id: String, wax: float) -> void:
	var players: Dictionary = rank_state.get("_players_by_id") as Dictionary
	var record: Dictionary = (players.get(player_id, {}) as Dictionary).duplicate(true)
	record["wax_score"] = wax
	players[player_id] = record
	rank_state.set("_players_by_id", players)

func _assert_cached_wax(rank_state: Node, player_id: String, expected: int, label: String) -> void:
	var player: Dictionary = rank_state.call("get_player_snapshot", player_id) as Dictionary
	_expect(int(round(float(player.get("wax_score", -1.0)))) == expected, label)

func _assert_quarantined(result: Dictionary, label: String) -> void:
	_expect(not bool(result.get("ok", true)), "%s unexpectedly succeeded" % label)
	_expect(str(result.get("code", result.get("err", result.get("reason", "")))) == "economy_disabled", "%s did not return stable economy_disabled: %s" % [label, str(result)])
	_expect(bool(result.get("cached_values_preserved", false)), "%s did not confirm cached preservation" % label)

func _assert_ok(result: Dictionary, label: String) -> void:
	_expect(bool(result.get("ok", false)), "%s failed: %s" % [label, str(result)])

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("RANK_RUNTIME_AWARDS_QUARANTINE_SMOKE: %s" % message)
