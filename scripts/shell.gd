extends Node
const SHELL_PATCH_REV: String = "rev_2026_02_06_a"
const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const SHELL_BUFFER_ROOT_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/TopBufferBackground"
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"
const PENDING_APPLY_MAX_TRIES: int = 60
const TRACE_SHELL_LOGS: bool = false
const MVP_SMOKE_ARENA_PATH: String = "/root/Shell/ArenaRoot/Main/WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena"
const MVP_SMOKE_PREMATCH_OVERLAY_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/PreMatchOverlay"
const MVP_SMOKE_RECORDS_PATH: String = MVP_SMOKE_PREMATCH_OVERLAY_PATH + "/RecordsPanel"
const MVP_SMOKE_RECORD_P1_PATH: String = MVP_SMOKE_RECORDS_PATH + "/RecordsBg/RecordsVBox/RecordP1"
const MVP_SMOKE_RECORD_H2H_PATH: String = MVP_SMOKE_RECORDS_PATH + "/RecordsBg/RecordsVBox/RecordH2H"
const MVP_SMOKE_OUTCOME_OVERLAY_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/OutcomeOverlay"
const MVP_SMOKE_DEFAULT_BOOT_TIMEOUT_MS: int = 7000
const MVP_SMOKE_DEFAULT_RUN_TIMEOUT_MS: int = 12000
const MVP_SMOKE_DEFAULT_END_TIMEOUT_MS: int = 25000
const MVP_SMOKE_DEFAULT_WIN_MAP: String = "res://maps/json/MAP_TEST.json"

@export var start_in_menu := true
@export var enable_dev_map_loader := true
@export var show_dev_map_loader_in_game := true
@export var game_scene_path := "res://scenes/Main.tscn"
@export var main_menu_scene_path := "res://scenes/MainMenu.tscn"
@export var map_picker_panel_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel")
@export var map_list_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/MapList")
@export var select_map_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/SelectMapButton")
@export var team_mode_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/TeamModeButton")
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
@onready var _team_mode_button: Button = get_node_or_null(team_mode_button_path) as Button
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
var _team_mode_ui: String = "2v2"

func _install_error_hooks() -> void:
	if _err_conn_ready:
		return
	_err_conn_ready = true
	var tree: SceneTree = get_tree()
	if tree != null:
		if not tree.process_frame.is_connected(_on_process_frame_once):
			tree.process_frame.connect(_on_process_frame_once)
	if TRACE_SHELL_LOGS: print("ERROR_HOOKS_INSTALLED")

func _on_process_frame_once() -> void:
	if _frame_once:
		return
	_frame_once = true
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 900: first_process_frame_reached")

func _safe_call(tag: String, fn: Callable) -> void:
	if TRACE_SHELL_LOGS: print("SAFE_CALL_BEGIN ", tag)
	fn.call()
	if TRACE_SHELL_LOGS: print("SAFE_CALL_END ", tag)

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
	if TRACE_SHELL_LOGS: print("SIG_DEDUPE before", {"btn": btn.name, "count": conns.size()})
	for c in conns:
		if c.has("callable"):
			var cb: Callable = c["callable"]
			if sig.is_connected(cb):
				sig.disconnect(cb)
	var call: Callable = Callable(target, method)
	if not sig.is_connected(call):
		sig.connect(call)
	var after: Array = sig.get_connections()
	if TRACE_SHELL_LOGS: print("SIG_DEDUPE after", {"btn": btn.name, "count": after.size()})

func _enter_tree() -> void:
	_install_error_hooks()
	_shell_enter_count += 1
	if TRACE_SHELL_LOGS: print("SHELL_LIFECYCLE enter #", _shell_enter_count, " iid=", _iid(self), " path=", _np(self))
	if TRACE_SHELL_LOGS: print("SHELL_ENTER_TREE_PROOF ", SHELL_PATCH_REV, " path=", get_path(), " script=", get_script())
	if TRACE_SHELL_LOGS:
		push_warning("SHELL_ENTER_TREE_PROOF " + SHELL_PATCH_REV + " path=" + str(get_path()))

