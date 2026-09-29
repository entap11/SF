class_name BotRunner
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")
const DETERMINISTIC_VARIANT := preload("res://scripts/util/deterministic_variant.gd")
const BotActionScript := preload("res://scripts/bot/bot_action.gd")
const BotDecisionScript := preload("res://scripts/bot/bot_decision.gd")
const BotCommandGatewayScript := preload("res://scripts/bot/bot_command_gateway.gd")
const BaselineBotPolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")
const BotCounterRngScript := preload("res://scripts/bot/bot_counter_rng.gd")
const BotObservationBuilderScript := preload("res://scripts/bot/bot_observation_builder.gd")
const BotEventDetectorScript := preload("res://scripts/bot/bot_event_detector.gd")

const RUNTIME_SCHEMA_VERSION: int = 1
const MATCH_PHASE_RUNNING: int = 1
const MAX_RUNTIME_COOLDOWNS_PER_SEAT: int = 192
const MAX_REACTIONS_PER_SEAT: int = 64

var policy: RefCounted = BaselineBotPolicyScript.new()
var state: GameState = null
var execution_enabled: bool = true
var persist_runtime_state: bool = true
var policy_version_override: String = ""

var _ops_state: Object = null
var _gateway: RefCounted = BotCommandGatewayScript.new()
var _runtime_by_seat: Dictionary = {}
var _observation_builder: RefCounted = BotObservationBuilderScript.new()
var _event_detector: RefCounted = BotEventDetectorScript.new()


func bind_state(state_ref: GameState, ops_state_ref: Object) -> void:
	state = state_ref
	_ops_state = ops_state_ref
	_gateway.call("bind", state_ref, ops_state_ref)
	_runtime_by_seat.clear()
	if persist_runtime_state and _ops_state != null and _ops_state.has_method("get_bot_runtime_snapshot"):
		var restored_any: Variant = _ops_state.call("get_bot_runtime_snapshot")
		if typeof(restored_any) == TYPE_DICTIONARY:
			var restored: Dictionary = restored_any as Dictionary
			var seats_any: Variant = restored.get("by_seat", {})
			if typeof(seats_any) == TYPE_DICTIONARY:
				_runtime_by_seat = (seats_any as Dictionary).duplicate(true)
	_sync_runtime_store()


func reset_runtime() -> void:
	_runtime_by_seat.clear()
	_sync_runtime_store()


func step() -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	if state == null or _ops_state == null:
		return outcomes
	if int(_ops_state.get("match_phase")) != MATCH_PHASE_RUNNING:
		return outcomes
	if bool(_ops_state.get("input_locked")):
		return outcomes
	if _ops_state.has_method("ensure_bot_profiles_from_roster"):
		_ops_state.call("ensure_bot_profiles_from_roster")
	var roster_any: Variant = _ops_state.get("match_roster")
	if typeof(roster_any) != TYPE_ARRAY:
		return outcomes
	var roster: Array = roster_any as Array
	if roster.is_empty():
		return outcomes
	var team_by_seat: Dictionary = _team_by_seat_snapshot()
	var now_ms: int = _simulation_time_ms()
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var seat: int = int(entry.get("seat", 0))
		if seat < 1 or seat > 4:
			continue
		if not bool(entry.get("is_cpu", false)) or not bool(entry.get("active", true)):
			continue
		var profile: Dictionary = _profile_for_seat(seat)
		if profile.is_empty() or not bool(profile.get("enabled", true)):
			continue
		if not policy_version_override.is_empty():
			profile["policy"] = policy_version_override
		var runtime: Dictionary = _runtime_for_seat(seat, profile, now_ms)
		var frozen_profile_any: Variant = runtime.get("resolved_profile", profile)
		if typeof(frozen_profile_any) == TYPE_DICTIONARY:
			profile = (frozen_profile_any as Dictionary).duplicate(true)
		var initialized_now: bool = bool(runtime.get("initialized_now", false))
		runtime.erase("initialized_now")
		if initialized_now:
			_store_runtime(seat, runtime)
			continue
		if now_ms < int(runtime.get("next_think_ms", 0)):
			_store_runtime(seat, runtime)
			continue
		var decision_outcomes: Array[Dictionary] = []
		if str(profile.get("policy", "baseline_v2")) == "adaptive_v3.0":
			decision_outcomes = _run_adaptive_v3_0(seat, profile, team_by_seat, runtime, now_ms)
		else:
			decision_outcomes = _run_decisions_for_seat(seat, profile, team_by_seat, runtime, now_ms)
		outcomes.append_array(decision_outcomes)
		_store_runtime(seat, runtime)
	_prune_inactive_seats(roster)
	_sync_runtime_store()
	return outcomes


