class_name BuffActivationSystem
extends Node

const BuffDefinitions = preload("res://scripts/state/buff_definitions.gd")
const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

signal buff_state_changed(snapshot: Dictionary)
signal activation_result(result: Dictionary)
signal target_highlight_requested(payload: Dictionary)
signal supercharge_release_requested(payload: Dictionary)

@export var ops_state_path: NodePath = NodePath("/root/OpsState")

var _buff_state: BuffState = BuffState.new()
var _ops_state: Node = null

func _ready() -> void:
	_ops_state = get_node_or_null(ops_state_path)
	if not _buff_state.buff_state_changed.is_connected(_on_state_changed):
		_buff_state.buff_state_changed.connect(_on_state_changed)
	if not _buff_state.supercharge_release_requested.is_connected(_on_supercharge_release):
		_buff_state.supercharge_release_requested.connect(_on_supercharge_release)
	buff_state_changed.emit(_buff_state.get_runtime_snapshot())

func bind_buff_state(state: BuffState) -> void:
	if state == null:
		return
	if _buff_state != null and _buff_state.buff_state_changed.is_connected(_on_state_changed):
		_buff_state.buff_state_changed.disconnect(_on_state_changed)
	if _buff_state != null and _buff_state.supercharge_release_requested.is_connected(_on_supercharge_release):
		_buff_state.supercharge_release_requested.disconnect(_on_supercharge_release)
	_buff_state = state
	_buff_state.buff_state_changed.connect(_on_state_changed)
	_buff_state.supercharge_release_requested.connect(_on_supercharge_release)
	buff_state_changed.emit(_buff_state.get_runtime_snapshot())

func get_snapshot() -> Dictionary:
	return _buff_state.get_runtime_snapshot()

func authoritative_tick(now_ms: int) -> void:
	_buff_state.update(now_ms)

func intent_activate_buff(
	owner_id: int,
	buff_id: String,
	tier: String,
	target: Dictionary,
	now_ms: int
) -> Dictionary:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		var missing_id: Dictionary = {"ok": false, "code": "missing_buff_id", "message": "Buff id is required."}
		activation_result.emit(missing_id)
		return missing_id
	var canonical_id: String = _canonical_buff_id(clean_id)
	if canonical_id == "":
		var unknown_missing: Dictionary = {"ok": false, "code": "unknown_buff", "message": "Unknown buff id."}
		activation_result.emit(unknown_missing)
		return unknown_missing
	var buff_def: Dictionary = BuffDefinitions.get_definition(canonical_id)
	if buff_def.is_empty():
		var unknown: Dictionary = {"ok": false, "code": "unknown_buff", "message": "Unknown buff id."}
		activation_result.emit(unknown)
		return unknown
	var target_type: String = BuffDefinitions.target_type_for(canonical_id)
	if BuffDefinitions.requires_target(canonical_id):
		if target.is_empty():
			var hint_missing: Dictionary = {
				"target_type": target_type,
				"buff_id": canonical_id,
				"owner_id": owner_id,
				"reason": "target_required"
			}
			target_highlight_requested.emit(hint_missing)
			var missing_target: Dictionary = {
				"ok": false,
				"code": "target_required",
				"message": "Target required.",
				"target_type": target_type
			}
			activation_result.emit(missing_target)
			return missing_target
		var validate_target: Dictionary = _validate_target_for_owner(owner_id, target_type, target)
		if not bool(validate_target.get("ok", false)):
			var invalid_hint: Dictionary = {
				"target_type": target_type,
				"buff_id": canonical_id,
				"owner_id": owner_id,
				"reason": str(validate_target.get("code", "invalid_target"))
			}
			target_highlight_requested.emit(invalid_hint)
			activation_result.emit(validate_target)
			return validate_target
	var result: Dictionary = _buff_state.intent_activate_buff(owner_id, canonical_id, tier, target, now_ms)
	if not bool(result.get("ok", false)) and str(result.get("code", "")) == "target_required":
		var hint: Dictionary = {
			"target_type": target_type,
			"buff_id": canonical_id,
			"owner_id": owner_id,
			"reason": "target_required"
		}
		target_highlight_requested.emit(hint)
	activation_result.emit(result)
	return result

func request_supercharge_release(owner_id: int, hive_id: int, now_ms: int) -> Dictionary:
	var result: Dictionary = _buff_state.intent_release_supercharge(owner_id, hive_id, now_ms)
	activation_result.emit(result)
	return result

