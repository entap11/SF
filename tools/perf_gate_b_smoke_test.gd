extends SceneTree

const DeterministicHash := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")
const FixtureValidator := preload("res://scripts/tests/perf/perf_fixture_validator.gd")

const QUICK_MAP: String = "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__2p.json"

var _failed: bool = false


func _init() -> void:
	_test_deterministic_hash()
	_test_execution_mode_contract()
	_test_canonical_runner_source_contract()
	_test_seed_override_source_contract()
	if not _failed:
		print("PERF_GATE_B_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_deterministic_hash() -> void:
	var first: Dictionary = {
		"fixture": "centerstrike",
		"seed": 4101,
		"commands": [{"tick": 5, "type": "attack"}, {"tick": 15, "type": "swarm"}]
	}
	var reordered: Dictionary = {
		"commands": [{"type": "attack", "tick": 5}, {"type": "swarm", "tick": 15}],
		"seed": 4101,
		"fixture": "centerstrike"
	}
	var changed: Dictionary = reordered.duplicate(true)
	changed["seed"] = 4102
	var first_hash: String = DeterministicHash.hash_variant(first)
	_expect(first_hash.length() == 64, "deterministic hash must be SHA-256")
	_expect(first_hash == DeterministicHash.hash_variant(reordered), "dictionary insertion order must not affect the hash")
	_expect(first_hash != DeterministicHash.hash_variant(changed), "state changes must affect the hash")


func _test_execution_mode_contract() -> void:
	var scenario: Dictionary = _scenario()
	var canonical: Dictionary = FixtureValidator.static_preflight(scenario, "canonical_sim_headless")
	_expect(bool(canonical.get("ok", false)), "canonical simulation mode must pass preflight: %s" % str(canonical.get("errors", [])))
	var isolation: Dictionary = FixtureValidator.static_preflight(scenario, "layer_isolation_noncanonical")
	_expect(bool(isolation.get("ok", false)), "noncanonical layer-isolation mode must remain available for investigation")
	var legacy: Dictionary = FixtureValidator.static_preflight(scenario, "full_simulation")
	_expect(not bool(legacy.get("ok", true)), "ambiguous legacy simulation labels must fail preflight")


func _test_canonical_runner_source_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(source.contains("sim_runner.call(\"_tick\", SIM_TICK_INTERVAL_SEC)"), "canonical mode must step SimRunner._tick directly")
	_expect(source.contains("sim_runner.set_process(false)"), "canonical mode must disable automatic SimRunner processing")
	_expect(source.contains("layer_isolation_noncanonical"), "the selective phase loop must be explicitly noncanonical")
	_expect(source.contains("OpsState.call(\"get_contract_state_hash\")"), "canonical evidence must use the OpsState contract hash")
	_expect(source.contains("_determinism_evidence"), "suite output must compare repeated fixture evidence")
	_expect(source.contains("required_repetition_count"), "determinism evidence must declare its repetition contract")


func _test_seed_override_source_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/arena.gd")
	_expect(source.contains("func set_perf_match_seed_override(seed_value: int) -> bool:"), "Arena must expose the benchmark seed seam")
	_expect(source.contains("not OS.is_debug_build()"), "the seed seam must reject release builds")
	_expect(source.contains("tree.get_meta(\"sf_perf_harness_active\", false)"), "the seed seam must require the active harness marker")
	_expect(source.contains("if _perf_match_seed_override_enabled:"), "normal seed computation must only change when the override is explicitly enabled")


func _scenario() -> Dictionary:
	return {
		"scenario_id": "gate_b_fixture",
		"fixture_version": 1,
		"map_path": QUICK_MAP,
		"duration_sec": 5.0,
		"seed": 4101,
		"tick_count": 50,
		"warmup_ticks": 10,
		"repetitions": 3,
		"systems": ["canonical_simrunner"],
		"renderers": ["floor", "hive", "lane", "unit"],
		"expected_counts": {"hives": 12, "towers": 0, "barracks": 0, "structure_slots": 0},
		"initial_lanes": 4,
		"initial_swarms": 0,
		"initial_barracks_routes": 0,
		"command_interval_ticks": 5,
		"commands_per_burst": 1,
		"swarm_burst": 0,
		"command_schedule": [{"tick": 5, "kind": "lane_intent_pair", "pair_index": 0, "intent": "attack"}],
		"camera_schedule": []
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_B_SMOKE: %s" % message)
