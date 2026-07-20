extends "res://scripts/platform/secure_credential_store.gd"
class_name NativeSecureCredentialStore

## Adapter for the platform singleton implemented by the iOS and Android
## SwarmfrontSecureCredentials plugins. Native methods return JSON so both
## plugin ABIs expose the exact same, narrow contract to GDScript.

const SINGLETON_NAME: String = "SwarmfrontSecureCredentials"

var _plugin: Object = null

func _init(plugin_override: Object = null) -> void:
	if plugin_override != null:
		_plugin = plugin_override
	elif Engine.has_singleton(SINGLETON_NAME):
		_plugin = Engine.get_singleton(SINGLETON_NAME)

func is_available() -> bool:
	return _plugin != null \
		and _plugin.has_method("is_available") \
		and bool(_plugin.call("is_available"))

func create_device_key(key_alias: String) -> Dictionary:
	return _call_result("create_device_key", [key_alias])

func public_key_jwk(key_alias: String) -> Dictionary:
	return _call_result("public_key_jwk", [key_alias])

func sign_challenge(key_alias: String, challenge_utf8: String) -> Dictionary:
	return _call_result("sign_challenge", [key_alias, challenge_utf8])

func delete_device_key(key_alias: String) -> Dictionary:
	return _call_result("delete_device_key", [key_alias])

func _call_result(method_name: String, arguments: Array) -> Dictionary:
	if not is_available():
		return {"ok": false, "err": "secure_credential_store_unavailable"}
	if not _plugin.has_method(method_name):
		return {"ok": false, "err": "secure_credential_method_unavailable"}
	var raw: Variant = _plugin.callv(method_name, arguments)
	if typeof(raw) == TYPE_DICTIONARY:
		return raw as Dictionary
	if typeof(raw) != TYPE_STRING:
		return {"ok": false, "err": "secure_credential_invalid_response"}
	var decoded: Variant = JSON.parse_string(str(raw))
	if typeof(decoded) != TYPE_DICTIONARY:
		return {"ok": false, "err": "secure_credential_invalid_response"}
	return decoded as Dictionary
