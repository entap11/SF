extends SceneTree

const DEFAULT_GATES_PATH := "res://data/perf/benchmark_gates.json"

func _init() -> void:
	var args: Dictionary = _parse_args()
	var baseline_path: String = str(args.get("baseline", ""))
	var current_path: String = str(args.get("current", ""))
	if baseline_path.is_empty() or current_path.is_empty():
		print("Usage: godot --path . --script res://scripts/tools/perf_compare.gd -- baseline.json current.json [--gates gates.json]")
		quit(2)
		return
	var gates: Dictionary = _load_json(str(args.get("gates", DEFAULT_GATES_PATH)))
	if gates.is_empty():
		gates = _default_gates()
	var baseline: Dictionary = _load_json(baseline_path)
	var current: Dictionary = _load_json(current_path)
	if baseline.is_empty() or current.is_empty():
		print("FAIL\nCould not read benchmark report(s).")
		quit(1)
		return
	var result: Dictionary = _compare_reports(baseline, current, gates)
	print(str(result.get("text", "")))
	quit(int(result.get("exit_code", 1)))

func _compare_reports(baseline: Dictionary, current: Dictionary, gates: Dictionary) -> Dictionary:
	var baseline_by_id: Dictionary = _scenarios_by_id(baseline)
	var current_by_id: Dictionary = _scenarios_by_id(current)
	var ids: Array = current_by_id.keys()
	ids.sort()
	var lines: Array[String] = []
	var overall := "PASS"
	for id_any in ids:
		var scenario_id := str(id_any)
		var cur: Dictionary = current_by_id[scenario_id] as Dictionary
		var base: Dictionary = baseline_by_id.get(scenario_id, {}) as Dictionary
		var verdict: Dictionary = _scenario_verdict(base, cur, gates)
		var status := str(verdict.get("status", "FAIL"))
		if status == "FAIL":
			overall = "FAIL"
		elif status == "WARN" and overall == "PASS":
			overall = "WARN"
		lines.append(scenario_id)
		lines.append(status)
		lines.append_array(verdict.get("lines", []) as Array[String])
		lines.append("")
	lines.append("Overall:")
	lines.append(overall)
	var exit_code := 0
	if overall == "WARN":
		exit_code = 1
	elif overall == "FAIL":
		exit_code = 2
	return {"status": overall, "text": "\n".join(lines), "exit_code": exit_code}

func _scenario_verdict(baseline: Dictionary, current: Dictionary, gates: Dictionary) -> Dictionary:
	var status := "PASS"
	var lines: Array[String] = []
	if not bool(current.get("pass", false)) and not bool(current.get("allowed_failure", false)):
		status = "FAIL"
		var failed_gates: Array = current.get("failed_gates", []) as Array
		if not failed_gates.is_empty():
			lines.append("Failed gates: %s" % JSON.stringify(failed_gates))
	elif bool(current.get("allowed_failure", false)) and not bool(current.get("pass", false)):
		lines.append("Allowed failure target: %s" % JSON.stringify(current.get("failed_gates", [])))
	var metrics := [
		{"key": "average_frame_ms", "label": "Avg"},
		{"key": "p95_frame_ms", "label": "P95"},
		{"key": "p99_frame_ms", "label": "P99"},
		{"key": "max_frame_ms", "label": "Max"},
		{"key": "hitch_count", "label": "Hitches"}
	]
	for metric_any in metrics:
		var metric: Dictionary = metric_any as Dictionary
		var key := str(metric.get("key", ""))
		var label := str(metric.get("label", key))
		var base_value := float(baseline.get(key, 0.0))
		var cur_value := float(current.get(key, 0.0))
		var regression := _regression_percent(base_value, cur_value)
		var marker := _marker_for_regression(regression, gates)
		if marker == "FAIL" and not bool(current.get("allowed_failure", false)):
			status = "FAIL"
		elif marker == "WARN" and status == "PASS":
			status = "WARN"
		if baseline.is_empty():
			lines.append("%s: %.3f" % [label, cur_value])
		else:
			var suffix := ""
			if absf(regression) > 0.001:
				suffix = " (%+.1f%%)" % regression
			lines.append("%s: %.3f -> %.3f%s" % [label, base_value, cur_value, suffix])
	var worst := _worst_subsystem(current)
	if not worst.is_empty():
		lines.append("Worst subsystem: %s" % worst)
	return {"status": status, "lines": lines}

func _marker_for_regression(regression_percent: float, gates: Dictionary) -> String:
	if regression_percent >= float(gates.get("fail_regression_percent", 20.0)):
		return "FAIL"
	if regression_percent >= float(gates.get("warn_regression_percent", 10.0)):
		return "WARN"
	return "PASS"

func _regression_percent(baseline_value: float, current_value: float) -> float:
	if baseline_value <= 0.000001:
		return 0.0 if current_value <= 0.000001 else 9999.0
	return ((current_value - baseline_value) / baseline_value) * 100.0

func _worst_subsystem(scenario: Dictionary) -> String:
	var hitches: Array = scenario.get("hitches", []) as Array
	if not hitches.is_empty():
		var first: Dictionary = hitches[0] as Dictionary
		var sim: Array = first.get("top_sim_sections", []) as Array
		if not sim.is_empty():
			var section: Dictionary = sim[0] as Dictionary
			return "%s %.3fms" % [str(section.get("section", "")), float(section.get("ms", 0.0))]
		var render: Array = first.get("top_render_sections", []) as Array
		if not render.is_empty():
			var section_r: Dictionary = render[0] as Dictionary
			return "%s %.3fms" % [str(section_r.get("section", "")), float(section_r.get("ms", 0.0))]
	var ticks: Array = scenario.get("worst_sim_ticks", []) as Array
	if not ticks.is_empty():
		var tick: Dictionary = ticks[0] as Dictionary
		var sections: Array = tick.get("top_sim_sections", []) as Array
		if not sections.is_empty():
			var section_t: Dictionary = sections[0] as Dictionary
			return "%s %.3fms" % [str(section_t.get("section", "")), float(section_t.get("ms", 0.0))]
	return ""

func _scenarios_by_id(report: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for scenario_any in report.get("scenarios", []) as Array:
		var scenario: Dictionary = scenario_any as Dictionary
		out[str(scenario.get("scenario_id", ""))] = scenario
	return out

func _parse_args() -> Dictionary:
	var out := {"gates": DEFAULT_GATES_PATH}
	var positional: Array[String] = []
	var args := _cmdline_args()
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		if arg.begins_with("--gates="):
			out["gates"] = arg.trim_prefix("--gates=")
		elif arg == "--gates" and i + 1 < args.size():
			i += 1
			out["gates"] = str(args[i])
		elif not arg.begins_with("--"):
			positional.append(arg)
		i += 1
	if positional.size() >= 2:
		out["baseline"] = positional[positional.size() - 2]
		out["current"] = positional[positional.size() - 1]
	return out

func _cmdline_args() -> PackedStringArray:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return OS.get_cmdline_args()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _default_gates() -> Dictionary:
	return {
		"target_fps": 60,
		"target_frame_ms": 16.67,
		"p95_max_ms": 22.0,
		"p99_max_ms": 33.33,
		"max_frame_ms": 50.0,
		"max_hitches": 0,
		"worst_frame_limit": 10,
		"warn_regression_percent": 10.0,
		"fail_regression_percent": 20.0
	}
