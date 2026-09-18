extends SceneTree

const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
var _sim_runner_script: Script

const DEFAULT_STYLES: Array[String] = ["balancer", "turtle", "raider", "greedy", "swarm_lord"]
const DEFAULT_TIERS: Array[String] = ["medium"]
const DEFAULT_VARIANTS: Array[String] = ["1p", "2p", "4p"]
const DEFAULT_ITERATIONS: int = 1
const DEFAULT_DURATION_MS: int = 420000
const DEFAULT_DT: float = 0.1
const DEFAULT_TIMING_SCALE: float = 1.0
const MATCH_PHASE_RUNNING: int = 1
const MATCH_PHASE_ENDED: int = 3

var _iterations: int = DEFAULT_ITERATIONS
var _duration_ms: int = DEFAULT_DURATION_MS
var _dt: float = DEFAULT_DT
var _timing_scale: float = DEFAULT_TIMING_SCALE
var _max_maps: int = 0
var _max_pairs: int = 0
var _maps_per_variant: int = 0
var _include_mirrors: bool = false
var _styles: Array[String] = DEFAULT_STYLES.duplicate()
var _tiers: Array[String] = DEFAULT_TIERS.duplicate()
var _variants: Array[String] = DEFAULT_VARIANTS.duplicate()
var _map_ids: Array[String] = []
var _profiles: Array[Dictionary] = []
var _seed: int = 4101
var _output_path: String = ""
var _results: Array[Dictionary] = []
var _pilot_control: bool = false
var _focus_style: String = ""
var _report_samples: bool = false
var _ops_state: Node = null
var _ops_profile_builder: Node = null
var _overall: Dictionary = {}
var _pair_results: Dictionary = {}
var _map_results: Dictionary = {}
var _games_run: int = 0
var _games_skipped: int = 0

func _init() -> void:
	_parse_args(_script_args())
	if not is_equal_approx(_dt, DEFAULT_DT) or not is_equal_approx(_timing_scale, 1.0):
		push_error("BOT_TOURNAMENT: canonical evaluation requires --dt=0.1 and --timing-scale=1")
		quit(2)
		return
	await process_frame
	# Load after autoload registration; SimRunner uses the OpsState singleton.
	_sim_runner_script = load("res://scripts/systems/sim_runner.gd")
	_ops_state = root.get_node_or_null("OpsState")
	if _ops_state == null:
		push_error("BOT_TOURNAMENT: OpsState autoload missing")
		quit(1)
		return
	_ops_profile_builder = load("res://scripts/ops/ops_state.gd").new()
	_profiles = _build_profiles()
	var maps: Array[Dictionary] = _discover_maps()
	if maps.is_empty():
		push_error("BOT_TOURNAMENT: no maps matched variants=%s" % [",".join(_variants)])
		quit(1)
		return
	var pairings: Array[Dictionary] = _build_pairings()
	if pairings.is_empty():
		push_error("BOT_TOURNAMENT: no profile pairings")
		quit(1)
		return
	var planned_games: int = maps.size() * pairings.size() * _iterations
	print("BOT_TOURNAMENT: START profiles=%d pairings=%d maps=%d iterations=%d planned_games=%d variants=%s duration_ms=%d timing_scale=%.3f" % [
		_profiles.size(),
		pairings.size(),
		maps.size(),
		_iterations,
		planned_games,
		",".join(_variants),
		_duration_ms,
		_timing_scale
	])
	print("BOT_TOURNAMENT: MAP_MIX %s" % [_map_mix(maps)])
	print("BOT_TOURNAMENT: MAPS %s" % [_map_ids_for_log(maps)])
	var started_us: int = Time.get_ticks_usec()
	for map_row in maps:
		for pairing in pairings:
			for iteration in range(_iterations):
				var result: Dictionary = await _run_game(map_row, pairing, iteration)
				_results.append(result)
				_record_result(result)
				_print_game_diagnostic(result)
				if _games_run > 0 and _games_run % 100 == 0:
					print("BOT_TOURNAMENT: progress games=%d skipped=%d elapsed_s=%.1f" % [
						_games_run,
						_games_skipped,
						float(Time.get_ticks_usec() - started_us) / 1000000.0
					])
	var elapsed_s: float = float(Time.get_ticks_usec() - started_us) / 1000000.0
	_print_summary(elapsed_s)
	if not _output_path.is_empty():
		var file := FileAccess.open(_output_path, FileAccess.WRITE)
		if file == null:
			push_error("BOT_TOURNAMENT: cannot write " + _output_path)
			quit(2)
			return
		file.store_string(JSON.stringify({"schema_version": 2, "engine": Engine.get_version_info(), "seed": _seed, "canonical_tick_ms": 100, "results": _results}, "\t"))
		file.close()
	if _ops_profile_builder != null:
		_ops_profile_builder.free()
	quit(0)

