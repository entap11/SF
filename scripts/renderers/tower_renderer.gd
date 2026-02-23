# NOTE: Minimal tower visualization (placeholder).
# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# They only (1) emit intents/requests and (2) render from state.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name TowerRenderer
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const BarracksRenderer := preload("res://scripts/renderers/barracks_renderer.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const SpriteRegistry := preload("res://scripts/renderers/sprite_registry.gd")
const TOWER_TEX_SMALL: Texture2D = preload("res://assets/sprites/sf_skin_v1/tower_small.tres")
const TOWER_TEX_MEDIUM: Texture2D = preload("res://assets/sprites/sf_skin_v1/tower_medium.tres")
const TOWER_TEX_LARGE: Texture2D = preload("res://assets/sprites/sf_skin_v1/tower_large.tres")

const TOWER_SPIKE_PX: float = 8.0
const TOWER_VISUAL_SCALE: float = 8.75
const TOWER_PITCH_SCALE_X: float = 1.1
const TOWER_PITCH_SCALE_Y: float = 1.6
const TOWER_BASE_LIFT_RATIO: float = 0.36
const TOWER_SPRITE_Z_INDEX: int = 2
const LOG_INTERVAL_MS: int = 1000
const TOWER_LIGHT_SWAP_SHADER_PATH: String = "res://assets/shaders/sf_color_swap.gdshader"
const TOWER_LIGHT_FROM_COLOR: Color = Color(1.0, 0.8235, 0.0, 1.0)
const TOWER_SIZE_MULT_T1: float = 1.0
const TOWER_SIZE_MULT_T2: float = 1.14
const TOWER_SIZE_MULT_T3_PLUS: float = 1.30

var model: Dictionary = {}
var towers: Array = []
var _last_set_log_ms: int = 0
var _logged_tower_ids: Dictionary = {}
var _sprite_registry: SpriteRegistry = null
var _tower_labels: Dictionary = {}
var _tower_sprites_by_id: Dictionary = {}
var _structure_control_system: Object = null

func _ready() -> void:
	SFLog.info("TOWER_RENDERER_READY", {"path": str(get_path())})
	_bind_structure_control_system()
	set_process(true)

func set_model(m: Dictionary) -> void:
	_bind_structure_control_system()
	model = m
	var towers_v: Variant = model.get("towers", [])
	towers = towers_v as Array if typeof(towers_v) == TYPE_ARRAY else []
	if towers.is_empty():
		_logged_tower_ids.clear()
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_set_log_ms >= LOG_INTERVAL_MS:
		_last_set_log_ms = now_ms
		SFLog.log_on_change_payload("TOWER_RENDERER_SET", towers.size(), {"count": towers.size()})
	_log_new_towers()
	_sync_tower_sprites()
	queue_redraw()

func _draw() -> void:
	if towers.is_empty():
		return
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var pos: Vector2 = _tower_world_pos(td)
		var owner_id: int = int(td.get("owner_id", 0))
		var active: bool = bool(td.get("active", owner_id != 0))
		var tower_id: int = int(td.get("id", -1))
		var sprite: Sprite2D = _tower_sprites_by_id.get(tower_id, null)
		var has_tex: bool = sprite != null and sprite.visible and sprite.texture != null
		if not has_tex:
			var color: Color = HiveRenderer._owner_color(owner_id)
			color.a = 0.9
			var fallback_h: float = TOWER_SPIKE_PX * TOWER_VISUAL_SCALE * TOWER_PITCH_SCALE_Y
			var tip: Vector2 = pos + Vector2(0.0, -fallback_h)
			draw_line(pos, tip, color, 2.0)
			var half_w: float = maxf(2.0, fallback_h * 0.14)
			draw_line(pos + Vector2(-half_w, 0.0), pos + Vector2(half_w, 0.0), color, 1.5)

func _process(_delta: float) -> void:
	_update_tower_labels()

func _update_tower_labels() -> void:
	if towers.is_empty():
		for key in _tower_labels.keys():
			var label: Label = _tower_labels[key]
			if label != null:
				label.queue_free()
		_tower_labels.clear()
		return

	var keep: Dictionary = {}
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("id", -1))
		if tower_id <= 0:
			continue
		keep[tower_id] = true
		var label: Label = _tower_labels.get(tower_id, null)
		if label == null:
			label = Label.new()
			label.name = "TowerLabel_%d" % tower_id
			label.z_index = 200
			add_child(label)
			_tower_labels[tower_id] = label
		var owner_id: int = int(td.get("owner_id", 0))
		var active: bool = bool(td.get("active", owner_id != 0))
		var tier: int = int(td.get("tier", 0))
		var cooldown_remaining: float = float(td.get("cooldown_remaining", td.get("cooldown_ms", 0.0)))
		var current_power: float = float(td.get("current_power", td.get("power", 0.0)))
		label.text = "owner_id=%s active=%s tier=%s cooldown_remaining=%s current_power=%s" % [
			str(owner_id),
			str(active),
			str(tier),
			str(cooldown_remaining),
			str(current_power)
		]
		var pos: Vector2 = _tower_world_pos(td)
		var label_pos: Vector2 = pos + Vector2(0.0, -TOWER_SPIKE_PX * TOWER_VISUAL_SCALE * TOWER_PITCH_SCALE_Y - 20.0)
		var sprite: Sprite2D = _tower_sprites_by_id.get(tower_id, null)
		if sprite != null and sprite.visible and sprite.texture != null:
			var draw_h: float = float(sprite.texture.get_height()) * absf(sprite.scale.y)
			label_pos = sprite.position + Vector2(0.0, -draw_h * 0.58 - 18.0)
		label.position = label_pos

	for key in _tower_labels.keys():
		if not keep.has(key):
			var stale: Label = _tower_labels[key]
			if stale != null:
				stale.queue_free()
			_tower_labels.erase(key)

