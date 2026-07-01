# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends RefCounted
class_name MapApplier
const SFLog := preload("res://scripts/util/sf_log.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const TRACE_MAP_APPLY: bool = false

static func apply_map(arena: Node2D, d: Dictionary) -> void:
	SFLog.allow_tag("MAP_APPLIER_RUNTIME_ROSTER_WRITE")
	var map_id := str(d.get("map_id", d.get("_id", d.get("id", "UNKNOWN"))))
	if TRACE_MAP_APPLY and SFLog.LOGGING_ENABLED:
		print("MAP_APPLY_TRIGGERED map_id=",
		map_id,
		" schema=", str(d.get("_schema", "")),
		"\nSTACK:\n", str(get_stack()))
	if arena == null:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP APPLY FAIL: arena is null")
		return
	if d.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("MAP APPLY FAIL: map is empty")
		return
	d = _adapt_map_for_vs_mode(d)
	d = _apply_progressive_scaling(d)
	var randomizer_payload: Dictionary = _match_randomizer_payload()
	if MatchSetupRandomizer.should_randomize_start_slots(randomizer_payload):
		d = MatchSetupRandomizer.apply_start_slots(d, randomizer_payload, _infer_active_seats_from_map(d))
	d = MatchSetupRandomizer.apply_to_map_data(d, randomizer_payload)
	if _is_dev_runner():
		_dev_seed_lanes_and_spawns(d)

	var p1_uid: String = _profile_manager_user_id()
	var active_seats: Array = _infer_active_seats_from_map(d)
	var team_by_seat: Dictionary = _resolve_team_ids_for_seats(d, active_seats)
	var roster: Array = [
		{
			"seat": 1,
			"team_id": int(team_by_seat.get(1, 1)),
			"uid": p1_uid,
			"is_local": true,
			"is_cpu": false,
			"active": active_seats.has(1)
		},
		{
			"seat": 2,
			"team_id": int(team_by_seat.get(2, 2)),
			"uid": "",
			"is_local": false,
			"is_cpu": active_seats.has(2),
			"active": active_seats.has(2)
		},
		{
			"seat": 3,
			"team_id": int(team_by_seat.get(3, 3)),
			"uid": "",
			"is_local": false,
			"is_cpu": active_seats.has(3),
			"active": active_seats.has(3)
		},
		{
			"seat": 4,
			"team_id": int(team_by_seat.get(4, 4)),
			"uid": "",
			"is_local": false,
			"is_cpu": active_seats.has(4),
			"active": active_seats.has(4)
		}
	]
	_apply_tree_vs_profiles_to_roster(roster, active_seats)
	if _is_runtime_non_dev_context():
		SFLog.warn("MAP_APPLIER_RUNTIME_ROSTER_WRITE", {
			"map_id": map_id,
			"reason": "runtime_direct_roster_assignment"
		})
	SFLog.info("MATCH_ROSTER", {
		"p1_uid": str((roster[0] as Dictionary).get("uid", "")),
		"p2_uid": str((roster[1] as Dictionary).get("uid", "")),
		"p3_uid": str((roster[2] as Dictionary).get("uid", "")),
		"p4_uid": str((roster[3] as Dictionary).get("uid", "")),
		"active_seats": active_seats,
		"team_by_seat": team_by_seat
	})
	SFLog.allow_tag("TEAM_ASSIGNMENT")
	var local_seat_for_team: int = _resolve_local_seat(roster)
	var local_team_id: int = int(team_by_seat.get(local_seat_for_team, local_seat_for_team))
	var ally_seats: Array = []
	var enemy_seats: Array = []
	for seat in [1, 2, 3, 4]:
		if not active_seats.has(seat):
			continue
		var team_id: int = int(team_by_seat.get(seat, seat))
		if team_id == local_team_id:
			ally_seats.append(seat)
		else:
			enemy_seats.append(seat)
	SFLog.warn("TEAM_ASSIGNMENT", {
		"map_id": map_id,
		"mode_override": _team_mode_override(),
		"active_seats": active_seats,
		"team_by_seat": team_by_seat,
		"local_seat": local_seat_for_team,
		"local_team_id": local_team_id,
		"ally_seats": ally_seats,
		"enemy_seats": enemy_seats
	}, "", 0)
	if "active_player_id" in arena:
		var local_seat: int = local_seat_for_team
		arena.set("active_player_id", local_seat)
		SFLog.allow_tag("ACTIVE_PLAYER_RESET")
		SFLog.warn("ACTIVE_PLAYER_RESET", {
			"seat": local_seat,
			"map_id": map_id
		})

	var ops_state: Node = _ops_state()
	if ops_state == null:
		push_error("MAP APPLY FAIL: OpsState is not available")
		return
	var built_state: GameState = ops_state.call("reset_state_from_map", d) as GameState
	# reset_state_from_map() resets match state, including match_roster.
	# Reapply roster after reset so team mapping remains authoritative for the live match.
	ops_state.call("sim_mutate", "MapApplier.apply_map_post_reset_roster", func() -> void:
		if ops_state.has_method("audit_mutation"):
			ops_state.call("audit_mutation", "MapApplier.apply_map_post_reset_roster", "match_roster", "res://scripts/maps/map_applier.gd")
		ops_state.set("match_roster", roster)
		if ops_state.has_method("ensure_bot_profiles_from_roster"):
			ops_state.call("ensure_bot_profiles_from_roster")
	)
	var map_lanes: Array = []
	for i in range(built_state.lanes.size()):
		var lane: Variant = built_state.lanes[i]
		var lane_id := -1
		var a_id := -1
		var b_id := -1
		if lane is LaneData:
			lane_id = int(lane.id)
			a_id = int(lane.a_id)
			b_id = int(lane.b_id)
		elif lane is Dictionary:
			var d_lane := lane as Dictionary
			lane_id = int(d_lane.get("lane_id", d_lane.get("id", -1)))
			a_id = int(d_lane.get("a_id", -1))
			b_id = int(d_lane.get("b_id", -1))
		if a_id <= 0 or b_id <= 0:
			continue
		map_lanes.append({
			"lane_id": lane_id,
			"a_id": a_id,
			"b_id": b_id
		})
	map_lanes.sort_custom(Callable(MapApplier, "_lane_dump_less"))
	built_state.set("map_lanes", map_lanes)
	SFLog.info("MAP_LANES_SET", {
		"count": map_lanes.size(),
		"sample": map_lanes[0] if map_lanes.size() > 0 else null
	})
	if "state" in arena:
		arena.state = built_state
		if "lane_system" in arena and arena.lane_system != null:
			arena.lane_system.bind_state(built_state)
	if "current_map_data" in arena:
		arena.current_map_data = d.duplicate(true)
	var dims: Vector2i = _resolve_grid_dims(d, built_state)
	if arena.has_method("_configure_grid_spec"):
		arena.call("_configure_grid_spec", int(dims.x), int(dims.y))
	SFLog.allow_tag("MAP_GRID_SPEC_APPLIED")
	SFLog.warn("MAP_GRID_SPEC_APPLIED", {
		"map_id": map_id,
		"grid_w": int(dims.x),
		"grid_h": int(dims.y)
	}, "", 0)
	SFLog.info("MAP_APPLIED_STATE", {
		"map_id": map_id,
		"hive_count": built_state.hives.size(),
		"state_iid": built_state.get_instance_id()
	})
	_dump_hive_snapshot(map_id, built_state)
	_dump_lanes(map_id, built_state)

	if arena.has_method("set_model"):
		arena.call("set_model", d)
	else:
		arena.set("model", d)

	arena.render_version += 1

	var hive_r: Node = arena.get_node_or_null("MapRoot/HiveRenderer")
	var lane_r: Node = arena.get_node_or_null("MapRoot/LaneRenderer")
	if hive_r != null:
		if hive_r.has_method("set_model"):
			hive_r.call("set_model", d)
		else:
			hive_r.set("model", d)
		if hive_r is CanvasItem:
			(hive_r as CanvasItem).queue_redraw()
	if lane_r != null:
		if lane_r.has_method("set_model"):
			lane_r.call("set_model", d)
		else:
			lane_r.set("model", d)
		if hive_r != null and lane_r.has_method("set_hive_nodes") and hive_r.has_method("get_hive_nodes_by_id"):
			lane_r.call("set_hive_nodes", hive_r.call("get_hive_nodes_by_id"))
		if lane_r is CanvasItem:
			(lane_r as CanvasItem).queue_redraw()

	if arena.has_method("mark_render_dirty"):
		arena.call("mark_render_dirty", "map_apply")
	if arena.has_method("_push_render_model"):
		arena.call("_push_render_model")
	if arena.has_method("apply_camera_fit_next_frame"):
		arena.call("apply_camera_fit_next_frame", "map_applier")
		SFLog.allow_tag("MAP_FITCAM_APPLIED")
		SFLog.warn("MAP_FITCAM_APPLIED", {
			"map_id": map_id,
			"grid_w": int(dims.x),
			"grid_h": int(dims.y)
		}, "", 0)

	# === OWNER SANITY CHECK (log once per map apply) ===
	var p1 := 0
	var p2 := 0
	var p3 := 0
	var p4 := 0
	var neutral := 0

	var state = arena.state
	if state is Dictionary and state.has("hives") and state["hives"] is Array:
		for h in state["hives"]:
			var oid := 0
			if h is Dictionary:
				oid = int(h.get("owner_id", h.get("owner", 0)))
			elif typeof(h) == TYPE_OBJECT and h != null and h.has_method("get"):
				oid = int(h.get("owner_id", 0))
			match oid:
				1: p1 += 1
				2: p2 += 1
				3: p3 += 1
				4: p4 += 1
				_: neutral += 1
		SFLog.info("LIVE_OWNER_SUMMARY", {"p1": p1, "p2": p2, "p3": p3, "p4": p4, "neutral": neutral})
	else:
		SFLog.warn("LIVE_OWNER_SUMMARY_SKIPPED", {"reason": "arena.state not ready or not dict", "state_type": typeof(state)})

static func _is_dev_runner() -> bool:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return false
	var tree := loop as SceneTree
	return tree.get_root().get_node_or_null("DevMapRunner") != null

static func _profile_manager_user_id() -> String:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return "local"
	var tree := loop as SceneTree
	var manager: Node = tree.get_root().get_node_or_null("ProfileManager")
	if manager != null and manager.has_method("get_user_id"):
		var uid: String = str(manager.call("get_user_id")).strip_edges()
		if not uid.is_empty():
			return uid
	return "local"

static func _ops_state() -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var tree := loop as SceneTree
	return tree.get_root().get_node_or_null("OpsState")

static func _apply_progressive_scaling(map_data: Dictionary) -> Dictionary:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return map_data
	var tree := loop as SceneTree
	if str(tree.get_meta("vs_mode", "")).strip_edges().to_upper() != "PROGRESSIVE":
		return map_data
	var npc_bonus: int = int(tree.get_meta("progressive_npc_power_bonus", 0))
	var bot_bonus: int = int(tree.get_meta("progressive_bot_start_power_bonus", 0))
	var player_delta: int = int(tree.get_meta("progressive_player_start_power_delta", 0))
	if npc_bonus == 0 and bot_bonus == 0 and player_delta == 0:
		return map_data
	var out: Dictionary = map_data.duplicate(true)
	var hives_any: Variant = out.get("hives", [])
	if typeof(hives_any) != TYPE_ARRAY:
		return map_data
	var hives: Array = hives_any as Array
	for i in range(hives.size()):
		var hive_any: Variant = hives[i]
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = (hive_any as Dictionary).duplicate(true)
		var owner_id: int = int(hive.get("owner_id", 0))
		var current_power: int = int(hive.get("power", hive.get("pwr", 10)))
		var next_power: int = current_power
		if owner_id == 1:
			next_power = maxi(1, current_power + player_delta)
		elif owner_id > 1:
			next_power = maxi(1, current_power + bot_bonus)
		else:
			next_power = maxi(1, current_power + npc_bonus)
		hive["power"] = next_power
		hive["pwr"] = next_power
		hives[i] = hive
	out["hives"] = hives
	SFLog.info("PROGRESSIVE_MAP_SCALING", {
		"npc_power_bonus": npc_bonus,
		"bot_start_power_bonus": bot_bonus,
		"player_start_power_delta": player_delta
	})
	return out

static func _is_runtime_non_dev_context() -> bool:
	if Engine.is_editor_hint():
		return false
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return true
	var tree := loop as SceneTree
	return tree.get_root().get_node_or_null("DevMapRunner") == null

static func _infer_active_seats_from_map(map_dict: Dictionary) -> Array:
	var vs_mode_seats: Array = _active_seats_from_vs_mode()
	if not vs_mode_seats.is_empty():
		return vs_mode_seats
	var declared: Array = _active_seats_from_declared_mode(map_dict)
	if not declared.is_empty():
		return declared
	var seats: Array = []
	var hives_v: Variant = map_dict.get("hives", [])
	if typeof(hives_v) == TYPE_ARRAY:
		for hive_any in hives_v as Array:
			if typeof(hive_any) != TYPE_DICTIONARY:
				continue
			var hive: Dictionary = hive_any as Dictionary
			var owner_id: int = int(hive.get("owner_id", 0))
			if owner_id < 1 or owner_id > 4:
				continue
			if not seats.has(owner_id):
				seats.append(owner_id)
	if seats.is_empty():
		seats = [1, 2]
	elif seats.size() == 1:
		var only: int = int(seats[0])
		if only == 1:
			seats.append(2)
		else:
			seats.insert(0, 1)
	seats.sort()
	return seats

static func _active_seats_from_vs_mode() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not tree.has_meta("vs_mode"):
		return []
	var mode: String = str(tree.get_meta("vs_mode", "")).strip_edges().to_upper()
	match mode:
		"2V2", "4P FFA":
			return [1, 2, 3, 4]
		"3P FFA":
			return [1, 2, 3]
		_:
			return []

static func _adapt_map_for_vs_mode(map_dict: Dictionary) -> Dictionary:
	var mode: String = _vs_mode()
	if mode == "CAPTURE_FLAG" or mode == "HIDDEN_CAPTURE_FLAG":
		return _adapt_map_for_capture_flag(map_dict, mode)
	if mode != "2V2" and mode != "4P FFA":
		return map_dict
	if _mode_from_map_descriptor(map_dict) != "1p":
		return map_dict
	var hives_v: Variant = map_dict.get("hives", [])
	if typeof(hives_v) != TYPE_ARRAY:
		return map_dict
	var out: Dictionary = map_dict.duplicate(true)
	var hives: Array = out.get("hives", []) as Array
	var changed: bool = false
	changed = _ensure_hive_for_multiplayer_seat(hives, 1, 3, true) or changed
	changed = _ensure_hive_for_multiplayer_seat(hives, 2, 4, false) or changed
	if changed:
		out["hives"] = hives
		SFLog.info("MAP_APPLIER_MULTIPLAYER_OWNER_SPLIT", {
			"map_id": str(out.get("map_id", out.get("_id", out.get("id", "UNKNOWN")))),
			"vs_mode": mode,
			"owner_counts": _owner_counts_for_hives(hives)
		})
	return out

static func _adapt_map_for_capture_flag(map_dict: Dictionary, mode: String) -> Dictionary:
	var out: Dictionary = MapModeRules.apply_capture_flag_territory_split(map_dict, {"mode": mode})
	var split_meta: Dictionary = out.get("capture_flag_territory_split", {}) as Dictionary
	SFLog.info("MAP_APPLIER_CTF_TERRITORY_SPLIT", {
		"map_id": str(out.get("map_id", out.get("_id", out.get("id", "UNKNOWN")))),
		"vs_mode": mode,
		"owner_counts": split_meta.get("owner_counts", {}),
		"neutral_count": int(split_meta.get("neutral_count", 0))
	})
	return out

static func _hidden_ctf_allotment_options(map_dict: Dictionary) -> Dictionary:
	var options: Dictionary = {
		"pattern": MapModeRules.HIDDEN_CTF_ALLOTMENT_ROLL,
		"seed": 0
	}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return options
	if tree.has_meta("hidden_ctf_allotment_pattern"):
		options["pattern"] = str(tree.get_meta("hidden_ctf_allotment_pattern", MapModeRules.HIDDEN_CTF_ALLOTMENT_ROLL))
	if tree.has_meta("hidden_ctf_allotment_seed"):
		options["seed"] = int(tree.get_meta("hidden_ctf_allotment_seed", 0))
	if int(options.get("seed", 0)) != 0:
		return options
	var session_source: String = "%s|%s|%s|%s" % [
		str(tree.get_meta("vs_handshake_session_id", "")).strip_edges(),
		str(tree.get_meta("vs_handshake_invite_code", "")).strip_edges(),
		str(tree.get_meta("vs_stage_current_index", 0)),
		str(map_dict.get("map_id", map_dict.get("_id", map_dict.get("id", "")))).strip_edges()
	]
	var seed: int = _stable_positive_hash(session_source)
	if seed == 0:
		seed = maxi(1, Time.get_ticks_msec())
	options["seed"] = seed
	tree.set_meta("hidden_ctf_allotment_seed", seed)
	return options

static func _stable_positive_hash(text: String) -> int:
	var h: int = 17
	for i in range(text.length()):
		h = int((h * 31 + text.unicode_at(i)) % 2147483647)
	return maxi(0, h)

static func _match_randomizer_payload() -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	for key in [MatchSetupRandomizer.TREE_META_KEY, MatchSetupRandomizer.CONTEXT_KEY]:
		if not tree.has_meta(key):
			continue
		var payload_v: Variant = tree.get_meta(key, {})
		if typeof(payload_v) == TYPE_DICTIONARY:
			return (payload_v as Dictionary).duplicate(true)
	return {}

static func _ensure_hive_for_multiplayer_seat(hives: Array, source_owner: int, target_owner: int, prefer_lower_y: bool) -> bool:
	if _hive_count_for_owner(hives, target_owner) > 0:
		return false
	var source_hives: Array = _hives_for_owner(hives, source_owner)
	if source_hives.size() > 1:
		source_hives.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _hive_y(a) < _hive_y(b)
		)
		var selected: Dictionary = source_hives[source_hives.size() - 1] if prefer_lower_y else source_hives[0]
		selected["owner_id"] = target_owner
		return true
	var neutral: Dictionary = _best_neutral_hive_for_split(hives, source_hives, prefer_lower_y)
	if neutral.is_empty():
		return false
	neutral["owner_id"] = target_owner
	return true

