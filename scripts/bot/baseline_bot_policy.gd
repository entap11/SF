# Deterministic baseline bot policy for MVP gameplay testing.
class_name BaselineBotPolicy
extends "res://scripts/bot/bot_policy.gd"

const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const DEFAULT_MAX_HIVE_POWER: int = 50

func choose_intent(state_ref: GameState, seat: int, profile: Dictionary, now_ms: int) -> Dictionary:
	if state_ref == null:
		return {}
	if seat < 1 or seat > 4:
		return {}
	var style_id: String = str(profile.get("style", profile.get("persona", "balancer"))).strip_edges().to_lower()
	var tier_id: String = str(profile.get("tier", "medium")).strip_edges().to_lower()
	var team_by_seat: Dictionary = _normalized_team_map(profile.get("team_by_seat", {}))
	var min_attack_power: int = maxi(1, int(profile.get("min_attack_power", 8)))
	var min_feed_power: int = maxi(1, int(profile.get("min_feed_power", 11)))
	var min_swarm_power: int = maxi(1, int(profile.get("min_swarm_power", min_attack_power + 6)))
	var allow_swarm: bool = bool(profile.get("allow_swarm", true))
	var aggression: float = clampf(float(profile.get("aggression", 0.72)), 0.0, 1.0)
	var feed_bias: float = clampf(float(profile.get("feed_bias", 0.22)), 0.0, 1.0)
	var randomness: float = clampf(float(profile.get("randomness", 0.08)), 0.0, 0.5)
	var prefer_neutral_bonus: float = clampf(float(profile.get("prefer_neutral_bonus", 0.5)), 0.0, 2.0)
	var attack_distance_weight: float = clampf(float(profile.get("attack_distance_weight", 2.0)), 0.1, 8.0)
	var feed_distance_weight: float = clampf(float(profile.get("feed_distance_weight", 1.6)), 0.1, 8.0)
	var attack_power_diff_weight: float = clampf(float(profile.get("attack_power_diff_weight", 1.2)), 0.1, 5.0)
	var feed_need_weight: float = clampf(float(profile.get("feed_need_weight", 1.3)), 0.1, 5.0)
	var weak_target_bonus: float = clampf(float(profile.get("weak_target_bonus", 4.0)), 0.0, 20.0)
	var strong_target_penalty: float = clampf(float(profile.get("strong_target_penalty", 6.0)), 0.0, 20.0)
	var low_ally_power_bonus: float = clampf(float(profile.get("low_ally_power_bonus", 5.0)), 0.0, 20.0)
	var enemy_owned_bonus: float = clampf(float(profile.get("enemy_owned_bonus", 2.5)), 0.0, 10.0)
	var neutral_capture_bonus: float = clampf(float(profile.get("neutral_capture_bonus", 8.0)), 0.0, 20.0)
	var swarm_distance_weight: float = clampf(float(profile.get("swarm_distance_weight", 1.2)), 0.1, 8.0)
	var swarm_power_diff_weight: float = clampf(float(profile.get("swarm_power_diff_weight", 1.8)), 0.1, 6.0)
	var swarm_low_power_bonus: float = clampf(float(profile.get("swarm_low_power_bonus", 6.0)), 0.0, 20.0)
	var weak_target_threshold: int = maxi(1, int(profile.get("weak_target_threshold", 12)))
	var swarm_frequency: float = clampf(float(profile.get("swarm_frequency", aggression * 0.60)), 0.0, 0.95)
	var wall_segments: Array = []
	if state_ref != null and state_ref.walls != null and not state_ref.walls.is_empty():
		wall_segments = MAP_SCHEMA._wall_segments_from_walls(state_ref.walls)

	var blocked_pairs: Dictionary = _build_blocked_pair_lookup_from_profile(profile)
	var attack_candidates: Array = []
	var feed_candidates: Array = []
	var swarm_candidates: Array = []
	for hive_any in state_ref.hives:
		var src: HiveData = hive_any as HiveData
		if src == null:
			continue
		if int(src.owner_id) != seat:
			continue
		var src_id: int = int(src.id)
		var src_power: int = int(src.power)
		var active_outgoing: int = int(state_ref.count_active_outgoing(src_id))
		var outgoing_budget: int = int(state_ref.lanes_allowed_for_power(src_power))

		for dst_any in state_ref.hives:
			var dst: HiveData = dst_any as HiveData
			if dst == null:
				continue
			var dst_id: int = int(dst.id)
			if dst_id == src_id:
				continue
			if not state_ref.can_connect(src_id, dst_id):
				continue
			if _is_blocked_pair(blocked_pairs, src_id, dst_id):
				continue
			if _pair_intersects_wall(src, dst, wall_segments):
				continue

			var dst_owner: int = int(dst.owner_id)
			var dst_power: int = int(dst.power)
			var dst_is_ally: bool = _are_allies(team_by_seat, seat, dst_owner)
			var outgoing_active: bool = state_ref.is_outgoing_lane_active(src_id, dst_id)
			if outgoing_active:
				if allow_swarm and dst_owner > 0 and not dst_is_ally and src_power >= min_swarm_power:
					var swarm_score: float = _score_swarm(
						src,
						dst,
						src_power,
						dst_power,
						swarm_distance_weight,
						swarm_power_diff_weight,
						swarm_low_power_bonus,
						weak_target_threshold
					)
					swarm_candidates.append({
						"src": src_id,
						"dst": dst_id,
						"intent": "swarm",
						"score": swarm_score,
						"policy": "baseline_v2",
						"style": style_id,
						"tier": tier_id
					})
				continue

			if active_outgoing >= outgoing_budget:
				continue

			if dst_is_ally:
				if src_power < min_feed_power:
					continue
				var feed_score: float = _score_feed(
					src,
					dst,
					src_power,
					dst_power,
					outgoing_budget,
					active_outgoing,
					feed_distance_weight,
					feed_need_weight,
					low_ally_power_bonus,
					weak_target_threshold
				)
				feed_candidates.append({
					"src": src_id,
					"dst": dst_id,
					"intent": "feed",
					"score": feed_score,
					"policy": "baseline_v2",
					"style": style_id,
					"tier": tier_id
				})
			else:
				if src_power < min_attack_power:
					continue
				var attack_score: float = _score_attack(
					src,
					dst,
					src_power,
					dst_power,
					outgoing_budget,
					active_outgoing,
					prefer_neutral_bonus,
					attack_distance_weight,
					attack_power_diff_weight,
					weak_target_bonus,
					strong_target_penalty,
					enemy_owned_bonus,
					neutral_capture_bonus,
					weak_target_threshold
				)
				attack_candidates.append({
					"src": src_id,
					"dst": dst_id,
					"intent": "attack",
					"score": attack_score,
					"policy": "baseline_v2",
					"style": style_id,
					"tier": tier_id
				})

	attack_candidates.sort_custom(Callable(self, "_score_desc"))
	feed_candidates.sort_custom(Callable(self, "_score_desc"))
	swarm_candidates.sort_custom(Callable(self, "_score_desc"))
	if attack_candidates.is_empty() and feed_candidates.is_empty() and swarm_candidates.is_empty():
		return {}

	# If a lane is already active against an enemy, occasionally trigger a burst swarm.
	if allow_swarm and not swarm_candidates.is_empty():
		var swarm_roll: float = _deterministic_roll(int(state_ref.tick), seat, now_ms, 211)
		var swarm_bias: float = clampf(swarm_frequency, 0.0, 0.90)
		if swarm_roll <= swarm_bias:
			var swarm_choice: Dictionary = swarm_candidates[0] as Dictionary
			swarm_choice["seat"] = seat
			return swarm_choice

	var attack_weight: float = clampf(aggression - (feed_bias * 0.5), 0.0, 1.0)
	var choose_attack: bool = false
	if not attack_candidates.is_empty() and feed_candidates.is_empty():
		choose_attack = true
	elif attack_candidates.is_empty() and not feed_candidates.is_empty():
		choose_attack = false
	else:
		var roll: float = _deterministic_roll(int(state_ref.tick), seat, now_ms, 17)
		choose_attack = roll <= attack_weight

	var chosen_pool: Array = attack_candidates if choose_attack else feed_candidates
	if chosen_pool.is_empty():
		chosen_pool = feed_candidates if choose_attack else attack_candidates
	if chosen_pool.is_empty():
		return {}

	var pick_index: int = 0
	if chosen_pool.size() > 1:
		var roll_pick: float = _deterministic_roll(int(state_ref.tick), seat, now_ms, 73)
		if roll_pick < randomness:
			pick_index = 1
	var chosen: Dictionary = chosen_pool[pick_index] as Dictionary
	chosen["seat"] = seat
	return chosen

