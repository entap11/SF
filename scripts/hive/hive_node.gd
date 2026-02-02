extends Area2D

signal hive_clicked(hive_id: int, button: int, global_pos: Vector2)
signal hive_released(hive_id: int, button: int, global_pos: Vector2)
signal hive_hovered(hive_id: int, global_pos: Vector2)
signal hive_unhovered(hive_id: int)

const SFLog := preload("res://scripts/util/sf_log.gd")
const SELECTOR_PULSE_SHADER := preload("res://shaders/selector_pulse.gdshader")
const SELECTOR_SMALL_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_small.tres"
const SELECTOR_MEDIUM_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_medium.tres"
const SELECTOR_LARGE_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_large.tres"

const SELECTOR_STATE_INACTIVE := 0
const SELECTOR_STATE_HOVER := 1
const SELECTOR_STATE_SELECTED := 2
const SELECTOR_STATE_ACTIVATED := 3
const LANE_ANCHOR_Y_PX: float = 58.0

@export var hive_id: int = -1
@export var owner_id: int = 0

var power: int = 0
var radius_px: float = 18.0
var _selected := false
var _hovered := false
var _activated := false
var _sel_t := 0.0
var _sel_color: Color = Color(1.0, 1.0, 1.0, 1.0)
const SEL_SEG := 48
const SEL_W := 5.0
const SEL_PAD := 6.0
const SELECTOR_RING_SCALE_MUL := 1.1
const SELECTOR_OFFSET_SMALL_MUL := 0.99
const SELECTOR_OFFSET_MED_MUL := 1.14
const SELECTOR_OFFSET_LARGE_MUL := 1.26
const SELECTOR_HOVER_PULSE_SPEED := 1.5
const SELECTOR_HOVER_PULSE_STRENGTH := 0.15
const SELECTOR_HOVER_GLOW_BOOST := 0.6
const SELECTOR_HOVER_SCALE := 1.0
const SELECTOR_SELECTED_PULSE_SPEED := 2.2
const SELECTOR_SELECTED_PULSE_STRENGTH := 0.25
const SELECTOR_SELECTED_GLOW_BOOST := 1.0
const SELECTOR_SELECTED_SCALE := 1.02
const SELECTOR_ACTIVATED_PULSE_SPEED := 3.0
const SELECTOR_ACTIVATED_PULSE_STRENGTH := 0.35
const SELECTOR_ACTIVATED_GLOW_BOOST := 1.4
const SELECTOR_ACTIVATED_SCALE := 1.04
const SELECTOR_BASE_ALPHA := 0.85
const SELECTOR_TIER_2_MIN_POWER := 10
const SELECTOR_TIER_3_MIN_POWER := 25
const SELECTOR_TIER_4_MIN_POWER := 50

@onready var visual: Node2D = $Visual
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var pick_shape: CollisionShape2D = $PickShape2D

const PICK_PAD_X := 10.0
const PICK_PAD_TOP := -6.0
const PICK_PAD_BOTTOM := 18.0
const PICK_Y_BIAS := 6.0
var _selector_sprite: Sprite2D = null
var _selector_tex_small: Texture2D = null
var _selector_tex_med: Texture2D = null
var _selector_tex_large: Texture2D = null
var _selector_mat: ShaderMaterial = null
var _selector_state: int = SELECTOR_STATE_INACTIVE
var _last_kind: String = ""
var _sim_events: Node = null

static func lane_anchor_world_from_center(center_world: Vector2) -> Vector2:
	return center_world + Vector2(0.0, -LANE_ANCHOR_Y_PX)

static func compute_lane_endpoints_world(a_center_world: Vector2, b_center_world: Vector2) -> Dictionary:
	var a_anchor: Vector2 = lane_anchor_world_from_center(a_center_world)
	var b_anchor: Vector2 = lane_anchor_world_from_center(b_center_world)
	var lane_vec: Vector2 = b_anchor - a_anchor
	var lane_len: float = lane_vec.length()
	var lane_dir: Vector2 = Vector2.ZERO
	if lane_len > 0.000001:
		lane_dir = lane_vec / lane_len
	return {
		"a_center": a_center_world,
		"b_center": b_center_world,
		"a_anchor": a_anchor,
		"b_anchor": b_anchor,
		"a": a_anchor,
		"b": b_anchor,
		"dir": lane_dir,
		"len": lane_len
	}

func get_lane_anchor_world() -> Vector2:
	return lane_anchor_world_from_center(global_position)

func _ready() -> void:
	input_pickable = true
	monitoring = true
	set_process(false)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_fit_pick_hitbox_to_sprite()
	if collision_shape != null and collision_shape.get_parent() != self:
		var parent_path := "<null>"
		if collision_shape.get_parent() != null:
			parent_path = str(collision_shape.get_parent().get_path())
		SFLog.warn("HIVE_COLLISION_PARENT_BAD", {
			"node": str(get_path()),
			"collision_parent": parent_path,
			"expected_parent": str(get_path())
		})
	_sync_collision()
	_load_selector_textures()
	_ensure_selector_sprite()
	_refresh_selector_state()

