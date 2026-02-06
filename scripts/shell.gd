extends Node
const SFLog := preload("res://scripts/util/sf_log.gd")
const SHELL_BUFFER_ROOT_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/TopBufferBackground"
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"

@export var start_in_menu := true
@export var enable_dev_map_loader := true
@export var show_dev_map_loader_in_game := true
@export var game_scene_path := "res://scenes/Main.tscn"
@export var main_menu_scene_path := "res://scenes/MainMenu.tscn"

@onready var menu_root: Control = $MenuRoot
@onready var arena_root: CanvasItem = $ArenaRoot
@onready var menu_panel: Control = $MenuRoot/MenuPanel
@onready var play_button: Button = $MenuRoot/MenuPanel/VBox/PlayButton
@onready var dev_button: Button = $MenuRoot/MenuPanel/VBox/DevButton
@onready var back_button: Button = $MenuRoot/BackButton
@onready var back_overlay: Control = $ArenaRoot/BackOverlay

var _arena_instance: Node = null
var _dev_loader: CanvasItem = null
var _last_power_bar_visible: int = -1
var _ui_watch_prev: Dictionary = {}

func _ready() -> void:
	set_process(true)
	if SFLog.LOGGING_ENABLED:
		print("MAIN FLAGS: start_in_menu=", start_in_menu,
		" enable_dev_map_loader=", enable_dev_map_loader,
		" show_dev_map_loader_in_game=", show_dev_map_loader_in_game)
	if play_button != null:
		play_button.pressed.connect(_on_play_pressed)
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
	if dev_button != null:
		dev_button.pressed.connect(_on_dev_pressed)
	if dev_button != null:
		dev_button.disabled = not enable_dev_map_loader
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)
	if not OpsState.hud_changed.is_connected(_on_ops_ui_signal):
		OpsState.hud_changed.connect(_on_ops_ui_signal)
	if not OpsState.ops_state_changed.is_connected(_on_ops_ui_signal):
		OpsState.ops_state_changed.connect(_on_ops_ui_signal)
	if not OpsState.state_changed.is_connected(_on_ops_ui_signal):
		OpsState.state_changed.connect(_on_ops_ui_signal)
	call_deferred("_log_shell_buffer_boot")
	_set_menu_state(start_in_menu)
	if not start_in_menu:
		_start_game()

func _log_shell_buffer_boot() -> void:
	await get_tree().process_frame
	var top_buffer: Control = get_node_or_null(SHELL_TOP_BUFFER_PATH) as Control
	if top_buffer == null:
		print("UI_BUFFER_BOOT: missing path=", SHELL_TOP_BUFFER_PATH)
		return
	var rect: Rect2 = top_buffer.get_global_rect()
	var top_y: float = rect.position.y
	var aligned: bool = top_y >= -1.0 and top_y <= 1.0
	print("UI_BUFFER_BOOT:",
		" path=", str(top_buffer.get_path()),
		" rect=", rect,
		" top_y=", top_y,
		" aligned=", aligned
	)

func _set_menu_state(in_menu: bool) -> void:
	if menu_root != null:
		menu_root.visible = in_menu
	if arena_root != null:
		arena_root.visible = not in_menu
	if menu_panel != null:
		menu_panel.visible = in_menu
	if back_overlay != null:
		back_overlay.visible = not in_menu
	_update_back_parent(not in_menu)

func _update_back_parent(in_game: bool) -> void:
	if back_button == null:
		return
	var target_parent: Node = menu_root
	if in_game and back_overlay != null:
		target_parent = back_overlay
	if back_button.get_parent() != target_parent:
		back_button.reparent(target_parent)
	_position_back_button()

func _position_back_button() -> void:
	if back_button == null:
		return
	back_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_button.offset_left = 16.0
	back_button.offset_top = 16.0
	back_button.offset_right = 136.0
	back_button.offset_bottom = 52.0

func _on_play_pressed() -> void:
	_start_game()

func _start_game() -> void:
	if _arena_instance != null:
		_set_menu_state(false)
		return
	var packed := load(game_scene_path) as PackedScene
	if packed == null:
		if SFLog.LOGGING_ENABLED:
			push_error("SHELL: game_scene_path invalid: %s" % game_scene_path)
		return
	var inst := packed.instantiate()
	_arena_instance = inst
	if inst.has_method("start_game"):
		inst.set("start_in_menu", true)
		inst.set("enable_dev_map_loader", enable_dev_map_loader)
		inst.set("show_dev_map_loader_in_game", show_dev_map_loader_in_game)
	arena_root.add_child(inst)
	_set_menu_state(false)
	if inst.has_method("start_game"):
		inst.call_deferred("start_game")
	call_deferred("_sync_power_bar_buffer_placement")
	_cache_dev_loader()

func _on_back_pressed() -> void:
	_stop_game()

func _stop_game() -> void:
	if _arena_instance != null:
		_arena_instance.queue_free()
		_arena_instance = null
	_dev_loader = null
	_set_menu_state(true)

func _on_dev_pressed() -> void:
	_open_main_menu()

func _open_main_menu() -> void:
	if main_menu_scene_path.is_empty():
		return
	var err := get_tree().change_scene_to_file(main_menu_scene_path)
	if err != OK:
		if SFLog.LOGGING_ENABLED:
			push_error("SHELL: failed to open main menu: %s" % main_menu_scene_path)

