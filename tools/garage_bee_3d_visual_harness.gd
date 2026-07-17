extends Control

const GARAGE_PANEL_SCENE := preload("res://scenes/ui/GaragePanel.tscn")
const OUTPUT_PATH: String = "/tmp/swarmfront_garage_bee_3d.png"
const PANEL_OUTPUT_PATH: String = "/tmp/swarmfront_garage_panel_3d.png"
const EXPECTED_DEFAULT_ROTATION := Vector3(90.0, 0.0, 0.0)

func _ready() -> void:
	get_viewport().size = Vector2i(720, 1280)
	var panel: Control = GARAGE_PANEL_SCENE.instantiate() as Control
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	for _frame in range(12):
		await get_tree().process_frame
	var preview_asset: Node3D = panel.get("_preview_3d_asset") as Node3D
	if preview_asset == null or preview_asset.find_children("", "MeshInstance3D", true, false).is_empty():
		push_error("GARAGE_BEE_3D_VISUAL: high-poly mesh was not mounted")
		get_tree().quit(1)
		return
	var turntable_x_slider: HSlider = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/AxisGrid/XAxis/Slider") as HSlider
	var turntable_y_slider: HSlider = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/AxisGrid/YAxis/Slider") as HSlider
	var turntable_z_slider: HSlider = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/AxisGrid/ZAxis/Slider") as HSlider
	var reset_button: Button = panel.get_node_or_null("VBox/Body/PreviewPanel/PreviewVBox/TurntableRow/Header/ResetButton") as Button
	var turntable_model: Node3D = panel.get("_preview_3d_model") as Node3D
	if turntable_x_slider == null or turntable_y_slider == null or turntable_z_slider == null or reset_button == null or turntable_model == null:
		push_error("GARAGE_BEE_3D_VISUAL: X/Y/Z controls were not created")
		get_tree().quit(1)
		return
	turntable_x_slider.value = 24.0
	turntable_y_slider.value = 34.0
	turntable_z_slider.value = -18.0
	await get_tree().process_frame
	if not turntable_model.rotation_degrees.is_equal_approx(Vector3(24.0, 34.0, -18.0)):
		push_error("GARAGE_BEE_3D_VISUAL: X/Y/Z sliders did not rotate all three axes")
		get_tree().quit(1)
		return
	reset_button.pressed.emit()
	await get_tree().process_frame
	if not turntable_model.rotation_degrees.is_equal_approx(EXPECTED_DEFAULT_ROTATION):
		push_error("GARAGE_BEE_3D_VISUAL: RESET did not restore the authored orientation")
		get_tree().quit(1)
		return
	panel.call("_apply_preview_drag_delta", Vector2(20.0, -10.0))
	panel.call("_apply_preview_roll_delta", 10.0)
	await get_tree().process_frame
	if not turntable_model.rotation_degrees.is_equal_approx(Vector3(88.0, 4.0, 2.0)):
		push_error("GARAGE_BEE_3D_VISUAL: drag controls did not update X/Y/Z")
		get_tree().quit(1)
		return
	reset_button.pressed.emit()
	await get_tree().process_frame
	var preview_rotation: Vector3 = _rotation_override_from_args(EXPECTED_DEFAULT_ROTATION)
	turntable_x_slider.value = preview_rotation.x
	turntable_y_slider.value = preview_rotation.y
	turntable_z_slider.value = preview_rotation.z
	await get_tree().process_frame
	var preview_viewport: SubViewport = panel.get("_preview_3d_viewport") as SubViewport
	if preview_viewport == null:
		push_error("GARAGE_BEE_3D_VISUAL: preview viewport was not created")
		get_tree().quit(1)
		return
	var image: Image = preview_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("GARAGE_BEE_3D_VISUAL: preview image was empty")
		get_tree().quit(1)
		return
	var save_error: Error = image.save_png(OUTPUT_PATH)
	if save_error != OK:
		push_error("GARAGE_BEE_3D_VISUAL: failed to save %s (%d)" % [OUTPUT_PATH, save_error])
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var panel_image: Image = get_viewport().get_texture().get_image()
	var panel_save_error: Error = panel_image.save_png(PANEL_OUTPUT_PATH)
	if panel_save_error != OK:
		push_error("GARAGE_BEE_3D_VISUAL: failed to save %s (%d)" % [PANEL_OUTPUT_PATH, panel_save_error])
		get_tree().quit(1)
		return
	print("GARAGE_BEE_3D_VISUAL: %s %s" % [OUTPUT_PATH, PANEL_OUTPUT_PATH])
	get_tree().quit(0)

func _rotation_override_from_args(fallback: Vector3) -> Vector3:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var marker_index: int = args.find("--rotation")
	if marker_index < 0 or marker_index + 3 >= args.size():
		return fallback
	return Vector3(
		float(args[marker_index + 1]),
		float(args[marker_index + 2]),
		float(args[marker_index + 3])
	)
