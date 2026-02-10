extends Node

const SFLog = preload("res://scripts/util/sf_log.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

const PROFILE_PATH: String = "user://profile.cfg"
const PROFILE_SECTION: String = "profile"
const USER_ID_PREFIX: String = "u_"
const USER_ID_HEX_LEN: int = 12
const DISPLAY_NAME_PREFIX: String = "Player "
const DISPLAY_NAME_MAX_LEN: int = 20
const BUFF_LOADOUT_SIZE: int = 3
const DEFAULT_BUFF_LOADOUT_IDS: Array[String] = [
	"buff_swarm_speed_classic",
	"buff_hive_faster_production_classic",
	"buff_tower_fire_rate_classic"
]

var _has_loaded: bool = false
var _boot_trace_enter_logged: bool = false
var _created_this_run: bool = false
var _onboarding_complete: bool = false
var _user_id: String = ""
var _display_name: String = ""
var _created_at_unix: int = 0
var _owned_buff_ids: Array[String] = []
var _buff_loadout_ids: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	ensure_loaded()

func ensure_loaded() -> void:
	if not _boot_trace_enter_logged:
		_boot_trace_enter_logged = true
		SFLog.info("PROFILE_BOOT_TRACE_ENTER", {
			"user_id": _user_id,
			"display_name": _display_name,
			"created_at_unix": _created_at_unix,
			"has_loaded": _has_loaded
		})
		SFLog.info("PROFILE_USER_DATA_DIR", {"dir": OS.get_user_data_dir()})
	if _has_loaded:
		return
	_rng.randomize()
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_LOAD", {
		"path": PROFILE_PATH,
		"err": err
	})
	if err == OK:
		_user_id = str(cfg.get_value(PROFILE_SECTION, "user_id", ""))
		_display_name = str(cfg.get_value(PROFILE_SECTION, "display_name", ""))
		_created_at_unix = int(cfg.get_value(PROFILE_SECTION, "created_at_unix", 0))
		_onboarding_complete = bool(cfg.get_value(PROFILE_SECTION, "onboarding_complete", false))
		_owned_buff_ids = _sanitize_owned_ids(cfg.get_value(PROFILE_SECTION, "owned_buff_ids", []))
		_buff_loadout_ids = _sanitize_loadout_ids(cfg.get_value(PROFILE_SECTION, "buff_loadout_ids", []))

	var created: bool = false
	if _user_id.is_empty():
		_user_id = _generate_user_id()
		_created_at_unix = int(Time.get_unix_time_from_system())
		_display_name = _default_display_name(_user_id)
		_onboarding_complete = false
		_owned_buff_ids = _default_owned_ids()
		_buff_loadout_ids = _sanitize_loadout_ids(_owned_buff_ids)
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
		created = true
		_created_this_run = true
	else:
		_created_this_run = false
		var cleaned_name: String = _sanitize_display_name(_display_name, _user_id)
		var updated: bool = false
		if cleaned_name != _display_name:
			_display_name = cleaned_name
			updated = true
		if _created_at_unix <= 0:
			_created_at_unix = int(Time.get_unix_time_from_system())
			updated = true
		if _owned_buff_ids.is_empty():
			_owned_buff_ids = _default_owned_ids()
			updated = true
		var cleaned_loadout: Array[String] = _sanitize_loadout_ids(_buff_loadout_ids)
		if cleaned_loadout != _buff_loadout_ids:
			_buff_loadout_ids = cleaned_loadout
			updated = true
		_ensure_loadout_owned()
		if updated:
			_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)

	_has_loaded = true
	if created:
		SFLog.info("PROFILE_CREATED", {
			"user_id": _user_id,
			"display_name": _display_name,
			"onboarding_complete": _onboarding_complete
		})
	else:
		SFLog.info("PROFILE_LOADED", {
			"user_id": _user_id,
			"display_name": _display_name,
			"onboarding_complete": _onboarding_complete
		})

func get_user_id() -> String:
	ensure_loaded()
	return _user_id

func was_created_this_run() -> bool:
	ensure_loaded()
	return _created_this_run

func is_onboarding_complete() -> bool:
	ensure_loaded()
	return _onboarding_complete

func get_display_name() -> String:
	ensure_loaded()
	return _display_name

