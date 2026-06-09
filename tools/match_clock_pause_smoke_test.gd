extends SceneTree

var _failed: bool = false

func _initialize() -> void:
	await process_frame
	var ops_state: Node = get_root().get_node_or_null("/root/OpsState")
	_expect_true(ops_state != null, "OpsState autoload should exist")
	if ops_state == null:
		quit(1)
		return
	_test_match_clock_pause_shifts_deadline(ops_state)
	_test_reset_clears_pause_state(ops_state)
	if not _failed:
		print("MATCH_CLOCK_PAUSE_SMOKE: PASS")
	quit(1 if _failed else 0)

func _test_match_clock_pause_shifts_deadline(ops_state: Node) -> void:
	var state: GameState = _reset_running_state(ops_state)
	ops_state.call("tick_match_clock", state, 0)
	var duration_ms: int = int(ops_state.get("match_duration_ms"))
	var deadline_start: int = int(ops_state.get("match_deadline_ms"))
	_expect_true(bool(ops_state.get("match_clock_started")), "clock should start on first tick")
	_expect_true(bool(ops_state.get("match_clock_running")), "clock should be running on first tick")
	_expect_true(deadline_start > 0, "clock should set deadline")
	var pause_at: int = Time.get_ticks_msec() + 1000
	var pause_result: Dictionary = ops_state.call("pause_match_clock", "smoke_background", pause_at) as Dictionary
	_expect_true(bool(pause_result.get("ok", false)), "pause_match_clock should succeed")
	_expect_true(bool(ops_state.get("match_clock_paused")), "clock should be marked paused")
	_expect_true(not bool(ops_state.get("match_clock_running")), "paused clock should not be running")
	var remaining_at_pause: int = int(ops_state.get("match_remaining_ms"))
	var elapsed_at_pause: int = int(ops_state.get("match_elapsed_ms"))
	ops_state.call("tick_match_clock", state, 30000)
	_expect_eq(int(ops_state.get("match_remaining_ms")), remaining_at_pause, "paused tick should not drain remaining time")
	_expect_eq(int(ops_state.get("match_elapsed_ms")), elapsed_at_pause, "paused tick should not advance elapsed time")
	var pause_duration_ms: int = 30000
	var resume_at: int = pause_at + pause_duration_ms
	var deadline_before_resume: int = int(ops_state.get("match_deadline_ms"))
	var resume_result: Dictionary = ops_state.call("resume_match_clock", "smoke_foreground", resume_at) as Dictionary
	_expect_true(bool(resume_result.get("ok", false)), "resume_match_clock should succeed")
	_expect_true(not bool(ops_state.get("match_clock_paused")), "clock should not remain paused after resume")
	_expect_true(bool(ops_state.get("match_clock_running")), "clock should run after resume")
	_expect_eq(int(ops_state.get("match_deadline_ms")), deadline_before_resume + pause_duration_ms, "resume should shift deadline by paused duration")
	_expect_eq(int(ops_state.get("match_remaining_ms")), remaining_at_pause, "resume should preserve frozen remaining time")
	_expect_eq(int(ops_state.get("match_elapsed_ms")), elapsed_at_pause, "resume should preserve frozen elapsed time")
	_expect_eq(int(ops_state.get("match_clock_pause_accumulated_ms")), pause_duration_ms, "pause duration should accumulate")
	_expect_true(int(ops_state.get("match_remaining_ms")) < duration_ms, "test should have consumed pre-pause time")
	_expect_eq(int(ops_state.get("match_phase")), int(ops_state.MatchPhase.RUNNING), "clock pause should not end the match")

func _test_reset_clears_pause_state(ops_state: Node) -> void:
	_reset_running_state(ops_state)
	ops_state.call("tick_match_clock", ops_state.call("get_state"), 0)
	var pause_at: int = Time.get_ticks_msec() + 500
	ops_state.call("pause_match_clock", "smoke_reset", pause_at)
	_expect_true(bool(ops_state.get("match_clock_paused")), "clock should be paused before reset")
	ops_state.call("reset_match_state")
	_expect_true(not bool(ops_state.get("match_clock_paused")), "reset should clear clock paused flag")
	_expect_eq(int(ops_state.get("match_clock_pause_started_ms")), 0, "reset should clear pause start")
	_expect_eq(int(ops_state.get("match_clock_pause_accumulated_ms")), 0, "reset should clear accumulated pause")
	_expect_eq(str(ops_state.get("match_clock_pause_reason")), "", "reset should clear pause reason")

func _reset_running_state(ops_state: Node) -> GameState:
	var map_dict := {
		"hives": [
			{"id": 1, "x": 0, "y": 0, "owner_id": 1, "power": 50, "kind": "Hive"},
			{"id": 2, "x": 4, "y": 0, "owner_id": 2, "power": 10, "kind": "Hive"}
		],
		"lane_candidates": [
			{"a_id": 1, "b_id": 2}
		]
	}
	var state: GameState = ops_state.call("reset_state_from_map", map_dict)
	ops_state.set("match_phase", int(ops_state.MatchPhase.RUNNING))
	return state

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("MATCH_CLOCK_PAUSE_SMOKE: %s" % message)

func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failed = true
	push_error("MATCH_CLOCK_PAUSE_SMOKE: %s actual=%s expected=%s" % [message, str(actual), str(expected)])
