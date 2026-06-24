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
		_configured_backend_token()
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

func get_diagnostic_log_path() -> String:
	return ProjectSettings.globalize_path(DIAGNOSTIC_LOG_PATH)

func get_beta_runtime_flags() -> Dictionary:
	var remote_online: bool = is_authoritative_transport_online()
	return {
		"match_authority": "local_ops_state",
		"progression_authority": "remote_authoritative" if remote_online else "local_provisional",
		"transport_mode": get_transport_mode(),
		"competitive_provisional": not remote_online,
		"authoritative_progression_online": remote_online
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

func approve_async_contest_payout_report(report: Dictionary, approver_id: String, idempotency_key: String) -> Dictionary:
	var transport := _call_transport("approve_async_contest_payout_report", {
		"report": report,
		"approver_id": approver_id,
		"idempotency_key": idempotency_key
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
	var existing_guest: Dictionary = session.get("guest", {}) as Dictionary
	var existing_guest_uid: String = str(existing_guest.get("uid", ""))
	if existing_guest_uid != "" and existing_guest_uid != str(guest.get("uid", "")):
		return {"ok": false, "err": "invite_full"}
	session["guest"] = {
		"uid": str(guest.get("uid", "")),
		"display_name": str(guest.get("display_name", "Player 2")),
		"ready": bool(existing_guest.get("ready", false))
	}
	var start_result: Dictionary = _mark_session_started(session)
	if not bool(start_result.get("ok", false)):
		return start_result
	_sessions[session_id] = session
	_emit_session_changed(session_id)
	return {"ok": true, "session_id": session_id, "session": _dup_session(session)}

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
		var start_result: Dictionary = _mark_session_started(session)
		if not bool(start_result.get("ok", false)):
			return start_result
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
		var host: Dictionary = session.get("host", {}) as Dictionary
		var guest: Dictionary = session.get("guest", {}) as Dictionary
		if str(host.get("ticket_id", "")) == tid or str(guest.get("ticket_id", "")) == tid:
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

func get_session(session_id: String) -> Dictionary:
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

func set_ready(session_id: String, uid: String, ready: bool) -> Dictionary:
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
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var host_uid: String = str(host.get("uid", ""))
	var guest_uid: String = str(guest.get("uid", ""))
	if player_uid == host_uid:
		host["ready"] = ready
		session["host"] = host
	elif player_uid == guest_uid and guest_uid != "":
		guest["ready"] = ready
		session["guest"] = guest
	else:
		return {"ok": false, "err": "player_not_in_session"}
	_session_refresh_status(session)
	_sessions[sid] = session
	_emit_session_changed(sid)
	return {"ok": true, "session": _dup_session(session)}

func can_start(session_id: String, uid: String) -> bool:
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
	if not ["matched", "ready", "started"].has(str(session.get("status", ""))):
		return false
	var host: Dictionary = session.get("host", {}) as Dictionary
	return str(host.get("uid", "")) == player_uid

func start_session(session_id: String, uid: String) -> Dictionary:
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
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	if str(host.get("uid", "")) == player_uid:
		_close_session_internal(sid, "host_left")
		return {"ok": true, "closed": true}
	if str(guest.get("uid", "")) == player_uid:
		session["guest"] = {"uid": "", "display_name": "", "ready": false}
		host["ready"] = false
		session["host"] = host
		_session_refresh_status(session)
		_sessions[sid] = session
		_emit_session_changed(sid)
		return {"ok": true, "closed": false, "session": _dup_session(session)}
	return {"ok": false, "err": "player_not_in_session"}

func heartbeat(profile: Dictionary) -> Dictionary:
	var transport := _call_transport("heartbeat", {"profile": profile})
	if bool(transport.get("handled", false)):
		return transport.get("result", {}) as Dictionary
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
	var start_result: Dictionary = _mark_session_started(session)
	if not bool(start_result.get("ok", false)):
		return start_result
	_sessions[session_id] = session
	invite["status"] = "accepted"
	_friend_invites[clean_id] = invite
	_emit_session_changed(session_id)
	return {"ok": true, "accepted": true, "session_id": session_id, "session": _dup_session(session)}

func publish_intent(session_id: String, uid: String, command: Dictionary) -> Dictionary:
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
	var stream: Dictionary = _intent_streams.get(sid, {"next_seq": 1, "events": []}) as Dictionary
	var seq: int = int(stream.get("next_seq", 1))
	if seq <= 0:
		seq = 1
	stream["next_seq"] = seq + 1
	var canonical_command: Dictionary = _canonicalize_authoritative_command(sid, sender_uid, command, seq, stream)
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
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	return str(host.get("uid", "")) == target_uid or str(guest.get("uid", "")) == target_uid

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
	return {
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
	var host: Dictionary = session.get("host", {}) as Dictionary
	var guest: Dictionary = session.get("guest", {}) as Dictionary
	var guest_uid: String = str(guest.get("uid", ""))
	var host_ready: bool = bool(host.get("ready", false))
	var guest_ready: bool = bool(guest.get("ready", false))
	if guest_uid == "":
		session["status"] = "waiting"
		return
	if host_ready and guest_ready:
		session["status"] = "ready"
		return
	session["status"] = "matched"

func _mark_session_started(session: Dictionary) -> Dictionary:
	var escrow_result: Dictionary = _ensure_money_escrow_for_session(session)
	if not bool(escrow_result.get("ok", false)):
		return escrow_result
	session["status"] = "started"
	session["started_unix"] = int(Time.get_unix_time_from_system())
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
	for key in ["host", "guest"]:
		var profile_any: Variant = session.get(key, {})
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		var uid: String = str(profile.get("uid", "")).strip_edges()
		if uid.is_empty():
			continue
		out.append(uid)
	return out

func _money_player_uid_for_owner_id(session: Dictionary, owner_id: int) -> String:
	var key: String = ""
	match owner_id:
		1:
			key = "host"
		2:
			key = "guest"
		_:
			return ""
	var profile_any: Variant = session.get(key, {})
	if typeof(profile_any) != TYPE_DICTIONARY:
		return ""
	return str((profile_any as Dictionary).get("uid", "")).strip_edges()

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
