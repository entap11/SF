extends Node

signal config_changed(snapshot: Dictionary)

const DEFAULT_CONFIG_PATH: String = "res://data/ops/ops_config_defaults.json"
const CACHE_PATH: String = "user://ops_config_cache_v1.json"
const ENV_REMOTE_URL: String = "SF_OPS_CONFIG_URL"
const SETTINGS_REMOTE_URL: String = "swarmfront/ops_config/remote_url"
const SETTINGS_FETCH_TIMEOUT_SEC: String = "swarmfront/ops_config/fetch_timeout_sec"
const SETTINGS_CLIENT_BUILD: String = "application/config/version"
const SETTINGS_VS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const ENV_VS_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const VS_REMOTE_SENTINEL: String = "vs://public_ops_config"
const SOURCE_BUNDLED_DEFAULT: String = "bundled_default"
const SOURCE_REMOTE_FRESH: String = "remote_fresh"
const SOURCE_REMOTE_CACHED: String = "remote_cached"
const SOURCE_MALFORMED_FALLBACK: String = "malformed_fallback"
const SOURCE_FETCH_FAILED_FALLBACK: String = "fetch_failed_fallback"
const SCHEMA_VERSION: int = 1
const DEFAULT_TIMEOUT_SEC: float = 2.0
const PUBLIC_ROLLOUT_FLAGS: Array = [
	"enable_public_1v1", "enable_public_crucible", "enable_public_3p_ffa",
	"enable_public_2v2", "enable_public_4p_ffa", "enable_public_ctf", "enable_public_hctf",
	"enable_public_time_puzzles", "enable_public_gauntlet", "enable_public_async_3map",
	"enable_public_async_5map", "enable_rank_mutations", "enable_crucible_wax_settlement",
	"enable_contest_rewards", "enable_bot_fallback", "enable_public_leaderboards"
]

var _defaults: Dictionary = {}
var _config: Dictionary = {}
var _config_source: String = SOURCE_BUNDLED_DEFAULT
var _config_hash: String = ""
var _last_error: String = ""
var _last_fetch_unix_ms: int = 0
var _cache_loaded_unix_ms: int = 0

func _ready() -> void:
	reload()

func reload() -> Dictionary:
	_defaults = _load_json_file(DEFAULT_CONFIG_PATH)
	if not _valid_config(_defaults):
		_defaults = _minimal_defaults()
	_last_error = ""
	_last_fetch_unix_ms = _unix_ms()
	var remote_url: String = _configured_remote_url()
	if remote_url.is_empty():
		_apply_config(_defaults, SOURCE_BUNDLED_DEFAULT)
		return get_debug_snapshot()
	var fetched: Dictionary = _fetch_config(remote_url)
	if bool(fetched.get("ok", false)):
		var parsed: Dictionary = fetched.get("config", {}) as Dictionary
		if _valid_config(parsed):
			_apply_config(_sanitize_config(parsed), SOURCE_REMOTE_FRESH)
			_save_cache(_config)
			return get_debug_snapshot()
		_last_error = "malformed_remote_config"
		var cached_malformed: Dictionary = _load_valid_cache()
		if not cached_malformed.is_empty():
			_apply_config(cached_malformed, SOURCE_REMOTE_CACHED)
		else:
			_apply_config(_defaults, SOURCE_MALFORMED_FALLBACK)
		return get_debug_snapshot()
	_last_error = str(fetched.get("err", "fetch_failed"))
	var cached: Dictionary = _load_valid_cache()
	if not cached.is_empty():
		_apply_config(cached, SOURCE_REMOTE_CACHED)
	else:
		_apply_config(_defaults, SOURCE_FETCH_FAILED_FALLBACK)
	return get_debug_snapshot()

func force_config_for_smoke(config: Dictionary, source: String = SOURCE_REMOTE_FRESH) -> void:
	if not OS.is_debug_build():
		return
	if _defaults.is_empty():
		_defaults = _load_json_file(DEFAULT_CONFIG_PATH)
	if not _valid_config(_defaults):
		_defaults = _minimal_defaults()
	var next: Dictionary = config if _valid_config(config) else _defaults
	_apply_config(_sanitize_config(next), source)

func get_config_snapshot() -> Dictionary:
	return _config.duplicate(true)

