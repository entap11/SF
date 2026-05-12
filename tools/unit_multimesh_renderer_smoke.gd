extends Node

const UnitRenderer := preload("res://scripts/renderers/unit_renderer.gd")

func _ready() -> void:
	await get_tree().process_frame
	var renderer := UnitRenderer.new()
	add_child(renderer)
	renderer.use_multimesh_units = true
	renderer.bind_hives([
		{"id": 1, "owner_id": 1, "grid_pos": Vector2i(0, 0), "power": 50},
		{"id": 2, "owner_id": 2, "grid_pos": Vector2i(5, 0), "power": 50}
	], 1)
	renderer.bind_units([
		{
			"id": 101,
			"lane_id": 1,
			"a_id": 1,
			"b_id": 2,
			"from_id": 1,
			"to_id": 2,
			"owner_id": 1,
			"dir": 1,
			"t": 0.25
		},
		{
			"id": 102,
			"lane_id": 1,
			"a_id": 1,
			"b_id": 2,
			"from_id": 2,
			"to_id": 1,
			"owner_id": 2,
			"dir": -1,
			"t": 0.75
		}
	], 1, 100000)
	renderer.call("_render_units", Time.get_ticks_usec())
	var submitted := 0
	var batches: Dictionary = renderer.get("_unit_multimesh_batches")
	for batch_any in batches.values():
		var batch: Dictionary = batch_any as Dictionary
		submitted += int(batch.get("count", 0))
	if submitted < 2:
		push_error("UNIT_MULTIMESH_RENDERER_SMOKE: multimesh renderer should submit unit instances")
		get_tree().quit(1)
		return
	print("UNIT_MULTIMESH_RENDERER_SMOKE: PASS")
	get_tree().quit(0)
