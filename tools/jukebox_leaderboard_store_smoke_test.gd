extends SceneTree

const JukeboxLeaderboardStoreScript = preload("res://scripts/state/jukebox_leaderboard_store.gd")
const SMOKE_SAVE_PATH: String = "user://jukebox_leaderboard_v1.smoke.json"
const MAP_ID: String = "MAP_nomansland__SBASE__1p"
const MODE: String = "ASYNC_SINGLE_MAP_TIMED"
const PERIOD: String = "WEEKLY"
const PLAYER_ID: String = "smoke_player"
const PLAYER_HANDLE: String = "Smoke Player"

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SMOKE_SAVE_PATH))
	var now_unix: int = int(Time.get_unix_time_from_system())

	var store = JukeboxLeaderboardStoreScript.new()
	store.save_path = SMOKE_SAVE_PATH
	store.debug_reset_state()

	var seeded: Dictionary = store.get_board_snapshot(MAP_ID, MODE, PERIOD, PLAYER_ID, PLAYER_HANDLE, 50)
	_assert_true(not (seeded.get("entries", []) as Array).is_empty(), "seeded board should not be empty")
	_assert_eq(int(seeded.get("your_rank", 0)), 0, "seeded board should not fabricate a requester rank")
	_assert_eq(int(seeded.get("your_best_ms", 0)), 0, "seeded board should not fabricate a requester time")

	var improve: Dictionary = store.upsert_result(MAP_ID, MODE, PERIOD, {
		"player_id": PLAYER_ID,
		"handle": PLAYER_HANDLE,
		"best_time_ms": 55123,
		"updated_at": now_unix
	})
	_assert_true(bool(improve.get("ok", false)), "upsert_result should accept improved result")
	_assert_true(bool(improve.get("updated", false)), "upsert_result should mark improved result updated")

	var improved: Dictionary = store.get_board_snapshot(MAP_ID, MODE, PERIOD, PLAYER_ID, PLAYER_HANDLE, 50)
	_assert_eq(int(improved.get("your_rank", 0)), 1, "faster local result should move requester to rank 1")
	_assert_eq(int(improved.get("your_best_ms", 0)), 55123, "snapshot should expose updated best time")
	_assert_eq(_count_player_rows(improved.get("entries", []) as Array, PLAYER_ID), 1, "board should show the first real run")

	var stale: Dictionary = store.upsert_result(MAP_ID, MODE, PERIOD, {
		"player_id": PLAYER_ID,
		"handle": PLAYER_HANDLE,
		"best_time_ms": 65000,
		"updated_at": now_unix + 1
	})
	_assert_true(bool(stale.get("ok", false)), "slower run should still be accepted")
	_assert_true(bool(stale.get("updated", false)), "slower run should still append to the board")

	var reloaded = JukeboxLeaderboardStoreScript.new()
	reloaded.save_path = SMOKE_SAVE_PATH
	var persisted: Dictionary = reloaded.get_board_snapshot(MAP_ID, MODE, PERIOD, PLAYER_ID, PLAYER_HANDLE, 50)
	_assert_eq(int(persisted.get("your_rank", 0)), 1, "reloaded store should preserve rank")
	_assert_eq(int(persisted.get("your_best_ms", 0)), 55123, "reloaded store should preserve best time")
	_assert_eq(_count_player_rows(persisted.get("entries", []) as Array, PLAYER_ID), 2, "reloaded store should preserve multiple runs")

	print("JUKEBOX_LEADERBOARD_STORE_SMOKE: PASS")
	quit(0)

func _count_player_rows(entries: Array, player_id: String) -> int:
	var count: int = 0
	for entry_any in entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		if str((entry_any as Dictionary).get("player_id", "")) == player_id:
			count += 1
	return count

func _assert_eq(actual: int, expected: int, label: String) -> void:
	if actual == expected:
		return
	push_error("JUKEBOX_LEADERBOARD_STORE_SMOKE: %s (expected %d, got %d)" % [label, expected, actual])
	quit(1)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	push_error("JUKEBOX_LEADERBOARD_STORE_SMOKE: %s" % label)
	quit(1)
