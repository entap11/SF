extends SceneTree

const MapLoader := preload("res://scripts/maps/map_loader.gd")

const DT := 0.1
const TIMING_SCALE := 0.08

func _init() -> void:
	await process_frame
	var paths: Dictionary = _argument_paths(OS.get_cmdline_user_args())
	if not bool(paths.get("ok", false)):
		_finish(str(paths.get("output", "")), {"ok": false, "error": "arguments_invalid"}, 2)
		return
	var loaded: Dictionary = MapLoader.load_map(str(paths.get("map", "")))
	if not bool(loaded.get("ok", false)):
		_finish(str(paths.get("output", "")), {"ok": false, "error": loaded.get("err", "map_load_failed")}, 2)
		return
	var ops: Node = get_root().get_node_or_null("OpsState")
	if ops == null:
		_finish(str(paths.get("output", "")), {"ok": false, "error": "ops_state_missing"}, 2)
		return
	var state: GameState = ops.call("reset_state_from_map", loaded.get("data", {})) as GameState
	ops.set("match_roster", [
		{"seat": 1, "team_id": 1, "uid": "golden-seat-1", "is_cpu": true, "active": true},
		{"seat": 2, "team_id": 2, "uid": "golden-seat-2", "is_cpu": false, "active": true}
	])
	ops.set("match_phase", 1)
	ops.set("input_locked", false)
	ops.set("input_locked_reason", "")
	ops.set("match_clock_started", true)
	ops.set("match_clock_running", true)
	var builder: Node = load("res://scripts/ops/ops_state.gd").new()
	var profiles: Dictionary = {
		1: _profile(builder, 1, "raider", "medium")
	}
	builder.free()
	ops.set("bot_profiles", profiles)
	if ops.has_method("set_bot_match_seed"):
		ops.call("set_bot_match_seed", abs("authority-golden".hash()))
	var runner: Node = load("res://scripts/systems/sim_runner.gd").new()
	get_root().add_child(runner)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	runner.call("set_running", true, "match_authority_golden_generator")
	var intents: Array = []
	var max_ticks: int = int(paths.get("max_ticks", 12000))
	while int(state.tick) < max_ticks and int(ops.get("winner_id")) <= 0:
		runner.call("_tick", DT)
		var bot_system: Node = runner.get("bot_system") as Node
		if bot_system == null or not bot_system.has_method("get_last_outcomes"):
			continue
		var outcomes: Array[Dictionary] = bot_system.call("get_last_outcomes") as Array[Dictionary]
		for outcome in outcomes:
			if str(outcome.get("outcome", "")) != "act":
				continue
			var result: Dictionary = outcome.get("result", {}) as Dictionary
			if not bool(result.get("ok", false)):
				continue
			var action: Dictionary = outcome.get("action", {}) as Dictionary
			if str(action.get("kind", "")) == "retract_route":
				continue
			intents.append({
				"execute_tick": int(action.get("execute_tick", state.tick)),
				"seat_id": int(action.get("seat", 0)),
				"src": int(action.get("src_id", -1)),
				"dst": int(action.get("dst_id", -1)),
				"intent": str(action.get("route_intent", ""))
			})
	var winner: int = int(ops.get("winner_id"))
	if winner <= 0:
		_finish(str(paths.get("output", "")), {
			"ok": false, "error": "match_not_terminal", "ticks": int(state.tick), "intents": intents.size()
		}, 3)
		return
	_finish(str(paths.get("output", "")), {
		"map_id": str((loaded.get("data", {}) as Dictionary).get("id", "")),
		"source": "pinned authority replay raider:medium vs idle seat 2",
		"expected_winner_seat": winner,
		"intents": intents
	}, 0)

func _profile(builder: Node, seat: int, style: String, tier: String) -> Dictionary:
	var profile: Dictionary = builder.call("_build_bot_profile_for_seat", seat, style, tier) as Dictionary
	profile["team_by_seat"] = {1: 1, 2: 2}
	profile["decision_seed"] = abs(("authority-golden|%s|%s|%d" % [style, tier, seat]).hash()) % 1000000
	for key in ["opening_delay_ms", "think_interval_ms", "think_jitter_ms", "post_intent_delay_ms",
		"pair_intent_cooldown_ms", "global_intent_cooldown_ms", "swarm_cooldown_ms",
		"swarm_global_cooldown_ms", "retry_block_ms", "no_lane_retry_ms"]:
		profile[key] = maxi(1, int(round(float(maxi(0, int(profile.get(key, 0)))) * TIMING_SCALE)))
	return profile

func _argument_paths(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {"map": "", "output": "", "max_ticks": 12000}
	for index in range(args.size()):
		if args[index] == "--map" and index + 1 < args.size():
			result["map"] = args[index + 1]
		elif args[index] == "--output" and index + 1 < args.size():
			result["output"] = args[index + 1]
		elif args[index] == "--max-ticks" and index + 1 < args.size():
			result["max_ticks"] = maxi(1, int(args[index + 1]))
	result["ok"] = not str(result.get("map", "")).is_empty() and not str(result.get("output", "")).is_empty()
	return result

func _finish(path: String, result: Dictionary, code: int) -> void:
	if not path.is_empty():
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "  "))
	quit(code)
