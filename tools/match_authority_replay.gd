extends SceneTree

const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")

func _init() -> void:
	await process_frame
	var paths: Dictionary = _argument_paths(OS.get_cmdline_user_args())
	if not bool(paths.get("ok", false)):
		_finish(str(paths.get("output", "")), {"ok": false, "error_code": "ARGUMENTS_INVALID"}, 2)
		return
	var input_path: String = str(paths.get("input", ""))
	var output_path: String = str(paths.get("output", ""))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_finish(output_path, {"ok": false, "error_code": "INPUT_JSON_INVALID"}, 2)
		return
	var result: Dictionary = await _replay(parsed as Dictionary)
	_finish(output_path, result, 0 if bool(result.get("ok", false)) else 3)

func _replay(bundle: Dictionary) -> Dictionary:
	var contract: Dictionary = bundle.get("contract", {}) as Dictionary
	var mode_id: String = str(contract.get("mode_id", ""))
	if int(contract.get("protocol_version", 0)) != 2 \
		or not ["STANDARD_1V1", "CTF_1V1"].has(mode_id) \
		or str(contract.get("authority_tier", "")) != "AUTHORITY_VERIFIED":
		return {"ok": false, "error_code": "CONTRACT_INCOMPATIBLE"}
	var roster: Array = contract.get("roster", []) as Array
	if roster.size() != 2:
		return {"ok": false, "error_code": "ROSTER_INCOMPATIBLE"}
	var map_data: Dictionary = bundle.get("map_data", {}) as Dictionary
	if map_data.is_empty():
		return {"ok": false, "error_code": "MAP_ARTIFACT_MISSING"}
	if mode_id == "CTF_1V1":
		map_data = MapModeRules.apply_capture_flag_territory_split(map_data, {"mode": "CAPTURE_FLAG"})
	var commands: Array = bundle.get("commands", []) as Array
	commands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("command_seq", 0)) < int(b.get("command_seq", 0))
	)
	for index in range(commands.size()):
		if typeof(commands[index]) != TYPE_DICTIONARY \
			or int((commands[index] as Dictionary).get("command_seq", 0)) != index + 1:
			return {"ok": false, "error_code": "COMMAND_STREAM_GAP"}
	var ops: Node = get_root().get_node_or_null("OpsState")
	if ops == null:
		return {"ok": false, "error_code": "OPS_STATE_MISSING"}
	var state: GameState = ops.call("reset_state_from_map", map_data) as GameState
	if state == null:
		return {"ok": false, "error_code": "MAP_LOAD_FAILED"}
	ops.set("match_roster", _ops_roster(roster))
	if mode_id == "CTF_1V1":
		var ruleset_data: Dictionary = bundle.get("ruleset_data", {}) as Dictionary
		var flag_result: Dictionary = ops.call("configure_capture_flag_mode", {
			"hidden_flag": false,
			"flag_selection_mode": str(ruleset_data.get("flag_selection_mode", "auto_random")),
			"flag_selection_player_select_pct": 0,
			"flag_selection_random_mirrored": bool(ruleset_data.get("flag_selection_random_mirrored", true)),
			"flag_selection_seed": maxi(1, str(contract.get("seed", "")).hash()),
			"flag_move_count_max": maxi(0, int(ruleset_data.get("flag_move_count_max", 0))),
			"flag_move_reveals": true,
			"map_data": map_data
		}) as Dictionary
		if (flag_result.get("flags_by_owner", {}) as Dictionary).size() != 2:
			return {"ok": false, "error_code": "CTF_RULES_CONFIGURATION_FAILED"}
	ops.set("match_phase", 1)
	ops.set("match_clock_started", true)
	ops.set("match_clock_running", true)
	var runner_script: Script = load("res://scripts/systems/sim_runner.gd") as Script
	if runner_script == null:
		return {"ok": false, "error_code": "SIM_RUNNER_MISSING"}
	var runner: Node = runner_script.new() as Node
	get_root().add_child(runner)
	runner.call("bind_state", state)
	runner.call("set_running", true, "match_authority_replay")
	var max_ticks: int = clampi(int((bundle.get("ruleset_data", {}) as Dictionary).get("max_sim_ticks", 12000)), 1, 36000)
	var command_index: int = 0
	var applied_commands: int = 0
	while int(state.tick) < max_ticks:
		var next_tick: int = int(state.tick) + 1
		while command_index < commands.size():
			var command: Dictionary = commands[command_index] as Dictionary
			var execute_tick: int = int(command.get("execute_tick", -1))
			if execute_tick > next_tick:
				break
			if execute_tick < next_tick:
				return {"ok": false, "error_code": "COMMAND_MISSED_EXECUTE_TICK", "command_seq": command_index + 1}
			var applied: Dictionary = _apply_command(ops, state, command)
			if not bool(applied.get("ok", false)):
				return applied
			command_index += 1
			applied_commands += 1
		runner.call("_tick", 0.1)
		if int(ops.get("winner_id")) > 0:
			break
	if command_index != commands.size():
		return {"ok": false, "error_code": "COMMANDS_AFTER_TERMINAL", "remaining": commands.size() - command_index}
	var winner_seat: int = int(ops.get("winner_id"))
	if winner_seat <= 0:
		return {"ok": false, "error_code": "MATCH_NOT_TERMINAL", "elapsed_sim_ticks": int(state.tick)}
	var winner_player_id: String = ""
	for entry_any in roster:
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("seat_id", 0)) == winner_seat:
			winner_player_id = str(entry.get("player_id", ""))
	if winner_player_id.is_empty():
		return {"ok": false, "error_code": "WINNER_NOT_IN_ROSTER"}
	return {
		"ok": true,
		"terminal_reason": "OBJECTIVE_COMPLETE",
		"winner_player_id": winner_player_id,
		"winner_seat": winner_seat,
		"elapsed_sim_ticks": int(state.tick),
		"final_state_hash": str(ops.call("get_contract_state_hash")),
		"applied_commands": applied_commands
	}

