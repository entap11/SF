class_name ProfileSettingsPanel
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")
const UITypography := preload("res://scripts/ui/ui_typography.gd")
const TOGGLE_ON_TEXTURE: Texture2D = preload("res://assets/ui/toggles/sf_toggle_on.svg")
const TOGGLE_OFF_TEXTURE: Texture2D = preload("res://assets/ui/toggles/sf_toggle_off.svg")
const TOGGLE_ON_DISABLED_TEXTURE: Texture2D = preload("res://assets/ui/toggles/sf_toggle_on_disabled.svg")
const TOGGLE_OFF_DISABLED_TEXTURE: Texture2D = preload("res://assets/ui/toggles/sf_toggle_off_disabled.svg")

const MIN_HANDLE_LEN: int = 3
const MAX_HANDLE_LEN: int = 16
const DEV_ALLOW_UID_EDIT: bool = false
const SETTINGS_CONTROL_HEIGHT: float = 72.0
const SETTINGS_TOGGLE_HEIGHT: float = 88.0
const SETTINGS_TOGGLE_WIDTH: float = 184.0
const SETTINGS_TOGGLE_TEXT_GAP: int = 16
const SETTINGS_TEXT_EDIT_HEIGHT: float = 144.0
const SETTINGS_CATEGORY_BAR_HEIGHT: float = 72.0
const SETTINGS_CATEGORY_GAP: float = 24.0
const CATEGORY_ACCOUNT: String = "account"
const CATEGORY_AUDIO: String = "audio"
const CATEGORY_GRAPHICS: String = "graphics"
const CATEGORY_SUPPORT: String = "support"
const PERF_MODE_QUALITY: String = "quality"
const PERF_MODE_BALANCED: String = "balanced"
const PERF_MODE_PERFORMANCE: String = "performance"
const ADMIN_DASHBOARD_URL_DEFAULT: String = "http://127.0.0.1:8787/dashboard"
const ADMIN_DASHBOARD_USERNAME_DEFAULT: String = ""
const ADMIN_DASHBOARD_PASSWORD_DEFAULT: String = ""
const REPORT_CATEGORY_OPTIONS: Array[String] = ["call_sign", "hive", "match", "chat", "other"]

@onready var profile_dropdown: OptionButton = $VBox/ProfileRow/ProfileDropdown
@onready var display_name_input: LineEdit = $VBox/ProfileRow/DisplayNameInput
@onready var apply_display_name_button: Button = $VBox/ProfileRow/ApplyDisplayNameButton
@onready var current_user_id_label: Label = $VBox/UserIdSection/UserIdCurrentRow/CurrentUserIdLabel
@onready var copy_user_id_button: Button = $VBox/UserIdSection/UserIdCurrentRow/CopyUserIdButton
@onready var user_id_input: LineEdit = $VBox/UserIdSection/UserIdRow/UserIdInput
@onready var set_user_id_button: Button = $VBox/UserIdSection/UserIdRow/SetUserIdButton
@onready var user_id_status_label: Label = $VBox/UserIdSection/UserIdStatusLabel
@onready var user_id_warning_label: Label = $VBox/UserIdSection/UserIdWarningLabel
@onready var gpu_vfx_toggle: CheckButton = $VBox/VideoSection/GpuVfxRow/GpuVfxToggle
@onready var master_audio_toggle: CheckButton = $VBox/AudioSection/MasterAudioRow/MasterAudioToggle
@onready var sfx_toggle: CheckButton = $VBox/AudioSection/SfxRow/SfxToggle
@onready var haptics_toggle: CheckButton = $VBox/AudioSection/HapticsRow/HapticsToggle
@onready var performance_mode_option: OptionButton = $VBox/PerformanceSection/PerformanceModeRow/PerformanceModeOption
@onready var floor_graphics_toggle: CheckButton = $VBox/PerformanceSection/FloorGraphicsRow/FloorGraphicsToggle
@onready var admin_section: VBoxContainer = $VBox/AdminSection
@onready var admin_open_button: Button = $VBox/AdminSection/AdminRow/AdminOpenButton
@onready var admin_username_input: LineEdit = $VBox/AdminSection/AdminCredentialsRow/AdminUsernameInput
@onready var admin_password_input: LineEdit = $VBox/AdminSection/AdminCredentialsRow/AdminPasswordInput
@onready var admin_status_label: Label = $VBox/AdminSection/AdminStatusLabel
@onready var support_diagnostics_button: Button = $VBox/SupportSection/SupportRow/SupportDiagnosticsButton
@onready var rename_policy_label: Label = $VBox/RenamePolicyLabel
@onready var community_safety_button: Button = $VBox/CommunitySafetySection/CommunitySafetyRow/CommunitySafetyButton
@onready var community_safety_status_label: Label = $VBox/CommunitySafetySection/CommunitySafetyStatusLabel
@onready var buttons_row: HBoxContainer = $VBox/ButtonsRow
@onready var new_button: Button = $VBox/ButtonsRow/NewProfileButton
@onready var rename_button: Button = $VBox/ButtonsRow/RenameButton
@onready var delete_button: Button = $VBox/ButtonsRow/DeleteButton
@onready var rename_dialog: AcceptDialog = $RenameDialog
@onready var rename_input: LineEdit = $RenameDialog/RenameInput
@onready var community_safety_dialog: AcceptDialog = $CommunitySafetyDialog
@onready var safety_overview: Label = $CommunitySafetyDialog/SafetyVBox/SafetyOverview
@onready var report_target_input: LineEdit = $CommunitySafetyDialog/SafetyVBox/ReportTargetInput
@onready var report_category_option: OptionButton = $CommunitySafetyDialog/SafetyVBox/ReportCategoryOption
@onready var report_summary_input: TextEdit = $CommunitySafetyDialog/SafetyVBox/ReportSummaryInput
@onready var submit_report_button: Button = $CommunitySafetyDialog/SafetyVBox/SubmitReportButton
@onready var appeal_action_input: LineEdit = $CommunitySafetyDialog/SafetyVBox/AppealActionInput
@onready var appeal_statement_input: TextEdit = $CommunitySafetyDialog/SafetyVBox/AppealStatementInput
@onready var submit_appeal_button: Button = $CommunitySafetyDialog/SafetyVBox/SubmitAppealButton
@onready var safety_status_label: Label = $CommunitySafetyDialog/SafetyVBox/SafetyStatusLabel
@export var admin_dashboard_url: String = ADMIN_DASHBOARD_URL_DEFAULT
@export var admin_tools_enabled_in_release: bool = false
var _font_regular: Font = null
var _font_semibold: Font = null
var _category_tabs: HBoxContainer = null
var _category_buttons: Dictionary = {}
var _active_category: String = CATEGORY_ACCOUNT

