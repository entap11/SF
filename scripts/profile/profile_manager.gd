extends Node

signal honey_balance_changed(new_value: int, delta: int, reason: String)
signal achievement_granted(achievement_id: String)
signal powerbar_theme_changed(theme_id: String)
signal garage_selection_changed(category_id: String, item_id: String)
signal social_destination_changed(destination_id: String, enabled: bool)

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const EconomyEpochScript = preload("res://scripts/state/economy_epoch.gd")

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
const PROFILE_KEY_UNLOCKED_ACHIEVEMENTS: String = "unlocked_achievements"
const PROFILE_KEY_POWERBAR_THEME: String = "cosmetic_powerbar_theme"
const PROFILE_KEY_GARAGE_SELECTIONS: String = "garage_selections"
const PROFILE_KEY_SOCIAL_DESTINATIONS: String = "social_destinations"
const PROFILE_KEY_FORCED_RENAME_REQUIRED: String = "forced_rename_required"
const PROFILE_KEY_FORCED_RENAME_REASON: String = "forced_rename_reason"
const PROFILE_KEY_FORCED_RENAME_ACTION_ID: String = "forced_rename_action_id"
const PROFILE_KEY_TUTORIAL_CONTROLS_FOLLOWUP_BONUS_CLAIMED: String = "tutorial_controls_followup_bonus_claimed"
const PROFILE_KEY_ECONOMY_EPOCH: String = "economy_epoch"
const USER_ID_PREFIX: String = "u_"
const USER_ID_HEX_LEN: int = 12
const DISPLAY_NAME_PREFIX: String = "Player_"
const DISPLAY_NAME_MIN_LEN: int = 3
const DISPLAY_NAME_MAX_LEN: int = 16
const HANDLE_RENAME_COOLDOWN_SEC: int = 365 * 24 * 60 * 60
const HANDLE_EXTRA_CHANGE_HONEY_COST: int = 25
const HANDLE_POLICY_VERSION: int = 1
const BUFF_LOADOUT_SIZE: int = 3
const BUFF_MODE_VS: String = "vs"
const BUFF_MODE_ASYNC: String = "async"
const PERFORMANCE_MODE_QUALITY: String = "quality"
const PERFORMANCE_MODE_BALANCED: String = "balanced"
const PERFORMANCE_MODE_PERFORMANCE: String = "performance"
const MOBILE_CONTENT_SCALE_MULTIPLIER: float = 1.10
const TUTORIAL_SECTION1_STATUS_NOT_STARTED: String = "not_started"
const TUTORIAL_SECTION1_STATUS_IN_PROGRESS: String = "in_progress"
const TUTORIAL_SECTION1_STATUS_COMPLETED: String = "completed"
const TUTORIAL_SECTION1_STATUS_SKIPPED: String = "skipped"
const TUTORIAL_SECTION1_STEP_0_INTRO: String = "step_0_intro"
const TUTORIAL_SECTION1_STEP_1_ATTACK_LANE: String = "step_1_attack_lane"
const TUTORIAL_SECTION1_STEP_2_RETRACT_LANE: String = "step_2_retract_lane"
const TUTORIAL_SECTION1_STEP_3_CAPTURE_HIVE: String = "step_3_capture_hive"
const TUTORIAL_SECTION1_STEP_4_BUFF: String = "step_4_buff"
const TUTORIAL_SECTION1_STEP_4_SWARM_FINISH: String = "step_4_swarm_finish"
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
const TUTORIAL_CONTROLS_VERSION: int = 1
const TUTORIAL_CONTROLS_STATUS_NOT_STARTED: String = "not_started"
const TUTORIAL_CONTROLS_STATUS_IN_PROGRESS: String = "in_progress"
const TUTORIAL_CONTROLS_STATUS_COMPLETED: String = "completed"
const TUTORIAL_CONTROLS_STATUS_SKIPPED: String = "skipped"
const DEFAULT_HONEY_BALANCE: int = EconomyEpochScript.STARTING_HONEY
const DEFAULT_ADMIN_DASHBOARD_USERNAME: String = "Mattballou"
const DEFAULT_ADMIN_DASHBOARD_PASSWORD: String = "$warmFr0nt"
const POWERBAR_THEME_BASE: String = "base"
const POWERBAR_THEME_UPGRADED: String = "upgraded"
const POWERBAR_THEME_UPGRADED_DYNAMIC: String = "upgraded_dynamic"
const POWERBAR_THEME_UPGRADED_BOIL: String = "upgraded_boil"
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
var _tutorial_controls_status: String = TUTORIAL_CONTROLS_STATUS_NOT_STARTED
var _tutorial_controls_version: int = TUTORIAL_CONTROLS_VERSION
var _tutorial_controls_followup_bonus_claimed: bool = false
var _id: String = ""
var _entap_id: String = ""
var _call_sign: String = ""
var _legacy_user_id: String = ""
var _user_id: String = ""
var _display_name: String = ""
var _created_at_unix: int = 0
var _handle_chosen: bool = false
var _handle_changed_at_unix: int = 0
var _next_handle_change_unix: int = 0
var _handle_change_count: int = 0
var _handle_locked: bool = false
var _handle_history: Array = []
var _forced_rename_required: bool = false
var _forced_rename_reason: String = ""
var _forced_rename_action_id: String = ""
var _owned_buff_ids: Array[String] = []
var _buff_loadout_ids: Array[String] = []
var _owned_buff_ids_by_mode: Dictionary = {}
var _buff_loadout_ids_by_mode: Dictionary = {}
var _honey_balance: int = DEFAULT_HONEY_BALANCE
var _economy_epoch: String = EconomyEpochScript.CURRENT
var _store_entitlements: Dictionary = {}
var _unlocked_achievements: Dictionary = {}
var _powerbar_theme: String = POWERBAR_THEME_BASE
var _garage_selections: Dictionary = {}
var _social_destinations: Dictionary = {}
var _gpu_vfx_enabled: bool = true
var _audio_enabled: bool = true
var _sfx_enabled: bool = true
var _haptics_enabled: bool = true
var _floor_graphics_enabled: bool = true
var _performance_mode: String = PERFORMANCE_MODE_QUALITY
var _admin_dashboard_username: String = DEFAULT_ADMIN_DASHBOARD_USERNAME
var _admin_dashboard_password: String = DEFAULT_ADMIN_DASHBOARD_PASSWORD
func _ready() -> void:
	ensure_loaded()

