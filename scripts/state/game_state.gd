# NOTE: GameState is a pure data container. Match outcome/clock authority lives in OpsState.
# NOTE: Rate-limit lane length debug logs to prevent per-tick spam.
class_name GameState
extends RefCounted

const START_POWER := 10

const SFLog := preload("res://scripts/util/sf_log.gd")
const MapSchema := preload("res://scripts/maps/map_schema.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")

const HIVE_DIAMETER_PX := 36.0
const HIVE_RADIUS_PX := HIVE_DIAMETER_PX * 0.5
const HIVE_LANE_RADIUS_PX := 18.0
const HIVE_BLOCK_RADIUS_PX := HIVE_RADIUS_PX
const LANE_TRAVEL_SPEED_PX_S := 160.0
const LANE_LEN_LOG_INTERVAL_MS := 1000
const SPAWN_BLOCK_LOG_INTERVAL_MS := 1000
const DEFAULT_CELL_SIZE := 64.0
const MATCH_DURATION_MS := 300000
const DEFAULT_UNINTENDED_POWER_PER_SEC := 1.0
const PASSIVE_CHILL_MS := 3000
const PASSIVE_MS_PER_POWER: float = 3000.0
const AUTH_FENCE_LOG_INTERVAL_MS := 1000
const AUTH_FENCE_ALLOWED_PREFIXES := [
	"res://scripts/systems/",
	"res://scripts/sim/",
	"res://scripts/ops/",
	"res://scripts/maps/map_applier.gd"
]

enum GameOutcome {
	NONE,
	WIN_P1,
	WIN_P2,
	DRAW
}

var hives: Array[HiveData] = []
var lanes: Array = [] # Array[LaneData] (kept untyped for compatibility)
var map_lanes: Array = []
var lane_candidates: Array = []
var selection: SelectionState = null
var grid_spec: Object = null

var outgoing_by_hive: Dictionary = {}
var spawns: Array = []
var swarm_requests: Array = []
var swarm_packets: Array = []
var lane_retract_requests: Array = []
var units_set_version: int = 0
var hives_set_version: int = 0

# Optional lane sim state (v2+)
var lane_sim_by_key: Dictionary = {}
var units_by_lane: Dictionary = {}
var structure_by_node_id: Dictionary = {}
var structure_owner_by_node_id: Dictionary = {}
var tower_owner_by_node_id: Dictionary = {}
var towers: Array = []
var barracks: Array = []
var unit_system: UnitSystem = null
var _arrival_q: Dictionary = {}
var _sim_time_us: int = 0
var hive_spawn_block_until_us: Dictionary = {}
var tick: int = 0
var _unintended_power_accum_by_hive: Dictionary = {}
var _passive_accum_ms: float = 0.0
var _passive_config_logged: bool = false
var _outgoing_sample_log_ms: int = 0

# Indexes
var hive_by_id: Dictionary = {}
var lane_index_by_key: Dictionary = {}
var _hive_index_count: int = 0
var _lane_index_count: int = 0
var _last_hives_set_count: int = -1
var _last_hives_set_sig: int = 0

# Debug
var _lane_dump_accum_ms: float = 0.0
var debug_lane_len_log: bool = false
var _last_lane_len_log_ms: int = 0
var _last_spawn_block_log_ms: Dictionary = {}
var _last_spawn_block_reason: Dictionary = {}
var _lane_spawn_disabled_logged: bool = false
var auth_fence_assert_enabled: bool = false
var _auth_fence_last_ms: Dictionary = {}

# -------------------------------------------------------------------
# Init
# -------------------------------------------------------------------

func _init() -> void:
	tower_owner_by_node_id = structure_owner_by_node_id

# -------------------------------------------------------------------
# Init / reset
# -------------------------------------------------------------------

func init_demo_data() -> void:
	init_core_defaults()
	init_demo_map()
	rebuild_indexes()

func init_core_defaults() -> void:
	reset_map_only()

func init_players_only() -> void:
	reset_map_only()

func init_demo_map() -> void:
	hives = [
		HiveData.new(1, Vector2i(1, 2), 1, START_POWER, "Hive"),
		HiveData.new(2, Vector2i(3, 5), 1, START_POWER, "Hive"),
		HiveData.new(3, Vector2i(6, 3), 0, START_POWER, "Hive"),
		HiveData.new(4, Vector2i(8, 1), 2, START_POWER, "Hive"),
		HiveData.new(5, Vector2i(10, 6), 3, START_POWER, "Hive"),
		HiveData.new(6, Vector2i(7, 6), 4, START_POWER, "Hive")
	]
	lanes = [
		LaneData.new(1, 1, 2, 1, true, false),
		LaneData.new(2, 2, 3, 1, true, false),
		LaneData.new(3, 3, 4, -1, false, true),
		LaneData.new(4, 2, 4, 1, true, true),
		LaneData.new(5, 4, 5, 1, true, true),
		LaneData.new(6, 5, 6, 1, true, true),
		LaneData.new(7, 1, 6, -1, false, true),
		LaneData.new(8, 4, 6, 1, true, false)
	]

func reset_map_only() -> void:
	hives = []
	lanes = []
	map_lanes = []
	lane_candidates = []
	selection = SelectionState.new()
	outgoing_by_hive.clear()
	spawns = []
	swarm_requests = []
	swarm_packets = []
	lane_retract_requests = []
	lane_sim_by_key.clear()
	units_by_lane.clear()
	structure_by_node_id.clear()
	structure_owner_by_node_id.clear()
	tower_owner_by_node_id = structure_owner_by_node_id
	towers = []
	barracks = []
	_arrival_q.clear()
	_sim_time_us = 0
	hive_spawn_block_until_us.clear()
	_lane_spawn_disabled_logged = false
	tick = 0
	_unintended_power_accum_by_hive.clear()
	_passive_accum_ms = 0.0
	_passive_config_logged = false
	_outgoing_sample_log_ms = 0
	units_set_version = 0
	_last_hives_set_count = -1
	_last_hives_set_sig = 0
	rebuild_indexes()

# -------------------------------------------------------------------
# Map load
# -------------------------------------------------------------------

