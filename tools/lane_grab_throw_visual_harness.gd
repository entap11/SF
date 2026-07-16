extends SceneTree

const CAPTURE_SIZE := Vector2i(640, 360)
const OUTPUT_PATH := "/tmp/swarmfront_lane_grab_throw.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color(0.015, 0.02, 0.03, 1.0))

	var renderer_script: Script = load("res://scripts/renderers/lane_renderer.gd") as Script
	if renderer_script == null:
		push_error("LANE_GRAB_THROW_VISUAL: failed to load LaneRenderer")
		quit(1)
		return
	var renderer: Node2D = renderer_script.new() as Node2D
	root.add_child(renderer)
	renderer.call(
		"set_lane_grab_preview",
		1,
		"a",
		"throw_ready",
		Vector2(80.0, 180.0),
		Vector2(520.0, 180.0),
		Vector2(300.0, 300.0),
		Vector2(300.0, 180.0)
	)

	for _frame in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("LANE_GRAB_THROW_VISUAL: capture was empty")
		quit(1)
		return
	var error: Error = image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("LANE_GRAB_THROW_VISUAL: failed to save capture (%d)" % error)
		quit(1)
		return
	print("LANE_GRAB_THROW_VISUAL: PASS %s" % OUTPUT_PATH)
	quit(0)