func _fit_pick_hitbox_to_sprite() -> void:
	if pick_shape == null:
		return
	var sprite := get_node_or_null("Visual/HiveSprite")
	if sprite == null or not (sprite is Sprite2D):
		return
	var s := sprite as Sprite2D
	if s.texture == null:
		return
	var tex := s.texture
	var tex_w: float = tex.get_width()
	var tex_h: float = tex.get_height()
	var gs: Vector2 = s.global_scale
	var w: float = tex_w * abs(gs.x)
	var h: float = tex_h * abs(gs.y)
	if w <= 0.0 or h <= 0.0:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w + PICK_PAD_X, h + PICK_PAD_TOP + PICK_PAD_BOTTOM)
	pick_shape.shape = rect
	pick_shape.global_position = s.global_position + Vector2(0, PICK_Y_BIAS + 3)
	pick_shape.disabled = false
	SFLog.log_once("HIVE_PICK_BOX", "HIVE_PICK_BOX fitted", SFLog.Level.INFO)

func apply_render(owner_id_in: int, power_in: int, radius_in: float, color: Color, font_size: int, kind: String = "Hive") -> void:
	SFLog.log_once(
		"HIVENODE_APPLY_RENDER",
		"HiveNode.apply_render called (sample): id=%s owner=%s power=%s kind=%s" % [str(hive_id), str(owner_id_in), str(power_in), str(kind)],
		SFLog.Level.INFO
	)
	owner_id = owner_id_in
	power = power_in
	radius_px = radius_in
	var prev_kind: String = _last_kind
	_last_kind = kind
	if prev_kind != "" and prev_kind != kind:
		var sim_events := _get_sim_events()
		if sim_events != null:
			sim_events.emit_signal("hive_kind_changed", hive_id, owner_id, global_position, prev_kind, kind)
	_sync_collision()
	if visual != null and visual.has_method("configure"):
		visual.call("configure", owner_id, color, radius_px, power, font_size, kind)
	if visual is CanvasItem:
		var ci := visual as CanvasItem
		if ci.has_method("set_self_modulate"):
			ci.set_self_modulate(Color(1, 1, 1, 1))
		else:
			ci.modulate = Color(1, 1, 1, 1)
	if not _selected:
		_sel_color = color
	_update_selector_visual()
	if _selected:
		queue_redraw()

func set_selected(on: bool, color: Color) -> void:
	_selected = on
	_sel_color = color
	if not _selected:
		_sel_t = 0.0
	_refresh_selector_state()
	_update_selector_visual()
	_update_fallback_process()
	queue_redraw()

func set_activated(on: bool) -> void:
	if _activated == on:
		return
	_activated = on
	_refresh_selector_state()
	_update_selector_visual()

func _process(delta: float) -> void:
	if not (_selected or _hovered):
		return
	_sel_t += delta * 3.0
	queue_redraw()

func _draw() -> void:
	if _selector_state == SELECTOR_STATE_INACTIVE:
		return
	if _selector_sprite != null and _selector_sprite.texture != null:
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
	var offset := _selector_offset_for_power(power)
	for i in range(SEL_SEG + 1):
		var a := float(i) / float(SEL_SEG) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r + offset)
	draw_polyline(pts, c, SEL_W, true)

func _input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if SFLog.LOGGING_ENABLED:
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
	_fit_pick_hitbox_to_sprite()

func _load_selector_textures() -> void:
	_selector_tex_small = _load_selector_texture(SELECTOR_SMALL_PATH)
	_selector_tex_med = _load_selector_texture(SELECTOR_MEDIUM_PATH)
	_selector_tex_large = _load_selector_texture(SELECTOR_LARGE_PATH)

func _load_selector_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as Texture2D if res is Texture2D else null

func _get_sim_events() -> Node:
	if _sim_events != null and is_instance_valid(_sim_events):
		return _sim_events
	var tree := get_tree()
	if tree == null:
		return null
	_sim_events = tree.get_first_node_in_group("sim_events")
	return _sim_events

func _ensure_selector_sprite() -> void:
	if _selector_sprite != null and is_instance_valid(_selector_sprite):
		return
	var parent_node: Node = visual if visual != null else self
	var existing := parent_node.get_node_or_null("SelectorRing")
	if existing is Sprite2D:
		_selector_sprite = existing as Sprite2D
	else:
		var legacy := get_node_or_null("SelectorRing")
		if legacy is Sprite2D and visual != null:
			legacy.reparent(visual, true)
			_selector_sprite = legacy as Sprite2D
		else:
			var sprite := Sprite2D.new()
			sprite.name = "SelectorRing"
			sprite.centered = true
			sprite.z_index = -2
			parent_node.add_child(sprite)
			_selector_sprite = sprite
	if _selector_mat == null:
		_selector_mat = ShaderMaterial.new()
		_selector_mat.shader = SELECTOR_PULSE_SHADER
	_selector_sprite.material = _selector_mat
	_selector_sprite.centered = true
	_selector_sprite.z_index = -2
	_selector_sprite.visible = false

