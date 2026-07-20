extends RefCounted

const PERF_DETERMINISTIC_HASH := preload("res://scripts/tests/perf/perf_deterministic_hash.gd")

const RESULT_SCHEMA_VERSION: int = 3
const FINGERPRINT_VERSION: int = 2
const ENVIRONMENT_COMPATIBILITY_VERSION: int = 1
const COLLECTION_LEVEL_MINIMAL: String = "MINIMAL"
const COLLECTION_LEVELS: Array[String] = ["OFF", "MINIMAL", "FULL"]
const MEASUREMENT_PROFILES: Array[String] = [
	"canonical_sim_headless",
	"deterministic_windowed_presentation",
	"static_windowed_deterministic",
	"investigative_render_windowed",
	"investigative_layer_isolation"
]
const METRIC_CLASSIFICATIONS: Array[String] = [
	"DIRECT",
	"DERIVED",
	"CONFIGURATION_STATE",
	"UNAVAILABLE",
	"EXTERNAL_PROFILER_REQUIRED"
]
const COMPARISON_CRITICAL_FIELDS: Array[String] = [
	"result_schema_version",
	"fixture_id",
	"fixture_version",
	"catalog_schema",
	"catalog_version",
	"catalog_content_hash",
	"catalog_fixture_registered",
	"measurement_profile",
	"content_kind",
	"content_identity",
	"environment_compatibility_hash",
	"fixture_config_hash",
	"map_content_hash",
	"command_schedule_hash",
	"godot_version",
	"build_type",
	"rendering_method",
	"rendering_driver",
	"video_adapter",
	"viewport_width",
	"viewport_height",
	"content_scale_factor",
	"stretch_mode",
	"stretch_aspect",
	"benchmark_mode",
	"collection_level",
	"warmup_duration_sec",
	"measurement_duration_sec",
	"target_fps",
	"physics_ticks_per_second"
]


static func normalize_collection_level(raw: String) -> String:
	return raw.strip_edges().to_upper()


static func is_known_collection_level(level: String) -> bool:
	return COLLECTION_LEVELS.has(normalize_collection_level(level))


static func metric(
	classification: String,
	value: Variant,
	unit: String,
	source: String,
	reason: String = ""
) -> Dictionary:
	var normalized_classification: String = classification.strip_edges().to_upper()
	var available: bool = value != null
	return {
		"classification": normalized_classification,
		"available": available,
		"value": value,
		"unit": unit,
		"source": source,
		"reason": reason if not available else ""
	}


static func unavailable_metric(classification: String, unit: String, reason: String) -> Dictionary:
	return metric(classification, null, unit, "not_collected", reason)


static func attach_scenario_fingerprint(report: Dictionary, scenario: Dictionary) -> void:
	_apply_scenario_identity_defaults(scenario)
	var environment_payload: Dictionary = _environment_compatibility_payload(report, scenario)
	var environment_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(environment_payload)
	scenario["environment_compatibility_hash"] = environment_hash
	scenario["environment_compatibility"] = {
		"version": ENVIRONMENT_COMPATIBILITY_VERSION,
		"hash": environment_hash,
		"payload": environment_payload
	}
	var payload: Dictionary = _scenario_fingerprint_payload(report, scenario)
	scenario["comparison_fingerprint"] = {
		"version": FINGERPRINT_VERSION,
		"hash": PERF_DETERMINISTIC_HASH.hash_variant(payload),
		"payload": payload
	}


static func validate_report(report: Dictionary) -> Dictionary:
	var errors: Array = []
	if str(report.get("report_type", "")) != "sf_perf_benchmark_suite":
		errors.append("report_type_invalid")
	if int(report.get("result_schema_version", 0)) != RESULT_SCHEMA_VERSION:
		errors.append("result_schema_version_unsupported")
	var collection_level: String = normalize_collection_level(str(report.get("collection_level", "")))
	if not is_known_collection_level(collection_level):
		errors.append("collection_level_invalid")
	for required_key in ["git", "godot", "machine", "build", "renderer", "viewport", "pacing"]:
		if typeof(report.get(required_key)) != TYPE_DICTIONARY:
			errors.append("missing_or_invalid:%s" % required_key)
	_validate_catalog_identity(report.get("fixture_catalog"), errors)
	var scenarios: Array = report.get("scenarios", []) as Array
	if int(report.get("scenario_count", -1)) != scenarios.size():
		errors.append("scenario_count_mismatch")
	for scenario_index in range(scenarios.size()):
		var scenario_any: Variant = scenarios[scenario_index]
		if typeof(scenario_any) != TYPE_DICTIONARY:
			errors.append("scenario_%d_not_dictionary" % scenario_index)
			continue
		_validate_scenario(report, scenario_any as Dictionary, scenario_index, errors)
	return {
		"status": "VALID" if errors.is_empty() else "INVALID",
		"pass": errors.is_empty(),
		"schema_version": RESULT_SCHEMA_VERSION,
		"errors": errors
	}


