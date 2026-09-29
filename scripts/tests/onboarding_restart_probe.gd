extends Node

# Four separate processes share only their test installation's saved files.
# The account service is controlled; Android uses the real native key store.
const CredentialFactory = preload("res://scripts/platform/secure_credential_store_factory.gd")
const RESULT_PATH = "user://signup_restart_results.json"
const CALL_SIGN = "BetaPersist_35"
const PLAYER_ID = "018f0000-0000-7000-8000-000000000321"
const DEVICE_ID = "018f0000-0000-7000-8000-000000000654"
const PHASES = ["signup", "offline_restart", "online_restart", "second_online_restart"]

class DesktopCredentials extends RefCounted:
	func is_available() -> bool:
		return true
	func create_device_key(_alias: String) -> Dictionary:
		return {"ok": true}
	func public_key_jwk(_alias: String) -> Dictionary:
		return {"ok": true, "jwk": {"kty": "EC", "crv": "P-256", "x": "desktop", "y": "fixture"}}
	func sign_challenge(_alias: String, _text: String) -> Dictionary:
		return {"ok": true, "signature": "desktop-fixture-signature"}

class AccountService extends RefCounted:
	var offline: bool = false
	var allow_registration: bool = false
	var server_call_sign: String = ""
	var actions: Array[String] = []
	func configure(_url: String, _timeout: float, _token: String = "") -> void:
		pass
	func call_read(_action: String) -> Dictionary:
		return {"ok": false, "err": "economy_disabled"}
	func call_action(action: String, payload: Dictionary) -> Dictionary:
		actions.append(action)
		if offline:
			return {"ok": false, "err": "response_timeout", "transport_error": true}
		match action:
			"identity/register":
				if not allow_registration:
					return {"ok": false, "err": "unexpected_repeat_registration"}
				server_call_sign = str(payload.get("call_sign", ""))
				return {"ok": true, "player": player(), "device": {"id": DEVICE_ID}, "challenge": challenge()}
			"identity/challenge":
				if str(payload.get("device_id", "")) != DEVICE_ID:
					return {"ok": false, "err": "wrong_persisted_device"}
				return {"ok": true, "challenge": challenge()}
			"identity/session":
				if str(payload.get("signature", "")).is_empty():
					return {"ok": false, "err": "missing_device_proof"}
				return {"ok": true, "player": player(), "access_token": "test.access.token", "session": {
					"id": "restart-session", "player_id": PLAYER_ID, "device_id": DEVICE_ID,
					"expires_at_unix": int(Time.get_unix_time_from_system()) + 600}}
			"identity/session/status":
				return {"ok": true}
		return {"ok": false, "err": "unexpected_action"}
	func player() -> Dictionary:
		return {"id": PLAYER_ID, "entap_id": "AAA 789", "call_sign": server_call_sign}
	func challenge() -> Dictionary:
		return {"id": "restart-challenge", "challenge": "swarmfront:identity-session:v1:restart:proof"}

var _results: Array = []
var _errors: Array[String] = []
var _phase: String = ""
var _identity: Node
var _profile: Node
var _service: AccountService
var _credentials: RefCounted
var _native: bool = false
var _done_count: int = 0
var _boot: Dictionary = {}

