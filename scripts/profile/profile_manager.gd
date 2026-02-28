extends Node

signal honey_balance_changed(new_value: int, delta: int, reason: String)

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

const PROFILE_PATH: String = "user://profile.cfg"
const PROFILE_SECTION: String = "profile"
const PROFILE_KEY_GPU_VFX_ENABLED: String = "gpu_vfx_enabled"
const PROFILE_KEY_AUDIO_ENABLED: String = "audio_enabled"
const PROFILE_KEY_SFX_ENABLED: String = "sfx_enabled"
const PROFILE_KEY_HAPTICS_ENABLED: String = "haptics_enabled"
const PROFILE_KEY_FLOOR_GRAPHICS_ENABLED: String = "floor_graphics_enabled"
const PROFILE_KEY_PERFORMANCE_MODE: String = "performance_mode"
const PROFILE_KEY_ADMIN_DASHBOARD_USERNAME: String = "admin_dashboard_username"
const PROFILE_KEY_ADMIN_DASHBOARD_PASSWORD: String = "admin_dashboard_password"
const USER_ID_PREFIX: String = "u_"
const USER_ID_HEX_LEN: int = 12
const DISPLAY_NAME_PREFIX: String = "Player "
const DISPLAY_NAME_MAX_LEN: int = 20
const BUFF_LOADOUT_SIZE: int = 3
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"
const PERFORMANCE_MODE_QUALITY: String = "quality"
const PERFORMANCE_MODE_BALANCED: String = "balanced"
const PERFORMANCE_MODE_PERFORMANCE: String = "performance"
const TUTORIAL_SECTION1_STATUS_NOT_STARTED: String = "not_started"
const TUTORIAL_SECTION1_STATUS_IN_PROGRESS: String = "in_progress"
const TUTORIAL_SECTION1_STATUS_COMPLETED: String = "completed"
const TUTORIAL_SECTION1_STATUS_SKIPPED: String = "skipped"
const TUTORIAL_SECTION1_STEP_0_INTRO: String = "step_0_intro"
const TUTORIAL_SECTION1_STEP_1_ATTACK_LANE: String = "step_1_attack_lane"
const TUTORIAL_SECTION1_STEP_2_RETRACT_LANE: String = "step_2_retract_lane"
const TUTORIAL_SECTION1_STEP_3_CAPTURE_HIVE: String = "step_3_capture_hive"
const TUTORIAL_SECTION1_STEP_COMPLETED: String = "completed"
const TUTORIAL_SECTION1_STEP_SKIPPED: String = "skipped"
const TUTORIAL_SECTION2_STATUS_NOT_STARTED: String = "not_started"
const TUTORIAL_SECTION2_STATUS_IN_PROGRESS: String = "in_progress"
const TUTORIAL_SECTION2_STATUS_COMPLETED: String = "completed"
const TUTORIAL_SECTION2_STATUS_SKIPPED: String = "skipped"
const TUTORIAL_SECTION2_STEP_0_INTRO: String = "step_0_intro"
const TUTORIAL_SECTION2_STEP_1_DUAL_LANE: String = "step_1_dual_lane"
const TUTORIAL_SECTION2_STEP_2_RETRACT_LANE: String = "step_2_retract_lane"
const TUTORIAL_SECTION2_STEP_3_REDIRECT_LANE: String = "step_3_redirect_lane"
const TUTORIAL_SECTION2_STEP_COMPLETED: String = "completed"
const TUTORIAL_SECTION2_STEP_SKIPPED: String = "skipped"
const TUTORIAL_SECTION3_STATUS_NOT_STARTED: String = "not_started"
const TUTORIAL_SECTION3_STATUS_IN_PROGRESS: String = "in_progress"
const TUTORIAL_SECTION3_STATUS_COMPLETED: String = "completed"
const TUTORIAL_SECTION3_STATUS_SKIPPED: String = "skipped"
const TUTORIAL_SECTION3_STEP_0_INTRO: String = "step_0_intro"
const TUTORIAL_SECTION3_STEP_1_SWARM: String = "step_1_swarm"
const TUTORIAL_SECTION3_STEP_2_TOWER_CONTROL: String = "step_2_tower_control"
const TUTORIAL_SECTION3_STEP_3_BARRACKS_ROUTE: String = "step_3_barracks_route"
const TUTORIAL_SECTION3_STEP_COMPLETED: String = "completed"
const TUTORIAL_SECTION3_STEP_SKIPPED: String = "skipped"
const DEFAULT_HONEY_BALANCE: int = 12480
const DEFAULT_ADMIN_DASHBOARD_USERNAME: String = "Mattballou"
const DEFAULT_ADMIN_DASHBOARD_PASSWORD: String = "$warmFr0nt"
const DEFAULT_BUFF_LOADOUT_IDS: Array[String] = [
	"buff_swarm_speed_classic",
	"buff_hive_faster_production_classic",
	"buff_tower_fire_rate_classic"
]

var _has_loaded: bool = false
var _boot_trace_enter_logged: bool = false
var _created_this_run: bool = false
var _onboarding_complete: bool = false
var _controls_hint_seen: bool = false
var _tutorial_section1_status: String = TUTORIAL_SECTION1_STATUS_NOT_STARTED
var _tutorial_section1_step: String = TUTORIAL_SECTION1_STEP_0_INTRO
var _tutorial_section2_unlocked: bool = false
var _tutorial_section2_status: String = TUTORIAL_SECTION2_STATUS_NOT_STARTED
var _tutorial_section2_step: String = TUTORIAL_SECTION2_STEP_0_INTRO
var _tutorial_section3_unlocked: bool = false
var _tutorial_section3_status: String = TUTORIAL_SECTION3_STATUS_NOT_STARTED
var _tutorial_section3_step: String = TUTORIAL_SECTION3_STEP_0_INTRO
var _user_id: String = ""
var _display_name: String = ""
var _created_at_unix: int = 0
var _owned_buff_ids: Array[String] = []
var _buff_loadout_ids: Array[String] = []
var _owned_buff_ids_by_mode: Dictionary = {}
var _buff_loadout_ids_by_mode: Dictionary = {}
var _honey_balance: int = DEFAULT_HONEY_BALANCE
var _store_entitlements: Dictionary = {}
var _gpu_vfx_enabled: bool = true
var _audio_enabled: bool = true
var _sfx_enabled: bool = true
var _haptics_enabled: bool = true
var _floor_graphics_enabled: bool = true
var _performance_mode: String = PERFORMANCE_MODE_QUALITY
var _admin_dashboard_username: String = DEFAULT_ADMIN_DASHBOARD_USERNAME
var _admin_dashboard_password: String = DEFAULT_ADMIN_DASHBOARD_PASSWORD
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	ensure_loaded()

