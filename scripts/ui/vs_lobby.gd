extends Control
const SFLog := preload("res://scripts/util/sf_log.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")

signal closed

const FONT_REGULAR_PATH := "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_FREE_ROLL_ATLAS_PATH := "res://assets/fonts/free_roll_display_v2_font.tres"
const FONT_FREE_ROLL_SUPPORTED := " ABCDEFGHIJKLMNOPQRSTUVWXYZ01235789"
const BASE_MIN_PLAYERS := 5
const BASE_MAX_PLAYERS := 10
const MISS_N_OUT_MIN_PLAYERS := 4
const MISS_N_OUT_MAX_PLAYERS := 8
const SYNC_JOIN_COUNTDOWN_SEC := 30
const ASYNC_WINDOW_COUNTDOWN_SEC := 30 * 60
const ASYNC_SLOT_FILL_EVERY_SEC := 15
const SMS_TIMEOUT_SEC := 120
const QUICK_SEARCH_TIMEOUT_SEC := 45
const DEBUG_AUTO_FILL_SEC := 5
const SHELL_SCENE_PATH := "res://scenes/Shell.tscn"
const TREE_META_VS_CPU_STYLE := "vs_cpu_style"
const TREE_META_VS_CPU_TIER := "vs_cpu_tier"
const DEV_BOT_STYLE_OPTIONS: Array[String] = ["Default", "Balancer", "Turtle", "Raider", "Greedy", "Swarm Lord"]
const DEV_BOT_TIER_OPTIONS: Array[String] = ["Default", "Easy", "Medium", "Hard"]
const SLOT_FILL_NAMES := ["Atlas", "Nova", "Rook", "Kite", "Echo", "Vex", "Mako", "Drift", "Pax"]
const DEFAULT_STAGE_MAP_IDS: Array[String] = []
const CTF_STAGE_MAP_IDS: Array[String] = [
	"MAP_nomansland__SBASE__1p",
	"MAP_nomansland__SN6__1p",
	"MAP_nomansland__GBASE__1p",
	"MAP_nomansland__GBASE__BR2__TR2__1p",
	"MAP_nomansland__GBASE__TB__1p"
]
const CTF_PLAYER_SELECT_PCT_DEFAULT: int = 35
const CTF_FLAG_MOVE_COUNT_MAX_DEFAULT: int = 1

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var quick_button: Button = $Panel/VBox/Buttons/QuickMatch
@onready var sms_button: Button = $Panel/VBox/Buttons/SmsInvite
@onready var dev_min_override_button: Button = $Panel/VBox/Buttons/DevMinOverride
@onready var dev_bot_row: HBoxContainer = $Panel/VBox/DevBotRow
@onready var dev_bot_label: Label = $Panel/VBox/DevBotRow/DevBotLabel
@onready var dev_bot_style_option: OptionButton = $Panel/VBox/DevBotRow/DevBotStyle
@onready var dev_bot_tier_option: OptionButton = $Panel/VBox/DevBotRow/DevBotTier
@onready var status_label: Label = $Panel/VBox/Status
@onready var slots_label: Label = $Panel/VBox/Slots
@onready var invite_label: Label = $Panel/VBox/Invite
@onready var join_row: HBoxContainer = $Panel/VBox/JoinRow
@onready var join_code: LineEdit = $Panel/VBox/JoinRow/JoinCode
@onready var join_button: Button = $Panel/VBox/JoinRow/JoinButton
@onready var countdown_label: Label = $Panel/VBox/Countdown
@onready var countdown_timer: Timer = $CountdownTimer
@onready var timeout_timer: Timer = $TimeoutTimer

var _mode := ""
var _map_count := 3
var _price_usd := 1
var _free_roll := false
var _countdown_left := 0
var _timeout_left := 0
var _invite_code := ""
var _assigned_players: Array[String] = []
var _countdown_mode: String = ""
var _window_sec: int = ASYNC_WINDOW_COUNTDOWN_SEC
var _sync_join_sec: int = SYNC_JOIN_COUNTDOWN_SEC
var _required_players: int = BASE_MIN_PLAYERS
var _contest_started_unix: int = 0
var _contest_deadline_unix: int = 0
var _contest_window_open: bool = false
var _local_joined: bool = false
var _dev_min_players_override: bool = false
var _dev_async_bot_style_override: String = ""
var _dev_async_bot_tier_override: String = ""
var _context_meta: Dictionary = {}
var _force_async_window: bool = false

var _local_uid: String = ""
var _local_name: String = "You"
var _session_id: String = ""
var _session_role: String = ""
var _quick_ticket_id: String = ""
var _search_elapsed_sec: int = 0
var _debug_filled: bool = false
var _font_regular: Font
var _font_semibold: Font
var _font_free_roll_atlas: Font

