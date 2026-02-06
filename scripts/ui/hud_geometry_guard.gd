extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

@export var hud_root_path: NodePath = NodePath("")
@export var enabled: bool = true
@export var check_interval_s: float = 0.5
@export var epsilon_px: float = 0.5
@export var log_interval_ms: int = 2000

var _baseline: Dictionary = {}
var _last_log_ms: Dictionary = {}
var _accum_s: float = 0.0

func _ready() -> void:
	if not OS.is_debug_build():
		return
	if not enabled:
		return
	var root: Node = get_node_or_null(hud_root_path)
	if root == null:
		SFLog.warn("HUD_GEOMETRY_GUARD_ROOT_MISSING", {"path": str(hud_root_path)})
		return
	_baseline = _snapshot_controls(root)

func _process(delta: float) -> void:
	if not OS.is_debug_build():
		return
	if not enabled:
		return
	if _baseline.is_empty():
		return
	_accum_s += delta
	if _accum_s < check_interval_s:
		return
	_accum_s = 0.0
	_check_drift()

func _snapshot_controls(root: Node) -> Dictionary:
	var out: Dictionary = {}
	var nodes: Array = [root]
	while not nodes.is_empty():
		var n_any: Variant = nodes.pop_back()
		var n: Node = n_any as Node
		if n == null:
			continue
		if n is Control:
			var c: Control = n as Control
			out[str(c.get_path())] = _snapshot_control(c)
		for child in n.get_children():
			nodes.append(child)
	return out

func _snapshot_control(c: Control) -> Dictionary:
	var rect: Rect2 = c.get_global_rect()
	return {
		"rect_pos": rect.position,
		"rect_size": rect.size,
		"anchor_left": c.anchor_left,
		"anchor_top": c.anchor_top,
		"anchor_right": c.anchor_right,
		"anchor_bottom": c.anchor_bottom,
		"offset_left": c.offset_left,
		"offset_top": c.offset_top,
		"offset_right": c.offset_right,
		"offset_bottom": c.offset_bottom
	}

func _check_drift() -> void:
	var now_ms: int = Time.get_ticks_msec()
	for path_key in _baseline.keys():
		var path: NodePath = NodePath(str(path_key))
		var node: Node = get_node_or_null(path)
		if node == null or not (node is Control):
			continue
		var c: Control = node as Control
		var base: Dictionary = _baseline.get(path_key, {})
		if base.is_empty():
			continue
		var current: Dictionary = _snapshot_control(c)
		var changed_fields: Array = []
		if _vec2_diff(current.get("rect_pos", Vector2.ZERO), base.get("rect_pos", Vector2.ZERO)) > epsilon_px:
			changed_fields.append("rect_pos")
		if _vec2_diff(current.get("rect_size", Vector2.ZERO), base.get("rect_size", Vector2.ZERO)) > epsilon_px:
			changed_fields.append("rect_size")
		for k in ["anchor_left", "anchor_top", "anchor_right", "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom"]:
			if float(current.get(k, 0.0)) != float(base.get(k, 0.0)):
				changed_fields.append(k)
		if changed_fields.is_empty():
			continue
		var last_ms: int = int(_last_log_ms.get(path_key, 0))
		if now_ms - last_ms < log_interval_ms:
			continue
		_last_log_ms[path_key] = now_ms
		SFLog.warn("HUD_GEOMETRY_DRIFT", {
			"path": str(path_key),
			"changed": changed_fields,
			"baseline": base,
			"current": current,
			"caller_hint": _caller_hint()
		})

func _vec2_diff(a: Vector2, b: Vector2) -> float:
	return maxf(absf(a.x - b.x), absf(a.y - b.y))

func _caller_hint() -> String:
	var stack: Array = get_stack()
	for i in range(1, stack.size()):
		var frame: Dictionary = stack[i]
		var src: String = str(frame.get("source", ""))
		if src == "":
			continue
		if not src.ends_with("hud_geometry_guard.gd"):
			var func_name: String = str(frame.get("function", ""))
			var line: int = int(frame.get("line", 0))
			return "%s:%s:%d" % [src, func_name, line]
	return ""
