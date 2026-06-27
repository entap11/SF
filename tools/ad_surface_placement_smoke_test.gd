extends SceneTree

func _init() -> void:
	var failed: bool = false
	failed = _expect_source_contains(
		"res://scripts/arena.gd",
		[
			"AdSurfaceScript",
			"PrematchHandshakeAdSurface",
			"\"prematch_handshake\", \"handshake\"",
			"InGameHudAdSurface",
			"\"in_game_hud\", \"in_game\"",
			"IN_GAME_AD_TOP_MARGIN_PX",
			"IN_GAME_AD_HUD_Z_INDEX",
			"_in_game_ad_surface.position = Vector2((vr.size.x - ad_size.x) * 0.5, IN_GAME_AD_TOP_MARGIN_PX)",
			"POWER_BAR_ARENA_TOP_GAP_PX",
			"func _arena_playfield_top_screen_y()",
			"anchor.offset_top += delta_y"
		]
	) or failed
	failed = _expect_source_contains(
		"res://scripts/shell.gd",
		[
			"AdSurfaceScript",
			"HandshakeAdSurface",
			"\"vs_handshake\", \"handshake\""
		]
	) or failed
	failed = _expect_source_contains(
		"res://scripts/ui/outcome_overlay.gd",
		[
			"AdSurfaceScript",
			"PostMatchAdSurface",
			"\"post_match_summary\"",
			"\"post_match\""
		]
	) or failed
	if failed:
		quit(1)
		return
	print("AD_SURFACE_PLACEMENT_SMOKE: PASS")
	quit(0)

func _expect_source_contains(path: String, needles: Array[String]) -> bool:
	if not FileAccess.file_exists(path):
		push_error("AD_SURFACE_PLACEMENT_SMOKE: missing source %s" % path)
		return true
	var source: String = FileAccess.get_file_as_string(path)
	var failed: bool = false
	for needle in needles:
		if not source.contains(needle):
			push_error("AD_SURFACE_PLACEMENT_SMOKE: %s missing %s" % [path, needle])
			failed = true
	return failed
