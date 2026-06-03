# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const MAP_LOADER = preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY = preload("res://scripts/maps/map_registry.gd")
const BotTelemetryStoreScript := preload("res://scripts/state/bot_telemetry_store.gd")

signal map_selected(map_id: String)
signal state_changed(state: GameState)
signal ops_state_changed(iid: int)
signal lanes_changed(iid: int)
signal lane_intent_changed(iid: int, lane_id: int)
signal hud_changed(hud: Dictionary)

const CONTESTS_DIR := "res://data/contests"
const MAPS_DIR := "res://data/maps"
const OPS_CONSOLE_SCENE := "res://scenes/ops/ops_console.tscn"
const MATCH_DURATION_MS_DEFAULT := 300000
const MATCH_DURATION_MS_TEST := 70000
const TEAM_MODE_2V2 := "2v2"
const TEAM_MODE_FFA := "ffa"
const BOT_STYLE_BALANCER := "balancer"
const BOT_STYLE_TURTLE := "turtle"
const BOT_STYLE_RAIDER := "raider"
const BOT_STYLE_GREEDY := "greedy"
const BOT_STYLE_SWARM_LORD := "swarm_lord"
const BOT_TIER_EASY := "easy"
const BOT_TIER_MEDIUM := "medium"
const BOT_TIER_HARD := "hard"
const BOT_REACTION_DELAY_EXTRA_MS := 750
const SWARM_COOLDOWN_MS := 5000
const AUTH_FENCE_LOG_INTERVAL_MS := 1000
const AUTH_FENCE_ALLOWED_PREFIXES := [
	"res://scripts/systems/",
	"res://scripts/sim/",
	"res://scripts/ops/"
]

var dev_enabled := false
var contests: Dictionary = {}
var maps: Dictionary = {}
var _in_render_export := false
var auth_fence_assert_enabled: bool = false
var _auth_fence_last_ms: Dictionary = {}
var _sim_mutate_depth: int = 0
var _sim_mutate_tag_stack: Array[String] = []

var state: GameState = null
var current_map_id: String = ""
var _state_serial: int = 0
var _console_instance: Control = null
var _bot_telemetry_store: RefCounted = BotTelemetryStoreScript.new()
var _match_telemetry_collector: RefCounted = null
var _intent_log_match_id: String = ""

# --- MATCH OUTCOME + CLOCK (authoritative) ---
enum MatchPhase {
	PREMATCH,
	RUNNING,
	ENDING,
	ENDED
}
const PREMATCH_DURATION_MS: int = 5000
const PREMATCH_RECORDS_SHOW_MS := 3000
const VICTORY_MODE_CONQUEST := "conquest"
const VICTORY_MODE_CAPTURE_FLAG := "capture_flag"

var match_phase: int = MatchPhase.PREMATCH
var outcome: int = GameState.GameOutcome.NONE
var outcome_tick: int = -1
var outcome_reason: String = ""
var winner_id: int = 0
var end_reason: String = ""
var ended_ms: int = 0
var ending_started_ms: int = 0
var ending_linger_ms: int = 1250
var end_screen_ready_ms: int = 0
var rematch_window_ms: int = 5000
var rematch_deadline_ms: int = 0
var rematch_votes: Dictionary = {}
var post_end_action: String = ""
var stats_by_team: Dictionary = {}
var match_duration_ms: int = GameState.MATCH_DURATION_MS
var match_elapsed_ms: int = 0
var match_time_remaining_sec: float = float(GameState.MATCH_DURATION_MS) / 1000.0
var match_time_remaining_ms: int = GameState.MATCH_DURATION_MS
var match_remaining_ms: int = GameState.MATCH_DURATION_MS
var match_deadline_ms: int = 0
var timer_visible_started: bool = false
var in_overtime: bool = false
var ot_checked: bool = false
var match_clock_running: bool = false
var match_clock_started: bool = false
var match_end_reason: String = ""
var SF_TEST_MATCH_TIMER: bool = false
var _match_timer_config_logged: bool = false
var _input_ignored_match_over_logged: bool = false
var match_over: bool = false
var input_locked: bool = false
var input_locked_reason: String = ""
var team_mode_override: String = TEAM_MODE_2V2
var prematch_duration_ms: int = PREMATCH_DURATION_MS
var prematch_remaining_ms: int = PREMATCH_DURATION_MS
var match_end_ms: int = 0
var lane_front_by_lane_id: Dictionary = {} # lane_id -> front_t [0..1]
var match_roster: Array = []
var _hud_snapshot: Dictionary = {}
var _runtime_telemetry_snapshot: Dictionary = {}
var _runtime_telemetry_serial: int = 0
var edge_cache: Dictionary = {}
var edge_cache_version: int = -1
var blocked_wall_pairs: Array = []
var bot_profiles: Dictionary = {}
var _remote_replication_apply_depth: int = 0
var victory_mode: String = VICTORY_MODE_CONQUEST
var victory_rules: Dictionary = {}
var capture_flag_state: Dictionary = {}
var _capture_flag_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func get_state() -> GameState:
	return state

