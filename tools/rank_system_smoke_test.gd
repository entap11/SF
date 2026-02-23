extends SceneTree

const RankStateScript = preload("res://scripts/state/rank_state.gd")
const RankPanelScene: PackedScene = preload("res://scenes/ui/RankPanel.tscn")

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rank_state.json"))

	var state: Node = RankStateScript.new()
	state.name = "RankState"
	get_root().add_child(state)
	await process_frame

	# Widen hysteresis in smoke so a single-rank move can validate anti-flicker.
	state._config.promotion_buffer = 0.02

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
	if float(after_match.get("wax_score", 0.0)) <= wax_before:
		_fail("wax did not increase after win")
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

	# Put local at exact 50th percentile => Honey Bee (promotion event expected first time).
	state.intent_debug_set_player_wax(local_id, 1949.0)
	var at_boundary: Dictionary = state.get_player_snapshot(local_id)
	if str(at_boundary.get("tier_id", "")) != "HONEY_BEE":
		_fail("expected HONEY_BEE at 50th percentile boundary")
		return
	var first_promotion_count: int = _count_first_time_promotions(tier_promotions)
	if first_promotion_count < 1:
		_fail("first-time tier promotion event missing")
		return

	# Drop one rank (49th percentile). With 2% hysteresis, should remain HONEY_BEE.
	state.intent_debug_set_player_wax(local_id, 1948.5)
	var near_boundary: Dictionary = state.get_player_snapshot(local_id)
	if str(near_boundary.get("tier_id", "")) != "HONEY_BEE":
		_fail("promotion buffer failed; tier flickered too early")
		return

	# Drop further to force demotion below hysteresis floor.
	state.intent_debug_set_player_wax(local_id, 1935.0)
	var demoted: Dictionary = state.get_player_snapshot(local_id)
	if str(demoted.get("tier_id", "")) == "HONEY_BEE":
		_fail("expected demotion below HONEY_BEE after crossing buffered floor")
		return

	# Re-promote to Honey Bee; no second first-time ceremony should trigger.
	state.intent_debug_set_player_wax(local_id, 1949.0)
	var promoted_again: Dictionary = state.get_player_snapshot(local_id)
	if str(promoted_again.get("tier_id", "")) != "HONEY_BEE":
		_fail("failed to re-promote to HONEY_BEE")
		return
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