func ensure_loaded() -> void:
	if not _boot_trace_enter_logged:
		_boot_trace_enter_logged = true
		SFLog.info("PROFILE_BOOT_TRACE_ENTER", {
			"user_id": _user_id,
			"display_name": _display_name,
			"created_at_unix": _created_at_unix,
			"has_loaded": _has_loaded
		})
		SFLog.info("PROFILE_USER_DATA_DIR", {"dir": OS.get_user_data_dir()})
	if _has_loaded:
		return
	_rng.randomize()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_LOAD", {
		"path": PROFILE_PATH,
		"err": err
	})
	if err == OK:
		_user_id = str(cfg.get_value(PROFILE_SECTION, "user_id", ""))
		_display_name = str(cfg.get_value(PROFILE_SECTION, "display_name", ""))
		_created_at_unix = int(cfg.get_value(PROFILE_SECTION, "created_at_unix", 0))
		_onboarding_complete = bool(cfg.get_value(PROFILE_SECTION, "onboarding_complete", false))
		_controls_hint_seen = bool(cfg.get_value(PROFILE_SECTION, "controls_hint_seen", false))
		_tutorial_section1_status = _sanitize_tutorial_section1_status(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section1_status", TUTORIAL_SECTION1_STATUS_NOT_STARTED))
		)
		_tutorial_section1_step = _sanitize_tutorial_section1_step(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section1_step", TUTORIAL_SECTION1_STEP_0_INTRO))
		)
		_tutorial_section2_unlocked = bool(cfg.get_value(PROFILE_SECTION, "tutorial_section2_unlocked", false))
		_tutorial_section2_status = _sanitize_tutorial_section2_status(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section2_status", TUTORIAL_SECTION2_STATUS_NOT_STARTED))
		)
		_tutorial_section2_step = _sanitize_tutorial_section2_step(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section2_step", TUTORIAL_SECTION2_STEP_0_INTRO))
		)
		_tutorial_section3_unlocked = bool(cfg.get_value(PROFILE_SECTION, "tutorial_section3_unlocked", false))
		_tutorial_section3_status = _sanitize_tutorial_section3_status(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section3_status", TUTORIAL_SECTION3_STATUS_NOT_STARTED))
		)
		_tutorial_section3_step = _sanitize_tutorial_section3_step(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_section3_step", TUTORIAL_SECTION3_STEP_0_INTRO))
		)
		_gpu_vfx_enabled = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_GPU_VFX_ENABLED, true))
		_audio_enabled = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_AUDIO_ENABLED, true))
		_sfx_enabled = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_SFX_ENABLED, true))
		_haptics_enabled = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_HAPTICS_ENABLED, true))
		_floor_graphics_enabled = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_FLOOR_GRAPHICS_ENABLED, true))
		_performance_mode = _sanitize_performance_mode(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_PERFORMANCE_MODE, PERFORMANCE_MODE_QUALITY)))
		_admin_dashboard_username = _sanitize_admin_dashboard_username(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_ADMIN_DASHBOARD_USERNAME, DEFAULT_ADMIN_DASHBOARD_USERNAME)))
		_admin_dashboard_password = _sanitize_admin_dashboard_password(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_ADMIN_DASHBOARD_PASSWORD, DEFAULT_ADMIN_DASHBOARD_PASSWORD)))
		_owned_buff_ids = _sanitize_owned_ids(cfg.get_value(PROFILE_SECTION, "owned_buff_ids", []))
		_buff_loadout_ids = _sanitize_loadout_ids(cfg.get_value(PROFILE_SECTION, "buff_loadout_ids", []))
		_owned_buff_ids_by_mode = _sanitize_owned_mode_map(cfg.get_value(PROFILE_SECTION, "owned_buff_ids_by_mode", {}))
		_buff_loadout_ids_by_mode = _sanitize_loadout_mode_map(cfg.get_value(PROFILE_SECTION, "buff_loadout_ids_by_mode", {}), _owned_buff_ids_by_mode)
		_honey_balance = maxi(0, int(cfg.get_value(PROFILE_SECTION, "honey_balance", DEFAULT_HONEY_BALANCE)))
		_store_entitlements = _sanitize_store_entitlements(cfg.get_value(PROFILE_SECTION, "store_entitlements", {}))

	var created: bool = false
	if _user_id.is_empty():
		_user_id = _generate_user_id()
		_created_at_unix = int(Time.get_unix_time_from_system())
		_display_name = _default_display_name(_user_id)
		_onboarding_complete = false
		_controls_hint_seen = false
		_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_NOT_STARTED
		_tutorial_section1_step = TUTORIAL_SECTION1_STEP_0_INTRO
		_tutorial_section2_unlocked = false
		_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_NOT_STARTED
		_tutorial_section2_step = TUTORIAL_SECTION2_STEP_0_INTRO
		_tutorial_section3_unlocked = false
		_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_NOT_STARTED
		_tutorial_section3_step = TUTORIAL_SECTION3_STEP_0_INTRO
		_gpu_vfx_enabled = true
		_audio_enabled = true
		_sfx_enabled = true
		_haptics_enabled = true
		_floor_graphics_enabled = true
		_performance_mode = PERFORMANCE_MODE_QUALITY
		_admin_dashboard_username = DEFAULT_ADMIN_DASHBOARD_USERNAME
		_admin_dashboard_password = DEFAULT_ADMIN_DASHBOARD_PASSWORD
		_owned_buff_ids = _default_owned_ids()
		_buff_loadout_ids = _sanitize_loadout_ids(_owned_buff_ids)
		_honey_balance = DEFAULT_HONEY_BALANCE
		_store_entitlements = {}
		_ensure_mode_maps()
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		created = true
		_created_this_run = true
	else:
		_created_this_run = false
		var cleaned_name: String = _sanitize_display_name(_display_name, _user_id)
		var updated: bool = false
		if cleaned_name != _display_name:
			_display_name = cleaned_name
			updated = true
		if _created_at_unix <= 0:
			_created_at_unix = int(Time.get_unix_time_from_system())
			updated = true
		var clean_mode: String = _sanitize_performance_mode(_performance_mode)
		if clean_mode != _performance_mode:
			_performance_mode = clean_mode
			updated = true
		var clean_admin_username: String = _sanitize_admin_dashboard_username(_admin_dashboard_username)
		if clean_admin_username != _admin_dashboard_username:
			_admin_dashboard_username = clean_admin_username
			updated = true
		var clean_admin_password: String = _sanitize_admin_dashboard_password(_admin_dashboard_password)
		if clean_admin_password != _admin_dashboard_password:
			_admin_dashboard_password = clean_admin_password
			updated = true
		if _owned_buff_ids.is_empty():
			_owned_buff_ids = _default_owned_ids()
			updated = true
		var clean_tutorial_status: String = _sanitize_tutorial_section1_status(_tutorial_section1_status)
		if clean_tutorial_status != _tutorial_section1_status:
			_tutorial_section1_status = clean_tutorial_status
			updated = true
		var clean_tutorial_step: String = _sanitize_tutorial_section1_step(_tutorial_section1_step)
		if clean_tutorial_step != _tutorial_section1_step:
			_tutorial_section1_step = clean_tutorial_step
			updated = true
		if _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_COMPLETED and not _tutorial_section2_unlocked:
			_tutorial_section2_unlocked = true
			updated = true
		var clean_tutorial2_status: String = _sanitize_tutorial_section2_status(_tutorial_section2_status)
		if clean_tutorial2_status != _tutorial_section2_status:
			_tutorial_section2_status = clean_tutorial2_status
			updated = true
		var clean_tutorial2_step: String = _sanitize_tutorial_section2_step(_tutorial_section2_step)
		if clean_tutorial2_step != _tutorial_section2_step:
			_tutorial_section2_step = clean_tutorial2_step
			updated = true
		if _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_COMPLETED and not _tutorial_section3_unlocked:
			_tutorial_section3_unlocked = true
			updated = true
		var clean_tutorial3_status: String = _sanitize_tutorial_section3_status(_tutorial_section3_status)
		if clean_tutorial3_status != _tutorial_section3_status:
			_tutorial_section3_status = clean_tutorial3_status
			updated = true
		var clean_tutorial3_step: String = _sanitize_tutorial_section3_step(_tutorial_section3_step)
		if clean_tutorial3_step != _tutorial_section3_step:
			_tutorial_section3_step = clean_tutorial3_step
			updated = true
		if _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_COMPLETED and not _tutorial_section3_unlocked:
			_tutorial_section3_unlocked = true
			updated = true
		var cleaned_loadout: Array[String] = _sanitize_loadout_ids(_buff_loadout_ids)
		if cleaned_loadout != _buff_loadout_ids:
			_buff_loadout_ids = cleaned_loadout
			updated = true
		var cleaned_honey: int = maxi(0, _honey_balance)
		if cleaned_honey != _honey_balance:
			_honey_balance = cleaned_honey
			updated = true
		var cleaned_entitlements: Dictionary = _sanitize_store_entitlements(_store_entitlements)
		if cleaned_entitlements != _store_entitlements:
			_store_entitlements = cleaned_entitlements
			updated = true
		if _ensure_mode_maps():
			updated = true
		_ensure_loadout_owned()
		if updated:
			_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)

	_has_loaded = true
	if created:
		SFLog.info("PROFILE_CREATED", {
			"user_id": _user_id,
			"display_name": _display_name,
			"onboarding_complete": _onboarding_complete
		})
	else:
		SFLog.info("PROFILE_LOADED", {
			"user_id": _user_id,
			"display_name": _display_name,
			"onboarding_complete": _onboarding_complete
		})

