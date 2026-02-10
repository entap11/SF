extends Control
const SFLog := preload("res://scripts/util/sf_log.gd")

signal closed

const BASE_MIN_PLAYERS := 5
const BASE_MAX_PLAYERS := 10
const MISS_N_OUT_MIN_PLAYERS := 4
const MISS_N_OUT_MAX_PLAYERS := 8
const SYNC_JOIN_COUNTDOWN_SEC := 30
const ASYNC_WINDOW_COUNTDOWN_SEC := 30 * 60
const ASYNC_SLOT_FILL_EVERY_SEC := 15
const SMS_TIMEOUT_SEC := 120
const SLOT_FILL_NAMES := ["Atlas", "Nova", "Rook", "Kite", "Echo", "Vex", "Mako", "Drift", "Pax"]

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var quick_button: Button = $Panel/VBox/Buttons/QuickMatch
@onready var sms_button: Button = $Panel/VBox/Buttons/SmsInvite
@onready var dev_min_override_button: Button = $Panel/VBox/Buttons/DevMinOverride
@onready var dev_autostart_button: Button = $Panel/VBox/Buttons/DevAutostart
@onready var status_label: Label = $Panel/VBox/Status
@onready var slots_label: Label = $Panel/VBox/Slots
@onready var invite_label: Label = $Panel/VBox/Invite
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
var _context_meta: Dictionary = {}

func configure(mode: String, map_count: int, price_usd: int, free_roll: bool, options: Dictionary = {}) -> void:
	_mode = mode
	_map_count = map_count
	_price_usd = price_usd
	_free_roll = free_roll
	_window_sec = maxi(1, int(options.get("window_sec", ASYNC_WINDOW_COUNTDOWN_SEC)))
	_sync_join_sec = maxi(1, int(options.get("sync_join_sec", SYNC_JOIN_COUNTDOWN_SEC)))
	var start_players: int = int(options.get("start_players", _min_players()))
	_required_players = mini(maxi(start_players, _min_players()), _max_players())
	_context_meta = {}
	for key in options.keys():
		match str(key):
			"window_sec", "sync_join_sec", "start_players":
				continue
			_:
				_context_meta[str(key)] = options[key]
	if is_node_ready():
		_refresh_summary()
		if _uses_async_window() and not _local_joined:
			quick_button.text = "Join Contest"
		elif not _uses_async_window():
			quick_button.text = "Quick Match"

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	quick_button.pressed.connect(_on_quick_match)
	sms_button.pressed.connect(_on_sms_invite)
	dev_min_override_button.pressed.connect(_on_dev_min_override_pressed)
	dev_autostart_button.pressed.connect(_on_dev_autostart_pressed)
	countdown_timer.timeout.connect(_on_countdown_tick)
	timeout_timer.timeout.connect(_on_timeout_tick)
	_assigned_players = ["You"]
	_local_joined = false
	_contest_window_open = false
	invite_label.visible = false
	_dev_min_players_override = false
	dev_min_override_button.visible = OS.is_debug_build()
	dev_autostart_button.visible = OS.is_debug_build()
	_sync_dev_button_text()
	if _uses_async_window():
		quick_button.text = "Join Contest"
	else:
		quick_button.text = "Quick Match"
	quick_button.disabled = false
	_refresh_summary()
	_status("Lobby idle")

func _refresh_summary() -> void:
	var price_text := "Free Roll" if _free_roll else "$%d Entry" % _price_usd
	summary_label.text = "%s | %d Maps | %s" % [_mode_label(_mode), _map_count, price_text]

func _on_quick_match() -> void:
	if _uses_async_window():
		if not _local_joined:
			_join_async_contest(false)
			return
		if _contest_window_open:
			_start_match()
			return
		status_label.text = "Contest window closed."
		return
	_start_sync_countdown_flow()

func _start_sync_countdown_flow() -> void:
	_stop_timers()
	_countdown_mode = "sync_join"
	_local_joined = true
	_assigned_players = ["You"]
	_fill_to_required_players()
	_status("Sync lobby")
	invite_label.visible = false
	_start_countdown(_sync_join_sec)