func _ready() -> void:
	ProfileManager.ensure_loaded()
	_apply_readability_layout()
	_build_category_tabs()
	profile_dropdown.item_selected.connect(_on_profile_selected)
	new_button.pressed.connect(_on_new_profile_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	display_name_input.text_submitted.connect(_on_display_name_submitted)
	apply_display_name_button.pressed.connect(_apply_display_name)
	set_user_id_button.pressed.connect(_on_set_user_id_pressed)
	copy_user_id_button.pressed.connect(_on_copy_user_id_pressed)
	gpu_vfx_toggle.toggled.connect(_on_gpu_vfx_toggled)
	master_audio_toggle.toggled.connect(_on_master_audio_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	performance_mode_option.item_selected.connect(_on_performance_mode_selected)
	floor_graphics_toggle.toggled.connect(_on_floor_graphics_toggled)
	support_diagnostics_button.pressed.connect(_on_support_diagnostics_pressed)
	community_safety_button.pressed.connect(_on_community_safety_pressed)
	community_safety_dialog.canceled.connect(_restore_community_safety_focus)
	community_safety_dialog.confirmed.connect(_restore_community_safety_focus)
	submit_report_button.pressed.connect(_on_submit_report_pressed)
	submit_appeal_button.pressed.connect(_on_submit_appeal_pressed)
	_disable_legacy_profile_controls()
	_set_uid_edit_enabled(DEV_ALLOW_UID_EDIT)
	_refresh_admin_tools()
	_build_report_category_options()
	_build_performance_options()
	_refresh_options()
	_refresh_display_name()
	_refresh_user_id()
	_refresh_gpu_vfx()
	_refresh_audio_settings()
	_refresh_performance_settings()
	_set_active_category(CATEGORY_ACCOUNT)
	_apply_master_audio_setting()
	_apply_performance_mode_setting()

func _refresh_options() -> void:
	var profiles: Array[Dictionary] = ProfileManager.get_profiles()
	var active_id: String = ProfileManager.get_active_profile_id()
	profile_dropdown.clear()
	var active_index: int = 0
	for i in range(profiles.size()):
		var profile: Dictionary = profiles[i]
		var handle: String = str(profile.get("call_sign", profile.get("handle", "")))
		var pid: String = str(profile.get("profile_id", ""))
		var label: String = handle
		var entap_id: String = str(profile.get("entap_id", ""))
		if not entap_id.is_empty():
			label = "%s (%s)" % [handle, entap_id]
		profile_dropdown.add_item(label)
		profile_dropdown.set_item_metadata(i, pid)
		if pid == active_id:
			active_index = i
	if profiles.size() > 0:
		profile_dropdown.select(active_index)
	delete_button.disabled = profiles.size() <= 1

func _refresh_display_name() -> void:
	var name_value: String = ProfileManager.get_display_name()
	display_name_input.text = name_value
	_refresh_rename_policy()

func _refresh_rename_policy(message: String = "") -> void:
	if rename_policy_label == null:
		return
	if not message.is_empty():
		rename_policy_label.text = message
		return
	if not ProfileManager.has_method("get_handle_policy_snapshot"):
		rename_policy_label.text = "Choose a call sign. Letters, numbers, underscore."
		return
	var snapshot: Dictionary = ProfileManager.call("get_handle_policy_snapshot") as Dictionary
	if not bool(snapshot.get("handle_chosen", false)):
		rename_policy_label.text = "Choose your first call sign. Letters, numbers, underscore. Founder and offensive names are reserved."
		return
	if bool(snapshot.get("handle_locked", false)):
		rename_policy_label.text = "Call sign changes are locked for this account."
		return
	if bool(snapshot.get("free_change_available", false)):
		rename_policy_label.text = "One free Call Sign change is available this calendar year. Honey renames cannot bypass reserved or prohibited names."
		return
	rename_policy_label.text = "One free Call Sign change is available per calendar year. Next free change: %s. Additional changes require Honey." % _format_policy_date(int(snapshot.get("next_free_change_unix", 0)))

func _build_report_category_options() -> void:
	if report_category_option == null:
		return
	report_category_option.clear()
	for category in REPORT_CATEGORY_OPTIONS:
		report_category_option.add_item(_category_label(category))
		report_category_option.set_item_metadata(report_category_option.get_item_count() - 1, category)

func _category_label(category: String) -> String:
	var clean: String = category.strip_edges().replace("_", " ")
	return clean.capitalize()

func _on_community_safety_pressed() -> void:
	_refresh_community_safety_dialog()
	community_safety_dialog.popup_centered_ratio(0.86)
	report_target_input.call_deferred("grab_focus")

func _restore_community_safety_focus() -> void:
	if community_safety_button != null and community_safety_button.is_visible_in_tree():
		community_safety_button.call_deferred("grab_focus")

func _refresh_community_safety_dialog(status_message: String = "") -> void:
	var public_identity: Dictionary = {}
	if ProfileManager.has_method("get_public_identity_snapshot"):
		public_identity = ProfileManager.call("get_public_identity_snapshot") as Dictionary
	var private_snapshot: Dictionary = {}
	if ProfileManager.has_method("get_private_profile_snapshot"):
		private_snapshot = ProfileManager.call("get_private_profile_snapshot") as Dictionary
	var moderation_snapshot: Dictionary = {}
	var moderation_state: Node = get_node_or_null("/root/ModerationState")
	if moderation_state != null and moderation_state.has_method("get_snapshot"):
		moderation_snapshot = moderation_state.call("get_snapshot") as Dictionary
	var policy: Dictionary = private_snapshot.get("handle_policy", {}) as Dictionary
	var privacy_posture: Dictionary = private_snapshot.get("privacy_posture", {}) as Dictionary
	var report_count: int = (moderation_snapshot.get("reports_by_id", {}) as Dictionary).size() if typeof(moderation_snapshot.get("reports_by_id", {})) == TYPE_DICTIONARY else 0
	var action_count: int = (moderation_snapshot.get("actions_by_id", {}) as Dictionary).size() if typeof(moderation_snapshot.get("actions_by_id", {})) == TYPE_DICTIONARY else 0
	var appeal_count: int = (moderation_snapshot.get("appeals_by_id", {}) as Dictionary).size() if typeof(moderation_snapshot.get("appeals_by_id", {})) == TYPE_DICTIONARY else 0
	safety_overview.text = "Public ID: %s\nCall Sign: %s\nFree Call Sign used this year: %s\nForced rename required: %s\nPublic financial identity: %s\nReports: %d | Actions: %d | Appeals: %d" % [
		str(public_identity.get("public_player_id", "")),
		str(public_identity.get("call_sign", "")),
		"yes" if bool(policy.get("free_change_used_this_year", false)) else "no",
		"yes" if bool(policy.get("forced_rename_required", false)) else "no",
		"yes" if bool(privacy_posture.get("public_identity_includes_financial_identity", false)) else "no",
		report_count,
		action_count,
		appeal_count
	]
	safety_status_label.text = status_message
	community_safety_status_label.text = status_message

func _on_submit_report_pressed() -> void:
	var moderation_state: Node = get_node_or_null("/root/ModerationState")
	if moderation_state == null or not moderation_state.has_method("submit_report"):
		_refresh_community_safety_dialog("Reporting is unavailable.")
		return
	var target_id: String = report_target_input.text.strip_edges()
	var summary: String = report_summary_input.text.strip_edges()
	var category: String = _selected_report_category()
	var reporter_id: String = ProfileManager.get_user_id()
	var result: Dictionary = moderation_state.call("submit_report", reporter_id, _target_type_for_category(category), target_id, category, summary, {"surface": "dash_settings"}) as Dictionary
	if bool(result.get("ok", false)):
		var report: Dictionary = result.get("report", {}) as Dictionary
		report_summary_input.text = ""
		_refresh_community_safety_dialog("Report submitted: %s" % str(report.get("report_id", "")))
	else:
		_refresh_community_safety_dialog(str(result.get("reason", "Report rejected.")))

func _on_submit_appeal_pressed() -> void:
	var moderation_state: Node = get_node_or_null("/root/ModerationState")
	if moderation_state == null or not moderation_state.has_method("submit_appeal"):
		_refresh_community_safety_dialog("Appeals are unavailable.")
		return
	var action_id: String = appeal_action_input.text.strip_edges()
	var statement: String = appeal_statement_input.text.strip_edges()
	var player_id: String = ProfileManager.get_user_id()
	var result: Dictionary = moderation_state.call("submit_appeal", action_id, player_id, statement) as Dictionary
	if bool(result.get("ok", false)):
		var appeal: Dictionary = result.get("appeal", {}) as Dictionary
		appeal_statement_input.text = ""
		_refresh_community_safety_dialog("Appeal submitted: %s" % str(appeal.get("appeal_id", "")))
	else:
		_refresh_community_safety_dialog(str(result.get("reason", "Appeal rejected.")))

func _selected_report_category() -> String:
	var selected: int = report_category_option.get_selected_id()
	if selected < 0:
		selected = report_category_option.selected
	var metadata: Variant = report_category_option.get_item_metadata(selected) if selected >= 0 and selected < report_category_option.get_item_count() else ""
	var category: String = str(metadata).strip_edges()
	return "other" if category.is_empty() else category

func _target_type_for_category(category: String) -> String:
	match category.strip_edges().to_lower():
		"hive":
			return "hive"
		"match":
			return "match"
		"chat":
			return "message"
		_:
			return "player"

func _format_policy_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "not scheduled"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0))]