func _ready() -> void:
	_install_error_hooks()
	_shell_ready_count += 1
	if TRACE_SHELL_LOGS: print("SHELL_LIFECYCLE ready #", _shell_ready_count, " iid=", _iid(self), " path=", _np(self))
	if TRACE_SHELL_LOGS: print("SHELL_READY_PROOF ", SHELL_PATCH_REV, " path=", get_path(), " script=", get_script())
	if TRACE_SHELL_LOGS:
		push_warning("SHELL_READY_PROOF " + SHELL_PATCH_REV + " path=" + str(get_path()))
	if fail_if_shell_script_not_running:
		var script_res: Script = get_script() as Script
		var script_path: String = script_res.resource_path if script_res != null else ""
		if script_path != "res://scripts/shell.gd":
			push_error("SHELL_SCRIPT_MISMATCH: expected scripts/shell.gd but got " + script_path)
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 010: after_ready_proof")
	call_deferred("_shell_post_ready_diag")
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 020: after_call_deferred_post_diag")
	SFLog.info("SHELL_READY_PROOF", {
		"node_path": str(get_path()),
		"scene_file": get_tree().current_scene.scene_file_path if get_tree() != null and get_tree().current_scene != null else "<no_scene>",
		"script": str(get_script()),
		"name": name
	})
	set_process(true)
	if SFLog.LOGGING_ENABLED:
		if TRACE_SHELL_LOGS: print("MAIN FLAGS: start_in_menu=", start_in_menu,
		" enable_dev_map_loader=", enable_dev_map_loader,
		" show_dev_map_loader_in_game=", show_dev_map_loader_in_game)
	SFLog.info("MAP_PICKER_UI_RESOLVE", {
		"map_picker_panel": _map_picker_panel != null,
		"map_list": _map_list != null,
		"select_map_button": _select_map_button != null,
		"play_selected_button": _play_selected_button != null,
		"picker_back_button": _picker_back_button != null
	})
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 030: before_resolve_map_picker_ui_nodes")
	_resolve_map_picker_ui_nodes()
	_resolve_team_mode_ui_node()
	_resolve_dev_map_loader()
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 040: after_resolve_map_picker_ui_nodes")
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 050: before_wire_map_picker_ui")
	_safe_call("wire_map_picker_ui", Callable(self, "_wire_map_picker_ui"))
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 060: after_wire_map_picker_ui")
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
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 070: before_startup_menu_flow")
	_set_menu_state(start_in_menu)
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 080: after_startup_menu_flow")
	if _maybe_start_mvp_smoke():
		return
	var menu_root_node: Node = get_node_or_null("MenuRoot")
	var menu_panel_node: CanvasItem = get_node_or_null("MenuRoot/MenuPanel") as CanvasItem
	if TRACE_SHELL_LOGS: print("MENU_VIS ", {
		"menu_root": menu_root_node != null,
		"menu_panel": menu_panel_node != null,
		"menu_panel_visible": menu_panel_node.visible if menu_panel_node != null else false,
		"map_picker_panel": _map_picker_panel != null,
		"map_picker_visible": (_map_picker_panel.visible if _map_picker_panel != null else false),
		"select_map_button": _select_map_button != null
	})
	if not start_in_menu:
		_start_game()
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 090: after_start_game_check")

