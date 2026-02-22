extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const SwarmPassConfigScript = preload("res://scripts/state/swarm_pass_config.gd")
const SwarmPassPrestigeCapTrackerScript = preload("res://scripts/state/swarm_pass_prestige_cap_tracker.gd")
const SwarmPassTelemetryCollectorScript = preload("res://scripts/state/swarm_pass_telemetry_collector.gd")
const SwarmPassNectarPipelineScript = preload("res://scripts/state/swarm_pass_nectar_pipeline.gd")

signal pass_state_changed(snapshot: Dictionary)
signal pass_event(event: Dictionary)

enum PassTier {
	FREE,
	PREMIUM,
	ELITE
}

enum NectarSource {
	PVP,
	ASYNC,
	CONTEST,
	TOURNAMENT,
	MONEY_MATCH,
	STORE_KICKBACK
}

const CONFIG_PATH: String = "res://data/swarm_pass/swarm_pass_config.tres"
const SAVE_PATH: String = "user://swarm_pass_state.json"
const TELEMETRY_PATH: String = "user://swarm_pass_telemetry.json"
const PASS_GUARDRAIL_TEXT: String = "Pass multipliers affect Nectar and Pass progression only."

var _config: SwarmPassConfigScript = null
var _cap_tracker: SwarmPassPrestigeCapTrackerScript = SwarmPassPrestigeCapTrackerScript.new()
var _telemetry: SwarmPassTelemetryCollectorScript = SwarmPassTelemetryCollectorScript.new()
var _nectar_pipeline: SwarmPassNectarPipelineScript = SwarmPassNectarPipelineScript.new()

var _season_id: String = ""
var _season_started_unix: int = 0
var _season_ends_unix: int = 0

var _wallet_nectar: int = 0
var _pass_tier: int = PassTier.FREE
var _pass_xp: float = 0.0
var _pass_level: int = 1
var _blocked_hard_brick_level: int = -1
var _reward_variant_by_level: Dictionary = {}
var _claimed_free: Dictionary = {}
var _claimed_premium: Dictionary = {}
var _claimed_elite: Dictionary = {}
var _tier_achievements_seen: Dictionary = {}
var _first_free_apex_announced: bool = false

func _ready() -> void:
	SFLog.allow_tag("SWARMPASS_EVENT")
	SFLog.allow_tag("SWARMPASS_STATE")
	_load_config()
	_reset_or_roll_season_if_needed()
	_load_saved_state()
	_load_telemetry()
	SFLog.info("SWARMPASS_STATE", {
		"season_id": _season_id,
		"tier": _tier_name(_pass_tier),
		"level": _pass_level
	})
	_emit_changed()

func get_snapshot() -> Dictionary:
	var next_requirement: int = 0
	var progress_to_next: float = 1.0
	var level_next: int = mini(_pass_level + 1, _config.total_levels)
	if _pass_level < _config.total_levels:
		next_requirement = _config.pass_xp_required_for_level(_pass_level + 1)
		progress_to_next = clampf(_pass_xp / float(maxi(1, next_requirement)), 0.0, 1.0)
	var level_rows: Array[Dictionary] = _build_level_rows()
	return {
		"season_id": _season_id,
		"season_started_unix": _season_started_unix,
		"season_ends_unix": _season_ends_unix,
		"season_seconds_remaining": maxi(0, _season_ends_unix - _now_unix()),
		"pass_tier": _tier_name(_pass_tier),
		"pass_tier_int": _pass_tier,
		"pass_multiplier": _pass_multiplier(_pass_tier),
		"wallet_nectar": _wallet_nectar,
		"pass_xp": _pass_xp,
		"pass_level": _pass_level,
		"next_level": level_next,
		"next_level_requirement": next_requirement,
		"progress_to_next": progress_to_next,
		"total_levels": _config.total_levels,
		"standard_level_end": _config.standard_level_end,
		"advanced_level_end": _config.advanced_level_end,
		"prestige_level_start": _config.prestige_level_start,
		"apex_level_start": _config.apex_level_start,
		"prestige_model": "hard_brick" if _config.normalized_prestige_model() == SwarmPassConfigScript.PrestigeModel.HARD_BRICK else "soft_cap",
		"blocked_hard_brick_level": _blocked_hard_brick_level,
		"guardrail_text": PASS_GUARDRAIL_TEXT,
		"elite_async_access": _has_async_event_access(),
		"claimed": {
			"free": _claimed_free.duplicate(true),
			"premium": _claimed_premium.duplicate(true),
			"elite": _claimed_elite.duplicate(true)
		},
		"reward_variant_by_level": _reward_variant_by_level.duplicate(true),
		"level_rows": level_rows
	}

