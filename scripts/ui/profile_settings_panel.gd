class_name ProfileSettingsPanel
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")

const MIN_HANDLE_LEN: int = 3
const MAX_HANDLE_LEN: int = 20
const DEV_ALLOW_UID_EDIT: bool = false
const PERF_MODE_QUALITY: String = "quality"
const PERF_MODE_BALANCED: String = "balanced"
const PERF_MODE_PERFORMANCE: String = "performance"
const POWERBAR_THEME_BASE: String = "base"
const POWERBAR_THEME_UPGRADED: String = "upgraded"
const POWERBAR_THEME_UPGRADED_DYNAMIC: String = "upgraded_dynamic"
const POWERBAR_THEME_UPGRADED_BOIL: String = "upgraded_boil"
const FONT_REGULAR_PATH: String = "res://assets/fonts/ChakraPetch-Regular.ttf"
const FONT_SEMIBOLD_PATH: String = "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const ADMIN_DASHBOARD_URL_DEFAULT: String = "http://127.0.0.1:8787/dashboard"
const ADMIN_DASHBOARD_USERNAME_DEFAULT: String = "Mattballou"
const ADMIN_DASHBOARD_PASSWORD_DEFAULT: String = "$warmFr0nt"

@onready var profile_dropdown: OptionButton = $VBox/ProfileRow/ProfileDropdown
@onready var display_name_input: LineEdit = $VBox/ProfileRow/DisplayNameInput
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
@onready var powerbar_theme_row: HBoxContainer = $VBox/AdminSection/PowerBarThemeRow
@onready var powerbar_theme_option: OptionButton = $VBox/AdminSection/PowerBarThemeRow/PowerBarThemeOption
@onready var admin_username_input: LineEdit = $VBox/AdminSection/AdminCredentialsRow/AdminUsernameInput
@onready var admin_password_input: LineEdit = $VBox/AdminSection/AdminCredentialsRow/AdminPasswordInput
@onready var admin_status_label: Label = $VBox/AdminSection/AdminStatusLabel
@onready var rename_policy_label: Label = $VBox/RenamePolicyLabel
@onready var buttons_row: HBoxContainer = $VBox/ButtonsRow
@onready var new_button: Button = $VBox/ButtonsRow/NewProfileButton
@onready var rename_button: Button = $VBox/ButtonsRow/RenameButton
@onready var delete_button: Button = $VBox/ButtonsRow/DeleteButton
@onready var rename_dialog: AcceptDialog = $RenameDialog
@onready var rename_input: LineEdit = $RenameDialog/RenameInput
@export var admin_dashboard_url: String = ADMIN_DASHBOARD_URL_DEFAULT
@export var admin_tools_enabled_in_release: bool = false
var _font_regular: Font = null
var _font_semibold: Font = null