func _score_attack(
	src: HiveData,
	dst: HiveData,
	src_power: int,
	dst_power: int,
	outgoing_budget: int,
	active_outgoing: int,
	prefer_neutral_bonus: float,
	attack_distance_weight: float,
	attack_power_diff_weight: float,
	weak_target_bonus: float,
	strong_target_penalty: float,
	enemy_owned_bonus: float,
	neutral_capture_bonus: float,
	weak_target_threshold: int
) -> float:
	var dist: float = _grid_distance(src.grid_pos, dst.grid_pos)
	var score: float = 100.0
	score += float(src_power - dst_power) * attack_power_diff_weight
	score -= dist * attack_distance_weight
	score += float(outgoing_budget - active_outgoing) * 1.5
	if int(dst.owner_id) <= 0:
		score += neutral_capture_bonus * prefer_neutral_bonus
	else:
		score += enemy_owned_bonus
	if dst_power <= weak_target_threshold:
		score += weak_target_bonus
	if dst_power >= src_power:
		score -= strong_target_penalty
	return score

func _score_feed(
	src: HiveData,
	dst: HiveData,
	src_power: int,
	dst_power: int,
	outgoing_budget: int,
	active_outgoing: int,
	feed_distance_weight: float,
	feed_need_weight: float,
	low_ally_power_bonus: float,
	weak_target_threshold: int
) -> float:
	var dist: float = _grid_distance(src.grid_pos, dst.grid_pos)
	var score: float = 60.0
	score += float(DEFAULT_MAX_HIVE_POWER - dst_power) * feed_need_weight
	score -= dist * feed_distance_weight
	score += float(mini(src_power, 20)) * 0.2
	score += float(outgoing_budget - active_outgoing) * 0.8
	if dst_power <= weak_target_threshold:
		score += low_ally_power_bonus
	if dst_power >= DEFAULT_MAX_HIVE_POWER:
		score -= 8.0
	return score