func load_from_map_dict(map: Dictionary) -> void:
	reset_map_only()

	var hives_v: Variant = map.get("hives", [])
	if typeof(hives_v) == TYPE_ARRAY:
		var hives_arr: Array = hives_v as Array
		for hive_v in hives_arr:
			if typeof(hive_v) != TYPE_DICTIONARY:
				continue
			var hd: Dictionary = hive_v as Dictionary

			var id_v: Variant = hd.get("id", 0)
			var hive_id: int = 0
			if id_v is int:
				hive_id = int(id_v)
			else:
				var id_str: String = str(id_v)
				if id_str.is_valid_int():
					hive_id = int(id_str)
			if hive_id <= 0:
				continue

			var gx: int = int(hd.get("x", 0))
			var gy: int = int(hd.get("y", 0))
			if hd.has("grid_pos") and typeof(hd["grid_pos"]) == TYPE_ARRAY:
				var gp: Array = hd["grid_pos"] as Array
				if gp.size() >= 2:
					gx = int(gp[0])
					gy = int(gp[1])

			var owner_id: int = 0
			if hd.has("owner_id"):
				owner_id = int(hd.get("owner_id", 0))
			elif hd.has("owner"):
				owner_id = MapSchema.owner_to_owner_id(str(hd.get("owner", "")))

			var power: int = int(hd.get("pwr", hd.get("power", 0)))
			var kind: String = str(hd.get("kind", "Hive"))

			hives.append(HiveData.new(hive_id, Vector2i(gx, gy), owner_id, power, kind))

	var lanes_v: Variant = map.get("lanes", [])
	if typeof(lanes_v) == TYPE_ARRAY:
		var lanes_arr: Array = lanes_v as Array
		var lane_id := 1
		for lane_v in lanes_arr:
			if typeof(lane_v) != TYPE_DICTIONARY:
				continue
			var ld: Dictionary = lane_v as Dictionary

			var a_v: Variant = ld.get("a_id", ld.get("from", ld.get("from_hive", 0)))
			var b_v: Variant = ld.get("b_id", ld.get("to", ld.get("to_hive", 0)))

			var a_id: int = 0
			var b_id: int = 0

			if a_v is int:
				a_id = int(a_v)
			else:
				var a_str: String = str(a_v)
				if a_str.is_valid_int():
					a_id = int(a_str)

			if b_v is int:
				b_id = int(b_v)
			else:
				var b_str: String = str(b_v)
				if b_str.is_valid_int():
					b_id = int(b_str)

			if a_id <= 0 or b_id <= 0 or a_id == b_id:
				continue

			lanes.append(LaneData.new(lane_id, a_id, b_id, 1, false, false))
			lane_id += 1

	# Snapshot map lanes (stable IDs for “original layout”)
	var map_lanes_out: Array = []
	for i in range(lanes.size()):
		var lane: Variant = lanes[i]
		var lane_id_out := -1
		var a_id_out := -1
		var b_id_out := -1

		if lane is LaneData:
			var ld := lane as LaneData
			lane_id_out = int(ld.id)
			a_id_out = int(ld.a_id)
			b_id_out = int(ld.b_id)
		elif lane is Dictionary:
			var d := lane as Dictionary
			lane_id_out = int(d.get("lane_id", d.get("id", -1)))
			a_id_out = int(d.get("a_id", -1))
			b_id_out = int(d.get("b_id", -1))

		if a_id_out <= 0 or b_id_out <= 0:
			continue

		map_lanes_out.append({
			"lane_id": lane_id_out,
			"a_id": a_id_out,
			"b_id": b_id_out
		})

	map_lanes = map_lanes_out

	var candidates_v: Variant = map.get("lane_candidates", [])
	if typeof(candidates_v) == TYPE_ARRAY:
		lane_candidates = candidates_v as Array

	var spawns_v: Variant = map.get("spawns", [])
	if typeof(spawns_v) == TYPE_ARRAY:
		spawns = (spawns_v as Array).duplicate(true)

	var towers_out: Array = []
	var towers_v: Variant = map.get("towers", [])
	if typeof(towers_v) == TYPE_ARRAY:
		for tower_any in towers_v as Array:
			if typeof(tower_any) != TYPE_DICTIONARY:
				continue
			var td: Dictionary = tower_any as Dictionary
			var tower_id: int = int(td.get("id", -1))
			if tower_id <= 0:
				continue
			var gp: Vector2i = Vector2i.ZERO
			var gp_v: Variant = td.get("grid_pos", null)
			if gp_v is Vector2i:
				gp = gp_v as Vector2i
			elif gp_v is Array:
				var gp_arr: Array = gp_v as Array
				if gp_arr.size() >= 2:
					gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
			else:
				var x: int = int(td.get("x", 0))
				var y: int = int(td.get("y", 0))
				gp = Vector2i(x, y)
			var req_ids: Array = []
			var req_v: Variant = td.get("required_hive_ids", [])
			if typeof(req_v) == TYPE_ARRAY:
				for req_any in req_v as Array:
					req_ids.append(int(req_any))
			var control_ids: Array = []
			var control_v: Variant = td.get("control_hive_ids", [])
			if typeof(control_v) == TYPE_ARRAY:
				for control_any in control_v as Array:
					control_ids.append(int(control_any))
			towers_out.append({
				"id": tower_id,
				"grid_pos": gp,
				"required_hive_ids": req_ids,
				"control_hive_ids": control_ids,
				"owner_id": int(td.get("owner_id", 0))
			})
	towers = towers_out
	var tower_sample: Variant = towers_out[0] if towers_out.size() > 0 else null
	SFLog.info("STATE_TOWERS_SET", {"count": towers_out.size(), "sample": tower_sample})

	var barracks_out: Array = []
	var barracks_v: Variant = map.get("barracks", [])
	if typeof(barracks_v) == TYPE_ARRAY:
		for barracks_any in barracks_v as Array:
			if typeof(barracks_any) != TYPE_DICTIONARY:
				continue
			var bd: Dictionary = barracks_any as Dictionary
			var barracks_id: int = int(bd.get("id", -1))
			if barracks_id <= 0:
				continue
			var gp_b: Vector2i = Vector2i.ZERO
			var gp_b_v: Variant = bd.get("grid_pos", null)
			if gp_b_v is Vector2i:
				gp_b = gp_b_v as Vector2i
			elif gp_b_v is Array:
				var gp_b_arr: Array = gp_b_v as Array
				if gp_b_arr.size() >= 2:
					gp_b = Vector2i(int(gp_b_arr[0]), int(gp_b_arr[1]))
			else:
				var bx: int = int(bd.get("x", 0))
				var by: int = int(bd.get("y", 0))
				gp_b = Vector2i(bx, by)
			var req_b: Array = []
			var req_b_v: Variant = bd.get("required_hive_ids", [])
			if typeof(req_b_v) == TYPE_ARRAY:
				for req_any in req_b_v as Array:
					req_b.append(int(req_any))
			var control_b: Array = []
			var control_b_v: Variant = bd.get("control_hive_ids", [])
			if typeof(control_b_v) == TYPE_ARRAY:
				for control_any in control_b_v as Array:
					control_b.append(int(control_any))
			barracks_out.append({
				"id": barracks_id,
				"grid_pos": gp_b,
				"required_hive_ids": req_b,
				"control_hive_ids": control_b,
				"route_targets": [],
				"route_hive_ids": [],
				"route_mode": "round_robin",
				"route_cursor": 0,
				"owner_id": int(bd.get("owner_id", 0))
			})
	barracks = barracks_out
	var barracks_sample: Variant = barracks_out[0] if barracks_out.size() > 0 else null
	SFLog.info("STATE_BARRACKS_SET", {"count": barracks_out.size(), "sample": barracks_sample})

	rebuild_indexes()