func _script_args() -> Array:
	var args: Array = OS.get_cmdline_user_args()
	if not args.is_empty():
		return args
	return OS.get_cmdline_args()

func _parse_args(args: Array) -> void:
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--output="):
			_output_path = arg.trim_prefix("--output=")
		elif arg.begins_with("--iterations="):
			_iterations = maxi(1, int(arg.trim_prefix("--iterations=")))
		elif arg.begins_with("--duration-ms="):
			_duration_ms = maxi(1000, int(arg.trim_prefix("--duration-ms=")))
		elif arg.begins_with("--dt="):
			_dt = clampf(float(arg.trim_prefix("--dt=")), 0.02, 0.5)
		elif arg.begins_with("--timing-scale="):
			_timing_scale = clampf(float(arg.trim_prefix("--timing-scale=")), 0.001, 1.0)
		elif arg.begins_with("--max-maps="):
			_max_maps = maxi(0, int(arg.trim_prefix("--max-maps=")))
		elif arg.begins_with("--max-pairs="):
			_max_pairs = maxi(0, int(arg.trim_prefix("--max-pairs=")))
		elif arg.begins_with("--maps-per-variant="):
			_maps_per_variant = maxi(0, int(arg.trim_prefix("--maps-per-variant=")))
		elif arg.begins_with("--styles="):
			_styles = _csv(arg.trim_prefix("--styles="))
		elif arg.begins_with("--tiers="):
			_tiers = _csv(arg.trim_prefix("--tiers="))
		elif arg.begins_with("--variants="):
			_variants = _csv(arg.trim_prefix("--variants=").to_lower())
		elif arg.begins_with("--map-ids="):
			_map_ids = _csv(arg.trim_prefix("--map-ids="))
		elif arg == "--include-mirrors":
			_include_mirrors = true
		elif arg == "--pilot-control":
			_pilot_control = true
		elif arg == "--report-samples":
			_report_samples = true
		elif arg.begins_with("--focus-style="):
			_focus_style = arg.trim_prefix("--focus-style=")

func _csv(raw: String) -> Array[String]:
	var out: Array[String] = []
	for part in raw.split(",", false):
		var clean: String = str(part).strip_edges()
		if clean.is_empty():
			continue
		out.append(clean)
	return out

func _build_profiles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tier in _tiers:
		for style in _styles:
			var clean_style: String = style.strip_edges().to_lower()
			var clean_tier: String = tier.strip_edges().to_lower()
			out.append({
				"id": "%s:%s" % [clean_style, clean_tier],
				"style": clean_style,
				"tier": clean_tier
			})
	return out

func _build_pairings() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a_index in range(_profiles.size()):
		for b_index in range(_profiles.size()):
			if not _include_mirrors and b_index == a_index:
				continue
			var left: Dictionary = _profiles[a_index]
			var right: Dictionary = _profiles[b_index]
			if not _focus_style.is_empty() and str(left["style"]) != _focus_style and str(right["style"]) != _focus_style:
				continue
			out.append({"a": left, "b": right})
			if _max_pairs > 0 and out.size() >= _max_pairs:
				return out
	return out

