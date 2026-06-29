class_name OnboardingPanel
extends Control

signal onboarding_done
signal onboarding_guide_prompt_requested

const UITypography = preload("res://scripts/ui/ui_typography.gd")

const TITLE_FONT_SIZE: int = 54
const BODY_FONT_SIZE: int = 44
const STATUS_FONT_SIZE: int = 34
const INPUT_FONT_SIZE: int = 52
const BUTTON_FONT_SIZE: int = 46
const ROW_HEIGHT: float = 94.0
const DEBUG_OFFLINE_PROFILE_ID: String = "018f2b2c-1234-7abc-8def-123456789abc"
const DEBUG_OFFLINE_ENTAP_ID: String = "SFP 501"

@onready var title_label: Label = $VBox/TitleLabel
@onready var body_label: Label = $VBox/BodyLabel
@onready var display_name_input: LineEdit = $VBox/DisplayNameInput
@onready var display_name_label: Label = $VBox/DisplayNameLabel
@onready var age_label: Label = $VBox/AgeLabel
@onready var age_input: LineEdit = $VBox/AgeSpin
@onready var status_label: Label = $VBox/StatusLabel
@onready var continue_button: Button = $VBox/ContinueButton

func _ready() -> void:
	_apply_readable_first_run_type()
	ProfileManager.ensure_loaded()
	display_name_input.text = _initial_handle_text()
	_configure_age_input()
	continue_button.pressed.connect(_on_continue_pressed)
	display_name_input.text_changed.connect(func(_text: String) -> void:
		status_label.text = ""
	)
	age_input.text_changed.connect(_on_age_text_changed)

func _on_continue_pressed() -> void:
	var call_sign: String = display_name_input.text.strip_edges()
	var validation: Dictionary = ProfileManager.validate_handle_policy(call_sign)
	if not bool(validation.get("ok", false)):
		status_label.text = _call_sign_validation_message(validation, "Choose a valid call sign.")
		return
	var age_years: int = _age_years_from_input()
	if age_years < 0:
		status_label.text = "Enter an age from 1 to 99."
		return
	var registration: Dictionary = _register_backend_identity(call_sign)
	if not bool(registration.get("ok", false)):
		status_label.text = _registration_error_message(registration)
		return
	var player: Dictionary = registration.get("player", {}) as Dictionary
	if not player.is_empty() and ProfileManager.has_method("apply_backend_identity"):
		ProfileManager.call("apply_backend_identity", player)
	var server_call_sign: String = str(player.get("call_sign", call_sign)).strip_edges()
	var result: Dictionary = ProfileManager.request_handle_change(server_call_sign, false, "onboarding")
	if not bool(result.get("ok", false)):
		status_label.text = _call_sign_validation_message(result, "Choose a valid call sign.")
		return
	_report_age_to_scholastic_state(age_years)
	ProfileManager.mark_onboarding_complete()
	if not ProfileManager.is_onboarding_complete():
		status_label.text = "Account setup did not finish. Please try again."
		return
	onboarding_guide_prompt_requested.emit()
	onboarding_done.emit()

func _register_backend_identity(call_sign: String) -> Dictionary:
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state == null or not rank_state.has_method("intent_register_player"):
		return _debug_offline_registration(call_sign, "account_service_unavailable")
	var install_metadata: Dictionary = {
		"client": "swarmfront",
		"platform": OS.get_name()
	}
	var result: Dictionary = rank_state.call("intent_register_player", "", call_sign, "NA", [], install_metadata, true) as Dictionary
	if bool(result.get("ok", false)):
		return result
	var reason: String = str(result.get("err", result.get("reason", ""))).strip_edges()
	if _is_backend_unavailable_reason(reason):
		return _debug_offline_registration(call_sign, reason)
	return result

func _debug_offline_registration(call_sign: String, reason: String) -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "reason": reason}
	return {
		"ok": true,
		"debug_offline_identity": true,
		"player": {
			"id": DEBUG_OFFLINE_PROFILE_ID,
			"player_id": DEBUG_OFFLINE_PROFILE_ID,
			"entap_id": DEBUG_OFFLINE_ENTAP_ID,
			"call_sign": call_sign,
			"display_name": call_sign
		}
	}