func configure(mode: String, map_count: int, price_usd: int, free_roll: bool, options: Dictionary = {}) -> void:
	_mode = mode
	_map_count = map_count
	_price_usd = price_usd
	_free_roll = free_roll
	_force_async_window = bool(options.get("force_async_window", false))
	_window_sec = maxi(1, int(options.get("window_sec", ASYNC_WINDOW_COUNTDOWN_SEC)))
	_sync_join_sec = maxi(1, int(options.get("sync_join_sec", SYNC_JOIN_COUNTDOWN_SEC)))
	var start_players: int = int(options.get("start_players", _min_players()))
	_required_players = mini(maxi(start_players, _min_players()), _max_players())
	_context_meta = {}
	for key in options.keys():
		match str(key):
			"window_sec", "sync_join_sec", "start_players", "force_async_window":
				continue
			_:
				_context_meta[str(key)] = options[key]
	if is_node_ready():
		_refresh_summary()
		_sync_quick_button_text()
		_sync_join_row_visibility()
		_sync_dev_button_text()
		_sync_dev_bot_controls()

func _ready() -> void:
	_load_fonts()
	_apply_static_fonts()
	back_button.pressed.connect(_on_back_pressed)
	quick_button.pressed.connect(_on_quick_match)
	sms_button.pressed.connect(_on_sms_invite)
	dev_min_override_button.pressed.connect(_on_dev_min_override_pressed)
	if dev_bot_style_option != null:
		dev_bot_style_option.item_selected.connect(_on_dev_bot_style_selected)
	if dev_bot_tier_option != null:
		dev_bot_tier_option.item_selected.connect(_on_dev_bot_tier_selected)
	join_button.pressed.connect(_on_join_pressed)
	join_code.text_submitted.connect(func(_value: String) -> void:
		_on_join_pressed()
	)
	countdown_timer.timeout.connect(_on_countdown_tick)
	timeout_timer.timeout.connect(_on_timeout_tick)
	_local_uid = ProfileManager.get_user_id() if ProfileManager != null else "local"
	_local_name = ProfileManager.get_display_name() if ProfileManager != null else "You"
	if _local_name.strip_edges().is_empty():
		_local_name = "You"
	_assigned_players = [_local_name]
	_local_joined = false
	_contest_window_open = false
	_invite_code = ""
	invite_label.visible = false
	_dev_min_players_override = false
	dev_min_override_button.visible = OS.is_debug_build()
	_setup_dev_bot_options()
	_session_id = ""
	_session_role = ""
	_quick_ticket_id = ""
	_search_elapsed_sec = 0
	_debug_filled = false
	_sync_dev_button_text()
	_sync_dev_bot_controls()
	_sync_quick_button_text()
	_sync_join_row_visibility()
	quick_button.disabled = false
	_refresh_summary()
	_status("Lobby idle")

func _refresh_summary() -> void:
	var price_text := "Free Roll" if _free_roll else "$%d Entry" % _price_usd
	var summary_text: String = "%s | %d Maps | %s" % [_mode_label(_mode), _map_count, price_text]
	if OS.is_debug_build() and _uses_async_window():
		var style_label: String = "Default" if _dev_async_bot_style_override.is_empty() else _dev_async_bot_style_override.replace("_", " ").capitalize()
		var tier_label: String = "Default" if _dev_async_bot_tier_override.is_empty() else _dev_async_bot_tier_override.capitalize()
		summary_text += " | CPU %s / %s" % [style_label, tier_label]
	summary_label.text = summary_text

func _on_quick_match() -> void:
	if _uses_async_window():
		if not _local_joined:
			_join_async_contest(false)
			_start_match()
			return
		if _contest_window_open:
			_start_match()
			return
		status_label.text = "Contest window closed."
		return
	if _handshake() == null:
		_start_sync_countdown_flow()
		return
	if not _quick_ticket_id.is_empty():
		_cancel_quick_ticket()
		_status("Quick queue cancelled")
		return
	if _session_id.is_empty():
		_begin_quick_search()
		return
	_toggle_ready_or_start()

func _on_sms_invite() -> void:
	if _uses_async_window():
		_stop_timers()
		_assigned_players = [_local_name]
		_invite_code = _generate_invite_code()
		invite_label.text = "Invite code: %s\nLink: sf://vs/%s" % [_invite_code, _invite_code]
		invite_label.visible = true
		_join_async_contest(true)
		return
	var handshake: Node = _handshake()
	if handshake == null:
		status_label.text = "Handshake service unavailable."
		return
	_cancel_quick_ticket()
	_leave_session(false)
	var result: Dictionary = handshake.call("create_invite", _local_profile(), _handshake_context()) as Dictionary
	if not bool(result.get("ok", false)):
		status_label.text = "Could not create invite (%s)." % str(result.get("err", "unknown"))
		return
	_session_id = str(result.get("session_id", ""))
	_invite_code = str(result.get("invite_code", ""))
	_session_role = "host"
	_assigned_players = [_local_name]
	_local_joined = true
	invite_label.text = "Invite code: %s\nLink: sf://vs/%s" % [_invite_code, _invite_code]
	invite_label.visible = true
	_start_handshake_poll()
	_refresh_sync_session_ui()

