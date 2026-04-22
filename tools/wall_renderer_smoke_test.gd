extends SceneTree

const WallRendererScript := preload("res://scripts/renderers/wall_renderer.gd")

func _init() -> void:
	await process_frame
	var renderer: WallRenderer = WallRendererScript.new()
	renderer.name = "WallRendererSmoke"
	get_root().add_child(renderer)
	await process_frame
	renderer.set_wall_segments([
		{
			"a": Vector2(120.0, 180.0),
			"b": Vector2(360.0, 180.0)
		}
	])
	await process_frame
	_assert_true(renderer.get_child_count() > 0, "renderer should create a wall segment")
	renderer.notify_blocked_attempt_path(Vector2(240.0, 60.0), Vector2(240.0, 320.0), "attack")
	renderer.tick_visuals(0.25)
	print("WALL_RENDERER_SMOKE: PASS")
	quit(0)

func _assert_true(value: bool, message: String) -> void:
	if value:
		return
	push_error("WALL_RENDERER_SMOKE: %s" % message)
	quit(1)