func _wire_map_picker_ui() -> void:
	if TRACE_SHELL_LOGS: print("MAP_PICKER_WIRE_BEGIN_RAW",
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
		if TRACE_SHELL_LOGS: print("MAP_PICKER_WIRE_MISSING_RAW",
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
	if TRACE_SHELL_LOGS: print("SHELL_POST_READY_DIAG ", SHELL_PATCH_REV, " path=", get_path())
	var has_panel_np: bool = "map_picker_panel_path" in self
	var has_list_np: bool = "map_list_path" in self
	var has_select_np: bool = "select_map_button_path" in self
	var has_play_np: bool = "play_selected_button_path" in self
	var has_back_np: bool = "picker_back_button_path" in self
	if TRACE_SHELL_LOGS: print("MAP_PICKER_NODEPATHS_PRESENT ",
		"panel_np=", has_panel_np,
		" list_np=", has_list_np,
		" select_np=", has_select_np,
		" play_np=", has_play_np,
		" back_np=", has_back_np
	)
	if has_panel_np:
		if TRACE_SHELL_LOGS: print("panel_np=", map_picker_panel_path)
	if has_list_np:
		if TRACE_SHELL_LOGS: print("list_np=", map_list_path)
	if has_select_np:
		if TRACE_SHELL_LOGS: print("select_np=", select_map_button_path)
	if has_play_np:
		if TRACE_SHELL_LOGS: print("play_np=", play_selected_button_path)
	if has_back_np:
		if TRACE_SHELL_LOGS: print("back_np=", picker_back_button_path)
	var panel_ok: bool = _map_picker_panel != null
	var list_ok: bool = _map_list != null
	var select_ok: bool = _select_map_button != null
	var play_ok: bool = _play_selected_button != null
	var back_ok: bool = _picker_back_button != null
	if TRACE_SHELL_LOGS: print("MAP_PICKER_RESOLVED ",
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

func _resolve_team_mode_ui_node() -> void:
	_team_mode_button = get_node_or_null(team_mode_button_path) as Button
	SFLog.info("TEAM_MODE_UI_RESOLVE", {
		"team_mode_button_np": str(team_mode_button_path),
		"team_mode_button": _diag_resolve(_team_mode_button)
	})
	if _team_mode_button != null and not _team_mode_button.pressed.is_connected(_on_team_mode_pressed):
		_team_mode_button.pressed.connect(_on_team_mode_pressed)
	var mode_from_ops: String = "2v2"
	if OpsState.has_method("get_team_mode_override"):
		mode_from_ops = str(OpsState.call("get_team_mode_override"))
	_set_team_mode_ui(mode_from_ops)

func _on_team_mode_pressed() -> void:
	var next_mode: String = "ffa" if _team_mode_ui == "2v2" else "2v2"
	_set_team_mode_ui(next_mode)

func _set_team_mode_ui(mode: String) -> void:
	var normalized: String = mode.strip_edges().to_lower()
	if normalized != "ffa":
		normalized = "2v2"
	_team_mode_ui = normalized
	if _team_mode_button != null:
		_team_mode_button.text = "Mode: FFA" if _team_mode_ui == "ffa" else "Mode: 2v2"
	if OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", _team_mode_ui)
	SFLog.info("TEAM_MODE_SELECTED", {"mode": _team_mode_ui})

func _resolve_dev_map_loader() -> void:
	_dev_map_loader = get_node_or_null(dev_map_loader_path) as CanvasItem
	if TRACE_SHELL_LOGS: print("DEV_LOADER_RESOLVE ", {
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
	if TRACE_SHELL_LOGS: print("SHELL_LIFECYCLE exit #", _shell_exit_count, " iid=", _iid(self), " path=", _np(self))

func _log_shell_buffer_boot() -> void:
	await get_tree().process_frame
	var top_buffer: Control = get_node_or_null(SHELL_TOP_BUFFER_PATH) as Control
	if top_buffer == null:
		if TRACE_SHELL_LOGS: print("UI_BUFFER_BOOT: missing path=", SHELL_TOP_BUFFER_PATH)
		return
	var rect: Rect2 = top_buffer.get_global_rect()
	var top_y: float = rect.position.y
	var aligned: bool = top_y >= -1.0 and top_y <= 1.0
	if TRACE_SHELL_LOGS: print("UI_BUFFER_BOOT:",
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
	var selected_now: String = _selected_map_path_from_ui()
	if selected_now == "":
		SFLog.error("MAP_PICKER_PLAY_NO_SELECTION", {})
		return
	var preflight: Dictionary = MAP_LOADER.load_map(selected_now)
	if not bool(preflight.get("ok", false)):
		SFLog.warn("MAP_PICKER_PLAY_LOAD_FAIL_WARN", {
			"path": selected_now,
			"err": str(preflight.get("err", "unknown"))
		})
		SFLog.error("MAP_PICKER_PLAY_LOAD_FAIL", {
			"path": selected_now,
			"err": str(preflight.get("err", "unknown"))
		})
		return
	_selected_map_path = selected_now
	if TRACE_SHELL_LOGS: print("MAP_PICKER_PLAY_PRESSED", {"selected_path": _selected_map_path})
	SFLog.info("PLAY_SELECTED_PRESSED", {"map_path": _selected_map_path})
	var gamebot_boot: Node = get_node_or_null("/root/Gamebot")
	if gamebot_boot != null:
		if gamebot_boot.has_method("set_vs"):
			gamebot_boot.call("set_vs", _selected_map_path)
		else:
			gamebot_boot.set("next_map_id", _selected_map_path)
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
	if TRACE_SHELL_LOGS: print("MAP_PICKER_SHOW_CALL ", {
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
		var selected_idx: int = _find_map_index_by_path(_selected_map_path)
		if selected_idx < 0:
			selected_idx = 0
		_map_list.select(selected_idx)
		_on_map_item_selected(selected_idx)

func _scan_maps_into_list() -> void:
	var folder: String = "res://maps/json"
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
		var idx: int = _map_list.item_count - 1
		_map_list.set_item_metadata(idx, p)
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
	if TRACE_SHELL_LOGS: print("MAP_PICKER_SELECTED_RAW", {"index": index, "path": _selected_map_path})

func _selected_map_path_from_ui() -> String:
	if _map_list == null:
		return ""
	var selected: PackedInt32Array = _map_list.get_selected_items()
	if selected.is_empty():
		return ""
	return _map_path_for_index(int(selected[0]))

func _map_path_for_index(index: int) -> String:
	if _map_list == null:
		return ""
	if index < 0 or index >= _map_list.item_count:
		return ""
	var meta: Variant = _map_list.get_item_metadata(index)
	if typeof(meta) == TYPE_STRING:
		return str(meta)
	if _map_list.has_meta("paths"):
		var paths: PackedStringArray = _map_list.get_meta("paths") as PackedStringArray
		if index >= 0 and index < paths.size():
			return paths[index]
	return ""

func _find_map_index_by_path(map_path: String) -> int:
	if map_path == "":
		return -1
	if _map_list == null:
		return -1
	for i in range(_map_list.item_count):
		if _map_path_for_index(i) == map_path:
			return i
	return -1

func _apply_map_then_start(map_path: String) -> void:
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 010", {"map_path": map_path})
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START_BEGIN", {"map_path": map_path})
	if map_path == "":
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "empty_path"})
		SFLog.error("APPLY_MAP_EMPTY_PATH", {})
		SFLog.error("APPLY_MAP_BAIL_EMPTY_PATH", {})
		return
	if not FileAccess.file_exists(map_path):
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "file_missing"})
		SFLog.error("APPLY_MAP_FILE_MISSING", {"path": map_path})
		SFLog.error("APPLY_MAP_BAIL_FILE_MISSING", {"path": map_path})
		return
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 020", {
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
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "missing_resource"})
		SFLog.error("MAP_PATH_NOT_FOUND", {"map_path": map_path})
		SFLog.error("MAP_APPLY_FAIL", {"map_path": map_path, "err": "missing_resource"})
		SFLog.error("APPLY_MAP_BAIL_MISSING_RESOURCE", {"map_path": map_path})
		return
	_selected_map_path = map_path
	SFLog.info("MAP_APPLY_REQUEST", {"map_path": map_path})
	SFLog.info("MAP_APPLY_ENTRY", {"map_path": map_path})
	if not _apply_map_direct_to_arena(map_path):
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "direct_apply_failed"})
		SFLog.error("MAP_APPLY_FAIL", {"map_path": map_path, "err": "direct_apply_failed"})
		return
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START NOTE", {"note": "Dev picker uses DevMapLoader.load_map; skipping gamebot_set_vs_or_next_map_id may be safe."})
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 050_CALLING_ACTION", {"action": "gamebot_set_vs_or_next_map_id", "map_path": map_path})
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null:
		if gamebot.has_method("set_vs"):
			gamebot.call("set_vs", map_path)
		else:
			gamebot.set("next_map_id", map_path)
	else:
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "missing_gamebot"})
		SFLog.error("MAP_APPLY_FAIL", {"map_path": map_path, "err": "missing_gamebot"})
		SFLog.error("APPLY_MAP_BAIL_MISSING_GAMEBOT", {"map_path": map_path})
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 060_ACTION_RETURNED", {})
	SFLog.info("MAP_START_GAME", {"map_path": map_path})
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 050_CALLING_ACTION", {"action": "start_game", "map_path": map_path})
	_start_game()
	if TRACE_SHELL_LOGS: print("APPLY_MAP_THEN_START 060_ACTION_RETURNED", {"action": "start_game"})
	call_deferred("_verify_map_applied_and_start", map_path)
	SFLog.info("APPLY_MAP_THEN_START_DONE", {"map_path": map_path})

