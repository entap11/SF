extends SceneTree

const SecureCredentialStoreScript := preload("res://scripts/platform/secure_credential_store.gd")
const NativeSecureCredentialStoreScript := preload("res://scripts/platform/native_secure_credential_store.gd")
const SecureCredentialStoreFactoryScript := preload("res://scripts/platform/secure_credential_store_factory.gd")
const PlayerSessionStateScript := preload("res://scripts/state/player_session_state.gd")
const VsHandshakeTransportHttpScript := preload("res://scripts/state/vs_handshake_transport_http.gd")

var _failed: bool = false

class FakeNativeCredentialPlugin extends RefCounted:
	func is_available() -> bool:
		return true

	func create_device_key(key_alias: String) -> String:
		return JSON.stringify({"ok": true, "key_alias": key_alias, "algorithm": "ECDSA_P256_SHA256"})

	func public_key_jwk(_key_alias: String) -> String:
		return JSON.stringify({"ok": true, "jwk": {"kty": "EC", "crv": "P-256", "x": "x", "y": "y"}})

	func sign_challenge(_key_alias: String, _challenge_utf8: String) -> String:
		return JSON.stringify({"ok": true, "signature": "der-signature"})

	func delete_device_key(_key_alias: String) -> String:
		return JSON.stringify({"ok": true})

func _initialize() -> void:
	var secure_store = SecureCredentialStoreScript.new()
	_expect(not secure_store.is_available(), "base secure credential store must fail closed")
	_expect(str(secure_store.create_device_key("player").get("err", "")) == "secure_credential_store_unavailable",
		"base secure credential store unexpectedly created a key")
	var editor_store = SecureCredentialStoreFactoryScript.create()
	_expect(not editor_store.is_available(), "editor credential factory must fail closed")
	var native_store = NativeSecureCredentialStoreScript.new(FakeNativeCredentialPlugin.new())
	_expect(native_store.is_available(), "native credential adapter rejected available singleton")
	_expect(bool(native_store.create_device_key("player").get("ok", false)), "native key creation response was rejected")
	_expect(str(native_store.public_key_jwk("player").get("jwk", {}).get("crv", "")) == "P-256",
		"native public JWK response was not decoded")
	_expect(str(native_store.sign_challenge("player", "challenge").get("signature", "")) == "der-signature",
		"native signature response was not decoded")
	_expect(bool(native_store.delete_device_key("player").get("ok", false)), "native key deletion response was rejected")

	var session = PlayerSessionStateScript.new()
	var accepted: Dictionary = session.accept_session_response({
		"access_token": "header.payload.signature",
		"session": {
			"id": "session-smoke",
			"player_id": "0190f47a-1234-7abc-8def-123456789abc",
			"device_id": "0190f47a-2234-7abc-8def-123456789abc",
			"expires_at_unix": int(Time.get_unix_time_from_system()) + 600
		}
	})
	_expect(bool(accepted.get("ok", false)), "valid in-memory session response was rejected")
	_expect(session.access_token() == "header.payload.signature", "access token was not held in memory")
	var snapshot: Dictionary = session.debug_snapshot()
	_expect(not snapshot.has("access_token"), "debug snapshot leaked access token")
	_expect(bool(snapshot.get("has_access_token", false)), "debug snapshot lost token-presence diagnostic")
	session.revoke_local()
	_expect(session.access_token().is_empty(), "revoked session retained access token")

	var transport = VsHandshakeTransportHttpScript.new()
	transport.configure("", 1.0, "legacy-token")
	transport.set_auth_token("player-token")
	transport.clear_auth_token()
	_expect(not transport.configured(), "empty transport URL unexpectedly configured")

	quit(1 if _failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
