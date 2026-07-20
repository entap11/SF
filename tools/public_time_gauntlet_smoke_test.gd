extends SceneTree

const Content := preload("res://scripts/state/public_contest_content.gd")
const DashScene := preload("res://scenes/ui/PublicContestDashPanel.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = Content.build_catalog()
	assert(str(catalog.get("schema", "")) == "swarmfront.public_contest_catalog.v1")
	var time: Dictionary = catalog.get("time_puzzle", {}) as Dictionary
	for count in [3, 5]:
		var pack: Dictionary = time.get("three_map" if count == 3 else "five_map", {}) as Dictionary
		var maps: Array = pack.get("maps", []) as Array
		var hashes: Dictionary = {"pack": str(pack.get("pack_hash", ""))}
		var ids: Array = []
		for index in range(maps.size()):
			var map: Dictionary = maps[index] as Dictionary
			ids.append(str(map.get("map_id", "")))
			hashes["map_%d" % (index + 1)] = str(map.get("sha256", ""))
		var validation: Dictionary = Content.validate_definition({"family": "TIME_PUZZLE",
			"map_count": count, "map_ids": ids, "content_hashes": hashes})
		assert(bool(validation.get("ok", false)), "time content validation failed: %s" % validation)
	var gauntlet: Dictionary = catalog.get("gauntlet", {}) as Dictionary
	var stages: Array = gauntlet.get("stages", []) as Array
	assert(stages.size() == 18)
	var gauntlet_hashes: Dictionary = {"pack": str(gauntlet.get("plan_hash", ""))}
	var gauntlet_ids: Array = []
	for index in range(stages.size()):
		var stage: Dictionary = stages[index] as Dictionary
		gauntlet_ids.append(str(stage.get("map_id", "")))
		gauntlet_hashes["map_%d" % (index + 1)] = str(stage.get("map_sha256", ""))
	var gauntlet_validation: Dictionary = Content.validate_definition({"family": "GAUNTLET", "map_count": 18,
		"map_ids": gauntlet_ids, "content_hashes": gauntlet_hashes,
		"attempt_policy": {"stage_plan_hash": str(gauntlet.get("plan_hash", "")), "stage_plan": stages}})
	assert(bool(gauntlet_validation.get("ok", false)), "gauntlet content validation failed: %s" % gauntlet_validation)
	var panel: Control = DashScene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	var labels: Array[String] = []
	_collect_button_text(panel, labels)
	for required in ["WEEKLY", "MONTHLY", "SEASONAL", "3 MAP", "5 MAP", "GAUNTLET", "REFRESH BOARD", "PLAY"]:
		assert(required in labels, "public contest Dash control missing: %s" % required)
	var state_source: String = FileAccess.get_file_as_string("res://scripts/state/public_contest_state.gd")
	assert(state_source.find("ContestState") < 0 and state_source.find("runtime_leaderboards") < 0,
		"public board state must not import local contest fixtures")
	print("public_time_gauntlet_smoke_test: PASS")
	quit(0)

func _collect_button_text(node: Node, out: Array[String]) -> void:
	if node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_button_text(child, out)
