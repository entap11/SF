extends Node
class_name LaneSystem

const SFLog := preload("res://scripts/util/sf_log.gd")

signal lane_created(lane: Dictionary)
signal lane_updated(lane: Dictionary)
signal lane_removed(lane_id: int)

const LANE_BUILD_MS := 500
const LANE_FRONT_SPEED := 0.35
const LANE_ESTABLISH_EPS := 0.999

var lanes: Dictionary = {} # key "lo:hi" -> Dictionary lane_d (render/intent view)
var blockers: Array = []   # [{pos:Vector2, r:float, id:int}]
var state: GameState = null
var last_error_reason: String = ""
var _established_by_lane_id: Dictionary = {}
var _build_complete_logged: Dictionary = {}

var establish_ms: float = 2400.0
var first_unit_delay_ms: int = 2

var _next_lane_id: int = 1
var _sync_dirty: bool = false


func _ready() -> void:
	set_process(true)


func bind_state(state_ref: GameState) -> void:
	state = state_ref
	lanes.clear()
	_established_by_lane_id.clear()
	_build_complete_logged.clear()
	last_error_reason = ""
	_sync_dirty = false
	_next_lane_id = 1

	if state == null:
		return

	# Build a render/intent dictionary layer from the authoritative LaneData list.
	for lane in state.lanes:
		if not (lane is LaneData):
			continue
		var ld := lane as LaneData

		_next_lane_id = max(_next_lane_id, int(ld.id) + 1)

		# Only represent lanes that have some "meaning" to the UI layer.
		if not (ld.send_a or ld.send_b or ld.establish_a or ld.establish_b):
			continue

		var lo := mini(int(ld.a_id), int(ld.b_id))
		var hi := maxi(int(ld.a_id), int(ld.b_id))

		var lane_d := _make_lane(lo, hi, int(ld.id))
		lane_d["active"] = true
		lane_d["progress"] = 1.0

		# Map send_a/send_b onto lo/hi directions.
		if int(ld.a_id) == lo:
			lane_d["send_lo_to_hi"] = bool(ld.send_a)
			lane_d["send_hi_to_lo"] = bool(ld.send_b)
		else:
			lane_d["send_lo_to_hi"] = bool(ld.send_b)
			lane_d["send_hi_to_lo"] = bool(ld.send_a)

		lanes[_lane_key(lo, hi)] = lane_d


func get_last_error_reason() -> String:
	return last_error_reason


func set_blockers_from_hives(hive_list: Array, radius: float = 24.0) -> void:
	blockers.clear()
	var rr := radius
	for h in hive_list:
		if h is Dictionary:
			var d: Dictionary = h
			var pos: Vector2 = d.get("pos", Vector2.ZERO)
			blockers.append({"pos": pos, "r": rr, "id": int(d.get("id", -1))})


func get_lane_between(a_id: int, b_id: int) -> Dictionary:
	var key := _lane_key(a_id, b_id)
	if lanes.has(key):
		return lanes[key]
	return {}


func get_lane_by_id(lane_id: int) -> Dictionary:
	for lane in lanes.values():
		if int(lane.get("id", -1)) == lane_id:
			return lane
	return {}


func get_render_lanes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var keys := lanes.keys()
	keys.sort()
	for key in keys:
		var lane: Dictionary = lanes[key]
		out.append(lane.duplicate(true))
	return out


func count_outgoing_intents(hive_id: int) -> int:
	var n := 0
	for lane in lanes.values():
		var lo := int(lane.get("lo", -1))
		var hi := int(lane.get("hi", -1))
		if hive_id == lo and bool(lane.get("send_lo_to_hi", false)):
			n += 1
		elif hive_id == hi and bool(lane.get("send_hi_to_lo", false)):
			n += 1
	return n


func max_intents_allowed(power: int, current_outgoing: int) -> int:
	if power >= 25:
		return 3
	if power >= 10:
		return 2
	if current_outgoing >= 2:
		return 2
	return 1


func enforce_caps_for_hive(hive_id: int, power: int) -> void:
	var outgoing := _get_outgoing_lanes(hive_id)
	var current_n := outgoing.size()
	var cap := max_intents_allowed(power, current_n)
	if power < 25 and cap > 2:
		cap = 2
	if current_n <= cap:
		return

	# Oldest first => retract oldest until at cap
	outgoing.sort_custom(func(a, b): return int(a.get("t0_ms", 0)) < int(b.get("t0_ms", 0)))
	while outgoing.size() > cap:
		var lane: Dictionary = outgoing.pop_front()
		retract_intent(hive_id, int(lane.get("id", -1)))


