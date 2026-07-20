extends SceneTree

const MapLoader := preload("res://scripts/maps/map_loader.gd")
const BaselineBotPolicy := preload("res://scripts/bot/baseline_bot_policy.gd")

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
		{"seat": 1, "team_id": 1, "uid": "golden-seat-1", "is_cpu": false, "active": true},
		{"seat": 2, "team_id": 2, "uid": "golden-seat-2", "is_cpu": false, "active": true}
	])
	ops.set("match_phase", 1)
	ops.set("match_clock_started", true)
	ops.set("match_clock_running", true)
	var builder: Node = load("res://scripts/ops/ops_state.gd").new()
	var profiles: Dictionary = {
		1: _profile(builder, 1, "raider", "medium")
	}
	builder.free()
	var policy: RefCounted = BaselineBotPolicy.new()
	var next_think: Dictionary = {1: 0}
	var cooldowns: Dictionary = {}
	var runner: Node = load("res://scripts/systems/sim_runner.gd").new()
	get_root().add_child(runner)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	runner.call("set_running", true, "match_authority_golden_generator")
	var intents: Array = []
	var max_ticks: int = int(paths.get("max_ticks", 12000))
	while int(state.tick) < max_ticks and int(ops.get("winner_id")) <= 0:
		var execute_tick: int = int(state.tick) + 1
		var sim_ms: int = int(state.tick) * 100
		for seat in [1]:
			if sim_ms < int(next_think.get(seat, 0)):
				continue
			var profile: Dictionary = profiles.get(seat, {}) as Dictionary
			profile["blocked_wall_pairs"] = ops.call("get_blocked_wall_pairs") if ops.has_method("get_blocked_wall_pairs") else []
			var decision_any: Variant = policy.call("choose_intent", state, seat, profile, sim_ms)
			next_think[seat] = sim_ms + _next_interval_ms(profile, state, seat)
			if typeof(decision_any) != TYPE_DICTIONARY:
				continue
			var decision: Dictionary = decision_any as Dictionary
			var src: int = int(decision.get("src", -1))
			var dst: int = int(decision.get("dst", -1))
			var intent: String = str(decision.get("intent", ""))
			if src <= 0 or dst <= 0 or intent.is_empty():
				continue
			var cooldown_key: String = "%d|%d|%d|%s" % [seat, src, dst, intent]
			if sim_ms < int(cooldowns.get(cooldown_key, 0)):
				continue
			var holder: Dictionary = {"result": {}}
			ops.call("with_remote_replication_apply", func() -> void:
				holder["result"] = ops.call("apply_lane_intent", src, dst, intent)
			)
			var result: Dictionary = holder.get("result", {}) as Dictionary
			if not bool(result.get("ok", false)):
				var retry_ms: int = int(profile.get("retry_block_ms", 500))
				if str(result.get("reason", "")) == "no_lane":
					retry_ms = int(profile.get("no_lane_retry_ms", retry_ms))
				cooldowns[cooldown_key] = sim_ms + retry_ms
				continue
			intents.append({
				"execute_tick": execute_tick,
				"seat_id": seat,
				"src": src,
				"dst": dst,
				"intent": intent
			})
			_apply_pair_cooldown(cooldowns, seat, src, dst,
				sim_ms + int(profile.get("pair_intent_cooldown_ms", 1000)))
			var global_until: int = sim_ms + int(profile.get("global_intent_cooldown_ms", 0))
			if global_until > int(next_think.get(seat, 0)):
				next_think[seat] = global_until
		runner.call("_tick", DT)
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

func _next_interval_ms(profile: Dictionary, state: GameState, seat: int) -> int:
	var base_ms: int = maxi(1, int(profile.get("think_interval_ms", 80)))
	var jitter_ms: int = maxi(0, int(profile.get("think_jitter_ms", 0)))
	if jitter_ms <= 0:
		return base_ms
	var hash_value: int = abs((int(state.tick) + 1) * 1103515245 + seat * 12345 + 97)
	return maxi(1, base_ms + int(hash_value % (jitter_ms * 2 + 1)) - jitter_ms)

func _apply_pair_cooldown(cooldowns: Dictionary, seat: int, src: int, dst: int, until_ms: int) -> void:
	for intent_name in ["attack", "feed", "swarm"]:
		cooldowns["%d|%d|%d|%s" % [seat, src, dst, intent_name]] = until_ms
		cooldowns["%d|%d|%d|%s" % [seat, dst, src, intent_name]] = until_ms

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
