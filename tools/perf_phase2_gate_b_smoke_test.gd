extends SceneTree

const TARGETS: Array[int] = [50, 100, 200, 400]

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(source.contains("phase2_moving_unit_scale"), "runner must expose the moving scale suite")
	_expect(source.contains("unit_count_policy\"] = \"bounded_moving\""), "moving fixtures must use bounded evolution")
	_expect(source.contains("sim_runner.call(\"_tick\", SIM_TICK_INTERVAL_SEC)"), "moving fixtures must use canonical SimRunner ticks")
	_expect(source.contains("moving_unit_progress_not_observed"), "runner must prove movement")
	_expect(source.contains("unit_count_timeline_hash"), "runner must hash bounded count evolution")
	_expect(source.contains("unit_motion_hash"), "runner must hash motion evidence")
	_expect(source.contains("unexpected_renderer_pool_expansion"), "pool expansion must remain fail-closed")
	_expect(source.contains("capacity_bypass_used\": false"), "capacity bypass must remain prohibited")
	_expect(source.contains("MOVING_UNIT_SCALE_%03d_V1"), "moving fixture IDs must be formatted from exact targets")
	_expect(source.contains("--perf-user-dir="), "runner must support a dedicated protected-state namespace")
	_expect(source.contains("user_data_isolation"), "runner must report user-data isolation evidence")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf/harness_v1_completion_program.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "completion program must parse")
	if typeof(parsed) == TYPE_DICTIONARY:
		var phase: Dictionary = _phase_by_id(parsed as Dictionary, "P2_B_MOVING_UNIT_SCALE")
		_expect(not phase.is_empty(), "P2-B contract must exist")
		var fixtures: Array = phase.get("fixtures", []) as Array
		_expect(fixtures.size() == 4, "P2-B must retain four exact scales")
		for target in TARGETS:
			var fixture_id: String = "MOVING_UNIT_SCALE_%03d_V1" % target
			_expect(fixtures.has(fixture_id), "missing moving fixture: %s" % fixture_id)
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_B_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_B_SMOKE: %s" % failure)
		quit(1)

func _phase_by_id(program: Dictionary, phase_id: String) -> Dictionary:
	for phase_any in program.get("phases", []) as Array:
		if typeof(phase_any) == TYPE_DICTIONARY and str((phase_any as Dictionary).get("phase_id", "")) == phase_id:
			return phase_any as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
