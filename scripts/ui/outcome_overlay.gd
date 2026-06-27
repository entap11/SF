class_name OutcomeOverlay
extends Control

const SFLog := preload("res://scripts/util/sf_log.gd")
const PostMatchSummaryPanelScript := preload("res://scripts/ui/ui_post_match_summary.gd")
const AdSurfaceScript := preload("res://scripts/ui/ad_surface.gd")

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
var _post_match_ad_surface: Control = null

const PANEL_MAX_SIZE: Vector2 = Vector2(740.0, 620.0)
const PANEL_MARGIN_PX: float = 28.0
const PANEL_PAD_PX: float = 24.0
const LABEL_FONT_BODY: int = 18
const LABEL_FONT_TITLE: int = 30
const LABEL_FONT_RESULT: int = 24
const LABEL_FONT_STATUS: int = 18
const BUTTON_FONT_SIZE: int = 18
const BUTTON_MIN_SIZE: Vector2 = Vector2(190.0, 58.0)
const POST_MATCH_AD_SIZE: Vector2 = Vector2(520.0, 72.0)
const PANEL_BG: Color = Color(0.035, 0.038, 0.048, 0.92)
const PANEL_BORDER: Color = Color(0.95, 0.82, 0.24, 0.55)
const FONT_MAIN: Color = Color(0.96, 0.95, 0.88, 1.0)
const FONT_MUTED: Color = Color(0.82, 0.82, 0.76, 1.0)
const FONT_RESULT: Color = Color(1.0, 0.88, 0.30, 1.0)

const OVERLAY_MODE_REMATCH: String = "rematch"
const OVERLAY_MODE_STAGE_ROUND: String = "stage_round"
const OVERLAY_MODE_TUTORIAL_COMPLETE: String = "tutorial_complete"

func _ready() -> void:
	_force_fullscreen_anchors()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_post_match_summary_panel()
	_ensure_post_match_ad_surface()
	_apply_readable_layout()
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
	_apply_readable_layout()
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
	_apply_readable_layout()
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

func show_tutorial_complete(winner_id: int, reason: String, player_id: int) -> void:
	_overlay_mode = OVERLAY_MODE_TUTORIAL_COMPLETE
	_stage_next_action = "main_menu"
	_stage_next_available = false
	_stage_status_text = ""
	SFLog.info("OUTCOME_OVERLAY_TUTORIAL_SHOW_CALL", {
		"iid": int(get_instance_id()),
		"inside_tree": is_inside_tree(),
		"path": str(get_path()) if is_inside_tree() else "<detached>"
	})
	_force_fullscreen_anchors()
	_apply_readable_layout()
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
	_apply_tutorial_complete_outcome(winner_id, reason)
	set_process(true)
	exit_button.grab_focus()
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
	if _overlay_mode == OVERLAY_MODE_REMATCH:
		if _post_match_summary_panel.has_method("clear_summary"):
			_post_match_summary_panel.call("clear_summary")
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

func _ensure_post_match_ad_surface() -> void:
	if _post_match_ad_surface != null and is_instance_valid(_post_match_ad_surface):
		return
	if vbox == null:
		return
	var existing: Node = vbox.get_node_or_null("PostMatchAdSurface")
	if existing is Control:
		_post_match_ad_surface = existing as Control
	else:
		var created_any: Variant = AdSurfaceScript.new()
		if not (created_any is Control):
			return
		var created: Control = created_any as Control
		created.name = "PostMatchAdSurface"
		vbox.add_child(created)
		_post_match_ad_surface = created
	if _post_match_ad_surface.has_method("configure"):
		_post_match_ad_surface.call(
			"configure",
			"post_match_summary",
			"post_match",
			POST_MATCH_AD_SIZE,
			false
		)
	var insert_index: int = vbox.get_child_count()
	if countdown_label != null and countdown_label.get_parent() == vbox:
		insert_index = countdown_label.get_index()
	if _post_match_ad_surface.get_parent() == vbox and insert_index >= 0 and _post_match_ad_surface.get_index() > insert_index:
		vbox.move_child(_post_match_ad_surface, mini(insert_index, vbox.get_child_count() - 1))

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_countdown_label()
	_update_status()

