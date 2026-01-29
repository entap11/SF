extends Node

const FILE_PATH: String = "user://profiles.json"
const DATA_VERSION: int = 1
const HANDLE_PREFIX: String = "Player "
const HANDLE_MIN_LEN: int = 3
const HANDLE_MAX_LEN: int = 20

var _profiles: Array[Dictionary] = []
var _active_profile_id: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var loaded: bool = _load()
	if not loaded:
		_create_default_profile()
		_save()
		return
	var changed: bool = _ensure_active_valid()
	if changed:
		_save()

func get_profiles() -> Array[Dictionary]:
	return _profiles.duplicate(true)

func get_active_profile_id() -> String:
	return _active_profile_id

func get_active_profile() -> Dictionary:
	var idx: int = _find_profile_index(_active_profile_id)
	if idx >= 0:
		return _profiles[idx]
	if _profiles.size() > 0:
		return _profiles[0]
	return {}

func get_active_handle() -> String:
	var profile: Dictionary = get_active_profile()
	return str(profile.get("handle", ""))

func set_active_profile(profile_id: String) -> void:
	var idx: int = _find_profile_index(profile_id)
	if idx < 0:
		return
	_active_profile_id = profile_id
	_touch_profile(idx)
	_save()

func create_profile() -> String:
	var id: String = _create_profile_internal(true)
	_save()
	return id

func rename_profile(profile_id: String, new_handle: String) -> bool:
	var trimmed: String = new_handle.strip_edges()
	if trimmed.length() < HANDLE_MIN_LEN or trimmed.length() > HANDLE_MAX_LEN:
		return false
	var idx: int = _find_profile_index(profile_id)
	if idx < 0:
		return false
	var profile: Dictionary = _profiles[idx]
	profile["handle"] = trimmed
	_profiles[idx] = profile
	_save()
	return true

func delete_profile(profile_id: String) -> bool:
	if _profiles.size() <= 1:
		return false
	var idx: int = _find_profile_index(profile_id)
	if idx < 0:
		return false
	_profiles.remove_at(idx)
	if _active_profile_id == profile_id:
		_active_profile_id = str(_profiles[0].get("profile_id", ""))
		var active_idx: int = _find_profile_index(_active_profile_id)
		if active_idx >= 0:
			_touch_profile(active_idx)
	_save()
	return true

func _load() -> bool:
	if not FileAccess.file_exists(FILE_PATH):
		return false
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	_active_profile_id = str(data.get("active_profile_id", ""))
	var profiles_v: Variant = data.get("profiles", [])
	_profiles = _parse_profiles(profiles_v)
	return _profiles.size() > 0

func _save() -> void:
	var data: Dictionary = {
		"version": DATA_VERSION,
		"active_profile_id": _active_profile_id,
		"profiles": _profiles
	}
	var text: String = JSON.stringify(data)
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _parse_profiles(profiles_v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(profiles_v) != TYPE_ARRAY:
		return out
	var profiles_arr: Array = profiles_v
	for entry in profiles_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = entry
		var pid: String = str(d.get("profile_id", ""))
		var handle: String = str(d.get("handle", "")).strip_edges()
		if pid.is_empty() or handle.is_empty():
			continue
		var created: int = int(d.get("created_at_unix", 0))
		var last_used: int = int(d.get("last_used_at_unix", created))
		out.append({
			"profile_id": pid,
			"handle": handle,
			"created_at_unix": created,
			"last_used_at_unix": last_used
		})
	return out

func _ensure_active_valid() -> bool:
	if _profiles.size() == 0:
		return false
	var idx: int = _find_profile_index(_active_profile_id)
	if idx >= 0:
		return false
	_active_profile_id = str(_profiles[0].get("profile_id", ""))
	var active_idx: int = _find_profile_index(_active_profile_id)
	if active_idx >= 0:
		_touch_profile(active_idx)
	return true

func _create_default_profile() -> void:
	_create_profile_internal(true)

func _create_profile_internal(make_active: bool) -> String:
	var now: int = int(Time.get_unix_time_from_system())
	var id: String = _generate_uuid()
	var handle: String = _generate_default_handle()
	var profile: Dictionary = {
		"profile_id": id,
		"handle": handle,
		"created_at_unix": now,
		"last_used_at_unix": now
	}
	_profiles.append(profile)
	if make_active:
		_active_profile_id = id
	return id

func _touch_profile(idx: int) -> void:
	if idx < 0 or idx >= _profiles.size():
		return
	var profile: Dictionary = _profiles[idx]
	profile["last_used_at_unix"] = int(Time.get_unix_time_from_system())
	_profiles[idx] = profile

func _find_profile_index(profile_id: String) -> int:
	if profile_id.is_empty():
		return -1
	for i in range(_profiles.size()):
		var profile: Dictionary = _profiles[i]
		if str(profile.get("profile_id", "")) == profile_id:
			return i
	return -1

func _generate_default_handle() -> String:
	var num: int = _rng.randi_range(0, 9999)
	var suffix: String = str(num).pad_zeros(4)
	return HANDLE_PREFIX + suffix

func _generate_uuid() -> String:
	var bytes: Array[String] = []
	for i in range(16):
		var value: int = int(_rng.randi_range(0, 255))
		bytes.append("%02x" % value)
	return "%s%s%s%s-%s%s-%s%s-%s%s-%s%s%s%s%s%s" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]
