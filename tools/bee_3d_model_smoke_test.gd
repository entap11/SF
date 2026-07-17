extends SceneTree

const MODEL_PATHS: Array[String] = [
	"res://assets/models/bees/bee_low.glb",
	"res://assets/models/bees/bee_high.glb",
]

var _failed: bool = false

func _init() -> void:
	for model_path in MODEL_PATHS:
		_validate_model(model_path)
	if _failed:
		quit(1)
		return
	print("BEE_3D_MODEL_SMOKE: PASS")
	quit(0)

func _validate_model(model_path: String) -> void:
	var packed: PackedScene = load(model_path) as PackedScene
	_expect(packed != null, "%s must import as a PackedScene" % model_path)
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	var model_root := instance as Node3D
	_expect(model_root != null, "%s root must be Node3D" % model_path)
	if model_root == null:
		instance.free()
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(instance, meshes)
	_expect(not meshes.is_empty(), "%s must contain real MeshInstance3D geometry" % model_path)
	var surface_count: int = 0
	var vertex_count: int = 0
	var model_bounds := AABB()
	var has_bounds: bool = false
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var mesh_bounds: AABB = _transform_relative_to(mesh_instance, model_root) * mesh_instance.get_aabb()
		model_bounds = model_bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
		surface_count += mesh_instance.mesh.get_surface_count()
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface_index)
			if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				vertex_count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	_expect(surface_count > 0, "%s must contain renderable surfaces" % model_path)
	_expect(vertex_count > 100, "%s must contain modeled vertices, not billboard quads" % model_path)
	_expect(has_bounds and model_bounds.size.length() > 0.01, "%s must have nonzero 3D bounds" % model_path)
	var animation_names: PackedStringArray = []
	for player_any in instance.find_children("", "AnimationPlayer", true, false):
		var player := player_any as AnimationPlayer
		if player != null:
			animation_names.append_array(player.get_animation_list())
	if model_path.ends_with("bee_high.glb"):
		_expect(not animation_names.is_empty(), "high bee must retain its Blender animation")
	print("BEE_3D_MODEL: path=%s meshes=%d vertices=%d bounds=%s animations=%s" % [model_path, meshes.size(), vertex_count, str(model_bounds), str(animation_names)])
	instance.free()

func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var relative: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != ancestor:
		if parent is Node3D:
			relative = (parent as Node3D).transform * relative
		parent = parent.get_parent()
	return relative

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("BEE_3D_MODEL_SMOKE: %s" % message)
