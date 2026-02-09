extends Node
const SFLog := preload("res://scripts/util/sf_log.gd")

const MAP_BUILDER_SCRIPT := preload("res://scenes/MapBuilder.gd")
const SHELL_BUFFER_LAYER_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer"
const SHELL_BUFFER_ROOT_PATH: String = SHELL_BUFFER_LAYER_PATH + "/BufferRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/TopBufferBackground"
const TRACE_MAIN_LOGS: bool = false

@export var start_in_menu := true

# Dev-only: when ON, DevMapLoader is source of truth for map selection.
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
	if SFLog.LOGGING_ENABLED:
		if TRACE_MAIN_LOGS: print("MAIN: _ready scene=", get_tree().current_scene.scene_file_path)
	if SFLog.LOGGING_ENABLED:
		if TRACE_MAIN_LOGS: print("MAIN FLAGS: start_in_menu=", start_in_menu,
				" enable_dev_map_loader=", enable_dev_map_loader,
				" show_dev_map_loader_in_game=", show_dev_map_loader_in_game)
	_log_top_buffer_layer_once()
	call_deferred("_log_ui_debug_once")

	var pending_map_id: String = ""
	var has_pending_map: bool = false
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null:
		pending_map_id = str(gamebot.get("next_map_id"))
		has_pending_map = not pending_map_id.is_empty()
	if has_pending_map:
		start_in_menu = false
		show_dev_map_loader_in_game = false

	var arena: Node = get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
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

	# Map load is explicit: either pending map from Gamebot or DevMapLoader selection.
	if arena != null:
		if enable_dev_map_loader and _has_dev_map_loader() and not has_pending_map:
			return

		if not has_pending_map:
			SFLog.warn("MAIN_NO_PENDING_MAP", {
				"reason": "explicit_map_selection_required",
				"dev_loader_enabled": enable_dev_map_loader
			})
			return

		var map_path: String = pending_map_id

		var builder := MAP_BUILDER_SCRIPT.new()
		if arena.has_method("clear_map"):
			arena.call("clear_map")
		var ok := builder.build_into(arena, map_path)
		if ok:
			if arena.has_method("notify_map_built"):
				arena.call("notify_map_built")
			if arena.has_method("fitcam_once"):
				arena.call("fitcam_once")
			if has_pending_map and gamebot != null:
				gamebot.set("next_map_id", "")
				gamebot.set("next_mode", "")

func _node_pos(n: Node) -> Variant:
	if n == null:
		return "nil"
	if n is Node2D:
		return (n as Node2D).position
	if n is Control:
		return (n as Control).position
	return "<no position>"

func _node_scale(n: Node) -> Variant:
	if n == null:
		return "nil"
	if n is Node2D:
		return (n as Node2D).scale
	if n is Control:
		return (n as Control).scale
	return "<no scale>"

func _log_ui_debug_once() -> void:
	await get_tree().process_frame
	var br := get_node_or_null(SHELL_BUFFER_ROOT_PATH)
	var tb := get_node_or_null(SHELL_TOP_BUFFER_PATH)
	var bbl := get_node_or_null(SHELL_BUFFER_LAYER_PATH)
	var main := get_node_or_null("/root/Shell/ArenaRoot/Main")

	var bbl_off: Variant = "nil"
	if bbl != null and bbl is CanvasLayer:
		bbl_off = (bbl as CanvasLayer).offset

	var tb_rect: Variant = "nil"
	if tb != null and tb is Control:
		tb_rect = (tb as Control).get_global_rect()

	if TRACE_MAIN_LOGS: print("UI_DEBUG2:",
		" main_type=", main.get_class() if main else "nil",
		" main_pos=", _node_pos(main),
		" main_scale=", _node_scale(main),
		" bbl_type=", bbl.get_class() if bbl else "nil",
		" bbl_offset=", bbl_off,
		" br_type=", br.get_class() if br else "nil",
		" br_pos=", _node_pos(br),
		" tb_type=", tb.get_class() if tb else "nil",
		" tb_pos=", _node_pos(tb),
		" tb_rect=", tb_rect
	)
	var top_buffer: Control = tb as Control
	if top_buffer != null:
		var top_rect: Rect2 = top_buffer.get_global_rect()
		var top_y: float = top_rect.position.y
		var aligned_to_top: bool = top_y >= -1.0 and top_y <= 1.0
		if TRACE_MAIN_LOGS: print("UI_BUFFER_ALIGN:",
			" path=", str(top_buffer.get_path()),
			" rect=", top_rect,
			" top_y=", top_y,
			" aligned=", aligned_to_top
		)
	else:
		if TRACE_MAIN_LOGS: print("UI_BUFFER_ALIGN: top buffer missing or non-control")


func _has_dev_map_loader() -> bool:
	return get_node_or_null("UI/DevMapLoader") != null or find_child("DevMapPicker", true, false) != null

func _log_top_buffer_layer_once() -> void:
	var buffer_node: Node = get_node_or_null(SHELL_TOP_BUFFER_PATH)
	var canvas_layer: CanvasLayer = _nearest_canvas_layer(buffer_node)
	var canvas_item: CanvasItem = buffer_node as CanvasItem
	if TRACE_MAIN_LOGS: print("TEMP_BUFFER_LAYER path=", str(buffer_node.get_path()) if buffer_node != null else "<missing>",
		" inside_canvas_layer=", canvas_layer != null,
		" canvas_layer=", int(canvas_layer.layer) if canvas_layer != null else 0,
		" z_index=", int(canvas_item.z_index) if canvas_item != null else 0)
	SFLog.info("TEMP_BUFFER_LAYER", {
		"path": str(buffer_node.get_path()) if buffer_node != null else "<missing>",
		"inside_canvas_layer": canvas_layer != null,
		"canvas_layer": int(canvas_layer.layer) if canvas_layer != null else 0,
		"z_index": int(canvas_item.z_index) if canvas_item != null else 0
	})

func _nearest_canvas_layer(node: Node) -> CanvasLayer:
	var cursor: Node = node
	while cursor != null:
		if cursor is CanvasLayer:
			return cursor as CanvasLayer
		cursor = cursor.get_parent()
	return null


func start_game() -> void:
	var ui := get_node_or_null("UI")
	var arena_node: Node = get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
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