func _discover_maps() -> Array[Dictionary]:
	var paths: Array[String] = _list_candidate_map_paths()
	var out: Array[Dictionary] = []
	var count_by_variant: Dictionary = {}
	for path in paths:
		var map_id: String = path.get_file().get_basename()
		if not _map_ids.is_empty() and not _map_ids.has(map_id):
			continue
		var variant: String = _variant_for_path(path)
		if not _variants.has(variant):
			continue
		if _maps_per_variant > 0 and int(count_by_variant.get(variant, 0)) >= _maps_per_variant:
			continue
		var loaded: Dictionary = MAP_LOADER.load_map(path)
		if not bool(loaded.get("ok", false)):
			continue
		var data: Dictionary = loaded.get("data", {}) as Dictionary
		var active_seats: Array[int] = _active_seats_for_map(data)
		if active_seats.size() < 2:
			continue
		out.append({
			"path": path,
			"id": map_id,
			"variant": variant,
			"data": data,
			"active_seats": active_seats
		})
		count_by_variant[variant] = int(count_by_variant.get(variant, 0)) + 1
		if _max_maps > 0 and out.size() >= _max_maps:
			break
	return out

func _list_candidate_map_paths() -> Array[String]:
	var out: Array[String] = []
	_collect_json_paths("res://maps", out)
	out.sort()
	return out

