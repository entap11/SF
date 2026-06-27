extends SceneTree

const SINK_PATH := "user://analytics_client_sink.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ops_config: Node = root.get_node_or_null("OpsConfig")
	var analytics: Node = root.get_node_or_null("AnalyticsClient")
	if ops_config == null:
		return _fail("OpsConfig autoload missing")
	if analytics == null:
		return _fail("AnalyticsClient autoload missing")
	ops_config.call("force_config_for_smoke", {
		"schema_version": 1,
		"config_version": "analytics-smoke",
		"analytics": {
			"enabled": true,
			"endpoint_url": SINK_PATH,
			"flush_batch_size": 10
		}
	})
	analytics.call("clear_queue_for_smoke")
	var queued: Dictionary = analytics.call("record_event", "error", {
		"error_code": "smoke_error",
		"message": "queue test",
		"context": {}
	}) as Dictionary
	if not bool(queued.get("ok", false)):
		return _fail("event did not queue: %s" % str(queued))
	if int(analytics.call("queue_count")) != 1:
		return _fail("queue count should be 1")
	var flush: Dictionary = analytics.call("flush") as Dictionary
	if not bool(flush.get("ok", false)):
		return _fail("flush failed: %s" % str(flush))
	if int(analytics.call("queue_count")) != 0:
		return _fail("queue should be empty after flush")
	if not FileAccess.file_exists(SINK_PATH):
		return _fail("file sink missing")
	print("ANALYTICS_CLIENT_QUEUE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("ANALYTICS_CLIENT_QUEUE_SMOKE: %s" % message)
	quit(1)