func seed_starting_power_if_missing(default_power: int) -> void:
	for hive in hives:
		if hive.power <= 0:
			hive.power = default_power

# -------------------------------------------------------------------
# Geometry
# -------------------------------------------------------------------

func can_connect(a_id: int, b_id: int) -> bool:
	if a_id == b_id:
		return false
	var a := get_hive(a_id)
	var b := get_hive(b_id)
	if a == null or b == null:
		return false
	return not is_segment_blocked(_hive_world_pos(a), _hive_world_pos(b), a_id, b_id)

func is_segment_blocked(a: Vector2, b: Vector2, a_id: int, b_id: int) -> bool:
	for h in hives:
		if h.id == a_id or h.id == b_id:
			continue
		if _segment_hits_circle(a, b, _hive_world_pos(h), HIVE_BLOCK_RADIUS_PX):
			return true
	return false

func find_lane_by_id(lane_id: int) -> Variant:
	for lane in lanes:
		if lane == null:
			continue
		if lane is Dictionary:
			var d: Dictionary = lane as Dictionary
			if int(d.get("lane_id", d.get("id", -1))) == lane_id:
				return lane
		elif lane is Object:
			var obj: Object = lane as Object
			var id_v: Variant = obj.get("lane_id")
			if id_v == null:
				id_v = obj.get("id")
			if int(id_v) == lane_id:
				return lane
	return null

func _segment_hits_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var ab := b - a
	var t := 0.0
	var denom := ab.length_squared()
	if denom > 0.0:
		t = clampf((c - a).dot(ab) / denom, 0.0, 1.0)
	var p := a + ab * t
	return p.distance_squared_to(c) <= r * r

func _hive_world_pos(hive: HiveData) -> Vector2:
	if grid_spec != null:
		return grid_spec.grid_to_world(hive.grid_pos)
	return Vector2(
		(float(hive.grid_pos.x) + 0.5) * DEFAULT_CELL_SIZE,
		(float(hive.grid_pos.y) + 0.5) * DEFAULT_CELL_SIZE
	)

func hive_world_pos_by_id(hive_id: int) -> Vector2:
	var hive := find_hive_by_id(hive_id)
	if hive == null:
		return Vector2.ZERO
	return _hive_world_pos(hive)

static func lane_edge_points(a_pos: Vector2, b_pos: Vector2, hive_r: float = HIVE_LANE_RADIUS_PX) -> Dictionary:
	var dir := (b_pos - a_pos)
	var dist := dir.length()
	if dist <= 0.001:
		return {"a_edge": a_pos, "b_edge": b_pos}
	dir /= dist
	var a_edge := a_pos + dir * hive_r
	var b_edge := b_pos - dir * hive_r
	return {"a_edge": a_edge, "b_edge": b_edge}

# -------------------------------------------------------------------
# Lane keys / sim state (optional)
# -------------------------------------------------------------------

func _lane_key(a_id: int, b_id: int) -> String:
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	return "%d:%d" % [lo, hi]

func lane_key(a_id: int, b_id: int) -> String:
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	return "%d_%d" % [lo, hi]

func ensure_lane_state(a_id: int, b_id: int, length_px: float) -> Dictionary:
	var key := lane_key(a_id, b_id)
	var lane_state: Dictionary = lane_sim_by_key.get(key, {})
	if lane_state.is_empty():
		lane_state = {
			"lane_key": key,
			"a_id": a_id,
			"b_id": b_id,
			"length_px": length_px,
			"front_t": 0.5,
			"last_collision_t": 0.5,
			"side": {},
			"establish_t_by_owner": {},
			"establishing_by_owner": {},
			"established_by_owner": {},
			"spawn_timer_ms_by_owner": {},
			"establish_last_by_owner": {}
		}
	if not lane_state.has("establish_t_by_owner"):
		lane_state["establish_t_by_owner"] = {}
	if not lane_state.has("establishing_by_owner"):
		lane_state["establishing_by_owner"] = {}
	if not lane_state.has("established_by_owner"):
		lane_state["established_by_owner"] = {}
	if not lane_state.has("spawn_timer_ms_by_owner"):
		lane_state["spawn_timer_ms_by_owner"] = {}
	if not lane_state.has("establish_last_by_owner"):
		lane_state["establish_last_by_owner"] = {}
	lane_state["length_px"] = length_px
	lane_sim_by_key[key] = lane_state
	return lane_state

