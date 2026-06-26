extends Node

signal ad_event(event: Dictionary)

const ZERO_ADS_ENTITLEMENT: String = "zero_ads"
const PLACEMENT_HANDSHAKE: String = "handshake"
const PLACEMENT_IN_GAME: String = "in_game"
const PLACEMENT_POST_MATCH: String = "post_match"
const FAKE_ADS_ENV: String = "SF_FAKE_ADS"
const SETTINGS_FAKE_ADS: String = "swarmfront/ads/fake_ads"

var _provider: Object = null
var _slots: Dictionary = {}

func set_provider(provider: Object) -> void:
	_provider = provider

func clear_provider() -> void:
	_provider = null

func get_policy(slot_id: String, placement: String) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var clean_placement: String = placement.strip_edges()
	var placement_allowed: bool = _is_approved_placement(clean_placement)
	var zero_ads: bool = _has_zero_ads_entitlement()
	var family_safe_only: bool = _requires_family_safe_ads()
	return {
		"allowed": placement_allowed and not zero_ads,
		"placement_allowed": placement_allowed,
		"zero_ads": zero_ads,
		"slot_id": clean_slot,
		"placement": clean_placement,
		"family_safe_only": family_safe_only,
		"personalized_ads_allowed": false,
		"auto_dismiss_sec": _auto_dismiss_sec_for_placement(clean_placement),
		"external_open_requires_tap": true,
		"interrupts_gameplay": false
	}

func request_ad(slot_id: String, placement: String, surface: Control = null) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var clean_placement: String = placement.strip_edges()
	var policy: Dictionary = get_policy(clean_slot, clean_placement)
	if clean_slot.is_empty() or not bool(policy.get("allowed", false)):
		var empty_result: Dictionary = mark_empty(clean_slot, clean_placement, policy, "policy_blocked")
		_apply_surface_fill(surface, false)
		return empty_result
	var result: Dictionary = {}
	if _provider != null and _provider.has_method("request_ad"):
		result = _provider.call("request_ad", clean_slot, clean_placement, policy) as Dictionary
	elif _fake_ads_enabled():
		result = _fake_ad_result(clean_slot, clean_placement, policy)
	else:
		result = {"ok": true, "filled": false, "reason": "no_provider", "policy": policy}
	if bool(result.get("filled", false)):
		mark_filled(clean_slot, clean_placement, policy, result.get("creative", {}) as Dictionary)
		_apply_surface_fill(surface, true)
		return result
	var reason: String = str(result.get("reason", result.get("err", "no_fill")))
	var no_fill: Dictionary = mark_empty(clean_slot, clean_placement, policy, reason)
	_apply_surface_fill(surface, false)
	return no_fill

func mark_filled(slot_id: String, placement: String = "", policy: Dictionary = {}, creative: Dictionary = {}) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	if clean_slot.is_empty():
		return {"ok": false, "reason": "missing_slot_id"}
	var record: Dictionary = {
		"slot_id": clean_slot,
		"placement": placement.strip_edges(),
		"filled": true,
		"policy": policy.duplicate(true),
		"creative": creative.duplicate(true),
		"updated_at_ms": Time.get_ticks_msec(),
		"impressions": int((_slots.get(clean_slot, {}) as Dictionary).get("impressions", 0)),
		"taps": int((_slots.get(clean_slot, {}) as Dictionary).get("taps", 0))
	}
	_slots[clean_slot] = record
	_emit_ad_event("filled", record)
	return {"ok": true, "filled": true, "slot": record.duplicate(true), "policy": policy}

func mark_empty(slot_id: String, placement: String = "", policy: Dictionary = {}, reason: String = "no_fill") -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	if clean_slot.is_empty():
		return {"ok": false, "filled": false, "reason": "missing_slot_id", "policy": policy}
	var record: Dictionary = {
		"slot_id": clean_slot,
		"placement": placement.strip_edges(),
		"filled": false,
		"reason": reason,
		"policy": policy.duplicate(true),
		"creative": {},
		"updated_at_ms": Time.get_ticks_msec(),
		"impressions": int((_slots.get(clean_slot, {}) as Dictionary).get("impressions", 0)),
		"taps": int((_slots.get(clean_slot, {}) as Dictionary).get("taps", 0))
	}
	_slots[clean_slot] = record
	_emit_ad_event("empty", record)
	return {"ok": true, "filled": false, "reason": reason, "slot": record.duplicate(true), "policy": policy}

