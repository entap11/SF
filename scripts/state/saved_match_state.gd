extends Node

const BackendPolicy = preload("res://scripts/state/test_backend_policy.gd")
const Policy = preload("res://scripts/state/saved_match_policy.gd")
const Store = preload("res://scripts/state/saved_match_store.gd")
const AUTOSAVE_TICKS := 20
var store = Store.new()
var pending: Dictionary = {}
var active_id := ""
var active_owner := ""
var active_map := ""
var active_started_at := 0
var _last_tick := -1
var _arena: Node
var _suppressed := false
var _fingerprint := ""
var last_error := ""

# Launch metadata is data, not an authority. Only these namespaces may persist.
const CONTEXT_PREFIXES = ["vs_", "contest_", "public_contest_", "async_", "hive_tournament_", "progressive_", "jukebox_", "tutorial_", "ctf_", "campaign_", "miss_n_out_"]
const CONTEXT_KEYS = ["practice", "map_ids", "buff_activation_runtime_state", "saved_contest_end_unix", "match_started_unix", "match_randomizer"]

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 2.0
	add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(_arena):
			checkpoint(_arena, true)
	)
	timer.start()

func context() -> Dictionary:
	var result: Dictionary = {}
	for key in get_tree().get_meta_list():
		if _context_key(str(key)):
			result[str(key)] = _clean_data(get_tree().get_meta(key))
	var contest_id := str(result.get("contest_id", ""))
	if not contest_id.is_empty():
		var contest: Variant = ContestState.get_contest(contest_id)
		if contest is Dictionary:
			result["saved_contest_end_unix"] = int(contest.get("end_ts", 0))
		elif contest is Object:
			result["saved_contest_end_unix"] = int(contest.get("end_ts"))
	return result

func can_save(arena: Node) -> bool:
	return is_instance_valid(arena) and not bool(arena.call("_is_pvp_runtime_active")) and not _suppressed and not BotEvaluationSession.is_active() \
		and not BackendPolicy.performance_harness_active() and not FileAccess.file_exists("user://account_deletion_receipt.json") and bool(arena.get("_match_started")) \
		and OpsState.match_phase == OpsState.MatchPhase.RUNNING \
		and bool(Policy.eligibility(context(), OpsState.match_roster).ok)

func begin_match(arena: Node, map_path: String) -> void:
	_arena = arena
	_suppressed = false
	active_map = map_path
	if not pending.is_empty():
		return
	var previous: Dictionary = store.read(active_owner, active_id) if not active_id.is_empty() else {}
	var same_run: bool = _run_key(context()) != "" and _run_key(context()) == _run_key(previous.get("context", {}))
	if not bool(previous.get("launch_only", false)) or not same_run:
		active_id = Crypto.new().generate_random_bytes(16).hex_encode()
	active_owner = ProfileManager.get_user_id()
	active_started_at = int(Time.get_unix_time_from_system())
	_last_tick = -1
	get_tree().set_meta("match_started_unix", active_started_at)

func checkpoint(arena: Node, force: bool = false) -> bool:
	if not can_save(arena) or active_id.is_empty() or active_owner != ProfileManager.get_user_id():
		return false
	if not force and OpsState.state.tick - _last_tick < AUTOSAVE_TICKS:
		return true
	var payload: Dictionary = arena.capture_saved_match()
	payload.merge({"id": active_id, "owner": active_owner, "map_path": active_map,
		"started_at": active_started_at, "saved_at": int(Time.get_unix_time_from_system()),
		"context": context(), "compatibility": compatibility(), "map_hash": FileAccess.get_sha256(active_map)}, true)
	if not store.write(active_owner, active_id, payload):
		last_error = "Your game could not be saved. Free some device storage and try again."
		return false
	_last_tick = OpsState.state.tick
	last_error = ""
	return true

func abort_restore(message: String) -> void:
	pending = {}
	_suppressed = true
	_arena = null
	last_error = message

func attach_restored_arena(arena: Node) -> void:
	_arena = arena
	_last_tick = OpsState.state.tick

func discard_active() -> void:
	_suppressed = true
	if not active_id.is_empty():
		store.remove(active_owner, active_id)
	active_id = ""

func available() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for saved in store.list_for(ProfileManager.get_user_id()):
		var status := validate(saved)
		if not bool(status.ok):
			continue
		result.append(saved)
	return result

func validate(saved: Dictionary, now: int = -1) -> Dictionary:
	if str(saved.get("owner", "")) != ProfileManager.get_user_id():
		return {"ok": false, "reason": "different_player"}
	var launch: Dictionary = saved.get("context", {})
	var eligibility := Policy.eligibility(launch, saved.get("sim", {}).get("authority", {}).get("match_roster", []))
	if not bool(eligibility.ok):
		return eligibility
	var deadline := Policy.deadline(launch)
	var current := int(Time.get_unix_time_from_system()) if now < 0 else now
	if deadline > 0 and current >= deadline:
		return {"ok": false, "reason": "This contest's submission window has closed."}
	var path := str(saved.get("map_path", ""))
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(saved.get("map_hash", "")) or str(saved.get("compatibility", "")) != compatibility():
		return {"ok": false, "reason": "This saved game belongs to a different game version."}
	return {"ok": true}

