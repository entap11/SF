extends SceneTree

const PERF_FEATURE_REGISTRY := preload("res://scripts/tests/perf/perf_feature_registry.gd")
const REGISTRY_PATH: String = "res://data/perf/feature_isolation_registry_v1.json"

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var loaded: Dictionary = PERF_FEATURE_REGISTRY.load_registry(REGISTRY_PATH)
	_expect(bool(loaded.get("ok", false)), "feature registry must validate: %s" % str(loaded.get("errors", [])))
	if bool(loaded.get("ok", false)):
		var identity: Dictionary = loaded.get("identity", {}) as Dictionary
		_expect(int(identity.get("feature_count", 0)) == 47, "feature inventory count must remain exact")
		var counts: Dictionary = identity.get("classification_counts", {}) as Dictionary
		_expect(int(counts.get("PRESENT_ISOLATABLE", 0)) == 13, "isolatable classification count changed")
		_expect(int(counts.get("PRESENT_COUPLED", 0)) == 24, "coupled classification count changed")
		_expect(int(counts.get("NOT_PRESENT", 0)) == 5, "not-present classification count changed")
		_expect(int(counts.get("FUTURE", 0)) == 5, "future classification count changed")
		var registry: Dictionary = loaded.get("registry", {}) as Dictionary
		_expect(str(PERF_FEATURE_REGISTRY.resolved_feature(registry, "megaswarm_system").get("classification", "")) == "NOT_PRESENT", "Megaswarm must not gain a fabricated control")
		_expect(str(PERF_FEATURE_REGISTRY.resolved_feature(registry, "winning_move_chase_camera").get("classification", "")) == "FUTURE", "chase camera must remain future")
		_expect(str(PERF_FEATURE_REGISTRY.resolved_feature(registry, "dynamic_hive_shadows").get("classification", "")) == "PRESENT_COUPLED", "dynamic hive shadows must remain coupled")
		var polish: Dictionary = PERF_FEATURE_REGISTRY.resolved_feature(registry, "arena_polish_bundle")
		var variants: Dictionary = polish.get("variants", {}) as Dictionary
		for variant in ["off", "production", "exaggerated"]:
			var row: Dictionary = variants.get(variant, {}) as Dictionary
			_expect(bool(row.get("supported", false)) and bool(row.get("comparison_safe", false)), "arena polish %s variant must remain safe" % variant)
		_exercise_fail_closed_registry(registry)
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(runner.contains("phase2_feature_isolation"), "runner must expose the P2-F suite")
	_expect(runner.contains("_feature_isolation_evidence"), "runner must aggregate one-variable evidence")
	_expect(runner.contains("feature switch is not registered"), "unknown feature switches must fail closed")
	_expect(runner.contains("polish_layer.call(\"apply_runtime_settings\")"), "polish control must update its exact owner")
	_expect(runner.contains("key == \"polish\" and bool(allowed.get(key, false))"), "render isolation must preserve the resolved polish variant")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf/harness_v1_completion_program.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "completion program must parse")
	if typeof(parsed) == TYPE_DICTIONARY:
		var phase: Dictionary = _phase_by_id(parsed as Dictionary, "P2_F_FEATURE_ISOLATION")
		_expect(not phase.is_empty(), "P2-F contract must exist")
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_F_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_F_SMOKE: %s" % failure)
		quit(1)

func _exercise_fail_closed_registry(registry: Dictionary) -> void:
	var malformed: Dictionary = registry.duplicate(true)
	var features: Array = malformed.get("features", []) as Array
	if features.is_empty():
		_failures.append("malformed registry exercise needs features")
		return
	var first: Dictionary = (features[0] as Dictionary).duplicate(true)
	first["control"] = {"kind": "scene_visibility", "path": "Unapproved/FragmentSearch"}
	features[0] = first
	malformed["features"] = features
	var validation: Dictionary = PERF_FEATURE_REGISTRY.validate_registry(malformed)
	_expect(not bool(validation.get("ok", true)), "unapproved broad/fragment control must fail registry validation")

func _phase_by_id(program: Dictionary, phase_id: String) -> Dictionary:
	for phase_any in program.get("phases", []) as Array:
		if typeof(phase_any) == TYPE_DICTIONARY and str((phase_any as Dictionary).get("phase_id", "")) == phase_id:
			return phase_any as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