func get_handle(uid: String) -> String:
	ensure_loaded()
	if uid == _user_id:
		return _display_name
	return ""

func set_display_name(name: String) -> void:
	ensure_loaded()
	var cleaned: String = _sanitize_display_name(name, _user_id)
	if cleaned == _display_name:
		return
	_display_name = cleaned
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_DISPLAY_NAME_SET", {
		"user_id": _user_id,
		"display_name": _display_name
	})

func set_user_id(raw: String) -> bool:
	ensure_loaded()
	var uid: String = _sanitize_user_id(raw)
	if not _is_valid_user_id(uid):
		SFLog.info("PROFILE_USER_ID_REJECTED", {"attempted": raw})
		return false
	if uid == _user_id:
		SFLog.info("PROFILE_USER_ID_NOOP", {"user_id": _user_id})
		return true
	var old_id: String = _user_id
	_user_id = uid
	if _display_name.strip_edges().is_empty():
		_display_name = _default_display_name(_user_id)
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_USER_ID_SET", {
		"old": old_id,
		"new": _user_id
	})
	return true

func mark_onboarding_complete() -> void:
	ensure_loaded()
	if _onboarding_complete:
		return
	_onboarding_complete = true
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	SFLog.info("PROFILE_ONBOARDING_COMPLETE", {"user_id": _user_id})

func get_owned_buff_ids() -> Array[String]:
	ensure_loaded()
	return _owned_buff_ids.duplicate()

func set_owned_buff_ids(ids: Array) -> void:
	ensure_loaded()
	_owned_buff_ids = _sanitize_owned_ids(ids)
	_ensure_loadout_owned()
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)

func add_owned_buffs(ids: Array) -> int:
	ensure_loaded()
	var added: int = 0
	for buff_id_v in ids:
		var buff_id: String = str(buff_id_v).strip_edges()
		if buff_id == "":
			continue
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if _owned_buff_ids.has(buff_id):
			continue
		_owned_buff_ids.append(buff_id)
		added += 1
	if added > 0:
		_ensure_loadout_owned()
		_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	return added

func get_buff_loadout_ids() -> Array[String]:
	ensure_loaded()
	return _buff_loadout_ids.duplicate()

func set_buff_loadout_ids(ids: Array) -> bool:
	ensure_loaded()
	var next_ids: Array[String] = _sanitize_loadout_ids(ids)
	if next_ids == _buff_loadout_ids:
		return true
	_buff_loadout_ids = next_ids
	_ensure_loadout_owned()
	_save_profile(_user_id, _display_name, _created_at_unix, _onboarding_complete)
	return true

func _save_profile(user_id: String, display_name: String, created_at: int, onboarding_complete: bool) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(PROFILE_SECTION, "user_id", user_id)
	cfg.set_value(PROFILE_SECTION, "display_name", display_name)
	if created_at > 0:
		cfg.set_value(PROFILE_SECTION, "created_at_unix", created_at)
	cfg.set_value(PROFILE_SECTION, "onboarding_complete", onboarding_complete)
	cfg.set_value(PROFILE_SECTION, "owned_buff_ids", _owned_buff_ids)
	cfg.set_value(PROFILE_SECTION, "buff_loadout_ids", _buff_loadout_ids)
	var err: int = cfg.save(PROFILE_PATH)
	SFLog.info("PROFILE_BOOT_TRACE_SAVE", {
		"path": PROFILE_PATH,
		"err": err
	})
	if err == OK:
		SFLog.info("PROFILE_SAVED", {
			"path": PROFILE_PATH,
			"user_id": user_id,
			"display_name": display_name
		})

func _generate_user_id() -> String:
	var hex: String = ""
	for i in range(6):
		var value: int = int(_rng.randi_range(0, 255))
		hex += "%02x" % value
	return USER_ID_PREFIX + hex

func _default_display_name(user_id: String) -> String:
	var suffix: String = user_id
	if user_id.begins_with(USER_ID_PREFIX):
		suffix = user_id.substr(USER_ID_PREFIX.length(), user_id.length() - USER_ID_PREFIX.length())
	if suffix.length() >= 4:
		suffix = suffix.substr(suffix.length() - 4, 4)
	else:
		suffix = suffix.pad_zeros(4)
	return DISPLAY_NAME_PREFIX + suffix.to_upper()