func issue_attack_order(
	attacker_id: int,
	target_id: int,
	owner_id: int,
	lane_a_id: int,
	lane_b_id: int,
	length_px: float,
	est_speed_px: float,
	first_unit_delay_ms: int = 2
) -> Dictionary:
	if owner_id <= 0:
		return {}
	var lane_state := ensure_lane_state(lane_a_id, lane_b_id, length_px)

	var dir := 0
	if attacker_id == lane_a_id:
		dir = 1
	elif attacker_id == lane_b_id:
		dir = -1
	if dir == 0:
		return lane_state

	var establishing_by_owner: Dictionary = lane_state.get("establishing_by_owner", {})
	var established_by_owner: Dictionary = lane_state.get("established_by_owner", {})
	if bool(establishing_by_owner.get(owner_id, false)) or bool(established_by_owner.get(owner_id, false)):
		return lane_state

	var side_by_owner: Dictionary = lane_state.get("side", {})
	if side_by_owner.has(owner_id):
		return lane_state

	var establish_t_by_owner: Dictionary = lane_state.get("establish_t_by_owner", {})
	var spawn_timer_by_owner: Dictionary = lane_state.get("spawn_timer_ms_by_owner", {})

	establishing_by_owner[owner_id] = true
	established_by_owner[owner_id] = false
	establish_t_by_owner[owner_id] = 0.0
	spawn_timer_by_owner[owner_id] = 0.0

	side_by_owner[owner_id] = {
		"owner_id": owner_id,
		"attacker_id": attacker_id,
		"target_id": target_id,
		"dir": dir,
		"est_speed": est_speed_px,
		"first_unit_sent": false,
		"first_unit_delay_ms": first_unit_delay_ms,
		"first_unit_timer": 0.0
	}

	lane_state["side"] = side_by_owner
	lane_state["establish_t_by_owner"] = establish_t_by_owner
	lane_state["establishing_by_owner"] = establishing_by_owner
	lane_state["established_by_owner"] = established_by_owner
	lane_state["spawn_timer_ms_by_owner"] = spawn_timer_by_owner
	lane_sim_by_key[lane_state.get("lane_key", lane_key(lane_a_id, lane_b_id))] = lane_state
	return lane_state

# -------------------------------------------------------------------
# Indexes / queries
# -------------------------------------------------------------------

func rebuild_indexes() -> void:
	hive_by_id.clear()
	lane_index_by_key.clear()

	for hive in hives:
		var hive_id: int = int(hive.id)
		if hive_by_id.has(hive_id):
			if SFLog.LOGGING_ENABLED:
				push_warning("GAMESTATE: duplicate hive id in rebuild_indexes: %d" % hive_id)
			continue
		hive_by_id[hive_id] = hive

	for i in range(lanes.size()):
		var lane: Variant = lanes[i]
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData
		var key := _lane_key(int(ld.a_id), int(ld.b_id))
		if lane_index_by_key.has(key):
			if SFLog.LOGGING_ENABLED:
				push_warning("GAMESTATE: duplicate lane key in rebuild_indexes: %s" % key)
			continue
		lane_index_by_key[key] = i

	_hive_index_count = hives.size()
	_lane_index_count = lanes.size()
	_refresh_hives_set_version()

	rebuild_lane_adjacency()

func _refresh_hives_set_version() -> void:
	var count: int = hives.size()
	var sig: int = _hives_set_signature()
	if count == _last_hives_set_count and sig == _last_hives_set_sig:
		return
	_last_hives_set_count = count
	_last_hives_set_sig = sig
	hives_set_version += 1

func _hives_set_signature() -> int:
	var sig: int = hives.size()
	var xor_sig: int = 0
	for hive_any in hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		var packed: int = int(hive.id)
		packed = (packed * 31 + int(hive.grid_pos.x)) & 0x7fffffff
		packed = (packed * 31 + int(hive.grid_pos.y)) & 0x7fffffff
		packed = (packed * 31 + int(hive.owner_id)) & 0x7fffffff
		packed = (packed * 31 + int(String(hive.kind).hash())) & 0x7fffffff
		xor_sig = xor_sig ^ packed
	sig = (sig * 31 + xor_sig) & 0x7fffffff
	return sig

func rebuild_lane_adjacency() -> void:
	outgoing_by_hive.clear()
	for lane in lanes:
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData
		var a_id: int = int(ld.a_id)
		var b_id: int = int(ld.b_id)
		if a_id <= 0 or b_id <= 0:
			continue

		if not outgoing_by_hive.has(a_id):
			outgoing_by_hive[a_id] = []
		if not outgoing_by_hive.has(b_id):
			outgoing_by_hive[b_id] = []

		(outgoing_by_hive[a_id] as Array).append(ld)
		(outgoing_by_hive[b_id] as Array).append(ld)

func _indexes_dirty() -> bool:
	if not hives.is_empty():
		if hive_by_id.is_empty() or _hive_index_count != hives.size():
			return true
	if not lanes.is_empty():
		if lane_index_by_key.is_empty() or _lane_index_count != lanes.size():
			return true
	return false

func _ensure_indexes() -> void:
	if _indexes_dirty():
		rebuild_indexes()

func find_hive_at_cell(cell: Vector2i) -> HiveData:
	for hive in hives:
		if hive.grid_pos == cell:
			return hive
	return null

func find_hive_by_id(id: int) -> HiveData:
	_ensure_indexes()

	if hive_by_id.has(id):
		var cached: HiveData = hive_by_id[id]
		if cached != null and int(cached.id) != id:
			SFLog.info("HIVE_INDEX_STALE", {"requested": id, "cached_id": int(cached.id)})
			hive_by_id.erase(id)
		else:
			return cached

	for hive in hives:
		if hive.id == id:
			hive_by_id[id] = hive
			return hive

	return null

func get_hive(id: int) -> HiveData:
	# Keep signature stable: many call sites expect get_hive(int)
	return find_hive_by_id(id)

func lane_index_between(a_id: int, b_id: int) -> int:
	_ensure_indexes()

	var key := _lane_key(a_id, b_id)
	if lane_index_by_key.has(key):
		return int(lane_index_by_key[key])

	for i in range(lanes.size()):
		var lane: Variant = lanes[i]
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData
		if (int(ld.a_id) == a_id and int(ld.b_id) == b_id) or (int(ld.a_id) == b_id and int(ld.b_id) == a_id):
			lane_index_by_key[key] = i
			return i

	return -1

func lane_exists_between(a_id: int, b_id: int) -> bool:
	var a: int = int(a_id)
	var b: int = int(b_id)

	var samples: Array = []
	var sample_limit := 5

	for i in range(lanes.size()):
		var lane: Variant = lanes[i]
		var lane_a := -1
		var lane_b := -1
		var lane_id := -1

		if lane is LaneData:
			var ld := lane as LaneData
			lane_a = int(ld.a_id)
			lane_b = int(ld.b_id)
			lane_id = int(ld.id)
		elif lane is Dictionary:
			var d := lane as Dictionary
			lane_a = int(d.get("a_id", -1))
			lane_b = int(d.get("b_id", -1))
			lane_id = int(d.get("id", -1))
		else:
			continue

		if samples.size() < sample_limit:
			samples.append({"a_id": lane_a, "b_id": lane_b, "lane_id": lane_id})

		if (lane_a == a and lane_b == b) or (lane_a == b and lane_b == a):
			return true

	SFLog.info("LANE_EXISTS_MISS", {
		"a_id": a,
		"b_id": b,
		"lane_count": lanes.size(),
		"samples": samples
	})
	return false