func get_user_id() -> String:
	ensure_loaded()
	return _user_id

func was_created_this_run() -> bool:
	ensure_loaded()
	return _created_this_run

func is_onboarding_complete() -> bool:
	ensure_loaded()
	return _onboarding_complete

func has_seen_controls_hint() -> bool:
	ensure_loaded()
	return _controls_hint_seen

func get_tutorial_section1_status() -> String:
	ensure_loaded()
	return _tutorial_section1_status

func get_tutorial_section1_step() -> String:
	ensure_loaded()
	return _tutorial_section1_step

func is_tutorial_section2_unlocked() -> bool:
	ensure_loaded()
	return _tutorial_section2_unlocked

func get_tutorial_section2_status() -> String:
	ensure_loaded()
	return _tutorial_section2_status

func get_tutorial_section2_step() -> String:
	ensure_loaded()
	return _tutorial_section2_step

func is_tutorial_section3_unlocked() -> bool:
	ensure_loaded()
	return _tutorial_section3_unlocked

func get_tutorial_section3_status() -> String:
	ensure_loaded()
	return _tutorial_section3_status

func get_tutorial_section3_step() -> String:
	ensure_loaded()
	return _tutorial_section3_step

func get_display_name() -> String:
	ensure_loaded()
	return _display_name

func get_handle(uid: String) -> String:
	ensure_loaded()
	if uid == _user_id:
		return _display_name
	return ""

func set_display_name(name: String) -> void:
	ensure_loaded()
	var cleaned: String = _sanitize_display_name(name, _user_id)
	if cleaned == _display_name:
		return
	_display_name = cleaned
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_DISPLAY_NAME_SET", {
		"user_id": _user_id,
		"display_name": _display_name
	})

func set_user_id(raw: String) -> bool:
	ensure_loaded()
	var uid: String = _sanitize_user_id(raw)
	if not _is_valid_user_id(uid):
		SFLog.info("PROFILE_USER_ID_REJECTED", {"attempted": raw})
		return false
	if uid == _user_id:
		SFLog.info("PROFILE_USER_ID_NOOP", {"user_id": _user_id})
		return true
	var old_id: String = _user_id
	_user_id = uid
	if _display_name.strip_edges().is_empty():
		_display_name = _default_display_name(_user_id)
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_USER_ID_SET", {
		"old": old_id,
		"new": _user_id
	})
	return true

func mark_onboarding_complete() -> void:
	ensure_loaded()
	if _onboarding_complete:
		return
	_onboarding_complete = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ONBOARDING_COMPLETE", {"user_id": _user_id})

func mark_controls_hint_seen() -> void:
	ensure_loaded()
	if _controls_hint_seen:
		return
	_controls_hint_seen = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_CONTROLS_HINT_SEEN", {"user_id": _user_id})

func begin_tutorial_section1() -> void:
	ensure_loaded()
	if _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_COMPLETED or _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section1_status != TUTORIAL_SECTION1_STATUS_IN_PROGRESS:
		_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section1_step == TUTORIAL_SECTION1_STEP_COMPLETED or _tutorial_section1_step == TUTORIAL_SECTION1_STEP_SKIPPED:
		_tutorial_section1_step = TUTORIAL_SECTION1_STEP_0_INTRO
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION1_BEGIN", {"user_id": _user_id, "step": _tutorial_section1_step})

func set_tutorial_section1_step(step_name: String) -> void:
	ensure_loaded()
	var next_step: String = _sanitize_tutorial_section1_step(step_name)
	if _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_COMPLETED or _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section1_status != TUTORIAL_SECTION1_STATUS_IN_PROGRESS:
		_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section1_step != next_step:
		_tutorial_section1_step = next_step
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION1_STEP", {"user_id": _user_id, "step": _tutorial_section1_step})

func mark_tutorial_section1_completed() -> void:
	ensure_loaded()
	if _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_COMPLETED and _tutorial_section1_step == TUTORIAL_SECTION1_STEP_COMPLETED and _tutorial_section2_unlocked:
		return
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_COMPLETED
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_COMPLETED
	_tutorial_section2_unlocked = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION1_COMPLETED", {"user_id": _user_id})

func mark_tutorial_section1_skipped() -> void:
	ensure_loaded()
	if _tutorial_section1_status == TUTORIAL_SECTION1_STATUS_SKIPPED and _tutorial_section1_step == TUTORIAL_SECTION1_STEP_SKIPPED:
		return
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_SKIPPED
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_SKIPPED
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION1_SKIPPED", {"user_id": _user_id})