func get_telemetry_dashboard() -> Dictionary:
	return _telemetry.build_dashboard_snapshot()

func intent_purchase_pass_tier(tier_name: String) -> Dictionary:
	var requested: int = _tier_from_name(tier_name)
	if requested == -1:
		return {"ok": false, "reason": "invalid_tier"}
	if requested <= _pass_tier:
		return {"ok": false, "reason": "already_owned"}
	_pass_tier = requested
	_save_state()
	var event: Dictionary = {
		"type": "pass_tier_upgraded",
		"tier": _tier_name(_pass_tier),
		"price_usd": _config.premium_price_usd if _pass_tier == PassTier.PREMIUM else _config.elite_price_usd
	}
	pass_event.emit(event)
	SFLog.info("SWARMPASS_EVENT", event)
	_emit_changed()
	return {"ok": true, "tier": _tier_name(_pass_tier)}

func intent_claim_level(level: int) -> Dictionary:
	if level < 1 or level > _config.total_levels:
		return {"ok": false, "reason": "level_out_of_range"}
	if level > _pass_level:
		return {"ok": false, "reason": "level_locked"}
	var level_key: String = str(level)
	var claimed_payload: Dictionary = {
		"free": false,
		"premium": false,
		"elite": false
	}
	if not _claimed_free.has(level_key):
		_claimed_free[level_key] = true
		claimed_payload["free"] = true
	if _pass_tier >= PassTier.PREMIUM and not _claimed_premium.has(level_key):
		_claimed_premium[level_key] = true
		claimed_payload["premium"] = true
	if _pass_tier >= PassTier.ELITE and not _claimed_elite.has(level_key):
		_claimed_elite[level_key] = true
		claimed_payload["elite"] = true
	if not bool(claimed_payload["free"]) and not bool(claimed_payload["premium"]) and not bool(claimed_payload["elite"]):
		return {"ok": false, "reason": "already_claimed"}
	_save_state()
	var variant: String = str(_reward_variant_by_level.get(level_key, "standard"))
	var event: Dictionary = {
		"type": "pass_reward_claimed",
		"level": level,
		"variant": variant,
		"tracks_claimed": claimed_payload
	}
	pass_event.emit(event)
	SFLog.info("SWARMPASS_EVENT", event)
	_emit_changed()
	return {"ok": true, "claim": claimed_payload, "variant": variant}

func intent_record_nectar_award(source_name: String, nectar_amount: int, metadata: Dictionary = {}) -> Dictionary:
	var safe_nectar: int = maxi(0, nectar_amount)
	if safe_nectar <= 0:
		return {"ok": false, "reason": "no_nectar"}
	var multiplier: float = _pass_multiplier(_pass_tier)
	var pass_xp_gain: float = _nectar_pipeline.pass_xp_from_nectar(safe_nectar, multiplier)
	_wallet_nectar += safe_nectar
	var progress: Dictionary = _apply_pass_xp(pass_xp_gain)
	var event: Dictionary = {
		"type": "nectar_awarded",
		"source": source_name,
		"nectar_awarded": safe_nectar,
		"pass_xp_gain": pass_xp_gain,
		"metadata": metadata
	}
	pass_event.emit(event)
	SFLog.info("SWARMPASS_EVENT", event)
	_record_telemetry(safe_nectar)
	_save_state()
	_emit_changed()
	return {
		"ok": true,
		"source": source_name,
		"nectar_awarded": safe_nectar,
		"pass_xp_gain": pass_xp_gain,
		"progress": progress
	}

