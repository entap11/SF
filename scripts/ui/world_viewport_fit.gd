class_name WorldViewportFit
extends SubViewportContainer

const SFLog := preload("res://scripts/util/sf_log.gd")

@export var world_viewport_path: NodePath = NodePath("WorldViewport")
@export var world_size: Vector2i = Vector2i(1080, 1920)
@export var debug_log: bool = true

var _world_viewport: SubViewport = null

func _ready() -> void:
	_world_viewport = get_node_or_null(world_viewport_path) as SubViewport
	if _world_viewport != null:
		_world_viewport.disable_3d = true
		_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if world_size.x > 0 and world_size.y > 0:
			_world_viewport.size = world_size
	_apply_fit()
	var root_viewport: Viewport = get_viewport()
	if root_viewport != null and not root_viewport.size_changed.is_connected(_on_root_size_changed):
		root_viewport.size_changed.connect(_on_root_size_changed)

func _on_root_size_changed() -> void:
	_apply_fit()

func _apply_fit() -> void:
	var root_viewport: Viewport = get_viewport()
	if root_viewport == null:
		return
	var window_size: Vector2 = root_viewport.get_visible_rect().size
	var world_size_v: Vector2 = Vector2(world_size.x, world_size.y)
	if _world_viewport != null:
		world_size_v = Vector2(_world_viewport.size.x, _world_viewport.size.y)
	if world_size_v.x <= 0.0 or world_size_v.y <= 0.0:
		return
	var scale_factor: float = min(window_size.x / world_size_v.x, window_size.y / world_size_v.y)
	var target_size: Vector2 = world_size_v * scale_factor
	size = target_size
	position = (window_size - target_size) * 0.5
	if debug_log:
		SFLog.allow_tag("WORLD_VIEWPORT_FIT")
		SFLog.info("WORLD_VIEWPORT_FIT", {
			"window": window_size,
			"world": world_size_v,
			"scale": scale_factor,
			"container_size": size,
			"container_pos": position
		})
