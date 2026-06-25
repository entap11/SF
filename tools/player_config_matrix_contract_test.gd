extends SceneTree

const Manifest := preload("res://tools/player_config_matrix_manifest.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")

const DEFAULT_REPORT_PATH := "res://artifacts/player_config_matrix/latest.json"

var _failed := false
var _tier := "fast"
var _config_id := ""
var _seed := 0
var _report_path := DEFAULT_REPORT_PATH
var _list_only := false

func _initialize() -> void:
	_parse_args()
	await process_frame
	if _list_only:
		_print_list()
		quit(0)
		return
	var started_ms: int = Time.get_ticks_msec()
	var rows: Array[Dictionary] = _selected_rows()
	var report_rows: Array[Dictionary] = []
	var schema_failures: Array[String] = _validate_manifest_schema(Manifest.rows())
	for failure in schema_failures:
		report_rows.append(_suite_result("schema", "fail", failure, {}))
	if schema_failures.is_empty():
		report_rows.append(_suite_result("schema", "pass", "", {"row_count": Manifest.rows().size()}))
	var parity_failures: Array[String] = []
	if schema_failures.is_empty():
		parity_failures = _validate_contract_surface_parity(rows)
	for failure in parity_failures:
		report_rows.append(_suite_result("parity", "fail", failure, {}))
	if schema_failures.is_empty() and parity_failures.is_empty():
		report_rows.append(_suite_result("parity", "pass", "", {"row_count": rows.size()}))
	if schema_failures.is_empty():
		for row in rows:
			report_rows.append(_validate_row(row))
			report_rows.append(_runtime_route_row(row))
	var summary: Dictionary = _summary(report_rows, started_ms)
	_failed = int(summary.get("failed", 0)) > 0
	var report: Dictionary = {
		"ok": not _failed,
		"tier": _tier,
		"config_id": _config_id,
		"seed": _seed,
		"generated_unix": int(Time.get_unix_time_from_system()),
		"elapsed_ms": int(summary.get("elapsed_ms", 0)),
		"summary": summary,
		"rows": report_rows,
		"smoke_routes": Manifest.smoke_routes()
	}
	_write_report(report)
	print("PLAYER_CONFIG_MATRIX_SUMMARY: %s" % JSON.stringify(summary))
	print("PLAYER_CONFIG_MATRIX_REPORT: %s" % _report_path)
	quit(1 if _failed else 0)

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
	if _report_path.is_empty():
		_report_path = DEFAULT_REPORT_PATH

func _print_list() -> void:
	for row in Manifest.rows():
		print("%s tier=%s topology=%s contract=%s rules=%s expected=%s map=%s" % [
			str(row.get("config_id", "")),
			str(row.get("tiers", [])),
			str(row.get("topology", "")),
			str(row.get("contract_mode", "")),
			str(row.get("rules_mode", "")),
			str(row.get("expected_contract", "")),
			str(row.get("resolved_map_path", ""))
		])

func _selected_rows() -> Array[Dictionary]:
	var all_rows: Array[Dictionary] = Manifest.rows()
	if not _config_id.is_empty():
		var row: Dictionary = Manifest.row_by_id(_config_id)
		if row.is_empty():
			return [{
				"config_id": _config_id,
				"expected_contract": Manifest.EXPECT_INVALID,
				"expected_failure_reason": "unknown_config_id"
			}]
		return [row]
	var selected: Array[Dictionary] = []
	for row in all_rows:
		var tiers: Array = row.get("tiers", []) as Array
		if tiers.has(_tier):
			selected.append(row)
	return selected