func load_contests() -> void:
	contests.clear()
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state != null and contest_state.has_method("load_contests"):
		contest_state.call("load_contests")
		var live_contests_any: Variant = contest_state.get("contests")
		if typeof(live_contests_any) == TYPE_DICTIONARY:
			contests = (live_contests_any as Dictionary).duplicate()
			return
	var dir: DirAccess = DirAccess.open(CONTESTS_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var contest: ContestDef = load("%s/%s" % [CONTESTS_DIR, file_name]) as ContestDef
		if contest == null or contest.id.strip_edges().is_empty():
			continue
		contests[contest.id.strip_edges()] = contest

func get_contest_ids() -> PackedStringArray:
	var keys: Array = contests.keys()
	keys.sort()
	var ids: PackedStringArray = PackedStringArray()
	for key_any in keys:
		ids.append(str(key_any))
	return ids

func save_contest(contest: ContestDef) -> bool:
	if contest == null or contest.id.strip_edges().is_empty():
		return false
	var dir_path: String = ProjectSettings.globalize_path(CONTESTS_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path: String = "%s/%s.tres" % [CONTESTS_DIR, contest.id.strip_edges()]
	var err: Error = ResourceSaver.save(contest, path)
	if err != OK:
		SFLog.warn("OPS_CONTEST_SAVE_FAILED", {"path": path, "error": int(err)})
		return false
	load_contests()
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state != null and contest_state.has_method("load_contests"):
		contest_state.call("load_contests")
	return true

func delete_contest(contest_id: String) -> bool:
	var clean_id: String = contest_id.strip_edges()
	if clean_id.is_empty():
		return false
	var path: String = "%s/%s.tres" % [CONTESTS_DIR, clean_id]
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		SFLog.warn("OPS_CONTEST_DELETE_FAILED", {"path": path, "error": int(err)})
		return false
	load_contests()
	var contest_state: Node = get_node_or_null("/root/ContestState")
	if contest_state != null and contest_state.has_method("load_contests"):
		contest_state.call("load_contests")
	return true

func load_maps() -> void:
	maps.clear()
	var dir: DirAccess = DirAccess.open(MAPS_DIR)
	if dir != null:
		for file_name in dir.get_files():
			if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
				continue
			var map_def: MapDef = load("%s/%s" % [MAPS_DIR, file_name]) as MapDef
			if map_def == null or map_def.id.strip_edges().is_empty():
				continue
			maps[map_def.id.strip_edges()] = map_def
	for path_any in MAP_LOADER.list_maps():
		var path: String = str(path_any).strip_edges()
		var map_id: String = MAP_REGISTRY.map_id_from_path(path).strip_edges()
		if map_id.is_empty() or maps.has(map_id):
			continue
		var generated: MapDef = MapDef.new()
		generated.id = map_id
		generated.display_name = MAP_LOADER.display_name_for_map(map_id)
		generated.map_scene_path = path
		generated.preview_path = ""
		generated.in_pool = true
		maps[map_id] = generated

func get_map_ids() -> PackedStringArray:
	var keys: Array = maps.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return str(a).naturalnocasecmp_to(str(b)) < 0
	)
	var ids: PackedStringArray = PackedStringArray()
	for key_any in keys:
		ids.append(str(key_any))
	return ids

func save_map(map_def: MapDef) -> bool:
	if map_def == null or map_def.id.strip_edges().is_empty():
		return false
	var dir_path: String = ProjectSettings.globalize_path(MAPS_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var path: String = "%s/%s.tres" % [MAPS_DIR, map_def.id.strip_edges()]
	var err: Error = ResourceSaver.save(map_def, path)
	if err != OK:
		SFLog.warn("OPS_MAP_SAVE_FAILED", {"path": path, "error": int(err)})
		return false
	load_maps()
	return true

func request_map_test(map_id: String) -> void:
	var clean_id: String = map_id.strip_edges()
	if clean_id.is_empty():
		return
	current_map_id = clean_id
	map_selected.emit(clean_id)

func open_ops_console(parent: Node = null) -> Control:
	if _console_instance == null or not is_instance_valid(_console_instance):
		var scene: PackedScene = load(OPS_CONSOLE_SCENE) as PackedScene
		if scene == null:
			return null
		_console_instance = scene.instantiate() as Control
		if _console_instance == null:
			return null
		var host: Node = parent if parent != null else get_tree().root
		host.add_child(_console_instance)
	_console_instance.visible = true
	if _console_instance.has_method("refresh"):
		_console_instance.call("refresh")
	return _console_instance

func close_ops_console() -> void:
	if _console_instance != null and is_instance_valid(_console_instance):
		_console_instance.visible = false

func toggle_ops_console(parent: Node = null) -> void:
	if _console_instance != null and is_instance_valid(_console_instance) and _console_instance.visible:
		close_ops_console()
	else:
		open_ops_console(parent)

func get_contract_state_hash() -> String:
	return _build_contract_state_signature().sha256_text()

func get_authority_snapshot() -> Dictionary:
	var st: GameState = state
	if st == null:
		return {}
	var unit_system: Object = st.unit_system
	var units_any: Variant = unit_system.get("units") if unit_system != null else []
	return {
		"version": 1,
		"hash": get_contract_state_hash(),
		"tick": int(st.tick),
		"current_map_id": current_map_id,
		"match_phase": int(match_phase),
		"outcome": int(outcome),
		"outcome_tick": int(outcome_tick),
		"outcome_reason": outcome_reason,
		"winner_id": int(winner_id),
		"end_reason": end_reason,
		"match_duration_ms": int(match_duration_ms),
		"match_elapsed_ms": int(match_elapsed_ms),
		"match_time_remaining_ms": int(match_time_remaining_ms),
		"match_remaining_ms": int(match_remaining_ms),
		"match_deadline_ms": int(match_deadline_ms),
		"match_clock_running": bool(match_clock_running),
		"match_clock_started": bool(match_clock_started),
		"victory_mode": victory_mode,
		"victory_rules": victory_rules.duplicate(true),
		"capture_flag_state": capture_flag_state.duplicate(true),
		"stats_by_team": stats_by_team.duplicate(true),
		"team_mode_override": team_mode_override,
		"match_roster": match_roster.duplicate(true),
		"lane_front_by_lane_id": lane_front_by_lane_id.duplicate(true),
		"state": {
			"hives": _authority_snapshot_hives(st),
			"lanes": _authority_snapshot_lanes(st),
			"lane_candidates": st.lane_candidates.duplicate(true),
			"walls": st.walls.duplicate(true),
			"spawns": st.spawns.duplicate(true),
			"swarm_requests": st.swarm_requests.duplicate(true),
			"swarm_packets": st.swarm_packets.duplicate(true),
			"swarm_cooldown_until_us": st.swarm_cooldown_until_us.duplicate(true),
			"lane_retract_requests": st.lane_retract_requests.duplicate(true),
			"towers": st.towers.duplicate(true),
			"barracks": st.barracks.duplicate(true),
			"structure_owner_by_node_id": st.structure_owner_by_node_id.duplicate(true),
			"tower_owner_by_node_id": st.tower_owner_by_node_id.duplicate(true),
			"hive_spawn_block_until_us": st.hive_spawn_block_until_us.duplicate(true),
			"passive_power_block_until_ms_by_hive": st.passive_power_block_until_ms_by_hive.duplicate(true),
			"tick": int(st.tick),
			"sim_time_us": int(st.get("_sim_time_us")),
			"units": (units_any as Array).duplicate(true) if typeof(units_any) == TYPE_ARRAY else [],
			"unit_id_counter": int(unit_system.get("unit_id_counter")) if unit_system != null else 1,
			"unit_sim_time_us": int(unit_system.get("sim_time_us")) if unit_system != null else 0,
			"units_set_version": int(st.units_set_version)
		}
	}

func restore_authority_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var state_any: Variant = snapshot.get("state", {})
	if typeof(state_any) != TYPE_DICTIONARY:
		return false
	var state_snapshot: Dictionary = state_any as Dictionary
	var st: GameState = state
	if st == null:
		st = GameState.new()
		state = st
	var unit_system: Object = st.unit_system
	current_map_id = str(snapshot.get("current_map_id", current_map_id))
	match_phase = int(snapshot.get("match_phase", match_phase))
	outcome = int(snapshot.get("outcome", outcome))
	outcome_tick = int(snapshot.get("outcome_tick", outcome_tick))
	outcome_reason = str(snapshot.get("outcome_reason", outcome_reason))
	winner_id = int(snapshot.get("winner_id", winner_id))
	end_reason = str(snapshot.get("end_reason", end_reason))
	match_duration_ms = int(snapshot.get("match_duration_ms", match_duration_ms))
	match_elapsed_ms = int(snapshot.get("match_elapsed_ms", match_elapsed_ms))
	match_time_remaining_ms = int(snapshot.get("match_time_remaining_ms", match_time_remaining_ms))
	match_time_remaining_sec = float(match_time_remaining_ms) / 1000.0
	match_remaining_ms = int(snapshot.get("match_remaining_ms", match_remaining_ms))
	match_deadline_ms = int(snapshot.get("match_deadline_ms", match_deadline_ms))
	match_clock_running = bool(snapshot.get("match_clock_running", match_clock_running))
	match_clock_started = bool(snapshot.get("match_clock_started", match_clock_started))
	victory_mode = str(snapshot.get("victory_mode", victory_mode))
	victory_rules = (snapshot.get("victory_rules", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("victory_rules", {})) == TYPE_DICTIONARY else {}
	capture_flag_state = (snapshot.get("capture_flag_state", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("capture_flag_state", {})) == TYPE_DICTIONARY else {}
	stats_by_team = (snapshot.get("stats_by_team", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("stats_by_team", {})) == TYPE_DICTIONARY else {}
	team_mode_override = str(snapshot.get("team_mode_override", team_mode_override))
	match_roster = (snapshot.get("match_roster", []) as Array).duplicate(true) if typeof(snapshot.get("match_roster", [])) == TYPE_ARRAY else []
	lane_front_by_lane_id = (snapshot.get("lane_front_by_lane_id", {}) as Dictionary).duplicate(true) if typeof(snapshot.get("lane_front_by_lane_id", {})) == TYPE_DICTIONARY else {}
	st.hives = _authority_restore_hives(state_snapshot.get("hives", []))
	st.lanes = _authority_restore_lanes(state_snapshot.get("lanes", []))
	st.lane_candidates = (state_snapshot.get("lane_candidates", []) as Array).duplicate(true) if typeof(state_snapshot.get("lane_candidates", [])) == TYPE_ARRAY else []
	st.walls = (state_snapshot.get("walls", []) as Array).duplicate(true) if typeof(state_snapshot.get("walls", [])) == TYPE_ARRAY else []
	st.spawns = (state_snapshot.get("spawns", []) as Array).duplicate(true) if typeof(state_snapshot.get("spawns", [])) == TYPE_ARRAY else []
	st.swarm_requests = (state_snapshot.get("swarm_requests", []) as Array).duplicate(true) if typeof(state_snapshot.get("swarm_requests", [])) == TYPE_ARRAY else []
	st.swarm_packets = (state_snapshot.get("swarm_packets", []) as Array).duplicate(true) if typeof(state_snapshot.get("swarm_packets", [])) == TYPE_ARRAY else []
	st.swarm_cooldown_until_us = (state_snapshot.get("swarm_cooldown_until_us", {}) as Dictionary).duplicate(true) if typeof(state_snapshot.get("swarm_cooldown_until_us", {})) == TYPE_DICTIONARY else {}
	st.lane_retract_requests = (state_snapshot.get("lane_retract_requests", []) as Array).duplicate(true) if typeof(state_snapshot.get("lane_retract_requests", [])) == TYPE_ARRAY else []
	st.towers = (state_snapshot.get("towers", []) as Array).duplicate(true) if typeof(state_snapshot.get("towers", [])) == TYPE_ARRAY else []
	st.barracks = (state_snapshot.get("barracks", []) as Array).duplicate(true) if typeof(state_snapshot.get("barracks", [])) == TYPE_ARRAY else []
	st.structure_owner_by_node_id = (state_snapshot.get("structure_owner_by_node_id", {}) as Dictionary).duplicate(true) if typeof(state_snapshot.get("structure_owner_by_node_id", {})) == TYPE_DICTIONARY else {}
	st.tower_owner_by_node_id = st.structure_owner_by_node_id
	st.hive_spawn_block_until_us = (state_snapshot.get("hive_spawn_block_until_us", {}) as Dictionary).duplicate(true) if typeof(state_snapshot.get("hive_spawn_block_until_us", {})) == TYPE_DICTIONARY else {}
	st.passive_power_block_until_ms_by_hive = (state_snapshot.get("passive_power_block_until_ms_by_hive", {}) as Dictionary).duplicate(true) if typeof(state_snapshot.get("passive_power_block_until_ms_by_hive", {})) == TYPE_DICTIONARY else {}
	st.tick = int(state_snapshot.get("tick", st.tick))
	st.set("_sim_time_us", int(state_snapshot.get("sim_time_us", st.get("_sim_time_us"))))
	st.units_set_version = int(state_snapshot.get("units_set_version", st.units_set_version))
	st.rebuild_indexes()
	if unit_system != null:
		var units_any: Variant = state_snapshot.get("units", [])
		unit_system.set("units", (units_any as Array).duplicate(true) if typeof(units_any) == TYPE_ARRAY else [])
		unit_system.set("unit_id_counter", int(state_snapshot.get("unit_id_counter", 1)))
		unit_system.set("sim_time_us", int(state_snapshot.get("unit_sim_time_us", int(st.get("_sim_time_us")))))
		st.unit_system = unit_system
		st.units_by_lane.clear()
		st.units_by_lane["_all"] = unit_system.get("units")
	call_deferred("_emit_state_changed", st)
	return true

func get_pvp_debug_state_hash() -> String:
	return _build_pvp_debug_state_signature().sha256_text()

func get_pvp_debug_state_signature() -> String:
	return _build_pvp_debug_state_signature()

func get_pvp_debug_state_snapshot() -> Dictionary:
	var st: GameState = state
	var snapshot: Dictionary = {
		"map_id": current_map_id,
		"players": _pvp_debug_player_rows(),
		"hive_counts": {},
		"active_lanes": [],
		"swarms": [],
		"hash": ""
	}
	if st == null:
		snapshot["hash"] = get_pvp_debug_state_hash()
		return snapshot
	var hive_counts: Dictionary = {}
	for hive_any in st.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		hive_counts[owner_id] = int(hive_counts.get(owner_id, 0)) + 1
	snapshot["hive_counts"] = hive_counts
	var active_lanes: Array = []
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if not bool(lane.send_a) and not bool(lane.send_b):
			continue
		active_lanes.append({
			"lane_id": int(lane.id),
			"a_id": int(lane.a_id),
			"b_id": int(lane.b_id),
			"send_a": bool(lane.send_a),
			"send_b": bool(lane.send_b)
		})
	snapshot["active_lanes"] = active_lanes
	var swarm_rows: Array = []
	for swarm_any in st.swarm_packets:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var swarm: Dictionary = swarm_any as Dictionary
		swarm_rows.append({
			"id": int(swarm.get("id", -1)),
			"lane_id": int(swarm.get("lane_id", -1)),
			"owner_id": int(swarm.get("owner_id", 0)),
			"src": int(swarm.get("from_id", -1)),
			"dst": int(swarm.get("to_id", -1)),
			"count": int(swarm.get("count", 0)),
			"t": _round_contract_float(float(swarm.get("t", 0.0)))
		})
	snapshot["swarms"] = swarm_rows
	snapshot["hash"] = get_pvp_debug_state_hash()
	return snapshot

func _build_pvp_debug_state_signature() -> String:
	var st: GameState = state
	var parts: Array[String] = []
	parts.append("map=%s" % current_map_id)
	var player_rows: Array[String] = _pvp_debug_player_rows()
	player_rows.sort()
	parts.append("players=%s" % ",".join(player_rows))
	if st == null:
		parts.append("state=null")
		return "|".join(parts)
	var hive_rows: Array = []
	var hive_counts: Dictionary = {}
	for hive_any in st.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		hive_counts[owner_id] = int(hive_counts.get(owner_id, 0)) + 1
		hive_rows.append([
			int(hive.id),
			"h:%d:%d:%d" % [int(hive.id), owner_id, int(hive.power)]
		])
	hive_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	var owner_keys: Array = hive_counts.keys()
	owner_keys.sort()
	for owner_key in owner_keys:
		parts.append("hc:%d:%d" % [int(owner_key), int(hive_counts.get(owner_key, 0))])
	for hive_row_any in hive_rows:
		var hive_row: Array = hive_row_any as Array
		parts.append(str(hive_row[1]))
	var lane_rows: Array = []
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		if not bool(lane.send_a) and not bool(lane.send_b):
			continue
		lane_rows.append([
			int(lane.id),
			"l:%d:%d:%d:%d:%d" % [
				int(lane.id),
				int(lane.a_id),
				int(lane.b_id),
				1 if bool(lane.send_a) else 0,
				1 if bool(lane.send_b) else 0
			]
		])
	lane_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for lane_row_any in lane_rows:
		var lane_row: Array = lane_row_any as Array
		parts.append(str(lane_row[1]))
	var swarm_rows: Array = []
	for swarm_any in st.swarm_packets:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var swarm: Dictionary = swarm_any as Dictionary
		var swarm_id: int = int(swarm.get("id", -1))
		swarm_rows.append([
			swarm_id,
			"s:%d:%d:%d:%d:%d:%d:%d" % [
				swarm_id,
				int(swarm.get("lane_id", -1)),
				int(swarm.get("owner_id", 0)),
				int(swarm.get("from_id", -1)),
				int(swarm.get("to_id", -1)),
				int(swarm.get("count", 0)),
				_round_contract_float(float(swarm.get("t", 0.0)))
			]
		])
	swarm_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for swarm_row_any in swarm_rows:
		var swarm_row: Array = swarm_row_any as Array
		parts.append(str(swarm_row[1]))
	return "|".join(parts)

func _pvp_debug_player_rows() -> Array[String]:
	var rows: Array[String] = []
	for entry_any in match_roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		rows.append("%d:%s:%d" % [
			int(entry.get("seat", 0)),
			str(entry.get("uid", "")).strip_edges(),
			1 if bool(entry.get("active", false)) else 0
		])
	return rows

func _authority_snapshot_hives(st: GameState) -> Array:
	var rows: Array = []
	if st == null:
		return rows
	for hive_any in st.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		rows.append({
			"id": int(hive.id),
			"grid_pos": [int(hive.grid_pos.x), int(hive.grid_pos.y)],
			"render_grid_pos": [float(hive.render_grid_pos.x), float(hive.render_grid_pos.y)],
			"owner_id": int(hive.owner_id),
			"power": int(hive.power),
			"kind": str(hive.kind),
			"radius_px": float(hive.radius_px),
			"spawn_accum_ms": float(hive.spawn_accum_ms),
			"idle_accum_ms": float(hive.idle_accum_ms),
			"shock_ms": float(hive.shock_ms),
			"spawn_rr_index": int(hive.spawn_rr_index),
			"pass_rr_index": int(hive.pass_rr_index),
			"pass_preferred_targets": hive.pass_preferred_targets.duplicate()
		})
	return rows

func _authority_restore_hives(hives_any: Variant) -> Array[HiveData]:
	var rows: Array[HiveData] = []
	if typeof(hives_any) != TYPE_ARRAY:
		return rows
	for hive_any in hives_any as Array:
		if typeof(hive_any) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = hive_any as Dictionary
		var grid_any: Variant = data.get("grid_pos", [0, 0])
		var grid_arr: Array = grid_any as Array if typeof(grid_any) == TYPE_ARRAY else [0, 0]
		var render_any: Variant = data.get("render_grid_pos", [float(grid_arr[0]), float(grid_arr[1])])
		var render_arr: Array = render_any as Array if typeof(render_any) == TYPE_ARRAY else [float(grid_arr[0]), float(grid_arr[1])]
		var hive: HiveData = HiveData.new(
			int(data.get("id", 0)),
			Vector2i(int(grid_arr[0]), int(grid_arr[1])),
			int(data.get("owner_id", 0)),
			int(data.get("power", 0)),
			str(data.get("kind", "Hive")),
			float(data.get("radius_px", 0.0)),
			Vector2(float(render_arr[0]), float(render_arr[1]))
		)
		hive.spawn_accum_ms = float(data.get("spawn_accum_ms", 0.0))
		hive.idle_accum_ms = float(data.get("idle_accum_ms", 0.0))
		hive.shock_ms = float(data.get("shock_ms", 0.0))
		hive.spawn_rr_index = int(data.get("spawn_rr_index", 0))
		hive.pass_rr_index = int(data.get("pass_rr_index", 0))
		var preferred_any: Variant = data.get("pass_preferred_targets", [])
		hive.pass_preferred_targets.clear()
		if typeof(preferred_any) == TYPE_ARRAY:
			for target_any in preferred_any as Array:
				hive.pass_preferred_targets.append(int(target_any))
		rows.append(hive)
	return rows

func _authority_snapshot_lanes(st: GameState) -> Array:
	var rows: Array = []
	if st == null:
		return rows
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		rows.append({
			"id": int(lane.id),
			"a_id": int(lane.a_id),
			"b_id": int(lane.b_id),
			"dir": int(lane.dir),
			"send_a": bool(lane.send_a),
			"send_b": bool(lane.send_b),
			"a_pressure": float(lane.a_pressure),
			"b_pressure": float(lane.b_pressure),
			"a_stream_len": float(lane.a_stream_len),
			"b_stream_len": float(lane.b_stream_len),
			"build_t": float(lane.build_t),
			"last_impact_f": float(lane.last_impact_f),
			"establish_a": bool(lane.establish_a),
			"establish_b": bool(lane.establish_b),
			"establish_t0_ms": int(lane.establish_t0_ms),
			"spawn_accum_a_ms": float(lane.spawn_accum_a_ms),
			"spawn_accum_b_ms": float(lane.spawn_accum_b_ms),
			"retract_a": bool(lane.retract_a),
			"retract_b": bool(lane.retract_b),
			"a_seg": Array(lane.a_seg),
			"b_seg": Array(lane.b_seg),
			"seg_carry_ms": int(lane.seg_carry_ms)
		})
	return rows

func _authority_restore_lanes(lanes_any: Variant) -> Array:
	var rows: Array = []
	if typeof(lanes_any) != TYPE_ARRAY:
		return rows
	for lane_any in lanes_any as Array:
		if typeof(lane_any) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = lane_any as Dictionary
		var lane: LaneData = LaneData.new(
			int(data.get("id", 0)),
			int(data.get("a_id", 0)),
			int(data.get("b_id", 0)),
			int(data.get("dir", 1)),
			bool(data.get("send_a", false)),
			bool(data.get("send_b", false)),
			float(data.get("a_pressure", 0.0)),
			float(data.get("b_pressure", 0.0)),
			float(data.get("a_stream_len", 0.0)),
			float(data.get("b_stream_len", 0.0)),
			float(data.get("build_t", 1.0)),
			float(data.get("last_impact_f", 0.5)),
			bool(data.get("establish_a", false)),
			bool(data.get("establish_b", false)),
			int(data.get("establish_t0_ms", 0)),
			float(data.get("spawn_accum_a_ms", 0.0)),
			float(data.get("spawn_accum_b_ms", 0.0)),
			bool(data.get("retract_a", false)),
			bool(data.get("retract_b", false))
		)
		var a_seg_any: Variant = data.get("a_seg", [])
		var b_seg_any: Variant = data.get("b_seg", [])
		if typeof(a_seg_any) == TYPE_ARRAY:
			var a_seg: Array = a_seg_any as Array
			for i in range(mini(a_seg.size(), lane.a_seg.size())):
				lane.a_seg[i] = int(a_seg[i])
		if typeof(b_seg_any) == TYPE_ARRAY:
			var b_seg: Array = b_seg_any as Array
			for i in range(mini(b_seg.size(), lane.b_seg.size())):
				lane.b_seg[i] = int(b_seg[i])
		lane.seg_carry_ms = int(data.get("seg_carry_ms", 0))
		rows.append(lane)
	return rows

func _build_contract_state_signature() -> String:
	var st: GameState = state
	if st == null:
		return "state:null"
	var parts: Array[String] = []
	parts.append("map=%s" % current_map_id)
	parts.append("tick=%d" % int(st.tick))
	parts.append("sim_us=%d" % int(st.get("_sim_time_us")))
	parts.append("phase=%d" % int(match_phase))
	parts.append("outcome=%d" % int(outcome))
	parts.append("outcome_tick=%d" % int(outcome_tick))
	parts.append("winner=%d" % int(winner_id))
	parts.append("match_elapsed_ms=%d" % int(match_elapsed_ms))
	parts.append("match_remaining_ms=%d" % int(match_time_remaining_ms))
	parts.append("victory=%s" % get_victory_mode())
	var hive_rows: Array = []
	for hive_any in st.hives:
		if hive_any is HiveData:
			var hive: HiveData = hive_any as HiveData
			hive_rows.append([
				int(hive.id),
				"h:%d:%d:%d:%d:%d:%d:%d:%d" % [
					int(hive.id),
					int(hive.owner_id),
					int(hive.power),
					_round_contract_float(float(hive.spawn_accum_ms)),
					_round_contract_float(float(hive.idle_accum_ms)),
					_round_contract_float(float(hive.shock_ms)),
					int(hive.spawn_rr_index),
					int(hive.pass_rr_index)
				]
			])
	hive_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for row_any in hive_rows:
		var row: Array = row_any as Array
		parts.append(str(row[1]))
	var lane_rows: Array = []
	for lane_any in st.lanes:
		if lane_any is LaneData:
			var lane: LaneData = lane_any as LaneData
			lane_rows.append([
				int(lane.id),
				"l:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [
					int(lane.id),
					int(lane.a_id),
					int(lane.b_id),
					1 if bool(lane.send_a) else 0,
					1 if bool(lane.send_b) else 0,
					int(lane.dir),
					_round_contract_float(float(lane.a_pressure)),
					_round_contract_float(float(lane.b_pressure)),
					_round_contract_float(float(lane.spawn_accum_a_ms)),
					_round_contract_float(float(lane.spawn_accum_b_ms)),
					_round_contract_float(float(lane.build_t)),
					_round_contract_float(float(lane.a_stream_len)),
					_round_contract_float(float(lane.b_stream_len)),
					1 if bool(lane.establish_a) else 0,
					1 if bool(lane.establish_b) else 0,
					1 if bool(lane.retract_a) else 0,
					1 if bool(lane.retract_b) else 0,
					int(lane.seg_carry_ms)
				]
			])
	lane_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for row_any in lane_rows:
		var row: Array = row_any as Array
		parts.append(str(row[1]))
	var unit_rows: Array = []
	var unit_system: Object = st.unit_system
	var units_any: Variant = unit_system.get("units") if unit_system != null else []
	if typeof(units_any) == TYPE_ARRAY:
		for unit_any in units_any as Array:
			if typeof(unit_any) != TYPE_DICTIONARY:
				continue
			var unit: Dictionary = unit_any as Dictionary
			var unit_id: int = int(unit.get("id", -1))
			unit_rows.append([
				unit_id,
				"u:%d:%d:%d:%d:%d:%d:%d:%d" % [
					unit_id,
					int(unit.get("lane_id", -1)),
					int(unit.get("owner_id", 0)),
					int(unit.get("from_id", -1)),
					int(unit.get("to_id", -1)),
					int(unit.get("dir", 0)),
					int(unit.get("amount", 0)),
					_round_contract_float(float(unit.get("t", 0.0)))
				]
			])
	unit_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for row_any in unit_rows:
		var row: Array = row_any as Array
		parts.append(str(row[1]))
	var request_rows: Array = []
	for req_any in st.swarm_requests:
		if typeof(req_any) != TYPE_DICTIONARY:
			continue
		var req: Dictionary = req_any as Dictionary
		request_rows.append("swreq:%d:%d" % [int(req.get("src", -1)), int(req.get("dst", -1))])
	request_rows.sort()
	for row_any in request_rows:
		parts.append(str(row_any))
	var swarm_rows: Array = []
	for swarm_any in st.swarm_packets:
		if typeof(swarm_any) != TYPE_DICTIONARY:
			continue
		var swarm: Dictionary = swarm_any as Dictionary
		var swarm_id: int = int(swarm.get("id", -1))
		swarm_rows.append([
			swarm_id,
			"s:%d:%d:%d:%d:%d:%d:%d" % [
				swarm_id,
				int(swarm.get("lane_id", -1)),
				int(swarm.get("owner_id", 0)),
				int(swarm.get("from_id", -1)),
				int(swarm.get("to_id", -1)),
				int(swarm.get("count", 0)),
				_round_contract_float(float(swarm.get("t", 0.0)))
			]
		])
	swarm_rows.sort_custom(Callable(self, "_sort_contract_row_by_id"))
	for row_any in swarm_rows:
		var row: Array = row_any as Array
		parts.append(str(row[1]))
	var cooldown_keys: Array = st.swarm_cooldown_until_us.keys()
	cooldown_keys.sort()
	for key_any in cooldown_keys:
		parts.append("swcool:%s:%d" % [str(key_any), int(st.swarm_cooldown_until_us.get(key_any, 0))])
	var retract_rows: Array = []
	for retract_any in st.lane_retract_requests:
		if typeof(retract_any) != TYPE_DICTIONARY:
			continue
		var retract: Dictionary = retract_any as Dictionary
		retract_rows.append("retract:%d:%d:%d:%d" % [
			int(retract.get("lane_id", -1)),
			int(retract.get("from_id", -1)),
			int(retract.get("to_id", -1)),
			int(retract.get("owner_id", 0))
		])
	retract_rows.sort()
	for row_any in retract_rows:
		parts.append(str(row_any))
	var lane_front_keys: Array = lane_front_by_lane_id.keys()
	lane_front_keys.sort()
	for key_any in lane_front_keys:
		parts.append("front:%s:%d" % [str(key_any), _round_contract_float(float(lane_front_by_lane_id.get(key_any, 0.0)))])
	var tower_rows: Array = []
	for tower_any in st.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var tower: Dictionary = tower_any as Dictionary
		tower_rows.append("tower:%d:%d:%d:%d" % [
			int(tower.get("id", -1)),
			int(tower.get("owner_id", 0)),
			int(tower.get("power", 0)),
			int(tower.get("current_power", 0))
		])
	tower_rows.sort()
	for row_any in tower_rows:
		parts.append(str(row_any))
	var barracks_rows: Array = []
	for barracks_any in st.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var barracks: Dictionary = barracks_any as Dictionary
		barracks_rows.append("barracks:%d:%d:%d:%d:%s" % [
			int(barracks.get("id", -1)),
			int(barracks.get("owner_id", 0)),
			int(barracks.get("route_cursor", 0)),
			int(barracks.get("current_power", 0)),
			JSON.stringify(barracks.get("route_hive_ids", []))
		])
	barracks_rows.sort()
	for row_any in barracks_rows:
		parts.append(str(row_any))
	return "|".join(parts)

func _round_contract_float(value: float) -> int:
	return int(round(value * 1000.0))

func _sort_contract_row_by_id(a: Array, b: Array) -> bool:
	return int(a[0]) < int(b[0])

func set_match_telemetry_collector(collector: RefCounted) -> void:
	_match_telemetry_collector = collector

func reset_runtime_telemetry() -> void:
	_runtime_telemetry_snapshot = _default_runtime_telemetry_snapshot()
	_runtime_telemetry_serial += 1

func update_runtime_telemetry(patch: Dictionary) -> void:
	if patch == null:
		return
	if _runtime_telemetry_snapshot.is_empty():
		reset_runtime_telemetry()
	for key_any in patch.keys():
		_runtime_telemetry_snapshot[key_any] = patch.get(key_any)
	_runtime_telemetry_snapshot["updated_ms"] = Time.get_ticks_msec()
	_runtime_telemetry_serial += 1

func get_runtime_telemetry_snapshot() -> Dictionary:
	if _runtime_telemetry_snapshot.is_empty():
		reset_runtime_telemetry()
	var out: Dictionary = _runtime_telemetry_snapshot.duplicate(true)
	out["serial"] = _runtime_telemetry_serial
	return out

func _default_runtime_telemetry_snapshot() -> Dictionary:
	return {
		"updated_ms": 0,
		"transport_active": false,
		"transport_mode": "local",
		"local_fps": 0.0,
		"local_frame_ms_avg": 0.0,
		"local_frame_ms_max": 0.0,
		"local_process_ms_avg": 0.0,
		"local_process_ms_max": 0.0,
		"local_physics_fps": 0.0,
		"local_physics_fixed_hz": float(Engine.physics_ticks_per_second),
		"local_sim_tick_rate_hz": 0.0,
		"local_sim_fixed_hz": 0.0,
		"sim_ms": 0.0,
		"sim_ms_max": 0.0,
		"sim_time_scale": 1.0,
		"accumulated_sim_delta_ms": 0.0,
		"server_tick_rate_hz": 0.0,
		"server_frametime_ms": 0.0,
		"snapshot_receive_rate_hz": 0.0,
		"ping_rtt_ms": 0.0,
		"ping_rtt_ema_ms": 0.0,
		"packet_tx": 0,
		"packet_rx": 0,
		"packet_dropped": 0,
		"intent_events_tx": 0,
		"intent_events_rx": 0,
		"contract_version": 0,
		"contract_command_lead_ticks": -1,
		"contract_min_command_lead_ticks": -1,
		"contract_missed_scheduled_commands": 0,
		"contract_late_scheduled_commands": 0,
		"contract_buffered_lagging_commands": 0,
		"contract_state_hash_mismatches": 0,
		"contract_violation_count": 0,
		"contract_last_violation_reason": "",
		"contract_report_path": "",
		"contract_pending_commands": 0,
		"peer_desync_or_lagging": false,
		"peer_desync_or_lagging_reason": "",
		"peer_desync_or_lagging_details": {},
		"recovery_state": "running",
		"recovery_attempts": 0,
		"recovery_last_outcome": "",
		"recovery_desync_tick": -1,
		"last_matching_checkpoint_tick": -1,
		"authority_snapshot_count": 0,
		"accepted_command_log_size": 0,
		"waiting_for_remote": false,
		"waiting_for_remote_reason": "not_lockstep",
		"pool_hits": 0,
		"pool_misses": 0,
		"pool_expansions": 0,
		"runtime_instantiates_avoided": 0,
		"active_pooled_objects": 0,
		"available_pooled_objects": 0,
		"total_pooled_objects": 0,
		"peak_pooled_objects": 0,
		"match_prewarm_duration_ms": 0.0,
		"post_match_save_duration_ms": 0.0
	}

func require_state() -> GameState:
	assert(state != null, "OpsState.state is null. State must be created explicitly via reset_state_from_map().")
	return state

func get_state_iid() -> int:
	if state == null:
		return 0
	return int(state.get_instance_id())

func with_remote_replication_apply(callback: Callable) -> void:
	_remote_replication_apply_depth += 1
	callback.call()
	_remote_replication_apply_depth = maxi(0, _remote_replication_apply_depth - 1)

func set_edge_cache(cache: Dictionary) -> void:
	edge_cache = cache if cache != null else {}

func get_edge_for_lane_key(key: Variant) -> Variant:
	return edge_cache.get(key, null)

func bump_edge_cache_version(v: int) -> void:
	edge_cache_version = v

func set_blocked_wall_pairs(pairs: Array) -> void:
	blocked_wall_pairs = pairs if pairs != null else []

func get_blocked_wall_pairs() -> Array:
	return blocked_wall_pairs if blocked_wall_pairs != null else []

func has_outcome() -> bool:
	return match_phase == MatchPhase.ENDED

func is_running() -> bool:
	return match_phase == MatchPhase.RUNNING

func is_match_running() -> bool:
	return is_running()

func is_ending_or_ended() -> bool:
	return match_phase != MatchPhase.RUNNING

func reset_match_state() -> void:
	match_phase = MatchPhase.PREMATCH
	outcome = GameState.GameOutcome.NONE
	outcome_tick = -1
	outcome_reason = ""
	winner_id = 0
	end_reason = ""
	ended_ms = 0
	ending_started_ms = 0
	ending_linger_ms = 1250
	end_screen_ready_ms = 0
	rematch_deadline_ms = 0
	rematch_votes.clear()
	post_end_action = ""
	stats_by_team = {}
	match_duration_ms = _configured_match_duration_ms()
	match_elapsed_ms = 0
	match_time_remaining_sec = float(match_duration_ms) / 1000.0
	match_time_remaining_ms = match_duration_ms
	match_remaining_ms = match_duration_ms
	match_deadline_ms = 0
	timer_visible_started = false
	in_overtime = false
	ot_checked = false
	match_clock_running = false
	match_clock_started = false
	match_end_reason = ""
	_match_timer_config_logged = false
	_input_ignored_match_over_logged = false
	match_over = false
	input_locked = true
	input_locked_reason = "prematch"
	prematch_duration_ms = PREMATCH_DURATION_MS
	prematch_remaining_ms = prematch_duration_ms
	match_end_ms = 0
	lane_front_by_lane_id.clear()
	match_roster.clear()
	bot_profiles.clear()
	_hud_snapshot = {}
	reset_runtime_telemetry()
	victory_mode = VICTORY_MODE_CONQUEST
	victory_rules = {}
	capture_flag_state = {}
	_intent_log_match_id = ""
	current_map_id = ""

func set_prematch_remaining_ms(value_ms: int, context: String = "") -> void:
	var ctx: String = context
	if ctx == "":
		ctx = "set_prematch_remaining_ms"
	audit_mutation(ctx, "prematch_remaining_ms")
	prematch_remaining_ms = value_ms

func get_hud_snapshot() -> Dictionary:
	if _hud_snapshot.is_empty():
		return _default_hud_snapshot()
	return _hud_snapshot

func update_hud_snapshot(snapshot: Dictionary) -> void:
	if snapshot == null:
		return
	if snapshot == _hud_snapshot:
		return
	_hud_snapshot = snapshot
	emit_signal("hud_changed", _hud_snapshot)

func _default_hud_snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for seat in range(1, 5):
		snap[seat] = {"power": 0}
	snap["visible_seats"] = 2
	return snap

func _normalize_team_mode(mode: String) -> String:
	var norm: String = mode.strip_edges().to_lower()
	if norm == TEAM_MODE_FFA:
		return TEAM_MODE_FFA
	return TEAM_MODE_2V2

func set_team_mode_override(mode: String) -> void:
	var normalized: String = _normalize_team_mode(mode)
	if team_mode_override == normalized:
		return
	team_mode_override = normalized
	SFLog.info("TEAM_MODE_OVERRIDE", {"mode": team_mode_override})

func get_team_mode_override() -> String:
	return _normalize_team_mode(team_mode_override)

func _normalize_bot_style(style: String) -> String:
	var normalized: String = style.strip_edges().to_lower()
	if normalized == "swarmmaster" or normalized == "swarm_master" or normalized == "swarmdaddy":
		return BOT_STYLE_SWARM_LORD
	match normalized:
		BOT_STYLE_TURTLE, BOT_STYLE_RAIDER, BOT_STYLE_GREEDY, BOT_STYLE_SWARM_LORD:
			return normalized
		_:
			return BOT_STYLE_BALANCER

func _normalize_bot_tier(tier: String) -> String:
	var normalized: String = tier.strip_edges().to_lower()
	match normalized:
		BOT_TIER_EASY, BOT_TIER_HARD:
			return normalized
		"expert":
			return BOT_TIER_HARD
		_:
			return BOT_TIER_MEDIUM

func _default_bot_style_for_seat(seat: int) -> String:
	match seat:
		2:
			return BOT_STYLE_RAIDER
		3:
			return BOT_STYLE_TURTLE
		4:
			return BOT_STYLE_GREEDY
		_:
			return BOT_STYLE_BALANCER

func _base_bot_profile_for_seat(seat: int) -> Dictionary:
	return {
		"seat": seat,
		"enabled": true,
		"policy": "baseline_v2",
		"style": BOT_STYLE_BALANCER,
		"persona": BOT_STYLE_BALANCER,
		"tier": BOT_TIER_MEDIUM,
		"think_interval_ms": 880,
		"think_jitter_ms": 120,
		"post_intent_delay_ms": 400,
		"opening_delay_ms": 1600 + (maxi(0, seat - 1) * 120),
		"opening_stagger_ms": 120,
		"aggression": 0.58,
		"feed_bias": 0.28,
		"min_attack_power": 9,
		"min_feed_power": 12,
		"min_swarm_power": 17,
		"allow_swarm": true,
		"max_actions_per_tick": 1,
		"prefer_neutral_bonus": 0.50,
		"randomness": 0.06,
		"retry_block_ms": 900,
		"no_lane_retry_ms": 3200,
		"pair_intent_cooldown_ms": 1300,
		"global_intent_cooldown_ms": 1000,
		"swarm_cooldown_ms": 1600,
		"swarm_global_cooldown_ms": 3500,
		"attack_distance_weight": 2.0,
		"feed_distance_weight": 1.6,
		"attack_power_diff_weight": 1.2,
		"feed_need_weight": 1.3,
		"weak_target_bonus": 4.0,
		"strong_target_penalty": 6.0,
		"low_ally_power_bonus": 5.0,
		"enemy_owned_bonus": 2.5,
		"neutral_capture_bonus": 8.0,
		"swarm_distance_weight": 1.2,
		"swarm_power_diff_weight": 1.8,
		"swarm_low_power_bonus": 6.0,
		"weak_target_threshold": 12,
		"swarm_frequency": 0.34,
		"guard_ally_power_threshold": 0,
		"guard_feed_score_margin": 0.0,
		"prefer_enemy_owned_attacks": false,
		"enemy_owned_attack_priority_bonus": 0.0,
		"expansion_priority": 0.45,
		"safe_expansion_distance_weight": 0.0,
		"enemy_pressure_bias": 0.35,
		"exposed_target_bonus": 0.0,
		"isolation_bonus": 0.0,
		"risk_tolerance": 0.45,
		"overcommit_bias": 0.0,
		"preserve_core_bias": 0.25,
		"defense_urgency": 0.35,
		"forward_reinforce_bias": 0.0,
		"comeback_feed_bonus": 0.0,
		"comeback_attack_bonus": 0.0,
		"comeback_aggression_bonus": 0.0,
		"lead_attack_bonus": 0.0,
		"lead_aggression_bonus": 0.0,
		"lead_swarm_bonus": 0.0,
		"closeout_feed_reluctance": 0.0,
		"early_patience_ms": 0,
		"early_enemy_attack_penalty": 0.0,
		"early_attack_weight_penalty": 0.0,
		"early_swarm_penalty": 0.0,
		"complex_attack_score_bonus": 0.0,
		"compact_attack_score_bonus": 0.0,
		"complex_expansion_bonus": 0.0,
		"compact_expansion_bonus": 0.0,
		"complex_enemy_pressure_bonus": 0.0,
		"compact_enemy_pressure_bonus": 0.0,
		"complex_feed_bonus": 0.0,
		"compact_feed_bonus": 0.0,
		"complex_aggression_bonus": 0.0,
		"compact_aggression_bonus": 0.0,
		"complex_swarm_bonus": 0.0,
		"compact_swarm_bonus": 0.0,
		"early_neutral_capture_ms": 0,
		"early_neutral_attack_bonus": 0.0,
		"early_neutral_complex_bonus": 0.0,
		"early_neutral_compact_bonus": 0.0,
		"early_feed_shape_ms": 0,
		"early_forward_feed_bonus": 0.0,
		"early_backline_feed_penalty": 0.0,
		"complex_min_attack_power_bonus": 0.0,
		"compact_min_attack_power_bonus": 0.0,
		"sloppy_hesitation_rate": 0.0,
		"sloppy_extra_lane_forget_rate": 0.0,
		"sloppy_overextend_attack_rate": 0.0,
		"sloppy_bad_swarm_rate": 0.0
	}

func _bot_style_patch(style: String) -> Dictionary:
	var normalized_style: String = _normalize_bot_style(style)
	match normalized_style:
		BOT_STYLE_TURTLE:
			return {
				"style": BOT_STYLE_TURTLE,
				"persona": BOT_STYLE_TURTLE,
				"think_interval_ms": 900,
				"think_jitter_ms": 150,
				"post_intent_delay_ms": 420,
				"opening_delay_ms": 1050,
				"aggression": 0.74,
				"feed_bias": 0.18,
				"min_attack_power": 5,
				"min_feed_power": 10,
				"min_swarm_power": 42,
				"allow_swarm": true,
				"prefer_neutral_bonus": 0.92,
				"randomness": 0.05,
				"pair_intent_cooldown_ms": 1800,
				"global_intent_cooldown_ms": 1450,
				"attack_distance_weight": 2.0,
				"feed_distance_weight": 1.45,
				"attack_power_diff_weight": 1.25,
				"feed_need_weight": 1.20,
				"weak_target_bonus": 4.0,
				"strong_target_penalty": 7.0,
				"low_ally_power_bonus": 4.0,
				"enemy_owned_bonus": 3.2,
				"neutral_capture_bonus": 9.5,
				"guard_ally_power_threshold": 9,
				"guard_feed_score_margin": 3.0,
				"attack_commit_margin": 0.0,
				"swarm_frequency": 0.095,
				"expansion_priority": 0.64,
				"safe_expansion_distance_weight": 0.55,
				"enemy_pressure_bias": 0.15,
				"risk_tolerance": 0.22,
				"preserve_core_bias": 0.85,
				"defense_urgency": 1.25,
				"forward_reinforce_bias": 5.0,
				"comeback_feed_bonus": 10.0,
				"lead_attack_bonus": -2.0,
				"closeout_feed_reluctance": 0.0,
				"complex_attack_score_bonus": 70.0,
				"complex_expansion_bonus": 80.0,
				"complex_enemy_pressure_bonus": 22.0,
				"complex_feed_bonus": 3.0,
				"complex_aggression_bonus": 0.50,
				"lead_swarm_bonus": 0.01,
				"compact_attack_score_bonus": -35.0,
				"compact_expansion_bonus": -18.0,
				"compact_aggression_bonus": -0.32,
				"early_neutral_capture_ms": 70000,
				"early_neutral_attack_bonus": 36.0,
				"early_neutral_complex_bonus": 80.0,
				"early_neutral_compact_bonus": -60.0,
				"early_feed_shape_ms": 70000,
				"early_forward_feed_bonus": 22.0,
				"early_backline_feed_penalty": 34.0,
				"complex_min_attack_power_bonus": -2.0,
				"compact_min_attack_power_bonus": 4.0,
				"sloppy_hesitation_rate": 0.018,
				"sloppy_extra_lane_forget_rate": 0.020,
				"sloppy_overextend_attack_rate": 0.002,
				"sloppy_bad_swarm_rate": 0.003
			}
		BOT_STYLE_RAIDER:
			return {
				"style": BOT_STYLE_RAIDER,
				"persona": BOT_STYLE_RAIDER,
				"think_interval_ms": 1080,
				"think_jitter_ms": 140,
				"post_intent_delay_ms": 640,
				"opening_delay_ms": 1550,
				"aggression": 0.72,
				"feed_bias": 0.16,
				"min_attack_power": 8,
				"min_feed_power": 14,
				"min_swarm_power": 28,
				"allow_swarm": true,
				"prefer_neutral_bonus": 0.20,
				"randomness": 0.07,
				"retry_block_ms": 700,
				"no_lane_retry_ms": 2500,
				"pair_intent_cooldown_ms": 1500,
				"global_intent_cooldown_ms": 1250,
				"attack_distance_weight": 1.55,
				"feed_distance_weight": 1.9,
				"attack_power_diff_weight": 1.25,
				"feed_need_weight": 1.0,
				"weak_target_bonus": 6.0,
				"strong_target_penalty": 6.5,
				"low_ally_power_bonus": 2.0,
				"enemy_owned_bonus": 3.0,
				"neutral_capture_bonus": 4.0,
				"swarm_distance_weight": 1.0,
				"swarm_power_diff_weight": 1.35,
				"swarm_low_power_bonus": 4.0,
				"swarm_frequency": 0.16,
				"prefer_enemy_owned_attacks": true,
				"enemy_owned_attack_priority_bonus": 5.0,
				"expansion_priority": 0.18,
				"safe_expansion_distance_weight": 0.0,
				"enemy_pressure_bias": 0.42,
				"exposed_target_bonus": 3.5,
				"isolation_bonus": 3.0,
				"risk_tolerance": 0.42,
				"overcommit_bias": 0.05,
				"preserve_core_bias": 0.42,
				"defense_urgency": 0.25,
				"forward_reinforce_bias": 1.0,
				"comeback_attack_bonus": 3.0,
				"comeback_aggression_bonus": 0.02,
				"lead_attack_bonus": 1.0,
				"lead_swarm_bonus": 0.01,
				"compact_attack_score_bonus": 18.0,
				"compact_enemy_pressure_bonus": 22.0,
				"compact_aggression_bonus": 0.28,
				"complex_attack_score_bonus": -40.0,
				"complex_expansion_bonus": -32.0,
				"complex_enemy_pressure_bonus": -44.0,
				"complex_aggression_bonus": -0.42,
				"complex_min_attack_power_bonus": 5.0,
				"complex_swarm_bonus": -0.08,
				"sloppy_hesitation_rate": 0.006,
				"sloppy_extra_lane_forget_rate": 0.012,
				"sloppy_overextend_attack_rate": 0.035,
				"sloppy_bad_swarm_rate": 0.015
			}
		BOT_STYLE_GREEDY:
			return {
				"style": BOT_STYLE_GREEDY,
				"persona": BOT_STYLE_GREEDY,
				"think_interval_ms": 760,
				"think_jitter_ms": 150,
				"post_intent_delay_ms": 300,
				"opening_delay_ms": 1200,
				"aggression": 0.92,
				"feed_bias": 0.04,
				"min_attack_power": 6,
				"min_feed_power": 13,
				"min_swarm_power": 30,
				"allow_swarm": true,
				"prefer_neutral_bonus": 1.35,
				"randomness": 0.16,
				"attack_distance_weight": 1.9,
				"feed_distance_weight": 1.9,
				"attack_power_diff_weight": 1.0,
				"feed_need_weight": 1.0,
				"weak_target_bonus": 3.0,
				"strong_target_penalty": 3.5,
				"low_ally_power_bonus": 1.0,
				"enemy_owned_bonus": 1.5,
				"neutral_capture_bonus": 10.0,
				"swarm_distance_weight": 1.1,
				"swarm_power_diff_weight": 1.25,
				"swarm_low_power_bonus": 4.0,
				"swarm_frequency": 0.16,
				"expansion_priority": 1.15,
				"safe_expansion_distance_weight": 0.0,
				"enemy_pressure_bias": 0.72,
				"exposed_target_bonus": 2.0,
				"isolation_bonus": 1.5,
				"risk_tolerance": 0.82,
				"overcommit_bias": 1.0,
				"preserve_core_bias": 0.0,
				"defense_urgency": 0.05,
				"forward_reinforce_bias": 8.0,
				"comeback_attack_bonus": 9.0,
				"comeback_aggression_bonus": 0.10,
				"lead_attack_bonus": 6.0,
				"lead_aggression_bonus": 0.05,
				"closeout_feed_reluctance": 8.0,
				"compact_attack_score_bonus": 8.0,
				"compact_expansion_bonus": 8.0,
				"compact_aggression_bonus": 0.12,
				"complex_attack_score_bonus": -90.0,
				"complex_expansion_bonus": -70.0,
				"complex_enemy_pressure_bonus": -45.0,
				"complex_aggression_bonus": -0.65,
				"complex_min_attack_power_bonus": 8.0,
				"sloppy_hesitation_rate": 0.002,
				"sloppy_extra_lane_forget_rate": 0.008,
				"sloppy_overextend_attack_rate": 0.055,
				"sloppy_bad_swarm_rate": 0.025
			}
		BOT_STYLE_SWARM_LORD:
			return {
				"style": BOT_STYLE_SWARM_LORD,
				"persona": BOT_STYLE_SWARM_LORD,
				"think_interval_ms": 820,
				"think_jitter_ms": 100,
				"post_intent_delay_ms": 360,
				"opening_delay_ms": 1450,
				"aggression": 0.68,
				"feed_bias": 0.28,
				"min_attack_power": 6,
				"min_feed_power": 10,
				"min_swarm_power": 32,
				"allow_swarm": true,
				"prefer_neutral_bonus": 1.12,
				"randomness": 0.08,
				"retry_block_ms": 650,
				"no_lane_retry_ms": 2200,
				"pair_intent_cooldown_ms": 1100,
				"global_intent_cooldown_ms": 950,
				"swarm_cooldown_ms": 900,
				"swarm_global_cooldown_ms": 1800,
				"attack_distance_weight": 1.35,
				"feed_distance_weight": 1.7,
				"attack_power_diff_weight": 1.45,
				"feed_need_weight": 1.25,
				"weak_target_bonus": 6.0,
				"strong_target_penalty": 5.0,
				"low_ally_power_bonus": 3.0,
				"enemy_owned_bonus": 2.6,
				"neutral_capture_bonus": 9.0,
				"swarm_distance_weight": 0.9,
				"swarm_power_diff_weight": 1.35,
				"swarm_low_power_bonus": 4.0,
				"weak_target_threshold": 14,
				"swarm_frequency": 0.12,
				"expansion_priority": 1.05,
				"safe_expansion_distance_weight": 0.10,
				"enemy_pressure_bias": 0.35,
				"exposed_target_bonus": 3.0,
				"isolation_bonus": 3.0,
				"risk_tolerance": 0.50,
				"overcommit_bias": 0.0,
				"preserve_core_bias": 0.45,
				"guard_ally_power_threshold": 12,
				"guard_feed_score_margin": 5.0,
				"defense_urgency": 0.95,
				"forward_reinforce_bias": 5.5,
				"comeback_feed_bonus": 10.0,
				"lead_attack_bonus": 8.0,
				"lead_aggression_bonus": 0.12,
				"lead_swarm_bonus": 0.005,
				"comeback_swarm_bonus": -0.04,
				"early_patience_ms": 24000,
				"early_enemy_attack_penalty": 8.0,
				"early_attack_weight_penalty": 0.0,
				"early_swarm_penalty": 0.06,
				"complex_attack_score_bonus": 54.0,
				"complex_expansion_bonus": 72.0,
				"complex_enemy_pressure_bonus": 16.0,
				"complex_feed_bonus": 12.0,
				"complex_aggression_bonus": 0.32,
				"complex_swarm_bonus": 0.0,
				"compact_attack_score_bonus": -24.0,
				"compact_expansion_bonus": -5.0,
				"compact_aggression_bonus": -0.15,
				"early_neutral_capture_ms": 80000,
				"early_neutral_attack_bonus": 34.0,
				"early_neutral_complex_bonus": 80.0,
				"early_neutral_compact_bonus": -35.0,
				"early_feed_shape_ms": 80000,
				"early_forward_feed_bonus": 18.0,
				"early_backline_feed_penalty": 24.0,
				"complex_min_attack_power_bonus": -2.0,
				"compact_min_attack_power_bonus": 1.0,
				"sloppy_hesitation_rate": 0.014,
				"sloppy_extra_lane_forget_rate": 0.008,
				"sloppy_overextend_attack_rate": 0.010,
				"sloppy_bad_swarm_rate": 0.006
			}
		_:
			return {
				"style": BOT_STYLE_BALANCER,
				"persona": BOT_STYLE_BALANCER,
				"think_interval_ms": 860,
				"think_jitter_ms": 150,
				"post_intent_delay_ms": 420,
				"opening_delay_ms": 1350,
				"pair_intent_cooldown_ms": 1200,
				"global_intent_cooldown_ms": 900,
				"guard_ally_power_threshold": 10,
				"guard_feed_score_margin": 4.0,
				"aggression": 0.72,
				"feed_bias": 0.16,
				"min_attack_power": 8,
				"min_feed_power": 11,
				"prefer_neutral_bonus": 0.92,
				"attack_power_diff_weight": 1.30,
				"weak_target_bonus": 5.0,
				"strong_target_penalty": 5.5,
				"neutral_capture_bonus": 8.5,
				"min_swarm_power": 32,
				"swarm_frequency": 0.105,
				"enemy_owned_bonus": 3.6,
				"expansion_priority": 0.72,
				"enemy_pressure_bias": 0.40,
				"exposed_target_bonus": 2.0,
				"isolation_bonus": 1.5,
				"risk_tolerance": 0.54,
				"preserve_core_bias": 0.35,
				"defense_urgency": 0.70,
				"forward_reinforce_bias": 3.0,
				"comeback_feed_bonus": 6.0,
				"comeback_attack_bonus": 5.0,
				"comeback_aggression_bonus": 0.04,
				"lead_attack_bonus": 4.0,
				"lead_aggression_bonus": 0.06,
				"lead_swarm_bonus": 0.005,
				"complex_expansion_bonus": 4.0,
				"complex_feed_bonus": 4.0,
				"complex_aggression_bonus": 0.02,
				"compact_expansion_bonus": 2.0,
				"compact_aggression_bonus": 0.02,
				"sloppy_hesitation_rate": 0.010,
				"sloppy_extra_lane_forget_rate": 0.012,
				"sloppy_overextend_attack_rate": 0.012,
				"sloppy_bad_swarm_rate": 0.008
			}

func _apply_bot_tier(profile: Dictionary, tier: String) -> void:
	var normalized_tier: String = _normalize_bot_tier(tier)
	var style_id: String = _normalize_bot_style(str(profile.get("style", profile.get("persona", ""))))
	profile["tier"] = normalized_tier
	match normalized_tier:
		BOT_TIER_EASY:
			profile["think_interval_ms"] = int(profile.get("think_interval_ms", 900)) + 450
			profile["think_jitter_ms"] = int(profile.get("think_jitter_ms", 120)) + 100
			profile["post_intent_delay_ms"] = int(profile.get("post_intent_delay_ms", 400)) + 300
			profile["opening_delay_ms"] = int(profile.get("opening_delay_ms", 1600)) + 1700
			profile["aggression"] = clampf(float(profile.get("aggression", 0.5)) - 0.16, 0.0, 1.0)
			profile["feed_bias"] = clampf(float(profile.get("feed_bias", 0.3)) + 0.06, 0.0, 1.0)
			profile["randomness"] = clampf(float(profile.get("randomness", 0.08)) + 0.10, 0.0, 0.5)
			profile["min_attack_power"] = int(profile.get("min_attack_power", 9)) + 4
			profile["min_feed_power"] = int(profile.get("min_feed_power", 12)) + 3
			profile["min_swarm_power"] = int(profile.get("min_swarm_power", 17)) + 5
			profile["retry_block_ms"] = int(profile.get("retry_block_ms", 900)) + 650
			profile["no_lane_retry_ms"] = int(profile.get("no_lane_retry_ms", 3200)) + 1500
			profile["pair_intent_cooldown_ms"] = int(profile.get("pair_intent_cooldown_ms", 1300)) + 850
			profile["global_intent_cooldown_ms"] = int(profile.get("global_intent_cooldown_ms", 1000)) + 800
			profile["swarm_cooldown_ms"] = int(profile.get("swarm_cooldown_ms", 1600)) + 1200
			profile["swarm_global_cooldown_ms"] = int(profile.get("swarm_global_cooldown_ms", 3500)) + 2200
			profile["swarm_frequency"] = clampf(float(profile.get("swarm_frequency", 0.34)) - 0.22, 0.0, 1.0)
			if style_id == BOT_STYLE_RAIDER:
				profile["opening_enemy_home_penalty"] = 0.0
				profile["opening_enemy_home_max_own_hives"] = 0
				profile["opening_enemy_home_max_enemy_hives"] = 0
				profile["early_enemy_core_penalty"] = 0.0
				profile["early_enemy_core_max_own_hives"] = 0
				profile["early_enemy_core_max_enemy_hives"] = 0
				profile["early_enemy_core_break_margin"] = 0
		BOT_TIER_HARD:
			# Current playtest read: previous Medium is the right Expert target.
			profile["think_interval_ms"] = int(profile.get("think_interval_ms", 900)) + 220
			profile["think_jitter_ms"] = int(profile.get("think_jitter_ms", 120)) + 40
			profile["post_intent_delay_ms"] = int(profile.get("post_intent_delay_ms", 400)) + 180
			profile["opening_delay_ms"] = int(profile.get("opening_delay_ms", 1600)) + 500
			profile["pair_intent_cooldown_ms"] = int(profile.get("pair_intent_cooldown_ms", 1300)) + 250
			profile["global_intent_cooldown_ms"] = int(profile.get("global_intent_cooldown_ms", 1000)) + 250
			profile["swarm_cooldown_ms"] = int(profile.get("swarm_cooldown_ms", 1600)) + 300
			profile["swarm_global_cooldown_ms"] = int(profile.get("swarm_global_cooldown_ms", 3500)) + 400
			if style_id == BOT_STYLE_RAIDER:
				profile["opening_enemy_home_penalty"] = 42.0
				profile["opening_enemy_home_max_own_hives"] = 2
				profile["opening_enemy_home_max_enemy_hives"] = 1
				profile["early_enemy_core_penalty"] = 16.0
				profile["early_enemy_core_max_own_hives"] = 3
				profile["early_enemy_core_max_enemy_hives"] = 2
				profile["early_enemy_core_break_margin"] = 8
		_:
			profile["think_interval_ms"] = int(profile.get("think_interval_ms", 900)) + 290
			profile["think_jitter_ms"] = int(profile.get("think_jitter_ms", 120)) + 60
			profile["post_intent_delay_ms"] = int(profile.get("post_intent_delay_ms", 400)) + 210
			profile["opening_delay_ms"] = int(profile.get("opening_delay_ms", 1600)) + 950
			profile["aggression"] = clampf(float(profile.get("aggression", 0.5)) - 0.06, 0.0, 1.0)
			profile["feed_bias"] = clampf(float(profile.get("feed_bias", 0.3)) + 0.02, 0.0, 1.0)
			profile["randomness"] = clampf(float(profile.get("randomness", 0.08)) + 0.04, 0.0, 0.5)
			profile["min_attack_power"] = int(profile.get("min_attack_power", 9)) + 2
			profile["min_feed_power"] = int(profile.get("min_feed_power", 12)) + 1
			profile["min_swarm_power"] = int(profile.get("min_swarm_power", 17)) + 2
			profile["retry_block_ms"] = int(profile.get("retry_block_ms", 900)) + 250
			profile["no_lane_retry_ms"] = int(profile.get("no_lane_retry_ms", 3200)) + 600
			profile["pair_intent_cooldown_ms"] = int(profile.get("pair_intent_cooldown_ms", 1300)) + 450
			profile["global_intent_cooldown_ms"] = int(profile.get("global_intent_cooldown_ms", 1000)) + 425
			profile["swarm_cooldown_ms"] = int(profile.get("swarm_cooldown_ms", 1600)) + 650
			profile["swarm_global_cooldown_ms"] = int(profile.get("swarm_global_cooldown_ms", 3500)) + 1100
			profile["swarm_frequency"] = clampf(float(profile.get("swarm_frequency", 0.34)) - 0.09, 0.0, 1.0)
			if style_id == BOT_STYLE_RAIDER:
				profile["opening_enemy_home_penalty"] = 21.0
				profile["opening_enemy_home_max_own_hives"] = 2
				profile["opening_enemy_home_max_enemy_hives"] = 1
				profile["early_enemy_core_penalty"] = 8.0
				profile["early_enemy_core_max_own_hives"] = 3
				profile["early_enemy_core_max_enemy_hives"] = 2
				profile["early_enemy_core_break_margin"] = 4
	if normalized_tier == BOT_TIER_HARD and style_id == BOT_STYLE_TURTLE:
		profile["think_interval_ms"] = maxi(420, int(profile.get("think_interval_ms", 900)) - 120)
		profile["post_intent_delay_ms"] = maxi(200, int(profile.get("post_intent_delay_ms", 400)) - 90)
		profile["opening_delay_ms"] = maxi(700, int(profile.get("opening_delay_ms", 1600)) - 180)
		profile["pair_intent_cooldown_ms"] = maxi(550, int(profile.get("pair_intent_cooldown_ms", 1300)) - 180)
		profile["global_intent_cooldown_ms"] = maxi(500, int(profile.get("global_intent_cooldown_ms", 1000)) - 140)
		profile["aggression"] = clampf(float(profile.get("aggression", 0.5)) + 0.05, 0.0, 1.0)
		profile["feed_bias"] = clampf(float(profile.get("feed_bias", 0.3)) - 0.05, 0.0, 1.0)
		profile["min_attack_power"] = maxi(1, int(profile.get("min_attack_power", 9)) - 1)
		profile["attack_power_diff_weight"] = clampf(float(profile.get("attack_power_diff_weight", 1.2)) + 0.08, 0.1, 5.0)
		profile["enemy_owned_bonus"] = clampf(float(profile.get("enemy_owned_bonus", 2.5)) + 0.8, 0.0, 10.0)
		profile["neutral_capture_bonus"] = clampf(float(profile.get("neutral_capture_bonus", 8.0)) + 0.8, 0.0, 20.0)
		profile["feed_need_weight"] = clampf(float(profile.get("feed_need_weight", 1.3)) - 0.12, 0.1, 5.0)
		profile["low_ally_power_bonus"] = clampf(float(profile.get("low_ally_power_bonus", 5.0)) - 1.0, 0.0, 20.0)
		profile["guard_ally_power_threshold"] = maxi(0, int(profile.get("guard_ally_power_threshold", 0)) - 1)
		profile["guard_feed_score_margin"] = clampf(float(profile.get("guard_feed_score_margin", 0.0)) - 1.5, 0.0, 40.0)
		profile["attack_commit_margin"] = clampf(float(profile.get("attack_commit_margin", 0.0)) + 3.0, 0.0, 40.0)

func _build_bot_profile_for_seat(seat: int, style: String, tier: String) -> Dictionary:
	var profile: Dictionary = _base_bot_profile_for_seat(seat)
	var normalized_style: String = _normalize_bot_style(style)
	var normalized_tier: String = _normalize_bot_tier(tier)
	var style_patch: Dictionary = _bot_style_patch(normalized_style)
	for key_any in style_patch.keys():
		profile[key_any] = style_patch.get(key_any)
	_apply_bot_tier(profile, normalized_tier)
	profile["seat"] = seat
	profile["style"] = normalized_style
	profile["persona"] = normalized_style
	profile["tier"] = normalized_tier
	profile["opening_delay_ms"] = int(profile.get("opening_delay_ms", 1600)) + BOT_REACTION_DELAY_EXTRA_MS
	profile["think_interval_ms"] = int(profile.get("think_interval_ms", 900)) + BOT_REACTION_DELAY_EXTRA_MS
	return profile

func _default_bot_profile_for_seat(seat: int) -> Dictionary:
	return _build_bot_profile_for_seat(seat, _default_bot_style_for_seat(seat), BOT_TIER_MEDIUM)

func _merge_bot_profile(seat: int, patch: Dictionary) -> Dictionary:
	var requested_style: String = _default_bot_style_for_seat(seat)
	var requested_tier: String = BOT_TIER_MEDIUM
	if patch != null:
		if patch.has("style"):
			requested_style = _normalize_bot_style(str(patch.get("style", requested_style)))
		elif patch.has("persona"):
			requested_style = _normalize_bot_style(str(patch.get("persona", requested_style)))
		if patch.has("tier"):
			requested_tier = _normalize_bot_tier(str(patch.get("tier", requested_tier)))
	var merged: Dictionary = _build_bot_profile_for_seat(seat, requested_style, requested_tier)
	if patch != null:
		for key_any in patch.keys():
			merged[key_any] = patch.get(key_any)
	merged["seat"] = seat
	merged["style"] = _normalize_bot_style(str(merged.get("style", merged.get("persona", requested_style))))
	merged["persona"] = str(merged.get("style", requested_style))
	merged["tier"] = _normalize_bot_tier(str(merged.get("tier", requested_tier)))
	return merged

func ensure_bot_profiles_from_roster() -> void:
	var next_profiles: Dictionary = {}
	var roster: Array = match_roster if match_roster != null else []
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		if seat < 1 or seat > 4:
			continue
		var is_cpu: bool = bool(entry.get("is_cpu", false))
		var active: bool = bool(entry.get("active", true))
		if not is_cpu or not active:
			continue
		var existing: Dictionary = bot_profiles.get(seat, {})
		next_profiles[seat] = _merge_bot_profile(seat, existing)
	bot_profiles = next_profiles

func get_bot_profile(seat: int) -> Dictionary:
	var seat_id: int = int(seat)
	if seat_id < 1 or seat_id > 4:
		return {}
	if not bot_profiles.has(seat_id):
		bot_profiles[seat_id] = _default_bot_profile_for_seat(seat_id)
	return (bot_profiles.get(seat_id, {}) as Dictionary).duplicate(true)

func set_bot_profile(seat: int, patch: Dictionary) -> void:
	var seat_id: int = int(seat)
	if seat_id < 1 or seat_id > 4:
		return
	bot_profiles[seat_id] = _merge_bot_profile(seat_id, patch)

func get_bot_profiles_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for seat_any in bot_profiles.keys():
		var seat: int = int(seat_any)
		snapshot[seat] = (bot_profiles.get(seat, {}) as Dictionary).duplicate(true)
	return snapshot

func _is_cpu_seat(seat: int) -> bool:
	if seat < 1 or seat > 4:
		return false
	for entry_any in match_roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("seat", 0)) == seat:
			return bool(entry.get("is_cpu", false))
	return false

func get_team_for_seat(seat: int) -> int:
	var seat_id: int = int(seat)
	if seat_id < 1 or seat_id > 4:
		return 0
	for entry_any in match_roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if int(entry.get("seat", 0)) != seat_id:
			continue
		var team_id: int = int(entry.get("team_id", seat_id))
		if team_id > 0:
			return team_id
		return seat_id
	return seat_id

func set_victory_mode(mode: String, rules: Dictionary = {}) -> void:
	var clean_mode: String = mode.strip_edges().to_lower()
	if clean_mode.is_empty():
		clean_mode = VICTORY_MODE_CONQUEST
	victory_mode = clean_mode
	victory_rules = rules.duplicate(true)
	if victory_mode != VICTORY_MODE_CAPTURE_FLAG:
		capture_flag_state = {}

func get_victory_mode() -> String:
	var clean_mode: String = victory_mode.strip_edges().to_lower()
	if clean_mode.is_empty():
		return VICTORY_MODE_CONQUEST
	return clean_mode

func get_victory_rules() -> Dictionary:
	return victory_rules.duplicate(true)

func is_capture_flag_mode() -> bool:
	return get_victory_mode() == VICTORY_MODE_CAPTURE_FLAG

func configure_capture_flag_mode(options: Dictionary = {}) -> Dictionary:
	var hidden_flag: bool = bool(options.get("hidden_flag", false))
	if int(options.get("flag_selection_seed", 0)) != 0:
		_capture_flag_rng.seed = int(options.get("flag_selection_seed", 0))
	else:
		_capture_flag_rng.randomize()
	var default_selection_mode: String = "player_select" if hidden_flag else "auto_random"
	var selection_mode: String = str(options.get("flag_selection_mode", default_selection_mode)).strip_edges().to_lower()
	var player_select_pct: int = clampi(int(options.get("flag_selection_player_select_pct", 100 if hidden_flag else 0)), 0, 100)
	if hidden_flag:
		selection_mode = "player_select"
		player_select_pct = 100
	if selection_mode == "weighted" or selection_mode == "percent":
		if player_select_pct >= 100:
			selection_mode = "player_select"
		elif player_select_pct <= 0:
			selection_mode = "auto_random"
		else:
			var roll: int = _capture_flag_rng.randi_range(1, 100)
			selection_mode = "player_select" if roll <= player_select_pct else "auto_random"
			options["flag_selection_roll"] = roll
	var rules: Dictionary = {
		"hidden_flag": hidden_flag,
		"fog_of_war_enabled": bool(options.get("fog_of_war_enabled", false)),
		"flag_move_count_max": maxi(0, int(options.get("flag_move_count_max", 0))),
		"flag_move_reveals": bool(options.get("flag_move_reveals", true)),
		"flag_move_production_lock_sec": maxf(0.0, float(options.get("flag_move_production_lock_sec", 0.0))),
		"flag_selection_mode": selection_mode,
		"flag_selection_player_select_pct": player_select_pct,
		"flag_selection_random_mirrored": bool(options.get("flag_selection_random_mirrored", true)),
		"flag_selection_owner_id": clampi(int(options.get("flag_selection_owner_id", 1)), 1, 4),
		"flag_selection_pending": false,
		"flag_selection_roll": int(options.get("flag_selection_roll", 0)),
		"flag_selection_seed": int(options.get("flag_selection_seed", 0))
	}
	set_victory_mode(VICTORY_MODE_CAPTURE_FLAG, rules)
	if state != null:
		auto_assign_capture_flags(options.get("flag_hives", {}), options.get("map_data", {}))
	return get_capture_flag_state()

func get_capture_flag_state() -> Dictionary:
	return {
		"victory_mode": get_victory_mode(),
		"rules": victory_rules.duplicate(true),
		"flags_by_owner": capture_flag_state.duplicate(true)
	}

func get_capture_flag_for_owner(owner_id: int) -> Dictionary:
	if not is_capture_flag_mode():
		return {}
	return (capture_flag_state.get(owner_id, {}) as Dictionary).duplicate(true)

func get_capture_flag_hive_id(owner_id: int) -> int:
	var flag_state: Dictionary = get_capture_flag_for_owner(owner_id)
	return int(flag_state.get("hive_id", 0))

func is_capture_flag_selection_pending(owner_id: int = 0) -> bool:
	if not is_capture_flag_mode():
		return false
	if not bool(victory_rules.get("flag_selection_pending", false)):
		return false
	if owner_id <= 0:
		return true
	return int(victory_rules.get("flag_selection_owner_id", 0)) == int(owner_id)

func auto_complete_capture_flag_selection(owner_id: int = 0) -> Dictionary:
	if not is_capture_flag_mode():
		return {"ok": false, "reason": "victory_mode_not_capture_flag"}
	if not is_capture_flag_selection_pending():
		return {"ok": false, "reason": "selection_not_pending"}
	var selection_owner_id: int = int(victory_rules.get("flag_selection_owner_id", 0))
	if owner_id > 0:
		selection_owner_id = owner_id
	if selection_owner_id <= 0:
		selection_owner_id = 1
	var owners: Array[int] = _active_human_owners_from_state()
	var assigned: Dictionary = {}
	if owners.size() == 2:
		var fallback_pair: Dictionary = {}
		if bool(victory_rules.get("hidden_flag", false)):
			fallback_pair = _auto_capture_flag_hidden_pair_for_owners(owners)
		else:
			fallback_pair = _auto_capture_flag_pair_for_owners(
				owners,
				bool(victory_rules.get("flag_selection_random_mirrored", true))
			)
		for owner_any in fallback_pair.keys():
			var resolved_owner_id: int = int(owner_any)
			var hive_id: int = int(fallback_pair.get(owner_any, 0))
			if hive_id <= 0:
				continue
			var result: Dictionary = set_capture_flag_hive(resolved_owner_id, hive_id, {
				"auto_assigned": true,
				"timeout_auto_selected": true,
				"mirrored_pair": not bool(victory_rules.get("hidden_flag", false)),
				"balanced_pair": bool(victory_rules.get("hidden_flag", false)),
				"selection_timeout_owner_id": selection_owner_id
			})
			if bool(result.get("ok", false)):
				assigned[resolved_owner_id] = int(result.get("hive_id", 0))
	else:
		var hive_id_single: int = _auto_capture_flag_hive_for_owner(selection_owner_id)
		if hive_id_single > 0:
			var single_result: Dictionary = set_capture_flag_hive(selection_owner_id, hive_id_single, {
				"auto_assigned": true,
				"timeout_auto_selected": true,
				"selection_timeout_owner_id": selection_owner_id
			})
			if bool(single_result.get("ok", false)):
				assigned[selection_owner_id] = int(single_result.get("hive_id", 0))
	if assigned.is_empty():
		return {"ok": false, "reason": "selection_timeout_unresolved", "owner_id": selection_owner_id}
	victory_rules["flag_selection_pending"] = false
	SFLog.info("CAPTURE_FLAG_SELECTION_TIMEOUT", {
		"owner_id": selection_owner_id,
		"assigned": assigned
	})
	return {"ok": true, "assigned": assigned.duplicate(true), "owner_id": selection_owner_id}

func request_capture_flag_selection(owner_id: int, hive_id: int) -> Dictionary:
	if not is_capture_flag_mode():
		return {"ok": false, "reason": "victory_mode_not_capture_flag"}
	var selection_owner_id: int = int(victory_rules.get("flag_selection_owner_id", 0))
	if selection_owner_id > 0 and owner_id != selection_owner_id:
		return {"ok": false, "reason": "selection_owner_mismatch", "owner_id": owner_id, "selection_owner_id": selection_owner_id}
	if not is_capture_flag_selection_pending(owner_id):
		return {"ok": false, "reason": "selection_not_pending", "owner_id": owner_id}
	var owners: Array[int] = _active_human_owners_from_state()
	var assigned: Dictionary = {}
	if owners.size() == 2:
		var other_owner_id: int = int(owners[0]) if int(owners[1]) == owner_id else int(owners[1])
		var other_hive_id: int = 0
		if bool(victory_rules.get("hidden_flag", false)):
			other_hive_id = _balanced_hidden_capture_flag_partner_for_hive(owner_id, hive_id, other_owner_id)
			if other_hive_id <= 0:
				return {"ok": false, "reason": "balanced_hive_not_found", "owner_id": owner_id, "hive_id": hive_id}
		else:
			other_hive_id = _mirrored_capture_flag_partner_for_hive(owner_id, hive_id, other_owner_id)
			if other_hive_id <= 0:
				return {"ok": false, "reason": "mirrored_hive_not_found", "owner_id": owner_id, "hive_id": hive_id}
		var primary_result: Dictionary = set_capture_flag_hive(owner_id, hive_id, {
			"auto_assigned": false,
			"player_selected": true,
			"mirrored_pair": not bool(victory_rules.get("hidden_flag", false)),
			"balanced_pair": bool(victory_rules.get("hidden_flag", false))
		})
		if not bool(primary_result.get("ok", false)):
			return primary_result
		var mirror_result: Dictionary = set_capture_flag_hive(other_owner_id, other_hive_id, {
			"auto_assigned": false,
			"player_selected": false,
			"mirrored_pair": not bool(victory_rules.get("hidden_flag", false)),
			"balanced_pair": bool(victory_rules.get("hidden_flag", false)),
			"mirrored_from_owner_id": owner_id,
			"mirrored_from_hive_id": int(hive_id)
		})
		if not bool(mirror_result.get("ok", false)):
			return mirror_result
		assigned[owner_id] = int(primary_result.get("hive_id", 0))
		assigned[other_owner_id] = int(mirror_result.get("hive_id", 0))
	else:
		var single_result: Dictionary = set_capture_flag_hive(owner_id, hive_id, {
			"auto_assigned": false,
			"player_selected": true
		})
		if not bool(single_result.get("ok", false)):
			return single_result
		assigned[owner_id] = int(single_result.get("hive_id", 0))
	victory_rules["flag_selection_pending"] = false
	return {"ok": true, "assigned": assigned.duplicate(true)}

func request_capture_flag_move(owner_id: int, hive_id: int) -> Dictionary:
	if not is_capture_flag_mode():
		return {"ok": false, "reason": "victory_mode_not_capture_flag"}
	if not bool(victory_rules.get("hidden_flag", false)):
		return {"ok": false, "reason": "flag_move_disabled_for_standard_ctf"}
	if match_phase != MatchPhase.RUNNING:
		return {"ok": false, "reason": "match_not_running"}
	var owner_flag: Dictionary = capture_flag_state.get(owner_id, {}) as Dictionary
	if owner_flag.is_empty():
		return {"ok": false, "reason": "flag_not_assigned", "owner_id": owner_id}
	var current_hive_id: int = int(owner_flag.get("hive_id", 0))
	if hive_id == current_hive_id:
		return {"ok": false, "reason": "flag_already_on_hive", "hive_id": hive_id}
	var moves_remaining: int = int(owner_flag.get("moves_remaining", int(victory_rules.get("flag_move_count_max", 0))))
	if moves_remaining <= 0:
		return {"ok": false, "reason": "no_moves_remaining", "owner_id": owner_id}
	var set_result: Dictionary = set_capture_flag_hive(owner_id, hive_id, {
		"auto_assigned": false,
		"player_selected": false,
		"revealed_to_all": bool(victory_rules.get("flag_move_reveals", true)),
		"moved": true,
		"moved_from_hive_id": current_hive_id,
		"moved_at_unix": int(Time.get_unix_time_from_system()),
		"moves_used": int(owner_flag.get("moves_used", 0)) + 1,
		"moves_remaining": moves_remaining - 1,
		"production_lock_until_unix": int(Time.get_unix_time_from_system() + int(ceil(float(victory_rules.get("flag_move_production_lock_sec", 0.0)))))
	})
	if not bool(set_result.get("ok", false)):
		return set_result
	SFLog.info("CAPTURE_FLAG_MOVED", {
		"owner_id": owner_id,
		"from_hive_id": current_hive_id,
		"to_hive_id": hive_id,
		"moves_remaining": moves_remaining - 1,
		"revealed_to_all": bool(victory_rules.get("flag_move_reveals", true))
	})
	return set_result

func set_capture_flag_hive(owner_id: int, hive_id: int, metadata: Dictionary = {}) -> Dictionary:
	if not is_capture_flag_mode():
		return {"ok": false, "reason": "victory_mode_not_capture_flag"}
	var seat_id: int = int(owner_id)
	if seat_id < 1 or seat_id > 4:
		return {"ok": false, "reason": "owner_invalid", "owner_id": owner_id}
	var hive: HiveData = require_state().find_hive_by_id(int(hive_id))
	if hive == null:
		return {"ok": false, "reason": "hive_not_found", "hive_id": hive_id}
	if int(hive.owner_id) != seat_id:
		return {
			"ok": false,
			"reason": "hive_not_owned_by_owner",
			"hive_id": hive_id,
			"owner_id": seat_id,
			"actual_owner_id": int(hive.owner_id)
		}
	var existing_flag: Dictionary = capture_flag_state.get(seat_id, {}) as Dictionary
	var flag_entry: Dictionary = {
		"owner_id": seat_id,
		"hive_id": int(hive_id),
		"hidden": bool(victory_rules.get("hidden_flag", false)),
		"revealed_to_all": bool(metadata.get("revealed_to_all", false)),
		"moves_remaining": int(metadata.get("moves_remaining", existing_flag.get("moves_remaining", maxi(0, int(victory_rules.get("flag_move_count_max", 0)))))),
		"assigned_at_unix": int(Time.get_unix_time_from_system())
	}
	if not existing_flag.is_empty():
		flag_entry["assigned_at_unix"] = int(existing_flag.get("assigned_at_unix", flag_entry.get("assigned_at_unix", 0)))
	for key_any in metadata.keys():
		flag_entry[str(key_any)] = metadata.get(key_any)
	capture_flag_state[seat_id] = flag_entry
	SFLog.info("CAPTURE_FLAG_ASSIGNED", {
		"owner_id": seat_id,
		"hive_id": int(hive_id),
		"hidden": bool(flag_entry.get("hidden", false))
	})
	return {"ok": true, "owner_id": seat_id, "hive_id": int(hive_id), "flag": flag_entry.duplicate(true)}

func auto_assign_capture_flags(flag_hives_any: Variant = {}, map_data_any: Variant = {}) -> Dictionary:
	if not is_capture_flag_mode():
		return {"ok": false, "reason": "victory_mode_not_capture_flag"}
	var explicit: Dictionary = _normalize_capture_flag_assignments(flag_hives_any)
	if explicit.is_empty() and typeof(map_data_any) == TYPE_DICTIONARY:
		explicit = _normalize_capture_flag_assignments((map_data_any as Dictionary).get("ctf_flag_hives", {}))
	if bool(victory_rules.get("hidden_flag", false)) and str(victory_rules.get("flag_selection_mode", "")).strip_edges().to_lower() == "player_select":
		explicit.clear()
	capture_flag_state.clear()
	var assigned: Dictionary = {}
	var owners: Array[int] = _active_human_owners_from_state()
	if explicit.is_empty() and str(victory_rules.get("flag_selection_mode", "auto_random")) == "player_select":
		victory_rules["flag_selection_pending"] = true
		return {
			"ok": true,
			"assigned": {},
			"pending_selection": true,
			"owner_id": int(victory_rules.get("flag_selection_owner_id", 0))
		}
	victory_rules["flag_selection_pending"] = false
	if explicit.is_empty() and owners.size() == 2:
		var mirrored_assignments: Dictionary = {}
		if bool(victory_rules.get("hidden_flag", false)):
			mirrored_assignments = _auto_capture_flag_hidden_pair_for_owners(owners)
		else:
			mirrored_assignments = _auto_capture_flag_pair_for_owners(
				owners,
				bool(victory_rules.get("flag_selection_random_mirrored", true))
			)
		for owner_any in mirrored_assignments.keys():
			var owner_id: int = int(owner_any)
			var hive_id: int = int(mirrored_assignments.get(owner_any, 0))
			if hive_id <= 0:
				continue
			var set_pair_result: Dictionary = set_capture_flag_hive(owner_id, hive_id, {
				"auto_assigned": true,
				"mirrored_pair": not bool(victory_rules.get("hidden_flag", false)),
				"balanced_pair": bool(victory_rules.get("hidden_flag", false))
			})
			if bool(set_pair_result.get("ok", false)):
				assigned[owner_id] = int(set_pair_result.get("hive_id", 0))
		if assigned.size() == owners.size():
			return {"ok": true, "assigned": assigned.duplicate(true)}
	for owner_id in owners:
		var hive_id: int = int(explicit.get(owner_id, 0))
		if hive_id <= 0:
			hive_id = _auto_capture_flag_hive_for_owner(owner_id)
		if hive_id <= 0:
			continue
		var set_result: Dictionary = set_capture_flag_hive(owner_id, hive_id, {"auto_assigned": true})
		if bool(set_result.get("ok", false)):
			assigned[owner_id] = int(set_result.get("hive_id", 0))
	return {"ok": not assigned.is_empty(), "assigned": assigned.duplicate(true)}

func build_capture_flag_view(viewer_owner_id: int = 0) -> Dictionary:
	if not is_capture_flag_mode():
		return {"enabled": false}
	var flags: Array[Dictionary] = []
	var owners: Array = capture_flag_state.keys()
	owners.sort()
	for owner_any in owners:
		var owner_id: int = int(owner_any)
		var entry: Dictionary = (capture_flag_state.get(owner_any, {}) as Dictionary).duplicate(true)
		var hidden: bool = bool(entry.get("hidden", false))
		var revealed_to_all: bool = bool(entry.get("revealed_to_all", false))
		entry["visible_to_viewer"] = not hidden or revealed_to_all or owner_id == viewer_owner_id
		entry["viewer_owner_id"] = viewer_owner_id
		flags.append(entry)
	return {
		"enabled": true,
		"victory_mode": VICTORY_MODE_CAPTURE_FLAG,
		"rules": victory_rules.duplicate(true),
		"flags": flags
	}

func _active_human_owners_from_state() -> Array[int]:
	var owners: Array[int] = []
	if state == null:
		return owners
	var seen: Dictionary = {}
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		var owner_id: int = int(hive.owner_id)
		if owner_id < 1 or owner_id > 4 or seen.has(owner_id):
			continue
		seen[owner_id] = true
		owners.append(owner_id)
	owners.sort()
	return owners

func _normalize_capture_flag_assignments(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		for key_any in (raw as Dictionary).keys():
			var owner_id: int = int(str(key_any))
			var hive_id: int = int((raw as Dictionary).get(key_any, 0))
			if owner_id < 1 or owner_id > 4 or hive_id <= 0:
				continue
			out[owner_id] = hive_id
	elif typeof(raw) == TYPE_ARRAY:
		for entry_any in raw as Array:
			if typeof(entry_any) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = entry_any as Dictionary
			var owner_id: int = int(entry.get("owner_id", 0))
			var hive_id: int = int(entry.get("hive_id", 0))
			if owner_id < 1 or owner_id > 4 or hive_id <= 0:
				continue
			out[owner_id] = hive_id
	return out

func _auto_capture_flag_hive_for_owner(owner_id: int) -> int:
	if state == null:
		return 0
	var center: Vector2 = _capture_flag_map_center()
	var best_hive_id: int = 0
	var best_score: float = -INF
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null or int(hive.owner_id) != int(owner_id):
			continue
		var gp: Vector2 = Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
		var score: float = gp.distance_squared_to(center)
		if score > best_score:
			best_score = score
			best_hive_id = int(hive.id)
	return best_hive_id

func _auto_capture_flag_pair_for_owners(owners: Array[int], randomize: bool = false) -> Dictionary:
	var out: Dictionary = {}
	if owners.size() != 2:
		return out
	var candidates: Array[Dictionary] = _capture_flag_pair_candidates(int(owners[0]), int(owners[1]))
	if candidates.is_empty():
		return out
	var chosen_pair: Dictionary = {}
	if randomize:
		var pool: Array[Dictionary] = []
		for candidate in candidates:
			var symmetry_error: float = float(candidate.get("symmetry_error", INF))
			var radial_error: float = float(candidate.get("radial_error", INF))
			if symmetry_error <= 0.001 and radial_error <= 0.001:
				pool.append(candidate)
		if pool.is_empty():
			for i in range(mini(candidates.size(), 4)):
				pool.append(candidates[i])
		var pick_index: int = _capture_flag_rng.randi_range(0, maxi(pool.size() - 1, 0))
		chosen_pair = (pool[pick_index].get("pair", {}) as Dictionary).duplicate(true)
	else:
		chosen_pair = (candidates[0].get("pair", {}) as Dictionary).duplicate(true)
	return chosen_pair

func _auto_capture_flag_hidden_pair_for_owners(owners: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	if owners.size() != 2:
		return out
	var owner_a: int = int(owners[0])
	var owner_b: int = int(owners[1])
	var candidates: Array[Dictionary] = _balanced_hidden_capture_flag_pair_candidates(owner_a, owner_b)
	if candidates.is_empty():
		return _auto_capture_flag_pair_for_owners(owners, true)
	var chosen: Dictionary = _pick_balanced_hidden_capture_flag_pair(candidates)
	if chosen.is_empty():
		return out
	return (chosen.get("pair", {}) as Dictionary).duplicate(true)

func _mirrored_capture_flag_partner_for_hive(source_owner_id: int, source_hive_id: int, target_owner_id: int) -> int:
	var candidates: Array[Dictionary] = _capture_flag_pair_candidates(source_owner_id, target_owner_id, source_hive_id)
	if candidates.is_empty():
		return 0
	var pair: Dictionary = candidates[0].get("pair", {}) as Dictionary
	return int(pair.get(target_owner_id, 0))

func _balanced_hidden_capture_flag_partner_for_hive(source_owner_id: int, source_hive_id: int, target_owner_id: int) -> int:
	var candidates: Array[Dictionary] = _balanced_hidden_capture_flag_pair_candidates(source_owner_id, target_owner_id, source_hive_id)
	if candidates.is_empty():
		return _mirrored_capture_flag_partner_for_hive(source_owner_id, source_hive_id, target_owner_id)
	var pair: Dictionary = _pick_balanced_hidden_capture_flag_pair(candidates).get("pair", {}) as Dictionary
	return int(pair.get(target_owner_id, 0))

func _balanced_hidden_capture_flag_pair_candidates(owner_a: int, owner_b: int, preferred_owner_a_hive_id: int = 0) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = _capture_flag_pair_candidates(owner_a, owner_b, preferred_owner_a_hive_id)
	if candidates.is_empty():
		return candidates
	var filtered: Array[Dictionary] = []
	for candidate in candidates:
		if float(candidate.get("symmetry_error", 0.0)) > 0.001:
			filtered.append(candidate)
	if filtered.is_empty():
		filtered = candidates.duplicate(true)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_radial: float = float(a.get("radial_error", INF))
		var b_radial: float = float(b.get("radial_error", INF))
		if not is_equal_approx(a_radial, b_radial):
			return a_radial < b_radial
		var a_outward: float = float(a.get("outward", 0.0))
		var b_outward: float = float(b.get("outward", 0.0))
		if not is_equal_approx(a_outward, b_outward):
			return a_outward > b_outward
		return float(a.get("symmetry_error", 0.0)) > float(b.get("symmetry_error", 0.0))
	)
	return filtered

func _pick_balanced_hidden_capture_flag_pair(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var pool: Array[Dictionary] = []
	var best_radial: float = float(candidates[0].get("radial_error", INF))
	for candidate in candidates:
		if float(candidate.get("radial_error", INF)) <= best_radial + 0.001:
			pool.append(candidate)
	if pool.is_empty():
		for i in range(mini(candidates.size(), 4)):
			pool.append(candidates[i])
	var pick_index: int = _capture_flag_rng.randi_range(0, maxi(pool.size() - 1, 0))
	return (pool[pick_index] as Dictionary).duplicate(true)

func _capture_flag_pair_candidates(owner_a: int, owner_b: int, preferred_owner_a_hive_id: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null:
		return out
	var owner_a_id: int = int(owner_a)
	var owner_b_id: int = int(owner_b)
	var hives_a: Array[HiveData] = []
	var hives_b: Array[HiveData] = []
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		var owner_id: int = int(hive.owner_id)
		if owner_id == owner_a_id:
			hives_a.append(hive)
		elif owner_id == owner_b_id:
			hives_b.append(hive)
	if hives_a.is_empty() or hives_b.is_empty():
		return out
	var center: Vector2 = _capture_flag_map_center()
	for hive_a in hives_a:
		if preferred_owner_a_hive_id > 0 and int(hive_a.id) != preferred_owner_a_hive_id:
			continue
		var pos_a: Vector2 = Vector2(float(hive_a.grid_pos.x), float(hive_a.grid_pos.y))
		var mirror_a: Vector2 = (center * 2.0) - pos_a
		var dist_a: float = pos_a.distance_squared_to(center)
		for hive_b in hives_b:
			var pos_b: Vector2 = Vector2(float(hive_b.grid_pos.x), float(hive_b.grid_pos.y))
			var dist_b: float = pos_b.distance_squared_to(center)
			var symmetry_error: float = mirror_a.distance_squared_to(pos_b)
			var radial_error: float = absf(dist_a - dist_b)
			var score: float = symmetry_error + (radial_error * 0.10)
			var outward: float = minf(dist_a, dist_b)
			out.append({
				"pair": {
					owner_a_id: int(hive_a.id),
					owner_b_id: int(hive_b.id)
				},
				"score": score,
				"symmetry_error": symmetry_error,
				"radial_error": radial_error,
				"outward": outward
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: float = float(a.get("score", INF))
		var b_score: float = float(b.get("score", INF))
		if not is_equal_approx(a_score, b_score):
			return a_score < b_score
		return float(a.get("outward", 0.0)) > float(b.get("outward", 0.0))
	)
	return out

func _capture_flag_map_center() -> Vector2:
	if state == null or state.hives.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for hive_any in state.hives:
		var hive: HiveData = hive_any as HiveData
		if hive == null:
			continue
		sum += Vector2(float(hive.grid_pos.x), float(hive.grid_pos.y))
		count += 1
	if count <= 0:
		return Vector2.ZERO
	return sum / float(count)

func are_allies(seat_a: int, seat_b: int) -> bool:
	var a_id: int = int(seat_a)
	var b_id: int = int(seat_b)
	if a_id <= 0 or b_id <= 0:
		return false
	return get_team_for_seat(a_id) == get_team_for_seat(b_id)

func get_team_by_seat_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for seat in [1, 2, 3, 4]:
		out[seat] = get_team_for_seat(seat)
	return out

func _record_intent_telemetry(
	src_hive_id: int,
	dst_hive_id: int,
	intent: String,
	ok: bool,
	reason: String,
	lane_id: int = -1,
	src_owner_id: int = 0,
	dst_owner_id: int = 0,
	source_exec_override: Dictionary = {}
) -> void:
	_record_pvp_debug_intent_event(src_hive_id, dst_hive_id, intent, ok, reason, lane_id)
	if _bot_telemetry_store == null:
		return
	if not _bot_telemetry_store.has_method("record_intent"):
		return
	var st: GameState = state
	var ctx: Dictionary = _intent_telemetry_context(src_owner_id, dst_owner_id)
	var source_exec: Dictionary = source_exec_override.duplicate(true) if source_exec_override != null else {}
	if source_exec.is_empty() and st != null and st.has_method("get_execution_metrics_for_hive"):
		source_exec = st.call("get_execution_metrics_for_hive", src_hive_id)
	var event: Dictionary = {
		"match_id": str(ctx.get("match_id", "")),
		"map_id": str(ctx.get("map_id", "")),
		"match_type": str(ctx.get("match_type", "")),
		"match_time_ms": int(ctx.get("match_time_ms", 0)),
		"source_mode": str(ctx.get("source_mode", "")),
		"contest_id": str(ctx.get("contest_id", "")),
		"actor_label": str(ctx.get("actor_label", "")),
		"actor_style": str(ctx.get("actor_style", "")),
		"actor_tier": str(ctx.get("actor_tier", "")),
		"target_label": str(ctx.get("target_label", "")),
		"target_style": str(ctx.get("target_style", "")),
		"target_tier": str(ctx.get("target_tier", "")),
		"iid": int(st.get_instance_id()) if st != null else 0,
		"phase": int(match_phase),
		"tick": int(st.tick) if st != null else -1,
		"src": src_hive_id,
		"dst": dst_hive_id,
		"intent": intent,
		"ok": ok,
		"reason": reason,
		"lane_id": lane_id,
		"actor_id": src_owner_id,
		"src_owner_id": src_owner_id,
		"dst_owner_id": dst_owner_id,
		"is_cpu_actor": _is_cpu_seat(src_owner_id),
		"src_power": int(source_exec.get("power", 0)),
		"src_budget": int(source_exec.get("budget", 0)),
		"src_active_outgoing": int(source_exec.get("active_outgoing", 0)),
		"src_open_slots": int(source_exec.get("open_slots", 0)),
		"src_available_targets": int(source_exec.get("available_targets", 0)),
		"src_available_lane_unattended_ms": int(source_exec.get("available_lane_unattended_ms", 0)),
		"src_max_available_lane_unattended_ms": int(source_exec.get("max_available_lane_unattended_ms", 0)),
		"src_high_power_idle_ms": int(source_exec.get("high_power_idle_ms", 0)),
		"src_max_high_power_idle_ms": int(source_exec.get("max_high_power_idle_ms", 0))
	}
	_bot_telemetry_store.call("record_intent", event)
	_record_match_intent_event(
		src_owner_id,
		src_hive_id,
		dst_hive_id,
		intent,
		ok,
		reason,
		lane_id,
		{
			"src_owner": src_owner_id,
			"dst_owner": dst_owner_id,
			"phase": int(match_phase),
			"tick": int(st.tick) if st != null else -1,
			"source_mode": str(ctx.get("source_mode", "")),
			"match_type": str(ctx.get("match_type", "")),
			"is_cpu_actor": _is_cpu_seat(src_owner_id),
			"src_power": int(source_exec.get("power", 0)),
			"src_budget": int(source_exec.get("budget", 0)),
			"src_active_outgoing": int(source_exec.get("active_outgoing", 0)),
			"src_open_slots": int(source_exec.get("open_slots", 0)),
			"src_available_targets": int(source_exec.get("available_targets", 0)),
			"src_available_lane_unattended_ms": int(source_exec.get("available_lane_unattended_ms", 0)),
			"src_high_power_idle_ms": int(source_exec.get("high_power_idle_ms", 0))
		}
	)

func _record_pvp_debug_intent_event(src_hive_id: int, dst_hive_id: int, intent: String, ok: bool, reason: String, lane_id: int = -1) -> void:
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null:
		return
	if not ok and not str(reason).strip_edges().is_empty() and runtime.has_method("record_debug_input_rejected"):
		runtime.call("record_debug_input_rejected", src_hive_id, dst_hive_id, intent, reason, lane_id)
		return
	if ok and _remote_replication_apply_depth > 0 and runtime.has_method("record_debug_intent_applied"):
		runtime.call("record_debug_intent_applied", src_hive_id, dst_hive_id, intent, lane_id)

func _intent_telemetry_context(src_owner_id: int, dst_owner_id: int) -> Dictionary:
	var tree: SceneTree = _intent_telemetry_tree()
	var source_mode: String = ""
	var contest_id: String = ""
	var free_roll: bool = false
	var sync_start: bool = false
	var remote_is_cpu: bool = false
	if tree != null:
		source_mode = str(tree.get_meta("vs_mode", "")).strip_edges().to_upper()
		contest_id = str(tree.get_meta("contest_id", "")).strip_edges()
		free_roll = bool(tree.get_meta("vs_free_roll", false))
		sync_start = bool(tree.get_meta("vs_sync_start", false))
		var remote_profile_any: Variant = tree.get_meta("vs_remote_profile", {})
		if typeof(remote_profile_any) == TYPE_DICTIONARY:
			remote_is_cpu = bool((remote_profile_any as Dictionary).get("is_cpu", false))
	var match_type: String = "LOCAL"
	if remote_is_cpu:
		match_type = "BOT"
	elif sync_start:
		match_type = "VS"
	elif not source_mode.is_empty():
		match_type = "ASYNC"
	var map_id: String = _resolve_intent_telemetry_map_id(tree)
	var src_identity: Dictionary = _intent_telemetry_actor_identity(src_owner_id, tree)
	var dst_identity: Dictionary = _intent_telemetry_actor_identity(dst_owner_id, tree)
	return {
		"match_id": _ensure_intent_log_match_id(match_type, map_id),
		"map_id": map_id,
		"match_type": match_type,
		"match_time_ms": maxi(0, int(match_elapsed_ms)),
		"source_mode": source_mode,
		"contest_id": contest_id,
		"free_roll": free_roll,
		"actor_label": str(src_identity.get("label", "")),
		"actor_style": str(src_identity.get("style", "")),
		"actor_tier": str(src_identity.get("tier", "")),
		"target_label": str(dst_identity.get("label", "")),
		"target_style": str(dst_identity.get("style", "")),
		"target_tier": str(dst_identity.get("tier", ""))
	}

func _intent_telemetry_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	return main_loop as SceneTree

func _resolve_intent_telemetry_map_id(tree: SceneTree) -> String:
	if not current_map_id.is_empty():
		return current_map_id
	if tree != null:
		var jukebox_map_id: String = str(tree.get_meta("jukebox_map_id", "")).strip_edges()
		if not jukebox_map_id.is_empty():
			return jukebox_map_id
		var stage_maps_any: Variant = tree.get_meta("vs_stage_map_paths", [])
		if typeof(stage_maps_any) == TYPE_ARRAY:
			var stage_maps: Array = stage_maps_any as Array
			var stage_index: int = clampi(int(tree.get_meta("vs_stage_current_index", 0)), 0, maxi(stage_maps.size() - 1, 0))
			if stage_index >= 0 and stage_index < stage_maps.size():
				var path: String = str(stage_maps[stage_index]).strip_edges()
				if not path.is_empty():
					return path.get_file().get_basename().strip_edges()
		var next_map_id: String = str(tree.get_meta("jukebox_map_path", "")).strip_edges()
		if not next_map_id.is_empty():
			return next_map_id.get_file().get_basename().strip_edges()
	return "unknown_map"

func _intent_telemetry_actor_identity(owner_id: int, tree: SceneTree) -> Dictionary:
	var seat: int = int(owner_id)
	if seat <= 0:
		return {"label": "", "style": "", "tier": ""}
	var profile: Dictionary = bot_profiles.get(seat, {}) as Dictionary
	var label: String = "seat_%d" % seat
	var style: String = str(profile.get("style", profile.get("persona", ""))).strip_edges()
	var tier: String = str(profile.get("tier", "")).strip_edges()
	var is_cpu: bool = _is_cpu_seat(seat)
	if is_cpu:
		if style.is_empty():
			style = _default_bot_style_for_seat(seat)
		if tier.is_empty():
			tier = BOT_TIER_MEDIUM
		label = "cpu_%s_%s_s%d" % [style, tier, seat]
	else:
		var local_name: String = ""
		var remote_name: String = ""
		if tree != null:
			var local_profile_any: Variant = tree.get_meta("vs_local_profile", {})
			if typeof(local_profile_any) == TYPE_DICTIONARY:
				local_name = str((local_profile_any as Dictionary).get("name", (local_profile_any as Dictionary).get("handle", ""))).strip_edges()
			var remote_profile_any: Variant = tree.get_meta("vs_remote_profile", {})
			if typeof(remote_profile_any) == TYPE_DICTIONARY:
				remote_name = str((remote_profile_any as Dictionary).get("name", (remote_profile_any as Dictionary).get("handle", ""))).strip_edges()
		if seat == 1 and not local_name.is_empty():
			label = local_name
		elif seat != 1 and not remote_name.is_empty():
			label = remote_name
		else:
			label = "human_s%d" % seat
	return {
		"label": label,
		"style": style,
		"tier": tier
	}

func _ensure_intent_log_match_id(match_type: String, map_id: String) -> String:
	if not _intent_log_match_id.is_empty():
		return _intent_log_match_id
	var utc_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var clean_map: String = map_id.strip_edges()
	if clean_map.is_empty():
		clean_map = "unknown_map"
	_intent_log_match_id = "intent_%d_%s_%s_i%d" % [utc_ms, clean_map, match_type.to_lower(), get_state_iid()]
	return _intent_log_match_id

func _vs_pvp_runtime() -> Node:
	return get_node_or_null("/root/VsPvpRuntime")

func _maybe_replicate_lane_intent(src_hive_id: int, dst_hive_id: int, intent: String, src_owner_id: int, dst_owner_id: int) -> bool:
	if _remote_replication_apply_depth > 0:
		return true
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_lane_intent"):
		return true
	var result: Variant = runtime.call("record_local_lane_intent", src_hive_id, dst_hive_id, intent, src_owner_id, dst_owner_id)
	return bool(result) if typeof(result) == TYPE_BOOL else true

func _maybe_replicate_lane_retract(from_id: int, to_id: int, owner_id: int) -> bool:
	if _remote_replication_apply_depth > 0:
		return true
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_lane_retract"):
		return true
	var result: Variant = runtime.call("record_local_lane_retract", from_id, to_id, owner_id)
	return bool(result) if typeof(result) == TYPE_BOOL else true

func _maybe_replicate_barracks_route(barracks_id: int, route_hive_ids: Array, owner_id: int) -> bool:
	if _remote_replication_apply_depth > 0:
		return true
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_barracks_route"):
		return true
	var result: Variant = runtime.call("record_local_barracks_route", barracks_id, route_hive_ids, owner_id)
	return bool(result) if typeof(result) == TYPE_BOOL else true

func _vs_runtime_is_active_for_local_owner(owner_id: int) -> bool:
	if owner_id <= 0 or _remote_replication_apply_depth > 0:
		return false
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("is_active") or not runtime.has_method("get_local_seat"):
		return false
	if not bool(runtime.call("is_active")):
		return false
	return owner_id == int(runtime.call("get_local_seat"))

func _schedule_vs_lane_intent_if_needed(st: GameState, src_hive_id: int, dst_hive_id: int, intent: String) -> Dictionary:
	if st == null:
		return {}
	var src_hive: HiveData = st.find_hive_by_id(src_hive_id)
	if src_hive == null:
		return {}
	var src_owner_id: int = int(src_hive.owner_id)
	if not _vs_runtime_is_active_for_local_owner(src_owner_id):
		return {}
	var dst_hive: HiveData = st.find_hive_by_id(dst_hive_id)
	var dst_owner_id: int = int(dst_hive.owner_id) if dst_hive != null else 0
	var replicated: bool = _maybe_replicate_lane_intent(src_hive_id, dst_hive_id, intent, src_owner_id, dst_owner_id)
	return {
		"ok": replicated,
		"reason": "" if replicated else "vs_contract",
		"lane_id": -1,
		"src": src_hive_id,
		"dst": dst_hive_id,
		"intent": intent,
		"scheduled": replicated
	}

func _telemetry_match_ms() -> int:
	if state == null:
		return 0
	return maxi(0, int(round(float(state._sim_time_us) / 1000.0)))

func get_swarm_cooldown_total_ms() -> int:
	return SWARM_COOLDOWN_MS

func get_swarm_cooldown_remaining_ms(src_hive_id: int) -> int:
	if state == null or src_hive_id <= 0:
		return 0
	return _swarm_cooldown_remaining_ms(state, src_hive_id)

func _swarm_cooldown_remaining_ms(st: GameState, src_hive_id: int) -> int:
	if st == null or src_hive_id <= 0:
		return 0
	var until_us: int = int(st.swarm_cooldown_until_us.get(src_hive_id, 0))
	var now_us: int = int(st._sim_time_us)
	if until_us <= now_us:
		return 0
	return int(ceil(float(until_us - now_us) / 1000.0))

func _record_match_action_event(player_id: int, kind: String, payload: Dictionary = {}) -> void:
	if _match_telemetry_collector == null:
		return
	if not _match_telemetry_collector.has_method("record_action_event"):
		return
	var safe_player_id: int = maxi(0, player_id)
	if safe_player_id <= 0:
		return
	_match_telemetry_collector.call(
		"record_action_event",
		_telemetry_match_ms(),
		safe_player_id,
		kind,
		payload
	)

func _record_match_intent_event(
	player_id: int,
	src_hive_id: int,
	dst_hive_id: int,
	intent: String,
	ok: bool,
	reason: String,
	lane_id: int,
	context: Dictionary = {}
) -> void:
	if _match_telemetry_collector == null:
		return
	if not _match_telemetry_collector.has_method("record_intent_event"):
		return
	var safe_player_id: int = maxi(0, player_id)
	if safe_player_id <= 0:
		return
	_match_telemetry_collector.call(
		"record_intent_event",
		_telemetry_match_ms(),
		safe_player_id,
		src_hive_id,
		dst_hive_id,
		intent,
		ok,
		reason,
		lane_id,
		context
	)

func begin_match_end(winner: int, reason: String, linger_ms: int = 1500) -> void:
	if match_phase != MatchPhase.RUNNING:
		return
	match_phase = MatchPhase.ENDING
	winner_id = winner
	if winner_id != 0:
		SFLog.info("MATCH_END_LATCH", {"winner": winner_id})
	end_reason = reason
	var now_ms := Time.get_ticks_msec()
	ending_started_ms = now_ms
	ending_linger_ms = linger_ms
	end_screen_ready_ms = ending_started_ms + ending_linger_ms
	outcome_reason = reason
	match_end_reason = reason
	match_over = true
	input_locked = true
	input_locked_reason = "match_end"
	match_end_ms = now_ms
	SFLog.info("MATCH_END", {
		"winner_id": winner_id,
		"reason": end_reason,
		"match_end_ms": match_end_ms
	})
	match_clock_running = false
	var st := state
	outcome_tick = int(st.tick) if st != null else -1
	if winner == 1:
		outcome = GameState.GameOutcome.WIN_P1
	elif winner == 2:
		outcome = GameState.GameOutcome.WIN_P2
	else:
		outcome = GameState.GameOutcome.DRAW
	SFLog.info("MATCH_ENDING", {
		"winner_id": winner_id,
		"reason": end_reason,
		"linger_ms": ending_linger_ms,
		"iid": int(st.get_instance_id()) if st != null else int(get_instance_id())
	})
	SFLog.info("INPUT_FROZEN", {"phase": int(match_phase), "winner_team": winner_id})
	SFLog.log_once("M1_MATCH_PHASES", "M1_MATCH_PHASES_READY", SFLog.Level.INFO)

func finalize_match_end() -> void:
	if match_phase != MatchPhase.ENDING:
		return
	match_phase = MatchPhase.ENDED
	ended_ms = Time.get_ticks_msec()
	rematch_deadline_ms = ended_ms + rematch_window_ms
	rematch_votes.clear()
	post_end_action = ""
	var st := state
	SFLog.info("MATCH_ENDED", {
		"winner_id": winner_id,
		"reason": end_reason,
		"iid": int(st.get_instance_id()) if st != null else int(get_instance_id())
	})
	SFLog.info("END_SCREEN_SHOWN", {"winner_team": winner_id})
	SFLog.log_once("M3_MATCH_ENDED", "M3_MATCH_ENDED", SFLog.Level.INFO)
	SFLog.log_once("M5_REMATCH_READY", "M5_REMATCH_WINDOW_READY", SFLog.Level.INFO)

func enforce_post_match_authority(context: String = "") -> void:
	if match_phase != MatchPhase.ENDING and match_phase != MatchPhase.ENDED:
		return
	var corrected: bool = false
	if not match_over:
		match_over = true
		corrected = true
	if not input_locked:
		input_locked = true
		corrected = true
	if input_locked_reason == "":
		input_locked_reason = "match_end"
		corrected = true
	if match_clock_running:
		match_clock_running = false
		corrected = true
	if corrected:
		SFLog.warn("POSTMATCH_AUTHORITY_ENFORCED", {
			"context": context,
			"phase": int(match_phase),
			"winner_id": int(winner_id),
			"reason": str(end_reason),
			"input_locked_reason": str(input_locked_reason)
		})

func end_match(winner: int, reason: String) -> void:
	# Back-compat wrapper: ends immediately.
	begin_match_end(winner, reason, 0)
	finalize_match_end()

func _configured_match_duration_ms() -> int:
	return MATCH_DURATION_MS_TEST if SF_TEST_MATCH_TIMER else MATCH_DURATION_MS_DEFAULT

func request_rematch(player_id: int) -> bool:
	if match_phase != MatchPhase.ENDED:
		return false
	if player_id <= 0:
		return false
	var now_ms := Time.get_ticks_msec()
	if rematch_deadline_ms > 0 and now_ms > rematch_deadline_ms:
		return false
	rematch_votes[player_id] = true
	SFLog.info("REMATCH_VOTE", {
		"player_id": player_id,
		"p1": rematch_votes.has(1),
		"p2": rematch_votes.has(2)
	})
	if rematch_votes.has(1) and rematch_votes.has(2):
		post_end_action = "rematch"
		SFLog.info("REMATCH_CONFIRMED", {})
	return true

func expire_rematch_if_needed() -> void:
	if match_phase != MatchPhase.ENDED:
		return
	if post_end_action != "":
		return
	if rematch_deadline_ms <= 0:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms <= rematch_deadline_ms:
		return
	SFLog.warn("REMATCH_TIMEOUT_HOLD", {
		"deadline_ms": rematch_deadline_ms,
		"now_ms": now_ms,
		"note": "timeout reached; awaiting explicit user exit"
	}, "", 5000)

func _ensure_team_stats(team_id: int) -> Dictionary:
	if team_id <= 0:
		return {}
	var stats: Dictionary = stats_by_team.get(team_id, {})
	if stats.is_empty():
		stats = {
			"max_total_hive_power": 0,
			"units_killed": 0,
			"units_landed": 0,
			"units_landed_enemy": 0,
			"units_fed_friendly": 0
		}
		stats_by_team[team_id] = stats
	return stats

func update_team_max_power(team_id: int, total_power: int) -> void:
	if team_id <= 0 or total_power <= 0:
		return
	var stats := _ensure_team_stats(team_id)
	var current: int = int(stats.get("max_total_hive_power", 0))
	if total_power > current:
		stats["max_total_hive_power"] = total_power
		stats_by_team[team_id] = stats

func add_units_landed(owner_id: int, count: int) -> void:
	if owner_id <= 0 or count <= 0:
		return
	var team_id: int = get_team_for_seat(owner_id)
	if team_id <= 0:
		return
	var stats := _ensure_team_stats(team_id)
	stats["units_landed"] = int(stats.get("units_landed", 0)) + count
	stats_by_team[team_id] = stats

func add_units_landed_enemy(owner_id: int, count: int) -> void:
	if owner_id <= 0 or count <= 0:
		return
	var team_id: int = get_team_for_seat(owner_id)
	if team_id <= 0:
		return
	var stats := _ensure_team_stats(team_id)
	stats["units_landed_enemy"] = int(stats.get("units_landed_enemy", 0)) + count
	stats_by_team[team_id] = stats

func add_units_fed_friendly(owner_id: int, count: int) -> void:
	if owner_id <= 0 or count <= 0:
		return
	var team_id: int = get_team_for_seat(owner_id)
	if team_id <= 0:
		return
	var stats := _ensure_team_stats(team_id)
	stats["units_fed_friendly"] = int(stats.get("units_fed_friendly", 0)) + count
	stats_by_team[team_id] = stats

func add_units_killed(killer_id: int, count: int) -> void:
	if killer_id <= 0 or count <= 0:
		return
	var team_id: int = get_team_for_seat(killer_id)
	if team_id <= 0:
		return
	var stats := _ensure_team_stats(team_id)
	stats["units_killed"] = int(stats.get("units_killed", 0)) + count
	stats_by_team[team_id] = stats

func tick_match_clock(state_ref: GameState, dt_ms: int) -> void:
	if not is_running():
		match_clock_running = false
		return
	var now_ms := Time.get_ticks_msec()
	if not match_clock_started:
		match_clock_started = true
		match_elapsed_ms = 0
		match_clock_running = true
		match_end_reason = ""
		match_duration_ms = _configured_match_duration_ms()
		match_time_remaining_sec = float(match_duration_ms) / 1000.0
		match_time_remaining_ms = match_duration_ms
		match_remaining_ms = match_duration_ms
		match_deadline_ms = now_ms + match_duration_ms
		timer_visible_started = false
		in_overtime = false
		ot_checked = false
		if not _match_timer_config_logged:
			SFLog.info("MATCH_TIMER_CONFIG", {
				"test": SF_TEST_MATCH_TIMER,
				"duration_ms": match_duration_ms
			})
			_match_timer_config_logged = true
		SFLog.info("CLOCK_START", {
			"iid": int(state_ref.get_instance_id()) if state_ref != null else 0,
			"duration_ms": match_duration_ms
		})
	if not match_clock_running:
		return
	var remaining_ms := match_deadline_ms - now_ms
	if remaining_ms < 0:
		remaining_ms = 0
	match_time_remaining_ms = remaining_ms
	match_time_remaining_sec = float(remaining_ms) / 1000.0
	match_remaining_ms = remaining_ms
	match_elapsed_ms = match_duration_ms - remaining_ms
	if match_elapsed_ms < 0:
		match_elapsed_ms = 0
	if match_elapsed_ms >= match_duration_ms:
		match_elapsed_ms = match_duration_ms

func request_intent_feed(src_id: int, dst_id: int) -> bool:
	var result := apply_lane_intent(src_id, dst_id, "feed")
	var ok: bool = bool(result.get("ok", false))
	if not ok:
		SFLog.info("INTENT_BLOCKED", {
			"intent": "feed",
			"src": src_id,
			"dst": dst_id,
			"reason": str(result.get("reason", "unknown")),
			"lane_id": int(result.get("lane_id", -1))
		})
	return ok

func request_intent_attack(src_id: int, dst_id: int) -> bool:
	var result := apply_lane_intent(src_id, dst_id, "attack")
	var ok: bool = bool(result.get("ok", false))
	if not ok:
		SFLog.info("INTENT_BLOCKED", {
			"intent": "attack",
			"src": src_id,
			"dst": dst_id,
			"reason": str(result.get("reason", "unknown")),
			"lane_id": int(result.get("lane_id", -1))
		})
	return ok

func request_barracks_route(barracks_id: int, route_hive_ids: Array, player_id: int = -1) -> bool:
	var st: GameState = require_state()
	if st == null:
		return false
	if _guard_mutation("request_barracks_route"):
		return false
	if is_ending_or_ended():
		_log_input_ignored_match_over("request_barracks_route")
		return false
	var barracks_data: Dictionary = {}
	for b_any in st.barracks:
		if typeof(b_any) != TYPE_DICTIONARY:
			continue
		var b: Dictionary = b_any as Dictionary
		if int(b.get("id", -1)) == barracks_id:
			barracks_data = b
			break
	if barracks_data.is_empty():
		return false
	var owner_id: int = int(barracks_data.get("owner_id", 0))
	if owner_id <= 0:
		return false
	if player_id != -1 and owner_id != player_id:
		return false
	if _vs_runtime_is_active_for_local_owner(owner_id):
		return _maybe_replicate_barracks_route(barracks_id, route_hive_ids, owner_id)
	var allowed_ids: Array = _barracks_allowed_route_ids(st, barracks_data, owner_id)
	if allowed_ids.is_empty():
		return false
	var allowed_lookup: Dictionary = {}
	for hive_id_v in allowed_ids:
		allowed_lookup[int(hive_id_v)] = true
	var route: Array = []
	var seen: Dictionary = {}
	for hive_id_v in route_hive_ids:
		var hive_id: int = int(hive_id_v)
		if allowed_lookup.has(hive_id) and not seen.has(hive_id):
			seen[hive_id] = true
			route.append(hive_id)
	barracks_data["route_hive_ids"] = route.duplicate()
	barracks_data["route_targets"] = route.duplicate()
	barracks_data["route_mode"] = str(barracks_data.get("route_mode", "round_robin"))
	barracks_data["route_cursor"] = 0
	barracks_data["preferred_targets"] = route.duplicate()
	barracks_data["rr_index"] = 0
	SFLog.info("BARRACKS_ROUTE_SET", {"id": barracks_id, "route": route})
	_record_match_action_event(owner_id, "barracks_route", {
		"barracks_id": barracks_id,
		"route_hive_ids": route.duplicate()
	})
	_maybe_replicate_barracks_route(barracks_id, route, owner_id)
	return true

func _barracks_allowed_route_ids(state: GameState, barracks_data: Dictionary, owner_id: int) -> Array:
	var allowed: Array = []
	var allowed_lookup: Dictionary = {}
	var control_v: Variant = barracks_data.get("control_hive_ids", [])
	if typeof(control_v) == TYPE_ARRAY:
		for hive_id_v in control_v as Array:
			var hive_id: int = int(hive_id_v)
			if hive_id <= 0 or allowed_lookup.has(hive_id):
				continue
			var hive: HiveData = state.find_hive_by_id(hive_id)
			if hive != null and hive.owner_id == owner_id:
				allowed_lookup[hive_id] = true
				allowed.append(hive_id)
	if allowed.is_empty():
		var required_v: Variant = barracks_data.get("required_hive_ids", [])
		if typeof(required_v) == TYPE_ARRAY:
			for hive_id_v in required_v as Array:
				var hive_id: int = int(hive_id_v)
				if hive_id <= 0 or allowed_lookup.has(hive_id):
					continue
				var hive: HiveData = state.find_hive_by_id(hive_id)
				if hive != null and hive.owner_id == owner_id:
					allowed_lookup[hive_id] = true
					allowed.append(hive_id)
	allowed.sort()
	return allowed

func _log_intent_blocked_by_wall(st: GameState, src_hive_id: int, dst_hive_id: int, intent: String) -> void:
	if st == null:
		return
	var walls: Array = st.walls if st != null else []
	if walls.is_empty():
		return
	var wall_segments: Array = MAP_SCHEMA._wall_segments_from_walls(walls)
	if wall_segments.is_empty():
		return
	var src_hive: HiveData = st.find_hive_by_id(src_hive_id)
	var dst_hive: HiveData = st.find_hive_by_id(dst_hive_id)
	if src_hive == null or dst_hive == null:
		return
	var a_grid := Vector2(float(src_hive.grid_pos.x), float(src_hive.grid_pos.y))
	var b_grid := Vector2(float(dst_hive.grid_pos.x), float(dst_hive.grid_pos.y))
	if not MAP_SCHEMA._segment_intersects_any_wall(a_grid, b_grid, wall_segments):
		return
	var from_xy := Vector2i(int(src_hive.grid_pos.x), int(src_hive.grid_pos.y))
	var to_xy := Vector2i(int(dst_hive.grid_pos.x), int(dst_hive.grid_pos.y))
	var edge_key := "%d->%d" % [src_hive_id, dst_hive_id]
	SFLog.info("INTENT_BLOCKED_BY_WALL", {
		"intent_kind": intent,
		"from_id": int(src_hive_id),
		"to_id": int(dst_hive_id),
		"from_xy": from_xy,
		"to_xy": to_xy,
		"edge_key": edge_key
	})

func _next_runtime_lane_id(st: GameState) -> int:
	var max_id: int = 0
	for lane_any in st.lanes:
		if lane_any is LaneData:
			max_id = maxi(max_id, int((lane_any as LaneData).id))
		elif lane_any is Dictionary:
			var lane_d: Dictionary = lane_any as Dictionary
			max_id = maxi(max_id, int(lane_d.get("lane_id", lane_d.get("id", 0))))
	return max_id + 1

func _can_create_runtime_lane(st: GameState, src_hive_id: int, dst_hive_id: int, intent: String) -> bool:
	var src_hive: HiveData = st.find_hive_by_id(src_hive_id)
	var dst_hive: HiveData = st.find_hive_by_id(dst_hive_id)
	if src_hive == null or dst_hive == null:
		return false
	if not st.can_connect(src_hive_id, dst_hive_id):
		return false
	var walls: Array = st.walls if st != null else []
	if not walls.is_empty():
		var wall_segments: Array = MAP_SCHEMA._wall_segments_from_walls(walls)
		if not wall_segments.is_empty():
			var a_grid := Vector2(float(src_hive.grid_pos.x), float(src_hive.grid_pos.y))
			var b_grid := Vector2(float(dst_hive.grid_pos.x), float(dst_hive.grid_pos.y))
			if MAP_SCHEMA._segment_intersects_any_wall(a_grid, b_grid, wall_segments):
				_log_intent_blocked_by_wall(st, src_hive_id, dst_hive_id, intent)
				return false
	return true

func _ensure_runtime_lane(st: GameState, src_hive_id: int, dst_hive_id: int, intent: String) -> int:
	var lane_index: int = st.lane_index_between(src_hive_id, dst_hive_id)
	if lane_index != -1:
		return lane_index
	if not _can_create_runtime_lane(st, src_hive_id, dst_hive_id, intent):
		return -1
	var lane_id: int = _next_runtime_lane_id(st)
	st.lanes.append(LaneData.new(lane_id, src_hive_id, dst_hive_id, 1, false, false))
	st.rebuild_indexes()
	SFLog.allow_tag("RUNTIME_LANE_CREATED")
	SFLog.warn("RUNTIME_LANE_CREATED", {
		"lane_id": lane_id,
		"src": src_hive_id,
		"dst": dst_hive_id,
		"intent": intent
	})
	return st.lane_index_between(src_hive_id, dst_hive_id)

func apply_lane_intent(src_hive_id: int, dst_hive_id: int, intent: String) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "",
		"lane_id": -1,
		"src": src_hive_id,
		"dst": dst_hive_id,
		"intent": intent
	}
	var telemetry_src_owner: int = 0
	var telemetry_dst_owner: int = 0
	var st: GameState = require_state()
	if st == null:
		result["reason"] = "state_missing"
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	if _guard_mutation("apply_lane_intent"):
		result["reason"] = "render_export"
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	if is_ending_or_ended():
		result["reason"] = "match_over"
		_log_input_ignored_match_over("apply_lane_intent")
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	if intent == "swarm":
		var lane_index := st.lane_index_between(src_hive_id, dst_hive_id)
		if lane_index == -1:
			result["reason"] = "no_lane"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
			return result
		var lane_any: Variant = st.lanes[lane_index]
		if not (lane_any is LaneData):
			result["reason"] = "no_lane"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
			return result
		var swarm_lane := lane_any as LaneData
		result["lane_id"] = int(swarm_lane.id)
		var from_is_a: bool = false
		if src_hive_id == int(swarm_lane.a_id) and dst_hive_id == int(swarm_lane.b_id):
			from_is_a = true
		elif src_hive_id == int(swarm_lane.b_id) and dst_hive_id == int(swarm_lane.a_id):
			from_is_a = false
		else:
			result["reason"] = "no_lane"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
			return result
		var swarm_src: HiveData = st.find_hive_by_id(src_hive_id)
		var swarm_dst: HiveData = st.find_hive_by_id(dst_hive_id)
		if swarm_src != null:
			telemetry_src_owner = int(swarm_src.owner_id)
		if swarm_dst != null:
			telemetry_dst_owner = int(swarm_dst.owner_id)
		if swarm_src == null or swarm_dst == null:
			result["reason"] = "missing_hive"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)), telemetry_src_owner, telemetry_dst_owner)
			return result
		if int(swarm_src.owner_id) <= 0:
			result["reason"] = "src_owner"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)), telemetry_src_owner, telemetry_dst_owner)
			return result
		var send_enabled: bool = bool(swarm_lane.send_a if from_is_a else swarm_lane.send_b)
		if not send_enabled:
			result["reason"] = "not_enabled"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)), telemetry_src_owner, telemetry_dst_owner)
			return result
		if int(swarm_src.power) <= 1:
			result["reason"] = "no_power"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)), telemetry_src_owner, telemetry_dst_owner)
			return result
		var cooldown_remaining_ms: int = _swarm_cooldown_remaining_ms(st, src_hive_id)
		if cooldown_remaining_ms > 0:
			result["reason"] = "cooldown"
			result["cooldown_remaining_ms"] = cooldown_remaining_ms
			SFLog.info("SWARM_COOLDOWN_BLOCK", {
				"src": src_hive_id,
				"dst": dst_hive_id,
				"remaining_ms": cooldown_remaining_ms
			})
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)), telemetry_src_owner, telemetry_dst_owner)
			return result
		var scheduled_swarm_result: Dictionary = _schedule_vs_lane_intent_if_needed(st, src_hive_id, dst_hive_id, intent)
		if not scheduled_swarm_result.is_empty():
			return scheduled_swarm_result
		var now_us: int = int(st._sim_time_us)
		st.swarm_cooldown_until_us[src_hive_id] = now_us + (SWARM_COOLDOWN_MS * 1000)
		if st.swarm_requests == null:
			st.swarm_requests = []
		st.swarm_requests.append({"src": src_hive_id, "dst": dst_hive_id})
		result["ok"] = true
		result["cooldown_ms"] = SWARM_COOLDOWN_MS
		SFLog.info("INTENT_SWARM", {"src": src_hive_id, "dst": dst_hive_id, "cooldown_ms": SWARM_COOLDOWN_MS})
		_record_intent_telemetry(
			src_hive_id,
			dst_hive_id,
			intent,
			true,
			"",
			int(result.get("lane_id", -1)),
			telemetry_src_owner,
			telemetry_dst_owner
		)
		_record_match_action_event(telemetry_src_owner, "swarm_send", {
			"lane_id": int(result.get("lane_id", -1)),
			"src": src_hive_id,
			"dst": dst_hive_id,
			"src_owner": telemetry_src_owner,
			"dst_owner": telemetry_dst_owner
		})
		_maybe_replicate_lane_intent(src_hive_id, dst_hive_id, intent, telemetry_src_owner, telemetry_dst_owner)
		return result
	var lane_index := st.lane_index_between(src_hive_id, dst_hive_id)
	if lane_index == -1 and intent != "none":
		var budget_src_hive: HiveData = st.find_hive_by_id(src_hive_id)
		if budget_src_hive == null:
			result["reason"] = "missing_hive"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
			return result
		var pre_budget: int = int(st.lanes_allowed_for_power(int(budget_src_hive.power)))
		var pre_active: int = int(st.count_active_outgoing(src_hive_id))
		if pre_active >= pre_budget:
			SFLog.info("LANE_BUDGET_BLOCK", {
				"src": src_hive_id,
				"dst": dst_hive_id,
				"power": int(budget_src_hive.power),
				"active": pre_active,
				"budget": pre_budget,
				"runtime_lane_created": false
			})
			result["reason"] = "budget"
			_record_intent_telemetry(
				src_hive_id,
				dst_hive_id,
				intent,
				false,
				str(result.get("reason", "")),
				int(result.get("lane_id", -1))
			)
			return result
		if not _can_create_runtime_lane(st, src_hive_id, dst_hive_id, intent):
			if intent != "none":
				_log_intent_blocked_by_wall(st, src_hive_id, dst_hive_id, intent)
			result["reason"] = "no_lane"
			_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
			return result
		var scheduled_runtime_lane_result: Dictionary = _schedule_vs_lane_intent_if_needed(st, src_hive_id, dst_hive_id, intent)
		if not scheduled_runtime_lane_result.is_empty():
			return scheduled_runtime_lane_result
		lane_index = _ensure_runtime_lane(st, src_hive_id, dst_hive_id, intent)
	if lane_index == -1:
		if intent != "none":
			_log_intent_blocked_by_wall(st, src_hive_id, dst_hive_id, intent)
		result["reason"] = "no_lane"
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	var lane: LaneData = st.lanes[lane_index]
	result["lane_id"] = int(lane.id)
	var pre_send_a: bool = bool(lane.send_a)
	var pre_send_b: bool = bool(lane.send_b)

	var src_hive: HiveData = st.find_hive_by_id(src_hive_id)
	var dst_hive: HiveData = st.find_hive_by_id(dst_hive_id)
	if src_hive == null or dst_hive == null:
		result["reason"] = "missing_hive"
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	var src_owner := int(src_hive.owner_id)
	var dst_owner := int(dst_hive.owner_id)
	telemetry_src_owner = src_owner
	telemetry_dst_owner = dst_owner
	if src_owner <= 0:
		result["reason"] = "src_owner"
		_record_intent_telemetry(
			src_hive_id,
			dst_hive_id,
			intent,
			false,
			str(result.get("reason", "")),
			int(result.get("lane_id", -1)),
			telemetry_src_owner,
			telemetry_dst_owner
		)
		return result

	var same_team: bool = are_allies(src_owner, dst_owner)
	var resolved_intent: String = intent
	if resolved_intent == "attack" and same_team:
		resolved_intent = "feed"
		result["intent"] = resolved_intent
		SFLog.info("INTENT_AUTO_FEED_ALLY", {
			"src": src_hive_id,
			"dst": dst_hive_id,
			"requested_intent": intent,
			"resolved_intent": resolved_intent,
			"src_owner": src_owner,
			"dst_owner": dst_owner
		})
	# Route intents are idempotent commands. Repeating attack/feed should keep
	# the lane open; explicit retract/none is the only command that closes it.
	var enable := resolved_intent != "none"

	var power: int = int(src_hive.power)
	var budget: int = int(st.lanes_allowed_for_power(power))
	var active: int = int(st.count_active_outgoing(src_hive_id))
	var already_active: bool = bool(st.is_outgoing_lane_active(src_hive_id, dst_hive_id))

	if not enable and not already_active:
		result["reason"] = "not_active"
		_record_intent_telemetry(
			src_hive_id,
			dst_hive_id,
			resolved_intent,
			false,
			str(result.get("reason", "")),
			int(result.get("lane_id", -1)),
			telemetry_src_owner,
			telemetry_dst_owner
		)
		return result

	if enable and resolved_intent != "none" and not st.can_connect(src_hive_id, dst_hive_id):
		result["reason"] = "blocked"
		_log_intent_blocked_by_wall(st, src_hive_id, dst_hive_id, resolved_intent)
		_record_intent_telemetry(
			src_hive_id,
			dst_hive_id,
			resolved_intent,
			false,
			str(result.get("reason", "")),
			int(result.get("lane_id", -1)),
			telemetry_src_owner,
			telemetry_dst_owner
		)
		return result

	if enable and resolved_intent != "none":
		if resolved_intent == "feed" and not same_team:
			result["reason"] = "ownership"
			_record_intent_telemetry(
				src_hive_id,
				dst_hive_id,
				resolved_intent,
				false,
				str(result.get("reason", "")),
				int(result.get("lane_id", -1)),
				telemetry_src_owner,
				telemetry_dst_owner
			)
			return result
		if not already_active and active >= budget:
			SFLog.info("LANE_BUDGET_BLOCK", {
				"src": src_hive_id,
				"dst": dst_hive_id,
				"power": power,
				"active": active,
				"budget": budget
			})
			result["reason"] = "budget"
			_record_intent_telemetry(
				src_hive_id,
				dst_hive_id,
				resolved_intent,
				false,
				str(result.get("reason", "")),
				int(result.get("lane_id", -1)),
				telemetry_src_owner,
				telemetry_dst_owner
			)
			return result

	if (enable and not already_active) or (already_active and not enable):
		var action := "disable" if already_active and not enable else "enable"
		SFLog.info("LANE_BUDGET_APPLY", {
			"src": src_hive_id,
			"dst": dst_hive_id,
			"power": power,
			"active": active,
			"budget": budget,
				"action": action,
				"intent": resolved_intent
			})

	var scheduled_lane_result: Dictionary = _schedule_vs_lane_intent_if_needed(st, src_hive_id, dst_hive_id, resolved_intent)
	if not scheduled_lane_result.is_empty():
		scheduled_lane_result["lane_id"] = int(result.get("lane_id", -1))
		scheduled_lane_result["intent"] = resolved_intent
		return scheduled_lane_result

	var pre_apply_source_exec: Dictionary = {}
	if st.has_method("get_execution_metrics_for_hive"):
		pre_apply_source_exec = st.call("get_execution_metrics_for_hive", src_hive_id)
	var pre_source_targets: Dictionary = _active_outgoing_targets(st, src_hive_id)
	var pre_lane_directions: Array = _lane_direction_snapshot(st)
	_apply_lane_intent(lane, src_hive_id, dst_hive_id, enable, resolved_intent)
	if enable and resolved_intent != "none" and _lost_source_outgoing_target(st, src_hive_id, dst_hive_id, pre_source_targets):
		_restore_lane_direction_snapshot(st, pre_lane_directions)
		result["reason"] = "implicit_replace_blocked"
		result["ok"] = false
		SFLog.warn("LANE_REPLACE_BLOCKED", {
			"src": src_hive_id,
			"dst": dst_hive_id,
			"intent": resolved_intent,
			"pre_targets": pre_source_targets.keys()
		})
		_record_intent_telemetry(
			src_hive_id,
			dst_hive_id,
			resolved_intent,
			false,
			str(result.get("reason", "")),
			int(result.get("lane_id", -1)),
			telemetry_src_owner,
			telemetry_dst_owner
		)
		return result
	result["ok"] = true
	var opened_new_lane: bool = enable and not already_active
	var disabled_lane: bool = (not enable) and already_active
	var reversed_lane: bool = false
	if enable:
		if src_hive_id == int(lane.a_id):
			reversed_lane = pre_send_b
		elif src_hive_id == int(lane.b_id):
			reversed_lane = pre_send_a

	var log_intent := resolved_intent if enable else "none"
	var iid := int(st.get_instance_id())

	SFLog.info("LANE_INTENT_APPLIED", {
		"iid": iid,
		"lane_id": int(lane.id),
		"a_id": int(lane.a_id),
		"b_id": int(lane.b_id),
		"src": int(src_hive_id),
		"dst": int(dst_hive_id),
		"src_is_a": src_hive_id == int(lane.a_id),
		"src_is_b": src_hive_id == int(lane.b_id),
		"send_a": bool(lane.send_a),
		"send_b": bool(lane.send_b),
		"intent": log_intent
	})
	_record_intent_telemetry(
		src_hive_id,
		dst_hive_id,
		log_intent,
		true,
		"",
		int(result.get("lane_id", -1)),
		telemetry_src_owner,
		telemetry_dst_owner,
		pre_apply_source_exec
	)
	if opened_new_lane:
		_record_match_action_event(telemetry_src_owner, "lane_open_%s" % resolved_intent, {
			"lane_id": int(lane.id),
			"src": src_hive_id,
			"dst": dst_hive_id,
			"src_owner": telemetry_src_owner,
			"dst_owner": telemetry_dst_owner
		})
	if disabled_lane:
		_record_match_action_event(telemetry_src_owner, "lane_disable", {
			"lane_id": int(lane.id),
			"src": src_hive_id,
			"dst": dst_hive_id,
			"src_owner": telemetry_src_owner,
			"dst_owner": telemetry_dst_owner
		})
	if reversed_lane:
		_record_match_action_event(telemetry_src_owner, "lane_reverse", {
			"lane_id": int(lane.id),
			"src": src_hive_id,
			"dst": dst_hive_id,
			"src_owner": telemetry_src_owner,
			"dst_owner": telemetry_dst_owner,
			"intent": resolved_intent
		})
	_maybe_replicate_lane_intent(src_hive_id, dst_hive_id, log_intent, telemetry_src_owner, telemetry_dst_owner)
	emit_signal("lane_intent_changed", iid, int(lane.id))
	emit_signal("lanes_changed", iid)
	return result


