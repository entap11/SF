extends RefCounted
class_name SecureCredentialStore

## Platform boundary for a non-exportable device identity key.
## Release builds must provide an iOS Keychain/Secure Enclave or Android Keystore
## implementation. This base class fails closed and never stores private key bytes.

const DEVICE_KEY_ALGORITHM: String = "ECDSA_P256_SHA256"

func is_available() -> bool:
	return false

func create_device_key(_key_alias: String) -> Dictionary:
	return {
		"ok": false,
		"err": "secure_credential_store_unavailable",
		"algorithm": DEVICE_KEY_ALGORITHM
	}

func public_key_jwk(_key_alias: String) -> Dictionary:
	return {"ok": false, "err": "secure_credential_store_unavailable"}

func sign_challenge(_key_alias: String, _challenge_utf8: String) -> Dictionary:
	# Implementations return a base64url ECDSA/SHA-256 signature in `signature`.
	return {"ok": false, "err": "secure_credential_store_unavailable"}

func delete_device_key(_key_alias: String) -> Dictionary:
	return {"ok": false, "err": "secure_credential_store_unavailable"}