func intent_award_nectar_for_event(event_name: String, metadata: Dictionary = {}) -> Dictionary:
	var key: String = event_name.strip_edges().to_lower()
	var nectar: int = int(_config.nectar_awards.get(key, 0))
	if nectar <= 0:
		return {"ok": false, "reason": "unknown_event", "event_name": event_name}
	return intent_record_nectar_award(key, nectar, metadata)

func intent_record_store_purchase(amount_usd: float, metadata: Dictionary = {}) -> Dictionary:
	var usd: float = maxf(0.0, amount_usd)
	if usd <= 0.0:
		return {"ok": false, "reason": "amount_zero"}
	var kickback: int = int(round(usd * _config.store_kickback_nectar_per_usd))
	var meta: Dictionary = metadata.duplicate(true)
	meta["usd_amount"] = usd
	meta["kickback_nectar"] = kickback
	return intent_record_nectar_award("store_kickback", kickback, meta)

func intent_record_match_completed(is_money_match: bool, metadata: Dictionary = {}) -> Dictionary:
	var key: String = "match_completed_money" if is_money_match else "match_completed_free"
	return intent_award_nectar_for_event(key, metadata)

func intent_record_async_completed(metadata: Dictionary = {}) -> Dictionary:
	return intent_award_nectar_for_event("async_completed", metadata)

func intent_record_contest_participation(metadata: Dictionary = {}) -> Dictionary:
	return intent_award_nectar_for_event("contest_participation", metadata)

func intent_record_tournament_participation(metadata: Dictionary = {}) -> Dictionary:
	return intent_award_nectar_for_event("tournament_participation", metadata)

func intent_record_tournament_placement(placement: int, metadata: Dictionary = {}) -> Dictionary:
	var base: int = int(_config.nectar_awards.get("tournament_placement_bonus", 0))
	if base <= 0:
		return {"ok": false, "reason": "placement_bonus_unconfigured"}
	var clamped: int = maxi(1, placement)
	var bonus: int = int(round(float(base) / float(clamped)))
	var meta: Dictionary = metadata.duplicate(true)
	meta["placement"] = clamped
	meta["placement_bonus"] = bonus
	return intent_record_nectar_award("tournament_placement", bonus, meta)

func intent_record_money_match_completed(metadata: Dictionary = {}) -> Dictionary:
	return intent_award_nectar_for_event("money_match_completed", metadata)

func _apply_pass_xp(pass_xp_gain: float) -> Dictionary:
	var gained_levels: Array[int] = []
	var events: Array[Dictionary] = []
	var remaining_gain: float = maxf(0.0, pass_xp_gain)
	var blocked: bool = false
	while remaining_gain > 0.0 and _pass_level < _config.total_levels:
		var req: int = _config.pass_xp_required_for_level(_pass_level + 1)
		var need: float = float(req) - _pass_xp
		if need > 0.0001 and remaining_gain < need:
			_pass_xp += remaining_gain
			remaining_gain = 0.0
			break
		if need > 0.0:
			remaining_gain -= need
		_pass_xp = 0.0
		var next_level: int = _pass_level + 1
		if next_level >= _config.prestige_level_start:
			var preview: Dictionary = _cap_tracker.preview_unlock(next_level)
			if not bool(preview.get("ok", false)):
				_blocked_hard_brick_level = next_level
				blocked = true
				_pass_xp = float(req)
				remaining_gain = 0.0
				events.append({
					"type": "prestige_level_locked",
					"level": next_level,
					"remaining_slots": int(preview.get("remaining", 0))
				})
				break
			var commit: Dictionary = _cap_tracker.commit_unlock(next_level)
			_reward_variant_by_level[str(next_level)] = str(commit.get("variant", "standard"))
		_pass_level = next_level
		_blocked_hard_brick_level = -1
		gained_levels.append(_pass_level)
		events.append({"type": "pass_level_up", "level": _pass_level})
		_append_tier_entry_events(events, _pass_level)
		if _pass_level >= _config.total_levels:
			_pass_xp = 0.0
			remaining_gain = 0.0
			break
	if _pass_level >= _config.total_levels:
		_pass_xp = 0.0
	for event in events:
		pass_event.emit(event)
	return {
		"gained_levels": gained_levels,
		"blocked": blocked,
		"blocked_level": _blocked_hard_brick_level,
		"current_level": _pass_level
	}

