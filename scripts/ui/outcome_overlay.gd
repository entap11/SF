class_name OutcomeOverlay
extends Control

const SFLog := preload("res://scripts/util/sf_log.gd")
const PostMatchSummaryPanelScript := preload("res://scripts/ui/ui_post_match_summary.gd")

signal post_match_action(action: String)

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBox
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
var _reparent_queued: bool = false
var _overlay_mode: String = "rematch"
var _stage_next_action: String = "next_round"
var _stage_next_available: bool = false
var _stage_status_text: String = ""
var _post_match_summary_panel: Control = null

const OVERLAY_MODE_REMATCH: String = "rematch"
const OVERLAY_MODE_STAGE_ROUND: String = "stage_round"

func _ready() -> void:
	_force_fullscreen_anchors()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_post_match_summary_panel()
	rematch_button.text = "REMATCH"
	exit_button.text = "MAIN MENU"
	rematch_button.pressed.connect(_on_rematch_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func show_outcome(
	winner_id: int,
	reason: String,
	player_id: int,
	record_text: String = "",
	h2h_text: String = ""
) -> void:
	_overlay_mode = OVERLAY_MODE_REMATCH
	_stage_next_action = "next_round"
	_stage_next_available = false
	_stage_status_text = ""
	SFLog.info("OUTCOME_OVERLAY_SHOW_CALL", {
		"iid": int(get_instance_id()),
		"inside_tree": is_inside_tree(),
		"path": str(get_path()) if is_inside_tree() else "<detached>"
	})
	_force_fullscreen_anchors()
	_ensure_outcome_layer()
	local_player_id = maxi(1, player_id)
	_action_taken = false
	clear_post_match_summary()
	visible = true
	panel.visible = true
	show()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	panel.modulate = Color(1, 1, 1, 1)
	panel.self_modulate = Color(1, 1, 1, 1)
	_apply_outcome(winner_id, reason, record_text, h2h_text)
	set_process(true)
	rematch_button.grab_focus()
	_log_show_state()
	call_deferred("_log_layout_after_frame")

func show_stage_round_outcome(data: Dictionary) -> void:
	_overlay_mode = OVERLAY_MODE_STAGE_ROUND
	_stage_next_action = str(data.get("next_action", "next_round"))
	_stage_next_available = bool(data.get("next_button_enabled", data.get("next_round_available", false)))
	_stage_status_text = str(data.get("status_text", "Ready for next round?"))
	SFLog.info("OUTCOME_OVERLAY_STAGE_SHOW_CALL", {
		"iid": int(get_instance_id()),
		"inside_tree": is_inside_tree(),
		"path": str(get_path()) if is_inside_tree() else "<detached>",
		"next_action": _stage_next_action,
		"next_available": _stage_next_available
	})
	_force_fullscreen_anchors()
	_ensure_outcome_layer()
	local_player_id = maxi(1, int(data.get("local_player_id", 1)))
	_action_taken = false
	clear_post_match_summary()
	visible = true
	panel.visible = true
	show()
	if get_parent() != null:
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	modulate = Color(1, 1, 1, 1)
	self_modulate = Color(1, 1, 1, 1)
	panel.modulate = Color(1, 1, 1, 1)
	panel.self_modulate = Color(1, 1, 1, 1)
	_apply_stage_round_outcome(data)
	set_process(true)
	rematch_button.grab_focus()
	_log_show_state()
	call_deferred("_log_layout_after_frame")

func hide_overlay() -> void:
	clear_post_match_summary()
	visible = false
	set_process(false)

func set_post_match_summary(summary: Dictionary, winner_id: int, player_id: int) -> void:
	_ensure_post_match_summary_panel()
	if _post_match_summary_panel == null:
		return
	if summary.is_empty():
		if _post_match_summary_panel.has_method("clear_summary"):
			_post_match_summary_panel.call("clear_summary")
		return
	var local_id: int = maxi(1, player_id)
	var victory: bool = winner_id > 0 and winner_id == local_id
	if _post_match_summary_panel.has_method("render_summary"):
		_post_match_summary_panel.call("render_summary", summary, victory)

func clear_post_match_summary() -> void:
	_ensure_post_match_summary_panel()
	if _post_match_summary_panel == null:
		return
	if _post_match_summary_panel.has_method("clear_summary"):
		_post_match_summary_panel.call("clear_summary")

func _ensure_post_match_summary_panel() -> void:
	if _post_match_summary_panel != null and is_instance_valid(_post_match_summary_panel):
		return
	if vbox == null:
		return
	var existing: Node = vbox.get_node_or_null("PostMatchSummaryPanel")
	if existing != null and existing.has_method("render_summary") and existing.has_method("clear_summary"):
		_post_match_summary_panel = existing as Control
		return
	var created_any: Variant = PostMatchSummaryPanelScript.new()
	if not (created_any is Control):
		return
	var created: Control = created_any as Control
	created.name = "PostMatchSummaryPanel"
	created.visible = false
	var insert_index: int = vbox.get_child_count()
	if countdown_label != null and countdown_label.get_parent() == vbox:
		insert_index = countdown_label.get_index()
	vbox.add_child(created)
	if insert_index >= 0 and insert_index < vbox.get_child_count() - 1:
		vbox.move_child(created, insert_index)
	_post_match_summary_panel = created

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_countdown_label()
	_update_status()

func _apply_outcome(winner_id: int, reason: String, record_text: String, h2h_text: String) -> void:
	title_label.text = "REMATCH?"
	if winner_id == 0:
		result_label.text = "DRAW"
	else:
		result_label.text = "PLAYER %d WINS" % winner_id
	var local_lost: bool = winner_id > 0 and winner_id != local_player_id
	exit_button.text = "BACK TO LOBBY" if local_lost else "MAIN MENU"
	reason_label.text = "How: %s" % _present_reason(reason)
	record_label.text = record_text if not record_text.is_empty() else "Record: 0-0"
	h2h_label.text = h2h_text if not h2h_text.is_empty() else "H2H: 0-0"
	stats_header.text = "Match Stats"
	_update_stat_labels()
	_update_countdown_label()
	_update_status()

func _apply_stage_round_outcome(data: Dictionary) -> void:
	var round_number: int = maxi(1, int(data.get("round_number", 1)))
	var total_rounds: int = maxi(round_number, int(data.get("total_rounds", round_number)))
	var winner_id: int = int(data.get("winner_id", 0))
	var reason: String = str(data.get("reason", ""))
	var round_time_ms: int = maxi(0, int(data.get("round_time_ms", 0)))
	var cumulative_time_ms: int = maxi(round_time_ms, int(data.get("cumulative_time_ms", round_time_ms)))
	var local_owned: int = maxi(0, int(data.get("local_owned_hives", 0)))
	var opponent_owned: int = maxi(0, int(data.get("opponent_owned_hives", 0)))
	var current_rank: int = int(data.get("current_rank", 0))
	var local_round_wins: int = maxi(0, int(data.get("local_round_wins", 0)))
	var opponent_round_wins: int = maxi(0, int(data.get("opponent_round_wins", 0)))
	var next_label: String = str(data.get("next_label", "Next Round"))
	var exit_label: String = str(data.get("exit_label", "Back to Lobby"))
	title_label.text = "ROUND %d OF %d" % [round_number, total_rounds]
	if winner_id == 0:
		result_label.text = "ROUND RESULT: DRAW"
	elif winner_id == local_player_id:
		result_label.text = "ROUND RESULT: YOU WON"
	else:
		result_label.text = "ROUND RESULT: YOU LOST"
	reason_label.text = "How: %s" % _present_reason(reason)
	record_label.text = "Current Map Time: %s | Cumulative Time: %s" % [_format_stage_time(round_time_ms), _format_stage_time(cumulative_time_ms)]
	h2h_label.text = "Score: You %d | Opponent %d" % [local_owned, opponent_owned]
	stats_header.text = "Cumulative Rank"
	if current_rank > 0:
		stat_max_power.text = "#%d (provisional, cumulative)" % current_rank
	else:
		stat_max_power.text = "-- (provisional, cumulative)"
	stat_units_killed.text = "Round Wins: You %d | Opponent %d" % [local_round_wins, opponent_round_wins]
	stat_units_landed.text = "Rank is based on cumulative run totals (%d/%d)" % [round_number, total_rounds]
	countdown_label.text = ""
	rematch_button.text = next_label
	rematch_button.disabled = not _stage_next_available
	exit_button.text = exit_label
	_update_status()

func _update_stat_labels() -> void:
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		return
	var stats_by_team: Dictionary = OpsState.stats_by_team
	var team_stats: Dictionary = stats_by_team.get(local_player_id, {})
	var max_power: int = int(team_stats.get("max_total_hive_power", 0))
	var killed: int = int(team_stats.get("units_killed", 0))
	var landed: int = int(team_stats.get("units_landed", 0))
	stat_max_power.text = "Max Total Hive Power: %d" % max_power
	stat_units_killed.text = "Units Killed: %d" % killed
	stat_units_landed.text = "Units Landed: %d" % landed

func _update_countdown_label() -> void:
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		countdown_label.text = ""
		return
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
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		if _action_taken:
			status_label.text = "Loading next round..."
			return
		if _stage_status_text != "":
			status_label.text = _stage_status_text
			return
		status_label.text = "Ready for next round?"
		return
	var votes: Dictionary = OpsState.rematch_votes
	var local_voted: bool = votes.has(local_player_id)
	var post_action: String = str(OpsState.post_end_action)
	var window_open: bool = _is_rematch_window_open()
	rematch_button.disabled = local_voted or post_action != "" or not window_open
	if post_action == "rematch":
		status_label.text = "Rematch locked. Restarting..."
		return
	if post_action == "main_menu":
		status_label.text = "Rematch window expired."
		return
	if not window_open:
		status_label.text = "Rematch window expired. Choose Main Menu."
		return
	if local_voted:
		status_label.text = "Vote sent. Waiting on opponent..."
		return
	status_label.text = "Rematch votes: %d/2" % int(votes.size())

func _on_rematch_pressed() -> void:
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		if _action_taken or rematch_button.disabled:
			return
		_action_taken = true
		emit_signal("post_match_action", _stage_next_action)
		return
	if _action_taken or rematch_button.disabled or not _is_rematch_window_open():
		return
	emit_signal("post_match_action", "rematch_vote")

func _on_exit_pressed() -> void:
	if _action_taken:
		return
	_action_taken = true
	emit_signal("post_match_action", "main_menu")

func _present_reason(reason: String) -> String:
	var normalized: String = reason.strip_edges().to_lower()
	match normalized:
		"time", "timeout":
			return "time"
		"conquest", "elimination", "domination":
			return "domination"
		_:
			return normalized

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
		if _outcome_layer == null:
			_outcome_layer = CanvasLayer.new()
			_outcome_layer.name = "OutcomeCanvasLayer"
			_outcome_layer.layer = 999
		if _outcome_layer.get_parent() == null:
			ui_parent.call_deferred("add_child", _outcome_layer)
	if _outcome_layer == null:
		return
	_outcome_layer.layer = 999
	if get_parent() != _outcome_layer:
		if not _reparent_queued:
			_reparent_queued = true
			call_deferred("_deferred_reparent_to_outcome_layer")
	visible = false
	top_level = false
	z_as_relative = false
	z_index = 0
	clip_children = Control.CLIP_CHILDREN_DISABLED

func _deferred_reparent_to_outcome_layer() -> void:
	if _outcome_layer == null:
		_reparent_queued = false
		return
	if _outcome_layer.get_parent() == null:
		call_deferred("_deferred_reparent_to_outcome_layer")
		return
	_reparent_queued = false
	if get_parent() == _outcome_layer:
		return
	var old_parent: Node = get_parent()
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

func _nearest_canvas_layer() -> CanvasLayer:
	var p := get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null

func _is_rematch_window_open() -> bool:
	var deadline_ms: int = int(OpsState.rematch_deadline_ms)
	if deadline_ms <= 0:
		return true
	return Time.get_ticks_msec() <= deadline_ms

func _format_stage_time(ms: int) -> String:
	var clamped: int = maxi(0, ms)
	var total_seconds: int = int(round(float(clamped) / 1000.0))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _exit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