func begin_tutorial_section2() -> void:
	ensure_loaded()
	if _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_COMPLETED or _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section2_status != TUTORIAL_SECTION2_STATUS_IN_PROGRESS:
		_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section2_step == TUTORIAL_SECTION2_STEP_COMPLETED or _tutorial_section2_step == TUTORIAL_SECTION2_STEP_SKIPPED:
		_tutorial_section2_step = TUTORIAL_SECTION2_STEP_0_INTRO
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION2_BEGIN", {"user_id": _user_id, "step": _tutorial_section2_step})

func set_tutorial_section2_step(step_name: String) -> void:
	ensure_loaded()
	var next_step: String = _sanitize_tutorial_section2_step(step_name)
	if _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_COMPLETED or _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section2_status != TUTORIAL_SECTION2_STATUS_IN_PROGRESS:
		_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section2_step != next_step:
		_tutorial_section2_step = next_step
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION2_STEP", {"user_id": _user_id, "step": _tutorial_section2_step})

func mark_tutorial_section2_completed() -> void:
	ensure_loaded()
	if _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_COMPLETED and _tutorial_section2_step == TUTORIAL_SECTION2_STEP_COMPLETED and _tutorial_section3_unlocked:
		return
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_COMPLETED
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_COMPLETED
	_tutorial_section3_unlocked = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION2_COMPLETED", {"user_id": _user_id})

func mark_tutorial_section2_skipped() -> void:
	ensure_loaded()
	if _tutorial_section2_status == TUTORIAL_SECTION2_STATUS_SKIPPED and _tutorial_section2_step == TUTORIAL_SECTION2_STEP_SKIPPED:
		return
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_SKIPPED
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_SKIPPED
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION2_SKIPPED", {"user_id": _user_id})

func begin_tutorial_section3() -> void:
	ensure_loaded()
	if _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_COMPLETED or _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section3_status != TUTORIAL_SECTION3_STATUS_IN_PROGRESS:
		_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section3_step == TUTORIAL_SECTION3_STEP_COMPLETED or _tutorial_section3_step == TUTORIAL_SECTION3_STEP_SKIPPED:
		_tutorial_section3_step = TUTORIAL_SECTION3_STEP_0_INTRO
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION3_BEGIN", {"user_id": _user_id, "step": _tutorial_section3_step})

func set_tutorial_section3_step(step_name: String) -> void:
	ensure_loaded()
	var next_step: String = _sanitize_tutorial_section3_step(step_name)
	if _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_COMPLETED or _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_SKIPPED:
		return
	var changed: bool = false
	if _tutorial_section3_status != TUTORIAL_SECTION3_STATUS_IN_PROGRESS:
		_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_IN_PROGRESS
		changed = true
	if _tutorial_section3_step != next_step:
		_tutorial_section3_step = next_step
		changed = true
	if changed:
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_TUTORIAL_SECTION3_STEP", {"user_id": _user_id, "step": _tutorial_section3_step})

func mark_tutorial_section3_completed() -> void:
	ensure_loaded()
	if _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_COMPLETED and _tutorial_section3_step == TUTORIAL_SECTION3_STEP_COMPLETED:
		return
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_COMPLETED
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_COMPLETED
	_tutorial_section3_unlocked = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION3_COMPLETED", {"user_id": _user_id})

func mark_tutorial_section3_skipped() -> void:
	ensure_loaded()
	if _tutorial_section3_status == TUTORIAL_SECTION3_STATUS_SKIPPED and _tutorial_section3_step == TUTORIAL_SECTION3_STEP_SKIPPED:
		return
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_SKIPPED
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_SKIPPED
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION3_SKIPPED", {"user_id": _user_id})

func prepare_tutorial_section3_sandbox() -> void:
	ensure_loaded()
	_onboarding_complete = true
	_controls_hint_seen = true
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_COMPLETED
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_COMPLETED
	_tutorial_section2_unlocked = true
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_COMPLETED
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_COMPLETED
	_tutorial_section3_unlocked = true
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_IN_PROGRESS
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_0_INTRO
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION3_SANDBOX_PREPARED", {"user_id": _user_id})

func get_owned_buff_ids() -> Array[String]:
	return get_owned_buff_ids_for_mode(BUFF_MODE_VS)

func set_owned_buff_ids(ids: Array) -> void:
	set_owned_buff_ids_for_mode(BUFF_MODE_VS, ids)

func add_owned_buffs(ids: Array) -> int:
	return add_owned_buffs_for_mode(BUFF_MODE_VS, ids)

func get_owned_buff_ids_for_mode(mode: String) -> Array[String]:
	ensure_loaded()
	var mode_key: String = _normalize_buff_mode(mode)
	return _copy_string_array(_owned_buff_ids_by_mode.get(mode_key, []))

func set_owned_buff_ids_for_mode(mode: String, ids: Array) -> void:
	ensure_loaded()
	var mode_key: String = _normalize_buff_mode(mode)
	var owned_ids: Array[String] = _sanitize_owned_ids_for_mode(ids, mode_key)
	_owned_buff_ids_by_mode[mode_key] = owned_ids
	var current_loadout: Array[String] = _copy_string_array(_buff_loadout_ids_by_mode.get(mode_key, []))
	_buff_loadout_ids_by_mode[mode_key] = _sanitize_loadout_ids_for_mode(current_loadout, mode_key, owned_ids)
	_ensure_loadout_owned_for_mode(mode_key)
	_sync_legacy_from_vs_mode()
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)

func add_owned_buffs_for_mode(mode: String, ids: Array) -> int:
	ensure_loaded()
	var mode_key: String = _normalize_buff_mode(mode)
	var allow_duplicates: bool = _mode_allows_duplicates(mode_key)
	var owned_ids: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(mode_key, []))
	var added: int = 0
	for buff_id_v in ids:
		var buff_id: String = str(buff_id_v).strip_edges()
		if buff_id == "":
			continue
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if (not allow_duplicates) and owned_ids.has(buff_id):
			continue
		owned_ids.append(buff_id)
		added += 1
	if added > 0:
		_owned_buff_ids_by_mode[mode_key] = owned_ids
		_ensure_loadout_owned_for_mode(mode_key)
		_sync_legacy_from_vs_mode()
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	return added

func get_buff_loadout_ids() -> Array[String]:
	return get_buff_loadout_ids_for_mode(BUFF_MODE_VS)

func is_gpu_vfx_enabled() -> bool:
	ensure_loaded()
	return _gpu_vfx_enabled

func set_gpu_vfx_enabled(enabled: bool) -> void:
	ensure_loaded()
	if _gpu_vfx_enabled == enabled:
		return
	_gpu_vfx_enabled = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_GPU_VFX", {
		"user_id": _user_id,
		"enabled": _gpu_vfx_enabled
	})

func is_audio_enabled() -> bool:
	ensure_loaded()
	return _audio_enabled

func set_audio_enabled(enabled: bool) -> void:
	ensure_loaded()
	if _audio_enabled == enabled:
		return
	_audio_enabled = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_AUDIO_ENABLED", {"user_id": _user_id, "enabled": _audio_enabled})

func is_sfx_enabled() -> bool:
	ensure_loaded()
	return _sfx_enabled

