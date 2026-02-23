class_name RankLeaderboardManager
extends RefCounted

const RankConfigScript = preload("res://scripts/state/rank_config.gd")

func build_view(
		players_by_id: Dictionary,
		sorted_ids_desc: Array[String],
		requester_id: String,
		filter_name: String,
		limit: int,
		config: RankConfigScript
	) -> Dictionary:
	var filtered_ids: Array[String] = _filter_ids(players_by_id, sorted_ids_desc, requester_id, filter_name)
	var rows: Array[Dictionary] = []
	var safe_limit: int = maxi(1, limit)
	for i in range(mini(filtered_ids.size(), safe_limit)):
		var player_id: String = filtered_ids[i]
		var record: Dictionary = players_by_id.get(player_id, {}) as Dictionary
		var rank_global: int = int(record.get("rank_position", i + 1))
		var wax_score: float = float(record.get("wax_score", 0.0))
		var wax_gap_to_above: float = _wax_gap_to_above(players_by_id, sorted_ids_desc, player_id)
		var wax_gap_to_below: float = _wax_gap_to_below(players_by_id, sorted_ids_desc, player_id)
		rows.append({
			"rank_filtered": i + 1,
			"rank_global": rank_global,
			"player_id": player_id,
			"display_name": str(record.get("display_name", player_id)),
			"region": str(record.get("region", "GLOBAL")),
			"wax_score": wax_score,
			"tier_id": str(record.get("tier_id", "DRONE")),
			"color_id": str(record.get("color_id", "GREEN")),
			"percentile": float(record.get("percentile", 0.0)),
			"apex_active": bool(record.get("apex_active", false)),
			"wax_gap_to_above": wax_gap_to_above,
			"wax_gap_to_below": wax_gap_to_below
		})
	var local_context: Dictionary = _build_local_context(players_by_id, sorted_ids_desc, requester_id, config)
	return {
		"filter": filter_name,
		"rows": rows,
		"local_context": local_context
	}

func _build_local_context(
		players_by_id: Dictionary,
		sorted_ids_desc: Array[String],
		requester_id: String,
		config: RankConfigScript
	) -> Dictionary:
	var record: Dictionary = players_by_id.get(requester_id, {}) as Dictionary
	if record.is_empty():
		return {}
	var rank_position: int = int(record.get("rank_position", 0))
	var tier_id: String = str(record.get("tier_id", "DRONE"))
	var tier_idx: int = config.tier_index(tier_id)
	var target_rank: int = 0
	for player_id in sorted_ids_desc:
		var row: Dictionary = players_by_id.get(player_id, {}) as Dictionary
		var row_rank: int = int(row.get("rank_position", 0))
		if row_rank <= 0 or row_rank >= rank_position:
			continue
		var row_tier_idx: int = config.tier_index(str(row.get("tier_id", "DRONE")))
		if row_tier_idx > tier_idx:
			target_rank = row_rank
			break
	var places_to_next_tier: int = 0
	if target_rank > 0:
		places_to_next_tier = rank_position - target_rank
	var neighbors: Dictionary = _neighbors(players_by_id, sorted_ids_desc, requester_id)
	return {
		"rank_position": rank_position,
		"wax_score": float(record.get("wax_score", 0.0)),
		"tier_id": tier_id,
		"color_id": str(record.get("color_id", "GREEN")),
		"percentile": float(record.get("percentile", 0.0)),
		"places_to_next_tier": places_to_next_tier,
		"neighbors": neighbors,
		"wax_gap_to_next_player": float(neighbors.get("wax_gap_to_above", 0.0))
	}

