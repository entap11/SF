extends SceneTree

func _initialize() -> void:
	var loader = load("res://scripts/maps/map_loader.gd")
	for path in ["res://maps/nomansland/MAP_nomansland__SBASE__1p.json", "res://maps/nomansland/MAP_nomansland__SN6__1p.json", "res://maps/nomansland/MAP_nomansland__GBASE__1p.json", "res://maps/_future/nomansland/MAP_nomansland__545__v18_two_hubs_each__1p.json", "res://maps/_future/closequarters/MAP_closequarters__CQ2__1p.json"]:
		var loaded: Dictionary = loader.load_map(path)
		var seats := {}
		for hive in loaded.get("data", {}).get("hives", []):
			var owner := int(hive.get("owner_id", 0))
			if owner > 0:
				seats[owner] = true
		print("SUPPLY_MAP_PREFLIGHT " + JSON.stringify({"path": path, "ok": loaded.get("ok"), "error": loaded.get("err"), "seats": seats.keys(), "keys": loaded.keys()}))
	quit()
