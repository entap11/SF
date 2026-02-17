class_name ArenaStageRuntimeFlow
extends RefCounted

func is_stage_race_runtime_mode(tree: SceneTree, mode_meta_key: String, stage_mode_value: String) -> bool:
	if tree == null:
		return false
	var mode: String = str(tree.get_meta(mode_meta_key, "")).strip_edges().to_upper()
	return mode == stage_mode_value

func get_stage_map_paths_runtime(tree: SceneTree, stage_paths_meta_key: String) -> Array[String]:
	var out: Array[String] = []
	if tree == null or not tree.has_meta(stage_paths_meta_key):
		return out
	var raw: Variant = tree.get_meta(stage_paths_meta_key, [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for path_any in raw as Array:
		var path: String = str(path_any).strip_edges()
		if path.is_empty():
			continue
		out.append(path)
	return out

func get_stage_round_results_runtime(tree: SceneTree, results_meta_key: String) -> Array:
	var out: Array = []
	if tree == null or not tree.has_meta(results_meta_key):
		return out
	var raw: Variant = tree.get_meta(results_meta_key, [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item_any in raw as Array:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		out.append((item_any as Dictionary).duplicate(true))
	return out

func set_stage_round_results_runtime(tree: SceneTree, results_meta_key: String, results: Array) -> void:
	if tree == null:
		return
	tree.set_meta(results_meta_key, results.duplicate(true))

func upsert_stage_round_result(results: Array, round_index: int, result: Dictionary) -> Array:
	var out: Array = results.duplicate(true)
	for i in range(out.size()):
		if typeof(out[i]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = out[i] as Dictionary
		if int(row.get("round_index", -1)) != round_index:
			continue
		out[i] = result.duplicate(true)
		return out
	out.append(result.duplicate(true))
	return out

func owned_hive_counts_by_owner(state_ref: Object) -> Dictionary:
	var counts: Dictionary = {}
	if state_ref == null:
		return counts
	var hives_any: Variant = state_ref.get("hives")
	if typeof(hives_any) != TYPE_ARRAY:
		return counts
	for hive_any in hives_any as Array:
		if hive_any == null:
			continue
		var owner_id: int = 0
		if typeof(hive_any) == TYPE_DICTIONARY:
			owner_id = int((hive_any as Dictionary).get("owner_id", 0))
		elif hive_any is Object:
			owner_id = int((hive_any as Object).get("owner_id"))
		if owner_id <= 0:
			continue
		counts[owner_id] = int(counts.get(owner_id, 0)) + 1
	return counts

func resolve_stage_opponent_owner_id(owned_by_owner: Dictionary, local_owner_id: int, winner_id_in: int) -> int:
	if winner_id_in > 0 and winner_id_in != local_owner_id:
		return winner_id_in
	var best_owner: int = 0
	var best_owned: int = -1
	for owner_any in owned_by_owner.keys():
		var owner_id: int = int(owner_any)
		if owner_id <= 0 or owner_id == local_owner_id:
			continue
		var owned: int = int(owned_by_owner.get(owner_id, 0))
		if owned > best_owned:
			best_owned = owned
			best_owner = owner_id
	return best_owner

func stage_rank_snapshot(results: Array, local_owner_id: int) -> Dictionary:
	var stats_by_owner: Dictionary = {}
	for result_any in results:
		if typeof(result_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = result_any as Dictionary
		var winner: int = int(row.get("winner_id", 0))
		var elapsed_ms: int = maxi(0, int(row.get("elapsed_ms", 0)))
		var row_local_owner: int = int(row.get("local_owner_id", local_owner_id))
		var row_opponent_owner: int = int(row.get("opponent_owner_id", 0))
		var row_local_owned: int = maxi(0, int(row.get("local_owned_hives", 0)))
		var row_opponent_owned: int = maxi(0, int(row.get("opponent_owned_hives", 0)))
		_stage_stats_add(stats_by_owner, row_local_owner, row_local_owned, elapsed_ms, winner == row_local_owner)
		_stage_stats_add(stats_by_owner, row_opponent_owner, row_opponent_owned, elapsed_ms, winner == row_opponent_owner)
	var owners: Array = stats_by_owner.keys()
	owners.sort_custom(func(a, b):
		var a_id: int = int(a)
		var b_id: int = int(b)
		var a_stats: Dictionary = stats_by_owner.get(a_id, {})
		var b_stats: Dictionary = stats_by_owner.get(b_id, {})
		var a_wins: int = int(a_stats.get("wins", 0))
		var b_wins: int = int(b_stats.get("wins", 0))
		if a_wins != b_wins:
			return a_wins > b_wins
		var a_owned: int = int(a_stats.get("owned", 0))
		var b_owned: int = int(b_stats.get("owned", 0))
		if a_owned != b_owned:
			return a_owned > b_owned
		var a_elapsed: int = int(a_stats.get("elapsed_ms", 0))
		var b_elapsed: int = int(b_stats.get("elapsed_ms", 0))
		if a_elapsed != b_elapsed:
			return a_elapsed < b_elapsed
		return a_id < b_id
	)
	var rank: int = 0
	for i in range(owners.size()):
		if int(owners[i]) == local_owner_id:
			rank = i + 1
			break
	var local_wins: int = int((stats_by_owner.get(local_owner_id, {}) as Dictionary).get("wins", 0))
	var local_elapsed_ms: int = int((stats_by_owner.get(local_owner_id, {}) as Dictionary).get("elapsed_ms", 0))
	var opponent_wins: int = 0
	var opponent_elapsed_ms: int = 0
	for owner_any in owners:
		var owner_id: int = int(owner_any)
		if owner_id == local_owner_id:
			continue
		opponent_wins = int((stats_by_owner.get(owner_id, {}) as Dictionary).get("wins", 0))
		opponent_elapsed_ms = int((stats_by_owner.get(owner_id, {}) as Dictionary).get("elapsed_ms", 0))
		break
	return {
		"rank": rank,
		"local_wins": local_wins,
		"opponent_wins": opponent_wins,
		"local_elapsed_ms": local_elapsed_ms,
		"opponent_elapsed_ms": opponent_elapsed_ms
	}

func _stage_stats_add(stats_by_owner: Dictionary, owner_id: int, owned_delta: int, elapsed_ms_delta: int, won_round: bool) -> void:
	if owner_id <= 0:
		return
	var stats: Dictionary = stats_by_owner.get(owner_id, {
		"wins": 0,
		"owned": 0,
		"elapsed_ms": 0
	})
	stats["wins"] = int(stats.get("wins", 0)) + (1 if won_round else 0)
	stats["owned"] = int(stats.get("owned", 0)) + maxi(0, owned_delta)
	stats["elapsed_ms"] = int(stats.get("elapsed_ms", 0)) + maxi(0, elapsed_ms_delta)
	stats_by_owner[owner_id] = stats