static func _best_neutral_hive_for_split(hives: Array, source_hives: Array, prefer_lower_y: bool) -> Dictionary:
	var source_x: float = 0.0
	var source_y: float = 0.0
	if not source_hives.is_empty():
		var source: Dictionary = source_hives[0] as Dictionary
		source_x = _hive_x(source)
		source_y = _hive_y(source)
	else:
		source_x = 0.0
		source_y = 0.0
	var target_y: float = source_y + (8.0 if prefer_lower_y else -8.0)
	var best: Dictionary = {}
	var best_score: float = INF
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		if int(hive.get("owner_id", 0)) != 0:
			continue
		var score: float = absf(_hive_x(hive) - source_x) * 4.0 + absf(_hive_y(hive) - target_y)
		if score < best_score:
			best_score = score
			best = hive
	return best

static func _hives_for_owner(hives: Array, owner: int) -> Array:
	var out: Array = []
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var hive: Dictionary = hive_any as Dictionary
		if int(hive.get("owner_id", 0)) == owner:
			out.append(hive)
	return out

static func _hive_count_for_owner(hives: Array, owner: int) -> int:
	return _hives_for_owner(hives, owner).size()

static func _owner_counts_for_hives(hives: Array) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in hives:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var owner: int = int((hive_any as Dictionary).get("owner_id", 0))
		counts[owner] = int(counts.get(owner, 0)) + 1
	return counts

