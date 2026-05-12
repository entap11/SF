extends Node

const UnitRenderer := preload("res://scripts/renderers/unit_renderer.gd")

var _failed: bool = false

func _ready() -> void:
	await get_tree().process_frame
	var renderer: Node2D = UnitRenderer.new()
	add_child(renderer)
	renderer.use_multimesh_units = false
	renderer.bind_hives([
		{"id": 1, "x": 5, "y": 5, "owner_id": 1, "radius_px": 24.0},
		{"id": 2, "x": 5, "y": 1, "owner_id": 2, "radius_px": 24.0}
	], 1)
	await get_tree().process_frame

	var hive_by_id: Dictionary = renderer.call("_build_hive_by_id") as Dictionary
	var node := Node2D.new()
	renderer.add_child(node)
	var up_unit: Dictionary = {"id": 101, "from_id": 1, "to_id": 2, "a_id": 1, "b_id": 2, "dir": 1}
	var up_dir := Vector2.UP
	var source_boundary: Vector2 = renderer.call("_hive_shell_contact_world", 1, hive_by_id, up_dir) as Vector2
	node.global_position = source_boundary + (up_dir * 6.0)
	renderer.call("_update_target_hive_occlusion_depth", node, up_unit, hive_by_id, up_dir)
	_assert_true(not node.z_as_relative and int(node.z_index) == -2, "upward unit should stay behind source hive while clearing top edge")

	node.global_position = source_boundary + (up_dir * 30.0)
	renderer.call("_update_target_hive_occlusion_depth", node, up_unit, hive_by_id, up_dir)
	_assert_true(not node.z_as_relative and int(node.z_index) == -2, "upward unit should stay behind source hive until the sprite fully clears")

	node.global_position = source_boundary + (up_dir * 70.0)
	renderer.call("_update_target_hive_occlusion_depth", node, up_unit, hive_by_id, up_dir)
	_assert_true(not node.z_as_relative and int(node.z_index) == -2, "upward unit should stay behind source hive for the full emergence distance")

	node.global_position = source_boundary + (up_dir * 120.0)
	renderer.call("_update_target_hive_occlusion_depth", node, up_unit, hive_by_id, up_dir)
	_assert_true(node.z_as_relative and int(node.z_index) == 0, "upward unit should return to default depth after clearing top edge")

	var source_layer_close: String = str(renderer.call("_unit_batch_layer", up_unit, hive_by_id, source_boundary + (up_dir * 30.0), up_dir))
	var source_layer_clear: String = str(renderer.call("_unit_batch_layer", up_unit, hive_by_id, source_boundary + (up_dir * 120.0), up_dir))
	_assert_true(source_layer_close == "rear", "batched upward unit should use rear layer while clearing source hive")
	_assert_true(source_layer_clear == "main", "batched upward unit should return to main layer after clearing source hive")
	var source_occluded_close: bool = bool(renderer.call("_unit_hive_occlusion_active", up_unit, hive_by_id, source_boundary + (up_dir * 70.0), up_dir))
	var source_occluded_clear: bool = bool(renderer.call("_unit_hive_occlusion_active", up_unit, hive_by_id, source_boundary + (up_dir * 120.0), up_dir))
	_assert_true(source_occluded_close, "upward unit should remain rear-layered through the source emergence distance")
	_assert_true(not source_occluded_clear, "upward unit should leave the rear layer after clearing the source emergence distance")

	var down_unit: Dictionary = {"id": 102, "from_id": 2, "to_id": 1, "a_id": 1, "b_id": 2, "dir": -1}
	var down_dir := Vector2.DOWN
	var target_boundary: Vector2 = renderer.call("_target_hive_boundary_world", 1, hive_by_id, down_dir) as Vector2
	var down_endpoints: Dictionary = renderer.call("_unit_path_endpoints_map_local", down_unit, hive_by_id) as Dictionary
	_assert_true(bool(down_endpoints.get("ok", false)), "downward unit should resolve lane endpoints")
	var target_endpoint_world: Vector2 = renderer.to_global(down_endpoints.get("a", Vector2.ZERO) as Vector2)
	_assert_true(target_endpoint_world.distance_to(target_boundary) <= 0.5, "downward unit target endpoint should be the target back shell")
	node.global_position = target_boundary
	renderer.call("_update_target_hive_occlusion_depth", node, down_unit, hive_by_id, down_dir)
	_assert_true(not node.z_as_relative and int(node.z_index) == -2, "downward unit should render behind target hive at top edge")
	var target_occluded_close: bool = bool(renderer.call("_unit_hive_occlusion_active", down_unit, hive_by_id, target_boundary - (down_dir * 70.0), down_dir))
	var target_occluded_far: bool = bool(renderer.call("_unit_hive_occlusion_active", down_unit, hive_by_id, target_boundary - (down_dir * 120.0), down_dir))
	_assert_true(target_occluded_close, "downward unit should use the rear layer for the final emergence distance into target hive")
	_assert_true(not target_occluded_far, "downward unit should remain on the main layer before the final target occlusion distance")
	var alias_unit: Dictionary = {"id": 103, "from": 2, "to": 1, "a_id": 1, "b_id": 2, "dir": -1}
	var alias_occluded_close: bool = bool(renderer.call("_unit_hive_occlusion_active", alias_unit, hive_by_id, target_boundary - (down_dir * 70.0), down_dir))
	_assert_true(alias_occluded_close, "downward target occlusion should work with from/to aliases")

	if _failed:
		get_tree().quit(1)
		return
	print("UNIT_HIVE_OCCLUSION_SMOKE: PASS")
	get_tree().quit(0)

func _assert_true(value: bool, label: String) -> void:
	if value:
		return
	_failed = true
	push_error("UNIT_HIVE_OCCLUSION_SMOKE: %s" % label)
