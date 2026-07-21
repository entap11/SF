class_name PerfBaselineEligibility
extends RefCounted

const REQUIRED_REPETITIONS: int = 3
const REQUIRED_COLLECTION_LEVEL: String = "MINIMAL"


static func apply(report: Dictionary, catalog: Dictionary, fixtures_by_id: Dictionary) -> Dictionary:
	var global_reasons: Array[String] = []
	var suite_contract: Dictionary = _suite_contract(str(report.get("suite_id", "")), str(report.get("benchmark_mode", "")))
	if suite_contract.is_empty():
		global_reasons.append("suite_profile_not_approved")
	if str(catalog.get("status", "")) != "IMPLEMENTED":
		global_reasons.append("fixture_catalog_not_implemented")
	var git: Dictionary = report.get("git", {}) as Dictionary
	if bool(git.get("dirty", true)):
		global_reasons.append("dirty_worktree")
	if str(git.get("commit", "")).strip_edges().is_empty():
		global_reasons.append("git_commit_missing")
	if str(report.get("collection_level", "")).to_upper() != REQUIRED_COLLECTION_LEVEL:
		global_reasons.append("collection_level_not_minimal")
	if str(report.get("run_status", "")) != "COMPLETED" or str(report.get("integrity_status", "")) != "PASS":
		global_reasons.append("run_integrity_not_approved")
	if not bool(report.get("pass", false)):
		global_reasons.append("run_failed")
	for evidence_key in ["determinism", "isolation", "backend_isolation"]:
		if not bool((report.get(evidence_key, {}) as Dictionary).get("pass", false)):
			global_reasons.append("%s_failed" % evidence_key)

	var scenarios: Array = report.get("scenarios", []) as Array
	var grouped: Dictionary = {}
	for scenario_any in scenarios:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var key: String = _scenario_key(scenario)
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(scenario)
	var expected_keys: Array[String] = []
	if not suite_contract.is_empty():
		for fixture_id_any in suite_contract.get("fixtures", []) as Array:
			expected_keys.append("%s@%s" % [str(fixture_id_any), str(suite_contract.get("measurement_profile", ""))])
	expected_keys.sort()
	var observed_keys: Array = grouped.keys()
	observed_keys.sort()
	if observed_keys != expected_keys:
		global_reasons.append("fixture_profile_set_mismatch")
	for key_any in expected_keys:
		var key: String = str(key_any)
		var repetitions: Array = grouped.get(key, []) as Array
		if repetitions.size() != REQUIRED_REPETITIONS:
			global_reasons.append("repetition_count_not_exact:%s" % key)
			continue
		var indexes: Array[int] = []
		for repetition_any in repetitions:
			indexes.append(int((repetition_any as Dictionary).get("repetition_index", 0)))
		indexes.sort()
		if indexes != [1, 2, 3]:
			global_reasons.append("repetition_indexes_not_exact:%s" % key)

	var eligible_count: int = 0
	for scenario_index in range(scenarios.size()):
		var scenario_any: Variant = scenarios[scenario_index]
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var reasons: Array[String] = global_reasons.duplicate()
		var fixture_id: String = str(scenario.get("fixture_id", ""))
		var fixture: Dictionary = fixtures_by_id.get(fixture_id, {}) as Dictionary
		if fixture.is_empty():
			reasons.append("fixture_not_registered")
		if not bool(scenario.get("catalog_fixture_registered", false)):
			reasons.append("scenario_not_catalog_registered")
		if str(fixture.get("status", "")) != "IMPLEMENTED":
			reasons.append("fixture_not_implemented")
		if not bool(fixture.get("baseline_candidate", false)):
			reasons.append("fixture_not_baseline_candidate")
		var measurement_profile: String = str(scenario.get("measurement_profile", ""))
		if not (fixture.get("measurement_profiles", []) as Array).has(measurement_profile):
			reasons.append("measurement_profile_not_catalog_approved")
		if not bool(scenario.get("pass", false)):
			reasons.append("scenario_failed")
		if not (scenario.get("integrity_failures", []) as Array).is_empty():
			reasons.append("scenario_integrity_failed")
		if not bool((scenario.get("isolation_cleanup", {}) as Dictionary).get("pass", false)):
			reasons.append("scenario_isolation_failed")
		if not bool((scenario.get("fixture_setup_evidence", {}) as Dictionary).get("exact_counts", false)):
			reasons.append("fixture_counts_not_exact")
		if str(scenario.get("collection_level", "")).to_upper() != REQUIRED_COLLECTION_LEVEL:
			reasons.append("scenario_collection_level_not_minimal")
		if str(scenario.get("fixture_config_hash", "")).is_empty():
			reasons.append("fixture_config_hash_missing")
		if str(scenario.get("final_state_hash", "")).is_empty():
			reasons.append("final_state_hash_missing")
		if int(scenario.get("target_units", 0)) > 0:
			if not bool((scenario.get("unit_count_window", {}) as Dictionary).get("invariant", false)):
				reasons.append("unit_count_invariant_failed")
			var setup: Dictionary = scenario.get("unit_scale_setup", {}) as Dictionary
			if bool(setup.get("capacity_bypass_used", true)):
				reasons.append("capacity_bypass_used")
			var pool: Dictionary = scenario.get("renderer_pool_telemetry", {}) as Dictionary
			if int(pool.get("pool_misses", -1)) != 0 or int(pool.get("pool_expansions", -1)) != 0:
				reasons.append("renderer_pool_contract_failed")
		reasons = _dedupe(reasons)
		scenario["baseline_eligible"] = reasons.is_empty()
		scenario["baseline_ineligible_reasons"] = reasons
		if reasons.is_empty():
			eligible_count += 1
		scenarios[scenario_index] = scenario
	report["scenarios"] = scenarios
	var summary: Dictionary = {
		"policy_version": 1,
		"status": "ELIGIBLE" if eligible_count == scenarios.size() and not scenarios.is_empty() else "REFUSED",
		"eligible": eligible_count == scenarios.size() and not scenarios.is_empty(),
		"eligible_scenarios": eligible_count,
		"scenario_count": scenarios.size(),
		"required_repetitions": REQUIRED_REPETITIONS,
		"required_collection_level": REQUIRED_COLLECTION_LEVEL,
		"global_reasons": global_reasons
	}
	report["runtime_baseline_eligibility"] = summary
	return summary


