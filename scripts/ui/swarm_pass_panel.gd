extends Panel

signal close_requested()

@onready var title_label: Label = $Root/VBox/Title
@onready var season_label: Label = $Root/VBox/Season
@onready var tier_label: Label = $Root/VBox/Tier
@onready var progress_label: Label = $Root/VBox/Progress
@onready var progress_bar: ProgressBar = $Root/VBox/ProgressBar
@onready var guardrail_label: Label = $Root/VBox/Guardrail
@onready var prestige_label: Label = $Root/VBox/Prestige
@onready var actions_row: HBoxContainer = $Root/VBox/ActionsRow
@onready var premium_button: Button = $Root/VBox/ActionsRow/PremiumButton
@onready var elite_button: Button = $Root/VBox/ActionsRow/EliteButton
@onready var claim_button: Button = $Root/VBox/ActionsRow/ClaimButton
@onready var async_button: Button = $Root/VBox/ActionsRow/AsyncButton
@onready var close_button: Button = $Root/VBox/ActionsRow/CloseButton
@onready var event_log_label: Label = $Root/VBox/EventLog
@onready var levels_text: RichTextLabel = $Root/VBox/LevelsScroll/LevelsText

var _last_snapshot: Dictionary = {}

func _ready() -> void:
	title_label.text = "SwarmPass v1"
	premium_button.text = "Get Premium"
	elite_button.text = "Get Elite"
	claim_button.text = "Claim Current"
	async_button.text = "Elite Async"
	close_button.text = "Close"
	event_log_label.text = ""
	premium_button.pressed.connect(func() -> void:
		var state_node: Node = _swarm_pass_state()
		if state_node == null:
			return
		var result: Dictionary = state_node.intent_purchase_pass_tier("PREMIUM")
		_log_action_result("Premium", result)
	)
	elite_button.pressed.connect(func() -> void:
		var state_node: Node = _swarm_pass_state()
		if state_node == null:
			return
		var result: Dictionary = state_node.intent_purchase_pass_tier("ELITE")
		_log_action_result("Elite", result)
	)
	claim_button.pressed.connect(func() -> void:
		var state_node: Node = _swarm_pass_state()
		if state_node == null:
			return
		var level: int = int(_last_snapshot.get("pass_level", 1))
		var result: Dictionary = state_node.intent_claim_level(level)
		_log_action_result("Claim L%d" % level, result)
	)
	async_button.pressed.connect(func() -> void:
		var state_node: Node = _swarm_pass_state()
		if state_node == null:
			return
		var unlocked: bool = bool(_last_snapshot.get("elite_async_access", false))
		_log_action_result("Elite Async", {"ok": unlocked, "reason": "requires_elite_pass" if not unlocked else ""})
	)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	var state_node: Node = _swarm_pass_state()
	if state_node != null:
		if not state_node.pass_state_changed.is_connected(_on_swarm_pass_state_changed):
			state_node.pass_state_changed.connect(_on_swarm_pass_state_changed)
		if not state_node.pass_event.is_connected(_on_swarm_pass_event):
			state_node.pass_event.connect(_on_swarm_pass_event)
		_on_swarm_pass_state_changed(state_node.get_snapshot())

func _exit_tree() -> void:
	var state_node: Node = _swarm_pass_state()
	if state_node == null:
		return
	if state_node.pass_state_changed.is_connected(_on_swarm_pass_state_changed):
		state_node.pass_state_changed.disconnect(_on_swarm_pass_state_changed)
	if state_node.pass_event.is_connected(_on_swarm_pass_event):
		state_node.pass_event.disconnect(_on_swarm_pass_event)

func _on_swarm_pass_state_changed(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	var tier_name: String = str(snapshot.get("pass_tier", "FREE"))
	var multiplier: float = float(snapshot.get("pass_multiplier", 1.0))
	var level: int = int(snapshot.get("pass_level", 1))
	var total: int = int(snapshot.get("total_levels", 100))
	var next_level: int = int(snapshot.get("next_level", level))
	var req: int = int(snapshot.get("next_level_requirement", 0))
	var progress: float = clampf(float(snapshot.get("progress_to_next", 0.0)), 0.0, 1.0)
	var season_id: String = str(snapshot.get("season_id", "season"))
	var remaining_sec: int = int(snapshot.get("season_seconds_remaining", 0))
	var remaining_days: int = int(floor(float(remaining_sec) / 86400.0))
	season_label.text = "Season %s · %dd left" % [season_id, remaining_days]
	tier_label.text = "Tier: %s · Multiplier x%.2f · Nectar: %d" % [tier_name, multiplier, int(snapshot.get("wallet_nectar", 0))]
	progress_label.text = "Level %d / %d · Next L%d requires %d XP" % [level, total, next_level, req]
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = progress * 100.0
	guardrail_label.text = str(snapshot.get("guardrail_text", ""))
	var prestige_model: String = str(snapshot.get("prestige_model", "soft_cap"))
	var blocked_level: int = int(snapshot.get("blocked_hard_brick_level", -1))
	var prestige_line: String = "Prestige model: %s" % prestige_model
	if blocked_level > 0:
		prestige_line += " · Level %d currently capped" % blocked_level
	prestige_label.text = prestige_line
	_render_level_rows(snapshot.get("level_rows", []) as Array)
	premium_button.disabled = tier_name == "PREMIUM" or tier_name == "ELITE"
	elite_button.disabled = tier_name == "ELITE"
	async_button.disabled = not bool(snapshot.get("elite_async_access", false))

func _on_swarm_pass_event(event: Dictionary) -> void:
	var event_type: String = str(event.get("type", "event"))
	event_log_label.text = "Last event: %s" % event_type

func _log_action_result(prefix: String, result: Dictionary) -> void:
	var ok: bool = bool(result.get("ok", false))
	if ok:
		event_log_label.text = "%s: ok" % prefix
	else:
		event_log_label.text = "%s: %s" % [prefix, str(result.get("reason", "blocked"))]

func _render_level_rows(rows: Array) -> void:
	var lines: PackedStringArray = PackedStringArray()
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var level: int = int(row.get("level", 0))
		var band: String = str(row.get("band", "standard"))
		var unlocked: bool = bool(row.get("unlocked", false))
		var marker: String = "[OPEN]" if unlocked else "[LOCK]"
		var remaining: int = int(row.get("remaining_slots", -1))
		var cap_suffix: String = ""
		if remaining >= 0 and level >= 76:
			cap_suffix = " | slots:%d" % remaining
		var variant: String = str(row.get("reward_variant", "standard"))
		lines.append("L%03d %s %s | %s%s" % [level, marker, band.to_upper(), variant, cap_suffix])
	levels_text.text = "\n".join(lines)

func _swarm_pass_state() -> Node:
	return get_node_or_null("/root/SwarmPassState")