func _refresh_user_id() -> void:
	var uid: String = ProfileManager.get_entap_id() if ProfileManager.has_method("get_entap_id") else ""
	current_user_id_label.text = "ENTaP ID: %s" % uid
	if DEV_ALLOW_UID_EDIT:
		user_id_input.text = ProfileManager.get_user_id()
	user_id_status_label.text = ""

func _refresh_gpu_vfx() -> void:
	var enabled: bool = ProfileManager.is_gpu_vfx_enabled()
	gpu_vfx_toggle.set_pressed_no_signal(enabled)
	gpu_vfx_toggle.text = "ON" if enabled else "OFF"

func _refresh_audio_settings() -> void:
	var audio_enabled: bool = true
	var sfx_enabled: bool = true
	var haptics_enabled: bool = true
	if ProfileManager.has_method("is_audio_enabled"):
		audio_enabled = bool(ProfileManager.call("is_audio_enabled"))
	if ProfileManager.has_method("is_sfx_enabled"):
		sfx_enabled = bool(ProfileManager.call("is_sfx_enabled"))
	if ProfileManager.has_method("is_haptics_enabled"):
		haptics_enabled = bool(ProfileManager.call("is_haptics_enabled"))
	master_audio_toggle.set_pressed_no_signal(audio_enabled)
	sfx_toggle.set_pressed_no_signal(sfx_enabled)
	haptics_toggle.set_pressed_no_signal(haptics_enabled)
	master_audio_toggle.text = "ON" if audio_enabled else "OFF"
	sfx_toggle.text = "ON" if sfx_enabled else "OFF"
	haptics_toggle.text = "ON" if haptics_enabled else "OFF"

