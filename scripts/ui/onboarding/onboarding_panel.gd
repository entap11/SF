class_name OnboardingPanel
extends Control

signal onboarding_done

const SFLog = preload("res://scripts/util/sf_log.gd")

@onready var uid_value_label: Label = $VBox/UidRow/UidValueLabel
@onready var display_name_input: LineEdit = $VBox/DisplayNameInput
@onready var copy_uid_button: Button = $VBox/UidRow/CopyUidButton
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
	ProfileManager.ensure_loaded()
	uid_value_label.text = ProfileManager.get_user_id()
	display_name_input.text = ProfileManager.get_display_name()
	copy_uid_button.pressed.connect(_on_copy_uid_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	display_name_input.text_changed.connect(func(_text: String) -> void:
		continue_button.text = "Continue"
	)

func _on_copy_uid_pressed() -> void:
	DisplayServer.clipboard_set(ProfileManager.get_user_id())
	SFLog.info("PROFILE_UID_COPIED", {"user_id": ProfileManager.get_user_id()})

func _on_continue_pressed() -> void:
	var result: Dictionary = ProfileManager.request_handle_change(display_name_input.text, false, "onboarding")
	if not bool(result.get("ok", false)):
		continue_button.text = str(result.get("message", "Choose a valid handle."))
		return
	ProfileManager.mark_onboarding_complete()
	onboarding_done.emit()
