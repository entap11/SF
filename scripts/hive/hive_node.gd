extends Area2D

signal hive_clicked(hive_id: int, button: int, global_pos: Vector2)
signal hive_released(hive_id: int, button: int, global_pos: Vector2)
signal hive_hovered(hive_id: int, global_pos: Vector2)
signal hive_unhovered(hive_id: int)

const SFLog := preload("res://scripts/util/sf_log.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const SELECTOR_PULSE_SHADER := preload("res://shaders/selector_pulse.gdshader")
const SELECTOR_SMALL_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_small.tres"
const SELECTOR_MEDIUM_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_medium.tres"
const SELECTOR_LARGE_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_large.tres"
const FLAG_BADGE_FONT_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"

const SELECTOR_STATE_INACTIVE := 0
const SELECTOR_STATE_HOVER := 1
const SELECTOR_STATE_SELECTED := 2
const SELECTOR_STATE_ACTIVATED := 3
# Edge trims define contact along the lane axis; this Y bias sets the visible
# lane "height" on the hive plate.
const LANE_ANCHOR_Y_PX: float = -24.0
const LANE_ANCHOR_LEFT_EXTRA_Y_PX: float = 1.0
const LANE_ANCHOR_RIGHT_EXTRA_Y_PX: float = 0.0
const LANE_SHELL_RADIUS_X_MULT: float = 1.55
const LANE_SHELL_RADIUS_Y_TOP_MULT: float = 1.08
const LANE_SHELL_RADIUS_Y_BOTTOM_MULT: float = 0.92

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
const MIN_RENDER_RADIUS_PX := 27.0
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
const SWARM_COOLDOWN_SHAKE_PX := 2.8
const SWARM_COOLDOWN_SHAKE_HZ := 24.0

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
var _flag_badge: Panel = null
var _flag_badge_label: Label = null
var _visual_rest_position: Vector2 = Vector2.ZERO
var _swarm_cooldown_until_msec: int = 0
var _swarm_cooldown_total_ms: int = 5000

static func lane_anchor_world_from_center(center_world: Vector2) -> Vector2:
	return center_world + Vector2(0.0, -LANE_ANCHOR_Y_PX)

static func lane_shell_anchor_world(center_world: Vector2, outward_dir: Vector2, radius_px: float) -> Vector2:
	var dir: Vector2 = outward_dir
	if dir.length_squared() <= 0.000001:
		return lane_anchor_world_from_center(center_world)
	dir = dir.normalized()
	if radius_px <= 0.0:
		return lane_anchor_world_from_center(center_world)
	var rx: float = maxf(1.0, radius_px * LANE_SHELL_RADIUS_X_MULT)
	var ry_mult: float = LANE_SHELL_RADIUS_Y_BOTTOM_MULT if dir.y >= 0.0 else LANE_SHELL_RADIUS_Y_TOP_MULT
	var ry: float = maxf(1.0, radius_px * ry_mult)
	var denom: float = sqrt((dir.x * dir.x) / (rx * rx) + (dir.y * dir.y) / (ry * ry))
	if denom <= 0.000001:
		return center_world
	return center_world + (dir / denom)

static func lane_anchor_pair_world(
	a_center_world: Vector2,
	b_center_world: Vector2,
	src_override_world_pos: Variant = null,
	_src_radius_px: float = 0.0,
	_dst_radius_px: float = 0.0,
	_src_global_xform: Variant = null,
	_dst_global_xform: Variant = null
) -> Dictionary:
	var lane_vec: Vector2 = b_center_world - a_center_world
	var center_dir: Vector2 = Vector2.ZERO
	if lane_vec.length_squared() > 0.000001:
		center_dir = lane_vec.normalized()
	var a_anchor: Vector2 = lane_shell_anchor_world(a_center_world, center_dir, _src_radius_px)
	var b_anchor: Vector2 = lane_shell_anchor_world(b_center_world, -center_dir, _dst_radius_px)
	var side_weight: float = 1.0
	if center_dir.length_squared() > 0.000001:
		side_weight = absf(center_dir.x)
	var left_extra: float = LANE_ANCHOR_LEFT_EXTRA_Y_PX * side_weight
	var right_extra: float = LANE_ANCHOR_RIGHT_EXTRA_Y_PX * side_weight
	if a_center_world.x <= b_center_world.x:
		a_anchor.y += left_extra
		b_anchor.y += right_extra
	else:
		a_anchor.y += right_extra
		b_anchor.y += left_extra
	if src_override_world_pos is Vector2:
		a_anchor = src_override_world_pos as Vector2
	var dir: Vector2 = Vector2.ZERO
	var lane_dir_vec: Vector2 = b_anchor - a_anchor
	if lane_dir_vec.length_squared() > 0.000001:
		dir = lane_dir_vec.normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x) if dir.length_squared() > 0.000001 else Vector2.ZERO
	return {
		"a_anchor": a_anchor,
		"b_anchor": b_anchor,
		"a": a_anchor,
		"b": b_anchor,
		"dir": dir,
		"normal": normal
	}