func _collect_json_paths(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if path.find("/_legacy") == -1 and path.find("/templates") == -1:
				_collect_json_paths(path, out)
			continue
		if name.to_lower().ends_with(".json"):
			out.append(path)
	dir.list_dir_end()

func _map_mix(maps: Array[Dictionary]) -> String:
	var counts: Dictionary = {}
	for map_row in maps:
		var variant: String = str(map_row.get("variant", ""))
		counts[variant] = int(counts.get(variant, 0)) + 1
	var parts: Array[String] = []
	for variant in _variants:
		parts.append("%s=%d" % [variant, int(counts.get(variant, 0))])
	return " ".join(parts)

func _map_ids_for_log(maps: Array[Dictionary]) -> String:
	var ids: Array[String] = []
	for map_row in maps:
		ids.append(str(map_row.get("id", "")))
	return ",".join(ids)

func _variant_for_path(path: String) -> String:
	var id: String = path.get_file().get_basename().to_lower()
	for variant in ["1p", "2p", "3p", "4p"]:
		if id.ends_with("__%s" % variant) or id.find("_%s_" % variant) >= 0 or id.find("%s_" % variant) >= 0:
			return variant
		if id.find("_%s" % variant) >= 0:
			return variant
	return ""

func _active_seats_for_map(data: Dictionary) -> Array[int]:
	var present: Dictionary = {}
	var hives_any: Variant = data.get("hives", [])
	if typeof(hives_any) == TYPE_ARRAY:
		for hive_any in hives_any as Array:
			if typeof(hive_any) != TYPE_DICTIONARY:
				continue
			var owner_id: int = int((hive_any as Dictionary).get("owner_id", 0))
			if owner_id >= 1 and owner_id <= 4:
				present[owner_id] = true
	var out: Array[int] = []
	for seat in [1, 2, 3, 4]:
		if present.has(seat):
			out.append(seat)
	return out

func _run_game(map_row: Dictionary, pairing: Dictionary, iteration: int) -> Dictionary:
	var data: Dictionary = (map_row.get("data", {}) as Dictionary).duplicate(true)
	data["bot_seed"] = _seed + iteration
	var state: GameState = _ops_state.call("reset_state_from_map", data)
	var active_seats: Array = map_row["active_seats"]
	var team_by_seat := _team_map_for_seats(active_seats)
	var profile_by_seat := _profile_map_for_seats(active_seats, pairing)
	_ops_state.set("match_roster", _roster_for_seats(active_seats, team_by_seat))
	_ops_state.call("set_team_mode_override", "2v2" if active_seats.size() >= 4 else "1p")
	for seat_any in active_seats:
		var seat := int(seat_any)
		_ops_state.call("set_bot_profile", seat, _profile_for_seat(seat, profile_by_seat[seat], team_by_seat))
	_ops_state.set("match_phase", MATCH_PHASE_RUNNING)
	_ops_state.set("input_locked", false)
	var runner: Node = _sim_runner_script.new()
	runner.set("autostart_on_bind", false)
	runner.set("scene_structure_binding_enabled", false)
	root.add_child(runner)
	runner.set_process(false)
	runner.call("bind_state", state)
	runner.call("enable_deterministic_clock", 0)
	var unit_system: UnitSystem = runner.get("unit_system")
	var diagnostics := _new_game_diagnostics(active_seats)
	var trace: Array[Dictionary] = []
	var bot: Node = runner.get("bot_system")
	if _pilot_control:
		bot.set("_human_policy", load("res://tools/fixtures/bot/human_balancer_v1.gd").new())
	var board_samples: Array[Dictionary] = []
	bot.connect("decision_event", func(event: Dictionary) -> void:
		trace.append(event.duplicate(true))
		if str(event.get("event", "")) == "applied":
			_record_bot_intent_diagnostic(diagnostics, int(event["seat"]), str(event.get("intent", "")), int(event["sim_ms"]), event)
	)
	for step in range(maxi(1, int(ceil(float(_duration_ms) / 100.0)))):
		if int(_ops_state.get("match_phase")) != MATCH_PHASE_RUNNING:
			break
		var hive_owners_before := _hive_owner_snapshot(state)
		var tower_owners_before := _structure_owner_snapshot(state.towers)
		runner.call("step_canonical")
		var sim_ms := int(state._sim_time_us / 1000)
		_update_unit_diagnostics(unit_system, diagnostics)
		_record_first_hive_capture(diagnostics, hive_owners_before, state, sim_ms)
		_record_first_tower_capture(diagnostics, tower_owners_before, state, sim_ms)
		if _report_samples and step % 50 == 0:
			board_samples.append(_board_sample(state, sim_ms))
		if step % 100 == 99:
			await process_frame
	var complete := int(_ops_state.get("match_phase")) != MATCH_PHASE_RUNNING
	var winner_team := int(_ops_state.get("winner_id")) if complete else 0
	var reason := str(_ops_state.get("match_end_reason")) if complete else "horizon_limit"
	var winner_profile := _winner_profile_id(winner_team, pairing)
	var sim_ms := int(state._sim_time_us / 1000)
	var result := {
		"ok": true, "completed": complete, "seed": _seed + iteration,
		"map_id": map_row["id"], "variant": map_row["variant"], "iteration": iteration,
		"a": pairing["a"]["id"], "b": pairing["b"]["id"],
		"profiles": _ops_state.call("get_bot_profiles_snapshot"),
		"winner_team": winner_team, "winner_profile": winner_profile,
		"reason": reason, "sim_ms": sim_ms,
		"state_hash": _ops_state.call("get_contract_state_hash"), "trace": trace,
		"runtime_hash": JSON.stringify(_ops_state.get("bot_runtime_by_seat")).sha256_text(),
		"pilot_controller": "v1_control" if _pilot_control else "current", "board_samples": board_samples,
		"map_hash": JSON.stringify(data).sha256_text(), "active_seats": active_seats, "team_by_seat": team_by_seat,
		"scores": _score_snapshot(state, team_by_seat),
		"diagnostics": _finalize_game_diagnostics(diagnostics, state, unit_system, winner_profile, reason, sim_ms)
	}
	state.unit_system = null
	runner.free()
	await process_frame
	return result

func _board_sample(state: GameState, sim_ms: int) -> Dictionary:
	var hives: Array[Dictionary] = []
	for hive in state.hives:
		hives.append({"id": int(hive.id), "owner": int(hive.owner_id), "power": int(hive.power),
			"outgoing": state.count_active_outgoing(int(hive.id)), "budget": state.lanes_allowed_for_power(int(hive.power))})
	return {"sim_ms": sim_ms, "hives": hives}

func _team_map_for_seats(active_seats: Array) -> Dictionary:
	var out: Dictionary = {}
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		if active_seats.size() >= 4:
			out[seat] = 1 if seat == 1 or seat == 3 else 2
		else:
			out[seat] = 1 if seat == 1 else 2
	return out

func _profile_map_for_seats(active_seats: Array, pairing: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var a_profile: Dictionary = pairing.get("a", {}) as Dictionary
	var b_profile: Dictionary = pairing.get("b", {}) as Dictionary
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		out[seat] = a_profile if seat == 1 or (active_seats.size() >= 4 and seat == 3) else b_profile
	return out

func _roster_for_seats(active_seats: Array, team_by_seat: Dictionary) -> Array:
	var roster: Array = []
	for seat in [1, 2, 3, 4]:
		roster.append({
			"seat": seat,
			"team_id": int(team_by_seat.get(seat, seat)),
			"uid": "bot_%d" % seat,
			"is_local": false,
			"is_cpu": active_seats.has(seat),
			"active": active_seats.has(seat)
		})
	return roster

func _profile_for_seat(seat: int, row: Dictionary, team_by_seat: Dictionary) -> Dictionary:
	var profile: Dictionary = _ops_profile_builder.call("_build_bot_profile_for_seat", seat, str(row.get("style", "balancer")), str(row.get("tier", "medium")))
	profile["human_behavior_enabled"] = true
	profile["team_by_seat"] = team_by_seat.duplicate(true)
	return profile

func _new_game_diagnostics(active_seats: Array) -> Dictionary:
	var last_state_by_seat: Dictionary = {}
	var transitions_by_seat: Dictionary = {}
	var intent_counts_by_seat: Dictionary = {}
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		last_state_by_seat[seat] = "idle"
		transitions_by_seat[seat] = []
		intent_counts_by_seat[seat] = {"attack": 0, "feed": 0, "swarm": 0}
	return {
		"first_attack_ms": -1,
		"first_attack": {},
		"first_capture_ms": -1,
		"first_capture": {},
		"first_tower_capture_ms": -1,
		"first_tower_capture": {},
		"last_state_by_seat": last_state_by_seat,
		"bot_transitions_by_seat": transitions_by_seat,
		"intent_counts_by_seat": intent_counts_by_seat,
		"seen_unit_ids": {},
		"units_produced_by_player": {}
	}

func _record_bot_intent_diagnostic(diagnostics: Dictionary, seat: int, intent: String, sim_ms: int, decision: Dictionary) -> void:
	var intent_counts_by_seat: Dictionary = diagnostics.get("intent_counts_by_seat", {}) as Dictionary
	var seat_counts: Dictionary = intent_counts_by_seat.get(seat, {"attack": 0, "feed": 0, "swarm": 0}) as Dictionary
	seat_counts[intent] = int(seat_counts.get(intent, 0)) + 1
	intent_counts_by_seat[seat] = seat_counts
	diagnostics["intent_counts_by_seat"] = intent_counts_by_seat
	if intent == "attack" and int(diagnostics.get("first_attack_ms", -1)) < 0:
		diagnostics["first_attack_ms"] = sim_ms
		diagnostics["first_attack"] = {
			"seat": seat,
			"src": int(decision.get("src", 0)),
			"dst": int(decision.get("dst", 0)),
			"score": snapped(float(decision.get("score", 0.0)), 0.01)
		}
	var last_state_by_seat: Dictionary = diagnostics.get("last_state_by_seat", {}) as Dictionary
	var prev_state: String = str(last_state_by_seat.get(seat, "idle"))
	if prev_state == intent:
		return
	last_state_by_seat[seat] = intent
	diagnostics["last_state_by_seat"] = last_state_by_seat
	var transitions_by_seat: Dictionary = diagnostics.get("bot_transitions_by_seat", {}) as Dictionary
	var rows: Array = transitions_by_seat.get(seat, []) as Array
	rows.append({
		"ms": sim_ms,
		"from": prev_state,
		"to": intent,
		"src": int(decision.get("src", 0)),
		"dst": int(decision.get("dst", 0)),
		"score": snapped(float(decision.get("score", 0.0)), 0.01)
	})
	transitions_by_seat[seat] = rows
	diagnostics["bot_transitions_by_seat"] = transitions_by_seat

func _hive_owner_snapshot(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		out[int(hive.id)] = int(hive.owner_id)
	return out

func _structure_owner_snapshot(structures: Array) -> Dictionary:
	var out: Dictionary = {}
	for structure_any in structures:
		if typeof(structure_any) != TYPE_DICTIONARY:
			continue
		var structure: Dictionary = structure_any as Dictionary
		out[int(structure.get("id", 0))] = int(structure.get("owner_id", 0))
	return out

func _record_first_hive_capture(diagnostics: Dictionary, owners_before: Dictionary, state: GameState, sim_ms: int) -> void:
	if int(diagnostics.get("first_capture_ms", -1)) >= 0 or state == null:
		return
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		var hive_id: int = int(hive.id)
		var prev_owner: int = int(owners_before.get(hive_id, int(hive.owner_id)))
		var next_owner: int = int(hive.owner_id)
		if next_owner <= 0 or next_owner == prev_owner:
			continue
		diagnostics["first_capture_ms"] = sim_ms
		diagnostics["first_capture"] = {
			"hive_id": hive_id,
			"prev_owner": prev_owner,
			"next_owner": next_owner,
			"power": int(hive.power)
		}
		return

func _record_first_tower_capture(diagnostics: Dictionary, owners_before: Dictionary, state: GameState, sim_ms: int) -> void:
	if int(diagnostics.get("first_tower_capture_ms", -1)) >= 0 or state == null:
		return
	for tower_any in state.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		var tower_id: int = int(tower.get("id", 0))
		var prev_owner: int = int(owners_before.get(tower_id, int(tower.get("owner_id", 0))))
		var next_owner: int = int(tower.get("owner_id", 0))
		if next_owner <= 0 or next_owner == prev_owner:
			continue
		diagnostics["first_tower_capture_ms"] = sim_ms
		diagnostics["first_tower_capture"] = {
			"tower_id": tower_id,
			"prev_owner": prev_owner,
			"next_owner": next_owner
		}
		return

func _update_unit_diagnostics(unit_system: UnitSystem, diagnostics: Dictionary) -> void:
	if unit_system == null:
		return
	var seen: Dictionary = diagnostics.get("seen_unit_ids", {}) as Dictionary
	var produced_by_player: Dictionary = diagnostics.get("units_produced_by_player", {}) as Dictionary
	for unit_any in unit_system.units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		var unit_id: int = int(unit.get("id", unit.get("uid", 0)))
		if unit_id <= 0 or seen.has(unit_id):
			continue
		seen[unit_id] = true
		var owner_id: int = int(unit.get("owner_id", 0))
		if owner_id > 0:
			produced_by_player[owner_id] = int(produced_by_player.get(owner_id, 0)) + int(unit.get("amount", 1))
	diagnostics["seen_unit_ids"] = seen
	diagnostics["units_produced_by_player"] = produced_by_player

func _finalize_game_diagnostics(
		diagnostics: Dictionary,
		state: GameState,
		unit_system: UnitSystem,
		winner_profile: String,
		reason: String,
		sim_ms: int
	) -> Dictionary:
	var out: Dictionary = diagnostics.duplicate(true)
	out.erase("seen_unit_ids")
	out["winner"] = winner_profile
	out["win_time_ms"] = sim_ms if reason == "conquest" else -1
	out["evaluation_incomplete"] = reason == "horizon_limit"
	out["timeout_or_draw"] = reason == "time" or (winner_profile.is_empty() and reason != "horizon_limit")
	out["end_reason"] = reason
	out["final_node_ownership"] = _final_node_ownership(state)
	out["final_active_units_by_player"] = _active_units_by_player(unit_system)
	return out

func _final_node_ownership(state: GameState) -> Dictionary:
	var out: Dictionary = {"hives": {}, "towers": {}, "barracks": {}}
	if state == null:
		return out
	var hives: Dictionary = {}
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		hives[int(hive.id)] = int(hive.owner_id)
	out["hives"] = hives
	out["towers"] = _structure_owner_snapshot(state.towers)
	out["barracks"] = _structure_owner_snapshot(state.barracks)
	return out

func _active_units_by_player(unit_system: UnitSystem) -> Dictionary:
	var out: Dictionary = {}
	if unit_system == null:
		return out
	for unit_any in unit_system.units:
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		var owner_id: int = int(unit.get("owner_id", 0))
		if owner_id <= 0:
			continue
		out[owner_id] = int(out.get(owner_id, 0)) + int(unit.get("amount", 1))
	return out

func _score_snapshot(state: GameState, team_by_seat: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if state == null:
		return out
	for team_any in team_by_seat.values():
		var team_id: int = int(team_any)
		if team_id > 0:
			out[team_id] = {"hives": 0, "power": 0, "enemy_landed": 0, "friendly_fed": 0}
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		var owner_id: int = int(hive.owner_id)
		if owner_id <= 0:
			continue
		var team: int = int(team_by_seat.get(owner_id, owner_id))
		var score: Dictionary = out.get(team, {"hives": 0, "power": 0, "enemy_landed": 0, "friendly_fed": 0}) as Dictionary
		score["hives"] = int(score.get("hives", 0)) + 1
		score["power"] = int(score.get("power", 0)) + int(hive.power)
		out[team] = score
	var stats_by_team: Dictionary = _ops_state.get("stats_by_team") as Dictionary
	for team_any in stats_by_team.keys():
		var team_id: int = int(team_any)
		var score: Dictionary = out.get(team_id, {"hives": 0, "power": 0, "enemy_landed": 0, "friendly_fed": 0}) as Dictionary
		var stats: Dictionary = stats_by_team.get(team_id, {}) as Dictionary
		score["enemy_landed"] = int(stats.get("units_landed_enemy", 0))
		score["friendly_fed"] = int(stats.get("units_fed_friendly", 0))
		out[team_id] = score
	return out

func _winner_profile_id(winner_team: int, pairing: Dictionary) -> String:
	if winner_team == 1:
		return str((pairing.get("a", {}) as Dictionary).get("id", ""))
	if winner_team == 2:
		return str((pairing.get("b", {}) as Dictionary).get("id", ""))
	return ""

func _record_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)) or not bool(result.get("completed", false)):
		_games_skipped += 1
		return
	_games_run += 1
	var a_id: String = str(result.get("a", ""))
	var b_id: String = str(result.get("b", ""))
	var winner_profile: String = str(result.get("winner_profile", ""))
	_ensure_profile_stats(a_id)
	_ensure_profile_stats(b_id)
	_record_profile_game(a_id, winner_profile == a_id, winner_profile == "")
	_record_profile_game(b_id, winner_profile == b_id, winner_profile == "")
	var pair_key: String = "%s vs %s" % [a_id, b_id]
	var pair: Dictionary = _pair_results.get(pair_key, {"games": 0, "a_wins": 0, "b_wins": 0, "draws": 0}) as Dictionary
	pair["games"] = int(pair.get("games", 0)) + 1
	if winner_profile == a_id:
		pair["a_wins"] = int(pair.get("a_wins", 0)) + 1
	elif winner_profile == b_id:
		pair["b_wins"] = int(pair.get("b_wins", 0)) + 1
	else:
		pair["draws"] = int(pair.get("draws", 0)) + 1
	_pair_results[pair_key] = pair
	var map_id: String = str(result.get("map_id", ""))
	var map_stat: Dictionary = _map_results.get(map_id, {"games": 0, "draws": 0}) as Dictionary
	map_stat["games"] = int(map_stat.get("games", 0)) + 1
	if winner_profile == "":
		map_stat["draws"] = int(map_stat.get("draws", 0)) + 1
	_map_results[map_id] = map_stat

func _print_game_diagnostic(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		return
	var row: Dictionary = {
		"map_id": str(result.get("map_id", "")),
		"variant": str(result.get("variant", "")),
		"iteration": int(result.get("iteration", 0)),
		"completed": bool(result.get("completed", false)),
		"a": str(result.get("a", "")),
		"b": str(result.get("b", "")),
		"winner": str(result.get("winner_profile", "")),
		"reason": str(result.get("reason", "")),
		"sim_ms": int(result.get("sim_ms", 0)),
		"scores": result.get("scores", {}),
		"diagnostics": result.get("diagnostics", {})
	}
	print("BOT_TOURNAMENT: GAME %s" % [JSON.stringify(row)])

func _ensure_profile_stats(profile_id: String) -> void:
	if _overall.has(profile_id):
		return
	_overall[profile_id] = {"games": 0, "wins": 0, "losses": 0, "draws": 0}

func _record_profile_game(profile_id: String, won: bool, draw: bool) -> void:
	var row: Dictionary = _overall.get(profile_id, {}) as Dictionary
	row["games"] = int(row.get("games", 0)) + 1
	if draw:
		row["draws"] = int(row.get("draws", 0)) + 1
	elif won:
		row["wins"] = int(row.get("wins", 0)) + 1
	else:
		row["losses"] = int(row.get("losses", 0)) + 1
	_overall[profile_id] = row

func _print_summary(elapsed_s: float) -> void:
	var ranked: Array[Dictionary] = []
	for profile_id_any in _overall.keys():
		var profile_id: String = str(profile_id_any)
		var row: Dictionary = _overall.get(profile_id, {}) as Dictionary
		var games: int = maxi(1, int(row.get("games", 0)))
		var wins: int = int(row.get("wins", 0))
		var draws: int = int(row.get("draws", 0))
		var score: float = (float(wins) + (float(draws) * 0.5)) / float(games)
		ranked.append({
			"profile": profile_id,
			"games": games,
			"wins": wins,
			"losses": int(row.get("losses", 0)),
			"draws": draws,
			"score": score
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.get("score", 0.0)), float(b.get("score", 0.0))):
			return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
		return int(a.get("wins", 0)) > int(b.get("wins", 0))
	)
	print("BOT_TOURNAMENT: COMPLETE games=%d skipped=%d elapsed_s=%.2f" % [_games_run, _games_skipped, elapsed_s])
	print("BOT_TOURNAMENT: RANK profile,games,wins,losses,draws,score")
	for row in ranked:
		print("BOT_TOURNAMENT: RANK %s,%d,%d,%d,%d,%.4f" % [
			str(row.get("profile", "")),
			int(row.get("games", 0)),
			int(row.get("wins", 0)),
			int(row.get("losses", 0)),
			int(row.get("draws", 0)),
			float(row.get("score", 0.0))
		])
	print("BOT_TOURNAMENT: TOP_PAIR profile_a,profile_b,games,a_wins,b_wins,draws")
	var pair_keys: Array = _pair_results.keys()
	pair_keys.sort()
	for i in range(mini(20, pair_keys.size())):
		var key: String = str(pair_keys[i])
		var pair: Dictionary = _pair_results.get(key, {}) as Dictionary
		var parts: PackedStringArray = key.split(" vs ", false)
		var a: String = parts[0] if parts.size() > 0 else key
		var b: String = parts[1] if parts.size() > 1 else ""
		print("BOT_TOURNAMENT: TOP_PAIR %s,%s,%d,%d,%d,%d" % [
			a,
			b,
			int(pair.get("games", 0)),
			int(pair.get("a_wins", 0)),
			int(pair.get("b_wins", 0)),
			int(pair.get("draws", 0))
		])
