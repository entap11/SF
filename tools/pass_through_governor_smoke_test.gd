extends SceneTree

const UnitSystemScript := preload("res://scripts/systems/unit_system.gd")
const GameStateScript := preload("res://scripts/state/game_state.gd")
const HiveDataScript := preload("res://scripts/data/hive_data.gd")

func _init() -> void:
	await process_frame

	var failures: Array[String] = []
	_expect_multiplier(failures, 10, 1.0)
	_expect_multiplier(failures, 12, 0.8)
	_expect_multiplier(failures, 15, 0.8)
	_expect_multiplier(failures, 16, 0.6)
	_expect_multiplier(failures, 17, 0.6)

	if not failures.is_empty():
		for failure in failures:
			push_error("PASS_THROUGH_GOVERNOR_SMOKE: %s" % failure)
		push_error("PASS_THROUGH_GOVERNOR_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return

	print("PASS_THROUGH_GOVERNOR_SMOKE: PASS")
	quit(0)

func _expect_multiplier(failures: Array[String], hive_count: int, expected: float) -> void:
	var state = GameStateScript.new()
	for i in range(hive_count):
		var hive = HiveDataScript.new(i + 1, Vector2i.ZERO, 1, 10)
		state.hives.append(hive)
	var unit_system = UnitSystemScript.new()
	unit_system.bind_state(state)
	var actual: float = float(unit_system.call("_pass_through_emit_rate_multiplier"))
	if not is_equal_approx(actual, expected):
		failures.append("hive_count=%d expected %.2f got %.2f" % [hive_count, expected, actual])
