extends SceneTree

const Manifest := preload("res://tools/player_config_matrix_manifest.gd")

const DEFAULT_REPORT_PATH := "res://artifacts/player_config_matrix/boot_routes_latest.json"
const DEFAULT_LOG_DIR := "res://artifacts/player_config_matrix/logs"

var _config_id := ""
var _tier := "fast"
var _seed := 0
var _report_path := DEFAULT_REPORT_PATH
var _list_only := false

func _initialize() -> void:
	_parse_args()
	await process_frame
	if _list_only:
		for route in Manifest.smoke_routes():
			print("%s -> %s coverage=%s" % [
				str(route.get("route_id", "")),
				str(route.get("script", "")),
				str(route.get("coverage", []))
			])
		quit(0)
		return
	var started_ms: int = Time.get_ticks_msec()
	var rows: Array[Dictionary] = _selected_rows()
	var route_results: Dictionary = _execute_unique_routes(rows)
	var report_rows: Array[Dictionary] = []
	for row in rows:
		report_rows.append(_config_route_result(row, route_results))
	var summary: Dictionary = _summary(report_rows, started_ms)
	var report: Dictionary = {
		"ok": int(summary.get("failed", 0)) == 0,
		"tier": _tier,
		"config_id": _config_id,
		"seed": _seed,
		"generated_unix": int(Time.get_unix_time_from_system()),
		"elapsed_ms": int(summary.get("elapsed_ms", 0)),
		"summary": summary,
		"rows": report_rows,
		"route_results": route_results.values(),
		"smoke_routes": Manifest.smoke_routes()
	}
	_write_report(report)
	print("PLAYER_CONFIG_MATRIX_BOOT_SUMMARY: %s" % JSON.stringify(summary))
	print("PLAYER_CONFIG_MATRIX_BOOT_REPORT: %s" % _report_path)
	quit(0 if bool(report.get("ok", false)) else 1)

func _parse_args() -> void:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg == "--list" or arg == "--matrix-list":
			_list_only = true
		elif arg.begins_with("--tier="):
			_tier = arg.trim_prefix("--tier=").strip_edges().to_lower()
		elif arg.begins_with("--matrix-tier="):
			_tier = arg.trim_prefix("--matrix-tier=").strip_edges().to_lower()
		elif arg.begins_with("--config="):
			_config_id = arg.trim_prefix("--config=").strip_edges()
		elif arg.begins_with("--matrix-config="):
			_config_id = arg.trim_prefix("--matrix-config=").strip_edges()
		elif arg.begins_with("--replay="):
			_config_id = arg.trim_prefix("--replay=").strip_edges()
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--matrix-seed="):
			_seed = int(arg.trim_prefix("--matrix-seed="))
		elif arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=").strip_edges()
		elif arg.begins_with("--matrix-report="):
			_report_path = arg.trim_prefix("--matrix-report=").strip_edges()
	if _tier.is_empty():
		_tier = "fast"

func _selected_rows() -> Array[Dictionary]:
	if not _config_id.is_empty():
		var row: Dictionary = Manifest.row_by_id(_config_id)
		if row.is_empty():
			return [{
				"config_id": _config_id,
				"existing_smoke": [],
				"expected_contract": Manifest.EXPECT_INVALID
			}]
		return [row]
	var selected: Array[Dictionary] = []
	for row in Manifest.rows():
		var tiers: Array = row.get("tiers", []) as Array
		if tiers.has(_tier):
			selected.append(row)
	return selected