func validate_config_payload(config: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if config.is_empty():
		errors.append("config_empty")
	if int(config.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version_mismatch")
	if str(config.get("config_version", "")).strip_edges().is_empty():
		errors.append("missing_config_version")
	if typeof(config.get("feature_flags", {})) != TYPE_DICTIONARY:
		errors.append("feature_flags_not_dictionary")
	if typeof(config.get("ads", {})) != TYPE_DICTIONARY:
		errors.append("ads_not_dictionary")
	if typeof(config.get("maintenance", {})) != TYPE_DICTIONARY:
		errors.append("maintenance_not_dictionary")
	if typeof(config.get("match_tuning", {})) != TYPE_DICTIONARY:
		errors.append("match_tuning_not_dictionary")
	if typeof(config.get("analytics", {})) != TYPE_DICTIONARY:
		errors.append("analytics_not_dictionary")
	var flags: Dictionary = _dict(config.get("feature_flags", {}))
	for rollout_flag in PUBLIC_ROLLOUT_FLAGS:
		if flags.has(rollout_flag) and typeof(flags.get(rollout_flag)) != TYPE_BOOL:
			errors.append("rollout_flag_not_boolean:%s" % rollout_flag)
	var ads: Dictionary = _dict(config.get("ads", {}))
	if bool(flags.get("enable_ads", false)) and not bool(ads.get("external_ads_enabled", false)):
		warnings.append("enable_ads_true_but_external_ads_disabled")
	if bool(ads.get("external_ads_enabled", false)) and not bool(flags.get("enable_ads", false)):
		warnings.append("external_ads_enabled_but_enable_ads_false")
	if bool(config.get("force_update", false)) and int(config.get("min_supported_build", 0)) <= 0:
		warnings.append("force_update_without_min_supported_build")
	var maintenance: Dictionary = _dict(config.get("maintenance", {}))
	if bool(maintenance.get("enabled", false)) and str(maintenance.get("title", "")).strip_edges().is_empty():
		warnings.append("maintenance_enabled_without_title")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"schema_version": int(config.get("schema_version", 0)),
		"config_version": str(config.get("config_version", "")),
		"config_hash": JSON.stringify(config).sha256_text()
	}

func get_fail_closed_policy() -> Dictionary:
	return {
		"paid_entries": false,
		"honey_rewards": false,
		"local_honey_rewards": false,
		"observer_mode": false,
		"rank_backend": false,
		"rank_local_beta_fallback": true,
		"external_ads": false,
		"house_ads": true,
		"maintenance_mode_requires_valid_config": true,
		"force_update_requires_valid_config": true,
		"public_modes_require_fresh_or_unexpired_cached_config": true,
		"public_modes_require_supported_client_build": true
	}

func get_debug_snapshot() -> Dictionary:
	return {
		"config_source": _config_source,
		"config_version": get_config_version(),
		"config_hash": _config_hash,
		"schema_version": int(_config.get("schema_version", 0)),
		"last_error": _last_error,
		"last_fetch_unix_ms": _last_fetch_unix_ms,
		"cache_loaded_unix_ms": _cache_loaded_unix_ms,
		"remote_url": _redacted_url(_configured_remote_url()),
		"client_build": get_client_build(),
		"min_supported_build": int(_config.get("min_supported_build", 0)),
		"force_update_required": is_force_update_required(),
		"public_rollout_eligible": public_rollout_eligible(),
		"public_rollout_blocker": public_rollout_blocker(),
		"effective_public_flags": get_effective_public_flags(),
		"expires_utc": str(_config.get("expires_utc", ""))
	}

func get_config_source() -> String:
	return _config_source

func get_config_version() -> String:
	return str(_config.get("config_version", ""))

func get_config_hash() -> String:
	return _config_hash

func get_client_build() -> int:
	var from_export: String = str(ProjectSettings.get_setting(SETTINGS_CLIENT_BUILD, "0")).strip_edges()
	if from_export.is_valid_int():
		return int(from_export)
	return 0

func get_flag(flag_name: String, fallback: bool = false) -> bool:
	var flags: Dictionary = _dict(_config.get("feature_flags", {}))
	return bool(flags.get(flag_name.strip_edges(), fallback))

func public_rollout_eligible(client_build: int = -1) -> bool:
	if _config_source != SOURCE_REMOTE_FRESH and _config_source != SOURCE_REMOTE_CACHED:
		return false
	var expires_utc: String = str(_config.get("expires_utc", "")).strip_edges()
	if _config_source == SOURCE_REMOTE_CACHED and expires_utc.is_empty():
		return false
	if not expires_utc.is_empty():
		var expiry: int = _parse_iso_unix(expires_utc)
		if expiry <= 0 or int(Time.get_unix_time_from_system()) >= expiry:
			return false
	var build: int = get_client_build() if client_build < 0 else client_build
	return build >= int(_config.get("min_supported_build", 0))

func public_rollout_blocker(client_build: int = -1) -> String:
	if _config_source != SOURCE_REMOTE_FRESH and _config_source != SOURCE_REMOTE_CACHED:
		return "remote_config_unavailable"
	var expires_utc: String = str(_config.get("expires_utc", "")).strip_edges()
	if _config_source == SOURCE_REMOTE_CACHED and expires_utc.is_empty():
		return "cached_config_has_no_expiry"
	if not expires_utc.is_empty():
		var expiry: int = _parse_iso_unix(expires_utc)
		if expiry <= 0 or int(Time.get_unix_time_from_system()) >= expiry:
			return "config_expired"
	var build: int = get_client_build() if client_build < 0 else client_build
	if build < int(_config.get("min_supported_build", 0)):
		return "minimum_client_build_required"
	return ""

func public_flag_enabled(flag_name: String, client_build: int = -1) -> bool:
	var clean: String = flag_name.strip_edges().to_lower()
	if not PUBLIC_ROLLOUT_FLAGS.has(clean):
		return false
	return public_rollout_eligible(client_build) and get_flag(clean, false)

func get_effective_public_flags(client_build: int = -1) -> Dictionary:
	var out: Dictionary = {}
	for flag_name in PUBLIC_ROLLOUT_FLAGS:
		out[flag_name] = public_flag_enabled(flag_name, client_build)
	return out

func public_mode_enabled(mode_id: String, client_build: int = -1) -> bool:
	var clean: String = mode_id.strip_edges().to_upper().replace("-", "_").replace(" ", "_")
	var flag: String = {
		"1V1": "enable_public_1v1", "STANDARD_1V1": "enable_public_1v1",
		"CRUCIBLE": "enable_public_crucible", "CRUCIBLE_1V1": "enable_public_crucible",
		"3P_FFA": "enable_public_3p_ffa", "2V2": "enable_public_2v2", "4P_FFA": "enable_public_4p_ffa",
		"CTF": "enable_public_ctf", "CAPTURE_FLAG": "enable_public_ctf", "CTF_1V1": "enable_public_ctf",
		"HCTF": "enable_public_hctf", "HIDDEN_CTF": "enable_public_hctf",
		"HIDDEN_CAPTURE_FLAG": "enable_public_hctf", "HCTF_1V1": "enable_public_hctf"
	}.get(clean, "")
	if flag.is_empty() or not public_flag_enabled(flag, client_build):
		return false
	if flag == "enable_public_crucible":
		return public_flag_enabled("enable_crucible_wax_settlement", client_build)
	return true

func paid_entries_enabled() -> bool:
	return get_flag("enable_paid_entries", false)

func honey_rewards_enabled() -> bool:
	return get_flag("enable_honey_rewards", false)

func local_honey_rewards_enabled() -> bool:
	return get_flag("enable_local_honey_rewards", false)

func observer_mode_enabled() -> bool:
	return get_flag("enable_observer_mode", false)

func rank_backend_enabled() -> bool:
	return get_flag("enable_rank_backend", false)

func rank_local_beta_fallback_allowed() -> bool:
	return rank_local_beta_fallback_allowed_for_runtime(
		OS.is_debug_build(),
		get_flag("enable_rank_local_beta_fallback", true)
	)

static func rank_local_beta_fallback_allowed_for_runtime(is_debug_build: bool, configured_debug_flag: bool) -> bool:
	# Remote config and environment values cannot reactivate client-authoritative
	# Rank/Wax mutation in production exports.
	return is_debug_build and configured_debug_flag

func external_ads_enabled() -> bool:
	var ads: Dictionary = _dict(_config.get("ads", {}))
	return get_flag("enable_ads", false) and bool(ads.get("external_ads_enabled", false))

func house_ads_enabled() -> bool:
	var ads: Dictionary = _dict(_config.get("ads", {}))
	return get_flag("enable_house_ads", true) and bool(ads.get("house_ads_enabled", true))

func ad_placement_enabled(placement: String) -> bool:
	var ads: Dictionary = _dict(_config.get("ads", {}))
	var placements: Dictionary = _dict(ads.get("placements", {}))
	return bool(placements.get(placement.strip_edges(), false))

func get_house_ticker_items() -> Array[String]:
	var ads: Dictionary = _dict(_config.get("ads", {}))
	var raw: Array = _array(ads.get("house_ticker_items", []))
	var out: Array[String] = []
	for item_any in raw:
		var item: String = str(item_any).strip_edges()
		if not item.is_empty():
			out.append(item)
	return out

func get_motd() -> Dictionary:
	var maintenance: Dictionary = _dict(_config.get("maintenance", {}))
	return maintenance.duplicate(true)

func is_maintenance_mode() -> bool:
	var maintenance: Dictionary = get_motd()
	if not bool(maintenance.get("enabled", false)):
		return false
	return _within_time_window(str(maintenance.get("start_utc", "")), str(maintenance.get("end_utc", "")))

func is_force_update_required(client_build: int = -1) -> bool:
	if not bool(_config.get("force_update", false)):
		return false
	var build: int = get_client_build() if client_build < 0 else client_build
	return build < int(_config.get("min_supported_build", 0))

func get_analytics_config() -> Dictionary:
	return _dict(_config.get("analytics", {})).duplicate(true)

func get_support_config() -> Dictionary:
	return _dict(_config.get("support", {})).duplicate(true)

func build_match_config_snapshot(setup_context: Dictionary = {}) -> Dictionary:
	var match_tuning: Dictionary = _dict(_config.get("match_tuning", {})).duplicate(true)
	var flags: Dictionary = _dict(_config.get("feature_flags", {}))
	var snapshot: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"config_source": _config_source,
		"config_version": get_config_version(),
		"config_hash": _config_hash,
		"captured_unix_ms": _unix_ms(),
		"client_build": get_client_build(),
		"feature_flags": {
			"enable_buff_system": bool(flags.get("enable_buff_system", true)),
			"enable_paid_entries": bool(flags.get("enable_paid_entries", false)),
			"enable_honey_rewards": bool(flags.get("enable_honey_rewards", false)),
			"enable_local_honey_rewards": bool(flags.get("enable_local_honey_rewards", false)),
			"enable_rank_backend": bool(flags.get("enable_rank_backend", false))
		},
		"match_tuning": match_tuning,
		"setup_context": setup_context.duplicate(true)
	}
	snapshot["snapshot_hash"] = JSON.stringify(snapshot).sha256_text()
	return snapshot

