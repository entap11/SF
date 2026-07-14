class_name BuffTargetResolver
extends RefCounted

const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")
const BuffDefinitions = preload("res://scripts/state/buff_definitions.gd")

const TARGET_GLOBAL: String = "global"

func performance_snapshot() -> Dictionary:
	return {
		"per_frame_processing": false,
		"retained_target_sets": 0,
		"eligibility_scans_are_request_scoped": true
	}

func get_preview_eligible_targets(game_state: Object, owner_id: int, buff_id: String) -> Dictionary:
	var identity: Dictionary = _buff_identity(buff_id)
	if not bool(identity.get("ok", false)):
		return identity
	if game_state == null:
		return _reject("missing_game_state", identity)
	if owner_id <= 0:
		return _reject("invalid_owner", identity)
	var target_type: String = str(identity.get("target_type", BuffDefinitions.TARGET_NONE))
	var eligible_ids: Array = []
	match target_type:
		BuffDefinitions.TARGET_HIVE:
			for hive_any in _state_array(game_state, "hives"):
				var hive_id: int = _entry_int(hive_any, "id", -1)
				if hive_id <= 0 or _entry_int(hive_any, "owner_id", -1) != owner_id:
					continue
				eligible_ids.append(hive_id)
		BuffDefinitions.TARGET_LANE:
			var hive_ids: Dictionary = {}
			for hive_any in _state_array(game_state, "hives"):
				var hive_id: int = _entry_int(hive_any, "id", -1)
				if hive_id > 0:
					hive_ids[hive_id] = true
			for lane_any in _state_array(game_state, "lanes"):
				var lane_id: int = _entry_int(lane_any, "id", _entry_int(lane_any, "lane_id", -1))
				var a_id: int = _entry_int(lane_any, "a_id", _entry_int(lane_any, "from", -1))
				var b_id: int = _entry_int(lane_any, "b_id", _entry_int(lane_any, "to", -1))
				if lane_id <= 0 or a_id <= 0 or b_id <= 0:
					continue
				if not hive_ids.has(a_id) or not hive_ids.has(b_id):
					continue
				if not _lane_is_active(lane_any):
					continue
				eligible_ids.append(lane_id)
		_:
			target_type = TARGET_GLOBAL
			eligible_ids.append(TARGET_GLOBAL)
	eligible_ids.sort()
	return {
		"ok": true,
		"status": "eligible",
		"reason": "",
		"owner_id": owner_id,
		"buff_id": str(identity.get("buff_id", buff_id)),
		"canonical_buff_id": str(identity.get("canonical_buff_id", "")),
		"tier": str(identity.get("tier", BuffDefinitions.TIER_CLASSIC)),
		"target_type": target_type,
		"eligible_target_ids": eligible_ids,
		"state_tick": _state_int(game_state, "tick", -1)
	}

func validate_canonical_target(
	game_state: Object,
	owner_id: int,
	buff_id: String,
	proposed_target_type: String,
	proposed_target_id: Variant
) -> Dictionary:
	var eligible: Dictionary = get_preview_eligible_targets(game_state, owner_id, buff_id)
	if not bool(eligible.get("ok", false)):
		return eligible
	var expected_type: String = str(eligible.get("target_type", TARGET_GLOBAL))
	var clean_type: String = proposed_target_type.strip_edges().to_lower()
	if clean_type == BuffDefinitions.TARGET_NONE:
		clean_type = TARGET_GLOBAL
	if clean_type != expected_type:
		return _reject("target_type_mismatch", eligible, {
			"expected_target_type": expected_type,
			"proposed_target_type": clean_type
		})
	var normalized_target_id: Variant = _normalized_target_id(clean_type, proposed_target_id)
	if normalized_target_id == null:
		return _reject("missing_target", eligible)
	var eligible_ids: Array = eligible.get("eligible_target_ids", []) as Array
	if not eligible_ids.has(normalized_target_id):
		return _reject("target_ineligible", eligible, {"target_id": normalized_target_id})
	var result: Dictionary = eligible.duplicate(true)
	result["ok"] = true
	result["status"] = "valid"
	result["reason"] = "activated"
	result["target_id"] = normalized_target_id
	return result

