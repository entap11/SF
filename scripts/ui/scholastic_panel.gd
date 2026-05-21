extends Panel

signal close_requested()
signal scholastic_intent_submitted(intent_name: String, payload: Dictionary)

@onready var title_label: Label = $Root/VBox/Title
@onready var status_label: Label = $Root/VBox/Status
@onready var sfa_button: Button = $Root/VBox/ButtonRow/SFAButton
@onready var school_button: Button = $Root/VBox/ButtonRow/SchoolButton
@onready var recruiting_button: Button = $Root/VBox/ButtonRow/RecruitingButton
@onready var close_button: Button = $Root/VBox/ButtonRow/CloseButton
@onready var summary_text: RichTextLabel = $Root/VBox/SummaryScroll/SummaryText

const LOCAL_PLAYER_ID: String = "local_player"

func _ready() -> void:
	title_label.text = "SFA / SFU"
	sfa_button.pressed.connect(func() -> void:
		_submit_sfa_age_intent()
	)
	school_button.pressed.connect(func() -> void:
		_submit_school_placeholder_intent()
	)
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

func _submit_sfa_age_intent() -> void:
	var payload: Dictionary = {"player_id": LOCAL_PLAYER_ID, "age_years": 16}
	scholastic_intent_submitted.emit("intent_report_age", payload)
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_report_age"):
		var result: Dictionary = state_node.call("intent_report_age", LOCAL_PLAYER_ID, 16, "Local Player") as Dictionary
		_render_result(result)

func _submit_school_placeholder_intent() -> void:
	var identity: Dictionary = {
		"school_id": "demo_high",
		"school_name": "Demo High",
		"city": "San Francisco",
		"state": "CA",
		"mascot_name": "Stingers",
		"colors": ["Gold", "Black"],
		"verification_status": "PENDING"
	}
	scholastic_intent_submitted.emit("intent_register_high_school", {"player_id": LOCAL_PLAYER_ID, "identity": identity})
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_register_high_school"):
		var result: Dictionary = state_node.call("intent_register_high_school", LOCAL_PLAYER_ID, identity) as Dictionary
		_render_result(result)

func _submit_recruiting_placeholder_intent() -> void:
	scholastic_intent_submitted.emit("intent_update_recruiting_status", {"player_id": LOCAL_PLAYER_ID, "status": "SFA_RECRUITABLE"})
	var state_node: Node = _scholastic_state()
	if state_node != null and state_node.has_method("intent_update_recruiting_status"):
		var result: Dictionary = state_node.call("intent_update_recruiting_status", LOCAL_PLAYER_ID, "SFA_RECRUITABLE") as Dictionary
		_render_result(result)

func _refresh_from_state() -> void:
	var state_node: Node = _scholastic_state()
	if state_node == null:
		status_label.text = "ScholasticState missing"
		summary_text.text = ""
		return
	var profile: Dictionary = state_node.call("get_player_profile_snapshot", LOCAL_PLAYER_ID) as Dictionary if state_node.has_method("get_player_profile_snapshot") else {}
	if profile.is_empty():
		status_label.text = "No scholastic profile yet."
		summary_text.text = "Use SFA Age to create a placeholder local profile."
		return
	status_label.text = "Profile: %s" % str(profile.get("ecosystem", "NONE"))
	var comms: Dictionary = profile.get("communication_access", {}) as Dictionary
	var money: Dictionary = profile.get("money_access", {}) as Dictionary
	var sfa: Dictionary = profile.get("sfa", {}) as Dictionary
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Display: %s" % str(profile.get("display_name", "")))
	lines.append("SFA: %s" % str(sfa.get("is_user", false)))
	lines.append("Team: %s slot %d" % [str(sfa.get("team_label", "")), int(sfa.get("roster_slot", -1))])
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
