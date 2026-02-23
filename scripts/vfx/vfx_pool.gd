class_name VfxPool
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

var max_active: int = 24
var preload_count: int = 32
var ionpop_scene: PackedScene = null

var _available: Array[Node2D] = []
var _active: Array[Node2D] = []
var _enabled: bool = true
var _configured: bool = false

func configure(scene: PackedScene, preload_total: int, max_active_total: int) -> void:
	ionpop_scene = scene
	preload_count = maxi(0, preload_total)
	max_active = maxi(0, max_active_total)
	if preload_count < max_active:
		max_active = preload_count
		SFLog.allow_tag("IONPOP_POOL_CONFIG")
		SFLog.warn("IONPOP_POOL_CONFIG", {
			"note": "max_active clamped to preload_count",
			"preload_count": preload_count,
			"max_active": max_active
		})
	_build_pool()
	_configured = true

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		return
	var to_release: Array[Node2D] = _active.duplicate()
	for fx: Node2D in to_release:
		return_ionpop(fx)

func spawn_ionpop(from_pos: Vector2, to_pos: Vector2) -> void:
	if not _enabled:
		return
	if not _configured:
		return
	if _active.size() >= max_active:
		return
	if _available.is_empty():
		return
	var fx: Node2D = _available.pop_back()
	_active.append(fx)
	if fx.has_method("play"):
		fx.call("play", from_pos, to_pos)

func return_ionpop(fx: Node2D) -> void:
	if fx == null:
		return
	var active_index: int = _active.find(fx)
	if active_index >= 0:
		_active.remove_at(active_index)
	fx.hide()
	if not _available.has(fx):
		_available.append(fx)

func _build_pool() -> void:
	if ionpop_scene == null:
		return
	if not _available.is_empty() or not _active.is_empty():
		return
	for i: int in range(preload_count):
		var instance_any: Node = ionpop_scene.instantiate()
		var fx: Node2D = instance_any as Node2D
		if fx == null:
			if instance_any != null:
				instance_any.queue_free()
			continue
		fx.name = "IonPop_%d" % i
		add_child(fx)
		if fx.has_method("init"):
			fx.call("init", self)
		_available.append(fx)