func _validate_manifest_schema(rows: Array[Dictionary]) -> Array[String]:
	var failures: Array[String] = []
	var seen: Dictionary = {}
	var allowed_topologies: Array[String] = []
	for entry in Manifest.topology_entries():
		allowed_topologies.append(str(entry.get("topology", "")))
	var allowed_contract_modes: Array[String] = [
		Manifest.CONTRACT_1V1,
		Manifest.CONTRACT_2V2,
		Manifest.CONTRACT_3P_FFA,
		Manifest.CONTRACT_4P_FFA
	]
	for row in rows:
		var config_id: String = str(row.get("config_id", "")).strip_edges()
		if config_id.is_empty():
			failures.append("manifest row missing config_id: %s" % str(row))
			continue
		if seen.has(config_id):
			failures.append("duplicate config_id: %s" % config_id)
		seen[config_id] = true
		for field in ["topology", "contract_mode", "rules_mode", "source_map_path", "resolved_map_path", "entry_type", "expected_contract"]:
			if not row.has(field) or str(row.get(field, "")).strip_edges().is_empty():
				failures.append("%s missing required field %s" % [config_id, field])
		if not allowed_topologies.has(str(row.get("topology", ""))):
			failures.append("%s invalid topology: %s" % [config_id, str(row.get("topology", ""))])
		if not allowed_contract_modes.has(str(row.get("contract_mode", ""))):
			failures.append("%s invalid contract_mode: %s" % [config_id, str(row.get("contract_mode", ""))])
		if not Manifest.rules_modes().has(str(row.get("rules_mode", ""))):
			failures.append("%s invalid rules_mode: %s" % [config_id, str(row.get("rules_mode", ""))])
		var expected: String = str(row.get("expected_contract", ""))
		if expected != Manifest.EXPECT_VALID and expected != Manifest.EXPECT_INVALID:
			failures.append("%s invalid expected_contract: %s" % [config_id, expected])
		var existing_smoke: Array = row.get("existing_smoke", []) as Array
		for script_any in existing_smoke:
			var script_path: String = str(script_any)
			if not ResourceLoader.exists(script_path):
				failures.append("%s references missing smoke script: %s" % [config_id, script_path])
	return failures

func _validate_contract_surface_parity(rows: Array[Dictionary]) -> Array[String]:
	var failures: Array[String] = []
	var shell_script: Script = load("res://scripts/shell.gd") as Script
	var lobby_script: Script = load("res://scripts/ui/vs_lobby.gd") as Script
	var handshake_script: Script = load("res://scripts/state/vs_handshake_state.gd") as Script
	if shell_script == null:
		return ["failed to load Shell script for parity"]
	if lobby_script == null:
		return ["failed to load VsLobby script for parity"]
	if handshake_script == null:
		return ["failed to load VsHandshake script for parity"]
	var shell: Node = shell_script.new() as Node
	var lobby: Control = lobby_script.new() as Control
	var handshake: Node = handshake_script.new() as Node
	if shell == null or lobby == null or handshake == null:
		return ["failed to instantiate contract parity surfaces"]
	for mode in [
		Manifest.CONTRACT_1V1,
		Manifest.CONTRACT_2V2,
		Manifest.CONTRACT_3P_FFA,
		Manifest.CONTRACT_4P_FFA,
		Manifest.RULE_STAGE_RACE,
		Manifest.RULE_CAPTURE_FLAG,
		Manifest.RULE_HIDDEN_CAPTURE_FLAG,
		Manifest.RULE_TIMED_RACE,
		Manifest.RULE_MISS_N_OUT
	]:
		var expected_variant: String = Manifest.required_variant_for_contract_mode(mode)
		var shell_variant: String = str(shell.call("_required_player_variant_for_mode", mode))
		var lobby_variant: String = str(lobby.call("_required_player_variant_for_mode", mode))
		var handshake_variant: String = str(handshake.call("_required_player_variant_for_mode", mode))
		if shell_variant != expected_variant:
			failures.append("Shell variant mismatch for %s: expected=%s got=%s" % [mode, expected_variant, shell_variant])
		if lobby_variant != expected_variant:
			failures.append("VsLobby variant mismatch for %s: expected=%s got=%s" % [mode, expected_variant, lobby_variant])
		if handshake_variant != expected_variant:
			failures.append("VsHandshake variant mismatch for %s: expected=%s got=%s" % [mode, expected_variant, handshake_variant])
	for row in rows:
		if str(row.get("expected_contract", "")) != Manifest.EXPECT_VALID:
			continue
		var config_id: String = str(row.get("config_id", ""))
		var mode: String = str(row.get("contract_mode", ""))
		var path: String = str(row.get("resolved_map_path", ""))
		set_meta("vs_mode", mode)
		var shell_summary: Dictionary = shell.call("_validate_launch_map_mode_contract", path, self) as Dictionary
		var lobby_summary: Dictionary = lobby.call("_stage_map_path_supports_mode", path, mode) as Dictionary
		var handshake_summary: Dictionary = handshake.call("_stage_map_path_supports_mode", path, mode) as Dictionary
		var shell_ok: bool = bool(shell_summary.get("ok", false))
		var lobby_ok: bool = bool(lobby_summary.get("ok", false))
		var handshake_ok: bool = bool(handshake_summary.get("ok", false))
		if shell_ok != lobby_ok or shell_ok != handshake_ok:
			failures.append("%s parity ok mismatch shell=%s lobby=%s handshake=%s" % [config_id, str(shell_summary), str(lobby_summary), str(handshake_summary)])
		if not shell_ok:
			continue
		var shell_reason: String = str(shell_summary.get("reason", ""))
		var lobby_reason: String = str(lobby_summary.get("reason", ""))
		var handshake_reason: String = str(handshake_summary.get("reason", ""))
		if shell_reason != lobby_reason or shell_reason != handshake_reason:
			failures.append("%s parity reason mismatch shell=%s lobby=%s handshake=%s" % [config_id, shell_reason, lobby_reason, handshake_reason])
	if has_meta("vs_mode"):
		remove_meta("vs_mode")
	shell.free()
	lobby.free()
	handshake.free()
	return failures

