extends SceneTree

const BuffCatalog = preload("res://scripts/state/buff_catalog.gd")

func _init() -> void:
	var buffs: Array = BuffCatalog.list_all()
	var unique_paths: Dictionary = {}
	for buff_v in buffs:
		if typeof(buff_v) != TYPE_DICTIONARY:
			_fail("catalog entry is not a dictionary")
			return
		var buff: Dictionary = buff_v as Dictionary
		var buff_id: String = str(buff.get("id", ""))
		var icon_path: String = str(buff.get("icon_path", ""))
		if icon_path == "":
			_fail("%s has no sprite mapping" % buff_id)
			return
		if not ResourceLoader.exists(icon_path):
			_fail("%s points to missing sprite %s" % [buff_id, icon_path])
			return
		unique_paths[icon_path] = true
	print("BUFF_SPRITE_MAPPING_SMOKE: PASS entries=%d unique_sprites=%d" % [buffs.size(), unique_paths.size()])
	quit(0)

func _fail(message: String) -> void:
	push_error("BUFF_SPRITE_MAPPING_SMOKE: %s" % message)
	quit(1)