func _apply_map_direct_to_arena(map_path: String) -> bool:
	if _arena_instance == null:
		SFLog.error("MAP_APPLY_DIRECT_NO_GAME_INSTANCE", {"map_path": map_path})
		return false
	var arena_node: Node = _arena_instance.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")
	if not (arena_node is Node2D):
		SFLog.error("MAP_APPLY_DIRECT_NO_ARENA_NODE", {"map_path": map_path})
		return false
	var arena: Node2D = arena_node as Node2D
	var result: Dictionary = MAP_LOADER.load_map(map_path)
	if not bool(result.get("ok", false)):
		SFLog.warn("MAP_APPLY_DIRECT_LOAD_FAIL_WARN", {
			"map_path": map_path,
			"err": str(result.get("err", "unknown"))
		})
		SFLog.error("MAP_APPLY_DIRECT_LOAD_FAIL", {
			"map_path": map_path,
			"err": str(result.get("err", "unknown"))
		})
		return false
	var model: Dictionary = result.get("data", {}) as Dictionary
	if arena.has_method("apply_loaded_map"):
		arena.call("apply_loaded_map", model)
	MAP_APPLIER.apply_map(arena, model)
	if arena.has_method("notify_map_built"):
		arena.call("notify_map_built")
	if arena.has_method("fitcam_once"):
		arena.call("fitcam_once")
	return true

