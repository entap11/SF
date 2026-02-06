extends Node
const SFLog := preload("res://scripts/util/sf_log.gd")

@export var enabled: bool = true
@export var hud_root_path: NodePath = NodePath("HUDRoot")
@export var check_every_n_frames: int = 10

var _snapshots: Dictionary = {}
var _frame_counter: int = 0
var _hud_root: Node = null

func _ready() -> void:
	if not enabled:
		return
	SFLog.allow_tag("HUD_MUTATION_DETECTED")
	SFLog.allow_tag("HUD_CONTAINER_FOUND")
	SFLog.allow_tag("HUD_VIEWPORT_AUDIT")
	_hud_root = _resolve_hud_root()
	if _hud_root == null:
		return
	var root_viewport: Viewport = get_viewport()
	if root_viewport != null:
		SFLog.info("HUD_VIEWPORT_AUDIT", {
			"visible_rect": root_viewport.get_visible_rect(),
			"canvas_transform": root_viewport.get_canvas_transform()
		})
	_scan_containers(_hud_root)
	_snapshot_all(_hud_root)
	set_process(true)

func _process(_delta: float) -> void:
	if not enabled or _hud_root == null:
		return
	_frame_counter += 1
	var interval: int = check_every_n_frames
	if interval < 1:
		interval = 1
	if _frame_counter % interval != 0:
		return
	_check_mutations(_hud_root)

func _resolve_hud_root() -> Node:
	if hud_root_path != NodePath(""):
		var root_by_path: Node = get_node_or_null(hud_root_path)
		if root_by_path != null:
			return root_by_path
	return get_node_or_null("HUDRoot")

func _snapshot_all(root: Node) -> void:
	_snapshots.clear()
	_snapshot_node_recursive(root)

func _snapshot_node_recursive(node: Node) -> void:
	if node is Control:
		var control: Control = node as Control
		var path: String = str(control.get_path())
		_snapshots[path] = _capture_props(control)
	for child in node.get_children():
		_snapshot_node_recursive(child)

func _capture_props(control: Control) -> Dictionary:
	return {
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
		"position": control.position,
		"size": control.size,
		"scale": control.scale,
		"rotation": control.rotation,
		"pivot_offset": control.pivot_offset,
		"z_index": control.z_index,
		"visible": control.visible,
		"modulate": control.modulate
	}

func _check_mutations(root: Node) -> void:
	var current: Dictionary = {}
	_collect_current(root, current)
	for path in current.keys():
		var old_snapshot: Dictionary = _snapshots.get(path, {})
		var new_snapshot: Dictionary = current.get(path, {})
		var diff: Dictionary = _diff_props(old_snapshot, new_snapshot)
		if diff.size() > 0:
			var node: Node = get_tree().root.get_node_or_null(path)
			var script_path: String = ""
			if node != null:
				var script_ref: Script = node.get_script() as Script
				if script_ref != null:
					script_path = str(script_ref.resource_path)
			SFLog.warn("HUD_MUTATION_DETECTED", {
				"path": path,
				"changed": diff,
				"frame": int(Engine.get_process_frames()),
				"script": script_path
			})
			_snapshots[path] = new_snapshot

func _collect_current(node: Node, out: Dictionary) -> void:
	if node is Control:
		var control: Control = node as Control
		var path: String = str(control.get_path())
		out[path] = _capture_props(control)
	for child in node.get_children():
		_collect_current(child, out)

func _diff_props(old_props: Dictionary, new_props: Dictionary) -> Dictionary:
	var diff: Dictionary = {}
	for key in new_props.keys():
		var old_val: Variant = old_props.get(key, null)
		var new_val: Variant = new_props.get(key, null)
		if old_val != new_val:
			diff[key] = {"old": old_val, "new": new_val}
	return diff

func _scan_containers(root: Node) -> void:
	if root is Container:
		SFLog.warn("HUD_CONTAINER_FOUND", {
			"path": str(root.get_path()),
			"type": root.get_class()
		})
	for child in root.get_children():
		_scan_containers(child)
