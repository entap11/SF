class_name HiveGrowthTransition
extends Node2D
## Disposable presentation over canonical tier edges. Never writes gameplay state.

signal transition_started(old_tier: int, new_tier: int)
signal reveal_started(new_tier: int)
signal transition_finished(new_tier: int)
signal transition_cancelled(reason: String)

const Timing := preload("res://scripts/hive/hive_transition_timing.gd")
const BODY_SHADER := preload("res://shaders/hive_transform_surface.gdshader")
const CONTACT_SHADER := preload("res://shaders/hive_transform_contact.gdshader")
const SFLog := preload("res://scripts/util/sf_log.gd")
const GROWTH_SOUND_PATH := "res://assets/sprites/sf_skin_v1/sf_sounds/hive_growth.ogg"

var _body: Polygon2D
var _contact: Polygon2D
var _body_material: ShaderMaterial
var _contact_material: ShaderMaterial
var _audio_player: AudioStreamPlayer
var _source: Sprite2D
var _before: Dictionary = {}
var _after: Dictionary = {}
var _active := false
var _mode := "none"
var _old_tier := 0
var _new_tier := 0
var _elapsed := 0.0
var _side := 1.0
var _quad_center := Vector2.ZERO
var _port_entry: Dictionary = {}
var _core_layers: Array[CanvasItem] = []
var _revealed := false
var _pose: Dictionary = {}
var _style_signature: Array = []
var _initial_reveal := 0.0
var _resume_reveal := 0.0
var _resume_from := 0
var _resume_to := 0
var _port: CanvasItem
var _port_modulate := Color.WHITE
var _port_elapsed := -1.0

func _ready() -> void:
	_ensure_nodes()
	set_process(false)

func capture_old_sprite(source: Sprite2D, old_size: Vector2) -> bool:
	_ensure_nodes()
	_resume_reveal = float(_pose.get("reveal", 0.0)) if _active else 0.0
	_resume_from = _old_tier if _active else 0
	_resume_to = _new_tier if _active else 0
	cancel_and_reveal_final("replaced", false)
	_source = source
	_before = _sample_sprite(source, old_size)
	return not _before.is_empty()

func play(final_size: Vector2, center: Vector2, owner_color: Color, old_tier: int, new_tier: int, port_entry: Dictionary = {}, mode: String = "full") -> void:
	_ensure_nodes()
	_after = _sample_sprite(_source, final_size)
	_port_entry = port_entry
	_quad_center = center
	if _before.is_empty() or _after.is_empty() or mode == "none":
		cancel_and_reveal_final("unavailable_source")
		return
	_old_tier = old_tier
	_new_tier = new_tier
	_mode = mode
	_elapsed = 0.0
	_revealed = false
	_initial_reveal = 0.0
	if _resume_from == new_tier and _resume_to == old_tier and mode == "full":
		_initial_reveal = 1.0 - _resume_reveal
	_resume_from = 0
	_resume_to = 0
	_active = true
	_style_signature.clear()
	_side = maxf(maxf(_before.size.x, _after.size.x), maxf(_before.size.y, _after.size.y)) * 1.12
	var rect := Rect2(center - Vector2.ONE * _side * 0.5, Vector2.ONE * _side)
	_set_quad(_body, _body_material, rect)
	var ground := center + Vector2(0.0, final_size.y * 0.31)
	_set_quad(_contact, _contact_material, Rect2(ground - Vector2(final_size.x * 0.70, final_size.x * 0.20), Vector2(final_size.x * 1.40, final_size.x * 0.40)))
	for entry in [["before", _before], ["after", _after]]:
		var prefix: String = entry[0]
		var data: Dictionary = entry[1]
		_body_material.set_shader_parameter(prefix + "_tex", data.texture)
		_body_material.set_shader_parameter(prefix + "_size", data.size / _side)
		_body_material.set_shader_parameter(prefix + "_center", (data.center - center) / _side)
		_body_material.set_shader_parameter(prefix + "_region", data.region)
		_body_material.set_shader_parameter(prefix + "_flip", data.flip)
		_body_material.set_shader_parameter(prefix + "_key_enabled", data.key_enabled)
	_body_material.set_shader_parameter("direction", 1.0 if new_tier > old_tier else -1.0)
	_body_material.set_shader_parameter("reduced", 1.0 if mode == "reduced" else 0.0)
	_body_material.set_shader_parameter("owner_color", owner_color)
	_contact_material.set_shader_parameter("owner_color", owner_color)
	_refresh_source_style()
	_body.visible = true
	_contact.visible = mode == "full"
	_source.visible = false
	transition_started.emit(old_tier, new_tier)
	_sample_time(0.0)
	set_process(_active)
	SFLog.info("HIVE_TRANSFORM_START", {"old_tier": old_tier, "new_tier": new_tier, "mode": mode})

