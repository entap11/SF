class_name PerfBaselineComparator
extends RefCounted

const PERF_RESULT_CONTRACT := preload("res://scripts/tests/perf/perf_result_contract.gd")


static func compare(baseline: Dictionary, current: Dictionary, gates: Dictionary) -> Dictionary:
	var compatibility: Dictionary = PERF_RESULT_CONTRACT.comparison_compatibility(baseline, current)
	if not bool(compatibility.get("pass", false)):
		return {
			"status": "INCOMPATIBLE",
			"pass": false,
			"compatibility": compatibility,
			"scenarios": [],
			"reason": "comparison_critical_fingerprint_mismatch"
		}
	var baseline_by_id: Dictionary = _scenarios_grouped_by_id(baseline)
	var current_by_id: Dictionary = _scenarios_grouped_by_id(current)
	var ids: Array = current_by_id.keys()
	ids.sort()
	var out: Dictionary = {
		"status": "PASS",
		"pass": true,
		"compatibility": compatibility,
		"aggregation": "median_of_repetition_summaries",
		"scenarios": [],
		"metric_errors": []
	}
	for id_any in ids:
		var scenario_id: String = str(id_any)
		var baseline_repetitions: Array = baseline_by_id.get(scenario_id, []) as Array
		var current_repetitions: Array = current_by_id.get(scenario_id, []) as Array
		var rows: Array = []
		var status: String = "PASS"
		var first_current: Dictionary = current_repetitions[0] as Dictionary
		var metric_keys: Array[String] = PERF_RESULT_CONTRACT.comparison_metric_keys(str(first_current.get("benchmark_mode", "")))
		for key in metric_keys:
			if not _all_repetitions_have_metric(baseline_repetitions, key) or not _all_repetitions_have_metric(current_repetitions, key):
				status = "INCOMPATIBLE"
				out["status"] = "INCOMPATIBLE"
				out["pass"] = false
				var metric_error := {
					"scenario_id": scenario_id,
					"metric": key,
					"reason": "required_comparison_metric_missing_or_unavailable"
				}
				(out["metric_errors"] as Array).append(metric_error)
				rows.append({"metric": key, "status": "UNAVAILABLE", "reason": metric_error.get("reason", "")})
				continue
			var baseline_value: float = _median_scenario_metric(baseline_repetitions, key)
			var current_value: float = _median_scenario_metric(current_repetitions, key)
			var regression: float = _regression_percent(baseline_value, current_value)
			var marker: String = _marker_for_regression(regression, gates)
			if marker == "FAIL" and not bool(first_current.get("allowed_failure", false)):
				if status != "INCOMPATIBLE":
					status = "FAIL"
				if str(out.get("status", "PASS")) != "INCOMPATIBLE":
					out["status"] = "FAIL"
				out["pass"] = false
			elif marker == "WARN" and status == "PASS":
				status = "WARN"
				if str(out.get("status", "PASS")) == "PASS":
					out["status"] = "WARN"
			rows.append({
				"metric": key,
				"aggregation": "median_of_repetition_summaries",
				"baseline": baseline_value,
				"current": current_value,
				"regression_percent": regression,
				"status": marker
			})
		(out["scenarios"] as Array).append({
			"scenario_id": scenario_id,
			"status": status,
			"baseline_repetitions": baseline_repetitions.size(),
			"current_repetitions": current_repetitions.size(),
			"metrics": rows
		})
	return out


static func exit_code(comparison: Dictionary) -> int:
	match str(comparison.get("status", "INCOMPATIBLE")):
		"PASS":
			return 0
		"WARN":
			return 1
		_:
			return 2


static func _scenarios_grouped_by_id(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scenario_any in report.get("scenarios", []) as Array:
		if typeof(scenario_any) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_any as Dictionary
		var scenario_id: String = str(scenario.get("scenario_id", ""))
		if not out.has(scenario_id):
			out[scenario_id] = []
		(out[scenario_id] as Array).append(scenario)
	return out


static func _all_repetitions_have_metric(repetitions: Array, metric_name: String) -> bool:
	if repetitions.is_empty():
		return false
	for repetition_any in repetitions:
		if typeof(repetition_any) != TYPE_DICTIONARY:
			return false
		var repetition: Dictionary = repetition_any as Dictionary
		if not repetition.has(metric_name) or repetition.get(metric_name) == null:
			return false
	return true


static func _median_scenario_metric(repetitions: Array, metric_name: String) -> float:
	var values: Array = []
	for repetition_any in repetitions:
		values.append(float((repetition_any as Dictionary).get(metric_name)))
	values.sort()
	var index: int = clampi(int(round(0.5 * float(values.size() - 1))), 0, values.size() - 1)
	return float(values[index])


static func _marker_for_regression(regression_percent: float, gates: Dictionary) -> String:
	if regression_percent >= float(gates.get("fail_regression_percent", 20.0)):
		return "FAIL"
	if regression_percent >= float(gates.get("warn_regression_percent", 10.0)):
		return "WARN"
	return "PASS"


static func _regression_percent(baseline_value: float, current_value: float) -> float:
	if baseline_value <= 0.000001:
		return 0.0 if current_value <= 0.000001 else 9999.0
	return ((current_value - baseline_value) / baseline_value) * 100.0