static func _hive_x(hive: Dictionary) -> float:
	if hive.has("x"):
		return float(hive.get("x", 0.0))
	var grid_pos: Variant = hive.get("grid_pos", [])
	if typeof(grid_pos) == TYPE_ARRAY and (grid_pos as Array).size() >= 1:
		return float((grid_pos as Array)[0])
	return 0.0

static func _hive_y(hive: Dictionary) -> float:
	if hive.has("y"):
		return float(hive.get("y", 0.0))
	var grid_pos: Variant = hive.get("grid_pos", [])
	if typeof(grid_pos) == TYPE_ARRAY and (grid_pos as Array).size() >= 2:
		return float((grid_pos as Array)[1])
	return 0.0

static func _active_seats_from_declared_mode(map_dict: Dictionary) -> Array:
	var mode: String = _mode_from_map_descriptor(map_dict)
	match mode:
		"1p", "2p":
			return [1, 2]
		"3p":
			return [1, 2, 3]
		"4p":
			return [1, 2, 3, 4]
		_:
			return []

static func _mode_from_map_descriptor(map_dict: Dictionary) -> String:
	var mode_raw: String = str(map_dict.get("mode", "")).strip_edges().to_lower()
	if mode_raw == "1p" or mode_raw == "2p" or mode_raw == "3p" or mode_raw == "4p":
		return mode_raw
	var map_id: String = str(map_dict.get("id", map_dict.get("_id", map_dict.get("map_id", "")))).strip_edges().to_lower()
	if map_id.ends_with("__1p"):
		return "1p"
	if map_id.ends_with("__2p"):
		return "2p"
	if map_id.ends_with("__3p"):
		return "3p"
	if map_id.ends_with("__4p"):
		return "4p"
	return ""