static func compute_lane_endpoints_world(a_center_world: Vector2, b_center_world: Vector2) -> Dictionary:
	var anchor_pair: Dictionary = lane_anchor_pair_world(a_center_world, b_center_world)
	var a_anchor: Vector2 = anchor_pair.get("a", lane_anchor_world_from_center(a_center_world))
	var b_anchor: Vector2 = anchor_pair.get("b", lane_anchor_world_from_center(b_center_world))
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
	if visual != null:
		_visual_rest_position = visual.position
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
	_ensure_flag_badge()
	_refresh_selector_state()

func _fit_pick_hitbox_to_sprite() -> void:
	if pick_shape == null:
		return
	var sprite: Node = get_node_or_null("Visual/BaseSpriteLayer/BaseSprite")
	if sprite == null:
		sprite = get_node_or_null("Visual/BaseSprite")
	if sprite == null:
		sprite = get_node_or_null("Visual/HiveSprite")
	if sprite == null or not (sprite is Sprite2D):
		return
	var s: Sprite2D = sprite as Sprite2D
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

func apply_render(
	owner_id_in: int,
	power_in: int,
	radius_in: float,
	color: Color,
	font_size: int,
	kind: String = "Hive",
	lane_budget_used: int = 0,
	lane_budget_max: int = 3
) -> void:
	SFLog.log_once(
		"HIVENODE_APPLY_RENDER",
		"HiveNode.apply_render called (sample): id=%s owner=%s power=%s kind=%s" % [str(hive_id), str(owner_id_in), str(power_in), str(kind)],
		SFLog.Level.INFO
	)
	owner_id = owner_id_in
	power = power_in
	radius_px = maxf(float(radius_in), MIN_RENDER_RADIUS_PX)
	var prev_kind: String = _last_kind
	_last_kind = kind
	if prev_kind != "" and prev_kind != kind:
		var sim_events := _get_sim_events()
		if sim_events != null:
			sim_events.emit_signal("hive_kind_changed", hive_id, owner_id, global_position, prev_kind, kind)
	_sync_collision()
	if visual != null and visual.has_method("configure"):
		visual.call("configure", owner_id, color, radius_px, power, font_size, kind, lane_budget_used, lane_budget_max)
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
	_update_flag_badge_layout()

func set_capture_flag_marker(visible: bool, flag_owner_id: int = 0, hidden: bool = false) -> void:
	var badge: Panel = _ensure_flag_badge()
	if badge == null:
		return
	badge.visible = visible
	if not visible:
		badge.scale = Vector2.ONE
		_update_fallback_process()
		return
	var accent: Color = TeamVisuals.owner_color(flag_owner_id) if flag_owner_id > 0 else Color(1.0, 0.92, 0.35, 1.0)
	_style_flag_badge(accent)
	if _flag_badge_label != null:
		_flag_badge_label.text = "FLAG"
	var tooltip_text: String = "Hidden Flag" if hidden else "Flag Hive"
	if flag_owner_id > 0:
		tooltip_text += " P%d" % flag_owner_id
	badge.tooltip_text = tooltip_text
	_update_flag_badge_layout()
	_update_fallback_process()

func set_selected(on: bool, color: Color) -> void:
	_selected = on
	_sel_color = color
	if visual != null and visual.has_method("set_selected_visual"):
		visual.call("set_selected_visual", on, color)
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
	_update_fallback_process()

func set_swarm_cooldown(remaining_ms: int, total_ms: int = 5000) -> void:
	var safe_remaining: int = maxi(0, remaining_ms)
	_swarm_cooldown_total_ms = maxi(1, total_ms)
	if safe_remaining <= 0:
		if _swarm_cooldown_until_msec != 0 and visual != null:
			visual.position = _visual_rest_position
		_swarm_cooldown_until_msec = 0
		_update_fallback_process()
		queue_redraw()
		return
	_swarm_cooldown_until_msec = Time.get_ticks_msec() + safe_remaining
	_update_fallback_process()
	queue_redraw()