func _refresh_performance_settings() -> void:
	var perf_mode: String = PERF_MODE_QUALITY
	var floor_enabled: bool = true
	if ProfileManager.has_method("get_performance_mode"):
		perf_mode = str(ProfileManager.call("get_performance_mode"))
	if ProfileManager.has_method("is_floor_graphics_enabled"):
		floor_enabled = bool(ProfileManager.call("is_floor_graphics_enabled"))
	_select_performance_mode(perf_mode)
	floor_graphics_toggle.set_pressed_no_signal(floor_enabled)
	floor_graphics_toggle.text = "ON" if floor_enabled else "OFF"

func _build_performance_options() -> void:
	performance_mode_option.clear()
	performance_mode_option.add_item("Quality")
	performance_mode_option.set_item_metadata(0, PERF_MODE_QUALITY)
	performance_mode_option.add_item("Balanced")
	performance_mode_option.set_item_metadata(1, PERF_MODE_BALANCED)
	performance_mode_option.add_item("Performance")
	performance_mode_option.set_item_metadata(2, PERF_MODE_PERFORMANCE)

func _select_performance_mode(mode: String) -> void:
	var target: String = mode.strip_edges().to_lower()
	var selected_index: int = 0
	for index in range(performance_mode_option.get_item_count()):
		var metadata: Variant = performance_mode_option.get_item_metadata(index)
		var value: String = str(metadata)
		if value == target:
			selected_index = index
			break
	performance_mode_option.select(selected_index)

func _apply_master_audio_setting() -> void:
	var enabled: bool = true
	if ProfileManager.has_method("is_audio_enabled"):
		enabled = bool(ProfileManager.call("is_audio_enabled"))
	var bus_index: int = 0
	if bus_index >= 0 and bus_index < AudioServer.get_bus_count():
		AudioServer.set_bus_mute(bus_index, not enabled)

