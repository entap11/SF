extends SceneTree

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const Manifest := preload("res://tools/player_config_matrix_manifest.gd")

const DEFAULT_SOAK_SECONDS := 1800
const DEFAULT_ROUND_SECONDS := 300
const DEFAULT_PAIR_COUNT := 2
const DEFAULT_REAPPLY_MS := 1000
const DEFAULT_START_TIMEOUT_MS := 15000

var _map_path: String = ""
var _soak_seconds: int = DEFAULT_SOAK_SECONDS
var _round_seconds: int = DEFAULT_ROUND_SECONDS
var _pair_count: int = DEFAULT_PAIR_COUNT
var _reapply_ms: int = DEFAULT_REAPPLY_MS
var _start_timeout_ms: int = DEFAULT_START_TIMEOUT_MS
var _matrix_config_id: String = ""
var _seed: int = 0
var _topology: String = ""
var _contract_mode: String = ""
var _rules_mode: String = ""
var _required_players: int = 0
var _ctf_options: Dictionary = {}

func _initialize() -> void:
	_configure_logging()
	_parse_args(OS.get_cmdline_user_args())
	_resolve_matrix_config()
	_resolve_map_path()
	await _run()

func _configure_logging() -> void:
	SFLog.force_enable(true)
	SFLog.allow_tag("SOAK_START")
	SFLog.allow_tag("SOAK_ROUND_START")
	SFLog.allow_tag("SOAK_ROUND_INTENTS")
	SFLog.allow_tag("SOAK_ROUND_END")
	SFLog.allow_tag("SOAK_SUMMARY")
	SFLog.allow_tag("SOAK_ERROR")

