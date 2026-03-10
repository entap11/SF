# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
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
var _state_serial: int = 0
var _console_instance: Control = null
var _bot_telemetry_store: RefCounted = BotTelemetryStoreScript.new()

# --- MATCH OUTCOME + CLOCK (authoritative) ---
enum MatchPhase {
	PREMATCH,
	RUNNING,
	ENDING,
	ENDED
}
const PREMATCH_DURATION_MS := 5000
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

func require_state() -> GameState:
	assert(state != null, "OpsState.state is null. State must be created explicitly via reset_state_from_map().")
	return state

func get_state_iid() -> int:
	if state == null:
		return 0
	return int(state.iid)

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
	victory_mode = VICTORY_MODE_CONQUEST
	victory_rules = {}
	capture_flag_state = {}

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
		"swarm_frequency": 0.34
	}

func _bot_style_patch(style: String) -> Dictionary:
	var normalized_style: String = _normalize_bot_style(style)
	match normalized_style:
		BOT_STYLE_TURTLE:
			return {
				"style": BOT_STYLE_TURTLE,
				"persona": BOT_STYLE_TURTLE,
				"think_interval_ms": 1260,
				"think_jitter_ms": 150,
				"post_intent_delay_ms": 560,
				"opening_delay_ms": 2400,
				"aggression": 0.32,
				"feed_bias": 0.62,
				"min_attack_power": 12,
				"min_feed_power": 10,
				"min_swarm_power": 21,
				"allow_swarm": false,
				"prefer_neutral_bonus": 0.15,
				"randomness": 0.05,
				"pair_intent_cooldown_ms": 1700,
				"global_intent_cooldown_ms": 1300,
				"attack_distance_weight": 2.6,
				"feed_distance_weight": 1.1,
				"attack_power_diff_weight": 0.95,
				"feed_need_weight": 1.65,
				"weak_target_bonus": 2.0,
				"strong_target_penalty": 9.0,
				"low_ally_power_bonus": 8.0,
				"enemy_owned_bonus": 1.0,
				"neutral_capture_bonus": 4.0,
				"swarm_frequency": 0.08
			}
		BOT_STYLE_RAIDER:
			return {
				"style": BOT_STYLE_RAIDER,
				"persona": BOT_STYLE_RAIDER,
				"think_interval_ms": 720,
				"think_jitter_ms": 90,
				"post_intent_delay_ms": 260,
				"opening_delay_ms": 1250,
				"aggression": 0.82,
				"feed_bias": 0.12,
				"min_attack_power": 7,
				"min_feed_power": 14,
				"min_swarm_power": 16,
				"allow_swarm": true,
				"prefer_neutral_bonus": 0.20,
				"randomness": 0.07,
				"retry_block_ms": 700,
				"no_lane_retry_ms": 2500,
				"pair_intent_cooldown_ms": 900,
				"global_intent_cooldown_ms": 700,
				"attack_distance_weight": 1.3,
				"feed_distance_weight": 1.9,
				"attack_power_diff_weight": 1.5,
				"feed_need_weight": 1.0,
				"weak_target_bonus": 10.0,
				"strong_target_penalty": 4.0,
				"low_ally_power_bonus": 2.0,
				"enemy_owned_bonus": 4.0,
				"neutral_capture_bonus": 4.0,
				"swarm_distance_weight": 1.0,
				"swarm_power_diff_weight": 2.0,
				"swarm_low_power_bonus": 10.0,
				"swarm_frequency": 0.45
			}
		BOT_STYLE_GREEDY:
			return {
				"style": BOT_STYLE_GREEDY,
				"persona": BOT_STYLE_GREEDY,
				"think_interval_ms": 760,
				"think_jitter_ms": 150,
				"post_intent_delay_ms": 300,
				"opening_delay_ms": 1200,
				"aggression": 0.57,
				"feed_bias": 0.18,
				"min_attack_power": 8,
				"min_feed_power": 13,
				"min_swarm_power": 20,
				"allow_swarm": false,
				"prefer_neutral_bonus": 1.35,
				"randomness": 0.16,
				"attack_distance_weight": 1.9,
				"feed_distance_weight": 1.9,
				"attack_power_diff_weight": 1.0,
				"feed_need_weight": 1.0,
				"weak_target_bonus": 3.0,
				"strong_target_penalty": 7.0,
				"low_ally_power_bonus": 1.0,
				"enemy_owned_bonus": 1.5,
				"neutral_capture_bonus": 10.0,
				"swarm_frequency": 0.05
			}
		BOT_STYLE_SWARM_LORD:
			return {
				"style": BOT_STYLE_SWARM_LORD,
				"persona": BOT_STYLE_SWARM_LORD,
				"think_interval_ms": 780,
				"think_jitter_ms": 100,
				"post_intent_delay_ms": 260,
				"opening_delay_ms": 1400,
				"aggression": 0.88,
				"feed_bias": 0.10,
				"min_attack_power": 8,
				"min_feed_power": 14,
				"min_swarm_power": 13,
				"allow_swarm": true,
				"prefer_neutral_bonus": 0.25,
				"randomness": 0.08,
				"retry_block_ms": 650,
				"no_lane_retry_ms": 2200,
				"pair_intent_cooldown_ms": 800,
				"global_intent_cooldown_ms": 650,
				"swarm_cooldown_ms": 900,
				"swarm_global_cooldown_ms": 1800,
				"attack_distance_weight": 1.6,
				"feed_distance_weight": 2.0,
				"attack_power_diff_weight": 1.3,
				"feed_need_weight": 0.95,
				"weak_target_bonus": 7.0,
				"strong_target_penalty": 5.0,
				"low_ally_power_bonus": 2.0,
				"enemy_owned_bonus": 3.0,
				"neutral_capture_bonus": 3.0,
				"swarm_distance_weight": 0.9,
				"swarm_power_diff_weight": 2.3,
				"swarm_low_power_bonus": 12.0,
				"weak_target_threshold": 14,
				"swarm_frequency": 0.72
			}
		_:
			return {
				"style": BOT_STYLE_BALANCER,
				"persona": BOT_STYLE_BALANCER
			}

