class_name ArenaAPI
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const GridSpec := preload("res://scripts/maps/grid_spec.gd")

signal selected_hive_changed(selected_id: int)

var _arena: Node = null
var _map_root: Node2D = null
var _hive_renderer: HiveRenderer = null
var selected_hive_id: int = -1
var _state: GameState = null

func _init(arena_ref: Node) -> void:
	_arena = arena_ref
	_map_root = _resolve_map_root()
	_hive_renderer = _resolve_hive_renderer()

func bind_state(state_ref: GameState) -> void:
	_state = state_ref

func is_valid() -> bool:
	return _arena != null

func get_state() -> GameState:
	return _state

func get_grid_spec() -> GridSpec:
	if _arena == null:
		return null
	return _arena.grid_spec

func get_selection() -> SelectionState:
	if _arena == null:
		return null
	return _arena.sel

func get_active_player_id() -> int:
	if _arena == null:
		return -1
	return _arena.active_player_id

func get_active_pid() -> int:
	return get_active_player_id()

func set_active_player_id(player_id: int) -> void:
	if _arena == null:
		return
	_arena.active_player_id = player_id
	mark_render_dirty("active_player")

func set_selected_hive_id(hive_id: int) -> void:
	if hive_id == selected_hive_id:
		return
	selected_hive_id = hive_id
	emit_signal("selected_hive_changed", selected_hive_id)

func clear_selection() -> void:
	set_selected_hive_id(-1)

func get_sim_running() -> bool:
	if _arena == null:
		return false
	return bool(_arena.sim_running)

func set_sim_running(value: bool) -> void:
	if _arena == null:
		return
	_arena.sim_running = value
	mark_render_dirty("sim_running")

func get_debris_enabled() -> bool:
	if _arena == null:
		return false
	return bool(_arena.debris_enabled)

func set_debris_enabled(value: bool) -> void:
	if _arena == null:
		return
	_arena.debris_enabled = value
	mark_render_dirty("debris")

func dbg(msg: String) -> void:
	if _arena == null:
		return
	if _arena.has_method("dbg"):
		_arena.call("dbg", msg)
		return
	SFLog.debug(msg)

func mark_render_dirty(reason: String = "") -> void:
	if _arena == null:
		return
	if _arena.has_method("mark_render_dirty"):
		_arena.call("mark_render_dirty", reason)

func screen_to_world(screen_pos: Vector2) -> Vector2:
	if _arena == null:
		return Vector2.ZERO
	if _arena.has_method("_screen_to_world"):
		return _arena.call("_screen_to_world", screen_pos)
	return screen_pos

func world_to_map_local(world_pos: Vector2) -> Vector2:
	if _map_root == null:
		_map_root = _resolve_map_root()
	if _map_root == null:
		SFLog.log_once("arena_api_map_root_missing", "ARENA_API: MapRoot missing; using world_pos", SFLog.Level.WARN)
		return world_pos
	return _map_root.to_local(world_pos)

func set_input_handled() -> void:
	if _arena == null:
		return
	var viewport := _arena.get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func get_drag_deadzone_px() -> float:
	if _arena == null:
		return 0.0
	return float(_arena.DRAG_DEADZONE_PX)

func cell_center(cell: Vector2i) -> Vector2:
	return grid_to_world(cell)

func grid_to_world(cell: Vector2i) -> Vector2:
	if _arena == null:
		return Vector2.ZERO
	var spec: GridSpec = _arena.grid_spec
	if spec != null:
		return spec.grid_to_world(cell)
	return _arena._cell_center(cell)

func cell_from_point(local_pos: Vector2) -> Vector2i:
	return world_to_grid(local_pos)

func world_to_grid(local_pos: Vector2) -> Vector2i:
	if _arena == null:
		return Vector2i.ZERO
	var spec: GridSpec = _arena.grid_spec
	if spec != null:
		return spec.world_to_grid(local_pos)
	return _arena._cell_from_point(local_pos)