func _apply_outcome(winner_id: int, reason: String, _record_text: String, _h2h_text: String) -> void:
	_set_standard_rows_visible(false)
	countdown_label.visible = true
	rematch_button.visible = true
	rematch_button.disabled = false
	rematch_button.text = "REMATCH"
	exit_button.text = "MAIN MENU"
	title_label.text = "GAME OVER"
	result_label.text = _simple_result_text(winner_id)
	reason_label.text = _simple_reason_text(reason)
	record_label.visible = false
	record_label.text = ""
	h2h_label.text = ""
	stats_header.text = ""
	stat_max_power.text = ""
	stat_units_killed.text = ""
	stat_units_landed.text = ""
	_apply_crucible_status_from_tree(winner_id)
	_update_countdown_label()
	_update_status()

func _apply_stage_round_outcome(data: Dictionary) -> void:
	if str(data.get("mode_id", "")).strip_edges().to_upper() == "PROGRESSIVE":
		_apply_progressive_stage_outcome(data)
		return
	_set_standard_rows_visible(true)
	rematch_button.visible = true
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
	if bool(data.get("paid_entry", false)):
		_apply_stage_money_status(data, current_rank, round_number, total_rounds)
	else:
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
	_apply_readable_layout()
	_update_status()

func _apply_stage_money_status(data: Dictionary, current_rank: int, round_number: int, total_rounds: int) -> void:
	var wager_cents: int = maxi(0, int(data.get("wager_cents", 0)))
	var escrow_cents: int = maxi(0, int(data.get("async_money_escrow_cents", wager_cents)))
	var pot_cents: int = maxi(0, int(data.get("async_money_pot_cents", escrow_cents)))
	var payout_cents: int = maxi(0, int(data.get("winner_payout_cents", 0)))
	var ledger_status: String = str(data.get("async_money_ledger_status", "")).strip_edges().to_lower()
	var balance_start_cents: int = maxi(0, int(data.get("async_money_balance_start_cents", 0)))
	var balance_after_entry_cents: int = maxi(0, int(data.get("async_money_balance_after_entry_cents", balance_start_cents)))
	var balance_finish_cents: int = maxi(0, int(data.get("async_money_balance_finish_cents", balance_after_entry_cents + payout_cents)))
	stats_header.text = "Money Status"
	if balance_start_cents > 0 or balance_after_entry_cents > 0:
		stat_max_power.text = "Wallet: start %s | after entry %s | finish %s" % [
			_format_money_cents(balance_start_cents),
			_format_money_cents(balance_after_entry_cents),
			_format_money_cents(balance_finish_cents)
		]
	else:
		stat_max_power.text = "Entry debited: %s | Escrow: %s" % [_format_money_cents(wager_cents), _format_money_cents(escrow_cents)]
	if payout_cents > 0 or ledger_status == "settled":
		stat_units_killed.text = "Payout received: %s | Pot: %s" % [_format_money_cents(payout_cents), _format_money_cents(pot_cents)]
	elif ledger_status == "refunded":
		stat_units_killed.text = "Entry refunded: %s" % _format_money_cents(escrow_cents)
	elif current_rank > 0:
		stat_units_killed.text = "Entry: %s | Rank: #%d provisional | Pot: %s" % [_format_money_cents(wager_cents), current_rank, _format_money_cents(pot_cents)]
	else:
		stat_units_killed.text = "Entry: %s | Rank: -- provisional | Pot: %s" % [_format_money_cents(wager_cents), _format_money_cents(pot_cents)]
	if payout_cents > 0 or ledger_status == "settled":
		stat_units_landed.text = "Contest settlement is complete."
	elif ledger_status == "refunded":
		stat_units_landed.text = "This entry is no longer live."
	else:
		stat_units_landed.text = "Payout pending until contest close (%d/%d maps)." % [round_number, total_rounds]