func _on_join_pressed() -> void:
	if _uses_async_window():
		return
	var handshake: Node = _handshake()
	if handshake == null:
		status_label.text = "Handshake service unavailable."
		return
	var code: String = join_code.text.strip_edges().to_upper()
	if code.is_empty():
		status_label.text = "Enter an invite code to join."
		return
	_cancel_quick_ticket()
	_leave_session(false)
	var result: Dictionary = handshake.call("join_invite", code, _local_profile()) as Dictionary
	if not bool(result.get("ok", false)):
		status_label.text = "Join failed (%s)." % str(result.get("err", "unknown"))
		return
	_session_id = str(result.get("session_id", ""))
	_session_role = "guest"
	_invite_code = code
	_local_joined = true
	invite_label.visible = false
	_start_handshake_poll()
	_refresh_sync_session_ui()

func _begin_quick_search() -> void:
	var handshake: Node = _handshake()
	if handshake == null:
		status_label.text = "Handshake service unavailable."
		return
	_leave_session(false)
	var result: Dictionary = handshake.call("enqueue_quick_match", _local_profile(), _handshake_context()) as Dictionary
	if not bool(result.get("ok", false)):
		status_label.text = "Quick queue failed (%s)." % str(result.get("err", "unknown"))
		return
	if bool(result.get("matched", false)):
		_session_id = str(result.get("session_id", ""))
		_session_role = "guest"
		_start_handshake_poll()
		_refresh_sync_session_ui()
		return
	_quick_ticket_id = str(result.get("ticket_id", ""))
	_search_elapsed_sec = 0
	_debug_filled = false
	_countdown_mode = "quick_search"
	_countdown_left = maxi(_sync_join_sec, QUICK_SEARCH_TIMEOUT_SEC)
	countdown_timer.start(1.0)
	invite_label.visible = false
	_status("Searching quick match")
	_sync_quick_button_text()
	_sync_join_row_visibility()
	_update_countdown_label()

func _toggle_ready_or_start() -> void:
	if _session_id.is_empty():
		return
	if _can_start_sync_match():
		_start_match()
		return
	var handshake: Node = _handshake()
	if handshake == null:
		status_label.text = "Handshake service unavailable."
		return
	var session: Dictionary = handshake.call("get_session", _session_id) as Dictionary
	if session.is_empty():
		status_label.text = "Session no longer available."
		_leave_session(false)
		return
	var local_ready: bool = _is_local_ready(session)
	var result: Dictionary = handshake.call("set_ready", _session_id, _local_uid, not local_ready) as Dictionary
	if not bool(result.get("ok", false)):
		status_label.text = "Could not update ready (%s)." % str(result.get("err", "unknown"))
		return
	_refresh_sync_session_ui()

func _can_start_sync_match() -> bool:
	if _uses_async_window():
		return false
	if _session_id.is_empty():
		return false
	var handshake: Node = _handshake()
	if handshake == null or not handshake.has_method("can_start"):
		return false
	return bool(handshake.call("can_start", _session_id, _local_uid))

func _start_handshake_poll() -> void:
	_countdown_mode = "handshake_poll"
	countdown_timer.start(1.0)
	_sync_join_row_visibility()
	_sync_quick_button_text()
	_update_countdown_label()

func _refresh_sync_session_ui() -> void:
	if _uses_async_window():
		return
	var handshake: Node = _handshake()
	if handshake == null:
		return
	if _session_id.is_empty():
		_assigned_players = [_local_name]
		_status("Lobby idle")
		_sync_quick_button_text()
		_sync_join_row_visibility()
		_update_countdown_label()
		return
	var session: Dictionary = handshake.call("get_session", _session_id) as Dictionary
	if session.is_empty():
		status_label.text = "Session ended."
		_leave_session(false)
		return
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var host_name: String = str(host.get("display_name", "Player 1"))
	var guest_name: String = str(guest.get("display_name", "")).strip_edges()
	_assigned_players = [host_name]
	if not guest_name.is_empty():
		_assigned_players.append(guest_name)
	var open_slots: int = maxi(2 - _assigned_players.size(), 0)
	slots_label.text = "Assigned: %s\nOpen slots: %d" % [", ".join(_assigned_players), open_slots]
	var status: String = str(session.get("status", "waiting"))
	if status == "waiting":
		if _session_role == "host":
			_status("Waiting for opponent")
		else:
			_status("Joined lobby")
	elif status == "matched":
		_status("Opponent connected")
	elif status == "ready":
		if _can_start_sync_match():
			_status("Both ready. Host can start")
		else:
			_status("Both ready. Waiting for host")
	elif status == "started":
		_status("Match starting")
	else:
		_status("Lobby")
	if _session_role == "host" and not _invite_code.is_empty() and guest_name.is_empty():
		invite_label.text = "Invite code: %s\nLink: sf://vs/%s" % [_invite_code, _invite_code]
		invite_label.visible = true
	else:
		invite_label.visible = false
	_sync_quick_button_text()
	_sync_join_row_visibility()
	_update_countdown_label()

func _cancel_quick_ticket() -> void:
	if _quick_ticket_id.is_empty():
		return
	var handshake: Node = _handshake()
	if handshake != null and handshake.has_method("cancel_quick_match"):
		handshake.call("cancel_quick_match", _quick_ticket_id, _local_uid)
	_quick_ticket_id = ""
	_search_elapsed_sec = 0
	_debug_filled = false
	if _countdown_mode == "quick_search":
		countdown_timer.stop()
		_countdown_mode = ""
	_update_countdown_label()
	_sync_quick_button_text()
	_sync_join_row_visibility()

