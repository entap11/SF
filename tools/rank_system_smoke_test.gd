extends SceneTree

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const RankPanelScene: PackedScene = preload("res://scenes/ui/RankPanel.tscn")
const SMOKE_SAVE_PATH: String = "user://rank_state.smoke.json"
const SETTINGS_BACKEND_URL: String = "swarmfront/rank/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/rank/backend_token"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	# Keep smoke deterministic regardless of configured remote backend.
	ProjectSettings.set_setting(SETTINGS_BACKEND_URL, "")
	ProjectSettings.set_setting(SETTINGS_BACKEND_TOKEN, "")

	var state: Node = RankStateScript.new()
	state.set("save_path", SMOKE_SAVE_PATH)
	state.name = "RankState"
	get_root().add_child(state)
	await process_frame

	# Widen hysteresis in smoke so a single-rank move can validate anti-flicker.
	state._config.promotion_buffer = 0.02
	state._config.players_per_tier_to_unlock = 1

	for i in range(1, 102):
		var player_id: String = "p%03d" % i
		var display_name: String = "Player %03d" % i
		var register_result: Dictionary = state.intent_register_player(player_id, display_name, "NA", [])
		if not bool(register_result.get("ok", false)):
			_fail("register failed for %s" % player_id)
			return
		var wax_value: float = float(2000 - i)
		state.intent_debug_set_player_wax(player_id, wax_value)

	var local_id: String = "p051"
	state._local_player_id = local_id

	var tier_promotions: Array = []
	state.rank_event.connect(func(event: Dictionary) -> void:
		if str(event.get("type", "")) == "tier_promotion" and str(event.get("player_id", "")) == local_id:
			tier_promotions.append(event.duplicate(true))
	)

	var before_match: Dictionary = state.get_player_snapshot(local_id)
	var wax_before: float = float(before_match.get("wax_score", 0.0))
	var win_result: Dictionary = state.intent_record_match_result(local_id, "p090", true, "STANDARD", {})
	if not bool(win_result.get("ok", false)):
		_fail("match result intent failed")
		return
	var after_match: Dictionary = state.get_player_snapshot(local_id)
	if not is_equal_approx(float(after_match.get("wax_score", 0.0)), wax_before + 10.0):
		_fail("free pvp win should add exactly 10 wax")
		return

	var opponent_after_win: Dictionary = state.get_player_snapshot("p090")
	var opponent_wax_after_win: float = float(opponent_after_win.get("wax_score", 0.0))
	var loss_result: Dictionary = state.intent_record_match_result(local_id, "p090", false, "STANDARD", {})
	if not bool(loss_result.get("ok", false)):
		_fail("free pvp loss intent failed")
		return
	var after_loss: Dictionary = state.get_player_snapshot(local_id)
	if not is_equal_approx(float(after_loss.get("wax_score", 0.0)), float(after_match.get("wax_score", 0.0)) - 4.0):
		_fail("free pvp loss should subtract exactly 4 wax")
		return
	var opponent_after_loss: Dictionary = state.get_player_snapshot("p090")
	if not is_equal_approx(float(opponent_after_loss.get("wax_score", 0.0)), opponent_wax_after_win + 10.0):
		_fail("winner should gain exactly 10 wax in free pvp")
		return

	state.intent_debug_set_player_wax(local_id, 500.0)
	state.intent_debug_set_player_wax("p090", 500.0)
	var money_result: Dictionary = state.intent_record_match_result(local_id, "p090", true, "MONEY_MATCH", {}, 3)
	if not bool(money_result.get("ok", false)):
		_fail("money match result intent failed")
		return
	var after_money: Dictionary = state.get_player_snapshot(local_id)
	var opponent_after_money: Dictionary = state.get_player_snapshot("p090")
	if not is_equal_approx(float(after_money.get("wax_score", 0.0)), 520.0):
		_fail("money tier 3 win should add exactly 20 wax")
		return
	if not is_equal_approx(float(opponent_after_money.get("wax_score", 0.0)), 491.0):
		_fail("money tier 3 loss should subtract exactly 9 wax")
		return

	var contest_result: Dictionary = state.intent_record_contest_result(local_id, "WEEKLY", 1, {})
	if not bool(contest_result.get("ok", false)):
		_fail("contest result intent failed")
		return
	var after_contest: Dictionary = state.get_player_snapshot(local_id)
	if not is_equal_approx(float(after_contest.get("wax_score", 0.0)), 530.0):
		_fail("weekly contest first should add exactly 10 wax")
		return

	# Decay starts after 14 days; verify at day 15.
	var now_unix: int = int(Time.get_unix_time_from_system())
	state.intent_debug_set_last_active(local_id, now_unix - (15 * 86400))
	var before_decay: float = float(state.get_player_snapshot(local_id).get("wax_score", 0.0))
	state.intent_apply_decay_tick()
	var after_decay: float = float(state.get_player_snapshot(local_id).get("wax_score", 0.0))
	if after_decay >= before_decay:
		_fail("decay did not reduce wax at 15-day inactivity")
		return

	# Force a clear demotion then promotion; first-time promotion should only count once.
	state.intent_debug_set_player_wax(local_id, 100.0)
	var low_tier: Dictionary = state.get_player_snapshot(local_id)
	state.intent_debug_set_player_wax(local_id, 9999.0)
	var high_tier: Dictionary = state.get_player_snapshot(local_id)
	var low_idx: int = state._config.tier_index(str(low_tier.get("tier_id", "DRONE")))
	var high_idx: int = state._config.tier_index(str(high_tier.get("tier_id", "DRONE")))
	if high_idx <= low_idx:
		_fail("expected promotion to higher tier after large wax gain")
		return
	var first_promotion_count: int = _count_first_time_promotions(tier_promotions)
	if first_promotion_count < 1:
		_fail("first-time tier promotion event missing")
		return
	state.intent_debug_set_player_wax(local_id, 100.0)
	state.intent_debug_set_player_wax(local_id, 9999.0)
	if _count_first_time_promotions(tier_promotions) != first_promotion_count:
		_fail("tier promotion ceremony repeated after first achievement")
		return

	# Leaderboard ordering should reflect updated wax instantly.
	state.intent_debug_set_player_wax(local_id, 9999.0)
	var board: Dictionary = state.get_leaderboard_snapshot(local_id, "GLOBAL", 3)
	var rows_any: Variant = board.get("rows", [])
	if typeof(rows_any) != TYPE_ARRAY or (rows_any as Array).is_empty():
		_fail("leaderboard rows missing")
		return
	var first_row: Dictionary = (rows_any as Array)[0] as Dictionary
	if str(first_row.get("player_id", "")) != local_id:
		_fail("leaderboard did not reorder after wax update")
		return

	var panel_any: Variant = RankPanelScene.instantiate()
	if not (panel_any is Control):
		_fail("rank panel failed to instantiate")
		return
	var panel: Control = panel_any as Control
	get_root().add_child(panel)
	await process_frame
	panel.queue_free()

	print("RANK_SYSTEM_SMOKE: PASS")
	quit(0)

func _count_first_time_promotions(events: Array) -> int:
	var count: int = 0
	for event_any in events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		if bool(event.get("first_time", false)):
			count += 1
	return count

func _fail(message: String) -> void:
	push_error("RANK_SYSTEM_SMOKE: %s" % message)
	quit(1)