static func _vs_mode() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or not tree.has_meta("vs_mode"):
		return ""
	return str(tree.get_meta("vs_mode", "")).strip_edges().to_upper()

static func _resolve_local_seat(roster: Array) -> int:
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if bool(entry.get("is_local", false)):
			var seat: int = int(entry.get("seat", 1))
			if seat >= 1 and seat <= 4:
				return seat
	return 1

static func _resolve_team_ids_for_seats(map_dict: Dictionary, active_seats: Array) -> Dictionary:
	var team_by_seat: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4}
	var has_all_four: bool = active_seats.has(1) and active_seats.has(2) and active_seats.has(3) and active_seats.has(4) and active_seats.size() == 4
	if has_all_four:
		var mode_override: String = _team_mode_override()
		if mode_override == "ffa":
			team_by_seat[1] = 1
			team_by_seat[2] = 2
			team_by_seat[3] = 3
			team_by_seat[4] = 4
			return team_by_seat
		if mode_override == "2v2":
			team_by_seat[1] = 1
			team_by_seat[3] = 1
			team_by_seat[2] = 2
			team_by_seat[4] = 2
			return team_by_seat
	var explicit_any: Variant = map_dict.get("team_by_seat", map_dict.get("teams", null))
	if typeof(explicit_any) == TYPE_DICTIONARY:
		var explicit_dict: Dictionary = explicit_any as Dictionary
		for key_any in explicit_dict.keys():
			var seat: int = int(key_any)
			if seat < 1 or seat > 4:
				continue
			var team_id: int = int(explicit_dict.get(key_any, seat))
			if team_id <= 0:
				team_id = seat
			team_by_seat[seat] = team_id
		return team_by_seat
	if typeof(explicit_any) == TYPE_ARRAY:
		for team_entry_any in explicit_any as Array:
			if typeof(team_entry_any) != TYPE_DICTIONARY:
				continue
			var team_entry: Dictionary = team_entry_any as Dictionary
			var team_id: int = int(team_entry.get("team_id", team_entry.get("id", 0)))
			if team_id <= 0:
				continue
			var seats_any: Variant = team_entry.get("seats", [])
			if typeof(seats_any) != TYPE_ARRAY:
				continue
			for seat_any in seats_any as Array:
				var seat: int = int(seat_any)
				if seat >= 1 and seat <= 4:
					team_by_seat[seat] = team_id
		return team_by_seat
	if has_all_four:
		team_by_seat[1] = 1
		team_by_seat[3] = 1
		team_by_seat[2] = 2
		team_by_seat[4] = 2
	return team_by_seat

