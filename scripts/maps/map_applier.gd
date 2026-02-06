# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends RefCounted
class_name MapApplier
const SFLog := preload("res://scripts/util/sf_log.gd")

static func apply_map(arena: Node2D, d: Dictionary) -> void:
	SFLog.allow_tag("MAP_APPLIER_RUNTIME_ROSTER_WRITE")
	var map_id := str(d.get("map_id", d.get("_id", d.get("id", "UNKNOWN"))))
	if SFLog.LOGGING_ENABLED:
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
	if _is_dev_runner():
		_dev_seed_lanes_and_spawns(d)

	var p1_uid: String = ProfileManager.get_user_id()
	var roster: Array = [
		{"seat": 1, "uid": p1_uid, "is_local": true, "is_cpu": false, "active": true},
		{"seat": 2, "uid": "", "is_local": false, "is_cpu": true, "active": true},
		{"seat": 3, "uid": "", "is_local": false, "is_cpu": false, "active": false},
		{"seat": 4, "uid": "", "is_local": false, "is_cpu": false, "active": false}
	]
	if _is_runtime_non_dev_context():
		SFLog.warn("MAP_APPLIER_RUNTIME_ROSTER_WRITE", {
			"map_id": map_id,
			"reason": "runtime_direct_roster_assignment"
		})
	OpsState.sim_mutate("MapApplier.apply_map", func() -> void:
		if OpsState.has_method("audit_mutation"):
			OpsState.audit_mutation("MapApplier.apply_map", "match_roster", "res://scripts/maps/map_applier.gd")
		OpsState.match_roster = roster
	)
	SFLog.info("MATCH_ROSTER", {
		"p1_uid": p1_uid,
		"p2_uid": "",
		"p3_uid": "",
		"p4_uid": ""
	})

	var built_state := OpsState.reset_state_from_map(d)
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
	SFLog.info("MAP_APPLIED_STATE", {
		"map_id": map_id,
		"hive_count": built_state.hives.size(),
		"state_iid": built_state.get_instance_id()
	})
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

static func _is_runtime_non_dev_context() -> bool:
	if Engine.is_editor_hint():
		return false
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return true
	var tree := loop as SceneTree
	return tree.get_root().get_node_or_null("DevMapRunner") == null

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
