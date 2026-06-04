extends SceneTree

const SMOKE_SAVE_PATH: String = "user://stage_race_finish_leaderboard_handoff_smoke.json"
const CONTEST_ID: String = "WEEKLY_FREE_0_2025-W52"
const PLAYER_ID: String = "finish_handoff_player"
const PLAYER_NAME: String = "Finish Handoff"
const RUN_ID: String = "finish_handoff_run"
const RUN_ID_3_MAP: String = "finish_handoff_run_3_map"
const RUN_ID_3_MAP_BEST: String = "finish_handoff_run_3_map_best"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	var contest_state: Node = get_root().get_node_or_null("ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	contest_state.call("debug_set_runtime_leaderboard_save_path", SMOKE_SAVE_PATH)
	contest_state.call("debug_reset_runtime_leaderboards")
	var contest: ContestDef = contest_state.call("get_contest", CONTEST_ID) as ContestDef
	if contest == null:
		_fail("contest missing")
		return
	if contest.map_ids.size() < 3:
		_fail("contest needs at least three maps")
		return

	var main_menu_scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if main_menu_scene == null:
		_fail("MainMenu scene missing")
		return
	if contest.map_ids.size() >= 5:
		if not _record_run(contest_state, contest, 5, RUN_ID, 700):
			return
		set_meta("pending_stage_leaderboard_open", true)
		set_meta("pending_stage_leaderboard_context", {
			"contest_id": CONTEST_ID,
			"scope": "WEEKLY",
			"map_count": 5,
			"paid": false,
			"denomination": 0,
			"player_id": PLAYER_ID,
			"run_id": RUN_ID
		})
		var menu: Node = main_menu_scene.instantiate()
		get_root().add_child(menu)
		await process_frame
		await process_frame
		await process_frame
		if not _assert_highlighted_modal(menu, "finish handoff"):
			return

	contest_state.call("debug_reset_runtime_leaderboards")
	if not _record_run(contest_state, contest, 3, RUN_ID_3_MAP, 800):
		return
	if not _record_run(contest_state, contest, 3, RUN_ID_3_MAP_BEST, 600):
		return
	set_meta("pending_stage_leaderboard_open", true)
	set_meta("pending_stage_leaderboard_context", {
		"contest_id": CONTEST_ID,
		"scope": "WEEKLY",
		"map_count": 3,
		"paid": false,
		"denomination": 0,
		"player_id": PLAYER_ID,
		"run_id": RUN_ID_3_MAP
	})
	var menu_three: Node = main_menu_scene.instantiate()
	get_root().add_child(menu_three)
	await process_frame
	await process_frame
	await process_frame
	if not _assert_highlighted_modal(menu_three, "3-map finish handoff"):
		return
	contest_state.call("debug_reset_runtime_leaderboards")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	print("STAGE_RACE_FINISH_LEADERBOARD_HANDOFF_SMOKE: PASS")
	quit(0)

func _record_run(contest_state: Node, contest: ContestDef, map_count: int, run_id: String, base_time_ms: int) -> bool:
	for i in range(map_count):
		var result: Dictionary = contest_state.call("record_stage_race_map_result", CONTEST_ID, str(contest.map_ids[i]), {
			"player_id": PLAYER_ID,
			"player_name": PLAYER_NAME,
			"best_time_ms": base_time_ms + i,
			"run_id": run_id,
			"stage_index": i,
			"source": "finish_handoff_smoke"
		}) as Dictionary
		if not bool(result.get("ok", false)):
			_fail("result write failed: %s" % str(result))
			return false
	return true

func _assert_highlighted_modal(menu: Node, label: String) -> bool:
	var modal: Control = menu.get("_entry_route_modal") as Control
	if modal == null or not modal.visible:
		_fail("%s did not open leaderboard modal" % label)
		return false
	var highlighted: Control = _find_highlighted_row(modal)
	if highlighted == null:
		_fail("%s did not highlight the player's top-10 row" % label)
		return false
	var highlighted_name: Label = _find_highlighted_name(modal)
	if highlighted_name == null:
		_fail("%s did not mark name-level highlight" % label)
		return false
	if not bool(highlighted_name.get_meta("stage_leaderboard_emitting", false)):
		_fail("%s did not start name-level pulse/emitter" % label)
		return false
	return true

func _find_highlighted_row(root: Node) -> Control:
	if root is Control and bool((root as Control).get_meta("stage_leaderboard_highlighted", false)):
		return root as Control
	for child in root.get_children():
		var found: Control = _find_highlighted_row(child)
		if found != null:
			return found
	return null

func _find_highlighted_name(root: Node) -> Label:
	if root is Label and bool((root as Label).get_meta("stage_leaderboard_name_highlighted", false)):
		return root as Label
	for child in root.get_children():
		var found: Label = _find_highlighted_name(child)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error("STAGE_RACE_FINISH_LEADERBOARD_HANDOFF_SMOKE: %s" % message)
	quit(1)
