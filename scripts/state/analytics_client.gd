extends Node

signal queue_changed(count: int)

const QUEUE_PATH: String = "user://analytics_queue_v1.jsonl"
const STATE_PATH: String = "user://analytics_state_v1.json"
const ENV_ANALYTICS_URL: String = "SF_ANALYTICS_URL"
const SETTINGS_ANALYTICS_URL: String = "swarmfront/analytics/backend_url"
const SETTINGS_ANALYTICS_ENABLED: String = "swarmfront/analytics/enabled"
const DEFAULT_FLUSH_BATCH_SIZE: int = 25
const DEFAULT_FLUSH_INTERVAL_SEC: float = 30.0
const DEFAULT_PLATFORM: String = "ios"
const PHASE0_EVENTS: Array[String] = [
	"session_start",
	"session_end",
	"match_start",
	"match_end_summary",
	"purchase",
	"error",
	"crash"
]

var _install_id: String = ""
var _session_id: String = ""
var _queue: Array[Dictionary] = []
var _last_flush_result: Dictionary = {}
var _last_flush_unix_ms: int = 0
var _last_auto_flush_unix_ms: int = 0
var _auto_flush_count: int = 0
var _flush_timer: Timer = null

func _ready() -> void:
	_load_state()
	_load_queue()
	_bind_ops_config()
	_bind_app_lifecycle()
	_ensure_flush_timer()
	if _session_id.is_empty():
		start_session("cold")
	_sync_flush_timer()

func start_session(launch_reason: String = "cold") -> void:
	_ensure_ids()
	_session_id = _uuid_v4()
	_save_state()
	record_event("session_start", {
		"launch_reason": launch_reason,
		"timezone_offset_min": Time.get_time_zone_from_system().get("bias", 0)
	})

func end_session(duration_ms: int = 0, matches_played: int = 0, purchases_made: int = 0) -> void:
	record_event("session_end", {
		"duration_ms": maxi(0, duration_ms),
		"matches_played": maxi(0, matches_played),
		"purchases_made": maxi(0, purchases_made)
	})
	flush_if_ready("session_end")

func record_event(event_name: String, props: Dictionary = {}) -> Dictionary:
	var clean_name: String = event_name.strip_edges()
	if not PHASE0_EVENTS.has(clean_name):
		return {"ok": false, "err": "unsupported_event_name"}
	_ensure_ids()
	var event: Dictionary = {
		"event_id": _uuid_v4(),
		"event_name": clean_name,
		"event_time_utc_ms": _unix_ms(),
		"install_id": _install_id,
		"session_id": _session_id,
		"app_version": _app_version(),
		"platform": _platform(),
		"device_model": OS.get_model_name(),
		"os_version": OS.get_version(),
		"props": props.duplicate(true)
	}
	_queue.append(event)
	_save_queue()
	queue_changed.emit(_queue.size())
	_sync_flush_timer()
	return {"ok": true, "event": event.duplicate(true), "queue_count": _queue.size()}

func record_match_end_summary(match_payload: Dictionary) -> Dictionary:
	return record_event("match_end_summary", match_payload)

func record_match_start(match_payload: Dictionary) -> Dictionary:
	return record_event("match_start", match_payload)

func record_error(error_code: String, message: String = "", context: Dictionary = {}) -> Dictionary:
	return record_event("error", {
		"error_code": error_code,
		"message": message,
		"context": context.duplicate(true)
	})

func queue_count() -> int:
	return _queue.size()

func get_queue_snapshot() -> Array[Dictionary]:
	return _queue.duplicate(true)

func clear_queue_for_smoke() -> void:
	if not OS.is_debug_build():
		return
	_queue.clear()
	_save_queue()
	queue_changed.emit(0)
	_sync_flush_timer()

func flush() -> Dictionary:
	_load_queue()
	if _queue.is_empty():
		_last_flush_result = {"ok": true, "flushed": 0, "remaining": 0}
		_last_flush_unix_ms = _unix_ms()
		_sync_flush_timer()
		return _last_flush_result
	if not _enabled():
		_last_flush_result = {"ok": false, "err": "analytics_disabled", "remaining": _queue.size()}
		_last_flush_unix_ms = _unix_ms()
		_sync_flush_timer()
		return _last_flush_result
	var endpoint: String = _endpoint_url()
	if endpoint.is_empty():
		_last_flush_result = {"ok": false, "err": "missing_endpoint", "remaining": _queue.size()}
		_last_flush_unix_ms = _unix_ms()
		_sync_flush_timer()
		return _last_flush_result
	var batch_size: int = mini(_flush_batch_size(), _queue.size())
	var batch: Array[Dictionary] = []
	for i in range(batch_size):
		batch.append((_queue[i] as Dictionary).duplicate(true))
	var result: Dictionary
	if endpoint.begins_with("user://") or endpoint.begins_with("res://"):
		result = _flush_to_file_sink(endpoint, batch)
	else:
		result = _flush_http(endpoint, batch)
	if bool(result.get("ok", false)):
		_queue = _queue.slice(batch_size)
		_save_queue()
		result["flushed"] = batch_size
		result["remaining"] = _queue.size()
		queue_changed.emit(_queue.size())
	_last_flush_result = result.duplicate(true)
	_last_flush_unix_ms = _unix_ms()
	_sync_flush_timer()
	return result

