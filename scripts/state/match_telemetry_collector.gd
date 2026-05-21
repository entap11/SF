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
const EARLY_WINDOW_MS: int = 90000
const REACTION_RESPONSE_WINDOW_MS: int = 12000
const REACTION_THREAT_COOLDOWN_MS: int = 4000
const REPLAY_SAMPLE_INTERVAL_MS: int = 500
const REPLAY_MAX_UNITS_PER_FRAME: int = 220
const VIDEO_REPLAY_FPS: int = 30
const VIDEO_REPLAY_WIDTH: int = 1080
const VIDEO_REPLAY_HEIGHT: int = 1920
const VIDEO_REPLAY_DEFAULT_CLIP_MS: int = 30000

var _model: Variant = MatchTelemetryModelScript.new()
var _active_player_ids: Array[int] = []
var _started: bool = false
var _finalized: bool = false
var _start_utc_ms: int = 0
var _end_utc_ms: int = 0
var _total_swarm_collisions: int = 0

var _units_produced_by_player: Dictionary = {}
var _barracks_units_produced_by_player: Dictionary = {}
var _swarms_sent_by_player: Dictionary = {}
var _meaningful_actions_by_player: Dictionary = {}
var _lane_reversals_by_player: Dictionary = {}
var _units_arrived_friendly_hive_by_player: Dictionary = {}
var _units_arrived_enemy_hive_by_player: Dictionary = {}
var _units_arrived_npc_hive_by_player: Dictionary = {}
var _idle_time_s_by_player: Dictionary = {}
var _last_production_seen_by_player: Dictionary = {}
var _last_production_change_ms_by_player: Dictionary = {}
var _units_lost_by_player: Dictionary = {}
var _tower_units_killed_by_player: Dictionary = {}
var _unit_deaths_by_victim_player: Dictionary = {}
var _unit_deaths_by_killer_player: Dictionary = {}
var _hive_damage_dealt_by_player: Dictionary = {}
var _hive_damage_taken_by_player: Dictionary = {}
var _lane_control_time_s_by_player: Dictionary = {}
var _tower_control_time_s_by_player: Dictionary = {}
var _barracks_control_time_s_by_player: Dictionary = {}
var _active_lane_slots_time_s_by_player: Dictionary = {}
var _lane_budget_slots_time_s_by_player: Dictionary = {}
var _fully_utilized_lane_time_s_by_player: Dictionary = {}
var _underutilized_lane_time_s_by_player: Dictionary = {}
var _early_active_lane_slots_time_s_by_player: Dictionary = {}
var _early_lane_budget_slots_time_s_by_player: Dictionary = {}
var _board_control_area_by_player: Dictionary = {}
var _board_control_peak_share_by_player: Dictionary = {}
var _early_board_control_area_by_player: Dictionary = {}
var _overcommit_events_by_player: Dictionary = {}
var _overcommit_window_s_by_player: Dictionary = {}
var _overcommit_active_by_player: Dictionary = {}
var _intent_total_by_player: Dictionary = {}
var _intent_success_by_player: Dictionary = {}
var _intent_fail_by_player: Dictionary = {}
var _intent_budget_fail_by_player: Dictionary = {}
var _intent_no_lane_fail_by_player: Dictionary = {}

var _damage_events: Array[Dictionary] = []
var _buff_windows: Array[Dictionary] = []
var _replay_frames: Array[Dictionary] = []
var _replay_map: Dictionary = {}
var _replay_last_sample_ms: int = -999999

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
	_barracks_units_produced_by_player.clear()
	_swarms_sent_by_player.clear()
	_meaningful_actions_by_player.clear()
	_lane_reversals_by_player.clear()
	_units_arrived_friendly_hive_by_player.clear()
	_units_arrived_enemy_hive_by_player.clear()
	_units_arrived_npc_hive_by_player.clear()
	_idle_time_s_by_player.clear()
	_last_production_seen_by_player.clear()
	_last_production_change_ms_by_player.clear()
	_units_lost_by_player.clear()
	_tower_units_killed_by_player.clear()
	_unit_deaths_by_victim_player.clear()
	_unit_deaths_by_killer_player.clear()
	_hive_damage_dealt_by_player.clear()
	_hive_damage_taken_by_player.clear()
	_lane_control_time_s_by_player.clear()
	_tower_control_time_s_by_player.clear()
	_barracks_control_time_s_by_player.clear()
	_active_lane_slots_time_s_by_player.clear()
	_lane_budget_slots_time_s_by_player.clear()
	_fully_utilized_lane_time_s_by_player.clear()
	_underutilized_lane_time_s_by_player.clear()
	_early_active_lane_slots_time_s_by_player.clear()
	_early_lane_budget_slots_time_s_by_player.clear()
	_board_control_area_by_player.clear()
	_board_control_peak_share_by_player.clear()
	_early_board_control_area_by_player.clear()
	_overcommit_events_by_player.clear()
	_overcommit_window_s_by_player.clear()
	_overcommit_active_by_player.clear()
	_intent_total_by_player.clear()
	_intent_success_by_player.clear()
	_intent_fail_by_player.clear()
	_intent_budget_fail_by_player.clear()
	_intent_no_lane_fail_by_player.clear()
	_damage_events.clear()
	_buff_windows.clear()
	_replay_frames.clear()
	_replay_map.clear()
	_replay_last_sample_ms = -999999

func is_active() -> bool:
	return _started and not _finalized

func begin_match(
	match_id: String,
	season_id: String,
	map_id: String,
	match_type: int,
	player_ids: Array[int],
	start_utc_ms: int,
	metadata_overrides: Dictionary = {}
) -> void:
	reset()
	if not _ensure_model():
		return
	_started = true
	_start_utc_ms = maxi(0, start_utc_ms)
	_active_player_ids = _sanitize_player_ids(player_ids)
	var metadata: Dictionary = {
		"match_id": match_id,
		"season_id": season_id,
		"map_id": map_id,
		"match_type": int(match_type),
		"start_utc_ms": _start_utc_ms,
		"end_utc_ms": 0,
		"winner_player_id": 0,
		"duration_s": 0.0
	}
	for key_any in metadata_overrides.keys():
		metadata[key_any] = metadata_overrides.get(key_any)
	_model.metadata = metadata
	for player_id in _active_player_ids:
		_units_produced_by_player[player_id] = 0
		_barracks_units_produced_by_player[player_id] = 0
		_swarms_sent_by_player[player_id] = 0
		_meaningful_actions_by_player[player_id] = 0
		_lane_reversals_by_player[player_id] = 0
		_units_arrived_friendly_hive_by_player[player_id] = 0
		_units_arrived_enemy_hive_by_player[player_id] = 0
		_units_arrived_npc_hive_by_player[player_id] = 0
		_idle_time_s_by_player[player_id] = 0.0
		_last_production_seen_by_player[player_id] = 0
		_last_production_change_ms_by_player[player_id] = 0
		_units_lost_by_player[player_id] = 0
		_tower_units_killed_by_player[player_id] = 0
		_unit_deaths_by_victim_player[player_id] = 0
		_unit_deaths_by_killer_player[player_id] = 0
		_hive_damage_dealt_by_player[player_id] = 0
		_hive_damage_taken_by_player[player_id] = 0
		_lane_control_time_s_by_player[player_id] = 0.0
		_tower_control_time_s_by_player[player_id] = 0.0
		_barracks_control_time_s_by_player[player_id] = 0.0
		_active_lane_slots_time_s_by_player[player_id] = 0.0
		_lane_budget_slots_time_s_by_player[player_id] = 0.0
		_fully_utilized_lane_time_s_by_player[player_id] = 0.0
		_underutilized_lane_time_s_by_player[player_id] = 0.0
		_early_active_lane_slots_time_s_by_player[player_id] = 0.0
		_early_lane_budget_slots_time_s_by_player[player_id] = 0.0
		_board_control_area_by_player[player_id] = 0.0
		_board_control_peak_share_by_player[player_id] = 0.0
		_early_board_control_area_by_player[player_id] = 0.0
		_overcommit_events_by_player[player_id] = 0
		_overcommit_window_s_by_player[player_id] = 0.0
		_overcommit_active_by_player[player_id] = false
		_intent_total_by_player[player_id] = 0
		_intent_success_by_player[player_id] = 0
		_intent_fail_by_player[player_id] = 0
		_intent_budget_fail_by_player[player_id] = 0
		_intent_no_lane_fail_by_player[player_id] = 0

