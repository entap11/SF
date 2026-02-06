extends Control

const SFLog := preload("res://scripts/util/sf_log.gd")

@onready var MapPicker: OptionButton = %MapPicker
@onready var LoadBtn: Button = %LoadBtn
@onready var StartBtn: Button = %StartBtn
@onready var AutoplayChk: CheckBox = %AutoplayChk
@onready var StatusLbl: Label = %StatusLbl
@onready var BigLbl: Label = %BigLbl
@onready var panel_ui: Panel = $Panel
@onready var row2: HBoxContainer = $Panel/VBox/Row2

@export var autoplay := false
@export var autostart_sim := false
const CANON_GRID_W := 8
const CANON_GRID_H := 12
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const DEFAULT_DEV_MAP_ID := "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_TOWER_1.json"
var map_id := ""
var _arena: Node2D = null
var _builder := preload("res://scripts/maps/map_builder.gd").new()
var allowed_maps: PackedStringArray = PackedStringArray()
var _boot_done := false
var cell_size: int = 64

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sync_cell_size_from_arena()
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	# Dev harness: always show unless explicitly told to autoplay-headless.
	visible = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	call_deferred("_apply_in_game_input_passthrough")
	# --- DEV UI: force visible + on-screen in portrait ---
	panel_ui.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel_ui.offset_left = 16
	panel_ui.offset_top = 16
	panel_ui.offset_right = -16
	panel_ui.custom_minimum_size = Vector2(0, 180)
	# HARD reset to prevent double-connect when scene reloads / tool runs
	if LoadBtn.pressed.is_connected(_on_load_pressed):
		LoadBtn.pressed.disconnect(_on_load_pressed)
	if StartBtn.pressed.is_connected(_on_start_pressed):
		StartBtn.pressed.disconnect(_on_start_pressed)
	LoadBtn.pressed.connect(_on_load_pressed)
	StartBtn.pressed.connect(_on_start_pressed)

	# Make Row2 behave predictably
	row2.visible = true
	row2.clip_contents = false
	row2.size_flags_horizontal = Control.SIZE_FILL
	row2.add_theme_constant_override("separation", 12)

	# Force both buttons to take space
	LoadBtn.visible = true
	StartBtn.visible = true
	LoadBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StartBtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	LoadBtn.custom_minimum_size = Vector2(200, 44)
	StartBtn.custom_minimum_size = Vector2(200, 44)
	if StartBtn.text.strip_edges() == "":
		StartBtn.text = "Start"
	BigLbl.text = "DEV MAP LOADER\n(If you can read this, UI is working)"
	StatusLbl.text = "Booting..."
	SFLog.debug("DEV_MAP_LOADER: scene_file=%s script=%s" % [scene_file_path, get_script().resource_path])

	AutoplayChk.button_pressed = autoplay

	_populate_picker()
	if autoplay:
		call_deferred("_boot_load_once")

func _apply_in_game_input_passthrough() -> void:
	var arena_ci: CanvasItem = null
	if _arena != null:
		arena_ci = _arena as CanvasItem
	else:
		var main := get_tree().current_scene
		if main != null:
			arena_ci = main.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena") as CanvasItem
	if arena_ci == null or not arena_ci.visible:
		return
	# If we are showing the game (not in dev menu mode), do not intercept clicks.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(false)
	set_process_unhandled_input(false)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_arena(arena: Node2D) -> void:
	_arena = arena
	_sync_cell_size_from_arena()
	SFLog.debug("DEV_MAP_LOADER: arena injected =%s" % [str(_arena)])

func _sync_cell_size_from_arena() -> void:
	if _arena == null:
		return
	var spec: Variant = _arena.get("grid_spec")
	if spec != null:
		cell_size = int(spec.cell_size)

func _boot_load_once() -> void:
	if map_id == "":
		StatusLbl.text = "No map_id (picker empty)."
		SFLog.debug("DEV_MAP_LOADER: boot_load_once aborted (no map_id)")
		return
	StatusLbl.text = "Boot auto-load: %s" % map_id
	SFLog.debug("DEV_MAP_LOADER: boot auto-load map_id=%s" % map_id)
	_on_load_pressed()