func _parse_args(args: Array) -> void:
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg.begins_with("--map="):
			_map_path = arg.trim_prefix("--map=")
		elif arg.begins_with("--matrix-config="):
			_matrix_config_id = arg.trim_prefix("--matrix-config=").strip_edges()
		elif arg.begins_with("--config="):
			_matrix_config_id = arg.trim_prefix("--config=").strip_edges()
		elif arg.begins_with("--matrix-seed="):
			_seed = int(arg.trim_prefix("--matrix-seed="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--topology="):
			_topology = arg.trim_prefix("--topology=").strip_edges()
		elif arg.begins_with("--mode="):
			_rules_mode = arg.trim_prefix("--mode=").strip_edges().to_upper()
		elif arg.begins_with("--rules-mode="):
			_rules_mode = arg.trim_prefix("--rules-mode=").strip_edges().to_upper()
		elif arg.begins_with("--players="):
			_required_players = maxi(0, int(arg.trim_prefix("--players=")))
		elif arg.begins_with("--ctf-options-json="):
			var parsed: Variant = JSON.parse_string(arg.trim_prefix("--ctf-options-json="))
			if typeof(parsed) == TYPE_DICTIONARY:
				_ctf_options = parsed as Dictionary
		elif arg.begins_with("--seconds="):
			_soak_seconds = max(10, int(arg.trim_prefix("--seconds=")))
		elif arg.begins_with("--round-seconds="):
			_round_seconds = max(10, int(arg.trim_prefix("--round-seconds=")))
		elif arg.begins_with("--pairs="):
			_pair_count = clampi(int(arg.trim_prefix("--pairs=")), 1, 8)
		elif arg.begins_with("--reapply-ms="):
			_reapply_ms = max(250, int(arg.trim_prefix("--reapply-ms=")))
		elif arg.begins_with("--start-timeout-ms="):
			_start_timeout_ms = max(1000, int(arg.trim_prefix("--start-timeout-ms=")))

func _resolve_matrix_config() -> void:
	if _matrix_config_id.is_empty():
		return
	var row: Dictionary = Manifest.row_by_id(_matrix_config_id)
	if row.is_empty():
		SFLog.warn("SOAK_ERROR", {"reason": "matrix_config_not_found", "config_id": _matrix_config_id})
		return
	if str(row.get("expected_contract", "")) != Manifest.EXPECT_VALID:
		SFLog.warn("SOAK_ERROR", {"reason": "matrix_config_invalid_contract", "config_id": _matrix_config_id})
		return
	_topology = str(row.get("topology", _topology))
	_contract_mode = str(row.get("contract_mode", _contract_mode))
	_rules_mode = str(row.get("rules_mode", _rules_mode))
	if _map_path.is_empty():
		_map_path = str(row.get("resolved_map_path", ""))
	if _required_players <= 0:
		_required_players = Manifest.required_players_for_topology(_topology)
	if _ctf_options.is_empty() and typeof(row.get("ctf_options", {})) == TYPE_DICTIONARY:
		_ctf_options = (row.get("ctf_options", {}) as Dictionary).duplicate(true)

func _resolve_map_path() -> void:
	if not _map_path.is_empty():
		return
	var discovered: Array[String] = MapCatalog.list_json_maps()
	if discovered.is_empty():
		return
	_map_path = discovered[0]

func _run() -> void:
	await process_frame
	if _map_path.is_empty():
		SFLog.warn("SOAK_ERROR", {"reason": "no_map_available"})
		quit(1)
		return
	var soak_start_ms := Time.get_ticks_msec()
	var soak_deadline_ms := soak_start_ms + (_soak_seconds * 1000)
	var rounds: int = 0
	var failed_rounds: int = 0
	SFLog.info("SOAK_START", {
		"map": _map_path,
		"matrix_config": _matrix_config_id,
		"topology": _topology,
		"contract_mode": _contract_mode,
		"rules_mode": _rules_mode,
		"seed": _seed,
		"seconds": _soak_seconds,
		"round_seconds": _round_seconds,
		"pairs": _pair_count
	})
	while Time.get_ticks_msec() < soak_deadline_ms:
		rounds += 1
		var remaining_ms: int = soak_deadline_ms - Time.get_ticks_msec()
		var round_budget_ms: int = mini(_round_seconds * 1000, remaining_ms)
		var ok: bool = await _run_round(rounds, round_budget_ms)
		if not ok:
			failed_rounds += 1
	var elapsed_ms := Time.get_ticks_msec() - soak_start_ms
	SFLog.info("SOAK_SUMMARY", {
		"rounds": rounds,
		"failed_rounds": failed_rounds,
		"elapsed_s": snapped(float(elapsed_ms) / 1000.0, 0.1)
	})
	quit(1 if failed_rounds > 0 else 0)

func _run_round(round_index: int, round_budget_ms: int) -> bool:
	SFLog.info("SOAK_ROUND_START", {
		"round": round_index,
		"budget_ms": round_budget_ms
	})
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	if arena_scene == null:
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "arena_scene_load_failed"})
		return false
	var arena := arena_scene.instantiate() as Node2D
	if arena == null:
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "arena_instantiate_failed"})
		return false
	_prepare_matrix_runtime_context()
	root.add_child(arena)
	await process_frame
	await process_frame
	var result: Dictionary = MAP_LOADER.load_map(_map_path)
	if not bool(result.get("ok", false)):
		SFLog.warn("SOAK_ERROR", {
			"round": round_index,
			"reason": "map_load_failed",
			"error": str(result.get("err", result.get("error", "unknown")))
		})
		await _cleanup_round(arena)
		return false
	var data: Dictionary = result.get("data", {})
	MAP_APPLIER.apply_map(arena, data)
	if arena.has_method("start_sim"):
		arena.call("start_sim")
	var running_ok := await _wait_for_running(_start_timeout_ms)
	if not running_ok:
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "match_not_running"})
		await _cleanup_round(arena)
		return false
	var pairs := _pick_duel_pairs(_pair_count)
	if pairs.is_empty():
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "no_opposing_pairs"})
		await _cleanup_round(arena)
		return false
	_ensure_pairs_active(pairs)
	SFLog.info("SOAK_ROUND_INTENTS", {
		"round": round_index,
		"pairs": pairs
	})
	var end_ms: int = Time.get_ticks_msec() + maxi(1000, round_budget_ms)
	var last_reapply_ms: int = 0
	var ops_state: Node = _ops_state()
	while Time.get_ticks_msec() < end_ms:
		if ops_state != null and int(ops_state.get("match_phase")) == int(ops_state.MatchPhase.ENDED):
			break
		var now_ms := Time.get_ticks_msec()
		if now_ms - last_reapply_ms >= _reapply_ms:
			last_reapply_ms = now_ms
			if not _ensure_pairs_active(pairs):
				pairs = _pick_duel_pairs(_pair_count)
				_ensure_pairs_active(pairs)
		await process_frame
	await _cleanup_round(arena)
	SFLog.info("SOAK_ROUND_END", {
		"round": round_index,
		"phase": int(ops_state.get("match_phase")) if ops_state != null else -1
	})
	return true

