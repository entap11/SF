extends SceneTree

const SessionScript = preload("res://scripts/state/player_session_state.gd")
const PLAYER_ID = "018f0000-0000-7000-8000-000000000123"
const DEVICE_ID = "018f0000-0000-7000-8000-000000000456"

# Real panel and runtime with release failure behavior. Only the native
# keystore and HTTP boundary are replaced; no live accounts are touched.
class FakeCredentials extends RefCounted:
	var available: bool = true
	func is_available() -> bool:
		return available
	func create_device_key(_alias: String) -> Dictionary:
		return {"ok": true}
	func public_key_jwk(_alias: String) -> Dictionary:
		return {"ok": true, "jwk": {"kty": "EC", "crv": "P-256", "x": "test", "y": "test"}}
	func sign_challenge(_alias: String, _challenge: String) -> Dictionary:
		return {"ok": true, "signature": "test-signature"}

class FakeTransport extends RefCounted:
	var calls: Array[Dictionary] = []
	var register_error: String = ""
	var register_errors: Array[String] = []
	var session_error: String = ""
	var call_sign: String = ""
	var persisted_before_request: bool = true
	func configure(_url: String, _timeout: float, _token: String = "") -> void:
		pass
	func call_read(_action: String) -> Dictionary:
		return {"ok": false, "err": "economy_disabled"}
	func player() -> Dictionary:
		return {"id": PLAYER_ID, "entap_id": "AAA 777", "call_sign": call_sign}
	func call_action(action: String, payload: Dictionary) -> Dictionary:
		calls.append({"action": action, "payload": payload.duplicate(true)})
		match action:
			"identity/register":
				var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://player_identity_bootstrap.json"))
				persisted_before_request = persisted_before_request and saved.get("registration_request_id") == payload.get("request_id") and saved.get("registration_call_sign") == payload.get("call_sign")
				var rejection: String = register_error if register_errors.is_empty() else register_errors.pop_front()
				if not rejection.is_empty():
					return {"ok": false, "err": rejection}
				call_sign = str(payload.get("call_sign", ""))
				return {"ok": true, "player": player(), "device": {"id": DEVICE_ID}, "challenge": {"id": "challenge", "challenge": "proof"}}
			"identity/challenge":
				return {"ok": true, "challenge": {"id": "retry-challenge", "challenge": "retry-proof"}}
			"identity/session":
				if not session_error.is_empty():
					return {"ok": false, "err": session_error}
				return {"ok": true, "player": player(), "access_token": "test.access.token", "session": {
					"id": "session", "player_id": PLAYER_ID, "device_id": DEVICE_ID,
					"expires_at_unix": int(Time.get_unix_time_from_system()) + 600}}
			"identity/session/status":
				return {"ok": true}
		return {"ok": false, "err": "unexpected_action"}

var identity: Node
var profile: Node
var transport: FakeTransport
var credentials: FakeCredentials
var panel: Control
var release_panel_script: GDScript
var done_count: int = 0
var failed: bool = false

func _init() -> void:
	call_deferred("_run")

func _reset() -> void:
	if panel != null:
		panel.free()
	identity.set("_device_id", "")
	identity.set("_registration_request_id", "")
	identity.set("_registration_call_sign", "")
	identity.set("_authenticated_player", {})
	identity.set("_session", SessionScript.new())
	transport = FakeTransport.new()
	credentials = FakeCredentials.new()
	identity.set("_transport", transport)
	identity.set("_credential_store", credentials)
	profile.call("smoke_force_identity_state", "", "", "Player_Default", false, false)
	done_count = 0
	panel = load("res://scenes/ui/onboarding/onboarding_panel.tscn").instantiate()
	panel.set_script(release_panel_script)
	root.add_child(panel)
	panel.connect("onboarding_done", func(): done_count += 1)
	panel.get_node("VBox/DisplayNameInput").text = "BetaSmoke"
	panel.get_node("VBox/AgeSpin").text = "35"

func _submit() -> void:
	panel.call("_on_continue_pressed")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("ONBOARDING_BACKEND_IDENTITY_SUCCESS_SMOKE: " + message)

func _registered_calls() -> Array[Dictionary]:
	var registrations: Array[Dictionary] = []
	for request in transport.calls:
		if request.action == "identity/register":
			registrations.append(request.payload)
	return registrations