func _ready() -> void:
	ProfileManager.ensure_loaded()
	_apply_readability_layout()
	profile_dropdown.item_selected.connect(_on_profile_selected)
	new_button.pressed.connect(_on_new_profile_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	display_name_input.text_submitted.connect(_on_display_name_submitted)
	display_name_input.focus_exited.connect(_on_display_name_focus_exited)
	set_user_id_button.pressed.connect(_on_set_user_id_pressed)
	copy_user_id_button.pressed.connect(_on_copy_user_id_pressed)
	gpu_vfx_toggle.toggled.connect(_on_gpu_vfx_toggled)
	master_audio_toggle.toggled.connect(_on_master_audio_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	haptics_toggle.toggled.connect(_on_haptics_toggled)
	performance_mode_option.item_selected.connect(_on_performance_mode_selected)
	floor_graphics_toggle.toggled.connect(_on_floor_graphics_toggled)
	admin_username_input.text_submitted.connect(_on_admin_credentials_submitted)
	admin_password_input.text_submitted.connect(_on_admin_credentials_submitted)
	admin_username_input.focus_exited.connect(_on_admin_credentials_focus_exited)
	admin_password_input.focus_exited.connect(_on_admin_credentials_focus_exited)
	admin_open_button.pressed.connect(_on_admin_open_pressed)
	powerbar_theme_option.item_selected.connect(_on_powerbar_theme_selected)
	_disable_legacy_profile_controls()
	_set_uid_edit_enabled(DEV_ALLOW_UID_EDIT)
	_refresh_admin_credentials()
	_refresh_admin_tools()
	_build_performance_options()
	_build_powerbar_theme_options()
	_refresh_options()
	_refresh_display_name()
	_refresh_user_id()
	_refresh_gpu_vfx()
	_refresh_audio_settings()
	_refresh_performance_settings()
	_refresh_powerbar_theme_setting()
	_apply_master_audio_setting()
	_apply_performance_mode_setting()

func _refresh_options() -> void:
	var profiles: Array[Dictionary] = ProfileManager.get_profiles()
	var active_id: String = ProfileManager.get_active_profile_id()
	profile_dropdown.clear()
	var active_index: int = 0
	for i in range(profiles.size()):
		var profile: Dictionary = profiles[i]
		var handle: String = str(profile.get("handle", ""))
		var pid: String = str(profile.get("profile_id", ""))
		var label: String = handle
		if pid.length() >= 4:
			label = "%s (%s)" % [handle, pid.substr(pid.length() - 4, 4)]
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

func _refresh_user_id() -> void:
	var uid: String = ProfileManager.get_user_id()
	current_user_id_label.text = "Current: %s" % uid
	if DEV_ALLOW_UID_EDIT:
		user_id_input.text = uid
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

func _build_powerbar_theme_options() -> void:
	powerbar_theme_option.clear()
	powerbar_theme_option.add_item("Base")
	powerbar_theme_option.set_item_metadata(0, POWERBAR_THEME_BASE)
	powerbar_theme_option.add_item("Upgraded (Static)")
	powerbar_theme_option.set_item_metadata(1, POWERBAR_THEME_UPGRADED)
	powerbar_theme_option.add_item("Upgraded II (Dynamic)")
	powerbar_theme_option.set_item_metadata(2, POWERBAR_THEME_UPGRADED_DYNAMIC)
	powerbar_theme_option.add_item("Boil Prototype")
	powerbar_theme_option.set_item_metadata(3, POWERBAR_THEME_UPGRADED_BOIL)

func _refresh_powerbar_theme_setting() -> void:
	if not ProfileManager.has_method("get_powerbar_theme"):
		return
	var target_theme: String = str(ProfileManager.call("get_powerbar_theme")).strip_edges().to_lower()
	var selected_index: int = 0
	for index in range(powerbar_theme_option.get_item_count()):
		var metadata: Variant = powerbar_theme_option.get_item_metadata(index)
		if str(metadata).strip_edges().to_lower() == target_theme:
			selected_index = index
			break
	powerbar_theme_option.select(selected_index)

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
		window_ref.content_scale_factor = clampf(scale_factor, 0.7, 1.0)

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
	ProfileManager.rename_profile(active_id, new_handle)
	_refresh_options()

func _on_delete_pressed() -> void:
	var active_id: String = ProfileManager.get_active_profile_id()
	ProfileManager.delete_profile(active_id)
	_refresh_options()

func _on_display_name_submitted(_text: String) -> void:
	_apply_display_name()

func _on_display_name_focus_exited() -> void:
	_apply_display_name()

func _apply_display_name() -> void:
	var current_name: String = ProfileManager.get_display_name()
	ProfileManager.set_display_name(display_name_input.text)
	var updated_name: String = ProfileManager.get_display_name()
	display_name_input.text = updated_name
	_refresh_options()

func _on_set_user_id_pressed() -> void:
	if not DEV_ALLOW_UID_EDIT:
		return
	var attempted: String = user_id_input.text
	var ok: bool = ProfileManager.set_user_id(attempted)
	SFLog.info("UI_PROFILE_UID_SET_CLICK", {"ok": ok, "attempted": attempted})
	if ok:
		var uid: String = ProfileManager.get_user_id()
		current_user_id_label.text = "Current: %s" % uid
		user_id_input.text = uid
		user_id_status_label.text = "Saved."
	else:
		user_id_status_label.text = "Invalid. Use u_ + 12 hex (example: u_001122aabbcc)."

func _on_copy_user_id_pressed() -> void:
	DisplayServer.clipboard_set(ProfileManager.get_user_id())
	SFLog.info("PROFILE_UID_COPIED", {"user_id": ProfileManager.get_user_id()})
	user_id_status_label.text = "Copied."

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
	var enabled: bool = OS.is_debug_build() or admin_tools_enabled_in_release
	admin_section.visible = enabled
	admin_open_button.visible = enabled
	admin_open_button.disabled = not enabled
	powerbar_theme_row.visible = enabled
	powerbar_theme_option.disabled = not enabled
	admin_status_label.visible = enabled
	admin_status_label.text = "Private admin dashboard. Use in-app credentials."

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

func _on_powerbar_theme_selected(index: int) -> void:
	if not ProfileManager.has_method("set_powerbar_theme"):
		return
	var metadata: Variant = powerbar_theme_option.get_item_metadata(index)
	var theme_id: String = str(metadata).strip_edges().to_lower()
	ProfileManager.call("set_powerbar_theme", theme_id)
	_refresh_powerbar_theme_setting()
	admin_status_label.text = "PowerBar theme set to %s." % theme_id

func _apply_readability_layout() -> void:
	_load_fonts()
	custom_minimum_size = Vector2(0.0, 760.0)
	var root_vbox: VBoxContainer = get_node("VBox") as VBoxContainer
	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 14)
	for node_any in find_children("*", "VBoxContainer", true, false):
		var vbox: VBoxContainer = node_any as VBoxContainer
		if vbox == null or vbox == root_vbox:
			continue
		vbox.add_theme_constant_override("separation", 8)
	for node_any in find_children("*", "HBoxContainer", true, false):
		var hbox: HBoxContainer = node_any as HBoxContainer
		if hbox == null:
			continue
		hbox.add_theme_constant_override("separation", 14)
	for node_any in find_children("*", "Label", true, false):
		var label: Label = node_any as Label
		if label == null:
			continue
		_apply_font(label, _font_regular, 16)
	for node_any in find_children("*", "Button", true, false):
		var button: Button = node_any as Button
		if button == null:
			continue
		_apply_font(button, _font_regular, 16)
		_set_control_min_height(button, 44.0)
	for node_any in find_children("*", "CheckButton", true, false):
		var toggle: CheckButton = node_any as CheckButton
		if toggle == null:
			continue
		_apply_font(toggle, _font_regular, 16)
		_set_control_min_height(toggle, 40.0)
	for node_any in find_children("*", "OptionButton", true, false):
		var option: OptionButton = node_any as OptionButton
		if option == null:
			continue
		_apply_font(option, _font_regular, 16)
		_set_control_min_height(option, 44.0)
	for node_any in find_children("*", "LineEdit", true, false):
		var line_edit: LineEdit = node_any as LineEdit
		if line_edit == null:
			continue
		_apply_font(line_edit, _font_regular, 16)
		_set_control_min_height(line_edit, 44.0)
	if has_node("VBox/Header"):
		var header_label: Label = get_node("VBox/Header") as Label
		_apply_font(header_label, _font_semibold, 26)
	var section_title_paths: Array[String] = [
		"VBox/ProfileRow/ProfileLabel",
		"VBox/UserIdSection/UserIdLabel",
		"VBox/VideoSection/VideoLabel",
		"VBox/AudioSection/AudioLabel",
		"VBox/PerformanceSection/PerformanceLabel",
		"VBox/AdminSection/AdminLabel"
	]
	for section_path in section_title_paths:
		if not has_node(section_path):
			continue
		var section_label: Label = get_node(section_path) as Label
		_apply_font(section_label, _font_semibold, 18)
	display_name_input.placeholder_text = "Display name"
	current_user_id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current_user_id_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_id_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	admin_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rename_policy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		var regular_any: Variant = load(FONT_REGULAR_PATH)
		if regular_any is Font:
			_font_regular = regular_any as Font
	if ResourceLoader.exists(FONT_SEMIBOLD_PATH):
		var semibold_any: Variant = load(FONT_SEMIBOLD_PATH)
		if semibold_any is Font:
			_font_semibold = semibold_any as Font

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null or font == null:
		return
	control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)

func _set_control_min_height(control: Control, min_height: float) -> void:
	if control == null:
		return
	control.custom_minimum_size = Vector2(control.custom_minimum_size.x, maxf(control.custom_minimum_size.y, min_height))
