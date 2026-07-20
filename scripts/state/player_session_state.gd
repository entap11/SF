extends RefCounted
class_name PlayerSessionState

## In-memory player access-session seam. Access tokens are intentionally never
## written to ProjectSettings, user://, logs, or save data.

enum Status {
	OFFLINE_LOCAL,
	AUTHENTICATED_BACKEND,
	EXPIRED,
	REVOKED,
	MIGRATION_REQUIRED
}

var _status: Status = Status.OFFLINE_LOCAL
var _access_token: String = ""
var _player_id: String = ""
var _device_id: String = ""
var _session_id: String = ""
var _expires_at_unix: int = 0

func accept_session_response(response: Dictionary) -> Dictionary:
	var token: String = str(response.get("access_token", "")).strip_edges()
	var session_v: Variant = response.get("session", {})
	if token.is_empty() or typeof(session_v) != TYPE_DICTIONARY:
		return {"ok": false, "err": "invalid_session_response"}
	var session: Dictionary = session_v as Dictionary
	var player_id_value: String = str(session.get("player_id", "")).strip_edges()
	var device_id_value: String = str(session.get("device_id", "")).strip_edges()
	var session_id_value: String = str(session.get("id", "")).strip_edges()
	var expires_at_unix: int = int(session.get("expires_at_unix", 0))
	if player_id_value.is_empty() or device_id_value.is_empty() or session_id_value.is_empty() or expires_at_unix <= _now_unix():
		return {"ok": false, "err": "invalid_session_response"}
	_access_token = token
	_player_id = player_id_value
	_device_id = device_id_value
	_session_id = session_id_value
	_expires_at_unix = expires_at_unix
	_status = Status.AUTHENTICATED_BACKEND
	return {"ok": true, "player_id": _player_id, "expires_at_unix": _expires_at_unix}

func access_token() -> String:
	_refresh_expiry()
	return _access_token if _status == Status.AUTHENTICATED_BACKEND else ""

func player_id() -> String:
	return _player_id

func device_id() -> String:
	return _device_id

func session_id() -> String:
	return _session_id

func status() -> Status:
	_refresh_expiry()
	return _status

func revoke_local() -> void:
	clear(Status.REVOKED)

func clear(next_status: Status = Status.OFFLINE_LOCAL) -> void:
	_access_token = ""
	_session_id = ""
	_expires_at_unix = 0
	_status = next_status

func debug_snapshot() -> Dictionary:
	_refresh_expiry()
	return {
		"status": Status.keys()[_status],
		"player_id": _player_id,
		"device_id": _device_id,
		"session_id": _session_id,
		"expires_at_unix": _expires_at_unix,
		"has_access_token": not _access_token.is_empty()
	}

func _refresh_expiry() -> void:
	if _status == Status.AUTHENTICATED_BACKEND and _expires_at_unix <= _now_unix():
		clear(Status.EXPIRED)

func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
