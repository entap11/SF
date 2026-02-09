@tool
extends Node2D
class_name MapBuilderNode
const SFLog := preload("res://scripts/util/sf_log.gd")

@export var autoplay_in_game := false
@export var map_id: String = ""
@export_node_path("Node2D") var arena_path: NodePath

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not autoplay_in_game:
		if SFLog.LOGGING_ENABLED:
			print("MAP_BUILDER_NODE: autoplay_in_game=false (not building)")
		return

	build()

func build() -> void:
	var arena := get_node_or_null(arena_path)
	if arena == null:
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_NODE: arena_path invalid")
		return
	if map_id.is_empty():
		if SFLog.LOGGING_ENABLED:
			push_error("MAP_BUILDER_NODE: map_id is empty")
		return

	if SFLog.LOGGING_ENABLED:
		print("MAP_BUILDER_NODE: building map_id=", map_id, " into arena=", arena.name)
	var builder := MapBuilder.new()
	if arena.has_method("clear_map"):
		arena.call("clear_map")
	var ok := builder.build_into(arena, map_id)
	if ok:
		if arena.has_method("notify_map_built"):
			arena.call("notify_map_built")
		if arena.has_method("fitcam_once"):
			arena.call("fitcam_once")