func _leave_session(with_service_call: bool) -> void:
	if _session_id.is_empty():
		_session_role = ""
		return
	if with_service_call:
		var handshake: Node = _handshake()
		if handshake != null and handshake.has_method("leave_session"):
			handshake.call("leave_session", _session_id, _local_uid)
	_session_id = ""
	_session_role = ""
	_invite_code = ""
	invite_label.visible = false
	if _countdown_mode == "handshake_poll":
		countdown_timer.stop()
		_countdown_mode = ""
	_update_countdown_label()
	_sync_quick_button_text()
	_sync_join_row_visibility()

func _handshake_context() -> Dictionary:
	return {
		"mode": _mode,
		"map_count": _map_count,
		"price_usd": _price_usd,
		"free_roll": _free_roll
	}

func _local_profile() -> Dictionary:
	return {
		"uid": _local_uid,
		"display_name": _local_name
	}

func _handshake() -> Node:
	return get_node_or_null("/root/VsHandshake")

func _start_sync_countdown_flow() -> void:
	_stop_timers()
	_countdown_mode = "sync_join"
	_local_joined = true
	_assigned_players = [_local_name]
	_fill_to_required_players()
	_status("Sync lobby")
	invite_label.visible = false
	_start_countdown(_sync_join_sec)

func _status(label: String) -> void:
	var assigned: int = _assigned_players.size()
	var max_players: int = _max_players()
	if _uses_async_window():
		var start_players: int = _effective_required_players()
		var open_slots: int = maxi(max_players - assigned, 0)
		status_label.text = "%s: %d/%d assigned (window opens at %d)." % [label, assigned, max_players, start_players]
		slots_label.text = "Assigned: %s\nOpen slots: %d" % [", ".join(_assigned_players), open_slots]
		return
	var sync_open_slots: int = maxi(2 - assigned, 0)
	status_label.text = "%s: %d/2 connected." % [label, assigned]
	slots_label.text = "Assigned: %s\nOpen slots: %d" % [", ".join(_assigned_players), sync_open_slots]

func _start_countdown(seconds: int) -> void:
	_countdown_left = seconds
	_update_countdown_label()
	countdown_timer.start(1.0)

func _start_timeout(seconds: int) -> void:
	_timeout_left = seconds
	countdown_label.text = "Lobby expires in %ds" % _timeout_left
	timeout_timer.start(1.0)

func _stop_timers() -> void:
	countdown_timer.stop()
	timeout_timer.stop()
	_countdown_mode = ""
	countdown_label.text = ""

func _on_countdown_tick() -> void:
	if _countdown_mode == "quick_search":
		_countdown_left -= 1
		_search_elapsed_sec += 1
		_poll_quick_search()
		if _countdown_mode == "quick_search":
			if _countdown_left <= 0:
				_cancel_quick_ticket()
				status_label.text = "No opponent found."
				return
			_update_countdown_label()
		return
	if _countdown_mode == "handshake_poll":
		_refresh_sync_session_ui()
		return
	_countdown_left -= 1
	if _countdown_mode == "sync_join":
		_maybe_fill_open_slot(5)
		if _assigned_players.size() >= _max_players():
			countdown_timer.stop()
			countdown_label.text = ""
			_start_match()
			return
		if _countdown_left <= 0:
			countdown_timer.stop()
			countdown_label.text = ""
			_start_match()
			return
		_update_countdown_label()
		_status("Sync lobby")
		return
	if _countdown_mode == "async_window":
		_maybe_fill_open_slot(ASYNC_SLOT_FILL_EVERY_SEC)
		if _countdown_left <= 0:
			countdown_timer.stop()
			_countdown_left = 0
			_contest_window_open = false
			quick_button.disabled = true
			_update_countdown_label()
			_status("Window closed")
			return
		_update_countdown_label()
		_status("Contest open")
		return

func _poll_quick_search() -> void:
	var handshake: Node = _handshake()
	if handshake == null:
		return
	if _quick_ticket_id.is_empty():
		return
	var poll: Dictionary = handshake.call("poll_quick_match", _quick_ticket_id) as Dictionary
	if bool(poll.get("ok", false)) and bool(poll.get("matched", false)):
		_session_id = str(poll.get("session_id", ""))
		_quick_ticket_id = ""
		var session: Dictionary = poll.get("session", {}) as Dictionary
		_session_role = _role_for_local_player(session)
		_countdown_mode = "handshake_poll"
		countdown_timer.start(1.0)
		_refresh_sync_session_ui()
		return
	if OS.is_debug_build() and not _debug_filled and _search_elapsed_sec >= DEBUG_AUTO_FILL_SEC and handshake.has_method("debug_fill_quick_match"):
		_debug_filled = true
		var fill_result: Dictionary = handshake.call("debug_fill_quick_match", _quick_ticket_id, "Rival") as Dictionary
		if bool(fill_result.get("ok", false)):
			_session_id = str(fill_result.get("session_id", ""))
			_quick_ticket_id = ""
			var filled_session: Dictionary = fill_result.get("session", {}) as Dictionary
			_session_role = _role_for_local_player(filled_session)
			_countdown_mode = "handshake_poll"
			countdown_timer.start(1.0)
			_refresh_sync_session_ui()