func intent_is_on(from_id: int, to_id: int) -> bool:
	var lane_index := lane_index_between(from_id, to_id)
	if lane_index == -1:
		return false

	var lane: Variant = lanes[lane_index]

	if lane is LaneData:
		var ld := lane as LaneData
		if from_id == int(ld.a_id) and to_id == int(ld.b_id):
			return bool(ld.send_a)
		if from_id == int(ld.b_id) and to_id == int(ld.a_id):
			return bool(ld.send_b)
		return false

	if lane is Dictionary:
		var d := lane as Dictionary
		var a_id: int = int(d.get("a_id", -1))
		var b_id: int = int(d.get("b_id", -1))
		if from_id == a_id and to_id == b_id:
			return bool(d.get("send_a", false))
		if from_id == b_id and to_id == a_id:
			return bool(d.get("send_b", false))

	return false

func lanes_allowed_for_power(power: int) -> int:
	if power <= 9:
		return 1
	if power <= 24:
		return 2
	return 3

func count_active_outgoing(hive_id: int) -> int:
	var count := 0
	for lane in lanes:
		if lane is LaneData:
			var ld := lane as LaneData
			if int(ld.a_id) == hive_id and ld.send_a:
				count += 1
			elif int(ld.b_id) == hive_id and ld.send_b:
				count += 1
		elif lane is Dictionary:
			var d := lane as Dictionary
			var a_id: int = int(d.get("a_id", -1))
			var b_id: int = int(d.get("b_id", -1))
			if a_id == hive_id and bool(d.get("send_a", false)):
				count += 1
			elif b_id == hive_id and bool(d.get("send_b", false)):
				count += 1
	return count

func is_outgoing_lane_active(src_id: int, dst_id: int) -> bool:
	var lane_index := lane_index_between(src_id, dst_id)
	if lane_index == -1:
		return false

	var lane: Variant = lanes[lane_index]

	if lane is LaneData:
		var ld := lane as LaneData
		if src_id == int(ld.a_id) and dst_id == int(ld.b_id):
			return bool(ld.send_a)
		if src_id == int(ld.b_id) and dst_id == int(ld.a_id):
			return bool(ld.send_b)
		return false

	if lane is Dictionary:
		var d := lane as Dictionary
		var a_id: int = int(d.get("a_id", -1))
		var b_id: int = int(d.get("b_id", -1))
		if src_id == a_id and dst_id == b_id:
			return bool(d.get("send_a", false))
		if src_id == b_id and dst_id == a_id:
			return bool(d.get("send_b", false))

	return false

func map_lane_between(a_id: int, b_id: int) -> int:
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)

	for i in range(map_lanes.size()):
		var lane: Variant = map_lanes[i]
		if lane is Dictionary:
			var d := lane as Dictionary
			var a: int = int(d.get("a_id", -1))
			var b: int = int(d.get("b_id", -1))
			if mini(a, b) == lo and maxi(a, b) == hi:
				return int(d.get("lane_id", d.get("id", -1)))
		elif lane is LaneData:
			var ld := lane as LaneData
			var a: int = int(ld.a_id)
			var b: int = int(ld.b_id)
			if mini(a, b) == lo and maxi(a, b) == hi:
				return int(ld.id)

	return -1

# -------------------------------------------------------------------
# Lane flow
# -------------------------------------------------------------------

func tick_unintended_power(dt_ms: float) -> void:
	if dt_ms <= 0.0 or hives.is_empty():
		return
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		_passive_accum_ms = 0.0
		return
	if not _passive_config_logged:
		_passive_config_logged = true
		SFLog.info("PASSIVE_CONFIG", {
			"chill_ms": PASSIVE_CHILL_MS,
			"ms_per_power": PASSIVE_MS_PER_POWER
		})
	if int(OpsState.match_elapsed_ms) < PASSIVE_CHILL_MS:
		_passive_accum_ms = 0.0
		return
	_passive_accum_ms += dt_ms
	var ticks_fired: int = 0
	while _passive_accum_ms >= PASSIVE_MS_PER_POWER:
		_passive_accum_ms -= PASSIVE_MS_PER_POWER
		ticks_fired += 1
		_apply_passive_tick(1, ticks_fired)

func _apply_passive_tick(inc: int, ticks_fired: int) -> void:
	var eligible_count: int = 0
	var applied_count: int = 0
	var sample: Array = []
	for hive in hives:
		if hive == null:
			continue
		var hid: int = int(hive.id)
		if _is_npc_hive(hive):
			continue
		var outgoing: int = outgoing_active_count(hid)
		if outgoing > 0:
			continue
		eligible_count += 1
		var before: int = int(hive.power)
		var after: int = mini(SimTuning.MAX_POWER, before + inc)
		if after > before:
			hive.power = after
			applied_count += 1
		if sample.size() < 3:
			sample.append({
				"id": hid,
				"outgoing": outgoing,
				"p0": before,
				"p1": int(hive.power),
				"inc": inc
			})
	SFLog.info("PASSIVE_TICK", {
		"ticks_fired": ticks_fired,
		"eligible_count": eligible_count,
		"applied_count": applied_count,
		"sample": sample
	})
	var now_ms := Time.get_ticks_msec()
	if now_ms - _outgoing_sample_log_ms >= 2000 and hives.size() > 0:
		_outgoing_sample_log_ms = now_ms
		var sample_h := hives[0] as HiveData
		if sample_h != null:
			SFLog.info("OUTGOING_COUNT_SAMPLE", {
				"id": int(sample_h.id),
				"outgoing_active_count": outgoing_active_count(int(sample_h.id))
			})

func _normalized_hive_kind(kind: String) -> String:
	var key := kind.strip_edges().to_lower()
	key = key.replace("_", "")
	if key == "playerhive":
		return "hive"
	return key

func _is_npc_hive(hv: Variant) -> bool:
	if typeof(hv) == TYPE_DICTIONARY:
		var hd: Dictionary = hv
		var kind_norm := _normalized_hive_kind(str(hd.get("kind", "")))
		if kind_norm == "npc" or kind_norm == "npchive":
			return true
		if bool(hd.get("is_npc", false)):
			return true
		var owner_str := str(hd.get("owner", "")).strip_edges().to_lower()
		if owner_str == "npc":
			return true
		return false
	var kind_norm := _normalized_hive_kind(str(hv.kind))
	return kind_norm == "npc" or kind_norm == "npchive"

