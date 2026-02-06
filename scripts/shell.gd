extends Node
const SHELL_PATCH_REV: String = "rev_2026_02_06_a"
const SFLog := preload("res://scripts/util/sf_log.gd")
const SHELL_BUFFER_ROOT_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/TopBufferBackground"
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"
const DEFAULT_MAP_PATH: String = "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_TOWER_1.json"
const PENDING_APPLY_MAX_TRIES: int = 60

@export var start_in_menu := true
@export var enable_dev_map_loader := true
@export var show_dev_map_loader_in_game := true
@export var game_scene_path := "res://scenes/Main.tscn"
@export var main_menu_scene_path := "res://scenes/MainMenu.tscn"
@export var map_picker_panel_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel")
@export var map_list_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/MapList")
@export var select_map_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/SelectMapButton")
@export var play_selected_button_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/PickerButtonsRow/PlaySelectedButton")
@export var picker_back_button_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/PickerButtonsRow/PickerBackButton")
@export var dev_map_loader_path: NodePath = NodePath("DevMapLoader")
@export var fail_if_shell_script_not_running: bool = true

@onready var menu_root: Control = $MenuRoot
@onready var arena_root: CanvasItem = $ArenaRoot
@onready var menu_panel: Control = $MenuRoot/MenuPanel
@onready var dev_button: Button = $MenuRoot/MenuPanel/VBox/DevButton
@onready var back_button: Button = $MenuRoot/BackButton
@onready var back_overlay: Control = $ArenaRoot/BackOverlay
@onready var _map_picker_panel: Control = get_node_or_null(map_picker_panel_path) as Control
@onready var _map_list: ItemList = get_node_or_null(map_list_path) as ItemList
@onready var _select_map_button: Button = get_node_or_null(select_map_button_path) as Button
@onready var _play_selected_button: Button = get_node_or_null(play_selected_button_path) as Button
@onready var _picker_back_button: Button = get_node_or_null(picker_back_button_path) as Button

static var _shell_enter_count: int = 0
static var _shell_ready_count: int = 0
static var _shell_exit_count: int = 0

var _arena_instance: Node = null
var _dev_loader: CanvasItem = null
var _dev_map_loader: CanvasItem = null
var _last_power_bar_visible: int = -1
var _ui_watch_prev: Dictionary = {}
var _selected_map_path: String = ""
var _pending_map_path: String = ""
var _pending_apply_tries: int = 0
var _err_conn_ready: bool = false
var _frame_once: bool = false

func _install_error_hooks() -> void:
	if _err_conn_ready:
		return
	_err_conn_ready = true
	var tree: SceneTree = get_tree()
	if tree != null:
		if not tree.process_frame.is_connected(_on_process_frame_once):
			tree.process_frame.connect(_on_process_frame_once)
	print("ERROR_HOOKS_INSTALLED")

func _on_process_frame_once() -> void:
	if _frame_once:
		return
	_frame_once = true
	print("BOOT_BEACON 900: first_process_frame_reached")

func _safe_call(tag: String, fn: Callable) -> void:
	print("SAFE_CALL_BEGIN ", tag)
	fn.call()
	print("SAFE_CALL_END ", tag)

func _iid(n: Object) -> String:
	if n == null:
		return "<null>"
	return str(n.get_instance_id())

func _np(n: Node) -> String:
	if n == null:
		return "<null>"
	return str(n.get_path())

func _force_single_pressed_connection(btn: BaseButton, target: Object, method: String) -> void:
	if btn == null:
		return
	var sig: Signal = btn.pressed
	var conns: Array = sig.get_connections()
	print("SIG_DEDUPE before", {"btn": btn.name, "count": conns.size()})
	for c in conns:
		if c.has("callable"):
			var cb: Callable = c["callable"]
			if sig.is_connected(cb):
				sig.disconnect(cb)
	var call: Callable = Callable(target, method)
	if not sig.is_connected(call):
		sig.connect(call)
	var after: Array = sig.get_connections()
	print("SIG_DEDUPE after", {"btn": btn.name, "count": after.size()})