func _selector_texture_for_power(power_value: int) -> Texture2D:
	if power_value >= SELECTOR_TIER_4_MIN_POWER:
		return _selector_tex_large
	if power_value >= SELECTOR_TIER_3_MIN_POWER:
		return _selector_tex_large
	if power_value >= SELECTOR_TIER_2_MIN_POWER:
		return _selector_tex_med
	return _selector_tex_small

func _refresh_selector_state() -> void:
	if _activated:
		_selector_state = SELECTOR_STATE_ACTIVATED
	elif _selected:
		_selector_state = SELECTOR_STATE_SELECTED
	elif _hovered:
		_selector_state = SELECTOR_STATE_HOVER
	else:
		_selector_state = SELECTOR_STATE_INACTIVE

func _update_selector_visual() -> void:
	if _selector_sprite == null:
		return
	var tex := _selector_texture_for_power(power)
	_selector_sprite.texture = tex
	_selector_sprite.visible = _selector_state != SELECTOR_STATE_INACTIVE and tex != null
	_selector_sprite.position = _selector_offset_for_power(power)
	if tex == null:
		return
	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	var tex_max := maxf(tex_w, tex_h)
	if tex_max <= 0.0:
		_selector_sprite.scale = Vector2.ONE
		return
	var state_scale := _selector_scale_for_state(_selector_state)
	var target_size := radius_px * 2.0 * SELECTOR_RING_SCALE_MUL * state_scale
	var s := target_size / tex_max
	_selector_sprite.scale = Vector2(s, s)
	_apply_selector_shader_state(_selector_state)

func _selector_offset_for_power(power_value: int) -> Vector2:
	var offset_mul := SELECTOR_OFFSET_SMALL_MUL
	if power_value >= SELECTOR_TIER_4_MIN_POWER:
		offset_mul = SELECTOR_OFFSET_LARGE_MUL
	elif power_value >= SELECTOR_TIER_3_MIN_POWER:
		offset_mul = SELECTOR_OFFSET_LARGE_MUL
	elif power_value >= SELECTOR_TIER_2_MIN_POWER:
		offset_mul = SELECTOR_OFFSET_MED_MUL
	return Vector2(0.0, radius_px * offset_mul)

func _selector_scale_for_state(state: int) -> float:
	match state:
		SELECTOR_STATE_ACTIVATED:
			return SELECTOR_ACTIVATED_SCALE
		SELECTOR_STATE_SELECTED:
			return SELECTOR_SELECTED_SCALE
		SELECTOR_STATE_HOVER:
			return SELECTOR_HOVER_SCALE
		_:
			return 1.0

func _apply_selector_shader_state(state: int) -> void:
	if _selector_mat == null:
		return
	var speed := SELECTOR_HOVER_PULSE_SPEED
	var strength := SELECTOR_HOVER_PULSE_STRENGTH
	var boost := SELECTOR_HOVER_GLOW_BOOST
	match state:
		SELECTOR_STATE_ACTIVATED:
			speed = SELECTOR_ACTIVATED_PULSE_SPEED
			strength = SELECTOR_ACTIVATED_PULSE_STRENGTH
			boost = SELECTOR_ACTIVATED_GLOW_BOOST
		SELECTOR_STATE_SELECTED:
			speed = SELECTOR_SELECTED_PULSE_SPEED
			strength = SELECTOR_SELECTED_PULSE_STRENGTH
			boost = SELECTOR_SELECTED_GLOW_BOOST
		SELECTOR_STATE_HOVER:
			speed = SELECTOR_HOVER_PULSE_SPEED
			strength = SELECTOR_HOVER_PULSE_STRENGTH
			boost = SELECTOR_HOVER_GLOW_BOOST
		_:
			speed = SELECTOR_HOVER_PULSE_SPEED
			strength = SELECTOR_HOVER_PULSE_STRENGTH
			boost = SELECTOR_HOVER_GLOW_BOOST
	_selector_mat.set_shader_parameter("pulse_speed", speed)
	_selector_mat.set_shader_parameter("pulse_strength", strength)
	_selector_mat.set_shader_parameter("glow_boost", boost)
	_selector_mat.set_shader_parameter("base_alpha", SELECTOR_BASE_ALPHA)

func _update_fallback_process() -> void:
	var needs_fallback := _selector_sprite == null or _selector_sprite.texture == null
	set_process(needs_fallback and (_selected or _hovered))

func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_selector_state()
	_update_selector_visual()
	_update_fallback_process()
	emit_signal("hive_hovered", hive_id, global_position)

func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_selector_state()
	_update_selector_visual()
	_update_fallback_process()
	emit_signal("hive_unhovered", hive_id)