func set_sfx_enabled(enabled: bool) -> void:
	ensure_loaded()
	if _sfx_enabled == enabled:
		return
	_sfx_enabled = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_SFX_ENABLED", {"user_id": _user_id, "enabled": _sfx_enabled})

func is_haptics_enabled() -> bool:
	ensure_loaded()
	return _haptics_enabled

func set_haptics_enabled(enabled: bool) -> void:
	ensure_loaded()
	if _haptics_enabled == enabled:
		return
	_haptics_enabled = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_HAPTICS_ENABLED", {"user_id": _user_id, "enabled": _haptics_enabled})

func is_floor_graphics_enabled() -> bool:
	ensure_loaded()
	return _floor_graphics_enabled

func set_floor_graphics_enabled(enabled: bool) -> void:
	ensure_loaded()
	if _floor_graphics_enabled == enabled:
		return
	_floor_graphics_enabled = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_FLOOR_GRAPHICS_ENABLED", {"user_id": _user_id, "enabled": _floor_graphics_enabled})

func get_performance_mode() -> String:
	ensure_loaded()
	return _performance_mode

func set_performance_mode(mode: String) -> void:
	ensure_loaded()
	var next_mode: String = _sanitize_performance_mode(mode)
	if _performance_mode == next_mode:
		return
	_performance_mode = next_mode
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_PERFORMANCE_MODE", {"user_id": _user_id, "mode": _performance_mode})

func get_admin_dashboard_username() -> String:
	ensure_loaded()
	return _admin_dashboard_username

func set_admin_dashboard_username(username: String) -> void:
	set_admin_dashboard_credentials(username, _admin_dashboard_password)

func get_admin_dashboard_password() -> String:
	ensure_loaded()
	return _admin_dashboard_password

func set_admin_dashboard_password(password: String) -> void:
	set_admin_dashboard_credentials(_admin_dashboard_username, password)

func set_admin_dashboard_credentials(username: String, password: String) -> void:
	ensure_loaded()
	var next_username: String = _sanitize_admin_dashboard_username(username)
	var next_password: String = _sanitize_admin_dashboard_password(password)
	if next_username == _admin_dashboard_username and next_password == _admin_dashboard_password:
		return
	_admin_dashboard_username = next_username
	_admin_dashboard_password = next_password
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ADMIN_DASHBOARD_CREDENTIALS_SET", {"user_id": _user_id, "username": _admin_dashboard_username})

func get_content_scale_factor() -> float:
	ensure_loaded()
	match _performance_mode:
		PERFORMANCE_MODE_PERFORMANCE:
			return 0.8
		PERFORMANCE_MODE_BALANCED:
			return 0.9
		_:
			return 1.0

func get_honey_balance() -> int:
	ensure_loaded()
	return _honey_balance

func set_honey_balance(amount: int) -> void:
	ensure_loaded()
	var next_balance: int = maxi(0, amount)
	if next_balance == _honey_balance:
		return
	var previous_balance: int = _honey_balance
	_honey_balance = next_balance
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	honey_balance_changed.emit(_honey_balance, _honey_balance - previous_balance, "set_honey_balance")

func add_honey(amount: int, reason: String = "") -> Dictionary:
	ensure_loaded()
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "honey_balance": _honey_balance}
	var previous_balance: int = _honey_balance
	_honey_balance += amount
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_HONEY_ADDED", {
		"user_id": _user_id,
		"amount": amount,
		"reason": reason,
		"honey_balance": _honey_balance
	})
	honey_balance_changed.emit(_honey_balance, _honey_balance - previous_balance, reason if reason != "" else "add_honey")
	return {"ok": true, "honey_balance": _honey_balance}

func spend_honey(amount: int, reason: String = "") -> Dictionary:
	ensure_loaded()
	if amount <= 0:
		return {"ok": false, "reason": "invalid_amount", "honey_balance": _honey_balance}
	if _honey_balance < amount:
		return {"ok": false, "reason": "insufficient_honey", "honey_balance": _honey_balance}
	var previous_balance: int = _honey_balance
	_honey_balance -= amount
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_HONEY_SPENT", {
		"user_id": _user_id,
		"amount": amount,
		"reason": reason,
		"honey_balance": _honey_balance
	})
	honey_balance_changed.emit(_honey_balance, _honey_balance - previous_balance, reason if reason != "" else "spend_honey")
	return {"ok": true, "honey_balance": _honey_balance}

func get_store_entitlements() -> Dictionary:
	ensure_loaded()
	return _store_entitlements.duplicate(true)

func has_store_entitlement(flag: String) -> bool:
	ensure_loaded()
	var clean_flag: String = flag.strip_edges()
	if clean_flag == "":
		return false
	return bool(_store_entitlements.get(clean_flag, false))

func grant_store_entitlements(flags: Array, reason: String = "") -> Dictionary:
	ensure_loaded()
	var granted: Array[String] = []
	for flag_any in flags:
		var clean_flag: String = str(flag_any).strip_edges()
		if clean_flag == "":
			continue
		if bool(_store_entitlements.get(clean_flag, false)):
			continue
		_store_entitlements[clean_flag] = true
		granted.append(clean_flag)
	if granted.is_empty():
		return {"ok": true, "granted": granted, "store_entitlements": _store_entitlements.duplicate(true)}
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ENTITLEMENTS_GRANTED", {
		"user_id": _user_id,
		"reason": reason,
		"granted": granted
	})
	return {"ok": true, "granted": granted, "store_entitlements": _store_entitlements.duplicate(true)}

func set_buff_loadout_ids(ids: Array) -> bool:
	return set_buff_loadout_ids_for_mode(BUFF_MODE_VS, ids)

func get_buff_loadout_ids_for_mode(mode: String) -> Array[String]:
	ensure_loaded()
	var mode_key: String = _normalize_buff_mode(mode)
	return _copy_string_array(_buff_loadout_ids_by_mode.get(mode_key, []))

func set_buff_loadout_ids_for_mode(mode: String, ids: Array) -> bool:
	ensure_loaded()
	var mode_key: String = _normalize_buff_mode(mode)
	var owned_ids: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(mode_key, []))
	var next_ids: Array[String] = _sanitize_loadout_ids_for_mode(ids, mode_key, owned_ids)
	var current_ids: Array[String] = _copy_string_array(_buff_loadout_ids_by_mode.get(mode_key, []))
	if next_ids == current_ids:
		return true
	_buff_loadout_ids_by_mode[mode_key] = next_ids
	_ensure_loadout_owned_for_mode(mode_key)
	_sync_legacy_from_vs_mode()
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	return true