func _active_outgoing_targets(st: GameState, src_hive_id: int) -> Dictionary:
	var targets: Dictionary = {}
	if st == null:
		return targets
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane := lane_any as LaneData
		if int(lane.a_id) == src_hive_id and bool(lane.send_a):
			targets[int(lane.b_id)] = true
		elif int(lane.b_id) == src_hive_id and bool(lane.send_b):
			targets[int(lane.a_id)] = true
	return targets

func _lost_source_outgoing_target(st: GameState, src_hive_id: int, dst_hive_id: int, pre_targets: Dictionary) -> bool:
	if pre_targets.is_empty():
		return false
	var current_targets: Dictionary = _active_outgoing_targets(st, src_hive_id)
	for target_any in pre_targets.keys():
		var target_id: int = int(target_any)
		if target_id == dst_hive_id:
			continue
		if not bool(current_targets.get(target_id, false)):
			return true
	return false

func _lane_direction_snapshot(st: GameState) -> Array:
	var snapshot: Array = []
	if st == null:
		return snapshot
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane := lane_any as LaneData
		snapshot.append({
			"id": int(lane.id),
			"send_a": bool(lane.send_a),
			"send_b": bool(lane.send_b),
			"dir": int(lane.dir),
			"establish_a": bool(lane.establish_a),
			"establish_b": bool(lane.establish_b),
			"retract_a": bool(lane.retract_a),
			"retract_b": bool(lane.retract_b)
		})
	return snapshot

