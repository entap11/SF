class_name SupportDiagnosticsPanel
extends Control

@onready var _summary_label: Label = get_node_or_null("Panel/VBox/Summary") as Label
@onready var _payload_text: TextEdit = get_node_or_null("Panel/VBox/Payload") as TextEdit
@onready var _copy_button: Button = get_node_or_null("Panel/VBox/Buttons/Copy") as Button
@onready var _close_button: Button = get_node_or_null("Panel/VBox/Buttons/Close") as Button

func _ready() -> void:
	if _copy_button != null:
		_copy_button.pressed.connect(copy_diagnostics_to_clipboard)
	if _close_button != null:
		_close_button.pressed.connect(func(): visible = false)
	refresh()

func refresh() -> void:
	var payload: Dictionary = build_diagnostics_payload()
	if _summary_label != null:
		_summary_label.text = "ENTaP %s | %s | config %s" % [
			str(payload.get("entap_id", "--")),
			str(payload.get("call_sign", "--")),
			str((payload.get("ops_config", {}) as Dictionary).get("config_source", "--"))
		]
	if _payload_text != null:
		_payload_text.text = JSON.stringify(payload, "\t")

func copy_diagnostics_to_clipboard() -> Dictionary:
	var payload: Dictionary = build_diagnostics_payload()
	var text: String = JSON.stringify(payload, "\t")
	DisplayServer.clipboard_set(text)
	if _payload_text != null:
		_payload_text.text = text
	return {"ok": true, "bytes": text.length(), "payload": payload}

func build_diagnostics_payload() -> Dictionary:
	var profile: Node = get_node_or_null("/root/ProfileManager")
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	var analytics: Node = get_node_or_null("/root/AnalyticsClient")
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	var entap_id: String = ""
	var call_sign: String = ""
	var has_internal_player_id: bool = false
	if profile != null:
		if profile.has_method("ensure_loaded"):
			profile.call("ensure_loaded")
		if profile.has_method("get_entap_id"):
			entap_id = str(profile.call("get_entap_id")).strip_edges()
		if profile.has_method("get_display_name"):
			call_sign = str(profile.call("get_display_name")).strip_edges()
		if profile.has_method("get_user_id"):
			has_internal_player_id = not str(profile.call("get_user_id")).strip_edges().is_empty()
	var ops_snapshot: Dictionary = {}
	if ops_config != null and ops_config.has_method("get_debug_snapshot"):
		ops_snapshot = ops_config.call("get_debug_snapshot") as Dictionary
	var analytics_snapshot: Dictionary = {}
	if analytics != null and analytics.has_method("get_debug_snapshot"):
		analytics_snapshot = analytics.call("get_debug_snapshot") as Dictionary
	var analytics_health: Dictionary = {}
	if analytics != null and analytics.has_method("get_health_snapshot"):
		analytics_health = analytics.call("get_health_snapshot") as Dictionary
	var handshake_snapshot: Dictionary = {}
	if handshake != null:
		if handshake.has_method("get_beta_runtime_flags"):
			handshake_snapshot["beta_runtime_flags"] = handshake.call("get_beta_runtime_flags")
		if handshake.has_method("get_transport_mode"):
			handshake_snapshot["transport_mode"] = str(handshake.call("get_transport_mode"))
		if handshake.has_method("get_last_transport_error"):
			handshake_snapshot["last_transport_error"] = handshake.call("get_last_transport_error")
		if handshake.has_method("get_authoritative_transport_blocker"):
			handshake_snapshot["transport_blocker"] = str(handshake.call("get_authoritative_transport_blocker"))
	return {
		"schema_version": 1,
		"generated_unix_ms": _unix_ms(),
		"app_name": str(ProjectSettings.get_setting("application/config/name", "Swarmfront")),
		"app_build": str(ProjectSettings.get_setting("application/config/version", "")),
		"platform": OS.get_name(),
		"device_model": OS.get_model_name(),
		"os_version": OS.get_version(),
		"entap_id": entap_id,
		"call_sign": call_sign,
		"internal_player_id_present": has_internal_player_id,
		"ops_config": ops_snapshot,
		"analytics": analytics_snapshot,
		"analytics_health": analytics_health,
		"vs": handshake_snapshot
	}

func _unix_ms() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))