func export_runtime_state() -> Dictionary:
	return {
		"schema_version": RUNTIME_SCHEMA_VERSION,
		"by_seat": _runtime_by_seat.duplicate(true),
		"runtime_hash": DETERMINISTIC_VARIANT.hash_variant(_runtime_by_seat)
	}


func import_runtime_state(snapshot: Dictionary) -> bool:
	if int(snapshot.get("schema_version", 0)) != RUNTIME_SCHEMA_VERSION:
		return false
	var seats_any: Variant = snapshot.get("by_seat", {})
	if typeof(seats_any) != TYPE_DICTIONARY:
		return false
	var expected_hash: String = str(snapshot.get("runtime_hash", ""))
	if not expected_hash.is_empty() and expected_hash != DETERMINISTIC_VARIANT.hash_variant(seats_any):
		return false
	_runtime_by_seat = (seats_any as Dictionary).duplicate(true)
	_sync_runtime_store()
	return true


func _run_decisions_for_seat(
	seat: int,
	base_profile: Dictionary,
	team_by_seat: Dictionary,
	runtime: Dictionary,
	now_ms: int
) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var profile: Dictionary = base_profile.duplicate(true)
	profile["_frozen_profile_hash"] = str(runtime.get("decision_profile_hash", ""))
	var allow_swarm_profile: bool = bool(profile.get("allow_swarm", true))
	profile["allow_swarm"] = allow_swarm_profile and now_ms >= int(runtime.get("swarm_cooldown_until_ms", 0))
	profile["team_by_seat"] = team_by_seat.duplicate(true)
	if _ops_state.has_method("get_blocked_wall_pairs"):
		profile["blocked_wall_pairs"] = _ops_state.call("get_blocked_wall_pairs")
	var think_interval_ms: int = _next_think_interval_ms(
		profile,
		seat,
		int(runtime.get("decision_sequence", 0)),
		str(runtime.get("decision_profile_hash", ""))
	)
	runtime["next_think_ms"] = now_ms + think_interval_ms
	var max_actions: int = clampi(int(profile.get("max_actions_per_tick", 1)), 1, 4)
	for _action_index in range(max_actions):
		if policy == null or not policy.has_method("choose_intent"):
			break
		var decision_id: int = int(runtime.get("decision_sequence", 0)) + 1
		runtime["decision_sequence"] = decision_id
		var raw_any: Variant = policy.call("choose_intent", state, seat, profile, now_ms)
		if typeof(raw_any) != TYPE_DICTIONARY:
			outcomes.append(BotDecisionScript.defer({"reason": "policy_result_type", "decision_id": decision_id}))
			break
		var raw: Dictionary = raw_any as Dictionary
		if raw.is_empty():
			outcomes.append(BotDecisionScript.defer({"reason": "no_candidate", "decision_id": decision_id}))
			break
		var policy_version: String = str(raw.get("policy", profile.get("policy", "baseline_v2")))
		var action: Dictionary = BotActionScript.from_policy_intent(
			raw,
			seat,
			decision_id,
			int(state.tick),
			policy_version
		)
		if action.is_empty():
			outcomes.append(BotDecisionScript.defer({"reason": "invalid_policy_action", "decision_id": decision_id}))
			break
		var cooldown_key: String = _cooldown_key(
			seat,
			int(action.get("src_id", -1)),
			int(action.get("dst_id", -1)),
			str(action.get("route_intent", ""))
		)
		var failed_until: Dictionary = runtime.get("failed_intent_until_ms", {}) as Dictionary
		if now_ms < int(failed_until.get(cooldown_key, 0)):
			outcomes.append(BotDecisionScript.defer({"reason": "pair_cooldown", "decision_id": decision_id}))
			continue
		var decision: Dictionary = BotDecisionScript.act(action, {
			"score": float(raw.get("score", 0.0)),
			"style": str(profile.get("style", profile.get("persona", ""))),
			"tier": str(profile.get("tier", "medium"))
		})
		var result: Dictionary = _execute_action(action)
		decision["result"] = result.duplicate(true)
		outcomes.append(decision)
		_log_action(action, raw, profile, result)
		_update_runtime_after_result(runtime, profile, action, result, now_ms)
		if not bool(result.get("ok", false)):
			var reason: String = str(result.get("reason", ""))
			if reason == "budget" or reason == "ownership":
				break
	return outcomes


