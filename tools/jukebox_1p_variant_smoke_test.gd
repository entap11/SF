extends SceneTree

const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")

func _init() -> void:
	await process_frame

	var failures: Array[String] = []
	var jukebox_state = JukeboxStateScript.new()
	jukebox_state.refresh()
	var entries: Array[Dictionary] = jukebox_state.catalog("ALL")
	if entries.is_empty():
		failures.append("jukebox catalog is empty")
	var checked: int = 0
	for entry in entries:
		var source_path: String = str(entry.get("source_path", "")).strip_edges()
		var path: String = str(entry.get("path", "")).strip_edges()
		if path.ends_with("__1p.json") and int(entry.get("async_bot_count", -1)) != 1:
			failures.append("jukebox 1p entry should have one bot: %s count=%d" % [path, int(entry.get("async_bot_count", -1))])
		if not source_path.ends_with("__4p.json"):
			continue
		checked += 1
		if not path.ends_with("__1p.json"):
			failures.append("4p source did not resolve to 1p variant: %s -> %s" % [source_path, path])
		if int(entry.get("async_bot_count", -1)) != 1:
			failures.append("1p jukebox variant should have one bot: %s count=%d" % [path, int(entry.get("async_bot_count", -1))])
		var owner_counts: Dictionary = entry.get("owner_counts", {}) as Dictionary
		if int(owner_counts.get(1, 0)) < 1 or int(owner_counts.get(2, 0)) < 1:
			failures.append("1p jukebox variant missing P1/P2 hives: %s owners=%s" % [path, str(owner_counts)])
		if int(owner_counts.get(3, 0)) != 0 or int(owner_counts.get(4, 0)) != 0:
			failures.append("1p jukebox variant should not keep P3/P4 hives: %s owners=%s" % [path, str(owner_counts)])
	if checked <= 0:
		failures.append("no 4p-backed jukebox entries were checked")

	if not failures.is_empty():
		for failure in failures:
			push_error("JUKEBOX_1P_VARIANT_SMOKE: %s" % failure)
		push_error("JUKEBOX_1P_VARIANT_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return

	print("JUKEBOX_1P_VARIANT_SMOKE: PASS checked=%d" % checked)
	quit(0)
