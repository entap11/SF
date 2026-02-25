class_name PostMatchSummaryPanel
extends VBoxContainer

var _header_label: Label = null
var _outcome_label: Label = null
var _insights_header_label: Label = null
var _insights_list: VBoxContainer = null
var _stats_header_label: Label = null
var _stats_list: VBoxContainer = null

func _ready() -> void:
	name = "PostMatchSummaryPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_ensure_ui()
	hide()

func render_summary(summary: Dictionary, victory: bool) -> void:
	_ensure_ui()
	show()
	_header_label.text = "GAME ANALYZER"
	_outcome_label.text = "Outcome: VICTORY" if victory else "Outcome: DEFEAT"
	_clear_children(_insights_list)
	_clear_children(_stats_list)

	var insights_any: Variant = summary.get("insights", [])
	if typeof(insights_any) == TYPE_ARRAY:
		for insight_any in insights_any as Array:
			var text: String = str(insight_any).strip_edges()
			if text.is_empty():
				continue
			var label: Label = Label.new()
			label.text = "• %s" % text
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_insights_list.add_child(label)

	var key_stats_any: Variant = summary.get("key_stats", [])
	if typeof(key_stats_any) == TYPE_ARRAY:
		for stat_any in key_stats_any as Array:
			if typeof(stat_any) != TYPE_DICTIONARY:
				continue
			var stat: Dictionary = stat_any as Dictionary
			var label_text: String = str(stat.get("label", "")).strip_edges()
			var value_text: String = str(stat.get("value", "")).strip_edges()
			if label_text.is_empty():
				continue
			var row: Label = Label.new()
			row.text = "%s: %s" % [label_text, value_text]
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_stats_list.add_child(row)

	if _insights_list.get_child_count() == 0:
		var fallback: Label = Label.new()
		fallback.text = "• No analyzer insights for this match."
		_insights_list.add_child(fallback)
	if _stats_list.get_child_count() == 0:
		var fallback_stat: Label = Label.new()
		fallback_stat.text = "No key stats available."
		_stats_list.add_child(fallback_stat)

func clear_summary() -> void:
	_ensure_ui()
	_clear_children(_insights_list)
	_clear_children(_stats_list)
	hide()

func _ensure_ui() -> void:
	if _header_label != null and is_instance_valid(_header_label):
		return
	_header_label = Label.new()
	_header_label.text = "GAME ANALYZER"
	add_child(_header_label)

	_outcome_label = Label.new()
	_outcome_label.text = "Outcome: --"
	add_child(_outcome_label)

	_insights_header_label = Label.new()
	_insights_header_label.text = "Key Insights"
	add_child(_insights_header_label)

	_insights_list = VBoxContainer.new()
	_insights_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_insights_list.add_theme_constant_override("separation", 3)
	add_child(_insights_list)

	_stats_header_label = Label.new()
	_stats_header_label.text = "Key Stats"
	add_child(_stats_header_label)

	_stats_list = VBoxContainer.new()
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("separation", 2)
	add_child(_stats_list)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
