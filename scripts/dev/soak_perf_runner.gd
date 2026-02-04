extends SceneTree

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const ARENA_SCENE := preload("res://scenes/Arena.tscn")

const DEFAULT_MAP_PATH := "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_TOWER_1.json"
const DEFAULT_SOAK_SECONDS := 1800
const DEFAULT_ROUND_SECONDS := 300
const DEFAULT_PAIR_COUNT := 2
const DEFAULT_REAPPLY_MS := 1000
const DEFAULT_START_TIMEOUT_MS := 15000

var _map_path: String = DEFAULT_MAP_PATH
var _soak_seconds: int = DEFAULT_SOAK_SECONDS
var _round_seconds: int = DEFAULT_ROUND_SECONDS
var _pair_count: int = DEFAULT_PAIR_COUNT
var _reapply_ms: int = DEFAULT_REAPPLY_MS
var _start_timeout_ms: int = DEFAULT_START_TIMEOUT_MS

func _initialize() -> void:
	_configure_logging()
	_parse_args(OS.get_cmdline_user_args())
	await _run()

func _configure_logging() -> void:
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

func _run() -> void:
	await process_frame
	var soak_start_ms := Time.get_ticks_msec()
	var soak_deadline_ms := soak_start_ms + (_soak_seconds * 1000)
	var rounds: int = 0
	var failed_rounds: int = 0
	SFLog.info("SOAK_START", {
		"map": _map_path,
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
	var arena := ARENA_SCENE.instantiate() as Node2D
	if arena == null:
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "arena_instantiate_failed"})
		return false
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
	var last_reapply_ms := 0
	while Time.get_ticks_msec() < end_ms:
		if OpsState.match_phase == OpsState.MatchPhase.ENDED:
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
		"phase": int(OpsState.match_phase)
	})
	return true

func _wait_for_running(timeout_ms: int) -> bool:
	var start_ms := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if OpsState.match_phase == OpsState.MatchPhase.RUNNING:
			return true
		await process_frame
	return false

func _pick_duel_pairs(max_pairs: int) -> Array:
	var st: GameState = OpsState.get_state()
	if st == null:
		return []
	var candidates: Array = []
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		var a_hive: HiveData = st.find_hive_by_id(int(lane.a_id))
		var b_hive: HiveData = st.find_hive_by_id(int(lane.b_id))
		if a_hive == null or b_hive == null:
			continue
		var a_owner := int(a_hive.owner_id)
		var b_owner := int(b_hive.owner_id)
		if a_owner <= 0 or b_owner <= 0 or a_owner == b_owner:
			continue
		var a_pos: Vector2 = st.hive_world_pos_by_id(int(a_hive.id))
		var b_pos: Vector2 = st.hive_world_pos_by_id(int(b_hive.id))
		candidates.append({
			"src": int(a_hive.id),
			"dst": int(b_hive.id),
			"len": a_pos.distance_to(b_pos)
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("len", 0.0)) > float(b.get("len", 0.0))
	)
	var pairs: Array = []
	for c_any in candidates:
		if pairs.size() >= max_pairs:
			break
		var c: Dictionary = c_any as Dictionary
		pairs.append({"src": int(c.get("src", -1)), "dst": int(c.get("dst", -1))})
	return pairs

func _ensure_pairs_active(pairs: Array) -> bool:
	var st: GameState = OpsState.get_state()
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
		if src_owner <= 0 or dst_owner <= 0 or src_owner == dst_owner:
			continue
		_ensure_attack_intent(src, dst, st)
		_ensure_attack_intent(dst, src, st)
		kept += 1
	return kept > 0

func _ensure_attack_intent(src: int, dst: int, st: GameState) -> void:
	if st.intent_is_on(src, dst):
		return
	OpsState.apply_lane_intent(src, dst, "attack")

func _cleanup_round(arena: Node2D) -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
	await process_frame
	await process_frame
