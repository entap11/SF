extends SceneTree

const UnitSystemScript := preload("res://scripts/systems/unit_system.gd")
const GameStateScript := preload("res://scripts/state/game_state.gd")
const HiveDataScript := preload("res://scripts/data/hive_data.gd")

func _init() -> void:
	await process_frame

	var failures: Array[String] = []
	_expect_multiplier(failures, 0, 1.0)
	_expect_multiplier(failures, 200, 1.0)
	_expect_multiplier(failures, 201, 1.0)
	_expect_multiplier(failures, 230, 1.0)
	_expect_multiplier(failures, 231, 1.0)

	if not failures.is_empty():
		for failure in failures:
			push_error("PASS_THROUGH_GOVERNOR_SMOKE: %s" % failure)
		push_error("PASS_THROUGH_GOVERNOR_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return

	print("PASS_THROUGH_GOVERNOR_SMOKE: PASS")
	quit(0)

func _expect_multiplier(failures: Array[String], visible_units: int, expected: float) -> void:
	var state = GameStateScript.new()
	for i in range(10):
		var hive = HiveDataScript.new(i + 1, Vector2i.ZERO, 1, 10)
		state.hives.append(hive)
	var unit_system = UnitSystemScript.new()
	unit_system.bind_state(state)
	for i in range(visible_units):
		unit_system.units.append({"id": i + 1})
	var actual: float = float(unit_system.call("_pass_through_emit_rate_multiplier"))
	if not is_equal_approx(actual, expected):
		failures.append("visible_units=%d expected %.2f got %.2f" % [visible_units, expected, actual])
