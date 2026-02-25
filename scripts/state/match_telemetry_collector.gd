class_name MatchTelemetryCollector
extends RefCounted

const MatchTelemetryModelScript = preload("res://scripts/state/match_telemetry_model.gd")

const SAVE_DIR_PATH: String = "user://matches"
const BUFF_IMPACT_WINDOW_MS: int = 6000
const IDLE_GAP_S: float = 2.0
const OVERCOMMIT_WINDOW_S: float = 5.0
const OVERCOMMIT_RATIO: float = 0.70
const SWING_WINDOW_S: float = 10.0
const SWING_STEP_MS: int = 1000

var _model: Variant = MatchTelemetryModelScript.new()
var _active_player_ids: Array[int] = []
var _started: bool = false
var _finalized: bool = false
var _start_utc_ms: int = 0
var _end_utc_ms: int = 0
var _total_swarm_collisions: int = 0

var _units_produced_by_player: Dictionary = {}
var _idle_time_s_by_player: Dictionary = {}
var _last_production_seen_by_player: Dictionary = {}
var _last_production_change_ms_by_player: Dictionary = {}
var _units_lost_by_player: Dictionary = {}
var _hive_damage_dealt_by_player: Dictionary = {}
var _hive_damage_taken_by_player: Dictionary = {}
var _lane_control_time_s_by_player: Dictionary = {}
var _overcommit_events_by_player: Dictionary = {}
var _overcommit_window_s_by_player: Dictionary = {}
var _overcommit_active_by_player: Dictionary = {}

var _damage_events: Array[Dictionary] = []
var _buff_windows: Array[Dictionary] = []

func _ensure_model() -> bool:
	if _model == null:
		_model = MatchTelemetryModelScript.new()
	return _model != null

func reset() -> void:
	if _ensure_model():
		_model.reset()
	_active_player_ids.clear()
	_started = false
	_finalized = false
	_start_utc_ms = 0
	_end_utc_ms = 0
	_total_swarm_collisions = 0
	_units_produced_by_player.clear()
	_idle_time_s_by_player.clear()
	_last_production_seen_by_player.clear()
	_last_production_change_ms_by_player.clear()
	_units_lost_by_player.clear()
	_hive_damage_dealt_by_player.clear()
	_hive_damage_taken_by_player.clear()
	_lane_control_time_s_by_player.clear()
	_overcommit_events_by_player.clear()
	_overcommit_window_s_by_player.clear()
	_overcommit_active_by_player.clear()
	_damage_events.clear()
	_buff_windows.clear()

func is_active() -> bool:
	return _started and not _finalized

func begin_match(
	match_id: String,
	season_id: String,
	map_id: String,
	match_type: int,
	player_ids: Array[int],
	start_utc_ms: int
) -> void:
	reset()
	if not _ensure_model():
		return
	_started = true
	_start_utc_ms = maxi(0, start_utc_ms)
	_active_player_ids = _sanitize_player_ids(player_ids)
	_model.metadata = {
		"match_id": match_id,
		"season_id": season_id,
		"map_id": map_id,
		"match_type": int(match_type),
		"start_utc_ms": _start_utc_ms,
		"end_utc_ms": 0,
		"winner_player_id": 0,
		"duration_s": 0.0
	}
	for player_id in _active_player_ids:
		_units_produced_by_player[player_id] = 0
		_idle_time_s_by_player[player_id] = 0.0
		_last_production_seen_by_player[player_id] = 0
		_last_production_change_ms_by_player[player_id] = 0
		_units_lost_by_player[player_id] = 0
		_hive_damage_dealt_by_player[player_id] = 0
		_hive_damage_taken_by_player[player_id] = 0
		_lane_control_time_s_by_player[player_id] = 0.0
		_overcommit_events_by_player[player_id] = 0
		_overcommit_window_s_by_player[player_id] = 0.0
		_overcommit_active_by_player[player_id] = false

func record_unit_produced(t_ms: int, player_id: int, count: int = 1) -> void:
	if not is_active():
		return
	if player_id <= 0 or count <= 0:
		return
	_ensure_player_slot(player_id)
	var current: int = int(_units_produced_by_player.get(player_id, 0))
	_units_produced_by_player[player_id] = current + count
	_model.events.append({
		"e": int(MatchTelemetryModelScript.EVENT_PRODUCTION),
		"t": maxi(0, t_ms),
		"p": player_id,
		"c": count
	})

