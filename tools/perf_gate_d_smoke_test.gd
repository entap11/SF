extends SceneTree

const ResultContract := preload("res://scripts/tests/perf/perf_result_contract.gd")
const MetricsCollector := preload("res://scripts/tests/perf/perf_metrics_collector.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_schema_and_fingerprint()
	_test_explicit_unavailable_metric()
	_test_incompatible_fingerprint_refusal()
	_test_duplicate_fixture_occurrences_are_not_collapsed()
	_test_dirty_tree_approval_refusal()
	_test_fingerprint_tamper_detection()
	_test_runner_source_contracts()
	if not _failed:
		print("PERF_GATE_D_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_valid_schema_and_fingerprint() -> void:
	var report: Dictionary = _synthetic_report(false, true)
	var validation: Dictionary = ResultContract.validate_report(report)
	_expect(bool(validation.get("pass", false)), "current schema report must validate: %s" % str(validation.get("errors", [])))
	var compatibility: Dictionary = ResultContract.comparison_compatibility(report, report.duplicate(true))
	_expect(bool(compatibility.get("pass", false)), "identical fingerprints must be compatible")
	var approval: Dictionary = ResultContract.baseline_approval(report, compatibility, report)
	_expect(bool(approval.get("eligible", false)), "clean valid compatible eligible reports must pass approval policy")


func _test_explicit_unavailable_metric() -> void:
	var unsupported: Dictionary = ResultContract.unavailable_metric(
		"EXTERNAL_PROFILER_REQUIRED",
		"ms",
		"external profiler required"
	)
	_expect(not bool(unsupported.get("available", true)), "unsupported metric must be marked unavailable")
	_expect(unsupported.get("value") == null, "unsupported metric value must be null, not zero")
	_expect(str(unsupported.get("reason", "")).length() > 0, "unsupported metric must include a reason")
	var parsed: Variant = JSON.parse_string(JSON.stringify(unsupported))
	_expect(typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).get("value") == null, "unsupported metric must round-trip through JSON as null")


func _test_incompatible_fingerprint_refusal() -> void:
	var baseline: Dictionary = _synthetic_report(false, true)
	var current: Dictionary = baseline.duplicate(true)
	var scenario: Dictionary = (current.get("scenarios", []) as Array)[0] as Dictionary
	scenario["map_content_hash"] = "different_map_hash"
	ResultContract.attach_scenario_fingerprint(current, scenario)
	(current.get("scenarios", []) as Array)[0] = scenario
	var compatibility: Dictionary = ResultContract.comparison_compatibility(baseline, current)
	_expect(not bool(compatibility.get("pass", true)), "different map hashes must be incompatible")
	_expect(str(compatibility.get("status", "")) == "INCOMPATIBLE", "incompatible comparison must be explicit")
	_expect(_has_mismatch_field(compatibility, "map_content_hash"), "map hash mismatch must identify its critical field")
	var approval: Dictionary = ResultContract.baseline_approval(current, compatibility, baseline)
	_expect(not bool(approval.get("eligible", true)), "incompatible fingerprints must refuse baseline approval")
	_expect((approval.get("reasons", []) as Array).has("comparison_fingerprint_incompatible"), "approval refusal must name fingerprint incompatibility")


func _test_dirty_tree_approval_refusal() -> void:
	var clean: Dictionary = _synthetic_report(false, true)
	var dirty_current: Dictionary = _synthetic_report(true, true)
	var compatible: Dictionary = ResultContract.comparison_compatibility(clean, dirty_current)
	var current_approval: Dictionary = ResultContract.baseline_approval(dirty_current, compatible, clean)
	_expect(not bool(current_approval.get("eligible", true)), "dirty current run must be non-approvable")
	_expect((current_approval.get("reasons", []) as Array).has("dirty_worktree"), "dirty current refusal must be explicit")
	var baseline_approval: Dictionary = ResultContract.baseline_approval(clean, compatible, dirty_current)
	_expect(not bool(baseline_approval.get("eligible", true)), "dirty baseline must be non-approvable")
	_expect((baseline_approval.get("reasons", []) as Array).has("baseline_dirty_worktree"), "dirty baseline refusal must be explicit")
	var phase0: Dictionary = _synthetic_report(false, false)
	var phase0_approval: Dictionary = ResultContract.baseline_approval(phase0)
	_expect(not bool(phase0_approval.get("eligible", true)), "Phase 0 integrity fixture must remain non-approvable")


func _test_duplicate_fixture_occurrences_are_not_collapsed() -> void:
	var baseline: Dictionary = _synthetic_report(false, true)
	var baseline_second: Dictionary = ((baseline.get("scenarios", []) as Array)[0] as Dictionary).duplicate(true)
	baseline_second["suite_sequence_index"] = 2
	ResultContract.attach_scenario_fingerprint(baseline, baseline_second)
	(baseline.get("scenarios", []) as Array).append(baseline_second)
	baseline["scenario_count"] = 2
	var current: Dictionary = baseline.duplicate(true)
	var current_first: Dictionary = (current.get("scenarios", []) as Array)[0] as Dictionary
	current_first["map_content_hash"] = "first_occurrence_changed"
	ResultContract.attach_scenario_fingerprint(current, current_first)
	(current.get("scenarios", []) as Array)[0] = current_first
	var compatibility: Dictionary = ResultContract.comparison_compatibility(baseline, current)
	_expect(not bool(compatibility.get("pass", true)), "the first of duplicate fixture occurrences must not be overwritten by the second")
	_expect(_has_mismatch_field(compatibility, "map_content_hash"), "duplicate occurrence mismatch must retain field evidence")


func _test_fingerprint_tamper_detection() -> void:
	var report: Dictionary = _synthetic_report(false, true)
	var scenario: Dictionary = (report.get("scenarios", []) as Array)[0] as Dictionary
	var fingerprint: Dictionary = scenario.get("comparison_fingerprint", {}) as Dictionary
	fingerprint["hash"] = "tampered"
	scenario["comparison_fingerprint"] = fingerprint
	(report.get("scenarios", []) as Array)[0] = scenario
	var validation: Dictionary = ResultContract.validate_report(report)
	_expect(not bool(validation.get("pass", true)), "tampered fingerprint hash must invalidate the report")
	_expect((validation.get("errors", []) as Array).has("scenario_0_fingerprint_hash_invalid"), "tamper error must identify fingerprint hash")


func _test_runner_source_contracts() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var comparator: String = FileAccess.get_file_as_string("res://scripts/tests/perf/perf_baseline_comparator.gd")
	_expect(runner.contains("--collection-level="), "runner must parse the collection-level identity")
	_expect(runner.contains("PERF_BASELINE_COMPARATOR.compare"), "runner must use the shared baseline comparator")
	_expect(comparator.contains("comparison_compatibility"), "shared comparator must check compatibility before comparing metrics")
	_expect(comparator.contains("median_of_repetition_summaries"), "repeated runs must compare median summaries")
	_expect(runner.contains("render_windowed_requires_display"), "windowed render timing must refuse headless execution")
	_expect(runner.contains("baseline_missing_or_invalid_json"), "missing baseline must not silently skip comparison")


func _synthetic_report(dirty: bool, baseline_eligible: bool) -> Dictionary:
	var scenario := {
		"scenario_id": "GATE_D_SYNTHETIC_V1",
		"fixture_id": "GATE_D_SYNTHETIC_V1",
		"fixture_version": 1,
		"catalog_fixture_registered": true,
		"fixture_config_hash": "fixture_hash",
		"repetition_index": 1,
		"benchmark_mode": "canonical_sim_headless",
		"map_content_hash": "map_hash",
		"command_schedule_hash": "command_hash",
		"warmup_duration_sec": 1.0,
		"measurement_duration_sec": 4.0,
		"average_tick_ms": 1.0,
		"p95_tick_ms": 2.0,
		"p99_tick_ms": 3.0,
		"max_tick_ms": 4.0,
		"baseline_eligible": baseline_eligible,
		"collection_level": "MINIMAL",
		"collection": _synthetic_collection(),
		"metrics": {
			"simulation_tick_average_ms": ResultContract.metric("DERIVED", 1.0, "ms", "synthetic samples"),
			"gpu_frame_time_ms": ResultContract.unavailable_metric("EXTERNAL_PROFILER_REQUIRED", "ms", "external profiler required")
		}
	}
	var report := {
		"report_type": "sf_perf_benchmark_suite",
		"result_schema_version": ResultContract.RESULT_SCHEMA_VERSION,
		"run_status": "COMPLETED",
		"integrity_status": "PASS",
		"suite_id": "gate_d_synthetic",
		"benchmark_mode": "canonical_sim_headless",
		"collection_level": "MINIMAL",
		"generated_at_unix": 1,
		"git": {"commit": "abc123", "branch": "test", "dirty": dirty},
		"godot": {"string": "4.2.2.stable"},
		"machine": {"os": "Synthetic"},
		"fixture_catalog": _synthetic_catalog_identity(),
		"build": {"type": "debug", "debug": true},
		"renderer": {
			"rendering_method": "gl_compatibility",
			"rendering_driver": "opengl3",
			"video_adapter": "synthetic",
			"display_server": "headless",
			"headless": true
		},
		"viewport": {
			"width": 1152,
			"height": 648,
			"content_scale_factor": 1.0,
			"stretch_mode": "viewport",
			"stretch_aspect": "keep_width"
		},
		"pacing": {"benchmark_target_fps": 30, "physics_ticks_per_second": 60},
		"scenario_count": 1,
		"scenarios": [scenario],
		"pass": true
	}
	ResultContract.attach_scenario_fingerprint(report, scenario)
	(report.get("scenarios", []) as Array)[0] = scenario
	return report


func _synthetic_collection() -> Dictionary:
	var collector := MetricsCollector.new("MINIMAL", 2, 10.0)
	collector.observe(1, 1.0)
	return collector.summary()


func _synthetic_catalog_identity() -> Dictionary:
	return {
		"schema": "sf_perf_fixture_catalog_design_v1",
		"version": 1,
		"status": "DESIGN_APPROVED_NOT_IMPLEMENTED",
		"source": "synthetic",
		"content_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		"fixture_count": 7,
		"validation": "PASS",
		"baseline_default_eligible": false
	}


func _has_mismatch_field(compatibility: Dictionary, field_name: String) -> bool:
	for mismatch_any in compatibility.get("mismatches", []) as Array:
		if typeof(mismatch_any) == TYPE_DICTIONARY and str((mismatch_any as Dictionary).get("field", "")) == field_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_D_SMOKE: %s" % message)
