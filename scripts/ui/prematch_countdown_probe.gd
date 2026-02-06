extends Label

const SFLog = preload("res://scripts/util/sf_log.gd")

const DEFAULT_FONT_SIZE: int = 42

var _last_log_ms: int = 0
var _last_sec: int = -1
var _bind_logged: bool = false
var _ready_logged: bool = false

func _control_font_size(control: Control) -> int:
	if control == null:
		return -1
	if control.has_theme_font_size_override("font_size") or control.has_theme_font_size("font_size"):
		return int(control.get_theme_font_size("font_size"))
	return -1

func _ui_node_info(node: CanvasItem) -> Dictionary:
	if node == null:
		return {
			"path": "<null>",
			"class": "<null>",
			"inside_tree": false,
			"visible_in_tree": false,
			"modulate": Color(0, 0, 0, 0),
			"self_modulate": Color(0, 0, 0, 0),
			"scale": Vector2.ZERO,
			"size": Vector2.ZERO,
			"font_size": -1
		}
	var size: Vector2 = Vector2.ZERO
	var font_size: int = -1
	if node is Control:
		var control: Control = node as Control
		size = control.size
		font_size = _control_font_size(control)
	return {
		"path": str(node.get_path()),
		"class": node.get_class(),
		"inside_tree": node.is_inside_tree(),
		"visible_in_tree": node.is_visible_in_tree(),
		"modulate": node.modulate,
		"self_modulate": node.self_modulate,
		"scale": node.scale,
		"size": size,
		"font_size": font_size
	}

func _ready() -> void:
	var font_before: int = _control_font_size(self)
	if font_before > 0 and font_before < DEFAULT_FONT_SIZE:
		add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	elif font_before <= 0:
		add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
	var font_after: int = _control_font_size(self)
	var vp: Viewport = get_viewport()
	var vr: Rect2 = Rect2()
	if vp != null:
		vr = vp.get_visible_rect()
	var gr: Rect2 = get_global_rect()
	if not _ready_logged:
		_ready_logged = true
		SFLog.info("UI_TIMER_READY", {
			"node": _ui_node_info(self),
			"font_before": font_before,
			"font_after": font_after,
			"global_rect": gr,
			"visible_rect": vr
		})
	if not _bind_logged:
		_bind_logged = true
		SFLog.info("UI_TIMER_BIND", {
			"node": _ui_node_info(self),
			"binding": "poll_ops_state"
		})
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
	if sec_left != _last_sec:
		_last_sec = sec_left
		SFLog.info("UI_TIMER_TICK", {
			"node": _ui_node_info(self),
			"phase": phase,
			"ms": ms,
			"sec": sec_left
		})
	var next_text: String = str(sec_left)
	if text != next_text:
		text = next_text
		SFLog.info("UI_TIMER_TEXT_SET", {
			"node": _ui_node_info(self),
			"text": text
		})
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_log_ms >= 1000:
		_last_log_ms = now_ms
		SFLog.info("CLOCK_PROBE_TICK", {
			"phase": phase,
			"ms": ms,
			"sec": sec_left,
			"visible": visible
		})