func _role_for_local_player(session: Dictionary) -> String:
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	if str(host.get("uid", "")) == _local_uid:
		return "host"
	if str(guest.get("uid", "")) == _local_uid:
		return "guest"
	return ""

func _is_local_ready(session: Dictionary) -> bool:
	var role: String = _role_for_local_player(session)
	if role == "host":
		var host: Dictionary = session.get("host", {}) as Dictionary
		return bool(host.get("ready", false))
	if role == "guest":
		var guest: Dictionary = session.get("guest", {}) as Dictionary
		return bool(guest.get("ready", false))
	return false

func _on_timeout_tick() -> void:
	_timeout_left -= 1
	if _timeout_left <= 0:
		timeout_timer.stop()
		countdown_label.text = ""
		status_label.text = "Lobby expired."
		return
	countdown_label.text = "Lobby expires in %ds" % _timeout_left

func _start_match() -> void:
	if _uses_async_window() and not _contest_window_open:
		status_label.text = "Contest window closed."
		return
	if not _uses_async_window():
		if _session_id.is_empty() and _handshake() != null:
			status_label.text = "Create or join a PvP session first."
			return
		if _handshake() != null:
			var start_result: Dictionary = _handshake().call("start_session", _session_id, _local_uid) as Dictionary
			if not bool(start_result.get("ok", false)):
				status_label.text = "Both players must ready up; host starts the match."
				return
	var price_text := "FREE" if _free_roll else "$%d" % _price_usd
	var stage_map_paths: Array[String] = _resolve_stage_map_paths()
	var first_stage_map: String = stage_map_paths[0] if not stage_map_paths.is_empty() else ""
	status_label.text = "Match starting..."
	if SFLog.LOGGING_ENABLED:
		print("VS RUN", {
		"mode": _mode,
		"map_count": _map_count,
		"price": price_text,
		"assigned_players": _assigned_players,
		"stage_maps": stage_map_paths
	})
	var tree := get_tree()
	tree.set_meta("start_game", true)
	tree.set_meta("vs_mode", _mode)
	tree.set_meta("vs_price_usd", _price_usd)
	tree.set_meta("vs_free_roll", _free_roll)
	tree.set_meta("vs_assigned_players", _assigned_players.duplicate())
	tree.set_meta("vs_open_slots", maxi(_max_players() - _assigned_players.size(), 0))
	tree.set_meta("vs_required_players", _effective_required_players())
	tree.set_meta("vs_sync_start", not _uses_async_window())
	tree.set_meta("vs_sync_join_sec", _sync_join_sec)
	tree.set_meta("vs_window_sec", _window_sec)
	tree.set_meta("vs_window_started_unix", _contest_started_unix)
	tree.set_meta("vs_window_deadline_unix", _contest_deadline_unix)
	tree.set_meta("vs_stage_map_paths", stage_map_paths)
	tree.set_meta("vs_stage_current_index", 0)
	tree.set_meta("vs_stage_round_results", [])
	tree.set_meta("vs_handshake_session_id", _session_id)
	tree.set_meta("vs_handshake_role", _session_role)
	tree.set_meta("vs_handshake_invite_code", _invite_code)
	tree.set_meta("vs_local_profile", _local_profile())
	tree.set_meta("vs_remote_profile", _remote_profile_for_tree())
	_apply_dev_bot_overrides_to_tree(tree)
	for key in _context_meta.keys():
		tree.set_meta(key, _context_meta[key])
	if _mode == "CAPTURE_FLAG" or _mode == "HIDDEN_CAPTURE_FLAG":
		if not tree.has_meta("ctf_flag_selection_mode"):
			tree.set_meta("ctf_flag_selection_mode", "player_select" if _mode == "HIDDEN_CAPTURE_FLAG" else "weighted")
		if not tree.has_meta("ctf_player_select_pct"):
			tree.set_meta("ctf_player_select_pct", 100 if _mode == "HIDDEN_CAPTURE_FLAG" else CTF_PLAYER_SELECT_PCT_DEFAULT)
		if not tree.has_meta("ctf_randomize_flag_hive"):
			tree.set_meta("ctf_randomize_flag_hive", true)
		if not tree.has_meta("ctf_flag_move_count_max"):
			tree.set_meta("ctf_flag_move_count_max", CTF_FLAG_MOVE_COUNT_MAX_DEFAULT)
		if not tree.has_meta("ctf_flag_move_reveals"):
			tree.set_meta("ctf_flag_move_reveals", true)
	if _mode == "MISS_N_OUT":
		tree.set_meta("miss_n_out_local_player_id", _local_name)
		tree.set_meta("miss_n_out_eliminated", false)
		tree.set_meta("miss_n_out_notice", "")
	var shell: Node = get_node_or_null("/root/Shell")
	if shell != null and shell.has_method("_apply_map_then_start"):
		if first_stage_map.is_empty():
			status_label.text = "No valid stage map found."
			return
		var ops_state: Node = get_node_or_null("/root/OpsState")
		if ops_state != null and ops_state.has_method("set_team_mode_override"):
			ops_state.call("set_team_mode_override", "ffa")
		shell.call("_apply_map_then_start", first_stage_map)
		closed.emit()
		return
	if _mode == "STAGE_RACE" and first_stage_map.is_empty():
		status_label.text = "No valid stage map found."
		return
	var gamebot: Node = get_node_or_null("/root/Gamebot")
	if gamebot != null and not first_stage_map.is_empty():
		if gamebot.has_method("set_vs"):
			gamebot.call("set_vs", first_stage_map)
		else:
			gamebot.set("next_map_id", first_stage_map)
	if _mode == "STAGE_RACE":
		var ops_state: Node = get_node_or_null("/root/OpsState")
		if ops_state != null and ops_state.has_method("set_team_mode_override"):
			ops_state.call("set_team_mode_override", "ffa")
		match _mode:
			"STAGE_RACE", "TIMED_RACE", "MISS_N_OUT", "ASYNC_SINGLE_MAP_TIMED":
				tree.change_scene_to_file(SHELL_SCENE_PATH)
			_:
				tree.change_scene_to_file("res://scenes/Main.tscn")