func _restore_lane_direction_snapshot(st: GameState, snapshot: Array) -> void:
	if st == null:
		return
	var by_id: Dictionary = {}
	for entry_any in snapshot:
		if typeof(entry_any) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_any as Dictionary
			by_id[int(entry.get("id", -1))] = entry
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane := lane_any as LaneData
		var entry: Dictionary = by_id.get(int(lane.id), {}) as Dictionary
		if entry.is_empty():
			continue
		lane.send_a = bool(entry.get("send_a", false))
		lane.send_b = bool(entry.get("send_b", false))
		lane.dir = int(entry.get("dir", lane.dir))
		lane.establish_a = bool(entry.get("establish_a", false))
		lane.establish_b = bool(entry.get("establish_b", false))
		lane.retract_a = bool(entry.get("retract_a", false))
		lane.retract_b = bool(entry.get("retract_b", false))

func _apply_lane_intent(lane: LaneData, src_id: int, dst_id: int, enable: bool, intent: String) -> void:
	var st: GameState = require_state()
	var a: HiveData = st.find_hive_by_id(int(lane.a_id))
	var b: HiveData = st.find_hive_by_id(int(lane.b_id))
	if a == null or b == null:
		return
	var was_send_a: bool = bool(lane.send_a)
	var was_send_b: bool = bool(lane.send_b)
	var is_a_to_b: bool = src_id == int(lane.a_id) and dst_id == int(lane.b_id)
	var is_b_to_a: bool = src_id == int(lane.b_id) and dst_id == int(lane.a_id)
	if is_a_to_b:
		if enable:
			lane.send_a = lane.send_a or (src_id == int(lane.a_id))
		else:
			lane.send_a = false
		if enable:
			lane.dir = 1
			lane.retract_a = false
			if not was_send_a:
				lane.establish_a = true
				lane.establish_t0_ms = Time.get_ticks_msec()
				lane.build_t = 0.0
				lane.a_stream_len = 0.0
		else:
			lane.establish_a = false
		if enable and intent == "feed":
			lane.send_b = false
	elif is_b_to_a:
		if enable:
			lane.send_b = lane.send_b or (src_id == int(lane.b_id))
		else:
			lane.send_b = false
		if enable:
			lane.dir = -1
			lane.retract_b = false
			if not was_send_b:
				lane.establish_b = true
				lane.establish_t0_ms = Time.get_ticks_msec()
				lane.build_t = 0.0
				lane.b_stream_len = 0.0
		else:
			lane.establish_b = false
		if enable and intent == "feed":
			lane.send_a = false