func _apply_config(config: Dictionary, source: String) -> void:
	_config = _sanitize_config(config)
	_config_source = source
	_config_hash = JSON.stringify(_config).sha256_text()
	config_changed.emit(get_debug_snapshot())

func _sanitize_config(config: Dictionary) -> Dictionary:
	var merged: Dictionary = _deep_merge(_defaults if not _defaults.is_empty() else _minimal_defaults(), config)
	merged["schema_version"] = SCHEMA_VERSION
	merged["config_version"] = str(merged.get("config_version", "unknown")).strip_edges()
	merged["min_supported_build"] = maxi(0, int(merged.get("min_supported_build", 0)))
	merged["force_update"] = bool(merged.get("force_update", false))
	merged["expires_utc"] = str(merged.get("expires_utc", "")).strip_edges()
	var flags: Dictionary = _dict(merged.get("feature_flags", {}))
	flags["enable_ads"] = bool(flags.get("enable_ads", false))
	flags["enable_house_ads"] = bool(flags.get("enable_house_ads", true))
	flags["enable_buff_system"] = bool(flags.get("enable_buff_system", true))
	flags["enable_paid_entries"] = bool(flags.get("enable_paid_entries", false))
	flags["enable_observer_mode"] = bool(flags.get("enable_observer_mode", false))
	flags["enable_honey_rewards"] = bool(flags.get("enable_honey_rewards", false))
	flags["enable_local_honey_rewards"] = bool(flags.get("enable_local_honey_rewards", false))
	flags["enable_rank_backend"] = bool(flags.get("enable_rank_backend", false))
	flags["enable_rank_local_beta_fallback"] = bool(flags.get("enable_rank_local_beta_fallback", true))
	for rollout_flag in PUBLIC_ROLLOUT_FLAGS:
		flags[rollout_flag] = bool(flags.get(rollout_flag, false))
	merged["feature_flags"] = flags
	var ads: Dictionary = _dict(merged.get("ads", {}))
	ads["external_ads_enabled"] = bool(ads.get("external_ads_enabled", false))
	ads["house_ads_enabled"] = bool(ads.get("house_ads_enabled", true))
	ads["placements"] = _dict(ads.get("placements", {}))
	ads["house_ticker_items"] = _array(ads.get("house_ticker_items", []))
	merged["ads"] = ads
	var maintenance: Dictionary = _dict(merged.get("maintenance", {}))
	maintenance["enabled"] = bool(maintenance.get("enabled", false))
	maintenance["severity"] = _sanitize_severity(str(maintenance.get("severity", "info")))
	merged["maintenance"] = maintenance
	return merged

