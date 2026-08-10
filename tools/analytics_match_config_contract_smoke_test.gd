extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	var analytics: Node = root.get_node_or_null("AnalyticsClient")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	if analytics == null:
		return _fail("AnalyticsClient autoload missing")
	if not bool(analytics.call("set_perf_harness_isolation", false)):
		return _fail("could not enable the explicit analytics smoke seam")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "analytics-match-config-smoke",
		"analytics": {
			"enabled": true,
			"endpoint_url": "user://analytics_match_config_sink.json",
			"flush_batch_size": 10
		}
	})
	analytics.call("clear_queue_for_smoke")
	var config_hash: String = str(ops_config.call("get_config_hash"))
	var common: Dictionary = {
		"match_id": "match_config_smoke",
		"season_id": "beta",
		"map_id": "MAP_CONFIG_SMOKE",
		"match_type": "VS",
		"vs_mode": "1V1",
		"config_version": "analytics-match-config-smoke",
		"config_hash": config_hash,
		"config_source": "remote_fresh"
	}
	var start_payload: Dictionary = common.duplicate(true)
	start_payload["start_utc_ms"] = 123456
	var start_result: Dictionary = analytics.call("record_match_start", start_payload) as Dictionary
	if not bool(start_result.get("ok", false)):
		return _fail("match_start did not queue: %s" % str(start_result))
	var end_payload: Dictionary = common.duplicate(true)
	end_payload["duration_ms"] = 65000
	end_payload["winner"] = "1"
	var end_result: Dictionary = analytics.call("record_match_end_summary", end_payload) as Dictionary
	if not bool(end_result.get("ok", false)):
		return _fail("match_end_summary did not queue: %s" % str(end_result))
	var queue: Array = analytics.call("get_queue_snapshot") as Array
	if queue.size() != 2:
		return _fail("expected two analytics events, got %d" % queue.size())
	var start_event: Dictionary = queue[0] as Dictionary
	var end_event: Dictionary = queue[1] as Dictionary
	if str(start_event.get("event_name", "")) != "match_start":
		return _fail("first event should be match_start: %s" % str(start_event))
	if str(end_event.get("event_name", "")) != "match_end_summary":
		return _fail("second event should be match_end_summary: %s" % str(end_event))
	for event in [start_event, end_event]:
		var props: Dictionary = (event as Dictionary).get("props", {}) as Dictionary
		if str(props.get("config_version", "")) != "analytics-match-config-smoke":
			return _fail("missing config_version in event: %s" % str(event))
		if str(props.get("config_hash", "")) != config_hash:
			return _fail("missing config_hash in event: %s" % str(event))
		if str(props.get("config_source", "")) != "remote_fresh":
			return _fail("missing config_source in event: %s" % str(event))
	print("ANALYTICS_MATCH_CONFIG_CONTRACT_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ANALYTICS_MATCH_CONFIG_CONTRACT_SMOKE: %s" % message)
	quit(1)