func outgoing_active_count(hive_id: int) -> int:
	var count := 0
	for lane_any in lanes:
		if lane_any is LaneData:
			var ld := lane_any as LaneData
			if int(ld.a_id) == hive_id and bool(ld.send_a):
				count += 1
			if int(ld.b_id) == hive_id and bool(ld.send_b):
				count += 1
		elif lane_any is Dictionary:
			var d := lane_any as Dictionary
			var a_id := int(d.get("a_id", d.get("from", 0)))
			var b_id := int(d.get("b_id", d.get("to", 0)))
			if a_id == hive_id and bool(d.get("send_a", false)):
				count += 1
			if b_id == hive_id and bool(d.get("send_b", false)):
				count += 1
	return count

func tick_lane_flow(dt_ms: float, allow_spawns: bool = true) -> void:
	if dt_ms <= 0.0 or lanes.is_empty():
		return
	if not allow_spawns and not _lane_spawn_disabled_logged:
		_lane_spawn_disabled_logged = true
		SFLog.info("SPAWN_DISABLED", {"system": "lane"})
	tick += 1
	_sim_time_us += int(round(dt_ms * 1000.0))

	if OS.is_debug_build():
		_lane_dump_accum_ms += dt_ms
		if _lane_dump_accum_ms >= SimTuning.LANE_DUMP_INTERVAL_MS:
			_lane_dump_accum_ms = fmod(_lane_dump_accum_ms, SimTuning.LANE_DUMP_INTERVAL_MS)
			_debug_dump_lane_state()

	for lane in lanes:
		if lane is LaneData:
			_tick_lane(lane as LaneData, dt_ms, allow_spawns)

func _tick_lane(lane: LaneData, dt_ms: float, allow_spawns: bool) -> void:
	if lane.retract_a:
		_reset_lane_side(lane, true)
	if lane.retract_b:
		_reset_lane_side(lane, false)

	var a_hive: HiveData = find_hive_by_id(int(lane.a_id))
	var b_hive: HiveData = find_hive_by_id(int(lane.b_id))
	if a_hive == null or b_hive == null:
		return

	var a_pos := _hive_world_pos(a_hive)
	var b_pos := _hive_world_pos(b_hive)
	var lane_len: float = maxf(0.0, a_pos.distance_to(b_pos) - (HIVE_LANE_RADIUS_PX * 2.0))
	if debug_lane_len_log and int(lane.id) == 1:
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_lane_len_log_ms >= LANE_LEN_LOG_INTERVAL_MS:
			_last_lane_len_log_ms = now_ms
			SFLog.info("LANE_LEN_DEBUG", {
				"lane_id": int(lane.id),
				"dist": a_pos.distance_to(b_pos),
				"lane_len": lane_len,
				"lane_r": HIVE_LANE_RADIUS_PX
			})
	if lane_len <= 0.0:
		return

	_accumulate_lane_pressure(lane, dt_ms, lane_len, a_hive, b_hive, allow_spawns)
	_cancel_lane_pressure(lane)

	var speed_px_per_ms: float = float(SimTuning.UNIT_SPEED_PX_PER_SEC) / 1000.0
	_advance_lane_stream(lane, lane_len, speed_px_per_ms, dt_ms)
	_deliver_lane_pressure(lane)

func _reset_lane_side(lane: LaneData, is_a: bool) -> void:
	var q := _arrival_q_for(int(lane.id))
	if is_a:
		lane.send_a = false
		lane.a_pressure = 0.0
		lane.a_stream_len = 0.0
		lane.spawn_accum_a_ms = 0.0
		lane.establish_a = false
		lane.retract_a = false
		(q["a"] as Array).clear()
		q["a_i"] = 0
	else:
		lane.send_b = false
		lane.b_pressure = 0.0
		lane.b_stream_len = 0.0
		lane.spawn_accum_b_ms = 0.0
		lane.establish_b = false
		lane.retract_b = false
		(q["b"] as Array).clear()
		q["b_i"] = 0

func _accumulate_lane_pressure(
	lane: LaneData,
	dt_ms: float,
	lane_len: float,
	a_hive: HiveData,
	b_hive: HiveData,
	allow_spawns: bool
) -> void:
	if not allow_spawns:
		lane.spawn_accum_a_ms = 0.0
		lane.spawn_accum_b_ms = 0.0
		return
	if lane.send_a and not lane.retract_a:
		if lane.build_t < 0.999:
			lane.spawn_accum_a_ms = 0.0
			_log_spawn_block(lane, "A", "BUILD")
		else:
			if a_hive != null and a_hive.owner_id > 0:
				# Swarm shock: block outgoing spawns for a short window.
				var block_until_us: int = int(hive_spawn_block_until_us.get(int(a_hive.id), 0))
				if _sim_time_us < block_until_us:
					lane.spawn_accum_a_ms = 0.0
					_log_spawn_block(lane, "A", "SHOCK")
				else:
					lane.spawn_accum_a_ms += dt_ms
					var spawn_ms: float = _spawn_ms_for_hive(int(a_hive.power))
					var lane_cap_a: float = _lane_hard_cap_units(lane_len)
					var spawned_any := false
					while lane.spawn_accum_a_ms >= spawn_ms:
						if lane.a_pressure >= lane_cap_a:
							lane.spawn_accum_a_ms = minf(lane.spawn_accum_a_ms, spawn_ms)
							_log_spawn_block(lane, "A", "LANE_CAP")
							break
						lane.spawn_accum_a_ms -= spawn_ms
						var amount := _pressure_per_spawn()
						lane.a_pressure += amount
						lane.establish_a = true
						var spawn_count: int = int(maxi(1, int(round(amount))))
						spawned_any = true
						for _k in range(spawn_count):
							_schedule_arrival(lane, "A", lane_len)
							if unit_system != null:
								_spawn_unit_packet(lane, a_hive, b_hive, true)
						if SimTuning.LANE_FLOW_LOGS and SFLog.verbose_sim:
							SFLog.throttled_info("LANE_SPAWN", {
								"lane_id": int(lane.id),
								"side": "A",
								"amount": amount,
								"pressure": lane.a_pressure
							}, 250)
					if not spawned_any:
						_log_spawn_block(lane, "A", "INTERVAL")
			else:
				_log_spawn_block(lane, "A", "OWNER")
	else:
		lane.spawn_accum_a_ms = 0.0

	if lane.send_b and not lane.retract_b:
		if lane.build_t < 0.999:
			lane.spawn_accum_b_ms = 0.0
			_log_spawn_block(lane, "B", "BUILD")
		else:
			if b_hive != null and b_hive.owner_id > 0:
				# Swarm shock: block outgoing spawns for a short window.
				var block_until_us_b: int = int(hive_spawn_block_until_us.get(int(b_hive.id), 0))
				if _sim_time_us < block_until_us_b:
					lane.spawn_accum_b_ms = 0.0
					_log_spawn_block(lane, "B", "SHOCK")
				else:
					lane.spawn_accum_b_ms += dt_ms
					var spawn_ms: float = _spawn_ms_for_hive(int(b_hive.power))
					var lane_cap_b: float = _lane_hard_cap_units(lane_len)
					var spawned_any := false
					while lane.spawn_accum_b_ms >= spawn_ms:
						if lane.b_pressure >= lane_cap_b:
							lane.spawn_accum_b_ms = minf(lane.spawn_accum_b_ms, spawn_ms)
							_log_spawn_block(lane, "B", "LANE_CAP")
							break
						lane.spawn_accum_b_ms -= spawn_ms
						var amount := _pressure_per_spawn()
						lane.b_pressure += amount
						lane.establish_b = true
						var spawn_count: int = int(maxi(1, int(round(amount))))
						spawned_any = true
						for _k in range(spawn_count):
							_schedule_arrival(lane, "B", lane_len)
							if unit_system != null:
								_spawn_unit_packet(lane, b_hive, a_hive, false)
						if SimTuning.LANE_FLOW_LOGS and SFLog.verbose_sim:
							SFLog.throttled_info("LANE_SPAWN", {
								"lane_id": int(lane.id),
								"side": "B",
								"amount": amount,
								"pressure": lane.b_pressure
							}, 250)
					if not spawned_any:
						_log_spawn_block(lane, "B", "INTERVAL")
			else:
				_log_spawn_block(lane, "B", "OWNER")
	else:
		lane.spawn_accum_b_ms = 0.0

