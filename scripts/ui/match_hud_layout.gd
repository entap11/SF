extends RefCounted

# Screen geometry only. All values are in the root viewport's logical pixels.
const MARGIN: float = 16.0
const ROW_GAP: float = 8.0
const MENU_SIZE: Vector2 = Vector2(216.0, 124.0)
const AD_SIZE: Vector2 = Vector2(960.0, 150.0)
const POWER_ROW_HEIGHT: float = 92.0
const BUFF_FOOTER_HEIGHT: float = 256.0

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

static func resolve(viewport_size: Vector2, safe: Rect2, footer_top: float = INF, buffs_allowed: bool = false) -> Dictionary:
	var menu := Rect2(safe.position + Vector2(MARGIN, 8.0), MENU_SIZE)
	var width := maxf(1.0, safe.size.x - MARGIN * 2.0)
	var ad_size := Vector2(width, width / (AD_SIZE.x / AD_SIZE.y))
	var ad := Rect2(Vector2(safe.position.x + MARGIN, menu.end.y + ROW_GAP), ad_size)
	var power := Rect2(Vector2(safe.position.x, ad.end.y), Vector2(safe.size.x, POWER_ROW_HEIGHT))
	var footer_height := BUFF_FOOTER_HEIGHT if buffs_allowed else ad_size.y + ROW_GAP * 2.0
	var board_bottom := minf(safe.end.y - footer_height, footer_top)
	var footer := Rect2(Vector2(safe.position.x, board_bottom), Vector2(safe.size.x, safe.end.y - board_bottom))
	var bottom_ad := Rect2(Vector2(safe.position.x + MARGIN, board_bottom + ROW_GAP), ad_size)
	return {
		"menu": menu, "ad": ad, "power": power, "footer": footer,
		"bottom_ad": bottom_ad, "buffs_allowed": buffs_allowed, "safe": safe,
		"board": Rect2(Vector2(safe.position.x, power.end.y), Vector2(safe.size.x, maxf(1.0, board_bottom - power.end.y))),
		"top_inset": power.end.y,
		"bottom_inset": maxf(0.0, viewport_size.y - board_bottom)
	}
