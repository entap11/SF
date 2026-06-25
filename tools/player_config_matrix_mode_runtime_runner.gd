extends SceneTree

const Manifest := preload("res://tools/player_config_matrix_manifest.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const ContestStateScript := preload("res://scripts/state/contest_state.gd")
const StageRuntimeFlowScript := preload("res://scripts/arena_helpers/stage_runtime_flow.gd")

var _config_id := ""
var _seed := 0
var _row: Dictionary = {}
var _failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	await process_frame
	_row = Manifest.row_by_id(_config_id)
	_expect(not _row.is_empty(), "manifest config not found", {"config_id": _config_id})
	_expect(str(_row.get("expected_contract", "")) == Manifest.EXPECT_VALID, "mode runtime requires a valid manifest row", {
		"config_id": _config_id,
		"expected_contract": str(_row.get("expected_contract", ""))
	})
	var rules_mode: String = str(_row.get("rules_mode", ""))
	_expect(Manifest.rules_modes().has(rules_mode), "unsupported mode runtime rules_mode", {
		"config_id": _config_id,
		"rules_mode": rules_mode
	})
	if _failed:
		quit(1)
		return

	match rules_mode:
		Manifest.RULE_STAGE_RACE:
			_run_stage_race()
		Manifest.RULE_TIMED_RACE:
			_run_timed_race()
		Manifest.RULE_MISS_N_OUT:
			_run_miss_n_out()
		Manifest.RULE_CAPTURE_FLAG:
			_run_visible_capture_flag()
		Manifest.RULE_HIDDEN_CAPTURE_FLAG:
			_run_hidden_capture_flag()
	if not _failed:
		print("PLAYER_CONFIG_MATRIX_MODE_RUNTIME: PASS config=%s seed=%d" % [_config_id, _seed])
	quit(1 if _failed else 0)

func _parse_args() -> void:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg.begins_with("--matrix-config="):
			_config_id = arg.trim_prefix("--matrix-config=").strip_edges()
		elif arg.begins_with("--config="):
			_config_id = arg.trim_prefix("--config=").strip_edges()
		elif arg.begins_with("--matrix-seed="):
			_seed = int(arg.trim_prefix("--matrix-seed="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))

func _run_visible_capture_flag() -> void:
	_assert_map_contract_for_mode(false)
	var ops: Node = _ops_state()
	if ops == null:
		return
	var state: GameState = _new_two_owner_ctf_state()
	ops.state = state
	ops.reset_match_state()
	ops.state = state
	ops.match_phase = ops.MatchPhase.RUNNING
	var result: Dictionary = ops.call("configure_capture_flag_mode", _runtime_options(false)) as Dictionary
	var rules: Dictionary = result.get("rules", {}) as Dictionary
	_expect(str(result.get("victory_mode", "")) == "capture_flag", "visible CTF did not enter capture_flag victory mode", result)
	_expect(not bool(rules.get("hidden_flag", true)), "visible CTF should not be hidden", rules)
	_resolve_pending_selection_if_needed(ops, 1, 1)
	_assert_visible_flags(ops)
	_assert_flag_capture_result(ops, state)

func _run_stage_race() -> void:
	_assert_map_loads()
	var contest_state: Node = _new_contest_state("stage")
	if contest_state == null:
		return
	var contest_id: String = "MATRIX_USD_0_2026W26_STAGE_%s" % _safe_config_id()
	var map_ids: PackedStringArray = _stage_map_ids(3)
	contest_id = _install_contest(contest_state, contest_id, Manifest.RULE_STAGE_RACE, map_ids)
	var plan: Dictionary = contest_state.call("build_stage_race_plan", contest_id, 3) as Dictionary
	_expect(bool(plan.get("ok", false)), "stage race plan failed", plan)
	_expect(str(plan.get("mode", "")) == Manifest.RULE_STAGE_RACE, "stage race plan mode mismatch", plan)
	_expect(int(plan.get("map_count", 0)) == 3, "stage race plan map count mismatch", plan)
	var stage_flow: RefCounted = StageRuntimeFlowScript.new()
	set_meta("vs_mode", Manifest.RULE_STAGE_RACE)
	set_meta("vs_stage_map_paths", [str(map_ids[0]), str(map_ids[1]), str(map_ids[2])])
	set_meta("vs_stage_current_index", 0)
	set_meta("vs_stage_round_results", [])
	var first_result: Dictionary = {
		"round_index": 0,
		"round_number": 1,
		"map_path": str(map_ids[0]),
		"winner_id": 1,
		"reason": "stage_race_runtime_smoke",
		"elapsed_ms": 41000,
		"local_owner_id": 1,
		"opponent_owner_id": 2,
		"local_owned_hives": 3,
		"opponent_owned_hives": 1
	}
	var results: Array = stage_flow.call("upsert_stage_round_result", [], 0, first_result) as Array
	stage_flow.call("set_stage_round_results_runtime", self, "vs_stage_round_results", results)
	_expect((get_meta("vs_stage_round_results", []) as Array).size() == 1, "stage race round result did not record", {
		"results": get_meta("vs_stage_round_results", [])
	})
	set_meta("vs_stage_current_index", int(get_meta("vs_stage_current_index", 0)) + 1)
	_expect(int(get_meta("vs_stage_current_index", -1)) == 1, "stage race index did not advance", {
		"stage_index": int(get_meta("vs_stage_current_index", -1))
	})
	var record_a: Dictionary = contest_state.call("record_stage_race_map_result", contest_id, str(map_ids[0]), {
		"player_id": "stage_p1",
		"player_name": "Stage One",
		"run_id": "stage_run_1",
		"time_ms": 41000,
		"stage_index": 0,
		"source": "player_config_matrix"
	}) as Dictionary
	var record_b: Dictionary = contest_state.call("record_stage_race_map_result", contest_id, str(map_ids[1]), {
		"player_id": "stage_p1",
		"player_name": "Stage One",
		"run_id": "stage_run_1",
		"time_ms": 39000,
		"stage_index": 1,
		"source": "player_config_matrix"
	}) as Dictionary
	_expect(bool(record_a.get("ok", false)), "stage race map result A failed", record_a)
	_expect(bool(record_b.get("ok", false)), "stage race map result B failed", record_b)
	var overall: Array[Dictionary] = contest_state.call("build_stage_race_overall_leaderboard", contest_id, 3, 10) as Array[Dictionary]
	_expect(not overall.is_empty(), "stage race overall leaderboard missing", {"contest_id": contest_id})
	if not overall.is_empty():
		var lead: Dictionary = overall[0]
		_expect(int(lead.get("completed_maps", 0)) == 2, "stage race completed map count mismatch", lead)
		_expect(int(lead.get("aggregate_time_ms", 0)) == 80000, "stage race aggregate time mismatch", lead)
	contest_state.queue_free()

func _run_timed_race() -> void:
	_assert_map_loads()
	var ops: Node = _ops_state()
	if ops != null:
		var state: GameState = _new_two_owner_ctf_state()
		ops.state = state
		ops.reset_match_state()
		ops.state = state
		ops.match_phase = ops.MatchPhase.RUNNING
		ops.call("tick_match_clock", state, 0)
		var duration_ms: int = int(ops.get("match_duration_ms"))
		_expect(bool(ops.get("match_clock_started")), "timed race clock did not start", {
			"duration_ms": duration_ms,
			"remaining_ms": int(ops.get("match_remaining_ms"))
		})
		ops.call("tick_match_clock", state, 1000)
		_expect(int(ops.get("match_remaining_ms")) < duration_ms, "timed race clock did not decrement", {
			"duration_ms": duration_ms,
			"remaining_ms": int(ops.get("match_remaining_ms"))
		})
		ops.call("tick_match_clock", state, duration_ms)
		_expect(int(ops.get("match_remaining_ms")) == 0, "timed race clock did not reach zero", {
			"duration_ms": duration_ms,
			"remaining_ms": int(ops.get("match_remaining_ms")),
			"elapsed_ms": int(ops.get("match_elapsed_ms"))
		})
	var contest_state: Node = _new_contest_state("timed")
	if contest_state == null:
		return
	var contest_id: String = "MATRIX_USD_0_2026W26_TIMED_%s" % _safe_config_id()
	var map_ids: PackedStringArray = _stage_map_ids(3)
	contest_id = _install_contest(contest_state, contest_id, Manifest.RULE_TIMED_RACE, map_ids)
	var plan: Dictionary = contest_state.call("build_timed_race_plan", contest_id, 3) as Dictionary
	_expect(bool(plan.get("ok", false)), "timed race plan failed", plan)
	_expect(int(plan.get("start_countdown_sec", 0)) > 0, "timed race countdown missing", plan)
	var evaluated: Dictionary = contest_state.call("evaluate_timed_race", [
		{"player_id": "race_p1", "player_name": "Ada", "map_times_ms": [61000, 63000, 64000]},
		{"player_id": "race_p2", "player_name": "Bo", "map_times_ms": [59000, 60000, 61000]},
		{"player_id": "race_p3", "player_name": "Cy", "map_times_ms": [62000, 62000, 62000]},
		{"player_id": "race_p4", "player_name": "Dee", "map_times_ms": [58000, 59000]}
	], 3) as Dictionary
	_expect(bool(evaluated.get("ok", false)), "timed race evaluation failed", evaluated)
	_expect(str((evaluated.get("winner", {}) as Dictionary).get("player_id", "")) == "race_p2", "timed race winner mismatch", evaluated)
	_expect(str(evaluated.get("winner_reason", "")) == "first_to_finish", "timed race winner reason mismatch", evaluated)
	_record_timed(contest_state, contest_id, "race_p1", "Ada", "run_1", [61000, 63000, 64000])
	_record_timed(contest_state, contest_id, "race_p2", "Bo", "run_2", [59000, 60000, 61000])
	var leaderboard: Array[Dictionary] = contest_state.call("build_timed_race_leaderboard", contest_id, 10) as Array[Dictionary]
	_expect(leaderboard.size() >= 2, "timed race leaderboard missing rows", {"leaderboard": leaderboard})
	if leaderboard.size() >= 2:
		_expect(str(leaderboard[0].get("player_id", "")) == "race_p2", "timed race leaderboard first place mismatch", leaderboard[0])
		_expect(bool(leaderboard[0].get("completed_all", false)), "timed race completed_all missing", leaderboard[0])
	contest_state.queue_free()

func _run_miss_n_out() -> void:
	_assert_map_loads()
	var contest_state: Node = _new_contest_state("miss")
	if contest_state == null:
		return
	var contest_id: String = "MATRIX_USD_0_2026W26_MISS_%s" % _safe_config_id()
	var map_ids: PackedStringArray = _stage_map_ids(3)
	contest_id = _install_contest(contest_state, contest_id, Manifest.RULE_MISS_N_OUT, map_ids)
	var plan: Dictionary = contest_state.call("build_miss_n_out_plan", contest_id, 4) as Dictionary
	_expect(bool(plan.get("ok", false)), "miss n out plan failed", plan)
	_expect(int(plan.get("map_count", 0)) == 3, "miss n out map count should be players minus one", plan)
	var result: Dictionary = contest_state.call("evaluate_miss_n_out", [
		{"player_id": "miss_p1", "player_name": "Ada", "map_times_ms": [10000, 10000, 10000]},
		{"player_id": "miss_p2", "player_name": "Bo", "map_times_ms": [9000, 9000, 9000]},
		{"player_id": "miss_p3", "player_name": "Cy", "map_times_ms": [12000, 12000, 12000]},
		{"player_id": "miss_p4", "player_name": "Dee", "map_times_ms": [11000, 11000, 11000]}
	], 4, []) as Dictionary
	_expect(bool(result.get("ok", false)), "miss n out evaluation failed", result)
	var eliminated_order: Array = result.get("eliminated_order", []) as Array
	_expect(eliminated_order.size() == 3, "miss n out eliminated order mismatch", result)
	if eliminated_order.size() >= 1:
		_expect(str((eliminated_order[0] as Dictionary).get("player_id", "")) == "miss_p3", "miss n out first elimination mismatch", eliminated_order[0])
	_expect(str((result.get("winner", {}) as Dictionary).get("player_id", "")) == "miss_p2", "miss n out winner mismatch", result)
	var player_states: Dictionary = result.get("player_states", {}) as Dictionary
	var p1_state: Dictionary = player_states.get("miss_p1", {}) as Dictionary
	_expect(bool(p1_state.get("eliminated", false)), "miss n out player state did not mark eliminated player", p1_state)
	var record_result: Dictionary = contest_state.call("record_miss_n_out_result", contest_id, result) as Dictionary
	_expect(bool(record_result.get("ok", false)), "miss n out record failed", record_result)
	var leaderboard: Array[Dictionary] = contest_state.call("build_miss_n_out_leaderboard", contest_id, 10) as Array[Dictionary]
	_expect(leaderboard.size() == 4, "miss n out leaderboard row count mismatch", {"leaderboard": leaderboard})
	if not leaderboard.is_empty():
		_expect(str(leaderboard[0].get("player_id", "")) == "miss_p2", "miss n out leaderboard winner mismatch", leaderboard[0])
	contest_state.queue_free()

func _run_hidden_capture_flag() -> void:
	_assert_map_contract_for_mode(true)
	var ops: Node = _ops_state()
	if ops == null:
		return
	var state: GameState = _new_two_owner_ctf_state()
	ops.state = state
	ops.reset_match_state()
	ops.state = state
	ops.match_phase = ops.MatchPhase.PREMATCH
	var result: Dictionary = ops.call("configure_capture_flag_mode", _runtime_options(true)) as Dictionary
	var rules: Dictionary = result.get("rules", {}) as Dictionary
	_expect(str(result.get("victory_mode", "")) == "capture_flag", "hidden CTF did not enter capture_flag victory mode", result)
	_expect(bool(rules.get("hidden_flag", false)), "hidden CTF rules should mark flags hidden", rules)
	_expect(str(rules.get("flag_selection_mode", "")) == "player_select", "hidden CTF should force player_select", rules)
	_expect(int(rules.get("flag_selection_player_select_pct", 0)) == 100, "hidden CTF should force 100% player select", rules)
	_expect(bool(rules.get("flag_move_reveals", false)), "hidden CTF should reveal moved flag", rules)
	_expect(int(rules.get("flag_move_count_max", -1)) == int((_row.get("ctf_options", {}) as Dictionary).get("flag_move_count_max", -1)), "hidden CTF move budget mismatch", rules)
	_expect(bool(rules.get("flag_selection_pending", false)), "hidden CTF should start pending player selection", rules)
	var select_result: Dictionary = ops.call("request_capture_flag_selection", 1, 2) as Dictionary
	_expect(bool(select_result.get("ok", false)), "hidden CTF player flag selection failed", select_result)
	_assert_hidden_visibility(ops)
	ops.match_phase = ops.MatchPhase.RUNNING
	var move_result: Dictionary = ops.call("request_capture_flag_move", 1, 1) as Dictionary
	_expect(bool(move_result.get("ok", false)), "hidden CTF flag move failed", move_result)
	var moved_flag: Dictionary = ops.call("get_capture_flag_for_owner", 1) as Dictionary
	_expect(int(moved_flag.get("hive_id", 0)) == 1, "hidden CTF moved flag landed on wrong hive", moved_flag)
	_expect(bool(moved_flag.get("revealed_to_all", false)), "hidden CTF moved flag did not reveal", moved_flag)
	_expect(int(moved_flag.get("moves_remaining", -1)) == 0, "hidden CTF move budget did not decrement", moved_flag)
	_assert_flag_capture_result(ops, state)

func _runtime_options(hidden: bool) -> Dictionary:
	var ctf_options: Dictionary = _row.get("ctf_options", {}) as Dictionary
	return {
		"hidden_flag": hidden,
		"flag_selection_seed": _seed,
		"flag_selection_mode": "player_select" if hidden else str(ctf_options.get("flag_selection_mode", "weighted")),
		"flag_selection_player_select_pct": 100 if hidden else int(ctf_options.get("player_select_pct", 35)),
		"flag_selection_random_mirrored": bool(ctf_options.get("randomize_flag_hive", true)),
		"flag_selection_owner_id": 1,
		"flag_move_count_max": int(ctf_options.get("flag_move_count_max", 0)),
		"flag_move_reveals": true if hidden else bool(ctf_options.get("flag_move_reveals", true))
	}

func _assert_map_contract_for_mode(hidden: bool) -> void:
	_assert_map_loads()
	if _failed:
		return
	var map_path: String = str(_row.get("resolved_map_path", ""))
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	if hidden:
		var split: Dictionary = MapModeRules.hidden_capture_flag_split_summary(data)
		_expect(bool(split.get("ok", false)), "hidden CTF map split rejected", {"map": map_path, "split": split})

func _assert_map_loads() -> void:
	var map_path: String = str(_row.get("resolved_map_path", ""))
	var loaded: Dictionary = MAP_LOADER.load_map(map_path)
	_expect(bool(loaded.get("ok", false)), "mode runtime map failed to load", {"map": map_path, "loaded": loaded})

func _resolve_pending_selection_if_needed(ops: Node, owner_id: int, hive_id: int) -> void:
	if not bool(ops.call("is_capture_flag_selection_pending", owner_id)):
		return
	var result: Dictionary = ops.call("request_capture_flag_selection", owner_id, hive_id) as Dictionary
	_expect(bool(result.get("ok", false)), "visible CTF pending player selection failed", result)

func _assert_visible_flags(ops: Node) -> void:
	var flags_state: Dictionary = ops.call("get_capture_flag_state") as Dictionary
	var flags: Dictionary = flags_state.get("flags_by_owner", {}) as Dictionary
	for owner_id in [1, 2]:
		var flag: Dictionary = flags.get(owner_id, {}) as Dictionary
		_expect(int(flag.get("hive_id", 0)) > 0, "visible CTF flag missing", {"owner_id": owner_id, "flags": flags})
		_expect(not bool(flag.get("hidden", true)), "visible CTF flag should not be hidden", flag)
		var view: Dictionary = ops.call("build_capture_flag_view", owner_id) as Dictionary
		_expect(_viewer_can_see_flag(view, owner_id), "visible CTF owner flag not visible", {"owner_id": owner_id, "view": view})
		_expect(_viewer_can_see_flag(view, 3 - owner_id), "visible CTF enemy flag not visible", {"owner_id": owner_id, "view": view})

func _assert_hidden_visibility(ops: Node) -> void:
	var owner_one_view: Dictionary = ops.call("build_capture_flag_view", 1) as Dictionary
	var owner_two_view: Dictionary = ops.call("build_capture_flag_view", 2) as Dictionary
	_expect(_viewer_can_see_flag(owner_one_view, 1), "hidden CTF owner 1 cannot see own flag", owner_one_view)
	_expect(not _viewer_can_see_flag(owner_one_view, 2), "hidden CTF owner 1 can see enemy flag", owner_one_view)
	_expect(_viewer_can_see_flag(owner_two_view, 2), "hidden CTF owner 2 cannot see own flag", owner_two_view)
	_expect(not _viewer_can_see_flag(owner_two_view, 1), "hidden CTF owner 2 can see enemy flag", owner_two_view)

func _assert_flag_capture_result(ops: Node, state: GameState) -> void:
	var owner_two_flag_hive_id: int = int(ops.call("get_capture_flag_hive_id", 2))
	_expect(owner_two_flag_hive_id > 0, "owner 2 flag hive missing before capture", {})
	if owner_two_flag_hive_id <= 0:
		return
	var flag_hive: HiveData = state.find_hive_by_id(owner_two_flag_hive_id)
	_expect(flag_hive != null, "owner 2 flag hive data missing", {"hive_id": owner_two_flag_hive_id})
	if flag_hive == null:
		return
	flag_hive.owner_id = 1
	var win_system: Node = WinSystem.new()
	win_system.bind_state(state, ops)
	win_system.notify_hive_owner_changed()
	var result: Variant = win_system.tick(state, Time.get_ticks_msec())
	_expect(typeof(result) == TYPE_DICTIONARY, "flag capture win result missing", {"result": result})
	if typeof(result) != TYPE_DICTIONARY:
		win_system.free()
		return
	var win_result: Dictionary = result as Dictionary
	_expect(int(win_result.get("winner_id", 0)) == 1, "flag capture winner mismatch", win_result)
	_expect(str(win_result.get("reason", "")) == "flag_capture", "flag capture reason mismatch", win_result)
	win_system.free()

func _new_two_owner_ctf_state() -> GameState:
	var state: GameState = GameState.new()
	state.hives = [
		HiveData.new(1, Vector2i(0, 0), 1, 10, "Hive"),
		HiveData.new(2, Vector2i(1, 0), 1, 10, "Hive"),
		HiveData.new(3, Vector2i(4, 0), 2, 10, "Hive"),
		HiveData.new(4, Vector2i(5, 0), 2, 10, "Hive")
	]
	state.rebuild_indexes()
	return state

func _new_contest_state(label: String) -> Node:
	var contest_state: Node = ContestStateScript.new()
	contest_state.name = "MatrixContestState_%s" % label
	root.add_child(contest_state)
	var save_path: String = "user://player_config_matrix_%s_%s.json" % [label, _safe_config_id()]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if contest_state.has_method("debug_set_runtime_leaderboard_save_path"):
		contest_state.call("debug_set_runtime_leaderboard_save_path", save_path)
	if contest_state.has_method("debug_reset_runtime_leaderboards"):
		contest_state.call("debug_reset_runtime_leaderboards")
	return contest_state

func _contest_def(contest_id: String, family: String, map_ids: PackedStringArray) -> ContestDef:
	var contest: ContestDef = ContestDef.new()
	contest.id = contest_id
	contest.scope = "MATRIX"
	contest.currency = "USD"
	contest.price = 0
	contest.pool_type = "FREE"
	contest.contest_family = family
	contest.mode = family
	contest.schedule_kind = "SCHEDULED"
	contest.published = true
	contest.status = "OPEN"
	contest.map_ids = map_ids
	contest.normalize_definition()
	return contest

func _install_contest(contest_state: Node, contest_id: String, family: String, map_ids: PackedStringArray) -> String:
	var normalized_id: String = str(contest_state.call("normalize_contest_id", contest_id))
	var contest: ContestDef = _contest_def(normalized_id, family, map_ids)
	contest_state.set("contests", {normalized_id: contest})
	return normalized_id

func _stage_map_ids(count: int) -> PackedStringArray:
	var base_id: String = str(_row.get("resolved_map_path", "")).get_file().get_basename()
	if base_id.is_empty():
		base_id = "matrix_map"
	var out := PackedStringArray()
	for i in range(maxi(1, count)):
		out.append("%s_stage_%d" % [base_id, i + 1])
	return out

func _record_timed(contest_state: Node, contest_id: String, player_id: String, player_name: String, run_id: String, times: Array[int]) -> void:
	var result: Dictionary = contest_state.call("record_timed_race_result", contest_id, {
		"player_id": player_id,
		"player_name": player_name,
		"run_id": run_id,
		"map_count": 3,
		"completed_maps": times.size(),
		"map_times_ms": times,
		"status": "complete" if times.size() >= 3 else "incomplete",
		"source": "player_config_matrix"
	}) as Dictionary
	_expect(bool(result.get("ok", false)), "timed race record failed", result)

func _safe_config_id() -> String:
	var clean: String = _config_id.strip_edges()
	for ch in ["/", "\\", ":", " ", "."]:
		clean = clean.replace(ch, "_")
	return clean

func _viewer_can_see_flag(view: Dictionary, owner_id: int) -> bool:
	var flags: Array = view.get("flags", []) as Array
	for flag_any in flags:
		if typeof(flag_any) != TYPE_DICTIONARY:
			continue
		var flag: Dictionary = flag_any as Dictionary
		if int(flag.get("owner_id", 0)) != owner_id:
			continue
		return bool(flag.get("visible_to_viewer", false))
	return false

func _ops_state() -> Node:
	var ops: Node = root.get_node_or_null("OpsState")
	_expect(ops != null, "OpsState autoload missing", {})
	return ops

func _expect(condition: bool, message: String, details: Dictionary) -> void:
	if condition:
		return
	_failed = true
	push_error("PLAYER_CONFIG_MATRIX_MODE_RUNTIME: %s -> %s" % [message, details])