func _populate_picker() -> void:
	var maps := MapCatalog.list_json_maps()
	MapPicker.clear()

	if not allowed_maps.is_empty():
		var filtered: Array[String] = []
		for p in maps:
			if allowed_maps.has(p):
				filtered.append(p)
		maps = filtered

	if maps.is_empty():
		map_id = ""
		StatusLbl.text = "No JSON maps found (or none whitelisted)"
		SFLog.debug("DEV_MAP_LOADER: no maps found / none whitelisted")
		return

	for p in maps:
		MapPicker.add_item(p.get_file())
		MapPicker.set_item_metadata(MapPicker.item_count - 1, p)

	var preferred_idx := -1
	for i in range(maps.size()):
		if maps[i] == DEFAULT_DEV_MAP_ID:
			preferred_idx = i
			break
	var select_idx := preferred_idx if preferred_idx >= 0 else 0
	MapPicker.select(select_idx)
	map_id = str(MapPicker.get_item_metadata(select_idx))
	StatusLbl.text = "Ready: %s" % map_id
	SFLog.debug("DEV_MAP_LOADER: populated picker. default map_id=%s" % map_id)
	SFLog.info("DEFAULT_MAP_SELECTED", {"map_id": map_id})

	# Wire UI (do it once, after nodes exist)
	if not MapPicker.item_selected.is_connected(_on_picker_changed):
		MapPicker.item_selected.connect(_on_picker_changed)
	if not AutoplayChk.toggled.is_connected(_on_autoplay_toggled):
		AutoplayChk.toggled.connect(_on_autoplay_toggled)

func _on_picker_changed(idx: int) -> void:
	map_id = str(MapPicker.get_item_metadata(idx))
	StatusLbl.text = "Selected: %s" % map_id
	SFLog.debug("DEV_MAP_LOADER: pick map_id=%s" % map_id)
	if autoplay:
		_on_load_pressed()

func _on_autoplay_toggled(v: bool) -> void:
	autoplay = v
	SFLog.debug("DEV_MAP_LOADER: autoplay=%s" % autoplay)
	StatusLbl.text = "Autoplay: %s" % autoplay
	if autoplay and map_id != "":
		_on_load_pressed()

func _on_load_pressed() -> void:
	SFLog.debug("DEV_MAP_LOADER: LOAD pressed map_id=%s" % map_id)
	if _boot_done:
		return

	if _arena == null:
		StatusLbl.text = "Arena not injected"
		if SFLog.LOGGING_ENABLED:
			push_error("DEV_MAP_LOADER: Arena not injected by Main")
		return
	if map_id == "":
		StatusLbl.text = "No map selected."
		return

	StatusLbl.text = "Loading: %s" % map_id

	# Clear render
	if _arena.has_method("clear_map_render"):
		_arena.call("clear_map_render")
	elif _arena.has_method("clear_map"):
		_arena.call("clear_map")
	else:
		_clear_map(_arena)

	SFLog.debug("DEV_MAP_LOADER: calling MAP_LOADER.load_map(%s)" % map_id)
	var result: Dictionary = MAP_LOADER.load_map(map_id)
	var ok: bool = bool(result.get("ok", false))
	if not ok:
		var err: String = str(result.get("err", "unknown error"))
		StatusLbl.text = "LOAD FAILED: see console for reason"
		if SFLog.LOGGING_ENABLED:
			push_error("DEV_MAP_LOADER: MAP LOAD FAIL for %s err=%s" % [map_id, err])
		return
	var d: Dictionary = result.get("data", {}) as Dictionary
	SFLog.debug("DEV_MAP_LOADER: load_map ok size=%s keys=%s" % [d.size(), str(d.keys())])

	SFLog.debug("DEV_MAP_LOADER: calling MAP_APPLIER.apply_map(...)")
	MAP_APPLIER.apply_map(_arena, d)
	SFLog.debug("DEV_MAP_LOADER: apply_map DONE")

	_center_cam()
	if _arena.has_method("notify_map_built"):
		_arena.call("notify_map_built")
	if _arena.has_method("fitcam_once"):
		_arena.call("fitcam_once")
	_boot_done = true
	# After we successfully load once, the dev loader should never be able to fire again in-game.
	# Hide + disable input + free.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	queue_free()
	return

	# Sanity logs
	var maproot := _arena.get_node_or_null("MapRoot")
	var lr := maproot.get_node_or_null("LaneRenderer") if maproot else null
	var hr := maproot.get_node_or_null("HiveRenderer") if maproot else null

	SFLog.debug("DEV_MAP_LOADER: after_build maproot=%s children=%s" % [str(maproot), maproot.get_child_count() if maproot else -1])
	SFLog.debug("DEV_MAP_LOADER: renderer vis hr=%s lr=%s hr_children=%s lr_children=%s"
		% [hr != null and hr.visible, lr != null and lr.visible, hr.get_child_count() if hr else -1, lr.get_child_count() if lr else -1])

	var grid_w: int = int(d.get("grid_width", d.get("grid_w", 0)))
	var grid_h: int = int(d.get("grid_height", d.get("grid_h", 0)))
	var hives_v: Variant = d.get("hives", [])
	var entity_count: int = (hives_v as Array).size() if typeof(hives_v) == TYPE_ARRAY else 0
	StatusLbl.text = "Loaded: %s (%dx%d) entities=%d" % [map_id, grid_w, grid_h, entity_count]
	if panel_ui != null:
		panel_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel_ui.offset_left = 8
		panel_ui.offset_top = 8
		panel_ui.offset_right = panel_ui.offset_left + panel_ui.size.x
		panel_ui.offset_bottom = panel_ui.offset_top + panel_ui.size.y
	# Post-load UI state: you loaded successfully, now you can start
	LoadBtn.visible = false
	StartBtn.visible = true
	StartBtn.disabled = false
	StartBtn.grab_focus()

