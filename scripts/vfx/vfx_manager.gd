class_name VfxManager
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")

const DEBUG_VFX := false
const Z_INDEX_VFX := 20
const TRACER_WIDTH := 2.0
const TRACER_LIFE := 0.2
const SPIKE_TEX := preload("res://assets/sprites/sf_skin_v1/tower_spike.PNG")
const COLLISION_VFX_SCENE: PackedScene = preload("res://scenes/vfx/collision_vfx.tscn")
const IMPACT_FLASH_SCENE: PackedScene = preload("res://scenes/vfx/vfx_impact_flash.tscn")
const SPIKE_SIZE_PX := 20.0
const SPIKE_LIFE := 0.18
const SPIKE_ROTATION_OFFSET := -PI * 0.5
const HIT_RING_RADIUS := 10.0
const HIT_RING_LIFE := 0.25
const UPGRADE_RING_RADIUS := 22.0
const UPGRADE_RING_LIFE := 0.45
const RING_SEGMENTS := 24
const USE_VFX_POOL: bool = false
const VFX_POOL_COLLISION: int = 16
const VFX_POOL_IMPACT: int = 32
const VFX_OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)
const DISABLE_VFX: bool = false

var _sim_events: Node = null
var _prewarmed: bool = false
var _pool_collision: Array[Node2D] = []
var _pool_impact: Array[Node2D] = []

func _ready() -> void:
	z_index = Z_INDEX_VFX
	_vfx_pool_build()
	_try_bind()

func prewarm() -> void:
	if _prewarmed:
		return
	_prewarmed = true
	_vfx_pool_build()
	call_deferred("_prewarm_vfx_nodes")

func _prewarm_vfx_nodes() -> void:
	if not USE_VFX_POOL:
		return
	var impact_node: Node2D = _acquire_impact_node()
	if impact_node != null and impact_node.has_method("play"):
		impact_node.call(
			"play",
			VFX_OFFSCREEN_POS,
			0.0,
			Color(1.0, 1.0, 1.0, 1.0),
			0.2
		)
	var collision_node: Node2D = _acquire_collision_node()
	if collision_node != null and collision_node.has_method("play"):
		collision_node.call(
			"play",
			VFX_OFFSCREEN_POS,
			Vector2.RIGHT,
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 1.0),
			0.2
		)

func _vfx_pool_build() -> void:
	if not USE_VFX_POOL:
		return
	if not _pool_collision.is_empty() or not _pool_impact.is_empty():
		return
	for i in range(VFX_POOL_IMPACT):
		var impact_node: Node2D = _create_impact_node(i)
		if impact_node == null:
			continue
		add_child(impact_node)
		_release_impact_node(impact_node)
	for i in range(VFX_POOL_COLLISION):
		var collision_node: Node2D = _create_collision_node(i)
		if collision_node == null:
			continue
		add_child(collision_node)
		_release_collision_node(collision_node)

func _create_impact_node(pool_index: int) -> Node2D:
	if IMPACT_FLASH_SCENE == null:
		return null
	var node_any: Node = IMPACT_FLASH_SCENE.instantiate()
	var node: Node2D = node_any as Node2D
	if node == null:
		if node_any != null:
			node_any.queue_free()
		return null
	node.name = "ImpactPool_%d" % pool_index
	_prepare_vfx_node(node)
	if node.has_method("set_release_callback"):
		node.call("set_release_callback", Callable(self, "_release_impact_node"))
	return node

func _create_collision_node(pool_index: int) -> Node2D:
	if COLLISION_VFX_SCENE == null:
		return null
	var node_any: Node = COLLISION_VFX_SCENE.instantiate()
	var node: Node2D = node_any as Node2D
	if node == null:
		if node_any != null:
			node_any.queue_free()
		return null
	node.name = "CollisionPool_%d" % pool_index
	_prepare_vfx_node(node)
	if node.has_method("set_release_callback"):
		node.call("set_release_callback", Callable(self, "_release_collision_node"))
	return node

func _prepare_vfx_node(node: Node2D) -> void:
	if node == null:
		return
	node.visible = false
	node.position = VFX_OFFSCREEN_POS
	node.rotation = 0.0
	node.scale = Vector2.ONE
	node.process_mode = Node.PROCESS_MODE_DISABLED
	var sparks: GPUParticles2D = node.get_node_or_null("Sparks") as GPUParticles2D
	if sparks != null:
		sparks.emitting = false
	var light: PointLight2D = node.get_node_or_null("Light") as PointLight2D
	if light != null:
		light.enabled = false

func _acquire_impact_node() -> Node2D:
	if not USE_VFX_POOL:
		var direct_node: Node2D = _create_impact_node(-1)
		if direct_node != null:
			add_child(direct_node)
			direct_node.visible = true
			direct_node.process_mode = Node.PROCESS_MODE_INHERIT
		return direct_node
	_vfx_pool_build()
	if _pool_impact.is_empty():
		var extra_node: Node2D = _create_impact_node(-1)
		if extra_node != null:
			add_child(extra_node)
			_release_impact_node(extra_node)
	if _pool_impact.is_empty():
		return null
	var node: Node2D = _pool_impact.pop_back()
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	return node

func _acquire_collision_node() -> Node2D:
	if not USE_VFX_POOL:
		var direct_node: Node2D = _create_collision_node(-1)
		if direct_node != null:
			add_child(direct_node)
			direct_node.visible = true
			direct_node.process_mode = Node.PROCESS_MODE_INHERIT
		return direct_node
	_vfx_pool_build()
	if _pool_collision.is_empty():
		var extra_node: Node2D = _create_collision_node(-1)
		if extra_node != null:
			add_child(extra_node)
			_release_collision_node(extra_node)
	if _pool_collision.is_empty():
		return null
	var node: Node2D = _pool_collision.pop_back()
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	return node