func _apply_progressive_stage_outcome(data: Dictionary) -> void:
	_set_standard_rows_visible(true)
	rematch_button.visible = true
	var stage_number: int = maxi(1, int(data.get("stage_number", 1)))
	var stage_count: int = maxi(stage_number, int(data.get("stage_count", stage_number)))
	var winner_id: int = int(data.get("winner_id", 0))
	var reason: String = str(data.get("reason", ""))
	var stage_stars: int = clampi(int(data.get("stars", 0)), 0, 4)
	var total_stars: int = maxi(0, int(data.get("total_stars", stage_stars)))
	var max_stars: int = maxi(total_stars, int(data.get("max_stars", stage_count * 4)))
	var elapsed_ms: int = maxi(0, int(data.get("elapsed_ms", 0)))
	var thresholds: Dictionary = data.get("thresholds_ms", {}) as Dictionary
	var next_available: bool = bool(data.get("next_round_available", false))
	var next_label: String = str(data.get("next_label", "Next Stage"))
	var exit_label: String = str(data.get("exit_label", "Main Menu"))
	title_label.text = "GAUNTLET %d OF %d" % [stage_number, stage_count]
	if winner_id == 0:
		result_label.text = "STAGE RESULT: DRAW"
	elif winner_id == local_player_id:
		result_label.text = "STAGE RESULT: YOU WON"
	else:
		result_label.text = "STAGE RESULT: RUN ENDED"
	reason_label.text = "How: %s" % _present_reason(reason)
	record_label.text = "Stage Stars: %s  (%s)" % [_star_text(stage_stars, 4), _format_stage_time(elapsed_ms)]
	h2h_label.text = "Run Stars: %d / %d" % [total_stars, max_stars]
	stats_header.text = "Star Times"
	stat_max_power.text = "4-star: %s | 3-star: %s | 2-star: %s" % [
		_format_stage_time(int(thresholds.get("four_star_ms", 0))),
		_format_stage_time(int(thresholds.get("three_star_ms", 0))),
		_format_stage_time(int(thresholds.get("two_star_ms", 0)))
	]
	stat_units_killed.text = "Current Stage: %d / %d" % [stage_number, stage_count]
	if next_available:
		stat_units_landed.text = "Next stage starts automatically."
	else:
		stat_units_landed.text = "Running tally: %s" % _star_text(total_stars, max_stars)
	countdown_label.text = ""
	rematch_button.text = next_label
	rematch_button.disabled = not _stage_next_available
	rematch_button.visible = not next_available
	exit_button.text = exit_label
	_apply_readable_layout()
	_update_status()

func _apply_tutorial_complete_outcome(winner_id: int, reason: String) -> void:
	_set_standard_rows_visible(false)
	title_label.text = "TUTORIAL COMPLETE"
	if winner_id == local_player_id:
		result_label.text = "YOU WON"
	elif winner_id == 0:
		result_label.text = "MATCH COMPLETE"
	else:
		result_label.text = "MATCH COMPLETE"
	reason_label.visible = true
	reason_label.text = "Section 2 is unlocked."
	record_label.visible = true
	record_label.text = "Head back to the main menu when you're ready."
	h2h_label.text = ""
	stats_header.text = ""
	stat_max_power.text = ""
	stat_units_killed.text = ""
	stat_units_landed.text = ""
	countdown_label.text = ""
	rematch_button.visible = false
	rematch_button.disabled = true
	exit_button.text = "MAIN MENU"
	exit_button.custom_minimum_size = Vector2(maxf(exit_button.custom_minimum_size.x, 220.0), maxf(exit_button.custom_minimum_size.y, 72.0))
	_update_status()

func _set_standard_rows_visible(show_rows: bool) -> void:
	reason_label.visible = true
	record_label.visible = true
	h2h_label.visible = show_rows
	stats_header.visible = show_rows
	stat_max_power.visible = show_rows
	stat_units_killed.visible = show_rows
	stat_units_landed.visible = show_rows
	countdown_label.visible = show_rows

func _update_stat_labels() -> void:
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		return
	var ops_state: Node = _ops_state()
	var stats_by_team: Dictionary = ops_state.get("stats_by_team") if ops_state != null else {}
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
	var ops_state: Node = _ops_state()
	var deadline_ms: int = int(ops_state.get("rematch_deadline_ms")) if ops_state != null else 0
	if deadline_ms <= 0:
		countdown_label.text = ""
		return
	var remaining_ms: int = maxi(0, deadline_ms - Time.get_ticks_msec())
	if remaining_ms <= 0:
		countdown_label.text = ""
		return
	var sec: int = int(ceil(float(remaining_ms) / 1000.0))
	countdown_label.text = "Rematch available for %ds" % sec