func _prepare_matrix_runtime_context() -> void:
	if not _rules_mode.is_empty():
		set_meta("vs_mode", _rules_mode)
	if not _map_path.is_empty():
		set_meta("vs_stage_map_paths", [_map_path])
		set_meta("vs_stage_current_index", 0)
		set_meta("vs_stage_round_results", [])
	if _required_players > 0:
		set_meta("vs_required_players", _required_players)
	set_meta("vs_sync_start", true)
	set_meta("vs_free_roll", true)
	if not _matrix_config_id.is_empty():
		set_meta("player_config_matrix_soak_config_id", _matrix_config_id)
	if _seed != 0:
		set_meta("player_config_matrix_seed", _seed)
	if _rules_mode == Manifest.RULE_CAPTURE_FLAG or _rules_mode == Manifest.RULE_HIDDEN_CAPTURE_FLAG:
		set_meta("ctf_flag_selection_mode", str(_ctf_options.get("flag_selection_mode", "weighted")))
		set_meta("ctf_player_select_pct", int(_ctf_options.get("player_select_pct", 35)))
		set_meta("ctf_randomize_flag_hive", bool(_ctf_options.get("randomize_flag_hive", true)))
		set_meta("ctf_flag_move_count_max", int(_ctf_options.get("flag_move_count_max", 0)))
		set_meta("ctf_flag_move_reveals", bool(_ctf_options.get("flag_move_reveals", true)))
		set_meta("ctf_hidden_flag", _rules_mode == Manifest.RULE_HIDDEN_CAPTURE_FLAG)
	var ops_state: Node = _ops_state()
	if ops_state != null and ops_state.has_method("set_team_mode_override"):
		var override_mode: String = _team_mode_override_for_topology(_topology)
		if not override_mode.is_empty():
			ops_state.call("set_team_mode_override", override_mode)
	if ops_state != null and ops_state.has_method("sim_mutate") and _required_players > 0:
		var roster: Array = _roster_for_topology(_topology)
		ops_state.call("sim_mutate", "soak_perf_runner.matrix_roster", func() -> void:
			ops_state.set("match_roster", roster)
		)

func _team_mode_override_for_topology(topology: String) -> String:
	match topology:
		Manifest.TOPOLOGY_2V2:
			return "2v2"
		Manifest.TOPOLOGY_3P_FFA, Manifest.TOPOLOGY_4P_FFA:
			return "ffa"
		_:
			return ""

func _roster_for_topology(topology: String) -> Array:
	var teams: Array[int] = Manifest.expected_team_layout(topology)
	if teams.is_empty() and _required_players > 0:
		for i in range(_required_players):
			teams.append(i + 1)
	var names: Array[String] = ["Swarm Father", "Mrs. SwarmDaddy", "Third Swarm", "Fourth Swarm"]
	var roster: Array = []
	for i in range(teams.size()):
		roster.append({
			"seat": i + 1,
			"uid": "u_soak_%s_seat_%d" % [topology, i + 1],
			"display_name": names[i] if i < names.size() else "Soak %d" % (i + 1),
			"is_local": i == 0,
			"is_cpu": false,
			"active": true,
			"team_id": int(teams[i])
		})
	return roster

func _wait_for_running(timeout_ms: int) -> bool:
	var ops_state: Node = _ops_state()
	if ops_state == null:
		return false
	var start_ms := Time.get_ticks_msec()
	var last_hidden_select_ms := 0
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if int(ops_state.get("match_phase")) == int(ops_state.MatchPhase.RUNNING):
			return true
		var now_ms: int = Time.get_ticks_msec()
		if _rules_mode == Manifest.RULE_HIDDEN_CAPTURE_FLAG and now_ms - last_hidden_select_ms >= 500:
			last_hidden_select_ms = now_ms
			_auto_complete_hidden_ctf_selection(ops_state)
		await process_frame
	return false