func _valid_config(config: Dictionary) -> bool:
	if config.is_empty():
		return false
	if int(config.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	if str(config.get("config_version", "")).strip_edges().is_empty():
		return false
	return true

func _load_valid_cache() -> Dictionary:
	var cached: Dictionary = _load_json_file(CACHE_PATH)
	if _valid_config(cached):
		_cache_loaded_unix_ms = _unix_ms()
		return _sanitize_config(cached)
	return {}

func _save_cache(config: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(config, "\t"))
	file.close()

func _fetch_config(url: String) -> Dictionary:
	var clean: String = url.strip_edges()
	if clean.begins_with("res://") or clean.begins_with("user://"):
		if not FileAccess.file_exists(clean):
			return {"ok": false, "err": "file_fetch_failed"}
		var file_config: Dictionary = _load_json_file(clean)
		return {"ok": true, "config": file_config}
	if not clean.begins_with("http://") and not clean.begins_with("https://"):
		return {"ok": false, "err": "unsupported_remote_url"}
	var response: Dictionary = _fetch_http_text(clean)
	if not bool(response.get("ok", false)):
		return response
	var parsed: Variant = JSON.parse_string(str(response.get("text", "")))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": true, "config": {}}
	return {"ok": true, "config": parsed as Dictionary}

func _fetch_http_text(url: String) -> Dictionary:
	var parsed: Dictionary = _parse_http_url(url)
	if not bool(parsed.get("ok", false)):
		return parsed
	var client := HTTPClient.new()
	var err: Error
	if bool(parsed.get("tls", false)):
		err = client.connect_to_host(str(parsed.get("host", "")), int(parsed.get("port", 443)), TLSOptions.client())
	else:
		err = client.connect_to_host(str(parsed.get("host", "")), int(parsed.get("port", 80)))
	if err != OK:
		return {"ok": false, "err": "connect_failed", "code": int(err)}
	if not _wait_for_http_status(client, HTTPClient.STATUS_CONNECTED):
		client.close()
		return {"ok": false, "err": "connect_timeout"}
	err = client.request(HTTPClient.METHOD_GET, str(parsed.get("path", "/")), PackedStringArray(["Accept: application/json"]))
	if err != OK:
		client.close()
		return {"ok": false, "err": "request_failed", "code": int(err)}
	var response: Dictionary = _wait_for_http_response(client)
	client.close()
	return response

func _wait_for_http_status(client: HTTPClient, wanted: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(_configured_timeout_sec() * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var status: int = client.get_status()
		if status == wanted:
			return true
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE or status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return false
		if client.poll() != OK:
			return false
		OS.delay_msec(4)
	return false

func _wait_for_http_response(client: HTTPClient) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + int(_configured_timeout_sec() * 1000.0)
	var saw_response: bool = false
	var response_code: int = 0
	var expected_len: int = -1
	var body := PackedByteArray()
	while Time.get_ticks_msec() <= deadline:
		var err: Error = client.poll()
		if err != OK:
			return {"ok": false, "err": "poll_failed", "code": int(err)}
		if client.has_response():
			if not saw_response:
				saw_response = true
				response_code = client.get_response_code()
				expected_len = client.get_response_body_length()
			while client.get_status() == HTTPClient.STATUS_BODY:
				var chunk: PackedByteArray = client.read_response_body_chunk()
				if chunk.is_empty():
					break
				body.append_array(chunk)
		if saw_response and (expected_len == 0 or (expected_len > 0 and body.size() >= expected_len) or client.get_status() == HTTPClient.STATUS_DISCONNECTED):
			if response_code < 200 or response_code >= 300:
				return {"ok": false, "err": "http_status_%d" % response_code, "status": response_code}
			return {"ok": true, "status": response_code, "text": body.get_string_from_utf8()}
		OS.delay_msec(4)
	return {"ok": false, "err": "response_timeout"}

func _parse_http_url(url: String) -> Dictionary:
	var clean: String = url.strip_edges()
	var tls: bool = clean.begins_with("https://")
	var prefix_len: int = 8 if tls else 7
	if not tls and not clean.begins_with("http://"):
		return {"ok": false, "err": "unsupported_scheme"}
	var remainder: String = clean.substr(prefix_len)
	var slash: int = remainder.find("/")
	var host_port: String = remainder if slash < 0 else remainder.substr(0, slash)
	var path: String = "/" if slash < 0 else remainder.substr(slash)
	var host: String = host_port
	var port: int = 443 if tls else 80
	var colon: int = host_port.rfind(":")
	if colon > 0:
		host = host_port.substr(0, colon)
		var port_text: String = host_port.substr(colon + 1)
		if port_text.is_valid_int():
			port = int(port_text)
	if host.is_empty():
		return {"ok": false, "err": "missing_host"}
	return {"ok": true, "tls": tls, "host": host, "port": port, "path": path}

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}

func _configured_remote_url() -> String:
	var env_url: String = OS.get_environment(ENV_REMOTE_URL).strip_edges()
	if not env_url.is_empty():
		return env_url
	var configured: String = str(ProjectSettings.get_setting(SETTINGS_REMOTE_URL, "")).strip_edges()
	if not configured.is_empty() and configured != VS_REMOTE_SENTINEL:
		return configured
	var backend: String = OS.get_environment(ENV_VS_BACKEND_URL).strip_edges()
	if backend.is_empty():
		backend = str(ProjectSettings.get_setting(SETTINGS_VS_BACKEND_URL, "")).strip_edges()
	if backend.is_empty():
		return ""
	return backend.trim_suffix("/") + "/public_ops_config"

func _configured_timeout_sec() -> float:
	return maxf(0.1, float(ProjectSettings.get_setting(SETTINGS_FETCH_TIMEOUT_SEC, DEFAULT_TIMEOUT_SEC)))

func _within_time_window(start_utc: String, end_utc: String) -> bool:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var start_unix: int = _parse_iso_unix(start_utc)
	var end_unix: int = _parse_iso_unix(end_utc)
	if start_unix > 0 and now_unix < start_unix:
		return false
	if end_unix > 0 and now_unix > end_unix:
		return false
	return true

func _parse_iso_unix(value: String) -> int:
	var clean: String = value.strip_edges()
	if clean.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(clean.replace("Z", "")))

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key_any in override.keys():
		var key: String = str(key_any)
		var next: Variant = override.get(key_any)
		if typeof(next) == TYPE_DICTIONARY and typeof(out.get(key)) == TYPE_DICTIONARY:
			out[key] = _deep_merge(out.get(key) as Dictionary, next as Dictionary)
		else:
			out[key] = next
	return out

func _minimal_defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"config_version": "minimal-fail-closed",
		"min_supported_build": 0,
		"force_update": false,
		"expires_utc": "",
		"maintenance": {"enabled": false, "severity": "info"},
		"feature_flags": {
			"enable_ads": false,
			"enable_house_ads": true,
			"enable_buff_system": true,
			"enable_paid_entries": false,
			"enable_observer_mode": false,
			"enable_honey_rewards": false,
			"enable_local_honey_rewards": false,
			"enable_rank_backend": false,
			"enable_rank_local_beta_fallback": true
		},
		"ads": {"external_ads_enabled": false, "house_ads_enabled": true, "placements": {}, "house_ticker_items": []},
		"match_tuning": {},
		"analytics": {"enabled": false, "endpoint_url": ""},
		"support": {}
	}

func _sanitize_severity(value: String) -> String:
	var clean: String = value.strip_edges().to_lower()
	return clean if ["info", "warning", "maintenance"].has(clean) else "info"

func _redacted_url(value: String) -> String:
	if value.is_empty():
		return ""
	if value.contains("?"):
		return value.substr(0, value.find("?")) + "?..."
	return value

func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []

func _unix_ms() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))
