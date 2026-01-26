extends Node

const MAP_BUILDER_SCRIPT := preload("res://scenes/MapBuilder.gd")
const DEFAULT_MAP_PATH := "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_BARRACKS_1.json"

@export var start_in_menu := true

# Dev-only: when ON, Main will NOT auto-load DEFAULT_MAP_PATH (DevMapLoader becomes source of truth).
@export var enable_dev_map_loader := true

# If true, DevMapLoader stays visible even after Start Game.
@export var show_dev_map_loader_in_game := false


func _enter_tree() -> void:
	if not enable_dev_map_loader:
		return
	var dml := get_node_or_null("UI/DevMapLoader")
	if dml != null:
		# Only autoplay if you actually want the loader to be driving boot.
		dml.autoplay = start_in_menu or show_dev_map_loader_in_game


func _ready() -> void:
	print("MAIN: _ready scene=", get_tree().current_scene.scene_file_path)
	print("MAIN FLAGS: start_in_menu=", start_in_menu,
		" enable_dev_map_loader=", enable_dev_map_loader,
		" show_dev_map_loader_in_game=", show_dev_map_loader_in_game)

	var arena := $Arena
	var dml := get_node_or_null("UI/DevMapLoader")
	var ui := get_node_or_null("UI")

	# Wire / remove dev loader
	if not enable_dev_map_loader:
		if dml != null:
			dml.queue_free()
	else:
		if dml != null:
			dml.set_arena(arena)
			# In dev, show the loader at boot so you can pick/load maps.
			dml.visible = true

	# Menu visibility rules
	if start_in_menu:
		if ui != null:
			ui.visible = true
		if arena != null:
			arena.visible = false
		# IMPORTANT: keep DevMapLoader visible in menu when dev is enabled.
		if dml != null:
			dml.visible = enable_dev_map_loader
	else:
		# If you skip menu, start game immediately.
		start_game()

	# Auto-load a default map only when dev loader is OFF (real gameplay path)
	if arena != null:
		if enable_dev_map_loader and _has_dev_map_loader():
			return

		var builder := MAP_BUILDER_SCRIPT.new()
		if arena.has_method("clear_map"):
			arena.call("clear_map")
		var ok := builder.build_into(arena, DEFAULT_MAP_PATH)
		if ok:
			if arena.has_method("notify_map_built"):
				arena.call("notify_map_built")
			if arena.has_method("fitcam_once"):
				arena.call("fitcam_once")


func _has_dev_map_loader() -> bool:
	return get_node_or_null("UI/DevMapLoader") != null or find_child("DevMapPicker", true, false) != null


func start_game() -> void:
	var ui := get_node_or_null("UI")
	var arena_node: Node = get_node_or_null("Arena")
	var dml := get_node_or_null("UI/DevMapLoader")

	if ui != null:
		ui.visible = false
	if arena_node != null:
		arena_node.visible = true

	# Only keep the loader visible in-game if explicitly desired.
	if dml != null:
		if enable_dev_map_loader and show_dev_map_loader_in_game:
			dml.visible = true
			# make sure it won't intercept gameplay clicks
			if dml.has_method("_apply_in_game_input_passthrough"):
				dml.call_deferred("_apply_in_game_input_passthrough")
		else:
			# Hard-disable: prevents any “ghost reload” later
			dml.queue_free()

	# Defer fit until after visibility changes take effect.
	if arena_node != null and arena_node.has_method("_fit_camera_to_viewport"):
		arena_node.call_deferred("_fit_camera_to_viewport")
