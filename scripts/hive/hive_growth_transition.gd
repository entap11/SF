class_name HiveGrowthTransition
extends Node2D

signal transition_started(old_tier: int, new_tier: int)
# Fires once when the final ring launches from the lower hive and begins the
# bottom-to-top old-proxy crop. Presentation-owned tier adornments commit here.
signal final_ring_reveal_started(new_tier: int)
signal transition_finished(new_tier: int)
signal transition_cancelled(reason: String)

const SFLog := preload("res://scripts/util/sf_log.gd")
const RING_SHADER := preload("res://shaders/hive_growth_ring.gdshader")

const GROWTH_SOUND_PATH: String = "res://assets/sprites/sf_skin_v1/sf_sounds/hive_growth.ogg"
const MAX_RING_COUNT: int = 3
const PRECHARGE_SEC: float = 0.080
const RING_STAGGER_SEC: float = 0.105
const RING_LIFETIME_SEC: float = 0.250
const SETTLE_SEC: float = 0.160
const REDUCED_RING_SEC: float = 0.145
const RING_START_WIDTH_SCALE: float = 0.98
const RING_END_WIDTH_SCALE: float = 1.12
const RING_FOOTPRINT_WIDTH_SCALE: float = 1.38
const RING_FOOTPRINT_HEIGHT_SCALE: float = 0.52
const RING_MIN_HEIGHT_PX: float = 40.0
const RING_MAX_HEIGHT_PX: float = 68.0
const RING_VERTICAL_PAD_PX: float = 3.0
const RING_SHADER_RADIUS: float = 0.72
const RING_SHADER_CORE_OUTER: float = 0.080
const RING_CORE_LINE_WIDTH_PX: float = 2.60
const RING_CORE_ARC_SEGMENTS: int = 24
const RING_REAR_INTENSITY: float = 0.82
const RING_FRONT_INTENSITY: float = 1.00
const FINAL_RING_INTENSITY_MULTIPLIER: float = 1.15
const PORT_CONFIRM_SEC: float = 0.240

var _old_sprite: Sprite2D = null
var _ring_slots: Array[Dictionary] = []
var _ring_tweens: Array[Tween] = []
var _timeline_tween: Tween = null
var _port_tween: Tween = null
var _audio_player: AudioStreamPlayer = null
var _captured_old_size: Vector2 = Vector2.ZERO
var _old_source_rect: Rect2 = Rect2()
var _old_source_offset: Vector2 = Vector2.ZERO
var _old_source_centered: bool = true
var _ring_start_y: float = 0.0
var _ring_end_y: float = 0.0
var _ring_width: float = 80.0
var _ring_height: float = 20.0
var _configured_bounds: Vector2 = Vector2.ZERO
var _active: bool = false
var _mode: String = "none"
var _old_tier: int = 0
var _new_tier: int = 0
var _ring_count: int = 0
var _final_ring_index: int = -1
var _reveal_event_emitted: bool = false
var _pending_port_entry: Dictionary = {}
var _port_outline: Line2D = null
var _port_fill: Polygon2D = null
var _port_outline_width: float = 1.0
var _port_outline_modulate: Color = Color.WHITE
var _port_fill_scale: Vector2 = Vector2.ONE
var _port_fill_modulate: Color = Color.WHITE

func _ready() -> void:
	_ensure_nodes()
	reset_visuals()

