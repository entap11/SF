extends Node

signal ad_event(event: Dictionary)

const ZERO_ADS_ENTITLEMENT: String = "zero_ads"
const PLACEMENT_HANDSHAKE: String = "handshake"
const PLACEMENT_IN_GAME: String = "in_game"
const PLACEMENT_POST_MATCH: String = "post_match"
const FAKE_ADS_ENV: String = "SF_FAKE_ADS"
const DEV_BIODYNAMIC_ADS_ENV: String = "SF_BIODYNAMIC_TEST_ADS"
const SETTINGS_FAKE_ADS: String = "swarmfront/ads/fake_ads"
const SETTINGS_DEV_BIODYNAMIC_ADS: String = "swarmfront/ads/dev_biodynamic_test_ads"
const SETTINGS_DEV_BIODYNAMIC_IMAGE_PATH: String = "swarmfront/ads/dev_biodynamic_image_path"
const SETTINGS_DEV_BIODYNAMIC_DESTINATION_URL: String = "swarmfront/ads/dev_biodynamic_destination_url"
const SETTINGS_DEV_BIODYNAMIC_OPEN_URL_ON_TAP: String = "swarmfront/ads/dev_biodynamic_open_url_on_tap"
const CONTENT_MODE_AD: String = "ad"
const CONTENT_MODE_INTERNAL_TICKER: String = "internal_ticker"
const CONTENT_MODE_HIDDEN: String = "hidden"
const MEASUREMENT_SCHEMA_VERSION: int = 1
const DEV_BIODYNAMIC_DEFAULT_IMAGE_PATH: String = "res://assets/ads/test_creatives/biodynamic_laser_cleaning_banner.png"
const DEV_BIODYNAMIC_DEFAULT_DESTINATION_URL: String = "https://www.biodynamicusa.com"

var _provider: Object = null
var _measurement_sink: Object = null
var _slots: Dictionary = {}
var _measurement_events: Array[Dictionary] = []
var _event_sequence: int = 0
var _provider_is_dev_test: bool = false

class DevBiodynamicTestProvider:
	extends RefCounted

	var image_path: String = ""
	var destination_url: String = ""
	var open_url_on_tap: bool = true
	var opened_urls: Array[String] = []
	var recorded_events: Array[Dictionary] = []

	func _init(image_path_in: String, destination_url_in: String, open_url_on_tap_in: bool) -> void:
		image_path = image_path_in.strip_edges()
		destination_url = _normalized_url(destination_url_in)
		open_url_on_tap = open_url_on_tap_in

	func request_ad(slot_id: String, placement: String, policy: Dictionary) -> Dictionary:
		if not bool(policy.get("allowed", false)):
			return {"ok": true, "filled": false, "reason": "policy_blocked", "policy": policy}
		if image_path.is_empty() or not FileAccess.file_exists(image_path):
			return {"ok": true, "filled": false, "reason": "creative_missing", "policy": policy}
		return {
			"ok": true,
			"filled": true,
			"policy": policy,
			"creative": {
				"id": "dev_biodynamic_%s" % slot_id,
				"campaign_id": "biodynamic_local_dev",
				"provider": "dev_biodynamic_test_provider",
				"image_path": image_path,
				"destination_url": destination_url,
				"placement": placement
			}
		}

	func record_ad_event(event: Dictionary) -> void:
		recorded_events.append(event.duplicate(true))

	func open_ad(slot_record: Dictionary, _event: Dictionary) -> Dictionary:
		var creative: Dictionary = slot_record.get("creative", {}) as Dictionary
		var url: String = _normalized_url(str(creative.get("destination_url", destination_url)))
		if url.is_empty():
			return {"ok": false, "reason": "missing_destination_url"}
		opened_urls.append(url)
		if not open_url_on_tap:
			return {"ok": true, "url": url, "opened": false, "reason": "open_disabled"}
		var err: Error = OS.shell_open(url)
		return {"ok": err == OK, "url": url, "opened": err == OK, "open_err": int(err)}

	func _normalized_url(raw_url: String) -> String:
		var clean: String = raw_url.strip_edges()
		if clean.is_empty():
			return ""
		if clean.begins_with("http://") or clean.begins_with("https://"):
			return clean
		return "https://%s" % clean