func swarm_combat_damage_multiplier(owner_id: int) -> float:
	var active_any: Variant = _buff_state.get_active_unit_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return 1.0
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return 1.0
	if str(active.get("id", "")) != BuffDefinitions.UNIT_SWARM_DAMAGE:
		return 1.0
	var effects: Dictionary = active.get("effects", {}) as Dictionary
	return float(effects.get("swarm_combat_damage_mult", 1.0))

func hive_impact_damage_multiplier(owner_id: int) -> int:
	var active_any: Variant = _buff_state.get_active_unit_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return 1
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return 1
	if str(active.get("id", "")) != BuffDefinitions.UNIT_HIVE_IMPACT_DAMAGE:
		return 1
	var effects: Dictionary = active.get("effects", {}) as Dictionary
	return int(effects.get("hive_impact_damage_mult", 1))

func unit_speed_multiplier_for_spawn_hive(owner_id: int, spawn_hive_id: int) -> float:
	var active_any: Variant = _buff_state.get_active_unit_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return 1.0
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return 1.0
	if str(active.get("id", "")) != BuffDefinitions.UNIT_SPEED:
		return 1.0
	var target: Dictionary = active.get("target", {}) as Dictionary
	if int(target.get("hive_id", -1)) != spawn_hive_id:
		return 1.0
	var effects: Dictionary = active.get("effects", {}) as Dictionary
	return float(effects.get("unit_speed_mult", 1.0))

func hive_production_time_multiplier(owner_id: int, hive_id: int) -> float:
	var active_any: Variant = _buff_state.get_active_hive_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return 1.0
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return 1.0
	var buff_id: String = str(active.get("id", ""))
	if buff_id == BuffDefinitions.HIVE_GLOBAL_PRODUCTION_BOOST:
		return 0.7
	if buff_id == BuffDefinitions.HIVE_SINGLE_PRODUCTION_BOOST:
		var target: Dictionary = active.get("target", {}) as Dictionary
		if int(target.get("hive_id", -1)) == hive_id:
			return 0.7
	return 1.0

func hive_is_landing_damage_immune(owner_id: int, hive_id: int) -> bool:
	var active_any: Variant = _buff_state.get_active_hive_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return false
	var buff_id: String = str(active.get("id", ""))
	if buff_id == BuffDefinitions.HIVE_SHIELD_GLOBAL:
		return true
	if buff_id == BuffDefinitions.HIVE_SHIELD_SINGLE:
		var target: Dictionary = active.get("target", {}) as Dictionary
		return int(target.get("hive_id", -1)) == hive_id
	return false

func hive_is_shock_immune(owner_id: int, hive_id: int) -> bool:
	var active_any: Variant = _buff_state.get_active_hive_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return false
	if str(active.get("id", "")) != BuffDefinitions.HIVE_SHOCK_IMMUNITY:
		return false
	var target: Dictionary = active.get("target", {}) as Dictionary
	return int(target.get("hive_id", -1)) == hive_id

func hive_is_supercharge_queue_active(owner_id: int, hive_id: int) -> bool:
	var active_any: Variant = _buff_state.get_active_hive_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = active_any as Dictionary
	if int(active.get("owner_id", -1)) != owner_id:
		return false
	if str(active.get("id", "")) != BuffDefinitions.HIVE_SUPERCHARGE_QUEUE:
		return false
	var target: Dictionary = active.get("target", {}) as Dictionary
	return int(target.get("hive_id", -1)) == hive_id

func lane_freeze_blocks_enemy(lane_id: int, unit_owner_id: int) -> bool:
	var active: Dictionary = _active_enemy_lane_buff_for_unit(lane_id, unit_owner_id)
	if active.is_empty():
		return false
	return str(active.get("id", "")) == BuffDefinitions.LANE_FREEZE

func lane_should_convert_enemy_entering(lane_id: int, unit_owner_id: int, rng_value_0_to_1: float) -> bool:
	var active: Dictionary = _active_enemy_lane_buff_for_unit(lane_id, unit_owner_id)
	if active.is_empty():
		return false
	if str(active.get("id", "")) != BuffDefinitions.LANE_STEAL:
		return false
	return rng_value_0_to_1 < 0.5

func lane_should_reverse_enemy(lane_id: int, unit_owner_id: int) -> bool:
	var active: Dictionary = _active_enemy_lane_buff_for_unit(lane_id, unit_owner_id)
	if active.is_empty():
		return false
	return str(active.get("id", "")) == BuffDefinitions.LANE_TREACHEROUS

