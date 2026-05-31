extends SceneTree

const SMOKE_SAVE_PATH: String = "user://contest_leaderboard_runtime_smoke.json"
const CONTEST_ID: String = "WEEKLY_USD_1_2025-W52"
const PLAYER_ID: String = "contest_runtime_smoke_player"
const PLAYER_HANDLE: String = "Contest Smoke"
const ARENA_PLAYER_ID: String = "contest_arena_smoke_player"
const ARENA_PLAYER_HANDLE: String = "Arena Contest Smoke"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	await process_frame

	var contest_state: Node = get_root().get_node_or_null("ContestState")
	if contest_state == null:
		_fail("ContestState autoload missing")
		return
	if contest_state.has_method("debug_set_runtime_leaderboard_save_path"):
		contest_state.call("debug_set_runtime_leaderboard_save_path", SMOKE_SAVE_PATH)
	if contest_state.has_method("debug_reset_runtime_leaderboards"):
		contest_state.call("debug_reset_runtime_leaderboards")

	var contest: ContestDef = contest_state.call("get_contest", CONTEST_ID) as ContestDef
	if contest == null:
		_fail("contest missing: %s" % CONTEST_ID)
		return
	var map_ids: PackedStringArray = contest.map_ids
	if map_ids.size() < 5:
		_fail("stage race contest needs at least five maps")
		return

	var first_map_id: String = str(map_ids[0])
	var write_result: Dictionary = contest_state.call("record_stage_race_map_result", CONTEST_ID, first_map_id, {
		"player_id": PLAYER_ID,
		"player_name": PLAYER_HANDLE,
		"best_time_ms": 777,
		"source": "smoke"
	}) as Dictionary
	_assert_true(bool(write_result.get("ok", false)), "single map result should write")

	var map_rows: Array = contest_state.call("get_stage_race_map_leaderboard", CONTEST_ID, first_map_id, 25) as Array
	var player_row: Dictionary = _find_player_row(map_rows, PLAYER_ID)
	_assert_true(not player_row.is_empty(), "single map leaderboard should include local player")
	_assert_eq(int(player_row.get("time_ms", 0)), 777, "single map leaderboard should show best time")
	_assert_eq(str(player_row.get("player_name", "")), PLAYER_HANDLE, "single map leaderboard should show handle")

	for i in range(map_ids.size()):
		var map_id: String = str(map_ids[i])
		var time_ms: int = 900 + i
		var result: Dictionary = contest_state.call("record_stage_race_map_result", CONTEST_ID, map_id, {
			"player_id": PLAYER_ID,
			"player_name": PLAYER_HANDLE,
			"best_time_ms": time_ms,
			"source": "smoke"
		}) as Dictionary
		_assert_true(bool(result.get("ok", false)), "map %d result should write" % (i + 1))

	var overall_rows: Array = contest_state.call("build_stage_race_overall_leaderboard", CONTEST_ID, 5, 25) as Array
	var overall_row: Dictionary = _find_player_row(overall_rows, PLAYER_ID)
	_assert_true(not overall_row.is_empty(), "overall leaderboard should include local player")
	_assert_eq(int(overall_row.get("completed_maps", 0)), 5, "overall leaderboard should count completed maps")
	_assert_eq(int(overall_row.get("aggregate_time_ms", 0)), 777 + 901 + 902 + 903 + 904, "overall leaderboard should aggregate best map times")

	await _assert_arena_match_end_writes_contest_result(contest_state, map_ids[1])

	contest_state.call("debug_reset_runtime_leaderboards")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	print("CONTEST_LEADERBOARD_RUNTIME_SMOKE: PASS")
	quit(0)

func _assert_arena_match_end_writes_contest_result(contest_state: Node, map_id: String) -> void:
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		_fail("Arena scene missing")
		return
	var arena: Node = arena_scene.instantiate()
	get_root().add_child(arena)
	await process_frame
	var tree: SceneTree = self
	tree.set_meta("vs_mode", "STAGE_RACE")
	tree.set_meta("contest_id", CONTEST_ID)
	tree.set_meta("map_ids", PackedStringArray([str(map_id)]))
	tree.set_meta("vs_stage_map_paths", ["res://maps/_future/nomansland/MAP_nomansland__545__v02_all_sides_owned__1p.json"])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_local_profile", {
		"uid": ARENA_PLAYER_ID,
		"display_name": ARENA_PLAYER_HANDLE
	})
	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState autoload missing")
		return
	ops_state.set("match_roster", [{"seat": 1, "is_local": true}])
	ops_state.set("match_elapsed_ms", 1234)
	arena.call("_maybe_record_stage_race_contest_result", 1, "smoke")
	await process_frame
	var rows: Array = contest_state.call("get_stage_race_map_leaderboard", CONTEST_ID, str(map_id), 25) as Array
	var row: Dictionary = _find_player_row(rows, ARENA_PLAYER_ID)
	_assert_true(not row.is_empty(), "Arena match end hook should write contest row")
	_assert_eq(int(row.get("time_ms", 0)), 1234, "Arena hook should persist elapsed map time")
	_assert_eq(str(row.get("player_name", "")), ARENA_PLAYER_HANDLE, "Arena hook should use local display name")
	arena.queue_free()
	await process_frame

func _find_player_row(rows: Array, player_id: String) -> Dictionary:
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		if str(row.get("player_id", "")) == player_id:
			return row
	return {}

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("CONTEST_LEADERBOARD_RUNTIME_SMOKE: %s" % label)
	quit(1)

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("CONTEST_LEADERBOARD_RUNTIME_SMOKE: %s (expected %s, got %s)" % [label, str(expected), str(actual)])
	quit(1)

func _fail(message: String) -> void:
	push_error("CONTEST_LEADERBOARD_RUNTIME_SMOKE: %s" % message)
	quit(1)