static func comparison_compatibility(baseline: Dictionary, current: Dictionary) -> Dictionary:
	var baseline_validation: Dictionary = validate_report(baseline)
	var current_validation: Dictionary = validate_report(current)
	var mismatches: Array = []
	if not bool(baseline_validation.get("pass", false)):
		mismatches.append({"scope": "baseline_schema", "errors": baseline_validation.get("errors", [])})
	if not bool(current_validation.get("pass", false)):
		mismatches.append({"scope": "current_schema", "errors": current_validation.get("errors", [])})
	if mismatches.is_empty():
		var baseline_fingerprints: Dictionary = _fingerprints_by_repetition(baseline)
		var current_fingerprints: Dictionary = _fingerprints_by_repetition(current)
		var all_keys: Array = baseline_fingerprints.keys()
		for current_key_any in current_fingerprints.keys():
			if not all_keys.has(current_key_any):
				all_keys.append(current_key_any)
		all_keys.sort()
		for key_any in all_keys:
			var key: String = str(key_any)
			if not baseline_fingerprints.has(key):
				mismatches.append({"scope": key, "field": "scenario_repetition", "baseline": null, "current": "present"})
				continue
			if not current_fingerprints.has(key):
				mismatches.append({"scope": key, "field": "scenario_repetition", "baseline": "present", "current": null})
				continue
			var baseline_payload: Dictionary = baseline_fingerprints.get(key, {}) as Dictionary
			var current_payload: Dictionary = current_fingerprints.get(key, {}) as Dictionary
			for field in COMPARISON_CRITICAL_FIELDS:
				if not _values_equal(baseline_payload.get(field), current_payload.get(field)):
					mismatches.append({
						"scope": key,
						"field": field,
						"baseline": baseline_payload.get(field),
						"current": current_payload.get(field)
					})
	return {
		"status": "COMPATIBLE" if mismatches.is_empty() else "INCOMPATIBLE",
		"pass": mismatches.is_empty(),
		"critical_fields": COMPARISON_CRITICAL_FIELDS.duplicate(),
		"baseline_validation": baseline_validation,
		"current_validation": current_validation,
		"mismatches": mismatches
	}


static func baseline_approval(report: Dictionary, compatibility: Dictionary = {}, baseline: Dictionary = {}) -> Dictionary:
	var reasons: Array = []
	var validation: Dictionary = validate_report(report)
	if not bool(validation.get("pass", false)):
		reasons.append("result_schema_invalid")
	var git: Dictionary = report.get("git", {}) as Dictionary
	if bool(git.get("dirty", true)):
		reasons.append("dirty_worktree")
	if str(git.get("commit", "")).strip_edges().is_empty():
		reasons.append("git_commit_missing")
	if not baseline.is_empty():
		var baseline_git: Dictionary = baseline.get("git", {}) as Dictionary
		if bool(baseline_git.get("dirty", true)):
			reasons.append("baseline_dirty_worktree")
		if str(baseline_git.get("commit", "")).strip_edges().is_empty():
			reasons.append("baseline_git_commit_missing")
	if str(report.get("run_status", "")) != "COMPLETED" or str(report.get("integrity_status", "")) != "PASS":
		reasons.append("run_integrity_not_approved")
	if not bool(report.get("pass", false)):
		reasons.append("run_failed")
	var scenarios: Array = report.get("scenarios", []) as Array
	if scenarios.is_empty():
		reasons.append("no_scenarios")
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		if bool(scenario.get("baseline_eligible", false)) and not bool(scenario.get("catalog_fixture_registered", false)):
			var registration_reason: String = "scenario_not_catalog_registered:%s" % str(scenario.get("fixture_id", "unknown"))
			if not reasons.has(registration_reason):
				reasons.append(registration_reason)
		if not bool(scenario.get("baseline_eligible", false)):
			var scenario_reason: String = "scenario_not_baseline_eligible:%s" % str(scenario.get("fixture_id", "unknown"))
			if not reasons.has(scenario_reason):
				reasons.append(scenario_reason)
	if not compatibility.is_empty() and not bool(compatibility.get("pass", false)):
		reasons.append("comparison_fingerprint_incompatible")
	return {
		"status": "ELIGIBLE" if reasons.is_empty() else "REFUSED",
		"eligible": reasons.is_empty(),
		"reasons": reasons,
		"policy": "clean_valid_compatible_baseline_eligible_results_only"
	}