func _execute_unique_routes(rows: Array[Dictionary]) -> Dictionary:
	var route_requests: Dictionary = {}
	for row in rows:
		if str(row.get("expected_contract", "")) != Manifest.EXPECT_VALID:
			continue
		var config_id: String = str(row.get("config_id", ""))
		var scripts: Array = row.get("existing_smoke", []) as Array
		for script_any in scripts:
			var script_path: String = _normalize_script_path(str(script_any))
			if script_path.is_empty():
				continue
			var request_key: String = _route_request_key(script_path, config_id)
			if not route_requests.has(request_key):
				route_requests[request_key] = {
					"script": script_path,
					"config_ids": [],
					"extra_args": _extra_args_for_script(script_path, config_id)
				}
			var request: Dictionary = route_requests[request_key] as Dictionary
			var configs: Array = request.get("config_ids", []) as Array
			if not configs.has(config_id):
				configs.append(config_id)
			request["config_ids"] = configs
	var route_results: Dictionary = {}
	for request_key in route_requests.keys():
		var request: Dictionary = route_requests[request_key] as Dictionary
		route_results[request_key] = _execute_smoke_script(
			str(request.get("script", "")),
			request.get("config_ids", []) as Array,
			request.get("extra_args", PackedStringArray()) as PackedStringArray
		)
	return route_results

