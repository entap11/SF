extends SceneTree

func _initialize() -> void:
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn") as PackedScene
	_assert_true(arena_scene != null, "Arena scene should load")
	if arena_scene == null:
		quit(1)
		return
	var arena: Node = arena_scene.instantiate()
	get_root().add_child(arena)
	await process_frame
	var renderer: Node = arena.get_node_or_null("MapRoot/LaneRenderer")
	_assert_true(renderer != null, "LaneRenderer should exist in Arena scene")
	if renderer == null:
		quit(1)
		return

	var base_model: Dictionary = {
		"sim_running": true,
		"sim_time_s": 0.1,
		"lanes": [{"lane_id": 7, "a_id": 1, "b_id": 2, "send_a": true, "send_b": true, "front_t": 0.25}],
		"hives": [
			{"id": 1, "owner_id": 1, "grid_pos": Vector2i(0, 0), "x": 0.0, "y": 0.0, "pos": Vector2(0.0, 0.0), "radius_px": 24.0},
			{"id": 2, "owner_id": 2, "grid_pos": Vector2i(10, 0), "x": 10.0, "y": 0.0, "pos": Vector2(640.0, 0.0), "radius_px": 24.0}
		]
	}
	renderer.call("set_model", base_model)

	var next_model: Dictionary = base_model.duplicate(true)
	next_model["sim_time_s"] = 0.2
	next_model["lanes"] = [{"lane_id": 7, "a_id": 1, "b_id": 2, "send_a": true, "send_b": true, "front_t": 0.75}]
	renderer.call("set_model", next_model)

	var state_by_id: Dictionary = renderer.get("_lane_front_visual_by_id")
	var state: Dictionary = state_by_id.get(7, {}) as Dictionary
	_assert_true(not state.is_empty(), "lane front smoothing state should be recorded")
	if state.is_empty():
		quit(1)
		return

	var curr_wall_us: int = int(state.get("curr_wall_us", Time.get_ticks_usec()))
	var smoothed_t: float = float(renderer.call("_lane_front_visual_t", 7, 0.75, curr_wall_us + 50000))
	_assert_true(smoothed_t > 0.25, "smoothed lane front should advance from previous sample")
	_assert_true(smoothed_t < 0.75, "smoothed lane front should not snap to current sample midway")

	arena.queue_free()
	print("LANE_FRONT_VISUAL_SMOOTHING_SMOKE: PASS")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("LANE_FRONT_VISUAL_SMOOTHING_SMOKE: %s" % message)
	quit(1)
