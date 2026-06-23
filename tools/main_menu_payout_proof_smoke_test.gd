extends SceneTree

const MAIN_MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	var handshake: Node = get_root().get_node_or_null("VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	var scene: PackedScene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	if scene == null:
		_fail("main menu scene missing")
		return
	var menu: Control = scene.instantiate() as Control
	if menu == null:
		_fail("main menu instantiate failed")
		return
	get_root().add_child(menu)
	await process_frame
	await process_frame
	var button: Button = menu.get_node_or_null("PayoutProofButton") as Button
	if button == null:
		_fail("payout proof icon missing")
		return
	if button.text != "$":
		_fail("payout proof icon should be compact")
		return
	if button.modulate.a > 0.8:
		_fail("payout proof icon should be semi-transparent")
		return
	button.pressed.emit()
	await process_frame
	var modal: Panel = menu.get_node_or_null("PayoutProofModal") as Panel
	if modal == null:
		_fail("payout proof modal did not open")
		return
	var title: Label = modal.get_node_or_null("EntryScroll/EntryBody/EntryTitle") as Label
	if title == null or title.text != "Payout Proof":
		_fail("payout proof modal title missing")
		return
	var unavailable: Label = modal.get_node_or_null("EntryScroll/EntryBody/PayoutProofUnavailable") as Label
	if unavailable == null:
		_fail("offline payout proof state missing")
		return
	menu.queue_free()
	await process_frame
	print("MAIN_MENU_PAYOUT_PROOF_SMOKE: PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error("MAIN_MENU_PAYOUT_PROOF_SMOKE: %s" % message)
	quit(1)