func capture_old_sprite(source: Sprite2D, old_size: Vector2) -> bool:
	_ensure_nodes()
	cancel_and_reveal_final("replaced", false)
	if source == null or not is_instance_valid(source) or source.texture == null:
		_old_sprite.visible = false
		_captured_old_size = Vector2.ZERO
		return false
	_old_sprite.texture = source.texture
	_old_sprite.centered = source.centered
	_old_sprite.flip_h = source.flip_h
	_old_sprite.flip_v = source.flip_v
	_old_sprite.material = source.material
	_old_sprite.modulate = source.modulate
	_old_sprite.self_modulate = source.self_modulate
	_old_sprite.global_transform = source.global_transform
	_old_source_centered = source.centered
	_old_source_offset = source.offset
	_old_source_rect = source.region_rect if source.region_enabled else Rect2(Vector2.ZERO, source.texture.get_size())
	if _old_source_rect.size.x <= 0.0 or _old_source_rect.size.y <= 0.0:
		_old_source_rect = Rect2(Vector2.ZERO, source.texture.get_size())
	_old_sprite.offset = _old_source_offset
	_old_sprite.region_enabled = true
	_old_sprite.region_rect = _old_source_rect
	_old_sprite.visible = true
	_captured_old_size = old_size
	return true

func play(
	final_size: Vector2,
	center: Vector2,
	owner_color: Color,
	old_tier: int,
	new_tier: int,
	port_entry: Dictionary = {},
	mode: String = "full"
) -> void:
	_ensure_nodes()
	_kill_tweens()
	_old_tier = old_tier
	_new_tier = new_tier
	_mode = mode
	_active = true
	_reveal_event_emitted = false
	_pending_port_entry = port_entry.duplicate()
	_ring_count = 1 if mode == "reduced" else clampi(new_tier, 2, MAX_RING_COUNT)
	_final_ring_index = _ring_count - 1
	var bounds := Vector2(
		maxf(_captured_old_size.x, final_size.x),
		maxf(_captured_old_size.y, final_size.y)
	)
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		bounds = Vector2(86.0, 112.0)
	_configure_geometry(bounds, center)
	_configure_colors(owner_color)
	_set_old_reveal_progress(0.0)
	transition_started.emit(old_tier, new_tier)
	SFLog.info("HIVE_GROWTH_FX_START", {
		"hive_id": _hive_id(),
		"old_tier": old_tier,
		"new_tier": new_tier,
		"ring_count": _ring_count,
		"mode": mode,
		"shape": "wrapped_energy_rings"
	})
	if mode == "reduced":
		_play_reduced()
	else:
		_play_full()

func cancel_and_reveal_final(reason: String = "cancelled", emit_event: bool = true) -> void:
	var was_active: bool = _active
	_kill_tweens()
	_restore_port()
	if _audio_player != null:
		_audio_player.stop()
	reset_visuals()
	_active = false
	if was_active and emit_event:
		transition_cancelled.emit(reason)
		SFLog.info("HIVE_GROWTH_FX_CANCEL", {
			"hive_id": _hive_id(),
			"tier": _new_tier,
			"reason": reason
		})

func reset_visuals() -> void:
	if _old_sprite != null:
		_old_sprite.visible = false
		_old_sprite.texture = null
		_old_sprite.region_enabled = false
		_old_sprite.offset = Vector2.ZERO
	for slot in _ring_slots:
		var root: Node2D = slot.get("root", null) as Node2D
		if root != null:
			root.visible = false
			root.modulate = Color.WHITE
			root.scale = Vector2.ONE
	_captured_old_size = Vector2.ZERO
	_pending_port_entry.clear()

func is_active() -> bool:
	return _active

