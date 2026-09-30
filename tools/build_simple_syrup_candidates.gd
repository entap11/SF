extends SceneTree
## Retained drafts are the source. The four playable combinations share two layouts.
const Finalizer = preload("res://tools/map_authoring_finalize_lib.gd")

func _init() -> void:
	var check_only := "--check" in OS.get_cmdline_user_args()
	var failed := false
	for region in ["start", "center"]:
		var source: Dictionary = Finalizer.load_json("res://map_sources/simple_syrup_%s.draft.json" % region).data
		for kind in ["tower", "barracks"]:
			var draft: Dictionary = source.duplicate(true)
			var suffix := "T" if kind == "tower" else "B"
			draft.id = "MAP_simple_syrup__%s_%s__1p" % [region.to_upper(), suffix]
			draft.name = "Simple Syrup — %s Triangles (%s)" % [region.capitalize(), "Towers" if kind == "tower" else "Barracks"]
			for entity in draft.entities:
				if entity.type == "tower": entity.type = kind
			var result: Dictionary = Finalizer.finalize_map(draft)
			if not result.ok:
				push_error(str(result.errors))
				failed = true
				continue
			var path: String = "res://maps/_future/simple_syrup/%s.json" % draft.id
			if check_only:
				if FileAccess.get_file_as_string(path) != JSON.stringify(result.data, "  ") + "\n":
					push_error("Stale generated candidate: " + path)
					failed = true
			else:
				var saved: Dictionary = Finalizer.save_json(path, result.data)
				if not saved.ok:
					push_error(str(saved))
					failed = true
	print("SIMPLE_SYRUP_BUILD: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
