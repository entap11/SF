class_name ShellMvpWaiter
extends RefCounted

func wait_for_node(owner: Node, path: String, timeout_ms: int) -> Node:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var node: Node = owner.get_node_or_null(path)
		if node != null:
			return node
		await owner.get_tree().process_frame
	return null

func wait_for_records_visible(owner: Node, records_path: String, ops_state: Object, prematch_phase: int, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var records: Control = owner.get_node_or_null(records_path) as Control
		var prematch: bool = false
		if ops_state != null:
			prematch = int(ops_state.get("match_phase")) == prematch_phase
		if records != null and prematch and records.visible:
			return true
		await owner.get_tree().process_frame
	return false

func wait_for_phase(owner: Node, ops_state: Object, target_phase: int, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if ops_state != null and int(ops_state.get("match_phase")) == target_phase:
			return true
		await owner.get_tree().process_frame
	return false

func wait_for_phase_not(owner: Node, ops_state: Object, target_phase: int, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		if ops_state != null and int(ops_state.get("match_phase")) != target_phase:
			return true
		await owner.get_tree().process_frame
	return false

func wait_ms(owner: Node, duration_ms: int) -> void:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < duration_ms:
		await owner.get_tree().process_frame

func wait_for_outcome_overlay_visible(owner: Node, overlay_path: String, timeout_ms: int) -> bool:
	var start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms <= timeout_ms:
		var overlay: Control = owner.get_node_or_null(overlay_path) as Control
		if overlay != null and overlay.visible:
			return true
		await owner.get_tree().process_frame
	return false
