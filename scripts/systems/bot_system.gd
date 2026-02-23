# Authoritative CPU bot ticking; emits intents through OpsState only.
class_name BotSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const BaselineBotPolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")

var state: GameState = null
var policy: RefCounted = BaselineBotPolicyScript.new()
var _next_think_ms_by_seat: Dictionary = {}
var _failed_intent_until_ms: Dictionary = {}
var _swarm_cooldown_until_by_seat: Dictionary = {}

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	_next_think_ms_by_seat.clear()
	_failed_intent_until_ms.clear()
	_swarm_cooldown_until_by_seat.clear()

func tick(_dt: float) -> void:
	if state == null:
		return
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING:
		return
	if OpsState.input_locked:
		return
	if OpsState.has_method("ensure_bot_profiles_from_roster"):
		OpsState.ensure_bot_profiles_from_roster()
	var roster: Array = OpsState.match_roster
	if roster == null or roster.is_empty():
		return
	var team_by_seat: Dictionary = {}
	if OpsState.has_method("get_team_by_seat_snapshot"):
		var team_snapshot_any: Variant = OpsState.call("get_team_by_seat_snapshot")
		if typeof(team_snapshot_any) == TYPE_DICTIONARY:
			team_by_seat = (team_snapshot_any as Dictionary).duplicate(true)
	var now_ms: int = Time.get_ticks_msec()
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		if seat < 1 or seat > 4:
			continue
		var is_cpu: bool = bool(entry.get("is_cpu", false))
		var is_active: bool = bool(entry.get("active", true))
		if not is_cpu or not is_active:
			continue
		var profile: Dictionary = _get_profile_for_seat(seat)
		if profile.is_empty():
			continue
		var allow_swarm_profile: bool = bool(profile.get("allow_swarm", true))
		var swarm_cd_until_ms: int = int(_swarm_cooldown_until_by_seat.get(seat, 0))
		var swarm_ready: bool = now_ms >= swarm_cd_until_ms
		profile["allow_swarm"] = allow_swarm_profile and swarm_ready
		profile["team_by_seat"] = team_by_seat.duplicate(true)
		if OpsState.has_method("get_blocked_wall_pairs"):
			profile["blocked_wall_pairs"] = OpsState.call("get_blocked_wall_pairs")
		if not bool(profile.get("enabled", true)):
			continue
		if not _next_think_ms_by_seat.has(seat):
			var opening_delay_ms: int = maxi(0, int(profile.get("opening_delay_ms", 1400)))
			var opening_stagger_ms: int = maxi(0, int(profile.get("opening_stagger_ms", 120)))
			_next_think_ms_by_seat[seat] = now_ms + opening_delay_ms + ((seat - 1) * opening_stagger_ms)
			continue
		var think_interval_ms: int = _next_think_interval_ms(profile, seat)
		var next_think_ms: int = int(_next_think_ms_by_seat.get(seat, 0))
		if now_ms < next_think_ms:
			continue
		_next_think_ms_by_seat[seat] = now_ms + think_interval_ms
		var max_actions: int = clampi(int(profile.get("max_actions_per_tick", 1)), 1, 4)
		for _i in range(max_actions):
			if policy == null or not policy.has_method("choose_intent"):
				break
			var decision_any: Variant = policy.call("choose_intent", state, seat, profile, now_ms)
			if typeof(decision_any) != TYPE_DICTIONARY:
				break
			var decision: Dictionary = decision_any as Dictionary
			if decision.is_empty():
				break
			var src_id: int = int(decision.get("src", -1))
			var dst_id: int = int(decision.get("dst", -1))
			var intent: String = str(decision.get("intent", ""))
			if src_id <= 0 or dst_id <= 0:
				break
			if intent != "attack" and intent != "feed" and intent != "swarm":
				break
			var cooldown_key: String = _cooldown_key(seat, src_id, dst_id, intent)
			var retry_after_ms: int = int(_failed_intent_until_ms.get(cooldown_key, 0))
			if now_ms < retry_after_ms:
				continue
			var result: Dictionary = OpsState.apply_lane_intent(src_id, dst_id, intent)
			var ok: bool = bool(result.get("ok", false))
			var reason: String = str(result.get("reason", ""))
			SFLog.warn("BOT_INTENT", {
				"seat": seat,
				"src": src_id,
				"dst": dst_id,
				"intent": intent,
				"ok": ok,
				"reason": reason,
				"score": float(decision.get("score", 0.0)),
				"policy": str(decision.get("policy", "baseline_v1"))
			})
			if ok:
				var pair_cooldown_ms: int = maxi(250, int(profile.get("pair_intent_cooldown_ms", 1200)))
				var pair_until_ms: int = now_ms + pair_cooldown_ms
				_apply_pair_cooldown(seat, src_id, dst_id, pair_until_ms)
				if intent == "swarm":
					var swarm_pair_cooldown_ms: int = maxi(250, int(profile.get("swarm_cooldown_ms", 1600)))
					_failed_intent_until_ms[cooldown_key] = maxi(int(_failed_intent_until_ms.get(cooldown_key, 0)), now_ms + swarm_pair_cooldown_ms)
					var swarm_global_cooldown_ms: int = maxi(500, int(profile.get("swarm_global_cooldown_ms", 3500)))
					_swarm_cooldown_until_by_seat[seat] = now_ms + swarm_global_cooldown_ms
				var global_cooldown_ms: int = maxi(0, int(profile.get("global_intent_cooldown_ms", 900)))
				if global_cooldown_ms > 0:
					var global_until_ms: int = now_ms + global_cooldown_ms
					var planned_after_global: int = int(_next_think_ms_by_seat.get(seat, 0))
					if global_until_ms > planned_after_global:
						_next_think_ms_by_seat[seat] = global_until_ms
				var post_intent_delay_ms: int = maxi(0, int(profile.get("post_intent_delay_ms", 0)))
				if post_intent_delay_ms > 0:
					var delayed_until_ms: int = now_ms + post_intent_delay_ms
					var planned_next_think_ms: int = int(_next_think_ms_by_seat.get(seat, 0))
					if delayed_until_ms > planned_next_think_ms:
						_next_think_ms_by_seat[seat] = delayed_until_ms
				continue
			var retry_block_ms: int = maxi(200, int(profile.get("retry_block_ms", 900)))
			if reason == "no_lane":
				var no_lane_retry_ms: int = maxi(retry_block_ms, int(profile.get("no_lane_retry_ms", 2800)))
				var until_ms: int = now_ms + no_lane_retry_ms
				_apply_pair_cooldown(seat, src_id, dst_id, until_ms)
			else:
				_failed_intent_until_ms[cooldown_key] = now_ms + retry_block_ms
			if reason == "budget" or reason == "ownership":
				break

