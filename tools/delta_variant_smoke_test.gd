extends SceneTree


const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const DELTA_B_PATH := "res://maps/delta/MAP_delta__SBASE__BR3__3p.json"
const DELTA_T_PATH := "res://maps/delta/MAP_delta__SBASE__TR3__3p.json"
const SHARED_CONTROL_HIVE_ID := 6


func _initialize() -> void:
	var barracks_model: Dictionary = _load_map(DELTA_B_PATH)
	var towers_model: Dictionary = _load_map(DELTA_T_PATH)

	_assert_counts(barracks_model, 0, 3, "Delta barracks variant")
	_assert_counts(towers_model, 3, 0, "Delta tower variant")
	_assert_shared_center_control(barracks_model.get("barracks", []), "Delta barracks variant")
	_assert_shared_center_control(towers_model.get("towers", []), "Delta tower variant")

	print("DELTA_VARIANT_SMOKE_TEST: PASS")
	quit(0)


func _load_map(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if file == null:
		push_error("Failed to open %s" % path)
		quit(1)
		return {}
	var raw: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(raw) != OK:
		push_error("Failed to parse %s" % path)
		quit(1)
		return {}
	var source_any: Variant = json.data
	if typeof(source_any) != TYPE_DICTIONARY:
		push_error("Unexpected JSON root for %s" % path)
		quit(1)
		return {}
	var source: Dictionary = source_any as Dictionary
	var expanded: Dictionary = MAP_LOADER._expand_v1xy_compact_if_needed(source, path)
	var model: Dictionary = MAP_LOADER._load_v1xy(expanded, path)
	if model.is_empty():
		push_error("Failed to load model for %s" % path)
		quit(1)
		return {}
	return model


func _assert_counts(model: Dictionary, expected_towers: int, expected_barracks: int, label: String) -> void:
	var towers: Array = model.get("towers", [])
	var barracks: Array = model.get("barracks", [])
	if towers.size() != expected_towers or barracks.size() != expected_barracks:
		push_error("%s counts wrong: towers=%d barracks=%d" % [label, towers.size(), barracks.size()])
		quit(1)
		return


func _assert_shared_center_control(structures: Array, label: String) -> void:
	if structures.size() != 3:
		push_error("%s expected 3 structures, got %d" % [label, structures.size()])
		quit(1)
		return
	for structure_any: Variant in structures:
		if typeof(structure_any) != TYPE_DICTIONARY:
			push_error("%s contains non-dictionary structure" % label)
			quit(1)
			return
		var structure: Dictionary = structure_any as Dictionary
		var control_ids: Array = structure.get("control_hive_ids", [])
		var has_shared_control: bool = false
		for control_id_any: Variant in control_ids:
			if int(control_id_any) == SHARED_CONTROL_HIVE_ID:
				has_shared_control = true
				break
		if not has_shared_control:
			push_error("%s structure %s does not share control hive %d" % [
				label,
				str(structure.get("id", "?")),
				SHARED_CONTROL_HIVE_ID
			])
			quit(1)
			return
