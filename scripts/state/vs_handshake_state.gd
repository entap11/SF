extends Node

signal session_changed(session_id: String, session: Dictionary)
signal queue_changed(queue_size: int)

const SFLog := preload("res://scripts/util/sf_log.gd")
const VsHandshakeTransportHttp := preload("res://scripts/state/vs_handshake_transport_http.gd")
const MAP_LOADER := preload("res://scripts/maps/map_loader.gd")
const MAP_REGISTRY := preload("res://scripts/maps/map_registry.gd")
const MatchSetupRandomizer := preload("res://scripts/state/match_setup_randomizer.gd")
const MapModeRules := preload("res://scripts/maps/map_mode_rules.gd")
const MoneyGameLedgerScript := preload("res://scripts/state/money_game_ledger.gd")

const SESSION_TTL_SEC: int = 15 * 60
const QUEUE_TTL_SEC: int = 90
const INTENT_STREAM_MAX_EVENTS: int = 512
const ENV_BACKEND_URL: String = "SF_VS_BACKEND_URL"
const ENV_BACKEND_TOKEN: String = "SF_VS_BACKEND_TOKEN"
const ENV_PUBLIC_CLIENT_BUILD: String = "SF_PUBLIC_CLIENT_BUILD"
const SETTINGS_BACKEND_URL: String = "swarmfront/vs/backend_url"
const SETTINGS_BACKEND_TOKEN: String = "swarmfront/vs/backend_token"
const SETTINGS_BACKEND_TIMEOUT_SEC: String = "swarmfront/vs/backend_timeout_sec"
const SETTINGS_FORCE_RELEASE_GUARD_FOR_SMOKE: String = "swarmfront/vs/force_release_guard_for_smoke"
const DEFAULT_BACKEND_TIMEOUT_SEC: float = 6.0
const MAX_SYNC_BACKEND_TIMEOUT_SEC: float = 6.0
const AUTH_COMMAND_LEAD_TICKS: int = 6
const TRANSPORT_ERROR_BACKOFF_MS: int = 60000
const DIAGNOSTIC_LOG_PATH: String = "user://vs_handshake_diagnostics.jsonl"
const DIAGNOSTIC_MAX_PAYLOAD_CHARS: int = 1200
const SESSION_CONTRACT_VERSION: int = 2
const PUBLIC_MATCH_PROTOCOL_VERSION: int = 2
const SYNCHRONIZED_MATCH_LOADING_MIN_MS: int = 7000
const SYNCHRONIZED_START_NETWORK_BUFFER_MS: int = 1000
const SYNCHRONIZED_PREMATCH_MS: int = 10000
const SYNCHRONIZED_START_LEAD_MS: int = SYNCHRONIZED_MATCH_LOADING_MIN_MS \
	+ SYNCHRONIZED_START_NETWORK_BUFFER_MS \
	+ SYNCHRONIZED_PREMATCH_MS
