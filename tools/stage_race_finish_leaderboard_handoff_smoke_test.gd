extends SceneTree

const SMOKE_SAVE_PATH: String = "user://stage_race_finish_leaderboard_handoff_smoke.json"
const CONTEST_ID: String = "WEEKLY_FREE_0_2025-W52"
const PLAYER_ID: String = "finish_handoff_player"
const PLAYER_NAME: String = "Finish Handoff"
const RUN_ID: String = "finish_handoff_run"

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
	if contest.map_ids.size() < 5:
		_fail("contest needs five maps")
		return
	for i in range(5):
		var result: Dictionary = contest_state.call("record_stage_race_map_result", CONTEST_ID, str(contest.map_ids[i]), {
			"player_id": PLAYER_ID,
			"player_name": PLAYER_NAME,
			"best_time_ms": 700 + i,
			"run_id": RUN_ID,
			"source": "finish_handoff_smoke"
		}) as Dictionary
		if not bool(result.get("ok", false)):
			_fail("result write failed: %s" % str(result))
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

	var main_menu_scene: PackedScene = load("res://scenes/MainMenu.tscn") as PackedScene
	if main_menu_scene == null:
		_fail("MainMenu scene missing")
		return
	var menu: Node = main_menu_scene.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame
	await process_frame
	var modal: Control = menu.get("_entry_route_modal") as Control
	if modal == null or not modal.visible:
		_fail("finish handoff did not open leaderboard modal")
		return
	var highlighted: Control = _find_highlighted_row(modal)
	if highlighted == null:
		_fail("finish handoff did not highlight completed top-10 run")
		return
	contest_state.call("debug_reset_runtime_leaderboards")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	print("STAGE_RACE_FINISH_LEADERBOARD_HANDOFF_SMOKE: PASS")
	quit(0)

func _find_highlighted_row(root: Node) -> Control:
	if root is Control and bool((root as Control).get_meta("stage_leaderboard_highlighted", false)):
		return root as Control
	for child in root.get_children():
		var found: Control = _find_highlighted_row(child)
		if found != null:
			return found
	return null

func _fail(message: String) -> void:
	push_error("STAGE_RACE_FINISH_LEADERBOARD_HANDOFF_SMOKE: %s" % message)
	quit(1)