func _apply_performance_mode_setting() -> void:
	if not ProfileManager.has_method("get_content_scale_factor"):
		return
	var scale_factor: float = float(ProfileManager.call("get_content_scale_factor"))
	var window_ref: Window = get_window()
	if window_ref != null:
		window_ref.content_scale_factor = clampf(scale_factor, 0.7, 1.1)

func _set_uid_edit_enabled(enabled: bool) -> void:
	user_id_input.visible = enabled
	set_user_id_button.visible = enabled
	user_id_input.editable = enabled

func _disable_legacy_profile_controls() -> void:
	profile_dropdown.disabled = true
	buttons_row.visible = false
	new_button.disabled = true
	rename_button.disabled = true
	delete_button.disabled = true

func _on_profile_selected(index: int) -> void:
	var metadata: Variant = profile_dropdown.get_item_metadata(index)
	var profile_id: String = str(metadata)
	ProfileManager.set_active_profile(profile_id)
	_refresh_options()

func _on_new_profile_pressed() -> void:
	ProfileManager.create_profile()
	_refresh_options()

func _on_rename_pressed() -> void:
	var active: Dictionary = ProfileManager.get_active_profile()
	var handle: String = str(active.get("handle", ""))
	rename_input.text = handle
	rename_input.select_all()
	rename_dialog.popup_centered()

func _on_rename_confirmed() -> void:
	var new_handle: String = rename_input.text.strip_edges()
	if new_handle.length() < MIN_HANDLE_LEN or new_handle.length() > MAX_HANDLE_LEN:
		_refresh_options()
		return
	var active_id: String = ProfileManager.get_active_profile_id()
	var ok: bool = ProfileManager.rename_profile(active_id, new_handle)
	if not ok:
		_refresh_rename_policy("Handle change rejected. Check the policy text below.")
	_refresh_options()

func _on_delete_pressed() -> void:
	var active_id: String = ProfileManager.get_active_profile_id()
	ProfileManager.delete_profile(active_id)
	_refresh_options()

func _on_display_name_submitted(_text: String) -> void:
	_apply_display_name()

func _apply_display_name() -> void:
	var attempted: String = display_name_input.text
	var result: Dictionary = ProfileManager.request_handle_change(attempted, false, "settings")
	var updated_name: String = ProfileManager.get_display_name()
	display_name_input.text = updated_name
	if bool(result.get("ok", false)):
		_refresh_rename_policy()
	else:
		_refresh_rename_policy(str(result.get("message", "Handle change rejected.")))
	_refresh_options()

func _on_set_user_id_pressed() -> void:
	if not DEV_ALLOW_UID_EDIT:
		return
	var attempted: String = user_id_input.text
	var ok: bool = ProfileManager.set_user_id(attempted)
	SFLog.info("UI_PROFILE_UID_SET_CLICK", {"ok": ok, "attempted": attempted})
	if ok:
		var uid: String = ProfileManager.get_user_id()
		current_user_id_label.text = "Internal ID: %s" % uid
		user_id_input.text = uid
		user_id_status_label.text = "Saved."
	else:
		user_id_status_label.text = "Invalid. Use UUIDv7 format."

func _on_copy_user_id_pressed() -> void:
	var entap_id: String = ProfileManager.get_entap_id() if ProfileManager.has_method("get_entap_id") else ""
	DisplayServer.clipboard_set(entap_id)
	SFLog.info("PROFILE_ENTAP_ID_COPIED", {"entap_id": entap_id})
	user_id_status_label.text = "Copied."

func _on_support_diagnostics_pressed() -> void:
	var scene: PackedScene = load("res://scenes/ui/SupportDiagnosticsPanel.tscn") as PackedScene
	if scene == null:
		user_id_status_label.text = "Diagnostics unavailable."
		return
	var panel: Control = scene.instantiate() as Control
	if panel == null:
		user_id_status_label.text = "Diagnostics unavailable."
		return
	get_tree().root.add_child(panel)
	user_id_status_label.text = "Diagnostics opened."

func _on_gpu_vfx_toggled(enabled: bool) -> void:
	ProfileManager.set_gpu_vfx_enabled(enabled)
	gpu_vfx_toggle.text = "ON" if enabled else "OFF"
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var arena_any: Node = tree.get_first_node_in_group("Arena")
	if arena_any != null and arena_any.has_method("set_gpu_vfx_enabled"):
		arena_any.call("set_gpu_vfx_enabled", enabled)

func _on_master_audio_toggled(enabled: bool) -> void:
	if ProfileManager.has_method("set_audio_enabled"):
		ProfileManager.call("set_audio_enabled", enabled)
	master_audio_toggle.text = "ON" if enabled else "OFF"
	_apply_master_audio_setting()

func _on_sfx_toggled(enabled: bool) -> void:
	if ProfileManager.has_method("set_sfx_enabled"):
		ProfileManager.call("set_sfx_enabled", enabled)
	sfx_toggle.text = "ON" if enabled else "OFF"

