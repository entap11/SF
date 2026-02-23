class_name VfxManager
extends Node2D

const SFLog := preload("res://scripts/util/sf_log.gd")
const HiveRenderer := preload("res://scripts/renderers/hive_renderer.gd")
const SimTuning := preload("res://scripts/sim/sim_tuning.gd")
const IonPopScene: PackedScene = preload("res://scenes/vfx/ion_pop.tscn")

const DEBUG_VFX := false
const Z_INDEX_VFX := 20
const TRACER_WIDTH := 2.0
const TRACER_LIFE := 0.2
const SPIKE_TEX: Texture2D = preload("res://assets/sprites/sf_skin_v1/tower_spike.PNG")
const COLLISION_VFX_SCENE: PackedScene = preload("res://scenes/vfx/collision_vfx.tscn")
const IMPACT_FLASH_SCENE: PackedScene = preload("res://scenes/vfx/vfx_impact_flash.tscn")
const SPIKE_LIFE: float = float(SimTuning.TOWER_PROJECTILE_TRAVEL_SEC)
const SPIKE_ROTATION_OFFSET: float = 0.0
const SPIKE_LEN_T1_PX: float = 68.0
const SPIKE_LEN_T2_PX: float = 86.0
const SPIKE_LEN_T3_PLUS_PX: float = 104.0
const HIT_RING_RADIUS := 10.0
const HIT_RING_LIFE := 0.25
const UPGRADE_RING_RADIUS := 22.0
const UPGRADE_RING_LIFE := 0.45
const RING_SEGMENTS := 24
const IMPACT_IONIZE_LINE_LIFE := 0.12
const IMPACT_IONIZE_LEN_MIN := 10.0
const IMPACT_IONIZE_LEN_MAX := 22.0
const USE_VFX_POOL: bool = true
const VFX_POOL_COLLISION: int = 16
const VFX_POOL_IMPACT: int = 32
const VFX_OFFSCREEN_POS: Vector2 = Vector2(-99999.0, -99999.0)
const DISABLE_VFX: bool = false
const IONPOP_MAX_ACTIVE: int = 24
const IONPOP_PRELOAD_COUNT: int = 32
const IONPOP_COLLISION_HALF_LEN_PX: float = 10.0
const HIVE_IONPOP_THROTTLE_MS: int = 150
const AUTO_GPU_VFX_DISABLE_ENABLED: bool = true
const AUTO_GPU_VFX_DISABLE_FPS: float = 24.0
const AUTO_GPU_VFX_DISABLE_WINDOW_SEC: float = 6.0

var _sim_events: Node = null
var _prewarmed: bool = false
var _pool_collision: Array[Node2D] = []
var _pool_impact: Array[Node2D] = []
var _ion_pop_pool: VfxPool = null
var _last_hive_ionpop_ms: Dictionary = {}
var _gpu_vfx_enabled: bool = true
var _auto_gpu_vfx_disable_enabled: bool = AUTO_GPU_VFX_DISABLE_ENABLED
var _auto_gpu_vfx_disable_accum_sec: float = 0.0
var _auto_gpu_vfx_disable_triggered: bool = false

func _ready() -> void:
	z_index = Z_INDEX_VFX
	_sync_gpu_vfx_pref()
	_vfx_pool_build()
	_ensure_ion_pop_pool()
	_try_bind()

func _process(delta: float) -> void:
	if not _vfx_enabled():
		return
	if not _auto_gpu_vfx_disable_enabled:
		return
	if _auto_gpu_vfx_disable_triggered:
		return
	var fps: float = float(Engine.get_frames_per_second())
	if fps <= 0.0:
		return
	if fps < AUTO_GPU_VFX_DISABLE_FPS:
		_auto_gpu_vfx_disable_accum_sec += delta
	else:
		_auto_gpu_vfx_disable_accum_sec = maxf(0.0, _auto_gpu_vfx_disable_accum_sec - delta)
	if _auto_gpu_vfx_disable_accum_sec < AUTO_GPU_VFX_DISABLE_WINDOW_SEC:
		return
	_auto_gpu_vfx_disable_triggered = true
	set_gpu_vfx_enabled(false)
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("set_gpu_vfx_enabled"):
		profile_manager.call("set_gpu_vfx_enabled", false)
	SFLog.warn("GPU_VFX_AUTO_DISABLED", {
		"reason": "low_fps_window",
		"fps_threshold": AUTO_GPU_VFX_DISABLE_FPS,
		"window_sec": AUTO_GPU_VFX_DISABLE_WINDOW_SEC,
		"fps_now": fps
	})

