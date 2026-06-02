extends Node2D

const P1_TEXT_COLOR := Color(0.0, 0.0, 0.0)
const P2_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const CosmeticThemeDB := preload("res://scripts/cosmetics/cosmetic_theme_db.gd")
const VisualShadow := preload("res://scripts/renderers/visual_shadow.gd")
const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveGeometry := preload("res://scripts/sim/hive_geometry.gd")
const TEAM_GLOW_SHADER := preload("res://shaders/team_glow_recolor.gdshader")
const NPC_GRAYSCALE_SHADER := preload("res://shaders/hive_npc_grayscale.gdshader")
const CORE_ENERGY_SHADER := preload("res://shaders/hive_core_energy.gdshader")
const POWER_LABEL_FONT := preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const LIGHT_PROJECTION_LARGE_PATH := "res://assets/sprites/sf_skin_v1/light_projection.png"
const LIGHT_PROJECTION_MEDIUM_PATH := "res://assets/sprites/sf_skin_v1/light_projection_medium.png"
@export var debug_show_kind_label := false
@export var debug_tint_log := false
@export var show_hive_ids: bool = OS.is_debug_build()
@export var nine_margin_top: int = 48
@export var nine_margin_bottom: int = 48
@export var base_width_px: float = 0.0
@export var height_small_px: float = 0.0
@export var height_med_px: float = 0.0
@export var height_large_px: float = 0.0
@export var height_max_px: float = 0.0
@export var debug_tier_changes := false
@export var shadow_offset: Vector2 = Vector2(10.0, -6.0)
@export_range(0.0, 1.0, 0.01) var shadow_alpha: float = 0.30
@export var shadow_scale_x: float = 1.14
@export var shadow_scale_y: float = 0.46
@export var shadow_z_offset: int = -4
@export var core_scroll_speed: float = 0.18
@export_range(0.0, 1.0, 0.01) var core_pulse_strength: float = 0.16
@export_range(0.0, 2.0, 0.01) var core_glow_strength: float = 0.68
@export_range(0.0, 1.0, 0.01) var core_tint_strength: float = 0.88
@export_range(0.0, 1.5, 0.01) var activity_pulse_strength: float = 0.28
@export_range(0.0, 1.5, 0.01) var power_change_flash_strength: float = 0.42
@export var core_offset_ratio: Vector2 = Vector2(0.0, -0.08)
@export var core_size_ratio: Vector2 = Vector2(0.33, 0.27)
@export_range(0.0, 1.0, 0.01) var base_shadow_strength: float = 0.34
@export var base_shadow_scale: Vector2 = Vector2(1.18, 0.50)
@export_range(0.0, 1.5, 0.01) var ground_glow_strength: float = 1.0
@export_range(0.0, 1.5, 0.01) var owner_accent_strength: float = 0.82
@export_range(0.0, 1.5, 0.01) var selected_highlight_strength: float = 1.0
@export_range(0.0, 1.5, 0.01) var lane_port_pulse_strength: float = 0.75
@export_range(0.0, 1.5, 0.01) var under_attack_flicker_strength: float = 0.62
@export_range(0.0, 2.0, 0.01) var max_power_glow_strength: float = 1.2
@export_range(0.0, 1.0, 0.01) var projection_flicker_strength: float = 0.07
@export_range(0.0, 0.35, 0.01) var hive_sprite_pulse_strength: float = 0.18
@export_range(0.0, 8.0, 0.01) var hive_sprite_pulse_speed: float = 2.65

const TIER_2_MIN_POWER := 10
const TIER_3_MIN_POWER := 25
const TIER_4_MIN_POWER := 50
const SMALL_MAX_POWER := 9
const MED_MAX_POWER := 24
const LARGE_MAX_POWER := 50
const HEIGHT_MED_SCALE := HiveGeometry.HIVE_HEIGHT_SCALE_MED
const HEIGHT_LARGE_SCALE := HiveGeometry.HIVE_HEIGHT_SCALE_LARGE
const HEIGHT_MAX_SCALE := HiveGeometry.HIVE_HEIGHT_SCALE_MAX
const FLOOR_REFLECTION_ENABLED: bool = false
const HIVE_VISUAL_SCALE: float = HiveGeometry.HIVE_VISUAL_SCALE
const HIVE_HEIGHT_SCALE: float = HiveGeometry.HIVE_HEIGHT_SCALE
const HIVE_COLOR_SAT_BOOST: float = 1.22
const HIVE_COLOR_VAL_BOOST: float = 1.12
const HIVE_RING_SCALE: float = 0.85
const HIVE_LABEL_SCALE_COMP: bool = true
const LANE_OCCLUDER_COLOR := Color(0.10, 0.09, 0.08, 0.96)
const LANE_OCCLUDER_WIDTH_RATIO: float = 0.68
const LANE_OCCLUDER_HEIGHT_RATIO: float = 0.52
const LANE_OCCLUDER_Y_RATIO: float = 0.12
const LANE_OCCLUDER_POINTS: int = 24
const SHADOW_CONTACT_OFFSET_MULT: float = 0.45
const SHADOW_CONTACT_ALPHA_MULT: float = 0.62
const SHADOW_CONTACT_SCALE_X_MULT: float = 0.84
const SHADOW_CONTACT_SCALE_Y_MULT: float = 0.70
const FLOOR_REFLECTION_ALPHA: float = 0.42
const FLOOR_REFLECTION_CONTACT_ALPHA: float = 0.26
const FLOOR_REFLECTION_Y_RATIO: float = 0.42
const FLOOR_REFLECTION_CONTACT_Y_RATIO: float = 0.30
const FLOOR_REFLECTION_SCALE := Vector2(0.96, 0.42)
const FLOOR_REFLECTION_CONTACT_SCALE := Vector2(0.78, 0.22)
const FLOOR_REFLECTION_TINT := Color(0.72, 0.62, 0.98, 1.0)
const POWER_LABEL_OFFSET := Vector2(0.0, -42.0)
const POWER_LABEL_TOP_GAP_PX: float = 8.0
const POWER_LABEL_SCALE := 0.50
const POWER_LABEL_FONT_SIZE := 56
const POWER_LABEL_LOCAL_NUDGE := Vector2(0.0, -10.0)
const FLAT_TOP_POWER_LABEL_LOCAL_NUDGE := Vector2(0.0, -1.0)
const POWER_BADGE_PAD := Vector2(6.0, 2.0)
const POWER_LABEL_FILL_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const POWER_LABEL_STROKE_COLOR := Color(0.0, 0.0, 0.0, 0.96)
const POWER_LABEL_INVISIBLE_FILL := Color(1.0, 1.0, 1.0, 0.01)
const POWER_LABEL_ACCENT_ALPHA: float = 0.0
const POWER_BADGE_BG := Color(0.0, 0.0, 0.0, 0.0)
const POWER_BADGE_BORDER_ALPHA: float = 0.0
const POWER_BADGE_CORNER_RADIUS: int = 7
const POWER_PROJECTION_RING_Y: float = 20.0
const POWER_PROJECTION_BEAM_ALPHA: float = 0.18
const POWER_PROJECTION_PULSE_ALPHA: float = 0.07
const POWER_HOLOGRAM_PAD := Vector2(15.0, 12.0)
const POWER_HOLOGRAM_FRAY_PX: float = 13.0
const POWER_HOLOGRAM_MIN_SIZE := Vector2(56.0, 52.0)
const POWER_HOLOGRAM_SLOT_GROW := Vector2(8.0, 4.0)
const POWER_HOLOGRAM_BASE_RISE: float = 7.0
const POWER_HOLOGRAM_SLOT_RISE: float = 1.0
const POWER_PROJECTION_LAYOUT_NUDGE := Vector2(0.0, 40.0)
const POWER_PROJECTION_SOURCE_NUDGE_Y: float = 40.0
const FLAT_TOP_LABEL_Y_RATIO: float = -0.345
const FLAT_TOP_PIP_Y: float = 30.0
const FLAT_TOP_SMALL_PIP_Y: float = 9.0
const FLAT_TOP_MED_PIP_Y: float = 12.0
const FLAT_TOP_PIP_SPACING: float = 14.25
const POWER_PROJECTION_SMALL_SIZE := Vector2(58.0, 72.0)
const POWER_PROJECTION_MEDIUM_SIZE := Vector2(74.0, 84.0)
const POWER_PROJECTION_LARGE_SIZE := Vector2(92.0, 92.0)
const LANE_BUDGET_DEFAULT_SLOTS: int = 3
const LANE_BUDGET_PIP_RADIUS: float = 6.0
const LANE_BUDGET_PIP_INNER_RADIUS: float = 4.05
const LANE_BUDGET_PIP_SPACING: float = 25.5
const LANE_BUDGET_LABEL_SIDE_GAP: float = 18.0
const LANE_BUDGET_LABEL_TOP_GAP: float = 22.5
const LANE_BUDGET_THREE_TOP_LIFT: float = 19.5
const LANE_BUDGET_SINGLE_POS := Vector2(0.0, -46.5)
const LANE_BUDGET_LOBE_POS := Vector2(22.5, -42.0)
const LANE_BUDGET_CENTER_POS := Vector2(0.0, -54.0)
const LANE_BUDGET_PIP_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const GROUND_GLOW_POINTS: int = 32
const GROUND_GLOW_Y_RATIO: float = 0.27
const GROUND_GLOW_W_RATIO: float = 0.92
const GROUND_GLOW_H_RATIO: float = 0.24
const FLOOR_CONTACT_Y_RATIO: float = 0.31
const FLOOR_CONTACT_W_RATIO: float = 0.78
const FLOOR_CONTACT_H_RATIO: float = 0.18
const BASE_ACCENT_Y_RATIO: float = 0.13
const BASE_ACCENT_W_RATIO: float = 0.68
const BASE_ACCENT_H_RATIO: float = 0.18
const SELECTED_RING_Y_RATIO: float = 0.09
const SELECTED_RING_W_RATIO: float = 0.84
const SELECTED_RING_H_RATIO: float = 0.34
const LANE_PORT_COUNT: int = 3
const LANE_PORT_Y_RATIO: float = 0.20
const LANE_PORT_SPACING_RATIO: float = 0.18
const LANE_PORT_RADIUS: float = 3.4
const ACTIVITY_IDLE: String = "idle"
const ACTIVITY_FEEDING: String = "feeding"
const ACTIVITY_ATTACKING: String = "attacking"
const ACTIVITY_UNDER_ATTACK: String = "under_attack"
const ACTIVITY_MAX_POWER: String = "max_power"
const NPC_HIVE_COLOR := TeamVisuals.NPC_COLOR
@export var power_label_offset_override := Vector2.INF