func apply_intent_pair(start_id: int, end_id: int) -> bool:
	return request_intent_attack(start_id, end_id)

func apply_dev_intent(from_id: int, to_id: int, dev_pid: int) -> bool:
	if dev_pid == -1:
		return false
	var st: GameState = require_state()
	var from_hive: HiveData = st.find_hive_by_id(from_id)
	if from_hive == null or from_hive.owner_id != dev_pid:
		return false
	return request_intent_attack(from_id, to_id)

func retract_lane(from_id: int, to_id: int, owner_id: int) -> void:
	var st: GameState = require_state()
	if _guard_mutation("retract_lane"):
		return
	if is_ending_or_ended():
		_log_input_ignored_match_over("retract_lane")
		return
	var lane_index := st.lane_index_between(from_id, to_id)
	if lane_index == -1:
		return
	var lane: LaneData = st.lanes[lane_index]
	var from_hive_for_schedule: HiveData = st.find_hive_by_id(from_id)
	var schedule_owner_id: int = int(from_hive_for_schedule.owner_id) if from_hive_for_schedule != null else owner_id
	if _vs_runtime_is_active_for_local_owner(schedule_owner_id):
		_maybe_replicate_lane_retract(from_id, to_id, schedule_owner_id)
		return
	if from_id == int(lane.a_id):
		lane.send_a = false
		lane.retract_a = true
		lane.spawn_accum_a_ms = 0.0
		lane.establish_a = false
		lane.a_stream_len = 0.0
	elif from_id == int(lane.b_id):
		lane.send_b = false
		lane.retract_b = true
		lane.spawn_accum_b_ms = 0.0
		lane.establish_b = false
		lane.b_stream_len = 0.0
	st.lane_retract_requests.append({
		"lane_id": int(lane.id),
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id
	})
	SFLog.info("LANE_RETRACT_REQUEST", {
		"lane_id": int(lane.id),
		"from_id": from_id,
		"to_id": to_id,
		"owner_id": owner_id
	})
	_record_match_action_event(owner_id, "lane_retract", {
		"lane_id": int(lane.id),
		"src": from_id,
		"dst": to_id,
		"owner_id": owner_id
	})
	_maybe_replicate_lane_retract(from_id, to_id, owner_id)

