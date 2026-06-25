extends SceneTree

const Manifest := preload("res://tools/player_config_matrix_manifest.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")

const DEFAULT_REPORT_PATH := "res://artifacts/player_config_matrix/soak_latest.json"
const DEFAULT_LOG_DIR := "res://artifacts/player_config_matrix/logs"
const DEFAULT_SECONDS := 30
const DEFAULT_ROUND_SECONDS := 10
const DEFAULT_PAIR_COUNT := 2
const DEFAULT_START_TIMEOUT_MS := 45000
const SOAK_TIER_FAST_CONFIGS: Array[String] = [
	"1v1__stage_race__free",
	"1v1__hidden_capture_flag__free",
	"4p_ffa__stage_race__free"
]
const SOAK_TIER_PR_CONFIGS: Array[String] = [
	"1v1__stage_race__free",
	"1v1__stage_race__paid_1",
	"1v1__hidden_capture_flag__free",
	"2v2__capture_flag__free",
	"2v2__capture_flag__paid_1",
	"3p_ffa__timed_race__free",
	"3p_ffa__timed_race__paid_1",
	"4p_ffa__miss_n_out__free",
	"4p_ffa__hidden_capture_flag__paid_1"
]

var _config_id := ""
var _tier := "fast"
var _seed := 0
var _seed_runs := 1
var _seconds := DEFAULT_SECONDS
var _round_seconds := DEFAULT_ROUND_SECONDS
var _pair_count := DEFAULT_PAIR_COUNT
var _start_timeout_ms := DEFAULT_START_TIMEOUT_MS
var _report_path := DEFAULT_REPORT_PATH
var _list_only := false

func _initialize() -> void:
	_parse_args()
	await process_frame
	if _list_only:
		for row in _selected_rows():
			print("%s topology=%s rules=%s map=%s" % [
				str(row.get("config_id", "")),
				str(row.get("topology", "")),
				str(row.get("rules_mode", "")),
				str(row.get("resolved_map_path", ""))
			])
		quit(0)
		return
	var started_ms: int = Time.get_ticks_msec()
	var rows: Array[Dictionary] = _selected_rows()
	var report_rows: Array[Dictionary] = []
	for row in rows:
		for seed_run_index in range(_seed_runs):
			var run_seed: int = _seed + seed_run_index
			report_rows.append(_execute_soak(row, run_seed, seed_run_index))
	var summary: Dictionary = _summary(report_rows, started_ms)
	var generated_report_path: String = _timestamped_report_path()
	var report: Dictionary = {
		"ok": int(summary.get("failed", 0)) == 0,
		"tier": _tier,
		"config_id": _config_id,
		"seed": _seed,
		"seed_runs": _seed_runs,
		"seconds": _seconds,
		"round_seconds": _round_seconds,
		"pairs": _pair_count,
		"start_timeout_ms": _start_timeout_ms,
		"generated_unix": int(Time.get_unix_time_from_system()),
		"generated_report_path": generated_report_path,
		"elapsed_ms": int(summary.get("elapsed_ms", 0)),
		"summary": summary,
		"rows": report_rows
	}
	_write_report(report, generated_report_path)
	print("PLAYER_CONFIG_MATRIX_SOAK_SUMMARY: %s" % JSON.stringify(summary))
	print("PLAYER_CONFIG_MATRIX_SOAK_REPORT: %s" % _report_path)
	quit(0 if bool(report.get("ok", false)) else 1)

func _parse_args() -> void:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for i in range(args.size()):
		var arg: String = str(args[i])
		var next_arg: String = str(args[i + 1]) if i + 1 < args.size() else ""
		if arg == "--list" or arg == "--matrix-list":
			_list_only = true
		elif arg == "--soak-tier":
			_tier = next_arg.strip_edges().to_lower()
		elif arg.begins_with("--soak-tier="):
			_tier = arg.trim_prefix("--soak-tier=").strip_edges().to_lower()
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
		elif arg == "--seed-runs":
			_seed_runs = max(1, int(next_arg))
		elif arg.begins_with("--seed-runs="):
			_seed_runs = max(1, int(arg.trim_prefix("--seed-runs=")))
		elif arg.begins_with("--seconds="):
			_seconds = max(10, int(arg.trim_prefix("--seconds=")))
		elif arg.begins_with("--soak-seconds="):
			_seconds = max(10, int(arg.trim_prefix("--soak-seconds=")))
		elif arg.begins_with("--round-seconds="):
			_round_seconds = max(10, int(arg.trim_prefix("--round-seconds=")))
		elif arg.begins_with("--soak-round-seconds="):
			_round_seconds = max(10, int(arg.trim_prefix("--soak-round-seconds=")))
		elif arg.begins_with("--pairs="):
			_pair_count = clampi(int(arg.trim_prefix("--pairs=")), 1, 8)
		elif arg.begins_with("--soak-pairs="):
			_pair_count = clampi(int(arg.trim_prefix("--soak-pairs=")), 1, 8)
		elif arg.begins_with("--start-timeout-ms="):
			_start_timeout_ms = max(1000, int(arg.trim_prefix("--start-timeout-ms=")))
		elif arg.begins_with("--soak-start-timeout-ms="):
			_start_timeout_ms = max(1000, int(arg.trim_prefix("--soak-start-timeout-ms=")))
		elif arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=").strip_edges()
		elif arg.begins_with("--matrix-report="):
			_report_path = arg.trim_prefix("--matrix-report=").strip_edges()