func _update_status() -> void:
	if _overlay_mode == OVERLAY_MODE_TUTORIAL_COMPLETE:
		status_label.text = "Ready for the next lesson."
		return
	if _overlay_mode == OVERLAY_MODE_STAGE_ROUND:
		if _action_taken:
			status_label.text = "Loading next round..."
			return
		if _stage_status_text != "":
			status_label.text = _stage_status_text
			return
		status_label.text = "Ready for next round?"
		return
	var ops_state: Node = _ops_state()
	var votes: Dictionary = ops_state.get("rematch_votes") if ops_state != null else {}
	var local_voted: bool = votes.has(local_player_id)
	var post_action: String = str(ops_state.get("post_end_action")) if ops_state != null else ""
	var window_open: bool = _is_rematch_window_open()
	rematch_button.disabled = local_voted or post_action != "" or not window_open
	if post_action == "rematch":
		status_label.text = "Starting rematch..."
		return
	if post_action == "main_menu":
		status_label.text = "Returning to menu..."
		return
	if not window_open:
		status_label.text = "Rematch expired."
		return
	if local_voted:
		status_label.text = "Waiting for opponent..."
		return
	status_label.text = "Play again?"

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
		"conquest", "elimination", "domination", "capture_all":
			return "domination"
		_:
			return normalized

func _star_text(filled: int, total: int) -> String:
	var clean_total: int = maxi(0, total)
	var clean_filled: int = clampi(filled, 0, clean_total)
	var chars: PackedStringArray = PackedStringArray()
	for i in range(clean_total):
		chars.append("*" if i < clean_filled else "-")
	return "".join(chars)

func _format_money_cents(cents: int) -> String:
	var clean_cents: int = maxi(0, cents)
	return "$%d.%02d" % [int(clean_cents / 100), clean_cents % 100]

