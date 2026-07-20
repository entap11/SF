extends SceneTree

const ResultContract := preload("res://scripts/tests/perf/perf_result_contract.gd")
const MetricsCollector := preload("res://scripts/tests/perf/perf_metrics_collector.gd")
const BaselineComparator := preload("res://scripts/tests/perf/perf_baseline_comparator.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_shared_compatible_comparison()
	_test_fingerprint_refusal()
	_test_legacy_schema_refusal()
	_test_missing_metric_refusal()
	_test_source_migration_contracts()
	if not _failed:
		print("PERF_GATE_F_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_shared_compatible_comparison() -> void:
	var baseline: Dictionary = _synthetic_report()
	var current: Dictionary = baseline.duplicate(true)
	var comparison: Dictionary = BaselineComparator.compare(baseline, current, _gates())
	_expect(str(comparison.get("status", "")) == "PASS", "identical schema-v3 reports must compare as PASS")
	_expect(bool(comparison.get("pass", false)), "compatible shared comparison must pass")
	_expect(BaselineComparator.exit_code(comparison) == 0, "PASS must map to exit code 0")


func _test_fingerprint_refusal() -> void:
	var baseline: Dictionary = _synthetic_report()
	var current: Dictionary = baseline.duplicate(true)
	var scenario: Dictionary = (current.get("scenarios", []) as Array)[0] as Dictionary
	scenario["map_content_hash"] = "different_map_hash"
	ResultContract.attach_scenario_fingerprint(current, scenario)
	(current.get("scenarios", []) as Array)[0] = scenario
	var comparison: Dictionary = BaselineComparator.compare(baseline, current, _gates())
	_expect(str(comparison.get("status", "")) == "INCOMPATIBLE", "fingerprint mismatch must be incompatible")
	_expect(BaselineComparator.exit_code(comparison) == 2, "incompatible comparison must map to exit code 2")


func _test_legacy_schema_refusal() -> void:
	var current: Dictionary = _synthetic_report()
	var legacy := {
		"report_type": "sf_perf_benchmark_suite",
		"scenarios": current.get("scenarios", []).duplicate(true)
	}
	var comparison: Dictionary = BaselineComparator.compare(legacy, current, _gates())
	_expect(str(comparison.get("status", "")) == "INCOMPATIBLE", "unversioned legacy output must be refused")


func _test_missing_metric_refusal() -> void:
	var baseline: Dictionary = _synthetic_report()
	var current: Dictionary = baseline.duplicate(true)
	var scenario: Dictionary = (current.get("scenarios", []) as Array)[0] as Dictionary
	scenario["p99_tick_ms"] = null
	(current.get("scenarios", []) as Array)[0] = scenario
	var comparison: Dictionary = BaselineComparator.compare(baseline, current, _gates())
	_expect(str(comparison.get("status", "")) == "INCOMPATIBLE", "missing required timing must not default to zero")
	_expect(not (comparison.get("metric_errors", []) as Array).is_empty(), "missing timing refusal must carry metric evidence")


func _test_source_migration_contracts() -> void:
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	var supported_compare: String = FileAccess.get_file_as_string("res://scripts/tools/perf_compare.gd")
	var legacy_runner: String = FileAccess.get_file_as_string("res://tools/perf_benchmark_suite.gd")
	var legacy_compare: String = FileAccess.get_file_as_string("res://tools/perf_compare.gd")
	var migration_doc: String = FileAccess.get_file_as_string("res://docs/perf_harness_gate_f_migration.md")
	var exit_evidence: String = FileAccess.get_file_as_string("res://docs/swarmfront_performance_harness_v1.md")
	_expect(runner.contains("PERF_BASELINE_COMPARATOR.compare"), "canonical runner must call the shared comparator")
	_expect(supported_compare.contains("PERF_BASELINE_COMPARATOR.compare"), "offline CLI must call the shared comparator")
	_expect(supported_compare.contains("load_gate_config"), "offline CLI must fail closed through validated gates")
	_expect(not supported_compare.contains("func _regression_percent"), "offline CLI must not fork comparison math")
	_expect(legacy_runner.contains("DEPRECATED") and legacy_runner.contains("replacement"), "old runner must be an explicit deprecation shim")
	_expect(not legacy_runner.contains("MapApplier") and not legacy_runner.contains("DEFAULT_OUTPUT_PATH"), "old runner must refuse before fixture setup or output")
	_expect(legacy_compare.contains("DEPRECATED") and legacy_compare.contains("replacement"), "old comparator must be an explicit deprecation shim")
	_expect(not legacy_compare.contains("func _compare_scenario"), "old comparator must not retain fail-open comparison logic")
	_expect(migration_doc.contains("## Capability audit") and migration_doc.contains("## Invocation mapping"), "Gate F must document capability and invocation parity")
	_expect(migration_doc.contains("No migration command rewrites, upgrades, moves, or deletes historical output"), "migration must preserve historical evidence")
	_expect(exit_evidence.contains("## Architecture audit") and exit_evidence.contains("## Phase 0 file manifest"), "Phase 0 must include its required audit and file manifest")
	_expect(exit_evidence.contains("`PHASE 0 READY WITH LIMITATIONS`"), "Phase 0 evidence must carry one explicit recommendation")
	_expect(exit_evidence.contains("No production feature was optimized"), "Phase 0 evidence must confirm optimization governance")


func _synthetic_report() -> Dictionary:
	var scenario := {
		"scenario_id": "GATE_F_SYNTHETIC_V1",
		"fixture_id": "GATE_F_SYNTHETIC_V1",
		"fixture_version": 1,
		"catalog_fixture_registered": true,
		"fixture_config_hash": "fixture_hash",
		"repetition_index": 1,
		"suite_sequence_index": 1,
		"benchmark_mode": "canonical_sim_headless",
		"map_content_hash": "map_hash",
		"command_schedule_hash": "command_hash",
		"warmup_duration_sec": 1.0,
		"measurement_duration_sec": 4.0,
		"average_tick_ms": 1.0,
		"p95_tick_ms": 2.0,
		"p99_tick_ms": 3.0,
		"max_tick_ms": 4.0,
		"baseline_eligible": false,
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
		"suite_id": "gate_f_synthetic",
		"benchmark_mode": "canonical_sim_headless",
		"collection_level": "MINIMAL",
		"generated_at_unix": 1,
		"git": {"commit": "abc123", "branch": "test", "dirty": false},
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


func _gates() -> Dictionary:
	return {
		"target_fps": 30,
		"target_frame_ms": 33.33,
		"p95_max_ms": 40.0,
		"p99_max_ms": 50.0,
		"max_frame_ms": 75.0,
		"max_hitches": 0,
		"warn_regression_percent": 10.0,
		"fail_regression_percent": 20.0
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_F_SMOKE: %s" % message)