func _append_tier_entry_events(events: Array[Dictionary], level: int) -> void:
	if level >= _config.prestige_level_start:
		events.append({"type": "enter_prestige_tier", "level": level})
	if level >= _config.apex_level_start:
		events.append({"type": "enter_apex_tier", "level": level})
		if _pass_tier == PassTier.FREE and not _first_free_apex_announced:
			_first_free_apex_announced = true
			events.append({"type": "first_free_apex_highlight", "level": level})

func _build_level_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for level in range(1, _config.total_levels + 1):
		var key: String = str(level)
		var band: String = "standard"
		if level > _config.standard_level_end and level <= _config.advanced_level_end:
			band = "advanced"
		elif level >= _config.prestige_level_start and level < _config.apex_level_start:
			band = "prestige"
		elif level >= _config.apex_level_start:
			band = "apex"
		var preview: Dictionary = {}
		if level >= _config.prestige_level_start:
			preview = _cap_tracker.preview_unlock(level)
		rows.append({
			"level": level,
			"band": band,
			"xp_required": _config.pass_xp_required_for_level(level),
			"unlocked": level <= _pass_level,
			"reward_variant": str(_reward_variant_by_level.get(key, "standard")),
			"remaining_slots": int(preview.get("remaining", -1)),
			"free_claimed": bool(_claimed_free.get(key, false)),
			"premium_claimed": bool(_claimed_premium.get(key, false)),
			"elite_claimed": bool(_claimed_elite.get(key, false))
		})
	return rows

func _has_async_event_access() -> bool:
	if _pass_tier >= PassTier.ELITE:
		return bool(_config.elite_async_access)
	return false

func _load_config() -> void:
	var loaded_any: Variant = load(CONFIG_PATH)
	if loaded_any is SwarmPassConfigScript:
		_config = loaded_any as SwarmPassConfigScript
	else:
		_config = SwarmPassConfigScript.new()
	_cap_tracker.configure(
		_config.normalized_prestige_model(),
		_config.hard_brick_caps,
		_config.soft_variant_cutoffs
	)

func _reset_or_roll_season_if_needed() -> void:
	var now_unix: int = _now_unix()
	if _season_started_unix > 0 and now_unix < _season_ends_unix:
		return
	var duration_sec: int = maxi(1, _config.season_duration_days) * 86400
	var slot: int = int(floor(float(now_unix) / float(duration_sec)))
	_season_id = "sp_%d" % slot
	_season_started_unix = slot * duration_sec
	_season_ends_unix = _season_started_unix + duration_sec
	_reset_progress_for_new_season()

func _reset_progress_for_new_season() -> void:
	_wallet_nectar = 0
	_pass_tier = PassTier.FREE
	_pass_xp = 0.0
	_pass_level = 1
	_blocked_hard_brick_level = -1
	_reward_variant_by_level.clear()
	_claimed_free.clear()
	_claimed_premium.clear()
	_claimed_elite.clear()
	_tier_achievements_seen.clear()
	_first_free_apex_announced = false
	_cap_tracker.set_unlock_counts({})
	_telemetry.configure_for_season(_season_id)