func _neighbors(players_by_id: Dictionary, sorted_ids_desc: Array[String], requester_id: String) -> Dictionary:
	var idx: int = -1
	for i in range(sorted_ids_desc.size()):
		if sorted_ids_desc[i] == requester_id:
			idx = i
			break
	if idx < 0:
		return {}
	var out: Dictionary = {}
	if idx > 0:
		var above_id: String = sorted_ids_desc[idx - 1]
		var above_record: Dictionary = players_by_id.get(above_id, {}) as Dictionary
		var requester_record: Dictionary = players_by_id.get(requester_id, {}) as Dictionary
		var requester_wax: float = float(requester_record.get("wax_score", 0.0))
		var above_wax: float = float(above_record.get("wax_score", requester_wax))
		out["above"] = {
			"player_id": above_id,
			"display_name": str(above_record.get("display_name", above_id)),
			"wax_score": above_wax,
			"rank_position": int(above_record.get("rank_position", 0))
		}
		out["wax_gap_to_above"] = maxf(0.0, above_wax - requester_wax)
	if idx + 1 < sorted_ids_desc.size():
		var below_id: String = sorted_ids_desc[idx + 1]
		var below_record: Dictionary = players_by_id.get(below_id, {}) as Dictionary
		out["below"] = {
			"player_id": below_id,
			"display_name": str(below_record.get("display_name", below_id)),
			"wax_score": float(below_record.get("wax_score", 0.0)),
			"rank_position": int(below_record.get("rank_position", 0))
		}
	return out

func _filter_ids(players_by_id: Dictionary, sorted_ids_desc: Array[String], requester_id: String, filter_name: String) -> Array[String]:
	var filter_key: String = filter_name.strip_edges().to_upper()
	if filter_key == "GLOBAL":
		return sorted_ids_desc.duplicate()

	var requester_record: Dictionary = players_by_id.get(requester_id, {}) as Dictionary
	if requester_record.is_empty():
		return sorted_ids_desc.duplicate()

	if filter_key == "REGION":
		var region: String = str(requester_record.get("region", "GLOBAL"))
		var region_rows: Array[String] = []
		for player_id in sorted_ids_desc:
			var row: Dictionary = players_by_id.get(player_id, {}) as Dictionary
			if str(row.get("region", "GLOBAL")) != region:
				continue
			region_rows.append(player_id)
		return region_rows

	if filter_key == "FRIENDS":
		var friend_ids: Array[String] = []
		var friends_any: Variant = requester_record.get("friends", [])
		if typeof(friends_any) == TYPE_ARRAY:
			for friend_any in friends_any as Array:
				var friend_id: String = str(friend_any).strip_edges()
				if friend_id == "":
					continue
				if friend_ids.has(friend_id):
					continue
				friend_ids.append(friend_id)
		var friend_rows: Array[String] = []
		for player_id in sorted_ids_desc:
			if player_id == requester_id or friend_ids.has(player_id):
				friend_rows.append(player_id)
		return friend_rows

	return sorted_ids_desc.duplicate()

func _wax_gap_to_above(players_by_id: Dictionary, sorted_ids_desc: Array[String], player_id: String) -> float:
	for i in range(sorted_ids_desc.size()):
		if sorted_ids_desc[i] != player_id:
			continue
		if i == 0:
			return 0.0
		var record: Dictionary = players_by_id.get(player_id, {}) as Dictionary
		var above: Dictionary = players_by_id.get(sorted_ids_desc[i - 1], {}) as Dictionary
		var wax_now: float = float(record.get("wax_score", 0.0))
		var wax_above: float = float(above.get("wax_score", wax_now))
		return maxf(0.0, wax_above - wax_now)
	return 0.0

func _wax_gap_to_below(players_by_id: Dictionary, sorted_ids_desc: Array[String], player_id: String) -> float:
	for i in range(sorted_ids_desc.size()):
		if sorted_ids_desc[i] != player_id:
			continue
		if i + 1 >= sorted_ids_desc.size():
			return 0.0
		var record: Dictionary = players_by_id.get(player_id, {}) as Dictionary
		var below: Dictionary = players_by_id.get(sorted_ids_desc[i + 1], {}) as Dictionary
		var wax_now: float = float(record.get("wax_score", 0.0))
		var wax_below: float = float(below.get("wax_score", wax_now))
		return maxf(0.0, wax_now - wax_below)
	return 0.0
