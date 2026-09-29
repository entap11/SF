class_name BotRulesetVisibilityAdapter
extends RefCounted

const SCHEMA_VERSION: int = 1


func build_context(ops_state: Object, seat: int) -> Dictionary:
	var mode := "conquest"
	var rules: Dictionary = {}
	var team_by_seat: Dictionary = {}
	if ops_state != null:
		if ops_state.has_method("get_victory_mode"):
			mode = str(ops_state.call("get_victory_mode"))
		if ops_state.has_method("get_victory_rules"):
			var rules_any: Variant = ops_state.call("get_victory_rules")
			if typeof(rules_any) == TYPE_DICTIONARY:
				rules = (rules_any as Dictionary).duplicate(true)
		if ops_state.has_method("get_team_by_seat_snapshot"):
			var teams_any: Variant = ops_state.call("get_team_by_seat_snapshot")
			if typeof(teams_any) == TYPE_DICTIONARY:
				team_by_seat = (teams_any as Dictionary).duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"seat": seat,
		"mode": mode,
		"team_by_seat": team_by_seat,
		"hide_opponent_power": bool(rules.get("hide_opponent_power", false)),
		"hidden_objectives": bool(rules.get("hidden_flag", false))
	}


func visible_hive(hive: HiveData, seat: int, context: Dictionary) -> Dictionary:
	var power: int = int(hive.power)
	var owner_id: int = int(hive.owner_id)
	var team_by_seat: Dictionary = context.get("team_by_seat", {}) as Dictionary
	var viewer_team: int = int(team_by_seat.get(seat, seat))
	var owner_team: int = int(team_by_seat.get(owner_id, owner_id))
	var is_visible_owner: bool = owner_id <= 0 or owner_id == seat or owner_team == viewer_team
	if not is_visible_owner and bool(context.get("hide_opponent_power", false)):
		power = -1
	return {
		"id": int(hive.id),
		"owner_id": owner_id,
		"power": power,
		"kind": str(hive.kind),
		"grid_x": int(hive.grid_pos.x),
		"grid_y": int(hive.grid_pos.y)
	}
