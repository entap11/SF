extends SceneTree

const UnitRendererScript = preload("res://scripts/renderers/unit_renderer.gd")
const OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)

func _initialize() -> void:
	var root_node: Node2D = Node2D.new()
	root_node.name = "Arena"
	get_root().add_child(root_node)
	var map_root: Node2D = Node2D.new()
	map_root.name = "MapRoot"
	root_node.add_child(map_root)
	var pools_root: Node2D = Node2D.new()
	pools_root.name = "PoolsRoot"
	root_node.add_child(pools_root)
	var renderer: Node2D = UnitRendererScript.new()
	renderer.name = "UnitRenderer"
	pools_root.add_child(renderer)
	await process_frame

	var first_any: Variant = renderer.call("_pool_acquire")
	var first_node: Node2D = first_any as Node2D
	_assert_true(first_node != null, "pool acquire should return a node")
	if first_node == null:
		quit(1)
		return
	var first_id: int = int(first_node.get_instance_id())
	first_node.name = "Unit_77"
	first_node.set_meta("unit_id", 77)
	first_node.visible = true
	first_node.position = Vector2(128.0, 64.0)
	renderer.call("_pool_release", first_node)
	_assert_true(not first_node.visible, "released unit should be hidden")
	_assert_true(first_node.position == OFFSCREEN_POS, "released unit should move to sentinel offscreen position")
	_assert_true(int(first_node.get_meta("unit_id", -1)) == -1, "released unit id metadata should reset")

	var second_any: Variant = renderer.call("_pool_acquire")
	var second_node: Node2D = second_any as Node2D
	_assert_true(second_node != null, "second pool acquire should return a node")
	if second_node == null:
		quit(1)
		return
	_assert_true(int(second_node.get_instance_id()) == first_id, "pool should reuse returned unit node")
	renderer.call("_pool_release", second_node)

	_assert_true(_no_pooled_nodes_under_map_root(map_root), "pooled/system nodes must not be under MapRoot")
	var telemetry_any: Variant = renderer.call("get_pool_telemetry_snapshot")
	var telemetry: Dictionary = telemetry_any as Dictionary if typeof(telemetry_any) == TYPE_DICTIONARY else {}
	_assert_true(int(telemetry.get("pool_hits", 0)) >= 2, "pool telemetry should count hits")
	_assert_true(int(telemetry.get("runtime_instantiates_avoided", 0)) >= 2, "pool telemetry should count avoided runtime instantiates")
	root_node.queue_free()
	print("UNIT_VISUAL_POOL_SMOKE: PASS")
	quit(0)

func _no_pooled_nodes_under_map_root(node: Node) -> bool:
	for child in node.get_children():
		var child_node: Node = child as Node
		if child_node == null:
			continue
		if str(child_node.name).find("Pool") >= 0 or str(child_node.name).find("UnitRenderer") >= 0:
			push_error("UNIT_VISUAL_POOL_SMOKE: pooled/system node under MapRoot: %s" % str(child_node.get_path()))
			return false
		if not _no_pooled_nodes_under_map_root(child_node):
			return false
	return true

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("UNIT_VISUAL_POOL_SMOKE: %s" % message)
	quit(1)