func _ready() -> void:
	_native = OS.get_name() == "Android" and OS.has_feature("signup_restart_check")
	if not _native and not OS.get_user_data_dir().contains("SwarmfrontSignupChecks-"):
		push_error("Signup restart probe requires an isolated test installation.")
		get_tree().quit(2)
		return
	if FileAccess.file_exists(RESULT_PATH):
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RESULT_PATH))
		_results = saved.get("results", [])
	if _results.size() >= PHASES.size():
		get_tree().quit(0)
		return
	_phase = PHASES[_results.size()]
	_identity = get_node("/root/PlayerIdentityRuntime")
	_profile = get_node("/root/ProfileManager")
	# Capture the state loaded by the normal autoloads, before any authentication.
	_boot = {
		"call_sign": _profile.call("get_call_sign"),
		"onboarding_complete": _profile.call("is_onboarding_complete"),
		"device_id": _identity.get("_device_id"),
		"authenticated": _identity.call("is_authenticated"),
		"profile_created": _profile.call("was_created_this_run")
	}
	_service = AccountService.new()
	_service.offline = _phase == "offline_restart"
	_service.allow_registration = _phase == "signup"
	if not _results.is_empty():
		_service.server_call_sign = str(_results[0].get("registered_call_sign", ""))
	_credentials = CredentialFactory.create() if _native else DesktopCredentials.new()
	_identity.set("_credential_store", _credentials)
	_identity.set("_transport", _service)
	# Resume through the same entry point used by startup and the refresh timer.
	_identity.call_deferred("_authenticate")
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _run() -> void:
	_expect(not bool(_boot.authenticated), "access token survived a process restart")
	_expect(_credentials.call("is_available"), "credential store unavailable")
	if _phase == "signup":
		_expect(not bool(_boot.onboarding_complete), "signup fixture was already onboarded")
		_expect(_service.actions.is_empty(), "startup registered before Continue")
		var panel: Control = load("res://scenes/ui/onboarding/onboarding_panel.tscn").instantiate()
		add_child(panel)
		panel.connect("onboarding_done", func(): _done_count += 1)
		panel.get_node("VBox/DisplayNameInput").text = CALL_SIGN
		panel.get_node("VBox/AgeSpin").text = "35"
		panel.call("_on_continue_pressed")
		_expect(_done_count == 1, "signup did not complete exactly once")
		_expect(_service.actions.count("identity/register") == 1, "signup did not register exactly once")
		panel.free()
	else:
		_expect(str(_boot.call_sign) == CALL_SIGN, "call sign not restored from disk before authentication")
		_expect(bool(_boot.onboarding_complete), "signup completion not restored from disk")
		_expect(not bool(_boot.profile_created), "restart created a new profile")
		_expect(str(_boot.device_id) == DEVICE_ID, "registered device not restored")
		_expect(_service.actions.has("identity/challenge"), "startup did not resume the saved device")
		_expect(_service.actions.count("identity/register") == 0, "restart registered another account")
	_expect(_identity.call("is_authenticated") == not _service.offline, "unexpected authentication state")
	_expect(_profile.call("get_call_sign") == CALL_SIGN, "call sign changed after authentication")
	_expect(_profile.call("get_user_id") == PLAYER_ID, "account ID changed")
	_expect(_profile.call("has_authoritative_identity"), "saved authoritative identity was lost")
	_expect(_profile.call("is_onboarding_complete"), "signup completion was lost")
	var cfg := ConfigFile.new()
	_expect(cfg.load("user://profile.cfg") == OK, "profile file unreadable")
	_expect(str(cfg.get_value("profile", "call_sign", "")) == CALL_SIGN, "call sign not durable")
	_expect(bool(cfg.get_value("profile", "onboarding_complete", false)), "signup completion not durable")
	_expect(bool(cfg.get_value("profile", "handle_chosen", false)), "chosen-name flag not durable")
	var public_key: Dictionary = _credentials.call("public_key_jwk", "swarmfront.player.identity.v1")
	var key_hash: String = JSON.stringify(public_key.get("jwk", {})).sha256_text()
	_expect(bool(public_key.get("ok", false)), "saved device key unavailable")
	if not _results.is_empty():
		_expect(key_hash == str(_results[0].get("public_key_sha256", "")), "restart replaced the device key")
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay: Control = menu.get_node("ProfileFirstRunOverlay")
	var welcome: Label = menu.get_node("TopBar/WelcomeHandleLabel")
	_expect(not overlay.visible, "main menu reopened signup")
	_expect(welcome.text == "Welcome " + CALL_SIGN, "main menu did not display the saved call sign")
	_expect(_service.actions.count("identity/register") == (1 if _phase == "signup" else 0), "menu attempted registration")
	_results.append({
		"phase": _phase, "passed": _errors.is_empty(), "errors": _errors,
		"process_id": OS.get_process_id(), "platform": OS.get_name(),
		"native_credentials": _native, "public_key_sha256": key_hash,
		"registered_call_sign": _service.server_call_sign,
		"loaded_before_authentication": _boot, "account_id": _profile.call("get_user_id"),
		"welcome_text": welcome.text, "signup_visible": overlay.visible,
		"authenticated": _identity.call("is_authenticated"), "requests": _service.actions
	})
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	result_file.store_string(JSON.stringify({"results": _results}, "\t"))
	result_file.close()
	print("ONBOARDING_RESTART_SMOKE: %s phase=%s" % ["PASS" if _errors.is_empty() else "FAIL", _phase])
	print("ONBOARDING_RESTART_EVIDENCE: " + JSON.stringify(_results.back()))
	for error in _errors:
		push_error(error)
	if not _native:
		get_tree().quit(0 if _errors.is_empty() else 1)