func ensure_loaded() -> void:
	if not _boot_trace_enter_logged:
		_boot_trace_enter_logged = true
		SFLog.info("PROFILE_BOOT_TRACE_ENTER", {
			"id": _id,
			"entap_id": _entap_id,
			"call_sign": _call_sign,
			"created_at_unix": _created_at_unix,
			"has_loaded": _has_loaded
		})
		SFLog.info("PROFILE_USER_DATA_DIR", {"dir": OS.get_user_data_dir()})
	if _has_loaded:
		return
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_LOAD", {
		"path": PROFILE_PATH,
		"err": err
	})
	var had_existing_profile: bool = false
	if err == OK:
		_id = str(cfg.get_value(PROFILE_SECTION, "id", ""))
		_entap_id = str(cfg.get_value(PROFILE_SECTION, "entap_id", ""))
		_call_sign = str(cfg.get_value(PROFILE_SECTION, "call_sign", ""))
		_legacy_user_id = str(cfg.get_value(PROFILE_SECTION, "legacy_user_id", cfg.get_value(PROFILE_SECTION, "user_id", "")))
		_user_id = str(cfg.get_value(PROFILE_SECTION, "user_id", ""))
		_display_name = str(cfg.get_value(PROFILE_SECTION, "display_name", ""))
		if _call_sign.strip_edges().is_empty():
			_call_sign = _display_name
		had_existing_profile = not _id.strip_edges().is_empty() or not _user_id.strip_edges().is_empty() or not _legacy_user_id.strip_edges().is_empty()
		_created_at_unix = int(cfg.get_value(PROFILE_SECTION, "created_at_unix", 0))
		_onboarding_complete = bool(cfg.get_value(PROFILE_SECTION, "onboarding_complete", false))
		_handle_chosen = bool(cfg.get_value(PROFILE_SECTION, "handle_chosen", _onboarding_complete))
		_handle_changed_at_unix = int(cfg.get_value(PROFILE_SECTION, "handle_changed_at_unix", 0))
		_next_handle_change_unix = int(cfg.get_value(PROFILE_SECTION, "next_handle_change_unix", 0))
		_handle_change_count = maxi(0, int(cfg.get_value(PROFILE_SECTION, "handle_change_count", 0)))
		_handle_locked = bool(cfg.get_value(PROFILE_SECTION, "handle_locked", false))
		_handle_history = _sanitize_handle_history(cfg.get_value(PROFILE_SECTION, "handle_history", []))
		_forced_rename_required = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_REQUIRED, false))
		_forced_rename_reason = _sanitize_moderation_reason(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_REASON, "")))
		_forced_rename_action_id = _sanitize_moderation_action_id(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_ACTION_ID, "")))
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
		_tutorial_controls_status = _sanitize_tutorial_controls_status(
			str(cfg.get_value(PROFILE_SECTION, "tutorial_controls_status", TUTORIAL_CONTROLS_STATUS_NOT_STARTED))
		)
		_tutorial_controls_version = maxi(0, int(cfg.get_value(PROFILE_SECTION, "tutorial_controls_version", TUTORIAL_CONTROLS_VERSION)))
		_tutorial_controls_followup_bonus_claimed = bool(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_TUTORIAL_CONTROLS_FOLLOWUP_BONUS_CLAIMED, false))
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
		_economy_epoch = str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_ECONOMY_EPOCH, "")).strip_edges()
		_store_entitlements = _sanitize_store_entitlements(cfg.get_value(PROFILE_SECTION, "store_entitlements", {}))
		_unlocked_achievements = _sanitize_unlocked_achievements(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_UNLOCKED_ACHIEVEMENTS, {}))
		_powerbar_theme = _sanitize_powerbar_theme(str(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_POWERBAR_THEME, POWERBAR_THEME_BASE)))
		_garage_selections = _sanitize_garage_selections(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_GARAGE_SELECTIONS, {}))
		_social_destinations = _sanitize_social_destinations(cfg.get_value(PROFILE_SECTION, PROFILE_KEY_SOCIAL_DESTINATIONS, {}))

	var created: bool = false
	if not had_existing_profile:
		_id = ""
		_entap_id = ""
		_call_sign = _default_call_sign(_entap_id)
		_sync_identity_aliases()
		_created_at_unix = int(Time.get_unix_time_from_system())
		_handle_chosen = false
		_handle_changed_at_unix = 0
		_next_handle_change_unix = 0
		_handle_change_count = 0
		_handle_locked = false
		_handle_history = []
		_forced_rename_required = false
		_forced_rename_reason = ""
		_forced_rename_action_id = ""
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
		_tutorial_controls_status = TUTORIAL_CONTROLS_STATUS_NOT_STARTED
		_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
		_tutorial_controls_followup_bonus_claimed = false
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
		_economy_epoch = EconomyEpochScript.CURRENT
		_store_entitlements = {}
		_unlocked_achievements = {}
		_powerbar_theme = POWERBAR_THEME_BASE
		_garage_selections = _default_garage_selections()
		_social_destinations = _default_social_destinations()
		_ensure_mode_maps()
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		created = true
		_created_this_run = true
	else:
		_created_this_run = false
		var identity_updated: bool = _ensure_identity_fields()
		var cleaned_name: String = _sanitize_display_name(_call_sign, _id)
		var updated: bool = false
		if identity_updated:
			updated = true
		if cleaned_name != _display_name:
			_call_sign = cleaned_name
			_sync_identity_aliases()
			updated = true
		if _created_at_unix <= 0:
			_created_at_unix = int(Time.get_unix_time_from_system())
			updated = true
		if _handle_changed_at_unix <= 0 and _handle_chosen:
			_handle_changed_at_unix = _created_at_unix
			updated = true
		if _next_handle_change_unix <= 0 and _handle_chosen:
			_next_handle_change_unix = _first_day_of_next_calendar_year_unix(_handle_changed_at_unix)
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
		var clean_controls_tutorial_status: String = _sanitize_tutorial_controls_status(_tutorial_controls_status)
		if clean_controls_tutorial_status != _tutorial_controls_status:
			_tutorial_controls_status = clean_controls_tutorial_status
			updated = true
		if _tutorial_controls_version <= 0:
			_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
			updated = true
		var cleaned_loadout: Array[String] = _sanitize_loadout_ids(_buff_loadout_ids)
		if cleaned_loadout != _buff_loadout_ids:
			_buff_loadout_ids = cleaned_loadout
			updated = true
		var cleaned_honey: int = maxi(0, _honey_balance)
		if cleaned_honey != _honey_balance:
			_honey_balance = cleaned_honey
			updated = true
		if _economy_epoch != EconomyEpochScript.CURRENT:
			var previous_epoch: String = _economy_epoch
			_honey_balance = DEFAULT_HONEY_BALANCE
			_economy_epoch = EconomyEpochScript.CURRENT
			updated = true
			SFLog.info("PROFILE_ECONOMY_EPOCH_RESET", {
				"previous_epoch": previous_epoch,
				"economy_epoch": _economy_epoch,
				"identity_preserved": true
			})
		var cleaned_entitlements: Dictionary = _sanitize_store_entitlements(_store_entitlements)
		if cleaned_entitlements != _store_entitlements:
			_store_entitlements = cleaned_entitlements
			updated = true
		var cleaned_achievements: Dictionary = _sanitize_unlocked_achievements(_unlocked_achievements)
		if cleaned_achievements != _unlocked_achievements:
			_unlocked_achievements = cleaned_achievements
			updated = true
		var cleaned_theme: String = _sanitize_powerbar_theme(_powerbar_theme)
		if cleaned_theme != _powerbar_theme:
			_powerbar_theme = cleaned_theme
			updated = true
		var cleaned_garage: Dictionary = _sanitize_garage_selections(_garage_selections)
		if cleaned_garage != _garage_selections:
			_garage_selections = cleaned_garage
			updated = true
		var cleaned_social: Dictionary = _sanitize_social_destinations(_social_destinations)
		if cleaned_social != _social_destinations:
			_social_destinations = cleaned_social
			updated = true
		if _ensure_mode_maps():
			updated = true
		_ensure_loadout_owned()
		if updated:
			_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)

	_has_loaded = true
	if created:
		SFLog.info("PROFILE_CREATED", {
			"id": _id,
			"entap_id": _entap_id,
			"call_sign": _call_sign,
			"onboarding_complete": _onboarding_complete
		})
	else:
		SFLog.info("PROFILE_LOADED", {
			"id": _id,
			"entap_id": _entap_id,
			"call_sign": _call_sign,
			"onboarding_complete": _onboarding_complete
		})