func _run_adaptive_v3_0(
	seat: int,
	base_profile: Dictionary,
	team_by_seat: Dictionary,
	runtime: Dictionary,
	now_ms: int
) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var profile: Dictionary = base_profile.duplicate(true)
	profile["_frozen_profile_hash"] = str(runtime.get("decision_profile_hash", ""))
	profile["team_by_seat"] = team_by_seat.duplicate(true)
	if _ops_state.has_method("get_blocked_wall_pairs"):
		profile["blocked_wall_pairs"] = _ops_state.call("get_blocked_wall_pairs")
	var think_interval_ms: int = _next_think_interval_ms(
		profile,
		seat,
		int(runtime.get("decision_sequence", 0)),
		str(runtime.get("decision_profile_hash", ""))
	)
	runtime["next_think_ms"] = now_ms + think_interval_ms
	var observation: Dictionary = _observation_builder.call("build", state, seat, _ops_state) as Dictionary
	if observation.is_empty():
		outcomes.append(BotDecisionScript.defer({"reason": "observation_missing"}))
		return outcomes
	runtime["observation_sequence"] = int(runtime.get("observation_sequence", 0)) + 1
	runtime["observation_cursor_tick"] = int(observation.get("observation_tick", -1))
	var previous: Dictionary = runtime.get("last_observation", {}) as Dictionary
	var first_event_id: int = int(runtime.get("event_sequence", 0)) + 1
	var events: Array[Dictionary] = _event_detector.call(
		"detect",
		previous,
		observation,
		profile,
		first_event_id
	) as Array[Dictionary]
	_enqueue_reactions(runtime, profile, events)
	if not events.is_empty():
		runtime["event_sequence"] = int((events[events.size() - 1] as Dictionary).get("event_id", first_event_id))
	runtime["last_observation"] = observation.duplicate(true)

	if bool(runtime.get("reallocation_pending", false)):
		return _run_adaptive_reallocation(seat, profile, runtime, now_ms)

	var queue: Array = runtime.get("reaction_queue", []) as Array
	while not queue.is_empty():
		var reaction: Dictionary = queue[0] as Dictionary
		var ready_ms: int = int(reaction.get("ready_time_ms", 0))
		if now_ms < ready_ms:
			runtime["next_think_ms"] = mini(int(runtime.get("next_think_ms", ready_ms)), ready_ms)
			outcomes.append(BotDecisionScript.defer({
				"reason": "reaction_pending",
				"event_id": int(reaction.get("event_id", 0)),
				"ready_time_ms": ready_ms
			}))
			runtime["reaction_queue"] = queue
			return outcomes
		queue.remove_at(0)
		if str(reaction.get("kind", "")) != BotEventDetectorScript.ROUTE_BECAME_LOSING:
			continue
		var src_id: int = int(reaction.get("src_id", -1))
		var dst_id: int = int(reaction.get("dst_id", -1))
		if not bool(_event_detector.call("route_is_losing", observation, src_id, dst_id, profile)):
			continue
		var decision_id: int = int(runtime.get("decision_sequence", 0)) + 1
		runtime["decision_sequence"] = decision_id
		var action: Dictionary = BotActionScript.retract(
			seat,
			src_id,
			dst_id,
			decision_id,
			int(state.tick),
			"adaptive_v3.0",
			"",
			BotEventDetectorScript.ROUTE_BECAME_LOSING
		)
		var result: Dictionary = _execute_action(action)
		var decision: Dictionary = BotDecisionScript.act(action, {
			"trigger": BotEventDetectorScript.ROUTE_BECAME_LOSING,
			"event_id": int(reaction.get("event_id", 0)),
			"evidence": (reaction.get("evidence", {}) as Dictionary).duplicate(true)
		})
		decision["result"] = result.duplicate(true)
		outcomes.append(decision)
		_log_action(action, {"score": 0.0}, profile, result)
		if bool(result.get("ok", false)):
			runtime["reallocation_pending"] = true
			runtime["retracted_src_id"] = src_id
			runtime["retracted_dst_id"] = dst_id
			runtime["retracted_at_tick"] = int(state.tick)
			runtime["next_think_ms"] = now_ms + maxi(250, int(profile.get("adaptive_reallocation_delay_ms", 700)))
			var failed_until: Dictionary = runtime.get("failed_intent_until_ms", {}) as Dictionary
			_apply_pair_cooldown(
				failed_until,
				seat,
				src_id,
				dst_id,
				now_ms + maxi(1000, int(profile.get("adaptive_retract_target_cooldown_ms", 6000)))
			)
			runtime["failed_intent_until_ms"] = _bounded_cooldowns(failed_until)
		else:
			_update_runtime_after_result(runtime, profile, action, result, now_ms)
		runtime["reaction_queue"] = queue
		return outcomes
	runtime["reaction_queue"] = queue
	return _run_adaptive_baseline_fallback(seat, profile, runtime, now_ms)


