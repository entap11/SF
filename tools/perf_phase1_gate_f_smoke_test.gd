extends SceneTree

const BaselineEligibility := preload("res://scripts/tests/perf/perf_baseline_eligibility.gd")
const FixtureCatalog := preload("res://scripts/tests/perf/perf_fixture_catalog.gd")
const ResultContract := preload("res://scripts/tests/perf/perf_result_contract.gd")

const CATALOG_PATH: String = "res://data/perf/phase1_fixture_catalog_v1.json"
const BASELINE_MANIFEST_PATH: String = "res://data/perf/baselines/phase1/manifest.json"

var _failed: bool = false


func _init() -> void:
	_test_clean_runtime_eligibility()
	_test_dirty_tree_refused()
	_test_repetition_drift_refused()
	_test_catalog_and_packager_contract()
	_test_approved_baseline_package()
	if not _failed:
		print("PERF_PHASE1_GATE_F_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_clean_runtime_eligibility() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var report: Dictionary = _normal_report(false, 3)
	var result: Dictionary = BaselineEligibility.apply(report, loaded.get("catalog", {}) as Dictionary, loaded.get("fixtures_by_id", {}) as Dictionary)
	_expect(bool(result.get("eligible", false)), "clean three-repetition approved profile must become runtime eligible: %s" % str(result.get("global_reasons", [])))
	for scenario_any in report.get("scenarios", []) as Array:
		_expect(bool((scenario_any as Dictionary).get("baseline_eligible", false)), "every clean repetition must be eligible")


func _test_dirty_tree_refused() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var report: Dictionary = _normal_report(true, 3)
	var result: Dictionary = BaselineEligibility.apply(report, loaded.get("catalog", {}) as Dictionary, loaded.get("fixtures_by_id", {}) as Dictionary)
	_expect(not bool(result.get("eligible", true)), "dirty worktree must be refused")
	_expect((result.get("global_reasons", []) as Array).has("dirty_worktree"), "dirty refusal must be explicit")


func _test_repetition_drift_refused() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	var report: Dictionary = _normal_report(false, 2)
	var result: Dictionary = BaselineEligibility.apply(report, loaded.get("catalog", {}) as Dictionary, loaded.get("fixtures_by_id", {}) as Dictionary)
	_expect(not bool(result.get("eligible", true)), "two repetitions must be refused")
	_expect(str(result.get("global_reasons", [])).contains("repetition_count_not_exact"), "repetition refusal must be explicit")


func _test_catalog_and_packager_contract() -> void:
	var loaded: Dictionary = FixtureCatalog.load_catalog(CATALOG_PATH)
	_expect(bool(loaded.get("ok", false)), "completed catalog must validate")
	_expect(str((loaded.get("catalog", {}) as Dictionary).get("status", "")) == "IMPLEMENTED", "Phase 1 catalog must be implemented")
	for fixture_any in (loaded.get("catalog", {}) as Dictionary).get("fixtures", []) as Array:
		_expect(str((fixture_any as Dictionary).get("status", "")) == "IMPLEMENTED", "implemented catalog cannot contain design-only fixtures")
	var runner_source: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var package_source: String = FileAccess.get_file_as_string("res://scripts/tools/perf_phase1_baseline_package.gd")
	_expect(runner_source.contains("PERF_BASELINE_ELIGIBILITY.apply"), "runner must apply fail-closed runtime eligibility")
	_expect(package_source.contains("--approve-phase1-baselines"), "packager must require explicit approval")
	_expect(package_source.contains("baseline_approval_refused"), "packager must refuse ineligible reports")
	_expect(package_source.contains("source_commit_mismatch"), "package must come from one clean source commit")


func _test_approved_baseline_package() -> void:
	var manifest: Dictionary = _load_json(BASELINE_MANIFEST_PATH)
	_expect(not manifest.is_empty(), "approved baseline manifest must exist")
	_expect(str(manifest.get("package_schema", "")) == "sf_perf_phase1_baseline_package_v1", "baseline package schema must be frozen")
	_expect(str(manifest.get("status", "")) == "APPROVED", "baseline package must be explicitly approved")
	var source_commit: String = str(manifest.get("source_commit", ""))
	_expect(not source_commit.is_empty(), "baseline package source commit must be recorded")
	var reports: Array = manifest.get("reports", []) as Array
	_expect(reports.size() == 4, "baseline package must contain four approved profile reports")
	for report_row_any in reports:
		var report_row: Dictionary = report_row_any as Dictionary
		var path: String = str(report_row.get("path", ""))
		_expect(FileAccess.file_exists(path), "packaged report must exist: %s" % path)
		_expect(FileAccess.get_sha256(path) == str(report_row.get("sha256", "")), "packaged report hash must match: %s" % path)
		var report: Dictionary = _load_json(path)
		_expect(bool(ResultContract.validate_report(report).get("pass", false)), "packaged report schema must validate: %s" % path)
		_expect(bool((report.get("baseline_approval", {}) as Dictionary).get("eligible", false)), "packaged report must retain eligible approval: %s" % path)
		_expect(str((report.get("git", {}) as Dictionary).get("commit", "")) == source_commit, "packaged report must share source commit: %s" % path)
		for identity_any in report_row.get("scenario_identities", []) as Array:
			var identity: Dictionary = identity_any as Dictionary
			_expect(not str(identity.get("fixture_config_hash", "")).is_empty(), "manifest fixture identity hash must be present")
			_expect(not str(identity.get("environment_compatibility_hash", "")).is_empty(), "manifest environment identity hash must be present")
			_expect(identity.has("camera_identity") and identity.has("cadence_identity"), "manifest must carry camera and cadence identities")


func _normal_report(dirty: bool, repetitions: int) -> Dictionary:
	var scenarios: Array = []
	for repetition_index in range(1, repetitions + 1):
		scenarios.append({
			"fixture_id": "NORMAL_MATCH_V1",
			"measurement_profile": "canonical_sim_headless",
			"repetition_index": repetition_index,
			"catalog_fixture_registered": true,
			"collection_level": "MINIMAL",
			"pass": true,
			"integrity_failures": [],
			"isolation_cleanup": {"pass": true},
			"fixture_setup_evidence": {"exact_counts": true},
			"fixture_config_hash": "fixture_hash",
			"final_state_hash": "state_hash"
		})
	return {
		"suite_id": "phase1_normal_match",
		"benchmark_mode": "canonical_sim_headless",
		"collection_level": "MINIMAL",
		"run_status": "COMPLETED",
		"integrity_status": "PASS",
		"pass": true,
		"git": {"dirty": dirty, "commit": "abc123"},
		"determinism": {"pass": true},
		"isolation": {"pass": true},
		"backend_isolation": {"pass": true},
		"scenarios": scenarios
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_PHASE1_GATE_F_SMOKE: %s" % message)


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