static func _scenario_key(scenario: Dictionary) -> String:
	return "%s@%s" % [str(scenario.get("fixture_id", "")), str(scenario.get("measurement_profile", ""))]


static func _suite_contract(suite_id: String, benchmark_mode: String) -> Dictionary:
	match "%s@%s" % [suite_id, benchmark_mode]:
		"phase1_static_fixtures@static_windowed_deterministic":
			return {"measurement_profile": "static_windowed_deterministic", "fixtures": ["EMPTY_ARENA_V1", "STATIC_BATTLEFIELD_V1"]}
		"phase1_normal_match@canonical_sim_headless":
			return {"measurement_profile": "canonical_sim_headless", "fixtures": ["NORMAL_MATCH_V1"]}
		"phase1_normal_match@deterministic_windowed_presentation":
			return {"measurement_profile": "deterministic_windowed_presentation", "fixtures": ["NORMAL_MATCH_V1"]}
		"phase1_unit_scale@static_windowed_deterministic":
			return {"measurement_profile": "static_windowed_deterministic", "fixtures": ["UNIT_SCALE_050_V1", "UNIT_SCALE_100_V1", "UNIT_SCALE_200_V1", "UNIT_SCALE_400_V1"]}
		_:
			return {}


static func _dedupe(values: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		if not out.has(value):
			out.append(value)
	return out
