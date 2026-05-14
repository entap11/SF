class_name TelemetryDashboardPanel
extends Panel

signal close_requested()

const MATCHES_DIR: String = "user://matches"
const PROFILE_PATH: String = "user://player_telemetry_profiles_v1.json"

var _include_smoke: bool = false
var _profiles: Array[Dictionary] = []
var _matches: Array[Dictionary] = []
var _summary: Dictionary = {}

var _summary_label: Label = null
var _profile_list: ItemList = null
var _trend_text: RichTextLabel = null
var _detail_text: RichTextLabel = null
var _include_smoke_toggle: CheckButton = null

func _ready() -> void:
	_build_ui()
	refresh_data(false)

func refresh_data(include_smoke: bool = false) -> void:
	_include_smoke = include_smoke
	if _include_smoke_toggle != null:
		_include_smoke_toggle.button_pressed = _include_smoke
	var profile_store: Dictionary = _load_json_dict(PROFILE_PATH)
	var players_by_id: Dictionary = _dict(profile_store.get("players", {}))
	if not _include_smoke:
		players_by_id = _filtered_profiles(players_by_id)
	_profiles = _profile_rows(players_by_id)
	_matches = _load_match_payloads()
	if not _include_smoke:
		_matches = _filtered_matches(_matches)
	_summary = _build_summary(_profiles, _matches)
	_render()

func get_dashboard_snapshot() -> Dictionary:
	return {
		"profiles": _profiles.duplicate(true),
		"matches": _matches.duplicate(true),
		"summary": _summary.duplicate(true)
	}

func get_profile_count() -> int:
	return _profiles.size()

func _build_ui() -> void:
	custom_minimum_size = Vector2(900, 680)
	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var title := Label.new()
	title.name = "Title"
	title.text = "TELEMETRY DASHBOARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "REFRESH"
	refresh_button.custom_minimum_size = Vector2(132, 44)
	refresh_button.pressed.connect(func() -> void:
		refresh_data(_include_smoke)
	)
	header.add_child(refresh_button)

	_include_smoke_toggle = CheckButton.new()
	_include_smoke_toggle.name = "IncludeSmokeToggle"
	_include_smoke_toggle.text = "SMOKE"
	_include_smoke_toggle.custom_minimum_size = Vector2(116, 44)
	_include_smoke_toggle.toggled.connect(func(enabled: bool) -> void:
		refresh_data(enabled)
	)
	header.add_child(_include_smoke_toggle)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(116, 44)
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	header.add_child(close_button)

	_summary_label = Label.new()
	_summary_label.name = "Summary"
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_summary_label)

	var split := HSplitContainer.new()
	split.name = "Body"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	var left := VBoxContainer.new()
	left.name = "PlayersPane"
	left.custom_minimum_size = Vector2(315, 0)
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)

	var players_title := Label.new()
	players_title.text = "PLAYERS"
	players_title.add_theme_font_size_override("font_size", 18)
	left.add_child(players_title)

	_profile_list = ItemList.new()
	_profile_list.name = "ProfileList"
	_profile_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_list.item_selected.connect(_on_profile_selected)
	left.add_child(_profile_list)

	var right := VBoxContainer.new()
	right.name = "DetailPane"
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)

	var trend_title := Label.new()
	trend_title.text = "AGGREGATE TRENDS"
	trend_title.add_theme_font_size_override("font_size", 18)
	right.add_child(trend_title)

	_trend_text = RichTextLabel.new()
	_trend_text.name = "TrendText"
	_trend_text.bbcode_enabled = false
	_trend_text.fit_content = false
	_trend_text.custom_minimum_size = Vector2(0, 172)
	right.add_child(_trend_text)

	var detail_title := Label.new()
	detail_title.text = "PLAYER DETAIL"
	detail_title.add_theme_font_size_override("font_size", 18)
	right.add_child(detail_title)

	_detail_text = RichTextLabel.new()
	_detail_text.name = "DetailText"
	_detail_text.bbcode_enabled = false
	_detail_text.fit_content = false
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail_text)

func _render() -> void:
	if _summary_label != null:
		_summary_label.text = "Matches: %d | Schema 5: %d | Style-ready: %d | Human profiles: %d | Modes: %s" % [
			int(_summary.get("matches_found", 0)),
			int(_summary.get("schema5_matches", 0)),
			int(_summary.get("style_ready_matches", 0)),
			_profiles.size(),
			_format_dict(_summary.get("modes", {}))
		]
	if _profile_list != null:
		_profile_list.clear()
		for i in range(_profiles.size()):
			var profile: Dictionary = _profiles[i]
			_profile_list.add_item("%s  |  %d matches  |  A %.2f  D %.2f" % [
				_profile_name(profile),
				int(profile.get("match_count", 0)),
				float(profile.get("aggression", 0.0)),
				float(profile.get("defense_bias", 0.0))
			])
			_profile_list.set_item_metadata(i, i)
	if _trend_text != null:
		_trend_text.text = _trend_lines()
	if _detail_text != null:
		if _profiles.is_empty():
			_detail_text.text = "No schema-5 human profiles yet. Run PvP on the TestFlight build, finish a match, then refresh."
		else:
			if _profile_list != null:
				_profile_list.select(0)
			_render_profile_detail(0)

