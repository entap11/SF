extends SceneTree

var _failures: Array[String] = []

const FIXTURES: Array[String] = [
	"LATE_MATCH_V1",
	"LANE_STRESS_V1",
	"STRUCTURE_STRESS_V1",
	"DISTRESS_STORM_V1",
	"CAPTURE_STORM_V1",
	"CAMERA_STRESS_V1",
	"UI_STRESS_V1"
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var validator: String = FileAccess.get_file_as_string("res://scripts/tests/perf/perf_fixture_validator.gd")
	_expect(runner.contains("phase2_battlefield_ui_stress"), "runner must expose the P2-D suite")
	for fixture_id in FIXTURES:
		_expect(runner.contains(fixture_id), "runner must contain fixture %s" % fixture_id)
	_expect(runner.contains("phase2_battlefield_event_hash"), "P2-D must emit deterministic event evidence")
	_expect(runner.contains("_phase2_battlefield_track_render"), "P2-D must measure production renderer evidence")
	_expect(runner.contains("arena.get_node_or_null(\"Camera2D\")"), "camera stress must target the exact Arena camera path")
	_expect(runner.contains("scene_root.get_node_or_null(path)"), "UI stress must target exact Main scene paths")
	_expect(runner.contains("unit_pool_peak_active"), "late-match stress must record production unit-pool scale")
	_expect(runner.contains("get_distress_debug_snapshot"), "distress stress must use the production renderer snapshot")
	_expect(validator.contains("camera_schedule frame exceeds the deterministic cadence"), "camera schedules must fail closed outside the run cadence")
	_expect(validator.contains("ui_schedule frame exceeds the deterministic cadence"), "UI schedules must fail closed outside the run cadence")
	_expect(validator.contains("synthetic content_identity is required"), "synthetic presentation fixtures must declare identity")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf/harness_v1_completion_program.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "completion program must parse")
	if typeof(parsed) == TYPE_DICTIONARY:
		var phase: Dictionary = _phase_by_id(parsed as Dictionary, "P2_D_BATTLEFIELD_UI_STRESS")
		_expect(not phase.is_empty(), "P2-D contract must exist")
		_expect((phase.get("fixtures", []) as Array) == FIXTURES, "P2-D fixture inventory must remain exact")
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_D_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_D_SMOKE: %s" % failure)
		quit(1)

func _phase_by_id(program: Dictionary, phase_id: String) -> Dictionary:
	for phase_any in program.get("phases", []) as Array:
		if typeof(phase_any) == TYPE_DICTIONARY and str((phase_any as Dictionary).get("phase_id", "")) == phase_id:
			return phase_any as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
