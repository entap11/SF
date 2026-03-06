class_name RankMatchmaker
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

func find_candidates(
		players_by_id: Dictionary,
		requester_id: String,
		queue_entries: Array,
		config: RankConfigScript
	) -> Array[Dictionary]:
	var requester_record: Dictionary = players_by_id.get(requester_id, {}) as Dictionary
	if requester_record.is_empty():
		return []
	var requester_wax: float = float(requester_record.get("wax_score", 0.0))
	var requester_tier: String = str(requester_record.get("tier_id", "DRONE"))
	var requester_color: String = str(requester_record.get("color_id", "GREEN"))

	var rows: Array[Dictionary] = []
	for entry_any in queue_entries:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_any as Dictionary
		var candidate_id: String = str(entry.get("player_id", "")).strip_edges()
		if candidate_id == "" or candidate_id == requester_id:
			continue
		var candidate_record: Dictionary = players_by_id.get(candidate_id, {}) as Dictionary
		if candidate_record.is_empty():
			continue
		var wait_seconds: float = maxf(0.0, float(entry.get("wait_seconds", 0.0)))
		var wax_tolerance: float = config.mm_base_wax_tolerance + (wait_seconds * config.mm_wax_tolerance_per_sec)
		wax_tolerance = clampf(wax_tolerance, config.mm_base_wax_tolerance, config.mm_max_wax_tolerance)
		var candidate_wax: float = float(candidate_record.get("wax_score", 0.0))
		var wax_delta: float = absf(candidate_wax - requester_wax)
		if wax_delta > wax_tolerance:
			continue
		var candidate_tier: String = str(candidate_record.get("tier_id", "DRONE"))
		var candidate_color: String = str(candidate_record.get("color_id", "GREEN"))
		var tier_distance: int = _tier_distance(config, requester_tier, candidate_tier)
		var color_distance: int = _color_distance(config, requester_color, candidate_color)
		var score: float = 10000.0
		score -= float(tier_distance) * 1000.0
		score -= float(color_distance) * 100.0
		score -= wax_delta
		rows.append({
			"player_id": candidate_id,
			"display_name": str(candidate_record.get("display_name", candidate_id)),
			"wax_score": candidate_wax,
			"wax_delta": wax_delta,
			"tier_id": candidate_tier,
			"color_id": candidate_color,
			"tier_distance": tier_distance,
			"color_distance": color_distance,
			"wait_seconds": wait_seconds,
			"score": score
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_tier_distance: int = int(a.get("tier_distance", 99999))
		var b_tier_distance: int = int(b.get("tier_distance", 99999))
		if a_tier_distance != b_tier_distance:
			return a_tier_distance < b_tier_distance
		var a_color_distance: int = int(a.get("color_distance", 99999))
		var b_color_distance: int = int(b.get("color_distance", 99999))
		if a_color_distance != b_color_distance:
			return a_color_distance < b_color_distance
		var a_wax_delta: float = float(a.get("wax_delta", 999999.0))
		var b_wax_delta: float = float(b.get("wax_delta", 999999.0))
		if not is_equal_approx(a_wax_delta, b_wax_delta):
			return a_wax_delta < b_wax_delta
		var a_wait: float = float(a.get("wait_seconds", 0.0))
		var b_wait: float = float(b.get("wait_seconds", 0.0))
		if not is_equal_approx(a_wait, b_wait):
			return a_wait > b_wait
		return str(a.get("player_id", "")) < str(b.get("player_id", ""))
	)
	return rows

func _tier_distance(config: RankConfigScript, requester_tier: String, candidate_tier: String) -> int:
	var requester_idx: int = config.tier_index(requester_tier)
	var candidate_idx: int = config.tier_index(candidate_tier)
	if requester_idx < 0 or candidate_idx < 0:
		return 99999
	return absi(candidate_idx - requester_idx)

func _color_distance(config: RankConfigScript, requester_color: String, candidate_color: String) -> int:
	var colors: Array[String] = config.normalized_color_quintiles()
	var requester_idx: int = _index_of(colors, requester_color.strip_edges().to_upper())
	var candidate_idx: int = _index_of(colors, candidate_color.strip_edges().to_upper())
	if requester_idx < 0 or candidate_idx < 0:
		return 99999
	return absi(candidate_idx - requester_idx)

func _index_of(items: Array[String], value: String) -> int:
	for i in range(items.size()):
		if items[i] == value:
			return i
	return -1