func _trend_lines() -> String:
	if _profiles.is_empty():
		return "No human telemetry profiles available yet.\nAfter the phone test, this will show tester averages and outliers."
	var avg_reaction: float = _average_metric(_profiles, "reaction_delay_s")
	var avg_aggression: float = _average_metric(_profiles, "aggression")
	var avg_defense: float = _average_metric(_profiles, "defense_bias")
	var avg_expansion: float = _average_metric(_profiles, "expansion_bias")
	var avg_risk: float = _average_metric(_profiles, "risk_tolerance")
	var avg_lane: float = _average_metric(_profiles, "lane_efficiency")
	return "\n".join([
		"Average reaction delay: %.2fs" % avg_reaction,
		"Average aggression %.2f | defense %.2f | expansion %.2f | risk %.2f | lane efficiency %.2f" % [avg_aggression, avg_defense, avg_expansion, avg_risk, avg_lane],
		"Most aggressive: %s" % _top_profile_label("aggression", true),
		"Most defensive: %s" % _top_profile_label("defense_bias", true),
		"Lowest lane efficiency: %s" % _top_profile_label("lane_efficiency", false),
		"Mode coverage: %s" % _format_dict(_summary.get("modes", {}))
	])

func _on_profile_selected(index: int) -> void:
	_render_profile_detail(index)

func _render_profile_detail(index: int) -> void:
	if _detail_text == null:
		return
	if index < 0 or index >= _profiles.size():
		_detail_text.text = ""
		return
	var profile: Dictionary = _profiles[index]
	var lines: Array[String] = []
	lines.append("Player: %s" % _profile_name(profile))
	lines.append("ID: %s" % str(profile.get("player_id", "")))
	lines.append("Matches: %d" % int(profile.get("match_count", 0)))
	lines.append("Modes: %s" % _format_dict(profile.get("modes", {})))
	lines.append("")
	lines.append("Reaction delay: %.2fs" % float(profile.get("reaction_delay_s", 0.0)))
	lines.append("Aggression: %.2f" % float(profile.get("aggression", 0.0)))
	lines.append("Defense bias: %.2f" % float(profile.get("defense_bias", 0.0)))
	lines.append("Expansion bias: %.2f" % float(profile.get("expansion_bias", 0.0)))
	lines.append("Risk tolerance: %.2f" % float(profile.get("risk_tolerance", 0.0)))
	lines.append("Swarm preference: %.2f" % float(profile.get("swarm_preference", 0.0)))
	lines.append("Lane efficiency: %.2f" % float(profile.get("lane_efficiency", 0.0)))
	lines.append("")
	lines.append("Recent matches:")
	var recent: Array = _array(profile.get("recent_matches", []))
	recent.reverse()
	var count: int = 0
	for entry_any in recent:
		if count >= 8:
			break
		var entry: Dictionary = _dict(entry_any)
		lines.append("- %s | %s | won=%s | reaction=%.2fs | apm=%.1f | intents=%d/%d fail" % [
			str(entry.get("match_id", "")),
			str(entry.get("vs_mode", "")),
			str(bool(entry.get("won", false))),
			float(entry.get("reaction_time_s", 0.0)),
			float(entry.get("meaningful_apm", 0.0)),
			int(entry.get("intent_total", 0)),
			int(entry.get("intent_fail", 0))
		])
		count += 1
	if count == 0:
		lines.append("- No recent match rows.")
	_detail_text.text = "\n".join(lines)

func _build_summary(profiles: Array[Dictionary], matches: Array[Dictionary]) -> Dictionary:
	var modes: Dictionary = {}
	var schema5: int = 0
	var style_ready: int = 0
	for payload in matches:
		var schema_version: int = int(payload.get("schema_version", 0))
		if schema_version >= 5:
			schema5 += 1
		var metadata: Dictionary = _dict(payload.get("metadata", {}))
		var mode: String = str(metadata.get("vs_mode", "")).strip_edges()
		if mode.is_empty():
			mode = "UNKNOWN"
		modes[mode] = int(modes.get(mode, 0)) + 1
		var metrics: Dictionary = _dict(payload.get("metrics", {}))
		if not _array(metrics.get("style_features_by_player", [])).is_empty():
			style_ready += 1
	for profile in profiles:
		var profile_modes: Dictionary = _dict(profile.get("modes", {}))
		for mode_any in profile_modes.keys():
			var mode_key: String = str(mode_any)
			if modes.has(mode_key):
				continue
			modes[mode_key] = int(_dict(profile_modes.get(mode_any, {})).get("matches", 0))
	return {
		"matches_found": matches.size(),
		"schema5_matches": schema5,
		"style_ready_matches": style_ready,
		"modes": modes
	}

