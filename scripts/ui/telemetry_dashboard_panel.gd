class_name TelemetryDashboardPanel
extends Panel

signal close_requested()

const MATCHES_DIR: String = "user://matches"
const EXPORTS_DIR: String = "user://exports"
const PROFILE_PATH: String = "user://player_telemetry_profiles_v1.json"
const DEFAULT_EXPORT_MATCH_LIMIT: int = 20

var _include_smoke: bool = false
var _profiles: Array[Dictionary] = []
var _matches: Array[Dictionary] = []
var _summary: Dictionary = {}
@export var export_match_limit: int = DEFAULT_EXPORT_MATCH_LIMIT

var _summary_label: Label = null
var _export_status_label: Label = null
var _perf_summary_text: RichTextLabel = null
var _profile_list: ItemList = null
var _trend_text: RichTextLabel = null
var _detail_text: RichTextLabel = null
var _include_smoke_toggle: CheckButton = null
var _last_export_path: String = ""

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

func get_last_export_path() -> String:
	return _last_export_path

func export_debug_bundle(limit: int = -1) -> Dictionary:
	var safe_limit: int = export_match_limit if limit <= 0 else limit
	safe_limit = maxi(1, safe_limit)
	var entries: Array[Dictionary] = _load_recent_match_entries(safe_limit, _include_smoke)
	var match_exports: Array = []
	for entry in entries:
		var payload: Dictionary = _dict(entry.get("payload", {}))
		var metadata: Dictionary = _dict(payload.get("metadata", {}))
		var runtime_perf: Dictionary = _dict(payload.get("runtime_perf", {}))
		match_exports.append({
			"file_name": str(entry.get("file_name", "")),
			"path": str(entry.get("path", "")),
			"modified_unix": int(entry.get("modified_unix", 0)),
			"schema_version": int(payload.get("schema_version", 0)),
			"match_id": str(metadata.get("match_id", "")),
			"map_id": str(metadata.get("map_id", "")),
			"vs_mode": str(metadata.get("vs_mode", "")),
			"runtime_perf": {
				"summary": _dict(runtime_perf.get("summary", {})).duplicate(true),
				"samples": _array(runtime_perf.get("samples", [])).duplicate(true)
			},
			"payload": payload.duplicate(true)
		})
	var runtime_rows: Array[Dictionary] = _runtime_perf_rows_for_entries(entries)
	var bundle: Dictionary = {
		"schema_version": 1,
		"exported_utc_ms": _utc_ms_now(),
		"exported_unix": int(Time.get_unix_time_from_system()),
		"export_match_limit": safe_limit,
		"include_smoke": _include_smoke,
		"device": _device_info(),
		"app": _app_info(),
		"backend": _backend_info(),
		"summary": _runtime_summary_from_rows(runtime_rows),
		"matches": match_exports
	}
	var mk_err: int = DirAccess.make_dir_recursive_absolute(EXPORTS_DIR)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": "mkdir_failed", "code": mk_err}
	var path: String = "%s/swarmfront_debug_bundle_%d.json" % [EXPORTS_DIR, _utc_ms_now()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_failed", "path": path}
	file.store_string(JSON.stringify(bundle, "\t"))
	file.close()
	_last_export_path = path
	return {
		"ok": true,
		"path": path,
		"global_path": ProjectSettings.globalize_path(path),
		"match_count": match_exports.size(),
		"summary": bundle.get("summary", {})
	}

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

	var export_button := Button.new()
	export_button.name = "ExportDebugBundleButton"
	export_button.text = "EXPORT DEBUG"
	export_button.custom_minimum_size = Vector2(178, 44)
	export_button.pressed.connect(_on_export_debug_bundle_pressed)
	header.add_child(export_button)

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

	_export_status_label = Label.new()
	_export_status_label.name = "ExportStatus"
	_export_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_export_status_label.add_theme_font_size_override("font_size", 13)
	_export_status_label.add_theme_color_override("font_color", Color(0.74, 0.86, 0.96, 1.0))
	vbox.add_child(_export_status_label)

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

	var perf_title := Label.new()
	perf_title.text = "RUNTIME SUMMARY"
	perf_title.add_theme_font_size_override("font_size", 18)
	right.add_child(perf_title)

	_perf_summary_text = RichTextLabel.new()
	_perf_summary_text.name = "RuntimeSummaryText"
	_perf_summary_text.bbcode_enabled = false
	_perf_summary_text.fit_content = false
	_perf_summary_text.custom_minimum_size = Vector2(0, 190)
	right.add_child(_perf_summary_text)

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
		_summary_label.text = "Matches: %d | Schema 5: %d | Style-ready: %d | Perf: %d | Human profiles: %d | Modes: %s" % [
			int(_summary.get("matches_found", 0)),
			int(_summary.get("schema5_matches", 0)),
			int(_summary.get("style_ready_matches", 0)),
			int(_summary.get("runtime_perf_matches", 0)),
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
	if _perf_summary_text != null:
		_perf_summary_text.text = _runtime_summary_lines(_summary)
	if _detail_text != null:
		if _profiles.is_empty():
			_detail_text.text = "No schema-5 human profiles yet. Run PvP on the TestFlight build, finish a match, then refresh."
		else:
			if _profile_list != null:
				_profile_list.select(0)
			_render_profile_detail(0)

func _on_export_debug_bundle_pressed() -> void:
	var result: Dictionary = export_debug_bundle(export_match_limit)
	if _export_status_label == null:
		return
	if bool(result.get("ok", false)):
		_export_status_label.text = "Exported %d matches: %s" % [
			int(result.get("match_count", 0)),
			str(result.get("global_path", result.get("path", "")))
		]
	else:
		_export_status_label.text = "Export failed: %s" % str(result)

func _trend_lines() -> String:
	if _profiles.is_empty():
		return "No human telemetry profiles available yet.\nRuntime perf matches: %d | FPS %.1f | RTT %.1fms | drops %d" % [
			int(_summary.get("runtime_perf_matches", 0)),
			float(_summary.get("avg_runtime_fps", 0.0)),
			float(_summary.get("avg_runtime_rtt_ms", 0.0)),
			int(_summary.get("runtime_packet_dropped", 0))
		]
	var avg_reaction: float = _average_metric(_profiles, "reaction_delay_s")
	var avg_aggression: float = _average_metric(_profiles, "aggression")
	var avg_defense: float = _average_metric(_profiles, "defense_bias")
	var avg_expansion: float = _average_metric(_profiles, "expansion_bias")
	var avg_risk: float = _average_metric(_profiles, "risk_tolerance")
	var avg_lane: float = _average_metric(_profiles, "lane_efficiency")
	return "\n".join([
		"Average reaction delay: %.2fs" % avg_reaction,
		"Average aggression %.2f | defense %.2f | expansion %.2f | risk %.2f | lane efficiency %.2f" % [avg_aggression, avg_defense, avg_expansion, avg_risk, avg_lane],
		"Runtime perf: FPS %.1f | RTT %.1fms | sim %.2fms | drops %d" % [
			float(_summary.get("avg_runtime_fps", 0.0)),
			float(_summary.get("avg_runtime_rtt_ms", 0.0)),
			float(_summary.get("avg_runtime_sim_ms", 0.0)),
			int(_summary.get("runtime_packet_dropped", 0))
		],
		"Most aggressive: %s" % _top_profile_label("aggression", true),
		"Most defensive: %s" % _top_profile_label("defense_bias", true),
		"Lowest lane efficiency: %s" % _top_profile_label("lane_efficiency", false),
		"Mode coverage: %s" % _format_dict(_summary.get("modes", {}))
	])

func _runtime_summary_lines(summary: Dictionary) -> String:
	if int(summary.get("runtime_perf_matches", 0)) <= 0:
		return "No runtime performance samples found yet."
	return "\n".join([
		"Best match: %s" % str(summary.get("runtime_best_match", "none")),
		"Worst match: %s" % str(summary.get("runtime_worst_match", "none")),
		"Avg FPS: %.1f" % float(summary.get("avg_runtime_fps", 0.0)),
		"Avg sim tick Hz: %.1f" % float(summary.get("avg_runtime_sim_tick_hz", 0.0)),
		"Avg RTT: %.1fms | Max RTT: %.1fms" % [
			float(summary.get("avg_runtime_rtt_ms", 0.0)),
			float(summary.get("max_runtime_rtt_ms", 0.0))
		],
		"Packet drops: %d" % int(summary.get("runtime_packet_dropped", 0)),
		"Snapshot receive rate: %.1f/s" % float(summary.get("avg_runtime_snapshot_receive_hz", 0.0)),
		"Remote wait: %.1f%%" % float(summary.get("avg_runtime_remote_wait_pct", 0.0)),
		"Server frametime: %.1fms" % float(summary.get("avg_runtime_server_frametime_ms", 0.0)),
		"Pool avoided: %d | expansions: %d" % [
			int(summary.get("runtime_pool_avoided", 0)),
			int(summary.get("runtime_pool_expansions", 0))
		],
		"Prewarm avg: %.1fms | save max: %.1fms" % [
			float(summary.get("avg_runtime_prewarm_ms", 0.0)),
			float(summary.get("max_runtime_save_ms", 0.0))
		]
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
	var runtime_summary: Dictionary = _runtime_summary_from_rows(_runtime_perf_rows_for_payloads(matches))
	var out: Dictionary = {
		"matches_found": matches.size(),
		"schema5_matches": schema5,
		"style_ready_matches": style_ready,
		"modes": modes
	}
	for key_any in runtime_summary.keys():
		out[key_any] = runtime_summary.get(key_any)
	return out

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
	for entry in _load_match_file_entries():
		var payload: Dictionary = _dict(entry.get("payload", {}))
		if not payload.is_empty():
			out.append(payload)
	return out

func _load_recent_match_entries(limit: int, include_smoke: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = _load_match_file_entries()
	var filtered: Array[Dictionary] = []
	for entry in entries:
		var payload: Dictionary = _dict(entry.get("payload", {}))
		if payload.is_empty():
			continue
		if not include_smoke and _is_smoke_match(payload):
			continue
		filtered.append(entry)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ma: int = int(a.get("modified_unix", 0))
		var mb: int = int(b.get("modified_unix", 0))
		if ma != mb:
			return ma > mb
		return str(a.get("file_name", "")) > str(b.get("file_name", ""))
	)
	var out: Array[Dictionary] = []
	var max_count: int = mini(maxi(0, limit), filtered.size())
	for i in range(max_count):
		out.append(filtered[i])
	return out

func _load_match_file_entries() -> Array[Dictionary]:
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
		var path: String = "%s/%s" % [MATCHES_DIR, file_name]
		var payload: Dictionary = _load_json_dict(path)
		if not payload.is_empty():
			out.append({
				"file_name": file_name,
				"path": path,
				"modified_unix": int(FileAccess.get_modified_time(path)),
				"payload": payload
			})
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

func _runtime_perf_rows_for_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for entry in entries:
		var payload: Dictionary = _dict(entry.get("payload", {}))
		if payload.is_empty():
			continue
		var row: Dictionary = _runtime_perf_row(payload)
		if row.is_empty():
			continue
		row["file_name"] = str(entry.get("file_name", ""))
		row["path"] = str(entry.get("path", ""))
		row["modified_unix"] = int(entry.get("modified_unix", 0))
		payloads.append(row)
	return payloads

func _runtime_perf_rows_for_payloads(payloads: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for payload in payloads:
		var row: Dictionary = _runtime_perf_row(payload)
		if not row.is_empty():
			rows.append(row)
	return rows

func _runtime_perf_row(payload: Dictionary) -> Dictionary:
	var runtime_perf: Dictionary = _dict(payload.get("runtime_perf", {}))
	var samples: Array = _array(runtime_perf.get("samples", []))
	var runtime_summary: Dictionary = _dict(runtime_perf.get("summary", {}))
	if samples.is_empty() and runtime_summary.is_empty():
		return {}
	var metadata: Dictionary = _dict(payload.get("metadata", {}))
	var match_id: String = str(metadata.get("match_id", "")).strip_edges()
	if match_id.is_empty():
		match_id = "match"
	var avg_fps: float = float(runtime_summary.get("avg_local_fps", _avg_sample_value(samples, "fps")))
	var min_fps: float = float(runtime_summary.get("min_local_fps", _min_sample_value(samples, "fps")))
	var avg_rtt: float = float(runtime_summary.get("avg_ping_rtt_ms", _avg_sample_value(samples, "rtt")))
	var max_rtt: float = float(runtime_summary.get("max_ping_rtt_ms", _max_sample_value(samples, "rtt")))
	var avg_sim_ms: float = float(runtime_summary.get("avg_sim_ms", _avg_sample_value(samples, "sim_ms")))
	var max_sim_ms: float = float(runtime_summary.get("max_sim_ms", _max_sample_value(samples, "sim_ms")))
	var avg_snapshot_hz: float = float(runtime_summary.get("avg_snapshot_receive_rate_hz", _avg_sample_value(samples, "snap_hz")))
	var avg_server_ms: float = float(runtime_summary.get("avg_server_frametime_ms", _avg_sample_value(samples, "srv_ms")))
	var max_server_ms: float = float(runtime_summary.get("max_server_frametime_ms", _max_sample_value(samples, "srv_ms")))
	var pool_avoided: int = int(runtime_summary.get("runtime_instantiates_avoided", _last_sample_int(samples, "pool_avoided")))
	var pool_expansions: int = int(runtime_summary.get("pool_expansions", _last_sample_int(samples, "pool_expansions")))
	var max_active_units: int = int(runtime_summary.get("max_active_units", _max_sample_value(samples, "units")))
	var max_active_lanes: int = int(runtime_summary.get("max_active_lanes", _max_sample_value(samples, "lanes")))
	var max_active_send_lanes: int = int(runtime_summary.get("max_active_send_lanes", _max_sample_value(samples, "send_lanes")))
	var max_active_swarms: int = int(runtime_summary.get("max_active_swarms", _max_sample_value(samples, "swarms")))
	var prewarm_ms: float = float(runtime_summary.get("match_prewarm_duration_ms", _max_sample_value(samples, "prewarm_ms")))
	var save_ms: float = float(runtime_summary.get("post_match_save_duration_ms", _max_sample_value(samples, "save_ms")))
	var packet_drops: int = int(runtime_summary.get("packet_dropped", _last_sample_int(samples, "drop")))
	var avg_sim_tick_hz: float = _avg_sample_value(samples, "sim_hz")
	var remote_wait_pct: float = _remote_wait_pct(samples)
	var score: float = avg_fps - (avg_rtt * 0.05) - (float(packet_drops) * 2.0) - (remote_wait_pct * 0.5) - (avg_server_ms * 0.10) - (max_sim_ms * 0.25)
	return {
		"match_id": match_id,
		"map_id": str(metadata.get("map_id", "")),
		"vs_mode": str(metadata.get("vs_mode", "")),
		"duration_s": float(metadata.get("duration_s", 0.0)),
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"avg_sim_tick_hz": avg_sim_tick_hz,
		"avg_rtt_ms": avg_rtt,
		"max_rtt_ms": max_rtt,
		"avg_sim_ms": avg_sim_ms,
		"max_sim_ms": max_sim_ms,
		"packet_drops": packet_drops,
		"snapshot_receive_hz": avg_snapshot_hz,
		"remote_wait_pct": remote_wait_pct,
		"server_frametime_ms": avg_server_ms,
		"max_server_frametime_ms": max_server_ms,
		"max_active_units": max_active_units,
		"max_active_lanes": max_active_lanes,
		"max_active_send_lanes": max_active_send_lanes,
		"max_active_swarms": max_active_swarms,
		"pool_avoided": pool_avoided,
		"pool_expansions": pool_expansions,
		"prewarm_ms": prewarm_ms,
		"save_ms": save_ms,
		"sample_count": samples.size(),
		"score": score
	}

func _runtime_summary_from_rows(rows: Array[Dictionary]) -> Dictionary:
	if rows.is_empty():
		return {
			"runtime_perf_matches": 0,
			"runtime_best_match": "none",
			"runtime_worst_match": "none",
			"avg_runtime_fps": 0.0,
			"avg_runtime_sim_tick_hz": 0.0,
			"avg_runtime_rtt_ms": 0.0,
			"max_runtime_rtt_ms": 0.0,
			"avg_runtime_sim_ms": 0.0,
			"runtime_packet_dropped": 0,
			"avg_runtime_snapshot_receive_hz": 0.0,
			"avg_runtime_remote_wait_pct": 0.0,
			"avg_runtime_server_frametime_ms": 0.0,
			"runtime_pool_avoided": 0,
			"runtime_pool_expansions": 0,
			"avg_runtime_prewarm_ms": 0.0,
			"max_runtime_save_ms": 0.0
		}
	var best: Dictionary = rows[0]
	var worst: Dictionary = rows[0]
	var sum_fps: float = 0.0
	var sum_sim_hz: float = 0.0
	var sum_rtt: float = 0.0
	var max_rtt: float = 0.0
	var sum_sim_ms: float = 0.0
	var drops: int = 0
	var sum_snapshot_hz: float = 0.0
	var sum_remote_wait_pct: float = 0.0
	var sum_server_ms: float = 0.0
	var pool_avoided_total: int = 0
	var pool_expansion_total: int = 0
	var sum_prewarm_ms: float = 0.0
	var max_save_ms: float = 0.0
	for row in rows:
		if float(row.get("score", 0.0)) > float(best.get("score", 0.0)):
			best = row
		if float(row.get("score", 0.0)) < float(worst.get("score", 0.0)):
			worst = row
		sum_fps += float(row.get("avg_fps", 0.0))
		sum_sim_hz += float(row.get("avg_sim_tick_hz", 0.0))
		sum_rtt += float(row.get("avg_rtt_ms", 0.0))
		max_rtt = maxf(max_rtt, float(row.get("max_rtt_ms", 0.0)))
		sum_sim_ms += float(row.get("avg_sim_ms", 0.0))
		drops += int(row.get("packet_drops", 0))
		sum_snapshot_hz += float(row.get("snapshot_receive_hz", 0.0))
		sum_remote_wait_pct += float(row.get("remote_wait_pct", 0.0))
		sum_server_ms += float(row.get("server_frametime_ms", 0.0))
		pool_avoided_total += int(row.get("pool_avoided", 0))
		pool_expansion_total += int(row.get("pool_expansions", 0))
		sum_prewarm_ms += float(row.get("prewarm_ms", 0.0))
		max_save_ms = maxf(max_save_ms, float(row.get("save_ms", 0.0)))
	var count_f: float = float(maxi(1, rows.size()))
	return {
		"runtime_perf_matches": rows.size(),
		"runtime_best_match": _runtime_match_label(best),
		"runtime_worst_match": _runtime_match_label(worst),
		"avg_runtime_fps": sum_fps / count_f,
		"avg_runtime_sim_tick_hz": sum_sim_hz / count_f,
		"avg_runtime_rtt_ms": sum_rtt / count_f,
		"max_runtime_rtt_ms": max_rtt,
		"avg_runtime_sim_ms": sum_sim_ms / count_f,
		"runtime_packet_dropped": drops,
		"avg_runtime_snapshot_receive_hz": sum_snapshot_hz / count_f,
		"avg_runtime_remote_wait_pct": sum_remote_wait_pct / count_f,
		"avg_runtime_server_frametime_ms": sum_server_ms / count_f,
		"runtime_pool_avoided": pool_avoided_total,
		"runtime_pool_expansions": pool_expansion_total,
		"avg_runtime_prewarm_ms": sum_prewarm_ms / count_f,
		"max_runtime_save_ms": max_save_ms,
		"runtime_matches": rows.duplicate(true)
	}

func _runtime_match_label(row: Dictionary) -> String:
	return "%s | FPS %.1f | RTT %.1fms | drops %d" % [
		str(row.get("match_id", "match")),
		float(row.get("avg_fps", 0.0)),
		float(row.get("avg_rtt_ms", 0.0)),
		int(row.get("packet_drops", 0))
	]

func _avg_sample_value(samples: Array, key: String) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for sample_any in samples:
		var sample: Dictionary = _dict(sample_any)
		if not sample.has(key):
			continue
		total += float(sample.get(key, 0.0))
		count += 1
	return total / float(maxi(1, count))

func _min_sample_value(samples: Array, key: String) -> float:
	var found: bool = false
	var value: float = 0.0
	for sample_any in samples:
		var sample: Dictionary = _dict(sample_any)
		if not sample.has(key):
			continue
		var next_value: float = float(sample.get(key, 0.0))
		if not found or next_value < value:
			value = next_value
			found = true
	return value if found else 0.0

func _max_sample_value(samples: Array, key: String) -> float:
	var found: bool = false
	var value: float = 0.0
	for sample_any in samples:
		var sample: Dictionary = _dict(sample_any)
		if not sample.has(key):
			continue
		var next_value: float = float(sample.get(key, 0.0))
		if not found or next_value > value:
			value = next_value
			found = true
	return value if found else 0.0

func _last_sample_int(samples: Array, key: String) -> int:
	for i in range(samples.size() - 1, -1, -1):
		var sample: Dictionary = _dict(samples[i])
		if sample.has(key):
			return int(sample.get(key, 0))
	return 0

func _remote_wait_pct(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	var wait_count: int = 0
	for sample_any in samples:
		var sample: Dictionary = _dict(sample_any)
		if bool(sample.get("waiting", false)):
			wait_count += 1
	return (float(wait_count) * 100.0) / float(samples.size())

func _device_info() -> Dictionary:
	var screen_size: Vector2i = DisplayServer.screen_get_size() if DisplayServer.get_screen_count() > 0 else Vector2i.ZERO
	return {
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"model_name": OS.get_model_name(),
		"processor_name": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"locale": OS.get_locale(),
		"display_server": DisplayServer.get_name(),
		"screen_size": [screen_size.x, screen_size.y],
		"debug_build": OS.is_debug_build(),
		"engine": Engine.get_version_info()
	}

func _app_info() -> Dictionary:
	return {
		"name": str(ProjectSettings.get_setting("application/config/name", "Swarmfront")),
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"features": ProjectSettings.get_setting("application/config/features", PackedStringArray())
	}

func _backend_info() -> Dictionary:
	var env_url: String = OS.get_environment("SF_VS_BACKEND_URL").strip_edges()
	var settings_url: String = ""
	if ProjectSettings.has_setting("swarmfront/vs/backend_url"):
		settings_url = str(ProjectSettings.get_setting("swarmfront/vs/backend_url", "")).strip_edges()
	var handshake: Node = get_node_or_null("/root/VsHandshake")
	var mode: String = "unknown"
	if handshake != null and handshake.has_method("get_transport_mode"):
		mode = str(handshake.call("get_transport_mode"))
	return {
		"mode": mode,
		"url": env_url if not env_url.is_empty() else settings_url,
		"url_source": "env" if not env_url.is_empty() else "project_settings"
	}

func _utc_ms_now() -> int:
	return int(round(Time.get_unix_time_from_system() * 1000.0))

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
