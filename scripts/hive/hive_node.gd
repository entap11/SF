extends Area2D

signal hive_clicked(hive_id: int, button: int, global_pos: Vector2)
signal hive_released(hive_id: int, button: int, global_pos: Vector2)
signal hive_hovered(hive_id: int, global_pos: Vector2)
signal hive_unhovered(hive_id: int)

const SFLog := preload("res://scripts/util/sf_log.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const HiveGeometry := preload("res://scripts/sim/hive_geometry.gd")
const HiveGrowthRules := preload("res://scripts/sim/hive_growth_rules.gd")
const HiveDistressLightScript := preload("res://scripts/hive/hive_distress_light.gd")
const SELECTOR_PULSE_SHADER := preload("res://shaders/selector_pulse.gdshader")
const SELECTOR_SMALL_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_small.tres"
const SELECTOR_MEDIUM_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_medium.tres"
const SELECTOR_LARGE_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_large.tres"
const FLAG_CTF_PATH := "res://assets/sprites/sf_skin_v1/flag_ctf.png"
const FLAG_HCTF_PATH := "res://assets/sprites/sf_skin_v1/flag_hctf.png"
const FLAG_PROJECTION_SHADER := preload("res://assets/shaders/sf_color_swap.gdshader")

const SELECTOR_STATE_INACTIVE := 0
const SELECTOR_STATE_HOVER := 1
const SELECTOR_STATE_SELECTED := 2
const SELECTOR_STATE_ACTIVATED := 3
const SELECTOR_STATE_TARGET_VALID := 4
const SELECTOR_STATE_TARGET_INVALID := 5
# Legacy zero-direction fallback used when no lane bearing is available.
const LANE_ANCHOR_Y_PX: float = -24.0
const LANE_ANCHOR_LEFT_EXTRA_Y_PX: float = 0.0
const LANE_ANCHOR_RIGHT_EXTRA_Y_PX: float = 0.0
const LANE_SHELL_RADIUS_X_MULT: float = 1.55
const LANE_SHELL_RADIUS_Y_TOP_MULT: float = 1.08
const LANE_SHELL_RADIUS_Y_BOTTOM_MULT: float = 0.92
# The hive art is a perspective cylinder: side-facing sockets belong on the
# lower skirt, while vertical lanes should retain their straight centerline.
# This radius multiplier matches the skirt at the current canonical art scale.
const LANE_SHELL_SKIRT_Y_RADIUS_MULT: float = 1.65
const LANE_SHELL_SKIRT_Y_EXTRA_PX: float = 10.0

@export var hive_id: int = -1
@export var owner_id: int = 0

var power: int = 0
var growth_tier: int = HiveGrowthRules.TIER_SMALL
var radius_px: float = 18.0
var _selected := false
var _hovered := false
var _activated := false
var _target_hint_active := false
var _target_hint_valid := false
var _sel_t := 0.0
var _sel_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _selected_color: Color = Color(1.0, 1.0, 1.0, 1.0)
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
const SELECTOR_TARGET_VALID_PULSE_SPEED := 4.2
const SELECTOR_TARGET_VALID_PULSE_STRENGTH := 0.45
const SELECTOR_TARGET_VALID_GLOW_BOOST := 1.9
const SELECTOR_TARGET_VALID_SCALE := 1.12
const SELECTOR_TARGET_INVALID_PULSE_SPEED := 2.4
const SELECTOR_TARGET_INVALID_PULSE_STRENGTH := 0.18
const SELECTOR_TARGET_INVALID_GLOW_BOOST := 0.65
const SELECTOR_TARGET_INVALID_SCALE := 1.04
const SELECTOR_BASE_ALPHA := 0.85
const SELECTOR_TARGET_VALID_ALPHA := 1.0
const SELECTOR_TARGET_INVALID_ALPHA := 0.78
const TARGET_INVALID_GREY := Color(0.62, 0.66, 0.70, 1.0)
const SWARM_COOLDOWN_SHAKE_PX := 2.8
const SWARM_COOLDOWN_SHAKE_HZ := 24.0
const FLAG_Z_INDEX := -7
const FLAG_TARGET_HEIGHT_SMALL_PX := 92.0
const FLAG_TARGET_HEIGHT_MEDIUM_PX := 104.0
const FLAG_TARGET_HEIGHT_LARGE_PX := 118.0
const FLAG_OFFSET_SMALL := Vector2(1.10, 0.60)
const FLAG_OFFSET_MEDIUM := Vector2(1.25, 0.75)
const FLAG_OFFSET_LARGE := Vector2(1.40, 0.90)

@onready var visual: Node2D = $Visual
@onready var match_shadow_sprite: Sprite2D = $MatchShadowSprite
@onready var match_contact_shadow_sprite: Sprite2D = $MatchContactShadowSprite
@onready var capture_flag_sprite: Sprite2D = $CaptureFlagSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var pick_shape: CollisionShape2D = $PickShape2D

var _selector_sprite: Sprite2D = null
var _selector_tex_small: Texture2D = null
var _selector_tex_med: Texture2D = null
var _selector_tex_large: Texture2D = null
var _selector_mat: ShaderMaterial = null
var _selector_state: int = SELECTOR_STATE_INACTIVE
var _last_kind: String = ""
var _sim_events: Node = null
var _distress_light: Node2D = null
var _latest_distress_presentation: Dictionary = {}
var _distress_pre_transition_footprint: Vector2 = Vector2.ZERO
var _distress_current_footprint: Vector2 = Vector2.ZERO
var _flag_projection_material: ShaderMaterial = null
var _flag_ctf_texture: Texture2D = null
var _flag_hctf_texture: Texture2D = null
var _visual_rest_position: Vector2 = Vector2.ZERO
var _swarm_cooldown_until_msec: int = 0
var _swarm_cooldown_total_ms: int = 5000
var _match_shadow_profile_id: String = ""
var _pending_match_shadow_presentation: Dictionary = {}
var _defer_match_shadow_swap: bool = false
var _pending_growth_tier: int = 0
static var _match_contact_shadow_texture: Texture2D = null

const MATCH_CONTACT_TEXTURE_SIZE := Vector2i(128, 64)
const MATCH_CONTACT_SIZE_SMALL := Vector2(74.0, 16.0)
const MATCH_CONTACT_SIZE_MEDIUM := Vector2(96.0, 20.0)
const MATCH_CONTACT_SIZE_LARGE := Vector2(120.0, 24.0)
const MATCH_CONTACT_OFFSET := Vector2(0.0, 15.0)

static func lane_anchor_world_from_center(center_world: Vector2) -> Vector2:
	return center_world + Vector2(0.0, -LANE_ANCHOR_Y_PX)

static func lane_shell_anchor_world(center_world: Vector2, outward_dir: Vector2, radius_px: float, power: int = 0) -> Vector2:
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
	var anchor: Vector2 = center_world + (dir / denom)
	var side_weight: float = absf(dir.x)
	var tier_scale: float = HiveGeometry.hive_visual_height_tier_scale(power)
	var skirt_y: float = (radius_px * LANE_SHELL_SKIRT_Y_RADIUS_MULT * tier_scale) + LANE_SHELL_SKIRT_Y_EXTRA_PX
	anchor.y += skirt_y * side_weight
	return anchor

static func lane_anchor_pair_world(
	a_center_world: Vector2,
	b_center_world: Vector2,
	src_override_world_pos: Variant = null,
	_src_radius_px: float = 0.0,
	_dst_radius_px: float = 0.0,
	_src_global_xform: Variant = null,
	_dst_global_xform: Variant = null,
	_src_power: int = 0,
	_dst_power: int = 0
) -> Dictionary:
	var lane_vec: Vector2 = b_center_world - a_center_world
	var center_dir: Vector2 = Vector2.ZERO
	if lane_vec.length_squared() > 0.000001:
		center_dir = lane_vec.normalized()
	var a_anchor: Vector2 = lane_shell_anchor_world(a_center_world, center_dir, _src_radius_px, _src_power)
	var b_anchor: Vector2 = lane_shell_anchor_world(b_center_world, -center_dir, _dst_radius_px, _dst_power)
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
	_ensure_capture_flag_sprite()
	_bind_growth_transition_shadow_swap()
	_refresh_selector_state()

func _fit_pick_hitbox_to_sprite() -> void:
	if pick_shape == null:
		return
	var circle := pick_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		pick_shape.shape = circle
	circle.radius = get_pick_radius_px()
	pick_shape.position = Vector2.ZERO
	pick_shape.disabled = false
	SFLog.log_once("HIVE_PICK_BOX", "HIVE_PICK_BOX fitted", SFLog.Level.INFO)

func get_pick_radius_px() -> float:
	return HiveGeometry.hive_input_pick_radius_px(radius_px, power)

func apply_render(
	owner_id_in: int,
	power_in: int,
	radius_in: float,
	color: Color,
	font_size: int,
	kind: String = "Hive",
	lane_budget_used: int = 0,
	lane_budget_max: int = 3,
	growth_tier_in: int = 0,
	growth_transition: Dictionary = {}
) -> void:
	SFLog.log_once(
		"HIVENODE_APPLY_RENDER",
		"HiveNode.apply_render called (sample): id=%s owner=%s power=%s kind=%s" % [str(hive_id), str(owner_id_in), str(power_in), str(kind)],
		SFLog.Level.INFO
	)
	_distress_pre_transition_footprint = _get_visual_footprint()
	var previous_growth_tier: int = growth_tier
	var desired_growth_tier: int = clampi(
		growth_tier_in if growth_tier_in > 0 else HiveGrowthRules.tier_for_power(power_in),
		HiveGrowthRules.TIER_SMALL,
		HiveGrowthRules.TIER_LARGE
	)
	var transition_mode: String = str(growth_transition.get("mode", "none"))
	var transition_will_cover_swap: bool = (
		bool(growth_transition.get("play", false))
		and transition_mode != "none"
		and desired_growth_tier > previous_growth_tier
	)
	if not (_defer_match_shadow_swap and _growth_transition_active()):
		_defer_match_shadow_swap = transition_will_cover_swap
	owner_id = owner_id_in
	power = power_in
	if transition_will_cover_swap:
		_pending_growth_tier = desired_growth_tier
	else:
		_pending_growth_tier = 0
		growth_tier = desired_growth_tier
	radius_px = maxf(float(radius_in), MIN_RENDER_RADIUS_PX)
	var prev_kind: String = _last_kind
	_last_kind = kind
	if prev_kind != "" and prev_kind != kind:
		var sim_events := _get_sim_events()
		if sim_events != null:
			sim_events.emit_signal("hive_kind_changed", hive_id, owner_id, global_position, prev_kind, kind)
	_sync_collision()
	if visual != null and visual.has_method("configure"):
		visual.call(
			"configure",
			owner_id,
			color,
			radius_px,
			power,
			font_size,
			kind,
			lane_budget_used,
			lane_budget_max,
			desired_growth_tier,
			growth_transition
		)
	_distress_current_footprint = _get_visual_footprint()
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
	_update_capture_flag_layout()

func apply_match_shadow_presentation(presentation: Dictionary) -> void:
	var next_profile_id: String = str(presentation.get("profile_id", ""))
	if (
		_defer_match_shadow_swap
		and _growth_transition_active()
		and next_profile_id != _match_shadow_profile_id
	):
		_pending_match_shadow_presentation = presentation.duplicate()
		return
	_apply_match_shadow_presentation_now(presentation)

func _apply_match_shadow_presentation_now(presentation: Dictionary) -> void:
	var shadow: Sprite2D = _ensure_match_shadow_sprite()
	if shadow == null:
		return
	if not bool(presentation.get("enabled", false)):
		_match_shadow_profile_id = ""
		shadow.visible = false
		shadow.texture = null
		shadow.material = null
		_hide_match_contact_shadow()
		return
	var texture: Texture2D = presentation.get("canvas_texture", null) as Texture2D
	var material: Material = presentation.get("material", null) as Material
	if texture == null or material == null:
		_match_shadow_profile_id = ""
		shadow.visible = false
		shadow.texture = null
		shadow.material = null
		_hide_match_contact_shadow()
		return
	_match_shadow_profile_id = str(presentation.get("profile_id", ""))
	shadow.texture = texture
	shadow.material = material
	shadow.centered = false
	shadow.z_index = -9
	var base_scale: float = maxf(0.0001, float(presentation.get("scale", 1.0)))
	var length_scale: float = clampf(float(presentation.get("length_scale", 1.0)), 0.01, 1.0)
	shadow.scale = Vector2(base_scale * length_scale, base_scale)
	_update_match_shadow_layout(presentation)
	_update_match_contact_shadow(presentation)
	shadow.self_modulate = Color.WHITE
	shadow.visible = true

func _bind_growth_transition_shadow_swap() -> void:
	var transition: Node = get_node_or_null("Visual/FxLayer/HiveGrowthTransition")
	if transition == null:
		return
	var started_callback := Callable(self, "_on_growth_transition_started_for_distress")
	if transition.has_signal("transition_started") and not transition.is_connected("transition_started", started_callback):
		transition.connect("transition_started", started_callback)
	var reveal_callback := Callable(self, "_on_final_ring_reveal_started")
	if transition.has_signal("final_ring_reveal_started") and not transition.is_connected("final_ring_reveal_started", reveal_callback):
		transition.connect("final_ring_reveal_started", reveal_callback)
	var finished_callback := Callable(self, "_on_growth_transition_finished_for_shadow")
	if transition.has_signal("transition_finished") and not transition.is_connected("transition_finished", finished_callback):
		transition.connect("transition_finished", finished_callback)
	var cancelled_callback := Callable(self, "_on_growth_transition_cancelled_for_shadow")
	if transition.has_signal("transition_cancelled") and not transition.is_connected("transition_cancelled", cancelled_callback):
		transition.connect("transition_cancelled", cancelled_callback)

func _on_final_ring_reveal_started(_new_tier: int) -> void:
	_commit_pending_growth_presentation()

func _on_growth_transition_finished_for_shadow(_new_tier: int) -> void:
	_commit_pending_growth_presentation()
	_set_distress_growth_suppressed(false)

func _on_growth_transition_cancelled_for_shadow(_reason: String) -> void:
	_commit_pending_growth_presentation()
	_set_distress_growth_suppressed(false)

func _on_growth_transition_started_for_distress(_old_tier: int, _new_tier: int) -> void:
	_set_distress_growth_suppressed(true)

func _commit_pending_growth_presentation() -> void:
	if _pending_growth_tier > 0:
		growth_tier = _pending_growth_tier
		_pending_growth_tier = 0
	if visual != null and visual.has_method("commit_growth_presentation"):
		visual.call("commit_growth_presentation")
	_update_selector_visual()
	_update_capture_flag_layout()
	if _selected:
		queue_redraw()
	_flush_pending_match_shadow_presentation()

func _flush_pending_match_shadow_presentation() -> void:
	_defer_match_shadow_swap = false
	if _pending_match_shadow_presentation.is_empty():
		return
	var pending: Dictionary = _pending_match_shadow_presentation
	_pending_match_shadow_presentation = {}
	_apply_match_shadow_presentation_now(pending)

func _growth_transition_active() -> bool:
	if visual != null and visual.has_method("get_growth_transition_debug_snapshot"):
		var snapshot: Dictionary = visual.call("get_growth_transition_debug_snapshot") as Dictionary
		return bool(snapshot.get("active", false))
	return false

func get_match_shadow_debug_snapshot() -> Dictionary:
	var shadow: Sprite2D = _ensure_match_shadow_sprite()
	if shadow == null:
		return {"available": false}
	var assigned_material: Material = shadow.material
	var assigned_texture: Texture2D = shadow.texture
	var contact: Sprite2D = _ensure_match_contact_shadow_sprite()
	return {
		"available": true,
		"visible": shadow.visible,
		"profile_id": _match_shadow_profile_id,
		"position": shadow.position,
		"scale": shadow.scale,
		"has_material": assigned_material != null,
		"material_class": assigned_material.get_class() if assigned_material != null else "",
		"material_instance_id": assigned_material.get_instance_id() if assigned_material != null else 0,
		"has_texture": assigned_texture != null,
		"texture_size": assigned_texture.get_size() if assigned_texture != null else Vector2.ZERO,
		"contact_visible": contact != null and contact.visible,
		"contact_position": contact.position if contact != null else Vector2.ZERO,
		"contact_scale": contact.scale if contact != null else Vector2.ZERO,
		"is_visual_child": visual != null and visual.is_ancestor_of(shadow)
	}

func _ensure_match_shadow_sprite() -> Sprite2D:
	if match_shadow_sprite != null and is_instance_valid(match_shadow_sprite):
		return match_shadow_sprite
	var existing: Node = get_node_or_null("MatchShadowSprite")
	if existing is Sprite2D:
		match_shadow_sprite = existing as Sprite2D
		return match_shadow_sprite
	var shadow := Sprite2D.new()
	shadow.name = "MatchShadowSprite"
	shadow.centered = false
	shadow.z_index = -9
	shadow.visible = false
	add_child(shadow)
	match_shadow_sprite = shadow
	return match_shadow_sprite

func _ensure_match_contact_shadow_sprite() -> Sprite2D:
	if match_contact_shadow_sprite != null and is_instance_valid(match_contact_shadow_sprite):
		return match_contact_shadow_sprite
	var existing: Node = get_node_or_null("MatchContactShadowSprite")
	if existing is Sprite2D:
		match_contact_shadow_sprite = existing as Sprite2D
		return match_contact_shadow_sprite
	var contact := Sprite2D.new()
	contact.name = "MatchContactShadowSprite"
	contact.z_index = -5
	contact.visible = false
	add_child(contact)
	match_contact_shadow_sprite = contact
	return match_contact_shadow_sprite

func _hide_match_contact_shadow() -> void:
	var contact: Sprite2D = _ensure_match_contact_shadow_sprite()
	if contact != null:
		contact.visible = false

func _update_match_contact_shadow(presentation: Dictionary) -> void:
	var contact: Sprite2D = _ensure_match_contact_shadow_sprite()
	if contact == null:
		return
	var contact_texture: Texture2D = _get_match_contact_shadow_texture()
	if contact_texture == null:
		contact.visible = false
		return
	var tier: int = clampi(
		int(presentation.get("tier", growth_tier)),
		HiveGrowthRules.TIER_SMALL,
		HiveGrowthRules.TIER_LARGE
	)
	var target_size: Vector2 = MATCH_CONTACT_SIZE_SMALL
	if tier >= HiveGrowthRules.TIER_LARGE:
		target_size = MATCH_CONTACT_SIZE_LARGE
	elif tier >= HiveGrowthRules.TIER_MEDIUM:
		target_size = MATCH_CONTACT_SIZE_MEDIUM
	contact.texture = contact_texture
	contact.centered = true
	contact.z_index = -5
	contact.position = _stable_match_shadow_ground_contact() + MATCH_CONTACT_OFFSET
	contact.scale = Vector2(
		target_size.x / float(MATCH_CONTACT_TEXTURE_SIZE.x),
		target_size.y / float(MATCH_CONTACT_TEXTURE_SIZE.y)
	)
	contact.self_modulate = Color.WHITE
	contact.visible = true

static func _get_match_contact_shadow_texture() -> Texture2D:
	if _match_contact_shadow_texture != null:
		return _match_contact_shadow_texture
	var image: Image = Image.create(
		MATCH_CONTACT_TEXTURE_SIZE.x,
		MATCH_CONTACT_TEXTURE_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	for y in range(MATCH_CONTACT_TEXTURE_SIZE.y):
		var normalized_y: float = (
			(float(y) + 0.5) / float(MATCH_CONTACT_TEXTURE_SIZE.y) - 0.5
		) * 2.0
		for x in range(MATCH_CONTACT_TEXTURE_SIZE.x):
			var normalized_x: float = (
				(float(x) + 0.5) / float(MATCH_CONTACT_TEXTURE_SIZE.x) - 0.5
			) * 2.0
			var radial_distance: float = sqrt(
				(normalized_x * normalized_x) + (normalized_y * normalized_y)
			)
			var falloff: float = clampf(1.0 - radial_distance, 0.0, 1.0)
			var alpha: float = pow(falloff, 1.65) * 0.52
			image.set_pixel(x, y, Color(0.018, 0.016, 0.024, alpha))
	_match_contact_shadow_texture = ImageTexture.create_from_image(image)
	return _match_contact_shadow_texture

func _stable_match_shadow_ground_contact() -> Vector2:
	var ground_contact: Vector2 = Vector2.ZERO
	if visual != null and visual.has_method("get_match_shadow_ground_contact_local"):
		var visual_contact: Vector2 = visual.call("get_match_shadow_ground_contact_local") as Vector2
		var stable_visual_transform: Transform2D = visual.transform
		stable_visual_transform.origin = _visual_rest_position
		ground_contact = stable_visual_transform * visual_contact
	return ground_contact

func _update_match_shadow_layout(presentation: Dictionary) -> void:
	if match_shadow_sprite == null or not is_instance_valid(match_shadow_sprite):
		return
	var ground_contact: Vector2 = _stable_match_shadow_ground_contact()
	var local_offset: Vector2 = presentation.get("local_offset", Vector2.ZERO) as Vector2
	var anchor_px: Vector2 = presentation.get("ground_anchor_px", Vector2.ZERO) as Vector2
	match_shadow_sprite.position = (
		ground_contact
		+ local_offset
		- Vector2(anchor_px.x * match_shadow_sprite.scale.x, anchor_px.y * match_shadow_sprite.scale.y)
	)

func cancel_growth_transition(reason: String = "cancelled") -> void:
	if visual != null and visual.has_method("cancel_growth_transition"):
		visual.call("cancel_growth_transition", reason)

func get_growth_transition_debug_snapshot() -> Dictionary:
	if visual != null and visual.has_method("get_growth_transition_debug_snapshot"):
		return visual.call("get_growth_transition_debug_snapshot") as Dictionary
	return {"active": false, "missing": true}

func apply_distress_presentation(
	viewer_owner_id: int,
	hostile_capture_pressure: bool,
	color: Color,
	motion_mode: String,
	presentation: Dictionary = {}
) -> void:
	var resolved: Dictionary = presentation.duplicate(true)
	resolved["pre_transition_size"] = _distress_pre_transition_footprint
	resolved["current_size"] = _distress_current_footprint
	_latest_distress_presentation = {
		"viewer_owner_id": viewer_owner_id,
		"hostile_capture_pressure": hostile_capture_pressure,
		"color": color,
		"motion_mode": motion_mode,
		"resolved": resolved
	}
	_refresh_distress_presentation()

func _refresh_distress_presentation() -> void:
	var distress: Node2D = _ensure_distress_light()
	if distress == null or _latest_distress_presentation.is_empty():
		return
	var outlet_anchor: Vector2 = Vector2(0.0, -maxf(18.0, radius_px))
	if visual != null and visual.has_method("get_distress_outlet_anchor_local"):
		outlet_anchor = visual.call(
			"get_distress_outlet_anchor_local",
			growth_tier
		) as Vector2
	distress.call(
		"apply_presentation",
		hive_id,
		outlet_anchor,
		_latest_distress_presentation.get("color", Color.WHITE) as Color,
		str(_latest_distress_presentation.get("motion_mode", "full")),
		_latest_distress_presentation.get("resolved", {}) as Dictionary,
		bool(_latest_distress_presentation.get("hostile_capture_pressure", false))
	)
	if distress.has_method("set_growth_suppressed"):
		distress.call("set_growth_suppressed", _growth_transition_active())

func _ensure_distress_light() -> Node2D:
	if _distress_light != null and is_instance_valid(_distress_light):
		return _distress_light
	var existing: Node = get_node_or_null("Visual/FxLayer/HiveDistressLight")
	if existing is Node2D:
		_distress_light = existing as Node2D
		return _distress_light
	var fx_layer: Node = get_node_or_null("Visual/FxLayer")
	if fx_layer == null:
		return null
	var created: Node2D = HiveDistressLightScript.new() as Node2D
	created.name = "HiveDistressLight"
	fx_layer.add_child(created)
	_distress_light = created
	return _distress_light

func _get_visual_footprint() -> Vector2:
	if visual != null and visual.has_method("get_rendered_footprint_local"):
		return visual.call("get_rendered_footprint_local") as Vector2
	var fallback_diameter: float = maxf(20.0, radius_px * 2.0)
	return Vector2(fallback_diameter, fallback_diameter)

func _set_distress_growth_suppressed(suppressed: bool) -> void:
	var distress: Node2D = _ensure_distress_light()
	if distress != null and distress.has_method("set_growth_suppressed"):
		distress.call("set_growth_suppressed", suppressed)
	if not suppressed:
		_refresh_distress_presentation()

func set_distress_lifecycle_suspended(suspended: bool) -> void:
	var distress: Node2D = _ensure_distress_light()
	if distress != null and distress.has_method("set_lifecycle_suspended"):
		distress.call("set_lifecycle_suspended", suspended)

func get_distress_debug_snapshot() -> Dictionary:
	var distress: Node2D = _ensure_distress_light()
	if distress != null and distress.has_method("get_debug_snapshot"):
		return distress.call("get_debug_snapshot") as Dictionary
	return {"state": "normal", "missing": true}

func set_capture_flag_marker(visible: bool, flag_owner_id: int = 0, hidden: bool = false) -> void:
	var flag_sprite: Sprite2D = _ensure_capture_flag_sprite()
	if flag_sprite == null:
		return
	var flag_texture: Texture2D = _capture_flag_texture(hidden)
	if flag_texture != null and flag_sprite.texture != flag_texture:
		flag_sprite.texture = flag_texture
	flag_sprite.visible = visible
	flag_sprite.set_meta("capture_flag_hidden", hidden)
	flag_sprite.set_meta("capture_flag_owner_id", flag_owner_id)
	if not visible:
		return
	var accent: Color = TeamVisuals.owner_color(flag_owner_id) if flag_owner_id > 0 else Color(1.0, 0.92, 0.35, 1.0)
	_apply_capture_flag_team_color(accent)
	_update_capture_flag_layout()

func set_selected(on: bool, color: Color) -> void:
	_selected = on
	_selected_color = color
	if not _selected:
		_sel_t = 0.0
	_refresh_selector_state()
	_update_selector_visual()
	_apply_visual_highlight()
	_update_fallback_process()
	queue_redraw()

func set_target_hint(active: bool, valid: bool) -> void:
	if _target_hint_active == active and _target_hint_valid == valid:
		return
	_target_hint_active = active
	_target_hint_valid = valid
	_refresh_selector_state()
	_update_selector_visual()
	_apply_visual_highlight()
	_update_fallback_process()
	queue_redraw()

func set_activated(on: bool) -> void:
	if _activated == on:
		return
	_activated = on
	_refresh_selector_state()
	_update_selector_visual()
	_apply_visual_highlight()
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
	if not (_selected or _hovered or _activated or _target_hint_active or cooldown_active):
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
	queue_redraw()

func _draw() -> void:
	var cooldown_active: bool = _swarm_cooldown_active()
	if cooldown_active:
		_draw_swarm_cooldown_ring()
	if _selector_state == SELECTOR_STATE_INACTIVE:
		return
	if _selector_state == SELECTOR_STATE_SELECTED or _selector_state == SELECTOR_STATE_ACTIVATED:
		return
	if _selector_sprite != null and _selector_sprite.texture != null:
		return
	var r := 24.0
	var cs := get_node_or_null("CollisionShape2D")
	if cs is CollisionShape2D and (cs as CollisionShape2D).shape is CircleShape2D:
		r = ((cs as CollisionShape2D).shape as CircleShape2D).radius
	r += SEL_PAD
	var pulse := 0.6 + 0.4 * (0.5 + 0.5 * sin(_sel_t))
	var c := _selector_color_for_state(_selector_state)
	c.a *= pulse
	var pts := PackedVector2Array()
	var offset := _selector_offset_for_tier(growth_tier)
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

func _ensure_capture_flag_sprite() -> Sprite2D:
	if capture_flag_sprite != null and is_instance_valid(capture_flag_sprite):
		_cache_capture_flag_textures()
		return capture_flag_sprite
	var existing: Node = get_node_or_null("CaptureFlagSprite")
	if existing is Sprite2D:
		capture_flag_sprite = existing as Sprite2D
	else:
		var sprite := Sprite2D.new()
		sprite.name = "CaptureFlagSprite"
		add_child(sprite)
		capture_flag_sprite = sprite
	if capture_flag_sprite.texture == null and ResourceLoader.exists(FLAG_CTF_PATH):
		capture_flag_sprite.texture = ResourceLoader.load(FLAG_CTF_PATH) as Texture2D
	_cache_capture_flag_textures()
	capture_flag_sprite.centered = true
	capture_flag_sprite.z_index = FLAG_Z_INDEX
	capture_flag_sprite.visible = false
	_update_capture_flag_layout()
	return capture_flag_sprite

func _cache_capture_flag_textures() -> void:
	if _flag_ctf_texture == null:
		if capture_flag_sprite != null and capture_flag_sprite.texture != null:
			_flag_ctf_texture = capture_flag_sprite.texture
		elif ResourceLoader.exists(FLAG_CTF_PATH):
			_flag_ctf_texture = ResourceLoader.load(FLAG_CTF_PATH) as Texture2D
	if _flag_hctf_texture == null and ResourceLoader.exists(FLAG_HCTF_PATH):
		_flag_hctf_texture = ResourceLoader.load(FLAG_HCTF_PATH) as Texture2D

func _capture_flag_texture(hidden: bool) -> Texture2D:
	_cache_capture_flag_textures()
	if hidden and _flag_hctf_texture != null:
		return _flag_hctf_texture
	return _flag_ctf_texture

func _apply_capture_flag_team_color(accent: Color) -> void:
	if capture_flag_sprite == null or not is_instance_valid(capture_flag_sprite):
		return
	if _flag_projection_material == null:
		_flag_projection_material = ShaderMaterial.new()
		_flag_projection_material.shader = FLAG_PROJECTION_SHADER
		_flag_projection_material.set_shader_parameter("from_color", Color.WHITE)
		_flag_projection_material.set_shader_parameter("hue_thresh", 0.0)
		_flag_projection_material.set_shader_parameter("sat_min", 1.0)
		_flag_projection_material.set_shader_parameter("val_min", 0.50)
		_flag_projection_material.set_shader_parameter("softness", 0.08)
		_flag_projection_material.set_shader_parameter("white_sat_max", TeamVisuals.WHITE_SAT_MAX)
		_flag_projection_material.set_shader_parameter("white_val_min", 0.50)
		_flag_projection_material.set_shader_parameter("white_strength", 1.0)
	_flag_projection_material.set_shader_parameter("to_color", accent)
	capture_flag_sprite.material = _flag_projection_material
	capture_flag_sprite.self_modulate = Color.WHITE

func _update_capture_flag_layout() -> void:
	if capture_flag_sprite == null or not is_instance_valid(capture_flag_sprite):
		return
	var target_height: float = FLAG_TARGET_HEIGHT_SMALL_PX
	var offset_mul: Vector2 = FLAG_OFFSET_SMALL
	if growth_tier >= HiveGrowthRules.TIER_LARGE:
		target_height = FLAG_TARGET_HEIGHT_LARGE_PX
		offset_mul = FLAG_OFFSET_LARGE
	elif growth_tier >= HiveGrowthRules.TIER_MEDIUM:
		target_height = FLAG_TARGET_HEIGHT_MEDIUM_PX
		offset_mul = FLAG_OFFSET_MEDIUM
	var texture_height: float = float(capture_flag_sprite.texture.get_height()) if capture_flag_sprite.texture != null else 0.0
	var uniform_scale: float = target_height / texture_height if texture_height > 0.0 else 1.0
	capture_flag_sprite.scale = Vector2.ONE * uniform_scale
	capture_flag_sprite.position = Vector2(radius_px * offset_mul.x, radius_px * offset_mul.y)

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

func _selector_texture_for_tier(tier: int) -> Texture2D:
	if tier >= HiveGrowthRules.TIER_LARGE:
		return _selector_tex_large
	if tier >= HiveGrowthRules.TIER_MEDIUM:
		return _selector_tex_med
	return _selector_tex_small

func _refresh_selector_state() -> void:
	if _target_hint_active and _target_hint_valid:
		_selector_state = SELECTOR_STATE_TARGET_VALID
	elif _target_hint_active:
		_selector_state = SELECTOR_STATE_TARGET_INVALID
	elif _activated:
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
	if _selector_state == SELECTOR_STATE_SELECTED or _selector_state == SELECTOR_STATE_ACTIVATED:
		_selector_sprite.visible = false
		_selector_sprite.texture = null
		return
	var tex := _selector_texture_for_tier(growth_tier)
	_selector_sprite.texture = tex
	_selector_sprite.visible = _selector_state != SELECTOR_STATE_INACTIVE and tex != null
	_selector_sprite.position = _selector_offset_for_tier(growth_tier)
	_selector_sprite.modulate = _selector_color_for_state(_selector_state)
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

func _selector_offset_for_tier(tier: int) -> Vector2:
	var offset_mul := SELECTOR_OFFSET_SMALL_MUL
	if tier >= HiveGrowthRules.TIER_LARGE:
		offset_mul = SELECTOR_OFFSET_LARGE_MUL
	elif tier >= HiveGrowthRules.TIER_MEDIUM:
		offset_mul = SELECTOR_OFFSET_MED_MUL
	return Vector2(0.0, radius_px * offset_mul)

func _selector_scale_for_state(state: int) -> float:
	match state:
		SELECTOR_STATE_TARGET_VALID:
			return SELECTOR_TARGET_VALID_SCALE
		SELECTOR_STATE_TARGET_INVALID:
			return SELECTOR_TARGET_INVALID_SCALE
		SELECTOR_STATE_ACTIVATED:
			return SELECTOR_ACTIVATED_SCALE
		SELECTOR_STATE_SELECTED:
			return SELECTOR_SELECTED_SCALE
		SELECTOR_STATE_HOVER:
			return SELECTOR_HOVER_SCALE
		_:
			return 1.0

func _selector_color_for_state(state: int) -> Color:
	match state:
		SELECTOR_STATE_TARGET_VALID:
			return Color(1.0, 1.0, 1.0, SELECTOR_TARGET_VALID_ALPHA)
		SELECTOR_STATE_TARGET_INVALID:
			return Color(TARGET_INVALID_GREY.r, TARGET_INVALID_GREY.g, TARGET_INVALID_GREY.b, SELECTOR_TARGET_INVALID_ALPHA)
		SELECTOR_STATE_SELECTED, SELECTOR_STATE_ACTIVATED:
			return _selected_color
		_:
			return _sel_color

func _apply_selector_shader_state(state: int) -> void:
	if _selector_mat == null:
		return
	var speed := SELECTOR_HOVER_PULSE_SPEED
	var strength := SELECTOR_HOVER_PULSE_STRENGTH
	var boost := SELECTOR_HOVER_GLOW_BOOST
	match state:
		SELECTOR_STATE_TARGET_VALID:
			speed = SELECTOR_TARGET_VALID_PULSE_SPEED
			strength = SELECTOR_TARGET_VALID_PULSE_STRENGTH
			boost = SELECTOR_TARGET_VALID_GLOW_BOOST
		SELECTOR_STATE_TARGET_INVALID:
			speed = SELECTOR_TARGET_INVALID_PULSE_SPEED
			strength = SELECTOR_TARGET_INVALID_PULSE_STRENGTH
			boost = SELECTOR_TARGET_INVALID_GLOW_BOOST
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

func _apply_visual_highlight() -> void:
	if visual == null or not visual.has_method("set_selected_visual"):
		return
	visual.call("set_selected_visual", _selected or _activated, _selected_color)

func _swarm_cooldown_remaining_ms() -> int:
	if _swarm_cooldown_until_msec <= 0:
		return 0
	return maxi(0, _swarm_cooldown_until_msec - Time.get_ticks_msec())

func _swarm_cooldown_active() -> bool:
	return _swarm_cooldown_remaining_ms() > 0

func _update_fallback_process() -> void:
	var needs_fallback := _selector_sprite == null or _selector_sprite.texture == null
	var selector_needs_process := needs_fallback and (_hovered or _target_hint_active)
	set_process(selector_needs_process or _swarm_cooldown_active())

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
