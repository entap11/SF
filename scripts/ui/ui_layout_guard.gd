extends CanvasLayer
const SFLog := preload("res://scripts/util/sf_log.gd")

func _ready() -> void:
	SFLog.allow_tag("UI_LAYOUT_GUARD_AUDIT")
	_audit("ready")
	call_deferred("_audit", "deferred")
	_ensure_next_frame()

func _ensure_next_frame() -> void:
	await get_tree().process_frame
	_audit("next_frame")

func _audit(tag: String) -> void:
	var window_size: Vector2 = get_window().size
	var visible_rect: Rect2 = get_viewport().get_visible_rect()
	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var top_bg: Control = get_node_or_null("HUDRoot/BufferBackdropLayer/BufferRoot/TopBufferBackground") as Control
	var top_rect: Rect2 = Rect2()
	if top_bg != null:
		top_rect = top_bg.get_global_rect()
	SFLog.info("UI_LAYOUT_GUARD_AUDIT", {
		"tag": tag,
		"window": window_size,
		"visible_rect": visible_rect,
		"canvas_transform": canvas_xform,
		"top_bg_global_rect": top_rect
	})