func _run_adaptive_baseline_fallback(
	seat: int,
	profile: Dictionary,
	runtime: Dictionary,
	now_ms: int
) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var decision_id: int = int(runtime.get("decision_sequence", 0)) + 1
	runtime["decision_sequence"] = decision_id
	profile["allow_swarm"] = (
		bool(profile.get("allow_swarm", true))
		and now_ms >= int(runtime.get("swarm_cooldown_until_ms", 0))
	)
	profile["decision_seed"] = BotCounterRngScript.sample_u32(
		_bot_match_seed(),
		"adaptive_v3.0",
		str(runtime.get("decision_profile_hash", "")),
		seat,
		decision_id,
		"baseline_fallback_v1"
	) % 1000000
	var raw_any: Variant = policy.call("choose_intent", state, seat, profile, now_ms) if policy != null else {}
	if typeof(raw_any) != TYPE_DICTIONARY or (raw_any as Dictionary).is_empty():
		outcomes.append(BotDecisionScript.defer({
			"reason": "baseline_fallback_no_candidate",
			"fallback": "baseline_v2",
			"decision_id": decision_id
		}))
		return outcomes
	var raw: Dictionary = (raw_any as Dictionary).duplicate(true)
	raw["policy"] = "adaptive_v3.0"
	raw["trigger_code"] = "baseline_fallback_v1"
	var action: Dictionary = BotActionScript.from_policy_intent(
		raw,
		seat,
		decision_id,
		int(state.tick),
		"adaptive_v3.0"
	)
	if action.is_empty():
		outcomes.append(BotDecisionScript.defer({"reason": "baseline_fallback_invalid_action"}))
		return outcomes
	var cooldown_key: String = _cooldown_key(
		seat,
		int(action.get("src_id", -1)),
		int(action.get("dst_id", -1)),
		str(action.get("route_intent", ""))
	)
	var failed_until: Dictionary = runtime.get("failed_intent_until_ms", {}) as Dictionary
	if now_ms < int(failed_until.get(cooldown_key, 0)):
		outcomes.append(BotDecisionScript.defer({
			"reason": "baseline_fallback_pair_cooldown",
			"decision_id": decision_id
		}))
		return outcomes
	var result: Dictionary = _execute_action(action)
	var decision: Dictionary = BotDecisionScript.act(action, {
		"trigger": "baseline_fallback_v1",
		"fallback": "baseline_v2",
		"score": float(raw.get("score", 0.0))
	})
	decision["result"] = result.duplicate(true)
	outcomes.append(decision)
	_log_action(action, raw, profile, result)
	_update_runtime_after_result(runtime, profile, action, result, now_ms)
	return outcomes


