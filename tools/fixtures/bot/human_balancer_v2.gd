# First human-behavior pilot: medium Balancer. Cognition is simulation-owned;
# this policy reads a delayed observation and updates only its supplied memory.
extends RefCounted

const Growth := preload("res://scripts/sim/hive_growth_rules.gd")
const Swarm := preload("res://scripts/systems/swarm_system.gd")

func choose(observation: Dictionary, memory: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var hives: Dictionary = observation["hives"]
	var seat := int(observation["seat"])
	var plan: Dictionary = memory.get("plan", {})
	var avoided: Dictionary = memory.get("avoided_until", {})
	for key in avoided.keys():
		if now_ms >= int(avoided[key]):
			avoided.erase(key)
	memory["avoided_until"] = avoided
	var threats := _threats(observation)
	# Reassess a stalled commitment using observed progress, never hindsight.
	if not plan.is_empty():
		var target: Dictionary = hives.get(str(plan.get("target", -1)), {})
		var source: Dictionary = hives.get(str(plan.get("source", -1)), {})
		if target.is_empty() or source.is_empty() or int(source.get("owner", 0)) != seat:
			_clear_plan(memory, "source_lost")
			plan = {}
		elif str(plan.get("goal", "")) != "defend" and _allied(observation, int(target["owner"])):
			_clear_plan(memory, "target_captured")
			plan = {}
		elif str(plan.get("goal", "")) != "defend":
			if int(target["power"]) < int(plan.get("best_power", target["power"])):
				plan["best_power"] = int(target["power"])
				plan["progress_ms"] = now_ms
			var stalled := now_ms - int(plan.get("progress_ms", now_ms)) >= int(profile.get("plan_stall_ms", 8000))
			var exposed := float(threats.get(str(source["id"]), 0.0)) > 0.0 and not _is_counterpressure(observation, int(source["id"]), int(target["id"]))
			if (stalled or exposed) and not _is_counterpressure(observation, int(source["id"]), int(target["id"])):
				var retreat := _active_route(observation, int(source["id"]), int(target["id"]))
				if not retreat.is_empty() and _available(profile, retreat, "retract", now_ms):
					avoided[str(target["id"])] = now_ms + int(profile.get("plan_retry_ms", 8000))
					_clear_plan(memory, "stalled" if stalled else "source_threatened")
					return _command(retreat, "retract", "withdraw", 100.0)
				if stalled:
					avoided[str(target["id"])] = now_ms + int(profile.get("plan_retry_ms", 8000))
					_clear_plan(memory, "stalled")
					plan = {}
	# One front at a time. A delayed threat can interrupt; ordinary alternatives
	# wait until the current focus's review interval has elapsed.
	var defense := _best_defense(observation, threats, profile, now_ms)
	if not defense.is_empty():
		if not plan.is_empty() and str(plan.get("goal", "")) != "defend":
			memory["suspended_plan"] = plan.duplicate(true)
		_set_plan(memory, "defend", int(defense["src"]), int(defense["dst"]), hives, now_ms)
		return defense
	if not plan.is_empty() and str(plan.get("goal", "")) == "defend":
		if float(threats.get(str(plan.get("target", -1)), 0.0)) > 0.0 and now_ms < int(plan.get("review_ms", now_ms)):
			# A command cooldown or unavailable donor does not resolve the threat.
			return _develop_supply(observation, profile, threats, now_ms)
		_clear_plan(memory, "defense_stable")
		plan = memory.get("suspended_plan", {})
		if not plan.is_empty():
			var saved_src: Dictionary = hives.get(str(plan.get("source", -1)), {})
			var saved_dst: Dictionary = hives.get(str(plan.get("target", -1)), {})
			if int(saved_src.get("owner", 0)) != seat or saved_dst.is_empty() or _allied(observation, int(saved_dst.get("owner", 0))):
				plan = {}
		memory["plan"] = plan
		memory["suspended_plan"] = {}
	var reviewed := _review_watching(observation, memory, profile, threats, now_ms)
	if not reviewed.is_empty():
		return reviewed
	if not plan.is_empty():
		var followup := _advance_attack(observation, plan, profile, now_ms)
		if not followup.is_empty():
			return followup
		if not _active_route(observation, int(plan["source"]), int(plan["target"])).is_empty():
			var watching: Array = memory.get("watching", [])
			if now_ms < int(plan.get("review_ms", 0)) or watching.size() >= 2:
				return _develop_supply(observation, profile, threats, now_ms)
			# Orders keep running while attention moves. Remember a bounded number
			# of commitments and inspect only one of them per observation.
			watching.append(plan.duplicate(true))
			memory["watching"] = watching
			_clear_plan(memory, "shift_attention")
			plan = {}
		if now_ms < int(plan.get("review_ms", 0)):
			return {}
		_clear_plan(memory, "review_front")
		plan = {}
	var candidates: Array[Dictionary] = []
	for route in observation["routes"]:
		var src: Dictionary = hives[str(route["src"])]
		var dst: Dictionary = hives[str(route["dst"])]
		if _allied(observation, int(dst["owner"])) or avoided.has(str(dst["id"])):
			continue
		var support_count := _friendly_pressure(observation, int(dst["id"]))
		if _target_watched(memory, int(dst["id"])) and (int(dst["owner"]) == 0 or support_count >= 2):
			continue
		if bool(route["active"]) or int(src["open_slots"]) <= 0:
			continue
		var supplied := _friendly_pressure(observation, int(src["id"])) > 0
		var counter := _is_counterpressure(observation, int(src["id"]), int(dst["id"]))
		var min_power := 4 if supplied else int(profile.get("min_attack_power", 11))
		if counter:
			# A one-power contested capture often changes hands before the normal
			# notice/motor delay ends. Wait for a small reserve instead of repeatedly
			# preparing commands that cannot survive their own execution delay.
			min_power = 4
		if not _available(profile, route, "attack", now_ms) or int(src["power"]) < min_power:
			continue
		var projected_power := float(dst["power"]) + _friendly_incoming(observation, int(dst["id"]), int(dst["owner"]))
		var margin := float(src["power"]) - projected_power
		var score := margin * 1.5 - float(route["distance"]) * 2.0 + (14.0 if int(dst["owner"]) == 0 else 0.0)
		score -= float(threats.get(str(src["id"]), 0.0)) * 3.0
		if int(src.get("outgoing", 0)) == 0:
			score += 10.0
		if support_count > 0 and int(dst["owner"]) > 0:
			score += 20.0
		if counter:
			score += 35.0
		# A limited optimistic error is coherent across this decision's candidates.
		score += float(memory.get("optimism", 0.0)) * minf(8.0, projected_power)
		if margin < -8.0 and not counter and not (supplied and int(dst["owner"]) == 0) and support_count == 0:
			continue
		candidates.append(_command(route, "attack", "expand" if int(dst["owner"]) == 0 else "pressure", score))
	if candidates.is_empty():
		return _develop_supply(observation, profile, threats, now_ms)
	candidates.sort_custom(_better)
	var choice: Dictionary = candidates[0]
	_set_plan(memory, str(choice["goal"]), int(choice["src"]), int(choice["dst"]), hives, now_ms)
	return _advance_attack(observation, memory["plan"], profile, now_ms)

func _target_watched(memory: Dictionary, target: int) -> bool:
	for plan in memory.get("watching", []):
		if int(plan.get("target", -1)) == target:
			return true
	return false

func _review_watching(obs: Dictionary, memory: Dictionary, profile: Dictionary, threats: Dictionary, now_ms: int) -> Dictionary:
	var watching: Array = memory.get("watching", [])
	if watching.is_empty():
		return {}
	var index := int(memory.get("watch_cursor", 0)) % watching.size()
	memory["watch_cursor"] = index + 1
	var plan: Dictionary = watching[index]
	var src: Dictionary = obs["hives"].get(str(plan["source"]), {})
	var dst: Dictionary = obs["hives"].get(str(plan["target"]), {})
	var route := _active_route(obs, int(plan["source"]), int(plan["target"]))
	if int(src.get("owner", 0)) != int(obs["seat"]) or dst.is_empty() or _allied(obs, int(dst.get("owner", 0))) or route.is_empty():
		watching.remove_at(index)
		return {}
	if int(dst["power"]) < int(plan.get("best_power", dst["power"])):
		plan["best_power"] = int(dst["power"])
		plan["progress_ms"] = now_ms
	var stalled := now_ms - int(plan.get("progress_ms", now_ms)) >= int(profile.get("plan_stall_ms", 8000))
	var exposed := float(threats.get(str(plan["source"]), 0.0)) > 0.0 and not _is_counterpressure(obs, int(plan["source"]), int(plan["target"]))
	if (stalled or exposed) and not _is_counterpressure(obs, int(plan["source"]), int(plan["target"])) and _available(profile, route, "retract", now_ms):
		watching.remove_at(index)
		memory["avoided_until"][str(plan["target"])] = now_ms + int(profile.get("plan_retry_ms", 8000))
		memory["last_plan_reason"] = "watched_stall" if stalled else "watched_source_threatened"
		return _command(route, "retract", "withdraw", 100.0)
	return _advance_attack(obs, plan, profile, now_ms)

func _advance_attack(obs: Dictionary, plan: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var src: Dictionary = obs["hives"].get(str(plan["source"]), {})
	var dst: Dictionary = obs["hives"].get(str(plan["target"]), {})
	if src.is_empty() or dst.is_empty():
		return {}
	for route in obs["routes"]:
		if int(route["src"]) != int(src["id"]) or int(route["dst"]) != int(dst["id"]):
			continue
		if bool(route["active"]):
			var can_burst := int(src["power"]) >= maxi(12, int(profile.get("min_swarm_power", 17)))
			var resistance := float(dst["power"]) + _friendly_incoming(obs, int(dst["id"]), int(dst["owner"]))
			if can_burst and _preserves_capacity(src) and resistance <= float(src["power"]) + 3.0 and _available(profile, route, "swarm", now_ms):
				return _command(route, "swarm", str(plan["goal"]), 50.0)
			return {}
		# Build a short supply sequence before opening an evenly matched attack.
		if int(src["power"]) < int(dst["power"]) + 5 and not bool(plan.get("supply_ordered", false)):
			var supply := _feed_to(obs, int(src["id"]), profile, now_ms, false)
			if not supply.is_empty():
				return supply
		if int(src["open_slots"]) > 0 and _available(profile, route, "attack", now_ms):
			return _command(route, "attack", str(plan["goal"]), 50.0)
	return {}

func _best_defense(obs: Dictionary, threats: Dictionary, profile: Dictionary, now_ms: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for id in obs["ids"]:
		var urgency := float(threats.get(str(id), 0.0))
		if urgency <= 0.0:
			continue
		var feed := _feed_to(obs, int(id), profile, now_ms, true)
		if not feed.is_empty():
			feed["score"] = urgency
			candidates.append(feed)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(_better)
	return candidates[0]

func _feed_to(obs: Dictionary, target: int, profile: Dictionary, now_ms: int, urgent: bool) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var donor_threats := _threats(obs)
	for route in obs["routes"]:
		if int(route["dst"]) != target:
			continue
		if not _active_route(obs, target, int(route["src"])).is_empty():
			continue
		var src: Dictionary = obs["hives"][str(route["src"])]
		if int(src["power"]) < maxi(12, int(profile.get("min_feed_power", 12))):
			continue
		var intent := "swarm" if bool(route["active"]) else "feed"
		if bool(route["active"]) and not urgent:
			continue
		if not bool(route["active"]) and int(src["open_slots"]) <= 0:
			continue
		if not _available(profile, route, intent, now_ms):
			continue
		var donor_threat := float(donor_threats.get(str(src["id"]), 0.0))
		if donor_threat > 0.0 or (intent == "swarm" and not _preserves_capacity(src)):
			continue
		var score := float(src["power"]) - float(route["distance"]) * 2.0
		if int(src.get("outgoing", 0)) == 0:
			score += 18.0
		if intent == "swarm":
			score -= 8.0
		candidates.append(_command(route, intent, "defend" if urgent else "supply", score))
	if candidates.is_empty():
		return {}
	candidates.sort_custom(_better)
	return candidates[0]

func _threats(obs: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in obs["ids"]:
		var hive: Dictionary = obs["hives"][str(id)]
		if not _allied(obs, int(hive["owner"])):
			continue
		var incoming := 0.0
		for row in obs["incoming"]:
			if int(row["dst"]) == int(id) and not _allied(obs, int(row["owner"])):
				incoming += float(row["amount"])
		var attackers := 0
		for row in obs["pressure"]:
			if int(row["dst"]) == int(id) and not _allied(obs, int(row["owner"])):
				attackers += 1
		if attackers > 0 or incoming > 0.0:
			# Near-term estimate; observation does not expose future unit queues.
			var counterstreams := 0
			for row in obs["pressure"]:
				if int(row["dst"]) == int(id) and not _allied(obs, int(row["owner"])) and not _active_route(obs, int(id), int(row["src"])).is_empty():
					counterstreams += 1
			var net_pressure := maxi(0, attackers - counterstreams - _friendly_pressure(obs, int(id)))
			out[str(id)] = maxf(0.0, incoming + net_pressure * 6.0 + 6.0 - float(hive["power"]) - _friendly_incoming(obs, int(id), int(hive["owner"])))
	return out

func _preserves_capacity(source: Dictionary) -> bool:
	var power := int(source["power"])
	return Growth.lane_budget_for_power(power - mini(Swarm.SWARM_MAX_START, power - 1)) >= Growth.lane_budget_for_power(power)

func _friendly_pressure(obs: Dictionary, target: int) -> int:
	var count := 0
	for row in obs["pressure"]:
		if int(row["dst"]) == target and _allied(obs, int(row["owner"])):
			count += 1
	return count

func _is_counterpressure(obs: Dictionary, source: int, target: int) -> bool:
	for row in obs["pressure"]:
		if int(row["src"]) == target and int(row["dst"]) == source and not _allied(obs, int(row["owner"])):
			return true
	return false

func _front_distance(obs: Dictionary, hive: Dictionary) -> float:
	var distance := INF
	for target in obs["hives"].values():
		if _allied(obs, int(target["owner"])):
			continue
		distance = minf(distance, Vector2(hive["x"], hive["y"]).distance_to(Vector2(target["x"], target["y"])))
	return distance

func _develop_supply(obs: Dictionary, profile: Dictionary, threats: Dictionary, now_ms: int) -> Dictionary:
	# Put unused rear production behind the frontier. Strictly decreasing distance
	# to the frontier avoids circulating supply between otherwise idle hives.
	var candidates: Array[Dictionary] = []
	for route in obs["routes"]:
		var src: Dictionary = obs["hives"][str(route["src"])]
		var dst: Dictionary = obs["hives"][str(route["dst"])]
		if not _allied(obs, int(dst["owner"])) or bool(route["active"]):
			continue
		if int(src.get("outgoing", 0)) > 0 or int(src["open_slots"]) <= 0 or int(src["power"]) < int(profile.get("min_feed_power", 12)):
			continue
		if int(dst["power"]) >= 40 or float(threats.get(str(src["id"]), 0.0)) > 0.0:
			continue
		if _front_distance(obs, dst) >= _front_distance(obs, src) or not _active_route(obs, int(dst["id"]), int(src["id"])).is_empty():
			continue
		if _friendly_pressure(obs, int(dst["id"])) >= 2 or not _available(profile, route, "feed", now_ms):
			continue
		var score := float(40 - int(dst["power"])) - float(route["distance"]) * 2.0
		candidates.append(_command(route, "feed", "develop", score))
	if candidates.is_empty():
		return {}
	candidates.sort_custom(_better)
	return candidates[0]

func _friendly_incoming(obs: Dictionary, target: int, owner: int) -> float:
	if owner <= 0:
		return 0.0
	var amount := 0.0
	for row in obs["incoming"]:
		if int(row["dst"]) == target and _team(obs, int(row["owner"])) == _team(obs, owner):
			amount += float(row["amount"])
	return amount

func _allied(obs: Dictionary, owner: int) -> bool:
	return owner > 0 and _team(obs, owner) == _team(obs, int(obs["seat"]))

func _team(obs: Dictionary, owner: int) -> int:
	var teams: Dictionary = obs["teams"]
	return int(teams.get(owner, teams.get(str(owner), owner)))

func _available(profile: Dictionary, route: Dictionary, intent: String, now_ms: int) -> bool:
	if intent == "swarm" and (not bool(profile.get("allow_swarm", true)) or now_ms < int(route.get("swarm_ready_ms", 0))):
		return false
	var key := "%d|%d|%s" % [int(route["src"]), int(route["dst"]), intent]
	return now_ms >= int(profile.get("blocked_intents_until_ms", {}).get(key, 0))

func _active_route(obs: Dictionary, src: int, dst: int) -> Dictionary:
	for route in obs["routes"]:
		if int(route["src"]) == src and int(route["dst"]) == dst and bool(route["active"]):
			return route
	return {}

func _command(route: Dictionary, intent: String, goal: String, score: float) -> Dictionary:
	return {"src": int(route["src"]), "dst": int(route["dst"]), "intent": intent, "goal": goal, "score": score, "policy": "human_balancer_v2"}

func _set_plan(memory: Dictionary, goal: String, source: int, target: int, hives: Dictionary, now_ms: int) -> void:
	var old: Dictionary = memory.get("plan", {})
	if int(old.get("target", -1)) == target and int(old.get("source", -1)) == source and str(old.get("goal", "")) == goal:
		return
	memory["plan"] = {"goal": goal, "source": source, "target": target, "started_ms": now_ms, "progress_ms": now_ms, "review_ms": now_ms + 6000, "best_power": int(hives[str(target)]["power"])}
	memory["last_plan_reason"] = goal

func _clear_plan(memory: Dictionary, reason: String) -> void:
	memory["plan"] = {}
	memory["last_plan_reason"] = reason

func _better(a: Dictionary, b: Dictionary) -> bool:
	if float(a["score"]) != float(b["score"]):
		return float(a["score"]) > float(b["score"])
	if int(a["src"]) != int(b["src"]):
		return int(a["src"]) < int(b["src"])
	return int(a["dst"]) < int(b["dst"])