func _remote_profile_for_tree() -> Dictionary:
	if _session_id.is_empty() or _handshake() == null:
		return {}
	var session: Dictionary = _handshake().call("get_session", _session_id) as Dictionary
	if session.is_empty():
		return {}
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var remote: Dictionary = {}
	if str(host.get("uid", "")) == _local_uid:
		remote = guest
	elif str(guest.get("uid", "")) == _local_uid:
		remote = host
	if remote.is_empty():
		return {}
	var uid: String = str(remote.get("uid", "")).strip_edges()
	if uid.is_empty():
		return {}
	return {
		"uid": uid,
		"display_name": str(remote.get("display_name", "Player 2"))
	}

func _mode_label(mode_id: String) -> String:
	match mode_id:
		"STAGE_RACE":
			return "Stage Race"
		"CAPTURE_FLAG":
			return "Capture the Flag"
		"HIDDEN_CAPTURE_FLAG":
			return "Hidden CTF"
		"TIMED_RACE", "RACE":
			return "Timed Race"
		"MISS_N_OUT":
			return "Miss-N-Out"
		_:
			return mode_id

func _generate_invite_code() -> String:
	var seed := int(Time.get_unix_time_from_system())
	return "VS%05d" % int(seed % 100000)

func _on_back_pressed() -> void:
	_stop_timers()
	_cancel_quick_ticket()
	_leave_session(true)
	closed.emit()

func _uses_async_window() -> bool:
	if _force_async_window:
		return true
	return _mode == "STAGE_RACE" or _mode == "MISS_N_OUT"

func _min_players() -> int:
	if _mode == "MISS_N_OUT":
		return MISS_N_OUT_MIN_PLAYERS
	return BASE_MIN_PLAYERS

func _max_players() -> int:
	if _uses_async_window():
		if _mode == "MISS_N_OUT":
			return MISS_N_OUT_MAX_PLAYERS
		return BASE_MAX_PLAYERS
	return 2

func _fill_to_required_players() -> void:
	var required: int = _effective_required_players()
	while _assigned_players.size() < required:
		_assigned_players.append(_next_fill_name())

func _maybe_fill_open_slot(cadence_sec: int) -> void:
	if _assigned_players.size() >= _max_players():
		return
	if cadence_sec <= 0:
		return
	if _countdown_left % cadence_sec != 0:
		return
	_assigned_players.append(_next_fill_name())

func _next_fill_name() -> String:
	var idx: int = maxi(_assigned_players.size() - 1, 0)
	if idx < SLOT_FILL_NAMES.size():
		return SLOT_FILL_NAMES[idx]
	return "Player%d" % (_assigned_players.size() + 1)

func _join_async_contest(from_invite: bool) -> void:
	_stop_timers()
	_countdown_mode = "async_window"
	_local_joined = true
	_contest_window_open = true
	quick_button.disabled = false
	quick_button.text = "Start Run"
	_assigned_players = [_local_name]
	_fill_to_required_players()
	_contest_started_unix = int(Time.get_unix_time_from_system())
	_contest_deadline_unix = _contest_started_unix + _window_sec
	if not from_invite:
		invite_label.visible = false
	_status("Contest open")
	_start_countdown(_window_sec)

func _effective_required_players() -> int:
	if _uses_async_window() and _dev_min_players_override:
		return 1
	if _uses_async_window():
		return _required_players
	return 2

func _on_dev_min_override_pressed() -> void:
	if not _uses_async_window():
		_dev_fill_sync_opponent()
		return
	_dev_min_players_override = not _dev_min_players_override
	_sync_dev_button_text()
	if _local_joined:
		_fill_to_required_players()
	_update_countdown_label()
	if not _local_joined:
		_status("Lobby idle")
	elif _uses_async_window():
		_status("Contest open")
	else:
		_status("Sync lobby")