func get_id() -> String:
	ensure_loaded()
	return _id

func get_user_id() -> String:
	ensure_loaded()
	return _id if not _id.strip_edges().is_empty() else _user_id.strip_edges()

func get_entap_id() -> String:
	ensure_loaded()
	return _entap_id

func has_authoritative_identity() -> bool:
	ensure_loaded()
	return _is_uuidv7(_id) and _is_valid_entap_id_static(_entap_id)

func get_call_sign() -> String:
	ensure_loaded()
	return _call_sign if not _call_sign.strip_edges().is_empty() else _display_name.strip_edges()

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

func get_tutorial_controls_status() -> String:
	ensure_loaded()
	return _tutorial_controls_status

func get_tutorial_controls_version() -> int:
	ensure_loaded()
	return _tutorial_controls_version

func is_tutorial_controls_completed() -> bool:
	ensure_loaded()
	return _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_COMPLETED

func get_display_name() -> String:
	ensure_loaded()
	return get_call_sign()

func get_handle(uid: String) -> String:
	ensure_loaded()
	if uid == _id:
		return _call_sign
	return ""

func set_display_name(name: String) -> void:
	request_handle_change(name, true, "legacy_set_display_name")

func request_paid_display_name_change(name: String, source: String = "paid_rename") -> Dictionary:
	return request_handle_change(name, true, source)

func request_honey_display_name_change(name: String, source: String = "honey_rename") -> Dictionary:
	ensure_loaded()
	var preview: Dictionary = request_handle_change(name, false, source + "_preview")
	if bool(preview.get("ok", false)):
		return preview
	if str(preview.get("reason", "")) != "requires_honey_payment":
		return preview
	return {
		"ok": false,
		"reason": "requires_honey_payment",
		"message": "Additional Call Sign changes require Honey.",
		"honey_cost": HANDLE_EXTRA_CHANGE_HONEY_COST,
		"payment_action": "spend_honey_then_call_request_paid_display_name_change"
	}

func request_handle_change(name: String, paid_override: bool = false, source: String = "settings") -> Dictionary:
	ensure_loaded()
	var raw_clean: String = name.strip_edges()
	if raw_clean == _call_sign.strip_edges() and _handle_chosen:
		if _forced_rename_required:
			return {
				"ok": false,
				"reason": "forced_rename_required",
				"message": "A moderator-required Call Sign change must choose a new Call Sign.",
				"forced_rename_action_id": _forced_rename_action_id
			}
		return {
			"ok": true,
			"changed": false,
			"handle": _call_sign,
			"next_free_change_unix": _next_handle_change_unix
		}
	var validation: Dictionary = validate_handle_policy(raw_clean)
	if not bool(validation.get("ok", false)):
		SFLog.info("PROFILE_HANDLE_REJECTED", {
			"id": _id,
			"source": source,
			"reason": str(validation.get("reason", "")),
			"attempted": name
		})
		return validation
	var cleaned: String = _sanitize_display_name(raw_clean, _id)
	if cleaned == _call_sign and _handle_chosen:
		return {
			"ok": true,
			"changed": false,
			"handle": _call_sign,
			"next_free_change_unix": _next_handle_change_unix
		}
	if _handle_locked:
		return {
			"ok": false,
			"reason": "locked",
			"message": "Handle changes are locked for this account."
		}
	var now_unix: int = int(Time.get_unix_time_from_system())
	var is_initial_pick: bool = not _handle_chosen
	if not is_initial_pick and not paid_override and not _forced_rename_required and _free_handle_change_used_in_calendar_year(_calendar_year_from_unix(now_unix)):
		return {
			"ok": false,
			"reason": "requires_honey_payment",
			"message": "One free Call Sign change is available per calendar year. Additional changes require Honey.",
			"honey_cost": HANDLE_EXTRA_CHANGE_HONEY_COST,
			"current_calendar_year": _calendar_year_from_unix(now_unix)
		}
	var old_handle: String = _call_sign
	_call_sign = cleaned
	_sync_identity_aliases()
	_handle_chosen = true
	_handle_changed_at_unix = now_unix
	if is_initial_pick or not paid_override:
		_next_handle_change_unix = _first_day_of_next_calendar_year_unix(now_unix)
	var forced_action_id: String = _forced_rename_action_id
	var forced_reason: String = _forced_rename_reason
	var cleared_forced_rename: bool = _forced_rename_required
	_forced_rename_required = false
	_forced_rename_reason = ""
	_forced_rename_action_id = ""
	_handle_change_count += 1
	_handle_history.append({
		"old": old_handle,
		"new": _call_sign,
		"changed_at_unix": now_unix,
		"source": source,
		"paid": paid_override,
		"initial": is_initial_pick,
		"calendar_year": _calendar_year_from_unix(now_unix),
		"moderation_forced": cleared_forced_rename,
		"moderation_action_id": forced_action_id
	})
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_DISPLAY_NAME_SET", {
		"id": _id,
		"call_sign": _call_sign,
		"source": source,
		"paid": paid_override,
		"initial": is_initial_pick
	})
	return {
		"ok": true,
		"changed": true,
		"handle": _call_sign,
		"call_sign": _call_sign,
		"next_free_change_unix": _next_handle_change_unix,
		"initial": is_initial_pick,
		"paid": paid_override,
		"honey_cost": HANDLE_EXTRA_CHANGE_HONEY_COST if paid_override else 0,
		"forced_rename_cleared": cleared_forced_rename,
		"forced_rename_reason": forced_reason,
		"forced_rename_action_id": forced_action_id
	}

