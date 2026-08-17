extends Node

signal authentication_changed(snapshot: Dictionary)

const SFLog = preload("res://scripts/util/sf_log.gd")
const SecureCredentialStoreFactoryScript = preload("res://scripts/platform/secure_credential_store_factory.gd")
const PlayerSessionStateScript = preload("res://scripts/state/player_session_state.gd")
const RankTransportHttpScript = preload("res://scripts/state/rank_transport_http.gd")

const STATE_PATH: String = "user://player_identity_bootstrap.json"
const KEY_ALIAS: String = "swarmfront.player.identity.v1"
const SETTINGS_IDENTITY_URL: String = "swarmfront/identity/backend_url"
const DEFAULT_IDENTITY_URL: String = "https://swarmfront-cert-rank.onrender.com/v1"
const SESSION_REFRESH_SEC: float = 300.0

var _credential_store: RefCounted = null
var _session = PlayerSessionStateScript.new()
var _transport = RankTransportHttpScript.new()
var _device_id: String = ""
var _registration_request_id: String = ""
var _last_error: String = ""
var _auth_in_progress: bool = false

func _ready() -> void:
	SFLog.allow_tag("PLAYER_IDENTITY")
	_credential_store = SecureCredentialStoreFactoryScript.create()
	_transport.configure(str(ProjectSettings.get_setting(SETTINGS_IDENTITY_URL, DEFAULT_IDENTITY_URL)), 6.0)
	_load_bootstrap_state()
	var timer := Timer.new()
	timer.wait_time = SESSION_REFRESH_SEC
	timer.one_shot = false
	timer.timeout.connect(_authenticate)
	add_child(timer)
	timer.start()
	call_deferred("_authenticate")

func is_authenticated() -> bool:
	return not _session.access_token().is_empty()

func access_token() -> String:
	return _session.access_token()

func debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = _session.debug_snapshot()
	snapshot["secure_credentials_available"] = _credential_store != null \
		and _credential_store.has_method("is_available") and bool(_credential_store.call("is_available"))
	snapshot["device_registered"] = not _device_id.is_empty()
	snapshot["last_error"] = _last_error
	snapshot["auth_in_progress"] = _auth_in_progress
	return snapshot

func refresh_platform_snapshot() -> Dictionary:
	if not is_authenticated():
		return {"ok": false, "err": "player_session_required"}
	var profile: Node = get_node_or_null("/root/ProfileManager")
	if profile == null or not _transport.has_method("call_read"):
		return {"ok": false, "err": "platform_projection_unavailable"}
	var player_id: String = str(profile.call("get_user_id")).strip_edges()
	var result: Dictionary = _transport.call_read("platform/economy/me") as Dictionary
	if not bool(result.get("ok", false)):
		return result
	if profile.has_method("set_honey_balance"):
		profile.call("set_honey_balance", int(maxi(0, int(result.get("honey_centi", 0))) / 100))
	if profile.has_method("apply_platform_entitlements"):
		profile.call("apply_platform_entitlements", result.get("entitlements", []))
	var pass_state: Node = get_node_or_null("/root/BattlePassState")
	if pass_state != null and pass_state.has_method("apply_platform_progression_snapshot"):
		pass_state.call("apply_platform_progression_snapshot", result)
	var rank_state: Node = get_node_or_null("/root/RankState")
	if rank_state != null and rank_state.has_method("apply_platform_wax_projection"):
		rank_state.call("apply_platform_wax_projection", player_id, int(result.get("wax_millis", 0)))
	return result

func _authenticate() -> void:
	if _auth_in_progress or is_authenticated():
		return
	_auth_in_progress = true
	_last_error = ""
	var result: Dictionary = _authenticate_once()
	_auth_in_progress = false
	if not bool(result.get("ok", false)):
		_last_error = str(result.get("err", "player_authentication_failed"))
		SFLog.warn("PLAYER_IDENTITY", {"status": "unavailable", "err": _last_error}, "", 30000)
		authentication_changed.emit(debug_snapshot())
		return
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	if handshake != null and handshake.has_method("set_player_access_token"):
		handshake.call("set_player_access_token", _session.access_token())
	_transport.configure(str(ProjectSettings.get_setting(SETTINGS_IDENTITY_URL, DEFAULT_IDENTITY_URL)), 6.0, _session.access_token())
	refresh_platform_snapshot()
	SFLog.info("PLAYER_IDENTITY", {"status": "authenticated", "player_id": _session.player_id()})
	authentication_changed.emit(debug_snapshot())