func is_in_bounds(cell: Vector2i) -> bool:
	if _arena == null:
		return false
	var spec: GridSpec = _arena.grid_spec
	if spec != null:
		return cell.x >= 0 and cell.y >= 0 and cell.x < spec.grid_w and cell.y < spec.grid_h
	return cell.x >= 0 and cell.y >= 0 and cell.x < _arena.grid_w and cell.y < _arena.grid_h

func find_hive_by_id(hive_id: int) -> HiveData:
	var st: GameState = get_state()
	if st == null:
		return null
	return st.find_hive_by_id(hive_id)

func find_lane_by_id(lane_id: int) -> LaneData:
	var st: GameState = get_state()
	if st == null:
		return null
	var lane: Variant = st.find_lane_by_id(lane_id)
	SFLog.info("FIND_LANE_BY_ID", {"lane_id": lane_id, "ok": lane != null})
	return lane

func pick_lane(local_pos: Vector2) -> LaneData:
	if _arena == null:
		return null
	return _arena._pick_lane(local_pos)

func pick_lane_hit(local_pos: Vector2) -> Dictionary:
	if _arena == null:
		return {"ok": false, "lane_id": -1, "t": 0.0}
	return _arena._pick_lane_hit(local_pos)

func pick_lane_world(world_pos: Vector2) -> Dictionary:
	if _arena == null:
		return {"ok": false, "lane_id": -1, "t": 0.0}
	if _arena.has_method("pick_lane_world"):
		return _arena.call("pick_lane_world", world_pos)
	var local_pos: Vector2 = world_to_map_local(world_pos)
	return _arena._pick_lane_hit(local_pos)

func pick_hive_id(world_pos: Vector2) -> int:
	return pick_hive_id_world(world_pos)

func pick_hive_id_local(local_pos: Vector2) -> int:
	var world_pos := local_pos
	if _map_root == null:
		_map_root = _resolve_map_root()
	if _map_root != null:
		world_pos = _map_root.to_global(local_pos)
	return pick_hive_id_world(world_pos)

func get_hive_radius_px() -> float:
	var r := 0.0
	if _arena != null:
		var v: Variant = _arena.get("HIVE_HIT_RADIUS_PX")
		if v != null:
			r = float(v)
	if r <= 0.0 and _arena != null:
		var v2: Variant = _arena.get("HIVE_RADIUS_PX")
		if v2 != null:
			r = float(v2)
	if r <= 0.0:
		r = 18.0
	return r

func get_hive_renderer() -> HiveRenderer:
	if _hive_renderer == null:
		_hive_renderer = _resolve_hive_renderer()
	return _hive_renderer

func get_hive_owner_id(hive_id: int) -> int:
	if _arena == null:
		return -1
	var state: GameState = get_state()
	if state == null:
		return -1
	var hive: HiveData = state.find_hive_by_id(hive_id)
	var owner_id := -1
	var hive_info: Dictionary = {}
	if hive != null:
		owner_id = int(hive.owner_id)
		hive_info = {
			"id": int(hive.id),
			"owner_id": int(hive.owner_id),
			"power": int(hive.power),
			"kind": str(hive.kind),
			"grid_pos": hive.grid_pos
		}
	SFLog.info("OWNER_LOOKUP", {
		"hive_id": hive_id,
		"found_state": hive != null,
		"owner_id": owner_id,
		"hive": hive_info,
		"state_iid": state.get_instance_id(),
		"hives_count": state.hives.size()
	})
	return owner_id

