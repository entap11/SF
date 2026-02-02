extends RefCounted
class_name MapBuilderAdapter
const SFLog := preload("res://scripts/util/sf_log.gd")

const BUILDER_SCRIPT_PATH := "res://scripts/maps/map_builder.gd"
const METHOD := "build_into"

static func build_into(arena: Node, map_id: String) -> bool:
	if SFLog.LOGGING_ENABLED:
		print("MAP_BUILDER_ADAPTER: using ", BUILDER_SCRIPT_PATH)
	if not ResourceLoader.exists(BUILDER_SCRIPT_PATH):
		if SFLog.LOGGING_ENABLED:
			print("MAP_BUILDER_ADAPTER: fail at exists")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_ADAPTER: missing builder script: %s" % BUILDER_SCRIPT_PATH)
		return false
	var s: Script = load(BUILDER_SCRIPT_PATH) as Script
	if s == null:
		if SFLog.LOGGING_ENABLED:
			print("MAP_BUILDER_ADAPTER: fail at load")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_ADAPTER: failed to load: %s" % BUILDER_SCRIPT_PATH)
		return false
	var builder: RefCounted = s.new() as RefCounted
	if builder == null:
		if SFLog.LOGGING_ENABLED:
			print("MAP_BUILDER_ADAPTER: fail at instantiate")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_ADAPTER: failed to instantiate: %s" % BUILDER_SCRIPT_PATH)
		return false
	if SFLog.LOGGING_ENABLED:
		print("MAP_BUILDER_ADAPTER: builder script =", builder.get_script().resource_path)
	if not builder.has_method(METHOD):
		if SFLog.LOGGING_ENABLED:
			print("MAP_BUILDER_ADAPTER: fail at has_method")
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_ADAPTER: missing method %s on %s" % [METHOD, BUILDER_SCRIPT_PATH])
		return false
	var ok: bool = bool(builder.call(METHOD, arena, map_id))
	return ok