static func _apply_tree_vs_profiles_to_roster(roster: Array, active_seats: Array) -> void:
	if roster == null or roster.is_empty():
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var role: String = str(tree.get_meta("vs_handshake_role", "host")).strip_edges().to_lower()
	var local_seat: int = 2 if role == "guest" else 1
	var remote_seat: int = 1 if local_seat == 2 else 2
	_set_roster_local_flag(roster, 1, local_seat == 1)
	_set_roster_local_flag(roster, 2, local_seat == 2)
	var local_profile: Dictionary = _tree_profile_meta(tree, "vs_local_profile")
	var remote_profile: Dictionary = _tree_profile_meta(tree, "vs_remote_profile")
	_apply_profile_to_roster_entry(roster, local_seat, local_profile, active_seats, true)
	_apply_profile_to_roster_entry(roster, remote_seat, remote_profile, active_seats, false)

static func _tree_profile_meta(tree: SceneTree, key: String) -> Dictionary:
	if tree == null or not tree.has_meta(key):
		return {}
	var raw: Variant = tree.get_meta(key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var profile: Dictionary = (raw as Dictionary).duplicate(true)
	var uid: String = str(profile.get("uid", "")).strip_edges()
	if uid.is_empty():
		return {}
	profile["uid"] = uid
	profile["display_name"] = str(profile.get("display_name", "")).strip_edges()
	return profile

static func _apply_profile_to_roster_entry(roster: Array, seat: int, profile: Dictionary, active_seats: Array, is_local: bool) -> void:
	if profile.is_empty():
		return
	var index: int = seat - 1
	if index < 0 or index >= roster.size():
		return
	if typeof(roster[index]) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = (roster[index] as Dictionary).duplicate(true)
	entry["uid"] = str(profile.get("uid", ""))
	var display_name: String = str(profile.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		entry["display_name"] = display_name
	entry["is_local"] = is_local
	entry["is_cpu"] = bool(profile.get("is_cpu", false))
	entry["active"] = active_seats.has(seat)
	roster[index] = entry

static func _set_roster_local_flag(roster: Array, seat: int, is_local: bool) -> void:
	var index: int = seat - 1
	if index < 0 or index >= roster.size():
		return
	if typeof(roster[index]) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = (roster[index] as Dictionary).duplicate(true)
	entry["is_local"] = is_local
	roster[index] = entry

static func _team_mode_override() -> String:
	var ops_state: Node = _ops_state()
	if ops_state == null or not ops_state.has_method("get_team_mode_override"):
		return ""
	var mode: String = str(ops_state.call("get_team_mode_override")).strip_edges().to_lower()
	if mode == "ffa" or mode == "2v2" or mode == "1p":
		return mode
	return ""

static func _dump_lanes(map_id: String, state: GameState) -> void:
	if state == null:
		return
	var lanes_out: Array = []
	var idx := 0
	for i in range(state.lanes.size()):
		var lane: Variant = state.lanes[i]
		var lane_id := -1
		var a_id := -1
		var b_id := -1
		if lane is LaneData:
			lane_id = int(lane.id)
			a_id = int(lane.a_id)
			b_id = int(lane.b_id)
		elif lane is Dictionary:
			var d: Dictionary = lane
			a_id = int(d.get("a_id", -1))
			b_id = int(d.get("b_id", -1))
			lane_id = int(d.get("id", -1))
		var entry := {
			"a_id": a_id,
			"b_id": b_id,
			"idx": idx
		}
		if lane_id != -1:
			entry["lane_id"] = lane_id
		lanes_out.append(entry)
		idx += 1
	lanes_out.sort_custom(Callable(MapApplier, "_lane_dump_less"))
	var payload := {
		"map_id": map_id,
		"hive_count": state.hives.size(),
		"lane_count": lanes_out.size(),
		"lanes": lanes_out
	}
	var json := JSON.stringify(payload)
	SFLog.info("LANE_DUMP_JSON", {"json": json})

static func _dump_hive_snapshot(map_id: String, state: GameState) -> void:
	if state == null:
		return
	SFLog.allow_tag("MAP_HIVE_SNAPSHOT")
	var hives_out: Array = []
	for hive_any in state.hives:
		if hive_any == null:
			continue
		var hive: HiveData = hive_any as HiveData
		hives_out.append({
			"id": int(hive.id),
			"owner_id": int(hive.owner_id),
			"grid_pos": Vector2i(int(hive.grid_pos.x), int(hive.grid_pos.y))
		})
	hives_out.sort_custom(Callable(MapApplier, "_hive_dump_less"))
	SFLog.warn("MAP_HIVE_SNAPSHOT", {
		"map_id": map_id,
		"hive_count": hives_out.size(),
		"hives": hives_out
	}, "", 0)

static func _resolve_grid_dims(map_dict: Dictionary, state: GameState) -> Vector2i:
	var w: int = int(map_dict.get("grid_w", map_dict.get("width", 0)))
	var h: int = int(map_dict.get("grid_h", map_dict.get("height", 0)))
	if w > 0 and h > 0:
		return Vector2i(w, h)
	if state != null:
		var max_x: int = -1
		var max_y: int = -1
		for hive_any in state.hives:
			var hive: HiveData = hive_any as HiveData
			if hive == null:
				continue
			max_x = maxi(max_x, int(hive.grid_pos.x))
			max_y = maxi(max_y, int(hive.grid_pos.y))
		if max_x >= 0 and max_y >= 0:
			return Vector2i(max_x + 1, max_y + 1)
	return Vector2i(8, 12)

static func _lane_dump_less(a: Dictionary, b: Dictionary) -> bool:
	var a_min: int = mini(int(a.get("a_id", -1)), int(a.get("b_id", -1)))
	var b_min: int = mini(int(b.get("a_id", -1)), int(b.get("b_id", -1)))
	if a_min == b_min:
		var a_max: int = maxi(int(a.get("a_id", -1)), int(a.get("b_id", -1)))
		var b_max: int = maxi(int(b.get("a_id", -1)), int(b.get("b_id", -1)))
		if a_max == b_max:
			var a_key: int = int(a.get("lane_id", a.get("id", a.get("idx", -1))))
			var b_key: int = int(b.get("lane_id", b.get("id", b.get("idx", -1))))
			return a_key < b_key
		return a_max < b_max
	return a_min < b_min

static func _hive_dump_less(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("id", -1)) < int(b.get("id", -1))

static func _dev_seed_lanes_and_spawns(model: Dictionary) -> void:
	var spawns_v: Variant = model.get("spawns", [])
	if typeof(spawns_v) == TYPE_ARRAY and (spawns_v as Array).is_empty():
		var hives_v: Variant = model.get("hives", [])
		if typeof(hives_v) == TYPE_ARRAY:
			var dev_spawns: Array = []
			for hive_v in hives_v as Array:
				if typeof(hive_v) != TYPE_DICTIONARY:
					continue
				var hd: Dictionary = hive_v as Dictionary
				var owner_id: int = int(hd.get("owner_id", 0))
				if owner_id <= 0:
					continue
				dev_spawns.append({
					"hive_id": hd.get("id", 0),
					"rate": 1.0,
					"owner_id": owner_id
				})
			model["spawns"] = dev_spawns
			if SFLog.LOGGING_ENABLED:
				print("DEV_FALLBACK: seeded spawns=%d" % dev_spawns.size())
