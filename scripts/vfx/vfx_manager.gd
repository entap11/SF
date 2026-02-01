class_name VfxManager
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")

const DEBUG_VFX := true
const Z_INDEX_VFX := 20
const TRACER_WIDTH := 2.0
const TRACER_LIFE := 0.2
const SPIKE_TEX := preload("res://assets/sprites/sf_skin_v1/tower_spike.PNG")
const SPIKE_SIZE_PX := 20.0
const SPIKE_LIFE := 0.18
const SPIKE_ROTATION_OFFSET := -PI * 0.5
const HIT_RING_RADIUS := 10.0
const HIT_RING_LIFE := 0.25
const UPGRADE_RING_RADIUS := 22.0
const UPGRADE_RING_LIFE := 0.45
const RING_SEGMENTS := 24

var _sim_events: Node = null

func _ready() -> void:
	z_index = Z_INDEX_VFX
	_try_bind()

func set_sim_events(sim_events: Node) -> void:
	_sim_events = sim_events
	_bind_sim_events()

func _try_bind() -> void:
	if _sim_events == null:
		var tree := get_tree()
		if tree != null:
			_sim_events = tree.get_first_node_in_group("sim_events")
	_bind_sim_events()

func _bind_sim_events() -> void:
	if _sim_events == null:
		return
	if not _sim_events.is_connected("tower_fire", Callable(self, "_on_tower_fire")):
		_sim_events.connect("tower_fire", Callable(self, "_on_tower_fire"))
	if not _sim_events.is_connected("tower_hit", Callable(self, "_on_tower_hit")):
		_sim_events.connect("tower_hit", Callable(self, "_on_tower_hit"))
	if not _sim_events.is_connected("hive_kind_changed", Callable(self, "_on_hive_kind_changed")):
		_sim_events.connect("hive_kind_changed", Callable(self, "_on_hive_kind_changed"))

func _on_tower_fire(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, target_pos: Vector2) -> void:
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_FIRE", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id
		})
	_spawn_tracer(tower_pos, target_pos, owner_id)

func _on_tower_hit(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, hit_pos: Vector2) -> void:
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_HIT", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id
		})
	_spawn_spike(tower_pos, hit_pos)
	_spawn_ring(hit_pos, HIT_RING_RADIUS, _owner_color(owner_id), HIT_RING_LIFE)

func _on_hive_kind_changed(hive_id: int, owner_id: int, world_pos: Vector2, prev_kind: String, next_kind: String) -> void:
	if DEBUG_VFX:
		SFLog.info("VFX_HIVE_UPGRADE", {
			"hive_id": hive_id,
			"owner_id": owner_id,
			"prev_kind": prev_kind,
			"next_kind": next_kind
		})
	_spawn_ring(world_pos, UPGRADE_RING_RADIUS, _owner_color(owner_id), UPGRADE_RING_LIFE)

func _owner_color(owner_id: int) -> Color:
	return HiveRenderer._owner_color(owner_id)

func _spawn_tracer(from_pos: Vector2, to_pos: Vector2, owner_id: int) -> void:
	var line := Line2D.new()
	line.width = TRACER_WIDTH
	line.default_color = _owner_color(owner_id)
	line.points = PackedVector2Array([from_pos, to_pos])
	line.z_index = Z_INDEX_VFX
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, TRACER_LIFE)
	tween.parallel().tween_property(line, "width", 0.0, TRACER_LIFE)
	tween.tween_callback(Callable(line, "queue_free"))

func _spawn_spike(from_pos: Vector2, to_pos: Vector2) -> void:
	var tex: Texture2D = SPIKE_TEX
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.z_index = Z_INDEX_VFX
	sprite.position = from_pos
	var dir := to_pos - from_pos
	if dir.length_squared() > 0.0001:
		sprite.rotation = dir.angle() + SPIKE_ROTATION_OFFSET
	var size := tex.get_size()
	var max_dim := maxf(size.x, size.y)
	if max_dim > 0.0:
		var scale := SPIKE_SIZE_PX / max_dim
		sprite.scale = Vector2.ONE * scale
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position", to_pos, SPIKE_LIFE)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, SPIKE_LIFE)
	tween.tween_callback(Callable(sprite, "queue_free"))

func _spawn_ring(pos: Vector2, radius: float, color: Color, life: float) -> void:
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = color
	line.points = _ring_points(radius)
	line.position = pos
	line.z_index = Z_INDEX_VFX
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, life)
	tween.parallel().tween_property(line, "scale", Vector2.ONE * 1.4, life)
	tween.tween_callback(Callable(line, "queue_free"))

func _ring_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(RING_SEGMENTS + 1):
		var t := float(i) / float(RING_SEGMENTS) * TAU
		pts.append(Vector2(cos(t), sin(t)) * radius)
	return pts