func record_collision_event(
	t_ms: int,
	lane_id: int,
	position_scalar: float,
	units_a: int,
	units_b: int,
	owner_a: int,
	owner_b: int,
	units_lost_each: int
) -> void:
	if not is_active():
		return
	_total_swarm_collisions += 1
	var clamped_pos: float = clampf(position_scalar, 0.0, 1.0)
	var lost_each: int = maxi(0, units_lost_each)
	if owner_a > 0 and lost_each > 0:
		_ensure_player_slot(owner_a)
		_units_lost_by_player[owner_a] = int(_units_lost_by_player.get(owner_a, 0)) + lost_each
	if owner_b > 0 and lost_each > 0:
		_ensure_player_slot(owner_b)
		_units_lost_by_player[owner_b] = int(_units_lost_by_player.get(owner_b, 0)) + lost_each
	_model.events.append({
		"e": int(MatchTelemetryModelScript.EVENT_COLLISION),
		"t": maxi(0, t_ms),
		"l": lane_id,
		"s": clamped_pos,
		"a": maxi(0, units_a),
		"b": maxi(0, units_b),
		"oa": owner_a,
		"ob": owner_b
	})

func record_hive_damage(t_ms: int, attacker_player_id: int, defender_player_id: int, damage_amount: int) -> void:
	if not is_active():
		return
	var damage: int = maxi(0, damage_amount)
	if damage <= 0:
		return
	if attacker_player_id > 0:
		_ensure_player_slot(attacker_player_id)
		_hive_damage_dealt_by_player[attacker_player_id] = int(_hive_damage_dealt_by_player.get(attacker_player_id, 0)) + damage
	if defender_player_id > 0:
		_ensure_player_slot(defender_player_id)
		_hive_damage_taken_by_player[defender_player_id] = int(_hive_damage_taken_by_player.get(defender_player_id, 0)) + damage
	_damage_events.append({
		"t": maxi(0, t_ms),
		"atk": attacker_player_id,
		"def": defender_player_id,
		"dmg": damage
	})
	_model.events.append({
		"e": int(MatchTelemetryModelScript.EVENT_HIVE_DAMAGE),
		"t": maxi(0, t_ms),
		"atk": attacker_player_id,
		"def": defender_player_id,
		"dmg": damage
	})

func record_buff_activation(
	t_ms: int,
	player_id: int,
	buff_id: String,
	scope: String,
	target_id: Variant = ""
) -> void:
	if not is_active():
		return
	if player_id <= 0:
		return
	_ensure_player_slot(player_id)
	_model.events.append({
		"e": int(MatchTelemetryModelScript.EVENT_BUFF_ACTIVATION),
		"t": maxi(0, t_ms),
		"p": player_id,
		"id": buff_id,
		"scope": scope,
		"target": target_id,
		"impact_hd": 0,
		"impact_ul": 0
	})
	var event_index: int = _model.events.size() - 1
	_buff_windows.append({
		"event_index": event_index,
		"player_id": player_id,
		"end_ms": maxi(0, t_ms) + BUFF_IMPACT_WINDOW_MS,
		"base_hd": int(_hive_damage_dealt_by_player.get(player_id, 0)),
		"base_ul": int(_units_lost_by_player.get(player_id, 0))
	})

func sample_state(now_ms: int, dt_s: float, state: GameState) -> void:
	if not is_active():
		return
	if state == null:
		return
	var sample_dt_s: float = maxf(0.0, dt_s)
	if sample_dt_s <= 0.0:
		return
	var sample_now_ms: int = maxi(0, now_ms)
	_expire_buff_windows(sample_now_ms)
	var owned_hive_counts: Dictionary = _owned_hive_counts(state)
	_sample_production_idle(sample_now_ms, sample_dt_s, owned_hive_counts)
	_sample_lane_control(sample_dt_s, state)
	_sample_overcommit(sample_dt_s, state)

func finalize_match(winner_player_id: int, end_utc_ms: int) -> Variant:
	if not _started:
		return _model
	if _finalized:
		return _model
	_finalized = true
	_end_utc_ms = maxi(_start_utc_ms, end_utc_ms)
	var duration_ms: int = maxi(0, _end_utc_ms - _start_utc_ms)
	var duration_s: float = float(duration_ms) / 1000.0
	_expire_buff_windows(2147483647)
	_model.metadata["end_utc_ms"] = _end_utc_ms
	_model.metadata["winner_player_id"] = winner_player_id
	_model.metadata["duration_s"] = duration_s
	_model.metrics = _build_metrics(duration_s)
	return _model

