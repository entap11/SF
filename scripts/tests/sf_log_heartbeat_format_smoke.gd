extends SceneTree

const SFLog := preload("res://scripts/util/sf_log.gd")


func _initialize() -> void:
	SFLog.set_quiet_mode(true)
	var formatted: String = SFLog._format_payload("SIM_HEARTBEAT", {
		"ticks": 10,
		"max_tick_ms": 12.34,
		"hotspot_phase": "unit_system",
		"hotspot_ms": 9.76
	})
	var expected := "SIM_HEARTBEAT ticks=10 max_tick_ms=12.3 hotspot_phase=unit_system hotspot_ms=9.8"
	if formatted != expected:
		push_error("SF_LOG_HEARTBEAT_FORMAT_SMOKE_FAIL expected=%s actual=%s" % [expected, formatted])
		quit(1)
		return
	print("SF_LOG_HEARTBEAT_FORMAT_SMOKE_PASS")
	quit(0)
