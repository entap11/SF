class_name VfxPool
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

var max_active: int = 24
var preload_count: int = 32
var ionpop_scene: PackedScene = null

var _available: Array[IonPop] = []
var _active: Array[IonPop] = []
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
	var to_release: Array[IonPop] = _active.duplicate()
	for fx: IonPop in to_release:
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
	var fx: IonPop = _available.pop_back()
	_active.append(fx)
	fx.play(from_pos, to_pos)

func return_ionpop(fx: IonPop) -> void:
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
		var fx: IonPop = instance_any as IonPop
		if fx == null:
			if instance_any != null:
				instance_any.queue_free()
			continue
		fx.name = "IonPop_%d" % i
		add_child(fx)
		fx.init(self)
		_available.append(fx)
