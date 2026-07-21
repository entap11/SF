extends SceneTree

const PERF_ISOLATION_GUARD := preload("res://scripts/tests/perf/perf_isolation_guard.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var disposable_ops_state := Node.new()
	root.add_child(disposable_ops_state)
	var freed_ops_state: Variant = disposable_ops_state
	disposable_ops_state.free()
	_expect(not is_instance_valid(freed_ops_state), "test fixture must hold a freed object reference")
	var release_result: Dictionary = PERF_ISOLATION_GUARD.release_fixture_state({}, freed_ops_state)
	_expect(not bool(release_result.get("released", true)), "freed OpsState must not be released twice")
	_expect(str(release_result.get("reason", "")) == "ops_state_unavailable", "freed OpsState must fail closed as unavailable")
	var missing_result: Dictionary = PERF_ISOLATION_GUARD.release_fixture_state({}, null)
	_expect(str(missing_result.get("reason", "")) == "ops_state_unavailable", "missing OpsState must fail closed as unavailable")
	if _failures.is_empty():
		print("PERF_INTERRUPTED_CLEANUP_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_INTERRUPTED_CLEANUP_SMOKE: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