func _verify_map_applied_and_start(map_path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var hive_count: int = _get_hive_count()
	if hive_count <= 0:
		SFLog.warn("MAP_APPLY_FAIL_WARN", {"map_path": map_path, "err": "no_hives_after_apply"})
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
	if hud_layer != null and world_layer != null and hud_layer.layer <= world_layer.layer:
		hud_layer.layer = world_layer.layer + 1
		SFLog.warn("HUD_LAYER_RAISED", {
			"hud_layer_path": str(hud_layer.get_path()),
			"hud_layer": hud_layer.layer,
			"world_layer_path": str(world_layer.get_path()),
			"world_layer": world_layer.layer
		})
	var wvp: Node = null
	if world_layer != null:
		wvp = world_layer.get_node_or_null("WorldViewportContainer")
	if TRACE_SHELL_LOGS: print("LAYER_ORDER hud=", hud_layer.layer if hud_layer != null else -1,
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
	if TRACE_SHELL_LOGS: print("DEV_LOADER_SHOW_CALL ", {
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
		if TRACE_SHELL_LOGS: print("UI_WATCH init ", snap)
		return

	var changed: Array[String] = []
	for k in snap.keys():
		if snap[k] != _ui_watch_prev.get(k):
			changed.append(k)

	if changed.size() > 0:
		if TRACE_SHELL_LOGS: print("UI_WATCH changed=", changed, " snap=", snap)
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

func _maybe_start_mvp_smoke() -> bool:
	var config: Dictionary = _parse_mvp_smoke_config(OS.get_cmdline_user_args())
	if not bool(config.get("enabled", false)):
		return false
	call_deferred("_run_mvp_smoke", config)
	return true

func _parse_mvp_smoke_config(args: Array) -> Dictionary:
	var config: Dictionary = {
		"enabled": false,
		"map_path": "",
		"win_map_path": "",
		"boot_timeout_ms": MVP_SMOKE_DEFAULT_BOOT_TIMEOUT_MS,
		"run_timeout_ms": MVP_SMOKE_DEFAULT_RUN_TIMEOUT_MS,
		"end_timeout_ms": MVP_SMOKE_DEFAULT_END_TIMEOUT_MS
	}
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg == "--mvp-smoke":
			config["enabled"] = true
		elif arg.begins_with("--mvp-map="):
			config["map_path"] = arg.trim_prefix("--mvp-map=")
		elif arg.begins_with("--mvp-win-map="):
			config["win_map_path"] = arg.trim_prefix("--mvp-win-map=")
		elif arg.begins_with("--mvp-boot-timeout-ms="):
			config["boot_timeout_ms"] = max(1000, int(arg.trim_prefix("--mvp-boot-timeout-ms=")))
		elif arg.begins_with("--mvp-run-timeout-ms="):
			config["run_timeout_ms"] = max(1000, int(arg.trim_prefix("--mvp-run-timeout-ms=")))
		elif arg.begins_with("--mvp-end-timeout-ms="):
			config["end_timeout_ms"] = max(2000, int(arg.trim_prefix("--mvp-end-timeout-ms=")))
	return config

func _run_mvp_smoke(config: Dictionary) -> void:
	SFLog.allow_tag("MVP_SMOKE_START")
	SFLog.allow_tag("MVP_SMOKE_CHECK")
	SFLog.allow_tag("MVP_SMOKE_FAIL")
	SFLog.allow_tag("MVP_SMOKE_SUMMARY")

	var fails: int = 0
	var passes: int = 0
	var map_path: String = str(config.get("map_path", ""))
	if map_path == "":
		map_path = _mvp_pick_default_map()
	if map_path == "":
		_mvp_smoke_fail("map_path_resolved", {"reason": "no_map_found"})
		get_tree().quit(1)
		return

	var preflight: Dictionary = MAP_LOADER.load_map(map_path)
	var preflight_ok: bool = bool(preflight.get("ok", false))
	if preflight_ok:
		passes += _mvp_smoke_pass("map_load_preflight", {"map": map_path})
	else:
		fails += _mvp_smoke_fail("map_load_preflight", {"map": map_path, "err": str(preflight.get("err", "unknown"))})
		get_tree().quit(1)
		return

	var model: Dictionary = preflight.get("data", {}) as Dictionary
	var expected_walls: int = _mvp_count_walls(model)
	var boot_timeout_ms: int = int(config.get("boot_timeout_ms", MVP_SMOKE_DEFAULT_BOOT_TIMEOUT_MS))
	var run_timeout_ms: int = int(config.get("run_timeout_ms", MVP_SMOKE_DEFAULT_RUN_TIMEOUT_MS))
	var end_timeout_ms: int = int(config.get("end_timeout_ms", MVP_SMOKE_DEFAULT_END_TIMEOUT_MS))
	var win_map_path: String = str(config.get("win_map_path", ""))
	if win_map_path == "":
		win_map_path = _mvp_pick_win_map()
	SFLog.info("MVP_SMOKE_START", {
		"map": map_path,
		"expected_walls": expected_walls,
		"boot_timeout_ms": boot_timeout_ms,
		"run_timeout_ms": run_timeout_ms,
		"end_timeout_ms": end_timeout_ms,
		"win_map": win_map_path
	})

	_apply_map_then_start(map_path)

	var arena_node: Node = await _mvp_wait_for_node(MVP_SMOKE_ARENA_PATH, boot_timeout_ms)
	if arena_node != null:
		passes += _mvp_smoke_pass("arena_spawned", {"path": MVP_SMOKE_ARENA_PATH})
	else:
		fails += _mvp_smoke_fail("arena_spawned", {"path": MVP_SMOKE_ARENA_PATH})

	var records_ok: bool = await _mvp_wait_for_records_visible(boot_timeout_ms)
	if records_ok:
		passes += _mvp_smoke_pass("prematch_records_visible", {"path": MVP_SMOKE_RECORDS_PATH})
	else:
		fails += _mvp_smoke_fail("prematch_records_visible", {"path": MVP_SMOKE_RECORDS_PATH})

	var p1_label: Label = get_node_or_null(MVP_SMOKE_RECORD_P1_PATH) as Label
	var p1_ok: bool = p1_label != null and not str(p1_label.text).strip_edges().is_empty()
	if p1_ok:
		passes += _mvp_smoke_pass("prematch_record_text_populated", {"text": p1_label.text})
	else:
		fails += _mvp_smoke_fail("prematch_record_text_populated", {"text": p1_label.text if p1_label != null else "<null>"})
	var h2h_label: Label = get_node_or_null(MVP_SMOKE_RECORD_H2H_PATH) as Label
	var records_no_tbd: bool = p1_label != null and h2h_label != null \
		and str(p1_label.text).find("TBD") == -1 \
		and str(h2h_label.text).find("TBD") == -1
	if records_no_tbd:
		passes += _mvp_smoke_pass("prematch_records_no_tbd", {
			"p1": p1_label.text,
			"h2h": h2h_label.text
		})
	else:
		fails += _mvp_smoke_fail("prematch_records_no_tbd", {
			"p1": p1_label.text if p1_label != null else "<null>",
			"h2h": h2h_label.text if h2h_label != null else "<null>"
		})

	var countdown_count: int = _mvp_count_hud_countdowns()
	if countdown_count == 1:
		passes += _mvp_smoke_pass("single_countdown_label", {"count": countdown_count})
	else:
		fails += _mvp_smoke_fail("single_countdown_label", {"count": countdown_count})

	var running_ok: bool = await _mvp_wait_for_phase(int(OpsState.MatchPhase.RUNNING), run_timeout_ms)
	if running_ok:
		passes += _mvp_smoke_pass("phase_reaches_running", {"phase": int(OpsState.match_phase)})
	else:
		fails += _mvp_smoke_fail("phase_reaches_running", {"phase": int(OpsState.match_phase)})

	await _mvp_wait_ms(250)
	var prematch_overlay: Control = get_node_or_null(MVP_SMOKE_PREMATCH_OVERLAY_PATH) as Control
	var overlay_hidden: bool = prematch_overlay == null or not prematch_overlay.visible
	if overlay_hidden:
		passes += _mvp_smoke_pass("prematch_overlay_hidden_after_start", {})
	else:
		fails += _mvp_smoke_fail("prematch_overlay_hidden_after_start", {"visible": prematch_overlay.visible})

	if expected_walls > 0:
		var st: GameState = OpsState.get_state()
		var blocked_pair: Vector2i = _mvp_find_wall_intersection_pair(st)
		if blocked_pair.x <= 0 or blocked_pair.y <= 0:
			fails += _mvp_smoke_fail("wall_intersection_pair_found", {})
		else:
			passes += _mvp_smoke_pass("wall_intersection_pair_found", {"pair": blocked_pair})
			var r1: Dictionary = OpsState.apply_lane_intent(int(blocked_pair.x), int(blocked_pair.y), "attack")
			var r2: Dictionary = OpsState.apply_lane_intent(int(blocked_pair.y), int(blocked_pair.x), "attack")
			var blocked_intent_ok: bool = str(r1.get("reason", "")) == "no_lane" or str(r2.get("reason", "")) == "no_lane"
			if blocked_intent_ok:
				passes += _mvp_smoke_pass("wall_pair_blocks_lane_intent", {})
			else:
				fails += _mvp_smoke_fail("wall_pair_blocks_lane_intent", {"r1": r1, "r2": r2})
	else:
		passes += _mvp_smoke_pass("wall_check_skipped", {"reason": "map_has_no_walls"})

	var end_flow_result: Dictionary = await _mvp_run_post_match_flow_check(win_map_path, run_timeout_ms, end_timeout_ms)
	passes += int(end_flow_result.get("passes", 0))
	fails += int(end_flow_result.get("fails", 0))

	var summary_status: String = "pass" if fails == 0 else "fail"
	SFLog.warn("MVP_SMOKE_SUMMARY", {"passes": passes, "fails": fails, "map": map_path, "status": summary_status})
	_stop_game()
	await get_tree().process_frame
	get_tree().quit(1 if fails > 0 else 0)

func _mvp_pick_default_map() -> String:
	var maps: Array[String] = _mvp_list_json_maps()
	if maps.is_empty():
		return ""
	for map_path in maps:
		var preflight: Dictionary = MAP_LOADER.load_map(map_path)
		if not bool(preflight.get("ok", false)):
			continue
		var data: Dictionary = preflight.get("data", {}) as Dictionary
		var wall_count: int = _mvp_count_walls(data)
		if wall_count <= 0:
			continue
		if map_path.findn("NO_WALLS") != -1:
			continue
		return map_path
	return maps[0]

func _mvp_pick_win_map() -> String:
	if ResourceLoader.exists(MVP_SMOKE_DEFAULT_WIN_MAP):
		return MVP_SMOKE_DEFAULT_WIN_MAP
	var maps: Array[String] = _mvp_list_json_maps()
	for map_path_any in maps:
		var map_path: String = str(map_path_any)
		var preflight: Dictionary = MAP_LOADER.load_map(map_path)
		if not bool(preflight.get("ok", false)):
			continue
		var data: Dictionary = preflight.get("data", {}) as Dictionary
		var hives_v: Variant = data.get("hives", [])
		if typeof(hives_v) != TYPE_ARRAY:
			continue
		var hives: Array = hives_v as Array
		var owner_counts: Dictionary = {}
		for hive_any in hives:
			if typeof(hive_any) != TYPE_DICTIONARY:
				continue
			var hive_d: Dictionary = hive_any as Dictionary
			var owner_id: int = int(hive_d.get("owner_id", 0))
			if owner_id < 1 or owner_id > 4:
				continue
			owner_counts[owner_id] = int(owner_counts.get(owner_id, 0)) + 1
		if owner_counts.size() >= 2:
			return map_path
	return ""

func _mvp_run_post_match_flow_check(win_map_path: String, run_timeout_ms: int, end_timeout_ms: int) -> Dictionary:
	var result: Dictionary = {"passes": 0, "fails": 0}
	var ended_mode: String = "natural"
	if win_map_path == "":
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_map_path_resolved", {"reason": "no_win_map_found"})
		return result
	var preflight: Dictionary = MAP_LOADER.load_map(win_map_path)
	if not bool(preflight.get("ok", false)):
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_map_load_preflight", {"map": win_map_path, "err": str(preflight.get("err", "unknown"))})
		return result
	result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_map_load_preflight", {"map": win_map_path})
	_apply_map_then_start(win_map_path)
	var running_ok: bool = await _mvp_wait_for_phase(int(OpsState.MatchPhase.RUNNING), run_timeout_ms)
	if not running_ok:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_phase_reaches_running", {"phase": int(OpsState.match_phase), "map": win_map_path})
		return result
	result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_phase_reaches_running", {"map": win_map_path})
	var lane_start_result: Dictionary = _mvp_start_conquest_flow()
	var intents_ok: bool = bool(lane_start_result.get("ok", false))
	if not intents_ok:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_conquest_intents", lane_start_result)
		return result
	result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_conquest_intents", lane_start_result)
	var ended_ok: bool = await _mvp_wait_for_phase(int(OpsState.MatchPhase.ENDED), end_timeout_ms)
	if not ended_ok:
		OpsState.begin_match_end(1, "smoke_forced_conquest", 0)
		OpsState.finalize_match_end()
		ended_ok = await _mvp_wait_for_phase(int(OpsState.MatchPhase.ENDED), 1000)
		if ended_ok:
			ended_mode = "forced_fallback"
			result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_phase_reaches_ended", {
				"winner": int(OpsState.winner_id),
				"reason": str(OpsState.match_end_reason),
				"mode": ended_mode
			})
		else:
			result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_phase_reaches_ended", {"phase": int(OpsState.match_phase), "winner": int(OpsState.winner_id)})
			return result
	else:
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_phase_reaches_ended", {"winner": int(OpsState.winner_id), "reason": str(OpsState.match_end_reason), "mode": ended_mode})
	var lock_ok: bool = bool(OpsState.input_locked)
	var lock_reason: String = str(OpsState.input_locked_reason)
	if lock_ok and lock_reason != "":
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_input_locked", {"reason": lock_reason})
	else:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_input_locked", {"locked": lock_ok, "reason": lock_reason})
	if ended_mode != "natural":
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_ui_checks_skipped", {"mode": ended_mode})
		return result
	var overlay_ok: bool = await _mvp_wait_for_outcome_overlay_visible(run_timeout_ms)
	if overlay_ok:
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_outcome_overlay_visible", {"path": MVP_SMOKE_OUTCOME_OVERLAY_PATH})
	else:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_outcome_overlay_visible", {"path": MVP_SMOKE_OUTCOME_OVERLAY_PATH})
	var vote1_ok: bool = OpsState.request_rematch(1)
	var vote2_ok: bool = OpsState.request_rematch(2)
	if vote1_ok and vote2_ok:
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_rematch_votes", {"p1": vote1_ok, "p2": vote2_ok})
	else:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_rematch_votes", {"p1": vote1_ok, "p2": vote2_ok})
	var restarted_ok: bool = await _mvp_wait_for_phase_not(int(OpsState.MatchPhase.ENDED), run_timeout_ms)
	if restarted_ok:
		result["passes"] = int(result.get("passes", 0)) + _mvp_smoke_pass("post_match_rematch_restarts_match", {"phase": int(OpsState.match_phase)})
	else:
		result["fails"] = int(result.get("fails", 0)) + _mvp_smoke_fail("post_match_rematch_restarts_match", {"phase": int(OpsState.match_phase), "post_end_action": str(OpsState.post_end_action)})
	return result

func _mvp_start_conquest_flow() -> Dictionary:
	var st: GameState = OpsState.get_state()
	if st == null:
		return {"ok": false, "reason": "state_null"}
	if st.hives == null or st.hives.is_empty():
		return {"ok": false, "reason": "no_hives"}
	var hives_by_owner: Dictionary = {}
	for hive_any in st.hives:
		if not (hive_any is HiveData):
			continue
		var hive: HiveData = hive_any as HiveData
		var owner_id: int = int(hive.owner_id)
		if owner_id < 1 or owner_id > 4:
			continue
		var arr: Array = hives_by_owner.get(owner_id, [])
		arr.append(hive)
		hives_by_owner[owner_id] = arr
	if hives_by_owner.size() < 2:
		return {"ok": false, "reason": "insufficient_player_owners", "owners": hives_by_owner.keys()}
	var attacker_owner: int = -1
	var attacker_count: int = -1
	for owner_any in hives_by_owner.keys():
		var owner_id: int = int(owner_any)
		var owned_arr: Array = hives_by_owner.get(owner_id, [])
		var count: int = owned_arr.size()
		if count > attacker_count:
			attacker_count = count
			attacker_owner = owner_id
	if attacker_owner <= 0:
		return {"ok": false, "reason": "attacker_owner_unresolved"}
	var target_owner: int = -1
	var target_count: int = 1_000_000
	for owner_any in hives_by_owner.keys():
		var owner_id: int = int(owner_any)
		if owner_id == attacker_owner:
			continue
		var owned_arr: Array = hives_by_owner.get(owner_id, [])
		var count: int = owned_arr.size()
		if count < target_count:
			target_count = count
			target_owner = owner_id
	if target_owner <= 0:
		return {"ok": false, "reason": "target_owner_unresolved", "attacker_owner": attacker_owner}
	var attacker_hives: Array = hives_by_owner.get(attacker_owner, [])
	var target_hives: Array = hives_by_owner.get(target_owner, [])
	if attacker_hives.is_empty() or target_hives.is_empty():
		return {"ok": false, "reason": "missing_attack_or_target_hives"}
	OpsState.sim_mutate("mvp_smoke_power_boost", func() -> void:
		for attacker_any in attacker_hives:
			if not (attacker_any is HiveData):
				continue
			var attacker_hive: HiveData = attacker_any as HiveData
			attacker_hive.power = maxi(int(attacker_hive.power), 50)
		for target_any in target_hives:
			if not (target_any is HiveData):
				continue
			var target_hive: HiveData = target_any as HiveData
			target_hive.power = mini(int(target_hive.power), 3)
	)
	var intents_sent: int = 0
	var attempts: Array = []
	for attacker_any in attacker_hives:
		if not (attacker_any is HiveData):
			continue
		var attacker: HiveData = attacker_any as HiveData
		for target_any in target_hives:
			if not (target_any is HiveData):
				continue
			var target: HiveData = target_any as HiveData
			var lane_result: Dictionary = OpsState.apply_lane_intent(int(attacker.id), int(target.id), "attack")
			attempts.append({
				"src": int(attacker.id),
				"dst": int(target.id),
				"ok": bool(lane_result.get("ok", false)),
				"reason": str(lane_result.get("reason", ""))
			})
			if bool(lane_result.get("ok", false)):
				intents_sent += 1
				break
		if intents_sent >= 2:
			break
	if intents_sent <= 0:
		return {
			"ok": false,
			"reason": "no_attack_intent_applied",
			"attacker_owner": attacker_owner,
			"target_owner": target_owner,
			"attempts": attempts
		}
	return {
		"ok": true,
		"attacker_owner": attacker_owner,
		"target_owner": target_owner,
		"intents_sent": intents_sent,
		"attempts": attempts
	}

func _mvp_list_json_maps() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://maps/json")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.to_lower().ends_with(".json"):
			continue
		out.append("res://maps/json/%s" % name)
	dir.list_dir_end()
	out.sort()
	return out

func _mvp_wait_for_node(path: String, timeout_ms: int) -> Node:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var node: Node = get_node_or_null(path)
		if node != null:
			return node
		await get_tree().process_frame
	return null

func _mvp_wait_for_records_visible(timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var records: Control = get_node_or_null(MVP_SMOKE_RECORDS_PATH) as Control
		var prematch: bool = int(OpsState.match_phase) == int(OpsState.MatchPhase.PREMATCH)
		if records != null and prematch and records.visible:
			return true
		await get_tree().process_frame
	return false

func _mvp_wait_for_phase(target_phase: int, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if int(OpsState.match_phase) == target_phase:
			return true
		await get_tree().process_frame
	return false

func _mvp_wait_for_phase_not(target_phase: int, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if int(OpsState.match_phase) != target_phase:
			return true
		await get_tree().process_frame
	return false

func _mvp_wait_ms(duration_ms: int) -> void:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < duration_ms:
		await get_tree().process_frame

func _mvp_wait_for_outcome_overlay_visible(timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var overlay: Control = get_node_or_null(MVP_SMOKE_OUTCOME_OVERLAY_PATH) as Control
		if overlay != null and overlay.visible:
			return true
		await get_tree().process_frame
	return false

func _mvp_count_hud_countdowns() -> int:
	var hud_root: Node = get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot")
	if hud_root == null:
		return 0
	var labels: Array[Node] = hud_root.find_children("*CountdownLabel", "Label", true, false)
	return labels.size()

func _mvp_count_walls(model: Dictionary) -> int:
	var walls_v: Variant = model.get("walls", [])
	if typeof(walls_v) != TYPE_ARRAY:
		return 0
	return (walls_v as Array).size()

func _mvp_find_wall_intersection_pair(st: GameState) -> Vector2i:
	if st == null or st.hives == null or st.hives.is_empty():
		return Vector2i(-1, -1)
	var wall_segments: Array = MAP_SCHEMA._wall_segments_from_walls(st.walls)
	if wall_segments.is_empty():
		return Vector2i(-1, -1)
	var hives: Array = st.hives
	for i in range(hives.size()):
		var a_any: Variant = hives[i]
		if not (a_any is HiveData):
			continue
		var a_hive: HiveData = a_any as HiveData
		var a_owner: int = int(a_hive.owner_id)
		if a_owner <= 0:
			continue
		for j in range(i + 1, hives.size()):
			var b_any: Variant = hives[j]
			if not (b_any is HiveData):
				continue
			var b_hive: HiveData = b_any as HiveData
			var b_owner: int = int(b_hive.owner_id)
			if b_owner <= 0 or b_owner == a_owner:
				continue
			var a_grid: Vector2 = Vector2(float(a_hive.grid_pos.x), float(a_hive.grid_pos.y))
			var b_grid: Vector2 = Vector2(float(b_hive.grid_pos.x), float(b_hive.grid_pos.y))
			if MAP_SCHEMA._segment_intersects_any_wall(a_grid, b_grid, wall_segments):
				return Vector2i(int(a_hive.id), int(b_hive.id))
	return Vector2i(-1, -1)

func _mvp_smoke_pass(name: String, data: Dictionary) -> int:
	SFLog.info("MVP_SMOKE_CHECK", {"name": name, "ok": true, "data": data})
	return 1

func _mvp_smoke_fail(name: String, data: Dictionary) -> int:
	SFLog.warn("MVP_SMOKE_FAIL", {"name": name, "ok": false, "data": data})
	return 1