func _save_profile(user_id: String, display_name: String, created_at: int, onboarding_complete: bool) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(PROFILE_SECTION, "user_id", user_id)
	cfg.set_value(PROFILE_SECTION, "display_name", display_name)
	if created_at > 0:
		cfg.set_value(PROFILE_SECTION, "created_at_unix", created_at)
	cfg.set_value(PROFILE_SECTION, "onboarding_complete", onboarding_complete)
	cfg.set_value(PROFILE_SECTION, "controls_hint_seen", _controls_hint_seen)
	cfg.set_value(PROFILE_SECTION, "tutorial_section1_status", _tutorial_section1_status)
	cfg.set_value(PROFILE_SECTION, "tutorial_section1_step", _tutorial_section1_step)
	cfg.set_value(PROFILE_SECTION, "tutorial_section2_unlocked", _tutorial_section2_unlocked)
	cfg.set_value(PROFILE_SECTION, "tutorial_section2_status", _tutorial_section2_status)
	cfg.set_value(PROFILE_SECTION, "tutorial_section2_step", _tutorial_section2_step)
	cfg.set_value(PROFILE_SECTION, "tutorial_section3_unlocked", _tutorial_section3_unlocked)
	cfg.set_value(PROFILE_SECTION, "tutorial_section3_status", _tutorial_section3_status)
	cfg.set_value(PROFILE_SECTION, "tutorial_section3_step", _tutorial_section3_step)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_GPU_VFX_ENABLED, _gpu_vfx_enabled)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_AUDIO_ENABLED, _audio_enabled)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_SFX_ENABLED, _sfx_enabled)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_HAPTICS_ENABLED, _haptics_enabled)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_FLOOR_GRAPHICS_ENABLED, _floor_graphics_enabled)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_PERFORMANCE_MODE, _performance_mode)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_ADMIN_DASHBOARD_USERNAME, _admin_dashboard_username)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_ADMIN_DASHBOARD_PASSWORD, _admin_dashboard_password)
	cfg.set_value(PROFILE_SECTION, "owned_buff_ids", _owned_buff_ids)
	cfg.set_value(PROFILE_SECTION, "buff_loadout_ids", _buff_loadout_ids)
	cfg.set_value(PROFILE_SECTION, "owned_buff_ids_by_mode", _owned_buff_ids_by_mode)
	cfg.set_value(PROFILE_SECTION, "buff_loadout_ids_by_mode", _buff_loadout_ids_by_mode)
	cfg.set_value(PROFILE_SECTION, "honey_balance", _honey_balance)
	cfg.set_value(PROFILE_SECTION, "store_entitlements", _store_entitlements)
	var err: int = cfg.save(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_SAVE", {
		"path": PROFILE_PATH,
		"err": err
	})
	if err == OK:
		SFLog.info("PROFILE_SAVED", {
			"path": PROFILE_PATH,
			"user_id": user_id,
			"display_name": display_name
		})

func _generate_user_id() -> String:
	var hex: String = ""
	for i in range(6):
		var value: int = int(_rng.randi_range(0, 255))
		hex += "%02x" % value
	return USER_ID_PREFIX + hex

func _default_display_name(user_id: String) -> String:
	var suffix: String = user_id
	if user_id.begins_with(USER_ID_PREFIX):
		suffix = user_id.substr(USER_ID_PREFIX.length(), user_id.length() - USER_ID_PREFIX.length())
	if suffix.length() >= 4:
		suffix = suffix.substr(suffix.length() - 4, 4)
	else:
		suffix = suffix.pad_zeros(4)
	return DISPLAY_NAME_PREFIX + suffix.to_upper()

func _sanitize_display_name(name: String, user_id: String) -> String:
	var cleaned: String = name.strip_edges()
	if cleaned.length() > DISPLAY_NAME_MAX_LEN:
		cleaned = cleaned.substr(0, DISPLAY_NAME_MAX_LEN)
	if cleaned.is_empty():
		cleaned = _default_display_name(user_id)
	return cleaned

func _sanitize_performance_mode(mode: String) -> String:
	var cleaned: String = mode.strip_edges().to_lower()
	if cleaned != PERFORMANCE_MODE_QUALITY and cleaned != PERFORMANCE_MODE_BALANCED and cleaned != PERFORMANCE_MODE_PERFORMANCE:
		return PERFORMANCE_MODE_QUALITY
	return cleaned

func _sanitize_tutorial_section1_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION1_STATUS_IN_PROGRESS:
		return TUTORIAL_SECTION1_STATUS_IN_PROGRESS
	if cleaned == TUTORIAL_SECTION1_STATUS_COMPLETED:
		return TUTORIAL_SECTION1_STATUS_COMPLETED
	if cleaned == TUTORIAL_SECTION1_STATUS_SKIPPED:
		return TUTORIAL_SECTION1_STATUS_SKIPPED
	return TUTORIAL_SECTION1_STATUS_NOT_STARTED

func _sanitize_tutorial_section1_step(step_name: String) -> String:
	var cleaned: String = step_name.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION1_STEP_1_ATTACK_LANE:
		return TUTORIAL_SECTION1_STEP_1_ATTACK_LANE
	if cleaned == TUTORIAL_SECTION1_STEP_2_RETRACT_LANE:
		return TUTORIAL_SECTION1_STEP_2_RETRACT_LANE
	if cleaned == TUTORIAL_SECTION1_STEP_3_CAPTURE_HIVE:
		return TUTORIAL_SECTION1_STEP_3_CAPTURE_HIVE
	if cleaned == TUTORIAL_SECTION1_STEP_COMPLETED:
		return TUTORIAL_SECTION1_STEP_COMPLETED
	if cleaned == TUTORIAL_SECTION1_STEP_SKIPPED:
		return TUTORIAL_SECTION1_STEP_SKIPPED
	return TUTORIAL_SECTION1_STEP_0_INTRO

func _sanitize_tutorial_section2_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION2_STATUS_IN_PROGRESS:
		return TUTORIAL_SECTION2_STATUS_IN_PROGRESS
	if cleaned == TUTORIAL_SECTION2_STATUS_COMPLETED:
		return TUTORIAL_SECTION2_STATUS_COMPLETED
	if cleaned == TUTORIAL_SECTION2_STATUS_SKIPPED:
		return TUTORIAL_SECTION2_STATUS_SKIPPED
	return TUTORIAL_SECTION2_STATUS_NOT_STARTED

func _sanitize_tutorial_section2_step(step_name: String) -> String:
	var cleaned: String = step_name.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION2_STEP_1_DUAL_LANE:
		return TUTORIAL_SECTION2_STEP_1_DUAL_LANE
	if cleaned == TUTORIAL_SECTION2_STEP_2_RETRACT_LANE:
		return TUTORIAL_SECTION2_STEP_2_RETRACT_LANE
	if cleaned == TUTORIAL_SECTION2_STEP_3_REDIRECT_LANE:
		return TUTORIAL_SECTION2_STEP_3_REDIRECT_LANE
	if cleaned == TUTORIAL_SECTION2_STEP_COMPLETED:
		return TUTORIAL_SECTION2_STEP_COMPLETED
	if cleaned == TUTORIAL_SECTION2_STEP_SKIPPED:
		return TUTORIAL_SECTION2_STEP_SKIPPED
	return TUTORIAL_SECTION2_STEP_0_INTRO