func _run() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("SwarmfrontSignupChecks-"):
		push_error("Run through tools/run_onboarding_identity_checks.py with isolated player data.")
		quit(1)
		return
	identity = root.get_node("PlayerIdentityRuntime")
	profile = root.get_node("ProfileManager")
	# Compile after autoloads exist; a SceneTree preload cannot resolve them.
	release_panel_script = GDScript.new()
	release_panel_script.source_code = 'extends "res://scripts/ui/onboarding/onboarding_panel.gd"\nfunc _debug_offline_registration(_call_sign: String, reason: String) -> Dictionary:\n\treturn {"ok": false, "err": reason}\n'
	if release_panel_script.reload() != OK:
		quit(1)
		return
	_expect(not root.get_node("OpsConfig").call("rank_backend_enabled"), "fixture must reproduce disabled Rank")
	_reset()
	identity.call("_authenticate")
	_expect(transport.calls.is_empty(), "startup registered before the player submitted a call sign")
	_submit()
	_expect(done_count == 1 and profile.call("is_onboarding_complete"), "first submit did not complete onboarding")
	_expect(profile.call("get_user_id") == PLAYER_ID and profile.call("get_entap_id") == "AAA 777", "server identity was not applied")
	_expect(profile.call("get_call_sign") == "BetaSmoke", "chosen call sign was not registered")
	_expect(identity.call("is_authenticated"), "onboarding completed without a device session")
	_expect(_registered_calls().size() == 1 and transport.persisted_before_request, "request not persisted before registration")
	_expect(not _registered_calls()[0].has("player_id"), "client assigned an authoritative player ID")
	_expect(not FileAccess.get_file_as_string("user://player_identity_bootstrap.json").contains("test.access.token"), "bootstrap persisted a bearer token")

	# A lost response preserves the form and exact request across a restart.
	_reset()
	transport.register_error = "response_timeout"
	_submit()
	_expect(done_count == 0 and not profile.call("is_onboarding_complete"), "timeout completed onboarding")
	_expect(panel.get_node("VBox/AgeSpin").text == "35", "timeout discarded entered age")
	_expect(not panel.get_node("VBox/StatusLabel").text.is_empty(), "timeout gave no retry message")
	var original_request: Dictionary = _registered_calls()[0]
	identity.set("_registration_request_id", "")
	identity.set("_registration_call_sign", "")
	identity.call("_load_bootstrap_state")
	transport.register_error = ""
	panel.get_node("VBox/DisplayNameInput").text = "ChangedName"
	_submit()
	_expect(_registered_calls()[1] == original_request, "restart or form edit changed an uncertain request")
	_expect(done_count == 0 and panel.get_node("VBox/DisplayNameInput").text == "BetaSmoke", "recovered account was silently substituted")
	_submit()
	_expect(done_count == 1 and _registered_calls().size() == 2, "confirmation registered another account")

	# A definitive name conflict permits a new choice.
	_reset()
	transport.register_error = "call_sign_not_unique"
	_submit()
	_expect(done_count == 0 and panel.get_node("VBox/StatusLabel").text.contains("already taken"), "name conflict not shown")
	transport.register_error = ""
	panel.get_node("VBox/DisplayNameInput").text = "AnotherName"
	_submit()
	_expect(done_count == 1 and transport.call_sign == "AnotherName", "name conflict could not be corrected")

	# An older build may have saved a failed startup request using its default
	# name. Reconcile it without falsely rejecting the new name in the form.
	_reset()
	profile.call("smoke_force_identity_state", "", "", "OldDefault", false, false)
	var old_bootstrap := FileAccess.open("user://player_identity_bootstrap.json", FileAccess.WRITE)
	old_bootstrap.store_string(JSON.stringify({"schema_version": 1, "device_id": "", "registration_request_id": "legacy-request"}))
	old_bootstrap.close()
	identity.call("_load_bootstrap_state")
	transport.register_errors.assign(["call_sign_not_unique", ""])
	_submit()
	_expect(done_count == 1 and _registered_calls().size() == 2, "legacy rejected default prevented signup")
	_expect(_registered_calls()[0].call_sign == "OldDefault" and _registered_calls()[1].call_sign == "BetaSmoke", "legacy request was not reconciled before the new choice")

	# A session failure resumes proof of the saved device.
	_reset()
	transport.session_error = "response_timeout"
	_submit()
	_expect(done_count == 0 and identity.get("_device_id") == DEVICE_ID, "partial registration lost device or completed early")
	transport.session_error = ""
	_submit()
	_expect(done_count == 1 and _registered_calls().size() == 1, "session retry registered another account")
	_expect(transport.calls[2].action == "identity/challenge", "session retry did not get a fresh challenge")

	# Older beta devices keep their already registered account.
	_reset()
	identity.set("_device_id", DEVICE_ID)
	transport.call_sign = "ExistingBeta"
	identity.call("_authenticate")
	_submit()
	_expect(done_count == 0 and _registered_calls().is_empty(), "existing device was registered again")
	_expect(panel.get_node("VBox/DisplayNameInput").text == "ExistingBeta", "existing account not offered for confirmation")
	_submit()
	_expect(done_count == 1 and profile.call("get_user_id") == PLAYER_ID, "existing beta account could not finish")

	_reset()
	credentials.available = false
	_submit()
	_expect(done_count == 0 and transport.calls.is_empty(), "missing keystore bypassed authentication")
	_expect(not profile.call("is_onboarding_complete"), "release failure used a debug identity")

	_reset()
	DirAccess.make_dir_absolute("user://player_identity_bootstrap.json.tmp")
	_submit()
	_expect(done_count == 0 and transport.calls.is_empty(), "registration proceeded without a durable retry record")
	_expect(panel.get_node("VBox/StatusLabel").text.contains("storage"), "save failure did not explain how to retry")
	DirAccess.remove_absolute("user://player_identity_bootstrap.json.tmp")
	_submit()
	_expect(done_count == 1, "registration could not resume after storage recovered")
	panel.free()
	if not failed:
		print("ONBOARDING_BACKEND_IDENTITY_SUCCESS_SMOKE: PASS (fresh, retry, restart, conflict, existing device, secure storage)")
	quit(1 if failed else 0)
