extends RefCounted

# Product policy: change this decision here if money-game resume is introduced.
const ALLOW_MONEY_RESUME := false

static func eligibility(context: Dictionary, roster: Array = []) -> Dictionary:
	var paid: bool = bool(context.get("vs_paid_entry", false)) \
		or float(context.get("vs_price_usd", 0)) > 0.0 \
		or int(context.get("vs_wager_cents", 0)) > 0 \
		or not str(context.get("async_money_entry_id", "")).is_empty() \
		or bool(context.get("vs_crucible", false)) \
		or str(context.get("vs_ruleset", "")).to_upper() == "CRUCIBLE"
	if paid and not ALLOW_MONEY_RESUME:
		return {"ok": false, "reason": "money_game"}
	if not str(context.get("vs_handshake_session_id", "")).is_empty() or bool(context.get("vs_sync_start", false)):
		return {"ok": false, "reason": "live_multiplayer"}
	var humans := 0
	for seat in roster:
		if seat is Dictionary and bool(seat.get("active", true)) and not bool(seat.get("is_cpu", false)):
			humans += 1
	if humans > 1:
		return {"ok": false, "reason": "multiplayer"}
	return {"ok": true}

static func deadline(context: Dictionary) -> int:
	var earliest := 0
	for key in ["vs_window_deadline_unix", "hive_tournament_deadline_unix", "saved_contest_end_unix"]:
		earliest = _earliest(earliest, int(context.get(key, 0)))
	for key in ["public_contest_submission_deadline_at", "public_contest_ends_at"]:
		earliest = _earliest(earliest, parse_deadline(str(context.get(key, ""))))
	var attempt: Dictionary = context.get("public_contest_attempt", {})
	earliest = _earliest(earliest, parse_deadline(str(attempt.get("submission_deadline_at", ""))))
	return earliest

static func parse_deadline(value: String) -> int:
	if value.is_empty():
		return 0
	# Service timestamps are ISO-8601 UTC, optionally with fractional seconds.
	return int(Time.get_unix_time_from_datetime_string(value.trim_suffix("Z").split(".")[0]))

static func _earliest(a: int, b: int) -> int:
	return b if b > 0 and (a <= 0 or b < a) else a
