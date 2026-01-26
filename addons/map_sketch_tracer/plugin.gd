extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	dock = preload("res://addons/map_sketch_tracer/tracer_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock != null:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