func get_debug_snapshot() -> Dictionary:
	var visible_rings: int = 0
	var material_instance_ids: Array[int] = []
	for slot in _ring_slots:
		var root: Node2D = slot.get("root", null) as Node2D
		if root != null and root.visible:
			visible_rings += 1
		for key in ["rear_material", "front_material"]:
			var ring_material: ShaderMaterial = slot.get(key, null) as ShaderMaterial
			if ring_material != null:
				material_instance_ids.append(ring_material.get_instance_id())
	return {
		"active": _active,
		"old_tier": _old_tier,
		"new_tier": _new_tier,
		"ring_count": _ring_count,
		"visible_ring_count": visible_rings,
		"final_ring_index": _final_ring_index,
		"reveal_started": _reveal_event_emitted,
		"old_proxy_visible": _old_sprite != null and _old_sprite.visible,
		"ring_width": _ring_width,
		"ring_height": _ring_height,
		"configured_bounds": _configured_bounds,
		"bright_outer_width_ratio": (
			(_ring_width * (RING_SHADER_RADIUS + RING_SHADER_CORE_OUTER))
			/ _configured_bounds.x
			if _configured_bounds.x > 0.0
			else 0.0
		),
		"core_line_width": RING_CORE_LINE_WIDTH_PX,
		"rear_intensity": RING_REAR_INTENSITY,
		"front_intensity": RING_FRONT_INTENSITY,
		"final_ring_intensity_multiplier": FINAL_RING_INTENSITY_MULTIPLIER,
		"rear_z_index": -22,
		"front_z_index": -7,
		"material_instance_ids": material_instance_ids,
		"material_count": material_instance_ids.size(),
		"child_count": get_child_count()
	}

func set_debug_ring_phase(index: int, progress: float) -> void:
	if index < 0 or index >= _ring_slots.size():
		return
	_kill_tweens()
	for slot in _ring_slots:
		var slot_root: Node2D = slot.get("root", null) as Node2D
		if slot_root != null:
			slot_root.visible = false
	var root: Node2D = (_ring_slots[index] as Dictionary).get("root", null) as Node2D
	if root == null:
		return
	root.visible = true
	_set_ring_progress(clampf(progress, 0.0, 0.999), index)

func confirm_port_entry(port_entry: Dictionary) -> void:
	_capture_port_entry(port_entry)
	_play_port_confirmation()

func _play_full() -> void:
	for i in range(_ring_count):
		var delay: float = PRECHARGE_SEC + (float(i) * RING_STAGGER_SEC)
		_launch_ring_tween(i, delay, RING_LIFETIME_SEC)
	var total: float = PRECHARGE_SEC + (float(_ring_count - 1) * RING_STAGGER_SEC) + RING_LIFETIME_SEC + SETTLE_SEC
	_timeline_tween = create_tween()
	_timeline_tween.tween_interval(total)
	_timeline_tween.tween_callback(_finish)

func _play_reduced() -> void:
	_launch_ring_tween(0, 0.0, REDUCED_RING_SEC)
	_timeline_tween = create_tween()
	_timeline_tween.tween_interval(REDUCED_RING_SEC)
	_timeline_tween.tween_callback(_finish)

