# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name BarracksRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const BARRACKS_ACCENT_SHADER := preload("res://assets/shaders/barracks_accent_recolor.gdshader")

const LOG_INTERVAL_MS: int = 1000
const BARRACKS_SIZE_PX: float = 10.0
const BARRACKS_VISUAL_SCALE: float = 1.5
const BARRACKS_PITCH_SCALE_X := 1.00
const BARRACKS_PITCH_SCALE_Y := 0.88
const BARRACKS_SELECTOR_PATH := "res://assets/sprites/sf_skin_v1/selector_ring_large.tres"
const TARGET_RING_EXTRA_PX: float = 6.0
const TARGET_RING_WIDTH: float = 2.0
const TARGET_RING_STEPS: int = 48
const ORDER_LABEL_RADIUS_PX: float = 7.0
const ORDER_LABEL_FONT_SIZE: int = 12
const DRAW_TARGET_LINKS := false
const NPC_ACCENT_COLOR := Color(0.55, 0.50, 0.70, 1.0)

var model: Dictionary = {}
var barracks: Array = []
var selected_barracks_id: int = -1
var selected_barracks_owner_id: int = -1
var _last_set_log_ms: int = 0
var _sprite_registry: SpriteRegistry = null
var _selector_tex: Texture2D = null
var _barracks_nodes: Dictionary = {}

func _ready() -> void:
	SFLog.info("BARRACKS_RENDERER_READY", {"path": str(get_path())})
	_load_selector_texture()

func _load_selector_texture() -> void:
	if _selector_tex != null:
		return
	if not ResourceLoader.exists(BARRACKS_SELECTOR_PATH):
		return
	var res := ResourceLoader.load(BARRACKS_SELECTOR_PATH)
	if res is Texture2D:
		_selector_tex = res as Texture2D

func set_model(m: Dictionary) -> void:
	model = m
	var barracks_v: Variant = model.get("barracks", [])
	barracks = barracks_v as Array if typeof(barracks_v) == TYPE_ARRAY else []
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_set_log_ms >= LOG_INTERVAL_MS:
		_last_set_log_ms = now_ms
		SFLog.log_on_change_payload("BARRACKS_RENDERER_SET", barracks.size(), {"count": barracks.size()})
	_sync_barracks_sprites()
	queue_redraw()

func set_selected_barracks(id: int, owner_id: int) -> void:
	selected_barracks_id = id
	selected_barracks_owner_id = owner_id
	queue_redraw()

func clear_selected_barracks() -> void:
	selected_barracks_id = -1
	selected_barracks_owner_id = -1
	queue_redraw()