func canonical_target_payload(target_type: String, target_id: Variant) -> Dictionary:
	var clean_type: String = target_type.strip_edges().to_lower()
	match clean_type:
		BuffDefinitions.TARGET_HIVE:
			return {"kind": "hive", "hive_id": int(target_id)}
		BuffDefinitions.TARGET_LANE:
			return {"kind": "lane", "lane_id": int(target_id)}
		_:
			return {"kind": TARGET_GLOBAL, "target_id": TARGET_GLOBAL}

func _buff_identity(buff_id: String) -> Dictionary:
	var clean_id: String = buff_id.strip_edges()
	var catalog_entry: Dictionary = BuffCatalog.get_buff(clean_id)
	if clean_id == "" or catalog_entry.is_empty():
		return {"ok": false, "status": "rejected", "reason": "unknown_buff", "buff_id": clean_id}
	var canonical_id: String = str(catalog_entry.get("canonical_id", clean_id)).strip_edges().to_upper()
	if not BuffDefinitions.has_definition(canonical_id):
		return {"ok": false, "status": "rejected", "reason": "unknown_buff", "buff_id": clean_id}
	var raw_target_type: String = BuffDefinitions.target_type_for(canonical_id)
	return {
		"ok": true,
		"buff_id": clean_id,
		"canonical_buff_id": canonical_id,
		"tier": str(catalog_entry.get("tier", BuffDefinitions.TIER_CLASSIC)),
		"target_type": TARGET_GLOBAL if raw_target_type == BuffDefinitions.TARGET_NONE else raw_target_type
	}

func _normalized_target_id(target_type: String, target_id: Variant) -> Variant:
	if target_type == TARGET_GLOBAL:
		return TARGET_GLOBAL if str(target_id).strip_edges().to_lower() == TARGET_GLOBAL else null
	var numeric_id: int = int(target_id)
	return numeric_id if numeric_id > 0 else null

func _state_array(game_state: Object, property_name: String) -> Array:
	var value: Variant = game_state.get(property_name)
	return value as Array if typeof(value) == TYPE_ARRAY else []

func _state_int(game_state: Object, property_name: String, fallback: int) -> int:
	var value: Variant = game_state.get(property_name)
	return fallback if value == null else int(value)

func _entry_int(entry: Variant, property_name: String, fallback: int) -> int:
	if typeof(entry) == TYPE_DICTIONARY:
		return int((entry as Dictionary).get(property_name, fallback))
	if entry is Object:
		var value: Variant = (entry as Object).get(property_name)
		return fallback if value == null else int(value)
	return fallback

func _lane_is_active(entry: Variant) -> bool:
	if typeof(entry) == TYPE_DICTIONARY:
		var lane: Dictionary = entry as Dictionary
		if lane.has("active"):
			return bool(lane.get("active", false))
		if lane.has("send_a") or lane.has("send_b") or lane.has("establish_a") or lane.has("establish_b"):
			return bool(lane.get("send_a", false)) or bool(lane.get("send_b", false)) or bool(lane.get("establish_a", false)) or bool(lane.get("establish_b", false))
		return true
	if entry is Object:
		var property_names: Dictionary = {}
		for property_any in (entry as Object).get_property_list():
			if typeof(property_any) == TYPE_DICTIONARY:
				property_names[str((property_any as Dictionary).get("name", ""))] = true
		if property_names.has("active"):
			return bool((entry as Object).get("active"))
		if property_names.has("send_a") or property_names.has("send_b") or property_names.has("establish_a") or property_names.has("establish_b"):
			return (
				(property_names.has("send_a") and bool((entry as Object).get("send_a")))
				or (property_names.has("send_b") and bool((entry as Object).get("send_b")))
				or (property_names.has("establish_a") and bool((entry as Object).get("establish_a")))
				or (property_names.has("establish_b") and bool((entry as Object).get("establish_b")))
			)
	return true

func _reject(reason: String, base: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	out["ok"] = false
	out["status"] = "rejected"
	out["reason"] = reason
	for key_any in extra.keys():
		out[key_any] = extra.get(key_any)
	return out
