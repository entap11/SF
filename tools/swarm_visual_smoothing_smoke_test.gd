extends SceneTree

const UnitRendererScript = preload("res://scripts/renderers/unit_renderer.gd")

func _initialize() -> void:
	var root_node: Node2D = Node2D.new()
	root_node.name = "SwarmVisualSmoothingSmoke"
	get_root().add_child(root_node)
	var renderer: Node2D = UnitRendererScript.new()
	renderer.name = "UnitRenderer"
	root_node.add_child(renderer)
	await process_frame

	renderer.call("bind_hives", [
		{"id": 1, "owner_id": 1, "grid_pos": Vector2i(0, 0), "x": 0.0, "y": 0.0, "pos": Vector2(0.0, 0.0), "radius_px": 24.0},
		{"id": 2, "owner_id": 2, "grid_pos": Vector2i(10, 0), "x": 10.0, "y": 0.0, "pos": Vector2(640.0, 0.0), "radius_px": 24.0}
	], 1)

	var base_model: Dictionary = {
		"sim_running": true,
		"lanes": [{"lane_id": 1, "a_id": 1, "b_id": 2, "send_a": true, "send_b": false}],
		"swarms": [{"swarm_id": 55, "lane_id": 1, "owner_id": 1, "side": "A", "t": 0.20, "count": 5, "src": 1, "dst": 2}]
	}
	renderer.set("model", base_model.duplicate(true))
	renderer.call("bind_units", [], 1, 100000)
	var nodes: Dictionary = renderer.get("swarm_nodes_by_id")
	var swarm_node: Node2D = nodes.get(55, null) as Node2D
	_assert_true(swarm_node != null, "swarm node should be created")
	if swarm_node == null:
		quit(1)
		return
	var first_pos: Vector2 = swarm_node.position

	var next_model: Dictionary = base_model.duplicate(true)
	next_model["swarms"] = [{"swarm_id": 55, "lane_id": 1, "owner_id": 1, "side": "A", "t": 0.40, "count": 5, "src": 1, "dst": 2}]
	renderer.set("model", next_model)
	renderer.call("bind_units", [], 2, 200000)
	var state_by_id: Dictionary = renderer.get("_swarm_visual_by_id")
	var state: Dictionary = state_by_id.get(55, {}) as Dictionary
	_assert_true(not state.is_empty(), "swarm smoothing state should be recorded")
	if state.is_empty():
		quit(1)
		return
	var curr_pos: Vector2 = state.get("curr_pos", first_pos)
	var curr_wall_us: int = int(state.get("curr_wall_us", Time.get_ticks_usec()))
	renderer.call("_update_swarm_visual_smoothing", curr_wall_us + 50000)
	var smoothed_pos: Vector2 = swarm_node.position
	_assert_true(smoothed_pos.distance_to(first_pos) > 0.01, "smoothed swarm should advance from previous sample")
	_assert_true(smoothed_pos.distance_to(curr_pos) > 0.01, "smoothed swarm should not snap to current sample midway")

	root_node.queue_free()
	print("SWARM_VISUAL_SMOOTHING_SMOKE: PASS")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("SWARM_VISUAL_SMOOTHING_SMOKE: %s" % message)
	quit(1)