func _dev_fill_sync_opponent() -> void:
	var handshake: Node = _handshake()
	if handshake == null:
		status_label.text = "Handshake service unavailable."
		return
	if not _quick_ticket_id.is_empty() and handshake.has_method("debug_fill_quick_match"):
		var quick_fill: Dictionary = handshake.call("debug_fill_quick_match", _quick_ticket_id, "Rival") as Dictionary
		if bool(quick_fill.get("ok", false)):
			_session_id = str(quick_fill.get("session_id", ""))
			_quick_ticket_id = ""
			var session: Dictionary = quick_fill.get("session", {}) as Dictionary
			_session_role = _role_for_local_player(session)
			_start_handshake_poll()
			_refresh_sync_session_ui()
			return
	if _session_id.is_empty():
		status_label.text = "Create an invite or quick queue first."
		return
	if handshake.has_method("debug_fill_session"):
		handshake.call("debug_fill_session", _session_id, "Rival")
	var session: Dictionary = handshake.call("get_session", _session_id) as Dictionary
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var remote_uid: String = ""
	if str(host.get("uid", "")) == _local_uid:
		remote_uid = str(guest.get("uid", ""))
	else:
		remote_uid = str(host.get("uid", ""))
	if not remote_uid.is_empty():
		handshake.call("set_ready", _session_id, remote_uid, true)
	_refresh_sync_session_ui()

func _sync_quick_button_text() -> void:
	if quick_button == null:
		return
	if _uses_async_window():
		if _local_joined and _contest_window_open:
			quick_button.text = "Start Run"
		elif _mode == "STAGE_RACE":
			quick_button.text = "Play Stage Race"
		elif _mode == "MISS_N_OUT":
			quick_button.text = "Play Miss-N-Out"
		else:
			quick_button.text = "Play Contest"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	if not _quick_ticket_id.is_empty():
		quick_button.text = "Cancel Search"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	if _session_id.is_empty():
		quick_button.text = "Quick Match"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	var handshake: Node = _handshake()
	var session: Dictionary = {}
	if handshake != null:
		session = handshake.call("get_session", _session_id) as Dictionary
	if session.is_empty():
		quick_button.text = "Quick Match"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	if _can_start_sync_match():
		quick_button.text = "Start Match"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var has_guest: bool = not str(guest.get("uid", "")).strip_edges().is_empty()
	if not has_guest:
		quick_button.text = "Waiting..."
		quick_button.disabled = true
		_apply_quick_button_font()
		return
	if _is_local_ready(session):
		quick_button.text = "Unready"
		quick_button.disabled = false
		_apply_quick_button_font()
		return
	quick_button.text = "Ready Up"
	quick_button.disabled = false
	_apply_quick_button_font()

func _sync_join_row_visibility() -> void:
	if join_row == null:
		return
	if _uses_async_window():
		join_row.visible = false
		return
	join_row.visible = _session_id.is_empty() and _quick_ticket_id.is_empty()

func _resolve_stage_map_paths() -> Array[String]:
	var resolved: Array[String] = []
	if _mode == "CAPTURE_FLAG" or _mode == "HIDDEN_CAPTURE_FLAG":
		for map_id_any in CTF_STAGE_MAP_IDS:
			var ctf_map_path: String = _resolve_map_path(str(map_id_any))
			if ctf_map_path.is_empty():
				continue
			if resolved.has(ctf_map_path):
				continue
			resolved.append(ctf_map_path)
			if resolved.size() >= _map_count:
				return resolved
	var ids: PackedStringArray = _context_map_ids()
	for map_id in ids:
		var map_path: String = _resolve_map_path(map_id)
		if map_path.is_empty():
			continue
		if not resolved.has(map_path):
			resolved.append(map_path)
		if resolved.size() >= _map_count:
			return resolved
	for map_id_any in DEFAULT_STAGE_MAP_IDS:
		var fallback_path: String = _resolve_map_path(str(map_id_any))
		if fallback_path.is_empty():
			continue
		if resolved.has(fallback_path):
			continue
		resolved.append(fallback_path)
		if resolved.size() >= _map_count:
			return resolved
	for map_path_any in MAP_LOADER.list_maps():
		var map_path: String = str(map_path_any)
		if map_path.is_empty():
			continue
		if resolved.has(map_path):
			continue
		resolved.append(map_path)
		if resolved.size() >= _map_count:
			return resolved
	return resolved

func _context_map_ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var raw: Variant = _context_meta.get("map_ids", PackedStringArray())
	if typeof(raw) == TYPE_PACKED_STRING_ARRAY:
		return raw as PackedStringArray
	if typeof(raw) == TYPE_ARRAY:
		for item in raw as Array:
			var map_id: String = str(item).strip_edges()
			if not map_id.is_empty():
				out.append(map_id)
	return out

func _resolve_map_path(map_id: String) -> String:
	var trimmed: String = map_id.strip_edges()
	if trimmed.is_empty():
		return ""
	var resolved: String = MAP_LOADER._resolve_map_path(trimmed)
	if not resolved.is_empty() and FileAccess.file_exists(resolved):
		return resolved
	return ""

