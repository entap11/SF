# WE MAINTAIN ONE AUTHORITATIVE GAME STATE (OpsState/SimState).
# UI / render / input MUST NOT mutate state directly.
# Only simulation/state systems may mutate state, and ONLY via OpsState-owned references.
class_name StructureControlSystem
extends Node

const SFLog := preload("res://scripts/util/sf_log.gd")

signal structure_owner_changed(structure_type: String, structure_id: int, prev_owner: int, next_owner: int, control_ids: Array)

var state: GameState = null
var _last_tower_count: int = -1
var _last_barracks_count: int = -1
var _warned_empty_controls: Dictionary = {}

func bind_state(state_ref: GameState) -> void:
	state = state_ref
	_warned_empty_controls.clear()
	_last_tower_count = -1
	_last_barracks_count = -1
	_refresh_structure_index()

func tick(_dt: float) -> void:
	if state == null:
		return
	if OpsState.has_outcome():
		return
	_refresh_structure_index()
	_eval_structures(state.towers, "tower")
	_eval_structures(state.barracks, "barracks")

static func control_ids_for(structure: Dictionary) -> Array:
	var control_ids: Array = []
	var control_v: Variant = structure.get("control_hive_ids", structure.get("required_hive_ids", []))
	if typeof(control_v) == TYPE_ARRAY:
		for hive_id_v in control_v as Array:
			var hive_id: int = int(hive_id_v)
			if hive_id > 0:
				control_ids.append(hive_id)
	if control_ids.is_empty():
		var req_v: Variant = structure.get("required_hive_ids", [])
		if typeof(req_v) == TYPE_ARRAY:
			for hive_id_v in req_v as Array:
				var hive_id: int = int(hive_id_v)
				if hive_id > 0:
					control_ids.append(hive_id)
	return control_ids

func _eval_structures(list: Array, structure_type: String) -> void:
	for struct_any in list:
		if typeof(struct_any) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = struct_any as Dictionary
		var struct_id: int = int(sd.get("id", -1))
		var control_ids: Array = control_ids_for(sd)
		var prev_owner: int = int(sd.get("owner_id", 0))
		var prev_controlled: bool = bool(sd.get("is_controlled", false))
		var next_owner: int = 0
		var next_controlled: bool = false
		if control_ids.is_empty():
			_warn_empty_control_ids(structure_type, struct_id)
			next_owner = 0
			next_controlled = false
		else:
			var control_resolution: Dictionary = _compute_control_resolution(control_ids)
			next_owner = int(control_resolution.get("owner_id", 0))
			next_controlled = bool(control_resolution.get("controlled", false))
		sd["is_controlled"] = next_controlled
		if next_owner != prev_owner or next_controlled != prev_controlled:
			sd["owner_id"] = next_owner
			_update_structure_owner_index(sd, structure_type, next_owner)
			SFLog.info("STRUCTURE_OWNER_CHANGED", {
				"type": structure_type,
				"id": struct_id,
				"prev_owner": prev_owner,
				"next_owner": next_owner,
				"prev_controlled": prev_controlled,
				"next_controlled": next_controlled,
				"control_ids": control_ids
			})
			emit_signal("structure_owner_changed", structure_type, struct_id, prev_owner, next_owner, control_ids)
		else:
			_update_structure_owner_index(sd, structure_type, prev_owner)

func _compute_control_resolution(control_ids: Array) -> Dictionary:
	var owner_id: int = 0
	var initialized: bool = false
	for hive_id_v in control_ids:
		var hive_id: int = int(hive_id_v)
		var hive: HiveData = state.find_hive_by_id(hive_id)
		if hive == null:
			return {"owner_id": 0, "controlled": false}
		if not initialized:
			owner_id = hive.owner_id
			initialized = true
		elif hive.owner_id != owner_id:
			return {"owner_id": 0, "controlled": false}
	if not initialized:
		return {"owner_id": 0, "controlled": false}
	return {"owner_id": owner_id, "controlled": true}

func _warn_empty_control_ids(structure_type: String, struct_id: int) -> void:
	if struct_id <= 0:
		return
	var key := "%s:%d" % [structure_type, struct_id]
	if _warned_empty_controls.has(key):
		return
	_warned_empty_controls[key] = true
	SFLog.info("STRUCTURE_CONTROL_EMPTY", {
		"type": structure_type,
		"id": struct_id
	})

func _refresh_structure_index() -> void:
	if state == null:
		return
	var tower_count: int = state.towers.size() if state.towers != null else 0
	var barracks_count: int = state.barracks.size() if state.barracks != null else 0
	if tower_count == _last_tower_count and barracks_count == _last_barracks_count and not state.structure_by_node_id.is_empty():
		return
	_last_tower_count = tower_count
	_last_barracks_count = barracks_count
	state.structure_by_node_id.clear()
	state.structure_owner_by_node_id.clear()
	if state.tower_owner_by_node_id != null:
		state.tower_owner_by_node_id.clear()
	for tower_any in state.towers:
		if typeof(tower_any) != TYPE_DICTIONARY:
			continue
		var td: Dictionary = tower_any as Dictionary
		_update_structure_owner_index(td, "tower", int(td.get("owner_id", 0)))
	for barracks_any in state.barracks:
		if typeof(barracks_any) != TYPE_DICTIONARY:
			continue
		var bd: Dictionary = barracks_any as Dictionary
		_update_structure_owner_index(bd, "barracks", int(bd.get("owner_id", 0)))

func _update_structure_owner_index(structure: Dictionary, structure_type: String, owner_id: int) -> void:
	if state == null:
		return
	var node_id: int = int(structure.get("node_id", structure.get("id", -1)))
	if node_id <= 0:
		return
	state.structure_by_node_id[node_id] = structure_type
	state.structure_owner_by_node_id[node_id] = owner_id
	if state.tower_owner_by_node_id != null:
		state.tower_owner_by_node_id[node_id] = owner_id