func is_handle_chosen() -> bool:
	ensure_loaded()
	return _handle_chosen

func get_handle_policy_snapshot() -> Dictionary:
	ensure_loaded()
	var now_unix: int = int(Time.get_unix_time_from_system())
	return {
		"policy_version": HANDLE_POLICY_VERSION,
		"handle_chosen": _handle_chosen,
		"handle_locked": _handle_locked,
		"forced_rename_required": _forced_rename_required,
		"forced_rename_reason": _forced_rename_reason,
		"forced_rename_action_id": _forced_rename_action_id,
		"handle_change_count": _handle_change_count,
		"handle_changed_at_unix": _handle_changed_at_unix,
		"next_free_change_unix": _next_handle_change_unix,
		"free_change_available": (not _handle_chosen) or _forced_rename_required or (not _handle_locked and not _free_handle_change_used_in_calendar_year(_calendar_year_from_unix(now_unix))),
		"paid_change_available": _handle_chosen and not _handle_locked,
		"cooldown_sec": HANDLE_RENAME_COOLDOWN_SEC,
		"calendar_year": _calendar_year_from_unix(now_unix),
		"free_change_used_this_year": _free_handle_change_used_in_calendar_year(_calendar_year_from_unix(now_unix)),
		"honey_change_cost": HANDLE_EXTRA_CHANGE_HONEY_COST
	}

func require_forced_handle_change(reason: String, moderation_action_id: String = "") -> Dictionary:
	ensure_loaded()
	_forced_rename_required = true
	_forced_rename_reason = _sanitize_moderation_reason(reason)
	_forced_rename_action_id = _sanitize_moderation_action_id(moderation_action_id)
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_FORCED_RENAME_REQUIRED", {
		"user_id": _user_id,
		"reason": _forced_rename_reason,
		"action_id": _forced_rename_action_id
	})
	return {
		"ok": true,
		"forced_rename_required": _forced_rename_required,
		"reason": _forced_rename_reason,
		"action_id": _forced_rename_action_id
	}

func clear_forced_handle_change(reason: String = "moderator_clear") -> Dictionary:
	ensure_loaded()
	if not _forced_rename_required and _forced_rename_reason.is_empty() and _forced_rename_action_id.is_empty():
		return {"ok": true, "changed": false}
	_forced_rename_required = false
	_forced_rename_reason = ""
	_forced_rename_action_id = ""
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_FORCED_RENAME_CLEARED", {"user_id": _user_id, "reason": reason})
	return {"ok": true, "changed": true}

func get_public_identity_snapshot() -> Dictionary:
	ensure_loaded()
	return {
		"schema_version": 1,
		"player_id": _user_id,
		"public_player_id": _public_player_id(_user_id),
		"call_sign": _display_name,
		"display_name": _display_name,
		"handle_policy_version": HANDLE_POLICY_VERSION,
		"identity_authority": "sf_local"
	}

func get_private_profile_snapshot() -> Dictionary:
	ensure_loaded()
	return {
		"schema_version": 1,
		"user_id": _user_id,
		"public_player_id": _public_player_id(_user_id),
		"display_name": _display_name,
		"created_at_unix": _created_at_unix,
		"onboarding_complete": _onboarding_complete,
		"handle_policy": get_handle_policy_snapshot(),
		"handle_history": _handle_history.duplicate(true),
		"communication_preferences": _social_destinations.duplicate(true),
		"privacy_posture": {
			"public_identity_includes_financial_identity": false,
			"public_identity_includes_private_contact": false,
			"public_identity_includes_payment_identity": false
		}
	}

func apply_backend_identity(identity: Dictionary) -> bool:
	ensure_loaded()
	var backend_id: String = _sanitize_user_id(str(identity.get("id", identity.get("player_id", ""))))
	if backend_id.is_empty():
		return false
	var backend_entap_id: String = _sanitize_entap_id(str(identity.get("entap_id", "")))
	var backend_call_sign: String = str(identity.get("call_sign", identity.get("display_name", _call_sign))).strip_edges()
	if not bool(validate_call_sign(backend_call_sign).get("ok", false)):
		backend_call_sign = _call_sign
	var changed: bool = false
	if backend_id != _id:
		if _legacy_user_id.strip_edges().is_empty() and not _id.strip_edges().is_empty():
			_legacy_user_id = _id
		_id = backend_id
		changed = true
	if not backend_entap_id.is_empty() and backend_entap_id != _entap_id:
		_entap_id = backend_entap_id
		changed = true
	if not backend_call_sign.strip_edges().is_empty() and backend_call_sign != _call_sign:
		_call_sign = _sanitize_display_name(backend_call_sign, _id)
		changed = true
	if changed:
		_sync_identity_aliases()
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		SFLog.info("PROFILE_BACKEND_IDENTITY_APPLIED", {
			"id": _id,
			"entap_id": _entap_id,
			"call_sign": _call_sign
		})
	return changed

func smoke_force_identity_state(
		id: String,
		entap_id: String,
		call_sign: String,
		handle_chosen: bool,
		onboarding_complete: bool
	) -> bool:
	if not OS.is_debug_build():
		return false
	ensure_loaded()
	_id = _sanitize_user_id(id)
	_entap_id = _sanitize_entap_id(entap_id)
	_call_sign = _sanitize_display_name(call_sign, _id)
	_handle_chosen = handle_chosen
	_onboarding_complete = onboarding_complete
	_sync_identity_aliases()
	return true

