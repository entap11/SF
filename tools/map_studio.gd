extends SceneTree

func _init() -> void:
	call_deferred("_open")

func _open() -> void:
	root.title = "Swarmfront — Map Studio"
	root.size = Vector2i(1100, 1400)
	root.content_scale_size = Vector2i(1100, 1400)
	var studio: Control = load("res://addons/map_sketch_tracer/tracer_dock.tscn").instantiate()
	root.add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
