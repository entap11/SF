extends SceneTree

const FixtureCatalog := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")
const FixtureValidator := preload("res://scripts/tests/perf/perf_fixture_validator.gd")

const CATALOG_PATH: String = "res://data/perf/phase1_fixture_catalog_v1.json"

var _failed: bool = false


func _init() -> void:
	_test_synthetic_preflight_without_map()
	_test_production_static_preflight()
	_test_synthetic_map_claim_refused()
	_test_runner_registration_contract()
	if not _failed:
		print("PERF_PHASE1_GATE_C_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_synthetic_preflight_without_map() -> void:
	var fixture: Dictionary = _fixture("EMPTY_ARENA_V1")
	var scenario: Dictionary = _base_scenario(fixture)
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = str(fixture.get("content_identity", ""))
	scenario["map_path"] = ""
	var result: Dictionary = FixtureValidator.static_preflight(scenario, "static_windowed_deterministic")
	_expect(bool(result.get("ok", false)), "empty arena must preflight without MapLoader input: %s" % str(result.get("errors", [])))
	_expect(bool(result.get("synthetic", false)), "empty arena preflight must identify synthetic content")
	_expect(str(result.get("map_content_hash", "")).is_empty(), "synthetic content must not claim a file-backed map hash")


func _test_production_static_preflight() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var catalog: Dictionary = loaded.get("catalog", {}) as Dictionary
	var common: Dictionary = catalog.get("common", {}) as Dictionary
	var production_map: Dictionary = common.get("production_map", {}) as Dictionary
	var fixture: Dictionary = _fixture("STATIC_BATTLEFIELD_V1")
	var scenario: Dictionary = _base_scenario(fixture)
	scenario["content_kind"] = "production_map"
	scenario["map_path"] = str(production_map.get("path", ""))
	var result: Dictionary = FixtureValidator.static_preflight(scenario, "static_windowed_deterministic")
	_expect(bool(result.get("ok", false)), "static battlefield must pass production MapLoader preflight: %s" % str(result.get("errors", [])))
	_expect(str(result.get("map_content_hash", "")) == str(production_map.get("sha256", "")), "static battlefield must retain the approved production map hash")
	var counts: Dictionary = result.get("expected_runtime_counts", {}) as Dictionary
	_expect(int(counts.get("hives", -1)) == 12 and int(counts.get("walls", -1)) == 2, "production preflight must normalize 12 hives and two walls")
	_expect(int(counts.get("active_lanes", -1)) == 0 and int(counts.get("units", -1)) == 0, "static production setup must begin without active lanes or units")


func _test_synthetic_map_claim_refused() -> void:
	var fixture: Dictionary = _fixture("EMPTY_ARENA_V1")
	var scenario: Dictionary = _base_scenario(fixture)
	scenario["content_kind"] = "synthetic_scene"
	scenario["content_identity"] = str(fixture.get("content_identity", ""))
	scenario["map_path"] = "res://maps/_future/centerstrike/MAP_centerstrike__SBASE__1p.json"
	var result: Dictionary = FixtureValidator.static_preflight(scenario, "static_windowed_deterministic")
	_expect(not bool(result.get("ok", true)), "synthetic fixture must fail if it claims a map path")
	_expect((result.get("errors", []) as Array).has("synthetic fixture cannot declare a map_path"), "synthetic map-path refusal must be explicit")


func _test_runner_registration_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(FixtureValidator.SUPPORTED_MODES.has("static_windowed_deterministic"), "validator must support the approved static profile")
	_expect(source.contains("phase1_static_fixtures"), "runner must expose the P1-C fixture suite")
	_expect(source.contains("_phase1_static_catalog_scenario"), "P1-C scenarios must be built from catalog entries")
	_expect(source.contains("map_loader_used"), "runner must record loader/applier setup evidence")
	_expect(source.contains("authored_scene_transform"), "empty arena must use its authored camera policy")


func _base_scenario(fixture: Dictionary) -> Dictionary:
	return {
		"scenario_id": str(fixture.get("fixture_id", "")),
		"fixture_version": int(fixture.get("fixture_version", 1)),
		"duration_sec": 12.0,
		"tick_count": 120,
		"warmup_ticks": 20,
		"repetitions": 3,
		"seed": int(fixture.get("seed", 0)),
		"systems": [],
		"renderers": [],
		"command_interval_ticks": 5,
		"command_schedule": [],
		"expected_counts": (fixture.get("expected_counts", {}) as Dictionary).duplicate(true)
	}


func _fixture(fixture_id: String) -> Dictionary:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	_expect(bool(loaded.get("ok", false)), "approved catalog must load")
	return ((loaded.get("fixtures_by_id", {}) as Dictionary).get(fixture_id, {}) as Dictionary).duplicate(true)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_C_SMOKE: %s" % message)
