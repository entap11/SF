extends SceneTree

const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")
const PlayerTelemetryProfileStoreScript := preload("res://scripts/state/player_telemetry_profile_store.gd")

func _initialize() -> void:
	var collector: MatchTelemetryCollector = MatchTelemetryCollectorScript.new()
	collector.begin_match(
		"report_smoke_match",
		"dev",
		"MAP_REPORT_SMOKE",
		int(MatchTelemetryModelScript.MATCH_TYPE_VS),
		[1, 2],
		1000,
		{
			"vs_mode": "1V1",
			"players": [
				{"seat": 1, "player_id": "u_report_smoke_a", "display_name": "ReportA", "is_local": true, "is_cpu": false},
				{"seat": 2, "player_id": "u_report_smoke_b", "display_name": "ReportB", "is_local": false, "is_cpu": false}
			]
		}
	)
	collector.record_unit_produced(1000, 1, 8, "lane")
	collector.record_action_event(1400, 1, "lane_open_attack", {"lane_id": 4, "src": 10, "dst": 20, "src_owner": 1, "dst_owner": 2})
	collector.record_intent_event(1400, 1, 10, 20, "attack", true, "", 4, {"src_power": 22, "src_budget": 2, "src_open_slots": 1})
	collector.record_hive_damage(2600, 1, 2, 12)
	collector.record_action_event(3300, 2, "lane_open_attack", {"lane_id": 5, "src": 20, "dst": 10, "src_owner": 2, "dst_owner": 1})
	collector.record_intent_event(3300, 2, 20, 10, "attack", true, "", 5, {"src_power": 18, "src_budget": 2, "src_open_slots": 1})
	collector.record_intent_event(4200, 2, 20, 30, "attack", false, "budget", -1, {"src_power": 18, "src_budget": 1, "src_open_slots": 0})
	var model: Variant = collector.finalize_match(1, 61000)
	var save_result: Dictionary = collector.save_to_user(model)
	if not bool(save_result.get("ok", false)):
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: match save failed %s" % str(save_result))
		quit(1)
		return
	var profile_store: Variant = PlayerTelemetryProfileStoreScript.new()
	var profile_result: Dictionary = profile_store.update_from_match(model)
	if not bool(profile_result.get("ok", false)):
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: profile update failed %s" % str(profile_result))
		quit(1)
		return
	var report_script: Script = load("res://scripts/dev/player_telemetry_report.gd")
	var report_tree: SceneTree = report_script.new()
	var matches: Array[Dictionary] = report_tree.call("_load_match_payloads")
	var profile_payload: Dictionary = report_tree.call("_load_json_dict", "user://player_telemetry_profiles_v1.json")
	var report: Dictionary = report_tree.call("_build_report", matches, profile_payload, true)
	report_tree.free()
	if int(report.get("matches_found", 0)) <= 0:
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: no matches found")
		quit(1)
		return
	if int(report.get("schema5_matches", 0)) <= 0 or int(report.get("style_ready_matches", 0)) <= 0:
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: missing schema/style data %s" % str(report))
		quit(1)
		return
	var human_ids: Array = report.get("human_player_ids", [])
	if not human_ids.has("u_report_smoke_a") or not human_ids.has("u_report_smoke_b"):
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: missing human ids %s" % str(human_ids))
		quit(1)
		return
	var profiles: Array = report.get("profiles", [])
	var found_profile: bool = false
	for profile_any in profiles:
		if typeof(profile_any) != TYPE_DICTIONARY:
			continue
		var profile: Dictionary = profile_any as Dictionary
		if str(profile.get("player_id", "")) != "u_report_smoke_a":
			continue
		found_profile = float(profile.get("aggression", 0.0)) > 0.0 and profile.has("reaction_delay_s")
	if not found_profile:
		push_error("PLAYER_TELEMETRY_REPORT_SMOKE: aggregate profile missing %s" % str(profiles))
		quit(1)
		return
	print("PLAYER_TELEMETRY_REPORT_SMOKE: PASS")
	quit(0)
