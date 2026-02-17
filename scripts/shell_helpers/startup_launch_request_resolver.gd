class_name ShellStartupLaunchRequestResolver
extends RefCounted

func resolve(tree: SceneTree, gamebot: Node) -> Dictionary:
	var request: Dictionary = {
		"start": false,
		"map_path": "",
		"reason": "none"
	}
	if tree == null:
		return request
	var start_requested: bool = bool(tree.get_meta("start_game", false))
	if not start_requested:
		return request
	if tree.has_meta("start_game"):
		tree.remove_meta("start_game")
	request["start"] = true
	var stage_map_path: String = resolve_stage_map_from_tree_meta(tree)
	if stage_map_path != "":
		request["map_path"] = stage_map_path
		request["reason"] = "stage_meta"
		return request
	if gamebot != null:
		var gamebot_map_path: String = str(gamebot.get("next_map_id")).strip_edges()
		if gamebot_map_path != "":
			request["map_path"] = gamebot_map_path
			request["reason"] = "gamebot_next_map"
			return request
	request["reason"] = "start_flag_no_map"
	return request

func resolve_stage_map_from_tree_meta(tree: SceneTree) -> String:
	if tree == null or not tree.has_meta("vs_stage_map_paths"):
		return ""
	var stage_maps_any: Variant = tree.get_meta("vs_stage_map_paths", [])
	if typeof(stage_maps_any) != TYPE_ARRAY:
		return ""
	var stage_maps: Array = stage_maps_any as Array
	if stage_maps.is_empty():
		return ""
	var index_raw: int = int(tree.get_meta("vs_stage_current_index", 0))
	var index: int = clampi(index_raw, 0, stage_maps.size() - 1)
	return str(stage_maps[index]).strip_edges()
