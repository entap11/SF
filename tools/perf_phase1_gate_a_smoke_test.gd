extends SceneTree

const FixtureCatalog := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")
const ResultContract := preload("res://scripts/tests/perf/perf_result_contract.gd")

const CATALOG_PATH: String = "res://data/perf/phase1_fixture_catalog_v1.json"
const TEMP_MALFORMED_CATALOG: String = "user://perf_phase1_gate_a_malformed_catalog.json"

var _failed: bool = false


func _init() -> void:
	_test_approved_catalog_loads()
	_test_file_loading_fails_closed()
	_test_duplicate_fixture_refused()
	_test_unknown_profile_refused()
	_test_map_hash_mismatch_refused()
	_test_capacity_violation_refused()
	_test_fixture_identity_drift_refused()
	_test_default_eligibility_refused()
	_test_schema_v3_identity_contract()
	_test_runner_loads_registry_before_fixture_selection()
	_cleanup_temp_file()
	if not _failed:
		print("PERF_PHASE1_GATE_A_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_approved_catalog_loads() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	_expect(bool(loaded.get("ok", false)), "approved Phase 1 catalog must load: %s" % str(loaded.get("errors", [])))
	var identity: Dictionary = loaded.get("identity", {}) as Dictionary
	_expect(str(identity.get("validation", "")) == "PASS", "loaded catalog identity must record validation PASS")
	_expect(str(identity.get("content_hash", "")).length() == 64, "loaded catalog must carry a SHA-256 content identity")
	_expect(int(identity.get("fixture_count", 0)) == 7, "approved catalog must contain seven concrete fixture IDs")
	var by_id: Dictionary = loaded.get("fixtures_by_id", {}) as Dictionary
	_expect(by_id.size() == 7, "registry lookup must preserve all unique fixtures")
	for fixture_any in by_id.values():
		var fixture: Dictionary = fixture_any as Dictionary
		_expect(not bool(fixture.get("baseline_eligible", true)), "design-only catalog entries must default to baseline-ineligible")


func _test_file_loading_fails_closed() -> void:
	var missing: Dictionary = FixtureCatalog.load_catalog("res://data/perf/phase1_catalog_missing.json")
	_expect(not bool(missing.get("ok", true)), "missing catalog must fail closed")
	_expect((missing.get("catalog", {}) as Dictionary).is_empty(), "missing catalog must expose no usable registry")
	var file: FileAccess = FileAccess.open(TEMP_MALFORMED_CATALOG, FileAccess.WRITE)
	_expect(file != null, "malformed catalog test file must be writable")
	if file != null:
		file.store_string("{ not valid catalog JSON")
		file.close()
	var malformed: Dictionary = FixtureCatalog.load_catalog(TEMP_MALFORMED_CATALOG)
	_expect(not bool(malformed.get("ok", true)), "malformed catalog must fail closed")
	_expect((malformed.get("fixtures_by_id", {}) as Dictionary).is_empty(), "malformed catalog must not yield fixture fallbacks")


func _test_duplicate_fixture_refused() -> void:
	var catalog: Dictionary = _approved_catalog()
	var fixtures: Array = catalog.get("fixtures", []) as Array
	fixtures.append((fixtures[0] as Dictionary).duplicate(true))
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "duplicate fixture ID must fail validation")
	_expect(_has_error_prefix(result, "fixture_id_duplicate:"), "duplicate refusal must identify the fixture ID")


func _test_unknown_profile_refused() -> void:
	var catalog: Dictionary = _approved_catalog()
	var fixture: Dictionary = (catalog.get("fixtures", []) as Array)[0] as Dictionary
	fixture["measurement_profiles"] = ["unknown_profile"]
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "unknown measurement profile must fail validation")
	_expect(_has_error_prefix(result, "fixture_profile_unsupported:"), "profile refusal must be explicit")


func _test_map_hash_mismatch_refused() -> void:
	var catalog: Dictionary = _approved_catalog()
	var common: Dictionary = catalog.get("common", {}) as Dictionary
	var production_map: Dictionary = common.get("production_map", {}) as Dictionary
	production_map["sha256"] = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "production map hash mismatch must fail validation")
	_expect((result.get("errors", []) as Array).has("production_map_hash_mismatch"), "map refusal must name the hash mismatch")