func _run_adaptive_reallocation(
	seat: int,
	profile: Dictionary,
	runtime: Dictionary,
	now_ms: int
) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var retracted_src: int = int(runtime.get("retracted_src_id", -1))
	var retracted_dst: int = int(runtime.get("retracted_dst_id", -1))
	var blocked_pairs: Array = profile.get("blocked_wall_pairs", []) as Array
	blocked_pairs = blocked_pairs.duplicate(true)
	blocked_pairs.append([retracted_src, retracted_dst])
	profile["blocked_wall_pairs"] = blocked_pairs
	profile["allow_swarm"] = false
	var decision_id: int = int(runtime.get("decision_sequence", 0)) + 1
	runtime["decision_sequence"] = decision_id
	profile["decision_seed"] = BotCounterRngScript.sample_u32(
		_bot_match_seed(),
		"adaptive_v3.0",
		str(runtime.get("decision_profile_hash", "")),
		seat,
		decision_id,
		"reallocation_candidate"
	) % 1000000
	var raw_any: Variant = policy.call("choose_intent", state, seat, profile, now_ms) if policy != null else {}
	if typeof(raw_any) != TYPE_DICTIONARY or (raw_any as Dictionary).is_empty():
		outcomes.append(BotDecisionScript.defer({
			"reason": "reallocation_candidate_missing",
			"decision_id": decision_id
		}))
		return outcomes
	var raw: Dictionary = (raw_any as Dictionary).duplicate(true)
	raw["policy"] = "adaptive_v3.0"
	raw["trigger_code"] = "capacity_reallocated"
	var action: Dictionary = BotActionScript.from_policy_intent(
		raw,
		seat,
		decision_id,
		int(state.tick),
		"adaptive_v3.0"
	)
	if action.is_empty():
		outcomes.append(BotDecisionScript.defer({"reason": "invalid_reallocation_action"}))
		return outcomes
	var result: Dictionary = _execute_action(action)
	var decision: Dictionary = BotDecisionScript.act(action, {
		"trigger": "capacity_reallocated",
		"retracted_src_id": retracted_src,
		"retracted_dst_id": retracted_dst,
		"score": float(raw.get("score", 0.0))
	})
	decision["result"] = result.duplicate(true)
	outcomes.append(decision)
	_log_action(action, raw, profile, result)
	_update_runtime_after_result(runtime, profile, action, result, now_ms)
	if bool(result.get("ok", false)):
		runtime["reallocation_pending"] = false
		runtime["last_reallocation_tick"] = int(state.tick)
	return outcomes