func set_user_id(raw: String) -> bool:
	ensure_loaded()
	var uid: String = _sanitize_user_id(raw)
	if not _is_valid_user_id(uid):
		SFLog.info("PROFILE_USER_ID_REJECTED", {"attempted": raw})
		return false
	if uid == _id:
		SFLog.info("PROFILE_USER_ID_NOOP", {"id": _id})
		return true
	var old_id: String = _id
	_id = uid
	_sync_identity_aliases()
	if _call_sign.strip_edges().is_empty():
		_call_sign = _default_call_sign(_entap_id)
		_sync_identity_aliases()
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_USER_ID_SET", {
		"old": old_id,
		"new": _id
	})
	return true

func mark_onboarding_complete() -> void:
	ensure_loaded()
	if _onboarding_complete:
		return
	if not _handle_chosen:
		SFLog.info("PROFILE_ONBOARDING_BLOCKED_NO_HANDLE", {"id": _id})
		return
	if _id.strip_edges().is_empty() or _entap_id.strip_edges().is_empty():
		SFLog.info("PROFILE_ONBOARDING_BLOCKED_NO_BACKEND_IDENTITY", {
			"id": _id,
			"entap_id": _entap_id
		})
		return
	_onboarding_complete = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ONBOARDING_COMPLETE", {"id": _id})

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

func begin_tutorial_controls() -> void:
	ensure_loaded()
	if _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_COMPLETED or _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_SKIPPED:
		return
	if _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_IN_PROGRESS and _tutorial_controls_version == TUTORIAL_CONTROLS_VERSION:
		return
	_tutorial_controls_status = TUTORIAL_CONTROLS_STATUS_IN_PROGRESS
	_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_CONTROLS_BEGIN", {
		"user_id": _user_id,
		"version": _tutorial_controls_version
	})

func mark_tutorial_controls_completed() -> void:
	ensure_loaded()
	if _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_COMPLETED and _tutorial_controls_version == TUTORIAL_CONTROLS_VERSION:
		return
	_tutorial_controls_status = TUTORIAL_CONTROLS_STATUS_COMPLETED
	_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_CONTROLS_COMPLETED", {"user_id": _user_id})

func has_tutorial_controls_followup_bonus_claimed() -> bool:
	ensure_loaded()
	return _tutorial_controls_followup_bonus_claimed

func mark_tutorial_controls_followup_bonus_claimed() -> bool:
	ensure_loaded()
	if _tutorial_controls_followup_bonus_claimed:
		return false
	_tutorial_controls_followup_bonus_claimed = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_CONTROLS_FOLLOWUP_BONUS_CLAIMED", {"user_id": _user_id})
	return true

func mark_tutorial_controls_skipped() -> void:
	ensure_loaded()
	if _tutorial_controls_status == TUTORIAL_CONTROLS_STATUS_SKIPPED and _tutorial_controls_version == TUTORIAL_CONTROLS_VERSION:
		return
	_tutorial_controls_status = TUTORIAL_CONTROLS_STATUS_SKIPPED
	_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_CONTROLS_SKIPPED", {"user_id": _user_id})

func prepare_tutorial_controls_sandbox() -> void:
	ensure_loaded()
	_onboarding_complete = true
	_controls_hint_seen = true
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_SKIPPED
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_SKIPPED
	_tutorial_section2_unlocked = false
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_SKIPPED
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_SKIPPED
	_tutorial_section3_unlocked = false
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_SKIPPED
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_SKIPPED
	_tutorial_controls_status = TUTORIAL_CONTROLS_STATUS_IN_PROGRESS
	_tutorial_controls_version = TUTORIAL_CONTROLS_VERSION
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_CONTROLS_SANDBOX_PREPARED", {
		"user_id": _user_id,
		"version": _tutorial_controls_version
	})

func prepare_tutorial_section1_sandbox() -> void:
	ensure_loaded()
	_onboarding_complete = true
	_controls_hint_seen = true
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_IN_PROGRESS
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_0_INTRO
	_tutorial_section2_unlocked = false
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_NOT_STARTED
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_0_INTRO
	_tutorial_section3_unlocked = false
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_NOT_STARTED
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_0_INTRO
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION1_SANDBOX_PREPARED", {"user_id": _user_id})

func prepare_tutorial_section2_sandbox() -> void:
	ensure_loaded()
	_onboarding_complete = true
	_controls_hint_seen = true
	_tutorial_section1_status = TUTORIAL_SECTION1_STATUS_COMPLETED
	_tutorial_section1_step = TUTORIAL_SECTION1_STEP_COMPLETED
	_tutorial_section2_unlocked = true
	_tutorial_section2_status = TUTORIAL_SECTION2_STATUS_IN_PROGRESS
	_tutorial_section2_step = TUTORIAL_SECTION2_STEP_0_INTRO
	_tutorial_section3_unlocked = false
	_tutorial_section3_status = TUTORIAL_SECTION3_STATUS_NOT_STARTED
	_tutorial_section3_step = TUTORIAL_SECTION3_STEP_0_INTRO
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_TUTORIAL_SECTION2_SANDBOX_PREPARED", {"user_id": _user_id})

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
	var scale_factor: float = 1.0
	match _performance_mode:
		PERFORMANCE_MODE_PERFORMANCE:
			scale_factor = 0.8
		PERFORMANCE_MODE_BALANCED:
			scale_factor = 0.9
	if _uses_mobile_content_scale():
		scale_factor *= MOBILE_CONTENT_SCALE_MULTIPLIER
	return scale_factor

func _uses_mobile_content_scale() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("ios") or OS.has_feature("android"):
		return true
	return OS.has_feature("web_ios") or OS.has_feature("web_android")

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

func get_unlocked_achievements() -> Dictionary:
	ensure_loaded()
	return _unlocked_achievements.duplicate(true)

func has_achievement(achievement_id: String) -> bool:
	ensure_loaded()
	var clean_id: String = achievement_id.strip_edges()
	if clean_id == "":
		return false
	return bool(_unlocked_achievements.get(clean_id, false))

func grant_achievement(achievement_id: String) -> bool:
	ensure_loaded()
	var clean_id: String = achievement_id.strip_edges()
	if clean_id == "":
		return false
	if bool(_unlocked_achievements.get(clean_id, false)):
		return false
	_unlocked_achievements[clean_id] = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ACHIEVEMENT_GRANTED", {
		"user_id": _user_id,
		"achievement_id": clean_id
	})
	achievement_granted.emit(clean_id)
	return true

func get_powerbar_theme() -> String:
	ensure_loaded()
	return _powerbar_theme