func flush_if_ready(reason: String = "manual") -> Dictionary:
	if not _auto_flush_enabled():
		return {"ok": false, "err": "auto_flush_not_ready", "reason": reason, "remaining": _queue.size()}
	if _queue.is_empty():
		return {"ok": true, "flushed": 0, "remaining": 0, "reason": reason}
	var result: Dictionary = flush()
	result["reason"] = reason
	return result

func get_debug_snapshot() -> Dictionary:
	return {
		"enabled": _enabled(),
		"endpoint_url": _redacted_url(_endpoint_url()),
		"install_id": _install_id,
		"session_id": _session_id,
		"queue_count": _queue.size(),
		"last_flush_unix_ms": _last_flush_unix_ms,
		"last_auto_flush_unix_ms": _last_auto_flush_unix_ms,
		"auto_flush_count": _auto_flush_count,
		"auto_flush_interval_sec": _flush_interval_sec(),
		"auto_flush_ready": _auto_flush_enabled(),
		"last_flush_result": _last_flush_result.duplicate(true)
	}

func get_health_snapshot() -> Dictionary:
	var endpoint: String = _endpoint_url()
	var enabled: bool = _enabled()
	var endpoint_configured: bool = not endpoint.is_empty()
	var status: String = "disabled"
	if enabled and not endpoint_configured:
		status = "missing_endpoint"
	elif enabled and _queue.is_empty():
		status = "idle"
	elif enabled:
		status = "queued"
	if enabled and not bool(_last_flush_result.get("ok", true)) and not _last_flush_result.is_empty():
		status = "last_flush_failed"
	return {
		"status": status,
		"enabled": enabled,
		"endpoint_configured": endpoint_configured,
		"queue_count": _queue.size(),
		"auto_flush_ready": _auto_flush_enabled(),
		"auto_flush_interval_sec": _flush_interval_sec(),
		"auto_flush_count": _auto_flush_count,
		"last_flush_unix_ms": _last_flush_unix_ms,
		"last_auto_flush_unix_ms": _last_auto_flush_unix_ms,
		"last_flush_result": _last_flush_result.duplicate(true)
	}

func _bind_ops_config() -> void:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config == null or not ops_config.has_signal("config_changed"):
		return
	var callback: Callable = Callable(self, "_on_ops_config_changed")
	if not ops_config.is_connected("config_changed", callback):
		ops_config.connect("config_changed", callback)

func _bind_app_lifecycle() -> void:
	var lifecycle: Node = get_node_or_null("/root/AppLifecycle")
	if lifecycle == null or not lifecycle.has_signal("app_backgrounded"):
		return
	var callback: Callable = Callable(self, "_on_app_backgrounded")
	if not lifecycle.is_connected("app_backgrounded", callback):
		lifecycle.connect("app_backgrounded", callback)

func _ensure_flush_timer() -> void:
	if _flush_timer != null and is_instance_valid(_flush_timer):
		return
	_flush_timer = Timer.new()
	_flush_timer.name = "AnalyticsFlushTimer"
	_flush_timer.one_shot = true
	add_child(_flush_timer)
	_flush_timer.timeout.connect(_on_flush_timer_timeout)

func _sync_flush_timer() -> void:
	_ensure_flush_timer()
	if _flush_timer == null:
		return
	if _queue.is_empty() or not _auto_flush_enabled():
		_flush_timer.stop()
		return
	_flush_timer.wait_time = _flush_interval_sec()
	if _flush_timer.is_stopped():
		_flush_timer.start()

func _auto_flush_enabled() -> bool:
	return _enabled() and not _endpoint_url().is_empty() and _flush_interval_sec() > 0.0

func _flush_interval_sec() -> float:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_analytics_config"):
		var analytics: Dictionary = ops_config.call("get_analytics_config") as Dictionary
		if analytics.has("flush_interval_sec"):
			return maxf(0.1, float(analytics.get("flush_interval_sec", DEFAULT_FLUSH_INTERVAL_SEC)))
	return DEFAULT_FLUSH_INTERVAL_SEC

func _on_flush_timer_timeout() -> void:
	if _queue.is_empty() or not _auto_flush_enabled():
		_sync_flush_timer()
		return
	_auto_flush_count += 1
	_last_auto_flush_unix_ms = _unix_ms()
	flush()

func _on_ops_config_changed(_snapshot: Dictionary) -> void:
	_sync_flush_timer()

func _on_app_backgrounded(reason: String, _paused_at_msec: int, _paused_at_unix: int) -> void:
	flush_if_ready("app_backgrounded:%s" % reason.strip_edges())

func _enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_analytics_config"):
		var analytics: Dictionary = ops_config.call("get_analytics_config") as Dictionary
		if analytics.has("enabled"):
			return bool(analytics.get("enabled", false))
	return bool(ProjectSettings.get_setting(SETTINGS_ANALYTICS_ENABLED, false))