func attach_analysis_summary(summary: Dictionary) -> void:
	_model.analysis_summary = summary.duplicate(true)

func save_to_user(model_override: Variant = null) -> Dictionary:
	var model: Variant = _model if model_override == null else model_override
	var payload: Dictionary = model.to_dict()
	var match_id: String = _sanitize_match_id(str((payload.get("metadata", {}) as Dictionary).get("match_id", "")))
	if match_id.is_empty():
		match_id = "match_%d" % int(Time.get_unix_time_from_system())
	var mk_err: int = DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "mkdir_failed", "code": mk_err}
	var save_path: String = "%s/%s.json" % [SAVE_DIR_PATH, match_id]
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed", "path": save_path}
	file.store_string(JSON.stringify(payload, "\t"))
	return {"ok": true, "path": save_path}

func load_from_user(match_id: String) -> Variant:
	var clean_id: String = _sanitize_match_id(match_id)
	if clean_id.is_empty():
		return MatchTelemetryModelScript.new()
	var path: String = "%s/%s.json" % [SAVE_DIR_PATH, clean_id]
	if not FileAccess.file_exists(path):
		return MatchTelemetryModelScript.new()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return MatchTelemetryModelScript.new()
	var parser: JSON = JSON.new()
	var err: int = parser.parse(file.get_as_text())
	if err != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return MatchTelemetryModelScript.new()
	var restored: Variant = MatchTelemetryModelScript.from_dict(parser.data as Dictionary)
	if restored == null:
		return MatchTelemetryModelScript.new()
	return restored

func _build_metrics(duration_s: float) -> Dictionary:
	var players: Array[int] = _active_player_ids.duplicate()
	players.sort()
	var produced: Array = []
	var idle_time: Array = []
	var avg_rate: Array = []
	var lost: Array = []
	var damage_dealt: Array = []
	var damage_taken: Array = []
	var lane_control: Array = []
	var overcommit: Array = []
	var player_index: Dictionary = {}
	for i in range(players.size()):
		var player_id: int = players[i]
		player_index[str(player_id)] = i
		var produced_count: int = int(_units_produced_by_player.get(player_id, 0))
		var idle_value: float = float(_idle_time_s_by_player.get(player_id, 0.0))
		var avg_value: float = 0.0
		if duration_s > 0.0:
			avg_value = float(produced_count) / duration_s
		produced.append(produced_count)
		idle_time.append(idle_value)
		avg_rate.append(avg_value)
		lost.append(int(_units_lost_by_player.get(player_id, 0)))
		damage_dealt.append(int(_hive_damage_dealt_by_player.get(player_id, 0)))
		damage_taken.append(int(_hive_damage_taken_by_player.get(player_id, 0)))
		lane_control.append(float(_lane_control_time_s_by_player.get(player_id, 0.0)))
		overcommit.append(int(_overcommit_events_by_player.get(player_id, 0)))
	var swing_moment_ms: int = _compute_swing_moment_ms(duration_s)
	return {
		"players": players,
		"player_index": player_index,
		"total_units_produced_by_player": produced,
		"production_idle_time_s_by_player": idle_time,
		"average_production_rate_by_player": avg_rate,
		"total_swarm_collisions": _total_swarm_collisions,
		"total_units_lost_by_player": lost,
		"hive_damage_dealt_by_player": damage_dealt,
		"hive_damage_taken_by_player": damage_taken,
		"lane_control_time_s_by_player": lane_control,
		"overcommit_events_by_player": overcommit,
		"swing_moment_ms": swing_moment_ms
	}

func _sample_production_idle(now_ms: int, dt_s: float, owned_hive_counts: Dictionary) -> void:
	var idle_gap_ms: int = int(round(IDLE_GAP_S * 1000.0))
	for player_id in _active_player_ids:
		var produced_now: int = int(_units_produced_by_player.get(player_id, 0))
		var produced_last: int = int(_last_production_seen_by_player.get(player_id, 0))
		if produced_now != produced_last:
			_last_production_seen_by_player[player_id] = produced_now
			_last_production_change_ms_by_player[player_id] = now_ms
		var owned_hives: int = int(owned_hive_counts.get(player_id, 0))
		if owned_hives <= 0:
			continue
		var last_change_ms: int = int(_last_production_change_ms_by_player.get(player_id, now_ms))
		var gap_ms: int = now_ms - last_change_ms
		if gap_ms > idle_gap_ms:
			_idle_time_s_by_player[player_id] = float(_idle_time_s_by_player.get(player_id, 0.0)) + dt_s

