extends SceneTree

const Circuits := preload("res://scripts/renderers/floor_circuit_layer.gd")
var failed := false

class Preferences:
	extends Node
	var enabled := true
	func is_floor_graphics_enabled() -> bool:
		return enabled
	func is_gpu_vfx_enabled() -> bool:
		return enabled

class Lifecycle:
	extends Node
	var backgrounded := false
	func is_backgrounded() -> bool:
		return backgrounded

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func run() -> void:
	var layer: Node2D = Circuits.new()
	root.add_child(layer)
	var bounds := Rect2(-32, -64, 1144, 2048)
	layer.call("configure", bounds)
	var paths: Array = layer.get("_paths")
	check(paths.size() == 16, "floor uses a fixed sparse set of circuit paths")
	for path: PackedVector2Array in paths:
		for point in path:
			check(bounds.has_point(point), "decorative traces stay within the floor")
	layer.call("configure", bounds)
	check(layer.get_child_count() == 0 and layer.get("_paths") == paths, "repeat layout creates no extra effects or geometry")
	var seen: Dictionary = {}
	for tick in range(1200):
		var time_sec: float = float(tick) * 0.1
		var pulses: Array = Circuits.pulses_at(time_sec)
		check(pulses.size() <= 2, "no more than two ambient traces glow at once")
		check(pulses == Circuits.pulses_at(time_sec), "glow schedule depends on elapsed time, not frame count")
		for pulse in pulses:
			check(float(pulse.strength) >= 0.0 and float(pulse.strength) <= 1.0, "glow envelope stays bounded")
			seen[pulse.trace] = true
	check(seen.size() > 8, "randomized sequence visits a variety of traces")
	var preferences := Preferences.new()
	var lifecycle := Lifecycle.new()
	layer.set("_profile", preferences)
	layer.set("_lifecycle", lifecycle)
	check(layer.call("_motion_allowed"), "ambient motion allowed with normal settings")
	preferences.enabled = false
	check(not layer.call("_motion_allowed"), "reduced graphics settings suppress ambient motion")
	preferences.enabled = true
	lifecycle.backgrounded = true
	check(not layer.call("_motion_allowed"), "backgrounding suppresses ambient motion")
	layer.free()
	preferences.free()
	lifecycle.free()
	print("FLOOR_CIRCUIT_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
