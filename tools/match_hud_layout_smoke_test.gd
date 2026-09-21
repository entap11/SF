extends SceneTree

const Layout = preload("res://scripts/ui/match_hud_layout.gd")
var failed: bool = false

func _initialize() -> void:
	for viewport_size in [Vector2(1080, 1920), Vector2(944, 2048), Vector2(1080, 2348), Vector2(720, 1280)]:
		var safe := Rect2(Vector2(12, 120), viewport_size - Vector2(24, 180))
		for buffs in [false, true]:
			var layout: Dictionary = Layout.resolve(viewport_size, safe, INF, buffs)
			_expect(safe.encloses(layout.menu) and safe.encloses(layout.ad), "menu and banner respect phone safe area")
			_expect(layout.ad.position.y >= layout.menu.end.y, "banner always sits below menu")
			_expect(is_equal_approx(layout.ad.end.y, layout.power.position.y), "banner meets power row")
			_expect(is_equal_approx(layout.power.end.y, layout.board.position.y), "power row meets arena")
			_expect(is_equal_approx(layout.board.end.y, layout.footer.position.y), "arena meets footer")
			_expect(layout.board.size.y > 500, "smallest supported portrait retains usable arena")
			_expect(not layout.board.intersects(layout.ad) and not layout.board.intersects(layout.bottom_ad), "ads cannot cover gameplay")
			if not buffs:
				_expect(layout.footer.encloses(layout.bottom_ad), "bottom banner stays above home indicator")
				_expect(is_equal_approx(layout.ad.size.x / layout.ad.size.y, 6.4), "creative aspect is preserved")
	print("MATCH_HUD_LAYOUT_SMOKE: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