func _launch_ring_tween(index: int, delay: float, lifetime: float) -> void:
	if index < 0 or index >= _ring_slots.size():
		return
	var root: Node2D = (_ring_slots[index] as Dictionary).get("root", null) as Node2D
	if root == null:
		return
	root.visible = false
	root.position = Vector2(root.position.x, _ring_start_y)
	root.scale = Vector2(RING_START_WIDTH_SCALE, 1.0)
	root.modulate.a = 0.0
	var tween: Tween = create_tween()
	_ring_tweens.append(tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(Callable(self, "_on_ring_launched").bind(index))
	tween.tween_method(Callable(self, "_set_ring_progress").bind(index), 0.0, 1.0, lifetime)
	tween.tween_callback(Callable(self, "_on_ring_finished").bind(index))

func _on_ring_launched(index: int) -> void:
	if not _active or index < 0 or index >= _ring_slots.size():
		return
	var root: Node2D = (_ring_slots[index] as Dictionary).get("root", null) as Node2D
	if root != null:
		root.visible = true
	if index == _final_ring_index:
		_begin_final_ring_reveal()

func _set_ring_progress(progress: float, index: int) -> void:
	if not _active or index < 0 or index >= _ring_slots.size():
		return
	var root: Node2D = (_ring_slots[index] as Dictionary).get("root", null) as Node2D
	if root == null:
		return
	var t: float = clampf(progress, 0.0, 1.0)
	var travel_t: float = smoothstep(0.0, 1.0, t)
	root.position.y = lerpf(_ring_start_y, _ring_end_y, travel_t)
	root.scale.x = lerpf(RING_START_WIDTH_SCALE, RING_END_WIDTH_SCALE, t)
	var fade_in: float = smoothstep(0.0, 0.10, t)
	var fade_out: float = 1.0 - smoothstep(0.66, 0.92, t)
	root.modulate.a = pow(maxf(0.0, fade_in * fade_out), 0.72)
	if index == _final_ring_index:
		_set_old_reveal_progress(smoothstep(0.02, 0.98, t))

func _on_ring_finished(index: int) -> void:
	if index < 0 or index >= _ring_slots.size():
		return
	var root: Node2D = (_ring_slots[index] as Dictionary).get("root", null) as Node2D
	if root != null:
		root.visible = false
	if index == _final_ring_index:
		_set_old_reveal_progress(1.0)

func _begin_final_ring_reveal() -> void:
	if not _active or _reveal_event_emitted:
		return
	_reveal_event_emitted = true
	_play_sound()
	if not _pending_port_entry.is_empty():
		confirm_port_entry(_pending_port_entry)
	final_ring_reveal_started.emit(_new_tier)

func _finish() -> void:
	if not _active:
		return
	_set_old_reveal_progress(1.0)
	_active = false
	for slot in _ring_slots:
		var root: Node2D = slot.get("root", null) as Node2D
		if root != null:
			root.visible = false
	_timeline_tween = null
	_ring_tweens.clear()
	transition_finished.emit(_new_tier)
	SFLog.info("HIVE_GROWTH_FX_END", {
		"hive_id": _hive_id(),
		"tier": _new_tier,
		"ring_count": _ring_count
	})

func _set_old_reveal_progress(progress: float) -> void:
	if _old_sprite == null or _old_sprite.texture == null:
		return
	var t: float = clampf(progress, 0.0, 1.0)
	if t >= 0.999:
		_old_sprite.visible = false
		return
	var visible_height: float = maxf(1.0, _old_source_rect.size.y * (1.0 - t))
	var cropped: Rect2 = _old_source_rect
	cropped.size.y = visible_height
	_old_sprite.region_enabled = true
	_old_sprite.region_rect = cropped
	if _old_source_centered:
		var removed_height: float = _old_source_rect.size.y - visible_height
		_old_sprite.offset = _old_source_offset + Vector2(0.0, -removed_height * 0.5)
	else:
		_old_sprite.offset = _old_source_offset
	_old_sprite.visible = true

func _configure_geometry(bounds: Vector2, center: Vector2) -> void:
	_configured_bounds = bounds
	_ring_width = maxf(48.0, bounds.x * RING_FOOTPRINT_WIDTH_SCALE)
	_ring_height = clampf(bounds.x * RING_FOOTPRINT_HEIGHT_SCALE, RING_MIN_HEIGHT_PX, RING_MAX_HEIGHT_PX)
	_ring_start_y = center.y + (bounds.y * 0.47) - RING_VERTICAL_PAD_PX
	_ring_end_y = center.y - (bounds.y * 0.47) + RING_VERTICAL_PAD_PX
	for slot in _ring_slots:
		var root: Node2D = slot.get("root", null) as Node2D
		var rear: Polygon2D = slot.get("rear", null) as Polygon2D
		var front: Polygon2D = slot.get("front", null) as Polygon2D
		var rear_core: Line2D = slot.get("rear_core", null) as Line2D
		var front_core: Line2D = slot.get("front_core", null) as Line2D
		if root != null:
			root.position.x = center.x
		_set_ring_quad(rear, _ring_width, _ring_height)
		_set_ring_quad(front, _ring_width, _ring_height)
		_set_ring_core_arc(rear_core, _ring_width, _ring_height, false)
		_set_ring_core_arc(front_core, _ring_width, _ring_height, true)

func _configure_colors(owner_color: Color) -> void:
	var shoulder := Color(1.0, 0.94, 0.76, 1.0)
	var fringe := owner_color.lerp(Color(1.0, 0.84, 0.48, 1.0), 0.78)
	fringe.a = 1.0
	for index in range(_ring_slots.size()):
		var slot: Dictionary = _ring_slots[index]
		var final_multiplier: float = (
			FINAL_RING_INTENSITY_MULTIPLIER if index == _final_ring_index else 1.0
		)
		for key in ["rear_material", "front_material"]:
			var material: ShaderMaterial = slot.get(key, null) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("shoulder_color", shoulder)
				material.set_shader_parameter("fringe_color", fringe)
				var arc_intensity: float = (
					RING_REAR_INTENSITY if key == "rear_material" else RING_FRONT_INTENSITY
				)
				material.set_shader_parameter("intensity", arc_intensity * final_multiplier)
		var rear_core: Line2D = slot.get("rear_core", null) as Line2D
		if rear_core != null:
			rear_core.default_color = Color(1.0, 0.965, 0.82, 0.62 * final_multiplier)
		var front_core: Line2D = slot.get("front_core", null) as Line2D
		if front_core != null:
			front_core.default_color = Color(1.0, 0.995, 0.96, minf(1.0, final_multiplier))

func _set_ring_quad(poly: Polygon2D, width: float, height: float) -> void:
	if poly == null:
		return
	var half := Vector2(width, height) * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	poly.uv = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])