func _on_start_pressed() -> void:
	SFLog.debug("DEV_MAP_LOADER: START pressed")
	if _arena == null:
		StatusLbl.text = "Arena not injected"
		return
	_arena.set("autostart", true)
	if _arena.has_method("start_sim"):
		_arena.call("start_sim")
		SFLog.debug("DEV_MAP_LOADER: START pressed -> called Arena.start_sim()")
		StatusLbl.text = "Sim started."
	elif _arena.has_method("start"):
		_arena.call("start")
		SFLog.debug("DEV_MAP_LOADER: START pressed -> called Arena.start()")
		StatusLbl.text = "Sim started."
	else:
		_arena.set("sim_running", true)
		SFLog.debug("DEV_MAP_LOADER: START pressed -> set arena.sim_running=true")
		StatusLbl.text = "No Arena.start_sim()/start()"
	SFLog.debug("DEV_MAP_LOADER: arena sim_running=%s autostart=%s" % [
		str(_arena.get("sim_running")),
		str(_arena.get("autostart"))
	])
	hide()
	set_process(false)
	set_process_input(false)

func load_map(map_id_path: String) -> void:
	map_id = map_id_path
	SFLog.debug("DEV_MAP_LOADER: load_map() %s" % map_id)
	if has_method("_on_load_pressed"):
		call("_on_load_pressed")
	elif has_method("_on_load_button_pressed"):
		call("_on_load_button_pressed")
	else:
		if SFLog.LOGGING_ENABLED:
			push_error("DEV_MAP_LOADER: No load handler found (_on_load_pressed/_on_load_button_pressed)")

func _has_prop(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if String(p.name) == prop_name:
			return true
	return false

func _clear_map(arena: Node2D) -> void:
	var hr := arena.get_node("MapRoot/HiveRenderer")
	var lr := arena.get_node("MapRoot/LaneRenderer")
	for c in hr.get_children():
		c.queue_free()
	for c in lr.get_children():
		c.queue_free()

func _center_cam() -> void:
	var world := Vector2(CANON_GRID_W * cell_size, CANON_GRID_H * cell_size)
	if _arena.has_method("cam_set"):
		var cam := _arena.get_node("Camera2D") as Camera2D
		_arena.call("cam_set", "dev_loader_center", world * 0.5, cam.zoom)
	else:
		(_arena.get_node("Camera2D") as Camera2D).global_position = world * 0.5