func _on_haptics_toggled(enabled: bool) -> void:
	if ProfileManager.has_method("set_haptics_enabled"):
		ProfileManager.call("set_haptics_enabled", enabled)
	haptics_toggle.text = "ON" if enabled else "OFF"

func _on_performance_mode_selected(index: int) -> void:
	var metadata: Variant = performance_mode_option.get_item_metadata(index)
	var mode: String = str(metadata)
	if ProfileManager.has_method("set_performance_mode"):
		ProfileManager.call("set_performance_mode", mode)
	_apply_performance_mode_setting()

func _on_floor_graphics_toggled(enabled: bool) -> void:
	if ProfileManager.has_method("set_floor_graphics_enabled"):
		ProfileManager.call("set_floor_graphics_enabled", enabled)
	floor_graphics_toggle.text = "ON" if enabled else "OFF"
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var arena_any: Node = tree.get_first_node_in_group("Arena")
	if arena_any != null and arena_any.has_method("set_floor_graphics_enabled"):
		arena_any.call("set_floor_graphics_enabled", enabled)

func _refresh_admin_tools() -> void:
	admin_section.visible = false
	admin_open_button.visible = false
	admin_open_button.disabled = true
	admin_status_label.visible = false

func _refresh_admin_credentials() -> void:
	var username: String = ADMIN_DASHBOARD_USERNAME_DEFAULT
	var password: String = ADMIN_DASHBOARD_PASSWORD_DEFAULT
	if ProfileManager.has_method("get_admin_dashboard_username"):
		username = str(ProfileManager.call("get_admin_dashboard_username"))
	if ProfileManager.has_method("get_admin_dashboard_password"):
		password = str(ProfileManager.call("get_admin_dashboard_password"))
	admin_username_input.text = username
	admin_password_input.text = password

func _persist_admin_credentials() -> void:
	if not ProfileManager.has_method("set_admin_dashboard_credentials"):
		return
	var username: String = admin_username_input.text.strip_edges()
	var password: String = admin_password_input.text
	ProfileManager.call("set_admin_dashboard_credentials", username, password)

func _build_auth_dashboard_url(base_url: String, username: String, password: String) -> String:
	var clean_username: String = username.strip_edges()
	if clean_username == "" or password == "":
		return base_url
	var scheme_sep_index: int = base_url.find("://")
	if scheme_sep_index < 0:
		return base_url
	var scheme_prefix: String = base_url.substr(0, scheme_sep_index + 3)
	var remainder: String = base_url.substr(scheme_sep_index + 3, base_url.length() - (scheme_sep_index + 3))
	var slash_index: int = remainder.find("/")
	var authority: String = remainder if slash_index < 0 else remainder.substr(0, slash_index)
	var suffix: String = "" if slash_index < 0 else remainder.substr(slash_index, remainder.length() - slash_index)
	var at_index: int = authority.rfind("@")
	if at_index >= 0:
		authority = authority.substr(at_index + 1, authority.length() - (at_index + 1))
	var credential_block: String = "%s:%s@" % [clean_username.uri_encode(), password.uri_encode()]
	return scheme_prefix + credential_block + authority + suffix

func _on_admin_open_pressed() -> void:
	var enabled: bool = OS.is_debug_build() or admin_tools_enabled_in_release
	if not enabled:
		admin_status_label.text = "Admin tools disabled in this build."
		return
	var url: String = admin_dashboard_url.strip_edges()
	if url == "":
		admin_status_label.text = "Dashboard URL missing."
		return
	_persist_admin_credentials()
	var username: String = admin_username_input.text.strip_edges()
	var password: String = admin_password_input.text
	var open_url: String = _build_auth_dashboard_url(url, username, password)
	var err: Error = OS.shell_open(open_url)
	if err == OK:
		if username == "" or password == "":
			admin_status_label.text = "Opened dashboard. Browser prompt expected (missing saved credentials)."
		else:
			admin_status_label.text = "Opened dashboard with saved credentials."
	else:
		admin_status_label.text = "Failed to open dashboard (%d)." % int(err)

func _on_admin_credentials_submitted(_text: String) -> void:
	_persist_admin_credentials()
	admin_status_label.text = "Admin credentials saved."

func _on_admin_credentials_focus_exited() -> void:
	_persist_admin_credentials()