func _enter_tree() -> void:
	_install_error_hooks()
	_shell_enter_count += 1
	print("SHELL_LIFECYCLE enter #", _shell_enter_count, " iid=", _iid(self), " path=", _np(self))
	print("SHELL_ENTER_TREE_PROOF ", SHELL_PATCH_REV, " path=", get_path(), " script=", get_script())
	push_warning("SHELL_ENTER_TREE_PROOF " + SHELL_PATCH_REV + " path=" + str(get_path()))

func _ready() -> void:
	_install_error_hooks()
	_shell_ready_count += 1
	print("SHELL_LIFECYCLE ready #", _shell_ready_count, " iid=", _iid(self), " path=", _np(self))
	print("SHELL_READY_PROOF ", SHELL_PATCH_REV, " path=", get_path(), " script=", get_script())
	push_warning("SHELL_READY_PROOF " + SHELL_PATCH_REV + " path=" + str(get_path()))
	if fail_if_shell_script_not_running and str(get_script()).find("scripts/shell.gd") == -1:
		push_error("SHELL_SCRIPT_MISMATCH: expected scripts/shell.gd but got " + str(get_script()))
	print("BOOT_BEACON 010: after_ready_proof")
	call_deferred("_shell_post_ready_diag")
	print("BOOT_BEACON 020: after_call_deferred_post_diag")
	SFLog.info("SHELL_READY_PROOF", {
		"node_path": str(get_path()),
		"scene_file": get_tree().current_scene.scene_file_path if get_tree() != null and get_tree().current_scene != null else "<no_scene>",
		"script": str(get_script()),
		"name": name
	})
	set_process(true)
	if SFLog.LOGGING_ENABLED:
		print("MAIN FLAGS: start_in_menu=", start_in_menu,
		" enable_dev_map_loader=", enable_dev_map_loader,
		" show_dev_map_loader_in_game=", show_dev_map_loader_in_game)
	SFLog.info("MAP_PICKER_UI_RESOLVE", {
		"map_picker_panel": _map_picker_panel != null,
		"map_list": _map_list != null,
		"select_map_button": _select_map_button != null,
		"play_selected_button": _play_selected_button != null,
		"picker_back_button": _picker_back_button != null
	})
	print("BOOT_BEACON 030: before_resolve_map_picker_ui_nodes")
	_resolve_map_picker_ui_nodes()
	_resolve_dev_map_loader()
	print("BOOT_BEACON 040: after_resolve_map_picker_ui_nodes")
	print("BOOT_BEACON 050: before_wire_map_picker_ui")
	_safe_call("wire_map_picker_ui", Callable(self, "_wire_map_picker_ui"))
	print("BOOT_BEACON 060: after_wire_map_picker_ui")
	if back_button != null:
		if not back_button.pressed.is_connected(_on_back_pressed):
			back_button.pressed.connect(_on_back_pressed)
	if dev_button != null:
		if not dev_button.pressed.is_connected(_on_dev_pressed):
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
	print("BOOT_BEACON 070: before_startup_menu_flow")
	_set_menu_state(start_in_menu)
	print("BOOT_BEACON 080: after_startup_menu_flow")
	var menu_root_node: Node = get_node_or_null("MenuRoot")
	var menu_panel_node: CanvasItem = get_node_or_null("MenuRoot/MenuPanel") as CanvasItem
	print("MENU_VIS ", {
		"menu_root": menu_root_node != null,
		"menu_panel": menu_panel_node != null,
		"menu_panel_visible": menu_panel_node.visible if menu_panel_node != null else false,
		"map_picker_panel": _map_picker_panel != null,
		"map_picker_visible": (_map_picker_panel.visible if _map_picker_panel != null else false),
		"select_map_button": _select_map_button != null
	})
	if not start_in_menu:
		_start_game()
	print("BOOT_BEACON 090: after_start_game_check")

