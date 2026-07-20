extends Panel

signal close_requested()
signal intent_filter_changed(filter_name: String)

@onready var title_label: Label = $Root/VBox/Title
@onready var player_label: Label = $Root/VBox/PlayerSummary
@onready var tier_label: Label = $Root/VBox/TierSummary
@onready var gap_label: Label = $Root/VBox/GapSummary
@onready var filter_row: HBoxContainer = $Root/VBox/FilterRow
@onready var global_button: Button = $Root/VBox/FilterRow/GlobalButton
@onready var region_button: Button = $Root/VBox/FilterRow/RegionButton
@onready var friends_button: Button = $Root/VBox/FilterRow/FriendsButton
@onready var close_button: Button = $Root/VBox/FilterRow/CloseButton
@onready var leaderboard_text: RichTextLabel = $Root/VBox/LeaderboardScroll/LeaderboardText

var _selected_filter: String = "GLOBAL"

func _ready() -> void:
	title_label.text = "Rank / Leaderboard"
	global_button.pressed.connect(func() -> void:
		_on_filter_pressed("GLOBAL")
	)
	region_button.pressed.connect(func() -> void:
		_on_filter_pressed("REGION")
	)
	friends_button.pressed.connect(func() -> void:
		_on_filter_pressed("FRIENDS")
	)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	var state_node: Node = _rank_state()
	if state_node != null and state_node.rank_state_changed.is_connected(_on_rank_state_changed) == false:
		state_node.rank_state_changed.connect(_on_rank_state_changed)
	_refresh_from_state()

func _exit_tree() -> void:
	var state_node: Node = _rank_state()
	if state_node != null and state_node.rank_state_changed.is_connected(_on_rank_state_changed):
		state_node.rank_state_changed.disconnect(_on_rank_state_changed)

func _on_rank_state_changed(_snapshot: Dictionary) -> void:
	_refresh_from_state()

func _on_filter_pressed(filter_name: String) -> void:
	_selected_filter = filter_name
	intent_filter_changed.emit(filter_name)
	_refresh_from_state()

func _refresh_from_state() -> void:
	if _selected_filter == "GLOBAL":
		var vs_state: Node = get_node_or_null("/root/VsHandshakeState")
		if vs_state != null and vs_state.has_method("get_public_global_rank"):
			var result: Dictionary = vs_state.call("get_public_global_rank", 25) as Dictionary
			if bool(result.get("ok", false)) and typeof(result.get("board", null)) == TYPE_DICTIONARY:
				_render_public_global(result.get("board", {}) as Dictionary)
				return
		_render_public_global_unavailable()
		return
	var state_node: Node = _rank_state()
	if state_node == null:
		player_label.text = "RankState missing"
		tier_label.text = ""
		gap_label.text = ""
		leaderboard_text.text = ""
		return
	var view: Dictionary = state_node.get_local_rank_view(_selected_filter, 25)
	_render(view)

func _render_public_global(board: Dictionary) -> void:
	var stale: bool = bool(board.get("stale", false))
	var cache_age_seconds: int = maxi(0, int(board.get("cache_age_seconds", 0)))
	player_label.text = "Global Rank · shared server board"
	tier_label.text = "Cached server snapshot" if stale else "Live server data"
	var generated_at: String = str(board.get("generated_at", "")).strip_edges()
	if stale:
		gap_label.text = "Snapshot age: %d seconds%s" % [cache_age_seconds, " · %s" % generated_at if not generated_at.is_empty() else ""]
	else:
		gap_label.text = "Updated %s" % generated_at if not generated_at.is_empty() else "Updated now"
	_render_rows(board.get("rows", []))

func _render_public_global_unavailable() -> void:
	player_label.text = "Global Rank unavailable."
	tier_label.text = "No shared server snapshot is available."
	gap_label.text = "Local device data is not substituted for public standings."
	leaderboard_text.text = ""

func _render(view: Dictionary) -> void:
	var player: Dictionary = view.get("player", {}) as Dictionary
	if player.is_empty():
		player_label.text = "No local player rank data."
		tier_label.text = ""
		gap_label.text = ""
		leaderboard_text.text = ""
		return
	var rank_position: int = int(player.get("rank_position", 0))
	var percentile: float = float(player.get("percentile", 0.0)) * 100.0
	var wax_score: float = float(player.get("wax_score", 0.0))
	player_label.text = "Player %s · Rank #%d · Wax %.1f" % [str(player.get("display_name", "Player")), rank_position, wax_score]
	tier_label.text = "%s %s · Percentile %.2f%%" % [str(player.get("color_id", "GREEN")), str(player.get("tier_id", "DRONE")), percentile]
	var local_context: Dictionary = view.get("local_context", {}) as Dictionary
	var wax_gap: float = float(local_context.get("wax_gap_to_next_player", 0.0))
	var places_to_next_tier: int = int(local_context.get("places_to_next_tier", 0))
	gap_label.text = "Gap to next player: %.1f wax · Places to next tier: %d" % [wax_gap, places_to_next_tier]

	_render_rows(view.get("rows", []))

func _render_rows(rows_any: Variant) -> void:
	if typeof(rows_any) != TYPE_ARRAY:
		leaderboard_text.text = ""
		return
	var rows: Array = rows_any as Array
	var lines: PackedStringArray = PackedStringArray()
	for row_any in rows:
		if typeof(row_any) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_any as Dictionary
		lines.append(
			"#%d  %s  %.1f  %s %s  (%.2f%%)"
			% [
				int(row.get("rank_global", 0)),
				str(row.get("display_name", "Player")),
				float(row.get("wax_score", 0.0)),
				str(row.get("color_id", "GREEN")),
				str(row.get("tier_id", "DRONE")),
				float(row.get("percentile", 0.0)) * 100.0
			]
		)
	leaderboard_text.text = "\n".join(lines)

func _rank_state() -> Node:
	return get_node_or_null("/root/RankState")