func _score_swarm(
	src: HiveData,
	dst: HiveData,
	src_power: int,
	dst_power: int,
	swarm_distance_weight: float,
	swarm_power_diff_weight: float,
	swarm_low_power_bonus: float,
	weak_target_threshold: int
) -> float:
	var dist: float = _grid_distance(src.grid_pos, dst.grid_pos)
	var score: float = 85.0
	score += float(src_power - dst_power) * swarm_power_diff_weight
	score -= dist * swarm_distance_weight
	if dst_power <= weak_target_threshold:
		score += swarm_low_power_bonus
	return score

func _build_blocked_pair_lookup_from_profile(profile: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	var raw_pairs: Variant = profile.get("blocked_wall_pairs", [])
	if typeof(raw_pairs) != TYPE_ARRAY:
		return lookup
	for pair_any in raw_pairs as Array:
		if pair_any is Vector2i:
			var pair_v2i: Vector2i = pair_any as Vector2i
			var lo_v2i: int = mini(int(pair_v2i.x), int(pair_v2i.y))
			var hi_v2i: int = maxi(int(pair_v2i.x), int(pair_v2i.y))
			lookup[_pair_key(lo_v2i, hi_v2i)] = true
		elif typeof(pair_any) == TYPE_ARRAY:
			var pair_arr: Array = pair_any as Array
			if pair_arr.size() >= 2:
				var lo_arr: int = mini(int(pair_arr[0]), int(pair_arr[1]))
				var hi_arr: int = maxi(int(pair_arr[0]), int(pair_arr[1]))
				lookup[_pair_key(lo_arr, hi_arr)] = true
	return lookup

func _is_blocked_pair(lookup: Dictionary, src_id: int, dst_id: int) -> bool:
	return bool(lookup.get(_pair_key(src_id, dst_id), false))

func _pair_key(a_id: int, b_id: int) -> String:
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	return "%d:%d" % [lo, hi]

func _pair_intersects_wall(src: HiveData, dst: HiveData, wall_segments: Array) -> bool:
	if wall_segments.is_empty():
		return false
	if src == null or dst == null:
		return false
	var a_grid := Vector2(float(src.grid_pos.x), float(src.grid_pos.y))
	var b_grid := Vector2(float(dst.grid_pos.x), float(dst.grid_pos.y))
	return MAP_SCHEMA._segment_intersects_any_wall(a_grid, b_grid, wall_segments)

func _normalized_team_map(raw: Variant) -> Dictionary:
	var out: Dictionary = {1: 1, 2: 2, 3: 3, 4: 4}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var raw_dict: Dictionary = raw as Dictionary
	for key_any in raw_dict.keys():
		var seat: int = int(key_any)
		if seat < 1 or seat > 4:
			continue
		var team_id: int = int(raw_dict.get(key_any, seat))
		if team_id <= 0:
			team_id = seat
		out[seat] = team_id
	return out

func _team_for_seat(team_by_seat: Dictionary, seat: int) -> int:
	var seat_id: int = int(seat)
	if seat_id < 1 or seat_id > 4:
		return 0
	var team_id: int = int(team_by_seat.get(seat_id, seat_id))
	if team_id <= 0:
		return seat_id
	return team_id

func _are_allies(team_by_seat: Dictionary, seat_a: int, seat_b: int) -> bool:
	var a_id: int = int(seat_a)
	var b_id: int = int(seat_b)
	if a_id <= 0 or b_id <= 0:
		return false
	return _team_for_seat(team_by_seat, a_id) == _team_for_seat(team_by_seat, b_id)

func _deterministic_roll(tick: int, seat: int, now_ms: int, salt: int) -> float:
	var seed: int = abs((tick + 1) * 1103515245 + seat * 12345 + now_ms + salt * 265443576)
	return float(seed % 10000) / 10000.0

func _score_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 0.0)) > float(b.get("score", 0.0))

func _grid_distance(a: Vector2i, b: Vector2i) -> float:
	var av: Vector2 = Vector2(float(a.x), float(a.y))
	var bv: Vector2 = Vector2(float(b.x), float(b.y))
	return av.distance_to(bv)
