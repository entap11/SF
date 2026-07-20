extends RefCounted
class_name SecureCredentialStoreFactory

const NativeStoreScript := preload("res://scripts/platform/native_secure_credential_store.gd")
const FailClosedStoreScript := preload("res://scripts/platform/secure_credential_store.gd")

static func create() -> RefCounted:
	if OS.get_name() in ["iOS", "Android"]:
		return NativeStoreScript.new()
	return FailClosedStoreScript.new()