func set_powerbar_theme(theme_id: String) -> bool:
	ensure_loaded()
	var clean_theme: String = _sanitize_powerbar_theme(theme_id)
	if clean_theme == _powerbar_theme:
		return false
	_powerbar_theme = clean_theme
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_POWERBAR_THEME_SET", {
		"user_id": _user_id,
		"theme_id": _powerbar_theme
	})
	powerbar_theme_changed.emit(_powerbar_theme)
	return true

func get_garage_selections() -> Dictionary:
	ensure_loaded()
	return _garage_selections.duplicate(true)

func get_garage_selection(category_id: String) -> String:
	ensure_loaded()
	var defaults: Dictionary = _default_garage_selections()
	var clean_category: String = str(category_id).strip_edges().to_lower()
	if not defaults.has(clean_category):
		return ""
	return str(_garage_selections.get(clean_category, defaults.get(clean_category, "")))

func set_garage_selection(category_id: String, item_id: String) -> bool:
	ensure_loaded()
	var defaults: Dictionary = _default_garage_selections()
	var clean_category: String = str(category_id).strip_edges().to_lower()
	var clean_item: String = str(item_id).strip_edges()
	if clean_item == "":
		return false
	if not defaults.has(clean_category):
		return false
	var current_item: String = str(_garage_selections.get(clean_category, defaults.get(clean_category, "")))
	if current_item == clean_item:
		return false
	_garage_selections[clean_category] = clean_item
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_GARAGE_SELECTION_SET", {
		"user_id": _user_id,
		"category_id": clean_category,
		"item_id": clean_item
	})
	garage_selection_changed.emit(clean_category, clean_item)
	return true

func get_social_destinations() -> Dictionary:
	ensure_loaded()
	return _social_destinations.duplicate(true)

func is_social_destination_enabled(destination_id: String) -> bool:
	ensure_loaded()
	var clean_destination: String = str(destination_id).strip_edges().to_lower()
	if not _default_social_destinations().has(clean_destination):
		return false
	return bool(_social_destinations.get(clean_destination, false))

func set_social_destination_enabled(destination_id: String, enabled: bool) -> bool:
	ensure_loaded()
	var clean_destination: String = str(destination_id).strip_edges().to_lower()
	if not _default_social_destinations().has(clean_destination):
		return false
	var current_enabled: bool = bool(_social_destinations.get(clean_destination, false))
	if current_enabled == enabled:
		return false
	_social_destinations[clean_destination] = enabled
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_SOCIAL_DESTINATION_SET", {
		"user_id": _user_id,
		"destination_id": clean_destination,
		"enabled": enabled
	})
	social_destination_changed.emit(clean_destination, enabled)
	return true

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
	_ensure_identity_fields()
	_sync_identity_aliases()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(PROFILE_SECTION, "id", _id)
	cfg.set_value(PROFILE_SECTION, "entap_id", _entap_id)
	cfg.set_value(PROFILE_SECTION, "call_sign", _call_sign)
	if not _legacy_user_id.strip_edges().is_empty():
		cfg.set_value(PROFILE_SECTION, "legacy_user_id", _legacy_user_id)
	cfg.set_value(PROFILE_SECTION, "user_id", _id)
	cfg.set_value(PROFILE_SECTION, "display_name", _call_sign)
	cfg.set_value(PROFILE_SECTION, "handle_chosen", _handle_chosen)
	cfg.set_value(PROFILE_SECTION, "handle_changed_at_unix", _handle_changed_at_unix)
	cfg.set_value(PROFILE_SECTION, "next_handle_change_unix", _next_handle_change_unix)
	cfg.set_value(PROFILE_SECTION, "handle_change_count", _handle_change_count)
	cfg.set_value(PROFILE_SECTION, "handle_locked", _handle_locked)
	cfg.set_value(PROFILE_SECTION, "handle_history", _handle_history)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_REQUIRED, _forced_rename_required)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_REASON, _forced_rename_reason)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_FORCED_RENAME_ACTION_ID, _forced_rename_action_id)
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
	cfg.set_value(PROFILE_SECTION, "tutorial_controls_status", _tutorial_controls_status)
	cfg.set_value(PROFILE_SECTION, "tutorial_controls_version", _tutorial_controls_version)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_TUTORIAL_CONTROLS_FOLLOWUP_BONUS_CLAIMED, _tutorial_controls_followup_bonus_claimed)
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
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_ECONOMY_EPOCH, _economy_epoch)
	cfg.set_value(PROFILE_SECTION, "store_entitlements", _store_entitlements)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_UNLOCKED_ACHIEVEMENTS, _unlocked_achievements)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_POWERBAR_THEME, _powerbar_theme)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_GARAGE_SELECTIONS, _garage_selections)
	cfg.set_value(PROFILE_SECTION, PROFILE_KEY_SOCIAL_DESTINATIONS, _social_destinations)
	var err: int = cfg.save(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_SAVE", {
		"path": PROFILE_PATH,
		"err": err
	})
	if err == OK:
		SFLog.info("PROFILE_SAVED", {
			"path": PROFILE_PATH,
			"id": _id,
			"entap_id": _entap_id,
			"call_sign": _call_sign
		})

func _ensure_identity_fields() -> bool:
	var changed: bool = false
	var clean_id: String = _sanitize_user_id(_id)
	if clean_id.is_empty() and not _user_id.strip_edges().is_empty() and _is_uuidv7(_user_id.strip_edges()):
		clean_id = _user_id.strip_edges().to_lower()
	if clean_id.is_empty():
		if _legacy_user_id.strip_edges().is_empty() and not _user_id.strip_edges().is_empty():
			_legacy_user_id = _user_id.strip_edges()
	if clean_id != _id:
		_id = clean_id
		changed = true
	var clean_entap: String = _sanitize_entap_id(_entap_id)
	if clean_entap != _entap_id:
		_entap_id = clean_entap
		changed = true
	var clean_call_sign: String = _sanitize_display_name(_call_sign, _id)
	if clean_call_sign.is_empty():
		clean_call_sign = _default_call_sign(_entap_id)
	if clean_call_sign != _call_sign:
		_call_sign = clean_call_sign
		changed = true
	if _user_id != _id or _display_name != _call_sign:
		_sync_identity_aliases()
		changed = true
	return changed

func _sync_identity_aliases() -> void:
	_user_id = _id
	_display_name = _call_sign

func _default_call_sign(entap_id: String) -> String:
	var suffix: String = _sanitize_entap_id(entap_id).replace(" ", "_")
	if suffix.length() >= 4:
		suffix = suffix.substr(suffix.length() - 4, 4)
	else:
		suffix = suffix.pad_zeros(4)
	return DISPLAY_NAME_PREFIX + suffix.to_upper()

