extends Panel

signal close_requested()
signal scholastic_intent_submitted(intent_name: String, payload: Dictionary)

@onready var title_label: Label = $Root/VBox/Title
@onready var status_label: Label = $Root/VBox/Status
@onready var age_spin: SpinBox = $Root/VBox/FormGrid/AgeSpin
@onready var school_name_input: LineEdit = $Root/VBox/FormGrid/SchoolNameInput
@onready var school_city_input: LineEdit = $Root/VBox/FormGrid/SchoolCityInput
@onready var school_state_input: LineEdit = $Root/VBox/FormGrid/SchoolStateInput
@onready var school_year_input: LineEdit = $Root/VBox/FormGrid/SchoolYearInput
@onready var freshman_year_input: LineEdit = $Root/VBox/FormGrid/FreshmanYearInput
@onready var program_name_input: LineEdit = $Root/VBox/FormGrid/ProgramNameInput
@onready var program_city_input: LineEdit = $Root/VBox/FormGrid/ProgramCityInput
@onready var program_state_input: LineEdit = $Root/VBox/FormGrid/ProgramStateInput
@onready var age_button: Button = $Root/VBox/ButtonRow/AgeButton
@onready var sfa_button: Button = $Root/VBox/ButtonRow/SFAButton
@onready var sfu_button: Button = $Root/VBox/ButtonRow/SFUButton
@onready var recruiting_button: Button = $Root/VBox/ButtonRow/RecruitingButton
@onready var close_button: Button = $Root/VBox/ButtonRow/CloseButton
@onready var summary_text: RichTextLabel = $Root/VBox/SummaryScroll/SummaryText

func _ready() -> void:
	title_label.text = "SFA / SFU"
	_seed_form_defaults()
	age_button.pressed.connect(_submit_age_intent)
	sfa_button.pressed.connect(_submit_school_intent)
	sfu_button.pressed.connect(_submit_sfu_intent)
	recruiting_button.pressed.connect(func() -> void:
		_submit_recruiting_placeholder_intent()
	)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_signal("scholastic_state_changed"):
		if not state_node.is_connected("scholastic_state_changed", _on_scholastic_state_changed):
			state_node.connect("scholastic_state_changed", _on_scholastic_state_changed)
	_refresh_from_state()

func _exit_tree() -> void:
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_signal("scholastic_state_changed"):
		if state_node.is_connected("scholastic_state_changed", _on_scholastic_state_changed):
			state_node.disconnect("scholastic_state_changed", _on_scholastic_state_changed)

func _on_scholastic_state_changed(_snapshot: Dictionary) -> void:
	_refresh_from_state()

func _submit_age_intent() -> void:
	var age_years: int = int(age_spin.value)
	var payload: Dictionary = {"player_id": _local_player_id(), "age_years": age_years}
	scholastic_intent_submitted.emit("intent_report_age", payload)
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_report_age"):
		var result: Dictionary = state_node.call("intent_report_age", _local_player_id(), age_years, _local_display_name()) as Dictionary
		_render_result(result)

func _submit_school_intent() -> void:
	var identity: Dictionary = _school_identity_from_inputs()
	if str(identity.get("school_name", "")).is_empty() or str(identity.get("city", "")).is_empty() or str(identity.get("state", "")).is_empty():
		status_label.text = "High school, city, and state are required."
		return
	if int(age_spin.value) >= 0 and int(age_spin.value) < 18:
		_submit_age_intent()
	scholastic_intent_submitted.emit("intent_register_high_school", {"player_id": _local_player_id(), "identity": identity})
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_register_high_school"):
		var result: Dictionary = state_node.call("intent_register_high_school", _local_player_id(), identity) as Dictionary
		_render_result(result)

func _submit_sfu_intent() -> void:
	var identity: Dictionary = _program_identity_from_inputs()
	if str(identity.get("university_name", "")).is_empty() or str(identity.get("city", "")).is_empty() or str(identity.get("state", "")).is_empty():
		status_label.text = "Program, city, and state are required."
		return
	if int(age_spin.value) >= 18:
		_submit_age_intent()
	scholastic_intent_submitted.emit("intent_register_college_program", {"identity": identity})
	var state_node: Node = _scholastic_state()
	if state_node == null:
		return
	if state_node.has_method("intent_register_college_program"):
		var register_result: Dictionary = state_node.call("intent_register_college_program", identity) as Dictionary
		if not bool(register_result.get("ok", false)):
			_render_result(register_result)
			return
	if state_node.has_method("intent_join_college_program"):
		var result: Dictionary = state_node.call("intent_join_college_program", _local_player_id(), str(identity.get("college_program_id", "")), {
			"attested_affiliated": true,
			"school_year": school_year_input.text
		}) as Dictionary
		_render_result(result)

func _submit_recruiting_placeholder_intent() -> void:
	scholastic_intent_submitted.emit("intent_update_recruiting_status", {"player_id": _local_player_id(), "status": "SFA_RECRUITABLE"})
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_update_recruiting_status"):
		var result: Dictionary = state_node.call("intent_update_recruiting_status", _local_player_id(), "SFA_RECRUITABLE") as Dictionary
		_render_result(result)

