extends Control
const SFLog := preload("res://scripts/util/sf_log.gd")

signal closed

const MIN_PLAYERS := 5
const MAX_PLAYERS := 8
const COUNTDOWN_SEC := 60
const SMS_TIMEOUT_SEC := 120

@onready var title_label: Label = $Panel/VBox/Header/Title
@onready var back_button: Button = $Panel/VBox/Header/Back
@onready var summary_label: Label = $Panel/VBox/Summary
@onready var quick_button: Button = $Panel/VBox/Buttons/QuickMatch
@onready var sms_button: Button = $Panel/VBox/Buttons/SmsInvite
@onready var status_label: Label = $Panel/VBox/Status
@onready var invite_label: Label = $Panel/VBox/Invite
@onready var countdown_label: Label = $Panel/VBox/Countdown
@onready var countdown_timer: Timer = $CountdownTimer
@onready var timeout_timer: Timer = $TimeoutTimer

var _mode := ""
var _map_count := 3
var _price_usd := 1
var _free_roll := false
var _player_count := 1
var _countdown_left := 0
var _timeout_left := 0
var _invite_code := ""

func configure(mode: String, map_count: int, price_usd: int, free_roll: bool) -> void:
	_mode = mode
	_map_count = map_count
	_price_usd = price_usd
	_free_roll = free_roll

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	quick_button.pressed.connect(_on_quick_match)
	sms_button.pressed.connect(_on_sms_invite)
	countdown_timer.timeout.connect(_on_countdown_tick)
	timeout_timer.timeout.connect(_on_timeout_tick)
	invite_label.visible = false
	_refresh_summary()

func _refresh_summary() -> void:
	var price_text := "Free Roll" if _free_roll else "$%d Entry" % _price_usd
	summary_label.text = "%s | %d Maps | %s" % [_mode_label(_mode), _map_count, price_text]

func _on_quick_match() -> void:
	_stop_timers()
	_player_count = MIN_PLAYERS
	_status("Quick Match lobby", _player_count)
	invite_label.visible = false
	_start_countdown(COUNTDOWN_SEC)

func _on_sms_invite() -> void:
	_stop_timers()
	_player_count = 1
	_invite_code = _generate_invite_code()
	invite_label.text = "Invite code: %s\nLink: sf://vs/%s" % [_invite_code, _invite_code]
	invite_label.visible = true
	_status("SMS lobby", _player_count)
	_start_timeout(SMS_TIMEOUT_SEC)

func _status(label: String, count: int) -> void:
	status_label.text = "%s: %d/%d players" % [label, count, MAX_PLAYERS]

func _start_countdown(seconds: int) -> void:
	_countdown_left = seconds
	countdown_label.text = "Match starts in %ds" % _countdown_left
	countdown_timer.start(1.0)

func _start_timeout(seconds: int) -> void:
	_timeout_left = seconds
	countdown_label.text = "Lobby expires in %ds" % _timeout_left
	timeout_timer.start(1.0)

func _stop_timers() -> void:
	countdown_timer.stop()
	timeout_timer.stop()
	countdown_label.text = ""

func _on_countdown_tick() -> void:
	_countdown_left -= 1
	if _countdown_left <= 0:
		countdown_timer.stop()
		countdown_label.text = ""
		_start_match()
		return
	countdown_label.text = "Match starts in %ds" % _countdown_left

func _on_timeout_tick() -> void:
	_timeout_left -= 1
	if _timeout_left <= 0:
		timeout_timer.stop()
		countdown_label.text = ""
		status_label.text = "Lobby expired."
		return
	countdown_label.text = "Lobby expires in %ds" % _timeout_left

func _start_match() -> void:
	var price_text := "FREE" if _free_roll else "$%d" % _price_usd
	status_label.text = "Match starting..."
	if SFLog.LOGGING_ENABLED:
		print("VS RUN", {
		"mode": _mode,
		"map_count": _map_count,
		"price": price_text
	})
	var tree := get_tree()
	tree.set_meta("start_game", true)
	tree.change_scene_to_file("res://scenes/Main.tscn")

func _mode_label(mode_id: String) -> String:
	match mode_id:
		"STAGE_RACE":
			return "Stage Race"
		"RACE":
			return "Race"
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