func _apply_crucible_status_from_tree(winner_id: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or not bool(tree.get_meta("vs_crucible", false)):
		return
	_set_standard_rows_visible(true)
	stats_header.text = "Crucible Wax"
	var start_millis: int = maxi(0, int(tree.get_meta("crucible_local_balance_start_millis", 0)))
	var after_escrow_millis: int = maxi(0, int(tree.get_meta("crucible_local_balance_after_escrow_millis", start_millis)))
	var finish_millis: int = maxi(0, int(tree.get_meta("crucible_local_balance_finish_millis", after_escrow_millis)))
	var stake_millis: int = maxi(0, int(tree.get_meta("crucible_stake_each_millis", start_millis - after_escrow_millis)))
	var payout_millis: int = maxi(0, int(tree.get_meta("crucible_winner_payout_millis", 0)))
	var burn_millis: int = maxi(0, int(tree.get_meta("crucible_burn_millis", 0)))
	var delta_millis: int = int(tree.get_meta("crucible_balance_delta_millis", finish_millis - start_millis))
	var settlement_status: String = str(tree.get_meta("crucible_settlement_status", "")).strip_edges()
	stat_max_power.text = "Wax: start %s | after escrow %s | finish %s" % [
		_format_wax_millis(start_millis),
		_format_wax_millis(after_escrow_millis),
		_format_wax_millis(finish_millis)
	]
	var delta_prefix: String = "+" if delta_millis > 0 else ""
	stat_units_killed.text = "Stake %s | Winner payout %s | Burn %s | Net %s%s" % [
		_format_wax_millis(stake_millis),
		_format_wax_millis(payout_millis),
		_format_wax_millis(burn_millis),
		delta_prefix,
		_format_signed_wax_millis(delta_millis)
	]
	if settlement_status.is_empty():
		stat_units_landed.text = "Crucible settlement status pending."
	elif winner_id == 0 or settlement_status == "NO_CONTEST" or settlement_status == "REFUNDED":
		stat_units_landed.text = "Crucible settlement: %s." % settlement_status.capitalize()
	elif winner_id == local_player_id:
		stat_units_landed.text = "Crucible settlement: %s. You won this Wax match." % settlement_status.capitalize()
	else:
		stat_units_landed.text = "Crucible settlement: %s. You lost this Wax match." % settlement_status.capitalize()

func _format_wax_millis(amount_millis: int) -> String:
	var clean_millis: int = maxi(0, amount_millis)
	return "%d.%03d Wax" % [int(clean_millis / 1000), clean_millis % 1000]

func _format_signed_wax_millis(amount_millis: int) -> String:
	if amount_millis < 0:
		return "-%s" % _format_wax_millis(absi(amount_millis))
	return _format_wax_millis(amount_millis)

func _simple_result_text(winner_id: int) -> String:
	if winner_id == 0:
		return "Draw"
	if winner_id == local_player_id:
		return "You won"
	return "You lost"

func _simple_reason_text(reason: String) -> String:
	var presented: String = _present_reason(reason)
	if presented.is_empty():
		return ""
	if presented == "time":
		return "Time ran out."
	if presented == "domination":
		return "Win by domination."
	return "Win by %s." % presented

func _ops_state() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var root_node: Window = tree.root
	if root_node == null:
		return null
	return root_node.get_node_or_null("OpsState")

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

func _apply_readable_layout() -> void:
	if panel == null or vbox == null:
		return
	var viewport_size: Vector2 = PANEL_MAX_SIZE + Vector2(PANEL_MARGIN_PX * 2.0, PANEL_MARGIN_PX * 2.0)
	var viewport := get_viewport()
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
	var panel_size := Vector2(
		minf(PANEL_MAX_SIZE.x, maxf(360.0, viewport_size.x - PANEL_MARGIN_PX * 2.0)),
		minf(PANEL_MAX_SIZE.y, maxf(420.0, viewport_size.y - PANEL_MARGIN_PX * 2.0))
	)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	panel.custom_minimum_size = panel_size
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = PANEL_PAD_PX
	panel_style.content_margin_top = PANEL_PAD_PX
	panel_style.content_margin_right = PANEL_PAD_PX
	panel_style.content_margin_bottom = PANEL_PAD_PX
	panel.add_theme_stylebox_override("panel", panel_style)

	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = PANEL_PAD_PX
	vbox.offset_top = PANEL_PAD_PX
	vbox.offset_right = -PANEL_PAD_PX
	vbox.offset_bottom = -PANEL_PAD_PX
	vbox.add_theme_constant_override("separation", 8)

	_style_label(title_label, LABEL_FONT_TITLE, FONT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label(result_label, LABEL_FONT_RESULT, FONT_RESULT, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label(reason_label, LABEL_FONT_BODY, FONT_MUTED)
	_style_label(record_label, LABEL_FONT_BODY, FONT_MAIN)
	_style_label(h2h_label, LABEL_FONT_BODY, FONT_MAIN)
	_style_label(stats_header, LABEL_FONT_BODY, FONT_RESULT)
	_style_label(stat_max_power, LABEL_FONT_BODY, FONT_MAIN)
	_style_label(stat_units_killed, LABEL_FONT_BODY, FONT_MAIN)
	_style_label(stat_units_landed, LABEL_FONT_BODY, FONT_MAIN)
	_style_label(countdown_label, LABEL_FONT_STATUS, FONT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label(status_label, LABEL_FONT_STATUS, FONT_MAIN, HORIZONTAL_ALIGNMENT_CENTER)
	_style_button(rematch_button)
	_style_button(exit_button)
	if _post_match_ad_surface != null:
		_post_match_ad_surface.custom_minimum_size = Vector2(
			minf(POST_MATCH_AD_SIZE.x, maxf(320.0, panel_size.x - PANEL_PAD_PX * 2.0)),
			POST_MATCH_AD_SIZE.y
		)

func _style_label(label: Label, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if label == null:
		return
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _style_button(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(
		maxf(button.custom_minimum_size.x, BUTTON_MIN_SIZE.x),
		maxf(button.custom_minimum_size.y, BUTTON_MIN_SIZE.y)
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)

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
	var ops_state: Node = _ops_state()
	var deadline_ms: int = int(ops_state.get("rematch_deadline_ms")) if ops_state != null else 0
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