func _ready() -> void:
	_install_dev_biodynamic_provider_if_enabled()

func set_provider(provider: Object) -> void:
	_provider = provider
	_provider_is_dev_test = false

func clear_provider() -> void:
	_provider = null
	_provider_is_dev_test = false

func set_measurement_sink(sink: Object) -> void:
	_measurement_sink = sink

func clear_measurement_sink() -> void:
	_measurement_sink = null

func get_policy(slot_id: String, placement: String) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var clean_placement: String = placement.strip_edges()
	var placement_allowed: bool = _is_approved_placement(clean_placement)
	var zero_ads: bool = _has_zero_ads_entitlement()
	var family_safe_only: bool = _requires_family_safe_ads()
	var external_ads_allowed: bool = placement_allowed and not zero_ads and _external_ads_enabled()
	var house_ads_allowed: bool = placement_allowed and _house_ads_enabled()
	return {
		"allowed": external_ads_allowed,
		"ad_allowed": external_ads_allowed,
		"surface_allowed": placement_allowed,
		"placement_allowed": placement_allowed,
		"zero_ads": zero_ads,
		"slot_id": clean_slot,
		"placement": clean_placement,
		"content_mode": _content_mode_for_policy(placement_allowed, zero_ads, external_ads_allowed, house_ads_allowed),
		"house_ads_allowed": house_ads_allowed,
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
		"filled_at_unix_ms": _unix_time_ms(),
		"impression_recorded": false,
		"impressions": int((_slots.get(clean_slot, {}) as Dictionary).get("impressions", 0)),
		"taps": int((_slots.get(clean_slot, {}) as Dictionary).get("taps", 0)),
		"conversions": int((_slots.get(clean_slot, {}) as Dictionary).get("conversions", 0))
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
		"filled_at_unix_ms": 0,
		"impression_recorded": false,
		"impressions": int((_slots.get(clean_slot, {}) as Dictionary).get("impressions", 0)),
		"taps": int((_slots.get(clean_slot, {}) as Dictionary).get("taps", 0)),
		"conversions": int((_slots.get(clean_slot, {}) as Dictionary).get("conversions", 0))
	}
	_slots[clean_slot] = record
	_emit_ad_event("empty", record)
	return {"ok": true, "filled": false, "reason": reason, "slot": record.duplicate(true), "policy": policy}