static func comparison_metric_keys(benchmark_mode: String) -> Array[String]:
	if benchmark_mode == "canonical_sim_headless":
		return ["average_tick_ms", "p95_tick_ms", "p99_tick_ms", "max_tick_ms"]
	return ["average_frame_ms", "p95_frame_ms", "p99_frame_ms", "max_frame_ms", "hitch_count"]


static func _scenario_fingerprint_payload(report: Dictionary, scenario: Dictionary) -> Dictionary:
	var godot: Dictionary = report.get("godot", {}) as Dictionary
	var build: Dictionary = report.get("build", {}) as Dictionary
	var renderer: Dictionary = report.get("renderer", {}) as Dictionary
	var viewport: Dictionary = report.get("viewport", {}) as Dictionary
	var pacing: Dictionary = report.get("pacing", {}) as Dictionary
	var catalog: Dictionary = report.get("fixture_catalog", {}) as Dictionary
	return {
		"result_schema_version": int(report.get("result_schema_version", 0)),
		"fixture_id": str(scenario.get("fixture_id", scenario.get("scenario_id", ""))),
		"fixture_version": int(scenario.get("fixture_version", 0)),
		"catalog_schema": str(catalog.get("schema", "")),
		"catalog_version": int(catalog.get("version", 0)),
		"catalog_content_hash": str(catalog.get("content_hash", "")),
		"catalog_fixture_registered": bool(scenario.get("catalog_fixture_registered", false)),
		"measurement_profile": str(scenario.get("measurement_profile", "")),
		"content_kind": str(scenario.get("content_kind", "")),
		"content_identity": str(scenario.get("content_identity", "")),
		"environment_compatibility_hash": str(scenario.get("environment_compatibility_hash", "")),
		"repetition_index": int(scenario.get("repetition_index", 1)),
		"suite_sequence_index": int(scenario.get("suite_sequence_index", 0)),
		"fixture_config_hash": str(scenario.get("fixture_config_hash", "")),
		"map_content_hash": str(scenario.get("map_content_hash", "")),
		"command_schedule_hash": str(scenario.get("command_schedule_hash", "")),
		"godot_version": str(godot.get("string", godot.get("full_name", ""))),
		"build_type": str(build.get("type", "")),
		"rendering_method": str(renderer.get("rendering_method", "")),
		"rendering_driver": str(renderer.get("rendering_driver", "")),
		"video_adapter": str(renderer.get("video_adapter", "")),
		"viewport_width": int(viewport.get("width", 0)),
		"viewport_height": int(viewport.get("height", 0)),
		"content_scale_factor": float(viewport.get("content_scale_factor", 0.0)),
		"stretch_mode": str(viewport.get("stretch_mode", "")),
		"stretch_aspect": str(viewport.get("stretch_aspect", "")),
		"benchmark_mode": str(scenario.get("benchmark_mode", report.get("benchmark_mode", ""))),
		"collection_level": str(scenario.get("collection_level", report.get("collection_level", ""))),
		"warmup_duration_sec": float(scenario.get("warmup_duration_sec", 0.0)),
		"measurement_duration_sec": float(scenario.get("measurement_duration_sec", 0.0)),
		"target_fps": int(pacing.get("benchmark_target_fps", 0)),
		"physics_ticks_per_second": int(pacing.get("physics_ticks_per_second", 0))
	}