func _sample_lane_control(dt_s: float, state: GameState) -> void:
	var lane_counts_by_player: Dictionary = {}
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		var a_hive: HiveData = state.find_hive_by_id(int(lane.a_id))
		var b_hive: HiveData = state.find_hive_by_id(int(lane.b_id))
		if a_hive == null or b_hive == null:
			continue
		var a_pressure: float = float(lane.a_pressure)
		var b_pressure: float = float(lane.b_pressure)
		if is_equal_approx(a_pressure, b_pressure):
			continue
		var leader_player_id: int = int(a_hive.owner_id) if a_pressure > b_pressure else int(b_hive.owner_id)
		if leader_player_id <= 0:
			continue
		lane_counts_by_player[leader_player_id] = int(lane_counts_by_player.get(leader_player_id, 0)) + 1
	var leader_id: int = 0
	var leader_count: int = 0
	var tied: bool = false
	for player_id_any in lane_counts_by_player.keys():
		var player_id: int = int(player_id_any)
		var lane_count: int = int(lane_counts_by_player.get(player_id, 0))
		if lane_count > leader_count:
			leader_count = lane_count
			leader_id = player_id
			tied = false
		elif lane_count == leader_count and lane_count > 0:
			tied = true
	if leader_id > 0 and not tied:
		_ensure_player_slot(leader_id)
		_lane_control_time_s_by_player[leader_id] = float(_lane_control_time_s_by_player.get(leader_id, 0.0)) + dt_s

func _sample_overcommit(dt_s: float, state: GameState) -> void:
	var lane_pressure_by_player: Dictionary = {}
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		var lane_id: int = int(lane.id)
		if lane_id <= 0:
			continue
		var a_hive: HiveData = state.find_hive_by_id(int(lane.a_id))
		var b_hive: HiveData = state.find_hive_by_id(int(lane.b_id))
		if a_hive == null or b_hive == null:
			continue
		if bool(lane.send_a):
			var player_a: int = int(a_hive.owner_id)
			if player_a > 0:
				_add_lane_pressure_proxy(lane_pressure_by_player, player_a, lane_id, 1.0)
		if bool(lane.send_b):
			var player_b: int = int(b_hive.owner_id)
			if player_b > 0:
				_add_lane_pressure_proxy(lane_pressure_by_player, player_b, lane_id, 1.0)
	for player_id in _active_player_ids:
		var lanes_any: Variant = lane_pressure_by_player.get(player_id, {})
		var total_pressure: float = 0.0
		var max_lane_pressure: float = 0.0
		if typeof(lanes_any) == TYPE_DICTIONARY:
			var lanes_dict: Dictionary = lanes_any as Dictionary
			for pressure_any in lanes_dict.values():
				var pressure: float = maxf(0.0, float(pressure_any))
				total_pressure += pressure
				if pressure > max_lane_pressure:
					max_lane_pressure = pressure
		var ratio: float = 0.0
		if total_pressure > 0.0:
			ratio = max_lane_pressure / total_pressure
		if total_pressure > 0.0 and ratio > OVERCOMMIT_RATIO:
			var running_window: float = float(_overcommit_window_s_by_player.get(player_id, 0.0)) + dt_s
			_overcommit_window_s_by_player[player_id] = running_window
			var active_window: bool = bool(_overcommit_active_by_player.get(player_id, false))
			if running_window >= OVERCOMMIT_WINDOW_S and not active_window:
				_overcommit_events_by_player[player_id] = int(_overcommit_events_by_player.get(player_id, 0)) + 1
				_overcommit_active_by_player[player_id] = true
		else:
			_overcommit_window_s_by_player[player_id] = 0.0
			_overcommit_active_by_player[player_id] = false