func _test_capacity_violation_refused() -> void:
	var catalog: Dictionary = _approved_catalog()
	for fixture_any in catalog.get("fixtures", []) as Array:
		var fixture: Dictionary = fixture_any as Dictionary
		if str(fixture.get("fixture_id", "")) == "UNIT_SCALE_400_V1":
			fixture["target_units"] = 401
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "unit target above production/render capacity must fail validation")
	_expect(_has_error_prefix(result, "unit_scale_target_exceeds_capacity:"), "capacity refusal must identify the fixture")


func _test_fixture_identity_drift_refused() -> void:
	var seed_catalog: Dictionary = _approved_catalog()
	var seed_fixture: Dictionary = (seed_catalog.get("fixtures", []) as Array)[0] as Dictionary
	seed_fixture["seed"] = 9999
	var seed_result: Dictionary = FixtureCatalog.validate_catalog(seed_catalog)
	_expect(not bool(seed_result.get("ok", true)), "unapproved seed drift must fail validation")
	_expect(_has_error_prefix(seed_result, "fixture_seed_not_approved:"), "seed refusal must identify the fixture")
	var timing_catalog: Dictionary = _approved_catalog()
	for fixture_any in timing_catalog.get("fixtures", []) as Array:
		var fixture: Dictionary = fixture_any as Dictionary
		if str(fixture.get("fixture_id", "")) == "NORMAL_MATCH_V1":
			(fixture.get("timing", {}) as Dictionary)["measurement_ticks"] = 99
	var timing_result: Dictionary = FixtureCatalog.validate_catalog(timing_catalog)
	_expect(not bool(timing_result.get("ok", true)), "unapproved timing drift must fail validation")
	_expect((timing_result.get("errors", []) as Array).has("normal_match_timing_not_approved"), "timing refusal must be explicit")


func _test_default_eligibility_refused() -> void:
	var catalog: Dictionary = _approved_catalog()
	var fixture: Dictionary = (catalog.get("fixtures", []) as Array)[0] as Dictionary
	fixture["baseline_eligible"] = true
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "catalog entry cannot pre-approve itself for baselines")
	_expect(_has_error_prefix(result, "fixture_must_default_ineligible:"), "eligibility refusal must identify the fixture")


func _test_schema_v3_identity_contract() -> void:
	_expect(ResultContract.RESULT_SCHEMA_VERSION == 3, "Phase 1 result contract must be schema v3")
	_expect(ResultContract.FINGERPRINT_VERSION == 2, "schema v3 must use the expanded fingerprint version")
	for field in [
		"catalog_schema",
		"catalog_version",
		"catalog_content_hash",
		"catalog_fixture_registered",
		"measurement_profile",
		"content_kind",
		"content_identity",
		"environment_compatibility_hash"
	]:
		_expect(ResultContract.COMPARISON_CRITICAL_FIELDS.has(field), "schema v3 comparison identity missing %s" % field)


func _test_runner_loads_registry_before_fixture_selection() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var catalog_load_index: int = source.find("PERF_FIXTURE_CATALOG.load_catalog")
	var fixture_selection_index: int = source.find("_scenario_definitions(suite_id")
	_expect(catalog_load_index >= 0, "canonical runner must load the Phase 1 catalog")
	_expect(fixture_selection_index > catalog_load_index, "catalog validation must occur before fixture selection or scene setup")
	_expect(source.contains("fixture_catalog_validation_failed"), "runner must expose an explicit catalog refusal")
	_expect(source.contains("DEFAULT_FIXTURE_CATALOG_PATH"), "runner must use one canonical catalog path")
	_expect(not source.contains("fixtures_by_id(catalog_result"), "P1-A must not execute Phase 1 fixtures before later gates")


func _approved_catalog() -> Dictionary:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	if not bool(loaded.get("ok", false)):
		_failed = true
		push_error("PERF_PHASE1_GATE_A_SMOKE: approved catalog unavailable for mutation tests")
		return {}
	return (loaded.get("catalog", {}) as Dictionary).duplicate(true)


func _has_error_prefix(result: Dictionary, prefix: String) -> bool:
	for error_any in result.get("errors", []) as Array:
		if str(error_any).begins_with(prefix):
			return true
	return false


func _cleanup_temp_file() -> void:
	if FileAccess.file_exists(TEMP_MALFORMED_CATALOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MALFORMED_CATALOG))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_A_SMOKE: %s" % message)