func _sanitize_tutorial_section3_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION3_STATUS_IN_PROGRESS:
		return TUTORIAL_SECTION3_STATUS_IN_PROGRESS
	if cleaned == TUTORIAL_SECTION3_STATUS_COMPLETED:
		return TUTORIAL_SECTION3_STATUS_COMPLETED
	if cleaned == TUTORIAL_SECTION3_STATUS_SKIPPED:
		return TUTORIAL_SECTION3_STATUS_SKIPPED
	return TUTORIAL_SECTION3_STATUS_NOT_STARTED

func _sanitize_tutorial_section3_step(step_name: String) -> String:
	var cleaned: String = step_name.strip_edges().to_lower()
	if cleaned == TUTORIAL_SECTION3_STEP_1_SWARM:
		return TUTORIAL_SECTION3_STEP_1_SWARM
	if cleaned == TUTORIAL_SECTION3_STEP_2_TOWER_CONTROL:
		return TUTORIAL_SECTION3_STEP_2_TOWER_CONTROL
	if cleaned == TUTORIAL_SECTION3_STEP_3_BARRACKS_ROUTE:
		return TUTORIAL_SECTION3_STEP_3_BARRACKS_ROUTE
	if cleaned == TUTORIAL_SECTION3_STEP_COMPLETED:
		return TUTORIAL_SECTION3_STEP_COMPLETED
	if cleaned == TUTORIAL_SECTION3_STEP_SKIPPED:
		return TUTORIAL_SECTION3_STEP_SKIPPED
	return TUTORIAL_SECTION3_STEP_0_INTRO

func _sanitize_admin_dashboard_username(username: String) -> String:
	return username.strip_edges()

func _sanitize_admin_dashboard_password(password: String) -> String:
	return password

func _sanitize_user_id(raw: String) -> String:
	var cleaned: String = raw.strip_edges().to_lower()
	return cleaned

func _is_valid_user_id(uid: String) -> bool:
	if not uid.begins_with(USER_ID_PREFIX):
		return false
	var suffix: String = uid.substr(USER_ID_PREFIX.length(), uid.length() - USER_ID_PREFIX.length())
	if suffix.length() != USER_ID_HEX_LEN:
		return false
	for i in range(suffix.length()):
		var ch: String = suffix.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		var is_upper_hex: bool = code >= 65 and code <= 70
		if not (is_digit or is_lower_hex or is_upper_hex):
			return false
	return true

func _default_owned_ids() -> Array[String]:
	var out: Array[String] = []
	for buff_id in DEFAULT_BUFF_LOADOUT_IDS:
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if out.has(buff_id):
			continue
		out.append(buff_id)
	return out

func _sanitize_owned_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return _default_owned_ids()
	for buff_id_v in raw as Array:
		var buff_id: String = str(buff_id_v).strip_edges()
		if buff_id == "":
			continue
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if out.has(buff_id):
			continue
		out.append(buff_id)
	if out.is_empty():
		out = _default_owned_ids()
	return out

func _sanitize_loadout_ids(raw: Variant) -> Array[String]:
	var base: Array[String] = _default_owned_ids()
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for buff_id_v in raw as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if out.has(buff_id):
				continue
			out.append(buff_id)
	if out.size() > BUFF_LOADOUT_SIZE:
		out = out.slice(0, BUFF_LOADOUT_SIZE)
	var fill_i: int = 0
	while out.size() < BUFF_LOADOUT_SIZE and fill_i < base.size():
		var fallback_id: String = base[fill_i]
		if not out.has(fallback_id):
			out.append(fallback_id)
		fill_i += 1
	while out.size() < BUFF_LOADOUT_SIZE:
		for fallback_id in DEFAULT_BUFF_LOADOUT_IDS:
			if BuffCatalog.get_buff(fallback_id).is_empty():
				continue
			if out.has(fallback_id):
				continue
			out.append(fallback_id)
			break
		if out.size() >= BUFF_LOADOUT_SIZE:
			break
		break
	return out