func _apply_readability_layout() -> void:
	_load_fonts()
	var root_vbox: VBoxContainer = get_node("VBox") as VBoxContainer
	_ensure_scroll_layout(root_vbox)
	if root_vbox != null:
		root_vbox.custom_minimum_size = Vector2(root_vbox.custom_minimum_size.x, 0.0)
		root_vbox.add_theme_constant_override("separation", 24)
	for node_any in find_children("*", "VBoxContainer", true, false):
		var vbox: VBoxContainer = node_any as VBoxContainer
		if vbox == null or vbox == root_vbox:
			continue
		vbox.add_theme_constant_override("separation", 16)
	for node_any in find_children("*", "HBoxContainer", true, false):
		var hbox: HBoxContainer = node_any as HBoxContainer
		if hbox == null:
			continue
		hbox.add_theme_constant_override("separation", 16)
	for node_any in find_children("*", "Label", true, false):
		var label: Label = node_any as Label
		if label == null:
			continue
		UITypography.apply_token(label, _font_regular, "body", UITypography.PORTRAIT_CANVAS_SCALE)
	for node_any in find_children("*", "Button", true, false):
		var button: Button = node_any as Button
		if button == null:
			continue
		UITypography.apply_button_token(button, _font_regular, "button", UITypography.PORTRAIT_CANVAS_SCALE, SETTINGS_CONTROL_HEIGHT)
	for node_any in find_children("*", "CheckButton", true, false):
		var toggle: CheckButton = node_any as CheckButton
		if toggle == null:
			continue
		_style_settings_toggle(toggle)
	for node_any in find_children("*", "OptionButton", true, false):
		var option: OptionButton = node_any as OptionButton
		if option == null:
			continue
		UITypography.apply_button_token(option, _font_regular, "button", UITypography.PORTRAIT_CANVAS_SCALE, SETTINGS_CONTROL_HEIGHT)
	for node_any in find_children("*", "LineEdit", true, false):
		var line_edit: LineEdit = node_any as LineEdit
		if line_edit == null:
			continue
		UITypography.apply_token(line_edit, _font_regular, "body", UITypography.PORTRAIT_CANVAS_SCALE)
		_set_control_min_height(line_edit, SETTINGS_CONTROL_HEIGHT)
	for node_any in find_children("*", "TextEdit", true, false):
		var text_edit: TextEdit = node_any as TextEdit
		if text_edit == null:
			continue
		UITypography.apply_token(text_edit, _font_regular, "body", UITypography.PORTRAIT_CANVAS_SCALE)
		_set_control_min_height(text_edit, SETTINGS_TEXT_EDIT_HEIGHT)
	if root_vbox != null:
		var header_label: Label = root_vbox.get_node_or_null("Header") as Label
		if header_label != null:
			UITypography.apply_token(header_label, _font_semibold, "panel_title", UITypography.PORTRAIT_CANVAS_SCALE)
	var section_title_paths: Array[String] = [
		"ProfileRow/ProfileLabel",
		"UserIdSection/UserIdLabel",
		"VideoSection/VideoLabel",
		"AudioSection/AudioLabel",
		"PerformanceSection/PerformanceLabel",
		"SupportSection/SupportLabel",
		"CommunitySafetySection/CommunitySafetyLabel"
	]
	for section_path in section_title_paths:
		if root_vbox == null or not root_vbox.has_node(section_path):
			continue
		var section_label: Label = root_vbox.get_node(section_path) as Label
		UITypography.apply_token(section_label, _font_semibold, "section_title", UITypography.PORTRAIT_CANVAS_SCALE)
	display_name_input.placeholder_text = "Call sign"
	current_user_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_user_id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_id_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	admin_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rename_policy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	community_safety_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety_overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safety_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var safety_close_button: Button = community_safety_dialog.get_ok_button()
	if safety_close_button != null:
		safety_close_button.text = "CLOSE"
		UITypography.apply_button_token(safety_close_button, _font_regular, "button", UITypography.PORTRAIT_CANVAS_SCALE, SETTINGS_CONTROL_HEIGHT)

func _style_settings_toggle(toggle: CheckButton) -> void:
	if toggle == null:
		return
	UITypography.apply_button_token(toggle, _font_regular, "button", UITypography.PORTRAIT_CANVAS_SCALE, SETTINGS_TOGGLE_HEIGHT)
	toggle.custom_minimum_size.x = maxf(toggle.custom_minimum_size.x, SETTINGS_TOGGLE_WIDTH)
	toggle.add_theme_icon_override("checked", TOGGLE_ON_TEXTURE)
	toggle.add_theme_icon_override("unchecked", TOGGLE_OFF_TEXTURE)
	toggle.add_theme_icon_override("checked_disabled", TOGGLE_ON_DISABLED_TEXTURE)
	toggle.add_theme_icon_override("unchecked_disabled", TOGGLE_OFF_DISABLED_TEXTURE)
	toggle.add_theme_constant_override("h_separation", SETTINGS_TOGGLE_TEXT_GAP)
	toggle.add_theme_constant_override("check_v_offset", 0)