static func _validate_scenario(report: Dictionary, scenario: Dictionary, scenario_index: int, errors: Array) -> void:
	var prefix: String = "scenario_%d" % scenario_index
	for required_string in [
		"fixture_id",
		"fixture_config_hash",
		"command_schedule_hash",
		"measurement_profile",
		"content_kind",
		"content_identity",
		"environment_compatibility_hash"
	]:
		if str(scenario.get(required_string, "")).strip_edges().is_empty():
			errors.append("%s_missing:%s" % [prefix, required_string])
	if typeof(scenario.get("catalog_fixture_registered")) != TYPE_BOOL:
		errors.append("%s_catalog_registration_invalid" % prefix)
	var content_kind: String = str(scenario.get("content_kind", ""))
	if not MEASUREMENT_PROFILES.has(str(scenario.get("measurement_profile", ""))):
		errors.append("%s_measurement_profile_invalid" % prefix)
	if not ["production_map", "synthetic_scene"].has(content_kind):
		errors.append("%s_content_kind_invalid" % prefix)
	elif content_kind == "production_map" and str(scenario.get("map_content_hash", "")).strip_edges().is_empty():
		errors.append("%s_production_map_hash_missing" % prefix)
	_validate_environment_compatibility(report, scenario, prefix, errors)
	if not scenario.has("warmup_duration_sec") or not scenario.has("measurement_duration_sec"):
		errors.append("%s_duration_identity_missing" % prefix)
	var collection: Variant = scenario.get("collection")
	if typeof(collection) != TYPE_DICTIONARY:
		errors.append("%s_collection_contract_missing" % prefix)
	else:
		var collection_dict: Dictionary = collection as Dictionary
		var scenario_level: String = normalize_collection_level(str(scenario.get("collection_level", report.get("collection_level", ""))))
		if str(collection_dict.get("level", "")) != scenario_level:
			errors.append("%s_collection_level_mismatch" % prefix)
		var timing_enabled: bool = bool(collection_dict.get("timing_enabled", false))
		var retention: Dictionary = collection_dict.get("retention", {}) as Dictionary
		var raw_capture: bool = bool(retention.get("raw_sample_capture", false))
		if scenario_level == "OFF" and (timing_enabled or raw_capture):
			errors.append("%s_collection_off_behavior_invalid" % prefix)
		if scenario_level == "MINIMAL" and (not timing_enabled or raw_capture):
			errors.append("%s_collection_minimal_behavior_invalid" % prefix)
		if scenario_level == "FULL" and (not timing_enabled or not raw_capture):
			errors.append("%s_collection_full_behavior_invalid" % prefix)
	var metrics: Variant = scenario.get("metrics")
	if typeof(metrics) != TYPE_DICTIONARY:
		errors.append("%s_metrics_missing" % prefix)
	else:
		for metric_name_any in (metrics as Dictionary).keys():
			var metric_entry: Variant = (metrics as Dictionary).get(metric_name_any)
			if typeof(metric_entry) != TYPE_DICTIONARY:
				errors.append("%s_metric_invalid:%s" % [prefix, str(metric_name_any)])
				continue
			var classification: String = str((metric_entry as Dictionary).get("classification", ""))
			if not METRIC_CLASSIFICATIONS.has(classification):
				errors.append("%s_metric_classification_invalid:%s" % [prefix, str(metric_name_any)])
			var available: bool = bool((metric_entry as Dictionary).get("available", false))
			var value: Variant = (metric_entry as Dictionary).get("value")
			if available and value == null:
				errors.append("%s_metric_available_without_value:%s" % [prefix, str(metric_name_any)])
			if not available and value != null:
				errors.append("%s_metric_unavailable_with_value:%s" % [prefix, str(metric_name_any)])
			if not available and str((metric_entry as Dictionary).get("reason", "")).strip_edges().is_empty():
				errors.append("%s_metric_unavailable_without_reason:%s" % [prefix, str(metric_name_any)])
	var fingerprint: Variant = scenario.get("comparison_fingerprint")
	if typeof(fingerprint) != TYPE_DICTIONARY:
		errors.append("%s_fingerprint_missing" % prefix)
		return
	var fingerprint_dict: Dictionary = fingerprint as Dictionary
	if int(fingerprint_dict.get("version", 0)) != FINGERPRINT_VERSION:
		errors.append("%s_fingerprint_version_invalid" % prefix)
	var payload: Dictionary = fingerprint_dict.get("payload", {}) as Dictionary
	for field in COMPARISON_CRITICAL_FIELDS:
		if not payload.has(field):
			errors.append("%s_fingerprint_field_missing:%s" % [prefix, field])
	for required_string in [
		"fixture_id", "catalog_schema", "catalog_content_hash", "measurement_profile",
		"content_kind", "content_identity", "environment_compatibility_hash",
		"fixture_config_hash", "command_schedule_hash",
		"godot_version", "build_type", "rendering_method", "rendering_driver", "video_adapter",
		"stretch_mode", "stretch_aspect", "benchmark_mode", "collection_level"
	]:
		if str(payload.get(required_string, "")).strip_edges().is_empty():
			errors.append("%s_fingerprint_value_missing:%s" % [prefix, required_string])
	if int(payload.get("viewport_width", 0)) <= 0 or int(payload.get("viewport_height", 0)) <= 0:
		errors.append("%s_fingerprint_viewport_invalid" % prefix)
	if float(payload.get("content_scale_factor", 0.0)) <= 0.0:
		errors.append("%s_fingerprint_content_scale_invalid" % prefix)
	if float(payload.get("warmup_duration_sec", -1.0)) < 0.0 or float(payload.get("measurement_duration_sec", 0.0)) <= 0.0:
		errors.append("%s_fingerprint_durations_invalid" % prefix)
	if int(payload.get("target_fps", 0)) <= 0 or int(payload.get("physics_ticks_per_second", 0)) <= 0:
		errors.append("%s_fingerprint_pacing_invalid" % prefix)
	var expected_payload: Dictionary = _scenario_fingerprint_payload(report, scenario)
	if PERF_DETERMINISTIC_HASH.hash_variant(payload) != str(fingerprint_dict.get("hash", "")):
		errors.append("%s_fingerprint_hash_invalid" % prefix)
	if PERF_DETERMINISTIC_HASH.hash_variant(expected_payload) != PERF_DETERMINISTIC_HASH.hash_variant(payload):
		errors.append("%s_fingerprint_payload_stale" % prefix)