func _default_display_name(user_id: String) -> String:
	return _default_call_sign(_entap_id)

func _sanitize_display_name(name: String, user_id: String) -> String:
	var cleaned: String = ""
	var raw: String = name.strip_edges()
	for i in range(raw.length()):
		var code: int = raw.unicode_at(i)
		var allowed: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95
		cleaned += raw.substr(i, 1) if allowed else "_"
	if cleaned.length() > DISPLAY_NAME_MAX_LEN:
		cleaned = cleaned.substr(0, DISPLAY_NAME_MAX_LEN)
	if cleaned.is_empty():
		cleaned = _default_call_sign(_entap_id)
	while cleaned.length() < DISPLAY_NAME_MIN_LEN:
		cleaned += "_"
	return cleaned

static func validate_handle_policy(raw_handle: String) -> Dictionary:
	var handle: String = raw_handle.strip_edges()
	if handle.length() < DISPLAY_NAME_MIN_LEN:
		return _handle_reject("too_short", "Handle must be at least %d characters." % DISPLAY_NAME_MIN_LEN)
	if handle.length() > DISPLAY_NAME_MAX_LEN:
		return _handle_reject("too_long", "Handle must be %d characters or fewer." % DISPLAY_NAME_MAX_LEN)
	for i in range(handle.length()):
		var code: int = handle.unicode_at(i)
		var allowed: bool = (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95
		if not allowed:
			return _handle_reject("invalid_chars", "Use letters, numbers, and underscore only.")
	var compact: String = _handle_policy_compact(handle)
	var collapsed: String = _collapse_repeated_chars(compact)
	var lower_handle: String = handle.to_lower()
	if lower_handle != "swarmfather" and compact.begins_with("swarm") and (compact.contains("father") or compact.contains("daddy") or compact.contains("daddi") or compact.contains("dad")):
		return _handle_reject("reserved_founder", "That handle is reserved.")
	for protected_term in ["admin", "moderator", "support", "official", "developer", "devteam", "staff"]:
		if compact == protected_term or compact.begins_with(protected_term + "_") or compact.ends_with("_" + protected_term):
			return _handle_reject("reserved_staff", "That handle could be confused with staff.")
		if compact.begins_with(protected_term) or compact.ends_with(protected_term):
			return _handle_reject("reserved_staff", "That handle could be confused with staff.")
	if compact == "mod" or compact.begins_with("mod_") or compact.ends_with("_mod"):
		return _handle_reject("reserved_staff", "That handle could be confused with staff.")
	for reserved_identity in ["entap", "swarmfront", "officialswarmfront", "swarmfrontofficial", "mattballou"]:
		if compact == reserved_identity or compact.begins_with(reserved_identity + "_") or compact.ends_with("_" + reserved_identity):
			return _handle_reject("reserved_identity", "That handle is reserved.")
	var hard_terms: Array[String] = [
		"fuck", "fuk", "fck", "fvck", "shit", "cunt",
		"rape", "rapist", "molest", "incest", "pedo", "pedophile",
		"genocide", "holocaust", "nazi", "hitler",
		"nigger", "nigga", "kike", "chink", "spic", "gook", "wetback", "faggot"
	]
	for term in hard_terms:
		if compact.contains(term) or collapsed.contains(term):
			return _handle_reject("prohibited_language", "That handle is not allowed.")
	if compact.contains("jew"):
		var charged_adjacent: Array[String] = ["fuck", "shit", "cunt", "rape", "gas", "oven", "nazi", "hitler", "genocide", "hate", "die", "kys"]
		for term in charged_adjacent:
			if compact.contains(term) or collapsed.contains(term):
				return _handle_reject("protected_class_abuse", "That handle is not allowed.")
	return {
		"ok": true,
		"handle": handle,
		"call_sign": handle,
		"normalized": compact
	}

static func validate_call_sign(raw_call_sign: String) -> Dictionary:
	return validate_handle_policy(raw_call_sign)

static func validate_entap_id(raw_entap_id: String) -> Dictionary:
	var clean: String = raw_entap_id.strip_edges().to_upper()
	if _is_valid_entap_id_static(clean):
		return {"ok": true, "entap_id": clean}
	return {
		"ok": false,
		"reason": "invalid_entap_id",
		"message": "ENTaP ID must match AAA 000."
	}

static func _handle_reject(reason: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"message": message
	}

static func _handle_policy_compact(value: String) -> String:
	var out: String = ""
	var lower: String = value.strip_edges().to_lower()
	for i in range(lower.length()):
		var ch: String = lower.substr(i, 1)
		match ch:
			"@", "4":
				out += "a"
			"0":
				out += "o"
			"1", "!", "|":
				out += "i"
			"$", "5":
				out += "s"
			"3":
				out += "e"
			"7":
				out += "t"
			_:
				var code: int = ch.unicode_at(0)
				if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
					out += ch
	return out

static func _collapse_repeated_chars(value: String) -> String:
	var out: String = ""
	var last: String = ""
	for i in range(value.length()):
		var ch: String = value.substr(i, 1)
		if ch == last:
			continue
		out += ch
		last = ch
	return out

func _sanitize_handle_history(values_v: Variant) -> Array:
	var out: Array = []
	if typeof(values_v) != TYPE_ARRAY:
		return out
	for item_v in values_v as Array:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v as Dictionary
		out.append({
			"old": _sanitize_display_name(str(item.get("old", "")), _user_id),
			"new": _sanitize_display_name(str(item.get("new", "")), _user_id),
			"changed_at_unix": int(item.get("changed_at_unix", 0)),
			"source": str(item.get("source", "")),
			"paid": bool(item.get("paid", false)),
			"initial": bool(item.get("initial", false)),
			"calendar_year": int(item.get("calendar_year", _calendar_year_from_unix(int(item.get("changed_at_unix", 0))))),
			"moderation_forced": bool(item.get("moderation_forced", false)),
			"moderation_action_id": _sanitize_moderation_action_id(str(item.get("moderation_action_id", "")))
		})
	return out

func _free_handle_change_used_in_calendar_year(year: int) -> bool:
	for item_any in _handle_history:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		if bool(item.get("initial", false)):
			continue
		if bool(item.get("paid", false)):
			continue
		if bool(item.get("moderation_forced", false)):
			continue
		var item_year: int = int(item.get("calendar_year", _calendar_year_from_unix(int(item.get("changed_at_unix", 0)))))
		if item_year == year:
			return true
	return false

func _calendar_year_from_unix(unix_time: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(maxi(0, unix_time))
	var year: int = int(dt.get("year", 0))
	if year <= 0:
		year = int(Time.get_datetime_dict_from_system().get("year", 0))
	return year

func _first_day_of_next_calendar_year_unix(unix_time: int) -> int:
	var year: int = _calendar_year_from_unix(unix_time)
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year + 1,
		"month": 1,
		"day": 1,
		"hour": 0,
		"minute": 0,
		"second": 0
	}))

