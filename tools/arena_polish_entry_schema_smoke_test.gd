extends SceneTree

const LayerScript: Script = preload("res://scripts/renderers/arena_polish_layer.gd")

var _failed: bool = false

func _initialize() -> void:
	await process_frame

	var required: PackedStringArray = LayerScript.call("entry_required_fields") as PackedStringArray
	for field in ["id", "texture", "allowed_placement_zones", "max_instances", "opacity_range", "scale_range", "z_index"]:
		_expect_true(field in required, "Required field should be exposed: %s" % field)

	var manifest: Dictionary = LayerScript.call("load_manifest_from_path", "res://assets/sprites/arena_polish/arena_polish_manifest.json") as Dictionary
	var schema: Dictionary = manifest.get("entry_schema", {}) as Dictionary
	_expect_true(schema.has("required"), "Manifest should document required asset entry fields")
	_expect_true(schema.has("texture_roots"), "Manifest should document per-kind texture roots")
	var manifest_errors: PackedStringArray = LayerScript.call("validate_manifest", manifest) as PackedStringArray
	_expect_true(manifest_errors.is_empty(), "Empty tracked manifest should validate against entry schema")

	var defaults: Dictionary = manifest.get("defaults", {}) as Dictionary
	var incomplete_entry: Dictionary = {
		"id": "missing_fields",
		"texture": "res://assets/sprites/arena_polish/props/missing.png"
	}
	var incomplete_errors: PackedStringArray = _validate_entry("props", 0, incomplete_entry, defaults)
	_expect_true(_has_error_containing(incomplete_errors, "allowed_placement_zones_missing"), "Entry schema should require placement zones")
	_expect_true(_has_error_containing(incomplete_errors, "max_instances_missing"), "Entry schema should require max instances")
	_expect_true(_has_error_containing(incomplete_errors, "opacity_range_missing"), "Entry schema should require opacity range")
	_expect_true(_has_error_containing(incomplete_errors, "scale_range_missing"), "Entry schema should require scale range")
	_expect_true(_has_error_containing(incomplete_errors, "z_index_missing"), "Entry schema should require z-index")

	var bad_id_entry: Dictionary = _complete_entry()
	bad_id_entry["id"] = "Bad Id"
	var bad_id_errors: PackedStringArray = _validate_entry("props", 1, bad_id_entry, defaults)
	_expect_true(_has_error_containing(bad_id_errors, "id_invalid"), "Entry schema should reject non snake_case ids")

	var wrong_folder_entry: Dictionary = _complete_entry()
	wrong_folder_entry["texture"] = "res://assets/sprites/arena_polish/vfx/debris.png"
	var wrong_folder_errors: PackedStringArray = _validate_entry("props", 2, wrong_folder_entry, defaults)
	_expect_true(_has_error_containing(wrong_folder_errors, "texture_wrong_kind_folder"), "Entry schema should reject texture paths outside the entry kind folder")

	var bad_animation_entry: Dictionary = _complete_entry()
	bad_animation_entry["animation"] = {
		"enabled": true,
		"fps": 90,
		"frames": 64
	}
	var bad_animation_errors: PackedStringArray = _validate_entry("props", 3, bad_animation_entry, defaults)
	_expect_true(_has_error_containing(bad_animation_errors, "animation_fps_out_of_bounds"), "Entry schema should cap animation fps")
	_expect_true(_has_error_containing(bad_animation_errors, "animation_frames_out_of_bounds"), "Entry schema should cap animation frame count")

	var bad_vfx_entry: Dictionary = _complete_entry()
	bad_vfx_entry["vfx"] = {
		"max_particles": 100,
		"spawn_rate_hz": 12.0
	}
	var bad_vfx_errors: PackedStringArray = _validate_entry("props", 4, bad_vfx_entry, defaults)
	_expect_true(_has_error_containing(bad_vfx_errors, "vfx_max_particles_too_high"), "Entry schema should cap max particles")
	_expect_true(_has_error_containing(bad_vfx_errors, "vfx_spawn_rate_too_high"), "Entry schema should cap vfx spawn rate")

	if not _failed:
		print("ARENA_POLISH_ENTRY_SCHEMA_SMOKE: PASS")
	quit(1 if _failed else 0)

func _complete_entry() -> Dictionary:
	return {
		"id": "safe_corner_debris",
		"texture": "res://assets/sprites/arena_polish/props/debris.png",
		"allowed_placement_zones": ["corner_atmosphere"],
		"forbidden_overlap": ["active_lane_core", "hive_body", "ui"],
		"max_instances": 3,
		"opacity_range": [0.35, 0.65],
		"scale_range": [0.8, 1.1],
		"z_index": -15,
		"affects_gameplay": false
	}

func _validate_entry(kind: String, index: int, entry: Dictionary, defaults: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	LayerScript.call("_validate_manifest_entry", errors, kind, index, entry, defaults)
	return errors

func _has_error_containing(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if str(error).contains(needle):
			return true
	return false

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("ARENA_POLISH_ENTRY_SCHEMA_SMOKE: %s" % message)