func _on_sms_invite() -> void:
	_stop_timers()
	_assigned_players = ["You"]
	_invite_code = _generate_invite_code()
	invite_label.text = "Invite code: %s\nLink: sf://vs/%s" % [_invite_code, _invite_code]
	invite_label.visible = true
	if _uses_async_window():
		_join_async_contest(true)
		return
	_status("SMS lobby")
	_start_timeout(SMS_TIMEOUT_SEC)

func _status(label: String) -> void:
	var assigned: int = _assigned_players.size()
	var max_players: int = _max_players()
	var start_players: int = _effective_required_players()
	var open_slots: int = maxi(max_players - assigned, 0)
	if _uses_async_window():
		status_label.text = "%s: %d/%d assigned (window opens at %d)." % [label, assigned, max_players, start_players]
	else:
		status_label.text = "%s: %d/%d assigned (launch at %d)." % [label, assigned, max_players, start_players]
	if slots_label != null:
		slots_label.text = "Assigned: %s\nOpen slots: %d" % [", ".join(_assigned_players), open_slots]

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
	var price_text := "FREE" if _free_roll else "$%d" % _price_usd
	status_label.text = "Match starting..."
	if SFLog.LOGGING_ENABLED:
		print("VS RUN", {
		"mode": _mode,
		"map_count": _map_count,
		"price": price_text,
		"assigned_players": _assigned_players
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
	for key in _context_meta.keys():
		tree.set_meta(key, _context_meta[key])
	if _mode == "MISS_N_OUT":
		tree.set_meta("miss_n_out_local_player_id", "You")
		tree.set_meta("miss_n_out_eliminated", false)
		tree.set_meta("miss_n_out_notice", "")
	tree.change_scene_to_file("res://scenes/Main.tscn")

func _mode_label(mode_id: String) -> String:
	match mode_id:
		"STAGE_RACE":
			return "Stage Race"
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
	closed.emit()

func _on_dev_autostart_pressed() -> void:
	dev_autostart_now()

func _uses_async_window() -> bool:
	return _mode == "STAGE_RACE" or _mode == "MISS_N_OUT"

func _min_players() -> int:
	if _mode == "MISS_N_OUT":
		return MISS_N_OUT_MIN_PLAYERS
	return BASE_MIN_PLAYERS

func _max_players() -> int:
	if _mode == "MISS_N_OUT":
		return MISS_N_OUT_MAX_PLAYERS
	return BASE_MAX_PLAYERS

func _fill_to_required_players() -> void:
	var required: int = _effective_required_players()
	while _assigned_players.size() < required:
		_assigned_players.append(_next_fill_name())

func _maybe_fill_open_slot(cadence_sec: int) -> void:
	if _assigned_players.size() >= _max_players():
		return
	if cadence_sec <= 0:
		return
	# Lightweight simulation so lobby counts move during the countdown.
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
	_assigned_players = ["You"]
	_fill_to_required_players()
	_contest_started_unix = int(Time.get_unix_time_from_system())
	_contest_deadline_unix = _contest_started_unix + _window_sec
	if not from_invite:
		invite_label.visible = false
	_status("Contest open")
	_start_countdown(_window_sec)

func dev_autostart_now() -> void:
	if not OS.is_debug_build():
		return
	if _uses_async_window() and not _local_joined:
		_join_async_contest(false)
	_start_match()

func _effective_required_players() -> int:
	if _dev_min_players_override:
		return 1
	return _required_players

func _on_dev_min_override_pressed() -> void:
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

func _sync_dev_button_text() -> void:
	if dev_min_override_button == null:
		return
	dev_min_override_button.text = "DEV: Min=1 ON" if _dev_min_players_override else "DEV: Min=1 OFF"

func _update_countdown_label() -> void:
	if _countdown_mode == "sync_join":
		countdown_label.text = "Sync start in %ds (%d/%d)" % [_countdown_left, _assigned_players.size(), _max_players()]
		return
	if _countdown_mode == "async_window":
		countdown_label.text = "Run window closes in %s (%d/%d)" % [_format_duration(_countdown_left), _assigned_players.size(), _max_players()]
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
