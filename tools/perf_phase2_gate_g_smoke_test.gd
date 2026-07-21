extends SceneTree

const RESULT_CONTRACT := preload("res://scripts/tests/perf/perf_result_contract.gd")
const BASELINE_MANIFEST_PATH: String = "res://data/perf/baselines/harness_v1/manifest.json"
const EXIT_PATH: String = "res://data/perf/harness_v1_exit.json"
const PROGRAM_PATH: String = "res://data/perf/harness_v1_completion_program.json"
const EXIT_DOC_PATH: String = "res://docs/swarmfront_performance_harness_v1_exit.md"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = _load_json(BASELINE_MANIFEST_PATH)
	var exit_decision: Dictionary = _load_json(EXIT_PATH)
	var program: Dictionary = _load_json(PROGRAM_PATH)
	_validate_manifest(manifest, exit_decision)
	_validate_exit(exit_decision)
	_validate_program(program)
	_validate_external_workflow()
	if _failures.is_empty():
		print("PERF_PHASE2_GATE_G_SMOKE: PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error("PERF_PHASE2_GATE_G_SMOKE: %s" % failure)
		quit(1)


func _validate_manifest(manifest: Dictionary, exit_decision: Dictionary) -> void:
	_expect(str(manifest.get("package_schema", "")) == "sf_perf_phase1_baseline_package_v1", "Harness V1 package schema changed")
	_expect(str(manifest.get("status", "")) == "APPROVED", "Harness V1 package must be approved")
	_expect(str(manifest.get("required_collection_level", "")) == "MINIMAL", "approved package must use MINIMAL collection")
	_expect(int(manifest.get("required_repetitions", 0)) == 3, "approved package must require three repetitions")
	var source_commit: String = str(manifest.get("source_commit", ""))
	_expect(not source_commit.is_empty(), "package source commit must be recorded")
	_expect(source_commit == str(exit_decision.get("candidate_source_commit", "")), "package and exit source commits must match")
	var reports: Array = manifest.get("reports", []) as Array
	_expect(reports.size() == 4, "only four eligible profile families may be packaged")
	var total_scenarios: int = 0
	for report_row_any in reports:
		var report_row: Dictionary = report_row_any as Dictionary
		var suite_id: String = str(report_row.get("suite_id", ""))
		_expect(not suite_id.begins_with("phase2_"), "Phase 2 diagnostic suite must not be packaged: %s" % suite_id)
		var path: String = str(report_row.get("path", ""))
		_expect(path.begins_with("res://data/perf/baselines/harness_v1/"), "report must stay in curated Harness V1 package: %s" % path)
		_expect(FileAccess.file_exists(path), "packaged report missing: %s" % path)
		if not FileAccess.file_exists(path):
			continue
		_expect(FileAccess.get_sha256(path) == str(report_row.get("sha256", "")), "packaged report hash mismatch: %s" % path)
		var report: Dictionary = _load_json(path)
		_expect(bool(RESULT_CONTRACT.validate_report(report).get("pass", false)), "packaged report schema invalid: %s" % path)
		_expect(bool(report.get("pass", false)), "packaged report did not pass: %s" % path)
		_expect(bool((report.get("baseline_approval", {}) as Dictionary).get("eligible", false)), "packaged report not baseline eligible: %s" % path)
		_expect(bool((report.get("runtime_baseline_eligibility", {}) as Dictionary).get("eligible", false)), "packaged report not runtime eligible: %s" % path)
		var git: Dictionary = report.get("git", {}) as Dictionary
		_expect(not bool(git.get("dirty", true)), "packaged report source must be clean: %s" % path)
		_expect(str(git.get("commit", "")) == source_commit, "packaged report source commit mismatch: %s" % path)
		total_scenarios += int(report.get("scenario_count", 0))
	_expect(total_scenarios == 24, "approved package must contain exactly 24 scenario repetitions")


func _validate_exit(exit_decision: Dictionary) -> void:
	_expect(str(exit_decision.get("exit_schema", "")) == "sf_perf_harness_v1_exit_v1", "exit schema changed")
	_expect(str(exit_decision.get("status", "")) == "COMPLETE", "exit status must be complete")
	_expect(str(exit_decision.get("recommendation", "")) == "HARNESS V1 READY WITH LIMITATIONS", "exit recommendation must be exact")
	var matrix: Dictionary = exit_decision.get("exit_matrix", {}) as Dictionary
	_expect(int(matrix.get("focused_gates_before_gate_g", 0)) == 18, "pre-G focused gate count changed")
	_expect(int(matrix.get("focused_gates_total", 0)) == 19, "final focused gate count changed")
	_expect(int(matrix.get("real_scenario_runs", 0)) == 95, "exit scenario count changed")
	_expect(int(matrix.get("failed_scenario_runs", -1)) == 0, "exit cannot report failed scenarios")
	var baseline_package: Dictionary = exit_decision.get("baseline_package", {}) as Dictionary
	_expect(int(baseline_package.get("self_comparisons_passed", 0)) == 4, "all packaged profiles must self-compare")
	var device: Dictionary = exit_decision.get("device_evidence", {}) as Dictionary
	_expect(str(device.get("status", "")) == "UNAVAILABLE", "uncollected device evidence must remain explicit")
	_expect((device.get("missing", []) as Array).size() == 3, "GPU, thermal, and energy gaps must all be disclosed")
	_expect((exit_decision.get("limitations", []) as Array).size() >= 5, "exit limitations must not be omitted")


func _validate_program(program: Dictionary) -> void:
	_expect(str(program.get("status", "")) == "COMPLETE", "completion program must be complete")
	var phases: Array = program.get("phases", []) as Array
	_expect(phases.size() == 7, "completion program must retain seven exact phases")
	for phase_any in phases:
		var phase: Dictionary = phase_any as Dictionary
		_expect(str(phase.get("status", "")) == "IMPLEMENTED", "phase not implemented: %s" % str(phase.get("phase_id", "")))


func _validate_external_workflow() -> void:
	var exit_doc: String = FileAccess.get_file_as_string(EXIT_DOC_PATH)
	_expect(exit_doc.contains("HARNESS V1 READY WITH LIMITATIONS"), "exit document recommendation missing")
	_expect(exit_doc.contains("xcrun xctrace record --template 'Metal System Trace'"), "iOS Metal workflow missing")
	_expect(exit_doc.contains("xcrun xctrace record --template 'Time Profiler'"), "iOS CPU workflow missing")
	_expect(exit_doc.contains("adb shell dumpsys thermalservice"), "Android thermal workflow missing")
	_expect(exit_doc.contains("adb shell dumpsys batterystats"), "Android energy workflow missing")
	_expect(exit_doc.contains("Android GPU Inspector"), "Android GPU workflow missing")
	_expect(exit_doc.contains("missing `assets/sprites/sf_skin_v1/barracks.PNG`"), "known missing asset limitation must remain explicit")


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