const SETTINGS_PUBLIC_CLIENT_BUILD: String = "swarmfront/vs/public_client_build"
const MAX_SYNC_PLAYERS: int = 4
const TIER_ORDER: Array[String] = [
	"DRONE",
	"WORKER",
	"SOLDIER",
	"HONEY_BEE",
	"BUMBLEBEE",
	"QUEEN",
	"YELLOWJACKET",
	"RED_WASP",
	"HORNET",
	"BALD_FACED_HORNET",
	"KILLER_BEE",
	"ASIAN_GIANT_HORNET",
	"EXECUTIONER_WASP",
	"SCORPION_WASP",
	"COW_KILLER"
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sessions: Dictionary = {}
var _invite_to_session: Dictionary = {}
var _queue: Array[Dictionary] = []
var _intent_streams: Dictionary = {}
var _presence_by_uid: Dictionary = {}
var _friend_invites: Dictionary = {}
var _rematch_sessions_by_parent_key: Dictionary = {}
var _transport_http: VsHandshakeTransportHttp = null
var _transport_mode: String = "local"
var _transport_error_logged: bool = false
var _transport_config_blocker: String = ""
var _last_transport_error: Dictionary = {}
var _transport_backoff_until_msec: int = 0
var _player_access_token: String = ""
var _durable_public_ticket_ids: Dictionary = {}
var _durable_public_match_ids: Dictionary = {}
var _money_ledger = MoneyGameLedgerScript.new()

func _ready() -> void:
	_rng.randomize()
	_configure_transport()

func _configure_transport() -> void:
	_transport_config_blocker = ""
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		_transport_http = null
		_transport_mode = "local"
		return
	_transport_config_blocker = _release_backend_url_blocker(backend_url)
	if _release_requires_authoritative_transport() and not _transport_config_blocker.is_empty():
		_transport_http = null
		_transport_mode = "invalid"
		SFLog.allow_tag("VS_TRANSPORT_CONFIG")
		SFLog.warn("VS_TRANSPORT_CONFIG", {"mode": _transport_mode, "url": backend_url, "blocker": _transport_config_blocker})
		return
	_transport_http = VsHandshakeTransportHttp.new()
	_transport_http.configure(
		backend_url,
		_configured_backend_timeout_sec(),
		_player_access_token if not _player_access_token.is_empty() else _configured_backend_token()
	)
	_transport_mode = "http"
	SFLog.allow_tag("VS_TRANSPORT_CONFIG")
	SFLog.info("VS_TRANSPORT_CONFIG", {"mode": _transport_mode, "url": backend_url})

func get_transport_mode() -> String:
	return _transport_mode

func is_authoritative_transport_online() -> bool:
	return _transport_mode == "http" and _transport_http != null and _transport_http.configured() and _transport_config_blocker.is_empty()

func get_authoritative_transport_blocker() -> String:
	var backend_url: String = _configured_backend_url()
	if backend_url.is_empty():
		return "Online VS backend is not configured for this build."
	if not _transport_config_blocker.is_empty():
		return _transport_config_blocker
	if not is_authoritative_transport_online():
		return "Online VS backend is not available."
	return ""

func get_last_transport_error() -> Dictionary:
	return _last_transport_error.duplicate(true)

func set_player_access_token(access_token: String) -> void:
	_player_access_token = access_token.strip_edges()
	if _transport_http != null:
		_transport_http.set_auth_token(_player_access_token)

func clear_player_access_token() -> void:
	_player_access_token = ""
	if _transport_http != null:
		_transport_http.clear_auth_token()

func has_player_access_token() -> bool:
	return not _player_access_token.is_empty()

func get_diagnostic_log_path() -> String:
	return ProjectSettings.globalize_path(DIAGNOSTIC_LOG_PATH)

func get_beta_runtime_flags() -> Dictionary:
	var remote_online: bool = is_authoritative_transport_online()
	return {
		"match_authority": "local_ops_state",
		"progression_authority": "remote_authoritative" if remote_online else "local_provisional",
		"transport_mode": get_transport_mode(),
		"competitive_provisional": not remote_online,
		"authoritative_progression_online": remote_online,
		"ops_config": _ops_config_debug_snapshot()
	}

func clear() -> void:
	_sessions.clear()
	_invite_to_session.clear()
	_queue.clear()
	_intent_streams.clear()
	_presence_by_uid.clear()
	_friend_invites.clear()
	_rematch_sessions_by_parent_key.clear()
	_last_transport_error = {}
	_transport_backoff_until_msec = 0
	_transport_error_logged = false
	_durable_public_ticket_ids.clear()
	_durable_public_match_ids.clear()
	_money_ledger = MoneyGameLedgerScript.new()
	emit_signal("queue_changed", _queue.size())

func debug_set_money_balance_cents(account_id: String, amount_cents: int) -> Dictionary:
	return _money_ledger.set_balance_cents(account_id, amount_cents)

func debug_get_money_balance_cents(account_id: String) -> int:
	return int(_money_ledger.get_balance_cents(account_id))

func debug_get_money_match_snapshot(session_id: String) -> Dictionary:
	return _money_ledger.get_match_snapshot(session_id)

func debug_get_money_ledger_snapshot() -> Dictionary:
	return _money_ledger.get_snapshot()

func debug_get_money_transaction_ledger(filters: Dictionary = {}) -> Array[Dictionary]:
	return _money_ledger.get_transaction_ledger(filters)

func open_async_entry_escrow(entry_id: String, contest_id: String, player_id: String, wager_cents: int, idempotency_key: String, balance_cents: int = -1) -> Dictionary:
	var payload: Dictionary = {
		"entry_id": entry_id,
		"contest_id": contest_id,
		"player_id": player_id,
		"wager_cents": wager_cents,
		"idempotency_key": idempotency_key
	}
	if balance_cents >= 0:
		payload["balance_cents"] = balance_cents
	var transport := _call_transport("open_async_entry_escrow", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func refund_async_entry(entry_id: String, reason: String, idempotency_key: String) -> Dictionary:
	var transport := _call_transport("refund_async_entry", {
		"entry_id": entry_id,
		"reason": reason,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func preview_async_contest_payout_report(contest_id: String, payouts: Array, house_rake_bps: int) -> Dictionary:
	var transport := _call_transport("preview_async_contest_payout_report", {
		"contest_id": contest_id,
		"payouts": payouts,
		"house_rake_bps": house_rake_bps
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func submit_async_contest_result(contest_id: String, contest_family: String, player_id: String, result: Dictionary, idempotency_key: String) -> Dictionary:
	var payload: Dictionary = {
		"contest_id": contest_id,
		"contest_family": contest_family,
		"player_id": player_id,
		"result": result,
		"idempotency_key": idempotency_key
	}
	var transport := _call_transport("submit_async_contest_result", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func list_async_contest_results(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("list_async_contest_results", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func preview_async_contest_result_payout_report(contest_id: String, contest_family: String, payout_schedule: Array, house_rake_bps: int, options: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = options.duplicate(true)
	payload["contest_id"] = contest_id
	payload["contest_family"] = contest_family
	payload["payout_schedule"] = payout_schedule
	payload["house_rake_bps"] = house_rake_bps
	payload["options"] = options.duplicate(true)
	var transport := _call_transport("preview_async_contest_result_payout_report", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func list_async_contest_payout_reports(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("list_async_contest_payout_reports", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_money_payout_summary(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("get_money_payout_summary", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_money_transactions(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("get_money_transactions", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_honey_balance(player_id: String) -> Dictionary:
	var transport := _call_transport("get_honey_balance", {
		"player_id": player_id
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_honey_policy() -> Dictionary:
	var transport := _call_transport("get_honey_policy", {})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func record_honey_activity(player_id: String, activity_key: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var payload: Dictionary = metadata.duplicate(true)
	payload["player_id"] = player_id
	payload["activity_key"] = activity_key
	payload["metadata"] = metadata.duplicate(true)
	payload["idempotency_key"] = idempotency_key
	if not payload.has("entap_title"):
		payload["entap_title"] = "Swarmfront"
	var transport := _call_transport("record_honey_activity", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func grant_honey(player_id: String, amount_centi: int, source: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("grant_honey", {
		"player_id": player_id,
		"amount_centi": amount_centi,
		"source": source,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func debit_honey(player_id: String, amount_centi: int, source: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("debit_honey", {
		"player_id": player_id,
		"amount_centi": amount_centi,
		"source": source,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func preview_hive_honey_purchase(hive_id: String, member_ids: Array, cost_centi: int) -> Dictionary:
	var transport := _call_transport("preview_hive_honey_purchase", {
		"hive_id": hive_id,
		"member_ids": member_ids,
		"cost_centi": cost_centi
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func debit_hive_honey_purchase(hive_id: String, member_ids: Array, cost_centi: int, source: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("debit_hive_honey_purchase", {
		"hive_id": hive_id,
		"member_ids": member_ids,
		"cost_centi": cost_centi,
		"source": source,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_honey_transactions(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("get_honey_transactions", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func approve_async_contest_payout_report(report: Dictionary, approver_id: String, idempotency_key: String) -> Dictionary:
	var transport := _call_transport("approve_async_contest_payout_report", {
		"report": report,
		"approver_id": approver_id,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_crucible_config() -> Dictionary:
	var transport := _call_transport("get_crucible_config", {})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func update_crucible_config(patch: Dictionary, actor_id: String = "ops") -> Dictionary:
	var transport := _call_transport("update_crucible_config", {
		"patch": patch,
		"actor_id": actor_id
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func preview_crucible_entry(player_id: String, balance_millis: int = -1, active_crucible_count: int = -1, has_priority_access: bool = false) -> Dictionary:
	var payload: Dictionary = {
		"player_id": player_id,
		"has_priority_access": has_priority_access
	}
	if balance_millis >= 0:
		payload["balance_millis"] = balance_millis
	if active_crucible_count >= 0:
		payload["active_crucible_count"] = active_crucible_count
	var transport := _call_transport("preview_crucible_entry", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func open_crucible_escrow(match_id: String, player_a_id: String, player_b_id: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("open_crucible_escrow", {
		"match_id": match_id,
		"player_a_id": player_a_id,
		"player_b_id": player_b_id,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func settle_crucible_match(match_id: String, winner_id: String, result_source: String, reason: String = "", metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("settle_crucible_match", {
		"match_id": match_id,
		"winner_id": winner_id,
		"result_source": result_source,
		"reason": reason,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func refund_crucible_match(match_id: String, reason: String = "refund", metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("refund_crucible_match", {
		"match_id": match_id,
		"reason": reason,
		"result_source": "SERVER_MATCH_RESULT",
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func resolve_crucible_review(match_id: String, action: String, actor_id: String = "ops", metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var transport := _call_transport("resolve_crucible_review", {
		"match_id": match_id,
		"action": action,
		"actor_id": actor_id,
		"metadata": metadata,
		"idempotency_key": idempotency_key
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func record_crucible_lifecycle(match_id: String, event_type: String, player_id: String = "", metadata: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("record_crucible_lifecycle", {
		"match_id": match_id,
		"event_type": event_type,
		"player_id": player_id,
		"metadata": metadata
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func award_crucible_wax(player_id: String, amount_millis: int, source: String, metadata: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("award_crucible_wax", {
		"player_id": player_id,
		"amount_millis": amount_millis,
		"source": source,
		"metadata": metadata
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_wax_policy() -> Dictionary:
	var transport := _call_transport("get_wax_policy", {})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func record_competitive_wax_result(match_id: String, player_id: String, opponent_id: String, did_win: bool, mode_name: String, metadata: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var payload: Dictionary = metadata.duplicate(true)
	payload["match_id"] = match_id
	payload["player_id"] = player_id
	payload["opponent_id"] = opponent_id
	payload["did_win"] = did_win
	payload["mode_name"] = mode_name
	payload["metadata"] = metadata
	payload["idempotency_key"] = idempotency_key
	var transport := _call_transport("record_competitive_wax_result", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func debug_set_crucible_balance(player_id: String, balance_millis: int) -> Dictionary:
	var transport := _call_transport("debug_set_crucible_balance", {
		"player_id": player_id,
		"balance_millis": balance_millis
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func debug_get_crucible_snapshot() -> Dictionary:
	var transport := _call_transport("debug_get_crucible_snapshot", {})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func get_wax_audit_snapshot(filters: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("get_wax_audit_snapshot", {
		"filters": filters
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func _configured_backend_url() -> String:
	var env_url: String = OS.get_environment(ENV_BACKEND_URL).strip_edges()
	if not env_url.is_empty():
		return env_url
	if ProjectSettings.has_setting(SETTINGS_BACKEND_URL):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_URL, "")).strip_edges()
	return ""

func _configured_backend_token() -> String:
	var env_token: String = OS.get_environment(ENV_BACKEND_TOKEN).strip_edges()
	if not env_token.is_empty():
		return env_token
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TOKEN):
		return str(ProjectSettings.get_setting(SETTINGS_BACKEND_TOKEN, "")).strip_edges()
	return ""

func _configured_backend_timeout_sec() -> float:
	var configured_timeout: float = DEFAULT_BACKEND_TIMEOUT_SEC
	if ProjectSettings.has_setting(SETTINGS_BACKEND_TIMEOUT_SEC):
		configured_timeout = float(ProjectSettings.get_setting(SETTINGS_BACKEND_TIMEOUT_SEC, DEFAULT_BACKEND_TIMEOUT_SEC))
	return clampf(configured_timeout, 0.1, MAX_SYNC_BACKEND_TIMEOUT_SEC)

func _ops_observer_mode_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("observer_mode_enabled"):
		return bool(ops_config.call("observer_mode_enabled"))
	return false

func _ops_config_debug_snapshot() -> Dictionary:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_debug_snapshot"):
		return ops_config.call("get_debug_snapshot") as Dictionary
	return {}

func _call_public_transport(action: String, payload: Dictionary) -> Dictionary:
	if _player_access_token.is_empty():
		return {"ok": false, "err": "player_token_required"}
	var transport: Dictionary = _call_transport(action, payload)
	if not bool(transport.get("handled", false)):
		return {
			"ok": false,
			"err": "authenticated_transport_required",
			"transport_error": true
		}
	var result: Dictionary = (transport.get("result", {}) as Dictionary).duplicate(true)
	if not bool(result.get("ok", false)):
		return result
	var session_v: Variant = result.get("session", null)
	if typeof(session_v) == TYPE_DICTIONARY and not (session_v as Dictionary).is_empty():
		var normalized: Dictionary = _normalize_public_session(session_v as Dictionary)
		if normalized.is_empty():
			return {"ok": false, "err": "public_match_contract_invalid"}
		result["session"] = normalized
		_remember_public_session(normalized)
	var ticket_id: String = str(result.get("ticket_id", "")).strip_edges()
	if not ticket_id.is_empty():
		_durable_public_ticket_ids[ticket_id] = true
	return result

func _normalize_public_session(source: Dictionary) -> Dictionary:
	if int(source.get("protocol_version", source.get("contract_version", 0))) != PUBLIC_MATCH_PROTOCOL_VERSION:
		return {}
	var roster_v: Variant = source.get("roster", [])
	if typeof(roster_v) != TYPE_ARRAY:
		return {}
	var source_roster: Array = roster_v as Array
	var roster: Array = []
	var seen_uids: Dictionary = {}
	var seen_colors: Dictionary = {}
	for index in range(source_roster.size()):
		if typeof(source_roster[index]) != TYPE_DICTIONARY:
			return {}
		var entry: Dictionary = (source_roster[index] as Dictionary).duplicate(true)
		var uid: String = str(entry.get("player_id", "")).strip_edges()
		if entry.get("player_id", null) == null or uid.is_empty():
			uid = str(entry.get("uid", "")).strip_edges()
		var seat: int = int(entry.get("seat_id", entry.get("seat", 0)))
		if uid.is_empty() or seen_uids.has(uid) or seat != index + 1:
			return {}
		seen_uids[uid] = true
		entry["uid"] = uid
		entry["player_id"] = uid
		entry["seat"] = seat
		entry["seat_id"] = seat
		entry["role"] = "host" if seat == 1 else "player"
		var color_id: String = str(entry.get("color_id", "")).strip_edges().to_upper()
		if source_roster.size() > 2 and (color_id.is_empty() or seen_colors.has(color_id)):
			return {}
		if not color_id.is_empty():
			seen_colors[color_id] = true
		roster.append(entry)
	var required_players: int = int(source.get("required_players", 0))
	var context: Dictionary = source.get("context", {}) as Dictionary
	if required_players < 2 or required_players > MAX_SYNC_PLAYERS \
			or required_players != _required_players_for_context(context) \
			or roster.size() != required_players:
		return {}
	var mode: String = str(context.get("mode", "")).strip_edges().to_upper().replace("_", " ")
	if mode == "2V2":
		var team_counts: Dictionary = {}
		for player_any in roster:
			var team_id: int = int((player_any as Dictionary).get("team_id", 0))
			if team_id not in [1, 2]:
				return {}
			team_counts[team_id] = int(team_counts.get(team_id, 0)) + 1
		if int(team_counts.get(1, 0)) != 2 or int(team_counts.get(2, 0)) != 2:
			return {}
	elif required_players > 2:
		var ffa_teams: Dictionary = {}
		for player_any in roster:
			var team_id: int = int((player_any as Dictionary).get("team_id", 0))
			if team_id <= 0 or ffa_teams.has(team_id):
				return {}
			ffa_teams[team_id] = true
	var session: Dictionary = source.duplicate(true)
	session["id"] = str(source.get("match_id", source.get("session_id", source.get("id", ""))))
	session["session_id"] = str(session.get("id", ""))
	if str(session.get("id", "")).is_empty():
		return {}
	session["contract_version"] = PUBLIC_MATCH_PROTOCOL_VERSION
	session["protocol_version"] = PUBLIC_MATCH_PROTOCOL_VERSION
	session["required_players"] = required_players
	session["roster"] = roster
	session["host"] = (roster[0] as Dictionary).duplicate(true)
	session["guest"] = (roster[1] as Dictionary).duplicate(true)
	return session

func _remember_public_session(session: Dictionary) -> void:
	var match_id: String = str(session.get("match_id", session.get("session_id", session.get("id", "")))).strip_edges()
	if not match_id.is_empty():
		_durable_public_match_ids[match_id] = true

func _new_public_request_id(action: String) -> String:
	return "%s-%d-%d" % [action, Time.get_ticks_usec(), _rng.randi()]

func _public_client_build() -> String:
	var env_build: String = OS.get_environment(ENV_PUBLIC_CLIENT_BUILD).strip_edges()
	if not env_build.is_empty():
		return env_build
	if ProjectSettings.has_setting(SETTINGS_PUBLIC_CLIENT_BUILD):
		var configured: String = str(ProjectSettings.get_setting(SETTINGS_PUBLIC_CLIENT_BUILD, "")).strip_edges()
		if not configured.is_empty():
			return configured
	return str(ProjectSettings.get_setting("application/config/version", "dev")).strip_edges()

func _call_transport(action: String, payload: Dictionary) -> Dictionary:
	if _transport_http == null or not _transport_http.configured():
		if _release_requires_authoritative_transport():
			var blocker: String = get_authoritative_transport_blocker()
			var result: Dictionary = {
				"ok": false,
				"transport_error": true,
				"err": "authoritative_transport_required",
				"message": blocker
			}
			_last_transport_error = result.duplicate(true)
			_record_diagnostic(action, payload, result, "blocked")
			return {"handled": true, "result": result}
		return {"handled": false}
	var now_msec: int = Time.get_ticks_msec()
	if _transport_backoff_until_msec > now_msec:
		var backoff_result: Dictionary = _last_transport_error.duplicate(true)
		if backoff_result.is_empty():
			backoff_result = {
				"ok": false,
				"transport_error": true,
				"err": "transport_backoff"
			}
		backoff_result["backoff_ms_remaining"] = _transport_backoff_until_msec - now_msec
		_record_diagnostic(action, payload, backoff_result, "backoff")
		return {"handled": true, "result": backoff_result}
	var result: Dictionary = _transport_http.call_action(action, payload)
	_record_diagnostic(action, payload, result, "http")
	if bool(result.get("ok", false)):
		_transport_error_logged = false
		_last_transport_error = {}
		_transport_backoff_until_msec = 0
		return {"handled": true, "result": result}
	if bool(result.get("transport_error", false)):
		_last_transport_error = result.duplicate(true)
		_transport_backoff_until_msec = Time.get_ticks_msec() + TRANSPORT_ERROR_BACKOFF_MS
		if not _transport_error_logged:
			_transport_error_logged = true
			SFLog.allow_tag("VS_TRANSPORT_FALLBACK")
			SFLog.warn("VS_TRANSPORT_FALLBACK", {
				"action": action,
				"err": str(result.get("err", "transport_error")),
				"mode": _transport_mode
			}, "", 3000)
		return {"handled": true, "result": result}
	return {"handled": true, "result": result}

func _call_transport_async(action: String, payload: Dictionary) -> Dictionary:
	if _transport_http == null or not _transport_http.configured():
		if _release_requires_authoritative_transport():
			var blocker: String = get_authoritative_transport_blocker()
			var unavailable_result: Dictionary = {
				"ok": false,
				"transport_error": true,
				"err": "authoritative_transport_required",
				"message": blocker
			}
			_last_transport_error = unavailable_result.duplicate(true)
			_record_diagnostic(action, payload, unavailable_result, "blocked")
			return {"handled": true, "result": unavailable_result}
		return {"handled": false}
	var now_msec: int = Time.get_ticks_msec()
	if _transport_backoff_until_msec > now_msec:
		var backoff_result: Dictionary = _last_transport_error.duplicate(true)
		if backoff_result.is_empty():
			backoff_result = {
				"ok": false,
				"transport_error": true,
				"err": "transport_backoff"
			}
		backoff_result["backoff_ms_remaining"] = _transport_backoff_until_msec - now_msec
		_record_diagnostic(action, payload, backoff_result, "backoff")
		return {"handled": true, "result": backoff_result}
	var result: Dictionary = await _transport_http.call_action_async(self, action, payload)
	_record_diagnostic(action, payload, result, "http_async")
	if bool(result.get("ok", false)):
		_transport_error_logged = false
		_last_transport_error = {}
		_transport_backoff_until_msec = 0
		return {"handled": true, "result": result}
	if bool(result.get("transport_error", false)):
		_last_transport_error = result.duplicate(true)
		_transport_backoff_until_msec = Time.get_ticks_msec() + TRANSPORT_ERROR_BACKOFF_MS
		if not _transport_error_logged:
			_transport_error_logged = true
			SFLog.allow_tag("VS_TRANSPORT_FALLBACK")
			SFLog.warn("VS_TRANSPORT_FALLBACK", {
				"action": action,
				"err": str(result.get("err", "transport_error")),
				"mode": _transport_mode
			}, "", 3000)
	return {"handled": true, "result": result}

func create_invite(profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("create_invite", {
		"profile": profile,
		"context": context
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var host: Dictionary = _normalize_profile(profile)
	if host.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var session: Dictionary = _new_session(host, context, "invite")
	var session_id: String = str(session.get("id", ""))
	if session_id.is_empty():
		return {"ok": false, "err": "session_create_failed"}
	_sessions[session_id] = session
	_invite_to_session[str(session.get("invite_code", ""))] = session_id
	_emit_session_changed(session_id)
	return {
		"ok": true,
		"session_id": session_id,
		"invite_code": str(session.get("invite_code", "")),
		"session": _dup_session(session)
	}

func join_invite(invite_code: String, profile: Dictionary) -> Dictionary:
	var transport := _call_transport("join_invite", {
		"invite_code": invite_code,
		"profile": profile
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var code: String = invite_code.strip_edges().to_upper()
	if code.is_empty():
		return {"ok": false, "err": "invite_code_empty"}
	if not _invite_to_session.has(code):
		return {"ok": false, "err": "invite_not_found"}
	var session_id: String = str(_invite_to_session.get(code, ""))
	if session_id.is_empty() or not _sessions.has(session_id):
		return {"ok": false, "err": "session_not_found"}
	var guest: Dictionary = _normalize_profile(profile)
	if guest.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var session: Dictionary = _sessions.get(session_id, {}) as Dictionary
	if not _is_session_live(session):
		_close_session_internal(session_id, "expired")
		return {"ok": false, "err": "session_expired"}
	var host: Dictionary = session.get("host", {}) as Dictionary
	if str(host.get("uid", "")) == str(guest.get("uid", "")):
		return {"ok": false, "err": "cannot_join_own_invite"}
	var roster: Array = _session_roster(session)
	var existing_index: int = _session_roster_index_for_uid(roster, str(guest.get("uid", "")))
	if existing_index < 0 and roster.size() >= _session_required_players(session):
		return {"ok": false, "err": "invite_full"}
	if existing_index < 0:
		roster.append(_roster_player_from_profile(guest, roster.size() + 1, false))
	_set_session_roster(session, roster)
	if _session_has_required_players(session) and not _session_uses_synchronized_start(session):
		var start_result: Dictionary = _mark_session_started(session)
		if not bool(start_result.get("ok", false)):
			return start_result
	else:
		_session_refresh_status(session)
	_sessions[session_id] = session
	_emit_session_changed(session_id)
	return {"ok": true, "session_id": session_id, "seat": existing_index + 1 if existing_index >= 0 else roster.size(), "session": _dup_session(session)}

func enqueue_quick_match(profile: Dictionary, context: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("enqueue_quick_match", {
		"profile": profile,
		"context": context
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var player: Dictionary = _normalize_profile(profile)
	if player.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var uid: String = str(player.get("uid", ""))
	var prepared_context: Dictionary = _prepare_session_context(context)
	for session_id_any in _sessions.keys():
		var open_session_id: String = str(session_id_any)
		var open_session: Dictionary = _sessions.get(open_session_id, {}) as Dictionary
		if str(open_session.get("source", "")) != "quick" or not _is_session_live(open_session):
			continue
		if _session_has_required_players(open_session) or str(open_session.get("status", "")) == "started":
			continue
		if not _contexts_compatible(open_session.get("context", {}) as Dictionary, prepared_context):
			continue
		var open_roster: Array = _session_roster(open_session)
		if _session_roster_index_for_uid(open_roster, uid) >= 0:
			return {"ok": true, "matched": true, "session_id": open_session_id, "session": _dup_session(open_session)}
		open_roster.append(_roster_player_from_profile(player, open_roster.size() + 1, false))
		_set_session_roster(open_session, open_roster)
		if _session_has_required_players(open_session) and not _session_uses_synchronized_start(open_session):
			var open_start: Dictionary = _mark_session_started(open_session)
			if not bool(open_start.get("ok", false)):
				return open_start
		else:
			_session_refresh_status(open_session)
		_sessions[open_session_id] = open_session
		_emit_session_changed(open_session_id)
		return {"ok": true, "matched": true, "session_id": open_session_id, "seat": open_roster.size(), "session": _dup_session(open_session)}
	for ticket in _queue:
		if str(ticket.get("uid", "")) == uid:
			return {
				"ok": true,
				"matched": false,
				"ticket_id": str(ticket.get("id", ""))
			}
	var match_index: int = _best_quick_match_index(player, context)
	if match_index >= 0:
		var other: Dictionary = _queue[match_index] as Dictionary
		var host: Dictionary = {
			"uid": str(other.get("uid", "")),
			"display_name": str(other.get("display_name", "Player 1")),
			"ready": false,
			"ticket_id": str(other.get("id", "")),
			"tier_id": str(other.get("tier_id", "DRONE")),
			"rank_position": int(other.get("rank_position", 0)),
			"wax_score": float(other.get("wax_score", 0.0)),
			"color_id": str(other.get("color_id", "GREEN"))
		}
		var other_context: Dictionary = other.get("context", {}) as Dictionary
		var session: Dictionary = _new_session(host, other_context, "quick")
		session["guest"] = {
			"uid": uid,
			"display_name": str(player.get("display_name", "Player 2")),
			"ready": false,
			"ticket_id": "",
			"tier_id": str(player.get("tier_id", "DRONE")),
			"rank_position": int(player.get("rank_position", 0)),
			"wax_score": float(player.get("wax_score", 0.0)),
			"color_id": str(player.get("color_id", "GREEN"))
		}
		_set_session_roster(session, [
			_roster_player_from_profile(host, 1, true),
			_roster_player_from_profile(player, 2, false)
		])
		if _session_has_required_players(session) and not _session_uses_synchronized_start(session):
			var start_result: Dictionary = _mark_session_started(session)
			if not bool(start_result.get("ok", false)):
				return start_result
		else:
			_session_refresh_status(session)
		var session_id: String = str(session.get("id", ""))
		_sessions[session_id] = session
		_invite_to_session[str(session.get("invite_code", ""))] = session_id
		_queue.remove_at(match_index)
		emit_signal("queue_changed", _queue.size())
		_emit_session_changed(session_id)
		return {
			"ok": true,
			"matched": true,
			"session_id": session_id,
			"session": _dup_session(session)
		}
	var ticket_id: String = _next_ticket_id()
	_queue.append({
		"id": ticket_id,
		"uid": uid,
		"display_name": str(player.get("display_name", "Player")),
		"context": context.duplicate(true),
		"created_unix": int(Time.get_unix_time_from_system()),
		"last_seen_unix": int(Time.get_unix_time_from_system()),
		"tier_id": str(player.get("tier_id", "DRONE")),
		"rank_position": int(player.get("rank_position", 0)),
		"wax_score": float(player.get("wax_score", 0.0)),
		"color_id": str(player.get("color_id", "GREEN"))
	})
	emit_signal("queue_changed", _queue.size())
	return {
		"ok": true,
		"matched": false,
		"ticket_id": ticket_id
	}

func enqueue_public_1v1(_profile: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if _player_access_token.is_empty():
		return {"ok": false, "err": "player_token_required"}
	var request_id: String = str(context.get("request_id", "")).strip_edges()
	if request_id.is_empty():
		request_id = _new_public_request_id("enqueue")
	return _call_public_transport("enqueue_public_1v1", {
		"request_id": request_id,
		"mode_id": _public_duel_mode_id(context),
		"protocol_version": PUBLIC_MATCH_PROTOCOL_VERSION,
		"client_build": _public_client_build()
	})

func poll_public_1v1(ticket_id: String) -> Dictionary:
	return _call_public_transport("poll_public_1v1", {"ticket_id": ticket_id.strip_edges()})

func cancel_public_1v1(ticket_id: String, request_id: String = "") -> Dictionary:
	var clean_request_id: String = request_id.strip_edges()
	if clean_request_id.is_empty():
		clean_request_id = _new_public_request_id("cancel")
	return _call_public_transport("cancel_public_1v1", {
		"ticket_id": ticket_id.strip_edges(),
		"request_id": clean_request_id
	})

func get_public_bot_fallback_offer(ticket_id: String) -> Dictionary:
	return _call_public_transport("get_public_bot_fallback_offer", {
		"ticket_id": ticket_id.strip_edges()
	})

func accept_public_bot_fallback(ticket_id: String, request_id: String = "") -> Dictionary:
	var clean_request_id: String = request_id.strip_edges()
	if clean_request_id.is_empty():
		clean_request_id = _new_public_request_id("bot_fallback")
	return _call_public_transport("accept_public_bot_fallback", {
		"ticket_id": ticket_id.strip_edges(),
		"request_id": clean_request_id
	})

func _public_duel_mode_id(context: Dictionary) -> String:
	if bool(context.get("vs_crucible", false)) or str(context.get("vs_ruleset", "")).strip_edges().to_upper() == "CRUCIBLE":
		return "CRUCIBLE_1V1"
	var mode: String = str(context.get("mode", context.get("vs_mode", "1V1"))).strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	if mode == "CAPTURE_FLAG" or mode == "CTF":
		return "CTF_1V1"
	if mode == "HIDDEN_CAPTURE_FLAG" or mode == "HIDDEN_CTF" or mode == "HCTF":
		return "HCTF_1V1"
	if mode == "3P_FFA":
		return "STANDARD_3P_FFA"
	if mode == "2V2":
		return "STANDARD_2V2"
	if mode == "4P_FFA":
		return "STANDARD_4P_FFA"
	return "STANDARD_1V1"

func get_public_1v1_session(match_id: String) -> Dictionary:
	var result: Dictionary = _call_public_transport("get_public_1v1_session", {"match_id": match_id.strip_edges()})
	if not bool(result.get("ok", false)):
		return {}
	return result.get("session", {}) as Dictionary

func set_public_1v1_ready(match_id: String, ready: bool, request_id: String = "") -> Dictionary:
	return _call_public_transport("set_public_1v1_ready", {
		"match_id": match_id.strip_edges(),
		"ready": ready,
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("ready")
	})

func start_public_1v1(match_id: String, request_id: String = "") -> Dictionary:
	return _call_public_transport("start_public_1v1", {
		"match_id": match_id.strip_edges(),
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("start")
	})

func publish_public_1v1_command(match_id: String, command: Dictionary) -> Dictionary:
	var payload_command: Dictionary = command.duplicate(true)
	var command_id: String = str(payload_command.get("client_command_id", "")).strip_edges()
	if command_id.is_empty():
		command_id = _new_public_request_id("command")
		payload_command["client_command_id"] = command_id
	return _call_public_transport("publish_public_1v1_command", {
		"match_id": match_id.strip_edges(),
		"client_command_id": command_id,
		"command": payload_command
	})

func poll_public_1v1_commands(match_id: String, after_seq: int = 0) -> Dictionary:
	return _call_public_transport("poll_public_1v1_commands", {
		"match_id": match_id.strip_edges(),
		"after_seq": maxi(0, after_seq)
	})

func leave_public_1v1(match_id: String, request_id: String = "") -> Dictionary:
	return _call_public_transport("leave_public_1v1", {
		"match_id": match_id.strip_edges(),
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("leave")
	})

func resume_public_1v1(request_id: String = "") -> Dictionary:
	return _call_public_transport("resume_public_1v1", {
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("resume")
	})

func submit_public_1v1_terminal_report(match_id: String, final_state_hash: String,
		elapsed_sim_ticks: int, claimed_terminal_reason: String,
		claimed_winner_player_id: String = "", diagnostics: Dictionary = {}, request_id: String = "") -> Dictionary:
	var clean_request_id: String = request_id.strip_edges()
	if clean_request_id.is_empty():
		clean_request_id = _new_public_request_id("terminal")
	return _call_public_transport("submit_public_1v1_terminal_report", {
		"match_id": match_id.strip_edges(),
		"request_id": clean_request_id,
		"final_state_hash": final_state_hash.strip_edges().to_lower(),
		"elapsed_sim_ticks": maxi(0, elapsed_sim_ticks),
		"claimed_terminal_reason": claimed_terminal_reason.strip_edges().to_upper(),
		"claimed_winner_player_id": claimed_winner_player_id.strip_edges(),
		"diagnostics": diagnostics.duplicate(true)
	})

func get_public_1v1_result(match_id: String) -> Dictionary:
	return _call_public_transport("get_public_1v1_result", {"match_id": match_id.strip_edges()})

func list_public_contests(family: String = "", scope: String = "", map_count: int = 0) -> Dictionary:
	var payload: Dictionary = {"client_build": _public_client_build()}
	if not family.strip_edges().is_empty():
		payload["family"] = family.strip_edges().to_upper()
	if not scope.strip_edges().is_empty():
		payload["scope"] = scope.strip_edges().to_upper()
	if map_count > 0:
		payload["map_count"] = map_count
	return _call_public_transport("list_public_contests", payload)

func enter_public_contest(contest_id: String, request_id: String = "") -> Dictionary:
	return _call_public_transport("enter_public_contest", {
		"contest_id": contest_id.strip_edges(),
		"client_build": _public_client_build(),
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("contest_enter")
	})

func get_public_contest_leaderboard(contest_id: String, limit: int = 25) -> Dictionary:
	return _call_public_transport("get_public_contest_leaderboard", {
		"contest_id": contest_id.strip_edges(), "limit": clampi(limit, 1, 100),
		"client_build": _public_client_build()
	})

func submit_public_contest_evidence(contest_id: String, attempt: Dictionary, evidence: Dictionary,
		request_id: String = "") -> Dictionary:
	return _call_public_transport("submit_public_contest_evidence", {
		"contest_id": contest_id.strip_edges(),
		"attempt_id": str(attempt.get("attempt_id", "")).strip_edges(),
		"definition_hash": str(attempt.get("definition_hash", "")).strip_edges(),
		"grant_hash": str(attempt.get("grant_hash", "")).strip_edges(),
		"client_build": _public_client_build(),
		"evidence": evidence.duplicate(true),
		"request_id": request_id.strip_edges() if not request_id.strip_edges().is_empty() else _new_public_request_id("contest_evidence")
	})

func get_public_contest_evidence(evidence_id: String) -> Dictionary:
	return _call_public_transport("get_public_contest_evidence", {"evidence_id": evidence_id.strip_edges(),
		"client_build": _public_client_build()})

func list_public_contest_messages(limit: int = 25) -> Dictionary:
	return _call_public_transport("list_public_contest_messages", {"limit": clampi(limit, 1, 100),
		"client_build": _public_client_build()})

func acknowledge_public_contest_message(event_id: String) -> Dictionary:
	return _call_public_transport("ack_public_contest_message", {"event_id": event_id.strip_edges(),
		"client_build": _public_client_build()})

func get_public_global_rank(limit: int = 25) -> Dictionary:
	var transport: Dictionary = _call_transport("get_public_global_rank", {"limit": clampi(limit, 1, 100),
		"client_build": _public_client_build()})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "err": "public_leaderboard_unavailable"}

func poll_quick_match(ticket_id: String) -> Dictionary:
	var transport := _call_transport("poll_quick_match", {
		"ticket_id": ticket_id
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for session_any in _sessions.values():
		var session: Dictionary = session_any as Dictionary
		var source: String = str(session.get("source", ""))
		if source != "quick":
			continue
		var ticket_found: bool = false
		for roster_any in _session_roster(session):
			if typeof(roster_any) == TYPE_DICTIONARY and str((roster_any as Dictionary).get("ticket_id", "")) == tid:
				ticket_found = true
				break
		if ticket_found:
			return {
				"ok": true,
				"matched": true,
				"session_id": str(session.get("id", "")),
				"session": _dup_session(session)
			}
	for ticket_any in _queue:
		var ticket: Dictionary = ticket_any as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		ticket["last_seen_unix"] = int(Time.get_unix_time_from_system())
		return {"ok": true, "matched": false, "ticket_id": tid}
	return {"ok": false, "err": "ticket_not_found"}

func cancel_quick_match(ticket_id: String, uid: String = "") -> Dictionary:
	if _durable_public_ticket_ids.has(ticket_id.strip_edges()):
		return cancel_public_1v1(ticket_id)
	var transport := _call_transport("cancel_quick_match", {
		"ticket_id": ticket_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for i in range(_queue.size()):
		var ticket: Dictionary = _queue[i] as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		var owner_uid: String = str(ticket.get("uid", ""))
		if uid.strip_edges() != "" and owner_uid != uid:
			return {"ok": false, "err": "ticket_owner_mismatch"}
		_queue.remove_at(i)
		emit_signal("queue_changed", _queue.size())
		return {"ok": true}
	return {"ok": false, "err": "ticket_not_found"}

func debug_fill_quick_match(ticket_id: String, bot_name: String = "Rival") -> Dictionary:
	var transport := _call_transport("debug_fill_quick_match", {
		"ticket_id": ticket_id,
		"bot_name": bot_name
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var tid: String = ticket_id.strip_edges()
	if tid.is_empty():
		return {"ok": false, "err": "ticket_empty"}
	for i in range(_queue.size()):
		var ticket: Dictionary = _queue[i] as Dictionary
		if str(ticket.get("id", "")) != tid:
			continue
		var host: Dictionary = {
			"uid": str(ticket.get("uid", "")),
			"display_name": str(ticket.get("display_name", "Player")),
			"ready": false,
			"ticket_id": tid
		}
		var context: Dictionary = ticket.get("context", {}) as Dictionary
		var session: Dictionary = _new_session(host, context, "quick")
		session["guest"] = {
			"uid": _next_bot_uid(),
			"display_name": bot_name,
			"ready": true
		}
		var start_result: Dictionary = _mark_session_started(session)
		if not bool(start_result.get("ok", false)):
			return start_result
		var session_id: String = str(session.get("id", ""))
		_sessions[session_id] = session
		_invite_to_session[str(session.get("invite_code", ""))] = session_id
		_queue.remove_at(i)
		emit_signal("queue_changed", _queue.size())
		_emit_session_changed(session_id)
		return {"ok": true, "session_id": session_id, "session": _dup_session(session)}
	return {"ok": false, "err": "ticket_not_found"}

func debug_fill_session(session_id: String, bot_name: String = "Rival") -> Dictionary:
	var transport := _call_transport("debug_fill_session", {
		"session_id": session_id,
		"bot_name": bot_name
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty() or not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	if str(guest.get("uid", "")) == "":
		session["guest"] = {
			"uid": _next_bot_uid(),
			"display_name": bot_name,
			"ready": false
		}
	var start_result: Dictionary = _mark_session_started(session)
	if not bool(start_result.get("ok", false)):
		return start_result
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session_id": sid, "session": _dup_session(session)}

func fill_free_bot_match(ticket_id: String = "", session_id: String = "", bot_name: String = "Rival") -> Dictionary:
	var payload: Dictionary = {"bot_name": bot_name}
	if not ticket_id.strip_edges().is_empty():
		payload["ticket_id"] = ticket_id.strip_edges()
	elif not session_id.strip_edges().is_empty():
		payload["session_id"] = session_id.strip_edges()
	else:
		return {"ok": false, "err": "missing_ticket_or_session_id"}
	var transport := _call_transport("fill_free_bot_match", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	# Local mode never crosses a production trust boundary.
	if not ticket_id.strip_edges().is_empty():
		return debug_fill_quick_match(ticket_id, bot_name)
	return debug_fill_session(session_id, bot_name)

func get_session(session_id: String) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return get_public_1v1_session(session_id)
	var transport := _call_transport("get_session", {"session_id": session_id})
	if bool(transport.get("handled", false)):
		var result: Dictionary = transport.get("result", {}) as Dictionary
		var session_v: Variant = result.get("session", {})
		if typeof(session_v) == TYPE_DICTIONARY:
			return session_v as Dictionary
		if bool(result.get("ok", false)):
			return result
		return {}
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty() or not _sessions.has(sid):
		return {}
	return _dup_session(_sessions.get(sid, {}) as Dictionary)

func get_session_sync_async(session_id: String) -> Dictionary:
	var started_ticks_ms: int = Time.get_ticks_msec()
	var started_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var transport: Dictionary = await _call_transport_async("get_session", {"session_id": session_id})
	if bool(transport.get("handled", false)):
		return _with_client_clock_sample(transport.get("result", {}) as Dictionary, started_ticks_ms, started_unix_ms)
	var session: Dictionary = get_session(session_id)
	var local_result: Dictionary = {"ok": not session.is_empty(), "session": session}
	if session.is_empty():
		local_result["err"] = "session_not_found"
	return _with_client_clock_sample(_with_server_perf_meta(local_result, started_ticks_ms), started_ticks_ms, started_unix_ms)

func set_ready_sync_async(session_id: String, uid: String, ready: bool) -> Dictionary:
	var started_ticks_ms: int = Time.get_ticks_msec()
	var started_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var transport: Dictionary = await _call_transport_async("set_ready", {
		"session_id": session_id,
		"uid": uid,
		"ready": ready
	})
	if bool(transport.get("handled", false)):
		return _with_client_clock_sample(transport.get("result", {}) as Dictionary, started_ticks_ms, started_unix_ms)
	var local_result: Dictionary = set_ready(session_id, uid, ready)
	return _with_client_clock_sample(_with_server_perf_meta(local_result, started_ticks_ms), started_ticks_ms, started_unix_ms)

func start_session_sync_async(session_id: String, uid: String) -> Dictionary:
	var started_ticks_ms: int = Time.get_ticks_msec()
	var started_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var transport: Dictionary = await _call_transport_async("start_session", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return _with_client_clock_sample(transport.get("result", {}) as Dictionary, started_ticks_ms, started_unix_ms)
	var local_result: Dictionary = start_session(session_id, uid)
	return _with_client_clock_sample(_with_server_perf_meta(local_result, started_ticks_ms), started_ticks_ms, started_unix_ms)

func _with_client_clock_sample(result: Dictionary, started_ticks_ms: int, started_unix_ms: int) -> Dictionary:
	var out: Dictionary = result.duplicate(true)
	var finished_ticks_ms: int = Time.get_ticks_msec()
	var finished_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var round_trip_ms: int = maxi(0, finished_ticks_ms - started_ticks_ms)
	var server_unix_ms: int = int(out.get("server_unix_ms", 0))
	out["client_round_trip_ms"] = round_trip_ms
	if server_unix_ms > 0:
		var local_midpoint_unix_ms: int = int(round((float(started_unix_ms) + float(finished_unix_ms)) * 0.5))
		var clock_offset_ms: int = server_unix_ms - local_midpoint_unix_ms
		out["client_server_clock_offset_ms"] = clock_offset_ms
		out["estimated_server_now_ms"] = finished_unix_ms + clock_offset_ms
	return out

func set_ready(session_id: String, uid: String, ready: bool) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return set_public_1v1_ready(session_id, ready)
	var transport := _call_transport("set_ready", {
		"session_id": session_id,
		"uid": uid,
		"ready": ready
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	if not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var roster: Array = _session_roster(session)
	var player_index: int = _session_roster_index_for_uid(roster, player_uid)
	if player_index < 0:
		return {"ok": false, "err": "player_not_in_session"}
	var player_entry: Dictionary = roster[player_index] as Dictionary
	player_entry["ready"] = ready
	roster[player_index] = player_entry
	_set_session_roster(session, roster)
	_session_refresh_status(session)
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session": _dup_session(session)}

func can_start(session_id: String, uid: String) -> bool:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		var public_session: Dictionary = get_public_1v1_session(session_id)
		if public_session.is_empty() or not ["ready", "started"].has(str(public_session.get("status", ""))):
			return false
		return _session_roster_index_for_uid(_session_roster(public_session), uid) >= 0
	var transport := _call_transport("can_start", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		var result: Dictionary = transport.get("result", {}) as Dictionary
		return bool(result.get("can_start", result.get("ok", false)))
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty() or not _sessions.has(sid):
		return false
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if not _session_has_required_players(session):
		return false
	var allowed_statuses: Array[String] = ["ready", "started"] if _session_uses_synchronized_start(session) else ["matched", "ready", "started"]
	if not allowed_statuses.has(str(session.get("status", ""))):
		return false
	var host: Dictionary = session.get("host", {}) as Dictionary
	return str(host.get("uid", "")) == player_uid

func start_session(session_id: String, uid: String) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return start_public_1v1(session_id)
	var transport := _call_transport("start_session", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	if not can_start(sid, uid):
		return {"ok": false, "err": "not_ready_or_not_host"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var start_result: Dictionary = _mark_session_started(session)
	if not bool(start_result.get("ok", false)):
		return start_result
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session": _dup_session(session)}

func settle_money_match(session_id: String, winner_owner_id: int, reason: String = "") -> Dictionary:
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty():
		return {"ok": false, "err": "missing_session_id", "code": "missing_session_id"}
	var session: Dictionary = _money_session_for_settlement(sid)
	if session.is_empty():
		return {"ok": false, "err": "session_not_found", "code": "session_not_found"}
	var context: Dictionary = session.get("context", {}) as Dictionary
	if not bool(context.get("paid_entry", false)):
		return {"ok": true, "type": "no_money_settlement_required", "session_id": sid, "ledger_required": false}
	if str(context.get("ledger_status", "")).strip_edges().to_lower() == "refunded":
		return {
			"ok": false,
			"err": "money_match_already_refunded",
			"code": "money_match_already_refunded",
			"session_id": sid
		}
	var clean_reason: String = reason.strip_edges()
	if winner_owner_id <= 0:
		var refund_transport := _call_transport("refund_money_match", {
			"session_id": sid,
			"reason": clean_reason if not clean_reason.is_empty() else "draw_or_no_winner",
			"idempotency_key": "refund:%s:%s" % [sid, clean_reason if not clean_reason.is_empty() else "draw_or_no_winner"]
		})
		if bool(refund_transport.get("handled", false)):
			return _money_transport_result_with_owner(refund_transport.get("result", {}) as Dictionary, session, winner_owner_id, "")
		return _refund_money_match_for_session(session, clean_reason if not clean_reason.is_empty() else "draw_or_no_winner")
	var winner_uid: String = _money_player_uid_for_owner_id(session, winner_owner_id)
	if winner_uid.is_empty():
		return {
			"ok": false,
			"err": "winner_not_in_match",
			"code": "winner_not_in_match",
			"session_id": sid,
			"winner_owner_id": winner_owner_id
		}
	var settle_transport := _call_transport("settle_money_match", {
		"session_id": sid,
		"winner_id": winner_uid,
		"idempotency_key": "settle:%s:%s" % [sid, winner_uid]
	})
	if bool(settle_transport.get("handled", false)):
		return _money_transport_result_with_owner(settle_transport.get("result", {}) as Dictionary, session, winner_owner_id, winner_uid)
	var settle_result: Dictionary = _money_ledger.intent_settle_match(
		sid,
		winner_uid,
		"settle:%s:%s" % [sid, winner_uid]
	)
	if not bool(settle_result.get("ok", false)):
		var out: Dictionary = settle_result.duplicate(true)
		out["err"] = str(out.get("code", out.get("err", "settlement_failed")))
		return out
	context["ledger_status"] = "settled"
	context["winner_owner_id"] = winner_owner_id
	context["winner_uid"] = winner_uid
	context["winner_payout_cents"] = int(settle_result.get("winner_payout_cents", 0))
	context["house_rake_cents"] = int(settle_result.get("house_rake_cents", 0))
	context["settle_transaction_ids"] = (settle_result.get("transaction_ids", []) as Array).duplicate(true)
	context["settle_reason"] = clean_reason
	session["context"] = context
	_sessions[sid] = session
	_emit_session_changed(sid)
	var response: Dictionary = settle_result.duplicate(true)
	response["winner_owner_id"] = winner_owner_id
	response["winner_uid"] = winner_uid
	response["session"] = _dup_session(session)
	return response

func _money_session_for_settlement(session_id: String) -> Dictionary:
	if _transport_http != null and _transport_http.configured():
		var remote_session: Dictionary = get_session(session_id)
		if not remote_session.is_empty():
			return remote_session.duplicate(true)
	if _sessions.has(session_id):
		return (_sessions.get(session_id, {}) as Dictionary).duplicate(true)
	return {}

func _money_transport_result_with_owner(result: Dictionary, session: Dictionary, winner_owner_id: int, winner_uid: String) -> Dictionary:
	var out: Dictionary = result.duplicate(true)
	if bool(out.get("ok", false)):
		out["winner_owner_id"] = winner_owner_id
		if not winner_uid.strip_edges().is_empty():
			out["winner_uid"] = winner_uid
		if not out.has("session") and not session.is_empty():
			out["session"] = session.duplicate(true)
	return out

func get_money_rematch_funding_status(session_id: String, owner_id: int) -> Dictionary:
	var sid: String = session_id.strip_edges()
	if sid.is_empty():
		return {"ok": false, "err": "missing_session_id", "code": "missing_session_id"}
	if not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found", "code": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var context: Dictionary = session.get("context", {}) as Dictionary
	if not bool(context.get("paid_entry", false)):
		return {"ok": true, "payment_required": false, "paid_entry": false, "session_id": sid}
	var player_uid: String = _money_player_uid_for_owner_id(session, owner_id)
	if player_uid.is_empty():
		return {
			"ok": false,
			"err": "player_not_in_session",
			"code": "player_not_in_session",
			"session_id": sid,
			"owner_id": owner_id
		}
	var wager_cents: int = maxi(0, int(context.get("wager_cents", int(context.get("price_usd", 0)) * 100)))
	var balance_cents: int = int(_money_ledger.get_balance_cents(player_uid))
	return {
		"ok": true,
		"payment_required": balance_cents < wager_cents,
		"paid_entry": true,
		"session_id": sid,
		"owner_id": owner_id,
		"player_uid": player_uid,
		"wager_cents": wager_cents,
		"balance_cents": balance_cents,
		"missing_cents": maxi(0, wager_cents - balance_cents)
	}

func prepare_money_rematch(session_id: String) -> Dictionary:
	var transport := _call_transport("prepare_money_rematch", {"session_id": session_id})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	if sid.is_empty():
		return {"ok": false, "err": "missing_session_id", "code": "missing_session_id"}
	if not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found", "code": "session_not_found"}
	var parent_session: Dictionary = (_sessions.get(sid, {}) as Dictionary).duplicate(true)
	var parent_context: Dictionary = parent_session.get("context", {}) as Dictionary
	if not bool(parent_context.get("paid_entry", false)):
		return {"ok": true, "type": "no_money_rematch_escrow_required", "session_id": sid, "ledger_required": false}
	var next_rematch_index: int = maxi(1, int(parent_context.get("rematch_index", 0)) + 1)
	var parent_key: String = "%s:%d" % [sid, next_rematch_index]
	var existing_session_id: String = str(_rematch_sessions_by_parent_key.get(parent_key, "")).strip_edges()
	if not existing_session_id.is_empty() and _sessions.has(existing_session_id):
		var existing_session: Dictionary = _sessions.get(existing_session_id, {}) as Dictionary
		return {"ok": true, "type": "money_rematch_prepared", "session_id": existing_session_id, "session": _dup_session(existing_session), "cached": true}
	var host: Dictionary = parent_session.get("host", {}) as Dictionary
	var guest: Dictionary = parent_session.get("guest", {}) as Dictionary
	if str(host.get("uid", "")).strip_edges().is_empty() or str(guest.get("uid", "")).strip_edges().is_empty():
		return {"ok": false, "err": "not_enough_players", "code": "not_enough_players"}
	var rematch_context: Dictionary = parent_context.duplicate(true)
	for key in [
		"ledger_status",
		"pot_cents",
		"escrow_cents",
		"winner_owner_id",
		"winner_uid",
		"winner_payout_cents",
		"house_rake_cents",
		"settle_transaction_ids",
		"settle_reason",
		"refund_reason",
		"refund_transaction_ids"
	]:
		rematch_context.erase(key)
	rematch_context["rematch_parent_session_id"] = sid
	rematch_context["rematch_index"] = next_rematch_index
	var rematch_session: Dictionary = _new_session(host, rematch_context, "rematch")
	rematch_session["guest"] = {
		"uid": str(guest.get("uid", "")),
		"display_name": str(guest.get("display_name", "Player 2")),
		"ready": true,
		"tier_id": str(guest.get("tier_id", "DRONE")),
		"rank_position": int(guest.get("rank_position", 0)),
		"wax_score": float(guest.get("wax_score", 0.0)),
		"color_id": str(guest.get("color_id", "GREEN"))
	}
	_set_session_roster(rematch_session, [host, rematch_session.get("guest", {}) as Dictionary])
	var start_result: Dictionary = _mark_session_started(rematch_session)
	if not bool(start_result.get("ok", false)):
		return start_result
	var rematch_session_id: String = str(rematch_session.get("id", ""))
	_sessions[rematch_session_id] = rematch_session
	_invite_to_session[str(rematch_session.get("invite_code", ""))] = rematch_session_id
	_rematch_sessions_by_parent_key[parent_key] = rematch_session_id
	parent_context["next_rematch_session_id"] = rematch_session_id
	parent_session["context"] = parent_context
	_sessions[sid] = parent_session
	_emit_session_changed(rematch_session_id)
	return {
		"ok": true,
		"type": "money_rematch_prepared",
		"session_id": rematch_session_id,
		"parent_session_id": sid,
		"session": _dup_session(rematch_session)
	}

func leave_session(session_id: String, uid: String) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return leave_public_1v1(session_id)
	var transport := _call_transport("leave_session", {
		"session_id": session_id,
		"uid": uid
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var player_uid: String = uid.strip_edges()
	if sid.is_empty() or player_uid.is_empty() or not _sessions.has(sid):
		return {"ok": false, "err": "session_not_found"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	var host: Dictionary = session.get("host", {}) as Dictionary
	if str(host.get("uid", "")) == player_uid:
		_close_session_internal(sid, "host_left")
		return {"ok": true, "closed": true}
	var roster: Array = _session_roster(session)
	var player_index: int = _session_roster_index_for_uid(roster, player_uid)
	if player_index < 0:
		return {"ok": false, "err": "player_not_in_session"}
	roster.remove_at(player_index)
	for i in range(roster.size()):
		var remaining: Dictionary = roster[i] as Dictionary
		remaining["ready"] = false
		roster[i] = remaining
	_set_session_roster(session, roster)
	_session_refresh_status(session)
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "closed": false, "session": _dup_session(session)}

func heartbeat(profile: Dictionary) -> Dictionary:
	var transport := _call_transport("heartbeat", {"profile": profile})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _heartbeat_local(profile)

func heartbeat_async(profile: Dictionary) -> Dictionary:
	var transport: Dictionary = await _call_transport_async("heartbeat", {"profile": profile})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _heartbeat_local(profile)

func _heartbeat_local(profile: Dictionary) -> Dictionary:
	var player: Dictionary = _normalize_profile(profile)
	if player.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	var uid: String = str(player.get("uid", "")).strip_edges()
	var presence: Dictionary = {
		"uid": uid,
		"display_name": str(player.get("display_name", uid)),
		"last_seen_unix": int(Time.get_unix_time_from_system())
	}
	_presence_by_uid[uid] = presence
	return {"ok": true, "presence": presence.duplicate(true)}

func list_online_friends(uid: String, friends: Array) -> Dictionary:
	var transport := _call_transport("list_online_friends", {
		"uid": uid,
		"friends": friends
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _list_online_friends_local(uid, friends)

func list_online_friends_async(uid: String, friends: Array) -> Dictionary:
	var transport: Dictionary = await _call_transport_async("list_online_friends", {
		"uid": uid,
		"friends": friends
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _list_online_friends_local(uid, friends)

func _list_online_friends_local(uid: String, friends: Array) -> Dictionary:
	_prune()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var out: Array = []
	for friend_any in friends:
		var friend_id: String = str(friend_any).strip_edges()
		if friend_id.is_empty() or friend_id == uid:
			continue
		var presence: Dictionary = _presence_by_uid.get(friend_id, {}) as Dictionary
		if presence.is_empty():
			continue
		if now_unix - int(presence.get("last_seen_unix", 0)) > QUEUE_TTL_SEC * 2:
			continue
		out.append(presence.duplicate(true))
	return {"ok": true, "online": out}

func create_friend_invite(profile: Dictionary, target_uid: String, context: Dictionary = {}) -> Dictionary:
	var transport := _call_transport("create_friend_invite", {
		"profile": profile,
		"target_uid": target_uid,
		"context": context
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var host: Dictionary = _normalize_profile(profile)
	var clean_target: String = target_uid.strip_edges()
	if host.is_empty():
		return {"ok": false, "err": "invalid_profile"}
	if clean_target.is_empty() or clean_target == str(host.get("uid", "")):
		return {"ok": false, "err": "invalid_target"}
	var session: Dictionary = _new_session(host, context, "invite")
	var session_id: String = str(session.get("id", ""))
	_sessions[session_id] = session
	_invite_to_session[str(session.get("invite_code", ""))] = session_id
	var now_unix: int = int(Time.get_unix_time_from_system())
	var invite: Dictionary = {
		"id": _next_friend_invite_id(),
		"from_uid": str(host.get("uid", "")),
		"from_name": str(host.get("display_name", "Player 1")),
		"target_uid": clean_target,
		"session_id": session_id,
		"context": context.duplicate(true),
		"created_unix": now_unix,
		"expires_unix": now_unix + SESSION_TTL_SEC,
		"status": "pending"
	}
	_friend_invites[str(invite.get("id", ""))] = invite
	_emit_session_changed(session_id)
	return {"ok": true, "invite": invite.duplicate(true), "session_id": session_id, "session": _dup_session(session)}

func poll_friend_invites(uid: String) -> Dictionary:
	var transport := _call_transport("poll_friend_invites", {"uid": uid})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _poll_friend_invites_local(uid)

func poll_friend_invites_async(uid: String) -> Dictionary:
	var transport: Dictionary = await _call_transport_async("poll_friend_invites", {"uid": uid})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return _poll_friend_invites_local(uid)

func _poll_friend_invites_local(uid: String) -> Dictionary:
	_prune()
	var clean_uid: String = uid.strip_edges()
	if clean_uid.is_empty():
		return {"ok": false, "err": "invalid_uid"}
	var out: Array = []
	for invite_any in _friend_invites.values():
		var invite: Dictionary = invite_any as Dictionary
		if str(invite.get("target_uid", "")) != clean_uid:
			continue
		if str(invite.get("status", "")) != "pending":
			continue
		out.append(invite.duplicate(true))
	return {"ok": true, "invites": out}

func respond_friend_invite(invite_id: String, profile: Dictionary, accept: bool) -> Dictionary:
	var transport := _call_transport("respond_friend_invite", {
		"invite_id": invite_id,
		"profile": profile,
		"accept": accept
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var clean_id: String = invite_id.strip_edges()
	if clean_id.is_empty() or not _friend_invites.has(clean_id):
		return {"ok": false, "err": "invite_not_found"}
	var invite: Dictionary = _friend_invites.get(clean_id, {}) as Dictionary
	if str(invite.get("status", "")) != "pending":
		return {"ok": false, "err": "invite_not_found"}
	var guest: Dictionary = _normalize_profile(profile)
	if guest.is_empty() or str(guest.get("uid", "")) != str(invite.get("target_uid", "")):
		return {"ok": false, "err": "invalid_profile"}
	if not accept:
		invite["status"] = "rejected"
		_friend_invites[clean_id] = invite
		return {"ok": true, "accepted": false}
	var session_id: String = str(invite.get("session_id", ""))
	var session: Dictionary = _sessions.get(session_id, {}) as Dictionary
	if session.is_empty() or not _is_session_live(session):
		invite["status"] = "expired"
		_friend_invites[clean_id] = invite
		return {"ok": false, "err": "session_not_found"}
	session["guest"] = {
		"uid": str(guest.get("uid", "")),
		"display_name": str(guest.get("display_name", "Player 2")),
		"ready": false
	}
	var roster: Array = _session_roster(session)
	if _session_roster_index_for_uid(roster, str(guest.get("uid", ""))) < 0:
		roster.append(_roster_player_from_profile(guest, roster.size() + 1, false))
	_set_session_roster(session, roster)
	if _session_has_required_players(session):
		var start_result: Dictionary = _mark_session_started(session)
		if not bool(start_result.get("ok", false)):
			return start_result
	else:
		_session_refresh_status(session)
	_sessions[session_id] = session
	invite["status"] = "accepted"
	_friend_invites[clean_id] = invite
	_emit_session_changed(session_id)
	return {"ok": true, "accepted": true, "session_id": session_id, "session": _dup_session(session)}

func publish_intent(session_id: String, uid: String, command: Dictionary) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return publish_public_1v1_command(session_id, command)
	var start_ms: int = Time.get_ticks_msec()
	var transport := _call_transport("publish_intent", {
		"session_id": session_id,
		"uid": uid,
		"command": command
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var sender_uid: String = uid.strip_edges()
	if sid.is_empty() or sender_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if session.is_empty():
		return {"ok": false, "err": "session_not_found"}
	if not _session_has_player_uid(session, sender_uid):
		return {"ok": false, "err": "player_not_in_session"}
	var roster: Array = _session_roster(session)
	var roster_index: int = _session_roster_index_for_uid(roster, sender_uid)
	var expected_seat: int = roster_index + 1
	var claimed_seat: int = int(command.get("sender_seat", 0))
	if claimed_seat > 0 and claimed_seat != expected_seat:
		return {"ok": false, "err": "sender_seat_mismatch", "expected_seat": expected_seat}
	var authoritative_input: Dictionary = command.duplicate(true)
	authoritative_input["sender_seat"] = expected_seat
	var stream: Dictionary = _intent_streams.get(sid, {"next_seq": 1, "events": []}) as Dictionary
	var seq: int = int(stream.get("next_seq", 1))
	if seq <= 0:
		seq = 1
	stream["next_seq"] = seq + 1
	var canonical_command: Dictionary = _canonicalize_authoritative_command(sid, sender_uid, authoritative_input, seq, stream)
	var events_any: Variant = stream.get("events", [])
	var events: Array = events_any as Array if typeof(events_any) == TYPE_ARRAY else []
	var event: Dictionary = {
		"seq": seq,
		"uid": sender_uid,
		"command": canonical_command.duplicate(true),
		"ts_unix": int(Time.get_unix_time_from_system())
	}
	events.append(event)
	while events.size() > INTENT_STREAM_MAX_EVENTS:
		events.remove_at(0)
	stream["events"] = events
	_intent_streams[sid] = stream
	return _with_server_perf_meta({
		"ok": true,
		"seq": seq,
		"command_seq": seq,
		"command_id": str(canonical_command.get("command_id", "")),
		"command": canonical_command.duplicate(true),
		"canonical_command": canonical_command.duplicate(true)
	}, start_ms)

func _canonicalize_authoritative_command(session_id: String, sender_uid: String, command: Dictionary, seq: int, stream: Dictionary) -> Dictionary:
	var canonical: Dictionary = command.duplicate(true)
	var command_seq: int = maxi(1, int(seq))
	var issued_tick: int = int(canonical.get("issued_tick", canonical.get("local_issued_tick", 0)))
	var requested_execute_tick: int = int(canonical.get("execute_tick", canonical.get("requested_execute_tick", -1)))
	var last_execute_tick: int = int(stream.get("last_execute_tick", -1))
	var min_execute_tick: int = issued_tick + AUTH_COMMAND_LEAD_TICKS
	var execute_tick: int = requested_execute_tick
	if execute_tick < min_execute_tick:
		execute_tick = min_execute_tick
	if execute_tick <= last_execute_tick:
		execute_tick = last_execute_tick + 1
	stream["last_execute_tick"] = execute_tick
	canonical["command_seq"] = command_seq
	canonical["command_id"] = "%s:%d" % [session_id, command_seq]
	canonical["authority_session_id"] = session_id
	canonical["authority_uid"] = sender_uid
	canonical["canonical_execute_tick"] = execute_tick
	canonical["execute_tick"] = execute_tick
	canonical["requested_execute_tick"] = requested_execute_tick
	canonical["authority_action"] = "accepted" if execute_tick == requested_execute_tick else "rebased"
	return canonical

func poll_intents(session_id: String, uid: String, after_seq: int = 0) -> Dictionary:
	if _durable_public_match_ids.has(session_id.strip_edges()):
		return poll_public_1v1_commands(session_id, after_seq)
	var start_ms: int = Time.get_ticks_msec()
	var transport := _call_transport("poll_intents", {
		"session_id": session_id,
		"uid": uid,
		"after_seq": after_seq
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	_prune()
	var sid: String = session_id.strip_edges()
	var viewer_uid: String = uid.strip_edges()
	if sid.is_empty() or viewer_uid.is_empty():
		return {"ok": false, "err": "invalid_args"}
	var session: Dictionary = _sessions.get(sid, {}) as Dictionary
	if session.is_empty():
		return {"ok": false, "err": "session_not_found"}
	if not _session_has_player_uid(session, viewer_uid):
		return {"ok": false, "err": "player_not_in_session"}
	var stream: Dictionary = _intent_streams.get(sid, {}) as Dictionary
	if stream.is_empty():
		return _with_server_perf_meta({"ok": true, "events": [], "latest_seq": maxi(0, after_seq)}, start_ms)
	var events_any: Variant = stream.get("events", [])
	if typeof(events_any) != TYPE_ARRAY:
		return _with_server_perf_meta({"ok": true, "events": [], "latest_seq": maxi(0, after_seq)}, start_ms)
	var events: Array = events_any as Array
	var out: Array = []
	var latest_seq: int = maxi(0, after_seq)
	for e_any in events:
		if typeof(e_any) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_any as Dictionary
		var seq: int = int(e.get("seq", 0))
		if seq > latest_seq:
			latest_seq = seq
		if seq <= after_seq:
			continue
		out.append(e.duplicate(true))
	return _with_server_perf_meta({"ok": true, "events": out, "latest_seq": latest_seq}, start_ms)

func create_spectator_grant(session_id: String, role: String = "invited_spectator", spectator_uid: String = "", display_name: String = "Spectator", delay_sec: int = 20) -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": false, "handled": true, "err": "observer_mode_disabled"}
	var payload: Dictionary = {
		"session_id": session_id,
		"role": role,
		"spectator_uid": spectator_uid,
		"display_name": display_name,
		"delay_sec": delay_sec
	}
	var transport := _call_transport("create_spectator_grant", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func join_spectate(grant_token: String, session_id: String = "", spectator_uid: String = "") -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": false, "handled": true, "err": "observer_mode_disabled"}
	var payload: Dictionary = {
		"grant_token": grant_token,
		"session_id": session_id,
		"spectator_uid": spectator_uid
	}
	var transport := _call_transport("join_spectate", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func poll_spectator_events(grant_token: String, session_id: String = "", after_seq: int = 0) -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": false, "handled": true, "err": "observer_mode_disabled"}
	var payload: Dictionary = {
		"grant_token": grant_token,
		"session_id": session_id,
		"after_seq": after_seq
	}
	var transport := _call_transport("poll_spectator_events", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func publish_spectator_snapshot(session_id: String, uid: String, snapshot: Dictionary) -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": false, "handled": true, "err": "observer_mode_disabled"}
	var transport := _call_transport("publish_spectator_snapshot", {
		"session_id": session_id,
		"uid": uid,
		"snapshot": snapshot
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func poll_spectator_snapshots(grant_token: String, session_id: String = "", after_seq: int = 0) -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": false, "handled": true, "err": "observer_mode_disabled"}
	var payload: Dictionary = {
		"grant_token": grant_token,
		"session_id": session_id,
		"after_seq": after_seq
	}
	var transport := _call_transport("poll_spectator_snapshots", payload)
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func leave_spectate(grant_token: String) -> Dictionary:
	if not _ops_observer_mode_enabled():
		return {"ok": true, "closed": true, "observer_mode_disabled": true}
	var transport := _call_transport("leave_spectate", {
		"grant_token": grant_token
	})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
	return {"ok": false, "handled": false, "err": "transport_not_configured"}

func _with_server_perf_meta(result: Dictionary, start_ms: int) -> Dictionary:
	var out: Dictionary = result.duplicate(true)
	out["server_unix_ms"] = int(round(Time.get_unix_time_from_system() * 1000.0))
	out["server_frametime_ms"] = maxi(0, Time.get_ticks_msec() - start_ms)
	out["server_tick_rate_hz"] = 0.0
	return out

func _session_has_player_uid(session: Dictionary, uid: String) -> bool:
	if session.is_empty():
		return false
	var target_uid: String = uid.strip_edges()
	if target_uid.is_empty():
		return false
	return _session_roster_index_for_uid(_session_roster(session), target_uid) >= 0

func _new_session(host: Dictionary, context: Dictionary, source: String) -> Dictionary:
	var now_unix: int = int(Time.get_unix_time_from_system())
	var session_id: String = _next_session_id()
	var invite_code: String = _next_invite_code()
	var session_context: Dictionary = _prepare_session_context(context)
	var host_copy: Dictionary = {
		"uid": str(host.get("uid", "")),
		"display_name": str(host.get("display_name", "Player 1")),
		"ready": false,
		"tier_id": str(host.get("tier_id", "DRONE")),
		"rank_position": int(host.get("rank_position", 0)),
		"wax_score": float(host.get("wax_score", 0.0)),
		"color_id": str(host.get("color_id", "GREEN"))
	}
	if host.has("ticket_id"):
		host_copy["ticket_id"] = str(host.get("ticket_id", ""))
	var session: Dictionary = {
		"id": session_id,
		"invite_code": invite_code,
		"source": source,
		"context": session_context,
		"created_unix": now_unix,
		"expires_unix": now_unix + SESSION_TTL_SEC,
		"status": "waiting",
		"host": host_copy,
		"guest": {
			"uid": "",
			"display_name": "",
			"ready": false
		},
		"close_reason": ""
	}
	_set_session_roster(session, [_roster_player_from_profile(host_copy, 1, true)])
	return session

func _required_players_for_context(context: Dictionary) -> int:
	var declared: int = int(context.get("required_players", 0))
	var mode: String = str(context.get("mode", "")).strip_edges().to_upper().replace("_", " ").replace("-", " ")
	var inferred: int = 2
	match mode:
		"2V2", "4P FFA":
			inferred = 4
		"3P FFA":
			inferred = 3
		_:
			inferred = 2
	if declared > 0 and declared != inferred:
		SFLog.warn("VS_SESSION_CONTRACT_NORMALIZED", {
			"mode": mode,
			"declared_required_players": declared,
			"required_players": inferred
		})
	return clampi(inferred, 2, MAX_SYNC_PLAYERS)

func _session_required_players(session: Dictionary) -> int:
	var context: Dictionary = session.get("context", {}) as Dictionary
	return _required_players_for_context(context)

func _session_has_required_players(session: Dictionary) -> bool:
	return _session_roster(session).size() >= _session_required_players(session)

func _session_roster(session: Dictionary) -> Array:
	var roster_any: Variant = session.get("roster", [])
	if typeof(roster_any) == TYPE_ARRAY and not (roster_any as Array).is_empty():
		return (roster_any as Array).duplicate(true)
	var legacy: Array = []
	for key in ["host", "guest"]:
		var profile_any: Variant = session.get(key, {})
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		if str(profile.get("uid", "")).strip_edges().is_empty():
			continue
		legacy.append(_roster_player_from_profile(profile, legacy.size() + 1, legacy.is_empty()))
	return legacy

func _session_roster_index_for_uid(roster: Array, uid: String) -> int:
	var target_uid: String = uid.strip_edges()
	if target_uid.is_empty():
		return -1
	for i in range(roster.size()):
		if typeof(roster[i]) != TYPE_DICTIONARY:
			continue
		if str((roster[i] as Dictionary).get("uid", "")).strip_edges() == target_uid:
			return i
	return -1

func _roster_player_from_profile(profile: Dictionary, seat: int, is_host: bool) -> Dictionary:
	var clean_seat: int = clampi(seat, 1, MAX_SYNC_PLAYERS)
	var player: Dictionary = {
		"uid": str(profile.get("uid", "")).strip_edges(),
		"display_name": str(profile.get("display_name", "Player %d" % clean_seat)),
		"ready": bool(profile.get("ready", false)),
		"seat": clean_seat,
		"role": "host" if is_host else "player",
		"team_id": clean_seat
	}
	for key in ["ticket_id", "tier_id", "rank_position", "wax_score", "color_id", "balance_cents", "crucible_wax_millis", "is_cpu"]:
		if profile.has(key):
			player[key] = profile[key]
	return player

func _set_session_roster(session: Dictionary, roster: Array) -> void:
	var normalized: Array = []
	for player_any in roster:
		if typeof(player_any) != TYPE_DICTIONARY or normalized.size() >= MAX_SYNC_PLAYERS:
			continue
		var profile: Dictionary = player_any as Dictionary
		var uid: String = str(profile.get("uid", "")).strip_edges()
		if uid.is_empty() or _session_roster_index_for_uid(normalized, uid) >= 0:
			continue
		var seat: int = normalized.size() + 1
		var normalized_player: Dictionary = _roster_player_from_profile(profile, seat, seat == 1)
		var mode: String = str((session.get("context", {}) as Dictionary).get("mode", "")).strip_edges().to_upper()
		if mode == "2V2":
			normalized_player["team_id"] = 1 if seat == 1 or seat == 3 else 2
		normalized.append(normalized_player)
	session["roster"] = normalized
	session["required_players"] = _session_required_players(session)
	session["contract_version"] = SESSION_CONTRACT_VERSION
	if not normalized.is_empty():
		session["host"] = (normalized[0] as Dictionary).duplicate(true)
	else:
		session["host"] = {"uid": "", "display_name": "", "ready": false}
	if normalized.size() > 1:
		session["guest"] = (normalized[1] as Dictionary).duplicate(true)
	else:
		session["guest"] = {"uid": "", "display_name": "", "ready": false}
	session["contract_hash"] = _session_contract_hash(session)

func _session_contract_hash(session: Dictionary) -> String:
	var context: Dictionary = session.get("context", {}) as Dictionary
	var parts: PackedStringArray = PackedStringArray([
		"v%d" % SESSION_CONTRACT_VERSION,
		str(context.get("mode", "")).strip_edges().to_upper(),
		str(_session_required_players(session)),
		str(context.get("map_count", 1)),
		str(context.get("stage_map_paths", [])),
		str(context.get("match_setup", context.get(MatchSetupRandomizer.CONTEXT_KEY, {})))
	])
	var roster_any: Variant = session.get("roster", [])
	if typeof(roster_any) == TYPE_ARRAY:
		for player_any in roster_any as Array:
			if typeof(player_any) != TYPE_DICTIONARY:
				continue
			var player: Dictionary = player_any as Dictionary
			parts.append("%d:%s:%d" % [int(player.get("seat", 0)), str(player.get("uid", "")), int(player.get("team_id", 0))])
	return "|".join(parts).sha256_text()

func _prepare_session_context(context: Dictionary) -> Dictionary:
	var out: Dictionary = context.duplicate(true)
	var price_usd: int = maxi(0, int(out.get("price_usd", 0)))
	var wager_cents: int = maxi(0, int(out.get("wager_cents", price_usd * 100)))
	var free_roll: bool = bool(out.get("free_roll", price_usd <= 0 and wager_cents <= 0))
	if free_roll or wager_cents <= 0:
		free_roll = true
		price_usd = 0
		wager_cents = 0
	out["price_usd"] = price_usd
	out["wager_cents"] = wager_cents
	out["free_roll"] = free_roll
	out["paid_entry"] = not free_roll and wager_cents > 0
	out["required_players"] = _required_players_for_context(out)
	out["session_contract_version"] = SESSION_CONTRACT_VERSION
	var requested_count: int = maxi(1, int(out.get("map_count", 1)))
	var stage_maps: Array[String] = _stage_map_paths_from_context_stage_paths(out, requested_count)
	if stage_maps.is_empty():
		var selected_maps: Array[String] = _select_stage_map_paths_for_context(out)
		if not selected_maps.is_empty():
			stage_maps = selected_maps
	if not stage_maps.is_empty():
		out["stage_map_paths"] = stage_maps
	else:
		out.erase("stage_map_paths")
	if not out.has(MatchSetupRandomizer.CONTEXT_KEY):
		out[MatchSetupRandomizer.CONTEXT_KEY] = MatchSetupRandomizer.roll(_rng)
	return out

func _context_has_stage_maps(context: Dictionary) -> bool:
	return not _stage_map_paths_from_context_stage_paths(context, 1).is_empty()

func _select_stage_map_paths_for_context(context: Dictionary) -> Array[String]:
	var requested_count: int = maxi(1, int(context.get("map_count", 1)))
	var picked: Array[String] = _stage_map_paths_from_map_ids(context, requested_count)
	if picked.size() >= requested_count:
		return picked
	var mode: String = str(context.get("mode", "")).strip_edges().to_upper()
	var pool: Array[String] = _candidate_stage_map_paths_for_mode(mode)
	while picked.size() < requested_count and not pool.is_empty():
		var idx: int = _rng.randi_range(0, pool.size() - 1)
		var path: String = str(pool[idx])
		if not picked.has(path):
			picked.append(path)
		pool.remove_at(idx)
	return picked

func _stage_map_paths_from_map_ids(context: Dictionary, requested_count: int) -> Array[String]:
	var picked: Array[String] = []
	var mode: String = str(context.get("mode", "")).strip_edges().to_upper()
	var ids_v: Variant = context.get("map_ids", [])
	var ids: Array = []
	if typeof(ids_v) == TYPE_ARRAY:
		ids = ids_v as Array
	elif typeof(ids_v) == TYPE_PACKED_STRING_ARRAY:
		for id_any in ids_v as PackedStringArray:
			ids.append(str(id_any))
	for id_any in ids:
		var resolved_path: String = MAP_LOADER._resolve_map_path(str(id_any))
		var map_path: String = _stage_map_path_variant_for_mode(resolved_path, mode)
		if map_path.is_empty() or picked.has(map_path):
			continue
		var validation: Dictionary = _stage_map_path_supports_mode(map_path, mode)
		if not bool(validation.get("ok", false)):
			continue
		picked.append(map_path)
		if picked.size() >= requested_count:
			break
	return picked

func _stage_map_paths_from_context_stage_paths(context: Dictionary, requested_count: int) -> Array[String]:
	var picked: Array[String] = []
	var mode: String = str(context.get("mode", "")).strip_edges().to_upper()
	var paths_v: Variant = context.get("stage_map_paths", [])
	if typeof(paths_v) != TYPE_ARRAY:
		return picked
	for path_any in paths_v as Array:
		var raw_path: String = str(path_any).strip_edges()
		var map_path: String = _stage_map_path_variant_for_mode(raw_path, mode)
		if map_path.is_empty() or picked.has(map_path):
			continue
		if not FileAccess.file_exists(map_path):
			continue
		var validation: Dictionary = _stage_map_path_supports_mode(map_path, mode)
		if not bool(validation.get("ok", false)):
			_report_map_mode_contract_violation(mode, map_path, str(validation.get("reason", "invalid_map_mode")))
			continue
		picked.append(map_path)
		if picked.size() >= requested_count:
			break
	return picked

func _candidate_stage_map_paths_for_mode(mode: String) -> Array[String]:
	var out: Array[String] = []
	for path_any in MAP_LOADER.list_maps():
		var source_path: String = str(path_any).strip_edges()
		var path: String = _stage_map_path_variant_for_mode(source_path, mode)
		if path.is_empty():
			continue
		if out.has(path):
			continue
		var validation: Dictionary = _stage_map_path_supports_mode(path, mode)
		if not bool(validation.get("ok", false)):
			continue
		out.append(path)
	return out

func _stage_map_path_variant_for_mode(path: String, mode: String) -> String:
	var clean_path: String = path.strip_edges()
	if clean_path.is_empty():
		return ""
	var required_variant: String = _required_player_variant_for_mode(mode)
	if required_variant.is_empty():
		return clean_path
	var source_variant: String = MAP_REGISTRY.player_variant_for_path(clean_path)
	if source_variant == required_variant:
		return clean_path
	if source_variant.is_empty():
		return ""
	var sibling_path: String = clean_path.trim_suffix("__%s.json" % source_variant) + "__%s.json" % required_variant
	if FileAccess.file_exists(sibling_path):
		return sibling_path
	return ""

func _stage_map_path_supports_mode(path: String, mode: String) -> Dictionary:
	var required_variant: String = _required_player_variant_for_mode(mode)
	if not required_variant.is_empty() and MAP_REGISTRY.player_variant_for_path(path) != required_variant:
		return {
			"ok": false,
			"reason": "requires_%s_map_path" % required_variant
		}
	var loaded: Dictionary = MAP_LOADER.load_map(path)
	if not bool(loaded.get("ok", false)):
		return {
			"ok": false,
			"reason": str(loaded.get("err", "load_failed"))
		}
	var data: Dictionary = loaded.get("data", {}) as Dictionary
	var summary: Dictionary = MapModeRules.map_supports_game_mode(data, mode)
	if not bool(summary.get("ok", false)):
		return summary
	var owner_summary: Dictionary = MapModeRules.map_matches_active_owner_contract(data, mode)
	if not bool(owner_summary.get("ok", false)):
		return owner_summary
	return {
		"ok": true,
		"reason": ""
	}

func _required_player_variant_for_mode(mode: String) -> String:
	var clean_mode: String = mode.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	match clean_mode:
		"1V1", "PVP":
			return "1p"
		"2V2":
			return "2p"
		"3P_FFA":
			return "3p"
		"4P_FFA":
			return "4p"
		_:
			return ""

func _report_map_mode_contract_violation(mode: String, path: String, reason: String) -> void:
	var payload: Dictionary = {
		"mode": mode,
		"map_path": path,
		"reason": reason
	}
	SFLog.warn("MAP_MODE_CONTRACT_VIOLATION", payload)
	push_error("MAP_MODE_CONTRACT_VIOLATION: mode=%s map=%s reason=%s" % [mode, path.get_file().get_basename(), reason])

func _map_buckets_for_mode(mode: String) -> Array[String]:
	match mode:
		"2V2":
			return ["2V2"]
		"4P FFA":
			return ["4P_FFA", "4P FFA"]
		"3P FFA":
			return ["3P_FFA", "3P FFA"]
		"CAPTURE_FLAG", "HIDDEN_CAPTURE_FLAG":
			return ["1P", "2P", "4P", "CTF"]
		_:
			return ["1V1", "1P", "2P"]

func _map_data_matches_buckets(data: Dictionary, required_buckets: Array[String]) -> bool:
	if required_buckets.is_empty():
		return true
	var buckets_v: Variant = data.get("player_buckets", [])
	var buckets: Array[String] = []
	if typeof(buckets_v) == TYPE_ARRAY:
		for bucket_any in buckets_v as Array:
			var normalized: String = _normalize_bucket(str(bucket_any))
			if not normalized.is_empty():
				buckets.append(normalized)
	var mode: String = _normalize_bucket(str(data.get("mode", "")))
	if not mode.is_empty():
		buckets.append(mode)
	for required in required_buckets:
		if buckets.has(_normalize_bucket(required)):
			return true
	return false

func _normalize_bucket(value: String) -> String:
	return value.strip_edges().to_upper().replace(" ", "_").replace("-", "_")

func _session_refresh_status(session: Dictionary) -> void:
	var roster: Array = _session_roster(session)
	if roster.size() < _session_required_players(session):
		session["status"] = "waiting"
		return
	var all_ready: bool = true
	for player_any in roster:
		if typeof(player_any) != TYPE_DICTIONARY or not bool((player_any as Dictionary).get("ready", false)):
			all_ready = false
			break
	if all_ready:
		session["status"] = "ready"
		return
	session["status"] = "matched"

func _session_uses_synchronized_start(session: Dictionary) -> bool:
	var context: Dictionary = session.get("context", {}) as Dictionary
	return bool(context.get("human_pvp", false)) \
		and bool(context.get("free_roll", false)) \
		and not bool(context.get("paid_entry", false)) \
		and not bool(context.get("vs_crucible", false)) \
		and str(context.get("vs_ruleset", "")).strip_edges().to_upper() != "CRUCIBLE"

func _mark_session_started(session: Dictionary) -> Dictionary:
	if not _session_has_required_players(session):
		return {
			"ok": false,
			"err": "not_enough_players",
			"code": "not_enough_players",
			"required_players": _session_required_players(session),
			"current_players": _session_roster(session).size()
		}
	var escrow_result: Dictionary = _ensure_money_escrow_for_session(session)
	if not bool(escrow_result.get("ok", false)):
		return escrow_result
	session["status"] = "started"
	var lead_ms: int = SYNCHRONIZED_START_LEAD_MS if _session_uses_synchronized_start(session) else 0
	var start_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0)) + lead_ms
	session["start_unix_ms"] = start_unix_ms
	session["started_unix"] = int(floor(float(start_unix_ms) / 1000.0))
	return {"ok": true, "session": _dup_session(session)}

func _ensure_money_escrow_for_session(session: Dictionary) -> Dictionary:
	var context: Dictionary = session.get("context", {}) as Dictionary
	if not bool(context.get("paid_entry", false)):
		return {"ok": true, "ledger_required": false}
	if str(context.get("ledger_status", "")).strip_edges().to_lower() == "escrowed":
		return {"ok": true, "ledger_required": true, "ledger_status": "escrowed"}
	var session_id: String = str(session.get("id", "")).strip_edges()
	if session_id.is_empty():
		return {"ok": false, "err": "missing_session_id", "code": "missing_session_id"}
	var player_ids: Array[String] = _money_player_ids_for_session(session)
	if player_ids.size() < 2:
		return {"ok": false, "err": "not_enough_players", "code": "not_enough_players", "message": "Paid VS requires two funded players."}
	var wager_cents: int = maxi(0, int(context.get("wager_cents", int(context.get("price_usd", 0)) * 100)))
	if wager_cents <= 0:
		return {"ok": false, "err": "invalid_wager", "code": "invalid_wager", "message": "Paid VS wager must be positive integer cents."}
	var escrow_result: Dictionary = _money_ledger.intent_open_escrow(
		session_id,
		player_ids,
		wager_cents,
		"open:%s" % session_id
	)
	if not bool(escrow_result.get("ok", false)):
		var out: Dictionary = escrow_result.duplicate(true)
		out["err"] = str(out.get("code", out.get("err", "escrow_failed")))
		return out
	context["ledger_status"] = "escrowed"
	context["wager_cents"] = wager_cents
	context["pot_cents"] = int(escrow_result.get("pot_cents", wager_cents * player_ids.size()))
	context["escrow_cents"] = int(escrow_result.get("escrow_cents", context.get("pot_cents", 0)))
	session["context"] = context
	return {"ok": true, "ledger_required": true, "ledger_status": "escrowed", "escrow": escrow_result}

func _money_player_ids_for_session(session: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for profile_any in _session_roster(session):
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		var uid: String = str(profile.get("uid", "")).strip_edges()
		if uid.is_empty():
			continue
		out.append(uid)
	return out

func _money_player_uid_for_owner_id(session: Dictionary, owner_id: int) -> String:
	for profile_any in _session_roster(session):
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		if int(profile.get("seat", 0)) == owner_id:
			return str(profile.get("uid", "")).strip_edges()
	return ""

func _refund_money_match_for_session(session: Dictionary, reason: String) -> Dictionary:
	var sid: String = str(session.get("id", "")).strip_edges()
	if sid.is_empty():
		return {"ok": false, "err": "missing_session_id", "code": "missing_session_id"}
	var clean_reason: String = reason.strip_edges()
	if clean_reason.is_empty():
		clean_reason = "money_match_refund"
	var refund_result: Dictionary = _money_ledger.intent_refund_match(
		sid,
		clean_reason,
		"refund:%s:%s" % [sid, clean_reason]
	)
	if not bool(refund_result.get("ok", false)):
		var out: Dictionary = refund_result.duplicate(true)
		out["err"] = str(out.get("code", out.get("err", "refund_failed")))
		return out
	var context: Dictionary = session.get("context", {}) as Dictionary
	context["ledger_status"] = "refunded"
	context["refund_reason"] = clean_reason
	context["refund_transaction_ids"] = (refund_result.get("transaction_ids", []) as Array).duplicate(true)
	session["context"] = context
	_sessions[sid] = session
	_emit_session_changed(sid)
	var response: Dictionary = refund_result.duplicate(true)
	response["session"] = _dup_session(session)
	return response

func _contexts_compatible(a: Dictionary, b: Dictionary) -> bool:
	if str(a.get("mode", "")) != str(b.get("mode", "")):
		return false
	if int(a.get("map_count", 0)) != int(b.get("map_count", 0)):
		return false
	if int(a.get("price_usd", 0)) != int(b.get("price_usd", 0)):
		return false
	if _context_wager_cents(a) != _context_wager_cents(b):
		return false
	if _context_paid_entry(a) != _context_paid_entry(b):
		return false
	if bool(a.get("free_roll", false)) != bool(b.get("free_roll", false)):
		return false
	var context_keys: Array[String] = ["map_ids", "stage_map_paths", "contest_id", "contest_scope"]
	if bool(a.get("human_pvp", false)) or bool(b.get("human_pvp", false)):
		context_keys = ["contest_id", "contest_scope"]
	for key in context_keys:
		if not _context_value_matches(a, b, key):
			return false
	return true

func _context_wager_cents(context: Dictionary) -> int:
	return maxi(0, int(context.get("wager_cents", int(context.get("price_usd", 0)) * 100)))

func _context_paid_entry(context: Dictionary) -> bool:
	if context.has("paid_entry"):
		return bool(context.get("paid_entry", false))
	var wager_cents: int = _context_wager_cents(context)
	var free_roll: bool = bool(context.get("free_roll", int(context.get("price_usd", 0)) <= 0 and wager_cents <= 0))
	return not free_roll and wager_cents > 0

func _best_quick_match_index(player: Dictionary, context: Dictionary) -> int:
	var best_index: int = -1
	var best_score: Array = []
	for i in range(_queue.size()):
		var ticket: Dictionary = _queue[i] as Dictionary
		if str(ticket.get("uid", "")) == str(player.get("uid", "")):
			continue
		if not _contexts_compatible(context, ticket.get("context", {}) as Dictionary):
			continue
		var score: Array = _quick_match_score(player, ticket)
		if best_index < 0 or _compare_match_score(score, best_score) < 0:
			best_index = i
			best_score = score
	return best_index

func _quick_match_score(player: Dictionary, ticket: Dictionary) -> Array:
	var player_rank: int = maxi(0, int(player.get("rank_position", 0)))
	var ticket_rank: int = maxi(0, int(ticket.get("rank_position", 0)))
	var rank_delta: int = abs(player_rank - ticket_rank) if player_rank > 0 and ticket_rank > 0 else 999999999
	var wax_delta: float = absf(float(player.get("wax_score", 0.0)) - float(ticket.get("wax_score", 0.0)))
	var tier_delta: int = abs(_tier_index(str(player.get("tier_id", "DRONE"))) - _tier_index(str(ticket.get("tier_id", "DRONE"))))
	return [tier_delta, rank_delta, wax_delta, int(ticket.get("created_unix", 0))]

func _compare_match_score(a: Array, b: Array) -> int:
	if b.is_empty():
		return -1
	var size: int = mini(a.size(), b.size())
	for i in range(size):
		if a[i] == b[i]:
			continue
		return -1 if a[i] < b[i] else 1
	return 0

func _tier_index(tier_id: String) -> int:
	var clean: String = tier_id.strip_edges().to_upper()
	var idx: int = TIER_ORDER.find(clean)
	return idx if idx >= 0 else 99999

func _context_value_matches(a: Dictionary, b: Dictionary, key: String) -> bool:
	var a_has: bool = a.has(key)
	var b_has: bool = b.has(key)
	if a_has != b_has:
		return false
	if not a_has:
		return true
	var a_value: Variant = a.get(key)
	var b_value: Variant = b.get(key)
	if typeof(a_value) == TYPE_ARRAY or typeof(a_value) == TYPE_PACKED_STRING_ARRAY \
	or typeof(b_value) == TYPE_ARRAY or typeof(b_value) == TYPE_PACKED_STRING_ARRAY:
		return _context_string_list(a_value) == _context_string_list(b_value)
	return str(a_value) == str(b_value)

func _context_string_list(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if typeof(value) == TYPE_PACKED_STRING_ARRAY:
		for item in value as PackedStringArray:
			out.append(str(item))
		return out
	if typeof(value) == TYPE_ARRAY:
		for item in value as Array:
			out.append(str(item))
		return out
	out.append(str(value))
	return out

func _release_requires_authoritative_transport() -> bool:
	if bool(ProjectSettings.get_setting(SETTINGS_FORCE_RELEASE_GUARD_FOR_SMOKE, false)):
		return true
	return not OS.is_debug_build()

func _release_backend_url_blocker(url: String) -> String:
	var trimmed: String = url.strip_edges()
	if trimmed.is_empty():
		return "Online VS backend is not configured for this build."
	var lower: String = trimmed.to_lower()
	if not lower.begins_with("https://"):
		return "Online VS backend must use HTTPS for TestFlight."
	var host: String = _host_from_url(lower)
	if host.is_empty():
		return "Online VS backend URL is invalid."
	if _is_localhost(host):
		return "Online VS backend points at this device; TestFlight needs a deployed HTTPS backend."
	if _is_private_ipv4(host):
		return "Online VS backend points at a private/local IP; TestFlight needs a deployed HTTPS backend."
	return ""

func _host_from_url(url: String) -> String:
	var remainder: String = url
	if remainder.begins_with("https://"):
		remainder = remainder.substr(8)
	elif remainder.begins_with("http://"):
		remainder = remainder.substr(7)
	var slash_idx: int = remainder.find("/")
	if slash_idx >= 0:
		remainder = remainder.substr(0, slash_idx)
	if remainder.begins_with("["):
		var bracket_idx: int = remainder.find("]")
		if bracket_idx > 0:
			return remainder.substr(1, bracket_idx - 1)
	var colon_idx: int = remainder.rfind(":")
	if colon_idx > 0:
		remainder = remainder.substr(0, colon_idx)
	return remainder.strip_edges()

func _is_localhost(host: String) -> bool:
	var clean: String = host.strip_edges().to_lower()
	return clean == "localhost" \
		or clean == "::1" \
		or clean == "0.0.0.0" \
		or clean.begins_with("127.") \
		or clean.ends_with(".local")

func _is_private_ipv4(host: String) -> bool:
	var parts: PackedStringArray = host.split(".")
	if parts.size() != 4:
		return false
	var nums: Array[int] = []
	for part in parts:
		if not part.is_valid_int():
			return false
		var n: int = int(part)
		if n < 0 or n > 255:
			return false
		nums.append(n)
	if int(nums[0]) == 10:
		return true
	if int(nums[0]) == 192 and int(nums[1]) == 168:
		return true
	if int(nums[0]) == 172 and int(nums[1]) >= 16 and int(nums[1]) <= 31:
		return true
	return false

func _normalize_profile(profile: Dictionary) -> Dictionary:
	var uid: String = str(profile.get("uid", "")).strip_edges()
	if uid.is_empty():
		return {}
	var display_name: String = str(profile.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = "Player"
	var out: Dictionary = {
		"uid": uid,
		"display_name": display_name,
		"tier_id": str(profile.get("tier_id", "DRONE")).strip_edges().to_upper(),
		"rank_position": maxi(0, int(profile.get("rank_position", 0))),
		"wax_score": float(profile.get("wax_score", 0.0)),
		"color_id": str(profile.get("color_id", "GREEN")).strip_edges().to_upper()
	}
	if str(out.get("tier_id", "")).is_empty():
		out["tier_id"] = "DRONE"
	if str(out.get("color_id", "")).is_empty():
		out["color_id"] = "GREEN"
	return out

func _record_diagnostic(action: String, payload: Dictionary, result: Dictionary, source: String) -> void:
	if not _should_record_diagnostic(action):
		return
	var profile_uid: String = ""
	var profile_v: Variant = payload.get("profile", {})
	if typeof(profile_v) == TYPE_DICTIONARY:
		profile_uid = str((profile_v as Dictionary).get("uid", ""))
	var context_v: Variant = payload.get("context", {})
	var context_hash: int = 0
	if typeof(context_v) == TYPE_DICTIONARY:
		context_hash = JSON.stringify(context_v).hash()
	var entry: Dictionary = {
		"ts_unix": int(Time.get_unix_time_from_system()),
		"ticks_ms": Time.get_ticks_msec(),
		"source": source,
		"transport_mode": _transport_mode,
		"action": action,
		"ok": bool(result.get("ok", false)),
		"err": str(result.get("err", "")),
		"message": str(result.get("message", "")),
		"transport_error": bool(result.get("transport_error", false)),
		"matched": bool(result.get("matched", false)),
		"session_id": str(result.get("session_id", "")),
		"ticket_id": str(result.get("ticket_id", "")),
		"profile_uid": profile_uid,
		"context_hash": context_hash,
		"context": context_v
	}
	var text: String = JSON.stringify(entry)
	if text.length() > DIAGNOSTIC_MAX_PAYLOAD_CHARS:
		entry["context"] = "<trimmed>"
		text = JSON.stringify(entry)
	var mode: FileAccess.ModeFlags = FileAccess.WRITE
	if FileAccess.file_exists(DIAGNOSTIC_LOG_PATH):
		mode = FileAccess.READ_WRITE
	var file: FileAccess = FileAccess.open(DIAGNOSTIC_LOG_PATH, mode)
	if file == null:
		return
	if mode == FileAccess.READ_WRITE:
		file.seek_end()
	file.store_line(text)

func _should_record_diagnostic(action: String) -> bool:
	return [
		"create_invite",
		"join_invite",
		"enqueue_quick_match",
		"enqueue_public_1v1",
		"poll_public_1v1",
		"cancel_public_1v1",
		"get_public_bot_fallback_offer",
		"accept_public_bot_fallback",
		"get_public_1v1_session",
		"set_public_1v1_ready",
		"start_public_1v1",
		"publish_public_1v1_command",
		"poll_public_1v1_commands",
		"leave_public_1v1",
		"resume_public_1v1",
		"submit_public_1v1_terminal_report",
		"get_public_1v1_result",
		"get_public_global_rank",
		"poll_quick_match",
		"cancel_quick_match",
		"debug_fill_quick_match",
		"debug_fill_session",
		"get_session",
		"set_ready",
		"can_start",
		"start_session",
		"create_friend_invite",
		"poll_friend_invites",
		"respond_friend_invite",
		"list_online_friends"
	].has(action)

func _is_session_live(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var status: String = str(session.get("status", ""))
	if status == "started":
		return true
	var now_unix: int = int(Time.get_unix_time_from_system())
	return now_unix <= int(session.get("expires_unix", 0))

func _close_session_internal(session_id: String, reason: String) -> void:
	if not _sessions.has(session_id):
		return
	var session: Dictionary = _sessions.get(session_id, {}) as Dictionary
	var code: String = str(session.get("invite_code", ""))
	session["status"] = "closed"
	session["close_reason"] = reason
	_emit_session_changed(session_id, session)
	_sessions.erase(session_id)
	_intent_streams.erase(session_id)
	if not code.is_empty() and _invite_to_session.get(code, "") == session_id:
		_invite_to_session.erase(code)

func _dup_session(session: Dictionary) -> Dictionary:
	return session.duplicate(true)

func _next_session_id() -> String:
	for _i in range(64):
		var sid: String = "S%08d" % int(_rng.randi() % 100000000)
		if not _sessions.has(sid):
			return sid
	return "S%08d" % int(Time.get_ticks_msec() % 100000000)

func _next_ticket_id() -> String:
	for _i in range(64):
		var tid: String = "Q%08d" % int(_rng.randi() % 100000000)
		var exists: bool = false
		for ticket_any in _queue:
			var ticket: Dictionary = ticket_any as Dictionary
			if str(ticket.get("id", "")) == tid:
				exists = true
				break
		if not exists:
			return tid
	return "Q%08d" % int(Time.get_ticks_msec() % 100000000)

func _next_invite_code() -> String:
	for _i in range(32):
		var code: String = "VS%05d" % int(_rng.randi() % 100000)
		if not _invite_to_session.has(code):
			return code
	return "VS%05d" % int(int(Time.get_unix_time_from_system()) % 100000)

func _next_friend_invite_id() -> String:
	for _i in range(64):
		var iid: String = "FI%08d" % int(_rng.randi() % 100000000)
		if not _friend_invites.has(iid):
			return iid
	return "FI%08d" % int(Time.get_ticks_msec() % 100000000)

func _next_bot_uid() -> String:
	return "bot_%06d" % int(_rng.randi() % 1000000)

func _emit_session_changed(session_id: String, session_override: Dictionary = {}) -> void:
	var payload: Dictionary = session_override
	if payload.is_empty():
		payload = _sessions.get(session_id, {}) as Dictionary
	emit_signal("session_changed", session_id, _dup_session(payload))

func _prune() -> void:
	var now_unix: int = int(Time.get_unix_time_from_system())
	for i in range(_queue.size() - 1, -1, -1):
		var ticket: Dictionary = _queue[i] as Dictionary
		var last_seen_unix: int = int(ticket.get("last_seen_unix", ticket.get("created_unix", 0)))
		if now_unix - last_seen_unix > QUEUE_TTL_SEC:
			_queue.remove_at(i)
	var remove_ids: Array[String] = []
	for sid_any in _sessions.keys():
		var sid: String = str(sid_any)
		var session: Dictionary = _sessions.get(sid, {}) as Dictionary
		if str(session.get("status", "")) == "started":
			continue
		if now_unix > int(session.get("expires_unix", 0)):
			remove_ids.append(sid)
	for sid in remove_ids:
		_close_session_internal(sid, "expired")
	var stale_presence: Array[String] = []
	for uid_any in _presence_by_uid.keys():
		var uid: String = str(uid_any)
		var presence: Dictionary = _presence_by_uid.get(uid, {}) as Dictionary
		if now_unix - int(presence.get("last_seen_unix", 0)) > QUEUE_TTL_SEC * 2:
			stale_presence.append(uid)
	for uid in stale_presence:
		_presence_by_uid.erase(uid)
	for invite_id_any in _friend_invites.keys():
		var invite_id: String = str(invite_id_any)
		var invite: Dictionary = _friend_invites.get(invite_id, {}) as Dictionary
		if str(invite.get("status", "")) == "pending" and now_unix > int(invite.get("expires_unix", 0)):
			invite["status"] = "expired"
			_friend_invites[invite_id] = invite
	emit_signal("queue_changed", _queue.size())