func _tower_world_pos(td: Dictionary) -> Vector2:
	var pos_v: Variant = td.get("pos_px", null)
	if pos_v is Vector2:
		return pos_v as Vector2
	var gp_v: Variant = td.get("grid_pos", Vector2i.ZERO)
	var gp: Vector2i = Vector2i.ZERO
	if gp_v is Vector2i:
		gp = gp_v as Vector2i
	elif gp_v is Array:
		var gp_arr: Array = gp_v as Array
		if gp_arr.size() >= 2:
			gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
	var cell_size: float = float(model.get("cell_size", 64))
	return Vector2((float(gp.x) + 0.5) * cell_size, (float(gp.y) + 0.5) * cell_size)

func _log_new_towers() -> void:
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("id", -1))
		if tower_id <= 0 or _logged_tower_ids.has(tower_id):
			continue
		_logged_tower_ids[tower_id] = true
		var gp_v: Variant = td.get("grid_pos", Vector2i.ZERO)
		var gp: Vector2i = Vector2i.ZERO
		if gp_v is Vector2i:
			gp = gp_v as Vector2i
		elif gp_v is Array:
			var gp_arr: Array = gp_v as Array
			if gp_arr.size() >= 2:
				gp = Vector2i(int(gp_arr[0]), int(gp_arr[1]))
		var pos: Vector2 = _tower_world_pos(td)
		SFLog.info("TOWER_RENDER_CREATE", {"id": tower_id, "grid_pos": gp, "world_pos": pos})

func _sync_tower_sprites() -> void:
	if towers.is_empty():
		for key in _tower_sprites_by_id.keys():
			var sprite: Sprite2D = _tower_sprites_by_id[key]
			if sprite != null:
				sprite.queue_free()
		_tower_sprites_by_id.clear()
		return

	var keep: Dictionary = {}
	var registry: SpriteRegistry = _get_sprite_registry()
	for tower_any in towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		var tower_id: int = int(td.get("id", -1))
		if tower_id <= 0:
			continue
		keep[tower_id] = true
		var sprite: Sprite2D = _tower_sprites_by_id.get(tower_id, null)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = "TowerSprite_%d" % tower_id
			sprite.centered = true
			sprite.z_index = TOWER_SPRITE_Z_INDEX
			sprite.add_to_group("sf_tower")
			add_child(sprite)
			_tower_sprites_by_id[tower_id] = sprite
		_update_tower_sprite(sprite, td, registry)
		_apply_tower_owner_visual(tower_id, int(td.get("owner_id", 0)))

	for key in _tower_sprites_by_id.keys():
		if not keep.has(key):
			var sprite: Sprite2D = _tower_sprites_by_id[key]
			if sprite != null:
				sprite.queue_free()
			_tower_sprites_by_id.erase(key)

func _update_tower_sprite(sprite: Sprite2D, td: Dictionary, registry: SpriteRegistry) -> void:
	var pos: Vector2 = _tower_world_pos(td)
	sprite.position = pos
	var owner_id: int = int(td.get("owner_id", 0))
	var active: bool = bool(td.get("active", owner_id != 0))
	var tier: int = int(td.get("tier", 1))
	var owner_key: String = SpriteRegistry.owner_key(owner_id)
	var state_key: String = "active" if active else "base"
	var key: String = "tower.%s.%s" % [state_key, owner_key]
	var tex: Texture2D = null
	var scale: float = 1.0
	var offset: Vector2 = Vector2.ZERO
	if registry != null:
		tex = registry.get_tex(key)
		scale = registry.get_scale(key)
		offset = registry.get_offset(key)
	var tier_tex: Texture2D = _tower_texture_for_tier(tier, state_key, owner_key, registry)
	if tier_tex != null:
		tex = tier_tex
	sprite.texture = tex
	if tex != null:
		var tex_size: Vector2 = tex.get_size()
		var tier_mult: float = _tower_size_multiplier_for_tier(tier)
		var draw_size_px: float = TOWER_SPIKE_PX * 2.0 * TOWER_VISUAL_SCALE * maxf(0.1, scale) * tier_mult
		var tex_max: float = maxf(tex_size.x, tex_size.y)
		var s: float = draw_size_px / tex_max if tex_max > 0.0 else 1.0
		var scale_x: float = TOWER_PITCH_SCALE_X * s
		var scale_y: float = TOWER_PITCH_SCALE_Y * s
		sprite.scale = Vector2(scale_x, scale_y)
		var draw_h: float = tex_size.y * scale_y
		sprite.position = pos + offset + Vector2(0.0, -draw_h * TOWER_BASE_LIFT_RATIO)
		sprite.z_index = TOWER_SPRITE_Z_INDEX
		sprite.visible = true
	else:
		sprite.position = pos
		sprite.visible = false

