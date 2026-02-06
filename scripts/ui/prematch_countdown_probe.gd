extends Label

const SFLog = preload("res://scripts/util/sf_log.gd")

var _last_log_ms: int = 0

func _ready() -> void:
	var vp: Viewport = get_viewport()
	var vr: Rect2 = Rect2()
	if vp != null:
		vr = vp.get_visible_rect()
	var gr: Rect2 = get_global_rect()
	SFLog.info("CLOCK_PROBE_READY", {
		"path": str(get_path()),
		"visible": visible,
		"modulate": modulate,
		"text": text,
		"visible_rect": vr,
		"global_rect": gr
	})

func _process(_delta: float) -> void:
	var phase: int = int(OpsState.match_phase)
	var ms: int = int(OpsState.prematch_remaining_ms)
	if ms <= 0:
		visible = false
		return
	visible = true
	var sec_left: int = int(ceil(float(ms) / 1000.0))
	text = str(sec_left)
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_log_ms >= 1000:
		_last_log_ms = now_ms
		SFLog.info("CLOCK_PROBE_TICK", {
			"phase": phase,
			"ms": ms,
			"sec": sec_left,
			"visible": visible
		})
