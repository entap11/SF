extends SceneTree

const FixtureCatalog := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")

const CATALOG_PATH: String = "res://data/perf/phase1_fixture_catalog_v1.json"
const TARGETS: Array[int] = [50, 100, 200, 400]

var _failed: bool = false


func _init() -> void:
	_test_implemented_scale_catalog()
	_test_capacity_policy_drift_refused()
	_test_runner_contract()
	if not _failed:
		print("PERF_PHASE1_GATE_E_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_implemented_scale_catalog() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	_expect(bool(loaded.get("ok", false)), "implemented catalog must load: %s" % str(loaded.get("errors", [])))
	var fixtures: Dictionary = loaded.get("fixtures_by_id", {}) as Dictionary
	for target in TARGETS:
		var fixture_id: String = "UNIT_SCALE_%03d_V1" % target
		var fixture: Dictionary = fixtures.get(fixture_id, {}) as Dictionary
		_expect(str(fixture.get("status", "")) == "IMPLEMENTED", "%s must be implemented" % fixture_id)
		_expect(int(fixture.get("target_units", 0)) == target, "%s target must be exact" % fixture_id)
		_expect(int(fixture.get("initial_lanes", 0)) == 2, "%s must use two accepted lanes" % fixture_id)
		_expect(not bool(fixture.get("capacity_bypass_allowed", true)), "%s must prohibit capacity bypass" % fixture_id)
		_expect(int(fixture.get("expected_pool_capacity", 0)) == 400, "%s must use the production 400-unit pool" % fixture_id)
		_expect(int(fixture.get("expected_pool_expansions", -1)) == 0, "%s must prohibit pool expansion" % fixture_id)


func _test_capacity_policy_drift_refused() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var catalog: Dictionary = (loaded.get("catalog", {}) as Dictionary).duplicate(true)
	for fixture_any in catalog.get("fixtures", []) as Array:
		var fixture: Dictionary = fixture_any as Dictionary
		if str(fixture.get("fixture_id", "")) == "UNIT_SCALE_400_V1":
			fixture["capacity_bypass_allowed"] = true
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "capacity-bypass drift must fail closed")
	_expect((result.get("errors", []) as Array).has("unit_scale_capacity_bypass_must_be_false:UNIT_SCALE_400_V1"), "capacity-bypass refusal must be explicit")


func _test_runner_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(source.contains("phase1_unit_scale"), "runner must expose the unit-scale suite")
	_expect(source.contains("UnitSystem.spawn_unit"), "setup evidence must name the public spawn API")
	_expect(source.contains("capacity_bypass_used\": false"), "runner must record that capacity bypass was not used")
	_expect(source.contains("_wait_for_built_lanes"), "lane construction must use a condition wait")
	_expect(source.contains("fixed_sleep_used\": false"), "condition waits must record that no fixed sleep was used")
	_expect(source.contains("unexpected_renderer_pool_expansion"), "runner must fail on pool expansion")
	_expect(source.contains("unit_count_measurement_invariant_failed"), "runner must enforce exact unit count throughout measurement")
	_expect(source.contains("affects_suite_pass\": false"), "monotonic workload sanity must remain diagnostic only")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_E_SMOKE: %s" % message)