func _log_spawn_block(lane: LaneData, side: String, reason: String) -> void:
	var lane_key := "%d:%s" % [int(lane.id), side]
	var now_ms := Time.get_ticks_msec()
	var last_ms: int = int(_last_spawn_block_log_ms.get(lane_key, 0))
	var last_reason: String = str(_last_spawn_block_reason.get(lane_key, ""))
	if reason == last_reason and now_ms - last_ms < SPAWN_BLOCK_LOG_INTERVAL_MS:
		return
	_last_spawn_block_log_ms[lane_key] = now_ms
	_last_spawn_block_reason[lane_key] = reason
	if reason == "LANE_CAP":
		SFLog.info("LANE_CAP_BLOCK", {
			"lane_id": int(lane.id),
			"side": side
		})
	if SFLog.verbose_sim:
		SFLog.throttled_info("LANE_SPAWN_BLOCK", {
			"lane_id": int(lane.id),
			"side": side,
			"reason": reason
		}, 250)

func _spawn_unit_packet(lane: LaneData, from_hive: HiveData, to_hive: HiveData, from_is_a: bool) -> void:
	if unit_system == null:
		return
	var side := "A" if from_is_a else "B"
	var unit: Dictionary = {
		"from_id": int(from_hive.id),
		"to_id": int(to_hive.id),
		"owner_id": int(from_hive.owner_id),
		"amount": 1,
		"lane_id": int(lane.id),
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"dir": 1 if from_is_a else -1
	}
	if SFLog.verbose_sim:
		SFLog.throttled_info("UNIT_ENQUEUE_FROM_LANE", {
			"lane_id": int(lane.id),
			"side": side,
			"amount": int(unit.get("amount", 1)),
			"owner_id": int(from_hive.owner_id)
		}, 250)
	unit_system.spawn_unit(unit)

func _lane_hard_cap_units(lane_len: float) -> float:
	var px_per_unit: float = maxf(1.0, float(SimTuning.LANE_HARD_CAP_PX_PER_UNIT))
	var raw_cap: int = int(round(maxf(1.0, lane_len) / px_per_unit))
	var min_cap: int = int(SimTuning.LANE_HARD_CAP_MIN_UNITS)
	var max_cap: int = int(SimTuning.LANE_HARD_CAP_MAX_UNITS)
	return float(clampi(raw_cap, min_cap, max_cap))

func _cancel_lane_pressure(lane: LaneData) -> void:
	if unit_system != null and unit_system.use_lane_system_spawns:
		return
	var cancel: float = minf(lane.a_pressure, lane.b_pressure)
	if cancel <= 0.0:
		return

	lane.a_pressure = maxf(0.0, lane.a_pressure - cancel)
	lane.b_pressure = maxf(0.0, lane.b_pressure - cancel)

	if SimTuning.LANE_FLOW_LOGS:
		SFLog.info("LANE_CANCEL", {
			"lane_id": int(lane.id),
			"cancel": cancel,
			"a_pressure": lane.a_pressure,
			"b_pressure": lane.b_pressure
		})

func _advance_lane_stream(lane: LaneData, lane_len: float, speed_px_per_ms: float, dt_ms: float) -> void:
	var delta_len: float = speed_px_per_ms * dt_ms

	if lane.a_pressure > 0.0:
		lane.a_stream_len = min(lane_len, lane.a_stream_len + delta_len)
	else:
		lane.a_stream_len = maxf(0.0, lane.a_stream_len - delta_len)

	if lane.b_pressure > 0.0:
		lane.b_stream_len = min(lane_len, lane.b_stream_len + delta_len)
	else:
		lane.b_stream_len = maxf(0.0, lane.b_stream_len - delta_len)

func _deliver_lane_pressure(lane: LaneData) -> void:
	if unit_system != null and unit_system.use_lane_system_spawns:
		return
	var q := _arrival_q_for(int(lane.id))

	# side A arrivals (a -> b)
	var qa: Array = q["a"] as Array
	var ai: int = int(q.get("a_i", 0))
	while ai < qa.size() and int(qa[ai]) <= _sim_time_us:
		ai += 1
		_apply_lane_arrival(int(lane.a_id), int(lane.b_id), 1.0, lane)
		lane.a_pressure = maxf(0.0, lane.a_pressure - 1.0)
	q["a_i"] = ai
	if ai > 64:
		qa = qa.slice(ai, qa.size() - ai)
		q["a"] = qa
		q["a_i"] = 0

	# side B arrivals (b -> a)
	var qb: Array = q["b"] as Array
	var bi: int = int(q.get("b_i", 0))
	while bi < qb.size() and int(qb[bi]) <= _sim_time_us:
		bi += 1
		_apply_lane_arrival(int(lane.b_id), int(lane.a_id), 1.0, lane)
		lane.b_pressure = maxf(0.0, lane.b_pressure - 1.0)
	q["b_i"] = bi
	if bi > 64:
		qb = qb.slice(bi, qb.size() - bi)
		q["b"] = qb
		q["b_i"] = 0