func _auto_complete_hidden_ctf_selection(ops_state: Node) -> void:
	if ops_state == null:
		return
	if not ops_state.has_method("is_capture_flag_selection_pending"):
		return
	if not bool(ops_state.call("is_capture_flag_selection_pending")):
		return
	if ops_state.has_method("auto_complete_capture_flag_selection"):
		var result: Dictionary = ops_state.call("auto_complete_capture_flag_selection", 1) as Dictionary
		SFLog.info("SOAK_ROUND_INTENTS", {"hidden_ctf_auto_selected": bool(result.get("ok", false)), "result": result})

func _pick_duel_pairs(max_pairs: int) -> Array:
	var ops_state: Node = _ops_state()
	if ops_state == null:
		return []
	var st: GameState = ops_state.call("get_state") as GameState
	if st == null:
		return []
	var candidates: Array = []
	for src_any in st.hives:
		if not (src_any is HiveData):
			continue
		var src_hive: HiveData = src_any as HiveData
		var src_owner := int(src_hive.owner_id)
		if src_owner <= 0:
			continue
		for dst_any in st.hives:
			if not (dst_any is HiveData):
				continue
			var dst_hive: HiveData = dst_any as HiveData
			var src_id: int = int(src_hive.id)
			var dst_id: int = int(dst_hive.id)
			if src_id == dst_id:
				continue
			var dst_owner := int(dst_hive.owner_id)
			if dst_owner == src_owner:
				continue
			if not st.can_connect(src_id, dst_id):
				continue
			var src_pos: Vector2 = st.hive_world_pos_by_id(src_id)
			var dst_pos: Vector2 = st.hive_world_pos_by_id(dst_id)
			candidates.append({
				"src": src_id,
				"dst": dst_id,
				"len": src_pos.distance_to(dst_pos),
				"src_budget": int(st.lanes_allowed_for_power(int(src_hive.power)))
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("len", 0.0)) > float(b.get("len", 0.0))
	)
	var pairs: Array = []
	var picked_by_src: Dictionary = {}
	for c_any in candidates:
		if pairs.size() >= max_pairs:
			break
		var c: Dictionary = c_any as Dictionary
		var src: int = int(c.get("src", -1))
		var src_budget: int = maxi(1, int(c.get("src_budget", 1)))
		var picked: int = int(picked_by_src.get(src, 0))
		if picked >= src_budget:
			continue
		pairs.append({"src": src, "dst": int(c.get("dst", -1))})
		picked_by_src[src] = picked + 1
	return pairs

func _ensure_pairs_active(pairs: Array) -> bool:
	var ops_state: Node = _ops_state()
	if ops_state == null:
		return false
	var st: GameState = ops_state.call("get_state") as GameState
	if st == null:
		return false
	var kept: int = 0
	for p_any in pairs:
		if typeof(p_any) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_any as Dictionary
		var src: int = int(p.get("src", -1))
		var dst: int = int(p.get("dst", -1))
		if src <= 0 or dst <= 0 or src == dst:
			continue
		var src_hive: HiveData = st.find_hive_by_id(src)
		var dst_hive: HiveData = st.find_hive_by_id(dst)
		if src_hive == null or dst_hive == null:
			continue
		var src_owner := int(src_hive.owner_id)
		var dst_owner := int(dst_hive.owner_id)
		if src_owner <= 0 or src_owner == dst_owner:
			continue
		if not st.can_connect(src, dst):
			continue
		_ensure_attack_intent(src, dst, st)
		if dst_owner > 0:
			_ensure_attack_intent(dst, src, st)
		kept += 1
	return kept > 0

func _ensure_attack_intent(src: int, dst: int, st: GameState) -> void:
	if st.intent_is_on(src, dst):
		return
	var ops_state: Node = _ops_state()
	if ops_state != null:
		ops_state.call("apply_lane_intent", src, dst, "attack")

func _ops_state() -> Node:
	return root.get_node_or_null("OpsState")

func _cleanup_round(arena: Node2D) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	await process_frame
	await process_frame
