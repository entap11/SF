extends SceneTree

const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")
const PlayerTelemetryProfileStoreScript := preload("res://scripts/state/player_telemetry_profile_store.gd")

func _initialize() -> void:
	var collector: MatchTelemetryCollector = MatchTelemetryCollectorScript.new()
	var player_ids: Array[int] = [1, 2]
	collector.begin_match(
		"smoke_match",
		"dev",
		"MAP_TEST",
		int(MatchTelemetryModelScript.MATCH_TYPE_BOT),
		player_ids,
		0,
		{
			"vs_mode": "1V1",
			"players": [
				{"seat": 1, "player_id": "u_smoke_alpha", "display_name": "Alpha", "is_local": true, "is_cpu": false},
				{"seat": 2, "player_id": "u_smoke_beta", "display_name": "Beta", "is_local": false, "is_cpu": false}
			]
		}
	)
	collector.record_unit_produced(1000, 1, 2, "lane")
	collector.record_unit_arrival(2000, 2, 17, 1, 2, "enemy", "lane", 3)
	collector.record_unit_death(3000, 2, 1, "tower_hit", 4)
	collector.record_action_event(1200, 1, "lane_open_attack", {"lane_id": 7, "src": 11, "dst": 12, "src_owner": 1, "dst_owner": 2})
	collector.record_intent_event(1200, 1, 11, 12, "attack", true, "", 7, {"src_power": 24, "src_budget": 2, "src_open_slots": 1})
	collector.record_hive_damage(1500, 1, 2, 5)
	collector.record_intent_event(4000, 2, 17, 99, "attack", false, "budget", -1, {"src_power": 10, "src_budget": 1, "src_open_slots": 0})
	var model: Variant = collector.finalize_match(1, 60000)
	if model == null:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: missing model")
		quit(1)
		return
	var payload: Dictionary = model.to_dict()
	var events_any: Variant = payload.get("events", [])
	var totals_any: Variant = payload.get("totals", {})
	var metrics_any: Variant = payload.get("metrics", {})
	if typeof(events_any) != TYPE_ARRAY:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: events missing")
		quit(1)
		return
	if typeof(totals_any) != TYPE_DICTIONARY:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: totals missing")
		quit(1)
		return
	if typeof(metrics_any) != TYPE_DICTIONARY:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: metrics missing")
		quit(1)
		return
	var events: Array = events_any as Array
	var totals: Dictionary = totals_any as Dictionary
	var metrics: Dictionary = metrics_any as Dictionary
	if int(payload.get("schema_version", 0)) != int(MatchTelemetryModelScript.SCHEMA_VERSION):
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad schema %s" % str(payload.get("schema_version", 0)))
		quit(1)
		return
	if events.size() < 3:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: expected at least 3 events, got %d" % events.size())
		quit(1)
		return
	var spawn_event: Dictionary = events[0] as Dictionary
	var land_event: Dictionary = events[1] as Dictionary
	var death_event: Dictionary = events[2] as Dictionary
	if str(spawn_event.get("name", "")) != "UNIT_SPAWN" or int(spawn_event.get("p", 0)) != 1:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad UNIT_SPAWN %s" % str(spawn_event))
		quit(1)
		return
	if str(land_event.get("name", "")) != "UNIT_LAND" or int(land_event.get("p", 0)) != 2 or int(land_event.get("h", 0)) != 17:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad UNIT_LAND %s" % str(land_event))
		quit(1)
		return
	if str(death_event.get("name", "")) != "UNIT_DEATH" or int(death_event.get("vp", 0)) != 2 or int(death_event.get("kp", -1)) != 1:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad UNIT_DEATH %s" % str(death_event))
		quit(1)
		return
	if int(totals.get("event_count", 0)) < 3:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad totals event_count %s" % str(totals))
		quit(1)
		return
	var intent_totals: Dictionary = totals.get("intent_total_by_player", {})
	if int(intent_totals.get("1", 0)) != 1 or int(intent_totals.get("2", 0)) != 1:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad intent totals %s" % str(intent_totals))
		quit(1)
		return
	var style_features: Array = metrics.get("style_features_by_player", [])
	var bot_knobs: Array = metrics.get("bot_profile_knobs_by_player", [])
	if style_features.size() != 2 or bot_knobs.size() != 2:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: missing style/profile arrays")
		quit(1)
		return
	if not ((style_features[0] as Dictionary).has("aggression")) or not ((bot_knobs[0] as Dictionary).has("reaction_delay_s")):
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: missing bot/style keys")
		quit(1)
		return
	var spawn_totals: Dictionary = totals.get("unit_spawn_by_player", {})
	var land_enemy_totals: Dictionary = totals.get("unit_land_enemy_by_player", {})
	var death_victim_totals: Dictionary = totals.get("unit_deaths_by_victim_player", {})
	var death_killer_totals: Dictionary = totals.get("unit_deaths_by_killer_player", {})
	if int(spawn_totals.get("1", 0)) != 2:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad spawn totals %s" % str(spawn_totals))
		quit(1)
		return
	if int(land_enemy_totals.get("2", 0)) != 3:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad land totals %s" % str(land_enemy_totals))
		quit(1)
		return
	if int(death_victim_totals.get("2", 0)) != 4 or int(death_killer_totals.get("1", 0)) != 4:
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: bad death totals victims=%s killers=%s" % [str(death_victim_totals), str(death_killer_totals)])
		quit(1)
		return
	var profile_store: Variant = PlayerTelemetryProfileStoreScript.new()
	var profile_result: Dictionary = profile_store.update_from_match(model)
	if not bool(profile_result.get("ok", false)):
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: profile update failed %s" % str(profile_result))
		quit(1)
		return
	var alpha_profile: Dictionary = profile_store.get_profile("u_smoke_alpha")
	if alpha_profile.is_empty() or not alpha_profile.has("bot_profile_knobs"):
		push_error("MATCH_TELEMETRY_HOOKS_SMOKE: missing aggregate profile %s" % str(alpha_profile))
		quit(1)
		return
	print("MATCH_TELEMETRY_HOOKS_SMOKE: PASS")
	quit(0)