func _sync_dev_button_text() -> void:
	if dev_min_override_button == null:
		return
	if _uses_async_window():
		dev_min_override_button.text = "DEV: Min=1 ON" if _dev_min_players_override else "DEV: Min=1 OFF"
		return
	dev_min_override_button.text = "DEV: Fill Opponent"

func _setup_dev_bot_options() -> void:
	if dev_bot_style_option != null and dev_bot_style_option.item_count == 0:
		for label in DEV_BOT_STYLE_OPTIONS:
			dev_bot_style_option.add_item(label)
	if dev_bot_tier_option != null and dev_bot_tier_option.item_count == 0:
		for label in DEV_BOT_TIER_OPTIONS:
			dev_bot_tier_option.add_item(label)
	if dev_bot_style_option != null:
		dev_bot_style_option.selected = 0
	if dev_bot_tier_option != null:
		dev_bot_tier_option.selected = 0
	_dev_async_bot_style_override = ""
	_dev_async_bot_tier_override = ""

func _sync_dev_bot_controls() -> void:
	if dev_bot_row == null:
		return
	var show_row: bool = OS.is_debug_build() and _uses_async_window()
	dev_bot_row.visible = show_row
	if not show_row:
		return
	if dev_bot_style_option != null:
		dev_bot_style_option.disabled = false
	if dev_bot_tier_option != null:
		dev_bot_tier_option.disabled = false

func _on_dev_bot_style_selected(index: int) -> void:
	_dev_async_bot_style_override = _dev_style_value_for_index(index)
	_refresh_summary()
	_status("Contest open" if _uses_async_window() and _local_joined else "Lobby idle")

func _on_dev_bot_tier_selected(index: int) -> void:
	_dev_async_bot_tier_override = _dev_tier_value_for_index(index)
	_refresh_summary()
	_status("Contest open" if _uses_async_window() and _local_joined else "Lobby idle")

func _dev_style_value_for_index(index: int) -> String:
	match index:
		1:
			return "balancer"
		2:
			return "turtle"
		3:
			return "raider"
		4:
			return "greedy"
		5:
			return "swarm_lord"
		_:
			return ""

func _dev_tier_value_for_index(index: int) -> String:
	match index:
		1:
			return "easy"
		2:
			return "medium"
		3:
			return "hard"
		_:
			return ""

func _apply_dev_bot_overrides_to_tree(tree: SceneTree) -> void:
	if tree == null:
		return
	if _dev_async_bot_style_override.is_empty():
		if tree.has_meta(TREE_META_VS_CPU_STYLE):
			tree.remove_meta(TREE_META_VS_CPU_STYLE)
	else:
		tree.set_meta(TREE_META_VS_CPU_STYLE, _dev_async_bot_style_override)
	if _dev_async_bot_tier_override.is_empty():
		if tree.has_meta(TREE_META_VS_CPU_TIER):
			tree.remove_meta(TREE_META_VS_CPU_TIER)
	else:
		tree.set_meta(TREE_META_VS_CPU_TIER, _dev_async_bot_tier_override)

func _update_countdown_label() -> void:
	if _countdown_mode == "quick_search":
		countdown_label.text = "Searching... %ds remaining" % maxi(_countdown_left, 0)
		return
	if _countdown_mode == "sync_join":
		countdown_label.text = "Sync start in %ds (%d/%d)" % [_countdown_left, _assigned_players.size(), _max_players()]
		return
	if _countdown_mode == "async_window":
		countdown_label.text = "Run window closes in %s (%d/%d)" % [_format_duration(_countdown_left), _assigned_players.size(), _max_players()]
		return
	if _countdown_mode == "handshake_poll":
		countdown_label.text = "Handshake live"
		return
	countdown_label.text = ""

func _format_duration(total_seconds: int) -> String:
	var clamped: int = maxi(total_seconds, 0)
	var hours: int = clamped / 3600
	var minutes: int = (clamped % 3600) / 60
	var seconds: int = clamped % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _load_fonts() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_semibold = load(FONT_SEMIBOLD_PATH)
	_font_free_roll_atlas = load(FONT_FREE_ROLL_ATLAS_PATH)

func _apply_static_fonts() -> void:
	_apply_free_roll_atlas_font(title_label, 24)
	_apply_font(back_button, _font_regular, 16)
	_apply_font(summary_label, _font_regular, 16)
	_apply_quick_button_font()
	_apply_free_roll_atlas_font(sms_button, 15)
	_apply_font(dev_min_override_button, _font_regular, 14)
	_apply_font(dev_bot_label, _font_semibold, 15)
	_apply_font(dev_bot_style_option, _font_regular, 15)
	_apply_font(dev_bot_tier_option, _font_regular, 15)
	_apply_font(status_label, _font_regular, 15)
	_apply_font(slots_label, _font_regular, 15)
	_apply_font(invite_label, _font_regular, 15)
	_apply_font(join_code, _font_regular, 15)
	_apply_font(join_button, _font_regular, 15)
	_apply_font(countdown_label, _font_semibold, 15)

func _apply_quick_button_font() -> void:
	if not _apply_free_roll_atlas_font(quick_button, 15):
		_apply_font(quick_button, _font_semibold, 15)

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
