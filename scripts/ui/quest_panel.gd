extends PanelContainer
## Read-only server projection; buttons send claim intents. No local quest awards.

@export var backend_path: NodePath = NodePath("/root/VsHandshake")
@export var identity_path: NodePath = NodePath("/root/PlayerIdentityRuntime")
var snapshot: Dictionary = {}
var _rows: VBoxContainer
var _status: Label
var _bonus: Label
var _busy: bool = false

func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.04, 0.055, 1.0)
	add_theme_stylebox_override("panel", background)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Daily & Weekly Quests"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.custom_minimum_size.y = 48
	refresh.pressed.connect(refresh_quests)
	actions.add_child(refresh)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 48
	close.pressed.connect(queue_free)
	actions.add_child(close)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_bonus = Label.new()
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_bonus)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 12)
	scroll.add_child(_rows)
	call_deferred("refresh_quests")

func refresh_quests() -> void:
	if _busy:
		return
	_busy = true
	var backend: Node = get_node_or_null(backend_path)
	var result: Dictionary = {"ok": false, "err": "connection_unavailable"}
	if backend != null and backend.has_method("get_quests"):
		result = backend.call("get_quests") as Dictionary
	_busy = false
	if not bool(result.get("ok", false)):
		snapshot = {}
		_render()
		_status.text = "Quests unavailable. Refresh to try again. (%s)" % str(result.get("err", "connection_failed"))
		return
	snapshot = result.duplicate(true)
	_render()

func claim_quest(quest: Dictionary) -> void:
	if _busy or not bool(quest.get("ready_to_claim", false)) or snapshot.is_empty():
		return
	_busy = true
	var epoch: String = str(snapshot.get("epoch_id", ""))
	var quest_id: String = str(quest.get("quest_id", ""))
	var cycle: String = str(quest.get("cycle_start", ""))
	# Stable across retries/restarts; the service also binds the intent to the authenticated player.
	var request_id: String = "quest-" + (epoch + ":" + quest_id + ":" + cycle).sha256_text()
	var backend: Node = get_node_or_null(backend_path)
	var result: Dictionary = {"ok": false, "err": "connection_unavailable"}
	if backend != null and backend.has_method("claim_quest"):
		result = backend.call("claim_quest", {"epoch_id": epoch, "quest_id": quest_id,
			"cycle_start": cycle, "request_id": request_id, "player_id": str(snapshot.get("player_id", ""))}) as Dictionary
	_busy = false
	if not bool(result.get("ok", false)):
		_status.text = "Claim not confirmed. Refresh or retry. (%s)" % str(result.get("err", "connection_failed"))
		return
	# Fetch the current wallet projection; an idempotent claim receipt can contain an older balance.
	var identity: Node = get_node_or_null(identity_path)
	if identity != null and identity.has_method("refresh_platform_snapshot"):
		identity.call("refresh_platform_snapshot")
	refresh_quests()
	_status.text = "Reward claimed."

func _render() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_bonus.text = ""
	if not bool(snapshot.get("enabled", false)):
		_status.text = "Quests are not available yet."
		return
	_status.text = "Progress comes from completed, verified games. Claim before the reset."
	var bonus: Dictionary = snapshot.get("weekly_bonus", {}) as Dictionary
	if bool(bonus.get("eligible", false)):
		_bonus.text = "Full-week bonus: %d/%d rewards claimed. +10%% quest Honey%s" % [
			int(bonus.get("claimed_count", 0)), int(bonus.get("expected_count", 25)),
			" — awarded!" if bool(bonus.get("awarded", false)) else " when all are claimed."]
	else:
		_bonus.text = "The full-week bonus starts with the next complete quest week."
	for cadence in ["DAILY", "WEEKLY"]:
		var heading := Label.new()
		heading.text = "Daily quests" if cadence == "DAILY" else "Weekly quests"
		heading.add_theme_font_size_override("font_size", 24)
		_rows.add_child(heading)
		for value in snapshot.get("quests", []):
			var quest: Dictionary = value as Dictionary
			if str(quest.get("cadence", "")) != cadence:
				continue
			_add_quest(quest)

func _add_quest(quest: Dictionary) -> void:
	var card := VBoxContainer.new()
	_rows.add_child(card)
	var title := Label.new()
	title.text = str(quest.get("title", "Quest"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	for value in quest.get("objectives", []):
		var objective: Dictionary = value as Dictionary
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.text = "%s: %d / %d" % [str(objective.get("label", objective.get("id", ""))),
			int(objective.get("progress", 0)), int(objective.get("target", 0))]
		card.add_child(line)
	var reward: Dictionary = quest.get("reward", {}) as Dictionary
	var details := Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.text = "%.2f Honey + %.0f Nectar · Resets %s UTC" % [float(reward.get("honey_centi", 0)) / 100.0,
		float(reward.get("nectar_milli", 0)) / 1000.0, str(quest.get("cycle_end", "")).replace("T", " ").left(16)]
	card.add_child(details)
	var claim := Button.new()
	claim.text = "Claimed" if bool(quest.get("claimed", false)) else "Claim reward"
	claim.disabled = not bool(quest.get("ready_to_claim", false))
	claim.custom_minimum_size.y = 48
	claim.pressed.connect(func() -> void: claim_quest(quest))
	card.add_child(claim)