var radius_px: float = 18.0
var owner_color: Color = Color(1.0, 1.0, 1.0)
var owner_id: int = 0
var power: int = 0
var font_size: int = 14
var hive_kind: String = "Hive"
var _tex: Texture2D = null
var _sprite_key: String = ""
var _sprite_scale: float = 1.0
var _sprite_offset: Vector2 = Vector2.ZERO
var _shadow_layer: Node2D = null
var _ground_glow_layer: Node2D = null
var _base_sprite_layer: Node2D = null
var _core_energy_layer: Node2D = null
var _core_glow_layer: Node2D = null
var _lane_budget_layer: Node2D = null
var _power_projection: Node2D = null
var _fx_layer: Node2D = null
var _lane_port_layer: Node2D = null
var _sprite: Sprite2D = null
var _ground_shadow: VisualShadow = null
var _contact_shadow: VisualShadow = null
var _core_energy_poly: Polygon2D = null
var _core_glow_poly: Polygon2D = null
var _core_crown_glow: Polygon2D = null
var _core_energy_mat: ShaderMaterial = null
var _core_glow_mat: ShaderMaterial = null
var _ground_glow_outer: Polygon2D = null
var _ground_glow_core: Polygon2D = null
var _floor_contact_ring: Line2D = null
var _floor_reactor_spill: Polygon2D = null
var _owner_accent_ring: Line2D = null
var _selected_highlight_ring: Line2D = null
var _lane_port_nodes: Array[Dictionary] = []
var _lane_occluder: Polygon2D = null
var _shader_mat: ShaderMaterial = null
var _npc_shader_mat: ShaderMaterial = null
var _npc_reflection_mat: ShaderMaterial = null
var _power_label_holder: Node2D = null
var _power_badge: Control = null
var _power_backing: PanelContainer = null
var _power_accent_label: Label = null
var _power_stroke_label: Label = null
var _power_label: Label = null
var _power_projector_panel: Polygon2D = null
var _power_projector_fray_top: Polygon2D = null
var _power_projector_fray_bottom: Polygon2D = null
var _power_projector_fray_left: Polygon2D = null
var _power_projector_fray_right: Polygon2D = null
var _power_projector_ring: Polygon2D = null
var _power_projector_beam: Polygon2D = null
var _power_projection_sprite: Sprite2D = null
var _power_projection_shimmer: Sprite2D = null
var _power_projection_sprite_base_scale: Vector2 = Vector2.ONE
var _projection_shader_mat: ShaderMaterial = null
var _projection_shimmer_shader_mat: ShaderMaterial = null
var _light_projection_large_texture: Texture2D = null
var _light_projection_medium_texture: Texture2D = null
var _hive_id_label: Label = null
var _lane_budget_pips: Array[Dictionary] = []
var _lane_budget_used: int = 0
var _lane_budget_max: int = LANE_BUDGET_DEFAULT_SLOTS
var _activity_state: String = "idle"
var _current_size: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE
var _projection_base_scale: Vector2 = Vector2.ONE
var _visual_tier: int = -1
var _last_radius_px: float = -1.0
var _power_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _tint_logged := false
var _power_label_logged: Dictionary = {}
var _power_label_state := ""
var _power_snap_tween: Tween = null
var _fx_t: float = 0.0
var _has_configured: bool = false
var _core_flash: float = 0.0
var _core_surge: float = 0.0
var _core_flicker: float = 0.0
var _last_power_delta: int = 0
var _selected_visual: bool = false
var _selected_visual_color: Color = Color.WHITE
static var _scale_logged: bool = false

func _ready() -> void:
	_ensure_presentation_layers()
	_ensure_shadows()
	_ensure_lane_occluder()
	_ensure_core_layers()
	_ensure_ground_glow()
	_ensure_phase3_polish()
	_ensure_lane_budget_layer()
	_ensure_sprite()
	_ensure_shader_material()
	_ensure_power_label()
	_base_scale = scale * HIVE_VISUAL_SCALE
	_projection_base_scale = _power_label_holder.scale if _power_label_holder != null else Vector2.ONE
	set_process(true)
	if not _scale_logged:
		_scale_logged = true
		SFLog.info("HIVE_VISUAL_SCALE_SET", {"scale": HIVE_VISUAL_SCALE, "ring_scale": HIVE_RING_SCALE})

func configure(
	owner_id_value: int,
	color: Color,
	radius: float,
	power_value: int,
	font_size_value: int,
	kind_value: String = "Hive",
	lane_budget_used: int = 0,
	lane_budget_max: int = LANE_BUDGET_DEFAULT_SLOTS
) -> void:
	scale = _base_scale
	var previous_power: int = power
	owner_id = owner_id_value
	owner_color = color
	radius_px = radius
	power = power_value
	font_size = font_size_value
	hive_kind = kind_value
	SFLog.log_once(
		"HIVEVIS_CONFIGURE",
		"HiveVisual.configure called: owner=%s power=%s kind=%s radius=%s" % [str(owner_id), str(power), str(hive_kind), str(radius_px)],
		SFLog.Level.INFO
	)
	var desired_tier := _visual_tier_for_power(power)
	var kind_key := _tier_key_for_tier(desired_tier)
	var key := "hive.%s.%s" % [
		kind_key,
		SpriteRegistry.owner_key(owner_id)
	]
	SFLog.log_once(
		"HIVE_SPRITE_KEY_SAMPLE",
		"Hive sprite key sample: kind=%s kind_key=%s owner=%s power=%s key=%s" % [str(hive_kind), str(kind_key), str(owner_id), str(power), key],
		SFLog.Level.INFO
	)
	var registry := SpriteRegistry.get_instance()
	var resolved_sprite: Dictionary = CosmeticThemeDB.resolve_hive_sprite(owner_id, hive_kind, power, registry)
	key = str(resolved_sprite.get("key", key))
	var next_tex: Texture2D = resolved_sprite.get("texture", null) as Texture2D
	var next_scale := float(resolved_sprite.get("scale", registry.get_scale(key) if registry != null else 1.0))
	var next_offset := registry.get_offset(key) if registry != null else Vector2.ZERO
	var tier_changed := desired_tier != _visual_tier
	if tier_changed:
		if debug_tier_changes:
			var hive_id := -1
			var parent := get_parent()
			if parent != null and parent.has_method("get"):
				var id_v: Variant = parent.get("hive_id")
				if id_v != null:
					hive_id = int(id_v)
			SFLog.info("HIVE_TIER_CHANGE", {
				"id": hive_id,
				"old": _visual_tier,
				"new": desired_tier,
				"power": power
			})
		_visual_tier = desired_tier
	var needs_sprite_refresh := (
		tier_changed
		or key != _sprite_key
		or not is_equal_approx(radius_px, _last_radius_px)
		or next_tex != _tex
	)
	if needs_sprite_refresh:
		_tex = next_tex
		_sprite_key = key
		_sprite_scale = next_scale
		_sprite_offset = next_offset
		_last_radius_px = radius_px
		_ensure_shader_material()
		if _tex == null:
			SFLog.log_once(
				"HIVE_SPRITE_MISSING_" + key,
				"Hive sprite missing key=" + key + " kind=" + hive_kind + " power=" + str(power) + " owner_id=" + str(owner_id),
				SFLog.Level.WARN
			)
		elif _tex != null:
			SFLog.log_once(
				"HIVE_TEX_INFO",
				_hive_tex_debug(_tex, _sprite_key, _sprite_scale, _sprite_offset),
				SFLog.Level.INFO
			)
		_apply_sprite()
	var should_respond: bool = _has_configured and previous_power != power
	_apply_tint(owner_id, power)
	_update_power_label(owner_id, power, should_respond)
	if should_respond:
		_trigger_core_power_response(power - previous_power)
	set_lane_budget(lane_budget_used, lane_budget_max)
	set_activity_state(_activity_state)
	_has_configured = true
	queue_redraw()

func set_power(value: int) -> void:
	if power == value:
		return
	var previous_power: int = power
	power = value
	_apply_tint(owner_id, power)
	_update_power_label(owner_id, power, previous_power != power)
	_trigger_core_power_response(power - previous_power)
	queue_redraw()

func set_lane_budget(used: int, max_budget: int) -> void:
	var next_used: int = maxi(0, int(used))
	var next_max: int = maxi(0, int(max_budget))
	if next_used == _lane_budget_used and next_max == _lane_budget_max:
		return
	_lane_budget_used = mini(next_used, maxi(next_max, next_used))
	_lane_budget_max = next_max
	_update_lane_budget_indicators()
	_ensure_lane_ports()
	_update_phase3_layout()
	_update_phase3_polish()

func set_owner_color(color: Color) -> void:
	owner_color = color
	_update_lane_budget_indicators()
	_update_projection_tint()
	_update_ground_glow()
	_update_core_materials()
	_update_phase3_polish()

func set_activity_state(state: String) -> void:
	# Presentation-only input. TODO: feed this from render_model when authoritative
	# attacking/feeding/under-attack state is exported; never infer it here.
	var next_state: String = _sanitize_activity_state(state)
	if next_state == _activity_state:
		return
	_activity_state = next_state
	_update_core_materials()
	_update_phase3_polish()

func set_selected_visual(on: bool, color: Color = Color.WHITE) -> void:
	_selected_visual = on
	_selected_visual_color = color
	_update_phase3_polish()

func preview_state_idle() -> void:
	if not _preview_helpers_allowed():
		return
	set_selected_visual(false)
	set_activity_state(ACTIVITY_IDLE)

func preview_state_attacking() -> void:
	if not _preview_helpers_allowed():
		return
	set_activity_state(ACTIVITY_ATTACKING)

func preview_state_feeding() -> void:
	if not _preview_helpers_allowed():
		return
	set_activity_state(ACTIVITY_FEEDING)

func preview_state_under_attack() -> void:
	if not _preview_helpers_allowed():
		return
	set_activity_state(ACTIVITY_UNDER_ATTACK)

func preview_state_selected() -> void:
	if not _preview_helpers_allowed():
		return
	set_selected_visual(true, Color.WHITE)

func _preview_helpers_allowed() -> bool:
	return OS.is_debug_build() or Engine.is_editor_hint()

