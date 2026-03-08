extends Panel

signal close_requested()

@export var battle_pass_state_path: NodePath = NodePath("/root/BattlePassState")
@export var season_label_path: NodePath = NodePath("Root/VBox/Season")
@export var summary_label_path: NodePath = NodePath("Root/VBox/Summary")
@export var veteran_label_path: NodePath = NodePath("Root/VBox/Veteran")
@export var wallet_label_path: NodePath = NodePath("Root/VBox/Wallet")
@export var levels_text_path: NodePath = NodePath("Root/VBox/LevelsScroll/LevelsText")
@export var quests_text_path: NodePath = NodePath("Root/VBox/QuestsScroll/QuestsText")
@export var premium_button_path: NodePath = NodePath("Root/VBox/Actions/PremiumButton")
@export var elite_button_path: NodePath = NodePath("Root/VBox/Actions/EliteButton")
@export var claim_current_button_path: NodePath = NodePath("Root/VBox/Actions/ClaimCurrentButton")
@export var claim_all_button_path: NodePath = NodePath("Root/VBox/Actions/ClaimAllButton")
@export var veteran_start_button_path: NodePath = NodePath("Root/VBox/Actions/VeteranStartButton")
@export var veteran_opt_out_button_path: NodePath = NodePath("Root/VBox/Actions/VeteranOptOutButton")
@export var close_button_path: NodePath = NodePath("Root/VBox/Actions/CloseButton")

var _state: Node = null
var _last_snapshot: Dictionary = {}

func _ready() -> void:
	_bind_state()
	_connect_buttons()
	_refresh_from_state()

func _exit_tree() -> void:
	if _state == null:
		return
	if _state.has_signal("battle_pass_state_changed") and _state.battle_pass_state_changed.is_connected(_on_state_changed):
		_state.battle_pass_state_changed.disconnect(_on_state_changed)
	if _state.has_signal("battle_pass_event") and _state.battle_pass_event.is_connected(_on_pass_event):
		_state.battle_pass_event.disconnect(_on_pass_event)

func _bind_state() -> void:
	_state = get_node_or_null(battle_pass_state_path)
	if _state == null:
		return
	if _state.has_signal("battle_pass_state_changed") and not _state.battle_pass_state_changed.is_connected(_on_state_changed):
		_state.battle_pass_state_changed.connect(_on_state_changed)
	if _state.has_signal("battle_pass_event") and not _state.battle_pass_event.is_connected(_on_pass_event):
		_state.battle_pass_event.connect(_on_pass_event)

func _connect_buttons() -> void:
	var premium_button: Button = get_node_or_null(premium_button_path) as Button
	var elite_button: Button = get_node_or_null(elite_button_path) as Button
	var claim_current_button: Button = get_node_or_null(claim_current_button_path) as Button
	var claim_all_button: Button = get_node_or_null(claim_all_button_path) as Button
	var veteran_start_button: Button = get_node_or_null(veteran_start_button_path) as Button
	var veteran_opt_out_button: Button = get_node_or_null(veteran_opt_out_button_path) as Button
	var close_button: Button = get_node_or_null(close_button_path) as Button

	if premium_button != null:
		premium_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_set_pass_entitlements"):
				return
			_state.call("intent_set_pass_entitlements", true, false)
		)
	if elite_button != null:
		elite_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_set_pass_entitlements"):
				return
			_state.call("intent_set_pass_entitlements", true, true)
		)
	if claim_current_button != null:
		claim_current_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_claim_reward"):
				return
			var level: int = int(_last_snapshot.get("battle_pass_level", 1))
			_state.call("intent_claim_reward", level, "free")
		)
	if claim_all_button != null:
		claim_all_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_claim_all_available"):
				return
			_state.call("intent_claim_all_available")
		)
	if veteran_start_button != null:
		veteran_start_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_apply_veteran_start"):
				return
			var flags: Dictionary = {
				"member_this_season": true,
				"member_last_season": true,
				"played_every_mode_last_season": true,
				"money_async_last_season": true,
				"money_vs_last_season": true
			}
			_state.call("intent_apply_veteran_start", flags, false)
		)
	if veteran_opt_out_button != null:
		veteran_opt_out_button.pressed.connect(func() -> void:
			if _state == null or not _state.has_method("intent_apply_veteran_start"):
				return
			_state.call("intent_apply_veteran_start", {}, true)
		)
	if close_button != null:
		close_button.pressed.connect(func() -> void:
			close_requested.emit()
		)

func _refresh_from_state() -> void:
	if _state == null:
		return
	if _state.has_method("get_snapshot"):
		var snapshot_any: Variant = _state.call("get_snapshot")
		if typeof(snapshot_any) == TYPE_DICTIONARY:
			_on_state_changed(snapshot_any as Dictionary)