func _active_enemy_lane_buff_for_unit(lane_id: int, unit_owner_id: int) -> Dictionary:
	var active_any: Variant = _buff_state.get_active_lane_buff()
	if typeof(active_any) != TYPE_DICTIONARY:
		return {}
	var active: Dictionary = active_any as Dictionary
	var target: Dictionary = active.get("target", {}) as Dictionary
	if int(target.get("lane_id", -1)) != lane_id:
		return {}
	var buff_owner_id: int = int(active.get("owner_id", -1))
	if buff_owner_id <= 0 or buff_owner_id == unit_owner_id:
		return {}
	return active

func _validate_target_for_owner(owner_id: int, target_type: String, target: Dictionary) -> Dictionary:
	match target_type:
		BuffDefinitions.TARGET_HIVE:
			var hive_id: int = int(target.get("hive_id", -1))
			if hive_id <= 0:
				return {"ok": false, "code": "missing_hive_target", "message": "Hive target required."}
			var hive_owner: int = _hive_owner_id(hive_id)
			if hive_owner <= 0:
				return {"ok": false, "code": "hive_not_found", "message": "Hive target not found."}
			if hive_owner != owner_id:
				return {"ok": false, "code": "hive_not_owned", "message": "Target hive must be owned by activator."}
			return {"ok": true}
		BuffDefinitions.TARGET_LANE:
			var lane_id: int = int(target.get("lane_id", -1))
			if lane_id <= 0:
				return {"ok": false, "code": "missing_lane_target", "message": "Lane target required."}
			if not _lane_exists(lane_id):
				return {"ok": false, "code": "lane_not_found", "message": "Lane target not found."}
			return {"ok": true}
		_:
			return {"ok": true}

func _hive_owner_id(hive_id: int) -> int:
	var game_state: Object = _ops_game_state()
	if game_state == null:
		return -1
	var hives_any: Variant = game_state.get("hives")
	if typeof(hives_any) != TYPE_ARRAY:
		return -1
	for hive_any in hives_any as Array:
		if hive_any == null:
			continue
		if hive_any is RefCounted:
			var hive_obj: RefCounted = hive_any as RefCounted
			if int(hive_obj.get("id")) == hive_id:
				return int(hive_obj.get("owner_id"))
		elif typeof(hive_any) == TYPE_DICTIONARY:
			var hive_dict: Dictionary = hive_any as Dictionary
			if int(hive_dict.get("id", -1)) == hive_id:
				return int(hive_dict.get("owner_id", -1))
	return -1

func _lane_exists(lane_id: int) -> bool:
	var game_state: Object = _ops_game_state()
	if game_state == null:
		return false
	var lanes_any: Variant = game_state.get("lanes")
	if typeof(lanes_any) != TYPE_ARRAY:
		return false
	for lane_any in lanes_any as Array:
		if lane_any == null:
			continue
		if lane_any is RefCounted:
			var lane_obj: RefCounted = lane_any as RefCounted
			if int(lane_obj.get("id")) == lane_id:
				return true
		elif typeof(lane_any) == TYPE_DICTIONARY:
			var lane_dict: Dictionary = lane_any as Dictionary
			if int(lane_dict.get("id", -1)) == lane_id:
				return true
	return false

func _ops_game_state() -> Object:
	if _ops_state == null:
		_ops_state = get_node_or_null(ops_state_path)
	if _ops_state == null:
		return null
	if _ops_state.has_method("get_state"):
		var state_any: Variant = _ops_state.call("get_state")
		if state_any is Object:
			return state_any as Object
	var direct_state: Variant = _ops_state.get("state")
	if direct_state is Object:
		return direct_state as Object
	return null

func _canonical_buff_id(buff_id: String) -> String:
	var clean_id: String = buff_id.strip_edges()
	if clean_id == "":
		return ""
	var upper_id: String = clean_id.to_upper()
	if BuffDefinitions.has_definition(upper_id):
		return upper_id
	if BuffDefinitions.has_definition(clean_id):
		return clean_id
	var catalog_buff: Dictionary = BuffCatalog.get_buff(clean_id)
	if catalog_buff.is_empty():
		return ""
	var canonical_id: String = str(catalog_buff.get("canonical_id", "")).strip_edges().to_upper()
	if canonical_id != "" and BuffDefinitions.has_definition(canonical_id):
		return canonical_id
	return ""

func _on_state_changed(snapshot: Dictionary) -> void:
	buff_state_changed.emit(snapshot)

func _on_supercharge_release(payload: Dictionary) -> void:
	supercharge_release_requested.emit(payload)