func _draw() -> void:
	SFLog.log_once("HIVEVIS_DRAW", "HiveVisual._draw ran", SFLog.Level.INFO)
	if _tex == null:
		draw_circle(Vector2.ZERO, radius_px, _power_color)
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	if _power_label != null and is_instance_valid(_power_label):
		return
	var text := str(power)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := -size * 0.5 + Vector2(0.0, size.y * 0.35)
	var text_color := Color(1.0, 1.0, 1.0, 1.0)
	var shadow_color := Color(0.0, 0.0, 0.0, 0.8)
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_color)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if debug_show_kind_label:
		var kind_pos := pos + Vector2(0.0, font_size * 1.2)
		draw_string(font, kind_pos, hive_kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

func _process(delta: float) -> void:
	_fx_t += delta
	_core_flash = maxf(0.0, _core_flash - (delta * 2.8))
	_core_surge = move_toward(_core_surge, 0.0, delta * 3.2)
	_core_flicker = maxf(0.0, _core_flicker - (delta * 4.4))
	var state_flicker: float = under_attack_flicker_strength if _activity_state == ACTIVITY_UNDER_ATTACK else 0.0
	var subtle_noise: float = 0.5 + (0.5 * sin((_fx_t * 13.7) + (float(owner_id) * 0.71)))
	if _power_label_holder != null and is_instance_valid(_power_label_holder):
		var base_offset: Vector2 = _power_label_offset()
		var bob_y: float = sin(_fx_t * 2.2) * 0.8
		var label_pos: Vector2 = base_offset + Vector2(0.0, bob_y)
		_power_label_holder.position = label_pos
		if _lane_budget_layer != null and is_instance_valid(_lane_budget_layer):
			_lane_budget_layer.position = label_pos
		_power_label_holder.modulate.a = 1.0
	if _power_projector_beam != null and is_instance_valid(_power_projector_beam):
		var beam_color: Color = _projection_color()
		beam_color.a = POWER_PROJECTION_BEAM_ALPHA + 0.10 + (projection_flicker_strength * 0.55 * (0.5 + 0.5 * sin(_fx_t * 5.1)))
		_power_projector_beam.color = beam_color
	if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
		var projection_alpha: float = 0.86 + (projection_flicker_strength * 0.45 * (0.5 + 0.5 * sin(_fx_t * 4.7)))
		_power_projection_sprite.modulate.a = clampf(projection_alpha, 0.78, 0.96)
		_set_projection_shader_alpha(_projection_shader_mat, _power_projection_sprite.modulate.a)
	if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
		var shimmer_alpha: float = 0.10 + (0.11 * (0.5 + 0.5 * sin((_fx_t * 6.8) + 1.3)))
		_power_projection_shimmer.modulate.a = shimmer_alpha
		_set_projection_shader_alpha(_projection_shimmer_shader_mat, shimmer_alpha)
		_power_projection_shimmer.position.y = (_power_projection_sprite.position.y if _power_projection_sprite != null else 0.0) - (sin(_fx_t * 3.2) * 1.6)
	_update_core_materials()
	_update_phase3_motion()

func _ensure_power_label() -> void:
	if _power_label != null and is_instance_valid(_power_label):
		_ensure_hive_id_label()
		_ensure_power_projection_fx()
		return
	_ensure_presentation_layers()
	var holder: Node = get_node_or_null("PowerProjection")
	if holder == null:
		holder = get_node_or_null("PowerLabelHolder")
	if holder is Node2D:
		_power_label_holder = holder as Node2D
		_power_label_holder.name = "PowerProjection"
		_power_label_holder.z_index = 20
		_apply_label_scale_comp()
		var badge := _power_label_holder.get_node_or_null("PowerBadge")
		if badge is Control:
			_power_badge = badge as Control
			var backing := _power_badge.get_node_or_null("Backing")
			if backing is PanelContainer:
				_power_backing = backing as PanelContainer
				_style_power_backing()
				var existing := _power_backing.get_node_or_null("PowerLabel")
				if existing is Label:
					_power_label = existing as Label
					_ensure_power_label_aux_layers()
					_apply_power_label_settings()
					var existing_id := _power_label_holder.get_node_or_null("HiveIdLabel")
					if existing_id is Label:
						_hive_id_label = existing_id as Label
					_ensure_power_projection_fx()
					return
	if _power_label_holder == null:
		var new_holder := Node2D.new()
		new_holder.name = "PowerProjection"
		new_holder.z_index = 20
		add_child(new_holder)
		_power_label_holder = new_holder
		_apply_label_scale_comp()
	if _power_badge == null:
		var new_badge := Control.new()
		new_badge.name = "PowerBadge"
		new_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		new_badge.position = Vector2.ZERO
		_power_label_holder.add_child(new_badge)
		_power_badge = new_badge
	if _power_backing == null:
		var new_backing := PanelContainer.new()
		new_backing.name = "Backing"
		new_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		new_backing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		new_backing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_power_badge.add_child(new_backing)
		_power_backing = new_backing
		_style_power_backing()
	_ensure_power_label_aux_layers()
	var label := Label.new()
	label.name = "PowerLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	_power_backing.add_child(label)
	_power_label = label
	_apply_power_label_settings()
	_ensure_hive_id_label()
	_ensure_power_projection_fx()

func _ensure_power_label_aux_layers() -> void:
	if _power_backing == null or not is_instance_valid(_power_backing):
		return
	if _power_accent_label == null or not is_instance_valid(_power_accent_label):
		var existing_accent := _power_backing.get_node_or_null("PowerLabelAccent")
		if existing_accent is Label:
			_power_accent_label = existing_accent as Label
		else:
			_power_accent_label = _create_power_label_layer("PowerLabelAccent", 0)
	if _power_stroke_label == null or not is_instance_valid(_power_stroke_label):
		var existing_stroke := _power_backing.get_node_or_null("PowerLabelStroke")
		if existing_stroke is Label:
			_power_stroke_label = existing_stroke as Label
		else:
			_power_stroke_label = _create_power_label_layer("PowerLabelStroke", 1)

func _create_power_label_layer(layer_name: String, z: int) -> Label:
	var label := Label.new()
	label.name = layer_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = z
	_power_backing.add_child(label)
	return label

func _style_power_backing() -> void:
	if _power_backing == null or not is_instance_valid(_power_backing):
		return
	var accent: Color = _owner_accent_color()
	accent.a = POWER_BADGE_BORDER_ALPHA
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = POWER_BADGE_BG
	style.border_color = accent
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = POWER_BADGE_CORNER_RADIUS
	style.corner_radius_top_right = POWER_BADGE_CORNER_RADIUS
	style.corner_radius_bottom_left = POWER_BADGE_CORNER_RADIUS
	style.corner_radius_bottom_right = POWER_BADGE_CORNER_RADIUS
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 0
	style.content_margin_left = POWER_BADGE_PAD.x
	style.content_margin_right = POWER_BADGE_PAD.x
	style.content_margin_top = POWER_BADGE_PAD.y
	style.content_margin_bottom = POWER_BADGE_PAD.y
	_power_backing.add_theme_stylebox_override("panel", style)

func _apply_power_label_settings() -> void:
	if _power_label == null or not is_instance_valid(_power_label):
		return
	_ensure_power_label_aux_layers()
	_apply_power_layer_settings(_power_accent_label, POWER_LABEL_INVISIBLE_FILL, Color(1.0, 1.0, 1.0, POWER_LABEL_ACCENT_ALPHA), 5, 0)
	_apply_power_layer_settings(_power_stroke_label, POWER_LABEL_INVISIBLE_FILL, POWER_LABEL_STROKE_COLOR, 3, 0)
	_apply_power_layer_settings(_power_label, POWER_LABEL_FILL_COLOR, Color(0.0, 0.0, 0.0, 0.0), 0, 0)

func _apply_power_layer_settings(label: Label, fill_color: Color, outline_color: Color, outline_size: int, shadow_size: int) -> void:
	if label == null or not is_instance_valid(label):
		return
	var settings: LabelSettings = LabelSettings.new()
	settings.font = POWER_LABEL_FONT
	settings.font_size = POWER_LABEL_FONT_SIZE
	settings.font_color = fill_color
	settings.outline_size = outline_size
	settings.outline_color = outline_color
	settings.shadow_size = shadow_size
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
	settings.shadow_offset = Vector2.ZERO
	label.label_settings = settings

func _apply_label_scale_comp() -> void:
	if not HIVE_LABEL_SCALE_COMP:
		return
	if _power_label_holder == null:
		return
	var comp := clampf(1.0 / HIVE_VISUAL_SCALE, 1.1, 1.35)
	_power_label_holder.scale = Vector2.ONE * comp
	_projection_base_scale = _power_label_holder.scale

func _ensure_hive_id_label() -> void:
	if _power_label_holder == null:
		return
	if _hive_id_label != null and is_instance_valid(_hive_id_label):
		return
	var existing := _power_label_holder.get_node_or_null("HiveIdLabel")
	if existing is Label:
		_hive_id_label = existing as Label
		return
	var id_label := Label.new()
	id_label.name = "HiveIdLabel"
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	id_label.size = Vector2(56.0, 18.0)
	id_label.position = Vector2(-28.0, 16.0)
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.outline_size = 1
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	settings.shadow_size = 2
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	settings.shadow_offset = Vector2(1.0, 1.0)
	id_label.label_settings = settings
	_power_label_holder.add_child(id_label)
	_hive_id_label = id_label

func _update_power_label(owner_id_value: int, power_value: int, snap: bool = false) -> void:
	_ensure_power_label()
	if _power_label == null or not is_instance_valid(_power_label) or _power_label_holder == null or _power_badge == null:
		return
	var hive_id := -1
	var parent := get_parent()
	if parent != null and parent.has_method("get"):
		var id_v: Variant = parent.get("hive_id")
		if id_v != null:
			hive_id = int(id_v)
	_ensure_hive_id_label()
	if _hive_id_label != null and is_instance_valid(_hive_id_label):
		_hive_id_label.visible = show_hive_ids
		_hive_id_label.text = ("h" + str(hive_id)) if hive_id > 0 else ""
	var next_state := "%s:%s" % [str(owner_id_value), str(power_value)]
	if next_state == _power_label_state:
		return
	_power_label_state = next_state
	var team_color: Color = _team_color_for_player(owner_id_value)
	if owner_id_value > 0:
		team_color = _boost_team_color(team_color)
	team_color.a = 1.0
	var accent_color: Color = team_color.lerp(Color.WHITE, 0.10)
	accent_color.a = POWER_LABEL_ACCENT_ALPHA
	_power_label.text = str(power_value)
	_ensure_power_label_aux_layers()
	_style_power_backing()
	if _power_accent_label != null and is_instance_valid(_power_accent_label):
		_power_accent_label.text = _power_label.text
	if _power_stroke_label != null and is_instance_valid(_power_stroke_label):
		_power_stroke_label.text = _power_label.text
	_apply_power_layer_settings(_power_accent_label, POWER_LABEL_INVISIBLE_FILL, accent_color, 5, 0)
	_apply_power_layer_settings(_power_stroke_label, POWER_LABEL_INVISIBLE_FILL, POWER_LABEL_STROKE_COLOR, 3, 0)
	_apply_power_layer_settings(_power_label, POWER_LABEL_FILL_COLOR, Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	_power_label.modulate = Color.WHITE
	if _power_accent_label != null and is_instance_valid(_power_accent_label):
		_power_accent_label.modulate = Color.WHITE
	if _power_stroke_label != null and is_instance_valid(_power_stroke_label):
		_power_stroke_label.modulate = Color.WHITE
	_power_label.custom_minimum_size = Vector2.ZERO
	var label_size := _power_label.get_minimum_size()
	_layout_power_label_layer(_power_accent_label, label_size)
	_layout_power_label_layer(_power_stroke_label, label_size)
	_layout_power_label_layer(_power_label, label_size)
	_power_badge.scale = Vector2.ONE * POWER_LABEL_SCALE
	if _power_backing != null and is_instance_valid(_power_backing):
		_power_backing.custom_minimum_size = label_size + (POWER_BADGE_PAD * 2.0)
		_power_backing.size = _power_backing.custom_minimum_size
		_power_badge.size = _power_backing.size
		_power_badge.position = -(_power_badge.size * POWER_LABEL_SCALE * 0.5) + _power_label_local_nudge()
	var off := _power_label_offset()
	_power_label_holder.position = off
	_update_power_projection_layout()
	_update_lane_budget_indicators()
	_update_projection_tint()
	if snap:
		_play_power_snap()
	if not _power_label_logged.has(hive_id):
		_power_label_logged[hive_id] = true
		SFLog.info("HIVE_POWER_LABEL", {
			"hive_id": hive_id,
			"owner_id": owner_id_value,
			"power": power_value,
			"label_text": _power_label.text,
			"offset": off,
			"label_global": _power_label.global_position
		})

func _layout_power_label_layer(label: Label, label_size: Vector2) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.custom_minimum_size = label_size
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.position = Vector2.ZERO

func _power_label_local_nudge() -> Vector2:
	if _uses_flat_top_label_layout():
		return FLAT_TOP_POWER_LABEL_LOCAL_NUDGE
	return POWER_LABEL_LOCAL_NUDGE

func _power_label_offset() -> Vector2:
	if power_label_offset_override != Vector2.INF:
		return power_label_offset_override
	if _current_size.y <= 0.0:
		return POWER_LABEL_OFFSET
	if _uses_flat_top_label_layout():
		return _sprite_offset + Vector2(0.0, _current_size.y * FLAT_TOP_LABEL_Y_RATIO)
	var slot_count: int = _lane_budget_display_slot_count()
	var rise: float = POWER_HOLOGRAM_BASE_RISE + (float(slot_count - 1) * POWER_HOLOGRAM_SLOT_RISE)
	return _sprite_offset + Vector2(0.0, -(_current_size.y * 0.5) - rise) + POWER_PROJECTION_LAYOUT_NUDGE

func _ensure_power_projection_fx() -> void:
	if _power_label_holder == null or not is_instance_valid(_power_label_holder):
		return
	_remove_power_projection_poly("ProjectionPanel")
	_remove_power_projection_poly("ProjectionFrayTop")
	_remove_power_projection_poly("ProjectionFrayBottom")
	_remove_power_projection_poly("ProjectionFrayLeft")
	_remove_power_projection_poly("ProjectionFrayRight")
	_remove_power_projection_poly("ProjectionBeam")
	_remove_power_projection_poly("ProjectorRing")
	if _power_projection_sprite == null or not is_instance_valid(_power_projection_sprite):
		var projection_sprite := Sprite2D.new()
		projection_sprite.name = "ProjectionSprite"
		projection_sprite.centered = true
		projection_sprite.z_index = -7
		projection_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_power_label_holder.add_child(projection_sprite)
		_power_projection_sprite = projection_sprite
	if _power_projection_shimmer == null or not is_instance_valid(_power_projection_shimmer):
		var shimmer_sprite := Sprite2D.new()
		shimmer_sprite.name = "ProjectionShimmer"
		shimmer_sprite.centered = true
		shimmer_sprite.z_index = -6
		shimmer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_power_label_holder.add_child(shimmer_sprite)
		_power_projection_shimmer = shimmer_sprite
	_ensure_projection_shader_material()
	_update_power_projection_layout()
	_update_projection_tint()

func _remove_power_projection_poly(node_name: String) -> void:
	if _power_label_holder == null or not is_instance_valid(_power_label_holder):
		return
	var node := _power_label_holder.get_node_or_null(node_name)
	if node != null:
		node.queue_free()

func _create_power_projection_poly(poly_name: String, z: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = poly_name
	poly.z_index = z
	_power_label_holder.add_child(poly)
	return poly

func _update_power_projection_layout() -> void:
	if _power_label_holder == null or not is_instance_valid(_power_label_holder):
		return
	if _uses_flat_top_label_layout():
		if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
			_power_projection_sprite.visible = false
		if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
			_power_projection_shimmer.visible = false
		return
	var projection_tier: int = _power_projection_visual_tier()
	var texture: Texture2D = _power_projection_texture(projection_tier)
	var target_size: Vector2 = _power_projection_target_size(projection_tier)
	if texture == null or target_size == Vector2.ZERO:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size == Vector2.ZERO:
		return
	var source_y: float = target_size.y * 0.5
	if _current_size.y > 0.0:
		var hive_top_y: float = _sprite_offset.y - (_current_size.y * 0.5)
		source_y = hive_top_y - _power_label_offset().y + 1.0 + POWER_PROJECTION_SOURCE_NUDGE_Y
	var sprite_scale: Vector2 = target_size / tex_size
	var sprite_position := Vector2(0.0, source_y - (target_size.y * 0.5))
	_power_projection_sprite_base_scale = sprite_scale
	if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
		_power_projection_sprite.visible = true
		_power_projection_sprite.texture = texture
		_power_projection_sprite.scale = sprite_scale
		_power_projection_sprite.position = sprite_position
	if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
		_power_projection_shimmer.visible = true
		_power_projection_shimmer.texture = texture
		_power_projection_shimmer.scale = sprite_scale * Vector2(1.018, 0.992)
		_power_projection_shimmer.position = sprite_position

func _power_hologram_size(label_size: Vector2, slot_count: int) -> Vector2:
	var slot_extra: float = float(maxi(0, slot_count - 1))
	var side_width: float = 0.0
	if slot_count >= 2:
		side_width = (((label_size.x * 0.5) + LANE_BUDGET_LABEL_SIDE_GAP + LANE_BUDGET_PIP_RADIUS) * 2.0)
	var top_extra: float = 0.0
	if slot_count == 1:
		top_extra = LANE_BUDGET_LABEL_TOP_GAP + (LANE_BUDGET_PIP_RADIUS * 2.0)
	elif slot_count >= 3:
		top_extra = LANE_BUDGET_LABEL_TOP_GAP + LANE_BUDGET_THREE_TOP_LIFT + (LANE_BUDGET_PIP_RADIUS * 2.0)
	var width: float = maxf(label_size.x, side_width) + (POWER_HOLOGRAM_PAD.x * 2.0) + (slot_extra * POWER_HOLOGRAM_SLOT_GROW.x)
	var height: float = label_size.y + top_extra + (POWER_HOLOGRAM_PAD.y * 2.0) + (slot_extra * POWER_HOLOGRAM_SLOT_GROW.y)
	return Vector2(maxf(POWER_HOLOGRAM_MIN_SIZE.x, width), maxf(POWER_HOLOGRAM_MIN_SIZE.y, height))

func _power_projection_texture(projection_tier: int) -> Texture2D:
	if _light_projection_medium_texture == null:
		_light_projection_medium_texture = _load_projection_texture(LIGHT_PROJECTION_MEDIUM_PATH)
	return _light_projection_medium_texture

func _load_projection_texture(path: String) -> Texture2D:
	var texture: Texture2D = ResourceLoader.load(path) as Texture2D
	if texture == null:
		SFLog.warn("HIVE_POWER_PROJECTION_LOAD_FAILED", {"path": path})
	return texture

func _power_projection_target_size(projection_tier: int) -> Vector2:
	match projection_tier:
		1:
			return POWER_PROJECTION_SMALL_SIZE
		2, 3:
			return POWER_PROJECTION_MEDIUM_SIZE
		_:
			return POWER_PROJECTION_LARGE_SIZE

func _power_projection_visual_tier() -> int:
	return clampi(_visual_tier_for_power(power), 1, 3)

func _update_projection_tint() -> void:
	_ensure_projection_shader_material()
	var projection: Color = _projection_color()
	if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
		var sprite_color := Color(1.0, 1.0, 1.0, 1.0)
		sprite_color.a = 0.88
		_power_projection_sprite.modulate = sprite_color
	if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
		var shimmer_color := Color(1.0, 0.98, 0.76, 0.16)
		_power_projection_shimmer.modulate = shimmer_color
	if _power_projector_panel != null and is_instance_valid(_power_projector_panel):
		var panel_color: Color = projection
		panel_color.a = 0.86
		_power_projector_panel.color = panel_color
	var fray_color: Color = projection
	fray_color.a = 0.28
	for fray_poly in [_power_projector_fray_top, _power_projector_fray_bottom, _power_projector_fray_left, _power_projector_fray_right]:
		if fray_poly != null and is_instance_valid(fray_poly):
			fray_poly.color = fray_color
	if _power_projector_ring != null and is_instance_valid(_power_projector_ring):
		var ring_color: Color = projection
		ring_color.a = 0.48
		_power_projector_ring.color = ring_color
	if _power_projector_beam != null and is_instance_valid(_power_projector_beam):
		var beam_color: Color = projection
		beam_color.a = POWER_PROJECTION_BEAM_ALPHA + 0.16
		_power_projector_beam.color = beam_color
	if _projection_shader_mat != null:
		_configure_projection_shader(_projection_shader_mat, projection, _power_projection_sprite.modulate.a if _power_projection_sprite != null else 0.88)
	if _projection_shimmer_shader_mat != null:
		_configure_projection_shader(_projection_shimmer_shader_mat, projection, _power_projection_shimmer.modulate.a if _power_projection_shimmer != null else 0.16)

func _ensure_projection_shader_material() -> void:
	if _projection_shader_mat == null:
		_projection_shader_mat = ShaderMaterial.new()
		_projection_shader_mat.shader = TEAM_GLOW_SHADER
	if _projection_shimmer_shader_mat == null:
		_projection_shimmer_shader_mat = ShaderMaterial.new()
		_projection_shimmer_shader_mat.shader = TEAM_GLOW_SHADER
	if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
		_power_projection_sprite.material = _projection_shader_mat
	if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
		_power_projection_shimmer.material = _projection_shimmer_shader_mat

func _configure_projection_shader(mat: ShaderMaterial, color: Color, alpha: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("team_color", color)
	if owner_id <= 0:
		mat.set_shader_parameter("glow_strength", 0.82)
		mat.set_shader_parameter("colorize_strength", 1.0)
		mat.set_shader_parameter("detail_preserve", 1.0)
		mat.set_shader_parameter("additive_glow", 0.04)
		mat.set_shader_parameter("r_min", 0.20)
		mat.set_shader_parameter("g_min", 0.16)
		mat.set_shader_parameter("r_max", 0.55)
		mat.set_shader_parameter("g_max", 0.50)
		mat.set_shader_parameter("b_soft", 0.24)
		mat.set_shader_parameter("b_max", 0.64)
	else:
		mat.set_shader_parameter("glow_strength", 0.96)
		mat.set_shader_parameter("colorize_strength", 0.90)
		mat.set_shader_parameter("detail_preserve", 0.86)
		mat.set_shader_parameter("additive_glow", 0.14)
		mat.set_shader_parameter("r_min", 0.55)
		mat.set_shader_parameter("g_min", 0.45)
		mat.set_shader_parameter("r_max", 0.85)
		mat.set_shader_parameter("g_max", 0.80)
		mat.set_shader_parameter("b_soft", 0.10)
		mat.set_shader_parameter("b_max", 0.30)
	_set_projection_shader_alpha(mat, alpha)

func _set_projection_shader_alpha(mat: ShaderMaterial, alpha: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("global_alpha", clampf(alpha, 0.0, 1.0))

func _projection_color() -> Color:
	var team_color: Color = _team_color_for_player(owner_id)
	if owner_id <= 0:
		return NPC_HIVE_COLOR.lerp(Color.WHITE, 0.10)
	return team_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.24)

func _play_power_snap() -> void:
	if _power_badge == null or not is_instance_valid(_power_badge):
		return
	if _power_snap_tween != null:
		_power_snap_tween.kill()
	_power_badge.scale = Vector2.ONE * (POWER_LABEL_SCALE * 1.14)
	if _power_projector_ring != null and is_instance_valid(_power_projector_ring):
		_power_projector_ring.scale = Vector2(1.18, 1.18)
	_power_snap_tween = create_tween()
	_power_snap_tween.set_trans(Tween.TRANS_SINE)
	_power_snap_tween.set_ease(Tween.EASE_OUT)
	_power_snap_tween.tween_property(_power_badge, "scale", Vector2.ONE * POWER_LABEL_SCALE, 0.16)
	if _power_projection_sprite != null and is_instance_valid(_power_projection_sprite):
		_power_projection_sprite.scale = _power_projection_sprite_base_scale * 1.06
		_power_snap_tween.parallel().tween_property(_power_projection_sprite, "scale", _power_projection_sprite_base_scale, 0.18)
	if _power_projection_shimmer != null and is_instance_valid(_power_projection_shimmer):
		_power_projection_shimmer.scale = _power_projection_sprite_base_scale * Vector2(1.08, 1.02)
		_power_snap_tween.parallel().tween_property(_power_projection_shimmer, "scale", _power_projection_sprite_base_scale * Vector2(1.018, 0.992), 0.20)
	if _power_projector_ring != null and is_instance_valid(_power_projector_ring):
		_power_snap_tween.parallel().tween_property(_power_projector_ring, "scale", Vector2.ONE, 0.18)

func _ensure_presentation_layers() -> void:
	_shadow_layer = _ensure_child_layer("ShadowLayer", -8)
	_ground_glow_layer = _ensure_child_layer("GroundGlowLayer", -6)
	_base_sprite_layer = _ensure_child_layer("BaseSpriteLayer", -1)
	_core_energy_layer = _ensure_child_layer("CoreEnergyLayer", 4)
	_core_glow_layer = _ensure_child_layer("CoreGlowLayer", 5)
	_lane_budget_layer = _ensure_child_layer("LaneBudgetIndicators", 24)
	_fx_layer = _ensure_child_layer("FxLayer", 18)
	_lane_port_layer = _ensure_child_layer("LanePortLayer", 10)
	var projection_node: Node = get_node_or_null("PowerProjection")
	if projection_node == null:
		projection_node = get_node_or_null("PowerLabelHolder")
	if projection_node is Node2D:
		_power_projection = projection_node as Node2D
		_power_projection.name = "PowerProjection"
		_power_projection.z_index = 20

func _ensure_child_layer(layer_name: String, z_value: int) -> Node2D:
	var existing: Node = get_node_or_null(layer_name)
	if existing is Node2D:
		var existing_layer: Node2D = existing as Node2D
		existing_layer.z_index = z_value
		return existing_layer
	var layer: Node2D = Node2D.new()
	layer.name = layer_name
	layer.z_index = z_value
	add_child(layer)
	return layer

func _ensure_phase3_polish() -> void:
	_ensure_presentation_layers()
	if _ground_glow_layer != null and is_instance_valid(_ground_glow_layer):
		if _floor_reactor_spill == null or not is_instance_valid(_floor_reactor_spill):
			var spill: Polygon2D = Polygon2D.new()
			spill.name = "FloorReactorSpill"
			spill.z_index = 2
			_ground_glow_layer.add_child(spill)
			_floor_reactor_spill = spill
		if _floor_contact_ring == null or not is_instance_valid(_floor_contact_ring):
			_floor_contact_ring = _create_ring_line("FloorContactRing", 3, 1.4, _ground_glow_layer)
	if _fx_layer != null and is_instance_valid(_fx_layer):
		if _owner_accent_ring == null or not is_instance_valid(_owner_accent_ring):
			_owner_accent_ring = _create_ring_line("OwnerAccentRing", 0, 1.6, _fx_layer)
		if _selected_highlight_ring == null or not is_instance_valid(_selected_highlight_ring):
			_selected_highlight_ring = _create_ring_line("SelectedHighlightRing", 2, 2.2, _fx_layer)
	if _lane_port_layer != null and is_instance_valid(_lane_port_layer):
		_ensure_lane_ports()
	_update_phase3_layout()
	_update_phase3_polish()

func _create_ring_line(node_name: String, z_value: int, width: float, parent_node: Node) -> Line2D:
	var line: Line2D = Line2D.new()
	line.name = node_name
	line.z_index = z_value
	line.width = width
	line.closed = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent_node.add_child(line)
	return line

func _ensure_lane_ports() -> void:
	if _lane_port_layer == null or not is_instance_valid(_lane_port_layer):
		return
	var port_count: int = _lane_budget_display_slot_count()
	if _lane_port_nodes.size() == port_count:
		return
	for child in _lane_port_layer.get_children():
		child.queue_free()
	_lane_port_nodes.clear()
	for i in range(port_count):
		var outline: Line2D = _create_ring_line("LanePortOutline_%d" % i, 0, 1.2, _lane_port_layer)
		var fill: Polygon2D = Polygon2D.new()
		fill.name = "LanePortFill_%d" % i
		fill.z_index = 1
		fill.polygon = _hex_points(LANE_PORT_RADIUS)
		_lane_port_layer.add_child(fill)
		_lane_port_nodes.append({"outline": outline, "fill": fill})

func _update_phase3_layout() -> void:
	if _current_size == Vector2.ZERO:
		return
	var floor_pos: Vector2 = _sprite_offset + Vector2(0.0, _current_size.y * FLOOR_CONTACT_Y_RATIO)
	var floor_rx: float = maxf(10.0, _current_size.x * FLOOR_CONTACT_W_RATIO * 0.5)
	var floor_ry: float = maxf(4.0, _current_size.y * FLOOR_CONTACT_H_RATIO * 0.5)
	if _floor_contact_ring != null and is_instance_valid(_floor_contact_ring):
		_floor_contact_ring.position = floor_pos
		_floor_contact_ring.points = _ellipse_points(floor_rx, floor_ry, 40)
	if _floor_reactor_spill != null and is_instance_valid(_floor_reactor_spill):
		_floor_reactor_spill.position = floor_pos + Vector2(0.0, -1.0)
		_floor_reactor_spill.polygon = _ellipse_points(floor_rx * 0.72, floor_ry * 0.72, 32)
	var accent_pos: Vector2 = _sprite_offset + Vector2(0.0, _current_size.y * BASE_ACCENT_Y_RATIO)
	var accent_rx: float = maxf(8.0, _current_size.x * BASE_ACCENT_W_RATIO * 0.5)
	var accent_ry: float = maxf(3.0, _current_size.y * BASE_ACCENT_H_RATIO * 0.5)
	if _owner_accent_ring != null and is_instance_valid(_owner_accent_ring):
		_owner_accent_ring.position = accent_pos
		_owner_accent_ring.points = _ellipse_points(accent_rx, accent_ry, 36)
	var selected_pos: Vector2 = _sprite_offset + Vector2(0.0, _current_size.y * SELECTED_RING_Y_RATIO)
	if _selected_highlight_ring != null and is_instance_valid(_selected_highlight_ring):
		_selected_highlight_ring.position = selected_pos
		_selected_highlight_ring.points = _ellipse_points(
			maxf(10.0, _current_size.x * SELECTED_RING_W_RATIO * 0.5),
			maxf(5.0, _current_size.y * SELECTED_RING_H_RATIO * 0.5),
			44
		)
	# Generic ports until lane endpoint angles are exported to render_model.
	var port_y: float = _sprite_offset.y + (_current_size.y * LANE_PORT_Y_RATIO)
	var spacing: float = maxf(8.0, _current_size.x * LANE_PORT_SPACING_RATIO)
	var center_offset: float = (float(_lane_port_nodes.size()) - 1.0) * 0.5
	for i in range(_lane_port_nodes.size()):
		var entry: Dictionary = _lane_port_nodes[i]
		var port_pos: Vector2 = Vector2((float(i) - center_offset) * spacing, port_y)
		var outline: Line2D = entry.get("outline", null) as Line2D
		var fill: Polygon2D = entry.get("fill", null) as Polygon2D
		if outline != null and is_instance_valid(outline):
			outline.position = port_pos
			outline.points = _hex_points(LANE_PORT_RADIUS + 1.6)
		if fill != null and is_instance_valid(fill):
			fill.position = port_pos
			fill.polygon = _hex_points(LANE_PORT_RADIUS)

func _update_phase3_motion() -> void:
	if _current_size == Vector2.ZERO:
		return
	var selected_wave: float = 0.5 + (0.5 * sin(_fx_t * 3.1))
	var port_wave: float = 0.5 + (0.5 * sin(_fx_t * 4.8))
	if _selected_highlight_ring != null and is_instance_valid(_selected_highlight_ring):
		var selected_color: Color = _selected_visual_color.lerp(Color.WHITE, 0.65)
		selected_color.a = (0.30 + (selected_wave * 0.24)) * selected_highlight_strength if _selected_visual else 0.0
		_selected_highlight_ring.default_color = selected_color
	_update_lane_port_colors(port_wave)

func _update_phase3_polish() -> void:
	if _current_size == Vector2.ZERO:
		return
	var accent: Color = _owner_accent_color()
	var neutral_mul: float = 0.55 if owner_id <= 0 else 1.0
	var activity: Dictionary = _activity_profile(_activity_state)
	var max_power_mul: float = max_power_glow_strength if _activity_state == ACTIVITY_MAX_POWER or power >= LARGE_MAX_POWER else 1.0
	if _floor_contact_ring != null and is_instance_valid(_floor_contact_ring):
		var contact_color: Color = accent
		contact_color.a = 0.18 * owner_accent_strength * ground_glow_strength * neutral_mul
		_floor_contact_ring.default_color = contact_color
	if _floor_reactor_spill != null and is_instance_valid(_floor_reactor_spill):
		var spill_color: Color = accent
		spill_color.a = 0.10 * ground_glow_strength * owner_accent_strength * max_power_mul * neutral_mul
		_floor_reactor_spill.color = spill_color
	if _owner_accent_ring != null and is_instance_valid(_owner_accent_ring):
		var ring_color: Color = accent
		ring_color.a = 0.28 * owner_accent_strength * max_power_mul * neutral_mul
		_owner_accent_ring.default_color = ring_color
	if _selected_highlight_ring != null and is_instance_valid(_selected_highlight_ring):
		_selected_highlight_ring.visible = selected_highlight_strength > 0.0
	var crown_boost: float = float(activity.get("crown", 0.0))
	if _core_crown_glow != null and is_instance_valid(_core_crown_glow) and crown_boost <= 0.0:
		var crown_color: Color = accent
		crown_color.a = 0.05 * owner_accent_strength * neutral_mul
		_core_crown_glow.color = crown_color
	_update_lane_port_colors(0.5)

func _update_lane_port_colors(pulse_t: float) -> void:
	var accent: Color = _owner_accent_color()
	var neutral_mul: float = 0.55 if owner_id <= 0 else 1.0
	var active_count: int = clampi(_lane_budget_used, 0, _lane_port_nodes.size())
	var activity_out: bool = _activity_state == ACTIVITY_ATTACKING
	var activity_in: bool = _activity_state == ACTIVITY_FEEDING
	var stress: bool = _activity_state == ACTIVITY_UNDER_ATTACK
	for i in range(_lane_port_nodes.size()):
		var entry: Dictionary = _lane_port_nodes[i]
		var outline: Line2D = entry.get("outline", null) as Line2D
		var fill: Polygon2D = entry.get("fill", null) as Polygon2D
		var is_active: bool = i < active_count
		var pulse: float = pulse_t * lane_port_pulse_strength
		var alpha_base: float = 0.15
		if is_active:
			alpha_base = 0.46 + (pulse * 0.20)
		elif i < _lane_budget_max:
			alpha_base = 0.24 + (pulse * 0.08)
		if activity_out and is_active:
			alpha_base += 0.18 * lane_port_pulse_strength
		if activity_in:
			alpha_base += 0.10 * lane_port_pulse_strength
		if stress:
			alpha_base *= 0.72 + (0.28 * sin(_fx_t * 34.0))
		var outline_color: Color = accent.lerp(Color.WHITE, 0.28)
		outline_color.a = clampf(alpha_base * owner_accent_strength * neutral_mul, 0.0, 0.95)
		var fill_color: Color = accent
		fill_color.a = clampf((alpha_base * 0.58) * owner_accent_strength * neutral_mul, 0.0, 0.80)
		if outline != null and is_instance_valid(outline):
			outline.default_color = outline_color
		if fill != null and is_instance_valid(fill):
			fill.color = fill_color

func _owner_accent_color() -> Color:
	if owner_id <= 0:
		return NPC_HIVE_COLOR.lerp(Color.WHITE, 0.18)
	return _boost_team_color(_team_color_for_player(owner_id)).lerp(Color.WHITE, 0.10)

func _ensure_core_layers() -> void:
	_ensure_presentation_layers()
	if _core_energy_layer == null or not is_instance_valid(_core_energy_layer):
		return
	if _core_energy_mat == null:
		_core_energy_mat = ShaderMaterial.new()
		_core_energy_mat.shader = CORE_ENERGY_SHADER
	if _core_glow_mat == null:
		_core_glow_mat = ShaderMaterial.new()
		_core_glow_mat.shader = CORE_ENERGY_SHADER
	if _core_energy_poly == null or not is_instance_valid(_core_energy_poly):
		var energy_poly: Polygon2D = Polygon2D.new()
		energy_poly.name = "CoreEnergy"
		energy_poly.z_index = 0
		energy_poly.material = _core_energy_mat
		_core_energy_layer.add_child(energy_poly)
		_core_energy_poly = energy_poly
	if _core_glow_poly == null or not is_instance_valid(_core_glow_poly):
		var glow_poly: Polygon2D = Polygon2D.new()
		glow_poly.name = "CoreGlow"
		glow_poly.z_index = 0
		glow_poly.material = _core_glow_mat
		_core_glow_layer.add_child(glow_poly)
		_core_glow_poly = glow_poly
	if _core_crown_glow == null or not is_instance_valid(_core_crown_glow):
		var crown_poly: Polygon2D = Polygon2D.new()
		crown_poly.name = "CrownGlow"
		crown_poly.z_index = 1
		_core_glow_layer.add_child(crown_poly)
		_core_crown_glow = crown_poly
	_update_core_layout()
	_update_core_materials()

func _update_core_layout() -> void:
	if _current_size == Vector2.ZERO:
		if _core_energy_layer != null:
			_core_energy_layer.visible = false
		if _core_glow_layer != null:
			_core_glow_layer.visible = false
		return
	if _core_energy_layer != null:
		_core_energy_layer.visible = true
	if _core_glow_layer != null:
		_core_glow_layer.visible = true
	var core_rx: float = maxf(5.0, _current_size.x * core_size_ratio.x * 0.5)
	var core_ry: float = maxf(4.0, _current_size.y * core_size_ratio.y * 0.5)
	var core_pos: Vector2 = _sprite_offset + Vector2(
		_current_size.x * core_offset_ratio.x,
		_current_size.y * core_offset_ratio.y
	)
	if _core_energy_poly != null and is_instance_valid(_core_energy_poly):
		_core_energy_poly.position = core_pos
		_core_energy_poly.polygon = _ellipse_points(core_rx, core_ry, 28)
		_core_energy_poly.uv = _ellipse_uv_points(28)
	if _core_glow_poly != null and is_instance_valid(_core_glow_poly):
		_core_glow_poly.position = core_pos
		_core_glow_poly.polygon = _ellipse_points(core_rx * 1.42, core_ry * 1.28, 32)
		_core_glow_poly.uv = _ellipse_uv_points(32)
	if _core_crown_glow != null and is_instance_valid(_core_crown_glow):
		_core_crown_glow.position = _sprite_offset + Vector2(0.0, _current_size.y * -0.34)
		_core_crown_glow.polygon = _ellipse_points(core_rx * 1.35, maxf(3.0, core_ry * 0.28), 28)
		_core_crown_glow.uv = _ellipse_uv_points(28)
	_update_core_materials()

func _update_core_materials() -> void:
	if _core_energy_mat == null and _core_glow_mat == null:
		return
	var activity: Dictionary = _activity_profile(_activity_state)
	var activity_amount: float = float(activity.get("pulse", 0.0)) * activity_pulse_strength
	var glow_mul: float = float(activity.get("glow_mul", 1.0))
	var scroll_mul: float = float(activity.get("scroll_mul", 1.0))
	var flicker_extra: float = float(activity.get("flicker", 0.0))
	var crown_alpha: float = float(activity.get("crown", 0.0))
	var tint: Color = _core_color()
	var power_t: float = clampf(float(power) / float(LARGE_MAX_POWER), 0.0, 1.0)
	var neutral_alpha_mul: float = 0.74 if owner_id <= 0 else 1.0
	var stress_flicker: float = maxf(_core_flicker, flicker_extra)
	if _activity_state == ACTIVITY_UNDER_ATTACK:
		stress_flicker = maxf(stress_flicker, under_attack_flicker_strength)
	var max_power_mul: float = max_power_glow_strength if _activity_state == ACTIVITY_MAX_POWER or power >= LARGE_MAX_POWER else 1.0
	if _core_energy_mat != null:
		_core_energy_mat.set_shader_parameter("core_color", tint)
		_core_energy_mat.set_shader_parameter("scroll_speed", core_scroll_speed * scroll_mul)
		_core_energy_mat.set_shader_parameter("pulse_strength", core_pulse_strength)
		_core_energy_mat.set_shader_parameter("glow_strength", core_glow_strength * glow_mul * max_power_mul)
		_core_energy_mat.set_shader_parameter("tint_strength", core_tint_strength)
		_core_energy_mat.set_shader_parameter("activity_pulse", activity_amount + (power_t * 0.08))
		_core_energy_mat.set_shader_parameter("power_flash", _core_flash)
		_core_energy_mat.set_shader_parameter("surge", _core_surge)
		_core_energy_mat.set_shader_parameter("flicker", stress_flicker)
		_core_energy_mat.set_shader_parameter("alpha_scale", 0.88 * neutral_alpha_mul)
	if _core_glow_mat != null:
		_core_glow_mat.set_shader_parameter("core_color", tint.lerp(Color.WHITE, 0.18))
		_core_glow_mat.set_shader_parameter("scroll_speed", core_scroll_speed * 0.42 * scroll_mul)
		_core_glow_mat.set_shader_parameter("pulse_strength", core_pulse_strength * 0.72)
		_core_glow_mat.set_shader_parameter("glow_strength", core_glow_strength * 1.15 * glow_mul * max_power_mul)
		_core_glow_mat.set_shader_parameter("tint_strength", core_tint_strength * 0.72)
		_core_glow_mat.set_shader_parameter("activity_pulse", activity_amount * 0.66)
		_core_glow_mat.set_shader_parameter("power_flash", _core_flash * 0.70)
		_core_glow_mat.set_shader_parameter("surge", _core_surge * 0.60)
		_core_glow_mat.set_shader_parameter("flicker", stress_flicker * 0.45)
		_core_glow_mat.set_shader_parameter("alpha_scale", 0.34 * neutral_alpha_mul)
	if _core_glow_layer != null and is_instance_valid(_core_glow_layer):
		var pop_scale: float = 1.0 + (_core_flash * 0.055)
		_core_glow_layer.scale = Vector2(pop_scale, pop_scale)
	if _core_crown_glow != null and is_instance_valid(_core_crown_glow):
		var crown_color: Color = tint.lerp(Color.WHITE, 0.20)
		crown_color.a = clampf((crown_alpha + (_core_flash * 0.22)) * neutral_alpha_mul, 0.0, 0.48)
		_core_crown_glow.color = crown_color

func _activity_profile(state: String) -> Dictionary:
	match state:
		ACTIVITY_FEEDING:
			return {"pulse": 0.42, "glow_mul": 1.18, "scroll_mul": 0.86, "flicker": 0.0, "crown": 0.10}
		ACTIVITY_ATTACKING:
			return {"pulse": 0.58, "glow_mul": 1.28, "scroll_mul": 1.55, "flicker": 0.0, "crown": 0.16}
		ACTIVITY_UNDER_ATTACK:
			return {"pulse": 0.34, "glow_mul": 1.08, "scroll_mul": 1.16, "flicker": 0.34, "crown": 0.08}
		ACTIVITY_MAX_POWER:
			return {"pulse": 0.32, "glow_mul": 1.42, "scroll_mul": 0.78, "flicker": 0.0, "crown": 0.34}
		_:
			return {"pulse": 0.0, "glow_mul": 1.0, "scroll_mul": 1.0, "flicker": 0.0, "crown": 0.04}

func _sanitize_activity_state(state: String) -> String:
	match state:
		ACTIVITY_FEEDING, ACTIVITY_ATTACKING, ACTIVITY_UNDER_ATTACK, ACTIVITY_MAX_POWER:
			return state
		_:
			return ACTIVITY_IDLE

func _core_color() -> Color:
	var team_color: Color = _team_color_for_player(owner_id)
	if owner_id <= 0:
		team_color = NPC_HIVE_COLOR
	else:
		team_color = _boost_team_color(team_color)
	return team_color.lerp(Color.WHITE, 0.18)

func _trigger_core_power_response(power_delta: int) -> void:
	if power_delta == 0:
		return
	_last_power_delta = power_delta
	_core_flash = maxf(_core_flash, power_change_flash_strength)
	if power_delta > 0:
		_core_surge = maxf(_core_surge, 1.0)
	else:
		_core_surge = minf(_core_surge, -0.58)
		_core_flicker = maxf(_core_flicker, power_change_flash_strength * 0.74)
	_update_core_materials()

func _ensure_ground_glow() -> void:
	_ensure_presentation_layers()
	if _ground_glow_layer == null or not is_instance_valid(_ground_glow_layer):
		return
	if _ground_glow_outer == null or not is_instance_valid(_ground_glow_outer):
		var outer: Polygon2D = Polygon2D.new()
		outer.name = "GroundGlowOuter"
		outer.z_index = 0
		_ground_glow_layer.add_child(outer)
		_ground_glow_outer = outer
	if _ground_glow_core == null or not is_instance_valid(_ground_glow_core):
		var core: Polygon2D = Polygon2D.new()
		core.name = "GroundGlowCore"
		core.z_index = 1
		_ground_glow_layer.add_child(core)
		_ground_glow_core = core
	_update_ground_glow()

func _update_ground_glow() -> void:
	if _ground_glow_layer == null or not is_instance_valid(_ground_glow_layer):
		return
	if _tex == null or _current_size == Vector2.ZERO:
		_ground_glow_layer.visible = false
		return
	_ground_glow_layer.visible = true
	var glow_color: Color = _team_color_for_player(owner_id)
	if owner_id <= 0:
		glow_color = NPC_HIVE_COLOR
	var width: float = maxf(22.0, _current_size.x * GROUND_GLOW_W_RATIO)
	var height: float = maxf(8.0, _current_size.y * GROUND_GLOW_H_RATIO)
	var glow_pos: Vector2 = _sprite_offset + Vector2(0.0, _current_size.y * GROUND_GLOW_Y_RATIO)
	if _ground_glow_outer != null and is_instance_valid(_ground_glow_outer):
		_ground_glow_outer.position = glow_pos
		_ground_glow_outer.polygon = _ellipse_points(width * 0.5, height * 0.5, GROUND_GLOW_POINTS)
		var outer_color: Color = glow_color
		outer_color.a = (0.16 if owner_id > 0 else 0.08) * ground_glow_strength
		_ground_glow_outer.color = outer_color
	if _ground_glow_core != null and is_instance_valid(_ground_glow_core):
		_ground_glow_core.position = glow_pos + Vector2(0.0, -1.0)
		_ground_glow_core.polygon = _ellipse_points(width * 0.31, height * 0.30, GROUND_GLOW_POINTS)
		var core_color: Color = glow_color.lerp(Color.WHITE, 0.25)
		core_color.a = (0.26 if owner_id > 0 else 0.12) * ground_glow_strength
		_ground_glow_core.color = core_color
	_update_phase3_polish()

func _ensure_lane_budget_layer() -> void:
	_ensure_presentation_layers()
	_update_lane_budget_indicators()

func _update_lane_budget_indicators() -> void:
	if _lane_budget_layer == null or not is_instance_valid(_lane_budget_layer):
		return
	var slot_count: int = _lane_budget_display_slot_count()
	if slot_count != _lane_budget_pips.size():
		for child in _lane_budget_layer.get_children():
			_lane_budget_layer.remove_child(child)
			child.queue_free()
		_lane_budget_pips.clear()
		for i in range(slot_count):
			var outline: Line2D = _create_ring_line("BudgetPipOutline_%d" % i, 1, 1.5, _lane_budget_layer)
			var fill: Polygon2D = Polygon2D.new()
			fill.name = "BudgetPipFill_%d" % i
			fill.z_index = 0
			fill.polygon = _hex_points(LANE_BUDGET_PIP_INNER_RADIUS)
			_lane_budget_layer.add_child(fill)
			_lane_budget_pips.append({"outline": outline, "fill": fill})
	var label_size: Vector2 = _lane_budget_reference_label_size()
	_lane_budget_layer.position = _power_label_offset()
	_update_power_projection_layout()
	var indicator_color: Color = LANE_BUDGET_PIP_COLOR
	for i in range(slot_count):
		var entry: Dictionary = _lane_budget_pips[i]
		var outline_line: Line2D = entry.get("outline", null) as Line2D
		var fill_poly: Polygon2D = entry.get("fill", null) as Polygon2D
		var pip_pos: Vector2 = _lane_budget_pip_position(slot_count, i, label_size)
		if outline_line != null and is_instance_valid(outline_line):
			outline_line.position = pip_pos
			outline_line.points = _hex_points(LANE_BUDGET_PIP_RADIUS)
		if fill_poly != null and is_instance_valid(fill_poly):
			fill_poly.position = pip_pos
			fill_poly.polygon = _hex_points(LANE_BUDGET_PIP_INNER_RADIUS)
		var is_used: bool = i < _lane_budget_used
		var is_available: bool = i < _lane_budget_max
		var outline_color: Color = Color(0.0, 0.0, 0.0, 0.30)
		var fill_color: Color = Color(0.0, 0.0, 0.0, 0.0)
		if is_used:
			outline_color = indicator_color
			outline_color.a = 0.96
			fill_color = Color(0.0, 0.0, 0.0, 0.0)
		elif is_available:
			outline_color = indicator_color
			outline_color.a = 0.96
			fill_color = indicator_color
			fill_color.a = 0.88
		else:
			outline_color = Color(0.0, 0.0, 0.0, 0.20)
			fill_color = Color(0.0, 0.0, 0.0, 0.0)
		if outline_line != null and is_instance_valid(outline_line):
			outline_line.default_color = outline_color
			outline_line.visible = true
		if fill_poly != null and is_instance_valid(fill_poly):
			fill_poly.color = fill_color
			fill_poly.visible = is_available and not is_used

func _lane_budget_reference_label_size() -> Vector2:
	if _power_badge != null and is_instance_valid(_power_badge) and _power_badge.size != Vector2.ZERO:
		return _power_badge.size * POWER_LABEL_SCALE
	if _power_label != null and is_instance_valid(_power_label):
		var min_size: Vector2 = _power_label.get_minimum_size()
		if min_size != Vector2.ZERO:
			return (min_size + (POWER_BADGE_PAD * 2.0)) * POWER_LABEL_SCALE
	return Vector2(26.0, 22.0)

func _lane_budget_pip_position(slot_count: int, slot_index: int, label_size: Vector2) -> Vector2:
	if _uses_flat_top_label_layout():
		return _flat_top_lane_budget_pip_position(slot_count, slot_index, label_size)
	match slot_count:
		1:
			return LANE_BUDGET_SINGLE_POS
		2:
			var side: float = -1.0 if slot_index == 0 else 1.0
			return Vector2(side * LANE_BUDGET_LOBE_POS.x, LANE_BUDGET_LOBE_POS.y)
		3:
			match slot_index:
				0:
					return Vector2(-LANE_BUDGET_LOBE_POS.x, LANE_BUDGET_LOBE_POS.y)
				1:
					return Vector2(LANE_BUDGET_LOBE_POS.x, LANE_BUDGET_LOBE_POS.y)
				_:
					return LANE_BUDGET_CENTER_POS
	var top_y: float = -((label_size.y * 0.5) + LANE_BUDGET_LABEL_TOP_GAP)
	var center: float = (float(slot_count) - 1.0) * 0.5
	return Vector2((float(slot_index) - center) * LANE_BUDGET_PIP_SPACING, top_y)

func _flat_top_lane_budget_pip_position(slot_count: int, slot_index: int, label_size: Vector2) -> Vector2:
	var center: float = (float(slot_count) - 1.0) * 0.5
	var tier: int = _resolve_tier(power)
	if tier <= 1:
		if slot_count == 1:
			return Vector2((label_size.x * 0.5) + 10.0, FLAT_TOP_SMALL_PIP_Y)
		var small_spacing: float = maxf(22.0, label_size.x + 10.0)
		return Vector2((float(slot_index) - center) * small_spacing, FLAT_TOP_SMALL_PIP_Y)
	if tier == 2:
		var med_spacing: float = maxf(28.0, label_size.x + 12.0)
		return Vector2((float(slot_index) - center) * med_spacing, FLAT_TOP_MED_PIP_Y)
	return Vector2((float(slot_index) - center) * FLAT_TOP_PIP_SPACING, FLAT_TOP_PIP_Y)

func _lane_budget_display_slot_count() -> int:
	return clampi(_lane_budget_max, 1, LANE_BUDGET_DEFAULT_SLOTS)

func _uses_flat_top_label_layout() -> bool:
	if not _sprite_key.begins_with("hive."):
		return false
	var registry := SpriteRegistry.get_instance()
	if registry == null:
		return false
	return registry.get_tex_path(_sprite_key).get_file().to_lower().contains("flatop")

func _ellipse_points(rx: float, ry: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_count: int = maxi(8, count)
	for i in range(safe_count):
		var angle: float = (TAU * float(i)) / float(safe_count)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _ellipse_uv_points(count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_count: int = maxi(8, count)
	for i in range(safe_count):
		var angle: float = (TAU * float(i)) / float(safe_count)
		points.append(Vector2((cos(angle) * 0.5) + 0.5, (sin(angle) * 0.5) + 0.5))
	return points

func _hex_points(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = (TAU * float(i)) / 6.0 + (PI * 0.5)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _ensure_sprite() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		return
	_ensure_presentation_layers()
	var existing: Node = get_node_or_null("BaseSprite")
	if existing == null:
		existing = get_node_or_null("HiveSprite")
	if existing == null and _base_sprite_layer != null:
		existing = _base_sprite_layer.get_node_or_null("BaseSprite")
	if existing == null and _base_sprite_layer != null:
		existing = _base_sprite_layer.get_node_or_null("HiveSprite")
	if existing is Sprite2D:
		_sprite = existing as Sprite2D
		_sprite.name = "BaseSprite"
		if _base_sprite_layer != null and _sprite.get_parent() != _base_sprite_layer:
			_sprite.reparent(_base_sprite_layer, true)
		return
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "BaseSprite"
	sprite.centered = true
	sprite.z_index = -1
	if _base_sprite_layer != null:
		_base_sprite_layer.add_child(sprite)
	else:
		add_child(sprite)
	_sprite = sprite

func _ensure_shadows() -> void:
	_ensure_presentation_layers()
	if not FLOOR_REFLECTION_ENABLED:
		_hide_hive_reflection_nodes()
		return
	if _ground_shadow == null or not is_instance_valid(_ground_shadow):
		_ground_shadow = _ensure_shadow_sprite("GroundShadow")
	if _contact_shadow == null or not is_instance_valid(_contact_shadow):
		_contact_shadow = _ensure_shadow_sprite("ContactShadow")

func _hide_hive_reflection_nodes() -> void:
	for node_name in ["GroundShadow", "ContactShadow"]:
		var node: Node = null
		if _shadow_layer != null and is_instance_valid(_shadow_layer):
			node = _shadow_layer.get_node_or_null(node_name)
		if node == null:
			node = get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
	if _ground_shadow != null and is_instance_valid(_ground_shadow):
		_ground_shadow.visible = false
	if _contact_shadow != null and is_instance_valid(_contact_shadow):
		_contact_shadow.visible = false

func _ensure_shadow_sprite(node_name: String) -> VisualShadow:
	var existing: Node = null
	if _shadow_layer != null:
		existing = _shadow_layer.get_node_or_null(node_name)
	if existing == null:
		existing = get_node_or_null(node_name)
	if existing is VisualShadow:
		var shadow_existing: VisualShadow = existing as VisualShadow
		if _shadow_layer != null and shadow_existing.get_parent() != _shadow_layer:
			shadow_existing.reparent(_shadow_layer, true)
		return shadow_existing
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var shadow: VisualShadow = VisualShadow.new()
	shadow.name = node_name
	shadow.centered = true
	shadow.z_index = shadow_z_offset
	shadow.visible = false
	if _shadow_layer != null:
		_shadow_layer.add_child(shadow)
	else:
		add_child(shadow)
	return shadow

func _update_hive_shadows() -> void:
	if not FLOOR_REFLECTION_ENABLED:
		_hide_hive_reflection_nodes()
		return
	_ensure_shadows()
	if (_ground_shadow == null or not is_instance_valid(_ground_shadow)
		or _contact_shadow == null or not is_instance_valid(_contact_shadow)):
		return
	if _sprite == null or not is_instance_valid(_sprite) or _tex == null:
		_ground_shadow.visible = false
		_contact_shadow.visible = false
		return
	var reflection_offset: Vector2 = Vector2(0.0, _current_size.y * FLOOR_REFLECTION_Y_RATIO)
	var contact_offset: Vector2 = Vector2(0.0, _current_size.y * FLOOR_REFLECTION_CONTACT_Y_RATIO)
	var neutral_mul: float = 0.66 if owner_id <= 0 else 1.0
	var reflection_material: Material = _npc_reflection_material() if owner_id <= 0 else null
	_ground_shadow.sync_reflection_from_sprite(
		_sprite,
		reflection_offset,
		FLOOR_REFLECTION_SCALE,
		FLOOR_REFLECTION_ALPHA * base_shadow_strength * neutral_mul,
		shadow_z_offset,
		FLOOR_REFLECTION_TINT,
		reflection_material
	)
	_contact_shadow.sync_reflection_from_sprite(
		_sprite,
		contact_offset,
		FLOOR_REFLECTION_CONTACT_SCALE,
		FLOOR_REFLECTION_CONTACT_ALPHA * base_shadow_strength * neutral_mul,
		shadow_z_offset + 1,
		FLOOR_REFLECTION_TINT.lerp(Color.WHITE, 0.14),
		reflection_material
	)

func _ensure_lane_occluder() -> void:
	if _lane_occluder != null and is_instance_valid(_lane_occluder):
		return
	var existing := get_node_or_null("LaneOccluder")
	if existing is Polygon2D:
		_lane_occluder = existing as Polygon2D
	else:
		var poly := Polygon2D.new()
		poly.name = "LaneOccluder"
		poly.z_index = -2
		poly.color = LANE_OCCLUDER_COLOR
		add_child(poly)
		_lane_occluder = poly

func _update_lane_occluder() -> void:
	_ensure_lane_occluder()
	if _lane_occluder == null or not is_instance_valid(_lane_occluder):
		return
	# The broad occluder was intended to hide lane art below the hive, but the
	# premium layer stack made it read as a black disk over the hive art.
	_lane_occluder.visible = false
	if _tex == null:
		if _ground_shadow != null:
			_ground_shadow.visible = false
		if _contact_shadow != null:
			_contact_shadow.visible = false
		if _ground_glow_layer != null:
			_ground_glow_layer.visible = false
		return
	_update_hive_shadows()
	_update_ground_glow()

func _ensure_shader_material() -> void:
	if _shader_mat == null:
		_shader_mat = ShaderMaterial.new()
		_shader_mat.shader = TEAM_GLOW_SHADER
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.material = _shader_mat

func _ensure_npc_shader_material() -> void:
	if _npc_shader_mat == null:
		_npc_shader_mat = ShaderMaterial.new()
		_npc_shader_mat.shader = NPC_GRAYSCALE_SHADER
	_configure_npc_shader_material(
		_npc_shader_mat,
		NPC_HIVE_COLOR,
		1.02,
		0.88,
		0.34,
		0.18,
		0.42,
		0.82
	)
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.material = _npc_shader_mat

func _npc_reflection_material() -> ShaderMaterial:
	if _npc_reflection_mat == null:
		_npc_reflection_mat = ShaderMaterial.new()
		_npc_reflection_mat.shader = NPC_GRAYSCALE_SHADER
	_configure_npc_shader_material(
		_npc_reflection_mat,
		NPC_HIVE_COLOR.lerp(Color.WHITE, 0.08),
		0.88,
		0.92,
		0.0,
		0.0,
		0.0,
		0.0
	)
	return _npc_reflection_mat

func _configure_npc_shader_material(
	mat: ShaderMaterial,
	tint: Color,
	brightness_value: float,
	tint_strength_value: float,
	glow_strength_value: float,
	additive_glow_value: float,
	pulse_strength_mult: float,
	pulse_speed_mult: float
) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("npc_tint", tint)
	mat.set_shader_parameter("contrast", 1.05)
	mat.set_shader_parameter("brightness", brightness_value)
	mat.set_shader_parameter("tint_strength", tint_strength_value)
	mat.set_shader_parameter("glow_strength", glow_strength_value)
	mat.set_shader_parameter("additive_glow", additive_glow_value)
	mat.set_shader_parameter("pulse_strength", hive_sprite_pulse_strength * pulse_strength_mult)
	mat.set_shader_parameter("pulse_speed", hive_sprite_pulse_speed * pulse_speed_mult)
	mat.set_shader_parameter("pulse_phase", _hive_sprite_pulse_phase())

func _resolve_tier(power_value: int) -> int:
	return _visual_tier_for_power(power_value)

static func visual_tier_for_power_value(power_value: int) -> int:
	if power_value <= 0:
		return 1
	if power_value <= SMALL_MAX_POWER:
		return 1
	if power_value <= MED_MAX_POWER:
		return 2
	return 3

static func tier_key_for_power_value(power_value: int) -> String:
	return SpriteRegistry.hive_power_tier_key(power_value)

static func tier_key_for_tier_value(tier: int) -> String:
	match tier:
		2:
			return "med"
		3:
			return "large"
		_:
			return "small"

func _visual_tier_for_power(power_value: int) -> int:
	return visual_tier_for_power_value(power_value)

func _tier_key_for_tier(tier: int) -> String:
	return tier_key_for_tier_value(tier)

static func _team_color_for_player(player_id: int) -> Color:
	return TeamVisuals.owner_color(player_id)

func _apply_tint(owner_id_value: int, power_value: int) -> void:
	_ensure_shader_material()
	var team_color: Color = _team_color_for_player(owner_id_value)
	var is_neutral_owner: bool = owner_id_value <= 0
	if not is_neutral_owner:
		team_color = _boost_team_color(team_color)
	owner_color = team_color
	var t: float = clamp(
		float(power_value) / float(LARGE_MAX_POWER),
		0.0,
		1.0
	)
	var base: Color = team_color.darkened(0.25)
	var bright: Color = team_color.lightened(0.15)
	_power_color = base.lerp(bright, t)
	_power_color.a = 1.0
	if debug_tint_log and not _tint_logged:
		_tint_logged = true
		var hive_id := -1
		var parent := get_parent()
		if parent != null and parent.has_method("get"):
			var id_v: Variant = parent.get("hive_id")
			if id_v != null:
				hive_id = int(id_v)
		SFLog.info("HIVE_TINT_SAMPLE", {
			"hive_id": hive_id,
			"owner_id": owner_id_value,
			"team_color": team_color
		})
	if _sprite != null and is_instance_valid(_sprite):
		if is_neutral_owner:
			# Hard grayscale for NPC/neutral owners: no red/green/blue/yellow tinting.
			_ensure_npc_shader_material()
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			if _shader_mat != null:
				_sprite.material = _shader_mat
			_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _shader_mat != null and not is_neutral_owner:
		_shader_mat.set_shader_parameter("team_color", team_color)
		_shader_mat.set_shader_parameter("glow_strength", lerp(0.95, 1.62, t))
		TeamVisuals.apply_white_projection_params(_shader_mat)
		_shader_mat.set_shader_parameter("additive_glow", lerp(0.30, 0.48, t))
		_shader_mat.set_shader_parameter("detail_preserve", 0.92)
		_shader_mat.set_shader_parameter("pulse_strength", hive_sprite_pulse_strength)
		_shader_mat.set_shader_parameter("pulse_speed", hive_sprite_pulse_speed)
		_shader_mat.set_shader_parameter("pulse_phase", _hive_sprite_pulse_phase())
	if _npc_shader_mat != null and is_neutral_owner:
		_npc_shader_mat.set_shader_parameter("npc_tint", NPC_HIVE_COLOR)
		_npc_shader_mat.set_shader_parameter("tint_strength", 0.88)
		_npc_shader_mat.set_shader_parameter("brightness", 1.02)
		_npc_shader_mat.set_shader_parameter("glow_strength", 0.34)
		_npc_shader_mat.set_shader_parameter("additive_glow", 0.18)
		_npc_shader_mat.set_shader_parameter("pulse_strength", hive_sprite_pulse_strength * 0.42)
		_npc_shader_mat.set_shader_parameter("pulse_speed", hive_sprite_pulse_speed * 0.82)
		_npc_shader_mat.set_shader_parameter("pulse_phase", _hive_sprite_pulse_phase())
	_update_projection_tint()
	_update_lane_budget_indicators()
	_update_ground_glow()
	_update_core_materials()

func _hive_sprite_pulse_phase() -> float:
	var hive_id_value: int = 0
	var parent := get_parent()
	if parent != null and parent.has_method("get"):
		var id_v: Variant = parent.get("hive_id")
		if id_v != null:
			hive_id_value = int(id_v)
	return (float(hive_id_value) * 0.73) + (float(owner_id) * 1.19)

func _boost_team_color(in_color: Color) -> Color:
	var boosted_s: float = clampf(in_color.s * HIVE_COLOR_SAT_BOOST, 0.0, 1.0)
	var boosted_v: float = clampf(in_color.v * HIVE_COLOR_VAL_BOOST, 0.0, 1.0)
	return Color.from_hsv(in_color.h, boosted_s, boosted_v, 1.0)

func _height_for_tier(base_height: float, tier: int) -> float:
	var small_h := height_small_px if height_small_px > 0.0 else base_height
	var med_h := height_med_px if height_med_px > 0.0 else base_height * HEIGHT_MED_SCALE
	var large_h := height_large_px if height_large_px > 0.0 else base_height * HEIGHT_LARGE_SCALE
	var max_h := height_max_px if height_max_px > 0.0 else base_height * HEIGHT_MAX_SCALE
	match tier:
		4:
			return max_h * HIVE_HEIGHT_SCALE
		3:
			return large_h * HIVE_HEIGHT_SCALE
		2:
			return med_h * HIVE_HEIGHT_SCALE
		_:
			return small_h * HIVE_HEIGHT_SCALE

func _apply_sprite() -> void:
	_ensure_sprite()
	_ensure_shader_material()
	if _sprite == null or not is_instance_valid(_sprite):
		return
	_sprite.texture = _tex
	_sprite.visible = _tex != null
	_sprite.position = _sprite_offset
	if _tex == null:
		_current_size = Vector2.ONE * maxf(20.0, radius_px * 2.0)
		_sprite.scale = Vector2.ONE
		if _lane_occluder != null:
			_lane_occluder.visible = false
		_update_hive_shadows()
		_update_core_layout()
		_update_ground_glow()
		_update_phase3_layout()
		_update_lane_budget_indicators()
		return
	var tex_size := Vector2(float(_tex.get_width()), float(_tex.get_height()))
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		_current_size = Vector2.ZERO
		_sprite.scale = Vector2.ONE
		_update_core_layout()
		_update_lane_occluder()
		_update_phase3_layout()
		_update_lane_budget_indicators()
		return
	var base_diameter := radius_px * 2.0 * _sprite_scale
	var target_height := _height_for_tier(
		height_small_px if height_small_px > 0.0 else base_diameter,
		_resolve_tier(power)
	)
	var uniform_scale := target_height / tex_size.y
	_current_size = tex_size * uniform_scale
	_sprite.scale = Vector2.ONE * uniform_scale
	_update_core_layout()
	_update_lane_occluder()
	_update_phase3_layout()
	_update_lane_budget_indicators()

func _hive_tex_debug(tex: Texture2D, key: String, scale: float, offset: Vector2) -> String:
	var region_enabled := false
	var region_rect := Rect2()
	var base_path := ""
	if tex is AtlasTexture:
		var atlas := tex as AtlasTexture
		region_enabled = true
		region_rect = atlas.region
		if atlas.atlas != null:
			base_path = str(atlas.atlas.resource_path)
	var img := tex.get_image() if tex != null else null
	var alpha_info := "unknown"
	if img != null:
		alpha_info = str(img.get_format() in [
			Image.FORMAT_RGBA8,
			Image.FORMAT_RGBAF,
			Image.FORMAT_RGBAH,
			Image.FORMAT_RGBA4444
		])
	return "key=%s scale=%s offset=%s tex=%s base_tex=%s w=%d h=%d region_enabled=%s region=%s alpha=%s" % [
		key,
		str(scale),
		str(offset),
		str(tex.resource_path),
		base_path,
		tex.get_width(),
		tex.get_height(),
		str(region_enabled),
		str(region_rect),
		alpha_info
	]
