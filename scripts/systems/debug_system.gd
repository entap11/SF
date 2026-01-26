class_name DebugSystem
extends RefCounted

const SFLog := preload("res://scripts/util/sf_log.gd")

func dbg(msg: String) -> void:
	var t_sec := float(Time.get_ticks_msec()) / 1000.0
	SFLog.debug("%8.3f | %s" % [t_sec, msg])

func debug_camera(
	tag: String,
	active: Camera2D,
	ours: Camera2D,
	viewport_size: Vector2,
	ours_pos: Vector2,
	ours_zoom: Vector2
) -> void:
	var msg := "CAMDBG: %s active=%s ours=%s same=%s vsize=%s ours_pos=%s ours_zoom=%s" % [
		tag,
		str(active),
		str(ours),
		str(active == ours),
		str(viewport_size),
		str(ours_pos),
		str(ours_zoom)
	]
	SFLog.throttle("camdbg:" + tag, 1.0, msg, SFLog.Level.TRACE)

func debug_map_bounds(tag: String, bounds: Rect2, cam_pos: Vector2, cam_zoom: Vector2) -> void:
	var msg := "MAPBOUNDS: %s rect=%s cam_pos=%s cam_zoom=%s" % [tag, str(bounds), str(cam_pos), str(cam_zoom)]
	SFLog.throttle("mapbounds:" + tag, 1.0, msg, SFLog.Level.TRACE)

func log_fit_state(
	tag: String,
	arena_node: Node2D,
	map_root: Node2D,
	hive_renderer: Node2D,
	camera: Camera2D,
	arena_rect: Rect2,
	arena_center: Vector2,
	viewport_size: Vector2,
	safe_rect: Rect2,
	overlays_count: int,
	map_offset: Vector2
) -> void:
	if arena_node == null or map_root == null or hive_renderer == null or camera == null:
		return
	var arena_scale: Vector2 = arena_node.scale
	var arena_global_scale: Vector2 = arena_node.global_transform.get_scale()
	var map_pos: Vector2 = map_root.position
	var map_global_pos: Vector2 = map_root.global_position
	var map_scale: Vector2 = map_root.scale
	var map_global_scale: Vector2 = map_root.global_transform.get_scale()
	var grid_pos: Vector2 = hive_renderer.position
	var grid_global_pos: Vector2 = hive_renderer.global_position
	var grid_scale: Vector2 = hive_renderer.scale
	var grid_global_scale: Vector2 = hive_renderer.global_transform.get_scale()
	var cam_pos: Vector2 = camera.position
	var cam_global_pos: Vector2 = camera.global_position
	var cam_zoom: Vector2 = camera.zoom
	var msg := "FITSTATE:%s arena_pos=%s arena_gpos=%s arena_scale=%s arena_gscale=%s map_pos=%s map_gpos=%s map_scale=%s map_gscale=%s grid_pos=%s grid_gpos=%s grid_scale=%s grid_gscale=%s cam_pos=%s cam_gpos=%s cam_zoom=%s viewport=%s arena_rect=%s arena_center=%s overlays=%s safe_rect=%s map_offset=%s" % [
		tag,
		arena_node.position,
		arena_node.global_position,
		arena_scale,
		arena_global_scale,
		map_pos,
		map_global_pos,
		map_scale,
		map_global_scale,
		grid_pos,
		grid_global_pos,
		grid_scale,
		grid_global_scale,
		cam_pos,
		cam_global_pos,
		cam_zoom,
		viewport_size,
		arena_rect,
		arena_center,
		overlays_count,
		safe_rect,
		map_offset
	]
	SFLog.throttle("fitstate:" + tag, 1.0, msg, SFLog.Level.TRACE)

func handle_events(_events: Array, _arena_api: ArenaAPI) -> void:
	pass
