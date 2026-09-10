extends SceneTree

const Layout = preload("res://scripts/ui/match_hud_layout.gd")
var failed: bool = false

func _initialize() -> void:
	var desktop: Dictionary = Layout.resolve(Vector2(1080, 1920), Rect2(0, 0, 1080, 1920))
	_expect(desktop.ad.size == Vector2(720, 90), "compact header preserves the full ad slot")
	_expect(desktop.menu.size == Vector2(225, 110), "menu retains its target size")
	_expect(not desktop.menu.intersects(desktop.ad), "menu and ad cannot overlap")
	_expect(is_equal_approx(desktop.top_inset, 224.0), "separate power row must fit in compact header")
	_expect(is_equal_approx(desktop.bottom_inset, 16.0), "unused footer leaves only an edge gutter")
	for width in [800.0, 982.0, 1080.0, 1543.0]:
		var safe: Rect2 = Rect2(20, 110, width - 40, 2300)
		var layout: Dictionary = Layout.resolve(Vector2(width, 2500), safe)
		_expect(safe.encloses(layout.menu) and safe.encloses(layout.ad), "header stays in safe area at width %s" % width)
		_expect(not layout.menu.intersects(layout.ad), "narrow header must stack without overlap")
		_expect(layout.ad.size == Vector2(720, 90), "narrow supported widths preserve ad size")
		_expect(layout.top_inset - maxf(layout.ad.end.y, layout.menu.end.y) >= 98.0, "power bar retains its own row")
		_expect(2500.0 - layout.bottom_inset <= safe.end.y - 16.0, "board excludes phone home area")
	var footer: Dictionary = Layout.resolve(Vector2(1080, 1920), Rect2(0, 0, 1080, 1920), 1743.0)
	_expect(1920.0 - footer.bottom_inset < 1743.0, "visible bottom controls stay outside the battlefield")
	print("MATCH_HUD_LAYOUT_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
