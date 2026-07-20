class_name PublicContestComparator
extends RefCounted

const TICK_MS := 100

static func score(comparator_id: String, map_ids: Array, metrics: Dictionary, attempt_policy: Dictionary = {}) -> Dictionary:
	if comparator_id == "TIME_TOTAL_V1":
		return _score_time(map_ids, metrics)
	if comparator_id == "GAUNTLET_STARS_V1":
		return _score_gauntlet(attempt_policy.get("stage_plan", []) as Array, metrics)
	return {"ok": false, "err": "invalid_contest_comparator"}

static func _score_time(map_ids: Array, metrics: Dictionary) -> Dictionary:
	var per_map: Array = metrics.get("per_map", []) as Array
	if per_map.size() != map_ids.size():
		return {"ok": false, "err": "contest_result_incomplete"}
	var aggregate: int = 0
	for index in range(per_map.size()):
		var row: Dictionary = per_map[index] as Dictionary
		if not bool(row.get("completed", false)) or str(row.get("map_id", "")) != str(map_ids[index]):
			return {"ok": false, "err": "contest_result_incomplete"}
		var elapsed: int = int(row.get("elapsed_ticks", -1))
		var penalty: int = int(row.get("penalty_ticks", 0))
		if elapsed < 0 or penalty < 0:
			return {"ok": false, "err": "invalid_contest_elapsed_ticks"}
		aggregate += elapsed + penalty
	if metrics.has("aggregate_elapsed_ticks") and int(metrics.get("aggregate_elapsed_ticks", -1)) != aggregate:
		return {"ok": false, "err": "contest_aggregate_mismatch"}
	return {"ok": true, "primary": -aggregate, "secondary": 0, "tertiary": 0,
		"result": {"aggregate_elapsed_ticks": aggregate}}

static func _score_gauntlet(stage_plan: Array, metrics: Dictionary) -> Dictionary:
	var evidence: Array = metrics.get("stage_evidence", []) as Array
	if evidence.is_empty() or evidence.size() > stage_plan.size():
		return {"ok": false, "err": "gauntlet_stage_evidence_incomplete"}
	var stars: int = 0
	var completed: int = 0
	var elapsed_ticks: int = 0
	var terminal_seen: bool = false
	for index in range(evidence.size()):
		var stage: Dictionary = stage_plan[index] as Dictionary
		var row: Dictionary = evidence[index] as Dictionary
		if terminal_seen or int(row.get("stage_number", 0)) != index + 1 \
				or int(stage.get("stage_number", 0)) != index + 1 \
				or str(row.get("map_id", "")) != str(stage.get("map_id", "")):
			return {"ok": false, "err": "gauntlet_stage_evidence_mismatch"}
		var ticks: int = int(row.get("elapsed_ticks", -1))
		if ticks < 0:
			return {"ok": false, "err": "invalid_gauntlet_elapsed_ticks"}
		elapsed_ticks += ticks
		var won: bool = bool(row.get("won", false))
		var stage_stars: int = _stars_for_elapsed(ticks * TICK_MS,
			stage.get("thresholds_ms", {}) as Dictionary, won, str(row.get("win_reason", "")))
		stars += stage_stars
		if won and stage_stars > 0:
			completed += 1
		else:
			terminal_seen = true
	if not terminal_seen and evidence.size() < stage_plan.size():
		return {"ok": false, "err": "gauntlet_stage_evidence_incomplete"}
	return {"ok": true, "primary": stars, "secondary": completed, "tertiary": -elapsed_ticks,
		"result": {"stars": stars, "completed_stage_count": completed, "elapsed_ticks": elapsed_ticks}}

static func _stars_for_elapsed(elapsed_ms: int, thresholds: Dictionary, won: bool, reason_raw: String) -> int:
	if not won:
		return 0
	var reason: String = reason_raw.strip_edges().to_lower()
	if not reason.is_empty() and reason not in ["domination", "capture_all", "conquest", "elimination"]:
		return 0
	var four: int = int(thresholds.get("four_star_ms", 0))
	var three: int = int(thresholds.get("three_star_ms", 0))
	var two: int = int(thresholds.get("two_star_ms", 0))
	if four <= 0 or three <= four or two <= three:
		return 0
	if elapsed_ms <= four:
		return 4
	if elapsed_ms <= three:
		return 3
	if elapsed_ms <= two:
		return 2
	return 1