func request_resume(id: String) -> Dictionary:
	var saved: Dictionary = store.read(ProfileManager.get_user_id(), id)
	if saved.is_empty():
		return {"ok": false, "reason": "The saved game could not be read."}
	var status := validate(saved)
	if not bool(status.ok):
		return status
	pending = saved
	active_id = id
	_last_tick = -1
	active_owner = ProfileManager.get_user_id()
	active_map = str(saved.map_path)
	active_started_at = int(saved.started_at)
	_suppressed = false
	var tree := get_tree()
	for key in tree.get_meta_list():
		if _context_key(str(key)):
			tree.remove_meta(key)
	for key in saved.context:
		if _context_key(str(key)):
			tree.set_meta(key, saved.context[key])
	CampaignRuntime.restore_checkpoint(saved.get("campaign", {}))
	if not saved.get("progressive", {}).is_empty():
		preload("res://scripts/state/progressive_run_store.gd").new().save_current_run(saved.progressive)
	tree.set_meta("start_game", true)
	Gamebot.set_vs(active_map)
	var error := tree.change_scene_to_file("res://scenes/Shell.tscn")
	if error != OK:
		pending = {}
		return {"ok": false, "reason": "The saved game's map could not be opened."}
	return {"ok": true}

func compatibility() -> String:
	if _fingerprint.is_empty():
		var hashes := PackedStringArray(["saved-match-v1"])
		var paths: Array[String] = ["res://scripts/state/game_state.gd", "res://scripts/state/buff_state.gd", "res://scripts/state/buff_definitions.gd", "res://scripts/persistence/checkpoint_fields.gd"]
		for folder in ["res://scripts/ops", "res://scripts/systems", "res://scripts/sim", "res://scripts/bot", "res://scripts/data"]:
			for name in DirAccess.get_files_at(folder):
				if name.ends_with(".gd") or name.ends_with(".gd.remap"):
					var path: String = folder.path_join(name.trim_suffix(".remap"))
					if not paths.has(path):
						paths.append(path)
		paths.sort()
		for path in paths:
			var resolved: String = path
			if FileAccess.file_exists(path + ".remap"):
				var remap := ConfigFile.new()
				if remap.load(path + ".remap") == OK:
					resolved = str(remap.get_value("remap", "path", path))
			hashes.append(path + ":" + FileAccess.get_sha256(resolved))
		_fingerprint = "|".join(hashes).sha256_text()
	return _fingerprint

func _context_key(key: String) -> bool:
	var token := key.to_lower()
	if token.contains("token") or token.contains("password") or token.contains("secret") or token.contains("authorization"):
		return false
	if CONTEXT_KEYS.has(key):
		return true
	for prefix in CONTEXT_PREFIXES:
		if key.begins_with(prefix):
			return true
	return false

func _clean_data(value: Variant) -> Variant:
	if value is Dictionary:
		var cleaned: Dictionary = {}
		for key in value:
			var token := str(key).to_lower()
			if token.contains("token") or token.contains("password") or token.contains("secret") or token.contains("authorization"):
				continue
			cleaned[key] = _clean_data(value[key])
		return cleaned
	if value is Array:
		var cleaned: Array = []
		for entry in value:
			cleaned.append(_clean_data(entry))
		return cleaned
	return null if value is Object or value is Callable or value is Signal else value


func _run_key(launch: Dictionary) -> String:
	return str(launch.get("progressive_run_id", launch.get("vs_stage_run_id", "")))

func save_stage_transition(arena: Node, map_path: String, overrides: Dictionary = {}) -> bool:
	var launch := context()
	launch.merge(overrides, true)
	if not bool(Policy.eligibility(launch, OpsState.match_roster).ok) or BotEvaluationSession.is_active() or BackendPolicy.performance_harness_active():
		return false
	if Policy.deadline(launch) > 0 and int(Time.get_unix_time_from_system()) >= Policy.deadline(launch):
		return false
	_arena = arena
	active_owner = ProfileManager.get_user_id()
	active_id = Crypto.new().generate_random_bytes(16).hex_encode()
	active_map = map_path
	var payload := {"id": active_id, "owner": active_owner, "map_path": map_path,
		"started_at": active_started_at, "saved_at": int(Time.get_unix_time_from_system()),
		"context": launch, "compatibility": compatibility(), "map_hash": FileAccess.get_sha256(map_path),
		"launch_only": true, "campaign": CampaignRuntime.capture_checkpoint(),
		"progressive": arena.get("_progressive_run_store").load_current_run() if str(launch.get("vs_mode", "")) == "PROGRESSIVE" else {}}
	return store.write(active_owner, active_id, payload)