func _draw() -> void:
	if barracks.is_empty():
		return
	var hives_by_id: Dictionary = model.get("hives_by_id", {})
	var selected_id_model: int = int(model.get("barracks_select_id", -1))
	var selected_id: int = selected_barracks_id if selected_barracks_id != -1 else selected_id_model
	var selected_pos: Vector2 = Vector2.ZERO
	var selected_found := false
	var ring_owner_id: int = selected_barracks_owner_id
	for barracks_any in barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var bd: Dictionary = barracks_any as Dictionary
		var barracks_id: int = int(bd.get("id", -1))
		var pos: Vector2 = _barracks_anchor_pos(bd, hives_by_id)
		var owner_id: int = int(bd.get("owner_id", 0))
		var active: bool = bool(bd.get("active", owner_id != 0))
		if barracks_id == selected_id:
			selected_pos = pos
			selected_found = true
			ring_owner_id = owner_id
		var color: Color = HiveRenderer._owner_color(owner_id)
		color.a = 0.9
		_draw_control_links(pos, bd, color, hives_by_id)
		var owner_key := SpriteRegistry.owner_key(owner_id)
		var state_key := "active" if active else "base"
		var key := "barracks.%s.%s" % [state_key, owner_key]
		var tex: Texture2D = null
		var registry := _get_sprite_registry()
		var scale := 1.0
		var offset := Vector2.ZERO
		if registry != null:
			tex = registry.get_tex(key)
			scale = registry.get_scale(key)
			offset = registry.get_offset(key)
		if tex != null:
			SFLog.log_once(
				"BARRACKS_SPRITE_META",
				"key=%s scale=%s offset=%s tex=%s w=%d h=%d" % [
					key,
					str(scale),
					str(offset),
					str(tex.resource_path),
					tex.get_width(),
					tex.get_height()
				],
				SFLog.Level.INFO
			)
		var draw_size_px := BARRACKS_SIZE_PX * scale * BARRACKS_VISUAL_SCALE
		var draw_pos := pos + offset
		if tex == null:
			var half: float = draw_size_px * 0.5
			var rect := Rect2(draw_pos - Vector2(half, half), Vector2(draw_size_px, draw_size_px))
			draw_rect(rect, color, true)
			draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
		if barracks_id == selected_id:
			if _selector_tex != null:
				var ring_size := Vector2(draw_size_px, draw_size_px) * 1.6
				var ring_rect := Rect2(pos - ring_size * 0.5, ring_size)
				draw_texture_rect(_selector_tex, ring_rect, false)
			else:
				var ring_color: Color = HiveRenderer._owner_color(owner_id)
				ring_color.a = 0.9
				draw_arc(pos, draw_size_px * 0.9 + 4.0, 0.0, TAU, 32, ring_color, 2.0)
	var targets_v: Variant = model.get("barracks_select_targets", [])
	if selected_id <= 0 or typeof(targets_v) != TYPE_ARRAY:
		return
	var targets: Array = targets_v as Array
	if targets.is_empty():
		return
	var ring_color: Color = HiveRenderer._owner_color(ring_owner_id)
	ring_color.a = 0.85
	var font: Font = ThemeDB.fallback_font
	var idx := 1
	for hive_id_v in targets:
		var hive_id: int = int(hive_id_v)
		if not hives_by_id.has(hive_id):
			continue
		var hive: Dictionary = hives_by_id[hive_id]
		var hive_pos_v: Variant = hive.get("pos", null)
		if not (hive_pos_v is Vector2):
			continue
		var hive_pos: Vector2 = hive_pos_v as Vector2
		var hive_radius: float = float(hive.get("radius_px", 0.0))
		var ring_radius: float = hive_radius + TARGET_RING_EXTRA_PX
		draw_arc(hive_pos, ring_radius, 0.0, TAU, TARGET_RING_STEPS, ring_color, TARGET_RING_WIDTH)
		if font != null:
			var label := str(idx)
			var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ORDER_LABEL_FONT_SIZE)
			var badge_pos := hive_pos + Vector2(ring_radius + ORDER_LABEL_RADIUS_PX, -ring_radius - ORDER_LABEL_RADIUS_PX)
			draw_circle(badge_pos, ORDER_LABEL_RADIUS_PX, Color(0, 0, 0, 0.7))
			draw_arc(badge_pos, ORDER_LABEL_RADIUS_PX, 0.0, TAU, 24, ring_color, 1.0)
			var text_pos := badge_pos - (size * 0.5) + Vector2(0.0, size.y * 0.35)
			draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, ORDER_LABEL_FONT_SIZE, Color(1, 1, 1, 1))
		if DRAW_TARGET_LINKS and selected_found:
			var link_color := ring_color
			link_color.a = 0.25
			draw_line(selected_pos, hive_pos, link_color, 1.5)
		idx += 1