func try_swarm(_from_id: int, _to_id: int, _pid: int = -1) -> bool:
	var result := apply_lane_intent(_from_id, _to_id, "swarm")
	return bool(result.get("ok", false))

func try_activate_buff_slot(_pid: int, _slot_index: int) -> void:
	return

func _log_input_ignored_match_over(context: String) -> void:
	if _input_ignored_match_over_logged:
		return
	_input_ignored_match_over_logged = true
	SFLog.info("INPUT_IGNORED_MATCH_OVER", {
		"phase": int(match_phase),
		"context": context
	})

func _lane_mode(a: HiveData, b: HiveData) -> String:
	var ao := int(a.owner_id)
	var bo := int(b.owner_id)
	if ao == 0 or bo == 0:
		return "neutral"
	if ao == bo:
		return "friendly"
	return "opposing"

func reset_state_from_map(map_dict: Dictionary) -> GameState:
	if _guard_mutation("reset_state_from_map"):
		return state
	_state_serial += 1
	reset_match_state()
	edge_cache = {}
	edge_cache_version = -1
	blocked_wall_pairs = []

	var new_state: GameState = GameState.new()
	state = new_state

	new_state.init_core_defaults()
	new_state.load_from_map_dict(map_dict)
	new_state.seed_starting_power_if_missing(GameState.START_POWER)
	new_state.rebuild_lane_adjacency()
	lane_front_by_lane_id.clear()
	for lane_any in new_state.lanes:
		if lane_any is LaneData:
			var l: LaneData = lane_any
			lane_front_by_lane_id[int(l.id)] = 0.5
		elif lane_any is Dictionary:
			var d: Dictionary = lane_any as Dictionary
			var lane_id: int = int(d.get("lane_id", d.get("id", -1)))
			if lane_id > 0:
				lane_front_by_lane_id[lane_id] = 0.5

	SFLog.info("STATE_CREATED", {
		"iid": int(new_state.get_instance_id()),
		"serial": _state_serial,
		"stack": get_stack()
	})

	var map_id := str(map_dict.get("map_id", map_dict.get("_id", map_dict.get("id", "UNKNOWN"))))
	current_map_id = map_id
	SFLog.info("OPS_STATE_CHANGED", {
		"iid": int(new_state.get_instance_id()),
		"map_id": map_id
	})

	call_deferred("_emit_state_changed", new_state)
	return new_state