func _selected_rows() -> Array[Dictionary]:
	if not _config_id.is_empty():
		var row: Dictionary = Manifest.row_by_id(_config_id)
		if row.is_empty():
			return [{
				"config_id": _config_id,
				"expected_contract": Manifest.EXPECT_INVALID,
				"expected_failure_reason": "unknown_config_id"
			}]
		return [row]
	var soak_config_ids: Array[String] = _soak_config_ids_for_tier(_tier)
	if not soak_config_ids.is_empty():
		var rows_for_soak_tier: Array[Dictionary] = []
		for config_id in soak_config_ids:
			var tier_row: Dictionary = Manifest.row_by_id(config_id)
			if tier_row.is_empty():
				rows_for_soak_tier.append({
					"config_id": config_id,
					"expected_contract": Manifest.EXPECT_INVALID,
					"expected_failure_reason": "unknown_config_id"
				})
			else:
				rows_for_soak_tier.append(tier_row)
		return rows_for_soak_tier
	var selected: Array[Dictionary] = []
	for row in Manifest.rows():
		var tiers: Array = row.get("tiers", []) as Array
		if tiers.has(_tier) and str(row.get("expected_contract", "")) == Manifest.EXPECT_VALID:
			selected.append(row)
	return selected

func _soak_config_ids_for_tier(tier: String) -> Array[String]:
	match tier.strip_edges().to_lower():
		"fast":
			return SOAK_TIER_FAST_CONFIGS.duplicate()
		"pr":
			return SOAK_TIER_PR_CONFIGS.duplicate()
		_:
			return []

func _execute_soak(row: Dictionary, run_seed: int, seed_run_index: int) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var config_id: String = str(row.get("config_id", ""))
	var log_path: String = _log_path_for(config_id, run_seed)
	if str(row.get("expected_contract", "")) != Manifest.EXPECT_VALID:
		return _row_result(row, run_seed, seed_run_index, "skipped", Time.get_ticks_msec() - started_ms, "invalid contract config has no soak route", log_path, -1)
	var executable: String = OS.get_executable_path()
	var project_root: String = ProjectSettings.globalize_path("res://")
	var args := PackedStringArray([
		"--headless",
		"--path",
		project_root,
		"--script",
		"res://scripts/dev/soak_perf_runner.gd",
		"--",
		"--matrix-config=%s" % config_id,
		"--matrix-seed=%d" % run_seed,
		"--seconds=%d" % _seconds,
		"--round-seconds=%d" % _round_seconds,
		"--pairs=%d" % _pair_count,
		"--start-timeout-ms=%d" % _start_timeout_ms
	])
	var output: Array = []
	print("PLAYER_CONFIG_MATRIX_SOAK_RUN: %s seed=%d seconds=%d round_seconds=%d pairs=%d" % [config_id, run_seed, _seconds, _round_seconds, _pair_count])
	var exit_code: int = OS.execute(executable, args, output, true, false)
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	var log_text: String = _join_output(output)
	_write_log(log_path, log_text)
	var status := "pass" if exit_code == 0 else "fail"
	var first_failure: String = "" if exit_code == 0 else _first_failure_line(log_text)
	if first_failure.is_empty() and exit_code != 0:
		first_failure = "soak exited %d" % exit_code
	return _row_result(row, run_seed, seed_run_index, status, elapsed_ms, first_failure, log_path, exit_code)

func _row_result(row: Dictionary, run_seed: int, seed_run_index: int, status: String, elapsed_ms: int, first_failure: String, log_path: String, exit_code: int) -> Dictionary:
	var config_id: String = str(row.get("config_id", ""))
	return {
		"config_id": config_id,
		"run_id": "%s__seed_%d" % [config_id, run_seed],
		"tier": _tier,
		"topology": str(row.get("topology", "")),
		"contract_mode": str(row.get("contract_mode", "")),
		"rules_mode": str(row.get("rules_mode", "")),
		"map": str(row.get("resolved_map_path", "")),
		"map_variant": MAP_REGISTRY.player_variant_for_path(str(row.get("resolved_map_path", ""))),
		"entry_type": str(row.get("entry_type", "")),
		"ctf_options": row.get("ctf_options", {}),
		"seed": run_seed,
		"seed_run_index": seed_run_index,
		"seed_runs": _seed_runs,
		"seconds": _seconds,
		"round_seconds": _round_seconds,
		"pairs": _pair_count,
		"start_timeout_ms": _start_timeout_ms,
		"expected_contract": str(row.get("expected_contract", "")),
		"result": status,
		"exit_code": exit_code,
		"elapsed_ms": elapsed_ms,
		"first_failure_line": first_failure,
		"log_path": log_path,
		"replay_command": "scripts/dev/run_player_config_matrix.sh --soak-routes --config %s --seed %d --seed-runs 1 --seconds %d --round-seconds %d --pairs %d --start-timeout-ms %d" % [
			config_id,
			run_seed,
			_seconds,
			_round_seconds,
			_pair_count,
			_start_timeout_ms
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

func _log_path_for(config_id: String, run_seed: int) -> String:
	var clean_config: String = config_id.strip_edges().replace("/", "_").replace(":", "_")
	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	return DEFAULT_LOG_DIR.path_join("matrix_soak_%s_seed_%d_%s.log" % [clean_config, run_seed, stamp])

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
		if upper.find("SOAK_ERROR") >= 0 or upper.find("ERROR:") >= 0 or upper.find("FAIL") >= 0:
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
		push_error("PLAYER_CONFIG_MATRIX_SOAK: failed to open log %s" % log_path)
		return
	file.store_string(text)

func _write_report(report: Dictionary, history_path: String) -> void:
	_write_report_file(_report_path, report)
	if history_path != _report_path:
		_write_report_file(history_path, report)

func _write_report_file(path: String, report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PLAYER_CONFIG_MATRIX_SOAK: failed to open report %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))

func _timestamped_report_path() -> String:
	var stamp: String = "%d" % int(Time.get_unix_time_from_system())
	return "res://artifacts/player_config_matrix/soak_%s.json" % stamp
