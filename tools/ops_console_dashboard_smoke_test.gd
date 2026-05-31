extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/ops/ops_console.tscn") as PackedScene
	if scene == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: ops console scene missing")
		quit(1)
		return
	var console: Control = scene.instantiate() as Control
	if console == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: ops console instantiate failed")
		quit(1)
		return
	get_root().add_child(console)
	await process_frame
	if console.has_method("refresh"):
		console.call("refresh")
	await process_frame
	var map_count: OptionButton = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapCount") as OptionButton
	var prize_pool: SpinBox = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestPrizePool") as SpinBox
	var rewards_json: TextEdit = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestRewardsJson") as TextEdit
	var map_pool: ItemList = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestForm/ContestMapPool") as ItemList
	var contest_list: ItemList = console.get_node_or_null("RootPanel/RootVBox/Tabs/Contests/ContestsHBox/ContestList") as ItemList
	if map_count == null or map_count.item_count < 2:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map count selector missing")
		quit(1)
		return
	if int(map_count.get_item_metadata(0)) != 3 or int(map_count.get_item_metadata(1)) != 5:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map count selector metadata wrong")
		quit(1)
		return
	if prize_pool == null or rewards_json == null:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: payout fields missing")
		quit(1)
		return
	if map_pool == null or map_pool.item_count <= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: map pool did not load")
		quit(1)
		return
	if contest_list == null or contest_list.item_count <= 0:
		push_error("OPS_CONSOLE_DASHBOARD_SMOKE: contests did not load")
		quit(1)
		return
	console.queue_free()
	await process_frame
	print("OPS_CONSOLE_DASHBOARD_SMOKE: PASS")
	quit(0)