func _execute_smoke_script(script_path: String, config_ids: Array, extra_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var normalized: String = _normalize_script_path(script_path)
	var route_id: String = _route_id_for_script(normalized)
	var log_path: String = _log_path_for(route_id, config_ids)
	if not ResourceLoader.exists(normalized):
		var missing_result: Dictionary = _route_result(route_id, normalized, config_ids, "fail", -1, Time.get_ticks_msec() - started_ms, log_path, "missing smoke script")
		_write_log(log_path, "Missing smoke script: %s\n" % normalized)
		return missing_result
	var output: Array = []
	var executable: String = OS.get_executable_path()
	var project_root: String = ProjectSettings.globalize_path("res://")
	var args := PackedStringArray([
		"--headless",
		"--path",
		project_root,
		"--script",
		normalized
	])
	if not extra_args.is_empty():
		args.append("--")
		for extra_arg in extra_args:
			args.append(extra_arg)
	print("PLAYER_CONFIG_MATRIX_BOOT_RUN: %s configs=%s args=%s" % [normalized, str(config_ids), str(extra_args)])
	var exit_code: int = OS.execute(executable, args, output, true, false)
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	var log_text: String = _join_output(output)
	_write_log(log_path, log_text)
	var status := "pass" if exit_code == 0 else "fail"
	var first_failure: String = "" if exit_code == 0 else _first_failure_line(log_text)
	if first_failure.is_empty() and exit_code != 0:
		first_failure = "smoke exited %d" % exit_code
	return _route_result(route_id, normalized, config_ids, status, exit_code, elapsed_ms, log_path, first_failure)

func _config_route_result(row: Dictionary, route_results: Dictionary) -> Dictionary:
	var config_id: String = str(row.get("config_id", ""))
	var scripts: Array = row.get("existing_smoke", []) as Array
	var selected_results: Array = []
	for script_any in scripts:
		var script_path: String = _normalize_script_path(str(script_any))
		var request_key: String = _route_request_key(script_path, config_id)
		if route_results.has(request_key):
			selected_results.append(route_results[request_key])
	var status := "skipped"
	var first_failure := ""
	var log_paths: Array[String] = []
	if selected_results.is_empty():
		first_failure = "no existing smoke route for config" if str(row.get("expected_contract", "")) == Manifest.EXPECT_VALID else "invalid contract config has no runtime route"
	else:
		status = "pass"
		for result_any in selected_results:
			var result: Dictionary = result_any as Dictionary
			log_paths.append(str(result.get("log_path", "")))
			if str(result.get("result", "")) == "fail":
				status = "fail"
				if first_failure.is_empty():
					first_failure = str(result.get("first_failure_line", ""))
	return {
		"config_id": config_id,
		"tier": _tier,
		"topology": str(row.get("topology", "")),
		"contract_mode": str(row.get("contract_mode", "")),
		"rules_mode": str(row.get("rules_mode", "")),
		"map": str(row.get("resolved_map_path", "")),
		"entry_type": str(row.get("entry_type", "")),
		"seed": _seed,
		"result": status,
		"first_failure_line": first_failure,
		"log_path": ", ".join(log_paths),
		"existing_smoke": scripts,
		"route_results": selected_results,
		"replay_command": "scripts/dev/run_player_config_matrix.sh --boot-routes --config %s --seed %d" % [config_id, _seed]
	}

func _route_result(
	route_id: String,
	script_path: String,
	config_ids: Array,
	status: String,
	exit_code: int,
	elapsed_ms: int,
	log_path: String,
	first_failure: String
) -> Dictionary:
	return {
		"route_id": route_id,
		"script": script_path,
		"config_ids": config_ids,
		"result": status,
		"exit_code": exit_code,
		"elapsed_ms": elapsed_ms,
		"first_failure_line": first_failure,
		"log_path": log_path,
		"replay_command": "%s --headless --path %s --script %s" % [
			OS.get_executable_path(),
			ProjectSettings.globalize_path("res://"),
			script_path
		]
	}

func _summary(rows: Array[Dictionary], started_ms: int) -> Dictionary:
	var passed := 0
	var failed := 0
	var skipped := 0
	for row in rows:
		match str(row.get("result", "")):
			"pass":
				passed += 1
			"fail":
				failed += 1
			"skipped":
				skipped += 1
	return {
		"passed": passed,
		"failed": failed,
		"skipped": skipped,
		"elapsed_ms": Time.get_ticks_msec() - started_ms
	}

func _route_id_for_script(script_path: String) -> String:
	for route in Manifest.smoke_routes():
		if _normalize_script_path(str(route.get("script", ""))) == script_path:
			return str(route.get("route_id", script_path.get_file().get_basename()))
	return script_path.get_file().get_basename()

func _normalize_script_path(script_path: String) -> String:
	var clean: String = script_path.strip_edges()
	if clean.is_empty():
		return ""
	if clean.begins_with("res://"):
		return clean
	return "res://%s" % clean

func _route_request_key(script_path: String, config_id: String) -> String:
	var normalized: String = _normalize_script_path(script_path)
	if _script_requires_config_args(normalized):
		return "%s::%s" % [normalized, config_id]
	return normalized

func _extra_args_for_script(script_path: String, config_id: String) -> PackedStringArray:
	var normalized: String = _normalize_script_path(script_path)
	if _script_requires_config_args(normalized):
		return PackedStringArray([
			"--matrix-config=%s" % config_id,
			"--matrix-seed=%d" % _seed
		])
	return PackedStringArray()

func _script_requires_config_args(script_path: String) -> bool:
	var normalized: String = _normalize_script_path(script_path)
	return normalized == "res://tools/player_config_matrix_topology_boot_runner.gd" \
		or normalized == "res://tools/player_config_matrix_mode_runtime_runner.gd"

func _log_path_for(route_id: String, config_ids: Array = []) -> String:
	var clean_route: String = route_id.strip_edges().replace("/", "_").replace(":", "_")
	if config_ids.size() == 1:
		clean_route = "%s_%s" % [clean_route, str(config_ids[0]).replace("/", "_").replace(":", "_")]
	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	return DEFAULT_LOG_DIR.path_join("%s_%s.log" % [clean_route, stamp])

func _join_output(output: Array) -> String:
	var parts: Array[String] = []
	for item in output:
		parts.append(str(item))
	return "\n".join(parts)

func _first_failure_line(log_text: String) -> String:
	for raw_line in log_text.split("\n"):
		var line: String = str(raw_line).strip_edges()
		if line.is_empty():
			continue
		var upper: String = line.to_upper()
		if upper.find("SCRIPT ERROR") >= 0 or upper.find("[FAIL]") >= 0 or upper.find("FAIL:") >= 0 or upper.find("ERROR:") >= 0 or upper.find("PUSH_ERROR") >= 0:
			return line
	var lines: PackedStringArray = log_text.split("\n")
	for i in range(lines.size() - 1, -1, -1):
		var fallback: String = str(lines[i]).strip_edges()
		if not fallback.is_empty():
			return fallback
	return ""

func _write_log(log_path: String, text: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(log_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		push_error("PLAYER_CONFIG_MATRIX_BOOT_ROUTES: failed to open log %s" % log_path)
		return
	file.store_string(text)

func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_report_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("PLAYER_CONFIG_MATRIX_BOOT_ROUTES: failed to open report %s" % _report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