func _wire_map_picker_ui() -> void:
	print("MAP_PICKER_WIRE_BEGIN_RAW",
		" panel=", _map_picker_panel != null,
		" list=", _map_list != null,
		" select=", _select_map_button != null,
		" play=", _play_selected_button != null,
		" back=", _picker_back_button != null
	)
	SFLog.info("MAP_PICKER_WIRE_BEGIN", {
		"panel": _map_picker_panel != null,
		"list": _map_list != null,
		"select": _select_map_button != null,
		"play": _play_selected_button != null,
		"back": _picker_back_button != null
	})
	if _map_picker_panel == null or _map_list == null or _select_map_button == null or _play_selected_button == null or _picker_back_button == null:
		print("MAP_PICKER_WIRE_MISSING_RAW",
			" panel=", _diag_resolve(_map_picker_panel),
			" list=", _diag_resolve(_map_list),
			" select=", _diag_resolve(_select_map_button),
			" play=", _diag_resolve(_play_selected_button),
			" back=", _diag_resolve(_picker_back_button)
		)
		SFLog.error("MAP_PICKER_WIRE_MISSING_NODES", {
			"panel": _diag_resolve(_map_picker_panel),
			"list": _diag_resolve(_map_list),
			"select": _diag_resolve(_select_map_button),
			"play": _diag_resolve(_play_selected_button),
			"back": _diag_resolve(_picker_back_button)
		})
		return
	if not _select_map_button.pressed.is_connected(_on_select_map_pressed):
		_select_map_button.pressed.connect(_on_select_map_pressed)
	_force_single_pressed_connection(_play_selected_button, self, "_on_play_selected_pressed")
	if not _picker_back_button.pressed.is_connected(_on_picker_back_pressed):
		_picker_back_button.pressed.connect(_on_picker_back_pressed)
	if not _map_list.item_selected.is_connected(_on_map_item_selected):
		_map_list.item_selected.connect(_on_map_item_selected)
	SFLog.info("MAP_PICKER_WIRE_DONE", {})

func _diag_resolve(n: Node) -> String:
	if n == null:
		return "<null>"
	return str(n.get_path())

func _shell_post_ready_diag() -> void:
	print("SHELL_POST_READY_DIAG ", SHELL_PATCH_REV, " path=", get_path())
	var has_panel_np: bool = "map_picker_panel_path" in self
	var has_list_np: bool = "map_list_path" in self
	var has_select_np: bool = "select_map_button_path" in self
	var has_play_np: bool = "play_selected_button_path" in self
	var has_back_np: bool = "picker_back_button_path" in self
	print("MAP_PICKER_NODEPATHS_PRESENT ",
		"panel_np=", has_panel_np,
		" list_np=", has_list_np,
		" select_np=", has_select_np,
		" play_np=", has_play_np,
		" back_np=", has_back_np
	)
	if has_panel_np:
		print("panel_np=", map_picker_panel_path)
	if has_list_np:
		print("list_np=", map_list_path)
	if has_select_np:
		print("select_np=", select_map_button_path)
	if has_play_np:
		print("play_np=", play_selected_button_path)
	if has_back_np:
		print("back_np=", picker_back_button_path)
	var panel_ok: bool = _map_picker_panel != null
	var list_ok: bool = _map_list != null
	var select_ok: bool = _select_map_button != null
	var play_ok: bool = _play_selected_button != null
	var back_ok: bool = _picker_back_button != null
	print("MAP_PICKER_RESOLVED ",
		"panel=", panel_ok,
		" list=", list_ok,
		" select=", select_ok,
		" play=", play_ok,
		" back=", back_ok
	)

func _resolve_map_picker_ui_nodes() -> void:
	SFLog.info("MAP_PICKER_UI_NODEPATHS", {
		"map_picker_panel_np": str(map_picker_panel_path),
		"map_list_np": str(map_list_path),
		"select_map_button_np": str(select_map_button_path),
		"play_selected_button_np": str(play_selected_button_path),
		"picker_back_button_np": str(picker_back_button_path)
	})
	_map_picker_panel = get_node_or_null(map_picker_panel_path) as Control
	_map_list = get_node_or_null(map_list_path) as ItemList
	_select_map_button = get_node_or_null(select_map_button_path) as Button
	_play_selected_button = get_node_or_null(play_selected_button_path) as Button
	_picker_back_button = get_node_or_null(picker_back_button_path) as Button
	SFLog.info("MAP_PICKER_UI_RESOLVE2", {
		"map_picker_panel": _diag_resolve(_map_picker_panel),
		"map_list": _diag_resolve(_map_list),
		"select_map_button": _diag_resolve(_select_map_button),
		"play_selected_button": _diag_resolve(_play_selected_button),
		"picker_back_button": _diag_resolve(_picker_back_button)
	})

