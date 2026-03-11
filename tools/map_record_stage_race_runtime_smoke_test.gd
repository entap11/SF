extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const JukeboxLeaderboardStoreScript = preload("res://scripts/state/jukebox_leaderboard_store.gd")
const SMOKE_SAVE_PATH: String = "user://map_record_stage_race_runtime.smoke.json"
const MAP_PATH: String = "res://maps/nomansland/MAP_nomansland__GBASE__1p.json"
const MAP_ID: String = "MAP_nomansland__GBASE__1p"
const BOARD_MODE: String = "ASYNC_SINGLE_MAP_TIMED"
const PLAYER_ID: String = "stage_smoke_player"
const PLAYER_HANDLE: String = "Stage Smoke"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	await process_frame

	var runtime: Node = get_root().get_node_or_null("JukeboxRuntime")
	if runtime == null:
		_fail("JukeboxRuntime autoload missing")
		return
	if runtime.has_method("debug_set_store_save_path"):
		runtime.call("debug_set_store_save_path", SMOKE_SAVE_PATH)
	if runtime.has_method("debug_reset_store"):
		runtime.call("debug_reset_store")

	var tree: SceneTree = self
	tree.set_meta("vs_mode", "STAGE_RACE")
	tree.set_meta("vs_sync_start", false)
	tree.set_meta("vs_stage_map_paths", [MAP_PATH, "res://maps/nomansland/MAP_nomansland__SBASE__1p.json"])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_local_profile", {
		"uid": PLAYER_ID,
		"name": PLAYER_HANDLE
	})
	tree.set_meta("jukebox_local_owner_id", 1)

	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState autoload missing")
		return
	ops_state.set("match_elapsed_ms", 61234)

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame
	fake_runner.emit_signal("match_ended", 1, "round_end")
	await process_frame

	var store = JukeboxLeaderboardStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	var snapshot: Dictionary = store.get_board_snapshot(MAP_ID, BOARD_MODE, "WEEKLY", PLAYER_ID, PLAYER_HANDLE, 50)
	_assert_eq(int(snapshot.get("your_rank", 0)), 1, "stage race round win should write to canonical map board")
	_assert_eq(int(snapshot.get("your_best_ms", 0)), 61234, "stage race round win should persist elapsed map time")
	var summary: Dictionary = store.get_player_map_summary(MAP_ID, BOARD_MODE, PLAYER_ID, PLAYER_HANDLE, "ALL TIME")
	_assert_eq(int(summary.get("best_time_ms", 0)), 61234, "stage race should update all-time map PB")
	_assert_eq(int(summary.get("run_count", 0)), 1, "stage race should add one run to map summary")

	print("MAP_RECORD_STAGE_RACE_RUNTIME_SMOKE: PASS")
	quit(0)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("MAP_RECORD_STAGE_RACE_RUNTIME_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _fail(message: String) -> void:
	push_error("MAP_RECORD_STAGE_RACE_RUNTIME_SMOKE: %s" % message)
	quit(1)
