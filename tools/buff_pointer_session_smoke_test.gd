extends SceneTree

const SessionScript := preload("res://scripts/shell_helpers/buff_pointer_session.gd")

var _failed: bool = false


func _init() -> void:
	var session: RefCounted = SessionScript.new()
	var first: Dictionary = session.begin(
		"touch", 7, 1, "buff_unit_speed_classic", Vector2(100.0, 100.0),
		{"ok": true, "slot": {"id": "buff_unit_speed_classic"}}, "revision-a"
	)
	var first_id: int = int(first.get("pointer_session_id", 0))
	_expect(first_id > 0, "capture should allocate a local generation id")
	_expect(session.matches("touch", 7, first_id), "initiating touch should own the session")
	_expect(not session.matches("touch", 8, first_id), "foreign touch must not own the session")

	var below: Dictionary = session.move("touch", 7, first_id, Vector2(112.0, 100.0), 18.0)
	_expect(bool(below.get("ok", false)) and not bool(below.get("drag_started", false)), "below-slop movement must stay captured")
	_expect(str(below.get("state", "")) == SessionScript.STATE_CAPTURED, "below-slop state should remain captured")
	var foreign: Dictionary = session.move("touch", 8, first_id, Vector2(300.0, 300.0), 18.0)
	_expect(not bool(foreign.get("ok", false)), "foreign movement must be rejected")
	var crossed: Dictionary = session.move("touch", 7, first_id, Vector2(118.0, 100.0), 18.0)
	_expect(bool(crossed.get("drag_started", false)), "crossing touch slop should begin one drag")
	var continued: Dictionary = session.move("touch", 7, first_id, Vector2(160.0, 100.0), 18.0)
	_expect(not bool(continued.get("drag_started", true)), "continued movement must not restart drag")

	var cleared: Dictionary = session.clear(first_id)
	_expect(not cleared.is_empty() and not session.is_active(), "matching cancellation should clear ownership")
	var second: Dictionary = session.begin(
		"touch", 7, 2, "buff_freeze_lane_classic", Vector2.ZERO,
		{"ok": true, "slot": {"id": "buff_freeze_lane_classic"}}, "revision-b"
	)
	var second_id: int = int(second.get("pointer_session_id", 0))
	_expect(second_id > first_id, "reused OS touch IDs must receive a newer generation")
	_expect(not bool(session.move("touch", 7, first_id, Vector2.ONE, 1.0).get("ok", false)), "stale queued movement must not affect a newer generation")
	_expect(session.matches("touch", 7, second_id), "new generation should retain ownership")
	session.clear(second_id)

	var mouse: Dictionary = session.begin(
		SessionScript.POINTER_MOUSE,
		SessionScript.MOUSE_POINTER_ID,
		0,
		"buff_swarm_speed_classic",
		Vector2.ZERO,
		{"ok": true},
		"revision-c"
	)
	_expect(session.matches("mouse", 0, int(mouse.get("pointer_session_id", 0))), "development mouse should use the same explicit session contract")

	var perf_id: int = int(mouse.get("pointer_session_id", 0))
	var started_us: int = Time.get_ticks_usec()
	for i in range(100000):
		session.move("mouse", 0, perf_id, Vector2(float(i % 1000), 20.0), 18.0)
	var elapsed_us: int = Time.get_ticks_usec() - started_us
	var active: Dictionary = session.snapshot()
	_expect(active.size() == 12, "movement must reuse one bounded session record")
	print("BUFF_POINTER_SESSION_PERF: events=100000 elapsed_us=%d avg_us=%.4f fields=%d" % [
		elapsed_us,
		float(elapsed_us) / 100000.0,
		active.size()
	])

	if not _failed:
		print("BUFF_POINTER_SESSION_SMOKE: PASS")
	quit(1 if _failed else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BUFF_POINTER_SESSION_SMOKE: %s" % message)