func _resolve_dev_map_loader() -> void:
	_dev_map_loader = get_node_or_null(dev_map_loader_path) as CanvasItem
	print("DEV_LOADER_RESOLVE ", {
		"path": str(dev_map_loader_path),
		"node": _np(_dev_map_loader),
		"iid": _iid(_dev_map_loader),
		"visible": (_dev_map_loader.visible if _dev_map_loader != null else false)
	})

func _resolve_dev_map_loader_node() -> Node:
	if _dev_loader != null:
		return _dev_loader
	_cache_dev_loader()
	return _dev_loader

func _exit_tree() -> void:
	_shell_exit_count += 1
	print("SHELL_LIFECYCLE exit #", _shell_exit_count, " iid=", _iid(self), " path=", _np(self))

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
	if _map_picker_panel != null:
		_map_picker_panel.visible = false
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

func _on_select_map_pressed() -> void:
	SFLog.info("MAP_PICKER_OPEN", {})
	_show_map_picker()

func _on_picker_back_pressed() -> void:
	SFLog.info("MAP_PICKER_CLOSE", {})
	if _map_picker_panel != null:
		_map_picker_panel.visible = false

func _on_play_selected_pressed() -> void:
	print("MAP_PICKER_PLAY_PRESSED", {"selected_path": _selected_map_path})
	SFLog.info("PLAY_SELECTED_PRESSED", {"map_path": _selected_map_path})
	if _selected_map_path == "":
		SFLog.error("MAP_PICKER_PLAY_NO_SELECTION", {})
		return
	if not FileAccess.file_exists(_selected_map_path):
		SFLog.error("MAP_PICKER_PLAY_FILE_MISSING", {"path": _selected_map_path})
		return
	_pending_map_path = _selected_map_path
	_pending_apply_tries = 0
	if _arena_instance != null:
		SFLog.info("PENDING_MAP_APPLY_IMMEDIATE", {"path": _pending_map_path})
		_apply_pending_map_if_ready()
		return
	SFLog.info("PENDING_MAP_START_GAME_FIRST", {"path": _pending_map_path})
	_start_game()
	call_deferred("_apply_pending_map_if_ready")

func _apply_pending_map_if_ready() -> void:
	if _pending_map_path == "":
		return
	_pending_apply_tries += 1
	if _arena_instance == null:
		if _pending_apply_tries >= PENDING_APPLY_MAX_TRIES:
			SFLog.error("PENDING_MAP_ARENA_NEVER_READY", {"path": _pending_map_path, "tries": _pending_apply_tries})
			_pending_map_path = ""
			return
		call_deferred("_apply_pending_map_if_ready")
		return
	SFLog.info("PENDING_MAP_ARENA_READY_APPLYING", {"path": _pending_map_path, "tries": _pending_apply_tries})
	var p: String = _pending_map_path
	_pending_map_path = ""
	_apply_map_then_start(p)

func _show_map_picker() -> void:
	print("MAP_PICKER_SHOW_CALL ", {
		"shell_iid": _iid(self),
		"panel": _np(_map_picker_panel),
		"list": _np(_map_list)
	})
	SFLog.info("MAP_PICKER_SHOW", {
		"panel": _map_picker_panel != null,
		"list": _map_list != null
	})
	if _map_picker_panel == null or _map_list == null:
		SFLog.error("MAP_PICKER_SHOW_MISSING_NODES", {
			"panel": _diag_resolve(_map_picker_panel),
			"list": _diag_resolve(_map_list)
		})
		return
	_scan_maps_into_list()
	_map_picker_panel.visible = true
	if _map_list.item_count > 0:
		_map_list.select(0)
		_on_map_item_selected(0)

