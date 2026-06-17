extends SceneTree

const PolicyScript: Script = preload("res://scripts/renderers/arena_polish_placement_policy.gd")
const LayerScript: Script = preload("res://scripts/renderers/arena_polish_layer.gd")

var _failed: bool = false

func _initialize() -> void:
	await process_frame

	var safe_zones: PackedStringArray = PolicyScript.call("safe_zones") as PackedStringArray
	var forbidden_zones: PackedStringArray = PolicyScript.call("forbidden_zones") as PackedStringArray
	_expect_true("arena_dead_space" in safe_zones, "arena_dead_space should be a safe placement zone")
	_expect_true("corner_atmosphere" in safe_zones, "corner_atmosphere should be a safe placement zone")
	_expect_true("active_lane_core" in forbidden_zones, "active_lane_core should be forbidden")
	_expect_true("hive_body" in forbidden_zones, "hive_body should be forbidden")
	_expect_true("ui" in forbidden_zones, "ui should be forbidden")
	_expect_true(bool(PolicyScript.call("is_safe_zone", "lane_edges")), "lane_edges should be accepted as safe")
	_expect_true(bool(PolicyScript.call("is_forbidden_zone", "tap_target_area")), "tap_target_area should be forbidden")

	var manifest: Dictionary = LayerScript.call("load_manifest_from_path", "res://assets/sprites/arena_polish/arena_polish_manifest.json") as Dictionary
	var manifest_errors: PackedStringArray = LayerScript.call("validate_manifest", manifest) as PackedStringArray
	_expect_true(manifest_errors.is_empty(), "Tracked arena polish manifest should satisfy placement policy")

	var defaults: Dictionary = manifest.get("defaults", {}) as Dictionary
	var unsafe_entry: Dictionary = {
		"id": "unsafe_lane_core",
		"texture": "res://assets/sprites/arena_polish/props/fake.png",
		"allowed_placement_zones": ["active_lane_core"],
		"forbidden_overlap": ["active_lane_core", "hive_body", "ui"],
		"max_instances": 1,
		"affects_gameplay": false
	}
	var unsafe_errors: PackedStringArray = PackedStringArray()
	PolicyScript.call("validate_entry", unsafe_errors, "props_0", unsafe_entry, defaults)
	_expect_true(_has_error_containing(unsafe_errors, "uses_forbidden_zone_active_lane_core"), "Policy should reject active lane core placement")

	var unknown_entry: Dictionary = unsafe_entry.duplicate(true)
	unknown_entry["allowed_placement_zones"] = ["mystery_zone"]
	var unknown_errors: PackedStringArray = PackedStringArray()
	PolicyScript.call("validate_entry", unknown_errors, "props_1", unknown_entry, defaults)
	_expect_true(_has_error_containing(unknown_errors, "unknown_zone_mystery_zone"), "Policy should reject unknown placement zones")

	var high_z_entry: Dictionary = unsafe_entry.duplicate(true)
	high_z_entry["allowed_placement_zones"] = ["arena_dead_space"]
	high_z_entry["z_index"] = 1
	var high_z_errors: PackedStringArray = PackedStringArray()
	PolicyScript.call("validate_entry", high_z_errors, "props_2", high_z_entry, defaults)
	_expect_true(_has_error_containing(high_z_errors, "z_index_above_safe_max"), "Policy should reject gameplay-level z-indexes")

	var safe_entry: Dictionary = unsafe_entry.duplicate(true)
	safe_entry["id"] = "safe_corner_debris"
	safe_entry["allowed_placement_zones"] = ["corner_atmosphere", "outer_floor_edges"]
	safe_entry["z_index"] = -15
	var safe_errors: PackedStringArray = PackedStringArray()
	PolicyScript.call("validate_entry", safe_errors, "props_3", safe_entry, defaults)
	_expect_true(safe_errors.is_empty(), "Policy should accept safe decorative placement metadata")

	if not _failed:
		print("ARENA_POLISH_PLACEMENT_POLICY_SMOKE: PASS")
	quit(1 if _failed else 0)

func _has_error_containing(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if str(error).contains(needle):
			return true
	return false

func _expect_true(value: bool, message: String) -> void:
	if value:
		return
	_failed = true
	push_error("ARENA_POLISH_PLACEMENT_POLICY_SMOKE: %s" % message)