func toggle_intent(a_id: int, b_id: int) -> bool:
	last_error_reason = ""
	if state != null and OpsState.is_ending_or_ended():
		last_error_reason = "match_over"
		return false
	if a_id <= 0 or b_id <= 0 or a_id == b_id:
		return false

	var lo := mini(a_id, b_id)
	var hi := maxi(a_id, b_id)
	var key := _lane_key(lo, hi)

	var lane: Dictionary = lanes.get(key, {})
	if lane.is_empty():
		lane = _make_lane(lo, hi)
		lanes[key] = lane
		emit_signal("lane_created", lane)

	var send_lo_to_hi := bool(lane.get("send_lo_to_hi", false))
	var send_hi_to_lo := bool(lane.get("send_hi_to_lo", false))

	if a_id == lo and b_id == hi:
		send_lo_to_hi = not send_lo_to_hi
	else:
		send_hi_to_lo = not send_hi_to_lo

	lane["send_lo_to_hi"] = send_lo_to_hi
	lane["send_hi_to_lo"] = send_hi_to_lo

	# If any direction is sending, keep lane.
	if send_lo_to_hi or send_hi_to_lo:
		if not bool(lane.get("active", false)):
			lane["t0_ms"] = Time.get_ticks_msec()
			lane["progress"] = 0.0
		lanes[key] = lane
		emit_signal("lane_updated", lane)

		# If already active, we can sync immediately; otherwise build animation will sync later.
		if bool(lane.get("active", false)):
			_sync_dirty = true
			_sync_to_state()
		return true

	# Otherwise remove lane entirely.
	var lane_id := int(lane.get("id", -1))
	lanes.erase(key)
	_sync_dirty = true
	_sync_to_state()
	emit_signal("lane_removed", lane_id)
	return true


func try_create_or_flip_intent(
	src_id: int,
	trg_id: int,
	_src_pos: Vector2,
	_trg_pos: Vector2,
	_src_owner: int,
	_trg_owner: int,
	_src_power: int
) -> bool:
	if state != null and OpsState.is_ending_or_ended():
		last_error_reason = "match_over"
		return false
	return toggle_intent(src_id, trg_id)


func retract_intent(src_id: int, lane_id: int) -> void:
	var lane := get_lane_by_id(lane_id)
	if lane.is_empty():
		return

	var lo := int(lane.get("lo", -1))
	var hi := int(lane.get("hi", -1))

	var send_lo_to_hi := bool(lane.get("send_lo_to_hi", false))
	var send_hi_to_lo := bool(lane.get("send_hi_to_lo", false))

	if src_id == lo:
		send_lo_to_hi = false
	elif src_id == hi:
		send_hi_to_lo = false
	else:
		return

	lane["send_lo_to_hi"] = send_lo_to_hi
	lane["send_hi_to_lo"] = send_hi_to_lo

	if send_lo_to_hi or send_hi_to_lo:
		lanes[_lane_key(lo, hi)] = lane
		emit_signal("lane_updated", lane)
		_sync_dirty = true
		_sync_to_state()
		return

	lanes.erase(_lane_key(lo, hi))
	_sync_dirty = true
	_sync_to_state()
	emit_signal("lane_removed", lane_id)


func _process(_delta: float) -> void:
	if lanes.is_empty():
		return
	if state != null and OpsState.is_ending_or_ended():
		return

	var now := Time.get_ticks_msec()

	for key in lanes.keys():
		var lane: Dictionary = lanes[key]

		if bool(lane.get("active", false)):
			continue
		if not (bool(lane.get("send_lo_to_hi", false)) or bool(lane.get("send_hi_to_lo", false))):
			continue

		var t0 := int(lane.get("t0_ms", now))
		var progress := clampf(float(now - t0) / float(LANE_BUILD_MS), 0.0, 1.0)

		if progress != float(lane.get("progress", 0.0)):
			lane["progress"] = progress
			lanes[key] = lane
			emit_signal("lane_updated", lane)

		if progress >= 1.0:
			lane["active"] = true
			lane["progress"] = 1.0
			lanes[key] = lane
			emit_signal("lane_updated", lane)
			_sync_dirty = true

	if _sync_dirty:
		_sync_to_state()


