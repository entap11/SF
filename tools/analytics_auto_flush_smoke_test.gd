extends SceneTree

const SINK_PATH := "user://analytics_auto_flush_sink.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SINK_PATH))
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
		"config_version": "analytics-auto-flush-smoke",
		"analytics": {
			"enabled": true,
			"endpoint_url": SINK_PATH,
			"flush_batch_size": 10,
			"flush_interval_sec": 0.1
		}
	})
	analytics.call("clear_queue_for_smoke")
	var queued: Dictionary = analytics.call("record_event", "error", {
		"error_code": "auto_flush_smoke",
		"message": "auto flush test",
		"context": {}
	}) as Dictionary
	if not bool(queued.get("ok", false)):
		return _fail("event did not queue: %s" % str(queued))
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline and int(analytics.call("queue_count")) > 0:
		await process_frame
	if int(analytics.call("queue_count")) != 0:
		var queued_health: Dictionary = analytics.call("get_health_snapshot") as Dictionary
		return _fail("queue should be empty after auto flush: %s" % str(queued_health))
	if not FileAccess.file_exists(SINK_PATH):
		var missing_health: Dictionary = analytics.call("get_health_snapshot") as Dictionary
		return _fail("auto flush sink missing: %s" % str(missing_health))
	var health: Dictionary = analytics.call("get_health_snapshot") as Dictionary
	if str(health.get("status", "")) != "idle":
		return _fail("health should be idle after auto flush: %s" % str(health))
	if int(health.get("auto_flush_count", 0)) < 1:
		return _fail("auto flush count should increment: %s" % str(health))
	print("ANALYTICS_AUTO_FLUSH_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ANALYTICS_AUTO_FLUSH_SMOKE: %s" % message)
	quit(1)
