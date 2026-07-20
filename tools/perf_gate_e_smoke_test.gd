extends SceneTree

const MetricsCollector := preload("res://scripts/tests/perf/perf_metrics_collector.gd")
const DeterministicHash := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")
const ResultContract := preload("res://scripts/tests/perf/perf_result_contract.gd")

var _failed: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_off_has_no_per_sample_collection()
	_test_minimal_is_bounded_without_raw_samples()
	_test_full_is_bounded_with_raw_samples()
	_test_retention_is_deterministic()
	_test_source_contracts()
	if not _failed:
		print("PERF_GATE_E_SMOKE: PASS")
	quit(1 if _failed else 0)


func _test_off_has_no_per_sample_collection() -> void:
	var collector := MetricsCollector.new("OFF", 3, 5.0, 5, 7)
	for sample_index in range(1, 21):
		collector.observe(sample_index, float(sample_index), {"probe": sample_index})
	var summary: Dictionary = collector.summary()
	_expect(not collector.timing_enabled(), "OFF must disable timing collection")
	_expect(int(summary.get("sample_count", -1)) == 0, "OFF must retain no observed samples")
	_expect(summary.get("average_ms") == null, "OFF timing summary must be null")
	_expect(int((summary.get("overhead_contract", {}) as Dictionary).get("additional_per_sample_clock_reads", -1)) == 0, "OFF must require zero additional per-sample collector clock reads")


func _test_minimal_is_bounded_without_raw_samples() -> void:
	var collector := MetricsCollector.new("MINIMAL", 3, 5.0, 5)
	for sample_index in range(1, 21):
		var duration_ms: float = float(sample_index)
		var context: Dictionary = {"probe": sample_index} if collector.needs_forensic_context(duration_ms) else {}
		collector.observe(sample_index, duration_ms, context)
	var summary: Dictionary = collector.summary()
	var retention: Dictionary = summary.get("retention", {}) as Dictionary
	_expect(collector.timing_enabled(), "MINIMAL must collect timing")
	_expect(not collector.full_capture_enabled(), "MINIMAL must not enable full capture")
	_expect(int(summary.get("sample_count", 0)) == 20, "MINIMAL aggregate count must include every sample")
	_expect((summary.get("raw_samples", []) as Array).is_empty(), "MINIMAL must retain no raw sample array")
	_expect(int(retention.get("retained_percentile_sample_count", 99)) <= 5, "MINIMAL percentile retention must honor its hard bound")
	_expect(int(retention.get("retained_worst_record_count", 99)) <= 3, "MINIMAL worst-record retention must honor its hard bound")
	_expect(int(retention.get("retained_hitch_record_count", 99)) <= 3, "MINIMAL hitch retention must honor its hard bound")
	_expect(int(summary.get("hitch_count", 0)) == 15, "MINIMAL must stream the full hitch count despite bounded records")
	_expect(bool(retention.get("truncated", false)), "bounded overflow must be explicit")


func _test_full_is_bounded_with_raw_samples() -> void:
	var collector := MetricsCollector.new("FULL", 2, 5.0, 6, 7)
	for sample_index in range(1, 21):
		collector.observe(sample_index, float(sample_index))
	var summary: Dictionary = collector.summary()
	var retention: Dictionary = summary.get("retention", {}) as Dictionary
	_expect(collector.full_capture_enabled(), "FULL must enable raw capture")
	_expect((summary.get("raw_samples", []) as Array).size() == 7, "FULL raw samples must stop at the configured bound")
	_expect(int(retention.get("dropped_raw_sample_count", 0)) == 13, "FULL must report dropped raw samples")
	_expect(int(retention.get("retained_percentile_sample_count", 99)) <= 6, "FULL percentile retention must remain bounded")
	_expect(int(retention.get("retained_worst_record_count", 99)) <= 2, "FULL forensic retention must remain bounded")
	_expect(bool((summary.get("overhead_contract", {}) as Dictionary).get("raw_sample_allocation", false)), "FULL overhead contract must disclose raw allocation")


func _test_retention_is_deterministic() -> void:
	var first := MetricsCollector.new("MINIMAL", 4, 9.0, 7)
	var second := MetricsCollector.new("MINIMAL", 4, 9.0, 7)
	for sample_index in range(1, 101):
		var duration_ms: float = float((sample_index * 17) % 29)
		first.observe(sample_index, duration_ms)
		second.observe(sample_index, duration_ms)
	_expect(
		DeterministicHash.hash_variant(first.summary()) == DeterministicHash.hash_variant(second.summary()),
		"identical sample streams must produce identical bounded retention"
	)


func _test_source_contracts() -> void:
	_expect(ResultContract.RESULT_SCHEMA_VERSION >= 2, "Gate E collection semantics require schema v2 or later")
	var runner: String = FileAccess.get_file_as_string("res://scripts/tests/perf_benchmark_suite.gd")
	_expect(runner.contains("phase0_collector_calibration"), "runner must expose the repeated calibration suite")
	_expect(runner.contains("measurement_wall_duration_ms"), "calibration must use a shared outer wall interval")
	_expect(runner.contains("directional repeated evidence only"), "calibration must reject an exact single-run overhead claim")
	_expect(runner.contains("collector.timing_enabled()"), "runner must bypass per-sample timing in OFF mode")
	_expect(not runner.contains("collection_level_not_implemented_phase0"), "OFF and FULL must no longer be placeholder refusals")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("PERF_GATE_E_SMOKE: %s" % message)