func _set_ring_core_arc(line: Line2D, width: float, height: float, front: bool) -> void:
	if line == null:
		return
	var points := PackedVector2Array()
	var start_angle: float = 0.0 if front else PI
	var end_angle: float = PI if front else TAU
	var radius := Vector2(width, height) * 0.5 * RING_SHADER_RADIUS
	for i in range(RING_CORE_ARC_SEGMENTS + 1):
		var t: float = float(i) / float(RING_CORE_ARC_SEGMENTS)
		var angle: float = lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	line.points = points

func _capture_port_entry(port_entry: Dictionary) -> void:
	_restore_port()
	_port_outline = port_entry.get("outline", null) as Line2D
	_port_fill = port_entry.get("fill", null) as Polygon2D
	if _port_outline != null and is_instance_valid(_port_outline):
		_port_outline_width = _port_outline.width
		_port_outline_modulate = _port_outline.modulate
	if _port_fill != null and is_instance_valid(_port_fill):
		_port_fill_scale = _port_fill.scale
		_port_fill_modulate = _port_fill.modulate

func _play_port_confirmation() -> void:
	if _port_outline == null and _port_fill == null:
		return
	if _port_tween != null and _port_tween.is_valid():
		_port_tween.kill()
	_port_tween = create_tween()
	_port_tween.set_trans(Tween.TRANS_SINE)
	_port_tween.set_ease(Tween.EASE_OUT)
	if _port_outline != null and is_instance_valid(_port_outline):
		_port_outline.width = maxf(_port_outline_width, 3.0)
		_port_outline.modulate = Color.WHITE
		_port_outline.scale = Vector2.ONE * 1.42
		_port_tween.tween_property(_port_outline, "scale", Vector2.ONE, PORT_CONFIRM_SEC)
		_port_tween.parallel().tween_property(_port_outline, "modulate", _port_outline_modulate, PORT_CONFIRM_SEC)
	if _port_fill != null and is_instance_valid(_port_fill):
		_port_fill.modulate = Color.WHITE
		_port_fill.scale = _port_fill_scale * 1.32
		_port_tween.parallel().tween_property(_port_fill, "scale", _port_fill_scale, PORT_CONFIRM_SEC)
		_port_tween.parallel().tween_property(_port_fill, "modulate", _port_fill_modulate, PORT_CONFIRM_SEC)
	_port_tween.tween_callback(_restore_port)