func _endpoint_url() -> String:
	var env_url: String = OS.get_environment(ENV_ANALYTICS_URL).strip_edges()
	if not env_url.is_empty():
		return _batch_endpoint(env_url)
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_analytics_config"):
		var analytics: Dictionary = ops_config.call("get_analytics_config") as Dictionary
		var config_url: String = str(analytics.get("endpoint_url", "")).strip_edges()
		if not config_url.is_empty():
			return _batch_endpoint(config_url)
	return _batch_endpoint(str(ProjectSettings.get_setting(SETTINGS_ANALYTICS_URL, "")).strip_edges())

func _batch_endpoint(raw_url: String) -> String:
	var clean: String = raw_url.strip_edges().trim_suffix("/")
	if clean.is_empty() or clean.begins_with("user://") or clean.begins_with("res://"):
		return clean
	if clean.ends_with("/v1/events/batch"):
		return clean
	return "%s/v1/events/batch" % clean

func _flush_batch_size() -> int:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_analytics_config"):
		var analytics: Dictionary = ops_config.call("get_analytics_config") as Dictionary
		return maxi(1, int(analytics.get("flush_batch_size", DEFAULT_FLUSH_BATCH_SIZE)))
	return DEFAULT_FLUSH_BATCH_SIZE

func _flush_to_file_sink(path: String, batch: Array[Dictionary]) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "err": "file_sink_open_failed"}
	file.store_string(JSON.stringify({"events": batch}, "\t"))
	file.close()
	return {"ok": true, "sink": "file"}

func _flush_http(endpoint: String, batch: Array[Dictionary]) -> Dictionary:
	var parsed: Dictionary = _parse_http_url(endpoint)
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
	if not _wait_connected(client):
		client.close()
		return {"ok": false, "err": "connect_timeout"}
	var body: String = JSON.stringify({"events": batch})
	err = client.request(HTTPClient.METHOD_POST, str(parsed.get("path", "/")), PackedStringArray(["Content-Type: application/json", "Accept: application/json"]), body)
	if err != OK:
		client.close()
		return {"ok": false, "err": "request_failed", "code": int(err)}
	var response: Dictionary = _wait_response(client)
	client.close()
	return response

func _wait_connected(client: HTTPClient) -> bool:
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() <= deadline:
		var status: int = client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			return true
		if status == HTTPClient.STATUS_CANT_CONNECT or status == HTTPClient.STATUS_CANT_RESOLVE or status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return false
		if client.poll() != OK:
			return false
		OS.delay_msec(4)
	return false

func _wait_response(client: HTTPClient) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 3000
	var saw_response: bool = false
	var response_code: int = 0
	var body := PackedByteArray()
	while Time.get_ticks_msec() <= deadline:
		var err: Error = client.poll()
		if err != OK:
			return {"ok": false, "err": "poll_failed", "code": int(err)}
		if client.has_response():
			if not saw_response:
				saw_response = true
				response_code = client.get_response_code()
			while client.get_status() == HTTPClient.STATUS_BODY:
				var chunk: PackedByteArray = client.read_response_body_chunk()
				if chunk.is_empty():
					break
				body.append_array(chunk)
		if saw_response and client.get_status() == HTTPClient.STATUS_DISCONNECTED:
			if response_code < 200 or response_code >= 300:
				return {"ok": false, "err": "http_status_%d" % response_code, "status": response_code}
			return {"ok": true, "status": response_code, "body": body.get_string_from_utf8()}
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
	return {"ok": not host.is_empty(), "tls": tls, "host": host, "port": port, "path": path, "err": "missing_host" if host.is_empty() else ""}

func _load_state() -> void:
	var state: Dictionary = _load_json_file(STATE_PATH)
	_install_id = str(state.get("install_id", "")).strip_edges()
	_session_id = str(state.get("session_id", "")).strip_edges()
	_ensure_ids()

func _save_state() -> void:
	var file: FileAccess = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"install_id": _install_id, "session_id": _session_id}, "\t"))
	file.close()

func _load_queue() -> void:
	_queue.clear()
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var file: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) == TYPE_DICTIONARY:
			_queue.append(parsed as Dictionary)
	file.close()

func _save_queue() -> void:
	var file: FileAccess = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if file == null:
		return
	for event in _queue:
		file.store_line(JSON.stringify(event))
	file.close()

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

func _ensure_ids() -> void:
	if _install_id.is_empty():
		_install_id = _uuid_v4()
	if _session_id.is_empty():
		_session_id = _uuid_v4()

func _uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: PackedByteArray = PackedByteArray()
	for i in range(16):
		bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]

func _app_version() -> String:
	var version: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	if version.is_empty():
		version = str(ProjectSettings.get_setting("application/config/name", "Swarmfront")).strip_edges()
	return version

func _platform() -> String:
	var name: String = OS.get_name().strip_edges().to_lower()
	return name if not name.is_empty() else DEFAULT_PLATFORM

func _redacted_url(value: String) -> String:
	if value.contains("?"):
		return value.substr(0, value.find("?")) + "?..."
	return value

func _unix_ms() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))
