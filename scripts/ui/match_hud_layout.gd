extends RefCounted

# Screen geometry only. All values are in the root viewport's logical pixels.
const MARGIN: float = 16.0
const ROW_GAP: float = 16.0
const MENU_SIZE: Vector2 = Vector2(225.0, 110.0)
const AD_SIZE: Vector2 = Vector2(720.0, 90.0)
const POWER_ROW_HEIGHT: float = 98.0

static func safe_rect_for_viewport(viewport: Viewport) -> Rect2:
	var full: Rect2 = viewport.get_visible_rect()
	if OS.get_name() not in ["iOS", "Android"]:
		return full
	var display_safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if not display_safe.has_area():
		return full
	# Includes content scaling, letterboxing and the window's screen origin.
	var safe: Rect2 = viewport.get_screen_transform().affine_inverse() * display_safe
	return full.intersection(safe) if full.intersects(safe) else full

static func resolve(viewport_size: Vector2, safe: Rect2, footer_top: float = INF) -> Dictionary:
	var menu: Rect2 = Rect2(safe.position + Vector2.ONE * MARGIN, MENU_SIZE)
	var ad_size: Vector2 = Vector2(minf(AD_SIZE.x, maxf(1.0, safe.size.x - MARGIN * 2.0)), AD_SIZE.y)
	var ad: Rect2 = Rect2(Vector2(safe.end.x - MARGIN - ad_size.x, menu.position.y + (MENU_SIZE.y - ad_size.y) * 0.5), ad_size)
	if ad.position.x < menu.end.x + ROW_GAP:
		ad.position = Vector2(safe.get_center().x - ad_size.x * 0.5, menu.end.y + ROW_GAP)
	var header_bottom: float = maxf(menu.end.y, ad.end.y) + POWER_ROW_HEIGHT
	var board_bottom: float = minf(safe.end.y - MARGIN, footer_top - MARGIN)
	return {
		"menu": menu,
		"ad": ad,
		"safe": safe,
		"top_inset": header_bottom,
		"bottom_inset": maxf(0.0, viewport_size.y - board_bottom)
	}