func _show_dev_panel(show: bool) -> void:
	if _dev_loader == null:
		_cache_dev_loader()
	if _dev_loader == null:
		return
	_dev_loader.visible = show
	if show and _dev_loader.has_method("_apply_in_game_input_passthrough"):
		_dev_loader.call_deferred("_apply_in_game_input_passthrough")

func _cache_dev_loader() -> void:
	_dev_loader = null
	if not enable_dev_map_loader:
		return
	if _arena_instance == null:
		return
	var dml: CanvasItem = _arena_instance.get_node_or_null("UI/DevMapLoader") as CanvasItem
	if dml == null:
		dml = _arena_instance.find_child("DevMapLoader", true, false) as CanvasItem
	_dev_loader = dml
	if _dev_loader != null and _dev_loader.has_method("_apply_in_game_input_passthrough"):
		_dev_loader.call_deferred("_apply_in_game_input_passthrough")

func _on_viewport_size_changed() -> void:
	if _arena_instance == null:
		return
	call_deferred("_sync_power_bar_buffer_placement")

func _process(_delta: float) -> void:
	if _arena_instance == null:
		return
	_update_power_bar_visibility()
	_ui_watch_tick()

func _ui_watch_tick() -> void:
	var hud: Node = get_node_or_null("/root/Shell/HUDCanvasLayer")
	var top_bg: Node = get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground")

	if hud == null or top_bg == null:
		return

	var vp: Viewport = get_viewport()
	var vp_canvas: Transform2D = vp.get_canvas_transform()
	var vp_visible: Rect2 = vp.get_visible_rect()

	var hud_follow: bool = false
	var hud_off: Vector2 = Vector2.INF
	var hud_scale: Vector2 = Vector2.ONE
	var hud_rot: float = 0.0
	if hud is CanvasLayer:
		var cl: CanvasLayer = hud as CanvasLayer
		hud_follow = cl.follow_viewport_enabled
		hud_off = cl.offset
		hud_scale = cl.scale
		hud_rot = cl.rotation

	var tb_rect: Rect2 = Rect2()
	var tb_gt: Transform2D = Transform2D()
	if top_bg is Control:
		var c: Control = top_bg as Control
		tb_rect = c.get_global_rect()
		tb_gt = c.get_global_transform_with_canvas()

	var snap: Dictionary = {
		"vp_visible": vp_visible,
		"vp_canvas": vp_canvas,
		"hud_follow": hud_follow,
		"hud_off": hud_off,
		"hud_scale": hud_scale,
		"hud_rot": hud_rot,
		"tb_rect": tb_rect,
		"tb_gt": tb_gt,
	}

	if _ui_watch_prev.is_empty():
		_ui_watch_prev = snap
		print("UI_WATCH init ", snap)
		return

	var changed: Array[String] = []
	for k in snap.keys():
		if snap[k] != _ui_watch_prev.get(k):
			changed.append(k)

	if changed.size() > 0:
		print("UI_WATCH changed=", changed, " snap=", snap)
		_ui_watch_prev = snap

func _on_ops_ui_signal(_payload: Variant = null) -> void:
	if _arena_instance == null:
		return
	call_deferred("_update_power_bar_visibility")

func _sync_power_bar_buffer_placement() -> void:
	if _arena_instance == null:
		return
	var power_bar: Control = get_node_or_null(SHELL_POWER_BAR_PATH) as Control
	if power_bar == null:
		return

	# Editor-authoritative: PowerBarAnchor placement is authored in scene.
	# Do not create/move anchors or reposition the power bar at runtime.
	_update_power_bar_visibility()
	SFLog.info("POWERBAR_ANCHOR", {
		"bar_path": str(power_bar.get_path()),
		"bar_pos": power_bar.position,
		"bar_size": power_bar.size
	})

func _ensure_power_bar_anchor() -> Control:
	if _arena_instance == null:
		return null
	var top_buffer: Control = get_node_or_null(SHELL_TOP_BUFFER_PATH) as Control
	if top_buffer == null:
		return null
	var anchor: Control = top_buffer.get_node_or_null("PowerBarAnchor") as Control
	if anchor != null:
		return anchor
	# IMPORTANT:
	# Do NOT rewrite PowerBarAnchor geometry at runtime.
	# It is authored in scenes/Shell.tscn (under TopBufferBackground) and must remain stable.
	# Do not use legacy BufferRoot/PowerBarAnchor shims. PowerBar must remain under:
	# /root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground/PowerBarAnchor/PowerBar
	anchor = Control.new()
	anchor.name = "PowerBarAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 0.0
	anchor.anchor_top = 0.0
	anchor.anchor_right = 0.0
	anchor.anchor_bottom = 0.0
	top_buffer.add_child(anchor)
	return anchor

func _update_power_bar_visibility() -> void:
	if _arena_instance == null:
		return
	var power_bar: Control = get_node_or_null(SHELL_POWER_BAR_PATH) as Control
	if power_bar == null:
		return
	var is_live: bool = _is_match_live()
	power_bar.visible = is_live
	if _last_power_bar_visible != int(is_live):
		_last_power_bar_visible = int(is_live)
		SFLog.info("POWERBAR_VISIBLE", {
			"visible": is_live,
			"prematch_ms": int(OpsState.prematch_remaining_ms),
			"phase": int(OpsState.match_phase)
		})

func _is_match_live() -> bool:
	return int(OpsState.match_phase) == int(OpsState.MatchPhase.RUNNING) and int(OpsState.prematch_remaining_ms) <= 0