func tick_lane_fronts(dt: float) -> void:
	if state == null:
		return
	if OpsState.is_ending_or_ended():
		return
	if dt <= 0.0:
		return
	var now_ms := Time.get_ticks_msec()
	for lane_any in state.lanes:
		var lane_id := -1
		var send_a := false
		var send_b := false
		if lane_any is LaneData:
			var l: LaneData = lane_any
			lane_id = int(l.id)
			send_a = bool(l.send_a)
			send_b = bool(l.send_b)
			if l.establish_a or l.establish_b:
				if int(l.establish_t0_ms) <= 0:
					l.establish_t0_ms = now_ms
				var progress := clampf(float(now_ms - int(l.establish_t0_ms)) / float(LANE_BUILD_MS), 0.0, 1.0)
				l.build_t = progress
				var was_built := bool(_build_complete_logged.get(lane_id, false))
				var now_built := progress >= 1.0
				if now_built:
					l.build_t = 1.0
					var side := "A" if l.establish_a else ("B" if l.establish_b else "")
					l.establish_a = false
					l.establish_b = false
					if not was_built:
						_build_complete_logged[lane_id] = true
						SFLog.info("LANE_BUILD_COMPLETE", {
							"lane_id": lane_id,
							"side": side
						})
				elif was_built:
					_build_complete_logged[lane_id] = false
			elif l.build_t <= 0.0:
				l.build_t = 1.0
		elif lane_any is Dictionary:
			var d: Dictionary = lane_any as Dictionary
			lane_id = int(d.get("lane_id", d.get("id", -1)))
			send_a = bool(d.get("send_a", false))
			send_b = bool(d.get("send_b", false))
		if lane_id <= 0:
			continue
		var t: float = float(OpsState.lane_front_by_lane_id.get(lane_id, 0.5))
		var dir := 0.0
		if send_a and not send_b:
			dir = 1.0
		elif send_b and not send_a:
			dir = -1.0
		if dir != 0.0:
			t = clampf(t + dir * LANE_FRONT_SPEED * dt, 0.05, 0.95)
		OpsState.lane_front_by_lane_id[lane_id] = t
		var was_established := bool(_established_by_lane_id.get(lane_id, false))
		var now_established := t >= LANE_ESTABLISH_EPS
		if now_established and not was_established:
			_established_by_lane_id[lane_id] = true
			var src := -1
			var dst := -1
			if send_a and not send_b:
				src = int(lane_any.a_id) if lane_any is LaneData else int((lane_any as Dictionary).get("a_id", -1))
				dst = int(lane_any.b_id) if lane_any is LaneData else int((lane_any as Dictionary).get("b_id", -1))
			elif send_b and not send_a:
				src = int(lane_any.b_id) if lane_any is LaneData else int((lane_any as Dictionary).get("b_id", -1))
				dst = int(lane_any.a_id) if lane_any is LaneData else int((lane_any as Dictionary).get("a_id", -1))
			var a_id := int(lane_any.a_id) if lane_any is LaneData else int((lane_any as Dictionary).get("a_id", -1))
			var b_id := int(lane_any.b_id) if lane_any is LaneData else int((lane_any as Dictionary).get("b_id", -1))
			SFLog.info("LANE_ESTABLISHED", {
				"lane_id": lane_id,
				"a_id": a_id,
				"b_id": b_id,
				"src": src,
				"dst": dst,
				"front_t": t
			})
		elif not now_established and was_established:
			_established_by_lane_id[lane_id] = false