func _refresh_from_state() -> void:
	var state_node: Node = _scholastic_state()
	if state_node == null:
		status_label.text = "ScholasticState missing"
		summary_text.text = ""
		return
	var profile: Dictionary = state_node.call("get_player_profile_snapshot", _local_player_id()) as Dictionary if state_node.has_method("get_player_profile_snapshot") else {}
	if profile.is_empty():
		status_label.text = "No scholastic profile yet."
		summary_text.text = "Set age first. SFA appears for high-school/minor accounts; SFU appears for adult post-secondary accounts."
		_sync_button_visibility(-1)
		return
	status_label.text = "Profile: %s" % str(profile.get("ecosystem", "NONE"))
	var age_years: int = int(profile.get("age_years", -1))
	if age_years >= 0:
		age_spin.value = age_years
	_sync_button_visibility(age_years)
	var comms: Dictionary = profile.get("communication_access", {}) as Dictionary
	var money: Dictionary = profile.get("money_access", {}) as Dictionary
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var sfu: Dictionary = profile.get("sfu", {}) as Dictionary
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Display: %s" % str(profile.get("display_name", "")))
	lines.append("Age: %d" % age_years)
	lines.append("SFA: %s" % str(sfa.get("is_user", false)))
	lines.append("Status: %s" % str(sfa.get("eligibility_status", "")))
	lines.append("School: %s" % str(sfa.get("school_id", "")))
	lines.append("School year: %s" % str(sfa.get("current_school_year_attested", "")))
	lines.append("Team: %s slot %d" % [str(sfa.get("team_label", "")), int(sfa.get("roster_slot", -1))])
	lines.append("SFU: %s" % str(sfu.get("sfu_status", "")))
	lines.append("Program: %s" % str(sfu.get("college_program_id", "")))
	lines.append("DM/chat/voice: %s/%s/%s" % [str(comms.get("dm_enabled", false)), str(comms.get("in_game_chat_enabled", false)), str(comms.get("voice_enabled", false))])
	lines.append("Real money prizes: %s" % str(money.get("can_win_real_money", false)))
	summary_text.text = "\n".join(lines)

func _render_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		status_label.text = "Intent accepted."
	else:
		status_label.text = "Intent rejected: %s" % str(result.get("reason", "unknown"))
	_refresh_from_state()

func _scholastic_state() -> Node:
	return get_node_or_null("/root/ScholasticState")

func _seed_form_defaults() -> void:
	var current_year: String = _current_school_year()
	school_year_input.text = current_year
	freshman_year_input.text = current_year
	school_state_input.placeholder_text = "OR"
	program_state_input.placeholder_text = "OR"

func _sync_button_visibility(age_years: int) -> void:
	var sfa_visible: bool = age_years >= 0 and age_years < 18
	var sfu_visible: bool = age_years >= 18 and age_years <= 24
	sfa_button.visible = sfa_visible
	sfu_button.visible = sfu_visible
	recruiting_button.visible = sfa_visible or sfu_visible

func _school_identity_from_inputs() -> Dictionary:
	var school_name: String = school_name_input.text.strip_edges()
	var city: String = school_city_input.text.strip_edges()
	var state: String = school_state_input.text.strip_edges().to_upper()
	var school_id: String = _school_program_id(school_name, city, state)
	return {
		"school_id": school_id,
		"school_name": school_name,
		"city": city,
		"state": state,
		"verification_status": "PENDING",
		"attested_enrolled": true,
		"school_year": school_year_input.text.strip_edges(),
		"freshman_school_year": freshman_year_input.text.strip_edges()
	}

func _program_identity_from_inputs() -> Dictionary:
	var program_name: String = program_name_input.text.strip_edges()
	var city: String = program_city_input.text.strip_edges()
	var state: String = program_state_input.text.strip_edges().to_upper()
	var program_id: String = _school_program_id(program_name, city, state)
	return {
		"college_program_id": program_id,
		"university_name": program_name,
		"program_type": "COLLEGE",
		"city": city,
		"state": state
	}

func _school_program_id(name: String, city: String, state: String) -> String:
	return _normalize_id("%s_%s_%s" % [state, city, name])

func _normalize_id(value: String) -> String:
	var out: String = value.strip_edges().to_lower()
	for token in [" ", "-", "/", "\\", ".", "'", "\"", ","]:
		out = out.replace(token, "_")
	while out.find("__") >= 0:
		out = out.replace("__", "_")
	return out.strip_edges()

func _current_school_year() -> String:
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("get_snapshot"):
		var snapshot: Dictionary = state_node.call("get_snapshot") as Dictionary
		var sfa_policy: Dictionary = snapshot.get("sfa_policy", {}) as Dictionary
		var current_year: String = str(sfa_policy.get("current_school_year", "")).strip_edges()
		if not current_year.is_empty():
			return current_year
	return "2026-2027"

func _local_player_id() -> String:
	if ProfileManager != null and ProfileManager.has_method("get_user_id"):
		return str(ProfileManager.call("get_user_id"))
	return "local_player"

func _local_display_name() -> String:
	if ProfileManager != null and ProfileManager.has_method("get_display_name"):
		var display_name: String = str(ProfileManager.call("get_display_name")).strip_edges()
		if not display_name.is_empty():
			return display_name
	return "Local Player"
