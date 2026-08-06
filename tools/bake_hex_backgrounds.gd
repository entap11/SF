extends SceneTree

const OUTPUT_DIR: String = "res://assets/sprites/sf_skin_v1/baked_ui/backgrounds"
const BACKGROUND_SCENE: PackedScene = preload("res://ui/backgrounds/HexSeamBackground.tscn")
const PRESETS: PackedStringArray = ["dash", "store", "hive", "popup"]
const OUTPUT_SIZE: Vector2i = Vector2i(540, 1170)


func _initialize() -> void:
	call_deferred("_bake_all")


func _bake_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failures: int = 0
	for preset_name in PRESETS:
		var viewport := SubViewport.new()
		viewport.size = OUTPUT_SIZE
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		get_root().add_child(viewport)

		var background: Control = BACKGROUND_SCENE.instantiate() as Control
		viewport.add_child(background)
		background.position = Vector2.ZERO
		background.size = Vector2(OUTPUT_SIZE)
		background.call("apply_preset", StringName(preset_name))

		await process_frame
		await process_frame
		await process_frame
		var image: Image = viewport.get_texture().get_image()
		var output_path: String = "%s/hex_%s.png" % [OUTPUT_DIR, preset_name]
		var error: Error = image.save_png(output_path)
		if error != OK:
			failures += 1
			push_error("Failed to bake %s: %s" % [output_path, error_string(error)])
		else:
			print("Baked %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
		viewport.queue_free()
		await process_frame

	print("HEX_BACKGROUND_BAKE_COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)