func _sync_to_state() -> void:
	_sync_dirty = false
	if state == null:
		return
	if OpsState.is_ending_or_ended():
		return

	# Build lookup of previous LaneData by canonical key.
	var prev_by_key: Dictionary = {}
	for lane in state.lanes:
		if lane is LaneData:
			var ld: LaneData = lane
			prev_by_key[state.lane_key(int(ld.a_id), int(ld.b_id))] = ld

	var new_lanes: Array[LaneData] = []

	for lane in lanes.values():
		if not bool(lane.get("active", false)):
			continue

		var lo := int(lane.get("lo", lane.get("a_id", -1)))
		var hi := int(lane.get("hi", lane.get("b_id", -1)))
		if lo <= 0 or hi <= 0 or lo == hi:
			continue

		var key := state.lane_key(lo, hi)
		var prev: LaneData = prev_by_key.get(key)

		# Preserve original a/b ordering if lane existed previously.
		var a_id := lo
		var b_id := hi
		if prev != null:
			a_id = int(prev.a_id)
			b_id = int(prev.b_id)

		var send_lo_to_hi := bool(lane.get("send_lo_to_hi", false))
		var send_hi_to_lo := bool(lane.get("send_hi_to_lo", false))

		var send_a := false
		var send_b := false
		if a_id == lo and b_id == hi:
			send_a = send_lo_to_hi
			send_b = send_hi_to_lo
		else:
			send_a = send_hi_to_lo
			send_b = send_lo_to_hi

		var dir := int(lane.get("dir", (prev.dir if prev != null else 0)))
		if dir == 0:
			if send_a and not send_b:
				dir = 1
			elif send_b and not send_a:
				dir = -1

		var lane_id := int(lane.get("id", (prev.id if prev != null else _alloc_lane_id())))

		var lane_data := LaneData.new(
			lane_id,
			a_id,
			b_id,
			dir,
			send_a,
			send_b,
			float(lane.get("a_pressure", (prev.a_pressure if prev != null else 0.0))),
			float(lane.get("b_pressure", (prev.b_pressure if prev != null else 0.0))),
			float(lane.get("a_stream_len", (prev.a_stream_len if prev != null else 0.0))),
			float(lane.get("b_stream_len", (prev.b_stream_len if prev != null else 0.0))),
			float(lane.get("build_t", (prev.build_t if prev != null else 1.0))),
			float(lane.get("split_t", (prev.last_impact_f if prev != null else 0.5))),
			bool(lane.get("establish_a", (prev.establish_a if prev != null else false))),
			bool(lane.get("establish_b", (prev.establish_b if prev != null else false))),
			int(lane.get("establish_t0_ms", (prev.establish_t0_ms if prev != null else 0))),
			float(lane.get("spawn_accum_a_ms", (prev.spawn_accum_a_ms if prev != null else 0.0))),
			float(lane.get("spawn_accum_b_ms", (prev.spawn_accum_b_ms if prev != null else 0.0))),
			bool(lane.get("retract_a", (prev.retract_a if prev != null else false))),
			bool(lane.get("retract_b", (prev.retract_b if prev != null else false)))
		)

		new_lanes.append(lane_data)

	state.lanes = new_lanes
	state.rebuild_indexes()


func _alloc_lane_id() -> int:
	var lane_id := _next_lane_id
	_next_lane_id += 1
	return lane_id


func _lane_key(a_id: int, b_id: int) -> String:
	var lo := mini(a_id, b_id)
	var hi := maxi(a_id, b_id)
	return "%d:%d" % [lo, hi]


func _make_lane(lo: int, hi: int, lane_id: int = -1) -> Dictionary:
	var id := lane_id
	if id <= 0:
		id = _alloc_lane_id()
	return {
		"id": id,
		"lo": lo,
		"hi": hi,
		"a_id": lo,
		"b_id": hi,
		"t0_ms": Time.get_ticks_msec(),
		"progress": 0.0,
		"active": false,
		"send_lo_to_hi": false,
		"send_hi_to_lo": false
	}


func _get_outgoing_lanes(hive_id: int) -> Array:
	var out := []
	for lane in lanes.values():
		var lo := int(lane.get("lo", -1))
		var hi := int(lane.get("hi", -1))
		if lo == hive_id and bool(lane.get("send_lo_to_hi", false)):
			out.append(lane)
		elif hi == hive_id and bool(lane.get("send_hi_to_lo", false)):
			out.append(lane)
	return out


func _can_connect_segment(a_id: int, b_id: int, a_pos: Vector2, b_pos: Vector2) -> bool:
	for blk in blockers:
		if blk.has("id"):
			var blk_id := int(blk.get("id", -1))
			if blk_id == a_id or blk_id == b_id:
				continue
		var c: Vector2 = blk.get("pos", Vector2.ZERO)
		var r: float = float(blk.get("r", 0.0))
		var closest := Geometry2D.get_closest_point_to_segment(c, a_pos, b_pos)
		if c.distance_to(closest) < r:
			return false
	return true
