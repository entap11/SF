class_name BuffPointerSession
extends RefCounted

const POINTER_TOUCH: String = "touch"
const POINTER_MOUSE: String = "mouse"
const MOUSE_POINTER_ID: int = 0

const STATE_IDLE: String = "idle"
const STATE_CAPTURED: String = "captured"
const STATE_DRAGGING: String = "dragging"

var _next_session_id: int = 0
var _active: Dictionary = {}


func begin(
	pointer_kind: String,
	pointer_id: int,
	slot_index: int,
	buff_id: String,
	root_screen_pos: Vector2,
	source_snapshot: Dictionary,
	inventory_revision: String
) -> Dictionary:
	_next_session_id += 1
	_active = {
		"pointer_session_id": _next_session_id,
		"pointer_kind": pointer_kind,
		"pointer_id": pointer_id,
		"slot_index": slot_index,
		"buff_id": buff_id,
		"state": STATE_CAPTURED,
		"start_root_screen_pos": root_screen_pos,
		"current_root_screen_pos": root_screen_pos,
		"source_snapshot": source_snapshot.duplicate(true),
		"inventory_revision": inventory_revision,
		"preview": {},
		"submitted": false
	}
	return snapshot()


func is_active() -> bool:
	return not _active.is_empty()


func matches(pointer_kind: String, pointer_id: int, pointer_session_id: int = -1) -> bool:
	if _active.is_empty():
		return false
	if str(_active.get("pointer_kind", "")) != pointer_kind or int(_active.get("pointer_id", -1)) != pointer_id:
		return false
	return pointer_session_id < 0 or int(_active.get("pointer_session_id", 0)) == pointer_session_id


func move(pointer_kind: String, pointer_id: int, pointer_session_id: int, root_screen_pos: Vector2, touch_slop_px: float) -> Dictionary:
	if not matches(pointer_kind, pointer_id, pointer_session_id):
		return {"ok": false, "reason": "pointer_session_mismatch"}
	_active["current_root_screen_pos"] = root_screen_pos
	var drag_started: bool = false
	if str(_active.get("state", STATE_IDLE)) == STATE_CAPTURED:
		var start_pos: Vector2 = _active.get("start_root_screen_pos", root_screen_pos) as Vector2
		if root_screen_pos.distance_to(start_pos) >= maxf(0.0, touch_slop_px):
			_active["state"] = STATE_DRAGGING
			drag_started = true
	return {
		"ok": true,
		"drag_started": drag_started,
		"state": str(_active.get("state", STATE_IDLE)),
		"pointer_session_id": int(_active.get("pointer_session_id", 0)),
		"slot_index": int(_active.get("slot_index", -1))
	}


func set_preview(pointer_session_id: int, preview: Dictionary) -> bool:
	if _active.is_empty() or int(_active.get("pointer_session_id", 0)) != pointer_session_id:
		return false
	var stored_preview: Dictionary = preview.duplicate(true)
	stored_preview["selected_target_type"] = ""
	stored_preview["selected_target_id"] = null
	_active["preview"] = stored_preview
	return true


func set_selected_target(pointer_session_id: int, target_type: String, target_id: Variant) -> bool:
	if _active.is_empty() or int(_active.get("pointer_session_id", 0)) != pointer_session_id:
		return false
	var preview: Dictionary = _active.get("preview", {}) as Dictionary
	if not bool(preview.get("ok", false)):
		return false
	var clean_target_type: String = target_type.strip_edges()
	if clean_target_type.is_empty() or target_id == null:
		preview["selected_target_type"] = ""
		preview["selected_target_id"] = null
	else:
		preview["selected_target_type"] = clean_target_type
		preview["selected_target_id"] = target_id
	_active["preview"] = preview
	return true


func clear_selected_target(pointer_session_id: int) -> bool:
	return set_selected_target(pointer_session_id, "", null)


func mark_submitted(pointer_session_id: int) -> bool:
	if _active.is_empty() or int(_active.get("pointer_session_id", 0)) != pointer_session_id:
		return false
	_active["submitted"] = true
	return true


func snapshot() -> Dictionary:
	return _active.duplicate(true)


func clear(pointer_session_id: int = -1) -> Dictionary:
	if _active.is_empty():
		return {}
	if pointer_session_id >= 0 and int(_active.get("pointer_session_id", 0)) != pointer_session_id:
		return {}
	var previous: Dictionary = snapshot()
	_active.clear()
	return previous