func _restore_port() -> void:
	if _port_outline != null and is_instance_valid(_port_outline):
		_port_outline.width = _port_outline_width
		_port_outline.scale = Vector2.ONE
		_port_outline.modulate = _port_outline_modulate
	if _port_fill != null and is_instance_valid(_port_fill):
		_port_fill.scale = _port_fill_scale
		_port_fill.modulate = _port_fill_modulate
	_port_outline = null
	_port_fill = null
	_port_tween = null

func _play_sound() -> void:
	if _audio_player == null or _audio_player.stream == null or not _audio_allowed():
		return
	_audio_player.stop()
	_audio_player.play()

func _audio_allowed() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		return true
	if profile_manager.has_method("is_audio_enabled") and not bool(profile_manager.call("is_audio_enabled")):
		return false
	if profile_manager.has_method("is_sfx_enabled") and not bool(profile_manager.call("is_sfx_enabled")):
		return false
	return true

func _kill_tweens() -> void:
	if _timeline_tween != null and _timeline_tween.is_valid():
		_timeline_tween.kill()
	_timeline_tween = null
	for tween in _ring_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_ring_tweens.clear()
	if _port_tween != null and _port_tween.is_valid():
		_port_tween.kill()
	_port_tween = null

func _ensure_nodes() -> void:
	if _old_sprite == null:
		_old_sprite = Sprite2D.new()
		_old_sprite.name = "OldSpriteProxy"
		_old_sprite.z_index = -18
		add_child(_old_sprite)
	while _ring_slots.size() < MAX_RING_COUNT:
		var index: int = _ring_slots.size()
		var root := Node2D.new()
		root.name = "EnergyRing_%d" % index
		add_child(root)
		var rear_material := ShaderMaterial.new()
		rear_material.shader = RING_SHADER
		rear_material.set_shader_parameter("front_arc", false)
		rear_material.set_shader_parameter("intensity", RING_REAR_INTENSITY)
		var rear := Polygon2D.new()
		rear.name = "RearArc"
		rear.z_index = -22
		rear.material = rear_material
		root.add_child(rear)
		var rear_core := Line2D.new()
		rear_core.name = "RearCore"
		rear_core.z_index = -21
		rear_core.width = RING_CORE_LINE_WIDTH_PX
		rear_core.default_color = Color(1.0, 0.965, 0.82, 0.54)
		rear_core.antialiased = true
		root.add_child(rear_core)
		var front_material := ShaderMaterial.new()
		front_material.shader = RING_SHADER
		front_material.set_shader_parameter("front_arc", true)
		front_material.set_shader_parameter("intensity", RING_FRONT_INTENSITY)
		var front := Polygon2D.new()
		front.name = "FrontArc"
		front.z_index = -7
		front.material = front_material
		root.add_child(front)
		var front_core := Line2D.new()
		front_core.name = "FrontCore"
		front_core.z_index = -6
		front_core.width = RING_CORE_LINE_WIDTH_PX
		front_core.default_color = Color(1.0, 0.995, 0.96, 1.0)
		front_core.antialiased = true
		root.add_child(front_core)
		_ring_slots.append({
			"root": root,
			"rear": rear,
			"front": front,
			"rear_core": rear_core,
			"front_core": front_core,
			"rear_material": rear_material,
			"front_material": front_material
		})
	if _audio_player == null:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "GrowthSfxPlayer"
		_audio_player.bus = &"Master"
		_audio_player.volume_db = -5.0
		if ResourceLoader.exists(GROWTH_SOUND_PATH):
			_audio_player.stream = load(GROWTH_SOUND_PATH) as AudioStream
		add_child(_audio_player)

func _hive_id() -> int:
	var visual: Node = get_parent().get_parent() if get_parent() != null else null
	var hive_node: Node = visual.get_parent() if visual != null else null
	if hive_node != null:
		var value: Variant = hive_node.get("hive_id")
		if value != null:
			return int(value)
	return -1
