extends SceneTree

const AdSurfaceScript := preload("res://scripts/ui/ad_surface.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", true)
	var root_control := Control.new()
	root_control.custom_minimum_size = Vector2(944, 2048)
	get_root().add_child(root_control)
	var cases: Array[Dictionary] = [
		{"slot": "prematch_handshake", "placement": "handshake", "size": Vector2(468, 60)},
		{"slot": "vs_handshake", "placement": "handshake", "size": Vector2(468, 60)},
		{"slot": "in_game_hud", "placement": "in_game", "size": Vector2(320, 50)},
		{"slot": "post_match_summary", "placement": "post_match", "size": Vector2(520, 72)}
	]
	var y: float = 20.0
	for case in cases:
		var surface: Control = AdSurfaceScript.new() as Control
		root_control.add_child(surface)
		surface.position = Vector2(20.0, y)
		surface.call("configure", str(case.get("slot", "")), str(case.get("placement", "")), case.get("size", Vector2.ZERO), false)
		await process_frame
		if not bool(surface.visible):
			_fail("%s fake ad should be visible" % str(case.get("slot", "")))
			return
		if surface.size.x < float((case.get("size", Vector2.ZERO) as Vector2).x) or surface.size.y < float((case.get("size", Vector2.ZERO) as Vector2).y):
			_fail("%s fake ad surface size collapsed: %s" % [str(case.get("slot", "")), str(surface.size)])
			return
		var label: Label = surface.get_node_or_null("PlaceholderLabel") as Label
		if label == null or not label.visible or not label.text.contains("ENTaP"):
			_fail("%s fake ad creative label missing" % str(case.get("slot", "")))
			return
		y += surface.size.y + 18.0
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	print("AD_FAKE_AD_VISUAL_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	ProjectSettings.set_setting("swarmfront/ads/fake_ads", false)
	push_error("AD_FAKE_AD_VISUAL_SMOKE: %s" % message)
	quit(1)