func _validate_row(row: Dictionary) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var config_id: String = str(row.get("config_id", ""))
	var validation: Dictionary = _contract_validation(row)
	var actual_ok: bool = bool(validation.get("ok", false))
	var expected: String = str(row.get("expected_contract", ""))
	var expected_ok: bool = expected == Manifest.EXPECT_VALID
	var first_failure: String = ""
	var status := "pass"
	if actual_ok != expected_ok:
		status = "fail"
		first_failure = "%s expected %s but validator returned %s (%s)" % [
			config_id,
			expected,
			"valid" if actual_ok else "invalid",
			str(validation)
		]
	elif not actual_ok:
		var expected_reason: String = str(row.get("expected_failure_reason", ""))
		var actual_reason: String = str(validation.get("reason", ""))
		if not expected_reason.is_empty() and actual_reason != expected_reason:
			status = "fail"
			first_failure = "%s expected failure reason %s but got %s" % [config_id, expected_reason, actual_reason]
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	return _config_result(row, "contract", status, first_failure, elapsed_ms, {
		"contract_validation": validation
	})

func _contract_validation(row: Dictionary) -> Dictionary:
	if not row.has("topology"):
		return {"ok": false, "reason": "unknown_config_id"}
	var contract_mode: String = str(row.get("contract_mode", ""))
	var rules_mode: String = str(row.get("rules_mode", ""))
	var map_path: String = str(row.get("resolved_map_path", ""))
	var required_variant: String = Manifest.required_variant_for_contract_mode(contract_mode)
	var actual_variant: String = MAP_REGISTRY.player_variant_for_path(map_path)
	if not required_variant.is_empty() and actual_variant != required_variant:
		return {
			"ok": false,
			"reason": "requires_%s_map_path" % required_variant,
			"required_variant": required_variant,
			"actual_variant": actual_variant,
			"path": map_path
		}
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(loaded.get("ok", false)):
		return {
			"ok": false,
			"reason": str(loaded.get("err", "load_failed")),
			"path": map_path
		}
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var mode_summary: Dictionary = MapModeRules.map_supports_game_mode(data, contract_mode)
	if not bool(mode_summary.get("ok", false)):
		mode_summary["path"] = map_path
		return mode_summary
	var owner_summary: Dictionary = MapModeRules.map_matches_active_owner_contract(data, contract_mode)
	if not bool(owner_summary.get("ok", false)):
		owner_summary["path"] = map_path
		return owner_summary
	var rules_summary: Dictionary = _validate_rules(row, data)
	if not bool(rules_summary.get("ok", false)):
		rules_summary["path"] = map_path
		return rules_summary
	return {
		"ok": true,
		"reason": "",
		"path": map_path,
		"variant": actual_variant,
		"owner_counts": owner_summary.get("owner_counts", {}),
		"rules": rules_summary
	}

