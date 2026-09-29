extends SceneTree

const Base := preload("res://scripts/bot/human_bot_policy.gd")
const Candidate := preload("res://tools/bot_concentration_prototype.gd")
const FOLDER := "/Users/matthewballou/SideProjects/SF/artifacts/bot-concentration-2026-09-22/"

func _initialize() -> void:
	var games: Array = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "observed_choices.json"))
	var reviewed := 0
	var changes: Array[Dictionary] = []
	for game in games:
		for witness in game["witnesses"]:
			var obs: Dictionary = witness["observation"]
			# JSON parses numbers as floats. Restore the observation's declared
			# integer ID/power/time fields before replaying production policy.
			obs["seat"] = int(obs["seat"])
			obs["observed_ms"] = int(obs["observed_ms"])
			for i in range(obs["ids"].size()):
				obs["ids"][i] = int(obs["ids"][i])
			for hive in obs["hives"].values():
				for key in ["id", "owner", "power", "x", "y", "outgoing", "open_slots"]:
					hive[key] = int(hive[key])
			for route in obs["routes"]:
				for key in ["src", "dst", "swarm_ready_ms"]:
					route[key] = int(route[key])
				# Vector2 distances originate as engine real_t (float32).
				route["distance"] = float(PackedFloat32Array([route["distance"]])[0])
			for rows in [obs["pressure"], obs["incoming"]]:
				for row in rows:
					for key in ["src", "dst", "owner", "amount"]:
						if row.has(key):
							row[key] = int(row[key])
			var original := obs.duplicate(true)
			var profile: Dictionary = witness["profile"]
			var now_ms := int(witness["now_ms"])
			witness["memory"] = _restore_memory(witness["memory"])
			for key in ["src", "dst"]:
				witness["action"][key] = int(witness["action"][key])
			var before := Base.new().choose(obs, witness["memory"].duplicate(true), profile, now_ms)
			if before != witness["action"]:
				push_error("Concentration observation replay differs " + JSON.stringify({"index": reviewed, "map": game["map"], "time": now_ms, "actual": before, "expected": witness["action"]}))
				quit(1)
				return
			var proposed := profile.duplicate(true)
			proposed["human_concentrate_pressure"] = true
			var policy := Candidate.new()
			var after := policy.choose(obs, witness["memory"].duplicate(true), proposed, now_ms)
			if obs != original:
				push_error("Concentration audit mutated observation")
				quit(1)
				return
			reviewed += 1
			if before != after:
				changes.append({"map": game["map"], "opponent": game["opponent"], "seat": game["balancer_seat"],
					"now_ms": now_ms, "before": before, "after": after, "observation": obs, "memory": witness["memory"],
					"target_friendly_streams": policy._friendly_pressure(obs, int(after.get("dst", -1)))})
	var file := FileAccess.open(FOLDER + "observation_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"exact_replayed_decisions": reviewed, "changed_choices": changes}, "\t"))
	print("CONCENTRATION_OBSERVATION_AUDIT: PASS exact=%d changed=%d" % [reviewed, changes.size()])
	quit()

func _restore_memory(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		for key in value:
			if str(key) != "optimism":
				value[key] = _restore_memory(value[key])
	elif typeof(value) == TYPE_ARRAY:
		for i in range(value.size()):
			value[i] = _restore_memory(value[i])
	elif typeof(value) == TYPE_FLOAT:
		return int(value)
	return value