func prewarm() -> void:
	if _prewarmed:
		return
	if not _vfx_enabled():
		return
	_prewarmed = true
	_vfx_pool_build()
	_ensure_ion_pop_pool()
	call_deferred("_prewarm_vfx_nodes")

func _prewarm_vfx_nodes() -> void:
	if not _vfx_enabled():
		return
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
	if not _vfx_enabled():
		return null
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
	if not _vfx_enabled():
		return null
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

func _vfx_enabled() -> bool:
	return not DISABLE_VFX and _gpu_vfx_enabled

func _sync_gpu_vfx_pref() -> void:
	var env_disable_auto: String = OS.get_environment("SF_DISABLE_GPU_VFX_AUTO_FALLBACK").strip_edges().to_lower()
	_auto_gpu_vfx_disable_enabled = not (env_disable_auto == "1" or env_disable_auto == "true" or env_disable_auto == "yes")
	var env_disable: String = OS.get_environment("SF_DISABLE_GPU_VFX").strip_edges().to_lower()
	if env_disable == "1" or env_disable == "true" or env_disable == "yes":
		_gpu_vfx_enabled = false
		return
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager != null and profile_manager.has_method("is_gpu_vfx_enabled"):
		_gpu_vfx_enabled = bool(profile_manager.call("is_gpu_vfx_enabled"))

func set_gpu_vfx_enabled(enabled: bool) -> void:
	_gpu_vfx_enabled = enabled
	if enabled:
		_auto_gpu_vfx_disable_accum_sec = 0.0
		_auto_gpu_vfx_disable_triggered = false
	if _ion_pop_pool != null and _ion_pop_pool.has_method("set_enabled"):
		_ion_pop_pool.call("set_enabled", enabled)
	if not enabled:
		for node in _pool_collision:
			_prepare_vfx_node(node)
		for node in _pool_impact:
			_prepare_vfx_node(node)
	_last_hive_ionpop_ms.clear()

func _ensure_ion_pop_pool() -> void:
	if _ion_pop_pool != null and is_instance_valid(_ion_pop_pool):
		return
	var pool: VfxPool = VfxPool.new()
	pool.name = "IonPopPool"
	add_child(pool)
	_ion_pop_pool = pool
	if _ion_pop_pool.has_method("configure"):
		_ion_pop_pool.call("configure", IonPopScene, IONPOP_PRELOAD_COUNT, IONPOP_MAX_ACTIVE)
	if _ion_pop_pool.has_method("set_enabled"):
		_ion_pop_pool.call("set_enabled", _vfx_enabled())

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
	if not _sim_events.is_connected("unit_death", Callable(self, "_on_unit_death")):
		_sim_events.connect("unit_death", Callable(self, "_on_unit_death"))
	if not _sim_events.is_connected("hive_kind_changed", Callable(self, "_on_hive_kind_changed")):
		_sim_events.connect("hive_kind_changed", Callable(self, "_on_hive_kind_changed"))

func _on_tower_fire(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, target_pos: Vector2) -> void:
	if not _vfx_enabled():
		return
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_FIRE", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id,
			"tower_pos": tower_pos,
			"target_pos": target_pos
		})
	_spawn_spike(tower_pos, target_pos, tier)
	_spawn_tracer(tower_pos, target_pos, owner_id)

func _on_tower_hit(tower_id: int, owner_id: int, tier: int, tower_pos: Vector2, target_unit_id: int, hit_pos: Vector2) -> void:
	if not _vfx_enabled():
		return
	if DEBUG_VFX:
		SFLog.info("VFX_TOWER_HIT", {
			"tower_id": tower_id,
			"owner_id": owner_id,
			"tier": tier,
			"target_unit_id": target_unit_id,
			"tower_pos": tower_pos,
			"hit_pos": hit_pos
		})
	_spawn_ring(hit_pos, HIT_RING_RADIUS, _owner_color(owner_id), HIT_RING_LIFE)