func pick_hive_id_world(world_pos: Vector2) -> int:
	if _arena == null:
		return -1
	var world: World2D = _arena.get_world_2d()
	if world == null:
		return -1
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return -1
	var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hits: Array = space.intersect_point(params, 16)
	if hits.is_empty():
		SFLog.info("PICK_MISS", {"world": world_pos})
		return -1
	var best_id := -1
	var best_d := INF
	for h in hits:
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var col: Object = h.get("collider", null)
		if col == null:
			continue
		if not (col is Node):
			continue
		var n: Node = col
		var cur: Node = n
		var hive_node: Node = null
		while cur != null:
			if cur.is_in_group("hive_pick"):
				hive_node = cur
				break
			cur = cur.get_parent()
		if hive_node == null:
			continue
		var hid := -1
		if hive_node.has_meta("hive_id"):
			hid = int(hive_node.get_meta("hive_id"))
		elif hive_node.has_method("get_hive_id"):
			hid = int(hive_node.call("get_hive_id"))
		elif "hive_id" in hive_node:
			hid = int(hive_node.get("hive_id"))
		elif hive_node.name.begins_with("HiveNode_"):
			var suffix := hive_node.name.substr("HiveNode_".length())
			if suffix.is_valid_int():
				hid = int(suffix)
		if hid <= 0:
			continue
		var p := world_pos
		if hive_node is Node2D:
			p = (hive_node as Node2D).global_position
		var d := world_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best_id = hid
	if best_id <= 0:
		SFLog.info("PICK_MISS", {"world": world_pos, "note": "hit_non_hive"})
		return -1
	SFLog.info("PICK_HIT", {"world": world_pos, "hid": best_id, "dist": best_d})
	return best_id

func get_nearest_hive_local(local_pos: Vector2) -> Dictionary:
	var nearest := _nearest_hive_local(local_pos)
	var best_id: int = int(nearest.get("id", -1))
	var best_d: float = float(nearest.get("dist", INF))
	if best_id <= 0 or best_d == INF:
		return {"id": -1, "dist": -1.0, "center": Vector2.INF}
	return {"id": best_id, "dist": best_d, "center": nearest.get("center", Vector2.INF)}

func _nearest_hive_local(local_pos: Vector2) -> Dictionary:
	var hr := get_hive_renderer()
	if hr == null:
		return {"id": -1, "dist": INF, "center": Vector2.INF}
	var best_id := -1
	var best_d := INF
	var best_center := Vector2.INF
	for hid in hr.get_hive_ids():
		var c: Vector2 = hr.get_hive_center_local(hid)
		if c == Vector2.INF:
			continue
		var d := c.distance_to(local_pos)
		if d < best_d:
			best_d = d
			best_id = int(hid)
			best_center = c
	return {"id": best_id, "dist": best_d, "center": best_center}

func _resolve_map_root() -> Node2D:
	if _arena == null:
		return null
	var node := _arena.get_node_or_null("MapRoot")
	if node is Node2D:
		return node
	return null

func _resolve_hive_renderer() -> HiveRenderer:
	if _arena == null:
		return null
	var map_root := _resolve_map_root()
	if map_root == null:
		return null
	var node := map_root.get_node_or_null("HiveRenderer")
	if node is HiveRenderer:
		return node
	return null

func lane_mode(a: HiveData, b: HiveData) -> String:
	if _arena == null:
		return ""
	return _arena._lane_mode(a, b)

func lane_exists_between(a_id: int, b_id: int) -> bool:
	var st: GameState = get_state()
	if st == null:
		return false
	return st.lane_exists_between(a_id, b_id)

func lane_index_between(a_id: int, b_id: int) -> int:
	var st: GameState = get_state()
	if st == null:
		return -1
	return st.lane_index_between(a_id, b_id)

func intent_is_on(from_id: int, to_id: int) -> bool:
	var st: GameState = get_state()
	if st == null:
		return false
	return st.intent_is_on(from_id, to_id)

func is_outgoing_lane_active(from_id: int, to_id: int) -> bool:
	var st: GameState = get_state()
	if st == null:
		return false
	return st.is_outgoing_lane_active(from_id, to_id)

func hive_id_at_point(local_pos: Vector2) -> int:
	if _arena == null:
		return -1
	return _arena._hive_id_at_point(local_pos)

func barracks_id_at_point(local_pos: Vector2) -> int:
	if _arena == null:
		return -1
	return _arena._barracks_id_at_point(local_pos)

func barracks_by_id(barracks_id: int) -> Dictionary:
	if _arena == null:
		return {}
	return _arena._barracks_by_id(barracks_id)

func get_barracks_select_id() -> int:
	if _arena == null:
		return -1
	return int(_arena.barracks_select_id)

