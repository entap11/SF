extends SceneTree

func _initialize() -> void:
	var args: Array = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("perf_compare: usage: godot --headless --script res://tools/perf_compare.gd -- res://baseline.json res://latest.json")
		quit(2)
		return
	var baseline_path := str(args[0])
	var latest_path := str(args[1])
	var baseline: Dictionary = _load_json(baseline_path)
	var latest: Dictionary = _load_json(latest_path)
	if baseline.is_empty() or latest.is_empty():
		print("perf_compare: failed to load reports")
		quit(2)
		return
	var gates: Dictionary = latest.get("gates", baseline.get("gates", {})) as Dictionary
	var warn_percent: float = float(gates.get("warn_regression_percent", 10.0))
	var fail_percent: float = float(gates.get("fail_regression_percent", 20.0))
	var baseline_by_id: Dictionary = _scenarios_by_id(baseline)
	var comparisons: Array = []
	var failed: Array = []
	var warned: Array = []
	for latest_any in latest.get("scenarios", []) as Array:
		var latest_scenario: Dictionary = latest_any as Dictionary
		var scenario_id: String = str(latest_scenario.get("scenario_id", ""))
		if not baseline_by_id.has(scenario_id):
			continue
		var base_scenario: Dictionary = baseline_by_id.get(scenario_id, {}) as Dictionary
		var comparison: Dictionary = _compare_scenario(base_scenario, latest_scenario, warn_percent, fail_percent)
		comparisons.append(comparison)
		if bool(comparison.get("fail", false)):
			failed.append(scenario_id)
		elif bool(comparison.get("warn", false)):
			warned.append(scenario_id)
	var report := {
		"report_type": "sf_perf_compare",
		"baseline": baseline_path,
		"latest": latest_path,
		"warn_regression_percent": warn_percent,
		"fail_regression_percent": fail_percent,
		"comparisons": comparisons,
		"warned_scenarios": warned,
		"failed_scenarios": failed,
		"pass": failed.is_empty()
	}
	print("perf_compare: %s" % JSON.stringify(report))
	quit(0 if failed.is_empty() else 1)

func _compare_scenario(base: Dictionary, latest: Dictionary, warn_percent: float, fail_percent: float) -> Dictionary:
	var metrics := ["average_frame_ms", "p95_frame_ms", "p99_frame_ms", "max_frame_ms", "hitch_count"]
	var entries: Array = []
	var warn := false
	var fail := false
	for metric in metrics:
		var base_value: float = float(base.get(metric, 0.0))
		var latest_value: float = float(latest.get(metric, 0.0))
		var change_percent: float = 0.0
		if base_value > 0.0:
			change_percent = ((latest_value - base_value) / base_value) * 100.0
		var metric_warn: bool = change_percent >= warn_percent
		var metric_fail: bool = change_percent >= fail_percent
		warn = warn or metric_warn
		fail = fail or metric_fail
		entries.append({
			"metric": metric,
			"baseline": base_value,
			"latest": latest_value,
			"change_percent": snappedf(change_percent, 0.01),
			"warn": metric_warn,
			"fail": metric_fail
		})
	return {
		"scenario_id": str(latest.get("scenario_id", "")),
		"metrics": entries,
		"warn": warn,
		"fail": fail
	}

func _scenarios_by_id(report: Dictionary) -> Dictionary:
	var out := {}
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		out[str(scenario.get("scenario_id", ""))] = scenario
	return out

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary
