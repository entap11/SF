class_name OnboardingPanel
extends Control

signal onboarding_done

const SFLog = preload("res://scripts/util/sf_log.gd")
const UITypography = preload("res://scripts/ui/ui_typography.gd")

const TITLE_FONT_SIZE: int = 42
const BODY_FONT_SIZE: int = 36
const UID_FONT_SIZE: int = 28
const INPUT_FONT_SIZE: int = 42
const BUTTON_FONT_SIZE: int = 36
const ROW_HEIGHT: float = 76.0

@onready var title_label: Label = $VBox/TitleLabel
@onready var uid_label: Label = $VBox/UidRow/UidLabel
@onready var uid_value_label: Label = $VBox/UidRow/UidValueLabel
@onready var display_name_input: LineEdit = $VBox/DisplayNameInput
@onready var display_name_label: Label = $VBox/DisplayNameLabel
@onready var age_label: Label = $VBox/AgeLabel
@onready var age_spin: SpinBox = $VBox/AgeSpin
@onready var copy_uid_button: Button = $VBox/UidRow/CopyUidButton
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
	_apply_readable_first_run_type()
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
	_report_age_to_scholastic_state()
	ProfileManager.mark_onboarding_complete()
	onboarding_done.emit()

func _report_age_to_scholastic_state() -> void:
	var state_node: Node = get_node_or_null("/root/ScholasticState")
	if state_node == null or not state_node.has_method("intent_report_age"):
		return
	state_node.call("intent_report_age", ProfileManager.get_user_id(), int(age_spin.value), ProfileManager.get_display_name())

func _apply_readable_first_run_type() -> void:
	custom_minimum_size = Vector2(820.0, 560.0)
	var box: VBoxContainer = $VBox
	if box != null:
		box.add_theme_constant_override("separation", 18)
	_apply_font(title_label, UITypography.semibold_font(), TITLE_FONT_SIZE)
	_apply_font(uid_label, UITypography.regular_font(), BODY_FONT_SIZE)
	_apply_font(uid_value_label, UITypography.regular_font(), UID_FONT_SIZE)
	_apply_font(display_name_label, UITypography.semibold_font(), BODY_FONT_SIZE)
	_apply_font(display_name_input, UITypography.regular_font(), INPUT_FONT_SIZE)
	_apply_font(age_label, UITypography.semibold_font(), BODY_FONT_SIZE)
	_apply_font(age_spin, UITypography.regular_font(), INPUT_FONT_SIZE)
	_apply_font(copy_uid_button, UITypography.semibold_font(), BUTTON_FONT_SIZE)
	_apply_font(continue_button, UITypography.semibold_font(), BUTTON_FONT_SIZE)
	for control in [display_name_input, age_spin, copy_uid_button, continue_button]:
		if control is Control:
			(control as Control).custom_minimum_size.y = ROW_HEIGHT

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)