static func _fingerprints_by_repetition(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scenario_any in report.get("scenarios", []) as Array:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var key: String = "%s#repetition_%d#sequence_%d" % [
			"%s@%s" % [
				str(scenario.get("fixture_id", scenario.get("scenario_id", ""))),
				str(scenario.get("measurement_profile", ""))
			],
			int(scenario.get("repetition_index", 1)),
			int(scenario.get("suite_sequence_index", 0))
		]
		var fingerprint: Dictionary = scenario.get("comparison_fingerprint", {}) as Dictionary
		out[key] = (fingerprint.get("payload", {}) as Dictionary).duplicate(true)
	return out


static func _values_equal(a: Variant, b: Variant) -> bool:
	return PERF_DETERMINISTIC_HASH.hash_variant(a) == PERF_DETERMINISTIC_HASH.hash_variant(b)


static func _apply_scenario_identity_defaults(scenario: Dictionary) -> void:
	var benchmark_mode: String = str(scenario.get("benchmark_mode", ""))
	if str(scenario.get("measurement_profile", "")).strip_edges().is_empty():
		match benchmark_mode:
			"render_windowed":
				scenario["measurement_profile"] = "investigative_render_windowed"
			"layer_isolation_noncanonical":
				scenario["measurement_profile"] = "investigative_layer_isolation"
			_:
				scenario["measurement_profile"] = "canonical_sim_headless"
	if str(scenario.get("content_kind", "")).strip_edges().is_empty():
		scenario["content_kind"] = "production_map"
	if str(scenario.get("content_identity", "")).strip_edges().is_empty():
		var map_hash: String = str(scenario.get("map_content_hash", ""))
		scenario["content_identity"] = "sha256:%s" % map_hash if not map_hash.is_empty() else "unresolved_content"
	if not scenario.has("catalog_fixture_registered"):
		scenario["catalog_fixture_registered"] = false


static func _environment_compatibility_payload(report: Dictionary, scenario: Dictionary) -> Dictionary:
	var godot: Dictionary = report.get("godot", {}) as Dictionary
	var build: Dictionary = report.get("build", {}) as Dictionary
	var renderer: Dictionary = report.get("renderer", {}) as Dictionary
	var viewport: Dictionary = report.get("viewport", {}) as Dictionary
	var pacing: Dictionary = report.get("pacing", {}) as Dictionary
	return {
		"godot_version": str(godot.get("string", godot.get("full_name", ""))),
		"build_type": str(build.get("type", "")),
		"rendering_method": str(renderer.get("rendering_method", "")),
		"rendering_driver": str(renderer.get("rendering_driver", "")),
		"video_adapter": str(renderer.get("video_adapter", "")),
		"display_server": str(renderer.get("display_server", "")),
		"headless": bool(renderer.get("headless", false)),
		"viewport_width": int(viewport.get("width", 0)),
		"viewport_height": int(viewport.get("height", 0)),
		"content_scale_factor": float(viewport.get("content_scale_factor", 0.0)),
		"stretch_mode": str(viewport.get("stretch_mode", "")),
		"stretch_aspect": str(viewport.get("stretch_aspect", "")),
		"render_scale_3d": float(viewport.get("render_scale_3d", 1.0)),
		"target_fps": int(pacing.get("benchmark_target_fps", 0)),
		"physics_ticks_per_second": int(pacing.get("physics_ticks_per_second", 0)),
		"vsync_mode": int(pacing.get("vsync_mode", -1)),
		"measurement_profile": str(scenario.get("measurement_profile", "")),
		"camera_identity": scenario.get("camera_identity", "NOT_CAPTURED_FOR_PROFILE"),
		"cadence_identity": scenario.get("cadence_identity", "CANONICAL_PROFILE_DEFAULT")
	}


static func _validate_catalog_identity(catalog_any: Variant, errors: Array) -> void:
	if typeof(catalog_any) != TYPE_DICTIONARY:
		errors.append("fixture_catalog_missing_or_invalid")
		return
	var catalog: Dictionary = catalog_any as Dictionary
	if str(catalog.get("schema", "")) != "sf_perf_fixture_catalog_design_v1":
		errors.append("fixture_catalog_schema_unsupported")
	if int(catalog.get("version", 0)) != 1:
		errors.append("fixture_catalog_version_unsupported")
	if str(catalog.get("status", "")) != "DESIGN_APPROVED_NOT_IMPLEMENTED":
		errors.append("fixture_catalog_status_invalid")
	if str(catalog.get("content_hash", "")).length() != 64:
		errors.append("fixture_catalog_hash_invalid")
	if int(catalog.get("fixture_count", 0)) != 7:
		errors.append("fixture_catalog_count_invalid")
	if str(catalog.get("validation", "")) != "PASS":
		errors.append("fixture_catalog_validation_not_pass")
	if bool(catalog.get("baseline_default_eligible", true)):
		errors.append("fixture_catalog_default_eligibility_invalid")


static func _validate_environment_compatibility(
	report: Dictionary,
	scenario: Dictionary,
	prefix: String,
	errors: Array
) -> void:
	var compatibility_any: Variant = scenario.get("environment_compatibility")
	if typeof(compatibility_any) != TYPE_DICTIONARY:
		errors.append("%s_environment_compatibility_missing" % prefix)
		return
	var compatibility: Dictionary = compatibility_any as Dictionary
	if int(compatibility.get("version", 0)) != ENVIRONMENT_COMPATIBILITY_VERSION:
		errors.append("%s_environment_compatibility_version_invalid" % prefix)
	var payload: Dictionary = compatibility.get("payload", {}) as Dictionary
	var expected_payload: Dictionary = _environment_compatibility_payload(report, scenario)
	var payload_hash: String = PERF_DETERMINISTIC_HASH.hash_variant(payload)
	if payload_hash != str(compatibility.get("hash", "")):
		errors.append("%s_environment_compatibility_hash_invalid" % prefix)
	if payload_hash != str(scenario.get("environment_compatibility_hash", "")):
		errors.append("%s_environment_compatibility_identity_stale" % prefix)
	if PERF_DETERMINISTIC_HASH.hash_variant(expected_payload) != payload_hash:
		errors.append("%s_environment_compatibility_payload_stale" % prefix)
