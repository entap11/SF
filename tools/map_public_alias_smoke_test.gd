extends SceneTree

const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const JukeboxStateScript := preload("res://scripts/state/jukebox_state.gd")

func _init() -> void:
	await process_frame

	var failures: Array[String] = []
	_expect_display(
		failures,
		"MAP_nomansland__SBASE__1p",
		"nomansland656-1"
	)
	_expect_display(
		failures,
		"MAP_nomansland__SN6__1p",
		"nomansland656-2"
	)
	_expect_display(
		failures,
		"MAP_nomansland__GBASE__1p",
		"nomansland656-3"
	)
	_expect_display(
		failures,
		"MAP_nomansland__GBASE__BR2__TR2__1p",
		"nomansland656-4"
	)
	_expect_display(
		failures,
		"MAP_nomansland__GBASE__TB__1p",
		"nomansland656-5"
	)
	_expect_display(
		failures,
		"MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each",
		"nomansland656-6"
	)
	_expect_display(
		failures,
		"MAP_nomansland__545__v01_top2_sides__1p",
		"nomansland545-1"
	)
	_expect_display(
		failures,
		"MAP_nomansland__545__v01_top2_sides__B__1p",
		"nomansland545-1-b"
	)
	_expect_display(
		failures,
		"MAP_delta__SBASE__3p",
		"delta"
	)
	_expect_display(
		failures,
		"MAP_delta__SBASE__BR3__3p",
		"delta1"
	)
	_expect_display(
		failures,
		"MAP_delta__SBASE__TR3__3p",
		"delta2"
	)
	_check_alias_uniqueness(failures)
	_check_catalog_alias_coverage(failures)
	_check_jukebox_public_titles(failures)
	_check_jukebox_playstyle_tags(failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("MAP_PUBLIC_ALIAS_SMOKE: %s" % failure)
		push_error("MAP_PUBLIC_ALIAS_SMOKE: %d failure(s)" % failures.size())
		quit(1)
		return

	print("MAP_PUBLIC_ALIAS_SMOKE: PASS aliases=%d" % MAP_REGISTRY.registered_public_map_aliases().size())
	quit(0)

func _expect_display(failures: Array[String], map_id: String, expected: String) -> void:
	var actual: String = MAP_REGISTRY.public_map_display_name_for_id(map_id)
	if actual != expected:
		failures.append("expected %s -> %s, got %s" % [map_id, expected, actual])

func _check_alias_uniqueness(failures: Array[String]) -> void:
	var names_seen: Dictionary = {}
	var family_sequences_seen: Dictionary = {}
	for entry in MAP_REGISTRY.registered_public_map_aliases():
		var public_name: String = str(entry.get("public_name", "")).strip_edges()
		var family: String = str(entry.get("family", "")).strip_edges().to_lower()
		var style: String = str(entry.get("style", "")).strip_edges().to_lower()
		var sequence: int = int(entry.get("style_sequence", entry.get("sequence", 0)))
		if public_name.is_empty():
			failures.append("empty public name for %s" % str(entry.get("map_id", "")))
		if bool(names_seen.get(public_name, false)):
			failures.append("duplicate public name: %s" % public_name)
		names_seen[public_name] = true
		var family_sequence_key: String = "%s:%s:%d" % [family, style, sequence]
		if bool(family_sequences_seen.get(family_sequence_key, false)):
			failures.append("duplicate public sequence: %s" % family_sequence_key)
		family_sequences_seen[family_sequence_key] = true

func _check_catalog_alias_coverage(failures: Array[String]) -> void:
	for path_any in MAP_LOADER.list_maps():
		var path: String = str(path_any)
		var map_id: String = MAP_REGISTRY.map_id_from_path(path)
		if not MAP_REGISTRY.has_public_map_alias_for_id(map_id):
			failures.append("public map has no stable alias: %s" % map_id)

func _check_jukebox_public_titles(failures: Array[String]) -> void:
	var jukebox_state = JukeboxStateScript.new()
	jukebox_state.refresh()
	var entries: Array[Dictionary] = jukebox_state.catalog("ALL")
	if entries.is_empty():
		failures.append("jukebox catalog is empty")
		return
	var title_sequence: Array[String] = []
	var seen_titles: Dictionary = {}
	for entry in entries:
		var map_id: String = str(entry.get("map_id", ""))
		var title: String = str(entry.get("title", ""))
		var expected: String = MAP_REGISTRY.public_map_display_name_for_id(map_id)
		if title != expected:
			failures.append("jukebox title mismatch for %s: expected %s got %s" % [map_id, expected, title])
		var title_key: String = title.to_lower()
		if seen_titles.has(title_key):
			failures.append("jukebox duplicate title: %s" % title)
		seen_titles[title_key] = true
		if _looks_internal(title):
			failures.append("jukebox title leaks internal naming: %s" % title)
		if not str(entry.get("hero_title", "")).strip_edges().is_empty():
			failures.append("jukebox hero title should be empty for %s: %s" % [map_id, str(entry.get("hero_title", ""))])
		if not str(entry.get("meta", "")).strip_edges().is_empty():
			failures.append("jukebox meta should be empty for %s: %s" % [map_id, str(entry.get("meta", ""))])
		if not str(entry.get("desc", "")).strip_edges().is_empty():
			failures.append("jukebox description should be empty for %s: %s" % [map_id, str(entry.get("desc", ""))])
		title_sequence.append(title)
	var expected_prefix: Array[String] = [
		"delta",
		"delta1",
		"delta2",
		"nomansland656-1",
		"nomansland656-2",
		"nomansland656-3",
		"nomansland656-4",
		"nomansland656-5",
		"nomansland656-6"
	]
	for i in range(mini(expected_prefix.size(), title_sequence.size())):
		if title_sequence[i] != expected_prefix[i]:
			failures.append("jukebox sort mismatch at %d: expected %s got %s" % [i, expected_prefix[i], title_sequence[i]])

func _check_jukebox_playstyle_tags(failures: Array[String]) -> void:
	var jukebox_state = JukeboxStateScript.new()
	jukebox_state.refresh()
	var nomansland_entries: Array[Dictionary] = jukebox_state.catalog("NOMANSLAND")
	if nomansland_entries.is_empty():
		failures.append("jukebox nomansland catalog is empty")
		return
	var first_entry: Dictionary = nomansland_entries[0]
	var playstyle_tags: Array = first_entry.get("playstyle_tags", []) as Array
	if not playstyle_tags.has("FFA") or not playstyle_tags.has("STRATEGY"):
		failures.append("nomansland playstyle tags missing FFA/STRATEGY: %s" % str(playstyle_tags))
	var ffa_entries: Array[Dictionary] = jukebox_state.catalog("FFA")
	if ffa_entries.is_empty():
		failures.append("jukebox FFA catalog is empty")
	var strategy_entries: Array[Dictionary] = jukebox_state.catalog("STRATEGY")
	if strategy_entries.is_empty():
		failures.append("jukebox STRATEGY catalog is empty")
	var delta_entries: Array[Dictionary] = jukebox_state.catalog("DELTA")
	if delta_entries.size() < 3:
		failures.append("jukebox DELTA catalog expected at least 3 entries, got %d" % delta_entries.size())

func _looks_internal(text: String) -> bool:
	var upper: String = text.to_upper()
	return upper.contains("MAP_") or upper.contains("__") or upper.contains("SBASE") or upper.contains("GBASE") or upper.contains("SN6")