func _tower_texture_for_tier(tier: int, state_key: String, owner_key: String, registry: SpriteRegistry) -> Texture2D:
	if registry != null:
		var tier_key: String = "tower.%s.t%d.%s" % [state_key, _visual_tier_bucket(tier), owner_key]
		if registry.has_tex(tier_key):
			return registry.get_tex(tier_key)
	match _visual_tier_bucket(tier):
		1:
			return TOWER_TEX_SMALL
		2:
			return TOWER_TEX_MEDIUM
		_:
			return TOWER_TEX_LARGE

func _visual_tier_bucket(tier: int) -> int:
	# Sim tier is 1..4 while art has 3 sizes:
	# tiers 1-2 -> small, 3 -> medium, 4+ -> large.
	if tier <= 2:
		return 1
	if tier == 3:
		return 2
	return 3

func _tower_size_multiplier_for_tier(tier: int) -> float:
	if tier <= 1:
		return TOWER_SIZE_MULT_T1
	if tier == 2:
		return TOWER_SIZE_MULT_T2
	return TOWER_SIZE_MULT_T3_PLUS

func _apply_tower_owner_visual(tower_id: int, owner_id: int) -> void:
	if not _tower_sprites_by_id.has(tower_id):
		return
	var sprite: Sprite2D = _tower_sprites_by_id.get(tower_id, null)
	if sprite == null:
		return
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	var shader: Shader = null
	if mat != null and mat.shader != null:
		shader = mat.shader
	if mat == null or shader == null or shader.resource_path != TOWER_LIGHT_SWAP_SHADER_PATH:
		shader = load(TOWER_LIGHT_SWAP_SHADER_PATH)
		if shader == null:
			return
		mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("from_color", TOWER_LIGHT_FROM_COLOR)
		sprite.material = mat
	var to_col: Color = BarracksRenderer.NPC_ACCENT_COLOR
	to_col = _tower_light_color(owner_id)
	mat.set_shader_parameter("to_color", to_col)
	SFLog.info("TOWER_LIGHTS_COLOR", {"tower_id": tower_id, "owner_id": owner_id})

func _on_structure_owner_changed(
	structure_type: String,
	structure_id: int,
	prev_owner: int,
	next_owner: int,
	control_ids: Array
) -> void:
	if structure_type != "tower":
		return
	_apply_tower_owner_visual(structure_id, next_owner)

func _tower_light_color(owner_id: int) -> Color:
	if owner_id <= 0:
		return BarracksRenderer.NPC_ACCENT_COLOR
	if owner_id >= 1 and owner_id <= 4:
		return HiveRenderer._owner_color(owner_id)
	SFLog.log_once(
		"UNKNOWN_OWNER_ID:%d" % owner_id,
		"UNKNOWN_OWNER_ID",
		SFLog.Level.WARN,
		{"owner_id": owner_id}
	)
	return BarracksRenderer.NPC_ACCENT_COLOR

func _bind_structure_control_system() -> void:
	if _structure_control_system != null and is_instance_valid(_structure_control_system):
		return
	var sim_runner: Node = _find_sim_runner()
	if sim_runner == null:
		return
	if not sim_runner.has_method("get_structure_control_system"):
		return
	var scs: Object = sim_runner.call("get_structure_control_system")
	if scs == null:
		return
	_structure_control_system = scs
	if _structure_control_system.has_signal("structure_owner_changed"):
		var signal_obj = _structure_control_system.structure_owner_changed
		if not signal_obj.is_connected(_on_structure_owner_changed):
			signal_obj.connect(_on_structure_owner_changed)

func _find_sim_runner() -> Node:
	var n: Node = self
	while n != null:
		var sr: Node = n.get_node_or_null("SimRunner")
		if sr != null:
			return sr
		n = n.get_parent()
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene.find_child("SimRunner", true, false)
	return null

func _get_sprite_registry() -> SpriteRegistry:
	if _sprite_registry == null:
		_sprite_registry = SpriteRegistry.get_instance()
	return _sprite_registry