func _runtime_for_seat(seat: int, profile: Dictionary, now_ms: int) -> Dictionary:
	var runtime_any: Variant = _runtime_by_seat.get(seat, _runtime_by_seat.get(str(seat), {}))
	if typeof(runtime_any) == TYPE_DICTIONARY and not (runtime_any as Dictionary).is_empty():
		return (runtime_any as Dictionary).duplicate(true)
	var opening_delay_ms: int = maxi(0, int(profile.get("opening_delay_ms", 1400)))
	var opening_stagger_ms: int = maxi(0, int(profile.get("opening_stagger_ms", 120)))
	var profile_hash: String = _decision_profile_hash(profile)
	return {
		"schema_version": RUNTIME_SCHEMA_VERSION,
		"seat": seat,
		"policy_version": str(profile.get("policy", "baseline_v2")),
		"profile_id": "%s:%s" % [
			str(profile.get("style", profile.get("persona", "balancer"))),
			str(profile.get("tier", "medium"))
		],
		"decision_profile_hash": profile_hash,
		"resolved_profile": profile.duplicate(true),
		"match_seed": _bot_match_seed(),
		"rng_version": BotCounterRngScript.RNG_VERSION,
		"rng_counters": {},
		"decision_sequence": 0,
		"next_think_ms": now_ms + opening_delay_ms + ((seat - 1) * opening_stagger_ms),
		"failed_intent_until_ms": {},
		"swarm_cooldown_until_ms": 0,
		"reaction_queue": [],
		"observation_sequence": 0,
		"observation_cursor_tick": -1,
		"event_sequence": 0,
		"event_cursor": 0,
		"last_observation": {},
		"posture": "",
		"goal": {},
		"plan": {},
		"plan_step_cursor": 0,
		"opponent_model": {},
		"reallocation_pending": false,
		"initialized_now": true
	}


func _update_runtime_after_result(
	runtime: Dictionary,
	profile: Dictionary,
	action: Dictionary,
	result: Dictionary,
	now_ms: int
) -> void:
	var seat: int = int(action.get("seat", 0))
	var src_id: int = int(action.get("src_id", -1))
	var dst_id: int = int(action.get("dst_id", -1))
	var intent: String = str(action.get("route_intent", ""))
	var cooldown_key: String = _cooldown_key(seat, src_id, dst_id, intent)
	var failed_until: Dictionary = runtime.get("failed_intent_until_ms", {}) as Dictionary
	if bool(result.get("ok", false)):
		var pair_cooldown_ms: int = maxi(250, int(profile.get("pair_intent_cooldown_ms", 1200)))
		_apply_pair_cooldown(failed_until, seat, src_id, dst_id, now_ms + pair_cooldown_ms)
		if intent == "swarm":
			var swarm_pair_ms: int = maxi(250, int(profile.get("swarm_cooldown_ms", 1600)))
			failed_until[cooldown_key] = maxi(int(failed_until.get(cooldown_key, 0)), now_ms + swarm_pair_ms)
			var swarm_global_ms: int = maxi(500, int(profile.get("swarm_global_cooldown_ms", 3500)))
			runtime["swarm_cooldown_until_ms"] = now_ms + swarm_global_ms
		var global_ms: int = maxi(0, int(profile.get("global_intent_cooldown_ms", 900)))
		if global_ms > 0:
			runtime["next_think_ms"] = maxi(int(runtime.get("next_think_ms", 0)), now_ms + global_ms)
		var post_ms: int = maxi(0, int(profile.get("post_intent_delay_ms", 0)))
		if post_ms > 0:
			runtime["next_think_ms"] = maxi(int(runtime.get("next_think_ms", 0)), now_ms + post_ms)
	else:
		var retry_ms: int = maxi(200, int(profile.get("retry_block_ms", 900)))
		if str(result.get("reason", "")) == "no_lane":
			retry_ms = maxi(retry_ms, int(profile.get("no_lane_retry_ms", 2800)))
			_apply_pair_cooldown(failed_until, seat, src_id, dst_id, now_ms + retry_ms)
		else:
			failed_until[cooldown_key] = now_ms + retry_ms
	runtime["failed_intent_until_ms"] = _bounded_cooldowns(failed_until)


