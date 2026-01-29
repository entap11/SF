class_name ProfileSettingsPanel
extends Control

const MIN_HANDLE_LEN: int = 3
const MAX_HANDLE_LEN: int = 20

@onready var profile_dropdown: OptionButton = $VBox/ProfileRow/ProfileDropdown
@onready var new_button: Button = $VBox/ButtonsRow/NewProfileButton
@onready var rename_button: Button = $VBox/ButtonsRow/RenameButton
@onready var delete_button: Button = $VBox/ButtonsRow/DeleteButton
@onready var rename_dialog: AcceptDialog = $RenameDialog
@onready var rename_input: LineEdit = $RenameDialog/RenameInput

func _ready() -> void:
	profile_dropdown.item_selected.connect(_on_profile_selected)
	new_button.pressed.connect(_on_new_profile_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	_refresh_options()

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
