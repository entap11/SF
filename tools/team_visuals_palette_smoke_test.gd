extends SceneTree

const TeamVisuals := preload("res://scripts/renderers/team_visuals.gd")

func _init() -> void:
	var green: Color = TeamVisuals.owner_color(3)
	var blue: Color = TeamVisuals.owner_color(4)
	if green.v < 0.99 or green.g < 0.99 or green.r < 0.40:
		_fail("P3 green should be a lighter lime shade")
		return
	if blue.v > 0.76 or blue.b < 0.70 or blue.r > 0.12:
		_fail("P4 blue should be a darker royal blue shade")
		return
	var green_rgb := Vector3(green.r, green.g, green.b)
	var blue_rgb := Vector3(blue.r, blue.g, blue.b)
	if green_rgb.distance_to(blue_rgb) < 0.80:
		_fail("P3 green and P4 blue should be visually separated")
		return
	print("TEAM_VISUALS_PALETTE_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("TEAM_VISUALS_PALETTE_SMOKE: %s" % message)
	quit(1)
