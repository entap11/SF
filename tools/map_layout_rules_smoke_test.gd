extends SceneTree

const NO_UPPER_LEFT_CORNER_VARIANTS := [
	"res://maps/_future/closequarters/MAP_closequarters__CQ2__1p.json",
	"res://maps/_future/closequarters/MAP_closequarters__CQ2__4p.json",
	"res://maps/_future/closequarters/MAP_closequarters__CQ3__1p.json",
	"res://maps/_future/closequarters/MAP_closequarters__CQ3__4p.json"
]

const NO_WALL_MIDLINE_VARIANTS := [
	"res://maps/_future/closequarters/MAP_closequarters__CQ3__1p.json",
	"res://maps/_future/closequarters/MAP_closequarters__CQ3__4p.json",
	"res://maps/_future/centerstrike/MAP_centerstrike__CS3__1p.json",
	"res://maps/_future/centerstrike/MAP_centerstrike__CS3__4p.json"
]

const QUADFIGHT_VARIANTS := [
	"res://maps/_future/quadfight/MAP_quadfight__SBASE__1p.json",
	"res://maps/_future/quadfight/MAP_quadfight__SBASE__4p.json"
]

const QUADFIGHT_CITY_STATE_POSITIONS := {
	"tl_outer": Vector2(6.0, 1.0),
	"tl_lower": Vector2(1.0, 7.0),
	"tl_inner": Vector2(6.0, 7.0),
	"tr_outer": Vector2(12.0, 1.0),
	"tr_lower": Vector2(17.0, 7.0),
	"tr_inner": Vector2(12.0, 7.0),
	"bl_upper": Vector2(1.0, 21.0),
	"bl_inner": Vector2(6.0, 21.0),
	"bl_outer": Vector2(6.0, 27.0),
	"br_inner": Vector2(12.0, 21.0),
	"br_upper": Vector2(17.0, 21.0),
	"br_outer": Vector2(12.0, 27.0)
}

func _init() -> void:
	for path in NO_UPPER_LEFT_CORNER_VARIANTS:
		var data: Dictionary = _load_map(path)
		if data.is_empty():
			return
		if _has_hive_at(data, 0.0, 0.0):
			_fail("%s should not keep the unfair upper-left corner hive" % path)
			return
	for path in NO_WALL_MIDLINE_VARIANTS:
		var data: Dictionary = _load_map(path)
		if data.is_empty():
			return
		var grid: Dictionary = data.get("grid", {}) as Dictionary
		var grid_w: float = float(grid.get("w", 18.0))
		var mid_y: float = float(grid.get("h", 28.0)) * 0.5
		for node_any in data.get("nodes", []) as Array:
			if typeof(node_any) != TYPE_DICTIONARY:
				continue
			var node: Dictionary = node_any as Dictionary
			if str(node.get("kind", "")).to_lower() != "hive":
				continue
			var pos: Dictionary = node.get("pos", {}) as Dictionary
			var x: float = float(pos.get("x", INF))
			var y: float = float(pos.get("y", INF))
			if is_equal_approx(y, mid_y) and (x <= 1.0 or x >= grid_w - 1.0):
				_fail("%s should not keep wall-adjacent middle-line hive %s at (%s,%s)" % [
					path,
					str(node.get("id", "")),
					str(x),
					str(y)
				])
				return
	for path in QUADFIGHT_VARIANTS:
		var data: Dictionary = _load_map(path)
		if data.is_empty():
			return
		var positions: Dictionary = _hive_positions_by_id(data)
		for hive_id_any in QUADFIGHT_CITY_STATE_POSITIONS.keys():
			var hive_id: String = str(hive_id_any)
			if not positions.has(hive_id):
				_fail("%s is missing Quad Fight city-state hive %s" % [path, hive_id])
				return
			var actual: Vector2 = positions[hive_id] as Vector2
			var expected: Vector2 = QUADFIGHT_CITY_STATE_POSITIONS[hive_id] as Vector2
			if not actual.is_equal_approx(expected):
				_fail("%s has Quad Fight hive %s at %s, expected %s" % [
					path,
					hive_id,
					str(actual),
					str(expected)
				])
				return
	print("MAP_LAYOUT_RULES_SMOKE: PASS")
	quit(0)

func _load_map(path: String) -> Dictionary:
	var source: String = FileAccess.get_file_as_string(path)
	if source.is_empty():
		_fail("%s missing or empty" % path)
		return {}
	var parsed: Variant = JSON.parse_string(source)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("%s is not valid JSON object" % path)
		return {}
	return parsed as Dictionary

func _has_hive_at(data: Dictionary, x: float, y: float) -> bool:
	for node_any in data.get("nodes", []) as Array:
		if typeof(node_any) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_any as Dictionary
		if str(node.get("kind", "")).to_lower() != "hive":
			continue
		var pos: Dictionary = node.get("pos", {}) as Dictionary
		if is_equal_approx(float(pos.get("x", INF)), x) and is_equal_approx(float(pos.get("y", INF)), y):
			return true
	return false

func _hive_positions_by_id(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for node_any in data.get("nodes", []) as Array:
		if typeof(node_any) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_any as Dictionary
		if str(node.get("kind", "")).to_lower() != "hive":
			continue
		var pos: Dictionary = node.get("pos", {}) as Dictionary
		out[str(node.get("id", ""))] = Vector2(float(pos.get("x", INF)), float(pos.get("y", INF)))
	return out

func _fail(message: String) -> void:
	push_error("MAP_LAYOUT_RULES_SMOKE: %s" % message)
	quit(1)
