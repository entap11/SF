extends SceneTree

const MatchShadowCatalogScript := preload("res://scripts/renderers/match_shadow_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var schema_only: bool = args.has("--schema-only")
	var include_disabled: bool = args.has("--include-disabled")
	var path: String = MatchShadowCatalogScript.DEFAULT_CATALOG_PATH
	for arg in args:
		if arg.begins_with("--catalog="):
			path = arg.trim_prefix("--catalog=")
	var data: Dictionary = MatchShadowCatalogScript.load_catalog_data(path)
	var errors: PackedStringArray = MatchShadowCatalogScript.validate_catalog(
		data,
		not schema_only,
		include_disabled
	)
	if errors.is_empty():
		print("MATCH_SHADOW_ASSET_VALIDATOR: PASS")
		print(path)
		quit(0)
		return
	for error in errors:
		push_error("MATCH_SHADOW_ASSET_VALIDATOR: %s" % error)
	quit(1)
