extends SceneTree

const MapAuthoringFinalize := preload("res://tools/map_authoring_finalize_lib.gd")

func _init() -> void:
	await process_frame
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if bool(args.get("help", false)):
		_print_usage()
		quit(0)
		return
	var input_path: String = str(args.get("input", "")).strip_edges()
	var output_path: String = str(args.get("output", "")).strip_edges()
	if input_path.is_empty() or output_path.is_empty():
		push_error("MAP_AUTHORING_FINALIZE: --input and --output are required")
		_print_usage()
		quit(1)
		return
	var loaded: Dictionary = MapAuthoringFinalize.load_json(input_path)
	if not bool(loaded.get("ok", false)):
		push_error("MAP_AUTHORING_FINALIZE: %s" % str(loaded.get("err", "load_failed")))
		quit(1)
		return
	var finalized: Dictionary = MapAuthoringFinalize.finalize_map(loaded.get("data", {}) as Dictionary, args)
	for warning_any in finalized.get("warnings", []) as Array:
		print("MAP_AUTHORING_FINALIZE warning: %s" % str(warning_any))
	if not bool(finalized.get("ok", false)):
		for error_any in finalized.get("errors", []) as Array:
			push_error("MAP_AUTHORING_FINALIZE: %s" % str(error_any))
		quit(1)
		return
	var saved: Dictionary = MapAuthoringFinalize.save_json(output_path, finalized.get("data", {}) as Dictionary)
	if not bool(saved.get("ok", false)):
		push_error("MAP_AUTHORING_FINALIZE: %s" % str(saved.get("err", "save_failed")))
		quit(1)
		return
	var validation: Dictionary = MapAuthoringFinalize.validate_saved_map(output_path, str((finalized.get("data", {}) as Dictionary).get("mode", "")))
	if not bool(validation.get("ok", false)):
		push_error("MAP_AUTHORING_FINALIZE: saved map validation failed: %s" % str(validation.get("err", "invalid")))
		quit(1)
		return
	print("MAP_AUTHORING_FINALIZE: wrote %s" % output_path)
	quit(0)

func _parse_args(raw_args: Array) -> Dictionary:
	var out: Dictionary = {}
	for arg_any in raw_args:
		var arg: String = str(arg_any).strip_edges()
		if arg == "--help" or arg == "-h":
			out["help"] = true
			continue
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = true
			continue
		var key: String = body.substr(0, eq).strip_edges().replace("-", "_")
		var value: String = body.substr(eq + 1).strip_edges()
		match key:
			"player_buckets", "playstyle_tags", "season_tags":
				out[key] = _split_csv(value)
			"structure_slot_groups", "centroid_slot_groups":
				out[key] = _parse_group_arg(value)
			"async_bot_count":
				out[key] = int(value)
			_:
				out[key] = value
	return out

func _split_csv(value: String) -> Array[String]:
	var out: Array[String] = []
	for token in value.split(",", false):
		var clean: String = str(token).strip_edges()
		if not clean.is_empty():
			out.append(clean)
	return out

func _parse_group_arg(value: String) -> Array:
	var groups: Array = []
	var idx: int = 1
	for group_text in value.split(";", false):
		var ids: Array[String] = _split_csv(str(group_text))
		if ids.size() < 3:
			continue
		groups.append({
			"id": "structure_slot_%02d" % idx,
			"hive_ids": ids,
			"allowed": ["tower", "barracks"]
		})
		idx += 1
	return groups

func _print_usage() -> void:
	print("\n".join([
		"Usage:",
		"  godot --headless --path . --script tools/map_authoring_finalize.gd -- --input=res://draft.json --output=res://maps/.../MAP_name__SBASE__1p.json [options]",
		"",
		"Options:",
		"  --id=MAP_family__SBASE__1p",
		"  --name=Display Name",
		"  --family=nomansland",
		"  --display-family=No Man's Land",
		"  --mode=1p|2p|3p|4p",
		"  --player-buckets=1P,2V2,4P_FFA",
		"  --playstyle-tags=FFA,STRATEGY",
		"  --season-tags=nomansland,545",
		"  --rotation-status=candidate",
		"  --centroid-slot-groups=hive_a,hive_b,hive_c;hive_d,hive_e,hive_f"
	]))
