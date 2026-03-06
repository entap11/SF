extends RefCounted
class_name RankTransportHttp

const DEFAULT_TIMEOUT_SEC: float = 2.0

var _base_url: String = ""
var _timeout_sec: float = DEFAULT_TIMEOUT_SEC
var _auth_token: String = ""

func configure(base_url: String, timeout_sec: float = DEFAULT_TIMEOUT_SEC, auth_token: String = "") -> void:
	_base_url = _normalize_base_url(base_url)
	_timeout_sec = maxf(0.1, timeout_sec)
	_auth_token = auth_token.strip_edges()

func configured() -> bool:
	return not _base_url.is_empty()

func call_action(action: String, payload: Dictionary) -> Dictionary:
	if not configured():
		return {
			"ok": false,
			"transport_error": true,
			"err": "transport_not_configured"
		}
	var action_path: String = action.strip_edges().trim_prefix("/")
	if action_path.is_empty():
		return {
			"ok": false,
			"transport_error": true,
			"err": "invalid_action"
		}
	var url: String = "%s/%s" % [_base_url, action_path]
	var response: Dictionary = _post_json(url, payload)
	if bool(response.get("transport_error", false)):
		return response
	var body: Variant = response.get("body", {})
	if typeof(body) == TYPE_DICTIONARY:
		var parsed: Dictionary = body as Dictionary
		if not parsed.has("ok"):
			parsed["ok"] = true
		return parsed
	return {
		"ok": false,
		"transport_error": true,
		"err": "invalid_json_body"
	}

func _post_json(url: String, payload: Dictionary) -> Dictionary:
	var parsed: Dictionary = _parse_http_url(url)
	if not bool(parsed.get("ok", false)):
		return {
			"ok": false,
			"transport_error": true,
			"err": str(parsed.get("err", "url_parse_failed")),
			"url": url
		}
	var host: String = str(parsed.get("host", ""))
	var port: int = int(parsed.get("port", 80))
	var use_tls: bool = bool(parsed.get("tls", false))
	var path: String = str(parsed.get("path", "/"))
	var client: HTTPClient = HTTPClient.new()
	var err: int = OK
	if use_tls:
		err = client.connect_to_host(host, port, TLSOptions.client())
	else:
		err = client.connect_to_host(host, port)
	if err != OK:
		return {
			"ok": false,
			"transport_error": true,
			"err": "connect_failed",
			"code": err,
			"host": host,
			"port": port
		}
	var connect_ok: bool = _wait_for_connection(client)
	if not connect_ok:
		client.close()
		return {
			"ok": false,
			"transport_error": true,
			"err": "connect_timeout"
		}
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	if not _auth_token.is_empty():
		headers.append("Authorization: Bearer %s" % _auth_token)
	var body_text: String = JSON.stringify(payload)
	err = client.request(HTTPClient.METHOD_POST, path, headers, body_text)
	if err != OK:
		client.close()
		return {
			"ok": false,
			"transport_error": true,
			"err": "request_failed",
			"code": err
		}
	var recv: Dictionary = _wait_for_response(client)
	client.close()
	if not bool(recv.get("ok", false)):
		recv["transport_error"] = true
		return recv
	var text: String = str(recv.get("text", ""))
	if text.strip_edges().is_empty():
		return {
			"ok": true,
			"status": int(recv.get("status", 200)),
			"body": {}
		}
	var json := JSON.new()
	var parse_err: int = json.parse(text)
	if parse_err != OK:
		return {
			"ok": false,
			"transport_error": true,
			"err": "json_parse_failed",
			"status": int(recv.get("status", 0))
		}
	return {
		"ok": true,
		"status": int(recv.get("status", 200)),
		"body": json.data
	}

