extends RefCounted

const SCHEMA_VERSION: int = 1
const PLATFORM_NAMESPACE: String = "ENTaP"
const PRODUCER_GAME: String = "swarmfront"

static func build_award_event(economy: String, unit: String, event_type: String, event_id: String, player_id: String, amount_minor: int, balance_minor: int, source_name: String, metadata: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var clean_economy: String = economy.strip_edges().to_lower()
	var clean_unit: String = unit.strip_edges().to_lower()
	var clean_event_type: String = event_type.strip_edges().to_lower()
	var clean_event_id: String = event_id.strip_edges()
	var clean_player_id: String = player_id.strip_edges()
	var clean_source: String = source_name.strip_edges().to_lower()
	if clean_event_id.is_empty():
		clean_event_id = "%s:%s:%s" % [clean_economy, clean_event_type, clean_source]
	var event: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"platform_namespace": PLATFORM_NAMESPACE,
		"producer_game": PRODUCER_GAME,
		"economy": clean_economy,
		"unit": clean_unit,
		"event_type": clean_event_type,
		"event_id": clean_event_id,
		"idempotency_key": "%s:%s:%s:%s" % [PRODUCER_GAME, clean_economy, clean_event_type, clean_event_id],
		"occurred_unix": int(Time.get_unix_time_from_system()),
		"player_ref": _player_ref(clean_player_id),
		"amount_minor": maxi(0, amount_minor),
		"balance_minor": maxi(0, balance_minor),
		"source": clean_source,
		"metadata": _sanitize_metadata(metadata),
		"extra": _sanitize_metadata(extra)
	}
	return event

static func _player_ref(player_id: String) -> Dictionary:
	var clean_id: String = player_id.strip_edges()
	return {
		"kind": "platform_player_id" if not clean_id.is_empty() else "unknown",
		"value": clean_id
	}

static func _sanitize_metadata(metadata: Dictionary) -> Dictionary:
	var blocked_keys: Dictionary = {
		"call_sign": true,
		"display_name": true,
		"username": true,
		"user_name": true,
		"email": true,
		"apple_id": true,
		"google_id": true,
		"payment": true,
		"payment_id": true,
		"card": true,
		"bank": true,
		"wallet": true,
		"financial_identity": true
	}
	var out: Dictionary = {}
	for key_any in metadata.keys():
		var key: String = str(key_any)
		if blocked_keys.has(key.strip_edges().to_lower()):
			continue
		var value: Variant = metadata[key_any]
		if typeof(value) == TYPE_DICTIONARY:
			out[key] = _sanitize_metadata(value as Dictionary)
		elif typeof(value) == TYPE_ARRAY:
			out[key] = _sanitize_array(value as Array)
		else:
			out[key] = value
	return out

static func _sanitize_array(values: Array) -> Array:
	var out: Array = []
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			out.append(_sanitize_metadata(value as Dictionary))
		elif typeof(value) == TYPE_ARRAY:
			out.append(_sanitize_array(value as Array))
		else:
			out.append(value)
	return out