func _authenticate_once() -> Dictionary:
	if _credential_store == null or not _credential_store.has_method("is_available") \
			or not bool(_credential_store.call("is_available")):
		return {"ok": false, "err": "secure_credential_store_unavailable"}
	var key_result: Dictionary = _credential_store.call("create_device_key", KEY_ALIAS) as Dictionary
	if not bool(key_result.get("ok", false)):
		return key_result
	var challenge: Dictionary = {}
	if _device_id.is_empty():
		var public_key: Dictionary = _credential_store.call("public_key_jwk", KEY_ALIAS) as Dictionary
		if not bool(public_key.get("ok", false)) or typeof(public_key.get("jwk", null)) != TYPE_DICTIONARY:
			return {"ok": false, "err": "device_public_key_unavailable"}
		if _registration_request_id.is_empty():
			_registration_request_id = _new_request_id("register")
			_save_bootstrap_state()
		var profile: Node = get_node_or_null("/root/ProfileManager")
		var call_sign: String = "Player"
		if profile != null and profile.has_method("get_call_sign"):
			call_sign = str(profile.call("get_call_sign")).strip_edges()
		var registered: Dictionary = _transport.call_action("identity/register", {
			"request_id": _registration_request_id,
			"call_sign": call_sign,
			"region": "GLOBAL",
			"device": {"public_key_jwk": public_key.get("jwk", {}), "platform": OS.get_name(), "label": "primary"},
			"install_metadata": {"client_build": str(ProjectSettings.get_setting("application/config/version", "dev"))}
		})
		if not bool(registered.get("ok", false)):
			return registered
		var device: Dictionary = registered.get("device", {}) as Dictionary
		_device_id = str(device.get("id", "")).strip_edges()
		if _device_id.is_empty():
			return {"ok": false, "err": "registered_device_missing"}
		_save_bootstrap_state()
		challenge = registered.get("challenge", {}) as Dictionary
		_apply_backend_identity(registered.get("player", {}) as Dictionary)
	else:
		var challenge_result: Dictionary = _transport.call_action("identity/challenge", {
			"device_id": _device_id, "request_id": _new_request_id("session")
		})
		if not bool(challenge_result.get("ok", false)):
			return challenge_result
		challenge = challenge_result.get("challenge", {}) as Dictionary
	var challenge_id: String = str(challenge.get("id", "")).strip_edges()
	var challenge_text: String = str(challenge.get("challenge", ""))
	if challenge_id.is_empty() or challenge_text.is_empty():
		return {"ok": false, "err": "device_challenge_invalid"}
	var signed: Dictionary = _credential_store.call("sign_challenge", KEY_ALIAS, challenge_text) as Dictionary
	if not bool(signed.get("ok", false)) or str(signed.get("signature", "")).is_empty():
		return {"ok": false, "err": "device_challenge_signing_failed"}
	var session_response: Dictionary = _transport.call_action("identity/session", {
		"challenge_id": challenge_id, "signature": str(signed.get("signature", ""))
	})
	if not bool(session_response.get("ok", false)):
		return session_response
	var accepted: Dictionary = _session.accept_session_response(session_response)
	if not bool(accepted.get("ok", false)):
		return accepted
	_apply_backend_identity(session_response.get("player", {}) as Dictionary)
	return {"ok": true, "player_id": _session.player_id()}

func _apply_backend_identity(identity: Dictionary) -> void:
	var profile: Node = get_node_or_null("/root/ProfileManager")
	if profile != null and profile.has_method("apply_backend_identity"):
		profile.call("apply_backend_identity", identity)

func _new_request_id(scope: String) -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	return "%s-%s-%d" % [scope, Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", ""), Time.get_ticks_usec()]

func _load_bootstrap_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if typeof(decoded) != TYPE_DICTIONARY:
		return
	_device_id = str((decoded as Dictionary).get("device_id", "")).strip_edges()
	_registration_request_id = str((decoded as Dictionary).get("registration_request_id", "")).strip_edges()

func _save_bootstrap_state() -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": 1, "device_id": _device_id,
		"registration_request_id": _registration_request_id, "key_alias": KEY_ALIAS
	}))
