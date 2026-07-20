extends SceneTree

const FixtureCatalog := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")

const CATALOG_PATH: String = "res://data/perf/phase1_fixture_catalog_v1.json"

var _failed: bool = false


func _init() -> void:
	_test_frozen_normal_match_catalog()
	_test_schedule_drift_refused()
	_test_runner_contract()
	if not _failed:
		print("PERF_PHASE1_GATE_D_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_frozen_normal_match_catalog() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	_expect(bool(loaded.get("ok", false)), "catalog with frozen normal match must load: %s" % str(loaded.get("errors", [])))
	var fixture: Dictionary = (loaded.get("fixtures_by_id", {}) as Dictionary).get("NORMAL_MATCH_V1", {}) as Dictionary
	_expect(str(fixture.get("status", "")) == "IMPLEMENTED", "normal match must be marked implemented only after pilot")
	_expect(str(fixture.get("schedule_status", "")) == "FROZEN_AFTER_PILOT", "normal match schedule must be frozen")
	_expect((fixture.get("command_schedule", []) as Array).size() == 4, "frozen schedule must contain four commands")
	_expect((fixture.get("expected_accepted_commands", []) as Array).size() == 4, "catalog must record four resolved accepted commands")
	_expect(int(fixture.get("expected_command_count", 0)) == 4, "accepted command count must be exact")
	_expect(str(fixture.get("pilot_accepted_command_hash", "")).length() == 64, "pilot accepted-command hash must be recorded")
	_expect(str(fixture.get("pilot_canonical_final_state_hash", "")).length() == 64, "pilot final-state hash must be recorded")


func _test_schedule_drift_refused() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var catalog: Dictionary = (loaded.get("catalog", {}) as Dictionary).duplicate(true)
	for fixture_any in catalog.get("fixtures", []) as Array:
		var fixture: Dictionary = fixture_any as Dictionary
		if str(fixture.get("fixture_id", "")) != "NORMAL_MATCH_V1":
			continue
		var schedule: Array = fixture.get("command_schedule", []) as Array
		(schedule[0] as Dictionary)["pair_index"] = 99
	var result: Dictionary = FixtureCatalog.validate_catalog(catalog)
	_expect(not bool(result.get("ok", true)), "frozen pair-index drift must fail closed")
	_expect((result.get("errors", []) as Array).has("normal_match_schedule_not_approved"), "schedule drift refusal must be explicit")


func _test_runner_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(source.contains("phase1_normal_match"), "runner must expose the registered normal-match suite")
	_expect(source.contains("expected_command_count_exact"), "normal-match runner must enforce exact accepted-command count")
	_expect(source.contains("accepted_command_evidence_mismatch"), "normal-match runner must enforce resolved command meaning")
	_expect(source.contains("canonical_final_state_hash_mismatch"), "canonical profile must enforce the frozen pilot state hash")
	_expect(source.contains("_disable_bots_for_benchmark"), "normal match must explicitly disable automatic bots")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_D_SMOKE: %s" % message)