func record_impression(slot_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var record: Dictionary = _slots.get(clean_slot, {}) as Dictionary
	if record.is_empty() or not bool(record.get("filled", false)):
		return {"ok": false, "reason": "slot_not_filled"}
	if bool(record.get("impression_recorded", false)) and not bool(context.get("allow_duplicate", false)):
		return {"ok": false, "reason": "impression_already_recorded", "slot": record.duplicate(true)}
	record["impressions"] = int(record.get("impressions", 0)) + 1
	record["last_impression_ms"] = Time.get_ticks_msec()
	record["last_impression_unix_ms"] = _unix_time_ms()
	record["impression_recorded"] = true
	var measurement: Dictionary = _record_measurement_event("impression", record, context)
	record["last_impression_event_id"] = str(measurement.get("event_id", ""))
	_slots[clean_slot] = record
	_emit_ad_event("impression", record)
	return {"ok": true, "slot": record.duplicate(true), "event": measurement}

func record_tap(slot_id: String, context: Dictionary = {}) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var record: Dictionary = _slots.get(clean_slot, {}) as Dictionary
	if record.is_empty() or not bool(record.get("filled", false)):
		return {"ok": false, "reason": "slot_not_filled"}
	record["taps"] = int(record.get("taps", 0)) + 1
	record["last_tap_ms"] = Time.get_ticks_msec()
	record["last_tap_unix_ms"] = _unix_time_ms()
	var measurement: Dictionary = _record_measurement_event("tap", record, context)
	record["last_tap_event_id"] = str(measurement.get("event_id", ""))
	_slots[clean_slot] = record
	_emit_ad_event("tap", record)
	var open_result: Dictionary = _open_provider_ad(record, measurement)
	return {"ok": true, "slot": record.duplicate(true), "event": measurement, "open": open_result}

func record_conversion(slot_id: String, attribution: Dictionary = {}) -> Dictionary:
	var clean_slot: String = slot_id.strip_edges()
	var record: Dictionary = _slots.get(clean_slot, {}) as Dictionary
	if record.is_empty():
		var creative: Dictionary = _dict_from_variant(attribution.get("creative", {}))
		record = {
			"slot_id": clean_slot,
			"placement": str(attribution.get("placement", "")).strip_edges(),
			"filled": false,
			"policy": {},
			"creative": creative,
			"updated_at_ms": Time.get_ticks_msec(),
			"impressions": 0,
			"taps": 0,
			"conversions": 0
		}
	record["conversions"] = int(record.get("conversions", 0)) + 1
	record["last_conversion_ms"] = Time.get_ticks_msec()
	record["last_conversion_unix_ms"] = _unix_time_ms()
	var measurement: Dictionary = _record_measurement_event("conversion", record, attribution)
	record["last_conversion_event_id"] = str(measurement.get("event_id", ""))
	if not clean_slot.is_empty():
		_slots[clean_slot] = record
	_emit_ad_event("conversion", record)
	return {"ok": true, "slot": record.duplicate(true), "event": measurement}

func get_slot_state(slot_id: String) -> Dictionary:
	return (_slots.get(slot_id.strip_edges(), {}) as Dictionary).duplicate(true)

func get_all_slots() -> Dictionary:
	return _slots.duplicate(true)

func get_measurement_events() -> Array[Dictionary]:
	return _measurement_events.duplicate(true)

func get_provider_debug_snapshot() -> Dictionary:
	var out: Dictionary = {
		"has_provider": _provider != null,
		"is_dev_test": _provider_is_dev_test,
		"provider_class": _provider.get_class() if _provider != null else ""
	}
	if _provider_is_dev_test and _provider is DevBiodynamicTestProvider:
		var dev_provider: DevBiodynamicTestProvider = _provider as DevBiodynamicTestProvider
		out["image_path"] = dev_provider.image_path
		out["destination_url"] = dev_provider.destination_url
		out["open_url_on_tap"] = dev_provider.open_url_on_tap
		out["opened_urls"] = dev_provider.opened_urls.duplicate()
		out["recorded_event_count"] = dev_provider.recorded_events.size()
	return out

func get_house_ticker_items() -> Array[String]:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("get_house_ticker_items"):
		return ops_config.call("get_house_ticker_items") as Array[String]
	return []

func clear_measurement_events() -> void:
	_measurement_events.clear()
	_event_sequence = 0

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

func _record_measurement_event(event_type: String, record: Dictionary, context: Dictionary = {}) -> Dictionary:
	var event: Dictionary = _build_measurement_event(event_type, record, context)
	_measurement_events.append(event)
	_forward_measurement_event(event)
	return event

func _build_measurement_event(event_type: String, record: Dictionary, context: Dictionary = {}) -> Dictionary:
	_event_sequence += 1
	var creative: Dictionary = _dict_from_variant(record.get("creative", {}))
	var policy: Dictionary = _dict_from_variant(record.get("policy", {}))
	var event: Dictionary = {
		"schema_version": MEASUREMENT_SCHEMA_VERSION,
		"event_id": "%s:%d:%d" % [event_type, _unix_time_ms(), _event_sequence],
		"type": event_type,
		"recorded_unix_ms": _unix_time_ms(),
		"recorded_ticks_ms": Time.get_ticks_msec(),
		"slot_id": str(record.get("slot_id", "")).strip_edges(),
		"placement": str(record.get("placement", "")).strip_edges(),
		"creative_id": str(creative.get("id", "")).strip_edges(),
		"campaign_id": str(creative.get("campaign_id", "")).strip_edges(),
		"provider": str(creative.get("provider", creative.get("network", ""))).strip_edges(),
		"policy": policy.duplicate(true),
		"creative": creative.duplicate(true),
		"context": context.duplicate(true),
		"client_billable_candidate": event_type == "impression" or event_type == "tap",
		"billing_authority": "provider_or_server"
	}
	return event

func _forward_measurement_event(event: Dictionary) -> void:
	if _measurement_sink != null and _measurement_sink.has_method("record_ad_event"):
		_measurement_sink.call("record_ad_event", event.duplicate(true))
	if _provider != null and _provider.has_method("record_ad_event"):
		_provider.call("record_ad_event", event.duplicate(true))

func _open_provider_ad(record: Dictionary, event: Dictionary) -> Dictionary:
	if _provider == null:
		return {"ok": false, "reason": "provider_unavailable"}
	if _provider.has_method("open_ad"):
		return _provider.call("open_ad", record.duplicate(true), event.duplicate(true)) as Dictionary
	if _provider.has_method("record_tap"):
		return _provider.call("record_tap", record.duplicate(true), event.duplicate(true)) as Dictionary
	return {"ok": false, "reason": "open_not_supported"}

func _dict_from_variant(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}

func _is_approved_placement(value: String) -> bool:
	var clean: String = value.strip_edges()
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("ad_placement_enabled"):
		return bool(ops_config.call("ad_placement_enabled", clean))
	return clean == PLACEMENT_HANDSHAKE or clean == PLACEMENT_IN_GAME or clean == PLACEMENT_POST_MATCH

func _auto_dismiss_sec_for_placement(value: String) -> float:
	if value == PLACEMENT_HANDSHAKE:
		return 8.0
	if value == PLACEMENT_POST_MATCH:
		return 9.0
	return 0.0

func _content_mode_for_policy(placement_allowed: bool, zero_ads: bool, external_ads_allowed: bool = true, house_ads_allowed: bool = false) -> String:
	if not placement_allowed:
		return CONTENT_MODE_HIDDEN
	if external_ads_allowed:
		return CONTENT_MODE_AD
	if house_ads_allowed or zero_ads:
		return CONTENT_MODE_INTERNAL_TICKER
	return CONTENT_MODE_HIDDEN

func _external_ads_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("external_ads_enabled"):
		return bool(ops_config.call("external_ads_enabled"))
	return false

func _house_ads_enabled() -> bool:
	var ops_config: Node = get_node_or_null("/root/OpsConfig")
	if ops_config != null and ops_config.has_method("house_ads_enabled"):
		return bool(ops_config.call("house_ads_enabled"))
	return true

func _fake_ads_enabled() -> bool:
	var env_value: String = OS.get_environment(FAKE_ADS_ENV).strip_edges().to_lower()
	if ["1", "true", "yes", "on"].has(env_value):
		return true
	if ProjectSettings.has_setting(SETTINGS_FAKE_ADS):
		return bool(ProjectSettings.get_setting(SETTINGS_FAKE_ADS))
	return false

func _install_dev_biodynamic_provider_if_enabled() -> void:
	if not _dev_biodynamic_ads_enabled():
		return
	var image_path: String = str(ProjectSettings.get_setting(SETTINGS_DEV_BIODYNAMIC_IMAGE_PATH, DEV_BIODYNAMIC_DEFAULT_IMAGE_PATH)).strip_edges()
	var destination_url: String = str(ProjectSettings.get_setting(SETTINGS_DEV_BIODYNAMIC_DESTINATION_URL, DEV_BIODYNAMIC_DEFAULT_DESTINATION_URL)).strip_edges()
	var open_url_on_tap: bool = bool(ProjectSettings.get_setting(SETTINGS_DEV_BIODYNAMIC_OPEN_URL_ON_TAP, true))
	_provider = DevBiodynamicTestProvider.new(image_path, destination_url, open_url_on_tap)
	_provider_is_dev_test = true

func _dev_biodynamic_ads_enabled() -> bool:
	var env_value: String = OS.get_environment(DEV_BIODYNAMIC_ADS_ENV).strip_edges().to_lower()
	if ["1", "true", "yes", "on"].has(env_value):
		return true
	if ["0", "false", "no", "off"].has(env_value):
		return false
	if ProjectSettings.has_setting(SETTINGS_DEV_BIODYNAMIC_ADS):
		return bool(ProjectSettings.get_setting(SETTINGS_DEV_BIODYNAMIC_ADS))
	return false

func _has_zero_ads_entitlement() -> bool:
	var battle_pass_state: Node = get_node_or_null("/root/BattlePassState")
	if battle_pass_state != null and battle_pass_state.has_method("has_active_ad_free_reward"):
		if bool(battle_pass_state.call("has_active_ad_free_reward")):
			return true
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

func _unix_time_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