func record_impression(slot_id: String) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var record: Dictionary = _slots.get(clean_slot, {}) as Dictionary
	if record.is_empty() or not bool(record.get("filled", false)):
		return {"ok": false, "reason": "slot_not_filled"}
	record["impressions"] = int(record.get("impressions", 0)) + 1
	record["last_impression_ms"] = Time.get_ticks_msec()
	_slots[clean_slot] = record
	_emit_ad_event("impression", record)
	return {"ok": true, "slot": record.duplicate(true)}

func record_tap(slot_id: String) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var record: Dictionary = _slots.get(clean_slot, {}) as Dictionary
	if record.is_empty() or not bool(record.get("filled", false)):
		return {"ok": false, "reason": "slot_not_filled"}
	record["taps"] = int(record.get("taps", 0)) + 1
	record["last_tap_ms"] = Time.get_ticks_msec()
	_slots[clean_slot] = record
	_emit_ad_event("tap", record)
	return {"ok": true, "slot": record.duplicate(true)}

func get_slot_state(slot_id: String) -> Dictionary:
	return (_slots.get(slot_id.strip_edges(), {}) as Dictionary).duplicate(true)

func get_all_slots() -> Dictionary:
	return _slots.duplicate(true)

func _fake_ad_result(slot_id: String, placement: String, policy: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"filled": true,
		"policy": policy,
		"creative": {
			"id": "fake_entap_%s" % slot_id,
			"title": "ENTaP",
			"body": "Test ad for Swarmfront placement validation.",
			"placement": placement
		}
	}

func _apply_surface_fill(surface: Control, filled: bool) -> void:
	if surface != null and is_instance_valid(surface) and surface.has_method("set_ad_available"):
		surface.call("set_ad_available", filled)

func _is_approved_placement(value: String) -> bool:
	return value == PLACEMENT_HANDSHAKE or value == PLACEMENT_IN_GAME or value == PLACEMENT_POST_MATCH

func _auto_dismiss_sec_for_placement(value: String) -> float:
	if value == PLACEMENT_HANDSHAKE:
		return 8.0
	if value == PLACEMENT_POST_MATCH:
		return 9.0
	return 0.0

func _fake_ads_enabled() -> bool:
	var env_value: String = OS.get_environment(FAKE_ADS_ENV).strip_edges().to_lower()
	if ["1", "true", "yes", "on"].has(env_value):
		return true
	if ProjectSettings.has_setting(SETTINGS_FAKE_ADS):
		return bool(ProjectSettings.get_setting(SETTINGS_FAKE_ADS))
	return false

func _has_zero_ads_entitlement() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null or not profile_manager.has_method("has_store_entitlement"):
		return false
	return bool(profile_manager.call("has_store_entitlement", ZERO_ADS_ENTITLEMENT))

func _requires_family_safe_ads() -> bool:
	var profile_manager: Node = get_node_or_null("/root/ProfileManager")
	if profile_manager == null or not profile_manager.has_method("get_user_id"):
		return false
	var player_id: String = str(profile_manager.call("get_user_id")).strip_edges()
	if player_id.is_empty():
		return false
	var scholastic_state: Node = get_node_or_null("/root/ScholasticState")
	if scholastic_state == null or not scholastic_state.has_method("get_player_profile_snapshot"):
		return false
	var profile: Dictionary = scholastic_state.call("get_player_profile_snapshot", player_id) as Dictionary
	if profile.is_empty():
		return false
	if str(profile.get("ecosystem", "")).strip_edges().to_upper() == "SFA":
		return true
	var privacy: Dictionary = profile.get("privacy", {}) as Dictionary
	return bool(privacy.get("is_minor", false))

func _emit_ad_event(event_type: String, record: Dictionary) -> void:
	var event: Dictionary = record.duplicate(true)
	event["type"] = event_type
	ad_event.emit(event)
