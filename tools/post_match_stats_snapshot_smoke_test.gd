extends SceneTree

const MatchTelemetryCollectorScript := preload("res://scripts/state/match_telemetry_collector.gd")
const MatchTelemetryModelScript := preload("res://scripts/state/match_telemetry_model.gd")

func _initialize() -> void:
	await process_frame
	var collector: MatchTelemetryCollector = MatchTelemetryCollectorScript.new()
	collector.begin_match(
		"post_match_snapshot_smoke",
		"local_beta",
		"MAP_SNAPSHOT",
		int(MatchTelemetryModelScript.MATCH_TYPE_BOT),
		[1, 2],
		1000,
		{
			"players": [
				{"seat": 1, "player_id": "local_alpha", "display_name": "Alpha", "is_local": true, "is_cpu": false},
				{"seat": 2, "player_id": "bot_beta", "display_name": "Beta Bot", "is_local": false, "is_cpu": true}
			]
		}
	)
	collector.record_unit_produced(100, 1, 12, "lane")
	collector.record_unit_produced(100, 2, 9, "lane")
	collector.record_unit_arrival(200, 1, 10, 2, 1, "enemy", "lane", 7)
	collector.record_unit_arrival(250, 1, 11, 1, 1, "friendly", "pass_through", 5)
	collector.record_unit_arrival(300, 2, 12, 0, 2, "npc", "lane", 4)
	collector.record_action_event(350, 1, "swarm_send")
	collector.record_action_event(360, 2, "swarm_send")
	collector.record_action_event(370, 2, "swarm_send")
	var telemetry_model: Variant = collector.finalize_match(1, 10000)

	var arena_script: Script = load("res://scripts/arena.gd") as Script
	if arena_script == null:
		return _fail("Arena failed to parse")
	var arena_any: Variant = arena_script.new()
	if not (arena_any is Node):
		return _fail("Arena failed to instantiate")
	var arena: Node = arena_any as Node
	arena.set("active_player_id", 1)
	var snapshot_any: Variant = arena.call("_build_post_match_stats_snapshot", telemetry_model, 1, 272000)
	if typeof(snapshot_any) != TYPE_DICTIONARY:
		arena.free()
		return _fail("snapshot is not a dictionary")
	var snapshot: Dictionary = snapshot_any as Dictionary
	var players_any: Variant = snapshot.get("players", [])
	if str(snapshot.get("match_instance_id", "")) != "post_match_snapshot_smoke" or int(snapshot.get("duration_ms", 0)) != 272000:
		arena.free()
		return _fail("snapshot identity or gameplay duration is wrong: %s" % str(snapshot))
	if typeof(players_any) != TYPE_ARRAY or (players_any as Array).size() != 2:
		arena.free()
		return _fail("snapshot players are missing: %s" % str(players_any))
	var players: Array = players_any as Array
	var local_player: Dictionary = players[0] as Dictionary
	var opponent: Dictionary = players[1] as Dictionary
	if str(local_player.get("display_name", "")) != "Alpha" or not bool(local_player.get("is_local", false)) or not bool(local_player.get("is_winner", false)):
		arena.free()
		return _fail("local player identity is wrong: %s" % str(local_player))
	if int(local_player.get("hives_captured", 0)) != 1 or int(local_player.get("units_created", 0)) != 12 or int(local_player.get("units_landed", 0)) != 7 or int(local_player.get("swarms_initiated", 0)) != 1:
		arena.free()
		return _fail("local player counters are wrong: %s" % str(local_player))
	if int(opponent.get("hives_captured", 0)) != 1 or int(opponent.get("units_created", 0)) != 9 or int(opponent.get("units_landed", 0)) != 4 or int(opponent.get("swarms_initiated", 0)) != 2:
		arena.free()
		return _fail("opponent counters are wrong: %s" % str(opponent))

	collector.record_unit_arrival(11000, 1, 10, 2, 1, "enemy", "lane", 99)
	if int((players[0] as Dictionary).get("units_landed", 0)) != 7:
		arena.free()
		return _fail("frozen snapshot mutated after telemetry finalization")
	arena.free()
	print("POST_MATCH_STATS_SNAPSHOT_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("POST_MATCH_STATS_SNAPSHOT_SMOKE: %s" % message)
	quit(1)