func _sample_sprite(source: Sprite2D, size: Vector2) -> Dictionary:
	if source == null or not is_instance_valid(source) or source.texture == null:
		return {}
	var texture: Texture2D = source.texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		region = (texture as AtlasTexture).region
		texture = (texture as AtlasTexture).atlas
		if texture == null:
			return {}
	if source.region_enabled:
		region = Rect2(region.position + source.region_rect.position, source.region_rect.size)
	var total := texture.get_size()
	if total.x <= 0.0 or total.y <= 0.0:
		return {}
	var sprite_center := source.offset
	if not source.centered:
		sprite_center += region.size * 0.5
	var key_enabled: Variant = source.material.get_shader_parameter("key_enabled") if source.material is ShaderMaterial else 0.0
	return {"texture": texture, "size": size, "center": to_local(source.to_global(sprite_center)),
		"region": Vector4(region.position.x / total.x, region.position.y / total.y, region.size.x / total.x, region.size.y / total.y),
		"flip": Vector2(float(source.flip_h), float(source.flip_v)),
		"key_enabled": float(key_enabled) if key_enabled != null else 0.0}

func sync_source_style(owner: int, power: int, selected: bool, selection_color: Color, opacity: float) -> void:
	if not _active:
		return
	var signature := [owner, power, selected, selection_color, opacity]
	if signature == _style_signature:
		return
	_style_signature = signature
	_refresh_source_style()

func _refresh_source_style() -> void:
	if _source == null or not is_instance_valid(_source):
		return
	var mat := _source.material as ShaderMaterial
	if mat == null:
		return
	for key in ["global_alpha", "glow_strength", "additive_glow", "white_strength", "selected_hot", "selected_hot_color", "selected_metal_lift", "selected_hot_edge", "key_color", "key_threshold", "key_softness"]:
		var value: Variant = mat.get_shader_parameter(key)
		if value != null:
			_body_material.set_shader_parameter(key, value)
	var tint: Variant = mat.get_shader_parameter("team_color")
	if tint != null:
		_body_material.set_shader_parameter("owner_color", tint)
	_body_material.set_shader_parameter("neutral", 1.0 if mat.shader != null and mat.shader.resource_path.ends_with("hive_npc_grayscale.gdshader") else 0.0)

func _process(delta: float) -> void:
	if _active:
		_elapsed += maxf(delta, 0.0)
		_sample_time(_elapsed)
	if _port_elapsed >= 0.0:
		_port_elapsed += maxf(delta, 0.0)
		if is_instance_valid(_port):
			_port.modulate = _port_modulate.lerp(Color(1.0, 0.96, 0.75), sin(clampf(_port_elapsed / 0.20, 0.0, 1.0) * PI) * 0.55)
		if _port_elapsed >= 0.20:
			_restore_port()
	set_process(_active or _port_elapsed >= 0.0)

func _sample_time(seconds: float) -> void:
	if not is_instance_valid(_source):
		cancel_and_reveal_final("source_removed")
		return
	_pose = Timing.sample(seconds, _old_tier, _new_tier, _mode == "reduced")
	_pose["reveal"] = lerpf(_initial_reveal, 1.0, float(_pose.reveal))
	var progress: float = _pose.reveal
	var center: Vector2 = (_before.center as Vector2).lerp(_after.center, progress)
	var bounds: Vector2 = (_before.size as Vector2).lerp(_after.size, progress)
	var origin: Vector2 = _quad_center
	var ground: float = (center.y - origin.y + bounds.y * 0.44) / _side
	var top: float = ground - bounds.y * 0.87 / _side
	var bottom: float = ground - bounds.y * 0.045 / _side
	_body_material.set_shader_parameter("sweep", lerpf(bottom, top, progress) if _new_tier > _old_tier else lerpf(top, bottom, progress))
	for key in ["reveal", "charge", "band_energy", "settle", "body_scale"]:
		_body_material.set_shader_parameter(key, _pose[key])
	_contact_material.set_shader_parameter("energy", _pose.ground)
	_contact_material.set_shader_parameter("arrival", progress)
	if progress > 0.0 and not _revealed:
		_revealed = true
		reveal_started.emit(_new_tier)
		confirm_port_entry(_port_entry)
		if _new_tier > _old_tier and _audio_player.stream != null:
			_audio_player.play()
	# Blend to the actual, currently styled final sprite during the seating phase.
	# This also preserves cosmetic materials and live selection changes at handoff.
	if progress >= 0.999:
		_source.visible = true
		_body.modulate.a = 1.0 - smoothstep(0.46 if _new_tier > _old_tier else 0.34, 0.66 if _new_tier > _old_tier else 0.49, seconds)
	else:
		_source.visible = false
		_body.modulate.a = 1.0
	_body_material.set_shader_parameter("surface_opacity", _body.modulate.a)
	for layer in _core_layers:
		if is_instance_valid(layer):
			layer.visible = progress >= 0.999
	if bool(_pose.done):
		_active = false
		_reveal_final()
		transition_finished.emit(_new_tier)

