extends SceneTree

class FakeSimRunner:
	extends Node
	signal match_ended(winner_id: int, reason: String)

const JukeboxLeaderboardStoreScript = preload("res://scripts/state/jukebox_leaderboard_store.gd")
const SMOKE_SAVE_PATH: String = "user://jukebox_runtime_v1.smoke.json"
const MAP_PATH: String = "res://maps/nomansland/MAP_nomansland__SBASE__1p.json"
const MAP_ID: String = "MAP_nomansland__SBASE__1p"
const MODE: String = "ASYNC_SINGLE_MAP_TIMED"
const PERIOD: String = "WEEKLY"
const PLAYER_ID: String = "jukebox_smoke_player"
const PLAYER_HANDLE: String = "Jukebox Smoke"

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
	tree.set_meta("jukebox_board_enabled", true)
	tree.set_meta("jukebox_map_path", MAP_PATH)
	tree.set_meta("jukebox_map_id", MAP_ID)
	tree.set_meta("jukebox_board_period", PERIOD)
	tree.set_meta("jukebox_local_owner_id", 1)
	tree.set_meta("vs_mode", MODE)
	tree.set_meta("vs_sync_start", false)
	tree.set_meta("vs_stage_map_paths", [MAP_PATH])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_local_profile", {
		"uid": PLAYER_ID,
		"name": PLAYER_HANDLE
	})

	var ops_state: Node = get_root().get_node_or_null("OpsState")
	if ops_state == null:
		_fail("OpsState autoload missing")
		return
	ops_state.set("match_elapsed_ms", 54321)

	var fake_runner := FakeSimRunner.new()
	fake_runner.name = "SimRunner"
	get_root().add_child(fake_runner)
	await process_frame
	fake_runner.emit_signal("match_ended", 1, "capture_all")
	await process_frame

	var store = JukeboxLeaderboardStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	for period_label in JukeboxLeaderboardStoreScript.PERIOD_LABELS:
		var snapshot: Dictionary = store.get_board_snapshot(MAP_ID, MODE, str(period_label), PLAYER_ID, PLAYER_HANDLE, 50)
		_assert_eq(int(snapshot.get("your_rank", 0)), 1, "runtime should write winning jukebox time to %s board" % str(period_label))
		_assert_eq(int(snapshot.get("your_best_ms", 0)), 54321, "runtime should persist elapsed match time to %s board" % str(period_label))
	var all_time_summary: Dictionary = store.get_player_map_summary(MAP_ID, MODE, PLAYER_ID, PLAYER_HANDLE, "ALL TIME")
	_assert_eq(int(all_time_summary.get("best_time_ms", 0)), 54321, "runtime should update all-time player map summary")
	_assert_eq(int(all_time_summary.get("run_count", 0)), 1, "runtime should record exactly one deduped run")

	print("JUKEBOX_RUNTIME_SMOKE: PASS")
	quit(0)

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("JUKEBOX_RUNTIME_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _fail(message: String) -> void:
	push_error("JUKEBOX_RUNTIME_SMOKE: %s" % message)
	quit(1)