func _profile_for_seat(seat: int) -> Dictionary:
	if _ops_state.has_method("get_bot_profile"):
		var profile_any: Variant = _ops_state.call("get_bot_profile", seat)
		if typeof(profile_any) == TYPE_DICTIONARY:
			return (profile_any as Dictionary).duplicate(true)
	return {}


func _team_by_seat_snapshot() -> Dictionary:
	if _ops_state.has_method("get_team_by_seat_snapshot"):
		var team_any: Variant = _ops_state.call("get_team_by_seat_snapshot")
		if typeof(team_any) == TYPE_DICTIONARY:
			return (team_any as Dictionary).duplicate(true)
	return {}


func _simulation_time_ms() -> int:
	if state == null:
		return 0
	return maxi(0, int(int(state.get("_sim_time_us")) / 1000))


func _next_think_interval_ms(
	profile: Dictionary,
	seat: int,
	decision_sequence: int,
	profile_hash: String
) -> int:
	var base_ms: int = maxi(100, int(profile.get("think_interval_ms", 420)))
	var jitter_ms: int = maxi(0, int(profile.get("think_jitter_ms", 0)))
	if jitter_ms <= 0:
		return base_ms
	var offset: int = BotCounterRngScript.range_inclusive(
		-jitter_ms,
		jitter_ms,
		_bot_match_seed(),
		str(profile.get("policy", "baseline_v2")),
		profile_hash,
		seat,
		decision_sequence,
		"think_interval"
	)
	return maxi(100, base_ms + offset)


func _bot_match_seed() -> int:
	if _ops_state != null and _ops_state.has_method("get_bot_match_seed"):
		return int(_ops_state.call("get_bot_match_seed"))
	return 0


func _execute_action(action: Dictionary) -> Dictionary:
	if execution_enabled:
		return _gateway.call("execute", action) as Dictionary
	return {
		"ok": true,
		"reason": "shadow_only",
		"applied": false,
		"shadow_only": true,
		"canonical_payload": _gateway.call("canonical_payload", action) as Dictionary,
		"action_fingerprint": BotActionScript.fingerprint(action)
	}


func _enqueue_reactions(runtime: Dictionary, profile: Dictionary, events: Array[Dictionary]) -> void:
	var queue: Array = runtime.get("reaction_queue", []) as Array
	for event in events:
		var reaction: Dictionary = event.duplicate(true)
		reaction["ready_time_ms"] = int(event.get("observed_time_ms", 0)) + _reaction_delay_ms(
			profile,
			int(event.get("event_id", 0))
		)
		queue.append(reaction)
	queue.sort_custom(func(a_any: Variant, b_any: Variant) -> bool:
		var a: Dictionary = a_any as Dictionary
		var b: Dictionary = b_any as Dictionary
		var a_ready: int = int(a.get("ready_time_ms", 0))
		var b_ready: int = int(b.get("ready_time_ms", 0))
		if a_ready != b_ready:
			return a_ready < b_ready
		return int(a.get("event_id", 0)) < int(b.get("event_id", 0))
	)
	if queue.size() > MAX_REACTIONS_PER_SEAT:
		queue.resize(MAX_REACTIONS_PER_SEAT)
	runtime["reaction_queue"] = queue


func _reaction_delay_ms(profile: Dictionary, event_id: int) -> int:
	var tier: String = str(profile.get("tier", "medium"))
	var default_delay: int = 950
	match tier:
		"easy":
			default_delay = 1450
		"hard", "expert":
			default_delay = 700
	var base_ms: int = maxi(400, int(profile.get("adaptive_reaction_delay_ms", default_delay)))
	var jitter_ms: int = maxi(0, int(profile.get("adaptive_reaction_jitter_ms", 180)))
	return maxi(400, base_ms + BotCounterRngScript.range_inclusive(
		-jitter_ms,
		jitter_ms,
		_bot_match_seed(),
		str(profile.get("policy", "adaptive_v3.0")),
		str(profile.get("_frozen_profile_hash", _decision_profile_hash(profile))),
		int(profile.get("seat", 0)),
		event_id,
		"reaction_delay:route_became_losing"
	))