func _sanitize_moderation_reason(value: String) -> String:
	var clean: String = value.strip_edges()
	if clean.length() > 160:
		clean = clean.substr(0, 160)
	return clean

func _sanitize_moderation_action_id(value: String) -> String:
	var clean: String = value.strip_edges()
	if clean.length() > 80:
		clean = clean.substr(0, 80)
	return clean

func _public_player_id(player_id: String) -> String:
	var clean: String = _sanitize_user_id(player_id)
	if clean.length() <= 6:
		return clean
	return "sf_" + clean.substr(clean.length() - 6, 6)

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
	if cleaned == TUTORIAL_SECTION1_STEP_4_BUFF:
		return TUTORIAL_SECTION1_STEP_4_BUFF
	if cleaned == TUTORIAL_SECTION1_STEP_4_SWARM_FINISH:
		return TUTORIAL_SECTION1_STEP_4_SWARM_FINISH
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

func _sanitize_tutorial_controls_status(status: String) -> String:
	var cleaned: String = status.strip_edges().to_lower()
	if cleaned == TUTORIAL_CONTROLS_STATUS_IN_PROGRESS:
		return TUTORIAL_CONTROLS_STATUS_IN_PROGRESS
	if cleaned == TUTORIAL_CONTROLS_STATUS_COMPLETED:
		return TUTORIAL_CONTROLS_STATUS_COMPLETED
	if cleaned == TUTORIAL_CONTROLS_STATUS_SKIPPED:
		return TUTORIAL_CONTROLS_STATUS_SKIPPED
	return TUTORIAL_CONTROLS_STATUS_NOT_STARTED

func _sanitize_admin_dashboard_username(username: String) -> String:
	return username.strip_edges()

func _sanitize_admin_dashboard_password(password: String) -> String:
	return password

func _sanitize_user_id(raw: String) -> String:
	var cleaned: String = raw.strip_edges().to_lower()
	return cleaned if _is_uuidv7(cleaned) else ""

func _is_valid_user_id(uid: String) -> bool:
	return _is_uuidv7(uid)

func _is_uuidv7(uid: String) -> bool:
	var clean: String = uid.strip_edges().to_lower()
	if clean.length() != 36:
		return false
	for hyphen_index in [8, 13, 18, 23]:
		if clean.substr(hyphen_index, 1) != "-":
			return false
	if clean.substr(14, 1) != "7":
		return false
	var variant: String = clean.substr(19, 1)
	if not ["8", "9", "a", "b"].has(variant):
		return false
	for i in range(clean.length()):
		if [8, 13, 18, 23].has(i):
			continue
		var code: int = clean.unicode_at(i)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		if not is_digit and not is_lower_hex:
			return false
	return true

func _sanitize_entap_id(raw: String) -> String:
	var clean: String = raw.strip_edges().to_upper()
	return clean if _is_valid_entap_id_static(clean) else ""

static func _is_valid_entap_id_static(value: String) -> bool:
	var clean: String = value.strip_edges().to_upper()
	if clean.length() != 7:
		return false
	if clean.substr(3, 1) != " ":
		return false
	for i in range(3):
		var letter_code: int = clean.unicode_at(i)
		if letter_code < 65 or letter_code > 90:
			return false
	for i in range(4, 7):
		var digit_code: int = clean.unicode_at(i)
		if digit_code < 48 or digit_code > 57:
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

func _sanitize_unlocked_achievements(raw: Variant) -> Dictionary:
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

func _sanitize_powerbar_theme(theme_id: String) -> String:
	var clean: String = theme_id.strip_edges().to_lower()
	match clean:
		"", POWERBAR_THEME_BASE:
			return POWERBAR_THEME_BASE
		"upgraded_static", POWERBAR_THEME_UPGRADED:
			return POWERBAR_THEME_UPGRADED
		POWERBAR_THEME_UPGRADED_DYNAMIC:
			return POWERBAR_THEME_UPGRADED_DYNAMIC
		POWERBAR_THEME_UPGRADED_BOIL:
			return POWERBAR_THEME_UPGRADED_BOIL
		_:
			return POWERBAR_THEME_BASE

func _default_garage_selections() -> Dictionary:
	return {
		"units": "unit_field_issue",
		"hives": "hive_classic",
		"lanes": "lane_classic",
		"floors": "floor_standard",
		"vfx": "vfx_ion_pop"
	}

func _sanitize_garage_selections(raw: Variant) -> Dictionary:
	var defaults: Dictionary = _default_garage_selections()
	var out: Dictionary = defaults.duplicate(true)
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = raw as Dictionary
	for category_any in source.keys():
		var clean_category: String = str(category_any).strip_edges().to_lower()
		if not defaults.has(clean_category):
			continue
		var clean_item: String = str(source.get(category_any, "")).strip_edges()
		if clean_item == "":
			continue
		out[clean_category] = clean_item
	return out

func _default_social_destinations() -> Dictionary:
	return {
		"discord": false,
		"slack": false,
		"instagram": false,
		"tiktok": false,
		"hive_feed": false
	}

func _sanitize_social_destinations(raw: Variant) -> Dictionary:
	var defaults: Dictionary = _default_social_destinations()
	var out: Dictionary = defaults.duplicate(true)
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var source: Dictionary = raw as Dictionary
	for destination_any in source.keys():
		var clean_destination: String = str(destination_any).strip_edges().to_lower()
		if not defaults.has(clean_destination):
			continue
		out[clean_destination] = bool(source.get(destination_any, false))
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
		"profile_id": _id,
		"id": _id,
		"entap_id": _entap_id,
		"handle": _call_sign,
		"call_sign": _call_sign,
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
	if profile_id != _id:
		return

func create_profile() -> String:
	return get_user_id()

func rename_profile(profile_id: String, new_handle: String) -> bool:
	ensure_loaded()
	if profile_id != _id:
		return false
	var result: Dictionary = request_handle_change(new_handle, false, "rename_dialog")
	return bool(result.get("ok", false))

func delete_profile(_profile_id: String) -> bool:
	return false
