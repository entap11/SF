extends SceneTree

const RESULT_CONTRACT := preload("res://scripts/tests/perf/perf_result_contract.gd")

const PACKAGE_SCHEMA: String = "sf_perf_phase1_baseline_package_v1"
const DEFAULT_OUTPUT_DIR: String = "res://data/perf/baselines/phase1"
const REPORT_SPECS: Array[Dictionary] = [
	{"arg": "static", "filename": "static_fixtures_windowed.json", "suite": "phase1_static_fixtures", "mode": "static_windowed_deterministic", "scenario_count": 6},
	{"arg": "normal_canonical", "filename": "normal_match_canonical.json", "suite": "phase1_normal_match", "mode": "canonical_sim_headless", "scenario_count": 3},
	{"arg": "normal_windowed", "filename": "normal_match_windowed.json", "suite": "phase1_normal_match", "mode": "deterministic_windowed_presentation", "scenario_count": 3},
	{"arg": "unit_scale", "filename": "unit_scale_windowed.json", "suite": "phase1_unit_scale", "mode": "static_windowed_deterministic", "scenario_count": 12}
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: Dictionary = _parse_args()
	var errors: Array[String] = []
	if not bool(args.get("approve", false)):
		errors.append("explicit_phase1_baseline_approval_flag_missing")
	var reports: Array[Dictionary] = []
	var source_commit: String = ""
	var catalog_hash: String = ""
	for spec in REPORT_SPECS:
		var arg_name: String = str(spec.get("arg", ""))
		var source_path: String = str(args.get(arg_name, "")).strip_edges()
		if source_path.is_empty():
			errors.append("report_argument_missing:%s" % arg_name)
			continue
		var report: Dictionary = _load_json(source_path)
		if report.is_empty():
			errors.append("report_unreadable:%s" % arg_name)
			continue
		_validate_candidate_report(report, spec, arg_name, errors)
		var report_commit: String = str((report.get("git", {}) as Dictionary).get("commit", ""))
		var report_catalog_hash: String = str((report.get("fixture_catalog", {}) as Dictionary).get("content_hash", ""))
		if source_commit.is_empty():
			source_commit = report_commit
		elif source_commit != report_commit:
			errors.append("source_commit_mismatch:%s" % arg_name)
		if catalog_hash.is_empty():
			catalog_hash = report_catalog_hash
		elif catalog_hash != report_catalog_hash:
			errors.append("catalog_hash_mismatch:%s" % arg_name)
		reports.append({"spec": spec, "source_path": source_path, "report": report})
	if not errors.is_empty():
		push_error("perf_phase1_baseline_package: %s" % str(errors))
		quit(2)
		return

	var output_dir: String = str(args.get("output_dir", DEFAULT_OUTPUT_DIR)).strip_edges()
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var manifest_reports: Array = []
	for row in reports:
		var spec: Dictionary = row.get("spec", {}) as Dictionary
		var report: Dictionary = row.get("report", {}) as Dictionary
		var destination: String = "%s/%s" % [output_dir.trim_suffix("/"), str(spec.get("filename", ""))]
		if not _write_json(destination, report):
			push_error("perf_phase1_baseline_package: write_failed:%s" % destination)
			quit(2)
			return
		manifest_reports.append({
			"suite_id": str(report.get("suite_id", "")),
			"benchmark_mode": str(report.get("benchmark_mode", "")),
			"path": destination,
			"sha256": FileAccess.get_sha256(destination),
			"scenario_count": int(report.get("scenario_count", 0)),
			"baseline_approval": str((report.get("baseline_approval", {}) as Dictionary).get("status", "")),
			"scenario_identities": _scenario_identities(report)
		})
	var first_report: Dictionary = (reports[0] as Dictionary).get("report", {}) as Dictionary
	var manifest: Dictionary = {
		"package_schema": PACKAGE_SCHEMA,
		"package_version": 1,
		"status": "APPROVED",
		"approval_scope": "Phase 1 approved clean-tree product fixture baselines",
		"generated_at_unix": Time.get_unix_time_from_system(),
		"source_commit": source_commit,
		"source_branch": str((first_report.get("git", {}) as Dictionary).get("branch", "")),
		"fixture_catalog": (first_report.get("fixture_catalog", {}) as Dictionary).duplicate(true),
		"required_collection_level": "MINIMAL",
		"required_repetitions": 3,
		"reports": manifest_reports,
		"deferred": ["moving UNIT_SCALE profile", "3-player fixtures", "4-player fixtures", "multi-map or multi-stage async fixtures"]
	}
	var manifest_path: String = "%s/manifest.json" % output_dir.trim_suffix("/")
	if not _write_json(manifest_path, manifest):
		push_error("perf_phase1_baseline_package: manifest_write_failed")
		quit(2)
		return
	print("perf_phase1_baseline_package: %s" % JSON.stringify({"status": "APPROVED", "manifest": manifest_path, "source_commit": source_commit, "reports": manifest_reports.size()}))
	quit(0)


func _validate_candidate_report(report: Dictionary, spec: Dictionary, label: String, errors: Array[String]) -> void:
	var validation: Dictionary = RESULT_CONTRACT.validate_report(report)
	if not bool(validation.get("pass", false)):
		errors.append("result_schema_invalid:%s" % label)
	if str(report.get("suite_id", "")) != str(spec.get("suite", "")):
		errors.append("suite_mismatch:%s" % label)
	if str(report.get("benchmark_mode", "")) != str(spec.get("mode", "")):
		errors.append("benchmark_mode_mismatch:%s" % label)
	if int(report.get("scenario_count", -1)) != int(spec.get("scenario_count", -2)):
		errors.append("scenario_count_mismatch:%s" % label)
	if str(report.get("collection_level", "")) != "MINIMAL":
		errors.append("collection_level_not_minimal:%s" % label)
	if not bool(report.get("pass", false)) or str(report.get("run_status", "")) != "COMPLETED" or str(report.get("integrity_status", "")) != "PASS":
		errors.append("candidate_run_not_passed:%s" % label)
	if not bool((report.get("baseline_approval", {}) as Dictionary).get("eligible", false)):
		errors.append("baseline_approval_refused:%s" % label)
	if not bool((report.get("runtime_baseline_eligibility", {}) as Dictionary).get("eligible", false)):
		errors.append("runtime_eligibility_refused:%s" % label)
	var git: Dictionary = report.get("git", {}) as Dictionary
	if bool(git.get("dirty", true)) or str(git.get("commit", "")).is_empty():
		errors.append("candidate_git_state_not_clean:%s" % label)


func _scenario_identities(report: Dictionary) -> Array:
	var identities: Array = []
	for scenario_any in report.get("scenarios", []) as Array:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		identities.append({
			"fixture_id": str(scenario.get("fixture_id", "")),
			"fixture_version": int(scenario.get("fixture_version", 0)),
			"measurement_profile": str(scenario.get("measurement_profile", "")),
			"repetition_index": int(scenario.get("repetition_index", 0)),
			"content_identity": str(scenario.get("content_identity", "")),
			"fixture_config_hash": str(scenario.get("fixture_config_hash", "")),
			"environment_compatibility_hash": str(scenario.get("environment_compatibility_hash", "")),
			"camera_identity_hash": str(scenario.get("camera_identity_hash", "")),
			"cadence_identity_hash": str(scenario.get("cadence_identity_hash", ""))
		})
	return identities


func _parse_args() -> Dictionary:
	var out: Dictionary = {"output_dir": DEFAULT_OUTPUT_DIR, "approve": false}
	for arg_any in OS.get_cmdline_user_args():
		var arg: String = str(arg_any)
		if arg == "--approve-phase1-baselines":
			out["approve"] = true
		elif arg.begins_with("--output-dir="):
			out["output_dir"] = arg.trim_prefix("--output-dir=")
		else:
			for spec in REPORT_SPECS:
				var key: String = str(spec.get("arg", ""))
				var prefix: String = "--%s=" % key.replace("_", "-")
				if arg.begins_with(prefix):
					out[key] = arg.trim_prefix(prefix)
	return out


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true
