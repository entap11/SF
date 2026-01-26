extends Area2D

signal hive_clicked(hive_id: int, button: int, global_pos: Vector2)
signal hive_released(hive_id: int, button: int, global_pos: Vector2)
signal hive_hovered(hive_id: int, global_pos: Vector2)
signal hive_unhovered(hive_id: int)

const SFLog := preload("res://scripts/util/sf_log.gd")

@export var hive_id: int = -1
@export var owner_id: int = 0

var power: int = 0
var radius_px: float = 18.0
var _selected := false
var _sel_t := 0.0
var _sel_color: Color = Color(1.0, 1.0, 1.0, 1.0)
const SEL_SEG := 48
const SEL_W := 5.0
const SEL_PAD := 6.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual

func _ready() -> void:
	input_pickable = true
	monitoring = true
	set_process(false)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sync_collision()

func apply_render(owner_id_in: int, power_in: int, radius_in: float, color: Color, font_size: int, kind: String = "Hive") -> void:
	SFLog.log_once(
		"HIVENODE_APPLY_RENDER",
		"HiveNode.apply_render called (sample): id=%s owner=%s power=%s kind=%s" % [str(hive_id), str(owner_id_in), str(power_in), str(kind)],
		SFLog.Level.INFO
	)
	owner_id = owner_id_in
	power = power_in
	radius_px = radius_in
	_sync_collision()
	if visual != null and visual.has_method("configure"):
		visual.call("configure", owner_id, color, radius_px, power, font_size, kind)
	if visual is CanvasItem:
		var ci := visual as CanvasItem
		if ci.has_method("set_self_modulate"):
			ci.set_self_modulate(Color(1, 1, 1, 1))
		else:
			ci.modulate = Color(1, 1, 1, 1)
	if _selected:
		queue_redraw()

func set_selected(on: bool, color: Color) -> void:
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
	var r := 24.0
	var cs := get_node_or_null("CollisionShape2D")
	if cs is CollisionShape2D and (cs as CollisionShape2D).shape is CircleShape2D:
		r = ((cs as CollisionShape2D).shape as CircleShape2D).radius
	r += SEL_PAD
	var pulse := 0.6 + 0.4 * (0.5 + 0.5 * sin(_sel_t))
	var c := _sel_color
	c.a = pulse
	var pts := PackedVector2Array()
	for i in range(SEL_SEG + 1):
		var a := float(i) / float(SEL_SEG) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, c, SEL_W, true)

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			print("HIVE_NODE_CLICK hive_id=", hive_id)
			emit_signal("hive_clicked", hive_id, mb.button_index, global_position)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			emit_signal("hive_released", hive_id, mb.button_index, global_position)

func _sync_collision() -> void:
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = radius_px

func _on_mouse_entered() -> void:
	emit_signal("hive_hovered", hive_id, global_position)

func _on_mouse_exited() -> void:
	emit_signal("hive_unhovered", hive_id)
