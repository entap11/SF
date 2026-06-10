extends SceneTree

func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/renderers/lane_renderer.gd")
	if not source.contains("const LANE_CONTEST_BUFFER_PX: float = 130.0"):
		push_error("LANE_RENDERER_CONTESTED_MIN_COLOR_SMOKE: contested lane minimum color should be 130px")
		quit(1)
		return
	print("LANE_RENDERER_CONTESTED_MIN_COLOR_SMOKE: PASS")
	quit(0)