func cancel_and_reveal_final(reason: String = "cancelled", emit_event: bool = true) -> void:
	var was_active := _active
	_active = false
	_restore_port()
	_reveal_final()
	set_process(false)
	if _audio_player != null:
		_audio_player.stop()
	if was_active and emit_event:
		transition_cancelled.emit(reason)

func _reveal_final() -> void:
	if is_instance_valid(_source):
		_source.visible = true
	for layer in _core_layers:
		if is_instance_valid(layer):
			layer.visible = true
	if _body != null:
		_body.visible = false
		_body.modulate = Color.WHITE
	if _contact != null:
		_contact.visible = false

func confirm_port_entry(entry: Dictionary) -> void:
	_restore_port()
	if _mode != "full":
		return
	_port = entry.get("fill", null) as CanvasItem
	if is_instance_valid(_port):
		_port_modulate = _port.modulate
		_port_elapsed = 0.0
		set_process(true)

func _restore_port() -> void:
	if is_instance_valid(_port):
		_port.modulate = _port_modulate
	_port = null
	_port_elapsed = -1.0

func is_active() -> bool:
	return _active

func set_debug_elapsed(seconds: float) -> void:
	set_process(false)
	if _active:
		_elapsed = maxf(seconds, 0.0)
		_sample_time(_elapsed)
	set_process(false)

func get_debug_snapshot() -> Dictionary:
	return {"active": _active, "old_tier": _old_tier, "new_tier": _new_tier, "mode": _mode,
		"elapsed": _elapsed, "reveal_started": _revealed, "reveal": _pose.get("reveal", 0.0),
		"shape": "fitted_energy_sweep", "ring_count": 1,
		"visible_ring_count": int(_active and float(_pose.get("band_energy", 0.0)) > 0.01),
		"material_count": 2, "material_instance_ids": [_body_material.get_instance_id(), _contact_material.get_instance_id()] if _body_material != null else [],
		"child_count": get_child_count(), "base_sprite_visible": is_instance_valid(_source) and _source.visible}

func _ensure_nodes() -> void:
	if _body != null:
		return
	for path in ["../../CoreEnergyLayer", "../../CoreGlowLayer"]:
		var layer := get_node_or_null(path) as CanvasItem
		if layer != null:
			_core_layers.append(layer)
	_body_material = ShaderMaterial.new()
	_body_material.shader = BODY_SHADER
	_contact_material = ShaderMaterial.new()
	_contact_material.shader = CONTACT_SHADER
	_contact = Polygon2D.new()
	_contact.name = "ContactEnergy"
	_contact.z_index = -24
	_contact.material = _contact_material
	_contact.visible = false
	add_child(_contact)
	_body = Polygon2D.new()
	_body.name = "TransformSurface"
	_body.z_index = -11
	_body.material = _body_material
	_body.visible = false
	add_child(_body)
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "GrowthSfxPlayer"
	_audio_player.volume_db = -5.0
	if ResourceLoader.exists(GROWTH_SOUND_PATH):
		_audio_player.stream = load(GROWTH_SOUND_PATH) as AudioStream
	add_child(_audio_player)

func _set_quad(quad: Polygon2D, mat: ShaderMaterial, rect: Rect2) -> void:
	quad.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	mat.set_shader_parameter("quad_origin", rect.position)
	mat.set_shader_parameter("quad_size", rect.size)
