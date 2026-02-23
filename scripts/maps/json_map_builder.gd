extends RefCounted
class_name JsonMapBuilder
const SFLog = preload("res://scripts/util/sf_log.gd")

const DEFAULT_CELL: float = 64.0

# Minimal, visibility-first builder:
# - loads a JSON map
# - clears old map geometry (keeps renderers)
# - draws debug hives + lanes so we SEE something, even if renderers are not wired yet
func build_into(arena: Node, map_id: String, cell_size: float = DEFAULT_CELL) -> bool:
	if arena == null:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: arena is null")
		return false

	var map_root: Node = arena.get_node_or_null("MapRoot")
	if map_root == null:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: Arena missing child 'MapRoot'")
		return false

	var data: Variant = _load_json(map_id)
	if data == null:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: failed to load json: %s" % map_id)
		return false

	_clear_map_geometry(map_root)

	# Try a few common shapes. We only need "hives" + "lanes" to prove load.
	var hives: Array = []
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("hives"):
			hives = data["hives"]
		elif data.has("nodes"):
			hives = data["nodes"] # some schemas call them nodes
	if typeof(hives) != TYPE_ARRAY:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: no 'hives' (or 'nodes') array in %s" % map_id)
		return false

	var hive_pos: Dictionary = {} # id -> Vector2 (px)
	for i in range(hives.size()):
		var h: Dictionary = hives[i]
		if typeof(h) != TYPE_DICTIONARY:
			continue
		var id: String = str(h.get("id", i))
		var x: float = float(h.get("x", h.get("gx", 0)))
		var y: float = float(h.get("y", h.get("gy", 0)))

		# If your JSON is already pixel coords, set "units":"px" in the future.
		# For now we assume grid coords -> px via cell_size.
		var p: Vector2 = Vector2(x * cell_size, y * cell_size)
		hive_pos[id] = p

		var dot: DebugDot = DebugDot.new()
		dot.name = "DBG_HIVE_%s" % id
		dot.position = p
		map_root.add_child(dot)

	# Lanes / edges
	var lanes: Array = []
	if typeof(data) == TYPE_DICTIONARY:
		if data.has("lanes"):
			lanes = data["lanes"]
		elif data.has("edges"):
			lanes = data["edges"]
	if typeof(lanes) == TYPE_ARRAY:
		for e in lanes:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var a: String = str(e.get("a", e.get("from", "")))
			var b: String = str(e.get("b", e.get("to", "")))
			if not hive_pos.has(a) or not hive_pos.has(b):
				continue
			var line: Line2D = Line2D.new()
			line.name = "DBG_LANE_%s_%s" % [a, b]
			line.width = 3.0
			line.add_point(hive_pos[a])
			line.add_point(hive_pos[b])
			map_root.add_child(line)

	if SFLog.LOGGING_ENABLED:
		print("JsonMapBuilder: built %d hives, %d lanes from %s" % [hive_pos.size(), lanes.size(), map_id])
	return true


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: file not found: %s" % path)
		return null
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: cannot open: %s" % path)
		return null
	var txt: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		if SFLog.LOGGING_ENABLED:
			push_error("JsonMapBuilder: JSON.parse_string failed: %s" % path)
	return parsed


func _clear_map_geometry(map_root: Node) -> void:
	# Keep renderers if they exist; remove prior debug geometry / prior builds.
	for c: Node in map_root.get_children():
		if c.name == "HiveRenderer" or c.name == "LaneRenderer":
			continue
		c.queue_free()


# Tiny debug node that draws a visible hive dot.
class DebugDot:
	extends Node2D

	const R: float = 10.0

	func _draw() -> void:
		# default white dot + black outline for visibility on any background
		draw_circle(Vector2.ZERO, R, Color(1, 1, 1, 1))
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 32, Color(0, 0, 0, 1), 2.0)

	func _ready() -> void:
		queue_redraw()