func _on_state_changed(snapshot: Dictionary) -> void:
	_last_snapshot = snapshot.duplicate(true)
	var season_label: Label = get_node_or_null(season_label_path) as Label
	var summary_label: Label = get_node_or_null(summary_label_path) as Label
	var veteran_label: Label = get_node_or_null(veteran_label_path) as Label
	var wallet_label: Label = get_node_or_null(wallet_label_path) as Label
	var levels_text: RichTextLabel = get_node_or_null(levels_text_path) as RichTextLabel
	var quests_text: RichTextLabel = get_node_or_null(quests_text_path) as RichTextLabel
	var premium_button: Button = get_node_or_null(premium_button_path) as Button
	var elite_button: Button = get_node_or_null(elite_button_path) as Button

	if season_label != null:
		var season_id: String = str(snapshot.get("season_id", "season"))
		var remaining_sec: int = int(snapshot.get("season_seconds_remaining", 0))
		var remaining_days: int = int(floor(float(remaining_sec) / 86400.0))
		var projection_any: Variant = snapshot.get("prestige_projection", {})
		var projection: Dictionary = projection_any as Dictionary if typeof(projection_any) == TYPE_DICTIONARY else {}
		var growth_factor: float = float(projection.get("growth_factor", 1.0))
		season_label.text = "Season %s · %dd left · Prestige growth x%.2f" % [season_id, remaining_days, growth_factor]

	if summary_label != null:
		var level: int = int(snapshot.get("battle_pass_level", 1))
		var total_levels: int = int(snapshot.get("total_levels", 120))
		var progress_ratio: float = float(snapshot.get("progress_ratio", 0.0))
		var premium_owned: bool = bool(snapshot.get("premium_owned", false))
		var elite_owned: bool = bool(snapshot.get("elite_owned", false))
		var side_quest_paths: int = int(snapshot.get("side_quest_paths_available", 1))
		var prestige_pool_base: int = int(snapshot.get("prestige_pool_base_slots", 0))
		summary_label.text = "Level %d/%d · Progress %.0f%% · Paths %d · Prestige %d · Premium %s · Elite %s" % [
			level,
			total_levels,
			progress_ratio * 100.0,
			side_quest_paths,
			prestige_pool_base,
			"YES" if premium_owned else "NO",
			"YES" if elite_owned else "NO"
		]

	if veteran_label != null:
		var lock_notice: String = str(snapshot.get("veteran_lock_notice", ""))
		veteran_label.text = lock_notice
		veteran_label.visible = not lock_notice.is_empty()

	if wallet_label != null:
		var wallet_any: Variant = snapshot.get("wallet", {})
		var wallet: Dictionary = wallet_any as Dictionary if typeof(wallet_any) == TYPE_DICTIONARY else {}
		var inventory_any: Variant = snapshot.get("inventory", {})
		var inventory: Dictionary = inventory_any as Dictionary if typeof(inventory_any) == TYPE_DICTIONARY else {}
		wallet_label.text = "Honey %d · Tickets %d" % [
			int(wallet.get("honey", 0)),
			int(inventory.get("access_tickets", 0))
		]

	if levels_text != null:
		levels_text.text = _render_levels(snapshot.get("rows", []) as Array)

	if quests_text != null:
		quests_text.text = _render_quests(snapshot.get("quests", []) as Array, snapshot.get("quest_bonuses", []) as Array)

	if premium_button != null:
		premium_button.disabled = bool(snapshot.get("premium_owned", false))
	if elite_button != null:
		elite_button.disabled = bool(snapshot.get("elite_owned", false))

func _on_pass_event(_event: Dictionary) -> void:
	# State-driven UI: this hook only triggers a full re-render from authoritative snapshot.
	_refresh_from_state()

func _render_levels(rows: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		var level: int = int(row.get("level", 0))
		var scarcity_remaining: int = int(row.get("scarcity_remaining", -1))
		var tracks_any: Variant = row.get("tracks", {})
		var tracks: Dictionary = tracks_any as Dictionary if typeof(tracks_any) == TYPE_DICTIONARY else {}
		var free_state: Dictionary = tracks.get("free", {}) as Dictionary
		var premium_state: Dictionary = tracks.get("premium", {}) as Dictionary
		var elite_state: Dictionary = tracks.get("elite", {}) as Dictionary
		var free_badge: String = _track_badge(free_state)
		var premium_badge: String = _track_badge(premium_state)
		var elite_badge: String = _track_badge(elite_state)
		var scarcity_text: String = ""
		if scarcity_remaining >= 0:
			scarcity_text = " | Slots %d" % scarcity_remaining
		lines.append("L%03d | F:%s P:%s E:%s%s" % [level, free_badge, premium_badge, elite_badge, scarcity_text])
	return "\n".join(lines)

func _render_quests(quests: Array, bonuses: Array) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Quests")
	for quest_any in quests:
		if typeof(quest_any) != TYPE_DICTIONARY:
			continue
		var quest: Dictionary = quest_any as Dictionary
		var quest_id: String = str(quest.get("id", "quest"))
		var path_index: int = int(quest.get("path_index", 0)) + 1
		var progress: int = int(quest.get("progress", 0))
		var target: int = int(quest.get("target", 1))
		var claimed: bool = bool(quest.get("claimed", false))
		lines.append("- P%d %s [%d/%d] %s" % [path_index, quest_id, progress, target, "CLAIMED" if claimed else "OPEN"])
	if not bonuses.is_empty():
		lines.append("Bonuses")
		for bonus_any in bonuses:
			if typeof(bonus_any) != TYPE_DICTIONARY:
				continue
			var bonus: Dictionary = bonus_any as Dictionary
			var bonus_id: String = str(bonus.get("id", "bonus"))
			var bonus_path_index: int = int(bonus.get("path_index", 0)) + 1
			var claimed_bonus: bool = bool(bonus.get("claimed", false))
			var ready_bonus: bool = bool(bonus.get("ready_to_claim", false))
			var status: String = "CLAIMED" if claimed_bonus else ("READY" if ready_bonus else "LOCKED")
			lines.append("- P%d %s [%s]" % [bonus_path_index, bonus_id, status])
	return "\n".join(lines)

func _track_badge(track_state: Dictionary) -> String:
	if track_state.is_empty():
		return "--"
	if bool(track_state.get("claimed", false)):
		return "CLM"
	if bool(track_state.get("claimable", false)):
		return "NOW"
	var reward_type: String = str(track_state.get("reward_type", "none"))
	if reward_type == "none":
		return "--"
	var reason: String = str(track_state.get("locked_reason", ""))
	if reason.is_empty():
		return "LCK"
	return reason