func _apply_bot_tier(profile: Dictionary, tier: String) -> void:
	var normalized_tier: String = _normalize_bot_tier(tier)
	profile["tier"] = normalized_tier
	match normalized_tier:
		BOT_TIER_EASY:
			profile["think_interval_ms"] = int(profile.get("think_interval_ms", 900)) + 360
			profile["think_jitter_ms"] = int(profile.get("think_jitter_ms", 120)) + 80
			profile["post_intent_delay_ms"] = int(profile.get("post_intent_delay_ms", 400)) + 240
			profile["opening_delay_ms"] = int(profile.get("opening_delay_ms", 1600)) + 1400
			profile["aggression"] = clampf(float(profile.get("aggression", 0.5)) - 0.12, 0.0, 1.0)
			profile["feed_bias"] = clampf(float(profile.get("feed_bias", 0.3)) + 0.04, 0.0, 1.0)
			profile["randomness"] = clampf(float(profile.get("randomness", 0.08)) + 0.08, 0.0, 0.5)
			profile["min_attack_power"] = int(profile.get("min_attack_power", 9)) + 3
			profile["min_feed_power"] = int(profile.get("min_feed_power", 12)) + 2
			profile["min_swarm_power"] = int(profile.get("min_swarm_power", 17)) + 4
			profile["retry_block_ms"] = int(profile.get("retry_block_ms", 900)) + 500
			profile["no_lane_retry_ms"] = int(profile.get("no_lane_retry_ms", 3200)) + 1200
			profile["pair_intent_cooldown_ms"] = int(profile.get("pair_intent_cooldown_ms", 1300)) + 650
			profile["global_intent_cooldown_ms"] = int(profile.get("global_intent_cooldown_ms", 1000)) + 600
			profile["swarm_cooldown_ms"] = int(profile.get("swarm_cooldown_ms", 1600)) + 1000
			profile["swarm_global_cooldown_ms"] = int(profile.get("swarm_global_cooldown_ms", 3500)) + 1800
			profile["swarm_frequency"] = clampf(float(profile.get("swarm_frequency", 0.34)) - 0.18, 0.0, 1.0)
		BOT_TIER_HARD:
			profile["think_interval_ms"] = maxi(180, int(profile.get("think_interval_ms", 900)) - 180)
			profile["think_jitter_ms"] = maxi(0, int(profile.get("think_jitter_ms", 120)) - 30)
			profile["post_intent_delay_ms"] = maxi(0, int(profile.get("post_intent_delay_ms", 400)) - 120)
			profile["opening_delay_ms"] = maxi(0, int(profile.get("opening_delay_ms", 1600)) - 350)
			profile["aggression"] = clampf(float(profile.get("aggression", 0.5)) + 0.08, 0.0, 1.0)
			profile["feed_bias"] = clampf(float(profile.get("feed_bias", 0.3)) - 0.03, 0.0, 1.0)
			profile["randomness"] = clampf(float(profile.get("randomness", 0.08)) - 0.04, 0.0, 0.5)
			profile["min_attack_power"] = maxi(1, int(profile.get("min_attack_power", 9)) - 1)
			profile["min_feed_power"] = maxi(1, int(profile.get("min_feed_power", 12)) - 1)
			profile["min_swarm_power"] = maxi(1, int(profile.get("min_swarm_power", 17)) - 2)
			profile["retry_block_ms"] = maxi(200, int(profile.get("retry_block_ms", 900)) - 150)
			profile["no_lane_retry_ms"] = maxi(600, int(profile.get("no_lane_retry_ms", 3200)) - 500)
			profile["pair_intent_cooldown_ms"] = maxi(300, int(profile.get("pair_intent_cooldown_ms", 1300)) - 220)
			profile["global_intent_cooldown_ms"] = maxi(250, int(profile.get("global_intent_cooldown_ms", 1000)) - 180)
			profile["swarm_cooldown_ms"] = maxi(250, int(profile.get("swarm_cooldown_ms", 1600)) - 220)
			profile["swarm_global_cooldown_ms"] = maxi(500, int(profile.get("swarm_global_cooldown_ms", 3500)) - 500)
			profile["swarm_frequency"] = clampf(float(profile.get("swarm_frequency", 0.34)) + 0.10, 0.0, 1.0)
		_:
			pass
	if normalized_tier == BOT_TIER_HARD and float(profile.get("aggression", 0.0)) >= 0.80:
		profile["max_actions_per_tick"] = maxi(int(profile.get("max_actions_per_tick", 1)), 2)

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
	dst_owner_id: int = 0
) -> void:
	if _bot_telemetry_store == null:
		return
	if not _bot_telemetry_store.has_method("record_intent"):
		return
	var st: GameState = state
	var event: Dictionary = {
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
		"is_cpu_actor": _is_cpu_seat(src_owner_id)
	}
	_bot_telemetry_store.call("record_intent", event)

