extends SceneTree

const PERF_ISOLATION_GUARD := preload("res://scripts/tests/perf/perf_isolation_guard.gd")

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var validator: String = FileAccess.get_file_as_string("res://scripts/tests/perf/perf_fixture_validator.gd")
	_expect(runner.contains("phase2_lifecycle_soak"), "runner must expose the P2-E suite")
	_expect(runner.contains("LIFECYCLE_SOAK_V1"), "lifecycle fixture must exist")
	_expect(runner.contains("_lifecycle_soak_evidence"), "suite must aggregate lifecycle evidence")
	_expect(runner.contains("OBJECT_NODE_COUNT"), "lifecycle evidence must record node counts")
	_expect(runner.contains("OBJECT_COUNT"), "lifecycle evidence must record object counts")
	_expect(runner.contains("OBJECT_RESOURCE_COUNT"), "lifecycle evidence must record resource counts")
	_expect(runner.contains("MEMORY_STATIC"), "lifecycle evidence must record static memory")
	_expect(runner.contains("lifecycle_report_payload_bytes"), "lifecycle evidence must bound report growth")
	_expect(runner.contains("_finalize->_recover_interrupted_repetition"), "interrupted cleanup recovery must be declared")
	_expect(validator.contains("lifecycle repetitions must equal lifecycle_required_cycles"), "lifecycle cycles must fail closed")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf/harness_v1_completion_program.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "completion program must parse")
	if typeof(parsed) == TYPE_DICTIONARY:
		var phase: Dictionary = _phase_by_id(parsed as Dictionary, "P2_E_LIFECYCLE_SOAK")
		_expect(not phase.is_empty(), "P2-E contract must exist")
		_expect((phase.get("fixtures", []) as Array) == ["LIFECYCLE_SOAK_V1"], "P2-E fixture inventory must remain exact")
	await _exercise_interrupted_cleanup_primitives()
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_E_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_E_SMOKE: %s" % failure)
		quit(1)

func _exercise_interrupted_cleanup_primitives() -> void:
	var ops_state: Node = root.get_node_or_null("/root/OpsState")
	_expect(ops_state != null, "OpsState autoload must exist for recovery exercise")
	if ops_state == null:
		return
	var snapshot: Dictionary = PERF_ISOLATION_GUARD.capture(self, ops_state)
	var original_max_fps: int = Engine.max_fps
	var fixture_root := Node.new()
	fixture_root.name = "PerfLifecycleInterruptedFixture"
	root.add_child(fixture_root)
	Engine.max_fps = original_max_fps + 7
	var fixture_state := GameState.new()
	ops_state.set("state", fixture_state)
	fixture_root.free()
	var release: Dictionary = PERF_ISOLATION_GUARD.release_fixture_state(snapshot, ops_state)
	var restore: Dictionary = PERF_ISOLATION_GUARD.restore(snapshot, self, ops_state)
	await process_frame
	await process_frame
	var verify: Dictionary = PERF_ISOLATION_GUARD.verify(snapshot, self, ops_state)
	_expect(bool(release.get("released", false)), "interrupted recovery must release fixture state")
	_expect(bool(restore.get("pass", false)), "interrupted recovery restore must pass: %s" % str(restore.get("mismatches", [])))
	_expect(bool(verify.get("pass", false)), "interrupted recovery verification must pass: %s" % str(verify.get("mismatches", [])))
	_expect(str(verify.get("before_protected_state_hash", "")) == str(verify.get("after_protected_state_hash", "")), "interrupted recovery must preserve protected state")

func _phase_by_id(program: Dictionary, phase_id: String) -> Dictionary:
	for phase_any in program.get("phases", []) as Array:
		if typeof(phase_any) == TYPE_DICTIONARY and str((phase_any as Dictionary).get("phase_id", "")) == phase_id:
			return phase_any as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
