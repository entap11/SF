class_name RankPercentileCalculator
extends RefCounted

func sort_player_ids_desc(players_by_id: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for player_id_any in players_by_id.keys():
		var player_id: String = str(player_id_any)
		if player_id == "":
			continue
		ids.append(player_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var a_record: Dictionary = players_by_id.get(a, {}) as Dictionary
		var b_record: Dictionary = players_by_id.get(b, {}) as Dictionary
		var a_wax: float = float(a_record.get("wax_score", 0.0))
		var b_wax: float = float(b_record.get("wax_score", 0.0))
		if is_equal_approx(a_wax, b_wax):
			return a < b
		return a_wax > b_wax
	)
	return ids

func build_percentile_map(sorted_ids_desc: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var count: int = maxi(1, sorted_ids_desc.size())
	if count == 1:
		out[sorted_ids_desc[0]] = {
			"rank_position": 1,
			"percentile": 1.0
		}
		return out
	for i in range(sorted_ids_desc.size()):
		var player_id: String = sorted_ids_desc[i]
		var rank_position: int = i + 1
		var percentile: float = 1.0 - (float(i) / float(count - 1))
		out[player_id] = {
			"rank_position": rank_position,
			"percentile": clampf(percentile, 0.0, 1.0)
		}
	return out
