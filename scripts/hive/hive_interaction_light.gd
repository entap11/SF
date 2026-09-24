extends Node2D
## Disposable selection/capture lighting. Inputs are canonical presentation samples.
## No gameplay references, particles, screen reads or per-frame scene allocation.
const SURFACE := preload("res://shaders/hive_interaction_light.gdshader")
const SELECT_IN_SEC := 0.12
const SELECT_OUT_SEC := 0.10
const CAPTURE_SEC := 0.46
const REDUCED_CAPTURE_SEC := 0.16

var _surface: ShaderMaterial
var _size := Vector2(40.0, 52.0)
var _owner_color := Color.WHITE
var _mode := "full"
var _selected := false
var _selection := 0.0
var _selection_from := 0.0
var _selection_elapsed := SELECT_IN_SEC
var _capture_elapsed := -1.0
var _capture_serial := 0
var _capture_progress := 0.0
var _capture_energy := 0.0

func _ready() -> void:
	# FxLayer 18: above the shell, below pressure (19), power (20) and ports (24).
	z_index = 0
	_surface = ShaderMaterial.new()
	_surface.shader = SURFACE
	material = _surface
	_update_activity()

func configure(center: Vector2, size: Vector2, color: Color, mode: String, opacity: float) -> void:
	position = center
	_size = Vector2(maxf(40.0, size.x), maxf(52.0, size.y))
	_owner_color = color
	modulate.a = clampf(opacity, 0.0, 1.0)
	var next_mode := mode if mode in ["full", "reduced", "none"] else "none"
	if next_mode != _mode:
		_mode = next_mode
		cancel_transients()
	queue_redraw()

func set_selected(selected: bool) -> void:
	if selected == _selected:
		return
	_selected = selected
	_selection_from = _selection
	_selection_elapsed = 0.0
	if _mode != "full":
		_selection = 1.0 if _selected else 0.0
		_selection_elapsed = SELECT_IN_SEC
	_update_activity()

func play_capture() -> void:
	if _mode == "none":
		return
	_capture_serial += 1
	_capture_elapsed = 0.0
	_sample_capture()
	_update_activity()

func cancel_capture() -> void:
	_capture_elapsed = -1.0
	_capture_energy = 0.0
	_capture_progress = 0.0
	_update_activity()

func cancel_transients() -> void:
	_selection = 1.0 if _selected else 0.0
	_selection_from = _selection
	_selection_elapsed = SELECT_IN_SEC
	cancel_capture()

func _process(delta: float) -> void:
	var elapsed := maxf(0.0, delta)
	var duration := SELECT_IN_SEC if _selected else SELECT_OUT_SEC
	_selection_elapsed = minf(duration, _selection_elapsed + elapsed)
	_selection = lerpf(_selection_from, 1.0 if _selected else 0.0,
		smoothstep(0.0, duration, _selection_elapsed))
	if _capture_elapsed >= 0.0:
		_capture_elapsed += elapsed
		_sample_capture()
	_update_activity()

func _sample_capture() -> void:
	var duration := CAPTURE_SEC if _mode == "full" else REDUCED_CAPTURE_SEC
	var t := clampf(_capture_elapsed / duration, 0.0, 1.0)
	_capture_progress = smoothstep(0.0, 0.84, t) if _mode == "full" else 0.0
	_capture_energy = smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.24, 1.0, t))
	if t >= 1.0:
		_capture_elapsed = -1.0
		_capture_energy = 0.0

func _update_activity() -> void:
	visible = _selection > 0.001 or _capture_energy > 0.001
	set_process(_capture_elapsed >= 0.0 or not is_equal_approx(_selection, 1.0 if _selected else 0.0))
	queue_redraw()

func _draw() -> void:
	if _surface == null:
		return
	_surface.set_shader_parameter("footprint", _size)
	_surface.set_shader_parameter("owner_color", _owner_color)
	_surface.set_shader_parameter("selection", _selection)
	_surface.set_shader_parameter("capture_energy", _capture_energy)
	_surface.set_shader_parameter("capture_progress", _capture_progress)
	_surface.set_shader_parameter("capture_travel", 1.0 if _mode == "full" else 0.0)
	draw_rect(Rect2(Vector2(-0.58, -0.43) * _size, Vector2(1.16, 0.96) * _size), Color.WHITE)

func get_debug_snapshot() -> Dictionary:
	return {"selected": _selected, "selection": _selection, "capture_active": _capture_elapsed >= 0.0,
		"capture_serial": _capture_serial, "capture_energy": _capture_energy,
		"capture_progress": _capture_progress, "mode": _mode, "owner_color": _owner_color,
		"material_instance_id": material.get_instance_id() if material != null else 0,
		"child_count": get_child_count(), "processing": is_processing()}