func _vs_pvp_runtime() -> Node:
	return get_node_or_null("/root/VsPvpRuntime")

func _maybe_replicate_lane_intent(src_hive_id: int, dst_hive_id: int, intent: String, src_owner_id: int, dst_owner_id: int) -> void:
	if _remote_replication_apply_depth > 0:
		return
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_lane_intent"):
		return
	runtime.call("record_local_lane_intent", src_hive_id, dst_hive_id, intent, src_owner_id, dst_owner_id)

func _maybe_replicate_lane_retract(from_id: int, to_id: int, owner_id: int) -> void:
	if _remote_replication_apply_depth > 0:
		return
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_lane_retract"):
		return
	runtime.call("record_local_lane_retract", from_id, to_id, owner_id)

func _maybe_replicate_barracks_route(barracks_id: int, route_hive_ids: Array, owner_id: int) -> void:
	if _remote_replication_apply_depth > 0:
		return
	var runtime: Node = _vs_pvp_runtime()
	if runtime == null or not runtime.has_method("record_local_barracks_route"):
		return
	runtime.call("record_local_barracks_route", barracks_id, route_hive_ids, owner_id)

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
			"units_landed": 0
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
		if lane_index != -1:
			var lane_any: Variant = st.lanes[lane_index]
			if lane_any is LaneData:
				result["lane_id"] = int((lane_any as LaneData).id)
			elif lane_any is Dictionary:
				result["lane_id"] = int((lane_any as Dictionary).get("lane_id", (lane_any as Dictionary).get("id", -1)))
		if st.swarm_requests == null:
			st.swarm_requests = []
		st.swarm_requests.append({"src": src_hive_id, "dst": dst_hive_id})
		result["ok"] = true
		var swarm_src: HiveData = st.find_hive_by_id(src_hive_id)
		var swarm_dst: HiveData = st.find_hive_by_id(dst_hive_id)
		if swarm_src != null:
			telemetry_src_owner = int(swarm_src.owner_id)
		if swarm_dst != null:
			telemetry_dst_owner = int(swarm_dst.owner_id)
		SFLog.info("INTENT_SWARM", {"src": src_hive_id, "dst": dst_hive_id})
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
		return result
	var lane_index := st.lane_index_between(src_hive_id, dst_hive_id)
	if lane_index == -1 and intent != "none":
		lane_index = _ensure_runtime_lane(st, src_hive_id, dst_hive_id, intent)
	if lane_index == -1:
		if intent != "none":
			_log_intent_blocked_by_wall(st, src_hive_id, dst_hive_id, intent)
		result["reason"] = "no_lane"
		_record_intent_telemetry(src_hive_id, dst_hive_id, intent, false, str(result.get("reason", "")), int(result.get("lane_id", -1)))
		return result
	var lane: LaneData = st.lanes[lane_index]
	result["lane_id"] = int(lane.id)

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
	var enable := true
	if resolved_intent == "none":
		enable = false
	else:
		enable = not st.intent_is_on(src_hive_id, dst_hive_id)

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

	_apply_lane_intent(lane, src_hive_id, dst_hive_id, enable, resolved_intent)
	result["ok"] = true

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
		telemetry_dst_owner
	)
	_maybe_replicate_lane_intent(src_hive_id, dst_hive_id, log_intent, telemetry_src_owner, telemetry_dst_owner)
	emit_signal("lane_intent_changed", iid, int(lane.id))
	emit_signal("lanes_changed", iid)
	return result


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