func _validate_rules(row: Dictionary, map_data: Dictionary) -> Dictionary:
	var rules_mode: String = str(row.get("rules_mode", ""))
	var ctf_options: Dictionary = row.get("ctf_options", {}) as Dictionary
	if rules_mode == Manifest.RULE_HIDDEN_CAPTURE_FLAG:
		if str(ctf_options.get("flag_selection_mode", "")) != "player_select":
			return {"ok": false, "reason": "hidden_ctf_requires_player_select"}
		if int(ctf_options.get("player_select_pct", -1)) != 100:
			return {"ok": false, "reason": "hidden_ctf_requires_100_pct_select"}
		if not bool(ctf_options.get("flag_move_reveals", false)):
			return {"ok": false, "reason": "hidden_ctf_requires_reveal_on_move"}
		var move_count: int = int(ctf_options.get("flag_move_count_max", -1))
		if move_count < 0 or move_count > 2:
			return {"ok": false, "reason": "ctf_invalid_move_budget"}
		var hidden_summary: Dictionary = MapModeRules.hidden_capture_flag_split_summary(map_data)
		if not bool(hidden_summary.get("ok", false)):
			return {"ok": false, "reason": "hidden_ctf_%s" % str(hidden_summary.get("reason", "invalid"))}
		return {"ok": true, "reason": "", "ctf": hidden_summary}
	if rules_mode == Manifest.RULE_CAPTURE_FLAG:
		var move_count_visible: int = int(ctf_options.get("flag_move_count_max", -1))
		if move_count_visible < 0 or move_count_visible > 2:
			return {"ok": false, "reason": "ctf_invalid_move_budget"}
		var pct: int = int(ctf_options.get("player_select_pct", 35))
		if pct < 0 or pct > 100:
			return {"ok": false, "reason": "ctf_invalid_player_select_pct"}
		return {"ok": true, "reason": ""}
	return {"ok": true, "reason": ""}

func _runtime_route_row(row: Dictionary) -> Dictionary:
	var existing_smoke: Array = row.get("existing_smoke", []) as Array
	var details: Dictionary = {
		"existing_smoke": existing_smoke,
		"note": "runtime execution is intentionally deferred in milestone 1"
	}
	return _config_result(row, "runtime_route", "skipped", "", 0, details)

func _config_result(
	row: Dictionary,
	phase: String,
	status: String,
	first_failure: String,
	elapsed_ms: int,
	details: Dictionary
) -> Dictionary:
	var config_id: String = str(row.get("config_id", ""))
	var replay_command := "scripts/dev/run_player_config_matrix.sh --config %s --seed %d" % [config_id, _seed]
	return {
		"config_id": config_id,
		"phase": phase,
		"tier": _tier,
		"topology": str(row.get("topology", "")),
		"contract_mode": str(row.get("contract_mode", "")),
		"rules_mode": str(row.get("rules_mode", "")),
		"map": str(row.get("resolved_map_path", "")),
		"map_variant": MAP_REGISTRY.player_variant_for_path(str(row.get("resolved_map_path", ""))),
		"entry_type": str(row.get("entry_type", "")),
		"ctf_options": row.get("ctf_options", {}),
		"seed": _seed,
		"expected_contract": str(row.get("expected_contract", "")),
		"result": status,
		"elapsed_ms": elapsed_ms,
		"first_failure_line": first_failure,
		"log_path": "",
		"replay_command": replay_command,
		"details": details
	}

func _suite_result(phase: String, status: String, first_failure: String, details: Dictionary) -> Dictionary:
	return {
		"config_id": phase,
		"phase": phase,
		"tier": _tier,
		"topology": "",
		"contract_mode": "",
		"rules_mode": "",
		"map": "",
		"map_variant": "",
		"entry_type": "",
		"ctf_options": {},
		"seed": _seed,
		"expected_contract": "valid",
		"result": status,
		"elapsed_ms": 0,
		"first_failure_line": first_failure,
		"log_path": "",
		"replay_command": "scripts/dev/run_player_config_matrix.sh --tier %s --seed %d" % [_tier, _seed],
		"details": details
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

func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_report_path)
	var dir_path: String = absolute_path.get_base_dir()
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if mk_err != OK:
		push_error("PLAYER_CONFIG_MATRIX: failed to create report dir %s err=%d" % [dir_path, int(mk_err)])
		_failed = true
		return
	var file: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		push_error("PLAYER_CONFIG_MATRIX: failed to open report %s" % _report_path)
		_failed = true
		return
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report.get("summary", {})))