func _load_saved_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_save_state()
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw_text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = parsed as Dictionary
	var saved_season: String = str(raw.get("season_id", ""))
	if saved_season != _season_id:
		_save_state()
		return
	_season_started_unix = int(raw.get("season_started_unix", _season_started_unix))
	_season_ends_unix = int(raw.get("season_ends_unix", _season_ends_unix))
	_wallet_nectar = maxi(0, int(raw.get("wallet_nectar", 0)))
	_pass_tier = clampi(int(raw.get("pass_tier", PassTier.FREE)), PassTier.FREE, PassTier.ELITE)
	_pass_xp = maxf(0.0, float(raw.get("pass_xp", 0.0)))
	_pass_level = clampi(int(raw.get("pass_level", 1)), 1, _config.total_levels)
	_blocked_hard_brick_level = int(raw.get("blocked_hard_brick_level", -1))
	_reward_variant_by_level = (raw.get("reward_variant_by_level", {}) as Dictionary).duplicate(true)
	_claimed_free = (raw.get("claimed_free", {}) as Dictionary).duplicate(true)
	_claimed_premium = (raw.get("claimed_premium", {}) as Dictionary).duplicate(true)
	_claimed_elite = (raw.get("claimed_elite", {}) as Dictionary).duplicate(true)
	_tier_achievements_seen = (raw.get("tier_achievements_seen", {}) as Dictionary).duplicate(true)
	_first_free_apex_announced = bool(raw.get("first_free_apex_announced", false))
	var unlock_counts: Dictionary = (raw.get("prestige_unlock_counts", {}) as Dictionary).duplicate(true)
	_cap_tracker.set_unlock_counts(unlock_counts)

func _save_state() -> void:
	var payload: Dictionary = {
		"season_id": _season_id,
		"season_started_unix": _season_started_unix,
		"season_ends_unix": _season_ends_unix,
		"wallet_nectar": _wallet_nectar,
		"pass_tier": _pass_tier,
		"pass_xp": _pass_xp,
		"pass_level": _pass_level,
		"blocked_hard_brick_level": _blocked_hard_brick_level,
		"reward_variant_by_level": _reward_variant_by_level,
		"claimed_free": _claimed_free,
		"claimed_premium": _claimed_premium,
		"claimed_elite": _claimed_elite,
		"tier_achievements_seen": _tier_achievements_seen,
		"first_free_apex_announced": _first_free_apex_announced,
		"prestige_unlock_counts": _cap_tracker.unlock_counts()
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))

func _load_telemetry() -> void:
	_telemetry.configure_for_season(_season_id)
	if not FileAccess.file_exists(TELEMETRY_PATH):
		_save_telemetry()
		return
	var f: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw: Dictionary = parsed as Dictionary
	var season: String = str(raw.get("season_id", ""))
	if season != _season_id:
		_save_telemetry()
		return
	_telemetry.import_data(raw)

func _save_telemetry() -> void:
	var payload: Dictionary = _telemetry.export_data()
	payload["season_id"] = _season_id
	var f: FileAccess = FileAccess.open(TELEMETRY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))

func _record_telemetry(nectar_awarded: int) -> void:
	var player_id: String = _resolve_player_id()
	_telemetry.on_progress(
		player_id,
		_tier_name(_pass_tier),
		_pass_level,
		_season_started_unix,
		_now_unix(),
		nectar_awarded
	)
	_save_telemetry()

func _resolve_player_id() -> String:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("get_player_name"):
		var name_any: Variant = profile_manager.call("get_player_name")
		var name: String = str(name_any).strip_edges()
		if name != "":
			return name
	return "local_player"

func _pass_multiplier(tier: int) -> float:
	match tier:
		PassTier.PREMIUM:
			return maxf(1.0, _config.premium_multiplier)
		PassTier.ELITE:
			return maxf(1.0, _config.elite_multiplier)
		_:
			return 1.0

func _tier_name(tier: int) -> String:
	match tier:
		PassTier.PREMIUM:
			return "PREMIUM"
		PassTier.ELITE:
			return "ELITE"
		_:
			return "FREE"

func _tier_from_name(name: String) -> int:
	var key: String = name.strip_edges().to_upper()
	match key:
		"FREE":
			return PassTier.FREE
		"PREMIUM":
			return PassTier.PREMIUM
		"ELITE":
			return PassTier.ELITE
		_:
			return -1

func _emit_changed() -> void:
	var snap: Dictionary = get_snapshot()
	pass_state_changed.emit(snap)

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