# -------------------------------------------------------------------
# Arrival resolution
# -------------------------------------------------------------------

func _apply_lane_arrival(src_id: int, dst_id: int, amount: float, lane: LaneData) -> void:
	var src: HiveData = find_hive_by_id(src_id)
	var dst: HiveData = find_hive_by_id(dst_id)
	if src == null or dst == null:
		return
	if src.owner_id <= 0:
		return

	var delta: int = int(round(amount))
	if delta <= 0:
		return
	var before_owner: int = int(dst.owner_id)
	var before_power: int = int(dst.power)
	if SimTuning.LANE_FLOW_LOGS:
		SFLog.info("LANE_ARRIVE", {
			"lane_id": int(lane.id),
			"src": src_id,
			"dst": dst_id,
			"amount": delta,
			"owner": before_owner,
			"power": before_power,
			"before_owner": before_owner,
			"before_power": before_power,
			"arrive_source": "lane_system",
			"mutated": false
		})
	return

func _clear_all_outgoing_from(hive_id: int) -> void:
	for lane in lanes:
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData
		if int(ld.a_id) == hive_id and ld.send_a:
			ld.send_a = false
			ld.establish_a = false
			ld.a_pressure = 0.0
			ld.a_stream_len = 0.0
			ld.spawn_accum_a_ms = 0.0
		elif int(ld.b_id) == hive_id and ld.send_b:
			ld.send_b = false
			ld.establish_b = false
			ld.b_pressure = 0.0
			ld.b_stream_len = 0.0
			ld.spawn_accum_b_ms = 0.0

func _spawn_ms_for_hive(power: int) -> int:
	var p: int = int(maxi(1, power))
	return maxi(50, 1000 - (p - 1) * 2)

func _pressure_per_spawn() -> float:
	return float(SimTuning.PRESSURE_PER_SPAWN)

func _arrival_q_for(lane_id: int) -> Dictionary:
	if not _arrival_q.has(lane_id):
		_arrival_q[lane_id] = {"a": [], "a_i": 0, "b": [], "b_i": 0}
	return _arrival_q[lane_id]

func _schedule_arrival(lane: LaneData, side: String, lane_len: float) -> void:
	if unit_system != null and unit_system.use_lane_system_spawns:
		return
	var speed_px_per_ms: float = float(SimTuning.UNIT_SPEED_PX_PER_SEC) / 1000.0
	var travel_ms: float = lane_len / maxf(0.001, speed_px_per_ms)
	var eta_us := _sim_time_us + int(round(travel_ms * 1000.0))
	if SimTuning.LANE_FLOW_LOGS:
		SFLog.info("ARRIVAL_SCHEDULE", {
			"lane_id": int(lane.id),
			"side": side,
			"lane_len": lane_len,
			"speed_px_s": float(SimTuning.UNIT_SPEED_PX_PER_SEC),
			"travel_ms": travel_ms,
			"now_us": _sim_time_us,
			"eta_us": eta_us,
			"eta_delta_ms": float(eta_us - _sim_time_us) / 1000.0
		})
	var q := _arrival_q_for(int(lane.id))
	if side == "A":
		var qa: Array = q["a"] as Array
		if qa.is_empty() or eta_us >= int(qa[qa.size() - 1]):
			qa.append(eta_us)
		else:
			var i := qa.bsearch(eta_us)
			qa.insert(i, eta_us)
	else:
		var qb: Array = q["b"] as Array
		if qb.is_empty() or eta_us >= int(qb[qb.size() - 1]):
			qb.append(eta_us)
		else:
			var i := qb.bsearch(eta_us)
			qb.insert(i, eta_us)

# -------------------------------------------------------------------
# Debug
# -------------------------------------------------------------------

func _debug_dump_lane_state() -> void:
	for lane in lanes:
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData
		SFLog.debug("LANE_DUMP", {
			"lane_id": int(ld.id),
			"send_a": ld.send_a,
			"send_b": ld.send_b,
			"a_pressure": ld.a_pressure,
			"b_pressure": ld.b_pressure,
			"a_stream_len": ld.a_stream_len,
			"b_stream_len": ld.b_stream_len
		})

func _auth_fence_first_external_frame() -> Dictionary:
	var stack: Array = get_stack()
	for i in range(1, stack.size()):
		var frame: Dictionary = stack[i]
		var source: String = str(frame.get("source", ""))
		if source.ends_with("scripts/state/game_state.gd"):
			continue
		return frame
	return {}

func _auth_fence_source_allowed(source: String) -> bool:
	if source.is_empty():
		return true
	if source.ends_with("scripts/state/game_state.gd"):
		return true
	for prefix in AUTH_FENCE_ALLOWED_PREFIXES:
		if source.begins_with(prefix):
			return true
	return false

func audit_mutation(context: String, target: String = "", source_hint: String = "") -> void:
	SFLog.allow_tag("GAMESTATE_MUTATION_FENCE")
	var source: String = source_hint.strip_edges()
	var frame: Dictionary = {}
	if source.is_empty():
		frame = _auth_fence_first_external_frame()
		source = str(frame.get("source", ""))
	if source.is_empty():
		source = context
	if _auth_fence_source_allowed(source):
		return
	var line_no: int = int(frame.get("line", 0))
	var key: String = "%s|%s|%s|%d" % [source, context, target, line_no]
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = int(_auth_fence_last_ms.get(key, 0))
	if now_ms - last_ms < AUTH_FENCE_LOG_INTERVAL_MS:
		return
	_auth_fence_last_ms[key] = now_ms
	SFLog.warn("GAMESTATE_MUTATION_FENCE", {
		"context": context,
		"target": target,
		"source": source,
		"line": line_no
	})
	if auth_fence_assert_enabled:
		assert(false, "GameState mutation fence hit: %s (%s)" % [context, target])
