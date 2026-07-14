extends SceneTree

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const LOCAL_ID: String = "018f2b2c-1234-7abc-8def-123456789abc"
const BOT_ID: String = "bot_000001"
const SAVE_PATH: String = "user://rank_local_award_calculation_debug.smoke.json"

var _failed: bool = false

func _init() -> void:
	await process_frame
	if not OS.is_debug_build():
		push_error("RANK_LOCAL_AWARD_CALCULATION_DEBUG_SMOKE: requires a debug build")
		quit(1)
		return
	OS.set_environment("SF_RANK_BACKEND_URL", "")
	ProjectSettings.set_setting("swarmfront/rank/backend_url", "")
	_force_local_rank_debug_fallback(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var rank_state: Node = RankStateScript.new()
	rank_state.set("save_path", SAVE_PATH)
	get_root().add_child(rank_state)
	await process_frame
	_expect(bool((rank_state.call("intent_register_player", LOCAL_ID, "Alpha", "NA", []) as Dictionary).get("ok", false)), "local registration failed")
	_expect(bool((rank_state.call("intent_register_player", BOT_ID, "Bot", "NA", []) as Dictionary).get("ok", false)), "bot registration failed")
	_expect(bool((rank_state.call("intent_debug_set_player_wax", LOCAL_ID, 200.0) as Dictionary).get("ok", false)), "local Wax fixture failed")
	_expect(bool((rank_state.call("intent_debug_set_player_wax", BOT_ID, 200.0) as Dictionary).get("ok", false)), "bot Wax fixture failed")
	var result: Dictionary = rank_state.call("intent_record_match_result", LOCAL_ID, BOT_ID, true, "STANDARD", {
		"event_id": "debug-calculation-match",
		"duration_sec": 60.0,
		"completed": true,
		"minimum_quality_met": true
	}, 0) as Dictionary
	_expect(bool(result.get("ok", false)), "debug match calculation failed: %s" % str(result))
	_expect(_wax(rank_state, LOCAL_ID) == 210, "debug match win calculation changed")
	_expect(_wax(rank_state, BOT_ID) == 196, "debug match loss calculation changed")
	var contest: Dictionary = rank_state.call("intent_record_contest_result", LOCAL_ID, "WEEKLY", 1, {"event_id": "debug-calculation-contest"}) as Dictionary
	_expect(bool(contest.get("ok", false)) and bool(contest.get("awarded", false)), "debug contest calculation failed: %s" % str(contest))
	_expect(_wax(rank_state, LOCAL_ID) == 220, "debug weekly first-place calculation changed")
	if not _failed:
		print("RANK_LOCAL_AWARD_CALCULATION_DEBUG_SMOKE: PASS")
	quit(1 if _failed else 0)

func _force_local_rank_debug_fallback(enabled: bool) -> void:
	var ops_config: Node = get_root().get_node_or_null("OpsConfig")
	if ops_config == null:
		return
	var snapshot: Dictionary = ops_config.call("get_config_snapshot") as Dictionary
	var flags: Dictionary = (snapshot.get("feature_flags", {}) as Dictionary).duplicate(true)
	flags["enable_rank_local_beta_fallback"] = enabled
	snapshot["feature_flags"] = flags
	ops_config.call("force_config_for_smoke", snapshot)

func _wax(rank_state: Node, player_id: String) -> int:
	return int(round(float((rank_state.call("get_player_snapshot", player_id) as Dictionary).get("wax_score", 0.0))))

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("RANK_LOCAL_AWARD_CALCULATION_DEBUG_SMOKE: %s" % message)