func _scan_maps_into_list() -> void:
	var folder: String = "res://maps/json"
	_selected_map_path = ""
	if _map_list == null:
		SFLog.error("MAP_SCAN_NO_MAP_LIST", {"folder": folder})
		return
	_map_list.clear()
	_map_list.set_meta("paths", PackedStringArray())
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		SFLog.error("MAP_SCAN_DIR_OPEN_FAIL", {"folder": folder})
		return
	var paths: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	while true:
		var f: String = dir.get_next()
		if f == "":
			break
		if dir.current_is_dir():
			continue
		if not f.ends_with(".json"):
			continue
		var full_path: String = folder.path_join(f)
		paths.append(full_path)
	dir.list_dir_end()
	paths.sort()
	for p in paths:
		_map_list.add_item(p.get_file())
	_map_list.set_meta("paths", paths)
	SFLog.info("MAP_SCAN_DONE", {"folder": folder, "count": paths.size()})

func _on_map_item_selected(index: int) -> void:
	if _map_list == null:
		return
	if index < 0 or index >= _map_list.item_count:
		return
	var map_path := ""
	var meta: Variant = _map_list.get_item_metadata(index)
	if typeof(meta) == TYPE_STRING:
		map_path = str(meta)
	else:
		if not _map_list.has_meta("paths"):
			SFLog.error("MAP_PICKER_NO_PATHS_META", {})
			return
		var paths: PackedStringArray = _map_list.get_meta("paths") as PackedStringArray
		if index >= 0 and index < paths.size():
			map_path = paths[index]
	if map_path.is_empty():
		SFLog.error("MAP_SELECTED_EMPTY", {"index": index})
		return
	_selected_map_path = map_path
	SFLog.info("MAP_PICKER_SELECTED", {"map_path": _selected_map_path})
	print("MAP_PICKER_SELECTED_RAW", {"index": index, "path": _selected_map_path})

func _apply_map_then_start(map_path: String) -> void:
	print("APPLY_MAP_THEN_START 010", {"map_path": map_path})
	print("APPLY_MAP_THEN_START_BEGIN", {"map_path": map_path})
	if map_path == "":
		SFLog.error("APPLY_MAP_EMPTY_PATH", {})
		SFLog.error("APPLY_MAP_BAIL_EMPTY_PATH", {})
		return
	if not FileAccess.file_exists(map_path):
		SFLog.error("APPLY_MAP_FILE_MISSING", {"path": map_path})
		SFLog.error("APPLY_MAP_BAIL_FILE_MISSING", {"path": map_path})
		return
	print("APPLY_MAP_THEN_START 020", {
		"arena_instance_null": (_arena_instance == null),
		"arena_instance": str(_arena_instance) if _arena_instance != null else "<null>"
	})
	if _arena_instance == null:
		SFLog.info("APPLY_MAP_THEN_START_DEFERRED_NO_ARENA", {"map_path": map_path})
		_pending_map_path = map_path
		_pending_apply_tries = 0
		_start_game()
		call_deferred("_apply_pending_map_if_ready")
		return
	if not ResourceLoader.exists(map_path):
		SFLog.error("MAP_PATH_NOT_FOUND", {"map_path": map_path})
		SFLog.error("MAP_APPLY_FAIL", {"map_path": map_path, "err": "missing_resource"})
		SFLog.error("APPLY_MAP_BAIL_MISSING_RESOURCE", {"map_path": map_path})
		return
	_selected_map_path = map_path
	SFLog.info("MAP_APPLY_REQUEST", {"map_path": map_path})
	SFLog.info("MAP_APPLY_ENTRY", {"map_path": map_path})
	print("APPLY_MAP_THEN_START 030", {"dev_loader_before": _dev_loader != null})
	_cache_dev_loader()
	print("APPLY_MAP_THEN_START 040", {
		"dev_loader_after": _dev_loader != null,
		"dev_loader_path": (str(_dev_loader.get_path()) if _dev_loader != null else "<null>"),
		"dev_loader_has_load_map": (_dev_loader.has_method("load_map") if _dev_loader != null else false)
	})
	if _dev_loader != null and _dev_loader.has_method("load_map"):
		print("APPLY_MAP_THEN_START 050_CALLING_ACTION", {"action": "dev_loader_load_map", "map_path": map_path})
		_dev_loader.call("load_map", map_path)
		print("APPLY_MAP_THEN_START 060_ACTION_RETURNED", {"action": "dev_loader_load_map"})
	else:
		SFLog.error("APPLY_MAP_NO_DEV_LOADER", {"map_path": map_path})
		return
	print("APPLY_MAP_THEN_START NOTE", {"note": "Dev picker uses DevMapLoader.load_map; skipping gamebot_set_vs_or_next_map_id may be safe."})
	print("APPLY_MAP_THEN_START 050_CALLING_ACTION", {"action": "gamebot_set_vs_or_next_map_id", "map_path": map_path})
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null:
		if gamebot.has_method("set_vs"):
			gamebot.call("set_vs", map_path)
		else:
			gamebot.set("next_map_id", map_path)
	else:
		SFLog.error("MAP_APPLY_FAIL", {"map_path": map_path, "err": "missing_gamebot"})
		SFLog.error("APPLY_MAP_BAIL_MISSING_GAMEBOT", {"map_path": map_path})
	print("APPLY_MAP_THEN_START 060_ACTION_RETURNED", {})
	SFLog.info("MAP_START_GAME", {"map_path": map_path})
	print("APPLY_MAP_THEN_START 050_CALLING_ACTION", {"action": "start_game", "map_path": map_path})
	_start_game()
	print("APPLY_MAP_THEN_START 060_ACTION_RETURNED", {"action": "start_game"})
	call_deferred("_verify_map_applied_and_start", map_path)
	SFLog.info("APPLY_MAP_THEN_START_DONE", {"map_path": map_path})