func _is_backend_unavailable_reason(reason: String) -> bool:
	return [
		"account_service_unavailable",
		"rank_backend_not_configured",
		"rank_backend_unavailable",
		"transport_not_configured",
		"backend_unavailable"
	].has(reason)

func _registration_error_message(result: Dictionary) -> String:
	var reason: String = str(result.get("err", result.get("reason", ""))).strip_edges()
	match reason:
		"call_sign_not_unique":
			return "That call sign is already taken."
		"invalid_call_sign":
			return "Use letters, numbers, and underscore only."
		"rank_backend_not_configured", "rank_backend_unavailable", "account_service_unavailable":
			return "Account service is unavailable. Check your connection and try again."
		_:
			return "Account setup failed. Please try again."

func _call_sign_validation_message(result: Dictionary, fallback: String) -> String:
	var message: String = str(result.get("message", fallback)).strip_edges()
	if message.is_empty():
		message = fallback
	return message.replace("handle", "call sign").replace("Handle", "Call Sign")

func _report_age_to_scholastic_state(age_years: int) -> void:
	var state_node: Node = get_node_or_null("/root/ScholasticState")
	if state_node == null or not state_node.has_method("intent_report_age"):
		return
	state_node.call(
		"intent_report_age",
		ProfileManager.get_user_id(),
		age_years,
		ProfileManager.get_display_name()
	)

func _configure_age_input() -> void:
	if age_input == null:
		return
	age_input.text = ""
	age_input.placeholder_text = "Age"
	age_input.max_length = 2
	age_input.virtual_keyboard_enabled = true
	age_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER

func _on_age_text_changed(text: String) -> void:
	status_label.text = ""
	var digits: String = ""
	for index in text.length():
		var character: String = text.substr(index, 1)
		if character.is_valid_int():
			digits += character
	if digits == text:
		return
	var caret_column: int = mini(age_input.caret_column, digits.length())
	age_input.text = digits
	age_input.caret_column = caret_column

func _age_years_from_input() -> int:
	var text: String = age_input.text.strip_edges() if age_input != null else ""
	if text.is_empty() or not text.is_valid_int():
		return -1
	var age_years: int = int(text)
	if age_years < 1 or age_years > 99:
		return -1
	return age_years

func _initial_handle_text() -> String:
	if ProfileManager.has_method("is_handle_chosen") and bool(ProfileManager.call("is_handle_chosen")):
		return ProfileManager.get_display_name()
	var uid: String = ProfileManager.get_user_id()
	if uid.strip_edges().is_empty():
		var suffix_num: int = int(Time.get_ticks_msec() % 10000)
		return "Player_%04d" % suffix_num
	var suffix: String = uid
	if suffix.begins_with("u_"):
		suffix = suffix.substr(2, suffix.length() - 2)
	if suffix.length() >= 4:
		suffix = suffix.substr(suffix.length() - 4, 4)
	else:
		suffix = suffix.pad_zeros(4)
	return "Player_%s" % suffix.to_upper()

func _apply_readable_first_run_type() -> void:
	custom_minimum_size = Vector2(960.0, 740.0)
	var box: VBoxContainer = $VBox
	if box != null:
		box.add_theme_constant_override("separation", 24)
	_apply_font(title_label, UITypography.semibold_font(), TITLE_FONT_SIZE)
	_apply_font(body_label, UITypography.regular_font(), BODY_FONT_SIZE)
	_apply_font(display_name_label, UITypography.semibold_font(), BODY_FONT_SIZE)
	_apply_font(display_name_input, UITypography.regular_font(), INPUT_FONT_SIZE)
	_apply_font(age_label, UITypography.semibold_font(), BODY_FONT_SIZE)
	_apply_font(age_input, UITypography.regular_font(), INPUT_FONT_SIZE)
	_apply_font(status_label, UITypography.regular_font(), STATUS_FONT_SIZE)
	_apply_font(continue_button, UITypography.semibold_font(), BUTTON_FONT_SIZE)
	for control in [display_name_input, age_input, continue_button]:
		if control is Control:
			(control as Control).custom_minimum_size.y = ROW_HEIGHT

func _apply_font(control: Control, font: Font, size: int) -> void:
	if control == null:
		return
	if font != null:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", size)
