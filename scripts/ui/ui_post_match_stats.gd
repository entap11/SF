class_name PostMatchStatsPanel
extends VBoxContainer

const UITypography := preload("res://scripts/ui/ui_typography.gd")
const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")

const IN_GAME_TYPE_SCALE: float = 2.5
const TABLE_BREAKPOINT_PX: float = 820.0
const FONT_MAIN: Color = Color(0.96, 0.95, 0.88, 1.0)
const FONT_MUTED: Color = Color(0.82, 0.82, 0.76, 1.0)
const FONT_RESULT: Color = Color(1.0, 0.88, 0.30, 1.0)
const CARD_BG: Color = Color(0.055, 0.06, 0.078, 0.94)

const METRICS: Array[Dictionary] = [
	{"key": "hives_captured", "label": "HIVES CAPTURED"},
	{"key": "units_created", "label": "UNITS CREATED"},
	{"key": "units_landed", "label": "UNITS LANDED"},
	{"key": "swarms_initiated", "label": "SWARMS INITIATED"}
]

var _match_length_label: Label = null
var _stats_header_label: Label = null
var _content: VBoxContainer = null

func _ready() -> void:
	name = "PostMatchStatsPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 15)
	_ensure_ui()
	hide()

func render_stats(snapshot: Dictionary) -> void:
	_ensure_ui()
	var players: Array[Dictionary] = _sorted_players(snapshot.get("players", []))
	if players.is_empty():
		clear_stats()
		return
	_clear_children(_content)
	_match_length_label.text = "MATCH LENGTH   %s" % _format_duration(maxi(0, int(snapshot.get("duration_ms", 0))))
	_stats_header_label.text = "MATCH STATS"
	if players.size() == 2 and _viewport_width() >= TABLE_BREAKPOINT_PX:
		_build_comparison_table(players)
	else:
		_build_player_cards(players)
	show()

func clear_stats() -> void:
	_ensure_ui()
	_clear_children(_content)
	_match_length_label.text = ""
	hide()

func _ensure_ui() -> void:
	if _match_length_label != null and is_instance_valid(_match_length_label):
		return
	_match_length_label = Label.new()
	_match_length_label.name = "MatchLength"
	_style_label(_match_length_label, "panel_subtitle", FONT_RESULT, true)
	add_child(_match_length_label)

	_stats_header_label = Label.new()
	_stats_header_label.name = "MatchStatsHeader"
	_stats_header_label.text = "MATCH STATS"
	_style_label(_stats_header_label, "section_title", FONT_RESULT, true)
	add_child(_stats_header_label)

	_content = VBoxContainer.new()
	_content.name = "StatsContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	add_child(_content)

func _build_comparison_table(players: Array[Dictionary]) -> void:
	var table := GridContainer.new()
	table.name = "PlayerComparisonTable"
	table.columns = 3
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 18)
	table.add_theme_constant_override("v_separation", 8)
	_content.add_child(table)

	var corner := Label.new()
	corner.name = "MetricHeader"
	corner.custom_minimum_size.x = 330.0
	_style_label(corner, "meta", FONT_MUTED, true)
	table.add_child(corner)
	for player in players:
		var header := Label.new()
		header.name = "Player%dHeader" % int(player.get("seat", 0))
		header.text = _player_heading(player)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		header.custom_minimum_size.x = 170.0
		_style_label(header, "panel_subtitle", _player_color(player), true)
		table.add_child(header)

	for metric in METRICS:
		var key: String = str(metric.get("key", ""))
		var metric_label := Label.new()
		metric_label.name = "Metric_%s" % key
		metric_label.text = str(metric.get("label", ""))
		_style_label(metric_label, "meta", FONT_MAIN, true)
		table.add_child(metric_label)
		for player in players:
			var value := Label.new()
			value.name = "Player%d_%s" % [int(player.get("seat", 0)), key]
			value.text = str(maxi(0, int(player.get(key, 0))))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_style_label(value, "body", FONT_MAIN, true)
			table.add_child(value)

func _build_player_cards(players: Array[Dictionary]) -> void:
	var cards := VBoxContainer.new()
	cards.name = "PlayerCards"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 12)
	_content.add_child(cards)
	for player in players:
		cards.add_child(_build_player_card(player))

func _build_player_card(player: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Player%dCard" % int(player.get("seat", 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent: Color = _player_color(player)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_top = 12.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", style)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	card.add_child(body)

	var heading := Label.new()
	heading.name = "PlayerHeading"
	heading.text = _player_heading(player)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label(heading, "panel_subtitle", accent, true)
	body.add_child(heading)

	var first_row := Label.new()
	first_row.name = "PrimaryMetrics"
	first_row.text = "HIVES %d   •   CREATED %d" % [
		maxi(0, int(player.get("hives_captured", 0))),
		maxi(0, int(player.get("units_created", 0)))
	]
	_style_label(first_row, "meta", FONT_MAIN, true)
	body.add_child(first_row)

	var second_row := Label.new()
	second_row.name = "SecondaryMetrics"
	second_row.text = "LANDED %d   •   SWARMS %d" % [
		maxi(0, int(player.get("units_landed", 0))),
		maxi(0, int(player.get("swarms_initiated", 0)))
	]
	_style_label(second_row, "meta", FONT_MAIN, true)
	body.add_child(second_row)
	return card

func _sorted_players(players_any: Variant) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	if typeof(players_any) != TYPE_ARRAY:
		return players
	for player_any in players_any as Array:
		if typeof(player_any) != TYPE_DICTIONARY:
			continue
		var player: Dictionary = (player_any as Dictionary).duplicate(true)
		if int(player.get("seat", 0)) <= 0:
			continue
		players.append(player)
	players.sort_custom(_player_order_less)
	return players

func _player_order_less(a: Dictionary, b: Dictionary) -> bool:
	var a_local: bool = bool(a.get("is_local", false))
	var b_local: bool = bool(b.get("is_local", false))
	if a_local != b_local:
		return a_local
	var a_winner: bool = bool(a.get("is_winner", false))
	var b_winner: bool = bool(b.get("is_winner", false))
	if a_winner != b_winner:
		return a_winner
	return int(a.get("seat", 0)) < int(b.get("seat", 0))

func _player_heading(player: Dictionary) -> String:
	var heading: String = "YOU" if bool(player.get("is_local", false)) else str(player.get("display_name", "Player %d" % int(player.get("seat", 0)))).strip_edges()
	if heading.is_empty():
		heading = "PLAYER %d" % int(player.get("seat", 0))
	if bool(player.get("is_winner", false)):
		heading += "  • WINNER"
	return heading

func _player_color(player: Dictionary) -> Color:
	return TeamVisuals.owner_color(maxi(1, int(player.get("team_id", player.get("seat", 1)))))

func _format_duration(duration_ms: int) -> String:
	var total_seconds: int = maxi(0, duration_ms) / 1000
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _viewport_width() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return TABLE_BREAKPOINT_PX
	return viewport.get_visible_rect().size.x

func _style_label(label: Label, type_role: String, color: Color, semibold: bool = false) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font: Font = UITypography.semibold_font() if semibold else UITypography.regular_font()
	UITypography.apply_token(label, font, type_role, IN_GAME_TYPE_SCALE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