func _compute_swing_moment_ms(duration_s: float) -> int:
	if _damage_events.is_empty():
		return 0
	var duration_ms: int = maxi(0, int(round(duration_s * 1000.0)))
	if duration_ms <= 0:
		for event in _damage_events:
			var first_t: int = int(event.get("t", 0))
			return maxi(0, first_t)
		return 0
	var window_ms: int = int(round(SWING_WINDOW_S * 1000.0))
	if window_ms <= 0:
		window_ms = 10000
	var best_start: int = 0
	var best_magnitude: int = -1
	var max_start: int = maxi(0, duration_ms - window_ms)
	var start_ms: int = 0
	while start_ms <= max_start:
		var window_end: int = start_ms + window_ms
		var damage_sum: int = 0
		for event in _damage_events:
			var event_t: int = int(event.get("t", 0))
			if event_t < start_ms or event_t >= window_end:
				continue
			damage_sum += maxi(0, int(event.get("dmg", 0)))
		if damage_sum > best_magnitude:
			best_magnitude = damage_sum
			best_start = start_ms
		start_ms += SWING_STEP_MS
	return best_start

func _expire_buff_windows(now_ms: int) -> void:
	if _buff_windows.is_empty():
		return
	var keep: Array[Dictionary] = []
	for window in _buff_windows:
		var end_ms: int = int(window.get("end_ms", 0))
		if now_ms < end_ms and not _finalized:
			keep.append(window)
			continue
		var event_index: int = int(window.get("event_index", -1))
		var player_id: int = int(window.get("player_id", 0))
		if event_index < 0 or event_index >= _model.events.size():
			continue
		var base_hd: int = int(window.get("base_hd", 0))
		var base_ul: int = int(window.get("base_ul", 0))
		var now_hd: int = int(_hive_damage_dealt_by_player.get(player_id, 0))
		var now_ul: int = int(_units_lost_by_player.get(player_id, 0))
		var event_row: Dictionary = _model.events[event_index]
		event_row["impact_hd"] = maxi(0, now_hd - base_hd)
		event_row["impact_ul"] = maxi(0, now_ul - base_ul)
		_model.events[event_index] = event_row
	_buff_windows = keep

func _owned_hive_counts(state: GameState) -> Dictionary:
	var counts: Dictionary = {}
	for hive_any in state.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		if owner_id <= 0:
			continue
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func _add_lane_pressure_proxy(storage: Dictionary, player_id: int, lane_id: int, amount: float) -> void:
	var by_lane_any: Variant = storage.get(player_id, {})
	var by_lane: Dictionary = by_lane_any as Dictionary if typeof(by_lane_any) == TYPE_DICTIONARY else {}
	by_lane[lane_id] = float(by_lane.get(lane_id, 0.0)) + amount
	storage[player_id] = by_lane

func _ensure_player_slot(player_id: int) -> void:
	if player_id <= 0:
		return
	if not _active_player_ids.has(player_id):
		_active_player_ids.append(player_id)
		_active_player_ids.sort()
	if not _units_produced_by_player.has(player_id):
		_units_produced_by_player[player_id] = 0
	if not _idle_time_s_by_player.has(player_id):
		_idle_time_s_by_player[player_id] = 0.0
	if not _last_production_seen_by_player.has(player_id):
		_last_production_seen_by_player[player_id] = 0
	if not _last_production_change_ms_by_player.has(player_id):
		_last_production_change_ms_by_player[player_id] = 0
	if not _units_lost_by_player.has(player_id):
		_units_lost_by_player[player_id] = 0
	if not _hive_damage_dealt_by_player.has(player_id):
		_hive_damage_dealt_by_player[player_id] = 0
	if not _hive_damage_taken_by_player.has(player_id):
		_hive_damage_taken_by_player[player_id] = 0
	if not _lane_control_time_s_by_player.has(player_id):
		_lane_control_time_s_by_player[player_id] = 0.0
	if not _overcommit_events_by_player.has(player_id):
		_overcommit_events_by_player[player_id] = 0
	if not _overcommit_window_s_by_player.has(player_id):
		_overcommit_window_s_by_player[player_id] = 0.0
	if not _overcommit_active_by_player.has(player_id):
		_overcommit_active_by_player[player_id] = false

func _sanitize_player_ids(player_ids: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for player_id in player_ids:
		var clean_id: int = int(player_id)
		if clean_id <= 0:
			continue
		if out.has(clean_id):
			continue
		out.append(clean_id)
	out.sort()
	return out

func _sanitize_match_id(match_id: String) -> String:
	var out: String = match_id.strip_edges()
	out = out.replace("/", "_")
	out = out.replace("\\", "_")
	out = out.replace(":", "_")
	out = out.replace(" ", "_")
	out = out.replace("|", "_")
	return out
