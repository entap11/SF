class_name MissNOutBannerRuntime
extends RefCounted

var _runtime_sig_cache: int = 0

func refresh(tree: SceneTree, contest_state: Node, force: bool = false) -> Dictionary:
	if tree == null:
		return {"changed": false, "visible": false, "notice": ""}
	var sig: int = _runtime_signature(tree)
	if not force and sig == _runtime_sig_cache:
		return {"changed": false, "visible": false, "notice": ""}
	_runtime_sig_cache = sig
	var show_banner: bool = false
	var notice: String = ""
	if tree.has_meta("miss_n_out_eliminated") and bool(tree.get_meta("miss_n_out_eliminated")):
		show_banner = true
		notice = str(tree.get_meta("miss_n_out_notice", "Eliminated. You can keep playing or return to lobby."))
	if not show_banner and tree.has_meta("miss_n_out_result") and tree.has_meta("miss_n_out_local_player_id"):
		if contest_state != null and contest_state.has_method("miss_n_out_player_status"):
			var result: Dictionary = tree.get_meta("miss_n_out_result", {}) as Dictionary
			var player_id: String = str(tree.get_meta("miss_n_out_local_player_id", ""))
			var status: Dictionary = contest_state.call("miss_n_out_player_status", result, player_id) as Dictionary
			if bool(status.get("eliminated", false)):
				show_banner = true
				notice = str(status.get("notice", "Eliminated. You can keep playing or return to lobby."))
	if show_banner and notice.is_empty():
		notice = "Eliminated. You can keep playing or return to lobby."
	return {"changed": true, "visible": show_banner, "notice": notice}

func _runtime_signature(tree: SceneTree) -> int:
	if tree == null:
		return 0
	var eliminated: bool = bool(tree.get_meta("miss_n_out_eliminated", false))
	var notice: String = str(tree.get_meta("miss_n_out_notice", ""))
	var local_player: String = str(tree.get_meta("miss_n_out_local_player_id", ""))
	var result_hash: int = 0
	if tree.has_meta("miss_n_out_result"):
		result_hash = hash(tree.get_meta("miss_n_out_result", {}))
	return hash([eliminated, notice, local_player, result_hash])