func _sanitize_store_entitlements(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var in_map: Dictionary = raw as Dictionary
	for key_any in in_map.keys():
		var key: String = str(key_any).strip_edges()
		if key == "":
			continue
		if not bool(in_map.get(key_any, false)):
			continue
		out[key] = true
	return out

func _normalize_buff_mode(mode: String) -> String:
	if mode.strip_edges().to_lower() == BUFF_MODE_ASYNC:
		return BUFF_MODE_ASYNC
	return BUFF_MODE_VS

func _mode_allows_duplicates(mode: String) -> bool:
	return _normalize_buff_mode(mode) == BUFF_MODE_ASYNC

func _copy_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value_any in raw as Array:
		out.append(str(value_any).strip_edges())
	return out

func _sanitize_owned_ids_for_mode(raw: Variant, mode: String) -> Array[String]:
	var allow_duplicates: bool = _mode_allows_duplicates(mode)
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for buff_id_v in raw as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if (not allow_duplicates) and out.has(buff_id):
				continue
			out.append(buff_id)
	if out.is_empty():
		out = _default_owned_ids()
	return out

func _sanitize_loadout_ids_for_mode(raw: Variant, mode: String, owned_ids: Array[String]) -> Array[String]:
	var allow_duplicates: bool = _mode_allows_duplicates(mode)
	var base: Array[String] = owned_ids.duplicate()
	if base.is_empty():
		base = _default_owned_ids()
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for buff_id_v in raw as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if (not allow_duplicates) and out.has(buff_id):
				continue
			out.append(buff_id)
	if out.size() > BUFF_LOADOUT_SIZE:
		out = out.slice(0, BUFF_LOADOUT_SIZE)
	var fill_i: int = 0
	while out.size() < BUFF_LOADOUT_SIZE and fill_i < base.size():
		var fallback_id: String = base[fill_i]
		if allow_duplicates or (not out.has(fallback_id)):
			out.append(fallback_id)
		fill_i += 1
	while out.size() < BUFF_LOADOUT_SIZE:
		for fallback_id in DEFAULT_BUFF_LOADOUT_IDS:
			if BuffCatalog.get_buff(fallback_id).is_empty():
				continue
			if (not allow_duplicates) and out.has(fallback_id):
				continue
			out.append(fallback_id)
			break
		if out.size() >= BUFF_LOADOUT_SIZE:
			break
		break
	return out

func _sanitize_owned_mode_map(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) == TYPE_DICTIONARY:
		var map_any: Dictionary = raw as Dictionary
		if map_any.has(BUFF_MODE_VS):
			out[BUFF_MODE_VS] = _sanitize_owned_ids_for_mode(map_any.get(BUFF_MODE_VS, []), BUFF_MODE_VS)
		if map_any.has(BUFF_MODE_ASYNC):
			out[BUFF_MODE_ASYNC] = _sanitize_owned_ids_for_mode(map_any.get(BUFF_MODE_ASYNC, []), BUFF_MODE_ASYNC)
	return out

func _sanitize_loadout_mode_map(raw: Variant, owned_by_mode: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var map_any: Dictionary = raw as Dictionary
	for mode in [BUFF_MODE_VS, BUFF_MODE_ASYNC]:
		if not map_any.has(mode):
			continue
		var owned_any: Variant = owned_by_mode.get(mode, _default_owned_ids())
		var owned_ids: Array[String] = _copy_string_array(owned_any)
		out[mode] = _sanitize_loadout_ids_for_mode(map_any.get(mode, []), mode, owned_ids)
	return out

func _count_buff_in_list(entries: Array[String], buff_id: String) -> int:
	if buff_id == "":
		return 0
	var out: int = 0
	for entry_id in entries:
		if entry_id == buff_id:
			out += 1
	return out

func _ensure_mode_maps() -> bool:
	var changed: bool = false
	var legacy_owned_vs: Array[String] = _sanitize_owned_ids(_owned_buff_ids)
	var legacy_loadout_vs: Array[String] = _sanitize_loadout_ids(_buff_loadout_ids)
	for mode in [BUFF_MODE_VS, BUFF_MODE_ASYNC]:
		if not _owned_buff_ids_by_mode.has(mode):
			if mode == BUFF_MODE_VS:
				_owned_buff_ids_by_mode[mode] = legacy_owned_vs.duplicate()
			else:
				_owned_buff_ids_by_mode[mode] = legacy_owned_vs.duplicate()
			changed = true
	var vs_owned_any: Variant = _owned_buff_ids_by_mode.get(BUFF_MODE_VS, legacy_owned_vs)
	var vs_owned_ids: Array[String] = _sanitize_owned_ids_for_mode(vs_owned_any, BUFF_MODE_VS)
	if vs_owned_ids != _copy_string_array(vs_owned_any):
		changed = true
	_owned_buff_ids_by_mode[BUFF_MODE_VS] = vs_owned_ids
	var async_owned_any: Variant = _owned_buff_ids_by_mode.get(BUFF_MODE_ASYNC, vs_owned_ids)
	var async_owned_ids: Array[String] = _sanitize_owned_ids_for_mode(async_owned_any, BUFF_MODE_ASYNC)
	if async_owned_ids != _copy_string_array(async_owned_any):
		changed = true
	_owned_buff_ids_by_mode[BUFF_MODE_ASYNC] = async_owned_ids

	for mode in [BUFF_MODE_VS, BUFF_MODE_ASYNC]:
		if not _buff_loadout_ids_by_mode.has(mode):
			if mode == BUFF_MODE_VS:
				_buff_loadout_ids_by_mode[mode] = legacy_loadout_vs.duplicate()
			else:
				_buff_loadout_ids_by_mode[mode] = legacy_loadout_vs.duplicate()
			changed = true
	var vs_loadout_any: Variant = _buff_loadout_ids_by_mode.get(BUFF_MODE_VS, legacy_loadout_vs)
	var vs_loadout_ids: Array[String] = _sanitize_loadout_ids_for_mode(vs_loadout_any, BUFF_MODE_VS, vs_owned_ids)
	if vs_loadout_ids != _copy_string_array(vs_loadout_any):
		changed = true
	_buff_loadout_ids_by_mode[BUFF_MODE_VS] = vs_loadout_ids
	var async_loadout_any: Variant = _buff_loadout_ids_by_mode.get(BUFF_MODE_ASYNC, vs_loadout_ids)
	var async_loadout_ids: Array[String] = _sanitize_loadout_ids_for_mode(async_loadout_any, BUFF_MODE_ASYNC, async_owned_ids)
	if async_loadout_ids != _copy_string_array(async_loadout_any):
		changed = true
	_buff_loadout_ids_by_mode[BUFF_MODE_ASYNC] = async_loadout_ids

	var before_vs_owned: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(BUFF_MODE_VS, []))
	var before_async_owned: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(BUFF_MODE_ASYNC, []))
	_ensure_loadout_owned_for_mode(BUFF_MODE_VS)
	_ensure_loadout_owned_for_mode(BUFF_MODE_ASYNC)
	if before_vs_owned != _copy_string_array(_owned_buff_ids_by_mode.get(BUFF_MODE_VS, [])):
		changed = true
	if before_async_owned != _copy_string_array(_owned_buff_ids_by_mode.get(BUFF_MODE_ASYNC, [])):
		changed = true

	var old_legacy_owned: Array[String] = _owned_buff_ids.duplicate()
	var old_legacy_loadout: Array[String] = _buff_loadout_ids.duplicate()
	_sync_legacy_from_vs_mode()
	if old_legacy_owned != _owned_buff_ids:
		changed = true
	if old_legacy_loadout != _buff_loadout_ids:
		changed = true
	return changed

func _ensure_loadout_owned_for_mode(mode: String) -> void:
	var mode_key: String = _normalize_buff_mode(mode)
	var owned_ids: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(mode_key, []))
	var loadout_ids: Array[String] = _copy_string_array(_buff_loadout_ids_by_mode.get(mode_key, []))
	if _mode_allows_duplicates(mode_key):
		for buff_id in loadout_ids:
			if buff_id == "":
				continue
			var required: int = _count_buff_in_list(loadout_ids, buff_id)
			var available: int = _count_buff_in_list(owned_ids, buff_id)
			while available < required:
				owned_ids.append(buff_id)
				available += 1
	else:
		for buff_id in loadout_ids:
			if buff_id == "":
				continue
			if owned_ids.has(buff_id):
				continue
			owned_ids.append(buff_id)
	_owned_buff_ids_by_mode[mode_key] = owned_ids

func _sync_legacy_from_vs_mode() -> void:
	var vs_owned: Array[String] = _copy_string_array(_owned_buff_ids_by_mode.get(BUFF_MODE_VS, _default_owned_ids()))
	var vs_loadout: Array[String] = _copy_string_array(_buff_loadout_ids_by_mode.get(BUFF_MODE_VS, _sanitize_loadout_ids(vs_owned)))
	_owned_buff_ids = _sanitize_owned_ids_for_mode(vs_owned, BUFF_MODE_VS)
	_buff_loadout_ids = _sanitize_loadout_ids_for_mode(vs_loadout, BUFF_MODE_VS, _owned_buff_ids)

func _ensure_loadout_owned() -> void:
	_ensure_loadout_owned_for_mode(BUFF_MODE_VS)
	_sync_legacy_from_vs_mode()

# Legacy compatibility (single-profile semantics).
func get_profiles() -> Array[Dictionary]:
	ensure_loaded()
	var profile: Dictionary = {
		"profile_id": _user_id,
		"handle": _display_name,
		"created_at_unix": _created_at_unix,
		"last_used_at_unix": _created_at_unix
	}
	return [profile]

func get_active_profile_id() -> String:
	return get_user_id()

func get_active_profile() -> Dictionary:
	var profiles: Array[Dictionary] = get_profiles()
	if profiles.is_empty():
		return {}
	return profiles[0]

func get_active_handle() -> String:
	return get_display_name()

func set_active_profile(profile_id: String) -> void:
	ensure_loaded()
	if profile_id != _user_id:
		return

func create_profile() -> String:
	return get_user_id()

func rename_profile(profile_id: String, new_handle: String) -> bool:
	ensure_loaded()
	if profile_id != _user_id:
		return false
	set_display_name(new_handle)
	return true

func delete_profile(_profile_id: String) -> bool:
	return false
