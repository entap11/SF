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
		var score: float = 100.0 - (wax_delta / maxf(1.0, wax_tolerance)) * 40.0
		if str(candidate_record.get("tier_id", "DRONE")) == requester_tier:
			score += config.mm_same_tier_priority
		if str(candidate_record.get("color_id", "GREEN")) == requester_color:
			score += config.mm_same_color_priority
		rows.append({
			"player_id": candidate_id,
			"display_name": str(candidate_record.get("display_name", candidate_id)),
			"wax_score": candidate_wax,
			"wax_delta": wax_delta,
			"tier_id": str(candidate_record.get("tier_id", "DRONE")),
			"color_id": str(candidate_record.get("color_id", "GREEN")),
			"wait_seconds": wait_seconds,
			"score": score
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a.get("score", 0.0))
		var sb: float = float(b.get("score", 0.0))
		if is_equal_approx(sa, sb):
			return str(a.get("player_id", "")) < str(b.get("player_id", ""))
		return sa > sb
	)
	return rows
