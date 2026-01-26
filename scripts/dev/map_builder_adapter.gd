extends RefCounted
class_name MapBuilderAdapter

const BUILDER_SCRIPT_PATH := "res://scripts/maps/map_builder.gd"
const METHOD := "build_into"

static func build_into(arena: Node, map_id: String) -> bool:
	print("MAP_BUILDER_ADAPTER: using ", BUILDER_SCRIPT_PATH)
	if not ResourceLoader.exists(BUILDER_SCRIPT_PATH):
		print("MAP_BUILDER_ADAPTER: fail at exists")
		push_error("MAP_BUILDER_ADAPTER: missing builder script: %s" % BUILDER_SCRIPT_PATH)
		return false
	var s: Script = load(BUILDER_SCRIPT_PATH) as Script
	if s == null:
		print("MAP_BUILDER_ADAPTER: fail at load")
		push_error("MAP_BUILDER_ADAPTER: failed to load: %s" % BUILDER_SCRIPT_PATH)
		return false
	var builder: RefCounted = s.new() as RefCounted
	if builder == null:
		print("MAP_BUILDER_ADAPTER: fail at instantiate")
		push_error("MAP_BUILDER_ADAPTER: failed to instantiate: %s" % BUILDER_SCRIPT_PATH)
		return false
	print("MAP_BUILDER_ADAPTER: builder script =", builder.get_script().resource_path)
	if not builder.has_method(METHOD):
		print("MAP_BUILDER_ADAPTER: fail at has_method")
		push_error("MAP_BUILDER_ADAPTER: missing method %s on %s" % [METHOD, BUILDER_SCRIPT_PATH])
		return false
	var ok: bool = bool(builder.call(METHOD, arena, map_id))
	return ok
