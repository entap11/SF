class_name ArenaWorldViewportCache
extends RefCounted

var _container_cache: Control = null
var _subviewport_cache: SubViewport = null

func resolve_container(tree: SceneTree) -> Control:
	if _container_cache != null and is_instance_valid(_container_cache):
		return _container_cache
	if tree == null:
		return null
	var direct: Control = tree.root.get_node_or_null("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer") as Control
	if direct != null:
		_container_cache = direct
		return direct
	if tree.root == null:
		return null
	var found: Node = tree.root.find_child("WorldViewportContainer", true, false)
	if found != null and found is Control:
		_container_cache = found as Control
	return _container_cache

func resolve_subviewport(tree: SceneTree) -> SubViewport:
	if _subviewport_cache != null and is_instance_valid(_subviewport_cache):
		return _subviewport_cache
	if tree == null:
		return null
	var direct: SubViewport = tree.root.get_node_or_null("/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport") as SubViewport
	if direct != null:
		_subviewport_cache = direct
		return direct
	if tree.root == null:
		return null
	var found: Node = tree.root.find_child("WorldViewport", true, false)
	if found != null and found is SubViewport:
		_subviewport_cache = found as SubViewport
	return _subviewport_cache

func invalidate() -> void:
	_container_cache = null
	_subviewport_cache = null