func _emit_state_changed(new_state: GameState) -> void:
	if new_state == null:
		return
	emit_signal("state_changed", new_state)
	emit_signal("ops_state_changed", int(new_state.get_instance_id()))

func _guard_mutation(context: String) -> bool:
	if not _in_render_export:
		return false
	SFLog.error("MUTATE_DURING_RENDER_EXPORT", {
		"context": context,
		"stack": get_stack()
	})
	return true

func _auth_fence_first_external_frame() -> Dictionary:
	var stack: Array = get_stack()
	for i in range(1, stack.size()):
		var frame: Dictionary = stack[i]
		var source: String = str(frame.get("source", ""))
		if source.ends_with("scripts/ops/ops_state.gd"):
			continue
		return frame
	return {}

func _auth_fence_source_allowed(source: String) -> bool:
	if source.is_empty():
		return true
	if source.ends_with("scripts/ops/ops_state.gd"):
		return true
	for prefix in AUTH_FENCE_ALLOWED_PREFIXES:
		if source.begins_with(prefix):
			return true
	return false

func sim_mutate(tag: String, fn: Callable) -> void:
	_sim_mutate_depth += 1
	var tag_to_push: String = tag
	if tag_to_push == "":
		tag_to_push = "<untagged>"
	_sim_mutate_tag_stack.append(tag_to_push)
	if not fn.is_valid():
		SFLog.warn("SIM_MUTATE_INVALID_CALLABLE", {"tag": tag_to_push})
	else:
		fn.call()
	if _sim_mutate_tag_stack.is_empty():
		SFLog.warn("SIM_MUTATE_STACK_UNDERFLOW", {"tag": tag_to_push})
	else:
		_sim_mutate_tag_stack.pop_back()
	_sim_mutate_depth -= 1
	if _sim_mutate_depth < 0:
		SFLog.error("SIM_MUTATE_UNDERFLOW", {"tag": tag_to_push, "depth": _sim_mutate_depth})
		_sim_mutate_depth = 0

func audit_mutation(context: String, target: String = "", source_hint: String = "") -> void:
	SFLog.allow_tag("OPSSTATE_MUTATION_FENCE")
	if _sim_mutate_depth > 0:
		return
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
	var active_tag: String = ""
	if _sim_mutate_tag_stack.size() > 0:
		active_tag = _sim_mutate_tag_stack[_sim_mutate_tag_stack.size() - 1]
	SFLog.warn("OPSSTATE_MUTATION_FENCE", {
		"context": context,
		"target": target,
		"source": source,
		"line": line_no,
		"active_sim_tag": active_tag
	})
	if auth_fence_assert_enabled:
		assert(false, "OpsState mutation fence hit: %s (%s)" % [context, target])