func _verify_map_applied_and_start(map_path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var hive_count: int = _get_hive_count()
	if hive_count <= 0:
		SFLog.error("START_BLOCKED_NO_HIVES", {"map_path": map_path})
		_stop_game()
		return
	SFLog.info("MAP_APPLY_SUCCESS", {"map_path": map_path, "hive_count": hive_count})
	SFLog.info("MAP_PICKER_HIDE", {"map_path": map_path})
	if _map_picker_panel != null:
		_map_picker_panel.visible = false

func _get_hive_count() -> int:
	if _arena_instance != null and _arena_instance.has_method("get_hive_count"):
		return int(_arena_instance.call("get_hive_count"))
	var st: GameState = OpsState.get_state() if OpsState != null else null
	if st != null and st.hives != null:
		return int(st.hives.size())
	return 0

func _ensure_game_instance() -> void:
	if _arena_instance != null:
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
	var hud_layer: CanvasLayer = get_node_or_null("/root/Shell/HUDCanvasLayer") as CanvasLayer
	var world_layer: CanvasLayer = inst.get_node_or_null("WorldCanvasLayer") as CanvasLayer
	var wvp: Node = null
	if world_layer != null:
		wvp = world_layer.get_node_or_null("WorldViewportContainer")
	print("LAYER_ORDER hud=", hud_layer.layer if hud_layer != null else -1,
		" world=", world_layer.layer if world_layer != null else -1,
		" wvp=", str(wvp.get_path()) if wvp != null else "<null>"
	)
	call_deferred("_sync_power_bar_buffer_placement")
	_cache_dev_loader()

func _enter_game() -> void:
	if _arena_instance == null:
		return
	_set_menu_state(false)
	if _arena_instance.has_method("start_game"):
		_arena_instance.call_deferred("start_game")

func _start_game() -> void:
	_ensure_game_instance()
	_enter_game()


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
	print("DEV_LOADER_SHOW_CALL ", {
		"shell_iid": _iid(self),
		"node": _np(_dev_map_loader),
		"visible_before": (_dev_map_loader.visible if _dev_map_loader != null else false)
	})
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
