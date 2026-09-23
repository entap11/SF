# Simulation-owned CPU controller. Persistent runtime belongs to OpsState.
class_name BotSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")
const BaselineBotPolicyScript := preload("res://scripts/bot/baseline_bot_policy.gd")
const BotRandom := preload("res://scripts/bot/bot_random.gd")
const BotCommand := preload("res://scripts/bot/bot_command.gd")

const BotObservation := preload("res://scripts/bot/bot_observation.gd")
const HumanPolicy := preload("res://scripts/bot/human_bot_policy.gd")

var _human_policy: RefCounted = HumanPolicy.new()

signal decision_event(event: Dictionary)

var state: GameState = null
var policy: RefCounted = BaselineBotPolicyScript.new()

func bind_state(state_ref: GameState) -> void:
	# Rebinding must not discard schedules restored from an authority snapshot.
	state = state_ref

func tick(_dt: float) -> void:
	if state == null or state != OpsState.state:
		return
	if OpsState.match_phase != OpsState.MatchPhase.RUNNING or OpsState.input_locked or OpsState.match_clock_paused:
		return
	OpsState.ensure_bot_profiles_from_roster()
	var now_ms: int = int(state._sim_time_us / 1000)
	var teams: Dictionary = OpsState.get_team_by_seat_snapshot()
	var seats: Array = []
	for entry in OpsState.match_roster:
		if typeof(entry) == TYPE_DICTIONARY and bool(entry.get("is_cpu", false)) and bool(entry.get("active", true)):
			var seat := int(entry.get("seat", 0))
			if seat >= 1 and seat <= 4 and not seats.has(seat):
				seats.append(seat)
	seats.sort()
	for seat_any in seats:
		var seat := int(seat_any)
		var configured: Dictionary = OpsState.get_bot_profile(seat)
		if not bool(configured.get("enabled", true)):
			continue
		if _human_enabled(configured):
			configured["policy"] = "human_balancer_v3"
			configured.merge(configured.get("human_timing", {}), true)
		if not OpsState.bot_runtime_by_seat.has(seat):
			OpsState.bot_runtime_by_seat[seat] = {
				"profile": configured.duplicate(true), "decision_index": 0,
				"next_think_ms": now_ms + maxi(0, int(configured.get("opening_delay_ms", 1400))) + (seat - 1) * maxi(0, int(configured.get("opening_stagger_ms", 120))),
				"blocked": {}, "swarm_until_ms": 0, "pending_action": {}, "memory": {}
			}
			_emit_event(seat, "started", now_ms, {"seed": OpsState.bot_match_seed, "profile": configured.duplicate(true)})
		var runtime: Dictionary = OpsState.bot_runtime_by_seat[seat]
		var profile: Dictionary = (runtime["profile"] as Dictionary).duplicate(true)
		profile["team_by_seat"] = teams
		profile["blocked_wall_pairs"] = OpsState.get_blocked_wall_pairs()
		var blocked: Dictionary = runtime["blocked"]
		for key in blocked.keys():
			if now_ms >= int(blocked[key]):
				blocked.erase(key)
		profile["blocked_intents_until_ms"] = blocked
		profile["allow_swarm"] = bool(profile.get("allow_swarm", true)) and now_ms >= int(runtime.get("swarm_until_ms", 0))
		if _human_enabled(profile):
			_tick_human(seat, runtime, profile, teams, now_ms)
			continue
		if now_ms < int(runtime["next_think_ms"]):
			continue
		var index := int(runtime["decision_index"])
		profile["decision_seed"] = int(profile.get("decision_seed", 0)) + int(BotRandom.sample(OpsState.bot_match_seed, seat, index, "choice") * 1000000.0)
		runtime["decision_index"] = index + 1
		runtime["next_think_ms"] = now_ms + _next_think_interval_ms(profile, seat, index)
		var decision: Dictionary = policy.call("choose_intent", state, seat, profile, now_ms)
		if decision.is_empty():
			continue
		_execute(seat, decision, runtime, profile, now_ms)

func _human_enabled(profile: Dictionary) -> bool:
	if str(profile.get("human_policy", "")) != "human_balancer_v3" or OpsState.victory_mode != OpsState.VICTORY_MODE_CONQUEST:
		return false
	if not bool(profile.get("human_behavior_enabled", false)) and not OS.get_cmdline_user_args().has("--human-bot-pilot"):
		return false
	var count := 0
	for row in OpsState.match_roster:
		if typeof(row) == TYPE_DICTIONARY and bool(row.get("active", true)):
			count += 1
	return count == 2