func _process(delta: float) -> void:
	var cooldown_active: bool = _swarm_cooldown_active()
	if not (_selected or _hovered or _activated or (_flag_badge != null and _flag_badge.visible) or cooldown_active):
		return
	_sel_t += delta * 3.0
	if visual != null:
		if cooldown_active:
			var t_sec: float = float(Time.get_ticks_msec()) / 1000.0
			var x: float = sin(t_sec * TAU * SWARM_COOLDOWN_SHAKE_HZ) * SWARM_COOLDOWN_SHAKE_PX
			var y: float = sin(t_sec * TAU * (SWARM_COOLDOWN_SHAKE_HZ * 0.47)) * (SWARM_COOLDOWN_SHAKE_PX * 0.35)
			visual.position = _visual_rest_position + Vector2(x, y)
		elif visual.position != _visual_rest_position:
			visual.position = _visual_rest_position
			_update_fallback_process()
	if _flag_badge != null and _flag_badge.visible:
		var badge_pulse: float = 1.0 + (0.045 * (0.5 + 0.5 * sin(_sel_t * 1.4)))
		_flag_badge.scale = Vector2(badge_pulse, badge_pulse)
	queue_redraw()

func _draw() -> void:
	var cooldown_active: bool = _swarm_cooldown_active()
	if cooldown_active:
		_draw_swarm_cooldown_ring()
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

func _draw_swarm_cooldown_ring() -> void:
	var remaining_ms: int = _swarm_cooldown_remaining_ms()
	if remaining_ms <= 0:
		return
	var progress: float = clampf(float(remaining_ms) / float(maxi(1, _swarm_cooldown_total_ms)), 0.0, 1.0)
	var r: float = radius_px + 12.0
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	var pulse_alpha: float = 0.25 + 0.20 * (0.5 + 0.5 * sin(_sel_t * 5.0))
	draw_circle(Vector2.ZERO, r + 3.0, Color(1.0, 0.72, 0.20, pulse_alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.05, 0.06, 0.08, 0.65), 5.0)
	draw_arc(Vector2.ZERO, r, start_angle, end_angle, 64, Color(1.0, 0.78, 0.24, 0.95), 5.0)

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
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if SFLog.LOGGING_ENABLED:
				print("HIVE_NODE_TOUCH hive_id=", hive_id)
			emit_signal("hive_clicked", hive_id, MOUSE_BUTTON_LEFT, global_position)
			return
		emit_signal("hive_released", hive_id, MOUSE_BUTTON_LEFT, global_position)

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

func _style_flag_badge(accent: Color) -> void:
	if _flag_badge == null or not is_instance_valid(_flag_badge):
		return
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.05, 0.09, 0.94)
	panel_style.border_color = accent.lightened(0.12)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 3
	_flag_badge.add_theme_stylebox_override("panel", panel_style)
	if _flag_badge_label != null:
		_flag_badge_label.add_theme_color_override("font_color", accent.lightened(0.20))

func _ensure_flag_badge() -> Panel:
	if _flag_badge != null and is_instance_valid(_flag_badge):
		return _flag_badge
	var badge := Panel.new()
	badge.name = "FlagBadge"
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(82.0, 28.0)
	badge.pivot_offset = badge.size * 0.5
	add_child(badge)
	var label := Label.new()
	label.name = "FlagText"
	label.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "FLAG"
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	if ResourceLoader.exists(FLAG_BADGE_FONT_PATH):
		var badge_font: Resource = load(FLAG_BADGE_FONT_PATH)
		if badge_font is Font:
			label.add_theme_font_override("font", badge_font as Font)
	badge.add_child(label)
	_flag_badge = badge
	_flag_badge_label = label
	_style_flag_badge(Color(1.0, 0.92, 0.35, 1.0))
	_update_flag_badge_layout()
	return _flag_badge

func _update_flag_badge_layout() -> void:
	if _flag_badge == null or not is_instance_valid(_flag_badge):
		return
	var y_offset: float = -maxf(radius_px, MIN_RENDER_RADIUS_PX) - 34.0
	_flag_badge.position = Vector2(maxf(12.0, radius_px * 0.55), y_offset)

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

func _swarm_cooldown_remaining_ms() -> int:
	if _swarm_cooldown_until_msec <= 0:
		return 0
	return maxi(0, _swarm_cooldown_until_msec - Time.get_ticks_msec())

func _swarm_cooldown_active() -> bool:
	return _swarm_cooldown_remaining_ms() > 0

func _update_fallback_process() -> void:
	var needs_fallback := _selector_sprite == null or _selector_sprite.texture == null
	set_process((needs_fallback and (_selected or _hovered or _activated)) or (_flag_badge != null and _flag_badge.visible) or _swarm_cooldown_active())

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