func _sanitize_display_name(name: String, user_id: String) -> String:
	var cleaned: String = name.strip_edges()
	if cleaned.length() > DISPLAY_NAME_MAX_LEN:
		cleaned = cleaned.substr(0, DISPLAY_NAME_MAX_LEN)
	if cleaned.is_empty():
		cleaned = _default_display_name(user_id)
	return cleaned

func _sanitize_user_id(raw: String) -> String:
	var cleaned: String = raw.strip_edges().to_lower()
	return cleaned

func _is_valid_user_id(uid: String) -> bool:
	if not uid.begins_with(USER_ID_PREFIX):
		return false
	var suffix: String = uid.substr(USER_ID_PREFIX.length(), uid.length() - USER_ID_PREFIX.length())
	if suffix.length() != USER_ID_HEX_LEN:
		return false
	for i in range(suffix.length()):
		var ch: String = suffix.substr(i, 1)
		var code: int = ch.unicode_at(0)
		var is_digit: bool = code >= 48 and code <= 57
		var is_lower_hex: bool = code >= 97 and code <= 102
		var is_upper_hex: bool = code >= 65 and code <= 70
		if not (is_digit or is_lower_hex or is_upper_hex):
			return false
	return true

func _default_owned_ids() -> Array[String]:
	var out: Array[String] = []
	for buff_id in DEFAULT_BUFF_LOADOUT_IDS:
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if out.has(buff_id):
			continue
		out.append(buff_id)
	return out

func _sanitize_owned_ids(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return _default_owned_ids()
	for buff_id_v in raw as Array:
		var buff_id: String = str(buff_id_v).strip_edges()
		if buff_id == "":
			continue
		if BuffCatalog.get_buff(buff_id).is_empty():
			continue
		if out.has(buff_id):
			continue
		out.append(buff_id)
	if out.is_empty():
		out = _default_owned_ids()
	return out

func _sanitize_loadout_ids(raw: Variant) -> Array[String]:
	var base: Array[String] = _default_owned_ids()
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for buff_id_v in raw as Array:
			var buff_id: String = str(buff_id_v).strip_edges()
			if buff_id == "":
				continue
			if BuffCatalog.get_buff(buff_id).is_empty():
				continue
			if out.has(buff_id):
				continue
			out.append(buff_id)
	if out.size() > BUFF_LOADOUT_SIZE:
		out = out.slice(0, BUFF_LOADOUT_SIZE)
	var fill_i: int = 0
	while out.size() < BUFF_LOADOUT_SIZE and fill_i < base.size():
		var fallback_id: String = base[fill_i]
		if not out.has(fallback_id):
			out.append(fallback_id)
		fill_i += 1
	while out.size() < BUFF_LOADOUT_SIZE:
		for fallback_id in DEFAULT_BUFF_LOADOUT_IDS:
			if BuffCatalog.get_buff(fallback_id).is_empty():
				continue
			if out.has(fallback_id):
				continue
			out.append(fallback_id)
			break
		if out.size() >= BUFF_LOADOUT_SIZE:
			break
		break
	return out

func _ensure_loadout_owned() -> void:
	for buff_id in _buff_loadout_ids:
		if _owned_buff_ids.has(buff_id):
			continue
		_owned_buff_ids.append(buff_id)

# Legacy compatibility (single-profile semantics).
func get_profiles() -> Array[Dictionary]:
	ensure_loaded()
	var profile: Dictionary = {
		"profile_id": _user_id,
		"handle": _display_name,
		"created_at_unix": _created_at_unix,
		"last_used_at_unix": _created_at_unix
	}
	return [profile]

func get_active_profile_id() -> String:
	return get_user_id()

func get_active_profile() -> Dictionary:
	var profiles: Array[Dictionary] = get_profiles()
	if profiles.is_empty():
		return {}
	return profiles[0]

func get_active_handle() -> String:
	return get_display_name()

func set_active_profile(profile_id: String) -> void:
	ensure_loaded()
	if profile_id != _user_id:
		return

func create_profile() -> String:
	return get_user_id()

func rename_profile(profile_id: String, new_handle: String) -> bool:
	ensure_loaded()
	if profile_id != _user_id:
		return false
	set_display_name(new_handle)
	return true

func delete_profile(_profile_id: String) -> bool:
	return false
