extends SceneTree

const CAPTURE_SIZE := Vector2i(944, 2048)
const OUTPUT_DIR: String = "/tmp/swarmfront_ui_readability"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	await process_frame
	await _capture_scene("res://scenes/ui/GaragePanel.tscn", "dashboard_garage.png", false)
	await _capture_scene("res://scenes/ui/DashBuffsHero.tscn", "dashboard_buffs.png", false)
	await _capture_scene("res://scenes/ui/JukeboxPanel.tscn", "jukebox.png", true)
	print("UI_READABILITY_VISUAL: PASS")
	for filename in ["dashboard_garage.png", "dashboard_buffs.png", "jukebox.png"]:
		print(OUTPUT_DIR.path_join(filename))
	quit(0)

func _capture_scene(scene_path: String, filename: String, force_visible: bool) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("UI_READABILITY_VISUAL: failed to load %s" % scene_path)
		quit(1)
		return
	var control: Control = packed.instantiate() as Control
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = Vector2.ZERO
	control.size = Vector2(CAPTURE_SIZE)
	root.add_child(control)
	control.size = Vector2(CAPTURE_SIZE)
	if force_visible:
		control.visible = true
	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		push_error("UI_READABILITY_VISUAL: no viewport texture for %s" % scene_path)
		quit(1)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("UI_READABILITY_VISUAL: empty viewport image for %s" % scene_path)
		quit(1)
		return
	if image.get_width() >= CAPTURE_SIZE.x and image.get_height() >= CAPTURE_SIZE.y:
		image = image.get_region(Rect2i(Vector2i.ZERO, CAPTURE_SIZE))
	var output_path: String = OUTPUT_DIR.path_join(filename)
	var error: Error = image.save_png(output_path)
	if error != OK:
		push_error("UI_READABILITY_VISUAL: failed to save %s (%d)" % [output_path, error])
		quit(1)
		return
	control.queue_free()
	for _frame in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
