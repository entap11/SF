class_name ProfileSettingsPanel
extends Control

const SFLog = preload("res://scripts/util/sf_log.gd")

const MIN_HANDLE_LEN: int = 3
const MAX_HANDLE_LEN: int = 20
const DEV_ALLOW_UID_EDIT: bool = false

@onready var profile_dropdown: OptionButton = $VBox/ProfileRow/ProfileDropdown
@onready var display_name_input: LineEdit = $VBox/ProfileRow/DisplayNameInput
@onready var current_user_id_label: Label = $VBox/UserIdSection/UserIdCurrentRow/CurrentUserIdLabel
@onready var copy_user_id_button: Button = $VBox/UserIdSection/UserIdCurrentRow/CopyUserIdButton
@onready var user_id_input: LineEdit = $VBox/UserIdSection/UserIdRow/UserIdInput
@onready var set_user_id_button: Button = $VBox/UserIdSection/UserIdRow/SetUserIdButton
@onready var user_id_status_label: Label = $VBox/UserIdSection/UserIdStatusLabel
@onready var gpu_vfx_toggle: CheckButton = $VBox/VideoSection/GpuVfxRow/GpuVfxToggle
@onready var buttons_row: HBoxContainer = $VBox/ButtonsRow
@onready var new_button: Button = $VBox/ButtonsRow/NewProfileButton
@onready var rename_button: Button = $VBox/ButtonsRow/RenameButton
@onready var delete_button: Button = $VBox/ButtonsRow/DeleteButton
@onready var rename_dialog: AcceptDialog = $RenameDialog
@onready var rename_input: LineEdit = $RenameDialog/RenameInput

func _ready() -> void:
	ProfileManager.ensure_loaded()
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
	_disable_legacy_profile_controls()
	_set_uid_edit_enabled(DEV_ALLOW_UID_EDIT)
	_refresh_options()
	_refresh_display_name()
	_refresh_user_id()
	_refresh_gpu_vfx()

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