func _decision_profile_hash(profile: Dictionary) -> String:
	var payload: Dictionary = profile.duplicate(true)
	for non_decision_key in [
		"team_by_seat", "blocked_wall_pairs", "display_name", "actor_label",
		"target_label", "telemetry_label", "_frozen_profile_hash"
	]:
		payload.erase(non_decision_key)
	return DETERMINISTIC_VARIANT.hash_variant(payload)


func _store_runtime(seat: int, runtime: Dictionary) -> void:
	_runtime_by_seat.erase(str(seat))
	_runtime_by_seat[seat] = runtime.duplicate(true)


func _sync_runtime_store() -> void:
	if persist_runtime_state and _ops_state != null and _ops_state.has_method("store_bot_runtime_from_runner"):
		_ops_state.call("store_bot_runtime_from_runner", export_runtime_state())


func _prune_inactive_seats(roster: Array) -> void:
	var active_cpu: Dictionary = {}
	for entry_any in roster:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		if bool(entry.get("is_cpu", false)) and bool(entry.get("active", true)):
			active_cpu[int(entry.get("seat", 0))] = true
	for seat_any in _runtime_by_seat.keys():
		if not active_cpu.has(int(seat_any)):
			_runtime_by_seat.erase(seat_any)


func _bounded_cooldowns(cooldowns: Dictionary) -> Dictionary:
	if cooldowns.size() <= MAX_RUNTIME_COOLDOWNS_PER_SEAT:
		return cooldowns
	var rows: Array[Dictionary] = []
	for key_any in cooldowns.keys():
		rows.append({"key": str(key_any), "until_ms": int(cooldowns.get(key_any, 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_until: int = int(a.get("until_ms", 0))
		var b_until: int = int(b.get("until_ms", 0))
		if a_until != b_until:
			return a_until > b_until
		return str(a.get("key", "")) < str(b.get("key", ""))
	)
	var out: Dictionary = {}
	for index in range(mini(rows.size(), MAX_RUNTIME_COOLDOWNS_PER_SEAT)):
		var row: Dictionary = rows[index] as Dictionary
		out[str(row.get("key", ""))] = int(row.get("until_ms", 0))
	return out


func _cooldown_key(seat: int, src_id: int, dst_id: int, intent: String) -> String:
	return "%d|%d|%d|%s" % [seat, src_id, dst_id, intent]


func _apply_pair_cooldown(
	cooldowns: Dictionary,
	seat: int,
	src_id: int,
	dst_id: int,
	until_ms: int
) -> void:
	for intent_name in ["attack", "feed", "swarm"]:
		cooldowns[_cooldown_key(seat, src_id, dst_id, intent_name)] = until_ms
		cooldowns[_cooldown_key(seat, dst_id, src_id, intent_name)] = until_ms


func _log_action(action: Dictionary, raw: Dictionary, profile: Dictionary, result: Dictionary) -> void:
	var log_tag: String = "BOT_SHADOW_DECISION" if bool(result.get("shadow_only", false)) else "BOT_INTENT"
	SFLog.warn(log_tag, {
		"seat": int(action.get("seat", 0)),
		"src": int(action.get("src_id", -1)),
		"dst": int(action.get("dst_id", -1)),
		"intent": str(action.get("route_intent", "")),
		"ok": bool(result.get("ok", false)),
		"reason": str(result.get("reason", "")),
		"score": float(raw.get("score", 0.0)),
		"policy": str(action.get("policy_version", "baseline_v2")),
		"style": str(profile.get("style", profile.get("persona", ""))),
		"tier": str(profile.get("tier", "medium")),
		"decision_id": int(action.get("decision_id", 0)),
		"action_fingerprint": str(result.get("action_fingerprint", "")),
		"shadow_only": bool(result.get("shadow_only", false))
	})
