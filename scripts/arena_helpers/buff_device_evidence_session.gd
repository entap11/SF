class_name ArenaBuffDeviceEvidenceSession
extends RefCounted

const RuntimeGate := preload("res://scripts/shell_helpers/buff_targeting_runtime_gate.gd")
const BuffCatalogScript := preload("res://scripts/state/buff_catalog.gd")

const LOADOUT_IDS: Array[String] = [
	"buff_unit_speed_classic",
	"buff_freeze_lane_classic",
	"buff_global_production_boost_classic"
]
const REPEAT_USES: int = 64
const ASYNC_USES: int = 2

var _enabled: bool = false
var _role: String = "unspecified"
var _initial_uses: int = 0
var _remaining_by_id: Dictionary = {}


func configure(is_debug_build: bool, user_args: PackedStringArray) -> void:
	_enabled = RuntimeGate.enabled_for_runtime(false, is_debug_build, user_args)
	_role = RuntimeGate.device_role(user_args)
	_initial_uses = 0
	_remaining_by_id.clear()
	if not _enabled:
		return
	_initial_uses = ASYNC_USES if _role.begins_with("async_") else REPEAT_USES
	reset_for_match()


func reset_for_match() -> void:
	if not _enabled:
		return
	for buff_id: String in LOADOUT_IDS:
		_remaining_by_id[buff_id] = _initial_uses


func is_enabled() -> bool:
	return _enabled


func role() -> String:
	return _role


func initial_uses() -> int:
	return _initial_uses


func loadout_entries() -> Array:
	var entries: Array = []
	if not _enabled:
		return entries
	for buff_id: String in LOADOUT_IDS:
		var buff: Dictionary = BuffCatalogScript.get_buff(buff_id)
		if buff.is_empty():
			continue
		entries.append({
			"id": buff_id,
			"tier": str(buff.get("tier", "classic")),
			"uses": _initial_uses,
			"uses_total": _initial_uses
		})
	return entries


func has_buff(buff_id: String) -> bool:
	return _enabled and _remaining_by_id.has(buff_id)


func quantity(buff_id: String) -> int:
	return maxi(0, int(_remaining_by_id.get(buff_id, 0))) if has_buff(buff_id) else 0


func source_descriptor(buff_id: String) -> Dictionary:
	if not has_buff(buff_id):
		return {}
	var remaining: int = quantity(buff_id)
	if remaining <= 0:
		return {"ok": false, "status": "rejected", "reason": "device_evidence_uses_exhausted"}
	var async_role: bool = _role.begins_with("async_")
	var ordinal: int = 1
	if async_role:
		ordinal = 1 if remaining == ASYNC_USES else 2
	return {
		"ok": true,
		"status": "available",
		"reason": "",
		"source_kind": "async" if async_role else "vs",
		"source_use_ordinal": ordinal,
		"charge_key": "device_evidence:%s:%s:%d" % [_role, buff_id, remaining],
		"capacity": remaining
	}


func can_commit(buff_id: String, source_kind: String, ordinal: int) -> bool:
	var source: Dictionary = source_descriptor(buff_id)
	return bool(source.get("ok", false)) \
		and source_kind == str(source.get("source_kind", "")) \
		and ordinal == int(source.get("source_use_ordinal", 0))


func commit(buff_id: String) -> Dictionary:
	if not has_buff(buff_id):
		return {"ok": false, "reason": "device_evidence_buff_missing", "buff_id": buff_id}
	var remaining: int = quantity(buff_id)
	if remaining <= 0:
		return {"ok": false, "reason": "device_evidence_uses_exhausted", "buff_id": buff_id}
	remaining -= 1
	_remaining_by_id[buff_id] = remaining
	return {
		"ok": true,
		"buff_id": buff_id,
		"remaining": remaining,
		"uses_total": _initial_uses,
		"persistent_inventory_mutated": false
	}


func revision() -> String:
	if not _enabled:
		return ""
	var ids: Array[String] = []
	for buff_id_any: Variant in _remaining_by_id.keys():
		ids.append(str(buff_id_any))
	ids.sort()
	var parts: PackedStringArray = PackedStringArray(["device_evidence", _role])
	for buff_id: String in ids:
		parts.append("%s=%d" % [buff_id, quantity(buff_id)])
	return "|".join(parts).sha256_text()


func snapshot() -> Dictionary:
	return {
		"enabled": _enabled,
		"role": _role,
		"loadout_ids": LOADOUT_IDS.duplicate() if _enabled else [],
		"uses_per_slot": _initial_uses,
		"remaining_by_id": _remaining_by_id.duplicate(true),
		"persistent_inventory_mutated": false
	}
