@tool
extends Node2D

const CELL_SIZE := 64.0

@export var bake_grid_pos: bool = false:
	set(value):
		bake_grid_pos = value
		if bake_grid_pos:
			_bake_grid_pos()
			bake_grid_pos = false

@export var assign_hive_ids: bool = false:
	set(value):
		assign_hive_ids = value
		if assign_hive_ids:
			_assign_hive_ids()
			assign_hive_ids = false

@export var hive_id_start: int = 1
@export var preserve_existing_hive_ids: bool = true

func _bake_grid_pos() -> void:
	var nodes: Array = _collect_nodes_with_grid_pos(self)
	for node in nodes:
		if not (node is Node2D):
			continue
		var pos: Vector2 = node.position
		var grid: Vector2i = Vector2i(int(round(pos.x / CELL_SIZE)), int(round(pos.y / CELL_SIZE)))
		node.set("grid_pos", grid)
		node.position = Vector2(grid) * CELL_SIZE

func _collect_nodes_with_grid_pos(root: Node) -> Array:
	var found: Array = []
	if _has_property(root, "grid_pos"):
		found.append(root)
	for child in root.get_children():
		if child is Node:
			found.append_array(_collect_nodes_with_grid_pos(child))
	return found

func _has_property(obj: Object, name: String) -> bool:
	for prop in obj.get_property_list():
		if prop.name == name:
			return true
	return false

func _assign_hive_ids() -> void:
	var hives: Array = _collect_nodes_with_property(self, "hive_id")
	if hives.is_empty():
		return
	hives.sort_custom(Callable(self, "_hive_sort"))
	var max_existing: int = 0
	if preserve_existing_hive_ids:
		for hive in hives:
			var existing: int = int(hive.get("hive_id"))
			if existing > max_existing:
				max_existing = existing
	var next_id: int = hive_id_start
	if preserve_existing_hive_ids and max_existing >= next_id:
		next_id = max_existing + 1
	for hive in hives:
		if preserve_existing_hive_ids and int(hive.get("hive_id")) > 0:
			continue
		hive.set("hive_id", next_id)
		next_id += 1

func _collect_nodes_with_property(root: Node, name: String) -> Array:
	var found: Array = []
	if _has_property(root, name):
		found.append(root)
	for child in root.get_children():
		if child is Node:
			found.append_array(_collect_nodes_with_property(child, name))
	return found

func _hive_sort(a: Object, b: Object) -> bool:
	var pos_a: Vector2i = _grid_from_node(a)
	var pos_b: Vector2i = _grid_from_node(b)
	if pos_a.y == pos_b.y:
		return pos_a.x < pos_b.x
	return pos_a.y < pos_b.y

func _grid_from_node(node: Object) -> Vector2i:
	if node.has_method("get"):
		if node.get("grid_pos") is Vector2i:
			return node.get("grid_pos")
		if node.get("grid_pos") is Vector2:
			var gp_vec2: Vector2 = node.get("grid_pos")
			return Vector2i(int(round(gp_vec2.x)), int(round(gp_vec2.y)))
	if node is Node2D:
		var pos: Vector2 = node.position
		return Vector2i(int(round(pos.x / CELL_SIZE)), int(round(pos.y / CELL_SIZE)))
	return Vector2i.ZERO
