extends SceneTree

const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")
const PlayerTelemetryProfileStoreScript := preload("res://scripts/state/player_telemetry_profile_store.gd")
const TelemetryDashboardPanelScript := preload("res://scripts/ui/telemetry_dashboard_panel.gd")

func _initialize() -> void:
	var collector: MatchTelemetryCollector = MatchTelemetryCollectorScript.new()
	collector.begin_match(
		"dashboard_smoke_match",
		"dev",
		"MAP_DASHBOARD_SMOKE",
		int(MatchTelemetryModelScript.MATCH_TYPE_VS),
		[1, 2],
		1000,
		{
			"vs_mode": "1V1",
			"players": [
				{"seat": 1, "player_id": "u_dashboard_smoke_a", "display_name": "DashA", "is_local": true, "is_cpu": false},
				{"seat": 2, "player_id": "u_dashboard_smoke_b", "display_name": "DashB", "is_local": false, "is_cpu": false}
			]
		}
	)
	collector.record_unit_produced(1000, 1, 10, "lane")
	collector.record_action_event(1500, 1, "lane_open_attack", {"lane_id": 8, "src": 1, "dst": 2, "src_owner": 1, "dst_owner": 2})
	collector.record_intent_event(1500, 1, 1, 2, "attack", true, "", 8, {"src_power": 28, "src_budget": 2, "src_open_slots": 1})
	collector.record_hive_damage(2600, 1, 2, 10)
	collector.record_action_event(4300, 2, "lane_reverse", {"lane_id": 8, "src": 2, "dst": 1, "src_owner": 2, "dst_owner": 1})
	collector.record_intent_event(4300, 2, 2, 1, "attack", true, "", 8, {"src_power": 16, "src_budget": 2, "src_open_slots": 1})
	collector.sample_runtime_perf(5000, {
		"local_fps": 58.0,
		"local_physics_fps": 60.0,
		"local_physics_fixed_hz": 60.0,
		"local_sim_tick_rate_hz": 10.0,
		"local_sim_fixed_hz": 10.0,
		"snapshot_receive_rate_hz": 5.0,
		"ping_rtt_ema_ms": 48.0,
		"ping_rtt_ms": 50.0,
		"server_frametime_ms": 7.0,
		"sim_ms": 1.2,
		"packet_tx": 12,
		"packet_rx": 11,
		"packet_dropped": 1,
		"waiting_for_remote": false
	})
	var model: Variant = collector.finalize_match(1, 61000)
	var save_result: Dictionary = collector.save_to_user(model)
	if not bool(save_result.get("ok", false)):
		_fail("match save failed %s" % str(save_result))
		return
	var profile_store: Variant = PlayerTelemetryProfileStoreScript.new()
	var profile_result: Dictionary = profile_store.update_from_match(model)
	if not bool(profile_result.get("ok", false)):
		_fail("profile update failed %s" % str(profile_result))
		return

	var panel_any: Variant = TelemetryDashboardPanelScript.new()
	if not (panel_any is Control):
		_fail("panel did not instantiate")
		return
	var panel: Control = panel_any as Control
	root.add_child(panel)
	await process_frame
	if not panel.has_method("refresh_data") or not panel.has_method("get_dashboard_snapshot"):
		_fail("dashboard methods missing")
		return
	panel.call("refresh_data", true)
	var snapshot: Dictionary = panel.call("get_dashboard_snapshot") as Dictionary
	var profiles: Array = snapshot.get("profiles", [])
	var found: bool = false
	for profile_any in profiles:
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		if str(profile.get("player_id", "")) == "u_dashboard_smoke_a" and float(profile.get("aggression", 0.0)) > 0.0:
			found = true
			break
	if not found:
		_fail("seeded dashboard profile missing %s" % str(profiles))
		return
	if not panel.has_method("export_debug_bundle"):
		_fail("dashboard export method missing")
		return
	var export_result: Dictionary = panel.call("export_debug_bundle", 5) as Dictionary
	if not bool(export_result.get("ok", false)):
		_fail("dashboard export failed %s" % str(export_result))
		return
	var export_path: String = str(export_result.get("path", ""))
	if export_path.is_empty() or not FileAccess.file_exists(export_path):
		_fail("dashboard export file missing %s" % str(export_result))
		return
	var exported: Dictionary = _load_json_dict(export_path)
	if exported.is_empty() or int((exported.get("matches", []) as Array).size()) <= 0:
		_fail("dashboard export payload missing matches %s" % str(exported))
		return
	var export_summary: Dictionary = exported.get("summary", {}) as Dictionary
	if int(export_summary.get("runtime_perf_matches", 0)) <= 0:
		_fail("dashboard export runtime summary missing %s" % str(export_summary))
		return
	panel.queue_free()
	print("TELEMETRY_DASHBOARD_PANEL_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("TELEMETRY_DASHBOARD_PANEL_SMOKE: %s" % message)
	quit(1)

func _load_json_dict(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