func _get_profile_for_seat(seat: int) -> Dictionary:
	if OpsState.has_method("get_bot_profile"):
		var profile_any: Variant = OpsState.call("get_bot_profile", seat)
		if typeof(profile_any) == TYPE_DICTIONARY:
			return (profile_any as Dictionary).duplicate(true)
	return {}

func _cooldown_key(seat: int, src_id: int, dst_id: int, intent: String) -> String:
	return "%d|%d|%d|%s" % [seat, src_id, dst_id, intent]

func _apply_pair_cooldown(seat: int, src_id: int, dst_id: int, until_ms: int) -> void:
	for intent_name in ["attack", "feed", "swarm"]:
		_failed_intent_until_ms[_cooldown_key(seat, src_id, dst_id, intent_name)] = until_ms
		_failed_intent_until_ms[_cooldown_key(seat, dst_id, src_id, intent_name)] = until_ms

func _next_think_interval_ms(profile: Dictionary, seat: int) -> int:
	var base_ms: int = maxi(100, int(profile.get("think_interval_ms", 420)))
	var jitter_ms: int = maxi(0, int(profile.get("think_jitter_ms", 0)))
	if jitter_ms <= 0:
		return base_ms
	var tick: int = int(state.tick) if state != null else 0
	var hash_value: int = abs((tick + 1) * 1103515245 + seat * 12345 + 97)
	var jitter_span: int = jitter_ms * 2 + 1
	var offset: int = int(hash_value % jitter_span) - jitter_ms
	return maxi(100, base_ms + offset)