func _apply_command(ops: Node, state: GameState, command: Dictionary) -> Dictionary:
	var sender_seat: int = int(command.get("seat_id", command.get("sender_seat", 0)))
	var kind: String = str(command.get("kind", command.get("type", ""))).strip_edges().to_lower()
	match kind:
		"lane_intent", "move":
			var src: int = int(command.get("src", -1))
			var dst: int = int(command.get("dst", -1))
			var intent: String = str(command.get("intent", "attack" if kind == "move" else "")).to_lower()
			var hive: HiveData = state.find_hive_by_id(src)
			if hive == null or int(hive.owner_id) != sender_seat:
				return {"ok": false, "error_code": "COMMAND_OWNERSHIP_INVALID"}
			var holder: Dictionary = {"result": {}}
			ops.call("with_remote_replication_apply", func() -> void:
				holder["result"] = ops.call("apply_lane_intent", src, dst, intent)
			)
			if not bool((holder.get("result", {}) as Dictionary).get("ok", false)):
				return {"ok": false, "error_code": "COMMAND_REJECTED", "detail": holder.get("result", {})}
		"lane_retract":
			var from_id: int = int(command.get("from_id", -1))
			var to_id: int = int(command.get("to_id", -1))
			var from_hive: HiveData = state.find_hive_by_id(from_id)
			if from_hive == null or int(from_hive.owner_id) != sender_seat:
				return {"ok": false, "error_code": "COMMAND_OWNERSHIP_INVALID"}
			ops.call("with_remote_replication_apply", func() -> void:
				ops.call("retract_lane", from_id, to_id, sender_seat)
			)
		"barracks_route":
			var route: Array = command.get("route_hive_ids", []) as Array
			ops.call("with_remote_replication_apply", func() -> void:
				ops.call("request_barracks_route", int(command.get("barracks_id", -1)), route, sender_seat)
			)
		"buff_activate":
			var buff_result: Dictionary = ops.call("apply_authoritative_buff_command", command) as Dictionary
			if not bool(buff_result.get("ok", false)) and str(buff_result.get("status", "")) != "applied":
				return {"ok": false, "error_code": "BUFF_COMMAND_REJECTED", "detail": buff_result}
		_:
			return {"ok": false, "error_code": "COMMAND_KIND_UNSUPPORTED", "kind": kind}
	return {"ok": true}

func _ops_roster(roster: Array) -> Array:
	var out: Array = []
	for entry_any in roster:
		var entry: Dictionary = entry_any as Dictionary
		out.append({
			"uid": str(entry.get("player_id", "")),
			"seat": int(entry.get("seat_id", 0)),
			"team_id": int(entry.get("team_id", entry.get("seat_id", 0))),
			"active": true,
			"is_cpu": false
		})
	return out

func _argument_paths(args: PackedStringArray) -> Dictionary:
	var input_path: String = ""
	var output_path: String = ""
	for i in range(args.size()):
		if args[i] == "--input" and i + 1 < args.size():
			input_path = args[i + 1]
		elif args[i] == "--output" and i + 1 < args.size():
			output_path = args[i + 1]
	return {"ok": not input_path.is_empty() and not output_path.is_empty(), "input": input_path, "output": output_path}

func _finish(output_path: String, result: Dictionary, exit_code: int) -> void:
	if not output_path.is_empty():
		var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result))
	quit(exit_code)