func record_unit_produced(t_ms: int, player_id: int, count: int = 1, source: String = "lane") -> void:
	if not is_active():
		return
	if player_id <= 0 or count <= 0:
		return
	_ensure_player_slot(player_id)
	var source_name: String = source.strip_edges().to_lower()
	var counts_as_production: bool = source_name != "pass_through" and source_name != "recall"
	if counts_as_production:
		var current: int = int(_units_produced_by_player.get(player_id, 0))
		_units_produced_by_player[player_id] = current + count
	if source_name == "barracks":
		_barracks_units_produced_by_player[player_id] = int(_barracks_units_produced_by_player.get(player_id, 0)) + count
	_model.events.append({
		"name": "UNIT_SPAWN",
		"e": int(MatchTelemetryModelScript.EVENT_PRODUCTION),
		"t": maxi(0, t_ms),
		"p": player_id,
		"c": count,
		"src": source_name
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
	_meaningful_actions_by_player[player_id] = int(_meaningful_actions_by_player.get(player_id, 0)) + 1
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

func record_action_event(t_ms: int, player_id: int, kind: String, payload: Dictionary = {}) -> void:
	if not is_active():
		return
	if player_id <= 0:
		return
	var clean_kind: String = kind.strip_edges().to_lower()
	if clean_kind == "":
		return
	_ensure_player_slot(player_id)
	if clean_kind == "swarm_send":
		_swarms_sent_by_player[player_id] = int(_swarms_sent_by_player.get(player_id, 0)) + 1
	if clean_kind == "lane_reverse":
		_lane_reversals_by_player[player_id] = int(_lane_reversals_by_player.get(player_id, 0)) + 1
	if _counts_as_meaningful_action(clean_kind):
		_meaningful_actions_by_player[player_id] = int(_meaningful_actions_by_player.get(player_id, 0)) + 1
	var event_row: Dictionary = {
		"e": int(MatchTelemetryModelScript.EVENT_ACTION),
		"t": maxi(0, t_ms),
		"p": player_id,
		"k": clean_kind
	}
	for key_any in payload.keys():
		event_row[key_any] = payload.get(key_any)
	_model.events.append(event_row)

func record_intent_event(
	t_ms: int,
	player_id: int,
	src_hive_id: int,
	dst_hive_id: int,
	intent: String,
	ok: bool,
	reason: String = "",
	lane_id: int = -1,
	context: Dictionary = {}
) -> void:
	if not is_active():
		return
	if player_id <= 0:
		return
	var clean_intent: String = intent.strip_edges().to_lower()
	if clean_intent.is_empty():
		clean_intent = "unknown"
	var clean_reason: String = reason.strip_edges().to_lower()
	_ensure_player_slot(player_id)
	_intent_total_by_player[player_id] = int(_intent_total_by_player.get(player_id, 0)) + 1
	if ok:
		_intent_success_by_player[player_id] = int(_intent_success_by_player.get(player_id, 0)) + 1
	else:
		_intent_fail_by_player[player_id] = int(_intent_fail_by_player.get(player_id, 0)) + 1
		if clean_reason == "budget":
			_intent_budget_fail_by_player[player_id] = int(_intent_budget_fail_by_player.get(player_id, 0)) + 1
		elif clean_reason == "no_lane":
			_intent_no_lane_fail_by_player[player_id] = int(_intent_no_lane_fail_by_player.get(player_id, 0)) + 1
	var event_row: Dictionary = {
		"e": int(MatchTelemetryModelScript.EVENT_INTENT),
		"t": maxi(0, t_ms),
		"p": player_id,
		"src": src_hive_id,
		"dst": dst_hive_id,
		"intent": clean_intent,
		"ok": ok,
		"reason": clean_reason,
		"lane_id": lane_id
	}
	for key_any in context.keys():
		event_row[key_any] = context.get(key_any)
	_model.events.append(event_row)

func record_unit_arrival(
	t_ms: int,
	player_id: int,
	target_hive_id: int,
	target_owner_before: int,
	target_owner_after: int,
	relation: String,
	arrive_source: String,
	amount: int
) -> void:
	if not is_active():
		return
	if player_id <= 0 or amount <= 0:
		return
	_ensure_player_slot(player_id)
	var clean_relation: String = relation.strip_edges().to_lower()
	var clean_source: String = arrive_source.strip_edges().to_lower()
	var count_as_landing: bool = clean_source != "recall"
	if count_as_landing:
		match clean_relation:
			"friendly":
				_units_arrived_friendly_hive_by_player[player_id] = int(_units_arrived_friendly_hive_by_player.get(player_id, 0)) + amount
			"enemy":
				_units_arrived_enemy_hive_by_player[player_id] = int(_units_arrived_enemy_hive_by_player.get(player_id, 0)) + amount
			"npc":
				_units_arrived_npc_hive_by_player[player_id] = int(_units_arrived_npc_hive_by_player.get(player_id, 0)) + amount
			_:
				pass
	_model.events.append({
		"name": "UNIT_LAND",
		"e": int(MatchTelemetryModelScript.EVENT_ARRIVAL),
		"t": maxi(0, t_ms),
		"p": player_id,
		"h": target_hive_id,
		"bo": target_owner_before,
		"ao": target_owner_after,
		"rel": clean_relation,
		"src": clean_source,
		"c": amount
	})

func record_unit_death(
	t_ms: int,
	victim_player_id: int,
	killer_player_id: int,
	cause: String,
	count: int = 1
) -> void:
	if not is_active():
		return
	var safe_victim_player_id: int = maxi(0, victim_player_id)
	var safe_killer_player_id: int = maxi(0, killer_player_id)
	var safe_count: int = maxi(0, count)
	if safe_victim_player_id <= 0 or safe_count <= 0:
		return
	_ensure_player_slot(safe_victim_player_id)
	_unit_deaths_by_victim_player[safe_victim_player_id] = int(_unit_deaths_by_victim_player.get(safe_victim_player_id, 0)) + safe_count
	if safe_killer_player_id > 0:
		_ensure_player_slot(safe_killer_player_id)
		_unit_deaths_by_killer_player[safe_killer_player_id] = int(_unit_deaths_by_killer_player.get(safe_killer_player_id, 0)) + safe_count
	_model.events.append({
		"name": "UNIT_DEATH",
		"e": int(MatchTelemetryModelScript.EVENT_UNIT_DEATH),
		"t": maxi(0, t_ms),
		"vp": safe_victim_player_id,
		"kp": safe_killer_player_id,
		"cause": cause.strip_edges().to_lower(),
		"c": safe_count
	})

func record_tower_kill(t_ms: int, player_id: int, tower_id: int, victim_owner_id: int, count: int = 1) -> void:
	if not is_active():
		return
	if player_id <= 0 or count <= 0:
		return
	_ensure_player_slot(player_id)
	_tower_units_killed_by_player[player_id] = int(_tower_units_killed_by_player.get(player_id, 0)) + count
	_model.events.append({
		"e": int(MatchTelemetryModelScript.EVENT_TOWER_KILL),
		"t": maxi(0, t_ms),
		"p": player_id,
		"tower_id": tower_id,
		"victim_owner": victim_owner_id,
		"c": count
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
	_sample_replay_frame(sample_now_ms, state)
	var early_dt_s: float = _early_window_overlap_s(sample_now_ms, sample_dt_s)
	_expire_buff_windows(sample_now_ms)
	var owned_hive_counts: Dictionary = _owned_hive_counts(state)
	_sample_production_idle(sample_now_ms, sample_dt_s, owned_hive_counts)
	_sample_lane_control(sample_dt_s, state)
	_sample_structure_control(sample_dt_s, state)
	_sample_open_budget(sample_dt_s, state, early_dt_s)
	_sample_board_control(sample_dt_s, state, early_dt_s)
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
	_model.totals = _build_totals()
	_model.replay = _build_replay_payload(duration_ms)
	_model.video_replay = _build_video_replay_payload(duration_ms)
	return _model

func _sample_replay_frame(t_ms: int, state: GameState) -> void:
	if state == null:
		return
	if _replay_map.is_empty():
		_replay_map = _build_replay_map(state)
	if not _replay_frames.is_empty() and t_ms - _replay_last_sample_ms < REPLAY_SAMPLE_INTERVAL_MS:
		return
	_replay_last_sample_ms = t_ms
	_replay_frames.append(_build_replay_frame(t_ms, state))

func _build_replay_payload(duration_ms: int) -> Dictionary:
	return {
		"schema_version": 1,
		"sample_ms": REPLAY_SAMPLE_INTERVAL_MS,
		"duration_ms": maxi(0, duration_ms),
		"map": _replay_map.duplicate(true),
		"frames": _replay_frames.duplicate(true)
	}

func _build_video_replay_payload(duration_ms: int) -> Dictionary:
	var metadata: Dictionary = _model.metadata if typeof(_model.metadata) == TYPE_DICTIONARY else {}
	var map_data: Dictionary = {}
	var map_data_any: Variant = metadata.get("map_data", {})
	if typeof(map_data_any) == TYPE_DICTIONARY:
		map_data = (map_data_any as Dictionary).duplicate(true)
	var input_events: Array = []
	for event_any in _model.events:
		if typeof(event_any) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_any as Dictionary
		if int(event.get("e", 0)) != int(MatchTelemetryModelScript.EVENT_INTENT):
			continue
		if not bool(event.get("ok", false)):
			continue
		var intent: String = str(event.get("intent", "")).strip_edges().to_lower()
		if intent != "attack" and intent != "feed" and intent != "swarm" and intent != "none":
			continue
		input_events.append({
			"t_ms": maxi(0, int(event.get("t", 0))),
			"player_id": maxi(0, int(event.get("p", 0))),
			"src_hive_id": int(event.get("src", -1)),
			"dst_hive_id": int(event.get("dst", -1)),
			"intent": intent
		})
	input_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("t_ms", 0)) < int(b.get("t_ms", 0))
	)
	var clip_duration_ms: int = mini(VIDEO_REPLAY_DEFAULT_CLIP_MS, maxi(0, duration_ms))
	return {
		"schema_version": 1,
		"render_mode": "actual_arena_scene",
		"deterministic": true,
		"map_path": str(metadata.get("map_path", "")).strip_edges(),
		"map_data": map_data,
		"input_events": input_events,
		"player_loadouts": _dictionary_from_metadata(metadata, "player_loadouts"),
		"cosmetics": _dictionary_from_metadata(metadata, "cosmetics"),
		"clip_windows": [
			{
				"start_ms": maxi(0, duration_ms - clip_duration_ms),
				"duration_ms": clip_duration_ms,
				"reason": "default_social_clip"
			}
		],
		"cta": {
			"text_overlay": "Tap the link to play Swarmfront",
			"link_url": "",
			"safe_area": "bottom"
		},
		"export": {
			"width": VIDEO_REPLAY_WIDTH,
			"height": VIDEO_REPLAY_HEIGHT,
			"fps": VIDEO_REPLAY_FPS,
			"format": "mp4"
		}
	}

func _dictionary_from_metadata(metadata: Dictionary, key: String) -> Dictionary:
	var value: Variant = metadata.get(key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}

func _build_replay_map(state: GameState) -> Dictionary:
	var hives: Array = []
	for hive in state.hives:
		if not (hive is HiveData):
			continue
		var h := hive as HiveData
		hives.append([
			int(h.id),
			float(h.render_grid_pos.x),
			float(h.render_grid_pos.y),
			str(h.kind),
			float(h.radius_px)
		])
	var towers: Array = []
	for tower_any in state.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		var gp: Vector2i = tower.get("grid_pos", Vector2i.ZERO) as Vector2i
		towers.append([int(tower.get("id", -1)), float(gp.x), float(gp.y), int(tower.get("owner_id", 0))])
	var barracks: Array = []
	for barracks_any in state.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks_data: Dictionary = barracks_any as Dictionary
		var gp_b: Vector2i = barracks_data.get("grid_pos", Vector2i.ZERO) as Vector2i
		barracks.append([int(barracks_data.get("id", -1)), float(gp_b.x), float(gp_b.y), int(barracks_data.get("owner_id", 0))])
	var candidates: Array = []
	for lane_any in state.lane_candidates:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_any as Dictionary
		var a_id: int = int(lane.get("a_id", lane.get("from", -1)))
		var b_id: int = int(lane.get("b_id", lane.get("to", -1)))
		if a_id > 0 and b_id > 0:
			candidates.append([a_id, b_id])
	return {
		"hives": hives,
		"towers": towers,
		"barracks": barracks,
		"lane_candidates": candidates
	}

func _build_replay_frame(t_ms: int, state: GameState) -> Dictionary:
	return {
		"t": maxi(0, t_ms),
		"h": _replay_hive_rows(state),
		"l": _replay_lane_rows(state),
		"u": _replay_unit_rows(state)
	}

func _replay_hive_rows(state: GameState) -> Array:
	var out: Array = []
	for hive in state.hives:
		if not (hive is HiveData):
			continue
		var h := hive as HiveData
		out.append([int(h.id), int(h.owner_id), int(h.power)])
	return out

func _replay_lane_rows(state: GameState) -> Array:
	var out: Array = []
	for lane_any in state.lanes:
		if not (lane_any is LaneData):
			continue
		var lane := lane_any as LaneData
		out.append([
			int(lane.id),
			int(lane.a_id),
			int(lane.b_id),
			1 if bool(lane.send_a) else 0,
			1 if bool(lane.send_b) else 0,
			float(lane.build_t)
		])
	return out

func _replay_unit_rows(state: GameState) -> Array:
	var out: Array = []
	var units_any: Variant = state.units_by_lane.get("_all", [])
	if typeof(units_any) != TYPE_ARRAY:
		return out
	var units: Array = units_any as Array
	var limit: int = mini(units.size(), REPLAY_MAX_UNITS_PER_FRAME)
	for i in range(limit):
		var unit_any: Variant = units[i]
		if typeof(unit_any) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_any as Dictionary
		var lane_id: int = int(unit.get("lane_id", -1))
		var owner_id: int = int(unit.get("owner_id", 0))
		if lane_id <= 0 or owner_id <= 0:
			continue
		out.append([
			lane_id,
			owner_id,
			snappedf(clampf(float(unit.get("t", 0.0)), 0.0, 1.0), 0.001),
			maxi(1, int(unit.get("amount", 1)))
		])
	return out

func _build_totals() -> Dictionary:
	var players: Array[int] = _active_player_ids.duplicate()
	players.sort()
	return {
		"event_count": _model.events.size(),
		"player_ids": players,
		"unit_spawn_by_player": _dict_by_player(players, _units_produced_by_player),
		"unit_land_friendly_by_player": _dict_by_player(players, _units_arrived_friendly_hive_by_player),
		"unit_land_enemy_by_player": _dict_by_player(players, _units_arrived_enemy_hive_by_player),
		"unit_land_npc_by_player": _dict_by_player(players, _units_arrived_npc_hive_by_player),
		"tower_kills_by_player": _dict_by_player(players, _tower_units_killed_by_player),
		"unit_deaths_by_victim_player": _dict_by_player(players, _unit_deaths_by_victim_player),
		"unit_deaths_by_killer_player": _dict_by_player(players, _unit_deaths_by_killer_player),
		"intent_total_by_player": _dict_by_player(players, _intent_total_by_player),
		"intent_fail_by_player": _dict_by_player(players, _intent_fail_by_player)
	}

func _dict_by_player(players: Array[int], source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for player_id in players:
		out[str(player_id)] = source.get(player_id, 0)
	return out

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
	var sorted_events: Array[Dictionary] = _sorted_events_by_time()
	var reaction: Dictionary = _compute_reaction_metrics(players, sorted_events)
	var early_window_s: float = minf(duration_s, float(EARLY_WINDOW_MS) / 1000.0)
	var winner_player_id: int = int(_model.metadata.get("winner_player_id", 0))
	var produced: Array = []
	var units_sent: Array = []
	var barracks_produced: Array = []
	var won_match: Array = []
	var lost_match: Array = []
	var swarms_sent: Array = []
	var meaningful_actions: Array = []
	var meaningful_apm: Array = []
	var lane_reversals: Array = []
	var arrived_friendly: Array = []
	var arrived_enemy: Array = []
	var arrived_npc: Array = []
	var arrived_hostile: Array = []
	var idle_time: Array = []
	var avg_rate: Array = []
	var avg_interval: Array = []
	var lost: Array = []
	var wasted_in_collisions: Array = []
	var tower_kills: Array = []
	var damage_dealt: Array = []
	var damage_taken: Array = []
	var lane_control: Array = []
	var tower_control: Array = []
	var barracks_control: Array = []
	var active_lane_slots: Array = []
	var lane_budget_slots: Array = []
	var lane_budget_utilization: Array = []
	var lane_waste_pct: Array = []
	var fully_utilized_lane_time: Array = []
	var underutilized_lane_time: Array = []
	var board_control_area: Array = []
	var avg_board_control_share: Array = []
	var board_control_peak_share: Array = []
	var reaction_time_s: Array = []
	var reaction_samples: Array = []
	var early_apm: Array = []
	var early_open_budget_utilization: Array = []
	var early_board_control_share: Array = []
	var early_activity_score: Array = []
	var overcommit: Array = []
	var intent_total: Array = []
	var intent_success: Array = []
	var intent_fail: Array = []
	var intent_budget_fail: Array = []
	var intent_no_lane_fail: Array = []
	var style_features: Array = []
	var bot_profile_knobs: Array = []
	var player_index: Dictionary = {}
	for i in range(players.size()):
		var player_id: int = players[i]
		player_index[str(player_id)] = i
		var produced_count: int = int(_units_produced_by_player.get(player_id, 0))
		var hostile_arrivals_count: int = int(_units_arrived_enemy_hive_by_player.get(player_id, 0)) + int(_units_arrived_npc_hive_by_player.get(player_id, 0))
		var barracks_count: int = int(_barracks_units_produced_by_player.get(player_id, 0))
		var swarm_count: int = int(_swarms_sent_by_player.get(player_id, 0))
		var meaningful_count: int = int(_meaningful_actions_by_player.get(player_id, 0))
		var idle_value: float = float(_idle_time_s_by_player.get(player_id, 0.0))
		var avg_value: float = 0.0
		var avg_interval_value: float = 0.0
		var meaningful_apm_value: float = 0.0
		var active_lane_slots_value: float = float(_active_lane_slots_time_s_by_player.get(player_id, 0.0))
		var lane_budget_slots_value: float = float(_lane_budget_slots_time_s_by_player.get(player_id, 0.0))
		var board_control_area_value: float = float(_board_control_area_by_player.get(player_id, 0.0))
		var avg_board_control_share_value: float = 0.0
		var lane_budget_utilization_value: float = 0.0
		var lane_waste_value: float = 0.0
		var early_open_budget_value: float = 0.0
		var early_apm_value: float = 0.0
		var early_board_share_value: float = 0.0
		var reaction_time_value: float = float((reaction.get("median_by_player", {}) as Dictionary).get(player_id, 0.0))
		var reaction_sample_value: int = int((reaction.get("samples_by_player", {}) as Dictionary).get(player_id, 0))
		var early_reaction_time_value: float = float((reaction.get("early_median_by_player", {}) as Dictionary).get(player_id, 0.0))
		var early_reaction_sample_value: int = int((reaction.get("early_samples_by_player", {}) as Dictionary).get(player_id, 0))
		var lane_reversal_count: int = int(_lane_reversals_by_player.get(player_id, 0))
		var overcommit_count: int = int(_overcommit_events_by_player.get(player_id, 0))
		var intent_total_count: int = int(_intent_total_by_player.get(player_id, 0))
		var intent_success_count: int = int(_intent_success_by_player.get(player_id, 0))
		var intent_fail_count: int = int(_intent_fail_by_player.get(player_id, 0))
		var intent_budget_fail_count: int = int(_intent_budget_fail_by_player.get(player_id, 0))
		var intent_no_lane_fail_count: int = int(_intent_no_lane_fail_by_player.get(player_id, 0))
		if duration_s > 0.0:
			avg_value = float(produced_count) / duration_s
			avg_interval_value = duration_s / float(produced_count) if produced_count > 0 else 0.0
			meaningful_apm_value = (float(meaningful_count) * 60.0) / duration_s
			avg_board_control_share_value = board_control_area_value / duration_s
		if lane_budget_slots_value > 0.0:
			lane_budget_utilization_value = active_lane_slots_value / lane_budget_slots_value
		var lane_budget_active_time: float = float(_fully_utilized_lane_time_s_by_player.get(player_id, 0.0)) + float(_underutilized_lane_time_s_by_player.get(player_id, 0.0))
		if lane_budget_active_time > 0.0:
			lane_waste_value = float(_underutilized_lane_time_s_by_player.get(player_id, 0.0)) / lane_budget_active_time
		var early_budget_slots_value: float = float(_early_lane_budget_slots_time_s_by_player.get(player_id, 0.0))
		var early_active_slots_value: float = float(_early_active_lane_slots_time_s_by_player.get(player_id, 0.0))
		if early_budget_slots_value > 0.0:
			early_open_budget_value = early_active_slots_value / early_budget_slots_value
		if early_window_s > 0.0:
			var early_meaningful_count: int = _count_meaningful_actions_in_window(player_id, sorted_events, EARLY_WINDOW_MS)
			early_apm_value = (float(early_meaningful_count) * 60.0) / early_window_s
			early_board_share_value = float(_early_board_control_area_by_player.get(player_id, 0.0)) / early_window_s
		produced.append(produced_count)
		units_sent.append(produced_count)
		won_match.append(1 if winner_player_id > 0 and winner_player_id == player_id else 0)
		lost_match.append(1 if winner_player_id > 0 and winner_player_id != player_id else 0)
		barracks_produced.append(barracks_count)
		swarms_sent.append(swarm_count)
		meaningful_actions.append(meaningful_count)
		meaningful_apm.append(meaningful_apm_value)
		lane_reversals.append(lane_reversal_count)
		arrived_friendly.append(int(_units_arrived_friendly_hive_by_player.get(player_id, 0)))
		arrived_enemy.append(int(_units_arrived_enemy_hive_by_player.get(player_id, 0)))
		arrived_npc.append(int(_units_arrived_npc_hive_by_player.get(player_id, 0)))
		arrived_hostile.append(hostile_arrivals_count)
		idle_time.append(idle_value)
		avg_rate.append(avg_value)
		avg_interval.append(avg_interval_value)
		lost.append(int(_units_lost_by_player.get(player_id, 0)))
		wasted_in_collisions.append(int(_units_lost_by_player.get(player_id, 0)))
		tower_kills.append(int(_tower_units_killed_by_player.get(player_id, 0)))
		damage_dealt.append(int(_hive_damage_dealt_by_player.get(player_id, 0)))
		damage_taken.append(int(_hive_damage_taken_by_player.get(player_id, 0)))
		lane_control.append(float(_lane_control_time_s_by_player.get(player_id, 0.0)))
		tower_control.append(float(_tower_control_time_s_by_player.get(player_id, 0.0)))
		barracks_control.append(float(_barracks_control_time_s_by_player.get(player_id, 0.0)))
		active_lane_slots.append(active_lane_slots_value)
		lane_budget_slots.append(lane_budget_slots_value)
		lane_budget_utilization.append(lane_budget_utilization_value)
		lane_waste_pct.append(lane_waste_value)
		fully_utilized_lane_time.append(float(_fully_utilized_lane_time_s_by_player.get(player_id, 0.0)))
		underutilized_lane_time.append(float(_underutilized_lane_time_s_by_player.get(player_id, 0.0)))
		board_control_area.append(board_control_area_value)
		avg_board_control_share.append(avg_board_control_share_value)
		board_control_peak_share.append(float(_board_control_peak_share_by_player.get(player_id, 0.0)))
		reaction_time_s.append(reaction_time_value)
		reaction_samples.append(reaction_sample_value)
		early_apm.append(early_apm_value)
		early_open_budget_utilization.append(early_open_budget_value)
		early_board_control_share.append(early_board_share_value)
		early_activity_score.append(
			_compute_early_game_activity_score(
				player_id,
				sorted_events,
				early_window_s,
				early_open_budget_value,
				early_apm_value,
				early_board_share_value,
				early_reaction_time_value,
				early_reaction_sample_value
			)
		)
		overcommit.append(overcommit_count)
		intent_total.append(intent_total_count)
		intent_success.append(intent_success_count)
		intent_fail.append(intent_fail_count)
		intent_budget_fail.append(intent_budget_fail_count)
		intent_no_lane_fail.append(intent_no_lane_fail_count)
		var player_style_features: Dictionary = _build_style_features_for_player(
			duration_s,
			meaningful_apm_value,
			lane_reversal_count,
			swarm_count,
			hostile_arrivals_count,
			int(_hive_damage_dealt_by_player.get(player_id, 0)),
			int(_hive_damage_taken_by_player.get(player_id, 0)),
			lane_budget_utilization_value,
			lane_waste_value,
			avg_board_control_share_value,
			float(_board_control_peak_share_by_player.get(player_id, 0.0)),
			reaction_time_value,
			reaction_sample_value,
			overcommit_count,
			intent_total_count,
			intent_fail_count,
			intent_budget_fail_count,
			intent_no_lane_fail_count,
			early_apm_value,
			early_open_budget_value,
			early_board_share_value
		)
		style_features.append(player_style_features)
		bot_profile_knobs.append(_build_bot_profile_knobs_from_style(player_style_features, reaction_time_value, reaction_sample_value))
	var swing_moment_ms: int = _compute_swing_moment_ms(duration_s)
	var production_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(produced)
	var barracks_production_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(barracks_produced)
	var tower_kills_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(tower_kills)
	var enemy_hive_landings_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(arrived_enemy)
	var hostile_hive_landings_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(arrived_hostile)
	var tower_control_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(tower_control)
	var barracks_control_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(barracks_control)
	var active_lane_slots_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(active_lane_slots)
	var lane_budget_utilization_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(lane_budget_utilization)
	var fully_utilized_lane_time_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(fully_utilized_lane_time)
	var underutilized_lane_time_ratio_vs_top_opponent: Array = _ratio_vs_top_opponent_array(underutilized_lane_time)
	return {
		"players": players,
		"player_index": player_index,
		"won_match_by_player": won_match,
		"lost_match_by_player": lost_match,
		"total_units_produced_by_player": produced,
		"units_sent_by_player": units_sent,
		"barracks_units_produced_by_player": barracks_produced,
		"total_swarms_sent_by_player": swarms_sent,
		"meaningful_actions_by_player": meaningful_actions,
		"meaningful_actions_per_min_by_player": meaningful_apm,
		"lane_reversals_by_player": lane_reversals,
		"units_arrived_friendly_hive_by_player": arrived_friendly,
		"units_arrived_enemy_hive_by_player": arrived_enemy,
		"units_arrived_npc_hive_by_player": arrived_npc,
		"units_arrived_hostile_hive_by_player": arrived_hostile,
		"production_idle_time_s_by_player": idle_time,
		"average_production_rate_by_player": avg_rate,
		"average_unit_production_interval_s_by_player": avg_interval,
		"total_swarm_collisions": _total_swarm_collisions,
		"total_units_lost_by_player": lost,
		"units_wasted_in_collisions_by_player": wasted_in_collisions,
		"tower_units_killed_by_player": tower_kills,
		"hive_damage_dealt_by_player": damage_dealt,
		"hive_damage_taken_by_player": damage_taken,
		"lane_control_time_s_by_player": lane_control,
		"tower_control_time_s_by_player": tower_control,
		"barracks_control_time_s_by_player": barracks_control,
		"active_lane_slots_time_s_by_player": active_lane_slots,
		"lane_budget_slots_time_s_by_player": lane_budget_slots,
		"lane_budget_utilization_pct_by_player": lane_budget_utilization,
		"lane_waste_pct_by_player": lane_waste_pct,
		"fully_utilized_lane_time_s_by_player": fully_utilized_lane_time,
		"underutilized_lane_time_s_by_player": underutilized_lane_time,
		"board_control_area_by_player": board_control_area,
		"average_board_control_share_by_player": avg_board_control_share,
		"board_control_peak_share_by_player": board_control_peak_share,
		"production_ratio_vs_top_opponent_by_player": production_ratio_vs_top_opponent,
		"barracks_production_ratio_vs_top_opponent_by_player": barracks_production_ratio_vs_top_opponent,
		"tower_kills_ratio_vs_top_opponent_by_player": tower_kills_ratio_vs_top_opponent,
		"enemy_hive_landings_ratio_vs_top_opponent_by_player": enemy_hive_landings_ratio_vs_top_opponent,
		"hostile_hive_landings_ratio_vs_top_opponent_by_player": hostile_hive_landings_ratio_vs_top_opponent,
		"tower_control_time_ratio_vs_top_opponent_by_player": tower_control_ratio_vs_top_opponent,
		"barracks_control_time_ratio_vs_top_opponent_by_player": barracks_control_ratio_vs_top_opponent,
		"active_lane_slots_time_ratio_vs_top_opponent_by_player": active_lane_slots_ratio_vs_top_opponent,
		"lane_budget_utilization_ratio_vs_top_opponent_by_player": lane_budget_utilization_ratio_vs_top_opponent,
		"fully_utilized_lane_time_ratio_vs_top_opponent_by_player": fully_utilized_lane_time_ratio_vs_top_opponent,
		"underutilized_lane_time_ratio_vs_top_opponent_by_player": underutilized_lane_time_ratio_vs_top_opponent,
		"reaction_time_s_by_player": reaction_time_s,
		"reaction_time_samples_by_player": reaction_samples,
		"early_meaningful_actions_per_min_by_player": early_apm,
		"early_open_budget_utilization_pct_by_player": early_open_budget_utilization,
		"early_board_control_share_by_player": early_board_control_share,
		"early_game_activity_score_by_player": early_activity_score,
		"overcommit_events_by_player": overcommit,
		"intent_total_by_player": intent_total,
		"intent_success_by_player": intent_success,
		"intent_fail_by_player": intent_fail,
		"intent_budget_fail_by_player": intent_budget_fail,
		"intent_no_lane_fail_by_player": intent_no_lane_fail,
		"style_features_by_player": style_features,
		"bot_profile_knobs_by_player": bot_profile_knobs,
		"swing_moment_ms": swing_moment_ms
	}

func _build_style_features_for_player(
	duration_s: float,
	meaningful_apm: float,
	lane_reversals: int,
	swarms_sent: int,
	hostile_arrivals: int,
	hive_damage_dealt: int,
	hive_damage_taken: int,
	lane_budget_utilization: float,
	lane_waste: float,
	average_board_control_share: float,
	board_control_peak_share: float,
	reaction_time_s: float,
	reaction_samples: int,
	overcommit_events: int,
	intent_total: int,
	intent_fail: int,
	intent_budget_fail: int,
	intent_no_lane_fail: int,
	early_apm: float,
	early_open_budget_utilization: float,
	early_board_control_share: float
) -> Dictionary:
	var minutes: float = maxf(duration_s / 60.0, 0.25)
	var swarm_rate: float = float(swarms_sent) / minutes
	var hostile_arrival_rate: float = float(hostile_arrivals) / minutes
	var reversal_rate: float = float(lane_reversals) / minutes
	var overcommit_rate: float = float(overcommit_events) / minutes
	var intent_fail_rate: float = float(intent_fail) / float(maxi(intent_total, 1))
	var budget_fail_rate: float = float(intent_budget_fail) / float(maxi(intent_total, 1))
	var no_lane_fail_rate: float = float(intent_no_lane_fail) / float(maxi(intent_total, 1))
	var damage_pressure_ratio: float = float(hive_damage_dealt + 1) / float(hive_damage_taken + 1)
	var reaction_speed: float = 0.5
	if reaction_samples > 0:
		reaction_speed = clampf(1.0 - (reaction_time_s / 8.0), 0.0, 1.0)
	var aggression: float = clampf((swarm_rate / 4.0) * 0.34 + (hostile_arrival_rate / 12.0) * 0.26 + (float(hive_damage_dealt) / 80.0) * 0.22 + clampf(damage_pressure_ratio / 2.0, 0.0, 1.0) * 0.18, 0.0, 1.0)
	var defense_bias: float = clampf((float(hive_damage_taken) / 80.0) * 0.28 + reaction_speed * 0.25 + (1.0 - lane_waste) * 0.2 + (float(intent_budget_fail) / 5.0) * 0.12 + (1.0 - minf(aggression, 1.0)) * 0.15, 0.0, 1.0)
	var expansion_bias: float = clampf(early_board_control_share * 0.38 + average_board_control_share * 0.28 + board_control_peak_share * 0.2 + early_open_budget_utilization * 0.14, 0.0, 1.0)
	var lane_efficiency: float = clampf(lane_budget_utilization * 0.46 + (1.0 - lane_waste) * 0.34 + (1.0 - budget_fail_rate) * 0.2, 0.0, 1.0)
	var risk_tolerance: float = clampf(aggression * 0.36 + expansion_bias * 0.26 + (overcommit_rate / 2.5) * 0.2 + budget_fail_rate * 0.1 + no_lane_fail_rate * 0.08, 0.0, 1.0)
	var volatility: float = clampf((reversal_rate / 6.0) * 0.35 + intent_fail_rate * 0.25 + (overcommit_rate / 2.0) * 0.2 + (meaningful_apm / 18.0) * 0.1 + (early_apm / 18.0) * 0.1, 0.0, 1.0)
	var swarm_preference: float = clampf(swarm_rate / 5.0, 0.0, 1.0)
	var tempo: float = clampf(meaningful_apm / 16.0, 0.0, 1.0)
	return {
		"aggression": aggression,
		"defense_bias": defense_bias,
		"expansion_bias": expansion_bias,
		"reaction_speed": reaction_speed,
		"lane_efficiency": lane_efficiency,
		"risk_tolerance": risk_tolerance,
		"volatility_under_pressure": volatility,
		"swarm_preference": swarm_preference,
		"tempo": tempo,
		"intent_fail_rate": intent_fail_rate,
		"budget_fail_rate": budget_fail_rate,
		"no_lane_fail_rate": no_lane_fail_rate
	}

func _build_bot_profile_knobs_from_style(style: Dictionary, reaction_time_s: float, reaction_samples: int) -> Dictionary:
	var reaction_delay_s: float = 2.5
	if reaction_samples > 0:
		reaction_delay_s = clampf(reaction_time_s, 0.25, 8.0)
	return {
		"aggression": float(style.get("aggression", 0.0)),
		"defense_bias": float(style.get("defense_bias", 0.0)),
		"expansion_bias": float(style.get("expansion_bias", 0.0)),
		"reaction_delay_s": reaction_delay_s,
		"lane_budget_target": clampf(float(style.get("lane_efficiency", 0.0)), 0.15, 1.0),
		"risk_tolerance": float(style.get("risk_tolerance", 0.0)),
		"swarm_preference": float(style.get("swarm_preference", 0.0)),
		"volatility": float(style.get("volatility_under_pressure", 0.0)),
		"tempo": float(style.get("tempo", 0.0))
	}

func _sorted_events_by_time() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event in _model.events:
		out.append(event.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(a.get("t", 0))
		var tb: int = int(b.get("t", 0))
		if ta != tb:
			return ta < tb
		return int(a.get("e", 0)) < int(b.get("e", 0))
	)
	return out

func _ratio_vs_top_opponent_array(values: Array) -> Array:
	var out: Array = []
	for i in range(values.size()):
		var own_value: float = float(values[i])
		var opponent_top: float = 0.0
		for j in range(values.size()):
			if i == j:
				continue
			opponent_top = maxf(opponent_top, float(values[j]))
		if opponent_top <= 0.0:
			out.append(0.0)
		else:
			out.append(own_value / opponent_top)
	return out

func _compute_reaction_metrics(players: Array[int], sorted_events: Array[Dictionary]) -> Dictionary:
	var response_events_by_player: Dictionary = {}
	var overall_delays_by_player: Dictionary = {}
	var early_delays_by_player: Dictionary = {}
	var last_threat_ms_by_player: Dictionary = {}
	for player_id in players:
		response_events_by_player[player_id] = []
		overall_delays_by_player[player_id] = []
		early_delays_by_player[player_id] = []
		last_threat_ms_by_player[player_id] = -999999999
	for event in sorted_events:
		if not _event_is_response_candidate(event):
			continue
		var player_id: int = int(event.get("p", 0))
		if player_id <= 0:
			continue
		var response_events: Array = response_events_by_player.get(player_id, []) as Array
		response_events.append({
			"t": int(event.get("t", 0)),
			"e": int(event.get("e", 0))
		})
		response_events_by_player[player_id] = response_events
	for event in sorted_events:
		var threat_target_player_id: int = _event_threat_target_player_id(event)
		if threat_target_player_id <= 0:
			continue
		var threat_time_ms: int = int(event.get("t", 0))
		var last_threat_ms: int = int(last_threat_ms_by_player.get(threat_target_player_id, -999999999))
		if threat_time_ms - last_threat_ms < REACTION_THREAT_COOLDOWN_MS:
			continue
		last_threat_ms_by_player[threat_target_player_id] = threat_time_ms
		var delay_ms: int = _first_response_delay_ms(response_events_by_player.get(threat_target_player_id, []) as Array, threat_time_ms)
		if delay_ms < 0:
			continue
		var delay_s: float = float(delay_ms) / 1000.0
		var overall_delays: Array = overall_delays_by_player.get(threat_target_player_id, []) as Array
		overall_delays.append(delay_s)
		overall_delays_by_player[threat_target_player_id] = overall_delays
		if threat_time_ms <= EARLY_WINDOW_MS:
			var early_delays: Array = early_delays_by_player.get(threat_target_player_id, []) as Array
			early_delays.append(delay_s)
			early_delays_by_player[threat_target_player_id] = early_delays
	var median_by_player: Dictionary = {}
	var samples_by_player: Dictionary = {}
	var early_median_by_player: Dictionary = {}
	var early_samples_by_player: Dictionary = {}
	for player_id in players:
		var overall_values: Array = overall_delays_by_player.get(player_id, []) as Array
		var early_values: Array = early_delays_by_player.get(player_id, []) as Array
		median_by_player[player_id] = _median_float_array(overall_values)
		samples_by_player[player_id] = overall_values.size()
		early_median_by_player[player_id] = _median_float_array(early_values)
		early_samples_by_player[player_id] = early_values.size()
	return {
		"median_by_player": median_by_player,
		"samples_by_player": samples_by_player,
		"early_median_by_player": early_median_by_player,
		"early_samples_by_player": early_samples_by_player
	}

func _event_is_response_candidate(event: Dictionary) -> bool:
	var event_type: int = int(event.get("e", -1))
	if event_type == int(MatchTelemetryModelScript.EVENT_BUFF_ACTIVATION):
		return true
	if event_type != int(MatchTelemetryModelScript.EVENT_ACTION):
		return false
	var kind: String = str(event.get("k", "")).strip_edges().to_lower()
	match kind:
		"swarm_send", "lane_open_attack", "lane_open_feed", "lane_disable", "lane_retract", "lane_reverse", "barracks_route":
			return true
		_:
			return false

func _event_threat_target_player_id(event: Dictionary) -> int:
	var event_type: int = int(event.get("e", -1))
	if event_type == int(MatchTelemetryModelScript.EVENT_ACTION):
		var kind: String = str(event.get("k", "")).strip_edges().to_lower()
		if kind == "swarm_send" or kind == "lane_open_attack":
			var target_player_id: int = int(event.get("dst_owner", 0))
			var source_player_id: int = int(event.get("p", 0))
			if target_player_id > 0 and target_player_id != source_player_id:
				return target_player_id
	elif event_type == int(MatchTelemetryModelScript.EVENT_HIVE_DAMAGE):
		var defender_player_id: int = int(event.get("def", 0))
		var attacker_player_id: int = int(event.get("atk", 0))
		if defender_player_id > 0 and defender_player_id != attacker_player_id:
			return defender_player_id
	return 0

func _first_response_delay_ms(response_events: Array, threat_time_ms: int) -> int:
	for response_any in response_events:
		if typeof(response_any) != TYPE_DICTIONARY:
			continue
		var response_event: Dictionary = response_any as Dictionary
		var response_time_ms: int = int(response_event.get("t", -1))
		if response_time_ms <= threat_time_ms:
			continue
		var delay_ms: int = response_time_ms - threat_time_ms
		if delay_ms <= REACTION_RESPONSE_WINDOW_MS:
			return delay_ms
		break
	return -1

func _median_float_array(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	var middle_index: int = sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return float(sorted_values[middle_index])
	return (float(sorted_values[middle_index - 1]) + float(sorted_values[middle_index])) * 0.5

func _count_meaningful_actions_in_window(player_id: int, sorted_events: Array[Dictionary], max_time_ms: int) -> int:
	var count: int = 0
	for event in sorted_events:
		var event_time_ms: int = int(event.get("t", 0))
		if event_time_ms > max_time_ms:
			break
		var event_player_id: int = int(event.get("p", 0))
		if event_player_id != player_id:
			continue
		var event_type: int = int(event.get("e", -1))
		if event_type == int(MatchTelemetryModelScript.EVENT_BUFF_ACTIVATION):
			count += 1
			continue
		if event_type != int(MatchTelemetryModelScript.EVENT_ACTION):
			continue
		if _counts_as_meaningful_action(str(event.get("k", ""))):
			count += 1
	return count

func _compute_early_game_activity_score(
	player_id: int,
	sorted_events: Array[Dictionary],
	early_window_s: float,
	early_open_budget_utilization: float,
	early_apm: float,
	early_board_share: float,
	early_reaction_s: float,
	early_reaction_samples: int
) -> int:
	if early_window_s <= 0.0:
		return 1
	var early_window_ms: int = int(round(early_window_s * 1000.0))
	var first_open_ms: int = -1
	var second_open_ms: int = -1
	var first_swarm_ms: int = -1
	var opened_lane_ids: Dictionary = {}
	for event in sorted_events:
		var event_time_ms: int = int(event.get("t", 0))
		if event_time_ms > early_window_ms:
			break
		if int(event.get("p", 0)) != player_id:
			continue
		if int(event.get("e", -1)) != int(MatchTelemetryModelScript.EVENT_ACTION):
			continue
		var kind: String = str(event.get("k", "")).strip_edges().to_lower()
		if first_swarm_ms < 0 and kind == "swarm_send":
			first_swarm_ms = event_time_ms
		if kind != "lane_open_attack" and kind != "lane_open_feed":
			continue
		var lane_id: int = int(event.get("lane_id", -1))
		if lane_id <= 0 or opened_lane_ids.has(lane_id):
			continue
		opened_lane_ids[lane_id] = true
		if first_open_ms < 0:
			first_open_ms = event_time_ms
		elif second_open_ms < 0:
			second_open_ms = event_time_ms
	var score: float = 0.0
	score += _inverse_time_score(first_open_ms, 20000) * 16.0
	score += _inverse_time_score(second_open_ms, 45000) * 12.0
	score += _inverse_time_score(first_swarm_ms, 30000) * 16.0
	score += clampf(early_apm / 10.0, 0.0, 1.0) * 18.0
	score += clampf(early_open_budget_utilization / 0.72, 0.0, 1.0) * 18.0
	score += clampf(early_board_share / 0.55, 0.0, 1.0) * 10.0
	if early_reaction_samples > 0:
		score += clampf(1.0 - (early_reaction_s / 8.0), 0.0, 1.0) * 10.0
	else:
		score += 5.0
	return clampi(int(round(score)), 1, 100)

func _inverse_time_score(event_time_ms: int, target_time_ms: int) -> float:
	if event_time_ms < 0 or target_time_ms <= 0:
		return 0.0
	return clampf(1.0 - (float(event_time_ms) / float(target_time_ms)), 0.0, 1.0)

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

func _sample_structure_control(dt_s: float, state: GameState) -> void:
	for tower_any in state.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		if not bool(tower.get("active", false)):
			continue
		var owner_id: int = int(tower.get("owner_id", 0))
		if owner_id <= 0:
			continue
		_ensure_player_slot(owner_id)
		_tower_control_time_s_by_player[owner_id] = float(_tower_control_time_s_by_player.get(owner_id, 0.0)) + dt_s
	for barracks_any in state.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks: Dictionary = barracks_any as Dictionary
		if not bool(barracks.get("active", false)):
			continue
		var owner_id: int = int(barracks.get("owner_id", 0))
		if owner_id <= 0:
			continue
		_ensure_player_slot(owner_id)
		_barracks_control_time_s_by_player[owner_id] = float(_barracks_control_time_s_by_player.get(owner_id, 0.0)) + dt_s

func _sample_open_budget(dt_s: float, state: GameState, early_dt_s: float = 0.0) -> void:
	var budget_by_player: Dictionary = {}
	var active_by_player: Dictionary = {}
	for hive_any in state.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		if owner_id <= 0:
			continue
		_ensure_player_slot(owner_id)
		var metrics: Dictionary = state.get_execution_metrics_for_hive(int(hive.id))
		var budget: int = maxi(0, int(metrics.get("budget", 0)))
		var active_outgoing: int = maxi(0, int(metrics.get("active_outgoing", 0)))
		budget_by_player[owner_id] = int(budget_by_player.get(owner_id, 0)) + budget
		active_by_player[owner_id] = int(active_by_player.get(owner_id, 0)) + active_outgoing
		_lane_budget_slots_time_s_by_player[owner_id] = float(_lane_budget_slots_time_s_by_player.get(owner_id, 0.0)) + (float(budget) * dt_s)
		_active_lane_slots_time_s_by_player[owner_id] = float(_active_lane_slots_time_s_by_player.get(owner_id, 0.0)) + (float(active_outgoing) * dt_s)
		if early_dt_s > 0.0:
			_early_lane_budget_slots_time_s_by_player[owner_id] = float(_early_lane_budget_slots_time_s_by_player.get(owner_id, 0.0)) + (float(budget) * early_dt_s)
			_early_active_lane_slots_time_s_by_player[owner_id] = float(_early_active_lane_slots_time_s_by_player.get(owner_id, 0.0)) + (float(active_outgoing) * early_dt_s)
	for player_id_any in budget_by_player.keys():
		var player_id: int = int(player_id_any)
		var total_budget: int = maxi(0, int(budget_by_player.get(player_id, 0)))
		var total_active: int = maxi(0, int(active_by_player.get(player_id, 0)))
		if total_budget <= 0:
			continue
		if total_active >= total_budget:
			_fully_utilized_lane_time_s_by_player[player_id] = float(_fully_utilized_lane_time_s_by_player.get(player_id, 0.0)) + dt_s
		else:
			_underutilized_lane_time_s_by_player[player_id] = float(_underutilized_lane_time_s_by_player.get(player_id, 0.0)) + dt_s

func _sample_board_control(dt_s: float, state: GameState, early_dt_s: float = 0.0) -> void:
	var power_by_player: Dictionary = {}
	var total_power: float = 0.0
	for hive_any in state.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		if owner_id <= 0:
			continue
		_ensure_player_slot(owner_id)
		var power: float = maxf(0.0, float(hive.power))
		power_by_player[owner_id] = float(power_by_player.get(owner_id, 0.0)) + power
		total_power += power
	if total_power <= 0.0:
		return
	for player_id in _active_player_ids:
		var share: float = float(power_by_player.get(player_id, 0.0)) / total_power
		_board_control_area_by_player[player_id] = float(_board_control_area_by_player.get(player_id, 0.0)) + (share * dt_s)
		_board_control_peak_share_by_player[player_id] = maxf(float(_board_control_peak_share_by_player.get(player_id, 0.0)), share)
		if early_dt_s > 0.0:
			_early_board_control_area_by_player[player_id] = float(_early_board_control_area_by_player.get(player_id, 0.0)) + (share * early_dt_s)

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
	if not _barracks_units_produced_by_player.has(player_id):
		_barracks_units_produced_by_player[player_id] = 0
	if not _swarms_sent_by_player.has(player_id):
		_swarms_sent_by_player[player_id] = 0
	if not _meaningful_actions_by_player.has(player_id):
		_meaningful_actions_by_player[player_id] = 0
	if not _lane_reversals_by_player.has(player_id):
		_lane_reversals_by_player[player_id] = 0
	if not _units_arrived_friendly_hive_by_player.has(player_id):
		_units_arrived_friendly_hive_by_player[player_id] = 0
	if not _units_arrived_enemy_hive_by_player.has(player_id):
		_units_arrived_enemy_hive_by_player[player_id] = 0
	if not _units_arrived_npc_hive_by_player.has(player_id):
		_units_arrived_npc_hive_by_player[player_id] = 0
	if not _idle_time_s_by_player.has(player_id):
		_idle_time_s_by_player[player_id] = 0.0
	if not _last_production_seen_by_player.has(player_id):
		_last_production_seen_by_player[player_id] = 0
	if not _last_production_change_ms_by_player.has(player_id):
		_last_production_change_ms_by_player[player_id] = 0
	if not _units_lost_by_player.has(player_id):
		_units_lost_by_player[player_id] = 0
	if not _tower_units_killed_by_player.has(player_id):
		_tower_units_killed_by_player[player_id] = 0
	if not _hive_damage_dealt_by_player.has(player_id):
		_hive_damage_dealt_by_player[player_id] = 0
	if not _hive_damage_taken_by_player.has(player_id):
		_hive_damage_taken_by_player[player_id] = 0
	if not _lane_control_time_s_by_player.has(player_id):
		_lane_control_time_s_by_player[player_id] = 0.0
	if not _tower_control_time_s_by_player.has(player_id):
		_tower_control_time_s_by_player[player_id] = 0.0
	if not _barracks_control_time_s_by_player.has(player_id):
		_barracks_control_time_s_by_player[player_id] = 0.0
	if not _active_lane_slots_time_s_by_player.has(player_id):
		_active_lane_slots_time_s_by_player[player_id] = 0.0
	if not _lane_budget_slots_time_s_by_player.has(player_id):
		_lane_budget_slots_time_s_by_player[player_id] = 0.0
	if not _fully_utilized_lane_time_s_by_player.has(player_id):
		_fully_utilized_lane_time_s_by_player[player_id] = 0.0
	if not _underutilized_lane_time_s_by_player.has(player_id):
		_underutilized_lane_time_s_by_player[player_id] = 0.0
	if not _early_active_lane_slots_time_s_by_player.has(player_id):
		_early_active_lane_slots_time_s_by_player[player_id] = 0.0
	if not _early_lane_budget_slots_time_s_by_player.has(player_id):
		_early_lane_budget_slots_time_s_by_player[player_id] = 0.0
	if not _board_control_area_by_player.has(player_id):
		_board_control_area_by_player[player_id] = 0.0
	if not _board_control_peak_share_by_player.has(player_id):
		_board_control_peak_share_by_player[player_id] = 0.0
	if not _early_board_control_area_by_player.has(player_id):
		_early_board_control_area_by_player[player_id] = 0.0
	if not _overcommit_events_by_player.has(player_id):
		_overcommit_events_by_player[player_id] = 0
	if not _overcommit_window_s_by_player.has(player_id):
		_overcommit_window_s_by_player[player_id] = 0.0
	if not _overcommit_active_by_player.has(player_id):
		_overcommit_active_by_player[player_id] = false
	if not _intent_total_by_player.has(player_id):
		_intent_total_by_player[player_id] = 0
	if not _intent_success_by_player.has(player_id):
		_intent_success_by_player[player_id] = 0
	if not _intent_fail_by_player.has(player_id):
		_intent_fail_by_player[player_id] = 0
	if not _intent_budget_fail_by_player.has(player_id):
		_intent_budget_fail_by_player[player_id] = 0
	if not _intent_no_lane_fail_by_player.has(player_id):
		_intent_no_lane_fail_by_player[player_id] = 0

func _counts_as_meaningful_action(kind: String) -> bool:
	match kind:
		"swarm_send", "lane_open_attack", "lane_open_feed", "lane_disable", "lane_retract", "barracks_route":
			return true
		_:
			return false

func _early_window_overlap_s(now_ms: int, dt_s: float) -> float:
	if dt_s <= 0.0:
		return 0.0
	var dt_ms: int = maxi(0, int(round(dt_s * 1000.0)))
	var window_start_ms: int = maxi(0, now_ms - dt_ms)
	var overlap_start_ms: int = maxi(0, window_start_ms)
	var overlap_end_ms: int = mini(EARLY_WINDOW_MS, now_ms)
	var overlap_ms: int = maxi(0, overlap_end_ms - overlap_start_ms)
	return float(overlap_ms) / 1000.0

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