func _wait_for_connection(client: HTTPClient) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + int(_timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline_ms:
		var status: int = client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			return true
		if status == HTTPClient.STATUS_CANT_CONNECT \
		or status == HTTPClient.STATUS_CANT_RESOLVE \
		or status == HTTPClient.STATUS_CONNECTION_ERROR \
		or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return false
		var poll_err: int = client.poll()
		if poll_err != OK:
			return false
		OS.delay_msec(4)
	return false

func _wait_for_response(client: HTTPClient) -> Dictionary:
	var deadline_ms: int = Time.get_ticks_msec() + int(_timeout_sec * 1000.0)
	var saw_response: bool = false
	var saw_body_data: bool = false
	var response_code: int = 0
	var expected_len: int = -1
	var body_chunks: PackedByteArray = PackedByteArray()
	while Time.get_ticks_msec() <= deadline_ms:
		var poll_err: int = client.poll()
		if poll_err != OK:
			return {"ok": false, "err": "poll_failed", "code": poll_err}
		var status: int = client.get_status()
		if client.has_response():
			if not saw_response:
				saw_response = true
				response_code = client.get_response_code()
				expected_len = client.get_response_body_length()
			if status == HTTPClient.STATUS_BODY:
				while true:
					if client.get_status() != HTTPClient.STATUS_BODY:
						break
					var body_chunk: PackedByteArray = client.read_response_body_chunk()
					if body_chunk.is_empty():
						break
					saw_body_data = true
					body_chunks.append_array(body_chunk)
		if saw_response:
			if expected_len == 0:
				return {
					"ok": true,
					"status": response_code,
					"text": ""
				}
			if expected_len > 0 and body_chunks.size() >= expected_len:
				return {
					"ok": true,
					"status": response_code,
					"text": body_chunks.get_string_from_utf8()
				}
			if expected_len < 0 and saw_body_data and status == HTTPClient.STATUS_CONNECTED:
				return {
					"ok": true,
					"status": response_code,
					"text": body_chunks.get_string_from_utf8()
				}
			if status == HTTPClient.STATUS_DISCONNECTED:
				return {
					"ok": true,
					"status": response_code,
					"text": body_chunks.get_string_from_utf8()
				}
		if status == HTTPClient.STATUS_DISCONNECTED \
		or status == HTTPClient.STATUS_CONNECTION_ERROR \
		or status == HTTPClient.STATUS_CANT_CONNECT \
		or status == HTTPClient.STATUS_CANT_RESOLVE \
		or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return {"ok": false, "err": "connection_closed", "status": status}
		OS.delay_msec(4)
	return {"ok": false, "err": "response_timeout"}

func _parse_http_url(url: String) -> Dictionary:
	var trimmed: String = url.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "err": "url_empty"}
	var use_tls: bool = false
	var remainder: String = ""
	if trimmed.begins_with("https://"):
		use_tls = true
		remainder = trimmed.substr(8)
	elif trimmed.begins_with("http://"):
		use_tls = false
		remainder = trimmed.substr(7)
	else:
		return {"ok": false, "err": "unsupported_scheme"}
	var slash_idx: int = remainder.find("/")
	var host_port: String = remainder
	var path: String = "/"
	if slash_idx >= 0:
		host_port = remainder.substr(0, slash_idx)
		path = remainder.substr(slash_idx)
	if host_port.is_empty():
		return {"ok": false, "err": "host_missing"}
	var host: String = host_port
	var port: int = 443 if use_tls else 80
	var colon_idx: int = host_port.rfind(":")
	if colon_idx > 0 and colon_idx < host_port.length() - 1:
		host = host_port.substr(0, colon_idx)
		var port_str: String = host_port.substr(colon_idx + 1)
		port = int(port_str)
	if host.strip_edges().is_empty() or port <= 0:
		return {"ok": false, "err": "host_or_port_invalid"}
	if not path.begins_with("/"):
		path = "/" + path
	return {
		"ok": true,
		"tls": use_tls,
		"host": host,
		"port": port,
		"path": path
	}

func _normalize_base_url(url: String) -> String:
	return url.strip_edges().trim_suffix("/")
