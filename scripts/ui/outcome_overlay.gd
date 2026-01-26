class_name OutcomeOverlay
extends Control

const SFLog := preload("res://scripts/util/sf_log.gd")

signal post_match_action(action: String)

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var result_label: Label = $Panel/VBox/Result
@onready var reason_label: Label = $Panel/VBox/Reason
@onready var record_label: Label = $Panel/VBox/Record
@onready var h2h_label: Label = $Panel/VBox/H2H
@onready var stats_header: Label = $Panel/VBox/StatsHeader
@onready var stat_max_power: Label = $Panel/VBox/StatMaxHivePower
@onready var stat_units_killed: Label = $Panel/VBox/StatUnitsKilled
@onready var stat_units_landed: Label = $Panel/VBox/StatUnitsLanded
@onready var countdown_label: Label = $Panel/VBox/Countdown
@onready var status_label: Label = $Panel/VBox/Status
@onready var rematch_button: Button = $Panel/VBox/Buttons/Rematch
@onready var exit_button: Button = $Panel/VBox/Buttons/Exit

var local_player_id: int = 1
var _action_taken: bool = false
var _outcome_layer: CanvasLayer = null

func _ready() -> void:
	_ensure_outcome_layer()
	_force_fullscreen_anchors()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	rematch_button.text = "REMATCH"
	exit_button.text = "MAIN MENU"
	rematch_button.pressed.connect(_on_rematch_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func show_outcome(winner_id: int, reason: String, player_id: int) -> void:
	SFLog.info("OUTCOME_OVERLAY_SHOW_CALL", {
		"iid": int(get_instance_id()),
		"inside_tree": is_inside_tree(),
		"path": str(get_path()) if is_inside_tree() else "<detached>"
	})
	_force_fullscreen_anchors()
	_ensure_outcome_layer()
	local_player_id = maxi(1, player_id)
	_action_taken = false
	visible = true
	panel.visible = true
	show()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	panel.modulate = Color(1, 1, 1, 1)
	panel.self_modulate = Color(1, 1, 1, 1)
	_apply_outcome(winner_id, reason)
	set_process(true)
	rematch_button.grab_focus()
	_log_show_state()
	call_deferred("_log_layout_after_frame")

func hide_overlay() -> void:
	visible = false
	set_process(false)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_countdown_label()
	_update_status()

func _apply_outcome(winner_id: int, reason: String) -> void:
	title_label.text = "REMATCH?"
	if winner_id == 0:
		result_label.text = "DRAW"
	else:
		result_label.text = "PLAYER %d WINS" % winner_id
	reason_label.text = "Reason: %s" % reason
	record_label.text = "Record: 0-0"
	h2h_label.text = "H2H: 0-0"
	stats_header.text = "Match Stats"
	_update_stat_labels()
	_update_countdown_label()
	_update_status()

func _update_stat_labels() -> void:
	var stats_by_team: Dictionary = OpsState.stats_by_team
	var team_stats: Dictionary = stats_by_team.get(local_player_id, {})
	var max_power: int = int(team_stats.get("max_total_hive_power", 0))
	var killed: int = int(team_stats.get("units_killed", 0))
	var landed: int = int(team_stats.get("units_landed", 0))
	stat_max_power.text = "Max Total Hive Power: %d" % max_power
	stat_units_killed.text = "Units Killed: %d" % killed
	stat_units_landed.text = "Units Landed: %d" % landed

func _update_countdown_label() -> void:
	var deadline_ms: int = int(OpsState.rematch_deadline_ms)
	if deadline_ms <= 0:
		countdown_label.text = ""
		return
	var remaining_ms: int = maxi(0, deadline_ms - Time.get_ticks_msec())
	if remaining_ms <= 0:
		countdown_label.text = "Rematch window expired"
		return
	var sec: int = int(ceil(float(remaining_ms) / 1000.0))
	countdown_label.text = "Rematch window: 0:%02d" % sec

func _update_status() -> void:
	var votes: Dictionary = OpsState.rematch_votes
	status_label.text = "Rematch votes: %d/2" % int(votes.size())

func _on_rematch_pressed() -> void:
	if _action_taken:
		return
	_action_taken = true
	emit_signal("post_match_action", "rematch")

func _on_exit_pressed() -> void:
	if _action_taken:
		return
	_action_taken = true
	emit_signal("post_match_action", "main_menu")

func _log_show_state() -> void:
	var layer := -999
	var layer_path := ""
	var canvas_layer := _nearest_canvas_layer()
	if canvas_layer != null:
		layer = canvas_layer.layer
		layer_path = str(canvas_layer.get_path())
	var path_str := "<detached>"
	if is_inside_tree():
		path_str = str(get_path())
	SFLog.info("OUTCOME_OVERLAY_SHOW", {
		"path": path_str,
		"inside_tree": is_inside_tree(),
		"visible": visible,
		"panel_visible": panel.visible,
		"global_position": global_position,
		"size": size,
		"panel_size": panel.size,
		"z_index": z_index,
		"layer": layer,
		"layer_path": layer_path
	})
	SFLog.info("OUTCOME_OVERLAY_CHAIN", {"chain": _dump_parent_chain()})
	var parent_path := "<none>"
	if get_parent() != null:
		parent_path = str(get_parent().get_path())
	var viewport_rect := Rect2()
	var viewport := get_viewport()
	if viewport != null:
		viewport_rect = viewport.get_visible_rect()
	SFLog.info("OUTCOME_OVERLAY_CANVAS", {
		"parent": parent_path,
		"layer": layer,
		"viewport_rect": viewport_rect
	})

func _log_layout_after_frame() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	SFLog.info("OUTCOME_OVERLAY_LAYOUT", {
		"size_after_frame": size,
		"panel_size": panel.size
	})

func _dump_parent_chain() -> Array:
	var out: Array = []
	var n: Node = self
	while n != null:
		if n is CanvasItem:
			var ci := n as CanvasItem
			out.append({
				"path": str(ci.get_path()),
				"visible": ci.visible,
				"modulate_a": ci.modulate.a,
				"self_modulate_a": ci.self_modulate.a,
				"scale": ci.scale,
				"z_index": ci.z_index,
				"top_level": ci.top_level
			})
		else:
			out.append({"path": str(n.get_path()), "type": n.get_class()})
		n = n.get_parent()
	return out

func _force_fullscreen_anchors() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

func _ensure_outcome_layer() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var ui_parent := tree.root
	if ui_parent == null:
		return
	var existing := ui_parent.get_node_or_null("OutcomeCanvasLayer")
	if existing != null and existing is CanvasLayer:
		_outcome_layer = existing as CanvasLayer
	else:
		_outcome_layer = CanvasLayer.new()
		_outcome_layer.name = "OutcomeCanvasLayer"
		_outcome_layer.layer = 999
		ui_parent.add_child(_outcome_layer)
	if _outcome_layer == null:
		return
	_outcome_layer.layer = 999
	if get_parent() != _outcome_layer:
		var old_parent := get_parent()
		if old_parent != null:
			old_parent.remove_child(self)
		_outcome_layer.add_child(self)
		var viewport_rect := Rect2()
		var viewport := get_viewport()
		if viewport != null:
			viewport_rect = viewport.get_visible_rect()
		SFLog.info("OUTCOME_LAYER_REPARENT", {
			"overlay_inside_tree": is_inside_tree(),
			"overlay_path": str(get_path()) if is_inside_tree() else "<detached>",
			"layer_inside_tree": _outcome_layer.is_inside_tree(),
			"layer_path": str(_outcome_layer.get_path()) if _outcome_layer.is_inside_tree() else "<detached>",
			"viewport_rect": viewport_rect
		})
	visible = false
	top_level = false
	z_as_relative = false
	z_index = 0
	clip_children = Control.CLIP_CHILDREN_DISABLED

func _nearest_canvas_layer() -> CanvasLayer:
	var p := get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null

func _exit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
