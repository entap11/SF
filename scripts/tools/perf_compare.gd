extends SceneTree

const PERF_FIXTURE_VALIDATOR := preload("res://scripts/tests/perf/perf_fixture_validator.gd")
const PERF_BASELINE_COMPARATOR := preload("res://scripts/tests/perf/perf_baseline_comparator.gd")
const PERF_RESULT_CONTRACT := preload("res://scripts/tests/perf/perf_result_contract.gd")

const DEFAULT_GATES_PATH := "res://data/perf/benchmark_gates.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: Dictionary = _parse_args()
	var baseline_path: String = str(args.get("baseline", ""))
	var current_path: String = str(args.get("current", ""))
	if baseline_path.is_empty() or current_path.is_empty():
		print("Usage: godot --headless --path . --script res://scripts/tools/perf_compare.gd -- res://baseline.json res://current.json [--gates=res://data/perf/benchmark_gates.json]")
		quit(2)
		return
	var gate_result: Dictionary = PERF_FIXTURE_VALIDATOR.load_gate_config(str(args.get("gates", DEFAULT_GATES_PATH)))
	if not bool(gate_result.get("ok", false)):
		_refuse("gate_validation_failed", {"errors": gate_result.get("errors", [])})
		return
	var baseline_result: Dictionary = _load_report(baseline_path)
	var current_result: Dictionary = _load_report(current_path)
	if not bool(baseline_result.get("ok", false)) or not bool(current_result.get("ok", false)):
		_refuse("report_load_failed", {
			"baseline": baseline_result,
			"current": current_result
		})
		return
	var baseline: Dictionary = baseline_result.get("report", {}) as Dictionary
	var current: Dictionary = current_result.get("report", {}) as Dictionary
	var comparison: Dictionary = PERF_BASELINE_COMPARATOR.compare(
		baseline,
		current,
		gate_result.get("gates", {}) as Dictionary
	)
	var approval: Dictionary = PERF_RESULT_CONTRACT.baseline_approval(
		current,
		comparison.get("compatibility", {}) as Dictionary,
		baseline
	)
	var report := {
		"report_type": "sf_perf_compare_v2",
		"result_schema_version": PERF_RESULT_CONTRACT.RESULT_SCHEMA_VERSION,
		"baseline_path": baseline_path,
		"current_path": current_path,
		"gate_source": str(gate_result.get("source", "")),
		"comparison": comparison,
		"baseline_approval": approval,
		"pass": bool(comparison.get("pass", false))
	}
	print("perf_compare: %s" % JSON.stringify(report))
	quit(PERF_BASELINE_COMPARATOR.exit_code(comparison))


func _refuse(reason: String, evidence: Dictionary = {}) -> void:
	print("perf_compare: %s" % JSON.stringify({
		"report_type": "sf_perf_compare_v2",
		"status": "INCOMPATIBLE",
		"pass": false,
		"reason": reason,
		"evidence": evidence
	}))
	quit(2)


func _parse_args() -> Dictionary:
	var out := {"gates": DEFAULT_GATES_PATH}
	var positional: Array[String] = []
	var args: PackedStringArray = _cmdline_args()
	var i: int = 0
	while i < args.size():
		var arg: String = str(args[i])
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
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return user_args
	return OS.get_cmdline_args()


func _load_report(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "path": path, "reason": "cannot_open"}
	var json := JSON.new()
	var parse_error: int = json.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"ok": false,
			"path": path,
			"reason": "json_parse_failed",
			"line": json.get_error_line(),
			"message": json.get_error_message()
		}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "path": path, "reason": "root_not_dictionary"}
	return {"ok": true, "path": path, "report": json.data as Dictionary}