func _build_category_tabs() -> void:
	if _category_tabs != null and is_instance_valid(_category_tabs):
		return
	var scroll: ScrollContainer = get_node_or_null("SettingsScroll") as ScrollContainer
	if scroll == null:
		return
	_category_tabs = HBoxContainer.new()
	_category_tabs.name = "SettingsCategoryTabs"
	_category_tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_category_tabs.offset_left = 0.0
	_category_tabs.offset_top = 0.0
	_category_tabs.offset_right = 0.0
	_category_tabs.offset_bottom = SETTINGS_CATEGORY_BAR_HEIGHT
	_category_tabs.add_theme_constant_override("separation", 12)
	add_child(_category_tabs)
	move_child(_category_tabs, scroll.get_index())
	scroll.offset_top = SETTINGS_CATEGORY_BAR_HEIGHT + SETTINGS_CATEGORY_GAP
	for category_data in [
		{ "id": CATEGORY_ACCOUNT, "label": "ACCOUNT" },
		{ "id": CATEGORY_AUDIO, "label": "AUDIO" },
		{ "id": CATEGORY_GRAPHICS, "label": "GRAPHICS" },
		{ "id": CATEGORY_SUPPORT, "label": "SUPPORT" }
	]:
		var category_id: String = str(category_data.get("id", ""))
		var button := Button.new()
		button.name = "%sTab" % category_id.capitalize()
		button.text = str(category_data.get("label", category_id.to_upper()))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, SETTINGS_CATEGORY_BAR_HEIGHT)
		UITypography.apply_button_token(button, _font_semibold, "compact_button", UITypography.PORTRAIT_CANVAS_SCALE, SETTINGS_CATEGORY_BAR_HEIGHT)
		button.pressed.connect(Callable(self, "_set_active_category").bind(category_id))
		_category_tabs.add_child(button)
		_category_buttons[category_id] = button

func _set_active_category(category_id: String) -> void:
	if not [CATEGORY_ACCOUNT, CATEGORY_AUDIO, CATEGORY_GRAPHICS, CATEGORY_SUPPORT].has(category_id):
		category_id = CATEGORY_ACCOUNT
	_active_category = category_id
	var root_vbox: VBoxContainer = get_node_or_null("SettingsScroll/VBox") as VBoxContainer
	if root_vbox == null:
		return
	var header: Label = root_vbox.get_node_or_null("Header") as Label
	if header != null:
		header.text = category_id.to_upper()
	_set_section_visible(root_vbox, "ProfileRow", category_id == CATEGORY_ACCOUNT)
	_set_section_visible(root_vbox, "UserIdSection", category_id == CATEGORY_ACCOUNT)
	_set_section_visible(root_vbox, "RenamePolicyLabel", category_id == CATEGORY_ACCOUNT)
	_set_section_visible(root_vbox, "AudioSection", category_id == CATEGORY_AUDIO)
	_set_section_visible(root_vbox, "VideoSection", category_id == CATEGORY_GRAPHICS)
	_set_section_visible(root_vbox, "PerformanceSection", category_id == CATEGORY_GRAPHICS)
	_set_section_visible(root_vbox, "SupportSection", category_id == CATEGORY_SUPPORT)
	_set_section_visible(root_vbox, "CommunitySafetySection", category_id == CATEGORY_SUPPORT)
	_set_section_visible(root_vbox, "AdminSection", false)
	_set_section_visible(root_vbox, "ButtonsRow", false)
	profile_dropdown.visible = false
	for button_id in _category_buttons.keys():
		var button: Button = _category_buttons.get(button_id, null) as Button
		if button == null:
			continue
		var selected: bool = str(button_id) == category_id
		button.button_pressed = selected
		_style_category_button(button, selected)
	var scroll: ScrollContainer = get_node_or_null("SettingsScroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0

func _set_section_visible(root_vbox: VBoxContainer, path: String, visible: bool) -> void:
	var control: Control = root_vbox.get_node_or_null(path) as Control
	if control != null:
		control.visible = visible

func _style_category_button(button: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.25, 0.16, 0.98) if selected else Color(0.08, 0.09, 0.12, 0.98)
	style.border_color = Color(0.93, 0.67, 0.18, 0.95) if selected else Color(0.34, 0.36, 0.44, 0.82)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style.duplicate())
	button.add_theme_stylebox_override("pressed", style.duplicate())
	button.add_theme_stylebox_override("focus", style.duplicate())
	button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80, 1.0) if selected else Color(0.91, 0.92, 0.96, 1.0))

func focus_default_control() -> void:
	var button: Button = _category_buttons.get(_active_category, null) as Button
	if button != null and button.is_visible_in_tree():
		button.grab_focus()

func prepare_for_open() -> void:
	display_name_input.text = ProfileManager.get_display_name()
	_set_active_category(CATEGORY_ACCOUNT)

func _ensure_scroll_layout(root_vbox: VBoxContainer) -> void:
	if root_vbox == null:
		return
	var scroll: ScrollContainer = get_node_or_null("SettingsScroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "SettingsScroll"
		add_child(scroll)
		move_child(scroll, 0)
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if root_vbox.get_parent() != scroll:
		var old_parent: Node = root_vbox.get_parent()
		if old_parent != null:
			old_parent.remove_child(root_vbox)
		scroll.add_child(root_vbox)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _load_fonts() -> void:
	_font_regular = UITypography.regular_font()
	_font_semibold = UITypography.semibold_font()

func _set_control_min_height(control: Control, min_height: float) -> void:
	if control == null:
		return
	control.custom_minimum_size = Vector2(control.custom_minimum_size.x, maxf(control.custom_minimum_size.y, min_height))
