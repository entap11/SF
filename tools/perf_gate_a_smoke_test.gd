extends SceneTree

const RunPolicy := preload("res://scripts/tests/perf/perf_run_policy.gd")
const FixtureValidator := preload("res://scripts/tests/perf/perf_fixture_validator.gd")

const QUICK_MAP: String = "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json"
const LAYERS_MAP: String = "res://maps/_future/nomansland/MAP_nomansland__545__v08_spine_knife_fight__npc20__1p.json"
const STRESS_MAP: String = "res://maps/_future/nomansland/MAP_nomansland__545__v13_top3_each__npc20__1p.json"
const TEMP_BAD_GATES: String = "user://perf_gate_a_bad_gates.json"

var _failed: bool = false


func _init() -> void:
	_test_run_policy()
	_test_gate_validation()
	_test_static_fixture_preflight()
	_test_post_apply_validation()
	_test_canonical_runner_source_contract()
	_cleanup_temp_file()
	if not _failed:
		print("PERF_GATE_A_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_run_policy() -> void:
	var args := PackedStringArray([RunPolicy.HARNESS_ARG])
	_expect(not RunPolicy.enabled_for_runtime(false, args), "release policy must refuse the harness argument")
	_expect(not RunPolicy.enabled_for_runtime(true, PackedStringArray()), "debug policy must require the exact harness argument")
	_expect(RunPolicy.enabled_for_runtime(true, args), "debug policy must accept the exact harness argument")
	_expect(RunPolicy.refusal_reason(false, args) == "release_build_refused", "release refusal must be explicit")
	_expect(RunPolicy.refusal_reason(true, PackedStringArray()).contains(RunPolicy.HARNESS_ARG), "missing-argument refusal must name the required argument")


func _test_gate_validation() -> void:
	var loaded: Dictionary = FixtureValidator.load_gate_config("res://data/perf/benchmark_gates.json")
	_expect(bool(loaded.get("ok", false)), "approved 30 FPS gate file must load")
	_expect(int((loaded.get("gates", {}) as Dictionary).get("target_fps", 0)) == 30, "approved target must remain 30 FPS")
	var missing: Dictionary = FixtureValidator.load_gate_config("res://data/perf/does_not_exist.json")
	_expect(not bool(missing.get("ok", true)), "missing gate file must fail closed")
	var file := FileAccess.open(TEMP_BAD_GATES, FileAccess.WRITE)
	_expect(file != null, "malformed-gate fixture must be writable")
	if file != null:
		file.store_string("{ definitely not valid JSON")
		file.close()
	var malformed: Dictionary = FixtureValidator.load_gate_config(TEMP_BAD_GATES)
	_expect(not bool(malformed.get("ok", true)), "malformed gate JSON must fail closed")
	var wrong_target := {
		"target_fps": 60,
		"target_frame_ms": 16.67,
		"p99_max_ms": 33.33,
		"max_frame_ms": 50.0,
		"max_hitches": 0,
		"warn_regression_percent": 10.0,
		"fail_regression_percent": 20.0
	}
	var target_validation: Dictionary = FixtureValidator.validate_gate_config(wrong_target)
	_expect(not bool(target_validation.get("ok", true)), "Phase 0 must reject an undeclared 60 FPS target")


func _test_static_fixture_preflight() -> void:
	var valid: Dictionary = _scenario(QUICK_MAP, {"hives": 12, "towers": 0, "barracks": 0, "structure_slots": 0})
	var result: Dictionary = FixtureValidator.static_preflight(valid, "canonical_sim_headless")
	_expect(bool(result.get("ok", false)), "valid Centerstrike fixture must pass static preflight: %s" % str(result.get("errors", [])))
	_expect(str(result.get("map_content_hash", "")).length() == 64, "preflight must calculate a SHA-256 map hash")
	for map_path in [LAYERS_MAP, STRESS_MAP]:
		var map_result: Dictionary = FixtureValidator.static_preflight(
			_scenario(map_path, {"hives": 14, "towers": 0, "barracks": 0, "structure_slots": 2}),
			"canonical_sim_headless"
		)
		_expect(bool(map_result.get("ok", false)), "corrected one-player map must pass: %s errors=%s" % [map_path, str(map_result.get("errors", []))])
	var missing: Dictionary = FixtureValidator.static_preflight(_scenario("res://maps/missing.json", {}), "canonical_sim_headless")
	_expect(not bool(missing.get("ok", true)), "missing fixture resource must fail before scene setup")
	var bad_mode: Dictionary = FixtureValidator.static_preflight(valid, "full_simulation")
	_expect(not bool(bad_mode.get("ok", true)), "unsupported execution mode must fail preflight")
	var bad_count: Dictionary = valid.duplicate(true)
	bad_count["expected_counts"] = {"hives": 99}
	var count_result: Dictionary = FixtureValidator.static_preflight(bad_count, "canonical_sim_headless")
	_expect(not bool(count_result.get("ok", true)), "incorrect expected count must fail preflight")
	var bad_version: Dictionary = valid.duplicate(true)
	bad_version["fixture_version"] = 99
	var version_result: Dictionary = FixtureValidator.static_preflight(bad_version, "canonical_sim_headless")
	_expect(not bool(version_result.get("ok", true)), "unsupported fixture version must fail preflight")
	var unsupported_camera: Dictionary = valid.duplicate(true)
	unsupported_camera["camera_schedule"] = [{"tick": 1, "kind": "pan"}]
	var camera_result: Dictionary = FixtureValidator.static_preflight(unsupported_camera, "canonical_sim_headless")
	_expect(not bool(camera_result.get("ok", true)), "an unimplemented camera schedule must fail instead of being silently ignored")
	var bad_command: Dictionary = valid.duplicate(true)
	bad_command["command_schedule"] = [{"tick": 1, "kind": "unknown_command"}]
	var command_result: Dictionary = FixtureValidator.static_preflight(bad_command, "canonical_sim_headless")
	_expect(not bool(command_result.get("ok", true)), "unsupported scheduled commands must fail preflight")


func _test_post_apply_validation() -> void:
	var expected := {"hives": 12, "towers": 0, "barracks": 0, "structure_slots": 2}
	var matching: Dictionary = FixtureValidator.validate_post_apply(expected, expected.duplicate(true))
	_expect(bool(matching.get("ok", false)), "matching post-apply counts must pass")
	var actual := expected.duplicate(true)
	actual["hives"] = 11
	var mismatch: Dictionary = FixtureValidator.validate_post_apply(expected, actual)
	_expect(not bool(mismatch.get("ok", true)), "post-apply count mismatch must fail")


func _test_canonical_runner_source_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(source.contains("PERF_RUN_POLICY.enabled_for_runtime(OS.is_debug_build(), user_args)"), "runner must enforce policy before setup")
	_expect(not source.contains("__p24.json"), "runner must not retain nonexistent p24 fixture paths")
	_expect(not source.contains("func _default_gates()"), "canonical runner must not carry a second gate default")
	_expect(source.contains("renderer_configuration_state"), "renderer visibility must be labeled configuration state")
	_expect(not source.contains("top_render_sections"), "renderer visibility must not be reported as timed render sections")


func _scenario(map_path: String, expected_counts: Dictionary) -> Dictionary:
	return {
		"scenario_id": "gate_a_fixture",
		"fixture_version": 1,
		"map_path": map_path,
		"duration_sec": 5.0,
		"tick_count": 50,
		"warmup_ticks": 10,
		"seed": 4101,
		"systems": ["ops_events", "lane_flow"],
		"renderers": ["floor", "hive", "lane", "unit"],
		"expected_counts": expected_counts.duplicate(true),
		"initial_lanes": 1,
		"initial_swarms": 0,
		"initial_barracks_routes": 0,
		"command_interval_ticks": 5,
		"commands_per_burst": 1,
		"swarm_burst": 0,
		"command_schedule": [],
		"camera_schedule": []
	}


func _cleanup_temp_file() -> void:
	var absolute: String = ProjectSettings.globalize_path(TEMP_BAD_GATES)
	if FileAccess.file_exists(TEMP_BAD_GATES):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_A_SMOKE: %s" % message)