func set_barracks_select_id(value: int) -> void:
	if _arena == null:
		return
	_arena.barracks_select_id = value

func get_barracks_select_pid() -> int:
	if _arena == null:
		return -1
	return int(_arena.barracks_select_pid)

func set_barracks_select_pid(value: int) -> void:
	if _arena == null:
		return
	_arena.barracks_select_pid = value

func get_barracks_select_targets() -> Array:
	if _arena == null:
		return []
	return _arena.barracks_select_targets

func set_barracks_select_targets(value: Array) -> void:
	if _arena == null:
		return
	_arena.barracks_select_targets = value.duplicate()

func clear_barracks_select_targets() -> void:
	if _arena == null:
		return
	_arena.barracks_select_targets.clear()

func get_barracks_select_changed() -> bool:
	if _arena == null:
		return false
	return bool(_arena.barracks_select_changed)

func set_barracks_select_changed(value: bool) -> void:
	if _arena == null:
		return
	_arena.barracks_select_changed = value

func apply_intent_pair(start_id: int, end_id: int) -> void:
	if _arena == null:
		return
	_arena._apply_intent_pair(start_id, end_id)
	mark_render_dirty("intent")

func request_intent_feed(src_id: int, dst_id: int) -> bool:
	var ok := OpsState.request_intent_feed(src_id, dst_id)
	if ok:
		mark_render_dirty("intent_feed")
	return ok

func request_intent_attack(src_id: int, dst_id: int) -> bool:
	var ok := OpsState.request_intent_attack(src_id, dst_id)
	if ok:
		mark_render_dirty("intent_attack")
	return ok

func request_barracks_route(barracks_id: int, route_hive_ids: Array, player_id: int = -1) -> bool:
	var ok: bool = OpsState.request_barracks_route(barracks_id, route_hive_ids, player_id)
	if ok:
		mark_render_dirty("barracks_route")
	return ok

func apply_dev_intent(from_id: int, to_id: int, dev_pid: int) -> void:
	if _arena == null:
		return
	_arena._apply_dev_intent(from_id, to_id, dev_pid)
	mark_render_dirty("intent_dev")

func try_swarm(from_id: int, to_id: int, pid: int = -1) -> bool:
	var ok: bool = OpsState.try_swarm(from_id, to_id, pid)
	if ok:
		mark_render_dirty("swarm")
	return ok

func retract_lane(from_id: int, to_id: int, owner_id: int) -> void:
	if _arena == null:
		return
	_arena._retract_lane(from_id, to_id, owner_id)
	mark_render_dirty("retract_lane")

func try_activate_buff_slot(pid: int, slot_index: int) -> void:
	if _arena == null:
		return
	_arena._try_activate_buff_slot(pid, slot_index)
	mark_render_dirty("buff")

func issue_command(cmd: Dictionary) -> bool:
	if _arena == null:
		return false
	var cmd_type: String = str(cmd.get("type", ""))
	match cmd_type:
		"intent_pair":
			apply_intent_pair(int(cmd.get("from_id", -1)), int(cmd.get("to_id", -1)))
			return true
		"dev_intent":
			apply_dev_intent(
				int(cmd.get("from_id", -1)),
				int(cmd.get("to_id", -1)),
				int(cmd.get("player_id", -1))
			)
			return true
		"try_swarm":
			return try_swarm(
				int(cmd.get("from_id", -1)),
				int(cmd.get("to_id", -1)),
				int(cmd.get("player_id", -1))
			)
		"retract_lane":
			retract_lane(
				int(cmd.get("from_id", -1)),
				int(cmd.get("to_id", -1)),
				int(cmd.get("player_id", -1))
			)
			return true
		"set_barracks_route":
			var route_ids: Array = []
			var route_v: Variant = cmd.get("route_hive_ids", [])
			if typeof(route_v) == TYPE_ARRAY:
				route_ids = route_v as Array
			return request_barracks_route(
				int(cmd.get("barracks_id", -1)),
				route_ids,
				int(cmd.get("player_id", -1))
			)
	return false
