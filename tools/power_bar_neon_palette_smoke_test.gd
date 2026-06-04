extends SceneTree

const POWER_BAR_SCENE := "res://scenes/ui/power_bar.tscn"
const DYNAMIC_SHADER := "res://assets/shaders/power_bar_theme_dynamic.gdshader"
const BOIL_SHADER := "res://assets/shaders/power_bar_theme_boil.gdshader"

var _has_failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load(POWER_BAR_SCENE) as PackedScene
	if scene == null:
		_fail("power bar scene missing")
		return
	var power_bar: Node = scene.instantiate()
	get_root().add_child(power_bar)
	await process_frame

	_assert_color(power_bar, "Rig/BarDock/FillMask/FillP1", Color(1.0, 0.94, 0.0, 1.0), "P1 neon yellow")
	_assert_color(power_bar, "Rig/BarDock/FillMask/FillP2", Color(1.0, 0.0, 0.16, 1.0), "P2 neon red")
	_assert_color(power_bar, "Rig/BarDock/FillMask/FillP3", Color(0.0, 1.0, 0.10, 1.0), "P3 electric green")
	_assert_color(power_bar, "Rig/BarDock/FillMask/FillP4", Color(0.0, 0.22, 1.0, 1.0), "P4 electric blue")
	if _has_failed:
		return

	for shader_path in [DYNAMIC_SHADER, BOIL_SHADER]:
		var source: String = FileAccess.get_file_as_string(shader_path)
		if not source.contains("vec4(1.0, 0.94, 0.0, 1.0)"):
			_fail("%s should default P1 to neon yellow" % shader_path)
			return
		if not source.contains("vec4(1.0, 0.0, 0.16, 1.0)"):
			_fail("%s should default P2 to neon red" % shader_path)
			return
		if not source.contains("vec4(0.0, 1.0, 0.10, 1.0)"):
			_fail("%s should default P3 to electric green" % shader_path)
			return
		if not source.contains("vec4(0.0, 0.22, 1.0, 1.0)"):
			_fail("%s should default P4 to electric blue" % shader_path)
			return
		if source.contains("mix(tex_base.rgb *"):
			_fail("%s should not tint over the baked source fill color" % shader_path)
			return
		if source.contains("mix(color_p1.rgb, color_p2.rgb"):
			_fail("%s front glow should use the active segment color, not only P1/P2" % shader_path)
			return
		if not source.contains("front_color = seat_color_for_x"):
			_fail("%s should derive front glow from the normalized team segment" % shader_path)
			return

	print("POWER_BAR_NEON_PALETTE_SMOKE: PASS")
	quit(0)

func _assert_color(root_node: Node, path: String, expected: Color, label: String) -> void:
	var rect: ColorRect = root_node.get_node_or_null(path) as ColorRect
	if rect == null:
		_fail("%s fill node missing" % label)
		return
	var actual: Color = rect.color
	if not actual.is_equal_approx(expected):
		_fail("%s expected=%s actual=%s" % [label, str(expected), str(actual)])

func _fail(message: String) -> void:
	_has_failed = true
	push_error("POWER_BAR_NEON_PALETTE_SMOKE: %s" % message)
	quit(1)