func _tick_human(seat: int, runtime: Dictionary, profile: Dictionary, teams: Dictionary, now_ms: int) -> void:
	var pending: Dictionary = runtime.get("pending_action", {})
	if not pending.is_empty():
		if now_ms < int(pending["execute_ms"]):
			return
		runtime["pending_action"] = {}
		var result := _execute(seat, pending, runtime, profile, now_ms)
		var memory: Dictionary = runtime["memory"]
		if not bool(result.get("ok", false)):
			memory["plan"] = {}
			memory["last_plan_reason"] = "command_rejected"
			runtime["next_think_ms"] = maxi(int(runtime["next_think_ms"]), now_ms + 500)
		elif str(pending.get("goal", "")) == "supply":
			var plan: Dictionary = memory.get("plan", {})
			plan["supply_ordered"] = true
			# Related prepared actions can follow more closely than a new plan.
			runtime["next_think_ms"] = now_ms + maxi(450, int(profile.get("global_intent_cooldown_ms", 450)))
		return
	var perception: Dictionary = runtime.get("pending_observation", {})
	if not perception.is_empty():
		if now_ms < int(perception["ready_ms"]):
			return
		runtime["pending_observation"] = {}
		var memory: Dictionary = runtime["memory"]
		var previous_plan := JSON.stringify(memory.get("plan", {}))
		var decision: Dictionary = _human_policy.call("choose", perception["view"], memory, profile, now_ms)
		if previous_plan != JSON.stringify(memory.get("plan", {})):
			_emit_event(seat, "plan", now_ms, {"plan": memory.get("plan", {}).duplicate(true), "reason": memory.get("last_plan_reason", ""), "observed_ms": perception["view"]["observed_ms"]})
		var index := int(runtime["decision_index"])
		runtime["next_think_ms"] = now_ms + _next_think_interval_ms(profile, seat, index)
		if decision.is_empty():
			return
		decision["observed_ms"] = int(perception["view"]["observed_ms"])
		decision["decided_ms"] = now_ms
		decision["execute_ms"] = now_ms + _human_delay(profile, seat, index, "motor", 200, 100)
		runtime["pending_action"] = decision
		_emit_event(seat, "scheduled", now_ms, decision)
		return
	if now_ms < int(runtime["next_think_ms"]):
		return
	var index := int(runtime["decision_index"])
	runtime["decision_index"] = index + 1
	var memory: Dictionary = runtime["memory"]
	if not memory.has("optimism"):
		memory["optimism"] = (BotRandom.sample(OpsState.bot_match_seed, seat, 0, "optimism") - 0.5) * 0.3
	var view := BotObservation.capture(state, seat, teams, now_ms)
	runtime["pending_observation"] = {"view": view, "ready_ms": now_ms + _human_delay(profile, seat, index, "notice", 450, 200)}
	_emit_event(seat, "observed", now_ms, {"ready_ms": runtime["pending_observation"]["ready_ms"], "opportunity_count": view["routes"].size()})

func _human_delay(profile: Dictionary, seat: int, index: int, purpose: String, base: int, jitter: int) -> int:
	var delay := int(profile.get(purpose + "_delay_ms", base))
	var spread := int(profile.get(purpose + "_jitter_ms", jitter))
	delay += int(round((BotRandom.sample(OpsState.bot_match_seed, seat, index, purpose) * 2.0 - 1.0) * spread))
	return maxi(100, int(ceil(float(delay) / 100.0)) * 100)

func _execute(seat: int, decision: Dictionary, runtime: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var result := BotCommand.apply(OpsState, seat, decision)
	var src := int(decision.get("src", -1))
	var dst := int(decision.get("dst", -1))
	var intent := str(decision.get("intent", ""))
	var ok := bool(result.get("ok", false))
	var blocked: Dictionary = runtime["blocked"]
	if ok:
		_block_pair(blocked, src, dst, now_ms + maxi(250, int(profile.get("pair_intent_cooldown_ms", 1200))))
		if intent == "swarm":
			blocked[_key(src, dst, intent)] = maxi(int(blocked.get(_key(src, dst, intent), 0)), now_ms + maxi(250, int(profile.get("swarm_cooldown_ms", 1600))))
			runtime["swarm_until_ms"] = now_ms + maxi(500, int(profile.get("swarm_global_cooldown_ms", 3500)))
		var delay := maxi(int(profile.get("global_intent_cooldown_ms", 900)), int(profile.get("post_intent_delay_ms", 0)))
		runtime["next_think_ms"] = maxi(int(runtime["next_think_ms"]), now_ms + delay)
	else:
		var retry := maxi(200, int(profile.get("retry_block_ms", 900)))
		if str(result.get("reason", "")) == "no_lane":
			retry = maxi(retry, int(profile.get("no_lane_retry_ms", 2800)))
		_block_pair(blocked, src, dst, now_ms + retry)
	var event := decision.duplicate(true)
	# JSON snapshots restore numbers as floats. Keep canonical millisecond fields
	# integral so a resumed pending command emits the same trace on Godot 4.7.
	for field in ["observed_ms", "decided_ms", "execute_ms"]:
		if event.has(field):
			event[field] = int(event[field])
	event.merge(result, true)
	event["style"] = str(profile.get("style", ""))
	event["tier"] = str(profile.get("tier", "medium"))
	_emit_event(seat, "applied" if ok else "rejected", now_ms, event)
	return result

func _emit_event(seat: int, kind: String, now_ms: int, details: Dictionary) -> void:
	var event := details.duplicate(true)
	event["seat"] = seat
	event["event"] = kind
	event["sim_ms"] = now_ms
	event["tick"] = int(state.tick)
	decision_event.emit(event)
	SFLog.info("BOT_DECISION", event)
	OpsState._record_match_action_event(seat, "bot_" + kind, event)

func _key(src: int, dst: int, intent: String) -> String:
	return "%d|%d|%s" % [src, dst, intent]

func _block_pair(blocked: Dictionary, src: int, dst: int, until_ms: int) -> void:
	for intent in ["attack", "feed", "swarm", "retract"]:
		for pair in [[src, dst], [dst, src]]:
			var key := _key(int(pair[0]), int(pair[1]), intent)
			blocked[key] = maxi(int(blocked.get(key, 0)), until_ms)

func _next_think_interval_ms(profile: Dictionary, seat: int, index: int = 0) -> int:
	var base_ms := maxi(100, int(profile.get("think_interval_ms", 420)))
	var jitter_ms := maxi(0, int(profile.get("think_jitter_ms", 0)))
	var offset := int(round((BotRandom.sample(OpsState.bot_match_seed, seat, index, "timing") * 2.0 - 1.0) * jitter_ms))
	return maxi(100, base_ms + offset)
