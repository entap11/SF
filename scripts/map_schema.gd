extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchemaV1 := preload("res://scripts/maps/map_schema.gd")

const SCHEMA_ID := "swarmfront.map.v1.xy"
const CANON_GRID_W := 8
const CANON_GRID_H := 12

const OCCLUSION_RADIUS_MAX := 0.45
const OCCLUSION_EPS := 0.0001
const DEFAULT_SYMMETRY_MODE := "mirror_x"

static func owner_to_owner_id(owner: String) -> int:
	var normalized := owner.strip_edges().to_upper()
	match normalized:
		"P1":
			return 1
		"P2":
			return 2
		"P3":
			return 3
		"P4":
			return 4
		"NEUTRAL", "NPC", "":
			return 0
		_:
			if normalized.is_valid_int():
				return int(normalized)
			return 0

static func _default_owner_for_grid_pos(gx: float, gy: float) -> int:
	# Dev-safe fallback owner assignment:
	# Left half = P1, Right half = P2 (for now).
	# CANON grid is 8x12, x in [0..7]. Midline at 3.5.
	# If you later want 4 players: split by y too.
	if gx <= 3.5:
		return 1
	return 2

# NOTE: Keep this function parse-valid even if you haven't finished it.
# Fill in later as needed.
static func _adapt_v1_xy_to_internal(human: Dictionary) -> Dictionary:
	var adapted := MapSchemaV1._adapt_v1_xy_to_internal(human)
	if typeof(adapted) != TYPE_DICTIONARY:
		return adapted
	if not bool(adapted.get("ok", false)):
		return adapted
	var data: Dictionary = adapted.get("data", {})
	var out_hives: Array = data.get("hives", [])
	for i in range(out_hives.size()):
		if typeof(out_hives[i]) != TYPE_DICTIONARY:
			continue
		var h: Dictionary = out_hives[i]
		var gx := float(h.get("x", 0.0))
		var gy := float(h.get("y", 0.0))
		if h.has("grid_pos") and typeof(h["grid_pos"]) == TYPE_ARRAY:
			var gp: Array = h["grid_pos"] as Array
			if gp.size() >= 2:
				gx = float(gp[0])
				gy = float(gp[1])
		var owner_id: int = 0
		if h.has("owner_id"):
			owner_id = int(h.get("owner_id", 0))
		elif h.has("owner"):
			owner_id = owner_to_owner_id(str(h.get("owner", "")))
		if owner_id <= 0:
			owner_id = _default_owner_for_grid_pos(gx, gy)
		h["owner_id"] = owner_id
		out_hives[i] = h
	data["hives"] = out_hives
	adapted["data"] = data
	return adapted