func _release_impact_node(node: Node2D) -> void:
	if node == null:
		return
	if node.has_method("reset_for_pool") and node.is_node_ready():
		node.call("reset_for_pool")
	else:
		_prepare_vfx_node(node)
	if USE_VFX_POOL:
		if not _pool_impact.has(node):
			_pool_impact.append(node)
	else:
		node.queue_free()

func _release_collision_node(node: Node2D) -> void:
	if node == null:
		return
	if node.has_method("reset_for_pool") and node.is_node_ready():
		node.call("reset_for_pool")
	else:
		_prepare_vfx_node(node)
	if USE_VFX_POOL:
		if not _pool_collision.has(node):
			_pool_collision.append(node)
	else:
		node.queue_free()

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
	if DISABLE_VFX:
		return
	if _sim_events == null:
		return
	if not _sim_events.is_connected("tower_fire", Callable(self, "_on_tower_fire")):
		_sim_events.connect("tower_fire", Callable(self, "_on_tower_fire"))
	if not _sim_events.is_connected("tower_hit", Callable(self, "_on_tower_hit")):
		_sim_events.connect("tower_hit", Callable(self, "_on_tower_hit"))
	if not _sim_events.is_connected("unit_collision", Callable(self, "_on_unit_collision")):
		_sim_events.connect("unit_collision", Callable(self, "_on_unit_collision"))
	if not _sim_events.is_connected("unit_impact", Callable(self, "_on_unit_impact")):
		_sim_events.connect("unit_impact", Callable(self, "_on_unit_impact"))
	if not _sim_events.is_connected("hive_kind_changed", Callable(self, "_on_hive_kind_changed")):
		_sim_events.connect("hive_kind_changed", Callable(self, "_on_hive_kind_changed"))

func _on_tower_fire(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, target_pos: Vector2) -> void:
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_FIRE", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id,
			"tower_pos": tower_pos,
			"target_pos": target_pos
		})
	_spawn_tracer(tower_pos, target_pos, owner_id)

func _on_tower_hit(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, hit_pos: Vector2) -> void:
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_HIT", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id,
			"tower_pos": tower_pos,
			"hit_pos": hit_pos
		})
	_spawn_spike(tower_pos, hit_pos)
	_spawn_ring(hit_pos, HIT_RING_RADIUS, _owner_color(owner_id), HIT_RING_LIFE)

func _on_unit_collision(world_pos: Vector2, lane_dir: Vector2, owner_a: int, owner_b: int, lane_id: int, intensity: float) -> void:
	_spawn_collision_vfx(world_pos, lane_dir, owner_a, owner_b, intensity, lane_id)
# TODO: Reuse CollisionVfx for hive impact events (enemy/friendly) when those render events are wired.

func _on_unit_impact(
	kind: String,
	world_pos: Vector2,
	lane_dir: Vector2,
	owner_id: int,
	intensity: float,
	lane_id: int,
	unit_id: int,
	hive_id: int
) -> void:
	var map_root: Node2D = get_parent() as Node2D
	var rot_rad: float = 0.0
	if lane_dir.length_squared() > 0.000001:
		rot_rad = lane_dir.angle()
	spawn_impact_flash(
		map_root,
		world_pos,
		rot_rad,
		_owner_color(owner_id),
		intensity,
		kind,
		lane_id,
		unit_id,
		hive_id
	)

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

func _spawn_collision_vfx(
	world_pos: Vector2,
	dir: Vector2,
	owner_a: int,
	owner_b: int,
	intensity: float = 1.0,
	_lane_id: int = -1
) -> void:
	var node: Node2D = _acquire_collision_node()
	if node == null:
		return
	var c1: Color = _owner_color(owner_a)
	var c2: Color = _owner_color(owner_b)
	var axis: Vector2 = dir.normalized() if dir.length_squared() > 0.000001 else Vector2.RIGHT
	node.z_index = Z_INDEX_VFX
	if node.has_method("play"):
		node.call("play", world_pos, axis, c1, c2, intensity)
		return
	_release_collision_node(node)

func spawn_impact_flash(
	_map_root: Node2D,
	pos_map_local: Vector2,
	rot_rad: float,
	color: Color = Color(1.0, 1.0, 1.0, 1.0),
	intensity: float = 1.0,
	_kind: String = "",
	_lane_id: int = -1,
	_unit_id: int = -1,
	_hive_id: int = -1
) -> void:
	var node: Node2D = _acquire_impact_node()
	if node == null:
		return
	node.z_index = 999
	if node.has_method("play"):
		node.call("play", pos_map_local, rot_rad, color, intensity)
		return
	_release_impact_node(node)

func spawn_impact(kind: String, world_pos: Vector2, color: Color, intensity: float, dir: Vector2 = Vector2.ZERO) -> void:
	var map_root: Node2D = get_parent() as Node2D
	var rot_rad: float = 0.0
	if dir.length_squared() > 0.000001:
		rot_rad = dir.angle()
	spawn_impact_flash(map_root, world_pos, rot_rad, color, intensity, kind)

func _ring_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(RING_SEGMENTS + 1):
		var t := float(i) / float(RING_SEGMENTS) * TAU
		pts.append(Vector2(cos(t), sin(t)) * radius)
	return pts
