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
	_assert_true(node.z_as_relative and int(node.z_index) == 0, "upward unit should return to default depth after clearing top edge")

	var down_unit: Dictionary = {"id": 102, "from_id": 2, "to_id": 1, "a_id": 1, "b_id": 2, "dir": -1}
	var down_dir := Vector2.DOWN
	var target_boundary: Vector2 = renderer.call("_target_hive_boundary_world", 1, hive_by_id, down_dir) as Vector2
	node.global_position = target_boundary
	renderer.call("_update_target_hive_occlusion_depth", node, down_unit, hive_by_id, down_dir)
	_assert_true(not node.z_as_relative and int(node.z_index) == -2, "downward unit should render behind target hive at top edge")

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
