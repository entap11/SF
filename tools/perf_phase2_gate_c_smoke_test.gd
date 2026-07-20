extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var validator: String = FileAccess.get_file_as_string("res://scripts/tests/perf/perf_fixture_validator.gd")
	var growth_rules: String = FileAccess.get_file_as_string("res://scripts/sim/hive_growth_rules.gd")
	var swarm_system: String = FileAccess.get_file_as_string("res://scripts/systems/swarm_system.gd")
	var vfx_manager: String = FileAccess.get_file_as_string("res://scripts/vfx/vfx_manager.gd")
	_expect(runner.contains("phase2_upgrade_swarm_stress"), "runner must expose the P2-C suite")
	_expect(runner.contains("HIVE_UPGRADE_STORM_V1"), "hive upgrade fixture must exist")
	_expect(runner.contains("SUPER_SWARM_CHAIN_V1"), "Super Swarm fixture must exist")
	_expect(runner.contains("OpsState.apply_lane_intent(src_id, dst_id, intent)"), "exact lanes must use the production intent API")
	_expect(runner.contains("OpsState.apply_lane_intent(src_id, dst_id, \"swarm\")"), "exact swarms must use the production intent API")
	_expect(runner.contains("phase2_event_hash"), "P2-C must emit deterministic event evidence")
	_expect(runner.contains("growth_visible_ring_count"), "P2-C must measure hive ring VFX lifecycle")
	_expect(runner.contains("super_swarm_chain_ledger_not_observed"), "Super Swarm must prove the production carry ledger")
	_expect(runner.contains("DISABLE_GPU_VFX_AUTO_FALLBACK_ENV"), "runner must stabilize automatic VFX fallback")
	_expect(runner.contains("OS.unset_environment(DISABLE_GPU_VFX_AUTO_FALLBACK_ENV)"), "runner must restore an initially absent VFX fallback environment control")
	_expect(vfx_manager.contains("SF_DISABLE_GPU_VFX_AUTO_FALLBACK"), "VFX manager must honor the harness fallback control")
	_expect(validator.contains("exact_lane_intent"), "validator must fail closed over exact lane commands")
	_expect(validator.contains("exact_swarm_intent"), "validator must fail closed over exact swarm commands")
	_expect(growth_rules.contains("TIER_MEDIUM_MIN_POWER: int = 10"), "medium threshold changed from the fixture contract")
	_expect(growth_rules.contains("TIER_LARGE_MIN_POWER: int = 25"), "large threshold changed from the fixture contract")
	_expect(swarm_system.contains("SWARM_MAX_START := 5"), "Super Swarm start cap changed from the fixture contract")
	_expect(swarm_system.contains("SWARM_CHAIN_WINDOW_MS: int = 1000"), "Super Swarm chain window changed from the fixture contract")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/perf/harness_v1_completion_program.json"))
	_expect(typeof(parsed) == TYPE_DICTIONARY, "completion program must parse")
	if typeof(parsed) == TYPE_DICTIONARY:
		var phase: Dictionary = _phase_by_id(parsed as Dictionary, "P2_C_UPGRADE_AND_SWARM_STRESS")
		_expect(not phase.is_empty(), "P2-C contract must exist")
		var fixtures: Array = phase.get("fixtures", []) as Array
		_expect(fixtures == ["HIVE_UPGRADE_STORM_V1", "SUPER_SWARM_CHAIN_V1"], "P2-C fixture inventory must remain exact")
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_C_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_C_SMOKE: %s" % failure)
		quit(1)

func _phase_by_id(program: Dictionary, phase_id: String) -> Dictionary:
	for phase_any in program.get("phases", []) as Array:
		if typeof(phase_any) == TYPE_DICTIONARY and str((phase_any as Dictionary).get("phase_id", "")) == phase_id:
			return phase_any as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