func _profile_rows(players_by_id: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player_id_any in players_by_id.keys():
		var player_id: String = str(player_id_any)
		var profile: Dictionary = _dict(players_by_id.get(player_id, {}))
		var style: Dictionary = _dict(profile.get("rolling_style_features", {}))
		var knobs: Dictionary = _dict(profile.get("bot_profile_knobs", {}))
		rows.append({
			"player_id": player_id,
			"display_name": str(profile.get("display_name", "")),
			"match_count": int(profile.get("match_count", 0)),
			"modes": _dict(profile.get("modes", {})).duplicate(true),
			"recent_matches": _array(profile.get("recent_matches", [])).duplicate(true),
			"reaction_delay_s": float(knobs.get("reaction_delay_s", 0.0)),
			"aggression": float(style.get("aggression", 0.0)),
			"defense_bias": float(style.get("defense_bias", 0.0)),
			"expansion_bias": float(style.get("expansion_bias", 0.0)),
			"risk_tolerance": float(style.get("risk_tolerance", 0.0)),
			"swarm_preference": float(style.get("swarm_preference", 0.0)),
			"lane_efficiency": float(style.get("lane_efficiency", 0.0)),
			"last_seen_utc_ms": int(profile.get("last_seen_utc_ms", 0))
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var seen_a: int = int(a.get("last_seen_utc_ms", 0))
		var seen_b: int = int(b.get("last_seen_utc_ms", 0))
		if seen_a != seen_b:
			return seen_a > seen_b
		return str(a.get("player_id", "")) < str(b.get("player_id", ""))
	)
	return rows

func _load_match_payloads() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(MATCHES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue
		var payload: Dictionary = _load_json_dict("%s/%s" % [MATCHES_DIR, file_name])
		if not payload.is_empty():
			out.append(payload)
	dir.list_dir_end()
	return out

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary

func _filtered_profiles(players_by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for player_id_any in players_by_id.keys():
		var player_id: String = str(player_id_any)
		if _is_smoke_player_id(player_id):
			continue
		out[player_id] = players_by_id.get(player_id_any)
	return out

func _filtered_matches(matches: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for payload in matches:
		if _is_smoke_match(payload):
			continue
		out.append(payload)
	return out

func _is_smoke_match(payload: Dictionary) -> bool:
	var metadata: Dictionary = _dict(payload.get("metadata", {}))
	var match_id: String = str(metadata.get("match_id", "")).strip_edges().to_lower()
	if match_id.begins_with("smoke") or match_id.begins_with("report_smoke") or match_id.begins_with("dashboard_smoke"):
		return true
	for player_any in _array(metadata.get("players", [])):
		var player: Dictionary = _dict(player_any)
		if _is_smoke_player_id(str(player.get("player_id", ""))):
			return true
	return false

func _is_smoke_player_id(player_id: String) -> bool:
	var clean_id: String = player_id.strip_edges().to_lower()
	return clean_id.begins_with("u_smoke_") or clean_id.begins_with("u_report_smoke_") or clean_id.begins_with("u_dashboard_smoke_")

func _average_metric(profiles: Array[Dictionary], key: String) -> float:
	if profiles.is_empty():
		return 0.0
	var total: float = 0.0
	for profile in profiles:
		total += float(profile.get(key, 0.0))
	return total / float(profiles.size())

func _top_profile_label(key: String, high: bool) -> String:
	if _profiles.is_empty():
		return "none"
	var best: Dictionary = _profiles[0]
	var best_value: float = float(best.get(key, 0.0))
	for profile in _profiles:
		var value: float = float(profile.get(key, 0.0))
		if (high and value > best_value) or ((not high) and value < best_value):
			best = profile
			best_value = value
	return "%s %.2f" % [_profile_name(best), best_value]

func _profile_name(profile: Dictionary) -> String:
	var display_name: String = str(profile.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		return display_name
	return str(profile.get("player_id", "unknown"))

func _format_dict(raw: Variant) -> String:
	var data: Dictionary = _dict(raw)
	if data.is_empty():
		return "{}"
	var keys: Array = data.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_any in keys:
		parts.append("%s:%s" % [str(key_any), str(data.get(key_any))])
	return "{%s}" % ", ".join(parts)

func _dict(raw: Variant) -> Dictionary:
	return raw as Dictionary if typeof(raw) == TYPE_DICTIONARY else {}

func _array(raw: Variant) -> Array:
	return raw as Array if typeof(raw) == TYPE_ARRAY else []