func _sync_barracks_sprites() -> void:
	var hives_by_id: Dictionary = model.get("hives_by_id", {})
	var keep: Dictionary = {}
	var registry := _get_sprite_registry()
	for barracks_any in barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var bd: Dictionary = barracks_any as Dictionary
		var barracks_id: int = int(bd.get("id", -1))
		if barracks_id <= 0:
			continue
		keep[barracks_id] = true
		var anchor: Node2D = _barracks_nodes.get(barracks_id, null)
		if anchor == null:
			anchor = Node2D.new()
			anchor.name = "BarracksAnchor_%d" % barracks_id
			anchor.z_index = 0
			add_child(anchor)
			_barracks_nodes[barracks_id] = anchor
		var owner_id: int = int(bd.get("owner_id", 0))
		var active: bool = bool(bd.get("active", owner_id != 0))
		var owner_key := SpriteRegistry.owner_key(owner_id)
		var state_key := "active" if active else "base"
		var key := "barracks.%s.%s" % [state_key, owner_key]
		var tex: Texture2D = null
		var scale := 1.0
		var offset := Vector2.ZERO
		if registry != null:
			tex = registry.get_tex(key)
			scale = registry.get_scale(key)
			offset = registry.get_offset(key)
		var sprite := anchor.get_node_or_null("Sprite") as Sprite2D
		if tex == null:
			if sprite != null:
				sprite.visible = false
			continue
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "Sprite"
			sprite.centered = true
			sprite.z_index = 0
			anchor.add_child(sprite)
		var mat: ShaderMaterial = null
		if sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == BARRACKS_ACCENT_SHADER:
			mat = sprite.material as ShaderMaterial
		if mat == null:
			mat = ShaderMaterial.new()
			mat.shader = BARRACKS_ACCENT_SHADER
			sprite.material = mat
		var accent_color := _barracks_accent_color(owner_id)
		mat.set_shader_parameter("target_color", accent_color)
		sprite.texture = tex
		sprite.visible = true
		sprite.rotation = 0.0
		sprite.offset = Vector2.ZERO
		sprite.position = offset
		var tex_size := tex.get_size()
		var draw_size_px := BARRACKS_SIZE_PX * scale * BARRACKS_VISUAL_SCALE
		var tex_max := maxf(tex_size.x, tex_size.y)
		var s := draw_size_px / tex_max if tex_max > 0.0 else 1.0
		var scale_x := BARRACKS_PITCH_SCALE_X * s
		var scale_y := BARRACKS_PITCH_SCALE_Y * s
		sprite.scale = Vector2(scale_x, scale_y)
		anchor.position = _barracks_anchor_pos(bd, hives_by_id)
	for id in _barracks_nodes.keys():
		if keep.has(id):
			continue
		var anchor: Node2D = _barracks_nodes.get(id, null)
		if anchor != null:
			anchor.queue_free()
		_barracks_nodes.erase(id)

func _draw_control_links(pos: Vector2, bd: Dictionary, base_color: Color, hives_by_id: Dictionary) -> void:
	var control_v: Variant = bd.get("control_hive_ids", bd.get("required_hive_ids", []))
	if typeof(control_v) != TYPE_ARRAY:
		return
	var link_color: Color = base_color
	link_color.a = 0.25
	for hive_id_v in control_v as Array:
		var hive_id: int = int(hive_id_v)
		if not hives_by_id.has(hive_id):
			continue
		var hive: Dictionary = hives_by_id[hive_id]
		var hive_pos_v: Variant = hive.get("pos", null)
		if hive_pos_v is Vector2:
			draw_line(pos, hive_pos_v as Vector2, link_color, 1.0)

func _barracks_anchor_pos(bd: Dictionary, hives_by_id: Dictionary) -> Vector2:
	var ids := [2, 3, 7, 8]
	var sum := Vector2.ZERO
	for hive_id in ids:
		if not hives_by_id.has(hive_id):
			return _barracks_world_pos(bd)
		var h: Dictionary = hives_by_id[hive_id]
		var pos_v: Variant = h.get("pos", null)
		if not (pos_v is Vector2):
			return _barracks_world_pos(bd)
		sum += pos_v as Vector2
	return sum * 0.25

func _barracks_world_pos(bd: Dictionary) -> Vector2:
	var pos_v: Variant = bd.get("pos_px", null)
	if pos_v is Vector2:
		return pos_v as Vector2
	var gp_v: Variant = bd.get("grid_pos", Vector2i.ZERO)
	var gp: Vector2i = Vector2i.ZERO
	if gp_v is Vector2i:
		gp = gp_v as Vector2i
	elif gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var cell_size: float = float(model.get("cell_size", 64))
	return Vector2((float(gp.x) + 0.5) * cell_size, (float(gp.y) + 0.5) * cell_size)

func _barracks_accent_color(owner_id: int) -> Color:
	if _is_prematch():
		return NPC_ACCENT_COLOR
	if owner_id <= 0:
		return NPC_ACCENT_COLOR
	if owner_id >= 1 and owner_id <= 4:
		return HiveRenderer._owner_color(owner_id)
	SFLog.log_once(
		"UNKNOWN_OWNER_ID:%d" % owner_id,
		"UNKNOWN_OWNER_ID",
		SFLog.Level.WARN,
		{"owner_id": owner_id}
	)
	return NPC_ACCENT_COLOR

func _is_prematch() -> bool:
	return OpsState.match_phase == OpsState.MatchPhase.PREMATCH and int(OpsState.prematch_remaining_ms) > 0

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry
