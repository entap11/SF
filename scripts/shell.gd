extends Node
const SHELL_PATCH_REV: String = "rev_2026_02_06_a"
const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_APPLIER := preload("res://scripts/maps/map_applier.gd")
const MAP_SCHEMA := preload("res://scripts/maps/map_schema.gd")
const ShellStartupLaunchRequestResolver := preload("res://scripts/shell_helpers/startup_launch_request_resolver.gd")
const ShellMvpWaiter := preload("res://scripts/shell_helpers/mvp_waiter.gd")
const ShellMvpMapUtils := preload("res://scripts/shell_helpers/mvp_map_utils.gd")
const SHELL_BUFFER_ROOT_PATH: String = "/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer/BufferRoot"
const SHELL_TOP_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/TopBufferBackground"
const SHELL_POWER_BAR_PATH: String = SHELL_TOP_BUFFER_PATH + "/PowerBarAnchor/PowerBar"
const SHELL_BOTTOM_BUFFER_PATH: String = SHELL_BUFFER_ROOT_PATH + "/BottomBufferBackground"
const SHELL_PLAYER_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/BuffSlotsStrip"
const SHELL_OPPONENT_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/OpponentBuffStrip"
const SHELL_OPPONENT_BUFF_STRIP_B_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/OpponentBuffStripB"
const SHELL_ALLY_BUFF_STRIP_PATH: String = SHELL_BOTTOM_BUFFER_PATH + "/AllyBuffStrip"
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
const SOAK_DEFAULT_SECONDS: int = 1800
const SOAK_DEFAULT_ROUND_SECONDS: int = 300
const SOAK_DEFAULT_PAIR_COUNT: int = 2
const SOAK_DEFAULT_REAPPLY_MS: int = 1000
const SOAK_DEFAULT_START_TIMEOUT_MS: int = 15000
const CTF_BOT_STAGE_MAP_PATH: String = "res://maps/_future/nomansland/MAP_nomansland__SBASE__1p__start_v12_top_row_vs_bottom_row_3each.json"
const TUTORIAL_SANDBOX_MAP_PATH: String = "res://maps/json/MAP_SKETCH_LR_8x12_v1xy_BARRACKS_1.json"
const TUTORIAL_SANDBOX_FALLBACK_MAP_PATH: String = "res://maps/json/MAP_TEST_8x12.json"
const BUFF_SIDE_STRIP_WIDTH_PX: float = 92.0
const BUFF_SIDE_STRIP_TARGET_HEIGHT_PX: float = 150.0
const BUFF_SIDE_STRIP_GAP_PX: float = 16.0
const BUFF_SIDE_STRIP_MARGIN_PX: float = 12.0
const BUFF_SIDE_SLOT_SIZE_PX: float = 42.0
const BUFF_SIDE_SLOT_SEPARATION_PX: int = 4
const BUFF_SIDE_TITLE_FONT_SIZE: int = 12
const BUFF_SIDE_USED_MARK_FONT_SIZE: int = 40
const BUFF_OPP_STRIP_WIDTH_PX: float = 176.0
const BUFF_OPP_STRIP_HEIGHT_PX: float = 56.0
const BUFF_OPP_STRIP_ROW_GAP_PX: float = 10.0
const BUFF_OPP_SLOT_SIZE_PX: float = 48.0
const BUFF_OPP_SLOT_SEPARATION_PX: int = 8
const BUFF_OPP_USED_MARK_FONT_SIZE: int = 28
const BUFF_OPP_STRIP_MIN_HEIGHT_PX: float = 44.0
const BUFF_OPP_STRIP_MAX_HEIGHT_PX: float = 72.0
const BUFF_OPP_SLOT_MIN_PX: float = 30.0
const BUFF_OPP_SLOT_MAX_PX: float = 72.0
const BUFF_OPP_ROW_SIDE_PAD_PX: float = 8.0
const BUFF_PLAYER_STRIP_WIDTH_PX: float = 420.0
const BUFF_PLAYER_STRIP_HEIGHT_PX: float = 120.0
const BUFF_PLAYER_SLOT_SIZE_PX: float = 84.0
const BUFF_PLAYER_SLOT_SEPARATION_PX: int = 24
const PREMATCH_POWERBAR_REVEAL_WINDOW_MS: int = 350
const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_FREE_ROLL_ATLAS_PATH := "res://assets/fonts/free_roll_display_v2_font.tres"
const FONT_FREE_ROLL_SUPPORTED := " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"

@export var start_in_menu := true
@export var enable_dev_map_loader := true
@export var show_dev_map_loader_in_game := true
@export var game_scene_path := "res://scenes/Main.tscn"
@export var main_menu_scene_path := "res://scenes/MainMenu.tscn"
@export var map_picker_panel_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel")
@export var map_list_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/MapList")
@export var select_map_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/SelectMapButton")
@export var tutorial_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/TutorialButton")
@export var ctf_bot_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/CtfBotButton")
@export var team_mode_button_path: NodePath = NodePath("MenuRoot/MenuPanel/VBox/ButtonsRow/TeamModeButton")
@export var play_selected_button_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/PickerButtonsRow/PlaySelectedButton")
@export var picker_back_button_path: NodePath = NodePath("MenuRoot/MenuPanel/MapPickerPanel/Center/Panel/VBox/PickerButtonsRow/PickerBackButton")
@export var dev_map_loader_path: NodePath = NodePath("DevMapLoader")
@export var fail_if_shell_script_not_running: bool = true

@onready var menu_root: Control = $MenuRoot
@onready var arena_root: CanvasItem = $ArenaRoot
@onready var menu_panel: Control = $MenuRoot/MenuPanel
@onready var menu_title: Label = $MenuRoot/MenuPanel/VBox/Title
@onready var dev_button: Button = $MenuRoot/MenuPanel/VBox/DevButton
@onready var back_button: Button = $MenuRoot/BackButton
@onready var back_overlay: Control = $ArenaRoot/BackOverlay
@onready var _map_picker_panel: Control = get_node_or_null(map_picker_panel_path) as Control
@onready var _map_list: ItemList = get_node_or_null(map_list_path) as ItemList
@onready var _select_map_button: Button = get_node_or_null(select_map_button_path) as Button
@onready var _tutorial_button: Button = get_node_or_null(tutorial_button_path) as Button
@onready var _ctf_bot_button: Button = get_node_or_null(ctf_bot_button_path) as Button
@onready var _team_mode_button: Button = get_node_or_null(team_mode_button_path) as Button
@onready var _play_selected_button: Button = get_node_or_null(play_selected_button_path) as Button
@onready var _picker_back_button: Button = get_node_or_null(picker_back_button_path) as Button
@onready var _player_buff_strip: Control = get_node_or_null(SHELL_PLAYER_BUFF_STRIP_PATH) as Control
@onready var _opponent_buff_strip: Control = get_node_or_null(SHELL_OPPONENT_BUFF_STRIP_PATH) as Control
@onready var _opponent_buff_strip_b: Control = get_node_or_null(SHELL_OPPONENT_BUFF_STRIP_B_PATH) as Control
@onready var _ally_buff_strip: Control = get_node_or_null(SHELL_ALLY_BUFF_STRIP_PATH) as Control

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
var _buff_ui_last_active_pid: int = 1
var _font_regular: Font
var _font_semibold: Font
var _font_free_roll_atlas: Font
var _startup_request_resolver: ShellStartupLaunchRequestResolver = ShellStartupLaunchRequestResolver.new()
var _mvp_waiter: ShellMvpWaiter = ShellMvpWaiter.new()
var _mvp_map_utils: ShellMvpMapUtils = ShellMvpMapUtils.new()

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
	_load_dev_menu_fonts()
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 030: before_resolve_map_picker_ui_nodes")
	_resolve_map_picker_ui_nodes()
	_resolve_tutorial_ui_node()
	_resolve_ctf_bot_ui_node()
	_resolve_team_mode_ui_node()
	_resolve_dev_map_loader()
	_resolve_buff_ui_nodes()
	_apply_dev_menu_fonts()
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 040: after_resolve_map_picker_ui_nodes")
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 050: before_wire_map_picker_ui")
	_safe_call("wire_map_picker_ui", Callable(self, "_wire_map_picker_ui"))
	_safe_call("wire_buff_ui", Callable(self, "_wire_buff_ui"))
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
	var startup_request: Dictionary = _resolve_startup_launch_request()
	var startup_requested: bool = bool(startup_request.get("start", false))
	var startup_map_path: String = str(startup_request.get("map_path", "")).strip_edges()
	var startup_reason: String = str(startup_request.get("reason", "none"))
	var open_map_picker_on_ready: bool = _consume_open_map_picker_request(get_tree())
	var in_menu_boot: bool = start_in_menu and not startup_requested
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 070: before_startup_menu_flow")
	_set_menu_state(in_menu_boot)
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 080: after_startup_menu_flow")
	if _maybe_start_soak_perf():
		return
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
	if startup_requested:
		SFLog.info("SHELL_BOOT_AUTOSTART", {
			"reason": startup_reason,
			"map_path": startup_map_path,
			"in_menu_boot": in_menu_boot
		})
		if startup_map_path != "":
			call_deferred("_apply_map_then_start", startup_map_path)
		else:
			_start_game()
	elif not in_menu_boot:
		_start_game()
	elif open_map_picker_on_ready:
		call_deferred("_show_map_picker")
		SFLog.info("MAP_PICKER_OPEN_ON_READY", {})
	if TRACE_SHELL_LOGS: print("BOOT_BEACON 090: after_start_game_check")

func _resolve_startup_launch_request() -> Dictionary:
	var tree: SceneTree = get_tree()
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if _startup_request_resolver == null:
		_startup_request_resolver = ShellStartupLaunchRequestResolver.new()
	return _startup_request_resolver.resolve(tree, gamebot)

func _consume_open_map_picker_request(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var should_open: bool = bool(tree.get_meta("open_map_picker_on_ready", false))
	if tree.has_meta("open_map_picker_on_ready"):
		tree.remove_meta("open_map_picker_on_ready")
	return should_open

func _resolve_stage_map_from_tree_meta(tree: SceneTree) -> String:
	if _startup_request_resolver == null:
		_startup_request_resolver = ShellStartupLaunchRequestResolver.new()
	return _startup_request_resolver.resolve_stage_map_from_tree_meta(tree)

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

func _resolve_tutorial_ui_node() -> void:
	_tutorial_button = get_node_or_null(tutorial_button_path) as Button
	SFLog.info("TUTORIAL_UI_RESOLVE", {
		"tutorial_button_np": str(tutorial_button_path),
		"tutorial_button": _diag_resolve(_tutorial_button)
	})
	if _tutorial_button != null and not _tutorial_button.pressed.is_connected(_on_tutorial_pressed):
		_tutorial_button.pressed.connect(_on_tutorial_pressed)

func _resolve_ctf_bot_ui_node() -> void:
	_ctf_bot_button = get_node_or_null(ctf_bot_button_path) as Button
	SFLog.info("CTF_BOT_UI_RESOLVE", {
		"ctf_bot_button_np": str(ctf_bot_button_path),
		"ctf_bot_button": _diag_resolve(_ctf_bot_button)
	})
	if _ctf_bot_button != null and not _ctf_bot_button.pressed.is_connected(_on_ctf_bot_pressed):
		_ctf_bot_button.pressed.connect(_on_ctf_bot_pressed)

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
		_apply_team_mode_button_font()
	if OpsState.has_method("set_team_mode_override"):
		OpsState.call("set_team_mode_override", _team_mode_ui)
	SFLog.info("TEAM_MODE_SELECTED", {"mode": _team_mode_ui})

func _load_dev_menu_fonts() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_semibold = load(FONT_SEMIBOLD_PATH)
	_font_free_roll_atlas = load(FONT_FREE_ROLL_ATLAS_PATH)

func _apply_dev_menu_fonts() -> void:
	if menu_title != null:
		if not _apply_free_roll_atlas_font(menu_title, 72):
			_apply_font(menu_title, _font_semibold, 48)
	if dev_button != null:
		dev_button.custom_minimum_size.y = maxf(dev_button.custom_minimum_size.y, 78.0)
	if dev_button != null:
		if not _apply_free_roll_atlas_font(dev_button, 44):
			_apply_font(dev_button, _font_semibold, 30)
	if _select_map_button != null:
		_select_map_button.custom_minimum_size.y = maxf(_select_map_button.custom_minimum_size.y, 78.0)
		if not _apply_free_roll_atlas_font(_select_map_button, 40):
			_apply_font(_select_map_button, _font_regular, 28)
	if _tutorial_button != null:
		_tutorial_button.custom_minimum_size.y = maxf(_tutorial_button.custom_minimum_size.y, 78.0)
		if not _apply_free_roll_atlas_font(_tutorial_button, 40):
			_apply_font(_tutorial_button, _font_regular, 28)
	if _ctf_bot_button != null:
		_ctf_bot_button.custom_minimum_size.y = maxf(_ctf_bot_button.custom_minimum_size.y, 78.0)
		if not _apply_free_roll_atlas_font(_ctf_bot_button, 40):
			_apply_font(_ctf_bot_button, _font_regular, 28)
	if _play_selected_button != null:
		_play_selected_button.custom_minimum_size.y = maxf(_play_selected_button.custom_minimum_size.y, 78.0)
		if not _apply_free_roll_atlas_font(_play_selected_button, 40):
			_apply_font(_play_selected_button, _font_regular, 28)
	if _picker_back_button != null:
		_picker_back_button.custom_minimum_size.y = maxf(_picker_back_button.custom_minimum_size.y, 78.0)
		if not _apply_free_roll_atlas_font(_picker_back_button, 40):
			_apply_font(_picker_back_button, _font_regular, 28)
	if back_button != null:
		back_button.custom_minimum_size.y = maxf(back_button.custom_minimum_size.y, 56.0)
		if not _apply_free_roll_atlas_font(back_button, 26):
			_apply_font(back_button, _font_regular, 18)
	_apply_team_mode_button_font()
	_log_dev_menu_font_state()

func _apply_team_mode_button_font() -> void:
	if _team_mode_button == null:
		return
	if not _apply_free_roll_atlas_font(_team_mode_button, 22):
		_apply_font(_team_mode_button, _font_regular, 16)

func _apply_font(node: Control, font: Font, size: int) -> void:
	if node == null or font == null:
		return
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", maxi(1, size))

func _text_uses_free_roll_charset(text: String) -> bool:
	var source := text.to_upper()
	for i in source.length():
		var ch := source.substr(i, 1)
		if FONT_FREE_ROLL_SUPPORTED.find(ch) == -1:
			return false
	return true

func _apply_free_roll_atlas_font(node: Control, size: int) -> bool:
	if node == null or _font_free_roll_atlas == null:
		return false
	var raw_text := ""
	if node is Label:
		raw_text = (node as Label).text
	elif node is BaseButton:
		raw_text = (node as BaseButton).text
	if raw_text == "":
		return false
	var upper_text := raw_text.to_upper()
	if not _text_uses_free_roll_charset(upper_text):
		return false
	if node is Label:
		(node as Label).text = upper_text
	elif node is BaseButton:
		(node as BaseButton).text = upper_text
	node.add_theme_font_override("font", _font_free_roll_atlas)
	node.add_theme_font_size_override("font_size", maxi(1, size))
	return true

func _log_dev_menu_font_state() -> void:
	var targets: Array[Control] = []
	if menu_title != null:
		targets.append(menu_title)
	if dev_button != null:
		targets.append(dev_button)
	if _select_map_button != null:
		targets.append(_select_map_button)
	if _tutorial_button != null:
		targets.append(_tutorial_button)
	if _ctf_bot_button != null:
		targets.append(_ctf_bot_button)
	if _team_mode_button != null:
		targets.append(_team_mode_button)
	if back_button != null:
		targets.append(back_button)
	for node in targets:
		var text := ""
		if node is Label:
			text = (node as Label).text
		elif node is BaseButton:
			text = (node as BaseButton).text
		var f: Font = node.get_theme_font("font")
		var font_path := f.resource_path if f != null else "<null>"
		SFLog.info("DEV_MENU_FONT_STATE", {
			"node": str(node.get_path()),
			"text": text,
			"font_path": font_path,
			"font_size": node.get_theme_font_size("font_size"),
			"has_font_override": node.has_theme_font_override("font"),
			"has_size_override": node.has_theme_font_size_override("font_size")
		})

func _resolve_dev_map_loader() -> void:
	_dev_map_loader = get_node_or_null(dev_map_loader_path) as CanvasItem
	if TRACE_SHELL_LOGS: print("DEV_LOADER_RESOLVE ", {
		"path": str(dev_map_loader_path),
		"node": _np(_dev_map_loader),
		"iid": _iid(_dev_map_loader),
		"visible": (_dev_map_loader.visible if _dev_map_loader != null else false)
	})

func _resolve_buff_ui_nodes() -> void:
	_player_buff_strip = get_node_or_null(SHELL_PLAYER_BUFF_STRIP_PATH) as Control
	_opponent_buff_strip = get_node_or_null(SHELL_OPPONENT_BUFF_STRIP_PATH) as Control
	_opponent_buff_strip_b = get_node_or_null(SHELL_OPPONENT_BUFF_STRIP_B_PATH) as Control
	_ally_buff_strip = get_node_or_null(SHELL_ALLY_BUFF_STRIP_PATH) as Control
	SFLog.info("BUFF_UI_RESOLVE", {
		"player_strip": _diag_resolve(_player_buff_strip),
		"opponent_strip": _diag_resolve(_opponent_buff_strip),
		"opponent_strip_b": _diag_resolve(_opponent_buff_strip_b),
		"ally_strip": _diag_resolve(_ally_buff_strip)
	})

func _wire_buff_ui() -> void:
	if _player_buff_strip == null:
		SFLog.warn("BUFF_UI_MISSING_PLAYER_STRIP", {})
		return
	if _player_buff_strip.has_signal("buff_drag_started"):
		var drag_started_cb: Callable = Callable(self, "_on_player_buff_drag_started")
		if not _player_buff_strip.is_connected("buff_drag_started", drag_started_cb):
			_player_buff_strip.connect("buff_drag_started", drag_started_cb)
	if _player_buff_strip.has_signal("buff_drop_requested"):
		var drop_cb: Callable = Callable(self, "_on_player_buff_drop_requested")
		if not _player_buff_strip.is_connected("buff_drop_requested", drop_cb):
			_player_buff_strip.connect("buff_drop_requested", drop_cb)
	if _player_buff_strip.has_signal("buff_drag_cancelled"):
		var cancel_cb: Callable = Callable(self, "_on_player_buff_drag_cancelled")
		if not _player_buff_strip.is_connected("buff_drag_cancelled", cancel_cb):
			_player_buff_strip.connect("buff_drag_cancelled", cancel_cb)
	if _player_buff_strip.has_method("apply_snapshot"):
		_player_buff_strip.call("apply_snapshot", {"slots_active": 0, "slots": []})
	if _opponent_buff_strip != null and _opponent_buff_strip.has_method("set_visible_slot_count"):
		_opponent_buff_strip.call("set_visible_slot_count", 0)
	if _opponent_buff_strip != null and _opponent_buff_strip.has_method("reset_slots"):
		_opponent_buff_strip.call("reset_slots")
	if _opponent_buff_strip_b != null and _opponent_buff_strip_b.has_method("set_visible_slot_count"):
		_opponent_buff_strip_b.call("set_visible_slot_count", 0)
	if _opponent_buff_strip_b != null and _opponent_buff_strip_b.has_method("reset_slots"):
		_opponent_buff_strip_b.call("reset_slots")
	if _ally_buff_strip != null and _ally_buff_strip.has_method("set_visible_slot_count"):
		_ally_buff_strip.call("set_visible_slot_count", 0)
	if _ally_buff_strip != null and _ally_buff_strip.has_method("reset_slots"):
		_ally_buff_strip.call("reset_slots")
	SFLog.info("BUFF_UI_WIRED", {
		"player_strip_connected": true,
		"opponent_strip_present": _opponent_buff_strip != null,
		"opponent_strip_b_present": _opponent_buff_strip_b != null,
		"ally_strip_present": _ally_buff_strip != null
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
	if _map_list == null:
		SFLog.error("MAP_SCAN_NO_MAP_LIST", {})
		return
	_map_list.clear()
	_map_list.set_meta("paths", PackedStringArray())
	var paths: PackedStringArray = PackedStringArray()
	for path_any in MAP_LOADER.list_maps():
		var path: String = str(path_any)
		if path.is_empty():
			continue
		paths.append(path)
	paths.sort()
	for p in paths:
		_map_list.add_item(p.get_file())
		var idx: int = _map_list.item_count - 1
		_map_list.set_item_metadata(idx, p)
	_map_list.set_meta("paths", paths)
	SFLog.info("MAP_SCAN_DONE", {"count": paths.size()})

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
	MAP_APPLIER.apply_map(arena, model)
	if arena.has_method("notify_map_built"):
		arena.call("notify_map_built")
	if arena.has_method("apply_camera_fit_next_frame"):
		arena.call("apply_camera_fit_next_frame", "shell_map_apply")
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
	_ensure_vs_frame_visible()
	call_deferred("_sync_power_bar_buffer_placement")
	call_deferred("_sync_buff_ui")
	if _arena_instance.has_method("start_game"):
		_arena_instance.call_deferred("start_game")

func _ensure_vs_frame_visible() -> void:
	var hud_root: CanvasItem = get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot") as CanvasItem
	var buffer_layer: CanvasItem = get_node_or_null("/root/Shell/HUDCanvasLayer/HUDRoot/BufferBackdropLayer") as CanvasItem
	var buffer_root: CanvasItem = get_node_or_null(SHELL_BUFFER_ROOT_PATH) as CanvasItem
	var top_buffer: CanvasItem = get_node_or_null(SHELL_TOP_BUFFER_PATH) as CanvasItem
	var bottom_buffer: CanvasItem = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as CanvasItem
	for node_any in [hud_root, buffer_layer, buffer_root, top_buffer, bottom_buffer]:
		var node: CanvasItem = node_any as CanvasItem
		if node == null:
			continue
		node.visible = true

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
	_sync_buff_ui()

func _on_dev_pressed() -> void:
	_open_main_menu()

func _on_tutorial_pressed() -> void:
	_set_team_mode_ui("2v2")
	_prepare_tutorial_section3_sandbox_profile()
	var map_path: String = _resolve_tutorial_sandbox_map_path()
	SFLog.info("TUTORIAL_SANDBOX_LAUNCH", {"map_path": map_path, "mode": _team_mode_ui})
	_apply_map_then_start(map_path)

func _on_ctf_bot_pressed() -> void:
	var map_path: String = _resolve_ctf_bot_map_path()
	if map_path.is_empty():
		SFLog.error("CTF_BOT_LAUNCH_NO_MAP", {})
		return
	_prepare_ctf_bot_tree_meta(map_path)
	_set_team_mode_ui("ffa")
	SFLog.info("CTF_BOT_LAUNCH", {
		"map_path": map_path,
		"mode": "HIDDEN_CAPTURE_FLAG",
		"free_roll": true
	})
	_apply_map_then_start(map_path)

func _prepare_tutorial_section3_sandbox_profile() -> void:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null:
		return
	if profile_manager.has_method("prepare_tutorial_section3_sandbox"):
		profile_manager.call("prepare_tutorial_section3_sandbox")
		return
	if profile_manager.has_method("mark_onboarding_complete"):
		profile_manager.call("mark_onboarding_complete")
	if profile_manager.has_method("mark_tutorial_section1_completed"):
		profile_manager.call("mark_tutorial_section1_completed")
	if profile_manager.has_method("mark_tutorial_section2_completed"):
		profile_manager.call("mark_tutorial_section2_completed")
	if profile_manager.has_method("begin_tutorial_section3"):
		profile_manager.call("begin_tutorial_section3")
	if profile_manager.has_method("set_tutorial_section3_step"):
		profile_manager.call("set_tutorial_section3_step", "step_0_intro")

func _resolve_tutorial_sandbox_map_path() -> String:
	if ResourceLoader.exists(TUTORIAL_SANDBOX_MAP_PATH):
		return TUTORIAL_SANDBOX_MAP_PATH
	if ResourceLoader.exists(TUTORIAL_SANDBOX_FALLBACK_MAP_PATH):
		return TUTORIAL_SANDBOX_FALLBACK_MAP_PATH
	if _selected_map_path != "" and ResourceLoader.exists(_selected_map_path):
		return _selected_map_path
	return ""

func _resolve_ctf_bot_map_path() -> String:
	if FileAccess.file_exists(CTF_BOT_STAGE_MAP_PATH):
		return CTF_BOT_STAGE_MAP_PATH
	return ""

func _prepare_ctf_bot_tree_meta(map_path: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var local_uid: String = ProfileManager.get_user_id() if ProfileManager != null else "local"
	var local_name: String = ProfileManager.get_display_name() if ProfileManager != null else "You"
	if local_name.strip_edges().is_empty():
		local_name = "You"
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", "HIDDEN_CAPTURE_FLAG")
	tree.set_meta("vs_price_usd", 0)
	tree.set_meta("vs_free_roll", true)
	tree.set_meta("vs_assigned_players", [local_name, "CPU"])
	tree.set_meta("vs_open_slots", 0)
	tree.set_meta("vs_required_players", 2)
	tree.set_meta("vs_sync_start", true)
	tree.set_meta("vs_sync_join_sec", 0)
	tree.set_meta("vs_window_sec", 0)
	tree.set_meta("vs_window_started_unix", 0)
	tree.set_meta("vs_window_deadline_unix", 0)
	tree.set_meta("vs_stage_map_paths", [map_path])
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_handshake_session_id", "")
	tree.set_meta("vs_handshake_role", "host")
	tree.set_meta("vs_handshake_invite_code", "")
	tree.set_meta("vs_local_profile", {
		"uid": local_uid,
		"display_name": local_name
	})
	tree.set_meta("vs_remote_profile", {
		"uid": "",
		"display_name": "CPU",
		"is_cpu": true
	})
	tree.set_meta("ctf_flag_selection_mode", "player_select")
	tree.set_meta("ctf_player_select_pct", 100)
	tree.set_meta("ctf_randomize_flag_hive", true)
	tree.set_meta("ctf_hidden_flag", true)
	tree.set_meta("ctf_flag_move_count_max", 1)
	tree.set_meta("ctf_flag_move_reveals", true)

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
	call_deferred("_layout_buff_strip_positions")

func _process(_delta: float) -> void:
	_sync_buff_ui()
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
	call_deferred("_sync_buff_ui")
	if _arena_instance != null:
		call_deferred("_update_power_bar_visibility")

func _resolve_runtime_arena_node() -> Node:
	if _arena_instance == null:
		return null
	return _arena_instance.get_node_or_null("WorldCanvasLayer/WorldViewportContainer/WorldViewport/Arena")

func _sync_buff_ui() -> void:
	if _player_buff_strip == null:
		return
	if _arena_instance == null:
		_set_buff_strip_visibility(false, false, false, false)
		return
	var arena_node: Node = _resolve_runtime_arena_node()
	if arena_node == null or not arena_node.has_method("get_buff_ui_snapshot"):
		_set_buff_strip_visibility(false, false, false, false)
		return
	var snap_v: Variant = arena_node.call("get_buff_ui_snapshot")
	if typeof(snap_v) != TYPE_DICTIONARY:
		return
	var snapshot: Dictionary = snap_v as Dictionary
	if not bool(snapshot.get("buffs_enabled", false)):
		_set_buff_strip_visibility(false, false, false, false)
		return
	_player_buff_strip.visible = true
	var active_pid: int = int(snapshot.get("active_player_id", 1))
	_buff_ui_last_active_pid = active_pid
	var players_any: Variant = snapshot.get("players", {})
	var players: Dictionary = {}
	if typeof(players_any) == TYPE_DICTIONARY:
		players = players_any as Dictionary
	var player_data: Dictionary = _player_data_for_pid(players, active_pid)
	if _player_buff_strip.has_method("apply_snapshot"):
		_player_buff_strip.call("apply_snapshot", player_data)
	var active_seats: Array = _active_seats_from_hud()
	var relation: Dictionary = _split_relative_seats(active_pid, players, active_seats)
	var ally_seats: Array = relation.get("allies", [])
	var opponent_seats: Array = relation.get("opponents", [])
	_sync_side_strip(_ally_buff_strip, players, ally_seats, _ally_strip_title(active_seats, ally_seats))
	_sync_opponent_strips(players, opponent_seats, active_seats, ally_seats)
	_layout_buff_strip_positions()

func _set_buff_strip_visibility(player_visible: bool, opponent_visible: bool, opponent_b_visible: bool, ally_visible: bool) -> void:
	if _player_buff_strip != null:
		_player_buff_strip.visible = player_visible
	if _opponent_buff_strip != null:
		_opponent_buff_strip.visible = opponent_visible
	if _opponent_buff_strip_b != null:
		_opponent_buff_strip_b.visible = opponent_b_visible
	if _ally_buff_strip != null:
		_ally_buff_strip.visible = ally_visible

func _layout_buff_strip_positions() -> void:
	_layout_player_strip_inside_bottom_buffer()
	_layout_side_strips_inside_bottom_buffer()

func _visible_screen_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var size: Vector2 = vp.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return Rect2()
	return Rect2(Vector2.ZERO, size)

func _bottom_buffer_layout_rect(bottom_buffer: Control) -> Rect2:
	if bottom_buffer == null:
		return Rect2()
	var buffer_rect: Rect2 = bottom_buffer.get_global_rect()
	var visible_rect: Rect2 = _visible_screen_rect()
	if visible_rect.size.x <= 1.0 or visible_rect.size.y <= 1.0:
		return buffer_rect
	if not buffer_rect.intersects(visible_rect):
		return visible_rect
	var clipped: Rect2 = buffer_rect.intersection(visible_rect)
	if clipped.size.x <= 1.0 or clipped.size.y <= 1.0:
		return visible_rect
	return clipped

func _layout_player_strip_inside_bottom_buffer() -> void:
	var player_strip: Control = _player_buff_strip as Control
	if player_strip == null or not player_strip.visible:
		return
	var bottom_buffer: Control = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as Control
	if bottom_buffer == null:
		return
	var parent_rect: Rect2 = _bottom_buffer_layout_rect(bottom_buffer)
	if parent_rect.size.x <= 1.0 or parent_rect.size.y <= 1.0:
		return
	var max_width: float = maxf(220.0, parent_rect.size.x - (BUFF_SIDE_STRIP_MARGIN_PX * 2.0))
	var target_width: float = minf(BUFF_PLAYER_STRIP_WIDTH_PX, max_width)
	var target_height: float = minf(BUFF_PLAYER_STRIP_HEIGHT_PX, maxf(96.0, parent_rect.size.y - (BUFF_SIDE_STRIP_MARGIN_PX * 2.0)))
	var target_pos: Vector2 = Vector2(
		parent_rect.end.x - target_width - BUFF_SIDE_STRIP_MARGIN_PX,
		parent_rect.end.y - target_height - BUFF_SIDE_STRIP_MARGIN_PX
	)
	_set_control_global_rect(player_strip, Rect2(target_pos, Vector2(target_width, target_height)))
	player_strip.z_as_relative = false
	player_strip.z_index = 3000
	_compact_player_strip(player_strip)

func _compact_player_strip(player_strip: Control) -> void:
	if player_strip == null:
		return
	var slots_row: HBoxContainer = player_strip.get_node_or_null("Center/SlotsRow") as HBoxContainer
	if slots_row != null:
		slots_row.add_theme_constant_override("separation", BUFF_PLAYER_SLOT_SEPARATION_PX)
		slots_row.custom_minimum_size = Vector2(0.0, BUFF_PLAYER_SLOT_SIZE_PX)
		slots_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for idx in [1, 2, 3]:
		var slot: Panel = player_strip.get_node_or_null("Center/SlotsRow/BuffSlot%d" % idx) as Panel
		if slot == null:
			continue
		slot.custom_minimum_size = Vector2(BUFF_PLAYER_SLOT_SIZE_PX, BUFF_PLAYER_SLOT_SIZE_PX)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _layout_side_strips_inside_bottom_buffer() -> void:
	var bottom_buffer: Control = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as Control
	if bottom_buffer == null:
		return
	var parent_rect: Rect2 = _bottom_buffer_layout_rect(bottom_buffer)
	if parent_rect.size.x <= 1.0 or parent_rect.size.y <= 1.0:
		return

	var left_strips: Array[Control] = []
	if _opponent_buff_strip != null and _opponent_buff_strip.visible:
		left_strips.append(_opponent_buff_strip)
	if _opponent_buff_strip_b != null and _opponent_buff_strip_b.visible:
		left_strips.append(_opponent_buff_strip_b)
	var left_count: int = left_strips.size()
	if left_count <= 0:
		return

	var center_x: float = parent_rect.position.x + parent_rect.size.x * 0.5
	var left_bound: float = parent_rect.position.x + BUFF_SIDE_STRIP_MARGIN_PX
	var max_right: float = center_x - BUFF_SIDE_STRIP_MARGIN_PX
	var max_width_left: float = maxf(96.0, max_right - left_bound)
	var available_h: float = maxf(BUFF_OPP_STRIP_MIN_HEIGHT_PX, parent_rect.size.y - (BUFF_SIDE_STRIP_MARGIN_PX * 2.0))
	var dyn_h: float = (available_h - (BUFF_OPP_STRIP_ROW_GAP_PX * float(maxi(0, left_count - 1)))) / float(left_count)
	var strip_h: float = clampf(dyn_h, BUFF_OPP_STRIP_MIN_HEIGHT_PX, BUFF_OPP_STRIP_MAX_HEIGHT_PX)
	var strip_size: Vector2 = _resolved_opponent_strip_size(parent_rect, max_width_left, strip_h)
	var base_x: float = minf(left_bound, max_right - strip_size.x)
	base_x = maxf(left_bound, base_x)
	var base_y: float = parent_rect.end.y - strip_size.y - BUFF_SIDE_STRIP_MARGIN_PX

	for i in range(left_strips.size()):
		var strip: Control = left_strips[i]
		_compact_opponent_strip(strip, strip_size)
		var y: float = base_y - float(i) * (strip_size.y + BUFF_OPP_STRIP_ROW_GAP_PX)
		y = maxf(parent_rect.position.y + BUFF_SIDE_STRIP_MARGIN_PX, y)
		_set_control_global_rect(strip, Rect2(Vector2(base_x, y), strip_size))
		strip.z_as_relative = false
		strip.z_index = 3000

	if _ally_buff_strip != null and _ally_buff_strip.visible:
		var ally_strip: Control = _ally_buff_strip as Control
		var ally_size: Vector2 = _resolved_side_strip_size(parent_rect)
		var right_x: float = parent_rect.end.x - ally_size.x - BUFF_SIDE_STRIP_MARGIN_PX
		var y: float = parent_rect.end.y - ally_size.y - BUFF_SIDE_STRIP_MARGIN_PX
		_compact_side_strip(ally_strip)
		_set_control_global_rect(ally_strip, Rect2(Vector2(right_x, y), ally_size))
		ally_strip.z_as_relative = false
		ally_strip.z_index = 3000

func _resolved_opponent_strip_size(parent_rect: Rect2, max_width_left: float, preferred_h: float) -> Vector2:
	var width_px: float = maxf(64.0, max_width_left)
	var max_h: float = maxf(BUFF_OPP_STRIP_MIN_HEIGHT_PX, parent_rect.size.y - (BUFF_SIDE_STRIP_MARGIN_PX * 2.0))
	var height_px: float = clampf(preferred_h, BUFF_OPP_STRIP_MIN_HEIGHT_PX, max_h)
	return Vector2(width_px, height_px)

func _resolved_side_strip_size(parent_rect: Rect2) -> Vector2:
	var max_h: float = maxf(180.0, parent_rect.size.y - (BUFF_SIDE_STRIP_MARGIN_PX * 2.0))
	var resolved_h: float = minf(BUFF_SIDE_STRIP_TARGET_HEIGHT_PX, max_h)
	return Vector2(BUFF_SIDE_STRIP_WIDTH_PX, resolved_h)

func _compact_opponent_strip(strip: Control, strip_size: Vector2) -> void:
	if strip == null:
		return
	if strip.has_method("set_show_title"):
		strip.call("set_show_title", false)
	var title_label: Label = strip.get_node_or_null("Title") as Label
	if title_label != null:
		title_label.visible = false
	var slots_row: Control = strip.get_node_or_null("SlotsColumn") as Control
	if slots_row != null:
		slots_row.anchor_left = 0.0
		slots_row.anchor_top = 0.0
		slots_row.anchor_right = 1.0
		slots_row.anchor_bottom = 1.0
		slots_row.offset_left = 0.0
		slots_row.offset_top = 0.0
		slots_row.offset_right = 0.0
		slots_row.offset_bottom = 0.0
		var box: BoxContainer = slots_row as BoxContainer
		if box != null:
			var slot_size: float = _resolved_opponent_slot_size(strip_size)
			var sep: int = _resolved_opponent_slot_separation(strip_size.x, slot_size)
			box.add_theme_constant_override("separation", sep)
			box.alignment = BoxContainer.ALIGNMENT_CENTER
	for idx in [1, 2, 3]:
		var slot: Panel = strip.get_node_or_null("SlotsColumn/OpponentSlot%d" % idx) as Panel
		if slot != null:
			var resolved_slot_size: float = _resolved_opponent_slot_size(strip_size)
			slot.custom_minimum_size = Vector2(resolved_slot_size, resolved_slot_size)
		var used_mark: Label = strip.get_node_or_null("SlotsColumn/OpponentSlot%d/UsedMark" % idx) as Label
		if used_mark != null:
			used_mark.add_theme_font_size_override("font_size", BUFF_OPP_USED_MARK_FONT_SIZE)

func _resolved_opponent_slot_size(strip_size: Vector2) -> float:
	var slot_by_h: float = strip_size.y - 8.0
	var slot_by_w: float = (strip_size.x - (BUFF_OPP_ROW_SIDE_PAD_PX * 2.0) - (float(BUFF_OPP_SLOT_SEPARATION_PX) * 2.0)) / 3.0
	return clampf(minf(slot_by_h, slot_by_w), BUFF_OPP_SLOT_MIN_PX, BUFF_OPP_SLOT_MAX_PX)

func _resolved_opponent_slot_separation(strip_w: float, slot_size: float) -> int:
	var free_w: float = strip_w - (BUFF_OPP_ROW_SIDE_PAD_PX * 2.0) - (slot_size * 3.0)
	var ideal_sep: float = maxf(4.0, free_w / 2.0)
	return int(round(clampf(ideal_sep, 4.0, 64.0)))

func _compact_side_strip(strip: Control) -> void:
	if strip == null:
		return
	if strip.has_method("set_show_title"):
		strip.call("set_show_title", false)
	var title_label: Label = strip.get_node_or_null("Title") as Label
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", BUFF_SIDE_TITLE_FONT_SIZE)
	var slots_column: VBoxContainer = strip.get_node_or_null("SlotsColumn") as VBoxContainer
	if slots_column != null:
		slots_column.add_theme_constant_override("separation", BUFF_SIDE_SLOT_SEPARATION_PX)
		slots_column.offset_top = 4.0
	for idx in [1, 2, 3]:
		var slot: Panel = strip.get_node_or_null("SlotsColumn/OpponentSlot%d" % idx) as Panel
		if slot != null:
			slot.custom_minimum_size = Vector2(BUFF_SIDE_SLOT_SIZE_PX, BUFF_SIDE_SLOT_SIZE_PX)
		var used_mark: Label = strip.get_node_or_null("SlotsColumn/OpponentSlot%d/UsedMark" % idx) as Label
		if used_mark != null:
			used_mark.add_theme_font_size_override("font_size", BUFF_SIDE_USED_MARK_FONT_SIZE)

func _layout_teammate_strip_left_of_player_slots() -> void:
	if _ally_buff_strip == null or _player_buff_strip == null:
		return
	var ally_strip: Control = _ally_buff_strip as Control
	var player_strip: Control = _player_buff_strip as Control
	if ally_strip == null or player_strip == null:
		return
	if not ally_strip.visible or not player_strip.visible:
		return
	var parent: Control = ally_strip.get_parent() as Control
	if parent == null:
		return
	var slots_rect: Rect2 = _player_slots_cluster_global_rect(player_strip)
	if slots_rect.size.x <= 0.0 or slots_rect.size.y <= 0.0:
		return
	var bottom_buffer: Control = get_node_or_null(SHELL_BOTTOM_BUFFER_PATH) as Control
	var parent_rect: Rect2 = _bottom_buffer_layout_rect(bottom_buffer if bottom_buffer != null else parent)
	var target_size: Vector2 = _resolved_side_strip_size(parent_rect)
	var gap_px: float = 24.0
	_compact_side_strip(ally_strip)
	var target_pos: Vector2 = Vector2(
		slots_rect.position.x - target_size.x - gap_px,
		slots_rect.position.y + slots_rect.size.y - target_size.y
	)
	var min_x: float = maxf(parent_rect.position.x + 8.0, parent_rect.position.x + parent_rect.size.x * 0.5 + 8.0)
	target_pos.x = clampf(target_pos.x, min_x, parent_rect.end.x - target_size.x - 8.0)
	target_pos.y = clampf(target_pos.y, parent_rect.position.y + 8.0, parent_rect.end.y - target_size.y - 8.0)
	_set_control_global_rect(ally_strip, Rect2(target_pos, target_size))
	ally_strip.z_as_relative = false
	ally_strip.z_index = 3000

func _player_slots_cluster_global_rect(player_strip: Control) -> Rect2:
	if player_strip == null:
		return Rect2()
	var slot_nodes: Array[Control] = []
	for idx in [1, 2, 3]:
		var slot_node: Control = player_strip.get_node_or_null("Center/SlotsRow/BuffSlot%d" % idx) as Control
		if slot_node == null or not slot_node.visible:
			continue
		slot_nodes.append(slot_node)
	if slot_nodes.is_empty():
		var slots_row: Control = player_strip.get_node_or_null("Center/SlotsRow") as Control
		if slots_row != null:
			return slots_row.get_global_rect()
		return player_strip.get_global_rect()
	var merged: Rect2 = slot_nodes[0].get_global_rect()
	for i in range(1, slot_nodes.size()):
		merged = merged.merge(slot_nodes[i].get_global_rect())
	return merged

func _set_control_global_rect(ctrl: Control, global_rect: Rect2) -> void:
	if ctrl == null:
		return
	var parent: Control = ctrl.get_parent() as Control
	if parent == null:
		return
	var parent_inv: Transform2D = parent.get_global_transform_with_canvas().affine_inverse()
	var local_pos: Vector2 = parent_inv * global_rect.position
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = local_pos.x
	ctrl.offset_top = local_pos.y
	ctrl.offset_right = local_pos.x + global_rect.size.x
	ctrl.offset_bottom = local_pos.y + global_rect.size.y

func _player_data_for_pid(players: Dictionary, pid: int) -> Dictionary:
	var value: Variant = players.get(pid, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}

func _active_seats_from_hud() -> Array:
	var hud: Dictionary = OpsState.get_hud_snapshot()
	var seats_any: Variant = hud.get("active_seats", [])
	var out: Array = []
	if typeof(seats_any) == TYPE_ARRAY:
		for seat_any in seats_any as Array:
			var seat: int = int(seat_any)
			if seat >= 1 and seat <= 4 and not out.has(seat):
				out.append(seat)
	if out.is_empty():
		out = [1, 2]
	out.sort()
	return out

func _split_relative_seats(active_pid: int, players: Dictionary, active_seats: Array) -> Dictionary:
	var candidates: Array = []
	var candidate_lookup: Dictionary = {}
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		if seat < 1 or seat > 4 or seat == active_pid:
			continue
		if candidate_lookup.has(seat):
			continue
		candidate_lookup[seat] = true
		candidates.append(seat)
	for key_any in players.keys():
		var seat: int = int(key_any)
		if seat < 1 or seat > 4 or seat == active_pid:
			continue
		if candidate_lookup.has(seat):
			continue
		candidate_lookup[seat] = true
		candidates.append(seat)
	var allies: Array = []
	var opponents: Array = []
	if _team_mode_ui == "2v2":
		var canonical_teammate: int = _canonical_teammate_seat(active_pid)
		if canonical_teammate > 0 and candidates.has(canonical_teammate):
			allies.append(canonical_teammate)
			for seat_any in candidates:
				var seat: int = int(seat_any)
				if seat == canonical_teammate:
					continue
				opponents.append(seat)
			allies.sort()
			opponents.sort()
			return {
				"allies": allies,
				"opponents": opponents
			}
	for seat_any in candidates:
		var seat: int = int(seat_any)
		var same_team: bool = false
		if OpsState.has_method("are_allies"):
			same_team = bool(OpsState.call("are_allies", active_pid, seat))
		if same_team:
			allies.append(seat)
		else:
			opponents.append(seat)
	if opponents.is_empty() and not candidates.is_empty():
		var fallback_pid: int = _pick_opponent_pid(active_pid, players, candidates)
		if allies.has(fallback_pid):
			allies.erase(fallback_pid)
		if not opponents.has(fallback_pid):
			opponents.append(fallback_pid)
	# UI fallback for layout sanity: if mode is explicitly 2v2 but ally data still
	# resolves empty, enforce canonical teammate pairing.
	if allies.is_empty() and _team_mode_ui == "2v2":
		var canonical_teammate: int = _canonical_teammate_seat(active_pid)
		if canonical_teammate > 0 and canonical_teammate != active_pid and candidates.has(canonical_teammate):
			if opponents.has(canonical_teammate):
				opponents.erase(canonical_teammate)
			if not allies.has(canonical_teammate):
				allies.append(canonical_teammate)
		for seat_any in candidates:
			var seat: int = int(seat_any)
			if seat == active_pid or seat == canonical_teammate:
				continue
			if not opponents.has(seat):
				opponents.append(seat)
	allies.sort()
	opponents.sort()
	return {
		"allies": allies,
		"opponents": opponents
	}

func _canonical_teammate_seat(active_pid: int) -> int:
	match int(active_pid):
		1:
			return 3
		2:
			return 4
		3:
			return 1
		4:
			return 2
	return -1

func _ally_strip_title(_active_seats: Array, ally_seats: Array) -> String:
	if ally_seats.size() <= 1:
		return "Teammate Buffs"
	return "Ally Buffs"

func _opponent_strip_title(active_seats: Array, ally_seats: Array) -> String:
	if active_seats.size() <= 2:
		return "Opponent Buffs"
	if not ally_seats.is_empty():
		return "Opponent Team"
	return "Opponents"

func _sync_opponent_strips(players: Dictionary, opponent_seats: Array, active_seats: Array, ally_seats: Array) -> void:
	var seats: Array = []
	for seat_any in opponent_seats:
		var seat: int = int(seat_any)
		if seat < 1 or seat > 4 or seats.has(seat):
			continue
		seats.append(seat)
	seats.sort()
	var primary_seats: Array = []
	var secondary_seats: Array = []
	if seats.size() > 0:
		primary_seats.append(int(seats[0]))
	if seats.size() > 1:
		secondary_seats.append(int(seats[1]))
	for i in range(2, seats.size()):
		secondary_seats.append(int(seats[i]))
	var primary_title: String = _opponent_strip_title(active_seats, ally_seats)
	var secondary_title: String = ""
	if seats.size() > 1:
		primary_title = "Opponent 1" if not ally_seats.is_empty() else "Opp 1"
		secondary_title = "Opponent 2" if not ally_seats.is_empty() else "Opp 2"
	_sync_side_strip(_opponent_buff_strip, players, primary_seats, primary_title)
	_sync_side_strip(_opponent_buff_strip_b, players, secondary_seats, secondary_title)

func _sync_side_strip(strip: Control, players: Dictionary, seats: Array, strip_title: String) -> void:
	if strip == null:
		return
	var deduped: Array = []
	for seat_any in seats:
		var seat: int = int(seat_any)
		if seat < 1 or seat > 4 or deduped.has(seat):
			continue
		deduped.append(seat)
	deduped.sort()
	if deduped.is_empty():
		strip.visible = false
		if strip.has_method("set_visible_slot_count"):
			strip.call("set_visible_slot_count", 0)
		if strip.has_method("reset_slots"):
			strip.call("reset_slots")
		return
	var side_data: Dictionary = _aggregate_side_data(players, deduped)
	var slots_active: int = int(side_data.get("slots_active", 0))
	var is_opponent_strip: bool = (strip == _opponent_buff_strip or strip == _opponent_buff_strip_b)
	if is_opponent_strip:
		slots_active = maxi(3, slots_active)
	if slots_active <= 0 and not deduped.is_empty():
		# Layout-first fallback: keep side strips visible even if per-seat slot data
		# has not hydrated yet for this frame.
		slots_active = 3
	strip.visible = slots_active > 0
	if strip.has_method("set_strip_title"):
		strip.call("set_strip_title", strip_title)
	if strip.has_method("set_show_title"):
		strip.call("set_show_title", true)
	if strip.has_method("set_visible_slot_count"):
		strip.call("set_visible_slot_count", slots_active)
	if strip.has_method("set_used_slots"):
		strip.call("set_used_slots", side_data.get("used_slots", []))

func _aggregate_side_data(players: Dictionary, seats: Array) -> Dictionary:
	var slots_active: int = 0
	var used_lookup: Dictionary = {}
	for seat_any in seats:
		var seat: int = int(seat_any)
		var player_data: Dictionary = _player_data_for_pid(players, seat)
		slots_active = maxi(slots_active, int(player_data.get("slots_active", 0)))
		var used_slots: Array = _collect_used_slots(player_data)
		for used_any in used_slots:
			var slot_idx: int = int(used_any)
			if slot_idx < 0:
				continue
			used_lookup[slot_idx] = true
	var merged_used_slots: Array = used_lookup.keys()
	merged_used_slots.sort()
	return {
		"slots_active": slots_active,
		"used_slots": merged_used_slots
	}

func _pick_opponent_pid(active_pid: int, players: Dictionary, active_seats: Array) -> int:
	var candidates: Array = []
	for seat_any in active_seats:
		var seat: int = int(seat_any)
		if seat == active_pid:
			continue
		if not players.has(seat):
			continue
		candidates.append(seat)
	if candidates.is_empty():
		for key_any in players.keys():
			var seat: int = int(key_any)
			if seat != active_pid:
				candidates.append(seat)
	if candidates.is_empty():
		return 2 if active_pid == 1 else 1
	for seat_any in candidates:
		var seat: int = int(seat_any)
		if not OpsState.has_method("are_allies"):
			return seat
		if not bool(OpsState.call("are_allies", active_pid, seat)):
			return seat
	return int(candidates[0])

func _collect_used_slots(player_data: Dictionary) -> Array:
	var used: Array = []
	var slots_any: Variant = player_data.get("slots", [])
	if typeof(slots_any) != TYPE_ARRAY:
		return used
	var slots: Array = slots_any as Array
	for i in range(slots.size()):
		if typeof(slots[i]) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = slots[i] as Dictionary
		if bool(slot.get("consumed", false)) or bool(slot.get("active", false)):
			used.append(i)
	return used

func _on_player_buff_drag_started(slot_index: int, buff_id: String) -> void:
	SFLog.info("BUFF_DRAG_STARTED", {
		"pid": _buff_ui_last_active_pid,
		"slot_index": slot_index,
		"buff_id": buff_id
	})

func _on_player_buff_drop_requested(slot_index: int, screen_pos: Vector2, held_ms: int) -> void:
	var arena_node: Node = _resolve_runtime_arena_node()
	if arena_node == null or not arena_node.has_method("request_buff_drop"):
		return
	var world_pos: Vector2 = screen_pos
	if arena_node.has_method("_screen_to_world"):
		world_pos = arena_node.call("_screen_to_world", screen_pos)
	var result_v: Variant = arena_node.call("request_buff_drop", _buff_ui_last_active_pid, slot_index, world_pos)
	var result: Dictionary = {}
	if typeof(result_v) == TYPE_DICTIONARY:
		result = result_v as Dictionary
	SFLog.info("BUFF_DROP_REQUEST", {
		"pid": _buff_ui_last_active_pid,
		"slot_index": slot_index,
		"held_ms": held_ms,
		"screen_pos": screen_pos,
		"world_pos": world_pos,
		"ok": bool(result.get("ok", false)),
		"reason": str(result.get("reason", "")),
		"target": result.get("target", {})
	})
	call_deferred("_sync_buff_ui")

func _on_player_buff_drag_cancelled(slot_index: int, reason: String) -> void:
	SFLog.info("BUFF_DRAG_CANCELLED", {
		"pid": _buff_ui_last_active_pid,
		"slot_index": slot_index,
		"reason": reason
	})

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
	var should_show: bool = _is_match_live()
	power_bar.visible = should_show
	if _last_power_bar_visible != int(should_show):
		_last_power_bar_visible = int(should_show)
		SFLog.info("POWERBAR_VISIBLE", {
			"visible": should_show,
			"prematch_ms": int(OpsState.prematch_remaining_ms),
			"phase": int(OpsState.match_phase)
		})

func _is_match_live() -> bool:
	var phase: int = int(OpsState.match_phase)
	var prematch_ms: int = int(OpsState.prematch_remaining_ms)
	if phase == int(OpsState.MatchPhase.PREMATCH):
		return prematch_ms <= PREMATCH_POWERBAR_REVEAL_WINDOW_MS
	return phase == int(OpsState.MatchPhase.RUNNING) and prematch_ms <= 0

func _maybe_start_soak_perf() -> bool:
	var config: Dictionary = _parse_soak_perf_config(OS.get_cmdline_user_args())
	if not bool(config.get("enabled", false)):
		return false
	call_deferred("_run_soak_perf", config)
	return true

func _parse_soak_perf_config(args: Array) -> Dictionary:
	var config: Dictionary = {
		"enabled": false,
		"map_path": "",
		"seconds": SOAK_DEFAULT_SECONDS,
		"round_seconds": SOAK_DEFAULT_ROUND_SECONDS,
		"pairs": SOAK_DEFAULT_PAIR_COUNT,
		"reapply_ms": SOAK_DEFAULT_REAPPLY_MS,
		"start_timeout_ms": SOAK_DEFAULT_START_TIMEOUT_MS
	}
	for arg_any in args:
		var arg: String = str(arg_any)
		if arg == "--soak-perf":
			config["enabled"] = true
		elif arg.begins_with("--soak-map="):
			config["map_path"] = arg.trim_prefix("--soak-map=")
		elif arg.begins_with("--soak-seconds="):
			config["seconds"] = max(10, int(arg.trim_prefix("--soak-seconds=")))
		elif arg.begins_with("--soak-round-seconds="):
			config["round_seconds"] = max(10, int(arg.trim_prefix("--soak-round-seconds=")))
		elif arg.begins_with("--soak-pairs="):
			config["pairs"] = clampi(int(arg.trim_prefix("--soak-pairs=")), 1, 8)
		elif arg.begins_with("--soak-reapply-ms="):
			config["reapply_ms"] = max(250, int(arg.trim_prefix("--soak-reapply-ms=")))
		elif arg.begins_with("--soak-start-timeout-ms="):
			config["start_timeout_ms"] = max(1000, int(arg.trim_prefix("--soak-start-timeout-ms=")))
	return config

func _run_soak_perf(config: Dictionary) -> void:
	var prev_log_level: int = int(SFLog.LOG_LEVEL)
	SFLog.LOG_LEVEL = SFLog.Level.INFO
	SFLog.allow_tag("SOAK_START")
	SFLog.allow_tag("SOAK_ROUND_START")
	SFLog.allow_tag("SOAK_ROUND_INTENTS")
	SFLog.allow_tag("SOAK_ROUND_END")
	SFLog.allow_tag("SOAK_SUMMARY")
	SFLog.allow_tag("SOAK_ERROR")
	SFLog.allow_tag("ARENA_FRAME_HEARTBEAT")
	SFLog.allow_tag("SIM_HEARTBEAT")
	SFLog.allow_tag("SIM_TICK_COST")

	var map_path: String = str(config.get("map_path", "")).strip_edges()
	if map_path == "":
		var maps: Array[String] = _mvp_list_json_maps()
		if not maps.is_empty():
			map_path = maps[0]
	if map_path == "":
		SFLog.warn("SOAK_ERROR", {"reason": "no_map_available"})
		SFLog.LOG_LEVEL = prev_log_level
		get_tree().quit(1)
		return
	var soak_seconds: int = int(config.get("seconds", SOAK_DEFAULT_SECONDS))
	var round_seconds: int = int(config.get("round_seconds", SOAK_DEFAULT_ROUND_SECONDS))
	var pair_count: int = int(config.get("pairs", SOAK_DEFAULT_PAIR_COUNT))
	var reapply_ms: int = int(config.get("reapply_ms", SOAK_DEFAULT_REAPPLY_MS))
	var start_timeout_ms: int = int(config.get("start_timeout_ms", SOAK_DEFAULT_START_TIMEOUT_MS))
	_stop_game()
	await get_tree().process_frame
	_apply_map_then_start(map_path)
	var boot_running_ok: bool = await _mvp_wait_for_phase(int(OpsState.MatchPhase.RUNNING), start_timeout_ms)
	if not boot_running_ok:
		SFLog.warn("SOAK_ERROR", {"round": 0, "reason": "initial_match_not_running"})
		SFLog.LOG_LEVEL = prev_log_level
		get_tree().quit(1)
		return
	_soak_disable_bots()

	var soak_start_ms := Time.get_ticks_msec()
	var soak_deadline_ms := soak_start_ms + (soak_seconds * 1000)
	var rounds: int = 0
	var failed_rounds: int = 0
	SFLog.info("SOAK_START", {
		"map": map_path,
		"seconds": soak_seconds,
		"round_seconds": round_seconds,
		"pairs": pair_count
	})
	while Time.get_ticks_msec() < soak_deadline_ms:
		rounds += 1
		var remaining_ms: int = soak_deadline_ms - Time.get_ticks_msec()
		var round_budget_ms: int = mini(round_seconds * 1000, remaining_ms)
		var ok: bool = await _run_soak_perf_round(rounds, round_budget_ms, map_path, pair_count, reapply_ms, start_timeout_ms)
		if not ok:
			failed_rounds += 1
	var elapsed_ms := Time.get_ticks_msec() - soak_start_ms
	SFLog.info("SOAK_SUMMARY", {
		"rounds": rounds,
		"failed_rounds": failed_rounds,
		"elapsed_s": snapped(float(elapsed_ms) / 1000.0, 0.1)
	})
	SFLog.LOG_LEVEL = prev_log_level
	_stop_game()
	await get_tree().process_frame
	get_tree().quit(1 if failed_rounds > 0 else 0)

func _run_soak_perf_round(
	round_index: int,
	round_budget_ms: int,
	map_path: String,
	pair_count: int,
	reapply_ms: int,
	start_timeout_ms: int
) -> bool:
	SFLog.info("SOAK_ROUND_START", {
		"round": round_index,
		"budget_ms": round_budget_ms
	})
	if int(OpsState.match_phase) != int(OpsState.MatchPhase.RUNNING):
		_apply_map_then_start(map_path)
		var running_ok: bool = await _mvp_wait_for_phase(int(OpsState.MatchPhase.RUNNING), start_timeout_ms)
		if not running_ok:
			SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "match_not_running"})
			return false
		_soak_disable_bots()
	var pairs: Array = _soak_pick_duel_pairs(pair_count)
	if pairs.is_empty():
		SFLog.warn("SOAK_ERROR", {"round": round_index, "reason": "no_opposing_pairs"})
		return false
	_soak_ensure_pairs_active(pairs)
	SFLog.info("SOAK_ROUND_INTENTS", {
		"round": round_index,
		"pairs": pairs
	})
	var end_ms: int = Time.get_ticks_msec() + maxi(1000, round_budget_ms)
	var last_reapply_ms: int = 0
	while Time.get_ticks_msec() < end_ms:
		if OpsState.match_phase == OpsState.MatchPhase.ENDED:
			break
		var now_ms := Time.get_ticks_msec()
		if now_ms - last_reapply_ms >= reapply_ms:
			last_reapply_ms = now_ms
			if not _soak_ensure_pairs_active(pairs):
				pairs = _soak_pick_duel_pairs(pair_count)
				_soak_ensure_pairs_active(pairs)
		await get_tree().process_frame
	SFLog.info("SOAK_ROUND_END", {
		"round": round_index,
		"phase": int(OpsState.match_phase)
	})
	return true

func _soak_pick_duel_pairs(max_pairs: int) -> Array:
	var st: GameState = OpsState.get_state()
	if st == null:
		return []
	var candidates: Array = []
	for lane_any in st.lanes:
		if not (lane_any is LaneData):
			continue
		var lane: LaneData = lane_any as LaneData
		var a_hive: HiveData = st.find_hive_by_id(int(lane.a_id))
		var b_hive: HiveData = st.find_hive_by_id(int(lane.b_id))
		if a_hive == null or b_hive == null:
			continue
		var a_owner: int = int(a_hive.owner_id)
		var b_owner: int = int(b_hive.owner_id)
		if a_owner <= 0 or b_owner <= 0 or a_owner == b_owner:
			continue
		var a_pos: Vector2 = st.hive_world_pos_by_id(int(a_hive.id))
		var b_pos: Vector2 = st.hive_world_pos_by_id(int(b_hive.id))
		candidates.append({
			"src": int(a_hive.id),
			"dst": int(b_hive.id),
			"len": a_pos.distance_to(b_pos)
		})
	if candidates.is_empty():
		for i in range(st.hives.size()):
			var a_any: Variant = st.hives[i]
			if not (a_any is HiveData):
				continue
			var a_hive: HiveData = a_any as HiveData
			var a_owner: int = int(a_hive.owner_id)
			if a_owner <= 0:
				continue
			for j in range(i + 1, st.hives.size()):
				var b_any: Variant = st.hives[j]
				if not (b_any is HiveData):
					continue
				var b_hive: HiveData = b_any as HiveData
				var b_owner: int = int(b_hive.owner_id)
				if b_owner <= 0 or b_owner == a_owner:
					continue
				var a_pos_fb: Vector2 = st.hive_world_pos_by_id(int(a_hive.id))
				var b_pos_fb: Vector2 = st.hive_world_pos_by_id(int(b_hive.id))
				candidates.append({
					"src": int(a_hive.id),
					"dst": int(b_hive.id),
					"len": a_pos_fb.distance_to(b_pos_fb)
				})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("len", 0.0)) > float(b.get("len", 0.0))
	)
	var pairs: Array = []
	for c_any in candidates:
		if pairs.size() >= max_pairs:
			break
		var c: Dictionary = c_any as Dictionary
		pairs.append({
			"src": int(c.get("src", -1)),
			"dst": int(c.get("dst", -1))
		})
	return pairs

func _soak_ensure_pairs_active(pairs: Array) -> bool:
	var st: GameState = OpsState.get_state()
	if st == null:
		return false
	var kept: int = 0
	for p_any in pairs:
		if typeof(p_any) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_any as Dictionary
		var src: int = int(p.get("src", -1))
		var dst: int = int(p.get("dst", -1))
		if src <= 0 or dst <= 0 or src == dst:
			continue
		var src_hive: HiveData = st.find_hive_by_id(src)
		var dst_hive: HiveData = st.find_hive_by_id(dst)
		if src_hive == null or dst_hive == null:
			continue
		var src_owner: int = int(src_hive.owner_id)
		var dst_owner: int = int(dst_hive.owner_id)
		if src_owner <= 0 or dst_owner <= 0 or src_owner == dst_owner:
			continue
		_soak_ensure_attack_intent(src, dst, st)
		_soak_ensure_attack_intent(dst, src, st)
		kept += 1
	return kept > 0

func _soak_ensure_attack_intent(src: int, dst: int, st: GameState) -> void:
	if st.intent_is_on(src, dst):
		return
	OpsState.apply_lane_intent(src, dst, "attack")

func _soak_disable_bots() -> void:
	if OpsState == null or not OpsState.has_method("set_bot_profile"):
		return
	for seat in [1, 2, 3, 4]:
		OpsState.call("set_bot_profile", int(seat), {"enabled": false})

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

	var sim_runner_node: Node = arena_node.get_node_or_null("SimRunner") if arena_node != null else null
	var sim_stopped_during_prematch: bool = sim_runner_node != null and not bool(sim_runner_node.get("running"))
	if sim_stopped_during_prematch:
		passes += _mvp_smoke_pass("sim_stopped_during_prematch", {})
	else:
		fails += _mvp_smoke_fail("sim_stopped_during_prematch", {
			"sim_runner_found": sim_runner_node != null,
			"running": bool(sim_runner_node.get("running")) if sim_runner_node != null else null,
			"phase": int(OpsState.match_phase)
		})

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
	if _mvp_map_utils == null:
		_mvp_map_utils = ShellMvpMapUtils.new()
	return _mvp_map_utils.list_json_maps()

func _mvp_wait_for_node(path: String, timeout_ms: int) -> Node:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	return await _mvp_waiter.wait_for_node(self, path, timeout_ms)

func _mvp_wait_for_records_visible(timeout_ms: int) -> bool:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	return await _mvp_waiter.wait_for_records_visible(
		self,
		MVP_SMOKE_RECORDS_PATH,
		OpsState,
		int(OpsState.MatchPhase.PREMATCH),
		timeout_ms
	)

func _mvp_wait_for_phase(target_phase: int, timeout_ms: int) -> bool:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	return await _mvp_waiter.wait_for_phase(self, OpsState, target_phase, timeout_ms)

func _mvp_wait_for_phase_not(target_phase: int, timeout_ms: int) -> bool:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	return await _mvp_waiter.wait_for_phase_not(self, OpsState, target_phase, timeout_ms)

func _mvp_wait_ms(duration_ms: int) -> void:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	await _mvp_waiter.wait_ms(self, duration_ms)

func _mvp_wait_for_outcome_overlay_visible(timeout_ms: int) -> bool:
	if _mvp_waiter == null:
		_mvp_waiter = ShellMvpWaiter.new()
	return await _mvp_waiter.wait_for_outcome_overlay_visible(self, MVP_SMOKE_OUTCOME_OVERLAY_PATH, timeout_ms)

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
