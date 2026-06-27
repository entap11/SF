extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	get_root().set_meta("ops_console_spectator_tab_only", true)
	ProjectSettings.set_setting("swarmfront/vs/backend_url", "")
	var handshake: Node = get_root().get_node_or_null("/root/VsHandshake")
	if handshake != null and handshake.has_method("_configure_transport"):
		handshake.call("_configure_transport")
	var scene: PackedScene = load("res://scenes/ops/ops_console.tscn") as PackedScene
	if scene == null:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: ops console scene missing")
		quit(1)
		return
	var console: Control = scene.instantiate() as Control
	if console == null:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: instantiate failed")
		quit(1)
		return
	get_root().add_child(console)
	await process_frame
	var tabs: TabContainer = console.get_node_or_null("RootPanel/RootVBox/Tabs") as TabContainer
	if tabs == null:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: tabs missing")
		quit(1)
		return
	var spectate: Control = tabs.get_node_or_null("Spectate") as Control
	if spectate == null:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: Spectate tab missing")
		quit(1)
		return
	var session_id: LineEdit = spectate.get_node_or_null("SpectateVBox/Session ID/SpectatorSessionId") as LineEdit
	var uid: LineEdit = spectate.get_node_or_null("SpectateVBox/Spectator UID/SpectatorUid") as LineEdit
	var delay: SpinBox = spectate.get_node_or_null("SpectateVBox/SpectatorOptions/Delay sec/SpectatorDelay") as SpinBox
	var live: CheckButton = spectate.get_node_or_null("SpectateVBox/SpectatorOptions/SpectatorLiveAdmin") as CheckButton
	var join_button: Button = spectate.get_node_or_null("SpectateVBox/SpectatorButtons/SpectatorJoin") as Button
	var poll_button: Button = spectate.get_node_or_null("SpectateVBox/SpectatorButtons/SpectatorPoll") as Button
	var leave_button: Button = spectate.get_node_or_null("SpectateVBox/SpectatorButtons/SpectatorLeave") as Button
	var map_view: Control = spectate.get_node_or_null("SpectateVBox/SpectatorMapView") as Control
	var events: TextEdit = spectate.get_node_or_null("SpectateVBox/SpectatorEvents") as TextEdit
	var runtime: Node = console.get_node_or_null("SpectatorRuntime")
	if session_id == null or uid == null or delay == null or live == null or join_button == null or poll_button == null or leave_button == null or map_view == null or events == null or runtime == null:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: controls missing")
		quit(1)
		return
	if int(delay.value) != 20 or int(delay.min_value) != 10 or int(delay.max_value) != 30:
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: delay defaults wrong")
		quit(1)
		return
	if not runtime.has_method("poll_once") or runtime.has_method("publish_intent"):
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: runtime method surface wrong")
		quit(1)
		return
	if not runtime.has_method("poll_snapshots_once") or not map_view.has_method("set_replay_data"):
		push_error("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: visual spectator surface missing")
		quit(1)
		return
	print("OPS_CONSOLE_SPECTATOR_TAB_SMOKE: PASS")
	quit(0)
