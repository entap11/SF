extends RefCounted

static func should_show_opponent_buff_strips(tree: SceneTree) -> bool:
	if tree == null:
		return false
	if not bool(tree.get_meta("human_pvp", false)):
		return false
	var remote_profile_any: Variant = tree.get_meta("vs_remote_profile", {})
	if typeof(remote_profile_any) == TYPE_DICTIONARY:
		var remote_profile: Dictionary = remote_profile_any as Dictionary
		if bool(remote_profile.get("is_cpu", false)):
			return false
	return true