func _on_unit_collision(world_pos: Vector2, lane_dir: Vector2, owner_a: int, owner_b: int, lane_id: int, intensity: float) -> void:
	if not _vfx_enabled():
		return
	_spawn_collision_vfx(world_pos, lane_dir, owner_a, owner_b, intensity, lane_id)
	_spawn_collision_ionpop(world_pos, lane_dir)
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
	if not _vfx_enabled():
		return
	var map_root: Node2D = get_parent() as Node2D
	var rot_rad: float = 0.0
	var lane_norm: Vector2 = Vector2.RIGHT
	if lane_dir.length_squared() > 0.000001:
		lane_norm = lane_dir.normalized()
		rot_rad = lane_norm.angle()
	var ionize_intensity: float = clampf(intensity, 0.5, 2.2)
	var ionize_len: float = lerpf(IMPACT_IONIZE_LEN_MIN, IMPACT_IONIZE_LEN_MAX, clampf(ionize_intensity / 2.2, 0.0, 1.0))
	var ionize_from: Vector2 = world_pos - lane_norm * ionize_len
	_spawn_ionize_line(ionize_from, world_pos, _owner_color(owner_id), ionize_intensity)
	_spawn_hive_ionpop(hive_id, ionize_from, world_pos)
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
	if kind == "attack":
		_spawn_ring(world_pos, 7.0, _owner_color(owner_id), 0.12)

func _on_unit_death(
	world_pos: Vector2,
	lane_dir: Vector2,
	owner_id: int,
	intensity: float,
	lane_id: int,
	unit_id: int,
	reason: String
) -> void:
	if not _vfx_enabled():
		return
	var map_root: Node2D = get_parent() as Node2D
	var rot_rad: float = 0.0
	if lane_dir.length_squared() > 0.000001:
		rot_rad = lane_dir.angle()
	var death_color: Color = _owner_color(owner_id).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.2)
	var death_intensity: float = clampf(intensity * 1.1, 0.7, 2.4)
	spawn_impact_flash(
		map_root,
		world_pos,
		rot_rad,
		death_color,
		death_intensity,
		reason,
		lane_id,
		unit_id,
		-1
	)
	_spawn_ring(world_pos, lerpf(6.0, 13.0, clampf(death_intensity / 2.4, 0.0, 1.0)), death_color, 0.16)

func _on_hive_kind_changed(hive_id: int, owner_id: int, world_pos: Vector2, prev_kind: String, next_kind: String) -> void:
	if not _vfx_enabled():
		return
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

func _spawn_ionize_line(from_pos: Vector2, to_pos: Vector2, owner_color: Color, intensity: float) -> void:
	var line := Line2D.new()
	line.width = lerpf(1.6, 3.0, clampf(intensity / 2.2, 0.0, 1.0))
	line.default_color = owner_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.45)
	line.points = PackedVector2Array([from_pos, to_pos])
	line.z_index = Z_INDEX_VFX + 1
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, IMPACT_IONIZE_LINE_LIFE)
	tween.parallel().tween_property(line, "width", 0.0, IMPACT_IONIZE_LINE_LIFE)
	tween.tween_callback(Callable(line, "queue_free"))

func _spawn_collision_ionpop(world_pos: Vector2, lane_dir: Vector2) -> void:
	if _ion_pop_pool == null:
		return
	var axis: Vector2 = lane_dir
	if axis.length_squared() <= 0.000001:
		axis = Vector2.RIGHT
	axis = axis.normalized()
	var from_pos: Vector2 = world_pos - (axis * IONPOP_COLLISION_HALF_LEN_PX)
	var to_pos: Vector2 = world_pos + (axis * IONPOP_COLLISION_HALF_LEN_PX)
	_ion_pop_pool.spawn_ionpop(from_pos, to_pos)

func _spawn_hive_ionpop(hive_id: int, from_pos: Vector2, hive_pos: Vector2) -> void:
	if _ion_pop_pool == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = int(_last_hive_ionpop_ms.get(hive_id, -HIVE_IONPOP_THROTTLE_MS))
	if now_ms - last_ms < HIVE_IONPOP_THROTTLE_MS:
		return
	_last_hive_ionpop_ms[hive_id] = now_ms
	_ion_pop_pool.spawn_ionpop(from_pos, hive_pos)

func _spawn_spike(from_pos: Vector2, to_pos: Vector2, tier: int) -> void:
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
	var size: Vector2 = tex.get_size()
	var width_px: float = maxf(1.0, size.x)
	var target_len_px: float = _spike_len_for_tier(tier)
	if width_px > 0.0:
		var scale: float = target_len_px / width_px
		sprite.scale = Vector2.ONE * scale
	add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "position", to_pos, SPIKE_LIFE)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, SPIKE_LIFE)
	tween.tween_callback(Callable(sprite, "queue_free"))

func _spike_len_for_tier(tier: int) -> float:
	if tier <= 1:
		return SPIKE_LEN_T1_PX
	if tier == 2:
		return SPIKE_LEN_T2_PX
	return SPIKE_LEN_T3_PLUS_PX

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
