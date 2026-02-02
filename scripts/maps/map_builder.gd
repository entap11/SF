extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const CELL_SIZE := 64.0

# Minimal, visibility-first builder:
# - loads a JSON map
# - clears old map geometry (keeps renderers)
# - draws debug hives + lanes so we SEE something
func build_into(arena: Node2D, map_id: String) -> bool:
	SFLog.trace("MAPBUILDER: build_into map_id=%s stack=%s" % [map_id, str(get_stack())])
	assert(
		map_id.find("MAP_TEST_8x12") != -1
		or map_id.find("MAP_SKETCH_SYM_8x12") != -1
	)
	if arena == null:
		SFLog.trace("MAP_BUILDER: arena is null")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: arena is null")
		return false

	var map_root: Node = arena.get_node_or_null("MapRoot")
	if map_root == null:
		SFLog.trace("MAP_BUILDER: map_root is null")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: Arena missing child 'MapRoot'")
		return false
	var hive_parent := map_root.get_node_or_null("HiveRenderer")
	var lane_parent := map_root.get_node_or_null("LaneRenderer")
	if hive_parent == null:
		hive_parent = map_root
	if lane_parent == null:
		lane_parent = map_root
	SFLog.trace("MAPBUILDER: parents hive_parent=%s lane_parent=%s" % [hive_parent.name, lane_parent.name])

	var path := MAP_SCHEMA.normalize_path(map_id)
	var data: Variant = _load_json(path)
	if data == null:
		SFLog.trace("MAP_BUILDER: data == null after _load_json path=%s" % path)
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: failed to load json: %s" % path)
		return false

	if typeof(data) != TYPE_DICTIONARY:
		SFLog.trace("MAP_BUILDER: json root is not a Dictionary type=%s path=%s" % [str(typeof(data)), path])
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: json root is not a Dictionary: %s" % path)
		return false

	var dict: Dictionary = data
	var grid_w_val := int(dict.get("grid_width", dict.get("width", 0)))
	var grid_h_val := int(dict.get("grid_height", dict.get("height", 0)))
	assert(grid_w_val == MAP_SCHEMA.CANON_GRID_W)
	assert(grid_h_val == MAP_SCHEMA.CANON_GRID_H)
	SFLog.trace("MAP_BUILDER: keys=%s" % [str(dict.keys())])
	for k in ["hives", "nodes", "lanes", "edges", "entities", "points", "links"]:
		if dict.has(k):
			var v: Variant = dict[k]
			var size: int = -1
			if typeof(v) == TYPE_ARRAY:
				size = (v as Array).size()
			SFLog.trace("MAP_BUILDER: has %s type=%s size=%s" % [k, str(typeof(v)), str(size)])

	var hr := arena.get_node_or_null("MapRoot/HiveRenderer")
	var lr := arena.get_node_or_null("MapRoot/LaneRenderer")
	if hr != null and hr.has_method("set_model"):
		hr.call("set_model", dict)
	if lr != null and lr.has_method("set_model"):
		lr.call("set_model", dict)
	if lr != null and hr != null and lr.has_method("set_hive_nodes") and hr.has_method("get_hive_nodes_by_id"):
		lr.call("set_hive_nodes", hr.call("get_hive_nodes_by_id"))
	if arena.has_method("set_model"):
		arena.call("set_model", dict)
	var hives_for_log: Array = dict.get("hives", dict.get("nodes", []))
	var lanes_for_log: Array = dict.get("lanes", dict.get("edges", []))
	SFLog.trace("RENDER MODEL SET: hives=%s lanes=%s" % [str(hives_for_log.size()), str(lanes_for_log.size())])
	var arena_model: Variant = arena.get("model")
	SFLog.trace("ARENA MODEL TYPE: %s" % [str(typeof(arena_model))])
	if typeof(arena_model) == TYPE_DICTIONARY:
		SFLog.trace("ARENA MODEL KEYS: %s" % [str((arena_model as Dictionary).keys())])
		SFLog.trace("ARENA HIVES COUNT: %s NODES COUNT: %s" % [
			str((arena_model.get("hives", []) as Array).size()),
			str((arena_model.get("nodes", []) as Array).size())
		])
	SFLog.trace("ARENA render_version: %s" % [str(arena.get("render_version"))])

	_clear_map_geometry(map_root)

	# HARD DEBUG: prove drawing works even if JSON parsing/schema fails
	var test := DebugDot.new()
	test.name = "DBG_FORCED_DOT"
	test.position = Vector2(256, 384)
	hive_parent.add_child(test)
	SFLog.trace("MAP_BUILDER: forced debug dot added at (256,384)")
	SFLog.trace("MAP_BUILDER: HR vis=%s LR vis=%s MapRoot vis=%s" % [
		str(hive_parent.visible),
		str(lane_parent.visible),
		str(map_root.visible)
	])

	var hives: Array = []
	if dict.has("hives"):
		hives = dict.get("hives", [])
	elif dict.has("nodes"):
		hives = dict.get("nodes", [])
	if typeof(hives) != TYPE_ARRAY:
		SFLog.trace("MAP_BUILDER: hives not array type=%s" % [str(typeof(hives))])
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: no 'hives' (or 'nodes') array in %s" % path)
		return false

	var hive_pos: Dictionary = {} # id -> Vector2 (px)
	for i in range(hives.size()):
		var h: Variant = hives[i]
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var hd: Dictionary = h
		var id := str(hd.get("id", i))
		var x := float(hd.get("x", hd.get("gx", 0)))
		var y := float(hd.get("y", hd.get("gy", 0)))
		if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = hd["grid_pos"]
			if gp.size() >= 2:
				x = float(gp[0])
				y = float(gp[1])
		var p := Vector2((x + 0.5) * CELL_SIZE, (y + 0.5) * CELL_SIZE)
		hive_pos[id] = p

		var dot := DebugDot.new()
		dot.name = "DBG_HIVE_%s" % id
		dot.position = p
		hive_parent.add_child(dot)
		SFLog.trace("HIVE POS px=%s" % [str(dot.position)])
		if i == 0:
			SFLog.trace("HIVE0 placed at px=%s" % [str(dot.position)])

	var lanes: Array = []
	if dict.has("lanes"):
		lanes = dict.get("lanes", [])
	elif dict.has("edges"):
		lanes = dict.get("edges", [])
	if typeof(lanes) == TYPE_ARRAY:
		for e in lanes:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var ed: Dictionary = e
			var a := str(ed.get("a", ed.get("from", "")))
			var b := str(ed.get("b", ed.get("to", "")))
			if not hive_pos.has(a) or not hive_pos.has(b):
				continue
			var line := Line2D.new()
			line.name = "DBG_LANE_%s_%s" % [a, b]
			line.width = 3.0
			line.default_color = Color(0.9, 0.9, 0.9, 0.9)
			line.add_point(hive_pos[a])
			line.add_point(hive_pos[b])
			lane_parent.add_child(line)

	SFLog.trace("MAP_BUILDER: hives=%s lanes=%s maproot_children=%s" % [
		str(hive_pos.size()),
		str(lanes.size()),
		str(map_root.get_child_count())
	])
	SFLog.trace("MAPBUILDER: map_root children=%s hive_parent children=%s lane_parent children=%s" % [
		str(map_root.get_child_count()),
		str(hive_parent.get_child_count()),
		str(lane_parent.get_child_count())
	])
	SFLog.info("BUILD_SUMMARY: nodes=%d lanes=%d towers=%d barracks=%d spawns=%d" % [
		hive_pos.size(),
		lanes.size(),
		0,
		0,
		0
	])
	return true


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: file not found: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: cannot open: %s" % path)
		return null
	var txt := f.get_as_text()
	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER: JSON.parse failed (%s) %s" % [err, path])
		return null
	var parsed: Variant = json.data
	return parsed


func _clear_map_geometry(map_root: Node) -> void:
	# Keep renderers if they exist; remove prior debug geometry / prior builds.
	for c in map_root.get_children():
		if c.name == "HiveRenderer" or c.name == "LaneRenderer":
			continue
		c.queue_free()


# Tiny debug node that draws a visible hive dot.
class DebugDot:
	extends Node2D

	const R := 10.0

	func _draw() -> void:
		# default white dot + black outline for visibility on any background
		draw_circle(Vector2.ZERO, R, Color(1, 1, 1, 1))
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 32, Color(0, 0, 0, 1), 2.0)

	func _ready() -> void:
		queue_redraw()
