extends Area2D

signal hive_clicked(hive_id: int, button: int, global_pos: Vector2)
signal hive_released(hive_id: int, button: int, global_pos: Vector2)
signal hive_hovered(hive_id: int, global_pos: Vector2)
signal hive_unhovered(hive_id: int)

const SFLog = preload("res://scripts/util/sf_log.gd")
const SpriteRegistry = preload("res://scripts/renderers/sprite_registry.gd")
const BASE_ANCHOR_BY_KIND = {
	"sm": Vector2(0.0, 18.0),
	"med": Vector2(0.0, 22.0),
	"lg": Vector2(0.0, 28.0),
	"max": Vector2(0.0, 32.0)
}
const BASE_RADIUS_BY_KIND = {
	"sm": 28.0,
	"med": 34.0,
	"lg": 42.0,
	"max": 50.0
}
const RenderTuning = preload("res://scripts/renderers/render_tuning.gd")
const SCALE_GUARD_MAX = 2.5

@export var hive_id: int = -1
@export var owner_id: int = 0

var power: int = 0
var radius_px: float = 18.0
var _base_scale: Vector2 = Vector2.ONE
var _visual_base_scale: Vector2 = Vector2.ONE
var _scale_guard_tripped = false
var _visual_scale_guard_tripped = false
var _selected = false
var _sel_t = 0.0
var _sel_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _kind_key: String = "med"
const SEL_SEG = 48
const SEL_W = 5.0
const SEL_PAD = 6.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual

func _ready() -> void:
	input_pickable = true
	monitoring = true
	set_process(false)
	_base_scale = scale
	if visual != null:
		visual.position = Vector2.ZERO
		if visual is Node2D:
			_visual_base_scale = (visual as Node2D).scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sync_collision()

func apply_render(owner_id_in: int, power_in: int, radius_in: float, color: Color, font_size: int, kind: String = "Hive") -> void:
	_ensure_scale_baseline("apply_render")
	SFLog.log_once(
		"HIVENODE_APPLY_RENDER",
		"HiveNode.apply_render called (sample): id=%s owner=%s power=%s kind=%s" % [str(hive_id), str(owner_id_in), str(power_in), str(kind)],
		SFLog.Level.INFO
	)
	owner_id = owner_id_in
	power = power_in
	radius_px = radius_in
	_kind_key = _resolve_kind_key(kind, power)
	_sync_collision()
	if visual != null and visual.has_method("configure"):
		visual.call("configure", owner_id, color, radius_px, power, font_size, kind)
	if visual is CanvasItem:
		var ci = visual as CanvasItem
		if ci.has_method("set_self_modulate"):
			ci.set_self_modulate(Color(1, 1, 1, 1))
		else:
			ci.modulate = Color(1, 1, 1, 1)
	if _selected:
		queue_redraw()

func set_selected(on: bool, color: Color) -> void:
	_ensure_scale_baseline("set_selected")
	_selected = on
	_sel_color = color
	if not _selected:
		_sel_t = 0.0
	set_process(_selected)
	queue_redraw()

func _process(delta: float) -> void:
	if not _selected:
		return
	_sel_t += delta * 3.0
	queue_redraw()

func _draw() -> void:
	if not _selected:
		return
	var center = get_base_anchor_local()
	var r = get_base_radius_px()
	r += SEL_PAD
	r *= RenderTuning.SELECTION_RING_SCALE_MUL
	var pulse = 0.6 + 0.4 * (0.5 + 0.5 * sin(_sel_t))
	var c = _sel_color
	c.a = pulse
	var pts = PackedVector2Array()
	for i in range(SEL_SEG + 1):
		var a = float(i) / float(SEL_SEG) * TAU
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, c, SEL_W, true)

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			SFLog.debug_log(1, "HIVE_NODE_CLICK hive_id=" + str(hive_id))
			emit_signal("hive_clicked", hive_id, mb.button_index, global_position)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			emit_signal("hive_released", hive_id, mb.button_index, global_position)

func _sync_collision() -> void:
	if collision_shape == null:
		return
	var circle = collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = get_base_radius_px()
	collision_shape.position = get_base_anchor_local()

func _ensure_scale_baseline(reason: String) -> void:
	_guard_and_reset_scale(self, _base_scale, reason, "node")
	if visual is Node2D:
		_guard_and_reset_scale(visual as Node2D, _visual_base_scale, reason, "visual")

func _guard_and_reset_scale(node: Node2D, base: Vector2, reason: String, scope: String) -> void:
	if node == null:
		return
	var s = node.scale
	var max_axis = maxf(absf(s.x), absf(s.y))
	if max_axis > SCALE_GUARD_MAX:
		var tripped = _scale_guard_tripped if scope == "node" else _visual_scale_guard_tripped
		if not tripped:
			if scope == "node":
				_scale_guard_tripped = true
			else:
				_visual_scale_guard_tripped = true
			SFLog.warn("HIVE_SCALE_GUARD", {
				"hive_id": hive_id,
				"owner_id": owner_id,
				"path": str(get_path()),
				"scope": scope,
				"scale": s,
				"base_scale": base,
				"selected": _selected,
				"reason": reason
			})
		node.scale = base
		return
	if s != base:
		node.scale = base

func _on_mouse_entered() -> void:
	emit_signal("hive_hovered", hive_id, global_position)

func _on_mouse_exited() -> void:
	emit_signal("hive_unhovered", hive_id)

func get_base_anchor_local() -> Vector2:
	return BASE_ANCHOR_BY_KIND.get(_kind_key, Vector2.ZERO)

func get_base_anchor_global() -> Vector2:
	return to_global(get_base_anchor_local())

func get_base_radius_px() -> float:
	return float(BASE_RADIUS_BY_KIND.get(_kind_key, 34.0))

func lane_anchor_global() -> Vector2:
	return get_base_anchor_global()

func lane_attach_radius_px() -> float:
	return get_base_radius_px()

func _resolve_kind_key(kind: String, power_value: int) -> String:
	var key = kind.strip_edges().to_lower()
	if key == "sm" or key == "small":
		return "sm"
	if key == "med" or key == "medium" or key == "mediumhive":
		return "med"
	if key == "lg" or key == "large" or key == "largehive":
		return "lg"
	if key == "max" or key == "xl" or key == "xlarge":
		return "max"
	if SpriteRegistry != null:
		var size_key = SpriteRegistry.hive_size_key(kind, power_value)
		match size_key:
			"small":
				return "sm"
			"med":
				return "med"
			"large":
				return "lg"
	return "med"
